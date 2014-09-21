{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V+}
UNIT CRC_All;

INTERFACE

Type
  Str2 = String[2];
  Str4 = String[4];
  Str8 = String[8];
  ByteArray = array [1..1] of byte;
  ArrayPtr  = ^ByteArray;

Const

crctab: ARRAY[0..255] OF WORD = (
    $0000,  $1021,  $2042,  $3063,  $4084,  $50a5,  $60c6,  $70e7,
    $8108,  $9129,  $a14a,  $b16b,  $c18c,  $d1ad,  $e1ce,  $f1ef,
    $1231,  $0210,  $3273,  $2252,  $52b5,  $4294,  $72f7,  $62d6,
    $9339,  $8318,  $b37b,  $a35a,  $d3bd,  $c39c,  $f3ff,  $e3de,
    $2462,  $3443,  $0420,  $1401,  $64e6,  $74c7,  $44a4,  $5485,
    $a56a,  $b54b,  $8528,  $9509,  $e5ee,  $f5cf,  $c5ac,  $d58d,
    $3653,  $2672,  $1611,  $0630,  $76d7,  $66f6,  $5695,  $46b4,
    $b75b,  $a77a,  $9719,  $8738,  $f7df,  $e7fe,  $d79d,  $c7bc,
    $48c4,  $58e5,  $6886,  $78a7,  $0840,  $1861,  $2802,  $3823,
    $c9cc,  $d9ed,  $e98e,  $f9af,  $8948,  $9969,  $a90a,  $b92b,
    $5af5,  $4ad4,  $7ab7,  $6a96,  $1a71,  $0a50,  $3a33,  $2a12,
    $dbfd,  $cbdc,  $fbbf,  $eb9e,  $9b79,  $8b58,  $bb3b,  $ab1a,
    $6ca6,  $7c87,  $4ce4,  $5cc5,  $2c22,  $3c03,  $0c60,  $1c41,
    $edae,  $fd8f,  $cdec,  $ddcd,  $ad2a,  $bd0b,  $8d68,  $9d49,
    $7e97,  $6eb6,  $5ed5,  $4ef4,  $3e13,  $2e32,  $1e51,  $0e70,
    $ff9f,  $efbe,  $dfdd,  $cffc,  $bf1b,  $af3a,  $9f59,  $8f78,
    $9188,  $81a9,  $b1ca,  $a1eb,  $d10c,  $c12d,  $f14e,  $e16f,
    $1080,  $00a1,  $30c2,  $20e3,  $5004,  $4025,  $7046,  $6067,
    $83b9,  $9398,  $a3fb,  $b3da,  $c33d,  $d31c,  $e37f,  $f35e,
    $02b1,  $1290,  $22f3,  $32d2,  $4235,  $5214,  $6277,  $7256,
    $b5ea,  $a5cb,  $95a8,  $8589,  $f56e,  $e54f,  $d52c,  $c50d,
    $34e2,  $24c3,  $14a0,  $0481,  $7466,  $6447,  $5424,  $4405,
    $a7db,  $b7fa,  $8799,  $97b8,  $e75f,  $f77e,  $c71d,  $d73c,
    $26d3,  $36f2,  $0691,  $16b0,  $6657,  $7676,  $4615,  $5634,
    $d94c,  $c96d,  $f90e,  $e92f,  $99c8,  $89e9,  $b98a,  $a9ab,
    $5844,  $4865,  $7806,  $6827,  $18c0,  $08e1,  $3882,  $28a3,
    $cb7d,  $db5c,  $eb3f,  $fb1e,  $8bf9,  $9bd8,  $abbb,  $bb9a,
    $4a75,  $5a54,  $6a37,  $7a16,  $0af1,  $1ad0,  $2ab3,  $3a92,
    $fd2e,  $ed0f,  $dd6c,  $cd4d,  $bdaa,  $ad8b,  $9de8,  $8dc9,
    $7c26,  $6c07,  $5c64,  $4c45,  $3ca2,  $2c83,  $1ce0,  $0cc1,
    $ef1f,  $ff3e,  $cf5d,  $df7c,  $af9b,  $bfba,  $8fd9,  $9ff8,
    $6e17,  $7e36,  $4e55,  $5e74,  $2e93,  $3eb2,  $0ed1,  $1ef0
);

