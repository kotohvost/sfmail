{$X+,I-}

UNIT SfMpMain;

INTERFACE

uses
 {$IFDEF VIRTUALPASCAL}
 Use32,
 adDos2,
 {$ELSE}
 TpDos,
 TpMemChk,
 {$ENDIF}
 Dos,
 TpCrt,
 tString_,
 AEH,
 SfMp_Var,
 SfMp_Cfg,
 SfMp_Log,
 SfMp_Pkr,
 SfMp_Ndl;

procedure SfMp_Init;
procedure SfMp_Run;
procedure SfMp_Done;

IMPLEMENTATION

procedure Usage;
begin
 {$IFDEF OS2}
 writeln('Syntax: SFMP2 [Switches]'#13#10#10+
         'Switches:'#13#10+
         ' /? or /h - this help screen'#13#10+
         ' /c   - configuration file'#13#10+
         ' /l   - log filename'#13#10);
 {$ELSE}
 writeln('Syntax: SFMP [Switches]'#13#10#10+
         'Switches:'#13#10+
         ' /? or /h - this help screen'#13#10+
         ' /c   - configuration file'#13#10+
         ' /l   - log filename'#13#10);
 {$ENDIF}
 halt(255);
end;

{$F+}
procedure MyHalt;
begin
 if NeedUpdateEvents then
  SaveEvents;
 Log_End;
 ExitProc:=oldHalt;
 writeln;
 halt(ExitCode);
end;
{$F-}

procedure ParseCmdLine;
var
 i:byte;
 s:string;

begin
 for i:=1 to ParamCount do begin
  s:=ParamStr(i);
  if (s[1] ='-') or (s[1] ='/') then begin
   case LoCase(s[2]) of
    'c': begin
          CfgFname:=copy(s,3,255);
          if Length(CfgFname) =0 then
           InternalError(ieNotDefined,'Configuration filename',true);
         end;
    'l': begin
          LogFname:=copy(s,3,255);
          if Length(LogFname) =0 then
           InternalError(ieNotDefined,'Log filename',true);
         end;
    'h','?': Usage;
   end;
  end
  else
   InternalError(ieBadCmdLine,s,true);
 end;
end;

procedure CheckSavedEvents;
var
 f:file;
 sr:SearchRec;
 Ev:tEventRec;

begin
 RecompileEvents:=false;
 EvFname:=ForceExtension(CfgFname,'evt');
 {$I+} FindFirst(EvFname,Archive,sr); {$I-}
 if DosError <>0 then begin
  RecompileEvents:=true;
  Log_Write(lfDebug,'Events file can`t be found',lwtBoth);
 end
 else begin
  assign(f,EvFname);
  reset(f,1);
  BlockRead(f,EvFhdr,SizeOf(tEventFhdr));
  {$I+} FindFirst(CfgFname,Archive,sr); {$I-}
  if (DosError <>0) or
     (EvFhdr.EventsId <>EvId) or
     (sr.Time <>EvFhdr.CfgFtime) then begin
   close(f);
   Log_Write(lfAttention,'Event file doesn`t match config',lwtBoth);
   RecompileEvents:=true;
   exit;
  end;
  EvFhdr.CfgFtime:=sr.Time;
  Log_Write(lfNormal,'Loading events from '+EvFname,lwtBoth);
  { читаем события из бинарного файла }
  while not EOF(f) do begin
   BlockRead(f,Ev,SizeOf(tEventRec));
   LinkEvent(Ev);
  end;
  close(f);
  if EvHead =nil then
   Log_Write(lfDebug,'no events defined',lwtBoth);
 end;
end;

procedure DoActiveEvents;
var
 p:pEventRec;
 d,m,y,w:word;
 l:longint;
 pth:PathStr;
 s:string;
 ft:text;

begin
 p:=EvHead;
 while p <>nil do with p^ do begin
  if MatchTimePeriod(When) then begin
   GetDate(y,m,d, w);
   if (DMYtoDate(d,m,y) <>LastExecDate) then begin
    Log_Write(lfNormal,'Execute event '+EventName[EventType],lwtBoth);
    LastExecDate:=DMYtoDate(d,m,y);
    {---}
    case EventType of
     evFReq: begin
              Path4addr(TargetAddr,pth);
              MkAllDir(JustPathName(pth));
              pth:=pth+'.req';
              assign(ft,pth);
              append(ft);
              w:=IoResult;
              if w =2 then begin
               rewrite(ft);
               Log_Write(lfCreate,'Creating FileRequest to '+_4D2str(TargetAddr)+
                         ' ('+JustFilename(pth)+')',lwtBoth);
              end
              else
               if w <>0 then
                ForceDosError(w,pth,true)
               else
                Log_Write(lfAppend,'Appending FileRequest for '+_4D2str(TargetAddr)+
                          ' ('+JustFilename(pth)+')',lwtBoth);
              for w:=1 to WordCount(EvStr,[',']) do begin
               s:=ExtractWord(w,EvStr,[',']);
               if Pos('|',s) <>0 then begin
                writeln(ft,ExtractWord(1,s,['|'])+' !'+
                        ExtractWord(2,s,['|']));
                Log_Write(lfAppend,' freq '+ExtractWord(1,s,['|'])+' (pwd '+
                          ExtractWord(2,s,['|'])+')',lwtBoth);
               end
               else begin
                writeln(ft,s);
                Log_Write(lfAppend,' freq '+s,lwtBoth);
               end;
               CheckError(pth,true);
              end;
              close(ft);
              if IoResult <>0 then;
             end;
     evSend: begin {send (attach) files via *.?lo}
              Path4addr(TargetAddr,pth);
              MkAllDir(JustPathName(pth));
              pth:=pth+'.'+FlavourTo+'lo';
              assign(ft,pth);
              append(ft);
              w:=IoResult;
              if w =2 then begin
               rewrite(ft);
               Log_Write(lfCreate,'Creating FileAttach to '+
                         _4D2str(TargetAddr)+' ('+JustFilename(pth)+')',
                         lwtBoth);
              end
              else
               if w <>0 then
                ForceDosError(w,pth,true)
               else
                Log_Write(lfAppend,'Appending FileAttach for '+
                          _4D2str(TargetAddr)+' ('+JustFilename(pth)+')',
                          lwtBoth);
              for w:=1 to WordCount(EvStr,[',']) do begin
               s:=ExtractWord(w,EvStr,[',']);
               writeln(ft,s);
               if s[1] ='^' then begin
                Delete(s,1,1);
                s:=s+' [KFS]';
               end
               else
                if s[1] ='#' then begin
                 Delete(s,1,1);
                 s:=s+' [TFS]';
                end
                else
                 s:=s+' [NORM]';
               Log_Write(lfNormal,' send '+s,lwtBoth);
              end;
              close(ft);
              if IoResult <>0 then;
             end;
     evPost: begin  {send text file via *.?ut}
              Path4addr(TargetAddr,pth);
              MkAllDir(JustPathname(pth));
              pth:=pth+'.'+FlavourTo+'ut';
              for w:=1 to WordCount(EvStr,[',']) do begin
               s:=ExtractWord(w,EvStr,[',']);
               if ExistFile(s) then with MsgCB do begin
                { файл, который бум постить, найден }
                AddonMsgInfo:='Post '+s;
                assign(fMsg,s);
                reset(fMsg,1);
                CheckError(s,true);
                if not ExistFile(pth) then begin
                 CreatePkt(TargetAddr,pth);
                 Log_Write(lfCreate,'Creating MailPacket to '+
                           _4D2str(TargetAddr)+' ('+JustFilename(pth)+')',
                           lwtBoth);
                end;
                {else
                 Log_Write(lfAppend,'Appending MailPacket to '+
                           _4D2str(TargetAddr)+' ('+JustFilename(pth)+')',
                           lwtBoth);}
                ParseMsg:=false;
                MsgNotEmpty:=true;
                Move(TargetAddr,DestAddr,SizeOf(tAddress));
                Move(CfgRec^.MyAddress[1],OrgAddr,SizeOf(tAddress));
                MatchAka(OrgAddr);
                { клуджики }
                MsgStr:=^A'PID: '+PID+' '+VID;
                AddFirstMsgLn(false);
                MsgStr:=^A'MSGID: '+_4D2str(OrgAddr)+' '+
                        HexL(longint(TodayDate) or
                        Random($FEFE)or CurTimeSec);
                AddFirstMsgLn(false);
                if DestAddr.Point <>0 then begin
                 MsgStr:=^A'TOPT '+Long2str(DestAddr.Point);
                 AddFirstMsgLn(false);
                end;
                if OrgAddr.Point <>0 then begin
                 MsgStr:=^A'FMPT '+Long2str(OrgAddr.Point);
                 AddFirstMsgLn(false);
                end;
                MsgStr:=^A'INTL '+Addr2str(DestAddr.Zone,DestAddr.Net,
                        DestAddr.Node,0)+' '+Addr2str(OrgAddr.Zone,
                        OrgAddr.Net,OrgAddr.Node,0);
                AddFirstMsgLn(false);
                { добавляем фирменную дрюку ;-}
                MsgStr:=' * Posted by '+PID+' '+VID;
                AppendMsgLn(false);
                MsgStr:='';
                AppendMsgLn(false);
                FillChar(MsgHdr,SizeOf(tMsgHdr),0);
                if LoadMsgText then with MsgHdr do begin
                 MsgStr:='--- City of Tears';
                 AppendMsgLn(false);
                 { заполняем поля заголовка письма }
                 FromName:=PID;
                 ToName:='SysOp';
                 Subj:='get this text';
                 Date:=MsgDateStamp;
                 DestNode:=DestAddr.Node;
                 OrigNode:=OrgAddr.Node;
                 OrigNet:=OrgAddr.Net;
                 DestNet:=DestAddr.Net;
                 CreateMsgTimeStamp(MsgWritten);
                 Attribute:=bMsgFlag[_KillSent] or
                            bMsgFlag[_Private];
                 { фигачим в пакет }
                 AddMsg2pkt(TargetAddr,pth,l);
                 DisposeMessage;
                end;
               end
               else
                ForceDosError(2,s,false);
              end;
             end;
     evChange: ;
    end;
    {---}
    NeedUpdateEvents:=true;
   end;
  end;
  p:=p^.NextEvent;
 end;
 if not NeedUpdateEvents then
  Log_Write(lfAttention,'No active events for now',lwtBoth);
end;

procedure WriteStat;
begin
 with SessionStat do begin
  EndTimeMs:=TimeMs;
  Log_Write(lfStat,'Mail:  Scaned: '+Long2str(MailScaned)+
            '  Sent: '+Long2str(MailSent),lwtBoth);
  Log_Write(lfStat,'Pkt:  Found: '+Long2str(PktsFound)+
            '  Bad: '+Long2str(PktsBad),lwtBoth);
  Log_Write(lfStat,'Active '+Real2str((EndTimeMs-StartTimeMs)/1000,6,2)+
            ' sec.',lwtBoth);
 end;
end;

procedure LoadProdCodes;
var
 f:file;

begin
 ProdCodes:=nil;
 if Length(CfgRec^.FTSCprod) <>0 then begin
  assign(f,CfgRec^.FTSCprod);
  reset(f,1);
  if CheckError(CfgRec^.FTSCprod,false) then exit;
  ProdCodesSiz:=FileSize(f);
  GetMem(ProdCodes,ProdCodesSiz);
  BlockRead(f,ProdCodes^,ProdCodesSiz);
  close(f);
  CheckError(CfgRec^.FTSCprod,false);
 end;
end;

procedure SfMp_Init;
begin
 FillChar(SessionStat,SizeOf(tSessionStat),0);
 SessionStat.StartTimeMs:=TimeMs;
 TextAttr:=$07;
 ClrScr;
 {$IFDEF OS2}
 FastWrite(CharStr(' ',ScreenWidth*2),2,1,$70);
 FastCenter(xPID+' '+xVID,2,$7E);
 FastCenter('Copyright '+CID+'. All rights reserved.',3,$7F);
 FastWrite(CharStr('─',ScreenWidth-1),1,2,$7F);
 FastVert('┌'+CharStr('│',2)+'└',1,1,$7F);
 FastWrite(CharStr('─',ScreenWidth-1),4,2,$78);
 FastWrite('┐',1,ScreenWidth,$7F);
 FastVert(charstr('│',2)+'┘',2,ScreenWidth,$78);
 {$ELSE}
 FastFill(ScreenWidth*2,' ',2,1,$70);
 FastCenter(xPID+' '+xVID,2,$7E);
 FastCenter('Copyright '+CID+'. All rights reserved.',3,$7F);
 FastFill(ScreenWidth-1,'─',1,2,$7F);
 FastVert('┌'+CharStr('│',2)+'└',1,1,$7F);
 FastFill(ScreenWidth-1,'─',4,2,$78);
 FastWrite('┐',1,ScreenWidth,$7F);
 FastVert(charstr('│',2)+'┘',2,ScreenWidth,$78);
 {$ENDIF}
 GotoXY(1,6);
 {if ParamCount =0 then Usage;}
 Randomize;
 {---}
 CfgFname:=AddBackSlash(JustPathname(ParamStr(0)))+CfgFname;
 LogFname:=AddBackSlash(JustPathname(ParamStr(0)))+LogFname;
 NeedUpdateEvents:=false;
 TextRec(fLog).Mode:=fmClosed;
 oldHalt:=ExitProc;
 ExitProc:=@MyHalt;
 ShowErrorPtr:=@SayError;
 ParseCmdLine;
 Log_Begin;
 GetMem(CfgRec,SizeOf(tCfgRec));
 FillChar(CfgRec^,SizeOf(tCfgRec),0);
 CheckSavedEvents;
 ParseConfig;
 LoadProdCodes;
 {---}
 FillChar(MsgCB,SizeOf(tMsgCB),0);
 with MsgCB do begin
  GetMem(MsgTRxBuf,SizeOf(tMsgTrxBuf));
  GetMem(MsgLnBuf,SizeOf(tMsgTrxBuf));
 end;
 Log_Write(lfDebug,'Mem/Max: '+Long2str(MemAvail)+'/'+Long2str(MaxAvail),lwtBoth);
end;

procedure SfMp_Run;
begin
 DoActiveEvents;
 { после того, как ивенты отработаны, }
 { сканим netmail, запаковываем исходящюю почту, }
 { распаковываем пришедшие пакеты }
 InitNodeIdx;
 RescanNetmail;
 UnpackIncomingPkts(CfgRec^.Inbound);
 if (CfgRec^.SecInbound <>'') and (CfgRec^.SecInbound <>CfgRec^.Inbound) then
  UnpackIncomingPkts(CfgRec^.SecInbound);
end;

procedure SfMp_Done;
begin
 CloseNodeIdx;
 DisposeNodeIdx;
 FreeMem(MsgTRxBuf,SizeOf(tMsgTRxBuf));
 FreeMem(MsgLnBuf,SizeOf(tMsgTRxBuf));
 if ProdCodes <>nil then
  FreeMem(ProdCodes,ProdCodesSiz);
 WriteStat;
end;

end.
