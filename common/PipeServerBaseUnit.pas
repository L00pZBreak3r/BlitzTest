unit PipeServerBaseUnit;

interface

uses
  Windows, Classes, SysUtils, SyncObjs,
  CommunicationDeviceBaseUnit;

const
  WAIT_FOR_CONNECTION_MS_DEFAULT = 2000;
  PIPE_NAME_PREFIX = '\\.\pipe\';
  PIPE_INSTANCES_MAX = 4;
  PIPE_ERROR_CONTINUE_COMMUNICATION = 0;

type
  TPipeServerBase = class;
  TPipeDirectionEventType = (PIPE_DIRECTION_CONNECT, PIPE_DIRECTION_SEND, PIPE_DIRECTION_RECEIVE);
  TPipeConnectedEvent = procedure(Sender: TPipeServerBase; aClientPipe: THandle; aDirection: TPipeDirectionEventType; var aError: UInt32; aBytesTransferred: UInt32; const aRequest: TBytes; var aResponse: TBytes; out aDontReadAfterWrite: Boolean) of object;
  TPipeClientDataSendEvent = procedure(Sender: TPipeServerBase; aClientPipe: THandle; var aResponse: TBytes; out aDontReadAfterWrite: Boolean) of object;

  TPipeServerOverlappedModeState = (OVERLAPPED_IO_MODE_CONNECTING_STATE, OVERLAPPED_IO_MODE_READING_STATE, OVERLAPPED_IO_MODE_WRITING_STATE);

  TPipeInstanceInfo = record
    mOverlap: TOverlapped;
    mPipeInst: THandle;
    mRequest: TBytes;
    mResponse: TBytes;
    mBytesRead: UInt32;
    mBytesToWrite: UInt32;
    mState: TPipeServerOverlappedModeState;
    mPendingIO: Boolean;
    mDontReadAfterWrite: Boolean;
  end;

  TPipeInstancesArray = array [0 .. PIPE_INSTANCES_MAX - 1] of TPipeInstanceInfo;

  TPipeServerBase = class(TCommunicationDeviceBase)
  strict private
    [volatile] mIsWorking: Boolean;
    mClientsLock: TCriticalSection;
    mServerThread: TThread;
    mPipeInstances: TPipeInstancesArray;
    mStopServerEvent: TEvent;

    mOnConnected: TPipeConnectedEvent;
    mOnClientDataSend: TPipeClientDataSendEvent;
    mOnStarted, mOnStopped: TNotifyEvent;

    class function GetPipeBytesAvailable(aPipeHandle: THandle): UInt32; static;

    function ProcessRequest(aPipeIndex: Integer; aDirection: TPipeDirectionEventType; const aCallerThread: TThread = nil): Boolean;
    function ClosePipe: Boolean;
    procedure mServerThreadTerminated(Sender: TObject);
  private
    [volatile] mCanWork: Boolean;

    function RunServer(const aCallerThread: TThread = nil): Integer;
    function RunClient(const aCallerThread: TThread = nil): Integer;
  public
    OnConnectedUsesSynchronize, OnClientDataSendUsesSynchronize: Boolean;
    WaitForConnectionMs: UInt32;

    constructor Create(const aName: string; aBufferSizeDefault: UInt32 = 0);

    function Open(aOpenExisting: Boolean): Boolean; override;
    function Close: Boolean; override;
    function Start: Boolean;
    function Stop: Integer;

    function SendRequest(aRequest: PByte; aRequestSize: UInt32; aBuffer: PByte; var aBufferSize: UInt32; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): UInt32; overload;
    function SendRequest(const aRequest: TBytes; aRequestSize: UInt32; var aBuffer: TBytes; out aBufferSize: UInt32; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): UInt32; overload;
    function SendRequest(const aRequest: TBytes; var aBuffer: TBytes; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): UInt32; overload;

    function SendRequest(aMessage: PByte; aMessageSize: UInt32; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): Boolean; overload;
    function SendRequest(const aMessage: TBytes; aMessageSize: UInt32; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): Boolean; overload;
    function SendRequest(const aMessage: TBytes; aWaitForConnectionMs: UInt32 = WAIT_FOR_CONNECTION_MS_DEFAULT): Boolean; overload;

    property IsWorking: Boolean read mIsWorking;
    property OnConnected: TPipeConnectedEvent read mOnConnected write mOnConnected;
    property OnClientDataSend: TPipeClientDataSendEvent read mOnClientDataSend write mOnClientDataSend;
    property OnStarted: TNotifyEvent read mOnStarted write mOnStarted;
    property OnStopped: TNotifyEvent read mOnStopped write mOnStopped;
  end;

