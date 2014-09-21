
{$X+,I-,V-}

unit SfMp_Pkr;

INTERFACE

uses
 {$IFDEF OS2}
 Use32,
 Os2def,
 {$ENDIF}
 Dos,
 SfMp_Var;

procedure UnpackIncomingPkts(InPath:PathStr);
procedure RescanNetmail;

procedure ClosePkt;
{-append 2-zerobytes to current packet and close file}
function CreatePkt(var TargetAddr:tAddress;
                   var PktName:PathStr):boolean;
{-создает пакет, если его нет, пишет заголовок }
procedure DisposeMessage;
function AddFirstMsgLn(FromBuf:boolean):boolean;
function AppendMsgLn(FromBuf:boolean):boolean;
{ append line to msg line list }
function AddMsg2Pkt(var A:tAddress;
                    var PktFname:PathStr;
                    var AddedSize:longint):boolean;
{-в AddedSize возвpащает добавленый объем}
function LoadMsgText:boolean;
{-загрузка текста письма в память с текущей позиции MsgCB.fMsg}

IMPLEMENTATION

uses
 {$IFDEF OS2}
 adDos2,
 {$ELSE}
 TpDos,
 {$ENDIF}
 AEH,
 TpMemChk,
 tString_,
 SfMp_Log,
 SfMp_Ndl;

type
 tPktStatus=(pktOk,pktBad,pktArc);
 tMsgStatus=(mst4us,mstFwd,mstOk);

const
 msgBegin=$00;
 msgMustDie=$FE;
 msgOk=$FF;
 { cleared msg attributes and flags }
 caImm=$01;
 caDir=$02;

function NewMsgNum(pth:PathStr):word;
{-возвpащяет No для создаваемого письма}
var
 Di:SearchRec;
 {$IFDEF OS2}
 n1,n2:UShort;
 {$ELSE}
 n1,n2:word;
 {$ENDIF}

begin
 n1:=0;
 n2:=0;

 FindFirst(pth+'*.msg', Archive, Di);
 while DosError =0 do begin
  Str2word(copy(Di.Name,1,pred(Pos('.',Di.Name))),n1);
  if n1 >n2 then n2:=n1;
  FindNext(Di);
 end;
 NewMsgNum:=succ(n2);
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

 for i:=1 to CfgRec^.AllAddress do begin
  Move(CfgRec^.MyAddress[i],A2,SizeOf(tAddress));
  if Zone =0 then begin
   if CompWordStruct(A1.Net,A2.Net,6) =Equal then exit;
  end
  else
   if CompWordStruct(A1,A2,8) =Equal then exit;
 end;

 MsgForUs:=false;
end;

function WhatMonth(s:string):word;
var
 i:word;

begin
 for i:=1 to 12 do
   if StLoCase(s) =StLoCase(Months[i]) then begin
     WhatMonth:=i;
     exit;
   end;
end;

procedure ClosePkt;
{-append 2-zerobytes to current packet and close file}
var
 w:word;

begin
 with MsgCB do begin
  seek(fPkt,FileSize(fPkt));
  w:=$0000;
  BlockWrite(fPkt,w,2);
  close(fPkt);
  CheckError('pkt',true);
 end;
end;

function CreatePkt(var TargetAddr:tAddress;
                   var PktName:PathStr):boolean;
{-создает пакет, если его нет, пишет заголовок }
var
 w:word;
 MyAddr:tAddress;
 l:longint;
 dt:DateTime;

begin
  CreatePkt:=false;
  CreateDosTimeStamp(l);
  UnpackTime(l,dt);
  { подбиpаем подходящий AkA из списка наших адpесов }
  Move(TargetAddr,MyAddr,SizeOf(tAddress));
  MatchAkA(MyAddr);
  {-заполняем поля заголовка пакета-}
  with PktHdr, CfgRec^, MsgCB do begin
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
   OrigZone:=MyAddr.Zone;
   DestZone:=TargetAddr.Zone;
   OrigPoint:=MyAddr.Point;
   DestPoint:=TargetAddr.Point;
   {w:=FileMode; FileMode:=ofmDenyNone;}
   assign(fPkt,PktName);
   rewrite(fPkt,1);
   {FileMode:=lo(w);}
   CheckError(PktName,true);

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
     +CharStr(#0,8)                              {1A,1B,1C,1D,1E,1F,20,21}
     +Chr(Lo(OrigZone))+     Chr(Hi(OrigZone))      {22,23}
     +Chr(Lo(DestZone))+     Chr(Hi(DestZone))      {24,25}
     +Chr(Lo(AuxNet))+       Chr(Hi(AuxNet))        {26,27}
     +#0#0                                          {28,29}
     +_PCodeHi+              _PRevMinor             {2A,2B}
     +#0#0                                          {2C,2D}
     +Chr(Lo(OrigZone))+     Chr(Hi(OrigZone))      {2E,2F}
     +Chr(Lo(DestZone))+     Chr(Hi(DestZone))      {30,31}
     +Chr(Lo(OrigPoint))+    Chr(Hi(OrigPoint))     {32,33}
     +Chr(Lo(DestPoint))+    Chr(Hi(DestPoint))     {34,35}
     +_PdData);                                     {36,37,38,39}
  end;
  CheckError(PktName,true);
  ClosePkt;
  CreatePkt:=true;
end;

procedure DisposeMessage;
begin
 if MsgCB.FirstLn <>nil then with MsgCB do begin
  repeat
   LastLn:=FirstLn^.NextLn;
   FreeMem(FirstLn,MsgLnSiz+FirstLn^.LnLen+1);
   FirstLn:=LastLn;
  until FirstLn =nil;
  TotalLn:=0;
 end;
end;

procedure LogMsgInfo(lf:tLogFlavour; s:string);
begin
 with MsgCB, MsgHdr do begin
  if AddonMsgInfo <>'!' then begin
   if Pos('Post',AddonMsgInfo) =1 then
    Log_Write(lfNormal,AddonMsgInfo,lwtBoth)
   else
    log_Write(lfNormal,'Msg #'+AddonMsgInfo,lwtBoth);
  end
  else
   Log_Write(lfNormal,'─────',lwtBoth);
  Log_Write(lfNormal,' From: '+FromName+', '+_4D2str(OrgAddr),lwtBoth);
  Log_Write(lfNormal,' To  : '+ToName+', '+_4D2str(DestAddr),lwtBoth);
  Log_Write(lfNormal,' Subj: '+Subj,lwtBoth);
  Log_Write(lf,s,lwtBoth);
 end;
end;

function AddMsg2Pkt(var A:tAddress;
                    var PktFname:PathStr;
                    var AddedSize:longint):boolean;
{-в AddedSize возвpащает добавленый объем}
var
 sPmH:string;
 w,i:word;
 p:pMsgLn;

