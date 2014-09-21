{$X+,I-}

UNIT _SfM_Que;

INTERFACE

uses
 {$IFNDEF WINDOWS}
 tString_,
 TpWindow,
 Dos,
 TpPick,
 TpMenu,
 TpCrt,
 aMsgBox,
 {$ELSE}
 Strings,
 Objects,
 WinTypes,
 WinProcs,
 oWindows,
 oDialogs,
 WinDos,
 Dos2win,
 tStringW,
 ReadCfg,
 {$ENDIF}
 SfM_Api,
 UnixTime,
 Cfg;

type
 {$IFNDEF WINDOWS}
 TqvColor=(
  qvWindow,
  qvBorder,
  qvHeader,
  qvTable,
  qvTableTxt,
  qvSumm,
  qvMsgLabel,
  qvMsgHat,
  qvMsgData,
  qvItemLabel,
  qvItemData,
  qvNodeInfo1,
  qvNodeInfo2,
  qvUnlistedNode
 );
 {$ELSE}
 TextBuffer=array[0..65520] of byte;
 {structure of a Turbo File Interface Block}
 FIB=record
  Handle : Word;
  Mode : Word;
  BufSize : Word;
  Private : Word;
  BufPos : Word;
  BufEnd : Word;
  BufPtr : ^TextBuffer;
  OpenProc : Pointer;
  InOutProc : Pointer;
  FlushProc : Pointer;
  CloseProc : Pointer;
  UserData : array[1..16] of Byte;
  Name : array[0..79] of Char;
  Buffer : array[0..127] of Char;
 end;
 {$ENDIF}

const
 {$IFNDEF WINDOWS}
 PID='Sf-Mail eXternal Queue Manager';
 VID='ver 2.3.8';
 CID='(C) Anton Deinow & Santa Fox Team, 1995';
 DID='31 Jan `96';
 {$ELSE}
 AppName='SfM_Que';
 id_NormalMail=101;
 id_HoldMail  =102;
 id_NormalFile=103;
 id_HoldFile  =104;
 id_NormalFReq=105;
 id_HoldFreq  =106;
 id_NormalBox =107;
 id_HoldBox   =108;
 id_SysInfo1  =109;
 id_SysInfo2  =110;
 id_NormMailSiz=111;
 id_HoldMailSiz=112;
 id_NormFileSiz=113;
 id_HoldFileSiz=114;
 id_NormFReqSiz=115;
 id_HoldFReqSiz=116;
 id_NormBoxSiz =117;
 id_HoldBoxSiz =118;
 id_IMMmail   =119;
 id_PRIOmail  =120;
 id_IMM       =121;
 id_PRIO      =122;
 id_HOLD      =123;
 id_HXT       =124;
 id_HRQ       =125;
 {$ENDIF}
 EventManVer:string[3]=#2#2#4;
 NoYes:array[boolean] of string[3]=('No','Yes');

 MaxQueData=700;

 {$IFNDEF WINDOWS}
 qvColors:array[TqvColor] of byte=(
  $7, {qvWindow}
  $3, {qvBorder}
  $B, {qvHeader}
  $2, {qvTable}
  $3, {qvTableTxt}
  $E, {qvSumm}
  $B, {qvMsgLabel}
  $F, {qvMsgHat}
  $7, {qvMsgData}
  $B, {qvItemLabel}
  $7, {qvItemData}
  $E, {qvNodeInfo1}
  $F, {qvNodeInfo2}
  $C  {qvUnlistedNode}
 );
 {                          Win Frm Hdr Sel Alt AHi Unp}
 PickColors:PickColorArray=($07,$03,$0B,$21,$0F,$2F,$0C);
 FillColors:PickColorArray=($07,$03,$0B,$07,$01,$0F,$0C);
 (*
 {msgbox colors          Frm Hdr Itm Sel Hlt Txt (Dsb Sdw)}
 mbClrs :MenuColorArray=($87,$8F,$2F,$9F,$2E,$87, $7C,$08);
 {alarm msgbox colors}
 ambClrs:MenuColorArray=($C7,$CE,$2F,$9F,$2E,$CF, $C4,$08);
 *)
 mbClrs :MenuColorArray=($70,$7F,$2F,$1F,$2E,$70, $7C,$08);
 ambClrs:MenuColorArray=($47,$4E,$2F,$1F,$2E,$4F, $4C,$08);
 {$ENDIF}
 NoPrio=$FFFFFFFF;

type
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

 { структуры для HIP-флагов }
 tPriority=(tpImm,tpPrio,tpHold,tpHXT,tpHRQ);
 tHIPend=array[tPriority] of longint;
 tHIPflag=record
  hipAddr:tAddress;
  hipEnd:tHIPend;
 end;

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
  LastCallLine: boolean;  {FALSE=пpед.звонок был на доп.линию}
  ActiveItem  : boolean;  {для aQM: TRUE, если сейчас будем сюда звонить сейчас}
 end;

 stuffType=(
  queMail,
  queHoldMail,
  queAttach,
  queHoldAttach,
  queFReq,
  queHoldFReq,
  queBox,
  queHoldBox
 );

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

 tQueBit=record
   Name:PathStr;        {полное имя файла}
   FileType:tFileType;  {тип файла}
   MsgNo:word;          {только для пеpедачи: номеp письма (ATTACH/MSG)}
   MsgAttr:word;        {    ---""---       : атpибуты письма (ATTACH/MSG)}
 end;

 tBoxBit=string[12];

 tQueData=array[1..MaxQueData] of pointer;
 pQueData=^tQueData;

 tQueStuff=record
   {$IFNDEF WINDOWS}
   W:WindowPtr;
   x1,x2:byte;
   First:word;
   Curr:word;
   {$ENDIF}
   Total:word;
   Data:pQueData;
   Summ:longint;
 end;

