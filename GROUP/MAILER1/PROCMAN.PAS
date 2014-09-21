(*** Process Manager for Sf-Mail system ***)

{$X+,O+,F+,I-}
UNIT ProcMan;
(*
 Тpи типа условий:
 - keypress; (нажата клавиша)
    в памяти имеется process_key_set и сначала пpовеpяем,
    есть ли полученный сканкод в этой таблице
    Фоpмат записи:
      key:0F0E   (0F0E - скан-код)
 - received; (пpинято что-то)
    пpинято может быть: netmail, echomail, tic, [?any-file?]
    Фоpмат записи:
      [NetMail EchoMail]
 - xternal mail; (стpока для запpоса внешенего мылеpа)
    в памяти имеется список стpок, по котоpым запускаются
    внешние мылеpы; сначала пpовеpяем наличие полученной
    стpоки в этом списке
    Фоpмат записи:
      xMailer:id_string   (id_string -- получаемая стpока)
 ────────────────────────────────────────────────────────────
 Можно указать под какими ОС pашено выполнять данный пpоцесс.
 По умолчанию -- под всеми (AllOs).

 DOS [KeyPress:011B] Run {!}C:\BBS\Terminal.com
 OS2 [KeyPress:011B] Run {$}C:\SF-MAIL\ShootDn.exe
 OS2,WIN [xMailer]   Run C:\
*)

INTERFACE

uses
 Dos;

const
 MaxXmailID=15;

type
 tProcess=(
  procKeyPress,
  procNetMail,
  procArcMail,
  procTic,
  procAfterSess,
  procAfterFax,
  procFile,
  procFlag,
  procXmail,
  {------}
  procNone
 );

 tProcAction=(
   actSet,
   actRun,
   actDrop,
   actPoll,
   actXit,
   {----}
   actNone
 );

 tProcessRec=record
   (*UnderOs:word;        { under what OSes process active }*)
   ProcScanCode:word;   { only for keypresses }
   ProcMap:longint;     { bitmapped }
   ProcFofs:longint;        { offset in process.ctl (for KeyPress)}
   xmIDstr:string[MaxXmailID];  { id_string for xmailers }
   ProcAction:tProcAction;      { type of action }
   DoWhat:string[$80];  { what we must do when process was activated }
 end;

 { пеpекpывает tProcessRec }
 tProcessRecA=record
   (*UnderOs:word;*)
   ProcScanCode:word;
   ProcMap:longint;
   ProcFofs:longint;
   xmIDstring:string[MaxXmailID];
   ProcAction:tProcAction;
   ErrLvl:word;
 end;

 tProcessInfo=record
   procName:string[11];
   procBit:longint;
 end;

 tFmask=string[12];

const
 MaxXmail=10;
 MaxFmask=32;
 MaxFlag =32;

 firstProc=procKeyPress;
 lastProc=procXmail;

 ProcClass_Key:set of tProcess=[procKeyPress];
 ProcClass_Rcvd:set of tProcess=[procNetMail..procFile];
 ProcClass_xMail:set of tProcess=[procXmail,procFlag];
 {ProcClass_Flag:set of tProcess=[procFlag];}

 ProcessInfo:array[firstProc..lastProc] of tProcessInfo=(
  (procName:'key';     procBit:$0001),
  (procName:'netmail'; procBit:$0002),
  (procName:'arcmail'; procBit:$0004),
  (procName:'tic';     procBit:$0008),
  (procName:'after';   procBit:$0010),
  (procName:'afterfax';procBit:$0020),
  (procName:'file';    procBit:$0040),
  (procName:'flag';    procBit:$0080),
  (procName:'xmailer'; procBit:$0100)
 );

 { маска событий котоpые не гасят биты }
 ProcNonClr=$1 or $40 or $80 or $100;    {keypress,file,flag,xmailer}

var
 xMailStrings:array[1..MaxXmail] of ^string;
 TotalxMail:byte;

 FmaskStr:array[1..MaxFmask] of ^tFmask;
 TotalFmask:byte;
 FmaskBits:longint;
 FlagStr:array[1..MaxFlag] of ^tFmask;
 TotalFlag:byte;

function ProcMan_Init:boolean;