implementation

const
  PIPE_TIMEOUT = 5000;
  SERVER_PIPE_MAXIMUM_INSTANCES = 16; //PIPE_UNLIMITED_INSTANCES;

type
  TPipeClientHandlerThreadAction = (THREAD_ACTION_RUN_SERVER, THREAD_ACTION_RUN_CLIENT);

  TPipeClientHandlerThread = class(TThread)
  strict private
    mPipeServerBase: TPipeServerBase;
    mAction: TPipeClientHandlerThreadAction;
    mPipeHandle: THandle;

  protected
    constructor Create(const aPipeServerBase: TPipeServerBase; aAction: TPipeClientHandlerThreadAction; aPipeHandle: THandle = 0);
    procedure Execute; override;    
  end;

{ TPipeClientHandlerThread }

constructor TPipeClientHandlerThread.Create(const aPipeServerBase: TPipeServerBase; aAction: TPipeClientHandlerThreadAction; aPipeHandle: THandle);
begin
  mPipeServerBase := aPipeServerBase;
  mAction := aAction;
  mPipeHandle := aPipeHandle;
  inherited Create(False);
end;

procedure TPipeClientHandlerThread.Execute;
begin
  if not Terminated and mPipeServerBase.mCanWork then
  case mAction of
    THREAD_ACTION_RUN_SERVER : ReturnValue := mPipeServerBase.RunServer(Self);
    THREAD_ACTION_RUN_CLIENT : ReturnValue := mPipeServerBase.RunClient(Self);
  end
end;

{ TPipeServerBase }

constructor TPipeServerBase.Create(const aName: string; aBufferSizeDefault: UInt32);
begin
  inherited Create(aName, aBufferSizeDefault);
  mClientsLock := TCriticalSection.Create;
end;

function TPipeServerBase.Open(aOpenExisting: Boolean): Boolean;
begin
  Close;
  mClientsLock := TCriticalSection.Create;
  if aOpenExisting then
  begin
    mIsClientMode := mName.Length > 0;
    Result := mIsClientMode;
  end
  else
  begin
    Result := True;
  end;
end;

function TPipeServerBase.Close: Boolean;
begin
  Stop;
  Result := inherited Close;
  FreeAndNil(mClientsLock);
end;

function TPipeServerBase.ClosePipe: Boolean;
begin
  Result := CloseDevice;
end;

class function TPipeServerBase.GetPipeBytesAvailable(aPipeHandle: THandle): UInt32;
begin
  Result := 0;
  if (aPipeHandle <> 0) and (aPipeHandle <> INVALID_HANDLE_VALUE) and not PeekNamedPipe(aPipeHandle, nil, 0, nil, @Result, nil) then
    Result := 0;
end;

function TPipeServerBase.RunServer(const aCallerThread: TThread): Integer;
var
  aName: PChar;
  i: Integer;
  aError, aWritten: UInt32;
  aOpResult: Boolean;
  aPipeEvents: TWOHandleArray;

  function ConnectToNewClient(aPipeIndex: Integer): Boolean;
  var
    aConnected, aPendingIO: Boolean;
    aPipe: THandle;
    aOvelap: POverlapped;
  begin
    Result := False;
    aPendingIO := False;
    aPipe := mPipeInstances[aPipeIndex].mPipeInst;
    aOvelap := @mPipeInstances[aPipeIndex].mOverlap;
    aConnected := ConnectNamedPipe(aPipe, aOvelap);

    if not aConnected then
      case GetLastError of
        ERROR_IO_PENDING : begin aPendingIO := True; Result := True; end;
        ERROR_PIPE_CONNECTED : Result := SetEvent(aOvelap^.hEvent);
      end;
    mPipeInstances[aPipeIndex].mPendingIO := aPendingIO;
    if mPipeInstances[aPipeIndex].mPendingIO then
      mPipeInstances[aPipeIndex].mState := OVERLAPPED_IO_MODE_CONNECTING_STATE
    else
      mPipeInstances[aPipeIndex].mState := OVERLAPPED_IO_MODE_READING_STATE
  end;

  function DisconnectAndReconnect(aPipeIndex: Integer): Boolean;
  begin
    Result := DisconnectNamedPipe(mPipeInstances[aPipeIndex].mPipeInst);
    ConnectToNewClient(aPipeIndex);
  end;

