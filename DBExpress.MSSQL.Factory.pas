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
    function ExecuteQuery(ASQLCommand: TDBXCommand): TDBXReader;
    function Prepare(ASQL: string): TDBXCommand; overload;
    function Prepare(ASQL: string; args: OleVariant): TDBXCommand; overload;
    property ConnectionProps: TDBXProperties read FConnectionProps;
  end;

implementation

uses
  SysUtils;

// uses DBXDevartSQLServer
const DEVART_MSSQL_CONNECTION_STRING = ''
  +'%s=DevartSQLServer;%s=%s;%s=%s;%s=%s;%s=%s'
  +';BlobSize=-1;SchemaOverride=%%.dbo;LongStrings=True;EnableBCD=True'
  //+';Custom String=ApplicationName=A_NAME;WorkstationID=WID'
  +';FetchAll=True;UseUnicode=True;IPVersion=IPv4';
// uses DbxMsSql
const MSSQL_CONNECTION_STRING = ''
  +'%s=MSSQL;%s=%s;%s=%s;%s=%s;%s=%s'
  +';SchemaOverride=%%.dbo;BlobSize=-1;ErrorResourceFile=;LocaleCode=0000'
  +';IsolationLevel=ReadCommitted;OS Authentication=False;Prepare SQL=True'
  +';ConnectTimeout=60;Mars_Connection=False';

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
  FConnectionProps.Free;
  if Assigned(FDBXConnection) then
  begin
    if FDBXConnection.IsOpen then
      FDBXConnection.Close;
    FDBXConnection.Free;
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
  LParamPos: Integer;
  LParam: TDBXParameter;
  LIsCreated: Boolean;
begin
  Result := -1;
  try
    LDBXCmd := GetConnection.CreateCommand;
    LDBXCmd.CommandType := TDBXCommandTypes.DbxSQL;
    LDBXCmd.Text := ASQL;
    //if not LDBXCmd.IsPrepared then
      LDBXCmd.Prepare;
    LIsCreated := LDBXCmd.Parameters.Count > 0;
    //FCommand.Parameters.SetCount((VarArrayHighBound(args, 1) + 1)); // Only set, but it's null!
    if not(VarIsNull(args)) and not(VarIsEmpty(args)) then
      for LParamPos := 0 to (VarArrayHighBound(args, 1)) do
      begin
        if not LIsCreated then
          LParam := LDBXCmd.CreateParameter
        else
          LParam := LDBXCmd.Parameters[LParamPos];
        case VarType(args[LParamPos]) and VarTypeMask of  {$REGION 'begin..end'}
          varInteger:
            begin
              LParam.DataType := TDBXDataTypes.Int32Type;
              LParam.Value.AsInt32 := args[LParamPos];
            end;
          varOleStr, varString, varUString:
            begin
              LParam.DataType := TDBXDataTypes.WideStringType;
              LParam.Value.AsString := args[LParamPos];
            end;
          varBoolean:
            begin
              LParam.DataType := TDBXDataTypes.BooleanType;
              LParam.Value.AsBoolean := args[LParamPos];
            end;
          varDouble:
            begin
              LParam.DataType := TDBXDataTypes.DoubleType;
              LParam.Value.AsDouble := args[LParamPos];
            end;
          varDate:
            begin
              LParam.DataType := TDBXDataTypes.DateTimeType;
              LParam.Value.AsDateTime := args[LParamPos];
            end;
          varSmallint:
            begin
              LParam.DataType := TDBXDataTypes.Int16Type;
              LParam.Value.AsInt16 := args[LParamPos];
            end;
          varSingle:
            begin
              LParam.DataType := TDBXDataTypes.SingleType;
              LParam.Value.AsSingle := args[LParamPos];
            end;
          varCurrency:
            begin
              LParam.DataType := TDBXDataTypes.CurrencyType;
              LParam.Value.AsCurrency := args[LParamPos];
            end;
          varShortInt:
            begin
              LParam.DataType := TDBXDataTypes.Int8Type;
              LParam.Value.AsInt8 := args[LParamPos];
            end;
          varWord:
            begin
              LParam.DataType := TDBXDataTypes.UInt16Type;
              LParam.Value.AsUInt16 := args[LParamPos];
            end;
          varInt64:
            begin
              LParam.DataType := TDBXDataTypes.Int64Type;
              LParam.Value.AsInt64 := args[LParamPos];
            end;
        else
          raise Exception.Create('Invalid Type');
        end;{$ENDREGION}
        if not LIsCreated then
          LDBXCmd.Parameters.AddParameter(LParam);
      end;
    LDBXCmd.ExecuteUpdate;
    Result := LDBXCmd.RowsAffected;
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

