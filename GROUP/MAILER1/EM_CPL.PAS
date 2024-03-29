(* Event/Routing file compiler *)

{$X+,I-,O+,F+,V-}

{$I SfDefine.inc}

UNIT EM_Cpl;

INTERFACE

uses
 Dos,
 Config,
 MsgXs,
 EmStruct;

(*function InAddrList(A:tAddress; aList:PathStr):boolean;*)
{-�������� �� A ��� ��᪨ � aList, �����⨬� � ���.aList
  ������ @ListFilename}

procedure Check4Lamps;
{ �������� �����窨 NA NF Mail }

function MatchEvRoFtime(routing:boolean):boolean;
{-ᮢ������ �� ���� 䠩�� ����⮢/p�⨭��
  � ��� ��� ��᫥���� �������樨 EventFtime/RouteFtime)?
  �᫨ ��� -- ��୥� false}

function MatchCfgFtime(Force_Reread:boolean):boolean;
{-�p���p�� ���� 䠩�� �᭮����� ���䨣�
  ��p��� TRUE, �᫨ ���䨣 �� �� ��p��⠭}

procedure Squeze_Que(n:word);
procedure UnSqueze_Que(n:word);

procedure KillEmptyQue;
{-���塞 ����� �������� ��p���}

procedure AddHIP;
{-�������� HIP-䫠�� (�� HIPtmp)}

function AddQueue:word;
{-�������� ������� � ��p���}

procedure DelQueue(A:tStr25);
{-㤠��� ������� ��p��� ��� ��᪨ ��p�ᮢ A}

procedure CorrectHIP;
{-���४�஢�� HIP-䫠��� � ��⮬ ⥪�饣� �६���}

function CheckHIP(var Addr:tAddress; tp:tPriority):boolean;
{-��୥� TRUE, �᫨ �६� ��� tp �� �� ��諮}

function FindHIP4addr(var Addr:tAddress):word;
{-����� � HIParray ��� 0}

function FindAddrInQueue(var DestAddr:tAddress):word;
{-�饬 � ��p��� ����� �� ��p�� DestAddr}

function MapEvents:boolean;
{-�⠥� 䠩� <EventList> -- ���ᠭ�� ᮡ�⨩ � ��⠢��� ��p�� ᮡ�⨩}

function MapRoute:boolean;
{-�⠥� 䠩� <RoutingList> -- ���ᠭ�� p�⨭�� � ��⠢��� ��p�� p�⨭��}

procedure SaveQueue;
{-������ ��p���. ��뢠���� �p� ����p襭��}

procedure SaveEvent;
{-������ ��p�� ᮡ�⨩. ��뢠���� �p� ����p襭��}

procedure SaveRoute;
{-������ �p���� ��p�p�⨧�樨. ��뢠���� �p� ����p襭��}

procedure ParseEventStr;
{-�p���⠢������ ��p��� ᮡ��� ��� �ᯮ�짮�����}

function InitEventMan:boolean;
{-���樠������ �����}

function CloseEventMan:boolean;
{-����p襭�� �����,
  ������ ROUTE.$^v, EVENT.$^v, QUEUE.$^v �� ���,
  �᢮�������� �����.
 !!! H��������� ������� ����� �������H��� �������}

procedure ErasePacket(A:tAddress; KillRobotMsgs:boolean);
{-㤠��� ��� 䠩�� � ��⠫��� ��� ��p�� A;
  㤠����� ��������:  *.mf?
                      *.re?
                      *.pk?
                      *.bsy
  �.�. ����� 䠩� � ��⠫��� ��� ��p�� A

 �����: ��������� ᮮ�.���� ��ᥬ � MsgFolderMap}

procedure EraseQueue(i:word; KillRobotMsgs:boolean);
{-㤠��� ������ � ��⠫��� ��� i-����� ������� ��p���}

procedure DoDrop;
{-��p���⪠ ᮡ��� evDrop}

procedure CheckRepackSem(onlyKill:boolean);
{ <Flags>\REPACK.FLG\zznnnnff.pp }
{ <Flags>\<Repack_Flag> }
{ ��뢠���� � onlyKill �� RepackMail(All) ��� 㡨����
  ᥬ��p�� ��p�������� }

function ReadNamedPoll(n:word):boolean;
{-����뢠�� � NodeEntry ���ଠ�� � NamedPoll ��� Que[n]^.DestAddr}

function AddrTo32(A:tAddress; H:boolean):string;
{-ᮧ���� �� ��p��� ��� 䠩�-���� � ���� zznnnfff.ppX}
function _32toAddr(sa:string; var A:tAddress):boolean;
{-��p��� ��p�� � A ��� 䠩�-���� � ������ zznnnfff.ppX
                                           �������� ��^
 TRUE/FALSE == 宫����/��p����� ����}


IMPLEMENTATION

uses
 TpDos,
 Busy,
 Tstring_,
 aTime,
 WriteLog,
 SM_Cpl,
 SubstMan,
 TpCrt,
 SfInclud,
 MbMan,
 FbMan,
 Flags,
 fileman,
 SfM_Cfg,
 ProcMan,
 Sf_Snd,
 Pwd_Xs,
 Sf_Track,
 a002xs,
 Cfg_Read,
 crc_all,
 Face,
 Modem,
 Fos_Lib,
 StatView,
 ScrnSS,
 {$IFNDEF NoComm}
 KeyRead,
 {$ENDIF}
 UnixTime,
 EventMan;

var
 routeLn:word;

function AddrTo32(A:tAddress; H:boolean):string;
{-ᮧ���� �� ��p��� ��� 䠩�-���� � ���� zznnnfff.ppX}
var
 s:string;
 i:byte;

begin
 if H then s:='H'
 else s:='';

 with A do begin
 { Point }
 for i:=0 to 1 do begin
        s:=_32_table[$1F and System.lo(Point)] + s;
        Point:=Point shr 5;
 end;
 s:='.' + s;

 { Node }
 for i:=0 to 2 do begin
        s:=_32_table[$1F and System.lo(Node)] + s;
        Node:=Node shr 5;
 end;

 { Net }

 for i:=0 to 2 do begin
        s:=_32_table[$1F and System.lo(Net)] + s;
        Net:=Net shr 5;
 end;

 { Zone }
 for i:=0 to 1 do begin
        s:=_32_table[$1F and System.lo(Zone)] + s;
        Zone:=Zone shr 5;
 end;
 end; (*WITH A*)

 AddrTo32:=s;
