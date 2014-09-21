(*** Doorway-mode-DosShell for Santa Fox Mail ***)

{$X+,O+,F+,I-}
UNIT Sf_Shell;

INTERFACE

{$I SfDefine.inc}

procedure CommandCom;

IMPLEMENTATION

uses
 {$IFNDEF NoComm}
 SfInclud,
 Terminal,
 {$ENDIF}
 Dos,
 TpDos,
 Tstring_,
 TpCrt,
 {$IFNDEF NoComm}
 Keyb,
 {$ENDIF}
 Config,
 {$IFNDEF NoComm}
 Fos_Lib,
 Modem,
 WriteLog,
 ZModem,
 ShowF,
 Show,
 {$ENDIF}
 EmStruct,
 EventMan,
 Em_Cpl,
 RelTQ,
 MsgXs,
 Swapr,
 Date,
 TPWindow,
 FileMan,
 aTime;

type
 shellCmd=(
  cmdDir,
  cmdDel,
  cmdMkDir,
  cmdRmDir,
  cmdCD,
  cmdCopy,
  cmdExit,
  cmdRun,
  cmdQue,
  cmdUpLoad_Z,
  cmdDownLoad_Z,
  cmdTime,
  cmdDate,
  cmdHalt,
  cmdHelp,

  cmdUnknown
 );

 tCmdRec=record
  crNam:string[5];
  crMC:byte;
 end;

const
 ScrH=20;
 { ShowDirectory mode consts }
 dm_Wide=$01;
 dm_aTtr=$02;
 firstCmdId=cmdDir;
 lastCmdID=cmdHelp;

 (* scrH=20;  { чеpез сколько стpок делать паузу пpи выводе на экpан } *)

 shellCmdID:array[firstCmdId..lastCmdId] of tCmdRec=(
  (crNam:'dir';crMC:2),
  (crNam:'del';crMC:2),
  (crNam:'mkdir';crMC:2),
  (crNam:'rmdir';crMC:2),
  (crNam:'cd';crMC:2),
  (crNam:'copy';crMC:2),
  (crNam:'exit';crMC:2),
  (crNam:'run';crMC:2),
  (crNam:'que';crMC:3),
  (crNam:'ulz';crMC:3),
  (crNam:'dlz';crMC:3),
  (crNam:'time';crMC:2),
  (crNam:'date';crMC:2),
  (crNam:'halt';crMC:3),
  (crNam:'help';crMC:2)
 );

procedure writeBoth(s:string);
begin
 {$IFNDEF NoComm}
 SendStr(s);
 {$ENDIF}
 write(s);
end;

