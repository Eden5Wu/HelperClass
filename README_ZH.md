# Delphi Helper Class Library

[English Version](README.md)

Delphi Helper Class Library 是一套以 Delphi Class Helper（類別輔助類別）及工具類別為核心的程式庫，旨在簡化 JSON 處理、資料庫操作與資料序列化。

本程式庫透過擴充 Delphi 既有的 API，在不修改原始類別的情況下，為 `TJSONValue`、`TJSONObject`、`TDataSet`、`TDBXReader` 等類別提供可重複使用的輔助方法。

本專案的核心是 **資料庫與 JSON 之間的互通性（Database-to-JSON Interoperability）**，特別適用於使用 dbExpress、DataSnap 及 REST 服務的 Delphi 應用程式。

## 主要特色

- **JSON Class Helper**：簡化 JSON 值的存取、型別轉換及物件操作。
- **資料庫序列化**：將 `TDataSet` 及 `TDBXReader` 轉換為 JSON。
- **DataSnap 相容性**：產生及解析 DataSnap Table Block JSON 結構。
- **雙向資料轉換**：從 Table Block JSON 重建支援的記憶體資料集。
- **Streaming JSON**：不建立完整 JSON DOM，即可逐筆序列化大量資料。
- **二進位資料處理**：支援 Base64、Blob 與 Byte Array 格式。
- **跨版本相容性**：統一不同 Delphi 版本的 JSON 操作介面。
- **其他輔助工具**：包含 SQL Server dbExpress 與 `TStringList` 擴充功能。

本專案的目的不是取代 Delphi 原有的資料存取框架，而是在既有架構上提供更便利的操作方式。

---

## 1. 專案結構

| 檔案 | 說明 |
|------|------|
| `EdenDBXJsonHelper.pas` | JSON Helper、資料庫序列化、DataSnap Table Block 轉換及 Base64 工具。 |
| `DBExpress.MSSQL.Factory.pas` | SQL Server dbExpress 連線管理、SQL 執行、參數處理及 Metadata 工具。 |
| `StringListHelperUnit.pas` | 擴充 `TStringList`，提供具備型別的 Key/Value 操作。 |
| `DBXCypher.pas` | PC1 字串加解密，以及具有隨機前置字元的加解密函式。 |
| `Demo-JSON/` | JSON 相關功能的 Delphi 示範專案。 |
| `README.md` | 英文說明文件。 |
| `LICENSE` | MIT 授權條款。 |

其中，`EdenDBXJsonHelper.pas` 是本專案最主要的核心單元。

各單元負責不同功能，在滿足相依條件的情況下，可以依需求獨立使用。

---

## 2. 系統需求

### Delphi 版本相容性

本程式庫透過條件編譯（Conditional Compilation），處理不同 Delphi 版本之間的 API 差異。

| 功能 | 實作方式／版本需求 |
|------|-------------------|
| 舊版 Delphi JSON | `DBXJSON` |
| Delphi XE7 以上 JSON | `System.JSON` |
| 泛型 `ValueOrDefault<T>` | Delphi XE7 以上 |
| Streaming JSON | Delphi XE8 以上 |
| 資料庫轉換 | dbExpress、`TDataSet` API |
| Base64 編解碼 | Windows CryptoAPI（`crypt32.dll`） |

原始碼包含舊版 Delphi 的相容性處理，以及針對 Windows XP 的 Base64 相容實作。

**注意：** 目前尚未針對所有 Delphi 版本完成獨立編譯與測試。因此，條件編譯所涵蓋的版本不代表所有功能均已通過完整驗證。

### 支援的資料來源

正向序列化支援：

- `TDBXReader`
- `TClientDataSet`
- `TFDMemTable`
- 其他相容的 `TDataSet` 後代類別

反向轉換具有較多限制。目標 DataSet 必須支援動態建立欄位及新增記錄。

