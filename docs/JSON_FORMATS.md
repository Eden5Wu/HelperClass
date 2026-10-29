# JSON Formats

[Back to README](../README.md) | [API Reference](API_REFERENCE.md)

## Overview

`EdenDBXJsonHelper.pas` supports two primary JSON serialization formats:

1. **Row-oriented JSON** — Designed for REST APIs, JavaScript, and general data exchange.
2. **DataSnap Table Block JSON** — Preserves database field metadata and column-oriented data.

Both formats are generated from `TDataSet` or `TDBXReader`.

---

## 1. Row-Oriented JSON

Each database record is represented as a JSON object within an array.

### Example

```json
[
  {
    "ID": 1,
    "Name": "Alice",
    "Active": true
  },
  {
    "ID": 2,
    "Name": "Bob",
    "Active": false
  }
]
```

### Supported Methods

| Method | Source | Output |
|---|---|---|
| `DataSetToJSONArray` | `TDataSet` | `TJSONArray` |
| `TableToJSONArray` | `TDBXReader` | `TJSONArray` |
| `DataSetRecToJSONObj` | `TDataSet` | `TJSONObject` |
| `TableRecToJSONObj` | `TDBXReader` | `TJSONObject` |
| `TableToJSONWriter` | `TDBXReader` | Streaming JSON |
| `TableToJSONText` | `TDBXReader` | JSON string |

`TableToJSONWriter` and `TableToJSONText` require Delphi XE8 or later.

### Example

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

### Characteristics

- Simple and widely supported.
- Suitable for JavaScript and REST APIs.
- Field names are repeated for each record.
- Database metadata is not preserved.
- Does not support automatic DataSet reconstruction through `DJsonToDataSet`.

---

## 2. DataSnap Table Block JSON

DataSnap Table Block JSON stores database metadata and data values separately.

Instead of organizing values by record, it organizes them by column.

### Structure

```text
{
  "table": [
    ["ID",   DataType, SubType, Precision, Size, ...],
    ["Name", DataType, SubType, Precision, Size, ...]
  ],
  "ID": [1, 2],
  "Name": ["Alice", "Bob"]
}
```

The metadata values shown above are symbolic placeholders, not literal JSON values.

Actual metadata entries are generated using `TDBXJSONTools.ValueTypeToJSON`.

### Supported Methods

| Method | Operation |
|---|---|
| `DataSetToDJSON` | DataSet → Table Block |
| `TableToJSONB` | DBXReader → Table Block |
| `DJsonToDataSet` | Table Block → DataSet |

### Metadata

The `table` property contains an array of field definitions.

The current `DJsonToDataSet` implementation reads these positions:

| Index | Description |
|---|---|
| `0` | Field name |
| `1` | DBX data type |
| `2` | DBX subtype |
| `3` | Precision |
| `4` | Field size |

Additional metadata attributes may be present.

Only a subset of metadata properties is currently applied when rebuilding a DataSet.

### Example

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

### Characteristics

- Preserves field metadata in the serialized output.
- Uses column-oriented arrays.
- Supports reconstruction of compatible in-memory datasets.
- Suitable for DataSnap interoperability.
- More specialized than standard row-oriented JSON.

---

## 3. Data Type Representation

The library converts Delphi DBX values into JSON-compatible types.

| DBX Type | JSON Representation |
|---|---|
| Integer types | Number |
| Floating-point types | Number |
| Boolean | `true` / `false` |
| String | String |
| Date | `"yyyy-MM-dd"` |
| DateTime / TimeStamp | XML/ISO-style date-time string |
| Null | `null` |
| Blob / BinaryBlob | Base64 string |
| Memo / WideMemo | String |

### Binary Data

The representation of `BytesType` depends on the serialization method.

| Format | BytesType Representation |
|---|---|
| Row-oriented JSON | Base64 string |
| DataSnap Table Block | JSON byte array |
| Streaming JSON | JSON byte array |

Base64 example:

```json
{
  "BinaryData": "SGVsbG8="
}
```

Byte array example:

```json
{
  "BinaryData": [72, 101, 108, 108, 111]
}
```

This distinction is particularly relevant when exchanging SQL Server `binary`, `varbinary`, or `rowversion` values.

---

## 4. Null and Date Handling

### Null Values

Database Null values are represented as JSON `null`.

```json
{
  "ID": 1,
  "Name": null
}
```

Null is different from an empty string, zero, or false.

### Date and DateTime

Example representations:

```json
{
  "BirthDate": "1980-04-22",
  "CreatedAt": "2026-10-29T09:30:00"
}
```

- Date values use `yyyy-MM-dd`.
- DateTime and TimeStamp values use `DateTimeToXMLTime`.
- Reverse conversion uses the library's `AsDateTime` implementation.

Timezone interpretation follows the underlying Delphi date/time conversion functions.

---

## 5. Format Comparison

| Feature | Row-Oriented | Table Block |
|---|---|---|
| Standard JSON | Yes | Yes |
| JavaScript-friendly | Yes | Requires format-specific handling |
| Field metadata | No | Yes |
| Data organization | By record | By column |
| REST API usage | Recommended | Supported |
| DataSnap interoperability | Limited | Primary use case |
| DataSet reconstruction | Not provided | Supported with limitations |
| Streaming output | Available | Not implemented |

### Recommended Usage

**Choose Row-oriented JSON when:**

- Building REST APIs.
- Sending data to JavaScript applications.
- Working with DataGrid components.
- Database metadata is unnecessary.

**Choose DataSnap Table Block when:**

- Preserving database field metadata is important.
- Integrating with existing DataSnap systems.
- Reconstructing compatible Delphi in-memory datasets.

---

## 6. Reverse Conversion

`DJsonToDataSet` reconstructs a DataSet from DataSnap Table Block JSON.

```delphi
TDBXJSONTools.DJsonToDataSet(JsonObj, ClientDataSet);
```

The procedure:

1. Reads the `table` metadata.
2. Creates field definitions.
3. Attempts to create the target dataset.
4. Reads column-oriented values.
5. Inserts records into the dataset.

### Limitations

- Requires a compatible dataset supporting dynamic creation.
- Primarily intended for `TClientDataSet` and `TFDMemTable`.
- Does not accept row-oriented JSON arrays.
- Does not restore every metadata attribute.
- Binary field reconstruction, particularly `ftBytes` and `ftVarBytes`, is incomplete.
- Some date/time and Memo field types require additional handling.
- Lossless round-trip conversion is not guaranteed.

For details, see [DATA_CONVERSION.md](DATA_CONVERSION.md).

---

## 7. Empty Datasets

The current implementation handles empty results differently depending on the method.

| Method | Empty Input Result |
|---|---|
| `DataSetToJSONArray` | `[]` |
| `DataSetToDJSON` | `{}` |
| `TableToJSONArray` | `[]` for a nil or empty reader |
| `TableToJSONB` | `{"table":[]}` for a non-nil reader with no records |

For an empty DataSet, `DataSetToDJSON` does not preserve field metadata.

Consequently, metadata-only reconstruction of empty datasets is not currently supported.

---

## 8. Related Documentation

- [API_REFERENCE.md](API_REFERENCE.md) — Public API definitions.
- [DATA_CONVERSION.md](DATA_CONVERSION.md) — Type mapping and reverse conversion.
- [STREAMING.md](STREAMING.md) — Forward-only JSON serialization.

**Source:** [EdenDBXJsonHelper.pas](../EdenDBXJsonHelper.pas)
