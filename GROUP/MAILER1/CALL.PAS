{$F+,O+}
unit Call;
interface
Uses
 config;

Var
  CalledAddr : tAddress;

procedure CallNode;
procedure ContinueEvent;

implementation
uses EventMan,
     EmStruct,
     Busy,
     StatView,
     MsgXs,
     SFInclud,
     SF_Init,
     Answ,
     ScrnSS,
     Fos_Lib,
     A002Xs,
     TPCrt,
     TPWindow,
     keyb,
     Tstring_,
     WriteLog,
     SwapR;

procedure ContinueEvent;
var
  evExitCode : integer;
begin
  if ScreenSave then begin
    LastSaver:=true;
    RestScreen;
  end;
  with CurEventPtr^ do begin
   case EventType of
     evExec: begin
        OS2Title:='SF-Mail Exec ';
        Swap_Run(EventStr,true);
     end;
     evExit: begin
        Str2Int(EventStr,evExitCode);
        LogWrite(imExiting,Long2str(evExitCode),ld_All);
        Done;
        halt(evExitCode);
     end;
   else
    DoEvent;
   end;
  end;
end;

procedure CallNode;
var
  i       : byte;
  Str2Mod : String;
begin
  if ScreenSave then begin
    LastSaver:=true;
    RestScreen;
  end else
    LastSaver:=false;
  ModemScrollUp;
  Str2Mod:=pCfgRec^.Dial_Prefix;
  with NodeEntry do begin
    If NamedPoll then
      LogWrite(imCalling,Name+#3'(named poll)',ld_Screen)
    else begin
      LogWrite(imCalling,Name+#3+Addr2str(Address,Address.Point<>0),ld_Screen);
      if (AddressBusy(NodeEntry.Address)) or (CSYBusy(NodeEntry.Address)) then begin
        WaitMsg;
        exit;
      end;
      CalledAddr:=NodeEntry.Address;
      SetCSY(CalledAddr);
    end;
    MakeWindow(PWin,15,ScreenHeight div 2 - 4,45,ScreenHeight div 2 + 2,true,true,true,
              pCfgRec^.SfMailColors[Session_Border],
              pCfgRec^.SfMailColors[Session_Border],
              pCfgRec^.SfMailColors[Session_Header],
              ' Calling ');
    DisplayWindow(Pwin);
    ClrScr;

    if length(Dial)<>0 then
      Str2Mod:=Dial
    else begin
      if ((Capability and (NodeFlag[HST])) <>0) and
         (length(pCfgRec^.Hst_Prefix) <>0) then
        Str2Mod:=pCfgRec^.Hst_Prefix
      else begin
        if ((Capability and (NodeFlag[H14])) <>0) and
           (length(pCfgRec^.H14_Prefix) <>0) then
          Str2Mod:=pCfgRec^.H14_Prefix
        else begin
          if ((Capability and (NodeFlag[H16])) <>0) and
             (length(pCfgRec^.H16_Prefix) <>0) then
            Str2Mod:=pCfgRec^.H16_Prefix
          else begin
            if ((Capability and (NodeFlag[ZYX])) <>0) and
               (length(pCfgRec^.ZYX_Prefix) <>0) then
              Str2Mod:=pCfgRec^.ZYX_Prefix
            else begin
              if ((Capability and (NodeFlag[PEP])) <>0) and
                 (length(pCfgRec^.PEP_Prefix) <>0) then
                Str2Mod:=pCfgRec^.PEP_Prefix;
            end;
          end;
        end;
      end;
    end;

    if not NamedPoll then
      FastCenter(Addr2Str(Address,Address.Point<>0),2,pCfgRec^.SfMailColors[Session_File]);
    FastCenter(Copy(Name,1,27),3,pCfgRec^.SfMailColors[Session_Info]);
    FastCenter(' '{+Str2Mod}+telephone+' ',4,pCfgRec^.SfMailColors[Session_Param]);
    if NamedPoll then
      FastCenter(' Named Poll (tm) ',6,pCfgRec^.SfMailColors[Session_Border])
    else begin
      If MaxBaud<>0 then begin
        if Que[CurQue]^.LastCallLine=0 then
          FastCenter(' '+Long2str(MaxBaud)+','+Nflag2str(Capability)+' ',6,pCfgRec^.SfMailColors[Session_Border])
        else
          FastCenter(' '+Long2str(MaxBaud)+', Line #'+
                     Long2Str(succ(Que[CurQue]^.LastCallLine))+' ',6,pCfgRec^.SfMailColors[Session_Border]);
      end else
        FastCenter(' *Unlisted* ',6,pCfgRec^.SfMailColors[Session_Border]);
    end;
    Caller:=true;
    case ZMode of
         tzMode(zmbZMO)  : ZModemSize := 0;
         tzMode(zmbMin)  : ZModemSize := 1;
         tzMode(zmbNorm) : ZModemSize := 2;
         tzMode(zmbMax)  : ZModemSize := 3;
    end;
    If Wait=0 then
      WaitCarrierDef:=pCfgRec^.WaitCarrierOut else
      WaitCarrierDef:=Wait;

    if NamedPoll then
      LogWrite(imOutgoing,Name+#3+'(named poll), '+Str2Mod+telephone,ld_File)
    else
      LogWrite(imOutgoing,Name+#3+
               Addr2str(Address,Address.Point<>0)+', '+Str2Mod+telephone,ld_File);
    Answer(Str2Mod+Telephone+pCfgRec^.Dial_Suffix);
    Caller:=false;
    If PWin<>nil then KillWindow(PWin);
    ShowHistory;
    if LastSaver and (LastKeyPressed>pCfgRec^.ScreenSaverTime) and (pCfgRec^.ScreenSaverTime<>0) then begin
      ScreenSaver;
      LastSaver:=false;
    end;
  end; {*WITH*}
end;

end.