`DJsonToDataSet` 主要以 `TClientDataSet` 與 `TFDMemTable` 為預期使用對象。

### 作業系統

Base64 實作使用 Windows `crypt32.dll`。

若要在非 Windows 平台使用，必須替換相關 Windows API 實作。

---

## 3. 快速開始

### 安裝方式

複製 GitHub 專案：

```bash
git clone https://github.com/Eden5Wu/HelperClass.git
```

將需要使用的 `.pas` 檔案加入 Delphi 專案的搜尋路徑（Search Path）。

如需使用 JSON 與資料庫序列化功能，加入：

```delphi
uses
  EdenDBXJsonHelper;
```

加入後，即可透過 Class Helper 使用對應的擴充方法。

本程式庫不需要安裝自訂元件。

### 範例：DataSet 轉換成 JSON

```delphi
uses
  SysUtils, DB, DBClient, DBXCommon, DBXJSONCommon,
  {$IF CompilerVersion >= 28}
  System.JSON,
  {$ELSE}
  DBXJSON,
  {$IFEND}
  EdenDBXJsonHelper;

procedure ExampleDataSetToJSON;
var
  DataSet: TClientDataSet;
  JsonArray: TJSONArray;
begin
  DataSet := TClientDataSet.Create(nil);
  try
    DataSet.FieldDefs.Add('ID', ftInteger);
    DataSet.FieldDefs.Add('Name', ftString, 50);
    DataSet.CreateDataSet;

    DataSet.AppendRecord([1, 'Alice']);
    DataSet.AppendRecord([2, 'Bob']);

    JsonArray := TDBXJSONTools.DataSetToJSONArray(DataSet);
    try
      Writeln(JsonArray.ToJson);
    finally
      JsonArray.Free;
    end;

  finally
    DataSet.Free;
  end;
end;
```

輸出結果：

```json
[
  {"ID": 1, "Name": "Alice"},
  {"ID": 2, "Name": "Bob"}
]
```

產生的資料是標準 JSON Array，可以直接提供給 JavaScript 應用程式及 REST API 使用。

---

## 4. JSON Class Helper

`EdenDBXJsonHelper.pas` 透過 Class Helper 擴充 Delphi 內建的 JSON 類別。

主要目的是減少重複的型別判斷、強制轉型及 JSON 物件操作程式碼。

### 4.1 TJSONValueHelper

擴充 `TJSONValue`，提供型別檢查與轉換方法。

| 方法 | 說明 |
|------|------|
| `IsJsonNumber` | 判斷是否為 JSON Number。 |
| `IsJsonString` | 判斷是否為 JSON String。 |
| `IsJsonObject` | 判斷是否為 JSON Object。 |
| `IsJsonArray` | 判斷是否為 JSON Array。 |
| `IsJsonNull` | 判斷是否為 JSON Null。 |
| `IsJsonTrue` | 判斷是否為 JSON True。 |
| `IsJsonFalse` | 判斷是否為 JSON False。 |
| `AsJsonNumber` | 轉型為 `TJSONNumber`。 |
| `AsJsonString` | 轉型為 `TJSONString`。 |
| `AsJsonObject` | 轉型為 `TJSONObject`。 |
| `AsJsonArray` | 轉型為 `TJSONArray`。 |
| `AsVariant` | 轉換為對應的 Delphi `Variant`。 |
| `AsDateTime` | 將相容的 JSON 日期時間字串轉為 `TDateTime`。 |
| `HasJsonValue` | 檢查指定名稱或陣列索引是否存在。 |
| `ValueOrDefault<T>` | 取得指定型別的值，失敗時使用預設值。XE7 以上。 |

`AsJson...` 方法屬於型別轉型輔助函式，不代表轉型失敗時一定不會產生例外。

### 4.2 TJSONObjectHelper

擴充 `TJSONObject`，提供方便的 JSON 值取得與修改方法。

