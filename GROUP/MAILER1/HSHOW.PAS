{$O+,F+}
unit HShow;

interface
uses SFInclud,
     Show,
     Fos_Lib,
     Hydra,
     Dos,
     a002Xs,
     Config,
     Modem,
     EventMan,
     EmStruct,
     TString_,
     TPCRT,
     TPWindow,
     WriteLog;

procedure HydraFace;
procedure HShowFileName(Recv:boolean);
procedure HClearFileName(Recv:boolean);
procedure HShowFilePos(Recv:boolean);
procedure HComplete(Recv:boolean);
procedure ShowTransfer;

implementation

procedure HydraFace;
Var
  x   : byte;
  y   : byte;
begin

  { ... face Session Screen Hydra Mode ... }
  if ScreenHeight>25 then x:=5 else x:=4;

  MakeWindow(PWin,10,x,70,x+SessionLines+14,true,true,true,
             pCfgRec^.SFMailColors[Session_Border],
             pCfgRec^.SFMailColors[Session_Border],
             pCfgRec^.SFMailColors[Session_Header],
             '');

  DisplayWindow(Pwin);
  ClrScr;

  If SessionControl^.SessionType = Inbound then begin
    FastCenter('น '+Pad('',23)+' ฬ',0,pCfgRec^.SFMailColors[Session_Border]);
    FastCenter('Inbound Session (Hydra)',
                0,pCfgRec^.SFMailColors[Session_Header]);
  end else begin
    FastCenter('น '+Pad('',24)+' ฬ',0,pCfgRec^.SFMailColors[Session_Border]);
    FastCenter('Outbound Session (Hydra)',
                0,pCfgRec^.SFMailColors[Session_Header]);
  end;

  FastWriteWindow('ฦออ[TX:     /      ]ออ[Cur:     /     ]ออ[RX:     /      ]ออต'
            ,4,0,pCfgRec^.SFMailColors[Session_Border]);

  with SessionControl^,pCfgRec^ do begin
{    FastWriteWindow('Send',5,2,(pCfgRec^.SFMailColors[Session_File] and $F0) or $0A);
    FastWriteWindow(':         of',5,9,pCfgRec^.SFMailColors[Session_File]);
    FastWriteWindow(LeftPad(vInBestForm(Traf_Out_Cur),6),5,11,SfMailColors[Session_Param]);
    FastWriteWindow(LeftPad(vInBestForm(Traf_Out),6),5,22,SfMailColors[Session_Param]);
    FastWriteWindow('Recv',5,34,(pCfgRec^.SFMailColors[Session_File] and $F0) or $0C);
    FastWriteWindow(':         of',5,39,pCfgRec^.SFMailColors[Session_File]);
}
    FastWriteWindow('Send   :         of',5,2,(pCfgRec^.SFMailColors[Session_File] and $F0) or $0A);
    FastWriteWindow(LeftPad(vInBestForm(Traf_Out_Cur),6),5,11,SfMailColors[Session_Param]);
    FastWriteWindow(LeftPad(vInBestForm(Traf_Out),6),5,22,SfMailColors[Session_Param]);
    FastWriteWindow('Recv   :         of',5,32,(pCfgRec^.SFMailColors[Session_File] and $F0) or $0C);
    FastWriteWindow(LeftPad(vInBestForm(Traf_In_Cur),6),5,41,SfMailColors[Session_Param]);
    FastWriteWindow(LeftPad(vInBestForm(Traf_In),6),5,52,SfMailColors[Session_Param]);
  end;
  FastWriteWindow('ฦอออออออออออออออออออออออออออออัอออออออออออออออออออออออออออออต'
            ,6,0,pCfgRec^.SFMailColors[Session_Border]);
  For x:= 7 to 12 do
  FastWriteWindow('ณ                             ณ                             ณ'
            ,x,0,pCfgRec^.SFMailColors[Session_Border]);
  FastWriteWindow('ฦอออออออออออออออออออออออออออออฯอออออออออออออออออออออออออออออต'
            ,13,0,pCfgRec^.SFMailColors[Session_Border]);
  FullInfo;

  FastWriteWindow('Send   :', 7, 2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Size   :', 8, 2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Pos    :', 9, 2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Time   :',10, 2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Left   :',11, 2,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('CPS    :',12, 2,pCfgRec^.SFMailColors[Session_File]);

  FastWriteWindow('Recv   :', 7,32,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Size   :', 8,32,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Pos    :', 9,32,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Time   :',10,32,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('Left   :',11,32,pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow('CPS    :',12,32,pCfgRec^.SFMailColors[Session_File]);

  FastCenter('น '+Pad('',length(LastConnect))+' ฬ',14+SessionLines,pCfgRec^.SFMailColors[Session_Border]);
  FastCenter(LastConnect,14+SessionLines,pCfgRec^.SFMailColors[Session_Info]);

  { ... end of face Session Screen Hydra Mode ... }
  for x:=1 to SessionLines do
   SesBuffer^ [x]:='';

end;

procedure HShowGauge(Recv:boolean);
var
 totCube,
 curCube  : longint;
 TotalCol : byte;
 XX       : ^tBufferControl;
 x        : byte;
 Traf,
 TrafAll  : LongInt;
begin
  if Recv then begin
    x:=34;
    XX:=@RX;
    Traf:=SessionControl^.Traf_In_Cur;
    TrafAll:=SessionControl^.Traf_In;
  end else begin
    x:=4;
    XX:=@TX;
    Traf:=SessionControl^.Traf_Out_Cur;
    TrafAll:=SessionControl^.Traf_Out;
  end;
  if XX^.FileSize <> 0 then begin
    curCube:=(XX^.Pos*20) div XX^.FileSize;
    if curCube >20 then curCube:=20;
  end else
    curCube:=20;

  if TrafAll <> 0 then begin
    if FileRec(XX^.WorkFile).mode<>fmClosed then
      totCube:=((Traf + XX^.Pos)*20) div TrafAll
    else
      totCube:=(Traf*20) div TrafAll;
    if totCube >20 then totCube:=20;
  end else
    totCube:=20;
  with pCfgRec^ do begin
    if FileRec(XX^.WorkFile).mode<>fmClosed then
      FastWriteWindow(LeftPad(vInBestForm(Traf+XX^.Pos),6),5,x+7,SfMailColors[Session_Param])
    else
      FastWriteWindow(LeftPad(vInBestForm(Traf),6),5,x+7,SfMailColors[Session_Param]);
    FastWriteWindow(LeftPad(vInBestForm(TrafAll),6),5,x+19,SfMailColors[Session_Param]);
  end;

 if Recv then
   TotalCol:=$04 else TotalCol:=$02;
 with pCfgRec^ do begin
  FastWriteWindow('[',13,x,SFMailColors[Session_Border]);
  if totCube >curCube then begin
     FastWriteWindow(CharStr('Ü',curCube),13,x+1,(TotalCol shl 4) or (SFMailColors[Session_Border] and $0F));
     FastWriteWindow(CharStr('฿',totCube-curCube),13,x+1+curCube,TotalCol or (SFMailColors[Session_Border] and $F0));
     FastWriteWindow(CharStr('ฤ',20-totCube),13,x+1+totCube,SFMailColors[Session_Border]);
  end else begin
     FastWriteWindow(CharStr('Ü',totCube),13,x+1,(TotalCol shl 4) or (SFMailColors[Session_Border] and $0F));
     FastWriteWindow(CharStr('Ü',curCube-totCube),13,x+1+totCube,SFMailColors[Session_Border]);
     FastWriteWindow(CharStr('ฤ',20-curCube),13,x+1+curCube,SFMailColors[Session_Border]);
  end;
  FastWriteWindow(']',13,x+21,SFMailColors[Session_Border]);
 end;
end;

procedure HShowFileName(Recv:boolean);
var x : byte;
    XX : ^tBufferControl;
begin
  HClearFileName(Recv);
  if Recv then begin
    x:=41;
    XX:=@RX;
  end else begin
    x:=11;
    XX:=@TX;
  end;
  FastWriteWindow(Pad(StUpCase(JustFileName(XX^.FileName)),14)+XX^.Mode+'/'+CRCType,
                  7,x,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad(long2Str(XX^.FileSize),12),
                  8,x,pCfgRec^.SfMailColors[Session_Param]);
  with SessionControl^ do
  If Recv then begin
    if Traf_In_Cur+XX^.FileSize>Traf_In then Traf_In:=Traf_In_Cur+XX^.FileSize;
  end else begin
    if Traf_Out_Cur+XX^.FileSize>Traf_Out then Traf_Out:=Traf_Out_Cur+XX^.FileSize;
  end;
end;

procedure HClearFileName(Recv:boolean);
var x : byte;
begin
  if Recv then
    x:=41
  else
    x:=11;
  FastWriteWindow(Pad('',18), 7,x,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad('',18), 8,x,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad('',18), 9,x,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad('',18),10,x,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad('',18),11,x,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad('',18),12,x,pCfgRec^.SfMailColors[Session_Param]);
  HShowGauge(Recv);
end;

procedure HShowFileTime(Total_Time,Left_Time:LongInt;x:byte);
Var
  Time_Sh    : longInt;
begin
 { Total Time }
 Time_Sh:=Total_Time div 3600;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',10,x,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=(Total_Time div 60) mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',10,x+3,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=Total_Time mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)    ,10,x+6,pCfgRec^.SfMailColors[Session_Param]);
 { Left Time }
 Time_Sh:=Left_Time div 3600;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',11,x,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=(Left_Time div 60) mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)+':',11,x+3,pCfgRec^.SfMailColors[Session_Param]);
 Time_Sh:=Left_Time mod 60;
 FastWriteWindow(LeftPadCh(long2Str(Time_sh),'0',2)    ,11,x+6,pCfgRec^.SfMailColors[Session_Param]);