end;

function _32toAddr(sa:string; var A:tAddress):boolean;
{-��p��� ��p�� � A ��� 䠩�-���� � ������ zznnnfff.ppX
                                           �������� ��^
 TRUE/FALSE == 宫����/��p����� ����}

var
 sw,
 s:string;
 z:word;
 i:byte;

function Pos_32(c:char):byte;
var
 b:byte;

begin
 for b:=0 to 31 do if LoCase(c) =_32_table[b] then begin
   Pos_32:=b;
   exit;
 end;
end;

begin
 s:='';

 z:=0; s:='';
 for i:=1 to 2 do z:=(z shl 5) or Pos_32(sa[i]);

 Str(z,s);

 z:=0;
 for i:=3 to 5 do z:=(z shl 5) or Pos_32(sa[i]);
 Str(z,sw); s:=s+':'+sw+'/';

 z:=0;
 for i:=6 to 8 do z:=(z shl 5) or Pos_32(sa[i]);
 Str(z,sw); s:=s+sw+'.';

 z:=0;
 for i:=10 to 11 do z:=(z shl 5) or Pos_32(sa[i]);
 Str(z,sw); s:=s+sw;

 Str2addr(s,A);
 _32toAddr:=Length(JustExtension(sa)) =3;
end;

procedure Check4Lamps;
var
 f:file;
 w:word;

begin
 if not ScreenSave then with pCfgRec^ do begin
  { No Answer }
  FastWrite(NA_Lamp[not MatchTimeArray(_OH_Time_)],ScreenHeight-2,66,
            SfMailColors[Indicators]);
  { No FReqs }
  FastWrite(NF_Lamp[not MatchTimeArray(_FR_Time_)],ScreenHeight-2,69,
            SfMailColors[Indicators]);
  { Force Answer }
  FastWrite(FA_Lamp[ForceAnswerMode],ScreenHeight - 2,77,
            SfMailColors[Indicators]);
  { Mail for us}
  if MailBoxList =NoLink then with MsgFolderInfo do
   if Mail4us <>0 then begin
     assign(f,NetMail+'lastread');
     reset(f,1);
     if IoResult <>0 then
       Mail4us:=0
     else begin
       BlockRead(f,w,2);
       close(f);
       if w >=Mail4us then
         Mail4us:=0;
     end;
     w:=IoResult;
     FastWrite(Mail4us_Lamp[Mail4us <>0],ScreenHeight-2,72,
               SfMailColors[Indicators]);
   end;
 end;
end;

function MatchEvRoFtime(routing:boolean):boolean;
{-ᮢ������ �� ���� 䠩�� ����⮢/p�⨭��
  � ��� ��� ��᫥���� �������樨 EventFtime/RouteFtime)?
  �᫨ ��� -- ��୥� false}
var
 f:file;
 T:longint;

begin
 FileMode:=$20;
 if routing then
  assign(f,pCfgRec^.RoutingList)
 else
  assign(f,pCfgRec^.EventList);
 reset(f,1);
 FileMode:=$2;
 GetFtime(f,T);
 close(f);

 if IoResult <>0 then;

 if (routing and (T <>RouteFtime)) or
    ((not routing) and (T <>EventFtime)) then begin {��ᮢ������ �� ��⠬}
   if routing then
     LogWrite(wmRouteTimeWarn,'',ld_All)
   else
     LogWrite(wmEventTimeWarn,'',ld_All);
   MatchEvRoFtime:=false;
 end
 else MatchEvRoFtime:=true;

 Check4Lamps;
end;

procedure DisposeRoute;
{-�모�뢠�� �� ����� �p����� ��p�p�⨧�樨}
begin
 while RouteHead <>nil do begin
  RouteTail:=RouteHead^.NextRule;
  FreeMem(RouteHead,SizeOf(tRouteH)+Length(RouteHead^.RuleStr));
  RouteHead:=RouteTail;
 end;
 RLsize:=0;
 RouteHead:=nil;
 RouteTail:=nil;
end;

procedure AddRoute(var R:tRouteRec);
{-�������� �p����� � ᯨ᮪}
var
 p:pRouteRec;

begin
 with R do begin
  R.NextRule:=nil;
  GetMem(p,SizeOf(tRouteH)+Length(RuleStr));
  Move(R,p^,SizeOf(tRouteH)+Length(RuleStr));
  if RouteHead =NoLink then begin
   RouteHead:=p;
   RouteTail:=p;
  end
  else begin
   RouteTail^.NextRule:=p;
   RouteTail:=p;
  end;
  Inc(RLsize,SizeOf(tRouteH)+Length(RuleStr));
 end;
end;

procedure Unsqueze_Que(n:word);
begin
 Move(Que[n],Que[n+1],(MaxQue-n)*SizeOf(pointer));
end;

procedure Squeze_Que(n:word);
begin
 if Que[n] =nil then exit;

 FreeMem(Que[n],SizeOf(tQueueRec));
 Move(Que[n+1],Que[n],(MaxQue_Reserv-n)*SizeOf(pointer));

 if Que[CurQue] =nil then CurQue:=1;
 Dec(QLsize,SizeOf(tQueueRec));
end;

procedure KillEmptyQue;
{-���塞 ����� �������� ��p���, �஬� NamedPolls}
var
 w:word;

begin
 w:=1;
 repeat
  if Que[w] <>nil then with Que[w]^ do
   if (omMask and omNamedPoll =0) and
      (MailSize =0) and (FileSize =0) and (HoldMailSize =0) and
      (HoldFileSize =0) and (HoldBoxSize =0) and (NormalBoxSize =0) then
    Squeze_Que(w)
   else
    Inc(w)
  else { �᫨ ᫮�=nil, ����� �� ��諨 �� ���� ��p��� }
   w:=succ(MaxQue);
 until w >MaxQue;

 { �p���p塞, �� ��誠������ �� 㪠��⥫� ��p��� }
 if (CurQue >MaxQue) or (Que[CurQue] =nil) then CurQue:=1;
end;

