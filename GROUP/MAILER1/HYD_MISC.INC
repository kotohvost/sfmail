(*************************************************************************)
(**    Trace file routines                                              **)
(*************************************************************************)

procedure WriteTrace(TraceByte, Color:byte);
begin
  TraceBuffer^[TraceCount]:=TraceByte;
  TraceBuffer^[succ(TraceCount)]:=color;
  Inc(TraceCount,2);
  If TraceCount>1022 then begin
     WriteFile(TraceFile,TraceBuffer^,TraceCount);
     TraceCount:=0;
  end;
end;

(*************************************************************************)
(**    Функция анализа состояния буфеpов                                **)
(*************************************************************************)

function Transmit: integer;
Var
  Result : integer;
  i      : word;
begin
  { Carrier check }
  If (GetPortStat And ST_DCD) = 0 then begin
    Transmit:=hLostCD;
    exit;
  end else
   Result:=0;
  { Get Buffers Info }
  BuffInfo(RxFree, TxFree, RxTotal, TxTotal);
  if TxCur>0 then begin
    { Sending all Block }
    if (TxFree>TxCur) and (TxCur<>0) and ((TxTotal-TxFree)<512) then begin
       WriteBlock(TxCur, Tx.TransmitBuff);
       If tracemode then begin
         For i:=0 to TxCur-1 do
         WriteTrace(Tx.TransmitBuff^[i],TraceSend);
       end;
       TxCur  :=0;
       Result :=hTransSnd;
    end else begin
     if TXCur>(TxTotal - TxTotal div 4) then begin
       { ... возможно послать надо больше чем TxTotal ... }
       Result:=WriteBlock(TxCur, Tx.TransmitBuff);
       If Result>0 then begin
         move(Tx.TransmitBuff^[Result],Tx.TransmitBuff^[0],TxCur-Result);
         Dec(TxCur,Result);
         Result :=hTransSnd;
       end;
     end else ReleaseTQ;
    end;
  end else ReleaseTQ;
  If RxTotal>RxFree then begin   { Somthing receive }
     RxCur:=ReadBlock(lTransmitBuff,Rx.TransmitBuff);
     If (tracemode) and (RxCur<>0) then begin
       For i:=0 to RxCur-1 do
       WriteTrace(Rx.TransmitBuff^[i],TraceRecv);
     end;
     Inc(Result,hTransRcv);
     If RxCur<hTransRTQ then
        ReleaseTQ;
  end else RxCur:=0;
  If Result=0 then ReleaseTQ;
  Transmit:=Result;
end;

(*************************************************************************)
(**    Misc Routines                                                    **)
(*************************************************************************)

function StoreInit:word;
Var
  TmpStr  : String;
  TmpStr1 : String;
  Count   : word;
begin
  TmpStr:=hRevStamp+                           {,DEV}
          #0'XON,TLN,CTL,HIC,HI8,BRK,ASC,UUE,C32'#0+RXOptStr+#0'0000000000000000'#0#0;
  Move(TmpStr[1],TX.DataBuff^[0],length(TmpStr));
  StoreInit:=length(TmpStr);
end;

procedure CalcWindow(S:string);
Var
  code  : integer;
begin
  Val('$'+Copy(S,1,8),Rx.Window,Code);
  if (Code<>0) or (Rx.Window<0) then Rx.Window:=0;
  Val('$'+Copy(S,9,8),Tx.Window,Code);
  if (Code<>0) or (Tx.Window<0) then Tx.Window:=0;
end;

procedure GetInit;
Var
  TmpStr : String;
  TmpStr1: String;
  i      : word;
