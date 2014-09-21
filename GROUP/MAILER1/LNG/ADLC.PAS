(*
                      advanced Language Engine
                     (c) Anton the Deinow, 1996
*)

{$I-}

program ad_LanguageCompiler;

uses
{$IFDEF OS2}
 Use32,
{$ENDIF}
 AEH,
 adLang,
 Dos,
 tString_;

const
 PID:string[31]='ADvanced Language File compiler';
 VID:string[19]='ver 0.0.1/alpha0328';
 CID:string[36]='Copyright (C) Anton the Deinow, 1996';

(* src str format:

 hex_code,msg_name=msg_string

 If first char is not in ['1'..'9'] then this string will be
 recognized as comment and when ignored.
*)

var
 fIn:text;
 fOut:file;
 InFname,
 OutFname:PathStr;
 Hdr:tLngHdr;
 oldHalt:pointer;
 NotCompleted:boolean;
 s:string;

procedure Usage;
begin
 writeln('Syntax: adLC <source[.lc]> [destenation[.lng]]'#10);
 halt;
end;

{$F+}
procedure MyHalt;
begin
 if TextRec(fIn).Mode <>fmClosed then close(fIn);
 if FileRec(fOut).Mode <>fmClosed then close(fOut);

 if NotCompleted then begin
  erase(fOut);
  if IoResult <>0 then;
  writeln(#10'Any error occured, output file killed.');
 end
 else
  writeln(#10'All done ok, be happy.');

 writeln;

 if LngIdx <>nil then Dispose(LngIdx);
 if LngArray <>nil then Dispose(LngArray);

 ExitProc:=oldHalt;
 halt(ExitCode);
end;

procedure SayError(s1,s2:string);
begin
 if Length(s2) <>0 then
  s1:=s1+' '+s2;
 writeln(#10+s1+#10^G);
end;
{$F-}

begin
 writeln(#13#10+PID+' '+VID+#13#10+CID+#10);
 if ParamCount =0 then usage;
 InFname:=DefaultExtension(ParamStr(1),'lc');
 OutFname:=ParamStr(2);
 if Length(OutFname) =0 then
  OutFname:=ForceExtension(InFname,'lng')
 else
  OutFname:=DefaultExtension(OutFname,'lng');

 TextRec(fIn).Mode:=fmClosed;
 FileRec(fOut).Mode:=fmClosed;
 oldHalt:=ExitProc;
 ExitProc:=@MyHalt;
 ShowErrorPtr:=@SayError;
 NotCompleted:=true;

 assign(fIn,InFname);
 reset(fIn);
 CheckError(InFname,true);
 assign(fOut,OutFname);
 rewrite(fOut,1);
 CheckError(OutFname,true);

 New(LngIdx);
 FillChar(LngIdx^,SizeOf(tLngIdx),0);
 New(LngArray);
 FillChar(LngArray^,SizeOf(tLngArray),0);

 writeln('Compiling: '+InFname+' -> '+OutFname+#10);
 repeat
  readln(fIn,s);
  s:=TrimLead(s);
  if (Length(s) <>0) and (s[1] in ['1'..'9']) then begin
   write(#13+Pad('word: '+ExtractWord(2,s,[',','=']),60));
   Inc(LngIdxSiz);
   Inc(LngArraySiz);
   Str2word(ExtractWord(1,s,[',']),LngIdx^[LngIdxSiz].MsgCode);
   LngIdx^[LngIdxSiz].MsgOfs:=LngArraySiz;
   s:=copy(s,succ(Pos('=',s)),255);
   Move(s[0],LngArray^[LngArraySiz],Length(s)+1);
   Inc(LngArraySiz,Length(s));
  end;
 until EOF(fIn);

 Hdr.LngSign:=DefLngSign;
 Hdr.TotalMsgs:=LngIdxSiz;
 Hdr.LngArraySiz:=LngArraySiz;

 writeln(#13+Pad('',60)+#13'Storing results');
 BlockWrite(fOut,Hdr,SizeOf(tLngHdr));
 BlockWrite(fOut,LngIdx^,LngIdxSiz*SizeOf(tLngIdxRec));
 BlockWrite(fOut,LngArray^,LngArraySiz);

 NotCompleted:=false;
end.
