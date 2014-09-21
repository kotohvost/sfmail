{$A+,B-,D+,E-,F+,I-,L+,N-,O+,R-,S+,V-}
Unit Hydra;
Interface
uses dos;

{$I hyd_def.inc}

Function Hydra_Init(Hydra_Speed : longInt; Orig : boolean) : boolean;
Procedure Hydra_DeInit;
function H_Session(Caller:boolean):boolean;

Implementation
uses fos_lib,
     SfInclud,
     fileMan,
     config,
     SessCtl,
     CRC_All,
     EmStruct,
     WriteLog,
     UnixTime,
     Modem,
     HShow,
     Show,
     keyb,
     tpcrt,
     Date,
     {debug}
     tstring_,
     {debug}
     RelTQ;

{$I hyd_time.inc}
{$I hyd_misc.inc}
{$I hyd_out.inc}
{$I hyd_in.inc}

(*************************************************************************)
(**    Syncronize                                                       **)
(*************************************************************************)

function H_Session(Caller:boolean):boolean;
Var
  RXCount   : word;
  DleCount  : byte;
  RxPktBeg  : boolean;
  tmpWord   : Word;
  RxPkt     : boolean;
  Skiping   : boolean;
  TxDone    : boolean;
  FTime     : LongInt;
  FSize     : LongInt;
  DiskSpace : LongInt;
  ReturnLoop: boolean;

function HandleRPos:boolean;
begin
 HandleRPos:=false;
 if Get_Long(0)<0 then begin
  SayError(hErr_SkipNext,0,Tx.FileName,true);
  CloseAll;
  exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
  Tx.Pos:=Get_Long(0);
  TxState:=hstSkipFile;
 end;
 if (Get_Long(6)=Tx.SyncId) then begin
   Inc(Tx.Try);
   if Tx.Try >9 then begin
     SayError(hErr_ManyErr,0,'TX',true);
     CloseAll;
     exit;
   end;
 end;
 if (Get_Long(6)<>Tx.SyncId) and (Get_Long(0)>=0) then begin
   if Get_Long(0)<>TX.FileSize then
     Dec(SendByte,TX.Pos-Get_Long(0));
   TX.Pos:=Get_Long(0);
   TX.SyncId:=Get_Long(6);
   TX.Try:=1;
   if TX.Pos=TX.FileSize then begin
     LogWrite(imZRequestSkip,'',ld_SessAll);
     Skiping:=true;
   end else begin
     if TX.BlockSize>Get_Word(4) then
       TX.BlockSize:=Get_Word(4)
     else
       TX.BlockSize:=TX.BlockSize shr 1;
     if TX.BlockSize<=64 then TX.BlockSize:=64
     else
      if TX.BlockSize<=128 then TX.BlockSize:=128
      else
       if TX.BlockSize<=256 then TX.BlockSize:=256
       else
        if TX.BlockSize<=512 then TX.BlockSize:=512
        else
         TX.BlockSize:=1024;
     TxGoodBytes:=0;
     inc(TxGoodNeeded,1024);
     if TxGoodNeeded>8192 then
      TxGoodNeeded:=8192;
     SayError(hErr_Resend,TX.Pos,'',false);
   end;
   if Not SeekFile(Tx.WorkFile,Tx.Pos) then begin
     SayError(hErr_BadPos,TX.Pos,'TX',true);
     SayError(hErr_SkipNext,0,Tx.FileName,true);
     CloseAll;
     exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
     Tx.Pos:=-2;
     TxState:=hstSkipFile;
   end;
 end;
 ResetTimer(BrainTimer,2184{120});
 HandleRPos:=true;
end;

