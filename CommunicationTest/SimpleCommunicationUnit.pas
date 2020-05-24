unit SimpleCommunicationUnit;

interface

uses
  System.Generics.Collections, Classes, SysUtils, SyncObjs,
  PipeServerBaseUnit;

const
  LIST_ITEM_DELIMITER = #10;
  LIST_ITEM_SIZE_PART_DELIMITER = '|';
  DIRECTORY_NAME_PEERS = 'peers';
  DIRECTORY_NAME_FILES = 'files';

type
  TCommunicationEndpointBase = class;
  TCommunicationEndpointRequestNumber = (REQUEST_NONE, REQUEST_DISCONNECT, REQUEST_EMPTY, REQUEST_GET_PEER_INFORMATION, REQUEST_GET_FILE_LIST, REQUEST_GET_FILE);
  TCommunicationEndpointRequestResult = (REQUEST_RESULT_ASK, REQUEST_RESULT_FAILURE, REQUEST_RESULT_SUCCESS, REQUEST_RESULT_SUCCESS_BEGIN, REQUEST_RESULT_SUCCESS_PART);
  TCommunicationEndpointType = (CommunicationEndpointUnknown, CommunicationEndpointServer, CommunicationEndpointClient);

  TCommunicationEndpointDataExchangeEvent = procedure(Sender: TCommunicationEndpointBase; aClientPipe: THandle; aDirection: TPipeDirectionEventType; var aError: UInt32; aBytesTransferred: UInt32; const aRequest: TBytes; var aResponse: TBytes; var aDontReadAfterWrite: Boolean;
                                                      var aRequestNumber: TCommunicationEndpointRequestNumber; var aRequestResult: TCommunicationEndpointRequestResult; var aString: string; var aDataSize: UInt32; aDataOffset: UInt32) of object;
  TCommunicationEndpointClientDataSendEvent = procedure(Sender: TCommunicationEndpointBase; var aResponse: TBytes; var aDontReadAfterWrite: Boolean;
                                                        var aRequestNumber: TCommunicationEndpointRequestNumber; var aRequestResult: TCommunicationEndpointRequestResult; var aString: string) of object;

  TAvailableFile = class
  strict private
    mPath: string;
    mSize: UInt32;
  public
    constructor Create(const aPath: string; aSize: UInt32);

    property Path: string read mPath;
    property Size: Uint32 read mSize;
  end;

  TAvailableFilesList = TObjectList<TAvailableFile>;

  TCommunicationEndpointBase = class
  strict private
    mEndpointType: TCommunicationEndpointType;

    function GetCommunicationDeviceName: string;
    procedure SetCommunicationDeviceName(const aValue: string);
    function GetBufferSize: UInt32;
    procedure SetBufferSize(aValue: UInt32);
    function GetIsWorking: Boolean;

    function GetOnServerStarted: TNotifyEvent;
    procedure SetOnServerStarted(const aValue: TNotifyEvent);
    function GetOnServerStopped: TNotifyEvent;
    procedure SetOnServerStopped(const aValue: TNotifyEvent);

    function GetOnDataExchangeUsesSynchronize: Boolean;
    procedure SetOnDataExchangeUsesSynchronize(aValue: Boolean);
    function GetOnClientDataSendUsesSynchronize: Boolean;
    procedure SetOnClientDataSendUsesSynchronize(aValue: Boolean);

    function GetAvailableFiles: TAvailableFilesList;

    function GetTransferringFileName: string;
    function GetTransferringFileSize: Integer;
    function GetTransferringFileBytesTransferred: Integer;
    function GetTransferringFileSending: Boolean;

  strict protected
    mPipeServer: TPipeServerBase;
    mName, mDescription: string;
    mAvailableFiles: TAvailableFilesList;
    mAvailableFilesLock: TCriticalSection;
    mTransferringFile: TFileStream;
    mTransferringFileClient: THandle; 
    mTransferringFileMode: Word;

    mOnDataExchange: TCommunicationEndpointDataExchangeEvent;
    mOnClientDataSend: TCommunicationEndpointClientDataSendEvent;

    class function GenerateGuidName: string; static;
    class function CreateDirectories: Boolean; static;
    class function GetFilesDirectoryContentString: string; static;
    class function BuildRequestHeader(aRequestNumber: TCommunicationEndpointRequestNumber; aRequestResult: TCommunicationEndpointRequestResult = REQUEST_RESULT_ASK; aStringLength: Word = 0; aBodySize: UInt32 = 0): UInt64; static;
    class function BuildRequest(aRequestNumber: TCommunicationEndpointRequestNumber; aRequestResult: TCommunicationEndpointRequestResult = REQUEST_RESULT_ASK; const aString: string = ''; const aBody: TStream = nil; aPartLength: UInt32 = 0): TBytes; static;
    class function ParseRequest(const aRequest: TBytes; out aRequestNumber: TCommunicationEndpointRequestNumber; out aRequestResult: TCommunicationEndpointRequestResult; out aString: string; out aBodySize: UInt32; out aDataOffset: UInt32; const aBody: TStream = nil): Boolean; static;

    class function BuildPeerInformationString(aEndpointType: TCommunicationEndpointType; const aEndpointName: string; const aEndpointDescription: string = ''): string; static;
    class procedure ParsePeerInformationString(const aPeerInformationString: string; out aEndpointType: TCommunicationEndpointType; out aEndpointName: string; out aEndpointDescription: string); static;

    function CreateTransferringFile(const aFileName: string; aMode: Word): TFileStream;
    procedure FreeTransferringFile;

    function GetIsOpen: Boolean; virtual;
    function GetIsClientMode: Boolean; virtual;
    procedure SetName(const aValue: string); virtual;

    function ProcessRequest(aClientPipe: THandle; const aRequest: TBytes; var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; out aRequestNumber: TCommunicationEndpointRequestNumber; out aRequestResult: TCommunicationEndpointRequestResult; out aString: string; out aBodySize: UInt32; out aDataOffset: UInt32): Boolean; virtual;
    function ProcessRequestPeerInformation(var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; aRequestResult: TCommunicationEndpointRequestResult; const aRequestString: string): Boolean; virtual;
    function ProcessRequestFileList(var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; aRequestResult: TCommunicationEndpointRequestResult; const aRequestString: string): Boolean; virtual;
    function ProcessRequestFile(aClientPipe: THandle; const aRequest: TBytes; var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; aRequestResult: TCommunicationEndpointRequestResult; const aRequestString: string; aBodySize: UInt32): Boolean; virtual;

    function SendClientRequestDisconnect: Boolean;

    procedure PipeServerConnected(Sender: TPipeServerBase; aClientPipe: THandle; aDirection: TPipeDirectionEventType; var aError: UInt32; aBytesTransferred: UInt32; const aRequest: TBytes; var aResponse: TBytes; out aDontReadAfterWrite: Boolean); virtual;
    procedure PipeServerClientDataSend(Sender: TPipeServerBase; aClientPipe: THandle; var aResponse: TBytes; out aDontReadAfterWrite: Boolean); virtual;
  public
    constructor Create(aEndpointType: TCommunicationEndpointType; const aCommunicationDeviceName: string = ''; const aName: string = ''; aBufferSize: UInt32 = 0);
    destructor Destroy; override;

    function Open(aOpenExisting: Boolean): Boolean; virtual;
    function Close: Boolean; virtual;
    function Start: Boolean; virtual;
    function Stop: Integer; virtual;

    procedure ReleaseAvailableFiles;

    function SendClientRequest(aRequestNumber: TCommunicationEndpointRequestNumber; const aRequestStringPart: string; out aResponseNumber: TCommunicationEndpointRequestNumber; out aResponseResult: TCommunicationEndpointRequestResult; out aResponseString: string; var aResponseBodySize: UInt32; const aResponseBody: TStream = nil; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): UInt32;

    property Name: string read mName write SetName;
    property Description: string read mDescription write mDescription;
    property CommunicationDeviceName: string read GetCommunicationDeviceName write SetCommunicationDeviceName;
    property IsOpen: Boolean read GetIsOpen;
    property BufferSize: UInt32 read GetBufferSize write SetBufferSize;
    property IsClientMode: Boolean read GetIsClientMode;
    property IsWorking: Boolean read GetIsWorking;
    property EndpointType: TCommunicationEndpointType read mEndpointType;
    property OnServerStarted: TNotifyEvent read GetOnServerStarted write SetOnServerStarted;
    property OnServerStopped: TNotifyEvent read GetOnServerStopped write SetOnServerStopped;
    property OnDataExchange: TCommunicationEndpointDataExchangeEvent read mOnDataExchange write mOnDataExchange;
    property OnClientDataSend: TCommunicationEndpointClientDataSendEvent read mOnClientDataSend write mOnClientDataSend;
    property OnDataExchangeUsesSynchronize: Boolean read GetOnDataExchangeUsesSynchronize write SetOnDataExchangeUsesSynchronize;
    property OnClientDataSendUsesSynchronize: Boolean read GetOnClientDataSendUsesSynchronize write SetOnClientDataSendUsesSynchronize;
    property AvailableFiles: TAvailableFilesList read GetAvailableFiles;
    property TransferringFileName: string read GetTransferringFileName;
    property TransferringFileSize: Integer read GetTransferringFileSize;
    property TransferringFileBytesTransferred: Integer read GetTransferringFileBytesTransferred;
    property TransferringFileSending: Boolean read GetTransferringFileSending;
  end;