| 方法 | 說明 |
|------|------|
| `FetchValue` | 依照名稱取得 JSON 值。 |
| `TryFetchValue` | 透過多載方法取得並轉換指定型別的值。 |
| `GetVariant` | 取得對應的 `Variant` 值。 |
| `GetValueToJO` | 取得巢狀 `TJSONObject`。 |
| `GetValueToJA` | 取得巢狀 `TJSONArray`。 |
| `SetVal` | 新增或取代指定名稱的 JSON 值。 |

`SetVal` 支援以下型別：

- `string`
- `Integer`
- `Int64`
- `Double`
- `Boolean`
- `TJSONValue`

### 範例：讀取 JSON 值

```delphi
var
  JsonObj: TJSONObject;
  Name: string;
  Age: Int64;
begin
  JsonObj := TJSONObject.ParseJSONValue(
    '{"name":"Alice","age":25}'
  ) as TJSONObject;

  try
    if JsonObj.TryFetchValue('name', Name) then
      Writeln(Name);

    if JsonObj.TryFetchValue('age', Age) then
      Writeln(Age);

  finally
    JsonObj.Free;
  end;
end;
```

輸出：

```text
Alice
25
```

### 範例：ValueOrDefault<T>

適用於 Delphi XE7 以上版本。

```delphi
var
  JsonObj: TJSONObject;
  Age: Integer;
begin
  JsonObj := TJSONObject.ParseJSONValue(
    '{"name":"Alice"}'
  ) as TJSONObject;

  try
    Age := JsonObj.ValueOrDefault<Integer>('age', 18);
    // age 不存在，回傳預設值 18。
  finally
    JsonObj.Free;
  end;
end;
```

當指定值不存在、為 JSON Null，或支援的型別轉換過程發生例外時，`ValueOrDefault<T>` 會回傳預設值。

### 其他 JSON Helper

| Helper | 功能 |
|--------|------|
| `TJSONAncestorHelper` | 透過 `ToJson` 將 JSON 物件序列化成字串。 |
| `TJSONNumberHelper` | 透過 `AsInt64` 取得整數值。 |
| `TJSONArrayHelper` | 為舊版 Delphi 提供 `Count`、`Items` 相容介面。 |
| `TJSONObjectHelper` | 為舊版 Delphi 提供 `Count`、`Pairs` 相容介面。 |

部分 Helper 使用條件編譯，避免與新版 Delphi 已提供的功能重複。

---

## 5. 資料庫與 JSON 轉換

`TDBXJSONToolsHelper` 提供 Delphi 資料庫結構與 JSON 之間的轉換功能。

主要支援兩種 JSON 序列化格式：

1. **Row-oriented JSON（列導向 JSON）**
2. **DataSnap Table Block JSON（欄導向 JSON）**

兩種格式有不同的使用目的。

### 5.1 Row-oriented JSON

Row-oriented JSON 使用一個 JSON Object 表示一筆資料列（Record）。

例如：

```json
[
  {
    "ID": 1,
    "Name": "Alice"
  },
  {
    "ID": 2,
    "Name": "Bob"
  }
]
```

相關方法：

| 方法 | 資料來源 |
|------|----------|
| `DataSetToJSONArray` | `TDataSet` |
| `TableToJSONArray` | `TDBXReader` |
| `DataSetRecToJSONObj` | `TDataSet` 目前記錄 |
| `TableRecToJSONObj` | `TDBXReader` 指定記錄 |

適用情境：

- REST API 回應
- JavaScript 應用程式
- 網頁 DataGrid
- 一般 JSON 資料交換

當前端不需要資料庫欄位 Metadata 時，通常建議使用這種格式。

### 5.2 DataSnap Table Block JSON

DataSnap Table Block JSON 除了資料內容，也保留資料庫的欄位 Metadata。

不同於 Row-oriented JSON，Table Block 以欄位為單位組織資料。

概念結構如下：