begin
  Result := 0;
  if mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) and not mIsWorking and not mIsClientMode and not GetIsOpen and (mName.Length > 0) and Assigned(mOnConnected) then
  begin
    aName := PChar(PIPE_NAME_PREFIX + mName);
    mIsWorking := True;
      for i := 0 to Length(mPipeInstances) - 1 do
      begin


        aPipeEvents[i] := CreateEvent(
          nil,
          True,
          True,
          nil);

        if aPipeEvents[i] = 0 then
          break;

        mPipeInstances[i].mOverlap.hEvent := aPipeEvents[i];

        mPipeInstances[i].mPipeInst := CreateNamedPipe(
          aName,
          PIPE_ACCESS_DUPLEX or
          FILE_FLAG_OVERLAPPED,
          PIPE_TYPE_MESSAGE or
          PIPE_READMODE_MESSAGE or
          PIPE_WAIT,
          Length(mPipeInstances),
          mBufferSize,
          mBufferSize,
          PIPE_TIMEOUT,
          nil);

        if (mPipeInstances[i].mPipeInst = 0) or (mPipeInstances[i].mPipeInst = INVALID_HANDLE_VALUE) then
          break;

        SetLength(mPipeInstances[i].mRequest, mBufferSize);
        SetLength(mPipeInstances[i].mResponse, 0);
        mPipeInstances[i].mBytesRead := 0;
        mPipeInstances[i].mBytesToWrite := 0;
        mPipeInstances[i].mDontReadAfterWrite := False;

        ConnectToNewClient(i);
        Inc(Result);
      end;

      mClientsLock.Acquire;
      if Assigned(mStopServerEvent) then
        mStopServerEvent.ResetEvent
      else
        mStopServerEvent := TEvent.Create;
      aPipeEvents[Result] := mStopServerEvent.Handle;
      mClientsLock.Release;

      if Result = Length(mPipeInstances) then
      while mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) do
      begin
        aWritten := WaitForMultipleObjects(
          Result + 1,
          @aPipeEvents,
          False,
          INFINITE);

        i := aWritten - WAIT_OBJECT_0;
        if (i < 0) or (i >= Result) then
          break;
        aWritten := 0;
        if mPipeInstances[i].mPendingIO then
        begin
          aOpResult := GetOverlappedResult(
            mPipeInstances[i].mPipeInst,
            mPipeInstances[i].mOverlap,
            aWritten,
            False);

          case mPipeInstances[i].mState of
            OVERLAPPED_IO_MODE_CONNECTING_STATE:
            begin
              mPipeInstances[i].mState := OVERLAPPED_IO_MODE_READING_STATE;
              if not (aOpResult and ProcessRequest(i, PIPE_DIRECTION_CONNECT, aCallerThread)) then
                break;
            end;

            OVERLAPPED_IO_MODE_READING_STATE:
            begin
              if not aOpResult or (aWritten = 0) then
              begin
                DisconnectAndReconnect(i);
                continue;
              end;
              mPipeInstances[i].mBytesRead := aWritten;
              mPipeInstances[i].mState := OVERLAPPED_IO_MODE_WRITING_STATE;
              if not ProcessRequest(i, PIPE_DIRECTION_RECEIVE, aCallerThread) then
                break;
            end;

            OVERLAPPED_IO_MODE_WRITING_STATE:
            begin
              if not aOpResult or (aWritten <> mPipeInstances[i].mBytesToWrite) then
              begin
                DisconnectAndReconnect(i);
                continue;
              end;
              if mPipeInstances[i].mDontReadAfterWrite then
                mPipeInstances[i].mDontReadAfterWrite := False
              else
                mPipeInstances[i].mState := OVERLAPPED_IO_MODE_READING_STATE;
              if mPipeInstances[i].mBytesToWrite > 0 then
              begin
                if not ProcessRequest(i, PIPE_DIRECTION_SEND, aCallerThread) then
                  break;
                SetLength(mPipeInstances[i].mResponse, 0);;
                mPipeInstances[i].mBytesToWrite := 0;
              end;
            end;
            else
              break;
          end
        end;


        case mPipeInstances[i].mState of

          OVERLAPPED_IO_MODE_READING_STATE:
          begin
            aWritten := GetPipeBytesAvailable(mPipeInstances[i].mPipeInst);
            if aWritten < mBufferSize then
              aWritten := mBufferSize;
            SetLength(mPipeInstances[i].mRequest, aWritten);
            aOpResult := ReadFile(
              mPipeInstances[i].mPipeInst,
              mPipeInstances[i].mRequest[0],
              Length(mPipeInstances[i].mRequest),
              mPipeInstances[i].mBytesRead,
              @mPipeInstances[i].mOverlap);
            aError := GetLastError;

            if aOpResult and (mPipeInstances[i].mBytesRead > 0) then
            begin
              mPipeInstances[i].mPendingIO := False;
              mPipeInstances[i].mState := OVERLAPPED_IO_MODE_WRITING_STATE;
              if not ProcessRequest(i, PIPE_DIRECTION_RECEIVE, aCallerThread) then
                break;
              continue;
            end;

            if not aOpResult and (aError = ERROR_IO_PENDING) then
            begin
              mPipeInstances[i].mPendingIO := True;
              continue;
            end;

            DisconnectAndReconnect(i);
          end;

          OVERLAPPED_IO_MODE_WRITING_STATE:
          begin
            aOpResult := True;
            aError := 0;
            aWritten := 0;
            if mPipeInstances[i].mBytesToWrite > 0 then
            begin
              aOpResult := WriteFile(
                mPipeInstances[i].mPipeInst,
                mPipeInstances[i].mResponse[0],
                mPipeInstances[i].mBytesToWrite,
                aWritten,
                @mPipeInstances[i].mOverlap);
              aError := GetLastError;
            end;

            if aOpResult and (aWritten = mPipeInstances[i].mBytesToWrite) then
            begin
              mPipeInstances[i].mPendingIO := False;
              if mPipeInstances[i].mDontReadAfterWrite then
                mPipeInstances[i].mDontReadAfterWrite := False
              else
                mPipeInstances[i].mState := OVERLAPPED_IO_MODE_READING_STATE;
              if mPipeInstances[i].mBytesToWrite > 0 then
              begin
                if not ProcessRequest(i, PIPE_DIRECTION_SEND, aCallerThread) then
                  break;
                SetLength(mPipeInstances[i].mResponse, 0);;
                mPipeInstances[i].mBytesToWrite := 0;
              end;
              continue;
            end;


            if not aOpResult and (aError = ERROR_IO_PENDING) then
            begin
              mPipeInstances[i].mPendingIO := True;
              continue;
            end;

            DisconnectAndReconnect(i);
          end;

          else
            break;
        end
      end;
      for i := 0 to Length(mPipeInstances) - 1 do
        if (mPipeInstances[i].mPipeInst <> 0) and (mPipeInstances[i].mPipeInst <> INVALID_HANDLE_VALUE) then
        begin
          FlushFileBuffers(mPipeInstances[i].mPipeInst);
          DisconnectNamedPipe(mPipeInstances[i].mPipeInst);
          CloseHandle(mPipeInstances[i].mPipeInst);
          CloseHandle(mPipeInstances[i].mOverlap.hEvent);
          mPipeInstances[i].mPipeInst := 0;
          mPipeInstances[i].mOverlap.hEvent := 0;
        end;
    mIsWorking := False;
  end;
