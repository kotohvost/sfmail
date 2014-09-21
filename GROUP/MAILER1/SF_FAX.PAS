{$X+,I-,O+,F+}

unit Sf_Fax;

INTERFACE

procedure ReceiveFax;

IMPLEMENTATION

uses
 Config,
 SFInclud,
 Dos,
 tString_,
 TpDos,
 MsgXs,
 aTime,
 WriteLog,
 procMan,
 keyb,
 RelTQ,
 KeyRead,
 Fos_Lib,
 Show,
 Modem,
 TPWindow,
 Date,
 TpCrt;

{$I Sf_Fax.inc}

var
 FaxCtl:pFaxCtl;
 TempStr:String;

Function GetByte(TimeOut:LongInt):integer;
Var
  C    : Integer;
  Time : LongInt;
begin
  if RxCount = RxTotal then begin
   C:=ReadBlock(1024,RxBuff);
   If C<=0 then begin
     Time := TimeCounter+TimeOut;
     Repeat
       ReleaseTQ;
       c:=GetPortStat;
       If (GetPortStat And ST_RDA) <> 0 then begin
         C:=ReadBlock(1024,RxBuff);
         If C>0 then begin
           RxTotal:=C;
           RxCount:=0;
         end;
       end;
     Until (TimeCounter > Time) or (RxCount<>RxTotal);
     If RxCount = RxTotal then begin
       ReleaseTQ;
       GetByte := WaitTOUT;
       exit;
     end;
   end else begin
     RxTotal:=C;
     RxCount:=0;
   end;
  end;
  Inc(RxCount);
  GetByte:=RxBuff^[RxCount];
end;

function RotateByte(Cod:char):byte; assembler;
{-Flip code MSB for LSB}
asm
    mov dl,Cod
    xor ax,ax
    mov cx,8
@1: shr dl,1
    rcl al,1
    loop @1
end;

procedure NewTimer(var ET:EventTimer; Tics:longint);
{-Returns a set EventTimer that will expire in Tics}
begin
 with ET do begin
  StartTics:=TimeCounter;
  ExpireTics:=StartTics+Tics;
 end;
end;

procedure NewTimerSecs(var ET:EventTimer; Secs:longint);
{-Returns a set EventTimer}
begin
 NewTimer(ET,(Secs*1675) div 92);
end;

function TimerExpired(ET:EventTimer):boolean;
{-Returns True if ET has expired}
begin
 TimerExpired:=true;
  { Check normal expiration }
 if TimeCounter <=ET.expireTics then
   TimerExpired:=false;
end;

procedure StripPrefix(var S:string);
{-removes prefix from faxmodem response string}
var
 SepPos:integer;

begin
 s:=Trim(s);
 SepPos:=Pos(':',s);
 if SepPos =0 then
   SepPos:=Pos('=',s);
 if SepPos >0 then
   Delete(s,1,SepPos);
 s:=Trim(s);
end;

function TrimStationID(s:string):string;
begin
 s:=Trim(s);
 if s[1] ='"' then
   s[1]:=' ';
 while (Length(s) >0) and (not(UpCase(s[Length(s)]) in ['0'..'9','A'..'Z'])) do
   Dec(s[0]);
 TrimStationID:=Trim(s);
end;

procedure GotError(fe:integer; ec:integer; es:string);
var
 s:string;

begin
 case fe of
   fe_Ok:            s:='no error';
   fe_IO:            s:='i/o error';
   fe_WriteFaxHdr:   s:='error write fax main hdr';
   fe_WritePgHdr:    s:='error write fax page hdr';
   fe_LocatePage:    s:='unable to locate page';
   fe_UnkModemResult:s:='unexpected char in modem result string';
   fe_UnexpectedFHNG:s:='unexpected FHGN frame';
   fe_Tout:          s:='timeout';
   fe_Init:          s:='fax init error';
   fe_DataCall:      s:='call is DATA';
   fe_VoiceCall:     s:='call is VOICE';
   fe_Train:         s:='fax train error';
   fe_UserAbort:     s:='user abort fax';
 else
   s:='extra error';
 end;
 if ec >0 then s:=s+' (#'+Long2str(ec)+')';
 if Length(es) <>0 then s:=s+' <'+es+'>';
 LogWrite(0,'(?) '+s,ld_all);
end;

function faxCheckKeyboard:boolean;
var
 ch:char;

