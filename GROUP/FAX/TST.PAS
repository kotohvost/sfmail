uses
  tString_;
var
  Source : array [0..2048] of byte;
  Dest   : array [0..4096] of byte;

function Scale(var Data: array of byte; Len:word):word;
var
 newLen:word;
 i:word;
 n:byte;
 a:byte;
 b:array[1..2] of byte;

begin
 newLen:=0;
 i:=0;
 Dec(Len);
 while i <Len do begin
   b[1]:=Data[i];
   Inc(i);
   if i <Len then
    b[2]:=Data[i]
   else
    b[2]:=0;
   Inc(i);
   { converting }
   a:=( b[1] and $C0       ) or ((b[1] and $40) shr 1) or
      ((b[1] and $30) shr 1) or ((b[1] and $10) shr 2) or
      ((b[1] and $0C) shr 2);
   Dest[newlen]:=a;
   a:=((b[1] and $07) shl 5) or ((b[1] and $01) shl 4) or
      ((b[2] and $C0) shr 4) or ((b[2] and $60) shr 5);
   Dest[newlen+1]:=a;
   a:=((b[2] and $10) shl 3) or ((b[2] and $10) shl 2) or
      ((b[2] and $0C) shl 2) or ((b[2] and $07) shl 1) or
      ( b[2] and $01       );
   Dest[newlen+2]:=a;
   Inc(newLen,3);
  end;
 Scale:=newLen;
end;

var
  i : word;

begin
  for i:=0 to 100 do
    Source[i]:=i;
  WriteLn(Scale(Source,100));
  WriteLn(BinaryB(Source[0])+' '+BinaryB(Source[1])+' '+BinaryB(Source[2]));
  WriteLn(BinaryB(Dest[0])+' '+BinaryB(Dest[1])+' '+BinaryB(Dest[2])+' '+BinaryB(Dest[3]));
end.