crc16tab: ARRAY[0..255] OF WORD = (
    $0000,  $1189,  $2312,  $329b,  $4624,  $57ad,  $6536,  $74bf,
    $8c48,  $9dc1,  $af5a,  $bed3,  $ca6c,  $dbe5,  $e97e,  $f8f7,
    $1081,  $0108,  $3393,  $221a,  $56a5,  $472c,  $75b7,  $643e,
    $9cc9,  $8d40,  $bfdb,  $ae52,  $daed,  $cb64,  $f9ff,  $e876,
    $2102,  $308b,  $0210,  $1399,  $6726,  $76af,  $4434,  $55bd,
    $ad4a,  $bcc3,  $8e58,  $9fd1,  $eb6e,  $fae7,  $c87c,  $d9f5,
    $3183,  $200a,  $1291,  $0318,  $77a7,  $662e,  $54b5,  $453c,
    $bdcb,  $ac42,  $9ed9,  $8f50,  $fbef,  $ea66,  $d8fd,  $c974,
    $4204,  $538d,  $6116,  $709f,  $0420,  $15a9,  $2732,  $36bb,
    $ce4c,  $dfc5,  $ed5e,  $fcd7,  $8868,  $99e1,  $ab7a,  $baf3,
    $5285,  $430c,  $7197,  $601e,  $14a1,  $0528,  $37b3,  $263a,
    $decd,  $cf44,  $fddf,  $ec56,  $98e9,  $8960,  $bbfb,  $aa72,
    $6306,  $728f,  $4014,  $519d,  $2522,  $34ab,  $0630,  $17b9,
    $ef4e,  $fec7,  $cc5c,  $ddd5,  $a96a,  $b8e3,  $8a78,  $9bf1,
    $7387,  $620e,  $5095,  $411c,  $35a3,  $242a,  $16b1,  $0738,
    $ffcf,  $ee46,  $dcdd,  $cd54,  $b9eb,  $a862,  $9af9,  $8b70,
    $8408,  $9581,  $a71a,  $b693,  $c22c,  $d3a5,  $e13e,  $f0b7,
    $0840,  $19c9,  $2b52,  $3adb,  $4e64,  $5fed,  $6d76,  $7cff,
    $9489,  $8500,  $b79b,  $a612,  $d2ad,  $c324,  $f1bf,  $e036,
    $18c1,  $0948,  $3bd3,  $2a5a,  $5ee5,  $4f6c,  $7df7,  $6c7e,
    $a50a,  $b483,  $8618,  $9791,  $e32e,  $f2a7,  $c03c,  $d1b5,
    $2942,  $38cb,  $0a50,  $1bd9,  $6f66,  $7eef,  $4c74,  $5dfd,
    $b58b,  $a402,  $9699,  $8710,  $f3af,  $e226,  $d0bd,  $c134,
    $39c3,  $284a,  $1ad1,  $0b58,  $7fe7,  $6e6e,  $5cf5,  $4d7c,
    $c60c,  $d785,  $e51e,  $f497,  $8028,  $91a1,  $a33a,  $b2b3,
    $4a44,  $5bcd,  $6956,  $78df,  $0c60,  $1de9,  $2f72,  $3efb,
    $d68d,  $c704,  $f59f,  $e416,  $90a9,  $8120,  $b3bb,  $a232,
    $5ac5,  $4b4c,  $79d7,  $685e,  $1ce1,  $0d68,  $3ff3,  $2e7a,
    $e70e,  $f687,  $c41c,  $d595,  $a12a,  $b0a3,  $8238,  $93b1,
    $6b46,  $7acf,  $4854,  $59dd,  $2d62,  $3ceb,  $0e70,  $1ff9,
    $f78f,  $e606,  $d49d,  $c514,  $b1ab,  $a022,  $92b9,  $8330,
    $7bc7,  $6a4e,  $58d5,  $495c,  $3de3,  $2c6a,  $1ef1,  $0f78
);

