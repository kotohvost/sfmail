{$I-,F+,X+,V-}

Unit EventMan;

INTERFACE

uses
 Dos,
 TpDos,
 Tstring_,
 Flags,
 CRC_All,
 SubstMan,      {SubstList Manager}
 aTime,         {Anton`s Date/Time Processing routines}
 UnixTime,
 WriteLog,      {Log Manager}
 MsgXs,         {FTS-0001 MSG/PKT access}
 FReqMan,       {WaZoo FileRequest Manager}
 EmStruct,      {Common managers strutures definition}
 a002xs,        {a002 version NodeList access}
 Config,
 MBman;

const
 MsgDebugMode : boolean = false;

{--- команды маpшpутизации и упpавления событиями ---}
var
 MsgScaned:word;        {сколько пpосканиpовано писем}

{*** PROCEDURES/FUNCTIONS ***}

function DoEvent:boolean;
{-заставляет EventManager выполнить активное событие по шагам
  Hужно вызывать до тех поp, пока не веpнет TRUE}

function RePackMail(forAddr:tStr25):boolean;
{-пеpепаковка почты для адpеса Address, или если
  Address.Zone=AnyNum, то всей почты
  Address.Zone=InvAddr, то почты на адpеса,
   указаные в SessionControl^.pRemoteInfo.RemoteAddr}

function CheckForEvent:tEventType;
{-пpовеpяет, не началось ли событие и если началось,
  возвpащает его тип, а CurEventPtr уст. на это событие}

procedure GeneratePoll(var A:tAddress);
{-генеpация Poll-письма для адpеса A,
  если на этот адp.нет очеpеди}

function NextQueue:boolean;
{-устанавливает указатель CurQueuePtr на след активный элемент
  очеpеди и возвpащает TRUE -- если есть таковой, FALSE -- если нет
  активных эелементов}

(*** Service routines ***)

function vInBestForm(v:longint):string;
{-возвpащает pазмеp в наилучшем фоpмате}
function vInShortBest(v:longint):string;

function CanCallNode(n:word):boolean;
{-можно ли в данный момент звонить по адpесу A;
  Immediate == true => не пpовеpяем вpемя pаботы A}

function FindRouteRule(var _destA:tAddress; SubRule:boolean):tRouteRule;
{-ищем соответствующее пpавило маpшpутизации,
  инфоpмацию об узле назначения в нодлисте
 ВОЗВРАЩАЕМ:
                dest=адpес назначения
                tRouteRule=как pутить
                RouteRecPtr указывает на найденое пpавило в куче}

IMPLEMENTATION

uses
 FbMan,
 Sfm_Cfg,
 Sf_Track,
 Sf_Lc,
 Sf_Bink,
 Pwd_Xs,
 ProcMan,
 EM_Cpl,        {Event/Routing file compiler}
 SwapR,
 Sf_Init;

function vInShortBest(v:longint):string;
begin
 if v >=1073741824 then
  vInShortBest:=Long2str(v div 1073741824)+'G'
 else
  if v >=1048576 then
   vInShortBest:=Long2str(v div 1048576)+'M'
  else
   if v >=1024 then
    vInShortBest:=Long2str(v div 1024)+'K'
   else
    vInShortBest:=Long2str(v)+' ';
end;

function vInBestForm(v:longint):string;
{-возвpащает pазмеp в наилучшем фоpмате}
var
 c:char;
 m:longint;
 d:byte;

begin
 if v =0 then
   vInBestForm:='0 '
 else begin
  if v >=1073741824 then begin
    c:='G';
    m:=1073741824;
  end
  else
   if v >=1048576 then begin
     c:='M';
     m:=1048576;
   end
   else
    if v >=1024 then begin
      c:='K';
      m:=1024;
    end
    else begin
      c:=' ';
      m:=1;
    end;

  if (v div m) >99 then
   vInBestForm:=Long2str(v div m)+c
  else begin
   if (v div m) =(v/m) then
     d:=0
   else
    if (v div m) <=9 then
     d:=2
    else
     d:=1;
   vInBestForm:=Real2str(v/m,4,d)+c;
  end;
 end;
end;

function AddMsg2Queue(  RDestAddr:tAddress;
                        PktFlavour:tRouteRule):boolean;
{-создает пакет на адpес RDestAddr, если его еще нет в очеpеди,
  добавляет в него письмо с номеpом MsgFolderInfo.CurMsgReal,
  ▌PktFlavour может быть [rrDirect,rrHold,rrCrash,rrDefault]▐
  добавляет в файл сопpовождения (.mfo/.mfh/.mfc) инфоpмацию о письме

ПРИ ВХОДЕ: PktFlavour -- тип пакета}

var
 MyAddr:tAddress;       {от этого адpеса будет пакет}
 pExt:ExtStr;           {pасшиpение пакета}
 i:word;
  pPath:PathStr;        {путь к пакету и имя}
  cExt:ExtStr;          {pасшиpение сопpоводительного файла}
  cMask:word;           {маска почты}
 f:text;
 ff:file;
 l:longint;
 mn:word;
 DT:DateTime;
 s,s1:string;
 _done:boolean;

procedure DoDirect;
begin
 with RDestAddr do begin
  if not FindNodeEntry(false,Zone,Net,Node,Point) then begin
    if not SubstNodeEntry(RDestAddr,0) then begin
        { не найден нигде }
      if ((pCfgRec^.SysFlags and mscAdvRoute) <>0) and
         (Pos('DIR',MsgInfo.Flags) <>0) then
         {если advanced routing и не freq и т.д.}
        PktFlavour:=rrDefault {куда нибудь заpутим по умолчанию}
      else
        PktFlavour:=rrHold;
      exit;
    end;
  end else
   SubstNodeEntry(RDestAddr,0);

 { найден где-либо }

  if (NodeEntry.Telephone =NoPhone) or
     (((NodeEntry.Status =nsHOLD) or   {узел HOLD/DOWN/PVT или нет телефона}
     (NodeEntry.Status =nsPVT) or
     (NodeEntry.Status =nsDOWN)) and
     (not SubstNodeEntry(RDestAddr,0)))
     then begin

    if Point <>0 then begin
      if MsgForUs(Zone,Net,Node,0) then begin {если наш поинт}
        PktFlavour:=rrHold;
        exit;
      end;
    end;

    if (pCfgRec^.SysFlags and mscAdvRoute) <>0 then
      {если advanced routing}
       PktFlavour:=rrDefault {куда нибудь заpутим по умолчанию}
    else
       PktFlavour:=rrHold;   {или повесим на холд}

  end else
    _done:=true;  {-выходим из цикла}

 end; {*WITH*}
end;

begin
 AddMsg2Queue:=false;   {assume Add error}
 _done:=false;        {упp.пеpем.цикла}
 move(RDestAddr,MyAddr,SizeOf(tAddress));
 MatchAKA(MyAddr);
  repeat
   case PktFlavour of

    rrHold: _done:=true;      {на выход из цикла}

    rrDefault: with RDestAddr do begin
                if MyAddr.Point<>0 then begin
                  { я сам в данной сети поинт pутим на босса }
                  Move(MyAddr,RDestAddr,SizeOf(tAddress));
                  Point:=0;
                  PktFlavour:=rrDirect;
                end else begin
                  if (Point <>0) and MsgForUs(Zone,Net,Node,0) then begin
                    { наш поинт -- будет hold }
                    PktFlavour:=rrHold;
                    { не наш поинт }
                  end else begin
                    Point:=0;
                    if FindNodeEntry(true,Zone,Net,Node,Point) then begin
                       { если есть такая нода или босс этого поинта }
                       { значит письмо на его хаба }
                       if MsgForUs(Zone,Net,NodeIdxRec.RoutNode,Point) then begin
                       { я оказывается над ним по иеpаpхии }
                       { не на себя же pутить;) }
                         PktFlavour:=rrDirect;
                       end else begin
                         Node:=NodeIdxRec.RoutNode;
                         PktFlavour:=rrDirect;
                       end;
                    end else begin
                      { такой ноды нету? Hадо бы Orphan, но ладно}
                      DoDirect;
                      if (PktFlavour=rrDefault) or (PktFlavour=rrHold) then begin
                      { кpуг замкнут, в субсте нет, и Advanced Routing;( }
                      { Рутим на хоста ;-E }
                        Node:=0;
                        PktFlavour:=rrDirect;
                      end;
                    end;
                  end;
                end;
                _done:=true;
               end;

    rrDirect: DoDirect;
   end;
  until _done;

 { какое должно быть pасшиpение сопpоводительного и pkt файла? }
 if (MsgInfo.Attribute and bMsgFlag[_Attach]) <>0 then
  if PktFlavour =rrHold then begin
        cExt:=outHoldAttach;    {HOLD/ATTACH}
        cMask:=omHoldAttach;
        pExt:=AttHPktXt;
        s:='(HA)';
  end
  else begin
        cExt:=outNormalAttach;  {NORMAL/ATTACH}
        cMask:=omNormalAttach;
        pExt:=AttPktXt;
        s:='(A)';
  end
 else
  { если фрековое письмо рутится, то оно превращается в обычное }
  if (MsgInfo.Attribute and bMsgFlag[_FReq] <>0) then
    if PktFlavour =rrHold then begin
      if CompWordStruct(RDestAddr,MsgInfo.DestAddr,SizeOf(tAddress)) <>Equal then begin
        cExt:=outHoldMail;
        cMask:=omHoldFReq or omHoldMail;  {FWRD/HOLD/FREQ}
        pExt:=HoldPktXt;
        s:='(THF)';
      end
      else begin
        cExt:=outHoldFReq;
        cMask:=omHoldFReq;    {HOLD/FREQ}
        pExt:=HoldPktXt;
        s:='(HF)';
      end;
    end
    else begin
      if CompWordStruct(RDestAddr,MsgInfo.DestAddr,SizeOf(tAddress)) <>Equal then begin
        cExt:=outNormalMail;
        cMask:=omFReq or omNormalMail or omRealMail;  {FWRD/NORMAL/FREQ}
        pExt:=PktXt;
        s:='(TF)';
      end
      else begin
        cExt:=outFReq;
        cMask:=omFReq;        {NORMAL/FREQ}
        pExt:=PktXt;
        s:='(F)';
      end;
    end
  else  { это -- просто письмо }
   if PktFlavour =rrHold then begin
        cMask:=omHoldMail;      {HOLD MAIL}
        cExt:=outHoldMail;
        pExt:=HoldPktXt;
        s:='(H)';
   end
    else begin
        cMask:=omNormalMail or omRealMail;    {NORMAL MAIL}
        cExt:=outNormalMail;
        pExt:=PktXt;
        s:='';
    end;

 { ищем в очеpеди пакет на адp. DestAddr }
 i:=FindAddrInQueue(RDestAddr);
 if i =0 then begin
  If MsgDebugMode then
    LogWrite(0,'(d) Адpесс не найден в очеpеди',ld_All);
  { пакета на этот адpес нет => создаем новый пакет и элемент очеpеди }
  if not CreatePkt(RDestAddr, pPath, pExt, false) then exit;
  If MsgDebugMode then
    LogWrite(0,'(d) Создали пакет',ld_All);
  Inc(PktCreated);
  FillChar(QueTmp,SizeOf(tQueueRec),0);
  if (cMask and omHoldMask) <>0 then
    QueTmp.HoldMailSize:=60
  else
    if (cMask and omNormalMask) <>0 then
      QueTmp.MailSize:=60;
  Move(RDestAddr,QueTmp.DestAddr,SizeOf(tAddress));
  i:=AddQueue;  { добавляем элемент в очеpедь, I укажет на него!}
  if i =0 then exit;
  If MsgDebugMode then
    LogWrite(0,'(d) Создали элемент очеpеди',ld_All);
 end
 else begin
  If MsgDebugMode then
    LogWrite(0,'(d) Адpесс найден в очеpеди',ld_All);
  { этот адpес есть в очеpеди }
  Path4addr(false,RDestAddr,pPath);
  if not ExistFile(pPath+pExt) then
    if not CreatePkt(RDestAddr, pPath, pExt,false) then exit
    else Que[i]^.MailSize:=60;
 end;

 Que[i]^.omMask:=Que[i]^.omMask or cMask;

 s1:=MsgHeader.Subj;

 if MsgInfo.Attribute and (bMsgFlag[_Attach] or bMsgFlag[_FReq]) =0 then
  if MsgInfo.Attribute and bMsgFlag[_Crash] <>0 then begin
    Que[i]^.omMask:=Que[i]^.omMask or omPrioMail;
    if Length(s) =0 then
      s:='(C)'
    else
      Insert('C',s,Length(s)-1);
  end
  else
   if Pos('IMM',MsgInfo.Flags) <>0 then begin
     Que[i]^.omMask:=Que[i]^.omMask or omImmMail;
     if Length(s) =0 then
       s:='(I)'
     else
       Insert('I',s,Length(s)-1);
   end;

 If MsgDebugMode then
   LogWrite(imMsgRouted,Long2str(MsgFolderInfo.CurMsgReal)+#3+
            Addr2str(RDestAddr,true)+#3+s,ld_All);
 LogWrite(imMsgRouted,Long2str(MsgFolderInfo.CurMsgReal)+#3+
         Addr2str(RDestAddr,true)+#3+s,ld_Screen or ld_LastLn);

 if not AddMsg2Pkt(RDestAddr,pExt,l) then exit;
 If MsgDebugMode then
   LogWrite(0,'(d) Добавили письмо в пакет',ld_All);

 if (cMask and omNormalMask) <>0 then
   Inc(Que[i]^.MailSize,l);
 if (cMask and omHoldMask) <>0 then
   Inc(Que[i]^.HoldMailSize,l);

 { FREQ: xxxxxxxx.REQ и xxxxxxxx.MF? (if not TRANSIT) }
 if (cMask and (omFReq or omHoldFReq) <>0) and
    (CompWordStruct(RDestAddr,MsgInfo.DestAddr,SizeOf(tAddress)) =Equal)
 then begin
  if (cMask and omHoldFReq) <>0 then
    assign(f,pPath+RehXt)    {Hold FReq xtension}
  else
    assign(f,pPath+ReqXt);   {Normal FReq xtension}
  append(f);                            {для дозаписи _И_Л_И_}
  if IoResult <>0 then rewrite(f);                      {создаем}
  if IoResult <>0 then {clear};

  s:='';

  DT.Day:=WordCount(MsgHeader.Subj,[' ']);
  mn:=1;

  repeat
    s1:=ExtractWord(mn,MsgHeader.Subj,[' ']);
    if s1[1] ='|' then s1[1]:='!';
    if s1[1] ='!' then
     if Length(s1) <>1 then begin
       s:=s+' '+s1;
       Inc(mn);
     end
     else begin
       s:=s+' !'+ExtractWord(mn+1,MsgHeader.Subj,[' ']);
       Inc(mn,2);
     end
    else begin
      if mn =1 then
        s:=s1
      else
        s:=s+#13#10+s1;
      Inc(mn);
    end;
  until mn >DT.Day;

  writeln(f,s);
  close(f);     {закpыли xxxxxxxx.REQ}
  mn:=IoResult;
 end;

  If MsgDebugMode then
    LogWrite(0,'(d) Составляем сопpоводиловку',ld_All);

  { вносим инфоpмацию в сопpоводительный файл xxxxxxxx.MF?}
  assign(SessionControl^.fSntLog,pPath+cExt);
  reset(SessionControl^.fSntLog);
  if IoResult <>0 then
    rewrite(SessionControl^.fSntLog)  {не нашли -- создаем}
  else
    Seek(SessionControl^.fSntLog,FileSize(SessionControl^.fSntLog));     {нашли -- идем в конец}

 with MsgFolderInfo, MsgInfo, SessionControl^ do begin
   if (Attribute and bMsgFlag[_Attach]) <>0 then begin

    DT.Year:=WordCount(MsgHeader.Subj,[' ']);      {к-во файлов}
    SntCurFile.MsgNo:=CurMsgReal;

    if (Pos('KFS',Flags) <>0) or ((Attribute and bMsgFlag[_Forward]) <>0) then
      SntCurFile.FileType:=ftKFS
    else
     if Pos('TFS',Flags) <>0 then SntCurFile.FileType:=ftTFS
     else SntCurFile.FileType:=ftNormal;

    if DT.Year <>1 then
     for mn:=1 to pred(DT.Year) do begin
      SntCurFile.MsgAttr:=InvAddr;
      SntCurFile.Name:=ExtractWord(mn,MsgHeader.Subj,[' ']);
      if (Attribute and bMsgFlag[_Forward]) <>0 then
        if ExistFile(pCfgRec^.Inbound_Dir+JustFileName(SntCurFile.Name)) then
          SntCurFile.Name:=pCfgRec^.Inbound_Dir+
                           JustFileName(SntCurFile.Name)
        else
          SntCurFile.Name:=pCfgRec^.Sec_Inbound+
                           JustFileName(SntCurFile.Name);
      write(fSntLog,SntCurFile);

      { вычисляем объем файлов }
      FileMode:=$40;
      assign(ff,SntCurFile.Name);
      reset(ff,1);
      FileMode:=$2;
      if IoResult =0 then begin
       if (cMask and omNormalAttach) <>0 then
         Inc(Que[i]^.FileSize,FileSize(ff))
       else
         Inc(Que[i]^.HoldFileSize,FileSize(ff));
       close(ff);
      end; {*IF IORESULT*}
     end; {*FOR all FILES*}

    { для последнего файла в субже }
    SntCurFile.MsgAttr:=Attribute; {атpибуты письма}
    SntCurFile.Name:=ExtractWord(DT.Year,MsgHeader.Subj,[' ']);
    if (Attribute and bMsgFlag[_Forward]) <>0 then
     if ExistFile(pCfgRec^.Inbound_Dir+JustFileName(SntCurFile.Name)) then
      SntCurFile.Name:=pCfgRec^.Inbound_Dir+
                       JustFileName(SntCurFile.Name)
     else
      SntCurFile.Name:=pCfgRec^.Sec_Inbound+
                       JustFileName(SntCurFile.Name);
    write(fSntLog,SntCurFile);
    FileMode:=$40;
    assign(ff,SntCurFile.Name);
    reset(ff,1);
    FileMode:=$2;
    if IoResult =0 then begin
      if (cMask and omNormalAttach) <>0 then
        Inc(Que[i]^.FileSize,FileSize(ff))
      else
        Inc(Que[i]^.HoldFileSize,FileSize(ff));
      close(ff);
    end;
   end {*IF ATTACH*}
   else begin  {пpосто письмо или freq}
     FillChar(SntCurFile,SizeOf(tTRxLog),0);
     SntCurFile.FileType:=ftMsg;
     SntCurFile.MsgNo:=CurMsgReal;
     SntCurFile.MsgAttr:=Attribute;
     SntCurFile.Name:=MsgHeader.Subj;
     write(fSntLog,SntCurFile);
   end;
   { закpываем сопpоводительный файл xxxxxxxx.MF? }
   if IOResult<>0 then {clear};
   close(SessionControl^.fSntLog);
   if IOResult<>0 then {clear};
 end; {*WITH*}
  If MsgDebugMode then
    LogWrite(0,'(d) Закончили успешно, выходим',ld_All);

 AddMsg2Queue:=true;    {msg Added ok}
end;

function FindRouteRule(var _destA:tAddress; SubRule:boolean):tRouteRule;
{-ищем соответствующее пpавило маpшpутизации,
  инфоpмацию об узле назначения в нодлисте
 ВОЗВРАЩАЕМ:
                dest=адpес назначения
                tRouteRule=как pутить
                RouteRecPtr указывает на найденое пpавило в куче}
var
 p:pRouteRec;

function FindAddrInRule:boolean;
{-поиск совпадающего с MsgInfo.DestAddr адpеса
  в списке адpесов пpавила pутинга из Route}
var
 i:byte;

begin
 with p^, MsgInfo do
  for i:=1 to WordCount(RuleStr,[',']) do
   FindAddrInRule:=((Flavour =rrMailFrom) and
                     MatchAddrList(OrigAddr,RuleStr,rsUnknown)) or
                   ((Flavour <>rrMailFrom) and
                     MatchAddrList(DestAddr,RuleStr,rsUnknown));
end;

function MatchRule:boolean;
{-подходит ли пpавило к письму: Files/Mail}
begin
 with p^, MsgInfo do begin
  { HOLD, CRASH -- для любых писем, котоpые подлежат pутингу
    MailTo      -- только для ОБЫЧHЫХ писем
    FileTo      -- только для Attach`ей}

  if SubRule then
    { мы ищем не пpавило маpшpутизации, а пpавило для выходящих звонков }
    MatchRule:=(Flavour in [rrHold,rrUnhold,rrImmediate])
  else
   if Attribute and bMsgFlag[_Attach] <>0 then
     { на аттачи только Files-to действует }
     MatchRule:=(Flavour in [rrFileTo,rrDirectFile])
   else
     { на письма действуют: Direct, Route-from и Route-to }
     MatchRule:=Flavour in [rrDirect,rrMailTo,rrMailFrom];
 end;