```text
{
  "table": [
    ["ID",   DBXType, SubType, Precision, Size, ...],
    ["Name", DBXType, SubType, Precision, Size, ...]
  ],
  "ID": [1, 2],
  "Name": ["Alice", "Bob"]
}
```

上述內容僅用於展示資料結構。

實際的 Metadata 由 DBX 序列化格式定義，包含資料型別、子型別、精度及欄位長度等資訊。

相關方法：

| 方法 | 操作 |
|------|------|
| `DataSetToDJSON` | DataSet → Table Block JSON |
| `TableToJSONB` | DBXReader → Table Block JSON |
| `DJsonToDataSet` | Table Block JSON → DataSet |

適用情境：

- DataSnap 系統互通
- 記憶體 DataSet 重建
- 資料庫 Metadata 傳遞
- 舊版 Delphi 系統整合

---

## 6. DataSet 雙向轉換

本程式庫提供支援的記憶體資料集與 DataSnap Table Block JSON 之間的有限雙向轉換功能。

### DataSet → JSON → DataSet

```text
+-------------------+
| TClientDataSet    |
| or TFDMemTable    |
+-------------------+
          |
          | DataSetToDJSON
          v
+-------------------+
| DataSnap          |
| Table Block JSON  |
|                   |
| - Field Metadata  |
| - Column Values   |
+-------------------+
          |
          | DJsonToDataSet
          v
+-------------------+
| Reconstructed     |
| In-Memory DataSet |
+-------------------+
```

### 範例：匯出 DataSet

```delphi
var
  JsonObj: TJSONObject;
begin
  JsonObj := TDBXJSONTools.DataSetToDJSON(DataSet);
  try
    Writeln(JsonObj.ToJson);
  finally
    JsonObj.Free;
  end;
end;
```

### 範例：從 JSON 重建 DataSet

```delphi
var
  JsonObj: TJSONObject;
  DataSet: TClientDataSet;
begin
  // JsonObj 已包含有效的 DataSnap Table Block JSON。

  DataSet := TClientDataSet.Create(nil);
  try
    TDBXJSONTools.DJsonToDataSet(JsonObj, DataSet);

    if DataSet.Active then
    begin
      DataSet.First;

      while not DataSet.Eof do
      begin
        Writeln(DataSet.FieldByName('Name').AsString);
        DataSet.Next;
      end;
    end;

  finally
    DataSet.Free;
  end;
end;
```

`DJsonToDataSet` 的處理流程如下：

1. 讀取 `table` Metadata。
2. 解析欄位名稱及 DBX 資料型別。
3. 將支援的 DBX 型別映射為 Delphi `TFieldType`。
4. 動態建立 `FieldDefs`。
5. 透過 RTTI 嘗試建立目標 DataSet。
6. 解析各欄位的資料陣列。
7. 將資料逐筆寫入目標 DataSet。

### 重要限制

`DJsonToDataSet` 預期目標 DataSet 支援：

- 動態建立欄位定義
- 無參數的 `CreateDataSet`
- 新增資料列
- 記憶體資料儲存

目前主要針對 `TClientDataSet` 與 `TFDMemTable` 這類元件設計。

不保證所有欄位型別或 Metadata 屬性都能無損還原。

此外，本函式只負責重建資料集，不會將修改結果自動寫回外部資料庫。

---

## 7. Streaming JSON 序列化

傳統 JSON 序列化通常需要先建立完整的 JSON 物件樹（DOM），再將其輸出為字串。

當資料量很大時，這種方式可能造成較高的記憶體使用量。

本程式庫因此提供使用 `TJsonTextWriter` 的 Forward-only Streaming JSON 功能。

### 支援方法

| 方法 | 說明 |
|------|------|
| `TableToJSONWriter` | 直接將 `TDBXReader` 寫入 JSON Writer。 |
| `TableToJSONText` | 將 `TDBXReader` 轉換為完整 JSON 字串。 |

兩者均需要 Delphi XE8 以上版本。

