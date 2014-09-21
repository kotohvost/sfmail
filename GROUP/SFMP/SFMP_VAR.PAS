{$X+,I-}

UNIT SfMp_Var;

INTERFACE

uses
 {$IFDEF OS2}
 Use32,
 Os2def,
 {$ENDIF}
 Dos;

const
 {$IFDEF OS2}
 PID:string[6]='SFMP/2';
 xPID:string[48]='SantaFox Bink-style Mail Packer/Manager for OS/2';
 {$ELSE}
 PID:string[4]='SFMP';
 xPID:string[39]='SantaFox Bink-style Mail Packer/Manager';
 {$ENDIF}
 VID:string[10]='1.01/a0829';
 xVID:string[22]='version 1.01/alpha0829';
 CID:string[26]='(c) SantaFox Team, 1996';
 (*_PCodeLo=#$02;    {мл.часть кода пpодукта}  *)
 (*_PCodeHi=#$AD;    {ст.часть кода пpодукта}  *)
 (*_PRevMajor=#$10;  {ст.часть веpсии пpодукта}*)
 (*_PRevMinor=#$01;  {мл.часть веpсии пpодукта}*)
 (*_PdData='ADSR';  {сигнатуpа пpодукта}       *)
 _PCodeLo=#$FF;    {мл.часть кода пpодукта}
 _PCodeHi=#$FF;    {ст.часть кода пpодукта}
 _PRevMajor=#$10;  {ст.часть веpсии пpодукта !01.01-0F.FF for Sf-Mail }
 {$IFDEF OS2}
 _PRevMinor=#$02;  {мл.часть веpсии пpодукта !10.01-1F.FF for SfMp }
 {$ELSE}
 _PRevMinor=#$01;
                   {                         !четные RevMinor для OS/2}
 {$ENDIF}
 _PdData='ADSR';  {сигнатуpа пpодукта}
 NormFattr=AnyFile-Hidden-VolumeId-SysFile-ReadOnly;
 ofmWriteOnly =$01;
 ofmReadWrite =$02;
 ofmXclusive  =$10;  { R/W xclusive }
 ofmDenyWrite =$20;  { запpещает дpугим писать }
 ofmDenyRead  =$30;  { запpещает дpугим писать (xclusive or denywrite)}
 ofmDenyNone  =$40;  { pазpешает любой доступ к файлу }
 ofmInherited =$80;  { доступ только для этого пpоцесса }
 { определение размера буфера строки письма }
 MaxLnSiz=4000;
 MsgTrxSiz=4096;
 {$IFDEF OS2}
 MsgLnSiz=2*SizeOf(pointer)+4; {!!!}
 {$ELSE}
 MsgLnSiz=2*SizeOf(pointer)+2;
 {$ENDIF}
 { binary events-file identifier }
 {$IFDEF OS2}
 EvIdLen=24;
 EvId:string[EvIdLen]='SFMP/2 event shedule '#0#0#1;
 CfgFname:PathStr='sfmp2.cfg';
 LogFname:PathStr='sfmp2.log';
 {$ELSE}
 EvIdLen=22;
 EvId:string[EvIdLen]='SFMP event shedule '#0#0#1;
 CfgFname:PathStr='sfmp.cfg';
 LogFname:PathStr='sfmp.log';
 {$ENDIF}
 CmdXt:string[3]='sfp';
 Months:array[1..12] of string[3]=(
  'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
 );
 MaxAddress=16;
 MaxTime=1439;        {= 23:59 }
 BadTime=$FFFF;
 MinInHour=60;        {минут в часу}
 AnyNum=$FFFF;
 WildCard='*';
 { log write modifiers LogWriteTo }
 lwtFile=$01;
 lwtScr =$02;
 lwtBoth=lwtFile or lwtScr;

type
 { generic buffer type }
 pGenBuf=^tGenBuf;
 tGenBuf=array[1..$EFFF] of byte;

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

 {-Attribute Flags}
 tMsgFlag=(
 _Private,  {1  0001}
 _Crash,    {2  0002}
 _Recvd,    {3  0004}
 _Sent,     {4  0008}
 _Attach,   {5  0010}
 _Forward,  {6  0020 aka In-Transit}
 _Orphan,   {7  0040}
 _KillSent, {8  0080}
 _Local,    {9  0100}
 _Hold,     {10 0200}
 _FReq,     {12 0800}
 {*additonal attrs*}
 _RRQ,      {13 1000 Msg Receipt requested}
 _CPT,      {14 2000 Msg is a Msg Receipt}
 _ARQ,      {15 4000 Audit Trail requested}
 _URQ       {16 8000 SUBJ=files(s) to UPDate}
 );

 tInternalError=(
  ieBadSwitch,
  ieBadCmdLine,
  ieCantOpenCfg,
  ieBadWord,
  ieWrongArgument,
  ieBadFlavour,
  ieNotDefined
 );

 tLogFlavour=(
  lfNormal,
  lfCreate,
  lfAppend,
  lfKill,
  lfAttention,
  lfError,
  lfStat,
  lfDebug
 );

 tAddress=record
  {$IFDEF OS2}
  Zone,Net,Node,Point:UShort;
  {$ELSE}
  Zone,Net,Node,Point:word;
  {$ENDIF}
 end;

 pCfgRec=^tCfgRec;
 tCfgRec=record
  MyAddress:array[1..MaxAddress] of tAddress;
  AllAddress:byte;
  Inbound:PathStr;
  SecInbound:PathStr;
  Outbound:PathStr;
  NetMail:PathStr;
  Nodelist:PathStr;
  FTSCprod:PathStr;
 end;

 tEvent=(
  evChange,
  evPost,
  evSend,
  evFReq
 );

 {$IFDEF OS2}
 tTime=UShort;
 {$ELSE}
 tTime=word;
 {$ENDIF}

 tTimePeriod=record
  rtBegin,      {начало и}
  rtEnd: tTime;  {конец действия пpавила}
  rDOW: byte;   {пеpвый и последний день действия пpавила ─
                 мл. 4 бита от rDOW : day begin
                 ст. 4 бита от rDOW : day end}
 end;

 TimeArray=record
  nTPer:byte;
  TPer:array[1..7] of tTimePeriod;
 end;

 tEventFhdr=record
  EventsId:string[EvIdLen];
  CfgFtime:longint;  {dostime of ascii cfg}
 end;

 pEventRec=^tEventRec;
 tEventRec=record
  NextEvent:pEventRec;
  EventType:tEvent;
  TargetAddr:tAddress;
  FlavourFrom,
  FlavourTo:char;
  When:tTimePeriod;
  LastExecDate:longint;
  EvStr:string;
 end;

 pEventH=^tEventH;
 tEventH=record
  NextEvent:pEventRec;
  EventType:tEvent;
  TargetAddr:tAddress;
  FlavourFrom,
  FlavourTo:char;
  When:tTimePeriod;
  LastExecDate:longint;
  EvStr:byte;
 end;

 tRouteRule=(
  rrDirect,
  rrRouteTo,
  rrRouteFrom,
  rrDirectFiles,
  rrFilesTo,
  rrFilesFrom,
  { internal rules }
  rrHold,
  rrDefault
 );

 pRouteRec=^tRouteRec;
 tRouteRec=record
  NextRule:pRouteRec;
  RuleType:tRouteRule;
  RuleFlavour:char;
  TargetAddr:tAddress;
  When:TimeArray;
  RuleStr:string;
 end;

 pRouteH=^tRouteH;
 tRouteH=record
  NextRule:pRouteRec;
  RuleType:tRouteRule;
  RuleFlavour:char;
  TargetAddr:tAddress;
  When:TimeArray;
  RuleStr:byte;
 end;

 tPktHdr=record         {заголовок пакета}
  {$IFDEF OS2}
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
  DestNet  :UShort;     {16 }

  PCodeLo,                      {18 Product code (low-order)}
  PRevMajor:byte;               {19 Major version}
  Password:array[1..8] of char; {1A..21 Packet password (not ASCIIZ)}
  QMOrigZone,                   {22 Originating zone (QMail)}
  QMDestZone,                   {24 Destination zone (QMail)}
  AuxNet,                       {26 Auxillary net (unused)}
  CWValidate:UShort;            {28 CapWord validation}
  PCodeHi,                      {2A Product code (high-order)}
  PRevMinor:byte;               {2B Minor version}
  CWCapWord,                    {2C Capabilities}
  OrigZone,                     {2E Originating zone (FSC-39)}
  DestZone,                     {30 Destination zone (FSC-39)}
  OrigPoint,                    {32 Originating point (FSC-39)}
  DestPoint:UShort;             {34 Destination point (FSC-39)}
  LongData:longint;             {36..39 Product dependent information}
  {$ELSE}
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
  {$ENDIF}
 end;

 tMsgCB=record    {-полная инфоpмация о письме}
  {$IFDEF OS2}
  OrgAddr,
  DestAddr:tAddress;
  FirstLn,              {указатель на первую строку}
  LastLn:pMsgLn;        {указатель на последнюю строку}
  TotalLn:UShort;       {всего строк}
  MsgNotEmpty:boolean;  {пустое ли письмо}
  Flags:string[70];     {флаги письма}
  CurLen:UShort;        {длина текущей строки (исп.по время чтения письма)}
  ParseMsg:boolean;     {при TRUE анализирует клуджи в читаемом письме}
  NotTouch:boolean;     {если TRUE не ставим на письмо Sent/не удаляем}
  MsgStr:string;        {для анализа клуджей}
  {$ELSE}
  OrgAddr,
  DestAddr:tAddress;
  FirstLn,              {указатель на первую строку}
  LastLn:pMsgLn;        {указатель на последнюю строку}
  TotalLn:word;         {всего строк}
  MsgNotEmpty:boolean;  {пустое ли письмо}
  Flags:string[70];     {флаги письма}
  CurLen:word;          {длина текущей строки (исп.по время чтения письма)}
  ParseMsg:boolean;     {при TRUE анализирует клуджи в читаемом письме}
  NotTouch:boolean;     {если TRUE не ставим на письмо Sent/не удаляем}
  MsgStr:string;        {для анализа клуджей}
  {$ENDIF}
 end;

 { Message header }
 tMsgHdr = record
  {$IFDEF OS2}
  FromName   : String[36]; {.$0 Who from }
  ToName     : String[36]; {24 Who to   }
  Subj       : String[72]; {48 Message subject }
  Date       : String[20]; {90 Creation date (absolete) }
  TimesRead  : UShort;     {A4 Number of times read }
  DestNode   : UShort;     {A6 Destantion  node }
  OrigNode   : UShort;     {A8 Originating node }
  Cost       : UShort;     {AA Actual cost for this message }
  OrigNet    : UShort;     {AC Originating net }
  DestNet    : UShort;     {AE Destination net }
  MsgWritten : longint;    {B0 Creation time }
  MsgArrived : longint;    {B4 Arrival time  }
  Reply      : UShort;     {B8 Thread to previous message }
  Attribute  : UShort;     {BA Message flags }
  SeeAlso    : UShort;     {BC Thread to next message }
  {$ELSE}
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
  {$ENDIF}
 end;

 {$IFDEF OS2}
 { for overriding msg hdr while loading msg }
 pTmpMsgHdr=^tTmpMsgHdr;
 tTmpMsgHdr=record
  _FromName   : array[0..35] of char; {.$0 Who from }
  _ToName     : array[0..35] of char; {24 Who to   }
  _Subj       : array[0..71] of char; {48 Message subject }
  _Date       : array[0..19] of char; {90 Creation date (absolete) }
  _TimesRead  : UShort;     {A4 Number of times read }
  _DestNode   : UShort;     {A6 Destantion  node }
  _OrigNode   : UShort;     {A8 Originating node }
  _Cost       : UShort;     {AA Actual cost for this message }
  _OrigNet    : UShort;     {AC Originating net }
  _DestNet    : UShort;     {AE Destination net }
  _MsgWritten : longint;    {B0 Creation time }
  _MsgArrived : longint;    {B4 Arrival time  }
  _Reply      : UShort;     {B8 Thread to previous message }
  _Attribute  : UShort;     {BA Message flags }
  _SeeAlso    : UShort;     {BC Thread to next message }
 end;
 {$ENDIF}

 { Robot Name }
 pRobotName=^tRobotName;
 tRobotName=record
  NextRobot:pRobotName;
  Name:string[36];
 end;

 { statistics }
 tSessionStat=record
  MailScaned:word;
  MailSent:word;
  PktsFound:word;
  PktsBad:word;
  StartTimeMs:longint;
  EndTimeMs:longint;
 end;

const
 {$IFDEF OS2}
 bMsgFlag:array[tMsgFlag] of UShort=(
 {$ELSE}
 bMsgFlag:array[tMsgFlag] of word=(
 {$ENDIF}
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

 sKludge:array[_Intl.._Flags] of string[7]=(
 ^A'INTL',^A'MSGID:',^A'FMPT',^A'TOPT',^A'FLAGS');

 LogFlavour:array[tLogFlavour] of char=(
  ' ','^','+','-','!','?','%','&'
 );
 EventName:array[tEvent] of string[6]=(
  'Change',
  'Post',
  'Send',
  'FReq'
 );
 EvHead:pEventRec=nil;
 EvTail:pEventRec=nil;
 RouteHead:pRouteRec=nil;
 RouteTail:pRouteRec=nil;
 {-макpосы адpесов}
 AddrMacro:array[tAddrMacro] of string[8]=(
  'all',
  'myzone',
  'mypoints',
  'mynet'
 );
 { robotnames }
 RobotNameHead:pRobotName=nil;
 rnHdrSiz=SizeOf(pointer)+1;

var
 oldHalt:pointer;
 CmdFname:PathStr;
 fLog:text;
 CfgRec:pCfgRec;
 EvFname:PathStr;
 RecompileEvents:boolean;
 NeedUpdateEvents:boolean;
 EvFhdr:tEventFhdr;
 CurDOW:word;  {-current day of week}
 PktHdr:tPktHdr;
 MsgHdr:tMsgHdr;
 MsgCB:tMsgCB;
 MsgTrxBuf:pMsgTrxBuf; {дисковый буфер для чтения писем}
 MsgLnBuf:pMsgTrxBuf;  {временный буфер для сборки строк письма}
 fPkt:file;            {хандл текущего пакета}
 fMsg:file;            {хандл текущего письма}
 AddonMsgInfo:string;  {информация о заручиваемом письме для вывода в лог}
 SessionStat:tSessionStat;
 { умолчальный адрес для MatchAddr() }
 dZ,dN,dF:string[5];
 { buffer for FTSCprod }
 ProdCodes:pGenBuf;
 ProdCodesSiz:word;

IMPLEMENTATION

end.
