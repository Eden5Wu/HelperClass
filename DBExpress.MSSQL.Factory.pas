unit DBExpress.MSSQL.Factory;

interface

uses
  DBXCommon, Classes, DbxMsSql, DBXDynalink, Variants;

type
  TDBXMSSQLFactory = class
  protected
    FDBXConnection: TDBXConnection;
    FConnectionProps: TDBXProperties;
    FConnectionFactory: TDBXConnectionFactory;
  private
  protected
  public
    constructor Create(const AHostName, ADatabase, AUserName, APassword: string); overload;
    constructor Create(const AParams: TStrings); overload;
    destructor Destroy; override;
    function GetConnection: TDBXConnection;
    function Execute(ASQL: string): Int64; overload;
    function Execute(ASQL: string; args: OleVariant): Int64; overload;
    function Execute(ASQLCommand: TDBXCommand): Int64; overload;
    function Execute(ASQLCommand: TDBXCommand; args: OleVariant): Int64; overload;
    function ExecuteQuery(ASQLCommand: TDBXCommand): TDBXReader; overload;
    function ExecuteQuery(ASQLCommand: TDBXCommand; args: OleVariant): TDBXReader; overload;
    function Prepare(ASQL: string): TDBXCommand;
    function PrepareMSQuery(ASQL: string): TDBXCommand;
    property ConnectionProps: TDBXProperties read FConnectionProps;
  end;

implementation

uses
  SysUtils;

// uses DBXDevartSQLServer
const DEVART_MSSQL_CONNECTION_STRING = ''
  +'%s=DevartSQLServer;%s=%s;%s=%s;%s=%s;%s=%s'
  +';BlobSize=-1;SchemaOverride=%%.dbo;LongStrings=True;EnableBCD=True'
  +';FetchAll=True;UseUnicode=True;IPVersion=IPv4';
  //+';Custom String=ApplicationName=A_NAME;WorkstationID=WID';
// uses DbxMsSql
const MSSQL_CONNECTION_STRING = ''
  +'%s=MSSQL;%s=%s;%s=%s;%s=%s;%s=%s'
  +';SchemaOverride=%%.dbo;BlobSize=-1;ErrorResourceFile=;LocaleCode=0000'
  +';IsolationLevel=ReadCommitted;OS Authentication=False;Prepare SQL=True'
  +';ConnectTimeout=60;Mars_Connection=False';

/// <summary> fixed: Cursor not returned from Query </summary>
const SET_NOCOUNT_ON = 'SET NOCOUNT ON;'#13#10;
const SET_READ_UNCOMMITTED = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;'#13#10;
const SET_MSQUERY_HEAD = SET_NOCOUNT_ON+SET_READ_UNCOMMITTED;

procedure FillParams(ASQLCommand: TDBXCommand; args: OleVariant);
var
  LParamPos: Integer;
  LIsCreated: Boolean;
  LParam: TDBXParameter;
begin
  LIsCreated := ASQLCommand.Parameters.Count > 0;
  //FCommand.Parameters.SetCount((VarArrayHighBound(args, 1) + 1)); // Only set, but it's null!
  if not(VarIsNull(args)) and not(VarIsEmpty(args)) then
    for LParamPos := 0 to (VarArrayHighBound(args, 1)) do
    begin
      if not LIsCreated then
        LParam := ASQLCommand.CreateParameter
      else
        LParam := ASQLCommand.Parameters[LParamPos];
      case VarType(args[LParamPos]) and VarTypeMask of  {$REGION 'begin..end'}
        varInteger:begin
            if not (LParam.DataType=TDBXDataTypes.Int32Type) then LParam.DataType := TDBXDataTypes.Int32Type;
            LParam.Value.AsInt32 := args[LParamPos];
          end;
        varOleStr, varString, varUString:begin
            if not (LParam.DataType=TDBXDataTypes.WideStringType) then LParam.DataType := TDBXDataTypes.WideStringType;
            LParam.Value.AsString := args[LParamPos];
          end;
        varBoolean:begin
            if not (LParam.DataType=TDBXDataTypes.BooleanType) then LParam.DataType := TDBXDataTypes.BooleanType;
            LParam.Value.AsBoolean := args[LParamPos];
          end;
        varDouble:begin
            if not (LParam.DataType=TDBXDataTypes.DoubleType) then LParam.DataType := TDBXDataTypes.DoubleType;
            LParam.Value.AsDouble := args[LParamPos];
          end;
        varDate:begin
            if not (LParam.DataType=TDBXDataTypes.DateTimeType) then LParam.DataType := TDBXDataTypes.DateTimeType;
            LParam.Value.AsDateTime := args[LParamPos];
          end;
        varSmallint:begin
            if not (LParam.DataType=TDBXDataTypes.Int16Type) then LParam.DataType := TDBXDataTypes.Int16Type;
            LParam.Value.AsInt16 := args[LParamPos];
          end;
        varSingle:begin
            if not (LParam.DataType=TDBXDataTypes.SingleType) then LParam.DataType := TDBXDataTypes.SingleType;
            LParam.Value.AsSingle := args[LParamPos];
          end;
        varCurrency:begin
            if not (LParam.DataType=TDBXDataTypes.CurrencyType) then LParam.DataType := TDBXDataTypes.CurrencyType;
            LParam.Value.AsCurrency := args[LParamPos];
          end;
        varShortInt:begin
            if not (LParam.DataType=TDBXDataTypes.Int8Type) then LParam.DataType := TDBXDataTypes.Int8Type;
            LParam.Value.AsInt8 := args[LParamPos];
          end;
        varWord:begin
            if not (LParam.DataType=TDBXDataTypes.UInt16Type) then LParam.DataType := TDBXDataTypes.UInt16Type;
            LParam.Value.AsUInt16 := args[LParamPos];
          end;
        varInt64:begin
            if not (LParam.DataType=TDBXDataTypes.Int64Type) then LParam.DataType := TDBXDataTypes.Int64Type;
            LParam.Value.AsInt64 := args[LParamPos];
          end;
      else
        raise Exception.Create('Invalid Type');
      end;{$ENDREGION}
      if not LIsCreated then
        ASQLCommand.Parameters.AddParameter(LParam);
    end;
