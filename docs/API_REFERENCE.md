# API Reference

[Back to README](../README.md) | [繁體中文版](../README_ZH.md)

## Overview

This document provides a technical reference for the public APIs exposed by the Delphi Helper Class Library.

The library extends existing Delphi classes through Class Helpers and provides additional utilities for JSON processing, database serialization, SQL Server access, and collection management.

### Covered Units

| Unit | Main Classes | Purpose |
|---|---|---|
| `EdenDBXJsonHelper.pas` | `TJSONValueHelper`, `TJSONObjectHelper`, `TDBXJSONToolsHelper`, `TEdenBase64` | JSON processing and database serialization |
| `DBExpress.MSSQL.Factory.pas` | `TDBXMSSQLFactory`, `TDBXCommandHelper`, `TDBXParameterHelper` | SQL Server dbExpress utilities |
| `StringListHelperUnit.pas` | `TStringListHelper` | Typed Key/Value collection operations |
| `DBXCypher.pas` | Standalone functions | Legacy PC1 string encryption utilities |

### Tested Delphi Versions

The library has been tested by the project maintainer with:

- Delphi XE
- Delphi XE7
- Delphi 10
- Delphi 11

Some APIs are available only when the corresponding Delphi compiler and RTL provide the required functionality.

### API Conventions

Unless otherwise specified:

- Method signatures reflect the public declarations in the source code.
- Returned `TJSONObject` and `TJSONArray` instances are owned by the caller.
- JSON child values retrieved from an existing JSON object are borrowed references.
- `RowCount = -1` means all remaining records.
- `RecNo = 1` identifies the first record.
- Methods exposing `IsLocalConnection = True` close and free the supplied `TDBXReader`.
- Conversion methods may raise exceptions for unsupported types or invalid input.

---

# 1. TJSONValueHelper

**Unit:** `EdenDBXJsonHelper.pas`

**Extends:** `TJSONValue`

Provides additional methods for inspecting JSON types, converting JSON values, and retrieving optional values.

## 1.1 Type Inspection

### Signatures

```delphi
function IsJsonNumber: Boolean;
function IsJsonTrue: Boolean;
function IsJsonFalse: Boolean;
function IsJsonString: Boolean;
function IsJsonNull: Boolean;
function IsJsonObject: Boolean;
function IsJsonArray: Boolean;
```

### Description

These methods identify the actual JSON value type.

| Method | Returns True When |
|---|---|
| `IsJsonNumber` | The value is `TJSONNumber` |
| `IsJsonTrue` | The value is `TJSONTrue` |
| `IsJsonFalse` | The value is `TJSONFalse` |
| `IsJsonString` | The value is `TJSONString` |
| `IsJsonNull` | The value is `TJSONNull` |
| `IsJsonObject` | The value is `TJSONObject` |
| `IsJsonArray` | The value is `TJSONArray` |

The implementation compares the runtime class with the corresponding JSON class.

### Example

```delphi
var
  LValue: TJSONValue;
begin
  LValue := TJSONNumber.Create(100);
  try
    if LValue.IsJsonNumber then
      Writeln('JSON Number');
  finally
    LValue.Free;
  end;
end;
```

**Output:**

```text
JSON Number
```

## 1.2 JSON Type Casting

### Signatures

```delphi
function AsJsonNumber: TJSONNumber;
function AsJsonString: TJSONString;
function AsJsonObject: TJSONObject;
function AsJsonArray: TJSONArray;
```

### Description

Provides convenient type casting without repeatedly writing explicit `as` expressions.

| Method | Return Type |
|---|---|
| `AsJsonNumber` | `TJSONNumber` |
| `AsJsonString` | `TJSONString` |
| `AsJsonObject` | `TJSONObject` |
| `AsJsonArray` | `TJSONArray` |

### Example

```delphi
var
  LValue: TJSONValue;
  LNumber: TJSONNumber;
begin
  LValue := TJSONNumber.Create(123);
  try
    if LValue.IsJsonNumber then
    begin
      LNumber := LValue.AsJsonNumber;
      Writeln(LNumber.ToString);
    end;
  finally
    LValue.Free;
  end;
end;
```

### Remarks

- These methods perform object casting, not arbitrary value conversion.
- A mismatched type can raise an exception.
- The returned reference points to the original JSON object.
- The caller must not free the returned reference separately.

## 1.3 AsVariant

### Signature

```delphi
function AsVariant: Variant;
```

### Description

Converts a JSON value into a corresponding Delphi `Variant`.

### Type Mapping

| JSON Type | Delphi Variant |
|---|---|
| JSON String | String |
| JSON Integer | Int64 |
| JSON Decimal | Double |
| JSON True | Boolean True |
| JSON False | Boolean False |
| JSON Null | Null |
| JSON Object | Serialized JSON string |
| JSON Array | Serialized JSON string |

### Example

```delphi
var
  LValue: TJSONValue;
  LResult: Variant;
begin
  LValue := TJSONNumber.Create(100);
  try
    LResult := LValue.AsVariant;
    Writeln(VarToStr(LResult));
  finally
    LValue.Free;
  end;
end;
```

### Remarks

- Objects and arrays are converted to JSON text, not native Delphi collections.
- Integer and floating-point conversion depends on the JSON number's textual representation.
- Extremely large values or unsupported numeric representations may cause conversion exceptions.
- This method does not automatically preserve the original database field type.

## 1.4 AsDateTime

### Signature

```delphi
function AsDateTime: TDateTime;
```

### Description

Converts a JSON string containing a compatible XML/ISO-style date-time representation into a Delphi `TDateTime`.

Internally uses `XMLTimeToDateTime`.

### Example

```delphi
var
  LValue: TJSONValue;
  LDate: TDateTime;
begin
  LValue := TJSONString.Create('2026-10-29T09:30:00');
  try
    LDate := LValue.AsDateTime;
  finally
    LValue.Free;
  end;
end;
```

### Remarks

- The source value must be a `TJSONString`.
- Invalid date-time strings may raise an exception.
- Timezone handling follows the implementation's `XMLTimeToDateTime` conversion rules.

## 1.5 HasJsonValue

### Signature

```delphi
function HasJsonValue(
  const APath: string = ''
): Boolean;
```

### Parameters

| Parameter | Type | Description |
|---|---|---|
| `APath` | `string` | JSON member name or array index represented as a string |

### Description

Checks whether a JSON value contains the specified member or array element.

Behavior depends on the current JSON type.

| JSON Type | Behavior |
|---|---|
| Object | Checks whether the specified member can be found |
| Array | Checks whether the specified zero-based index exists |
| Scalar | Returns True when `APath` is empty |

### Example