const
 QueStuff:array[stuffType] of tQueStuff=(
 {$IFNDEF WINDOWS}
  (W:nil; x1:2;  x2:9;  First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:11; x2:17; First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:19; x2:25; First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:27; x2:33; First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:35; x2:41; First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:43; x2:49; First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:51; x2:64; First:1; Curr:1; Total:0; Data:nil; Summ:0),
  (W:nil; x1:66; x2:79; First:1; Curr:1; Total:0; Data:nil; Summ:0)
 );
 y1=8;
 y2:byte=12;
 {$ELSE}
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0),
  (Total:0; Data:nil; Summ:0)
 );
 {$ENDIF}

 { типы почты для QueueEntry }
 omBits:array[stuffType] of word=(
  {omMail}       $0001,
  {omHoldMail}   $0002,
  {omAttach}     $0004,
  {omHoldAttach} $0008,
  {omFReq}       $0010,
  {omHoldFReq}   $0020,
  {omBox}        $0080,
  {omHoldBox}    $0040
 );

 omPrioMail     =$0100;
 omImmMail      =$0200;

 {omActive     =queMail or queAttach or queBox or queFReq;}
 {omNormalMask:word =omBits[queMail] + omBits[queAttach] + omBits[queFReq];}
 {omHoldMask:word   =omBits[queMail] + omBits[queAttach] + omBits[queFReq];}

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

{$IFNDEF WINDOWS}
var
 { old status }
 oldXY:word;
 oldScanL:word;
 oldHalt:pointer;
 { internal }
 queAddr:tAddress;
 quePath:PathStr;
 CfgFname:PathStr;
 QueTmp:tQueueRec;
 HIPtmp:tHIPflag;
 CurrStuff:stuffType;

 NdlOfs:longint;
 NdlStr:string;
 fNdl:text;
 nn:byte;

function MsgAttrs2Str(Flg:word):string;
function _2space(s:string):string;
function PrioEnd2str(l:longint):string;
function InitMemory:boolean;
procedure ShowHIPflags;
procedure SetRepackSem;
procedure KillStuff;
function NextStuff:boolean;
procedure PrevStuff;
function LoadQueue:boolean;
procedure ScanStuff;
function GetQueStuff(n:word):string;
{$ELSE}
var
 CurrStuff:StuffType;

type
 pMainWin=^tMainWin;
 tMainWin=object(tDlgWindow)
  cmdFname:PathStr;
  queAddr:tAddress;
  quePath:PathStr;
  queTmp:tQueueRec;
  {===}
  constructor Init;
  destructor Done; virtual;
  procedure SetupWindow; virtual;
  procedure GetWindowClass(var WC:tWndClass); virtual;
  function GetClassName:pChar; virtual;
  {===}
  function CompAddr(a1,a2:tAddress):CompareType;
  function _2space(s:string):string;
  function PrioEnd2str(l:longint):string;
  procedure ShowHIPflags;
  function InitMemory:boolean;
  procedure SetRepackSem;
  procedure KillStuff;
  function NextStuff:boolean;
  procedure PrevStuff;
  function LoadQueue:boolean;
  procedure ScanStuff;
  function GetQueSt(n:word):string;
  function TextSeek(var F:text; Target:longint):boolean;
 end;
{$ENDIF}

IMPLEMENTATION

{$IFDEF WINDOWS}
function tMainWin.TextSeek(var F:text; Target:longint):boolean;
{-Do a Seek for a text file opened for input. Returns False in case of I/O
  error}
var
 T:LongRec absolute Target;
 Pos:longint;
 Regs:tRegisters;

begin
 with Regs, FIB(F) do begin
  {assume failure}
  TextSeek:=false;
  {check for file opened for input}
  if Mode <>FMInput then exit;
  {get current position of the file pointer}
  AX:=$4201;           {move file pointer function}
  BX:=Handle;          {file handle}
  CX:=0;               {if CX and DX are both 0, call returns the..}
  DX:=0;               {current file pointer in DX:AX}
  MsDos(Regs);
  {check for I/O error}
  if Odd(Flags) then exit;
  {calculate current position for the start of the buffer}
  LongRec(Pos).Hi:=DX;
  LongRec(Pos).Lo:=AX;
  Dec(Pos, BufEnd);
  {see if the Target is within the buffer}
  Pos:=Target-Pos;
  if (Pos >=0) and (Pos <BufEnd) then
    {it is--just move the buffer pointer}
    BufPos:=Pos
  else begin
    {have DOS seek to the Target-ed offset}
    AX:=$4200;         {move file pointer function}
    BX:=Handle;        {file handle}
    CX:=T.Hi;    {CX has high word of Target offset}
    DX:=T.Lo;     {DX has low word}
    MsDos(Regs);
    {check for I/O error}
    if Odd(Flags) then exit;
    {tell Turbo its buffer is empty}
    BufEnd:=0;
    BufPos:=0;
  end;
 end;
 {if we get to here we succeeded}
 TextSeek:=true;
