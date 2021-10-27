unit EdenDBXJsonHelper;

interface

uses
  DBXCommon, SysUtils, DBXJSONCommon, Classes,
  {$IF CompilerVersion >= 28} System.JSON {$ELSE} DBXJSON {$IFEND},
  DB, Variants;

type
  // Reference: delphi-rest-client-api
  TJSONValueHelper = class helper for TJSONValue
  private
  public
    function HasJsonValue(const APath: string=''): Boolean;

    function IsJsonNumber: Boolean;
    function IsJsonTrue: Boolean;
    function IsJsonFalse: Boolean;
    function IsJsonString: Boolean;
    function IsJsonNull: Boolean;
    function IsJsonObject: Boolean;
    function IsJsonArray: Boolean;

    function AsJsonNumber: TJSONNumber;
    function AsJsonString: TJSONString;
    function AsJsonObject: TJSONObject;
    function AsJsonArray: TJSONArray;
    function AsVariant: Variant;
  end;

  TJSONObjectHelper = class helper for TJSONObject
    /// <summary> Returns a JSON pair based on the pair string part.
    ///  The search is case sensitive and it returns the fist pair with string part matching the argument </summary>
    /// <param name="APairName">- string: the  pair string part</param>
    /// <returns>- JSONPair : first pair encountered, null otherwise</returns>
    function FetchValue(const APairName: string): TJSONValue;

    function TryFetchValue(const APath: string; out AValue: string): Boolean; overload;
    function TryFetchValue(const APath: string; out AValue: Int64): Boolean; overload;
    function TryFetchValue(const APath: string; out AValue: Double): Boolean; overload;
    function TryFetchValue(const APath: string; out AValue: Boolean): Boolean; overload;

    function GetVariant(const Name: string): Variant;
    function GetValueToJO(const Name: string): TJSONObject;
    function GetValueToJA(const Name: string): TJSONArray;
  end;
{$IF CompilerVersion < 28}
  TJSONArrayHelper = class helper for TJSONArray
  private
    function GetValue(const Index: Integer): TJSONValue;
  public
    function Count: Integer;
    property Items[const Index: Integer]: TJSONValue read GetValue;
  end;
{$IFEND}
  TJSONAncestorHelper = class helper for TJsonAncestor
  public
    function ToJson(): string;
  end;

  TJSONNumberHelper = class helper for TJsonNumber
  public
    function AsInt64: Int64;
  end;
  // end Reference: delphi-rest-client-api

  TDBXJSONToolsHelper = class helper for TDBXJSONTools
  public
    class procedure FetchParamToDBXParameter(AParam: TParam; ADBXParameter: TDBXParameter);
    /// <summary> Creates the JSON equivalent of a DBX table. The result is suitable for asynchronous
    /// </summary>
    /// <remarks> The result is suitable for asynchronous
    ///  calls and should not be used for large table. It is recommended use of Data Converters
    ///  if the table is expected to be large
    ///
    ///  The caller assumes JSON object ownership
    ///
    /// </remarks>
    /// <param name="value">DBXReader object, never null</param>
    /// <param name="RowCount">Set result records</param>
    /// <param name="isLocalConnection">true if the connection is in-process, dictates memory ownership policy</param>
    /// <param name="RecNo">Set TDataSet.RecNo</param>
    /// <returns>JSON equivalent</returns>
    class function TableToJSONArray(const Value: TDBXReader; const RowCount: Integer=-1; const IsLocalConnection: Boolean=True; const RecNo: Integer=1): TJSONArray; static;
    class function TableRecToJSONObj(const Value: TDBXReader; const RecNo: Integer = 1; const IsLocalConnection: Boolean=True): TJSONObject; static;
    class function DataSetToJSONArray(ADataSet: TDataSet; const RowCount: Integer=-1; const RecNo: Integer=1): TJSONArray;
    class function DataSetToDJSON(ADataSet: TDataSet; const RowCount: Integer=-1; const RecNo: Integer=1): TJSONObject; static;
    class function DataSetRecToJSONObj(ADataSet: TDataSet): TJSONObject;
    class function TableToJSONB(const Value: TDBXReader; const RowCount: Integer=-1; const IsLocalConnection: Boolean=True; const RecNo: Integer=1): TJSONObject; static;
  end;