end;

function TPipeServerBase.RunClient(const aCallerThread: TThread): Integer;

  procedure ReadAll;
  var
    aBuf: TBytes;
    aBufLen: Integer;
    aBytesRead: UInt32;
  begin
    if GetIsOpen then
    begin
      aBytesRead := GetPipeBytesAvailable(mDeviceHandle);
      if aBytesRead > 0 then
      begin
        SetLength(aBuf, aBytesRead);
        aBufLen := Length(aBuf);
        repeat
          aBytesRead := 0;
          ReadFile(
            mDeviceHandle,
            aBuf[0],
            aBufLen,
            aBytesRead,
            nil);
        until GetLastError <> ERROR_MORE_DATA;
      end
    end
  end;

var
  aName: PChar;
  i: Integer;
  aError, aWritten: UInt32;
  aOpResult, aMoreData: Boolean;
  aPipeEventHandle: THandle;
  aPipeEvents: TWOHandleArray;
begin
  Result := 0;
  if mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) and not mIsWorking and mIsClientMode and not GetIsOpen and (mName.Length > 0) and Assigned(mOnConnected) and Assigned(mOnClientDataSend) then
  begin
    aName := PChar(PIPE_NAME_PREFIX + mName);
    mIsWorking := True;
      mClientsLock.Acquire;
      if Assigned(mStopServerEvent) then
        mStopServerEvent.ResetEvent
      else
        mStopServerEvent := TEvent.Create;
      aPipeEvents[1] := mStopServerEvent.Handle;
      mClientsLock.Release;
      aPipeEventHandle := CreateEvent(
          nil,
          True,
          True,
          nil);

      if aPipeEventHandle <> 0 then
      begin
        aPipeEvents[0] := aPipeEventHandle;
        mPipeInstances[0].mOverlap.hEvent := aPipeEventHandle;
        aMoreData := True;
        while aMoreData and mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) do
        begin
          ReadAll;
          ClosePipe;
          repeat
            mDeviceHandle := CreateFile(
               aName,
               GENERIC_READ or
               GENERIC_WRITE,
               0,
               nil,
               OPEN_EXISTING,
               FILE_FLAG_OVERLAPPED,
               0);
            if GetIsOpen then
              break;
            aError := GetLastError;
            if (aError <> ERROR_PIPE_BUSY) or not WaitNamedPipe(aName, WaitForConnectionMs) then
            begin
              aMoreData := False;
              break;
            end;
          until not mCanWork or (Assigned(aCallerThread) and aCallerThread.CheckTerminated);

          if aMoreData and GetIsOpen and mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) then
          begin
            aWritten := PIPE_READMODE_MESSAGE;
            if SetNamedPipeHandleState(
              mDeviceHandle,
              aWritten,
              nil,
              nil)
            then
            begin
              i := 0;
              mPipeInstances[i].mPipeInst := mDeviceHandle;
              SetLength(mPipeInstances[i].mRequest, mBufferSize);
              SetLength(mPipeInstances[i].mResponse, 0);
              mPipeInstances[i].mBytesRead := 0;
              mPipeInstances[i].mBytesToWrite := 0;
              mPipeInstances[i].mDontReadAfterWrite := False;

              mPipeInstances[i].mPendingIO := False;
              mPipeInstances[i].mState := OVERLAPPED_IO_MODE_WRITING_STATE;

              if not ProcessRequest(i, PIPE_DIRECTION_CONNECT, aCallerThread) then
                aMoreData := False
              else
              while mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated) do
              begin
              aWritten := WaitForMultipleObjects(
                2,
                @aPipeEvents,
                False,
                INFINITE);

              i := aWritten - WAIT_OBJECT_0;
              if (i < 0) or (i >= 1) then
              begin
                aMoreData := False;
                break;
              end;

              aWritten := 0;
              if mPipeInstances[i].mPendingIO then
              begin
                aOpResult := GetOverlappedResult(
                  mPipeInstances[i].mPipeInst,
                  mPipeInstances[i].mOverlap,
                  aWritten,
                  False);

                case mPipeInstances[i].mState of
                  OVERLAPPED_IO_MODE_READING_STATE:
                  begin
                    if not aOpResult or (aWritten = 0) then
                      continue;

                    mPipeInstances[i].mBytesRead := aWritten;
                    mPipeInstances[i].mState := OVERLAPPED_IO_MODE_WRITING_STATE;
                    if not ProcessRequest(i, PIPE_DIRECTION_RECEIVE, aCallerThread) then
                    begin
                      aMoreData := False;
                      break;
                    end;
                  end;

                  OVERLAPPED_IO_MODE_WRITING_STATE:
                  begin
                    if not aOpResult or (aWritten <> mPipeInstances[i].mBytesToWrite) then
                      continue;

                    if mPipeInstances[i].mDontReadAfterWrite then
                      mPipeInstances[i].mDontReadAfterWrite := False
                    else
                      mPipeInstances[i].mState := OVERLAPPED_IO_MODE_READING_STATE;
                    if mPipeInstances[i].mBytesToWrite > 0 then
                    begin
                      if not ProcessRequest(i, PIPE_DIRECTION_SEND, aCallerThread) then
                      begin
                        aMoreData := False;
                        break;
                      end;
                      SetLength(mPipeInstances[i].mResponse, 0);;
                      mPipeInstances[i].mBytesToWrite := 0;
                    end;
                  end;
                  else
                  begin
                    aMoreData := False;
                    break;
                  end
                end
              end;

              case mPipeInstances[i].mState of
                OVERLAPPED_IO_MODE_READING_STATE:
                begin
                  aWritten := GetPipeBytesAvailable(mPipeInstances[i].mPipeInst);
                  if aWritten < mBufferSize then
                    aWritten := mBufferSize;
                  SetLength(mPipeInstances[i].mRequest, aWritten);
                  aOpResult := ReadFile(
                    mPipeInstances[i].mPipeInst,
                    mPipeInstances[i].mRequest[0],
                    Length(mPipeInstances[i].mRequest),
                    mPipeInstances[i].mBytesRead,
                    @mPipeInstances[i].mOverlap);
                  aError := GetLastError;

                  if aOpResult and (mPipeInstances[i].mBytesRead > 0) then
                  begin
                    mPipeInstances[i].mPendingIO := False;
                    mPipeInstances[i].mState := OVERLAPPED_IO_MODE_WRITING_STATE;
                    if not ProcessRequest(i, PIPE_DIRECTION_RECEIVE, aCallerThread) then
                    begin
                      aMoreData := False;
                      break;
                    end;
                    continue;
                  end;

                  if not aOpResult and (aError = ERROR_IO_PENDING) then
                  begin
                    mPipeInstances[i].mPendingIO := True;
                    continue;
                  end;

                end;

                OVERLAPPED_IO_MODE_WRITING_STATE:
                begin
                  if mPipeInstances[i].mBytesToWrite = 0 then
                  begin
                    SetLength(mPipeInstances[i].mResponse, 0);
                    if Assigned(aCallerThread) and OnClientDataSendUsesSynchronize then
                      TThread.Synchronize(aCallerThread,  procedure
                                                          begin
                                                            mOnClientDataSend(Self, mPipeInstances[i].mPipeInst, mPipeInstances[i].mResponse, mPipeInstances[i].mDontReadAfterWrite)
                                                          end)
                    else
                      mOnClientDataSend(Self, mPipeInstances[i].mPipeInst, mPipeInstances[i].mResponse, mPipeInstances[i].mDontReadAfterWrite);
                    mPipeInstances[i].mBytesToWrite := Length(mPipeInstances[i].mResponse);
                  end;
                  aOpResult := True;
                  aError := 0;
                  aWritten := 0;
                  if mPipeInstances[i].mBytesToWrite > 0 then
                  begin
                    aOpResult := WriteFile(
                      mPipeInstances[i].mPipeInst,
                      mPipeInstances[i].mResponse[0],
                      mPipeInstances[i].mBytesToWrite,
                      aWritten,
                      @mPipeInstances[i].mOverlap);
                    aError := GetLastError;
                  end;

                  if aOpResult and (aWritten = mPipeInstances[i].mBytesToWrite) then
                  begin
                    mPipeInstances[i].mPendingIO := False;
                    if mPipeInstances[i].mDontReadAfterWrite then
                      mPipeInstances[i].mDontReadAfterWrite := False
                    else
                      mPipeInstances[i].mState := OVERLAPPED_IO_MODE_READING_STATE;
                    if mPipeInstances[i].mBytesToWrite > 0 then
                    begin
                      if not ProcessRequest(i, PIPE_DIRECTION_SEND, aCallerThread) then
                      begin
                        aMoreData := False;
                        break;
                      end;
                      SetLength(mPipeInstances[i].mResponse, 0);;
                      mPipeInstances[i].mBytesToWrite := 0;
                    end;
                    continue;
                  end;

                  if not aOpResult and (aError = ERROR_IO_PENDING) then
                  begin
                    mPipeInstances[i].mPendingIO := True;
                    continue;
                  end;

                end;

                else
                begin
                  aMoreData := False;
                  break;
                end
              end
              end
            end
          end
        end;

        CloseHandle(aPipeEventHandle);
      end;
    ReadAll;
    ClosePipe;
    mIsWorking := False;
  end;