```delphi
var
  LObject: TJSONObject;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('Name', 'Alice');

    if LObject.HasJsonValue('Name') then
      Writeln('Name exists');
  finally
    LObject.Free;
  end;
end;
```

### Remarks

- Array indexes are zero-based.
- Negative and out-of-range array indexes return False.
- JSON null is still an existing JSON value.
- Object member lookup follows the JSON API provided by the Delphi version.

## 1.6 ValueOrDefault<T>

**Availability:** Delphi XE7 and later.

### Signature

```delphi
function ValueOrDefault<T>(
  const APath: string;
  const ADefault: T
): T;
```

### Parameters

| Parameter | Type | Description |
|---|---|---|
| `APath` | `string` | JSON member name or supported JSON path |
| `ADefault` | `T` | Value returned when retrieval or conversion fails |

### Returns

The converted value of type `T`, or `ADefault`.

### Description

Attempts to retrieve a JSON value using `FindValue` and convert it using `AsType<T>`.

Returns the default value when:

- The requested value does not exist.
- The requested value is JSON null.
- The conversion raises an exception.

### Example

```delphi
var
  LObject: TJSONObject;
  LAge: Integer;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('Name', 'Alice');

    LAge := LObject.ValueOrDefault<Integer>('Age', 18);

    // Returns 18 because Age does not exist.
  finally
    LObject.Free;
  end;
end;
```

### Remarks

- Requires `CompilerVersion >= 28`.
- Uses Delphi's generic JSON conversion capabilities.
- Conversion behavior depends on the requested type and RTL implementation.

---

# 2. TJSONObjectHelper

**Unit:** `EdenDBXJsonHelper.pas`

**Extends:** `TJSONObject`

Provides additional methods for retrieving, converting, and modifying JSON object members.

## 2.1 FetchValue

### Signature

```delphi
function FetchValue(
  const APairName: string
): TJSONValue;
```

### Description

Retrieves the value associated with a JSON member name.

### Parameters

| Parameter | Description |
|---|---|
| `APairName` | Name of the JSON member |

### Returns

- The matching `TJSONValue` when found.
- `nil` when the member does not exist.

### Example

```delphi
var
  LObject: TJSONObject;
  LValue: TJSONValue;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('Name', 'Alice');

    LValue := LObject.FetchValue('Name');

    if Assigned(LValue) then
      Writeln(LValue.ToString);
  finally
    LObject.Free;
  end;
end;
```

### Remarks

- Member names are case-sensitive.
- The method retrieves a direct member by name.
- It does not perform arbitrary nested-path traversal.
- The returned value remains owned by the parent JSON object.

## 2.2 TryFetchValue

### Signatures

```delphi
function TryFetchValue(
  const APath: string;
  out AValue: string
): Boolean; overload;

function TryFetchValue(
  const APath: string;
  out AValue: Int64
): Boolean; overload;

function TryFetchValue(
  const APath: string;
  out AValue: Double
): Boolean; overload;

function TryFetchValue(
  const APath: string;
  out AValue: Boolean
): Boolean; overload;
```

### Description

Retrieves a JSON value and attempts to convert it into the requested Delphi type.

The return value indicates whether retrieval and conversion succeeded.

### Supported Output Types

| Output Type | Conversion |
|---|---|
| `string` | JSON string, number, or boolean to text |
| `Int64` | Parses integer text directly; also accepts supported decimal/scientific representations |
| `Double` | Parses numeric text |
| `Boolean` | Parses `true` or `false`, ignoring case |

### Example

```delphi
var
  LObject: TJSONObject;
  LName: string;
  LAge: Int64;
  LActive: Boolean;
begin
  LObject := TJSONObject.ParseJSONValue(
    '{"Name":"Alice","Age":25,"Active":true}'
  ) as TJSONObject;

  try
    if LObject.TryFetchValue('Name', LName) then
      Writeln(LName);

    if LObject.TryFetchValue('Age', LAge) then
      Writeln(IntToStr(LAge));

    if LObject.TryFetchValue('Active', LActive) then
      Writeln(BoolToStr(LActive, True));
  finally
    LObject.Free;
  end;
end;
```

### Conversion Details

#### String

The string overload accepts:

- `TJSONString`
- `TJSONNumber`
- `TJSONTrue`
- `TJSONFalse`

JSON null, arrays, and objects return False.

#### Int64

The integer overload first attempts direct `Int64` parsing to preserve integer precision.

When the input contains a decimal point or exponent, it attempts floating-point parsing and rounding.

The method rejects values outside the supported `Int64` range.

#### Double

The floating-point overload uses a decimal point as the decimal separator and rejects NaN or infinite results.

#### Boolean

The Boolean overload accepts the text representations:

```text
true
false
```

Case is ignored.

Unrecognized values return False.

### Remarks

- String retrieval uses `FindValue` on Delphi XE7 and later.
- Older Delphi versions use `FetchValue`, which retrieves direct members.
- Failed conversions return False and initialize the output value.
- Boolean False is a valid conversion result; the function's Boolean return value indicates success, not the converted value.
- Invalid values are not silently accepted as successful conversions.

## 2.3 GetVariant

### Signature

```delphi
function GetVariant(
  const Name: string
): Variant;
```

### Description

Retrieves a named member and converts it using `TJSONValueHelper.AsVariant`.

### Returns

- A converted `Variant` when the member exists.
- `Null` when the member is missing.

### Example

```delphi
var
  LValue: Variant;
begin
  LValue := LObject.GetVariant('Age');
end;
```

## 2.4 GetValueToJO

### Signature

```delphi
function GetValueToJO(
  const Name: string
): TJSONObject;
```

### Description

Retrieves a named member as a `TJSONObject`.

### Example

Given:

```json
{
  "User": {
    "ID": 100,
    "Name": "Alice"
  }
}
```

Usage:

```delphi
var
  LUser: TJSONObject;
begin
  LUser := LObject.GetValueToJO('User');

  if Assigned(LUser) then
    Writeln(LUser.ToString);
end;
```

### Remarks

- Returns `nil` when the member does not exist.
- A member containing an incompatible type may raise a casting exception.
- The returned object is owned by the original JSON structure.

## 2.5 GetValueToJA

### Signature

```delphi
function GetValueToJA(
  const Name: string
): TJSONArray;
```

### Description

Retrieves a named member as a `TJSONArray`.

### Example

Given:

```json
{
  "Items": [10, 20, 30]
}
```

Usage:

```delphi
var
  LItems: TJSONArray;
begin
  LItems := LObject.GetValueToJA('Items');

  if Assigned(LItems) then
    Writeln(IntToStr(LItems.Count));
end;
```

### Remarks