function ReadBytes:boolean;
begin
 ReadBytes:=false;
 repeat
   If (RxOptions and hOpt_HighBit) <> 0 then
     Rx.TransmitBuff^[RXCount] := Rx.TransmitBuff^[RXCount] and $7f;
   TmpWord:=Rx.TransmitBuff^[RXCount];
   If (RxOptions and hOpt_HighCtl) <> 0 then
    TmpWord := TmpWord and $7f;
   {convert bytes end}

   If ((TmpWord <> hDle) and
      (((RxOptions and hOpt_XonXoff <> 0) and (Rx.TransmitBuff^[RXCount] in [17,19]))  or
      ((RxOptions and hOpt_CtlChrs <> 0) and ((TmpWord < 32) or (TmpWord = 127))))) then
    Inc(RXCount) {* Ignore byte *}
   else begin
    If RxPktBeg then begin
      {Hачало пакета получено?}
      RXTmp.TempBuff^[RXTmp.TempCur]:=Rx.TransmitBuff^[RXCount];
      Inc(RxTmp.TempCur);
      If (RXTmp.LastRxByte=hdle) and
         (char(Rx.TransmitBuff^[RXCount]) <> hEndPkt) then begin
         {Пpедпоследний hDLE, но это не конец пакета}
         Dec(RXTmp.TempCur);
         RXTmp.TempBuff^[RXTmp.TempCur-1]:=Rx.TransmitBuff^[RXCount] xor $40;
      end else begin
        If (RXTmp.LastRxByte=hdle) and
           (char(Rx.TransmitBuff^[RXCount]) = hEndPkt) then begin
          { Конец пакета, обpабатываем }
          RxPktBeg:=false;
          If RetrivePkt(RXTmp.TempCur) then begin
           RxPkt:=true;
           RXTmp.TempCur:=0;
          end;
        end else begin
          {Пакет еще не полностью}
          If RXTmp.TempCur+5>=lTransmitBuff then begin
            RxPktBeg:=false;
            RXTmp.TempCur:=0;
          end;
          {Слишком длинный, игноpиpуем}
        end;
      end;
    end else begin
     RXTmp.TempCur:=0;
     If (RXTmp.LastRxByte=hdle) and (char(Rx.TransmitBuff^[RXCount]) in [hBinPkt..hUUEPkt]) then begin
       RxPktBeg:=true;
       RXTmp.TempBuff^[0]:=hDle;
       RXTmp.TempBuff^[1]:=Rx.TransmitBuff^[RXCount];
       RXTmp.TempCur:=2;
     end;
    end;

    RXTmp.LastRxByte:=Rx.TransmitBuff^[RXCount];
    Inc(RXCount);
    If RXTmp.LastRxByte=hDle then begin
      Inc(DleCount);
      If DleCount=5 then begin
        LogWrite(wmH5HDLE,'',ld_SessAll);
        CloseAll;
        exit;
      end;
    end else DleCount:=0;
   end;
 until RxPkt or (RxCur<=RXCount);
 ReadBytes:=true;
end;