implementation

uses
  Types, IOUtils,
  HelperUtilitiesUnit;

const
  GUID_STRING_DEFAULT = '{00020400-0000-0000-C000-0000000000A1}';
  REQUEST_STRING_PART_LENGTH_DEFAULT = 512;
  COMMUNICATION_ENDPOINT_NAMES : array [TCommunicationEndpointType] of string =
    (
      'Unknown', 'Server', 'Client'
    );

{ TAvailableFile }

constructor TAvailableFile.Create(const aPath: string; aSize: UInt32);
begin
  mPath := aPath;
  mSize := aSize;
end;

{ TCommunicationEndpointBase }

constructor TCommunicationEndpointBase.Create(aEndpointType: TCommunicationEndpointType; const aCommunicationDeviceName: string; const aName: string; aBufferSize: UInt32);
var
  aNameStr: string;
begin
  mEndpointType := aEndpointType;
  aNameStr := Trim(aName);
  if aNameStr.Length <= 0 then
    aNameStr := GenerateGuidName;
  mName := aNameStr;
  aNameStr := Trim(aCommunicationDeviceName);
  if aNameStr.Length <= 0 then
    aNameStr := GenerateGuidName;
  mPipeServer := TPipeServerBase.Create(aNameStr, aBufferSize);
  mPipeServer.OnConnected := PipeServerConnected;
  mPipeServer.OnClientDataSend := PipeServerClientDataSend;
  mAvailableFilesLock := TCriticalSection.Create;
  mAvailableFiles := TAvailableFilesList.Create;
  CreateDirectories;
