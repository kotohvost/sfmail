{ Hydra define file }

Const
  { Session Result }
  hOk         = 0;
  hLostCD     = -1;
  hKeybAbb    = -2;
  hRemoteAbb  = -3;

  lPktPrefix  = 30;     { Prefix max=30 }
  lMaxBlock   = 2048+16;{ with CRC-32 (���ᨬ���� �p���)}
  lTransmitBuff = 6200; { �����p ����p� ��� ��p����}
  lTxSaveBuff = 10240;  { �����p ����p ��� ��p����, � ����ᮬ }

Type
  pBuffer     = ^tBuffer;
  tBuffer     = array [0..lTxSaveBuff-1] of byte;

Type
  tBufferControl = record
    PktPrefix    : String[lPktPrefix]; { �p�䨪� }
    PktType      : char;               { ��� ����� }
    PktLen       : word;               { ����� ����� }
    TransmitBuff : pBuffer;            { ����p ��� �p����� ������p��������}
    DataBuff     : pBuffer;            { ���� ����� }
    Try          : byte;               { �p�� }
    Timer        : LongInt;            { ����-���� }
    WorkFile     : file;               { 䠩� }
    Pos          : longInt;            { ������ � p���祬 䠩�� }
    FileName     : PathStr;            { ��� ��p����뢠����� 䠩�� }
    SendName     : PathStr;            { Alias }
    FileSize     : longInt;            { �����p 䠩�� }
    FileTime     : longInt;            { ��� 䠩�� }
    StartTime    : longInt;            { �p��� ��砫� ��p����/�p���� }
    StartSize    : longInt;            { �����p �� Recovery }
    Mode         : char;               { ����� (N)ew, (R)eplace � Re(C)overy }
    BlockSize    : word;               { �����p ����� }
    SyncId       : longInt;            { ����p������� }
    Window       : longInt;            { Transfer Window }
    case LongInt of
    0 : (lastAck : longInt);           { Rx last DataAck }
    1 : (lastSync: longInt);           { RX Last Syncrinize }
  end;

  tRXBuffer      = record
    TempBuff     : pBuffer;            { ��� �p�������� �p���� �� ��ᨫ� }
    TempCur      : word;               { 㪠��⥫� � �⮬ ����p� }
    LastRxByte   : byte;               { ��᫥���� �p����� ����}
  end;

