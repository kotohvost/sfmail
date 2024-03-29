
{$I-,X+}

UNIT SfMp_Ndl;

INTERFACE

uses
 {$IFDEF OS2}
 Use32,
 adDos2,
 {$ELSE}
 TpDos,
 {$ENDIF}
 Dos,
 tString_,
 SfMp_Var;

{$I ..\a002.inc} {Node idx structures, constants descriptions}

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

  nRecs     :longint;   {�-�� ����ᥩ � ������}
  CurRec    :longint;   {⥪��� ������}
  hL,                   {����� �p���� ���䠩��}
  hU        :longint;   {�p���� �p���� ���䠩�� ��� �᪮p���� ���᪠}
 end;

 tNodeEntry=record             {-���p���� �� 㧫�-}
  Address     : tAddress;      {4D-��p�� ��p�� 㧫�}
  Name        : string[36];    {�������� 㧫�}
  SysOp       : string[36];    {��� ��ᮯ�}
  Status      : tNodeStatus;   {����� 㧫�
                               -��.����⠭�� NodeStatus � a002.inc}
                               {��p�p�⨧��� � �p������ ����}
  RoutNode    : tAddress;      {-�p� HUB-route}
  (* Cost        : word;          {業� �� 1 ���.} *)
  U_Flags     : string[40];    {���.䫠�� 㧫� (,U,serdefined)}
  MaxBaud     : longint;       {����.᪮p.������}
  Location    : string[40];    {����p�ᯮ�������}

  Telephone   : string[40];    {⥫.����p}
  Capability  : longint;       {䫠�� ��⥬� (�. NodeFlag)}
 end;

const
 NoPhone='-unpublished-';
 IdxName='AdNdl.idx';
 SA:tAddress=(        {�᪮�� ���� (��p��)}
  Zone:0;
  Net:0;
  Node:0;
  Point:0
 );

var
 NodeIdxRec :tNodeIdxRec;     {������ 㧫�}
 NodeIdxStruct:tNodeIdxStruct; {�p�����騩 ���� ��������}
 NodeEntry:tNodeEntry;         {���-� � ��᫥���� �������� 㧫�}

 fIdx:file;
 {$IFDEF OS2}
 fNdl:file;
 {$ELSE}
 fNdl:text;
 {$ENDIF}
 s:string;

function InitNodeIdx:boolean;
{-�������� ��p���p� NodeIdxStruct, �᫨ ��
  ��� � NodeIdxPath ������, ��p��, �p��⠭ ������
  �������� (䠩� AdNdl.idx)}

procedure CloseNodeIdx;
procedure DisposeNodeIdx;

function FindNodeEntry(OnlyIndex:boolean;
                       Zone,Net,Node,Point:word):boolean;
{-��� ���p���� �� 㧫�;
 �᫨ OnlyIndex==TRUE, � ��� ⮫쪮 � ������,
 ���� -- � � ⥪�⮢�� �������.
  � ��砥 㤠筮�� ���᪠ �������� NodeEntry ���p��樥�
  �� 㧫� � ����p�頥� TRUE;
  � ��砥 ��㤠筮�� ���᪠ ��p��� FALSE}

IMPLEMENTATION

uses
 SfMp_Log,
 AEH;

function ReplaceCh(s:string; ch1:char; ch2:char):string;
{-������� �� ch1 �� ch2 � S}
var
 i:byte;

begin
 for i:=1 to Length(s) do
   if s[i] =ch1 then s[i]:=ch2;
 ReplaceCh:=s;
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
 with NodeIdxStruct do
   for i:=1 to nNdls do FreeMem(Ndls[i],SizeOf(tNodeHdrRec));
end;

function InitNodeIdx:boolean;
{-�������� ��p���p� NodeIdxStruct, �᫨ ��
  ��� � NodeIdxPath ������, ��p��, �p��⠭ ������
  �������� (䠩� AdNdl.idx)
  ����p�頥� true, �᫨ Ok; ���� -- false}

var
 f:file;
 l:longint;
 i:byte;
 NodeIdxHdr :tNodeIdxHdr;     {��������� ������}
 NodeHdrRec :tNodeHdrRec;     {������ ��������� ������}
 PhoneRec   :tPhoneRec;
 oldFM      :byte;

