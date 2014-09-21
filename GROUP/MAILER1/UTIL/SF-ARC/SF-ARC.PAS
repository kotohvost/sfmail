{$X+,V-,I-}

program t_Arc;
uses
 TpDos,
 Dos,
 AEH,
 tConfig,
 Tstring_,
 SfM_Api,
 Cfg,
 ReadCfg,
 TpAsciiz;

const
 PID='Sf-Arc';
 xPID='Sf-Mail Echo-Knife';
 VID='ver 0.2.3/gamma';
 CID='(c) Anton Deinow Software Research Lab, 1995';

 Sf_ArcCfgFname='Sf-Arc.cfg';

 MaxLink=150;
 MaxMan=7;

 {-учитываемые pасшиpения-}
 ArcExt:string[21]='.SU.MO.TU.WE.TH.FR.SA';

type
 tLinkInfo=record
   LinkAddr:tAddress;
   MaxArcSize:longint;
 end;

 pMan=^tMan;
 tMan=string[36];

 tLogState=(
  lsNormal,
  lsWarning,
  lsError,
  lsStat,
  lsDebug,
  lsMsgXs,
  lsMsgXsDebug,
  lsFileXs,
  lsFileXsDebug
 );

 TmsgHdr=record
  FromName   : array[1..36] of char; {.$0 Who from }
  ToName     : array[1..36] of char; {24 Who to   }
  Subj       : array[1..72] of char; {48 Message subject }
  Date       : array[1..20] of char; {90 Creation date (absolete) }
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

const
 cLogState:array[tLogState] of char=(
  ' ',
  '!',
  '?',
  ':',
  '&',
  '$',
  '@',
  '-',
  '*'
 );

 MsgXt:ExtStr='.msg';

var
 fLog:text;
 LogLevel:string[10];
 LogName:PathStr;
 Sf_MailCfgFname:PathStr;
 CfgFname:PathStr;
 LinkInfo:array[1..MaxLink] of ^tLinkInfo;
 nLink:word;
 sr:SearchRec;

 ForceZone:boolean;

 msgNo:word;
 msgHdr:TmsgHdr;
 msgOrig,
 msgDest:tAddress;

 msgScaned,
 msgKilled,
 filesMoved:word;
 kbsMoved:longint;

 ManName:array[1..MaxMan] of pMan;
 nMan:integer;

 OldHalt:pointer;
 i:integer;

function A2S(var A):string;
var
 _A:Asciiz absolute A;

begin
 A2S:=Asc2str(_A);
end;

function T2S:string;
var
 h,m,s,t:word;

begin
 GetTime(h,m,s,t);
 T2S:=LeftPadCh(Long2str(h),'0',2)+':'+
      LeftPadCh(Long2str(m),'0',2)+':'+
      LeftPadCh(Long2str(s),'0',2);
end;

procedure ToLog(s:string; ls:tLogState);
begin
 if Pos(cLogState[ls],LogLevel) =0 then exit;
 if TextRec(fLog).Mode <>fmClosed then
  if ls =lsStat then begin
    { выводим статистику }
    writeln(fLog,'  :  Messages scaned - ',msgScaned,'; killed - ',msgKilled);
    writeln(':  Scaned - ',msgScaned,'; killed - ',msgKilled);
    writeln(fLog,'  :  Files moved - ',filesMoved,' ('+vInBestForm(kbsMoved)+')');
    writeln(':  Files moved - ',filesMoved,' ('+vInBestForm(kbsMoved)+')');
    exit;
  end
  else
   writeln(fLog,cLogState[ls]+' '+T2S+' '+s);

 if ls <>lsError then
  writeln(cLogState[ls]+' '+Trim(s));
end;

