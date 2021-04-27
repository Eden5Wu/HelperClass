unit DBExpress.MSSQL.Factory;

interface

uses
  DBXCommon, Classes, DBXMetaDataProvider, DBXDataExpressMetaDataProvider, DB,
  DbxMsSql,
  DBXDynalink, Variants, Generics.Collections, DBXTypedTableStorage;

type
  TDBXCommandHelper = class helper for TDBXCommand
    /// <seealso>https://forums.devart.com/viewtopic.php?t=22342</seealso>
    /// <code>
    /// DBXPar := DBXCmd.CreateParameter;
    /// DBXPar.DataType := TDBXDataTypes.BlobType;
    /// DBXPar.Value.SetStream(TFileStream.Create(sArqXml, fmOpenRead), True);
    /// DBXPar.Value.ValueType.ValueTypeFlags := DBXPar.Value.ValueType.ValueTypeFlags or TDBXValueTypeFlags.ExtendedType;
    ///
    /// DBXCmd.Parameters.AddParameter(DBXPar);
    /// </code>
    function CreateBlobParameter: TDBXParameter;
  end;

  TDBXParameterHelper = class helper for TDBXParameter
  private
    function GetAsString: string;
    procedure SetAsString(const AValue: string);
    function GetAsAnsiString: AnsiString;
    procedure SetAsAnsiString(const AValue: AnsiString);
    function GetAsDouble: Double;
    procedure SetAsDouble(const AValue: Double);
    function GetAsInt32: TInt32;
    procedure SetAsInt32(const AValue: TInt32);
    function GetAsBoolean: Boolean;
    procedure SetAsBoolean(const AValue: Boolean);
    function GetAsDateTime: TDateTime;
    procedure SetAsDateTime(const AValue: TDateTime);
  public
    procedure Clear;

    property AsDouble: Double read GetAsDouble write SetAsDouble;
    property AsString: string read GetAsString write SetAsString;
    property AsAnsiString: AnsiString read GetAsAnsiString write SetAsAnsiString;
    property AsInt32: TInt32 read GetAsInt32 write SetAsInt32;
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsDateTime: TDateTime read GetAsDateTime write SetAsDateTime;
  end;

  TDBXMSSQLFactory = class
  protected
    FDBXConnection: TDBXConnection;
    FConnectionProps: TDBXProperties;
    FConnectionFactory: TDBXConnectionFactory;
  private
    function DBXGetMetaProvider: TDBXMetaDataProvider;
    function DBXGetTables(const AProvider: TDBXMetaDataProvider): TDBXTablesTableStorage;
  public
    /// <summary>
    /// Get Table List, ATableType is DBXMetaDataReader.TDBXTableType, have Table, View, Synonym, SystemTable and SystemView
    /// </summary>
    /// <param name="ATableType">DBXMetaDataReader.TDBXTableType</param>
    /// <returns></returns>
    function DBXGetTableList(const ATableType: string=''): TStrings;

    constructor Create(const AHostName, ADatabase, AUserName, APassword: string; const OSAuthentication: Boolean=False); overload;
    constructor Create(const AParams: TStrings); overload;
    destructor Destroy; override;

    function FillParameters(AParams: TDBXParameterList; AVariableList: TList<Variant>):Boolean;

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
  SysUtils, StrUtils, SqlTimSt;

const MSSQL_CONNECTION_STRING = ''
  +'%s=MSSQL;%s=%s;%s=%s;%s=%s;%s=%s'
  +';SchemaOverride=%%.dbo;BlobSize=-1;ErrorResourceFile=;LocaleCode=0000'
  +';IsolationLevel=ReadCommitted;OS Authentication=%s;Prepare SQL=True'
  +';ConnectTimeout=60;Mars_Connection=False';

/// <summary> fixed: Cursor not returned from Query </summary>
const SET_NOCOUNT_ON = 'SET NOCOUNT ON;'#13#10;
const SET_READ_UNCOMMITTED = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;'#13#10;
const SET_MSQUERY_HEAD = SET_NOCOUNT_ON+SET_READ_UNCOMMITTED;

