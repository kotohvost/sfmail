{$I-,X+,O+,F+,V-}
{$I SfDefine.inc}
UNIT EmStruct;

INTERFACE

uses
 aTime,
 MsgXs,
 Config,
 Tstring_,
 Dos;

const
 MaxQue=300;
 MaxQue_reserv=400;
 MaxTRxLog=300;
 MaxAddrList=50;  {-max ��p�ᮢ � AddressList}
 faRetry=7;       {-file access retries }
 LongPrefix=$80000000;
 _32_table:array[0..31] of char='0123456789abcdefghijklmnopqrstuv';
 NormFattr=Archive or SysFile or Hidden or ReadOnly;
 { event modes }
 em_Period  =$01;    {% periodical}
 em_StartUp =$02;    {^ must be executed at startup}
 em_Critical=$04;    {! critical event}

 {��� keycodes ���}
 keyNull =$0000;
 {--- keypad ---}
 keyEsc  =$001B;
 keyUp   =$4800;
 keyDn   =$5000;
 keyPgUp =$4900;
 keyPgDn =$5100;
 keyHome =$4700;
 keyEnd  =$4F00;
 keyLeft =$4B00;
 keyRight=$4D00;
 keyDel  =$5300;
 keyGrayPlus=$002B;
 keyGrayMinus=$002D;
 {--- Fns ---}
 keyF1   =$3B00;
 keyAltF1=$6800;
 keyF10  =$4400;
 {--- Misc ---}
 keyEnter=$000D;
 keyTab  =$0009;
 keyBS   =$0008;
 keyCtrlEnter=$000A;
 keyCtrlPgUp=$8400;
 keyCtrlPgDn=$7600;
 keySpace=$0020;
 {--- alphas ---}
 keyCtrlA=$0001;
 keyAltB =$3000;
 keyC    =$0063;
 keyShC  =$0043;
 keyAltC =$2E00;
 keyAltF =$2100;
 keyAltG =$2200;
 keyH    =$0068;
 keyShH  =$0048;
 keyAltH =$2300;
 {keyCtrlH=$0008;}
 keyI    =$0069;
 keyShI  =$0049;
 keyAltI =$1700;
 keyAltK =$2500;
 keyAltM =$3200;
 keyAltN =$3100;
 keyAltO =$1800;
 keyP    =$0070;
 keyShP  =$0050;
 keyAltP =$1900;
 keyQ    =$0071;
 keyShQ  =$0051;
 keyAltQ =$1000;
 keyAltR =$1300;
 keyAltS =$1F00;
 keyCtrlS=$0013;
 keyU    =$0075;
 keyShU  =$0055;
 keyAltU =$1600;
 keyX    =$0078;
 keyShX  =$0058;
 keyAltY =$1500;

 MaxItemLen=76;   {max length of picklist`s items}

type
 { ⨯� ��p��������� 䠩��� }
 tFileType=(
  ftMsg,        {�᫨ �� �� 䠩�, � �p��� ���쬮}
  ftPacket,     {*.PKt}
  ftHoldPacket, {*.PKh}
  ftAttPacket,  {*.PKa}
  ftHAttPacket, {*.PKz}
  ftKFS,        {FillFileWhenSent}
  ftTFS,        {TruncateFileWhenSent}
  ftNormal,     {NoTourchOriginFile_And_SetSENTorKillLetter}
  ftFReq,       {*.REQ}
  ftFRQaccomp,  {*.mfq ᮯp���������� � �p���}
  ftFReh,       {*.REH (宫���� �p��)}
  ftFRHaccomp,  {*.mfr ᮯp���������� � ��������� �p���}
  ftFReqed,     {��� 䠩� �p������}
  ftBoxed,      {䠩� �� 䠩������ �騪�}
  {-��� �����p��� ERP-}
  ftEAS,        { (?) 㡨��, �᫨ �ᯥ譮 ��᫠�, ���� ��p�����}
  ftDontTouch,  { (+) �� �p�����}
  ftMustDie,    { (-) 䠩� ������ ���� 㡨� ��᫥ ��ᨨ}
  { �� �-� }
  ftBinkLoNorm, { ?lo stuff }
  ftBinkLoKFS,
  ftBinkLoTFS,
  ftBinkFReq,
  ftBinkUt      { *.?ut }
 );

 { ��p���p� ����� Rvd/Snt ����� }
 tTRxLog=record
   Name:PathStr;        { $0..$4F ������ ��� 䠩��}
   FileType:tFileType;  { $50 ⨯ 䠩��}
   MsgNo:word;          { $51,$52 ⮫쪮 ��� ��p����: ����p ���쬠 (ATTACH/MSG)}
   MsgAttr:word;        { $53,$54   ---""---       : ��p����� ���쬠 (ATTACH/MSG)}
   {total: 85 ($55) bytes}
 end;

 tSrt=(srt_PKT,srt_AMA,srt_ANY,srt_AttPkt);
 { ��p��p뢠�� tTRxLog �p� �p��p������ ᯨ᪠ ��p���� }
 tSortTRxRec=record
   Name:PathStr;        { $0..$4F ������ ��� 䠩��}
   FileType:tFileType;  { $50 ⨯ 䠩��}
   MsgNo:word;          { $51,$52 ⮫쪮 ��� ��p����: ����p ���쬠 (ATTACH/MSG)}
   MsgAttr:word;        { $53,$54   ---""---       : ��p����� ���쬠 (ATTACH/MSG)}
   fTime:longint;       { $55..$58 ���/�p��� 䠩��}
   Srt:tSrt;            { $59 �. srt_XXX}
   {total: 90 ($5A) bytes}
 end;
 pSortTRx=^tSortTRxArray;
 tSortTRxArray=array[1..MaxTRxLog] of tSortTRxRec;

 tSessionType=(Inbound,Outgoing);     {⨯ ��ᨨ}
 tProtocol=(pt_ZModem,pt_Hydra);      {⥪�騩 ��⮪�� ��।��}

 { ⨯� ����p�p㥬�� ��ᥬ }
 tMsgType=(mtFReq,mtPoll,mtAttach);

 { HIP flags }
 tPriority=(tpImm,tpPrio,tpHold,tpHXT,tpHRQ);
 tHIPend=array[tPriority] of longint;
 pHIPflag=^tHIPflag;
 tHIPflag=record
  hipAddr:tAddress;
  hipEnd:tHIPend;
 end;

 { ���ᨢ, �p���騩 HIP-䫠�� ��� ���ᮢ }
 tHIParray=array[1..MaxQue_reserv] of pHIPflag;

 { ���p���� �� 㤠������ ��⥬� �� �p��� ��ᨨ }
 tRemoteInfo=record
   CallToAddr:tAddress;   {�� ��室�饩 ��ᨨ -- �㤠 �������}
   RemoteName:string[40];       {�������� ��⥬�}
   RemoteSysOp:string[35];      {��� ��ᮯ� 㤠������ ��⥬�}
   RemoteAddr:array[1..16] of tAddress;    {ᯨ᮪ ��p�ᮢ ��⥬�}
   nRemoteAddr:byte;            {᪮�쪮 ��� � ��⥬�}
   RemoteStatus:byte;           {rsListed/rsPublished}
   BusyAddr:word;         {����� �� ��⮢ �⢥砥� �� ����⨢����� ������
                           ��p�� ��⥬�; 0==����⨢��/1==��⨢��}
   ConnectSpeed:longint;  {᪮p���� ᮥ�������}
 end;

 { �p������� ��p���p� ��� ��ᨨ }
 tSessionControl=record
   pRemoteInfo:^tRemoteInfo;       {���-� �� �.��⥬�}
   SessionType:tSessionType;       {⨯ ��ᨨ}
   SessionDateTime:longint;        {���/�p��� ��ᨨ}
   FReqOut:boolean;                {�뫨 �� ��p������ 䠩���� ���p���}
   FReqIn:boolean;                 {�뫨 �� �p����� 䠩���� ���p���}
   { sender control }
   fReqList:file of tTRxLog;       {��� ������������ ��ࠢ����� �४�}
   SntCurFile:tTRxLog;             {���-� ⥪�饣� send 䠩��}
   fSntLog:file of tTRxLog;        {��� ��᫠��� 䠩���}
   nToSend:word;                   {᪮�쪮 䠩��� ��� ��p����}
   nCurSend:word;                  {����p ���뫠����� ᥩ�� 䠩��}
   { receiver control }
   RvdCurFile:tTRxLog;             {���-� ⥪�饣� receive 䠩��}
   fRvdLog:file of tTRxLog;        {��� �p������ 䠩���}
   { misc }
   ProtocolType:tProtocol;      {�. pt_XXXXX}
   SecondBatch:boolean;         {Hydra: TRUE => now in second batch}
   WhatRcvd:word;               {�� �뫮 �p���� (�.imXXXXXX)}
   TrafficIn,                   {�p����}
   TrafficOut:longint;          {��p�����}
   EMSI_Flags:byte;             {���������� �p� p����p� EMSI (�.emsiXXX)}
   { ��� �p�p�ᮢ�� �p���᭨�� }
   TRAF_in,                     {��������� �p�����}
   TRAF_in_Cur,
   TRAF_out,                    {��������� ��p�����}
   TRAF_out_Cur:longint;
 end;
 pSessionControl=^tSessionControl;

 { ��� ����⨪� ��ᨩ }
 tSessionStat=record
  RemoteName:string[40];        {�������� ��⥬�}
  SessionDateTime:longint;      {���/�p��� ��ᨨ}
  Status:boolean;               {TRUE=Success/FALSE=Aborted}
  RemoteAddr:tAddress;          {��p�� ��⥬�}
  TrafficIn,                    {�p���� �� ����}
  TrafficOut:longint;           {��p����� �� ����}
 end;
 pSessionStat=^tSessionStat;

 (*** EVENTS/ROUTING CONTROL ***)

 {- ⨯� ᮡ�⨩ -}
 tEventType=(
  evExit,       {Exit with specified errorlevel}
  evExec,       {Execute xternal process}
  evSet,        {Set system parametr}
  evRePack,     {RePack netmail -- all or for specified address}
  evPack,       {---""---}
  evDrop,       {㤠���� ���쬠 �� ��-p���� � ��p���������}
  evPoll,       {Create POLL msg}
  evCutLog,     {Run internal log-knife}
  evNone        {Empty event}
 );

 {- ᮡ��� -}
 pEventRec=^tEventRec;
 tEventRec=record
  NextEvent:pEventRec;    {0..3}
  EventType:tEventType;   {4}
  EventMode:byte;         {5  see em_XXXX above}
  Executed:boolean;       {6}
  TimePeriod:tTimePeriod; {7..0B}
  Period:word;            {0C..0D  for periodical events}
  LastExec:longint;       {0E..11 unixtime of last execution}
  StrOfs:longint;         {12..15}
 end;

 tRouteRule=(
  rrDirect,     {AkA NORMAL}
  rrDirectFile, {send files directly for}
  rrCrash,      {crash for addresslist}
  rrHold,       {hold for addresslist}
  rrUnhold,     {except from hold list}
  rrImmediate,  {ignore work time}
  rrMailTo,     {route addresslist to target}
  rrMailFrom,   {route mail from addrlist to target}
  rrFileTo,     {files routing}
  rrDefault,
  rrError   {incorrect route command}
 );

const
 NoLink=nil;
 { temporary storage for string data for internal use }
 tmpSt:string='';

 ArcMailInStorage:integer=MaxInt;   { #Kb �宬���� � ����㭤� }

 { ��p�� EventManager'� }
 EventManVer:string[3]=#2#2#4;

 RouteSavName:string[6]='Route.';
 QueueSavName:string[6]='Queue.';
 EventSavName:string[6]='Event.';
 HIPsavName  :string[7]='HIPflg.';

 RepackDirName='REPACK.FLG';

 sRouteRule:array[rrDirect..rrFileTo] of string[12]=(
  'direct',
  'direct-files',
  'crash',
  'hold',
  'unhold',
  'immediate',
  'route-to',
  'route-from',
  'files-to'
 );

 sEventRule:array[tEventType] of string[6]=(
  'exit',
  'exec',
  'set',
  'repack',
  'pack',
  'drop',
  'poll',
  'cutlog',
  ''
 );

 { ⨯� ����� ��� QueueEntry }
 omNormalMail   =$0001;
 omHoldMail     =$0002;
 omNormalAttach =$0004;
 omHoldAttach   =$0008;
 omFReq         =$0010; {��p����� �p��}
 omHoldFReq     =$0020; {����p����� �p��}
 omHoldBox      =$0040; {� 宫����� 䠩�-����}
 omNormalBox    =$0080; {� ��p���쭮� 䠩�-����}
 omPrioMail     =$0100; {PRIOrity mail exists}
 omImmMail      =$0200; {IMMediate mail exists}
 omRealMail     =$0400;
 omNamedPoll    =$8000; {�� ���� ������� �맮�}

 omActive=omNormalMail or omNormalAttach or omNormalBox or omFReq or omNamedPoll;
 omNormalMask=omNormalMail or omNormalAttach or omFReq;
 omHoldMask=omHoldMail or omHoldAttach or omHoldFReq;

 { ⨯� ��� �p������ 䠩��� }
 imNetMail      =$0001; {*.PKT}
 imArcMail      =$0002; {�p���� arcmail �����}
 imTic          =$0004; {�p���� *.TiC}
 imAnyFile      =$8000; {�p���� �����-���� 䠩�}

 NoPriority=$FFFFFFFF;  {�����誠 ��� �p��p��⮢ ��p���}

type
 pRouteRec=^tRouteRec;
 tRouteRec=record
  NextRule:pRouteRec;
  Flavour:tRouteRule;
  ToAddr:tAddress;
  TimePeriod:tTimePeriod;
  RuleStr:string;
 end;

 pRouteH=^tRouteH;
 tRouteH=record
  NextRule:pRouteRec;
  Flavour:tRouteRule;
  ToAddr:tAddress;
  TimePeriod:tTimePeriod;
  RuleStr:byte;
 end;

 pQueueRec=^tQueueRec;
 tQueueRec=record
  DestAddr   : tAddress;  {��p�� �����祭�� �����}
  omMask     : word;      {bitmapped ⨯ ����� ��� �⮣� 㧫�}
  Try        : byte;      {����⪨ �p� �p�������}
  MailSize   : longint;   {��ꥬ NORMAL �����}
  FileSize   : longint;   {��ꥬ NORMAL/ATTACHes}
  HoldMailSize: longint;  {��ꥬ HOLD �����}
  HoldFileSize: longint;  {��ꥬ HOLD/ATTACHes}
  HoldBoxSize  :longint;  {��ꥬ 䠩��� � 宫����� �騪�}
  NormalBoxSize:longint;  {��ꥬ 䠩��� � ��p���쭮� �騪�}
  LastCallLine: byte;     {����p �����, �� ���.��᫥���� p�� ������� (0==main)}
  ActiveItem  : boolean;  {��� aQM: TRUE, �᫨ ����� � ������� ᥩ��}
  (*PriorityEnd : tHFarray;*)
 end;

 { ���ᨢ 㪠��⥫�� �� �������� ��p��� }
 tQueueArray=array[1..MaxQue_Reserv] of pQueueRec;

(*** PROCEDURES ***)

procedure WriteHistory(pSctl:pSessionControl; Aborted:boolean);

procedure WaitMsg;
{-�뢮� � ���� ���� `Waiting for call or event'}

function NamedPoll2str(A:tAddress):string;
procedure Str2NamedPoll(s:string; var A:tAddress);

function ReadScanCode:word;

const
 { 㪠��⥫� ��砫� ᯨ᪠ ��� ������⮢ }
 PickHead:pointer=nil;
 PickTail:pointer=nil;
 PickItems:integer=0;   {-�-�� ������⮢ � PickList`�}

 { �⢥���� ��⥬� }
 emsiHAT=$1;    {����p����� _����_ �p��䨪}
 emsiHXT=$2;    {����p����� 䠩��}
 emsiHRQ=$4;    {����p����� 䠩�-p������� (ᥩ�� �� �� �⤠�� �p���)}
 { ������� ��⥬� }
 emsiPUA=$8;    {���p��� ����� ��� ��� �p���⠢������ � EMSI AkA}
 emsiPUP=$10;   {���p��� ����� ⮫쪮 ��� Main AkA}
 emsiNPU=$20;   {H� ����p��� �����}

 emsiZMH=$80;   {�� �� 䫠� EMSI, ��.��� �� �p��� ��ᨨ ��� 㪠�����}
                {�� �, �� ���� �p���室�� � ZMH}

 HistoryFname:array[tSessionType] of string[11]=(
  'SfM_In.hi0',
  'SfM_Out.hi0'
 );

 emPID:string[21]='Sf-Mail Event Manager';
 emVID:string[9]='ver 2.2.3';
 emCID:string[29]='(c) Anton the Deinow, 1994-97';

 { Aborted=TRUE/Success=FALSE }
 SStatus:array[boolean] of char=('+','-');

 { �����窨 ��� ��p�� }
 NA_Lamp:array[boolean] of string[2]=('  ','NA');
 NF_Lamp:array[boolean] of string[2]=('  ','NF');
 Mail4us_Lamp:array[boolean] of string[4]=('    ','Mail');
 FA_Lamp:array[0..2] of string[2]=('  ','FA','DA');

var
 { �p������� ��ᨥ� }
 SessionControl:pSessionControl;

 { �p������� ��p�p�⨧�樥� }
 RouteFtime:longint;    {�p��� 䠩�� Route.sfm �� ������ ������樨}
 EventFtime:longint;    {�p��� 䠩�� Events.sfm �� ������ ������樨}
 RouteHead,             {-�.�� ��砫� ᯨ᪠ ��p�� p�⨭��}
 RouteTail:pRouteRec;   {-�.�� ����� ᯨ᪠ ��p�� p�⨭��}
 (*RouteRecPtr:pRouteRec;
 RoutePtr:pRoute absolute RouteRecPtr;  {-��� ����p��� ����㯠 � �p�����}*)

 { �p������� ��p���� }
 CurQue:word;            {����p ⥪�饣� ������� ��p���}
 Que:tQueueArray;        {���ᨢ 㪠��⥫�� �� �������� ��p���}
 HIParray:tHIParray;     {���ᨢ 䫠��� ���ᮢ}
 QueTmp:tQueueRec;       {��� �p�������� �p������}
 HIPtmp:tHIPflag;
 PktCreated:word;        {᪮�쪮 ����⮢ ᮧ����}
 (*RepackForAddr:tAddress;   {��᪠ ��� ᮡ��� RePack}*)
 RepackForAddr:tStr25;   {��᪠ ��� ᮡ��� RePack}

 { �p������� ᮡ��ﬨ }
 EventListPtr,             {�.�� ���.ᯨ᪠ ᮡ�⨩}
 EventListEnd:pEventRec;   {�.�� ���.ᯨ᪠ ᮡ�⨩}
 CurEventPtr:pEventRec;    {�.�� ⥪�饥/᫥���饥 ᮡ�⨥}
 EventStr:string;          {��p��� �� 䠩�� Route.ctl ��� ⥪.ᮡ���}
 bink_ScanCircle:byte;     {���稪 ��� p�᪠�� ��������� ��⡠㭤�}
 RLsize,                {p����p RouteRules � �����}
 QLsize,                {p����p QueueList}
 ELsize:longint;        {p����p EventMap}

IMPLEMENTATION

uses
 RelTQ,
 TpCrt,
 WriteLog,
 Modem;

procedure WriteHistory(pSctl:pSessionControl; Aborted:boolean);
var
 toDay:longint;
 f,f1:file of tSessionStat;
 p:pSessionStat;
 done:boolean;
 a1,a2:longint;

begin
 GetMem(p,SizeOf(tSessionStat));

 assign(f,HistoryFname[pSctl^.SessionType]);
 reset(f);
 if IoResult <>0 then rewrite(f)
 else
  if FileSize(f) >1 then begin
   CreateDosTimeStamp(toDay);
   done:=false;
   repeat
    read(f,p^);
    if (DateType(toDay).Date-DateType(p^.SessionDateTime).Date) <= pCfgRec^.KeepHistory then begin
     done:=true;
{     WRITELN('����� ���: '+Date2str(p^.SessionDateTime)); }
     a2:=pred(FilePos(f));
     if a2 <>0 then begin
      seek(f,a2);
      assign(f1,'History.$!$'); rewrite(f1);
      repeat
        read(f,p^); write(f1,p^);
      until EOF(f);
      close(f1);
      close(f); erase(f);
      rename(f1,HistoryFname[pSctl^.SessionType]);
      reset(f);
     end;
    end
    else
     if EOF(f) then done:=true;
   until done;
  end;

 seek(f,FileSize(f));  {�p��㤨⥫쭮 -- �� ����� 䠩��}

 p^.RemoteName:=pSctl^.pRemoteInfo^.RemoteName;
 p^.SessionDateTime:=pSctl^.SessionDateTime;
 p^.RemoteAddr:=pSctl^.pRemoteInfo^.RemoteAddr[1];
 p^.TrafficIn:=pSctl^.TrafficIn;
 p^.TrafficOut:=pSctl^.TrafficOut;
 p^.Status:=Aborted;
 write(f,p^);
 close(f);

 FreeMem(p,SizeOf(tSessionStat));
end;

procedure WaitMsg;
begin
 LogWrite(imWaitMsg,'',ld_Screen or ld_LastLn);
end;

function NamedPoll2str(A:tAddress):string;
var
 aa:array[1..8] of char absolute A;
 i:byte;
 s:string[8];

begin
 s:='';
 i:=1;
 while aa[i] <>#0 do begin
  s:=s+aa[i];
  Inc(i);
 end;
 NamedPoll2str:=s;
end;

procedure Str2NamedPoll(s:string; var A:tAddress);
begin
 if Pos('.',s) <>0 then
  Delete(s,Pos('.',s),4);
 FillChar(A,SizeOf(tAddress),0);
 Move(s[1],A,Length(s));
end;

function ReadScanCode:word;
var
 {sc:word;}
 ch:char;

begin
 while not KeyPressed do begin
   ReleaseTQ;
   if AskExit then begin
     ReadScanCode:=$00;
     exit;
   end;
 end;

 ch:=readkey;
 if ch =#0 then begin
   ch:=readkey;
   ReadScanCode:=word(ord(ch) shl 8);
 end
 else
   ReadScanCode:=ord(ch);
end;

end.
