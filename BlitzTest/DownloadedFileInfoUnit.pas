unit DownloadedFileInfoUnit;

interface

uses
  SimpleCommunicationUnit;

type
  TDownloadedFileInfo = class(TAvailableFile)
  strict private
    function GetDownloaded: Boolean;
  public
    constructor Create(const aFileInfo: TAvailableFile); overload;

    property Downloaded: Boolean read GetDownloaded;
  end;

implementation

uses
  SysUtils, HelperUtilitiesUnit;

{ TDownloadedFileInfo }

constructor TDownloadedFileInfo.Create(const aFileInfo: TAvailableFile);
begin
  inherited Create(aFileInfo.Path, aFileInfo.Size);
end;

function TDownloadedFileInfo.GetDownloaded: Boolean;
var
  aFileSize: Int64;
begin
  Result := False;
  if Size <> 0 then
  begin
    aFileSize := GetFileSize(IncludeTrailingPathDelimiter(DIRECTORY_NAME_FILES) + Path);
    Result := (aFileSize > 0) and (aFileSize = Size);
  end;
end;

end.