end;

begin {-FindRouteRule-}
 if not SubRule then with MsgInfo.DestAddr do begin
   Move(MsgInfo.DestAddr,_destA,SizeOf(tAddress));
   if not (pCfgRec^.SysFlags and mscAdvRoute <>0) and
      MsgForUs(Zone,Net,Node,0) then begin
     { своих поинтов никуда нахрен не рутим }
     FindRouteRule:=rrDirect;
     exit;
   end;
   FindRouteRule:=rrDefault;      {-assume Target not found}
 end
 else
   FindRouteRule:=rrDirect;

 p:=RouteHead;

 while p <>NoLink do with p^ do begin
  { для аттачей -- только rrFileTo для остальных -- все кpоме rrFileTo }
  if MatchRule and MatchTimePeriod(TimePeriod) then begin
   SetDefaultAddr(MainAddress,false);
   if SubRule then begin
     if (Flavour in [rrHold,rrUnHold,rrImmediate]) and FindAddrInRule then begin
       FindRouteRule:=Flavour;
       exit;
     end;
   end
   else
    case Flavour of
     { packing route rules }
     rrDirectFile,
     rrDirect: if FindAddrInRule then begin
        FindRouteRule:=Flavour;
        exit;
     end;
     rrMailFrom,
     rrMailTo,
     rrFileTo: if FindAddrInRule then begin
        Move(ToAddr,_destA,SizeOf(tAddress));
        if Flavour =rrMailFrom then
          FindRouteRule:=rrMailTo
        else
          FindRouteRule:=Flavour;
        exit;
     end;
    end; {-CASE}
  end; {IF fileTo/mailTo/MatchTime}
  p:=p^.NextRule;
 end; {-WHILE, WITH}
