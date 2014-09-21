{$O+,F+}
unit Show;

interface
Uses
  Config,
  Dos;

Type
  TDispProg    = procedure;

tProtocol =
  (shZModem,
   shHydra,
   shFax);

tFaxState =
  (RemoteID,
   BeginPage,
   RecvPage,
   EndPage,
   EndFax);

Const
  TabShow   : TDispProg = nil;
  ZMod_Type : array [0..3] of String[6] = ('ZModem','ZedMin','ZedZap','ZedMax');
  Fax_Type  : array [FaxClass1..FaxClass20] of String[3] = ('1','2','2.0');

Var
  receiveName        : string;     (* ฌ๏ ไ ฉซ  *)
  ReceiveSize        : LongInt;    (*  งฌฅp โฅชใ้ฅฃo ไ ฉซ    *)
  TransferTime       : LongInt;    (* pฅฌ๏ แฎงค ญจ๏ โฅชใ้ฅฃo ไ ฉซ    *)
  FileAddition       : String[8];  (* ’จฏ ไ ฉซ                *)
  TransferCheck      : String[2];  (* ’จฏ CRC                 *)
  TransferBlockSize  : word;       (*  งฌฅp กซoช             *)
  TransferError      : word;       (* ฎซจ็ฅแโขฎ ฎ่จกฎช       *)
  TransferStart      : LongInt;    (* H ็ ซฎ แ ็ฅฃฎ ฌ๋ ฏpจญจฌ ฅฌ ไ ฉซ         *)
  TransferBytes      : LongInt;    (* —จแซo ก ฉโ ฏoซใ็ฅญญoฅ ข ํโoฌ ฏ ชฅโฅ     *)
  TransferBeginTime  : LongInt;    (* pฅฌ๏ ฎโ ญ ็ ซ  ฏฅpฅค ็จ ไ ฉซ           *)
  Total_Time         : longInt;
  Transfer_CPS       : longInt;
  Transfer_CPSpc     : word;
  Session_CPS        : LongInt;

  SendByte           : LongInt;
  ReceiveByte        : LongInt;
           { ฎซจ็ฅแโขฎ ฏฅpฅแซ ญ๋ๅ ก ฉโ ง  แฅแแจ๎ }
  ReceivingFile      : boolean;
Var
  OldName      : PathStr;
  NewName      : PathStr;
  Session_Type : byte;
  InBound_Path : PathStr;
  LogFaxSpeed  : boolean;

{-- Routines --}
procedure FullInfo;
procedure AKAInfo;

procedure SessionFace;
procedure ShowFileName(Recv:boolean; Prot:tProtocol; FileName:String);
procedure ClearFileName(Recv:boolean; Prot:tProtocol);
procedure ShowFileTime(Total_Time,Left_Time:LongInt;y:byte);
procedure Calc_CPS(Recv:boolean; Prot:tProtocol);

procedure EndFile;
procedure TermEndFile;

{--- Fax ---}
procedure FaxFace;
procedure ShowFaxState(FaxState:tFaxState);
procedure ShowRemote(RemoteId:String);
procedure ShowFaxSpeed(Speed:longInt);
procedure ShowFaxRes(SessionRes:boolean);
procedure ShowFaxFile(FileName:string);
procedure ShowFaxPage(PageNo:word);
procedure ShowFaxSize(Size:LongInt);

implementation

uses SFInclud,
     Pwd_Xs,
     a002Xs,
     MsgXs,
     Date,
     EmStruct,
     ShowF,
     UnixTime,
     Fos_Lib,
     Modem,
     WriteLog,
     TPCRT,
     SessCtl,
     EventMan,
     TString_,
     TPWindow;

