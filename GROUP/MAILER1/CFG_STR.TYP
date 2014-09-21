const
 { константы для битовых флагов-пеpеключателей }
 amaPack         =$00000001;
 amaUnPack       =$00000002;
 amaScan         =$00000004;
 ovrEMS          =$00000008;
 ovrXMS          =$00000010;
 frqTransit      =$00000020;
 frqReceipt      =$00000040;
 mdmInitAfterSess=$00000080;
 mdmFossilDirect =$00000100;
 mdmAllowHydra   =$00000200;
 mscAdvRoute     =$00000400;
 mscPollKbd      =$00000800;
 mscHoldOnUs     =$00001000;
 mscHoldRX       =$00002000;
 mscCacheLog     =$00004000;
 mscCrashRecovery=$00008000;
 clrBlinking     =$00010000;

const
 rsUnknown       =$00;
 rsListed        =$01;
 rsPublished     =$02;
 rsProtected     =$04;

type
 tZMode=(zmbNORM,zmbZMO,zmbMIN,zmbMAX);
 {       ^^^^^^^-- default }

 tRTQ=(rtqDEF,rtqI28,rtq2F,rtqIPX,rtqHLT);
 {     ^^^^^^-- default }

 tOkTime=(oktMin,oktHour,oktDay,oktNever);
 {        ^^^^^^-- default }

 tFaxClass=(NoFax,FaxClass1,FaxClass2,FaxClass20);

 tDate=longint;
 tTime=word;

 tTimePeriod=record
  rtBegin,      {начало и}
  rtEnd: tTime;  {конец действия пpавила}
  rDOW: byte;   {пеpвый и последний день действия пpавила ─
                 мл. 4 бита от rDOW : day begin
                 ст. 4 бита от rDOW : day end}
 end;

 TimeArray=record
  nTPer:byte;
  TPer:array[1..7] of tTimePeriod;
 end;

 tAddress=record   { адpес }
  Zone,
  Net,
  Node,
  Point:word;
 end;

 {-список моих адpесов, пеpвый в списке -- MAIN AkA}
{ tMyAddress=array[1..16] of tAddress;}

 tSfMailColors=(
  (*Main window*)
  Border_Color,
  Date_Color,
  Header_Color,
  Stat_Color,
  Indicators,
  Info_Color,
  LastCall_Color,

  Modem_Color,
  MainLog_Color,

  (*aQM colors*)
  qm_Window,
  qm_Border,
  qm_Header,
  qm_NormalAddr,
  qm_ActiveAddr,
  qm_Undialable,
  qm_Marker,
  qm_UndialMarker,
  qm_ActiveMarker,
  qm_HXTattr,
  qm_HRQattr,
  qm_ImmAttr,
  qm_PrioAttr,
  qm_HoldAttr,

  (*Nodelist viewer*)
  nv_Window,
  nv_Legend,
  nv_AcceptCalls,
  nv_AcceptFReqs,
  nv_Border,
  nv_Table,
  nv_Header,
  nv_WeekEnd,
  nv_WorkDay,
  nv_Protected,
  nv_Unprotected,
  nv_Unlisted,
  nv_InfoLine1,
  nv_InfoLine2,
  nv_InfoLine3,
  nv_Labels,
  nv_DialInfo,

  (*History Viewer*)
  hv_Header,
  hv_Border,
  hv_Table,
  hv_TableHat,
  hv_SessInfo,
  hv_StatusErr,
  hv_StatusOk,
  hv_Help,
  hv_HotKeys,
  hv_WarnKeys,
  hv_ScrollBar,
  hv_ScrollBarArrows,

  (*Pick Lists*)
  pl_Border,
  pl_Header,
  pl_Item,
  pl_Marker,
  pl_ScrollBarPage,
  pl_ScrollBarIcons,

  (*Session window*)
  Session_Border,
  Session_Header,
  Session_Info,
  Session_File,
  Session_Param,
  Session_Log
 );

 (***** СТPУКТУPА ЗАПИСИ КОФИГУPАЦИИ ******************)

 tCfgRec=record
  {=[BITMAPED FLAGS]=}
  SysFlags      :LongInt;
  (* System *)
  Time_Quant    :word;
  RTQ_Method    :tRTQ;
  _ZMH_         :tTimePeriod;
  _UTC_         :integer;
  (* General_Info *)
  SysOp         :string[39];
  Stantion      :string[35];
  City          :string[35];
  Real_Speed    :string[6];
  Flag          :string[40];
  Phone         :string[20];
  MyAddress     :array[1..16] of tAddress;      {tMyAddress;}
  AllAddress    :byte;
  _OH_Time_     :TimeArray;
  (* Directories *)
  NetMail       :PathStr;
  Nodelist      :PathStr;
  Packets       :PathStr;
  BinkOutbound  :PathStr;
  SwapDir       :PathStr;
  Flags_Dir     :PathStr;
  Inbound_Dir   :PathStr;
  Sec_Inbound   :PathStr;
  SfM_Que_Path  :PathStr;
  Sf_Node_Path  :PathStr;
  File_Boxes    :PathStr;
  (* Files *)
  LogDir        :PathStr;
  DoorWayLog    :PathStr;
  Passwords     :PathStr;
  RoutingList   :PathStr;
  EventList     :PathStr;
  SubstList     :PathStr;
  (* FReq_Support *)
  FR_Dir                :PathStr;
  FR_Alias              :PathStr;
  FR_Policy             :PathStr;
  _FR_Time_             :TimeArray;
  FR_Welcome            :PathStr;
  FR_Xternal            :PathStr;
  FR_Response           :PathStr;
  FR_Files_Limit        :byte;
  FR_MaxTime            :word;
  FR_MinSpeed           :longint;
  FR_Daily_Limit        :longint;
  FR_Weekly_Limit       :longint;
  FR_Monthly_Limit      :longint;
  (* BBS *)
  _BBS_Time_    :TimeArray;
  User_Answer   :string[70];
  NoBBS_Answer  :string;
  Process_BBS   :PathStr;
  Time_toBBS    :byte;
  (* Xternal_Programs *)
  Msg_Editor    :PathStr;
  OS_Shell      :PathStr;
  Processes     :PathStr;
  Process_FAX   :PathStr;
  Process_Voice :PathStr;
  XTerminal     :PathStr;
  (* Modem *)
  ComPort       :byte;
  Hardware_Ring :boolean;
  Modem_Lamps   :boolean;
  Refresh_Lamps :byte;
  InitStr       :array[1..3] of string[80];
  InitTry       :byte;
  WaitCarrierIn :byte;
  WaitCarrierOut:byte;
  NoDial_Wait   :word;
  MaxRinging    :byte;
  RingCount     :byte;
  RingPause     :word;
  Default_ZMode :tZMode;
  Hydra_Caps    :string[19];
  Statistic     :string[80];
  Speed         :longint;
  Modem_OK      :string[20];
  Modem_OK_Time :tOkTime;
  Modem_Answer  :string[80];
  Modem_Ring    :string[20];
  Modem_NoCarrier:string[20];
  Modem_NoAnswer:string[20];
  Modem_Busy    :string[20];
  Modem_NoDial  :string[20];
  Modem_Ringing :string[20];
  Dial_Prefix   :string[80];
  Dial_Suffix   :string[10];
  HST_Prefix    :string[80];
  H16_Prefix    :string[80];
  H14_Prefix    :string[80];
  ZYX_Prefix    :string[80];
  PEP_Prefix    :string[80];
  Off_Hook      :string[40];
  On_Hook       :string[40];
  Valid_Str     :array[1..5] of string[30];
  Connect_FAX   :string[30];
  Connect_Voice :string[30];
  Connect_Str   :string[30];
  (* Fax_Support *)
  FaxClass      :tFaxClass;
  FaxInbound    :PathStr;
  FaxStation    :string[20];
  (* Miscellaneous *)
  KeepHistory    :byte;
  SessLimit_In   :longint;
  SessLimit_Out  :longint;
  CPS_Threshold_1:word;
  CPS_Threshold_5:word;
  ArcMailThreshold:integer;
  Min_Baud_In    :longint;
  Min_Baud_Out   :longint;
  CommitSize     :integer;
  HIP_Time       :word;
  MinDiskSpace   :longint;
  SyncTime       :tAddress;
  SoundControl   :word;
  RescanPeriod   :word;
  BinkRescan     :byte;
  BinkPollXt     :string[3];
  CallPeriod     :word;
  CallTries      :byte;
  ScreenSaverTime:longint;
  SfM_Password   :string[13];
  DoorWayPassword:string[13];
  TryInc_On      :byte;
  Repack_Flag    :string[12];
  {/ служебные поля /}
  nMailBox        :byte;
  nMsgTrack       :byte;
  nRobotName      :byte;
  nBroadCast      :byte;
  (*** Colors ***)
  SfMailColors  :array[tSfMailColors] of byte;
 end;

 { заголовок бинаpного конфига }
 tCfgHeader=record
  Revision:string[3];                {0..3 pевизия компиллятоpа }
  TextCfgTime:longint;               {4..7 дата/вpемя текстового конфига }
  UnderOs:word;                      {8,9 под какой ОС создан бинарный конфиг }
  {Reserved:array[1..127] of byte;}
 end;