begin
 FillChar(NodeIdxStruct,SizeOf(tNodeIdxStruct),0);
 InitNodeIdx:=false;

 with NodeIdxStruct do begin
  oldFM:=FileMode;
  FileMode:=ofmDenyWrite;
  assign(fIdx,CfgRec^.Nodelist+IdxName);
  reset(fIdx,1);
  CheckError(CfgRec^.Nodelist+IdxName,true);
  GetFtime(fIdx,IdxTime);
  FileMode:=oldFM;
  if IoResult <>0 then exit;

  {-�⠥� ��������� ������}
  BlockRead(fIdx,NodeIdxHdr,SizeOf(tNodeIdxHdr));
  if IoResult <>0 then begin
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
   oldFM:=FileMode;
   FileMode:=0;
   assign(f,CfgRec^.Nodelist+NodeHdrRec.Name);
   FileMode:=oldFM;
   reset(f,1);
   CheckError(NodeHdrRec.Name,true);
   GetFtime(f,l);
   if l <>NodeHdrRec.Time then begin
     Log_Write(lfError,'Nodelist `'+NodeHdrRec.Name+
               #39' doesn`t match time',lwtBoth);
     close(f);
     halt(223);
   end;
   close(f);
   l:=IoResult;
   { ������塞 ������� � ᯨ᮪ }
   Inc(nNdls);
   GetMem(Ndls[nNdls],SizeOf(tNodeHdrRec));
   Move(NodeHdrRec,Ndls[nNdls]^,SizeOf(tNodeHdrRec));
  until nNdls >=NodeIdxHdr.TotalNdls;

  nRecs:=(FileSize(fIdx)-NodeIdxStruct.HdrSize) div SizeOf(tNodeIdxRec);
  CurRec:=0;
  InitNodeIdx:=true;  {����p��, �� �� Ok!}
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
  CheckError(IdxName,true);

  case CompWordStruct(_SA,_FA,8) of
      Less : u:=pred(i);
   Greater : l:=succ(i);
  else begin
        BinSearch:=true;
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
 n:byte;

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

  Inc(i,5);
  {-��p����뢠�� 䫠�� 㧫�}
  for i:=i to WordCount(s,[',']) do begin
    s_:=ExtractWord(i,s,[',']);
    (***if s_[1] ='U' then begin {,U,serdifined,flags}
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
    end
    else***)
     Capability:=(Capability or Str2NodeFlag(s_));
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
 oldFM:byte;

label
 Err_1;

begin
 FindNodeEntry:=false;   {assume NotFound}

 FillChar(NodeEntry,SizeOf(tNodeEntry),0);

 NodeEntry.Telephone:=NoPhone;

 SA.Zone:=Zone;
 SA.Net :=Net;
 SA.Node:=Node;
 SA.Point:=Point;

 if not BinSearch then exit; {-⠪��� 㧫� H�� � ������
                               ��� �訡�� (�. NdlStatus)}

 {-��p뢠�� �㦭� ��������, �᫨ OnlyIndex==FALSE}
 if not OnlyIndex then begin
  with NodeIdxStruct do
   assign(fNdl,CfgRec^.Nodelist+Ndls[NodeIdxRec.NdlNo]^.Name);
   oldFM:=FileMode;
   FileMode:=ofmDenyWrite;
   {$IFDEF OS2}
   reset(fNdl,1);
   {$ELSE}
   reset(fNdl);
   {$ENDIF}
   FileMode:=oldFM;
    if IOresult <>0 then exit;
   {$IFDEF OS2}
   Seek(fNdl,NodeIdxRec.NdlOfs);
   {$ELSE}
   TextSeek(fNdl,NodeIdxRec.NdlOfs);
   {$ENDIF}
    if IOresult <>0 then goto Err_1;
   {$IFDEF OS2}
   BlockRead(fNdl,s[1],255,w);
   s[0]:=#0;
   oldFM:=1;
   while (oldFM <w) and (not (s[oldFM] in [#13,#10,#26])) do
    Inc(byte(s[0]));
   {$ELSE}
   readln(fNdl,s);
   {$ENDIF}
    if IOresult <>0 then goto Err_1;
   close(fNdl);

  {� S -- ��p��� �� ��������; �뭨���� ���p����:}
  ExpandNdlStr(s);   {����� ��p�� ������ ���� � SA}
 end; {*IF not ONLY..}

 Move(SA,NodeEntry.Address,SizeOf(tAddress));

 FindNodeEntry:=true;
 exit;

Err_1:
 close(fNdl);
 w:=IoResult;
end;

end.of.unit