end;

destructor TCommunicationEndpointBase.Destroy;
begin
  SendClientRequestDisconnect;
  mAvailableFilesLock.Acquire;
  FreeAndNil(mAvailableFiles);
  mAvailableFilesLock.Release;
  FreeAndNil(mAvailableFilesLock);
  mPipeServer.Free;
  FreeTransferringFile;
  inherited
end;

class function TCommunicationEndpointBase.GenerateGuidName: string;
begin
  Result := GenerateGuidString(GUID_STRING_DEFAULT)
end;

class function TCommunicationEndpointBase.CreateDirectories: Boolean;
begin
  Result := (DirectoryExists(DIRECTORY_NAME_PEERS) or CreateDir(DIRECTORY_NAME_PEERS))
        and (DirectoryExists(DIRECTORY_NAME_FILES) or CreateDir(DIRECTORY_NAME_FILES));
end;

class function TCommunicationEndpointBase.GetFilesDirectoryContentString: string;
var
  aList: TStringDynArray;
  aStringBuilder: TStringBuilder;
  aCnt, i, aStartIndex: Integer;
begin
  Result := string.Empty;
  if DirectoryExists(DIRECTORY_NAME_FILES) then
  begin
    aList := TDirectory.GetFiles(DIRECTORY_NAME_FILES);
    aCnt := Length(aList);
    if aCnt > 0 then
    begin
      aStartIndex := Length(DIRECTORY_NAME_FILES) + 1;
      aStringBuilder := TStringBuilder.Create;
      for i := 0 to aCnt - 1 do
      begin
        aStringBuilder.Append(aList[i], aStartIndex, Length(aList[i]) - aStartIndex);
        aStringBuilder.Append(LIST_ITEM_SIZE_PART_DELIMITER);
        aStringBuilder.Append(GetFileSize(aList[i]));
        aStringBuilder.Append(LIST_ITEM_DELIMITER);
      end;
      Result := aStringBuilder.ToString(True);
      aStringBuilder.Free;
    end
  end
end;

class function TCommunicationEndpointBase.BuildRequestHeader(aRequestNumber: TCommunicationEndpointRequestNumber; aRequestResult: TCommunicationEndpointRequestResult; aStringLength: Word; aBodySize: UInt32): UInt64;
begin
  Result := UInt64(Ord(aRequestNumber)) or (UInt64(Ord(aRequestResult)) shl 8) or (UInt64(aStringLength * SizeOf(Char)) shl 16) or (UInt64(aBodySize) shl 32)
end;

class function TCommunicationEndpointBase.BuildRequest(aRequestNumber: TCommunicationEndpointRequestNumber; aRequestResult: TCommunicationEndpointRequestResult; const aString: string; const aBody: TStream; aPartLength: UInt32): TBytes;
var
  aStringLen: Word;
  aBodySize: UInt32;
  aRequestHeader: UInt64;
  aOffset: Integer;
