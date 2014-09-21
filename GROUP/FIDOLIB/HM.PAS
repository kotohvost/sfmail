unit HM;
interface

{ Функции конвеpтиpования числа в стpоку ...}
  {Hex}
Function HexByteU(bt:Byte):String;
Function HexWordU(wd:Word):String;
Function HexLongU(dw:LongInt):String;
Function HexByteL(bt:Byte):String;
Function HexWordL(wd:Word):String;
Function HexLongL(dw:LongInt):String;
{ Функции стpоки в число ...}

implementation

Function HexByteU(bt:Byte):String;
Const
  Hex : Array[$0..$F] Of Char = '0123456789ABCDEF';
Begin
  HexByteU := Hex[bt Shr 4] + Hex[bt And $F];
end;

Function HexWordU(wd:Word):String;
Begin
  HexWordU := HexByteU(Hi(wd)) + HexByteU(Lo(wd));
End;

Function HexLongU(dw:LongInt):String;
Var
  w : Array[1..2] Of Word Absolute dw;
Begin
  HexLongU := HexWordU(w[2]) + HexWordU(w[1]);
End;

Function HexByteL(bt:Byte):String;
Const
  Hex : Array[$0..$F] Of Char = '0123456789abcdef';
Begin
  HexByteL := Hex[bt Shr 4] + Hex[bt And $F];
end;

Function HexWordL(wd:Word):String;
Begin
  HexWordL := HexByteL(Hi(wd)) + HexByteL(Lo(wd));
End;

Function HexLongL(dw:LongInt) : String;
Var
  w : Array[1..2] Of Word Absolute dw;
Begin
  HexLongL := HexWordL(w[2]) + HexWordL(w[1]);
End;

end.