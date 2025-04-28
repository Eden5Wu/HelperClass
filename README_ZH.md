# EdenDBXJsonHelper.pas - Delphi JSON 與資料庫輔助工具

## 簡介

`EdenDBXJsonHelper.pas` 是一個 Delphi (`.pas`) 單元，提供了一系列 Class Helper (類別輔助函數)，旨在簡化在 Delphi 應用程式中處理 JSON 資料以及在資料庫元件 (如 `TDataSet`, `TDBXReader`) 與 JSON 格式之間進行轉換的操作。

此單元特別針對 Embarcadero Delphi 環境，並利用了內建的 JSON 處理庫 (`System.JSON` 或舊版的 `DBXJSON`) 以及資料庫存取元件 (DBX)。

## 主要功能

本單元透過 Class Helper 為標準的 JSON 類別和 DBX 工具類別添加了實用的擴充方法：

### JSON 相關輔助函數

* **`TJSONValueHelper`**:
    * 提供方便的類型檢查方法 (`IsJsonNumber`, `IsJsonObject`, `IsJsonNull` 等)。
    * 提供安全的類型轉換方法 (`AsJsonNumber`, `AsJsonObject`, `AsJsonArray` 等)。
    * `HasJsonValue(APath: string)`: 檢查 JSON 值（特別是 Object 或 Array）中是否存在指定路徑或索引的值。
    * `AsVariant`: 將 `TJSONValue` 轉換為對應的 `Variant` 型別。
    * `AsDateTime`: 將符合特定格式的 JSON 字串值轉換為 `TDateTime`。
* **`TJSONObjectHelper`**:
    * `WorkspaceValue(APairName: string)`: 根據名稱（區分大小寫）獲取 `TJSONValue`。
    * `TryFetchValue(APath: string; out AValue: ...)` (多載): 安全地嘗試獲取指定路徑的值，並轉換為 `string`, `Int64`, `Double`, 或 `Boolean` 型別，回傳是否成功。
    * `GetVariant(Name: string)`: 獲取指定名稱的值並轉換為 `Variant`。
    * `GetValueToJO(Name: string)`: 獲取指定名稱的值並轉換為 `TJSONObject`。
    * `GetValueToJA(Name: string)`: 獲取指定名稱的值並轉換為 `TJSONArray`。
    * (舊版 Delphi) 提供 `Count` 屬性和 `Pairs` 索引屬性。
* **`TJSONArrayHelper`** (舊版 Delphi):
    * 提供 `Count` 屬性和 `Items` 索引屬性，以統一不同 Delphi 版本的 API。
* **`TJSONAncestorHelper`**:
    * `ToJson`: 將任何 `TJsonAncestor` 後代（如 `TJSONObject`, `TJSONArray`）序列化為 JSON 格式的字串。
* **`TJSONNumberHelper`**:
    * `AsInt64`: 將 `TJSONNumber` 轉換為 `Int64`。

### 資料庫與 JSON 轉換輔助函數

* **`TDBXJSONToolsHelper`**:
    * `WorkspaceParamToDBXParameter(AParam: TParam; ADBXParameter: TDBXParameter)`: 將 `TParam` 的值設定到 `TDBXParameter` 中（注意：此實作可能需要根據具體需求調整）。
    * `TableToJSONArray(Value: TDBXReader; ...)`: 將 `TDBXReader` 的結果集轉換為 `TJSONArray`，其中每個陣列元素是一個代表資料列的 `TJSONObject`。支援指定最大行數 (`RowCount`)、起始記錄號 (`RecNo`) 和是否為本地連接 (`IsLocalConnection`)。
    * `TableRecToJSONObj(Value: TDBXReader; RecNo: Integer; ...)`: 將 `TDBXReader` 中指定記錄號 (`RecNo`) 的單筆記錄轉換為 `TJSONObject`。
    * `DataSetToJSONArray(ADataSet: TDataSet; ...)`: 將 `TDataSet` (如 `TClientDataSet`, `TFDMemTable`) 的內容轉換為 `TJSONArray`，格式同 `TableToJSONArray`。
    * `DataSetToDJSON(ADataSet: TDataSet; ...)`: 將 `TDataSet` 的內容轉換為 `TJSONObject`，採用 DataSnap "Table Block" 格式（包含元資料和按列組織的數據）。
    * `DataSetRecToJSONObj(ADataSet: TDataSet)`: 將 `TDataSet` 的 *目前* 記錄轉換為 `TJSONObject`。
    * `TableToJSONB(Value: TDBXReader; ...)`: 將 `TDBXReader` 的結果集轉換為 `TJSONObject`，採用 DataSnap "Table Block" 格式（包含一個名為 'table' 的元數據陣列，以及每個欄位名對應一個包含該列所有值的 JSON 陣列）。

