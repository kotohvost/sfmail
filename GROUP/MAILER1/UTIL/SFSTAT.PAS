{$X+,I-}

PROGRAM Sfstat;

uses
 Dos,
 TpCrt,
 tString_,
 TpDos,
 TpDate,
 AEH,
 Cfg,
 SfM_API;

const
 PID='Sf-Mail`s Statistics Generator (SFstat)';
 VID='ver 0.0.2/alpha';
 CID='(C) Anton Deinow, Santa Fox Team, 1995-95';

 graphFname='sfsgraph.rep';
 traffFname='sfstraff.rep';
 MaxAddr=1000;
 MaxMailer=50;
 tF='hh:mm:ss';
 dF='dd-mm-yyyy';

 repGen =$01;
 repDL  =$02;
 repUL  =$04;
 repTime=$08;
 repCPS =$10;
 repLMD =$20;
 repMU  =$40;

type
 pCache=^tCache;
 tCache=array[1..57344] of byte;
 {
   total sessions
   ÃÄinbound
   ³ ÃÄaborted
   ³ ÀÄnormal
   ÀÄoutbound
     ÃÄaborted
     ÀÄnormal
 }
 tSessSum=record
   Fail,
   Success:word;
 end;

 tSumInfo=record
   totalSess:word;
   totalIn,
   totalOut:tSessSum;
   totalBBS:word;
   totalSent,
   totalRcvd:longint;
   totalOnLine:Time;
 end;

 { parser states }
 tParserState=(
  psIdle,
  psInCall,
  psBeginInSess,
  psOutCall,
  psBeginOutSess,
  psInEMSI,
  psOutEMSI,
  psEndInSess,
  psEndOutSess,
  psReceive,
  psSend
 );

 tAddrInfo=record
  Addr:tAddress;
  OnLine:Time;
  OutCalls,
  InCalls:word;
  BytesSent,
  BytesRcvd:longint;
  AverageCPS:integer;
 end;
 tAllAddrInfo=array[1..MaxAddr] of tAddrInfo;

 tMailer=record
  mName:string[46];
  mNum:word;
 end;
 tMailerUsage=array[1..MaxMailer] of tMailer;

 tSortBy=(sbUL,sbDL,sbTime,sbCPS,sbLMD);

var
 OldHalt:pointer;
 _ps:tParserState;
 inCache:pCache;
 fIn:text;
 inFname:PathStr;
 fOut:text;
 AnalDate:Date;
 tmpDate:DateTime;
 w:word;
 logLn:word;
 SumInfo:tSumInfo;
 s,s1:string;
 AllAddrInfo:^tAllAddrInfo;
 TotalAddr:word;
 CurAddr:word;
 MailerUsage:^tMailerUsage;
 TotalMailer:byte;
 l:longint;
 tmp4D:tAddress;
 tim:Time;
 _Ok:boolean;
 _LastDay:boolean;
 Reports:byte;
 SortBy:tSortBy;

