unit LoginUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TLoginForm = class(TForm)
    txtUserName: TStaticText;
    edtUserName: TEdit;
    txtPassword: TStaticText;
    edtPassword: TEdit;
    btnClose: TButton;
    chkShowRecentUsername: TCheckBox;
  private
    { Private declarations }

  public
    { Public declarations }
    procedure LoadFromSettings;
    procedure SaveToSettings;
  end;

var
  LoginForm: TLoginForm;

implementation

uses
  MP.Settings;

{$R *.dfm}

{ TLoginForm }

procedure TLoginForm.LoadFromSettings;
begin
  edtUserName.Text := Settings.Login.UserName;
  chkShowRecentUsername.Checked := Settings.Login.ShowRecent;
end;

procedure TLoginForm.SaveToSettings;
begin
  if chkShowRecentUsername.Checked then
    Settings.Login.UserName := edtUserName.Text
  else
    Settings.Login.UserName := '';
  Settings.Login.ShowRecent := chkShowRecentUsername.Checked;
end;

end.