begin
  aStringLen := aString.Length;
  aBodySize := 0;
  if Assigned(aBody) then
  begin
    aBodySize := aBody.Size;
    if (aBodySize > 0) and (aPartLength > 0) then
      aBodySize := aPartLength;
  end;
  aRequestHeader := BuildRequestHeader(aRequestNumber, aRequestResult, aStringLen, aBodySize);
  aStringLen := aStringLen * SizeOf(Char);
  aOffset := SizeOf(aRequestHeader) + aStringLen + aBodySize;
  SetLength(Result, aOffset);
  aOffset := 0;
  Move(aRequestHeader, Result[aOffset], SizeOf(aRequestHeader));
  Inc(aOffset, SizeOf(aRequestHeader));
  if aStringLen > 0 then
  begin
    Move(aString[1], Result[aOffset], aStringLen);
    Inc(aOffset, aStringLen);
  end;
  if aBodySize > 0 then
  begin
    aBody.ReadBuffer(Result[aOffset], aBodySize);
  end;
end;

class function TCommunicationEndpointBase.ParseRequest(const aRequest: TBytes; out aRequestNumber: TCommunicationEndpointRequestNumber; out aRequestResult: TCommunicationEndpointRequestResult; out aString: string; out aBodySize: UInt32; out aDataOffset: UInt32; const aBody: TStream): Boolean;
var
  aRequestLen, aOffset: Integer;
  aRequestHeader: UInt64;
  aByte: Byte;
  aStringLen: Word;
begin
  Result := False;
  aRequestNumber := REQUEST_NONE;
  aRequestResult := REQUEST_RESULT_ASK;
  aString := string.Empty;
  aBodySize := 0;
  aDataOffset := 0;

  aRequestLen := Length(aRequest);
  if aRequestLen >= SizeOf(aRequestHeader) then
  begin
    aOffset := 0;
    Move(aRequest[aOffset], aRequestHeader, SizeOf(aRequestHeader));
    Inc(aOffset, SizeOf(aRequestHeader));
    aByte := Byte(aRequestHeader and High(Byte));
    Result := (aByte > 0) and (aByte <= Ord(High(TCommunicationEndpointRequestNumber)));
    if Result then
    begin
      aRequestNumber := TCommunicationEndpointRequestNumber(aByte);
      aByte := Byte((aRequestHeader shr 8) and High(Byte));
      if aByte <= Ord(High(TCommunicationEndpointRequestResult)) then
        aRequestResult := TCommunicationEndpointRequestResult(aByte)
      else
        Result := False;
      if Result then
      begin
        aStringLen := Word((aRequestHeader shr 16) and High(Word));
        aBodySize := UInt32((aRequestHeader shr 32) and High(UInt32));
        if aStringLen > 0 then
        begin
          if aRequestLen >= aStringLen + aOffset then
          begin
            SetLength(aString, aStringLen div SizeOf(Char));
            Move(aRequest[aOffset], aString[1], aStringLen);
          end;
          Inc(aOffset, aStringLen);
        end;
        if (aRequestResult >= REQUEST_RESULT_SUCCESS) and (aRequestResult <= REQUEST_RESULT_SUCCESS_PART) and (aBodySize > 0) then
        begin
          if aRequestLen >= aBodySize + aOffset then
          begin
            aDataOffset := aOffset;
            if Assigned(aBody) then
              aBody.WriteBuffer(aRequest[aOffset], aBodySize);
          end;
        end;
      end;
    end
  end;
end;

class function TCommunicationEndpointBase.BuildPeerInformationString(aEndpointType: TCommunicationEndpointType; const aEndpointName: string; const aEndpointDescription: string): string;
begin
  Result := IntToStr(Ord(aEndpointType));
  if aEndpointName.Length > 0 then
    Result := Result + LIST_ITEM_DELIMITER + aEndpointName;
  if aEndpointDescription.Length > 0 then
    Result := Result + LIST_ITEM_DELIMITER + aEndpointDescription;
end;

class procedure TCommunicationEndpointBase.ParsePeerInformationString(const aPeerInformationString: string; out aEndpointType: TCommunicationEndpointType; out aEndpointName: string; out aEndpointDescription: string);
var
  aSplitted: TArray<string>;
  aStr: string;
  aLen: Integer;
begin
  aEndpointType := CommunicationEndpointUnknown;
  aEndpointName := string.Empty;
  aEndpointDescription := string.Empty;
  aStr := Trim(aPeerInformationString);
  if aStr.Length > 0 then
  begin
    aSplitted := aStr.Split([LIST_ITEM_DELIMITER]);
    aLen := Length(aSplitted);
    if aLen > 0 then
    begin
      aEndpointType := TCommunicationEndpointType(StrToIntDef(aSplitted[0], Ord(CommunicationEndpointUnknown)));
      if aLen > 1 then
      begin
        aEndpointName := aSplitted[1];
        if aLen > 2 then
          aEndpointDescription := aSplitted[2];
      end
    end
  end;
end;

function TCommunicationEndpointBase.Close: Boolean;
begin
  SendClientRequestDisconnect;
  Result := mPipeServer.Close;
  FreeTransferringFile;
end;

function TCommunicationEndpointBase.Open(aOpenExisting: Boolean): Boolean;
begin
  FreeTransferringFile;
  Result := mPipeServer.Open(aOpenExisting);