{$IF CompilerVersion < 28}
  function DateToISO8601(const ADate: TDateTime; AInputIsUTC: Boolean = True): string;
{$IFEND}

implementation

uses
  DateUtils, DBXDBReaders, DBXPlatform, DBXCommonResStrs, Math;

const TABLE_PAIR = 'table';

{$IF CompilerVersion < 28}
function DateToISO8601(const ADate: TDateTime; AInputIsUTC: Boolean = True): string;
const
  SDateFormat: string = 'yyyy''-''mm''-''dd''T''hh'':''nn'':''ss''.''zzz''Z'''; { Do not localize }
  SOffsetFormat: string = '%s%s%.02d:%.02d'; { Do not localize }
  Neg: array[Boolean] of string = ('+', '-'); { Do not localize }
var
  Bias: Integer;
  TimeZone: TTimeZone;
begin
  Result := FormatDateTime(SDateFormat, ADate);
  if not AInputIsUTC then
  begin
    TimeZone := TTimeZone.Local;
    Bias := Trunc(TimeZone.GetUTCOffset(ADate).Negate.TotalMinutes);
    if Bias <> 0 then
    begin
      // Remove the Z, in order to add the UTC_Offset to the string.
      SetLength(Result, Length(Result) - 1);
      Result := Format(SOffsetFormat, [Result, Neg[Bias > 0], Abs(Bias) div MinsPerHour,
        Abs(Bias) mod MinsPerHour]);
    end
  end;
end;
{$IFEND}

function DBXToJSONValueEx(const Value: TDBXValue; const DataType: Integer;
  const IsLocalConnection: Boolean): TJSONValue;
var
  LReader: TDBXReader;
  LStream: TStream;
begin
  if Value = nil then
    Result := nil
  else if Value.IsNull then
    Result := TJSONNull.Create
  else
    case DataType of
      TDBXDataTypes.JsonValueType:
        Result := Value.GetJSONValue(False);
      TDBXDataTypes.Int8Type,
      TDBXDataTypes.Int16Type,
      TDBXDataTypes.Int32Type,
      TDBXDataTypes.UInt16Type,
      TDBXDataTypes.UInt32Type,
      TDBXDataTypes.DoubleType,
      TDBXDataTypes.CurrencyType,
      TDBXDataTypes.BcdType:
        Result := TJSONNumber.Create(Value.AsDouble);
      TDBXDataTypes.UInt64Type,
      TDBXDataTypes.Int64Type:
        Result := TJSONNumber.Create(Value.AsInt64);
      TDBXDataTypes.SingleType:
        Result := TJSONNumber.Create(Value.AsSingle);
      TDBXDataTypes.UInt8Type:
        Result := TJSONNumber.Create(Value.AsUInt8);
      TDBXDataTypes.BooleanType:
        if Value.GetBoolean then
          Result := TJSONTrue.Create
        else
          Result := TJSONFalse.Create;
      TDBXDataTypes.AnsiStringType,
      //TDBXDataTypes.TimeStampType,
      TDBXDataTypes.WideStringType,
      //TDBXDataTypes.DateType,
      //TDBXDataTypes.DatetimeType,
      TDBXDataTypes.TimeType:
        Result := TJSONString.Create(Value.AsString);
      TDBXDataTypes.DateType:
        Result := TJSONString.Create(FormatDateTime('yyyy-mm-dd',Value.AsDateTime));
      TDBXDataTypes.TimeStampType,
      TDBXDataTypes.DatetimeType:
        Result := TJSONString.Create(DateToISO8601(Value.AsDateTime, False));
      TDBXDataTypes.TableType:
        if IsLocalConnection then
        begin
          LReader := Value.GetDBXReader(False);
          Result := TDBXJSONTools.TableToJSONArray(LReader, High(Integer), IsLocalConnection);
        end
        else
        begin
          LReader := Value.GetDBXReader;
          Result := TDBXJSONTools.TableToJSONArray(LReader, High(Integer), IsLocalConnection);
        end;
      TDBXDataTypes.BlobType,
      TDBXDataTypes.BinaryBlobType,
      TDBXDataTypes.BytesType: begin
        // Reference by : https://stackoverflow.com/questions/3881720/delphi-convert-byte-array-to-string
        // to AnsiString
        //SetString(AnsiStr, PAnsiChar(@ByteArray[0]), LengthOfByteArray);

        // to String
        //SetString(UnicodeStr, PWideChar(@bytes[0]), value.GetValueSize div 2);
        //Result := TJSONString.Create(UnicodeStr);

        // to Bytes To Array
        LStream := TDBXStreamValue(Value).GetStream(True);
        if TDBXStreamValue(Value).IsNull then // GetBytes (GetStream裡有用到) 後 IsNull 才會正確，詳見 TDBXByteArrayValue 官方註解
          Result := TJSONNull.Create
        else
          Result := TDBXJSONTools.StreamToJSON(LStream, 0, High(Integer));
      end
    else
      raise TDBXError.Create(0, Format(SNoConversionToJSON, [TDBXValueType.DataTypeName(DataType)]));
    end;
