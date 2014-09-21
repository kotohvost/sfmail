const
 mxPID='Sf-Mail packer';
 mxVID='1.00';
 mxCID='(c) Santa Fox Team, 1996';

{msg}
 MsgHeadLen= $0BE;

{msg flags}
 mfPrivate = $00000001;
 mfCrash   = $00000002;
 mfRecd    = $00000004;
 mfSent    = $00000008;
 mfAttach  = $00000010;
 mfTransit = $00000020;
 mfOrphan  = $00000040;
 mfKillSent= $00000080;
 mfLocal   = $00000100;
 mfHold    = $00000200;
 mfFrq     = $00000800;
 mfRRQ     = $00001000;  {Return Receipt Request}
 mfIRR     = $00002000;  {is a Return Recept}
 mfARQ     = $00004000;  {Audit Trail Request}
 mfUpdFrq  = $00008000;  {Update Freq}
 mfDirect  = $00010000;
 mfHUB     = $00020000;  {HUB routing}
 mfImm     = $00040000;
 mfKFS     = $00080000;
 mfTFS     = $00100000;
 mfLOK     = $00200000;

{ msg error }
 meOk      = 0;
 meRead    = 1;
 meWrite   = 2;
 meOpen    = 3;
 meCorrupt = 4;
 meClose   = 5;

type
 tMsgHeader = record
  { Message header }
  FromName   : String[36]; {.$0 Who from }
  ToName     : String[36]; {24 Who to   }
  Subj       : String[72]; {48 Message subject }
  Date       : String[20]; {90 Creation date (absolete) }
  TimesRead  : Word;       {A4 Number of times read }
  DestNode   : Word;       {A6 Destantion  node }
  OrigNode   : Word;       {A8 Originating node }
  Cost       : Word;       {AA Actual cost for this message }
  OrigNet    : Word;       {AC Originating net }
  DestNet    : Word;       {AE Destination net }
  MsgWritten : longint;    {B0 Creation time }
  MsgArrived : longint;    {B4 Arrival time  }
  Reply      : Word;       {B8 Thread to previous message }
  Attribute  : Word;       {BA Message flags }
  SeeAlso    : Word;       {BC Thread to next message }
  {Всего - 190 байт}
  end;

 tMsgInfo = record
  MsgNum   : LongInt;
  DestAddr : tAddress;
  OrigAddr : tAddress;
  Flags    : LongInt;
  MsgEmpty : boolean;
 end;

 tBuffer = array[0..0] of byte;
 pBuffer = ^tBuffer;

 pRobotName = ^tRobotName;
 tRobotName = record
   Next : pRobotName;
   Name : string [36];
 end;
