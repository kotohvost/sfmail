{$F+,A+,B-,G+,I-,L-,D-,S-}
unit Fos_Lib;
interface
  uses RelTQ,
       TPCrt,
       tstring_;
const
   GlobalTimeOut      = 36;
   TimeCounter        : LongInt = 0;

const
   TERR_REENT         = -1  ;
   TERR_NOMEM         = -2  ;
   TERR_NOLIB         = -3  ;
   TERR_ACTIV         = -4  ;
   TERR_TSSBUSY       = -5  ;
   TERR_NOACTIV       = -6  ;
   TERR_ARG           = -7  ;
   TERR_NOFOSS        = -8  ;
   TERR_NOROOM        = -9  ;
   TERR_PORTN         = -10 ;
   TERR_RXEMPTY       = -11 ;
   TERR_TXFULL        = -12 ;
   TERR_ILLVER        = -13 ;
   TERR_TOUT          = -14 ;
   AERR_NOAES         = -$40;
   TERR_NIMPL         = $FF ;

{����⠭�� �ࠢ����� ��⮪��}
   FL_LOCK            = $80 ;{����� ����}
   FL_DCD             = $40 ;{᫥���� �� �ய������� DCD}
   FL_XX              = $20 ;{�ய�᪠�� XON/XOFF(⮫쪮 �᫨ softflow)}
   FL_RXSOFT          = $8  ;{soft flow �� �ਥ�}
   FL_ALTHARDW        = $4  ;{DTR/DSR  ���  ⨯  ��  ᮢ���⨬  �
                              ����設�⢮� ��ᨫ�� ��⮬� ��� ��
                              ४��������� ��⠭��������}

   FL_HARDW           = $2  ;{hard flow}
   FL_TXSOFT          = $1  ;{sowt flow �� ��।���}

{����⠭�� ��� 㤮��⢠ ࠧ��� ᫮�� �����頥���� �㭪樥� GetPortStat}
   ST_TXEMPT          = $4000;{ ���� ��।�� ����}
   ST_TXAV            = $2000;{� ���� ��।�� ���� ����}
   ST_OVRN            = $0200;{���� �ਥ�� �� ��९�����}
   ST_RDA             = $0100;{���� ����� � ���� �ਥ��}
   ST_DCD             = $0080;{���� ������}
   ST_RING            = $0040;{���� ������}
   ST_DTR             = $0002;{DTR ��⨢��}
   ST_PREVDCD         = $0001;{�।��騥 ���ﭨ� DCD}

{����⠭�� ��� 㤮��⢠ ��⠭���� ��ࠬ��஢ ����}
  SP110=0;     {110 ���   }
  SP150=1;     {150 ���   }
  SP300=2;     {300 ���   }
  SP600=3;     {600 ���   }
  SP1200=4;    {1200 ���  }
  SP2400=5;    {2400 ���  }
  SP4800=6;    {4800 ���  }
  SP9600=7;    {9600 ���  }
  SP19200=8;   {19200 ��� }
  SP38400=9;   {38400 ��� }
  SP57600=10;  {57600 ��� }
  SP115200=11; {115200 ���}

  BIT5=5;      { 5 ��� ������}
  BIT6=6;      { 6 ��� ������}
  BIT7=7;      { 7 ��� ������}
  BIT8=8;      { 8 ��� ������}

  STOP1=1;     { 1 �⮯ ��� }
  STOP2=2;     { 2 �⮯ ��� }

  NOPARITY  =0;{ ��� ����஫� �⭮��}
  ODDPARITY =1;{ ����஫� ���⭮�� }
  EVENPARITY=2;{ ����஫� �⭮�� }

{����⠭�� ��� 㤮��⢠ ࠡ��� � ��⮢�� ������� rLibFlags}
  FDIRECT   =2 ; {�맮� ��ᨫ� �� �����}
  FOLDINT14 =0 ; {�맮� �१ int 14h}
  FGEN      =0 ; {������� ᮡ�⨩ AES - ��ᨫ}
  STCGEN    =4 ; {������� ᮡ�⨩ AES - ⠩���}
  RTCGEN    =8 ; {������ ᮡ�⨩ AES - ��� ॠ�쭮�� �६���}


{����⠭�� ��� �������� ᨬ����}
  WaitTOUT  = -1;
  WaitRCDO  = -2;