end;

function DBXToJSONValueB(const Value: TDBXValue; const DataType: Integer;
  const IsLocalConnection: Boolean): TJSONValue;
var
  LReader: TDBXReader;
  LStream: TStream;
begin
  if Value = nil then
    Result := nil
  else if Value.IsNull then
    Result := TJSONNull.Create
  else
    case DataType of
      TDBXDataTypes.JsonValueType:
        Result := Value.GetJSONValue(False);
      TDBXDataTypes.Int8Type,
      TDBXDataTypes.Int16Type,
      TDBXDataTypes.Int32Type,
      TDBXDataTypes.UInt16Type,
      TDBXDataTypes.UInt32Type,
      TDBXDataTypes.DoubleType,
      TDBXDataTypes.CurrencyType,
      TDBXDataTypes.BcdType:
        Result := TJSONNumber.Create(Value.AsDouble);
      TDBXDataTypes.UInt64Type,
      TDBXDataTypes.Int64Type:
        Result := TJSONNumber.Create(Value.AsInt64);
      TDBXDataTypes.SingleType:
        Result := TJSONNumber.Create(Value.AsSingle);
      TDBXDataTypes.UInt8Type:
        Result := TJSONNumber.Create(Value.AsUInt8);
      TDBXDataTypes.BooleanType:
        if Value.GetBoolean then
          Result := TJSONTrue.Create
        else
          Result := TJSONFalse.Create;
      TDBXDataTypes.AnsiStringType,
      //TDBXDataTypes.TimeStampType,
      TDBXDataTypes.WideStringType,
      //TDBXDataTypes.DateType,
      //TDBXDataTypes.DatetimeType,
      TDBXDataTypes.TimeType:
        Result := TJSONString.Create(Value.AsString);
      TDBXDataTypes.DateType:
        Result := TJSONString.Create(FormatDateTime('yyyy-mm-dd',Value.AsDateTime));
      TDBXDataTypes.TimeStampType,
      TDBXDataTypes.DatetimeType:
        Result := TJSONString.Create(DateToISO8601(Value.AsDateTime, False));
      TDBXDataTypes.TableType:
        if IsLocalConnection then
        begin
          LReader := Value.GetDBXReader(False);
          Result := TDBXJSONTools.TableToJSONB(LReader, High(Integer), IsLocalConnection);
        end
        else
        begin
          LReader := Value.GetDBXReader;
          Result := TDBXJSONTools.TableToJSONB(LReader, High(Integer), IsLocalConnection);
        end;
      TDBXDataTypes.BlobType,
      TDBXDataTypes.BinaryBlobType,
      TDBXDataTypes.BytesType: begin
        // Reference by : https://stackoverflow.com/questions/3881720/delphi-convert-byte-array-to-string
        // to AnsiString
        //SetString(AnsiStr, PAnsiChar(@ByteArray[0]), LengthOfByteArray);

        // to String
        //SetString(UnicodeStr, PWideChar(@bytes[0]), value.GetValueSize div 2);
        //Result := TJSONString.Create(UnicodeStr);

        // to Bytes To Array
        LStream := TDBXStreamValue(Value).GetStream(True);
        if TDBXStreamValue(Value).IsNull then // GetBytes (GetStream裡有用到) 後 IsNull 才會正確，詳見 TDBXByteArrayValue 官方註解
          Result := TJSONNull.Create
        else
          Result := TDBXJSONTools.StreamToJSON(LStream, 0, High(Integer));
      end
    else
      raise TDBXError.Create(0, Format(SNoConversionToJSON, [TDBXValueType.DataTypeName(DataType)]));
    end;
