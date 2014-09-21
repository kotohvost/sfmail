{$F+,S-}
unit Code;
interface

procedure ChangeChar(Cha: byte; From:pointer);
procedure Init30Lines;

implementation

uses fonts, TPCrt;

procedure ChangeChar(Cha: byte; From:pointer);
begin
  LoadCharset(From^, Cha, 1, 16);
end;

procedure Init30Lines; assembler;
asm
  Mov     AH,0fh
  Int     10h
  Xor     AH,AH
  Int     10h

  Mov  DX,3C4h
  Mov  AX,100h
  Out  DX,AX
  Mov  AX,1
  Out  DX,AX
  Mov  AX,302h
  Out  DX,AX
  Mov  AX,3
  Out  DX,AX
  Mov  AX,204h
  Out  DX,AX
  Mov  DL,0C2h
  Mov  AL,0E7h
  Out  DX,al
  Mov  DL,0C4h
  Mov  AX,300h
  Out  DX,AX
  Mov  DL,0D4h
  Mov  AX,0C11h
  Out  DX,AX
  Mov  AX,0B06h
  Out  DX,AX
  Mov  AX,3E07h
  Out  DX,AX
  Mov  AX,4F09h
  Out  DX,AX
  Mov  AX,0EA10h
  Out  DX,AX
  Mov  AX,8C11h
  Out  DX,AX
  Mov  AX,0DF12h
  Out  DX,AX
  Mov  AX,0E715h
  Out  DX,AX
  Mov  AX,416h
  Out  DX,AX
  Push DS
  Push 0
  Pop  DS
  Mov  AL,1Dh
  Mov  DS:484h,AL
  Mov  AL,0FEh
  And  DS:487h,AL
  Mov  AX,12C0h
  Mov  DS:44Ch,AX
  Pop  DS
end;

end.

Дальше пpимеp:}

{.$I sfheart.inc}

var i:byte;
    _Done: boolean;

begin
  i:=0;
  repeat
    ChangeChar(79,@font[i,0]);
    Delay(50);
    inc(i);
    if i>15 then i:=0;
    _Done:=KeyPressed;
  until _Done;
 While KeyPressed do
   ReadKey;
end.