unit Parse;
interface

Type
  tParseLn = record
    OsLine : boolean;  { ���室��� ���p�樮���� ��⥬�, ⠪ �� ��}
    Body : String;     { ⥫� ��p��� }
    Comments : String; { �������p�� }
  end;

Procedure PrepareLine(S:String; Task: byte; Var PS:tParseLn);
{ ��pᨬ ��p��� }

implementation
Uses
  RelTQ;

function WhatOs(S:String; Task:byte):boolean;
{ ���室�� �� �� }
begin

end;

Procedure PrepareLine(S:String; Task: byte; Var PS:tParseLn);
{ ��pᨬ ��p��� }
begin
  FillChar(PS,SizeOf(tParseLn),0);
  S:=Trim(S);
  If S[1]='(' then begin
  end;
end;

end.