end;

{ TDBXJSONToolsHelper }

class function TDBXJSONToolsHelper.DataSetRecToJSONObj(
  ADataSet: TDataSet): TJSONObject;
var
  DBXReader: TDBXReader;
  JsonCell: TJSONValue;
  Pos01, PosRec, LRecNo: Integer;
begin
  if (not Assigned(ADataSet)) or (ADataSet.IsEmpty) then
    Exit(TJSONObject.Create);

  LRecNo := ADataSet.RecNo;
  if LRecNo < 1 then LRecNo := 1;
  DBXReader := TDBXDataSetReader.Create(ADataSet, False);
  Result := TJSONObject.Create;
  PosRec := 1;
  while DBXReader.Next do
  begin
    if PosRec = LRecNo then
    begin
      for Pos01 := 0 to DBXReader.ColumnCount-1 do begin
        if (ADataSet.Fields[Pos01].DataType in [ftMemo, ftWideMemo]) then
          JsonCell := DBXToJSONValueEx(DBXReader.Value[Pos01], TDBXDataTypes.WideStringType, True)
        else
          JsonCell := DBXToJSONValueEx(DBXReader.Value[Pos01], DBXReader.ValueType[Pos01].DataType, True);
        Result.AddPair(DBXReader.ValueType[Pos01].Name, JsonCell);
      end;
      Break;
    end;
    Inc(PosRec);
  end;
  DBXReader.Close;
  DBXReader.Free;
end;

class function TDBXJSONToolsHelper.DataSetToDJSON(ADataSet: TDataSet;
  const RowCount, RecNo: Integer): TJSONObject;
var
  LRowCount: Integer;
begin
  if (not Assigned(ADataSet)) or (ADataSet.IsEmpty) then
    Exit(TJSONObject.Create);

  if RowCount = -1 then
    LRowCount := High(Integer)
  else
    LRowCount := RowCount;

  Result := TDBXJSONTools.TableToJSONB(TDBXDataSetReader.Create(ADataSet, False), LRowCount, True, RecNo);
end;

class function TDBXJSONToolsHelper.DataSetToJSONArray(
  ADataSet: TDataSet; const RowCount, RecNo: Integer): TJSONArray;
var
  DBXReader: TDBXReader;
  JObj: TJSONObject;
  JsonCell: TJSONValue;
  Pos01, LRowCount, LRecPos: Integer;
