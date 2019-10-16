uses
  DBXEncryption, DBXPlatform, IdCoder, IdCoderMIME;


function EncodePC1Str(AKey, AOriginal: string): string;
var
  LBytes: TBytes;
  LBytePos: Integer;
begin
  LBytes := TEncoding.UTF8.GetBytes(AOriginal);
  with TPC1Cypher.Create(AKey) do
  begin
    for LBytePos := 0 to Length(LBytes)-1 do
      LBytes[LBytePos] := Cypher(LBytes[LBytePos]);
    Result := TIdEncoderMIME.EncodeBytes(LBytes);
    Free;
  end;
end;

function DecodePC1Str(AKey, AEncodedStr: string): string;
var
  LBytes: TBytes;
  LBytePos: Integer;
begin
  LBytes := TIdDecoderMIME.DecodeBytes(AEncodedStr);
  with TPC1Cypher.Create(AKey) do
  begin
    for LBytePos := 0 to Length(LBytes)-1 do
      LBytes[LBytePos] := Decypher(LBytes[LBytePos]);
    Result := TEncoding.UTF8.GetString(LBytes);
    Free;
  end;
end;