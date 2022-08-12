unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  DBXJSON, Dialogs, StdCtrls, DB, DBClient, DBXJSONReflect, ExtCtrls;

type
  TMainForm = class(TForm)
    StaticText1: TStaticText;
    chk1: TCheckBox;
    chk2: TCheckBox;
    Panel1: TPanel;
    rb1: TRadioButton;
    rb2: TRadioButton;
    rb3: TRadioButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure chk1Click(Sender: TObject);
  private
    { Private declarations }
    procedure LoadFromSettings;
    procedure SaveToSettings;
    procedure TryLogin;
    function LoginCorrect(ALogin, APassword: string): boolean;
  public
    { Public declarations }
    procedure LoadSettings;
  end;

var
  MainForm: TMainForm;

implementation

uses
  MP.Settings,
  LoginUnit;

{$R *.dfm}

{ TForm2 }

procedure TMainForm.chk1Click(Sender: TObject);
begin
  SaveToSettings();
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  LoadSettings();

  TryLogin();
  if Application.Terminated then
    exit;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Settings.SaveToFile();
  Settings.Free;
end;

procedure TMainForm.LoadFromSettings;
begin
  chk1.Checked := Settings.Chk1;
  chk1.Checked := Settings.Chk2;
  rb1.Checked := Settings.RadioIndex = 0;
  rb2.Checked := Settings.RadioIndex = 1;
  rb3.Checked := Settings.RadioIndex = 2;
end;

procedure TMainForm.LoadSettings;
begin
  if Settings = nil then
    Settings := TMyProgSettings.Create;
  if not FileExists(Settings.GetDefaultSettingsFilename()) then
  begin
    ForceDirectories(Settings.GetSettingsFolder());
    Settings.SaveToFile();
  end;

  Settings.LoadFromFile();
  LoadFromSettings();
end;

function TMainForm.LoginCorrect(ALogin, APassword: string): boolean;
begin
  Result := (ALogin = 'admin') and (APassword = '123');
end;

procedure TMainForm.SaveToSettings;
begin
  Settings.Chk1 := chk1.Checked;
  Settings.Chk2 := chk2.Checked;
  if rb1.Checked then
    Settings.radioIndex := 0
  else if rb2.Checked then
    Settings.radioIndex := 1
  else if rb3.Checked then
    Settings.radioIndex := 2;
end;

procedure TMainForm.TryLogin;
var
  F: TLoginForm;
  Login, Password: string;
begin
  F := TLoginForm.Create(NIL);
  try
    while not Application.Terminated do
    begin
      if F.ShowModal = mrOK then
      begin
        Login := F.edtUserName.Text;
        Password := F.edtPassword.Text;
        if LoginCorrect(Login, Password) then
          Break;
      end
      else
        Application.Terminate;
    end;
  finally
    F.Free;
  end;
end;

end.