begin
  {Initializing}
  H_Session:=false;
  TxCur:=0;
  RxCur:=0;
  Use32CRC:=false;
  TxOptions:=hCan_Options;
  RxOptions:=hInit_Options;
  RXOptStr:='';
  with pCfgRec^ do begin
    if pos('XON',Hydra_Caps) <> 0 then begin
      RXOptStr:='XON';
    end;
    if pos('TLN',Hydra_Caps) <> 0 then begin
      if RXOptStr[0]=#0 then
       RXOptStr:='TLN'
      else
       RXOptStr:=RXOptStr+',TLN';
    end;
    if pos('CTL',Hydra_Caps) <> 0 then begin
      if RXOptStr[0]=#0 then
       RXOptStr:='CTL'
      else
       RXOptStr:=RXOptStr+',CTL';
    end;
    if pos('HIC',Hydra_Caps) <> 0 then begin
      if RXOptStr[0]=#0 then
       RXOptStr:='HIC'
      else
       RXOptStr:=RXOptStr+',HIC';
    end;
    if pos('HI8',Hydra_Caps) <> 0 then begin
      if RXOptStr[0]=#0 then
       RXOptStr:='HI8'
      else
       RXOptStr:=RXOptStr+',HI8';
    end;
  end;

  { RxTmp }
  RXTmp.TempCur:=0;
  RxTmp.LastRxByte:=0;
  DleCount:=0;

  { Tx Type }
  Tx.PktPrefix:='';
  Tx.Try:=0;
  Tx.Pos:=0;
  FileRec(TX.WorkFile).mode:=fmClosed;
  TxState:=hstStart;
  TxDone:=false;
  ResetTimer(BrainTimer,2184{120});
  Skiping:=false;

  { Rx Type }
  Rx.PktPrefix:='';
  Rx.Try:=0;
  Rx.Pos:=0;
  FileRec(RX.WorkFile).mode:=fmClosed;
  RxState:=hsrInit;
  RxPktBeg:=false;
  RxPkt:=false;

  {Starting}
  LogWrite(imSynchronize,'',ld_Session);

  repeat { Global circle }

   {Transmit Bytes}
   if transmit=hLostCD then begin
     SayError(hErr_Carrier,0,'',true);
     CloseAll;
     exit;
   end;
   ShowTime;
   ShowSessTime;
   ShowTransfer;

   {Receive}
   RXCount:=0;
   ReturnLoop:=false;
   repeat
     {convert bytes start}
     if not ReturnLoop then begin
       if RXCur>RXCount then
         if not readBytes then begin
           CloseAll;
           exit;
         end;
     end;
     ReturnLoop:=false;

     { States of receiving }
     Case RxState of
      hsrInit      : begin
        if RxPkt and (Rx.PktType = hPktInit) then begin
          GetInit;
          StorePkt(0,hPktInitAck);
          ResetTimer(BrainTimer,2184{120});
          RxState:=hsrFInfo;
        end;
      end;

      hsrFInfo     : begin
        if RxPkt then begin
          Case Rx.PktType of
           hPktInit        : begin
             StorePkt(0,hPktInitAck);
           end;
           hPktFInfo: begin
             HClearFileName(true);
             if RX.DataBuff^[0]=0 then begin
               Put_Long(0,0);
               StorePkt(4,hPktFInfoAck);
               ResetTimer(BrainTimer,2184{120});
               RxState:=hsrDone;
             end else begin
               GetFileInfo;
               If RxPath[2]<>':' then
                 DiskSpace:=VirtualDiskFree(0)
               else begin
                 if RxPath[1] in ['A'..'Z'] then
                   DiskSpace:=VirtualDiskFree(byte(RxPath[1])-$40);
                 if RxPath[1] in ['a'..'z'] then
                   DiskSpace:=VirtualDiskFree(byte(RxPath[1])-$60);
               end;
               { Check for Exist file }
               if RX.FileSize=0 then begin
                 SayError(hErr_NullFile,0,Rx.FileName,true);
                 RX.Pos:=-1;
               end else begin
                 If FindFile(RxPath+RX.FileName, FSize, FTime) then begin
                   if FTime=RX.FileTime then begin
                     if FSize=RX.FileSize then begin
                     { Skipping, already have it }
                       RX.Pos:=-1;
                     end;
                     if FSize<RX.FileSize then begin
                     { Resuming file }
                       If DiskSpace<RX.FileSize-FSize then begin
                         SayError(hErr_FreeSp,0,'',true);
                         RX.Pos:=-2;
                       end else begin
                         RX.Pos:= FSize;
                         RX.Mode:= 'C';
                       end;
                     end;
                     if FSize>Rx.FileSize then begin
                     { Replacing file }
                       If DiskSpace<RX.FileSize then begin
                         SayError(hErr_FreeSp,0,'',true);
                         RX.Pos:=-2;
                       end else begin
                         RX.Pos:=0;
                         RX.Mode:= 'R';
                         SayError(hErr_Replace,0,RX.FileName,true);
                         RenNextFile(RxPath,RX.FileName);
                       end;
                     end;
                   end else begin
                   { Replacing file }
                     If DiskSpace<RX.FileSize then begin
                       SayError(hErr_FreeSp,0,'',true);
                       RX.Pos:=-2;
                     end else begin
                       RX.Pos:=0;
                       RX.Mode:= 'R';
                       SayError(hErr_Replace,0,RX.FileName,true);
                       RenNextFile(RxPath,RX.FileName);
                     end;
                   end;
                 end else begin
                 { New file }
                   If DiskSpace<RX.FileSize then begin
                     SayError(hErr_FreeSp,0,'',true);
                     RX.Pos:=-2;
                   end else begin
                     RX.Mode:= 'N';
                     RX.Pos:=0;
                   end;
                 end;
               end;
              {OpenFile}
               if RX.Pos>=0 then begin
                 if RX.Pos=0 then begin
                  If not (MakeFile(RX.WorkFile, RxPath+RX.FileName)) then begin
                    LogWrite(emCantCreate,stUpCase(RX.FileName),ld_SessAll);
                    RX.Pos:=-2;
                  end else
                    SetFileTime(RX.WorkFile, RX.FileTime);
                 end else begin
                  If not (OpenFile(RX.WorkFile, RxPath+RX.FileName,false)) then begin
                    LogWrite(emCantOpen,stUpCase(RX.FileName),ld_SessAll);
                    RX.Pos:=-2;
                  end else
                    SetFileTime(RX.WorkFile, RX.FileTime);
                 end;
                 if RX.Pos>=0 then
                   If not (SeekFile(RX.WorkFile, RX.Pos)) then begin
                     LogWrite(emCantSeek,StUpCase(RX.FileName),ld_SessAll);
                     CloseRX;
                     RX.Pos:=-2
                   end;
                 if RX.Pos>=0 then begin
                   RX.StartTime:=TimeCounter;
                   RX.StartSize:=RX.Pos;
                   HShowFileName(true);
                   LogWrite(imHRecv,CRCType+#3+StUpCase(Rx.FileName)+#3+
                            long2Str(Rx.FileSize),ld_Session);
                   LogWrite(imHRecv,CRCType+#3+RxPath+StLoCase(Rx.FileName)+#3+
                            long2Str(Rx.FileSize),ld_File);
                   RxState:=hsrToData;
                 end;
               end;
               Case RX.Pos of
               -2 : begin
                 ResetTimer(BrainTimer,2184{120});
                 SayError(hErr_SkipNext,0,Rx.FileName,true);
                 with SessionControl^ do
                   Inc(Traf_In_Cur,RX.FileSize);
               end;
               -1 : begin
                 ResetTimer(BrainTimer,2184{120});
                 LogWrite(imHSkip,RX.FileName,ld_SessAll);
                 with SessionControl^ do
                   Inc(Traf_In_Cur,RX.FileSize);
               end;
               else
                if RX.Pos>0 then begin
                   SayError(hErr_Resum,FSize,'RX',true);
                end;
               end;
               Put_Long(RX.Pos,0);
               StorePkt(4,hPktFInfoAck);
             end;
           end;
           hPktEOf  : begin
             Put_Long(RX.Pos,0);
             StorePkt(4,HPktEOfAck);
           end;
          end;
        end;
      end;

      hsrToData    : begin
        RX.SyncId:=0;
        RX.LastSync:=0;
        RX.Try:=0;
        ResetTimer(RX.Timer,TimeOut);
        ResetTimer(BrainTimer,2184{120});
        RxState:=hsrData;
      end;

      hsrData      : begin
        if SkippReq in [1,2] then begin
           LogWrite(imZSkipKeyboard,'',ld_SessAll);
           RX.Pos:=RX.FileSize;
           RX.LastSync:=0;
           RxState:=hsrBadPos;
           ReturnLoop:=true;
           Inc(SkippReq,10);
        end else begin
          if RxPkt then begin
            Case Rx.PktType of
              hPktFInfo: begin
                Put_Long(RX.Pos,0);
                StorePkt(4,hPktFInfoAck);
              end;
              hPktData : begin
                if Get_Long(0) = RX.Pos then begin
                  If not (WriteFile(RX.WorkFile, RX.DataBuff^[4],Rx.PktLen-4)) then begin
                    SayError(hErr_FErr,0,RX.FileName,true);
                    CloseRX;
                    RX.Pos:=-2;
                  end else begin
                    Inc(RX.Pos,Rx.PktLen-4);
                    Inc(ReceiveByte,RX.PktLen-4);
                    RX.Try:=0;
                    RX.LastSync:=RX.Pos;
                    RX.BlockSize:=RX.PktLen-4;
                    ResetTimer(RX.Timer,TimeOut);
                    ResetTimer(BrainTimer,2184{120});
                    HShowFilePos(true);
                    if RX.Window<>0 then begin
                      Put_Long(Rx.Pos,0);
                      StorePkt(4,hPktDataAck);
                    end;
                    If pCfgRec^.CommitSize <> 0 then begin
                      Inc(TotalSave,Rx.BlockSize);
                        If TotalSave div 1024 > pCfgRec^.CommitSize then begin
                          TotalSave:=0;
                          SetFileTime(RX.WorkFile,RX.FileTime);
                        end;
                    end;
                  end;
                end else begin
                  if SkippReq=0 then
                    SayError(hErr_BadPos,Get_Long(0),'RX',false);
                  RxState:=hsrBadPos;
                end;
              end;
              hPktEOf  : begin
                if Get_Long(0) = RX.Pos then begin
                  CloseRX;
                  if SkippReq=12 then
                    Erase(RX.WorkFile);
                  with SessionControl^ do
                    Inc(Traf_In_Cur,RX.FileSize);
                  HShowFilePos(true);
                  If SkippReq=0 then begin
                    HComplete(true);
                    RecvThisFile(RXPath+RX.FileName,RX.Pos);
                  end;
                  SkippReq:=0;
                  Put_Long(RX.Pos,0);
                  StorePkt(4,hPktEOfAck);
                  ResetTimer(RX.Timer,TimeOut);
                  ResetTimer(BrainTimer,2184{120});
                  RXState:=hsrFInfo;
                end else begin
                  if SkippReq=0 then
                    SayError(hErr_BadPos,Get_Long(0),'RX',false);
                  RxState:=hsrBadPos;
                end;
              end;
              hPktIdle : begin
                if not hdxLink then
                ResetTimer(BrainTimer,2184{120});
              end;
            end;
          end;
        end;
      end;

      hsrBadPos    : begin
        if Get_Long(0)<=Rx.LastSync then begin
          RX.Try:=0;
          ResetTimer(RX.Timer,TimeOut);
          RXState:=hsrData;
        end else begin
          if RX.Try=0 then begin
            RXState:=hsrRetries;
          end else begin
            if CheckTimer(RX.Timer) then
              RxState:=hsrHdxLink
            else
              RxState:=hsrData;
          end;
        end;
        RX.LastSync:=Get_Long(0);
        ReturnLoop:=true;
      end;

      hsrHdxLink   : begin
        if (RX.Try>4) and (TXState<hstREnd) and (not originator) then begin
          HdxLink:=true;
          RX.Try:=0;
        end;
        RXState:=hsrRetries;
        ReturnLoop:=true;
      end;

      hsrRetries   : begin
        Inc(RX.Try);
        If RX.Try>9 then begin
          SayError(hErr_ManyErr,0,'RX',true);
          CloseAll;
          exit;
        end;
        if Rx.Try = 1 then
          Inc(RX.SyncId);
        RX.BlockSize:= RX.BlockSize div 2;
        if RX.BlockSize<64 then
          RX.BlockSize:=64;
        Put_Long(RX.Pos,0);
        Put_Word(RX.BlockSize,4);
        Put_Long(RX.SyncId,6);
        StorePkt(10,hPktRPos);
        ResetTimer(RX.Timer,TimeOut);
        RXState:=hsrData;
        ReturnLoop:=true;
      end;

      hsrDone      : begin
        if RxPkt then begin
          if Rx.PktType=hPktFInfo then begin
            if RX.DataBuff^[0]=0 then
              Put_Long(0,0)
            else
              Put_Long(-2,0);
            ResetTimer(BrainTimer,2184{120});
            StorePkt(4,hPktFInfoAck);
          end;
        end;
      end;

     end; {Case}

     {States of Transmit ... }
     Case TxState of
       hstStart    : begin
         If TX.Try>9 then begin
           SayError(hErr_ManyErr,0,'TX',true);
           CloseAll;
           exit;
         end;
         { Send AutoStart String}
         Move(hAutoStart[1],TX.TransmitBuff^[TxCur],7);
         Inc(TxCur,7);
         { Send hStart Pkt }
         StorePkt(0,hPktStart);
         ResetTimer(Tx.Timer,91); { Tx.Timer --> 5 секунд таймаут }
         TxState:=hstSWait;
       end;

       hstSWait    : begin
         If RxPkt and ((Rx.PktType = hPktStart)
                    or (Rx.PktType = hPktInit)) then begin
           Tx.Try:=0;
           ResetTimer(BrainTimer,2184{120});
           TxState:=hstInit;
         end else begin
           if CheckTimer(Tx.Timer) then begin
             Inc(Tx.Try);
             SayError(hErr_TimeOut,Tx.Try,'TX',false);
             TxState:=hstStart;
           end;
         end;
       end;

       hstInit     : begin
         If TX.Try>9 then begin
           SayError(hErr_ManyErr,0,'TX',true);
           CloseAll;
           exit;
         end;
         StorePkt(StoreInit,hPktInit);
         ResetTimer(Tx.Timer,TimeOut div 2);
         TxState:=hstInitAck;
       end;

       hstInitAck  : begin
         If RxPkt and (Rx.PktType = hPktInitAck) then begin
           Tx.Try:=0;
           ResetTimer(BrainTimer,2184{120});
           TxState:=hstRInit;
         end else begin
           if CheckTimer(Tx.Timer) then begin
             Inc(Tx.Try);
             SayError(hErr_TimeOut,Tx.Try,'TX',false);
             TxState:=hstInit;
           end;
         end;
       end;

       hstRInit    : begin
        If RxState<>hsrInit then TxState:=hstNextFile;
       end;

       hstNextFile : begin
         { Check Files ... }
         RX.BlockSize:=0;
         HClearFileName(false);
         If SendThisFile(Tx.FileName,Tx.SendName,Skiping) then begin
           if not FindFile(Tx.FileName,Tx.FileSize,Tx.FileTime) then begin
             SayError(hErr_NotFound,0,Tx.FileName,true);
             Skiping:=true;
           end else begin
             if TX.FileSize=0 then begin
               SayError(hErr_NullFile,0,Tx.FileName,true);
               Skiping:=true;
             end else begin
               If not OpenFile(Tx.WorkFile,Tx.FileName,true) then begin
                 SayError(hErr_NotOpen,0,Tx.FileName,true);
                 CloseAll;
                 exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
               end else begin
                 LogWrite(imHSend,CRCType+#3+TruncPathName(Tx.FileName+
                          ' ('+long2Str(Tx.FileSize)+')',47),
                          ld_Session);
                 LogWrite(imHSend,CRCType+#3+Tx.FileName+
                          ' ('+long2Str(Tx.FileSize)+')',ld_File);
                 Tx.SyncId:=0;
                 Tx.Try:=0;
                 TxState:=hstFInfo;
               end;
             end;
           end;
         end else begin
           TxDone:=true;
           TxState:=hstFInfo;
         end;
       end;

       hstFInfo    : begin
         if TxCur<2048 then begin { Пpовеpяем место в буфеpе }
           if Tx.Try >9 then begin
             SayError(hErr_ManyErr,0,'TX',true);
             CloseAll;
             exit;
           end;
           if TxDone then begin
             Put_Long(0,0);
             StorePkt(4,hPktFInfo);
           end else begin
             StorePkt(StoreFileInfo,hPktFInfo);
           end;
           TxState:=hstFInfoAck;
           if Tx.Try>0 then
             ResetTimer(Tx.Timer,timeOut)
           else
             ResetTimer(Tx.Timer,timeOut div 2);
         end;
       end;

       hstFInfoAck : begin
         if RxPkt and (RX.PktType = hPktFInfoAck) then begin
           if TxDone then begin        { это был последний файл? }
             ResetTimer(Tx.Timer,364); { Idle TimeOut }
             TxState:=hstREnd;
           end else begin
             Tx.Pos:=Get_Long(0);
             case Tx.Pos of
             -2 : begin
                  SayError(hErr_SkipNext,0,Tx.FileName,true);
                  CloseAll;
                  exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
                  CloseTX;
                  TxState:=hstNextFile;
                  with SessionControl^ do
                    Inc(Traf_Out_Cur,TX.FileSize);
                end;
             -1 : begin
                  SayError(hErr_Skip,0,StUpCase(Tx.FileName),true);
                  Skiping:=true;
                  CloseTX;
                  TxState:=hstNextFile;
                  with SessionControl^ do
                    Inc(Traf_Out_Cur,TX.FileSize);
                end;
             else
               if Tx.Pos >= 0 then begin
                 Skiping:=false;
                 TxState:=hstData;
                 Tx.lastAck:=Tx.Pos;
                 Tx.Try:=0;
                 if TX.Pos>0 then
                   TX.Mode:='C'
                 else
                   TX.Mode:='N';
                 TX.StartTime:=TimeCounter;
                 TX.StartSize:=TX.Pos;
                 HShowFileName(false);
                 if Tx.Pos>0 then
                   SayError(hErr_Resum,TX.Pos,'TX',true);
                 HShowFilePos(false);
                 { ShowTxFileInfo OOPS!}
                 if Not SeekFile(Tx.WorkFile,Tx.Pos) then begin
                   SayError(hErr_BadPos,TX.Pos,'TX',true);
                   SayError(hErr_SkipNext,0,Tx.FileName,true);
                   CloseAll;
                   exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
                   CloseTX;
                   Tx.Pos:=-2;
                   TxState:=hstSkipFile;
                 end;
               end;
             end;
           end;
           ResetTimer(BrainTimer,2184{120});
         end else begin
           if CheckTimer(Tx.Timer) then begin
             Inc(Tx.Try);
             SayError(hErr_TimeOut,Tx.Try,'TX',false);
             TxState:=hstFInfo;
           end;
         end;
       end;

       hstData     : begin
         if (RxState<>hsrDone) and hdxLink then begin
           ResetTimer(Tx.Timer,364); { Idle TimeOut }
           TxState:=hstXWait;
         end else begin
           If RxPkt then begin
             Case Rx.PktType of
               hPktDataAck   : begin
                 TX.LastAck:=Get_Long(0);
               end;
               hPktRPos   : if not HandleRPos then exit;
               hPktIdle   : ResetTimer(BrainTimer,2184{120});
             end;
           end;
           if TxState=hstData then begin
             { есть ли место для новых данных? }
             if (Tx.Window<>0) and (TX.Pos>=TX.LastAck+TX.Window) then begin
               TxState:=hstDataAck;
               if Tx.Try=0 then
                 ResetTimer(Tx.Timer,timeOut)
               else
                 ResetTimer(Tx.Timer,timeOut div 2);
             end else begin
               if TXCur<256 then begin
                 Put_Long(TX.Pos,0);
                 if not ReadFile(TX.WorkFile,Tx.DataBuff^[SizeOf(LongInt)],
                                 Tx.BlockSize,TmpWord) then begin
                   SayError(hErr_FErr,0,Tx.FileName,true);
                   SayError(hErr_SkipNext,0,Tx.FileName,true);
                   CloseAll;
                   exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
                   CloseTX;
                   Tx.Pos:=-2;
                   TxState:=hstSkipFile;
                 end;
                 Inc(SendByte,TmpWord);
                 if TmpWord<>0 then begin
                   Inc(Tx.Pos,TmpWord);
                   Inc(TxGoodBytes,TmpWord);
                   if TxGoodBytes>TxGoodNeeded then begin
                     TX.BlockSize:=TX.BlockSize shl 1;
                     If TX.BlockSize>2048 then
                       TX.BlockSize:=2048;
                     TxGoodBytes:=0;
                   end;
                   Inc(TmpWord,SizeOf(LongInt));
                   StorePkt(TmpWord,hPktData);
                 end;
                 HShowFilePos(false);
               end;
               if EOf(TX.WorkFile) then begin
                 TxState:=hstEOf;
               end;
             end;
           end;
         end;
       end;

       hstSkipFile : begin
         TX.Pos:=-1;
         TX.Try:=0;
         TxState:=hstEOf;
       end;

       hstDataAck  : begin
         if Tx.Try >9 then begin
           SayError(hErr_ManyErr,0,'TX',true);
           CloseAll;
           exit;
         end;
         If RxPkt then begin
           Case Rx.PktType of
             hPktDataAck   : begin
               if (Get_Long(0)>TX.LastAck) and
                  (TX.Pos<Get_Long(0)+TX.Window) then begin
               TX.LastAck:=Get_Long(0);
               TX.Try:=0;
               ResetTimer(Tx.Timer,TimeOut);
               TXState:=hstData;
               end;
             end;
             hPktRPos      : if not HandleRPos then exit;
           end;
         end;
         if CheckTimer(Tx.Timer) then begin
           Inc(Tx.Try);
           SayError(hErr_TimeOut,Tx.Try,'TX',false);
           TxState:=hstData;
         end;
       end;

       hstXWait    : begin
         if RxState=hsrDone then begin
           ResetTimer(TX.Timer,TimeOut);
           TxState:=hstData;
         end;
         If RxPkt then begin
           Case Rx.PktType of
             hPktDataAck   : begin
               if Get_Long(0)>TX.LastAck then
               TX.LastAck:=Get_Long(0);
             end;
             hPktRPos      : if not HandleRPos then exit;
             hPktIdle      : begin
               hdxLink:=false;
               ResetTimer(TX.Timer,TimeOut);
               TxState:=hstData;
             end;
           end;
         end;
         if CheckTimer(Tx.Timer) then begin
           StorePkt(0,hPktIdle);
           ResetTimer(Tx.Timer,364); { Idle TimeOut }
         end;
       end;

       hstEOf      : begin
         if Tx.Try >9 then begin
           SayError(hErr_ManyErr,0,'TX',true);
           CloseAll;
           exit;
         end;
         Put_Long(TX.Pos,0);
         StorePkt(SizeOf(LongInt),hPktEOf);
         if TX.Try=0 then
           ResetTimer(TX.Timer,TimeOut)
         else
           ResetTimer(TX.Timer,TimeOut div 2);
         TxState:=hstEOfAck;
       end;

       hstEOfAck   : begin
         If RxPkt then begin
           Case Rx.PktType of
             hPktEOfAck    : begin
               CloseTX;
               HShowFilePos(false);
               if not skiping then
                 HComplete(false);
               with SessionControl^ do
                 Inc(Traf_Out_Cur,TX.FileSize);
               ResetTimer(BrainTimer,2184{120});
               TxState:=hstNextFile;
             end;
             hPktDataAck   : begin
               if Get_Long(0)>TX.LastAck then
               TX.LastAck:=Get_Long(0);
             end;
             hPktRPos      : begin
               if (Get_Long(6)=-2) and (TX.Pos<>-2) then begin
                 SayError(hErr_SkipNext,0,Tx.FileName,true);
                 CloseAll;
                 exit; { Skiping:=3 OOPS! Пpопускаем на эту сессию }
                 CloseTX;
                 Tx.Pos:=-2;
                 TxState:=hstEOf;
               end else begin
                 if not HandleRPos then exit;
                 TxState:=hstData;
               end;
             end;
           end;
         end;
         if CheckTimer(Tx.Timer) then begin
           Inc(Tx.Try);
           SayError(hErr_TimeOut,Tx.Try,'TX',false);
           TxState:=hstEOf;
         end;
       end;

       hstREnd     : begin
         if RxState=hsrDone then begin
           TX.Try:=0;
           TXState:=hstEnd;
         end;
         if CheckTimer(Tx.Timer) then begin
           StorePkt(0,hPktIdle);
           ResetTimer(Tx.Timer,364); { Idle TimeOut }
         end;
       end;

       hstEnd      : begin
         if Tx.Try >9 then begin
           SayError(hErr_ManyErr,0,'TX',true);
           CloseAll;
           exit;
         end else begin
           StorePkt(0,hPktEnd);
           StorePkt(0,hPktEnd);
           ResetTimer(Tx.Timer, TimeOut div 2);
           TxState:=hstEndAck;
         end;
       end;

       hstEndAck   : begin
         if RxPkt and (Rx.PktType=hPktEnd) then begin
           StorePkt(0,hPktEnd);
           StorePkt(0,hPktEnd);
           StorePkt(0,hPktEnd);
           SayError(hErr_Complete,0,'',false);
           Transmit;
           H_Session:=true;
           CloseAll;
           Exit;
         end else begin
           if RxPkt and (Rx.PktType=hPktIdle) then
             StorePkt(0,hPktEnd);
         end;
       end;
       { ----------------------------------------------------------------- }
     end;

     if not ReturnLoop then
       RxPkt:=false;

   until RxCur<=RXCount;

   If CheckTimer(BrainTimer) then begin
     SayError(hErr_BrainDead,0,'',true);
     CloseAll;
     exit;
   end;

   if not CheckKeyboard then begin
    LogWrite(wmSessKeybAbbort,'',ld_SessAll);
    CloseAll;
    exit;
   end;

  until false;
end;

{$I hyd_init.inc}

end.