end;

constructor tMainWin.Init;
begin
 tDlgWindow.Init(nil,'MAIN_WIN');
end;

destructor tMainWin.Done;
var
 f:text;

begin
 FreeMem(pCfgRec,SizeOf(tCfgRec));
 {assign(f,cmdFname);
 erase(f);}
 tDlgWindow.Done;
end;

procedure tMainWin.SetupWindow;
var
 s,s1:string;
 f:text;
 l:longint;
 nn:byte;
 ReqQuit:boolean;

begin
 tDlgWindow.SetupWindow;
 { load sfm-quew.cmd }
 cmdFname:=AddBackSlash(JustPathName(ParamStr(0)))+'sfm-quew.cmd';
 assign(f,cmdFname);
 reset(f);
 if IoResult <>0 then begin
  s:='Unable to open sf-quew.cmd';
  ReqQuit:=true;
 end
 else begin
  readln(f,s);
  close(f);
  if IoResult <>0 then;
  { read sf-mail`s config }
  ReqQuit:=not Read_Config(ExtractWord(2,s,[' ']));
  { <addr> <cfgfname> [<ndlfname> <offset>] }
  {   1        2           3          4}
 end;
 {---}
 if not ReqQuit then begin
  { set window title }
  s1:=ExtractWord(1,s,[' ']);
  Str2addr(s1,queAddr);
  s1:='SfM-Que - ['+s1+']'#0;
  SetWindowText(hWindow,@s1[1]);
  { load info about node }
  if WordCount(s,[' ']) >2 then begin
   assign(f,pCfgRec^.Nodelist+ExtractWord(3,s,[' ']));
   nn:=FileMode;
   FileMode:=ofmDenyWrite;
   reset(f);
   FileMode:=nn;
   Str2long(ExtractWord(4,s,[' ']),l);
   TextSeek(f,l);
   readln(f,s);
   close(f);
   if IoResult <>0 then;
   if s[1] =',' then nn:=2
   else nn:=3;
   s1:=_2space(ExtractWord(nn,s,[',']))+', '+
       _2space(ExtractWord(nn+2,s,[',']))+' at '+
       _2space(ExtractWord(nn+1,s,[',']))+#0;
   SendDlgItemMsg(id_SysInfo1,wm_SetText,0,longint(@s1[1]));
   s1:=copy(s,Pos(ExtractWord(nn+3,s,[',']),s),78)+#0;
   SendDlgItemMsg(id_SysInfo2,wm_SetText,0,longint(@s1[1]));
  end;
  { load que entry }
  if not LoadQueue then begin
   s:='Que entry for '+_4D2str(queAddr)+' not found';
   ReqQuit:=true;
  end
  else
   { scan outbound stuff }
   if not InitMemory then begin
    s:='Que entry is not corresponds'^M'to real stuff';
    ReqQuit:=true;
   end
   else begin
    NextStuff;
    ShowHIPflags;
    {s:='Queue for'^M+_4D2str(queAddr)+^M'loaded..'#0;
    MessageBox(0,@s[1],'Debug',mb_IconInformation);}
   end;
 end;
 if ReqQuit then begin
  s:=s+#0;
  MessageBox(0,@s[1],'Failed to..',mb_IconHand);
  PostQuitMessage(255);
 end;
end;

procedure tMainWin.GetWindowClass(var WC:tWndClass);
begin
 tDlgWindow.GetWindowClass(WC);
 WC.hIcon:=LoadIcon(hInstance,'SFQUE_ICO');
 WC.Style:=WC.Style and (not ws_SizeBox);
end;

function tMainWin.GetClassName:pChar;
begin
 GetClassName:=AppName;
end;

function tMainWin.GetQueSt(n:word):string;
begin
 with QueStuff[CurrStuff] do
  case CurrStuff of
    queMail..queHoldFReq: with tQueBit(Data^[n]^) do begin
      if FileType in [ftMsg,ftKFS,ftTFS,ftNormal] then
       GetQueSt:=Long2str(MsgNo)
      else
       if FileType =ftBinkUT then
        GetQueSt:=JustExtension(Name)
       else { imho, BinkLOnorm }
        GetQueSt:=JustExtension(Name);
    end;
    queBox..queHoldBox: GetQueSt:=tBoxBit(Data^[n]^);
  end;
end;
{$ENDIF}

{$IFNDEF WINDOWS}
{$F+}
function GetQueStuff(n:word):string;
begin
 with QueStuff[CurrStuff] do
  case CurrStuff of
    queMail..queHoldFReq: with tQueBit(Data^[n]^) do begin
      if FileType in [ftMsg,ftKFS,ftTFS,ftNormal] then
       GetQueStuff:=LeftPad(Long2str(MsgNo),6)
      else
       if FileType =ftBinkUT then
        GetQueStuff:=LeftPad(JustExtension(Name),6)
       else { imho, BinkLOnorm }
        GetQueStuff:=LeftPad(JustExtension(Name),6);
    end;
    queBox..queHoldBox: GetQueStuff:=LeftPad(tBoxBit(Data^[n]^),12);
  end;
end;
{$F-}

function _2space(s:string):string;
{$ELSE}
function tMainWin._2space(s:string):string;
{$ENDIF}
var
 i:byte;

begin
 for i:=1 to Length(s) do
   if s[i] ='_' then s[i]:=' ';
 _2space:=s;
end;

{$IFNDEF WINDOWS}
function PrioEnd2str(l:longint):string;
{$ELSE}
function tMainWin.PrioEnd2str(l:longint):string;
{$ENDIF}
var
 dt:DateTime;

begin
 if l =NoPrio then
   PrioEnd2str:='none'
 else with dt do begin
   l:=Unix2dos(l);
   UnpackTime(l,dt);
   PrioEnd2str:=LeftPad(Long2str(Day),2)+'-'+
                Months[Month]+'-'+
                copy(Long2str(Year),3,2)+
                +', '+
                LeftPad(Long2str(Hour),2)+':'+
                LeftPadCh(Long2str(Min),'0',2);
                {LeftPadCh(Long2str(Sec),'0',2);}
 end;
end;

function MsgAttrs2Str(Flg:word):string;
var
 sf:string;
 i:tMsgFlag;

begin
 sf:='';

 for i:=_Private to _URQ do
  if (Flg and bMsgFlag[i]) <>0 then
    sf:=sf+' '+sMsgFlag[i];

 MsgAttrs2Str:=TrimLead(sf);
end;

{$IFDEF WINDOWS}
function tMainWin.CompAddr(a1,a2:tAddress):CompareType;
type
 wa=array[1..4] of word;

var
 w1:wa absolute a1;
 w2:wa absolute a2;
 i:byte;

begin
 CompAddr:=Equal;
 for i:=1 to 4 do
  if w1[i] >w2[i] then begin
   CompAddr:=Greater;
   exit;
  end
  else
   if w1[i] <w2[i] then begin
    CompAddr:=Less;
    exit;
   end;
end;

procedure tMainWin.ShowHIPflags;
var
 s:string;

begin
 with {queTmp} HIPtmp do begin
  SendDlgItemMsg(id_IMMmail,wm_SetText,0,longint(@NoYes[omMask and omImmMail <>0,1]));
  SendDlgItemMsg(id_PRIOmail,wm_SetText,0,longint(@NoYes[omMask and omPrioMail <>0,1]));
  {---}
  s:=PrioEnd2str(hipEnd[tpImm])+#0;
  SendDlgItemMsg(id_IMM,wm_SetText,0,longint(@s[1]));
  s:=PrioEnd2str(hipEnd[tpPrio])+#0;
  SendDlgItemMsg(id_PRIO,wm_SetText,0,longint(@s[1]));
  s:=PrioEnd2str(hipEnd[tpHold])+#0;
  SendDlgItemMsg(id_HOLD,wm_SetText,0,longint(@s[1]));
  {---}
  s:=PrioEnd2str(hipEnd[tpHXT])+#0;
  SendDlgItemMsg(id_HXT,wm_SetText,0,longint(@s[1]));
  s:=PrioEnd2str(hipEnd[tpHRQ])+#0;
  SendDlgItemMsg(id_HRQ,wm_SetText,0,longint(@s[1]));
 end;
end;
{$ELSE}
procedure ShowHIPflags;
begin
 with QueTmp, HIPtmp do begin
  FastWrite('IMMediate mail',ScreenHeight-9,3, qvColors[qvItemLabel]);
  FastWrite('PRIOrity mail',ScreenHeight-8,4, qvColors[qvItemLabel]);
  FastWrite(NoYes[omMask and omImmMail <>0], ScreenHeight-9,18, qvColors[qvItemData]);
  FastWrite(NoYes[omMask and omPrioMail <>0], ScreenHeight-8,18, qvColors[qvItemData]);
  FastWrite('[I]',ScreenHeight-9,35,qvColors[qvItemLabel]);
  FastWrite('[P]',ScreenHeight-8,35,qvColors[qvItemLabel]);
  FastWrite('[H]',ScreenHeight-7,35,qvColors[qvItemLabel]);
  FastWrite(PrioEnd2str(hipEnd[tpImm]),ScreenHeight-9,39,qvColors[qvItemData]);
  FastWrite(PrioEnd2str(hipEnd[tpPrio]),ScreenHeight-8,39,qvColors[qvItemData]);
  FastWrite(PrioEnd2str(hipEnd[tpHold]),ScreenHeight-7,39,qvColors[qvItemData]);
  FastWrite('HXT',ScreenHeight-9,57,qvColors[qvItemLabel]);
  FastWrite('HRQ',ScreenHeight-8,57,qvColors[qvItemLabel]);
  FastWrite(PrioEnd2str(hipEnd[tpHXT]),ScreenHeight-9,61,qvColors[qvItemData]);
  FastWrite(PrioEnd2str(hipEnd[tpHRQ]),ScreenHeight-8,61,qvColors[qvItemData]);
 end;
end;

procedure SetRepackSem;
var
 f:file;

begin
 MkAllDir(pCfgRec^.Flags_Dir+'REPACK.FLG',false);
 assign(f,pCfgRec^.Flags_Dir+'REPACK.FLG\'+AddrTo32(queAddr,false));
 rewrite(f);
 close(f);
 if IoResult <>0 then;
end;

procedure KillStuff;
{$ENDIF}
{$IFDEF WINDOWS}
procedure tMainWin.KillStuff;
{$ENDIF}
var
 sp:PathStr;
 f:file of byte;
 o:integer;

{$IFDEF WINDOWS}
var
 Curr:word;
{$ENDIF}

begin
 with QueStuff[CurrStuff] do begin
  {$IFDEF WINDOWS}
  Curr:=SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_GetCurSel,0,0);
  {$ENDIF}
  if CurrStuff in [queMail,queHoldMail,queFReq,queHoldFReq] then begin
   if CurrStuff in [queMail,queHoldMail] then
    if tQueBit(Data^[Curr]^).FileType =ftBinkUt then
     sp:='mail packet'
    else
     sp:='NetMail msg'
   else
    if tQueBit(Data^[Curr]^).FileType =ftBinkFReq then
     sp:='bink FReq'
    else
     sp:='FReq msg';
   {$IFNDEF WINDOWS}
   if MessageBox('Do you really want to killthis '+sp+'?',
                 tYes,tNo,bButton[tYes] or bButton[tNo],
                 mbClrs,'Confirmation..') =tYes then begin
   {$ELSE}
   sp:='Do you really want to kill'^M'this '+sp+'?'#0;
   if MessageBox(hWindow,@sp[1],'Confirm..',mb_IconQuestion or mb_YesNo) =idYes then begin
   {$ENDIF}
     if tQueBit(Data^[Curr]^).FileType =ftBinkFReq then begin
      Path4addr(true,queAddr,sp);
      sp:=sp+'.req';
     end
     else
      if tQueBit(Data^[Curr]^).FileType =ftBinkUt then begin
       Path4addr(true,queAddr,sp);
       sp:=sp+'.'+chr(tQueBit(Data^[Curr]^).MsgNo)+'ut';
      end
      else
       sp:=pCfgRec^.NetMail+Long2str(tQueBit(Data^[Curr]^).MsgNo)+'.msg';
     assign(f,sp);
     erase(f);
     o:=IoResult;

     SetRepackSem;

     FreeMem(Data^[Curr],SizeOf(tQueBit));
     Dec(Total);
     {$IFDEF WINDOWS}
     SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_DeleteString,Curr,0);
     {$ENDIF}
     Move(Data^[Curr+1],Data^[Curr],SizeOf(pointer)*(MaxQueData-Curr));
     exit;
   end;
  end
  else
   if CurrStuff in [queBox,queHoldBox] then begin
    {$IFNDEF WINDOWS}
    if MessageBox('Do you really want to killfile '+
                  tBoxBit(Data^[Curr]^)+' from filebox?',
                  tYes,tNo,bButton[tYes] or bButton[tNo],
                  mbClrs,'Confirmation..') =tYes then begin
    {$ELSE}
    sp:='Do you really want to kill'^M'file '+tBoxBit(Data^[Curr]^)+' from filebox?'#0;
    if MessageBox(hWindow,@sp[1],'Confirm..',mb_IconQuestion or mb_YesNo) =idYes then begin
    {$ENDIF}
      assign(f,FileBoxName(queAddr,CurrStuff =queHoldBox)+
             tBoxBit(Data^[Curr]^));
      erase(f);
      o:=IoResult;
      Dec(Total);
      {$IFDEF WINDOWS}
      SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_DeleteString,Curr,0);
      {$ENDIF}
      FreeMem(Data^[Curr],SizeOf(tBoxBit));
      Move(Data^[Curr+1],Data^[Curr],SizeOf(pointer)*(MaxQueData-Curr));
      SetRepackSem;
    end
   end
   else
    {$IFNDEF WINDOWS}
    MessageBox('You can`t kill attaches/hold attaches,'#3+
               'because of this feature'#3+
               'was not implemented yet..',tOk,tOk,bButton[tOk],
               ambClrs,'Oops!..');
    {$ELSE}
    MessageBox(hWindow,'You can`t kill attaches/hold attaches,'^M+
               'because of this feature'^M+
               'was not implemented yet..','Oops!',mb_IconInformation);
    {$ENDIF}
 end; (*WITH*)
