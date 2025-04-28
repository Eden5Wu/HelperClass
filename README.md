[中文版 (Chinese Version)](README_ZH.md)

# EdenDBXJsonHelper.pas - Delphi JSON & Database Helpers

## What's This?

`EdenDBXJsonHelper.pas` is a Delphi (`.pas`) unit packed with Class Helpers to make your life easier when dealing with JSON and converting data between database components (like `TDataSet`, `TDBXReader`) and JSON formats in your Delphi apps.

It's built for the Embarcadero Delphi environment, using the built-in JSON libraries (`System.JSON` or the older `DBXJSON`) and database access components (DBX).

## Key Features

This unit extends standard Delphi JSON classes and DBX tools with extra, useful methods:

### JSON Helpers

* **`TJSONValueHelper`**:
    * Easy type checking (`IsJsonNumber`, `IsJsonObject`, `IsJsonNull`, etc.).
    * Safe type conversions (`AsJsonNumber`, `AsJsonObject`, `AsJsonArray`, etc.).
    * `HasJsonValue(APath: string)`: Checks if a value exists at a specific path (for objects) or index (for arrays).
    * `AsVariant`: Converts a `TJSONValue` into a matching `Variant`.
    * `AsDateTime`: Parses a JSON string (if formatted correctly) into a `TDateTime`.
* **`TJSONObjectHelper`**:
    * `WorkspaceValue(APairName: string)`: Gets a `TJSONValue` by its name (case-sensitive).
    * `TryFetchValue(APath: string; out AValue: ...)` (overloaded): Safely tries to get a value by name/path and convert it to `string`, `Int64`, `Double`, or `Boolean`. Returns `True` if successful. Super useful for avoiding exceptions!
    * `GetVariant(Name: string)`: Gets a value by name as a `Variant`.
    * `GetValueToJO(Name: string)`: Gets a nested `TJSONObject` by name.
    * `GetValueToJA(Name: string)`: Gets a nested `TJSONArray` by name.
    * (For older Delphi) Adds `Count` and `Pairs` properties for consistency.
* **`TJSONArrayHelper`** (For older Delphi):
    * Adds `Count` and `Items` properties to make the API feel the same across Delphi versions.
* **`TJSONAncestorHelper`**:
    * `ToJson`: Serializes any JSON object or array (`TJSONObject`, `TJSONArray`) into a JSON string.
* **`TJSONNumberHelper`**:
    * `AsInt64`: Converts a `TJSONNumber` to an `Int64`.

### Database <-> JSON Conversion Helpers

* **`TDBXJSONToolsHelper`**:
    * `WorkspaceParamToDBXParameter(AParam: TParam; ADBXParameter: TDBXParameter)`: Helps map `TParam` values to `TDBXParameter` (Note: You might need to tweak this based on your specific needs).
    * `TableToJSONArray(Value: TDBXReader; ...)`: Turns a `TDBXReader`'s result set into a `TJSONArray`. Each item in the array is a `TJSONObject` representing a data row. Options for max rows (`RowCount`), starting record (`RecNo`), and memory management (`IsLocalConnection`).
    * `TableRecToJSONObj(Value: TDBXReader; RecNo: Integer; ...)`: Converts a *single*, specific record (by `RecNo`) from a `TDBXReader` into a `TJSONObject`.
    * `DataSetToJSONArray(ADataSet: TDataSet; ...)`: Converts the contents of a `TDataSet` (like `TClientDataSet`, `TFDMemTable`) into a `TJSONArray`, same format as `TableToJSONArray`.
    * `DataSetToDJSON(ADataSet: TDataSet; ...)`: Converts a `TDataSet` into a `TJSONObject` using the DataSnap "Table Block" format (includes metadata and column-based data arrays).
    * `DataSetRecToJSONObj(ADataSet: TDataSet)`: Converts the *current* record of a `TDataSet` into a `TJSONObject`.
    * `TableToJSONB(Value: TDBXReader; ...)`: Converts a `TDBXReader`'s results into a `TJSONObject` using the DataSnap "Table Block" format (has a 'table' metadata array, then arrays of values for each column name).

## Getting Started

