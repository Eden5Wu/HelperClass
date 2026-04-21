unit EdenDBXJsonHelper;

interface

uses
  DBXCommon, SysUtils, DBXJSONCommon, Classes,
  {$IF CompilerVersion >= 28} System.JSON {$ELSE} DBXJSON {$IFEND},
  DB, Variants;

type
  TEdenBase64 = class
  public
    /// <summary>
    /// Encodes a TStream content to a Base64 string using Win32 API.
    /// Fully compatible with Windows XP and later.
    /// </summary>
    class function EncodeStream(const AStream: TStream): string; static;
    class function DecodeToStream(const ABase64Str: string; const AOutStream: TStream): Boolean; static;
  end;

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
    function AsDateTime: TDateTime;

    {$IF CompilerVersion >= 28} // 確保只有支援 System.JSON 與 AsType<T> 的版本才編譯
    function ValueOrDefault<T>(const APath: string; const ADefault: T): T;
    {$IFEND}
  end;

  TJSONObjectHelper = class helper for TJSONObject
  private
    {$IF CompilerVersion < 28}
    function GetJsonPair(AIndex: Integer): TJSONPair;
    {$IFEND}
  public
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


    {$IF CompilerVersion < 28}
    function Count(): Integer;
    property Pairs[AIndex: Integer]: TJSONPair read GetJsonPair;
    {$IFEND}
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
    class procedure DJsonToDataSet(AJsonObj: TJSONObject; ADataSet: TDataSet);
  end;

implementation

uses
  Windows, DateUtils, DBXDBReaders, DBXPlatform, DBXCommonResStrs, Math,
  XSBuiltIns, Rtti, TypInfo;

const TABLE_PAIR = 'table';

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
        Result := TJSONString.Create(DateTimeToXMLTime(Value.AsDateTime));
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
          //Result := TDBXJSONTools.StreamToJSON(LStream, 0, High(Integer));
          Result := TJSONString.Create(TEdenBase64.EncodeStream(LStream));
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
        Result := TJSONString.Create(DateTimeToXMLTime(Value.AsDateTime));
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
      TDBXDataTypes.BinaryBlobType: begin
        LStream := TDBXStreamValue(Value).GetStream(True);
        if TDBXStreamValue(Value).IsNull then
          Result := TJSONNull.Create
        else
          Result := TJSONString.Create(TEdenBase64.EncodeStream(LStream));
      end;
      TDBXDataTypes.BytesType: begin // 為了相容舊 DataSnap + rowversion 除錯
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

class procedure TDBXJSONToolsHelper.DJsonToDataSet(AJsonObj: TJSONObject;
  ADataSet: TDataSet);