- Returns `nil` when the member does not exist.
- A member containing an incompatible type may raise a casting exception.
- The returned array is owned by the parent JSON object.

## 2.6 SetVal

### Signatures

```delphi
function SetVal(
  const Name: string;
  const Value: string
): TJSONObject; overload;

function SetVal(
  const Name: string;
  Value: Integer
): TJSONObject; overload;

function SetVal(
  const Name: string;
  Value: Int64
): TJSONObject; overload;

function SetVal(
  const Name: string;
  Value: Double
): TJSONObject; overload;

function SetVal(
  const Name: string;
  Value: Boolean
): TJSONObject; overload;

function SetVal(
  const Name: string;
  Value: TJSONValue
): TJSONObject; overload;
```

### Description

Adds or replaces a named JSON member.

If the member already exists, its previous JSON pair is removed and freed.

The method returns the current `TJSONObject`, allowing chained calls.

### Example

```delphi
var
  LObject: TJSONObject;
begin
  LObject := TJSONObject.Create;
  try
    LObject
      .SetVal('ID', 100)
      .SetVal('Name', 'Alice')
      .SetVal('Active', True);

    Writeln(LObject.ToString);
  finally
    LObject.Free;
  end;
end;
```

### Output

```json
{
  "ID": 100,
  "Name": "Alice",
  "Active": true
}
```

### Remarks

- Returns `Self`; no new parent object is created.
- Replacing a member frees the existing JSON pair and its owned value.
- Passing `nil` as a `TJSONValue` creates a JSON null value.
- When a `TJSONValue` instance is supplied, ownership transfers to the parent JSON object.
- Do not pass the same child instance into multiple owning JSON structures.

---

# 3. Legacy JSON Compatibility Helpers

**Unit:** `EdenDBXJsonHelper.pas`

These helpers provide a more consistent API across older Delphi JSON implementations.

## 3.1 TJSONArrayHelper

**Availability:** `CompilerVersion < 28`

### Signatures

```delphi
function Count: Integer;

property Items[
  const Index: Integer
]: TJSONValue;
```

### Description

Provides array-count and indexed-access functionality for older JSON implementations.

| Member | Description |
|---|---|
| `Count` | Returns the number of array elements |
| `Items[Index]` | Returns the element at the specified zero-based index |

### Remarks

The helper is conditionally compiled only for older Delphi versions.

## 3.2 TJSONObjectHelper Legacy Members

**Availability:** `CompilerVersion < 28`

### Signatures

```delphi
function Count: Integer;

property Pairs[
  AIndex: Integer
]: TJSONPair;
```

### Description

Provides additional compatibility members for accessing JSON object pairs.

## 3.3 TJSONAncestorHelper

### Signature

```delphi
function ToJson: string;
```

### Description

Serializes a JSON object or array into JSON text.

### Example

```delphi
var
  LObject: TJSONObject;
  LText: string;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('Name', 'Alice');

    LText := LObject.ToJson;
  finally
    LObject.Free;
  end;
end;
```

### Remarks

The implementation serializes the JSON structure into bytes and converts the result into a Delphi string.

Behavior should be verified for non-ASCII content when used across different Delphi versions.

## 3.4 TJSONNumberHelper

### Signature

```delphi
function AsInt64: Int64;
```

### Description

Converts a `TJSONNumber` into a Delphi `Int64`.

Internally uses `StrToInt64` on the number's textual representation.

### Remarks

- Intended for integer-formatted JSON numbers.
- Decimal or scientific representations may not be accepted.
- Invalid or out-of-range values can raise conversion exceptions.

---

# 4. TDBXJSONToolsHelper

**Unit:** `EdenDBXJsonHelper.pas`

**Extends:** `TDBXJSONTools`

Provides database serialization and conversion methods for `TDBXReader`, `TDataSet`, and DataSnap-compatible JSON structures.

## 4.1 API Summary

| Method | Input | Output | Format |
|---|---|---|---|
| `TableToJSONArray` | `TDBXReader` | `TJSONArray` | Row-oriented |
| `TableRecToJSONObj` | `TDBXReader` | `TJSONObject` | Single record |
| `DataSetToJSONArray` | `TDataSet` | `TJSONArray` | Row-oriented |
| `DataSetRecToJSONObj` | `TDataSet` | `TJSONObject` | Current record |
| `TableToJSONB` | `TDBXReader` | `TJSONObject` | Table Block |
| `DataSetToDJSON` | `TDataSet` | `TJSONObject` | Table Block |
| `DJsonToDataSet` | `TJSONObject` | `TDataSet` | Reverse Table Block |
| `TableToJSONWriter` | `TDBXReader` | Writer output | Streaming |
| `TableToJSONText` | `TDBXReader` | `string` | Row-oriented JSON text |
| `FetchParamToDBXParameter` | `TParam` | `TDBXParameter` | Parameter mapping |

## 4.2 Common Parameters

### RowCount

```delphi
const RowCount: Integer = -1
```

Specifies the maximum number of records to serialize.

| Value | Meaning |
|---|---|
| `-1` | All remaining records |
| Positive integer | Maximum number of records |
| `0` | No records included in the output |

### RecNo

```delphi
const RecNo: Integer = 1
```

Specifies the starting record position.

The first record is numbered `1`.

For example:

```delphi
JsonArray := TDBXJSONTools.DataSetToJSONArray(
  DataSet,
  10,
  21
);
```

This requests up to 10 records starting from record 21.

### IsLocalConnection

```delphi
const IsLocalConnection: Boolean = True
```

Controls whether the conversion method closes and frees the supplied `TDBXReader`.

| Value | Behavior |
|---|---|
| `True` | Reader is closed and freed by the conversion method |
| `False` | Reader is closed but not freed by the conversion method |

**Important:** `False` does not guarantee that the reader remains open or that its position is preserved.

The caller remains responsible for releasing the reader when necessary.

---

## 4.3 TableToJSONArray

### Signature

```delphi
class function TableToJSONArray(
  const Value: TDBXReader;
  const RowCount: Integer = -1;
  const IsLocalConnection: Boolean = True;
  const RecNo: Integer = 1
): TJSONArray;
```

### Description

Converts records from a `TDBXReader` into a JSON array.

Each record becomes a `TJSONObject`.

### Parameters

| Parameter | Description |
|---|---|
| `Value` | Source `TDBXReader` |
| `RowCount` | Maximum number of records |
| `IsLocalConnection` | Controls reader cleanup |
| `RecNo` | Starting record position |

### Returns

A newly created `TJSONArray`.

If `Value` is `nil`, returns an empty array.

### Example