begin
 AddedSize:=0;
 AddMsg2pkt:=true;
 { не пакуем, если пустое письмо и не тpанзит }
 if (not MsgCB.MsgNotEmpty) and
    (MsgHdr.Attribute and bMsgFlag[_Forward] =0) and
    (CompWordStruct(A,MsgCB.DestAddr,SizeOf(tAddress)) =Equal) then begin
   LogMsgInfo(lfAttention,'skipped (empty msg)');
   exit;
 end;

 AddMsg2pkt:=false;

 with MsgHdr, MsgCB do begin
  MsgStr:=Subj;  {save original msg subj}
  w:=Attribute;  {save original attributes}
  {-снимаем атpибуты Local, Transit, Hold, Orphaned}
  Attribute:=Attribute and (not(bMsgFlag[_Local] or
                                bMsgFlag[_Forward] or
                                bMsgFlag[_Hold] or
                                bMsgFlag[_Orphan]));
  { если attach, то в субже выpезаем пути }
  if Attribute and bMsgFlag[_Attach] <>0 then begin
    sPmH:='';
    for i:=1 to WordCount(Subj,[' ']) do
      sPmH:=sPmH+' '+JustFilename(ExtractWord(i,Subj,[' ']));
    Subj:=TrimLead(sPmH);
  end;
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
  Subj:=MsgStr;  {restore original msg subj}
  Attribute:=w;  {restore original attributes}
  {i:=FileMode; FileMode:=ofmDenyNone;}
  assign(fPkt,PktFname);
  reset(fPkt,1);
  {FileMode:=lo(i);}
  { если пакет уже закpыт, убиpаем 2 ноль-байта }
  seek(fPkt,FileSize(fPkt)-2);
  BlockWrite(fPkt,sPmH[1],Length(sPmH));  {записали заголовок письма}
  if IoResult <>0 then begin
   close(fPkt);
   if IoResult <>0 then;
   exit;
  end;

  Inc(AddedSize,Length(sPmH));

  p:=FirstLn;

  repeat
   BlockWrite(fPkt,p^.Ln,p^.LnLen);
   Inc(AddedSize,p^.LnLen);
    p:=p^.NextLn;
  until p =nil;
  { дописываем в конце два 0-байта }
  ClosePkt;
  AddMsg2pkt:=true;
  if A.Point <>0 then
   sPmH:=JustFilename(JustPathname(PktFname))+'\'+JustFilename(PktFname)
  else
   sPmH:=JustFilename(PktFname);
  LogMsgInfo(lfAppend,' Packed to '+_4D2str(A)+' as '+sPmH+
             ' ('+Long2str(AddedSize)+' bytes)');
 end;
end;

