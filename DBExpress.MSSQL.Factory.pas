unit DBExpress.MSSQL.Factory;

interface

uses
  DBXCommon, Classes, DBXMetaDataProvider, DBXDataExpressMetaDataProvider,
  DbxMsSql, DBXDynalink, Variants, Generics.Collections, DBXTypedTableStorage;

type
  TDBXCommandHelper = class helper for TDBXCommand
    function ParseSQL(DoCreate: Boolean): string;
  end;

  TDBXMSSQLFactory = class
  protected
    FDBXConnection: TDBXConnection;
    FConnectionProps: TDBXProperties;
    FConnectionFactory: TDBXConnectionFactory;
  private
    function DBXGetMetaProvider: TDBXMetaDataProvider;
    function DBXGetTables(const AProvider: TDBXMetaDataProvider): TDBXTablesTableStorage;
  protected
  public
    /// <summary>
    /// Get Table List, ATableType is DBXMetaDataReader.TDBXTableType, have Table, View, Synonym, SystemTable and SystemView
    /// </summary>
    /// <param name="ATableType">DBXMetaDataReader.TDBXTableType</param>
    /// <returns></returns>
    function DBXGetTableList(const ATableType: string=''): TStrings;

    constructor Create(const AHostName, ADatabase, AUserName, APassword: string); overload;
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

procedure FillDBXParamFromVariable(AParam: TDBXParameter; Variable: Variant);
var
  LParam: TDBXParameter;
begin
  LParam := AParam;
  case VarType(Variable) and VarTypeMask of  {$REGION 'begin..end'}
    varInteger:begin
        if not (LParam.DataType=TDBXDataTypes.Int32Type) then LParam.DataType := TDBXDataTypes.Int32Type;
        LParam.Value.AsInt32 := Variable;
      end;
    varOleStr, varString, varUString:begin
        if not (LParam.DataType=TDBXDataTypes.WideStringType) then LParam.DataType := TDBXDataTypes.WideStringType;
        LParam.Value.AsString := Variable;
      end;
    varBoolean:begin
        if not (LParam.DataType=TDBXDataTypes.BooleanType) then LParam.DataType := TDBXDataTypes.BooleanType;
        LParam.Value.AsBoolean := Variable;
      end;
    varDouble:begin
        if not (LParam.DataType=TDBXDataTypes.DoubleType) then LParam.DataType := TDBXDataTypes.DoubleType;
        LParam.Value.AsDouble := Variable;
      end;
    varDate:begin
        if not (LParam.DataType=TDBXDataTypes.DateTimeType) then LParam.DataType := TDBXDataTypes.DateTimeType;
        LParam.Value.AsDateTime := Variable;
      end;
    varSmallint:begin
        if not (LParam.DataType=TDBXDataTypes.Int16Type) then LParam.DataType := TDBXDataTypes.Int16Type;
        LParam.Value.AsInt16 := Variable;
      end;
    varSingle:begin
        if not (LParam.DataType=TDBXDataTypes.SingleType) then LParam.DataType := TDBXDataTypes.SingleType;
        LParam.Value.AsSingle := Variable;
      end;
    varCurrency:begin
        if not (LParam.DataType=TDBXDataTypes.CurrencyType) then LParam.DataType := TDBXDataTypes.CurrencyType;
        LParam.Value.AsCurrency := Variable;
      end;
    varShortInt:begin
        if not (LParam.DataType=TDBXDataTypes.Int8Type) then LParam.DataType := TDBXDataTypes.Int8Type;
        LParam.Value.AsInt8 := Variable;
      end;
    varWord:begin
        if not (LParam.DataType=TDBXDataTypes.UInt16Type) then LParam.DataType := TDBXDataTypes.UInt16Type;
        LParam.Value.AsUInt16 := Variable;
      end;
    varInt64:begin
        if not (LParam.DataType=TDBXDataTypes.Int64Type) then LParam.DataType := TDBXDataTypes.Int64Type;
        LParam.Value.AsInt64 := Variable;
      end;
  else
    raise Exception.Create('Invalid Type');
  end;{$ENDREGION}
end;

procedure FillParams(ASQLCommand: TDBXCommand; args: OleVariant);
var
  LParamPos: Integer;
  LParam: TDBXParameter;
begin
  ASQLCommand.ParseSQL(True);
  //FCommand.Parameters.SetCount((VarArrayHighBound(args, 1) + 1)); // Only set, but it's null!
  if not(VarIsNull(args)) and not(VarIsEmpty(args)) then
    for LParamPos := 0 to (VarArrayHighBound(args, 1)) do
    begin
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
  Result := False;
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

function TDBXCommandHelper.ParseSQL(DoCreate: Boolean): string;

  function NameDelimiter(CurChar: Char): Boolean;
  begin
    case CurChar of
      ' ', ',', ';', ')', #13, #10:
        Result := True;
    else
      Result := False;
    end;
  end;

var
  LiteralChar, CurChar: Char;
  CurPos, StartPos, BeginPos, NameStart: PChar;
  Name: string;
  LParam: TDBXParameter;
begin
  Result := '';

  if DoCreate then
    Parameters.ClearParameters;

  StartPos := PChar(Text);
  BeginPos := StartPos;
  CurPos := StartPos;
  while True do
  begin
    // Fast forward
    while True do
    begin
      case CurPos^ of
        #0, ':', '''', '"', '`':
          Break;
      end;
      Inc(CurPos);
    end;

    case CurPos^ of
      #0: // string end
        Break;
      '''', '"', '`': // literal
        begin
          LiteralChar := CurPos^;
          Inc(CurPos);
          // skip literal, escaped literal chars must not be handled because they
          // end the string and start a new string immediately.
          while (CurPos^ <> #0) and (CurPos^ <> LiteralChar) do
            Inc(CurPos);
          if CurPos^ = #0 then
            Break;
          Inc(CurPos);
        end;
      ':': // parameter
        begin
          Inc(CurPos);
          if CurPos^ = ':' then
            Inc(CurPos) // skip escaped ":"
          else
          begin
            Result := Result + Copy(Text, StartPos - BeginPos + 1, CurPos - StartPos - 1) + '?';

            LiteralChar := #0;
            case CurPos^ of
              '''', '"', '`':
                begin
                  LiteralChar := CurPos^;
                  Inc(CurPos);
                end;
            end;
            NameStart := CurPos;

            CurChar := CurPos^;
            while CurChar <> #0 do
            begin
              if (CurChar = LiteralChar) or
                  ((LiteralChar = #0) and NameDelimiter(CurChar)) then
                Break;
              Inc(CurPos);
              CurChar := CurPos^;
            end;
            SetString(Name, NameStart, CurPos - NameStart);
            if LiteralChar <> #0 then
              Inc(CurPos);
            if DoCreate then
            begin
              LParam := CreateParameter;
              LParam.Name := Name;
              Parameters.AddParameter(LParam);
            end;

            StartPos := CurPos;
          end;
        end;
    end;
  end;
  Result := Result + Copy(Text, StartPos - BeginPos + 1, CurPos - StartPos);
end;

end.
