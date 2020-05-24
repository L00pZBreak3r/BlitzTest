object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Blitz Test'
  ClientHeight = 478
  ClientWidth = 696
  Color = clBtnFace
  Constraints.MinHeight = 500
  Constraints.MinWidth = 700
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    696
    478)
  PixelsPerInch = 96
  TextHeight = 13
  object mSortingResultLabel: TLabel
    Left = 615
    Top = 209
    Width = 3
    Height = 13
    Anchors = [akTop, akRight]
  end
  object mInputText: TMemo
    Left = 8
    Top = 39
    Width = 680
    Height = 62
    Hint = 'Text to torture'
    Anchors = [akLeft, akTop, akRight]
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
  end
  object mOutputText: TMemo
    Left = 8
    Top = 107
    Width = 680
    Height = 62
    Hint = 'Text torture result'
    Anchors = [akLeft, akTop, akRight]
    ParentShowHint = False
    ReadOnly = True
    ShowHint = True
    TabOrder = 1
  end
  object mStringReplaceButton: TButton
    Left = 8
    Top = 8
    Width = 145
    Height = 25
    Action = mStringReplaceAction
    TabOrder = 2
  end
  object mOldPatternText: TEdit
    Left = 159
    Top = 8
    Width = 146
    Height = 21
    Hint = 'Old pattern'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 3
  end
  object mNewPatternText: TEdit
    Left = 311
    Top = 8
    Width = 146
    Height = 21
    Hint = 'New pattern'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 4
  end
  object mReplaceAllCheckBox: TCheckBox
    Left = 463
    Top = 8
    Width = 74
    Height = 17
    Caption = 'Replace all'
    TabOrder = 5
  end
  object mIgnoreCaseCheckBox: TCheckBox
    Left = 552
    Top = 8
    Width = 81
    Height = 17
    Caption = 'Ignore case'
    TabOrder = 6
  end
  object mTest13Button: TButton
    Left = 8
    Top = 175
    Width = 145
    Height = 25
    Action = mTest13Action
    ParentShowHint = False
    ShowHint = True
    TabOrder = 7
  end
  object mTest13ResultText: TEdit
    Left = 159
    Top = 175
    Width = 529
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    ReadOnly = True
    TabOrder = 8
  end
  object mTextFileSortButton: TButton
    Left = 8
    Top = 206
    Width = 145
    Height = 25
    Action = mTextFileSortAction
    TabOrder = 9
  end
  object mTextFileSortFileName: TEdit
    Left = 159
    Top = 206
    Width = 450
    Height = 21
    Hint = 'Double click to open a file open dialog'
    Anchors = [akLeft, akTop, akRight]
    ParentShowHint = False
    ShowHint = True
    TabOrder = 10
    OnDblClick = mTextFileSortFileNameDblClick
  end
  object mSaveSortedFileButton: TButton
    Left = 8
    Top = 237
    Width = 145
    Height = 25
    Action = mSaveSortedFileAction
    ParentShowHint = False
    ShowHint = True
    TabOrder = 11
  end
  object mGenerateTestFileButton: TButton
    Left = 159
    Top = 237
    Width = 145
    Height = 25
    Action = mGenerateTestFileAction
    TabOrder = 12
  end
  object mSimpleServerGroupBox: TGroupBox
    Left = 8
    Top = 268
    Width = 680
    Height = 202
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = 'Simple communication server'
    TabOrder = 13
    DesignSize = (
      680
      202)
    object mStartServerSpeedButton: TSpeedButton
      Left = 3
      Top = 16
      Width = 75
      Height = 22
      Action = mStartServerAction
      ParentShowHint = False
      ShowHint = True
    end
    object mStartClientSpeedButton: TSpeedButton
      Left = 84
      Top = 16
      Width = 75
      Height = 22
      Action = mStartClientAction
      ParentShowHint = False
      ShowHint = True
    end
    object mFileListLabel: TLabel
      Left = 278
      Top = 44
      Width = 74
      Height = 13
      Caption = 'Remote file list:'
    end
    object mPeerListLabel: TLabel
      Left = 3
      Top = 44
      Width = 42
      Height = 13
      Caption = 'Peer list:'
    end
    object mTransferringFileNameLabel: TLabel
      Left = 511
      Top = 145
      Width = 3
      Height = 13
    end
    object mTransferringFilePercentLabel: TLabel
      Left = 511
      Top = 164
      Width = 3
      Height = 13
    end
    object mTransferringFileDirectionLabel: TLabel
      Left = 511
      Top = 126
      Width = 3
      Height = 13
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object mRemoteFileListBox: TCheckListBox
      Left = 278
      Top = 63
      Width = 227
      Height = 136
      Anchors = [akLeft, akTop, akBottom]
      ItemHeight = 13
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnMouseMove = mRemoteFileListBoxMouseMove
    end
    object mRequestFilesButton: TButton
      Left = 511
      Top = 95
      Width = 75
      Height = 25
      Action = mRequestFilesAction
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
    end
    object mGetFileListButton: TButton
      Left = 511
      Top = 64
      Width = 75
      Height = 25
      Action = mRequestFileListAction
      TabOrder = 3
    end
    object mPeerListBox: TListBox
      Left = 3
      Top = 63
      Width = 269
      Height = 136
      Anchors = [akLeft, akTop, akBottom]
      ItemHeight = 13
      Sorted = True
      TabOrder = 4
      OnClick = mPeerListBoxClick
      OnKeyPress = mPeerListBoxKeyPress
    end
    object mDelayUpDown: TUpDown
      Left = 449
      Top = 17
      Width = 16
      Height = 21
      Associate = mDelayEdit
      Max = 1000
      TabOrder = 5
    end
    object mPipeNameEdit: TLabeledEdit
      Left = 223
      Top = 17
      Width = 121
      Height = 21
      Hint = 'Pipe name'
      EditLabel.Width = 53
      EditLabel.Height = 13
      EditLabel.Caption = 'Pipe name:'
      LabelPosition = lpLeft
      ParentShowHint = False
      ShowHint = True
      TabOrder = 6
    end
    object mDelayEdit: TLabeledEdit
      Left = 390
      Top = 17
      Width = 59
      Height = 21
      Hint = 'Delay pipe communication (ms)'
      EditLabel.Width = 31
      EditLabel.Height = 13
      EditLabel.Caption = 'Delay:'
      LabelPosition = lpLeft
      NumbersOnly = True
      ParentShowHint = False
      ShowHint = True
      TabOrder = 7
      Text = '0'
    end
  end
  object mActionList1: TActionList
    Left = 632
    Top = 216
    object mStringReplaceAction: TAction
      Caption = 'StringReplace'
      OnExecute = mStringReplaceActionExecute
      OnUpdate = mStringReplaceActionUpdate
    end
    object mTest13Action: TAction
      Caption = 'Test 13'
      Hint = 'Run Blitz3 test'
      OnExecute = mTest13ActionExecute
    end
    object mTextFileSortAction: TAction
      Caption = 'Sort a text file'
      OnExecute = mTextFileSortActionExecute
      OnUpdate = mTextFileSortActionUpdate
    end
    object mSaveSortedFileAction: TAction
      Caption = 'Save'
      Hint = 'Save the sorted file'
      OnExecute = mSaveSortedFileActionExecute
      OnUpdate = mSaveSortedFileActionUpdate
    end
    object mGenerateTestFileAction: TAction
      Caption = 'Generate a test file'
      Hint = 'Create a file to test sorting'
      OnExecute = mGenerateTestFileActionExecute
      OnUpdate = mGenerateTestFileActionUpdate
    end
    object mStartServerAction: TAction
      Caption = 'Server'
      Hint = 'Start server'
      OnExecute = mStartServerActionExecute
      OnUpdate = mStartServerActionUpdate
    end
    object mStartClientAction: TAction
      Caption = 'Client'
      Hint = 'Start client'
      OnExecute = mStartClientActionExecute
      OnUpdate = mStartClientActionUpdate
    end
    object mRequestFilesAction: TAction
      Caption = 'Request files'
      Hint = 'Request files from a remote peer'
      OnExecute = mRequestFilesActionExecute
      OnUpdate = mRequestFilesActionUpdate
    end
    object mRequestFileListAction: TAction
      Caption = 'Get file list'
      Hint = 'Get list of available files from a remote peer'
      OnExecute = mRequestFileListActionExecute
      OnUpdate = mRequestFileListActionUpdate
    end
  end
  object mOpenTextFileDialog: TOpenDialog
    DefaultExt = 'txt'
    Filter = 'Text files|*.txt|Pascal files|*.pas'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 544
    Top = 216
  end
end
