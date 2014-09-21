{$I-}
PROGRAM SfM_LDC;

uses
 Dos,
 aEH,
 TpDate,
 tString_;

const
 PID:string[25]='Santa Fox "LastDayCutter"';
 VID:string[15]='ver 0.0.1/alpha';
 CID:string[51]='(C) Anton the Deinow (UNIVERSAL SOFTWARE Inc), 1995';
 Months:array[1..12] of string[3]=('Jan','Feb','Mar','Apr','May',
                          'Jun','Jul','Aug','Sep','Oct','Nov','Dec');

var
 oldHalt:pointer;
 s:string;
 inFname,outFname:PathStr;
 _done,
 _ok,
 killOut:boolean;
 fIn,fOut:text;
 tmpDate:DateTime;
 AnalDate:Date;

procedure Usage;
begin
 writeln(#13#10'Syntax:  SfM_LDC <logFname> [outFname]'#13#10);
 halt(255);
end;

{$F+}
procedure ShowError(s1,s2:string);
begin
 if Length(s2) <>0 then s1:=s1+' `'+s2+#39;
 writeln(#13#10+s1+^G);
end;

procedure MyHalt;
begin
 if TextRec(fIn).Mode <>fmClosed then close(fIn);
 if IoResult <>0 then;
 if TextRec(fOut).Mode <>fmClosed then close(fOut);
 if IoResult <>0 then;
 if killOut then erase(fOut);
 writeln('He-he-he.. All done! ;-)');
 ExitProc:=oldHalt;
 halt(ExitCode);
end;
{$F-}

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

begin
 writeln(#13#10+PID+'  '+VID+#13#10+CID);
 if (ParamCount <1) or (ParamCount >2) then Usage;
 { parse cmd line }
 inFname:=DefaultExtension(ParamStr(1),'log');
 outFname:=ParamStr(2);
 if Length(outFname) =0 then
  outFname:=ForceExtension(inFname,'ldc')
 else
  outFname:=DefaultExtension(outFname,'ldc');
 { init vars }
 ShowErrorPtr:=@ShowError;
 oldHalt:=ExitProc;
 ExitProc:=@MyHalt;
 killOut:=true;
 TextRec(fIn).Mode:=fmClosed;
 TextRec(fOut).Mode:=fmClosed;
 _done:=false;
 _ok:=false;
 AnalDate:=IncDate(Today,-1,0,0);
 { open files }
 assign(fIn,inFname);
 reset(fIn);
 CheckError(inFname,true);
 assign(fOut,outFname);
 rewrite(fOut);
 CheckError(outFname,true);
 { parse log }
 killOut:=false;
 repeat
  readln(fIn,s);
  if Pos('ÄÄÄÄÄÄÄÄÄ',s) =1 then with tmpDate do begin
    FillChar(tmpDate,SizeOf(DateTime),0);
    Str2word(ExtractWord(2,s,[' ']),day);
    month:=WhatMonth(ExtractWord(3,s,[' ']));
    Str2word(ExtractWord(4,s,[' ',',']),year);
    if _Ok then begin
      if AnalDate <>DMYtoDate(day,month,year) then exit
    end
    else BEGIN
      _Ok:=AnalDate =DMYtoDate(day,month,year);
      if _Ok then writeln(s);
    END;
  end;
  if _Ok then writeln(fOut,s);
 until EOF(fIn);
end.