begin
  if (not Assigned(ADataSet)) or (ADataSet.IsEmpty) then
    Exit(TJSONArray.Create);

  DBXReader := TDBXDataSetReader.Create(ADataSet, False);

  if RowCount = -1 then
    LRowCount := High(Integer)
  else
    LRowCount := RowCount;

  LRecPos := 1;

  Result := TJSONArray.Create;
  while (DBXReader.Next) and (LRowCount > 0) do
  begin
    if LRecPos >= RecNo then
    begin
      JObj := TJSONObject.Create;
      for Pos01 := 0 to DBXReader.ColumnCount-1 do begin
        if (ADataSet.Fields[Pos01].DataType in [ftMemo, ftWideMemo]) then
          JsonCell := DBXToJSONValueEx(DBXReader.Value[Pos01], TDBXDataTypes.WideStringType, True)
        else
          JsonCell := DBXToJSONValueEx(DBXReader.Value[Pos01], DBXReader.ValueType[Pos01].DataType, True);
        JObj.AddPair(DBXReader.ValueType[Pos01].Name, JsonCell);
      end;
      Result.AddElement(JObj);
      DecrAfter(LRowCount);
    end
    else
      Inc(LRecPos);
  end;
  DBXReader.Close;
  DBXReader.Free;
end;

class procedure TDBXJSONToolsHelper.FetchParamToDBXParameter(AParam: TParam;
  ADBXParameter: TDBXParameter);
begin {保留這段只為了之後重寫可以少一點}
  case AParam.DataType of
    ftString: begin
      ADBXParameter.DataType := TDBXDataTypes.AnsiStringType;
      ADBXParameter.Value.SetAnsiString(AParam.AsAnsiString);
    end;
    ftDate: begin
      ADBXParameter.DataType := TDBXDataTypes.DateType;
      ADBXParameter.Value.SetString(AParam.AsString);
    end;
    ftBoolean: begin
      ADBXParameter.DataType := TDBXDataTypes.BooleanType;
      ADBXParameter.Value.SetBoolean(AParam.AsBoolean);
    end;
    ftInteger, ftWord: begin
      ADBXParameter.DataType := TDBXDataTypes.Int32Type;
      ADBXParameter.Value.SetInt32(AParam.AsInteger);
    end;
    ftFloat: begin
      ADBXParameter.DataType := TDBXDataTypes.DoubleType;
      ADBXParameter.Value.SetDouble(AParam.AsFloat);
    end;
    ftBCD: begin
      ADBXParameter.DataType := TDBXDataTypes.BcdType;
      ADBXParameter.Value.SetBcd(AParam.AsFMTBCD);
    end;
    ftTime: begin
      ADBXParameter.DataType := TDBXDataTypes.TimeType;
      ADBXParameter.Value.SetString(AParam.AsString);
    end;
    ftDateTime: begin
      ADBXParameter.DataType := TDBXDataTypes.DateTimeType;
      ADBXParameter.Value.AsDateTime := (AParam.AsDateTime);
    end;
    ftLargeint: begin
      ADBXParameter.DataType := TDBXDataTypes.Int64Type;
      ADBXParameter.Value.SetInt64(AParam.AsLargeInt);
    end;
    ftTimeStamp: begin
      ADBXParameter.DataType := TDBXDataTypes.TimeStampType;
      ADBXParameter.Value.SetTimeStamp(AParam.AsSQLTimeStamp);
    end;
    ftCurrency: begin
      ADBXParameter.DataType := TDBXDataTypes.CurrencyType;
      ADBXParameter.Value.AsCurrency := (AParam.AsCurrency);
    end;
    ftWideString: begin
      ADBXParameter.DataType := TDBXDataTypes.WideStringType;
      ADBXParameter.Value.SetWideString(AParam.AsWideString);
    end;
    ftBlob: begin
      ADBXParameter.DataType := TDBXDataTypes.BinaryBlobType;
      ADBXParameter.Value.SetStream(AParam.AsStream, False);
    end;
    ftWideMemo, ftMemo: begin
      ADBXParameter.DataType := TDBXDataTypes.WideStringType;
      ADBXParameter.Value.SetWideString(AParam.AsWideString);
    end
  else
    raise TDBXError.Create('invalid field type');
  end;
end;

class function TDBXJSONToolsHelper.TableRecToJSONObj(const Value: TDBXReader;
  const RecNo: Integer; const IsLocalConnection: Boolean): TJSONObject;