end;

function TCommunicationEndpointBase.Start: Boolean;
begin
  FreeTransferringFile;
  Result := mPipeServer.Start;
end;

function TCommunicationEndpointBase.Stop: Integer;
begin
  SendClientRequestDisconnect;
  Result := mPipeServer.Stop;
  FreeTransferringFile;
end;

procedure TCommunicationEndpointBase.SetName(const aValue: string);
var
  aNameStr: string;
begin
  if not GetIsOpen then
  begin
    aNameStr := Trim(aValue);
    if aNameStr.Length <= 0 then
      aNameStr := GenerateGuidName;
    mName := aNameStr;
  end
end;

function TCommunicationEndpointBase.GetCommunicationDeviceName: string;
begin
  Result := mPipeServer.Name;
end;

procedure TCommunicationEndpointBase.SetCommunicationDeviceName(const aValue: string);
var
  aNameStr: string;
begin
  if not GetIsOpen then
  begin
    aNameStr := Trim(aValue);
    if aNameStr.Length <= 0 then
      aNameStr := GenerateGuidName;
    mPipeServer.Name := aNameStr;
  end
end;

function TCommunicationEndpointBase.GetIsOpen: Boolean;
begin
  Result := mPipeServer.IsOpen;
end;

function TCommunicationEndpointBase.GetIsClientMode: Boolean;
begin
  Result := mPipeServer.IsClientMode;
end;

function TCommunicationEndpointBase.GetIsWorking: Boolean;
begin
  Result := mPipeServer.IsWorking;
end;

function TCommunicationEndpointBase.GetBufferSize: UInt32;
begin
  Result := mPipeServer.BufferSize;
end;

procedure TCommunicationEndpointBase.SetBufferSize(aValue: UInt32);
begin
  if not GetIsOpen then
    mPipeServer.BufferSize := aValue;
end;

function TCommunicationEndpointBase.GetOnDataExchangeUsesSynchronize: Boolean;
begin
  Result := mPipeServer.OnConnectedUsesSynchronize;
end;

procedure TCommunicationEndpointBase.SetOnDataExchangeUsesSynchronize(aValue: Boolean);
begin
  mPipeServer.OnConnectedUsesSynchronize := aValue;
end;

function TCommunicationEndpointBase.GetOnClientDataSendUsesSynchronize: Boolean;
begin
  Result := mPipeServer.OnClientDataSendUsesSynchronize;
end;

procedure TCommunicationEndpointBase.SetOnClientDataSendUsesSynchronize(aValue: Boolean);
begin
  mPipeServer.OnClientDataSendUsesSynchronize := aValue;
end;

function TCommunicationEndpointBase.GetOnServerStarted: TNotifyEvent;
begin
  Result := mPipeServer.OnStarted;
end;

procedure TCommunicationEndpointBase.SetOnServerStarted(const aValue: TNotifyEvent);
begin
  mPipeServer.OnStarted := aValue;
end;

function TCommunicationEndpointBase.GetOnServerStopped: TNotifyEvent;
begin
  Result := mPipeServer.OnStopped;
end;

procedure TCommunicationEndpointBase.SetOnServerStopped(const aValue: TNotifyEvent);
begin
  mPipeServer.OnStopped := aValue;
end;

function TCommunicationEndpointBase.GetAvailableFiles: TAvailableFilesList;
begin
  mAvailableFilesLock.Acquire;
  Result := mAvailableFiles;
end;

procedure TCommunicationEndpointBase.ReleaseAvailableFiles;
begin
  mAvailableFilesLock.Release;
end;

function TCommunicationEndpointBase.GetTransferringFileName: string;
begin
  Result := string.Empty;
  if Assigned(mTransferringFile) then
    Result := mTransferringFile.FileName;
end;

function TCommunicationEndpointBase.GetTransferringFileSize: Integer;
begin
  Result := 0;
  if Assigned(mTransferringFile) then
    Result := mTransferringFile.Size;
end;

function TCommunicationEndpointBase.GetTransferringFileBytesTransferred: Integer;
begin
  Result := 0;
  if Assigned(mTransferringFile) then
    if GetTransferringFileSending then
      Result := mTransferringFile.Position
    else
      Result := mTransferringFile.Size;
end;

function TCommunicationEndpointBase.GetTransferringFileSending: Boolean;
begin
  Result := False;
  if Assigned(mTransferringFile) then
    Result := (mTransferringFileMode and fmCreate) = 0;
end;

function TCommunicationEndpointBase.CreateTransferringFile(const aFileName: string; aMode: Word): TFileStream;
begin
  FreeTransferringFile;
  mTransferringFile := TFileStream.Create(aFileName, aMode or fmShareDenyWrite);
  Result := mTransferringFile;
  mTransferringFileMode := aMode;
end;

