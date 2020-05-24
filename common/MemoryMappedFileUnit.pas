unit MemoryMappedFileUnit;

interface

uses
  Windows, Classes, SysUtils,
  CommunicationDeviceBaseUnit;

type
  TMemoryMappedFile = class(TCommunicationDeviceBase)
  strict private
    mFileHandle: THandle;
    mPosition: UInt32;
    mCloseFileHandle, mReadOnly, mUnicodeTextFileMode: Boolean;
    mBuffer: PByte;

    function GetIsShared: Boolean;
    function GetIsGlobal: Boolean;
    procedure SetIsGlobal(aValue: Boolean);
    function GetIsLocal: Boolean;
    procedure SetIsLocal(aValue: Boolean);

    function OpenMappedFile(aOpenExisting: Boolean; aReadOnly: Boolean; aFileHandle: THandle; aCloseFileHandle: Boolean): Boolean;

  strict protected
    function GetIsOpen: Boolean; override;

  public
    constructor Create(const aName: string = ''; aBufferSizeDefault: UInt32 = 0);

    function Open(aOpenExisting: Boolean): Boolean; overload; override;
    function Open(aOpenExisting: Boolean; aReadOnly: Boolean): Boolean; overload;
    function Open(aFileHandle: THandle; aReadOnly: Boolean = False; aCloseFileHandle: Boolean = False): Boolean; overload;
    function Open(const aFileName: string; aReadOnly: Boolean = False; aResize: Boolean = False): Boolean; overload;
    function Close: Boolean; override;
    function CreateUnicodeTextFile: Boolean;

    function WriteMemory(aMemory: PByte; aSize: UInt32; aOffset: UInt32 = 0): UInt32;
    function ReadMemory(aMemory: PByte; aSize: UInt32; aOffset: UInt32 = 0): UInt32;
    function Write(const aBuffer; aSize: UInt32; aOffset: UInt32 = 0): UInt32; overload;
    function Read(var aBuffer; aSize: UInt32; aOffset: UInt32 = 0): UInt32; overload;
    function Write(const aBuffer: TBytes; aOffset: UInt32 = 0): UInt32; overload;
    function Read(const aBuffer: TBytes; aOffset: UInt32 = 0): UInt32; overload;
    function Write(const aStream: TMemoryStream; aSize: UInt32 = 0; aOffset: UInt32 = 0): UInt32; overload;
    function Read(const aStream: TMemoryStream; aSize: UInt32 = 0; aOffset: UInt32 = 0): UInt32; overload;
    function AppendUnicodeString(const aStr: string; aLength: UInt32 = 0): UInt32;
    function TruncateAndClose(aSize: UInt32 = 0): UInt32;

    property IsGlobal: Boolean read GetIsGlobal write SetIsGlobal;
    property IsLocal: Boolean read GetIsLocal write SetIsLocal;
    property IsShared: Boolean read GetIsShared;
    property IsReadOnly: Boolean read mReadOnly;
    property Buffer: PByte read mBuffer;
    property UnicodeTextFileMode: Boolean read mUnicodeTextFileMode;
    property Position: UInt32 read mPosition;
  end;

implementation

uses
  HelperUtilitiesUnit;

const
  NAME_GLOBAL_PREFIX = 'Global\';
  NAME_LOCAL_PREFIX = 'Local\';
  BUFFER_SIZE_DEFAULT = 1024 * 1024 * 1024;

constructor TMemoryMappedFile.Create(const aName: string; aBufferSizeDefault: UInt32);
begin
  if aBufferSizeDefault = 0 then
    aBufferSizeDefault := BUFFER_SIZE_DEFAULT;
  inherited Create(aName, aBufferSizeDefault);
end;

function TMemoryMappedFile.OpenMappedFile(aOpenExisting: Boolean; aReadOnly: Boolean; aFileHandle: THandle; aCloseFileHandle: Boolean): Boolean;
var
  aMapName: PChar;
  aSize, aMapAccess, aCreateAccess: UInt32;
  aLInt: TLargeInteger;
