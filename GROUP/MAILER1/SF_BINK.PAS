(*
  Sf-Mail`s bink-mode stuff
  Copyrught (C) Anton the Deinow, 1995
  All rights reserved.
*)

{$X+,I-,O+,F+,V-}

UNIT Sf_Bink;

INTERFACE

uses
 Dos,
 Config;

procedure ScanOutbound(bink:boolean; forMask:boolean);
procedure GenerateBinkPoll(var A:tAddress);
procedure GenerateBinkFReq(var A:tAddress; var sreq:string);
procedure GenerateBinkAttch(var A:tAddress; var fName:PathStr; _kfs,_hld:boolean);
procedure FromBinkOutbound(hld:boolean; nAkA:byte);
procedure ScanNamedPolls;

IMPLEMENTATION

uses
 SFInclud,
 TpDos,
 busy,
 tString_,
 MsgXs,
 fileMan,
 WriteLog,
 EmStruct,
 Em_Cpl,
 FbMan,
 Flags;

type
 tFSM=(fsm_KFS,fsm_TFS);
 tLOmode=(lo_Normal,lo_Direct,lo_Crash,lo_Imm,lo_Hold, lo_Hmm);

Type  { for FindFirst/FindNext }
  SearchPos = record
    Name : String[12];
    Next : pointer;
  end;
  pSearchPos = ^SearchPos;

const
                             {normal direct crash imm hold}
 LO_mode:array[lo_Normal..lo_Hold] of char=('f',  'd',    'c',  'i','h');
 UT_mode:array[lo_Normal..lo_Hold] of char=('o',  'd',    'c',  'i','h');
 { file send mode }
 cFSM:array[tFSM] of char=('^','#'); { else == NORMAL (don`t tourch) }

procedure GenerateBinkPoll(var A:tAddress);
var
 pth:PathStr;
 f:file;

