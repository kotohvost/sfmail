{$A+,B-,D+,E-,F+,I-,L+,N-,O+,R-,S-,V-}
unit Emsi;
interface

function EmsiHandshake: boolean;
function CheckAddr : byte;
procedure FTN_Session;

implementation
uses
  TPCrt,
  TString_,
  CRC_All,
  Dos,
  SFInclud,
  a002xs,
  Config,
  aTime,
  Date,
  EMStruct,
  EventMan,
  MsgXs,
  keyb,
  KeyRead,
  Modem,
  SF_Snd,
  Show,
  SF_Shell,
  StatView,
  SessCtl,
  Session,
  Swapr,
  RelTQ,
  ProcMan,
  Pwd_Xs,
  WriteLog,
  Fos_Lib,
  UnixTime;

Const
  EMSI_INQ = '**EMSI_INQC816';
  EMSI_REC = '**EMSI_REQA77E';
  EMSI_CLI = '**EMSI_CLIFA8C';
  EMSI_HBT = '**EMSI_HBTEAEE';
  EMSI_ACK = '**EMSI_ACKA490';
  EMSI_NAK = '**EMSI_NAKEEC3';
  EMSI_DAT = '**EMSI_DAT';
  xMailerSearch = 60;
  BBS_Str  : string [2] = #27#27;

Type
  tBuffer = array [0..10240] of byte;
  pBuffer = ^tBuffer;

Type
  tEMSIState =
  (ems_Attempt,
   ems_Waiting,
   ems_GetLen,
   ems_Receiving,
   ems_Build,
   ems_Sending,
   ems_WaitAck,
   ems_Ending);

  tTimerExp =
  (tim_Normal,
   tim_Exper,
   tim_BBSExp,
   tim_ToutExp);

Type
  tEMSIControl = record
    WorkBuff   : pBuffer;
    WorkPtr    : word;
    State      : tEMSIState;
    EMSITimer  : longInt;
    BBSTimer   : longInt;
    ToutTimer  : longInt;
    BBSActive  : boolean;
    EMSI_Name  : string[8];
    EMSIFile   : File;
    EMSI_Try   : byte;
    xMailSrch  : boolean;
    EMSIsrch   : boolean;
    EMSILen    : word;
  end;

Var
  EMSICtl : tEMSIControl;

procedure EMSIInit;
begin
  With EMSICtl do begin
    GetMem (WorkBuff,10240);
    WorkPtr:=0;
    if MatchTimeArray(pCfgRec^._BBS_Time_) then
      BBSTimer:=timeCounter+trunc(pCfgRec^.Time_toBBS*18.2)
    else
      BBSTimer:=timeCounter+1820;
    EMSITimer:=timeCounter+1092;
    ToutTimer:=TimeCounter+182;
    BBSActive:=(EMSITimer>BBSTimer) and (not caller);
    EMSI_Name:=HexWord(minuts)+HexWord(seconds);
    EMSI_Try:=0;
    State:=ems_Attempt;
    xMailsrch:=true;
    EndingSess:=false;
    Pause(9);
  end;
end;

procedure EMSIDone;
begin
  NullTime:=true;
  ShowTime;
  FreeMem(EMSICtl.WorkBuff,10240);
end;

procedure SendFile(FileToSend:String);
Var
  F        : text;
  SomeStr  : string;