crc_32_tab: ARRAY[0..255] OF LONGINT = (
$00000000, $77073096, $ee0e612c, $990951ba, $076dc419, $706af48f, $e963a535, $9e6495a3,
$0edb8832, $79dcb8a4, $e0d5e91e, $97d2d988, $09b64c2b, $7eb17cbd, $e7b82d07, $90bf1d91,
$1db71064, $6ab020f2, $f3b97148, $84be41de, $1adad47d, $6ddde4eb, $f4d4b551, $83d385c7,
$136c9856, $646ba8c0, $fd62f97a, $8a65c9ec, $14015c4f, $63066cd9, $fa0f3d63, $8d080df5,
$3b6e20c8, $4c69105e, $d56041e4, $a2677172, $3c03e4d1, $4b04d447, $d20d85fd, $a50ab56b,
$35b5a8fa, $42b2986c, $dbbbc9d6, $acbcf940, $32d86ce3, $45df5c75, $dcd60dcf, $abd13d59,
$26d930ac, $51de003a, $c8d75180, $bfd06116, $21b4f4b5, $56b3c423, $cfba9599, $b8bda50f,
$2802b89e, $5f058808, $c60cd9b2, $b10be924, $2f6f7c87, $58684c11, $c1611dab, $b6662d3d,
$76dc4190, $01db7106, $98d220bc, $efd5102a, $71b18589, $06b6b51f, $9fbfe4a5, $e8b8d433,
$7807c9a2, $0f00f934, $9609a88e, $e10e9818, $7f6a0dbb, $086d3d2d, $91646c97, $e6635c01,
$6b6b51f4, $1c6c6162, $856530d8, $f262004e, $6c0695ed, $1b01a57b, $8208f4c1, $f50fc457,
$65b0d9c6, $12b7e950, $8bbeb8ea, $fcb9887c, $62dd1ddf, $15da2d49, $8cd37cf3, $fbd44c65,
$4db26158, $3ab551ce, $a3bc0074, $d4bb30e2, $4adfa541, $3dd895d7, $a4d1c46d, $d3d6f4fb,
$4369e96a, $346ed9fc, $ad678846, $da60b8d0, $44042d73, $33031de5, $aa0a4c5f, $dd0d7cc9,
$5005713c, $270241aa, $be0b1010, $c90c2086, $5768b525, $206f85b3, $b966d409, $ce61e49f,
$5edef90e, $29d9c998, $b0d09822, $c7d7a8b4, $59b33d17, $2eb40d81, $b7bd5c3b, $c0ba6cad,
$edb88320, $9abfb3b6, $03b6e20c, $74b1d29a, $ead54739, $9dd277af, $04db2615, $73dc1683,
$e3630b12, $94643b84, $0d6d6a3e, $7a6a5aa8, $e40ecf0b, $9309ff9d, $0a00ae27, $7d079eb1,
$f00f9344, $8708a3d2, $1e01f268, $6906c2fe, $f762575d, $806567cb, $196c3671, $6e6b06e7,
$fed41b76, $89d32be0, $10da7a5a, $67dd4acc, $f9b9df6f, $8ebeeff9, $17b7be43, $60b08ed5,
$d6d6a3e8, $a1d1937e, $38d8c2c4, $4fdff252, $d1bb67f1, $a6bc5767, $3fb506dd, $48b2364b,
$d80d2bda, $af0a1b4c, $36034af6, $41047a60, $df60efc3, $a867df55, $316e8eef, $4669be79,
$cb61b38c, $bc66831a, $256fd2a0, $5268e236, $cc0c7795, $bb0b4703, $220216b9, $5505262f,
$c5ba3bbe, $b2bd0b28, $2bb45a92, $5cb36a04, $c2d7ffa7, $b5d0cf31, $2cd99e8b, $5bdeae1d,
$9b64c2b0, $ec63f226, $756aa39c, $026d930a, $9c0906a9, $eb0e363f, $72076785, $05005713,
$95bf4a82, $e2b87a14, $7bb12bae, $0cb61b38, $92d28e9b, $e5d5be0d, $7cdcefb7, $0bdbdf21,
$86d3d2d4, $f1d4e242, $68ddb3f8, $1fda836e, $81be16cd, $f6b9265b, $6fb077e1, $18b74777,
$88085ae6, $ff0f6a70, $66063bca, $11010b5c, $8f659eff, $f862ae69, $616bffd3, $166ccf45,
$a00ae278, $d70dd2ee, $4e048354, $3903b3c2, $a7672661, $d06016f7, $4969474d, $3e6e77db,
$aed16a4a, $d9d65adc, $40df0b66, $37d83bf0, $a9bcae53, $debb9ec5, $47b2cf7f, $30b5ffe9,
$bdbdf21c, $cabac28a, $53b39330, $24b4a3a6, $bad03605, $cdd70693, $54de5729, $23d967bf,
$b3667a2e, $c4614ab8, $5d681b02, $2a6f2b94, $b40bbe37, $c30c8ea1, $5a05df1b, $2d02ef8d
);

Function UpdCrc(cp: BYTE; crc: WORD): WORD;
Function CRCBlock(crc: word; Buff : pointer; len : word) : word;
Function UpdC16(cp: BYTE; crc: WORD): WORD;
Function CRC16Block(crc: word; Buff : pointer; len : word) : word;
Function UpdC32(octet: BYTE; crc: LONGINT) : LONGINT;
Function CRC32Block(crc: LongInt; Buff : pointer; len : word) : LongInt;
Function HexByte(bt : Byte)   : Str2;
Function HexWord(wd : Word)   : Str4;
Function HexLong(dw : LongInt): Str8;
Function LowHexByte(bt : Byte)   : Str2;
Function LowHexWord(wd : Word)   : Str4;
Function LowHexLong(dw : LongInt): Str8;
Function strCRC32(S:string):longint;
Function LowHex(bt : LongInt)   : String;
function TakeFirstLong (SomeStr : String):LongInt;
function TakeFirstHex (SomeStr : String):LongInt;

IMPLEMENTATION

Function HexByte(bt : Byte) : Str2;
Const
  Hex : Array[$0..$F] Of Char = '0123456789ABCDEF';
Begin
  HexByte := Hex[bt Shr 4] + Hex[bt And $F];