### TableToJSONText

這是取得完整 JSON 字串最簡單的方式。

```delphi
var
  JsonText: string;
begin
  JsonText := TDBXJSONTools.TableToJSONText(Reader);
end;
```

此方法內部使用 `TableToJSONWriter` 執行序列化。

但由於最終結果仍然是完整字串，因此 JSON 內容仍會佔用記憶體。

### TableToJSONWriter

對於大量資料，可直接將 JSON 寫入檔案或其他輸出目的地，避免建立完整的 JSON DOM。

```delphi
uses
  SysUtils, Classes, DBXCommon,
  DBXJSONCommon, System.JSON.Writers,
  EdenDBXJsonHelper;

procedure ExportReaderToJSON(Reader: TDBXReader);
var
  TextWriter: TStreamWriter;
  JsonWriter: TJsonTextWriter;
begin
  TextWriter := TStreamWriter.Create(
    'export.json', False, TEncoding.UTF8
  );

  try
    JsonWriter := TJsonTextWriter.Create(TextWriter);
    try
      JsonWriter.Formatting := TJsonFormatting.None;

      TDBXJSONTools.TableToJSONWriter(
        Reader,
        JsonWriter
      );

    finally
      JsonWriter.Free;
    end;

  finally
    TextWriter.Free;
  end;
end;
```

### 主要優點

- 以循序方式讀取資料列。
- 不需要建立完整的 `TJSONArray`。
- 降低 JSON DOM 所造成的記憶體消耗。
- 可直接輸出至相容的 Text Writer。
- 適合大量資料匯出及 REST API 回應。

### 記憶體使用注意事項

Streaming 並不代表所有情況下都能維持固定的記憶體使用量。

目前實作在處理部分 Blob、Bytes 欄位時，仍可能配置額外的記憶體緩衝區。

此外，`TableToJSONText` 會將完整 JSON 字串保留在記憶體中。

當資料量較大，而且輸出目的地支援逐步寫入時，建議直接使用 `TableToJSONWriter`。

---

## 8. 二進位資料處理

JSON 並沒有原生的二進位資料型別。

本程式庫主要使用兩種方式表示二進位資料：

- Base64 字串
- JSON Byte Array

### 二進位資料表示方式

| 資料型別 | JSON 格式 |
|----------|-----------|
| Blob / BinaryBlob | Base64 字串 |
| Table Block 中的 Bytes | JSON 數值陣列 |
| Memo / WideMemo | 一般文字字串 |

Base64 範例：

```json
{
  "Document": "SGVsbG8="
}
```

Byte Array 範例：

```json
{
  "Version": [72, 101, 108, 108, 111]
}
```

實際輸出格式取決於轉換方法以及 DBX 資料型別。

尤其是 `BytesType`，在 Row-oriented JSON 與 Table Block JSON 中，不一定採用完全相同的表示方式。

### TEdenBase64

提供以下方法：

| 方法 | 說明 |
|------|------|
| `EncodeStream` | 將二進位 Stream 編碼為 Base64。 |
| `DecodeToStream` | 將 Base64 字串還原至 Stream。 |
| `EncodeCleanStream` | 嘗試移除特定檔案格式的前置資料，再進行 Base64 編碼。 |

實作使用 Windows CryptoAPI。

`EncodeCleanStream` 會掃描部分檔案特徵碼，包括：

- BMP
- JPEG
- PNG
- GIF
- PDF
- ZIP

**注意：** `EncodeCleanStream` 可能移除偵測到的檔案特徵碼之前的內容，因此不應視為一般用途的無損二進位編碼方法。

若需要完整保留原始二進位資料，應使用 `EncodeStream`。

### 反向轉換限制

`DJsonToDataSet` 已包含 Base64 字串及 Byte Array 的解析邏輯。

但目前尚未完整處理所有二進位欄位型別，尤其是 `ftBytes` 與 `ftVarBytes`。

