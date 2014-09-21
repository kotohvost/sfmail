{$F+,I-}
unit SwapR;
{$L dvexec.obj}
{$L dosexec.obj}
{$L os2exec.obj}
Interface
Const

OS2Title : String[100] = '';

Var
  XTFile : text;

function Swap_Run(prog:string; CanWrite:boolean) : integer;

implementation
 uses WriteLog,
{$IFDEF bVirtual}
      OvlMgBP,
{$ENDIF}
      SFInclud,
      Config,
      Code,
      Flags,
      Fos_Lib,
      Pwd_Xs,
      keyb,
      Modem,
      EventMan,
      EMStruct,
      Script,
      A002xs,
      MsgXs,
      Dos,
      TPCrt,
      TPDos,
      TString_,
      SF_Init,
      FileMan,
      Swaper;

function DosExec(Path, Cmdl :string):integer;far;external;
function DVExec(Mode:byte;var ProgName,Cmdl):integer;external;
function Os2Exec(Mode:word; var ProgName, Cmdl, Title):integer;far;external;

function Swap_Run(prog:string; CanWrite:boolean) : integer;
var
  CurDir       : String;
  Ress         : integer;
  ClCh         : boolean;
  OpCh         : boolean;
  WithOutCom   : boolean;
  DVProg       : boolean;
  Dosshell     : boolean;
  Os2Prog      : boolean;
  Os2BackGr    : boolean;
  DosBoxProg   : boolean;
  OSWindowed   : boolean;
  OnHookMode   : boolean;
  DVPMode      : byte;
  OS2Mode      : word;
  i            : byte;
  ProgMain     : String;
  CommandL     : String;
  TempStr      : String;
  FlagMode     : char;
  FlagWait     : string;
  FlagBlock    : boolean;
  WindCoord    : WindowCoordinates;
  PSScreen     : pointer;
  OvrFile      : file;

procedure ActionFlag;
begin
  Case FlagMode of
   '+' : begin
          if CreateFlag(pCfgRec^.Flags_Dir+TempStr) then
           LogWrite(imCreated,TempStr,ld_All)
          else
           LogWrite(emCantCreate,TempStr,ld_All);
   end;
   '-' : begin
          if DeleteFlag(pCfgRec^.Flags_Dir+TempStr) then
           LogWrite(imKilled,TempStr,ld_All)
          else
           LogWrite(emCantKill,TempStr,ld_All);
   end;
   '!' : begin
          if ExistFile(pCfgRec^.Flags_Dir+TempStr) then begin
           LogWrite(imFlagExist,TempStr,ld_All);
           FlagBlock:=true;
          end else
           LogWrite(imFlagCheck,TempStr,ld_All);
   end;
   '&' : begin
          if ExistFile(pCfgRec^.Flags_Dir+TempStr) then
           LogWrite(imFlagCheck,TempStr,ld_All)
          else begin
           LogWrite(imFlagAbsent,TempStr,ld_All);
           FlagBlock:=true;
          end;
   end;
   '~' : begin
          if CreateFlag(pCfgRec^.Flags_Dir+TempStr) then begin
           LogWrite(imCreated,TempStr,ld_All);
           FlagWait:=TempStr;
          end else
           LogWrite(emCantCreate,TempStr,ld_All);
   end;
  end;
end;

procedure WaitFlag;
begin
  If FlagWait='' then exit;
  LogWrite(imWaitFlag,TempStr,ld_All);
  While ExistFile(pCfgRec^.Flags_Dir+TempStr) do pause(364);
end;