End;

Function HexWord(wd : Word) : Str4;
Begin
  HexWord := HexByte(Hi(wd)) + HexByte(Lo(wd));
End;

Function HexLong(dw : LongInt) : Str8;
Var
  w : Array[1..2] Of Word Absolute dw;
Begin
  HexLong := HexWord(w[2]) + HexWord(w[1]);
End;

Function LowHex(bt : LongInt) : String;
Const
  Hex : Array[$0..$F] Of Char = '0123456789abcdef';
var
  Stri: String;
Begin
  Stri:='';
  repeat
  Stri := Hex[bt And $F] + Stri;
  bt   := bt shr 4;
  until bt=0;
  LowHex := Stri;
End;

Function LowHexByte(bt : Byte) : Str2;
Const
  Hex : Array[$0..$F] Of Char = '0123456789abcdef';
Begin
  LowHexByte := Hex[bt Shr 4] + Hex[bt And $F];
End;

Function LowHexWord(wd : Word) : Str4;
Begin
  LowHexWord := LowHexByte(Hi(wd)) + LowHexByte(Lo(wd));
End;

Function LowHexLong(dw : LongInt) : Str8;
Var
  w : Array[1..2] Of Word Absolute dw;
Begin
  LowHexLong := LowHexWord(w[2]) + LowHexWord(w[1]);
End;

FUNCTION UpdCrc(cp: BYTE; crc: WORD): WORD;
BEGIN
   UpdCrc := crctab[((crc SHR 8) AND $0FF)] XOR (crc SHL 8) XOR cp;
END;

FUNCTION UpdC16(cp: BYTE; crc: WORD): WORD;
BEGIN
   UpdC16 := Crc16Tab[(Crc XOR Cp) AND $FF] XOR (Crc SHR 8);
END;

FUNCTION UpdC32(octet: BYTE; crc: LONGINT) : LONGINT;
BEGIN { UpdC32 }
    UpdC32 := Crc_32_Tab[(Crc XOR octet) AND $FF] XOR (Crc SHR 8);

END;

function strCRC32(S:string):longint;
{-возвpащает crc32 для стpоки S}
var
 l,
 crc: longint;
 i:byte;
 crcPrim:array[0..3] of byte absolute crc;

begin
 crc := $FFFFFFFF;

 for i:= 1 to Length(S) do crc := UpdC32(Byte(S[i]),crc);
 for i:=0 to 3 do l:=(l shl 8) or crcPrim[i];

 strCRC32:=l;
end;

Function CRCBlock(crc: word; Buff : pointer; len : word) : word;
Var
  i      : word;
  OutCRC : word;
  Buffer : ArrayPtr absolute Buff;
begin
  OutCRC:=CRC;
  For i:=1 to len do

  OutCRC:=UpdCrc(Buffer^[i],OutCRC);
  CRCBlock:=OutCRC;
end;

Function CRC16Block(crc: word; Buff : pointer; len : word) : word;
Var
  i      : word;
  OutCRC : word;
  Buffer : ArrayPtr absolute Buff;
begin
  OutCRC:=CRC;
  If Len<>0 then
  For i:=1 to len do
  OutCRC:=UpdC16(Buffer^[i],OutCRC);
  CRC16Block:=OutCRC;
end;

Function CRC32Block(crc: LONGINT; Buff : pointer; len : word) : LongInt;
Var
  i      : word;
  OutCRC : LongInt;
  Buffer : ArrayPtr absolute Buff;
begin
  OutCRC:=CRC;
  If Len<>0 then
  For i:=1 to len do
  OutCRC:=UpdC32(Buffer^[i],OutCRC);
  CRC32Block:=OutCRC;
end;

function TakeFirstLong (SomeStr : String):LongInt;
Var
  i   : byte;
  Res : LongInt;
begin
  Res:=0;
  For i:=1 to length(SomeStr) do
  If SomeStr[i]<>' ' then begin
    If SomeStr[i] in ['0'..'9'] then
       Res:=Res*10+(byte(SomeStr[i])-$30)
    else begin
       TakeFirstLong:=Res;
       exit;
    end;
  end;
  TakeFirstLong:=Res;
end;

function TakeFirstHex (SomeStr : String):LongInt;
Var
  i   : byte;
  Res : LongInt;
begin
  Res:=0;
  For i:=1 to length(SomeStr) do begin
    case SomeStr[i] of
    '0'..'9' : Res:=(Res shl 4)+(byte(SomeStr[i])-$30);
    'a'..'f' : Res:=(Res shl 4)+(byte(SomeStr[i])-$57);
    'A'..'F' : Res:=(Res shl 4)+(byte(SomeStr[i])-$37);
    else
     TakeFirstHex:=Res;
     exit;
    end;
  end;
  TakeFirstHex:=Res;
end;

END. {unit}
