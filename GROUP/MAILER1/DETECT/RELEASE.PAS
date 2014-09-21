uses
{$IFDEF OS2}
  VPUtils,
{$ENDIF}
  TpCrt,
  TpWindow,
  TString_,
  RelTQ;

var
  ch    : char;
{$IFNDEF OS2}
  Timer : LongInt absolute $40:$6C;
{$ENDIF}
  Time  : LongInt;
  Delta : LongInt;
{$IFDEF OS2}
  Err   : LongInt;
{$ELSE}
  Err   : integer;
{$ENDIF}
  Win   : pointer;
  S     : String;

{$IFDEF OS2}
function Timer:LongInt;
begin
  Timer:=GetTimeMSec div 55;
end;
{$ENDIF}

procedure MyHalt(ErrorCo:word);
begin
  KillWindow(Win);
  NormalCursor;
  halt(ErrorCo);
end;

begin
 HiddenCursor;
 MakeWindow(Win,10,10,70,14,true,true,true,
            $1F,$1E,$1B,' OS: '+NameMultiTasker+' ');
 DisplayWindow(Win);
 ClrScr;
 if ParamCount=1 then begin
   Val(ParamStr(1),Delta,Err);
   Delta:=round(Delta*18.2);
   if Delta<18 then Delta:=182;
 end else
   Delta:=182;

 Time:=Timer;
 repeat
   FastWriteWindow('Wait ticker: '+long2Str(Time+Delta)+
                   '        Curent ticker: '+long2Str(Timer),2,7,$1A);

   Case sCPUXID.bXID of
      0    : s:='8086/8088 CPU detected';
      1..4 : s:='80'+Long2Str(sCPUXID.bXID)+'86 CPU detected';
      5    : s:='Pentium detected';
   end;

   FastCenter(' '+s+' ',4,$1B);
   If KeyPressed then begin
     ch:=readKey;
     if ch=#0 then begin
       ReadKey;
       Myhalt(0);
     end;
     if Ch=#27 then
       Myhalt(1);
     MyHalt(0);
   end;

   if (Timer>Time+Delta) or (Timer<Time) then Myhalt(0);
   ReleaseTQ;
   ReleaseTQ;
   ReleaseTQ;
   ReleaseTQ;
   ReleaseTQ;
   ReleaseTQ;
   ReleaseTQ;
   ReleaseTQ;
 until false;
end.