begin
  Close;
  mReadOnly := aReadOnly;
  if mReadOnly then
  begin
    aMapAccess := FILE_MAP_READ;
    aCreateAccess := PAGE_READONLY;
  end
  else
  begin
    aMapAccess := FILE_MAP_ALL_ACCESS;
    aCreateAccess := PAGE_READWRITE;
  end;
  aMapName := nil;
  if mName.Length > 0 then
    aMapName := PChar(mName);
  if aOpenExisting then
  begin
    if aCloseFileHandle then
      CloseHandle(aFileHandle);
    if aMapName <> nil then
      mDeviceHandle := OpenFileMapping(
                   aMapAccess,
                   False,
                   aMapName);
  end
  else
  begin
    if aFileHandle = 0 then
      aFileHandle := INVALID_HANDLE_VALUE;
    if aFileHandle = INVALID_HANDLE_VALUE then
      aSize := mBufferSize
    else
    begin
      mCloseFileHandle := aCloseFileHandle;
      mFileHandle := aFileHandle;
      aSize := 0;
      if GetFileSizeEx(aFileHandle, aLInt) then
        mBufferSize := aLInt
      else
      begin
        Close;
        Result := False;
        exit;
      end
    end;
    mDeviceHandle := CreateFileMapping(
                 aFileHandle,
                 nil,
                 aCreateAccess,
                 0,
                 aSize,
                 aMapName);
  end;
  if mDeviceHandle <> 0 then
  begin
    mIsClientMode := aOpenExisting or (GetLastError = ERROR_ALREADY_EXISTS);
    mBuffer := MapViewOfFile(mDeviceHandle,
                        aMapAccess,
                        0,
                        0,
                        0);
    if mBuffer = nil then
      Close;
  end;
  Result := GetIsOpen;
  if not Result then
    Close;
end;

function TMemoryMappedFile.Open(aOpenExisting: Boolean): Boolean;
begin
  Result := OpenMappedFile(aOpenExisting, False, 0, False);
end;

function TMemoryMappedFile.Open(aOpenExisting: Boolean; aReadOnly: Boolean): Boolean;
begin
  Result := OpenMappedFile(aOpenExisting, aReadOnly, 0, False);
end;

function TMemoryMappedFile.Open(aFileHandle: THandle; aReadOnly: Boolean; aCloseFileHandle: Boolean): Boolean;
begin
  Result := OpenMappedFile(False, aReadOnly, aFileHandle, aCloseFileHandle);
end;

function TMemoryMappedFile.Open(const aFileName: string; aReadOnly, aResize: Boolean): Boolean;
var
  aFileHandle: THandle;
  aCreateAccess: UInt32;
  aFileExists: Boolean;