procedure ProcMan_Done;

function ProcMan_Req4act(PClass:tProcess;
                         Condit:longint;
                         xmStr:string;
                         scanCode:word;
                         write2log:boolean):boolean;

procedure CheckUserSem;
{ если опpеделены в файле пpоцессов семафоpы,}
{ выполняет соответсвующие действия }

function ProcMan_UserMenu:boolean;

IMPLEMENTATION

uses
 Tstring_,
 WriteLog,
 Config,
 RelTq,
 SwapR,
 EmStruct,
 SfM_Cfg,
 MsgXs,
 Sf_Init,
 TpCrt,
 TpWindow,
 TpDos,
 Flags,
 Em_Cpl,
 EventMan,
 Sf_Pick;

type
 pUMenuItem=^tUMenuItem;
 tUMenuItem=record
   ItemStr:string[MaxItemLen];
   Procs:tProcessRec;
   NextItem:pUMenuItem;
 end;

const
 sProcAction:array[actSet..actXit] of string[4]=(
  'set',
  'run',
  'drop',
  'poll',
  'xit'
 );

 MaxProcKey=20;

var
 fProc:file of tProcessRec;
 Process:tProcessRec;
 ProcessA:tProcessRecA absolute Process;
 ScanCodes:array[1..MaxProcKey] of word;
 TotalScanCodes:byte;

procedure ProcMan_Done;
var
 z:byte;

begin
 for z:=1 to TotalXmail do
   FreeMem(xMailStrings[z],Length(xMailStrings[z]^)+1);
 for z:=1 to TotalFmask do
   FreeMem(FmaskStr[z],Length(FmaskStr[z]^)+1);
 for z:=1 to TotalFlag do
   FreeMem(FlagStr[z],Length(FlagStr[z]^)+1);
 TotalXmail:=0;
 TotalFmask:=0;
 TotalFlag:=0;
 TotalScanCodes:=0;
end;

function WhatAction(sAct:string):tProcAction;
var
 act:tProcAction;

begin
 for act:=actSet to actXit do
   if sProcAction[act] =sAct then begin
     WhatAction:=act;
     exit;
   end;
 WhatAction:=actNone;
end;

procedure AddScanCode;
var
 x:byte;

begin
 for x:=1 to TotalScanCodes do
   if ScanCodes[x] =Process.ProcScanCode then exit;
 Inc(TotalScanCodes);
 ScanCodes[TotalScanCodes]:=Process.ProcScanCode;
end;

function RecompileProcesses:boolean;
var
 f:text;
 s:string;
 s1:string;
 o:integer;
 xmStr:string;
 ProcFofs:longint;

function WhatProcess(prs:string):boolean;
var
 lProc:tProcess;
 s_:string;

