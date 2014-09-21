{$O+,F+}
Unit UnixTime;

Interface

Uses Dos,
     TString_,
     Crc_All;

Function Date2Unix (FDate: LongInt): String;
Function Date2UnixHex (FDate: LongInt): String;
Function Now2UnixHex : String;
Function Unix2Date (S: String): Longint;
Function Unix2DateHex (S: String): Longint;
Procedure Unix2NormalDate (S: String; var Date : Str8; var Time : Str8);

Function Dos2unix(l:longint): longint;
Function Unix2dos(l:longint): longint;

Function Long2FullDate (FDate: LongInt): String;

Implementation
Uses
  aTime;

Const
   C1970 = 2440588;
   D0 =    1461;
   D1 =  146097;
   D2 = 1721119;

function LeadingZero(w : Word) : String;
var
  s : String;
begin
  Str(w:0,s);
  if Length(s) = 1 then
    s := '0' + s;
  LeadingZero := copy(s,length(S)-1,2);
end;

Procedure GregorianToJulianDN(Year, Month, Day : Word;
                                  Var JulianDN : LongInt);
Var
  Century,
  XYear    : LongInt;

Begin
  If Month <= 2 Then
  Begin
    Year := Pred(Year);
    Month := Month + 12;
  End;
  Month := Month - 3;
  Century := Year Div 100;
  XYear := Year Mod 100;
  Century := (Century * D1) Shr 2;
  XYear := (XYear * D0) Shr 2;
  JulianDN := ((((Month * 153) + 2) div 5) + Day) + D2 + XYear + Century;
End;

Procedure JulianDNToGregorian(JulianDN : LongInt;
                  var Year, Month, Day : Word);
var
  Temp,
  XYear   : LongInt;
  YYear,
  YMonth,
  YDay    : Integer;

Begin
  Temp := (((JulianDN - D2) Shl 2) - 1);
  XYear := (Temp Mod D1) Or 3;
  JulianDN := Temp Div D1;
  YYear := (XYear Div D0);
  Temp := ((((XYear Mod D0) + 4) Shr 2) * 5) - 3;
  YMonth := Temp Div 153;
  If YMonth >= 10 Then Begin
    YYear := YYear + 1;
    YMonth := YMonth - 12;
    End;
  YMonth := YMonth + 3;
  YDay := Temp Mod 153;
  YDay := (YDay + 5) Div 5;
  Year := YYear + (JulianDN * 100);
  Month := YMonth;
  Day := YDay;
End;

Function Date2Unix(FDate: Longint): String;
Var
   Dt          : DateTime;
   SecSpast,
   DateNum,
   DaySpast    : Longint;
   S           : String;
   dh          : LongInt;

Begin
   UnpackTime(FDate,Dt);
   GregorianToJulianDN(Dt.Year,Dt.Month,Dt.Day,DateNum);
   DaysPast := DateNum - c1970;
   SecsPast := DaysPast * 86400;
   dh:=Dt.Hour;
   SecsPast := SecsPast + LongInt(dh) * 3600 + word(Dt.Min) * 60 + Dt.Sec;
   S := '';
   While (SecsPast <> 0) And (Length(S) < 255) Do
   Begin
      S:= Chr((SecsPast And 7) + $30) + S;
      SecsPast := (SecsPast Shr 3)
   End;
   Date2Unix := '0' + S;
End;

Function Date2UnixHex(FDate: Longint): String;
Var
   Dt          : DateTime;
   TmpRes,
   SecsPast,
   DateNum,
   DaySpast    : Longint;
   dh          : LongInt;

Begin
   UnpackTime(FDate,Dt);
   GregorianToJulianDN(Dt.Year,Dt.Month,Dt.Day,DateNum);
   DaysPast := DateNum - c1970;
   SecsPast := DaysPast * 86400;
   dh:=Dt.Hour;
   SecsPast := SecsPast + LongInt(DH) * 3600 + Word(Dt.Min) * 60 + Dt.Sec;
   Date2UnixHex := HexLong(SecsPast);
End;

Function Dos2unix(l: Longint): longint;
Var
   Dt          : DateTime;
   TmpRes,
   SecsPast,
   DateNum,
   DaySpast    : Longint;
   dh          : LongInt;

