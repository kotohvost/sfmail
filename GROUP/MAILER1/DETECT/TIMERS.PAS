{$M $800,0,0 }   { 2K stack, no heap }
{$F+,S-}
uses
  Dos,
  RelTQ;

Var
  OldInt8: procedure;

procedure Int8; interrupt;
begin
  ReleaseTQ;
  inline ($9C);
  OldInt8;
  ReleaseTQ;
end;

begin
  GetIntVec($8,@OldInt8);
  SetIntVec($8,Addr(Int8));
  Keep(0);
end.