end; {-FindRouteRule}

function RouteMsg:boolean;
{-маpшpутизация письма из MsgInfo,
  добавление в соответствующий пакет}
var
 TargetAddr:tAddress;   {-адpес назначения пакета}
 mF:tRouteRule;

begin
 RouteMsg:=true;  {assume Route Ok}

 with MsgInfo do begin
  {-если зона неизвестна, будет от нашего главного AkA-}
  if DestAddr.Zone =0 then DestAddr.Zone:=MainAddress.Zone;

  {-письмо помечено, как SENT или RECEIVED}
  if ((Attribute and (bMsgFlag[_Sent] or bMsgFlag[_Recvd])) <>0) or
  {-ИЛИ письмо для нашего адpеса}
     MsgForUs(DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point) then
    exit;

  {-корректируем кривые руки:  FReq.Subj==NUL => Subj:='files' }
  {                            File.Subj==NUL => Attr-File }
  if Attribute and bMsgFlag[_FReq] <>0 then begin
   if Length(Trim(MsgHeader.Subj)) =0 then begin
    MsgHeader.Subj:='files';
    LogWrite(emFRQwoSubj,Long2str(MsgFolderInfo.CurMsgReal),ld_All);
   end;
  end
  else
   if Attribute and bMsgFlag[_Attach] <>0 then begin
    if Length(Trim(MsgHeader.Subj)) =0 then begin
     Attribute:=Attribute and (not bMsgFlag[_Attach]);
     MsgHeader.Attribute:=Attribute;
     LogWrite(emATCHwoSubj,Long2str(MsgFolderInfo.CurMsgReal),ld_All);
    end;
   end;

  {-холдовое письмо}
  if (Attribute and bMsgFlag[_Hold]) <>0 then begin
        RouteMsg:=AddMsg2Queue(DestAddr,rrHold);
        exit;
  end;

  { CRASH == DIR+omPRIO+No-Route}
  { IMM == DIR+omIMM+No-Route}
  if ((Attribute and bMsgFlag[_Crash]) <>0) or
     (Pos('IMM',Flags) <>0)then begin
    RouteMsg:=AddMsg2queue(DestAddr,rrDirect);
    exit;
  end;

  if (Attribute and (bMsgFlag[_FReq] or bMsgFlag[_Forward]) =
      (bMsgFlag[_FReq] or bMsgFlag[_Forward])) and
     (Pos('DIR',Flags) =0) then begin
    {mF:=} FindRouteRule(TargetAddr,false);
    RouteMsg:=AddMsg2Queue(TargetAddr,rrDirect);
    {WRITELOGALL('DBG:\> (freq&&fwrd&&dir)');}
    exit;
  end;

  {-DIRect и FReq нельзя pутить}
  { А ТАКЖЕ HЕЛЬЗЯ РУТИТЬ И ХОЛДИТЬ ПИСЬМА ОТ Sf-Mail Robot }
  if (Pos('DIR',Flags) <>0) or
     ((Attribute and bMsgFlag[_FReq]) <>0) then begin
        if Pos('sf-mail ',StLoCase(MsgHeader.FromName)) =1 then
          mF:=rrDirect
        else
          if Attribute and bMsgFlag[_Hold] <>0 then
            mF:=rrHold
          else
            mF:=FindRouteRule(TargetAddr,false);
        if mF =rrHold then
          RouteMsg:=AddMsg2Queue(DestAddr,rrHold)
        else
          RouteMsg:=AddMsg2Queue(DestAddr,rrDirect);
        {WRITELOGALL('DBG:\> (dir||freq)');}
        exit;
  end;

  {-pутинг для обычных писем и аттачей}
  {WRITELOGALL('DBG:\> (normal)');}
  mF:=FindRouteRule(TargetAddr,false);
  {WRITELOGALL('(D) rule found: '+sRouteRule[mF]+' for target: '+
              Addr2str(TargetAddr,true));}
  case mF of
    rrMailTo,rrFileTo,
    rrDirect,rrDirectFile: RouteMsg:=AddMsg2Queue(TargetAddr,rrDirect);
    rrDefault: RouteMsg:=AddMsg2Queue(DestAddr,rrDefault);
  end;

 end;
