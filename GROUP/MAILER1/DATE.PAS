Unit Date;

interface
Uses Dos;

Const
  ChangeTime : byte = 0;
  NullTime   : boolean = true;
Var
  OldTime    : byte;
  BegH       : word;
  BegM       : word;
  BegS       : word;
  RemotDate  : DateTime;
  ReMotLong  : LongInt absolute RemotDate;

procedure ShowTime;
procedure StoreSessTime;
procedure ShowSessTime;
procedure ClearSessTime;
procedure ShowScanTime(tim : word);
procedure ShowDialTime(tim : word);
procedure GetDate_Time;

implementation
Uses TPCrt,
     SFInclud,
     aTime,
     TString_,
     Config;


function LeadingZero(w : Word) : String;
var
  s : String;
begin
  Str(w:0,s);
  if Length(s) = 1 then
    s := '0' + s;
  LeadingZero := s;
end;

procedure GetDate_Time;
begin
  GetTime(hours,minuts,seconds,hund);
  GetDate(year,month,day,dow);
  If NullTime then begin
    ChangeTime:=0;
    OldTime:=Seconds;
    NullTime:=false;
  end else begin
    If Seconds<OldTime then
      ChangeTime:=ChangeTime+Seconds+60-OldTime else
      ChangeTime:=ChangeTime+Seconds-OldTime;
    OldTime:=Seconds;
  end;
  Date_:= LeadingZero(day)+'-'+
          Months[month]+'-'+
          LeadingZero(year mod 100);
  ShortTime:=LeadingZero(hours)+':'+
          LeadingZero(minuts);
  Time_:= ShortTime +':'+
          LeadingZero(seconds);
end;


procedure ShowTime;
begin
  GetDate_Time;
  If ScreenSave then exit;
  FastWrite(Date_,3,9,pCfgRec^.SfMailColors[Info_Color]);
  FastWrite(Time_,3,55,pCfgRec^.SfMailColors[Info_Color]);
end;

procedure StoreSessTime;
begin
 FastWrite('   On-Line:',3,25,pCfgRec^.SfMailColors[Date_Color]);
  GetDate_Time;
  BegH:=Hours;
  BegM:=Minuts;
  BegS:=Seconds;
end;

procedure ClearSessTime;
begin
  FastWrite('   Log Echo',3,25,pCfgRec^.SfMailColors[Header_Color]);
  FastWrite(pad('',8),3,37,pCfgRec^.SfMailColors[Info_Color]);
end;

procedure ShowSessTime;
Var
  SesTime : String [8];
  CurH    : LongInt;
  CurM    : LongInt;
  CurS    : LongInt;
begin
  CurH:=LongInt(Hours)-BegH;
  CurM:=LongInt(Minuts)-BegM;
  CurS:=LongInt(Seconds)-BegS;
  while CurS<0 do begin
    Inc(CurS,60);
    Dec(CurM);
  end;
  while CurM<0 do begin
    Inc(CurM,60);
    Dec(CurH);
  end;
  while CurH<0 do Inc(CurH,24);
  while CurH<0 do Inc(CurH,24);
  SesTime:=LeadingZero(CurH)+':'+
          LeadingZero(CurM)+':'+
          LeadingZero(CurS);
  FastWrite(SesTime,3,37,pCfgRec^.SfMailColors[Info_Color]);
end;

procedure ShowScanTime(tim : word);
  var
   tstr : string[5];
begin
   if tim>3600 then tim:=0;
   tstr := LeadingZero(tim div 60)+':'+
           LeadingZero(tim mod 60);
   If ScreenSave then exit;
   FastWrite(tstr,ScreenHeight-2,44,pCfgRec^.SfMailColors[Info_Color]);
end;

procedure ShowDialTime(tim : word);
  var
   tstr : string[5];
begin
   if tim>3600 then tim:=0;
   tstr := LeadingZero(tim div 60)+':'+
           LeadingZero(tim mod 60);
   FastCenter(tstr,4,pCfgRec^.SfMailColors[Session_Info]);
end;

end.