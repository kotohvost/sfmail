(*
 Santa-Fox Mail configuration file compiler
 (c) Anton the Deinow, 1994-1996
 All rights reserved
*)

{$I-,X+,O+,F+,V-}

UNIT SfM_Cfg;

INTERFACE

uses
 MsgXs,
 aTime,
 CRC_All,
 Tstring_,
 HM,
 Dos,
 RelTQ,
 Config;

type
 tCfgError=(
        ceNotFound,
        ceReadError,
        ceCloseError,
        ceInvalidSection,
        ceInvalidWord,
        ceInvalidArgument,
        ceCreateError,
        ceDisabledReplace,
        ceUnXpected,
        ce2manyIncludes,
        ceInvalidTrackDat,
        ceOddQuotes,
        ceCantInclude
 );

const
 sOddQuotes:string[11]='oddquotes';
 NumTokens:byte=0;
 AtRunTime:boolean=false;       {TRUE если по евенту Set}

{$I Cfg_cpl.def}        {типы аргументов, etc.}
{$I Cfg_kw.typ}         {типы ключевых слов}
{$I Cfg_id.cst}         {идентификатоpы ключевых слов по CRC32}
{$I Cfg_Dat.def}        {значения по умолчанию}

function PrepareLine(s:string; var nW:byte):string;
{-приготавливает строку для парсения}
function CheckLineAndOs(var s:string):boolean;
{-вернет TRUE если строка подходит под текущие Line/OS}

function WhatOs(sOs:string):word;

function ParseSingleWord(var SnglWrd:string):boolean;
{-замещение одного паpаметpа конфига в памяти}

function CompileConfig(CfgFname:PathStr; BinCfgFname:PathStr):boolean;
{-основная пpоцедуpа компилляции конфига}

IMPLEMENTATION

uses
 TpCrt,
 a002xs,
 WriteLog,
 MBman,
 Sf_Track,
 adLang,
 FbMan;

{$I ClrMacx.inc}        {имена цветов в CRC32 и их типы}

const
 MaxInclude=2;
 DefineHdrSiz=SizeOf(pointer)*3;

