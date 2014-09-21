{$I-,F+,O+}
unit Script;

interface

Type
  keyCode =
  (kcExit,
   {Screen commands}
   kcClrScr,
   kcWrite,
   kcWriteLn,
   kcDelay,
   {Modem commands}
   kcModemStr,
   kcSendStr,
   kcWait,
   {other commands}
   kcIfFound,
   kcIfNotFound,
   kcIfCD,
   kcIfNotCD,
   kcLogWrite,
   kcRun,
   kcZReceive,
   kcIfReceive,
   kcUnknown);

Const
  keyWord : array [keyCode] of String[10]=
  ('exit',
   'clr',
   'write',
   'writeln',
   'pause',
   'modemstr',
   'sendstr',
   'wait',
   'iffound',
   'ifnotfound',
   'ifcd',
   'ifnotcd',
   'logwrite',
   'run',
   'zreceive',
   'ifreceive',
   'Unknown');

Var
  Founded    : boolean;
  ReceiveOk  : boolean;

function DoScript(Script:String):boolean;

implementation
uses
   TPCrt,
   TPWindow,
   fos_Lib,
   Config,
   Swapr,
   UnixTime,
   sfInclud,
   sf_snd,
   WriteLog,
   Terminal,
   ZModem,
   Show,
   TString_;

procedure ReceiveFiles;
begin
  TermMode:=true;
  ReceiveOk:=false;
  if (GetPortStat and ST_DCD)=0 then exit;
  Conn_Speed:=Connect_Speed;
  ZModemBegin(Connect_Speed,0);
  Z_MakeCRC32    := true;
  SessionFace;
  Receive:=true;
  LogWrite(imSynchronize,'',ld_Session);
  If (ZModemReceive(pCfgRec^.InBound_Dir,
      TermEndFile)<>0) and (ReceivingFile) then begin
      { Пpием накpылся;( }
      LogWrite(wmZRecvFailed,
               long2Str(TransferStart + TransferBytes)+#3+
               long2Str(Transfer_CPS)+#3+
               long2Str(Transfer_CPSpc),ld_SessAll);
      PlaySound(tSndSessAbort);
  end else begin
    LogWrite(imZRCompleteMsg,'',ld_Session);
    ReceiveOk:=true;
    PlaySound(tSndSessOk);
  end;
  KillWindow(PWin);
  ZModemEnd;
  TermMode:=false;
end;

function DoScript(Script:String):boolean;
Var
  f : text;
  S,S1:String;
  i,kw : keyCode;
  ln : word;
  tw : word;
  ti : integer;
  tl : longint;

begin
  DoScript:=false;
  Founded:=false;
  ReceiveOk:=false;
  ln:=0;
  Assign(f,Script);
  fileMode:=$20;
  Reset(f);
  fileMode:=$2;
  if IOResult<>0 then begin
    WriteLn('Bad Script Name: '+Script);
    Pause(18);
    exit;
  end;
  repeat
    ReadLn(f,S);
    If IOResult<>0 then begin
      WriteLn('Can''t read Script');
      Close(f);
      if IOResult<>0 then {clear};
      exit;
    end;
    S:=trim(S);
    Inc(ln);
    if (Length(S)<>0) and (S[1]<>';') then begin
      S1:=StLoCase(trim(ExtractWord(1,S,[' ',^I,'('])));
      kw:=kcUnknown;
      For i:=kcExit to kcUnknown do begin
        if S1=keyWord[i] then kw:=i;
      end;
      Case kw of
       kcExit : begin
                 DoScript:=true;
                 Close(f);
                 if IOResult<>0 then {clear};
                 exit;
                end;
       kcClrScr: begin
                  TextAttr:=$07;
                  ClrScr;
                 end;
       kcWrite : begin
                  S1:=ExtractWord(2,S,['''']);
                  Write(S1);
                 end;
       kcWriteLn : begin
                  S1:=ExtractWord(2,S,['''']);
                  WriteLn(S1);
                 end;
       kcDelay : begin
                  S1:=ExtractWord(2,S,['(',')']);
                  if Str2Word(trim(S1),tw) then
                    Delay(tw);
                 end;
       kcModemStr : begin
                     S1:=ExtractWord(2,S,['''']);
                     if WriteString(S1)<>0 then
                       WriteLn('Sending string error');
                    end;
       kcSendStr : begin
                    S1:=ExtractWord(2,S,['''']);
                    SendStr(S1);
                   end;
       kcWait    : begin
                    S1:=ExtractWord(2,S,['''']);
                    S:='';
                    tl:=timeCounter;
                    TextAttr:=$0E;
                    repeat
                      ti:=ReadWait;
                      if ti>0 then begin
                        S:=S+char(ti);
                        if byte(S[0])>100 then
                        s:=copy(S,70,100);
                        Write(char(ti));
                      end;
                    until (timecounter>tl+364) or (Pos(S1,S)<>0);
                    if Pos(S1,S)<>0 then founded:=true else founded:=false;
                    TextAttr:=$07;
                   end;
       kcIfFound : begin
                    if not founded then ReadLn(f,s);
                   end;
       kcIfNotFound : begin
                    if founded then ReadLn(f,s);
                   end;
       kcIfCD    : begin
                    if (GetPortStat and ST_DCD) = 0 then ReadLn(f,s);
                   end;
       kcIfNotCD : begin
                    if (GetPortStat and ST_DCD) <> 0 then ReadLn(f,s);
                   end;
       kcLogWrite: begin
                    S1:=ExtractWord(2,S,['''']);
                    LogWrite(0,S1,ld_File);
                   end;
       kcRun     : begin
                    S1:=ExtractWord(2,S,['''']);
                    Swap_Run(S1,false);
                   end;
       kcZReceive: begin
                    ReceiveFiles;
                   end;
       kcIfReceive: begin
                    if not ReceiveOk then ReadLn(f,s);
                   end;
       else
           WriteLn('Bad Command <'+S1+'> in line: '+Long2Str(ln)+' ignored');
      end;
    end;
  until Eof(f);
  DoScript:=true;
  Close(f);
  if IOResult<>0 then {clear};
end;

end.