end;

{$IFNDEF WINDOWS}
function NextStuff:boolean;
{$ELSE}
function tMainWin.NextStuff:boolean;
{$ENDIF}
var
 curr:stuffType;

begin
 curr:=CurrStuff;
 NextStuff:=true;
 repeat
   CurrStuff:=stuffType(ord(CurrStuff)+1);
   if ord(CurrStuff) >ord(queHoldBox) then
     CurrStuff:=queMail;
 {$IFNDEF WINDOWS}
   if QueStuff[CurrStuff].Total <>0 then
     exit;
 until CurrStuff =curr;
 if QueStuff[curr].Total =0 then NextStuff:=false;
 {$ELSE}
   if IsWindowEnabled(GetItemHandle(id_NormalMail+ord(CurrStuff))) then begin
     SetFocus(GetItemHandle(id_NormalMail+ord(CurrStuff)));
     SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_SetCurSel,0,0);
     exit;
   end;
 until CurrStuff =curr;
 if IsWindowEnabled(GetItemHandle(id_NormalMail+ord(curr))) then
  NextStuff:=false
 else
  SetFocus(GetItemHandle(id_NormalMail+ord(CurrStuff)));
 {$ENDIF}
end;

{$IFNDEF WINDOWS}
procedure PrevStuff;
{$ELSE}
procedure tMainWin.PrevStuff;
{$ENDIF}
var
 curr:stuffType;

