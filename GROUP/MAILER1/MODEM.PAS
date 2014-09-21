Unit modem;

interface
procedure InitCom;
procedure InitModem;
procedure WriteStatistic;
function AskExit : boolean;
procedure refresh;
procedure KillCD;   { в течении 3 секунд гасим каppиеp }
procedure DTRCheck; { очистка буффеpов и пеpедеpгивание DTR }

Var
  VirtualCD      : boolean;

Const
  DetectExit     : boolean = true;

implementation
Uses TPCRT,
     DOS,
     Overlay,
     aTime,
     TString_,
     SFInclud,
     Config,
     keyb,
     Date,
     RelTQ,
     WriteLog,
     Error,
     EmStruct,
     Fos_Lib;

procedure InitCom;
begin
 ErrorCode:=FullInit(pCfgRec^.ComPort,pCfgRec^.Speed);
 If ErrorCode = TERR_ILLVER then
   ErrorMessage('(?) Invalid fossil revision!',210);
 If ErrorCode <> 0 then
   ErrorMessage('(?) Problem with acces to fossil! ErrorCode: '+Long2Str(ErrorCode),210);
end;


  {---------------------------  Init modem  ----------------------------}
procedure KillCD;
Var
 Timer          : LongInt;
begin
VirtualCD:=false;
 If (GetPortStat and ST_DCD)=0 then exit;
 Timer:=TimeCounter;
 repeat
   PulseDTR(2);
   ChangeDTR(1);
   ReleaseTQ;
 until ((GetPortStat and ST_DCD)=0) or
        (TimeCounter > Timer + 55) or
        (Timer>TimeCounter);
 {  Hеудачная попытка  }
 If (GetPortStat and ST_DCD)<>0 then
   WriteString('~+~+~+~~~ATH|');
end;

procedure DTRCheck;
begin
 ClearRXQueue;
 ClearTXQueue;
 PulseDTR(2);
 ChangeDTR(1);
end;

function GetResponse(Var Response:string):boolean;
begin
  GetResponse:=ReadString(Response)=0;
  Response:=stUpCase(Response);
end;

function OkResponse(Var Response:String):boolean;
begin
  OkResponse:=Pos('OK',Response)<>0;
end;

function ErrorResponse(Var Response:String):boolean;
begin
  ErrorResponse:=Pos('ERR',Response)<>0;
end;

function RingResponse(Var Response:String):boolean;
begin
  RingResponse:=Pos('RING',Response)<>0;
end;

function InitOnce(StrToModem:String):byte;
{Result 0 -- Success
        1 -- Error
        2 -- No Response}
Var
  Try      : byte;
  Response : string;

begin
  Try:=0;
  repeat
    ShowTime;
    if WriteString(StrToModem)<>0 then begin
      Inc(Try);
    end else begin
      while GetResponse(Response) do begin
        ShowTime;
        if OkResponse(Response) then begin
          InitOnce:=0;
          exit;
        end;
        if ErrorResponse(Response) then begin
          InitOnce:=1;
          exit;
        end;
        if RingResponse(Response) then
          ModemLogScreen('RING');
      end;
      Inc(Try);
    end;
  until Try>2;
  InitOnce:=2;
end;

procedure InitModem;
Var
  State    : byte;
  Retry    : byte;
  try      : byte;
  i        : byte;
begin
  KillCD;
  Retry:=1;
  ShowTime;
  if pCfgRec^.Speed<>0 then
    LogWrite(imInitModem,Long2Str(pCfgRec^.Speed),ld_Screen or ld_LastLn)
  else
    LogWrite(imInitModemLock,'',ld_Screen or ld_LastLn);

  repeat
    DTRCheck;
    if Retry=pCfgRec^.InitTry then begin
      if not SaveWindow(1, 1, 80, ScreenHeight, true, PScreen) then begin
        TempClose;
        ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
      end else begin
        TempClose;
        ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
        RestoreWindow(1, 1, 80, ScreenHeight, true, PScreen);
      end;
    end;
    i := 1;
    Try:= 1;
    while (i<4) and (try<3) do begin
     Inc(Try);
     If pCfgRec^.InitStr[i]<>'' then begin
       ShowTime;
       Case InitOnce(pCfgRec^.InitStr[i]) of
        0 : begin
          Inc(i);
          Try:= 0;
        end;
        1 : begin
          ModemLogScreen('ERROR');
          LogWrite(emInitStr,Long2Str(i),ld_Screen);
          Inc(i);
          Try:= 0;
        end;
       end;
     end else Inc(i);
    end;
    if Try<3 then begin
      ModemLogScreen('OK');
      WaitMsg;
      HardRing:=false;
      exit;
    end;
    Inc(Retry);
  until Retry>pCfgRec^.InitTry;
  LogWrite(emNotInit,'',ld_All);
  CloseLogFile;
  ClrScr;
  Halt(211);
end;

{---------------------------  Writing Statistic  ------------------------}

procedure WriteStatistic;
  var ErrorCode  : integer;
      Str        : string;

begin
 ShowTime;
 LogWrite(imWriteStat,'',ld_All);
 Pause(18);
 DTRCheck;

 If WriteString(pCfgRec^.Statistic) <> 0 then begin
   LogWrite(emWriteStat,'',ld_All);
   exit;
 end else begin
   Repeat
    Str:='';
    ErrorCode:=ReadString(Str);
    if ErrorCode = 0 then begin
      If (Pos('OK',Str)<>0) then begin
        ModemLogScreen('OK');
        LogWrite(imStatDone,'',ld_All);
        exit;
      end else begin
        while pos(CR,Str)<>0 do Delete(Str,pos(CR,Str),1);
        while pos(LF,Str)<>0 do Delete(Str,pos(LF,Str),1);
        LogWrite(0,'> '+Str,ld_Clear);
      end;
    end else begin
      LogWrite(emWriteStat,'',ld_All);
      exit;
    end;
   until false;
 end;
end;

  {---------------------------  Refresh modem  ---------------------------}

procedure refresh;
var
  ErrorCode  : integer;
  RetryCount : byte;
  TryCount   : byte;
  Str        : string;
  i          : byte;
begin
 ShowTime;
 DTRCheck;
 KillCD;
 ShowTime;
 TryCount:=0;
 Repeat
   RetryCount:=0;
   Pause(9);
   If WriteString(pCfgRec^.Modem_Ok) <> 0 then begin
     Inc(RetryCount);
     DTRCheck;
   end else begin
     Str:='';
     repeat
       ShowTime;
       ErrorCode:=ReadString(Str);
       ShowTime;
       If (Pos('OK',Str)<>0) then begin
         RetryCount:=10;
         ModemLogScreen('OK');
       end;
       If ErrorCode<0 then begin
         RetryCount:=9;
         DTRCheck;
       end;
     until (Retrycount<>0);
   end;
   If RetryCount=10 then
     TryCount:=6 else
     Inc(TryCount);
 until TryCount>3;

 if RetryCount=4 then
   LogWrite(emNotRefresh,'',ld_All);
end;

function AskExit : boolean;
begin
 AskExit:=false;
 if not DetectExit then exit;
 If (HardRing) and
    (ForceAnswerMode<>2) and
    ((ForceAnswerMode=1) or (MatchTimeArray(pCfgRec^._OH_Time_)))  then
     AskExit:=true;
 If LastKeyPressed>5460 then
    AskExit:=true;
end;

end.
