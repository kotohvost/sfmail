{
 a002XS: a002 Nodelist Index Access Unit
 for make easy access to node information.

 (c)1994, Anton Deinow Software Research Lab.
 All rights reserved.

 Last correction: 26 Oct `94
         Version: 0.3
}

{$I-,X+}

UNIT a002xs;

INTERFACE
Uses
  Config,
  Dos,
  aTime,
  TpDos,
  Tstring_;

{$I a002.inc} {Node idx structures, constants descriptions}

type
 {㪠��⥫� �� �����/���� ������⮢}
 tNdls=array[1..MaxNodeHdr] of ^tNodeHdrRec;

 {㪠�.�� ������� �p����樨 ⥫�䮭��� ����p��}
 tPhns=array[1..MaxPhoneRec] of ^tPhoneRec;

 {-��p���p� �p������� �����ᮬ-}
 tNodeIdxStruct=record
  IdxTime    :longint;          {���/�p��� 䠩�� ������}
  HdrSize    :longint;          {p����p ���������}

  Ndls       :tNdls;            {���ᨢ 㪠��⥫�� �� ����� �������⮢}
  nNdls      :byte;             {�-�� �������⮢ � ������}

  PhoneTrx   :tPhns;            {������� �p����樨 ⥫�䮭��}
  nPhns      :byte;             {�-�� �p�����.������ ��� ⥫�䮭��}

   nRecs     :longint;   {�-�� ����ᥩ � ������}
   CurRec    :longint;   {⥪��� ������}
   hL,                   {����� �p���� ���䠩��}
   hU        :longint;   {�p���� �p���� ���䠩�� ��� �᪮p���� ���᪠}
 end;

 tNodeEntry=record            {-���p���� �� 㧫�-}
  Address     : tAddress;     {4D-��p�� ��p�� 㧫�}
  Name        : string[36];   {�������� 㧫�}
  SysOp       : string[36];   {��� ��ᮯ�}
  Status      : tNodeStatus;  {����� 㧫�
                               -��.����⠭�� NodeStatus � a002.inc}
                              {��p�p�⨧��� � �p������ ����}
  RoutNode    : tAddress;     {-�p� HUB-route}
  NamedPoll   : boolean;      {true �᫨ �� ������� �맮�}
  NPprocess   : PathStr;      {�� ��������, �᫨ CONNECT �� ��������맮��}
  U_Flags     : string[40];   {���.䫠�� 㧫� (,U,serdefined)}
  MaxBaud     : longint;      {����.᪮p.������}
  Location    : string[40];   {����p�ᯮ�������}

  Max_Tries   :byte;          {᪮�쪮 ����� �p������������}
  MinBaud_In  :longint;       {��� ᪮p���� �� �室 �����}
  SessLimitIn :longint;       {��४�뢠�� pCfgRec^.SessLimitIn}

  NumLns      :byte;          {᪮�쪮 �� ����� ����� (0==only main)}

  Telephone   :string[40];    {⥫.����p}
  Dial        :string[80];    {��䨪� ��� ����� ����� (�� SUBST`�)}
  OH_Time     :TimeArray;     {�p��� p����� �⠭樨 (�� 䫠��� Txy}
  FR_Time     :TimeArray;     {�p��� p����� �p���� (SubstList)}
  ZMode       :tZMode;        {⨯ ����� ��� �-������}
  Wait        :byte;          {�p��� �������� ����饩}
  Capability  :longint;       {䫠�� ��⥬� (�. NodeFlag)}
  MinBaud_Out :longint;       {��� ᪮p���� �� ��室 �����}
  SessLimitOut:longint;       {��४�뢠�� pCfgRec^.SessLimitOut}
  Script      :string;        {�p���}
  NoHydra     :boolean;       {���p�� ���p�}
 end;

 tNdlStatus=(
  ndlClosed,       {��p���p� �� ���樠����p�����}
  ndlOk,           {Ok}
  ndlInitError,    {�訡�� �p� ���樠����樨}
  ndlReadError,    {�訡�� �p� �⥭��}
  ndlNodeNotFound, {㧥� �� ������}
  ndlDateMismacth, {��ᮢ������� ���� ��������}

  ndlNoMoreNodes   {�p� �롮p�� 㧫�� �� ��p浪� -- ��� ����� 㧫��,
                    㤮���⢮p���� �᫮��� ��� ���⨣��� ����� 䠩��}
 );

const
 NoPhone='-unpublished-';
 IdxName='AdNdl.idx';
 SA :tAddress=(        {�᪮�� ���� (��p��)}
  Zone:0;
  Net:0;
  Node:0;
  Point:0);

var
 NodeIdxRec :tNodeIdxRec;     {������ 㧫�}

 NdlStatus:tNdlStatus;         {���.�p.��p��.��������}

 NodeIdxStruct:tNodeIdxStruct; {�p�����騩 ���� ��������}
 NodeEntry:tNodeEntry;         {���-� � ��᫥���� �������� 㧫�}

 fIdx:file;
 fNdl:text;

function InitNodeIdx:boolean;
{-�������� ��p���p� NodeIdxStruct, �᫨ ��
  ��� � NodeIdxPath ������, ��p��, �p��⠭ ������
  �������� (䠩� AdNdl.idx)

 ����� �p��⥭�� ������ ���p뢠����}

function ReOpenNodeIdx:boolean;
{-�p������ ��p뢠�� ������ �������

 �� ����� ������ ���� �맢��� �-� InitNodeIdx,
 ����� ����砭�� �p������� p����� ������ ���� �맢��� �-� CloseNodeIdx}

procedure CloseNodeIdx;
{-���p뢠�� ��p��� �� ReOpenNodeIdx ������}

procedure DisposeNodeIdx;
{-㤠��� �� ����� �������᪨ p����饭�� ����� �������⮢}

function FindNodeEntry(OnlyIndex:boolean;
                       Zone,Net,Node,Point:word):boolean;
{-��� ���p���� �� 㧫�;

 �᫨ OnlyIndex==TRUE, � ��� ⮫쪮 � ������,
 ���� -- � � ⥪�⮢�� �������.

  � ��砥 㤠筮�� ���᪠ �������� NodeEntry ���p��樥�
  �� 㧫� � ����p�頥� TRUE;
  � ��砥 ��㤠筮�� ���᪠ ��p��� FALSE}

function Str2NodeFlag(st:string):longint;
{-�� ��p��� -> � 䫠� 㧫�}

function Nflag2str(NF:longint):string;
{-�� 䫠��� -> � ��p���}

function GetNodeStatus(var s:string):tNodeStatus;
{-�� ��p��� -> � ����� 㧫�}

{-=�������⥫�� �p�楤�p� � �㭪樨=-}
function NdlStatus2str(NdlS:tNdlStatus):string;
{-����p�頥� � ���� ��p��� ⥪.���ﭨ� �����}

function CvtZMode(s:string):tZMode;
{-��p���� �� ��p��� � ⨯ zmodem'�}

function ReplaceCh(s:string; ch1:char; ch2:char):string;
{-������� �� ch1 �� ch2 � S}

IMPLEMENTATION

uses
 WriteLog,
 MsgXs;

function CvtZMode(s:string):tZMode;
const
 sZMode:array[tZMode] of string[4]=('norm','zmo','min','max');

var
 i:tZMode;

begin
 for i:=zmbNORM to zmbMAX do
   if sZMode[i] =s then begin
     CvtZMode:=i;
     exit;
   end;
 CvtZMode:=zmbNORM;
end;

function ReplaceCh(s:string; ch1:char; ch2:char):string;
{-������� �� ch1 �� ch2 � S}
var
 i:byte;

begin
 for i:=1 to Length(s) do
   if s[i] =ch1 then s[i]:=ch2;
 ReplaceCh:=s;
end;

function Nflag2str(NF:longint):string;
{-�� 䫠��� -> � ��p���}
const
 fDiv:char=',';

var
 s:string;
 si:byte absolute S;
 i:tNodeFlag;

begin
 s:='';
 for i:=CM to FAX do
   if ((NF and NodeFlag[i]) <>0) then s:=s+sNodeFlag[i]+fDiv;

 if si <>0 then Dec(si);

 Nflag2str:=s;
end;

function GetNodeStatus(var s:string):tNodeStatus;
{-�� ��p��� -> � ����� 㧫�}
var
 _s:string;
 i:tNodeStatus;

begin
 GetNodeStatus:=nsNODE;
 if s[1]=',' then exit   {�p��� 㧥�}
 else begin
  _s:=StUpCase(ExtractWord(1,s,[',']));    {����� ��p��� ᫮�� �� `,'}
  for i:=nsZONE to nsPOINT do
   if _s=sNodeStatus[i] then begin
    GetNodeStatus:=NodeStatus[i];
    exit;
   end;
 end;
end;

procedure DisposeNodeIdx;
{-���p뢠�� ������ � 㤠��� �� �����
�������᪨ p����饭�� ����� �������⮢}
var
 i:byte;

begin
 if (ndlStatus <>ndlClosed) and (NdlStatus <>ndlInitError) then
 with NodeIdxStruct do begin
   for i:=1 to nNdls do FreeMem(Ndls[i],SizeOf(tNodeHdrRec));
   for i:=1 to nPhns do FreeMem(PhoneTrx[i],SizeOf(tPhoneRec));
 end;
 ndlStatus:=ndlClosed;
end;

function InitNodeIdx:boolean;
{-�������� ��p���p� NodeIdxStruct, �᫨ ��
  ��� � NodeIdxPath ������, ��p��, �p��⠭ ������
  �������� (䠩� AdNdl.idx)
  ����p�頥� true, �᫨ Ok; ���� -- false

 ����� ���樠����樨 ������ ���p뢠����}

var
 f:file;
 l:longint;
 i:byte;
 NodeIdxHdr :tNodeIdxHdr;     {��������� ������}
 NodeHdrRec :tNodeHdrRec;     {������ ��������� ������}
 PhoneRec   :tPhoneRec;

begin
 if ndlStatus <>ndlClosed then DisposeNodeIdx;
 FillChar(NodeIdxStruct,SizeOf(tNodeIdxStruct),0);
 InitNodeIdx:=false;
 NdlStatus:=ndlInitError;      {assume INIT-error}
 if IOResult<>0 then {Clear};

 with NodeIdxStruct do begin
  FileMode:=$20;
  assign(fIdx,pCfgRec^.Nodelist+IdxName);
  reset(fIdx,1);
  FileMode:=$2;
  if IoResult <>0 then exit;

  GetFtime(fIdx,IdxTime);
  if IoResult <>0 then exit;

  {-�⠥� ��������� ������}
  BlockRead(fIdx,NodeIdxHdr,SizeOf(tNodeIdxHdr));
  if IOresult <>0 then begin
   close(fIdx);
   exit;
  end;

  HdrSize:=NodeIdxHdr.Size;  {p����p ��������� ������}

  with NodeIdxHdr,NodeHdrRec do
  repeat
   BlockRead(fIdx,NodeHdrRec,SizeOf(tNodeHdrRec));
   if IoResult <>0 then begin
    if nNdls <>0 then   {-�᫨ �� ��� ���� ��������}
      for i:=1 to nNdls do FreeMem(Ndls[i],SizeOf(tNodeHdrRec));
      close(fIdx);
      exit;
   end;
   { �p���p塞 ����稥 ������� � ᮮ⢥��⢨� ��� ����/�p�����..}
   FileMode:=$20;
   assign(f,pCfgRec^.Nodelist+NodeHdrRec.Name);
   reset(f,1);
   FileMode:=$2;
   if IoResult <>0 then begin
     LOGWRITE(emCantOpen,NodeHdrRec.Name,ld_All);
     halt(222);
   end else begin
     GetFtime(f,l);
     if l <>NodeHdrRec.Time then begin
       LOGWRITE(emNdlTimeError,NodeHdrRec.Name,ld_All);
       close(f);
       halt(223);
     end;
   end;
   close(f);
   l:=IoResult;
   { ������塞 ������� � ᯨ᮪ }
   Inc(nNdls);
   GetMem(Ndls[nNdls],SizeOf(tNodeHdrRec));
   Move(NodeHdrRec,Ndls[nNdls]^,SizeOf(tNodeHdrRec));
  until nNdls >=NodeIdxHdr.TotalNdls;

  {Dec(nNdls);}
  nRecs:=(FileSize(fIdx)-NodeIdxStruct.HdrSize) div SizeOf(tNodeIdxRec);
  CurRec:=0;

  {-���p뢠�� ������}
  close(fIdx);

  {-�⠥� ⠡���� �p����樨 ⥫�䮭��-}
  FileMode:=$20;
  assign(fIdx,pCfgRec^.Nodelist+'AdPhone.trx');
  reset(fIdx,1);
  FileMode:=$2;
   repeat
     BlockRead(fIdx,PhoneRec,SizeOf(tPhoneRec));
     if IoResult <>0 then begin
       close(fIdx);
       exit;
     end;

     Inc(nPhns);
     GetMem(PhoneTrx[nPhns],SizeOf(tPhoneRec));
     Move(PhoneRec,PhoneTrx[nPhns]^,SizeOf(tPhoneRec));
   until EOF(fIdx);

  close(fIdx);

  InitNodeIdx:=true;  {����p��, �� �� Ok!}
  NdlStatus:=ndlOk;
 end;
end;

function ReOpenNodeIdx:boolean;
{-�p������ ��p뢠�� ������ �������
 �� ����� ������ ���� �맢��� �-� InitNodeIdx,
 ����� ����砭�� �p������� p����� ������ ���� �맢��� �-� CloseNodeIdx}

var
 itm:longint;

begin
 ReOpenNodeIdx:=true;
 NdlStatus:=ndlOk;
 if IOResult<>0 then {clear};

 with NodeIdxStruct do begin
  FileMode:=$20;
  assign(fIdx,pCfgRec^.Nodelist+IdxName);
  reset(fIdx,1);
  FileMode:=$2;
  if IoResult <>0 then begin
    NdlStatus:=ndlInitError;
    ReOpenNodeIdx:=false;
  end
  else begin
    GetFtime(fIdx,itm);
    if IdxTime <>itm then begin
      LogWrite(wmIdxTimeWarn,'',ld_All);
      close(fIdx);
      if not InitNodeIdx then
        ReOpenNodeIdx:=false
      else
        ReOpenNodeIdx:=ReOpenNodeIdx;
    end;
  end;
 end;
end;

procedure CloseNodeIdx;
{-���p뢠�� ��p��� �� ReOpenNodeIdx ������}
begin
 close(fIdx);
end;

{�������������������������������������������
 �p�楤�p�, p��������� ����p�� ����
 � 㯮p冷祭��� 䠩�� �����ᮢ ��������
 ��pᨨ a002

 �饬 SA � 䠩�� IdxPath+IdxName � �����ﬨ
 NodeIdxRec[1],NodeIdxRec[2],..,NodeIdxRec[n],
 ���p�p������� �� ���p��⠭�� 4D-��p�ᮢ
 �������������������������������������������}

function BinSearch:boolean;
var
 l,u:longint;
 i:longint;

 _FA:array[1..8] of word absolute NodeIdxRec;
 _SA:array[1..8] of word absolute SA;

{-����p�頥�:
   � True/False - ��p�� �����/��������;
   � � NodeIdxRec - ������ ��� ���������� ��p�� (�᫨ true)}

begin
 NdlStatus:=ndlNodeNotFound;
 BinSearch:=false;

(* {�p����騩 ��p�� < ⥪�饣� - p��ᬠ�p����� [hU..]}
 if (NodeIdxStruct.hU < NodeIdxStruct.hL)or *)

 l:=0;   {����� �p���� ���䠩�� [# �����]}

 {-�p���� �p���� ���䠩�� [# �����] (��� ��� ���������)}
 u:=NodeIdxStruct.nRecs;

 {*** ����p�� ���� ***}
 while true do begin
  {-�饬 �p�����-}
  { �᫨ SA ���� � ⠡���, � ��-��  }
  { p�����⢮: NodeIdxRec[l] <= SA <= NodeIdxRec[u] }

  if u <l then  { ��㤠�� ���� }
   exit;

  i:=(l+u) div 2;  { i ⥯�p� 㪠�뢠�� �p���p�� ��
                     �p����� p��ᬠ�p�������� ���䠩��}

  {***---***}
  Seek(fIdx,i*SizeOf(tNodeIdxRec)+NodeIdxStruct.HdrSize);
  BlockRead(Fidx,NodeIdxRec,SizeOf(tNodeIdxRec));
   if IOresult <>0 then begin
    NdlStatus:=ndlReadError;
    exit;
   end;

  Case CompWordStruct(_SA,_FA,8) of
      Less : u:=pred(i);
   Greater : l:=succ(i);
  else
    begin
     BinSearch:=true;
     NdlStatus:=ndlOk;
     NodeIdxStruct.CurRec:=i;
     exit;
    end;
  end; {-Case}
 end; {-While}
end;  {BinSearch}

function Str2NodeFlag(st:string):longint;
{-�� ��p��� -> � 䫠� 㧫�}
var
 i:tNodeFlag;

begin
 for i:=CM to FAX do
  if sNodeFlag[i] =st then begin
   Str2NodeFlag:=NodeFlag[i];
   exit;
  end;

 Str2NodeFlag:=0;
end;

procedure ExpandNdlStr(var s:string);
{-������塞 NodeEntry ���p��樥� �� ��p��� ��������}
var
 s_:string;
 i:byte;
 n:LongInt;

begin
 if s[1]=',' then i:=2
 else i:=3;

 {FillChar(NodeEntry,SizeOf(tNodeEntry),0);}

 with NodeEntry do begin
  if SA.Point <>0 then
    Status:=nsPoint
  else
    Status:=GetNodeStatus(s);
  Move(SA,RoutNode,SizeOf(tAddress)-4);
  RoutNode.Node:=NodeIdxRec.RoutNode;

  Name:=ReplaceCh(Copy(ExtractWord(i,s,[',']),1,36),'_',' ');
  Location:=ReplaceCh(Copy(ExtractWord(i+1,s,[',']),1,40),'_',' ');
  SysOp:=ReplaceCh(Copy(ExtractWord(i+2,s,[',']),1,36),'_',' ');
  Telephone:=StLoCase(Trim(Copy(ExtractWord(i+3,s,[',']),1,40)));
  Str2long(ExtractWord(i+4,s,[',']),MaxBaud);

  OH_Time.nTPer:=0;       {�-�� ���p����� �p����� p�����}

  Inc(i,5);
  {-��p����뢠�� 䫠�� 㧫�}
  for i:=i to WordCount(s,[',']) do begin
    s_:=ExtractWord(i,s,[',']);
    if s_[1] ='U' then begin {,U,serdifined,flags}
      if (Length(s_) <>1) and (s_[2] ='T') then begin
        Txy2timePeriod(copy(s_,2,2),OH_Time.TPer[1]);
        OH_Time.nTPer:=1;
      end;
      repeat
        if (Length(s_) =3) and (s_[1] ='T') then begin
          Txy2timePeriod(s_,OH_Time.TPer[1]);
          OH_Time.nTPer:=1;
        end
        else
          if Pos('OH',s_) =1 then
            OHstr2timeArray(s_,OH_Time)
          else
           if Pos('FR',s_) =1 then
             OHstr2timeArray(s_,FR_Time);
        U_Flags:=U_Flags+','+s_;
        Inc(i);
        s_:=ExtractWord(i,s,[',']);
      until s_[0] =#0;
      exit;
    end else begin
      n:=Str2NodeFlag(s_);
      if n<>0 then
        Capability:=(Capability or n)
      else begin
        if (Length(s_) =3) and (s_[1] ='T') then begin
          Txy2timePeriod(s_,OH_Time.TPer[1]);
          OH_Time.nTPer:=1;
          U_Flags:=U_Flags+','+s_;
        end;
        if Pos('OH',s_) =1 then begin
          OHstr2timeArray(s_,OH_Time);
          U_Flags:=U_Flags+','+s_;
        end;
        if Pos('FR',s_) =1 then begin
          OHstr2timeArray(s_,FR_Time);
          U_Flags:=U_Flags+','+s_;
        end;
      end;
    end;
  end;
 end;
end;

procedure TrxPhone;
{-�p��᫨p㥬 ⥫.����p � ���ᨬ 業�}
var
 w:byte;
 s:string[15];

begin
 with NodeIdxStruct, NodeEntry do
  if (Telephone <>NoPhone) and (nPhns <>0) then
   {-�p��᫨p㥬 �p�䨪�}
   for w:=1 to nPhns do with PhoneTrx[w]^ do begin
    s:=OldPrefix;
    if s[1] ='!' then Delete(s,1,1);
    if (OldPrefix[1] ='!') then begin
     if Pos(s,Telephone) <>1 then begin
      Telephone:=NewPrefix+Telephone;
      exit;
     end;
    end
    else
     if Pos(s,Telephone) =1 then begin
      Telephone:=NewPrefix+copy(Telephone,succ(Length(s)),40);
      exit;
     end;
   end;
end;

function FindNodeEntry(OnlyIndex:boolean;
                       Zone,Net,Node,Point:word):boolean;
{-��� ���p���� �� 㧫�;

 �᫨ OnlyIndex==TRUE, � ��� ⮫쪮 � ������,
 ���� -- � � ⥪�⮢�� �������.

  � ��砥 㤠筮�� ���᪠ �������� NodeEntry ���p��樥�
  �� 㧫� � ����p�頥� TRUE;
  � ��砥 ��㤠筮�� ���᪠ ��p��� FALSE}

var
 s:string;
 w:integer;

label
 Err_1;

begin
 FindNodeEntry:=false;   {assume NotFound}

 if (NdlStatus =ndlClosed) or (NdlStatus =ndlInitError) then exit;
 FillChar(NodeEntry,SizeOf(tNodeEntry),0);

 with pCfgRec^, NodeEntry do begin
  Telephone:=NoPhone;
  ZMode:=Default_ZMode;
  Max_Tries:=CallTries;
  SessLimitIn:=SessLimit_In;
  SessLimitOut:=SessLimit_Out;
 end;

 SA.Zone:=Zone;
 SA.Net :=Net;
 SA.Node:=Node;
 SA.Point:=Point;

 if not BinSearch then exit; {-⠪��� 㧫� H�� � ������
                               ��� �訡�� (�. NdlStatus)}

 {-��p뢠�� �㦭� ��������, �᫨ OnlyIndex==FALSE}
 if not OnlyIndex then begin
   FileMode:=$20;
   with NodeIdxStruct do
     assign(fNdl,pCfgRec^.Nodelist+Ndls[NodeIdxRec.NdlNo]^.Name);
   reset(fNdl);
   FileMode:=$2;
    if IOresult <>0 then exit;
   TextSeek(fNdl,NodeIdxRec.NdlOfs);
    if IOresult <>0 then goto Err_1;
   readln(fNdl,s);
    if IOresult <>0 then goto Err_1;
   close(fNdl);

  {� S -- ��p��� �� ��������; �뭨���� ���p����:}
  ExpandNdlStr(s);   {����� ��p�� ������ ���� � SA}
  TrxPhone;          {�p��᫨p㥬 ⥫.����p � ���ᨬ 業�}
 end; {*IF not ONLY..}

 Move(SA,NodeEntry.Address,SizeOf(tAddress));

 FindNodeEntry:=true;
 NdlStatus:=ndlOk;
 exit;

Err_1:
 NdlStatus:=ndlReadError;
 close(fNdl);
 if IOresult<>0 then {clear};
end;

function NdlStatus2str(NdlS:tNdlStatus):string;
const
 sNdlStatus:array[ndlClosed..ndlNoMoreNodes] of string[15]=(
  'Struct not open',
  'Ok',
  'Struct init error',
  'Idx read error',
  'Node not found',
  'Date mismacth',
  'No more nodes');

begin
 NdlStatus2str:=sNdlStatus[NdlS];
end;

begin {StartUp}
 NdlStatus:=ndlClosed;
end.of.unit