var
  JsonCell: TJSONValue;
  LPos01, LRecPos: Integer;
begin
  if Value = nil then
    Exit(TJSONObject.Create);

  Result := TJSONObject.Create;

  LRecPos := 1;
  Value.Reset;
  while Value.Next do
  begin
    if LRecPos = RecNo then
    begin
      for LPos01 := 0 to Value.ColumnCount-1 do
      begin
        if Value.ValueType[LPos01].DataType in [TDBXDataTypes.BlobType, TDBXDataTypes.BinaryBlobType] then
        begin
          if Value.ValueType[LPos01].SubType in [TDBXDataTypes.MemoSubType, TDBXDataTypes.WideMemoSubType] then
            JsonCell := DBXToJSONValueEx(Value.Value[LPos01], TDBXDataTypes.WideStringType, True)
          else
            JsonCell := DBXToJSONValueEx(Value.Value[LPos01], Value.ValueType[LPos01].DataType, True);
        end
        else
          JsonCell := DBXToJSONValueEx(Value.Value[LPos01], Value.ValueType[LPos01].DataType, True);
        Result.AddPair(Value.ValueType[LPos01].Name, JsonCell);
      end;
      Break;
    end
    else
      Inc(LRecPos)
  end;
  Value.Close;
  if IsLocalConnection then
    Value.Free;
end;

class function TDBXJSONToolsHelper.TableToJSONArray(const Value: TDBXReader;
  const RowCount: Integer; const IsLocalConnection: Boolean; const RecNo: Integer): TJSONArray;
var
  JObj: TJSONObject;
  JsonCell: TJSONValue;
  LPos01, LRowCount, LRecPos: Integer;
begin
  if Value = nil then
    Exit(TJSONArray.Create);

  if RowCount = -1 then
    LRowCount := High(Integer)
  else
    LRowCount := RowCount;

  LRecPos := 1;

  Result := TJSONArray.Create;
  while Value.Next and (LRowCount > 0) do
  begin
    if LRecPos >= RecNo then
    begin
      JObj := TJSONObject.Create;
      for LPos01 := 0 to Value.ColumnCount-1 do
      begin
        if Value.ValueType[LPos01].DataType in [TDBXDataTypes.BlobType, TDBXDataTypes.BinaryBlobType] then
        begin
          if Value.ValueType[LPos01].SubType in [TDBXDataTypes.MemoSubType, TDBXDataTypes.WideMemoSubType] then
            JsonCell := DBXToJSONValueEx(Value.Value[LPos01], TDBXDataTypes.WideStringType, True)
          else
            JsonCell := DBXToJSONValueEx(Value.Value[LPos01], Value.ValueType[LPos01].DataType, True);
        end
        else
          JsonCell := DBXToJSONValueEx(Value.Value[LPos01], Value.ValueType[LPos01].DataType, True);
        JObj.AddPair(Value.ValueType[LPos01].Name, JsonCell);
      end;
      Result.AddElement(JObj);
      DecrAfter(LRowCount);
    end
    else
      Inc(LRecPos);
  end;
  Value.Close;
  if IsLocalConnection then
    Value.Free;
end;


{ TJsonValueHelper }

function TJsonValueHelper.AsJsonArray: TJSONArray;
begin
  Result := Self as TJSONArray;
end;

function TJsonValueHelper.AsJsonNumber: TJSONNumber;
begin
  Result := Self as TJSONNumber;
end;

function TJsonValueHelper.AsJsonObject: TJSONObject;
begin
  Result := Self as TJSONObject;
end;

function TJsonValueHelper.AsJsonString: TJSONString;
begin
  Result := Self as TJSONString;
end;

function TJsonValueHelper.AsVariant: Variant;
begin
  Result := Unassigned;
  if Self.IsJsonObject or Self.IsJsonArray then
    Result := Self.ToString;
  if Self.IsJsonNumber then
    if Pos('.', Self.AsJsonNumber.ToString) = 0 then
      Result := Self.AsJsonNumber.AsInt64
    else
      Result := Self.AsJsonNumber.AsDouble
  else if Self.IsJsonString then
    Result := Self.AsJsonString.Value
  else if Self.IsJsonTrue then
    Result := True
  else if Self.IsJsonFalse then
    Result := False
  else if Self.IsJsonNull then
    Result := Variants.Null
