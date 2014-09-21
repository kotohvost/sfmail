(*************************************************************************)
(**    Time routines                                                    **)
(*************************************************************************)

function CheckTimer(Timer:LongInt): boolean;
begin
  If Timer>TimeCounter then
    CheckTimer:=false else
    CheckTimer:=true;
end;

procedure ResetTimer(Var Timer:longInt; Tics:longint);
begin
  Timer:=TimeCounter+Tics;
end;
