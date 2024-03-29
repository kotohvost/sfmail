
unit DT;

INTERFACE

uses
 Dos,
 tString_;

type
 tDOW=(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);

const
 sDOW:array[tDOW] of string[9] = (
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

 MinTime = 0;           {= 00:00 }
 MaxTime = 1439;        {= 23:59 }
 BadTime = $FFFF;

 HrsInDay = 24;         {�ᮢ � ��⪠�}
 MinInDay = 1440;       {����� � ��⪠�}
 MinInHour = 60;        {����� � ���}

 SecInMin = 60;         {ᥪ㭤 � �����}

type
 tTime=word;

 tTimePeriod=record
  rtBegin,      {��砫� �}
  rtEnd: tTime;  {����� ����⢨� �p�����}
  rDOW: byte;   {��p�� � ��᫥���� ���� ����⢨� �p����� �
                 ��. 4 ��� �� rDOW : day begin
                 ��. 4 ��� �� rDOW : day end}
 end;

 TimeArray=record
  nTPer:byte;
  TPer:array[1..7] of tTimePeriod;
 end;

function Time2str(T:tTime):string;
{-�� tTime � ��p��� `HH:MM'}
function Str2Time(s:string):tTime;
{-��p���� �� ��p��� � tTime}
function Str2timePeriod(s:string;
                        var TPer:tTimePeriod):boolean;
{-�����p�p㥬 �� ��p��� � ��p���p� timePeriod ��� �p��� � time}
function TimePeriod2str(TPer:tTimePeriod):string;
{-�� ��p���� � ��p���}
function MatchTimePeriod(TPer:tTimePeriod):boolean;
{-���室�� �� ⥪. �p��� � �������� � TPer}
function MatchTimeArray(var TA:TimeArray):boolean;
{-᪠��� ���ᨢ ��p����� p����� TA.TPer � ����p�頥�:
  TRUE==⥪.�p���/���� �室�� � ���� �� ��p����� }
function Str2timeArray(s:string; var TA:TimeArray):boolean;
{-���p���� �p������, p��������� `,' �� ��p��� S � TA}

IMPLEMENTATION

function Time2str(T:tTime):string;
{-�� tTime � ��p��� `HH:MM'}
begin
 Time2str:=LeftPadCh(Long2str(T div MinInHour),'0',2)+':'+
           LeftPadCh(Long2str(T mod MinInHour),'0',2);
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

 if StLoCase(s) ='cm' then with TPer do begin   {�p㣫����筮}
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
{-�� ��p���� � ��p���}
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
{-���室�� �� ⥪. �p��� � �������� � TPer}
var
 w,DoW:word;
 cT:tTime;

function MatchDay:boolean;
{-ᥣ����譨� ���� �室�� � �p�����⮪ �� TPer?}
begin
 with TPer do

 {���� ��p��� �p����� > ��� ��p�� �p����� 6.00:00-3.22:10}
 if (rDOW and $F) >(rDOW shr 4) then
  if (DoW <=(rDOW shr 4)) or (DoW >=(rDOW and $F)) then MatchDay:=true
  else MatchDay:=false
 else
 {���� ��p��� �p����� <= ��� ��p�� �p�����}
  if ((rDOW and $F) <=DoW) and                  {⥪.���� >= ���.��p���� _�_}
     ((rDOW shr 4) >=DoW) then MatchDay:=true   {⥪.���� <= ���.��p����}
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
 GetDate(w,w,w,DoW);
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
   if Str2TimePeriod(ExtractWord(z,s,[',']),TPer[succ(nTPer)]) then Inc(nTPer);

   if z =7 then begin
     Str2timeArray:= TA.nTPer <>0;
     exit;
   end;
  end;

  Str2timeArray:= TA.nTPer <>0;
 end;
end;

end.
