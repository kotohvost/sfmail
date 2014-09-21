(*************************************)
(***      Sf-Mail Fax Manager      ***)
(***    General Data Defenition    ***)
(*************************************)

type
 SigArray=array[0..5] of char;        {Fax file signature array}

 { End-of-page status }
 ReceivePageStatus=(
  rpsBadPage,
  rpsMoreSame,
  rpsNewPage,
  rpsNewDocument,
  rpsEndOfDocument
 );

 { General fax states }
 FaxStateType=(
  faxReady,           {State machine ready immediately}
  faxWaiting,         {State machine waiting}
  faxFinished         {State machine is finished}
 );

 { Send machine states }
 SendStates=(
   tfNone,

   {Setup, both classes}
   tfGetEntry,
   tfInit,

   {Phase A, Class 1}
   tf1Init1,

   {Phase A, Class 2}
   tf2Init1,
   tf2Init2,
   tf2Init3,

   {Phase A, both classes}
   tfDial,
   tfRetryWait,

   {Phase B, Class 1}
   tf1Connect,
   tf1SendTSI,
   tf1TSIResponse,
   tf1DCSResponse,
   tf1TrainStart,
   tf1TrainFinish,
   tf1WaitCFR,
   tf1WaitPageConnect,

   {Phase B, Class 2}
   tf2Connect,
   tf2GetParams,

   {Phase C, both classes}
   tfWaitXon,
   tfWaitFreeHeader,
   tfSendPageHeader,
   tfOpenCover,
   tfSendCover,
   tfPrepPage,
   tfSendPage,
   tfDrainPage,

   {Phase D states for Class 1}
   tf1PageEnd,
   tf1PrepareEOP,
   tf1SendEOP,
   tf1WaitMPS,
   tf1WaitEOP,
   tf1WaitMCF,
   tf1SendDCN,
   tf1Hangup,
   tf1WaitHangup,

   {Phase D, Class 2}
   tf2SendEOP,
   tf2WaitFPTS,
   tf2WaitFET,
   tf2WaitPageOK,
   tf2NextPage,

   {Phase E, both classes}
   tfClose,
   tfCompleteOK,
   tfAbort,
   tfDone
 );

 { Receive machine states }
 ReceiveStates=(
   rfNone,

   {Phase B, class 1}
   rf1SendCSI,
   rf1SendDIS,
   rf1CollectFrames,
   rf1StartTrain,
   rf1CollectTrain,
   rf1Retrain,
   rf1FinishTrain,
   rf1SendCFR,
   rf1WaitPageConnect,

   {Phase B, class 2}
   rf2GetSenderID,
   rf2GetConnect,

   {Phase C}
   rfStartPage,
   rfGetPageData,

   {Phase D, class 1}
   rf1FinishPage,
   rf1WaitEOP,
   rf1WritePage,
   rf1SendMCF,
   rf1WaitDCN,
   rf1WaitHangup,

   {Phase D, class 2}
   rf2GetPageResult,
   rf2GetFHNG,

   {Phase E, both classes}
   rfComplete,
   rfAbort,
   rfDone
 );

