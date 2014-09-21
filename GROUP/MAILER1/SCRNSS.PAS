unit ScrnSS;
interface
type
  onedigit = array [1..5] of byte;


const
  LastSaver       : boolean = false;
  ssComaColor     = $07;
  ssBackColor     = $08;
  ssForeColor     = $0A;
  SSDigits        : array [0..9] of onedigit =
                    ((1,5,0,5,1), {0}
                     (0,4,0,4,0), {1}
                     (1,4,1,3,1), {2}
                     (1,4,1,4,1), {3}
                     (0,5,1,4,0), {4}
                     (1,3,1,4,1), {5}
                     (1,3,1,5,1), {6}
                     (1,4,0,4,0), {7}
                     (1,5,1,5,1), {8}
                     (1,5,1,4,1));{9}

var
  ClockX     : byte;
  ClockY     : byte;

Procedure ScreenSaver;
Procedure RestScreen;
Procedure RefreshScreen;

implementation
uses SFInclud,
     Date,
     Config,
     TPWindow,
     TPCRT,
     keyb;

Var
  SSWin       : WindowPtr;
  SSLast      : byte;

Procedure ScreenSaver;
begin
  if (pCfgRec^.SysFlags and mscPollKbd) <> 0 then begin
    LastKeyPressed:=0;
    exit;
  end;
  If (ScreenSave) or (SSWin <> Nil) then exit;
  if not SaveWindow(1, 1, 80, ScreenHeight, true, SSWin) then exit;
  ScreenSave:=true;
  TextAttr:=0;
  ClrScr;
  SSLast:=0;
  RefreshScreen;
end;

procedure DrawDigit(digit: byte; Y,X :byte);
var
  i  : byte;
begin
  if digit<10 then
  For i:= 1 to 5 do begin
    Case SSDigits[digit,i] of
    0 : FastWrite(' ÄÄÄ ',y+i,x,ssBackColor);
    1 : FastWrite(' ÍÍÍ ',y+i,x,ssForeColor);
    2 : FastWrite('³   ³',y+i,x,ssBackColor);
    3 : begin
         FastWrite('Ý',y+i,x,ssForeColor);
         FastWrite('³',y+i,x+4,ssBackColor);
        end;
    4 : begin
         FastWrite('³',y+i,x,ssBackColor);
         FastWrite('Þ',y+i,x+4,ssForeColor);
        end;
    5 : FastWrite('Ý   Þ',y+i,x,ssForeColor);
    end;
  end else begin
    if digit<11 then begin
      FastWrite(#7,y+2,x+2,ssComaColor);
      FastWrite(#7,y+4,x+2,ssComaColor);
    end else begin
      FastWrite(' ',y+2,x+2,ssComaColor);
      FastWrite(' ',y+4,x+2,ssComaColor);
    end;
  end;
end;

Procedure RefreshScreen;
Var
    i   : byte;
begin
  If not ScreenSave then exit;
  GetDate_Time;
  If SSLast=0 then begin
    ClockX:=Random(49)+1;
    ClockY:=Random(19)+1;
    SSLast:=11;
    ClrScr;
  end else
    Dec(SSLast);
  for i:= 1 to 5 do
   if Time_[i] in ['0'..'9'] then
     DrawDigit(byte(Time_[i])-$30,ClockY,ClockX+pred(i)*6)
   else begin
     if (SSLast mod 2) = 0 then
       DrawDigit(10,ClockY,ClockX+pred(i)*6)
     else
       DrawDigit(11,ClockY,ClockX+pred(i)*6);
   end;
end;

Procedure RestScreen;
begin
If (not ScreenSave) or (SSWin=nil) then exit;
RestoreWindow(1, 1, 80, ScreenHeight, true, SSWin);
SSWin:=nil;
ScreenSave:=false;
ShowTime;
end;

end.