end;

procedure HShowFilePos(Recv:boolean);
var x  : byte;
    XX : ^tBufferControl;
    Percent   : word;
    SessCPS   : longInt;
    SessCPSpc : word;
    AllTime   : LongInt;
    Cur_CPS   : longInt;
    Cur_CPSpc : word;
    time      : LongInt;
    Left_Time : LongInt;
    Total_Time: LongInt;

begin
  if Recv then begin
    x:=41;
    XX:=@RX;
  end else begin
    x:=11;
    XX:=@TX;
  end;
  if XX^.FileSize<>0 then
    PerCent:=trunc((XX^.Pos/XX^.FileSize)*100)
  else
    PerCent:=0;
  FastWriteWindow(LeftPad(long2Str(XX^.BlockSize),4),
                  8,x+14,pCfgRec^.SfMailColors[Session_Param]);
  FastWriteWindow(Pad(long2Str(XX^.Pos),14)+LeftPad(long2Str(Percent)+'%',4),
                  9,x,pCfgRec^.SfMailColors[Session_Param]);
  AllTime:=TimeCounter-BeginTime;
  if AllTime>0 then begin
    SessCPS:=trunc ((SendByte+ReceiveByte) / (Alltime/18.2));
    if SessCPS>99999 then SessCPS:=99999;
    FastWriteWindow('['+LeftPad(long2Str(SessCPS),5)+']',
                    0,52,pCfgRec^.SfMailColors[Session_Header]);
  end;
  SessCPSpc:=trunc(SessCPS / (HSpeed / 1000));
  If SessCPSpc>999 then SessCPSpc:=999;

  { Check CPS TreshOld }
  if AllTime>5460 then begin
    if SessCPSpc < pcfgRec^.CPS_Threshold_5 then begin
      KillCD;
      LogWrite(wmLowCPS,long2Str(SessCPS)+#3+
               long2Str(SessCPSpc),ld_SessAll);
    end;
  end;
  if (AllTime<5460) and (AllTime>1092) then begin
    if SessCPSpc < pcfgRec^.CPS_Threshold_1 then begin
      KillCD;
      LogWrite(wmLowCPS,long2Str(SessCPS)+#3+
               long2Str(SessCPSpc),ld_SessAll);
    end;
  end;

  { Check Session Limit }
  If SessionControl^.SessionType = Inbound then begin
    if (NodeEntry.SessLimitIn<>0) and
       (AllTime>NodeEntry.SessLimitIn) then begin
      KillCD;
      LogWrite(wmLimitIn,'',ld_SessAll);
    end;
  end else begin
    if (NodeEntry.SessLimitOut<>0) and
       (AllTime>NodeEntry.SessLimitOut) then begin
      KillCD;
      LogWrite(wmLimitOut,'',ld_SessAll);
    end;
  end;

  Time:=TimeCounter - XX^.StartTime;
  if Time>0 then
    Cur_CPS:=trunc((XX^.Pos-XX^.StartSize) / (time/18.3))
  else
    Cur_CPS:=0;
  if Cur_CPS>99999 then Cur_CPS:=99999;
  Cur_CPSpc:=trunc(Cur_CPS / (HSpeed / 1000));
  If Cur_CPSpc>999 then Cur_CPSpc:=999;

  if Cur_CPS<>0 then begin
    Left_Time:=(XX^.FileSize-XX^.Pos) div Cur_CPS;
    Total_Time:=(XX^.FileSize-XX^.StartSize) div Cur_CPS;
  end else begin
    Left_Time:=((XX^.FileSize-XX^.Pos)*10) div HSpeed;
    Total_Time:=((XX^.FileSize-XX^.StartSize)*10) div HSpeed;
  end;

  HShowFileTime(Total_Time,Left_Time,x);
  FastWriteWindow(pad(long2Str(Cur_CPS),6)+' '+
                  LeftPad(Long2Str(Cur_CPSpc),3)+
                  '%  ',12,x,pCfgRec^.SfMailColors[Session_Param]);

  HShowGauge(Recv);