const
 { size of buffer for file fax data }
 DataBufSiz =4096;
 faxWaitChar=91;  {91 tick}
 DefSig:SigArray='APF10'#26; {Default fax file signature}
 DefStatusBytes=1024; {Force periodic exit}

 MaxModIndex=6;
 MaxBadPercent=10;   {error if this % bad training}

 ReplyWait    =546;  {ticks to wait fax cmd response}
 PreCmdDelay  =100;  {msec before general modem cmds}
 PreFaxDelay  =40;   {MSec before inprog fax modem cmds}
 ExtraCmdDelay=200;  {MSec extra delay before some cmds}
 FrameWait    =20;   {Msec delay before HDLC frame}
 { undocumented ;-}
 ExtraCommandDelay:word=200;     { MSec extra delay before some cmds }

 { Option flags for FAX page header }
 ffHighRes    =$0001;     {image stored in high-res mode}
 ffHighWidth  =$0002;     {image uses option high-width mode}
 ffLengthWords=$0004;     {set if raster lines include length word}

 { fax error codes: fe_XXX }
 fe_Ok            =0;      {all ok}
 fe_IO            =301;    {fax i/o fatal error}
 fe_WriteFaxHdr   =302;    {error write fax main hdr}
 fe_WritePgHdr    =303;    {error write fax page hdr}
 fe_LocatePage    =304;    {unable to locate page}
 fe_UnkModemResult=305;    {unexpected char in modem result string}
 fe_UnexpectedFHNG=306;    {unexpected FHGN frame}
 fe_Tout          =307;    {timeout}
 fe_Init          =308;    {fax init error}
 fe_DataCall      =309;    {call is DATA}
 fe_VoiceCall     =310;    {call is VOICE}
 fe_Train         =311;    {fax train error}
 fe_UserAbort     =312;    {user abort fax}

 { For calculating minimum bytes per line }
 ScanTimes:array[0..7,boolean] of byte=(
    (0,0),    {0}
    (5,5),    {1}
    (10,5),   {2}
    (10,10),  {3}
    (20,10),  {4}
    (20,20),  {5}
    (40,20),  {6}
    (40,40)); {7}

 { For managing Class 1 modulations }
 ModArray:array[1..MaxModIndex] of string[3]=(
  '24','48','72','96','121','145');

 { For getting MaxFaxBPS from modulation index }
 Class1BPSArray:array[1..MaxModIndex] of word=(
  2400,4800,7200,9600,12000,14400);

 { Bit reversed fax control fields IDs from HDLC info field }
 NSFframe=$20;
 EOPframe=$2E;
 CSIframe=$40;
 TSIframe=$42;
 FTTframe=$44;
 RTNframe=$4C;
 MPSframe=$4E;
 DISframe=$80;
 DCSframe=$82;
 CFRframe=$84;
 MCFframe=$8C;
 EOMframe=$8E;
 DCNframe=$FB;
 RTPframe=$CC;

 { Fax progress codes, sending }
 fpInitModem         =01;  {Initializing modem for fax processing}
 fpDialing           =02;  {Dialing}
 fpBusyWait          =03;  {Busy, FaxTransmit is waiting}
 fpSendPage          =04;  {Sending document page data}
 fpSendPageStatus    =05;  {Send EOP}
 fpPageError         =06;  {Error sending page}
 fpPageOK            =07;  {Page accepted by remote}

 { Fax progress codes, receiving }
 fpWaiting           =20;  {Waiting for incoming call}
 fpNoConnect         =21;  {No connect on this call}
 fpAnswer            =22;  {Answering incoming call}
 fpIncoming          =23;  {Incoming call validated as fax}
 fpGetPage           =24;  {Getting page data}
 fpGetPageResult     =25;  {Getting end-of-page signal}
 fpCheckMorePages    =26;  {getting end-of-document status}
 fpGetHangup         =27;  {Get hangup command}
 fpGotHangup         =28;  {Got Class 2 FHNG code}

 { Fax progress codes, common }
 fpSessionParams     =40;  {Getting connection params}
 fpGotRemoteID       =41;  {got called-station ID}

 { Convenient character constants (and aliases) }
 cNul=#0;
 cSoh=#1;
 cStx=#2;
 cEtx=#3;
 cEot=#4;
 cEnq=#5;
 cAck=#6;
 cBel=#7;
 cBS =#8;
 cTab=#9;
 cLF =#10;
 cVT =#11;
 cFF =#12;
 cCR =#13;
 cSO =#14;
 cSI =#15;
 cDle=#16;
 cDC1=#17;       cXon =#17;
 cDC2=#18;
 cDC3=#19;       cXoff=#19;
 cDC4=#20;
 cNak=#21;
 cSyn=#22;
 cEtb=#23;
 cCan=#24;
 cEM =#25;
 cSub=#26;
 cEsc=#27;
 cFS =#28;
 cGS =#29;
 cRS =#30;
 cUS =#31;

 { DIS/DCS permanent bit masks, bit reversed }
 DISgroup1  =$00;        {No group 1/2 options}
 DISgroup3_1=$03;        {RS 465 receiver/transmitter support}
 DISgroup3_2=$F8;        {A4 max width, unlimited length, extended byte}
 DISgroup3_3=$00;        {No extended options}

 { DIS/DCS option bits for DISgroup3_1 }
 DIShighResolution=$40;
 DIS2400BPS       =$00;
 DIS4800BPS       =$08;
 DIS7200BPS       =$0C;
 DIS9600BPS       =$04;
 DIS12000BPS      =$10;
 DIS14400BPS      =$20;

 { Class 1 constants }
 AddrField=#$FF;
 ControlField=#$03;
 ControlFieldLast=#$13;