procedure FillDBXParamFromVariable(AParam: TDBXParameter; Variable: Variant);
begin
  case VarType(Variable) and VarTypeMask of  {$REGION 'begin..end'}
    varInteger:begin
        if not (AParam.DataType=TDBXDataTypes.Int32Type) then AParam.DataType := TDBXDataTypes.Int32Type;
        AParam.Value.AsInt32 := Variable;
      end;
    varOleStr, varString, varUString:begin
        if not (AParam.DataType=TDBXDataTypes.WideStringType) then AParam.DataType := TDBXDataTypes.WideStringType;
        AParam.Value.AsString := Variable;
      end;
    varBoolean:begin
        if not (AParam.DataType=TDBXDataTypes.BooleanType) then AParam.DataType := TDBXDataTypes.BooleanType;
        AParam.Value.AsBoolean := Variable;
      end;
    varDouble:begin
        if not (AParam.DataType=TDBXDataTypes.DoubleType) then AParam.DataType := TDBXDataTypes.DoubleType;
        AParam.Value.AsDouble := Variable;
      end;
    varDate:begin
        if not (AParam.DataType=TDBXDataTypes.DateTimeType) then AParam.DataType := TDBXDataTypes.DateTimeType;
        AParam.Value.AsDateTime := Variable;
      end;
    varSmallint:begin
        if not (AParam.DataType=TDBXDataTypes.Int16Type) then AParam.DataType := TDBXDataTypes.Int16Type;
        AParam.Value.AsInt16 := Variable;
      end;
    varSingle:begin
        if not (AParam.DataType=TDBXDataTypes.SingleType) then AParam.DataType := TDBXDataTypes.SingleType;
        AParam.Value.AsSingle := Variable;
      end;
    varCurrency:begin
        if not (AParam.DataType=TDBXDataTypes.CurrencyType) then AParam.DataType := TDBXDataTypes.CurrencyType;
        AParam.Value.AsCurrency := Variable;
      end;
    varShortInt:begin
        if not (AParam.DataType=TDBXDataTypes.Int8Type) then AParam.DataType := TDBXDataTypes.Int8Type;
        AParam.Value.AsInt8 := Variable;
      end;
    varWord:begin
        if not (AParam.DataType=TDBXDataTypes.UInt16Type) then AParam.DataType := TDBXDataTypes.UInt16Type;
        AParam.Value.AsUInt16 := Variable;
      end;
    varInt64:begin
        if not (AParam.DataType=TDBXDataTypes.Int64Type) then AParam.DataType := TDBXDataTypes.Int64Type;
        AParam.Value.AsInt64 := Variable;
      end;
  else
    raise Exception.Create('Invalid Type');
  end;{$ENDREGION}
end;

procedure FillParams(ASQLCommand: TDBXCommand; args: OleVariant);
var
  LParamPos: Integer;
begin
  ASQLCommand.Prepare;
  //FCommand.Parameters.SetCount((VarArrayHighBound(args, 1) + 1)); // Only set, but it's null!
  if not(VarIsNull(args)) and not(VarIsEmpty(args)) then
    for LParamPos := 0 to (VarArrayHighBound(args, 1)) do
    begin
      FillDBXParamFromVariable(ASQLCommand.Parameters[LParamPos], args[LParamPos]);
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
  APassword: string; const OSAuthentication: Boolean=False);
begin
  inherited Create;

  FConnectionProps := TDBXProperties.Create;
  FConnectionProps.SetProperties(Format(MSSQL_CONNECTION_STRING,
                        [TDBXPropertyNames.DriverName,
                         TDBXPropertyNames.HostName, AHostName,
                         TDBXPropertyNames.Database, ADatabase,
                         TDBXPropertyNames.UserName, AUserName,
                         TDBXPropertyNames.Password, APassword,
                         IfThen(OSAuthentication, 'True', 'False')]));
  FConnectionFactory := TDBXConnectionFactory.GetConnectionFactory;
end;

constructor TDBXMSSQLFactory.Create(const AParams: TStrings);
begin
  inherited Create;

  FConnectionProps := TDBXProperties.Create;
  FConnectionProps.MergeProperties(AParams);
  FConnectionFactory := TDBXConnectionFactory.GetConnectionFactory;
end;

function TDBXMSSQLFactory.DBXGetMetaProvider: TDBXMetaDataProvider;
var
  Provider: TDBXDataExpressMetaDataProvider;

begin
  Provider := TDBXDataExpressMetaDataProvider.Create;
  try
    Provider.Connection := FDBXConnection;
    Provider.Open;
  except
    FreeAndNil(Provider);
    raise;

  end;
  Result := Provider;
