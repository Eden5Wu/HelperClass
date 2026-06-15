uses
  SysUtils, DBXEncryption, DBXPlatform, IdCoder, IdCoderMIME;


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

// 目的：透過前置隨機鹽值，觸發 PC1 加密演算法的雪崩反饋效應，
// 達到「相同明文每次加密，產生的密文字串皆完全不同」的隨機防護效果。
// 輔助函式：產生 4 碼隨機英數鹽值
function GetRandomSalt(ALen: Integer): string;
const
  CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  I: Integer;
begin
  Result := '';
  Randomize; // 初始化亂數產生器
  for I := 1 to ALen do
    Result := Result + CHARS[Random(Length(CHARS)) + 1];
end;

// 隨機加密：前置 4 碼隨機鹽值，再調用原有的 EncodePC1Str
function EncodePC1StrRandom(AKey, AOriginal: string): string;
var
  LSalt: string;
begin
  if AOriginal = '' then Exit('');
  LSalt := GetRandomSalt(4);
  Result := EncodePC1Str(AKey, LSalt + AOriginal);
end;

// 隨機解密：調用原有的 DecodePC1Str，再剝離前 4 碼鹽值
function DecodePC1StrRandom(AKey, AEncodedStr: string): string;
var
  LDecrypted: string;
begin
  if AEncodedStr = '' then Exit('');
  LDecrypted := DecodePC1Str(AKey, AEncodedStr);
  if Length(LDecrypted) >= 4 then
    Result := Copy(LDecrypted, 5, MaxInt)
  else
    Result := '';
end;
