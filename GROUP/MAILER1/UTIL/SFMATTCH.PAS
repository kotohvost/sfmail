(*******************************)
(*** The File Attach utility ***)
(***   for Sf-Mail system    ***)
(*******************************)

{$X+,I-,V-}

program SfMattch;

uses
 Dos,
 TpDos,
 Cfg,
 ReadCfg,
 SfM_Api,
 Tstring_;

const
 PID='The SfM`s Attach utility';
 VID='ver 0.3.2';
 CID='(c) Anton Deinow, UNIVERSAL SOFTWARE Inc, 1996';

 sCfgState:array[tRCS] of string[25]=(
  'Ok',
  'Config file not found',
  'Config I/O error',
  'Recompile config',
  'Invalid cfg version',
  'Cfg is not for current OS'
 );

type
 AttachControl=record
  toAddr:tAddress;     {на какой адpес}
  toName:string[35];   {кому}
  fromName:string[35]; {от кого}
  Hld:boolean;         {холдить?}
  KFS:boolean;         {ставить ли EraseAfterSent}
  DIR:boolean;         {диpектом пойдет?}
  BOX:boolean;         {pежим FileBox?}
  xLO:boolean;         {pежим Bink ?.LO}
  fName2send:PathStr;  {маска файлов для отпpавки}
 end;

 tBuf=array[1..57344] of byte;

var
 CfgFname:PathStr;
 AC:AttachControl;
 sr:SearchRec;
 f:text;
 i:byte;
 s:string;
 CmdLine:string[120];
 CmdFname:PathStr;
 w:word;

type
 tIE=(
  ieInvalidAddress,
  ieUnableLoadCfg,
  ieInvalidSwitch,
  ieCantReadCmd,
  ieNoFileSpec,

  ieFileNotFound,
  ieNoFileBoxes,
  ieNoBinkOb,
  ieNoAma,
  ieAddrBusy,
  ieCantCreateFile,
  ieCantOpenFile,
  ieCantReName
 );

const
 IEfatal:Set of tIE =[ieInvalidAddress..ieNoFileSpec];