1.  **Add the Unit**: Add the `EdenDBXJsonHelper.pas` file to your Delphi project.
2.  **Use It**: Add `EdenDBXJsonHelper` to the `uses` clause of any unit where you want to use these helper functions.

```delphi
uses
  SysUtils, Classes, DB, DBXJSON, DBXCommon,
  EdenDBXJsonHelper; // Add this line

procedure ExampleUsage;
var
  JsonObj: TJSONObject;
  JsonArr: TJSONArray;
  Reader: TDBXReader;
  DataSet: TClientDataSet; // Or any TDataSet descendant
  ValueStr: string;
  ValueInt: Int64;
  Success: Boolean;
begin
  // --- JSON Helper Example ---
  JsonObj := TJSONObject.ParseJSONValue('{"name": "Test", "value": 123, "active": true, "items": [1, 2]}') as TJSONObject;
  try
    // Safely get values
    Success := JsonObj.TryFetchValue('name', ValueStr);
    if Success then
      ShowMessage('Name: ' + ValueStr); // Shows 'Name: Test'

    Success := JsonObj.TryFetchValue('value', ValueInt);
    if Success then
      ShowMessage('Value: ' + IntToStr(ValueInt)); // Shows 'Value: 123'

    // Check if a key exists
    if JsonObj.HasJsonValue('active') then
      ShowMessage('Active exists');

    // Get a nested array
    JsonArr := JsonObj.GetValueToJA('items');
    if Assigned(JsonArr) then
      ShowMessage('Items count: ' + IntToStr(JsonArr.Count)); // Shows 'Items count: 2'

    // Serialize back to string
    ShowMessage('As JSON String: ' + JsonObj.ToJson);

  finally
    JsonObj.Free;
  end;

  // --- DB to JSON Helper Example ---

  // Assume DataSet is loaded with data
  DataSet := TClientDataSet.Create(nil);
  try
    // ... (Code to load or create DataSet data)
    // Example: Add some data if empty
    DataSet.FieldDefs.Add('Field1', ftString, 20);
    DataSet.FieldDefs.Add('Field2', ftInteger);
    DataSet.CreateDataSet;
    DataSet.AppendRecord(['Row1Col1', 10]);
    DataSet.AppendRecord(['Row2Col1', 20]);

    // Convert DataSet to JSONArray (array of row objects)
    JsonArr := TDBXJSONTools.DataSetToJSONArray(DataSet);
    try
      ShowMessage('DataSet as JSONArray: ' + JsonArr.ToJson);
      // Output: [{"Field1": "Row1Col1", "Field2": 10}, {"Field1": "Row2Col1", "Field2": 20}]
    finally
      JsonArr.Free;
    end;

    // Convert current DataSet record to JSONObject
    if not DataSet.IsEmpty then
    begin
      DataSet.First; // Or navigate to a specific record
      JsonObj := TDBXJSONTools.DataSetRecToJSONObj(DataSet);
      try
        ShowMessage('Current DataSet Record as JSONObject: ' + JsonObj.ToJson);
        // Output: {"Field1": "Row1Col1", "Field2": 10} (if on the first record)
      finally
        JsonObj.Free;
      end;
    end;

    // Convert DataSet to DataSnap Table Block format (JSONObject)
    JsonObj := TDBXJSONTools.DataSetToDJSON(DataSet);
    try
      ShowMessage('DataSet as Table Block JSON: ' + JsonObj.ToJson);
      // Output looks like: {"table": [...metadata...], "Field1": ["Row1Col1", "Row2Col1"], "Field2": [10, 20]}
    finally
      JsonObj.Free;
    end;

  finally
    DataSet.Free;
  end;

  // Assume Reader comes from DataSnap or DBX
  // Reader := ... (Code to get a TDBXReader instance)
  // if Assigned(Reader) then
  // begin
  //   // Convert reader (max 10 rows)
  //   JsonArr := TDBXJSONTools.TableToJSONArray(Reader, 10);
  //   try
  //      // ... use JsonArr ...
  //   finally
  //     JsonArr.Free; // Don't forget to free it!
  //   end;
  // end;

end;
