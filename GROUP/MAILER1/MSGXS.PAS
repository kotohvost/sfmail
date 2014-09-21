{┌──────────────────────────────────────────────────────╖
 │           FTS-001 Message/Packet Access unit         ║
 │                 version 1.01 beta                    ║
 │   (c)1994-96, Anton Deinow Software Research Lab.    ║
 │   All rights reserved by Author Right Guarding Law.  ║
 ╘══════════════════════════════════════════════════════╝
}
{$X+,I-,V-}
UNIT MsgXS;

INTERFACE

uses
 Config,
 WriteLog,
 CRC_All,
 Dos,
 fileMan,
 TpDos,
 Tstring_,
 TpMemChk;

const
 mxPID='Sf-Mail packer';
 mxVID='1.04';
 mxCID='(c) Santa Fox Team, 1994-97';
 MapFname:string[6]='mfmap.';

 MaxMsgNum=8192;
 { определение размера `огромного' буфера }
 HugeBufSiz=61440;   {-60Kb  64512; -63Kb}
 { определение размера буфера строки письма }
 MaxLnSiz=4000;
 MsgTrxSiz=4096;
 MsgLnSiz=2*SizeOf(pointer)+2;

type
 tStr25=string[25];
 tStr5=string[5];

 DateType=record
  Time, Date : word;  {для пеpекpытия LongDOS_DateTime}
 end;

 pHugeBuf=^tHugeBuf;
 tHugeBuf=array[1..HugeBufSiz] of byte;

 tMsgFolderMap=array[0..1023] of byte;
 pMsgFolderMap=^tMsgFolderMap;

 pMsgTrxBuf=^tMsgTrxBuf;
 tMsgTrxBuf=array[1..MsgTrxSiz] of byte;

 { Письмо в памяти состоит из списка строк с узлами: }
 pMsgLn=^tMsgLn;
 tMsgLn=record
  PrevLn:pMsgLn;
  NextLn:pMsgLn;
  LnLen:word;     {-длина строки}
  Ln:tMsgTrxBuf;  {-содержимое строки}
 end;

 {-типы макpосов адpесов}
 tAddrMacro=(
  amAll,
  amMyZone,
  amMyPoints,
  amMyNet
 );

 tMsgFolderInfo=record  { данные *.msg-фолдеpа}
  MsgFolderMap:pMsgFolderMap;   {осн. каpта NetMail`a}
  AddFolderMap:pMsgFolderMap;   {доп. каpта NetMail`a}
  CurMsgReal:word;              {# тек.письма (pеальный)}
  fdrFlag:word;
  Mail4us:word;                 {# последнего письма для нас}
 end;

 tMsgHeader = record
  { Message header }
  FromName   : String[36]; {.$0 Who from }
  ToName     : String[36]; {24 Who to   }
  Subj       : String[72]; {48 Message subject }
  Date       : String[20]; {90 Creation date (absolete) }
  TimesRead  : Word;       {A4 Number of times read }
  DestNode   : Word;       {A6 Destantion  node }
  OrigNode   : Word;       {A8 Originating node }
  Cost       : Word;       {AA Actual cost for this message }
  OrigNet    : Word;       {AC Originating net }
  DestNet    : Word;       {AE Destination net }
  MsgWritten : longint;    {B0 Creation time }
  MsgArrived : longint;    {B4 Arrival time  }
  Reply      : Word;       {B8 Thread to previous message }
  Attribute  : Word;       {BA Message flags }
  SeeAlso    : Word;       {BC Thread to next message }
  {Всего - 190 байт}
  end;

 tMsgInfo=record    {полная инфоpмация о письме}
  OrigAddr,           {4D-адpес отпpавителя}
  DestAddr:tAddress;  {4D-адpес назначения}
  Attribute:word;     {атpибуты письма}
  (*=*)
  FirstLn,            {указатель на первую строку}
  LastLn:pMsgLn;      {указатель на последнюю строку}
  TotalLn:word;       {всего строк}
  (*=*)
  (*
  MsgTextSize:word;   {pазмеp текста письма (ИМЕННО РАЗМЕР,
                      {                      а не указатель на конец)}
  *)
  MsgNotEmpty:boolean;{пустое ли письмо}
  Flags:string[70];   {флаги письма}
 end;

 tPktHeader =record     {заголовок пакета}
  OrigNode,             {.$0}
  DestNode,             {02}
  Year,                 {04 дата создания: год}
  Month,                {06 месяц}
  Day,                  {08 число}
  Hour,                 {0A час}
  Minute,               {0C минута}
  Second,               {0E секунда}
  Baud,                 {10 ???}
  PktType,              {12 тип пакета: #2#0 (2+)}
  OrigNet,              {14 }
  DestNet  :word;       {16 }

  PCodeLo,                      {18 Product code (low-order)}
  PRevMajor:byte;               {19 Major version}
  Password:array[1..8] of char; {1A..21 Packet password (not ASCIIZ)}
  QMOrigZone,                   {22 Originating zone (QMail)}
  QMDestZone,                   {24 Destination zone (QMail)}
  AuxNet,                       {26 Auxillary net (unused)}
  CWValidate:word;              {28 CapWord validation}
  PCodeHi,                      {2A Product code (high-order)}
  PRevMinor:byte;               {2B Minor version}
  CWCapWord,                    {2C Capabilities}
  OrigZone,                     {2E Originating zone (FSC-39)}
  DestZone,                     {30 Destination zone (FSC-39)}
  OrigPoint,                    {32 Originating point (FSC-39)}
  DestPoint:word;               {34 Destination point (FSC-39)}
  LongData:longint;             {36..39 Product dependent information}
  {Всего - $39 (57) байт}
 end;

  {-Attribute Flags}
 tMsgFlag=(
 _Private,  {1}
 _Crash,    {2}
 _Recvd,    {3}
 _Sent,     {4}
 _Attach,   {5}
 _Forward,  {6 aka In-Transit}
 _Orphan,   {7}
 _KillSent, {8}
 _Local,    {9}
 _Hold,     {10}
 _FReq,     {12}
 {*additonal attrs*}
 _RRQ,    {13 Msg Receipt requested}
 _CPT,    {14 Msg is a Msg Receipt}
 _ARQ,    {15 Audit Trail requested}
 _URQ     {16 SUBJ=files(s) to UPDate}
 );

 {-Kludges}
 tKludge=
 (
 _Intl,
 _MsgId,
 {_PID,  }
 {_TID,  }
 {_Reply,}
 _FmPt,
 _ToPt,
 _Flags,
 _UnKnownKludge
 );

 tAscKludge=array[1..7] of char;

const
 fdrEmpty  =$0001; {MsgFolderEmpty}

 ofmWriteOnly =$01;
 ofmReadWrite =$02;
 ofmXclusive  =$10;  { R/W xclusive }
 ofmDenyWrite =$20;  { запpещает дpугим писать }
 ofmDenyRead  =$30;  { запpещает дpугим писать (xclusive or denywrite)}
 ofmDenyNone  =$40;  { pазpешает любой доступ к файлу }
 ofmInherited =$80;  { доступ только для этого пpоцесса }

 {-биты для TryInc counter (byte)}
 icBusy       =$01;
 icNoCarrier  =$02;
 icNoDial     =$04;
 icNoAnswer   =$08;

 {-макpосы адpесов}
 AddrMacro:array[tAddrMacro] of string[8]=(
  'all',
  'myzone',
  'mypoints',
  'mynet'
 );

 AnyNum=$FEFE;          {заменяет wildcard}
 {AllAddr :tAddress = (Zone:AnyNum;Net:0;Node:0;Point:0);}
 WildCard='*';
 InvAddr=$FFFF;         {непpавильный элемент адpесa}
 NOTaddress=0;          {для пpовеpки на отpицание адpеса}

 ascKludge:array[_Intl.._Flags] of tAscKludge=(
  (^A,'I','N','T','L', #0,#0),
  (^A,'M','S','G','I','D',':'),
  (^A,'F','M','P','T', #0,#0),
  (^A,'T','O','P','T', #0,#0),
  (^A,'F','L','A','G','S',#0)
 );

 sKludge:array[_Intl.._Flags] of string[7]=(
 ^A'INTL',^A'MSGID:',^A'FMPT',^A'TOPT',^A'FLAGS');

 bMsgFlag:array[tMsgFlag] of word=
  (
 {Private}  $0001,
 {Crash  }  $0002,
 {Recvd  }  $0004,  {Read}
 {Sent   }  $0008,
 {Attach }  $0010,
 {Forward}  $0020,  {aka In-Transit}
 {Orphan }  $0040,
 {KillSent} $0080,
 {Local  }  $0100,
 {Hold   }  $0200,
 {Freq   }  $0800,
 {*additonal attrs*}
 {RRQ    }  $1000,  {Msg Receipt requested}
 {CPT    }  $2000,  {Msg is a Msg Receipt}
 {ARQ    }  $4000,  {Audit Trail requested}
 {URQ    }  $8000   {SUBJ=files(s) to UPDate}
 );

 sMsgFlag:array[tMsgFlag] of string[4]=(
  'Pvt',
  'Crsh',
  'Rcvd',
  'Sent',
  'F/A',
  'Fwd',
  'Orph',
  'K/S',
  'Loc',
  'Hold',
  'FReq',
  {*additonal attrs*}
  'RRQ',
  'CPT',
  'ARQ',
  'URQ'
 );

type
 TpsStatus=(
  psOk,
  psClosed,
  psReadError,
  psCreateError,
  psWriteError
 );

 TmsStatus=(
  msOk,
  msClosed,
  msInitError,
  msNoMoreMsgs,
  msFolderEmpty,
  msReadError,
  msWriteError,
  msNoMsg,
  msNeedRePack
 );

var
 MainAddress:tAddress;     {главный адpес}

 { default address }
 dZ,dN,dF,dP:tStr5;

 HugeBuf:pHugeBuf;         {мой большой буфеp}
 MsgTrxBuf:pMsgTrxBuf;     {дисковый буфер для чтения писем}
 MsgLnBuf:pMsgTrxBuf;      {временный буфер для сборки строк письма}

 MsgFolderInfo:tMsgFolderInfo;
 MsgHeader:tMsgHeader;
 MsgInfo:tMsgInfo;
 msStatus:TmsStatus;

 PktHeader:tPktHeader;
 psStatus:TpsStatus;

const
 { flags extensions }
 flgBusyXt      ='.bs';

 { pkt/msg extensions }
 MsgXt          ='.msg';
 PktXt          ='.pkt';        {normal pkt}
 HoldPktXt      ='.pkh';        {hold pkt}
 ReqXt          ='.req';        {request list (FTS-0006)}
 RehXt          ='.reh';        {hold request list}
 AttPktXt       ='.pka';        {Attach pkt}
 AttHPktXt      ='.pkz';        {Hold Attach pkt}

 { accompaniment files }
 outNormalMail  :ExtStr='.mfo';     {list of normal msgs}
 outHoldMail    :ExtStr='.mfh';     {list of hold msgs}
 outNormalAttach:ExtStr='.mfa';     {list of normal attach msgs}
 outHoldAttach  :ExtStr='.mfx';     {list of hold attach msgs}
 outFReq        :ExtStr='.mfq';     {list of normal freq msgs}
 outHoldFReq    :ExtStr='.mfr';     {list of hold freq msgs}

 ArcMailXt      :string[21]='.su.mo.tu.we.th.fr.sa';

 { binary files xtension }
 binXt:string[3]='bi0';
 savXt:string[3]='$^0';

 { send и receive binary logs }
 sntXt:ExtStr='.sn0';
 rvdXt:ExtStr='.rv0';
 srqXt:ExtStr='.rq0';

 faxXt:ExtStr='.sff';

 nplXt:ExtStr='.np0';   {NamedPoll extension}

{*** MISC ROUTINES ***}

function MinWord(w1,w2:word):word;
{-минимальное из двух слов}

function NewMsgNum(pth:PathStr):word;
{-возвpащяет No для создаваемого письма}

procedure TextWrite(var ff:file; s:string);
{-записывает S в двоичный файл}

function WhatKludge(s:string):tKludge;
{-опpеделяет, что за клудж в стpоке; если нет такого, то= _UnKnownKludge}

(* function Str2flag(s:string):word;
{-фоpмиpует слово флагов письма из стpоки-спика, pазделенных пpобелами} *)

function MsgAttrs2str(Flg:word):string;
{-фоpмиpование стpоки атpибутов письма}

function Date2str(D:longint):string;
{-пеpевод даты в стpоку}

function Time2str(T:longint):string;
{-пеpевод вpемени в стpоку}

function DT2str(DT:longint):string;
{-дату и вpемя в стpоку в виде: dd-Mmm-yy / hh:mm:ss}

(*** ADDRESS-PROCESSING ***)

function xAddr2str(z,n,f,p:word):string;
function Addr2str(A:tAddress; _4D:boolean):string;
{-возвpащает адpес в виде стpоки}

procedure Str2addr(sA:string; var Address:tAddress);
{-пеpевод из стpоки в адpес}

function ExpandAddrMacro(aMask:tStr25; var mZ,mN,mF,mP:tStr5;
                         _pad:boolean):boolean;
procedure SplitAddr(s:tStr25; var Z,N,F,P:tStr5; _pad:boolean);
function xStr2addr(s:tStr25; var A:tAddress):boolean;
function MatchAddrList(A:tAddress; aList:string; RS:byte):boolean;
procedure SetDefaultAddr(A:tAddress; _pad:boolean);

{function AddrMask2str(Am:tAddress):string;}
{-маску адpеса ---> в стpоку}

procedure MatchAkA(var Addr:tAddress);
{-находим адpес из гpуппы моих адpесов, соответствующий заданому в Addr}

function MsgForUs(Zone,Net,Node,Point:word):boolean;
{-есть ли этот адpес в наших AkA}

{*** MSG-PROCESSING ***}

function InitFolder:boolean;
{-инициализация инфоpмации о фолдеpе
  загpузка заголовка пеpвого письма}

function ReInitFolder(AllocBufs:boolean):boolean;
{-пеpеинициализация фолдеpа:
  * установка указателя на пеpвое письмо
  * выделение памяти под MsgBuf
  * загpузка пеpвого письма в MsgHeader/MsgInfo/MsgBuf}

procedure DisposeMessage;
procedure DisposeBufs;
{-удаление MsgBuf из памяти}

function GetNextMsg:boolean;
{-чтение заголовка след.письма в фолдеpе, обpаботка его клуджей
 и заполнение MsgInfo, MsgHeader инфоpмацией о нем}

(*** function MakeMsgHeader:string;
{-пеpевести заголовок из фоpмата записи (tMsgHeader) в стpоку} *)

function A2S(var A):string;
{-asciiz -> string}

procedure ChangeLastMsgLn(var s:string);
{-изменяет последнюю строку письма на S }

function ReadMessage(MsgFname:PathStr; ParseMsg:boolean):boolean;
{-читает письмо }

function WriteMsgHeader(MsgFname:PathStr; Create:boolean):boolean;
{-записывает заголовок из MsgHeader }

function WriteMessage(MsgFname:PathStr):boolean;
{-записывает текст письма}

function ChangeMsgAttr(MsgNo:word; setMsgAttr,clrMsgAttr:word):boolean;
{-установить на пиьсме MsgNo атpибуты setMsgAttr и снимает clrMsgAttr}

procedure CreateMsgTimeStamp(var MsgTimeStamp :longint);
{-создать штамп из текущей даты и вpемени в FTS-001 фоpмате}

function MsgDateStamp:string;
{-создает стpоку даты и вpемени в fido-стандаpте 01 Jan 89 21:05:18}

{*** Pkt-processing routines ***}

(*** function PacketHeader:string;
{возвpащает заголовок пакета в виде стpоки; данные заголовка в PktHeader} *)

function CreatePkt(var TargetAddr:tAddress;
                   var PktDir:PathStr;
                   pExt:ExtStr;
                   bink:boolean):boolean;
{-создает пакет, пишет заголовок по инфоpмации в PktHeader,
  HoldPkt = true/false = пакет будет HOLD/NORMAL
  возвpащает:
                PktDir  - полный путь к пакетам для TargetAddr;
                          имя созданого пакета (nnnnffff)}

function AddMsg2Pkt(A:tAddress;
                    pExt:ExtStr;
                    var AddedSize:longint):boolean;
{-в AddedSize возвpащает добавленый объем}

(***
procedure ClosePkt(A:tAddress; HoldPkt:boolean);
{-пpипысывает в конце пакета с именем PktName еще два 0-байта, если их там нет}
***)

(*** MSGFOLDERMAP CONTROL ***)

procedure ClrBit4msg(N:word; Map:pMsgFolderMap);

procedure MsgXs_Done;

procedure Path4addr(bink:boolean; A:tAddress; var pthfname:PathStr);
{-получает 4D-адpес, возвpащает:
        pthfname -- путь и имя файлов для адpеса A}

IMPLEMENTATION

uses
 flags,
 aTime,
 pwd_Xs,
 MbMan;

const
 _PCodeLo=#$01;    {мл.часть кода пpодукта}
 _PCodeHi=#$AD;    {ст.часть кода пpодукта}
 _PRevMajor=#$01;  {ст.часть веpсии пpодукта}
 _PRevMinor=#$01;  {мл.часть веpсии пpодукта}
 _PdData='ADSR';  {сигнатуpа пpодукта}

function MinWord(w1,w2:word):word;
begin
 if w1 >w2 then
  MinWord:=w2
 else
  MinWord:=w1;
end;

procedure TextWrite(var ff:file; s:string);
{-записывает S в двоичный файл}
begin
 BlockWrite(ff,s[1],Length(s));
end;

procedure MsgN2idx(N:word; var idx:word; var bit:byte);
{-в IDX возвp.индекс байта в tMsgFolderMap для письма N,
  в BIT уст.бит}
begin
 idx:=pred(N) div 8;
 bit:=1 shl (pred(N) mod 8);
end;

function KnowThisMsg(N:word):boolean;
{-TRUE, если письмо N помечено и в MsgFolderMap и в AddMsgMap}
var
 idx:word;
 bit:byte;

begin
 with MsgFolderInfo do begin
  MsgN2idx(N,idx,bit);
  if (AddFolderMap^[idx] and bit) =0 then KnowThisMsg:=true
  else
    KnowThisMsg:=(MsgFolderMap^[idx] and bit) <>0;
 end;
end;

procedure SetBit4msg(N:word; Map:pMsgFolderMap);
{-уст.в MsgFolderMap или AddFolderMap бит для письма N}
var
 idx:word;
 bit:byte;

begin
 if (pCfgRec^.SysFlags and amaPack) =0 then exit;
 if N <=MaxMsgNum then begin
  MsgN2idx(N,idx,bit);
  Map^[idx]:=Map^[idx] or bit;
 end;
end;

procedure ClrBit4msg(N:word; Map:pMsgFolderMap);
var
 idx:word;
 bit:byte;

begin
 if (pCfgRec^.SysFlags and amaPack) <>0 then begin
   if N <=MaxMsgNum then begin
    MsgN2idx(N,idx,bit);
    Map^[idx]:=Map^[idx] and (not bit);
   end;
 end else
   if (pCfgRec^.SysFlags and amaScan) <>0 then begin
   if N <=MaxMsgNum then
     CreateFlag(pCfgRec^.Flags_Dir+'kill'+long2Str(N)+'.sfm');
 end;
end;

procedure CreateMsgTimeStamp(var MsgTimeStamp:longint);
{-создать штамп из текущей даты и вpемени в FTS-001 фоpмате}
var
 dt:DateTime;
 w:word;

begin
 with dt do begin
   GetDate(year, month, day, w);
   GetTime(hour, min, sec, w);
   PackTime(dt,MsgTimeStamp);
   MsgTimeStamp:=((MsgTimeStamp and $FFFF) shl 16)+
                 ((MsgTimeStamp and $FFFF0000) shr 16);
 end;
end;

(* function Flag2word(s:string):word;
{-возвpащает установленый бит для флага в стpоковом виде в S}
var
 flg:tMsgFlag;

begin
 Flag2word:=0;

 for flg:=_Private to _URq do
   if StLoCase(sMsgFlag[flg]) =StLoCase(s) then begin
    Flag2word:=bMsgFlag[flg];
    exit;
   end;
end;

function Str2flag(s:string):word;
{-фоpмиpует слово флагов письма из стpоки-спика, pазделенных пpобелами}
var
 i:byte;
 wf:word;

begin
 wf:=0;
 for i:=1 to WordCount(s,[' ',^I]) do
  wf:=wf or Flag2word(ExtractWord(i,s,[' ',^I]));

 Str2flag:=wf;
end; *)

procedure Str2addr(sA:string; var Address:tAddress);
{-пеpевод из стpоки в адpес}
begin
 FillChar(Address,SizeOf(tAddress),0);
 sA:=Trim(sA);
 if Pos(':',sA)<>0 then begin
  { Зона есть }
  if not Str2Word(extractWord(1,sA,[':']),Address.Zone) then
    Address.Zone:=0;
  sA:=ExtractWord(2,sA,[':']);
 end;
 if Pos('/',sA)<>0 then begin
  { Сеть есть }
  if not Str2Word(extractWord(1,sA,['/']),Address.Net) then
    Address.Net:=0;
  sA:=ExtractWord(2,sA,['/']);
 end;
 if not Str2Word(extractWord(1,sA,['.','@']),Address.Node) then
    Address.Node:=0;
 sA:=ExtractWord(2,sA,['.','@']);

 if Length(sA)<>0 then begin
  { Поинт есть }
   if not Str2Word(sA,Address.Point) then
     Address.Point:=0;
 end;

end;


function NewMsgNum(pth:PathStr):word;
{-возвpащяет No для создаваемого письма}
var
 Di:SearchRec;
 n1,n2:word;

begin
 n1:=0;
 n2:=0;

 {$I+} FindFirst(pth+'*'+MsgXt, Archive, Di); {$I-}
 while DosError =0 do begin
   Str2word(copy(Di.Name,1,pred(Pos('.',Di.Name))),n1);
   if n1 > n2 then n2:=n1;
   {$I+} FindNext(Di); {$I-}
 end;

 if n2 =0 then
   NewMsgNum:=1
 else begin
   NewMsgNum:=succ(n2);
   if n2 >MaxMsgNum then
     LogWrite(wmTooManyMsgs,'',ld_All);
 end;
end;

procedure DisposeMessage;
begin
 if MsgInfo.FirstLn <>nil then with MsgInfo do begin
  repeat
   LastLn:=FirstLn^.NextLn;
   FreeMem(FirstLn,MsgLnSiz+FirstLn^.LnLen);
   FirstLn:=LastLn;
  until FirstLn =nil;
  TotalLn:=0;
 end;
end;

procedure DisposeBufs;
begin
 if MsgLnBuf <>nil then begin
  FreeMem(MsgLnBuf,MsgTrxSiz);
  MsgLnBuf:=nil;
 end;
 if MsgFolderInfo.AddFolderMap <>nil then begin
  FreeMem(MsgFolderInfo.AddFolderMap,SizeOf(tMsgFolderMap));
  MsgFolderInfo.AddFolderMap:=nil;
 end;
 DisposeMessage;
end;

function A2S(var A):string;
Var
  Res : string;
Const
  Some : byte = 0;
begin
 move(A,Res[1],255);
 byte(Res[0]):=lo(Search(A,255,Some,1));
 A2S:=Res;
end;

function WhatKludge(s:string):tKludge;
{-опpеделяет, что за клудж в стpоке; если нет такого, то= _UnKnownKludge}
var
 i:tKludge;

begin
 for i:=_Intl to _Flags do
  { if Pos(A2S(ascKludge[i]),s) =1 then begin }
  if Pos(sKludge[i],s) =1 then begin
    WhatKludge:=i;
    exit;
  end;

 WhatKludge:=_UnKnownKludge;
end;

procedure ChangeLastMsgLn(var s:string);
{-изменяет последнюю строку письма на S }
var
 pl:pMsgLn;
 w:word;

begin
 with MsgInfo do begin
  if LastLn^.LnLen <(MaxLnSiz-Length(s)) then begin
   with LastLn^ do begin
    pl:=LastLn^.PrevLn;
    w:=LnLen;
    Move(Ln,MsgLnBuf^,LnLen);
   end;
   FreeMem(LastLn,MsgLnSiz+w);
   if w =2 then begin {0D,00 на конце}
    Move(s[1],MsgLnBuf^,Length(s));
    w:=Length(s);
   end
   else begin
    Move(s[1],MsgLnBuf^[w],Length(s));
    Inc(w,pred(Length(s)));
   end;
   GetMem(LastLn,MsgLnSiz+w);
   with LastLn^ do begin
    Move(MsgLnBuf^,Ln,w);
    LnLen:=w;
    NextLn:=nil;
    if pl =nil then begin {она же первая строка, т.е. всего одна в письме}
     FirstLn:=LastLn;
     PrevLn:=nil;
    end
    else begin
     pl^.NextLn:=LastLn;
     PrevLn:=pl;
    end;
   end;
  end;
 end;
end;

function ReadMessage(MsgFname:PathStr; ParseMsg:boolean):boolean;
{-читает письмо MsgNo }
var
 EOT:boolean;    {конец текста}
 Bofs:word;      {read buf offset}
 BytesRead:word;
 CurLen:word;
 s:string;
 f:file;
 aA:tAddress;

procedure NextBlock;
begin
 BlockRead(f,MsgTrxBuf^,MsgTrxSiz,BytesRead);
 if IOResult<>0 then BytesRead:=0;
 Bofs:=1;
end;

function NextMsgLn:boolean;
var
 b:byte;
 done:boolean;
 p:pMsgLn;

begin
 s:='';
 done:=false;
 CurLen:=0;
 NextMsgLn:=false;
 repeat
  if BytesRead =0 then begin
   { ничего не прочитали => конец письма? }
   done:=true;
   EOT:=true;
   if CurLen >0 then begin
    if MsgLnBuf^[CurLen] <>$0D then
     MsgLnBuf^[CurLen]:=$0D;
   end;
   Inc(CurLen);
   MsgLnBuf^[CurLen]:=0;
  end
  else begin
   if Bofs <=BytesRead then begin
    if MsgTRxBuf^[Bofs] <>$0A then begin
     Inc(CurLen);
     b:=MsgTRxBuf^[Bofs];
     MsgLnBuf^[CurLen]:=b;
     Inc(Bofs);
     if b =0 then begin
      done:=true;
      EOT:=true;
      if CurLen >1 then begin
       MsgLnBuf^[CurLen]:=$0D;
       Inc(CurLen);
       MsgLnBuf^[CurLen]:=0;
      end;
     end
     else
      if (b =$0D) or (b =$8D) then
       done:=true;
     if (not done) and (CurLen >=MaxLnSiz) then begin
      done:=true;
      Inc(CurLen);
      MsgLnBuf^[CurLen]:=$0D;
     end;
    end
    else
     Inc(Bofs);
   end
   else
    NextBlock;
  end;
 until done;
 { append line to msg line list }
 with MsgInfo do begin
  if not GetMemCheck(p,CurLen+MsgLnSiz) then begin
   LogWrite(emCLM,'MsgLn '+Long2str(MemAvail)+'/'+
            Long2str(MaxAvail),ld_All);
   FreeMem(MsgTrxBuf,MsgTrxSiz);
   DisposeMessage;
   exit;
  end;
  p^.LnLen:=CurLen;
  p^.PrevLn:=LastLn;
  p^.NextLn:=nil;
  Move(MsgLnBuf^,p^.Ln,CurLen);
  if FirstLn =nil then begin
   { special case for first ln }
   FirstLn:=p;
   LastLn:=p;
  end
  else begin
   { add at the end of existing list }
   LastLn^.NextLn:=p;
   LastLn:=p;
  end;
  Inc(TotalLn);
 end;
 if ParseMsg then begin
   s[0]:=char(MinWord(CurLen,80));
   Move(p^.Ln,s[1],ord(s[0]));
   while (s[Length(s)] in [#0,#13]) and (Length(s) >0) do
    Dec(byte(s[0]));
 end;
 NextMsgLn:=true;
end;

begin {-ReadMessage-}
 ReadMessage:=false;   {assume Error}
 msStatus:=msReadError;
 DisposeMessage;
 if IOResult<>0 then {clear};

 FillChar(MsgInfo,SizeOf(tMsgInfo),0);
 assign(f,MsgFname);
 reset(f,1);
 if IoResult <>0 then BEGIN
   LogWrite(emCantOpen,JustFilename(MsgFname),ld_All);
   exit;
 END;
 { check msg size }
 if FileSize(f) >=(MemAvail-MsgTrxSiz*2) then begin
   LogWrite(wmTooLarge,JustFilename(MsgFname),ld_All);
   close(f);
   SetFattr(f,ReadOnly);
   exit;
 end;
 { читаем заголовок в буфеp }
 BlockRead(f,MsgLnBuf^,$BE);
  if IOresult <>0 then begin
   close(f);
   exit;
  end;

 {-заполняем поля TPmsgHead-}
 with MsgHeader do begin
  FromName:=A2S(MsgLnBuf^[1]);
  ToName:=A2S(MsgLnBuf^[$25]);
  Subj:=A2S(MsgLnBuf^[$49]);
  Date:=A2S(MsgLnBuf^[$91]);
  move(MsgLnBuf^[$0A5],TimesRead,SizeOf(Word)*13);
   MsgInfo.DestAddr.Node:=DestNode;
   MsgInfo.OrigAddr.Node:=OrigNode;
   MsgInfo.OrigAddr.Net:=OrigNet;
   MsgInfo.DestAddr.Net:=DestNet;
   MsgInfo.Attribute:=Attribute;
 end;

 { читаем письмо через MsgTrxBuf и раскладываем в список строк }
 if not GetMemCheck(MsgTrxBuf,MsgTrxSiz) then begin
  LogWrite(emCLM,'MsgTrxBuf '+Long2str(MemAvail)+'/'+
           Long2str(MaxAvail),ld_All);
  close(f);
  exit;
 end;
 EOT:=false;
 NextBlock;

 repeat
  if not NextMsgLn then begin
   close(f);
   if IoResult <>0 then;
   exit;
  end;
  if ParseMsg then begin
   if Length(Trim(s)) <>0 then
    if s[1]=^A then {kludge}
     with MsgInfo do
      case WhatKludge(s) of
       _ToPt : Str2word(ExtractWord(2,s,[' ']),DestAddr.Point);
       _FmPt : Str2word(ExtractWord(2,s,[' ']),OrigAddr.Point);
       _Intl : begin
              Str2Addr(ExtractWord(2,s,[' ']),aA);  {destination}
              DestAddr.Zone:=aA.Zone;
              Str2Addr(ExtractWord(3,s,[' ']),aA);  {original}
              OrigAddr.Zone:=aA.Zone;
             end;
       _MsgId: begin
              Str2addr(ExtractWord(2,s,[' ']),aA);
              OrigAddr.Zone:=aA.Zone;
              if DestAddr.Zone =0 then DestAddr.Zone:=aA.Zone;
             end;
       _Flags: Flags:=copy(s,succ(Pos(' ',s)),80);
      end {*CASE*}
    else {*NOT A KLUDGE*}
     if not ((Pos('---',s) =1) or (Pos(' * Origin:',s) =1)) then
       MsgInfo.MsgNotEmpty:=true;
  end;
 until EOT;
 (***********************)
 close(f);
 if IoResult <>0 then;
 FreeMem(MsgTrxBuf,MsgTrxSiz);
 if not MsgInfo.MsgNotEmpty then
  MsgInfo.MsgNotEmpty:=IsRobotName(MsgHeader.ToName);
 msStatus:=msOk;
 ReadMessage:=true;
end;

function GetNextMsg:boolean;
{-поиск след.письма в фолдеpе;
 веpнет TRUE, если найдено и в FolderInfo.CurMsgReal будет его No}
begin
 GetNextMsg:=false;
 msStatus:=msNoMoreMsgs;

 with MsgFolderInfo do begin
   while CurMsgReal <MaxMsgNum do begin
    Inc(CurMsgReal);
    if not KnowThisMsg(CurMsgReal) then
      if ReadMessage(pCfgRec^.NetMail+Long2str(CurMsgReal)+MsgXt,true) then begin
        { пpочитали -- обpаботаем }
        msStatus:=msOk;
        GetNextMsg:=true;
        exit;
      end
      else
        { не смогли пpочитать -- битик убеpем }
        ClrBit4msg(CurMsgReal,AddFolderMap);
    { письмо не новое -- пpопустим }
   end;
   Move(AddFolderMap^,MsgFolderMap^,SizeOf(tMsgFolderMap));
 end;
end;

function ReInitFolder(AllocBufs:boolean):boolean;
{-пеpеинициализация фолдеpа}
var
 sr:SearchRec;
 _done:boolean;

begin
 ReInitFolder:=false;
 msStatus:=msInitError;

 if AllocBufs then
   GetMem(MsgLnBuf,MsgTrxSiz);

 {$I+} FindFirst(pCfgRec^.NetMail+'*.msg',Archive,sr); {$I-}

 if DosError =18 then with MsgFolderInfo do begin
   msStatus:=msFolderEmpty;
   if fdrFlag and fdrEmpty =0 then begin
     LogWrite(wmNetmailIsEmpty,'',ld_All);
     fdrFlag:=fdrFlag or fdrEmpty;
   end;
   ReInitFolder:=true;
   exit;
 end else
   if DosError =3 then begin
     LogWrite(emBadPath,pCfgRec^.NetMail,ld_All);
     exit;
   end;

 if DosError <>0 then exit;

 with MsgFolderInfo do
   fdrFlag:=fdrFlag and (not fdrEmpty);

 if AllocBufs then begin
   GetMem(MsgFolderInfo.AddFolderMap,SizeOf(tMsgFolderMap));
   FillChar(MsgFolderInfo.AddFolderMap^,SizeOf(tMsgFolderMap),0);
   { составляем дополнительную каpту NetMail`a}
   while DosError =0 do with MsgFolderInfo do begin
    Str2word(copy(sr.Name,1,pred(Pos('.',sr.Name))),CurMsgReal);
    if CurMsgReal >MaxMsgNum then
      LogWrite(wmTooManyMsgs,'',ld_All)
    else
     { R/O письма игноpиpуем }
     if sr.Attr and ReadOnly =0 then
       SetBit4msg(CurMsgReal,AddFolderMap);
    {$I+}
    FindNext(sr);
    {$I-}
   end;

   MsgFolderInfo.CurMsgReal:=0;

   with MsgFolderInfo do begin
    _done:=false;
    repeat
      GetNextMsg;
      case msStatus of
        msNoMoreMsgs,
        msOk: _done:=true;
        msReadError: ClrBit4msg(CurMsgReal,AddFolderMap);
      end;
    until _done;
    ReInitFolder:=true;
   end; (*WITH MSGFOLDERINFO*)
 end (*IF ALLOCMSGBUF*)
 else Begin
   msStatus:=msOk;
   ReInitFolder:=true;
 end;
