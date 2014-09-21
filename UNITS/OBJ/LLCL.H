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


{константы ошибок}
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
{константы управления потоком}
        FL_LOCK:byte=$80;  {лочить порт}
        FL_DCD:byte=$40;   {следить за пропаданием DCD}
        FL_XX:byte=$20;    {пропускать XON/XOFF(только если softflow)}
        FL_RXSOFT:byte=$8; {soft flow на прием}
        FL_ALTHARDW:byte=$4;   {DTR/DSR  этот  тип  не  совместим  с
большинством фоссилов потому его не рекомендуется устанавливать}

        FL_HARDW:byte=$2;  {hard flow}
        FL_TXSOFT:byte=$1; {sowt flow на передачу}

{константы для удобства разбора слова возвращаемого функцией GetPortStat}

        ST_TXEMPT=$4000; { буфер передачи пуст}
        ST_TXAV=$2000;  {в буфере передачи есть место}
        ST_OVRN=$0200;  {буфер приема был переполнен}
        ST_RDA=$0100;   {есть данные в буфере приема}
        ST_DCD=$0080; {есть несущая}
        ST_RING=$0040; {есть звонок}
        ST_DTR=$0002; {DTR активен}
        ST_PREVDCD=$0001; {Предыдущие состояние DCD}
{константы для удобства установки параметров порта}

  SP110=0;     {110 бод   }
  SP150=1;     {150 бод   }
  SP300=2;     {300 бод   }
  SP600=3;     {600 бод   }
  SP1200=4;    {1200 бод  }
  SP2400=5;    {2400 бод  }
  SP4800=6;    {4800 бод  }
  SP9600=7;    {9600 бод  }
  SP19200=8;   {19200 бод }
  SP38400=9;   {38400 бод }
  SP57600=10;  {57600 бод }
  SP115200=11; {115200 бод}


        BIT5=5; { 5 бит данных}
        BIT6=6; { 6 бит данных}
        BIT7=7; { 7 бит данных}
        BIT8=8; { 8 бит данных}

        STOP1=1; { 1 стоп бит }
        STOP2=2; { 2 стоп бит }

        NOPARITY=0;   { без контроля четности}
        ODDPARITY=1;  { контроль нечетности }
        EVENPARITY=2; { контроль четности }

{Константы для удобства работы с битовой записью rLibFlags}
        FDIRECT=2 ; {вызов фоссила на прямую}
        FOLDINT14=0 ; {вызов через int 14h}
        FGEN=0 ; {генератор событий AES - фоссил}
        STCGEN=4 ; {генератор событий AES - таймер}
        UTCGEN=8 ; {генератор событий AES - тамер но вектор 1Ch}
        RTCGEN=$0C ; {генратор событий AES - часы реального времени}

{запись(структура) информации о библиотеке}
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

{запись(структура) установок порта}
        type PortParam=record
                vPortNomber:word;
                vPortSpeed:byte;
                vPortParity:byte;
                vPortStop:byte;
                vPortBits:byte;
                rFlowCtrl:byte;
                vTimeOut:word;
        end;

{запись(структура) информации о канале}
        type ChanelInfo=record
                vTaskHndl:byte;
                vOpenTime:longint;
                vCloseTime:longint;
                vCharRx:longint;
                vCharTx:longint;
                vPortAssign:word;
        end;

{запись(структура) информации о коммуникационном драйвере(фоссиле)}
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

{запись(структура) информации о LLCLдрайвере}
  type LLCLInfo=record
    wInfoSize:word;               {размер этой структуры}
    wLLCLID:word;                 {идентификатор LLCL}
    bDrvRev:byte;                 {ревизия LLCL пакованый HEX}
    bDrvVer:byte;                 {версия данного драйвера - пакованный HEX}
    bMinRev:byte;                 {минимальная ревизия совместимости}
    rOptions:longint;             {флаги драйвера}
    fpDrvName:pointer;            {указатель на имя драйвера}
    fpLLCLPARAM:pointer;          {указатель на структуру LLCLPARAM}
    fpDrvSpecific:pointer;        {указатель на структуру специфичных параметров}
    fpAdditional:pointer;         {указатель на дополнительную структуру инфы}
    wRxBuffSz:word;               {размер буфера приема}
    wRxBuffFree:word;             {сколько свободно в буфере приема}
    wTxBuffSz:word;               {размер буфера передачи}
    wTxBuffFree:word;             {сколько свободно в буфере передачи}
    wRxLMark:word;                {нижня граница срабатывания flow control}
    wRxHMark:word;                {верхняя граница срабатывания flow control}
    wTxLMark:word;                {граница "в буфере есть место" буфера передачи}
    wRxTimeOut:word;              {таймаут приема в тиках }
    wTxTimeOut:word;              {таймаут передачи в тиках}
    dwRxSpeed:longint;            {скоротсть приема }
    dwTxSpeed:longint;            {скорость передачи}
(*если в скорости установлен старший бит то скорость килобитах
;иначе в битах в секунду. Тоесть от 0 до 2.147.483.647 бит/кбит в секунду *)
    bBits:byte;                    {размер еденицы данных}
    wTxBlockSize:word;             {max размер блока передачи}
    wRxBlockSize:word;             {max размер блока приема}
    bErrorControl:byte;       (* котроль ошибок
                                0 - без контроля
                                1 - нечетность
                                2 - четность
                                3 - контрольная сумма 8 бит
                                4 - контрольная сумма 16 бит
                                5 - CRC-16
                                6 - CRC-32
                                7 - CRC-64
                                8 - CRC-128 *)
  end;