```delphi
var
  LArray: TJSONArray;
begin
  LArray := TDBXJSONTools.TableToJSONArray(
    Reader,
    100,
    False,
    1
  );

  try
    Writeln(LArray.ToJson);
  finally
    LArray.Free;
  end;
end;
```

### Remarks

- Builds the complete JSON DOM in memory.
- Supports data-type conversion through internal DBX conversion routines.
- Blob and binary conversion follows the library's JSON representation rules.
- The returned array belongs to the caller.

---

## 4.4 TableRecToJSONObj

### Signature

```delphi
class function TableRecToJSONObj(
  const Value: TDBXReader;
  const RecNo: Integer = 1;
  const IsLocalConnection: Boolean = True
): TJSONObject;
```

### Description

Converts the selected record of a `TDBXReader` into a `TJSONObject`.

### Returns

A newly created `TJSONObject`.

If the reader is `nil`, returns an empty JSON object.

### Example

```delphi
var
  LObject: TJSONObject;
begin
  LObject := TDBXJSONTools.TableRecToJSONObj(
    Reader,
    1,
    False
  );

  try
    Writeln(LObject.ToJson);
  finally
    LObject.Free;
  end;
end;
```

### Remarks

- Calls `Reset` on the source reader before traversal.
- The reader must support the required reset behavior.
- Closes the reader after processing.
- Returns an empty object when no matching record is found.

---

## 4.5 DataSetToJSONArray

### Signature

```delphi
class function DataSetToJSONArray(
  ADataSet: TDataSet;
  const RowCount: Integer = -1;
  const RecNo: Integer = 1
): TJSONArray;
```

### Description

Converts a `TDataSet` into a row-oriented JSON array.

Internally creates a `TDBXDataSetReader` to access the dataset.

### Returns

A newly created `TJSONArray`.

Returns an empty array if the dataset is `nil` or empty.

### Example

```delphi
var
  LArray: TJSONArray;
begin
  LArray := TDBXJSONTools.DataSetToJSONArray(DataSet);
  try
    Writeln(LArray.ToJson);
  finally
    LArray.Free;
  end;
end;
```

### Remarks

- The original `TDataSet` is not freed.
- The internal `TDBXDataSetReader` is released after conversion.
- The result contains values but no database field metadata.
- For large result sets, JSON DOM allocation may consume significant memory.

---

## 4.6 DataSetRecToJSONObj

### Signature

```delphi
class function DataSetRecToJSONObj(
  ADataSet: TDataSet
): TJSONObject;
```

### Description

Converts the current logical record of a `TDataSet` into a JSON object.

### Example

```delphi
var
  LObject: TJSONObject;
begin
  DataSet.First;

  LObject := TDBXJSONTools.DataSetRecToJSONObj(DataSet);
  try
    Writeln(LObject.ToJson);
  finally
    LObject.Free;
  end;
end;
```

### Remarks

- Uses `ADataSet.RecNo` to identify the record.
- Falls back to record number 1 if `RecNo < 1`.
- Internally traverses a `TDBXDataSetReader` to the selected record.
- Returns an empty object when the dataset is `nil` or empty.
- Actual positioning behavior depends on the dataset implementation.

---

## 4.7 TableToJSONB

### Signature

```delphi
class function TableToJSONB(
  const Value: TDBXReader;
  const RowCount: Integer = -1;
  const IsLocalConnection: Boolean = True;
  const RecNo: Integer = 1
): TJSONObject;
```

### Description

Converts a `TDBXReader` into DataSnap Table Block JSON.

Unlike row-oriented serialization, Table Block JSON contains:

1. Field metadata
2. Column-oriented data arrays

### Structure

```text
{
  "table": [
    ["ID", Type, SubType, Precision, Size, ...],
    ["Name", Type, SubType, Precision, Size, ...]
  ],
  "ID": [1, 2],
  "Name": ["Alice", "Bob"]
}
```

The metadata values above are placeholders illustrating the structure.

### Returns

A newly created `TJSONObject`.

### Remarks

- Field metadata is generated from the reader's `TDBXValueType`.
- Column values are stored in arrays associated with field names.
- Metadata and column arrays are initialized when the first record is processed.
- A reader containing no records does not produce a complete field schema.
- The method closes the reader and optionally frees it.

---

## 4.8 DataSetToDJSON

### Signature

```delphi
class function DataSetToDJSON(
  ADataSet: TDataSet;
  const RowCount: Integer = -1;
  const RecNo: Integer = 1
): TJSONObject;
```

### Description

Converts a `TDataSet` into DataSnap Table Block JSON.

Internally uses `TDBXDataSetReader` and `TableToJSONB`.

### Example

```delphi
var
  LObject: TJSONObject;
begin
  LObject := TDBXJSONTools.DataSetToDJSON(DataSet);

  try
    Writeln(LObject.ToJson);
  finally
    LObject.Free;
  end;
end;
```

### Remarks

- The result is a `TJSONObject`.
- Field metadata and column values are included for non-empty datasets.
- If the dataset is `nil` or empty, the method returns an empty JSON object.
- An empty dataset's field definitions are not preserved by this method.

---

## 4.9 DJsonToDataSet

### Signature

```delphi
class procedure DJsonToDataSet(
  AJsonObj: TJSONObject;
  ADataSet: TDataSet
);
```

### Description

Reconstructs a compatible in-memory dataset from DataSnap Table Block JSON.

Unlike the forward conversion methods, this procedure modifies the supplied `TDataSet`.

### Parameters

| Parameter | Description |
|---|---|
| `AJsonObj` | DataSnap Table Block JSON containing metadata and column arrays |
| `ADataSet` | Target dataset to reconstruct and populate |

### Processing Steps

1. Retrieves the `table` metadata array.
2. Reads field names, DBX types, subtypes, and selected size information.
3. Maps supported DBX types to Delphi field types.
4. Closes the target dataset.
5. Clears existing field definitions.
6. Rebuilds field definitions.
7. Attempts to invoke parameterless `CreateDataSet` through RTTI.
8. Reads column-oriented values.
9. Appends records to the dataset.
10. Positions the dataset at the first record.

### Example

```delphi
var
  LDataSet: TClientDataSet;
begin
  // JsonObj contains valid DataSnap Table Block JSON.

  LDataSet := TClientDataSet.Create(nil);
  try
    TDBXJSONTools.DJsonToDataSet(
      JsonObj,
      LDataSet
    );

    if LDataSet.Active and not LDataSet.IsEmpty then
    begin
      LDataSet.First;

      while not LDataSet.Eof do
      begin
        Writeln(
          LDataSet.FieldByName('Name').AsString
        );

        LDataSet.Next;
      end;
    end;

  finally
    LDataSet.Free;
  end;
end;
```

### Supported Target Datasets

