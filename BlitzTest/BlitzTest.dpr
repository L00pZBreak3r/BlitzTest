program BlitzTest;

uses
  Vcl.Forms,
  MainFormUnit in 'MainFormUnit.pas' {Form1},
  StringReplaceCustomUnit in 'StringReplaceCustomUnit.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
