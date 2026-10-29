# Data Conversion

[Back to README](../README.md) | [API Reference](API_REFERENCE.md) | [JSON Formats](JSON_FORMATS.md)

## Overview

`EdenDBXJsonHelper.pas` provides conversion between Delphi database components and JSON.

Supported operations include:

- `TDataSet` → JSON
- `TDBXReader` → JSON
- DataSnap Table Block JSON → `TDataSet`
- Database field types → JSON-compatible values
- Blob, Bytes, and DateTime serialization

The implementation uses Delphi's existing dbExpress and JSON APIs.

---

## 1. Conversion Methods

| Method | Source | Output |
|---|---|---|
| `DataSetToJSONArray` | `TDataSet` | Row-oriented JSON |
| `TableToJSONArray` | `TDBXReader` | Row-oriented JSON |
| `DataSetRecToJSONObj` | Current DataSet record | JSON Object |
| `TableRecToJSONObj` | Selected Reader record | JSON Object |
| `DataSetToDJSON` | `TDataSet` | DataSnap Table Block |
| `TableToJSONB` | `TDBXReader` | DataSnap Table Block |
| `DJsonToDataSet` | DataSnap Table Block | In-memory DataSet |
| `TableToJSONWriter` | `TDBXReader` | Streaming JSON |
| `TableToJSONText` | `TDBXReader` | JSON string |

Streaming methods require Delphi XE8 or later.

---

## 2. Forward Conversion

### 2.1 DataSet to JSON Array

```delphi
var
  JsonArray: TJSONArray;
begin
  JsonArray := TDBXJSONTools.DataSetToJSONArray(DataSet);
  try
    Writeln(JsonArray.ToJson);
  finally
    JsonArray.Free;
  end;
end;
```

Example output:

```json
[
  {"ID": 1, "Name": "Alice"},
  {"ID": 2, "Name": "Bob"}
]
```

### 2.2 DataSet to DataSnap Table Block

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

The Table Block format contains field metadata and column-oriented values.

See [JSON_FORMATS.md](JSON_FORMATS.md) for its structure.

---

## 3. DBX to JSON Type Mapping

The forward conversion methods translate DBX data types into JSON values.

| DBX Data Type | JSON Type |
|---|---|
| `Int8Type`, `Int16Type`, `Int32Type` | Number |
| `UInt8Type`, `UInt16Type`, `UInt32Type` | Number |
| `Int64Type`, `UInt64Type` | Number |
| `SingleType`, `DoubleType` | Number |
| `CurrencyType`, `BcdType` | Number |
| `BooleanType` | Boolean |
| `AnsiStringType`, `WideStringType` | String |
| `DateType` | String (`yyyy-MM-dd`) |
| `TimeType` | String |
| `DatetimeType`, `TimeStampType` | XML/ISO-style date-time string |
| `BlobType`, `BinaryBlobType` | Base64 string |
| `BytesType` | Base64 string or byte array |
| `JsonValueType` | JSON value |
| `TableType` | Nested JSON structure |
| Null values | `null` |

### Important Details

- Most numeric types are serialized using `TJSONNumber`.
- Some integer and fixed-point types pass through `Double`, potentially affecting precision.
- `Int64Type` uses `AsInt64`.
- Date values use `FormatDateTime`.
- DateTime values use `DateTimeToXMLTime`.
- Unsupported DBX types may raise `TDBXError`.

---

## 4. Binary Data Conversion

JSON does not provide a native binary type.

The library supports two representations.

### 4.1 Base64

Used for Blob data and `BytesType` in row-oriented conversion.

```json
{
  "Document": "SGVsbG8="
}
```

### 4.2 Byte Array

Used for `BytesType` in DataSnap Table Block and streaming conversion.

```json
{
  "RowVersion": [72, 101, 108, 108, 111]
}
```

### Binary Format Comparison

| DBX Type | Row-oriented | Table Block | Streaming |
|---|---|---|---|
| `BlobType` | Base64 | Base64 | Base64 |
| `BinaryBlobType` | Base64 | Base64 | Base64 |
| `BytesType` | Base64 | Byte array | Byte array |
| Memo subtypes | String | String | String |

Blob encoding uses `TEdenBase64.EncodeCleanStream`.

**Warning:** This method may remove leading bytes when a recognized file signature is detected. It is not suitable for arbitrary lossless binary encoding.

---

## 5. Reverse Conversion

`DJsonToDataSet` reconstructs a supported in-memory DataSet from DataSnap Table Block JSON.

### Signature

```delphi
class procedure DJsonToDataSet(
  AJsonObj: TJSONObject;
  ADataSet: TDataSet
);
```

### Example

