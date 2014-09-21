{$V-,O+,F+,I-}
Unit terminal;

interface

procedure RunTerminal;
function Dial(AskMode:boolean;OutTime:LongInt):boolean;

Const
  CursorX    : byte = 1;
  CursorY    : byte = 1;
  DoorWayMode: boolean= false;
  KbdMapMode : boolean= false;
  LogingMode : boolean= false;
  LS         : string='';

implementation

uses
   A002xs,
   ADir,
   ATime,
   Config,
   Crc_All,
   Date,
   Dos,
   EdLn,
   Fos_Lib,
   Keyb,
   MsgXs,
   NES,
   Pwd_Xs,
   RelTQ,
   SFInclud,
   SF_snd,
   SubstMan,
   TPCRT,
   TPWindow,
   TString_,
   WriteLog,
   Modem,
   Show,
   ZModem;

Var
  QuitTerminal : boolean;
  ch           : char;
  RByte        : integer;
  AvState      : byte;
  mAvState     : byte;
  TempChar     : char;
  TempByte     : byte;
  TempCounter  : byte;
  TempStr      : string;
  ConnStr      : string;
  TempConnect  : string;
  i,k          : byte;
  ti           : integer;
  n            : word;
  TempInt      : integer;
  s1           : String;
  s2           : String;
  HiBit        : boolean;
  HiBack       : boolean;
  Timer        : longInt;
  PTermScreen  : Pointer;
  LogingFile   : text;
  KbdMapping   : array[1..512] of string[20];

procedure HelpTerminal;
  Var
    CH      : char;