begin
 faxCheckKeyboard:=false;
 repeat
 if (IfKeyPress <>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then
  if KeyPressed then begin
    ch:=readkey;
    case ch of
     #27: begin        {Esc}
            faxCheckKeyboard:=true;
            FaxCtl^.faxStatus:=fe_UserAbort;  {abort state}
            GotError(fe_UserAbort,0,'');
            exit;
          end;
     #0: begin                                    {#0+}
          ch:=ReadKey;
          if ch =#35 then begin                   {Alt-H}
            faxCheckKeyboard:=true;
            FaxCtl^.faxStatus:=fe_UserAbort;  {abort state}
            GotError(fe_UserAbort,0,'');
            exit;
          end;
         end; {Begin --> #0}
    end; {Case}
  end
  else
    IfKeyPress:=0;
 until IfKeyPress =0;
end;

function WaitComplete(ET:EventTimer):boolean;
begin
 if TimerExpired(ET) or faxCheckKeyboard then
  WaitComplete:=true
 else
  WaitComplete:=false;
end;

procedure InitFaxCtl;
{-Allocate and initialize a FaxData structure}
begin
 GetMem(FaxCtl,SizeOf(tFaxCtl));
 FillChar(FaxCtl^,SizeOf(tFaxCtl),0);
 GetMem(FaxCtl^.DataBuf,DataBufSiz);
 GetMem(RxBuff,1024);
 RxCount:=0;
 RxTotal:=0;
end;

procedure DoneFaxCtl;
{-Dispose of a FaxData record}
begin
 close(FaxCtl^.InFile);
 if IOResult<>0 then ;
 FreeMem(FaxCtl^.DataBuf,DataBufSiz);
 FreeMem(FaxCtl,SizeOf(tFaxCtl));
 FreeMem(RxBuff,1024);
end;

function SpeedCode:char;
{-returns char code for speed}
begin
 with FaxCtl^ do begin
  case MaxFaxBPS of
   2400: SpeedCode:='0';
   4800: SpeedCode:='1';
   7200: SpeedCode:='2';
   12000: SpeedCode:='4';
   14400: SpeedCode:='5';
  else
   SpeedCode:='3';
  end;
 end;
end;

function NameFax:PathStr;
{-Unique fax filename in format: DDMM0001.adf}
var
 d,mnth,yr,o:word;
 fn:string[4];

begin
 GetDate(yr,mnth,d,o);
 fn:=LeftPadCh(Long2str(d),'0',2)+LeftPadCh(Long2str(mnth),'0',2);
 o:=0;
 while (o <10000) and ExistFile(pCfgRec^.FaxInbound+fn+
                       LeftPadCh(Long2str(o),'0',4)+faxXt) do Inc(o);
 if o <10000 then
  NameFax:=pCfgRec^.FaxInbound+fn+LeftPadCh(Long2str(o),'0',4)+faxXt
 else
  NameFax:=pCfgRec^.FaxInbound+'noname'+faxXt;
end;

procedure Merge(var s:string; c:char);
var
 sl:byte absolute s;

begin
 if sl >254 then
  Move(s[2],s[1],sl-1)
 else
  Inc(sl);
 s[sl]:=c;
end;

function LocatePage(PgNo : Word):integer;
var
 w:word;
 l:longint;
 Result:word;
 P:PageHeaderRec;

begin
 with FaxCtl^ do begin
  LocatePage:=-1;
  { validate number }
  if (PgNo =0) or (PgNo >FaxHeader.PageCount) then
    exit;
  { start at head of file and walk the list of pages }
  seek(InFile, FaxHeader.PageOfs);
  Result:=IoResult;
  if Result <>0 then begin
    LocatePage:=Result;
    exit;
  end;

  if PgNo >1 then begin
    for W:=1 to (PgNo-1) do begin
      BlockRead(InFile, P, SizeOf(P));
      Result:=IoResult;
      if Result <>0 then begin
        LocatePage:=Result;
        exit;
      end;
      l:=FilePos(InFile);
      Inc(l,P.ImgLength);

      seek(InFile, l);
      Result:=IoResult;
    end;
  end;
  LocatePage:=Result;
 end;
end;

function ConnectResp:boolean;
begin
 ConnectResp:=Pos('CONNECT',FaxCtl^.Response) >0;
end;

function OkResp:boolean;
begin
 OkResp:=Pos('OK',FaxCtl^.Response) >0;
end;

function NoCarrierResp:boolean;
begin
 NoCarrierResp:=Pos('CARRIER',FaxCtl^.Response) >0;
end;

function ErrorResp:boolean;
begin
 ErrorResp:=Pos('ERROR',FaxCtl^.Response) >0;
end;

function FHNGResp:boolean;
begin
 if pCfgRec^.FaxClass=FaxClass20 then
   FHNGResp:=Pos('FHS',FaxCtl^.Response) >0 else
   FHNGResp:=Pos('FHNG',FaxCtl^.Response) >0;
end;

procedure PrepResp;
begin
 with FaxCtl^ do begin
  CRLFindex:=0;
  ETXindex:=0;
  Response:='';
  CollectResp:=true;
 end;
end;

procedure PutModem(s:string);
{-send string to modem and prepare to response}
begin
 Delay(PreCmdDelay);
 SendStr(s+^M);
 PrepResp;
end;

function ExtractFHNGCode:word;
{-Return numeric FHNG response}
var
 s:string[20];
 W:word;
 I:byte;
 Cod:word;

begin
 with FaxCtl^ do begin
  I:=Pos(':',Response);
  if I <>0 then begin
    s:=Copy(Response,I+1,3);
    s:=Trim(s);
    w:=0;
    Val(s,w,Cod);
    ExtractFHNGCode:=w;
  end
  else
    ExtractFHNGCode:=0;
 end;
end;

function AddReceivedCmd(var s:string):boolean;
var
 i:integer;

begin
 AddReceivedCmd:=false;
 with FaxCtl^ do
  repeat
   i:=GetByte(91);
   if i <0 then
    exit
   else
    if i =13 then begin
     if s <>'' then begin
      AddReceivedCmd:=true;
      exit;
     end;
    end
    else
     if i >=32 then
      Merge(s,char(i));
  until false;
end;

procedure PutFaxCommand(s:string);
{-Send FTM/FRM modem command}
begin
 with FaxCtl^ do begin
   Delay(PreFaxDelay);
   PutModem(S+^M);
   PrepResp;
 end;
end;

procedure PutFrameR;
begin
 SendStr('AT+FRH=3'^M);
 PrepResp;
end;

procedure PutFrameT;
begin
 SendStr('AT+FTH=3'^M);
 PrepResp;
end;

procedure HDLCstart(_last:boolean);
begin
 with FaxCtl^ do begin
   Delay(FrameWait);
   WriteChar(AddrField);
   if _last then
     WriteChar(ControlFieldLast)
   else
     WriteChar(ControlField);
 end;
end;

procedure HDCLend;
begin
 with FaxCtl^ do begin
  WriteChar(cDLE);
  WriteChar(cETX);
 end;
end;

procedure PutStandardFrame(Frame:byte);
{-Transmit an standard frame of type Frame}
begin
 with FaxCtl^ do begin
   { Send HDLC address and control fields }
   HDLCstart(true);
   { Send fax control field, EOP format }
   WriteChar(char(Frame));
   { Send message terminator }
   HDCLend;
 end;
end;

procedure PutDCSDISframe(UseDIS:boolean);
{-Transmit a DCS or DIS frame}
var
 b:byte;

begin
 with FaxCtl^ do begin
   { Send HDLC address and control fields }
   HDLCstart(true);
   { Send fax control field, DCS format }
   if UseDIS then
     WriteChar(char(DISframe))
   else
     WriteChar(char(DCSframe or $01));
   { Send DCS/DIS data, first byte is static }
   WriteChar(char(DISgroup1));
   { Second byte contains resolution and BPS info }
   b:=DISgroup3_1;
   if ResC ='1' then
     b:=b or DIShighResolution;
   if UseDIS then begin
     case BPSindex of
       6: b:=b or DIS9600BPS or DIS14400BPS;
       5: b:=b or DIS9600BPS or DIS12000BPS;
       3: b:=b or DIS7200BPS;
       2: b:=b or DIS4800BPS;
       1: b:=b or DIS2400BPS;
     else
       b:=b or DIS7200BPS
     end;
   end
   else begin
     case BPSindex of
       6: b:=b or DIS14400BPS;
       5: b:=b or DIS12000BPS;
       3: b:=b or DIS7200BPS;
       2: b:=b or DIS4800BPS;
       1: b:=b or DIS2400BPS;
     else
       b:=b or DIS9600BPS;
     end;
   end;
   WriteChar(char(b));
   { Note modulation code for training and message transmission }
   if not UseDIS then
     ModCode:=ModArray[BPSindex];
   { Last two bytes are static }
   SendStr(char(DISgroup3_2)+char(DISgroup3_3));
   { Send message terminator }
   HDCLend;
 end;
end;

procedure PutCSIframe;
{-Transmit a CSI frame}
var
 i:word;

begin
 with FaxCtl^ do begin
   { Send HDLC address and control fields }
   HDLCstart(false);
   { Send fax control field, CSI format }
   (*PutChar(CPort,char(CSIframe));*)
   WriteChar(char(CSIframe));
   { Send CSI data }
   for i:=20 downto 1 do
    WriteChar(pCfgRec^.FaxStation[i]);
   { Send message terminator }
   HDCLend;
 end;
end;

function ProcessModemCmd(s:string):boolean;
var
 C:char;
 OkString:string;
 Finished:boolean;

begin
 with FaxCtl^ do begin
   {Send the command}
   ProcessModemCmd:=false;
   SendStr(s);

   repeat
     ShowSessTime;
     {Collect the reponse}
     Finished:=false;
     Response:='';
     repeat
       Finished:=AddReceivedCmd(Response);
     until Finished or WaitComplete(ReplyTimer);
     if faxStatus <>0 then exit;
   until (Response <>'');
   { Check for errors }
   if not ErrorResp then begin
     { Collect and discard the OK if above response was data }
     if Pos('OK',Response) =0 then begin
       OkString:='';
       Finished:=false;
       repeat
         Finished:=AddReceivedCmd(OkString);
       until Finished or WaitComplete(ReplyTimer);
       if faxStatus <>0 then exit;
     end;
     ProcessModemCmd:=true
   end
   else begin
     ProcessModemCmd:=false;
     faxStatus:=-1;  {error}
   end;
 end;
end;

function CheckForString(var Index:byte; C:char;
                        S:string; IgnoreCase:boolean):boolean;
{-Checks for string S on consecutive calls, returns True when found}
begin
 CheckForString:=false;
 Inc(Index);
 { Upcase both data if ignoring case}
 if IgnoreCase then begin
   C:=UpCase(C);
   s[Index]:=UpCase(s[Index]);
 end;
 { Compare...}
 if C =s[Index] then
  { Got match, was it complete?}
  if Index =Length(s) then begin
    Index:=0;
    CheckForString:=true;
  end
  else
 else
  {No match, reset Index}
  if C =UpCase(s[1]) then
    Index:=1
  else
    Index:=0;
end;

procedure CalcMinBytesPerLine;
{-Calculate minimum byte per line}
begin
 with FaxCtl^ do
  MinBytes:=((SessionBPS*ScanTimes[SessionScan,SessionRes]) div 8000);
end;

procedure ExtractClass1Params(DIS:boolean; B2,B3:byte);
{-Extract bps, res, ecm from 2nd byte of DCS/DIS}
begin
 with FaxCtl^ do begin
   FillChar(RmtMods, SizeOf(RmtMods), false);
   RmtMods[1]:=true;
   RmtMods[2]:=true;

   if DIS then begin
     RmtMods[6]:=B2 and $20 =$20;
     RmtMods[5]:=B2 and $10 =$10;
     case B2 and $0C of
       $04: RmtMods[4]:=true;
       $0C: begin
             RmtMods[3]:=true;
             RmtMods[4]:=true;
            end;
     end;
     { Set SessionBPS from lowest common btween local and remote capabilities}
     { and less than or equal to MaxFaxBPS}
     BPSindex:=MaxModIndex+1;
     repeat
      Dec(BPSindex);
     until (LocalMods[BPSindex] and RmtMods[BPSindex]) and
           (Class1BPSarray[BPSindex] <=MaxFaxBPS);
     SessionBPS:=Class1BPSArray[BPSindex];
   end
   else begin
     if (B2 and $20) =$20 then
       BPSindex:=14400
     else
      if (B2 and $10) =$10 then
        BPSindex:=12000
      else begin
        case B2 and $0C of
          $00: BPSIndex:=1;
          $08: BPSIndex:=2;
          $04: BPSIndex:=4;
        else  BPSIndex:=3;
        end;
      end;
     SessionBPS:=Class1BPSarray[BPSindex];
   end;
   ShowFaxSpeed(SessionBPS);
   { Set resolution and error correction }
   SessionRes:=B2 and $40 =$40;
   ShowFaxRes(SessionRes);
   SessionECM:=false;
   { Set scan times }
   case B3 and $70 of
     $70: SessionScan:=0;   {0,0}
     $10: SessionScan:=1;   {5,5}
     $60: SessionScan:=2;   {10,5}
     $20: SessionScan:=3;   {10,10}
     $30: SessionScan:=4;   {20,10}
     $00: SessionScan:=5;   {20,20}
     $50: SessionScan:=6;   {40,20}
     $40: SessionScan:=7;   {40,40}
   end;
   CalcMinBytesPerLine;
 end;
end;

procedure ExtractClass2Params(s:string);
{-Extract bps, res, ecm from S, as data from FDCS/FDIS}
begin
 with FaxCtl^ do begin
  case s[3] of
   '0': SessionBPS:=2400;
   '1': SessionBPS:=4800;
   '2': SessionBPS:=7200;
   '4': SessionBPS:=12000;
   '5': SessionBPS:=14400;
  else SessionBPS:=9600;
  end;
  ShowFaxSpeed(SessionBPS);

  SessionRes:=s[1]='1';
  ShowFaxRes(SessionRes);

  case Response[11] of
   '1','2': SessionECM:=true;
  else SessionECM:=false;
  end;

  SessionScan:=ord(Response[15])-$30;

  CalcMinBytesPerLine;
 end;
end;

procedure GetClass1Modulations(Transmit:boolean);
{-Get this faxmodem's transmit/receive modulation capabilities}
var
 Finished:boolean;
 i:word;

begin
 with FaxCtl^ do begin
   { Set defaults }
   FillChar(LocalMods,SizeOf(LocalMods),false);
   LocalMods[1]:=true;
   LocalMods[2]:=true;

   if Transmit then
     PutModem('AT+FTM=?')
   else
     PutModem('AT+FRM=?');
   NewTimer(ReplyTimer,ReplyWait);

   repeat
     ShowSessTime;
     { Collect the response }
     Finished:=false;
     Response:='';
     repeat
       Finished:=AddReceivedCmd(Response);
     until Finished or WaitComplete(ReplyTimer);
     { If this is a modulation response string, parse it }
     if Pos('3,',Response) <>0 then begin
       for I:=3 to 6 do
         LocalMods[I]:=Pos(ModArray[I],Response) <>0;
       { Note highest mod }
       BPSindex:=MaxModIndex;
       while not LocalMods[BPSindex] do
         Dec(BPSindex);
     end;
     { Wait briefly for OK }
     NewTimer(ReplyTimer,36);
     if not OkResp and not ErrorResp then begin
       Finished:=false;
       Response:='';
     end;
   until Finished or WaitComplete(ReplyTimer);
 end;
end;

function ProcessFrame(var Retrain:boolean):boolean;
{-Process the frame in Response}
var
 I:word;

begin
 with FaxCtl^ do begin
   Retrain:=false;
   { Discard till flag byte }
   while (Response[1] <>#255) and (Length(Response) >1) do
     Delete(Response,1,1);
   { If last frame, return True }
   ProcessFrame:=byte(Response[2]) and $10 =$10;

   ReceivedFrame:=ord(Response[3]);

   { Process frame }
   case (ReceivedFrame and $FE) of
     TSIFrame,
     CSIFrame: begin
                { Extract remote station ID }
                for I:=1 to 20 do
                 RemoteID[I]:=Response[24-I];
                RemoteID[0]:=#20;
                ShowRemote(RemoteId);
                ShowFaxState(BeginPage);
                ForceStatus:=true;
               end;
     DISFrame: begin
                { Extract session parameters }
                ExtractClass1Params(true,ord(Response[5]),ord(Response[6]));
                FaxProgress:=fpSessionParams;
                ForceStatus:=true;
               end;
     DCSFrame: begin
                { Extract session parameters }
                ExtractClass1Params(false,ord(Response[5]),ord(Response[6]));
                { Set modulation code }
                ModCode:=ModArray[BPSIndex];
                FaxProgress:=fpSessionParams;
                ForceStatus:=true;
               end;
     CFRFrame: { Nothing to do for CFR frames } ;
     NSFFrame: { Nothing to do for NSF frames } ;
     RTNFrame,
     FTTFrame: Retrain:=true;
   end;
   PrepResp;
 end;
end;

procedure FlushBuffer;
{-write current buffered data to InFile}
var
 BytesWritten:word;

begin
 with FaxCtl^ do begin
   { Write the block }
   BlockWrite(InFile,DataBuf^,CurrOfs,BytesWritten);
   faxStatus:=IoResult;
   if BytesWritten <>CurrOfs then
     faxStatus:=160;
   if faxStatus <>fe_Ok then
     GotError(fe_IO,faxStatus,FaxFname);
   CurrOfs:=0;
 end;
end;

function AddReceivedData:boolean;
{-Get waiting FAX stream data.  Returns True if EOP seen.}
var
 c:char;
 i:integer;
 Count:word;

function AddToStream(_c:char):boolean;
begin
 with FaxCtl^ do begin
   AddToStream:=true;
{   if pCfgRec^.FaxClass in [FaxClass2,FaxClass20] then
     DataBuf^[CurrOfs]:=RotateByte(_c)}
   if pCfgRec^.FaxClass = FaxClass2 then
     DataBuf^[CurrOfs]:=RotateByte(_c)
   else
     DataBuf^[CurrOfs]:=byte(_c);
   Inc(CurrOfs);
   if CurrOfs >=DataBufSiz then begin
     ShowSessTime;
     FlushBuffer;
     if faxStatus <>fe_Ok then
       AddToStream:=false;
   end;
 end;
end;

begin
 with FaxCtl^ do begin
   AddReceivedData:=false;
   faxStatus:=fe_Ok;

   i:=GetByte(faxWaitChar);
   if i >=0 then begin
     { Process while received data ready }
     Count:=0;
     (*while CharReady(CPort) do begin*)
     while i >=0 do begin
       { Periodically exit back to state machine to check abort and status }
       Inc(Count);
       if Count >DefStatusBytes then begin
         ShowTime;
         ShowSessTime;
         ShowFaxSize(DataCount);
         exit;
       end;
       c:=char(i);
       (*GetChar(CPort,c);*)
       faxStatus:=fe_Ok;
       { check for <DLE><ETX> pair indicating end of page }
       if c =cETX then
         if Last =cDLE then begin
           FlushBuffer;
           AddReceivedData:=true;
           exit;
         end;
         { Write data, DLE is data link escape }
         if (c <>cDLE) or ((c =cDLE) and (Last =cDLE)) then begin
           if AddToStream(c) then
             Inc(DataCount)
           else begin
             { Error writing to file, let state machine handle error }
             AddReceivedData:=true;
             exit;
           end;
           if Last =cDLE then
             Last:=#255
           else
             Last:=c;
         end
         else
           Last:=c;
       i:=GetByte(faxWaitChar);
     end; (*WHILE CHARREADY*)
     { update our timeout }
     NewTimer(ReplyTimer,ReplyWait);
     exit;
   end;

   if TimerExpired(ReplyTimer) then begin
     faxStatus:=fe_Tout;
     AddReceivedData:=true;
   end;
 end;
end;

function UpdateMainHeader:integer;
{-Update the contents of the main header in the file}
var
 i:integer;
 l:longint;
 w:word;

begin
 with FaxCtl^ do begin
   { Refresh needed fields of MainHeader rec }
   with FaxHeader do begin
     {SenderID:=pCfgRec^.FaxStation;}
     CreateDosTimestamp(fDateTime);
   end;
   { Save current file position for later }
   l:=FilePos(InFile);
   i:=IoResult;
   if i <>0 then begin
     GotError(fe_WriteFaxHdr,i,'');
     UpdateMainHeader:=i;
     exit;
   end;
   { seek to head of file }
   seek(InFile,0);
   i:=IoResult;
   if i <>0 then begin
     UpdateMainHeader:=i;
     GotError(fe_WriteFaxHdr,i,'');
     exit;
   end;
   { Write the header }
   BlockWrite(InFile, FaxHeader, SizeOf(FaxHeader), w);
   i:=IoResult;
   if (I =0) and (w <>SizeOf(FaxHeader)) then
     I:=160;  {-device write fault}
   if I <>0 then begin
     UpdateMainHeader:=i;
     GotError(fe_WriteFaxHdr,i,'');
     exit;
   end;
   { Return to original position }
   seek(InFile,l);
   i:=IoResult;
   if i <>0 then begin
     UpdateMainHeader:=i;
     GotError(fe_WriteFaxHdr,i,'');
   end
   else
     UpdateMainHeader:=fe_Ok;
 end;
end;

function UpdatePageHeader(PgNo:word; var PgInfo:PageHeaderRec):integer;
{-Update the contents of the PgNo-th page header in the file}
var
 i:integer;
 w:word;
 l:longint;

begin
 with FaxCtl^ do begin
  { save current file position for later }
  l:=FilePos(InFile);
  I:=IoResult;
  if I <>0 then begin
    UpdatePageHeader:=i;
    GotError(fe_WritePgHdr,i,'');
    exit;
  end;
  { find the page in question }
  i:=LocatePage(PgNo);
  if i <>0 then begin
    UpdatePageHeader:=i;
    GotError(fe_LocatePage,i,Long2str(PgNo));
    exit;
  end;
  { update the header }
  BlockWrite(InFile, PgInfo, SizeOf(PageHeaderRec), w);
  i:=IoResult;
  if (i =0) and (w <>SizeOf(PageHeaderRec)) then
    i:=160;
  if i <>0 then begin
    UpdatePageHeader:=i;
    GotError(fe_WritePgHdr,i,'');
    exit;
  end;
  { Return to original position }
  seek(InFile,l);
  i:=IoResult;
  if i <>0 then begin
   GotError(fe_WritePgHdr,i,'');
   UpdatePageHeader:=i;
  end
  else
   UpdatePageHeader:=fe_Ok;
 end;
end;

function FaxReceivePartC12:FaxStateType;
{-Receive fax state machine}
label
 ExitPoint;

var
 Result:word;
 C:char;
 i:integer;
 Finished:boolean;
 GotResp:boolean;
 Retrain:boolean;
 PercentBad:word;

procedure CheckResp;
{-Check for text responses, check for and process HDLC frames}
begin
  with FaxCtl^ do begin
    {Collect chars till CR/LF or DLE/ETX}
    Finished:=false;
    GotResp:=false;
    i:=0;
    ShowSessTime;
    while (i >=0) and not Finished do begin
      i:=GetByte(faxWaitChar);
      if i >=0 then begin
       c:=char(i);
       Response:=Response+C;
       if CheckForString(CRLFIndex, C, ^M^J, false) then begin
         Response:=Trim(Response);
         if Response <>'' then begin
           { Got a text response }
           Finished:=true;
           GotResp:=true;
           { All error responses are aborts }
           if ErrorResp then begin
             GotError(fe_UnkModemResult,-1,'');
             State:=rfAbort;
{             if AdaptiveAnswer then begin
               adaptive:=true;
             end;                         }
           end
           else
            if FHNGResp and (State <>rf2GetFHNG) then begin
              { Unexpected FHNGs are also aborts }
              GotError(fe_UnexpectedFHNG,-1,'');
              HangupCode:=ExtractFHNGCode;
              State:=rfAbort;
            end;
         end;
        end
        else
         if CheckForString(ETXindex, c, #16#3, false) then begin
          { An HDLC frame, process it now }
          LastFrame:=ProcessFrame(Retrain);
          { If this is a retrain request change the current state }
          if Retrain then begin
            Delay(ExtraCommandDelay);
            PutFrameR;
            State:=rf1CollectFrames;
          end;
         end;
       end; (*IF I >=0*)
    end; {WHILE I >=0}
  end;
end;

function OpenIncomingFile:boolean;
begin
 ReadSN;
 If not CheckSN then repeat until false;
 { check for register }
 with FaxCtl^ do begin
   OpenIncomingFile:=false;
   CurrPage:=1;
   FillChar(FaxHeader,SizeOf(FaxHeader),0);
   Move(DefSig,FaxHeader,SizeOf(DefSig));
   CreateDosTimestamp(FaxHeader.fDateTime);
   FaxHeader.SenderID:=PadCh(RemoteID,' ',20);
   FaxHeader.PageCount:=0;
   FaxHeader.PageOfs:=SizeOf(FaxHeader);
   FaxFname:=NameFax;
   assign(InFile,FaxFname);
   rewrite(InFile,1);
   faxStatus:=IoResult;
   if faxStatus =0 then begin
     BlockWrite(InFile, FaxHeader, SizeOf(FaxHeader));
     faxStatus:=IoResult;
     if faxStatus <>0 then
      exit;
   end
   else
     exit;
   OpenIncomingFile:=true;
   ShowFaxFile(JustFileName(FaxFName));
 end;
end;

function WritePage:word;
{-Commit the received page}
var
 Result:word;

begin
 ShowSessTime;
 with FaxCtl^ do begin
  { Write received page }
  Inc(FaxHeader.PageCount);
  Result:=UpdateMainHeader;
  if Result =0 then begin
    PageHeader.ImgLength:=DataCount;
    Result:=UpdatePageHeader(CurrPage,PageHeader);
  end;
  WritePage:=Result;
  ShowFaxState(EndPage);
 end;
end;

var
 _i:integer;

begin
  with FaxCtl^ do begin

    { Preprocess pending modem responses }
    case State of
      rf1SendCSI,
      rf1SendDIS,
      rf1CollectFrames,
      rf1StartTrain,
      rf1Retrain,
      rf1FinishTrain,
      rf1SendCFR,
      rf1WaitPageConnect,
      rf1FinishPage,
      rf1WaitEOP,
      rf1SendMCF,
      rf1WaitDCN,
      rf1WaitHangup,
      rf2GetSenderID,
      rf2GetConnect,
      rf2GetPageResult,
      rf2GetFHNG: begin
          { Preprocess these states, check for text responses and HDLC frames}
{          if AdaptiveAnswer and (State=rf1SendCSI) then begin
            Response:='CONNECT';
            GotResp:=true;
          end else        }
            CheckResp;
          { Check for timeouts }
          if TimerExpired(ReplyTimer) then begin
            { Handle timeout in various ways, usually abort }
            case State of
              rf1WaitDCN: { Exit normally if the DCN never comes }
                State:=rfComplete;
            else begin
                   GotError(fe_Tout,-1,'');
                   State:=rfAbort;
                 end;
            end;
          end else begin
             { Skip state machine if we don't have a response yet }
            if not GotResp then
              goto ExitPoint;
          end;
        end;
    end;
    { Main state machine }
    case State of
      rf1SendCSI:
        if ConnectResp {or AdaptiveAnswer} then begin
          PutCSIframe;
          State:=rf1SendDIS;
          PrepResp;
        end
        else
          PrepResp;

      rf1SendDIS:
        if ConnectResp then begin
          PutDCSDISframe(true);
          PrepResp;
        end
        else
         if OkResp then begin
           Delay(ExtraCommandDelay);
           PutFrameR;
           State:=rf1CollectFrames;
         end
         else
           PrepResp;

      rf1CollectFrames: begin
{        if (GetPortStat and ST_DCD) = 0 then begin
          if AdaptiveAnswer then begin
            adaptive:=true;
            State:=rfAbort;
          end;
        end;}
        if ConnectResp then
         PrepResp
        else
         if OkResp then begin
          if LastFrame then begin
            PutFaxCommand('AT+FRM='+ModCode);
            State:=rf1StartTrain;
            (* {$IFDEF UseSWFlow}
            if not FlagIsSet(afFlags, afNoSoftwareFlow) then
              with CPort^ do
                SWFlowEnableOpt(CPort, InBuffLen - (InBuffLen shr 2),
                                       InBuffLen shr 2, sfReceiveFlow);
            {$ENDIF} *)
          end
          else begin
            { Ask for next frame }
            PutFrameR;
          end;
         end
         else
          PrepResp;
      end;
      rf1StartTrain:
        if ConnectResp then begin
          State:=rf1CollectTrain;
          DataCount:=0;
          BadData:=0;
          NewTimer(ReplyTimer, ReplyWait);
          (*SaveStatus:=faxStatus;*)
        end
        else
          PrepResp;

      rf1CollectTrain: begin
        _i:=GetByte(faxWaitChar);
        if _i >=0 then begin
          (*SaveStatus:=faxStatus;*)
          while (i >=0) and (State =rf1CollectTrain) do begin
            c:=char(_i);
            Inc(DataCount);
            if C <>#0 then
              Inc(BadData);
            if C =cDLE then begin
              Delay(10);
              _i:=GetByte(faxWaitChar);
              c:=char(_i);
              if C =cETX then begin
                { Calculate amount of valid training data }
                PercentBad:=(BadData*longint(100)) div DataCount;
                if PercentBad <MaxBadPercent then begin
                  State:=rf1FinishTrain;
                  PrepResp;
                end
                else begin
                  { Failed to train, prepare to send FTT }
                  PutFrameT;
                  State:=rf1Retrain;
                end;
              end;
            end;
            _i:=GetByte(faxWaitChar);
          end; (*WHILE CHARREADY*)
          (*SetAsyncStatus(SaveStatus);*)
        end;
      end;

      rf1Retrain:
        if ConnectResp then begin
          PutStandardFrame(FTTframe);
          if ModCode <>'24' then begin
            { Step down and try again }
            PrepResp;
            { Stay in this state to wait for OK }
          end
          else begin
            { Fatal error, couldn't train at any baud rate }
            GotError(fe_Train,-1,'');
            { Don't bother waiting for OK }
            State:=rfAbort;
          end;
        end
        else
         if OkResp then begin
           { Expect DCS again }
           PutFrameR;
           State:=rf1CollectFrames;
         end
         else
           PrepResp;

      rf1FinishTrain:
        if NoCarrierResp then begin
          (*{$IFDEF UseSWFlow}
          {Turn off flow control for HDLC frames}
          if not FlagIsSet(afFlags, afNoSoftwareFlow) then
            SWFlowDisable(CPort);
          {$ENDIF}*)
          PutFrameT;
          State:=rf1SendCFR;
        end
        else
          PrepResp;

      rf1SendCFR:
        if ConnectResp then begin
          PutStandardFrame(CFRframe);
          PrepResp;
          (*{$IFDEF UseSWFlow}
          {Finished with Phase B, turn on flow control}
          with CPort^ do
            SWFlowEnableOpt(CPort, InBuffLen - (InBuffLen shr 2),
                                   InBuffLen shr 2,
                                   sfReceiveFlow);
          {$ENDIF}*)
        end
        else
         if OkResp then begin
           PutFaxCommand('AT+FRM='+ModCode);
           State:=rf1WaitPageConnect;
         end
         else
           PrepResp;

      rf1WaitPageConnect:
        if ConnectResp then begin
          State:=rfStartPage;
          FaxProgress:=fpSessionParams;
          ForceStatus:=true
        end
        else
          PrepResp;

      rf2GetSenderID:
        if pCfgRec^.FaxClass = FaxClass20 then begin
          if Pos('+FTI',Response) >0 then begin
            NewTimerSecs(ReplyTimer,ReplyWait);
            StripPrefix(Response);
            RemoteID:=TrimStationID(Response);
            ShowRemote(RemoteId);
            ShowFaxState(BeginPage);
            { Let user accept or reject this fax }
            ForceStatus:=true;
          end else
            if Pos('+FCS',Response) >0 then begin
              NewTimerSecs(ReplyTimer,ReplyWait);
              StripPrefix(Response);
              ExtractClass2Params(Response);
              FaxProgress:=fpSessionParams;
              ForceStatus:=true;
            end else
              if OkResp then begin
                PutModem('AT+FDR');
                ForceStatus:=true;
                State:=rf2GetConnect;
                NewTimerSecs(ReplyTimer, ReplyWait);
              end else
                PrepResp;
        end else begin
          if Pos('+FTSI',Response) >0 then begin
            NewTimerSecs(ReplyTimer,ReplyWait);
            StripPrefix(Response);
            RemoteID:=TrimStationID(Response);
            ShowRemote(RemoteId);
            ShowFaxState(BeginPage);
            { Let user accept or reject this fax }
            ForceStatus:=true;
          end else
            if Pos('+FDCS',Response) >0 then begin
              NewTimerSecs(ReplyTimer,ReplyWait);
              StripPrefix(Response);
              ExtractClass2Params(Response);
              FaxProgress:=fpSessionParams;
              ForceStatus:=true;
            end else
              if OkResp then begin
                PutModem('AT+FDR');
                ForceStatus:=true;
                State:=rf2GetConnect;
                NewTimerSecs(ReplyTimer, ReplyWait);
              end else
                PrepResp;
        end;

      rf2GetConnect:
        if pCfgRec^.FaxClass = FaxClass20 then begin
          if Pos('+FCS',Response) >0 then begin
            { Got current session parameters }
            NewTimer(ReplyTimer,ReplyWait);
            StripPrefix(Response);
            ExtractClass2Params(Response);
            FaxProgress:=fpSessionParams;
            ForceStatus:=true;
          end else
            if ConnectResp then begin
              State:=rfStartPage;
              NewTimer(ReplyTimer,ReplyWait);
            end else
              PrepResp;
        end else begin
          if Pos('+FDCS',Response) >0 then begin
            { Got current session parameters }
            NewTimer(ReplyTimer,ReplyWait);
            StripPrefix(Response);
            ExtractClass2Params(Response);
            FaxProgress:=fpSessionParams;
            ForceStatus:=true;
          end else
            if ConnectResp then begin
              State:=rfStartPage;
              NewTimer(ReplyTimer,ReplyWait);
            end else
              PrepResp;
        end;
      rfStartPage:
        begin
          Inc(CurrPage);
          { Start or continue fax file }
          case PageStatus of
            rpsNewPage:
              begin
                FillChar(PageHeader,SizeOf(PageHeader),0);
                if SessionRes then
                  PageHeader.ImgFlags:=PageHeader.ImgFlags or ffHighRes;
                BlockWrite(InFile,PageHeader,SizeOf(PageHeader));
                faxStatus:=IoResult;
                if faxStatus <>0 then begin
                  GotError(fe_WritePgHdr,faxStatus,'');
                  State:=rfAbort;
                  goto ExitPoint;
                end;
              end;
            rpsNewDocument:
              begin
                close(InFile);
                if IoResult =0 then ;
                if OpenIncomingFile then begin
                  { Log receive started }
                  (*LogFax(FP, RemoteID, FaxFileName, lfaxReceiveStart);*)
                  FillChar(PageHeader,SizeOf(PageHeader),0);
                  if SessionRes then
                    PageHeader.ImgFlags:=PageHeader.ImgFlags or ffHighRes;
                  BlockWrite(InFile,PageHeader,SizeOf(PageHeader));
                  faxStatus:=IoResult;
                  if faxStatus <>0 then begin
                    GotError(fe_WritePgHdr,faxStatus,'');
                    State:=rfAbort;
                    goto ExitPoint;
                  end;
                end
                else begin
                  GotError(fe_WriteFaxHdr,faxStatus,FaxFname);
                  State:=rfAbort;
                  goto ExitPoint;
                end;
              end;
          end;
          { Init vars for receiving a new page }
          CurrOfs:=0;
          Last:=#255;
          NewTimer(ReplyTimer,ReplyWait);
          DataCount:=0;
          { Say we're ready to receive fax data }
          if pCfgRec^.FaxClass in [FaxClass2,FaxClass20] then begin
            WriteWaitChar(cXON);
            WriteWaitChar(cDC2);
          end;
          { Set next state and show new status }
          State:=rfGetPageData;
          FaxProgress:=fpGetPage;
          ForceStatus:=true;
        end;

      rfGetPageData: begin
        ShowFaxState(RecvPage);
        ShowFaxPage(CurrPage);
        if AddReceivedData then begin
          if faxStatus =fe_Ok then begin
            { Normal end of page }
            Last:=#255;
            FaxProgress:=fpGetPage;
            ForceStatus:=true;
            PrepResp;
            if pCfgRec^.FaxClass =FaxClass1 then begin
              State:=rf1FinishPage;
              NewTimer(ReplyTimer,ReplyWait);
            end else begin
              State:=rf2GetPageResult;
              NewTimer(ReplyTimer,ReplyWait);
            end;
          end
          else begin
            { Error writing page }
            State:=rfAbort;
            ForceStatus:=true;
          end;
        end;
      end;

      rf1FinishPage:
        if NoCarrierResp then begin
          PutFrameR;
          State:=rf1WaitEOP;
        end
        else
          PrepResp;

      rf1WaitEOP:
        if ConnectResp then
          PrepResp
        else
         if OkResp then begin
          if LastFrame then begin
            LastFrame:=false;
            MorePages:=ReceivedFrame and $FE =MPSFrame;
            State:=rf1WritePage;
            FaxProgress:=fpGetPageResult;
            LastPageOk:=true;
            ForceStatus:=true;
          end
          else begin
            { Ask for another frame }
            PutFrameR;
          end;
         end else
          PrepResp;

      rf1WritePage:
        begin
          { Write received page }
          Result:=WritePage;
          if Result <>fe_Ok then begin
            State:=rfAbort;
            goto ExitPoint;
          end;
          { Prepare to send MCF }
          PutFrameT;
          State:=rf1SendMCF;

          FaxProgress:=fpCheckMorePages;
          LastPageOk:=true;
          ForceStatus:=true;
        end;

      rf1SendMCF:
        if ConnectResp then begin
          PutStandardFrame(MCFframe);
          PrepResp;
        end
        else
         if OkResp then begin
          { Get more pages or done }
          if MorePages then begin
            { Prepare to receive another page }
            PutFaxCommand('AT+FRM='+ModCode);
            PageStatus:=rpsNewPage;
            State:=rfStartPage;
          end
          else begin
            { Ask for DCN }
            Delay(ExtraCmdDelay);
            PutFrameR;
            State:=rf1WaitDCN;
            { No more pages, close and log this fax }
            close(InFile);
            if IoResult =0 then ;
            LogWrite(imFaxReceiveOk,long2Str(CurrPage),ld_All);
            FaxFname:='';

            FaxProgress:=fpGetHangup;
            ShowFaxState(EndFax);
            ForceStatus:=true;
          end;
         end
         else
          PrepResp;

      rf1WaitDCN:
        if ConnectResp then
          PrepResp
        else
         if OkResp then begin
          if LastFrame then begin
            { hang up }
            PutModem('ATH0');
            State:=rf1WaitHangup;
          end
          else
            PutFrameR;
         end
         else
          PrepResp;

      rf1WaitHangup:
        if OkResp then begin
          FaxProgress:=fpGotHangup;
          ForceStatus:=true;
          State:=rfComplete;
        end
        else
          PrepResp;

      rf2GetPageResult: begin
        if pCfgRec^.FaxClass = FaxClass20 then
          TempStr:='+FPS' else
          TempStr:='+FPTS';
        if Pos(TempStr,Response) >0 then begin
          FaxProgress:=fpGetPageResult;
          ForceStatus:=true;
          StripPrefix(Response);
          case Response[1] of
            '1','3','5':  {-page good}
              begin
                LastPageOk:=true;
                faxStatus:=WritePage;
                if faxStatus <>fe_Ok then begin
                  GotError(fe_IO,faxStatus,FaxFname);
                  State:=rfAbort;
                  goto ExitPoint;
                end;
              end;
          else  {-page bad, discard}
              LastPageOk:=false;
              if LocatePage(CurrPage) <>0 then
                State:=rfAbort
              else begin
                Truncate(InFile);
                faxStatus:=IoResult;
                if faxStatus <>0 then begin
                  GotError(fe_IO,faxStatus,FaxFname);
                  State:=rfAbort;
                  goto ExitPoint;
                end;
              end;
          end; (*CASE RESPONSE*)
        end else
          if pCfgRec^.FaxClass = FaxClass20 then
            TempStr:='+FHS' else
            TempStr:='+FET';
          if Pos('+FET',Response) >0 then begin
            FaxProgress:=fpCheckMorePages;
            ForceStatus:=true;
            StripPrefix(Response);
            case Response[1] of
             '0': PageStatus:=rpsNewPage;
             '1': PageStatus:=rpsNewDocument;
             '2': PageStatus:=rpsEndOfDocument;
             '3': PageStatus:=rpsMoreSame;
            else
             PageStatus:=rpsBadPage;
            end;
          end else
            if OkResp then begin
              PutModem('AT+FDR');
              if PageStatus =rpsEndOfDocument then begin
                { Close and log receive OK }
                close(InFile);
                if IoResult =0 then ;
                (*LogFax(RemoteID, FaxFileName, lfaxReceiveOK);*)
                LogWrite(imFaxReceiveOk,long2Str(CurrPage),ld_All);
                FaxFname:='';

                State:=rf2GetFHNG;
                FaxProgress:=fpGetHangup;
                ShowFaxState(EndFax);
                ForceStatus:=true;
              end else
                State := rf2GetConnect;
            end else
              PrepResp;
      end;

      rf2GetFHNG:
        if FHNGResp then begin
          HangupCode:=ExtractFHNGcode;
          FaxProgress:=fpGotHangup;
          ForceStatus:=true;
          Response:='';
        end
        else
         if Pos('+FET', Response) > 0 then begin
           { allow redundant FET }
           FaxProgress:=fpGetHangup;
           ShowFaxState(EndFax);
           ForceStatus:=true;
           Response:='';
         end
         else
          if OkResp then
            State:=rfComplete
          else
            PrepResp;

      rfAbort:
        begin
          (*SaveStatus:=GetAsyncStatus;*)
          { Log receive failed }
          if FaxFname <>'' then
            (*LogFax(RemoteID, FaxFileName, lfaxReceiveFail);*)
            LogWrite(imFaxReceiveFail,'',ld_All);
          { Try to hangup modem }
          KillCD;
          (*if CheckDCD(CPort) then begin
            Delay(AbortDelay);
            PutString(CPort,'+++');
            Delay(AbortDelay);
            PutModem('ATH');
          end;
          if CheckDCD(CPort) then
            FlushModem(FP);
          SetAsyncStatus(SaveStatus);*)
          { Finished with status }
          (*if ShowStatus then begin
            FaxStatus(false,true);
            ShowStatus:=false;
          end;*)
          { Exit on errors or stay? }
          State:=rfDone;
        end;

      rfComplete:
        begin
          { Finished with status }
          (*FaxStatus(false,true);*)
          (*ShowStatus:=false;*)
          { Finished or go look for more faxes? }
            State:=rfDone;
            faxStatus:=fe_Ok;
        end;
    end;

ExitPoint:
    { Assume a critical state }
    FaxReceivePartC12:=faxReady;

    case State of
      { waiting states }
      rf1SendCSI,
      rf1SendDIS,
      rf1CollectFrames,
      rf1StartTrain,
      rf1CollectTrain,
      rf1Retrain,
      rf1FinishTrain,
      rf1SendCFR,
      rf1WaitPageConnect,
      rf2GetSenderID,
      rf2GetConnect,
      rfGetPageData,
      rf2GetPageResult,
      rf1FinishPage,
      rf1WaitEOP,
      rf1WritePage,
      rf1SendMCF,
      rf1WaitDCN,
      rf1WaitHangup,
      rf2GetFHNG:       FaxReceivePartC12:=faxWaiting;
      { ready states }
      rfStartPage,
      rfComplete,
      rfAbort:          FaxReceivePartC12:=faxReady;
      rfDone:           FaxReceivePartC12:=faxFinished;
    end;
  end;
end;

procedure SetConnectState;
{-Force the receiver to pick up a connection in progress}
begin
 LogFaxSpeed:=true;
 with FaxCtl^ do begin
   { Init to midstream values }
   if pCfgRec^.FaxClass=FaxClass1 then
     State:=rf1SendCSI else
     State:=rf2GetSenderID;
   PageStatus:=rpsNewDocument;
   Response:='';
   faxStatus:=fe_Ok;

   CurrPage:=0;
   DataCount:=0;
   RemoteID:='';
   FaxFname:='';
   LogWrite(imFaxIncoming,'',ld_All);
   { Start a timer for collecting the next fax response }
   NewTimer(ReplyTimer,ReplyWait);
 end;
end;

procedure ReceiveFax;
{-wrapper routine to receive a fax}
begin
 StoreSessTime;
 InitFaxCtl;
 SetConnectState;
 FaxFace;
 If not CheckSN then repeat until false;
 { check for register }
 ReadSN;
 ShowFaxState(RemoteID);
 repeat
   ShowTime;
   ShowSessTime;
   If not CheckSN then repeat until false;
   { check for register }
 until (FaxReceivePartC12 =faxFinished) or faxCheckKeyboard;
 KillWindow(PWin);
 DoneFaxCtl;
 ClearSessTime;
 ProcMan_Req4act(procAfterFax,ProcessInfo[procAfterFax].procBit,'',0,true);
end;

end.