procedure CheckLastMsgLn;
{ last ln must be ended by #13#0 }
begin
 with MsgCB do begin
  if CurLen =0 then begin
   MsgLnBuf^[1]:=13;
   MsgLnBuf^[2]:=0;
  end
  else begin
   while (CurLen <>0) and (MsgLnBuf^[CurLen] in [0,13]) do
    Dec(CurLen);
   if CurLen =0 then begin
    MsgLnBuf^[1]:=13;
    MsgLnBuf^[2]:=0;
   end
   else begin
    MsgLnBuf^[CurLen+1]:=13;
    MsgLnBuf^[CurLen+2]:=0;
   end;
  end;
  Inc(CurLen,2);
 end;
end;

procedure CheckFirstMsgLn;
{ first ln must be ended by #13 }
begin
 with MsgCB do begin
  while (CurLen <>0) and (MsgLnBuf^[CurLen] in [0,13]) do
   Dec(CurLen);
  Inc(CurLen);
  MsgLnBuf^[CurLen]:=13;
 end;
end;

function AddFirstMsgLn(FromBuf:boolean):boolean;
{-if FromBuf=true, ln source in MsgLnBuf,}
{ else it`s in a MsgStr }
var
 p:pMsgLn;

begin
 AddFirstMsgLn:=false;
 with MsgCB do begin
  { --- }
  if not FromBuf then begin
   CurLen:=Length(MsgStr);
   Move(MsgStr[1],MsgLnBuf^,CurLen);
  end;
  { if it`s a last ln -- check the end }
  if FirstLn =nil then
   CheckLastMsgLn      { must be ended by #13#0 }
  else
   CheckFirstMsgLn;    { must be ended by #13 }
  { --- }
  if not GetMemCheck(p,CurLen+MsgLnSiz+1) then begin
   Log_Write(lfError,'CLM: for add first line',lwtBoth);
   DisposeMessage;
   exit;
  end;
  p^.LnLen:=CurLen;
  p^.PrevLn:=nil;
  Move(MsgLnBuf^,p^.Ln,CurLen);
  if FirstLn =nil then begin    { it`s a first ln in msg }
   FirstLn:=p;
   LastLn:=p;
   p^.NextLn:=nil;
  end
  else begin
   { it isn`t a single ln in msg }
   FirstLn^.PrevLn:=p;
   p^.NextLn:=FirstLn;
   FirstLn:=p;
  end;
  Inc(TotalLn);
 end;
 AddFirstMsgLn:=true;
end;

function AppendMsgLn(FromBuf:boolean):boolean;
{ append line to the end of msg line list }
{ if FromBuf=true, ln source in MsgLnBuf,}
{ else it`s in a MsgStr }
var
 p:pMsgLn;

begin
 AppendMsgLn:=false;
 with MsgCB do begin
  if not FromBuf then begin
   CurLen:=Length(MsgStr);
   Move(MsgStr[1],MsgLnBuf^,CurLen);
  end;
  { check the end of ln }
  CheckLastMsgLn;
  { delete #0 at the end of prev line }
  if LastLn <>nil then
   Dec(LastLn^.LnLen);
  { --- }
  if not GetMemCheck(p,CurLen+MsgLnSiz+1) then begin
   Log_Write(lfError,'CLM: for append msg line',lwtBoth);
   DisposeMessage;
   exit;
  end;
  p^.LnLen:=CurLen;
  p^.PrevLn:=LastLn;
  p^.NextLn:=nil;
  Move(MsgLnBuf^,p^.Ln,CurLen);
  if FirstLn =nil then begin { special case for first ln }
   FirstLn:=p;
   LastLn:=p;
  end
  else begin { add at the end of existing list }
   LastLn^.NextLn:=p;
   LastLn:=p;
  end;
  Inc(TotalLn);
  if ParseMsg then begin
   MsgStr[0]:=char(MinWord(CurLen,80));
   Move(p^.Ln,MsgStr[1],ord(MsgStr[0]));
   while (MsgStr[0] <>#0) and (MsgStr[Length(MsgStr)] in [#0,#13]) do
    Dec(byte(MsgStr[0]));
  end;
 end;
 AppendMsgLn:=true;
end;

function LoadMsgHdr(MsgFname:PathStr):boolean;
{-загрузка заголовка письма в MsgHdr}
{$IFDEF OS2}
var
 hTmp:pTmpMsgHdr absolute MsgLnBuf;
{$ENDIF}

begin
 LoadMsgHdr:=false;
 DisposeMessage;
 FillChar(MsgCB,SizeOf(tMsgCB),0);
 FillChar(MsgHdr,SizeOf(tMsgHdr),0);
 {$IFDEF OS2}
 with MsgCB, MsgHdr, hTmp^ do begin
 {$ELSE}
 with MsgCB, MsgHdr do begin
 {$ENDIF}
  ParseMsg:=true;
  assign(fMsg,MsgFname);
  reset(fMsg,1);
  if CheckError(MsgFname,false) then exit;
  BlockRead(fMsg,MsgLnBuf^,$BE);
  if CheckError(MsgFname,false) then begin
   close(fMsg);
   if IoResult <>0 then;
   exit;
  end;
  { заполняем поля MsgHdr }
  FromName:=A2S(MsgLnBuf^[1],36);
  ToName:=A2S(MsgLnBuf^[$25],36);
  Subj:=A2S(MsgLnBuf^[$49],72);
  Date:=A2S(MsgLnBuf^[$91],20);
  {$IFDEF OS2}
  TimesRead:=_TimesRead;
  DestNode:=_DestNode;
  OrigNode:=_OrigNode;
   DestAddr.Node:=DestNode;  {MsgCB}
   OrgAddr.Node:=OrigNode;   {MsgCB}
  Cost:=_Cost;
  OrigNet:=_OrigNet;
  DestNet:=_DestNet;
   OrgAddr.Net:=OrigNet;     {MsgCB}
   DestAddr.Net:=DestNet;    {MsgCB}
  MsgWritten:=_MsgWritten;
  MsgArrived:=_MsgArrived;
  Reply:=_Reply;
  Attribute:=_Attribute;
  SeeAlso:=_SeeAlso;
  {$ELSE}
  TimesRead:=MemW[seg(MsgLnBuf^[$A5]):ofs(MsgLnBuf^[$A5])];
  DestNode:=MemW[seg(MsgLnBuf^[$A7]):ofs(MsgLnBuf^[$A7])];
  OrigNode:=MemW[seg(MsgLnBuf^[$A9]):ofs(MsgLnBuf^[$A9])];
   DestAddr.Node:=DestNode;  {MsgCB}
   OrgAddr.Node:=OrigNode;   {MsgCB}
  Cost:=MemW[seg(MsgLnBuf^[$AB]):ofs(MsgLnBuf^[$AB])];
  OrigNet:=MemW[seg(MsgLnBuf^[$AD]):ofs(MsgLnBuf^[$AD])];
  DestNet:=MemW[seg(MsgLnBuf^[$AF]):ofs(MsgLnBuf^[$AF])];
   OrgAddr.Net:=OrigNet;     {MsgCB}
   DestAddr.Net:=DestNet;    {MsgCB}
  MsgWritten:=MemL[seg(MsgLnBuf^[$B1]):ofs(MsgLnBuf^[$B1])];
  MsgArrived:=MemL[seg(MsgLnBuf^[$B5]):ofs(MsgLnBuf^[$B5])];
  Reply:=MemW[seg(MsgLnBuf^[$B9]):ofs(MsgLnBuf^[$B9])];
  Attribute:=MemW[seg(MsgLnBuf^[$BB]):ofs(MsgLnBuf^[$BB])];
  SeeAlso:=MemW[seg(MsgLnBuf^[$BD]):ofs(MsgLnBuf^[$BD])];
  {$ENDIF}
 end;
 LoadMsgHdr:=true;
end;

function LoadMsgText:boolean;
{-загрузка текста письма в память с текущей позиции MsgCB.fMsg}
var
 EOT:boolean;    {конец текста}
 Bofs:word;      {read buf offset}
 BytesRead:word;
 aA:tAddress;

procedure NextBlock;
begin
 with MsgCB do
  BlockRead(fMsg,MsgTrxBuf^,MsgTrxSiz,BytesRead);
 Bofs:=1;
end;

function NextMsgLn:boolean;
var
 b:byte;
 done:boolean;

begin
 done:=false;
 NextMsgLn:=false;
 with MsgCB do begin
  CurLen:=0;
  MsgStr:='';
  repeat
   if BytesRead =0 then begin
    { ничего не прочитали => конец письма? }
    done:=true;
    EOT:=true;
    {if CurLen >0 then begin
     if MsgLnBuf^[CurLen] <>$0D then
      MsgLnBuf^[CurLen]:=$0D;
    end;
    Inc(CurLen);
    MsgLnBuf^[CurLen]:=0;}
   end
   else begin
    if Bofs <=BytesRead then begin
     if MsgTrxBuf^[Bofs] <>$0A then begin
      Inc(CurLen);
      b:=MsgTrxBuf^[Bofs];
      MsgLnBuf^[CurLen]:=b;
      Inc(Bofs);
      if b =0 then begin
       done:=true;
       EOT:=true;
       {if CurLen >1 then begin
        MsgLnBuf^[CurLen]:=$0D;
        Inc(CurLen);
        MsgLnBuf^[CurLen]:=0;
       end;}
      end
      else
       if (b =$0D) or (b =$8D) then
        done:=true;
      if (not done) and (CurLen >=MaxLnSiz) then begin
       done:=true;
       {Inc(CurLen);
       MsgLnBuf^[CurLen]:=$0D;}
      end;
     end
     else
      Inc(Bofs);
    end
    else
     NextBlock;
   end;
  until done;
 end;
 NextMsgLn:=AppendMsgLn(true);
end;

begin
 LoadMsgText:=false;   {assume Error}
 with MsgCB do begin
  { check msg size }
  if FileSize(fMsg) >=(MemAvail-MsgTrxSiz) then begin
   Log_Write(lfError,'file too large',lwtBoth);
   close(fMsg);
   exit;
  end;
  { читаем письмо через MsgTrxBuf и раскладываем в список строк
  if not GetMemCheck(MsgTrxBuf,MsgTrxSiz) then begin
   Log_Write(lfError,'CLM: for trx buffer',lwtBoth);
   exit;
  end;}

  EOT:=false;
  NextBlock;

  repeat
   if not NextMsgLn then begin
    close(fMsg);
    if IoResult <>0 then;
    exit;
   end;
   if ParseMsg then begin
    if Length(Trim(MsgStr)) <>0 then
     if MsgStr[1]=^A then {kludge}
       case WhatKludge(ExtractWord(1,MsgStr,[' '])) of
        _ToPt: Str2word(ExtractWord(2,MsgStr,[' ']),DestAddr.Point);
        _FmPt: Str2word(ExtractWord(2,MsgStr,[' ']),OrgAddr.Point);
        _Intl: begin
                Str2Addr(ExtractWord(2,MsgStr,[' ']),aA);  {destination}
                DestAddr.Zone:=aA.Zone;
                Str2Addr(ExtractWord(3,MsgStr,[' ']),aA);  {original}
                OrgAddr.Zone:=aA.Zone;
               end;
        _MsgId: if Str2addr(ExtractWord(2,MsgStr,[' ']),aA) then begin
                 OrgAddr.Zone:=aA.Zone;
                 if DestAddr.Zone =0 then
                  DestAddr.Zone:=aA.Zone;
                end;
        _Flags: Flags:=copy(MsgStr,succ(Pos(' ',MsgStr)),80);
       end {*CASE*}
     else {*NOT A KLUDGE*}
      if not ((Pos('---',MsgStr) =1) or (Pos(' * Origin:',MsgStr) =1)) then
        MsgNotEmpty:=true;
   end;
  until EOT;
  (***********************)
  close(fMsg);
  if IoResult <>0 then;
  if not MsgNotEmpty then
   MsgNotEmpty:=IsRobotName(MsgHdr.FromName);
  LoadMsgText:=true;
 end;
end;

function WriteMessage(MsgFname:PathStr):boolean;
{-записывает текст письма}
var
 p:pMsgLn;

begin
 WriteMessage:=false;
 with MsgCB do begin
  assign(fMsg,MsgFname);
  reset(fMsg,1);
  if IoResult <>0 then exit;
  seek(fMsg,$BE);
  p:=FirstLn;
  repeat
   BlockWrite(fMsg,p^.Ln,p^.LnLen);
   p:=p^.NextLn;
  until p =nil;
  close(fMsg);
  if IoResult <>0 then;
  WriteMessage:=true;
  (***
  assign(fMsg,'_debug_.$$$');
  rewrite(fMsg,1);
  p:=FirstLn;
  repeat
   BlockWrite(fMsg,p^.Ln,p^.LnLen);
   p:=p^.NextLn;
  until p =nil;
  close(fMsg);
  ***)
 end;
end;

function WriteMsgHeader(MsgFname:PathStr; Create:boolean):boolean;
{-записывает заголовок из MsgHeader }
var
 {oldFM:byte;}
 s:string;

begin
 WriteMsgHeader:=false;
 {oldFM:=FileMode; FileMode:=ofmDenyWrite or ofmWriteOnly;}
 with MsgCB do begin
  assign(fMsg,MsgFname);
  if Create then
    rewrite(fMsg,1)
  else
    reset(fMsg,1);
  {FileMode:=oldFM;}
  if IoResult <>0 then exit;

  with MsgHdr do
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

  BlockWrite(fMsg,s[1],Length(s));
  if IoResult <>0 then begin
    close(fMsg);
    {erase(fMsg);}
    exit;
  end;
  close(fMsg);
 end;
 WriteMsgHeader:=true;
end;

function AddMsg2outbound(ToAddr:tAddress; Rule:tRouteRule; Fl:char):boolean;
var
 f:text;
 dt:DateTime;
 _done:boolean;
 pth:PathStr;
 s,s1,s2:string;
 l:longint;
 w:word;

procedure DoDirect;
begin
 with ToAddr do begin
  if not FindNodeEntry(false,Zone,Net,Node,Point) then begin
    if Pos('DIR',MsgCB.Flags) <>0 then
      Rule:=rrDefault
    else
      Rule:=rrHold;
    exit;
  end;
  { найден в нодлисте }
  if (NodeEntry.Status =nsHOLD) or   {узел HOLD/DOWN/PVT или нет телефона}
     (NodeEntry.Status =nsPVT) or
     (NodeEntry.Status =nsDOWN) or
     (NodeEntry.Telephone =NoPhone) then
    (*if Point <>0 then
      if MsgForUs(Zone,Net,Node,0) then
       Rule:=rrHold
      else
       if (CfgRec^.SysFlags and mscAdvRoute) <>0 then
         Point:=0
       else
         Rule:=rrHold
    else*)
      Rule:=rrHold
  else
    _done:=true;  {-выходим из цикла}
 end; {*WITH*}
end;

begin (*AddMsg2outbound*)
 AddMsg2outbound:=false;
 with DT do begin
  GetDate(Year,Month,Day,w);
  GetTime(Hour,Min,Sec,w);
 end;
 _done:=false;        {упp.пеpем.цикла}
 repeat
  case Rule of
   rrHold: _done:=true;      {на выход из цикла}
   rrDefault: with ToAddr do begin
                if Point <>0 then
                  if not MsgForUs(Zone,Net,Node,0) then
                    (*if (pCfgRec^.SysFlags and mscAdvRoute) <>0 then
                      Point:=0  { не наш поинт -- pутим на его босса }
                    else*)
                      Rule:=rrHold { pучение на босса отключено }
                  else
                   { наш поинт -- будет direct или hold }
                   if not FindNodeEntry(false,Zone,Net,Node,Point) then
                    Rule:=rrHold
                   else begin
                    if NodeEntry.Telephone <>NoPhone then begin
                     Rule:=rrDirect;
                     _done:=true;
                    end
                    else
                     Rule:=rrHold;
                   end
                else
                  { узел }
                  (*if ((pCfgRec^.SysFlags and mscAdvRoute) <>0) and
                     FindNodeEntry(true,Zone,Net,Node,Point) then
                    Node:=NodeIdxRec.RoutNode
                  else*)
                    Rule:=rrHold;
                if Rule <>rrHold then
                 Rule:=rrDirect;
               end;
    rrDirect: DoDirect;
  end;
 until _done;
 Path4addr(ToAddr,pth);
 MkAllDir(JustPathname(pth));
 if Rule =rrHold then
  Fl:='h';
 pth:=pth+'.';
 { FileRequest }
 if (MsgHdr.Attribute and bMsgFlag[_FReq]) <>0 then begin
  pth:=pth+'req';
  assign(f,pth);
  append(f);
  l:=IoResult;
  if l =2 then begin
   rewrite(f);
   Log_Write(lfCreate,'Creating FileRequest to '+_4D2str(ToAddr)+
             ' ('+JustFilename(pth)+')',lwtBoth);
  end
  else
   if l =0 then
    Log_Write(lfAppend,'Appending FileRequest to '+_4D2str(ToAddr)+
              ' ('+JustFilename(pth)+')',lwtBoth)
   else
    ForceDosError(l,pth,false);
  { write requesting files }
  s:='';
  l:=WordCount(MsgHdr.Subj,[' ']);
  w:=1;

  repeat
    s1:=ExtractWord(w,MsgHdr.Subj,[' ']);
    if s1[1] ='|' then s1[1]:='!';
    if s1[1] ='!' then begin
     if Length(s1) <>1 then begin
       s:=s+' '+s1;
       Inc(w);
     end
     else begin
       s:=s+' !'+ExtractWord(w+1,MsgHdr.Subj,[' ']);
       Inc(w,2);
     end;
    end
    else begin
     Log_Write(lfAppend,' freq '+s1,lwtBoth);
     if w =1 then
       s:=s1
     else
       s:=s+#13#10+s1;
     Inc(w);
    end;
  until w >l;

  writeln(f,s);
  close(f);
  CheckError(pth,false);
  Dec(byte(pth[0]),3);
 end;
 { attach }
 if (MsgHdr.Attribute and bMsgFlag[_Attach]) <>0 then begin
  if Fl ='o' then
   pth:=pth+'flo'
  else
   pth:=pth+Fl+'lo';
  assign(f,pth);
  append(f);
  l:=IoResult;
  if l =2 then begin
   rewrite(f);
   Log_Write(lfCreate,'Creating FileAttach to '+_4D2str(ToAddr)+
             ' ('+JustFilename(pth)+')',lwtBoth);
  end
  else
   if l =0 then
    Log_Write(lfAppend,'Appending FileAttach to '+_4D2str(ToAddr)+
              ' ('+JustFilename(pth)+')',lwtBoth)
   else
    ForceDosError(l,pth,false);
  with MsgCB do
   if Pos('TFS',Flags) <>0 then begin
    s:='#';
    s1:='[TFS]';
   end
   else
    if (Pos('KFS',Flags) <>0) or
       (MsgHdr.Attribute and bMsgFlag[_Forward] <>0) then begin
     s:='^';
     s1:='[KFS]';
    end
    else begin
     s:='';
     s1:='[NORM]';
    end;
  { write attached files }
  for w:=1 to WordCount(MsgHdr.Subj,[' ']) do begin
   if (MsgHdr.Attribute and bMsgFlag[_Forward]) <>0 then begin
    s2:=JustFilename(ExtractWord(w,MsgHdr.Subj,[' ']));
    if ExistFile(CfgRec^.Inbound+s2) then
     s2:=CfgRec^.Inbound+s2
    else
     s2:=CfgRec^.SecInbound+s2;
   end
   else
    s2:=ExtractWord(w,MsgHdr.Subj,[' ']);
   writeln(f,s+s2);
   Log_Write(lfAppend,' sent '+s2+' '+s1,lwtBoth);
  end;
  close(f);
  CheckError(pth,false);
  Dec(byte(pth[0]),3);
 end;
 { pack msg }
 pth:=pth+Fl+'ut';
 if not ExistFile(pth) then begin
  CreatePkt(ToAddr,pth);
  if ToAddr.Point <>0 then
   s2:=JustFilename(JustPathname(pth))+'\'
  else
   s2:='';
  Log_Write(lfCreate,'Creating '+s2+JustFilename(pth)+
            ' for '+_4D2str(ToAddr),lwtBoth);
 end;
 AddMsg2pkt(ToAddr,pth,l);
 AddMsg2outbound:=true;
end;

function FindRouteRule(var destAddr:tAddress; var Flavour:char):tRouteRule;
{-ищем соответствующее пpавило маpшpутизации,
  инфоpмацию об узле назначения в нодлисте
 ВОЗВРАЩАЕМ:
                dest=адpес назначения
                tRouteRule=как pутить
                RouteRecPtr указывает на найденое пpавило в куче}
var
 Route:pRouteRec;

function FindAddrInRule:boolean;
{-поиск совпадающего с MsgCB.DestAddr адpеса
  в списке адpесов пpавила pутинга из Route}
var
 i:byte;
 Ok:boolean;

begin
 Ok:=false;
 with Route^, MsgCB do
  for i:=1 to WordCount(RuleStr,[',']) do begin
   if RuleType in [rrRouteFrom,rrFilesFrom] then
    Ok:=MatchAddrList(OrgAddr,RuleStr)
   else
    Ok:=MatchAddrList(DestAddr,RuleStr);
   if Ok then begin
    FindAddrInRule:=true;
    exit;
   end;
  end;
 FindAddrInRule:=false;
   {FindAddrInRule:=((RuleType =rrRouteFrom) and MatchAddrList(OrgAddr,RuleStr)) or
      ((RuleType <>rrRouteFrom) and MatchAddrList(DestAddr,RuleStr));}
end;

function MatchRule:boolean;
{-подходит ли пpавило к письму: Files/Mail}
{ RouteTo, RouteFrom, Direct      -- только для ОБЫЧHЫХ писем}
{ DirectFiles, FilesTo, FilesFrom -- только для Attach`ей    }
begin
 with Route^, MsgCB, MsgHdr do begin
  if Attribute and bMsgFlag[_Attach] <>0 then
    MatchRule:=RuleType in [rrDirectFiles,rrFilesTo,rrFilesFrom]
  else
    MatchRule:=RuleType in [rrDirect,rrRouteTo,rrRouteFrom];
 end;
end;

begin {-FindRouteRule-}
 with MsgCB.DestAddr do begin
  Move(MsgCB.DestAddr,destAddr,SizeOf(tAddress));
  {if not (pCfgRec^.SysFlags and mscAdvRoute <>0) and
     MsgForUs(Zone,Net,Node,0) then begin
   FindRouteRule:=rrDirect;
   exit;
  end;}
  FindRouteRule:=rrDefault;      {assume Target not found}
  Flavour:='o';                  {out}
 end;

 Route:=RouteHead;

 while Route <>nil do with Route^ do begin
  { для аттачей -- только rrFiles* для остальных -- rrRoute* }
  if MatchRule and MatchTimeArray(When) then begin
    if FindAddrInRule then begin
     case RuleType of
      rrRouteFrom: FindRouteRule:=rrRouteTo;
      rrFilesFrom: FindRouteRule:=rrFilesTo;
      rrDirectFiles: FindRouteRule:=rrDirect;
     else
      FindRouteRule:=RuleType;
     end;
     if RuleType in [rrDirect,rrDirectFiles] then
      Move(MsgCB.DestAddr,destAddr,SizeOf(tAddress))
     else
      Move(TargetAddr,destAddr,SizeOf(tAddress));
     Flavour:=RuleFlavour;
     exit;
    end;
  end; {IF MUTCHRULE & MUTCHTIMEARRAY}
  { goto next rule }
  Route:=NextRule;
 end; {-WHILE, WITH}
end; {-FindRouteRule}

function RouteMsg:boolean;
{-маpшpутизация загруженного письма и
  добавление в соответствующий пакет}
var
 TargetA:tAddress;   {-адpес назначения пакета}
 mF:tRouteRule;      {-правило}
 Fl:char;            {-тип пакета}

begin
 RouteMsg:=true;  {assume Route Ok}

 with MsgCB, MsgHdr, CfgRec^ do begin
  NotTouch:=true;      { assume: not set sent/kill sent msg }
  {-если зона неизвестна, будет от нашего главного AkA-}
  if DestAddr.Zone =0 then
   DestAddr.Zone:=MyAddress[1].Zone;

  {-письмо помечено, как SENT или RECEIVED}
  if ((Attribute and (bMsgFlag[_Sent] or bMsgFlag[_Recvd])) <>0) or
     {.ИЛИ. письмо для нашего адpеса}
     MsgForUs(DestAddr.Zone,DestAddr.Net,DestAddr.Node,DestAddr.Point) then
    exit;
  NotTouch:=false;
  {-корректируем кривые руки:  FReq.Subj==NUL => Subj:='files' }
  {                            File.Subj==NUL => Attr-File }
  if Attribute and bMsgFlag[_FReq] <>0 then begin
   if Length(Trim(Subj)) =0 then begin
    Subj:='files';
    Log_Write(lfAttention,' FReq msg w/o subj:',lwtBoth);
   end;
  end
  else
   if Attribute and bMsgFlag[_Attach] <>0 then begin
    if Length(Trim(Subj)) =0 then begin
     Attribute:=Attribute and (not bMsgFlag[_Attach]);
     Attribute:=Attribute;
     Log_Write(lfAttention,' Attach msg w/o subj:',lwtBoth);
    end;
   end;

  {-холдовое письмо}
  if (Attribute and bMsgFlag[_Hold]) <>0 then begin
    RouteMsg:=AddMsg2outbound(DestAddr,rrHold,'h');
    exit;
  end;

  { CRASH == DIR+omIMM+omPRIO+No-Route}
  if (Attribute and bMsgFlag[_Crash]) <>0 then begin
    RouteMsg:=AddMsg2outbound(DestAddr,rrDirect,'c');
    exit;
  end;
  { IMM == DIR+omIMM+No-Route}
  if Pos('IMM',Flags) <>0 then begin
    RouteMsg:=AddMsg2outbound(DestAddr,rrDirect,'i');
    exit;
  end;

  if (Attribute and (bMsgFlag[_FReq] or bMsgFlag[_Forward]) =
      (bMsgFlag[_FReq] or bMsgFlag[_Forward])) and
     (Pos('DIR',Flags) =0) then begin
    {mF:=} FindRouteRule(TargetA,Fl);
    RouteMsg:=AddMsg2outbound(TargetA,rrDirect,'d');
    {WRITELOGALL('DBG:\> (freq&&fwrd&&dir)');}
    exit;
  end;

  {-DIRect и FReq нельзя pутить}
  if (Pos('DIR',Flags) <>0) or
     ((Attribute and bMsgFlag[_FReq]) <>0) then begin
    if Attribute and bMsgFlag[_Hold] <>0 then begin
      mF:=rrHold;
      Fl:='h';
    end
    else
      mF:=FindRouteRule(TargetA,Fl);
    if mF =rrHold then
      RouteMsg:=AddMsg2outbound(DestAddr,rrHold,Fl)
    else
      RouteMsg:=AddMsg2outbound(DestAddr,rrDirect,Fl);
    exit;
  end;

  {-pутинг для обычных писем и аттачей}
  mF:=FindRouteRule(TargetA,Fl);
  if mF =rrDefault then
   RouteMsg:=AddMsg2outbound(DestAddr,rrDefault,Fl)
  else
   RouteMsg:=AddMsg2outbound(TargetA,rrDirect,Fl);
 end;
end;

procedure DateStamp2timeStamp(s:string; var MsgTimeStamp:longint);
{-пеpеводит из стpокового вида в MsgTimeStamp}
var
 dt:DateTime;

begin
 with DT do begin
  { дата }
  {$IFDEF OS2}
  Str2long(ExtractWord(1,s,[' ']),day);
  Str2long(ExtractWord(3,s,[' ']),year);
  {$ELSE}
  Str2word(ExtractWord(1,s,[' ']),day);
  Str2word(ExtractWord(3,s,[' ']),year);
  {$ENDIF}
  month:=WhatMonth(ExtractWord(2,s,[' ']));
  { вpемя }
  s:=ExtractWord(4,s,[' ']);
  {$IFDEF OS2}
  Str2long(ExtractWord(1,s,[':']),hour);
  Str2long(ExtractWord(2,s,[':']),min);
  Str2long(ExtractWord(3,s,[':']),sec);
  {$ELSE}
  Str2word(ExtractWord(1,s,[':']),hour);
  Str2word(ExtractWord(2,s,[':']),min);
  Str2word(ExtractWord(3,s,[':']),sec);
  {$ENDIF}
 end;
 { объединяем в стpуктуpу }
 PackTime(dt,MsgTimeStamp);
 MsgTimeStamp:=((MsgTimeStamp and $FFFF) shl 16)+
               ((MsgTimeStamp and $FFFF0000) shr 16);
end;

function UnpackPkt(PktFname:PathStr):boolean;
type
 tBuf=array[1..20480] of byte;  {дисковый буфер для пакета}

var
 f:file;
 BufRead:^tBuf;         {буфеp для чтения пакетов}
 BufRp:word;            {указатель в буфеpе чтения}
 InRB:word;             {сколько байт в буфеpе чтения}
 {$IFDEF OS2}
 w:UShort;
 {$ELSE}
 w:word;
 {$ENDIF}
 s:string;
 aA:tAddress;

 EmptyPkt:boolean;      {если пакет был пустым}
 EOP,                   {конец пакета (End Of Packet)}
 EOPM:boolean;          {конец письма в пакете (End Of Packed Msg)}
 MsgStatus:tMsgStatus;  {состояние текущего pаспакованного письма}
 PktStatus:tPktStatus;  {состояние пакета}
 PktSiz:longint;
 ClrAttr:byte;

function NextByte:byte;
begin
 if BufRp >InRB then begin
  if not EOF(f) then begin
    BlockRead(f,BufRead^[1], SizeOf(tBuf),InRB);
    BufRp:=1;
    NextByte:=NextByte;
  end
  else begin
    NextByte:=0;
    EOP:=true;
  end;
  exit;
 end;
 { в буфеpе есть еще байты }
 NextByte:=BufRead^[BufRp];
 Inc(BufRp);
end;

{$IFDEF OS2}
function NextWord:UShort;
begin
 NextWord:=NextByte+(NextByte shl 8);
end;
{$ELSE}
function NextWord:word;
begin
 NextWord:=(NextByte shl 8)+NextByte;
end;
{$ENDIF}

procedure NextField(MsgBody:boolean);
var
 b:byte;
 done:boolean;

begin
 done:=false;
 with MsgCB do begin
  CurLen:=0;
  MsgStr:='';
  repeat
   b:=NextByte;
   if MsgBody then begin
    if b <>$0A then begin
     Inc(CurLen);
     MsgLnBuf^[CurLen]:=b;
     if b =0 then begin
      done:=true;
      EOPm:=true;
      if CurLen >1 then begin
       MsgLnBuf^[CurLen]:=$0D;
       Inc(CurLen);
       MsgLnBuf^[CurLen]:=0;
      end
      else
       Dec(CurLen);
       {MsgLnBuf^[CurLen]:=$0D;}
     end
     else
      if (b =$0D) or (b =$8D) then
       done:=true;
     if (not done) and (CurLen >=MaxLnSiz) then begin
      Inc(CurLen);
      MsgLnBuf^[CurLen]:=$0D;
      done:=true;
     end;
    end;
   end
   else begin
    if b =0 then
     done:=true
    else
     MsgStr:=MsgStr+char(b);
   end;
  until done;
  if MsgBody then begin
   MsgStr[0]:=char(MinWord(CurLen,80));
   Move(MsgLnBuf^,MsgStr[1],ord(MsgStr[0]));
   while (MsgStr[0] <>#0) and (MsgStr[Length(MsgStr)] in [#0,#13]) do
    Dec(byte(MsgStr[0]));
  end;
 end;
end;

begin (* UNPACKPKT *)
 UnpackPkt:=false;   {assume paket was спижжен}

 with MsgCB do begin
  FillChar(PktHdr,SizeOf(tPktHdr),0);
  assign(f,PktFname);
  reset(f,1);

  if IoResult <>0 then begin
   Log_Write(lfError,'Unable to open '+PktFname,lwtBoth);
   exit;
  end;

  PktSiz:=FileSize(f);

  BlockRead(f,PktHdr,SizeOf(tPktHdr));
  CheckError(PktFname,true);

  GetMem(BufRead,SizeOf(tBuf));

  BufRp:=1;
  InRB:=0;
  EOP:=false;
  EmptyPkt:=true;
  PktStatus:=pktBad;

  if PktHdr.PktType =$02 then begin

    PktStatus:=pktOk;

    Log_Write(lfNormal,'Unpacking '+JustFileName(PktFname)+' ['+
              Long2str(PktSiz)+'b]..',lwtBoth);
    with PktHdr do begin
      if (OrigPoint <>0) and (OrigNet =$FFFF) then OrigNet:=AuxNet;
      Log_Write(lfNormal,Addr2str(OrigZone,OrigNet,OrigNode,OrigPoint)+
       ' ══'#16' '+Addr2str(DestZone,DestNet,DestNode,DestPoint)+' ('+
       CheckProdCode+')',
       lwtBoth);
    end;

    repeat
     DisposeMessage;
     FillChar(MsgHdr,SizeOf(tMsgHdr),0);
     MsgNotEmpty:=false;
     FillChar(MsgCB,SizeOf(tMsgCB),0);

     EOPm:=false;
     w:=NextWord;  {PktType}
     ClrAttr:=0;   {никакие атpибуты еще не снимали}

     if not (EOP or (w =$0)) then
      if w <>$0002 then begin
        {Log_Write(lfDebug,'Pkt type $'+HexW(w)+' instead of 2+',lwtBoth);}
        PktStatus:=pktBad;
        EOP:=true;
     end
     else with MsgHdr do begin
         OrigNode:=NextWord;
         DestNode:=NextWord;
         OrigNet:=NextWord;
         DestNet:=NextWord;
         Attribute:=NextWord;
         Cost:=NextWord;

         NextField(false);
         Date:=MsgStr;

         DateStamp2timeStamp(Date,MsgWritten);
         CreateMsgTimeStamp(MsgArrived);

         NextField(false);
         ToName:=MsgStr;
         NextField(false);
         FromName:=MsgStr;
         NextField(false);
         Subj:=MsgStr;
         { в MsgCB: }
         OrgAddr.Net:=OrigNet;
         OrgAddr.Node:=OrigNode;
         DestAddr.Net:=DestNet;
         DestAddr.Node:=DestNode;
         { если письмо пpавильное }
         if EOP then
          PktStatus:=pktBad
         else with CfgRec^ do begin
          w:=msgBegin; {-после чтения пеpвой же стpоки обнулится }
          repeat
           NextField(true);
           { хм.. попался клудж AREA:xxxxxxxxx }
           if w =msgBegin then
             if Pos('AREA:',MsgStr) =1 then
               if StLoCase(copy(MsgStr,succ(Pos(':',MsgStr)),7)) <>'netmail' then
                 w:=msgMustDie
               else
                 w:=msgOk
             else
               w:=msgOk;
           {---}
           if (w =msgOk) and (Length(Trim(MsgStr)) <>0) then begin
            if MsgStr[1]=^A then  {-kludge}
             case WhatKludge(ExtractWord(1,MsgStr,[' '])) of
              _ToPt : Str2word(ExtractWord(2,MsgStr,[' ']),DestAddr.Point);
              _FmPt : Str2word(ExtractWord(2,MsgStr,[' ']),OrgAddr.Point);
              _Intl : begin
                str2Addr(ExtractWord(2,MsgStr,[' ']),aA);  {destination}
                DestAddr.Zone:=aA.Zone;
                str2Addr(ExtractWord(3,MsgStr,[' ']),aA);  {original}
                OrgAddr.Zone:=aA.Zone;
               end;
              _MsgId: begin
                Str2addr(ExtractWord(2,MsgStr,[' ']),aA);
                OrgAddr.Zone:=aA.Zone;
                if DestAddr.Zone =0 then
                 DestAddr.Zone:=aA.Zone;
               end;
              _Flags: begin
                       {Flags:=copy(s,succ(Pos(' ',s)),80);}
                       if Pos('DIR',MsgStr) <>0 then begin
                         ClrAttr:=ClrAttr or caDir;
                         FillChar(MsgLnBuf^[Pos('DIR',MsgStr)],3,' ');
                       end;
                       if Pos('IMM',MsgStr) <>0 then begin
                         ClrAttr:=ClrAttr or caImm;
                         FillChar(MsgLnBuf^[Pos('IMM',MsgStr)],3,' ');
                       end;
                      end;
             end {*CASE*}
            else { не клудж }
             if not ((Pos('---',MsgStr) =1) or (Pos(' * Origin:',MsgStr) =1)) then
               MsgNotEmpty:=true;
           end; {*IF LENGTH <>0*}
           if (w <>msgMustDie) and (CurLen <>0) then
             AppendMsgLn(true);
             {BlockWrite(fm,MsgLnBuf^,CurLen);}
          until EOPm;     {пока не конец письма}

          if w <>msgMustDie then with MsgHdr do begin
           if not MsgForUs(DestAddr.Zone,DestNet,
                          DestNode,DestAddr.Point) then begin
            { тpанзитное письмо }
            if (Attribute and bMsgFlag[_FReq] <>0) {and
               (SysFlags and frqTransit =0)} then begin
              {close(fm);
              erase(fm);
              s:=' (*Killed as transit FReq*)';}
              DisposeMessage;
              MsgStatus:=mstOk;
            end
            else with MsgHdr do begin
              { подбиpаем подходящий AkA из списка наших адpесов }
              Move(DestAddr,aA,SizeOf(tAddress));
              MatchAkA(aA);
              MsgStr:=^A'Via '+_4D2str(aA)+', '+MsgDateStamp+
                        ' '+PID+' '+VID+#$0D;
              AppendMsgLn(false);
              { чистим некоторые атрибуты и флаги }
              s:='';
              if (Attribute and bMsgFlag[_Local]) <>0 then
                s:='local';
              if (Attribute and bMsgFlag[_Crash]) <>0 then begin
                if Length(MsgStr) <>0 then s:=s+',';
                s:=s+'crash';
              end;
              if ClrAttr and caImm <>0 then begin
                if Length(s) <>0 then s:=s+',';
                s:=s+'immediate';
              end;
              if ClrAttr and caDir <>0 then begin
                if Length(s) <>0 then s:=s+',';
                s:=s+'direct';
              end;
              if Length(s) <>0 then begin
               MsgStr:=^A'ClrAttr: ['+s+']';
               AppendMsgLn(false);
              end;
              Attribute:=(Attribute or bMsgFlag[_KillSent] or
                                       bMsgFlag[_Forward]) and
                         (not (bMsgFlag[_Local] or bMsgFlag[_Crash]));
              MsgNotEmpty:=true;
              UnpackPkt:=true;     {-эффективное письмо}
              MsgStatus:=mstFwd;
                            {N°/From/To/Subj/Flags}
              AddonMsgInfo:='!';
              { тут мы его должны зарутить }
              RouteMsg;
              { .......................... }
            end;
           end
           else begin { письмо для нас }
            { удаляем, если письмо пустое }
            if (not MsgNotEmpty) and
               (not IsRobotName(ToName)) then begin
              DisposeMessage;
              s:=' (*Empty*)';
              MsgStatus:=mstOk;
            end
            else with MsgHdr do begin  { нам, но не пустое }
              MsgNotEmpty:=true;
              s:='';
              if ClrAttr and caImm <>0 then s:='immediate';
              if ClrAttr and caDir <>0 then begin
               if Length(s) <>0 then s:=s+',';
               s:=s+'direct';
              end;
              if Length(s) <>0 then begin
               MsgStr:=^A'ClrAttr: ['+s+']';
               AppendMsgLn(false);
              end;
              Attribute:=Attribute and (not (bMsgFlag[_Local] or bMsgFlag[_Crash]));
              s:='';
              UnpackPkt:=true;
              MsgStatus:=mst4us;
              { записываем письмо в каталог Netmail }
              w:=NewMsgNum(NetMail);
              WriteMsgHeader(NetMail+Long2str(w)+'.msg',true);
              WriteMessage(NetMail+Long2str(w)+'.msg');
            end;
            { выводим инфоpмацию о письме ЭТО БУДЕТ ВЫВОДИТЬСЯ В ЛОГ }
            Log_Write(lfNormal,'Msg from '+FromName+', '+_4D2str(OrgAddr)+
                      ' to '+ToName+', '+_4D2str(DestAddr)+s,lwtBoth);
           end;
            { напускаем MsgTrack и MbMan на это письмо }
            (*** if (MsgStatus <>mstOk) and
               ReadMessage(NetMail+Long2str(CurMsgReal)+MsgXt,true) then begin
              TrackMsg;
              if not Forward2mailBox then
                if MsgForUs(DestAddr.Zone,DestNet,
                            DestNode,DestAddr.Point) then
                  Mail4us:=CurMsgReal;
            end
            else
              if MsgStatus =mst4us then
                Mail4us:=CurMsgReal; ***)
          end {*IF NOT MUSTDIE*}
          else begin
            { если письмо не мыльное..}
            DisposeMessage;
            PktStatus:=pktArc;
            Log_Write(lfAttention,'There are echomail msgs in packet',
                      lwtBoth);
            { фоpсиpуем завеpшение pаспаковки..}
            EOP:=true;
          end;

          EmptyPkt:=false;
         end;
     end; {*ELSE WITH PKTHEADER*}
    until EOP;     {пока не конец пакета}
  end; {*IF PktType in PktHeader is OK*}

  close(f);
  if IoResult <>0 then;
  assign(f,PktFname);

  case PktStatus of
   pktBad: begin
            rename(f,ForceExtension(PktFname,'bad'));
            if IoResult <>0 then;
            Log_Write(lfError,'Invalid packet '+PktFname+' renamed to '+
                      ForceExtension(JustFileName(PktFname),'bad'),
                      lwtBoth);
            Inc(SessionStat.PktsBad);
           end;
   pktOk: begin
            if EmptyPkt then Log_Write(lfStat,'(*Empty*)',lwtBoth);
            erase(f);
            Log_Write(lfKill,PktFname+' killed',lwtBoth);
          end;
   pktArc: begin
             UnpackPkt:=false;
             Inc(SessionStat.PktsBad);
           end;
  end;
 end; (*WITH MSGCB*)
 if IoResult <>0 then;
 FreeMem(BufRead,SizeOf(tBuf));
end;

procedure UnpackIncomingPkts(InPath:PathStr);
var
 sr:SearchRec;

begin
 Log_Write(lfDebug,'--- Searching incoming pkts in '+InPath,lwtBoth);
 {$I+} FindFirst(InPath+'*.pkt',NormFattr,sr); {$I-}
 while DosError =0 do begin
  Inc(SessionStat.PktsFound);
  UnpackPkt(InPath+sr.Name);
  {$I+} FindNext(sr); {$I-}
 end;
end;

procedure RescanNetmail;
var
 sr:SearchRec;
 KillAfterSent:boolean;
 l:longint;

begin
 Log_Write(lfDebug,'--- Scaning netmail',lwtBoth);
 MkAllDir(CfgRec^.Netmail);
 {$I+} FindFirst(CfgRec^.Netmail+'*.msg',NormFattr,sr); {$I-}
 while DosError =0 do with CfgRec^ do begin
  Inc(SessionStat.MailScaned);
  if LoadMsgHdr(Netmail+sr.Name) and
     LoadMsgText then with MsgCB, MsgHdr do begin
   AddonMsgInfo:=copy(sr.Name,1,pred(Pos('.',sr.Name)));
   KillAfterSent:=(Attribute and bMsgFlag[_KillSent]) <>0;
   if RouteMsg and (not NotTouch) then begin
    Inc(SessionStat.MailSent);
    assign(fMsg,Netmail+sr.Name);
    if KillAfterSent then begin
     erase(fMsg);
     if not CheckError(Netmail+sr.Name,false) then
      Log_Write(lfKill,' '+sr.Name+' killed',lwtBoth);
    end
    else begin
     reset(fMsg,1);
     if not CheckError(Netmail+sr.Name,false) then begin
      seek(fMsg,$BA);
      {BlockRead(fMsg,w,SizeOf(word));
      seek(fMsg,$BA);
      w:=w or bMsgFlag[_Sent];}
      Attribute:=Attribute or bMsgFlag[_Sent];
      BlockWrite(fMsg,Attribute,2);
      seek(fMsg,$B4);
      CreateMsgTimeStamp(l);
      BlockWrite(fMsg,l,SizeOf(longint));
      close(fMsg);
      if not CheckError(Netmail+sr.Name,false) then
       Log_Write(lfNormal,' set SENT attr to '+sr.Name,lwtBoth);
     end;
    end;
   end;
  end;
  DisposeMessage;
  {$I+} FindNext(sr); {$I-}
 end;
end;

end.
