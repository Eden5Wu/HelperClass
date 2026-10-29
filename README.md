# Delphi Helper Class Library

[繁體中文版](README_ZH.md)

A collection of Delphi Class Helpers and utility classes designed to simplify JSON processing, database operations, and data serialization.

The library extends Delphi's existing APIs without modifying their original classes, providing reusable methods for working with `TJSONValue`, `TJSONObject`, `TDataSet`, `TDBXReader`, and other Delphi classes.

Its primary focus is **database-to-JSON interoperability**, particularly for applications using dbExpress, DataSnap, and REST services.

## Key Features

- **JSON Class Helpers** — Simplify JSON value access, type conversion, and object manipulation.
- **Database Serialization** — Convert `TDataSet` and `TDBXReader` results into JSON.
- **DataSnap Compatibility** — Generate and consume DataSnap Table Block JSON structures.
- **Bidirectional Conversion** — Reconstruct supported in-memory datasets from Table Block JSON.
- **Streaming JSON** — Serialize large database result sets without constructing a complete JSON DOM.
- **Binary Data Handling** — Support Base64, Blob, and byte-array representations.
- **Cross-Version Compatibility** — Provide compatibility helpers for different Delphi JSON implementations.
- **Additional Utilities** — Include SQL Server dbExpress helpers and `TStringList` extensions.

The project is intended to complement Delphi's existing frameworks rather than replace them.

---

## 1. Project Structure

| File | Description |
|------|-------------|
| `EdenDBXJsonHelper.pas` | JSON helpers, database serialization, DataSnap Table Block conversion, and Base64 utilities. |
| `DBExpress.MSSQL.Factory.pas` | SQL Server dbExpress connection management, command execution, parameter handling, and metadata utilities. |
| `StringListHelperUnit.pas` | Extends `TStringList` with typed Key/Value operations. |
| `DBXCypher.pas` | PC1 encryption/decryption utility functions with optional randomized prefixes. |
| `Demo-JSON/` | Example Delphi project demonstrating JSON-related functionality. |
| `README_ZH.md` | Traditional Chinese documentation. |
| `LICENSE` | MIT License. |

The main component is `EdenDBXJsonHelper.pas`.

Each unit serves a different purpose and may be used independently where its dependencies are satisfied.

---

## 2. Requirements

### Delphi Compatibility

The library uses conditional compilation to accommodate differences between Delphi versions.

| Feature | Implementation / Requirement |
|---------|------------------------------|
| JSON support on older Delphi versions | `DBXJSON` |
| JSON support on Delphi XE7+ | `System.JSON` |
| Generic `ValueOrDefault<T>` | Delphi XE7+ |
| Streaming JSON serialization | Delphi XE8+ |
| Database conversion | dbExpress and `TDataSet` APIs |
| Base64 implementation | Windows CryptoAPI (`crypt32.dll`) |

The source includes compatibility logic for older Delphi releases, including Windows XP-related Base64 handling.

**Note:** Compatibility with every Delphi version has not been independently verified. Conditional compilation support should not be interpreted as a guarantee that all features have been tested on every compiler version.

### Supported Data Sources

Forward serialization supports:

- `TDBXReader`
- `TClientDataSet`
- `TFDMemTable`
- Other compatible `TDataSet` descendants

Reverse conversion is more restrictive. The target dataset must support dynamic field creation and record insertion.

`TClientDataSet` and `TFDMemTable` are the intended targets for `DJsonToDataSet`.

### Platform

The Base64 implementation depends on Windows `crypt32.dll`.

Replacing the Windows-specific implementation is necessary for non-Windows platforms.

---

## 3. Getting Started

### Installation

Clone the repository:

```bash
git clone https://github.com/Eden5Wu/HelperClass.git
```

Add the required `.pas` files to your Delphi project's search path.

For JSON and database serialization, include:

```delphi
uses
  EdenDBXJsonHelper;
```

