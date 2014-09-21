unit keyb;
interface
Var
  OldInt9Vec      : procedure;
  LastKeyPressed  : longInt;
  IfKeyPress      : byte;
Const
  CanRestore      : boolean = false;

procedure InitInt9;
procedure RestoreInt9;

implementation
  uses
    Fos_Lib,
    Config,
    SFInclud,
    ScrnSS,
    TPCrt,
    Dos;

Const
  FirstKey  : boolean=false;
  SecondKey : boolean=false;
  LockMode  : boolean=false;

{$F+,S-}
procedure NewInt9Vec; interrupt;
Var
  key : word;

begin
  key:=Port[$60];
  case key of
    29   : FirstKey:=true;
    157  : FirstKey:=false;
    78   : SecondKey:=true;
    206  : SecondKey:=false;
  end;

  if FirstKey and SecondKey then begin
    LockMode:=not LockMode;
    FirstKey:=false;
    SecondKey:=false;
    if LockMode then begin
      asm
        push BP
        mov  AX,1201h
        mov  BL,36h
        Int  10h
        pop  BP
      end;
    end else begin
      asm
        push BP
        mov  AX,1200h
        mov  BL,36h
        Int  10h
        pop  BP
      end;
    end;
  end;

  if LockMode then begin
    asm
     mov DX,$61
     in  AL,DX
     or  AL,$80
     out DX,AL
     mov DX,$20
     mov AL,$20
     out DX,AL
    end;
  end else begin
    if Port[$60] < $80 then begin
      { Только если клавиша нажата }
      Inc(IfKeyPress);
      LastKeyPressed:=0;
    end;
    inline ($9C);
    OldInt9Vec;
  end;
end;
{$F-,S+}

procedure InitInt9;
begin
  LastKeyPressed := 0;
  Randomize;
  { пеpеустанавливаем вектоpа }
  GetIntVec($9,@OldInt9Vec);
  SetIntVec($9,Addr(NewInt9Vec));
  CanRestore := true;
end;

procedure RestoreInt9;
begin
  { востанавливаем вектоp }
  If CanRestore then
   begin
   If ScreenSave then
      RestScreen;
   SetIntVec($9,Addr(OldInt9Vec));
   CanRestore:=false;
   end;
end;

end.