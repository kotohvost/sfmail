{$X+,I-,O+,F+}
Unit writelog;

interface
Uses Config;

{$I SF_Lang.inc}

Const
  LogLastLn : boolean = false;
  CanLog    : boolean = false;
  FullLog   : boolean = false;
  ModWinTout : longInt = 0;
  BusyCount : longInt = 0;

Const
  ld_Clear   = $01;
  ld_File    = $02;
  ld_Screen  = $04;
  ld_Session = $08;
  ld_All     = ld_File or ld_Screen;
  ld_SessAll = ld_File or ld_Session;
  ld_LastLn  = $80;

procedure OpenLogFile;
procedure WriteLogHead;
procedure LogWrite(StrId:word; Par:String; LogPar:byte);
procedure CloseLogFile;
procedure ModemScrollUp;
procedure ModemScrollDown;
procedure ModemLogScreen(S:String);

implementation
Uses TPCrt,
     TString_,
     ADLang,
     Dos,
     {msgXs,}
     {for debug}
     eventMan,
     {for debug}
     aTime,
     fileMan,
     Pwd_Xs,
     Sm_Cpl,
     SFInclud,
     EMStruct,
     Date,
     Error;

procedure OpenLogFile;
  var
   a : integer;
begin
  MkAllDir(JustPathName(pCfgRec^.LogDir));
  Assign(Log, pCfgRec^.LogDir);
  a:=IOResult;
  filemode:=$22;
  Reset(Log);
  Close(Log);
  filemode:=$2;
  if IOResult <> 0 then begin
    Rewrite(Log);
    close(Log);
  end;
  if IOResult <> 0 then
    ErrorMessage('Can''t open Log File',221);
  CanLog:=true;
end;

procedure LogWrite(StrId:word; Par:String; LogPar:byte);
Var
  TempIO  : integer;
  S1      : string;
  S       : string;
  i       : byte;
  k       : byte;
begin
  If StrId=0 then
    S1:=Par
  else
    S1:=TranslateStr(StrId,Par);
  GetDate_Time;

  if S1[length(S1)]='' then S1:=S1+' ';
  for k:=1 to WordCount(S1,['']) do begin
   S:=ExtractWord(k,S1,['']);
   { Write in File }
   if LogPar and (ld_File or ld_Clear)<>0 then begin
     TempIO:=IOResult;
     If FileLogCount=10 then begin
       FileLogCount := 0;
       if CanLog then begin
        filemode:=$22;
        Append(Log);
        filemode:=$2;
        If IOResult <> 0 then
          Rewrite(Log);
        For i :=1 to 10 do
        Writeln(Log,FileLogBuffer^[i]);
        Close(Log);
       end;
     end;
     Inc(FileLogCount);
     if (LogPar and ld_Clear <> 0) or (length(trim(S))=0) then
       FileLogBuffer^[FileLogCount]:=S
     else
       FileLogBuffer^[FileLogCount]:=Time_+'  '+S;
     TempIO:=IOResult;
     If (pCfgRec^.SysFlags and mscCacheLog = 0) or MsgDebugMode then
       CloseLogFile;
   end;

   { Write in Screen }
   if LogPar and ld_Screen<>0 then begin
     if not LogLastLn then begin
      for i:=1 to MaxScrLines-15 do
       LogBuffer^[i]  :=LogBuffer^[succ(i)];
     end;
     LogBuffer^[MaxScrLines-14] :=Pad(ShortTime+'  '+S,LogScreenLen);
     if length(LogBuffer^[MaxScrLines-14])>LogScreenLen then
       LogBuffer^[MaxScrLines-14]:=Copy(LogBuffer^[MaxScrLines-14],1,LogScreenLen);
     If not ScreenSave then begin
      if PWin=nil then
       if FullLog then begin
         for i:=1 to ScreenHeight-14 do
           FastWrite(LogBuffer^[i+MaxScrLines-ScreenHeight],i+4,2,pCfgRec^.SfMailColors[MainLog_Color]);
       end else begin
         for i:=1 to ScreenHeight-14 do
           FastWrite(Copy(LogBuffer^[i+MaxScrLines-ScreenHeight],1,LogShortLen),i+4,2,pCfgRec^.SfMailColors[MainLog_Color]);
       end;
     end;
   end;

   if LogPar and ld_Session<>0 then begin
     if not LogLastLn then begin
       for i:=1 to SessionLines-1 do
       SesBuffer^[i]  :=SesBuffer^[Succ(i)];
     end;
     if length(S)>57 then
        S:=Copy(S,1,55)+'..';
     SesBuffer^[SessionLines]  :=Pad(S,57);

     if termMode then begin
       for i:=11 to SessionLines+10 do
         FastWriteWindow(SesBuffer^[i-10],i,2,pCfgRec^.SfMailColors[Session_Log]);
     end else begin
       if HydraMode then begin
         for i:=14 to SessionLines+13 do
           FastWriteWindow(SesBuffer^[i-13],i,2,pCfgRec^.SfMailColors[Session_Log]);
       end else begin
         for i:=13 to SessionLines+12 do
           FastWriteWindow(SesBuffer^[i-12],i,2,pCfgRec^.SfMailColors[Session_Log]);
       end;
     end;
   end;
  end;

  if LogPar and ld_LastLn<>0 then
    LogLastLn:=true
  else
    LogLastLn:=false;
end;

procedure WriteLogHead;
  var
   tempIORes : integer;
begin
  LogWrite(0,#13#10#12#13#10'ƒƒƒƒƒƒƒƒƒƒ  '+Long2Str(day)+' '+
             Months[month]+' '+Long2Str(year)+', '+PID+' '+VID+NID,
           ld_Clear);
  LastTear := Date_;
  ChangeDOW;