procedure FullInfo;
begin
  FastWriteWindow(Pad(Copy(EMSI_DAT_R^.System_Name,1,33),33)+' ',1,2,pCfgRec^.SFMailColors[Session_Info]);
  FastWriteWindow(LeftPad(Copy(EMSI_DAT_R^.City,1,23),23),1,36,pCfgRec^.SFMailColors[Session_Info]);
  FastWriteWindow(Pad(Copy(EMSI_DAT_R^.System_Op,1,33),33)+' ',2,2,pCfgRec^.SFMailColors[Session_Info]);
  FastWriteWindow(LeftPad(Addr2Str(SessionControl^.pRemoteInfo^.RemoteAddr[1],
                                   SessionControl^.pRemoteInfo^.RemoteAddr[1].point<>0),23)
                  ,2,36,pCfgRec^.SFMailColors[Session_Info]);
  FastWriteWindow(Pad(Copy('Using: '+EMSI_DAT_R^.Mailer_Name+' '+EMSI_DAT_R^.Mailer_Version,1,33),33)+' '
            ,3,2,pCfgRec^.SFMailColors[Session_Info]);
  FastWriteWindow(LeftPad(Copy(EMSI_DAT_R^.BAUD_RATE_Flags,1,23),23),3,36,pCfgRec^.SFMailColors[Session_Info]);
  TabShow:=AkaInfo;
end;

procedure AKAInfo;
Var
  i    : byte;
  line : byte;
  s    : byte;
  tmpS : string[25];
begin
  FastWriteWindow('AKA:  ',1,2,pCfgRec^.SFMailColors[Session_Info]);
  line := 1;
  if SessionControl^.pRemoteInfo^.nRemoteAddr = 1 then begin
    FastWriteWindow(Pad('Remote system has no AKA',51),1,8,pCfgRec^.SFMailColors[Session_Info]);
    FastWriteWindow(Pad(' ',57),2,2,pCfgRec^.SFMailColors[Session_Info]);
  end else begin
    FastWriteWindow(Pad(' ',51),1,8,pCfgRec^.SFMailColors[Session_Info]);
    FastWriteWindow(Pad(' ',57),2,2,pCfgRec^.SFMailColors[Session_Info]);
    s:=8;
    For i:=2 to SessionControl^.pRemoteInfo^.nRemoteAddr do
      if line<3 then begin
        tmpS:=Addr2Str(SessionControl^.pRemoteInfo^.RemoteAddr[i],
                       SessionControl^.pRemoteInfo^.RemoteAddr[i].point<>0)+' ';
        if length(tmpS)+s > 58 then begin
          Inc(line);
          If Line < 3 then begin
            FastWriteWindow(TmpS,line,8,pCfgRec^.SFMailColors[Session_Info]);
            s:=8+Length(TmpS);
          end;
        end else begin
          FastWriteWindow(TmpS,line,s,pCfgRec^.SFMailColors[Session_Info]);
          Inc(s,Length(TmpS));
        end;
      end;
  end;
  If Line=1 then
    FastWriteWindow(PadCh('ฤ','ฤ',57),2,2,pCfgRec^.SFMailColors[Session_Border]);

  FastWriteWindow(Pad('Phone '+EMSI_DAT_R^.Phone_Number,34),3,2,pCfgRec^.SFMailColors[Session_Info]);
  If CheckPassword(SessionControl^.pRemoteInfo^.RemoteAddr[1]) then
    FastWriteWindow(LeftPad('þ protected þ',23),3,36,pCfgRec^.SFMailColors[Session_Info])
  else
    FastWriteWindow(LeftPad('๚ nonprotected ๚',23),3,36,pCfgRec^.SFMailColors[Session_Info]);
  TabShow:=FullInfo;
end;

procedure SessionFace;
Var
  x   : byte;
  y   : byte;
begin
  DrawTime     := 0;