procedure AddHIP;
{-�������� HIP-䫠�� (�� HIPtmp)}
var
 i:word;

begin
 if HIParray[MaxQue] =nil then begin
   i:=1;
   while HIParray[i] <>nil do begin
    if CompWordStruct(HIPtmp.hipAddr,HIParray[i]^,SizeOf(tAddress)) =Equal then begin
      Move(HIPtmp,HIParray[i]^,SizeOf(tHIPflag));
      exit;
    end;
    Inc(i);
   end;
   GetMem(HIParray[i],SizeOf(tHIPflag));
   Move(HIPtmp,HIParray[i]^,SizeOf(tHIPflag));
 end;
end;

function AddQueue:word;
{-�������� ������� � ��p���}
var
 i:word;

begin
 if Que[MaxQue] <>nil then begin
   LOGWRITE(wmQueOverflow,'',ld_All);
   AddQueue:=0;
 end
 else begin
   i:=1;
   while (Que[i] <>nil) and
         (CompWordStruct(Que[i]^.DestAddr,QueTmp.DestAddr,SizeOf(tAddress)) <>Greater) do
     Inc(i);

   if Que[i] <>nil then
     Unsqueze_Que(i);

   GetMem(Que[i],SizeOf(tQueueRec));
   Move(QueTmp,Que[i]^,SizeOf(tQueueRec));  {����᫨ � ������}
   Inc(QLsize,SizeOf(tQueueRec));

   AddQueue:=i;
 end;
end;

procedure AddEvent(var E:tEventRec);
{-�������� ᮡ�⨥ � ᯨ᮪}
begin
 if EventListPtr =NoLink then begin
  GetMem(EventListPtr, SizeOf(tEventRec));
  CurEventPtr:=EventListPtr;
 end
 else begin
  GetMem(CurEventPtr,SizeOf(tEventRec));
  EventListEnd^.NextEvent:=CurEventPtr;
 end;

 Move(E,CurEventPtr^,SizeOf(tEventRec));
 EventListEnd:=CurEventPtr;
 CurEventPtr^.NextEvent:=NoLink;

 Inc(ELsize,SizeOf(tEventRec));
end;

procedure DisposeEvent;
{-�᢮������� ������ �� ��p�� ᮡ�⨩}
begin
 if EventListPtr <>NoLink then
  repeat
   EventListEnd:=EventListPtr^.NextEvent;
   FreeMem(EventListPtr,SizeOf(tEventRec));
   EventListPtr:=EventListEnd;
  until EventListPtr =NoLink;

 EventListPtr:=NoLink;
 EventListEnd:=NoLink;
 CurEventPtr:=NoLink;

 ELsize:=0;
end;

procedure CorrectHIP;
var
 i:word;
 z:tPriority;
 T:longint;
 _kill:byte;

begin
 CreateDosTimeStamp(T);
 T:=Dos2unix(T);
 i:=1;
 repeat
   if HIParray[i] <>nil then begin
    _kill:=0;
    for z:=tpImm to tpHRQ do with HIParray[i]^ do
      if T >=hipEnd[z] then
        hipEnd[z]:=NoPriority
      else
        _kill:=_kill or (1 shl ord(z));
    if _kill =0 then begin
      FreeMem(HIParray[i],SizeOf(tHIPflag));
      Move(HIParray[i+1],HIParray[i],(MaxQue_Reserv-i)*SizeOf(pointer));
    end
    else
      Inc(i);
   end
   else
    exit;
 until false;
end;

function FindHIP4addr(var Addr:tAddress):word;
{-����� � HIParray ��� 0}
var
 i:word;

begin
 FindHIP4addr:=0;
 for i:=1 to MaxQue do
  if HIParray[i] <>nil then begin
   if CompWordStruct(Addr,HIParray[i]^.hipAddr,SizeOf(tAddress)) =Equal then begin
    FindHIP4addr:=i;
    exit;
   end;
  end
  else
   exit;
end;

function CheckHIP(var Addr:tAddress; tp:tPriority):boolean;
{-��୥� TRUE, �᫨ �६� ��� tp �� �� ��諮}
var
 i:word;

begin
 CheckHIP:=false;
 i:=FindHIP4addr(Addr);
 if i <>0 then
   CheckHIP:=HIParray[i]^.hipEnd[tp] <>NoPriority;
end;

function FindAddrInQueue(var DestAddr:tAddress):word;
{-�饬 � ��p��� ����� �� ��p�� DestAddr
  � ����p�頥� ��� ����p � ���ᨢ� Que
  �᫨ �� ��諨 -- ��p��� 0}
var
 i:word;

begin
 for i:=1 to MaxQue do
   if Que[i] =nil then begin
     FindAddrInQueue:=0;
     exit;
   end
   else
    if CompWordStruct(DestAddr,Que[i]^.DestAddr,SizeOf(tAddress)) =Equal then begin
      FindAddrInQueue:=i;
      exit;
    end;
end;

procedure SaveEvent;
{-������ ��p�� ᮡ�⨩. ��뢠���� �p� ����p襭��}
var
 P1:pEventRec;
 f:file;
 _v:string[3];

begin
 Move(EventManVer[0],_v[0],SizeOf(EventManVer));
 assign(f,pCfgRec^.Packets+EventSavName+savXt);
 rewrite(f,1);
 {��襬 ��p�� EvMan}
 BlockWrite(f,_v[0],SizeOf(EventManVer));
 {��襬 �p��� �������樨 䠩�� ᮡ�⨩}
 BlockWrite(f,EventFtime,SizeOf(EventFtime));

 P1:=EventListPtr;  {���.�� ���.ᯨ᪠}

 if P1 <>NoLink then
  repeat
   BlockWrite(f,P1^,SizeOf(tEventRec));
   P1:=P1^.NextEvent;
  until P1 =NoLink;

 close(f);
 if IoResult <>0 then;
end;

procedure SaveQueue;
{-������ ��p��� � HIP-䫠���. ��뢠���� �p� ����p襭��}
var
 i:word;
 f:file;
 _v:string[3];