procedure TCommunicationEndpointBase.FreeTransferringFile;
begin
  if Assigned(mTransferringFile) then
    FreeAndNil(mTransferringFile);
  mTransferringFileClient := 0;
  mTransferringFileMode := 0;
end;

function TCommunicationEndpointBase.SendClientRequest(aRequestNumber: TCommunicationEndpointRequestNumber; const aRequestStringPart: string; out aResponseNumber: TCommunicationEndpointRequestNumber; out aResponseResult: TCommunicationEndpointRequestResult; out aResponseString: string; var aResponseBodySize: UInt32; const aResponseBody: TStream; aWaitForConnectionMs: UInt32): UInt32;
var
  aResponseLen, aDataOffset: UInt32;
  aRequest, aResponse: TBytes;
begin
  aResponseNumber := REQUEST_NONE;
  aResponseResult := REQUEST_RESULT_ASK;
  aResponseString := string.Empty;
  aResponseLen := aResponseBodySize + REQUEST_STRING_PART_LENGTH_DEFAULT + SizeOf(UInt64);
  SetLength(aResponse, aResponseLen);
  aRequest := BuildRequest(aRequestNumber, REQUEST_RESULT_ASK, aRequestStringPart);
  Result := mPipeServer.SendRequest(aRequest, aResponse, aWaitForConnectionMs);
  if Result > 0 then
    ParseRequest(aResponse, aResponseNumber, aResponseResult, aResponseString, aResponseBodySize, aDataOffset, aResponseBody);
end;

function TCommunicationEndpointBase.SendClientRequestDisconnect: Boolean;
var
  aRequest: TBytes;
begin
  Result := False;
  if IsClientMode then
  begin
    aRequest := BuildRequest(REQUEST_DISCONNECT);
    Result := mPipeServer.SendRequest(aRequest);
  end
end;

function TCommunicationEndpointBase.ProcessRequest(aClientPipe: THandle; const aRequest: TBytes; var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; out aRequestNumber: TCommunicationEndpointRequestNumber; out aRequestResult: TCommunicationEndpointRequestResult; out aString: string; out aBodySize: UInt32; out aDataOffset: UInt32): Boolean;
begin
  aResponseResult := REQUEST_RESULT_ASK;
  Result := False;
  if ParseRequest(aRequest, aRequestNumber, aRequestResult, aString, aBodySize, aDataOffset) then
    case aRequestNumber of
      REQUEST_GET_PEER_INFORMATION : Result := ProcessRequestPeerInformation(aResponse, aResponseResult, aRequestResult, aString);
      REQUEST_GET_FILE_LIST : Result := ProcessRequestFileList(aResponse, aResponseResult, aRequestResult, aString);
      REQUEST_GET_FILE : Result := ProcessRequestFile(aClientPipe, aRequest, aResponse, aResponseResult, aRequestResult, aString, aBodySize);
    end
end;

function TCommunicationEndpointBase.ProcessRequestPeerInformation(var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; aRequestResult: TCommunicationEndpointRequestResult; const aRequestString: string): Boolean;
var
  aEndpointType: TCommunicationEndpointType;
  aEndpointName, aEndpointDescription, aEndpointTypeString: string;
  aFileStream: TFileStream;
begin
  aResponseResult := REQUEST_RESULT_ASK;
  Result := False;
  case aRequestResult of
    REQUEST_RESULT_ASK :
    begin
      aResponseResult := REQUEST_RESULT_SUCCESS;
      aResponse := BuildRequest(REQUEST_GET_PEER_INFORMATION, aResponseResult, BuildPeerInformationString(mEndpointType, mName, mDescription));
      Result := True;
    end;
    REQUEST_RESULT_SUCCESS :
    begin
      ParsePeerInformationString(aRequestString, aEndpointType, aEndpointName, aEndpointDescription);
      aEndpointName := Trim(aEndpointName);
      if (aEndpointName.Length > 0) and CreateDirectories then
      begin
        aFileStream := TFileStream.Create(IncludeTrailingPathDelimiter(DIRECTORY_NAME_PEERS) + aEndpointName + '.txt', fmCreate or fmShareDenyWrite);
        aEndpointName := aEndpointName + sLineBreak;
        aEndpointTypeString := COMMUNICATION_ENDPOINT_NAMES[aEndpointType] + sLineBreak;
        try
          aFileStream.WriteBuffer(UNICODE_BOM, SizeOf(UNICODE_BOM));
          aFileStream.WriteBuffer(aEndpointName[1], Length(aEndpointName) * SizeOf(Char));
          aFileStream.WriteBuffer(aEndpointTypeString[1], Length(aEndpointTypeString) * SizeOf(Char));
          if aEndpointDescription.Length > 0 then
          begin
            aEndpointDescription := aEndpointDescription + sLineBreak;
            aFileStream.WriteBuffer(aEndpointDescription[1], Length(aEndpointDescription) * SizeOf(Char));
          end;
        finally
          aFileStream.Free;
        end
      end
    end;
  end
