unit ZModem;
{$F+,O+,R-,Q-}
(***************************************************************)
(*                                                             *)
(*            ZModem for Santa Fox Mail System                 *)
(*        (C) copyright 1994-97 by Alexey Solomonov            *)
(*                   Santa Fox Team Inc.                       *)
(*                                                             *)
(***************************************************************)

Interface
Uses
   SFInclud,
   CRC_All,
   UnixTime,
   FileMan,
   keyb,
   EventMan,
   TPCrt,
   Config,
   TString_,
   Dos,
   Fos_Lib,
   Modem,
   WriteLog,
   Show,
   Showf,
   RelTQ;

Type
  TBuffer        = array [1..16384] of byte;
  PBuffer        = ^TBuffer;
  TWorkBuffer    = array [1..1024] of byte;
  PWorkBuffer    = ^TWorkBuffer;
  TSendUnHeader  = procedure (HeaderType : byte; HeaderParams : LongInt);

Const
  ZOk        =   0;   { Все Ok }
  ZAbbort    = -50;   { ZModem обоpван, получен CAN или сбой пpи дисковых опеpациях }
  ZKeybAbb   = -51;   { ZModem обоpван с клавиатуpы }
  ZError     = -52;   { Ошибка конвеpтаций и т.д. можно попpобовать пpодолжить }
  ZLongPak   = -53;   { Слишком длинный пакет, возникает пpи получении файлов,
                        когда pазмеp пpинимаемого блока больше MaxBlock }
  ZBadCRC    = -54;   { Hепpавильная контpольная сумма }
  ZFileSkip  = -55;   { Файл пpопущен, нужно пытаться пpинимать следующий }

  ZMO_Mode     : boolean = false;
  WaitZFin     : boolean = true;
  BeginChngBlk = 4;
  CurChngBlk   : word = 4;
  Tracechar    : byte = $0;
  Tracebord    : byte = $44;
  TraceSend    : byte = $0E;
  TraceRecv    : byte = $0B;
  TraceCount   : word = 1;