{������(�������) ���ଠ樨 � ������⥪�}
  type LibInfo=record
       pReleaseSlice:pointer;
       fpAESStack:pointer;
       fpServerStack:pointer;
       wAESStckSize:word;
       wServerStckSize:word;
       cLibver:word;
       cFossilRev:byte;
       cDriverRev:byte;
       cMaxFossFunc:byte;
       pDrvName:pointer;
       rLibFlags:byte;
       wDrvType:word;
       bCPUID:byte;
  end;

{������(�������) ��⠭���� ����}
  type PortParam=record
       vPortNumber:word;
       wPortHandl:word;
       vPortSpeed:byte;
       vPortParity:byte;
       vPortStop:byte;
       vPortBits:byte;
       rFlowCtrl:byte;
       vTimeOut:word;
  end;

{������(�������) ���ଠ樨 � ������}
  type ChanelInfo=record
       vTaskHndl:byte;
       vOpenTime:longint;
       vCloseTime:longint;
       vCharRx:longint;
       vCharTx:longint;
       vPortAssign:word;
  end;

{������(�������) ���ଠ樨 � ����㭨��樮���� �ࠩ���(��ᨫ�)}
  type FossInfo=record
       wInfoSize:word;
       bDrvRev:byte;
       bDrvVer:byte;
       pDrvName:pointer;
       wRxBuffSz:word;
       wRxBuffFree:word;
       wTxBuffSz:word;
       wTxBuffFree:word;
       bScreenW:byte;
       bScreenH:byte;
       bSpeed:byte
  end;

{������(�������) ���ଠ樨 � LLCL�ࠩ���}
  type LLCLInfo=record
    wInfoSize:word;               {ࠧ��� �⮩ ��������}
    wLLCLID:word;                 {�����䨪��� LLCL}
    bDrvRev:byte;                 {ॢ���� LLCL �������� HEX}
    bDrvVer:byte;                 {����� ������� �ࠩ��� - ��������� HEX}
    bMinRev:byte;                 {�������쭠� ॢ���� ᮢ���⨬���}
    rOptions:longint;             {䫠�� �ࠩ���}
    pDrvName:pointer;             {㪠��⥫� �� ��� �ࠩ���}
    fpLLCLPARAM:pointer;          {㪠��⥫� �� �������� LLCLPARAM}
    fpDrvSpecific:pointer;        {㪠��⥫� �� �������� ᯥ����� ��ࠬ��஢}
    fpAdditional:pointer;         {㪠��⥫� �� �������⥫��� �������� ����}
    wRxBuffSz:word;               {ࠧ��� ���� �ਥ��}
    wRxBuffFree:word;             {᪮�쪮 ᢮����� � ���� �ਥ��}
    wTxBuffSz:word;               {ࠧ��� ���� ��।��}
    wTxBuffFree:word;             {᪮�쪮 ᢮����� � ���� ��।��}
    wRxLMark:word;                {����� �࠭�� �ࠡ��뢠��� flow control}
    wRxHMark:word;                {������ �࠭�� �ࠡ��뢠��� flow control}
    wTxLMark:word;                {�࠭�� "� ���� ���� ����" ���� ��।��}
    wRxTimeOut:word;              {⠩���� �ਥ�� � ⨪�� }
    wTxTimeOut:word;              {⠩���� ��।�� � ⨪��}
    dwRxSpeed:longint;            {᪮����� �ਥ�� }
    dwTxSpeed:longint;            {᪮���� ��।��}
    bBits:byte;                   {ࠧ��� ������� ������}
    wTxBlockSize:word;            {max ࠧ��� ����� ��।��}
    wRxBlockSize:word;            {max ࠧ��� ����� �ਥ��}
    bErrorControl:byte;
  end;

var
   sLibInfo       : LibInfo;
   sPortParam     : PortParam;
   sChanelInfo    : ChanelInfo;
   sLLCLInfo      : LLCLInfo;
   sFossInfo      : FossInfo absolute sLLCLInfo;
   pLibInfo       : ^LibInfo;
   ErrorCode      : integer;
   pPortParam     : ^PortParam;
   pChanelInfo    : ^ChanelInfo;

