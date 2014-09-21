
uses
 tstring_,
 dos;

const
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
 taddress=record
  zone,net,node,point:word;
 end;
 tRouteRule=(
  rrDirect,     {AkA NORMAL}
  rrDirectFile,
  rrCrash,      {crash for addresslist}
  rrHold,       {hold for addresslist}
  rrUnhold,     {except from hold list}
  rrImmediate,  {ignore work time}
  rrMailTo,     {route addresslist to target}
  rrMailFrom,   {route mail from addrlist to target}
  rrFileTo,     {files routing}
  rrDefault,
  rrError   {incorrect route command}
 );
 pRouteRec=^tRouteRec;
 tRouteRec=record
  NextRule:pRouteRec;
  Flavour:tRouteRule;
  ToAddr:tAddress;
  TimePeriod:tTimePeriod;
  RuleStr:string;
 end;

 tDOW=(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);

const
 sDOW:array[tDOW] of string[9] = (
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

var
 f:file;
 s:string;
 l:longint;
 dt:datetime;
 rule:tRouteRec;

procedure usage;
begin
 writeln('Syntax: Rdump <route.$^N>'#13#10);
 halt;
end;

function Addr2str(a:taddress):string;
begin
 with a do
  Addr2str:=Long2str(zone)+':'+Long2str(net)+'/'+
            Long2str(node)+'.'+Long2str(point);
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
 writeln(#13#10'Sf-Mail binary routing dumper'#13#10);
 if paramcount <>1 then usage;
 assign(f,paramstr(1));
 reset(f,1);
 blockread(f,s,4);
 writeln('Event Manager ver: ',char(ord(s[1])+48),
         char(ord(s[2])+48),char(ord(s[3])+48));
 blockread(f,l,4);
 unpacktime(l,dt);
 with dt do
  writeln('ASCII Route file date: ',day,'.',month,'.',year,
          '  ',hour,':',min,':',sec);
 writeln('        *********************************************************');
 repeat
  blockread(f,rule,sizeOf(trouterec));
  with rule do begin
   case flavour of
    rrDirect: write('direct for '+rulestr);
    rrDirectFile: write('direct files for '+rulestr);
    rrCrash: write('crash for '+rulestr);
    rrHold: write('hold for '+rulestr);
    rrUnhold: write('unhold for '+rulestr);
    rrImmediate: write('immediately for '+rulestr);
    rrMailTo: write('mail for '+rulestr+' route to '+addr2str(toaddr));
    rrMailFrom: write('mail from '+rulestr+' route to '+addr2str(toaddr));
    rrFileTo: write('files for '+rulestr+' route to '+addr2str(toaddr));
   end;
   writeln(', active @'+TimePeriod2str(TimePeriod));
  end;
 until eof(f);
 writeln('        *********************************************************');
 close(f);
end.
