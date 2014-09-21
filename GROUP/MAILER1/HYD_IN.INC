(*************************************************************************)
(**    In Packets Routines                                              **)
(*************************************************************************)

function Get_BinBuff(Len:word):word;
begin
  Get_BinBuff:=0;
  if len>lMaxBlock then exit;
  move(RxTmp.TempBuff^[2],RX.DataBuff^[0],len-4);
  Get_BinBuff:=len-4;
end;

function Get_AscBuff(Len:word):word;
Var
  Count : word;
  N,C   : word;
  i     : word;
begin
  N:=0;C:=0;
  Count:=0;
  Get_AscBuff:=0;
  For i:=2 to Len-3 do begin
    N:=N or ((RxTmp.TempBuff^[i] and $7f) shl C);
    Inc(C,7);
    If C>=8 then begin
      Rx.DataBuff^[Count]:=byte(N);
      Inc(Count);
      if Count>lMaxBlock then exit;
      N:=N shr 8;
      Dec(C,8);
    end;
  end;
  Get_AscBuff:=Count;
end;

function Get_UUEBuff(Len:word):word;
Var
  Count : word;
  i     : word;
begin
  Count:=0;
  Get_UUEBuff:=0;

  For i:=2 to Len-3 do
    RxTmp.TempBuff^[i]:=(RxTmp.TempBuff^[i]-33) and $3F;

  i:=2;
  While i<Len-3 do begin
    Rx.DataBuff^[count]  :=(RxTmp.TempBuff^[i] shl 2) or
                           (RxTmp.TempBuff^[i+1] shr 4);
    Rx.DataBuff^[count+1]:=(RxTmp.TempBuff^[i+1] shl 4) or
                           (RxTmp.TempBuff^[i+2] shr 2);
    Rx.DataBuff^[count+2]:=(RxTmp.TempBuff^[i+2] shl 6) or
                           (RxTmp.TempBuff^[i+3]);
    Inc(Count,3);
    Inc(I,4);
    if Count>lMaxBlock-3 then exit;
  end;
  Case (Len mod 4) of
   2 : Dec(Count,2);
   3 : Dec(Count);
  end;
  Get_UUEBuff:=Count;
end;

function Get_HexBuff(Len:word):word;
Var
  i     : word;
  count : word;
begin
  count:=0;
  Get_HexBuff:=0;
  For i:=2 to Len-3 do begin
   if RxTmp.TempBuff^[i] = byte('\') then begin
     If RxTmp.TempBuff^[i+1]=byte('\') then begin
       RX.DataBuff^[Count]:=byte('\');
       Inc(I);
     end else begin
       Case RxTmp.TempBuff^[i+1] of
         $30..$39 : Dec(RxTmp.TempBuff^[i+1],$30);
         $41..$46 : Dec(RxTmp.TempBuff^[i+1],$37);
         $61..$66 : Dec(RxTmp.TempBuff^[i+1],$57);
       end;
       Case RxTmp.TempBuff^[i+2] of
         $30..$39 : Dec(RxTmp.TempBuff^[i+2],$30);
         $41..$46 : Dec(RxTmp.TempBuff^[i+2],$37);
         $61..$66 : Dec(RxTmp.TempBuff^[i+2],$57);
       end;
       RX.DataBuff^[Count]:=(RxTmp.TempBuff^[i+1] shl 4) + RxTmp.TempBuff^[i+2];
       Inc(I,2);
     end;
   end else begin
     RX.DataBuff^[Count]:=RxTmp.TempBuff^[i];
   end;
   Inc(Count);
   If Count>lMaxBlock then exit;
  end;
  Get_HexBuff:=Count;
end;

function RetrivePkt(Len:word):boolean;
Var
  CRCRes     : boolean;
  TmpStr     : string;
  FormatPkt  : char;
  f : file;
begin
  RetrivePkt:=false;
  FormatPkt:=char(RXTmp.TempBuff^[1]);

  Case FormatPkt of
    hBinPkt : RX.PktLen:=Get_BinBuff(Len);
    hHexPkt : RX.PktLen:=Get_HexBuff(Len);
    hAscPkt : RX.PktLen:=Get_AscBuff(Len);
    hUUEPkt : RX.PktLen:=Get_UUEBuff(Len);
  end;

  If (FormatPkt<>hHexPkt) and (RxOptions and hOpt_CRC32 <> 0) then begin
    If RX.PktLen<5 then exit;
    RX.PktType:=char(RX.DataBuff^[RX.PktLen-5]);
    CRCRes := (Crc32Block($FFFFFFFF,RX.DataBuff,RX.PktLen) = $DEBB20E3);
    Dec(RX.PktLen, SizeOf(longint)+1);   (*Remove CRC-32*)
  end else begin
    If RX.PktLen<3 then exit;
    RX.PktType:=char(RX.DataBuff^[RX.PktLen-3]);
    CRCRes := (Crc16Block($FFFF,RX.DataBuff,RX.PktLen) = $F0B8);
    Dec(RX.PktLen, SizeOf(word)+1);      (*Remove CRC-16*)
  end;

  If tracemode then begin
    Case FormatPkt of
     hHexPkt : TmpStr:='Hex Packet: ';
     hBinPkt : TmpStr:='Bin Packet: ';
     hAscPkt : TmpStr:='Asc Packet: ';
     hUUEPkt : TmpStr:='UUE Packet: ';
    end;

    Case RX.PktType of
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

    if CRCRes then
       LogWrite(0,'<þùú Receive '+TmpStr+', Size: ('+Long2Str(Len)+
                  '/'+Long2Str(RX.PktLen)+')',ld_SessAll)
    else
       LogWrite(0,'<þùú Receive '+TmpStr+', Size: ('+Long2Str(Len)+
                  '/'+Long2Str(RX.PktLen)+') bad CRC!',ld_SessAll);
  end;

  RetrivePkt:=CRCRes;
end;

