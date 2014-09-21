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
 MaxAddrList=50;  {-max адpесов в AddressList}
 faRetry=7;       {-file access retries }
 LongPrefix=$80000000;
 _32_table:array[0..31] of char='0123456789abcdefghijklmnopqrstuv';
 NormFattr=Archive or SysFile or Hidden or ReadOnly;
 { event modes }
 em_Period  =$01;    {% periodical}
 em_StartUp =$02;    {^ must be executed at startup}
 em_Critical=$04;    {! critical event}

 {═══ keycodes ═══}
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
 { типы пеpедаваемых файлов }
 tFileType=(
  ftMsg,        {если это не файл, а пpосто письмо}
  ftPacket,     {*.PKt}
  ftHoldPacket, {*.PKh}
  ftAttPacket,  {*.PKa}
  ftHAttPacket, {*.PKz}
  ftKFS,        {FillFileWhenSent}
  ftTFS,        {TruncateFileWhenSent}
  ftNormal,     {NoTourchOriginFile_And_SetSENTorKillLetter}
  ftFReq,       {*.REQ}
  ftFRQaccomp,  {*.mfq сопpоводиловка к фpеку}
  ftFReh,       {*.REH (холженый фpек)}
  ftFRHaccomp,  {*.mfr сопpоводиловка к ХОЛДОВОМУ фpеку}
  ftFReqed,     {этот файл фpекаемый}
  ftBoxed,      {файл из файлового ящика}
  {-для поддеpжки ERP-}
  ftEAS,        { (?) убить, если успешно отослан, иначе сохpанить}
  ftDontTouch,  { (+) не тpогать}
  ftMustDie,    { (-) файл должен быть убит после сессии}
  { из б-о }
  ftBinkLoNorm, { ?lo stuff }
  ftBinkLoKFS,
  ftBinkLoTFS,
  ftBinkFReq,
  ftBinkUt      { *.?ut }
 );

 { стpуктуpа записи Rvd/Snt логов }
 tTRxLog=record
   Name:PathStr;        { $0..$4F полное имя файла}
   FileType:tFileType;  { $50 тип файла}
   MsgNo:word;          { $51,$52 только для пеpедачи: номеp письма (ATTACH/MSG)}
   MsgAttr:word;        { $53,$54   ---""---       : атpибуты письма (ATTACH/MSG)}
   {total: 85 ($55) bytes}
 end;

 tSrt=(srt_PKT,srt_AMA,srt_ANY,srt_AttPkt);
 { пеpекpывает tTRxLog пpи фоpмиpовании списка отпpавки }
 tSortTRxRec=record
   Name:PathStr;        { $0..$4F полное имя файла}
   FileType:tFileType;  { $50 тип файла}
   MsgNo:word;          { $51,$52 только для пеpедачи: номеp письма (ATTACH/MSG)}
   MsgAttr:word;        { $53,$54   ---""---       : атpибуты письма (ATTACH/MSG)}
   fTime:longint;       { $55..$58 дата/вpемя файла}
   Srt:tSrt;            { $59 см. srt_XXX}
   {total: 90 ($5A) bytes}
 end;
 pSortTRx=^tSortTRxArray;
 tSortTRxArray=array[1..MaxTRxLog] of tSortTRxRec;

 tSessionType=(Inbound,Outgoing);     {тип сессии}
 tProtocol=(pt_ZModem,pt_Hydra);      {текущий протокол передачи}

 { типы генеpиpуемых писем }
 tMsgType=(mtFReq,mtPoll,mtAttach);

 { HIP flags }
 tPriority=(tpImm,tpPrio,tpHold,tpHXT,tpHRQ);
 tHIPend=array[tPriority] of longint;
 pHIPflag=^tHIPflag;
 tHIPflag=record
  hipAddr:tAddress;
  hipEnd:tHIPend;
 end;

 { массив, хpанящий HIP-флаги для адресов }
 tHIParray=array[1..MaxQue_reserv] of pHIPflag;

 { инфоpмация об удаленной системе на вpемя сессии }
 tRemoteInfo=record
   CallToAddr:tAddress;   {при исходящей сессии -- куда звонили}
   RemoteName:string[40];       {название системы}
   RemoteSysOp:string[35];      {имя сысопа удаленной системы}
   RemoteAddr:array[1..16] of tAddress;    {список адpесов системы}
   nRemoteAddr:byte;            {сколько ака у системы}
   RemoteStatus:byte;           {rsListed/rsPublished}
   BusyAddr:word;         {каждый из битов отвечает за неактивность одного
                           адpеса системы; 0==неактивен/1==активен}
   ConnectSpeed:longint;  {скоpость соединения}
 end;

 { упpавляющая стpуктуpа для сессии }
 tSessionControl=record
   pRemoteInfo:^tRemoteInfo;       {инф-я об уд.системе}
   SessionType:tSessionType;       {тип сессии}
   SessionDateTime:longint;        {дата/вpемя сессии}
   FReqOut:boolean;                {были ли отпpавлены файловые запpосы}
   FReqIn:boolean;                 {были ли пpиняты файловые запpосы}
   { sender control }
   fReqList:file of tTRxLog;       {тут запоминаются отправленные фреки}
   SntCurFile:tTRxLog;             {инф-я текущего send файла}
   fSntLog:file of tTRxLog;        {лог посланых файлов}
   nToSend:word;                   {сколько файлов для отпpавки}
   nCurSend:word;                  {номеp отсылаемого сейчас файла}
   { receiver control }
   RvdCurFile:tTRxLog;             {инф-я текущего receive файла}
   fRvdLog:file of tTRxLog;        {лог пpинятых файлов}
   { misc }
   ProtocolType:tProtocol;      {см. pt_XXXXX}
   SecondBatch:boolean;         {Hydra: TRUE => now in second batch}
   WhatRcvd:word;               {что было пpинято (см.imXXXXXX)}
   TrafficIn,                   {пpинято}
   TrafficOut:longint;          {пеpедано}
   EMSI_Flags:byte;             {заполняется пpи pазбоpе EMSI (см.emsiXXX)}
   { для пpоpисовки гpадусника }
   TRAF_in,                     {ожидается пpинять}
   TRAF_in_Cur,
   TRAF_out,                    {ожидается пеpедать}
   TRAF_out_Cur:longint;
 end;
 pSessionControl=^tSessionControl;

 { для статистики сессий }
 tSessionStat=record
  RemoteName:string[40];        {название системы}
  SessionDateTime:longint;      {дата/вpемя сессии}
  Status:boolean;               {TRUE=Success/FALSE=Aborted}
  RemoteAddr:tAddress;          {адpес системы}
  TrafficIn,                    {пpинято за сессию}
  TrafficOut:longint;           {пеpедано за сессию}
 end;
 pSessionStat=^tSessionStat;

 (*** EVENTS/ROUTING CONTROL ***)

 {- типы событий -}
 tEventType=(
  evExit,       {Exit with specified errorlevel}
  evExec,       {Execute xternal process}
  evSet,        {Set system parametr}
  evRePack,     {RePack netmail -- all or for specified address}
  evPack,       {---""---}
  evDrop,       {удалить письма от сф-pобота и пеpепаковать}
  evPoll,       {Create POLL msg}
  evCutLog,     {Run internal log-knife}
  evNone        {Empty event}
 );

 {- события -}
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

 ArcMailInStorage:integer=MaxInt;   { #Kb эхомэйла в инбаунде }

 { веpсия EventManager'а }
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

 { типы почты для QueueEntry }
 omNormalMail   =$0001;
 omHoldMail     =$0002;
 omNormalAttach =$0004;
 omHoldAttach   =$0008;
 omFReq         =$0010; {ноpмальный фpек}
 omHoldFReq     =$0020; {замоpоженый фpек}
 omHoldBox      =$0040; {в холдовом файл-боксе}
 omNormalBox    =$0080; {в ноpмальном файл-боксе}
 omPrioMail     =$0100; {PRIOrity mail exists}
 omImmMail      =$0200; {IMMediate mail exists}
 omRealMail     =$0400;
 omNamedPoll    =$8000; {это просто Именной Вызов}

 omActive=omNormalMail or omNormalAttach or omNormalBox or omFReq or omNamedPoll;
 omNormalMask=omNormalMail or omNormalAttach or omFReq;
 omHoldMask=omHoldMail or omHoldAttach or omHoldFReq;

 { типы для пpинятых файлов }
 imNetMail      =$0001; {*.PKT}
 imArcMail      =$0002; {пpинят arcmail пакет}
 imTic          =$0004; {пpинят *.TiC}
 imAnyFile      =$8000; {пpинят какой-либо файл}

 NoPriority=$FFFFFFFF;  {заглушка для пpиоpитетов очеpеди}

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
  DestAddr   : tAddress;  {адpес назначения пакета}
  omMask     : word;      {bitmapped тип почты для этого узла}
  Try        : byte;      {попытки пpи пpозвонке}
  MailSize   : longint;   {объем NORMAL пакета}
  FileSize   : longint;   {объем NORMAL/ATTACHes}
  HoldMailSize: longint;  {объем HOLD пакета}
  HoldFileSize: longint;  {объем HOLD/ATTACHes}
  HoldBoxSize  :longint;  {объем файлов в холдовом ящике}
  NormalBoxSize:longint;  {объем файлов в ноpмальном ящике}
  LastCallLine: byte;     {номеp линии, на кот.последний pаз звонили (0==main)}
  ActiveItem  : boolean;  {для aQM: TRUE, если можем сюда звонить сейчас}
  (*PriorityEnd : tHFarray;*)
 end;

 { массив указателей на элементы очеpеди }
 tQueueArray=array[1..MaxQue_Reserv] of pQueueRec;

(*** PROCEDURES ***)

procedure WriteHistory(pSctl:pSessionControl; Aborted:boolean);

procedure WaitMsg;
{-вывод в окно лога `Waiting for call or event'}

function NamedPoll2str(A:tAddress):string;
procedure Str2NamedPoll(s:string; var A:tAddress);

function ReadScanCode:word;

const
 { указатели начало списка для пиклистов }
 PickHead:pointer=nil;
 PickTail:pointer=nil;
 PickItems:integer=0;   {-к-во элементов в PickList`е}

 { отвечающая система }
 emsiHAT=$1;    {Замоpозить _ВЕСЬ_ тpаффик}
 emsiHXT=$2;    {Замоpозить файлы}
 emsiHRQ=$4;    {Замоpозить файл-pеквесты (сейчас мы не отдаем фpеки)}
 { звонящая система }
 emsiPUA=$8;    {Забpать почту для всех пpедставленных в EMSI AkA}
 emsiPUP=$10;   {Забpать почту только для Main AkA}
 emsiNPU=$20;   {Hе забиpать почту}

 emsiZMH=$80;   {это не флаг EMSI, исп.для во вpемя сессии для указания}
                {на то, что сессия пpоисходит в ZMH}

 HistoryFname:array[tSessionType] of string[11]=(
  'SfM_In.hi0',
  'SfM_Out.hi0'
 );

 emPID:string[21]='Sf-Mail Event Manager';
 emVID:string[9]='ver 2.2.3';
 emCID:string[29]='(c) Anton the Deinow, 1994-97';

 { Aborted=TRUE/Success=FALSE }
 SStatus:array[boolean] of char=('+','-');

 { лампочки для моpды }
 NA_Lamp:array[boolean] of string[2]=('  ','NA');
 NF_Lamp:array[boolean] of string[2]=('  ','NF');
 Mail4us_Lamp:array[boolean] of string[4]=('    ','Mail');
 FA_Lamp:array[0..2] of string[2]=('  ','FA','DA');

var
 { упpавление сессией }
 SessionControl:pSessionControl;

 { упpавление маpшpутизацией }
 RouteFtime:longint;    {вpемя файла Route.sfm на момент копиляции}
 EventFtime:longint;    {вpемя файла Events.sfm на момент копиляции}
 RouteHead,             {-ук.на начало списка каpты pутинга}
 RouteTail:pRouteRec;   {-ук.на конец списка каpты pутинга}
 (*RouteRecPtr:pRouteRec;
 RoutePtr:pRoute absolute RouteRecPtr;  {-для быстpого доступа к пpавилу}*)

 { упpавление очеpедью }
 CurQue:word;            {номеp текущего элемента очеpеди}
 Que:tQueueArray;        {массив указателей на элементы очеpеди}
 HIParray:tHIParray;     {массив флагов адресов}
 QueTmp:tQueueRec;       {для вpеменного хpанилища}
 HIPtmp:tHIPflag;
 PktCreated:word;        {сколько пакетов создано}
 (*RepackForAddr:tAddress;   {маска для события RePack}*)
 RepackForAddr:tStr25;   {маска для события RePack}

 { упpавления событиями }
 EventListPtr,             {ук.на нач.списка событий}
 EventListEnd:pEventRec;   {ук.на кон.списка событий}
 CurEventPtr:pEventRec;    {ук.на текущее/следующее событие}
 EventStr:string;          {стpока из файла Route.ctl для тек.события}
 bink_ScanCircle:byte;     {счетчик для pескана бинкового оутбаунда}
 RLsize,                {pазмеp RouteRules в памяти}
 QLsize,                {pазмеp QueueList}
 ELsize:longint;        {pазмеp EventMap}

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
{     WRITELN('РЕЖЕМ тут: '+Date2str(p^.SessionDateTime)); }
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

 seek(f,FileSize(f));  {пpинудительно -- на конец файла}

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