The Class Helpers become available to compatible classes when the unit is included in the `uses` clause.

No custom component installation is required.

### Quick Start: DataSet to JSON

```delphi
uses
  SysUtils, DB, DBClient, DBXCommon,
  DBXJSONCommon, EdenDBXJsonHelper;

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

Output:

```json
[
  {"ID": 1, "Name": "Alice"},
  {"ID": 2, "Name": "Bob"}
]
```

The output is a standard JSON array suitable for JavaScript applications and REST APIs.

---

## 4. JSON Class Helpers

`EdenDBXJsonHelper.pas` extends Delphi's built-in JSON classes using Class Helpers.

These methods simplify common JSON operations and reduce repetitive type checking and casting code.

### 4.1 TJSONValueHelper

Extends `TJSONValue` with additional type inspection and conversion methods.

| Method | Description |
|--------|-------------|
| `IsJsonNumber` | Checks whether a value is a JSON number. |
| `IsJsonString` | Checks whether a value is a JSON string. |
| `IsJsonObject` | Checks whether a value is a JSON object. |
| `IsJsonArray` | Checks whether a value is a JSON array. |
| `IsJsonNull` | Checks whether a value is JSON null. |
| `IsJsonTrue` | Checks whether a value is JSON true. |
| `IsJsonFalse` | Checks whether a value is JSON false. |
| `AsJsonNumber` | Casts a value to `TJSONNumber`. |
| `AsJsonString` | Casts a value to `TJSONString`. |
| `AsJsonObject` | Casts a value to `TJSONObject`. |
| `AsJsonArray` | Casts a value to `TJSONArray`. |
| `AsVariant` | Converts a JSON value to a Delphi `Variant`. |
| `AsDateTime` | Converts a compatible JSON date/time string to `TDateTime`. |
| `HasJsonValue` | Checks for the existence of a member or array element. |
| `ValueOrDefault<T>` | Returns a typed value or a specified default value. XE7+. |

The `AsJson...` methods are casting helpers, not non-throwing conversion methods.

### 4.2 TJSONObjectHelper

Extends `TJSONObject` with convenient value retrieval and modification methods.

| Method | Description |
|--------|-------------|
| `FetchValue` | Retrieves a JSON value using its member name. |
| `TryFetchValue` | Retrieves and converts values using overloaded methods. |
| `GetVariant` | Retrieves a value as a Delphi `Variant`. |
| `GetValueToJO` | Retrieves a nested `TJSONObject`. |
| `GetValueToJA` | Retrieves a nested `TJSONArray`. |
| `SetVal` | Adds or replaces a named JSON value. |

`SetVal` supports several value types, including:

- `string`
- `Integer`
- `Int64`
- `Double`
- `Boolean`
- `TJSONValue`

### Example: Reading JSON Values

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

Output:

```text
Alice
25
```

### Example: ValueOrDefault<T>

Available on Delphi XE7 and later.

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
    // Returns 18 when the value is missing.
  finally
    JsonObj.Free;
  end;
end;
```

`ValueOrDefault<T>` also returns the default when the value is JSON null or a supported conversion raises an exception.

### Other JSON Helpers

| Helper | Feature |
|--------|---------|
| `TJSONAncestorHelper` | JSON serialization using `ToJson`. |
| `TJSONNumberHelper` | Integer conversion using `AsInt64`. |
| `TJSONArrayHelper` | Legacy compatibility for `Count` and `Items`. |
| `TJSONObjectHelper` | Legacy compatibility for `Count` and `Pairs`. |

Some compatibility helpers are conditionally compiled because newer Delphi versions already provide equivalent functionality.

---

## 5. Database and JSON Conversion

The `TDBXJSONToolsHelper` provides methods for converting between Delphi database structures and JSON.

Two primary serialization formats are supported:

1. **Row-oriented JSON**
2. **DataSnap Table Block JSON**