end;

{ Factory }

function TDBXMSSQLFactory.Execute(ASQL: string): Int64;
var
  Cmd: TDBXCommand;
begin
  Cmd := GetConnection.CreateCommand;
  try
    Cmd.Text := ASQL;
    Cmd.ExecuteUpdate;
    Result := Cmd.RowsAffected;
  finally
    Cmd.Free;
  end;
end;

function TDBXMSSQLFactory.Prepare(ASQL: string): TDBXCommand;
var
  Cmd: TDBXCommand;
begin
  Cmd := GetConnection.CreateCommand;
  try
    Cmd.Text := ASQL;
    Cmd.Prepare;
  except
    FreeAndNil(Cmd);
    raise;
  end;
  Result := Cmd;
end;

function TDBXMSSQLFactory.PrepareMSQuery(ASQL: string): TDBXCommand;
begin
  Result := Prepare(SET_MSQUERY_HEAD + ASQL); // fixed: Cursor not returned from Query
end;

constructor TDBXMSSQLFactory.Create(const AHostName, ADatabase, AUserName,
  APassword: string);
begin
  inherited Create;

  FConnectionProps := TDBXProperties.Create;
  FConnectionProps.SetProperties(Format(MSSQL_CONNECTION_STRING,
                        [TDBXPropertyNames.DriverName,
                         TDBXPropertyNames.HostName, AHostName,
                         TDBXPropertyNames.Database, ADatabase,
                         TDBXPropertyNames.UserName, AUserName,
                         TDBXPropertyNames.Password, APassword]));
  FConnectionFactory := TDBXConnectionFactory.GetConnectionFactory;
end;

constructor TDBXMSSQLFactory.Create(const AParams: TStrings);
begin
  inherited Create;

  FConnectionProps := TDBXProperties.Create;
  FConnectionProps.MergeProperties(AParams);
  FConnectionFactory := TDBXConnectionFactory.GetConnectionFactory;
end;

destructor TDBXMSSQLFactory.Destroy;
begin
  FreeAndNil(FConnectionProps);
  if Assigned(FDBXConnection) then
  begin
    if FDBXConnection.IsOpen then
      FDBXConnection.Close;
    FreeAndNil(FDBXConnection);
  end;
  inherited;
end;

function TDBXMSSQLFactory.Execute(ASQLCommand: TDBXCommand): Int64;
begin
  ASQLCommand.ExecuteUpdate;
  Result := ASQLCommand.RowsAffected;
end;

function TDBXMSSQLFactory.Execute(ASQL: string; args: OleVariant): Int64;
var
  LDBXCmd: TDBXCommand;
begin
  try
    LDBXCmd := GetConnection.CreateCommand;
    LDBXCmd.CommandType := TDBXCommandTypes.DbxSQL;
    LDBXCmd.Text := ASQL;
    LDBXCmd.Prepare;
    Result := Self.Execute(LDBXCmd, args);
  finally
    FreeAndNil(LDBXCmd);
  end;
end;

function TDBXMSSQLFactory.ExecuteQuery(ASQLCommand: TDBXCommand): TDBXReader;
begin
  Result := ASQLCommand.ExecuteQuery;
end;

function TDBXMSSQLFactory.GetConnection: TDBXConnection;
begin
  if FDBXConnection = nil then
    FDBXConnection := FConnectionFactory.GetConnection(FConnectionProps);
  Result := FDBXConnection;
end;

function TDBXMSSQLFactory.Execute(ASQLCommand: TDBXCommand;
  args: OleVariant): Int64;
begin
  if not ASQLCommand.IsPrepared then
    ASQLCommand.Prepare;
  FillParams(ASQLCommand, args);
  ASQLCommand.ExecuteUpdate;
  Result := ASQLCommand.RowsAffected;
end;

function TDBXMSSQLFactory.ExecuteQuery(ASQLCommand: TDBXCommand;
  args: OleVariant): TDBXReader;
begin
  if not ASQLCommand.IsPrepared then
    ASQLCommand.Prepare;
  FillParams(ASQLCommand, args);
  Result := ASQLCommand.ExecuteQuery;
end;

end.