procedure writeBothLn(s:string);
begin
 writeBoth(s+#13#10);
end;

procedure CommandCom;
var
 oldDir:PathStr;
 _done:boolean;
 saveWin:pointer;
 RByte:integer;
 CmdBuf:string[78];
 cmdStr:string[13];
 doCmd:boolean;
 w:word;
 ch:char;
 chi:byte;
 CurrDir:PathStr;
 sr:SearchRec;
 l:longint;
 dt:DateTime;
 LastZero:boolean;
 LastPlus:boolean;
 Timer:LongInt;
 DoorLog: text;
 Logging: boolean;

function Ask(AskStr:string; defAns:boolean):boolean;
var
 Sask:string[3];

begin
  Ask:=false;
  { Выход если нет несущей }
  {$IFNDEF NoComm}
  if GetPortStat and ST_DCD =0 then exit;
  {$ENDIF}
  if defAns =true then
   Sask:='Y/n'
  else
   Sask:='y/N';
  writeBoth(#13#10+AskStr+' ('+Sask+')? ');

 ch:=#0;

 repeat
 {$IFNDEF NoComm}
   if GetPortStat and ST_DCD =0 then exit;
 { Read from modem }
   RByte:=ReadChar;
   if RByte<>TERR_RXEMPTY then
      Ch:=Char(RByte);

 if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
 {$ENDIF}
   if KeyPressed then begin
     ch:=ReadKey;
     if ch =#0 then ch:=ReadKey;
 {$IFNDEF NoComm}
   end
   else
     IfKeyPress:=0;
 {$ENDIF}
 end;
  if ch =#13 then
   if defAns then ch:='y'
   else ch:='n';
  ch:=LoCase(ch);
 until (ch ='y') or (ch ='n');
 Ask:=LoCase(ch) ='y';
 { clear prompt and move cursor up }
 writeBoth(#13);
 ClrEol;
 GotoXY(1,pred(WhereY));
 {$IFNDEF NoComm}
 SendStr(^V^G^V^C);
 {$ENDIF}
end;

procedure SendFiles;
begin
  {$IFNDEF NoComm}
  { Выход если нет несущей }
  if GetPortStat and ST_DCD =0 then exit;
  { Инициализация ZMdoem'а }
  Receive:=false;
  Conn_Speed:=Connect_Speed;
  ZModemBegin(Connect_Speed,0);
  Z_MakeCRC32:=true;
  HiddenCursor;
  SessionFace;
  {$ENDIF}
  { check validation of filename }
  if Length(JustPathName(cmdBuf)) =0 then
    cmdBuf:=AddBackSlash(CurrDir)+JustFileName(cmdBuf);
  { синхpонизация }
  {$IFDEF NoComm}
  writeBothln('Syncronizing with receiver..');
  {$ELSE}
  LogWrite(imSynchronize,'',ld_Session);
  if not Synchronize then begin
    KillWindow(PWin);
    NormalCursor;
    ZModemEnd;
    exit;
  end;
  {$ENDIF}
  { пеpесылка файлов по маске в цикле }
  {$I+} FindFirst(cmdBuf,AnyFile-Directory-VolumeId,sr); {$I-}
  if DosError <>0 then begin
    {$IFNDEF NoComm}
    LogWrite(imZSCompleteMsg,'',ld_Session);
    SendZEnd;
    KillWindow(PWin);
    NormalCursor;
    ZModemEnd;
    {$ENDIF}
    writeBothLn('No matching files found for <'+cmdBuf+'>');
    if logging then begin
      GetDate_Time;
      WriteLn(DoorLog,Time_+' No matching files found for <'+cmdBuf+'>');
      if IOResult<>0 then {clear};
    end;
    exit;
  end;
  cmdBuf:=AddBackSlash(JustPathName(cmdBuf));
  while DosError =0 do begin
   {$IFNDEF NoComm}
   if logging then begin
     GetDate_Time;
     WriteLn(DoorLog,Time_+' Sending '+cmdBuf+sr.Name);
     if IOResult<>0 then {clear};
   end;
   case ZModemSend(cmdBuf+sr.Name,sr.Name,TermEndFile) of
           ZOk : begin
                   if TransferError =0 then
                     LogWrite(imZSendComplete,long2Str(Transfer_CPS)+#3+
                              long2Str(Transfer_CPSpc),ld_SessAll)
                   else
                     LogWrite(imZSendComplErr,Long2Str(Transfer_CPS)+#3+
                              +long2Str(Transfer_CPSpc)+#3+
                              Long2Str(TransferError),ld_SessAll);
                 end;
     ZFileSkip : LogWrite(imZSkipping,sr.Name,ld_SessAll);
   else
     LogWrite(wmZSendFailed,Long2Str(TransferStart+TransferBytes)+#3+
              Long2Str(Transfer_CPS)+#3+Long2Str(Transfer_CPSpc),
              ld_SessAll);
     KillWindow(PWin);
     NormalCursor;
     ZModemEnd;
     writeBothLn('File sending failed at '+
                 Long2Str(TransferStart + TransferBytes)+', average CPS: '+
                 Long2Str(Transfer_CPS)+' ('+
                 Long2Str(Transfer_CPSpc)+'%)');
     if logging then begin
       GetDate_Time;
       WriteLn(DoorLog,Time_+'File sending failed at '+
               Long2Str(TransferStart + TransferBytes)+', average CPS: '+
               Long2Str(Transfer_CPS)+' ('+
               Long2Str(Transfer_CPSpc)+'%)');
       if IOResult<>0 then {clear};
     end;
     exit;
   end; (*CASE ZMODEMSEND*)
   {$ELSE}
   if Ask('Ok to send '+cmdBuf+sr.name,true) then
    writeln('<'+sr.Name+'> sent')
   else
    if Ask('<Y> for skip, <N> for abort',true) then
     writeln('Skipping '+sr.Name)
    else begin
     writeln('File sending failed');
     exit;
    end;
   {$ENDIF}
   {$I+} FindNext(sr); {$I-}
  end; (*WHILE DOSERROR=0*)
  { Кpичим, что все пеpедали }
  {$IFNDEF NoComm}
  LogWrite(imZSCompleteMsg,'',ld_Session);
  SendZEnd;
  KillWindow(PWin);
  ZModemEnd;
  NormalCursor;
  {$ENDIF}
  writeBothLn('Sending completed');
  if logging then begin
    GetDate_Time;
    WriteLn(DoorLog,Time_+' Sending completed');
    if IOResult<>0 then {clear};
  end;
end;

procedure RecvFiles;
begin
  {$IFNDEF NoComm}
  { Выход если нет несущей }
  if GetPortStat and ST_DCD =0 then exit;
  { Инициализация ZMdoem'а }
  Receive:=true;
  Conn_Speed:=Connect_Speed;
  ZModemBegin(Connect_Speed,0);
  Z_MakeCRC32:=true;
  HiddenCursor;
  SessionFace;
  {синхpонизация}
  LogWrite(imSynchronize,'',ld_Session);
  If (ZModemReceive('.\',TermEndFile)<>0)
     and (ReceivingFile) then begin
     { Пpием накpылся;( }
     LogWrite(wmZRecvFailed,
              long2Str(TransferStart + TransferBytes)+#3+
              long2Str(Transfer_CPS)+#3+
              long2Str(Transfer_CPSpc),ld_SessAll);
  end else
     LogWrite(imZRCompleteMsg,'',ld_Session);
  KillWindow(PWin);
  NormalCursor;
  ZModemEnd;
  {$ENDIF}
end;

procedure DoCopy;
var
 fIn,fOut:file;
 s1,s2:PathStr;
 buf:pointer;
 bufSiz:word;
 bRd,bWr:word;

procedure PanicClose(ss:string);
begin
 writeBothLn(ss);
 close(fIn);
 if IoResult <>0 then;
 close(fOut);
 if IoResult <>0 then;
 FreeMem(buf,bufSiz);
 _done:=false;
end;

begin
 w:=0;
 s1:=ExtractWord(1,cmdBuf,[' ']);
 s2:=ExtractWord(2,cmdBuf,[' ']);
 if (Pos('*',s2) <>0) or (Pos('?',s2) <>0) then begin
   writeBothLn('Invalid dest path `'+s2+#39);
   exit;
 end;
 { copy process }
 {$I+} FindFirst(s1,AnyFile-Directory-VolumeId,sr); {$I-}
 if DosError <>0 then
   writeBothLn('File not found `'+s1+#39)
 else begin
   { alloc copy buffer }
   bufSiz:=57344;
   if bufSiz >MaxAvail then bufSiz:=MaxAvail;
   GetMem(buf,bufSiz);
   { copy-in-circle }
   while DosError =0 do begin
    if ExistFile(AddBackSlash(s2)+sr.name) then
     _done:=Ask('File `'+sr.Name+#39' exists, overwrite',false)
    else
     _done:=true;

    if _done then begin
      assign(fIn,AddBackSlash(JustPathName(s1))+sr.Name);
      reset(fIn,1);
      if IoResult <>0 then begin
        PanicClose('Unable to open `'+AddBackSlash(JustPathName(s1))+
                   sr.Name+#39);
        exit;
      end;
      GetFtime(fIn,l); { взяли дату/вpемя пеpемещаемого файла }
      assign(fOut,AddBackSlash(s2)+sr.Name);
      rewrite(fOut,1);
      if IoResult <>0 then begin
        PanicClose('Unable to open `'+AddBackSlash(s2)+sr.Name+#39);
        exit;
      end;
      { coping }
      repeat
        BlockRead(fIn, buf^, bufSiz, bRd);
        BlockWrite(fOut, buf^, bRd, bWr);
        if IoResult <>0 then begin
          PanicClose('I/O error');
          exit;
        end;
      until (bRd =0) or (bWr <>bRd);
      SetFtime(fOut,l); { устанавливаем новому файлу стаpую дату }
      { closing }
      close(fIn);
      close(fOut);
      { copied }
      writeBothLn(AddBackSlash(JustPathName(s1))+sr.Name+' => '+
                  AddBackSlash(s2)+sr.name);
      Inc(w);
    end;
    {$I+}
    FindNext(sr);
    {$I-}
   end;
 end;
 if IoResult <>0 then;
 FreeMem(buf,bufSiz);
 _done:=false;
end;

procedure DoDel;
var
 f:file;
 o:boolean;

begin
 w:=0; { num of files }
 l:=0; { bytes freed }
 if (Length(cmdBuf) =1) and (cmdBuf[1] ='.') then { del *.* }
   cmdBuf:=AddBackSlash(CurrDir)+'*.*';

 if (Pos('*.*',cmdBuf) <>0) and (not Ask('Kill ALL, are U sure',false)) then exit;

 {$I+}
 FindFirst(cmdBuf,AnyFile-VolumeId-Directory,sr);
 {$I-}
 if DosError <>0 then
  writeBothLn('File not found `'+cmdBuf+#39)
 else
  while DosError =0 do begin
    o:=true;
    assign(f,AddBackSlash(JustPathName(cmdBuf))+sr.Name);
    if sr.Attr and ReadOnly <>0 then begin
     if Ask('File '+sr.Name+' marked R/O, are U really want to kill',false) then
       SetFattr(f,sr.Attr-ReadOnly)
     else
       o:=false;
    end
    else
     if sr.Attr and SysFile <>0 then
      if not Ask('File '+sr.Name+' marked SYS, are U really want to kill',false) then
       o:=false;
    if o then begin
      erase(f);
      Inc(w);
      Inc(l,sr.Size);
      writeBothLn('Deleting '+AddBackSlash(JustPathName(cmdBuf))+sr.Name);
    end;
    {$I+}
    FindNext(sr);
    {$I-}
  end;
 writeBothLn(Long2str(w)+' file(s) deleted : '+Long2str(l)+' bytes freed');
end;

function WhatCommand:shellCmd;
var
 z:shellCmd;

begin
 if (Length(cmdStr) = 2) and (cmdStr[2]=':') then begin
  cmdBuf:=cmdStr;
  WhatCommand:=cmdCD;
  exit;
 end;
 for z:=firstCmdId to lastCmdId do
   if Pos(cmdStr,shellCmdId[z].crNam) =1 then
     if (Length(cmdStr) >=shellCmdId[z].crMC) then begin
       WhatCommand:=z;
       exit;
     end;
 WhatCommand:=cmdUnknown;
end;

procedure FileAttr2str;
begin
 with sr do begin
  if Attr and ReadOnly <>0 then ch:='R'
  else ch:='·';
  cmdBuf:=cmdBuf+' '+ch;
  if Attr and Hidden <>0 then ch:='H'
  else ch:='·';
  cmdBuf:=cmdBuf+ch;
  if Attr and SysFile <>0 then ch:='S'
  else ch:='·';
  cmdBuf:=cmdBuf+ch;
  if Attr and Archive <>0 then ch:='A'
  else ch:='·';
  cmdBuf:=cmdBuf+ch;
  if Attr and Directory <>0 then ch:='D'
  else ch:='·';
  cmdBuf:=cmdBuf+ch;
 end;
end;

function MakeQueStr(n:word):string;
var
 s:PathStr;

begin
 with Que[n]^ do begin
  { set CurQue marker }
  if ((Que[succ(CurQue)] =nil) and (n =1)) or (n =succ(CurQue)) then
   s[1]:=#16
  else
   s[1]:=' ';
  { make que string }
  s:=s[1]+Pad(Addr2str(DestAddr,DestAddr.Point <>0),19)+
    LeftPad(Long2str(Try),5)+
    LeftPad(vInBestForm(MailSize),10)+
    LeftPad(vInBestForm(FileSize+NormalBoxSize),8)+
    LeftPad(vInBestForm(HoldMailSize+HoldFileSize+HoldBoxSize),8)+' ';

  if CheckHIP(DestAddr,tpImm) then
    s:=s+'Imm '
  else
    s:=s+'··· ';
  if CheckHIP(DestAddr,tpPrio) then
    s:=s+'Prio '
  else
    s:=s+'···· ';
  if CheckHIP(DestAddr,tpHold) then
    s:=s+'Hold '
  else
    s:=s+'···· ';
  if CheckHIP(DestAddr,tpHXT) then
    s:=s+'HXT '
  else
    s:=s+'··· ';
  if CheckHIP(DestAddr,tpHRQ) then
    s:=s+'HRQ'
  else
    s:=s+'···';
 end;
 MakeQueStr:=s;
end;

procedure XsQue;
var
 n:word;

begin
 chI:=0;
 if Length(cmdBuf) =0 then begin
  if Que[1] =nil then
   writeBothLn('Que is empty')
  else begin
   n:=1;
   repeat
    writeBothLn(MakeQueStr(n));
    Inc(n);
    Inc(chI);
    if (Que[n] <>nil) and (chI =ScrH) then begin
      _done:=not Ask('More',true);
      chI:=0;
    end;
   until (Que[n] =nil) or _done;
  end;
 end;
 _done:=false;
end;

procedure ShowDirectory;
var
 w1:word;
 dirMode:byte;
 s,s1:PathStr;
 show:boolean;

begin
 dirMode:=0;
 s:='';
 for w1:=1 to WordCount(cmdBuf,[' ']) do begin
  s1:=ExtractWord(w1,cmdBuf,[' ']);
  if s1[1] ='/' then begin
   case LoCase(s1[2]) of
    'w': dirMode:=dirMode or dm_Wide;
    't': dirMode:=dirMode or dm_Attr;
   end;
  end
  else
   { not a switch => filespec }
   s:=s1;
 end;
 if Length(s) =0 then
   s:=AddBackSlash(CurrDir)+'*.*'
 else
  if s[Length(s)] in ['\',':'] then
    s:=s+'*.*';
 if dirMode and dm_Attr <>0 then
  dirMode:=dirMode and (not dm_Wide);
 s:=StLoCase(s);
 writeBothLn('  ∙Directory of '+s+#13#10);
 cmdBuf:='';
 w:=0;  { num of files }
 w1:=0; { num of dirs }
 l:=0;     { sum size }
 chI:=3;
 show:=true;
 {$I+} FindFirst(s,AnyFile-VolumeId,sr); {$I-}
 if DosError =0 then begin
   while DosError =0 do begin
     _done:=true;
     Inc(l,sr.Size);
     UnpackTime(sr.Time,dt);
     if sr.Attr and Directory <>0 then begin
      if dirMode and dm_Wide <>0 then
        cmdBuf:=cmdBuf+Pad('['+sr.Name+']',15)
      else
        cmdBuf:=Pad(sr.Name,13)+Center('·∙DIR∙·',11)+
                LeftPad(Long2str(dt.Day),3)+'-'+
                LeftPadCh(Long2str(dt.Month),'0',2)+'-'+
                copy(Long2str(dt.Year),3,2)+'  '+
                LeftPad(Long2str(dt.Hour),2)+':'+
                LeftPadCh(Long2str(dt.Min),'0',2);
      Inc(w1);
     end
     else begin
      if dirMode and dm_Wide <>0 then
        cmdBuf:=cmdBuf+Pad(StLoCase(sr.Name),15)
      else
        cmdBuf:=StLoCase(Pad(sr.Name,13))+LeftPad(Long2str(sr.Size),11)+
                LeftPad(Long2str(dt.Day),3)+'-'+
                LeftPadCh(Long2str(dt.Month),'0',2)+'-'+
                copy(Long2str(dt.Year),3,2)+'  '+
                LeftPad(Long2str(dt.Hour),2)+':'+
                LeftPadCh(Long2str(dt.Min),'0',2);
      Inc(w);
     end;
     if dirMode and dm_Attr <>0 then
      FileAttr2str;
     if show then
      if (dirMode and dm_Wide =0) or
         ((dirMode and dm_Wide <>0) and (Length(cmdBuf) >=75)) then begin
       writeBothLn(cmdBuf);
       cmdBuf:='';
       Inc(chI);
      end;
     {$I+} FindNext(sr); {$I-}
     if show and (chI =ScrH) then begin
      _done:=Ask('More',true);
      chI:=0;
      show:=_done;
      _done:=true;
     end;
     if not _done then DosError:=-1;
   end;
   if show and (dirMode and dm_Wide <>0) and (Length(cmdBuf) <>0) then
     { show rest of files }
     writeBothLn(cmdBuf);
   writeBothLn(PadCh(' ','─',40));
   writeBothLn(LeftPad(Long2Str(l),13)+' bytes in '+
               Long2Str(w)+' files and '+
               Long2str(w1)+' dirs');
   if (Length(s) <2) or (s[2] <>':') then
    l:=VirtualDiskFree(ord(CurrDir[1])-$40)
   else
    l:=VirtualDiskFree(ord(s[1])-$60);
   writeBothLn(LeftPad(Long2str(l),13)+' bytes free');
 end
 else
  writeBothLn('File not found `'+s+#39#13);
 _done:=false;
end;

procedure ShowSetDate;
begin
 with dt do begin
  if Length(cmdBuf) <>0 then begin
   w:=0;
   if (not(Str2word(ExtractWord(1,cmdBuf,['-']),Day))) or (Day =0) then
    w:=$FFFF;
   if (not(Str2word(ExtractWord(2,cmdBuf,['-']),Month))) or
      (Month <1) or (Month >12) then
    w:=$FFFF;
   if (not(Str2word(ExtractWord(3,cmdBuf,['-']),Year))) or
      (Year <1980) then
    w:=$FFFF;
   if (w <>0) or (DaysInMonth(Month,Year) <Day) then
    writeBothLn('Invalid date')
   else
    SetDate(Year,Month,Day);
  end;
  GetDate(Year,Month,Day,w);
  writeBothLn('Today is  '+LeftPad(Long2str(Day),2)+'-'+Months[Month]+'-'+
              Long2str(Year)+', '+sDOW[tDOW(w)]);
 end;
end;

procedure ShowSetTime;
begin
 with dt do begin
  if Length(cmdBuf) <>0 then begin
   w:=0;
   if (not Str2word(ExtractWord(1,cmdBuf,[':']),Hour)) or
      (Hour >23) then w:=$FFFF;
   if (not Str2word(ExtractWord(2,cmdBuf,[':']),Min)) or
      (Min >59) then w:=$FFFF;
   if WordCount(cmdBuf,[':']) >2 then begin
    if (not Str2word(ExtractWord(3,cmdBuf,[':']),Sec)) or
       (Sec >59) then w:=$FFFF;
   end
   else
    Sec:=0;
   if w <>0 then
    writeBothLn('Invalid time')
   else
    SetTime(Hour,Min,Sec,0);
  end;
  GetTime(Hour,Min,Sec,w);
  writeBothLn('Current time: '+LeftPad(Long2str(Hour),2)+':'+
              LeftPadCh(Long2str(Min),'0',2)+':'+
              LeftPadCh(Long2str(Sec),'0',2));
 end;
end;

procedure DoCommand;
begin
 { if cmdBuf is empty -- do nothing }
 writeBothLn('');
 cmdBuf:=Trim(cmdBuf);
 if Length(cmdBuf) <>0 then begin
   if logging then begin
     GetDate_Time;
     WriteLn(DoorLog,Time_+' '+CurrDir+'>'+cmdBuf);
     if IOResult<>0 then {clear};
   end;
   chI:=Pos(' ',cmdBuf);
   if chI <>0 then begin
     cmdStr:=copy(cmdBuf,1,pred(chI));
     cmdBuf:=TrimLead(copy(cmdBuf,succ(chI),Length(cmdBuf)));
   end
   else begin
     cmdStr:=cmdBuf;
     cmdBuf:='';
   end;
   cmdStr:=StLoCase(cmdStr);
   case WhatCommand of
     cmdExit: _done:=true;
     cmdRun: begin
              if Ask('Realy <'+cmdBuf+'>',false) then
                Swap_Run(cmdBuf,false);
              end;
     cmdDel: DoDel; { Del <filemask> }
     cmdRmDir: begin
                RmDir(cmdBuf);
                if IoResult <>0 then
                 writeBothLn('Cannot remove dir `'+cmdBuf+#39);
               end;
     cmdMkDir: begin
                MkDir(cmdBuf);
                if IoResult <>0 then
                 writeBothLn('Cannot create dir `'+cmdBuf+#39);
               end;
     cmdCopy: begin { Copy <src> [dest] }
               chI:=WordCount(cmdBuf,[' ']);
               if chI =1 then begin
                cmdBuf:=cmdBuf+' '+CurrDir;
                chI:=2;
               end;
               if chI <>2 then
                 writeBothLn('Invalid number of params')
               else begin
                 DoCopy;
                 writeBothLn(Long2str(w)+' file(s) copied');
               end;
              end;
     cmdUpLoad_Z: writeBothLn('This feature is not implemented yet..');
     cmdDownLoad_Z: if Length(cmdBuf) =0 then
                      writeBothLn('U must specify filename')
                    else
                      SendFiles;
     cmdCD: begin
             ChDir(cmdBuf);
             chI:=IoResult;
             case chI of
              0: GetDir(0,CurrDir);
              3: writeBothLn('Invalid path `'+cmdBuf+#39);
              152: writeBothLn('Drive not ready');
             else
              writeBothLn('ERROR #'+Long2str(chI));
             end;
            end;
     cmdDate: ShowSetDate;
     cmdTime: ShowSetTime;
     cmdDir: ShowDirectory;
     cmdQue: XsQue;
     cmdHalt: begin
               if (Length(cmdBuf) =0) or (not Str2long(cmdBuf,l)) then
                l:=240;
               if Ask('Halt '+Long2str(l),false) then
                halt(l);
              end;
     cmdHelp: begin
                if Length(cmdBuf) <>0 then begin
                  cmdStr:=StLoCase(cmdBuf);
                  case WhatCommand of
                   cmdRmDir: writeBothLn('RMDIR <dir>'#13#10#10+
                              'do not attempt to remove current dir!');
                   cmdMkDir: writeBothLn('MKDIR <dir>');
                   cmdDel: writeBothLn('DEL <file>'#13#10#10+
                              'if <file> is `.` all files in current dir will be killed');
                   cmdDownLoad_Z: writeBothLn('DLZ <filemask>'#13#10#10+
                                   'Receive files from remote');
                   cmdUpLoad_Z: writeBothLn('UP'#13#10#10+
                                 'Send files to remote');
                   cmdCD: writeBothLn('CD [pathname]'#13#13#10+
                            '<pathname> can be one of:'#13#10+
                            ' .. - jump to prev dir'#13#10+
                            '  \ - jump to root');
                   cmdHelp: writeBothLn('HELP [cmd]'#13#13#10+
                             '<cmd> - command U want detailed info about');
                   cmdCopy: writeBothLn('COPY <src> [dest]'#13#13#10+
                             '<src> MUST BE specefied; dos wildcards are allowed'#13#10+
                             '<dest> is a path where files be copied');
                   cmdExit: writeBothLn('EXIT'#13#13#10+
                             'use this command to disconnect before U hangup');
                   cmdRun:  writeBothLn('RUN <program>'#13#13#10+
                             'use this command to execute <program>');
                   cmdDir: writeBothLn('DIR [mask] [switches]'#13#13#10+
                            '<mask> - file, dir or dos filemask'#13#10+
                            '<switches> - recognized swiches:'#13#10+
                            '  /W(ide)  /T (aTtributes)');
                   cmdTime: writeBothLn('TIME [new time]'#13#10+
                             '<new time> - time in format hh:mm[:ss]');
                   cmdDate: writeBothLn('DATE [new date]'#13#10+
                             '<new date> - date in format dd-mm-yyyy');
                   cmdQue: writeBothLn('QUE [cmd]'#13#10+
                            '<cmd> one of:'#13#10+
                            '  /S<f> - set que ');
                   cmdHalt: writeBothLn('HALT [errorlevel]'#13#10+
                             '<errorlevel> - default is 240');
                  else
                   cmdBuf:='';
                  end;
                end;
                if Length(cmdBuf) =0 then begin
                  writeBothLn(#10'∙SfM DoorWay commands summary:'#13#10+
                              CharStr('═',42)+#13#10+
                              ' CD    - change drive/directory'#13#10+
                              ' COpy  - copy files'#13#10+
                              ' DEl   - kill files'#13#10+
                              ' DIr   - display directory contenst'#13#10+
                              ' DLz   - download files via Z-Modem'#13#10+
                              ' EXit  - end session');
                  writeBothLn(' RUn   - execute program');
                  writeBothLn(' HElp  - show this help'#13#10+
                              ' MKdir - create dir'#13#10+
                              ' RMdir - remove empty dir'#13#10+
                              ' TIme  - display/set system time'#13#10+
                              ' DAte  - display/set system date'#13#10+
                              ' QUE   - que manager'+#13#10+
                              ' HALt  - halt Sf-Mail');
                  writeBothLn(CharStr('─',42)+#13#10+
                              '■For details about command type HELP <cmd>'#13#10+
                              CharStr('═',42));
                end;
              end;
     cmdUnknown: writeBothLn('Unknown command `'+cmdStr+#39);
   end;
 end;
 { reinit command prompt }
 doCmd:=false;
 cmdBuf:='';
 chI:=1;
 writeBoth(#13#10+CurrDir+'>');
end;

(*** here insert KEYBCHECK ***)
procedure KeyBcheck;
var
 NeedReDraw:boolean;
 ProcedKey :boolean;

begin
 NeedReDraw:=false;
 repeat
 ProcedKey:=false;
 { Read Keyboard }
 {$IFNDEF NoComm}
 if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
 {$ENDIF}
   if KeyPressed then begin
     ch:=ReadKey;
     ProcedKey:=true;
 {$IFNDEF NoComm}
   end
   else
     IfKeyPress:=0;
 end;

 { Read from modem }
 if not Procedkey then begin
    RByte:=ReadChar;
    If RByte<>TERR_RXEMPTY then begin
       Ch:=Char(RByte);
       If LastPlus and (Ch = '+') then
          {Ignoring '++'}
       else
       ProcedKey:=true;
       If Ch = '+' then LastPlus:=true else LastPlus:=false;
    end;
 end;

 if GetPortStat and ST_DCD =0 then exit;
 {$ELSE}
   end;
 {$ENDIF}

 { Proced Keys }
 If ProcedKey then begin
    If LastZero then begin
       LastZero:=false;
       Case ch of
         (* #$48: {-Up} *)
         #$4B: if chI >1 then begin {-Left}
                 Dec(chI);
                 {$IFNDEF NoComm}
                 SendStr(^V^E);
                 {$ENDIF}
                 NeedReDraw:=true;
               end;
         #$4D: if chI <=Length(CmdBuf) then begin {-Right}
                 Inc(chI);
                 {$IFNDEF NoComm}
                 SendStr(^V^F);
                 {$ENDIF}
                 NeedReDraw:=true;
               end;
         #$53: if chI <=Length(cmdBuf) then begin {-DEL}
                 Delete(cmdBuf,chI,1);
                 NeedReDraw:=true;
                 {$IFNDEF NoComm}
                 SendStr(^V^G+copy(cmdBuf,chI,Length(cmdBuf))+^V^Y#2^V^E+chr(succ(byte(cmdBuf[0]))-chI));
                 {$ENDIF}
               end;
         {---}
         #35: begin
                {$IFNDEF NoComm}
                ClearTxQueue;
                ClearRxQueue;
                Timer:=TimeCounter;
                KillCD;
                {$ENDIF}
                _done:=true;
              end;
       end; {Case}
    end {If LastZero}
    else
    begin
       Case ch of
         #1..#7,#9..#12,#14..#23,#25..#31:;
         #0  : begin
               LastZero:=true;
               {$IFNDEF NoComm}
               Inc(IfKeyPress);
               {$ENDIF}
               end;
         #$0D: begin {-Enter}
                 doCmd:=true;
                 {$IFNDEF NoComm}
                 SendStr(#13#10);
                 {$ENDIF}
                 writeln;
               end;
         #$08: if chI >1 then begin {-BS}
                 Dec(chI);
                 Delete(cmdBuf,chI,1);
                 {$IFNDEF NoComm}
                 if byte(cmdBuf[0]) <chI then
                  SendStr(^V^E+' '+^V^E)
                 else
                  SendStr(^V^E^V^G+copy(cmdBuf,chI,Length(cmdBuf))+^V^Y#2^V^E+chr(succ(byte(cmdBuf[0]))-chI));
                 {$ENDIF}
                 NeedReDraw:=true;
               end;
         #$1B: begin
                 cmdBuf:='';
                 chI:=1;
                 NeedReDraw:=true;
               end;
         else {Case}
         if Length(cmdBuf) <70 then begin
            Insert(ch,cmdBuf,chI);
            Inc(chI);
            {$IFNDEF NoComm}
            if byte(cmdBuf[0])<chI then
             SendStr(ch)
            else
             SendStr(ch+copy(cmdBuf,chI,Length(cmdBuf))+^V^Y#2^V^E+chr(succ(byte(cmdBuf[0])-chI)));
            {$ENDIF}
            NeedReDraw:=true;
         end;
       end; {Case}

    end; {If LastZero else}
 end;
 {$IFNDEF NoComm}
 if Pos('**'#24'B00',cmdBuf)<>0 then begin
   Write(CR);
   ClrEol;
   RecvFiles;
   cmdBuf:='';
   chI:=1;
 end;
 {$ENDIF}
 { Redraw }
 if NeedReDraw then begin
   FastWrite(Pad(CurrDir+'>'+cmdBuf,80),WhereY,1,$7);
   GotoXY(Length(CurrDir)+succ(chI),WhereY);
 end;

 ReleaseTQ;
 until (not ProcedKey) or doCmd;
 ReleaseTQ;
end;

begin
 LastZero:=false;
 LastPlus:=false;
 _done:=false;
 if not SaveWindow(1,1,80,ScreenHeight-1,true,saveWin) then begin
   {$IFNDEF NoComm}
   LogWrite(0,'(?) CAN`T ALLOCATE WINDOW BUFFER',ld_Screen);
   {$ELSE}
   writeBothLn('(?) CAN`T ALLOCATE WINDOW BUFFER');
   {$ENDIF}
   exit;
 end;
 Window(1,1,80,ScreenHeight-1);
 TextAttr:=$07;
 ClrScr;
 { белые буквы на синем фоне }
 {$IFNDEF NoComm}
 SendStr(^L^V^A#$1F+Center('Santa Fox Doorway Shell ver 1.02/beta',80)+
           ^V^A#$0F+CharStr('─',80)+^V^A#7);
 {$ENDIF}
 FastWrite(Center('Santa Fox Doorway Shell ver 1.02/beta',ScreenWidth),1,1,$1F);
 FastWrite(CharStr('─',ScreenWidth),2,1,$0F);

 NormalCursor;

 writeln;
 CmdBuf:='';
 GetDir(0,CurrDir);
 oldDir:=CurrDir;
 DoCommand; { для инициализации }

 if length(pCfgRec^.DoorWayLog)=0 then
   Logging:=false
 else begin
   Logging:=true;
   Assign(DoorLog,pCfgRec^.DoorWayLog);
   Append(DoorLog);
   if IOResult<>0 then Rewrite(DoorLog);
   If IOResult<>0 then Logging:=false;
 end;

 (* MAIN LOOP of CommandCom *)
 repeat
   KeyBcheck;
   if doCmd then DoCommand;
   ReleaseTQ;
 {$IFNDEF NoComm}
 until _done or (GetPortStat and ST_DCD =0);
 {$ELSE}
 until _done;
 {$ENDIF}

 if Logging then begin
   WriteLn(DoorLog,'');
   Close(DoorLog);
   If IOResult<>0 then {clear};
 end;

 (* Restoring previous modes *)
 HiddenCursor;
 TextAttr:=0;
 ClrScr;
 {$IFNDEF NoComm}
 Window(1,1,80,ScreenHeight-1);
 TempClose;
 ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
 {$ELSE}
 Window(3,5,68,19);
 {$ENDIF}
 TextAttr:=$07;
 RestoreWindow(1,1,80,ScreenHeight-1,true,saveWin);
 { restore sturt-up directory }
 ChDir(oldDir);
end;

end.
