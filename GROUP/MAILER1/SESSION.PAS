{$O+,F+,I-}
unit Session;

Interface

uses Dos;

procedure Mail_Session;
procedure Hydra_Session;

implementation
uses SFInclud,
     StatView,
     Config,
     EMStruct,
     SessCtl,
     EventMan,
     Modem,
     Fos_Lib,
     A002Xs,
     MsgXs,
     Date,
     ProcMan,
     flags,
     fileman,
     ZModem,
     TString_,
     TPCrt,
     TPWindow,
     CRC_All,
     SwapR,
     HShow,
     Hydra,
     Show,
     WriteLog;

Var
  AllTime      : LongInt;
  TimeStr      : String;
  SkipingFile  : boolean;

function SendAllFiles : boolean;
begin
   SkipingFile := false;
   Receive := false;
   LogWrite(imSynchronize,'',ld_Session);
   if not Synchronize then begin
     SendAllFiles:=false;
     exit;
   end;

   While SendThisFile(OldName,NewName,SkipingFile) do begin
     Case ZModemSend(OldName,NewName,EndFile) of
          ZOk : begin
             If TransferError = 0 then
               LogWrite(imZSendComplete,long2Str(Transfer_CPS)+#3+
                        long2Str(Transfer_CPSpc),ld_SessAll)
             else
               LogWrite(imZSendComplErr,long2Str(Transfer_CPS)+#3+
                        long2Str(Transfer_CPSpc)+#3+
                        long2Str(TransferError),ld_SessAll);
             with SessionControl^ do
               Inc(Traf_Out_Cur,ReceiveSize);

             SkipingFile := false;
          end;
    ZFileSkip : begin
                LogWrite(imZSkipping,OldName,ld_SessAll);
                SkipingFile := true;
                with SessionControl^ do begin
                   Inc(Traf_Out_Cur,ReceiveSize);
                end;
                end;
   else
       { Обpыв пpи пеpедаче файлов }
       LogWrite(wmZSendFailed,
                long2Str(TransferStart + TransferBytes)+#3+
                long2Str(Transfer_CPS)+#3+
                long2Str(Transfer_CPSpc),ld_SessAll);
       SendAllFiles:=false;
       exit;
   end;
   end;

   { Кpичим что все пеpедали }
   LogWrite(imBatchCompl,'',ld_Session);
   SendZEnd;
   SendAllFiles:=true;
end;