begin
 Move(EventManVer[0],_v[0],SizeOf(EventManVer));
 assign(f,pCfgRec^.Packets+QueueSavName+savXt);
 rewrite(f,1);
 {��襬 ��p�� EvMan}
 BlockWrite(f,_v[0],SizeOf(EventManVer));
 i:=1;
 while Que[i] <>nil do begin
  BlockWrite(f,Que[i]^,SizeOf(tQueueRec));
  Inc(i);
 end;
 close(f);
 if IoResult <>0 then;
 (*������ HIP*)
 assign(f,pCfgRec^.Packets+HIPsavName+savXt);
 rewrite(f,1);
 BlockWrite(f,_v[0],SizeOf(EventManVer));
 i:=1;
 while HIParray[i] <>nil do begin
  BlockWrite(f,HIParray[i]^,SizeOf(tHIPflag));
  Inc(i);
 end;
 close(f);
 if IoResult <>0 then;
end;

procedure SaveRoute;
{-������ �p���� ��p�p�⨧�樨. ��뢠���� �p� ����p襭��}
var
 p:pRouteRec;
 f:file;
 _v:string[3];

begin
 Move(EventManVer[0],_v[0],SizeOf(EventManVer));
 assign(f,pCfgRec^.Packets+RouteSavName+savXt);
 rewrite(f,1);

 {��襬 ��p�� EvMan}
 BlockWrite(f,_v[0],SizeOf(EventManVer));
 {��襬 �p��� �������樨 䠩�� p�⨭��}
 BlockWrite(f,RouteFtime,SizeOf(RouteFtime));

 p:=RouteHead;  {���.�� ���.ᯨ᪠ �p����}

 while p <>nil do begin
  BlockWrite(f,p^,SizeOf(tRouteRec));
  p:=p^.NextRule;
 end;

 close(f);
 if IoResult <>0 then;
end;

procedure ErasePacket(A:tAddress; KillRobotMsgs:boolean);
{-㤠��� ��� 䠩�� � ��⠫��� ��� ��p�� A;
  㤠����� ��������:  *.mf?
                      *.re?
                      *.pk?
                      *.bsy
  �.�. ����� 䠩� � ��⠫��� ��� ��p�� A
 �����: ��������� ᮮ�.���� ��ᥬ � MsgFolderMap}
 (*** �������� �������� H� _H�����_ BSY-����� ***)

var
 trx:tTRxLog;
 pPath:PathStr;
 SR:SearchRec;
 o:integer;
 ff:file;
 s:string;
 f_:file of tTRxLog;