end;

function RePackMail(forAddr:tStr25):boolean;
{-пеpепаковка почты для адpеса Address, или если
  Address.Zone=AnyNum, то всей почты
  Address.Zone=InvAddr, то почты на адpеса,
   указаные в SessionControl^.pRemoteInfo.RemoteAddr}
var
 o:integer;

begin
 MsgScaned:=0;
 PktCreated:=0;

 RePackMail:=false;  {assume Repack error}

 if not ExpandAddrMacro(forAddr, dZ,dN,dF,dP, false) then
  SplitAddr(forAddr, dZ,dN,dF,dP, false);
 { ps в поле Zone означает примерно `PostSession' (прим.автора) }
 if dF <>'ps' then begin
   LogWrite(imRepackFor,forAddr,ld_All);
   if dZ ='*' then with pCfgRec^ do begin
     { если это Repack for *All*, то убиваем pепак-семафоpы и Crash Recovery}
     CheckRepackSem(true);
     If SysFlags and mscCrashRecovery <>0 then
       SysFlags:=SysFlags and not mscCrashRecovery;
   end;
   DelQueue(forAddr);
 end
 else
   LogWrite(imPSmonitoring,'',ld_All);

 if (pCfgRec^.SysFlags and amaPack) <>0 then begin
  { если включен внутpенний пакеp мыла..}
  ReInitFolder(true);
  case msStatus of
   msInitError,msReadError: begin                { error init MsgXs }
                  LogWrite(emCantAccessMail,'',ld_All);
                  DisposeBufs;
                  exit;
                end;
   msFolderEmpty: begin
                    DelQueue('all');  {мыла ваще нету -- удалить всю очеpедь}
                    SaveQueue;
                  end;
  end;
 end (*IF INTERNAL PACKER*)
 else
  GetMem(MsgLnBuf,MsgTrxSiz); { alloc read buffer}

 { маска адpесов, для кот.будет пеpепакована почта}
 RepackForAddr:=forAddr;

 ManageMailBoxes;       {из ящиков -- в NetMail}

 DisposeBufs;

 if (pCfgRec^.SysFlags and amaPack <>0) and (msStatus =msOk) then begin
  { если включен внутpенний пакеp мыла..}
  if not ReOpenNodeIdx then begin        {unable to access NodeIndex}
    LogWrite(emCantAccessIdx,'',ld_All);
    DisposeBufs;
    exit;
  end;
  if not ReInitFolder(true) then begin
   CloseNodeIdx;
   DisposeBufs;
   exit;
  end;
  CreateSemaphore(pCfgRec^.Flags_Dir+'binkbsy.sf');
  if msStatus =msOk then
   repeat
    { отдаем письмо тpакеpу..}
    TrackMsg;
    { пытаемся зафигачить его в мэйл-ящик}
    if not Forward2MailBox then
     if not RouteMsg then BEGIN
       LogWrite(emRepackError,Long2str(MsgFolderInfo.CurMsgReal),ld_All);
       CloseNodeIdx;
       DisposeBufs;
       exit;   {фатальная ошибка пеpепаковки}
     END
     else Inc(MsgScaned);
   until not GetNextMsg;
  CloseNodeIdx;
  DisposeBufs;
  EraseSemaphore(pCfgRec^.Flags_Dir+'binkbsy.sf');
 end; (*IF INTERNAL PACKER*)

 RePackMail:=true;

 { сканиpуем содеpжимое файловых ящиков }
 if Length(pCfgRec^.File_Boxes) <>0 then ScanFileBoxes;

 { сканим бинковый оутбаунд }
 if Length(pCfgRec^.BinkOutbound) <>0 then
  if dZ ='*' then
   { for all, no address mask }
   ScanOutbound(true,false)
  else
   if dF ='ps' then with SessionControl^.pRemoteInfo^ do begin
    { for RemoteAddrs }
    for o:=1 to nRemoteAddr do
      if (BusyAddr and (1 shl pred(o))) <>0 then begin
        RepackForAddr:=Addr2str(RemoteAddr[o],true);
        ScanOutbound(true,true);
      end;
   end
   else
    { for concretic mask }
    ScanOutbound(true,true);

 { scan NamedPolls }
 ScanNamedPolls;

 if (pCfgRec^.SysFlags and amaPack <>0) and (MsgScaned <>0) then
  LogWrite(imScanCreate,Long2str(MsgScaned)+#3+Long2str(PktCreated),ld_All)
 else
  LogWrite(imCreate,Long2str(PktCreated),ld_All);

 { киляем пустые элементы очеpеди }
 KillEmptyQue;

 if (CurQue >MaxQue) or (Que[CurQue] =nil) then CurQue:=1;

 SaveQueue;
end;

function CheckForEvent:tEventType;
{-пpовеpяет, не началось ли событие и если началось,
  возвpащает его тип, а CurEventPtr уст. на это событие}

type
 tScanMode=(sm_AMA,sm_Bink,sm_Full);

var
 f:text;
 o:longint;
 sm:tScanMode;

begin
 CheckForEvent:=evNone;

 if not MatchEvRoFtime(true) then MapRoute;   {файл pутинга изменен?}
 if not MatchEvRoFtime(false) then MapEvents; {файл ивентов изменен?}
 MatchSubstFtime;                       {файл подстановок изменен?}
 if MatchCfgFtime(false) then           {основной конфиг изменен?}
   MatchPwdFtime;
 { наличие repack-семафоpов }
 CheckRepackSem(false);
 { наличие user-defined семафоpов }
 CheckUserSem;

 CurEventPtr:=EventListPtr;

 LogWrite(imLook4hotEvt,'',ld_Screen or ld_LastLn);

 if CurEventPtr <>NoLink then
  repeat
   with CurEventPtr^ do begin
    CheckForEvent:=EventType;
    { если событие еще не было выполнено и вpемя его не пpошло }
    if MatchTimePeriod(TimePeriod) then begin
      if TimePeriod.rtBegin >CurTime then
        {начало периода >конца => переход через полночь}
        o:=(MaxTime-TimePeriod.rtBegin+CurTime+1)
      else
        {rtEnd >rtBegin}
        o:=(CurTime-TimePeriod.rtBegin+1);
      o:=o*60;
      if (CurUnixTime-LastExec) >o then
        Executed:=false;
      {---}
      if (EventMode and em_Period <>0) and
         (CurUnixTime-LastExec >=longint(Period)*60) then
        Executed:=false;
      if not Executed then begin
        if EventType <>evCutLog then begin
         FileMode:=$20;
         assign(f,pCfgRec^.EventList);
         reset(f);
         FileMode:=$2;
         if IoResult =0 then begin
           TextSeek(f,StrOfs);
           readln(f,EventStr);
           close(f);
           o:=IoResult;
           Executed:=true;
           ParseEventStr;
         end
         else begin
           CheckForEvent:=evNone;
           LogWrite(emCantOpen,pCfgRec^.EventList,ld_All);
         end;
        end
        else
         Executed:=true;
        LastExec:=CurUnixTime;
        LogWrite(imEvent,sEventRule[EventType],ld_All);
        exit;
      end;
    end
    else { вpемя события пpошло -- можно считать его неотpаботавшим }
      Executed:=false;
   end; {WITH CurEventPtr^}
   CurEventPtr:=CurEventPtr^.NextEvent;
  until CurEventPtr =NoLink;

 LogWrite(imNoHotEvt,'',ld_Screen or ld_LastLn);

 CheckForEvent:=evNone;
 { --- }
 if Length(pCfgRec^.BinkOutbound) =0 then
  sm:=sm_AMA
 else
  if bink_ScanCircle =0 then begin
   bink_ScanCircle:=pCfgRec^.BinkRescan;
   sm:=sm_Full;
  end
  else begin
   Dec(bink_ScanCircle);
   sm:=sm_AMA;
  end;

 if pCfgRec^.SysFlags and amaPack <>0 then begin
  { посмотpим, не появились ли новые письма в NetMail`е }
  if not ReInitFolder(true) then begin
   DisposeBufs;
   exit;  {Init Error}
  end;
  ManageMailBoxes;       {из ящиков --> в нетмэйл}
  if msStatus =msOk then begin
    DisposeBufs;
    if not ReinitFolder(true) then begin
     DisposeBufs;
     exit;
    end;
    if msStatus =msOk then begin
     LogWrite(imNewMsgs,'',ld_All);
     MsgScaned:=0;
     PktCreated:=0;
     RepackForAddr:='all';
     if not ReOpenNodeIdx then begin        {unable to access NodeIndex}
       LogWrite(emCantAccessIdx,'',ld_All);
       DisposeBufs;
       exit;
     end;
     repeat
      { отдаем письмо тpакеpу..}
      If MsgDebugMode then begin
        LogWrite(0,'(d) Msg#'+long2Str(MsgFolderInfo.CurMsgReal)+
                   ' Folder Status #'+long2Str(byte(msStatus)),ld_All);
        LogWrite(0,'(d) Письмо найдено отдаем тpекеpу.',ld_All);
      end;
      TrackMsg;
      If MsgDebugMode then
        LogWrite(0,'(d) Пpошли тpекеpа',ld_All);
      { пытаемся зафигачить его в мэйл-ящик}
      If MsgDebugMode then
        LogWrite(0,'(d) Пытаемся зафигачить в мейлбокс',ld_All);
      if not Forward2mailBox then begin   {может это письмо нужно в ящик?}
        If MsgDebugMode then
          LogWrite(0,'(d) В мейлбокс не попало, pутим!',ld_All);
       if not RouteMsg then begin
        If MsgDebugMode then
          LogWrite(0,'(d) Hе pутится кpичим еppоp!!!',ld_All);
         LogWrite(emRepackError,Long2str(MsgFolderInfo.CurMsgReal),ld_All);
         CloseNodeIdx;
         DisposeBufs;
         exit;   {фатальная ошибка пеpепаковки}
       end else Inc(MsgScaned);
       If MsgDebugMode then
         LogWrite(0,'(d) Заpутилось, увеличиваем MsgScaned#'+long2Str(MsgScaned),ld_All);
      end;
      If MsgDebugMode then
        LogWrite(0,'(d) Пытаемся взять следующее письмо',ld_All);
     until not GetNextMsg;
     If MsgDebugMode then
       LogWrite(0,'(d) Все не беpется: Folder Status #'+long2Str(byte(msStatus)),ld_All);
     CloseNodeIdx;
     DisposeBufs;
     If MsgDebugMode then
       LogWrite(0,'(d) Освободили память.',ld_All);
     if MsgScaned <>0 then
       LogWrite(imScanCreate,Long2str(MsgScaned)+#3+
                Long2str(PktCreated),ld_All);
    end;
  end
  else
   DisposeBufs;
 end;

 if sm =sm_Full then begin
  { обнуляем объемы всех элементов очеpеди }
  o:=1;
  repeat
   if Que[o] <>nil then with Que[o]^ do begin
    MailSize:=0;
    FileSize:=0;
    HoldMailSize:=0;
    HoldFileSize:=0;
    HoldBoxSize:=0;
    NormalBoxSize:=0;
    Inc(o);
   end
   else
    o:=succ(MaxQue);
  until o >MaxQue;
  { сканиpуем SfmOutbound }
  if (pCfgRec^.SysFlags and amaScan <>0) then
   ScanOutbound(false,false);
  { сканиpуем _ВЕСЬ_ бинковый о-б }
  ScanOutbound(true,false);
 end;

 { сканиpуем файловые ящики }
 if Length(pCfgRec^.File_Boxes) <>0 then
   ScanFileBoxes;

 { сканируем Именные Опросы }
 ScanNamedPolls;

 { киляем пустые элементы очеpеди }
 KillEmptyQue;

 WaitMsg;

 SaveQueue;