type
 pDataBuf=^tDataBuf;
 tDataBuf=array[0..$FFF0] of byte;

 EventTimer=record
  startTics,
  expireTics:longint;
 end;

 {APRO fax file header record}
 FaxHeaderRec=record
  Signature:SigArray;               {APRO FAX signature}
  FDateTime:longint;                {Date and time in DOS format}
  SenderID :string[20];             {Station ID of sender}
  Filler   :byte;                   {Alignment byte, unused}
  PageCount:word;                   {Number of pages in this file}
  PageOfs  :longint;                {Offset in file of first page}
  Padding  :array[39..64] of byte;  {Expansion room}
 end;

 {APRO fax page header record}
 PageHeaderRec=record
  ImgLength:longint;                 {Bytes of image data in this page}
  ImgFlags :word;                    {Image flags for width, res, etc}
  Padding  :array[7..16] of byte;    {Expansion room}
 end;

 pFaxCtl=^tFaxCtl;
 tFaxCtl=record
  faxStatus    :integer;     {general fax status (aka AsyncStatus)}
  faxProgress  : Word;       {For storing progress codes}
  CurrPage     : Integer;    {counter for pages}
  PageCount    : Integer;    {total pages in document}
  DataCount    : LongInt;    {count of received "real" data bytes}
  BadData      : word;       {bad bytes during train}
  PageSize     : LongInt;    {size of page file in bytes}
  RemoteID     : string[20]; {StationID of remote}
  CoverFname   : PathStr;    {cover page file if any}
  Title        : String;     {Sender title}
  Recipient    : String;     {Recipient's name}
  Sender       : String;     {Sender's name}
  {------------}
  DataBuf      :pDataBuf;    {transmit fax buffer}
  CurrOfs      :word;        {current offset in DataBuf}
  Last         :char;        {last received data char}
  {------------}
  Response     :string;
  CollectResp  :boolean;
  CRLFindex    :byte;        {index for CRLF checking}
  ETXindex     :byte;        {index for DLE/ETX checking}
  ModCode      :string[3];   {modulation code}
  ReceivedFrame:byte;        {last received HDLC frame type}
  LastFrame    :boolean;     {true if last Class 1 frame}
  LocalMods    :array[1..MaxModIndex] of boolean; {Local Class 1 mods}
  RmtMods      :array[1..MaxModIndex] of boolean; {Remote Class 1 mods}
  BPSindex     :word;        {last Class 1 BPS index}
  ResC         :char;        {resolution character}
  MaxFaxBPS    :word;        {max fax BPS for this modem}
  SessionBPS   :longint;     {remote/session BPS}
  SessionRes   :boolean;     {remote/session resolution}
  SessionECM   :boolean;     {remote/session ECM}
  ForceStatus  :boolean;     {true to force special status}
  MorePages    :boolean;     {true if more fax pages to receive}
  OneFax       :boolean;     {true if only receiving one fax}
  SessionScan  :byte;        {remote/session scantime}
  MinBytes     :word;        {minimum raster line length}
  FaxHeader    :faxHeaderRec;  {fax main header}
  PageHeader   :pageHeaderRec; {fax page header}
  InFile       :file;        {received data file}
  FaxFname     :PathStr;     {name of current file}
  ReplyTimer   :EventTimer;  {timer for all replies}
  LastPageOk   :boolean;     {true if last page received ok}
  CheckChar    :char;        {ECM character}
  PageStatus   :ReceivePageStatus;  {status of most-recent page}
  State        :ReceiveStates;      {current state of StateMachine}
  HangupCode   :word;        {last FHNG code}
 end;

Type
 tRxBuff = array [1..1024] of byte;
 pRxBuff = ^tRxBuff;

Var
 RxBuff  : pRxBuff;
 RxCount : word;
 RxTotal : word;