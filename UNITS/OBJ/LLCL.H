   {$F+ $L+ $D+}

    function InitFLib(port:byte;p:pointer):integer;external;
    function EndWork:integer;external;
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
    function ReceiveCtrl(Mode:byte):integer;external;
    function WriteBlock(a:integer;p:pointer):integer;external;
    function ReadBlock(a:integer;p:pointer):integer;external;
    function ClearRxQueue:integer;external;
    function ClearTxQueue:integer;external;
    function ChangeSpeed(a:byte):integer;external;
    function GetPortStat:integer;external;
    function WatchDCD(a:byte):integer;external;
    function ChangeChanelPort(a:word):integer;external;
    function ChangeTimeOut(Time:word):integer;external;
    function GetAsyncInfo(p:pointer):integer;external;
    function GetChanelInfo(p:pointer):integer;external;
    function GetPortInfo(p:pointer):integer;external;
    function SendString(p:pointer):integer;external;
    function XXPass(Mode:byte):integer;external;
    function GetXtendPortStat:integer;external;
    function GetContextStr:pointer;external;
{---------AES----------------------------------}
    function CreateAlarmSem(var Hndl;var TimeSem;Period:longint):boolean;external;
    function DeleteAESClient(var Hndl):boolean;external;
    function CreateRepESR(var Hndl; Routine:pointer ;Period:longint):boolean;external;
    function CreateESR(var Hndl; Routine:pointer; var TruSem):boolean;external;
    procedure Suspend;external;
    function Resume:integer;external;
   {$L llcl_srv.obj}


{����⠭�� �訡��}
        TERR_REENT:integer = -1 ;
        TERR_NOMEM :integer= -2 ;
        TERR_NOLIB :integer= -3  ;
        TERR_ACTIV :integer= -4  ;
        TERR_TSSBUSY :integer= -5 ;
        TERR_NOACTIV :integer= -6 ;
        TERR_ARG :integer= -7   ;
        TERR_NOFOSS :integer= -8 ;
        TERR_NOROOM :integer= -9 ;
        TERR_PORTN :integer= -10 ;
        TERR_RXEMPTY :integer= -11 ;
        TERR_TXFULL :integer= -12  ;
        TERR_ILLVER :integer= -13  ;
        TERR_TOUT :integer= -14  ;
        AERR_NOAES : integer= -$40 ;
        TERR_NIMPL :integer= $FF ;
{����⠭�� �ࠢ����� ��⮪��}
        FL_LOCK:byte=$80;  {����� ����}
        FL_DCD:byte=$40;   {᫥���� �� �ய������� DCD}
        FL_XX:byte=$20;    {�ய�᪠�� XON/XOFF(⮫쪮 �᫨ softflow)}
        FL_RXSOFT:byte=$8; {soft flow �� �ਥ�}
        FL_ALTHARDW:byte=$4;   {DTR/DSR  ���  ⨯  ��  ᮢ���⨬  �
����設�⢮� ��ᨫ�� ��⮬� ��� �� ४��������� ��⠭��������}

        FL_HARDW:byte=$2;  {hard flow}
        FL_TXSOFT:byte=$1; {sowt flow �� ��।���}

{����⠭�� ��� 㤮��⢠ ࠧ��� ᫮�� �����頥���� �㭪樥� GetPortStat}

        ST_TXEMPT=$4000; { ���� ��।�� ����}
        ST_TXAV=$2000;  {� ���� ��।�� ���� ����}
        ST_OVRN=$0200;  {���� �ਥ�� �� ��९�����}
        ST_RDA=$0100;   {���� ����� � ���� �ਥ��}
        ST_DCD=$0080; {���� ������}
        ST_RING=$0040; {���� ������}
        ST_DTR=$0002; {DTR ��⨢��}
        ST_PREVDCD=$0001; {�।��騥 ���ﭨ� DCD}
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


        BIT5=5; { 5 ��� ������}
        BIT6=6; { 6 ��� ������}
        BIT7=7; { 7 ��� ������}
        BIT8=8; { 8 ��� ������}

        STOP1=1; { 1 �⮯ ��� }
        STOP2=2; { 2 �⮯ ��� }

        NOPARITY=0;   { ��� ����஫� �⭮��}
        ODDPARITY=1;  { ����஫� ���⭮�� }
        EVENPARITY=2; { ����஫� �⭮�� }

{����⠭�� ��� 㤮��⢠ ࠡ��� � ��⮢�� ������� rLibFlags}
        FDIRECT=2 ; {�맮� ��ᨫ� �� �����}
        FOLDINT14=0 ; {�맮� �१ int 14h}
        FGEN=0 ; {������� ᮡ�⨩ AES - ��ᨫ}
        STCGEN=4 ; {������� ᮡ�⨩ AES - ⠩���}
        UTCGEN=8 ; {������� ᮡ�⨩ AES - ⠬�� �� ����� 1Ch}
        RTCGEN=$0C ; {������ ᮡ�⨩ AES - ��� ॠ�쭮�� �६���}

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
                wCPUID:byte;
         end;

{������(�������) ��⠭���� ����}
        type PortParam=record
                vPortNomber:word;
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
                vInfoSize:word;
                cFossRev:byte;
                cDrvVer:byte;
                pDrvName:pointer;
                cRxBuffSz:word;
                cRxBuffFree:word;
                cTxBuffSz:word;
                cTxBuffFree:word;
                vScreenW:byte;
                vScreenH:byte;
                vSpeed:byte
        end;

{������(�������) ���ଠ樨 � LLCL�ࠩ���}
  type LLCLInfo=record
    wInfoSize:word;               {ࠧ��� �⮩ ��������}
    wLLCLID:word;                 {�����䨪��� LLCL}
    bDrvRev:byte;                 {ॢ���� LLCL �������� HEX}
    bDrvVer:byte;                 {����� ������� �ࠩ��� - ��������� HEX}
    bMinRev:byte;                 {�������쭠� ॢ���� ᮢ���⨬���}
    rOptions:longint;             {䫠�� �ࠩ���}
    fpDrvName:pointer;            {㪠��⥫� �� ��� �ࠩ���}
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
(*�᫨ � ᪮��� ��⠭����� ���訩 ��� � ᪮���� ��������
;���� � ���� � ᥪ㭤�. ������ �� 0 �� 2.147.483.647 ���/���� � ᥪ㭤� *)
    bBits:byte;                    {ࠧ��� ������� ������}
    wTxBlockSize:word;             {max ࠧ��� ����� ��।��}
    wRxBlockSize:word;             {max ࠧ��� ����� �ਥ��}
    bErrorControl:byte;       (* ���஫� �訡��
                                0 - ��� ����஫�
                                1 - ���⭮���
                                2 - �⭮���
                                3 - ����஫쭠� �㬬� 8 ���
                                4 - ����஫쭠� �㬬� 16 ���
                                5 - CRC-16
                                6 - CRC-32
                                7 - CRC-64
                                8 - CRC-128 *)
  end;