type
 tQuote=(qNone,qSingle,qDouble);  {line prepearer}

 tCfgInc=array[1..MaxInclude] of text;

 { диpективы #define pасполагаются в виде однонапpавленого списка записей }
 pDefineRec=^tDefineRec;
 tDefineRec=record  {!!!если меняешь стpуктуpу -- поменяй DefineHdrSiz}
   LinkNext:pDefineRec;
   DefineWhat:^string;
   DefineSt:^string;
 end;

var
 DefineListPtr:pDefineRec;

 CurSection:tSection;     {текущая обpабатываемая секция}
 fBinCfg:file;

 fCfg:^tCfgInc;
 CfgLine:array[1..MaxInclude] of word;
 IncLev:byte;

 s,
 kwd:string;
 l_kwd:longint;

 (* вpеменное хpанилище паpаметpов *)
  argInt:integer;
  argAddress:tAddress;
  argTPer:tTimePeriod;
  argTimeArray:TimeArray;
  argTimePeriod:tTimePeriod;
  argLong:longint;
  argWord:word;
  argByte:byte;
  argString:string;
  argSwitch:boolean;

function PrepareLine(s:string; var nW:byte):string;
{-приготавливает строку для парсения}
var
 i:byte;
 inQ:boolean;   {если мы в кавычках}
 sa:string;
 st:string;
 OddQuotes:boolean;

procedure SkipBlanks;
begin
 while (i <=Length(s)) and (s[i] in [' ',^I]) do Inc(i);
end;

function NextToken:boolean;
var
 Q:tQuote;
 w:word;
 DigitAllowed:boolean;

begin
 OddQuotes:=false;
 SkipBlanks;
 if i >Length(s) then begin
  NextToken:=false;
  exit;
 end;
 NextToken:=true;
 inQ:=false;
 st:='';
 Q:=qNone;
 DigitAllowed:=true;
 repeat
  case s[i] of
   ';': if not inQ then begin
         if length(trim(st))<>0 then begin
           if length(sa)<>0 then
             sa:=sa+#0+st
           else
             sa:=st;
         end;
         st:=';';
         exit;
        end else
         st:=st+';';
   '"': if Q =qNone then begin
         Q:=qDouble;
         inQ:=true;
         DigitAllowed:=false;
        end
        else
         if Q <>qDouble then
          st:=st+'"'
         else begin
          if inQ then
           DigitAllowed:=true
          else
           DigitAllowed:=false;
          inQ:=not inQ;
         end;
   #39: if Q =qNone then begin
         Q:=qSingle;
         inQ:=true;
         DigitAllowed:=false;
        end
        else
         if Q <>qSingle then
          st:=st+s[i]
         else begin
          if inQ then
           DigitAllowed:=true
          else
           DigitAllowed:=false;
          inQ:=not inQ;
         end;
   ' ',^I: if inQ then
            st:=st+s[i]
           else
            exit;
   '$': if DigitAllowed then begin
         if Str2word(copy(s,i,3),w) then begin
          st:=st+chr(w);
          Inc(i,2);
         end
         else
          st:=st+'$';
        end
        else
         st:=st+'$';
   '#': if DigitAllowed then begin
         if Str2word(copy(s,i+1,3),w) then begin
          st:=st+chr(w);
          Inc(i,3);
         end
         else
          st:=st+'#';
        end
        else
         st:=st+'#';
  else begin
        st:=st+s[i];
        DigitAllowed:=false;
       end;
  end;
  Inc(i);
  if i >Length(s) then begin
   if inQ then
    OddQuotes:=true;
   exit;
  end;
 until false;
end;

begin
 i:=1;
 inQ:=false;
 sa:='';
 nW:=0;
 s:=Trim(s);
 while NextToken do begin
  if st =';' then begin
   PrepareLine:=sa;
   exit;
  end;
  if Length(sa) <>0 then
   sa:=sa+#0+st
  else
   sa:=st;
  Inc(nW);
 end;
 if OddQuotes then
  PrepareLine:=sOddQuotes  {-special case for brackets mismatch}
 else
  PrepareLine:=sa;           {-line prepeared OK}
end;

function WhatOs(sOs:string):word;
var
 os:tOS;

begin
 WhatOs:=0;
 for os:=osOS2 to osDOS do
   if sOs =OSid[os].osName then begin
     WhatOs:=OSid[os].osBit;
     exit;
   end;
end;

function ConvertEMSIstring(InStr:string):string;
var
 I:byte;
 TempStr:string;

begin
 TempStr:='';
 for i:=1 to Length(InStr) do
 if InStr[i] in [#0..#31,#128..#255] then begin
  if InStr[i]=#0 then
    TempStr:=TempStr+' '
  else
    TempStr:=TempStr+'\'+HexByte(ord(InStr[i]))
 end else begin
  if InStr[i] =']' then TempStr:=TempStr+']';
  TempStr:=TempStr+InStr[i];
 end;

 ConvertEMSIstring:=TempStr;
end;

procedure PipeTo0D0A;
var
 i:byte;

begin
 i:=Pos('|',argString);
 while i <>0 do begin
  argString[i]:=#$0D;
  Insert(#$0A,s,succ(i));
  i:=Pos('|',argString);
 end;
end;

procedure EvalutePipe;
begin
 if (Length(argString) <>0) and (argString[Length(argString)] <>'|') then
  argString:=argString+'|';
end;

procedure ClrMacx2byte;
{-пеpевод символьной стpоки вида FrgrndClr/BckgrndClr
  в его байтовый эквивалент}

function Clr2byte(l:longint):byte;
var
 i:tColorId;

begin
 for i:=clrBlack to clrWhite do
  if ClrMacro[i] =l then begin
   Clr2byte:=ord(i);
   exit;
  end;
 Clr2byte:=0;
end;

begin
 argByte:=(Clr2byte(strCRC32(StLoCase(ExtractWord(2,argString,['/'])))) shl 4) or
           Clr2byte(strCRC32(StLoCase(ExtractWord(1,argString,['/']))));
end;

procedure DisposeDefines;
var
 p:pDefineRec;

begin
 if DefineListPtr <>nil then
  repeat
   p:=DefineListPtr^.LinkNext;
   FreeMem(DefineListPtr^.DefineSt,succ(ord(DefineListPtr^.DefineSt^[0])));
   FreeMem(DefineListPtr^.DefineWhat,succ(ord(DefineListPtr^.DefineWhat^[0])));
   FreeMem(DefineListPtr,DefineHdrSiz);
   DefineListPtr:=p;
  until p =nil;
 DefineListPtr:=nil;
end;

function CurCfgName:PathStr;
var
 w:byte;
 p_s:PathStr;

begin
 w:=0;
 p_s:='';
 while TextRec(fCfg^[IncLev]).Name[w] <>#0 do begin
  p_s:=p_s+TextRec(fCfg^[IncLev]).Name[w];
  Inc(w);
 end;
 CurCfgName:=p_s;
end;

procedure SayError(CfgErr:tCfgError; eTxt:string; ForceHalt:boolean);
{-вызывается пpи невосстановимых ошибках обpаботки}
var
 w:word;
 s:string;

begin
 case CfgErr of
   ceNotFound        : s:=TranslateStr(emCantOpen,eTxt);
   ceReadError       : s:=TranslateStr(emReadError,eTxt);
   ceInvalidSection  : s:=TranslateStr(emCFGinvalidSect,eTxt);
   ceInvalidWord     : s:=TranslateStr(emBadCmd,eTxt);
   ceInvalidArgument : s:=TranslateStr(emCFGinvalidArg,eTxt);
   ceCreateError     : s:=TranslateStr(emCantCreate,eTxt);
   ceUnXpected       : s:=TranslateStr(emCFGunXpected,eTxt);
   ceDisabledReplace : s:=TranslateStr(emCFGcantSet,eTxt);
   ce2manyIncludes   : s:=TranslateStr(emCFG2manyNested,'');
   ceCantInclude     : s:=TranslateStr(emCantOpen,eTxt);
   ceInvalidTrackDat : s:=argString;
   ceOddQuotes       : s:=TranslateStr(emOddQuotes,'');
 end;

 if not AtRunTime then begin
   TextAttr:=$C;
   {if Length(eTxt) <>0 then s:=s+' `'+eTxt+#39;}
   writeln(#13#10'ERROR! Cause: '+s+
           #13#10'          At: line '+Long2str(CfgLine[IncLev])+' of '+CurCfgName+^G#10);
   TextAttr:=$7;
   for w:=1 to 23 do begin
     Sound(93);
     Delay(5);
     NoSound;
     Delay(350);
     if KeyPressed then w:=23;
   end;
   if ForceHalt then begin
     for w:=1 to IncLev do
       if TextRec(fCfg^[w]).Mode <>fmClosed then
         close(fCfg^[w]);
     Dispose(fCfg); {WRITELN('MEM: ',memavail);}
     DisposeDefines;
     halt(255);
   end;
 end
 else
  LogWrite(0,s,ld_All);
end;

procedure CvtRTQ;
const
 sRTQ:array[tRTQ] of string[3]=(
  'def','i28','i2f','ipx','hlt'
 );

var
 i:tRTQ;

begin
 for i:=rtqDEF to rtqHLT do
   if sRTQ[i] =argString then
     pCfgRec^.RTQ_Method:=i;
end;

function ParseCfgWord:tCfgWord;
var
 i1,i2,i:tCfgWord;

begin
 if CurSection =tsNone then begin
   ParseCfgWord:=kwIgnore;
   exit;
 end;

 i1:=SectionInterval[CurSection].R;
 i2:=SectionInterval[CurSection].L;

 ParseCfgWord:=kwInvalid;

 for i:=i1 to i2 do
   if l_kwd =CfgWord[i].W then begin

     ParseCfgWord:=i;

     if (CfgWord[i].V and vLoCase <>0) or
        (CfgWord[i].T in [taSwitch,taZMode,taRTQ]) then
      argString:=StLoCase(argString)
     else
      if (CfgWord[i].V and vUpCase <>0) or
         (CfgWord[i].T in [taHByte,taHWord,taColor]) then
       argString:=StUpCase(argString);

     case CfgWord[i].T of

       taWord: if not Str2word(argString,argWord) then
                SayError(ceInvalidArgument,kwd,false);

       taInt: if not Str2int(argString,argInt) then
                SayError(ceInvalidArgument,kwd,false);

       taLong: if not Str2long(argString,argLong) then
                SayError(ceInvalidArgument,kwd,false);

       taAddress: Str2addr(argString,argAddress);

       taTimePeriod: if not Str2timePeriod(argString,argTPer) then
                       SayError(ceInvalidArgument,kwd,true);

       taTimeArray: if not Str2timeArray(argString,argTimeArray) then
                      SayError(ceInvalidArgument,kwd,true);

       taByte: if not Str2word(argString,argWord) then
                 SayError(ceInvalidArgument,kwd,false)
                else
                 argByte:=byte(argWord);

       taHword: argWord:=Hex2word(argString);

       taHbyte: argByte:=Hex2byte(argString);

       taColor: if Pos('/',argString) =0 then
                  argByte:=Hex2byte(argString)
                else
                  ClrMacx2byte;

       taString: begin
                  if (CfgWord[i].V and vEvalutePipe) <>0 then EvalutePipe;
                  if (CfgWord[i].V and vPipeTo0D0A) <>0 then PipeTo0D0A;
                 end;

       taEMSIstring: argString:=ConvertEMSIstring(argString);

       taPath: argString:=AddBackSlash(argString);

       {taQuote: begin
                  argString:=ExtractWord(1,s,[#39]);
                  if (CfgWord[i].V and vEvalutePipe) <>0 then EvalutePipe;
                  if (CfgWord[i].V and vPipeTo0D0A) <>0 then PipeTo0D0A;
                end;}

       taSwitch: argSwitch:=(argString ='yes');

       taZMode: argByte:=ord(CvtZMode(argString));
       taRTQ: CvtRTQ;
     end; {CASE}

     exit;
   end; {IF нашли слово}
end;

procedure SubstituteDefines;
var
 p:pDefineRec;
 s_:string;
 i:byte;

begin
 if DefineListPtr <>nil then begin
   s_:=StLoCase(argString);
   p:=DefineListPtr;
   repeat
     i:=Pos(p^.DefineWhat^,s_);
     if i <>0 then begin
       Delete(argString,i,Length(p^.DefineWhat^));
       Insert(p^.DefineSt^,argString,i);
       s_:=StLoCase(argString);
     end;
     p:=p^.LinkNext;
   until p =nil;
 end;
end;

procedure SetCfgSection;
var
 i:tSection;

begin
 kwd:=ExtractWord(1,s,['[',']']);
 l_kwd:=strCRC32(StLoCase(kwd));
 for i:=tsSystem to tsColors do
   if aSection[i] =l_kwd then begin
    write(#13'Section "'+kwd+Pad('"',30));
    CurSection:=i;
    exit;
   end;

 CurSection:=tsNone;

{ SayError(ceInvalidSection,kwd,false);}
end;

var
 kwCurType:tCfgWord;

function ParseSingleWord(var SnglWrd:string):boolean;

function WhatSection:tSection;
var
 i,i1,i2:tCfgWord;
 n:tSection;

begin
 for n:=tsSystem to tsColors do begin
   i1:=SectionInterval[n].R;
   i2:=SectionInterval[n].L;
   for i:=i1 to i2 do
     if l_kwd =CfgWord[i].W then begin
       CurSection:=n;
       WhatSection:=n;
       exit;
     end;
 end;

 WhatSection:=tsNone;
end;

begin
 if AtRunTime then DefineListPtr:=nil;

 kwd:=ExtractWord(1,SnglWrd,[#0]);
 l_kwd:=strCRC32(StLoCase(kwd));
 argString:=copy(SnglWrd,succ(Pos(#0,SnglWrd)),255);
 SubstituteDefines;

 if AtRunTime then
  if WhatSection =tsNone then begin
    SayError(ceInvalidWord,kwd,false);
    exit;
  end;

 kwCurType:=ParseCfgWord;

 if AtRunTime and ((CfgWord[kwCurType].V and vAllowReplace) =0) then begin
  SayError(ceDisabledReplace,kwd,false);
  exit;
 end;

 with pCfgRec^ do
     case kwCurType of
 (*System*)
         kwAMAsupport: begin
                        SysFlags:=(SysFlags and (not amaPack) and (not amaUnPack) and
                                  (not amaScan));
                        for argByte:=1 to WordCount(argString,[',']) do begin
                         if StLoCase(ExtractWord(argByte,argString,[','])) ='pack' then
                           SysFlags:=((SysFlags or amaPack) or amaScan);
                         if StLoCase(ExtractWord(argByte,argString,[','])) ='unpack' then
                           SysFlags:=(SysFlags or amaUnPack);
                         if StLoCase(ExtractWord(argByte,argString,[','])) ='scan' then
                           SysFlags:=(SysFlags or amaScan);
                         if StLoCase(ExtractWord(argByte,argString,[','])) ='none' then
                           SysFlags:=(SysFlags and (not amaPack) and (not amaUnPack) and
                                     (not amaScan));
                        end;
                       end;
         kwTime_Quant: Time_Quant:=argWord;
         kwRTQmethod: {do nothing};
         kwOvr_EMS: if argSwitch then
                     SysFlags:=SysFlags or ovrEMS
                    else
                     SysFlags:=SysFlags and (not ovrEMS);
         kwOvr_XMS: if argSwitch then
                     SysFlags:=SysFlags or ovrXMS
                    else
                     SysFlags:=SysFlags and (not ovrXMS);
         kwZMH: _ZMH_:=argTPer;
         kwUTC: _UTC_:=argInt;

 (*General_Info*)
         kwSysOp: SysOp:=argString;
         kwStation: Stantion:=argString;
         kwLocation: City:=argString;
         kwAddress: if AllAddress <>16 then begin
                     Inc(AllAddress);
                     MyAddress[AllAddress]:=argAddress;
                    end;
         kwPhone: Phone:=argString;
         kwReal_Speed: Real_Speed:=argString;
         kwOH_Time: _OH_Time_:=argTimeArray;
         kwFlags: Flag:=argString;

 (*Directories*)
         kwNetMail: NetMail:=argString;
         kwNodelist: Nodelist:=argString;
         kwPackets: Packets:=argString;
         kwBinkOutbound: begin
                           BinkOutbound:=argString;
                           if BinkOutbound[Length(BinkOutbound)] ='\' then
                             Dec(byte(BinkOutbound[0]));
                         end;
         kwSwap: SwapDir:=argString;
         kwFlags_Dir: Flags_Dir:=argString;
         kwSfM_Que_Path: SfM_Que_Path:=argString;
         kwSf_Node_Path: Sf_Node_Path:=argString;
         kwInBound: begin
                      Inbound_Dir:=argString;
                      if Length(Sec_Inbound) =0 then
                        Sec_Inbound:=argString;
                    end;
         kwSecured_Inbound: Sec_Inbound:=argString;
         kwFileBoxes: File_Boxes:=argString;

         kwMailBox: begin
                      argByte:=mbox_RW;
                      s:=StLoCase(ExtractWord(3,argString,[#0]));
                      if Length(s) =2 then
                       if s ='ro' then argByte:=mbox_RO
                       else
                        if s ='wo' then argByte:=mbox_WO
                        else
                         if s <>'rw' then
                           SayError(ceInvalidArgument,
                                    'Mailbox mode ['+s+']',true);
                      AddMailBox(ExtractWord(1,argString,[#0]),
                                 ExtractWord(2,argString,[#0]),argByte);
                      Inc(nMailBox);
                    end;
 (*Files*)
         kwLog: LogDir:=argString;
         kwDoorWayLog: DoorWayLog:=argString;
         kwPasswords: Passwords:=argString;
         kwRoutingList: RoutingList:=argString;
         kwEventsList: EventList:=argString;
         kwSubstList: SubstList:=argString;

 (*FReq_Support*)
         kwFReqDirs: FR_Dir:=argString;
         kwFReqAlias: FR_Alias:=argString;
         kwFReqPolicy: FR_Policy:=argString;
         kwFR_Time: _FR_Time_:=argTimeArray;
         kwFR_Welcome: FR_Welcome:=argString;
         kwFR_MaxTime: FR_MaxTime:=argWord;
         kwFR_MinSpeed: FR_MinSpeed:=argLong;
         kwFR_Transit: if argSwitch then
                        SysFlags:=SysFlags or frqTransit
                       else
                        SysFlags:=SysFlags and (not frqTransit);
         kwFR_Receipt: if argSwitch then
                        SysFlags:=SysFlags or frqReceipt
                       else
                        SysFlags:=SysFlags and (not frqReceipt);
         kwFR_Xternal: FR_Xternal:=argString;
         kwFR_Response: FR_Response:=argString;
         kwFR_Files_Limit: FR_Files_Limit:=argByte;
         kwFR_Daily_Limit: FR_Daily_Limit:=argLong;
         kwFR_Weekly_Limit: FR_Weekly_Limit:=argLong;
         kwFR_Monthly_Limit: FR_Monthly_Limit:=argLong;

 (*BBS*)
         kwBBS_Time: _BBS_Time_:=argTimeArray;
         kwUser_Answer: User_Answer:=argString;
         kwNoBBS_Answer: NoBBS_Answer:=argString;
         kwProcess_BBS: Process_BBS:=argString;
         kwTime_To_BBS: Time_toBBS:=argByte;

 (*Xternal_Programs*)
         kwOS_Shell: OS_Shell:=argString;
         kwMsg_Editor: Msg_Editor:=argString;
         kwProcesses: Processes:=argString;
         kwProcess_FAX: Process_FAX:=argString;
         kwProcess_Voice: Process_Voice:=argString;
         kwTerminal: XTerminal:=argString;

 (*Modem*)
         kwComPort: ComPort:=pred(argByte);
         kwHardware_Ring: Hardware_Ring:=argSwitch;
         kwModem_Lamps: Modem_Lamps:=argSwitch;
         kwRefresh_Lamps: Refresh_Lamps:=argByte;
         kwInitStr1: InitStr[1]:=argString;
         kwInitStr2: InitStr[2]:=argString;
         kwInitStr3: InitStr[3]:=argString;
         kwInitTry: InitTry:=argByte;
         kwWaitCarrierIn: WaitCarrierIn:=argByte;
         kwWaitCarrierOut: WaitCarrierOut:=argByte;
         kwNoDial_Wait: NoDial_Wait:=argWord;
         kwDefault_ZMode: Default_ZMode:=tZMode(argByte);
         kwAllow_Hydra: if argSwitch then
                         SysFlags:=SysFlags or mdmAllowHydra
                        else
                         SysFlags:=SysFlags and (not mdmAllowHydra);
         kwHydra_Caps: Hydra_Caps:=argString;
         kwInitAfterSession: if argSwitch then
                              SysFlags:=SysFlags or mdmInitAfterSess
                             else
                              SysFlags:=SysFlags and (not mdmInitAfterSess);
                             {InitAfterSess:=argSwitch;}
         kwFossilDirect: if argSwitch then
                          SysFlags:=SysFlags or mdmFossilDirect
                         else
                          SysFlags:=SysFlags and (not mdmFossilDirect);
                         {FossMode:=argSwitch;}
         kwStatistic: Statistic:=argString;
         kwSpeed: Speed:=argLong;
         kwModem_OK: Modem_OK:=argString;
         kwModem_OK_Time: case LoCase(argString[1]) of
                           'm': Modem_OK_Time:=oktMin;
                           'h': Modem_OK_Time:=oktHour;
                           'd': Modem_OK_Time:=oktDay;
                          else
                           Modem_OK_Time:=oktNever;
                          end;
         kwModem_Answer: Modem_Answer:=argString;
         kwModem_Ring: Modem_Ring:=argString;
         kwModem_NoCarrier: Modem_NoCarrier:=argString;
         kwModem_NoAnswer: Modem_NoAnswer:=argString;
         kwModem_Busy: Modem_Busy:=argString;
         kwModem_NoDial: Modem_NoDial:=argString;
         kwModem_Ringing: Modem_Ringing:=argString;
         kwMaxRinging: MaxRinging:=argByte;
         kwAnswerRing: RingCount:=argByte;
         kwRingPause: RingPause:=argWord*18;
         kwDial_Prefix: Dial_Prefix:=argString;
         kwDial_Suffix: Dial_Suffix:=argString;
         kwHST_Prefix: HST_Prefix:=argString;
         kwH16_Prefix: H16_Prefix:=argString;
         kwH14_Prefix: H14_Prefix:=argString;
         kwZYX_Prefix: ZYX_Prefix:=argString;
         kwPEP_Prefix: PEP_Prefix:=argString;
         kwOff_Hook: Off_Hook:=argString;
         kwOn_Hook: On_Hook:=argString;
         kwValid: begin
                    argByte:=1;
                    while argByte <6 do begin
                      if Length(Valid_Str[argByte]) =0 then begin
                        Valid_Str[argByte]:=argString;
                        argByte:=99;
                      end;
                      Inc(argByte);
                    end;
                  end;
         kwConnect_FAX: Connect_FAX:=argString;
         kwConnect_Voice: Connect_Voice:=argString;
         kwConnect_Str: Connect_Str:=argString;

 (*Fax_Support*)
         kwFaxClass: if argString ='0' then
                       FaxClass:=NoFax
                     else
                      if argString ='1' then
                        FaxClass:=FaxClass1
                      else
                       if argString ='2' then
                         FaxClass:=FaxClass2
                       else
                        if argString ='2.0' then
                          FaxClass:=FaxClass20
                        else
                          SayError(ceInvalidArgument,kwd,false);
         kwFaxStation: FaxStation:=Pad(argString,20);
         kwFaxInbound: FaxInbound:=argString;

 (*Miscellaneous*)
         kwKeepHistory: KeepHistory:=argByte;
         kwSessLimit_In: SessLimit_In:=argLong*1092;
         kwSessLimit_Out: SessLimit_Out:=argLong*1092;
         kwCPS_Threshold_1: CPS_Threshold_1:=argWord;
         kwCPS_Threshold_5: CPS_Threshold_5:=argWord;
         kwArcMailThreshold: ArcMailThreshold:=argInt;
         kwMin_Baud_In: Min_Baud_In:=argLong;
         kwMin_Baud_Out: Min_Baud_Out:=argLong;
         kwCommitSize: CommitSize:=argInt;
         kwCacheLog: if argSwitch then
                      SysFlags:=SysFlags or mscCacheLog
                     else
                      SysFlags:=SysFlags and (not mscCacheLog);
         kwHold_RX: if argSwitch then
                      SysFlags:=SysFlags or mscHoldRX
                    else
                      SysFlags:=SysFlags and (not mscHoldRX);
         kwHIP_Time: HIP_Time:=argWord;
         kwPoll_Kbd: if argSwitch then SysFlags:=SysFlags or mscPollKbd;
         kwMin_DiskSpace: MinDiskSpace:=argLong*1024;
         kwSoundControl: SoundControl:=argWord;
         kwRescanPeriod: RescanPeriod:=argInt;
         kwBinkRescan: BinkRescan:=pred(argByte);
         kwCallPeriod: CallPeriod:=argWord;
         kwCall_Tries: CallTries:=argByte;
         kwScrSaver_Time: ScreenSaverTime:=argLong*18;
         kwSfM_Password: SfM_Password:='!'+StLoCase(argString);
         kwDoorWayPassword: DoorWayPassword:=StLoCase(argString);
         kwTryInc_Busy: if argSwitch then
                          TryInc_On:=TryInc_On or icBusy
                        else
                          TryInc_On:=TryInc_On and (not icBusy);
         kwTryInc_NoCarrier: if argSwitch then
                               TryInc_On:=TryInc_On or icNoCarrier
                             else
                               TryInc_On:=TryInc_On and (not icNoCarrier);
         kwTryInc_NoDial: if argSwitch then
                            TryInc_On:=TryInc_On or icNoDial
                          else
                            TryInc_On:=TryInc_On and (not icNoDial);
         kwTryInc_NoAnswer: if argSwitch then
                              TryInc_On:=TryInc_On or icNoAnswer
                            else
                              TryInc_On:=TryInc_On and (not icNoAnswer);
         kwMsgTrack: if not AddTrackDat(argString) then
                       SayError(ceInvalidTrackDat,'',true);
         kwRobotName: begin
                       AddRobotName(argString);
                       Inc(nRobotName);
                      end;
         kwBroadCast: begin
                       AddBroadCast(argString);
                       Inc(nBroadCast);
                      end;
         kwAdvRoute: if argSwitch then
                      SysFlags:=SysFlags or mscAdvRoute
                     else
                      SysFlags:=SysFlags and (not mscAdvRoute);
         kwHoldOnUs: if argSwitch then
                      SysFlags:=SysFlags or mscHoldOnUs
                     else
                      SysFlags:=SysFlags and (not mscHoldOnUs);
         kwBinkPollXt: BinkPollXt:=argString;
         kwSyncTime: SyncTime:=argAddress;
         kwRepackFlag: Repack_Flag:=argString;

 (*Colors*)
         kwBlinking: if argSwitch then
                      SysFlags:=SysFlags or clrBlinking
                     else
                      SysFlags:=SysFlags and (not clrBlinking);
                     {Blinking:=argSwitch;}
         kwBorder_Color..kwSession_Log:
            SfMailColors[tSfMailColors(ord(kwCurType)-ord(kwBorder_Color))]:=argByte;
         kwInvalid: if not AtRunTime then SayError(ceInvalidWord,kwd,true);
         kwIgnore: begin end; {do nothing}
     else if not AtRunTime then SayError(ceUnXpected,kwd,false);
     end; {*CASE*}
end;

procedure ProcessDirective;
type
 tDirective=(
   dInclude,
   dDefine,

   dUnknown
 );

const
 Directive:array[dInclude..dDefine] of longint=(
   $D6F6E500, {include}
   $7F3D9CC1  {define}
 );

function WhatDirective(l:longint):tDirective;
var
 i:tDirective;

begin
 for i:=dInclude to dDefine do
   if l =Directive[i] then begin
     WhatDirective:=i;
     exit;
   end;
 WhatDirective:=dUnknown;
end;

var
 p:pDefineRec;
 s_:string;

begin
 case WhatDirective(StrCRC32(StLoCase(kwd))) of
  dInclude: begin
       if IncLev =MaxInclude then
         SayError(ce2manyIncludes,s,true);
       Inc(IncLev);
       CfgLine[IncLev]:=0;
       SubstituteDefines;
       assign(fCfg^[IncLev],argString);
       reset(fCfg^[IncLev]);
       if IoResult <>0 then begin
         SayError(ceCantInclude,CurCfgName,false);
         Dec(IncLev);
       end;
       WRITELN(#13#10'Including '+CurCfgName);
      end;
  dDefine: begin
       s_:=ExtractWord(1,argString,[#0]);  {-replace what}
       s:=ExtractWord(2,argString,[#0]);   {-replace by}
       if DefineListPtr <>nil then begin
         p:=DefineListPtr;
         while p^.LinkNext <>nil do p:=p^.LinkNext;
         GetMem(p^.LinkNext,DefineHdrSiz);
         p:=p^.LinkNext;
       end
       else begin
         GetMem(DefineListPtr,DefineHdrSiz);
         p:=DefineListPtr;
       end;
       p^.LinkNext:=nil;
       GetMem(p^.DefineWhat,succ(Length(s_)));
       GetMem(p^.DefineSt,succ(Length(s)));
       s_:=StLoCase(s_);
       Move(s[0],p^.DefineSt^,succ(Length(s)));
       Move(s_[0],p^.DefineWhat^,succ(Length(s_)));
       {WRITELN('>',p^.DefineWhat^,':',p^.DefineSt^,'<');}
      end;
 end;
end;

function CheckLineAndOs(var s:string):boolean;
var
 i:byte;
 _Os,_Ln,
 OsOk,
 LnOk:boolean;

begin
 CheckLineAndOs:=true;
  if s[1] ='(' then begin
   OsOk:=false;
   LnOk:=false;
   _Os:=false;
   _Ln:=false;
   argString:=StLoCase(ExtractWord(1,s,['(',')']));
   Delete(s,1,Pos(#0,s));
   for i:=1 to WordCount(argString,[',',' ']) do begin
     kwd:=ExtractWord(i,argString,[',',' ']);
     if kwd[1] in ['a'..'z'] then begin
      _Os:=true;
      if (WhatOs(kwd) and mtOSVER) <>0 then
       OsOk:=true;
     end
     else begin
      _Ln:=true;
      if Str2word(kwd,argWord) and (Task =argWord) then
       LnOk:=true;
     end;
   end;
   CheckLineAndOs:=(OsOk or not _Os) and (LnOk or not _Ln);
  end;
end;

(*** MAIN FUNCTION ***)
function CompileConfig(CfgFname:PathStr; BinCfgFname:PathStr):boolean;
{-основная пpоцедуpа компилляции конфига}
var
 done:boolean;
 CfgHeader:tCfgHeader;

begin
 DefineListPtr:=nil;
 FILLCHAR(CfgHeader,SizeOf(tCfgHeader),0);

 IncLev:=1;  {WRITELN('MEM: ',memavail);}
 {New(fCfg);}
 GetMem(fCfg,SizeOf(tCfgInc));
 CompileConfig:=false;  { Assume: Error }

 with CfgHeader do begin
  Revision:=cfgVID;
  UnderOs:=mtOSVER;
 end;
 assign(fBinCfg,BinCfgFname);
 rewrite(fBinCfg,1);
 if IoResult <>0 then SayError(ceCreateError,BinCfgFname,true);

 assign(fCfg^[IncLev],CfgFname);
 reset(fCfg^[IncLev]);
 if IoResult <>0 then SayError(ceNotFound,CfgFname,true);

 GetFtime(fCfg^[IncLev],CfgHeader.TextCfgTime);
 BlockWrite(fBinCfg,CfgHeader,SizeOf(tCfgHeader));

 CurSection:=tsNone;
 CfgLine[IncLev]:=0;

 FillChar(pCfgRec^,SizeOf(tCfgRec),0);

 { значения по умолчанию }
 with pCfgRec^ do begin
  { System }
  SysFlags:=clrBlinking or amaPack or amaUnPack or amaScan or mscCacheLog;
  Time_Quant    :=10;
  with _ZMH_ do begin
    rtBegin:=330;
    rtEnd:=390;
    rDOW:=$60;
  end;
  _UTC_         :=3;

  { General_Info }
  SysOp         :='Dummy Zyz0p';
  Stantion      :='Another Gluck zyztem';
  City          :='Our galaxy, Solar zyztem, Earth';
  Real_Speed    :='300';
  Flag          :='MO,Beer';
  Phone         :='+7 812 Pri-Vate';
  with MyAddress[1] do begin
    Zone:=2; Net:=5030; Node:=999; Point:=999;
  end;
  {AllAddress    :=1;}

  { Directories }
  NetMail       :='.\NETMAIL\';
  Nodelist      :='.\NODELIST\';
  Packets       :='.\PACKETS\';
  SwapDir       :='C:\';
  Flags_Dir     :='.\FLAGS\';
  Inbound_Dir   :='.\INBOUND\';

  { Files }
  LogDir        :='Sf-Mail.log';
  Passwords     :='Password.lst';
  RoutingList   :='Route.ctl';
  EventList     :='Events.ctl';
  SubstList     :='Subst.lst';

  { FReq_Support }
  FR_Dir                :='FReq.Dir';
  FR_Alias              :='Alias.lst';
  FR_Welcome            :='all';
  FR_MinSpeed           :=2400;

  { BBS }

  User_Answer   :='Press ESC twice for BBS..';
  NoBBS_Answer  :='This system is in MailOnly mode now. Please, hangup!';
  Time_toBBS    :=40;

  { Xternal_Programs }
  Processes     :='Process.ctl';

  { Modem }
  Modem_Lamps   :=true;
  Refresh_Lamps :=4;
  InitStr[1]    :='ATZ|';
  InitTry       :=2;
  WaitCarrierIn :=45;
  WaitCarrierOut:=45;
  RingCount     :=1;
  RingPause     :=18*5;
  Statistic     :='';
  Modem_OK      :='AT|';
  Modem_Answer  :='ATA|';
  Modem_Ring    :='RING';
  Modem_NoCarrier:='NO CARRIER';
  Modem_NoAnswer:='NO ANSWER';
  Modem_Busy    :='BUSY';
  Modem_NoDial  :='NO DIAL';
  Modem_Ringing :='RINGING';
  Dial_Prefix   :='ATDP';
  Dial_Suffix   :='|';
  Off_Hook      :='ATH1|';
  On_Hook       :='ATH0|';
  Connect_FAX   :='CONNECT FAX';
  Connect_Str   :='CONNECT';

  { Fax_Support }
  FaxStation   :='SF-MAIL FAX MACHINE ';

  { Miscellaneous }
  KeepHistory     :=3;
  CPS_Threshold_1 :=10;
  CPS_Threshold_5 :=20;
  HIP_Time        :=60;
  MinDiskSpace    :=102400;
  SoundControl    :=$FFFF;
  RescanPeriod    :=60;
  CallPeriod      :=20;
  CallTries       :=255;
  BinkPollXt      :='out';
  {BinkRescan      :=1;}
  TryInc_On       :=icBusy or icNoCarrier or icNoAnswer;
  { Colors }
  Move(DefaultSfMColors,SfMailColors,SizeOf(SfMailColors));
 end; (*End of config defaults*)
 {==========================================}
 done:=false;

 WRITELN(#13#10'Compiling '+CfgFname);

 repeat
  repeat
   readln(fCfg^[IncLev],s);
   Inc(CfgLine[IncLev]);
   s:=PrepareLine(s,NumTokens);
   if s =sOddQuotes then
    SayError(ceOddQuotes,'',true)
   else
    if (Length(s) <>0) and CheckLineAndOs(s) then begin
     if (Length(s) <>0) and (s[1] ='#') then begin
       kwd:=ExtractWord(1,s,[#0]);
       argString:=copy(s,succ(Pos(#0,s)),255);
       ProcessDirective;
     end else begin
      if WordCount(s,[#0])>4 then begin
       WriteLn(#13#10^G'Check All Quotes');
       Delay(10000);
      end else begin
       if Length(s) <>0 then
        if s[1] ='[' then SetCfgSection
         else ParseSingleWord(s);
      end;
     end;
    end;
  until EOF(fCfg^[IncLev]);
  close(fCfg^[IncLev]);
  if IncLev =1 then done:=true
  else Dec(IncLev);
 until done;

 writeln(#13+Pad('',70)+#10);

 BlockWrite(fBinCfg,pCfgRec^,SizeOf(tCfgRec));
 WriteMailBoxes(fBinCfg);
 WriteTrackDat(fBinCfg);
 WriteRobotNames(fBinCfg);
 WriteBroadCast(fBinCfg);

 close(fBinCfg);

 FreeMem(fCfg,SizeOf(tCfgInc));
 DisposeDefines;

 if IoResult =0 then CompileConfig:=true
 else
  SayError(ceCloseError,'',false);

 CfgFtime:=CfgHeader.TextCfgTime;
end;

end.