The procedure is intended primarily for:

- `TClientDataSet`
- `TFDMemTable`

A target dataset must support:

- Field definition creation
- A publicly accessible parameterless `CreateDataSet`
- Record insertion
- Assignment to its field values

### Important Restrictions

- General row-oriented JSON arrays are not supported.
- The method expects DataSnap Table Block JSON.
- Invalid or missing input causes the procedure to return without modification.
- A valid `table` member causes the target dataset to be closed and rebuilt.
- Not every `TDataSet` descendant supports reconstruction.
- The procedure does not guarantee lossless schema restoration.
- Metadata properties such as precision and nullability are not fully restored.
- Memo and binary field mappings have known limitations.
- `ftBytes` and `ftVarBytes` restoration is incomplete.
- Some date/time field representations are not fully handled.
- Exceptions can leave the destination dataset partially populated.
- No automatic rollback is performed.
- The procedure does not update the original database.

For conversion details, see [DATA_CONVERSION.md](DATA_CONVERSION.md).

---

## 4.10 TableToJSONWriter

**Availability:** Delphi XE8 and later.

### Signature

```delphi
class procedure TableToJSONWriter(
  const AReader: TDBXReader;
  const AWriter: TJsonTextWriter;
  const ARowCount: Integer = -1
);
```

### Description

Serializes a `TDBXReader` directly into a `TJsonTextWriter`.

The method processes records sequentially without creating a complete JSON DOM.

### Parameters

| Parameter | Description |
|---|---|
| `AReader` | Source reader |
| `AWriter` | Destination JSON writer |
| `ARowCount` | Maximum number of records |

### Output

A row-oriented JSON array.

### Example

```delphi
var
  LJsonWriter: TJsonTextWriter;
  LTextWriter: TStreamWriter;
begin
  LTextWriter := TStreamWriter.Create(
    'output.json',
    False,
    TEncoding.UTF8
  );

  try
    LJsonWriter := TJsonTextWriter.Create(LTextWriter);
    try
      LJsonWriter.Formatting := TJsonFormatting.None;

      TDBXJSONTools.TableToJSONWriter(
        Reader,
        LJsonWriter
      );

    finally
      LJsonWriter.Free;
    end;

  finally
    LTextWriter.Free;
  end;
end;
```

### Remarks

- Uses forward-only record processing.
- Does not create a `TJSONArray` or `TJSONObject` for each record.
- The caller owns the reader and writer.
- A `nil` reader produces an empty JSON array.
- Binary values may still require temporary memory buffers.
- The writer's underlying output destination determines whether the complete output is retained in memory.

For additional examples, see [STREAMING.md](STREAMING.md).

---

## 4.11 TableToJSONText

**Availability:** Delphi XE8 and later.

### Signature

```delphi
class function TableToJSONText(
  const AReader: TDBXReader;
  const ARowCount: Integer = -1
): string;
```

### Description

Converts a `TDBXReader` directly into a JSON string.

Internally uses `TableToJSONWriter` with a `TStringWriter` and `TStringBuilder`.

### Example

```delphi
var
  LJsonText: string;
begin
  LJsonText := TDBXJSONTools.TableToJSONText(
    Reader
  );
end;
```

### Returns

- A complete JSON array string.
- `'[]'` when `AReader` is `nil`.

### Remarks

- Does not construct a complete JSON DOM.
- The final string is retained in memory.
- Suitable when the caller requires a JSON string result.
- Direct streaming is preferable when the output is very large.
- The caller retains ownership of the reader.

---

## 4.12 FetchParamToDBXParameter

### Signature

```delphi
class procedure FetchParamToDBXParameter(
  AParam: TParam;
  ADBXParameter: TDBXParameter
);
```

### Description

Copies a supported `TParam` value into a `TDBXParameter`.

### Parameters

| Parameter | Description |
|---|---|
| `AParam` | Source Delphi database parameter |
| `ADBXParameter` | Destination DBX parameter |

### Supported Field Types

| Source Field Type | DBX Type |
|---|---|
| `ftString` | `AnsiStringType` |
| `ftWideString` | `WideStringType` |
| `ftInteger`, `ftWord` | `Int32Type` |
| `ftLargeint` | `Int64Type` |
| `ftFloat` | `DoubleType` |
| `ftCurrency` | `CurrencyType` |
| `ftBCD` | `BcdType` |
| `ftBoolean` | `BooleanType` |
| `ftDate` | `DateType` |
| `ftTime` | `TimeType` |
| `ftDateTime` | `DateTimeType` |
| `ftTimeStamp` | `TimeStampType` |
| `ftBlob` | `BinaryBlobType` |
| `ftMemo`, `ftWideMemo` | `WideStringType` |

### Remarks

- Unsupported field types raise `TDBXError`.
- The method updates the destination parameter.
- The implementation is intended as a basic mapping utility.
- Not every Delphi field type or DBX parameter attribute is supported.

---

# 5. TEdenBase64

**Unit:** `EdenDBXJsonHelper.pas`

**Class:** `TEdenBase64`

Provides binary-to-Base64 and Base64-to-binary conversion methods using Windows CryptoAPI.

## 5.1 EncodeStream

### Signature

```delphi
class function EncodeStream(
  const AStream: TStream
): string; static;
```

### Description

Encodes the contents of a stream as a Base64 string.

### Returns

- Base64-encoded text.
- An empty string for a `nil` or empty stream.

### Example

```delphi
var
  LStream: TMemoryStream;
  LEncoded: string;
begin
  LStream := TMemoryStream.Create;
  try
    // Populate LStream with binary data.

    LEncoded := TEdenBase64.EncodeStream(LStream);

  finally
    LStream.Free;
  end;
end;
```

### Remarks

- Reads the stream from position zero.
- Does not free the supplied stream.
- Uses Windows `CryptBinaryToStringW`.
- Reads the entire input into memory before encoding.
- Includes compatibility handling for Windows XP.

## 5.2 DecodeToStream

### Signature

```delphi
class function DecodeToStream(
  const ABase64Str: string;
  const AOutStream: TStream
): Boolean; static;
```

### Description

Decodes Base64 text and writes the resulting bytes into a destination stream.

### Returns

- `True` when decoding succeeds.
- `False` when the input is empty or decoding fails through the Windows API.

### Example

```delphi
var
  LStream: TMemoryStream;
  LSuccess: Boolean;
begin
  LStream := TMemoryStream.Create;
  try
    LSuccess := TEdenBase64.DecodeToStream(
      'SGVsbG8=',
      LStream
    );

    if LSuccess then
      Writeln('Decoded successfully');

  finally
    LStream.Free;
  end;
end;
```

### Remarks