var
  LMetaArray: TJSONArray;
  LFieldArray, LJsonByteArr: TJSONArray;
  LColArray: TJSONArray;
  LFieldPair: TJSONPair;
  LValue: TJSONValue;
  I, RowIdx, ColIdx, LRowCount, ByteIdx, LByteValue: Integer;
  LFieldName: string;
  LDBXType, LSubType, LSize: Integer;
  LFieldType: TFieldType;
  LStream: TStream;
  function GetFieldTypeFromDBX(const ADBXType: Integer; const ASubType: Integer): TFieldType;
  begin
    case ADBXType of
      TDBXDataTypes.Int8Type,
      TDBXDataTypes.Int16Type,
      TDBXDataTypes.Int32Type,
      TDBXDataTypes.UInt16Type,
      TDBXDataTypes.UInt32Type: Result := ftInteger;
      TDBXDataTypes.Int64Type,
      TDBXDataTypes.UInt64Type: Result := ftLargeint;
      TDBXDataTypes.DoubleType,
      TDBXDataTypes.SingleType: Result := ftFloat;
      TDBXDataTypes.CurrencyType: Result := ftCurrency;
      TDBXDataTypes.BcdType:    Result := ftFMTBcd;
      TDBXDataTypes.BooleanType: Result := ftBoolean;
      TDBXDataTypes.AnsiStringType: Result := ftString;
      TDBXDataTypes.WideStringType: Result := ftWideString;
      TDBXDataTypes.DateType:     Result := ftDate;
      TDBXDataTypes.TimeType:     Result := ftTime;
      TDBXDataTypes.DatetimeType: Result := ftDateTime;
      TDBXDataTypes.TimeStampType: Result := ftTimeStamp;
      TDBXDataTypes.BlobType,
      TDBXDataTypes.BinaryBlobType:
      begin
        // 判斷是否為 Memo
        if ASubType in [TDBXSubDataTypes.MemoSubType, TDBXSubDataTypes.WideMemoSubType] then
          Result := ftWideMemo
        else
          Result := ftBlob; // SQL Server: varbinary(max), image
      end;
      TDBXDataTypes.BytesType:  Result := ftBytes; // SQL Server: binary, varbinary(n), rowversion
    else
      Result := ftUnknown;
    end;
  end;
  // 內連 (巢狀) 程序：利用 RTTI 動態呼叫 CreateDataSet
  procedure InternalInvokeCreateDataSet(ADS: TDataSet);
  var
    LContext: TRttiContext;
    LType: TRttiType;
    LMethod: TRttiMethod;
  begin
    LContext := TRttiContext.Create;
    try
      LType := LContext.GetType(ADS.ClassType);
      LMethod := LType.GetMethod('CreateDataSet');
      // 如果該元件有實作 CreateDataSet 且是 Public 則呼叫它
      if Assigned(LMethod) then
        LMethod.Invoke(ADS, []);
    finally
      LContext.Free;
    end;
  end;