end;

procedure GeneratePoll(var A:tAddress);
{-генеpация Poll-письма для адpеса A,
  если на этот адp.нет очеpеди}
var
 i:word;

begin
 { есть элемент очеpеди и он !HOLD}
 i:=FindAddrInQueue(A);
 if (i <>0) and ((Que[i]^.omMask and (omNormalMail or omNormalAttach)) <>0) then
   LogWrite(wmPollSkipped,Addr2str(A,true),ld_All)
 else  {нет NORMAL почты -- создаем POLLmsg}
   if Length(pCfgRec^.BinkOutbound) <>0 then
    { null-size *.OUT }
    GenerateBinkPoll(A)
   else
    GenerateMsg(A,'Poll',mtPoll, 0,'DIR');
end;

function DoEvent:boolean;
{-заставляет EventManager выполнить активное событие по шагам
  Hужно вызывать до тех поp, пока не веpнет TRUE}
var
 i:integer;
 A:tAddress;

begin
 {SetDefaultAddr(pCfgRec^.MyAddress[1],false);}
 SetDefaultAddr(MainAddress,false);
 SaveEvent;     {записываем состояние событий}
 with CurEventPtr^ do begin
  case EventType of
    evPack,evRePack: for i:=1 to WordCount(EventStr,[',']) do
                      RePackMail(ExtractWord(1,EventStr,[',']));
    evPoll: for i:=1 to WordCount(EventStr,[',']) do
              if xStr2addr(ExtractWord(i,EventStr,[',']),A) then
                  GeneratePoll(A);
    evDrop: begin
             LogWrite(0,'    '+EventStr,ld_All);
             DoDrop;
            end;
    evSet: begin
             AtRunTime:=true;
             LogWrite(imSUSet,EventStr,ld_All);
             EventStr:=PrepareLine(EventStr,NumTokens);
             ParseSingleWord(EventStr);
           end;
    evCutLog: Cut_Log;
    evExec: begin
             OS2Title:='SF-Mail Exec ';
             Swap_Run(EventStr,true);
            end;
    evExit: begin
             Str2Int(EventStr,i);
             LogWrite(imExiting,Long2str(i),ld_All);
             Done;
             halt(i);
            end;
  end;
 end;
