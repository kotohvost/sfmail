(*** Session control routines ***)

{$X+,I-,O+,F+}

UNIT SessCtl;

INTERFACE

uses
 Dos;

procedure RecvThisFile(RcvdFname:PathStr; fSiz:longint);
{ ��뢠���� ��᫥ �p����� ������� 䠩��
  � 䨪�p�� � SessionControl.fRvdLog`� �� ���H�� �����}

procedure EndSession(Aborted:boolean; TraffIn,TraffOut:longint);
{ ����p襭�� ��ᨨ}

function SendThisFile(var RealFname:PathStr;
                      var NewFname:PathStr;
                      PrevSkipped:boolean):boolean;
{ ����p���� TRUE � � RealName ���� p���쭮� ��� 䠩��,
  � � NewName -- �, � ����� �� ������ ���� �p���� �� ⮩
  ��p��� -- �᫨ ���� 䠩� ��� ��p����,
  �᫨ ��p������� ��祣� -- ����p. FALSE}

procedure BeginSession;
{ � RemoteInfo ������ ���� ���ᥭ� ���p����:
  RemoteName,RemoteAddr,nRemoteAddr,SessionType}

procedure EndFirstBatch;
{ ��᫥ ����砭�� ��ࢮ�� ���� �� 娤�}

IMPLEMENTATION

uses
 a002xs,
 aTime,
 Busy,
 WriteLog,
 CRC_All,
 TpDos,
 Tstring_,
 EmStruct,
 MsgXs,
 EventMan,
 EM_Cpl,
 FReqMan,
 Flags,
 Config,
 Sf_Snd,
 FbMan,
 UnPkt,
 UnixTime,
 ProcMan,
 ERP,
 Sf_Bink,
 SfInclud,
 SubstMan,
 FileMan,
 Pwd_Xs;

function CheckDosMask(fName,Mask:string):boolean;
var
 m_Nm,m_Xt:string;
 f_Nm,f_Xt,
 s,s1:PathStr;
 i:byte;

begin
 fName:=StLoCase(fName);
 Mask:=StLoCase(Mask);

 if Pos('.',Mask) <>0 then begin
  m_Nm:=Pad(Copy(Mask,1,pred(Pos('.',Mask))),8);
  m_Xt:=Copy(Mask,succ(Pos('.',Mask)),3);
 end
 else begin
  m_Nm:=Pad(Mask,8);
  m_Xt:='';
 end;

 if Pos('.',fName) <>0 then begin
  f_Nm:=Pad(Copy(fName,1,pred(Pos('.',fName))),8);
  f_Xt:=Copy(fName,succ(Pos('.',fName)),3);
 end
 else begin
  f_Nm:=Pad(fName,8);
  f_Xt:='';
 end;

 { 㤠��� �� `?' }

 while Pos('?',m_Nm) <>0 do begin
  i:=Pos('?',m_Nm);
  Delete(m_Nm,i,1);
  Delete(f_Nm,i,1);
 end;

 while Pos('?',m_Xt) <>0 do begin
  i:=Pos('?',m_Xt);
  Delete(m_Xt,i,1);
  Delete(f_Xt,i,1);
 end;

 { ��p���⠥� `*' }

 if Pos('*',m_Nm) <>0 then begin
  i:=Pos('*',m_Nm);
  Delete(m_Nm,i,8);
  Delete(f_Nm,i,8);
 end;

 if Pos('*',m_Xt) <>0 then begin
  i:=Pos('*',m_Xt);
  Delete(m_Xt,i,8);
  Delete(f_Xt,i,8);
 end;

 CheckDosMask:=(f_Nm =m_Nm) and (f_Xt =m_Xt);
end;

{***************** Session control *******}

procedure BeginSession;
{ � RemoteInfo ������ ���� ���ᥭ� ���p����:
  RemoteName,RemoteAddr,nRemoteAddr,SessionType}
var
 i:word;
 u:word;
 pPath:PathStr;

procedure CreateSendLog(ForHold:boolean);
var
 i:word;

begin
 with SessionControl^, pCfgRec^ do begin
  { ᮧ���� ᯨ᮪ 䠩��� ��� ��p���� }
  { �p���p塞 Busy }
  for i:=1 to pRemoteInfo^.nRemoteAddr do begin
    if AddressBusy(pRemoteInfo^.RemoteAddr[i]) then begin
      pRemoteInfo^.BusyAddr:=pRemoteInfo^.BusyAddr and (not(1 shl pred(i)));
    end else begin
      SetBusy(pRemoteInfo^.RemoteAddr[i]);
      if (pCfgRec^.SysFlags and amaScan <>0) then begin
       { �p� ����稨 䫠�� HAT � ⮩ ��⥬� 宫��� �� 1 �� }
       Path4addr(false,pRemoteInfo^.RemoteAddr[i],pPath);
       if (EMSI_Flags and emsiHAT) =0 then begin
         if ForHold then begin
           { HOLD MAIL }
           SntCurFile.Name:=pPath+HoldPktXt;
           SntCurFile.FileType:=ftHoldPacket;
           if ExistFile(SntCurFile.Name) then Insert2sntLog;
         end;
         { NORMAL MAIL}
         SntCurFile.Name:=pPath+PktXt;
         SntCurFile.FileType:=ftPacket;
         if ExistFile(SntCurFile.Name) then Insert2sntLog;

         if (EMSI_Flags and (emsiHXT or emsiZMH) =0) then begin
           if ForHold then begin
             {HOLD ATTACHES}
             assign(fRvdLog,pPath+outHoldAttach);
             reset(fRvdLog);
             if IoResult =0 then begin
              repeat
               read(fRvdLog,SntCurFile);
               if IOResult=0 then Insert2sntLog;
              until EOF(fRvdLog);
              close(fRvdLog);
             end;
             if IOResult=0 then;
             { Hold Attach Pkt }
             SntCurFile.Name:=pPath+AttHPktXt;
             SntCurFile.FileType:=ftHAttPacket;
             if ExistFile(SntCurFile.Name) then Insert2sntLog;
           end;
           {NORMAL ATTACHES}
           assign(fRvdLog,pPath+outNormalAttach);
           reset(fRvdLog);
           if IoResult =0 then begin
            repeat
             read(fRvdLog,SntCurFile);
             if IOResult=0 then Insert2sntLog;
            until EOF(fRvdLog);
            close(fRvdLog);
           end;
           if IOResult=0 then;
           { Normal Attach Pkt }
           SntCurFile.Name:=pPath+AttPktXt;
           SntCurFile.FileType:=ftAttPacket;
           if ExistFile(SntCurFile.Name) then Insert2sntLog;
           {File Boxes}
           if ForHold then
             FromFileBox(true,pRemoteInfo^.RemoteAddr[i],true);
           FromFileBox(true,pRemoteInfo^.RemoteAddr[i],false);
           if (EMSI_Flags and (emsiHRQ or emsiZMH)) =0 then begin
             if ForHold then begin
             { HOLD FILE REQUEST }
               SntCurFile.Name:=pPath+outHoldFReq;
               SntCurFile.FileType:=ftFRHaccomp;
               if ExistFile(pPath+outHoldFReq) then begin
                 Insert2sntLog;
                 FReqOut:=true;
                 SntCurFile.Name:=pPath+RehXt;
                 SntCurFile.FileType:=ftFReh;
                 Insert2sntLog;
               end;
             end;
             SntCurFile.Name:=pPath+outFReq;
             SntCurFile.FileType:=ftFRQAccomp;
             if ExistFile(pPath+outFReq) then begin
               Insert2sntLog;
               SntCurFile.Name:=pPath+ReqXt;
               SntCurFile.FileType:=ftFReq;
               Insert2sntLog;
               FReqOut:=true;
             end;
           end;
         end;
       end;
      end;
      if Length(BinkOutbound) <>0 then begin
        if ForHold then FromBinkOutbound(true,i);
        FromBinkOutbound(false,i);
      end;
      if (i=1) then BroadCastFile;
    end; {if Address Busy}
  end; {For i}
 end; {with}
end; {of procedure}

begin
 PlaySound(TsndSessBegin);
 CreateDosTimeStamp(SessionControl^.SessionDateTime);   {���/�p��� ��ᨨ}

 { ���⠢�塞 busy-ᥬ��p� � ��⠢�� ᯨ᮪ ��� ��p���� }
 with SessionControl^, pCfgRec^ do begin
  FmaskBits:=0;
  WhatRcvd:=0;
  TrafficIn:=0;
  TrafficOut:=0;
  TRAF_in_Cur:=0;
  TRAF_out:=0;
  TRAF_out_Cur:=0;
  FReqOut:=false;
  FReqIn:=false;
  pRemoteInfo^.BusyAddr:=$FFFF;         {�� 16 AkA ��⨢��}

  GetMem(SortTRx,SizeOf(tSortTRxArray));

  with pRemoteInfo^ do begin
    { �饬 � ��������� � ���� }
    RemoteStatus:=rsUnknown;
    if SessionType =Outgoing then
      Move(NodeEntry.Address,CallToAddr,SizeOf(tAddress))
    else
      Move(RemoteAddr[1],CallToAddr,SizeOf(tAddress));

    if CheckPassword(RemoteAddr[1]) then
      RemoteStatus:=rsProtected;

    if ReopenNodeIdx then with RemoteAddr[1] do begin
      if FindNodeEntry(true,Zone,Net,Node,Point) then
       RemoteStatus:=RemoteStatus or rsPublished or rsListed;
      CloseNodeIdx;
    end;

    if SessionType =Outgoing then begin
     if (not CrashMode) then begin
       if SubstNodeEntry(RemoteAddr[1],Que[CurQue]^.LastCallLine) then
         RemoteStatus:=RemoteStatus or rsListed;
     end else begin
       if SubstNodeEntry(RemoteAddr[1],CrashLine) then
         RemoteStatus:=RemoteStatus or rsListed;
     end;
    end else
     if SubstNodeEntry(RemoteAddr[1],0) then
       RemoteStatus:=RemoteStatus or rsListed;

    pPath:='';
    if (RemoteStatus and rsListed)<>0 then pPath:=pPath+'listed/';
    if (RemoteStatus and rsPublished)<>0 then pPath:=pPath+'published/';
    if (RemoteStatus and rsProtected)<>0 then pPath:=pPath+'protected/';
    if length(pPath)=0 then pPath:='unknown/';
    Dec(byte(pPath[0]));

    LogWrite(imRemoteStatus,pPath,ld_All);
    if SessionType =Inbound then
     SubstNodeEntry(RemoteAddr[1],0)
    else begin
     if (not CrashMode) then begin
       if CompWordStruct(RemoteAddr[1],Que[CurQue]^.DestAddr,SizeOf(tAddress)) =Equal then
         SubstNodeEntry(RemoteAddr[1],Que[CurQue]^.LastCallLine)
       else
         SubstNodeEntry(RemoteAddr[1],0);
     end else
       SubstNodeEntry(RemoteAddr[1],CrashLine);
    end;
    { ������ EMSI-䫠��� }
    pPath:='';
    if EMSI_Flags and emsiHAT <>0 then pPath:='HAT ';
    if EMSI_Flags and emsiHRQ <>0 then pPath:=pPath+'HRQ ';
    if EMSI_Flags and emsiHXT <>0 then pPath:=pPath+'HXT ';
    {---}
    if Length(pPath) <>0 then begin
      LogWrite(imEMSIflags,pPath,ld_All);
      for i:=1 to nRemoteAddr do begin
        u:=FindHIP4addr(RemoteAddr[i]);
        Move(RemoteAddr[i],HIPtmp,SizeOf(tAddress));
        FillChar(HIPtmp.hipEnd,SizeOf(tHIPend),$FF);
        if u <>0 then
          Move(HIParray[u]^,HIPtmp,SizeOf(tHIPflag));
        { HAT }
        if (EMSI_Flags and emsiHAT <>0) and
           (HIPtmp.hipEnd[tpHold] =NoPriority) then
          HIPtmp.hipEnd[tpHold]:=CurUnixTime+SecInMin*HIP_Time;
        { HXT }
        if (EMSI_Flags and emsiHXT <>0) and
           (HIPtmp.hipEnd[tpHXT] =NoPriority) then
          HIPtmp.hipEnd[tpHXT]:=CurUnixTime+SecInMin*HIP_Time;
        { HRQ }
        if (EMSI_Flags and emsiHRQ <>0) and
           (HIPtmp.hipEnd[tpHRQ] =NoPriority) then
          HIPtmp.hipEnd[tpHRQ]:=CurUnixTime+SecInMin*HIP_Time;
        AddHIP;
      end;
      CorrectHIP;
    end;
    if MatchTimePeriod(_ZMH_) then begin
      for i:=1 to AllAddress do
        if MyAddress[i].Point =0 then
          EMSI_Flags:=EMSI_Flags or emsiZMH;
      if EMSI_Flags and emsiZMH <>0 then
        LogWrite(imZMHsession,'',ld_All);
    end;
    { ��p뢠�� ��� ��p���� }
    assign(fSntLog,Packets+HexL(strCRC32(Addr2str(RemoteAddr[1],true)))+sntXt);
    rewrite(fSntLog);

    { ��p��� 䠩� ��p��� ����� ��� ��� ��� ��⥬�}
    nCurSend:=0; {ᥩ�� ��祣� �� 諥�}
    nToSend:=0;  {assume: NO FILES to SEND}

    { ᮧ���� ᯨ᮪ ���뫪� HOLD (� �����)}
    if (SessionType =Inbound) or (SysFlags and mscHoldOnUs <>0) then
     CreateSendLog(true)
    else begin
     if (not CrashMode) and
        (CompWordStruct(Que[CurQue]^.DestAddr,
                        RemoteAddr[1],SizeOf(tAddress)) <>Equal) then
     LogWrite(wmOtherMainAddr,Addr2str(RemoteAddr[1],true)+#3+
               Addr2str(Que[CurQue]^.DestAddr,true),ld_All);

     CreateSendLog(false);
    end;

    { �����뢠�� ���p�p������ ᯨ᮪ ���뫪�}
    {ASSIGN(f,'_$___$_.tmp'); REWRITE(f);}
    for i:=1 to nToSend do begin
      Move(SortTRx^[i],SntCurFile,SizeOf(tTRxLog));
      write(fSntLog,SntCurFile);
      {WRITELN(f,DT2str(SortTRx^[z].fTime)+' '+SortTRx^[z].Name);}
    end;
    {CLOSE(f);}
    FreeMem(SortTRx,SizeOf(tSortTRxArray));

    { ������� ��� �p����}
    assign(fRvdLog,Packets+HexL(strCRC32(Addr2str(RemoteAddr[1],true)))+rvdXt);
    rewrite(fRvdLog);
    close(fRvdLog);

    { ᮧ����� fReqList ��� ��室��� �४�� � ��� ftMustDie }
    assign(fReqList,Packets+HexL(strCRC32(Addr2str(RemoteAddr[1],true)))+srqXt);
    rewrite(fReqList);
    close(fReqList);
  end;

  { 㪠��⥫� �� ��砫� ᯨ᪠ ��p����}
  reset(fSntLog);
 end; {*WITH*}
end;

procedure EndFirstBatch;
{ ��᫥ ����砭�� ��ࢮ�� ���� �� 娤�}
begin
 with SessionControl^ do begin
  Secondbatch:=true;
  {rewrite(fSntLog);
  nCurSend:=0;
  nToSend:=0;}
  if FReqIn then begin
   reset(fRvdLog);
   while not EOF(fRvdLog) do begin
    read(fRvdLog,SntCurFile);
    if SntCurFile.FileType =ftFReq then
     if Length(pCfgRec^.FR_Xternal) <>0 then
      ERP_Call(SntCurFile.Name)
     else
      FReqMan_Begin(SntCurFile.Name);
   end;
   close(fRvdLog);
   if IoResult <>0 then;
  end;
 end;
end;

function SendThisFile(var RealFname:PathStr;
                      var NewFname:PathStr;
                      PrevSkipped:boolean):boolean;
{ ����p���� TRUE � � RealName ���� p���쭮� ��� 䠩��,
  � � NewName -- �, � ����� �� ������ ���� �p���� �� ⮩
  ��p��� -- �᫨ ���� 䠩� ��� ��p����,
  �᫨ ��p������� ��祣� -- ����p. FALSE}
var
 ff:file;
 o:integer;
 l:longint;
 f:file of tTRxLog;
 trx:tTRxLog;

procedure PostSentAction;
{-��p���⪠ ��᫠��� 䠩��� � ��ᥬ}
var
 pExt:ExtStr;
 pth:PathStr;

begin
 with SessionControl^, SntCurFile do begin
  if FileType in [ftFRQaccomp,ftFRHaccomp] then exit;
  { 䠩�-���� }
  case FileType of
    ftTFS,ftBinkLoTFS: begin
                         CreateFlag(Name);   {᮪p�頥� �� 0-�����}
                       end;
    ftEAS,ftMustDie,   {-for ERP support}
    ftBoxed,ftKFS,
    ftFReq,ftFReh,
    ftBinkUt,ftBinkLoKFS: begin
                           DeleteFlag(Name); {��p���}
                          end;
  end; {*CASE*}

  {�襫 *.PK?}
  if FileType in [ftPacket,ftHoldPacket,ftAttPacket,ftHAttPacket] then begin
   case FileType of
     ftPacket: begin
       pExt:=copy(PktXt,2,3);
       assign(f,CleanPathName(ForceExtension(Name,outNormalMail)));
     end;
     ftHoldPacket: begin
       pExt:=copy(HoldPktXt,2,3);
       assign(f,CleanPathName(ForceExtension(Name,outHoldMail)));
     end;
     ftAttPacket: begin
       pExt:=copy(AttPktXt,2,3);
       assign(f,CleanPathName(ForceExtension(Name,outNormalAttach)));
     end;
     ftHAttPacket: begin
       pExt:=copy(AttHPktXt,2,3);
       assign(f,CleanPathName(ForceExtension(Name,outHoldAttach)));
     end;
   end;
   o:=IoResult;  {-��ᨬ �訡��, �� ��直� ��砩}
   reset(f);
   if IoResult =0 then begin
    { ᯨ᮪ ��ᥬ �� ��᫠���� ����� }
     repeat
      read(f,trx);
      { FReq -- �� �p����� �� ����砭�� ��ᨨ }
      if (trx.MsgAttr and bMsgFlag[_FReq]) =0 then
       if (trx.MsgAttr and bMsgFlag[_KillSent]) =0 then begin
        { K/S ��� -- �⠢�� SENT � ���� ���뫪� }
        ChangeMsgAttr(trx.MsgNo,bMsgFlag[_Sent],0);
        assign(ff,pCfgRec^.NetMail+Long2str(trx.MsgNo)+MsgXt);
        reset(ff,1);
        seek(ff,$B4);
        CreateMsgTimeStamp(l);
        BlockWrite(ff,l,SizeOf(l));
        close(ff);
        o:=IoResult;
       end else begin
        { K/S ���� -- 㤠���� ���쬮 }
        assign(ff,pCfgRec^.NetMail+Long2str(trx.MsgNo)+MsgXt);
        erase(ff);
        o:=IoResult;
        ClrBit4msg(trx.MsgNo,MsgFolderInfo.MsgFolderMap);
       end;
     until EOF(f);
     close(f);
     erase(f); o:=IoResult;
   end; {*IF IORESULT*}
   { ᮯp���������� 㤠���� -- 㤠��� � ᠬ ����� }
   assign(f,ForceExtension(Name,pExt));
   erase(f);
   o:=IoResult;
  end {*IF PKT*}
  else { �᫨ ⨯==ftMsg, �� ��p���﫨 ��� �� �p�� }
   if FileType =ftMsg then begin
     assign(ff,Name);
     erase(ff);
     o:=IoResult;
   end (*IF MSG (FREQ_STAT)*)
   else { ftFReqed -- 䠩� �� �p��� }
    if FileType =ftFReqed then
      FReqMan_PostSent(PrevSkipped)
    else
      if FileType in [ftBinkLoKFS,ftBinkLoTFS,ftBinkLoNorm] then begin
        Path4addr(true,pRemoteInfo^.RemoteAddr[System.lo(MsgNo)],pth);
        trx.Name:=Pad('',Length(Name));
        if FileType <>ftBinkLoNorm then trx.Name:=trx.Name+' ';
        assign(ff,pth+'.'+chr(hi(MsgNo))+'lo');
        reset(ff,1);
        seek(ff,longint(MsgAttr));
        BlockWrite(ff,trx.Name[1],Length(trx.Name));
        close(ff);
        if IoResult <>0 then;
      end;
 end; {*WITH*}
end;

begin
 with SessionControl^, SntCurFile do begin
  { ��-� 㦥 ��᫠�� }
  if nCurSend <>0 then PostSentAction;   {�p��.䠩� ��᫠�}

  repeat
   SendThisFile:=true;
   if nCurSend =nToSend then             {����� ��祣� ᫠��}
    if FreqIn then begin                 {�� �p��..}
      if SecondBatch then
       if Length(pCfgRec^.FR_Xternal) =0 then  {�p�� ��p����뢠��� SfM`��}
        FReqMan_End(false)  {..�����⮢�� ����⨪�}
       else begin
        DeleteFlag(pCfgRec^.FR_Response); {��p��� 䠩� �⢥� ERP}
        Inc(nCurSend)   {�p�� ��p����뢠� ERP -- �p�p㥬 ����砭�� ��p����}
       end
      else
       Inc(nCurSend);
    end
    else
     if SecondBatch then begin
      { ����� 祣� � 䠩�-����� ������?..}
      if (EMSI_Flags and (emsiHAT or emsiHXT or emsiZMH) =0) then begin
       l:=FilePos(fSntLog);
       for o:=1 to pRemoteInfo^.nRemoteAddr do begin
         if (SessionType =Inbound) or
            (pCfgRec^.SysFlags and mscHoldOnUs <>0) then
           FromFileBox(false,pRemoteInfo^.RemoteAddr[o],true); {-�� 宫������}
         FromFileBox(false,pRemoteInfo^.RemoteAddr[o],false);  {-�� ��p���쭮��}
       end;
       { �p�p㥬 ����砭�� ��p����, �᫨ ������ ��祣� ��� }
       if nCurSend =nToSend then Inc(nCurSend)
       else seek(fSntLog,l);
      end
      else
        Inc(nCurSend); {-�p�p㥬 ����砭�� ��p����}
     end
     else
      Inc(nCurSend);

   if nCurSend >nToSend then begin
     SendThisFile:=false;
     RealFname[0]:=#0;
     NewFname[0]:=#0;
     SntCurFile.FileType:=ftMsg;  {�����誠}
     nToSend:=0;
     nCurSend:=0;
     rewrite(fSntLog);
     exit;
   end;

   Inc(nCurSend);

   read(fSntLog,SntCurFile);
   RealFname:=SntCurFile.Name;

   if FileType in [ftPacket,ftHoldPacket,ftMsg,ftBinkUt,ftAttPacket,ftHAttPacket] then begin
    assign(ff,RealFname);
    reset(ff,1);
    l:=FileSize(ff);
    close(ff);
    o:=IoResult;  { �� ��� ��砩 (� ��p� ��� ����� ��-� 㯥p ;-) }
    if l >60 then begin
      NewFname:=HexL(longint(TodayDate) or CurTimeSec)+PktXt;
      exit;
    end
    else PostSentAction;  {㤠����� ���⮣� ���쬠 � PKT}
   end
   else
    if FileType in [ftFReq,ftFReh,ftBinkFReq,
                    ftFRQaccomp,ftFRHaccomp] then begin
      if FileType in [ftBinkFReq,ftFRQaccomp,ftFRHaccomp] then begin
        reset(fReqList);
        seek(fReqList,FileSize(fReqList));
        Move(SntCurFile,trx,SizeOf(tTRxLog));
        write(fReqList,trx);
        close(fReqList);
        if IoResult <>0 then;
      end;
      if FileType in [ftFReq,ftFReh,ftBinkFReq] then begin
       if StLoCase(JustExtension(JustPathName(RealFname))) ='pnt' then
        NewFname:=ForceExtension(JustFileName(JustPathName(RealFname)),'Req')
       else begin
        NewFname:=JustFileName(RealFname);
        NewFname[Length(NewFname)]:='q';
       end;
       exit;
      end;
    end
    else
      if not (FileType in [ftFRQaccomp,ftFRHaccomp]) then begin
       NewFname:=JustFileName(RealFname);
       exit;
      end;
  until FALSE;
 end; {*WITH*}
end;

procedure EndSession(Aborted:boolean; TraffIn,TraffOut:longint);
{ ����p襭�� ��ᨨ; Aborted:
   TRUE - ��p�
   FALSE- ��p���쭮�}
var
 trx:tTRxLog;
 ff:file;
 ft:text;
 s:string;
 f:file of tTRxLog;
 i:word;
 o:integer;
 pPath:PathStr;
 l:longint;
 {A:tAddress;}

begin
 with SessionControl^, pCfgRec^ do begin
  if Aborted then begin
   PlaySound(TsndSessAbort);
   if (SntCurFile.FileType in [ftKFS,ftTFS,ftNormal]) then begin
     { ��p���﫨 �� ����, �� �� ��� � ����p�����..}
     assign(ff,pCfgRec^.NetMail+Long2str(SntCurFile.MsgNo)+MsgXt);
     reset(ff,1);
     seek(ff,$48);
     BlockRead(ff,pPath[0],72);  {�⠥� subj}
     pPath:=A2S(pPath);
     if WordCount(pPath,[' ']) <>1 then begin
       Delete(pPath,1,pred(Pos(SntCurFile.Name,pPath)));
       pPath:=PadCh(pPath,#0,72);
       seek(ff,$48);
       BlockWrite(ff,pPath[1],72);
     end;
     close(ff);
     o:=IoResult;
   end
   else
     if SntCurFile.FileType =ftMustDie then
       {EraseSemaphore(SntCurFile.Name);}
       DeleteFlag(SntCurFile.Name);
   { �᫨ ��� �p��뫠�� �p�� + � ��� ���� ERP + ���� �� � ᫠�� }
   { �� ������ 㡨�� �� 䠩�� �� fReqList � ��p���⮬ ftMustDie }
   if FReqIn then begin
     if Length(pCfgRec^.FR_Xternal) <>0 then begin
      repeat
       reset(fReqList);
       read(fReqList,SntCurFile);
       if (IoResult =0) and (SntCurFile.FileType =ftMustDie) then begin
        DeleteFlag(SntCurFile.Name);
        if IoResult <>0 then;
       end;
      until EOF(fReqList);
      close(fReqList);
     end;
     if IoResult <>0 then;
     reset(fRvdLog);
     while not EOF(fRvdLog) do begin
      read(fRvdLog,RvdCurFile);
      if RvdCurFile.FileType =ftFReq then
       DeleteFlag(RvdCurFile.Name);
     end;
     close(fRvdLog);
     if IoResult <>0 then;
   end;
  end {*IF ABORTED*}
  else begin
   PlaySound(TsndSessOk);      {��몠 � ⮬, �� ���� �ᯥ譠�}
   { 㤠��� �� FReq/MustDie �.�. ��p뢠 �� �뫮 }
   reset(fReqList);
   repeat
    read(fReqList,SntCurFile);
    if (IoResult =0) and
       (SntCurFile.FileType in [ftFRQaccomp,ftFRHaccomp,ftBinkFReq,ftMustDie]) then begin
      if SntCurFile.FileType =ftFRHaccomp then
       assign(f,CleanPathName(ForceExtension(SntCurFile.Name,outHoldFReq)))
      else
       if SntCurFile.FileType =ftFRQaccomp then
        assign(f,CleanPathName(ForceExtension(SntCurFile.Name,outFReq)))
       else
        { bink freq, mustdie file }
        DeleteFlag(SntCurFile.Name);
      if SntCurFile.FileType in [ftFRQaccomp,ftFRHaccomp] then begin
       reset(f);
       if IoResult =0 then begin
        repeat
         read(f,trx);
         {if (trx.MsgAttr <>InvAddr) and}
         {   ((trx.MsgAttr and bMsgFlag[_FReq]) <>0) then begin}
          assign(ff,pCfgRec^.NetMail+Long2str(trx.MsgNo)+MsgXt);
          if (trx.MsgAttr and bMsgFlag[_KillSent]) =0 then begin
            { K/S ��� -- �⠢�� SENT � ���� ��p���� }
            ChangeMsgAttr(trx.MsgNo,bMsgFlag[_Sent],0);
            CreateMsgTimeStamp(l);
            reset(ff,1);
            seek(ff,$B4);
            BlockWrite(ff,l,SizeOf(l));
            close(ff);
            o:=IoResult;
          end
          else begin
            { K/S ���� -- 㤠���� ���쬮 }
            erase(ff);
            o:=IoResult;
            ClrBit4msg(trx.MsgNo,MsgFolderInfo.MsgFolderMap);
          end;
         {end;}
        until EOF(f);
        close(f);
        o:=IoResult;
       end; {*IF IOresult==0*}
      end; (*IF NOT BINKFREQ*)
    end;
   until EOF(fReqList);
  end;

  o:=IoResult;
  close(fSntLog);

  close(fReqList);
  o:=IoResult;
  erase(FreqList);
  o:=IoResult;

  for i:=1 to pRemoteInfo^.nRemoteAddr do with pRemoteInfo^ do begin
    if (BusyAddr and (1 shl pred(i))) <>0 then begin
      { ��p�� ��⨢�� -- ����⨬�� }
      ClearBusy(RemoteAddr[i]);
      DelQueue(Addr2str(RemoteAddr[i],true));
    end;
    { �᫨ �ᯥ譮 -- ᭨���� 䫠�� IMM � PRIO � AkA 㤠������ ��⥬� }
    if not Aborted then begin
     o:=FindHIP4addr(RemoteAddr[i]);
     if o <>0 then with HIParray[o]^ do begin
      hipEnd[tpImm]:=NoPriority;
      hipEnd[tpPrio]:=NoPriority;
     end;
    end;
  end; {*IF(FOR all aka)*}

  { �᫨ �p���� ��� ���� *.PKT..}
  if (WhatRcvd and imNetMail) <>0 then begin
   if (pCfgRec^.SysFlags and amaUnpack) <>0 then begin
    if IOResult<>0 then {clear};
    reset(fRvdLog);
    i:=0;
    repeat
      PlaySound(TsndUnpack);
      if IOResult<>0 then {clear};
      read(fRvdLog,RvdCurFile);
      if IOResult<>0 then break;
      if RvdCurFile.FileType =ftPacket then
        if UnPackPkt(RvdCurFile.Name) then Inc(i);
    until EOF(fRvdLog);
    close(fRvdLog);
    {-��䥪⨢��� ��ᥬ �� �p�諮..}
    if i =0 then WhatRcvd:=WhatRcvd and (not imNetMail);
   end;
  end;

  { 㤠�塞 ᯨ᪨ �p������/��᫠��� 䠩���}
  erase(fRvdLog);
  o:=IoResult;
  erase(fSntLog);
  o:=IoResult;

  if Aborted then with pRemoteInfo^ do begin
   (*if SessionType =Outgoing then A:=NodeEntry.Address;*)
   if Length(pCfgRec^.FR_Xternal) =0 then {-�᫨ �� ERP}
     FReqMan_End(true)  { aborted session }
   else
     DeleteFlag(pCfgRec^.FR_Response);
   RepackForAddr:='ps';
   RePackMail(RepackForAddr);   {��p��������� ��� ��� ��� AkA}
   if SessionType =Outgoing then begin
     i:=FindAddrInQueue(CallToAddr);
     {IF I <>0 THEN WRITELOGALL('om for '+_4D2str(CallToAddr)+' is '+HexW(Que[i]^.omMask))
     ELSE WRITELOGALL('!!! NO QUE for '+Addr2str(CallToAddr,true));}
     if (i =0) or
        (Que[i]^.omMask and (omNormalMail or omNormalAttach {or omFReq}) =0) then
      if (not CrashMode) then
       GeneratePoll(CallToAddr);
   end;
  end; {*IF ABORTED*}
  { ����襬 ����⨪� ��ᨨ, � ������ -- ����⨬ 䠩� ����⨪� }
  Inc(TrafficIn,TraffIn);
  Inc(TrafficOut,TraffOut);
  WriteHistory(SessionControl,Aborted);
  { �᫨ �宬뫠 ���������� �����筮 ��� ⮣�, �⮡� ��� � ������..}
  if (ArcMailInStorage >0) and
     (ArcMailInStorage <pCfgRec^.ArcMailThreshold) then
    WhatRcvd:=WhatRcvd and (not imArcMail)
  else { <0 ��� >=threshold }
   if WhatRcvd and imArcMail <>0 then ArcMailInStorage:=0;
 end; {*WITH SESSIONCONTROL*}
end;

procedure RecvThisFile(RcvdFname:PathStr; fSiz:longint);
{ ��뢠���� ��᫥ �p����� ������� 䠩��
  � 䨪�p�� � SessionControl.fRvdLog`�
  �� ����� �����, �᫨ �� *.PKT}
var
 x:string[4];
 i:byte;
 f:file;

begin
 with SessionControl^ do begin

  x:='.'+StLoCase(JustExtension(RcvdFname));

  if x =PktXt then begin
    WhatRcvd:=WhatRcvd or imNetMail;
    RvdCurFile.Name:=RcvdFname;   {��� �p���⮣� �����}
    RvdCurFile.FileType:=ftPacket;
   { ��p��� ��� �p����}
    {assign(fRvdLog,pCfgRec^.Packets+HexL(strCRC32(Addr2str(pRemoteInfo^.RemoteAddr[1],true)))+rvdXt);}
    reset(fRvdLog);
    seek(fRvdLog,FileSize(fRvdLog));
   { ����襬 �p����� PKT-䠩�}
    write(fRvdLog,RvdCurFile);
    close(fRvdLog);
  end
  else
   if x =ReqXt then begin
     { rename to *.reN, where N is RenNextFile }
     RenNextFile(AddBackSlash(JustPathname(RcvdFname)),JustFilename(RcvdFname));
     RcvdFname:=RenNextName;
     if ProtocolType =pt_ZModem then begin
      if Length(pCfgRec^.FR_Xternal) <>0 then
       ERP_Call(RcvdFname)
      else
       FReqMan_Begin(RcvdFname);
     end
     else begin
      FReqIn:=true;
      RvdCurFile.Name:=RcvdFname;   {��� �p���⮣� �����}
      RvdCurFile.FileType:=ftFReq;
      reset(fRvdLog);
      seek(fRvdLog,FileSize(fRvdLog));
      write(fRvdLog,RvdCurFile);
      close(fRvdLog);
     end;
   end
   else
    if (Length(x) =4) and (Pos(copy(x,1,3),ArcMailXt) <>0) then
      if ArcMailInStorage >=pCfgRec^.ArcMailThreshold then
        WhatRcvd:=WhatRcvd or imArcMail
      else begin
        if fSiz <1024 then Inc(ArcMailInStorage,1)
        else Inc(ArcMailInStorage,fSiz div 1024);
        if ArcMailInStorage >=pCfgRec^.ArcMailThreshold then
          WhatRcvd:=WhatRcvd or imArcMail;
      end
    else
     if x ='.tic' then WhatRcvd:=WhatRcvd or imTic
     else begin
       WhatRcvd:=WhatRcvd or imAnyFile;
       for i:=1 to TotalFmask do
         if CheckDosMask(JustFileName(RcvdFname),FmaskStr[i]^) then
           FmaskBits:=FmaskBits or (1 shl pred(i));
         {ELSE WRITELOGALL('FILE not match to mask "'+FmaskStr[i]^+'"');}
     end;
 end;
 if IoResult <>0 then
  LogWrite(emIoError,'',ld_All);
end;

end.