end;

function TJsonValueHelper.IsJsonArray: Boolean;
begin
  Result := ClassType = TJSONArray;
end;

function TJsonValueHelper.IsJsonFalse: Boolean;
begin
  Result := ClassType = TJSONFalse;
end;

function TJsonValueHelper.IsJsonNull: Boolean;
begin
  Result := ClassType = TJSONNull;
end;

function TJsonValueHelper.IsJsonNumber: Boolean;
begin
  Result := ClassType = TJSONNumber;
end;

function TJsonValueHelper.IsJsonObject: Boolean;
begin
  Result := ClassType = TJSONObject;
end;

function TJsonValueHelper.IsJsonString: Boolean;
begin
  Result := ClassType = TJSONString;
end;

function TJsonValueHelper.IsJsonTrue: Boolean;
begin
  Result := ClassType = TJSONTrue;
end;

function TJSONValueHelper.HasJsonValue(const APath: string): Boolean;
var
  LIndex: Integer;
  {$IF CompilerVersion < 28}
  LJsonPair: TJSONPair;
  {$IFEND}
begin
  if Self.IsJsonObject then
  begin
    {$IF CompilerVersion >= 28}
    Result := Self.AsJsonObject.GetValue(APath) <> nil
    {$ELSE}
    LJsonPair := Self.AsJsonObject.Get(APath);
    if LJsonPair = nil then Exit(False);
    Result := LJsonPair.JsonValue <> nil;
    {$IFEND}
  end
  else if Self.IsJsonArray then
  begin
    if TryStrToInt(APath, LIndex) and (Self.AsJsonArray.Count < LIndex) then
    begin
      Result := Self.AsJsonArray.Items[LIndex] <> nil
    end
    else Exit(False);
  end
  else Result := APath = '';
end;

{$IF CompilerVersion < 28}
{ TJsonArrayHelper }

function TJsonArrayHelper.Count: Integer;
begin
  Result := Self.Size;
end;

function TJsonArrayHelper.GetValue(const Index: Integer): TJSONValue;
begin
  Result := Self.Get(Index);
end;
{$IFEND}

{ TJsonAncestorHelper }

function TJsonAncestorHelper.ToJson: string;
var
  bytes: TBytes;
  len: Integer;
begin
  SetLength(bytes, Self.EstimatedByteSize);
  len := Self.ToBytes(bytes, 0);
  Result := TEncoding.ASCII.GetString(bytes, 0, len);
end;

{ TJsonNumberHelper }

function TJsonNumberHelper.AsInt64: Int64;
begin
  Result := StrToInt64(ToString);
end;

{ TJSONObjectHelper }

function TJSONObjectHelper.GetVariant(const Name: string): Variant;
var
  LPair: TJSONPair;
begin
  LPair := Self.Get(Name);
  if Assigned(LPair) and Assigned(LPair.JsonValue) then
    Result := LPair.JsonValue.AsVariant
  else
    Result := Variants.Null;
end;

function TJSONObjectHelper.TryFetchValue(const APath: string;
  out AValue: Int64): Boolean;
var LValue: TJSONValue;
begin
  LValue := Self.FetchValue(APath);
  Result := (LValue <> nil) and (LValue.IsJsonNumber);
  if Result then
    AValue := Trunc(Math.SimpleRoundTo(LValue.AsJsonNumber.AsDouble, 0));
end;

function TJSONObjectHelper.TryFetchValue(const APath: string;
  out AValue: Double): Boolean;
var LValue: TJSONValue;
begin
  LValue := Self.FetchValue(APath);
  Result := (LValue <> nil) and (LValue.IsJsonNumber);
  if Result then
    AValue := LValue.AsJsonNumber.AsDouble;