end;

function TPipeServerBase.SendRequest(aRequest: PByte; aRequestSize: UInt32; aBuffer: PByte; var aBufferSize: UInt32; aWaitForConnectionMs: UInt32): UInt32;
begin
  Result := 0;
  if (mName.Length > 0) and Assigned(aRequest) and (aRequestSize > 0) and Assigned(aBuffer) and (aBufferSize > 0) then
  begin
    if CallNamedPipe(
      PChar(PIPE_NAME_PREFIX + mName),
      aRequest,
      aRequestSize,
      aBuffer,
      aBufferSize,
      aBufferSize,
      aWaitForConnectionMs)
    then
      Result := 1
    else if GetLastError = ERROR_MORE_DATA then
      Result := 2;
  end;
end;

function TPipeServerBase.SendRequest(const aRequest: TBytes; aRequestSize: UInt32; var aBuffer: TBytes; out aBufferSize: UInt32; aWaitForConnectionMs: UInt32): UInt32;
var
  aReqLen: UInt32;
begin
  Result := 0;
  if mName.Length > 0 then
  begin
    aBufferSize := Length(aBuffer);
    if aBufferSize = 0 then
    begin
      aBufferSize := 1;
      SetLength(aBuffer, aBufferSize);
    end;
    aReqLen := Length(aRequest);
    if (aRequestSize = 0) or (aRequestSize > aReqLen) then
      aRequestSize := aReqLen;
    if aRequestSize > 0 then
      Result := SendRequest(@aRequest[0], aRequestSize, @aBuffer[0], aBufferSize, aWaitForConnectionMs);
  end
