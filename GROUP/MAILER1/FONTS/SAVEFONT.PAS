uses TpCrt,Fonts;

{$I heart.inc}
Var
  i : byte;

Begin
  if not EGAInstalled then
  begin
    WriteLn('EGA/VGA required');
    Halt(1)
  end;
  i:=0;
  While not keyPressed do begin
    LoadCharset(Font1[i,0], 32, 1, 16);
    Inc(i);
    if i>15 then i:=0;
    Delay(1000);
  end;
End.