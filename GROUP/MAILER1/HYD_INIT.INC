
(*************************************************************************)
(**    Init/DeInit Routines                                             **)
(*************************************************************************)

Function Hydra_Init(Hydra_Speed : longInt; Orig : boolean) : boolean;
begin
  Hydra_Init := false;
   RxPath:= AddBackSlash(InBound_Path);
   Originator:=Orig;
   HdxLink := false;
   SendByte:=0;
   ReceiveByte:=0;
   HSpeed:=Hydra_Speed;

  { Trace Debug }
   If TraceMode then begin
     Assign(traceFile,'hTrace.dbg');
     {$I-} Reset(traceFile,1); {$I+}
     If IOResult<>0 then
       Rewrite(traceFile,1);
     GetMem(TraceBuffer,1024);
     TraceCount:=0;
     Seek(TraceFile,FileSize(TraceFile));
     WriteTrace(TraceChar,TraceBord);
     WriteTrace(TraceChar,TraceBord);
   end;

  FillChar(Tx,SizeOf(tBufferControl),0);
  FillChar(Rx,SizeOf(tBufferControl),0);
  FillChar(RxTmp,SizeOf(tRXBuffer),0);
  GetMem(Tx.TransmitBuff,lTransmitBuff);
  GetMem(Rx.TransmitBuff,lTxSaveBuff);
  GetMem(Tx.DataBuff,lMaxBlock+8);
  GetMem(Rx.DataBuff,lMaxBlock+8);
  GetMem(RxTmp.TempBuff,lTransmitBuff);

  If (Tx.TransmitBuff = nil) or (Rx.TransmitBuff = nil) or
     (Tx.DataBuff = nil) or (Rx.DataBuff = nil) or
     (RxTmp.TempBuff = nil) then begin
      Hydra_DeInit;
      Exit;
  end;

  TimeOut:=Trunc(13567590 / Hydra_Speed);
  If (TimeOut <  182) then TimeOut := 182;
  If (TimeOut > 1092) then TimeOut := 1092;

  If Hydra_Speed < 2400 then
    Tx.BlockSize:=256
  else
    Tx.BlockSize:=512;
  Rx.BlockSize:=Tx.BlockSize;

  TxGoodBytes  := 0;
  TxGoodNeeded := 1024;
  SkippReq:=0;

  Hydra_Init := true;
end;

Procedure Hydra_DeInit;
begin
  { Trace Debug }
  If TraceMode then begin
     WriteTrace(TraceChar,TraceBord);
     WriteTrace(TraceChar,TraceBord);
     WriteFile(TraceFile,TraceBuffer^,TraceCount);
     FreeMem(TraceBuffer,1024);
     close(traceFile);
  end;

  If Tx.TransmitBuff <> nil then FreeMem(Tx.TransmitBuff,lTransmitBuff);
  If Rx.TransmitBuff <> nil then FreeMem(Rx.TransmitBuff,lTxSaveBuff);
  If Tx.DataBuff     <> nil then FreeMem(Tx.DataBuff,lMaxBlock+8);
  If Rx.DataBuff     <> nil then FreeMem(Rx.DataBuff,lMaxBlock+8);
  If RxTmp.TempBuff  <> nil then FreeMem(RxTmp.TempBuff,lTransmitBuff);
end;

