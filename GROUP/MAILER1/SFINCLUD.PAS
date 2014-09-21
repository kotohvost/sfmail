Unit SFInclud;
interface
Uses
  CRC_All,
  Dos,
  TPWindow,
  Config;

Const
  PID              = 'Santa Fox Mail System';
  VID              = '1.08g';
  NID              = '0129';
  CID              = '(C)opyright 1994-99, Santa Fox Team';
  SerialNo         : string[13] = 'Noncommercial';

  NoHydra          : array [1..2] of string[5] = ('/HST','/RHST');
  NoHydCount       : byte = 2;
  CanHydra         : boolean = true;
{  AdaptiveAnswer   : boolean = true;
  Adaptive         : boolean = true;}

Const
  LogScreenLen     = 78;
  LogShortLen      = 62;
  ModScreenLen     = 14;
  MaxScrLines      = 100;
  SessionLines     : byte = 5;
  LastConnect_Addr  : String[18] = '0:0/0.0';
  LastConnect_Phone : String[30] = '';
  Connect_Speed    : LongInt = 2400;
  Conn_Speed       : LongInt = 2400;
  LastSess_State   : boolean = true;
  HardRing         : boolean = false;
  LastRNG          : LongInt = 0;
  HardDCD          : boolean = false;
  EMSI_DatFile     : boolean = false;
  ZModemSize       : byte = 2;
  ZModemSupp       : boolean = false;
  FileLogCount     : byte = 0;
  ScreenSave       : boolean = false;
  LampsAES         : boolean = false;
  TimeAES          : boolean = false;
  OldSampleTime    : LongInt = 0;
  ForceAnswerMode  : byte = 0;
  LastRing         : LongInt = 0;
  LastMRefresh     : word = 0;
  AskRescan        : boolean = true;
  SlowSpeed        : boolean = false;
  InvalidSN        : boolean = false;
  BadPwdStr        : String  = '';
  CrashMode        : boolean = false;
  CrashLine        : byte    = 0;
  CrashExit        : boolean = false;
  TermMode         : boolean = false;
  HydraMode        : boolean = false;
  TraceMode        : boolean = false;
  DontInc          : boolean = false;
  IgnoreFreeSpace  : boolean = false;
  Init30Mode       : boolean = false;

Type
  tFileLogBuffer    = Array[1..10] of string;
  pFileLogBuffer    = ^tFileLogBuffer;
  tLogBuffer        = Array[1..MaxScrLines-11] of string;
  pLogBuffer        = ^tLogBuffer;
  tModBuffer        = Array[1..MaxScrLines-11] of string [ModScreenLen];
  pModBuffer        = ^tModBuffer;
  tSesBuffer        = Array[1..MaxScrLines-22] of string;
  pSesBuffer        = ^tSesBuffer;

Var
  LogBuffer        : pLogBuffer;
  ModBuffer        : pModBuffer;
  FileLogBuffer    : pFileLogBuffer;
  SesBuffer        : pSesBuffer;
  LastSession      : String[15];
  LastStatus       : boolean;
  LastConnect      : String[50];
  LastTear         : String[9];
  LampsHandl       : LongInt;
  TimeHandl        : LongInt;
  DiskSpace        : LongInt;
  ILColors         : array [1..2] of byte;
  SampleTime       : longint absolute $0040:$006c;
  WaitCarrierDef   : byte;
  BeginTime        : LongInt;
  RxPath           : PathStr;
  EndingSess       : boolean;

Var
     Log                          : Text;
     hours, minuts, seconds, hund : Word;
     year,  month,  day,     dow  : Word;
     Date_                        : string[9];
     Time_                        : string[8];
     ShortTime                    : string[5];
     PScreen                      : Pointer;
     PWin                         : WindowPtr;
     Lamps                        : integer;
     ColorLamp                    : byte;

Const
     CR       = #13;
     LF       = #10;

Type
  tEMSI_DAT = record
   FingerPrint              : string [4];
   System_Address_List      : array  [1..16] of tAddress;
   AddressCount             : byte;
   Passworded               : boolean;
   Password                 : string [14];
   Link_Codes               : String [11];
   Compatibility_Codes      : string [50];
   Mailer_Product_Code      : string [2];
   Mailer_Name              : string;
   Mailer_Version           : string [50];
   Mailer_Serial_Number     : string  [100];
   System_Name              : string;
   City                     : string;
   System_Op                : string;
   Phone_Number             : string[20];
   BAUD_RATE_Flags          : string;
   RemoteDate               : Str8;
   RemoteTime               : Str8;
  end;

  pEMSI_DAT = ^tEMSI_DAT;
Var
     EMSI_DAT_R : pEMSI_DAT;
     Caller     : boolean;
     pSwap      : function (a:byte;b,c,d :string):integer;

     SaveBreak    : boolean;
     SaveDosBreak : boolean;
     OldExitProc  : pointer;
     Receive      : boolean;

Implementation

end.