end;

function TCommunicationEndpointBase.ProcessRequestFileList(var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; aRequestResult: TCommunicationEndpointRequestResult; const aRequestString: string): Boolean;
var
  aFileArr, aFileInf: TArray<string>;
  aCnt, aFileInfLen, i: Integer;
  aFileName: string;
  aFileSize: UInt32;
begin
  aResponseResult := REQUEST_RESULT_ASK;
  Result := False;
  case aRequestResult of
    REQUEST_RESULT_ASK :
    begin
      aResponseResult := REQUEST_RESULT_SUCCESS;
      aResponse := BuildRequest(REQUEST_GET_FILE_LIST, aResponseResult, GetFilesDirectoryContentString);
      Result := True;
    end;
    REQUEST_RESULT_SUCCESS :
    begin
      mAvailableFilesLock.Acquire;
      mAvailableFiles.Clear;
      if aRequestString.Length > 0 then
      begin
        aFileArr := aRequestString.Split([LIST_ITEM_DELIMITER]);
        aCnt := Length(aFileArr);
        for i := 0 to aCnt - 1 do
        begin
          aFileInf := aFileArr[i].Split([LIST_ITEM_SIZE_PART_DELIMITER]);
          aFileInfLen := Length(aFileInf);
          if aFileInfLen > 0 then
          begin
            aFileName := aFileInf[0];
            if aFileName.Length > 0 then
            begin
              aFileSize := 0;
              if aFileInfLen > 1 then
                aFileSize := StrToIntDef(aFileInf[1], 0);
              mAvailableFiles.Add(TAvailableFile.Create(aFileName, aFileSize));
            end
          end
        end
      end;
      mAvailableFilesLock.Release;
    end;
  end
end;

function TCommunicationEndpointBase.ProcessRequestFile(aClientPipe: THandle; const aRequest: TBytes; var aResponse: TBytes; out aResponseResult: TCommunicationEndpointRequestResult; aRequestResult: TCommunicationEndpointRequestResult; const aRequestString: string; aBodySize: UInt32): Boolean;
var
  aFileStream: TFileStream;
  aFilePath, aFileName: string;
  aFN: TCommunicationEndpointRequestNumber;
  aFR: TCommunicationEndpointRequestResult;
  aFS: string;
  aFSz, aFDS, aPartLength, aStrPartLength: UInt32;
  aFreeFileStream: Boolean;
begin
  aResponseResult := REQUEST_RESULT_ASK;
  Result := False;
  aFilePath := TransferringFileName;
  if Length(aFilePath) = 0 then
  begin
    aFilePath := IncludeTrailingPathDelimiter(DIRECTORY_NAME_FILES) + aRequestString;
    aFileName := aRequestString;
  end
  else
    aFileName := ExtractFileName(aFilePath);
  case aRequestResult of
    REQUEST_RESULT_ASK :
    if FileExists(aFilePath) and ((mTransferringFileClient = 0) or (mTransferringFileClient = aClientPipe)) then
    begin
      aFreeFileStream := True;
      aPartLength := 0;
      aResponseResult := REQUEST_RESULT_SUCCESS;
      if Assigned(mTransferringFile) then
      begin
        if not TransferringFileSending then
        begin
          if Length(aRequestString) > 0 then
          begin
            aFilePath := IncludeTrailingPathDelimiter(DIRECTORY_NAME_FILES) + aRequestString;
            aFileName := aRequestString;
          end;
          CreateTransferringFile(aFilePath, fmOpenRead);
        end;
        aFileStream := mTransferringFile;
        aPartLength := aFileStream.Size - aFileStream.Position;
        aStrPartLength := SizeOf(UInt64) + (Length(aFileName) + 1) * SizeOf(Char);
        if aPartLength > BufferSize - aStrPartLength then
        begin
          aResponseResult := REQUEST_RESULT_SUCCESS_PART;
          aPartLength := BufferSize - aStrPartLength;
          aFreeFileStream := False;
        end
        else
        begin
          mTransferringFile := nil;
          mTransferringFileClient := 0;
        end
      end
      else
      begin
        aFileStream := TFileStream.Create(aFilePath, fmOpenRead or fmShareDenyWrite);
        aStrPartLength := SizeOf(UInt64) + (Length(aFileName) + 1) * SizeOf(Char);
        if aFileStream.Size > BufferSize - aStrPartLength then
        begin
          FreeTransferringFile;
          mTransferringFile := aFileStream;
          mTransferringFileClient := aClientPipe;
          mTransferringFileMode := fmOpenRead;
          aResponseResult := REQUEST_RESULT_SUCCESS_BEGIN;
          aPartLength := BufferSize - aStrPartLength;
          aFreeFileStream := False;
        end;
      end;
      try
        aResponse := BuildRequest(REQUEST_GET_FILE, aResponseResult, aFileName, aFileStream, aPartLength);
        Result := True;
      finally
        if aFreeFileStream then
          aFileStream.Free;
      end
    end
    else
    begin
      aResponseResult := REQUEST_RESULT_FAILURE;
      aResponse := BuildRequest(REQUEST_GET_FILE, aResponseResult, aFileName);
      Result := True;
    end;
    REQUEST_RESULT_SUCCESS..REQUEST_RESULT_SUCCESS_PART :
    if (aBodySize > 0) and CreateDirectories and ((mTransferringFileClient = 0) or (mTransferringFileClient = aClientPipe)) then
    begin
      aFileStream := nil;
      aFreeFileStream := False;
      case aRequestResult of
        REQUEST_RESULT_SUCCESS:
        begin
          aFreeFileStream := True;
          if Assigned(mTransferringFile) and not TransferringFileSending then
          begin
            aFileStream := mTransferringFile;
            mTransferringFile := nil;
          end;
          FreeTransferringFile;
          if not Assigned(aFileStream) then
          begin
            if Length(aRequestString) > 0 then
            begin
              aFilePath := IncludeTrailingPathDelimiter(DIRECTORY_NAME_FILES) + aRequestString;
              aFileName := aRequestString;
            end;
            aFileStream := TFileStream.Create(aFilePath, fmCreate or fmShareDenyWrite);
          end;
        end;
        REQUEST_RESULT_SUCCESS_BEGIN:
        begin
          aFileStream := CreateTransferringFile(aFilePath, fmCreate);
          mTransferringFileClient := aClientPipe;
          aResponse := BuildRequest(REQUEST_GET_FILE);
          Result := True;
        end;
        REQUEST_RESULT_SUCCESS_PART:
        if not TransferringFileSending then
        begin
          aFileStream := mTransferringFile;
          aResponse := BuildRequest(REQUEST_GET_FILE);
          Result := True;
        end;
      end;
      if Assigned(aFileStream) then
        try
          ParseRequest(aRequest, aFN, aFR, aFS, aFSz, aFDS, aFileStream);
        finally
          if aFreeFileStream then
            aFileStream.Free;
        end
    end;
  end
