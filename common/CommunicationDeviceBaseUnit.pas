unit CommunicationDeviceBaseUnit;

interface

uses
  Windows;

type
  TCommunicationDeviceBase = class abstract
  strict protected
    mDeviceHandle: THandle;
    mName: string;
    mBufferSize, mBufferSizeDefault: UInt32;
    mIsClientMode: Boolean;

    function CloseDevice: Boolean;

    function GetIsOpen: Boolean; virtual;
    procedure SetName(const aValue: string); virtual;
    procedure SetBufferSize(aValue: UInt32); virtual;

  public
    constructor Create(const aName: string; aBufferSizeDefault: UInt32);
    destructor Destroy; override;

    function Open(aOpenExisting: Boolean): Boolean; overload; virtual; abstract;
    function Close: Boolean; virtual;

    property Name: string read mName write SetName;
    property IsOpen: Boolean read GetIsOpen;
    property BufferSize: UInt32 read mBufferSize write SetBufferSize;
    property IsClientMode: Boolean read mIsClientMode;
  end;


implementation

const
  BUFFER_SIZE_DEFAULT = 2 * 1024;
  BUFFER_SIZE_MINIMAL = 1024;

constructor TCommunicationDeviceBase.Create(const aName: string; aBufferSizeDefault: UInt32);
begin
  mName := aName;
  if aBufferSizeDefault = 0 then
    aBufferSizeDefault := BUFFER_SIZE_DEFAULT
  else if aBufferSizeDefault < BUFFER_SIZE_MINIMAL then
    aBufferSizeDefault := BUFFER_SIZE_MINIMAL;
  mBufferSizeDefault := aBufferSizeDefault;
  mBufferSize := mBufferSizeDefault;
end;

destructor TCommunicationDeviceBase.Destroy;
begin
  Close;
  inherited
end;

function TCommunicationDeviceBase.CloseDevice: Boolean;
begin
  if (mDeviceHandle <> 0) and (mDeviceHandle <> INVALID_HANDLE_VALUE) then
    Result := CloseHandle(mDeviceHandle)
  else
    Result := True;
  mDeviceHandle := 0;
end;

function TCommunicationDeviceBase.Close: Boolean;
begin
  Result := CloseDevice;
  mIsClientMode := False;
end;

procedure TCommunicationDeviceBase.SetName(const aValue: string);
begin
  if not GetIsOpen then
    mName := aValue;
end;

function TCommunicationDeviceBase.GetIsOpen: Boolean;
begin
  Result := (mDeviceHandle <> 0) and (mDeviceHandle <> INVALID_HANDLE_VALUE);
end;

procedure TCommunicationDeviceBase.SetBufferSize(aValue: UInt32);
begin
  if not GetIsOpen then
  begin
    if aValue = 0 then
      aValue := mBufferSizeDefault;
    mBufferSize := aValue;
  end;
end;

end.