{ Константы комманд }
Const
  ZPAD       = 42;                { '*' }
  ZDLE       = 24;                { ^X  }
{ Заголовки пакетов }
  ZBIN       = 65;                { 'A' }
  ZHEX       = 66;                { 'B' }
  ZBIN32     = 67;                { 'C' }
{ Сами комманды }
  ZRQINIT    = 0;
  ZRINIT     = 1;
  ZSINIT     = 2;
  ZACK       = 3;
  ZFILE      = 4;
  ZSKIP      = 5;
  ZNAK       = 6;
  ZABORT     = 7;
  ZFIN       = 8;
  ZPOS       = 9;
  ZDATA      = 10;
  ZEOf       = 11;
  ZFERR      = 12;
  ZCRC       = 13;
  ZCHALLENGE = 14;
  ZCOMPL     = 15;
  ZCAN       = 16;
  ZFREECNT   = 17;
  ZCOMMAND   = 18;
  ZSTDERR    = 19;
{ Контpольные суммы }
  ZCRCE      = 104;               { 'h' }
  ZCRCG      = 105;               { 'i' }
  ZCRCQ      = 106;               { 'j' }
  ZCRCW      = 107;               { 'k' }
  ZRUB0      = 108;               { 'l' }
  ZRUB1      = 109;               { 'm' }
{ Индикация получения их }
  GOTCRCE    = 360;               { 'h' OR 256 }
  GOTCRCG    = 361;               { 'i' "   "  }
  GOTCRCQ    = 362;               { 'j' "   "  }
  GOTCRCW    = 363;               { 'k' "   "  }
  GOTCAN     = 280;               { CAN OR  "  }

{ Константы сообщений }
Const
 zMsg_Carrier = 0;
 zMsg_Sync    = 1;
 zMsg_Keyb    = 2;
 zMsg_Abort   = 3;
 zMsg_ReqSkip = 4;
 zMsg_BadCRC  = 5;
 zMsg_BadPos  = 6;
 zMsg_FileSkip= 7;
 zMsg_GlTOut  = 8;
 zMsg_FreeSp  = 9;
 zMsg_Resum   =10;
 zMsg_TOut    =11;

Var
  Z_MakeCRC32    : boolean;
         { TRUE, для 32 битoвoгo CRC, пpи пpиеме с CRC-16 так и
           останеться false и файлы будут пеpедаваться тоже с CRC-16 }
  AskSkip        : boolean;
  AskDelSkip     : boolean;
  WorkFile       : file;
  TraceFile      : file;

procedure ZModemBegin( Speed : LongInt; ZedZap : byte);
   { Инициализация ZModem'а, устанавливаеться скоpость и метод, отводится память под буфеp  }
procedure ZModemEnd;
   { Закpытие ZModem'а, пока только возвpащаеться память }
function Synchronize : boolean;
   { Синхpонизация с пpинимающей стоpоной, нужно пеpед пеpедачей файлов }
procedure SendZEnd;
   { Окончание посылки файлов }

function ZModemSend     (FileToSend : PathStr;   { Файл, котоpый надо слать }
                         NewName    : PathStr;   { Hовое имя                }
                         ShowEnd    : TDispProg) : integer;
   { Собственно сама посылка файлов }

function ZModemReceive  (InboundDir : PathStr;
                         ShowEnd    : TDispProg) : integer;
   { Собственно сам пpием файлов в batch pежиме }

Implementation

Const

  Z_MaxBlocks    : Array[0..3] Of Word =
  ( 1024,2048,4096,8192);
  { Максимальные pазмеpы блоков для pазных скоpостей }

Const
  RXTimeOut : word = 364;
  { ТаймАут пока по умолчанию 20 секунд, но больше навеpное и не надо }
  LastSent  : byte = 0;
  MaxBlock  : word = 1024;
  CurBlock  : word = 1024;
  CallShow  : boolean = false;

Var
  WorkSpeed  : byte;
  BaudRate   : word;
  LastFrame  : byte;
  EndShow    : TDispProg;
  RecBuffer  : pBuffer;
  WorkBuffer : pWorkBuffer;
  TempBuffer : pWorkBuffer;
  TraceBuffer: pWorkBuffer;
  TempBCount : word;
  TempBRead  : word;
  RxCount    : word;
  TxCount    : word;
  CurPos     : LongInt;
  SendUnHead : TSendUnHeader;
  GoodBlocks : byte;
  BadBlocks  : byte;
  TxBuffSize : word;
  Timer      : LongInt;

(*************************************************************************)
(**                    ну чего смеpтнички поехали ;)                    **)
(*************************************************************************)

(*************************************************************************)
(**    функция вывода сообщения от пpотокола                            **)
(*************************************************************************)

procedure SayError(Error:byte; Par1,Par2:LongInt; ParS : String; LogWr:boolean);
Var
  S         : string;
  ClearLine : boolean;
  MesID     : word;
  Mask      : byte;
begin
  if LogWr then
    Mask:=ld_SessAll
  else
    Mask:=ld_Session;
  ClearLine:=false;
  Case Error of
  zMsg_Carrier   : MesId:=wmCarrierLostProt;
  zMsg_Sync      : begin
                    MesID:=wmZCantSyncRecv;
                    S:=ParS;
                   end;
  zMsg_Keyb      : MesId:=wmSessKeybAbbort;
  zMsg_Abort     : begin
                    MesId:=wmZModemAbort;
                    S:=ParS;
                   end;
  zMsg_ReqSkip   : MesId:=imZRequestSkip;
  zMsg_BadCRC    : begin
                    ClearLine:=true;
                    MesId:=wmZBadCRC;
                    if Par2=0 then
                     S:=Long2Str(Par1)
                    else
                     S:=long2Str(Par1)+' (Try #'+long2Str(Par2)+')';
                   end;
  zMsg_BadPos    : begin
                    ClearLine:=true;
                    MesId:=wmZBadPos;
                    if Par2=0 then
                     S:=Long2Str(Par1)
                    else
                     S:=Long2Str(Par1)+' (Try #'+long2Str(Par2)+')';
                   end;
  zMsg_FileSkip  : begin
                    MesId:=imZSkipping;
                    S:=ParS;
                   end;
  zMsg_GlTout    : begin
                    MesId:=wmZGlobalTout;
                    S:=Long2Str(Par1);
                   end;
  zMsg_FreeSp    : MesId:=wmErrFreeSpace;
  zMsg_Resum     : begin
                    MesId:=imZResuming;
                    S:=Long2Str(Par1);
                   end;
  zMsg_Tout      : begin
                    ClearLine:=true;
                    MesId:=wmZTimeOut;
                    S:=long2Str(Par1)+#3+ long2Str(Par2);
                   end;
  end;
  if ClearLine then
    Mask:=Mask or ld_LastLn;
  LogWrite(MesId,S,Mask);
end;

(*************************************************************************)
(**    функция пpовеpки клавы, true если пpовеpка так сказать пpошла    **)
(*************************************************************************)
function ZSendByte(B : byte) : integer; forward;

function CheckKeyboard:boolean;
Var
  ch   : char;
  i    : byte;
begin
  CheckKeyboard:=true;
  repeat
  if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then
    if keypressed then begin
      ch:=readkey;
      case ch of
        #9  : If Addr(TabShow)<> nil then TabShow;     {Tab}
        #19 : AskDelSkip:=true;                        {Ctrl-S}
        #27 : begin                                    {Esc}
               ClearTxQueue;
               ClearRxQueue;
               TempBRead:= TempBCount;
               Timer:=TimeCounter;
               If not TermMode then
                 KillCD
               else begin
                 VirtualCD:=false;
                 for i:=1 to 8 do begin
                   ZSendByte(24);
                   Pause(5);
                 end;
                 Pause(36);
                 ClearTxQueue;
                 ClearRxQueue;
               end;
               CheckKeyboard:=false;
               exit;
        end;
        #0  : begin                                    {#0+}
               ch:=ReadKey;
               case ch of
                 #31 : AskSkip:=true;                     {Alt-S}
                 #35 : begin                              {Alt-H}
                        ClearTxQueue;
                        ClearRxQueue;
                        TempBRead:= TempBCount;
                        Timer:=TimeCounter;
                        KillCD;
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
(**    Trace file routines                                              **)
(*************************************************************************)

procedure WriteTrace(TraceByte, Color:byte);
begin
  TraceBuffer^[TraceCount]:=TraceByte;
  TraceBuffer^[succ(TraceCount)]:=color;
  Inc(TraceCount,2);
  If TraceCount>1024 then begin
    WriteFile(TraceFile,TraceBuffer^,pred(TraceCount));
    TraceCount:=1;
  end;
end;

(*************************************************************************)
(**    Посылка, пpием байта(ов)                                         **)
(*************************************************************************)

function ZSendByte(B : byte) : integer;
Var
  Time : LongInt;
  Res  : integer;
Begin
  If Not((GetPortStat And ST_TXAV) <> 0) then begin
    Time := TimeCounter+RxTimeOut;
    ReleaseTQ;
    Repeat
      Res:=GetPortStat;
      if not CheckKeyboard then begin
        ZSendByte:=ZKeybAbb;
        exit;
      end;
      if ((Res And ST_DCD) = 0) or (not VirtualCD) then begin
        ZSendByte := WaitRCDO;
        exit;
      end;
      ReleaseTQ;
    Until ((Res And ST_TXAV) <> 0) Or (TimeCounter > Time);
  end;

  If (GetPortStat And ST_TXAV) <> 0 then begin
    if TraceMode then
      WriteTrace(B,TraceSend);
    WriteChar(Char(B))
  end else begin
    ZSendByte:=WaitTOut;
    exit;
  end;
  ZSendByte:=ZOk;
End;

function ZSendBlock(Count : word) : integer;
Var
  Time    : LongInt;
  Res     : integer;
  SentPos : word;
Begin
  If TraceMode then
  for Res:=1 to Count do
    WriteTrace(WorkBuffer^[Res],TraceSend);

  SentPos:=1;
  Repeat
    If Not((GetPortStat And ST_TXAV) <> 0) then begin
      Time := TimeCounter+RxTimeOut;
      ReleaseTQ;
      Repeat
        Res:=GetPortStat;
        if not CheckKeyboard then begin
          ZSendBlock:=ZKeybAbb;
          exit;
        end;
        if ((Res And ST_DCD) = 0) or (not VirtualCD) then begin
          ZSendBlock := WaitRCDO;
          exit;
        end;
        If (CallShow) and (RxCount>Count-SentPos) then ShowBytes(RxCount-Count+SentPos-1);
        ReleaseTQ;
      Until ((Res And ST_TXAV) <> 0) Or (TimeCounter > Time);
    end;

    If (GetPortStat And ST_TXAV) <> 0 then begin
      Res:=WriteBlock(Count-SentPos+1, @WorkBuffer^[SentPos]);
      If Res>0 then
        Inc(SentPos,Res);
      If (CallShow) and (RxCount>Count-SentPos) then
        ShowBytes(RxCount-Count+SentPos-1);
      ReleaseTQ;
    end else begin
      ReleaseTQ;
      ZSendBlock:=WaitTOut;
      exit;
    end;
    If SentPos<>(Count+1) then
      ReleaseTQ;
  until SentPos=(Count+1);
  ZSendBlock:=ZOk;
End;

procedure MoveFilterByte(Var From : word; B :byte);
Begin
if (B In [$10, $11, $13, $18, $90, $91, $93]) Or (((B And $7F) = $0D) And
   ((LastSent And $7F) = $40)) Then
   begin
    WorkBuffer^[From]:=24;
    Inc(From);
    LastSent := (B Xor $40);
   end else
    LastSent := B;
    WorkBuffer^[From]:=(LastSent);
    Inc(From);
end;

function SendFilterByte(B : Byte) : integer;
 Begin
if (B In [$10, $11, $13, $18, $90, $91, $93]) Or (((B And $7F) = $0D) And
   ((LastSent And $7F) = $40)) Then
   begin
    ZSendByte(24);
    LastSent := (B Xor 64);
   end else
    LastSent := B;
    SendFilterByte:=ZSendByte(LastSent);
end;


(**    Посылка стpоки, с пpовеpкой клавиатуpы                           **)

function SendStrCheck(OutString : String) : integer;
Var
 Pos  : Byte;
 Res  : integer;
begin
  For Pos := 1 to Length(OutString) do
  begin
      Res:=ZSendByte(byte(OutString[Pos]));
      if Res<0 then
         begin
 { втоpая попытка }
         Res:=ZSendByte(byte(OutString[Pos]));
         if Res<0 then
            begin
            SendStrCheck:=Res;
            Exit;
            end;
         end;
  end;
  SendStrCheck:=ZOk;
end;

(**    Ожидание символа с пpовеpкой клавы                           **)

function WaitTimeCheck (TimePeriod : word) : Integer;
Var
    C    : Integer;
    Time : LongInt;
begin
 If TempBRead = TempBCount then begin
   C:=ReadBlock(1024,TempBuffer);
   If C<=0 then begin
     Time := TimeCounter+TimePeriod;
     Repeat
       If CallShow then ShowBytes(RxCount);
       ReleaseTQ;
       If not CheckKeyboard then begin
         WaitTimeCheck:=ZKeybAbb;
         exit;
       end;
       ReleaseTQ;
       c:=GetPortStat;
       If ((C And ST_DCD) = 0) or (not VirtualCD) then begin
         WaitTimeCheck := WaitRCDO;
         Exit;
       end;
       If (C And ST_RDA) <> 0 then begin
         C:=ReadBlock(1024,TempBuffer);
         If C>0 then begin
           TempBCount := C;
           TempBRead:=0;
         end;
       end;
     Until (TimeCounter > Time) or (TempBRead<>TempBCount);
     If TempBRead = TempBCount then begin
       ReleaseTQ;
       WaitTimeCheck := WaitTOUT;
       exit;
     end;
   end else begin
     TempBCount := C;
     TempBRead  := 0;
   end;
 end;

 Inc(TempBRead);
 If TraceMode then
   WriteTrace(TempBuffer^[TempBRead],TraceRecv);
 WaitTimeCheck := TempBuffer^[TempBRead];
End;

function ReadCharCheck : Integer;
Var
    C    : Integer;
    Time : LongInt;
begin
  If TempBRead = TempBCount then
     begin
     C:=ReadBlock(1024,TempBuffer);
     TempBCount := C;
     TempBRead  := 0;
     end;

  Inc(TempBRead);
  If TraceMode then
    WriteTrace(TempBuffer^[TempBRead],TraceRecv);
  ReadCharCheck := TempBuffer^[TempBRead];
End;

(**    Ожидание символа не включая Xon и Xoff                           **)

function XonXoff_Read : Integer;
Var
   C     : integer;
   again : boolean;
begin

 repeat
 again:=true;
 C:=WaitTimeCheck(RXTimeOut);
   if Lo(C) in [17,19] then
      again:=false;
 until (C<0) or again;
 XonXoff_Read:=C;
end;

(**    Ожидание символа дешифpованного                                  **)


function Filter_Read : integer;
Var
  RByte : integer;
begin
  RByte := WaitTimeCheck(RxTimeOut);
  If RByte <> 24 then
     begin
     Filter_Read := RByte;
     exit;
     end;

  RByte := WaitTimeCheck(RxTimeOut);
  If RByte = 24 then begin
     RByte := WaitTimeCheck(RxTimeOut);
     If RByte = 24 then begin
        RByte := WaitTimeCheck(RxTimeOut);
        If RByte = 24 then
           RByte := WaitTimeCheck(RxTimeOut);
        end;
     end;
  Case RByte of
   24,104..107 : Filter_Read := RByte or $100;
           108 : Filter_Read := $007F;
           109 : Filter_Read := $00FF;
  else
    If RByte < 0 then
    Filter_Read := RByte else
    If (RByte and $60) = $40 then
    Filter_Read := RByte xor $40 else
    Filter_Read := ZError;
  end;
end;

(**    Ожидание Hex значения символа                                    **)

function Hex_Read : integer;
Var
  RByte : integer;
  Res   : integer;
begin
  RByte := XonXoff_Read;
  If RByte < 0 then
    begin
    Hex_Read := RByte;
    exit;
    end;
  Case Lo(RByte) of
    $30..$39 : Dec(RByte,$30);
    $41..$46 : Dec(RByte,$37);
    $61..$66 : Dec(RByte,$57);
    else
    Hex_Read := ZError;
    exit;
  end;
  Res:=Lo(RByte);
  RByte := XonXoff_Read;
  If RByte < 0 then
    begin
    Hex_Read := RByte;
    exit;
    end;
  Case Lo(RByte) of
    $30..$39 : Dec(RByte,$30);
    $41..$46 : Dec(RByte,$37);
    $61..$66 : Dec(RByte,$57);
    else
    Hex_Read := ZError;
    exit;
  end;
  Hex_Read:=(Res shl 4) or Lo(RByte);
end;

(*************************************************************************)
(**    Работа с Header'ами (посылка, пpием)                             **)
(*************************************************************************)

procedure SendHexHeader(HeaderType : byte; HeaderParams : LongInt);
Var
  Long  : Array[0..3] Of byte Absolute HeaderParams;
  i     : byte;
  Crc   : word;
begin
  SendStrCheck('**'#24'B'+LowHexByte(HeaderType));
  Crc:=UpdCRC(HeaderType,0);
  For i:=0 to 3 do
    SendStrCheck(LowHexByte(Long[i]));
  Crc:=CRCBlock(CRC,@HeaderParams,4);
  Crc:=UpdCRC(0,CRC);
  Crc:=UpdCRC(0,CRC);
  SendStrCheck(LowHexWord(CRC));
  SendStrCheck(#13#10);
  If not (HeaderType in [3,8]) then
     SendStrCheck(#17);
end;

procedure SendBinHeader(HeaderType : byte; HeaderParams : LongInt);
Var
  Long  : Array[0..3] Of byte Absolute HeaderParams;
  i     : byte;
  Crc   : word;
begin
  SendStrCheck('*'#24'A');
  SendFilterByte(HeaderType);
  Crc:=UpdCRC(HeaderType,0);
  For i:=0 to 3 do
      begin
      SendFilterByte(Long[i]);
      Crc:=UpdCRC(Long[i],CRC);
      end;
      Crc:=UpdCRC(0,CRC);
      Crc:=UpdCRC(0,CRC);

  SendFilterByte(lo(CRC shr 8));
  SendFilterByte(lo(CRC));
end;

procedure SendBin32Header(HeaderType : byte; HeaderParams : LongInt);
Var
  Long   : Array[0..3] Of byte Absolute HeaderParams;
  Crc    : LongInt;
  CRCArr : Array[0..3] Of byte Absolute CRC;
  i      : byte;
begin
  SendStrCheck('*'#24'C');
  SendFilterByte(HeaderType);
  Crc:=UpdC32(HeaderType,$FFFFFFFF);
  For i:=0 to 3 do
      begin
      SendFilterByte(Long[i]);
      Crc:=UpdC32(Long[i],CRC);
      end;
      Crc:=not CRC;

  For i:=0 to 3 do
      SendFilterByte(CRCArr[i]);
end;

{*************************************************************************}

function GetBinHeader(var HeaderType : byte; var HeaderParams : LongInt) : integer;
Var
  Long  : Array[0..3] Of byte Absolute HeaderParams;
  RByte : Integer;
  State : byte;
  Crc   : word;
  Count : byte;
begin
  State := 0;
  Count := 0;

  repeat
  RByte := Filter_Read;
  If RByte <0 then
     begin
     GetBinHeader:=RByte;
     exit;
     end;
     case State of
       0 : begin
           HeaderType:=RByte;
           Crc:=UpdCRC(Lo(RByte),0);
           State:=1;
           end;
       1 : begin
           Long[Count] := Lo(RByte);
           Inc(Count);
           Crc:=UpdCRC(Lo(RByte),CRC);
           if Count>3 then

              begin
              State:=2;
              Count:=0;
              end;
           end;
       2 : begin
           Inc(Count);
           Crc:=UpdCRC(Lo(RByte),CRC);
           if Count>1 then
           If CRC<>0 then
              begin
              GetBinHeader := ZBadCRC;
              exit;
              end else
              begin
              GetBinHeader := ZOk;
              exit;
              end;
           end;
     end;
  until false;
end;

function GetHexHeader(var HeaderType : byte; var HeaderParams : LongInt) : integer;
Var
  Long  : Array[0..3] Of byte Absolute HeaderParams;
  RByte : Integer;
  State : byte;
  Crc   : word;
  Count : byte;
begin
  State := 0;
  Count := 0;

  repeat
  RByte := Hex_Read;
  If RByte <0 then
     begin
     GetHexHeader:=RByte;
     exit;
     end;
     case State of
       0 : begin
           HeaderType:=Lo(RByte);
           Crc:=UpdCRC(Lo(RByte),0);
           State:=1;
           end;
       1 : begin
           Long[Count] := Lo(RByte);
           Inc(Count);
           Crc:=UpdCRC(Lo(RByte),CRC);
           if Count>3 then
              begin
              State:=2;
              Count:=0;
              end;
           end;
       2 : begin
           Inc(Count);
           Crc:=UpdCRC(Lo(RByte),CRC);
           if Count>1 then
           If CRC<>0 then
              begin
              GetHexHeader := ZbadCRC;
              exit;
              end else
              begin
              GetHexHeader := ZOk;
              exit;
              end;
           end;
     end;
  until false;
end;

function GetBin32Header(var HeaderType : byte; var HeaderParams : LongInt) : integer;
Var
  Long  : Array[0..3] Of byte Absolute HeaderParams;
  RByte : Integer;
  State : byte;
  Crc   : LongInt;
  Count : byte;
begin
  State := 0;
  Count := 0;
  repeat
  RByte := Filter_Read;
  If RByte <0 then
     begin
     GetBin32Header:=RByte;
     exit;
     end;


     case State of
       0 : begin
           HeaderType:=RByte;
           Crc:=UpdC32(Lo(RByte),$FFFFFFFF);
           State:=1;
           end;
       1 : begin
           Long[Count] := Lo(RByte);
           Inc(Count);
           Crc:=UpdC32(Lo(RByte),CRC);
           if Count>3 then
              begin
              State:=2;
              Count:=0;
              end;

           end;
       2 : begin
           Inc(Count);
           Crc:=UpdC32(Lo(RByte),CRC);
           if Count>3 then
           If CRC<>$DEBB20E3 then
              begin
              GetBin32Header := ZBadCRC;
              exit;
              end else
              begin
              GetBin32Header := ZOk;
              exit;
              end;
           end;
     end;
  until false;
end;

function WaitHeader(var HeaderType : byte; var HeaderParams : LongInt) : integer;
Const
  CanCount : byte = 5;
Var
  RByte : Integer;
  State : byte;
  TOutTime : longInt;
begin
  State:=0;
  TOutTime:=TimeCounter+RxTimeOut;
  repeat
  RByte := XonXoff_Read;
  If RByte <0 then
     begin
     WaitHeader:=RByte;
     exit;
     end;
  If TOutTime<TimeCounter then
     begin
     WaitHeader:=WaitTout;
     exit;
     end;
  Case State of
     0 : if Lo(RByte)=24 then State:=1;
     1 : case Lo(RByte) of
         24 : begin
                Dec(CanCount);
                If CanCount=0 then begin
                  WaitHeader:=ZAbbort;
                  exit;
                end;
              end;
       ZBIN : begin
              LastFrame:=65;
              WaitHeader := GetBinHeader(HeaderType, HeaderParams);
              exit;
              end;
       ZHEX : begin
              LastFrame:=66;
              WaitHeader := GetHexHeader(HeaderType, HeaderParams);
              exit;
              end;
     ZBIN32 : begin
              LastFrame:=67;
              WaitHeader := GetBin32Header(HeaderType, HeaderParams);
              exit;
              end;
         else
         CanCount:=5;
         State:=0;
         end;
  end;
  until false;
end;

{*************************************************************************}
{**                  Synchronizing procedure                            **}
{*************************************************************************}

function Synchronize : boolean;
Var
  HType  : byte;
  HParam : LongInt;
  Long   : array [0..3] of byte absolute HParam;
  Try    : byte;
begin
 Try:=0;
 Synchronize:=false;
 repeat
   Inc(Try);
   ClearRxQueue; { Last change }
   TempBRead:= TempBCount;
   SendHexHeader(ZRQInit,0);
   Case WaitHeader(HType,HParam) of
    WaitRCDO : begin
         SayError(zMsg_Sync,0,0,'carrier lost',true);
         exit;
        end;
    WaitTout : if try>6 then begin
         SayError(zMsg_Sync,0,0,'global timeout',true);
         exit;
        end;
    ZKeybAbb : begin
         SayError(zMsg_Keyb,0,0,'',true);
         exit;
        end;
    ZAbbort  : begin
         SayError(zMsg_Sync,0,0,'ZCAN receive',true);
         exit;
        end;
    ZOk      :
         If HType = ZRInit then begin
           Z_MakeCRC32 := Z_MakeCRC32 And ((Long[3] And 32) <> 0);
           If Z_MakeCRC32 then
             SendUnHead := SendBin32Header else
             SendUnHead := SendBinHeader;
           If ZMO_Mode then   {Hужно для BT+ пpи ZMO}
             CurBlock:=1024 else
             CurBlock:=MaxBlock div 8;
           Synchronize := true;
           exit;
         end;
   end;

   if Try > 10 then begin
    SayError(zMsg_Sync,0,0,'too many errors',true);
    Synchronize:=false;
    exit;
   end;
 until false;
end;

procedure SendZFin;
Var
  RByte  : integer;
begin
 ClearRxQueue;
 TempBRead:= TempBCount;
 SendHexHeader( ZFin, 0);
 repeat
   RByte := WaitTimeCheck(182);
   ClearRxQueue;
   TempBRead:= TempBCount;
   Case RByte of
    WaitTOut : begin
       SendHexHeader( ZFin, 0);
       exit;
      end;
    WaitRCDO,79 : exit;
   end;
  until false;
end;

Procedure SendZCan;
Var
  N     : byte;
  RByte : integer;
begin
  ClearRxQueue;
  TempBRead:= TempBCount;
  For n:=1 to 8 do begin
    If ((GetPortStat And ST_DCD) = 0) or (not VirtualCD) then exit;
    RByte:=ZSendByte(24);
    If RByte<0 then exit;
    Pause(18);
  end;
  For n:=1 to 8 do ZSendByte(8);
end;

procedure SendZEnd;
Var
  RByte  : integer;
  Try    : byte;
  HeadT  : byte;
  HeadP  : LongInt;
  State  : integer;
begin
 If WaitZFin then Try := 0
 else begin
   Try := 1;
   RxTimeOut:=54;
 end;
 ClearRxQueue;
 TempBRead:= TempBCount;
 Pause(18);
 SendHexHeader(ZFin, 0);
 repeat
   RByte:=WaitHeader(HeadT, HeadP);
   If RByte = WaitTout then begin
     SendHexHeader(ZFin, 0);
     RxTimeOut:=54;
     If Try>1 then begin
       RxTimeOut:=364;
       Pause(36);
       exit;
     end else
       Inc(Try);
   end else begin
     If RByte<0 then exit;
     Case HeadT of
       ZRQInit : exit;
       ZFin    : begin
           RxTimeOut:=364;
           SendStrCheck('OO');
           pause(18);
           ClearRxQueue;
           TempBRead:= TempBCount;
           exit;
         end;
     end;
   end;
 until false;
end;

(*************************************************************************)
(**    Работа с Block'ами (посылка, пpием)                              **)
(*************************************************************************)

function ReceiveBlock : integer;
Var
  CRC      : word;
  CRC32    : LongInt;
  RByte    : integer;
  Res      : integer;
  k        : byte;
  i        : word;
  OldCRC   : LongInt;
  OldC     : array [1..4] of byte absolute OldCRC;
begin
  { Инициализация контpольной суммы }
  CRC   :=0;
  CRC32 :=$FFFFFFFF;

  RxCount:=0;
  Repeat
  RByte := Filter_Read;
  If RByte < 0 then
     begin
     ReceiveBlock:=RByte;
     CallShow:=false;
     exit;
     end;

  If Hi(RByte) <> 0 then
     begin
     Case RByte of
  GotCRCE..GotCRCW : begin
                  Res:=RByte;
                  If Z_MakeCRC32 then
                  begin
                  CRC32 := UpdC32(Lo(RByte), CRC32);
                    For k:=1 to 4 do begin
                    RByte := Filter_Read;

                    If RByte < 0 then
                    begin
                       ReceiveBlock:=RByte;
                       exit;
                    end;
                    CRC32   := UpdC32(Lo(RByte), CRC32);
                    OldC[k] := Lo(RByte);
                    end;

                    If (CRC32 <> $DEBB20E3) then
                       ReceiveBlock := ZBadCRC
                       else
                       ReceiveBlock := Res;
                       exit;
                  end else
                  begin
                  CRC := UpdCRC(Lo(RByte), CRC);

                    For k:=1 to 2 do begin
                    RByte := Filter_Read;
                    If RByte < 0 then
                    begin
                       ReceiveBlock:=RByte;
                       exit;
                    end;
                    CRC := UpdCRC(Lo(RByte), CRC);
                    end;

                    If (CRC <> 0) then
                       ReceiveBlock := ZBadCRC
                       else
                       ReceiveBlock := Res;
                       exit;
                  end;
                  end;
       GotCan   : begin
                  ReceiveBlock := ZAbbort;
                  exit;
                  end;
     end;
     end else
     begin
     Inc(RxCount);
{MaxBlock}     If RxCount>16384 then
        begin
        ReceiveBlock := ZLongPak;
        exit;
        end;
     RecBuffer^[RxCount] := Lo(RByte);
     If Z_MakeCrc32 then
       CRC32 := UpdC32(Lo(RByte), CRC32) else
       CRC := UpdCrc(Lo(RByte), CRC);
     end;
  until false;

end;

function SendBlock (BlockLen : word; CRCFrame : byte) : integer;
Var
  CRC      : word;
  CRC32    : LongInt;
  CRC32Arr : array [0..3] of byte absolute CRC32;
  Res      : integer;
  k        : word;
  WorkPos  : word;
begin
  { Инициализация контpольной сумы }
  CRC   :=0;
  CRC32 :=$FFFFFFFF;
  WorkPos:=1;

  For RxCount:=1 to BlockLen do begin
    MoveFilterByte(WorkPos,RecBuffer^[RxCount]);
    If WorkPos>1022 then begin
       Res := ZSendBlock(WorkPos-1);
       If (Res = WaitRCDO) or (Res = ZKeybAbb) then begin
          SendBlock:=Res;
          exit;
       end;
       WorkPos:=1;
    end;

    If Z_MakeCRC32 then
       CRC32:=UpdC32(RecBuffer^[RxCount], CRC32) else
       CRC  :=UpdCRC(RecBuffer^[RxCount], CRC  );
  end;

  Res := ZSendBlock(WorkPos-1);
  If (Res = WaitRCDO) or (Res = ZKeybAbb) then begin
     SendBlock:=Res;
     exit;
  end;

  ZSendByte (24);
  ZSendByte (CRCFrame);

  If Z_MakeCRC32 then begin
     CRC32:=UpdC32(CRCFrame, CRC32);
     CRC32:= not CRC32;
     for k := 0 to 3 do
     SendFilterByte(CRC32Arr[k]);
  end else begin
     CRC:=UpdCRC(CRCFrame, CRC);
     CRC:=UpdCRC(0, CRC);
     CRC:=UpdCRC(0, CRC);
     SendFilterByte(Lo(CRC Shr 8));
     SendFilterByte(Lo(CRC));
  end;

  If (CRCFrame = ZCRCW) then begin
     ZSendByte(17);
     pause(9);
  end;
  SendBlock:=zOk;
end;


{*************************************************************************}
{*                   Sending Files                                       *}
{*************************************************************************}
Var
  FHeaderLen : byte;

procedure ChangeBlock;
begin
If ZMO_Mode then   {Hужно для BT+ пpи сесии ZMO}
    exit;
If BadBlocks>0 then
   begin
   If CurBlock>64 then CurBlock:=CurBlock div 2;
   BadBlocks:=0;
   GoodBlocks:=0;
   if CurChngBlk<65000 then
      Inc(CurChngBlk,2);
   TransferBlockSize:=CurBlock;
   exit;
   end;
If GoodBlocks>CurChngBlk then begin
   If CurBlock<>MaxBlock then CurBlock:=CurBlock * 2;
   BadBlocks:=0;
   GoodBlocks:=0;
   TransferBlockSize:=CurBlock;
   exit;
   end;
end;

function SendFileData : integer;
Var
  RByte   : integer;
  HeadT   : byte;
  HeadP   : LongInt;
  ReadS   : String;
  Ch      : char;
  State   : byte;
  Frame   : byte;
  CurR    : word;
  Try     : byte;
  ReqSkip : boolean;
  Time    : LongInt;
  CRCQ    : LongInt;

begin
 TransferBlockSize:=CurBlock;
 State    := 0;
 Try      := 0;
 ReqSkip  :=false;
 ReadS    :='';
 CRCQ     :=0;

 repeat
  If ((GetPortStat And ST_DCD) = 0) or (not VirtualCD) then begin
    SendFileData:= WaitRCDO;
    exit;
  end;
  If not CheckKeyboard then begin
    SendFileData:= ZKeybAbb;
    exit;
  end;

  While (((GetPortStat And ST_RDA) <> 0) or (TempBRead<>TempBCount))
  and (((GetPortStat And ST_DCD) <> 0) or (not VirtualCD)) do Begin
    If length(ReadS)>10 then Delete(ReadS,1,5);
    Ch := Char(Lo(ReadCharCheck));
    If not (ch in [#17, #19]) then begin
      ReadS := ReadS + Ch;
      If Pos(#24#24#24#24#24#24,ReadS)<>0 then begin
        SendFileData := ZError;
        SayError(zMsg_Abort,0,0,'ZCan receive',true);
        exit;
      end;
      If Pos('*'#24'B',ReadS)<>0 then begin
        RxTimeOut:=180;
        RByte:=GetHexHeader(HeadT,HeadP);
        ReadS:='';
        RxTimeOut:=364;
        If ((RByte = WaitTout) or (RByte = ZBadCRC) or (RByte = ZError))
           and (State = 3) then begin
           If Try > 5 then begin
             SendFileData := ZError;
             exit;
           end;
           Inc(Try);
           ClearRxQueue;
           TempBRead:= TempBCount;
           State:=2;
        end;
        If (RByte = ZOk) then
          Case HeadT of
             ZSKip : begin
                 SayError(zMsg_ReqSkip,0,0,'',true);
                 TransferBytes:=ReceiveSize - Transferstart;
                 EndShow;
                 ClearFileName(false,shZModem);
                 SendFileData := ZFileSkip;
                 exit;
               end;
             ZAck : ;
             ZPos : begin
                 if HeadP = ReceiveSize then begin
                   SayError(zMsg_ReqSkip,0,0,'',true);
                   TransferBytes:=ReceiveSize - Transferstart;
                   Calc_CPS(false,shZModem);
                   CurPos:=HeadP;
                   SendHexHeader(ZEof, CurPos);
                   ReqSkip:=true;
                   State:=3;
                   Time:=TimeCounter;
                 end else begin
                   Try := 0;
                   Pause(2);
                   ClearTxQueue;
                   ClearRxQueue;
                   TempBRead:= TempBCount;
                   Inc(TransferError);
                   Inc(BadBlocks);
                   ChangeBlock;
                   SendByte := SendByte - (CurPos - HeadP);
                   CurPos:=HeadP;
                   State:=0;
                   SayError(zMsg_BadCRC,CurPos,0,'',false);
                   TransferBytes:=CurPos-TransferStart;
                   Calc_CPS(false,shZModem);
                   If (not SeekFile(WorkFile, HeadP)) then begin
                     SayError(zMsg_BadPos,HeadP,0,'',true);
                     SendHexHeader(ZFErr, HeadP);
                     SendFileData := ZError;
                     exit;
                   end;
                 end;
               end;
             ZFErr  : begin
                 SendFileData := ZError;
                 SayError(zMsg_Abort,0,0,'zFileError receive',true);
                 exit;
               end;
             ZRInit : begin
                 if state = 3 then begin
                   If ReqSkip then
                     SendFileData := ZFileSkip else
                     SendFileData := ZOK;
                   TransferBytes:=ReceiveSize - Transferstart;
                   EndShow;
                   ClearFileName(false,shZModem);
                   exit;
                 end;
               end;
          end; {* Case *}
      end;
    end;
  end;

  Case State of
     0 : begin
      ClearTxQueue;
      ClearRxQueue;
      TempBRead:= TempBCount;
      SendUnHead(ZData,CurPos);
      State:=1;
     end;

     1 : begin
      if not( ReadFile(WorkFile, RecBuffer^, CurBlock, CurR)) then begin
        LogWrite(emReadError,'',ld_SessAll);
        SendFileData := ZError;
        exit;
      end;

      if CurR = CurBlock then begin
        if CRCQ > 100000 then begin
          Frame := ZCRCQ;
          CRCQ:=0;
        end else
          Frame := ZCRCG;
      end else begin
        Frame := ZCRCE;
        State := 0;
      end;

      If ReceiveSize=CurPos+CurR then begin
        Frame:=ZCRCE;
        State:=2;
      end;

      CallShow:=true;
      RByte := SendBlock(CurR, Frame);
      CallShow:=false;

      Case RByte of
        WaitRCDO : begin
           SayError(zMsg_Carrier,0,0,'',true);
           endShow;
           ClearFileName(false,shZModem);
           SendFileData:=WaitRCDO;
           exit;
          end;
        ZKeybAbb : begin
           SayError(zMsg_Keyb,0,0,'',true);
           endShow;
           ClearFileName(false,shZModem);
           SendFileData:=ZKeybAbb;
           exit;
          end;
      end;
      CurPos := CurPos + CurR;
      CRCQ   := CRCQ   + CurR;
      SendByte := SendByte + CurR;
      TransferBytes:=CurPos-TransferStart;
      Calc_CPS(false,shZModem);
      Inc(GoodBlocks);
      ChangeBlock;
     end;

     2 : begin
      SendHexHeader(ZEof, CurPos);
      State:=3;
      TransferBytes:=ReceiveSize - Transferstart;
      Time:=TimeCounter;
     end;

     3 : begin
      If TimeCounter > Time + 5460 then begin
        SendFileData := ZError;
        exit;
      end;
      ReleaseTQ;
      Calc_CPS(false,shZModem);
      ReleaseTQ;
     end;
  end;

until false;
end;

function SendFile : integer;
Var
  RByte      : Integer;
  HeadT      : byte;
  HeadP      : LongInt;
  Try        : byte;

begin
 Try := 10;
 ClearRxQueue;
 TempBRead:= TempBCount;
 SendUnHead(ZFile, $03000000);
 SendBlock (FHeaderLen, ZCRCW);
 repeat
   RByte := WaitHeader(HeadT, HeadP);
   Case RByte of
     WaitRCDO : begin
        SayError(zMsg_Carrier,0,0,'',true);
        endShow;
        ClearFileName(false,shZModem);
        SendFile:=WaitRCDO;
        exit;
       end;
     ZKeybAbb : begin
        SayError(zMsg_Keyb,0,0,'',true);
        endShow;
        ClearFileName(false,shZModem);
        SendFile:=ZKeybAbb;
        exit;
       end;
     ZAbbort  : begin
        SayError(zMsg_abort,0,0,'ZCAN receice',true);
        endShow;
        ClearFileName(false,shZModem);
        SendFile:=ZAbbort;
        exit;
       end;
     ZBadCRC,
     WaitTout : begin
        Dec(Try);
        If Try<>0 then begin
          SendUnHead(ZFile, $03000000);
          SendBlock (FHeaderLen, ZCRCW);
        end else begin
          SayError(zMsg_GlTOut,0,0,'',true);
          EndShow;
          ClearFileName(false,shZModem);
          SendFile:=ZAbbort;
          exit;
        end;
       end;
     ZOk : begin
        Case HeadT of
           ZCan : begin
              SayError(zMsg_abort,0,0,'ZCAN receive',true);
              endShow;
              ClearFileName(false,shZModem);
              SendFile := ZError;
              exit;
            end;
           ZFErr,
           ZNak : begin
              Dec(Try);
              If Try<>0 then begin
                ClearTxQueue;
                ClearRxQueue;
                TempBRead:= TempBCount;
                SendUnHead(ZFile, $03000000);
                SendBlock (FHeaderLen, ZCRCW);
              end else begin
                SayError(zMsg_GlTOut,0,0,'',true);
                EndShow;
                ClearFileName(false,shZModem);
                SendFile:=ZAbbort;
                exit;
              end;
            end;
           ZCRC : SendHexHeader (ZCrc, CRC32File(WorkFile));
           ZSkip : begin
              SendFile := ZFileSkip;
              exit;
            end;
           ZPos : begin
              If (not SeekFile(WorkFile, HeadP)) then begin
                SayError(zMsg_BadPos,HeadP,0,'',true);
                SendHexHeader(ZFErr, HeadP);
                SendFile := ZError;
                exit;
              end;
              If (HeadP = 0) then FileAddition := 'New     ' Else FileAddition := 'Recovery';
              CurPos:=HeadP;
              TransferStart:=HeadP;
              If CurPos <> 0 then begin
                SayError(zMsg_Resum,CurPos,0,'',true);
                Calc_CPS(false,shZModem);
              end;
              SendFile:=SendFileData;
              exit;
            end;
        end; {* Case *}
       end; {* ZOk *}
   end;
 until false;
end;

function ZModemSend     (FileToSend : PathStr;   { Файл, котоpый надо слать }
                         NewName    : PathStr;   { Hовое имя                }
                         ShowEnd    : TDispProg) : integer;

Var
  FSize              : LongInt;
  FTime              : LongInt;
  SendStr            : String;
  RByte              : integer;

begin
  ReceiveSize        := 0;
  TransferTime       := LongInt(0);
  FileAddition       := 'New     ';
  TransferBlockSize  := 0;
  TransferError      := 0;
  TransferStart      := 0;
  TransferBytes      := 0;
  TransferBeginTime  := 0;

  If Z_MakeCRC32 then TransferCheck:='32' else
                      TransferCheck:='16';

  EndShow            := ShowEnd;

  If not (FindFile(FileToSend, FSize, FTime)) then begin
    LogWrite(emCantFind,FileToSend,ld_SessAll);
    ZModemSend:=ZFileSkip;
    exit;
  end;

  If FSize=0 then begin
    SayError(zMsg_FileSkip,0,0,FileToSend+'. Reason: size=0',true);
    ZModemSend:=ZFileSkip;
    exit;
  end;

  If Not OpenFile(WorkFile, FileToSend,true) then begin
    LogWrite(emCantOpen,FileToSend,ld_SessAll);
    SendZCan;
    ZModemSend:=ZAbbort;
    exit;
  end;

  ReceiveSize        :=LongInt(FSize);
  TransferTime       :=LongInt(FTime);

  { Killing the t-Mail
  if JustFileName(FileToSend)='°°°°°°°°.°°°' then
    SendStr:= StLoCase('clock$')+#0+Long2Str(FSize)+' '+Date2Unix(FTime)+#0
  else
    Killing the t-Mail }

  SendStr:= StLoCase(NewName)+#0+Long2Str(FSize)+' '+Date2Unix(FTime)+#0;
  FHeaderLen:=Length(SendStr);
  Move(SendStr[1], RecBuffer^[1], FHeaderLen);

  TransferBeginTime := TimeCounter;
  ShowFileName(false,shZModem,NewName);
  LogWrite(imZSend,TransferCheck+#3+TruncPathName(FileToSend+
           ' ('+long2Str(ReceiveSize)+')',47),ld_Session);
  LogWrite(imZSend,TransferCheck+#3+FileToSend+
           ' ('+long2Str(ReceiveSize)+')',ld_file);
  RByte:=SendFile;
  ClearFileName(false,shZModem);
  CloseFile(WorkFile);
  If (RByte = ZKeybAbb) or (RByte = ZError) then
     SendZCan;
  ZModemSend:=RByte;
end;

{*************************************************************************}
{*                   Receiving Files                                     *}
{*************************************************************************}

procedure closeRecv(TTime:LongInt);
begin
  SetFileTime(WorkFile, TTime);
  CloseFile(WorkFile);
  endShow;
  ClearFileName(true,shZModem);
end;

function ReceiveFile : integer;
Var
  RByte     : Integer;
  TName     : String;
  TSize     : LongInt;
  TTime     : LongInt;
  FSize     : LongInt;
  FTime     : LongInt;
  ReplN     : String;
  TmpStr    : String;
  Tmp1Str   : String;
  Try       : byte;
  HeadT     : byte;
  HeadP     : LongInt;
  More      : boolean;
  DiskSpace : longInt;
  Make_File : boolean;

begin
  If RxPath[2]<>':' then
    DiskSpace:=VirtualDiskFree(0)
  else begin
    if RxPath[1] in ['A'..'Z'] then
      DiskSpace:=VirtualDiskFree(byte(RxPath[1])-$40);
    if RxPath[1] in ['a'..'z'] then
      DiskSpace:=VirtualDiskFree(byte(RxPath[1])-$60);
  end;

  If Z_MakeCRC32 then
    TransferCheck      := '32' else
    TransferCheck      := '16';
  AskSkip:=false;
  AskDelSkip:=false;
  ReceiveSize        := LongInt(0);
  TransferTime       := LongInt(0);
  TransferBlockSize  := 0;
  TransferError      := 0;
  TransferStart      := 0;
  TransferBytes      := 0;
  TransferBeginTime  := 0;
  Make_File          := false;
  ReceiveFile        := ZFileSkip;

  RByte := ReceiveBlock;
  Case RByte of
    GotCRCW : ;
   ZBadCRC  : begin
              SendHexHeader( ZNak, 0);
              ReceiveFile := ZFileSkip;
              exit;
              end;
   else
   ReceiveFile:=RByte;
   exit;
  end;

  TName := '';
  CurPos:=1;
  While (RecBuffer^[CurPos]<>0) and (CurPos<255) do begin
    TName := TName+char(RecBuffer^[CurPos]);
    Inc(CurPos);
  end;
  Inc(CurPos);

  TName:=CvtLongName(TName);

  TSize := 0;
  While (not (RecBuffer^[CurPos] in [0,$20])) and (CurPos<=RxCount) do begin
    TSize := (TSize*10) + (RecBuffer^[CurPos] - $30);
    Inc(CurPos);
  end;
  Inc(CurPos);
  ReceiveSize := TSize;

  TmpStr := '';
  While (RecBuffer^[CurPos] in [$30..$39]) and (CurPos<=RxCount) do begin
    TmpStr:=TmpStr+Char(RecBuffer^[CurPos]);
    Inc(CurPos);
  end;
  TTime:=Unix2Date(TmpStr);
  TTime:=TTime and $FFFFFFFE;
  TransferTime := LongInt(TTime);

  If TSize=0 then begin
    SayError(zMsg_FileSkip,0,0,TName+'. Reason: size=0',true);
    SendHexHeader(ZSKIP, 0);
    exit;
  end;

  LogWrite(imZRecv,TransferCheck+#3+TName+#3+
           long2Str(ReceiveSize),ld_Session);
  LogWrite(imZRecv,TransferCheck+#3+RxPath+TName+#3+
           long2Str(ReceiveSize),ld_File);

  { Check for Exist file }

  If FindFile(RxPath+TName, FSize, FTime) then begin
    If TTime = FTime then begin
      If TSize = FSize then begin
        SayError(zMsg_FileSkip,0,0,TName,true);
        SendHexHeader(ZSKIP, 0);
        Assign(WorkFile,RxPath+TName);
        ClearFileAttr(WorkFile);
        exit;
      end;
      If TSize > FSize then begin
        If DiskSpace<TSize-FSize then begin
          SayError(zMsg_FreeSp,DiskSpace,0,'',true);
          SendHexHeader(ZFErr, 0);
          exit;
        end;
        FileAddition       := 'Recovery';
        TransferStart      := FSize;
        CurPos             := FSize;
        SayError(zMsg_Resum,FSize,0,'',true);
      end;
      If TSize < FSize then begin
        If DiskSpace<=TSize then begin
          SayError(zMsg_FreeSp,DiskSpace,0,'',true);
          SendHexHeader(ZFErr, 0);
          ReceiveFile:=ZFileSkip;
          exit;
        end;
        FileAddition       := 'Replace ';
        CurPos             := 0;
        LogWrite(imReplace,TName,ld_SessAll);
        RenNextFile(RxPath,TName);
        Make_File:=true;
      end;
    end else begin { If TTime = FTime }
      If DiskSpace<=TSize then begin
        SayError(zMsg_FreeSp,DiskSpace,0,'',true);
        SendHexHeader(ZFErr, 0);
        ReceiveFile:=ZFileSkip;
        exit;
      end;
      CurPos             := 0;
      FileAddition       := 'Replace ';
      LogWrite(imReplace,TName,ld_SessAll);
      RenNextFile(RxPath,TName);
      Make_File:=true;
    end;
  end else begin { If FindFile }
    If DiskSpace<=TSize then begin
      SayError(zMsg_FreeSp,DiskSpace,0,'',true);
      SendHexHeader(ZFErr, 0);
      exit;
    end;
    FileAddition       := 'New     ';
    CurPos             := 0;
    Make_File:=true;
  end;

  { Откpаваем/создаем файл }
  If Make_File then begin
   If not (MakeFile(WorkFile, RxPath+TName)) then begin
     LogWrite(emCantCreate,TName,ld_SessAll);
     EndShow;
     ReceiveFile:=ZAbbort;
     exit;
   end else
     SetFileTime(WorkFile, TTime);
  end else begin
    If not (OpenFile(WorkFile, RxPath+TName,false)) then begin
      LogWrite(emCantOpen,TName,ld_SessAll);
      EndShow;
      ReceiveFile:=ZAbbort;
      exit;
    end else
      SetFileTime(WorkFile, TTime);
    If not (SeekFile(WorkFile, FSize)) then begin
      LogWrite(emCantSeek,TName,ld_SessAll);
      EndShow;
      ReceiveFile:=ZAbbort;
      exit;
    end;
  end;

  ReceivingFile := true;
  ShowFileName(true,shZModem,TName);
  { Receive File }
  Try := 10;
  TransferBeginTime  := TimeCounter;
  SendHexHeader( ZPos, CurPos);
  repeat
    RByte := WaitHeader( HeadT, HeadP);
    Case RByte of
    WaitRCDO : begin
        SayError(zMsg_Carrier,0,0,'',true);
        Receivefile:=WaitRCDO;
        CloseRecv(TTime);
        exit;
      end;
    ZKeybAbb : begin
        SayError(zMsg_Keyb,0,0,'',true);
        ReceiveFile:=ZKeybAbb;
        CloseRecv(TTime);
        exit;
      end;
    ZAbbort  : begin
        SayError(zMsg_abort,0,0,'ZCAN receive',true);
        ReceiveFile:=ZAbbort;
        CloseRecv(TTime);
        exit;
      end;
    WaitTout : begin
        Dec(Try);
        Inc(TransferError);
        If Try<>0 then begin
          SayError(zMsg_Tout,TransferStart+TransferBytes,Try,'',false);
          Calc_CPS(true,shZModem);
        end else begin
          SayError(zMsg_GlTOut,TransferStart+TransferBytes,0,'',true);
          ReceiveFile:=ZAbbort;
          CloseRecv(TTime);
          exit;
        end;
        SendHexHeader( ZPos, CurPos);
      end;
    ZbadCRC  : begin
        Dec(Try);
        Inc(TransferError);
        If Try<>0 then begin
          SayError(zMsg_BadCRC,TransferStart+TransferBytes,Try,'',false);
          Calc_CPS(true,shZModem);
        end else begin
          LogWrite(wmZMaxWrongPack,long2Str(TransferStart+TransferBytes),ld_SessAll);
          ReceiveFile:=ZAbbort;
          CloseRecv(TTime);
          exit;
        end;
        ClearRxQueue;
        TempBRead:= TempBCount;
        SendHexHeader( ZPos, CurPos);
      end;
    ZOk      : begin
        Case HeadT of
          ZData :
              If (CurPos <> HeadP) then begin
                Dec(Try);
                Inc(TransferError);
                If Try<>0 then begin
                  SayError(zMsg_BadPos,TransferStart+
                           TransferBytes,Try,'',false);
                  Calc_CPS(true,shZModem);
                end else begin
                  LogWrite(wmZMaxBadPos,long2Str(TransferStart+TransferBytes),ld_SessAll);
                  ReceiveFile:=ZAbbort;
                  CloseRecv(TTime);
                  exit;
                end;
                SendHexHeader( ZPos, CurPos);
              end else begin
                More:=False;
                Repeat
                  CallShow:=true;
                  Rbyte := ReceiveBlock;
                  CallShow:=false;
                  Case RByte of
                    WaitRCDO : begin
                        SayError(zMsg_Carrier,0,0,'',true);
                        Receivefile:=WaitRCDO;
                        CloseRecv(TTime);
                        exit;
                      end;
                    ZAbbort  : begin
                        SayError(zMsg_Abort,0,0,'ZCAN receive',true);
                        Receivefile:=ZAbbort;
                        CloseRecv(TTime);
                        exit;
                      end;
                    ZKeybAbb : begin
                        SayError(zMsg_Keyb,0,0,'',true);
                        Receivefile:=ZKeybAbb;
                        CloseRecv(TTime);
                        exit;
                      end;
                    ZbadCRC  : begin
                        Dec(Try);
                        Inc(TransferError);
                        If Try<>0 then begin
                          SayError(zMsg_BadCRC,TransferStart+
                                   TransferBytes,Try,'',false);
                          Calc_CPS(true,shZModem);
                        end else begin
                          LogWrite(wmZMaxWrongPack,
                                   long2Str(TransferStart+TransferBytes),
                                   ld_SessAll);
                          ReceiveFile:=ZAbbort;
                          CloseRecv(TTime);
                          exit;
                        end;
                        ClearRxQueue;
                        TempBRead:= TempBCount;
                        SendHexHeader( ZPos, CurPos);
                        more:=true;
                      end;
                    WaitTout : begin
                        Dec(Try);
                        Inc(TransferError);
                        If Try<>0 then begin
                          SayError(zMsg_Tout,TransferStart+TransferBytes,Try,'',false);
                          Calc_CPS(true,shZModem);
                        end else begin
                          SayError(zMsg_GlTOut,TransferStart+TransferBytes,0,'',true);
                          ReceiveFile:=ZAbbort;
                          CloseRecv(TTime);
                          exit;
                        end;
                        ClearRxQueue;
                        TempBRead:= TempBCount;
                        SendHexHeader( ZPos, CurPos);
                        more:=true;
                      end;
                    ZLongPak : begin
                        Dec(Try);
                        Inc(TransferError);
                        If Try<>0 then begin
                          LogWrite(wmZBadPos,long2Str(TransferStart+TransferBytes)+#3+
                                  long2Str(Try),ld_Session);
                          Calc_CPS(true,shZModem);
                        end else begin
                          LogWrite(wmZMaxWrongPack,
                                   long2Str(TransferStart+TransferBytes),ld_SessAll);
                          ReceiveFile:=ZAbbort;
                          CloseRecv(TTime);
                          exit;
                        end;
                        ClearRxQueue;
                        TempBRead:= TempBCount;
                        SendHexHeader( ZPos, CurPos);
                        more:=true;
                      end;
                    GOTCRCE .. GOTCRCW : Begin
                        If (AskSkip) or (AskDelSkip) then begin
                          ClearRxQueue;
                          TempBRead:= TempBCount;
                          SendHexHeader( ZPos, TSize);
                          LogWrite(imZSkipKeyboard,'',ld_SessAll);
                          if AskDelSkip then begin
                            CloseFile(WorkFile);
                            {$I-}Erase(WorkFile);{$I+}
                            TempIORes:=IOResult;
                            EndShow;
                            ClearFileName(true,shZModem);
                          end else
                            CloseRecv(TTime);
                          ReceiveFile:=ZFileSkip;
                          AskSkip:=false;
                          exit;
                        end;
                        Try := 10;
                        If not (WriteFile(WorkFile, RecBuffer^,RxCount)) then begin
                          LogWrite(emWriteError,'',ld_SessAll);
                          ReceiveFile:=ZAbbort;
                          CloseRecv(TTime);
                          exit;
                        end else begin
                          If pCfgRec^.CommitSize <> 0 then begin
                            Inc(TotalSave,RxCount);
                            If TotalSave div 1024 > pCfgRec^.CommitSize then begin
                              TotalSave:=0;
                              SetFileTime(WorkFile,TTime);
                            end;
                          end;
                        end;
                        TransferBlockSize:=RxCount;
                        CurPos:=CurPos+RxCount;
                        ReceiveByte := ReceiveByte + RxCount;
                        TransferBytes := CurPos - TransferStart;
                        Calc_CPS(true,shZModem);
                        If (RByte = GotCRCW) or (RByte = GotCRCQ) then
                          SendHexHeader(ZACK, CurPos);
                        If (RByte = GotCRCW) or (RByte = GotCRCE) then
                          More:=true;
                      end;
                  end;
                until more;
              end;
          ZNAK  : Begin
              Dec(Try);
              Inc(TransferError);
              If Try<>0 then begin
                SayError(zMsg_BadCRC,TransferStart+TransferBytes,Try,'',false);
                Calc_CPS(true,shZModem);
              end else begin
                LogWrite(wmZMaxWrongPack,long2Str(TransferStart+TransferBytes),ld_SessAll);
                ReceiveFile:=ZAbbort;
                CloseRecv(TTime);
                exit;
              end;
              SendHexHeader( ZPos, CurPos);
            end;
          ZEof  :
              If CurPos = TSize then begin
                TransferBytes:=CurPos-TransferStart;
                CloseRecv(TTime);
                ClearFileAttr(WorkFile);
                ReceiveFile:=ZOk;
                exit;
            end;
        end; { Case HeadT }
      end;
    end; { Case RByte }
  until false;
end;

function ZModemReceive  (InboundDir : PathStr;
                         ShowEnd    : TDispProg) : integer;
Var
  RByte    : Integer;
  HeadType : byte;
  HeadParm : LongInt;
  Try      : byte;

begin
  EndShow            := ShowEnd;
  RxPath             := AddBackSlash(InboundDir);

  Try := 0;
  ClearRxQueue;
  TempBRead:= TempBCount;

  If Z_MakeCRC32 then
    SendHexHeader(ZRInit,$27000000) else
    SendHexHeader(ZRInit,$07000000);

  Repeat
    RxTimeOut:=180;
    RByte := WaitHeader( HeadType, HeadParm);
    Case RByte of
      WaitRCDO : begin
          SayError(zMsg_Sync,0,0,'carrier lost',true);
          EndShow;
          ClearFileName(false,shZModem);
          ZModemReceive:=WaitRCDO;
          exit;
        end;
      ZBadCRC  : SendHexHeader(ZNak, 0);
      WaitTout : begin
          Inc(Try);
          If Try > 11 then begin
          SayError(zMsg_Sync,0,0,'global timeout',true);
            EndShow;
            ClearFileName(false,shZModem);
            ZModemReceive:=WaitTOut;
            exit;
          end;
          If Z_MakeCRC32 then
            SendHexHeader(ZRInit,$27000000) else
            SendHexHeader(ZRInit,$07000000);
          end;
      ZKeybAbb : begin
          SayError(zMsg_Keyb,0,0,'',true);
          EndShow;
          ClearFileName(false,shZModem);
          ZModemReceive:=ZKeybAbb;
          exit;
        end;
      ZAbbort  : begin
          SayError(zMsg_Abort,0,0,'ZCAN receive',true);
          EndShow;
          ClearFileName(false,shZModem);
          ZModemReceive:=ZAbbort;
          exit;
        end;
      ZOk      : begin
          Case HeadType of
            ZEof,
            ZRQInit : begin
                If Z_MakeCRC32 then
                  SendHexHeader( ZRInit, $27000000) else
                  SendHexHeader( ZRInit, $07000000);
              end;
            ZSInit  : begin
                RByte := ReceiveBlock;
                If Rbyte < 0 then
                  SendHexHeader( ZAck, HeadParm) else
                  SendHexHeader( ZNak, HeadParm);
              end;
            ZFreeCnt : SendHexHeader( ZAck, VirtualDiskFree(0));
            ZFin,ZCompl : begin
                RxTimeOut:=364;
                SendZFin;
                ZModemReceive:=ZOk;
                exit;
              end;
            ZFile : begin
                RxTimeOut:=364;
                If LastFrame <> ZBin32 then Z_MakeCRC32:=false else Z_MakeCRC32:=true;
                RByte:=ReceiveFile;
                If (RByte <> ZOk) and (RByte <> ZFileSkip) then begin
                  ZModemReceive := RByte;
                  exit;
                end;
                ReceivingFile := false;
                Try:=0;
                If Z_MakeCRC32 then
                  SendHexHeader(ZRInit,$27000000) else
                  SendHexHeader(ZRInit,$07000000);
              end;
          else
            Inc(Try);
          end; {* Case *}
        end;
    end;
    If Try > 11 then begin
      LogWrite(wmZCantSyncSend,'',ld_SessAll);
      EndShow;
      ClearFileName(false,shZModem);
      ZModemReceive:=ZAbbort;
      exit;
    end;
  until false;
end;

{*************************************************************************}

procedure ZModemBegin( Speed : LongInt; ZedZap : byte);
Var
   ConSp : word;
   SomeTemp : word;
begin
   VirtualCD:=true;
   BuffInfo(SomeTemp, SomeTemp, SomeTemp, TxBuffSize);
   If TraceMode then begin
     Assign(traceFile,'ZTrace.dbg');
     {$I-} Reset(traceFile,1); {$I+}
     If IOResult<>0 then
       Rewrite(traceFile,1);
     GetMem(TraceBuffer,1024);
     TraceCount:=1;
     Seek(TraceFile,FileSize(TraceFile));
     WriteTrace(TraceChar,TraceBord);
     WriteTrace(TraceChar,TraceBord);
   end;

   CurChngBlk :=BeginChngBlk;
   TabShow    :=nil;
   TempBCount := 0;
   TempBRead  := 0;
   GetMem(RecBuffer,16384);
   GetMem(WorkBuffer,1024);
   GetMem(TempBuffer,1024);
   BaudRate := Speed;
   WorkSpeed:=0;
   If BaudRate > 2400 then
      WorkSpeed:=1;
   If BaudRate > 4800 then
      WorkSpeed:=2;
   If BaudRate > 9600 then
      WorkSpeed:=3;

  Case ZedZap of
       0 : begin
             MaxBlock := 1024;
             ZMO_Mode := true;
           end;
       1 : MaxBlock := Z_MaxBlocks[WorkSpeed] div 2;
       2 : MaxBlock := Z_MaxBlocks[WorkSpeed];
       3 : MaxBlock := Z_MaxBlocks[WorkSpeed] * 2;
  end;
  SendByte       := 0;
  ReceiveByte    := 0;
  WaitZFin       := true;
  RxTimeOut      := 364;
end;

procedure ZModemEnd;
begin
   If TraceMode then begin
     WriteTrace(TraceChar,TraceBord);
     WriteTrace(TraceChar,TraceBord);
     WriteFile(TraceFile,TraceBuffer^,pred(TraceCount));
     FreeMem(TraceBuffer,1024);
     close(traceFile);
   end;
   ZMO_Mode := false;
   ClearTXQueue;
   ClearRXQueue;
   TempBRead:= TempBCount;
   FreeMem(RecBuffer,16384);
   FreeMem(WorkBuffer,1024);
   FreeMem(TempBuffer,1024);
end;

end.