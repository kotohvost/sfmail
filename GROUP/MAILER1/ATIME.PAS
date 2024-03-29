{$X+}
unit aTime;

INTERFACE
uses
 Dos,
 UnixTime,
 Config,
 Tstring_;

type
 tDOW=(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);

const
 sDOW:array[tDOW] of string[9] = (
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

 Months :Array[1..12] Of String[3] = ('Jan','Feb','Mar','Apr','May',
                          'Jun','Jul','Aug','Sep','Oct','Nov','Dec');

 MinTime = 0;           {= 00:00 }
 MaxTime = 1439;        {= 23:59 }
 BadTime = $FFFF;

 HrsInDay = 24;         {�ᮢ � ��⪠�}
 MinInDay = 1440;       {����� � ��⪠�}
 MinInHour = 60;        {����� � ���}

 SecInMin = 60;         {ᥪ㭤 � �����}

function Str2Time(s:string):tTime;
{-��p���� �� ��p��� � tTime}

function Time2str(T:tTime):string;
{-�� tTime � ��p��� `HH:MM'}

function FullTime2str(T:DateTime):string;
{-�� DateTime � ��p��� `HH:MM'}

function FullDate2Str(T:DateTime; Separ:char):string;
{-�� DateTime � ��p��� `DD.MM.YY'}

function CurTime:tTime;
{-⥪�饥 �p��� (H:M)}

function CurUnixTime:longint;
{-⥪�饥 �p��� � UNIX-�p���}

function CurTimeSec:longint;
{-⥪.�p��� (H:M:sec)}

procedure CreateDosTimeStamp(var DtS:longint);
{-⥪�饥 �p��� � ��� � ���������� �p��� DOS}

function UTCstr:string;
{-��୥� ᬥ饭�� �� UTC � �ଠ� (UTC) }

function TimeInc(T:tTime; H,M:word):tTime;
{-㢥����� �p��� T �� H �ᮢ, M �����}

function Str2timePeriod(s:string; var TPer:tTimePeriod):boolean;
{-�����p�p㥬 �� ��p��� � ��p���p� timePeriod}

procedure Txy2TimePeriod(Txy:string; var TPer:tTimePeriod);
{-��p���� ������⮢��� 䫠�� Txy � ��p��� �p�����}

function Str2TimeArray(s:string; var TA:TimeArray):boolean;
{-���p���� �p������, p��������� `,' �� ��p��� S � TA}

procedure OHstr2timeArray(s:string; var TA:TimeArray);
{-���p���� � �p��� `OH:D.HHMM-D.HHMM/D.HHMM-D.HHMM' � TA}

function TimePeriod2str(TPer:tTimePeriod):string;
{-�� ��p���� � ��p���}

{function Min2rtEnd(var TPer:tTimePeriod):word;}
{-᪮�쪮 ����� ��⠫��� �� ����砭�� ���p����}

function MatchTimePeriod(TPer:tTimePeriod):boolean;
{-���室�� �� ⥪. �p��� � �������� � TPer}

function MatchTimeArray(var TA:TimeArray):boolean;
{-᪠��� ���ᨢ ��p����� p����� TA.TPer � ����p�頥�:
  TRUE==⥪.�p���/���� �室�� � ���� �� ��p����� }

(*** Date routines ***)

function IsLeapYear(Year:integer):boolean;
{-Return True if Year is a leap year}

function DaysInMonth(Month,Year:integer):integer;
{-Return the number of days in the specified month of a given year}

function DayNumber(Dy,Mnth,Yr:integer):integer;
{ ����p ��� �� ��砫� ���� }

function TodayDate:tDate;
{-⥪��� ���}

function WhatMonth(s:string):word;
{-��p��� ����p ����� �� ��� �����}

IMPLEMENTATION

const
 ucTxyTime:array[ord('A')..ord('X')] of tTime=(
 (* TA -> TX *)
        0,      {00:00}
        60,     {01:00}
        120,    {02:00}
        180,    {03:00}
        240,    {04:00}
        300,    {05:00}
        360,    {06:00}
        420,    {07:00}
        480,    {08:00}
        540,    {09:00}
        600,    {10:00}
        660,    {11:00}
        720,    {12:00}
        780,    {13:00}
        840,    {14:00}
        900,    {15:00}
        960,    {16:00}
        1020,   {17:00}
        1080,   {18:00}
        1140,   {19:00}
        1200,   {20:00}
        1260,   {21:00}
        1320,   {22:00}
        1380);  {23:00}

 lcTxyTime:array[ord('a')..ord('x')] of tTime=(
 (* Ta -> Tx *)
        30,     {00:00}
        90,     {01:00}
        150,    {02:30}
        210,    {03:30}
        270,    {04:30}
        330,    {05:30}
        390,    {06:30}
        450,    {07:30}
        510,    {08:30}
        570,    {09:30}
        630,    {10:30}
        690,    {11:30}
        750,    {12:30}
        810,    {13:30}
        870,    {14:30}
        930,    {15:30}
        990,    {16:30}
        1050,   {17:30}
        1110,   {18:30}
        1170,   {19:30}
        1230,   {20:30}
        1290,   {21:30}
        1350,   {22:30}
        1410);  {23:30}

(*** ��H���� ***)

function IsLeapYear(Year:integer):boolean;
{-Return True if Year is a leap year}
begin
 IsLeapYear:=(Year mod 4 =0) and (Year mod 4000 <>0) and
             ((Year mod 100 <>0) or (Year mod 400 =0));
end;

function DaysInMonth(Month,Year:integer):integer;
{-Return the number of days in the specified month of a given year}
begin
 case Month of
   1,3,5,7,8,10,12: DaysInMonth:=31;
    4,6,9,11: DaysInMonth:=30;
    2: DaysInMonth:=28+ord(IsLeapYear(Year));
 else
   DaysInMonth:=0;
 end;
end;

function DayNumber(Dy,Mnth,Yr:integer):integer;
{ ����p ��� �� ��砫� ���� }
var
 nDay:integer;
 i:word;

begin
 nDay:=0;
 for i:=1 to pred(mnth) do
   Inc(nDay,DaysInMonth(i,yr));
 Inc(nDay,dy);
 DayNumber:=nDay;
end;

function CurTime:tTime;
var
 H,M,w:word;

begin
 GetTime(H,M,w,w);
 CurTime:=H*MinInHour+M;
end;

function CurUnixTime:longint;
{-⥪�饥 �p��� � UNIX-�p���}
var
 t:longint;

begin
 CreateDosTimeStamp(t);
 CurUnixTime:=Dos2unix(t);
end;

function CurTimeSec:longint;
{-⥪.�p��� (H:M:sec)}
var
 w,sec:word;
 T:longint;

begin
 T:=CurTime;
 GetTime(w,w,sec,w);
 CurTimeSec:=T*60+sec;
end;

function UTCstr:string;
{-��୥� ᬥ饭�� �� UTC � �ଠ� (UTC) }
begin
 with pCfgRec^ do
  if _UTC_ >=0 then
   UTCstr:='(+'+Long2str(_UTC_)+')'
  else
   UTCstr:='('+Long2str(_UTC_)+')';
end;

procedure CreateDosTimeStamp(var DtS:longint);
{-�p��� � ��� � ���������� �p��� DOS}

var
 dt:DateTime;
 w:word;

begin
 with dt do begin
   GetDate(year, month, day, w);
   GetTime(hour, min, sec, w);
   PackTime(dt,DtS);
 end;
end;

function Time2str(T:tTime):string;
{-�� tTime � ��p��� `HH:MM'}
begin
 Time2str:=LeftPadCh(Long2str(T div MinInHour),'0',2)+':'+
           LeftPadCh(Long2str(T mod MinInHour),'0',2);
end;

function FullTime2str(T:DateTime):string;
{-�� DateTime � ��p��� `HH:MM'}
begin
  FullTime2Str:=LeftPadCh(Long2str(T.Hour),'0',2)+':'+
                LeftPadCh(Long2str(T.Min),'0',2);
end;

function FullDate2str(T:DateTime; Separ:char):string;
{-�� DateTime � ��p��� `DD.MM.YY'}
begin
  FullDate2Str:=LeftPadCh(Long2str(T.Day),'0',2)+Separ+
                LeftPadCh(Long2str(T.Month),'0',2)+Separ+
                LeftPadCh(Long2str(T.Year mod 100),'0',2);
end;

function TimeInc(T:tTime; H,M:word):tTime;
{-㢥����� �p��� T �� H �ᮢ, M �����}
begin
 H:=H mod HrsInDay;

 Inc(T,(H*MinInHour+M));

 TimeInc:=T mod MinInDay;
end;

function Str2Time(s:string):tTime;
{-��p���� �� ��p��� � tTime}
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
{-�����p�p㥬 �� ��p��� � ��p���p� timePeriod ��� �p��� � time}
var
 s1:string;
 i:integer;
 b:byte;

begin
 FillChar(TPer,SizeOf(tTimePeriod),0);
 TPer.rDOW:=$60;

 if Length(s) =0 then s:='cm';

 if StLoCase(s) ='cm' then with TPer do begin   {�p㣫����筮 00:00-23:59}
  rtBegin:=0;
  rtEnd:=MaxTime;
  Str2timePeriod:=true;
  exit;
 end;

 s1:=Copy(s,1,pred(Pos('-',s)));  { s1 - ��砫� }
 Delete(s,1,Pos('-',s));          { s - �����   }

 Str2timePeriod:=false;

 with TPer do begin
  if Pos('.',s) <>0 then begin
    val(copy(s1,1,1),b,i);
    if b=7 then b:=0;
    if b >6 then exit;
    rDOW:=b;
    val(copy(s,1,1),b,i);
    if b=7 then b:=0;
    if b >6 then exit;
    if Length(s1) =0 then begin
      rDOW:=b;
      if b =6 then b:=0
      else Inc(b);
    end;
    rDOW:=rDOW or (b shl 4);
  end;

  if Pos(':',s1) <>0 then
   rtBegin:=Str2Time(copy(s1,succ(Pos('.',s1)), 5))
  else
   rtBegin:=Str2Time(copy(s,succ(Pos('.',s)), 5));

  rtEnd:=Str2Time(copy(s,succ(Pos('.',s)), 5));

  if rtEnd =BadTime then rtEnd:=MaxTime
  else
   if Length(s1) =0 then
    if rtEnd =0 then
     rtEnd:=MaxTime
    else
     Dec(rtEnd);
 end;

 Str2timePeriod:=true;
end;

procedure Txy2TimePeriod(Txy:string; var TPer:tTimePeriod);
{-��p���� ������⮢��� 䫠�� Txy � ��p��� �p�����}
begin
 with TPer do begin
  rDOW:=$60;

  if Txy[2] in ['A'..'X'] then
   rtBegin:=TimeInc(ucTxyTime[ord(Txy[2])],pCfgRec^._UTC_,0)
  else
   rtBegin:=TimeInc(lcTxyTime[ord(Txy[2])],pCfgRec^._UTC_,0);

  if Txy[3] in ['A'..'X'] then
   rtEnd:=TimeInc(ucTxyTime[ord(Txy[3])],pCfgRec^._UTC_,0)
  else
   rtEnd:=TimeInc(lcTxyTime[ord(Txy[3])],pCfgRec^._UTC_,0);
 end; {*WITH TPer*}
end;

function TimePeriod2str(TPer:tTimePeriod):string;
{-�� ��p���� � ��p���}
begin
 with TPer do
  TimePeriod2str:=Copy(sDOW[tDOW(rDOW and $F)],1,3)+'�'+
         Copy(sDOW[tDOW(rDOW shr 4)],1,3)+' / '+
         Time2str(rtBegin)+'-'+
         Time2str(rtEnd);
end;

function MatchTimePeriod(TPer:tTimePeriod):boolean;
{-���室�� �� ⥪. �p��� � �������� � TPer}
var
 {w,DoW:word;}
 cT:tTime;

function MatchDay:boolean;
{-ᥣ����譨� ���� �室�� � �p�����⮪ �� TPer?}
begin
 with TPer do
 {���� ��p��� �p����� > ��� ��p�� �p����� 6.00:00-3.22:10}
 if (rDOW and $F) >(rDOW shr 4) then
  if (curDoW <=(rDOW shr 4)) or (curDoW >=(rDOW and $F)) then MatchDay:=true
  else MatchDay:=false
 else
 {���� ��p��� �p����� <= ��� ��p�� �p�����}
  if ((rDOW and $F) <=curDoW) and                  {⥪.���� >= ���.��p���� _�_}
     ((rDOW shr 4) >=curDoW) then MatchDay:=true   {⥪.���� <= ���.��p����}
  else MatchDay:=false;
end;

function MatchTime:boolean;
{-⥪�饥 �p��� �室�� � �p�����⮪ �� TPer?}
begin
 with TPer do

 {�᫨ �p��� ��p��� �p����� > �p����� ��p�� �p����� 21:00-03:00 }
 if rtBegin > rtEnd then
  if (cT <=rtEnd) or (cT >=rtBegin) then MatchTime:=true
  else MatchTime:=false
 else
  if (cT >=rtBegin) and (cT <=rtEnd) then MatchTime:=true
  else MatchTime:=false;
end;

begin
 {-����砥� ���� ������ � �p���}
 {GetDate(w,w,w,DoW);}
 cT:=CurTime;           { ⥪�饥 �p��� � ���� WORD (� ������)}

{ with TPer do
  if (rDOW shr 4) =0 then rDOW:=rDOW or $70;}

  MatchTimePeriod:=MatchDay and MatchTime;
end;

function MatchTimeArray(var TA:TimeArray):boolean;
{-᪠��� ���ᨢ ��p����� p����� TA.TPer � ����p�頥�:
  TRUE==⥪.�p���/���� �室�� � ���� �� ��p����� }
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

function Str2timeArray(s:string; var TA:TimeArray):boolean;
{-���p���� �p������, p��������� `,' �� ��p��� S � TA}
var
 z:byte;

begin
 TA.nTPer:=0;
 Str2timeArray:=false;

 if Length(s) <>0 then begin
  for z:=1 to WordCount(s,[',']) do with TA do begin
   if Str2TimePeriod(ExtractWord(z,s,[',']),TPer[succ(nTPer)]) then
     Inc(nTPer);
   if z =7 then begin
     Str2timeArray:= TA.nTPer <>0;
     exit;
   end;
  end;
  Str2timeArray:= TA.nTPer <>0;
 end;
end;

procedure OHstr2timeArray(s:string; var TA:TimeArray);
{-���p���� � �p��� `OH:D.HHMM-D.HHMM/D.HHMM-D.HHMM' � TA}
var
 z:byte;
 s_:string;

begin
 TA.nTPer:=0;
 Delete(s,1,3);
 for z:=1 to WordCount(s,['/']) do with TA do begin
   s_:=ExtractWord(z,s,['/']);
   if s_[1] >'0' then begin
     s_[1]:=pred(s_[1]);
     if s_[8] ='0' then
       s_[0]:=#0
     else
       s_[8]:=pred(s_[8]);
   end
   else  { day ==0 }
    if s_[8] <>'0' then
      s_[0]:=#0
    else
      s_[8]:='6';
   if (Length(s_) <>0) and
      Str2TimePeriod(copy(s_,1,4)+':'+copy(s_,5,7)+':'+copy(s_,12,2),
                     TPer[succ(nTPer)]) then
     Inc(nTPer);
   if z =7 then
     exit;
 end;
end;

(*** Date routines ***)

function TodayDate:tDate;
{-⥪��� ���}
var
 dt:DateTime;
 d:tDate;

begin
 GetDate(dt.Year,dt.Month,dt.Day, dt.Sec);
 FillChar(dt.Hour,6,0);
 PackTime(dt,d);
 TodayDate:=d;
end;

function WhatMonth(s:string):word;
var
 i:word;

begin
 for i:=1 to 12 do if StLoCase(s) =StLoCase(Months[i]) then begin
        WhatMonth:=i;
        exit;
 end;
end;

end.