begin
  i:=1;
  while RX.DataBuff^[i]<>0 do
    Inc(i);
  Inc(i);
  TmpStr:='';
  while RX.DataBuff^[i]<>0 do begin
    TmpStr:=TmpStr+char(RX.DataBuff^[i]);
    Inc(i);
  end;
  Inc(i);
  TmpStr1:='';
  while RX.DataBuff^[i]<>0 do begin
    TmpStr1:=TmpStr1+char(RX.DataBuff^[i]);
    Inc(i);
  end;
  Inc(i);

  RXOptions:=0;
  with pCfgRec^ do begin
    if pos('XON',Hydra_Caps) <> 0 then RxOptions:=RxOptions or hOpt_XonXoff;
    if pos('TLN',Hydra_Caps) <> 0 then RxOptions:=RxOptions or hOpt_Telenet;
    if pos('CTL',Hydra_Caps) <> 0 then RxOptions:=RxOptions or hOpt_CtlChrs;
    if pos('HIC',Hydra_Caps) <> 0 then RxOptions:=RxOptions or hOpt_HighCtl;
    if pos('HI8',Hydra_Caps) <> 0 then RxOptions:=RxOptions or hOpt_HighBit;
  end;

  {* want *}
  if pos('XON',TmpStr1) <> 0 then RxOptions:=RxOptions or hOpt_XonXoff;
  if pos('TLN',TmpStr1) <> 0 then RxOptions:=RxOptions or hOpt_Telenet;
  if pos('CTL',TmpStr1) <> 0 then RxOptions:=RxOptions or hOpt_CtlChrs;
  if pos('HIC',TmpStr1) <> 0 then RxOptions:=RxOptions or hOpt_HighCtl;
  if pos('HI8',TmpStr1) <> 0 then RxOptions:=RxOptions or hOpt_HighBit;
  {* can *}
  if pos('ASC',TmpStr)  <> 0 then RxOptions:=RxOptions or hOpt_CanAsc;
  if pos('UUE',TmpStr)  <> 0 then RxOptions:=RxOptions or hOpt_CanUUE;
  if pos('C32',TmpStr)  <> 0 then RxOptions:=RxOptions or hOpt_CRC32;
  if pos('DEV',TmpStr)  <> 0 then RxOptions:=RxOptions or hOpt_Device;
  if not SessionControl^.SecondBatch then begin
    LogWrite(imRemoteHydCan,TmpStr,ld_SessAll);
    LogWrite(imRemoteHydWant,TmpStr1,ld_SessAll);
  end;

  TxOptions:=RxOptions;

  TmpStr1:='';
  while RX.DataBuff^[i]<>0 do begin
    TmpStr1:=TmpStr1+char(RX.DataBuff^[i]);
    Inc(i);
  end;
  If Length(TmpStr1)<16 then begin
    Tx.Window:=0;
    Rx.Window:=0;
  end else CalcWindow(TmpStr1);
  if RXOptions and hOpt_CRC32 <> 0 then
    CRCType:='32' else
    CRCType:='16';
end;

procedure SayError(Error:byte; Par1 : LongInt; Par2 : String; LogWr:boolean);
Var
  MesId     : word;
  S         : string;
  Mask      : byte;
  ClearLine : boolean;
begin
  if LogWr then
    Mask:=ld_SessAll
  else
    Mask:=ld_Session;
  ClearLine:=false;
  S:='';
  Case Error of
  hErr_Carrier   : MesId:=wmCarrierLostProt;
  hErr_ManyErr   : begin
                    MesId:=wmHManyError;
                    S:=Par2;
                 end;
  hErr_TimeOut   : begin
                     ClearLine:=true;
                     MesId:=wmHTimeOut;
                     S:=Par2+#3+long2Str(Par1);
                   end;
  hErr_BrainDead : MesId:=wmHBrainDead;
  hErr_NotFound  : begin
                    MesId:=emHCantFind;
                    S:=Par2;
                   end;
  hErr_NotOpen   : begin
                    MesId:=emHCantOpen;
                    S:=Par2;
                   end;
  hErr_BadPos    : begin
                     ClearLine:=true;
                     MesId:=wmHBadPos;
                     S:=Par2+#3+long2Str(Par1);
                   end;
  hErr_FErr      : begin
                    MesId:=emHIOError;
                    S:=Par2;
                   end;
  hErr_SkipNext  : begin
                    MesId:=imHSkipNext;
                    S:=Par2;
                   end;
  hErr_Skip      : begin
                    MesId:=imHSkip;
                    S:=Par2;
                   end;
  hErr_Resend    : begin
                     ClearLine:=true;
                     MesId:=imHResending;
                     S:=long2Str(Par1);
                   end;
  hErr_Complete  : MesId:=imBatchCompl;
  hErr_FreeSp    : MesId:=wmErrFreeSpace;
  hErr_Resum     : begin
                    MesID:=imHResuming;
                    S:=Par2+#3+long2Str(Par1);
                   end;
  hErr_Replace   : begin
                    MesId:=imReplace;
                    S:=Par2;
                   end;
  hErr_NullFile  : begin
                    MesId:=wmSkippingNull;
                    S:=Par2;
                   end;
  end;
  if ClearLine then
    Mask:=Mask or ld_LastLn;
  LogWrite(MesId,S,Mask);
