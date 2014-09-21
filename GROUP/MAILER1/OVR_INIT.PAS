unit Ovr_Init;
interface
implementation
uses
{$IFDEF bVirtual}
  OvlMgBP;
{$ELSE}
  Overlay;
{$ENDIF}

begin
{$IFDEF bVirtual}
 OvlMgrInit;
 if OvlGetBuf<30000 then
 OvlSetBuf(30000);
{$ELSE}
 OvrFileMode:=$40;
 OvrInit('SF-MAIL.OVR');       { init overlay system, reserve heap space }
 if OvrResult <> 0 then begin
   Writeln('Can''t init overlay');
   Halt(208);
 end;
 if OvrGetBuf<30000 then
 OvrSetBuf(30000);
{$ENDIF}
end.