{$F+}
procedure TAshowError(se1,se2:string);
begin
 writeln(#13#10+se1+#13#10+se2+^G);
 ToLog(se1+': '+se2,lsError);
end;

procedure TAhalt;
begin
 ExitProc:=OldHalt;
 if TextRec(fLog).Mode <>fmClosed then begin
   ToLog('',lsStat);
   ToLog('End',lsNormal);
   close(fLog);
 end;
 halt(ExitCode);
end;
{$F-}

function GetUniqueFname(oldFname:PathStr):PathStr;
{-создает уникальное имя, если уже существует файл oldFname}
{ ['0'..'9','a'..'z'] }
var
 f:file;
 _done:boolean;
 c:char;
 sl:byte absolute oldFname;

begin
 if ExistFile(oldFname) then begin
   _done:=false;
   oldFname[sl]:=LoCase(oldFname[sl]);
   c:=oldFname[sl];
   repeat
     Inc(byte(oldFname[sl]));
     if oldFname[sl] >'z' then oldFname[sl]:='0'
     else
      if oldFname[sl] in [':'..'`'] then oldFname[sl]:='a';
     {---}
     if not ExistFile(oldFname) then _done:=true
     else
       if oldFname[sl] =c then begin
         _done:=true;
         assign(f,oldFname);
         erase(f);
       end;
   until _done;
   if IoResult <>0 then;
 end;
 GetUniqueFname:=oldFname;
end;

procedure NetMail_ReadMsg;
var
 f:file;
 fMsg:text;
 msgFname:PathStr;
 s:string;

procedure ParseKludge;
var
 sk:string[7];
 n:word;

begin
 sk:=StLoCase(ExtractWord(1,s,[' ']));
 if sk =^A'intl' then begin
   Str2word(ExtractWord(2,s,[' ',':']),msgDest.Zone);
   Str2word(ExtractWord(1,ExtractWord(3,s,[' ']),[':']),msgOrig.Zone);
 end
 else
  if sk =^A'topt' then
    Str2word(ExtractWord(2,s,[' ']),msgDest.Point)
  else
   if sk =^A'fmpt' then
     Str2word(ExtractWord(2,s,[' ']),msgOrig.Point)
   else
    if sk =^A'msgid:' then begin
      Str2word(ExtractWord(2,s,[' ',':']),n);
      if msgOrig.Zone =0 then msgOrig.Zone:=n;
      if msgDest.Zone =0 then msgDest.Zone:=n;
    end;
end;

begin
 msgFname:=pCfgRec^.NetMail+Long2str(msgNo)+MsgXt;
 assign(f,msgFname);
 reset(f,1);
 if CheckError(msgFname,false) then exit;
 BlockRead(f,msgHdr,SizeOf(TmsgHdr));
 close(f);
 if CheckError(msgFname,false) then exit;

 FillChar(msgOrig,SizeOf(tAddress),0);
 FillChar(msgDest,SizeOf(tAddress),0);

 with msgHdr do begin
  with msgOrig do begin
   Net:=OrigNet;
   Node:=OrigNode;
  end;
  with msgDest do begin
   Net:=DestNet;
   Node:=DestNode;
  end;
 end;

 assign(fMsg,msgFname);
 reset(fMsg);
 TextSeek(fMsg,$BE);
 repeat
   readln(fMsg,s);
   if (Length(s) <>0) and (s[1] =^A) then ParseKludge;
 until EOF(fMsg);
 close(fMsg);
 CheckError(msgFname,false);
 Inc(msgScaned);
end;

function NetMail_Init:boolean;
begin
 NetMail_Init:=false;
 {$I+}
 FindFirst(pCfgRec^.NetMail+'*'+MsgXt,Archive,sr);
 {$I-}
 if DosError =18 then begin
   ToLog('No msgs in NetMail, nothing to do',lsMsgXs);
   halt(0);
 end
 else
  if DosError =0 then begin
    NetMail_Init:=true;
    Str2word(Copy(sr.Name,1,pred(Pos('.',sr.Name))),msgNo);
    NetMail_ReadMsg;
  end;
end;

function NetMail_GetNext:boolean;
begin
 {$I+}
 FindNext(sr);
 {$I-}
 if DosError =0 then begin
   NetMail_GetNext:=false;
   Str2word(Copy(sr.Name,1,pred(Pos('.',sr.Name))),msgNo);
   NetMail_ReadMsg;
 end
 else
  NetMail_GetNext:=true;
end;

procedure AddLinkData;
{-из Sf-Arc.cfg}
begin
 if nLink <MaxLink then begin
   Inc(nLink);
   GetMem(LinkInfo[nLink],SizeOf(tLinkInfo));
   if LinkInfo[nLink] =nil then begin
     TAshowError('Unable to add link','`'+ValString+#39);
     Dec(nLink);
     exit;
   end
   else with LinkInfo[nLink]^ do begin
     Str2addr(ExtractWord(1,ValString,[' ',^I]),LinkAddr);
     Str2long(ExtractWord(2,ValString,[' ',^I]),MaxArcSize);
   end;
 end;
end;

procedure AddRobot;
begin
 if nMan <MaxMan then begin
  Inc(nMan);
  GetMem(ManName[nMan],SizeOf(tMan));
  if ManName[nMan] =nil then begin
    TAshowError('Unable to add robot','`'+ValString+#39);
    Dec(nMan);
    exit;
  end;
  ManName[nMan]^:=StLoCase(ValString);
 end;
end;

function My_ManName:boolean;
begin
 My_ManName:=true;

 for i:=1 to nMan do
   if StLoCase(A2S(msgHdr.FromName)) =ManName[i]^ then exit;

 My_ManName:=false;
end;

function My_Address:boolean;
begin
 if (msgOrig.Zone =0) and ForceZone then
   msgOrig.Zone:=pCfgRec^.MyAddress[1].Zone;
 if (msgDest.Zone =0) and ForceZone then
   msgDest.Zone:=pCfgRec^.MyAddress[1].Zone;

 My_Address:=true;

 with pCfgRec^ do
  for i:=1 to AllAddress do
    if CompWordStruct(msgOrig,MyAddress[i],SizeOf(tAddress)) =Equal then exit;

 My_Address:=false;
end;

function FindLink:integer;
{-ищем ноду в списке линков}
begin
 FindLink:=0;
 for i:=1 to nLink do
  if CompWordStruct(msgDest,LinkInfo[i]^.LinkAddr,
                    SizeOf(tAddress)) =Equal then begin
    FindLink:=i;
    exit;
  end;
end;

function MoveFile(InFile,OutFile:PathStr):boolean;
{-пеpнос/пеpеименование файла из InFile в OutFile}
type
 FileBuffer=array[1..4096] of byte;

var
 OldDate:longint; {дата файла}
 InF,
 OutF:file;
 BlocksRead,
 BlocksWritten,
 BufSize:word;
 buf:^FileBuffer;
 I:integer;
 _s:string[6];

procedure MovePanicExit;
begin
 close(outF);
 I:=IoResult;
 close(inF);
 FreeMem(buf, BufSize);
 I:=IoResult; {на всякий случай}
end;

begin {MoveFile}
  MoveFile:=false;
  OutFile:=GetUniqueFname(OutFile);
  if (InFile[2] =':') and (OutFile[2] =':') and
     (LoCase(InFile[1]) =LoCase(OutFile[1])) then begin
    assign(inF,InFile);
    reset(inF,1);
    Inc(kbsMoved,FileSize(inF));
    close(inF);
    I:=IoResult;
    Rename(inF,OutFile);
    if IoResult <>0 then exit;
    _s:='Rename';
  end
  else begin
    _s:='Move';
    BufSize:=SizeOf(FileBuffer);
    if BufSize >MaxAvail then
       BufSize:=MaxAvail;
    GetMem(buf,BufSize);

    assign(inF,InFile);
    reset(inF,1);
    if CheckError(InFile,false) then begin
      MovePanicExit;
      exit;
    end;

    GetFtime(inF,OldDate); {взяли дату/вpемя пеpемещаемого файла}
    assign(outF, OutFile);
    rewrite(outF,1);
    if CheckError(OutFile,false) then begin
      MovePanicExit;
      exit;
    end;

    repeat
      BlockRead(inF, buf^, BufSize, BlocksRead);
      if CheckError(InFile,false) then begin
        MovePanicExit;
        exit;
      end;
      BlockWrite(outF, buf^, BlocksRead, BlocksWritten);
      if CheckError(OutFile,false) then begin
        MovePanicExit;
        exit;
      end;
    until (BlocksRead <BufSize);

    SetFtime(outF,OldDate); {устанавливаем новому файлу стаpую дату}
    Inc(kbsMoved,FileSize(inF));
    MovePanicExit; {все закpываем и освоб.память}
    erase(inF); {уничтожаем оpигинал}
  end;
  Inc(filesMoved);
  I:=IoResult; {на всякий случай...}
  ToLog(_s+' packet '+JustFileName(InFile)+' -> '+OutFile,lsFileXs);
  MoveFile:=true;
end; { MoveFile }

procedure KillMsg;
var
 f:file;
 s:string;

begin
 { создаем семафоp для пеpепаковки }
 with pCfgRec^ do begin
   MkAllDir(Flags_Dir+'REPACK.FLG',false);
   s:=Flags_Dir+'REPACK.FLG\'+AddrTo32(msgDest,false);
 end;
 assign(f,s);
 rewrite(f,1);
 if CheckError(s,false) then exit;
 close(f);
 ToLog('Semaphore created: '+s,lsFileXsDebug);

 assign(f,pCfgRec^.NetMail+Long2str(msgNo)+MsgXt);
 erase(f);

 Inc(msgKilled);

 ToLog('Msg #'+Long2str(msgNo)+' killed',lsFileXs);
end;

procedure ProcessMsg;
var
 fi:SearchRec;
 LinkNo:integer;
 f:file;
 as:longint;
 fn:PathStr;
 fbName:PathStr;

begin
 with msgHdr do begin
  fn:=A2S(Subj);
  ToLog('·∙■Msg #'+Long2str(msgNo)+' (dest '+_4D2str(msgDest)+')',lsNormal);
  ToLog('Attrs: '+MsgAttrs2str(Attribute),lsMsgXsDebug);
  ToLog('┌FROM: '+A2S(FromName)+' ('+_4D2str(msgOrig)+')',lsMsgXsDebug);
  ToLog('├TO:   '+A2S(ToName)+' ('+_4D2str(msgDest)+')',lsMsgXsDebug);
  ToLog('└SUBJ: '+fn,lsMsgXsDebug);

 Path4addr(false,msgDest,fbName);
 {$I+}
 FindFirst(fbName+'.bs?',Archive,fi);
 {$I-}
 if DosError =0 then begin
   ToLog('Link in session now - msg skiped',lsFileXs);
   exit;
 end;

 LinkNo:=FindLink;
 if LinkNo =0 then begin  {-неизвестный линк}
   ToLog('Unknown link: '+_4D2str(msgDest)+' - msg ignored',lsWarning);
   exit;
 end;

 assign(f,fn);
 reset(f,1);
  i:=IoResult;
  if i <>0 then
    if i =2 then begin  {-пакет не найден -- стиpаем письмо}
      TAshowError('Packet not found',fn);
      KillMsg;
      exit;
    end
    else begin
     TAshowError('Packet access denied',fn);
     exit;
    end;

 as:=FileSize(f);
 close(f);

 ToLog('Packet size ='+Long2str(as)+' bytes',lsFileXsDebug);

 if as <LinkInfo[LinkNo]^.MaxArcSize then
   ToLog('└─ less then crytical ('+
         Long2str(LinkInfo[LinkNo]^.MaxArcSize)+'b)',lsFileXsDebug)
 else with pCfgRec^ do begin
 {-пеpеносим пакет, убиваем письмо, стaвим семафоp}
  ToLog('└─ greater then crytical ('+
        Long2str(LinkInfo[LinkNo]^.MaxArcSize)+
        'b) - will be moved',lsFileXsDebug);
  fbName:=AddrTo32(msgDest, msgHdr.Attribute and bMsgFlag[_Hold] <>0);
  MkAllDir(File_Boxes+fbName,false);

  {-пеpетаскиваем пакет в файл-бокс}
  if MoveFile(fn,File_Boxes+fbName+'\'+JustFileName(fn)) then
    KillMsg;  {-убиваем письмо и ставим семафоp}
 end;

 end; {WITH}
end;

{$I Sf-Arc.pp}

procedure Usage;
begin
 writeln(#13#10'Syntax: Sf-Arc [switches]'#10);
 halt(255);
end;

procedure ParseCmdLine;
var
 n:byte;
 s:string;
 w:word;

begin
 CfgFname:='Sf-Arc.cfg';
 if ParamCount <>0 then
  for n:=1 to ParamCount do begin
    s:=StLoCase(ParamStr(n));
    if s[1] in ['-','/'] then
     case s[2] of
      'c': if Length(s) >5 then
             CfgFname:=copy(s,3,81);
      '?','h': Usage;
      'n': if Str2word(copy(s,3,2),w) then
            Task:=w;
     else begin
            TAshowError('Unrecognized switch `'+s+#39,'');
            Usage;
          end;
     end;
  end;
end;

begin
 writeln(#10+PID+': '+xPID+'; '+VID+#13#10+CID+#10);

 {-начальные паpаметpы-}
 ForceZone:=false;  {игноpиpовать письма без MSGID/INTL}
 nLink:=0;
 nMan:=0;
 Sf_MailCfgFname:='';
 LogName:='Sf-Arc.log';
 LogLevel:='.!?:$-';

 ShowErrorPtr:=@TAshowError;
 OldHalt:=ExitProc;
 ExitProc:=@TAhalt;

 ParseCmdLine;

 {*читаем t-Arc.cfg*}
 ReadTAconfig;

 {*читаем Sf-Mail.cfg*}
 if (Length(Sf_MailCfgFname) =0) or
    (Read_Config(Sf_MailCfgFname)<> rcsOk) then begin
   TAshowError('Unable to load Sf-Mail`s configuration from',
               '`'+Sf_MailCfgFname+#39);
   halt(255);
 end;

 if Length(pCfgRec^.File_Boxes) =0 then begin
   TAshowError('Undefined File_Boxes variable in','`'+Sf_MailCfgFname+#39);
   halt(255);
 end;

 assign(fLog,LogName);
 append(fLog);
 i:=IoResult;
 if i <>0 then
  if i =2 then rewrite(fLog)
  else begin
    TAshowError('Unable open log',LogName);
    halt(255);
  end;

 writeln(fLog,#13#10'───── '+MsgDateStamp+', '+PID+' ['+VID+']');

 {-инициализация NetMail`a-}
 if not NetMail_Init then begin
   TAshowError('Unable to init netmail folder',pCfgRec^.NetMail);
   halt(255);
 end;

 msgScaned:=0;
 msgKilled:=0;
 filesMoved:=0;
 kbsMoved:=0;

 {-читаем почту-}
 repeat
  with msgHdr do
   if My_ManName and My_Address and
      (Pos(StUpCase(copy(A2S(Subj),Length(A2S(Subj))-2,2)),ArcExt) <>0) and
      ((Attribute and bMsgFlag[_Attach]) <>0) {and}
      (***((Attribute and bMsgFlag[_Hold]) <>0)***) then ProcessMsg;
 until NetMail_GetNext;
end.
