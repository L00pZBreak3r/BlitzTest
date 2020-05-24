unit MainFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.Actions,
  Vcl.ActnList, Vcl.ExtDlgs, Vcl.Buttons, Vcl.CheckLst,
  Vcl.ComCtrls, Vcl.ExtCtrls,
  MergeSorterUnit, SimpleCommunicationUnit, PipeServerBaseUnit, DownloadedFileInfoUnit;

type
  TSimpleServerMode = (SimpleServerModeNone, SimpleServerModeServer, SimpleServerModeClient);
  TForm1 = class(TForm)
    mInputText: TMemo;
    mOutputText: TMemo;
    mStringReplaceButton: TButton;
    mActionList1: TActionList;
    mStringReplaceAction: TAction;
    mOldPatternText: TEdit;
    mNewPatternText: TEdit;
    mReplaceAllCheckBox: TCheckBox;
    mIgnoreCaseCheckBox: TCheckBox;
    mTest13Action: TAction;
    mTest13Button: TButton;
    mTest13ResultText: TEdit;
    mTextFileSortAction: TAction;
    mTextFileSortButton: TButton;
    mTextFileSortFileName: TEdit;
    mSortingResultLabel: TLabel;
    mSaveSortedFileButton: TButton;
    mSaveSortedFileAction: TAction;
    mOpenTextFileDialog: TOpenDialog;
    mGenerateTestFileButton: TButton;
    mGenerateTestFileAction: TAction;
    mStartServerAction: TAction;
    mStartClientAction: TAction;
    mSimpleServerGroupBox: TGroupBox;
    mStartServerSpeedButton: TSpeedButton;
    mStartClientSpeedButton: TSpeedButton;
    mRemoteFileListBox: TCheckListBox;
    mFileListLabel: TLabel;
    mRequestFilesButton: TButton;
    mRequestFilesAction: TAction;
    mRequestFileListAction: TAction;
    mGetFileListButton: TButton;
    mPeerListLabel: TLabel;
    mPeerListBox: TListBox;
    mDelayUpDown: TUpDown;
    mPipeNameEdit: TLabeledEdit;
    mDelayEdit: TLabeledEdit;
    mTransferringFileNameLabel: TLabel;
    mTransferringFilePercentLabel: TLabel;
    mTransferringFileDirectionLabel: TLabel;
    procedure mStringReplaceActionExecute(Sender: TObject);
    procedure mStringReplaceActionUpdate(Sender: TObject);
    procedure mTest13ActionExecute(Sender: TObject);
    procedure mTextFileSortActionUpdate(Sender: TObject);
    procedure mTextFileSortActionExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure mSaveSortedFileActionUpdate(Sender: TObject);
    procedure mSaveSortedFileActionExecute(Sender: TObject);
    procedure mTextFileSortFileNameDblClick(Sender: TObject);
    procedure mGenerateTestFileActionUpdate(Sender: TObject);
    procedure mGenerateTestFileActionExecute(Sender: TObject);
    procedure mStartServerActionUpdate(Sender: TObject);
    procedure mStartClientActionUpdate(Sender: TObject);
    procedure mStartServerActionExecute(Sender: TObject);
    procedure mStartClientActionExecute(Sender: TObject);
    procedure mRequestFilesActionUpdate(Sender: TObject);
    procedure mRequestFileListActionUpdate(Sender: TObject);
    procedure mRequestFilesActionExecute(Sender: TObject);
    procedure mRequestFileListActionExecute(Sender: TObject);
    procedure mPeerListBoxClick(Sender: TObject);
    procedure mPeerListBoxKeyPress(Sender: TObject; var Key: Char);
    procedure mRemoteFileListBoxMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
  strict private
    { Private declarations }
    mMergeSorter: TStringFileMergeSorter;
    mSimpleServer: TCommunicationEndpointBase;
    mSortIsComplete: Boolean;
    mSimpleServerMode: TSimpleServerMode;
    mAskForPeerInfo, mAskForFileList: Boolean;
    mAskForFilesCount, mRemoteFileListHintPrevIndex, mTransferringFileIndex: Integer;
    mActivePeer, mRequestedFileName: string;
    mActivePeerId: THandle;

    procedure StartSimpleServer(aStartAsClient: Boolean);
    procedure StopSimpleServer;

    procedure mSimpleServerStarted(Sender: TObject);
    procedure mSimpleServerStopped(Sender: TObject);

    procedure ClearRemoteFileListBox;
    procedure AddPeer(aPeerId: THandle; const aPeerString: string);
    procedure RemovePeer(aPeerId: THandle);
    function GetPeerIndex(aPeerId: THandle): Integer;
    procedure UpdateFileList;
    function GetNextCheckedFileName: string;
    procedure HighlightFile(const aFileName: string);
    procedure UpdateTransferringFileInfo;

    procedure mMergeSorterSortCompleted(Sender: TStringFileMergeSorter; aSortSuccessful: Boolean);
    procedure mSimpleServerClientDataSend(Sender: TCommunicationEndpointBase; var aResponse: TBytes; var aDontReadAfterWrite: Boolean;
                                          var aRequestNumber: TCommunicationEndpointRequestNumber; var aRequestResult: TCommunicationEndpointRequestResult; var aString: string);
    procedure mSimpleServerClientDataExchange(Sender: TCommunicationEndpointBase; aClientPipe: THandle; aDirection: TPipeDirectionEventType; var aError: UInt32; aBytesTransferred: UInt32; const aRequest: TBytes; var aResponse: TBytes; var aDontReadAfterWrite: Boolean;
                                              var aRequestNumber: TCommunicationEndpointRequestNumber; var aRequestResult: TCommunicationEndpointRequestResult; var aString: string; var aDataSize: UInt32; aDataOffset: UInt32);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  Types, StringReplaceCustomUnit, TestBlitz3, MemoryMappedFileUnit;