end;

function TPipeServerBase.SendRequest(const aRequest: TBytes; var aBuffer: TBytes; aWaitForConnectionMs: UInt32): UInt32;
var
  aReceived: UInt32;
begin
  Result := SendRequest(aRequest, 0, aBuffer, aReceived, aWaitForConnectionMs);
  if aReceived < Length(aBuffer) then
    SetLength(aBuffer, aReceived);
end;

function TPipeServerBase.SendRequest(aMessage: PByte; aMessageSize: UInt32; aWaitForConnectionMs: UInt32): Boolean;
var
  aName: PChar;
  aPipeHandle: THandle;
  aWritten, aOffset: UInt32;
  aReqLen: Integer;
begin
  Result := False;
  if mName.Length > 0 then
  begin
    aName := PChar(PIPE_NAME_PREFIX + mName);
    aPipeHandle := INVALID_HANDLE_VALUE;
    while aPipeHandle = INVALID_HANDLE_VALUE do
    begin
      aPipeHandle := CreateFile(
         aName,
         GENERIC_WRITE,
         0,
         nil,
         OPEN_EXISTING,
         0,
         0);
      if (aPipeHandle <> 0) and (aPipeHandle <> INVALID_HANDLE_VALUE) then
        break;
      if (GetLastError <> ERROR_PIPE_BUSY) or not WaitNamedPipe(aName, aWaitForConnectionMs) then
      begin
        CloseHandle(aPipeHandle);
        exit;
      end;
    end;

    if (aPipeHandle <> 0) and (aPipeHandle <> INVALID_HANDLE_VALUE) then
    begin
      Result := True;
      if Assigned(aMessage) and (aMessageSize > 0) then
      begin
        aReqLen := aMessageSize;
        aWritten := 0;
        aOffset := 0;
        while (aReqLen > 0) and WriteFile(
          aPipeHandle,
          aMessage[aOffset],
          aReqLen,
          aWritten,
          nil) do
        begin
          Dec(aReqLen, aWritten);
          Inc(aOffset, aWritten);
        end
      end;
      CloseHandle(aPipeHandle);
    end
  end;