Const
  { Internal }
  hRevision   = 1;
  hRevStamp   = '2b1aab00SF-Mail,v1.06';
  hAutoStart  : string[7] = #13'hydra'#13;
  { Transmit Result }
  hTransNot   = 0;       { ��祣� �� ���������� }
  hTransSnd   = 1;       { �� ��᫠� ����p � ��ᨫ }
  hTransRcv   = 2;       { �뫮 �p���� ��-� }
  hTransRTQ   = 1024;    { ��p�� �p���⮣�, �p� ���p�� �� �⤠�� TQ}
  { Trace Debug }
  Tracechar   : byte = $0;
  Tracebord   : byte = $44;
  TraceSend   : byte = $0E;
  TraceRecv   : byte = $0B;
  TraceCount  : word = 1;

  { States of transmit }

  {Send}
  hstStart    = 0; { ���뫪� Start }
  hstSWait    = 1; { �������� Start }
  hstInit     = 2; { ��᫠�� Init}
  hstInitAck  = 3; { �������� InitAck}
  hstRInit    = 4; { �������� �p���� Init}
  hstNextFile = 5; { ��p�� ��� 䠩��, ���p� �㦭� ��᫠�� }
  hstFInfo    = 6; { ��襫 䠩� }
  hstFInfoAck = 7; { ����� Ack File Info }
  hstData     = 8; { ��諨 ����� }
  hstSkipFile = 9; { ᪨���� 䠩� }
  hstDataAck  =10; { ���⢥p������ �p���� Data }
  hstXWait    =11; { one way transfer }
  hstEOF      =12; { ��᫠�� Eof }
  hstEOFAck   =13; { ����� EofAck }
  hstREnd     =14; { ����� ����砭�� �p���� }
  hstEnd      =15; { ��᫠�� End }
  hstEndAck   =16; { ����� EndAck }
  hstDone     =17; { ��⮢ }
    {Recv}
  hsrInit     = 0; { ����� Init }
  hsrFInfo    = 1; { ����� File Info }
  hsrToData   = 2; { ��᫠�� FinfoAck � �p���⮢����� � �p���� }
  hsrData     = 3; { ����� File Data }
  hsrBadPos   = 4; { Bad Position }
  hsrHdxLink  = 5; { One Way Transfer? }
  hsrRetries  = 6; { ���p�� }
  hsrDone     = 7; { �p��� �����祭 }

  { format of Packets }
  hEndPkt     = 'a';
  hBinPkt     = 'b';
  hHexPkt     = 'c';
  hAscPkt     = 'd';
  hUUEPkt     = 'e';
  { types of Packets }
  hPktStart   = 'A';
  hPktInit    = 'B';
  hPktInitACK = 'C';
  hPktFInfo   = 'D';
  hPktFInfoACK= 'E';
  hPktData    = 'F';
  hPktDataACK = 'G';
  hPktRPos    = 'H';
  hPktEof     = 'I';
  hPktEofACK  = 'J';
  hPktEnd     = 'K';
  hPktIdle    = 'L';
  hPktDevDate = 'M';
  hPktDevDACK = 'N';
  { Options }
  hOpt_XonXoff= $00000001;  (* Escape XON/XOFF                   *)
  hOpt_Telenet= $00000002;  (* Escape CR-'@'-CR (Telenet escape) *)
  hOpt_CtlChrs= $00000004;  (* Escape ASCII 0-31 and 127         *)
  hOpt_HighCtl= $00000008;  (* Escape above 3 with 8th bit too   *)
  hOpt_HighBit= $00000010;  (* Escape ASCII 128-255 + strip high *)
  hOpt_CanBrk = $00000020;  (* Can transmit a break signal       *)
  hOpt_CanAsc = $00000040;  (* Can transmit/handle ASC packets   *)
  hOpt_CanUUE = $00000080;  (* Can transmit/handle UUE packets   *)
  hOpt_CRC32  = $00000100;  (* Packets with CRC-32 allowed       *)
  hOpt_Device = $00000200;  (* DEVICE packets allowed            *)
  hOpt_FPT    = $00000400;  (* Can handle filenames with paths   *)

  hCan_Options= (hOpt_XonXoff or
                 hOpt_Telenet or
                 hOpt_CtlChrs or
                 hOpt_HighCtl or
                 hOpt_HighBit or
                 hOpt_CanBrk or
                 hOpt_CanAsc or
                 hOpt_CanUUE or
                 hOpt_CRC32 {or
                 hOpt_Device});

  hInit_Options=(hOpt_XonXoff or
                 hOpt_Telenet or
                 hOpt_CtlChrs or
                 hOpt_HighCtl or
                 hOpt_HighBit);
  { Some Other }
  hDle        = 24;

  { Errors }
  hErr_Carrier   = 0; { Carrier Lost in space;) }
  hErr_ManyErr   = 1; { Many Errors Transfer aborted }
  hErr_TimeOut   = 2; { TimeOut }
  hErr_BrainDead = 3; { BrainDead }
  hErr_NotFound  = 4; { File not found }
  hErr_NotOpen   = 5; { File can''t open }
  hErr_BadPos    = 6; { Bad Position }
  hErr_FErr      = 7; { File IO Error }
  hErr_SkipNext  = 8; { File skiping for next session }
  hErr_Skip      = 9; { File skiping }
  hErr_Resend    =10; { Resending }
  hErr_Complete  =11; { End of bath }
  hErr_FreeSp    =12; { Not enough free space }
  hErr_Resum     =13; { Resuming file }
  hErr_Replace   =14; { Replacing File }
  hErr_NullFile  =15; { FileSize = 0}

Var
  Use32CRC    : boolean;
  RxFree,     { Fossil Bufers Info }
  RxTotal,
  TxFree,
  TxTotal     : word;

  RX,         { Transmit Buffers }
  TX          : tBufferControl;
  RxTmp       : tRXBuffer;

  RxCur,      { Buffer pointers }
  TxCur       : word;

  TxState,    { States }
  RxState     : byte;
  LastByte    : byte; { Last in Out Buffer }
  TimeOut     : word;

  { Trace Debug }
  TraceFile   : file;
  TraceBuffer : pBuffer;

  { Options }
  TxOptions   : longInt;
  RxOptions   : longInt;
  RXOptStr    : string[19];
  CrcType     : String[2];          { ��� CRC (32/16) }

  {Block data}
  TxGoodBytes  : word;    { ��p����� ��p���쭮 }
  TxGoodNeeded : word;    { H㦭� ��� 㢥��祭�� ����� }
  BrainTimer   : LongInt; { BrainTimer for BrainDead }
  Originator   : boolean; { �� ������? }
  HdxLink      : boolean; { One Way transfer? }
  HSpeed       : longInt; { ���p���� ᮥ������� }
  SkippReq     : byte;    { ���p�� ᪨�� � ��������p� }