- Does not create or free the destination stream.
- Writes to the supplied stream rather than automatically clearing it.
- Resets the stream position to zero after successful decoding.
- A writable destination stream is required.
- The implementation uses Windows `CryptStringToBinaryW`.

## 5.3 EncodeCleanStream

### Signature

```delphi
class function EncodeCleanStream(
  const ARawStream: TStream
): string; static;
```

### Description

Attempts to locate the beginning of recognized file content before performing Base64 encoding.

The implementation scans the first 512 bytes for selected file signatures.

### Recognized Signatures

| File Format | Signature |
|---|---|
| BMP | `42 4D` |
| JPEG | `FF D8` |
| PNG | `89 50 4E 47` |
| GIF | `47 49 46 38` |
| PDF | `25 50 44 46 2D` |
| ZIP | `50 4B 03 04` |

### Behavior

1. Reads the beginning of the input stream.
2. Searches for a recognized signature.
3. Uses the detected signature position as the beginning of the data.
4. Encodes the remaining bytes as Base64.

If no signature is found, encoding begins at offset zero.

### Important Warning

This method may discard valid binary data preceding a detected signature.

It is not a general-purpose lossless Base64 encoder.

For arbitrary binary content, use `EncodeStream`.

---

# 6. TDBXMSSQLFactory

**Unit:** `DBExpress.MSSQL.Factory.pas`

**Class:** `TDBXMSSQLFactory`

Provides helper operations for connecting to and interacting with SQL Server through dbExpress.

## 6.1 Constructors

### Signatures

```delphi
constructor Create(
  const AHostName: string;
  const ADatabase: string;
  const AUserName: string;
  const APassword: string;
  const OSAuthentication: Boolean = False
); overload;

constructor Create(
  const AParams: TStrings
); overload;
```

### Description

Creates a factory instance using either explicit connection settings or an existing collection of DBX connection properties.

### Example

```delphi
var
  LFactory: TDBXMSSQLFactory;
begin
  LFactory := TDBXMSSQLFactory.Create(
    'localhost',
    'SampleDB',
    'User',
    'Password'
  );

  try
    // Perform database operations.
  finally
    LFactory.Free;
  end;
end;
```

### Remarks

- The connection is initialized lazily through `GetConnection`.
- Connection properties are managed by the factory.
- The factory releases its managed connection during destruction.

## 6.2 GetConnection

### Signature

```delphi
function GetConnection: TDBXConnection;
```

### Description

Returns the managed `TDBXConnection`.

If the connection has not yet been created, it is obtained through `TDBXConnectionFactory`.

### Ownership

The connection belongs to `TDBXMSSQLFactory`.

Do not independently free it while the factory is active.

## 6.3 Prepare

### Signature

```delphi
function Prepare(
  ASQL: string
): TDBXCommand;
```

### Description

Creates and prepares a DBX SQL command.

### Returns

A prepared `TDBXCommand`.

### Example

```delphi
var
  LCommand: TDBXCommand;
begin
  LCommand := Factory.Prepare(
    'SELECT * FROM Employees'
  );

  try
    // Execute the command.
  finally
    LCommand.Free;
  end;
end;
```

### Remarks

The returned command is owned by the caller.

## 6.4 PrepareMSQuery

### Signature

```delphi
function PrepareMSQuery(
  ASQL: string
): TDBXCommand;
```

### Description

Prepares a SQL command with additional SQL Server statements.

The implementation prepends:

```sql
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
```

### Remarks

- `SET NOCOUNT ON` suppresses row-count messages.
- `READ UNCOMMITTED` changes the transaction isolation behavior for the session.
- This method should be used only when those settings are appropriate.
- The caller owns the returned command.

## 6.5 Execute

### Signatures

```delphi
function Execute(
  ASQL: string
): Int64; overload;

function Execute(
  ASQL: string;
  args: OleVariant
): Int64; overload;

function Execute(
  ASQLCommand: TDBXCommand
): Int64; overload;

function Execute(
  ASQLCommand: TDBXCommand;
  args: OleVariant
): Int64; overload;
```

### Description

Executes a non-query SQL command using `ExecuteUpdate`.

### Returns

The number of affected rows reported by the DBX command.

### Example

```delphi
var
  LAffectedRows: Int64;
begin
  LAffectedRows := Factory.Execute(
    'DELETE FROM TempData WHERE ID = 100'
  );
end;
```

### Remarks

- String-based overloads create the command internally.
- Command-based overloads execute the supplied command.
- Parameterized overloads use `OleVariant` arguments.
- Actual affected-row counts depend on the executed SQL statement.

## 6.6 ExecuteQuery

### Signatures

```delphi
function ExecuteQuery(
  ASQLCommand: TDBXCommand
): TDBXReader; overload;

function ExecuteQuery(
  ASQLCommand: TDBXCommand;
  args: OleVariant
): TDBXReader; overload;
```

### Description

Executes a prepared command and returns a `TDBXReader`.

### Remarks

- The command is supplied by the caller.
- The returned reader must be managed according to the DBX ownership rules.
- A reader may depend on its originating command and connection.
- Do not prematurely destroy the originating command while the reader is still required.

## 6.7 FillParameters

### Signature

```delphi
function FillParameters(
  AParams: TDBXParameterList;
  AVariableList: TList<Variant>
): Boolean;
```

### Description

Assigns values from a list of Variants into a DBX parameter collection.

### Remarks

- Parameters are assigned in positional order.
- The caller must provide compatible values and enough list entries.
- Only supported Variant types are handled.
- In non-debug builds, exceptions may be suppressed by the current implementation.
- Callers should not rely on a meaningful Boolean result after a suppressed exception.

## 6.8 DBXGetTableList

### Signature

```delphi
function DBXGetTableList(
  const ATableType: string = ''
): TStrings;
```

### Description

Retrieves table names from the database metadata provider.

### Parameters

| Parameter | Description |
|---|---|
| `ATableType` | Optional table type filter |

Possible table categories depend on the DBX metadata implementation and may include tables, views, synonyms, and system objects.

### Returns

A newly created `TStrings` instance.

### Example

```delphi
var
  LTables: TStrings;
begin
  LTables := Factory.DBXGetTableList;
  try
    Writeln(LTables.Text);
  finally
    LTables.Free;
  end;
end;
```

### Remarks

The returned list belongs to the caller.

## 6.9 OleDBConnectionStringToDBX

### Signature

```delphi
class function OleDBConnectionStringToDBX(
  AConnection: TSQLConnection;
  AOleDBConnectionString: string
): Boolean;
```

### Description

Extracts selected connection settings from an OLE DB-style connection string and applies them to a `TSQLConnection`.

Recognized source properties include:

