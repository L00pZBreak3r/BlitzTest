unit MergeSorterUnit;

interface

uses
  System.Generics.Collections, Classes, Windows, SysUtils, SyncObjs,
  MemoryMappedFileUnit;

type
  TStringFileMergeSorter = class;
  TTextFileStringItem = class
  strict private
    mBuffer: PByte;
    mBufferSize: Int64;
    mEncoding: TEncoding;
    mStringFileMergeSorter: TStringFileMergeSorter;

    function GetText: string;
  private
    mIndex, mLength: Int64;
    mStart: PByte;
    function GetTextN(aMaxLength: Integer = 0): string;

    property Text: string read GetText;
  public
    constructor Create(const aStringFileMergeSorter: TStringFileMergeSorter; const aEncoding: TEncoding; aBuffer: PByte; aBufferSize, aIndex: Int64; aStart: PByte; aLength: Int64);
  end;

  TTextFileStringItemList = TObjectList<TTextFileStringItem>;

  TStringCompareFunc = function(const S1: string; const S2: string): Integer;
  TStringFileMergeSorterEvent = procedure(Sender: TStringFileMergeSorter; aSortSuccessful: Boolean) of object;

  TStringFileMergeSorter = class
  private
    mLineCount: Int64;
    mMaxLineLength: Integer;
    mTextLock: TCriticalSection;
    [volatile] mCanWork: Boolean;
  strict private
    mDepth: Integer;
    mCaseInsensitive, mIsUnicode, mSortSuccessful: Boolean;
    [volatile] mIsWorking: Boolean;
    mEncoding: TEncoding;
    mStringCompareFunc: TStringCompareFunc;
    mJobThread: TThread;
    mMemoryMappedFile: TMemoryMappedFile;
    mLines: TTextFileStringItemList;
    mTextPreamble: TBytes;

    mOnSortingCompleted: TStringFileMergeSorterEvent;

    procedure SetCaseInsensitive(aValue: Boolean);
    procedure SetIsUnicode(aValue: Boolean);
    procedure SetMaxLineLength(aValue: Integer);
    procedure SetDepth(aValue: Integer);
    function GetIsFileOpen: Boolean;

    function GetLine(aIndex: Int64): TTextFileStringItem;
    procedure SetLine(aIndex: Int64; const aValue: TTextFileStringItem);

    function FillLines: Int64;
    procedure TriggerOnSortingCompletedEvent;
  private
    procedure Merge(aLow, aMid, aHigh: Int64);
    procedure MergeSort(aLow, aLen: Int64; aDepth: Integer);

    function DoSorting(const aCallerThread: TThread = nil): Integer;

    property Lines[Index: Int64]: TTextFileStringItem read GetLine write SetLine;
  public
    OnSortingCompletedUsesSynchronize: Boolean;

    constructor Create(aCaseInsensitive: Boolean = False; aMaxLineLength: Integer = 0; aDepth: Integer = 0);
    destructor Destroy; override;

    function Open(const aFileName: string): Boolean;
    function Save(const aFileName: string = ''; aUnicode: Boolean = False): Boolean;
    function Close(aTerminate: Boolean = False): Integer;
    function Start: Boolean;
    function Stop(aTerminate: Boolean = False): Integer;
    function WaitForResult: Integer;
    property Depth: Integer read mDepth write SetDepth;
    property MaxLineLength: Integer read mMaxLineLength write SetMaxLineLength;
    property CaseInsensitive: Boolean read mCaseInsensitive write SetCaseInsensitive;
    property IsUnicode: Boolean read mIsUnicode write SetIsUnicode;
    property IsWorking: Boolean read mIsWorking;
    property IsFileOpen: Boolean read GetIsFileOpen;
    property SortSuccessful: Boolean read mSortSuccessful;
    property OnSortingCompleted: TStringFileMergeSorterEvent read mOnSortingCompleted write mOnSortingCompleted;
  end;


implementation

uses
  HelperUtilitiesUnit;