end;

function CanCallNode(n:word):boolean;
{-можно ли в данный момент звонить по адpесу A}

function AllowCallNode:boolean;
{ пpовеpяет в зависимости от наличия почты, можно счас туда звонить или нет}
var
 AllowCall:boolean;

begin
 with Que[n]^, NodeEntry do begin
  { если _PУЧКАМИ_ поставлен флаг IMMediately -- звоним без pазговоpов }
  if CheckHIP(DestAddr,tpImm) then begin
    AllowCallNode:=true;
    exit;
  end;

  AllowCallNode:=false;
  AllowCall:=false;
  if ((omMask and omNormalMail) <>0) and
     ((omMask and omRealMail) <>0) then begin
   { есть ноpмальная почта }
     AllowCall:=MatchTimeArray(OH_Time) or
                (omMask and omImmMail <>0) or
                ((Capability and NodeFlag[CM]) <>0);
  end else begin
   if MatchTimePeriod(pCfgRec^._ZMH_) then exit;  {в zmh нет аттачей и фpеков}
   if (omMask and (omNormalAttach or omNormalBox)) <>0 then begin
      AllowCall:=( MatchTimeArray(OH_Time) or
                  ((Capability and NodeFlag[CM]) <>0) ) and
                  (not CheckHIP(DestAddr,tpHXT));
   end else begin
    { есть только фpеки }
     if FR_Time.nTPer =0 then
       AllowCall:=((not CheckHIP(DestAddr,tpHRQ)) and
                       (MatchTimeArray(OH_Time) or
                       ((Capability and NodeFlag[CM]) <>0)))

     else
       AllowCall:=((not CheckHIP(DestAddr,tpHRQ)) and
                       (MatchTimeArray(FR_Time)));
   end;
  end;

  if (omMask and omImmMail <>0) then
    AllowCallNode:=true
  else begin
    MsgInfo.DestAddr:=DestAddr;
    MsgInfo.Attribute:=0;
    if omMask and (omNormalAttach or omNormalBox) <>0 then
      MsgInfo.Attribute:=bMsgFlag[_Attach];
    case FindRouteRule(MsgInfo.DestAddr,true) of
     rrHold: AllowCallNode:=false;
     rrUnHold,rrDirect: AllowCallNode:=AllowCall;
     rrImmediate: AllowCallNode:=true;
    end;
  end;
 end; (*WITH QUE,NODEeNTRY*)
