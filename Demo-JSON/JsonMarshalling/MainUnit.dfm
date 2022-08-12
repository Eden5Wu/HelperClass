object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Eden'#39's Program'
  ClientHeight = 425
  ClientWidth = 419
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 19
  object StaticText1: TStaticText
    Left = 24
    Top = 24
    Width = 369
    Height = 29
    Caption = 'Some important values of our program'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
  end
  object chk1: TCheckBox
    Left = 24
    Top = 96
    Width = 97
    Height = 17
    Caption = 'chk1'
    TabOrder = 0
    OnClick = chk1Click
  end
  object chk2: TCheckBox
    Left = 24
    Top = 139
    Width = 97
    Height = 17
    Caption = 'chk2'
    TabOrder = 2
    OnClick = chk1Click
  end
  object Panel1: TPanel
    Left = 24
    Top = 208
    Width = 305
    Height = 121
    BevelOuter = bvNone
    Caption = 'Panel1'
    ShowCaption = False
    TabOrder = 3
    object rb1: TRadioButton
      Left = 0
      Top = 8
      Width = 113
      Height = 17
      Caption = 'Variant 1'
      TabOrder = 0
    end
    object rb2: TRadioButton
      Left = 0
      Top = 49
      Width = 113
      Height = 17
      Caption = 'Variant 2'
      TabOrder = 1
    end
    object rb3: TRadioButton
      Left = 0
      Top = 88
      Width = 113
      Height = 17
      Caption = 'Variant 3'
      TabOrder = 2
    end
  end
end