end;

function TJSONObjectHelper.TryFetchValue(const APath: string;
  out AValue: Boolean): Boolean;
var LValue: TJSONValue;
begin
  LValue := Self.FetchValue(APath);
  Result := LValue <> nil;
  if Result then
    AValue := LValue.IsJsonTrue;
end;

function TJSONObjectHelper.TryFetchValue(const APath: string;
  out AValue: string): Boolean;
var LValue: TJSONValue;
begin
  LValue := Self.FetchValue(APath);
  Result := (LValue <> nil) and (not LValue.IsJsonNull);
  if Result then
    AValue := LValue.AsJsonString.Value;
end;

function TJSONObjectHelper.FetchValue(const APairName: string): TJSONValue;
var LPath: TJSONPair;
begin
  LPath := Self.Get(APairName);
  if LPath = nil then
    Result := nil
  else
    Result := LPath.JsonValue;
end;

function TJSONObjectHelper.GetValueToJA(const Name: string): TJSONArray;
var
  LPair: TJSONPair;
begin
  LPair := Self.Get(Name);
  if Assigned(LPair) and Assigned(LPair.JsonValue) then
  begin
    Result := LPair.JsonValue.AsJsonArray;
  end
  else
    Result := nil;
end;

function TJSONObjectHelper.GetValueToJO(const Name: string): TJSONObject;
var
  LPair: TJSONPair;
begin
  LPair := Self.Get(Name);
  if Assigned(LPair) and Assigned(LPair.JsonValue) then
  begin
    Result := LPair.JsonValue.AsJsonObject;
  end
  else
    Result := nil;
end;

class function TDBXJSONToolsHelper.TableToJSONB(const Value: TDBXReader; const RowCount: Integer;
  const IsLocalConnection: Boolean; const RecNo: Integer): TJSONObject;
var
  I, C, Count, LRecPos: Integer;
  JTable: TJSONObject;
  JsonCols: array of TJSONArray;
  Meta: TJSONArray;
  Header: Boolean;
  JsonCell: TJSONValue;
begin
  if Value = nil then
    Exit(TJSONObject.Create);
  JTable := TJSONObject.Create;
  Count := Value.ColumnCount;
  SetLength(JsonCols,Count);
  Meta := TJSONArray.Create;
  JTable.AddPair('table', Meta);

  if RowCount = -1 then
    C := High(Integer)
  else
    C := RowCount;

  Header := True;
  LRecPos := 0;
  while Value.Next and (C > 0) do
  begin
    Inc(LRecPos);
    if LRecPos < RecNo then
      Continue;

    for i := 0 to Count - 1 do
    begin
      if Header then
      begin
        JsonCols[I] := TJSONArray.Create;
        JTable.AddPair(Value.ValueType[I].Name, JsonCols[I]);
        Meta.AddElement(ValueTypeToJSON(Value.ValueType[I]));
      end;

      if (Value.ValueType[I].DataType in [TDBXDataTypes.BlobType, TDBXDataTypes.BinaryBlobType]) then
        case Value.ValueType[I].SubType of
          TDBXSubDataTypes.MemoSubType,
          TDBXSubDataTypes.WideMemoSubType:
            JsonCell := DBXToJSONValueB(Value.Value[I], TDBXDataTypes.WideStringType, IsLocalConnection);
        else
          JsonCell := DBXToJSONValueB(Value.Value[I], Value.ValueType[I].DataType, IsLocalConnection);
        end
      else
        //JsonCell := DBXToJSON(Value.Value[I], Value.ValueType[I].DataType, IsLocalConnection);
        JsonCell := DBXToJSONValueB(Value.Value[I], Value.ValueType[I].DataType, IsLocalConnection);

      JsonCols[I].AddElement(JsonCell);
    end;
    Header := False;
    DecrAfter(C);
  end;
  Value.Close;
  if IsLocalConnection then
    Value.Free;
  Result := JTable;
end;

end.
