Unit sf_init;

interface
procedure ReadFullCfg;
procedure ReDrawScreen;
Procedure Init;
Procedure Done;
Procedure Run;

Const
  LiveByte  : byte = 0;
  LiveArray : array[0..15] of char = ('#','','*','+','-','ù','ú',' ',
                                      ' ','ú','ù','-','+','*','','#');

  TimeFlag  : boolean = false;
  LampFlag  : boolean = false;
  HeartMode : boolean = true;
  HeartIcon : byte = 1;

{$I heart.inc}

implementation
Uses TPCRT,
{$IFNDEF bVirtual}
     Overlay,
     OverXMS,
{$ENDIF}
     DOS,
     StatView,
     aTime,
     edln,
     Face,
     FileMan,
     TPWindow,
     TString_,
     TPAsciiZ,
     SFInclud,
     ExitPrg,
     Code,
     Config,
     Cfg_Read,
     keyread,
     ScrnSS,
     ADLang,
     Answ,
     keyb,
     flags,
     Date,
     WriteLog,
     Error,
     Eventman,
     Em_Cpl,
     Modem,
     MsgXs,
     A002Xs,
     RelTQ,
     Fos_Lib;

  {------------------------  Full Initialization  ------------------------}

{$S-}
procedure TimeAdd; far;
begin
  if TimeFlag then exit else
     TimeFlag:=true;

  If OldSampleTime = 0 then begin
     OldSampleTime:=SampleTime;
     If LastKeyPressed<$7FFFFFF then
        Inc(LastKeyPressed);
     Inc(TimeCounter);
  end else begin
     If DontInc then begin
       Inc(LastKeyPressed);
       Inc(TimeCounter);
     end else begin
       If (SampleTime<OldSampleTime) and (SampleTime+1310400<OldSampleTime) then begin
         Inc(LastKeyPressed);
         Inc(TimeCounter);
       end else begin
         Inc(LastKeyPressed,SampleTime-OldSampleTime);
         Inc(TimeCounter,SampleTime-OldSampleTime);
       end;
     end;
     OldSampleTime:=SampleTime;
  end;

  if (pCfgRec^.SysFlags and mscPollKbd) <> 0 then
    Inc(IfKeyPress);

  If HeartMode and (Not ScreenSave) then begin
   if HeartIcon<>0 then begin
     if HeartIcon =1 then
       FastWrite(LiveArray[LiveByte],ScreenHeight,80,ColorLamp+$0E)
     else begin
       FastWrite(#255,ScreenHeight,80,ColorLamp+$0E);
       if HeartIcon = 2 then
         ChangeChar(255,@font[LiveByte,0])
       else
         ChangeChar(255,@font1[LiveByte,0]);
     end;
     Inc(LiveByte);
     If LiveByte =16 then livebyte:=0
   end;
  end;
  TimeFlag:=false;
end;
{$S+}

{$S-}
procedure NewInt1CVec; far;
begin
  if LampFlag then exit else
     LampFlag:=true;
  if (not pCfgRec^.Modem_Lamps) and (not pCfgRec^.HardWare_Ring) then exit;

  Lamps := GetXtendPortStat;

{*** Drawing Lamps ***}
  If (pCfgRec^.Modem_Lamps) and (not ScreenSave) then begin
    If (Lamps and $1) <> 0 then
     FastWrite('DTR',ScreenHeight,47,ColorLamp+$0F)
    else
     FastWrite('DTR',ScreenHeight,47,ColorLamp);
    If (Lamps and $2) <> 0 then
     FastWrite('RTS',ScreenHeight,51,ColorLamp+$0F)
    else
     FastWrite('RTS',ScreenHeight,51,ColorLamp);
    If (Lamps and $4) <> 0 then
     FastWrite('RxD',ScreenHeight,26,ColorLamp+$0A)
    else
     FastWrite('RxD',ScreenHeight,26,ColorLamp);
    If (Lamps and $8) <> 0 then
     FastWrite('OVR',ScreenHeight,17,ColorLamp+$0C)
    else
     FastWrite('OVR',ScreenHeight,17,ColorLamp);
    If (Lamps and $10) <> 0 then
     FastWrite('PRT',ScreenHeight,13,ColorLamp+$0C)
    else
     FastWrite('PRT',ScreenHeight,13,ColorLamp);
    If (Lamps and $20) <> 0 then
     FastWrite('SYN',ScreenHeight, 9,ColorLamp+$0C)
    else
     FastWrite('SYN',ScreenHeight, 9,ColorLamp);
    If (Lamps and $40) <> 0 then
     FastWrite('BRK',ScreenHeight, 5,ColorLamp+$0C)
    else
     FastWrite('BRK',ScreenHeight, 5,ColorLamp);
    If (Lamps and $80) <> 0 then
     FastWrite('TxD',ScreenHeight,22,ColorLamp+$0A)
    else
     FastWrite('TxD',ScreenHeight,22,ColorLamp);
    If (Lamps and $100) <> 0 then
     FastWrite('CTS',ScreenHeight,43,ColorLamp+$0F)
    else
     FastWrite('CTS',ScreenHeight,43,ColorLamp);
    If (Lamps and $200) <> 0 then
     FastWrite('DSR',ScreenHeight,39,ColorLamp+$0E)
    else
     FastWrite('DSR',ScreenHeight,39,ColorLamp);
    If (Lamps and $400) <> 0 then
     FastWrite('RNG',ScreenHeight,34,ColorLamp+$0B)
    else
     FastWrite('RNG',ScreenHeight,34,ColorLamp);
    If (Lamps and $800) <> 0 then
     FastWrite('DCD',ScreenHeight,30,ColorLamp+$0E)
    else
     FastWrite('DCD',ScreenHeight,30,ColorLamp);
  end;
{*** End Drawing Lamps ***}

  If (Lamps and $400) <> 0 then begin { Hard Ring }
    If (TimeCounter<LastRng) or (TimeCounter>LastRng+9) then
      HardRing:=true;
    LastRng:=TimeCounter;
  end;

  HardDCD:=(Lamps and $800) <> 0;
  LampFlag:=false;
end;
{$S+}

procedure ReDrawScreen;
begin
  TextAttr:=$07;
  ClrScr;
  Draw_Face;
  ShowHistory;
  Check4lamps;
end;

procedure Init;
var i       : byte;
    tmpStr  : String;
    tA      : tAddress;
    flagfile: file of tAddress;
    Address : tAddress;
    pPath   : PathStr;

begin
 SetBlink(pCfgRec^.SysFlags and clrBlinking <>0);
 If pCfgRec^.SysFlags and clrBlinking <>0 then
   ColorLamp := $70
 else
   ColorLamp := $80;

 for i:=1 to MaxScrLines-11 do begin
   LogBuffer^[i]:='';
   ModBuffer^[i]:='';
 end;
 for i:=1 to 10 do
   FileLogBuffer^[i]:='';

 GetDate_Time;
 HiddenCursor;
 InitCom;
 Draw_Face;
 InitInt9;
 CreateRepESR(TimeHandl, @TimeAdd,0);
 TimeAES:=true;
 CreateRepESR(LampsHandl, @NewInt1CVec,longInt(pcfgRec^.Refresh_Lamps)-1);
 LampsAES:=true;
 OpenLogFile;
 WriteLogHead;

 if sLibInfo.wDrvType<$10 then begin
   LogWrite(imFossInfo,'',ld_All);
   LogWrite(0,'    '+Asc2Str(AsciiZ(sFossInfo.pDrvName^)),ld_All);
   LogWrite(imFossRevision,Long2Str(sFossInfo.bDrvRev),ld_All);
   If sLibInfo.cMaxFossFunc<>0 then
     LogWrite(imMaxFunctions,Long2Str(sLibInfo.cMaxFossFunc),ld_All);
   LogWrite(imBuffersInfo,Long2Str(sFossInfo.wRxBuffSz)+#3+
                          Long2Str(sFossInfo.wTxBuffSz),ld_All);
 end else begin
   LogWrite(0,'(-) '+Copy(Asc2Str(AsciiZ(sLLCLInfo.pDrvName^)),1,47),ld_All);
   LogWrite(0,'    '+Copy(Asc2Str(AsciiZ(sLLCLInfo.pDrvName^)),48,255),ld_All);
   If sLibInfo.cMaxFossFunc<>0 then
     LogWrite(imMaxFunctions,Long2Str(sLibInfo.cMaxFossFunc),ld_All);
   LogWrite(imBuffersInfo,Long2Str(sLLCLInfo.wRxBuffSz)+#3+
                          Long2Str(sLLCLInfo.wTxBuffSz),ld_All);
 end;

 Case sCPUXID.bXID of
      0    : LogWrite(0,'(þ) 8086/8088 CPU detected',ld_All);
      1..4 : LogWrite(0,'(þ) 80'+Long2Str(sCPUXID.bXID)+'86 CPU detected',ld_All);
      5    : LogWrite(0,'(þ) Pentium detected',ld_All);
 end;
 If sCPUXID.bLength > 2 then
    LogWrite(0,'    Model: '+Long2Str(sCPUXID.bModel)+
               ', Step: '+Long2Str(sCPUXID.bStep)+
               ', Vendor: '+sCPUXID.aVendor,ld_All);


 LogWrite(imDOSInfo,NameMultiTasker,ld_All);
 If pCfgRec^.RTQ_Method <> tRTQ(rtqDEF) then begin
   LogWrite(imChangeRelease,'',ld_Screen);
   Case pCfgRec^.RTQ_Method of
    tRTQ(rtqI28) : ChangeOsWord(mtUndefined);
    tRTQ(rtq2F)  : ChangeOsWord(mtWindows);
    tRTQ(rtqIPX) : ChangeOsWord(mtIPX);
    tRTQ(rtqHLT) : ChangeOsWord(mtHLT);
   end;
 end;

 If pCfgRec^.Time_Quant<>0 then begin
   LogWrite(imChangeTimeQ,Long2Str(pCfgRec^.Time_Quant),ld_Screen);
   ChangeTQ(pCfgRec^.Time_Quant);
 end else
   LogWrite(imChangeTimeQ,'default',ld_Screen);
 LogWrite(0,'ÄÄÄÄÄÄ',ld_All);

 If CheckSemaphore(pCfgRec^.Flags_Dir+'sf-mail.wr') then begin
   pCfgRec^.SysFlags:=pCfgRec^.SysFlags or mscCrashRecovery;
   LogWrite(imCrashRecovery,'',ld_All);
   If CheckSemaphore(pCfgRec^.Flags_Dir+'sf-mail.xt') then begin
     LogWrite(imRunFromExternal,'',ld_All);
     EraseSemaphore(pCfgRec^.Flags_Dir+'sf-mail.xt');
   end;
   If CheckSemaphore(pCfgRec^.Flags_Dir+'in-sess.sf') then begin
     Assign(FlagFile,pCfgRec^.Flags_Dir+'in-sess.sf'+Copy(HexB(Task),2,1));
    {$I-}
     if IOResult<>0 then ;
     Reset(FlagFile);
     EMSI_Dat_R^.AddressCount:=0;
     While not Eof(FlagFile) do begin
       Inc(EMSI_Dat_R^.AddressCount);
       Read(FlagFile,EMSI_Dat_R^.System_Address_List[EMSI_Dat_R^.AddressCount]);
     end;
     Close(FlagFile);
     if IOResult<>0 then ;
    {$I+}
     LogWrite(imCrashWith,Addr2Str(EMSI_Dat_R^.System_Address_List[1],
              EMSI_Dat_R^.System_Address_List[1].Point<>0),ld_All);
     for i:=1 to EMSI_Dat_R^.AddressCount do begin
       Path4addr(true,EMSI_Dat_R^.System_Address_List[i],pPath);
       DeleteFlag(pPath+'.bsy');
       DeleteFlag(pPath+'.csy');
     end;
     EraseSemaphore(pCfgRec^.Flags_Dir+'in-sess.sf');
   end;
 end else
   CreateSemaphore(pCfgRec^.Flags_Dir+'sf-mail.wr');

  { ˆ­¨æ¨ «¨§ æ¨ï msgXs ¨ A002Xs }
 if not InitNodeIdx then Halt(231);
 if not InitEventMan then Halt(230);
 if length(pCfgRec^.FaxInbound)<>0 then
   MkAllDir(pCfgRec^.FaxInbound);

 If pCfgRec^.SysFlags and mscCrashRecovery <>0 then
   RepackMail('all');

 LoadHistoryList;
 Caller:=false;
 InitModem;
 OpenHistory;
 ShowHistory;
 IfKeyPress:=10;
 HardRing:=false;
end;

Procedure Done;
begin
SaveHistoryList;
ShowTime;
if not CloseEventMan then
  LogWrite(emCantCloseEM,'',ld_All);
DisposeNodeIdx;
Language_Done;
end;

procedure ReadFullCfg;
  Var
    cfgFile : string;
    s       : string;
    i       : byte;
    w       : word;
    f       : file of key;
    oldFMode: byte;
begin
 cfgFile:= 'sf-mail.cfg';
 for i:=1 to ParamCount do begin
  s:=ParamStr(i);
  if ((Length(s) >2) or (s[2]='f') or (s[2]='3')) and (s[1] in ['-','/']) then
    case LoCase(s[2]) of
     'c': CfgFile:=copy(s,3,127);
     'n': if Str2word(copy(s,3,1),w) and (w <16) then
            Task:=w;
     'h': if Str2word(copy(s,3,1),w) and (w <4) then
            HeartIcon:=w;
     'f': IgnoreFreeSpace:=true;
     '3': Init30Mode:=true;
    end;
 end;
 if not Read_Config(cfgFile) then
   ErrorMessage('Can''t find Config file',220);
 SetBlink(false);
 if Init30Mode then begin
   Init30Lines;
   ReInitCrt;
 end;
 KeyPresent:=false;

 {$I-}
  filemode:=$20;
  Assign(f,'sf-mail.key');
  Reset(f);
  filemode:=$2;
  Read(f,KeyDat);
  Close(f);
  if IOResult<>0 then begin
    SerialNo:='Noncommercial';
    WriteLn('Now you can REGISTER your version of SF-Mail!');
    Pause(18);
  end else
    KeyPresent:=true;
 {$I+}
 ReadSn;
 If CheckSN then begin
   WriteLn('Registered to: '+pCfgRec^.SySop);
   WriteLn('Serial Number: '+SerialNo);
 end;
end;

procedure Run;
Var
  Loaded : boolean;
begin
  Loaded     := false;
  SaveBreak  := CheckBreak;
  CheckBreak := false;
  GetCBreak(SaveDosBreak);
  SetCBreak(false);

    New(LogBuffer);
    New(ModBuffer);
    New(FileLogBuffer);
    New(SesBuffer);
    New(EMSI_DAT_R);

  OldExitProc:=ExitProc;
  ExitProc:=@MyExit;

  Shadow:=true;
  ShadowAttr:=$08;
  TextAttr:=$07;

 {Init Languege}
 if not Language_Init('sf-mail.lng') then
   ErrorMessage('Error exit: sf-mail.lng error',225);

 ReadFullCfg;
{$IFNDEF bVirtual}
 ExitProc:=OldExitProc;
 OvrClearBuf;
 if pCfgRec^.SysFlags and OvrXMS <>0 then begin
   OvrInitXMS;
   if OvrResult=ovrOk then begin
     WriteLn('Loading overlay in XMS');
     loaded:=true;
   end;
 end;
 if (not loaded) and (pCfgRec^.SysFlags and OvrEMS <>0) then begin
   OvrInitEMS;
   if OvrResult=ovrOk then begin
     WriteLn('Loading overlay in EMS');
     Loaded:=true;
   end;
 end;
 if (not Loaded) then WriteLn('Leaving overlay on disk');
 OldExitProc:=ExitProc;
 ExitProc:=@MyExit;
{$ENDIF}

Init;
Wait;
Done;
MyExit;
end;

end.
