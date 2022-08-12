object LoginForm: TLoginForm
  Left = 0
  Top = 0
  Caption = 'Login Form'
  ClientHeight = 385
  ClientWidth = 418
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 19
  object txtUserName: TStaticText
    Left = 160
    Top = 88
    Width = 82
    Height = 23
    Caption = 'User Name'
    TabOrder = 0
  end
  object edtUserName: TEdit
    Left = 104
    Top = 117
    Width = 209
    Height = 27
    TabOrder = 1
  end
  object txtPassword: TStaticText
    Left = 160
    Top = 168
    Width = 71
    Height = 23
    Caption = 'Password'
    TabOrder = 2
  end
  object edtPassword: TEdit
    Left = 104
    Top = 197
    Width = 209
    Height = 27
    PasswordChar = '*'
    TabOrder = 3
  end
  object btnClose: TButton
    Left = 104
    Top = 264
    Width = 209
    Height = 25
    Caption = 'Log in'
    Default = True
    ModalResult = 1
    TabOrder = 4
  end
  object chkShowRecentUsername: TCheckBox
    Left = 104
    Top = 312
    Width = 209
    Height = 17
    Caption = 'Show recent username'
    TabOrder = 5
  end
end