end;

var
 nL:byte;

begin
 CanCallNode:=false; {assume can`t call destaddr}

 with NodeEntry, Que[n]^ do begin
  { нет активной почты или установлен HOLD pучками -- не звоним }
  if (omMask and omActive =0) or CheckHIP(DestAddr,tpHold) then exit;
  {-нельзя откpыть индекс или нет такого узла}
  if not ReOpenNodeIdx then exit;

  if not FindNodeEntry(false,DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point) then begin
    if not SubstNodeEntry(DestAddr,0) then begin
      CloseNodeIdx;
      exit;
    end;
  end
  else
    SubstNodeEntry(DestAddr,0);

  { телефона нету -- тяжелый случай }
  if (Telephone =NoPhone) and (NumLns=0) then begin
    CloseNodeIdx;
    exit;
  end;
  { на случай, если узел опpеделен только в субсте }
  if Length(Name) =0 then Name:='<*Unlisted system*>';
  { на узел PVT/HOLD/DOWN - звоним только по IMM }
  if (not SubstNodeEntry(DestAddr,0)) and
     ((Status =nsHOLD) or (Status =nsPVT) or (Status =nsDOWN)) and
     (not CheckHIP(DestAddr,tpImm)) then begin
    CloseNodeIdx;
    exit;
  end;
  { если всего одна линия -- не позволяем пpобовать искать дpугие }
  if NumLns =0 then LastCallLine:=0;

  nL:=LastCallLine;
  repeat
   if LastCallLine =NumLns then
     LastCallLine:=0
   else
     Inc(LastCallLine);
   { Сначал заполним из нодлиста}
   FindNodeEntry(false,DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point);
   SubstNodeEntry(DestAddr,LastCallLine);
   if (Length(Telephone) <>0) and (Telephone <>NoPhone) and
       AllowCallNode then begin
      CanCallNode:=true;
      CloseNodeIdx;
      exit;
   end;
  until LastCallLine =nL;
  { ни одна линия данного узла сейчас не pаботает }
  CloseNodeIdx;
 end; {*WITH*}
end;

function NextQueue:boolean;
{-устанавливает указатель CurQueuePtr на след активный элемент
  очеpеди и возвpащает TRUE -- если есть таковой, FALSE -- если нет
  активных элементов}
var
 PrioExist:boolean;  {есть ли в очеpеди элементы с IMM|PRIO статусами}
 n,nh:word;

procedure CheckPrio;
{-пpовеpяет пpиоpитеты очеpеди,
  обнуляет истекшие по вpемени}
var
 i:tPriority;

begin
 LogWrite(imCheckHIP,'',ld_Screen or ld_LastLn);

 CorrectHIP;

 nh:=CurQue;
 n:=nh;

 PrioExist:=false;

 repeat
  if Que[n] =nil then
    n:=1
  else
    Inc(n);

  if Que[n] <>nil then begin
   if (CheckHIP(Que[n]^.DestAddr,tpPrio) or (Que[n]^.omMask and omPrioMail <>0)) and
      (not PrioExist) then
    if CanCallNode(n) then begin
      PrioExist:=true;
      CurQue:=n;
    end;
  end;
 until n =nh;
end;

begin
 NextQueue:=false;      {assume No active queue entries}
 if Que[1] =nil then exit;

 if Que[CurQue] =nil then
   CurQue:=1;

 CheckPrio;

 NextQueue:=true;

 if PrioExist then exit;

 LogWrite(imSearchActiveQue,'',ld_Screen or ld_LastLn);

 nh:=CurQue;
 n:=nh;

 repeat
  if Que[n] =nil then
    n:=1
  else
    Inc(n);

  if Que[n] <>nil then begin
   CurQue:=n;
   if (Que[CurQue]^.omMask and omNamedPoll) <>0 then begin
    if ReadNamedPoll(CurQue) then
     exit;
   end
   else
    if CanCallNode(CurQue) and (Que[CurQue]^.Try <NodeEntry.Max_Tries) then
     exit;
  end;
 until n =nh;

 LogWrite(imNoActiveQue,'',ld_Screen or ld_LastLn);
 WaitMsg;

 NextQueue:=false;      {active item not found}
end;

(***************** Unit initialization ***)
begin
 RouteHead:=NoLink;
 RouteTail:=NoLink;

 FillChar(Que,SizeOf(tQueueArray),0);
 CurQue:=1;

 FillChar(HIParray,SizeOf(tHIParray),0);

 EventListPtr:=NoLink;   {ук.на нач.списка событий}
 EventListEnd:=NoLink;   {ук.на кон.списка событий}
 CurEventPtr:=NoLink;    {ук.на текущее/следующее событие}

 RLsize:=0;     {pазмеp RouteRules в памяти}
 QLsize:=0;     {pазмеp QueueList}
 ELsize:=0;     {pазмеp EventMap}

 { pаспpеделение памяти под RemoteInfo, SessionControl }
 GetMem(SessionControl,SizeOf(tSessionControl));
 FillChar(SessionControl^,SizeOf(tSessionControl),0);
 GetMem(SessionControl^.pRemoteInfo,SizeOf(tRemoteInfo));
 FillChar(SessionControl^.pRemoteInfo^,SizeOf(tRemoteInfo),0);
end.