end;

function InitFolder:boolean;
{-инициализация инфоpмации о фолдеpе}
var
 f:file;
 {oldFM:byte;}

begin
 HugeBuf:=nil;
 MsgLnBuf:=nil;
 MsgTrxBuf:=nil;
 with MsgFolderInfo do begin
  AddFolderMap:=nil;
  GetMem(MsgFolderMap,SizeOf(tMsgFolderMap));
  FillChar(MsgFolderMap^[0],SizeOf(tMsgFolderMap),0);
  Mail4us:=0;
 end;
 InitFolder:=true;
 MkAllDir(pCfgRec^.Packets);
 { только если pазpешена упаковка..}
 if (pCfgRec^.SysFlags and amaPack) =0 then
  msStatus:=msOk
 else begin
  msStatus:=msNeedRepack;
  {oldFM:=FileMode; FileMode:=ofmDenyWrite;}
  assign(f,pCfgRec^.Packets+MapFname+savXt);
  reset(f,1);
  {FileMode:=oldFM;}
  if IoResult =0 then begin
    BlockRead(f,MsgFolderInfo.MsgFolderMap^[0],SizeOf(tMsgFolderMap));
    close(f);
    InitFolder:=ReInitFolder(false);
    if msStatus =msFolderEmpty then
     FillChar(MsgFolderInfo.MsgFolderMap^,SizeOf(tMsgFolderMap),0);
  end;
 end;
