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

{--- ������� ��p�p�⨧�樨 � �p������� ᮡ��ﬨ ---}
var
 MsgScaned:word;        {᪮�쪮 �p�᪠��p����� ��ᥬ}

{*** PROCEDURES/FUNCTIONS ***}

function DoEvent:boolean;
{-���⠢��� EventManager �믮����� ��⨢��� ᮡ�⨥ �� 蠣��
  H㦭� ��뢠�� �� �� ��p, ���� �� ��p��� TRUE}

function RePackMail(forAddr:tStr25):boolean;
{-��p�������� ����� ��� ��p�� Address, ��� �᫨
  Address.Zone=AnyNum, � �ᥩ �����
  Address.Zone=InvAddr, � ����� �� ��p��,
   㪠���� � SessionControl^.pRemoteInfo.RemoteAddr}

function CheckForEvent:tEventType;
{-�p���p��, �� ��砫��� �� ᮡ�⨥ � �᫨ ��砫���,
  ����p�頥� ��� ⨯, � CurEventPtr ���. �� �� ᮡ�⨥}

procedure GeneratePoll(var A:tAddress);
{-����p��� Poll-���쬠 ��� ��p�� A,
  �᫨ �� ��� ��p.��� ��p���}

function NextQueue:boolean;
{-��⠭�������� 㪠��⥫� CurQueuePtr �� ᫥� ��⨢�� �������
  ��p��� � ����p�頥� TRUE -- �᫨ ���� ⠪����, FALSE -- �᫨ ���
  ��⨢��� �������⮢}

(*** Service routines ***)

function vInBestForm(v:longint):string;
{-����p�頥� p����p � ������襬 �p���}
function vInShortBest(v:longint):string;

function CanCallNode(n:word):boolean;
{-����� �� � ����� ������ ������� �� ��p��� A;
  Immediate == true => �� �p���p塞 �p��� p����� A}

function FindRouteRule(var _destA:tAddress; SubRule:boolean):tRouteRule;
{-�饬 ᮮ⢥�����饥 �p����� ��p�p�⨧�樨,
  ���p���� �� 㧫� �����祭�� � �������
 ����������:
                dest=��p�� �����祭��
                tRouteRule=��� p����
                RouteRecPtr 㪠�뢠�� �� �������� �p����� � ���}

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
{-����p�頥� p����p � ������襬 �p���}
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
{-ᮧ���� ����� �� ��p�� RDestAddr, �᫨ ��� �� ��� � ��p���,
  �������� � ���� ���쬮 � ����p�� MsgFolderInfo.CurMsgReal,
  �PktFlavour ����� ���� [rrDirect,rrHold,rrCrash,rrDefault]�
  �������� � 䠩� ᮯp��������� (.mfo/.mfh/.mfc) ���p���� � ���쬥

��� �����: PktFlavour -- ⨯ �����}

var
 MyAddr:tAddress;       {�� �⮣� ��p�� �㤥� �����}
 pExt:ExtStr;           {p���p���� �����}
 i:word;
  pPath:PathStr;        {���� � ������ � ���}
  cExt:ExtStr;          {p���p���� ᮯp�����⥫쭮�� 䠩��}
  cMask:word;           {��᪠ �����}
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
        { �� ������ ����� }
      if ((pCfgRec^.SysFlags and mscAdvRoute) <>0) and
         (Pos('DIR',MsgInfo.Flags) <>0) then
         {�᫨ advanced routing � �� freq � �.�.}
        PktFlavour:=rrDefault {�㤠 ����� ��p�⨬ �� 㬮�砭��}
      else
        PktFlavour:=rrHold;
      exit;
    end;
  end else
   SubstNodeEntry(RDestAddr,0);

 { ������ ���-���� }

  if (NodeEntry.Telephone =NoPhone) or
     (((NodeEntry.Status =nsHOLD) or   {㧥� HOLD/DOWN/PVT ��� ��� ⥫�䮭�}
     (NodeEntry.Status =nsPVT) or
     (NodeEntry.Status =nsDOWN)) and
     (not SubstNodeEntry(RDestAddr,0)))
     then begin

    if Point <>0 then begin
      if MsgForUs(Zone,Net,Node,0) then begin {�᫨ ��� �����}
        PktFlavour:=rrHold;
        exit;
      end;
    end;

    if (pCfgRec^.SysFlags and mscAdvRoute) <>0 then
      {�᫨ advanced routing}
       PktFlavour:=rrDefault {�㤠 ����� ��p�⨬ �� 㬮�砭��}
    else
       PktFlavour:=rrHold;   {��� ����ᨬ �� 宫�}

  end else
    _done:=true;  {-��室�� �� 横��}

 end; {*WITH*}