end;

procedure TCommunicationEndpointBase.PipeServerConnected(Sender: TPipeServerBase; aClientPipe: THandle; aDirection: TPipeDirectionEventType; var aError: UInt32; aBytesTransferred: UInt32; const aRequest: TBytes; var aResponse: TBytes; out aDontReadAfterWrite: Boolean);
var
  aFN: TCommunicationEndpointRequestNumber;
  aFR, aRR: TCommunicationEndpointRequestResult;
  aFS: string;
  aFSz, aFDS: UInt32;
  aDoProcessRequest: Boolean;
begin
  aDontReadAfterWrite := False;
  aFN := REQUEST_NONE;
  aFR := REQUEST_RESULT_ASK;
  aFS := string.Empty;
  aFSz := 0;
  aFDS := 0;

    aDoProcessRequest := (aError = PIPE_ERROR_CONTINUE_COMMUNICATION) and (aDirection = PIPE_DIRECTION_RECEIVE);
    if aDoProcessRequest then
    begin
      ProcessRequest(aClientPipe, aRequest, aResponse, aRR, aFN, aFR, aFS, aFSz, aFDS);
      aError := PIPE_ERROR_CONTINUE_COMMUNICATION;
      aDontReadAfterWrite := IsClientMode and ((aRR = REQUEST_RESULT_SUCCESS) or (aRR = REQUEST_RESULT_FAILURE));
    end;
    if Assigned(mOnDataExchange) then
    begin
      mOnDataExchange(Self, aClientPipe, aDirection, aError, aBytesTransferred, aRequest, aResponse, aDontReadAfterWrite, aFN, aFR, aFS, aFSz, aFDS);
      if aFN <> REQUEST_NONE then
        aResponse := BuildRequest(aFN, aFR, aFS);
    end

end;

procedure TCommunicationEndpointBase.PipeServerClientDataSend(Sender: TPipeServerBase; aClientPipe: THandle; var aResponse: TBytes; out aDontReadAfterWrite: Boolean);
var
  aFN: TCommunicationEndpointRequestNumber;
  aFR: TCommunicationEndpointRequestResult;
  aFS: string;
begin
  aDontReadAfterWrite := False;
  aFN := REQUEST_NONE;
  aFR := REQUEST_RESULT_ASK;
  aFS := string.Empty;
  if Assigned(mOnClientDataSend) then
  begin
    mOnClientDataSend(Self, aResponse, aDontReadAfterWrite, aFN, aFR, aFS);
    if aFN <> REQUEST_NONE then
      aResponse := BuildRequest(aFN, aFR, aFS);
  end
end;

end.