begin
 curr:=CurrStuff;
 repeat
   if CurrStuff =queMail then
     CurrStuff:=queHoldBox
   else
     CurrStuff:=stuffType(ord(CurrStuff)-1);
   {$IFNDEF WINDOWS}
   if QueStuff[CurrStuff].Total <>0 then begin
   {$ELSE}
   if IsWindowEnabled(GetItemHandle(id_NormalMail+ord(CurrStuff))) then begin
     SetFocus(GetItemHandle(id_NormalMail+ord(CurrStuff)));
   {$ENDIF}
     exit;
   end;
 until CurrStuff =curr;
end;

{$IFNDEF WINDOWS}
function LoadQueue:boolean;
{$ELSE}
function tMainWin.LoadQueue:boolean;
{$ENDIF}
var
 w:word;
 f:file;
 _v:string[3];
 _HIP:tHIPflag;

begin
 LoadQueue:=false;
 assign(f,pCfgRec^.Packets+'queue.$^'+_32_table[Task]);
 reset(f,1);
 if IoResult <>0 then exit;    {no QUEUE saved file, or open error}
 { читаем веpсию EvMan }
 BlockRead(f,_v[0],SizeOf(EventManVer),w);
 if (w =SizeOf(EventManVer)) and (_v =EventManVer) then begin
  repeat
   BlockRead(f,QueTmp,SizeOf(tQueueRec),w);
   if w =SizeOf(tQueueRec) then
    {$IFDEF WINDOWS}
    if CompAddr(queTmp.DestAddr,queAddr) =Equal then begin
    {$ELSE}
    if CompWordStruct(QueTmp,queAddr,SizeOf(tAddress)) =Equal then begin
    {$ENDIF}
      LoadQueue:=true;
      w:=0;
    end;
  until w <>SizeOf(tQueueRec);
 end;
 close(f);
 { read HIP }
 FillChar(HIPtmp,SizeOf(tHIPflag),$FF);
 assign(f,pCfgRec^.Packets+'hipflg.$^'+_32_table[Task]);
 reset(f,1);
 if IoResult <>0 then exit;
 { читаем веpсию EvMan }
 BlockRead(f,_v[0],SizeOf(EventManVer),w);
 if (w =SizeOf(EventManVer)) and (_v =EventManVer) then begin
  repeat
   BlockRead(f,_HIP,SizeOf(tHIPflag),w);
   if w =SizeOf(tHIPflag) then
    {$IFDEF WINDOWS}
    if CompAddr(_HIP.hipAddr,queAddr) =Equal then begin
    {$ELSE}
    if CompWordStruct(_HIP.hipAddr,queAddr,SizeOf(tAddress)) =Equal then begin
    {$ENDIF}
      Move(_HIP,HIPtmp,SizeOf(tHIPflag));
      w:=0;
    end;
  until w <>SizeOf(tHIPflag);
 end;
 close(f);