type
  TMergeSorterThreadAction = (SORTER_THREAD_ACTION_MAIN_JOB, SORTER_THREAD_ACTION_SORT);
  TMergeSorterThread = class(TThread)
  strict private
    mStringFileMergeSorter: TStringFileMergeSorter;
    mAction: TMergeSorterThreadAction;
    mStart: Int64;
    mLength: Int64;
    mDepth: Integer;
  protected
    constructor Create(const aStringFileMergeSorter: TStringFileMergeSorter; aAction: TMergeSorterThreadAction; aStart: Int64 = 0; aLength: Int64 = 0; aDepth: Integer = 0);
    procedure Execute; override;    
  end;

  TStrChrNFunc = function(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall;

const
  MAX_LINE_LENGTH = 50;
  LINE_END_MARKER = #10;
  STARTING_DEPTH_DEFAULT = 8;
  ELEMENTS_FOR_LEVEL = 512;
  DEPTH_MAX = 8;


{ TTextFileStringItem }

constructor TTextFileStringItem.Create(const aStringFileMergeSorter: TStringFileMergeSorter; const aEncoding: TEncoding; aBuffer: PByte; aBufferSize, aIndex: Int64; aStart: PByte; aLength: Int64);
begin
  mStringFileMergeSorter := aStringFileMergeSorter;
  mEncoding := aEncoding;
  mBuffer := aBuffer;
  mBufferSize := aBufferSize;
  mIndex := aIndex;
  mStart := aStart;
  mLength := aLength;
end;

function TTextFileStringItem.GetTextN(aMaxLength: Integer): string;
var
  aSize: Int64;
  aBytes: TBytes;
begin
  Result := string.Empty;
  if Assigned(mStringFileMergeSorter) and Assigned(mBuffer) and (mBufferSize > 0) and Assigned(mStart) and (mLength > 0) and Assigned(mEncoding) then
  begin
    mStringFileMergeSorter.mTextLock.Acquire;
    aSize := mLength;
    if aMaxLength > 0 then
    begin
      if (mEncoding.CodePage = TEncoding.Unicode.CodePage) or (mEncoding.CodePage = TEncoding.BigEndianUnicode.CodePage) then
        aMaxLength := aMaxLength * SizeOf(Char);
      if aSize > aMaxLength then
        aSize := aMaxLength;
    end;
    SetLength(aBytes, aSize);
    Move(mStart^, aBytes[0], aSize);
    Result := mEncoding.GetString(aBytes);
    mStringFileMergeSorter.mTextLock.Release;
  end;
end;

function TTextFileStringItem.GetText: string;
begin
  Result := GetTextN(mStringFileMergeSorter.mMaxLineLength)
end;

{ TMergeSorterThread }

constructor TMergeSorterThread.Create(const aStringFileMergeSorter: TStringFileMergeSorter; aAction: TMergeSorterThreadAction; aStart: Int64; aLength: Int64; aDepth: Integer);
begin
  mStringFileMergeSorter := aStringFileMergeSorter;
  mAction := aAction;
  mStart := aStart;
  mLength := aLength;
  mDepth := aDepth;
  inherited Create(False);
end;

procedure TMergeSorterThread.Execute;
begin
  if not Terminated and mStringFileMergeSorter.mCanWork then
  if mAction = SORTER_THREAD_ACTION_MAIN_JOB then
  begin
    ReturnValue := mStringFileMergeSorter.DoSorting(Self);
  end
  else if mAction = SORTER_THREAD_ACTION_SORT then
  begin
    mStringFileMergeSorter.MergeSort(mStart, mLength, mDepth);
  end
end;

{ TStringFileMergeSorter }

constructor TStringFileMergeSorter.Create(aCaseInsensitive: Boolean; aMaxLineLength: Integer; aDepth: Integer);
begin
  if aMaxLineLength < 0 then
    aMaxLineLength := MAX_LINE_LENGTH;
  mMaxLineLength := aMaxLineLength;
  if aDepth <= 0 then
    aDepth := STARTING_DEPTH_DEFAULT;
  mDepth := aDepth;

  mCaseInsensitive := aCaseInsensitive;
  if mCaseInsensitive then
    mStringCompareFunc := AnsiCompareText
  else
    mStringCompareFunc := AnsiCompareStr;
  mEncoding := TEncoding.ANSI;
  mTextLock := TCriticalSection.Create;
end;

destructor TStringFileMergeSorter.Destroy;
begin
  Close(True);
  FreeAndNil(mTextLock);
  inherited
end;

procedure TStringFileMergeSorter.SetCaseInsensitive(aValue: Boolean);
begin
  if not mIsWorking then
  begin
    mCaseInsensitive := aValue;
    if mCaseInsensitive then
      mStringCompareFunc := AnsiCompareText
    else
      mStringCompareFunc := AnsiCompareStr;
  end;
end;

procedure TStringFileMergeSorter.SetIsUnicode(aValue: Boolean);
begin
  if not mIsWorking then
  begin
    mIsUnicode := aValue;
    if mIsUnicode then
      mEncoding := TEncoding.Unicode
    else
      mEncoding := TEncoding.ANSI
  end;
end;

procedure TStringFileMergeSorter.SetMaxLineLength(aValue: Integer);
begin
  if not mIsWorking then
  begin
    if aValue < 0 then
      aValue := MAX_LINE_LENGTH;
    mMaxLineLength := aValue;
  end;
end;

procedure TStringFileMergeSorter.SetDepth(aValue: Integer);
begin
  if not mIsWorking then
  begin
    if aValue <= 0 then
      aValue := STARTING_DEPTH_DEFAULT;
    mDepth := aValue;
  end;
end;

function TStringFileMergeSorter.GetLine(aIndex: Int64): TTextFileStringItem;
begin
  Result := nil;
  if Assigned(mLines) and (aIndex >= 0) and (aIndex < mLineCount) then
    Result := mLines[aIndex];
end;

procedure TStringFileMergeSorter.SetLine(aIndex: Int64; const aValue: TTextFileStringItem);
begin
  if Assigned(mLines) and (aIndex >= 0) and (aIndex < mLineCount) and Assigned(aValue) then
    mLines[aIndex] := aValue;
end;

function TStringFileMergeSorter.FillLines: Int64;
var
  aBuffer, aStartBuff, aEndBuff, aLineEnd: PByte;
  aBufferSize: Int64;
  aStart, aCharSize: Integer;
  aEncoding: TEncoding;
  aStrChrN: TStrChrNFunc;
  aBytes: TBytes;
  aBE: Boolean;
begin
  Result := 0;
  if not mIsWorking and GetIsFileOpen and not Assigned(mLines) then
  begin
    aBuffer := mMemoryMappedFile.Buffer;
    aBufferSize := mMemoryMappedFile.BufferSize;
    if aBufferSize > 0 then
    begin
      aStart := 0;
      aEncoding := nil;
      aBE := False;
      if aBufferSize >= 4 then
      begin
        SetLength(aBytes, 4);
        Move(aBuffer^, aBytes[0], 4);
        aStart := TEncoding.GetBufferEncoding(aBytes, aEncoding);
      end;
      if (aStart > 0) and Assigned(aEncoding) then
      begin
        aBE := aEncoding.CodePage = TEncoding.BigEndianUnicode.CodePage;
        IsUnicode := (aEncoding.CodePage = TEncoding.Unicode.CodePage) or aBE;
        mEncoding := aEncoding;
        SetLength(mTextPreamble, aStart);
        Move(aBuffer^, mTextPreamble[0], aStart);
      end
      else
        aEncoding := mEncoding;
      if IsUnicode then
      begin
        if aBE then
          aStrChrN := StrChrNB
        else
          aStrChrN := StrChrNW;
        aCharSize := SizeOf(Char);
      end
      else
      begin
        aStrChrN := StrChrNA;
        aCharSize := SizeOf(AnsiChar);
      end;
      aStartBuff := aBuffer;
      aEndBuff := aBuffer;
      Inc(aStartBuff, aStart);
      Inc(aEndBuff, aBufferSize);
      mLines := TTextFileStringItemList.Create(False);
      while aStartBuff < aEndBuff do
      begin
        aLineEnd := aStrChrN(aStartBuff, LINE_END_MARKER, (aEndBuff - aStartBuff) div aCharSize);
        if aLineEnd = nil then
          aLineEnd := aEndBuff
        else
          Inc(aLineEnd, aCharSize);

        mLines.Add(TTextFileStringItem.Create(Self, aEncoding, aBuffer, aBufferSize, Result, aStartBuff, aLineEnd - aStartBuff));
        Inc(Result);
        aStartBuff := aLineEnd;
      end;
    end;
    mLineCount := Result;
  end;
end;

procedure TStringFileMergeSorter.Merge(aLow, aMid, aHigh: Int64);
var
  aResPart: TTextFileStringItemList;
  aL, aR: TTextFileStringItem;
  i, j: Int64;
begin
  i := aLow;
  j := aMid;
  aResPart := TTextFileStringItemList.Create(False);
  
  while mCanWork and (i < aMid) and (j < aHigh) do
  begin
    aL := Lines[i];
    aR := Lines[j];
    if mStringCompareFunc(aL.Text, aR.Text) <= 0 then
    begin
      aResPart.Add(aL);
      Inc(i);
    end
    else
    begin
      aResPart.Add(aR);
      Inc(j);
    end;
  end;

  while mCanWork and (i < aMid) do
  begin
    aL := Lines[i];
    aResPart.Add(aL);
    Inc(i);
  end;

  i := 0;
  j := aResPart.Count;
  while mCanWork and (i < j) do
  begin
    Lines[i + aLow] := aResPart[i];
    Inc(i);
  end;

  aResPart.Free;
end;

procedure TStringFileMergeSorter.MergeSort(aLow, aLen: Int64; aDepth: Integer);
var
  aMidLen: Int64;
  aThread: TMergeSorterThread;
begin
  if mCanWork and (aLen >= 2) then
  begin
    aMidLen := aLen div 2;
    if (aDepth <= 0) or (aLen < 4) then
    begin
        MergeSort(aLow, aMidLen, 0);
        MergeSort(aLow + aMidLen, aLen - aMidLen, 0);
    end
    else
    begin
        aDepth := aDepth div 2;
        aThread := TMergeSorterThread.Create(Self, SORTER_THREAD_ACTION_SORT, aLow, aMidLen, aDepth);

        MergeSort(aLow + aMidLen, aLen - aMidLen, aDepth);

        aThread.WaitFor;
        aThread.Free;
    end;

    Merge(aLow, aLow + aMidLen, aLow + aLen);
  end
end;

function TStringFileMergeSorter.Open(const aFileName: string): Boolean;
begin
  Close;
  Result := FileExists(aFileName);
  if Result then
  begin
    mMemoryMappedFile := TMemoryMappedFile.Create();
    Result := mMemoryMappedFile.Open(aFileName);
    if Result then
      FillLines
  end;
end;

function TStringFileMergeSorter.Close(aTerminate: Boolean): Integer;
var
  i: Int64;
begin
  Result := Stop(aTerminate);
  if Assigned(mLines) then
  begin
    for i := 0 to mLineCount - 1 do
      if Assigned(mLines[i]) then
        mLines[i].Free;
    FreeAndNil(mLines);
  end;
  if Assigned(mMemoryMappedFile) then
    FreeAndNil(mMemoryMappedFile);
  mLineCount := 0;
  SetLength(mTextPreamble, 0);
end;

function TStringFileMergeSorter.GetIsFileOpen: Boolean;
begin
  Result := Assigned(mMemoryMappedFile) and mMemoryMappedFile.IsOpen;
end;

function TStringFileMergeSorter.Save(const aFileName: string; aUnicode: Boolean): Boolean;
var
  aMemoryMappedFile: TMemoryMappedFile;
  aNewFile: Boolean;
  i: Int64;
  aSize, aOffset: UInt32;
begin
  Result := False;
  if not mIsWorking and GetIsFileOpen and (mLineCount > 0) then
  begin
    aNewFile := Length(aFileName) > 0;
    aMemoryMappedFile := TMemoryMappedFile.Create;
    aSize := mMemoryMappedFile.BufferSize;
    aUnicode := aUnicode and aNewFile and (mEncoding.CodePage <> TEncoding.Unicode.CodePage);
    if aUnicode then
      aSize := aSize * SizeOf(Char) + SizeOf(UNICODE_BOM);
    aMemoryMappedFile.BufferSize := aSize;
    if aNewFile then
    begin
      Result := aMemoryMappedFile.Open(aFileName, False, True);
      aUnicode := aUnicode and Result and aMemoryMappedFile.CreateUnicodeTextFile;
    end
    else
      Result := aMemoryMappedFile.Open(False);
    if Result then
    begin
      aOffset := 0;
      if (Length(mTextPreamble) > 0) and not aUnicode then
        Inc(aOffset, aMemoryMappedFile.Write(mTextPreamble));
      for i := 0 to mLineCount - 1 do
      begin
        if aUnicode then
          aSize := aMemoryMappedFile.AppendUnicodeString(mLines[i].GetTextN)
        else
          aSize := aMemoryMappedFile.WriteMemory(mLines[i].mStart, mLines[i].mLength, aOffset);
        Inc(aOffset, aSize);
      end;
      if not aNewFile then
        CopyMemory(mMemoryMappedFile.Buffer, aMemoryMappedFile.Buffer, mMemoryMappedFile.BufferSize);
      aMemoryMappedFile.TruncateAndClose(aOffset);
    end;
    aMemoryMappedFile.Free;
  end;
end;

function TStringFileMergeSorter.DoSorting(const aCallerThread: TThread): Integer;
var
  aDepth: Integer;
begin
  Result := 0;
  if mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) and not mIsWorking and GetIsFileOpen and (mLineCount > 0) then
  begin
    mIsWorking := True;
    aDepth := mDepth;
    if aDepth > mLineCount div ELEMENTS_FOR_LEVEL then
      aDepth := mLineCount div ELEMENTS_FOR_LEVEL;
    if aDepth > DEPTH_MAX then
      aDepth := DEPTH_MAX;
    MergeSort(0, mLineCount, aDepth);
    Result := 1;

    mIsWorking := False;
    mSortSuccessful := mCanWork;
    mCanWork := False;
    if Assigned(aCallerThread) and OnSortingCompletedUsesSynchronize then
      TThread.Synchronize(aCallerThread, TriggerOnSortingCompletedEvent)
    else
      TriggerOnSortingCompletedEvent
  end;
end;

procedure TStringFileMergeSorter.TriggerOnSortingCompletedEvent;
begin
  if Assigned(mOnSortingCompleted) then
    mOnSortingCompleted(Self, mSortSuccessful)
end;

function TStringFileMergeSorter.Start: Boolean;
begin
  Result := False;
  if not mIsWorking and GetIsFileOpen and (mLineCount > 0) then
  begin
    mCanWork := True;
    mSortSuccessful := False;
    mJobThread := TMergeSorterThread.Create(Self, SORTER_THREAD_ACTION_MAIN_JOB);
    Result := True;
  end;
end;

function TStringFileMergeSorter.Stop(aTerminate: Boolean): Integer;
begin
  if aTerminate then
    mCanWork := False;

  Result := WaitForResult;
  mCanWork := False;
  mSortSuccessful := False;
end;

function TStringFileMergeSorter.WaitForResult: Integer;
begin
  Result := -1;
  if Assigned(mJobThread) then
  begin
    Result := mJobThread.WaitFor;
    FreeAndNil(mJobThread);
  end;
end;

end.