- `Server`
- `Data Source`
- `Database`
- `Initial Catalog`
- `uid`
- `User ID`
- `pwd`
- `Password`

### Remarks

- Modifies the supplied `TSQLConnection`.
- Applies SQL Server-specific DBX settings.
- Attempts to open the connection.
- The current implementation does not explicitly assign its Boolean return value.
- The Boolean result should not be treated as a reliable success indicator until the implementation is corrected.

---

# 7. TDBXCommandHelper

**Unit:** `DBExpress.MSSQL.Factory.pas`

**Extends:** `TDBXCommand`

## 7.1 CreateBlobParameter

### Signature

```delphi
function CreateBlobParameter: TDBXParameter;
```

### Description

Creates a DBX parameter configured for Blob data.

The method:

1. Creates a `TDBXParameter`.
2. Sets its data type to `BlobType`.
3. Enables the `ExtendedType` flag.

### Returns

A newly created `TDBXParameter`.

### Remarks

The caller must manage the returned parameter's ownership, normally by adding it to an appropriate command parameter collection.

## 7.2 ExecuteSmartQuery

### Signature

```delphi
function ExecuteSmartQuery: TDBXReader;
```

### Description

Executes the command and attempts to find a result set containing columns.

### Processing

1. Calls `ExecuteQuery`.
2. Checks the returned reader's `ColumnCount`.
3. Skips result sets with zero columns.
4. Calls `GetNextReader` until a suitable result is found or no result remains.

### Returns

A `TDBXReader` containing columns, or `nil` if no suitable reader remains.

### Remarks

- Intermediate readers with zero columns are freed.
- DBX exceptions are caught and converted into descriptive exceptions.
- SQL text may be included in error messages.
- This method does not replace general multiple-result-set processing.

---

# 8. TDBXParameterHelper

**Unit:** `DBExpress.MSSQL.Factory.pas`

**Extends:** `TDBXParameter`

Provides property-style access to common DBX parameter values.

## 8.1 Properties

### Signatures

```delphi
property AsDouble: Double
  read GetAsDouble write SetAsDouble;

property AsString: string
  read GetAsString write SetAsString;

property AsAnsiString: AnsiString
  read GetAsAnsiString write SetAsAnsiString;

property AsInt32: TInt32
  read GetAsInt32 write SetAsInt32;

property AsBoolean: Boolean
  read GetAsBoolean write SetAsBoolean;

property AsDateTime: TDateTime
  read GetAsDateTime write SetAsDateTime;
```

### Description

Each property provides typed access to the parameter's underlying `TDBXValue`.

### Write Behavior

| Property | DBX Data Type |
|---|---|
| `AsDouble` | `DoubleType` |
| `AsString` | `WideStringType` |
| `AsAnsiString` | `AnsiStringType` |
| `AsInt32` | `Int32Type` |
| `AsBoolean` | `BooleanType` |
| `AsDateTime` | `TimeStampType` |

### Example

```delphi
Param.AsString := 'Alice';
Param.AsInt32 := 100;
Param.AsBoolean := True;
Param.AsDateTime := Now;
```

### Remarks

Property setters assign the corresponding DBX data type before writing the value.

## 8.2 Clear

### Signature

```delphi
procedure Clear;
```

### Description

Sets the parameter value to Null.

### Example

```delphi
Param.Clear;
```

Internally calls:

```delphi
Value.SetNull;
```

---

# 9. TStringListHelper

**Unit:** `StringListHelperUnit.pas`

**Extends:** `TStringList`

Provides a lightweight Key/Value abstraction using objects associated with `TStringList` entries.

## 9.1 Add

### Signatures

```delphi
function Add(
  const S, Value: string
): Integer; overload;

function Add(
  const S: string;
  Value: Integer
): Integer; overload;
```

### Description

Adds a key with an associated typed value.

Internally stores values using:

- `TStringObject`
- `TIntegerObject`

### Returns

The index of the newly added entry.

### Example

```delphi
Items.Add('UserName', 'Alice');
Items.Add('UserID', 1001);
```

## 9.2 ContainsKey

### Signature

```delphi
function ContainsKey(
  const Key: string
): Boolean;
```

### Description

Checks whether a key exists in the list.

Internally uses `IndexOf`.

### Example

```delphi
if Items.ContainsKey('UserID') then
  Writeln('Key exists');
```

### Remarks

Key comparison follows the current `TStringList` configuration.

## 9.3 TryGetValue

### Signatures

```delphi
function TryGetValue(
  const Key: string;
  out Value: string
): Boolean; overload;

function TryGetValue(
  const Key: string;
  var Value: Integer
): Boolean; overload;
```

### Description

Retrieves the typed value associated with a key.

### Returns

- `True` if the key exists.
- `False` if the key does not exist.

### Example

```delphi
var
  LUserID: Integer;
begin
  if Items.TryGetValue('UserID', LUserID) then
    Writeln(IntToStr(LUserID));
end;
```

### Important Remarks

- Values must be retrieved using the correct original type.
- The current implementation does not validate the stored object's class before casting.
- Incorrect type retrieval may produce invalid results or exceptions.
- The list should own its associated objects.

### Complete Example

```delphi
var
  Items: TStringList;
  LUserName: string;
  LUserID: Integer;
begin
  Items := TStringList.Create(True);
  try
    Items.Sorted := True;

    Items.Add('UserName', 'Alice');
    Items.Add('UserID', 1001);

    if Items.TryGetValue('UserName', LUserName) then
      Writeln(LUserName);

    if Items.TryGetValue('UserID', LUserID) then
      Writeln(IntToStr(LUserID));

  finally
    Items.Free;
  end;
end;
```

---

# 10. DBXCypher Functions

**File:** `DBXCypher.pas`

This file contains standalone encryption-related functions rather than a complete Delphi unit declaration.

It uses the legacy PC1 cipher and Indy Base64 utilities.

## 10.1 EncodePC1Str

### Signature

```delphi
function EncodePC1Str(
  AKey, AOriginal: string
): string;
```

### Description

1. Converts the input string to UTF-8 bytes.
2. Encrypts each byte using `TPC1Cypher`.
3. Encodes the encrypted bytes using Base64.

### Returns

A Base64 representation of the encrypted content.

## 10.2 DecodePC1Str

### Signature

```delphi
function DecodePC1Str(
  AKey, AEncodedStr: string
): string;
```

### Description

1. Decodes the Base64 input.
2. Decrypts the bytes using `TPC1Cypher`.
3. Converts the decrypted UTF-8 bytes into a string.

## 10.3 EncodePC1StrRandom

### Signature

```delphi
function EncodePC1StrRandom(
  AKey, AOriginal: string
): string;
```