const
  PIPE_NAME = 'muumuu';
  DOWNLOADED_FILE_MARK = ' (downloaded)';

procedure TForm1.FormCreate(Sender: TObject);
begin
  mMergeSorter := TStringFileMergeSorter.Create;
  mMergeSorter.OnSortingCompletedUsesSynchronize := True;
  mMergeSorter.OnSortingCompleted := mMergeSorterSortCompleted;
  mPipeNameEdit.Text := PIPE_NAME;
  mRemoteFileListHintPrevIndex := -1;
  mTransferringFileIndex := -1;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  StopSimpleServer;
  mMergeSorter.Free;
end;

procedure TForm1.mSaveSortedFileActionExecute(Sender: TObject);
begin
  mMergeSorter.Save(mTextFileSortFileName.Text + '.sorted.txt', True);
end;

procedure TForm1.mSaveSortedFileActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := mSortIsComplete;
end;

procedure TForm1.mStartClientActionExecute(Sender: TObject);
begin
  if (mSimpleServerMode = SimpleServerModeNone) or (mSimpleServerMode = SimpleServerModeClient) then
  begin
    if mSimpleServerMode = SimpleServerModeNone then
      StartSimpleServer(True)
    else
      StopSimpleServer;
    mStartClientSpeedButton.Down := mSimpleServerMode = SimpleServerModeClient;
  end;
end;

procedure TForm1.mStartClientActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (mSimpleServerMode = SimpleServerModeNone) or (mSimpleServerMode = SimpleServerModeClient);
end;

procedure TForm1.mStartServerActionExecute(Sender: TObject);
begin
  if (mSimpleServerMode = SimpleServerModeNone) or (mSimpleServerMode = SimpleServerModeServer) then
  begin
    if mSimpleServerMode = SimpleServerModeNone then
      StartSimpleServer(False)
    else
      StopSimpleServer;
    mStartServerSpeedButton.Down := mSimpleServerMode = SimpleServerModeServer;
  end;
