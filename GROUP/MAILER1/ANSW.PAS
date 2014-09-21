{$I SFDefine.inc}
{$V+,X+,O+,F+,A+}
Unit ANSW;

interface

procedure Answer(StrToMod:String);
procedure wait;

implementation
Uses TPCRT,
     TString_,
     Busy,
     StatView,
     SFInclud,
     SFM_DLG,
     Config,
     aTime,
     ScrnSS,
     Sfm_Cfg,
     SF_Bink,
     SF_Fax,
     SF_Snd,
     FreQMan,
     EmStruct,
     Em_Cpl,
     HisView,
     Help,
     Nes,
     aDir,
     face,
     AQM,
     Date,
     Terminal,
     TPWindow,
     A002Xs,
     MsgXs,
     EventMan,
     Debug,
     WriteLog,
     RelTQ,
     Modem,
     keyb,
     KeyRead,
     EMSI,
     EdLn,
     ChgMaddr,
     Pwd_Xs,
     Fos_Lib,
     Call,
     CRC_All,
     SF_Shell,
     SF_Init,
     Session,
     ProcMan,
     SwapR;

{ ===============================  Answers  ============================= }

function GetResponce(Var RespStr:String):boolean;
Var
    C    : Integer;
begin
 GetResponce:=false;
 c:=ReadChar;
 while c<>TERR_RXEMPTY do begin
  RespStr:=RespStr+char(c);
  if char(c)=#10 then begin
   Delete(RespStr,length(RespStr)-1,2);
   GetResponce:=true;
   exit;
  end;
  c:=ReadChar;
 end;
{$IFNDEF ANTON}
 ReleaseTQ;
{$ENDIF}
end;

procedure PrepAnswer;
begin
 Connect_Speed:=300;
 CanHydra:=pCfgRec^.SysFlags and mdmAllowHydra <> 0;
 if ScreenSave then begin
   LastSaver:=true;
   RestScreen;
   Check4Lamps;
 end;
 if not caller then begin
   LogWrite(imIncomingScreen,'',ld_Screen);
   LogWrite(imIncomingDisk,'',ld_File);
 end;
 LastStatus:=false;
end;

function CheckTime(Time:LongInt):boolean;
Var
  DifTime:LongInt;