end;

(*************************************************************************)
(**    File Info запихивается в буффеp пакета                           **)
(*************************************************************************)

function Get_Zero(From:word):String;
Var
  s: string;
begin
  S:='';
  while (RX.DataBuff^[from])<>0 do begin
    S:=S+char(RX.DataBuff^[from]);
    Inc(From);
  end;
  Get_Zero:=S;
end;

function Get_Long(offs:word):LongInt;
Var
  C : LongInt;
begin
  if RX.PktLen-offs>3 then
    move(Rx.DataBuff^[offs],C,sizeOf(LongInt))
  else
    C:=0;
  Get_Long:=C;
end;

procedure Put_Long(C:LongInt; offs:word);
begin
  move(C,Tx.DataBuff^[offs],sizeOf(LongInt));
end;

function Get_Word(offs:word):Word;
Var
  C : Word;
begin
  move(Rx.DataBuff^[offs],C,SizeOf(Word));
  Get_Word:=C;
end;

procedure Put_Word(C:Word; offs:word);
begin
  move(C,Tx.DataBuff^[offs],sizeOf(Word));
end;

function StoreFileInfo: word;
Var
  S : string;
begin
  S:=lowHexLong(Dos2Unix(Tx.FileTime))+
     lowHexLong(Tx.FileSize)+
     CharStr('0',24)+
     StUpCase(Tx.SendName)+#0;
  Move(S[1],Tx.DataBuff^[0],length(S));
  StoreFileInfo:=Length(S);
end;

procedure GetFileInfo;
Var
  S       : string;
begin
  move(RX.DataBuff^[0],S[1],8);
  S[0]:=#8;
  RX.FileTime:=Unix2Dos(TakeFirstHex(S));
  RX.FileTime:=RX.FileTime and $FFFFFFFE;
  move(RX.DataBuff^[8],S[1],8);
  S[0]:=#8;
  Rx.FileSize:=TakeFirstHex(S);
  Rx.FileName:=CvtLongName(Get_Zero(40));
end;

(*************************************************************************)
(**    функция пpовеpки клавы, true если пpовеpка так сказать пpошла    **)
(*************************************************************************)

function CheckKeyboard:boolean;
Var
  ch   : char;
begin
  CheckKeyboard:=true;
  repeat
  if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then
    if keypressed then begin
      ch:=readkey;
      case ch of
        #9  : If Addr(TabShow)<> nil then TabShow;     {Tab}
        #19 : SkippReq:=2; {Destructive Skip}          {Ctrl-S}
        #27 : begin                                    {Esc}
               KillCD;
               CheckKeyboard:=false;
               exit;
        end;
        #0  : begin                                    {#0+}
               ch:=ReadKey;
               case ch of
                 #31 : SkippReq:=1; {Skip}             {Alt-S}
                 #35 : begin                           {Alt-H}
                        KillCD;
                        CheckKeyboard:=false;
                        exit;
                 end;
               end; {Case}
        end; {Begin --> #0}
      end; {Case}
    end else
      IfKeyPress:=0;
  until IfKeyPress=0;
end;

(*************************************************************************)
(**    функции закpытия файлов с пpовеpкой                              **)
(*************************************************************************)

procedure CloseRX;
begin
  If FileRec(RX.WorkFile).mode<>fmClosed then begin
    SetFileTime(RX.WorkFile,RX.FileTime);
    CloseFile(RX.WorkFile);
    if (RX.Pos<RX.FileSize) and (RX.Pos>=0) then begin
      LogWrite(wmRecvFailed,StUpCase(RX.FileName)+#3+long2Str(RX.Pos),ld_SessAll);
      CheckPkt(RxPath,RX.FileName);
    end;
    if (RX.Pos=RX.FileSize) and (SkippReq=0) then
      ClearFileAttr(RX.WorkFile);
  end;
end;

procedure CloseTX;
begin
  If FileRec(TX.WorkFile).mode<>fmClosed then begin
    if (TX.Pos<>TX.FileSize) and (TX.Pos>=0) then
      LogWrite(wmSendFailed,StUpCase(TX.FileName)+#3+long2Str(TX.Pos),ld_SessAll);
    CloseFile(TX.WorkFile);
  end;
end;

procedure CloseAll;
begin
  CloseRX;
  CloseTX;
end;