end;

procedure HComplete(Recv:boolean);
var x  : byte;
    XX : ^tBufferControl;
    Cur_CPS   : longInt;
    Cur_CPSpc : word;
    time      : LongInt;
begin
 if Recv then begin
   XX:=@RX;
 end else begin
   XX:=@TX;
 end;
 Time:=TimeCounter - XX^.StartTime;
 if Time>0 then
   Cur_CPS:=trunc((XX^.Pos-XX^.StartSize) / (time/18.3))
 else
   Cur_CPS:=0;
 if Cur_CPS>99999 then Cur_CPS:=99999;
 Cur_CPSpc:=trunc(Cur_CPS / (HSpeed / 1000));
 If Cur_CPSpc>999 then Cur_CPSpc:=999;

 If Recv then
   LogWrite(imHRecvComplete,stUpCase(JustFileName(XX^.FileName))+#3+
            Long2Str(XX^.FileSize)+#3+long2Str(Cur_CPS)+#3+
            long2Str(Cur_CPSpc),ld_SessAll)
 else
   LogWrite(imHSentComplete,stUpCase(JustFileName(XX^.FileName))+#3+
            Long2Str(XX^.FileSize)+#3+long2Str(Cur_CPS)+#3+
            long2Str(Cur_CPSpc),ld_SessAll);
end;

procedure ShowTransfer;
begin
  BuffInfo(RxFree, TxFree, RxTotal, TxTotal);
  FastWriteWindow(LeftPad(long2Str(TXTotal-TxFree),5),4,7,
                   pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow(Pad(long2Str(TXTotal),5),4,13,
                   pCfgRec^.SFMailColors[Session_File]);

  FastWriteWindow(LeftPad(long2Str(TXCur),5),4,27,
                   pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow(Pad(long2Str(RXTmp.TempCur),5),4,33,
                   pCfgRec^.SFMailColors[Session_File]);

  FastWriteWindow(LeftPad(long2Str(RXTotal-RxFree),5),4,45,
                   pCfgRec^.SFMailColors[Session_File]);
  FastWriteWindow(Pad(long2Str(RXTotal),5),4,51,
                   pCfgRec^.SFMailColors[Session_File]);
end;

end.