function TDBXMSSQLFactory.Prepare(ASQL: string; args: OleVariant): TDBXCommand;
var
  LDBXCmd: TDBXCommand;
  LParam: TDBXParameter;
  LParamPos: Integer;
  LIsCreated: Boolean;
begin
  Result := nil;
  LDBXCmd := GetConnection.CreateCommand;
  try
    try
      LDBXCmd.Text := ASQL;
      LDBXCmd.Prepare;
      LIsCreated := LDBXCmd.Parameters.Count > 0;
      if not(VarIsNull(args)) and not(VarIsEmpty(args)) then
        for LParamPos := 0 to (VarArrayHighBound(args, 1)) do
        begin
          if not LIsCreated then
            LParam := LDBXCmd.CreateParameter
          else
            LParam := LDBXCmd.Parameters[LParamPos];
          case VarType(args[LParamPos]) and VarTypeMask of {$REGION 'begin..end'}
            varInteger:
              begin
                LParam.DataType := TDBXDataTypes.Int32Type;
                LParam.Value.AsInt32 := args[LParamPos];
              end;
            varOleStr, varString, varUString:
              begin
                LParam.DataType := TDBXDataTypes.WideStringType;
                LParam.Value.AsString := args[LParamPos];
              end;
            varBoolean:
              begin
                LParam.DataType := TDBXDataTypes.BooleanType;
                LParam.Value.AsBoolean := args[LParamPos];
              end;
            varDouble:
              begin
                LParam.DataType := TDBXDataTypes.DoubleType;
                LParam.Value.AsDouble := args[LParamPos];
              end;
            varDate:
              begin
                LParam.DataType := TDBXDataTypes.DateTimeType;
                LParam.Value.AsDateTime := args[LParamPos];
              end;
            varSmallint:
              begin
                LParam.DataType := TDBXDataTypes.Int16Type;
                LParam.Value.AsInt16 := args[LParamPos];
              end;
            varSingle:
              begin
                LParam.DataType := TDBXDataTypes.SingleType;
                LParam.Value.AsSingle := args[LParamPos];
              end;
            varCurrency:
              begin
                LParam.DataType := TDBXDataTypes.CurrencyType;
                LParam.Value.AsCurrency := args[LParamPos];
              end;
            varShortInt:
              begin
                LParam.DataType := TDBXDataTypes.Int8Type;
                LParam.Value.AsInt8 := args[LParamPos];
              end;
            varWord:
              begin
                LParam.DataType := TDBXDataTypes.UInt16Type;
                LParam.Value.AsUInt16 := args[LParamPos];
              end;
            varInt64:
              begin
                LParam.DataType := TDBXDataTypes.Int64Type;
                LParam.Value.AsInt64 := args[LParamPos];
              end;
          else
            raise Exception.Create('Invalid Type');
          end;{$ENDREGION}
          if not LIsCreated then
            LDBXCmd.Parameters.AddParameter(LParam);
        end;
        Result := LDBXCmd;
    finally
    end;
  except
    FreeAndNil(LDBXCmd);
    raise;
  end;
end;

end.
