(*************************************************************************)
(**    Out Packets Routines                                             **)
(*************************************************************************)

procedure Put_HexByte(StoreByte:byte);
  Var
    TStr : String;
begin
  If (StoreByte and $80) <> 0 then begin
   TStr:='\'+LowHexByte(StoreByte);
   Move(TStr[1],TX.TransmitBuff^[TxCur],3);
   Inc(TxCur,3);
  end else begin
   If (StoreByte<32) or (StoreByte=127) then begin
     TX.TransmitBuff^[TxCur]:=hDle;
     Inc(TxCur);
     TX.TransmitBuff^[TxCur]:=StoreByte xor $40;
     Inc(TxCur);
   end else begin
     If StoreByte = 92 then begin
      TX.TransmitBuff^[TxCur]:=byte('\');
      Inc(TxCur);
      TX.TransmitBuff^[TxCur]:=byte('\');
      Inc(TxCur);
     end else begin
      TX.TransmitBuff^[TxCur]:=StoreByte;
      Inc(TxCur);
     end;
   end;
  end;
end;

procedure Put_BinByte(StoreByte:byte);
Var TByte : byte;
begin
  TByte:=StoreByte;
  If (RxOptions and hOpt_HighCtl) <> 0 then
   TByte:=StoreByte and $7F;
  If ((TByte = hDle) or
     (((RxOptions and hOpt_XonXoff)<>0) and ((TByte=17) or (TByte=19)) ) or
     (((RxOptions and hOpt_Telenet)<>0) and ((TByte=13) and (LastByte=64)) ) or
     (((RxOptions and hOpt_CtlChrs)<>0) and ((TByte<32) or (TByte=127)) )) then begin
    TX.TransmitBuff^[TxCur]:=hDle;
    Inc(TxCur);
    StoreByte:=StoreByte xor $40;
  end;
  TX.TransmitBuff^[TxCur]:=StoreByte;
  Inc(TxCur);
  LastByte:=StoreByte;
end; {Put_BinByte}

procedure Put_ASCIIBuf(Buff:pBuffer;Len:word);
Var N,C   : word;
    TWord : word;
begin
  N:=0; C:=0;
  For TWord:= 0 to pred(Len) do begin
   C:=C or (Buff^[TWord] shl N);
   Put_BinByte(byte(C) and $7F);
   C:=C shr 7;
   Inc(N);
   If N>6 then begin
    Put_BinByte(byte(C) and $7F);
    N:=0; C:=0;
   end;
  end;
  If N > 0 then Put_BinByte(byte(C) and $7F);
end;

procedure Put_UUEBuf(Buff:pBuffer;Len:word);
  Var TWord : word;
begin
  TWord:=0;
  While Len>2 do begin
    TX.TransmitBuff^[TxCur]:=((Buff^[TWord] shr 2) and $3F) +33;
    TX.TransmitBuff^[Succ(TxCur)]:= (((Buff^[TWord] shl 4) and $30) or
                    ((Buff^[succ(TWord)] shr 4) and $0F)
                    and $3F) +33;
    TX.TransmitBuff^[TxCur+2]:= (((Buff^[succ(TWord)] shl 2) and $3c) or
                    ((Buff^[TWord+2] shr 6) and $03)
                    and $3F) +33;
    TX.TransmitBuff^[TxCur+3]:= (Buff^[TWord+2] and $3F) +33;
    Inc(TxCur,4);
    Inc(TWord,3);
    Dec(Len,3);
  end;
  If Len > 0 then begin
    TX.TransmitBuff^[TxCur]:=((Buff^[TWord] shr 2) and $3F) +33;
    TX.TransmitBuff^[Succ(TxCur)]:= (((Buff^[TWord] shl 4) and $30) or
                  ((Buff^[succ(TWord)] shr 4) and $0F)
                  and $3F) +33;
    Inc(TxCur,2);
    If Len = 2 then begin
      TX.TransmitBuff^[TxCur]:=((Buff^[TWord+1] shl 2) and $3C) +33;
      Inc(TxCur);
    end;
  end;
end;

procedure StorePkt(PktLen:word; PktType:char);
Var
  CRC        : word;      {CRC-16}
  CRC32      : LongInt;   {CRC-32}
  TmpStr     : string;
  FormatPkt  : char;
  CRC32Pkt   : boolean;
  indexIn    : word;

begin

  If Length(Tx.PktPrefix) >0 then
   For IndexIn:=1 to Length(Tx.PktPrefix) do begin
    Case Tx.PktPrefix[IndexIn] of
     #221,#222 : ;
     #223 : begin
      TX.TransmitBuff^[TxCur]:=0;
      Inc(TxCur);
     end;
    else
      TX.TransmitBuff^[TxCur]:=byte(Tx.PktPrefix[IndexIn]);
      Inc(TxCur);
    end;
   end;

  CRC32Pkt := false;

  Tx.DataBuff^[PktLen]:=byte(PktType);
  Inc(PktLen);

  Case PktType of
   hPktStart,
   hPktInit,
   hPktInitACK,
   hPktEnd,
   hPktIdle : FormatPkt:=hHexPkt;
   else
    If (RxOptions and hOpt_HighBit) <> 0 then begin
      If ((RxOptions and hOpt_CtlChrs <> 0) and
          (RxOptions and hOpt_CanUUE <> 0)) then begin
        FormatPkt := hUUEPkt;
      end else begin
       If (RxOptions and hOpt_CanAsc) <> 0 then
        FormatPkt := hAscPkt
       else
        FormatPkt := hHexPkt;
      end;
    end else
     FormatPkt := hBinPkt;
   end;

 If (FormatPkt<>hHexPkt) and ((RxOptions and hOpt_CRC32) <> 0) then
   CRC32Pkt:=true;

 If tracemode then begin
   Case FormatPkt of
    hHexPkt : TmpStr:='Hex Packet: ';
    hBinPkt : TmpStr:='Bin Packet: ';
    hAscPkt : TmpStr:='Asc Packet: ';
    hUUEPkt : TmpStr:='UUE Packet: ';
   end;

   Case PktType of
    hPktStart   : TmpStr:=TmpStr+'Start';
    hPktInit    : TmpStr:=TmpStr+'Init';
    hPktInitACK : TmpStr:=TmpStr+'AckInit';
    hPktFInfo   : TmpStr:=TmpStr+'File Info';
    hPktFInfoACK: TmpStr:=TmpStr+'FInfo Ack';
    hPktData    : TmpStr:=TmpStr+'Data';
    hPktDataACK : TmpStr:=TmpStr+'Data Ack';
    hPktRPos    : TmpStr:=TmpStr+'RPos';
    hPktEof     : TmpStr:=TmpStr+'Eof';
    hPktEofACK  : TmpStr:=TmpStr+'Eof Ack';
    hPktEnd     : TmpStr:=TmpStr+'End';
    hPktIdle    : TmpStr:=TmpStr+'Idle';
    hPktDevDate : TmpStr:=TmpStr+'Device';
    hPktDevDACK : TmpStr:=TmpStr+'Device ACK';
   end;

    Case TxState of
     hstStart    : TmpStr:=TmpStr+'. TX: hstStart /';
     hstSWait    : TmpStr:=TmpStr+'. TX: hstSWait /';
     hstInit     : TmpStr:=TmpStr+'. TX: hstInit /';
     hstInitAck  : TmpStr:=TmpStr+'. TX: hstInitAck /';
     hstRInit    : TmpStr:=TmpStr+'. TX: hstRInit /';
     hstNextFile : TmpStr:=TmpStr+'. TX: hstNextFile /';
     hstFInfo    : TmpStr:=TmpStr+'. TX: hstFInfo /';
     hstFInfoAck : TmpStr:=TmpStr+'. TX: hstFInfoAck /';
     hstData     : TmpStr:=TmpStr+'. TX: hstData /';
     hstSkipFile : TmpStr:=TmpStr+'. TX: hstSkipFile /';
     hstDataAck  : TmpStr:=TmpStr+'. TX: hstDataAck /';
     hstXWait    : TmpStr:=TmpStr+'. TX: hstXWait /';
     hstEOF      : TmpStr:=TmpStr+'. TX: hstEOF /';
     hstEOFAck   : TmpStr:=TmpStr+'. TX: hstEOFAck /';
     hstREnd     : TmpStr:=TmpStr+'. TX: hstREnd /';
     hstEnd      : TmpStr:=TmpStr+'. TX: hstEnd /';
     hstEndAck   : TmpStr:=TmpStr+'. TX: hstEndAck /';
     hstDone     : TmpStr:=TmpStr+'. TX: hstDone /';
    end;

    Case RxState of
     hsrInit     : TmpStr:=TmpStr+' RX: hsrInit';
     hsrFInfo    : TmpStr:=TmpStr+' RX: hsrFInfo';
     hsrToData   : TmpStr:=TmpStr+' RX: hsrToData';
     hsrData     : TmpStr:=TmpStr+' RX: hsrData';
     hsrBadPos   : TmpStr:=TmpStr+' RX: hsrBadPos';
     hsrHdxLink  : TmpStr:=TmpStr+' RX: hsrHdxLink';
     hsrRetries  : TmpStr:=TmpStr+' RX: hsrRetries';
     hsrDone     : TmpStr:=TmpStr+' RX: hsrDone';
    end;


   LogWrite(0,'úùþ> Send '+TmpStr,ld_SessAll);
 end;

 If CRC32Pkt then begin
   CRC32 := not (Crc32Block($FFFFFFFF,Tx.DataBuff,PktLen));
   move(CRC32, Tx.DataBuff^[PktLen],SizeOf(longInt));
   Inc(PktLen,SizeOf(longInt));
 end else begin
   Crc := not (Crc16Block($FFFF,Tx.DataBuff,PktLen));
   move(CRC, Tx.DataBuff^[PktLen],SizeOf(word));
   Inc(PktLen,SizeOf(word));
 end;
 LastByte:=0;

 TX.TransmitBuff^[TxCur]:=hDle;
 Inc(TxCur);
 TX.TransmitBuff^[TxCur]:=byte(FormatPkt);
 Inc(TxCur);

   Case FormatPkt of
     hHexPkt : for IndexIn := 0 to pred(PktLen) do
               Put_HexByte(Tx.DataBuff^[IndexIn]);
     hBinPkt : for IndexIn := 0 to pred(PktLen) do
               Put_BinByte(Tx.DataBuff^[IndexIn]);
     hAscPkt : Put_ASCIIBuf(Tx.DataBuff,PktLen);
     hUUEPkt : Put_UUEBuf(Tx.DataBuff,PktLen);
   end;

 TX.TransmitBuff^[TxCur]:=hDle;
 TX.TransmitBuff^[succ(TxCur)]:=byte(hEndPkt);
 Inc(TxCur,2);
 If (PktType <> hPktData) and (FormatPkt <> hBinPkt) then begin
   TX.TransmitBuff^[TxCur]:=13;
   TX.TransmitBuff^[succ(TxCur)]:=10;
   Inc(TxCur,2);
 end;
end;

