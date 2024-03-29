(*
**  a002.inc
**
**  Structure for the (Ad)Mail Nodelist Database Index
**  Copyright 1994 Anton the Deinow; All rights reserved.
**
**  Last revised: 17 Oct '94      version a002
*)

Type
 tNodeStatus=(
  nsZONE,
  nsREGION,
  nsHOST,
  nsHUB,
  nsPVT,
  nsHOLD,
  nsDOWN,
  nsPOINT,
  nsNODE);

Const
 NodeStatus :array[nsZONE..nsNODE] of tNodeStatus=(
  nsZONE,nsREGION,nsHOST,nsHUB,nsPVT,nsHOLD,nsDOWN,nsPOINT,nsNODE);

 sNodeStatus:array[nsZONE..nsNODE] of string[6]=
  ('ZONE','REGION','HOST','HUB','PVT','HOLD','DOWN','POINT','NODE');

  { ����� 㧫�� }
type
 tNodeFlag=(
  CM,
  MO,
  HST,
  H96,
  PEP,
  MAX,
  XX,
  XB,
  XR,
  XP,
  XW,
  MNP,
  H14,
  V32,
  V33,
  V34,
  V42,
  XC,
  XA,
  V42b,
  V32b,
  H16,
  LO_,
  ZYX,
  UISDNA,
  UISDNB,
  UISDNC,
  FAX);

const
  sNodeFlag :array[CM..FAX] of string[6]=(
  'CM'      ,
  'MO'      ,
  'HST'     ,
  'H96'     ,
  'PEP'     ,
  'MAX'     ,
  'XX'      ,
  'XB'      ,
  'XR'      ,
  'XP'      ,
  'XW'      ,
  'MNP'     ,
  'H14'     ,
  'V32'     ,
  'V33'     ,
  'V34'     ,
  'V42'     ,
  'XC'      ,
  'XA'      ,
  'V42B'    ,
  'V32B'    ,
  'H16'     ,
  'LO'      ,
  'ZYX'     ,
  'UISDNA'  ,
  'UISDNB'  ,
  'UISDNC'  ,
  'FAX'
  );

  NodeFlag :array[CM..FAX] of longint=(
  {CM    } $00000002,
  {MO    } $00000004,
  {HST   } $00000008,
  {H96   } $00000010,
  {PEP   } $00000020,
  {MAX   } $00000040,
  {XX    } $00000080,
  {XB    } $00000100,
  {XR    } $00000200,
  {XP    } $00000400,
  {XW    } $00000800,
  {MNP   } $00001000,
  {H14   } $00002000,
  {V32   } $00004000,
  {V33   } $00008000,
  {V34   } $00010000,
  {V42   } $00020000,
  {XC    } $00040000,
  {XA    } $00080000,
  {V42b  } $00100000,
  {V32b  } $00200000,
  {H16   } $00400000,
  {LO_   } $00800000,
  {ZYX   } $01000000,
  {UISDNA} $02000000,
  {UISDNB} $04000000,
  {UISDNC} $08000000,
  {FAX   } $10000000);

 MaxPhoneRec=100;        {����.�᫮ ������ �p����樨 ⥫.����p��}
 MaxNodeHdr=25;         {����.�������⮢}

Type

{*** ���� AdPhone.DAT ᮤ�p��� ������� �p����樨 ⥫�䮭��� ����p�� ***}
  tPhoneRec = record
    OldPrefix : string[15];     {-�� ��������}
    NewPrefix : string[15];     {-�� �� ��������}
    Cost      : word;           {-�⮨����� 1 ���.}
  end; {tPhoneRec}

  tPhoneArray=array[1..MaxPhoneRec] of tPhoneRec;
  pPhoneArray=^tPhoneArray;

{**  ������� 䠩� �������� AdNDL.IDX ����� ��p���p�:

 ���������:

 [���������][������_���������1][������_���������2]...[������_���������N]

 ��⥬ ���� ���p�p������ ����� ������:

 [����1][����2]..[����N]

 ��������� ᮤ�p��� ��騩 p����p ���������
 � �-�� �p����������� �������⮢:}

 tNodeIdxHdr =record
  Size      : longint;    {-p����p ���������}
  TotalNdls : byte;       {-��饥 �᫮ ����祭��� �������⮢}
 end;

{ ����� ᫥���� ����� ���������, ᮤ�p��騥 ���p���� � ����祭���
  ���������. �ᥣ� �� -- ᪮�쪮 㪠���� � ��������� � ����
  NodeIdxHdr.TotalNdls; M��ᨬ��쭮 == MaxNodeHdr}

 tNodeHdrRec =record
  Name : string[12]; {-��� �������a}
  Time : longint;    {-��� ����祭���� ��������}
 end;

 tNodeHdrArray=array[1..MaxNodeHdr] of tNodeHdrRec;
 pNodeHdrArray=^tNodeHdrArray;

{*** ����� ������ 㧫�� ***}

  tNodeIdxRec=record
    Address:tAddress;         {.$00: 4D-��p�� 㧫�}
    RoutNode   : word;        {.$08: �p� Hub-Route}
    NdlNo      : byte;        {.$0A: No �������� � ��������� ������}
    NdlOfs     : longint;     {.$0B: ᬥ饭�� � ���p��樨 �� 㧫� � �������}
  end; {NodeIdxRec, total == 16 ����}