begin
  Result := False;
  aFileExists := FileExists(aFileName);
  aReadOnly := aReadOnly and aFileExists;
  aCreateAccess := GENERIC_READ;
  if not aReadOnly then
    aCreateAccess := aCreateAccess or GENERIC_WRITE;
  aFileHandle := CreateFile(PChar(aFileName), aCreateAccess, FILE_SHARE_READ, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if aFileHandle <> INVALID_HANDLE_VALUE then
  begin
    aFileExists := GetLastError = ERROR_ALREADY_EXISTS;
    aResize := not aReadOnly and (aResize or not aFileExists);
    if aResize and SetFilePointerEx(aFileHandle, mBufferSize, nil, FILE_BEGIN) then
      SetEndOfFile(aFileHandle);

    Result := OpenMappedFile(False, aReadOnly, aFileHandle, True);
  end;
end;

function TMemoryMappedFile.Close: Boolean;
begin
  if mBuffer <> nil then
  begin
    UnmapViewOfFile(mBuffer);
    mBuffer := nil;
  end;
  Result := inherited Close;
  if mCloseFileHandle and (mFileHandle <> 0) and (mFileHandle <> INVALID_HANDLE_VALUE) then
  begin
    if mUnicodeTextFileMode and SetFilePointerEx(mFileHandle, mPosition, nil, FILE_BEGIN) then
      SetEndOfFile(mFileHandle);
    CloseHandle(mFileHandle);
  end;
  mFileHandle := 0;
  mCloseFileHandle := False;
  mReadOnly := False;
  mBufferSize := mBufferSizeDefault;
  mUnicodeTextFileMode := False;
  mPosition := 0;
end;

function TMemoryMappedFile.CreateUnicodeTextFile: Boolean;
begin
  Result := not mUnicodeTextFileMode and not mReadOnly and GetIsOpen;
  if Result then
    mUnicodeTextFileMode := True;
end;

function TMemoryMappedFile.GetIsGlobal: Boolean;
begin
  Result := mName.StartsWith(NAME_GLOBAL_PREFIX, True);
end;

procedure TMemoryMappedFile.SetIsGlobal(aValue: Boolean);
var
  aCur: Boolean;
begin
  if mName.Length > 0 then
  begin
    aCur := GetIsGlobal;
    if aCur xor aValue then
    begin
      if aValue then
      begin
        if GetIsLocal then
          Delete(mName, 1, Length(NAME_LOCAL_PREFIX));
        mName := NAME_GLOBAL_PREFIX + mName
      end
      else
        Delete(mName, 1, Length(NAME_GLOBAL_PREFIX))
    end
  end;
end;

function TMemoryMappedFile.GetIsLocal: Boolean;
begin
  Result := mName.StartsWith(NAME_LOCAL_PREFIX, True);
end;

procedure TMemoryMappedFile.SetIsLocal(aValue: Boolean);
var
  aCur: Boolean;
begin
  if mName.Length > 0 then
  begin
    aCur := GetIsLocal;
    if aCur xor aValue then
    begin
      if aValue then
      begin
        if GetIsGlobal then
          Delete(mName, 1, Length(NAME_GLOBAL_PREFIX));
        mName := NAME_LOCAL_PREFIX + mName
      end
      else
        Delete(mName, 1, Length(NAME_LOCAL_PREFIX))
    end
  end;
end;

function TMemoryMappedFile.GetIsOpen: Boolean;
begin
  Result := inherited GetIsOpen and (mBuffer <> nil);
end;

function TMemoryMappedFile.GetIsShared: Boolean;
begin
  Result := GetIsOpen and mIsClientMode;
end;

function TMemoryMappedFile.WriteMemory(aMemory: PByte; aSize: UInt32; aOffset: UInt32): UInt32;
var
  aDest: PByte;
begin
  Result := 0;
  if not mReadOnly and GetIsOpen and Assigned(aMemory) and (aSize > 0) and (aOffset < mBufferSize) then
  begin
    if aSize + aOffset > mBufferSize then
      aSize := mBufferSize - aOffset;
    aDest := mBuffer;
    Inc(aDest, aOffset);
    CopyMemory(aDest, aMemory, aSize);
    Result := aSize;
  end;
end;

function TMemoryMappedFile.ReadMemory(aMemory: PByte; aSize: UInt32; aOffset: UInt32): UInt32;
var
  aDest: PByte;
begin
  Result := 0;
  if GetIsOpen and Assigned(aMemory) and (aSize > 0) and (aOffset < mBufferSize) then
  begin
    if aSize + aOffset > mBufferSize then
      aSize := mBufferSize - aOffset;
    aDest := mBuffer;
    Inc(aDest, aOffset);
    CopyMemory(aMemory, aDest, aSize);
    Result := aSize;
  end;
end;

function TMemoryMappedFile.Write(const aBuffer; aSize: UInt32; aOffset: UInt32): UInt32;
var
  aDest: PByte;
begin
  Result := 0;
  if not mReadOnly and GetIsOpen and (aSize > 0) and (aOffset < mBufferSize) then
  begin
    if aSize + aOffset > mBufferSize then
      aSize := mBufferSize - aOffset;
    aDest := mBuffer;
    Inc(aDest, aOffset);
    Move(aBuffer, aDest^, aSize);
    Result := aSize;
  end;
end;

function TMemoryMappedFile.Read(var aBuffer; aSize: UInt32; aOffset: UInt32): UInt32;
var
  aDest: PByte;
begin
  Result := 0;
  if GetIsOpen and (aSize > 0) and (aOffset < mBufferSize) then
  begin
    if aSize + aOffset > mBufferSize then
      aSize := mBufferSize - aOffset;
    aDest := mBuffer;
    Inc(aDest, aOffset);
    Move(aDest^, aBuffer, aSize);
    Result := aSize;
  end;
end;

function TMemoryMappedFile.Write(const aBuffer: TBytes; aOffset: UInt32): UInt32;
var
  aSize: UInt32;
begin
  Result := 0;
  aSize := Length(aBuffer);
  if aSize > 0 then
    Result := Write(aBuffer[0], aSize, aOffset);
end;

function TMemoryMappedFile.Read(const aBuffer: TBytes; aOffset: UInt32): UInt32;
var
  aSize: UInt32;
begin
  Result := 0;
  aSize := Length(aBuffer);
  if aSize > 0 then
    Result := Read(aBuffer[0], aSize, aOffset);
end;

function TMemoryMappedFile.Write(const aStream: TMemoryStream; aSize: UInt32; aOffset: UInt32): UInt32;
begin
  Result := 0;
  if not mReadOnly and Assigned(aStream) then
  begin
    if (aSize = 0) or (aSize > aStream.Size) then
      aSize := aStream.Size;
    Result := WriteMemory(aStream.Memory, aSize, aOffset);
  end;
end;

function TMemoryMappedFile.Read(const aStream: TMemoryStream; aSize: UInt32; aOffset: UInt32): UInt32;
begin
  Result := 0;
  if Assigned(aStream) then
  begin
    if (aSize = 0) or (aSize > aStream.Size) then
      aSize := aStream.Size;
    Result := ReadMemory(aStream.Memory, aSize, aOffset);
  end;
end;

function TMemoryMappedFile.AppendUnicodeString(const aStr: string; aLength: UInt32): UInt32;
var
  aLen, aWritten: UInt32;
begin
  Result := 0;
  aLen := Length(aStr);
  if mUnicodeTextFileMode and (aLen > 0) then
  begin
    if (aLength = 0) or (aLength > aLen) then
      aLength := aLen;
    if mPosition = 0 then
    begin
      aWritten := Write(UNICODE_BOM, SizeOf(UNICODE_BOM), mPosition);
      Inc(Result, aWritten);
      Inc(mPosition, aWritten);
    end;
    aWritten := Write(aStr[1], aLength * SizeOf(Char), mPosition);
    Inc(Result, aWritten);
    Inc(mPosition, aWritten);
  end;
end;

function TMemoryMappedFile.TruncateAndClose(aSize: UInt32): UInt32;
var
  aNewSize: TLargeInteger;
begin
  Result := 0;
  if (mFileHandle <> 0) and (mFileHandle <> INVALID_HANDLE_VALUE) then
  begin
    if (aSize = 0) and mUnicodeTextFileMode then
      aSize := mPosition
    else if (aSize = 0) or (aSize > mBufferSize) then
      aSize := mBufferSize;
    aNewSize := 0;
    if SetFilePointerEx(mFileHandle, aSize, @aNewSize, FILE_BEGIN) and SetEndOfFile(mFileHandle) then
    begin
      mBufferSize := aNewSize;
      Result := mBufferSize;
      mUnicodeTextFileMode := False;
      Close;
    end;
  end;
end;

end.