begin
  if (AJsonObj = nil) or (ADataSet = nil) then Exit;

  // 1. 取得 Metadata 陣列
  LMetaArray := AJsonObj.GetValueToJA('table');
  if LMetaArray = nil then Exit;

  ADataSet.Close;
  ADataSet.FieldDefs.Clear;

  for I := 0 to LMetaArray.Size - 1 do
  begin
    // 注意：這裡 table 裡面每一項都是 JSONArray
    // 格式：["Name", DataType, SubType, Precision, Size, ...]
    LFieldArray := LMetaArray.Get(I) as TJSONArray;

    // 依照 TDBXJSONTools 定義的索引取值
    LFieldName := (LFieldArray.Get(0) as TJSONString).Value;

    // 注意：你的 Helper 只有 AsInt64，建議統一使用 AsInt64
    LDBXType   := LFieldArray.Get(1).AsJsonNumber.AsInt64;

    LSubType := 0;
    if LFieldArray.Size > 2 then
      LSubType := LFieldArray.Get(2).AsJsonNumber.AsInt64;

    LSize := 0;
    if LFieldArray.Size > 4 then
      LSize := LFieldArray.Get(4).AsJsonNumber.AsInt64;

    // 呼叫你的轉換邏輯
    LFieldType := GetFieldTypeFromDBX(LDBXType, LSubType);

    // 建立欄位定義
    with ADataSet.FieldDefs.AddFieldDef do
    begin
      Name := LFieldName;
      DataType := LFieldType;
      if LFieldType in [ftString, ftWideString, ftBytes, ftVarBytes] then
        Size := LSize;
    end;
  end;

  InternalInvokeCreateDataSet(ADataSet);

  // 3. 計算資料列數 (找出第一個資料陣列的長度)
  LRowCount := 0;
  for I := 0 to AJsonObj.Size - 1 do
  begin
    LFieldPair := AJsonObj.Get(I);
    if (LFieldPair.JsonString.Value <> 'table') and (LFieldPair.JsonValue is TJSONArray) then
    begin
      LRowCount := TJSONArray(LFieldPair.JsonValue).Size;
      Break;
    end;
  end;

  // 4. 填入資料
  if LRowCount > 0 then
  begin
    ADataSet.DisableControls;
    try
      for RowIdx := 0 to LRowCount - 1 do
      begin
        ADataSet.Append;
        for ColIdx := 0 to ADataSet.FieldCount - 1 do
        begin
          LFieldName := ADataSet.Fields[ColIdx].FieldName;
          LColArray := AJsonObj.GetValueToJA(LFieldName);

          if Assigned(LColArray) then
          begin
            LValue := LColArray.Get(RowIdx);
            // 1. 處理 Null (優先處理)
            if LValue.IsJsonNull then
            begin
              ADataSet.Fields[ColIdx].Clear;
            end

            // 2. 處理日期 (ISO8601 轉型)
            else if (ADataSet.Fields[ColIdx].DataType in [ftDate, ftTime, ftDateTime]) and (LValue is TJSONString) then
            begin
              ADataSet.Fields[ColIdx].AsDateTime := LValue.AsDateTime;
            end

            // 3. 處理 Blob 相關欄位
            else if ADataSet.Fields[ColIdx].IsBlob then
            begin
              if ADataSet.Fields[ColIdx].DataType in [ftMemo, ftWideMemo] then
              begin
                // 因為 Server 端對 Memo 做了 TDBXDataTypes.WideStringType 轉換
                // 所以這裡直接當一般字串填入即可，不需要解 Base64
                ADataSet.Fields[ColIdx].AsString := LValue.AsJsonString.Value;
              end
              else
              begin
                // 二進制 Blob 路徑
                LStream := TMemoryStream.Create;
                try
                  if LValue is TJSONArray then
                  begin
                    // --- 相容傳統 Byte Array [72, 101, 108, 108, 111] ---
                    LJsonByteArr := LValue as TJSONArray;
                    for ByteIdx := 0 to LJsonByteArr.Size - 1 do
                    begin
                      // 逐位元寫入，雖然較慢但最穩定
                      LByteValue := StrToInt(LJsonByteArr.Get(ByteIdx).ToString);
                      LStream.Write(LByteValue, 1);
                    end;
                  end
                  else if LValue is TJSONString then
                  begin
                    // --- 相容 Base64 字串 ---
                    TEdenBase64.DecodeToStream(LValue.AsJsonString.Value, LStream);
                  end;

                  if LStream.Size > 0 then
                  begin
                    LStream.Position := 0;
                    TBlobField(ADataSet.Fields[ColIdx]).LoadFromStream(LStream);
                  end;
                finally
                  LStream.Free;
                end;
              end;
            end
            else
            begin
              // 一般欄位才用 AsVariant
              ADataSet.Fields[ColIdx].Value := LValue.AsVariant;
            end;
          end;
        end;
        ADataSet.Post;
      end;
      ADataSet.First;
    finally
      ADataSet.EnableControls;
    end;
  end;
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

function TJSONValueHelper.AsDateTime: TDateTime;
var
  LDateStr: string;
begin
  LDateStr := Self.AsJsonString.Value;
  if (Length(LDateStr) >= 11) and (LDateStr[11] = ' ') then
    LDateStr[11] := 'T';
  Result := XMLTimeToDateTime(LDateStr, Pos(SLocalTimeMarker, LDateStr)=0);
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

{$IF CompilerVersion >= 28}
function TJSONValueHelper.ValueOrDefault<T>(const APath: string; const ADefault: T): T;
var
  LValue: TJSONValue;
begin
  // 1. 統一使用 FindValue 來支援 Path 穿透 (與現有 TryFetchValue 邏輯一致)
  LValue := Self.FindValue(APath);

  // 2. 如果抓不到或是 JsonNull，回傳預設值
  if (LValue = nil) or LValue.IsJsonNull then
    Exit(ADefault);

  // 3. 嘗試轉型
  try
    Result := LValue.AsType<T>;
  except
    // 若轉型失敗（例如字串轉整數），退回預設值
    Result := ADefault;
  end;
end;
{$IFEND}

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
  {$IF CompilerVersion >= 28}
  LValue := Self.FindValue(APath);
  {$ELSE}
  LValue := Self.FetchValue(APath);
  {$IFEND}
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