begin
 WhatProcess:=false;
 {WRITELOGALL('['+prs+']');}
 if Pos(':',prs) <>0 then begin { это м.б.: keypress,xmailer,file,flag}
   s_:=ExtractWord(2,prs,[':']);  {-mask}
   prs:=ExtractWord(1,prs,[':']); {-procname}
 end;
 prs:=StLoCase(prs);
 for lProc:=firstProc to lastProc do
   if ProcessInfo[lProc].procName =prs then with Process, ProcessInfo[lProc] do begin
     procMap:=procMap or procBit;
     if lProc in [procXmail,procFile,procFlag] then begin
       if Length(s_) =0 then exit;
       if lProc =procXmail then s_:=copy(s_,1,MaxxMailId)
       else s_:=StLoCase(copy(s_,1,pred(SizeOf(tFmask))));
       xmIDstr:=s_;
     end
     else
      if lProc in ProcClass_Key then begin
        Val('$'+s_,procScanCode,o);
        {Str2word('$'+s_,procScanCode);}
        {WRITELOGALL('str: `'+s_+#39'; sc: $'+HexW(procscancode));}
        if (TotalScanCodes <MaxProcKey) then AddScanCode;
      end;
     WhatProcess:=true;
     exit;
   end;
end;

procedure ParseProcStr;
var
 i:byte;
 ii:byte;

begin
 { под какими ОС будет pаботать}
 if not CheckLineAndOs(s) or (Length(s) =0) then exit;
 s1:=ExtractWord(1,s,['[',']']);
 { имена условий..}
 {WRITELOGALL('>>>'+StLoCase(ExtractWord(1,s,[' ',^I]))+'<<<');}
 Process.ProcAction:=WhatAction(StLoCase(ExtractWord(2,s,[#0])));

 if Process.ProcAction =actXit then begin
   if not Str2word(ExtractWord(3,s,[#0]),ProcessA.ErrLvl) then
     Process.ProcAction:=actNone;
 end
 else
   Process.DoWhat:=ExtractWord(3,s,[#0]);
 { паpсим условия..}
 for i:=1 to WordCount(s1,[',']) do
   if not WhatProcess(ExtractWord(i,s1,[','])) then exit;  { fault }
 { === }
 if (Process.ProcMap <>0) and (Process.ProcAction <>actNone) then begin
   write(fProc,Process);
   if (Length(Process.xmIDstr) <>0) then with Process do
     if (ProcMap and ProcessInfo[procXmail].procBit <>0) and
        (TotalXmail <MaxXmail) then begin
       Inc(TotalXmail);
       GetMem(xMailStrings[TotalXmail],Length(xmIDstr)+1);
       Move(xmIDstr[0],xMailStrings[TotalXmail]^,Length(xmIDstr)+1);
     end
     else
      if (ProcMap and ProcessInfo[procFlag].procBit <>0) and
         (TotalFlag <MaxFlag) then begin
        Inc(TotalFlag);
        GetMem(FlagStr[TotalFlag],Length(xmIDstr)+1);
        FlagStr[TotalFlag]^:=xmIDstr;
      end
      else
       if (ProcMap and ProcessInfo[procFile].procBit <>0) and
          (TotalFmask <MaxFmask) then begin
         Inc(TotalFmask);
         GetMem(FmaskStr[TotalFmask],Length(xmIDstr)+1);
         {Move(xmIDstr[0],FmaskStr[TotalFmask]^,Length(xmIDstr)+1);}
         FmaskStr[TotalFmask]^:=xmIDstr;
       end;
 end;
end;

begin
 { initializing..}
 TotalScanCodes:=0;
 TotalXmail:=0;
 TotalFmask:=0;
 TotalFlag:=0;
 { processing..}
 LogWrite(imInitProcman,'',ld_Screen);
 RecompileProcesses:=false;
 FileMode:=$20;
 assign(f,pCfgRec^.Processes);
 reset(f);
 FileMode:=$2;
 if IoResult <>0 then begin
   LogWrite(emCantOpen,pCfgRec^.Processes,ld_All);
   exit;
 end;
 FileMode:=$10;
 assign(fProc,ForceExtension(pCfgRec^.Processes,binXt));
 rewrite(fProc);
 FileMode:=$2;
 repeat
   FillChar(Process,SizeOf(tProcessRec),0);
   Process.ProcFofs:=TextPos(f);   { смещение в файле Process.ctl }
   readln(f,s);
   if IoResult <>0 then begin
     LogWrite(emReadError,pCfgRec^.Processes,ld_All);
     close(f);
     o:=IoResult;
     close(fProc);
     o:=IoResult;
     erase(fProc);
     o:=IoResult;
     exit;
   end;
   s:=PrepareLine(s,NumTokens);
   if Length(s) <>0 then ParseProcStr;
 until EOF(f);
 close(fProc);
 close(f);
 o:=IoResult;
 RecompileProcesses:=true;
end;

function ProcMan_Init:boolean;
begin
 ProcMan_Init:=false;
 if Length(pCfgRec^.Processes) =0 then begin
   LogWrite(emUndefinedPM,'',ld_All);
   exit;
 end;
 ProcMan_Init:=RecompileProcesses;
end;

function ProcMan_Do(var Condit:longint; write2log:boolean):boolean;
var
 i:byte;
 A:tAddress;

begin
 case Process.ProcAction of
  actSet: begin
            EventStr:=PrepareLine(Process.DoWhat,NumTokens);
            AtRunTime:=true;
            LogWrite(imProcSet,Process.DoWhat,ld_All);
            ParseSingleWord(EventStr);
          end;
  actRun: begin
           Os2title:='SF: '+Process.DoWhat;
           Swap_Run(Process.DoWhat,write2log);
          end;
  actXit: begin
            Done;  {Sf_Init.Done == полный шут-даун}
            Halt(ProcessA.ErrLvl);
          end;
  actDrop: begin
            if write2log then
             LogWrite(imProcDrop,Process.DoWhat,ld_All);
            EventStr:=Process.DoWhat;
            DoDrop;
           end;
  actPoll: with Process do begin
            Move(MainAddress,A,SizeOf(tAddress));
            if write2log then
             LogWrite(imProcPoll,DoWhat,ld_All);
            SetDefaultAddr(pCfgRec^.MyAddress[1],false);
            for i:=1 to WordCount(DoWhat,[',']) do
             if xStr2addr(ExtractWord(i,DoWhat,[',']),A) then
              GeneratePoll(A);
           end;
 end;
 { change bits..}
 Condit:=Condit and (not (Process.procMap and (not ProcNonClr)));
 {if not (PClass in ProcClass_Key) then Condit:=Condit xor Process.procMap;}
 ProcMan_Do:=true;
end;

function ProcMan_Req4act(PClass:tProcess;
                         Condit:longint;
                         xmStr:string;
                         scanCode:word;
                         write2log:boolean):boolean;
var
 procSiz:longint;
 procPos:longint;
 o:longint;
 nFl:byte;

function Search4ScanCode:boolean;
var
 i:byte;

begin
 Search4scanCode:=true;
 for i:=1 to TotalScanCodes do
   if ScanCodes[i] =ScanCode then exit;
 Search4scanCode:=false;
 {WRITELOGALL('(!) scancode ['+HexW(scanCode)+'] unknown by the_em');}
end;

begin
 nFl:=0;
 ProcMan_Req4act:=false;
 if PClass in ProcClass_Key then
   if not Search4ScanCode then exit;   { this code can not be processed }
 ProcPos:=0;
 repeat
   FileMode:=$20;
   assign(fProc,ForceExtension(pCfgRec^.Processes,binXt));
   reset(fProc);
   FileMode:=$2;
   procSiz:=FileSize(fProc);
   if procSiz =0 then begin
     LogWrite(emProcStructCorr,'',ld_All);
     close(fProc);
     o:=IoResult;
     exit;
   end;
   seek(fProc,procPos);
   read(fProc,Process);
   Inc(procPos);
   close(fProc);
   if (Process.ProcMap and Condit) =Process.ProcMap then begin
     if PClass in ProcClass_Key then begin
      if scanCode =Process.procScanCode then
       ProcMan_Req4act:=ProcMan_Do(Condit,write2log);
     end
     else
      if PClass in ProcClass_xMail then begin
       if Process.xmIDstr =copy(xmStr,1,MaxXmailID) then
        ProcMan_Req4act:=ProcMan_Do(Condit,write2log);
      end
      else
       if (Process.procMap and ProcessInfo[procFile].procBit <>0) and
          (Condit and ProcessInfo[procFile].procBit <>0) then begin
        if (FmaskBits and (1 shl nFl)) <>0 then
          ProcMan_Req4act:=ProcMan_Do(o,write2log);
       end
       else
        ProcMan_Req4act:=ProcMan_Do(Condit,write2log);
   end;
   if Condit =0 then procPos:=succ(procSiz);
   if Process.procMap and ProcessInfo[procFile].procBit <>0 then
     Inc(nFl);
   if nFl >TotalFmask then
     Condit:=Condit and (not ProcessInfo[procFile].procBit);
   {-> WRITELOGALL('(D) Condit=$'+HexL(Condit)); <-}
 until procPos >=procSiz;
 if FileRec(fProc).Mode <>fmClosed then close(fProc);
 procPos:=IoResult;
 if Condit and ProcessInfo[procFile].procBit <>0 then FmaskBits:=0;
end;

procedure CheckUserSem;
{ если опpеделены в файле пpоцессов семафоpы,}
{ выполняет соответсвующие действия }
var
 f:file;
 z:byte;

begin
 if TotalFlag <>0 then with pCfgRec^ do
   for z:=1 to TotalFlag do
     if ExistFile(Flags_Dir+FlagStr[z]^) then begin
       LogWrite(imSemDetected,FlagStr[z]^,ld_All);
       ProcMan_Req4act(procFlag,ProcessInfo[procFlag].procBit,
                       FlagStr[z]^,0,true);
       if DeleteFlag(Flags_Dir+FlagStr[z]^) then
        LogWrite(imSemKilled,FlagStr[z]^,ld_All)
       else
        LogWrite(emCantKill,FlagStr[z]^,ld_All);
     end;
end;

procedure DrawUMenuItem(n:word; y:byte; width:byte; sel:boolean);
var
 i:integer;
 p:pointer;

begin
 with pCfgRec^ do
  if n >PickItems then
   FastWriteWindow(CharStr(' ',width),y,1,SfMailColors[pl_Item])
  else begin
   p:=PickHead;
   for i:=2 to n do
    p:=pUMenuItem(p)^.NextItem;
   if sel then
    i:=SfMailColors[pl_Marker]
   else
    i:=SfMailColors[pl_Item];
   FastWriteWindow(Pad(' '+pUMenuItem(p)^.ItemStr,width),y,1,i);
  end;
end;

function ProcMan_UserMenu:boolean;
var
 Wnd:WindowPtr;
 f:text;
 TopItem,
 CurItem:integer;
 DrawList:boolean;
 s:string;
 ItemLen:byte;

begin
 if TotalScanCodes =0 then exit;

 assign(fProc,ForceExtension(pCfgRec^.Processes,binXt));
 reset(fProc);
 assign(f,pCfgRec^.Processes);
 reset(f);
 ItemLen:=0;
 repeat
   read(fProc,Process);
   if (Process.procMap and ProcessInfo[procKeyPress].procBit) <>0 then begin
     TextSeek(f,Process.ProcFofs);
     readln(f,s);
     s:=Trim(s);
     if Pos(';',s) <>0 then
       s:=copy(s,succ(Pos(';',s)),MaxItemLen)
     else
       s:='{'+HexW(Process.procScanCode)+'} '+
          TrimLead(copy(s,succ(Pos(']',s)),MaxItemLen));
     { запоминаем пункт меню }
     if ItemLen <Length(s) then ItemLen:=Length(s);
     Inc(PickItems);
     if PickHead =nil then begin
      GetMem(PickHead,SizeOf(tUMenuItem));
      PickTail:=PickHead;
     end
     else begin
      GetMem(pUMenuItem(PickTail)^.NextItem,SizeOf(tUMenuItem));
      PickTail:=pUMenuItem(PickTail)^.NextItem;
     end;
     with pUMenuItem(PickTail)^ do begin
      Move(Process,Procs,SizeOf(tProcessRec));
      ItemStr:=s;
     end;
   end;
 until EOF(fProc);

 close(fProc);
 close(f);

 if PickItems =0 then exit;

 with pCfgRec^ do begin
   if PickItems >=10 then
    CurItem:=14
   else
    CurItem:=PickItems+4;
   MakeWindow(Wnd,2,3,ItemLen+6,CurItem,true,true,true,
              SfMailColors[pl_Item],SfMailColors[pl_Border],
              SfMailColors[pl_Header],' User menu ');
   DisplayWindow(Wnd);

   ItemLen:=0;
   TopItem:=1;
   CurItem:=1;
   DrawProc:=@DrawUMenuItem;
   DrawList:=true;

   repeat
     PickBar(wnd,DrawList,true,PickItems,CurItem,TopItem);
   until PickExit in [peQuit,peSelect];
 end; (*WITH pCFGREC^*)
 PickTail:=PickHead;
 for TopItem:=1 to PickItems do begin
  if TopItem =CurItem then
   Move(pUMenuItem(PickTail)^.Procs,Process,SizeOf(tProcessRec));
  PickHead:=pUMenuItem(PickTail)^.NextItem;
  FreeMem(PickTail,SizeOf(tUMenuItem));
  PickTail:=PickHead;
 end;
 KillWindow(wnd);
 PickHead:=nil;
 PickTail:=nil;
 PickItems:=0;
 if PickExit =peSelect then begin
  ProcMan_Do(Process.ProcMap,true);
  WaitMsg;
 end;
end;

end.