end;

{$IFNDEF WINDOWS}
procedure ScanStuff;
{$ELSE}
procedure tMainWin.ScanStuff;
{$ENDIF}
var
 f:file;
 ff:file of tQueBit;
 QueBit:tQueBit;
 o:integer;

procedure Scan4mail;
var
 mfoExt:ExtStr;
 s:PathStr;

begin
 case CurrStuff of
  queMail: mfoExt:='.mfo';
  queHoldMail: mfoExt:='.mfh';
  queAttach: mfoExt:='.mfa';
  queHoldAttach: mfoExt:='.mfx';
  queFReq: mfoExt:='.mfq';
  queHoldFReq: mfoExt:='.mfr';
 end;

 o:=0;

 if CurrStuff in [queMail,queHoldMail] then begin
  if CurrStuff =queMail then
    assign(f,quePath+'.pkt')
  else
    assign(f,quePath+'.pkh');
  reset(f,1);
  QueStuff[CurrStuff].Summ:=FileSize(f);
  close(f);
  o:=IoResult;
 end;

 if CurrStuff in [queFReq,queHoldFReq] then begin
  if CurrStuff =queFReq then
    assign(f,quePath+'.req')
  else
    assign(f,quePath+'.reh');
  reset(f,1);
  QueStuff[CurrStuff].Summ:=FileSize(f);
  close(f);
  o:=IoResult;
 end;

 if o <>0 then exit;

 assign(ff,quePath+mfoExt);
 reset(ff);
 if IoResult <>0 then exit;
 s:='';
 repeat
   read(ff,QueBit);
   if CurrStuff in [queAttach,queHoldAttach] then begin
     assign(f,QueBit.Name);
     reset(f,1);
     Inc(QueStuff[CurrStuff].Summ,FileSize(f));
     close(f);
     o:=IoResult;
     if QueBit.MsgAttr =$0FFFF then
       if Length(s) =0 then
         s:=QueBit.Name
       else
         s:=s+' '+QueBit.Name
     else with QueStuff[CurrStuff] do begin
       Inc(Total);
       GetMem(Data^[Total],SizeOf(tQueBit));
       Move(QueBit,Data^[Total]^,SizeOf(tQueBit));
       if Length(s) <>0 then begin
        tQueBit(Data^[Total]^).Name:=s+' '+QueBit.Name;
        {$IFDEF WINDOWS}
        s:=GetQueSt(Total)+#0;
        SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_AddString,0,longint(@s[1]));
        {$ENDIF}
       end;
       s:='';
     end
   end
   else with QueStuff[CurrStuff] do begin
     Inc(Total);
     GetMem(Data^[Total],SizeOf(tQueBit));
     Move(QueBit,Data^[Total]^,SizeOf(tQueBit));
     {$IFDEF WINDOWS}
     s:=GetQueSt(Total)+#0;
     SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_AddString,0,longint(@s[1]));
     {$ENDIF}
   end;
 until EOF(ff);
 close(ff);
 o:=IoResult;
