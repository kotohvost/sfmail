{$V-}
uses
 tstring_,
 unixtime,
 dos;

const
 { event modes }
 em_Period  =$01;    {% periodical}
 em_StartUp =$02;    {^ must be executed at startup}
 em_Critical=$04;    {! critical event}
 MinInHour = 60;        {минут в часу}

type
 tTime=word;

 tTimePeriod=record
  rtBegin,      {начало и}
  rtEnd: tTime;  {конец действия пpавила}
  rDOW: byte;   {пеpвый и последний день действия пpавила ─
                 мл. 4 бита от rDOW : day begin
                 ст. 4 бита от rDOW : day end}
 end;

 {- типы событий -}
 tEventType=(
  evExit,       {Exit with specified errorlevel}
  evExec,       {Execute xternal process}
  evSet,        {Set system parametr}
  evRePack,     {RePack netmail -- all or for specified address}
  evPack,       {---""---}
  evDrop,       {удалить письма от сф-pобота и пеpепаковать}
  evPoll,       {Create POLL msg}
  evCutLog,     {Run internal log-knife}
  evNone        {Empty event}
 );

 {- события -}
 tEventRec=record
  NextEvent:pointer;      {0..3}
  EventType:tEventType;   {4}
  EventMode:byte;         {5  see em_XXXX above}
  Executed:boolean;       {6}
  TimePeriod:tTimePeriod; {7..0B}
  Period:word;            {0C..0D  for periodical events}
  LastExec:longint;       {0E..11 unixtime of last execution}
  StrOfs:longint;         {12..15}
 end;

 tDOW=(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);

const
 sDOW:array[tDOW] of string[9] = (
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

var
 f:file;
 s,s1,s2:string;
 l:longint;
 dt:datetime;
 Event:tEventRec;

procedure usage;
begin
 writeln('Syntax: Rdump <route.$^N>'#13#10);
 halt;
end;

function Time2str(T:tTime):string;
{-из tTime в стpоку `HH:MM'}
begin
 Time2str:=LeftPadCh(Long2str(T div MinInHour),'0',2)+':'+
           LeftPadCh(Long2str(T mod MinInHour),'0',2);
end;

function TimePeriod2str(TPer:tTimePeriod):string;
{-из пеpиода в стpоку}
begin
 with TPer do
  TimePeriod2str:=Copy(sDOW[tDOW(rDOW and $F)],1,3)+'─'+
         Copy(sDOW[tDOW(rDOW shr 4)],1,3)+' / '+
         Time2str(rtBegin)+'-'+
         Time2str(rtEnd);
end;

begin
 writeln(#13#10'Sf-Mail binary events dumper'#13#10);
 if paramcount <>1 then usage;
 assign(f,paramstr(1));
 reset(f,1);
 blockread(f,s,4);
 writeln('Event Manager ver: ',char(ord(s[1])+48),
         char(ord(s[2])+48),char(ord(s[3])+48));
 blockread(f,l,4);
 unpacktime(l,dt);
 with dt do
  writeln('ASCII Events file date: ',day,'.',month,'.',year,
          '  ',hour,':',min,':',sec);
 writeln('        *********************************************************');
 repeat
  blockread(f,Event,SizeOf(tEventRec));
  s:='';
  with Event do begin
   case EventType of
    evExit: s:='Exit';
    evExec: s:='Execute';
    evSet: s:='Set';
    evRePack,
    evPack: s:='Repack';
    evDrop: s:='Drop';
    evPoll: s:='Poll';
    evCutLog: s:='Cut log at '+Long2str(StrOfs)+'days';
   end;
   if Executed then
    s:=s+' (*)';
   s1:='';
   if EventMode and em_Critical <>0 then
    s1:='[!]';
   if EventMode and em_Period <>0 then
    if Length(s1) <>0 then
     Insert('%',s1,pred(Length(s1)))
    else
     s1:='[%]';
   if EventMode and em_StartUp <>0 then
    if Length(s1) <>0 then
     Insert('^',s1,pred(Length(s1)))
    else
     s1:='[^]';
   if Length(s1) <>0 then
    s:=s+' '+s1;
   if EventType <>evCutLog then
    s:=s+' str offset='+Long2str(StrOfs);
   Unix2normalDate(HexL(LastExec),s1,s2);
   writeln(s+' last exec on '+s1+'@'+s2+' ($'+HexL(LastExec)+')');
   writeln('Active at ['+TimePeriod2str(TimePeriod)+']');
   writeln(CharStr('-',30));
  end;
 until EOF(f);
 writeln('        *********************************************************');
 close(f);
end.