Begin
   UnpackTime(l,Dt);
   GregorianToJulianDN(Dt.Year,Dt.Month,Dt.Day,DateNum);
   DaysPast := DateNum - c1970;
   SecsPast := DaysPast * 86400;
   dh:=Dt.Hour;
   Dos2unix:= SecsPast + LongInt(DH) * 3600 + Word(Dt.Min) * 60 + Dt.Sec;
End;

Function Now2UnixHex : String;
Var
  TTime     : DateTime;
  LTime     : LongInt;
  tmp       : word;

begin
  With TTime do
  begin
  GetTime(hour,min,sec,tmp);
  GetDate(year,month,day,tmp);
  end;

  PackTime(TTime,LTime);
  Now2UnixHex:=Date2UnixHex(LTime);
end;

Function Unix2Date(S: String): Longint;
Var
   Dt               : DateTime;
   SecsPast, DateNum: Longint;
   N                : Word;
Begin
   SecsPast := Longint(0);
   For N := 1 To Length(s) Do
   SecsPast := (SecsPast Shl 3) + Ord(S[N]) - $30;

   DateNum := (SecsPast Div 86400) + c1970;
   JulianDNToGregorian(DateNum,Dt.Year,Dt.Month,Dt.Day);
   SecsPast := SecsPast Mod 86400;
   Dt.Hour := SecsPast Div 3600;
   SecsPast := SecsPast Mod 3600;
   Dt.Min := SecsPast Div 60;
   Dt.Sec := SecsPast MOD 60;
   PackTime(Dt,SecsPast);
   Unix2Date := SecsPast;
End;

Function Unix2DateHex(S: String): Longint;
Var
   Dt               : DateTime;
   SecsPast, DateNum: Longint;
   N                : Word;
   tmp              : integer;
Begin
   SecsPast := Longint(0);
   Val('$'+S,SecsPast,tmp);
   DateNum := (SecsPast Div 86400) + c1970;
   JulianDNToGregorian(DateNum,Dt.Year,Dt.Month,Dt.Day);
   SecsPast := SecsPast Mod 86400;
   Dt.Hour := SecsPast Div 3600;
   SecsPast := SecsPast Mod 3600;
   Dt.Min := SecsPast Div 60;
   Dt.Sec := SecsPast MOD 60;
   PackTime(Dt,SecsPast);
   Unix2DateHex := SecsPast;
End;

Function Unix2dos(l:longint): Longint;
Var
   Dt               : DateTime;
   SecsPast, DateNum: Longint;
   N                : Word;
   tmp              : integer;

Begin
   DateNum := (l Div 86400) + c1970;
   JulianDNToGregorian(DateNum,Dt.Year,Dt.Month,Dt.Day);
   l := l Mod 86400;
   Dt.Hour := l Div 3600;
   l := l Mod 3600;
   Dt.Min := l Div 60;
   Dt.Sec := l Mod 60;
   PackTime(Dt,l);
   Unix2Dos := l;
End;

Procedure Unix2NormalDate (S: String; var Date : Str8; var Time : Str8);
Var
  TTime     : DateTime;
  LTime     : LongInt;

begin
  LTime:=Unix2DateHex(S);
  UnPackTime(LTime,TTime);
  Date := LeadingZero(TTime.Day)+'/'+
          LeadingZero(TTime.Month)+'/'+
          LeadingZero(TTime.Year);
  Time := LeadingZero(TTime.hour)+':'+
          LeadingZero(TTime.min)+':'+
          LeadingZero(TTime.sec);
end;

Function Long2FullDate (FDate: LongInt): String;
Var
  TTime     : DateTime;
begin
  UnPackTime(FDate,TTime);
  If (TTime.Month < 1) or (TTime.Month > 12) then
      TTime.Month := 1;
  Long2FullDate :=LeadingZero(TTime.Day)+'-'+
                  Months[TTime.Month]+'-'+
                  Long2Str(TTime.Year)+'  '+
                  LeadingZero(TTime.hour)+':'+
                  LeadingZero(TTime.min);
end;

End.