實際使用時，應針對應用程式涉及的 DataSet 與欄位型別進行往返轉換測試。

---

## 9. SQL Server dbExpress 輔助工具

`DBExpress.MSSQL.Factory.pas` 提供 SQL Server dbExpress 相關的工具類別。

### TDBXMSSQLFactory

封裝常見的資料庫操作：

- 建立資料庫連線
- 準備 SQL Command
- 設定 SQL Parameter
- 執行查詢
- 執行非查詢命令
- 取得資料庫 Metadata

### 主要方法

| 方法 | 說明 |
|------|------|
| `GetConnection` | 取得管理中的 DBX Connection。 |
| `Prepare` | 建立並準備 SQL Command。 |
| `PrepareMSQuery` | 加入 SQL Server 專用前置語句後準備 Command。 |
| `Execute` | 執行非查詢 SQL Command。 |
| `ExecuteQuery` | 執行查詢並回傳 `TDBXReader`。 |
| `FillParameters` | 將變數值指定給 DBX Parameters。 |
| `DBXGetTableList` | 取得資料庫資料表 Metadata。 |
| `OleDBConnectionStringToDBX` | 將部分 OLE DB 連線設定轉換為 DBX 連線參數。 |

### TDBXCommandHelper

擴充 `TDBXCommand`：

- `CreateBlobParameter`
- `ExecuteSmartQuery`

`ExecuteSmartQuery` 會略過沒有資料欄位的結果集，直到找到可讀取的結果集。

這項功能主要處理特定的 SQL 查詢結果模式，並非一般性的多結果集處理框架。

### TDBXParameterHelper

提供具備型別的參數屬性：

```delphi
Param.AsString := 'Alice';
Param.AsInt32 := 100;
Param.AsBoolean := True;
Param.AsDateTime := Now;
```

另外也支援：

- `Clear`
- `AsDouble`
- `AsAnsiString`

透過這些 Helper，可以減少直接操作底層 DBX Parameter Value API 的重複程式碼。

---

## 10. TStringList 擴充

`StringListHelperUnit.pas` 擴充 `TStringList`，提供簡單的 Key/Value 操作。

### 支援方法

| 方法 | 說明 |
|------|------|
| `Add(Key, StringValue)` | 新增字串型別的 Key/Value。 |
| `Add(Key, IntegerValue)` | 新增整數型別的 Key/Value。 |
| `ContainsKey` | 檢查指定 Key 是否存在。 |
| `TryGetValue` | 取得字串或整數型別的 Value。 |

內部使用與 `TStringList` 項目關聯的物件儲存資料。

### 使用範例

```delphi
uses
  Classes, SysUtils, StringListHelperUnit;

var
  Items: TStringList;
  Value: Integer;
begin
  Items := TStringList.Create(True);
  try
    Items.Sorted := True;

    Items.Add('UserID', 1001);
    Items.Add('RoleID', 20);

    if Items.ContainsKey('UserID') then
      Writeln('UserID exists');

    if Items.TryGetValue('UserID', Value) then
      Writeln(IntToStr(Value));

  finally
    Items.Free;
  end;
end;
```

### 注意事項

此實作使用 `TObject` 儲存對應的 Value。

為避免記憶體洩漏，建議讓 `TStringList` 擁有這些物件。

取得資料時，也必須使用與原始儲存值一致的型別。

這是一個輕量化的 `TStringList` 擴充，而不是通用的泛型 Dictionary。

---

## 11. 字串加解密工具

`DBXCypher.pas` 包含基於 PC1 Cipher 的字串加解密函式。

### 支援函式

| 函式 | 說明 |
|------|------|
| `EncodePC1Str` | 使用 PC1 加密字串，再以 Base64 編碼。 |
| `DecodePC1Str` | 將 Base64 解碼並使用 PC1 解密。 |
| `EncodePC1StrRandom` | 加入隨機前置字元後進行加密。 |
| `DecodePC1StrRandom` | 解密後移除隨機前置字元。 |

