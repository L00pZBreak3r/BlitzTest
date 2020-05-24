unit TestBlitz3;

interface

function RunTestBlitz3: string;

implementation

uses
  SysUtils, Character;

type

TCalcNode = class
  left, right: TCalcNode;
  NodeText: string;

  constructor Create(const val: string = '');
  destructor Destroy; override;
  function Add(const val: string; aIsRight: Boolean = False): TCalcNode;
  function GetNumbersCount(aIncludeFlags: Integer = 3): Integer;


  procedure Delete;
end;

constructor TCalcNode.Create(const val: string);
begin
  NodeText := val;
  left := nil;
  right := nil;
end;

destructor TCalcNode.Destroy;
begin
  Delete;
  inherited
end;

procedure TCalcNode.Delete;
begin
  if Assigned(left) then
    FreeAndNil(left);
  if Assigned(right) then
    FreeAndNil(right);
end;

function TCalcNode.Add(const val: string; aIsRight: Boolean): TCalcNode;
begin
  Result := TCalcNode.Create(val);
  if aIsRight then
  begin
    if Assigned(right) then
      FreeAndNil(right);
    right := Result
  end
  else
  begin
    if Assigned(left) then
      FreeAndNil(left);
    left := Result
  end;
end;

function TCalcNode.GetNumbersCount(aIncludeFlags: Integer): Integer;
var
  i: Integer;
  length: Integer;
begin
  length := NodeText.Length;
  Result := 0;
  for i := 1 to length do
  begin
    if NodeText[i].IsDigit then
      inc(Result);
  end;
  if Assigned(left) and ((aIncludeFlags and 1) <> 0) then
    inc(Result, left.GetNumbersCount(3));
  if Assigned(right) and ((aIncludeFlags and 2) <> 0) then
    inc(Result, right.GetNumbersCount(3));
end;


function RunTestBlitz3: string;
var
  tree: TCalcNode;
  count: Integer;
begin
  tree := TCalcNode.Create;
  tree.Add('test123').Add('test1').Add('test1234');
  count := tree.GetNumbersCount;
  Result := Format('Numbers count: %d', [count]);
  FreeAndNil(tree);
end;

end.