end;

procedure Scan4box;
var
 s:PathStr;
 sr:SearchRec;
 {$IFDEF WINDOWS}
 tmpSt:string[13];
 {$ENDIF}

begin
 if Length(pCfgRec^.File_Boxes) <>0 then begin
  {$I+}
  {$IFDEF WINDOWS}
  s:=FileBoxName(queAddr,CurrStuff=queHoldBox)+'*.*'#0;
  FindFirst(@s[1],Archive,sr);
  {$ELSE}
  s:=FileBoxName(queAddr,CurrStuff=queHoldBox);
  FindFirst(s+'*.*',Archive,sr);
  {$ENDIF}
  {$I-}
  while DosError =0 do with QueStuff[CurrStuff] do begin
   Inc(Total);
   GetMem(Data^[Total],SizeOf(tBoxBit));
   Inc(Summ,sr.Size);
   {$IFDEF WINDOWS}
   tmpSt:=StrPas(sr.Name);
   s:=GetQueSt(Total)+#0;
   SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_AddString,0,longint(@s[1]));
   {$ELSE}
   tBoxBit(Data^[Total]^):=sr.Name;
   {$ENDIF}
   {$I+} FindNext(sr); {$I-}
  end;
 end;
end;

procedure Scan4LO;
var
 pth:PathStr;
 s:string;
 t:text;
 sr,fi:SearchRec;
 {$IFDEF WINDOWS}
 tmpSt:string[13];
 {$ENDIF}

begin
 Path4addr(true,queAddr,pth);
 {$I+}
 {$IFDEF WINDOWS}
 pth:=pth+'.?lo'#0;
 FindFirst(@pth[1],Archive,sr);
 Path4addr(true,queAddr,pth);
 {$ELSE}
 FindFirst(pth+'.?lo',Archive,sr);
 {$ENDIF}
 {$I-}
 while DosError =0 do with QueStuff[CurrStuff] do begin
  {$IFDEF WINDOWS}
  tmpSt:=StrPas(sr.Name);
  s[1]:=LoCase(tmpSt[succ(Pos('.',tmpSt))]);
  {$ELSE}
  s[1]:=LoCase(sr.Name[succ(Pos('.',sr.Name))]);
  {$ENDIF}
  if ((CurrStuff =queAttach) and (s[1] <>'h')) or
     ((CurrStuff =queHoldAttach) and (s[1] ='h')) then begin
    Inc(Total);
    GetMem(Data^[Total],SizeOf(tQueBit));
    tQueBit(Data^[Total]^).FileType:=ftBinkLOnorm;
    {$IFDEF WINDOWS}
    tQueBit(Data^[Total]^).Name:=JustPathname(pth)+'\'+tmpSt;
    s:=GetQueSt(Total)+#0;
    SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_AddString,0,longint(@s[1]));
    assign(t,pth+'.'+JustExtension(tmpSt));
    {$ELSE}
    tQueBit(Data^[Total]^).Name:=JustPathname(pth)+'\'+sr.Name;
    assign(t,pth+'.'+JustExtension(sr.Name));
    {$ENDIF}
    reset(t);
    repeat
      readln(t,s);
      s:=Trim(s);
      if Length(s) <>0 then begin
       if s[1] in ['^','#'] then Delete(s,1,1);
       {$I+}
       {$IFDEF WINDOWS}
       s:=s+#0;
       FindFirst(@s[1],AnyFile-Directory-VolumeId,fi);
       {$ELSE}
       FindFirst(s,AnyFile-Directory-VolumeId,fi);
       {$ENDIF}
       {$I-}
       if DosError =0 then Inc(Summ,fi.Size);
      end;
    until EOF(t);
    close(t);
    if IoResult <>0 then;
  end;
  {$I+} FindNext(sr); {$I-}
 end;
end;

procedure Scan4UT;
var
 pth:PathStr;
 sr:SearchRec;
 c:char;
 {$IFDEF WINDOWS}
 tmpSt:string[13];
 {$ENDIF}