end;

function TDBXMSSQLFactory.DBXGetTableList(const ATableType: string=''): TStrings;
var
  LProvider: TDBXMetaDataProvider;
  Tables: TDBXTablesTableStorage;
begin
  Result := TStringList.Create;
  LProvider := Self.DBXGetMetaProvider;
  Tables := DBXGetTables(LProvider);
  try
    while Tables.InBounds do
    begin
      if (Length(ATableType) = 0)
        or SameText(Tables.TableType, ATableType,
            TLocaleOptions.loInvariantLocale) then
      begin
        Result.Add(Tables.TableName);
      end;
      Tables.Next;
    end;

  finally
    FreeAndNil(Tables);
    FreeAndNil(LProvider);
  end;
end;

function TDBXMSSQLFactory.DBXGetTables(const AProvider: TDBXMetaDataProvider): TDBXTablesTableStorage;
begin
  Result := AProvider.GetCollection(TDBXMetaDataCommands.GetTables) as TDBXTablesTableStorage;
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
    FillParams(LDBXCmd, args);  //LDBXCmd.Prepare;
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
  FillParams(ASQLCommand, args);
  ASQLCommand.ExecuteUpdate;
  Result := ASQLCommand.RowsAffected;
end;

function TDBXMSSQLFactory.ExecuteQuery(ASQLCommand: TDBXCommand;
  args: OleVariant): TDBXReader;
begin
  FillParams(ASQLCommand, args);
  Result := ASQLCommand.ExecuteQuery;
end;

function TDBXMSSQLFactory.FillParameters(AParams: TDBXParameterList;
  AVariableList: TList<Variant>): Boolean;
var
  LItor: Integer;
begin
  try
    for LItor := 0 to AParams.Count-1 do
    begin
      FillDBXParamFromVariable(AParams[LItor], AVariableList.Items[LItor]);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      raise E;
      {$ENDIF}
    end;
  end;
end;

{ TDBXCommandHelper }

function TDBXCommandHelper.CreateBlobParameter: TDBXParameter;
begin
  Result := TDBXParameter.Create(FDbxContext);
  Result.DataType := TDBXDataTypes.BlobType;
  Result.ValueTypeFlags := Result.ValueTypeFlags or TDBXValueTypeFlags.ExtendedType;
end;

{ TDBXParameterHelper }

procedure TDBXParameterHelper.Clear;
begin
  Value.SetNull;
end;

function TDBXParameterHelper.GetAsAnsiString: AnsiString;
begin
  Result := Value.GetAnsiString;
end;

function TDBXParameterHelper.GetAsBoolean: Boolean;
begin
  Result := Value.GetBoolean;
end;

function TDBXParameterHelper.GetAsDateTime: TDateTime;
begin
  Result := Value.AsDateTime;
end;

function TDBXParameterHelper.GetAsDouble: Double;
begin
  Result := Value.GetDouble;
end;

function TDBXParameterHelper.GetAsInt32: TInt32;
begin
  Result := Value.GetInt32;
end;

function TDBXParameterHelper.GetAsString: string;
begin
  Result := Value.GetWideString;
end;

procedure TDBXParameterHelper.SetAsAnsiString(const AValue: AnsiString);
begin
  DataType := TDBXDataTypes.AnsiStringType;
  Value.SetAnsiString(AValue);
end;

procedure TDBXParameterHelper.SetAsBoolean(const AValue: Boolean);
begin
  DataType := TDBXDataTypes.BooleanType;
  Value.SetBoolean(AValue);
end;

procedure TDBXParameterHelper.SetAsDateTime(const AValue: TDateTime);
begin
  DataType := TDBXDataTypes.TimeStampType;
  Value.SetTimeStamp(DateTimeToSQLTimeStamp(AValue));
end;

procedure TDBXParameterHelper.SetAsDouble(const AValue: Double);
begin
  DataType := TDBXDataTypes.DoubleType;
  Value.SetDouble(AValue);
end;

procedure TDBXParameterHelper.SetAsInt32(const AValue: TInt32);
begin
  DataType := TDBXDataTypes.Int32Type;
  Value.SetInt32(AValue);
end;

procedure TDBXParameterHelper.SetAsString(const AValue: string);
begin
  DataType := TDBXDataTypes.WideStringType;
  Value.SetWideString(AValue);
end;

end.