end;

function TPipeServerBase.SendRequest(const aMessage: TBytes; aMessageSize: UInt32; aWaitForConnectionMs: UInt32): Boolean;
var
  aReqLen: UInt32;
begin
  Result := False;
  if mName.Length > 0 then
  begin
    aReqLen := Length(aMessage);
    if (aMessageSize = 0) or (aMessageSize > aReqLen) then
      aMessageSize := aReqLen;
    if aMessageSize > 0 then
      Result := SendRequest(@aMessage[0], aMessageSize, aWaitForConnectionMs);
  end
end;

function TPipeServerBase.SendRequest(const aMessage: TBytes; aWaitForConnectionMs: UInt32): Boolean;
begin
  Result := SendRequest(aMessage, 0, aWaitForConnectionMs);
end;

function TPipeServerBase.Start: Boolean;
var
  aAction: TPipeClientHandlerThreadAction;
begin
  Result := False;
  if not mIsWorking and not Assigned(mServerThread) then
  begin
    mCanWork := True;
    if mIsClientMode then
      aAction := THREAD_ACTION_RUN_CLIENT
    else
    begin
      aAction := THREAD_ACTION_RUN_SERVER;
    end;
    mServerThread := TPipeClientHandlerThread.Create(Self, aAction);
    mServerThread.OnTerminate := mServerThreadTerminated;
    Result := True;
    if Assigned(mOnStarted) then
      mOnStarted(Self);
  end;