### Description

Adds a four-character randomized alphanumeric prefix before calling `EncodePC1Str`.

### Returns

A Base64-encoded encrypted string.

Returns an empty string when the original input is empty.

## 10.4 DecodePC1StrRandom

### Signature

```delphi
function DecodePC1StrRandom(
  AKey, AEncodedStr: string
): string;
```

### Description

Decrypts the input and removes the first four characters representing the randomized prefix.

### Remarks

- Returns an empty string for empty input.
- Returns an empty string if the decrypted content is shorter than four characters.
- Does not authenticate or verify the decrypted content.

## 10.5 GetRandomSalt

### Signature

```delphi
function GetRandomSalt(
  ALen: Integer
): string;
```

### Description

Generates a pseudorandom alphanumeric string of the requested length.

### Remarks

- Uses Delphi's standard `Random` function.
- Calls `Randomize` during generation.
- Is not cryptographically secure.
- Should not be used as a cryptographic key generator.

### Security Notice

PC1 is a legacy encryption algorithm.

These functions are documented for compatibility with existing applications and are not recommended for protecting modern security-sensitive data.

---

# 11. Memory and Ownership Reference

Correct object ownership is essential when combining Delphi JSON objects, database readers, and streams.

## 11.1 Ownership Summary

| API | Ownership |
|---|---|
| `DataSetToJSONArray` | Caller owns returned JSON array |
| `DataSetToDJSON` | Caller owns returned JSON object |
| `DataSetRecToJSONObj` | Caller owns returned JSON object |
| `TableToJSONArray` | Caller owns returned JSON array |
| `TableRecToJSONObj` | Caller owns returned JSON object |
| `TableToJSONB` | Caller owns returned JSON object |
| `FetchValue` | Parent JSON object retains ownership |
| `GetValueToJO` | Parent JSON object retains ownership |
| `GetValueToJA` | Parent JSON object retains ownership |
| `SetVal` | Parent JSON object owns assigned JSON value |
| `TableToJSONWriter` | Caller owns reader and writer |
| `TableToJSONText` | Caller owns reader |
| `TEdenBase64.EncodeStream` | Caller owns stream |
| `TEdenBase64.DecodeToStream` | Caller owns stream |
| `TDBXMSSQLFactory.GetConnection` | Factory owns connection |
| `TDBXMSSQLFactory.Prepare` | Caller owns returned command |
| `TDBXMSSQLFactory.DBXGetTableList` | Caller owns returned list |

For conversion methods accepting `IsLocalConnection`, ownership of the supplied reader depends on that parameter.

## 11.2 Recommended JSON Ownership Pattern

```delphi
LJson := TDBXJSONTools.DataSetToJSONArray(DataSet);
try
  // Use the generated JSON object.
finally
  LJson.Free;
end;
```

## 11.3 Avoid Double Free

Do not free child JSON objects separately when they are owned by their parent.

```delphi
LChild := LParent.GetValueToJO('User');

// Do not call LChild.Free if LParent owns it.
```

## 11.4 Reader Lifetime

When using:

```delphi
TDBXJSONTools.TableToJSONArray(Reader);
```

the default `IsLocalConnection = True` allows the conversion method to free the reader.

Do not free the same reader again.

When using:

```delphi
TDBXJSONTools.TableToJSONWriter(Reader, Writer);
```

the caller remains responsible for the reader's lifetime.

---

# 12. Error Handling

The library uses several error-handling approaches depending on the API.

| API Category | Error Behavior |
|---|---|
| `TryFetchValue` | Returns False for unsupported or invalid scalar conversions handled by the method |
| `ValueOrDefault<T>` | Returns the default for missing/null values or caught conversion exceptions |
| JSON casting helpers | May raise type-casting exceptions |
| `AsDateTime` | May raise date/time conversion exceptions |
| `AsInt64` | May raise numeric conversion exceptions |
| `DJsonToDataSet` | May raise exceptions during metadata parsing or dataset reconstruction |
| `FetchParamToDBXParameter` | Raises `TDBXError` for unsupported field types |
| `ExecuteSmartQuery` | Converts selected DBX errors into descriptive exceptions |
| Base64 methods | Return values indicate success or failure in supported cases |

### Recommended Practice

Use `TryFetchValue` or `ValueOrDefault<T>` when optional JSON values are expected.

Use explicit exception handling around database reconstruction and other operations that can fail partway through execution.

---

# 13. Known API Limitations

This reference documents the current public implementation rather than an idealized or future API.

Important limitations include:

1. `DJsonToDataSet` supports only compatible datasets with dynamic creation capabilities.
2. DataSnap Table Block reconstruction does not restore every field metadata attribute.
3. Binary restoration for `ftBytes` and `ftVarBytes` remains incomplete.
4. Empty datasets do not retain their field metadata through `DataSetToDJSON`.
5. Streaming reduces JSON DOM memory allocation but does not eliminate temporary binary buffers.
6. Some JSON conversions remain dependent on the underlying Delphi RTL implementation.
7. `EncodeCleanStream` can remove leading binary data when a recognized signature is detected.
8. `DBXCypher.pas` is a collection of legacy functions, not a standalone unit.
9. The Boolean result of `OleDBConnectionStringToDBX` is not explicitly assigned in the current source.
10. Some factory parameter-assignment error paths do not provide reliable failure reporting in non-debug builds.

Applications should verify the relevant conversion paths and field types before relying on lossless round-trip behavior.

---

# 14. Related Documentation

| Document | Description |
|---|---|
| [README.md](../README.md) | Project overview, installation, and quick start |
| [JSON_FORMATS.md](JSON_FORMATS.md) | Row-oriented JSON, DataSnap Table Block, and metadata structures |
| [DATA_CONVERSION.md](DATA_CONVERSION.md) | Database type mapping, conversion rules, and binary handling |
| [STREAMING.md](STREAMING.md) | Streaming architecture, memory behavior, and advanced examples |

---

# 15. Source Code

The complete implementation is available in the project repository.

- [EdenDBXJsonHelper.pas](../EdenDBXJsonHelper.pas)
- [DBExpress.MSSQL.Factory.pas](../DBExpress.MSSQL.Factory.pas)
- [StringListHelperUnit.pas](../StringListHelperUnit.pas)
- [DBXCypher.pas](../DBXCypher.pas)

The source code is the authoritative reference for actual method signatures and implementation details.

---

## License

This project is licensed under the [MIT License](../LICENSE).

Copyright (c) 2023 Eden5Wu.

**Author:** Eden Wu (You-Bin Wu)

**Repository:** [Eden5Wu/HelperClass](https://github.com/Eden5Wu/HelperClass)