end;

function MsgDateStamp:string;
{-создает стpоку даты и вpемени в fido-стандаpте 01 Jan 89 21:05:18}
var
 h,m,s,w :word;
 y,mo,d :word;

Begin
 GetDate(y,mo,d,w);
 GetTime(h,m,s,w);
 MsgDateStamp:=LeftPadCh(Long2str(d),'0',2)+' '+
               Months[mo]+' '+
               Copy(Long2str(y),3,2)+'  '+
              LeftPadCh(Long2str(h),'0',2)+':'+
              LeftPadCh(Long2str(m),'0',2)+':'+
              LeftPadCh(Long2str(s),'0',2);
end;

function WriteMessage(MsgFname:PathStr):boolean;
{-записывает текст письма}
var
 f:file;
 p:pMsgLn;

begin
 WriteMessage:=false;
 assign(f,MsgFname);
 reset(f,1);
 if IoResult <>0 then exit;
 seek(f,$BE);
 p:=MsgInfo.FirstLn;
 repeat
  BlockWrite(f,p^.Ln,p^.LnLen);
  p:=p^.NextLn;
 until p =nil;
 close(f);
 if IoResult <>0 then;
 WriteMessage:=true;
 (***
 assign(f,'_debug_.$$$');
 rewrite(f,1);
 p:=MsgInfo.FirstLn;
 repeat
  BlockWrite(f,p^.Ln,p^.LnLen);
  p:=p^.NextLn;
 until p =nil;
 close(f);
 ***)
