unit MP.Settings;

interface

uses
  Classes,
  Types,
  SysUtils,
  IOUtils,

  {$IF CompilerVersion >= 28}
  System.JSON
  {$ELSE}
  DBXJSON
  {$IFEND},

  DBXJSONCommon,
  EdenDBXJsonHelper;

type
  TLoginSettings = record
    UserName: string;
    ShowRecent: Boolean;
  end;

  TMyProgSettings = class
  public
    Chk1: Boolean;
    Chk2: Boolean;
    RadioIndex: integer;
    Login: TLoginSettings;
    class function GetSettingsFolder(): string;
    class function GetDefaultSettingsFilename(): string;
    constructor Create();
    procedure LoadFromFile(AFileName: string = '');
    procedure SaveToFile(AFileName: string = '');
  end;

var
  Settings: TMyProgSettings;

implementation

{ TMyProgSettings }

constructor TMyProgSettings.Create;
begin
  Chk1 := True;
  Chk2 := False;
  RadioIndex := 0;
end;

class function TMyProgSettings.GetDefaultSettingsFilename: string;
begin
  Result := TPath.Combine(GetSettingsFolder(), 'init.json');
end;

class function TMyProgSettings.GetSettingsFolder: string;
begin
{$IFDEF MACOS}
  Result := TPath.Combine(TPath.GetLibraryPath(), 'MyProg');
{$ELSE}
  Result := TPath.Combine(TPath.GetHomePath(), 'MyProg');
{$ENDIF}
end;

procedure TMyProgSettings.LoadFromFile(AFileName: string = '');
var
  LJObj: TJSONObject;
begin
  if AFileName = '' then
    AFileName := GetDefaultSettingsFilename();

  if not FileExists(AFileName) then
    Exit;

  LJObj := TJSONObject.Create;
  try
    if LJObj.Parse(TFile.ReadAllBytes(AFileName), 0) > 0 then
    begin
      TDBXJSONTools.JsonToObj(LJObj, Self);
    end;
  finally
    LJObj.Free;
  end;
end;

procedure TMyProgSettings.SaveToFile(AFileName: string = '');
var
  Json: string;
begin
  if AFileName = '' then
    AFileName := GetDefaultSettingsFilename();

  with TDBXJSONTools.ObjToJSON(Self) do
  begin
    Json := ToJson;
    TFile.WriteAllText(AFileName, Json, TEncoding.UTF8);
    Free;
  end;
end;

end.