{ ... face Session Screen ... }               { ----------------------------------- }

  if ScreenHeight>25 then x:=5 else x:=4;
  if TermMode then
    MakeWindow(PWin,10,x+1,70,x+SessionLines+12,true,true,true,
               pCfgRec^.SFMailColors[Session_Border],
               pCfgRec^.SFMailColors[Session_Border],
               pCfgRec^.SFMailColors[Session_Header],
               '')
  else
    MakeWindow(PWin,10,x,70,x+SessionLines+13,true,true,true,
               pCfgRec^.SFMailColors[Session_Border],
               pCfgRec^.SFMailColors[Session_Border],
               pCfgRec^.SFMailColors[Session_Header],
               '');
  DisplayWindow(Pwin);
  ClrScr;

  If TermMode then begin
    FastCenter('น '+Pad('',8)+' ฬ',0,pCfgRec^.SFMailColors[Session_Border]);
    FastCenter('ZModem',0,pCfgRec^.SFMailColors[Session_Header]);
  end else begin
    If SessionControl^.SessionType = Inbound then begin
      FastCenter('น '+Pad('',24)+' ฬ',0,pCfgRec^.SFMailColors[Session_Border]);
      FastCenter('Inbound Session ('+ZMod_Type[Session_Type]+')',
                  0,pCfgRec^.SFMailColors[Session_Header]);
    end else begin
      FastCenter('น '+Pad('',25)+' ฬ',0,pCfgRec^.SFMailColors[Session_Border]);
      FastCenter('Outbound Session ('+ZMod_Type[Session_Type]+')',
                  0,pCfgRec^.SFMailColors[Session_Header]);
    end;
  end;

  if TermMode then begin
    y:=0;
  end else begin
    FastWriteWindow('ฦอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออต'
              ,4,0,pCfgRec^.SFMailColors[Session_Border]);
    with SessionControl^,pCfgRec^ do begin
      FastWriteWindow('Send',5,2,(pCfgRec^.SFMailColors[Session_File] and $F0) or $0A);
      FastWriteWindow(':         of',5,9,pCfgRec^.SFMailColors[Session_File]);
      FastWriteWindow(LeftPad(vInBestForm(Traf_Out_Cur),6),5,11,SfMailColors[Session_Param]);
      FastWriteWindow(LeftPad(vInBestForm(Traf_Out),6),5,22,SfMailColors[Session_Param]);
      FastWriteWindow('Recv',5,34,(pCfgRec^.SFMailColors[Session_File] and $F0) or $0C);
      FastWriteWindow(':         of',5,39,pCfgRec^.SFMailColors[Session_File]);
      FastWriteWindow(LeftPad(vInBestForm(Traf_In_Cur),6),5,41,SfMailColors[Session_Param]);
      FastWriteWindow(LeftPad(vInBestForm(Traf_In),6),5,52,SfMailColors[Session_Param]);
    end;
    y:=2;
  end;
  FastWriteWindow('ฦอออออออออออออออออออออออออออออออัอออออออออออออออออออออออออออต'
            ,y+4,0,pCfgRec^.SFMailColors[Session_Border]);
  For x:= 5 to 9 do
  FastWriteWindow('ณ                               ณ                           ณ'
            ,x+y,0,pCfgRec^.SFMailColors[Session_Border]);
  FastWriteWindow('ฦอออออออออออออออออออออออออออออออฯอออออออออออออออออออออออออออต'
            ,y+10,0,pCfgRec^.SFMailColors[Session_Border]);

  If TermMode then begin
    FastWriteWindow('Internal Terminal ZModem',1,18,pCfgRec^.SFMailColors[Session_Info]);
    FastWriteWindow('Original design by Alexey Solomonov',2,12,pCfgRec^.SFMailColors[Session_Info]);
    FastWriteWindow('(C)opyright 1994-98, Santa Fox Team.',3,12,pCfgRec^.SFMailColors[Session_Info]);
  end else
    FullInfo;

  FastWriteWindow('File   :',y+5,2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Date   :',y+6,2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Block  :',y+7,2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Errors :',y+8,2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('CPS    :',y+9,2,pCfgRec^.SFMailColors[Session_File]);

  FastWriteWindow('Mode :',y+5,34,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Size :',y+6,34,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Pos  :',y+7,34,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Time :',y+8,34,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Left :',y+9,34,pCfgRec^.SFMailColors[Session_File]);

  if not TermMode then begin
    FastCenter('น '+Pad('',length(LastConnect))+' ฬ',13+SessionLines,pCfgRec^.SFMailColors[Session_Border]);
    FastCenter(LastConnect,13+SessionLines,pCfgRec^.SFMailColors[Session_Info]);
  end;

{ ... end of face Session Screen ... }        { ----------------------------------- }
  for x:=1 to SessionLines do
   SesBuffer^ [x]:='';
end;

procedure ShowGauge(Recive:boolean; DrawCur:longInt);
var
 totCube,
 curCube:longint;
 TotalCol:byte;
begin
 if ReceiveSize <> 0 then begin
   curCube:=(DrawCur*20) div ReceiveSize;
   if curCube >20 then curCube:=20;
 end else
   curCube:=20;

 with SessionControl^ do begin
   if Recive then begin
    if Traf_In <> 0 then begin
      totCube:=((Traf_In_Cur + DrawCur)*20) div Traf_In;
      if totCube >20 then totCube:=20;
    end else
      totCube:=20;
   end else begin
    if Traf_Out <> 0 then begin
      totCube:=((Traf_Out_Cur + DrawCur)*20) div Traf_Out;
      if totCube >20 then totCube:=20;
    end else
      totCube:=20;
   end;
   with pCfgRec^ do begin
     if recive then
      FastWriteWindow(LeftPad(vInBestForm(Traf_Out_Cur),6),5,11,SfMailColors[Session_Param]) else
      FastWriteWindow(LeftPad(vInBestForm(Traf_Out_Cur+DrawCur),6),5,11,SfMailColors[Session_Param]);
     FastWriteWindow(LeftPad(vInBestForm(Traf_Out),6),5,22,SfMailColors[Session_Param]);
     if recive then
      FastWriteWindow(LeftPad(vInBestForm(Traf_In_Cur+DrawCur),6),5,41,SfMailColors[Session_Param]) else
      FastWriteWindow(LeftPad(vInBestForm(Traf_In_Cur),6),5,41,SfMailColors[Session_Param]);
     FastWriteWindow(LeftPad(vInBestForm(Traf_In),6),5,52,SfMailColors[Session_Param]);
   end;
 end;

 if Recive then
 TotalCol:=$04 else TotalCol:=$02;
 with pCfgRec^ do begin
  FastWriteWindow('[',12,36,SFMailColors[Session_Border]);
  if totCube >curCube then begin
     FastWriteWindow(CharStr('Ü',curCube),12,37,(TotalCol shl 4) or (SFMailColors[Session_Border] and $0F));
     FastWriteWindow(CharStr('฿',totCube-curCube),12,37+curCube,TotalCol or (SFMailColors[Session_Border] and $F0));
     FastWriteWindow(CharStr('ฤ',20-totCube),12,37+totCube,SFMailColors[Session_Border]);
  end
  else begin
     FastWriteWindow(CharStr('Ü',totCube),12,37,(TotalCol shl 4) or (SFMailColors[Session_Border] and $0F));
     FastWriteWindow(CharStr('Ü',curCube-totCube),12,37+totCube,SFMailColors[Session_Border]);
     FastWriteWindow(CharStr('ฤ',20-curCube),12,37+curCube,SFMailColors[Session_Border]);
  end;
  FastWriteWindow(']',12,57,SFMailColors[Session_Border]);
 end;
end;

procedure ShowTermGauge;
Var
  line : byte;
begin
  if ReceiveSize <> 0 then begin
    FastWriteWindow('[',10,36,pCfgRec^.SFMailColors[Session_Border]);
    line:=((TransferStart+TransferBytes) * 20) div ReceiveSize;
    If line>20 then line := 20;
    FastWriteWindow(PadCh(CharStr('Û',line),'๚',20)
                    ,10,37,pCfgRec^.SFMailColors[Session_Border]);
    FastWriteWindow(']',10,57,pCfgRec^.SFMailColors[Session_Border]);
  end else
    FastWriteWindow('ฦอออออออออออออออออออออออออออออออฯอออออออออออออออออออออออออออต'
                    ,10,0,pCfgRec^.SFMailColors[Session_Border]);
end;

procedure ShowFileTime(Total_Time,Left_Time:LongInt;y:byte);
Var
  Time_Sh    : longInt;
begin
 { Total Time }
 Time_Sh:=Total_Time div 3600;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',y+3,41,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=(Total_Time div 60) mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',y+3,44,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=Total_Time mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)    ,y+3,47,pCfgRec^.SfMailColors[Session_Param]);
 { Left Time }
 Time_Sh:=Left_Time div 3600;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',y+4,41,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=(Left_Time div 60) mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',y+4,44,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=Left_Time mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)    ,y+4,47,pCfgRec^.SfMailColors[Session_Param]);