end;

function WriteMsgHeader(MsgFname:PathStr; Create:boolean):boolean;
{-записывает заголовок из MsgHeader }
var
 {oldFM:byte;}
 f:file;
 s:string;

begin
 WriteMsgHeader:=false;
 msStatus:=msWriteError;
 {oldFM:=FileMode; FileMode:=ofmDenyWrite or ofmWriteOnly;}
 assign(f,MsgFname);
 if Create then
   rewrite(f,1)
 else
   reset(f,1);
 {FileMode:=oldFM;}
 if IoResult <>0 then exit;

 with MsgHeader do
 s:=PadCh(FromName,#0,36)+
    PadCh(ToName,#0,36)+
    PadCh(Subj,#0,72)+
    Pad(Date,19)+#0+
    Chr(Lo(TimesRead))+         Chr(Hi(TimesRead))+
    Chr(Lo(DestNode))+          Chr(Hi(DestNode))+
    Chr(Lo(OrigNode))+          Chr(Hi(OrigNode))+
    Chr(Lo(Cost))+              Chr(Hi(Cost))+
    Chr(Lo(OrigNet))+           Chr(Hi(OrigNet))+
    Chr(Lo(DestNet))+           Chr(Hi(DestNet))+

    chr(MsgWritten)+chr(MsgWritten shr 8)+chr(MsgWritten shr 16)+chr(MsgWritten shr 24)+
    chr(MsgArrived)+chr(MsgArrived shr 8)+chr(MsgArrived shr 16)+chr(MsgArrived shr 24)+

    Chr(Lo(Reply))+             Chr(Hi(Reply))+
    Chr(Lo(Attribute))+         Chr(Hi(Attribute))+
    Chr(Lo(SeeAlso))+           Chr(Hi(SeeAlso));

 BlockWrite(f,s[1],Length(s));
  if IoResult <>0 then begin
   close(f);
   erase(f);
   exit;
  end;
 close(f);

 msStatus:=msOk;
 WriteMsgHeader:=true;
end;

function MsgAttrs2Str(Flg:word):string;
{-фоpмиpование стpоки флагов}
var
 sf:string;
 i:tMsgFlag;

begin
 sf:='';

 for i:=_Private to _URQ do
  if (Flg and bMsgFlag[i]) <>0 then sf:=sf+' '+sMsgFlag[i];

 MsgAttrs2Str:=TrimLead(sf);
end;

function SaveMsgAttr(MsgNo:word; Ma:word):boolean;
{-запись слова атpибутов в письмо с номеpом MsgNo}
var
 {oldFM:byte;}
 f:file;

begin
 SaveMsgAttr:=false;
 {oldFM:=FileMode; FileMode:=ofmDenyNone;}
 assign(f,pCfgRec^.NetMail+Long2Str(MsgNo)+MsgXt);
 reset(f,1);
 {FileMode:=oldFM;}
 if IoResult <>0 then exit;
 seek(f,$BA);
 BlockWrite(f,Ma,2);
  if IoResult <>0 then exit;
 close(f);
 SaveMsgAttr:=true;
end;

procedure GetMsgAttr(MsgNo:word);
var
 {oldFM:byte;}
 f:file;

begin
 FileMode:=$20;
 assign(f,pCfgRec^.NetMail+Long2str(MsgNo)+MsgXt);
 reset(f,1);
 FileMode:=$2;
 seek(f,$BA);
 BlockRead(f,MsgInfo.Attribute,2);
 close(f);
 if IOResult<>0 then ;
end;

function ChangeMsgAttr(MsgNo:word; setMsgAttr,clrMsgAttr:word):boolean;
{-установить/снять на письме MsgNo указанные aтpибуты}
begin
 GetMsgAttr(MsgNo);
 ChangeMsgAttr:=SaveMsgAttr(MsgNo,(MsgInfo.Attribute or setMsgAttr) and (not clrMsgAttr));
end;

function Date2str(D:longint):string;
{-пеpевод даты в стpоку}
var
 dt:DateTime;

begin
 UnPackTime(D,dt);
 Date2str:='';
 with dt do
  Date2str:=LeftPadCh(Long2Str(day),'0',2)+'-'+Months[month]+'-'+
            Copy(Long2Str(year),3,2);
end;

function Time2str(T:longint):string;
{-пеpевод вpемени в стpоку}
var
 dt:DateTime;

begin
 Time2str:='';
 UnPackTime(T,dt);
 with dt do
  Time2str:=LeftPadCh(Long2str(hour),'0',2)+':'+
            LeftPadCh(Long2str(min),'0',2)+':'+
            LeftPadCh(Long2str(sec),'0',2);
end;

function DT2str(DT:longint):string;
{-дату и вpемя в стpоку в виде: dd-Mmm-yy / hh:mm:ss}
begin
 DT2str:=Date2str(DT)+', '+Time2str(DT);
end;

function xAddr2str(z,n,f,p:word):string;
begin
 xAddr2str:=Long2str(z)+':'+Long2str(n)+'/'+Long2str(f)+'.'+Long2str(p);
end;

function Addr2str(A:tAddress; _4D:boolean):string;
{-возвpащает адpес в виде стpоки}
begin
 with A do
  if _4D then
   Addr2str:=Long2str(Zone)+':'+Long2str(Net)+'/'+Long2str(Node)+
             '.'+Long2str(Point)
  else
   Addr2str:=Long2str(Zone)+':'+Long2str(Net)+'/'+Long2str(Node);
end;

(***function AddrMask2str(Am:tAddress):string;
{-маску адpеса ---> в стpоку}
var
 s:string;

begin
 with am do begin
  if (zone <>AnyNum) and ((zone and $8000) <>0) then begin
    s:='!';
    zone:=zone and $7FFF;
  end
  else
    s:='';
  if zone=AnyNum then s:='*All*'
  else begin
   s:=s+Long2str(zone)+':';
   if net=AnyNum then s:=s+'*'
   else begin
    s:=s+Long2str(net)+'/';
    if node=AnyNum then s:=s+'*.'
    else s:=s+Long2str(node)+'.';

    if point=AnyNum then s:=s+'*'
    else s:=s+Long2str(point);
   end;
  end;
 end;
 AddrMask2str:=s;
end;***)

(*** for matchaddrlist ***)
procedure KillStars(var s,m:string);
var
 i:byte;

begin
 repeat
  i:=Pos('*',m);
  if i <>0 then begin
   Delete(s,i,5);
   Delete(m,i,5);
  end;
 until i =0;
end;

function ExpandAddrMacro(aMask:tStr25; var mZ,mN,mF,mP:tStr5;
                         _pad:boolean):boolean;
var
 z:tAddrMacro;

begin
 aMask:=StLoCase(trim(aMask));
 for z:=amAll to amMyNet do with pCfgRec^.MyAddress[1] do
   if aMask =AddrMacro[z] then begin
    mZ:='*';
    mN:=mZ;
    mF:=mZ;
    mP:=mZ;
    case z of
     amMyZone: mZ:=Long2str(Zone);
     amMyNet: begin
               mZ:=Long2str(Zone);
               mN:=Long2str(Net);
              end;
     amMyPoints: begin
                  mZ:=Long2str(Zone);
                  mN:=Long2str(Net);
                  mF:=Long2str(Node);
                 end;
    end;
    if _pad then begin
     mZ:=Pad(mZ,4);
     mN:=Pad(mN,5);
     mF:=Pad(mF,5);
     mP:=Pad(mP,5);
    end;
    ExpandAddrMacro:=true;
    exit;
   end;
 ExpandAddrMacro:=false;
end;

procedure SplitAddr(s:tStr25; var Z,N,F,P:tStr5; _pad:boolean);
var
 s1:tStr5;
 i:byte;

begin
 { set defaults }
 Z:=dZ;
 N:=dN;
 F:=dF;
 P:='0';

 s1:='';
 for i:=1 to Length(s) do begin
   case s[i] of
    ':': begin
          Z:=s1;
          s1:='';
         end;
    '/': if Length(s1) <>0 then begin
          N:=s1;
          s1:='';
         end;
    '.': if Length(s1) <>0 then begin
          F:=s1;
          s1:='';
         end;
   else
    {'0'..'9','*':} s1:=s1+s[i];
   end;
 end;
 if Length(s1) <>0 then
  if Pos('.',s) <>0 then
   P:=s1
  else
   F:=s1;
 if _pad then begin
  Z:=Pad(Z,4);
  N:=Pad(N,5);
  F:=Pad(F,5);
  P:=Pad(P,5);
 end;
end;

function MatchAddrList(A:tAddress; aList:string; RS:byte):boolean;
var
 mZ,mN,mF,mP:tStr5;
 sA:tStr25;
 aMask:tStr25;
 res:boolean;
 i:byte;

function MatchAddr:boolean;
{-попадает ли A под маску aMask }
var
 aZ,aN,aF,aP:tStr5;

begin
 if aMask[1] ='!' then
  Delete(aMask,1,1);
 { check mask for group }
 if aMask ='protected' then begin
  MatchAddr:=(RS and rsProtected) <> 0;
  exit;
 end
 else
  if aMask ='listed' then begin
   MatchAddr:=(RS and rsListed) <> 0;
   exit;
  end
  else
   if aMask ='published' then begin
    MatchAddr:=(RS and rsPublished) <> 0;
    exit;
   end;
 { split address }
 SplitAddr(sA, aZ,aN,aF,aP, true);
 if not ExpandAddrMacro(aMask, mZ,mN,mF,mP, true) then
  SplitAddr(aMask, mZ,mN,mF,mP, true);
 { удалим все `*' }
 KillStars(aZ,mZ);
 KillStars(aN,mN);
 KillStars(aF,mF);
 KillStars(aP,mP);
 {---}
 MatchAddr:=(aZ =mZ) and (aN =mN) and (aF =mF) and (aP =mP);
end;

var
 f:text;

begin
 { первый проход -- только для `!' }
 { второй проход -- все, кроме `!' }
 aList:=StLoCase(aList);
 sA:=Addr2str(A,true);
 res:=false;
 MatchAddrList:=false;
 if aList[1] ='@' then begin
  assign(f,copy(aList,2,127));
  reset(f);
  if IoResult <>0 then begin
    LogWrite(emCantOpen,aList,ld_All);
    exit;
  end;
  (* FOR FILE ADDRESSLIST *)
  { first pass }
  repeat
   readln(f,aMask);
   i:=Pos(';',aMask);
   if i <>0 then
    Delete(aMask,i,Length(aMask));
   aMask:=StLoCase(Trim(aMask));
   if Length(aMask) <>0 then
    if aMask[1] ='!' then
     if MatchAddr then
      exit
     else
      res:=true;
  until EOF(f);
  { second pass }
  TextSeek(f,0);
  repeat
   readln(f,aMask);
   i:=Pos(';',aMask);
   if i <>0 then
    Delete(aMask,i,Length(aMask));
   aMask:=StLoCase(Trim(aMask));
   if Length(aMask) <>0 then
    if aMask[1] <>'!' then
     if MatchAddr then begin
      MatchAddrList:=true;
      exit;
     end
     else
      res:=false;
  until EOF(f);
  close(f);
  if IoResult <>0 then
   LogWrite(emIoError,aList,ld_All);
 end
 else begin
  (* FOR ADDRESSLIST *)
  { first pass }
  for i:=1 to WordCount(aList,[',']) do begin
    aMask:=ExtractWord(i,aList,[',']);
    if aMask[1] ='!' then
     if MatchAddr then
      {MatchAddrList:=false;}
      exit
     else
      res:=true;
  end;
  { second pass }
  for i:=1 to WordCount(aList,[',']) do begin
    aMask:=ExtractWord(i,aList,[',']);
    if (aMask[1] <>'!') then
     if MatchAddr then begin
      MatchAddrList:=true;
      exit;
     end
     else
      res:=false;
  end;
 end;

 MatchAddrList:=res;
end;

procedure SetDefaultAddr(A:tAddress; _pad:boolean);
begin
 with A do
  if _pad then begin
   dZ:=Pad(Long2str(Zone),4);
   dN:=Pad(Long2str(Net),5);
   dF:=Pad(Long2str(Node),5);
   dP:=Pad(Long2str(Point),5);
  end
  else begin
   dZ:=Long2str(Zone);
   dN:=Long2str(Net);
   dF:=Long2str(Node);
   dP:=Long2str(Point);
  end;
end;

function xStr2addr(s:tStr25; var A:tAddress):boolean;
var
 Z,N,F,P:tStr5;

begin
 SplitAddr(s, Z,N,F,P, false);
 with A do
  xStr2addr:=Str2word(Z,Zone) and Str2word(N,Net) and
             Str2word(F,Node) and Str2word(P,Point);
end;

procedure MatchAkA(var Addr:tAddress);
{-находим адpес из гpуппы моих адpесов, соответствующий заданому в Addr}
var
 BestCount:byte;
 BestNumber:byte;
 Count:byte;
 i:byte;

begin
 BestCount:=0;
 BestNumber:=0;
 for i:=1 to pCfgRec^.AllAddress do begin
  if pCfgRec^.MyAddress[i].Zone=Addr.Zone then begin
   {Зона подходит}
   Count:=$10;
   if pCfgRec^.MyAddress[i].Net=Addr.Net then begin
    {Сеть подходит}
    Count:=$18;
    if pCfgRec^.MyAddress[i].Point=0 then
      Inc(Count,$04);
    {Hодовый адpес имеет тот же пpиоpитет, что и поинтовый для своего босса}
    if pCfgRec^.MyAddress[i].Node=Addr.Node then
      Inc(Count,$04);
   end;
  end else
   {Зона не подходит}
   Count:=0;
  {Check count}
  if Count>BestCount then begin
   BestCount:=Count;
   BestNumber:=i;
  end;
 end;
 { подходящего адpеса нет -- используем MAIN AkA }
 if BestNumber=0 then
   Move(MainAddress,Addr,SizeOf(tAddress))
 else
   Move(pCfgRec^.MyAddress[BestNumber],Addr,SizeOf(tAddress));
end;

function MsgForUs(Zone,Net,Node,Point:word):boolean;
{-есть ли этот адpес в наших AkA}
var
 i:byte;
 A1,A2:tAddress;

begin
 MsgForUs:=true;

 A1.Zone:=Zone;
 A1.Net:=Net;
 A1.Node:=Node;
 A1.Point:=Point;

 for i:=1 to pCfgRec^.AllAddress do begin
   Move(pCfgRec^.MyAddress[i],A2,SizeOf(tAddress));
   if Zone =0 then begin
        if CompWordStruct(A1.Net,A2.Net,6) =Equal then exit;
   end
   else
        if CompWordStruct(A1,A2,8) =Equal then exit;
 end;

 MsgForUs:=false;
end;

procedure Path4addr(bink:boolean; A:tAddress; var pthfname:PathStr);
{-получает 4D-адpес, возвpащает:
        pthfname -- путь и имя файлов для адpеса A}
begin
 if bink then begin
  pthFname:=pCfgRec^.BinkOutbound;
  if A.Zone <>MainAddress.Zone then
    pthFname:=pthFname+'.'+copy(HexW(A.Zone),2,3);
 end
 else
  pthFname:=pCfgRec^.Packets+'zone.'+copy(HexW(A.Zone),2,3);
 pthFname:=pthFname+'\'+HexW(A.Net)+HexW(A.Node);
 if A.Point <>0 then
   pthFName:=pthFName+'.pnt\'+LeftPadCh(HexW(A.Point),'0',8);
end;

{┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐}
{├┼┼ Pkt-processing routines ┼┼┤}
{└┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┘}
function CreatePkt(var TargetAddr:tAddress;
                   var PktDir:PathStr;
                   pExt:ExtStr;
                   bink:boolean):boolean;
{-создает пакет, пишет заголовок по инфоpмации в PktHeader,
  HoldPkt = true/false = пакет будет HOLD/NORMAL
  возвpащает:
                PktDir  - полный путь к пакетам для TargetAddr;
                          имя созданого пакета (nnnnffff)}
var
 fPkt:file;
 w:word;
 MyAddr:tAddress;
 l:longint;
 dt:DateTime;
 sPwd:string[8];

begin
 CreatePkt:=false;
 psStatus:=psCreateError;

 CreateDosTimeStamp(l);
 UnPackTime(l,dt);

 {подбиpаем подходящий AkA из списка наших адpесов}
 Move(TargetAddr,MyAddr,SizeOf(tAddress));
 MatchAkA(MyAddr);

 {-заполняем поля заголовка пакета-}
 with PktHeader, pCfgRec^ do begin
  OrigNode:=MyAddr.Node;
  DestNode:=TargetAddr.Node;
  Year:=DT.Year;
  Month:=DT.Month;
  Day:=DT.Day;
  Hour:=DT.Hour;
  Minute:=DT.Min;
  Second:=DT.Sec;
  Baud:=0;
  { fucken auxnet support :-E }
  if MyAddr.Point <>0 then begin
    AuxNet:=MyAddr.Net;
    OrigNet:=$FFFF;
  end
  else
    OrigNet:=MyAddr.Net;
  DestNet:=TargetAddr.Net;
  sPwd:=PadCh(GetMailPassword(TargetAddr),#0,8); {sPwd:='12345678';}
  Move(sPwd[1],Password,8);
  OrigZone:=MyAddr.Zone;
  DestZone:=TargetAddr.Zone;
  OrigPoint:=MyAddr.Point;
  DestPoint:=TargetAddr.Point;

  Path4addr(bink,TargetAddr,PktDir);  {-путь и имя пакета}
  MkAllDir(JustPathName(PktDir));     {-создаем все пути для TargetAddr}

  {w:=FileMode; FileMode:=ofmDenyNone;}
  if ExistFile(PktDir+pExt) then exit;
  assign(fPkt,PktDir+pExt);
  rewrite(fPkt,1);
  {FileMode:=lo(w);}
  if IoResult <>0 then exit;

  TextWrite(fPkt,Chr(Lo(OrigNode))+     Chr(Hi(OrigNode))      {00,01}
     +Chr(Lo(DestNode))+     Chr(Hi(DestNode))      {02,03}
     +Chr(Lo(Year))+         Chr(Hi(Year))          {04,05}
     +Chr(Lo(Month))+        Chr(Hi(Month))         {06,07}
     +Chr(Lo(Day))+          Chr(Hi(Day))           {08,09}
     +Chr(Lo(Hour))+         Chr(Hi(Hour))          {0A,0B}
     +Chr(Lo(Minute))+       Chr(Hi(Minute))        {0C,0D}
     +Chr(Lo(Second))+       Chr(Hi(Second))        {0E,0F}
     +Chr(Lo(Baud))+         Chr(Hi(Baud))          {10,11}
     +#2#0                                          {12,13}
     +Chr(Lo(OrigNet))+      Chr(Hi(OrigNet))       {14,15}
     +Chr(Lo(DestNet))+      Chr(Hi(DestNet))       {16,17}
     +_PCodeLo+              _PRevMajor             {18,19}
     +Password                              {1A,1B,1C,1D,1E,1F,20,21}

     +Chr(Lo(OrigZone))+     Chr(Hi(OrigZone))      {22,23}
     +Chr(Lo(DestZone))+     Chr(Hi(DestZone))      {24,25}
     +Chr(Lo(AuxNet))+       Chr(Hi(AuxNet))        {26,27}
     +#0#1                                          {28,29}

     +_PCodeHi+              _PRevMinor             {2A,2B}
     +#1#0                                          {2C,2D}
     +Chr(Lo(OrigZone))+     Chr(Hi(OrigZone))      {2E,2F}
     +Chr(Lo(DestZone))+     Chr(Hi(DestZone))      {30,31}
     +Chr(Lo(OrigPoint))+    Chr(Hi(OrigPoint))     {32,33}
     +Chr(Lo(DestPoint))+    Chr(Hi(DestPoint))     {34,35}
     +_PdData);                                     {36,37,38,39}
 end;

 if IoResult <>0 then begin
   close(fPkt);
   w:=word(IoResult);
   psStatus:=psWriteError;
   exit;
 end;

 { дописываем в конце заголовка два 0-байта }
 w:=$0000;
 BlockWrite(fPkt,w,2);

 close(fPkt);

 psStatus:=psOk;
 CreatePkt:=true;
end;

function AddMsg2Pkt(A:tAddress;
                    pExt:ExtStr;
                    var AddedSize:longint):boolean;
{-в AddedSize возвpащает добавленый объем}
var
 fPkt:file;
 PktDir:PathStr;
 sPmH:string;
 i:word;
 p:pMsgLn;
 InTransit:boolean;

begin
 AddedSize:=0;
 AddMsg2pkt:=true;
 psStatus:=psOk;

 { не пакуем, если пустое письмо и не тpанзит }
 if (not MsgInfo.MsgNotEmpty) and
    (MsgInfo.Attribute and bMsgFlag[_Forward] =0) and
    (CompWordStruct(A,MsgInfo.DestAddr,SizeOf(tAddress)) =Equal) then
   exit;

 AddMsg2pkt:=false;
 psStatus:=psReadError;
 InTransit:=(MsgInfo.Attribute and bMsgFlag[_Forward]) <>0;

 with MsgHeader do begin
  PktDir:=Subj; {save original msg subj}
  {-снимаем атpибуты Local, Transit, Hold, Orphaned}
  Attribute:=Attribute and (not({bMsgFlag[_Recvd] or
                                bMsgFlag[_Sent] or}
                                bMsgFlag[_Local] or
                                bMsgFlag[_Forward] or
                                bMsgFlag[_Hold] or
                                bMsgFlag[_Orphan]));
  { если attach, то в субже выpезаем пути }
  if Attribute and bMsgFlag[_Attach] <>0 then begin
    sPmH:='';
    for i:=1 to WordCount(Subj,[' ']) do
      sPmH:=sPmH+' '+JustFileName(ExtractWord(i,Subj,[' ']));
    Subj:=TrimLead(sPmH);
  end;
  if length(Date)>19 then Date[0]:=#19;
  sPmH:= #2#0                { Type #2 packets... Type #1 is obsolete }
         +Chr(Lo(OrigNode))+Chr(Hi(OrigNode))
         +Chr(Lo(DestNode))+Chr(Hi(DestNode))
         +Chr(Lo(OrigNet))+Chr(Hi(OrigNet))
         +Chr(Lo(DestNet))+Chr(Hi(DestNet))
         +Chr(Lo(Attribute))+Chr(Hi(Attribute))
         +Chr(Lo(Cost))+Chr(Hi(Cost))
         +Date+#0
         +ToName+#0
         +FromName+#0
         +Subj+#0;

  Subj:=PktDir;  {restore original msg subj}
 end;

 Path4addr(false,A,PktDir);

 {i:=FileMode; FileMode:=ofmDenyNone;}
 assign(fPkt,PktDir+pExt);
 reset(fPkt,1);
 {FileMode:=lo(i);}

 { если пакет уже закpыт, убиpаем 2 ноль-байта }
 seek(fPkt,FileSize(fPkt)-2);
 BlockRead(fPkt,i,2);
 if i =$00 then seek(fPkt,FileSize(fPkt)-2);

 BlockWrite(fPkt,sPmH[1],Length(sPmH));  {записали заголовок письма}
  {i:=IORESULT;}
  if IoResult <>0 then begin
   psStatus:=psWriteError;  {WRITELOGALL('!!! Hdr write ERR#'+long2str(i));}
                            {WRITELOGALL('\\\ file `'+Pktdir+pext+#39);}
   close(fPkt);
   i:=IoResult;
   exit;
  end;

 Inc(AddedSize,Length(sPmH));

 p:=MsgInfo.FirstLn;
 repeat
  if InTransit and (p^.NextLn =nil) then begin
   Move(MsgInfo.DestAddr,A,SizeOf(tAddress));
   MatchAkA(A);
   sPmH:=^A'Via '+Addr2str(A,true)+', '+MsgDateStamp+
         UTCstr+' '+mxPID+' '+mxVID+#$0D#0;
   if p^.LnLen >2 then
    BlockWrite(fPkt,p^.Ln,p^.LnLen-1);
    BlockWrite(fPkt,sPmH[1],length(sPmH));
   Inc(AddedSize,Length(sPmH));
  end
  else
   BlockWrite(fPkt,p^.Ln,p^.LnLen);
  Inc(AddedSize,p^.LnLen);
  p:=p^.NextLn;
 until p =nil;

 { дописываем в конце два 0-байта }
 i:=$0000;
 BlockWrite(fPkt,i,2);
 close(fPkt);

 psStatus:=psOk;
 AddMsg2pkt:=true;
end;

procedure MsgXs_Done;
var
 {oldFM:byte;}
 f:file;

begin
 {oldFM:=FileMode; FileMode:=ofmDenyNone;}
 assign(f,pCfgRec^.Packets+MapFname+savXt);
 rewrite(f,1);
 {FileMode:=oldFM;}
 BlockWrite(f,MsgFolderInfo.MsgFolderMap^[0],SizeOf(tMsgFolderMap));
 close(f);
 FreeMem(MsgFolderInfo.MsgFolderMap,SizeOf(tMsgFolderMap));
end;

{*** TPU initialization code ***}
begin
 FillChar(MsgHeader,SizeOf(tMsgHeader),0);
 FillChar(MsgInfo,SizeOf(tMsgInfo),0);
 msStatus:=msClosed;
 psStatus:=psClosed;
{the} end. {of TPU}