begin
  HiddenCursor;
  MakeWindow(PWin,20,ScreenHeight div 2 - 7,60,ScreenHeight div 2 + 8,true,true,true,
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Header],
             '╡ Help ╞');
  DisplayWindow(Pwin);
  ClrScr;
  FastWriteWindow('Alt - Q  -  Exit from terminal',2,4,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Alt - D  -  Dialing phone number',3,4,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('node address',4,16,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('# phone number',5,16,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('> Full dialing string',6,16,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('PgUp  -  Send File(s)',7,7,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('PgDn  -  Receive File(s)',8,7,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Receiving files always',9,16,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('in inbound directory',10,16,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Alt - =  -  Switch DoorWayMode',11,4,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Alt - K  -  Keyboard Map Mode',12,4,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Alt - L  -  Logging Receiving Data',13,4,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('press any key..',15,22,pcfgRec^.SfMailColors[Session_File]);
  repeat
   ch:=#0;
   if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
      if keypressed then begin
         ch:=readkey;
         if ch=#0 then ch:=ReadKey;
      end;
   end else
      IfKeyPress:=0;
   ReleaseTQ;
  until CH<>#0;
  KillWindow(PWin);
  NormalCursor;
end;

procedure OpenLogingFile;
begin
  if not InputLine('Enter file name for logging',LS,
     ILColors[1],ILColors[1],ILColors[2],ILColors[1],80,60,false) then exit;
  Assign(LogingFile,LS);
  Append(LogingFile);
  If IOResult<>0 then Rewrite(LogingFile);
  If IOResult<>0 then begin
    WriteLn(#10#13'Can''t open '+LS);
    exit;
  end;
  LogingMode:=true;
  If pCfgRec^.SysFlags and clrBlinking <> 0 then
    FastWrite('L',ScreenHeight,2,$7F) else
    FastWrite('L',ScreenHeight,2,$8F);
end;

procedure CloseLogingFile;
begin
  if not LogingMode then exit;
  Close(LogingFile);
  if IOResult<>0 then {clear};
  LogingMode:=false;
  If pCfgRec^.SysFlags and clrBlinking <> 0 then
    FastWrite(' ',ScreenHeight,2,$7F) else
    FastWrite(' ',ScreenHeight,2,$8F);
end;

procedure AskNode;
var
  A   : tAddress;
begin
  if InputLine('NodeInfo',TempStr,
     ILColors[1],ILColors[1],ILColors[2],ILColors[1],25,25,true) then begin
    SetDefaultAddr(pCfgRec^.MyAddress[1],false);
    if not xStr2addr(TempStr,A) then
      Writeln(#10#13'Invalid address: '+tempStr)
    else begin
      HiddenCursor;
      NodeShow(A,CheckPassword(A));
      NormalCursor;
    end;
  end;
end;

procedure AnalisCD(Connect_MSG:String);
var c: byte;
begin
  If (ti<>WaitCarrierDef+5) and (Pos(Connect_MSG,TempConnect)<>0) then begin
    Delete(TempConnect,length(TempConnect)-1,2);
    If CanHydra then
      for c:=1 to NoHydCount do
      If Pos(NoHydra[c],TempConnect)<>0 then CanHydra:=false;
    KillWindow(PWin);
    if TermMode then
      Writeln(#10#13+TempConnect)
    else
      LogWrite(0,'    '+TempConnect,ld_All);
    LastConnect:=TempConnect;
    If Connect_Msg = pCfgRec^.Connect_Str then begin
      Delete(TempConnect,1,
             Pos(Connect_MSG,TempConnect)+length(Connect_MSG)-1);
      Conn_Speed:=TakeFirstLong(TempConnect);
      If Conn_Speed=0 then Conn_Speed:=2400;
      Connect_Speed:=Conn_Speed;
      If CrashMode then begin
        If TempConnect[0]<>#0 then
          ModemLogScreen('Connect '+Long2Str(Connect_Speed))
        else
          ModemLogScreen('Connect 300');
      end;
    end;
    ti:=WaitCarrierDef+5;
  end;
end;

function WaitPause(t : longInt):boolean;
var
   OldTime      : LongInt;
   ch           : char;
begin
  OldTime:=TimeCounter;
  WaitPause:=false;
  while TimeCounter<OldTime+t do
  if TimeCounter<OldTime then exit
  else begin
   if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
     if keypressed then begin
       ch:=readkey;
       case ch of
         #27 : begin
                WriteString(#27);
                WaitPause:=true;
                exit;
         end;
         #0  : ch:=ReadKey;
       end;
     end else
     IfKeyPress:=0;
   end;
   if (mtOsVer=mtOS_2) or (mtOsVer=mtDoubleDos) or (mtOsVer=mtWinNT) or
      (mtOsVer=mtPSMOS) then ReleaseTQ;
  end;
end;

function Dial(AskMode:boolean;OutTime:LongInt):boolean;
Var
  phone      : string;
  dAddr      : tAddress;
  RByte      : integer;
  FromList   : boolean;
begin
  Dial:=false;
  If AskMode then
   if not InputLine('Input address for dial',s2,
      ILColors[1],ILColors[1],ILColors[2],ILColors[1],100,60,true) then
     exit;
  Phone:='';
  FromList:=false;
  Case s2[1] of
   '#' : begin
          phone:=pCfgRec^.Dial_Prefix+
          +copy(s2,2,length(s2))+
          pCfgRec^.Dial_Suffix;
          WaitCarrierDef:=pCfgRec^.WaitCarrierOut;
   end;
   '>' : begin
          phone:=copy(s2,2,length(s2));
          If Phone[byte(Phone[0])] <> '|' then
           Phone:=Phone+'|';
          WaitCarrierDef:=pCfgRec^.WaitCarrierOut;
   end;
  else
   FromList:=true;
   SetDefaultAddr(pCfgRec^.MyAddress[1],false);
   if not xStr2addr(ExtractWord(1,s2,['#']),dAddr) then begin
     If TermMode then
      Writeln(#10#13'Invalid address: '+s2)
     else LogWrite(emInvalidAddr,s2,ld_Screen);
     exit;
   end;
   if not ReOpenNodeIdx then begin
     If TermMode then
      Writeln(#10#13'Can''t open Nodelist Index')
     else
      LogWrite(emCantAccessIdx,'',ld_Screen);
     exit;
   end;
   Rbyte:=0;
   if WordCount(s2,['#'])=2 then
     RByte:=TakeFirstLong(ExtractWord(2,S2,['#']));
   if not FindNodeEntry(false,dAddr.Zone,dAddr.Net,dAddr.Node,dAddr.Point) then begin
     if not SubstNodeEntry(dAddr,RByte) then begin
       CloseNodeIdx;
       If TermMode then
        Writeln(#10#13'Can''t find Node/Point')
       else
        LogWrite(wmCantFindNode,'',ld_Screen);
       exit;
     end;
   end else SubstNodeEntry(dAddr,RByte);
   CloseNodeIdx;
   if NodeEntry.NumLns<RByte then begin
     If TermMode then
       Writeln(#10#13'Can''t find Node/Point')
     else
       LogWrite(wmCantFindNode,'',ld_Screen);
     exit;
   end;
   CrashLine:=RByte;
   if (NodeEntry.Telephone =NoPhone) then begin
     If TermMode then
      Writeln(#10#13'UnPublished Node/Point')
     else
      LogWrite(wmUnPublishNode,'',ld_Screen);
     exit;
   end;
   Phone:='';
   with NodeEntry do begin
     If Wait=0 then
      WaitCarrierDef:=pCfgRec^.WaitCarrierOut
     else
      WaitCarrierDef:=Wait;
     if length(Dial)<>0 then
      Phone:=Dial+Telephone+pCfgRec^.Dial_Suffix
     else begin
      if (Capability and (NodeFlag[HST]) <> 0) and (pCfgRec^.Hst_Prefix[0]<>#0) then
         Phone:=pCfgRec^.Hst_Prefix+Telephone+pCfgRec^.Dial_Suffix;
      if (Capability and (NodeFlag[H16]) <> 0) and (pCfgRec^.H16_Prefix[0]<>#0) then
         Phone:=pCfgRec^.H16_Prefix+Telephone+pCfgRec^.Dial_Suffix;
      if (Capability and (NodeFlag[H14]) <> 0) and (pCfgRec^.H14_Prefix[0]<>#0) then
         Phone:=pCfgRec^.H14_Prefix+Telephone+pCfgRec^.Dial_Suffix;
      if (Capability and (NodeFlag[ZYX]) <> 0) and (pCfgRec^.ZYX_Prefix[0]<>#0) then
         Phone:=pCfgRec^.ZYX_Prefix+Telephone+pCfgRec^.Dial_Suffix;
      if (Capability and (NodeFlag[PEP]) <> 0) and (pCfgRec^.PEP_Prefix[0]<>#0) then
         Phone:=pCfgRec^.PEP_Prefix+Telephone+pCfgRec^.Dial_Suffix;
      if Phone[0]=#0 then
         Phone:=pCfgRec^.Dial_Prefix+Telephone+pCfgRec^.Dial_Suffix;
     end;
   end;
  end; {Case}
  S1:=Phone;
  Dec(S1[0]);
  If CrashMode then LogWrite(imCrashPoll,S1,ld_All);
  if CrashMode then S1:=' Crash poll ' else S1:=' Calling ';
  if CrashMode then RByte:=15 else RByte:=25;
  MakeWindow(PWin,RByte,ScreenHeight div 2 - 3,RByte+30,ScreenHeight div 2 + 3,true,true,true,
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Header],
             S1);
  DisplayWindow(Pwin);
  ClrScr;
  KillCD;
  repeat
   Conn_Speed:=2400;
   WriteString(Phone);
   TempConnect:='';
   ti:=0;
   If FromList then begin
     If length(NodeEntry.Name) > 0 then
        FastCenter(Copy(NodeEntry.Name,1,27),2,pCfgRec^.SfMailColors[Session_Info])
     else
        FastCenter('* Unlisted System *',2,pCfgRec^.SfMailColors[Session_Info]);
     FastCenter(copy(phone,1,27),3,pCfgRec^.SfMailColors[Session_File]);
   end else
     FastCenter(copy(phone,1,27),2,pCfgRec^.SfMailColors[Session_File]);
   GetDate_Time;
   ChangeTime:=0;
   repeat
     If CrashMode then ShowTime else GetDate_Time;
     if ChangeTime<>0 then begin
        while ChangeTime<>0 do begin
          Inc(ti,1);
          Dec(ChangeTime);
          ShowDialTime(WaitCarrierDef-ti);
          if ti>WaitCarrierDef then
            ChangeTime:=0;
        end;
     end;
     if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
       if keypressed then begin
         ch:=readkey;
         case ch of
          #32 : begin
                 WriteString(#27);
                 ti:=WaitCarrierDef+3;
                 PulseDtr(2);
                 Delay(10);
                 ChangeDTR(1);
          end;
          #27 : begin
                 WriteString(#27);
                 ti:=WaitCarrierDef+6;
                 PulseDtr(2);
                 Delay(10);
                 ChangeDTR(1);
          end;
          #45     : Inc(ti);
          #43     : Dec(ti);
          #0      : ch:=ReadKey;
         end;
       end else
        IfKeyPress:=0;
     end;
     RByte:=ReadChar;
     If RByte<>TERR_RXEMPTY then begin
       TempConnect:=TempConnect+Char(RByte);
       if Char(RByte)=#10 then begin
         If Pos(pCfgRec^.Modem_NoCarrier,TempConnect)<>0 then begin
           FastCenter(' No carrier',4,pCfgRec^.SfMailColors[Session_Info]);
           ClearRxQueue;
           ClearTxQueue;
           ti:=WaitCarrierDef+2;
           if CrashMode then ModemLogScreen('.No Carrier.');
         end;
         If Pos(pCfgRec^.Modem_NoAnswer,TempConnect)<>0 then begin
           FastCenter(' No Answer ',4,pCfgRec^.SfMailColors[Session_Info]);
           ClearRxQueue;
           ClearTxQueue;
           ti:=WaitCarrierDef+2;
           if CrashMode then ModemLogScreen('.No Answer.');
         end;
         If Pos(pCfgRec^.Modem_Busy,TempConnect)<>0 then begin
           FastCenter('    Busy   ',4,pCfgRec^.SfMailColors[Session_Info]);
           ClearRxQueue;
           ClearTxQueue;
           ti:=WaitCarrierDef+2;
           if CrashMode then ModemLogScreen('.Busy.');
         end;
         If Pos(pCfgRec^.Modem_NoDial,TempConnect)<>0 then begin
           FastCenter('No dialtone',4,pCfgRec^.SfMailColors[Session_Info]);
           ClearRxQueue;
           ClearTxQueue;
           ti:=WaitCarrierDef+2;
           if CrashMode then ModemLogScreen('.No DialTone.');
         end;
         AnalisCD(pCfgRec^.Connect_Str);
         TempConnect:='';
       end;
     end else begin
       ReleaseTQ;
       ReleaseTQ;
       ReleaseTQ;
     end;
     If ti=WaitCarrierDef+6 then begin
       Timer:=TimeCounter;
       KillCD;
       KillWindow(PWin);
       If TermMode then
        WriteLn(#10#13'Dialing canceled from keyboard')
       else
        LogWrite(imCrashCancel,'',ld_All);
       ClearRxQueue;
       ClearTxQueue;
       exit;
     end;
  until (ti>WaitCarrierDef) and (ti>0);
  If ti=WaitCarrierDef+5 then begin
    Dial:=true;
    PlaySound(tSndSessBegin);
    KillWindow(PWin);
    exit;
  end;
  If ti=WaitCarrierDef+1 then begin
    FastCenter(' TimeOut ',4,pCfgRec^.SfMailColors[Session_Info]);
    ClearRxQueue;
    ClearTxQueue;
    if CrashMode then ModemLogScreen('.TimeOut.');
  end;
  If ti=WaitCarrierDef+3 then begin
    FastCenter(' Recycle ',4,pCfgRec^.SfMailColors[Session_Info]);
    ClearRxQueue;
    ClearTxQueue;
  end;
  Timer:=TimeCounter;
  KillCD;
  If WaitPause(36) then begin
    KillWindow(PWin);
    If TermMode then
     WriteLn(#10#13'Dialing canceled from keyboard')
    else
     LogWrite(imCrashCancel,'',ld_All);
    ClearRxQueue;
    ClearTxQueue;
    exit;
  end;
  If (CrashMode) and (CurUnixTime>OutTime) then begin
    KillWindow(PWin);
    LogWrite(wmCrashTout,'',ld_All);
    ClearRxQueue;
    ClearTxQueue;
    exit;
  end;

  FastCenter('           ',4,pCfgRec^.SfMailColors[Session_Info]);
  ClearRxQueue;
  ClearTxQueue;
  until false;
end;

procedure SendFiles;
Var
  PaneType : tPaneMode;
begin
  if (GetPortStat and ST_DCD)=0 then exit;
  Receive := false;
  ZModemBegin(Conn_Speed,0);
  Z_MakeCRC32    := true;
  HiddenCursor;
  S1:='';
  if ScreenHeight >25 then
    PaneType:=pmMultiFull
  else
    PaneType:=pmMultiHalf;
  if InputLine('Input path',s1,
     ILColors[1],ILColors[1],ILColors[2],ILColors[1],100,60,false) then
     case Pane_Process(20,3,PaneType,ivOnlyName,s1) of
       pnOk: begin
           n:=InitSequence;
           if n <>0 then begin
             SessionFace;
             LogWrite(imSynchronize,'',ld_Session);
             if not Synchronize then begin
               PlaySound(tSndSessAbort);
               KillWindow(PWin);
               NormalCursor;
               ZModemEnd;
               Pane_Done;
               exit;
             end;
             while NextMarkedFile(s1) do
               Case ZModemSend(S1,JustFileName(S1),TermEndFile) of
                 ZOk : begin
                     If TransferError = 0 then
                       LogWrite(imZSendComplete,long2Str(Transfer_CPS)+#3+
                                      long2Str(Transfer_CPSpc),ld_SessAll)
                     else
                       LogWrite(imZSendComplErr,long2Str(Transfer_CPS)+#3+
                                      long2Str(Transfer_CPSpc)+#3+
                                      long2Str(TransferError),ld_SessAll);
                     end;
                 ZFileSkip : LogWrite(imZSkipping,JustFileName(S1),ld_SessAll);
               else
                 LogWrite(wmZSendFailed,
                          long2Str(TransferStart + TransferBytes)+#3+
                          long2Str(Transfer_CPS)+#3+
                          long2Str(Transfer_CPSpc),ld_SessAll);
                 PlaySound(tSndSessAbort);
                 KillWindow(PWin);
                 NormalCursor;
                 ZModemEnd;
                 Pane_Done;
                 exit;
               end;
             { Кpичим что все пеpедали }
             LogWrite(imZSCompleteMsg,'',ld_Session);
             SendZEnd;
             PlaySound(tSndSessOk);
             KillWindow(PWin);
             NormalCursor;
             ZModemEnd;
             Pane_Done;
             exit;
           end else begin
             s1:=GetCurrent;
             if s1[length(s1)]<>'\' then begin
               SessionFace;
               LogWrite(imSynchronize,'',ld_Session);
               if not Synchronize then begin
                 PlaySound(tSndSessAbort);
                 KillWindow(PWin);
                 NormalCursor;
                 ZModemEnd;
                 Pane_Done;
                 exit;
               end;
               Case ZModemSend(S1,JustFileName(S1),TermEndFile) of
                 ZOk : begin
                     If TransferError = 0 then
                       LogWrite(imZSendComplete,long2Str(Transfer_CPS)+#3+
                                long2Str(Transfer_CPSpc),ld_SessAll)
                     else
                       LogWrite(imZSendComplErr,long2Str(Transfer_CPS)+#3+
                                long2Str(Transfer_CPSpc)+#3+
                                long2Str(TransferError),ld_SessAll);
                     end;
                 ZFileSkip : LogWrite(imZSkipping,JustFileName(S1),ld_SessAll);
               else
                 LogWrite(wmZSendFailed,
                          long2Str(TransferStart + TransferBytes)+#3+
                          long2Str(Transfer_CPS)+#3+
                          long2Str(Transfer_CPSpc),ld_SessAll);
                 PlaySound(tSndSessAbort);
                 KillWindow(PWin);
                 NormalCursor;
                 ZModemEnd;
                 Pane_Done;
                 exit;
               end;
               { Кpичим что все пеpедали }
               LogWrite(imZSCompleteMsg,'',ld_Session);
               PlaySound(tSndSessOk);
               SendZEnd;
               KillWindow(PWin);
               NormalCursor;
               ZModemEnd;
               Pane_Done;
               exit;
             end;
           end;
         end;
      pnNotEnoughMem: Writeln(#10#13' ! Not enough memory');
           pnNoFiles: Writeln(#10#13' ! No files found');
       pnInvalidPath: Writeln(#10#13' ! Invalid path: '+s1);
     pnDriveNotReady: Writeln(#10#13' ! Drive not ready');
              pnQuit: Pane_Done;
     end;
  NormalCursor;
  ZModemEnd;
end;

procedure ReceiveFiles;
begin
  if (GetPortStat and ST_DCD)=0 then exit;
  ZModemBegin(Conn_Speed,0);
  Z_MakeCRC32    := true;
  HiddenCursor;
  SessionFace;
    Receive:=true;
    LogWrite(imSynchronize,'',ld_Session);
    If (ZModemReceive(pCfgRec^.InBound_Dir,
                      TermEndFile)<>0) and (ReceivingFile) then begin
      { Пpием накpылся;( }
      LogWrite(wmZRecvFailed,
               long2Str(TransferStart + TransferBytes)+#3+
               long2Str(Transfer_CPS)+#3+
               long2Str(Transfer_CPSpc),ld_SessAll);
      PlaySound(tSndSessAbort);
    end else begin
      LogWrite(imZRCompleteMsg,'',ld_Session);
      PlaySound(tSndSessOk);
    end;
  KillWindow(PWin);
  NormalCursor;
  ZModemEnd;
end;

procedure MapKbd(ch: word);
begin
  if kbdMapMode and (length(KbdMapping[ch])<>0) then begin
    WriteString(KbdMapping[ch]);
  end else begin
    if ch>$0FF then
      WriteChar(#0);
    WriteChar(char(lo(ch)));
  end;
end;

procedure KeybCheck;
begin
  { ----- Keyboard Section ----- }
  if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
    if keypressed then begin
      ch:=readkey;
      case ch of
      #0 : begin
            ch:=readkey;
            if DoorWayMode then begin
              if Ch=#131 then begin
                DoorWayMode:=false;
                If pCfgRec^.SysFlags and clrBlinking <> 0 then
                  FastWrite(' ',ScreenHeight,1,$7F) else
                  FastWrite(' ',ScreenHeight,1,$8F);
              end else begin
                MapKbd(word(ch)+256);
              end;
            end else begin
              case ch of
                #59 : helpTerminal;
                #16 : quitTerminal:=true;
                #81 : ReceiveFiles;
                #73 : SendFiles;
                #32 : begin
                       HiddenCursor;
                       Dial(true,0);
                       NormalCursor;
                      end;
                #49 : AskNode;
                #38 : if LogingMode then
                        CloseLogingFile
                      else
                        OpenLogingFile;
                #35 : begin
                       Timer:=TimeCounter;
                       DTRCheck;
                       KillCD;
                      end;
                #131: begin
                        DoorWayMode:=true;
                        If pCfgRec^.SysFlags and clrBlinking <> 0 then
                          FastWrite('D',ScreenHeight,1,$7F) else
                          FastWrite('D',ScreenHeight,1,$8F);
                      end;
                #37: begin
                        KbdMapMode:=not KbdMapMode;
                        if KbdMapMode then begin
                          If pCfgRec^.SysFlags and clrBlinking <> 0 then
                            FastWrite('K',ScreenHeight,3,$7F) else
                            FastWrite('K',ScreenHeight,3,$8F);
                        end else begin
                          If pCfgRec^.SysFlags and clrBlinking <> 0 then
                            FastWrite(' ',ScreenHeight,3,$7F) else
                            FastWrite(' ',ScreenHeight,3,$8F);
                        end;
                      end;
              else
                MapKbd(word(ch)+256);
              end;
            end;
           end;
      else
        MapKbd(word(ch));
      end;
    end else begin
      IfKeyPress:=0;
      ReleaseTQ;
    end;
  end;
  { ----- end of Keyboard Section ----- }
end;

procedure CheckConnect(CharByte : char);
begin
 if ConnStr[0]=#30 then Delete(ConnStr,1,10);
 ConnStr:=ConnStr+CharByte;
 If pos('**'#24'B00',ConnStr)<>0 then begin
   Write(CR);
   ClrEol;
   ReceiveFiles;
   ConnStr:='';
 end;
end;

procedure writeMultiAvatar(CharByte : char);
begin
    Case mAvState of
    0 : case CharByte of
        #0  : ;
        #12 : begin
              TextAttr:=$03;
              ClrScr;
              end;
        #25 : mAvState := 1;
        #22 : mAvState := 3;
        else
        Write(CharByte);
        end;
    1 : begin            { ^Y receive }
        TempChar:=CharByte;
        mAvState:=2;
        end;
    2 : begin
        for i:=1 to byte(CharByte) do
        Write(TempChar);
        mAvState:=0;
        end;
    3 : begin     { ^V receive }
        case CharByte of
        #1  : mAvState := 4;
        #2  : begin    { ^B High bit on}
              TextAttr := TextAttr or $80;
              mAvState := 0;
              end;
        #3  : begin    { ^C Move cursor one line UP}
              if WhereY > 1 then
              GotoXY(WhereX,WhereY-1);
              mAvState:=0;
              end;
        #4  : begin    { ^D Move cursor one line DOWN}
              if WhereY < 24 then
              GotoXY(WhereX,WhereY+1);
              mAvState:=0;
              end;
        #5  : begin    { ^E Move cursor one char LEFT}
              if WhereX >1 then
              GotoXY(WhereX-1,WhereY);
              mAvState:=0;
              end;
        #6  : begin    { ^F Move cursor one char RIGHT}
              if WhereX < 80 then
              GotoXY(WhereX+1,WhereY);
              mAvState:=0;
              end;
        #7  : begin    { ^G ClrEOL}
              ClrEol;
              mAvState:=0;
              end;
        #8  : mAvState := 5;  { ^H MoveCursor}
        else
        mAvState := 0;
        end;
        end;
    4 : begin     { ^A chang color }
        TextAttr:=byte(CharByte);
        mAvState := 0;
        end;
    5 : begin     { ^H Move Cursor row }
        TempByte:=byte(CharByte);
        mAvState := 6;
        end;
    6 : begin     { ^H Move Cursor col }
        GotoXY(byte(CharByte),TempByte);
        mAvState := 0;
        end;
    end;
end;

procedure writeAvatar(CharByte : char);
Var
  i        : byte;
  NextLine : boolean;
  SkipChar : char;
begin
    Case AvState of
    0 : case CharByte of
        #0  : ;
        #12 : begin
              TextAttr:=$03;
              ClrScr;
              end;
        #25 : AvState := 1;
        #22 : AvState := 3;
        #27 : AvState := 20; {ANSI sequanse}
        #9  : begin
                if (WhereX mod 8)=1 then GotoXY(WhereX+8,WhereY) else
                While ((WhereX mod 8)<>1) and (WhereX<80) do
                  GotoXY(WhereX+1,WhereY);
              {for i:=1 to 9-(WhereX mod 8) do
              Write(' ');}
              end;
        #8  : if WhereX>0 then begin
                GotoXY(WhereX-1,WhereY);
                Write(' ');
                GotoXY(WhereX-1,WhereY);
              end;
        else
          Write(CharByte);
        end;
    1 : begin            { ^Y receive }
        TempChar:=CharByte;
        AvState:=2;
        end;
    2 : begin
        for i:=1 to byte(CharByte) do
        Write(TempChar);
        AvState:=0;
        end;
    3 : begin     { ^V receive }
        case CharByte of
        #1  : AvState := 4;
        #2  : begin    { ^B High bit on}
              TextAttr := TextAttr or $80;
              AvState := 0;
              end;
        #3  : begin    { ^C Move cursor one line UP}
              if WhereY > 1 then
              GotoXY(WhereX,WhereY-1);
              AvState:=0;
              end;
        #4  : begin    { ^D Move cursor one line DOWN}
              if WhereY < 24 then
              GotoXY(WhereX,WhereY+1);
              AvState:=0;
              end;
        #5  : begin    { ^E Move cursor one char LEFT}
              if WhereX >1 then
              GotoXY(WhereX-1,WhereY);
              AvState:=0;
              end;
        #6  : begin    { ^F Move cursor one char RIGHT}
              if WhereX < 80 then
              GotoXY(WhereX+1,WhereY);
              AvState:=0;
              end;
        #7  : begin    { ^G ClrEOL}
              ClrEol;
              AvState:=0;
              end;
        #8  : AvState := 5;  { ^H MoveCursor}
        #25 : AvState := 7;  { ^Y Receive }
        else
        AvState := 0;
        end;
        end;
    4 : begin     { ^A chang color }
        TextAttr:=byte(CharByte);
        AvState := 0;
        end;
    5 : begin     { ^H Move Cursor row }
        TempByte:=byte(CharByte);
        AvState := 6;
        end;
    6 : begin     { ^H Move Cursor col }
        GotoXY(byte(CharByte),TempByte);
        AvState := 0;
        end;
    7 : begin
        TempByte:=byte(CharByte);
        TempCounter:=0;
        TempStr:='';
        AvState:=8;
        end;
    8 : begin
        Inc(TempCounter);
        TempStr:=TempStr+CharByte;
        If TempCounter=TempByte
           then
           AvState:=9;
        end;
    9 : begin
        For i :=1 to byte(CharByte) do
        For k :=1 to length(TempStr) do
        WriteMultiAvatar(TempStr[k]);
        AvState:=0;
        end;
    20: If CharByte <> '[' then begin
          Write(#27);
          WriteMultiAvatar(CharByte);
          AvState:=0;
        end else begin
          AvState:=21;
          TempStr:='';
        end;
    21: begin
        Case CharByte of
        'K' : begin
              ClrEol;
              AvState:=0;
              end;
        'S' : begin
              InsLine;
              AvState:=0;
              end;
 '0'..'9',';' : TempStr:=TempStr+CharByte;
    'j','J' : begin
              TextAttr:=$07;
              HiBit :=false;
              HiBack:=false;
              ClrScr;
              TempStr:='';
              AvState:=0;
              end;
    'n','N' : begin
              SendStr(#27+'['+long2Str(WhereX)+';'+long2Str(WhereY)+'R');
              AvState:=0;
              end;
    'a','A' : begin
              Val(TempStr,i,TempInt);
              if i=0 then i:=1;
              if WhereY > i then
                GotoXY(WhereX,WhereY-i)
              else
                GotoXY(WhereX,1);
              AvState:=0;
              TempStr:='';
              end;
    'b','B' : begin
              Val(TempStr,i,TempInt);
              if i=0 then i:=1;
              if WhereY < (ScreenHeight-i)-1 then
                GotoXY(WhereX,WhereY+i)
              else
                GotoXY(WhereX,ScreenHeight-1);
              AvState:=0;
              end;
    'c','C' : begin
              Val(TempStr,i,TempInt);
              if i=0 then i:=1;
              if WhereX < 80-i then
              GotoXY(WhereX+i,WhereY)
              else
              GotoXY(80,WhereY);
              AvState:=0;
              end;
    'd','D' : begin
              Val(TempStr,i,TempInt);
              if i=0 then i:=1;
              if WhereX > i then
              GotoXY(WhereX-i,WhereY)
              else
              GotoXY(1,WhereY);
              AvState:=0;
              end;
    'm','M' : begin
              if Length(TempStr)=0 then begin
                TextAttr:=$07;
                HiBit :=false;
                HiBack:=false;
              end;
              while Length(TempStr)<>0 do begin
                If Pos(';',TempStr)<>0 then begin
                  Val(copy(TempStr,1,pos(';',TempStr)-1),i,TempInt);
                  Delete(TempStr,1,pos(';',TempStr));
                end else begin
                  Val(TempStr,i,TempInt);
                  TempStr:='';
                end;
                Case i of
                   0 : begin
                         TextAttr:=$07;
                         HiBit :=false;
                         HiBack:=false;
                       end;
                   1 : HiBit :=true;
                   5 : HiBack:=true;
                   7 : begin
                        {TextAttr := (TextAttr shr 4) + (TextAttr shl 4);}
                        TextAttr := (TextAttr div 16) + (TextAttr mod 16)*16;
                       end;
                   8 : TextAttr := 0;
            30,32,35 : TextColor(i-30);
                  31 : TextColor(4);
                  33 : TextColor(6);
                  34 : TextColor(1);
                  36 : TextColor(3);
                  37 : TextColor(7);
            40,42,45 : TextBackGround(i-40);
                  41 : TextBackGround(4);
                  43 : TextBackGround(6);
                  44 : TextBackGround(1);
                  46 : TextBackGround(3);
                  47 : TextBackGround(7);
                end;
              end;
              If HiBit then
                 TextAttr:=TextAttr or  $08 else
                 TextAttr:=TextAttr and $f7;
              If HiBack then
                 TextAttr:=TextAttr or  $80 else
                 TextAttr:=TextAttr and $7f;
              AvState:=0;
            end;
        's' : begin
              CursorX:=WhereX;
              CursorY:=WhereY;
              AvState := 0;
              end;
        'u' : begin
              GotoXY(CursorX,CursorY);
              AvState:=0;
              end;
        'H' : If Length(TempStr)<>0 then begin
                if Pos(';',TempStr)<>0 then begin
                  Val(copy(TempStr,1,pos(';',TempStr)-1),i,TempInt);
                  Val(copy(TempStr,pos(';',TempStr)+1,2),k,TempInt);
                  GotoXY(k,i);
                  AvState:=0;
                end else begin
                  Val(TempStr,i,TempInt);
                  GotoXY(1,i);
                  AvState:=0;
                end;
              end else begin
                GotoXY(1,1);
                AvState:=0;
              end;
       else
              AvState:=0;
        end;
        end;
    end;
end;

procedure ModemCheck;
begin
  { ----- Modem Section ----- }
  RByte:=ReadChar;
  repeat
    If RByte<>TERR_RXEMPTY then begin
      If LogingMode then
        Write(LogingFile,Char(System.Lo(RByte)));
      WriteAvatar(Char(System.Lo(RByte)));
      CheckConnect(Char(System.Lo(RByte)));
    end else
      ReleaseTQ;
    RByte:=ReadChar;
  until RByte=TERR_RXEMPTY;
  { ----- end of Modem Section ----- }
end;

procedure readKbdMapping;
var
  i : word;
  s : string;
  s1 : string;
begin
  if IOResult<>0 then {clear};
  for i:=1 to 512 do
    KbdMapping[i]:='';
  Assign(LogingFile,'keyboard.map');
  reset(LogingFile);
  if IOResult<>0 then exit;
  repeat
    readln(LogingFile,s);
    s:=trim(s);
    if (s[1]<>';') and (length(s)>2) and (pos('=',s)<>0) then begin
      s1:=trim(copy(s,1,pos('=',s)-1));
      Val('$'+s1,i,TempInt);
      if i>$0FF then i:=(i shr 8) + 256;
        KbdMapping[i]:=copy(s,pos('=',s)+1,40);
    end;
  until Eof(LogingFile);
  close(LogingFile);
end;

procedure RunTerminal;
begin
  {----- Prepearing State -----}
  readKbdMapping;
  DoorWayMode :=false;
  KbdMapMode  :=false;
  LogingMode  :=false;
  quitTerminal:=false;
  AvState:=0;
  HiBit       :=false;
  HiBack      :=false;
  ConnStr:='';
  if not SaveWindow(1, 1, 80, ScreenHeight, true, PTermScreen) then begin
     exit;
  end;
  Window(1,1,80,ScreenHeight-1);
  TextAttr := $07;
  ClrScr;
  If pCfgRec^.SysFlags and clrBlinking <> 0 then begin
    If not (pCfgRec^.Modem_Lamps) then
     FastWrite(Center('Press F1 for Help',80),ScreenHeight,1,$7F) else
     FastWrite(LeftPad('│ Press F1 for Help ',80),ScreenHeight,1,$7F);
  end else begin
    If not (pCfgRec^.Modem_Lamps) then
     FastWrite(Center('Press F1 for Help',80),ScreenHeight,1,$8F) else
     FastWrite(LeftPad('│ Press F1 for Help ',80),ScreenHeight,1,$8F);
  end;
  NormalCursor;
  {----- end of Prepearing State -----}
  repeat
  KeybCheck;
  ModemCheck;
  ReleaseTQ;
  until quitTerminal;
  {----- begin of Restoring State -----}
  CloseLogingFile;
  HiddenCursor;
  TextAttr:=0;
  ClrScr;
  Window(1,1,80,ScreenHeight);
  TempClose;
  ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
  TextAttr:=$07;
  RestoreWindow(1, 1, 80, ScreenHeight, true, PTermScreen);
  {----- end of Restoring State -----}
end;

end.
