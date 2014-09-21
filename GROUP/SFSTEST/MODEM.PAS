Unit Modem;
interface

function InitComPort(Com:byte; Speed:Longint):Integer;
function InitFosLib(Com:byte; Speed:Longint; FossilDirect:boolean):Integer;
function CloseComPort:integer;
function CloseFosLib:integer;
function WriteModemCommand(OutString:String):integer;
function WriteStringCR(OutString:String):integer;
function WriteClearStr(OutString:String):integer;

implementation
uses
  Fos_Lib,
  RelTQ,
  TPCrt;

function InitComPort(Com:byte; Speed:Longint):Integer;

function CheckSpeed:integer;
begin
  if Speed = 110 then begin
    CheckSpeed := SP110;
    exit;
  end;
  if Speed = 150 then begin
    CheckSpeed := SP150;
    exit;
  end;
  if Speed = 300 then begin
    CheckSpeed := SP300;
    exit;
  end;
  if Speed = 600 then begin
    CheckSpeed := SP600;
    exit;
  end;
  if Speed = 1200 then begin
    CheckSpeed := SP1200;
    exit;
  end;
  if Speed = 2400 then begin
    CheckSpeed := SP2400;
    exit;
  end;
  if Speed = 4800 then begin
    CheckSpeed := SP4800;
    exit;
  end;
  if Speed = 9600 then begin
    CheckSpeed := SP9600;
    exit;
  end;
  if Speed = 19200 then begin
    CheckSpeed := SP19200;
    exit;
  end;
  if Speed = 38400 then begin
    CheckSpeed := SP38400;
    exit;
  end;
  if Speed = 57600 then begin
    CheckSpeed := SP57600;
    exit;
  end;
  if Speed = 115200 then begin
    CheckSpeed := SP115200;
    exit;
  end;

  { No Speed Define }
  CheckSpeed := SP19200;
  sPortParam.rFlowCtrl:=sPortParam.rFlowCtrl or FL_LOCK;
end;

Var
  TmpScreen : pointer;

begin
  sPortParam.vPortNumber:=Com;
  sPortParam.rFlowCtrl:=FL_HARDW;
  sPortParam.vPortSpeed:=CheckSpeed;
  sPortParam.vPortParity:=NoParity;
  sPortParam.vPortStop:=Stop1;
  sPortParam.vPortBits:=Bit8;
  sPortParam.vTimeOut:=GlobalTimeOut;
  pPortParam:=@sPortParam;

  if not SaveWindow(1, 1, 80, ScreenHeight, true, TmpScreen) then begin
    ErrorCode:=OpenChanel(pPortParam);
  end else begin
    ErrorCode:=OpenChanel(pPortParam);
    RestoreWindow(1, 1, 80, ScreenHeight, true, TmpScreen);
  end;
  WriteLn('Канал откpылся с кодом: ',ErrorCode);

  WriteLn('Канал инициализиpуем, код: ',InitPort);
  ErrorCode:=ChangeDTR(1);
  WriteLn('Попытались поднять DTR, pезультат: ',ErrorCode);
  if ErrorCode<0 then begin
    InitComPort:=ErrorCode;
    Exit;
  end;
  Delay(500);
  if sLibInfo.wDrvType<$10 then
    ErrorCode:=GetAsyncInfo(@sFossInfo)
  else
    ErrorCode:=GetAsyncInfo(@sLLCLInfo);
  WriteLn('Взяли инфу о фоссиле: ', ErrorCode);
  ErrorCode:=ChangeDTR(1);
  Delay(100);
  InitComPort:=0;
end;

function InitFosLib(Com:byte; Speed:Longint; FossilDirect:boolean):Integer;
begin
  pLibinfo:=@sLibInfo;
  sLibInfo.pReleaseSlice:=@ReleaseTQ;
  sLibInfo.bCPUID:=sCPUXID.bXID;
  sLibInfo.wAESStckSize:=4096;
  GetMem(sLibInfo.fpAESStack, sLibInfo.wAESStckSize);
  sLibInfo.wServerStckSize:=0;
  sLibInfo.fpServerStack:=nil;
  sLibInfo.rLibFlags:=STCGen;
  If FossilDirect then sLibInfo.rLibFlags:=sLibInfo.rLibFlags or FDirect;
  ErrorCode:= InitFLib($FF,pLibInfo);
  WriteLn('Библиотека инициализиpовалась с кодом:',ErrorCode);
  if ErrorCode<0 then begin
     InitFosLib:=ErrorCode;
     Exit;
  end;
  InitFosLib:=InitComPort(Com,Speed);
end;

function CloseComPort:integer;
begin
  pChanelInfo:=@sChanelInfo;
  CloseComPort:=CloseChanel($FF,pChanelInfo);
end;

function CloseFosLib:integer;
begin
  CloseFosLib:=CloseComPort;
  EndWork;
end;

function WriteModemCommand(OutString:String):integer;
Var
 i:Byte;
begin
 for i:=1 to Length(OutString) do begin
   case OutString[i] of
     '~' : DoPause(9);
     '''': DoPause(2);
     '^' : ChangeDTR(1);
     'v' : ChangeDTR(0);
     '|' : begin
             ErrorCode:=WriteWaitChar(#13);
             if ErrorCode<0 then begin
                WriteModemCommand:=ErrorCode;
                Exit;
             end;
           end;
   else
          ErrorCode:=WriteWaitChar(OutString[i]);
          if ErrorCode<0 then begin
             WriteModemCommand:=ErrorCode;
             Exit;
          end;
   end;
 end;
 WriteModemCommand:=0;
end;

function WriteStringCR(OutString:String):integer;
Var
 i:byte;
begin
 for i:=1 to Length(OutString) do begin
   case OutString[i] of
    '|' : begin
            ErrorCode:=WriteModemCommand(#13#10);
            if ErrorCode<0 then begin
               WriteStringCR:=ErrorCode;
               Exit;
            end;
          end;
   else
        ErrorCode:=WriteWaitChar(OutString[i]);
        if ErrorCode<0 then begin
           WriteStringCR:=ErrorCode;
           Exit;
        end;
   end;
 end;
 WriteStringCR:=0;
end;

function WriteClearStr(OutString:String):integer;
Var
 i:byte;
begin
 for i:=1 to Length(OutString) do begin
    ErrorCode:=WriteWaitChar(OutString[i]);
    if ErrorCode<0 then begin
       WriteClearStr:=ErrorCode;
       Exit;
    end;
  end;
  WriteClearStr:=0;
end;


end.