procedure Usage;
begin
 writeln('USAGE:'#13#10);
 writeln(' SfmAttch [/cConfig] [/nL] [Switches] <FileNames> <ToAddr> [from_Name to_Name]'+
         #13#10'or');
 writeln(' SfmAttch [/cConfig] [/nL] <@CmdFile>'#13#10);
 writeln('  /cConfig - name of Sf-Mail`s ascii config file'#13#10+
         '             (default: sf-mail.cfg in current dir)');
 writeln('  /nL      - line number (default: 0)'#13#10);
 writeln(' Available switches are:'#13#10+
         '  -H  -  hold'#13#10+
         '  -K  -  erase/sent'#13#10+
         '  -B  -  filebox mode');
 writeln('  -D  -  direct'#13#10+
         '  -L  -  bink ?lo mode'#13#10);
 halt(253);
end;

procedure InternalErr(ie:tIE; s:string);
begin
 case ie of
  ieInvalidAddress: s:='Invalid destination address `'+s+#39;
  ieUnableLoadCfg: s:='Unable to load configuration from `'+s+#39;
  ieInvalidSwitch: s:='Invalid command line switch `'+s+#39;
  ieNoFileSpec: s:='No files specified, aborting';
  ieCantReadCmd: s:='Unable to read Cmd-file `'+s+#39;

  ieFileNotFound: s:='File `'+s+#39+' not found';
  ieNoFileBoxes: s:='FileBoxes host directory is not defined';
  ieNoBinkOb: s:='Bink mode is not allowed';
  ieNoAma: s:='Ama mode is not allowed';
  ieAddrBusy: s:='Address '+s+' is occuped by other process';
  ieCantCreateFile: s:='Unable to create output file `'+s+#39;
  ieCantOpenFile: s:='Unable to open `'+s+#39;
  ieCantReName: s:='Can not rename '+s;
 end;

 writeln('(!) '+s,^G);

 if ie in IEfatal then halt(251);
end;

procedure ConvertName(var sn:string);
begin
 while Pos('_',sn) <>0 do sn[Pos('_',sn)]:=' ';
end;

function GetUniqueFname(oldFname:PathStr):PathStr;
{-создает уникальное имя, если уже существует файл oldFname}
{ ['0'..'9','a'..'z'] }
var
 f:file;
 _done:boolean;
 c:char;
 sl:byte absolute oldFname;

begin
 if ExistFile(oldFname) then begin
   _done:=false;
   oldFname[sl]:=LoCase(oldFname[sl]);
   c:=oldFname[sl];
   repeat
     Inc(byte(oldFname[sl]));
     if oldFname[sl] >'z' then oldFname[sl]:='0'
     else
      if oldFname[sl] =':' then oldFname[sl]:='a';
     {---}
     if not ExistFile(oldFname) then _done:=true
     else
       if oldFname[sl] =c then begin
         _done:=true;
         assign(f,oldFname);
         erase(f);
       end;
   until _done;
   if IoResult <>0 then;
 end;
 GetUniqueFname:=oldFname;
end;

function Find_1st(var fName:PathStr):boolean;
{-веpнет TRUE и имя файла, если найден пеpвый файл}
begin
 {$I+}
 FindFirst(AC.fName2send,AnyFile-Directory-VolumeID,sr);
 {$I-}
 Find_1st:=DosError =0;
 if DosError =0 then begin
   fName:=JustPathName(AC.fName2send);
   if not (fName[Length(fName)] in ['\',':']) then
     fName:=fName+'\';
   fName:=fName+sr.Name;
 end;
end;

function Find_Next(var fName:PathStr):boolean;
begin
 {$I+}
 FindNext(sr);
 {$I-}
 Find_Next:=DosError =0;
 if DosError =0 then begin
   fName:=JustPathName(AC.fName2send);
   if not (fName[Length(fName)] in ['\',':']) then
     fName:=fName+'\';
   fName:=fName+sr.Name;
 end;
end;

procedure FileBoxAttach;
var
 fIn,fOut:file;
 InFname,
 OutFname:PathStr;
 OutName:PathStr;
 Buf:^tBuf;
 BufSiz:word;
 l:longint;
 o:integer;
 rd,wt:word;

begin
 with AC do begin
    if not Find_1st(InFname) then begin
      InternalErr(ieFileNotFound,fName2send);
      exit;
    end;

    OutFname:=FileBoxName(toAddr,Hld);
    MkAllDir(OutFname,true);

    if KFS and (InFname[2] =':') and (OutFname[2] =':') and
       (LoCase(InFname[1]) =LoCase(OutFname[1])) then begin
      repeat
        assign(fIn,InFname);
        OutName:=GetUniqueFname(OutFname+JustFileName(InFname));
        rename(fIn,OutName);
        if IoResult <>0 then
          InternalErr(ieCantReName,InFname+' -> '+OutName)
        else
          writeln('■ File '+InFname+' moved (via rename)'#13#10'  into FileBox '+
                  OutFname+#13#10'  for '+_4D2str(toAddr));
      until not Find_Next(InFname);
    end
    else begin
      BufSiz:=SizeOf(tBuf);
      if MaxAvail <BufSiz then BufSiz:=MaxAvail;
      GetMem(Buf,BufSiz);

      repeat
        assign(fIn,InFname);
        reset(fIn,1);
        if IoResult <>0 then
          InternalErr(ieCantOpenFile,InFname)
        else begin
          GetFtime(fIn,l);
          OutName:=GetUniqueFname(OutFname+JustFileName(InFname));
          assign(fOut,OutName);
          rewrite(fOut,1);
          if IoResult <>0 then
            InternalErr(ieCantCreateFile,OutName)
          else begin
           repeat
             BlockRead(fIn,Buf^,BufSiz,rd);
             BlockWrite(fOut,Buf^,rd,wt);
           until rd <BufSiz;
           write('■ File '+InFname);
           close(fIn);
           if KFS then begin
             erase(fIn);
             o:=IoResult;
             writeln(' moved');
           end
           else
            writeln(' copied');
           writeln('  into FileBox '+OutFname+
                   #13#10'  for '+_4D2str(toAddr));
           SetFtime(fOut,l);
           close(fOut);
           o:=IoResult;
          end;
        end;
      until not Find_Next(InFname);
      FreeMem(Buf,BufSiz);
    end;
 end;
end;

function NewMsgName:word;
{-возвpащяет No для создаваемого письма}
var
 Di:SearchRec;
 n1,n2:word;

begin
 n1:=0;
 n2:=0;

 {$I+}
 FindFirst(pCfgRec^.NetMail+'*.msg', Archive, Di);
 while DosError =0 do begin
   Str2word(Copy(Di.Name,1,pred(Pos('.',Di.Name))),n1);
   if n1 >n2 then n2:=n1;
   FindNext(Di);
 end;

 NewMsgName:=succ(n2);
 {$I-}
end;

procedure MsgAttach;
var
 MsgFname:PathStr;
 MsgNo:word;
 fMsg:file;
 MyAddr:tAddress;
 InFname:PathStr;
 l:longint;
 attr:word;
 ok:boolean;
 BiosClock:longint absolute $40:$6C;

begin
 with AC do begin
  if not Find_1st(InFname) then begin
    InternalErr(ieFileNotFound,fName2send);
    exit;
  end;

  MyAddr:=toAddr;
  MatchAkA(MyAddr);

  attr:=$0001+  {Private}
        $0010+  {Attach}
        $0080+  {Kill/sent}
        $0100;  {Local}

  if Hld then
    attr:=attr or $0200;  {Hold}

  repeat
   CreateMsgTimeStamp(l);

   s:=PadCh(fromName,#0,36)+
    PadCh(toName,#0,36)+
    PadCh(InFname,#0,72)+
    Pad(MsgDateStamp,19)+#0+
    #0#0+  {timesread}
    Chr(Lo(toAddr.Node))+  Chr(Hi(toAddr.Node))+
    Chr(Lo(MyAddr.Node))+  Chr(Hi(MyAddr.Node))+
    #0#0+  {cost}
    Chr(Lo(MyAddr.Net))+   Chr(Hi(MyAddr.Net))+
    Chr(Lo(toAddr.Net))+   Chr(Hi(toAddr.Net))+
    chr(l)+chr(l shl 8)+chr(l shl 16)+chr(l shl 24)+
    #0#0#0#0+  {msgarrived}
    #0#0+      {reply}
    Chr(Lo(attr))+    Chr(Hi(attr))+
    #0#0;       {seealso}

   MsgNo:=NewMsgName;
   MsgFname:=pCfgRec^.NetMail+Long2str(MsgNo)+'.msg';

   assign(fMsg,MsgFname);
   rewrite(fMsg,1);
   BlockWrite(fMsg,s[1],Length(s));

   s:=^A'FMPT '+Long2str(MyAddr.Point)+
      #13^A'TOPT '+Long2str(toAddr.Point)+
      #13^A'INTL '+_4D2str(toAddr)+' '+_4D2str(MyAddr)+
      #13^A'MSGID: '+_4D2str(MyAddr)+' '+HexL(l xor BiosClock)+
      #13^A'PID: '+PID+' '+VID;

   if KFS then begin
     s:=s+#13^A'FLAGS KFS';
     ok:=true;
   end;

   if DIR then
     if not ok then
       s:=s+#13^A'FLAGS DIR'
     else
       s:=s+' DIR';

   s:=s+#13#0;

   BlockWrite(fMsg,s[1],Length(s));

   close(fMsg);

   write('■ File '+InFname+#13#10+
         '  to address '+_4D2str(toAddr));
   if KFS or DIR or Hld then begin
     write('  (');
     if KFS then write(' KFS ');
     if DIR then write(' DIR ');
     if Hld then write(' HLD ');
     write(')');
   end;
   writeln;
  until not Find_Next(InFname);
 end;
end;

procedure BinkLoAttach;
var
 InFname,
 pth:PathStr;
 f:text;
 c:char;
 s:string;

begin
 with AC do begin
  Path4addr(true,toAddr,pth);
  if ExistFile(pth+'.bsy') then
   InternalErr(ieAddrBusy,_4D2str(toAddr))
  else
   if not Find_1st(InFname) then
    InternalErr(ieFileNotFound,fName2send)
   else begin
    if Hld then begin
     c:='h';
     s:='HOLD';
    end
    else
     if DIR then begin
      c:='d';
      s:='DIRECT';
     end
     else begin
      c:='f';
      s:='NORMAL';
     end;
    MkAllDir(JustPathname(pth),true);
    assign(f,pth+'.'+c+'lo');
    append(f);
    if IoResult <>0 then begin
     rewrite(f);
     write('* Create '+s+' lo');
    end
    else
     write('* Found existing '+s+' lo');
    writeln(' for '+_4D2str(toAddr));
    repeat
     write('■ File '+InFname+#13#10+
           '  to address '+_4D2str(toAddr));
     if KFS then begin
      InFname:='^'+InFname;
      writeln(' (KFS)');
     end;
     writeln(f,InFname);
    until not Find_Next(InFname);
    close(f);
   end;
 end;
end;

procedure AttachFile;
begin
 with pCfgRec^ do
  if AC.BOX then
   {==FILEBOX MODE==}
   if Length(File_Boxes) =0 then
    InternalErr(ieNoFileBoxes,'')
   else
    FileBoxAttach
  else
   if AC.xLO then
    {==BINK ?LO MODE==}
    if Length(BinkOutbound) =0 then
     InternalErr(ieNoBinkOb,'')
    else
     BinkLoAttach
   else
    {==MSG-ATTACH MODE==}
    if (SysFlags and amaPack) =0 then
     InternalErr(ieNoAma,'')
    else
     MsgAttach;
end;

procedure ProcessCmdLine;
var
 i:byte;

begin
 FillChar(AC,SizeOf(AttachControl),0);

 i:=1;  (*   WRITELN('CmdLine = {'+CmdLine+'}'); *)

 repeat
   s:=ExtractWord(i,CmdLine,[' ',^I]);
   if s[1] ='-' then
     case LoCase(s[2]) of
      'h': AC.Hld:=true;
      'k': AC.KFS:=true;
      'b': AC.BOX:=true;
      'd': AC.DIR:=true;
      'l': AC.xLO:=true;
     else
      InternalErr(ieInvalidSwitch,s)
     end
   else with AC do begin
     fName2send:=s; {ExtractWord(i,CmdLine,[' ',^I]);}
      {if Length(fName2send) =0 then
        InternalErr(ieNoFileSpec,'');}

     if not xStr2addr(ExtractWord(i+1,CmdLine,[' ',^I]),pCfgRec^.MyAddress[1],toAddr) then
       InternalErr(ieInvalidAddress, _4D2str(toAddr) {ExtractWord(i+1,CmdLine,[' ',^I])} );

     fromName:=ExtractWord(i+2,CmdLine,[' ',^I]);
     if Length(fromName) =0 then
       fromName:=pCfgRec^.SysOp
     else
       ConvertName(fromName);

     toName:=ExtractWord(i+3,CmdLine,[' ',^I]);
     if Length(toName) =0 then
       toName:='System Operator'
     else
       ConvertName(toName);

     i:=20;
   end;

   Inc(i);
 until i >WordCount(CmdLine,[' ',^I]);

 with AC do begin
   with toAddr do
   if (Zone =0) or (Net =0) then begin
     InternalErr(ieInvalidAddress,_4D2str(toAddr));
     exit;
   end;
   if Length(fName2send) =0 then begin
     InternalErr(ieNoFileSpec,'');
     exit;
   end;
 end;

 if Length(JustPathName(AC.fName2send)) =0 then begin
   GetDir(0,s);
   AC.fName2send:=s+'\'+AC.fName2send;
 end;

 AttachFile;
end;

procedure ProcessCmdFile;
begin
 writeln('Using cmd-file `'+CmdFname+#39'..');

 assign(f,CmdFname);
 reset(f);
 if IoResult <>0 then
   InternalErr(ieCantReadCmd,CmdFname);

 repeat
   readln(f,CmdLine);
   if Pos('#',CmdLine) <>0 then
     CmdLine:=Copy(CmdLine,1,Pos('#',CmdLine)-1);
   if Length(CmdLine) <>0 then
     ProcessCmdLine;
 until EOF(f);

 close(f);
end;

var
 rcs:tRCS;

begin
 writeln(#10+PID+'; '+VID+#13#10+CID+#10);
 if ParamCount =0 then Usage;

 CfgFname:='sf-mail.cfg';
 CmdFname:='';
 CmdLine:='';

 for i:=1 to ParamCount do begin
   s:=ParamStr(i);
   if s[1] ='@' then
    CmdFname:=copy(s,2,Length(s))
   else
    if Pos('/c',StLoCase(s)) =1 then
     CfgFname:=copy(s,3,127)
    else
     if Pos('/n',StLoCase(s)) =1 then begin
      if Str2word(copy(s,3,2),w) then
       Task:=w;
     end
     else
      CmdLine:=CmdLine+' '+s
 end;
 CmdLine:=TrimLead(CmdLine);

 rcs:=Read_Config(CfgFname);
 if rcs <>rcsOk then begin
  writeln(sCfgState[rcs]+^G);
  halt(251);
 end;

 if Length(CmdFname) <>0 then
  ProcessCmdFile
 else
  ProcessCmdLine;
end.