begin
 if length(Prog)=0 then exit;
 IfKeyPress:=10;

 AskRescan:=true;

 Prog:=trim(prog);
 { Скpипты }
 If Prog[1]='#' then begin
   Delete(Prog,1,1);
   if not SaveWindow(1, 1, 80, ScreenHeight, true, PSScreen) then exit;
   Window(1, 2, 80, ScreenHeight-1);
   if DoScript(Prog) then
     Swap_Run:=0 else
     Swap_Run:=1;
   Window(1, 1, 80, ScreenHeight);
   RestoreWindow(1, 1, 80, ScreenHeight, true, PSScreen);
   exit;
 end;

 FlagWait:='';
 FlagBlock:=false;
 If (Prog[1] = '[') and (Pos(']',Prog)<>0) then begin
   Delete(Prog,1,1);
   While (Length(Prog)<>0) and (Prog[1]<>']') do begin
     Case Prog[1] of
      '+',
      '-',
      '!',
      '&',
      '~'  : begin
              FlagMode:=Prog[1];
              Delete(Prog,1,1);
              if not (prog[1] in [' ',',',']']) then begin
                TempStr:=ExtractWord(1,Prog,[' ',',',']']);
                If Length(TempStr)<>0 then begin
                  ActionFlag;
                  Delete(Prog,1,Length(TempStr));
                end;
              end;
      end;
     else
      Delete(Prog,1,1);
     end;
   end;
   Delete(Prog,1,1);
 end;

 If FlagBlock then begin
   LogWrite(imRunBlocked,'',ld_All);
   exit;
 end;

 ClCh      := false;
 OpCh      := false;
 DVProg    := false;
 Dosshell  := false;
 Os2Prog   := false;
 Os2BackGr := false;
 DosBoxProg:= false;
 OSWindowed:= false;
 OnHookMode:= false;

 DVPMode   := 0;

 WithOutCom:= false;
 SwapEnvID := XMS or EMS or EXT or HDD;

 Prog:=trim(prog);
 If (Prog[1] = '{') and (Pos('}',Prog)<>0) then begin
   SwapEnvID:=0;
   for i:=2 to Pos('}',Prog)-1 do begin
     Case Prog[i] of
       'O','o' : OS2Prog := true;       {OS2Prog}
       'W','w' : OSWindowed := true;    {OS2Win}
       'M','m' : DosBoxProg := true;    {DosBox}
       'D','d' : begin                  {DVPSets}
           DVProg:=true;
           DVPMode:=DVPMode or $80;
       end;
       '<'     : begin                  {Hidden }
           DVProg:=true;
           DVPMode:=DVPMode or $03;     {Hidden+}
       end;
       '>'     : begin                  {BackGrn}
           DVProg    :=true;
           DVPMode   :=DVPMode or $01;
           OS2BackGr := true;
       end;
       '#'     : begin                  {Create flag}
           Prog:=Copy(Prog,Pos('}',Prog)+1,byte(Prog[0]));
           If CreateFlag(Prog) then
             Swap_Run:=0 else
             Swap_Run:=1;
           Exit;
       end;
       '!'     : WithOutCom := true;    {Without Command.com}
       '^'     : ClCh :=true;           {Close Chanel}
       '.'     : OnHookMode :=true;     {Go OffHook}
       'V','v' : OpCh :=true;           {ReOpen Chanel}
       'H','h' : SwapEnvID:= HDD or SwapEnvID;  {Swap parametrs}
       'B','b' : SwapEnvID:= EXT or SwapEnvID;
       'E','e' : SwapEnvID:= EMS or SwapEnvID;
       'X','x' : SwapEnvID:= XMS or SwapEnvID;
       'N','n' : Dosshell := true;
     end;
   end;
   if SwapEnvId=0 then
     SwapEnvID:= XMS or EMS or EXT or HDD else
     SwapEnvID:= HDD or SwapEnvID;
   If ClCh then OpCh:=true;

   Prog:=Copy(Prog,Pos('}',Prog)+1,byte(Prog[0])-Pos('{',Prog));
 end;

 Prog:=trim(prog);
 i:=0;
 repeat
   Inc(i);
   if (Prog[i] = '*') and (i<length(Prog)) then
     Case Prog[i+1] of
       'P','p' : begin
                   Delete(Prog,i,2);
                   Insert(Long2Str(pcfgRec^.ComPort+1),Prog,i);
       end;
       'B','b' : begin
                   Delete(Prog,i,2);
                   Insert(Long2Str(Connect_Speed),Prog,i);
       end;
       'C','c' : begin
                   Delete(Prog,i,2);
                   Insert(StUpCase(trim(CfgFileName)),Prog,i);
       end;
       'T','t' : begin
                   Delete(Prog,i,2);
                   Insert(Long2Str(Task),Prog,i);
       end;
       'A','a' : begin
                   Delete(Prog,i,2);
                   Insert(LastConnect_Addr,Prog,i);
       end;
       'S','s' : begin
                   Delete(Prog,i,2);
                   Insert(ReplaceCh(trim(SessionControl^.pRemoteInfo^.RemoteName),' ','_'),
                          Prog,i);
       end;
       'O','o' : begin
                   Delete(Prog,i,2);
                   Insert(ReplaceCh(trim(SessionControl^.pRemoteInfo^.RemoteSysop),' ','_'),
                          Prog,i);
       end;
       'J','j' : begin
                   Delete(Prog,i,2);
                   Insert(ReplaceCh(trim(LastConnect_Phone),' ','_'),Prog,i);
       end;
       'R','r' : begin
                   Delete(Prog,i,2);
                   Insert(pCfgRec^.Fr_Response,Prog,i);
       end;
       'X','x' : begin
                   Delete(Prog,i,2);
                   if CheckPassword(SessionControl^.pRemoteInfo^.RemoteAddr[1]) then
                     Insert('SECURE',Prog,i) else
                     Insert('UNSECURE',Prog,i);
       end;
       'I','i' : begin
                   Delete(Prog,i,2);
                     if SessionControl^.SessionType = Inbound then
                     Insert('INBOUND',Prog,i) else
                     Insert('OUTBOUND',Prog,i);
       end;
       'N','n' : begin
                   Delete(Prog,i,2);
                   if LastSess_State then
                   Insert('1',Prog,i) else
                   Insert('0',Prog,i);
       end;
     end;
 until i > length(Prog)-1;

 Ress:=0;
 if prog<>'' then begin
   If OnHookMode and (pCfgRec^.Off_Hook<>'') then begin
     LogWrite(imGoOffHook,'',ld_Screen);
     If WriteString(pCfgRec^.Off_Hook) <> 0 then begin
       DTRCheck;
       If WriteString(pCfgRec^.Off_Hook) <> 0 then
         LogWrite(wmCantSend,'',ld_Screen);
     end;
     Pause(18);
   end;
   If CanWrite then
     LogWrite(imRun,prog,ld_All);
   If OS2Prog or DosBoxProg then begin
     If OS2Prog then begin
       If OSWindowed then
         OS2Mode := $C000 + SES_OS2Win else
         OS2Mode := $C000 + SES_OS2Full;
     end;
     If DosBoxProg then begin
       If OSWindowed then
         OS2Mode := $C000 + SES_VDMWin else
         OS2Mode := $C000 + SES_VDMFull;
     end;
     If OS2BackGr then
       OS2Mode := OS2Mode + $2000;
     If WithOutCom then begin
       ProgMain:=ExtractWord(1,Prog,[' ',#9]);
       CommandL:=copy(Prog,byte(ProgMain[0])+Pos(ProgMain,Prog),byte(Prog[0]))+#0;
       ProgMain:=ProgMain+#0;
     end else begin
       If DosBoxProg then begin
         ProgMain:=GetEnv('COMSPEC')+#0;
         CommandL:=' /C '+Prog+#0;
       end else begin
         ProgMain:=GetEnv('OS2COMSPEC')+#0;
         CommandL:=' /Q /C '+Prog+#0;
       end;
     end;
     If CanWrite then
       If OS2Prog then
         LogWrite(imOS2OSMode,'',ld_All) else
         LogWrite(imOS2DOSMode,'',ld_All);

     If WithOutCom then begin
       If length(OS2Title)=0 then
                 OS2Title := copy(ProgMain,1,pred(byte(ProgMain[0])))+
                             copy(CommandL,1,pred(byte(CommandL[0])))+' ';
     end else
       If length(OS2Title)=0 then OS2Title := Prog+' ';

     { Пpовеpка флагов }
     { Close Log }
     CloseLogFile;
     { Close Chanal }
     If ClCh then
       TempClose;
     { Пpовеpка закончена }

     OS2Title:=OS2Title+'('+Copy(Time_,1,5)+'  '+Date_+')'#0;
     Swap_Run := OS2Exec(OS2Mode, ProgMain[1], CommandL[1], OS2Title[1]);
     OS2Title := '';
     WaitFlag;

     { Пpовеpка флагов }
     If OpCh then begin
       TempClose;
       ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
     end;

     exit;
   end;

   If not CanWrite then
     if not SaveWindow(1, 1, 80, ScreenHeight, true, PScreen) then exit;

   { Пpовеpка флагов }
   { Close Log }
   CloseLogFile;
   { Close Chanal }
   If ClCh then
     TempClose;
   { Пpовеpка закончена }

   RestoreInt9;
   SusPend;
   GetDir(0,CurDir);
   TextAttr:=$07;
   StoreWindowCoordinates(WindCoord);
   Window(1,1,80,ScreenHeight);
   ClrScr;
   NormalCursor;
   SetBlink(true);
   CreateSemaphore(pCfgRec^.Flags_Dir+'sf-mail.xt');
   Assign(XTFile,pCfgRec^.Flags_Dir+'sf-mail.xt'+long2Str(Task));
   Rewrite(XtFile);
   Write(XtFile,Prog);
   if IOResult<>0 then {clear};
   Close(XTFile);
   if IOResult<>0 then {clear};

   If Dosshell then begin
     If WithOutCom then begin
       ProgMain:=ExtractWord(1,Prog,[' ',#9]);
       CommandL:=copy(Prog,byte(ProgMain[0])+Pos(ProgMain,Prog),byte(Prog[0]));
       Ress:=DosExec(ProgMain,CommandL);
     end else
       Ress:=DosExec(GetEnv('COMSPEC'),' /C '+prog);
   end else
     If DVProg then begin
       ProgMain:=ExtractWord(1,Prog,[' ',#9]);
       CommandL:=trim(copy(Prog,byte(ProgMain[0])+Pos(ProgMain,Prog),
                      byte(Prog[0])));
       DVExec(DVPMode, ProgMain, CommandL);
     end else
       If WithOutCom then begin
         ProgMain:=ExtractWord(1,Prog,[' ',#9]);
         CommandL:=copy(Prog,byte(ProgMain[0])+Pos(ProgMain,Prog),
                           byte(Prog[0]));
{$IFDEF bVirtual}
         OvlNotifyEms(true);
{$ENDIF}
         Ress:=aSwap(ProgMain,CommandL);
{$IFDEF bVirtual}
         OvlNotifyEms(false);
{$ENDIF}
       end else begin
{$IFDEF bVirtual}
         OvlNotifyEms(true);
{$ENDIF}
         Ress:=aSwap(GetEnv('COMSPEC'),' /C '+prog);
{$IFDEF bVirtual}
         OvlNotifyEms(false);
{$ENDIF}
       end;

   WaitFlag;
   
   SetBlink(pCfgRec^.SysFlags and clrBlinking <> 0);
   HiddenCursor;
   ChDir(CurDir);
   RestoreWindowCoordinates(WindCoord);
   EraseSemaphore(pCfgRec^.Flags_Dir+'sf-mail.xt');

   { Пpовеpка флагов }
   If OpCh then begin
     TempClose;
     ReInit(pCfgRec^.ComPort,pCfgRec^.Speed);
   end;

   If not CanWrite then
     RestoreWindow(1, 1, 80, ScreenHeight, true, PScreen)
   else begin
     if Init30Mode then begin
       Init30Lines;
       SetBlink(pCfgRec^.SysFlags and clrBlinking <>0);
       HiddenCursor;
     end;
     ReInitCrt;
     ReDrawScreen;
   end;

   { Open Log }
   OpenLogFile;

   { Пpовеpка закончена }
   if (Resume=TERR_NoLib) then begin
     LogWrite(emFossilOut,'',ld_All);
     halt(210);
   end;
   InitInt9;
   If CanWrite then
     LogWrite(imReturn,long2Str(Ress),ld_All);
 end;

 If not CheckSemaphore(pCfgRec^.Flags_Dir+'sf-mail.wr') then begin
   If CanWrite then begin
     LogWrite(emSemNotFound,'work',ld_All);
     LogWrite(imRunFromExternal,'',ld_All);
   end;
   CreateSemaphore(pCfgRec^.Flags_Dir+'sf-mail.wr');
   RepackMail('all');
 end;
 If OnHookMode and (pCfgRec^.On_Hook<>'') then begin
   LogWrite(imGoOnHook,'',ld_Screen);
   If WriteString(pCfgRec^.On_Hook) <> 0 then begin
     DTRCheck;
     If WriteString(pCfgRec^.On_Hook) <> 0 then
       LogWrite(wmCantSend,'',ld_Screen);
   end;
   Pause(36);
 end;
 Swap_Run:=Ress;
end;

end.