```delphi
var
  DataSet: TClientDataSet;
begin
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

### Processing Steps

1. Read the `table` metadata.
2. Extract field names, types, subtypes, and sizes.
3. Create Delphi field definitions.
4. Invoke `CreateDataSet` through RTTI.
5. Read column-oriented JSON arrays.
6. Insert records into the target DataSet.

### Requirements

The target DataSet must support:

- Dynamic field definitions
- Parameterless `CreateDataSet`
- Record insertion

The intended target components are `TClientDataSet` and `TFDMemTable`.

Not every `TDataSet` descendant supports these operations.

---

## 6. DBX to TFieldType Mapping

During reverse conversion, DBX metadata is mapped to Delphi field types.

| DBX Data Type | Delphi TFieldType |
|---|---|
| `Int8Type`, `Int16Type`, `Int32Type` | `ftInteger` |
| `UInt16Type`, `UInt32Type` | `ftInteger` |
| `Int64Type`, `UInt64Type` | `ftLargeint` |
| `SingleType`, `DoubleType` | `ftFloat` |
| `CurrencyType` | `ftCurrency` |
| `BcdType` | `ftFMTBcd` |
| `BooleanType` | `ftBoolean` |
| `AnsiStringType` | `ftString` |
| `WideStringType` | `ftWideString` |
| `DateType` | `ftDate` |
| `TimeType` | `ftTime` |
| `DatetimeType` | `ftDateTime` |
| `TimeStampType` | `ftTimeStamp` |
| `BlobType`, `BinaryBlobType` | `ftBlob` |
| Blob with Memo/WideMemo subtype | `ftWideMemo` |
| `BytesType` | `ftBytes` |
| Unsupported type | `ftUnknown` |

### Limitations

This mapping is not always lossless.

For example:

- Unsigned integer types may be mapped to signed field types.
- `UInt64Type` may exceed the range of `ftLargeint`.
- Numeric precision and scale are not fully restored.
- Metadata such as nullability is not fully applied.

---

## 7. Null and DateTime Handling

### Null Values

Database Null values are serialized as JSON `null`.

During reverse conversion, JSON null values clear the corresponding DataSet field.

```json
{
  "Name": null
}
```

### DateTime Values

Example:

```json
{
  "BirthDate": "1980-04-22",
  "CreatedAt": "2026-10-29T09:30:00"
}
```

Forward conversion uses:

- `FormatDateTime` for dates
- `DateTimeToXMLTime` for DateTime and TimeStamp values

Reverse conversion uses `AsDateTime` for supported date and time field types.

DateTime handling is not fully symmetrical for all field types, particularly `ftTimeStamp`.

---

## 8. Empty Datasets

Empty datasets require special consideration.

| Method | Result |
|---|---|
| `DataSetToJSONArray` | `[]` |
| `DataSetToDJSON` | `{}` |
| `TableToJSONArray` | `[]` |
| `TableToJSONB` | `{"table":[]}` when the reader contains no rows |

`DataSetToDJSON` does not preserve field metadata when the source DataSet is empty.

Therefore, an empty DataSet cannot currently be reconstructed with its original schema using this conversion path.

---

## 9. DataSet Ownership and State

### Forward Conversion

- The original `TDataSet` is not freed.
- Internal `TDBXDataSetReader` instances are released.
- Returned JSON objects belong to the caller.

### Reverse Conversion

`DJsonToDataSet` modifies the supplied DataSet directly.

For valid Table Block input, it:

- Closes the existing DataSet.
- Clears its field definitions.
- Rebuilds the dataset.
- Inserts the converted records.

**Existing data is replaced, not merged.**

If conversion fails, the DataSet may remain partially populated. No automatic rollback is provided.

---

## 10. Known Limitations

The current implementation has the following restrictions:

1. Reverse conversion supports DataSnap Table Block JSON only.
2. General row-oriented JSON cannot be passed directly to `DJsonToDataSet`.
3. `ftBytes` and `ftVarBytes` reconstruction is incomplete.
4. Metadata properties are not fully restored.
5. Some date/time and Memo mappings require additional handling.
6. Numerical precision may change for certain DBX types.
7. Empty DataSet schemas are not preserved by `DataSetToDJSON`.
8. Binary serialization may allocate additional memory.
9. `EncodeCleanStream` may remove leading binary content.
10. Lossless DataSet round-trip conversion is not guaranteed.

Applications requiring exact field preservation should test their actual data types and conversion paths.

---

## 11. Related Documentation

- [API_REFERENCE.md](API_REFERENCE.md) — Complete public API reference.
- [JSON_FORMATS.md](JSON_FORMATS.md) — JSON structures and metadata.
- [STREAMING.md](STREAMING.md) — Streaming JSON serialization.
- [README.md](../README.md) — Project overview.

**Source:** [EdenDBXJsonHelper.pas](../EdenDBXJsonHelper.pas)