These formats serve different purposes.

### 5.1 Row-Oriented JSON

A row-oriented JSON array represents each database record as a JSON object.

Example:

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

Relevant methods:

| Method | Source |
|--------|--------|
| `DataSetToJSONArray` | `TDataSet` |
| `TableToJSONArray` | `TDBXReader` |
| `DataSetRecToJSONObj` | Current `TDataSet` record |
| `TableRecToJSONObj` | Selected `TDBXReader` record |

This format is suitable for:

- REST API responses
- JavaScript applications
- Web-based data grids
- General JSON consumers

It is usually the preferred format when database field metadata is unnecessary.

### 5.2 DataSnap Table Block JSON

DataSnap Table Block JSON preserves database field metadata along with the actual values.

Unlike row-oriented JSON, values are organized by column.

Conceptual structure:

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

The example above illustrates the structure; actual metadata entries contain numeric values defined by the DBX serialization format.

Relevant methods:

| Method | Operation |
|--------|-----------|
| `DataSetToDJSON` | DataSet → Table Block JSON |
| `TableToJSONB` | DBXReader → Table Block JSON |
| `DJsonToDataSet` | Table Block JSON → DataSet |

This format is useful when consumers need database field information in addition to record values.

Typical scenarios include:

- DataSnap interoperability
- Reconstructing in-memory datasets
- Transferring database metadata
- Legacy Delphi application integration

---

## 6. Bidirectional DataSet Conversion

The library provides limited bidirectional conversion between supported in-memory datasets and DataSnap Table Block JSON.

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

### Example: Exporting a DataSet

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

### Example: Reconstructing a DataSet

```delphi
var
  JsonObj: TJSONObject;
  DataSet: TClientDataSet;
begin
  // JsonObj contains valid DataSnap Table Block JSON.

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

`DJsonToDataSet` performs the following operations:

1. Reads the `table` metadata array.
2. Extracts field names and DBX data types.
3. Maps supported DBX types to Delphi `TFieldType` values.
4. Creates field definitions.
5. Attempts to create the target dataset through RTTI.
6. Reads the column-oriented values.
7. Inserts records into the target dataset.

### Important Restrictions

`DJsonToDataSet` is intended for datasets that support:

- Dynamic field definition
- Parameterless `CreateDataSet`
- Record insertion
- In-memory data storage

The current implementation is primarily intended for `TClientDataSet` and `TFDMemTable`.

It does not guarantee lossless conversion of every field type or metadata property.

It also does not write changes back to an external database.

---

## 7. Streaming JSON Serialization

Traditional JSON serialization typically creates a complete JSON object tree before producing the final output.

For large result sets, this can increase memory usage significantly.

The library therefore provides forward-only JSON serialization using `TJsonTextWriter`.

### Available Methods

| Method | Description |
|--------|-------------|
| `TableToJSONWriter` | Writes a `TDBXReader` directly to a JSON writer. |
| `TableToJSONText` | Converts a `TDBXReader` to a complete JSON string. |

Both methods require Delphi XE8 or later.

### TableToJSONText

The simplest way to obtain a JSON string from a `TDBXReader`:

```delphi
var
  JsonText: string;
begin
  JsonText := TDBXJSONTools.TableToJSONText(Reader);