{$IF CompilerVersion < 28}
function TJSONObjectHelper.GetJsonPair(AIndex: Integer): TJSONPair;
begin
  Result := Get(AIndex);
end;
{$IFEND}

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

{$IF CompilerVersion < 28}
function TJSONObjectHelper.Count(): Integer;
begin
  Result := Self.Size;
end;
{$IFEND}

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

{ TEdenBase64 }

const
  CRYPT_STRING_BASE64 = $00000001;
  CRYPT_STRING_NOCRLF = $40000000;

function CryptBinaryToStringW(pbBinary: PByte; cbBinary: DWORD; dwFlags: DWORD;
  pszString: PWideChar; var pcchString: DWORD): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptBinaryToStringW';

function CryptStringToBinaryW(
  pszString: PWideChar;
  cchString: DWORD;
  dwFlags: DWORD;
  pbBinary: PByte;
  var pcbBinary: DWORD;
  pdwSkip: PDWORD;
  pdwFlags: PDWORD
): BOOL; stdcall; external 'crypt32.dll' name 'CryptStringToBinaryW';

class function TEdenBase64.DecodeToStream(const ABase64Str: string;
  const AOutStream: TStream): Boolean;
var
  LBinarySize: DWORD;
  LBytes: TBytes;
  LCleanStr: string;
begin
  Result := False;
  LCleanStr := Trim(ABase64Str);
  if LCleanStr = '' then Exit;

  // 1. 第一次呼叫：取得所需的二進位緩衝區大小
  LBinarySize := 0;
  if CryptStringToBinaryW(PWideChar(LCleanStr), Length(LCleanStr),
     CRYPT_STRING_BASE64, nil, LBinarySize, nil, nil) then
  begin
    SetLength(LBytes, LBinarySize);
    // 2. 第二次呼叫：進行實際解碼
    if CryptStringToBinaryW(PWideChar(LCleanStr), Length(LCleanStr),
       CRYPT_STRING_BASE64, @LBytes[0], LBinarySize, nil, nil) then
    begin
      AOutStream.WriteBuffer(LBytes[0], LBinarySize);
      AOutStream.Position := 0;
      Result := True;
    end;
  end;
end;

class function TEdenBase64.EncodeStream(const AStream: TStream): string;
var
  LInput: TBytes;
  LSize: DWORD;
  LOutLen: DWORD;
  LFlags: DWORD;
  LIsModernOS: Boolean;
begin
  Result := '';
  if (AStream = nil) or (AStream.Size = 0) then Exit;

  // Detect OS version: Returns True for Windows Vista (6.0) or later
  LIsModernOS := CheckWin32Version(6, 0);

  // Configure flags based on OS capabilities
  LFlags := CRYPT_STRING_BASE64;
  if LIsModernOS then
    LFlags := LFlags or CRYPT_STRING_NOCRLF;

  // 1. Read data from the stream
  AStream.Position := 0;
  SetLength(LInput, AStream.Size);
  AStream.Read(LInput[0], AStream.Size);

  LSize := Length(LInput);
  LOutLen := 0;

  // 2. First call to determine the required buffer length
  if CryptBinaryToStringW(@LInput[0], LSize, LFlags, nil, LOutLen) then
  begin
    if LOutLen = 0 then
      Exit;

    // Subtract 1 from LOutLen to exclude the Null terminator (#0) from the Delphi string length
    SetLength(Result, LOutLen - 1);

    // 3. Second call to perform the actual conversion
    if CryptBinaryToStringW(@LInput[0], LSize, LFlags, PWideChar(Result), LOutLen) then
    begin
      // Windows XP does not support CRYPT_STRING_NOCRLF; manually remove line breaks if on legacy OS
      if not LIsModernOS then
        Result := StringReplace(Result, #13#10, '', [rfReplaceAll]);

      // Clean up any trailing whitespace or null characters
      Result := Trim(Result);
    end;
  end;
end;

end.