{ Fossil lib }
  function InitFLib(a:byte;p:pointer):integer;
  function OpenChanel(a:pointer):integer;
  function CloseChanel(a:byte;p:pointer):integer;
  function InitPort:integer;
  function SetPort(p:pointer):integer;
  function DoPause(a:longint):integer;
  function ReadChar:integer;
  function WriteChar(a:char):integer;
  function PeekChar:integer;
  function WaitChar:integer;
  function WriteWaitChar(a:char):integer;
  function SendBreak(a:byte):integer;
  function ChangeDTR(a:byte):integer;
  function ToggleDTR:integer;
  function PulseDTR(a:byte):integer;
  function ClearRxQueue:integer;
  function ClearTxQueue:integer;
  function WriteBlock(a:word;p:pointer):integer;
  function ReadBlock(a:word;p:pointer):integer;
  function ChangeSpeed(a:byte):integer;
  function GetPortStat:integer;
  function WatchDCD(a:byte):integer;
  function ChangeChanelPort(a:word):integer;
  function GetChanelInfo(p:pointer):integer;
  function GetPortInfo(p:pointer):integer;
  function GetAsyncInfo(p:pointer):integer;
  function EndWork:integer;
  function SendString(p:pointer):integer;
  function XXPass(b:byte):integer;
  function GetContextStr:pointer;
  function GetXtendPortStat:integer;
  function ChangeTimeOut(Time:word):integer;
  function ReceiveCtrl(Mode:byte):integer;
{ AES }
  function CreateAlarmSem(var Hndl;var TimeSem;Period:longint):boolean;
  function CreateESR(var Hndl; Routine:pointer; var TruSem):boolean;
  function CreateRepESR(var Hndl; Routine:pointer ;Period:longint):boolean;
  function DeleteAESClient(var Hndl):boolean;
  procedure Suspend;
  function Resume:integer;

{ My Own routines }
  procedure Pause(t : longInt);
  function FullInit(Com:byte; Speed:Longint):Integer;
  Procedure FullClose;
  function ReInit(Com:byte; Speed:Longint):Integer;
  Procedure TempClose;
  function WriteString (OutString: String):integer;
  function WriteStringCR (OutString: String):integer;
  function SendStr (OutString: String):integer;
  function ReadString (var InString: String):integer;
  function ReadWait : Integer;
  function WaitTimeChar (TimePeriod : word):Integer;
  procedure BuffInfo(var RxFree, TxFree, RxTotal, TxTotal : word);

implementation
uses
   Config;

{ Fossil lib }
  function InitFLib(a:byte;p:pointer):integer;external;
  function OpenChanel(a:pointer):integer;external;
  function CloseChanel(a:byte;p:pointer):integer;external;
  function InitPort:integer;external;
  function SetPort(p:pointer):integer;external;
  function DoPause(a:longint):integer;external;
  function ReadChar:integer;external;
  function WriteChar(a:char):integer;external;
  function PeekChar:integer;external;
  function WaitChar:integer;external;
  function WriteWaitChar(a:char):integer;external;
  function SendBreak(a:byte):integer;external;
  function ChangeDTR(a:byte):integer;external;
  function ToggleDTR:integer;external;
  function PulseDTR(a:byte):integer;external;
  function ClearRxQueue:integer;external;
  function ClearTxQueue:integer;external;
  function WriteBlock(a:word;p:pointer):integer;external;
  function ReadBlock(a:word;p:pointer):integer;external;
  function ChangeSpeed(a:byte):integer;external;
  function GetPortStat:integer;external;
  function WatchDCD(a:byte):integer;external;
  function ChangeChanelPort(a:word):integer;external;
  function GetChanelInfo(p:pointer):integer;external;
  function GetPortInfo(p:pointer):integer;external;
  function GetAsyncInfo(p:pointer):integer;external;
  function EndWork:integer;external;
  function SendString(p:pointer):integer;external;
  function XXPass(b:byte):integer;external;
  function GetContextStr:pointer;external;
  function GetXtendPortStat:integer;external;
  function ChangeTimeOut(Time:word):integer;external;
  function ReceiveCtrl(Mode:byte):integer;external;
{AES}
  function CreateAlarmSem(var Hndl;var TimeSem;Period:longint):boolean;external;
  function CreateESR(var Hndl; Routine:pointer; var TruSem):boolean;external;
  function CreateRepESR(var Hndl; Routine:pointer ;Period:longint):boolean;external;
  function DeleteAESClient(var Hndl):boolean;external;
  procedure Suspend;external;
  function Resume:integer;external;

{$L llcl_srv.obj}

procedure Pause(t : longInt);
var
   TimeCounter  : LongInt absolute $40:$6C;
   OldTime      : LongInt;
begin
  OldTime:=TimeCounter;
  while TimeCounter<OldTime+t do
  if TimeCounter<OldTime then exit else releaseTQ;
end;

