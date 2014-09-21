(*** Sf-Mail internal log-knife ***)

{$X+,I-,O+,F+}

UNIT Sf_Lc;

INTERFACE

procedure Cut_Log;

IMPLEMENTATION

uses
 Config,
 Tstring_,
 Dos,
 aTime,
 UnixTime,
 MsgXs,
 WriteLog,
 EmStruct,
 TpMemChk,
 adLang;

type
 lcError=(lceNotEnoughMem,lceCantOpenIn,lceCantOpenOut,lceCantRead,
     lceCantWrite);

procedure Cut_Log;
var
 NewLogName:PathStr;
 NewBuf:pHugeBuf;
 bHugeSize,
 bNewSize:word;
 fOld,fNew:text;
 _ok:boolean;
 s:string;
 o:integer;

procedure lcErrorProc(lce:lcError);
begin
 case lce of
   {lceNotEnoughMem: s:='NOT ENOUGH MEMORY FOR CACHE';}
   lceCantOpenIn: s:=TranslateStr(emCantOpen,pCfgRec^.LogDir);
   lceCantOpenOut: s:=TranslateStr(emCantOpen,NewLogName);
   lceCantRead: s:=TranslateStr(emReadError,pCfgRec^.LogDir);
   lceCantWrite: s:=TranslateStr(emWriteError,NewLogName);
 end;
 LogWrite(0,s,ld_Screen);
 if TextRec(fOld).Mode <>fmClosed then close(fOld);
 o:=IoResult;
 if TextRec(fNew).Mode <>fmClosed then close(fNew);
 o:=IoResult;
 if HugeBuf <>nil then FreeMem(HugeBuf,bHugeSize);
 if NewBuf <>nil then FreeMem(NewBuf,bNewSize);
 HugeBuf:=nil;
 NewBuf:=nil;
 WaitMsg;
end;

procedure CheckTearLine;
var
 dt:DateTime;
 l:longint;
 _l:longint;

begin
 if Pos('ÄÄÄÄÄÄÄÄÄ',s) =1 then with dt do begin
   FillChar(dt,SizeOf(DateTime),0);
   Min:=1;
   Str2word(ExtractWord(2,s,[' ']),Day);
   Month:=WhatMonth(ExtractWord(3,s,[' ']));
   Str2word(copy(s,Pos(',',s)-4,4),Year);
   PackTime(dt,l);
   CreateDosTimeStamp(_l);
   if ((Dos2unix(_l) div (MinInDay*SecInMin))-
      (Dos2unix(l) div (MinInDay*SecInMin))) <CurEventPtr^.StrOfs then BEGIN
    _ok:=true;
    LogWrite(imWritingNewLog,'',ld_Screen or ld_LastLn);
    writeln(fNew,'þCutted on '+MsgDateStamp+
            ' by Sf-Mail internal log-knife'+#13#10);
   END;
 end;
end;

begin
 HugeBuf:=nil;
 NewBuf:=nil;
 TextRec(fOld).Mode:=fmClosed;
 TextRec(fNew).Mode:=fmClosed;
 { alloc cache buffers }
 bHugeSize:=MaxAvail div 2;
 if bHugeSize >HugeBufSiz then
  bHugeSize:=HugeBufSiz;
 GetMem(HugeBuf,bHugeSize);

 bNewSize:=MaxAvail;
 if bNewSize >HugeBufSiz then
  bNewSize:=HugeBufSiz;
 GetMem(NewBuf,bNewSize);

 {lcErrorProc(lceNotEnoughMem);}

 assign(fOld,pCfgRec^.LogDir);
 SetTextBuf(fOld,HugeBuf^,bHugeSize);
 reset(fOld);
 if IoResult <>0 then begin
   lcErrorProc(lceCantOpenIn);
   exit;
 end;
 NewLogName:=JustPathName(pCfgRec^.LogDir);
 if Length(NewLogName) <>0 then
   NewLogName:=AddBackSlash(NewLogName)+'$log$.swp';
 assign(fNew,NewLogName);
 SetTextBuf(fNew,NewBuf^,bNewSize);
 rewrite(fNew);
 if IoResult <>0 then begin
   lcErrorProc(lceCantOpenOut);
   exit;
 end;

 _ok:=false;

 LogWrite(imCutLogStart,'',ld_Screen);
 LogWrite(imCutLog,Long2str(CurEventPtr^.StrOfs),ld_Screen);
 LogWrite(imCutLogEnd,'',ld_Screen);

 repeat
   readln(fOld,s);
   if IoResult <>0 then begin
     lcErrorProc(lceCantRead);
     exit;
   end;
   if not _ok then CheckTearLine;
   if _ok then writeln(fNew,s);
   if IoResult <>0 then begin
     lcErrorProc(lceCantWrite);
     exit;
   end;
 until EOF(fOld);

 close(fOld);
 close(fNew);
 erase(fOld);
 rename(fNew,pCfgRec^.LogDir);

 if IoResult <>0 then
  LogWrite(emIoError,'',ld_All);

 { dispose cache }
 FreeMem(HugeBuf,bHugeSize);
 FreeMem(NewBuf,bNewSize);

 WaitMsg;
end;

end.