end;

begin
 AddMsg2Queue:=false;   {assume Add error}
 _done:=false;        {�p.��p��.横��}
 move(RDestAddr,MyAddr,SizeOf(tAddress));
 MatchAKA(MyAddr);
  repeat
   case PktFlavour of

    rrHold: _done:=true;      {�� ��室 �� 横��}

    rrDefault: with RDestAddr do begin
                if MyAddr.Point<>0 then begin
                  { � ᠬ � ������ �� ����� p�⨬ �� ���� }
                  Move(MyAddr,RDestAddr,SizeOf(tAddress));
                  Point:=0;
                  PktFlavour:=rrDirect;
                end else begin
                  if (Point <>0) and MsgForUs(Zone,Net,Node,0) then begin
                    { ��� ����� -- �㤥� hold }
                    PktFlavour:=rrHold;
                    { �� ��� ����� }
                  end else begin
                    Point:=0;
                    if FindNodeEntry(true,Zone,Net,Node,Point) then begin
                       { �᫨ ���� ⠪�� ���� ��� ���� �⮣� ����� }
                       { ����� ���쬮 �� ��� 堡� }
                       if MsgForUs(Zone,Net,NodeIdxRec.RoutNode,Point) then begin
                       { � ����뢠���� ��� ��� �� ��p�p娨 }
                       { �� �� ᥡ� �� p����;) }
                         PktFlavour:=rrDirect;
                       end else begin
                         Node:=NodeIdxRec.RoutNode;
                         PktFlavour:=rrDirect;
                       end;
                    end else begin
                      { ⠪�� ���� ����? H��� �� Orphan, �� �����}
                      DoDirect;
                      if (PktFlavour=rrDefault) or (PktFlavour=rrHold) then begin
                      { �p� �������, � ���� ���, � Advanced Routing;( }
                      { ��⨬ �� ��� ;-E }
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

 { ����� ������ ���� p���p���� ᮯp�����⥫쭮�� � pkt 䠩��? }
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
  { �᫨ �४���� ���쬮 ������, � ��� �ॢ�頥��� � ���筮� }
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
  else  { �� -- ���� ���쬮 }
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

 { �饬 � ��p��� ����� �� ��p. DestAddr }
 i:=FindAddrInQueue(RDestAddr);
 if i =0 then begin
  If MsgDebugMode then
    LogWrite(0,'(d) ��p��� �� ������ � ��p���',ld_All);
  { ����� �� ��� ��p�� ��� => ᮧ���� ���� ����� � ������� ��p��� }
  if not CreatePkt(RDestAddr, pPath, pExt, false) then exit;
  If MsgDebugMode then
    LogWrite(0,'(d) ������� �����',ld_All);
  Inc(PktCreated);
  FillChar(QueTmp,SizeOf(tQueueRec),0);
  if (cMask and omHoldMask) <>0 then
    QueTmp.HoldMailSize:=60
  else
    if (cMask and omNormalMask) <>0 then
      QueTmp.MailSize:=60;
  Move(RDestAddr,QueTmp.DestAddr,SizeOf(tAddress));
  i:=AddQueue;  { ������塞 ������� � ��p���, I 㪠��� �� ����!}
  if i =0 then exit;
  If MsgDebugMode then
    LogWrite(0,'(d) ������� ������� ��p���',ld_All);
 end
 else begin
  If MsgDebugMode then
    LogWrite(0,'(d) ��p��� ������ � ��p���',ld_All);
  { ��� ��p�� ���� � ��p��� }
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
   LogWrite(0,'(d) �������� ���쬮 � �����',ld_All);

 if (cMask and omNormalMask) <>0 then
   Inc(Que[i]^.MailSize,l);
 if (cMask and omHoldMask) <>0 then
   Inc(Que[i]^.HoldMailSize,l);

 { FREQ: xxxxxxxx.REQ � xxxxxxxx.MF? (if not TRANSIT) }
 if (cMask and (omFReq or omHoldFReq) <>0) and
    (CompWordStruct(RDestAddr,MsgInfo.DestAddr,SizeOf(tAddress)) =Equal)
 then begin
  if (cMask and omHoldFReq) <>0 then
    assign(f,pPath+RehXt)    {Hold FReq xtension}
  else
    assign(f,pPath+ReqXt);   {Normal FReq xtension}
  append(f);                            {��� ������� _�_�_�_}
  if IoResult <>0 then rewrite(f);                      {ᮧ����}
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
  close(f);     {���p뫨 xxxxxxxx.REQ}
  mn:=IoResult;
 end;

  If MsgDebugMode then
    LogWrite(0,'(d) ���⠢�塞 ᮯp����������',ld_All);

  { ���ᨬ ���p���� � ᮯp�����⥫�� 䠩� xxxxxxxx.MF?}
  assign(SessionControl^.fSntLog,pPath+cExt);
  reset(SessionControl^.fSntLog);
  if IoResult <>0 then
    rewrite(SessionControl^.fSntLog)  {�� ��諨 -- ᮧ����}
  else
    Seek(SessionControl^.fSntLog,FileSize(SessionControl^.fSntLog));     {��諨 -- ���� � �����}

 with MsgFolderInfo, MsgInfo, SessionControl^ do begin
   if (Attribute and bMsgFlag[_Attach]) <>0 then begin

    DT.Year:=WordCount(MsgHeader.Subj,[' ']);      {�-�� 䠩���}
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

      { ����塞 ��ꥬ 䠩��� }
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

    { ��� ��᫥����� 䠩�� � �㡦� }
    SntCurFile.MsgAttr:=Attribute; {��p����� ���쬠}
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
   else begin  {�p��� ���쬮 ��� freq}
     FillChar(SntCurFile,SizeOf(tTRxLog),0);
     SntCurFile.FileType:=ftMsg;
     SntCurFile.MsgNo:=CurMsgReal;
     SntCurFile.MsgAttr:=Attribute;
     SntCurFile.Name:=MsgHeader.Subj;
     write(fSntLog,SntCurFile);
   end;
   { ���p뢠�� ᮯp�����⥫�� 䠩� xxxxxxxx.MF? }
   if IOResult<>0 then {clear};
   close(SessionControl^.fSntLog);
   if IOResult<>0 then {clear};
 end; {*WITH*}
  If MsgDebugMode then
    LogWrite(0,'(d) �����稫� �ᯥ譮, ��室��',ld_All);

 AddMsg2Queue:=true;    {msg Added ok}
end;

function FindRouteRule(var _destA:tAddress; SubRule:boolean):tRouteRule;
{-�饬 ᮮ⢥�����饥 �p����� ��p�p�⨧�樨,
  ���p���� �� 㧫� �����祭�� � �������
 ����������:
                dest=��p�� �����祭��
                tRouteRule=��� p����
                RouteRecPtr 㪠�뢠�� �� �������� �p����� � ���}
var
 p:pRouteRec;

function FindAddrInRule:boolean;
{-���� ᮢ�����饣� � MsgInfo.DestAddr ��p��
  � ᯨ᪥ ��p�ᮢ �p����� p�⨭�� �� Route}
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
{-���室�� �� �p����� � �����: Files/Mail}
begin
 with p^, MsgInfo do begin
  { HOLD, CRASH -- ��� ���� ��ᥬ, ���p� �������� p�⨭��
    MailTo      -- ⮫쪮 ��� ����H�� ��ᥬ
    FileTo      -- ⮫쪮 ��� Attach`��}

  if SubRule then
    { �� �饬 �� �p����� ��p�p�⨧�樨, � �p����� ��� ��室��� ������� }
    MatchRule:=(Flavour in [rrHold,rrUnhold,rrImmediate])
  else
   if Attribute and bMsgFlag[_Attach] <>0 then
     { �� ���� ⮫쪮 Files-to ������� }
     MatchRule:=(Flavour in [rrFileTo,rrDirectFile])
   else
     { �� ���쬠 ��������: Direct, Route-from � Route-to }
     MatchRule:=Flavour in [rrDirect,rrMailTo,rrMailFrom];
 end;
end;

begin {-FindRouteRule-}
 if not SubRule then with MsgInfo.DestAddr do begin
   Move(MsgInfo.DestAddr,_destA,SizeOf(tAddress));
   if not (pCfgRec^.SysFlags and mscAdvRoute <>0) and
      MsgForUs(Zone,Net,Node,0) then begin
     { ᢮�� ����⮢ ���㤠 ���७ �� ��⨬ }
     FindRouteRule:=rrDirect;
     exit;
   end;
   FindRouteRule:=rrDefault;      {-assume Target not found}
 end
 else
   FindRouteRule:=rrDirect;

 p:=RouteHead;

 while p <>NoLink do with p^ do begin
  { ��� ���祩 -- ⮫쪮 rrFileTo ��� ��⠫��� -- �� �p��� rrFileTo }
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
{-��p�p�⨧��� ���쬠 �� MsgInfo,
  ���������� � ᮮ⢥�����騩 �����}
var
 TargetAddr:tAddress;   {-��p�� �����祭�� �����}
 mF:tRouteRule;

begin
 RouteMsg:=true;  {assume Route Ok}

 with MsgInfo do begin
  {-�᫨ ���� �������⭠, �㤥� �� ��襣� �������� AkA-}
  if DestAddr.Zone =0 then DestAddr.Zone:=MainAddress.Zone;

  {-���쬮 ����祭�, ��� SENT ��� RECEIVED}
  if ((Attribute and (bMsgFlag[_Sent] or bMsgFlag[_Recvd])) <>0) or
  {-��� ���쬮 ��� ��襣� ��p��}
     MsgForUs(DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point) then
    exit;

  {-���४��㥬 �ਢ� �㪨:  FReq.Subj==NUL => Subj:='files' }
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

  {-宫����� ���쬮}
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

  {-DIRect � FReq ����� p����}
  { � ����� H����� ������ � ������� ������ �� Sf-Mail Robot }
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

  {-p�⨭� ��� ������ ��ᥬ � ���祩}
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
{-��p�������� ����� ��� ��p�� Address, ��� �᫨
  Address.Zone=AnyNum, � �ᥩ �����
  Address.Zone=InvAddr, � ����� �� ��p��,
   㪠���� � SessionControl^.pRemoteInfo.RemoteAddr}
var
 o:integer;

begin
 MsgScaned:=0;
 PktCreated:=0;

 RePackMail:=false;  {assume Repack error}

 if not ExpandAddrMacro(forAddr, dZ,dN,dF,dP, false) then
  SplitAddr(forAddr, dZ,dN,dF,dP, false);
 { ps � ���� Zone ����砥� �ਬ�୮ `PostSession' (�ਬ.����) }
 if dF <>'ps' then begin
   LogWrite(imRepackFor,forAddr,ld_All);
   if dZ ='*' then with pCfgRec^ do begin
     { �᫨ �� Repack for *All*, � 㡨���� p����-ᥬ��p� � Crash Recovery}
     CheckRepackSem(true);
     If SysFlags and mscCrashRecovery <>0 then
       SysFlags:=SysFlags and not mscCrashRecovery;
   end;
   DelQueue(forAddr);
 end
 else
   LogWrite(imPSmonitoring,'',ld_All);

 if (pCfgRec^.SysFlags and amaPack) <>0 then begin
  { �᫨ ����祭 ����p����� ����p �뫠..}
  ReInitFolder(true);
  case msStatus of
   msInitError,msReadError: begin                { error init MsgXs }
                  LogWrite(emCantAccessMail,'',ld_All);
                  DisposeBufs;
                  exit;
                end;
   msFolderEmpty: begin
                    DelQueue('all');  {�뫠 ��� ���� -- 㤠���� ��� ��p���}
                    SaveQueue;
                  end;
  end;
 end (*IF INTERNAL PACKER*)
 else
  GetMem(MsgLnBuf,MsgTrxSiz); { alloc read buffer}

 { ��᪠ ��p�ᮢ, ��� ���.�㤥� ��p��������� ����}
 RepackForAddr:=forAddr;

 ManageMailBoxes;       {�� �騪�� -- � NetMail}

 DisposeBufs;

 if (pCfgRec^.SysFlags and amaPack <>0) and (msStatus =msOk) then begin
  { �᫨ ����祭 ����p����� ����p �뫠..}
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
    { �⤠�� ���쬮 �p���p�..}
    TrackMsg;
    { ��⠥��� ��䨣���� ��� � ����-�騪}
    if not Forward2MailBox then
     if not RouteMsg then BEGIN
       LogWrite(emRepackError,Long2str(MsgFolderInfo.CurMsgReal),ld_All);
       CloseNodeIdx;
       DisposeBufs;
       exit;   {�⠫쭠� �訡�� ��p��������}
     END
     else Inc(MsgScaned);
   until not GetNextMsg;
  CloseNodeIdx;
  DisposeBufs;
  EraseSemaphore(pCfgRec^.Flags_Dir+'binkbsy.sf');
 end; (*IF INTERNAL PACKER*)

 RePackMail:=true;

 { ᪠��p㥬 ᮤ�p����� 䠩����� �騪�� }
 if Length(pCfgRec^.File_Boxes) <>0 then ScanFileBoxes;

 { ᪠��� ������� ��⡠㭤 }
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

 { ���塞 ����� �������� ��p��� }
 KillEmptyQue;

 if (CurQue >MaxQue) or (Que[CurQue] =nil) then CurQue:=1;

 SaveQueue;
end;

function CheckForEvent:tEventType;
{-�p���p��, �� ��砫��� �� ᮡ�⨥ � �᫨ ��砫���,
  ����p�頥� ��� ⨯, � CurEventPtr ���. �� �� ᮡ�⨥}

type
 tScanMode=(sm_AMA,sm_Bink,sm_Full);

var
 f:text;
 o:longint;
 sm:tScanMode;

begin
 CheckForEvent:=evNone;

 if not MatchEvRoFtime(true) then MapRoute;   {䠩� p�⨭�� �������?}
 if not MatchEvRoFtime(false) then MapEvents; {䠩� ����⮢ �������?}
 MatchSubstFtime;                       {䠩� ����⠭���� �������?}
 if MatchCfgFtime(false) then           {�᭮���� ���䨣 �������?}
   MatchPwdFtime;
 { ����稥 repack-ᥬ��p�� }
 CheckRepackSem(false);
 { ����稥 user-defined ᥬ��p�� }
 CheckUserSem;

 CurEventPtr:=EventListPtr;

 LogWrite(imLook4hotEvt,'',ld_Screen or ld_LastLn);

 if CurEventPtr <>NoLink then
  repeat
   with CurEventPtr^ do begin
    CheckForEvent:=EventType;
    { �᫨ ᮡ�⨥ �� �� �뫮 �믮����� � �p��� ��� �� �p�諮 }
    if MatchTimePeriod(TimePeriod) then begin
      if TimePeriod.rtBegin >CurTime then
        {��砫� ��ਮ�� >���� => ���室 �१ �������}
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
    else { �p��� ᮡ��� �p�諮 -- ����� ����� ��� ����p���⠢訬 }
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
  { ��ᬮ�p��, �� ������ �� ���� ���쬠 � NetMail`� }
  if not ReInitFolder(true) then begin
   DisposeBufs;
   exit;  {Init Error}
  end;
  ManageMailBoxes;       {�� �騪�� --> � ������}
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
      { �⤠�� ���쬮 �p���p�..}
      If MsgDebugMode then begin
        LogWrite(0,'(d) Msg#'+long2Str(MsgFolderInfo.CurMsgReal)+
                   ' Folder Status #'+long2Str(byte(msStatus)),ld_All);
        LogWrite(0,'(d) ���쬮 ������� �⤠�� �p���p�.',ld_All);
      end;
      TrackMsg;
      If MsgDebugMode then
        LogWrite(0,'(d) �p�諨 �p���p�',ld_All);
      { ��⠥��� ��䨣���� ��� � ����-�騪}
      If MsgDebugMode then
        LogWrite(0,'(d) ��⠥��� ��䨣���� � ��������',ld_All);
      if not Forward2mailBox then begin   {����� �� ���쬮 �㦭� � �騪?}
        If MsgDebugMode then
          LogWrite(0,'(d) � �������� �� ������, p�⨬!',ld_All);
       if not RouteMsg then begin
        If MsgDebugMode then
          LogWrite(0,'(d) H� p����� �p�稬 �pp�p!!!',ld_All);
         LogWrite(emRepackError,Long2str(MsgFolderInfo.CurMsgReal),ld_All);
         CloseNodeIdx;
         DisposeBufs;
         exit;   {�⠫쭠� �訡�� ��p��������}
       end else Inc(MsgScaned);
       If MsgDebugMode then
         LogWrite(0,'(d) ��p�⨫���, 㢥��稢��� MsgScaned#'+long2Str(MsgScaned),ld_All);
      end;
      If MsgDebugMode then
        LogWrite(0,'(d) ��⠥��� ����� ᫥���饥 ���쬮',ld_All);
     until not GetNextMsg;
     If MsgDebugMode then
       LogWrite(0,'(d) �� �� ��p����: Folder Status #'+long2Str(byte(msStatus)),ld_All);
     CloseNodeIdx;
     DisposeBufs;
     If MsgDebugMode then
       LogWrite(0,'(d) �᢮������ ������.',ld_All);
     if MsgScaned <>0 then
       LogWrite(imScanCreate,Long2str(MsgScaned)+#3+
                Long2str(PktCreated),ld_All);
    end;
  end
  else
   DisposeBufs;
 end;

 if sm =sm_Full then begin
  { ����塞 ��ꥬ� ��� ������⮢ ��p��� }
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
  { ᪠��p㥬 SfmOutbound }
  if (pCfgRec^.SysFlags and amaScan <>0) then
   ScanOutbound(false,false);
  { ᪠��p㥬 _����_ ������� �-� }
  ScanOutbound(true,false);
 end;

 { ᪠��p㥬 䠩���� �騪� }
 if Length(pCfgRec^.File_Boxes) <>0 then
   ScanFileBoxes;

 { ᪠���㥬 ������ ����� }
 ScanNamedPolls;

 { ���塞 ����� �������� ��p��� }
 KillEmptyQue;

 WaitMsg;

 SaveQueue;
end;

procedure GeneratePoll(var A:tAddress);
{-����p��� Poll-���쬠 ��� ��p�� A,
  �᫨ �� ��� ��p.��� ��p���}
var
 i:word;

begin
 { ���� ������� ��p��� � �� !HOLD}
 i:=FindAddrInQueue(A);
 if (i <>0) and ((Que[i]^.omMask and (omNormalMail or omNormalAttach)) <>0) then
   LogWrite(wmPollSkipped,Addr2str(A,true),ld_All)
 else  {��� NORMAL ����� -- ᮧ���� POLLmsg}
   if Length(pCfgRec^.BinkOutbound) <>0 then
    { null-size *.OUT }
    GenerateBinkPoll(A)
   else
    GenerateMsg(A,'Poll',mtPoll, 0,'DIR');
end;

function DoEvent:boolean;
{-���⠢��� EventManager �믮����� ��⨢��� ᮡ�⨥ �� 蠣��
  H㦭� ��뢠�� �� �� ��p, ���� �� ��p��� TRUE}
var
 i:integer;
 A:tAddress;

begin
 {SetDefaultAddr(pCfgRec^.MyAddress[1],false);}
 SetDefaultAddr(MainAddress,false);
 SaveEvent;     {�����뢠�� ���ﭨ� ᮡ�⨩}
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
{-����� �� � ����� ������ ������� �� ��p��� A}

function AllowCallNode:boolean;
{ �p���p�� � ����ᨬ��� �� ������ �����, ����� ��� �㤠 ������� ��� ���}
var
 AllowCall:boolean;

begin
 with Que[n]^, NodeEntry do begin
  { �᫨ _P������_ ���⠢��� 䫠� IMMediately -- ������ ��� p������p�� }
  if CheckHIP(DestAddr,tpImm) then begin
    AllowCallNode:=true;
    exit;
  end;

  AllowCallNode:=false;
  AllowCall:=false;
  if ((omMask and omNormalMail) <>0) and
     ((omMask and omRealMail) <>0) then begin
   { ���� ��p���쭠� ���� }
     AllowCall:=MatchTimeArray(OH_Time) or
                (omMask and omImmMail <>0) or
                ((Capability and NodeFlag[CM]) <>0);
  end else begin
   if MatchTimePeriod(pCfgRec^._ZMH_) then exit;  {� zmh ��� ���祩 � �p����}
   if (omMask and (omNormalAttach or omNormalBox)) <>0 then begin
      AllowCall:=( MatchTimeArray(OH_Time) or
                  ((Capability and NodeFlag[CM]) <>0) ) and
                  (not CheckHIP(DestAddr,tpHXT));
   end else begin
    { ���� ⮫쪮 �p��� }
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
  { ��� ��⨢��� ����� ��� ��⠭����� HOLD p�窠�� -- �� ������ }
  if (omMask and omActive =0) or CheckHIP(DestAddr,tpHold) then exit;
  {-����� ��p��� ������ ��� ��� ⠪��� 㧫�}
  if not ReOpenNodeIdx then exit;

  if not FindNodeEntry(false,DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point) then begin
    if not SubstNodeEntry(DestAddr,0) then begin
      CloseNodeIdx;
      exit;
    end;
  end
  else
    SubstNodeEntry(DestAddr,0);

  { ⥫�䮭� ���� -- �殮�� ��砩 }
  if (Telephone =NoPhone) and (NumLns=0) then begin
    CloseNodeIdx;
    exit;
  end;
  { �� ��砩, �᫨ 㧥� ��p������ ⮫쪮 � ���� }
  if Length(Name) =0 then Name:='<*Unlisted system*>';
  { �� 㧥� PVT/HOLD/DOWN - ������ ⮫쪮 �� IMM }
  if (not SubstNodeEntry(DestAddr,0)) and
     ((Status =nsHOLD) or (Status =nsPVT) or (Status =nsDOWN)) and
     (not CheckHIP(DestAddr,tpImm)) then begin
    CloseNodeIdx;
    exit;
  end;
  { �᫨ �ᥣ� ���� ����� -- �� ������塞 �p������� �᪠�� �p㣨� }
  if NumLns =0 then LastCallLine:=0;

  nL:=LastCallLine;
  repeat
   if LastCallLine =NumLns then
     LastCallLine:=0
   else
     Inc(LastCallLine);
   { ���砫 �������� �� �������}
   FindNodeEntry(false,DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point);
   SubstNodeEntry(DestAddr,LastCallLine);
   if (Length(Telephone) <>0) and (Telephone <>NoPhone) and
       AllowCallNode then begin
      CanCallNode:=true;
      CloseNodeIdx;
      exit;
   end;
  until LastCallLine =nL;
  { �� ���� ����� ������� 㧫� ᥩ�� �� p���⠥� }
  CloseNodeIdx;
 end; {*WITH*}
end;

function NextQueue:boolean;
{-��⠭�������� 㪠��⥫� CurQueuePtr �� ᫥� ��⨢�� �������
  ��p��� � ����p�頥� TRUE -- �᫨ ���� ⠪����, FALSE -- �᫨ ���
  ��⨢��� ������⮢}
var
 PrioExist:boolean;  {���� �� � ��p��� �������� � IMM|PRIO ����ᠬ�}
 n,nh:word;

procedure CheckPrio;
{-�p���p�� �p��p���� ��p���,
  ������ ��⥪訥 �� �p�����}
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

 EventListPtr:=NoLink;   {�.�� ���.ᯨ᪠ ᮡ�⨩}
 EventListEnd:=NoLink;   {�.�� ���.ᯨ᪠ ᮡ�⨩}
 CurEventPtr:=NoLink;    {�.�� ⥪�饥/᫥���饥 ᮡ�⨥}

 RLsize:=0;     {p����p RouteRules � �����}
 QLsize:=0;     {p����p QueueList}
 ELsize:=0;     {p����p EventMap}

 { p��p�������� ����� ��� RemoteInfo, SessionControl }
 GetMem(SessionControl,SizeOf(tSessionControl));
 FillChar(SessionControl^,SizeOf(tSessionControl),0);
 GetMem(SessionControl^.pRemoteInfo,SizeOf(tRemoteInfo));
 FillChar(SessionControl^.pRemoteInfo^,SizeOf(tRemoteInfo),0);
end.