begin
  Assign(f,FileToSend);
  Reset(f);
  if IOResult=0 then begin
     repeat
       Readln(f,SomeStr);
       SendStr(SomeStr+#13#10);
     until EoF(f);
     Close(f);
     If IOResult<>0 then ; {Clear IOResult}
  end;
end;

procedure CreateEMSIBuff;
Var
  MyA       : tAddress; { Адpесс для Match AKA }
  k         : Word;
  CRC       : word;

procedure AddField(SomeStr:String);
begin
 Move(SomeStr[1], EMSICtl.WorkBuff^[EMSICtl.WorkPtr], ord(SomeStr[0]));
 Inc(EMSICtl.WorkPtr,ord(SomeStr[0]));
end;

begin
  { Заполняем EMSI_DAT }
  EMSICtl.WorkPtr:=0;
  AddField(EMSI_Dat+'0000{EMSI}{');
  { Адpеса }
  If caller then
    MyA:=NodeEntry.Address else
    MyA:=SessionControl^.pRemoteInfo^.RemoteAddr[1];
  {Считаем подходящий}
  MatchAkA(MyA);
  AddField(Addr2Str(MyA,MyA.Point<>0)+' ');
  for k:=1 to pCfgRec^.AllAddress do begin
    if CompWordStruct(MyA,pCfgRec^.MyAddress[k],
                      SizeOf(tAddress)) <> Equal then
      AddField(Addr2Str(pCfgRec^.MyAddress[k],
                        pCfgRec^.MyAddress[k].Point<>0)+' ');
  end;
  Dec(EMSICtl.WorkPtr);
  {Паpоль}
  If caller then
    EMSI_DAT_R^.Password:=GetPassword(NodeEntry.Address);
  AddField('}{'+EMSI_DAT_R^.Password+'}{8N1');
  {Флаги сессии}
  If Caller then begin
    If DiskSpace < pCfgRec^.MinDiskSpace then
      AddField(',NPU')
    else
      AddField(',PUA');
    If not MatchTimeArray(pCfgRec^._FR_Time_) then
      AddField(',NRQ');
  end else begin
    If DiskSpace < pCfgRec^.MinDiskSpace then
      AddField(',HAT')
    else begin
      If MatchTimePeriod(pCfgRec^._ZMH_) then
        AddField(',HRQ,HXT')
      else begin
        If not MatchTimeArray(pCfgRec^._FR_Time_) then
          AddField(',HRQ');
      end;
    end;
  end;
  AddField('}{');
  {Пpотоколы}
  if Caller then begin
    If CanHydra then
      AddField('HYD,');
    if ZModemSize<>0 then
      AddField('ZAP,');
    AddField('ZMO');
  end else begin
    If CanHydra then
      AddField('HYD')
    else begin
      If ZModemSize <> 0 then
        AddField('ZAP')
      else
        AddField('ZMO');
    end;
  end;
  {Данные о мейлеpе}
  AddField('}{FE}{SF-Mail}{'+VID+NID+'}{'+SerialNo+'}{IDENT}{[');
  {Данные системы}
  AddField(pCfgRec^.Stantion+'][');
  AddField(pCfgRec^.City+'][');
  AddField(pCfgRec^.SysOp+'][');
  AddField(pCfgRec^.Phone+'][');
  AddField(pCfgRec^.Real_Speed+'][');
  {Флаги с заменеными стpоками}
  if slowSpeed then begin
    AddField('*Too slow connection speed*');
  end else begin
    if (length(BadPwdStr) <> 0) and (not caller) then begin
      AddField('*Bad Pwd: '+BadPwdStr);
      BadPwdStr:='';
    end else
      AddField(pCfgRec^.Flag);
  end;
  AddField(']}');
  {Add On'ы}
  if caller then begin
    Case ZModemSize of
      0 : ;
      1 : AddField('{ZMB$}{[MINI]}');
      2 : AddField('{ZMB$}{[NORM]}');
      3 : AddField('{ZMB$}{[MAXI]}');
    end;
  end else
    AddField('{ZMB$}{[NORM]}');
  {Тpафик}
  If Not CrashMode then begin {Пpи кpеше не ставится}
    AddField('{MOH#}{[');
    if caller then begin
      with Que[CurQue]^ do begin
        if MailSize > 60 then
          AddField(lowHex(MailSize + FileSize + NormalBoxSize)) else
          AddField(lowHex(FileSize + NormalBoxSize));
      end;
    end else
      AddField(lowHex(SessionControl^.Traf_Out));
    AddField(']}');
  end;
  {Текущее вpемя}
  AddField('{TRX#}{['+Now2UnixHex+']}');
  k:=EMSICtl.WorkPtr;
  EMSICtl.WorkPtr:=10;
  AddField(HexWord(k-14));
  EMSICtl.WorkPtr:=k;
  CRC:=CRCBlock(0, @EMSICtl.WorkBuff^[2],EMSICtl.WorkPtr-2);
  CRC:=UpdCRC(0,CRC);
  CRC:=UpdCRC(0,CRC);
  AddField(Hexword(CRC)+CR);
  If EMSI_DatFile then begin
    With EMSICtl do begin
      Assign(EMSIFile,EMSI_Name+'.Out');
      Rewrite(EMSIFile,1);
      BlockWrite(EMSIFile,EMSICtl.WorkBuff^[0],EMSICtl.WorkPtr);
      Close(EMSIFile);
    end;
  end;
end;

function UnPackEMSI:boolean;
Var
  CRC      : word;
  Test_CRC : word;
  Count    : word;
  TempId   : String;
  TempStr  : String;

function ReadField: string;
Var
  Res : String;
begin
  ReadField:='';
  with EMSICtl do begin
    Res:='';
    While(WorkBuff^[Count]<> 123) do begin
      Inc(Count);
      if Count>=EMSILen+12 then exit;
    end;
    Inc(Count);
    Repeat
      if WorkBuff^[Count]=92 {'\'} then begin
        if WorkBuff^[Count+1]=92 {'\\'} then begin
         Res:=Res+'\';
         Inc(Count,2);
        end else begin       {'\HH'}
         Res:=Res+chr(TakeFirstHex(char(WorkBuff^[Count+1])+
                                   char(WorkBuff^[Count+2])));
         Inc(Count,3);
        end;
      end else begin
        if WorkBuff^[Count]=125 (*'}'*) then begin
          If WorkBuff^[Count+1]=125 (*'}}'*) then begin
            Res:=Res+'}';
            Inc(Count,2);
          end else begin
            Inc(Count);
            ReadField:=Res;
            exit;
          end;
        end else begin
          Res:=Res+char(WorkBuff^[Count]);
          Inc(Count);
        end;
      end;
      if Count>=EMSILen+12 then exit;
    until false;
  end;
end;

procedure ReadAddress;
Var
  Res : String;
begin
  with EMSICtl,EMSI_Dat_R^ do begin
    Res:='';
    AddressCount:=0;
    While(WorkBuff^[Count]<> 123) do begin
      Inc(Count);
      if Count>=EMSILen+12 then exit;
    end;
    Inc(Count);
    Repeat
      if WorkBuff^[Count]=125 (*'}'*) then begin
        if AddressCount<16 then begin
          Res:=extractWord(1,Res,['@']);
          if xStr2Addr(Res,System_Address_List[AddressCount+1]) then
            Inc(AddressCount);
        end;
        Inc(Count);
        exit;
      end else begin
        if WorkBuff^[Count]=32 (*' '*) then begin
          if AddressCount<16 then begin
            Res:=extractWord(1,Res,['@']);
            if xStr2Addr(Res,System_Address_List[AddressCount+1]) then
              Inc(AddressCount);
          end;
          Inc(Count);
          Res:='';
        end else begin
          Res:=Res+char(WorkBuff^[Count]);
          Inc(Count);
        end;
      end;
    Until false;
  end;
end;

function readAddOnField:string;
Var
  Res : string;
  i   : byte;
begin
  Res:=Copy(TempStr,pos('[',TempStr)+1,pos(']',TempStr)-(pos('[',TempStr)+1));
  Delete(TempStr,1,pos(']',TempStr));
  While (TempStr[1]=']') and (length(TempStr)<>0) do begin
    Delete(TempStr,1,1);
    Res:=Res+']'+Copy(TempStr,1,pos(']',TempStr)-1);
    Delete(TempStr,1,pos(']',TempStr));
  end;
  i:=1;
  While i<=length(Res) do begin
    if Res[i]='\' then begin
      if Res[i+1]='\' then begin
       Delete(Res,i+1,1);
       Inc(i);
      end else begin
       Res[i]:=chr(TakeFirstHex(Res[i+1]+Res[i+2]));
       Delete(Res,i+1,2);
       Inc(i);
      end;
    end else
      Inc(i);
  end;
  readAddOnField:=Res;
end;

procedure ReadIdent;
begin
  With EMSI_Dat_R^,EMSICtl do begin
    System_Name:=readAddOnField;
    City:=readAddOnField;
    System_Op:=readAddOnField;
    Phone_Number:=readAddOnField;
    BAUD_RATE_Flags:=readAddOnField+','+readAddOnField;
  end;
end;

procedure ReadTRX;
Var
  Temp  : String[8];
begin
 Temp:=ReadAddOnField;
 Unix2NormalDate(Temp, EMSI_DAT_R^.RemoteDate, EMSI_DAT_R^.RemoteTime);
 UnPackTime(Unix2DateHex(Temp),RemotDate);
end;

procedure readTRAF;
var
  i : LongInt;
begin
 i:=TakeFirstHex(TempStr);
 SessionControl^.Traf_In := TakeFirstHex(Copy(TempStr,pos(' ',TempStr)+1,255));
 if i>60 then Inc(SessionControl^.Traf_In,i);
end;

begin
  UnPackEMSI:=false;
  Count:=11;
  with EMSICtl do begin
    {Check CRC}
    CRC:=TakeFirstHex(char(WorkBuff^[EMSILen+12])+char(WorkBuff^[EMSILen+13])+
                      char(WorkBuff^[EMSILen+14])+char(WorkBuff^[EMSILen+15]));
    Test_CRC:=CRCBlock(0,WorkBuff,EMSILen+12);
    Test_CRC:=UpdCrc(0, Test_CRC);
    Test_CRC:=UpdCrc(0, Test_CRC);
    if Test_CRC<>CRC then exit;
    { Write EMSI Debug }
    If EMSI_DatFile then begin
      Assign(EMSIFile,EMSI_Name+'.In');
      Rewrite(EMSIFile,1);
      BlockWrite(EMSIFile,WorkBuff^,EMSILen+16);
      Close(EMSIFile);
    end;
    { Decode }
    with EMSI_Dat_R^ do begin
      FingerPrint:=readField;
      ReadAddress;
      Password:=readField;
      Link_Codes:=readField;
      Compatibility_Codes:=readField;
      If Pos('HYD',Compatibility_Codes)=0 then
        CanHydra:=false;
      if Pos('ZAP',Compatibility_Codes)=0 then
        ZModemSize:=0;
      Mailer_Product_Code:=readField;
      Mailer_Name:=readField;
      Mailer_Version:=readField;
      Mailer_Serial_Number:=readField;
      If (Mailer_Name = 'SF-Mail') and
         (Mailer_Serial_Number = SerialNo) and
          CheckSN then
        InvalidSN:=true
      else
        InvalidSN:=false;
      {Addon's}
      System_Name     :='';
      City            :='';
      System_Op       :='';
      Phone_Number    :='';
      BAUD_RATE_Flags :='';
      RemoteDate      :='';
      RemoteTime      :='';
      ZModemSupp      := false;
      SessionControl^.Traf_In  :=0;

      while Count<EMSILen+12 do begin
        TempId:=ReadField;
        TempStr:=ReadField;
        If TempId='IDENT' then begin
          ReadIdent;
        end else begin
          If TempId='TRX#' then begin
            ReadTRX;
          end else begin
            If TempId='MOH#' then begin
              SessionControl^.Traf_In := TakeFirstHex(ReadAddOnField);
            end else begin
              If TempId='TRAF' then begin
                ReadTRAF;
              end else begin
                If TempId='ZMB$' then begin
                  ZModemSupp := true;
                  If not Caller then begin
                    TempStr:=ReadAddOnField;
                    Case TempStr[2] of
                     'I' : ZModemSize:=1;
                     'A' : ZModemSize:=3;
                    else
                      ZModemSize:=2;
                    end; {Case}
                  end; {If caller}
                end; {ZMB$}
              end; {TRAF}
            end; {MOH#}
          end; {TRX#}
        end; {IDENT}
      end; {While}
    end; {With EMSI_Dat_R^}
  end; {With EMSICtl}
  UnPackEMSI:=true;
end;

function CheckKeyb:boolean;
{**********************  Keyboard section  ****************************}
Var
  ch  : char;
begin
  CheckKeyb:=false;
  if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
    if keypressed then begin
       case readkey of
         #0 : if readkey=#35 then begin
            KillCD; exit;
         end;
         #27: begin
            KillCD; exit;
         end;
       end;
    end else
    IfKeyPress:=0;
  end;
  CheckKeyb:=true;
end;

function CheckTimer: tTimerExp;
{**********************  Timer section  ****************************}
begin
  CheckTimer:=tim_Normal;
  ShowTime;
  ShowSessTime;
  with EMSICtl do begin
    if TimeCounter>ToutTimer then begin
      CheckTimer:=tim_ToutExp;
      ToutTimer:=TimeCounter+182;
    end;
    if BBSActive then begin
      ShowScanTime(trunc((BBSTimer-TimeCounter)/18.2));
      if TimeCounter>BBSTimer then
        CheckTimer:=tim_BBSExp;
    end else begin
      ShowScanTime(trunc((EMSITimer-TimeCounter)/18.2));
      if TimeCounter>EMSITimer then
        CheckTimer:=tim_Exper;
    end;
  end;
end;

procedure CopyRight;
Var
  TempInt : Integer;
begin
  if Caller then
    SendStr(CR)
  else begin
    TempInt:=WaitTimeChar(36);
    if TempInt<>Terr_RxEmpty then begin
      EMSICtl.WorkBuff^[0]:=byte(TempInt);
      EMSICtl.WorkPtr:=1;
    end;
    WriteStringCR(CR+CR+PID+'/'+VID+NID+'|');
    WriteStringCR(CID+'|');
    WriteStringCR('|');
    If MatchTimeArray(pCfgRec^._BBS_Time_) then
       WriteStringCR(EMSI_REC+CR+CR+pCfgRec^.User_Answer+'|') else
       WriteStringCR(EMSI_REC+CR+CR+pCfgRec^.NoBBS_Answer+'|');
  end;
end;

function GetBytes:boolean;
Var
  RxFree,     { Fossil Bufers Info }
  RxTotal,
  TxFree,
  TxTotal     : word;
  RxRes       : word;
begin
  GetBytes:=false;
  { Get Buffers Info }
  BuffInfo(RxFree, TxFree, RxTotal, TxTotal);
  If RxTotal>RxFree then begin   { Somthing receive }
    with EMSICtl do begin
      RxRes:=ReadBlock(10240-WorkPtr,@WorkBuff^[WorkPtr]);
      Inc(WorkPtr,RxRes);
      EMSISrch:=true;
    end;
    GetBytes:=true;
    if RxRes<256 then
      ReleaseTQ;
  end;
end;

function SendBuff:boolean;
Var
  RxFree,     { Fossil Bufers Info }
  RxTotal,
  TxFree,
  TxTotal     : word;
  TxRes       : word;
begin
  SendBuff:=false;
  BuffInfo(RxFree, TxFree, RxTotal, TxTotal);
  If TxFree>0 then begin   { Somthing space for sending }
    with EMSICtl do begin
      TxRes:=WriteBlock(WorkPtr,WorkBuff);
      if TxRes<>0 then begin
        Move(WorkBuff^[TxRes],WorkBuff^[0],WorkPtr-TxRes);
        Dec(WorkPtr,TxRes);
      end;
    end;
  end;
  if EMSICtl.WorkPtr=0 then SendBuff:=true;
end;

procedure FlushBuff(leaveBytes: word);
begin
  with EMSICtl do begin
    if WorkPtr>leaveBytes then begin
      move(WorkBuff^[WorkPtr-LeaveBytes],WorkBuff^[0],LeaveBytes);
      WorkPtr:=LeaveBytes;
    end;
  end;
end;

function inBuff(SearchStr:String):word;
begin
  with EMSICtl do
    inBuff:=Search(WorkBuff^,WorkPtr,SearchStr[1],length(SearchStr));
end;

function FoundxMail: boolean;
Var
  i  : byte;
begin
  FoundxMail:=true;
  with EMSICtl do begin
    if not xMailSrch then begin
      FoundxMail:=false;
      exit;
    end;
    If (not caller) then begin
      if (length(pCfgRec^.DoorWayPassword)<>0) and
         (SearchUC(WorkBuff^,WorkPtr,
          pCfgRec^.DoorWayPassword[1],
          length(pCfgRec^.DoorWayPassword))<>$0FFFF) then begin
         LogWrite(imDoorWayIn,'',ld_All);
         PlaySound(TsndHuman);
         TermMode:=true;
         CommandCom;
         TermMode:=false;
         LogWrite(imDoorWayOut,'',ld_All);
         AskRescan:=true;
         exit;
      end;

      if Search(WorkBuff^,WorkPtr,BBS_Str[1],2)<>$0FFFF then begin
        if (length(pCfgRec^.Process_BBS)<>0) and
           (MatchTimeArray(pCfgRec^._BBS_Time_)) then begin
          LogWrite(imHuman,'',ld_All);
          PlaySound(TsndHuman);
          SendFile('banner.txt');
          Swap_Run(PcfgRec^.Process_BBS,true);
        end else
          LogWrite(imHumanReject,'',ld_All);
        NullTime:=true;
        ShowTime;
        exit;
      end;
    end;

    if TotalxMail<>0 then
      for i:=1 to TotalxMail do
        if Search(WorkBuff^,WorkPtr-1,XMailStrings[i]^[1],
                  length(XMailStrings[i]^))<>$0FFFF then begin
          ProcMan_Req4act(procXmail,ProcessInfo[procXmail].procBit,
          XMailStrings[i]^,0,true);
          AskRescan:=true;
          NullTime:=true;
          ShowTime;
          exit;
        end;

    if WorkPtr>xMailerSearch then
      xMailSrch:=false;
  end;
  FoundxMail:=false;
end;

function CheckTry:boolean;
begin
  CheckTry:=true;
  with EMSICtl do begin
    Inc(EMSI_Try);
    If EMSI_Try>6 then begin
      LogWrite(wmFailEMSI,'',ld_All);
      EMSIDone;
      exit;
    end;
  end;
  CheckTry:=false;
end;

function Check_EMSI:boolean;
{**********************  Recv EMSI section  ****************************}
Var
  TmpStr : String;
  i      : byte;
begin
  Check_EMSI:=true;
  SendStr(EMSI_ACK+CR);
  SendStr(EMSI_ACK+CR);
  LogWrite(imStation,EMSI_DAT_R^.System_Name,ld_All);
  LogWrite(imAddress,Addr2Str(EMSI_DAT_R^.System_Address_List[1],
                              EMSI_DAT_R^.System_Address_List[1].Point<>0),ld_All);
  i:=2;
  While i<=EMSI_Dat_R^.AddressCount do begin
    TmpStr:=Addr2Str(EMSI_DAT_R^.System_Address_List[i],
                     EMSI_DAT_R^.System_Address_List[i].Point<>0);
    Inc(i);
    if i<=EMSI_Dat_R^.AddressCount then begin
      TmpStr:=TmpStr+', '+Addr2Str(EMSI_DAT_R^.System_Address_List[i],
                                   EMSI_DAT_R^.System_Address_List[i].Point<>0);
      inc(i);
    end;
    LogWrite(imAKAs,TmpStr,ld_All);
  end;
  LogWrite(imSysOp,EMSI_DAT_R^.System_Op,ld_All);
  LogWrite(imLocation,EMSI_DAT_R^.City,ld_All);
  LogWrite(imPhone,EMSI_DAT_R^.Phone_Number,ld_All);
  LogWrite(imFlags,EMSI_DAT_R^.BAUD_RATE_Flags,ld_All);
  LogWrite(imUsing,EMSI_DAT_R^.Mailer_Name+#3+
                   EMSI_DAT_R^.Mailer_Version+#3+
                   EMSI_DAT_R^.Mailer_Serial_Number,ld_All);

  If EMSI_DAT_R^.RemoteDate<>'' then
     LogWrite(imRemoteDate,EMSI_DAT_R^.RemoteDate+#3+
                           EMSI_DAT_R^.RemoteTime,ld_All);
  If SessionControl^.Traf_In<>0 then
     LogWrite(imTraffIn,vInBestForm(SessionControl^.Traf_In),ld_All);

  case CheckAddr of
       0 : begin
             ShowHistory;
             EMSIDone;
             Check_EMSI:=false;
             exit;
           end;
       1 : begin
             LogWrite(imProtected,'',ld_All);
             InBound_Path:=pCfgRec^.Sec_InBound;
           end;
       2 : begin
             LogWrite(imUnProtected,'',ld_All);
             InBound_Path:=pCfgRec^.Inbound_Dir;
           end;
  end;
  { Syncronize Time }
  with SessionControl^.pRemoteInfo^ do
  for i:=1 to nRemoteAddr do
   if CompWordStruct(pCfgRec^.SyncTime,RemoteAddr[i],
                     SizeOf(tAddress)) =Equal then begin
     LogWrite(imSynchronizing,'',ld_All);
     DontInc:=true;
     with RemotDate do begin
       SetDate(Year,Month,Day);
       SetTime(Hour,Min,Sec,0);
     end;
     NullTime:=true;
     ShowTime;
     StoreSessTime;
     DontInc:=false;
     OldSampleTime:=0;
     BeginTime:=TimeCounter;
     EMSICtl.EMSITimer:=timeCounter+1092;
     EMSICtl.ToutTimer:=TimeCounter+182;
   end;

  {Инициализация send.log }
  With SessionControl^ do begin
     if caller then SessionType := Outgoing else SessionType := Inbound;
     pRemoteInfo^.RemoteName:=EMSI_Dat_R^.System_Name;
     pRemoteInfo^.RemoteSysop:=EMSI_Dat_R^.System_Op;
     pRemoteInfo^.ConnectSpeed:=Connect_Speed;
     EMSI_Flags:=0;
     Emsi_Dat_R^.Link_Codes:=StUpCase(Emsi_Dat_R^.Link_Codes);
     If (Pos('HAT',Emsi_Dat_R^.Link_Codes)<>0) or
        (Pos('NPU',Emsi_Dat_R^.Link_Codes)<>0) then
        EMSI_Flags:=EMSI_Flags or emsiHAT;
     If (Pos('HXT',Emsi_Dat_R^.Link_Codes)<>0) then
        EMSI_Flags:=EMSI_Flags or emsiHXT;
     If (Pos('HRQ',Emsi_Dat_R^.Link_Codes)<>0) then
        EMSI_Flags:=EMSI_Flags or emsiHRQ;
  end;
  BeginSession;
  EndingSess:=true;
  {Инициализация send.log }
end;

function EmsiHandshake: boolean;
Var
  Res1,Res2,Res3 : word;
begin
  EmsiHandshake:=false;
  EMSIInit;
  CopyRight;
  repeat
   { Пpовеpяем таймеp }
   Case CheckTimer of
     tim_BBSExp  : begin
        EMSIDone;
        LogWrite(imRunBBSTout,'',ld_All);
        PlaySound(TSndHuman);
        SendFile('banner.txt');
        Swap_Run(PcfgRec^.Process_BBS,true);
        ShowScanTime(0);
        NullTime:=true;
        ShowTime;
        exit;
       end;
     tim_Exper   : begin
        EMSIDone;
        LogWrite(imEMSITout,'',ld_All);
        exit;
       end;
     tim_ToutExp : begin
        Case EMSICtl.State of
          ems_Attempt : begin
            if Caller then
              SendStr(EMSI_INQ+EMSI_INQ+CR)
            else
              SendStr(EMSI_REC+CR);
            LogWrite(imAttemptEMSI,'',ld_Screen);
          end;
          ems_WaitAck : begin
            if CheckTry then exit;
            FlushBuff(0);
            EMSICtl.State:=ems_Build;
          end;
         end;
       end;
   end;
   { Пpовеpяем клавиатуpу }
   if not CheckKeyb then begin
     LogWrite(wmKeybAbbort,'',ld_All);
     EMSIDone;
     exit;
   end;
   { Пpовеpяем несущую }
   If (GetPortStat And ST_DCD) = 0 then begin
     LogWrite(wmCarrierLost,'',ld_All);
     EMSIDone;
     exit;
   end;
   { Читаем из поpта }
   if (EMSICtl.State<>ems_Sending) and Getbytes then begin
   { Пpовеpяем xMailers }
     if EMSICtl.xMailSrch and FoundxMail then begin
       EMSIDone;
       exit;
     end;
   end else
     ReleaseTQ;

   with EMSICtl do
   case State of
     ems_Attempt : begin
         If EMSISrch then begin { Что-нибудь новое свалилось? }
           if caller then begin { Мы caller? }
             Res1:=inBuff(EMSI_REC);
             if Res1<>$0FFFF then begin { Попался в буффеpе EMSI_REC }
               FlushBuff(0);            { Чистим буффеp }
               xMailSrch:=false;
               BBSActive:=false;
               LogWrite(imEstablishEMSI,'',ld_Screen);
               State:=ems_Build;        { Посылаем EMSI_DAT }
             end else
               EMSISrch:=false;
           end else begin
             Res1:=inBuff(EMSI_INQ+CR);
             if Res1<>$0FFFF then begin
               FlushBuff(WorkPtr-Res1-14);
               SendStr(EMSI_REC+CR);
             end;
             Res2:=inBuff(EMSI_INQ+EMSI_DAT);
             if Res2<>$0FFFF then begin
               FlushBuff(WorkPtr-Res2-14);
             end;
             Res3:=inBuff(EMSI_INQ+EMSI_INQ);
             if Res3<>$0FFFF then begin
               FlushBuff(WorkPtr-Res3-28);
               xMailSrch:=false;
               if CheckTry then exit;
             end;

             if (Res1<>$0FFFF) or (Res2<>$0FFFF) then begin
               LogWrite(imEstablishEMSI,'',ld_Screen);
               xMailSrch:=false;
               BBSActive:=false;
               State:=ems_Waiting;
             end;
             if (Res1=$0FFFF) and
                (Res2=$0FFFF) and
                (Res3=$0FFFF) then
               EMSISrch:=false;
           end;
         end;
       end;
     ems_Build   : begin
         CreateEMSIBuff;
         LogWrite(imSendingEMSI,'',ld_Screen);
         State:=ems_Sending;
       end;
     ems_Sending : begin
         if caller then
           SendStr(EMSI_INQ+CR);
         If SendBuff then begin
           State:=ems_WaitAck;
           FlushBuff(0);
         end else
           ReleaseTQ;
       end;
     ems_Waiting : begin
         If EMSISrch then begin { Что-нибудь свалилось? }
           Res1:=inBuff(EMSI_DAT);
           if Res1=$0FFFF then begin
             FlushBuff(9);
             EMSISrch:=false;
           end else begin
             LogWrite(imReceivingEMSI,'',ld_Screen);
             FlushBuff(WorkPtr-Res1-2);
             State:=ems_GetLen;
           end;
         end;
       end;
     ems_GetLen  : begin
         if WorkPtr>11 then begin
           EMSILen:=TakeFirstHex(chr(WorkBuff^[8])+chr(WorkBuff^[9])+
                                chr(WorkBuff^[10])+chr(WorkBuff^[11]));
           State:=ems_Receiving;
         end;
       end;
     ems_Receiving : begin
         if WorkPtr>15+EMSILen then begin
           if UnPackEMSI then begin
             If not Check_Emsi then exit;
             if Caller then begin
               If NodeEntry.MinBaud_Out>0 then
                 SlowSpeed:=(NodeEntry.MinBaud_Out > Connect_Speed);
               State:=ems_Ending;
             end else begin
               If NodeEntry.MinBaud_In>0 then
                 SlowSpeed:=(NodeEntry.MinBaud_In > Connect_Speed);
               State:=ems_Build;
             end;
           end else begin
             if CheckTry then exit;
             SendStr(EMSI_NAK+CR);
             LogWrite(wmBadCRCEMSI,'',ld_Screen);
             State:=ems_Waiting;
           end;
         end;
       end;
     ems_WaitAck : begin
         If EMSISrch then begin { Что-нибудь свалилось? }
           if inBuff(EMSI_NAK)<>$FFFF then
             if CheckTry then exit;
           if inBuff(EMSI_ACK)<>$FFFF then
             if caller then
               State:=ems_Waiting
             else
               State:=ems_Ending;
           EMSISrch:=false;
         end;
       end;
     ems_Ending  : begin
         if slowspeed then begin
           LogWrite(wmSlowSpeed,'',ld_All);
           EMSIDone;
           AskRescan:=true;
           exit;
         end else begin
           if InvalidSN then begin
             LogWrite(wmInvalidSN,'',ld_Screen);
             EMSIDone;
             exit;
           end else begin
             if caller then begin
               if NodeEntry.SessLimitOut > 0 then
                 LogWrite(imSessBeginLimit,
                          long2Str(NodeEntry.SessLimitOut div 1092),ld_All)
               else
                 LogWrite(imSessBegin,'',ld_All);
             end else begin
               if NodeEntry.SessLimitIn > 0 then
                 LogWrite(imSessBeginLimit,
                          long2Str(NodeEntry.SessLimitIn div 1092),ld_All)
               else
                 LogWrite(imSessBegin,'',ld_All);
             end;
           end;
         end;
         EMSIHandShake:=true;
         EMSIDone;
         exit;
       end;
   end;
  until false;
end;

var
  temppwd    : tpwdCompareStatus;

procedure AddAddress;
var
   CurAddr     : byte;
begin
 with SessionControl^.pRemoteInfo^ do begin
 if nRemoteAddr <> 0 then
  for CurAddr := 1 to nRemoteAddr do begin
    if CompWordStruct(RemoteAddr[CurAddr],
                      RemoteAddr[nRemoteAddr+1],
                      SizeOf(tAddress)) =Equal then exit;
  end;

  tempPwd:=ComparePassword(RemoteAddr[nRemoteAddr+1],EMSI_DAT_R^.Password);
  case TempPwd of
    pcs_NotFound : ;
    pcs_Valid    : EMSI_Dat_R^.passworded:=true;
    pcs_InValid  : begin
      if length(BadPwdStr)=0 then
        BadPwdStr:=Addr2Str(RemoteAddr[nRemoteAddr+1],RemoteAddr[nRemoteAddr+1].Point<>0)
      else
        BadPwdStr:=BadPwdStr+', '+Addr2Str(RemoteAddr[nRemoteAddr+1],RemoteAddr[nRemoteAddr+1].Point<>0);
      LogWrite(wmBadPwd,Addr2Str(RemoteAddr[nRemoteAddr+1],
                                 RemoteAddr[nRemoteAddr+1].Point<>0),ld_All);
      LogWrite(wmBadPwdRecv,EMSI_DAT_R^.Password,ld_All);
      LogWrite(wmBadPwdExpect,GetPassword(RemoteAddr[nRemoteAddr+1]),ld_All);
      exit;
    end;
  end;
  Inc(nRemoteAddr);
 end;
end;

function CheckAddr : byte;
var
   CurAddr,
   AllAddr     : byte;
begin
 EMSI_Dat_R^.passworded:=false;
 BadPwdStr:='';
 with SessionControl^.pRemoteInfo^ do begin
   nRemoteAddr:=0;
   AllAddr:=EMSI_Dat_R^.AddressCount;
   for CurAddr:=1 to AllAddr do begin
     RemoteAddr[nRemoteAddr+1]:=EMSI_Dat_R^.System_Address_List[CurAddr];
     AddAddress;
   end;

   If nRemoteAddr=0 then begin
     LogWrite(wmNoValidAddr,'',ld_All);
     CheckAddr:=0;
     exit;
   end else
     LastConnect_Addr:=Addr2Str(SessionControl^.pRemoteInfo^.RemoteAddr[1],
                                SessionControl^.pRemoteInfo^.RemoteAddr[1].Point<>0);

   if EMSI_Dat_R^.Passworded then
     CheckAddr:=1 else
     CheckAddr:=2;
 end;
end;

procedure FTN_Session;
begin
 if EMSIHandShake then begin
  if CanHydra then
    Hydra_Session
  else
    Mail_Session;
 end else begin
  If EndingSess then begin
    EndSession(true,0,0);
    EndingSess:=false;
  end;
 end;
 ShowHistory;
end;

end.