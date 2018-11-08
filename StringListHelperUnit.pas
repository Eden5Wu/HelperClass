unit StringListHelperUnit;

interface

uses
  Classes;
type
  TStringListHelper = class helper for TStringList
  public
    ///<summary>Note: TStringList.Create(True); and Sorted is True.</summary>
    function Add(const S, Value: string): Integer; overload;
    function Add(const S: string; Value: Integer): Integer; overload;
    function ContainsKey(const Key: string): Boolean;
    function TryGetValue(const Key: string; out Value: string): Boolean; overload;
    function TryGetValue(const Key: string; var Value: Integer): Boolean; overload;
  end;

implementation

type
  TStringObject = class(TObject)
  public
    Value: String;
    constructor Create(const AValue: String);
  end;

  TIntegerObject = class(TObject)
  public
    Value: Integer;
    constructor Create(const AValue: Integer);
  end;

{ TStringListHelper }

function TStringListHelper.Add(const S, Value: string): Integer;
begin
  Result := AddObject(S, TStringObject.Create(Value));
end;

function TStringListHelper.Add(const S: string; Value: Integer): Integer;
begin
  Result := AddObject(S, TIntegerObject.Create(Value));
end;

function TStringListHelper.ContainsKey(const Key: string): Boolean;
begin
  Result := (Self.IndexOf(Key) > -1);
end;

function TStringListHelper.TryGetValue(const Key: string;
  var Value: Integer): Boolean;
var
  LIndex: Integer;
begin
  LIndex := Self.IndexOf(Key);
  Result := (LIndex > -1);
  if Result then
    Value := TIntegerObject(Self.Objects[LIndex]).Value;
end;

function TStringListHelper.TryGetValue(const Key: string;
  out Value: string): Boolean;
var
  LIndex: Integer;
begin
  LIndex := Self.IndexOf(Key);
  Result := (LIndex > -1);
  if Result then
    Value := TStringObject(Self.Objects[LIndex]).Value;
end;

{ TIntegerObject }

constructor TIntegerObject.Create(const AValue: Integer);
begin
  Value := AValue;
end;

{ TStringObject }

constructor TStringObject.Create(const AValue: String);
begin
  Value := AValue;
end;

end.