end;

procedure TForm1.mStartServerActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (mSimpleServerMode = SimpleServerModeNone) or (mSimpleServerMode = SimpleServerModeServer);
end;

procedure TForm1.mStringReplaceActionExecute(Sender: TObject);
var
  aFlags: TReplaceFlags;
begin
  aFlags := [];
  if mReplaceAllCheckBox.Checked then
    Include(aFlags, rfReplaceAll);
  if mIgnoreCaseCheckBox.Checked then
    Include(aFlags, rfIgnoreCase);
  mOutputText.Text := StringReplaceCustom(mInputText.Text, mOldPatternText.Text, mNewPatternText.Text, aFlags);
end;

procedure TForm1.mStringReplaceActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (Length(mInputText.Text) > 0) and (Length(mOldPatternText.Text) > 0);
end;

procedure TForm1.mTest13ActionExecute(Sender: TObject);
begin
  mTest13ResultText.Text := RunTestBlitz3;
end;

procedure TForm1.mTextFileSortActionExecute(Sender: TObject);
begin
  mSortingResultLabel.Caption := 'Sorting...';
  mSortIsComplete := False;
  mMergeSorter.Open(mTextFileSortFileName.Text);
  mMergeSorter.Start;
end;

procedure TForm1.mTextFileSortActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := FileExists(mTextFileSortFileName.Text);
end;

procedure TForm1.mTextFileSortFileNameDblClick(Sender: TObject);
begin
  if mOpenTextFileDialog.Execute then
    mTextFileSortFileName.Text := mOpenTextFileDialog.FileName;
end;

procedure TForm1.mGenerateTestFileActionExecute(Sender: TObject);
const
  M = 8 * 1024 * 1024;
var
  aMemoryMappedFile: TMemoryMappedFile;
  //aList: TStringList;
  i: Integer;