procedure Usage;
begin
 writeln(#10#10'SFstat-U-Invalid command line'#13#10#10+
         'Syntax:'#13#10#10+
         '   IN: SFstat <sfmail_log> [switches]'#13#10+
         '       possible switches are:'#13#10+
         '         /L - last day statistic only'#13#10+
         '         /S - summary statistic');
 writeln('         /D - top ten downloaders'#13#10+
         '         /U - top ten uploaders'#13#10+
         '         /T - top ten on-liners');
 writeln('         /C - top ten CPSers'#13#10+
         '         /M - MustDie list (tm)'#13#10+
         '         /G - mailers usage'#13#10+
         '         /A - all of above');
 writeln('  OUT: sfsgraph.rep  - total usage graph'#13#10+
         '       sfstraff.rep  - traffic report'#10#10);
 halt(255); {invalid cmd-line parameters}
end;

{$F+}
procedure ShowError(s1,s2:string);
begin
 if Length(s2) <>0 then s1:=s1+': '+s2;
 TextAttr:=$0C;
 writeln(s1+^G);
 TextAttr:=$07;
end;

procedure MyHalt;
begin
 if TextRec(fIn).Mode <>fmClosed then close(fIn);
 if IoResult <>0 then;
 if TextRec(fOut).Mode <>fmClosed then close(fOut);
 if IoResult <>0 then;
 { shut-down }

 TextAttr:=$0F;
 write(#13#10'-Done!');
 TextAttr:=$07;
 writeln(#10);
 ExitProc:=OldHalt;
 halt(ExitCode);
end;
{$F-}

function Percent(sum,num:word):real;
begin
 if num =0 then Percent:=0
 else Percent:=(num/sum)*100.0;
end;

procedure FindAddr;
begin
 for CurAddr:=1 to TotalAddr do with AllAddrInfo^[CurAddr] do
   if CompWordStruct(tmp4D,Addr,SizeOf(tAddress)) =Equal then exit;
 { not found }
 if TotalAddr =MaxAddr then begin
   ShowError('Unable to hold more than 1000 addresses','');
   halt(254);
 end;
 {Inc(TotalAddr);
 CurAddr:=TotalAddr;}
 CurAddr:=1;
 while (CurAddr <=TotalAddr) and
       (CompWordStruct(AllAddrInfo^[CurAddr].Addr,tmp4D,SizeOf(tAddress)) <>Greater) do
  Inc(CurAddr);
 if CurAddr <=TotalAddr then
   Move(AllAddrInfo^[CurAddr],AllAddrInfo^[succ(CurAddr)],SizeOf(tAddrInfo)*succ(TotalAddr-CurAddr));
 Inc(TotalAddr);

 FillChar(AllAddrInfo^[CurAddr],SizeOf(tAddrInfo),0);
 Move(tmp4D,AllAddrInfo^[CurAddr].Addr,SizeOf(tAddress));
end;

procedure AddMailer;
var
 i:byte;

begin
 s1:=Trim(copy(s,Pos('ing: ',s)+5,100));
 if Pos('ver',S1)<> 0 then
   s1:=copy(s1,1,pos('ver',S1)-1)
 else
   S1:=ExtractWord(1,S1,[' ']);
   
 for i:=1 to TotalMailer do
   if StLoCase(s1) =StLoCase(MailerUsage^[i].mName) then begin
    Inc(MailerUsage^[i].mNum);
    exit;
   end;
 if TotalMailer <MaxMailer then begin
  Inc(TotalMailer);
  MailerUsage^[TotalMailer].mName:=s1;
  MailerUsage^[TotalMailer].mNum:=1;
 end;
end;

procedure ParseLogStr;
begin
 case _ps of
  psIdle: if Pos('Outgoing',s) <>0 then
           _ps:=psOutCall
          else
           if Pos('Incoming',s) <>0 then
            _ps:=psInCall;
  psInCall: if Pos('CONNECT',s) <>0 then
             _ps:=psBeginInSess
            else
             _ps:=psIdle;
  psOutCall: if Pos('CONNECT',s) <>0 then
              _ps:=psBeginOutSess
             else
              _ps:=psIdle;
  psBeginInSess: if Pos('Station:',s) <>0 then begin
                  _ps:=psInEMSI;
                  Inc(SumInfo.totalSess);
                 end
                 else begin
                  if Pos('Human caller',s) <>0 then Inc(SumInfo.totalBBS);
                  _ps:=psIdle;
                 end;
  psBeginOutSess: if Pos('Station:',s) <>0 then begin
                   _ps:=psOutEMSI;
                   Inc(SumInfo.totalSess);
                  end
                  else
                   _ps:=psIdle;
  psInEMSI: if Pos('Using:',s) <>0 then begin
             if MailerUsage <>nil then AddMailer;
             _ps:=psEndInSess
            end
            else
             if Pos('Address:',s) <>0 then begin
              Str2addr(ExtractWord(3,s,[' ']),tmp4D);
              FindAddr;
              Inc(AllAddrInfo^[CurAddr].InCalls);
             end;
             {else
              _ps:=psIdle;}
  psOutEMSI: if Pos('Using:',s) <>0 then begin
              if MailerUsage <>nil then AddMailer;
              _ps:=psEndOutSess;
             end
             else
              if Pos('Address:',s) <>0 then begin
               Str2addr(ExtractWord(3,s,[' ']),tmp4D);
               FindAddr;
               Inc(AllAddrInfo^[CurAddr].OutCalls);
              end;
              {else
               _ps:=psIdle;}
  psEndInSess: if Pos('Session aborted',s) <>0 then
                Inc(SumInfo.totalIn.Fail)
               else
                if Pos('Session completed',s) <>0 then
                 Inc(SumInfo.totalIn.Success)
                else
                 if Pos('Traffic:',s) <>0 then with AllAddrInfo^[CurAddr] do begin
                  _ps:=psIdle;
                  Str2long(ExtractWord(1,ExtractWord(4,s,[' ']),['/']),l);
                  Inc(BytesSent,l);
                  Str2long(ExtractWord(2,ExtractWord(4,s,[' ']),['/',',']),l);
                  Inc(BytesRcvd,l);
                  tim:=TimeStringToTime(tF,ExtractWord(6,s,[' ']));
                  Inc(OnLine,tim);
                 end
                 else
                  if Pos('PostSession',s) <>0 then begin
                   _ps:=psIdle;
                   Inc(SumInfo.totalIn.Fail);
                  end;
  psEndOutSess: if Pos('Session aborted',s) <>0 then
                 Inc(SumInfo.totalOut.Fail)
                else
                 if Pos('Session completed',s) <>0 then
                  Inc(SumInfo.totalOut.Success)
                 else
                  if Pos('Traffic:',s) <>0 then with AllAddrInfo^[CurAddr] do begin
                   _ps:=psIdle;
                   Str2long(ExtractWord(1,ExtractWord(4,s,[' ']),['/']),l);
                   Inc(BytesSent,l);
                   Str2long(ExtractWord(2,ExtractWord(4,s,[' ']),['/',',']),l);
                   Inc(BytesRcvd,l);
                   tim:=TimeStringToTime(tF,ExtractWord(6,s,[' ']));
                   Inc(OnLine,tim);
                  end
                  else
                   if Pos('PostSession',s) <>0 then begin
                    _ps:=psIdle;
                    Inc(SumInfo.totalOut.Fail);
                   end;
  {psReceive:
  psSend:}
 end;
end;

procedure Rep_General;
begin
 if Reports and repGen <>0 then begin
  writeln(#13#10'ùGenerating summary report');
  writeln(fOut,'Summary link statistics for '+s+':'#13#10+
   'ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄ¿'#13#10+
   '³     Address      ³  On-Line ³  Out ³  In  ³   Sent  ³   Rcvd  ³  CPS  ³');
  writeln(fOut,'ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ´');
 end;
 with SumInfo do begin
  for CurAddr:=1 to TotalAddr do with AllAddrInfo^[CurAddr] do begin
   AverageCPS:=round((BytesSent+BytesRcvd)/OnLine);
   if Reports and repGen <>0 then begin
    writeln(fOut,'³ ',_4D2str(Addr):16,' ³ ',TimeToTimeString(tF,OnLine),
            ' ³ ',OutCalls:4,' ³ ',InCalls:4,' ³ ',
            vInBestForm(BytesSent):7,' ³ ',vInBestForm(BytesRcvd):7,
            ' ³ ',AverageCPS:5,' ³');
    Inc(totalSent,BytesSent);
    Inc(totalRcvd,BytesRcvd);
    Inc(totalOnLine,OnLine);
   end;
  end;
  if Reports and repGen <>0 then begin
   writeln(fOut,'ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ´'#13#10+
                '³ ',TotalAddr:16,' ³ ',TimeToTimeString(tF,totalOnLine),' ³ ',
                totalOut.Fail+totalOut.Success:4,' ³ ',
                totalIn.Fail+totalIn.Success:4,' ³ ',
                vInBestForm(totalSent):7,' ³ ',vInBestForm(totalRcvd):7,
                ' ³ ',(totalSent+totalRcvd)/totalOnLine:5:0,' ³');
   writeln(fOut,'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÙ');
  end;
 end;
end;

procedure Rep_TopTen;
var
 TopTen:array[1..10] of word;
 ttN:byte;

function MoreThan(tt,addr:word):boolean;
{ true if insertion is need }
begin
 case SortBy of
  sbUL: MoreThan:=AllAddrInfo^[TopTen[tt]].BytesRcvd <AllAddrInfo^[addr].BytesRcvd;
  sbDL: MoreThan:=AllAddrInfo^[TopTen[tt]].BytesSent <AllAddrInfo^[addr].BytesSent;
  sbTime: MoreThan:=AllAddrInfo^[TopTen[tt]].OnLine <AllAddrInfo^[addr].OnLine;
  sbCPS: MoreThan:=AllAddrInfo^[TopTen[tt]].AverageCPS <AllAddrInfo^[addr].AverageCPS;
  sbLMD: MoreThan:=(AllAddrInfo^[TopTen[tt]].AverageCPS >AllAddrInfo^[addr].AverageCPS) and
                   (AllAddrInfo^[addr].AverageCPS <>0);
 end;
end;

procedure SortTopTen;
var
 i:byte;

begin
 for i:=1 to ttN do
   if MoreThan(i,w) then begin
     if ttN <10 then begin
       Inc(ttN);
       Move(TopTen[i],TopTen[i+1],(ttN-i)*2);
     end
     else
       Move(TopTen[i],TopTen[i+1],(ttN-i)*2);
     TopTen[i]:=w;
     exit;
   end;
 if ttN <10 then begin
  Inc(ttN);
  TopTen[ttN]:=w;
 end;
end;

begin
 if TotalAddr =0 then exit;
 case SortBy of
  sbUL: s1:='TopTen Uploaders';
  sbDL: s1:='TopTen Downloaders';
  sbCPS: s1:='TopTen CPSers';
  sbTime: s1:='TopTen On-Liners';
  sbLMD: s1:='LamerzMustDie list (tm)';
 end;
 writeln(#13#10'ùGenerating '+s1+' report');
 writeln(fOut,#13#10+s1+' for '+s);
 ttN:=1;
 TopTen[1]:=1;
 { sorting..}
 for w:=2 to TotalAddr do SortTopTen;
 { writing..}
 writeln(fOut,'ÚÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄ¿'#13#10+
              '³Pos³     Address      ³  On-Line ³  Out ³  In  ³   Sent  ³   Rcvd  ³  CPS  ³');
 writeln(fOut,'ÃÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ´');
 for w:=1 to ttN do with AllAddrInfo^[TopTen[w]] do
  writeln(fOut,'³ ',w:2,'³ ',_4D2str(Addr):16,' ³ ',TimeToTimeString(tF,OnLine),
          ' ³ ',OutCalls:4,' ³ ',InCalls:4,' ³ ',
          vInBestForm(BytesSent):7,' ³ ',vInBestForm(BytesRcvd):7,
          ' ³ ',(BytesSent+BytesRcvd)/OnLine:5:0,' ³');
 writeln(fOut,'ÀÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÙ');
end;

procedure WriteStat;
begin
 { output collected info }
 with SumInfo do begin
  writeln(#13,logLn,Pad(' total lines parsed of '+JustFilename(inFname),74));
  writeln('Total sessions  : ',totalSess);
  writeln('  total inbound : ',totalIn.Fail+totalIn.Success);
  writeln('          fails : ',totalIn.Fail,' (',
          Percent(totalIn.Fail+totalIn.Success,totalIn.Fail):3:1,'%)');
  writeln('        success : ',totalIn.Success,' (',
          Percent(totalIn.Fail+totalIn.Success,totalIn.Success):3:1,'%)');
  writeln(' total outbound : ',totalOut.Fail+totalOut.Success);
  writeln('          fails : ',totalOut.Fail,' (',
          Percent(totalOut.Fail+totalOut.Success,totalOut.Fail):3:1,'%)');
  writeln('        success : ',totalOut.Success,' (',
          Percent(totalOut.Fail+totalOut.Success,totalOut.Success):3:1,'%)');
  writeln('Human           : ',totalBBS);
 end;
 { show summary info about all links }
 assign(fOut,traffFname);
 rewrite(fOut);
 if _LastDay then s:=DateToDateString(dF,AnalDate)
 else s:='all log data';
 WRITELN('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
 Rep_General;
 if (Reports and repDL) <>0 then begin
  SortBy:=sbDL;
  Rep_TopTen;
 end;
 if (Reports and repUL) <>0 then begin
  SortBy:=sbUL;
  Rep_TopTen;
 end;
 if (Reports and repTime) <>0 then begin
  SortBy:=sbTime;
  Rep_TopTen;
 end;
 if (Reports and repCPS) <>0 then begin
  SortBy:=sbCPS;
  Rep_TopTen;
 end;
 if (Reports and repLMD) <>0 then begin
  SortBy:=sbLMD;
  Rep_TopTen;
 end;
 if ((Reports and repMU) <>0) and (TotalMailer <>0) then begin
  writeln(fOut,#13#10'Mailers usage for '+s+#13#10+
   'ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿');
  for w:=1 to TotalMailer do with MailerUsage^[w] do
   writeln(fOut,'³ '+PadCh(mName,'.',51),mNum:4,' ³');
  writeln(fOut,'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ');
 end;
end;

procedure ParseLog;
begin
 repeat
   readln(fIn,s);
   Inc(logLn);
   write(#13+inFname+' - ',logLn);
   s:=Trim(s);
   if Length(s) <>0 then begin
     if _LastDay then
      if Pos('ÄÄÄÄÄÄÄÄÄÄ ',s) =1 then with tmpDate do begin
        FillChar(tmpDate,SizeOf(DateTime),0);
        Str2word(ExtractWord(2,s,[' ']),day);
        month:=WhatMonth(ExtractWord(3,s,[' ']));
        Str2word(ExtractWord(4,s,[' ',',']),year);
        if _Ok then begin
         if AnalDate <>DMYtoDate(day,month,year) then exit
        end
        else
         _Ok:=AnalDate =DMYtoDate(day,month,year);
      end;
     if _Ok then ParseLogStr;
   end;
 until EOF(fIn);
end;

procedure ParseCmdLine;
begin
 if ParamCount =0 then Usage;
 inFname:=ParamStr(1);
 _LastDay:=false;
 _Ok:=true;
 Reports:=0;
 for w:=2 to ParamCount do begin
  s:=StLoCase(ParamStr(w));
  if not (s[1] in ['-','/']) then Usage;
  case s[2] of
   'l': begin
         _LastDay:=true;
         _Ok:=false;
        end;
   's': Reports:=Reports or repGen;
   'c': Reports:=Reports or repCPS;
   'd': Reports:=Reports or repDL;
   'u': Reports:=Reports or repUL;
   't': Reports:=Reports or repTime;
   'm': Reports:=Reports or repLMD;
   'g': Reports:=Reports or repMU;
   'a': Reports:=repGen or repCPS or repDL or repUL or repTime or
                 repLMD or repMU;
  else Usage;
  end;
 end;
end;

procedure Initialize;
begin
 TextRec(fIn).Mode:=fmClosed;
 TextRec(fOut).Mode:=fmClosed;
 OldHalt:=ExitProc;
 ExitProc:=@MyHalt;
 GetMem(AllAddrInfo,SizeOf(tAllAddrInfo));
 FillChar(AllAddrInfo^,SizeOf(tAllAddrInfo),0);
 TotalAddr:=0;
 _ps:=psIdle;
 logLn:=0;
 if Reports =0 then Reports:=repGen;
 TotalMailer:=0;
 if Reports and repMU <>0 then
  GetMem(MailerUsage,SizeOf(tMailerUsage))
 else
  MailerUsage:=nil;
 ShowErrorPtr:=@ShowError;
 FillChar(SumInfo,SizeOf(tSumInfo),0);
 GetMem(inCache,SizeOf(tCache));
 FillChar(tmpDate,SizeOf(DateTime),0);
 AnalDate:=IncDate(Today,-1,0,0);
end;

begin
 { intro }
 TextAttr:=$07;
 ClrScr;
 TextAttr:=$0E;
 writeln(PID+'  '+VID);
 TextAttr:=$0F;
 writeln(CID);
 TextAttr:=$07;
 { parse cmd line }
 ParseCmdLine;
 { init internal structures }
 Initialize;
 assign(fIn,inFname);
 SetTextBuf(fIn,inCache^);
 reset(fIn);
 CheckError(inFname,true);
 writeln;
 ParseLog;
 close(fIn);
 { show statistics }
 WriteStat;
 { clearing memory }
 FreeMem(AllAddrInfo,SizeOf(tAllAddrInfo));
 FreeMem(inCache,SizeOf(tCache));
 if MailerUsage <>nil then FreeMem(MailerUsage,SizeOf(tMailerUsage));
end.