隨機版本會在明文前加入四個英數字元，再進行加密，以降低相同明文產生固定密文的情況。

### 注意事項

- 目前 `DBXCypher.pas` 是函式程式碼集合，而非完整的獨立 Delphi Unit。
- PC1 屬於舊式加密演算法，不建議用於現代高安全性需求。
- 隨機前置字元使用 Delphi 標準虛擬亂數產生器，並非密碼學安全的 Salt。
- 新系統若需要安全加密，應優先採用現代認證式加密演算法。

這些函式主要適合既有系統的相容性用途。

---

## 12. API 參考

### JSON 工具

| Class Helper | 方法 |
|--------------|------|
| `TJSONValueHelper` | `IsJsonNumber`、`IsJsonString`、`IsJsonObject`、`IsJsonArray`、`IsJsonNull`、`AsVariant`、`AsDateTime`、`HasJsonValue`、`ValueOrDefault<T>` |
| `TJSONObjectHelper` | `FetchValue`、`TryFetchValue`、`GetVariant`、`GetValueToJO`、`GetValueToJA`、`SetVal` |
| `TJSONArrayHelper` | `Count`、`Items`（舊版相容） |
| `TJSONAncestorHelper` | `ToJson` |
| `TJSONNumberHelper` | `AsInt64` |

### 資料庫轉換

| 方法 | 輸入 | 輸出 |
|------|------|------|
| `DataSetToJSONArray` | `TDataSet` | `TJSONArray` |
| `DataSetToDJSON` | `TDataSet` | `TJSONObject` |
| `DataSetRecToJSONObj` | `TDataSet` | `TJSONObject` |
| `TableToJSONArray` | `TDBXReader` | `TJSONArray` |
| `TableRecToJSONObj` | `TDBXReader` | `TJSONObject` |
| `TableToJSONB` | `TDBXReader` | `TJSONObject` |
| `DJsonToDataSet` | `TJSONObject` | 填入 `TDataSet` |
| `TableToJSONWriter` | `TDBXReader` | `TJsonTextWriter` |
| `TableToJSONText` | `TDBXReader` | `string` |
| `FetchParamToDBXParameter` | `TParam` | 填入 `TDBXParameter` |

### 分頁參數

部分資料轉換函式支援：

- `RowCount`：最多轉換的資料筆數。`-1` 代表所有剩餘記錄。
- `RecNo`：開始轉換的資料位置，從 1 開始。

部分 `TDBXReader` 轉換方法還提供 `IsLocalConnection` 參數，控制是否由轉換函式負責釋放 Reader。

使用前應確認各方法的參數宣告。

---

## 13. 記憶體管理

本程式庫遵循 Delphi 物件生命週期與所有權管理原則。

### JSON 物件

回傳 `TJSONObject` 或 `TJSONArray` 的函式，通常會將新建立物件的所有權交給呼叫端。

使用完畢後，應自行釋放。

```delphi
JsonArray := TDBXJSONTools.DataSetToJSONArray(DataSet);
try
  // 處理 JSON。
finally
  JsonArray.Free;
end;
```

### TDBXReader 所有權

部分轉換方法提供 `IsLocalConnection` 參數。

當參數為 `True` 時，函式可能在處理完成後關閉並釋放傳入的 Reader。

提供此參數的方法，預設值通常為 `True`。

若呼叫端需要自行管理 Reader 的生命週期，應使用 `False`。

Streaming 方法沒有提供此所有權參數，因此 Reader 的生命週期由呼叫端管理。

### JSON 子物件

透過 `TJSONObject` 取得的子物件，一般由上層 JSON 物件管理。

除非已明確移轉所有權，否則不應另外釋放這些子物件。

---

## 14. 已知限制

本程式庫著重於 Delphi 既有資料存取與 JSON API 的實務整合。

目前原始碼具有以下限制。

### DataSet 重建