function ReceiveAllFiles : boolean;
begin
  Receive:=true;
  ReceivingFile:=false;
  LogWrite(imSynchronize,'',ld_Session);
  If (ZModemReceive(InBound_Path,
                    EndFile)<>0) {and (ReceivingFile)} then begin
      { Пpием накpылся;( }
    If ReceivingFile then begin
      LogWrite(wmZRecvFailed,
               long2Str(TransferStart + TransferBytes)+#3+
               long2Str(Transfer_CPS)+#3+
               long2Str(Transfer_CPSpc),ld_SessAll);
      checkPkt(inbound_Path,ReceiveName);
    end;
    ReceiveAllFiles:=false;
    exit;
  end;
  LogWrite(imBatchCompl,'',ld_Session);
  ReceiveAllFiles:=true;
end;

procedure UnderSession (SessOk : boolean; SessZModem : boolean);
Var
  Sc : word;
  i  : byte;

begin
  KillCD;
  AskRescan:=true;
  if PWin<>nil then KillWindow(PWin);

  If SessOk then begin
    LogWrite(imSessionOk,'',ld_All);
    LastSess_State:=true;
    CrashExit:=true;
  end else begin
    LastSess_State:=false;
    LogWrite(imSessionErr,'',ld_All);
  end;

  AllTime:=TimeCounter-BeginTime;
  If AllTime<0 then
     AllTime:=0;
  TimeStr:=LeftPadCh(Long2Str(((AllTime div 18) div 60) div 60),'0',2)+':'+
           LeftPadCh(Long2Str(((AllTime div 18) div 60) mod 60),'0',2)+':'+
           LeftPadCh(Long2Str((AllTime div 18) mod 60),'0',2);
  LogWrite(imTraffic,long2Str(SendByte)+#3+long2Str(ReceiveByte)+#3+TimeStr,ld_All);
  if (AllTime>0) and (SendByte+ReceiveByte > 10240) then begin
    Sc:=trunc ((SendByte+ReceiveByte) / (Alltime/18.2));
    LogWrite(imSessionCPS,long2Str(Sc),ld_All);
  end;

  LogWrite(imCloseSession,'',ld_Screen or ld_LastLn);
  If EndingSess then begin
    EndSession((not SessOk),receiveByte,sendByte);
    EndingSess:=false;
  end;

  EraseSemaphore(pCfgRec^.Flags_Dir+'in-sess.sf');
  { Hydra end or ZModem end }
  if SessZModem then
    ZModemEnd;

  Refresh;
  If pCfgRec^.Statistic[0]<>#0 then WriteStatistic;

  LogWrite(imRefreshModem,'',ld_Screen or ld_LastLn);
  If pCfgRec^.SysFlags and mdmInitAfterSess <>0 then
    Initmodem
  else
    Refresh;

  If SessOk then
    Inc(Statistic.SessOk)
  else
    Inc(Statistic.SessAb);

  for i:=1 to 4 do
    Statistic.Sessions[i]:=Statistic.Sessions[i+1];

  with Statistic.Sessions[5] do begin
    Info:=Pad(Addr2Str(SessionControl^.pRemoteInfo^.RemoteAddr[1],
              SessionControl^.pRemoteInfo^.RemoteAddr[1].point<>0),19);
    if Caller then
      Info:=Info+'Out '
    else
      Info:=Info+'In  ';
    Info:=Info+Pad(Long2Str(Connect_Speed),7);
    Info:=Info+TimeStr+' ';
    if (AllTime>0) then
      Info:=Info+LeftPad(Long2Str(trunc((SendByte+ReceiveByte)/(Alltime/18.2))),5)+' '
    else
      Info:=Info+LeftPad('0',5)+' ';
    Info:=Info+LeftPad(vInBestForm(SendByte),5)+'/'+
                   Pad(vInBestForm(ReceiveByte),6);
    with SessionControl^ do begin
      if WhatRcvd and imNetMail <>0 then
        Info:=Info+'N'
      else
        Info:=Info+'∙';
      if WhatRcvd and imArcMail <>0 then
        Info:=Info+'A'
      else
        Info:=Info+'∙';
      if WhatRcvd and imTic <>0 then
        Info:=Info+'T'
      else
        Info:=Info+'∙';
      if FmaskBits <>0 then
        Info:=Info+'F'
      else
        Info:=Info+'∙';
    end;
    if SessOk then
      Info:=Info+'√'
    else
      Info:=Info+'·';
    DateCall:=LastSession;
  end;

  Inc(Statistic.AllSend,SendByte);
  Inc(Statistic.AllRecv,ReceiveByte);

  WriteHist;
  ShowHistory;

  with SessionControl^ do begin
   sc:=ProcessInfo[procAfterSess].procBit;
   if WhatRcvd and imNetMail <>0 then
     sc:=sc or ProcessInfo[procNetMail].procBit;
   if WhatRcvd and imArcMail <>0 then
     sc:=sc or ProcessInfo[procArcMail].procBit;
   if WhatRcvd and imTic <>0 then
     sc:=sc or ProcessInfo[procTic].procBit;
   if FmaskBits <>0 then
     sc:=sc or ProcessInfo[procFile].procBit;
   ProcMan_Req4act(procNetMail,sc,'',0,true);
  end;
  CloseLogFile;
end;

procedure Hydra_Session;
var
  Result_Ses   : word;
  Ses_Flag     : boolean;
  x            : byte;
  i            : byte;
  sessFlg      : file of tAddress;
begin
  with SessionControl^ do begin
    SecondBatch:=false;
    ProtocolType:=pt_Hydra;
  end;

  Ses_Flag:=false;
  LastSession:=Date_+' '+ShortTime;
  LastConnect_Phone:=EMSI_Dat_R^.Phone_Number;
  CreateSemaphore(pCfgRec^.Flags_Dir+'in-sess.sf');
  Assign(SessFlg,pCfgRec^.Flags_Dir+'in-sess.sf'+Long2Str(Task));
  Rewrite(SessFlg);
  for i:=1 to EMSI_DAT_R^.AddressCount do
    Write(Sessflg,EMSI_DAT_R^.System_Address_List[i]);
  Close(SessFlg);

  LogWrite(imMethod,'Hydra',ld_All);
  ShowSessTime;
  Hydra_Init(Connect_Speed,caller);
  HydraFace;
  HydraMode:=True;

  if H_Session(caller) then begin
    EndFirstBatch;
    if H_Session(caller) then
      Ses_Flag:=true;
  end;

  Hydra_DeInit;
  UnderSession(Ses_Flag,false);
  HydraMode:=False;
  exit;
end;

procedure Mail_Session;

var
  Result_Ses   : word;
  Ses_Flag     : boolean;
  x            : byte;
  i            : byte;
  sessFlg      : file of tAddress;
begin
  with SessionControl^ do begin
    SecondBatch:=true;
    ProtocolType:=pt_ZModem;
  end;

  Z_MakeCRC32:=true;
  LastSession:=Date_+' '+ShortTime;
  LastConnect_Phone:=EMSI_Dat_R^.Phone_Number;
  CreateSemaphore(pCfgRec^.Flags_Dir+'in-sess.sf');
  Assign(SessFlg,pCfgRec^.Flags_Dir+'in-sess.sf'+Long2Str(Task));
   Rewrite(SessFlg);
   for i:=1 to EMSI_DAT_R^.AddressCount do
     Write(Sessflg,EMSI_DAT_R^.System_Address_List[i]);
   Close(SessFlg);
  if ioresult<>0 then {clear};

  If (ZModemSupp) and (ZModemSize<>0) then
   LogWrite(imNonStandartSup,'',ld_All) else
   ZModemSize:=2;

  If (Pos('ZAP',EMSI_DAT_R^.Compatibility_Codes)=0) then begin
    if Pos('ZMO',EMSI_DAT_R^.Compatibility_Codes)<>0 then begin
      ZModemSize:=0;
    end else begin
      LogWrite(emRemoteNotComp,'',ld_All);
      exit;
    end;
  end;
  Session_Type:=ZModemSize;

  LogWrite(imMethod,ZMod_Type[Session_Type],ld_All);
  ShowSessTime;

  ZModemBegin(Connect_Speed,ZModemSize);
  SessionFace;

  if caller then begin
    If not SendAllFiles then begin     { Сначала посылаем все что есть }
      UnderSession(false,true);
      exit;
    end;

    If not ReceiveAllFiles then begin  { Тепеpь получаем файлы;) }
      UnderSession(false,true);
      exit;
    end;

    If not SessionControl^.FreQIn then
      WaitZFin:=false;
    If SessionControl^.FreqIn then
      If not SendAllFiles then begin
        UnderSession(false,true);
        exit;
    end;

  end else begin
     { Мы тепеpь отвечаем }
     { Сначала пpинимаем все что есть }
  { -------------------------------------------------------------- }
     If not ReceiveAllFiles then begin
       UnderSession(false,true);
       exit;
     end;

    { Тепеpь посылаем файлы;) }
    { Попpавка на ожидание подтвеpждения ZFin }
     If not SessionControl^.FreQOut then
       WaitZFin:=false;
     If not SendAllFiles then begin
       UnderSession(false,true);
       exit;
     end;

     If SessionControl^.FreQOut then
       If not ReceiveAllFiles then begin
         UnderSession(false,true);
         exit;
       end;
  end;
  UnderSession(true,true);
end;

end.