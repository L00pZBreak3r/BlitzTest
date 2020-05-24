unit StringReplaceCustomUnit;

interface

uses
  SysUtils;

function StringReplaceCustom(const Source, OldPattern, NewPattern: string; Flags: TReplaceFlags): string;

implementation

uses
  ShLwApi;

type
  TStrStrFunc = function(pszFirst, pszSrch: PChar): PChar; stdcall;

function StringReplaceBuff(var aDest: string; const aSource, aOldPattern, aNewPattern: string; Flags: TReplaceFlags): Integer;
var
  StrStrFunc: TStrStrFunc;
  aCpy: Boolean;
  aPSource, aPDest, aPOldPattern, aPNewPattern, aPStart, aPCur: PChar;
  aSourceLen, aDestLen, aOldLen, aNewLen, aDiffLen, aRestLen, aCatLen: Integer;
begin
  StrStrFunc := StrStr;
  if rfIgnoreCase in Flags then
    StrStrFunc := StrStrI;
  aDestLen := Length(aDest);
  aCpy := aDestLen > 0;
  if aCpy then
    aDest[1] := #0;
  aSourceLen := Length(aSource);
  aOldLen := Length(aOldPattern);
  aNewLen := Length(aNewPattern);
  aDiffLen := aNewLen - aOldLen;
  Result := aSourceLen;
  aPSource := PChar(aSource);
  aPDest := PChar(aDest);
  aPOldPattern := PChar(aOldPattern);
  aPNewPattern := PChar(aNewPattern);
  aPStart := aPSource;
  aPCur := StrStrFunc(aPStart, aPOldPattern);
  if aPCur <> nil then
  begin
    if rfReplaceAll in Flags then
    begin
      Result := aSourceLen;
      aRestLen := aDestLen;
      while aPCur <> nil do
      begin
        Inc(Result, aDiffLen);
        aCatLen := (aPCur - aPStart) + aNewLen;
        if aCpy and (aRestLen >= aCatLen) then
        begin
          StrNCat(aPDest, aPStart, aPCur - aPStart + 1);
          StrCat(aPDest, aPNewPattern);
          Dec(aRestLen, aCatLen);
        end;
        aPStart := aPCur + aOldLen;
        aPCur := StrStrFunc(aPStart, aPOldPattern);
      end;
      if aCpy and (aRestLen >= StrLen(aPStart)) then
        StrCat(aPDest, aPStart);
    end
    else
    begin
      Result := aSourceLen + aDiffLen;
      if aCpy and (aDestLen >= Result) then
      begin
        StrNCat(aPDest, aPStart, aPCur - aPStart + 1);
        StrCat(aPDest, aPNewPattern);
        StrCat(aPDest, aPCur + aOldLen);
      end;
    end;
  end
  else if aCpy and (aDestLen >= Result) then
    StrCpy(aPDest, aPSource);
  if aCpy then
    Result := StrLen(aPDest);
end;

function StringReplaceCustom(const Source, OldPattern, NewPattern: string; Flags: TReplaceFlags): string;
var
  aSourceLen, aOldLen, aResultLen: Integer;
begin
  Result := string.Empty;
  aSourceLen := Length(Source);
  aOldLen := Length(OldPattern);
  if (aSourceLen > 0) and (aOldLen > 0) then
  begin
    aResultLen := StringReplaceBuff(Result, Source, OldPattern, NewPattern, Flags);
    SetLength(Result, aResultLen);
    StringReplaceBuff(Result, Source, OldPattern, NewPattern, Flags);
  end
  else
    Result := Source;
end;

end.