end;
```

This method internally uses `TableToJSONWriter`.

However, the resulting JSON string is retained in memory.

### TableToJSONWriter

For larger result sets, writing directly to a file or another output destination avoids creating the entire JSON DOM.

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

### Advantages

- Processes records sequentially.
- Avoids constructing a complete `TJSONArray`.
- Reduces memory consumption associated with JSON DOM objects.
- Supports direct output to compatible text writers.
- Suitable for large database exports and API responses.

### Memory Considerations

Streaming does not guarantee constant memory usage in every situation.

The current implementation may allocate buffers for individual binary fields, and `TableToJSONText` accumulates the entire output string.

For large result sets, `TableToJSONWriter` is generally preferable when the output can be written incrementally.

---

## 8. Binary Data Handling

JSON has no native binary data type.

The library supports two representations for binary values:

- Base64-encoded strings
- JSON arrays of byte values

### Binary Representation

| Data Type | JSON Representation |
|-----------|---------------------|
| Blob / BinaryBlob | Base64 string |
| Bytes in Table Block format | JSON numeric array |
| Memo / WideMemo | Text string |

Example Base64:

```json
{
  "Document": "SGVsbG8="
}
```

Example Byte Array:

```json
{
  "Version": [72, 101, 108, 108, 111]
}
```

The appropriate representation depends on the conversion method and DBX data type.

In particular, row-oriented and Table Block serialization do not necessarily use identical representations for `BytesType`.

### TEdenBase64

The following functions are available:

| Method | Description |
|--------|-------------|
| `EncodeStream` | Encodes a binary stream as Base64. |
| `DecodeToStream` | Decodes a Base64 string into a stream. |
| `EncodeCleanStream` | Attempts to remove a recognized file prefix before Base64 encoding. |

The implementation uses Windows CryptoAPI.

`EncodeCleanStream` scans for selected file signatures, including BMP, JPEG, PNG, GIF, PDF, and ZIP.

**Important:** `EncodeCleanStream` can remove bytes preceding a recognized signature. It should not be treated as a general-purpose lossless binary encoder.

Use `EncodeStream` when the original binary content must be preserved exactly.

### Reverse Conversion Limitations

`DJsonToDataSet` includes logic for interpreting both Base64 strings and byte arrays.

However, the current implementation does not fully support all binary field types, particularly `ftBytes` and `ftVarBytes`.

Round-trip compatibility should be verified for the actual dataset and field types used by an application.

---

## 9. SQL Server dbExpress Utilities

`DBExpress.MSSQL.Factory.pas` provides utility classes for working with SQL Server through dbExpress.

### TDBXMSSQLFactory

Encapsulates common operations involving:

- Connection creation
- SQL command preparation
- Parameter assignment
- Query execution
- Non-query execution
- Database metadata retrieval

### Main Methods

| Method | Description |
|--------|-------------|
| `GetConnection` | Returns the managed DBX connection. |
| `Prepare` | Creates and prepares a SQL command. |
| `PrepareMSQuery` | Prepares a command with SQL Server-specific statements. |
| `Execute` | Executes a non-query SQL command. |
| `ExecuteQuery` | Executes a query and returns a `TDBXReader`. |
| `FillParameters` | Assigns values to DBX parameters. |
| `DBXGetTableList` | Retrieves database table metadata. |
| `OleDBConnectionStringToDBX` | Converts selected OLE DB connection settings into DBX connection properties. |

### TDBXCommandHelper

Extends `TDBXCommand` with:

- `CreateBlobParameter`
- `ExecuteSmartQuery`

`ExecuteSmartQuery` skips result sets without columns to locate a readable result set.

This utility handles a particular query-result pattern and should not be interpreted as a general replacement for multi-result-set processing.

### TDBXParameterHelper

Provides typed parameter properties:

```delphi
Param.AsString := 'Alice';
Param.AsInt32 := 100;
Param.AsBoolean := True;
Param.AsDateTime := Now;
```

Additional methods include `Clear`, `AsDouble`, and `AsAnsiString`.

These helpers reduce repetitive calls to the underlying DBX parameter value API.

---

## 10. TStringList Extensions

`StringListHelperUnit.pas` extends `TStringList` with additional Key/Value operations.

### Available Methods

| Method | Description |
|--------|-------------|
| `Add(Key, StringValue)` | Adds a string value associated with a key. |
| `Add(Key, IntegerValue)` | Adds an integer value associated with a key. |
| `ContainsKey` | Checks whether a key exists. |
| `TryGetValue` | Retrieves a string or integer value. |

Values are stored through objects associated with individual `TStringList` entries.

### Example

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

### Notes

The implementation uses associated `TObject` instances to store typed values.

The list should own those objects to avoid memory leaks.

Callers must retrieve each key using the same value type originally stored.

This implementation is a lightweight extension of `TStringList`, not a general-purpose generic dictionary.

---

## 11. Additional Encryption Utilities

`DBXCypher.pas` contains utility functions based on the PC1 cipher.

### Available Functions

| Function | Description |
|----------|-------------|
| `EncodePC1Str` | Encrypts a string using PC1 and encodes the result as Base64. |
| `DecodePC1Str` | Decodes and decrypts the string. |
| `EncodePC1StrRandom` | Adds a randomized prefix before encryption. |
| `DecodePC1StrRandom` | Decrypts and removes the randomized prefix. |

The randomized variant prepends four alphanumeric characters before encryption, reducing deterministic output for repeated plaintext values.

### Important Notes

- The file is currently a collection of functions rather than a complete standalone Delphi unit.
- PC1 is a legacy cipher and is not recommended for modern security-sensitive applications.
- The randomized prefix uses Delphi's standard pseudorandom generator and is not a cryptographic salt.
- New applications requiring strong encryption should use modern authenticated encryption instead.

These functions are retained primarily for compatibility with existing applications.

---

## 12. API Reference

### JSON Utilities

| Class Helper | Methods |
|--------------|---------|
| `TJSONValueHelper` | `IsJsonNumber`, `IsJsonString`, `IsJsonObject`, `IsJsonArray`, `IsJsonNull`, `AsVariant`, `AsDateTime`, `HasJsonValue`, `ValueOrDefault<T>` |
| `TJSONObjectHelper` | `FetchValue`, `TryFetchValue`, `GetVariant`, `GetValueToJO`, `GetValueToJA`, `SetVal` |
| `TJSONArrayHelper` | `Count`, `Items` (legacy compatibility) |
| `TJSONAncestorHelper` | `ToJson` |
| `TJSONNumberHelper` | `AsInt64` |

### Database Conversion

| Method | Input | Output |
|--------|-------|--------|
| `DataSetToJSONArray` | `TDataSet` | `TJSONArray` |
| `DataSetToDJSON` | `TDataSet` | `TJSONObject` |
| `DataSetRecToJSONObj` | `TDataSet` | `TJSONObject` |
| `TableToJSONArray` | `TDBXReader` | `TJSONArray` |
| `TableRecToJSONObj` | `TDBXReader` | `TJSONObject` |
| `TableToJSONB` | `TDBXReader` | `TJSONObject` |
| `DJsonToDataSet` | `TJSONObject` | Populates `TDataSet` |
| `TableToJSONWriter` | `TDBXReader` | `TJsonTextWriter` |
| `TableToJSONText` | `TDBXReader` | `string` |
| `FetchParamToDBXParameter` | `TParam` | Populates `TDBXParameter` |

### Pagination Parameters

Several conversion methods accept:

- `RowCount` — Maximum number of records to serialize. `-1` means all remaining records.
- `RecNo` — Starting record position, using a 1-based index.

For methods that accept `IsLocalConnection`, the flag controls whether the supplied reader is released by the conversion function.

Refer to the method signature before calling a conversion routine.

---

## 13. Memory Management

The library follows Delphi's object ownership model.

### JSON Objects

Functions returning `TJSONObject` or `TJSONArray` generally transfer ownership of the returned object to the caller.

Always release returned JSON objects after use.

```delphi
JsonArray := TDBXJSONTools.DataSetToJSONArray(DataSet);
try
  // Process JSON.
