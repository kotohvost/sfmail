(*様様様様様様様様様様様様様様様様*)
(*     Santa Fox Mail system      *)
(* Application Programs Interface *)
(*   for Sf-Mail ver 1.03/beta    *)
(*    (c) by Anton the Deinow     *)
(*様様様様様様様様様様様様様様様様*)

{$X+,O+,F+,I-}

UNIT SfM_Api;

INTERFACE

(* ALL BASE TYPES DEFINED IN Cfg.pas MODULE *)

uses
 {$IFNDEF WINDOWS}
 Dos,
 Tstring_,
 {$ELSE}
 WinDos,
 tStringW,
 Dos2win,
 {$ENDIF}
 Cfg;

type
 tDOW=(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);

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

const
 _32_table:array[0..31] of char='0123456789abcdefghijklmnopqrstuv';
 { open file mode consts }
 ofmWriteOnly =$01;
 ofmReadWrite =$02;
 ofmXclusive  =$10;  { R/W xclusive }
 ofmDenyWrite =$20;  { ���pラ�モ �p磽━ ����碎 }
 ofmDenyRead  =$30;  { ���pラ�モ �p磽━ ����碎 (xclusive or denywrite)}
 ofmDenyNone  =$40;  { p��pヨ�モ �遏�� ぎ痰祚 � ����� }
 ofmInherited =$80;  { ぎ痰祚 皰�讓� か� 轤��� �p�罐瘁� }

 StatFname='FRq.$tt';

 Months:array[1..12] of string[3]=('Jan','Feb','Mar','Apr','May',
                          'Jun','Jul','Aug','Sep','Oct','Nov','Dec');
 sDOW:array[tDOW] of string[9] = (
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

 MinTime = 0;           {= 00:00 }
 MaxTime = 1439;        {= 23:59 }
 BadTime = $FFFF;

 HrsInDay = 24;         {��甌� � 痺皖��}
 MinInDay = 1440;       {�┃竄 � 痺皖��}
 MinInHour = 60;        {�┃竄 � ��痺}

 SecInMin = 60;         {瓮�祗� � �┃竄�}

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

type
 { か� �オ�皰p諷 �甌°� 罐�ォ }
 DateType=record
   Time,Date:word;
 end;

 { ����瘡 ����� 痰�皋痰�� �pオ�� }
 tFReqStatRec=record
   Addr:tAddress;
   LastFReq:longint;
   onDay,
   onWeek,
   onMonth:longint;
 end;

(**************************************** PROCEDURES AND FUNCTIONS *)

procedure Str2addr(sA:string; var Address:tAddress);
{-��pア�� ├ 痰p��� � ��pメ}

function xStr2addr(sA:string; DefAddr:tAddress; var Address:tAddress):boolean;
{-��pア�� ├ 痰p��� � ��pメ}

procedure MatchAkA(var Addr:tAddress);
{-��絎え� ��pメ ├ �p祚�� ���� ��pメ��, 甌�癶モ痰≪鉗┤ �������� � Addr}

function _4D2str(A:tAddress):string;

function WhatMonth(s:string):word;
{-����p �メ閹� �� ィ� �pュ＜�▲����� ━キ�}

function MsgDateStamp:string;
{-甌Г�モ 痰p��� ��硅 � �pガキ� � fido-痰����p皀 01 Jan 89 21:05:18}

procedure CreateMsgTimeStamp(var MsgTimeStamp :longint);
{-甌Г�碎 萵��� ├ 皀�竕ォ ��硅 � �pガキ� � FTS-001 筮p��皀}

function CurTime:tTime;
{-皀�竕ゥ �pガ� (H:M)}

function Str2Time(s:string):tTime;
{-��pア�� ├ 痰p��� � tTime}

function Time2str(T:tTime):string;
{-├ tTime � 痰p��� `HH:MM'}

function Str2timePeriod(s:string; var TPer:tTimePeriod):boolean;
{-���▲p皋p礇� ├ 痰p��� � 痰p礫矣p� timePeriod}

function Str2TimeArray(s:string; var TA:TimeArray):boolean;
{-┃皀p���� �pガキ┤, p�Гカキ�襯 `,' ├ 痰p��� S � TA}

function TimePeriod2str(TPer:tTimePeriod):string;
{-├ ��p┏�� � 痰p���}

function MatchTimePeriod(TPer:tTimePeriod):boolean;
{-��ゅ�え� �� 皀�. �pガ� � �������� � TPer}

function MatchTimeArray(var TA:TimeArray):boolean;
{-瓷���� ��瘁│ ��p┏ぎ� p�｀硅 TA.TPer � 〓Бp���モ:
  TRUE==皀�.�pガ�/ぅ�� √�え� � �え� ├ ��p┏ぎ� }

function FileBoxName(A:tAddress; Hld:boolean):PathStr;
{-〓Бp�蜿モ ━� ����-｀��� か� ��pメ� A}

procedure MkAllDir(s:PathStr; wrLog:boolean);
{-甌Г�モ ≡� ←�Ε��襯 �������� �� �竄� s}

function AddrTo32(A:tAddress; H:boolean):string;
{-甌Г�モ �� ��pメ� ━� ����-｀��� � ※ぅ zznnnfff.ppX}

function vInBestForm(v:longint):string;
{-〓Бp���モ p�К�p � ��┼竍茱� 筮p��皀}

function MsgAttrs2Str(Flg:word):string;
{-筮p��p����┘ 痰p��� 筰����}

procedure Path4addr(bink:boolean; A:tAddress; var pthfname:PathStr);
{-���竍�モ 4D-��pメ, 〓Бp.: pthfname -- �竄� � ━� ������ か� ��pメ� A}

{$IFNDEF WINDOWS}
function ReadScanCode:word;
{-Δモ (�發���� ����硅 �pガキ�) ����皋� ���※荐 � 〓Бp���モ ゥ 瓷��-���}
{$ENDIF}

IMPLEMENTATION

{$IFNDEF WINDOWS}
uses
 TpCrt,
 RelTQ;
{$ENDIF}

type
 {-皋�� ���p�甌� ��pメ��}
 tAddrMacro=(
  amAll,
  amMyZone,
  amMyPoints,
  amMyNet
 );

const
 {-���p�瘠 ��pメ��}
 AddrMacro:array[tAddrMacro] of string[8]=(
  'all',
  'myzone',
  'mypoints',
  'mynet'
 );
 AnyNum=$FEFE;
 WildCard='*';


function vInBestForm(v:longint):string;
{-〓Бp���モ p�К�p � ��┼竍茱� 筮p��皀}
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
      c:='k';
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

procedure Path4addr(bink:boolean; A:tAddress; var pthfname:PathStr);
{-���竍�モ 4D-��pメ, 〓Бp���モ:
        pthfname -- �竄� � ━� ������ か� ��pメ� A}
begin
 with pCfgRec^ do
  if bink then begin
   pthFname:=BinkOutbound;
   if A.Zone <>MyAddress[1].Zone then
     pthFname:=pthFname+'.'+copy(HexW(A.Zone),2,3);
  end
  else
   pthFname:=Packets+'zone.'+copy(HexW(A.Zone),2,3);

 pthFname:=pthFname+'\'+HexW(A.Net)+HexW(A.Node);
 if A.Point <>0 then
   pthFName:=pthFName+'.pnt\'+LeftPadCh(HexW(A.Point),'0',8);
end;

function MsgAttrs2Str(Flg:word):string;
{-筮p��p����┘ 痰p��� 筰����}
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

procedure Str2addr(sA:string; var Address:tAddress);
{-��pア�� ├ 痰p��� � ��pメ}
var
 _A:byte absolute sA;
 zp,np,pp:byte;

begin
 FillChar(Address,SizeOf(tAddress),0);
 while not(sA[_A] in ['0'..'9']) and (_A <>0) do Dec(_A);
 if _A =0 then exit;

 zp:=Pos(':',sA);
 np:=Pos('/',sA);
 pp:=Pos('.',sA);

 with Address do
 begin
  Str2Word(Copy(sA,1,pred(zp)),Zone);
  if np =0 then begin
    Str2Word(Copy(sA,succ(zp),5), Net);
    exit;
  end;

  Str2Word(Copy(sA,succ(zp),pred(np)-zp),Net);

  if pp=0 then Str2Word(Copy(sA,succ(np),5),Node)
  else begin
    Str2Word(Copy(sA,succ(np),pred(pp)-np),Node);
    Str2Word(Copy(sA,succ(pp),5),Point);
  end;
 end;
end;

function ExpandAddrMacro(s:string; var A:tAddress):boolean;
var
 i:tAddrMacro;

begin
 ExpandAddrMacro:=false;  {assume ILLEGAL MACRO}

 for i:=amAll to amMyNet do
   if StLoCase(s) =AddrMacro[i] then with pCfgRec^.MyAddress[1] do begin
    case i of
     amMyZone: A.Zone:=Zone;
     amMyNet: Move(pCfgRec^.MyAddress[1],A,4);
     amMyPoints: Move(pCfgRec^.MyAddress[1],A,6);
    end;
    ExpandAddrMacro:=true;
   end;
end;

function xStr2addr(sA:string; DefAddr:tAddress; var Address:tAddress):boolean;
{-��pア�� ├ 痰p��� � ��pメ}
var
 _A:byte absolute sA;
 zp,np,pp:byte;

begin
 xStr2addr:=true;
 FillChar(Address,SizeOf(tAddress),Lo(AnyNum));

 if (_A =1)and(sA[1] =WildCard) then exit;  {`*'}

 if not (sA[1] in ['/','.','0'..'9']) then begin
  xStr2addr:=ExpandAddrMacro(sA,Address);
  exit;
 end;

 zp:=Pos(':',sA);  {zone lim}
 np:=Pos('/',sA);  {net lim}
 pp:=Pos('.',sA);  {point lim}

 Address.Point:=0;

 if (zp =0) then begin
  Move(DefAddr,Address,6);
  if (np >2) then
    Str2word(copy(sA,1,pred(np)),Address.Net);
  { nnnn/fff.pp }
  if pp =0 then
   if np =0 then xStr2addr:=Str2word(sA,Address.Node)  { fff }
   else
    { nnnn/fff }
    xStr2addr:=Str2word(copy(sA,succ(np),5),Address.Node)
  else begin {- Pp<>0 -}
   if sA[pp+1] =WildCard then Address.Point:=AnyNum
   else
    if not Str2word(Copy(sA,succ(pp),5), Address.Point) then
      xStr2addr:=false;

   if (pp <>1)and
      (not Str2word(Copy(sA,succ(np),pred(pp)-np), Address.Node)) then
     xStr2addr:=false;
  end;
  exit;
 end; {* IF Zp=0 *}

 xStr2addr:=false;

 with Address do begin
  if not Str2Word(Copy(sA,1,pred(zp)),Zone) then exit;

  if np=0 then begin
   if sA[zp+1] =WildCard then begin   { zz:* }
    xStr2addr:=true;
    exit;
   end;
  { zz:nnn }
   xStr2addr:=Str2Word(Copy(sA,succ(zp),15), Net);
   exit;
  end;

 { zz:nnn/ }
  if not Str2Word(Copy(sA,succ(zp),pred(np)-zp),Net) then exit;

  if pp =0 then begin
   if sA[np+1] =WildCard then begin  { zz:nnn/* }
    xStr2addr:=true;
    exit;
   end;
   if not Str2Word(Copy(sA,succ(np),5),Node) then exit;
  end
  else begin
  { zz:nnn/*.pp }
   if sA[np+1] <>WildCard then    { zz:nnn/ddd.pp }
    if not Str2Word(Copy(sA,succ(np),pred(pp)-np),Node) then exit;
   if sA[pp+1] =WildCard then Point:=AnyNum
   else
    if not Str2Word(Copy(sA,succ(pp),5),Point) then exit;
  end;
 end;

 xStr2addr:=true;
end;

procedure MatchAkA(var Addr:tAddress);
{-��絎え� ��pメ ├ �p祚�� ���� ��pメ��, 甌�癶モ痰≪鉗┤ �������� � Addr}
var
 A:tAddress;
 i:byte;

begin
 FillChar(A,SizeOf(tAddress),0);
 for i:=1 to pCfgRec^.AllAddress do
  if pCfgRec^.MyAddress[i].Zone =Addr.Zone then begin
   if A.Zone =0 then Move(pCfgRec^.MyAddress[i],A,SizeOf(tAddress));
   if (pCfgRec^.MyAddress[i].Net =Addr.Net)and
      (pCfgRec^.MyAddress[i].Node =Addr.Node) then begin
        Move(pCfgRec^.MyAddress[i],Addr,SizeOf(tAddress));
        exit;
   end;
  end;

 {��ゅ�わ薀�� ��pメ� �モ -- �甎��讌礇� MAIN AkA}
 if A.Zone =0 then
        Move(pCfgRec^.MyAddress[1],Addr,SizeOf(tAddress))
 else
        Move(A,Addr,SizeOf(tAddress));
end;


function AddrTo32(A:tAddress; H:boolean):string;
{-甌Г�モ �� ��pメ� ━� ����-｀��� � ※ぅ zznnnfff.ppX}
var
 s:string;
 i:byte;

begin
 if H then s:='H'

 else s:='';

 with A do begin
 { Point }
 for i:=0 to 1 do begin
        s:=_32_table[$1F and lo(Point)] + s;
        Point:=Point shr 5;
 end;
 s:='.' + s;

 { Node }
 for i:=0 to 2 do begin
        s:=_32_table[$1F and lo(Node)] + s;
        Node:=Node shr 5;
 end;

 { Net }
 for i:=0 to 2 do begin
        s:=_32_table[$1F and lo(Net)] + s;
        Net:=Net shr 5;
 end;

 { Zone }
 for i:=0 to 1 do begin
        s:=_32_table[$1F and lo(Zone)] + s;
        Zone:=Zone shr 5;
 end;
 end; (*WITH A*)

 AddrTo32:=s;
end;

function _32toAddr(sa:string; var A:tAddress):boolean;
{-▲p�モ ��pメ � A か� ����-｀��� � ━キガ zznnnfff.ppX
                                           碩青拈潰 碩^
 TRUE/FALSE == 絎�ぎ�覃/��p���讚覃 ｀��}

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

function FileBoxName(A:tAddress; Hld:boolean):PathStr;
{-〓Бp�蜿モ ━� ����-｀��� か� ��pメ� A}
begin
 if Length(pCfgRec^.File_Boxes) =0 then
   FileBoxName:=''
 else
   FileBoxName:=pCfgRec^.File_Boxes+AddrTo32(A,Hld)+'\';
end;

function ExistDir(s:PathStr):boolean;
{-�p�▲p錺�, 痺薀痰≪モ �� ������� S}
var
 dr:SearchRec;

begin
 {$IFDEF WINDOWS}
 s:=s+#0;
 {$I+} FindFirst(@s[1],Directory,dr); {$I-}
 {$ELSE}
 {$I+} FindFirst(s,Directory,dr); {$I-}
 {$ENDIF}
 ExistDir:=DosError =0;
end;

procedure MkAllDir(s:PathStr; wrLog:boolean);
{-甌Г�モ ≡� ←�Ε��襯 ��������}
var
 o:integer;
 i,z:byte;
 s1:PathStr;

begin
 s1:=ExtractWord(1,s,['\']);

 z:=1;

 if s1 ='.' then begin
   z:=2;
   s1:='';
 end
 else begin
   z:=2;
   s:=FullPathName(s);
   s1:=ExtractWord(1,s,['\']);
 end;

 for i:=z to WordCount(s,['\']) do begin
   if s1[0] <>#0 then s1:=s1+'\';
   s1:=s1+ExtractWord(i,s,['\']);

   { �p�▲p錺�, メ碎 �� 轤�� �������,}
   { � メ�� �モ -- 甌Г�ガ           }

   if not ExistDir(s1) then begin
     if wrLog then WriteLn('Creating Dir: '+S1);
     MkDir(s1);
   end;
 end;

 o:=IoResult;
end;

function _4D2str(A:tAddress):string;
var
 s:string;

begin
 s:='';
 with A do begin
   if Zone <>0 then s:=Long2str(Zone)+':';
   s:=s+Long2str(Net)+'/'+Long2str(Node);
   if Point <>0 then s:=s+'.'+Long2str(Point);
 end;
 _4D2str:=s;
end;

function MsgDateStamp:string;
{-甌Г�モ 痰p��� ��硅 � �pガキ� � fido-痰����p皀 01 Jan 89 21:05:18}
var
 h,m,s,w :word;
 y,mo,d :word;

Begin
 GetDate(y,mo,d,w);
 GetTime(h,m,s,w);
 MsgDateStamp:=LeftPadCh(Long2str(d),'0',2)+' '+
               Months[mo]+' '+
               Copy(Long2str(y),3,2)+'  '+
              LeftPadCh(Long2str(h),'0',2)+':'+
              LeftPadCh(Long2str(m),'0',2)+':'+
              LeftPadCh(Long2str(s),'0',2);
end;

procedure CreateMsgTimeStamp(var MsgTimeStamp :longint);
{-甌Г�碎 萵��� ├ 皀�竕ォ ��硅 � �pガキ� � FTS-001 筮p��皀}
var
 dt:DateTime;
 w:word;

begin
 with dt do begin
   GetDate(year, month, day, w);
   GetTime(hour, min, sec, w);
   PackTime(dt,MsgTimeStamp);
 end;
end;

function Time2str(T:tTime):string;
{-├ tTime � 痰p��� `HH:MM'}
begin
 Time2str:=LeftPadCh(Long2str(T div MinInHour),'0',2)+':'+
           LeftPadCh(Long2str(T mod MinInHour),'0',2);
end;

function Str2Time(s:string):tTime;
{-��pア�� ├ 痰p��� � tTime}
var
 H,M:word;

begin
 Str2Time:=BadTime;

 if (Pos(':',s) <2) or (Length(s) <4) then exit;

 if not ( Str2word(Copy(s,1,pred(Pos(':',s))),H) and
          Str2word(Copy(s,succ(Pos(':',s)),2),M) ) then exit;

 if (H >23) or (M >59) then exit;


 Str2Time:=H*MinInHour+M;
end;

function Str2timePeriod(s:string;
                        var TPer:tTimePeriod):boolean;
{-���▲p皋p礇� ├ 痰p��� � 痰p礫矣p� timePeriod ┼� �p�痰� � time}
var
 s1:string;
 i:integer;
 b:byte;

begin
 FillChar(TPer,SizeOf(tTimePeriod),0);
 TPer.rDOW:=$60;

 if StLoCase(s) ='cm' then with TPer do begin   {�p磽��痺皰膈�}
  rtBegin:=0;
  rtEnd:=MaxTime;
  Str2timePeriod:=true;
  exit;
 end;

 s1:=Copy(s,1,pred(Pos('-',s)));
 Delete(s,1,Pos('-',s));

 Str2timePeriod:=false;

 with TPer do begin
  if Pos('.',s) <>0 then begin
    Val(Copy(s1,1,1), b, i);
    if b >6 then exit;
    rDOW:=b;
    Val(Copy(s,1,1), b, i);
    if b >6 then exit;
    rDOW:=rDOW or (b shl 4);
  end;

  if Pos(':',s1) <>0 then
   rtBegin:=Str2Time(Copy(s1,succ(Pos('.',s1)), 5))
  else
   rtBegin:=Str2Time(Copy(s,succ(Pos('.',s)), 5));

  rtEnd:=Str2Time(Copy(s,succ(Pos('.',s)), 5));

  if rtEnd =BadTime then rtEnd:=MaxTime;
 end;

 Str2timePeriod:=true;
end;

function TimePeriod2str(TPer:tTimePeriod):string;
{-├ ��p┏�� � 痰p���}
begin
 with TPer do
  TimePeriod2str:=Copy(sDOW[tDOW(rDOW and $F)],1,3)+'�'+
         Copy(sDOW[tDOW(rDOW shr 4)],1,3)+' / '+
         Time2str(rtBegin)+'-'+
         Time2str(rtEnd);
end;

function CurTime:tTime;
var
 H,M,w:word;

begin
 GetTime(H,M,w,w);
 CurTime:=H*MinInHour+M;
end;

function MatchTimePeriod(TPer:tTimePeriod):boolean;
{-��ゅ�え� �� 皀�. �pガ� � �������� � TPer}
var
 w,DoW:word;
 cT:tTime;

function MatchDay:boolean;
{-瓮��き闊�┤ ぅ�� √�え� � �p��ウ竄�� ├ TPer?}
begin
 with TPer do

 {�キ� ��p〓� �p���肓 > ��� ≒�p�� �p���肓 6.00:00-3.22:10}
 if (rDOW and $F) >(rDOW shr 4) then
  if (DoW <=(rDOW shr 4)) or (DoW >=(rDOW and $F)) then MatchDay:=true
  else MatchDay:=false
 else
 {�キ� ��p〓� �p���肓 <= ��� ≒�p�� �p���肓}
  if ((rDOW and $F) <=DoW) and                  {皀�.ぅ�� >= ���.��p┏�� _�_}
     ((rDOW shr 4) >=DoW) then MatchDay:=true   {皀�.ぅ�� <= ���.��p┏��}
  else MatchDay:=false;
end;

function MatchTime:boolean;
{-皀�竕ゥ �pガ� √�え� � �p��ウ竄�� ├ TPer?}
begin
 with TPer do

 {�甄� �pガ� ��p〓� �p���肓 > �pガキ� ≒�p�� �p���肓 21:00-03:00 }
 if rtBegin > rtEnd then
  if (cT <=rtEnd) or (cT >=rtBegin) then MatchTime:=true
  else MatchTime:=false
 else
  if (cT >=rtBegin) and (cT <=rtEnd) then MatchTime:=true
  else MatchTime:=false;
end;

begin
 {-���竍�ガ ぅ�� �イカ� � �pガ�}
 GetDate(w,w,w,DoW);
 cT:=CurTime;           { 皀�竕ゥ �pガ� � ※ぅ WORD (� �┃竄��)}

{ with TPer do
  if (rDOW shr 4) =0 then rDOW:=rDOW or $70;}

  MatchTimePeriod:=MatchDay and MatchTime;
end;

function MatchTimeArray(var TA:TimeArray):boolean;
{-瓷���� ��瘁│ ��p┏ぎ� p�｀硅 TA.TPer � 〓Бp���モ:
  TRUE==皀�.�pガ�/ぅ�� √�え� � �え� ├ ��p┏ぎ� }
var
 i:byte;


begin
 MatchTimeArray:=false;
 if TA.nTPer =0 then exit;

 for i:=1 to TA.nTPer do
   if MatchTimePeriod(TA.TPer[i]) then begin
     MatchTimeArray:=true;
     exit;
   end;
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

function Str2timeArray(s:string; var TA:TimeArray):boolean;
{-┃皀p���� �pガキ┤, p�Гカキ�襯 `,' ├ 痰p��� S � TA}
var
 z:byte;

begin
 TA.nTPer:=0;
 Str2timeArray:=false;

 if Length(s) <>0 then begin
  for z:=1 to WordCount(s,[',']) do with TA do begin
   if Str2TimePeriod(ExtractWord(z,s,[',']),TPer[succ(nTPer)]) then Inc(nTPer);

   if z =7 then begin
     Str2timeArray:= TA.nTPer <>0;
     exit;
   end;
  end;

  Str2timeArray:= TA.nTPer <>0;
 end;
end;

{$IFNDEF WINDOWS}
function ReadScanCode:word;
var
 sc:word;

begin
 while not KeyPressed do ReleaseTQ;
 asm
   mov ah,0
   int 16h
   mov sc,ax
 end;
 ReadScanCode:=sc;
end;
{$ENDIF}

end.