- `DJsonToDataSet` 需要支援動態建立的 DataSet。
- 並非所有 `TDataSet` 後代都支援所需操作。
- Metadata 尚未完整還原。
- 部分數值、日期時間、Memo 及二進位欄位需要進一步處理。
- `ftBytes` 與 `ftVarBytes` 的反向還原尚未完整。
- 目標 DataSet 會被關閉並重新建立，而非合併原有資料。
- 轉換失敗時，不保證能回復 DataSet 的原始內容與狀態。

### 空資料集

當來源 DataSet 沒有資料時，`DataSetToDJSON` 目前會直接回傳空的 JSON Object。

因此，尚不支援只有 Metadata、沒有資料列的完整往返轉換。

### JSON Helper

- 部分 `TryFetchValue` 多載的型別驗證尚不完整。
- 使用 `Double` 作為中間轉換型別時，大型 `Int64` 可能產生精度損失。
- `HasJsonValue` 的陣列索引判斷存在邊界條件問題。
- JSON 強制轉型可能因實際資料型別不符而產生例外。

### Streaming

- `TableToJSONWriter` 不會建立完整 JSON DOM。
- 處理單筆 Blob 或 Bytes 時仍可能需要額外緩衝區。
- `TableToJSONText` 仍會將完整 JSON 字串保留在記憶體中。

### 二進位資料

- Base64 編解碼依賴 Windows API。
- `EncodeCleanStream` 偵測到特定檔案特徵碼時，可能移除前置資料。
- 並非所有二進位欄位型別均保證能完整往返還原。

### 跨版本相容性

本專案包含針對不同 Delphi 版本的條件編譯。

但目前尚未對所有版本與功能組合完成自動化編譯及測試。

建議使用者依實際的 Delphi 版本、資料庫元件及欄位型別進行驗證。

---

## 15. 示範專案

JSON 示範專案：

[Demo-JSON / JsonMarshalling](Demo-JSON/JsonMarshalling)

此專案可作為了解 Delphi JSON 操作的起點。

資料庫序列化的主要實作：

[EdenDBXJsonHelper.pas](EdenDBXJsonHelper.pas)

SQL Server 輔助工具：

[DBExpress.MSSQL.Factory.pas](DBExpress.MSSQL.Factory.pas)

---

## 16. 設計理念

本專案主要遵循三個設計原則。

### 擴充既有 API

透過 Delphi Class Helper 增加原始類別的操作能力，而不是重新建立或取代底層類別。

既有系統可以依需要逐步導入特定 Helper，而不必全面更換資料存取架構。

### 保留資料互通性

支援 Delphi 常見資料集結構，以及既有 DataSnap JSON 格式。

在可支援的範圍內，除了資料內容，也盡可能保留重要的欄位 Metadata。

讓不同系統之間的資料交換更容易實作。

### 減少重複程式碼

將常見操作集中處理，包括：

- JSON 型別判斷
- JSON 值讀取
- 資料庫欄位轉換
- 二進位資料序列化
- SQL 參數指定
- DataSet 序列化

讓應用程式可以將重點放在商業邏輯，而不是反覆撰寫底層資料轉換程式。

本程式庫不是 ORM，也不是資料庫驅動程式，更不是要取代 dbExpress、DataSnap 或 FireDAC。

---

## 17. 授權

本專案採用 [MIT License](LICENSE)。

Copyright (c) 2023 Eden5Wu.

使用者可以依 MIT License 條款，自由使用、修改、散布及整合本程式庫至其他專案。

---

## 18. 作者

**Eden Wu（You-Bin Wu／吳祐賓）**

GitHub：[Eden5Wu](https://github.com/Eden5Wu)

專案網址：[HelperClass](https://github.com/Eden5Wu/HelperClass)

---

**Delphi Helper Class Library** — 透過輕量化、可重複使用且符合實務需求的工具，擴充 Delphi 既有的開發能力。
