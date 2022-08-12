{
  Reference from:
  https://blogs.embarcadero.com/this-is-how-to-store-cross-platform-app-settings-in-json/#Delphi_developers_are_spoiled_for_choice_when_it_comes_to_using_JSON
}
program EdenProg;

uses
  Forms,
  MainUnit in 'MainUnit.pas' {MainForm},
  EdenDBXJsonHelper in 'EdenDBXJsonHelper.pas',
  MP.Settings in 'MP.Settings.pas',
  LoginUnit in 'LoginUnit.pas' {LoginForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  {$WARN SYMBOL_PLATFORM OFF}
  ReportMemoryLeaksOnShutdown := DebugHook<>0;  //Debug Memory Leak
  {$WARN SYMBOL_PLATFORM ON}
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