begin
 CheckTime:=false;
 DifTime:=trunc((TimeCounter-Time) / 18.2);
 if DifTime>WaitCarrierDef then begin
   WriteString(#27);
   pause(18);
   exit;
 end;
    {... TimeOut ...}
 ShowTime;
 ShowScanTime(WaitCarrierDef-DifTime);
 CheckTime:=true;
end;

procedure EndAnswer;
begin
  ShowTime;
  ShowScanTime(0);
  ShowHistory;
  Pause(10);
  ClearTxQueue;
  ClearRxQueue;
  InitModem;
end;

procedure CloseAnswer(ReasonMsg:word;ParStr:String;ModStr:String);
begin
   If Caller then begin
     if (not NodeEntry.NamedPoll) then
       ClearCSY(CalledAddr);
     KillWindow(PWin);
   end;
  LogWrite(ReasonMsg,ParStr,ld_All);
  ModemLogScreen(ModStr);
  EndAnswer;
end;

function CheckKbd(Var Time:LongInt):boolean;
Var
  Ch:char;
begin
 CheckKbd:=false;
 if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
   if keypressed then begin
     LastKeyPressed:=0;
     ch:=readkey;
     case ch of
      #27,#32 : begin
           WriteString(#27);
           pause(18);
           exit;
         end;
      #43     : Inc(Time,18); {+}
      #45     : Dec(Time,18); {-}
      #0      : ch:=ReadKey;
     end;
   end else
     IfKeyPress:=0;
 end;
 CheckKbd:=true;
end;

function CheckVoice(Responce:string):boolean;
begin
 CheckVoice:=false;
 if Pos(pCfgRec^.Connect_Voice,Responce+#13#10)<>0 then begin
   LogWrite(0,'    '+Responce,ld_All);
   if caller then begin
     If (not NodeEntry.NamedPoll) then
       ClearCSY(CalledAddr);
     KillWindow(PWin);
     LogWrite(emNotSession,'Human',ld_All);
   end else begin
     if PcfgRec^.Process_VOICE[0]=#0 then
       LogWrite(emNotVoice,'',ld_All) else
       Swap_Run(PcfgRec^.Process_VOICE,true);
   end;
   EndAnswer;
   CheckVoice:=true;
 end;
end;

function CheckFax(Responce:string):boolean;
begin
 CheckFax:=false;
 if Pos(pCfgRec^.Connect_Fax,Responce+#13#10)<>0 then begin
   If Caller then begin
     if (not NodeEntry.NamedPoll) then
       ClearCSY(CalledAddr);
     KillWindow(PWin);
   end;
   LogWrite(0,'    '+Responce,ld_All);
   if caller then
     LogWrite(emNotSession,'Fax',ld_All)
   else begin
     if PcfgRec^.Process_FAX[0]=#0 then begin
       If CheckSN then
         ReceiveFax
       else
         LogWrite(emNotFax,'',ld_All);
     end else
       Swap_Run(PcfgRec^.Process_FAX,true);
   end;
   EndAnswer;
   CheckFax:=true;
 end;
end;

function CheckConnect(Responce:string):boolean;
var c:byte;
begin
 CheckConnect:=false;
 if Pos(pCfgRec^.Connect_Str,Responce+#13#10)<>0 then begin
   If Caller then begin
     if (not NodeEntry.NamedPoll) then
       ClearCSY(CalledAddr);
     KillWindow(PWin);
   end;
   LogWrite(0,'    '+Responce,ld_All);
   If not NodeEntry.NamedPoll then
     ClearCSY(CalledAddr);
   {.. Check Hydra ...}
   If CanHydra then begin
     for c:=1 to NoHydCount do
      If Pos(NoHydra[c],Responce)<>0 then CanHydra:=false;
     If NodeEntry.NoHydra then CanHydra:=false;
   end;

   LastConnect:=Responce;
   Connect_Speed:=TakeFirstLong(ExtractWord(2,Responce,[' ']));
   If Connect_Speed=0 then begin
     ModemLogScreen('Connect 300');
     Connect_Speed:=2400;
   end else
     ModemLogScreen('Connect '+Long2Str(Connect_Speed));
   if Caller then begin
     if not NodeEntry.NamedPoll then begin
       LogWrite(imTryEMSI,'',ld_Screen);
       SlowSpeed:=(pCfgRec^.Min_Baud_Out > Connect_Speed);
     end;
   end else begin
     LogWrite(imAnalysing,'',ld_Screen);
     SlowSpeed:=(pCfgRec^.Min_Baud_In > Connect_Speed);
   end;
   if NodeEntry.NamedPoll and caller then begin
     if NodeEntry.NPprocess[1]='|' then begin
       TermMode:=true;
       LogWrite(imTerminalIn,'',ld_All);
       If pCfgRec^.XTerminal<>'' then begin
         OS2Title:='SF-Mail Terminal ';
         Swap_Run(pCfgRec^.XTerminal,true);
       end else
         RunTerminal;
       InitModem;
       NullTime:=true;
       ShowTime;
       TermMode:=false;
     end else begin
       LogWrite(imRunExternal,'',ld_All);
       OS2Title:='SF-Mail External ';
       Swap_Run(NodeEntry.NPprocess,true);
       InitModem;
       NullTime:=true;
       ShowTime;
     end;
   end else begin
     StoreSessTime;
     ShowSessTime;
     BeginTime:=TimeCounter;
     if (NodeEntry.Script<>'') and caller then begin
       Swap_Run('#'+NodeEntry.Script,true);
       if (GetPortStat and ST_DCD)<>0 then
         FTN_Session;
     end else
       FTN_Session;
     ClearSessTime;
   end;
   EndAnswer;
   CheckConnect:=true;
 end;
end;

procedure Answer(StrToMod:String);
Var
  Time     : LongInt;
  Responce : String;
  i        : byte;
  {first    : boolean;}
  c        : integer;
  Ringing  : byte;
begin
 PrepAnswer;
 Time:=TimeCounter;
 CheckTime(Time);
 Responce:='';
 Ringing:=0;
 WriteString(StrToMod);

 repeat
   If not CheckKbd(Time) then begin
     CloseAnswer(wmKeybAbbort,'','No Carrier');
     exit;
   end;
   If Not CheckTime(Time) then begin
     If ((pCfgRec^.TryInc_On and icNoCarrier)<>0) and caller then
       Inc(Que[CurQue]^.Try);
     CloseAnswer(wmTimeOut,'','No Carrier');
     exit;
   end;

   if GetResponce(Responce) then begin
     if length(pCfgRec^.Modem_Ringing)<>0 then begin
       If Pos(pCfgRec^.Modem_Ringing,Responce+#13#10)<>0 then begin
         Inc(Ringing);
         ModemLogScreen(StUpCase(pCfgRec^.Modem_Ringing)+' '+Long2Str(Ringing));
         if (pCfgRec^.MaxRinging<>0) and (Ringing>=pCfgRec^.MaxRinging) then begin
           If ((pCfgRec^.TryInc_On and icNoAnswer)<>0) and caller then
             Inc(Que[CurQue]^.Try);
           CloseAnswer(wmMaxRingReached,long2Str(Ringing),'No Answer');
           exit;
         end;
       end;
     end;
     If Pos(pCfgRec^.Modem_NoAnswer,Responce+#13#10)<>0 then begin
       If ((pCfgRec^.TryInc_On and icNoAnswer)<>0) and caller then
         Inc(Que[CurQue]^.Try);
       CloseAnswer(wmNoAnswer,'','No Answer');
       exit;
     end;
     If Pos('ERR',Responce+#13#10)<>0 then begin
       CloseAnswer(wmError,'','Error');
       exit;
     end;
     If Pos(pCfgRec^.Modem_NoCarrier,Responce+#13#10)<>0 then begin
       If ((pCfgRec^.TryInc_On and icNoCarrier)<>0) and caller then
         Inc(Que[CurQue]^.Try);
       CloseAnswer(wmNoCarrier,'','No Carrier');
       exit;
     end;
     If Pos(pCfgRec^.Modem_NoDial,Responce+#13#10)<>0 then begin
       If ((pCfgRec^.TryInc_On and icNoDial)<>0) and caller then
         Inc(Que[CurQue]^.Try);
       LastStatus:=true;
       CloseAnswer(wmNoDial,'','No DialTone');
       exit;
     end;
     If Pos(pCfgRec^.Modem_Busy,Responce+#13#10)<>0 then begin
       If ((pCfgRec^.TryInc_On and icBusy)<>0) and caller then
         Inc(Que[CurQue]^.Try);
       CloseAnswer(wmBusy,'','Busy');
       exit;
     end;
     for i:=1 to 5 do
       if length(pCfgRec^.Valid_Str[i])<>0 then
         If Pos(pCfgRec^.Valid_Str[i],Responce+#13#10)<>0 then
           LogWrite(0,'    '+Responce,ld_All);
     if CheckVoice(Responce) then exit;
     if CheckFax(Responce) then exit;
     if CheckConnect(Responce) then exit;
     Responce:='';
   end else
     ReleaseTQ;
 until false;
end;

{ ===============================  Wait  ================================= }
function AskRing(var Rings:byte):boolean;
begin
  AskRing:=false;
  PlaySound(TSndRing);
  If (TimeCounter-LastRing)<pCfgRec^.RingPause then
     Inc(Rings) else Rings:=1;
  ModemLogScreen('Ring '+Long2str(Rings));
  If Rings>=pCfgRec^.RingCount then
     AskRing:=true;
  LastRing:=TimeCounter;
end;

procedure wait;
Const
  RingAll : byte = 0;
Var
  ch       : char;
  All_Done : boolean;
  Chars    : integer;
  ReadS    : String;
  tempS    : String;
  s,s1     : String;
  tresc    : integer;
  tcall    : integer;
  ticMin   : word;
  Done     : boolean;
  CurEv    : tEventType;
  A,TmpA   : tAddress;
  k        : byte;
  n        : word;
  CrashTries : boolean;
  CrashTime  : LongInt;
  rescInit   : boolean;

procedure doRing(Msg:word);
begin
  If AskRing(RingAll) then begin
    LogWrite(msg,Long2str(RingAll),ld_Screen);
    RingAll:=0;
    if (ForceAnswerMode<>2) and ((ForceAnswerMode=1) or (MatchTimeArray(pCfgRec^._OH_Time_))) then begin
      Caller:=false;
      WaitCarrierDef:=pCfgRec^.WaitCarrierIn;
      Answer(pCfgRec^.Modem_Answer);
      ChangeTime:=0;
      if tCall<2 then tCall:=2;
    end else begin
      LogWrite(imRingIgnore,'',ld_All);
      WaitMsg;
      {Refresh;}
      If TCall<(pCfgRec^.RingPause div 9) then
        Inc(tcall,(pCfgRec^.RingPause div 9));
    end; {If Force Answer}
    ClearRxQueue;
    ClearTxQueue;
  end else begin
    If TCall<(pCfgRec^.RingPause div 15) then
      Inc(tcall,(pCfgRec^.RingPause div 15));
  end; {AskRing}
  ReadS:='';
  HardRing := false;
end;

begin
  If Keypressed then ifkeypress:=50;
  All_Done:= false;
  Done    := false;
  ReadS   := '';
  ClearRxQueue;
  ClearTxQueue;
  NullTime:=true;
  ShowTime;
  ticMin := minuts;
  tresc:=1;
  tcall:=pCfgRec^.CallPeriod;

repeat
  If HardRing and pCfgRec^.HardWare_Ring then
    doRing(imHardRing);

  TempS:='';
  ShowTime;

  if ChangeTime<>0 then begin
    If minuts<>ticMin then begin
      PlaySound(TSndTick);
      ticMin:=minuts;
    end;
    Case pCfgRec^.Modem_Ok_Time of
      oktMin  : if minuts<>LastMRefresh then begin
        Refresh;
        LastMRefresh:=minuts;
      end;
      oktHour : if hours<>LastMRefresh then begin
        Refresh;
        LastMRefresh:=hours;
      end;
      oktDay  : if Day<>LastMRefresh then begin
        Refresh;
        LastMRefresh:=Day;
      end;
    end;
    Dec(tresc,ChangeTime);
    Dec(tcall,ChangeTime);
    If ScreenSave then
      RefreshScreen;
    ChangeTime:=0;
    ShowTime;
    if (tresc<0) or (AskRescan) then begin
      tresc:=0;
      AskRescan:=false;
    end;
    if tcall<0 then tcall:=0;
    ShowScanTime(tcall);
    If LastTear<>Date_ then begin
      LogWrite(imStatistic,'',ld_File);
      LogWrite(imStatSendBytes,Long2Str(Statistic.AllSend),ld_File);
      LogWrite(imStatRecvBytes,Long2Str(Statistic.AllRecv),ld_File);
      LogWrite(imStatSessions,Long2Str(Statistic.SessOk)+#3+
                              Long2Str(Statistic.SessAb),ld_File);
      WriteLogHead;
      TimeCounter := 0;
      Statistic.AllSend:=0;
      Statistic.AllRecv:=0;
      Statistic.SessOk:=0;
      Statistic.SessAb:=0;
      WriteHist;
    end;
  end;

  {***********************  Refresh section  ****************************}

  If tresc=0 then begin
    CurEv:=CheckForEvent;
    rescInit:=CurEv <> evNone;
    While CurEv <> evNone do begin
      ContinueEvent;
      tresc:=0;
      ShowTime;
      CurEv:=CheckForEvent;
    end;
    tresc:=pCfgRec^.RescanPeriod;
    NullTime:=true;
    ShowTime;
    if RescInit then
      Initmodem;
  end;

  If tcall=0 then begin
    if NextQueue then begin
      CallNode;
      RingAll:=0;
      ChangeTime:=0;
      If LastStatus and (pCfgRec^.NoDial_Wait<>0) then
        tcall:=pCfgRec^.NoDial_Wait
      else
        tcall:=pCfgRec^.CallPeriod;
      NullTime:=true;
      ShowTime;
    end else begin
      If tCall<60 then tCall:=60;
      CloseLogFile;
      {refresh;}
    end;
  end;

  ReleaseTQ;

  {**********************  Keyboard section  ****************************}

  If pCfgRec^.ScreenSaverTime<>0 then begin
    If LastKeyPressed>pCfgRec^.ScreenSaverTime then begin
      LastKeyPressed:=pCfgRec^.ScreenSaverTime+1;
      If not ScreenSave then begin
        ScreenSaver;
        LastSaver:=false;
      end;
    end;
    If LastKeyPressed<pCfgRec^.ScreenSaverTime then
     if ScreenSave then begin
       RestScreen;
       Check4Lamps;
     end;
  end;

  if not FullLog and (ModWinTout+5<CurUnixTime) then ModemScrollDown;

  if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
    repeat
    if keypressed then begin
      LastKeyPressed:=0;
      ch:=readkey;
      case ch of
       #32: begin        {Space}
             tcall:=1;
             tresc:=0;
            end;
       #13: begin        {Enter}
             tcall:=1;
             tresc:=0;
             Bink_ScanCircle:=0;
            end;
       #42: begin               {*}
            tcall:=DefCallPeriod;
            pCfgRec^.CallPeriod:=DefCallPeriod;
            ShowScanTime(tcall);
            end;
       #43: begin               {+}
            Inc(tcall);
            Inc(pCfgRec^.CallPeriod);
            ShowScanTime(tcall);
            end;
       #15: tcall:=3600;        {Ctrl-O}
       #45: begin               {-}
            If tcall > 1 then Dec(tcall);
            If pCfgRec^.CallPeriod > 1 then Dec(pCfgRec^.CallPeriod);
            ShowScanTime(tcall);
            end;
       #8 : If pCfgRec^.ScreenSaverTime<>0 then begin      {BackSpace}
              LastKeyPressed:=pCfgRec^.ScreenSaverTime;
              ScreenSaver;
            end;
       #9 : begin                                          {Tab}
              If HeartMode then
                FastWrite(' ',ScreenHeight,80,ColorLamp);
              HeartMode:=Not HeartMode;
            end;
       #1 : begin                                          {Ctrl-A}
              ChangeMainAddr;
              DrawUpLine;
            end;
       #6 : begin       {Ctrl-F}
              if ForceAnswerMode<>2 then
                ForceAnswerMode :=2
              else
                ForceAnswerMode:=0;
              Check4Lamps;
            end;
       #16: begin                                          {Ctrl-P: Crash Poll}
            CanHydra:=pCfgRec^.SysFlags and mdmAllowHydra <> 0;
            CrashMode:=true;
            CrashExit:=false;
            CrashTries:=true;
            CrashTime:=CurUnixTime+pCfgRec^.HIP_Time*60;
            ModemScrollUp;
            repeat
             if Dial(CrashTries,CrashTime) then begin
               CrashTries:=false;
               StoreSessTime;
               ShowSessTime;
               BeginTime:=TimeCounter;
               Caller:=true;
               LastStatus:=false;
               LogWrite(imTryEMSI,'',ld_Screen);
               if (NodeEntry.Script<>'') and caller then begin
                 Swap_Run('#'+NodeEntry.Script,true);
                 if (GetPortStat and ST_DCD)<>0 then
                   FTN_Session;
               end else
                 FTN_Session;
               ClearSessTime;
             end else
              CrashExit:=true;
            until CrashExit;
            CrashMode:=false;
            ShowTime;
            ShowScanTime(0);
            InitModem;
       end;
       #0 : begin
            ch:=readkey;
            case ch of
              #45,
              #16 : All_Done:=true; {Alt-Q,Alt-X}
              #19 : begin
                     s:=''; s1:='';
                     if InputLine('FReq from address',s,
                        ILColors[1],ILColors[1],ILColors[2],ILColors[1],26,26,true)
                        then begin
                      SetDefaultAddr(pCfgRec^.MyAddress[1],false);
                      if not xStr2addr(S,A) then
                         LogWrite(emInvalidAddr,S,ld_Screen)
                      else begin
                        If InputLine('FReq files',s1,
                        ILColors[1],ILColors[1],ILColors[2],ILColors[1],100,60,false)
                        then begin
                          if Length(pCfgRec^.BinkOutbound) <>0 then
                            GenerateBinkFReq(a,s1)
                          else
                            GenerateMsg(a,s1,mtFReq, 0,'DIR');
                          tresc:=0;
                          Bink_ScanCircle:=0;
                        end;
                      end;
                     end;
                    InitModem;
                    NullTime:=true;
                    ShowTime;
                    end;
              #31 : begin        {Alt-S}
                    AttachFiles;
                    tresc:=0;
                    Bink_ScanCircle:=0;
                    InitModem;
                    NullTime:=true;
                    ShowTime;
                    end;
              #37 : {Alt-K}
                    MatchCfgFTime(true);
              #23 : begin        {Alt-I}
                    ViewHistory(Inbound);
                    NullTime:=true;
                    ShowTime;
                    end;
              #24 : begin        {Alt-O}
                    ViewHistory(OutGoing);
                    NullTime:=true;
                    ShowTime;
                    end;
              #44 : begin {Alt-Z}
                    InitModem;
                    ReadS := '';
                    ClearRxQueue;
                    ClearTxQueue;
                    NullTime:=true;
                    ShowTime;
                    end;
              #21 : begin        {Alt-Y}
                    RepackMail('all');
                    InitModem;
                    NullTime:=true;
                    ShowTime;
                    end;
              #25 : if InputLine('Input Address for poll',TempS,
                       ILColors[1],ILColors[1],ILColors[2],ILColors[1],26,26,true) then begin
                      Move(pCfgRec^.MyAddress[1],TmpA,SizeOf(tAddress));
                      for k:=1 to WordCount(TempS,[' ',',']) do begin
                        SetDefaultAddr(TmpA,false);
                        if xStr2addr(ExtractWord(k,TempS,[' ',',']),A) then begin
                          tmpA.Zone:=A.Zone;
                          tmpA.Net:=A.Net;
                          tmpA.Node:=A.Node;
                          GeneratePoll(A);
                          tresc:=0;
                          bink_ScanCircle:=0;
                        end else begin
                          LogWrite(emInvalidAddr,ExtractWord(k,TempS,[' ',',']),ld_Screen);
                        end;
                      end;
                    InitModem;
                    NullTime:=true;
                    ShowTime;
                    end;
              #49 : if InputLine('NodeInfo',TempS,
                       ILColors[1],ILColors[1],ILColors[2],ILColors[1],26,26,true) then begin
                      SetDefaultAddr(pCfgRec^.MyAddress[1],false);
                      if not xStr2addr(TempS,A) then
                        LogWrite(emInvalidAddr,TempS,ld_Screen)
                      else
                        NodeShow(A,CheckPassword(A));
                      InitModem;
                      NullTime:=true;
                      ShowTime;
                    end;
              #34 : begin       {Alt-G}
                    Draw_Debug;
                    NullTime:=true;
                    ShowTime;
                    end;
              #46 : begin       {Alt-C}
                    TempS:='';
                    If InputLine('Change config word',TempS,
                    ILColors[1],ILColors[1],ILColors[2],ILColors[1],100,60,false) then begin
                       AtRunTime:=true;
                       LogWrite(imManualSet,TempS,ld_All);
                       TempS:=PrepareLine(TempS,NumTokens);
                       ParseSingleWord(TempS);
                       InitModem;
                    end;
                    NullTime:=true;
                    ShowTime;
                    end;
             #104 : begin
                    TempS:=pCfgRec^.InitStr[1];
                    If InputLine('Change InitStr #1',TempS,
                    ILColors[1],ILColors[1],ILColors[2],ILColors[1],80,50,false) then begin
                      TempS:=Trim(TempS);
                      if (length(TempS)<>0) and (TempS[length(TempS)]<>'|') then
                      TempS:=TempS+'|';
                      pCfgRec^.InitStr[1]:=TempS;
                      InitModem;
                    end;
                    NullTime:=true;
                    ShowTime;
                    end;
             #105 : begin
                    TempS:=pCfgRec^.InitStr[2];
                    If InputLine('Change InitStr #2',TempS,
                    ILColors[1],ILColors[1],ILColors[2],ILColors[1],80,50,false) then begin
                      TempS:=Trim(TempS);
                      if (length(TempS)<>0) and (TempS[length(TempS)]<>'|') then
                      TempS:=TempS+'|';
                      pCfgRec^.InitStr[2]:=TempS;
                      InitModem;
                    end;
                    NullTime:=true;
                    ShowTime;
                    end;
             #106 : begin
                    TempS:=pCfgRec^.InitStr[3];
                    If InputLine('Change InitStr #3',TempS,
                    ILColors[1],ILColors[1],ILColors[2],ILColors[1],80,50,false) then begin
                      TempS:=Trim(TempS);
                      if (length(TempS)<>0) and (TempS[length(TempS)]<>'|') then
                      TempS:=TempS+'|';
                      pCfgRec^.InitStr[3]:=TempS;
                      InitModem;
                    end;
                    NullTime:=true;
                    ShowTime;
                    end;
             #107 : begin
                    TempS:=pCfgRec^.Modem_Answer;
                    If InputLine('Change Modem Answer',TempS,
                    ILColors[1],ILColors[1],ILColors[2],ILColors[1],80,50,false) then begin
                      TempS:=Trim(TempS);
                      if (length(TempS)<>0) and (TempS[length(TempS)]<>'|') then
                      TempS:=TempS+'|';
                      pCfgRec^.Modem_Answer:=TempS;
                      InitModem;
                    end;
                    NullTime:=true;
                    ShowTime;
                    end;
              #47 : begin       {Alt-S}
                    Show_Stati;
                    NullTime:=true;
                    ShowTime;
                    end;
              #59 : begin       {F1}
                    Draw_Help;
                    NullTime:=true;
                    ShowTime;
                    end;
             #129 : begin       {Alt-0}
                    ProcMan_UserMenu;
                    InitModem;
                    NullTime:=true;
                    ShowTime;
                    end;
              #20 : begin       {Alt-T}
                    TermMode:=true;
                    LogWrite(imTerminalIn,'',ld_All);
                    If pCfgRec^.XTerminal<>'' then begin
                      OS2Title:='SF-Mail Terminal ';
                      Swap_Run(pCfgRec^.XTerminal,true);
                    end else
                      RunTerminal;
                    InitModem;
                    NullTime:=true;
                    ShowTime;
                    TermMode:=false;
                    end;
              #33 : begin       {Alt-F}
                    if ForceAnswerMode<>1 then
                      ForceAnswerMode :=1
                    else
                      ForceAnswerMode:=0;
                    Check4Lamps;
                    end;
              #32 : begin
                    if pCfgRec^.Os_Shell<>'' then begin
                       OS2Title:='SF-Mail OS Shell ';
                       Swap_Run(pCfgRec^.Os_Shell,true);
                       InitModem;
                       end else
                       LogWrite(emNotShell,'',ld_Screen);
                    NullTime:=true;
                    ShowTime;
                    end;
              #18 : begin
                    if pCfgRec^.Msg_Editor<>'' then begin
                       OS2Title:='SF-Mail Msg Editor ';
                       Swap_Run(pCfgRec^.Msg_Editor,true);
                       InitModem;
                       end else
                       LogWrite(emNotEditor,'',ld_Screen);
                    NullTime:=true;
                    ShowTime;
                    end;
              #48 : begin
                    TextAttr:=$07;
                    QueueManager;
                    NullTime:=true;
                    ShowTime;
                    end;
              #22 : begin
                    if InputLine('Input program Name for exec',TempS,
                       ILColors[1],ILColors[1],ILColors[2],ILColors[1],128,60,false) then begin
                       OS2Title:='SF-Mail Manual prog ';
                       Swap_Run(TempS,true);
                       InitModem;
                       end;
                    NullTime:=true;
                    ShowTime;
                    end;
              #30 : begin  {Alt-A}
                    Caller:=false;
                    WaitCarrierDef:=pCfgRec^.WaitCarrierIn;
                    Answer(pCfgRec^.Modem_Answer);
                    RingAll:=0;
                    ChangeTime:=0;
                    if tCall<2 then tCall:=2;
                    ReadS := '';
                    ClearRxQueue;
                    ClearTxQueue;
                    NullTime:=true;
                    ShowTime;
                    end;
              else
              if ProcMan_Req4act(procKeyPress,ProcessInfo[procKeyPress].procBit,'',word(Ch) shl 8,true) then
                       begin
                       InitModem;
                       NullTime:=true;
                       ShowTime;
                       end;
              end;
            end;
            else
            If ProcMan_Req4act(procKeyPress,ProcessInfo[procKeyPress].procBit,'',word(0+byte(Ch)),true) then
                       begin
                       InitModem;
                       NullTime:=true;
                       ShowTime;
                       end;
       end;
     end else
     IfKeyPress:=0;
  Until IfKeyPress=0;
  end;

  ReleaseTQ;

  {***********************  Callers section  ****************************}

  Chars:=ReadChar;
  If Chars<>TERR_RXEMPTY then begin
    ReadS:=ReadS+Char(Chars);
    If (Pos('RING',ReadS)<>0) and (not pCfgRec^.HardWare_Ring) then
      doRing(imSoftRing);
  end else begin
    ReleaseTQ;
    ReleaseTQ;
  end;
until All_Done;
end;

end.