function FullInit(Com:byte; Speed:Longint):Integer;
begin
  pLibinfo:=@sLibInfo;
  sLibInfo.pReleaseSlice:=@ReleaseTQ;
  sLibInfo.bCPUID:=sCPUXID.bXID;
  sLibInfo.wAESStckSize:=4096;
  GetMem(sLibInfo.fpAESStack, sLibInfo.wAESStckSize);
  sLibInfo.wServerStckSize:=0;
  sLibInfo.fpServerStack:=nil;
  If (pCfgRec^.SysFlags and mdmFossilDirect) <> 0 then sLibInfo.rLibFlags:=$6
   else sLibInfo.rLibFlags:=$4;

  ErrorCode:=0;
  ErrorCode:= InitFLib(Com,pLibInfo);
  if ErrorCode<0 then begin
     FullInit:=ErrorCode;
     Exit;
  end;
  FullInit:=ReInit(Com,Speed);
end;

function ReInit(Com:byte; Speed:Longint):Integer;

procedure CheckSpeed;
begin
  sPortParam.rFlowCtrl:=FL_HARDW;
  if Speed = 110 then begin
    sPortParam.vPortSpeed := SP110;
    exit;
  end;
  if Speed = 150 then begin
    sPortParam.vPortSpeed := SP150;
    exit;
  end;
  if Speed = 300 then begin
    sPortParam.vPortSpeed := SP300;
    exit;
  end;
  if Speed = 600 then begin
    sPortParam.vPortSpeed := SP600;
    exit;
  end;
  if Speed = 1200 then begin
    sPortParam.vPortSpeed := SP1200;
    exit;
  end;
  if Speed = 2400 then begin
    sPortParam.vPortSpeed := SP2400;
    exit;
  end;
  if Speed = 4800 then begin
    sPortParam.vPortSpeed := SP4800;
    exit;
  end;
  if Speed = 9600 then begin
    sPortParam.vPortSpeed := SP9600;
    exit;
  end;
  if Speed = 19200 then begin
    sPortParam.vPortSpeed := SP19200;
    exit;
  end;
  if Speed = 38400 then begin
    sPortParam.vPortSpeed := SP38400;
    exit;
  end;
  if Speed = 57600 then begin
    sPortParam.vPortSpeed := SP57600;
    exit;
  end;
  if Speed = 115200 then begin
    sPortParam.vPortSpeed := SP115200;
    exit;
  end;

  { No Speed Define }
  sPortParam.vPortSpeed := SP19200;
  sPortParam.rFlowCtrl:=FL_LOCK or FL_HARDW;
end;

Var
  TmpScreen : pointer;

begin
  sPortParam.vPortNumber:=Com;
  sPortParam.rFlowCtrl:=0;
  CheckSpeed;
  sPortParam.vPortParity:=NoParity;
  sPortParam.vPortStop:=Stop1;
  sPortParam.vPortBits:=Bit8;
  sPortParam.vTimeOut:=GlobalTimeOut;
  pPortParam:=@sPortParam;

  if not SaveWindow(1, 1, 80, ScreenHeight, true, TmpScreen) then begin
    ErrorCode:=OpenChanel(pPortParam);
    InitPort;
  end else begin
    ErrorCode:=OpenChanel(pPortParam);
    InitPort;
    RestoreWindow(1, 1, 80, ScreenHeight, true, TmpScreen);
  end;

  ErrorCode:=ChangeDTR(1);
  if ErrorCode<0 then begin
    ReInit:=ErrorCode;
    Exit;
  end;
  Delay(200);
  if sLibInfo.wDrvType<$10 then
    ErrorCode:=GetAsyncInfo(@sFossInfo)
  else
    ErrorCode:=GetAsyncInfo(@sLLCLInfo);
  ErrorCode:=ChangeDTR(1);
  Delay(100);
  ReInit:=0;
end;

function WriteString (OutString: String):integer;
Var
 Pos: Byte;