begin
 Path4addr(true,A,pth);
 if ExistFile(pth+'.bsy') then
  LogWrite(wmBusyFor,Addr2str(A,true),ld_All)
 else with pCfgRec^ do begin
  if ExistFile(pth+'.'+BinkPollXt) then
   LogWrite(wmBinkPollSkipped,BinkPollXt+#3+Addr2str(A,true),ld_All)
  else begin
   MkAllDir(JustPathname(pth));
   assign(f,pth+'.'+BinkPollXt);
   rewrite(f,1);
   close(f);
   if IoResult <>0 then;
   LogWrite(imGenBinkPoll,BinkPollXt+#3+Addr2str(A,true),ld_All);
   bink_ScanCircle:=0;
  end;
 end;
end;

procedure GenerateBinkFReq(var A:tAddress; var sreq:string);
var
 pth:PathStr;
 f:text;
 i,z:byte;
 s,s1:string;

begin
 Path4addr(true,A,pth);
 if ExistFile(pth+'.bsy') then
  LogWrite(wmBusyFor,Addr2str(A,true),ld_All)
 else begin
  MkAllDir(JustPathname(pth));
  assign(f,pth+'.req');
  append(f);
  if IoResult <>0 then rewrite(f);
  {---}
  s:='';
  z:=WordCount(sreq,[' ']);
  i:=1;
  repeat
    s1:=ExtractWord(i,sreq,[' ']);
    if s1[1] ='|' then s1[1]:='!';
    if s1[1] ='!' then
     if Length(s1) <>1 then begin
       s:=s+' '+s1;
       Inc(i);
     end
     else begin
       s:=s+' !'+ExtractWord(i+1,sreq,[' ']);
       Inc(i,2);
     end
    else begin
      if i =1 then s:=s1
      else s:=s+#13#10+s1;
      Inc(i);
    end;
  until i >z;
  writeln(f,s);
  close(f);
  if IoResult <>0 then;
  LogWrite(imGenBinkFReq,Addr2str(A,true),ld_All);
 end;
end;

procedure GenerateBinkAttch(var A:tAddress; var fName:PathStr; _kfs,_hld:boolean);
var
 f:text;
 pth:PathStr;

begin
 Path4addr(true,A,pth);
 if ExistFile(pth+'.bsy') then
  LogWrite(wmBusyFor,Addr2str(A,true),ld_All)
 else begin
  MkAllDir(JustPathname(pth));
  if _hld then pth:=pth+'.hlo'
  else pth:=pth+'.dlo';
  assign(f,pth);
  append(f);
  if IoResult <>0 then rewrite(f);
  if _kfs then write(f,cFSM[fsm_KFS]);
  writeln(f,fName);
  close(f);
  pth:='';
  if (_hld and _kfs) then pth:='[Hold/KFS]'
  else
   if _hld then pth:='[Hold]'
   else
    if _kfs then pth:='[KFS]';
  LogWrite(imGenBinkAtch,JustFilename(fName)+#3+Addr2str(A,true)+#3+
          pth,ld_All);
 end;
end;

procedure FromBinkOutbound(hld:boolean; nAkA:byte);
var
 pth:PathStr;
 f:text;
 s:string;
 sr:SearchRec;

begin
 with SessionControl^, pCfgRec^ do begin
  Path4addr(true,pRemoteInfo^.RemoteAddr[nAkA],pth);
  { Øp® ≠†´®Á®® ‰´†£† HAT „ ‚Æ© ·®·‚•¨Î ÂÆ´§®¨ ≠† 1 Á†· }
  if (EMSI_Flags and emsiHAT) =0 then begin
   { prepare ?UT list }
   SntCurFile.FileType:=ftBinkUt;
   {WRITELOGALL('SCAN BINK OUTBOUND..');}
   {$I+} FindFirst(pth+'.?ut',Archive,BoxFileInfo); {$I-}
   while DosError =0 do with SntCurFile do begin
    s[1]:=LoCase(BoxFileInfo.Name[succ(Pos('.',BoxFileInfo.Name))]);
    if (Hld and (s[1] ='h')) or ((not Hld) and (s[1] <>'h')) then begin
      {WRITELOGALL('?UT:'+BoxFileInfo.Name);}
      Name:=pth+'.'+JustExtension(BoxFileInfo.Name);
      MsgNo:=nAkA or (ord(s[1]) shl 8);
      Insert2sntLog;
      {WRITELOGALL('UT INSERTED OK');}
    end;
    {$I+} FindNext(BoxFileInfo); {$I-}
   end;
   {WRITELOGALL('UTs SCANED');}
   { prepare ?LO list (attaches) }
   if (EMSI_Flags and (emsiHXT or emsiZMH) =0) then begin
    {$I+} FindFirst(pth+'.?lo',Archive,sr); {$I-}
    while DosError =0 do with SntCurFile do begin
     s[1]:=LoCase(sr.Name[succ(Pos('.',sr.Name))]);
     if (Hld and (s[1] ='h')) or ((not Hld) and (s[1] <>'h')) then begin
       {WRITELOGALL('?LO:'+sr.Name);}
       MsgNo:=nAkA or (ord(s[1]) shl 8);
       assign(f,pth+'.'+JustExtension(sr.Name));
       reset(f);
       repeat
         MsgAttr:=word(TextPos(f));
         readln(f,s);
         s:=Trim(s);
         if Length(s) <>0 then begin
          if s[1] =cFSM[fsm_KFS] then begin
            FileType:=ftBinkLoKFS;
            Delete(s,1,1);
          end
          else
           if s[1] =cFSM[fsm_TFS] then begin
             FileType:=ftBinkLoTFS;
             Delete(s,1,1);
           end
           else
             FileType:=ftBinkLoNorm;
          Name:=s;
          {WRITELOGALL('FILE:'+s);}
          Insert2sntLog;
         end;
       until EOF(f);
       close(f);
       if IoResult <>0 then;
     end;
     {$I+} FindNext(sr); {$I-}
    end;
    if (not hld) and ((EMSI_Flags and (emsiHRQ or emsiZMH)) =0) then
     if ExistFile(pth+'.req') then with SntCurFile do begin
       Name:=pth+'.req';
       {WRITELOGALL('FREQ:'+pth+'.req');}
       FileType:=ftBinkFReq;
       Insert2sntLog;
       FReqOut:=true;
     end;
   end; (*IF NOT emsiHXT/emsiZMH*)
  end; (*IF NOT emsiHAT*)
 end; (*WITH*)
end;

procedure ScanOutbound(bink:boolean; forMask:boolean);
var
 rZ,rN,rF,rP:tStr5;
 od:SearchRec;  {outbound directory}
 Ext:string[3];
 TargA:tAddress;
 emptyZone,
 emptyPoint:boolean;

function What_UT(c:char):tLOmode;
var
 z:tLOmode;

begin
 What_UT:=lo_Hmm;
 for z:=lo_Normal to lo_Hold do
   if c =UT_mode[z] then begin
     What_UT:=z;
     exit;
   end;
end;

function What_LO(c:char):tLOmode;
var
 z:tLOmode;

begin
 What_LO:=lo_Hmm;
 for z:=lo_Normal to lo_Hold do
   if c =LO_mode[z] then begin
     What_LO:=z;
     exit;
   end;
end;

procedure ScanOutboundStuff(pth:PathStr; pnt:boolean);
var
 sr:SearchRec;
 sExt:string[3];
 n:word;
 f:text;
 fsr:SearchRec;
 s:string;
 nst:byte;  { ·‚†§®Ô ·™†≠®‡Æ¢†≠®Ô §´Ô bink: 0-?ut, 1-?lo, 2-req}
            {                     §´Ô sfm: 0-pk?, 1-mfx, 2-mfa, 3-re?}

begin
 if bink then begin
  for nst:=0 to 2 do begin
   (* SCAN FOR ?UT/?LO/REQ *)
   case nst of
    0: s:='?ut';
    1: s:='?lo';
    2: s:='req';
   end;
   {$I+} FindFirst(pth+'\*.'+s,Archive,sr); {$I-}
   while DosError =0 do begin
    emptyPoint:=false;
    with TargA do
     if pnt then
      Str2word('$'+copy(sr.Name,1,8),TargA.Point)
     else begin
      Str2word('$'+copy(sr.Name,1,4),TargA.Net);
      Str2word('$'+copy(sr.Name,5,4),TargA.Node);
     end;
    sExt:=StLoCase(JustExtension(sr.Name));
    if forMask then
     if not ExpandAddrMacro(RepackForAddr, rZ,rN,rF,rP, false) then
      SplitAddr(RepackForAddr, rZ,rN,rF,rP, false);
    if (not forMask) or
       MatchAddrList(TargA, rZ+':'+rN+'/'+rF+'.'+rP,rsUnknown) then
     if (sExt ='bsy') or
        ExistFile(ForceExtension(pth+'\'+sr.Name,'bsy')) then begin
       LogWrite(wmBusyFor,Addr2str(TargA,true),ld_All or ld_LastLn);
       emptyPoint:=false;
     end
     else begin
       n:=FindAddrInQueue(TargA);
       if n =0 then begin
         FillChar(QueTmp,SizeOf(tQueueRec),0);
         Move(TargA,QueTmp.DestAddr,SizeOf(tAddress));
         n:=AddQueue;
         if n =0 then exit;
         Inc(PktCreated);
       end;
       with Que[n]^ do begin
        case nst of
         0: { *.?ut } begin
           if sr.Size =0 then Inc(sr.Size);
           case What_UT(sExt[1]) of
            lo_Normal,
            lo_Direct: begin
                        Inc(MailSize,sr.Size);
                        omMask:=omMask or omNormalMail or omRealMail;
                       end;
            lo_Crash: begin
                       Inc(MailSize,sr.Size);
                       omMask:=omMask or omPrioMail or omNormalMail or omRealMail;
                      end;
            lo_Imm: begin
                     Inc(MailSize,sr.Size);
                     omMask:=omMask or omImmMail or omNormalMail or omRealMail;
                    end;
            lo_Hold: begin
                      Inc(HoldMailSize,sr.Size);
                      omMask:=omMask or omHoldMail;
                     end;
           end;
           {LOGWRITE(0,'['+sExt[1]+'] bundle',ld_All); }
         end;
         1: { *.?lo } begin
           if sr.Size =0 then begin
            { Ø‡® Ø„·‚Æ© ´ÆË™• ¢·• ‡†¢≠Æ Ì´•¨•≠‚ ÆÁ•‡•§® §Æ´¶•≠ ·Æß§†¢†‚Ï·Ô }
            case What_LO(sExt[1]) of
             lo_Normal,lo_Direct: omMask:=omMask or omNormalAttach;
             lo_Imm: omMask:=omMask or (omImmMail or omNormalAttach);
             lo_Crash: omMask:=omMask or (omPrioMail or omNormalAttach);
             lo_Hold: omMask:=omMask or omHoldAttach;
            end;
            if What_LO(sExt[1]) =lo_Hold then begin
             if HoldFileSize =0 then Inc(HoldFileSize);
            end
            else
             if FileSize =0 then Inc(FileSize);
           end
           else begin
             { Scan_LO(pth+'\'+sr.Name); }
             assign(f,pth+'\'+sr.Name);
             reset(f);
             repeat
               readln(f,s);
               s:=Trim(s);
               if Length(s) <>0 then begin
                if s[1] in [cFSM[fsm_KFS],cFSM[fsm_TFS]] then s:=copy(s,2,255);
                {$I+} FindFirst(s,Archive,fsr); {$I-}
                if DosError =0 then
                 case What_LO(sExt[1]) of
                  lo_Normal,
                  lo_Direct: begin
                              Inc(FileSize,fsr.Size);
                              omMask:=omMask or omNormalAttach;
                             end;
                  lo_Imm: begin
                           Inc(FileSize,fsr.Size);
                           omMask:=omMask or (omImmMail or omNormalAttach);
                          end;
                  lo_Crash: begin
                             Inc(FileSize,fsr.Size);
                             omMask:=omMask or (omPrioMail or omNormalAttach);
                            end;
                  lo_Hold: begin
                            Inc(HoldFileSize,fsr.Size);
                            omMask:=omMask or omHoldAttach;
                           end;
                 end;
               end;
             until EOF(f);
             close(f);
             if IoResult <>0 then;
             {---------------------------}
           end;
         end;
         2: {*.req} begin
           if sExt ='req' then begin
            {WRITELOGALL('request for '+_4D2str(TargA));}
            Inc(FileSize,sr.Size);
            omMask:=omMask or omFReq;
           end;
         end;
        end; (*CASE nst*)
       end; (*WITH QUE[N]^*)
     end; (*NOT BUSY*)
    {$I+} FindNext(sr); {$I-}
   end; (*WHILE DOSERROR*)
  end; (*FOR nst*)
 end (*FOR BINK*)
 else begin
  { sf-mail`s native outbound: 0-pk?, 1-mfx, 2-mfa, 3-mfo, 4-re? }
  for nst:=0 to 4 do begin
   case nst of
    0: s:='pk?';
    1: s:='mfx';
    2: s:='mfa';
    3: s:='mfo';
    4: s:='re?';
   end;
   {$I+} FindFirst(pth+'\*.'+s,Archive,sr); {$I-}
   while DosError =0 do begin
    emptyPoint:=false;
    with TargA do
     if pnt then
      Str2word('$'+copy(sr.Name,1,8),TargA.Point)
     else begin
      Str2word('$'+copy(sr.Name,1,4),TargA.Net);
      Str2word('$'+copy(sr.Name,5,4),TargA.Node);
     end;
    sExt:=StLoCase(JustExtension(sr.Name));
(*    n:=FindAddrInQueue(TargA);                             *)
(*  if n =0 then                                             *)
(*    LogWrite(emLostQue,Addr2str(TargA,true),ld_All)        *)
(*  else with Que[n]^ do {BEGIN}                             *)
    n:=FindAddrInQueue(TargA);
    if n =0 then begin
       FillChar(QueTmp,SizeOf(tQueueRec),0);
       Move(TargA,QueTmp.DestAddr,SizeOf(tAddress));
       n:=AddQueue;
       if n =0 then exit;
       Inc(PktCreated);
    end;
    with Que[n]^ do
     case nst of
      0: { *.pk? } begin
        if sExt[3] ='h' then begin
         omMask:=omMask or omHoldMail;
         Inc(HoldMailSize,sr.Size);
        end
        else begin
         Inc(MailSize,sr.Size);
         omMask:=omMask or omNormalMail;
        end;
      end;
      1,2: { *.mfx, *.mfa } with SessionControl^ do begin
         {-attach or holdattach-}
         assign(fSntLog,pth+'\'+sr.Name);
         reset(fSntLog);
         repeat
          read(fSntLog,SntCurFile);
          {$I+} FindFirst(SntCurFile.Name,Archive,fsr); {$I-}
          if DosError =0 then begin
           if sExt[3] ='a' then begin
            omMask:=omMask or omNormalAttach;
            Inc(FileSize,fsr.Size);
           end
           else begin
            omMask:=omMask or omHoldAttach;
            Inc(FileSize,fsr.Size);
           end;
          end;
         until EOF(fSntLog);
         close(fSntLog);
         if IoResult <>0 then;
      end;
      3: omMask:=omMask or omRealMail;
      4: { *.re? } begin
        if sExt[3] ='h' then begin
         omMask:=omMask or omHoldFreq;
         Inc(HoldFileSize,sr.Size);
        end
        else begin
         omMask:=omMask or omFreq;
         Inc(FileSize,sr.Size);
        end;
      end;
     end; (*CASE*)
    {$I+} FindNext(sr); {$I-}
   end; (*WHILE DOSERROR*)
  end; (*FOR nst*)
 end; (*NOT FOR BINK*)
end;

procedure ScanZoneDir(zoneExt:string);
var
 zd:SearchRec;  {zone dir}
 Ext:string;

 DirPHead  : pSearchPos;
 DirPCur   : pSearchPos;

begin
 DirPHead:=nil;
 TargA.Point:=0;
 if bink then
  ScanOutboundStuff(pCfgRec^.BinkOutbound+'.'+zoneExt,false)
 else
  ScanOutboundStuff(pCfgRec^.Packets+'Zone.'+zoneExt,false);
 { ØÆ§™†‚†´Æ£® ØÆ®≠‚Æ¢ Ì‚Æ© ßÆ≠Î }
 {$I+}
 if bink then
  FindFirst(pCfgRec^.BinkOutbound+'.'+zoneExt+'\*.PNT',Directory,zd)
 else
  FindFirst(pCfgRec^.Packets+'Zone.'+zoneExt+'\*.PNT',Directory,zd);
 if DosError=0 then begin
   GetMem(DirPHead,sizeof(SearchPos));
   DirPHead^.Name:=zd.Name;
   DirPHead^.Next:=nil;
   DirPCur:=DirPHead;
 end;
 While DosError = 0 do begin
   FindNext(zd);
   if DosError=0 then begin
     GetMem(DirPCur^.Next,sizeof(SearchPos));
     DirPCur:=DirPCur^.Next;
     DirPCur^.Name:=zd.Name;
     DirPCur^.Next:=nil;
   end;
 end;
 {$I-}
 DirPCur:=DirPHead;

 while DirPCur<> nil do begin
  emptyPoint:=true;
  Str2word('$'+copy(DirPCur^.Name,1,4),TargA.Net);
  Str2word('$'+copy(DirPCur^.Name,5,4),TargA.Node);
  if bink then
   ScanOutboundStuff(pCfgRec^.BinkOutbound+'.'+zoneExt+'\'+DirPCur^.Name,true)
  else
   ScanOutboundStuff(pCfgRec^.Packets+'Zone.'+zoneExt+'\'+DirPCur^.Name,true);
  if bink and emptyPoint then
    KillEmptyDir(pCfgRec^.BinkOutbound+'.'+zoneExt+'\'+DirPCur^.Name)
  else
    emptyZone:=false;
  if IoResult <>0 then;
  DirPCur:=DirPCur^.Next;
 end;
 DirPCur:=DirPHead;
 while DirPCur<> nil do begin
   DirPHead:=DirPCur^.Next;
   FreeMem(DirPCur,sizeof(SearchPos));
   DirPCur:=DirPHead;
 end;

end;

Var
  DirHead  : pSearchPos;
  DirCur   : pSearchPos;

begin
 CreateSemaphore(pCfgRec^.Flags_Dir+'binkbsy.sf');
 DirHead:=nil;
 { ≠• ·™†≠®¨ °-Æ, •·´® ™†‚†´Æ£ ≠• ß†§†≠ }
 if bink and (Length(pCfgRec^.BinkOutbound) =0) then exit;
 LogWrite(imScanBO,'',ld_Screen or ld_LastLn);
 {$I+}
 if bink then
  FindFirst(pCfgRec^.BinkOutbound+'.*',Directory,od)
 else
  FindFirst(pCfgRec^.Packets+'Zone.*',Directory,od);
 if DosError=0 then begin
   GetMem(DirHead,sizeof(SearchPos));
   DirHead^.Name:=od.Name;
   DirHead^.Next:=nil;
   DirCur:=DirHead;
 end;

 While DosError = 0 do begin
   FindNext(od);
   if DosError=0 then begin
     GetMem(DirCur^.Next,sizeof(SearchPos));
     DirCur:=DirCur^.Next;
     DirCur^.Name:=od.Name;
     DirCur^.Next:=nil;
   end;
 end;
 {$I-}
 DirCur:=DirHead;

 while DirCur<> nil do begin
   Ext:=JustExtension(DirCur^.Name);
   FillChar(TargA,SizeOf(tAddress),0);
   if (Length(Ext) =0) or Str2word('$'+Ext,TargA.Zone) then begin
    if Length(Ext) =0 then TargA.Zone:=MainAddress.Zone;
    emptyZone:=true;
    if bink then begin
     if forMask then
      if not ExpandAddrMacro(RepackForAddr, rZ,rN,rF,rP, false) then
       SplitAddr(RepackForAddr, rZ,rN,rF,rP, false);
     if (not forMask) or (rZ ='*') or (rZ =Long2str(TargA.Zone)) then
      ScanZoneDir(Ext);
    end
    else
     ScanZoneDir(Ext);
    if bink and emptyZone then
     if TargA.Zone <>MainAddress.Zone then
      KillEmptyDir(pCfgRec^.BinkOutbound+'.'+Ext);
    if IoResult <>0 then;
   end;
   DirCur:=DirCur^.Next;
 end;
 DirCur:=DirHead;
 while DirCur<> nil do begin
   DirHead:=DirCur^.Next;
   FreeMem(DirCur,sizeof(SearchPos));
   DirCur:=DirHead;
 end;
 EraseSemaphore(pCfgRec^.Flags_Dir+'binkbsy.sf');
 {WaitMsg;}
end;

procedure ScanNamedPolls;
var
 sr:SearchRec;
 n:word;
 A:tAddress;

begin
 { ‡†ßÆ‚¨•Á†•¨ à¨•≠≠Î• ÇÎßÆ¢Î }
 n:=1;
 while Que[n] <>nil do with Que[n]^ do begin
  omMask:=omMask and (not omNamedPoll);
  Inc(n);
 end;
 { ®È•¨ }
 {$I+} FindFirst(pCfgRec^.Flags_Dir+'*'+nplXt,Archive,sr); {$I-}
 while DosError =0 do begin
  Str2NamedPoll(sr.Name,A);
  n:=FindAddrInQueue(A);
  if n =0 then begin
   {WRITELOGALL('Dbg: ≠• ≠†Ë´® '+Addr2str(A,true));}
   FillChar(QueTmp,SizeOf(tQueueRec),0);
   Move(A,QueTmp.DestAddr,SizeOf(tAddress));
   QueTmp.omMask:=omNamedPoll;
   n:=AddQueue;
   {WRITELOGALL('Dbg: §Æ°†¢®´® '+Long2str(n)+'-Î¨ Ì´•¨•≠‚Æ¨');}
   if n <>0 then
    Inc(PktCreated);
  end
  else BEGIN
   Que[n]^.omMask:=omNamedPoll;
   {WRITELOGALL('Dbg: '+Addr2str(A,true)+' „¶• •·‚Ï @'+Long2str(n));}
  END;
  {$I+} FindNext(sr); {$I-}
 end;
 {WRITELOGALL('Dbg: ß†™Æ≠Á®´® ·™†≠®‡Æ¢†≠®• NPL');}
end;

end.of.tpu
 ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
 ‹‹‹//////‹‹/////‹‹‹//‹‹‹‹//‹//////‹///‹///‹‹‹‹
 ‹‹‹/‹‹‹‹‹‹‹/‹‹‹‹‹‹‹///‹‹///‹‹‹‹‹‹/‹‹/‹‹‹/‹‹‹‹‹
 ‹‹‹//////‹///‹‹‹//‹/‹////‹/‹//////‹‹/‹‹‹/‹‹‹‹‹
 ‹‹‹‹‹‹‹‹/‹‹/‹‹‹‹‹‹‹/‹‹//‹‹/‹/‹‹‹‹/‹‹/‹‹‹/‹‹‹‹‹
 ‹‹‹//////‹‹/‹‹‹‹‹‹‹/‹‹‹‹‹‹/‹//////‹///‹‹////‹‹
 ‹‹‹‹‹‹‹‹‹///‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
