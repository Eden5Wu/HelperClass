# Streaming JSON

[Back to README](../README.md) | [API Reference](API_REFERENCE.md) | [Data Conversion](DATA_CONVERSION.md)

## Overview

`EdenDBXJsonHelper.pas` provides forward-only JSON serialization for `TDBXReader` using Delphi's `TJsonTextWriter`.

Unlike traditional JSON DOM serialization, streaming writes records directly to the output without constructing a complete `TJSONArray`.

**Requirements:** Delphi XE8 or later.

---

## 1. Streaming vs. Traditional JSON

### Traditional JSON Serialization

```text
TDBXReader
    |
    v
TJSONArray
    |
    v
JSON String
```

The complete JSON object tree is created in memory before serialization.

### Streaming JSON Serialization

```text
TDBXReader
    |
    v
TJsonTextWriter
    |
    v
File / Stream / Output
```

Records are processed sequentially and written directly to the destination.

### Comparison

| Feature | Traditional JSON | Streaming JSON |
|---|---|---|
| JSON DOM allocation | Required | Not required |
| Record processing | Builds an object tree | Sequential |
| Memory consumption | Grows with DOM size | Depends on buffers and output destination |
| Large datasets | Higher memory overhead | Generally preferable |
| Output format | JSON Array | JSON Array |
| Random access to JSON nodes | Yes | No |

Streaming is particularly useful for large database exports and REST API responses.

---

## 2. Available Methods

### TableToJSONWriter

```delphi
class procedure TableToJSONWriter(
  const AReader: TDBXReader;
  const AWriter: TJsonTextWriter;
  const ARowCount: Integer = -1
);
```

Writes JSON directly to a `TJsonTextWriter`.

| Parameter | Description |
|---|---|
| `AReader` | Source database reader |
| `AWriter` | Destination JSON writer |
| `ARowCount` | Maximum number of records; `-1` means all remaining records |

**Output:** Row-oriented JSON Array.

### TableToJSONText

```delphi
class function TableToJSONText(
  const AReader: TDBXReader;
  const ARowCount: Integer = -1
): string;
```

Uses `TableToJSONWriter` internally and returns the complete JSON string.

This method avoids constructing a JSON DOM but still stores the final string in memory.

---

## 3. Exporting JSON to a File

```delphi
uses
  SysUtils, Classes, DBXCommon, DBXJSONCommon,
  System.JSON.Writers, System.JSON.Types,
  EdenDBXJsonHelper;

procedure ExportReaderToJSON(AReader: TDBXReader);
var
  LTextWriter: TStreamWriter;
  LJsonWriter: TJsonTextWriter;
begin
  LTextWriter := TStreamWriter.Create(
    'export.json',
    False,
    TEncoding.UTF8
  );

  try
    LJsonWriter := TJsonTextWriter.Create(LTextWriter);
    try
      LJsonWriter.Formatting := TJsonFormatting.None;

      TDBXJSONTools.TableToJSONWriter(
        AReader,
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

Example output:

```json
[
  {"ID":1,"Name":"Alice","Active":true},
  {"ID":2,"Name":"Bob","Active":false}
]
```

The complete JSON DOM is never created.

---

## 4. Returning JSON as a String

For applications requiring a JSON string:

```delphi
var
  LJsonText: string;
begin
  LJsonText := TDBXJSONTools.TableToJSONText(
    Reader
  );
end;
```

To limit the number of serialized records:

```delphi
LJsonText := TDBXJSONTools.TableToJSONText(
  Reader,
  1000
);
```

This serializes up to 1,000 records.

### When to Use Each Method

| Requirement | Recommended Method |
|---|---|
| Export large datasets to a file | `TableToJSONWriter` |
| Write JSON to an output stream | `TableToJSONWriter` |
| Return a JSON string | `TableToJSONText` |
| Manipulate JSON nodes after conversion | `TableToJSONArray` |

---

## 5. Data Type Serialization

Streaming converts DBX field values directly into JSON tokens.

| DBX Data Type | JSON Output |
|---|---|
| Integer types | Number |
| Floating-point types | Number |
| Currency / BCD | Number |
| Boolean | `true` / `false` |
| String | String |
| Date | `yyyy-MM-dd` |
| DateTime / TimeStamp | XML/ISO-style date-time string |
| Blob / BinaryBlob | Base64 string |
| Memo / WideMemo | String |
| Bytes | Numeric array |
| Null | `null` |

### Binary Example

```json
{
  "Document": "SGVsbG8=",
  "RowVersion": [72, 101, 108, 108, 111]
}
```

Blob data is encoded using `TEdenBase64.EncodeCleanStream`.

**Note:** This method may remove leading bytes when it detects certain file signatures. It is not suitable for arbitrary lossless binary serialization.

---

## 6. Memory Management

Streaming eliminates the need to allocate a complete JSON object tree.

However, the implementation is not entirely allocation-free.

### Memory Considerations

1. Records are read sequentially from `TDBXReader`.
2. JSON values are written directly to `TJsonTextWriter`.
3. Blob encoding may allocate a buffer containing the entire binary field.
4. Bytes fields are temporarily loaded into a `TBytes` array.
5. `TableToJSONText` accumulates the complete result using `TStringBuilder`.

Consequently, memory usage depends on individual field sizes and the selected output destination.

### Recommendation

Use `TableToJSONWriter` with a file-backed or other incremental output writer for large datasets.

Use `TableToJSONText` when the application explicitly requires a complete JSON string.

No performance benchmark or fixed memory reduction percentage is claimed.

---

## 7. Reader and Writer Ownership

`TableToJSONWriter` does not free the supplied reader or writer.

The caller is responsible for managing their lifetimes.

### Important Behavior

- The reader is consumed sequentially using `Next`.
- The method does not call `Reset` or restore the reader's position.
- The method does not close the reader.
- An empty or `nil` reader produces `[]`.
- The writer must be a valid `TJsonTextWriter`.

When using `ARowCount`, the method consumes records from the reader's current position.

**Note:** The current loop evaluates `AReader.Next` before checking the remaining row count. Avoid using `ARowCount = 0` when preserving reader position matters.

---

## 8. Limitations

- Requires Delphi XE8 or later.
- Accepts `TDBXReader`, not `TDataSet` directly.
- A `TDataSet` can be adapted using `TDBXDataSetReader`.
- Produces row-oriented JSON only.
- Does not include DataSnap Table Block metadata.
- Binary fields may require additional memory allocation.
- Large JSON strings still consume memory when using `TableToJSONText`.
- An exception during writing may leave the destination with incomplete JSON.
- Streaming does not automatically improve database query execution time.

---

## 9. Related Documentation

- [API_REFERENCE.md](API_REFERENCE.md) — Public API definitions.
- [JSON_FORMATS.md](JSON_FORMATS.md) — JSON structure and supported formats.
- [DATA_CONVERSION.md](DATA_CONVERSION.md) — Data type conversion and binary handling.

**Source:** [EdenDBXJsonHelper.pas](../EdenDBXJsonHelper.pas)