end;

procedure ShowFileName(Recv:boolean; Prot:tProtocol; FileName:String);
Var
  x,y        : byte;
begin
  with SessionControl^ do
  if not TermMode then begin
    ShowTime;
    ShowSessTime;
    If Recv then begin
      if Traf_In_Cur+ReceiveSize>Traf_In then Traf_In:=Traf_In_Cur+ReceiveSize;
    end else begin
      if Traf_Out_Cur+ReceiveSize>Traf_Out then Traf_Out:=Traf_Out_Cur+ReceiveSize;
    end;
    Total_Time:=((ReceiveSize-TransferStart) * 10) div Connect_Speed;
  end else begin
    GetDate_Time;
    Total_Time:=((ReceiveSize-TransferStart) * 10) div Conn_Speed;
  end;
  LenSizes:=length(long2Str(ReceiveSize));

  Case Prot of
    shZModem : begin
        If TermMode then y:=5 else y:=7;
        If Recv then begin
          FastWriteWindow('Recv',y,2,(pCfgRec^.SFMailColors[Session_Info] and $F0) or $0C);
          ReceiveName:=FileName;
        end else
          FastWriteWindow('Send',y,2,(pCfgRec^.SFMailColors[Session_Info] and $F0) or $0A);
        FastWriteWindow(Pad(FileName,12),y,11,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow (FileAddition+' (',y,41,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow('CRC-'+TransferCheck+')',y,51,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow(Long2FullDate(TransferTime),y+1,11,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow(Pad(long2Str(ReceiveSize),12),y+1,41,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow(LeftPad(long2Str(TransferStart),LenSizes),y+2,41,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow('0    ',y+2,11,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow(Pad(long2Str(TransferError),3),y+3,11,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow(Pad('0',21),y+4,11,pCfgRec^.SfMailColors[Session_Param]);
        ShowFileTime(Total_Time,Total_Time,y);
        if TermMode then
          ShowTermGauge else
          ShowGauge(Recv,TransferStart);
      end;
  end;
end;

procedure Calc_CPS(Recv:boolean; Prot:tProtocol);
Var
  x,y        : byte;
  time       : LongInt;
  Total_Time : LongInt;
  Left_Time  : LongInt;
  TempSpeed  : LongInt;
begin
  If not TermMode then begin
    ShowTime;
    ShowSessTime;
    TempSpeed:=Connect_Speed;
  end else begin
    GetDate_Time;
    TempSpeed:=Conn_Speed;
  end;

  time:=TimeCounter - TransferBeginTime;
  if (time > 0) then
    Transfer_CPS:=trunc(TransferBytes / (time/18.3))
  else
    Transfer_CPS:=0;
  If Transfer_CPS>99999 then Transfer_CPS:=99999;

  Transfer_CPSpc:=trunc(Transfer_CPS / (TempSpeed / 1000));
  If Transfer_CPSpc>999 then Transfer_CPSpc:=999;

  if Transfer_CPS<>0 then begin
    Left_Time:=(ReceiveSize-(TransferStart + TransferBytes)) div Transfer_CPS;
    Total_Time:=(ReceiveSize-TransferStart) div Transfer_CPS;
  end else begin
    Left_Time:=((ReceiveSize-(TransferStart + TransferBytes))*10) div TempSpeed;
    Total_Time:=((ReceiveSize-TransferStart)*10) div TempSpeed;
  end;

  if not TermMode then begin
    { Check CPS TreshOld }
    if (time>5460) and (Left_Time>120) then begin
      if Transfer_CPSpc < pcfgRec^.CPS_Threshold_5 then begin
        KillCD;
        LogWrite(wmLowCPS,long2Str(Transfer_CPS)+#3+
                 long2Str(Transfer_CPSpc),ld_SessAll);
      end;
    end;
    if (time<5460) and (time>1092) and (Left_Time>120) then begin
      if Transfer_CPSpc < pcfgRec^.CPS_Threshold_1 then begin
        KillCD;
        LogWrite(wmLowCPS,long2Str(Transfer_CPS)+#3+
                 long2Str(Transfer_CPSpc),ld_SessAll);
      end;
    end;
    { Check CPS TreshOld }

    Time:=TimeCounter - BeginTime;
    if (Time > 0) then
      Session_CPS:=trunc((SendByte+ReceiveByte) / (Time/18.3))
    else Session_CPS:=0;
    if Session_CPS>99999 then Session_CPS:=99999;
    { Check Session Limit }
    If SessionControl^.SessionType = Inbound then begin
      if (NodeEntry.SessLimitIn<>0) and
         (Time>NodeEntry.SessLimitIn) then begin
        KillCD;
        LogWrite(wmLimitIn,'',ld_SessAll);
      end;
    end else begin
      if (NodeEntry.SessLimitOut<>0) and
         (Time>NodeEntry.SessLimitOut) then begin
        KillCD;
        LogWrite(wmLimitOut,'',ld_SessAll);
      end;
    end;
    { Check Session Limit }
  end;

  if TermMode then
    ShowFileTime(Total_Time,Left_Time,5)
  else
    ShowFileTime(Total_Time,Left_Time,7);

  Case Prot of
    shZModem : begin
        If TermMode then y:=9 else y:=11;
        FastWriteWindow(pad(long2Str(Transfer_CPS),6)+' '
                           +LeftPad(Long2Str(Transfer_CPSpc),3)
                           +'%  ',y,11,pCfgRec^.SfMailColors[Session_Param]);
        if not TermMode then begin
          FastWriteWindow('['+Leftpad(long2Str(Session_CPS),5)+']',y,24,pCfgRec^.SfMailColors[Session_Info]);
          ShowGauge(Recv,TransferStart+TransferBytes);
        end else
          ShowTermGauge;
        FastWriteWindow(pad(long2Str(TransferBlockSize),5),y-2,11,pCfgRec^.SfMailColors[Session_Param]);
        FastWriteWindow(Pad(long2Str(TransferError),3),y-1,11,pCfgRec^.SfMailColors[Session_Param]);
        ShowBytes(0);
      end;
    shHydra  : ;
    shFax    : ;
  end;
end;

procedure ClearFileName(Recv:boolean; Prot:tProtocol);
Var
  x,y : byte;
begin
  if not TermMode then begin
    ShowTime;
    ShowSessTime;
  end;
  Case Prot of
    shZModem : begin
        If TermMode then y:=5 else y:=7;
          FastWriteWindow('File   :',y,2,pCfgRec^.SFMailColors[Session_File]);
          FastWriteWindow(Pad('',12),y,11,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow(Pad('',18),y+1,11,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow (Pad('',18),y,41,pCfgRec^.SfMailColors[Session_Param]);

          FastWriteWindow(Pad('',12),y+1,41,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow(Pad('',18),y+2,41,pCfgRec^.SfMailColors[Session_Param]);

          FastWriteWindow('        ',y+3,41,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow('        ',y+4,41,pCfgRec^.SfMailColors[Session_Param]);

          FastWriteWindow(Pad('',20),y+2,11,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow('   ',y+3,11,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow(Pad(' ',21),y+4,11,pCfgRec^.SfMailColors[Session_Param]);
          FastWriteWindow('ฦอออออออออออออออออออออออออออออออฯอออออออออออออออออออออออออออต'
                          ,y+5,0,pCfgRec^.SFMailColors[Session_Border]);

      end;
    shHydra  : ;
    shFax    : ;
  end;
end;

procedure EndFile;
begin
  Calc_CPS(receive,shZModem);
  if (receive) and
     (ReceivingFile) then begin
    if (ReceiveSize = (TransferStart + TransferBytes)) then begin
      If TransferError = 0 then
        LogWrite(imZRecvComplete,long2Str(Transfer_CPS)+#3+
                 long2Str(Transfer_CPSpc),ld_SessAll)
      else
        LogWrite(imZRecvComplErr,long2Str(Transfer_CPS)+#3+
                 long2Str(Transfer_CPSpc)+#3+
                 long2Str(TransferError),ld_SessAll);
      RecvThisFile(Inbound_Path+ReceiveName,ReceiveSize);
    end;
    with SessionControl^ do
    Inc(Traf_In_Cur,ReceiveSize);
  end;
end;

procedure TermEndFile;
begin
  Calc_CPS(true,shZModem);
  if (receive) and
     (ReceivingFile) and
     (ReceiveSize = (TransferStart + TransferBytes)) then begin
      If TransferError = 0 then
        LogWrite(imZRecvComplete,long2Str(Transfer_CPS)+#3+
                 long2Str(Transfer_CPSpc),ld_SessAll)
      else
        LogWrite(imZRecvComplErr,long2Str(Transfer_CPS)+#3+
                 long2Str(Transfer_CPSpc)+#3+
                 long2Str(TransferError),ld_SessAll);
  end;
end;

{--- Fax ---}

procedure FaxFace;
begin
  MakeWindow(PWin,20,(ScreenHeight div 2)-5,60,(ScreenHeight div 2)+5,true,true,true,
             pCfgRec^.SFMailColors[Session_Border],
             pCfgRec^.SFMailColors[Session_Border],
             pCfgRec^.SFMailColors[Session_Header],
             '');
  DisplayWindow(PWin);
  ClrScr;
  FastCenter('น '+Pad('',20+length(Fax_Type[pCfgRec^.FaxClass]))+' ฬ',0,
             pCfgRec^.SFMailColors[Session_Border]);
  FastCenter('Receive fax (class '+Fax_Type[pCfgRec^.FaxClass]+')',0,
             pCfgRec^.SFMailColors[Session_Header]);
  FastWriteWindow('ฦ'+CharStr('อ',39)+'ต',3,0,
                  pCfgRec^.SFMailColors[Session_Border]);
  FastWriteWindow('ฦ'+CharStr('อ',39)+'ต',6,0,
                  pCfgRec^.SFMailColors[Session_Border]);
  FastWriteWindow('Remote ID :',1,4,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('State :',2,8,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Fax Speed :',4,4,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Resolution :',5,3,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('File :',7,9,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Page :',8,9,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Size :',9,9,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow(Pad('Unknown',20),1,16,pCfgRec^.SfMailColors[Session_Param]);
end;

procedure ShowFaxState(FaxState:tFaxState);
Var
  s : string;
begin
  Case FaxState of
    RemoteID : s:='Remote identification';
    BeginPage: s:='Begin of page';
    RecvPage : s:='Receiving page data';
    EndPage  : s:='End of page';
    EndFax   : s:='End of fax session';
  end;
  FastWriteWindow(Pad(s,21),2,16,pCfgRec^.SfMailColors[Session_Param]);
end;

procedure ShowRemote(RemoteId:String);
Var
  s : string;
begin
  FastWriteWindow(Pad(RemoteId,20),1,16,pCfgRec^.SfMailColors[Session_Param]);
  LogWrite(imFaxRemoteId,RemoteId,ld_File);
end;

procedure ShowFaxSpeed(Speed:longInt);
Var
  s : string;
begin
  FastWriteWindow(long2Str(Speed),4,16,pCfgRec^.SfMailColors[Session_Param]);
  If LogFaxSpeed then
    LogWrite(imFaxSpeed,long2Str(Speed),ld_File);
end;

procedure ShowFaxRes(SessionRes:boolean);
Var
  s : string;
begin
  if SessionRes then begin
    FastWriteWindow('Fine',5,16,pCfgRec^.SfMailColors[Session_Param]);
    If LogFaxSpeed then
      LogWrite(imFaxResolution,'Fine',ld_File);
  end else begin
    FastWriteWindow('Normal',5,16,pCfgRec^.SfMailColors[Session_Param]);
    If LogFaxSpeed then
      LogWrite(imFaxResolution,'Normal',ld_File);
  end;
  If LogFaxSpeed then LogFaxSpeed:=false;
end;

procedure ShowFaxFile(FileName:string);
Var
  s : string;
begin
  FastWriteWindow(FileName,7,16,pCfgRec^.SfMailColors[Session_Param]);
  LogWrite(imFaxReceive,FileName,ld_File);
end;

procedure ShowFaxPage(PageNo:word);
Var
  s : string;
begin
  FastWriteWindow(Long2Str(PageNo),8,16,pCfgRec^.SfMailColors[Session_Param]);
end;

procedure ShowFaxSize(Size:LongInt);
Var
  s : string;
begin
  FastWriteWindow(Pad(Long2Str(Size),6),9,16,
                  pCfgRec^.SfMailColors[Session_Param]);
end;

end.