finally
  JsonArray.Free;
end;
```

### TDBXReader Ownership

Some conversion methods accept an `IsLocalConnection` parameter.

When this parameter is `True`, the method may close and free the supplied reader.

The default value is `True` for methods that expose this parameter.

Use `False` when the caller must retain responsibility for releasing the reader.

Streaming methods do not expose this ownership flag. The caller remains responsible for managing the reader's lifetime.

### JSON Child Values

Values retrieved from a `TJSONObject` are generally owned by their parent JSON structure.

Do not separately free borrowed child values unless ownership has explicitly been transferred.

---

## 14. Known Limitations

The library focuses on practical compatibility with Delphi's existing database and JSON implementations.

The following limitations apply to the current source code.

### DataSet Reconstruction

- `DJsonToDataSet` requires a compatible dataset supporting dynamic creation.
- Not every `TDataSet` descendant supports the required operations.
- Field metadata is not fully reconstructed.
- Some numeric, date/time, Memo, and binary field types require additional handling.
- `ftBytes` and `ftVarBytes` reconstruction is incomplete.
- The target dataset is closed and rebuilt rather than merged with existing records.
- Conversion failures do not guarantee rollback to the original dataset state.

### Empty Datasets

`DataSetToDJSON` currently returns an empty JSON object when the source dataset contains no records.

Consequently, metadata-only round trips for empty datasets are not supported by the current implementation.

### JSON Helpers

- Some `TryFetchValue` overloads perform limited type validation.
- Large `Int64` values may lose precision in conversion paths using `Double`.
- The array-index branch of `HasJsonValue` contains a boundary-condition issue in the current implementation.
- JSON casting helpers may raise exceptions when the actual type does not match the requested type.

### Streaming

- `TableToJSONWriter` avoids constructing a complete JSON DOM.
- Individual Blob and Bytes values can still require memory buffers.
- `TableToJSONText` retains the completed JSON string in memory.

### Binary Data

- Base64 encoding relies on Windows APIs.
- `EncodeCleanStream` may remove leading bytes when a recognized file signature is detected.
- Complete binary round-trip preservation is not guaranteed for every dataset field type.

### Cross-Version Compatibility

The project contains conditional compilation for multiple Delphi versions, but not all combinations have been validated through automated compilation and testing.

Applications should test the methods and field types required by their target environment.

---

## 15. Examples

Example project:

[Demo-JSON / JsonMarshalling](Demo-JSON/JsonMarshalling)

The example project provides a starting point for exploring JSON-related operations in Delphi.

For database serialization, the relevant methods are implemented in:

[EdenDBXJsonHelper.pas](EdenDBXJsonHelper.pas)

For SQL Server utilities:

[DBExpress.MSSQL.Factory.pas](DBExpress.MSSQL.Factory.pas)

---

## 16. Design Philosophy

This project follows three principles.

### Extend Existing APIs

Use Delphi Class Helpers to provide additional functionality without replacing the underlying classes.

Existing applications can adopt individual helpers without migrating to a new data access framework.

### Preserve Interoperability

Support familiar Delphi database structures and established DataSnap JSON representations.

The objective is to simplify communication between applications while preserving useful metadata whenever supported.

### Reduce Repetitive Code

Centralize frequently repeated operations such as:

- JSON type inspection
- JSON value retrieval
- Database field conversion
- Binary serialization
- Parameter assignment
- Dataset serialization

This approach helps keep application code focused on business logic rather than low-level conversion details.

The library is not intended to be an ORM, a database driver, or a replacement for dbExpress, DataSnap, or FireDAC.

---

## 17. License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2023 Eden5Wu.

You may use, modify, distribute, and incorporate the code into other projects subject to the terms of the MIT License.

---

## 18. Author

**Eden Wu (You-Bin Wu)**

GitHub: [Eden5Wu](https://github.com/Eden5Wu)

Repository: [HelperClass](https://github.com/Eden5Wu/HelperClass)

---

**Delphi Helper Class Library** — Extending Delphi's existing capabilities through reusable, lightweight, and practical utilities.