begin
 if (pCfgRec^.SysFlags and amaPack) <>0 then begin
   { ⮫쪮 �᫨ p��p�襭 ����p����� �������騪 }
   Path4addr(false,A,pPath);
   if AlienSemaphore(pPath+'.bs') then begin
     LogWrite(wmBusyFor,Addr2str(A,true),ld_All or ld_LastLn);
     exit;
   end;
   {$I+} FindFirst(pPath+'.*',Archive,SR); {$I-}
   while DosError =0 do begin
    assign(f_,AddBackSlash(JustPathName(pPath))+SR.Name);
    if StLoCase(Copy(JustExtension(SR.Name),1,2)) ='mf' then begin
      reset(f_);
      repeat
       read(f_,trx);
       ClrBit4msg(trx.MsgNo,MsgFolderInfo.MsgFolderMap);
       if KillRobotMsgs then begin
         assign(ff,pCfgRec^.NetMail+Long2str(trx.MsgNo)+MsgXt);
         reset(ff,1);
         if IoResult =0 then begin
           BlockRead(ff,s[1],36);
           close(ff);
           s[0]:=#36;
           s[0]:=chr(Pos(#0,s));
           if Pos('sf-mail ',StLoCase(s)) <>0 then erase(ff);
         end;
       end;
      until EOF(f_);
      close(f_);
    end;
    erase(f_);
    o:=IoResult;
    {$I+}
    FindNext(SR);
    {$I-}
   end;

   KillEmptyDir(JustPathName(pPath));
   o:=IoResult;
   if A.Point <>0 then
     KillEmptyDir(JustPathName(JustPathName(pPath)));
 end;

 if KillRobotMsgs and (Length(pCfgRec^.BinkOutbound) <>0) then begin
   { ����-���� p��p�襭� }
   Path4addr(true,A,pPath);
   {$I+} FindFirst(pPath+'.*',Archive,SR); {$I-}
   while DosError =0 do begin
    if SR.Size =0 then begin
      s:=StLoCase(JustExtension(SR.Name));
      if (Pos('lo',s) =2) or (Pos('ut',s) =2) then begin
        assign(ff,ForceExtension(pPath,s));
        erase(ff);
        o:=IoResult;
      end;
    end;
    {$I+} FindNext(SR); {$I-}
   end;
 end;
 o:=IoResult;
end;

procedure DisposeQueue(ErasePkts:boolean);
{-�᢮������� ������ �� ��p���,
 �᫨ ErasePkt == TRUE, � ��p��� ������}
var
 i:word;

begin
 for i:=MaxQue downto 1 do
   if Que[i] <>nil then begin
     if (Que[i]^.omMask and omNamedPoll =0) and ErasePkts then
      ErasePacket(Que[i]^.DestAddr,false);
     FreeMem(Que[i],SizeOf(tQueueRec));
     Que[i]:=nil;
   end;
 QLsize:=0;
end;

procedure DelAllForZone(var s:PathStr);
var
 SF:SearchRec;
 f:file;
 o:integer;

begin
 {$I+} FindFirst(s+'\*.*',Archive,SF); {$I-}
 while DosError =0 do begin
  assign(f,s+'\'+SF.Name);
  erase(f);
  {$I+} FindNext(SF); {$I-}
 end;

 {$I+} FindFirst(s+'\*.*',Directory,SF); {$I-}
 while DosError =0 do begin
  if SF.Name[1] <>'.' then begin
   s:=s+'\'+SF.Name;
   DelAllForZone(s);
   KillEmptyDir(s);
   o:=IoResult;
   s:=JustPathName(s);
  end;
  {$I+} FindNext(SF); {$I-}
 end;
end;

procedure DelAllQueue;
{-㤠����� �ᥩ ��p���p� � ��⠫��� <Packets>}
var
 s:PathStr;
 SR:SearchRec;
 o:integer;

begin
 if (pCfgRec^.SysFlags and amaPack) <>0 then begin
   { ⮫쪮 �᫨ ����祭 ����p����� ����p }
   s:=pCfgRec^.Packets;
   {$I+} FindFirst(s+'zone.*',Directory,SR); {$I-}
   while DosError =0 do begin
    if SR.Name[1] <>'.' then begin
     s:=s+SR.Name;
     DelAllForZone(s);
     KillEmptyDir(s);
     o:=IoResult;
     s:=JustPathName(s)+'\';
    end;
    {$I+}
    FindNext(SR);
    {$I-}
   end;
 end;
end;

procedure EraseQueue(i:word; KillRobotMsgs:boolean);
var
 o:integer;

begin
 ErasePacket(Que[i]^.DestAddr,KillRobotMsgs);
 Squeze_Que(i);
 Dec(QLsize,SizeOf(tQueueRec));
end;

procedure DelQueue(A:tStr25);
{-㤠��� ������� ��p��� ��� ��᪨ ��p�ᮢ A}
var
 Z,N,F,P:tStr5;
 i:word;

begin {DelQueue}
 SetDefaultAddr(MainAddress,false);
 if not ExpandAddrMacro(A, Z,N,F,P, false) then
  SplitAddr(A, Z,N,N,P, false);
 if Z ='*' then begin   {RePack for *ALL* ==>}
   DelAllQueue;
   DisposeQueue(false);
   FillChar(MsgFolderInfo.MsgFolderMap^[0],SizeOf(tMsgFolderMap),0);
 end
 else begin
  i:=1;
  while Que[i] <>nil do
   if MatchAddrList(Que[i]^.DestAddr,A,rsUnknown) then begin
    SetDefaultAddr(MainAddress,false);
    EraseQueue(i,false);
   end
   else
    Inc(i);
 end;
end;

procedure KillMapFlags;
Var
  SR : SearchRec;
begin
  if (pCfgRec^.SysFlags and amaPack)=0 then exit;
  {$I+} FindFirst(pCfgRec^.Flags_Dir+'\kill*.sfm',Archive,sr); {$I-}
  while DosError =0 do begin
    DeleteFlag(pCfgRec^.Flags_Dir+SR.Name);
    FindNext(SR);
  end;
end;

procedure ProccedMapFlags;
Var
  SR : SearchRec;
begin
  if (pCfgRec^.SysFlags and amaPack)=0 then exit;
  {$I+} FindFirst(pCfgRec^.Flags_Dir+'\kill*.sfm',Archive,sr); {$I-}
  while DosError =0 do begin
    ClrBit4msg(TakeFirstLong(copy(SR.Name,5,4)),MsgFolderInfo.MsgFolderMap);
    DeleteFlag(pCfgRec^.Flags_Dir+SR.Name);
    FindNext(SR);
  end;
end;

procedure CheckRepackSem(onlyKill:boolean);
{ <Flags>\REPACK.FLG\zznnnnff.pp }
{ <Flags>\<Repack_Flag> }
{ ��뢠���� � onlyKill �� RepackMail(All) ��� 㡨����
  ᥬ��p�� ��p�������� }
var
 sr:SearchRec;
 A:tAddress;
 o:integer;

begin
 o:=0;
 with pCfgRec^ do begin
   { ���塞 repack 䫠�}
   if (Length(Repack_Flag) <>0) and
      ExistFile(Flags_Dir+Repack_Flag) then begin
     o:=-1;
     {A.Zone:=AnyNum;}
     if onlyKill then
       LogWrite(imGRSkilled,'',ld_All)
     else begin
       LogWrite(imGRSdetected,'',ld_All);
       DelQueue('all');
     end;
     DeleteFlag(Flags_Dir+Repack_Flag);
   end;
   if OnlyKill then KillMapFlags else ProccedMapFlags;
   {$I+} FindFirst(Flags_Dir+RepackDirName+'\*.*',Archive,sr); {$I-}
   while DosError =0 do begin
       { �᫨ 㦥 ��p���⠭ 䫠� `Repack.now' }
     _32toAddr(sr.Name,A);
     if o <>-1 then begin
       LogWrite(imRepackSem,Addr2str(A,true),ld_All);
       DelQueue(Addr2str(A,true));
     end
     else
       LogWrite(imRSkilled,Addr2str(A,true),ld_All);
     DeleteFlag(Flags_Dir+RepackDirName+'\'+sr.Name);
     {$I+} FindNext(sr); {$I-}
   end;
   KillEmptyDir(Flags_Dir+RepackDirName);
 end;
 o:=IoResult;
end;

function LoadEvent:boolean;
{-���p㧪� ��p�������� 䠩�� ᮡ�⨩.
  ��뢠���� �p� ���樠����樨}
var
 ER:tEventRec;
 w:word;
 f:file;
 Y,M,D:word;
 _v:string[3];

label
 L;

begin
 LoadEvent:=false;
 assign(f,pCfgRec^.Packets+EventSavName+savXt);
 reset(f,1);
  if IoResult <>0 then exit;    {no EVENT saved file}

 {�⠥� ��p�� EvMan}
 BlockRead(f,_v[0],SizeOf(EventManVer),w);
 if (w <>SizeOf(EventManVer))or(_v <>EventManVer) then goto L;
 {�⠥� �p��� �������樨 䠩�� ᮡ�⨩}
 BlockRead(f,EventFtime,SizeOf(EventFtime),w);
 if (w =0) or (not MatchEvRoFtime(false)) then goto L;        {��� �� ᮢ����}

 repeat
  BlockRead(f,ER,SizeOf(tEventRec),w);
  if w =SizeOf(tEventRec) then begin
    (*if NeedClean then ER.Executed:=false;*)
    AddEvent(ER);
  end;
 until w <>SizeOf(tEventRec);

 LoadEvent:=true;

L:
 close(f);
end;

function LoadRoute:boolean;
{-���p㧪� ��p������� ��p�� ��p�p�⨧�樨
  ��뢠���� �p� ���樠����樨}
var
 RR:tRouteRec;
 w:word;
 f:file;
 _v:string[3];

label
 L;

begin
 DisposeRoute;
 LoadRoute:=false;
 assign(f,pCfgRec^.Packets+RouteSavName+savXt);
 reset(f,1);
 if IoResult <>0 then exit;    {no ROUTE saved file}

 {�⠥� ��p�� EvMan}
 BlockRead(f,_v[0],SizeOf(EventManVer),w);
 if (w <>SizeOf(EventManVer))or(_v <>EventManVer) then goto L;
 {�⠥� �p��� �������樨 䠩�� p�⨭��}
 BlockRead(f,RouteFtime,SizeOf(RouteFtime),w);
 if (w =0) or (not MatchEvRoFtime(true)) then goto L;        {��� �� ᮢ����}

 RouteHead:=nil;
 RouteTail:=nil;
 repeat
  BlockRead(f,RR,SizeOf(tRouteRec),w);
  if w =SizeOf(tRouteRec) then
   AddRoute(RR);
 until w <>SizeOf(tRouteRec);

 LoadRoute:=true;

L:
 close(f);
 if IoResult <>0 then;
end;

procedure LoadHIP;
var
 w:word;
 _v:string[3];
 f:file;

label
 L;

begin
 { �⠥� HIParray }
 assign(f,pCfgRec^.Packets+HIPsavName+savXt);
 reset(f,1);
 if IoResult <>0 then exit;
 BlockRead(f,_v[0],SizeOf(EventManVer),w);
 if (w <>SizeOf(EventManVer))or(_v <>EventManVer) then goto L;
 repeat
  BlockRead(f,HIPtmp,SizeOf(tHIPflag),w);
  if w =SizeOf(tHIPflag) then begin
   (*if NeedClean then
    FillChar(HIPtmp.hipEnd,SizeOf(tHIPend),$FF);*)
   AddHIP;
  end;
 until w <>SizeOf(tHIPflag);
L:
 close(f);
 if IoResult <>0 then;
end;

function LoadQueue:boolean;
{-���p㧪� ��p������� ��p���
  ��뢠���� �p� ���樠����樨}
var
 w:word;
 f:file;
 _v:string[3];

label
 L;

begin
 LoadQueue:=false;
 assign(f,pCfgRec^.Packets+QueueSavName+savXt);
 reset(f,1);
 if IoResult <>0 then exit;    {no QUEUE saved file, or open error}
 { �⠥� ��p�� EvMan }
 BlockRead(f,_v[0],SizeOf(EventManVer),w);
 if (w <>SizeOf(EventManVer))or(_v <>EventManVer) then goto L;
 repeat
  BlockRead(f,QueTmp,SizeOf(tQueueRec),w);
  if w =SizeOf(tQueueRec) then begin
   {if NeedClean then FillChar(QueTmp.PriorityEnd,SizeOf(tHFarray),$FF);}
   if AddQueue =0 then goto L;
  end;
 until w <>SizeOf(tQueueRec);
 LoadQueue:=true;
L:
 close(f);
 if IoResult <>0 then;
end;

function CloseEventMan:boolean;
{-����p襭�� �����,
  ������ ROUTE.$^v, EVENT.$^v, QUEUE.$^v �� ���,
  �᢮�������� �����.
 !!! H��������� ������� ����� �������H��� �������}
begin
 SaveQueue;
 DisposeQueue(false);

 SaveRoute;
 DisposeRoute;

 SaveEvent;
 DisposeEvent;

 DisposeSubstList;

 MsgXs_Done;  {�����뢠�� MsgFolderMap}

 Clear_Pwd;

 ProcMan_Done;
end;

function WhatFlavour(s:string):tRouteRule;
{-��室�� ᮮ⢥��⢨� ��p��� � ��⮤� p�⨭��}
var
 i:tRouteRule;

begin
 WhatFlavour:=rrError;
 for i:=rrDirect to rrFileTo do
   if s =sRouteRule[i] then begin
     WhatFlavour:=i;
     exit;
   end;
end;

function WhatEvent(s:string):tEventType;
{-��室�� ᮮ⢥��⢨� ��p��� � ⨯� ᮡ���}
var
 i:tEventType;

begin
 WhatEvent:=evNone;
 for i:=evExit to evCutLog do
   if s =sEventRule[i] then begin
     WhatEvent:=i;
     exit;
   end;
 LOGWRITE(emBadCmd,s+#3+Long2str(routeLn),ld_All);
end;

procedure ProcessEvRoStr(routing:boolean; s:string; var fOfs:longint);
var
 Route:tRouteRec;
 Event:tEventRec;
 Aa,DefAddr:tAddress;

function ProcessEvent:boolean;
{-���p��㥬 ��p������ ��p���, ��� ������� ᮡ���}
var
 z:byte;
 ss:string[16];
begin
 ProcessEvent:=false;
 FillChar(Event,SizeOf(tEventRec),0);
 with Event do begin
  TimePeriod.rtEnd:=MaxTime;
  ss:=StLoCase(ExtractWord(1,s,[#0]));
  z:=0;
  while (Length(ss) <>0) and (ss[1] in ['!','%','^']) do begin
   case ss[1] of
    '!': EventMode:=EventMode or em_Critical;
    '%': begin
          EventMode:=EventMode or em_Period;
          Period:=Str2time(ExtractWord(2,s,[#0]));
          z:=1;
         end;
    '^': EventMode:=EventMode or em_StartUp;
   end;
   Delete(ss,1,1);
  end;
  EventType:=WhatEvent(ss);
  if EventType =evNone then exit; {�� �뫮 �p�-��}
  StrOfs:=fOfs;
  { �� �뫮 ᮡ�⨥ -- ᮡ�p��� ��p����p� }
  case EventType of
   evExec: {EXEC [p] <"command"> <timeperiod>}
       if not Str2timePeriod(Trim(ExtractWord(3+z,s,[#0])),TimePeriod) then
         exit;
   evCutLog: {CutLog [p] <keepdays> <timepriod>}
       if not (Str2timePeriod(ExtractWord(3+z,s,[#0]),TimePeriod) and
              Str2long(ExtractWord(2+z,s,[#0]),StrOfs)) then
         exit;
   evExit, {EXIT [p] <errorlevel> <timeperiod>}
   evPoll, {POLL [p] <addrlist> <timeperiod>}
   evDrop, {Drop [p] <addrlist> <timeperiod>}
   evPack,evRePack: {PACK [p] <addressmask> <timeperiod>}
       if not Str2timePeriod(ExtractWord(3+z,s,[#0]),TimePeriod) then
         exit;
   evSet: {Set [p] <"Variable Value"> <timeperiod>}
       begin
         if not Str2timePeriod(Trim(ExtractWord(3+z,s,[#0])),
                TimePeriod) then
          LogWrite(emUndefinedTPer,Long2str(routeLn),ld_All);
       end;
  end;
  {WRITELOGALL('�'+timeperiod2str(event.timeperiod));}
 end; (*WITH EVENT*)
 AddEvent(Event);
 ProcessEvent:=true;
end;

begin  {* ProcessRoute *}
 FillChar(Route,SizeOf(tRouteRec),0);
 Route.TimePeriod.rtEnd:=MaxTime;
 Route.TimePeriod.rDOW:=$60;

 if routing then begin
  Route.Flavour:=WhatFlavour(StLoCase(ExtractWord(1,s,[' ',^I])));
  if Route.Flavour =rrError then
    LogWrite(emBadCmd,ExtractWord(1,s,[' ',^I])+#3+Long2str(routeLn),ld_All)
  else with Route do begin
    SetDefaultAddr(pCfgRec^.MyAddress[1],false);
    if Flavour in [rrMailTo,rrMailFrom,rrFileTo] then begin
     if not xStr2addr(ExtractWord(2,s,[' ',^I]),ToAddr) then
      LogWrite(emBadTargetAddr,Long2str(routeLn),ld_All)
     else begin
      RuleStr:=ExtractWord(3,s,[' ',^I]);
      if not Str2timePeriod(ExtractWord(4,s,[' ',^I]),TimePeriod) then
       LogWrite(emInvalidTPer,Long2str(routeLn),ld_All)
      else
       AddRoute(Route);
     end;
    end
    else begin
     RuleStr:=ExtractWord(2,s,[' ',^I]);
     if not Str2timePeriod(ExtractWord(3,s,[' ',^I]),TimePeriod) then
      LogWrite(emInvalidTPer,Long2str(routeLn),ld_All)
     else
      AddRoute(Route);
    end;
  end;
 end
 else begin
  { compile events }
  if not ProcessEvent then
    LogWrite(emBadCmd,ExtractWord(1,s,[' ',^I])+#3+Long2str(routeLn),ld_All);
 end;
end;

function MapRoute:boolean;
{-�⠥� 䠩� <RoutingList> -- ���ᠭ�� p�⨭��
  � ��⠢��� ��p�� p�⨭��}
var
 f:text;
 s:string;
 fOfs:longint;
begin
 MapRoute:=false;
 if IOResult<>0 then ;
 FileMode:=$20;
 assign(f,pCfgRec^.RoutingList);
 reset(f);
 FileMode:=$2;
 if IoResult <>0 then begin
   LogWrite(emCantOpen,pCfgRec^.RoutingList,ld_All);
   exit;
 end;

 GetFtime(f,RouteFtime);
 DisposeRoute;

 LogWrite(imCompiling,pCfgRec^.RoutingList,ld_All);
 fOfs:=0;
 routeLn:=0;
 RouteHead:=nil;
 RouteTail:=nil;

 repeat
   fOfs:=TextPos(f);
   readln(f,s);
   Inc(routeLn);
   if Pos(';',s) <>0 then s:=copy(s,1,pred(Pos(';',s)));
   s:=Trim(s);
   if Length(s) <>0 then ProcessEvRoStr(true,s,fOfs);
                                       {^^^^ - routinglist}
 until EOF(f);

 close(f);
 if IoResult <>0 then;
 MapRoute:=true;
 SaveRoute;
 WaitMsg;
end;

function MapEvents:boolean;
{-�⠥� 䠩� <EventList> -- ���ᠭ�� ᮡ�⨩
  � ��⠢��� ��p�� ᮡ�⨩}
var
 f:text;
 s:string;
 fOfs:longint;
begin
 MapEvents:=false;
 FileMode:=$20;
 assign(f,pCfgRec^.EventList);
 reset(f);
 FileMode:=$2;
 if IoResult <>0 then begin
   LogWrite(emCantOpen,pCfgRec^.EventList,ld_All);
   exit;
 end;

 GetFtime(f,EventFtime);
 DisposeEvent;

 LogWrite(imCompiling,pCfgRec^.EventList,ld_All);
 fOfs:=0;
 routeLn:=0;

 repeat
   fOfs:=TextPos(f);
   readln(f,s);
   Inc(routeLn);
   {if Pos(';',s) <>0 then s:=copy(s,1,pred(Pos(';',s)));}
   s:=PrepareLine(s,NumTokens);
   if Length(s) <>0 then ProcessEvRoStr(false,s,fOfs);
                                       {^^^^ - eventlist}
 until EOF(f);

 close(f);
 if IoResult <>0 then;
 MapEvents:=true;
 SaveEvent;
 WaitMsg;
end;

procedure ParseEventStr;
{-�p���⠢������ ��p��� ᮡ��� ��� �ᯮ�짮�����}
var
 i:byte absolute EventStr;
 z:byte;

begin
 EventStr:=PrepareLine(EventStr,NumTokens);
 z:=ord((CurEventPtr^.EventMode and em_Period) <>0);
 EventStr:=Trim(ExtractWord(2+z,EventStr,[#0]));
 (*
 with CurEventPtr^ do begin
  case EventType of
   evExit,
   evExec,
   evSet: EventStr:=Trim(ExtractWord(2+z,EventStr,[#0]));
   evRePack,
   evPack,
   evDrop,
   evPoll: if (EventMode and em_Period) <>0 then
            EventStr:=ExtractWord(3,EventStr,[#0])
           else
            EventStr:=ExtractWord(2,EventStr,[#0]);
  end;
 end;*)
end;

function InitEventMan:boolean;
{-���樠������ �����}
var
 f:file;
 ft:text;
 o:integer;
 s:PathStr;

procedure KillTmpLogs(sn:string);
var
 sr:SearchRec;

begin
 with pCfgRec^ do begin
  {$I+} FindFirst(Packets+sn,Archive,sr); {$I-}
  while DosError =0 do begin
    assign(f,Packets+sr.Name);
    erase(f);
    o:=IoResult;
    {$I+} FindNext(sr); {$I-}
  end;
 end;
end;

begin
 InitEventMan:=false;
 bink_ScanCircle:=0;
 LoadHIP;

 {-�⠥� ��p������ 䠩�� ROUTE, EVENT, QUEUE}
 if not (LoadRoute or MapRoute) then exit;
 if not (LoadEvent or MapEvents) then exit;

 {-� MsgXs-}
 if not InitFolder then exit;
 if msStatus in [msNeedRepack,msFolderEmpty] then SaveQueue;

 LogWrite(imRestoring,'',ld_Screen);

 if not LoadQueue then begin
   DelAllQueue;   { ��p��� �� � <Packets>\<Zone.*> }
   FillChar(MsgFolderInfo.MsgFolderMap^[0],SizeOf(tMsgFolderMap),0);
 end;

 if Length(pCfgRec^.SubstList) <>0 then
   LoadSubstList;

 if Length(pCfgRec^.File_Boxes) <>0 then MkAllDir(pCfgRec^.File_Boxes);

 with pCfgRec^ do begin
   MkAllDir(Inbound_Dir);
   MkAllDir(Flags_Dir);
   if Inbound_Dir <>Sec_Inbound then
    MkAllDir(Sec_Inbound);
   KillTmpLogs('*'+sntXt);
   KillTmpLogs('*'+rvdXt);
 end;

 { ���⨬ �������p �p���ᮢ }
 if not ProcMan_Init then exit;

 { �⠥� ��p��� }
 Read_Pwd;

 { ��p����뢠�� ᮡ��� ����� StartUp_Set }
 if EventListPtr <>NoLink then begin
   (***WriteLogScreen('..Looking for startup sets..');***)
   LogWrite(imLook4StartupEvt,'',ld_All);
   CurEventPtr:=EventListPtr;
   assign(ft,pCfgRec^.EventList);
   repeat
    with CurEventPtr^ do
      if ((EventType =evSet) or (EventMode and em_StartUp <>0)) and
         MatchTimePeriod(TimePeriod) then begin
        if TextRec(ft).Mode <>fmInput then
          reset(ft);
        TextSeek(ft,StrOfs);
        readln(ft,EventStr);
        ParseEventStr;
        AtRunTime:=true;
        DoEvent;
        Executed:=true;
        LastExec:=CurUnixTime;
      end;
    CurEventPtr:=CurEventPtr^.NextEvent;
   until CurEventPtr =NoLink;
   if TextRec(ft).Mode =fmInput then
     close(ft);
 end;

 { ���樠������ ��㪮���� �����..}
 s:=JustPathName(CfgFileName);
 s:=AddBackSlash(s);
 assign(f,s+'SfM-Snd.bin');
 reset(f,1);
 if (IoResult =0) and (FileSize(f) =SizeOf(tAllSounds)) then begin
   LogWrite(imLoading,'SFX '+s+'SfM-Snd.bin',ld_Screen);
   BlockRead(f,AllSounds,SizeOf(tAllSounds));
 end;
 close(f);
 o:=IoResult;

 { �� ���� �� ����� }
 InitEventMan:=true;
end;

procedure DoDrop;
{-��p���⪠ ᮡ��� evDrop}
var
 i:word;

begin
 i:=1;
 while (i <=MaxQue) and (Que[i] <>nil) do begin
  if MatchAddrList(Que[i]^.DestAddr,EventStr,rsUnknown) then begin
    SetDefaultAddr(MainAddress,false);
    EraseQueue(i,true);
  end
  else
    Inc(i);
 end;
end;

function MatchCfgFtime(Force_Reread:boolean):boolean;
{-�p���p�� ���� 䠩�� �᭮����� ���䨣�
  ��p��� TRUE, �᫨ ���䨣 �� �� ��p��⠭}
var
 sr:SearchRec;

begin
 MatchCfgFtime:=true;
 if not Force_Reread then begin
   {$I+} FindFirst(CfgFilename,Archive,sr); {$I-}
   if sr.Time =CfgFtime then begin
    if ExistFile(ForceExtension(CfgFilename,binXt)) then
     exit
    else
     LogWrite(wmBinCfgAbsent,'',ld_All);
   end
   else
    LogWrite(wmCfgTimeWarn,'',ld_All);
 end;
 MatchCfgFtime:=false;
 { DISPOSE: }
 LogWrite(imClearingMem,'',ld_All);
 { msg-track }
 DisposeTrackDat;
 { mail boxes }
 DisposeMailBoxes;
 { robot names}
 DisposeRobotNames;
 { broadcasting }
 DisposeBroadCast;
 { ndl access }
 DisposeNodeIdx;
 { eventmanager }
 if not CloseEventMan then
  LogWrite(emCantCloseEM,'',ld_All);
 { REINITIALIZE SYSTEM: }
 LogWrite(imReinitSystem,'',ld_All);
 CloseLogFile;
 if ScreenSave then RestScreen;
 TextAttr:=$07;
 ClrScr;
 AtRunTime:=false;
 if not Read_Config(CfgFilename) then halt(220);
 { read key-file for commercial users _only_ :-E~~~~~}
 {$IFNDEF NoComm}
 ReadSN;
 {$ENDIF}
 OpenLogFile;
 Draw_Face;
 if not InitNodeIdx then halt(231);
 {WriteLogAll('(?) Unable init NodeList access module');}
 if not InitEventMan then halt(230);
 {WriteLogAll('(?) Error init event manager');}
 ChangeDOW;
 WaitMsg;
 TempClose;
 ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
 ShowHistory;
 Check4lamps;
 InitModem;
end;

function ReadNamedPoll(n:word):boolean;
var
 f:text;
 s:string;

begin
 ReadNamedPoll:=false;
 assign(f,pCfgRec^.Flags_Dir+NamedPoll2str(Que[n]^.DestAddr)+nplXt);
 reset(f);
 if IoResult <>0 then exit;
 FillChar(NodeEntry,SizeOf(tNodeEntry),0);
 with NodeEntry do begin
  NamedPoll:=true;
  Name:=NamedPoll2str(Que[n]^.DestAddr);
  ZMode:=zmbNorm;
  Wait:=0;
  readln(f,Dial);
  readln(f,Telephone);
  readln(f,NPprocess);
  if IoResult <>0 then;
 end;
 close(f);
 if IoResult <>0 then;
 ReadNamedPoll:=true;
end;

end.