begin
  {aList := TStringList.Create(dupAccept, False, True);
  for i := 0 to M do
    aList.Add(IntToStr(Random(MaxInt)));
  aList.SaveToFile(mTextFileSortFileName.Text);
  aList.Free;}
  aMemoryMappedFile := TMemoryMappedFile.Create;
  aMemoryMappedFile.BufferSize := M * 12 * SizeOf(Char);
  aMemoryMappedFile.Open(mTextFileSortFileName.Text, False, True);
  aMemoryMappedFile.CreateUnicodeTextFile;
  for i := 0 to M do
    aMemoryMappedFile.AppendUnicodeString(IntToStr(Random(MaxInt)) + #13#10);
  aMemoryMappedFile.Free;
end;

procedure TForm1.mGenerateTestFileActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (Length(mTextFileSortFileName.Text) > 0) and not FileExists(mTextFileSortFileName.Text);
end;

procedure TForm1.StartSimpleServer(aStartAsClient: Boolean);
var
  aEndpointType: TCommunicationEndpointType;
  aPipeName: string;
begin
  if mSimpleServerMode = SimpleServerModeNone then
  begin
    if Assigned(mSimpleServer) then
      FreeAndNil(mSimpleServer);
    if aStartAsClient then
      aEndpointType := CommunicationEndpointClient
    else
      aEndpointType := CommunicationEndpointServer;
    aPipeName := Trim(mPipeNameEdit.Text);
    if Length(aPipeName) = 0 then
    begin
      aPipeName := PIPE_NAME;
      mPipeNameEdit.Text := aPipeName;
    end;
    mSimpleServer := TCommunicationEndpointBase.Create(aEndpointType, aPipeName);
    mSimpleServer.OnServerStarted := mSimpleServerStarted;
    mSimpleServer.OnServerStopped := mSimpleServerStopped;
    mSimpleServer.OnClientDataSend := mSimpleServerClientDataSend;
    mSimpleServer.OnDataExchange := mSimpleServerClientDataExchange;
    if aStartAsClient then
    begin
      mSimpleServerMode := SimpleServerModeClient;
      mSimpleServer.Open(True);
    end
    else
      mSimpleServerMode := SimpleServerModeServer;
    mSimpleServer.Start;
  end;
end;

procedure TForm1.StopSimpleServer;
begin
  if Assigned(mSimpleServer) then
    FreeAndNil(mSimpleServer);
  mSimpleServerStopped(nil);
end;

procedure TForm1.mMergeSorterSortCompleted(Sender: TStringFileMergeSorter; aSortSuccessful: Boolean);
begin
  mSortIsComplete := True;
  mSortingResultLabel.Caption := BoolToStr(aSortSuccessful, True);
end;

procedure TForm1.mPeerListBoxClick(Sender: TObject);
begin
  if (mPeerListBox.ItemIndex >= 0) and (mPeerListBox.Items[mPeerListBox.ItemIndex] <> mActivePeer) then
  begin
    mActivePeer := mPeerListBox.Items[mPeerListBox.ItemIndex];
    mActivePeerId := THandle(mPeerListBox.Items.Objects[mPeerListBox.ItemIndex]);
    ClearRemoteFileListBox;
  end;
end;

procedure TForm1.mPeerListBoxKeyPress(Sender: TObject; var Key: Char);
begin
  mPeerListBoxClick(Sender)
end;

procedure TForm1.mRemoteFileListBoxMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  aIndex: Integer;
  aDownloadedFileInfo: TDownloadedFileInfo;
  aHintStr: string;
begin
  aIndex := mRemoteFileListBox.ItemAtPos(Point(X, Y), True);
  if aIndex >= 0 then
  begin
    aDownloadedFileInfo := TDownloadedFileInfo(mRemoteFileListBox.Items.Objects[aIndex]);
    aHintStr := 'Name: ' + aDownloadedFileInfo.Path + sLineBreak + 'Size: ' + IntToStr(aDownloadedFileInfo.Size) + ' bytes';
    if aDownloadedFileInfo.Downloaded then
      aHintStr := aHintStr + sLineBreak + 'Downloaded';
    mRemoteFileListBox.Hint := aHintStr;
  end
  else
    mRemoteFileListBox.Hint := '';
  if aIndex <> mRemoteFileListHintPrevIndex then
    Application.CancelHint;
  mRemoteFileListHintPrevIndex := aIndex;
end;

procedure TForm1.mRequestFileListActionExecute(Sender: TObject);
begin
  if Length(mRequestedFileName) = 0 then
    mAskForFileList := True;
end;

procedure TForm1.mRequestFileListActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (mSimpleServerMode <> SimpleServerModeNone) and not mAskForFileList and (Length(mRequestedFileName) = 0);
end;

procedure TForm1.mRequestFilesActionExecute(Sender: TObject);
var
  i, aCheckedCount: Integer;
begin
  if (mAskForFilesCount <= 0) and (Length(mRequestedFileName) = 0) then
  begin
    aCheckedCount := 0;
    for i := 0 to mRemoteFileListBox.Count - 1 do
      if mRemoteFileListBox.Checked[i] then
        Inc(aCheckedCount);

    mAskForFilesCount := aCheckedCount;
  end;
end;

procedure TForm1.mRequestFilesActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := (mSimpleServerMode <> SimpleServerModeNone) and (mRemoteFileListBox.Count > 0) and (mAskForFilesCount <= 0) and (Length(mRequestedFileName) = 0);
end;

procedure TForm1.mSimpleServerStarted(Sender: TObject);
begin
  mPeerListBox.Enabled := mSimpleServerMode <> SimpleServerModeNone;
  mRemoteFileListBox.Enabled := mSimpleServerMode <> SimpleServerModeNone;
end;

procedure TForm1.mSimpleServerStopped(Sender: TObject);
begin
  mSimpleServerMode := SimpleServerModeNone;
  mActivePeer := string.Empty;
  mActivePeerId := 0;
  mAskForPeerInfo := False;
  mAskForFileList := False;
  mStartServerSpeedButton.Down := False;
  mStartClientSpeedButton.Down := False;
  mPeerListBox.Clear;
  ClearRemoteFileListBox;
  mTransferringFileDirectionLabel.Caption := string.Empty;
  mTransferringFileNameLabel.Caption := string.Empty;
  mTransferringFilePercentLabel.Caption := string.Empty;
  mPeerListBox.Enabled := mSimpleServerMode <> SimpleServerModeNone;
  mRemoteFileListBox.Enabled := mSimpleServerMode <> SimpleServerModeNone;
end;

procedure TForm1.AddPeer(aPeerId: THandle; const aPeerString: string);
var
  aSplitted: TArray<string>;
  aPeerName: string;
  aIndex: Integer;
begin
  aSplitted := aPeerString.Split([LIST_ITEM_DELIMITER]);
  if Length(aSplitted) > 1 then
  begin
    aPeerName := aSplitted[1];
    aIndex := mPeerListBox.Items.IndexOf(aPeerName);
    if aIndex < 0 then
    begin
      mPeerListBox.AddItem(aPeerName, TObject(aPeerId));
      if mPeerListBox.Count = 1 then
      begin
        mActivePeer := aPeerName;
        mActivePeerId := aPeerId;
      end;
    end
    else
    begin
      mPeerListBox.Items.Objects[aIndex] := TObject(aPeerId);
      if mActivePeer = mPeerListBox.Items[aIndex] then
        mActivePeerId := aPeerId;
    end;
  end;
end;

procedure TForm1.RemovePeer(aPeerId: THandle);
var
  i: Integer;
begin
  if mActivePeerId = aPeerId then
  begin
    mActivePeer := string.Empty;
    mActivePeerId := 0;
    ClearRemoteFileListBox;
    mTransferringFileDirectionLabel.Caption := string.Empty;
    mTransferringFileNameLabel.Caption := string.Empty;
    mTransferringFilePercentLabel.Caption := string.Empty;
  end;
  for i := 0 to mPeerListBox.Count - 1 do
    if THandle(mPeerListBox.Items.Objects[i]) = aPeerId then
    begin
      mPeerListBox.Items.Delete(i);
      break;
    end;
  if mPeerListBox.Count = 1 then
  begin
    mActivePeer := mPeerListBox.Items[0];
    mActivePeerId := THandle(mPeerListBox.Items.Objects[0]);
  end;
end;

function TForm1.GetPeerIndex(aPeerId: THandle): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to mPeerListBox.Count - 1 do
    if THandle(mPeerListBox.Items.Objects[i]) = aPeerId then
    begin
      Result := i;
      break;
    end;
end;

procedure TForm1.UpdateFileList;
var
  i: Integer;
  aAvailableFiles: TAvailableFilesList;
  aDownloadedFileInfo: TDownloadedFileInfo;
  aFileName: string;
begin
  ClearRemoteFileListBox;
  if Assigned(mSimpleServer) then
  begin
    aAvailableFiles := mSimpleServer.AvailableFiles;
    mRemoteFileListBox.Items.BeginUpdate;
    for i := 0 to aAvailableFiles.Count - 1 do
    begin
      aDownloadedFileInfo := TDownloadedFileInfo.Create(aAvailableFiles[i]);
      aFileName := aDownloadedFileInfo.Path;
      if aDownloadedFileInfo.Downloaded then
        aFileName := aFileName + DOWNLOADED_FILE_MARK;
      mRemoteFileListBox.AddItem(aFileName, aDownloadedFileInfo);
    end;
    mRemoteFileListBox.Items.EndUpdate;
    mSimpleServer.ReleaseAvailableFiles;
  end;
end;

function TForm1.GetNextCheckedFileName: string;
var
  aCheckedIndex, i: Integer;
  aTransferringFileName: string;
  aDownloadedFileInfo: TDownloadedFileInfo;
begin
  Result := string.Empty;
  if mAskForFilesCount > 0 then
  begin
    aTransferringFileName := string.Empty;
    if Assigned(mSimpleServer) then
      aTransferringFileName := mSimpleServer.TransferringFileName;
    if (Length(mRequestedFileName) = 0) and (Length(aTransferringFileName) = 0) then
    begin
      Dec(mAskForFilesCount);
      aCheckedIndex := 0;
      for i := 0 to mRemoteFileListBox.Count - 1 do
        if mRemoteFileListBox.Checked[i] then
        begin
          if mAskForFilesCount = aCheckedIndex then
          begin
            aDownloadedFileInfo := TDownloadedFileInfo(mRemoteFileListBox.Items.Objects[i]);
            Result := aDownloadedFileInfo.Path;
            mRemoteFileListBox.Checked[i] := False;
            mRemoteFileListBox.Items[i] := Result;
            break;
          end;
          Inc(aCheckedIndex);
        end;
    end;
  end;
end;

procedure TForm1.HighlightFile(const aFileName: string);
var
  i: Integer;
  aDownloadedFileInfo: TDownloadedFileInfo;
begin
  UpdateTransferringFileInfo;
  for i := 0 to mRemoteFileListBox.Count - 1 do
  begin
    aDownloadedFileInfo := TDownloadedFileInfo(mRemoteFileListBox.Items.Objects[i]);
    if AnsiCompareText(aDownloadedFileInfo.Path, aFileName) = 0 then
    begin
      mRemoteFileListBox.Items[i] := aDownloadedFileInfo.Path + DOWNLOADED_FILE_MARK;
      break;
    end;
  end;
  mRequestedFileName := string.Empty;
end;

procedure TForm1.UpdateTransferringFileInfo;
var
  i, aIndex: Integer;
  aFileName: string;
  aDownloadedFileInfo, aTransferringFileInfo: TDownloadedFileInfo;
  aTransferringFileSize: UInt32;
begin
  aFileName := string.Empty;
  if Assigned(mSimpleServer) then
  begin
    aFileName := mSimpleServer.TransferringFileName;
    if Length(aFileName) > 0 then
    begin
      aFileName := ExtractFileName(aFileName);
      aIndex := -1;
      aTransferringFileInfo := nil;
      for i := 0 to mRemoteFileListBox.Count - 1 do
      begin
        aDownloadedFileInfo := TDownloadedFileInfo(mRemoteFileListBox.Items.Objects[i]);
        if AnsiCompareText(aDownloadedFileInfo.Path, aFileName) = 0 then
        begin
          aIndex := i;
          aTransferringFileInfo := aDownloadedFileInfo;
          break;
        end;
      end;
      if (aIndex <> mTransferringFileIndex) and (aIndex >= 0) then
      begin
        mTransferringFileIndex := aIndex;
        mRemoteFileListBox.ItemIndex := mTransferringFileIndex;
      end;
      aTransferringFileSize := 0;
      if mSimpleServer.TransferringFileSending then
      begin
        mTransferringFileDirectionLabel.Caption := 'Sending:';
        aTransferringFileSize := mSimpleServer.TransferringFileSize;
      end
      else
      begin
        mTransferringFileDirectionLabel.Caption := 'Receiving:';
        if Assigned(aTransferringFileInfo) then
          aTransferringFileSize := aTransferringFileInfo.Size;
      end;
      mTransferringFileNameLabel.Caption := aFileName;
      if aTransferringFileSize > 0 then
        mTransferringFilePercentLabel.Caption := Format('%3d%%', [mSimpleServer.TransferringFileBytesTransferred * 100 div aTransferringFileSize])
      else
        mTransferringFilePercentLabel.Caption := string.Empty;
    end;
  end;
  if Length(aFileName) = 0 then
  begin
    mRequestedFileName := string.Empty;
    mTransferringFileIndex := -1;
    mTransferringFileDirectionLabel.Caption := string.Empty;
    mTransferringFileNameLabel.Caption := string.Empty;
    mTransferringFilePercentLabel.Caption := string.Empty;
  end;
end;

procedure TForm1.ClearRemoteFileListBox;
var
  i: Integer;
begin
  mRequestedFileName := string.Empty;
  mRemoteFileListHintPrevIndex := -1;
  mTransferringFileIndex := -1;
  for i := 0 to mRemoteFileListBox.Count - 1 do
    TDownloadedFileInfo(mRemoteFileListBox.Items.Objects[i]).Free;
  mRemoteFileListBox.Clear;
  mAskForFilesCount := 0;
end;

procedure TForm1.mSimpleServerClientDataSend(Sender: TCommunicationEndpointBase; var aResponse: TBytes; var aDontReadAfterWrite: Boolean;
    var aRequestNumber: TCommunicationEndpointRequestNumber; var aRequestResult: TCommunicationEndpointRequestResult; var aString: string);
begin
  if mSimpleServerMode = SimpleServerModeClient then
    if mAskForPeerInfo then
    begin
      aRequestNumber := REQUEST_EMPTY;
      aRequestResult := REQUEST_RESULT_ASK;
    end
    else
    begin
      aRequestNumber := REQUEST_GET_PEER_INFORMATION;
      aRequestResult := REQUEST_RESULT_ASK;
      mAskForPeerInfo := True;
    end
end;

procedure TForm1.mSimpleServerClientDataExchange(Sender: TCommunicationEndpointBase; aClientPipe: THandle; aDirection: TPipeDirectionEventType; var aError: UInt32; aBytesTransferred: UInt32; const aRequest: TBytes; var aResponse: TBytes; var aDontReadAfterWrite: Boolean;
  var aRequestNumber: TCommunicationEndpointRequestNumber; var aRequestResult: TCommunicationEndpointRequestResult; var aString: string; var aDataSize: UInt32; aDataOffset: UInt32);
var
  aFN: string;
  aDelayMs: Integer;
begin
  aDelayMs := StrToIntDef(mDelayEdit.Text, 0);
  if aDelayMs > 0 then
    TThread.Sleep(aDelayMs);
  if aDirection = PIPE_DIRECTION_RECEIVE then
  if aRequestNumber = REQUEST_DISCONNECT then
  begin
    RemovePeer(aClientPipe);
    aRequestNumber := REQUEST_NONE;
  end
  else if aRequestResult = REQUEST_RESULT_SUCCESS then
  begin
    case aRequestNumber of
      REQUEST_GET_PEER_INFORMATION: AddPeer(aClientPipe, aString);
      REQUEST_GET_FILE_LIST: UpdateFileList;
      REQUEST_GET_FILE: HighlightFile(aString);
    end;
    aRequestNumber := REQUEST_NONE;
  end
  else if aRequestNumber = REQUEST_GET_FILE then
  begin
    if aRequestResult = REQUEST_RESULT_FAILURE then
      mRequestedFileName := string.Empty;

    UpdateTransferringFileInfo;
    aRequestNumber := REQUEST_NONE;
  end
  else if (aRequestNumber = REQUEST_EMPTY) and (aRequestResult = REQUEST_RESULT_ASK) then
  begin
    if GetPeerIndex(aClientPipe) < 0 then
    begin
      aRequestNumber := REQUEST_GET_PEER_INFORMATION;
    end
    else if mAskForFileList then
    begin
      mAskForFileList := False;
      aRequestNumber := REQUEST_GET_FILE_LIST;
    end
    else
    begin
      aFN := GetNextCheckedFileName;
      if aFN.Length > 0 then
      begin
        aRequestNumber := REQUEST_GET_FILE;
        aString := aFN;
        mRequestedFileName := aFN;
      end
    end
  end
  else
    aRequestNumber := REQUEST_NONE
end;

end.