end;

procedure CloseLogFile;
Var a : integer;
begin
  a:=IOResult;
  If FileLogCount=0 then exit;
  filemode:=$22;
  Append(Log);
  filemode:=$2;
  if IOResult=2 then begin
    Rewrite(Log);
    Writeln(Log,#13#10#12#13#10'ƒƒƒƒƒƒƒƒƒƒ  '+Long2Str(day)+' '+
            Months[month]+' '+Long2Str(year)+', '+PID+' '+VID+NID);
    LastTear := Date_;
    ChangeDOW;
  end;
  If IOResult=0 then begin
    For a :=1 to FileLogCount do
    Writeln(Log,FileLogBuffer^[a]);
    FileLogCount:=0;
  end;
  Close(Log);
  if IoResult<>0 then ;
end;

procedure ModemScrollDown;
Var
  i : byte;
begin
  If ScreenSave then exit;
  if FullLog then exit;
  for i:=64 to 79 do
    FastVert('≈'+PadCh('','≥',ScreenHeight-14)+'¡',4,i,pCfgRec^.SfMailColors[Border_Color]);
  FullLog:=true;
  FastWrite('√'+PadCh('','ƒ',62)+'¡'+PadCh('','ƒ',15)+'¥'
             ,4,1,pCfgRec^.SfMailColors[Border_Color]);
  for i:=5 to ScreenHeight-10 do
    FastWrite('≥'+pad('',78)+'≥',i,1,pCfgRec^.SfMailColors[Border_Color]);
  FastWrite('√'+PadCh('','ƒ',62)+'ƒ'+PadCh('','ƒ',15)+'¥'
            ,ScreenHeight-9,1,pCfgRec^.SfMailColors[Border_Color]);

  if PWin=nil then
   if FullLog then begin
     for i:=1 to ScreenHeight-14 do
       FastWrite(LogBuffer^[i+MaxScrLines-ScreenHeight],i+4,2,pCfgRec^.SfMailColors[MainLog_Color]);
   end else begin
     for i:=1 to ScreenHeight-14 do
       FastWrite(Copy(LogBuffer^[i+MaxScrLines-ScreenHeight],1,LogShortLen),i+4,2,pCfgRec^.SfMailColors[MainLog_Color]);
   end;
end;

procedure ModemScrollUp;
Var
  i : byte;
begin
  If ScreenSave then exit;
  if not FullLog then exit;
  for i:=79 downto 64 do
    FastVert('≈'+PadCh('','≥',ScreenHeight-14)+'¡',4,i,pCfgRec^.SfMailColors[Border_Color]);

  FullLog:=false;
  FastWrite('√'+PadCh('','ƒ',62)+'≈'+PadCh('','ƒ',15)+'¥'
             ,4,1,pCfgRec^.SfMailColors[Border_Color]);
  for i:=5 to ScreenHeight-10 do
    FastWrite('≥'+pad('',62)+'≥'+pad('',15)+'≥',i,1,pCfgRec^.SfMailColors[Border_Color]);
  FastWrite('√'+PadCh('','ƒ',62)+'¡'+PadCh('','ƒ',15)+'¥'
            ,ScreenHeight-9,1,pCfgRec^.SfMailColors[Border_Color]);

  if PWin=nil then
   if FullLog then begin
     for i:=1 to ScreenHeight-14 do
       FastWrite(LogBuffer^[i+MaxScrLines-ScreenHeight],i+4,2,pCfgRec^.SfMailColors[MainLog_Color]);
   end else begin
     for i:=1 to ScreenHeight-14 do
       FastWrite(Copy(LogBuffer^[i+MaxScrLines-ScreenHeight],1,LogShortLen),i+4,2,pCfgRec^.SfMailColors[MainLog_Color]);
   end;
  for i:=1 to ScreenHeight-14 do
     FastWrite(ModBuffer^[i+MaxScrLines-ScreenHeight],i+4,66,pCfgRec^.SfMailColors[Modem_Color]);
end;

procedure ModemLogScreen(S:String);
  Var
    i,k     : byte;
begin
  ModemScrollUp;
  { èÆ·´•§≠®© OK „p•ß†•¨}
  if trim(ModBuffer^[MaxScrLines-14])<>'OK' then begin
    for i:=1 to MaxScrLines-15 do
      ModBuffer^[i]:=ModBuffer^[succ(i)];
  end;
  if pos('Busy',S)<>0 then begin
    Inc(BusyCount);
    if pos('Busy',ModBuffer^[MaxScrLines-15])<>0 then begin
      for i:=MaxScrLines-14 downto 2 do
        ModBuffer^[i]:=ModBuffer^[Pred(i)];
    end;
    S:=S+' ('+Long2Str(BusyCount)+')';
  end else begin
    if pos('OK',S)=0 then
      BusyCount:=0;
  end;

  S:=Center(S,ModScreenLen);
  ModBuffer^[MaxScrLines-14]:=Center(S,ModScreenLen);
  if length(ModBuffer^[MaxScrLines-14])>ModScreenLen then
     ModBuffer^[MaxScrLines-14]:=Copy(ModBuffer^[MaxScrLines-14],1,ModScreenLen);

  If ScreenSave then exit;
  for i:=1 to ScreenHeight-14 do
    if length(ModBuffer^[i+MaxScrLines-ScreenHeight])=0 then
      FastWrite(pad(' ',ModScreenLen),i+4,66,pCfgRec^.SfMailColors[Modem_Color])
    else
      FastWrite(ModBuffer^[i+MaxScrLines-ScreenHeight],i+4,66,pCfgRec^.SfMailColors[Modem_Color]);
  ModWinTout:=CurUnixTime;
end;

end.