begin
  For Pos := 1 to Length(OutString) do begin
    case OutString[Pos] of
     '~' : Pause(9);
     '''': Pause(2);
     '^' : ChangeDTR(1);
     'v' : ChangeDTR(0);
     '|' : begin
             ErrorCode:=WriteWaitChar(#13);
             if ErrorCode<0 then begin
                WriteString:=ErrorCode;
                Exit
             end;
           end;
    else
     ErrorCode:=WriteWaitChar(OutString[Pos]);
       if ErrorCode<0 then begin
         WriteString:=ErrorCode;
         Exit;
       end;
    end;
  end;
  WriteString:=0;
end;

function WriteStringCR (OutString: String):integer;
Var
 Pos: Byte;
begin
  For Pos := 1 to Length(OutString) do begin
    case OutString[Pos] of
     '|' : begin
             ErrorCode:=WriteWaitChar(#13);
             ErrorCode:=WriteWaitChar(#10);
             if ErrorCode<0 then begin
                WriteStringCR:=ErrorCode;
                Exit
             end;
           end;
     else
          ErrorCode:=WriteWaitChar(OutString[Pos]);
          if ErrorCode<0 then begin
             WriteStringCR:=ErrorCode;
             Exit;
          end;
     end;
   end;
   WriteStringCR:=0;
end;

function SendStr (OutString: String):integer;
Var
 Pos: Byte;
begin
  For Pos := 1 to Length(OutString) do begin
      ErrorCode:=WriteWaitChar(OutString[Pos]);
      if ErrorCode<0 then begin
         SendStr:=ErrorCode;
         Exit;
      end;
  end;
  SendStr:=0;
end;

Procedure FullClose;
begin
  pChanelInfo:=@sChanelInfo;
  ErrorCode:=CloseChanel($FF,pChanelInfo);
  EndWork;
end;

Procedure TempClose;
begin
  pChanelInfo:=@sChanelInfo;
  ErrorCode:=CloseChanel($FF,pChanelInfo);
end;

function ReadWait : Integer;
Var
    C    : Integer;
    Time : LongInt;
begin
  c:=ReadChar;
  If C<>TERR_RXEMPTY then begin
    ReadWait := C;
    exit;
  end else begin
    Time := TimeCounter;
    Repeat
      if (mtOsVer=mtOS_2) or (mtOsVer=mtDoubleDos) or (mtOsVer=mtPSMOS) then ReleaseTQ;
      If (GetPortStat And ST_RDA) <> 0 then begin
        ReadWait := ReadChar;
        exit;
      end;
    Until (TimeCounter > Time + GlobalTimeOut) or (TimeCounter<Time);
    ReadWait := WaitTOUT;
  end;
end;

function WaitTimeChar (TimePeriod : word) : Integer;
Var
    C    : Integer;
    Time : LongInt;
begin
  c:=ReadChar;
  If C<>TERR_RXEMPTY then begin
    WaitTimeChar := C;
    exit;
  end else begin
    Time := TimeCounter+TimePeriod;
    Repeat
      ReleaseTQ;
      c:=GetPortStat;
      If (C And ST_DCD) = 0 then begin
        WaitTimeChar := WaitRCDO;
        exit;
      end;
      If (C And ST_RDA) <> 0 then begin
        WaitTimeChar := ReadChar;
        exit;
      end;
    Until (TimeCounter > Time) or (TimeCounter<Time-TimePeriod);
    WaitTimeChar := WaitTOUT;
  end;
end;

function ReadString (var InString: String):integer;
var
  Try : byte;
begin
  Try := 2;
  Repeat
    ErrorCode:=ReadWait;
    if ErrorCode<0 then begin
      Dec(Try);
      If Try=0 then begin
        ReadString:=ErrorCode;
        exit;
      end;
      ErrorCode:=0;
    end else begin
      Try:=2;
      InString:=InString+char(ErrorCode);
    end;
  until char(Errorcode)=#13;
  ReadString:=0;
end;

procedure BuffInfo(var RxFree, TxFree, RxTotal, TxTotal : word);
begin
  if sLibInfo.wDrvType<$10 then
    ErrorCode:=GetAsyncInfo(@sFossInfo)
  else
    ErrorCode:=GetAsyncInfo(@sLLCLInfo);
  if ErrorCode < 0 then begin
    RxFree:=0; TxFree:=0; RxTotal:=0; TxTotal:=0;
  end else begin
    if sLibInfo.wDrvType<$10 then begin
      RxFree:=sFossInfo.wRxBuffFree;
      TxFree:=sFossInfo.wTxBuffFree;
      RxTotal:=sFossInfo.wRxBuffSz;
      TxTotal:=sFossInfo.wTxBuffSz;
    end else begin
      RxFree:=sLLCLInfo.wRxBuffFree;
      TxFree:=sLLCLInfo.wTxBuffFree;
      RxTotal:=sLLCLInfo.wRxBuffSz;
      TxTotal:=sLLCLInfo.wTxBuffSz;
    end;
  end;
end;

end.