begin
 Path4addr(true,queAddr,pth);
 {$I+}
 {$IFDEF WINDOWS}
 pth:=pth+'.?ut'#0;
 FindFirst(@pth[1],Archive,sr);
 {$ELSE}
 FindFirst(pth+'.?ut',Archive,sr);
 {$ENDIF}
 {$I-}
 while DosError =0 do with QueStuff[CurrStuff] do begin
  {$IFDEF WINDOWS}
  tmpSt:=StrPas(sr.Name);
  c:=LoCase(tmpSt[succ(Pos('.',tmpSt))]);
  {$ELSE}
  c:=LoCase(sr.Name[succ(Pos('.',sr.Name))]);
  {$ENDIF}
  if ((CurrStuff =queMail) and (c <>'h')) or
     ((CurrStuff =queHoldMail) and (c ='h')) then begin
   Inc(Total);
   GetMem(Data^[Total],SizeOf(tQueBit));
   tQueBit(Data^[Total]^).FileType:=ftBinkUT;
   tQueBit(Data^[Total]^).MsgNo:=ord(c);
   Inc(Summ,sr.Size);
   {$IFDEF WINDOWS}
   tQueBit(Data^[Total]^).Name:=tmpSt;
   pth:=GetQueSt(Total)+#0;
   SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_AddString,0,longint(@pth[1]));
   {$ELSE}
   tQueBit(Data^[Total]^).Name:=sr.Name;
   {$ENDIF}
  end;
  {$I+} FindNext(sr); {$I-}
 end;
end;

procedure Scan4REQ;
var
 pth:PathStr;
 sr:SearchRec;
 {$IFDEF WINDOWS}
 tmpSt:string[13];
 {$ENDIF}

begin
 Path4addr(true,queAddr,pth);
 {$I+}
 {$IFDEF WINDOWS}
 pth:=pth+'.req'#0;
 FindFirst(@pth[1],Archive,sr);
 {$ELSE}
 FindFirst(pth+'.req',Archive,sr);
 {$ENDIF}
 {$I-}
 if DosError =0 then with QueStuff[CurrStuff] do begin
   Inc(Total);
   GetMem(Data^[Total],SizeOf(tQueBit));
   tQueBit(Data^[Total]^).FileType:=ftBinkFReq;
   Inc(Summ,sr.Size);
   {$IFDEF WINDOWS}
   tQueBit(Data^[Total]^).Name:=StrPas(sr.Name);
   pth:=GetQueSt(Total)+#0;
   SendDlgItemMsg(id_NormalMail+ord(CurrStuff),lb_AddString,0,longint(@pth[1]));
   {$ELSE}
   tQueBit(Data^[Total]^).Name:=sr.Name;
   {$ENDIF}
 end;
end;

begin
 if CurrStuff in [queMail..queHoldFReq] then begin
   if (pCfgRec^.SysFlags and amaScan <>0) then Scan4mail;
   if (Length(pCfgRec^.BinkOutbound) <>0) then begin
    if (CurrStuff in [queMail,queHoldMail]) then Scan4UT;
    if (CurrStuff in [queAttach,queHoldAttach]) then Scan4LO;
    if CurrStuff =queFReq then Scan4REQ;
   end;
 end
 else
   Scan4box;
end;

{$IFNDEF WINDOWS}
function InitMemory:boolean;
{$ELSE}
function tMainWin.InitMemory:boolean;
{$ENDIF}
var
 OnceOk:boolean;
 s:string;

begin
 OnceOk:=false;
 for CurrStuff:=queMail to queHoldBox do with QueStuff[CurrStuff],pCfgRec^ do begin
   {$IFNDEF WINDOWS}
   MakeWindow(W,x1,y1,x2,y2, false,true,true,qvColors[qvWindow],
              qvColors[qvWindow],qvColors[qvWindow],'');
   DisplayWindow(W);
   {$ENDIF}
   {if QueTmp.omMask and omBits[CurrStuff] <>0 then} begin
     GetMem(Data,SizeOf(tQueData));
     if Data =nil then halt(252);
     FillChar(Data^,SizeOf(tQueData),0);
     ScanStuff;
     if Total =0 then begin
       QueTmp.omMask:=QueTmp.omMask and (not omBits[CurrStuff]);
       FreeMem(Data,SizeOf(tQueData));
     end
     else begin
       OnceOk:=true;
       {$IFDEF WINDOWS}
       s:=vInBestForm(Summ)+#0;
       SendDlgItemMsg(id_NormMailSiz+ord(CurrStuff),wm_SetText,0,longint(@s[1]));
       EnableWindow(GetItemHandle(id_NormalMail+ord(CurrStuff)),true);
       {$ELSE}
       if CurrStuff in [queBox,queHoldBox] then
         FastWrite(LeftPad(vInBestForm(Summ),12),y2+2,x1+1,qvColors[qvSumm])
       else
         FastWrite(LeftPad(vInBestForm(Summ),5),y2+2,x1+1,qvColors[qvSumm]);
       FillPickWindow(W,@GetQueStuff,Total,FillColors,First, 0);
       {---}
       with WindowP(W)^ do
        ChangeAttribute(succ(XH-XL),pred(YL),XL,$0B);
       {$ENDIF}
     end;
   end;
 end;
 InitMemory:=OnceOk;
end;

end.