end;

function TPipeServerBase.Stop: Integer;
begin
  mCanWork := False;
  mClientsLock.Acquire;
  if Assigned(mStopServerEvent) then
    mStopServerEvent.SetEvent;
  mClientsLock.Release;
  Result := -1;
  if Assigned(mServerThread) then
  begin
    Result := mServerThread.WaitFor;
    FreeAndNil(mServerThread);
  end;
  mClientsLock.Acquire;
  if Assigned(mStopServerEvent) then
    FreeAndNil(mStopServerEvent);
  mClientsLock.Release;
  mIsWorking := False;
end;

procedure TPipeServerBase.mServerThreadTerminated(Sender: TObject);
begin
  if Assigned(mOnStopped) then
    mOnStopped(Self);
end;

function TPipeServerBase.ProcessRequest(aPipeIndex: Integer; aDirection: TPipeDirectionEventType; const aCallerThread: TThread): Boolean;
var
  aClientPipeHandle: THandle;
  aError: UInt32;
  aResp: TBytes;
begin
  Result := False;
  if Assigned(mOnConnected) and (aPipeIndex >= 0) and (aPipeIndex < Length(mPipeInstances)) then
  begin
    aClientPipeHandle := mPipeInstances[aPipeIndex].mPipeInst;
    SetLength(aResp, 0);
    aError := PIPE_ERROR_CONTINUE_COMMUNICATION;
    if Assigned(aCallerThread) and OnConnectedUsesSynchronize then
      TThread.Synchronize(aCallerThread,  procedure
                                          begin
                                            if aDirection = PIPE_DIRECTION_SEND then
                                              mOnConnected(Self, aClientPipeHandle, aDirection, aError, mPipeInstances[aPipeIndex].mBytesToWrite, mPipeInstances[aPipeIndex].mResponse, aResp, mPipeInstances[aPipeIndex].mDontReadAfterWrite)
                                            else
                                              mOnConnected(Self, aClientPipeHandle, aDirection, aError, mPipeInstances[aPipeIndex].mBytesRead, mPipeInstances[aPipeIndex].mRequest, mPipeInstances[aPipeIndex].mResponse, mPipeInstances[aPipeIndex].mDontReadAfterWrite)
                                          end)
    else if aDirection = PIPE_DIRECTION_SEND then
      mOnConnected(Self, aClientPipeHandle, aDirection, aError, mPipeInstances[aPipeIndex].mBytesToWrite, mPipeInstances[aPipeIndex].mResponse, aResp, mPipeInstances[aPipeIndex].mDontReadAfterWrite)
    else
      mOnConnected(Self, aClientPipeHandle, aDirection, aError, mPipeInstances[aPipeIndex].mBytesRead, mPipeInstances[aPipeIndex].mRequest, mPipeInstances[aPipeIndex].mResponse, mPipeInstances[aPipeIndex].mDontReadAfterWrite);

    mPipeInstances[aPipeIndex].mBytesToWrite := Length(mPipeInstances[aPipeIndex].mResponse);
    Result := (aError = PIPE_ERROR_CONTINUE_COMMUNICATION) and mCanWork and not (Assigned(aCallerThread) and aCallerThread.CheckTerminated);
  end
end;

end.