## 使用方法

1.  **引入單元**: 將 `EdenDBXJsonHelper.pas` 文件添加到您的 Delphi 專案中。
2.  **使用輔助函數**: 在需要使用這些輔助功能的單元的 `uses` 子句中加入 `EdenDBXJsonHelper`。

```delphi
uses
  SysUtils, Classes, DB, DBXJSON, DBXCommon,
  EdenDBXJsonHelper; // 加入此行

procedure ExampleUsage;
var
  JsonObj: TJSONObject;
  JsonArr: TJSONArray;
  Reader: TDBXReader;
  DataSet: TClientDataSet; // 或其他 TDataSet 子類別
  ValueStr: string;
  ValueInt: Int64;
  Success: Boolean;
begin
  // --- JSON Helper 範例 ---
  JsonObj := TJSONObject.ParseJSONValue('{"name": "Test", "value": 123, "active": true, "items": [1, 2]}') as TJSONObject;
  try
    // 安全地獲取值
    Success := JsonObj.TryFetchValue('name', ValueStr);
    if Success then
      ShowMessage('Name: ' + ValueStr); // 顯示 'Name: Test'

    Success := JsonObj.TryFetchValue('value', ValueInt);
    if Success then
      ShowMessage('Value: ' + IntToStr(ValueInt)); // 顯示 'Value: 123'

    // 檢查是否存在
    if JsonObj.HasJsonValue('active') then
      ShowMessage('Active exists');

    // 獲取巢狀陣列
    JsonArr := JsonObj.GetValueToJA('items');
    if Assigned(JsonArr) then
      ShowMessage('Items count: ' + IntToStr(JsonArr.Count)); // 顯示 'Items count: 2'

    // 序列化回字串
    ShowMessage(JsonObj.ToJson);

  finally
    JsonObj.Free;
  end;

  // --- DB to JSON Helper 範例 ---

  // 假設 DataSet 已經載入資料
  DataSet := TClientDataSet.Create(nil);
  try
    // ... (載入或建立 DataSet 資料的程式碼)
    DataSet.AppendRecord(['Row1Col1', 10]);
    DataSet.AppendRecord(['Row2Col1', 20]);

    // 將 DataSet 轉換為 JSONArray (陣列，每個元素是代表一行的 JSONObject)
    JsonArr := TDBXJSONTools.DataSetToJSONArray(DataSet);
    try
      ShowMessage('DataSet as JSONArray: ' + JsonArr.ToJson);
      // 輸出: [{"Field1": "Row1Col1", "Field2": 10}, {"Field1": "Row2Col1", "Field2": 20}] (假設欄位名為 Field1, Field2)
    finally
      JsonArr.Free;
    end;

    // 將 DataSet 的目前記錄轉換為 JSONObject
    if not DataSet.IsEmpty then
    begin
      DataSet.First; // 或定位到特定記錄
      JsonObj := TDBXJSONTools.DataSetRecToJSONObj(DataSet);
      try
        ShowMessage('Current DataSet Record as JSONObject: ' + JsonObj.ToJson);
      // 輸出: {"Field1": "Row1Col1", "Field2": 10} (假設目前在第一筆)
      finally
        JsonObj.Free;
      end;
    end;

    // 將 DataSet 轉換為 DataSnap Table Block 格式的 JSONObject
    JsonObj := TDBXJSONTools.DataSetToDJSON(DataSet);
    try
      ShowMessage('DataSet as Table Block JSON: ' + JsonObj.ToJson);
      // 輸出類似: {"table": [...metadata...], "Field1": ["Row1Col1", "Row2Col1"], "Field2": [10, 20]}
    finally
      JsonObj.Free;
    end;

  finally
    DataSet.Free;
  end;

  // 假設 Reader 從 DataSnap 或 DBX 獲得
  // Reader := ... (獲取 TDBXReader 實例的程式碼)
  // if Assigned(Reader) then
  // begin
  //   JsonArr := TDBXJSONTools.TableToJSONArray(Reader, 10); // 最多轉換 10 筆
  //   try
  //      // ... 使用 JsonArr ...
  //   finally
  //     JsonArr.Free;
  //   end;
  // end;

end;
