unit HelperUtilitiesUnit;

interface

const
  UNICODE_BOM: Word = $FEFF;


function GenerateGuidString(const aGuidStringDefault: string = ''): string;
function GetFileSize(const aFilename: string): Int64;

function StrChrNW(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall;
function StrChrNA(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall;
function StrChrNB(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall;

{$IF Defined(CPUX86) or Defined(CPUX64)}
function BitScanReverseWrapper(x: UInt32): UInt32;
{$ENDIF}

implementation

uses
  Windows, SysUtils;

function GenerateGuidString(const aGuidStringDefault: string): string;
var
  aGuid: TGUID;
begin
  if CreateGUID(aGuid) <> 0 then
    Result := aGuidStringDefault
  else
    Result := GUIDToString(aGuid)
end;

{$IF Defined(CPUX86) or Defined(CPUX64)}
function BitScanReverseWrapper(x: UInt32): UInt32;
asm
{$IF Defined(CPUX64)}
  MOV     EAX,ECX
{$ENDIF}
  BSR     EAX,EAX
end;
{$ENDIF}

function StrChrNW(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall; external 'shlwapi.dll' name 'StrChrNW';

function StrChrNA(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall;
var
  aByte: Byte;
  i: Integer;
begin
  Result := nil;
  aByte := Ord(wMatch);
  for i := 0 to cchMax - 1 do
  begin 
    if pszStart^ = 0 then
      break;
    if pszStart^ = aByte then
    begin
      Result := pszStart;
      break;
    end; 
    Inc(pszStart);
  end;
end;

function StrChrNB(pszStart: PByte; wMatch: Char; cchMax: UInt32): PByte; stdcall;
var
  aW: Word;
  i: Integer;
  aPW: PWord;
begin
  Result := nil;
  aW := Word(wMatch);
  aW := Swap(aW);
  aPW := PWord(pszStart);
  for i := 0 to cchMax - 1 do
  begin 
    if aPW^ = 0 then
      break;
    if aPW^ = aW then
    begin
      Result := PByte(aPW);
      break;
    end;
    Inc(aPW);
  end;
end;

function GetFileSize(const aFilename: string): Int64;
var
  info: TWin32FileAttributeData;
begin
  Result := -1;

  if GetFileAttributesEx(PChar(aFileName), GetFileExInfoStandard, @info) then
    Result := Int64(info.nFileSizeLow) or (Int64(info.nFileSizeHigh) shl 32);
end;

end.
