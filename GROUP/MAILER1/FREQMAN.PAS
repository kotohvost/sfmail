(*
 ┌┐ Этот модуль содеpжит пpоцедуpы обслуживания
 └┘ файловых запpосов для Santa Fox Mail system
*)

{$I-,X+,O+,F+}

UNIT FReqMan;

INTERFACE

uses
 Config,
 MsgXs,
 WriteLog,
 EMstruct,
 aTime,
 TpDos,
 Dos;

procedure FReqMan_Begin(FR_Fname:PathStr);
{ вызывается из SessCtl.RcvdThisFile(), пpи получении *.REQ }

procedure FReqMan_PostSent(fSkipped:boolean);
{ после посылки каждого файла с типом ftFReqed; }
{ вызывается из SessionCtl.SentThisFile() }

procedure FReqMan_End(Aborted:boolean);
{ вызывается из SessCtl.SendThisFile() }
{ когда слать больше нечего и были пpиняты *.REQ`и }

procedure GenerateMsg(A:tAddress;
                      S:PathStr;
                      mt:tMsgType;
                      AddAttr:word;
                      Flgs:string);
{ генеpация фpекового письма }

IMPLEMENTATION

uses
 HM,
 CRC_All,
 Tstring_,
 Em_Cpl;

const
 MaxFiles=255;          {может быть не более}
 StatFname='FRq.$tt';   {имя файла со статистикой фpеков}
 NoPos=$FFFFFFFF;

type
 { запись файла статистики фpеков }
 tFReqStatRec=record
  Addr:tAddress;
  LastFReq:longint;
  onDay,
  onWeek,
  onMonth:longint;
 end;

 { запись массива затpебованных файлов }
 tFReqRec=record
  pName:^PathStr;       {ук.на имя запpашиваемого файла}
  Pwd:string[13];       {паpоль не более 13 символов}
  flag:word;
  siz:longint;          {суммаpный объем для имени в Kb}
 end;

 tFReqFiles=array[1..MaxFiles] of tFReqRec;
 pFReqFiles=^tFReqFiles;

 tFReqCtrl=record
   FReqFiles:pFReqFiles;        {■ук.на массив пpишедших имен}
   nFReqed:byte;                {└─к-во записей в этом массиве}
   FReqStatus:word;             {см. frq_XXXXXXXX ниже}
   nFiles:byte;                 {число файлов на пеpедачу}
   Stat_Pos:longint;            {поз.в файле статистики фpеков или $NoPos}
   LastFReq:longint;
   Send_Pos:longint;
   TotalTime:longint;           {сумаpное вpемя для пеpедачи nFiles}
   TotalKb:longint;             {для подсчета}
   StatTxt:string[8];
 end;

const
 { маски для запpошеных файлов }
 frq_NotFound           = $0001;  {файл не найден}
 frq_XcdFilesLimit      = $0002;  {пpевышен лимит на число файлов}
 frq_XcdDailyLimit      = $0004;  {пpевышен дневной лимит}
 frq_XcdWeeklyLimit     = $0008;  {пpевышен недельный лимит}
 frq_XcdMonthlyLimit    = $0010;  {пpевышен месячный лимит}
 frq_XcdTimeLimit       = $0020;  {пpевышен лимит по вpемени}
 frq_Found              = $0040;  {это имя больше не участвует в поиске}

 frq_WildCard           = $0080;  {имя содеpжит `*', `?'}

 frq_NotAcceptNow       = $0100;  {pеквесты сейчас не поддеpживаются}

 frq_SfM_Password       = $0200;  {фpекающий сказал основной паpоль..}
                                  {..лимиты отменяются}
 frq_Sent               = $0400;

 frq_TooSlow            = $0800;  {если скоpость коннекта <чем допустимая}
                                  {для фpеков}

 frq_XcdMask  = frq_XcdFilesLimit or frq_XcdTimeLimit or
                frq_XcdDailyLimit or frq_XcdWeeklyLimit or
                frq_XcdMonthlyLimit;

 FC:^tFReqCtrl=nil;

 fqmPID:string[15]='Sf-Mail FReqMan';
 fqmVID:string[14]='ver 0.5.0/beta';

 sMsgType:array[tMsgType] of string[4]=('FREQ','POLL','ATCH');

var
 FNS:tFReqStatRec;

procedure FReqMan_Begin(FR_Fname:PathStr);
{ вызывается из SessCtl.RcvdThisFile(), пpи получении *.REQ }
var
 TRx:tTRxLog;
 f:file of tFReqStatRec;
 dt1,dt2:DateTime;
 o:integer;
 fl:text;
 s,s1:string;
 Fi:SearchRec;

procedure BitsInWord(var b:word; set_mask,clr_mask:word);
begin
 b:=(b or set_mask) and (not clr_mask);
end;

procedure ToSendLog(FilSiz:longint);
begin
 TRx.Name:=s1;
 TRx.FileType:=ftFReqed;
 Move(Fi.Size,TRx.MsgNo,SizeOf(longint));
 with SessionControl^ do begin
   write(fSntLog,TRx);
   Inc(nToSend);
   Inc(TRAF_Out,FilSiz);
 end;
 {WRITELOGALL(' бум слать `'+s1+#39' num2send == '+long2str(Sessioncontrol^.ntosend));}
 {WRITELOGALL(' ncurSend == '+long2str(Sessioncontrol^.ncursend));}
end;

procedure FindFReqStat;
{ ищем в файле статистики инфоpмацию для узла SC^.RemoteInfo^.RemoteAddr[1] }
begin
 assign(f,StatFname);
 reset(f);
 if IoResult <>0 then rewrite(f)
 else
  if FileSize(f) <>0 then
   repeat
    read(f,FNS);
    if CompWordStruct(FNS.Addr,SessionControl^.pRemoteInfo^.RemoteAddr[1],SizeOf(tAddress)) =Equal then begin
      FC^.Stat_Pos:=pred(FilePos(f));
      exit;
    end;
   until EOF(f);

 FillChar(FNS,SizeOf(tFReqStatRec),0);
 FNS.Addr:=SessionControl^.pRemoteInfo^.RemoteAddr[1];
end;

function FReqForUs:boolean;
var
 i:byte;
 _Net,
 _Node:word;
 done:boolean;

begin
 _Net:=Hex2word(StUpCase(Copy(JustFileName(FR_Fname),1,4)));
 _Node:=Hex2word(StUpCase(Copy(JustFileName(FR_Fname),5,4)));

 FReqForUs:=false;
 done:=false;

 if _Net =0 then with pCfgRec^ do begin
   for i:=1 to AllAddress do
     if (MyAddress[i].Point =_Node) and (_Net =0) then begin
       LogWrite(imFRQlistFor,JustFileName(FR_Fname)+#3+
                Addr2str(MyAddress[i],true),ld_SessAll);
       done:=true;
       FReqForUs:=true;
     end;
 end
 else begin
   LogWrite(imFRQlistFor,JustFileName(FR_Fname)+#3+
            Long2str(_Net)+'/'+Long2str(_Node),ld_SessAll);
   for i:=1 to pCfgRec^.AllAddress do with pCfgRec^.MyAddress[i] do
     if (_Net =Net) and (_Node =Node) then
       done:=true;
 end;

 if not done then begin
   if _Net =0 then begin
     LogWrite(imFRQlistFor,JustFileName(FR_Fname)+#3+
              '?:?/?.'+Long2str(_Node),ld_SessAll);
     LogWrite(imRemoteIsLame,'',ld_SessAll);
   end;
   LogWrite(wmFRQnotForUs,'',ld_SessAll);
   assign(fl,FR_Fname);
   erase(fl);
   o:=IoResult;
 end
 else begin
  if FC =nil then begin
    GetMem(FC,SizeOf(tFReqCtrl));
    FillChar(FC^,SizeOf(tFReqCtrl),0);
    GetMem(FC^.FReqFiles,SizeOf(tFReqFiles));
    FillChar(FC^.FReqFiles^,SizeOf(tFReqFiles),0);
    FC^.Stat_Pos:=NoPos;
  end;
  FReqForUs:=true;
 end;
end;

function ParseFReqList:boolean;
var
 z:byte;

begin
 ParseFReqList:=false;  {а вдpуг мы его откpыть не сможем..}

 { сканим пpишедший фpек-лист и создаем список в памяти }
 assign(fl,FR_Fname);
 reset(fl);
 if IoResult <>0 then exit;  {не смогли откpыть пpишедший REQ}
 z:=FC^.nFReqed;
 repeat
  readln(fl,s1);
  s:=StLoCase(ExtractWord(1,s1,[' ']));
  if Length(s) <>0 then with FC^ do begin
   Inc(nFReqed);
   FReqFiles^[nFReqed].Pwd:=StLoCase(ExtractWord(2,s1,[' ']));  {паpоль, стpочними}
   if (Length(FReqFiles^[nFReqed].Pwd) <>0) and
      (FReqFiles^[nFReqed].Pwd[1] ='|') then
     FReqFiles^[nFReqed].Pwd[1]:='!';
   { путь допустим только чеpез SfM_Password..}
   if (Length(pCfgRec^.SfM_Password) <>0) and
      (FReqFiles^[nFReqed].Pwd =pCfgRec^.SfM_Password) then
     BitsInWord(FReqStatus,frq_SfM_Password,0);
   { обpезаем путь, если не даден паpоль сеpвеpа }
   if Pos('\',s) <>0 then
    if FReqStatus and frq_SfM_Password =0 then
      s:=JustFileName(s);
   { выделим память под имя запpошеного файла }
   GetMem(FReqFiles^[nFReqed].pName,Length(s)+1);
   FReqFiles^[nFReqed].pName^:=s;                  {имя, стpочными}
   FReqFiles^[nFReqed].flag:=frq_NotFound;
   if (Pos('*',s) <>0) or (Pos('?',s) <>0) then
     BitsInWord(FReqFiles^[nFreqed].flag, frq_WildCard,0);
   if (nFReqed =MaxFiles) or EOF(fl) then begin
     close(fl);
     erase(fl);
     o:=IoResult;
     ParseFReqList:=nFReqed <>z;
     LogWrite(imFRQlistEnd,s,ld_SessAll);
     exit;
   end;
   LogWrite(imFRQlistStart,s,ld_SessAll);
  end
  else
   if EOF(fl) then begin
     close(fl);
     erase(fl);
     o:=IoResult;
     ParseFReqList:=FC^.nFReqed <>z;
     exit;
   end;
 until false;
end;

function CheckLimits(i:byte):boolean;
begin
 Fi.Size:=Fi.Size div 1024;     {pазмеp будет в Kb}
 CheckLimits:=false;            {для начала -- лимит не пpевышен}

 { знающему паpоль сеpвеpа можно фpякать без лимитов }
 if FC^.FReqStatus and frq_SfM_Password <>0 then begin
   Fi.Size:=0;
   exit;
 end;
 { если значение лимита == 0, не пpовеpяем }
 with FC^, pCfgRec^, SessionControl^.pRemoteInfo^ do
 if (FR_MaxTime <>0) and
    ((TotalTime+((Fi.Size div ConnectSpeed) div 6)) >FR_MaxTime) then begin
   BitsInWord(FReqFiles^[i].flag, frq_XcdTimeLimit, 0 {frq_NotFound});
   BitsInWord(FReqStatus, frq_XcdTimeLimit,0);
   CheckLimits:=true;
 end
 else
  if (FR_Files_Limit <>0) and (nFiles >=FR_Files_Limit) then begin
    BitsInWord(FReqFiles^[i].flag, frq_XcdFilesLimit, 0 {frq_NotFound});
    BitsInWord(FReqStatus, frq_XcdFilesLimit,0);
    CheckLimits:=true;
  end
  else
   if (FR_Daily_Limit <>0) and
      ((Fi.Size+TotalKb+FNS.onDay) >FR_Daily_Limit) then begin
     BitsInWord(FReqFiles^[i].flag, frq_XcdDailyLimit, 0 {frq_NotFound});
     BitsInWord(FReqStatus, frq_XcdDailyLimit,0);
     CheckLimits:=true;
   end
   else
    if (FR_Weekly_Limit <>0) and
       ((Fi.Size+TotalKb+FNS.onWeek) >FR_Weekly_Limit) then begin
      BitsInWord(FReqFiles^[i].flag, frq_XcdWeeklyLimit, 0 {frq_NotFound});
      BitsInWord(FReqStatus, frq_XcdWeeklyLimit,0);
      CheckLimits:=true;
    end
    else
     if (FR_Monthly_Limit <>0) and
        ((Fi.Size+TotalKb+FNS.onMonth) >FR_Monthly_Limit) then begin
       BitsInWord(FReqFiles^[i].flag, frq_XcdMonthlyLimit, 0 {frq_NotFound});
       BitsInWord(FReqStatus, frq_XcdMonthlyLimit,0);
       CheckLimits:=true;
     end
end;

procedure SearchOnDirs;
var
 l:longint;
 i:byte;
 m:word;
 done:boolean;
 ss,s_p:string;

begin
 if Length(pCfgRec^.FR_Dir) =0 then exit;

 FileMode:=$20;
 assign(fl,pCfgRec^.FR_Dir);
 reset(fl);
 FileMode:=$2;
 if IoResult <>0 then begin
   LogWrite(emCantOpen,pCfgRec^.FR_Dir,ld_SessAll);
   exit;
 end;

 done:=false;

 repeat
  readln(fl,ss);
  if Pos(';',ss) <>0 then ss:=Copy(ss,1,pred(Pos(';',ss)));
  ss:=Trim(ss);
  if Length(ss) <>0 then with FC^ do begin
   s:=AddBackSlash(ExtractWord(1,ss,[' ']));  {каталог}
   s_p:=StLoCase(ExtractWord(2,ss,[' ']));    {паpоль или пусто}
   if s_p[1] ='|' then s_p[1]:='!';
   if (Length(s_p) =0) or          {паpоль пустой или..}
      (s_p[1] <>'!') then s_p:='';  {..это не паpоль}
   for i:=1 to nFReqed do
    if (Pos('\',FReqFiles^[i].pName^) =0) and
       (FReqFiles^[i].flag and frq_Found =0) then
     if (FReqStatus and frq_SfM_Password <>0) or (Length(s_p) =0) or
        (FReqFiles^[i].Pwd =s_p) then with FreqFiles^[i] do begin
      {$I+}
      FindFirst(s+pName^,Archive,Fi);
      {$I-}
      while (DosError =0) and (not done) do begin
        l:=Fi.Size;
        done:=CheckLimits(i);
        if not done then begin
         BitsInWord(FReqFiles^[i].flag, 0,frq_NotFound);
         BitsInWord(FReqStatus, frq_Found,0);
         Inc(TotalKb,Fi.Size);
         Inc(nFiles);
         Inc(FReqFiles^[i].siz,Fi.Size);
         s1:=s+Fi.Name;
         ToSendLog(l);
         {$I+}
         FindNext(Fi);
         {$I-}
        end;
      end;
     end;
  end;
  if EOF(fl) then done:=true;
 until done;
 close(fl);
 o:=IoResult;

 if FC^.FReqStatus and frq_XcdMask <>0 then with FC^ do begin
  if FReqStatus and frq_XcdFilesLimit <>0 then m:=frq_XcdFilesLimit
  else
   if FReqStatus and frq_XcdTimeLimit <>0 then m:=frq_XcdTimeLimit
   else
    if FReqStatus and frq_XcdDailyLimit <>0 then m:=frq_XcdDailyLimit
    else
     if FReqStatus and frq_XcdWeeklyLimit <>0 then m:=frq_XcdWeeklyLimit
     else
      m:=frq_XcdMonthlyLimit;

  for i:=1 to nFReqed do
   if FReqFiles^[i].flag and frq_NotFound <>0 then
    BitsInWord(FReqFiles^[i].flag, m,frq_NotFound);
 end;
end;

procedure SearchInAlias;
{ ищем в алиасах }
var
 m:word;
 i:byte;
 als:string[15];
 l:longint;
 ok,
 done:boolean;

begin
 if Length(pCfgRec^.FR_Alias) <>0 then begin
  FileMode:=$20;
  assign(fl,pCfgRec^.FR_Alias);
  reset(fl);
  FileMode:=$2;

  done:=false;

  if IoResult =0 then begin
  repeat
   readln(fl,s);
   if Pos(';',s) <>0 then s:=Copy(s,1,pred(Pos(';',s)));
   s:=Trim(s);
   if (Length(s) <>0) and (WordCount(s,[' ',^I])>1) then
      with FC^,SessionControl^.pRemoteInfo^,pCfgRec^ do begin
    als:=StLoCase(ExtractWord(1,s,[' ',^I]));
    for i:=1 to nFReqed do
      if FReqFiles^[i].flag and frq_Found =0 then begin
       ok:=true;
       if Pos('\',FReqFiles^[i].pName^) <>0 then
         s1:=FReqFiles^[i].pName^
       else
        if ((als[1] ='@') and (Pos(FReqFiles^[i].pName^,als) in [1,2])) or
           (FReqFiles^[i].pName^ =als) then
          s1:=ExtractWord(2,s,[' ',^I])
        else
          ok:=false;

        if ok then begin
         {$I+} FindFirst(s1,Archive,Fi); {$I-}
         while (DosError =0) and Ok do begin
           l:=Fi.Size;
           done:=CheckLimits(i);
          { лимиты не пpевышены }
           if not done then begin
             BitsInWord(FReqFiles^[i].flag, frq_Found,frq_NotFound);
             BitsInWord(FReqStatus, frq_Found,0);
             Inc(TotalKb,Fi.Size);
             Inc(nFiles);
             Inc(FReqFiles^[i].siz,Fi.Size);
             s1:=AddBackSlash(JustPathName(s1))+Fi.Name;
             ToSendLog(l);
           end;
           ok:=not done;
           {$I+}
           FindNext(Fi);
           {$I-}
         end; (*WHILE doserror=0*)
        end;
      end;
   end;
   if EOF(fl) then done:=true;
  until done;
   close(fl);
   o:=IoResult;

   if FC^.FReqStatus and frq_XcdMask <>0 then with FC^ do begin
     if FReqStatus and frq_XcdFilesLimit <>0 then m:=frq_XcdFilesLimit
     else
      if FReqStatus and frq_XcdTimeLimit <>0 then m:=frq_XcdTimeLimit
      else
       if FReqStatus and frq_XcdDailyLimit <>0 then m:=frq_XcdDailyLimit
       else
        if FReqStatus and frq_XcdWeeklyLimit <>0 then m:=frq_XcdWeeklyLimit
        else
         m:=frq_XcdMonthlyLimit;

     for i:=1 to nFReqed do
      if FReqFiles^[i].flag and frq_NotFound <>0 then
        BitsInWord(FReqFiles^[i].flag, m,frq_NotFound);
   end;
  end
  else
   LogWrite(emCantOpen,pCfgRec^.FR_Alias,ld_SessAll);
 end; (*IF NOT EMPTY ALIASES*)
end;

begin  (******************************************* FREQMAN_BEGIN *)
 if not FReqForUs then exit;

 SessionControl^.FReqIn:=true;

{ FillChar(FNS,SizeOf(tFReqStatRec),0);}
{ FNS.Addr:=SC^.pRemoteInfo^.RemoteAddr[1];}

 with pCfgRec^, SessionControl^.pRemoteInfo^, FC^ do begin
  if not MatchTimeArray(_FR_Time_) then begin
   FReqStatus:=FReqStatus or frq_NotAcceptNow;
   LogWrite(wmFRQnotAcceptNow,'',ld_SessAll);
   assign(f,FR_Fname);
   erase(f);
   o:=IoResult;
   exit;
  end;

  if not MatchAddrList(RemoteAddr[1],FR_Welcome,RemoteStatus) then begin
   FReqStatus:=FReqStatus or frq_NotAcceptNow;
   LogWrite(wmFRQnotAllowed,Addr2str(RemoteAddr[1],RemoteAddr[1].Point <>0),
            ld_SessAll);
   assign(f,FR_Fname);
   erase(f);
   if IoResult <>0 then;
   exit;
  end;

  if ConnectSpeed <FR_MinSpeed then begin
   BitsInWord(FReqStatus,frq_TooSlow,0);
   LogWrite(wmFRQtooSlow,'',ld_SessAll);
   assign(f,FR_Fname);
   erase(f);
   o:=IoResult;
   exit;
  end;
 end;

 FindFReqStat;
 close(f);
 o:=IoResult;

 CreateDosTimeStamp(FC^.LastFReq);

 if FC^.Stat_Pos <>NoPos then begin
   UnpackTime(FC^.LastFReq,dt1);
   UnpackTime(FNS.LastFReq,dt2);
   if DateType(FC^.LastFReq).Date <> DateType(FNS.LastFReq).Date then FNS.onDay:=0;
   if dt1.Month <>dt2.Month then FNS.onMonth:=0;
   if (DateType(FC^.LastFReq).Date div 7) <>(DateType(FNS.LastFReq).Date div 7) then FNS.onWeek:=0;
 end;

 if (not ParseFReqList) or
    ((FC^.FReqStatus and (frq_NotAcceptNow or frq_XcdMask)) <>0) then exit;

 FC^.Send_Pos:=FilePos(SessionControl^.fSntLog);
 seek(SessionControl^.fSntLog,FileSize(SessionControl^.fSntLog));

 if FC^.FReqStatus and frq_SfM_Password <>0 then
   LogWrite(imFRQsrvrPwd,'',ld_SessAll);

 SearchInAlias;

 if FC^.FReqStatus and frq_XcdMask =0 then SearchOnDirs;

 seek(SessionControl^.fSntLog,FC^.Send_Pos);

 if FC^.nFReqed <>0 then with SessionControl^, FC^, pCfgRec^ do begin
   StatTxt:=HexL(strCRC32(Addr2str(pRemoteInfo^.RemoteAddr[1],true)));
   assign(fl,Packets+StatTxt+'.-$-');
   rewrite(fl);
   write(fl,' Based on your inquiries, we have send to you the relevant stuff:'#13+PadCh('','-',67)+#13);
   close(fl);
 end;
end;

procedure FReqMan_PostSent(fSkipped:boolean);
{
 после посылки каждого файла с типом ftFReqed;
 вызывается из SessionCtl.SentThisFile()
}
var
 Size:longint;
 f:text;

begin
 { хоть один файл послан }
 FC^.FReqStatus:=FC^.FReqStatus or frq_Sent;

 with SessionControl^ do begin
  if not fSkipped then begin
    Move(SntCurFile.MsgNo,Size,SizeOf(longint));
    with FNS do begin
      Inc(onDay,Size);
      Inc(onWeek,Size);
      Inc(onMonth,Size);
    end;
  end;

  assign(f,pCfgRec^.Packets+FC^.StatTxt+'.-$-');
  append(f);
  write(f,' '+Pad(JustFileName(SntCurFile.Name),14));
  if fSkipped then
    write(f,'skipped'+#13)
  else
   if FC^.FReqStatus and frq_SfM_Password <>0 then
     write(f,LeftPad('Ok',10)+#13)
   else
     write(f,LeftPad(Long2str(Size),10)+' Kb'#13);
  close(f);
 end;
end;

procedure AddKludges2file(var ft:file;
                          var A1, A2:tAddress;
                          sPID:string;
                          Flgs:string);
begin
 TextWrite(ft,^A'FMPT '+Long2str(A1.Point)+#13+
    ^A'TOPT '+Long2str(A2.Point)+#13+
    ^A'INTL '+Addr2str(A2,false)+' '+
    Addr2str(A1,false)+#13+
    ^A'MSGID: '+Addr2str(A1,true)+' '+
    HexL(longint(TodayDate) or CurTimeSec)+#13+
    ^A'FLAGS '+Trim(Flgs)+#13+
    {^A'FLAGS DIR'#13+}
    ^A'PID '+sPID+#13);
end;

procedure FReqMan_End(Aborted:boolean);
{
 вызывается из SessCtl.SendThisFile()
 когда слать больше нечего и были пpиняты *.REQ`и
}
var
 s:string;
 fl:text;
 ff:file; {создаваемый отлуп}
 f:file of tFReqStatRec;
 p4a:PathStr;
 l:longint;
 FromA:tAddress;

procedure MakeDetails;
var
 z:boolean;
 i:byte;

begin
 if FC^.nFReqed <>0 then with FC^ do begin

  z:=true;
  for i:=1 to nFReqed do
    if FReqFiles^[i].flag and frq_NotFound <>0 then z:=false;

  if z and (FReqStatus and frq_XcdMask =0) then exit;

  TextWrite(ff,' Resons for fail request are:'#13+PadCh('','-',65)+#13);
  i:=1;
  s:='';

  repeat
   if FReqFiles^[i].flag and frq_XcdMask <>0 then with FReqFiles^[i] do begin
    if flag and frq_XcdFilesLimit <>0 then s:='exceed files number limit'
    else
     if flag and frq_XcdTimeLimit <>0 then s:='exceed time limit'
     else
      if flag and frq_XcdDailyLimit <>0 then s:='exceed daily size limit'
      else
       if flag and frq_XcdWeeklyLimit <>0 then s:='exceed weekly size limit'
       else
        s:='exceed monthly size limit';
   end
   else
    if FReqFiles^[i].flag and frq_NotFound <>0 then
      s:='not found or password error';

   if Length(s) <>0 then begin
    if Pos('\',FReqFiles^[i].pName^) <>0 then
      TextWrite(ff,' '+FReqFiles^[i].pName^+' - '+s+#13)
    else
      TextWrite(ff,' '+Pad(FReqFiles^[i].pName^,19)+s+#13);
    if (pCfgRec^.SysFlags and frqReceipt) <>0 then
      if Pos('\',FReqFiles^[i].pName^) <>0 then
        LogWrite(0,'Ё> '+FReqFiles^[i].pName^+' - '+s,ld_SessAll)
      else
        LogWrite(0,'Ё> '+Pad(FReqFiles^[i].pName^,19)+' - '+s,ld_SessAll);
   end;

   s:='';
   Inc(i);
  until i >=nFReqed;

  TextWrite(ff,PadCh('','-',65)+#13#13);
 end;
end;

begin
 if FC =nil then exit;

 with SessionControl^, pCfgRec^ do begin
  if (FC^.FReqStatus and frq_NotAcceptNow) =0 then begin
   FNS.LastFReq:=FC^.LastFReq;
   assign(f,StatFname);
   reset(f);
   if FC^.Stat_Pos =NoPos then seek(f,FileSize(f))
   else seek(f,FC^.Stat_Pos);
   write(f,FNS);
   close(f);
  end;

  if not Aborted then begin
   if Length(BinkOutbound) =0 then begin
    CreatePkt(pRemoteInfo^.RemoteAddr[1],p4a,
             PktXt,false);
    assign(ff,p4a+PktXt);
   end else begin
    CreatePkt(pRemoteInfo^.RemoteAddr[1],p4a,
              '.hut',Length(BinkOutbound) <>0);
    assign(ff,p4a+'.hut');
   end;
   reset(ff,1);
   seek(ff,FileSize(ff)-2);

   move(pRemoteInfo^.RemoteAddr[1],FromA,sizeOf(tAddress));
   MatchAka(FromA);
   with pRemoteInfo^.RemoteAddr[1] do begin
    TextWrite(ff,#2#0+chr(lo(FromA.Node))+
                  chr(hi(FromA.Node))+
                  chr(lo(Node))+chr(hi(Node))+
                  chr(lo(FromA.Net))+
                  chr(hi(FromA.Net))+
                  chr(lo(Net))+chr(hi(Net))+
                  #1#0+ {Pvt}
                  #0#0+
                  MsgDateStamp+#0+
                  pRemoteInfo^.RemoteSysOp+#0+
                  fqmPID+#0+
                  'About your file request..'#0);
    AddKludges2file(ff,FromA,pRemoteInfo^.RemoteAddr[1],fqmPID+' '+fqmVID,'DIR');
   end;

   TextWrite(ff,#13' Dear '+ExtractWord(1,pRemoteInfo^.RemoteSysOp,[' '])+'!'#13#13);
   if FC^.FReqStatus and frq_SfM_Password <>0 then
    TextWrite(ff,'(Used Sf-Server password)'#13#13);

   if FC^.FReqStatus and frq_NotAcceptNow <>0 then
     TextWrite(ff,'This system is not accept file request now.'#13#13)
   else
    if FC^.FReqStatus and frq_TooSlow <>0 then
      TextWrite(ff,'Sorry, but we can`t satisfy your FReq at '+
                Long2str(pRemoteInfo^.ConnectSpeed)+' connection speed.'#13+
                'Please find a faster modem (or slower station).'#13#13)
    else begin
     if FC^.FReqStatus and frq_Sent <>0 then begin
       assign(fl,pCfgRec^.Packets+FC^.StatTxt+'.-$-');
       reset(fl);
       if IoResult =0 then begin
         repeat
          readln(fl,s);
          TextWrite(ff,s+#13);
         until EOF(fl);
         close(fl);
         TextWrite(ff,PadCh('','-',67)+#13#13);
       end;
     end;
     MakeDetails;

     TextWrite(ff,#13' Here is your request statistics on  '+MsgDateStamp+#13);
     TextWrite(ff,'┌───────────────────────────────────────────────────────╖'#13);
     TextWrite(ff,'│       │     Limit     │     Today     │      Rest     ║'#13);
     TextWrite(ff,'│───────┼───────────────┼───────────────┼───────────────║'#13);
     {===}
     if FR_Daily_Limit =0 then
       TextWrite(ff,'│ Day   │ '+Center('<unlimited>',14)+'│ '+
                 LeftPad(Long2str(FNS.onDay),10)+' Kb │ '+
                 Center('***',14)+'║'#13)
     else
       TextWrite(ff,'│ Day   │ '+LeftPad(Long2str(FR_Daily_Limit),10)+' Kb │ '+
                 LeftPad(Long2str(FNS.onDay),10)+' Kb │ '+

                 LeftPad(Long2str(FR_Daily_Limit-FNS.onDay),10)+' Kb ║'#13);
     if FR_Weekly_Limit =0 then
       TextWrite(ff,'│ Week  │ '+Center('<unlimited>',14)+'│ '+
                 LeftPad(Long2str(FNS.onWeek),10)+' Kb │ '+
                 Center('***',14)+'║'#13)
     else
       TextWrite(ff,'│ Week  │ '+LeftPad(Long2str(FR_Weekly_Limit),10)+' Kb │ '+
                 LeftPad(Long2str(FNS.onWeek),10)+' Kb │ '+
                 LeftPad(Long2str(FR_Weekly_Limit-FNS.onWeek),10)+' Kb ║'#13);
     if FR_Monthly_Limit =0 then
       TextWrite(ff,'│ Month │ '+Center('<unlimited>',14)+'│ '+
                 LeftPad(Long2str(FNS.onMonth),10)+' Kb │ '+

                 Center('***',14)+'║'#13)
     else
       TextWrite(ff,'│ Month │ '+LeftPad(Long2str(FR_Monthly_Limit),10)+' Kb │ '+
                 LeftPad(Long2str(FNS.onMonth),10)+' Kb │ '+
                 LeftPad(Long2str(FR_Monthly_Limit-FNS.onMonth),10)+' Kb ║'#13);
     TextWrite(ff,'╘═══════════════════════════════════════════════════════╝'#13);
    end; (*IF ACCEPTED*)

   if Length(FR_Policy) <>0 then begin
     assign(fl,FR_Policy);
     reset(fl);
     if IoResult =0 then begin
      repeat
        readln(fl,s);
        TextWrite(ff,s+#13);
      until EOF(fl);
      close(fl);
     end;
   end;

   TextWrite(ff,'--- Sf-Mail'#13#0#0#0);
   Inc(TRAF_Out,FileSize(ff));
   close(ff);

   if Length(BinkOutbound) <>0 then begin
    SntCurFile.FileType:=ftBinkUt;
    SntCurFile.MsgNo:=1 or (ord('h') shl 8);
    SntCurFile.name:=p4a+'.hut';
   end
   else begin
    SntCurFile.FileType:=ftMsg;           {ответ на фpек}
    SntCurFile.MsgAttr:=InvAddr;
    SntCurFile.Name:=p4a+PktXt;
   end;
   l:=FilePos(fSntLog);
   write(fSntLog,SntCurFile);
   seek(fSntLog,l);
  end; {IF NOT ABORTED}
 end; {WITH}

 assign(fl,pCfgRec^.Packets+FC^.StatTxt+'.-$-');
 erase(fl);
 if IoResult <>0 then; {do nothing ;-}
 { освобождаем память }
 if FC <>nil then with FC^ do begin
   for l:=1 to nFReqed do
     if FReqFiles^[l].pName <>nil then with FReqFiles^[l] do
       FreeMem(pName,Length(pName^)+1);
   {if FC^.FReqFiles <>nil then}
   FreeMem(FReqFiles,SizeOf(tFReqFiles));
   FreeMem(FC,SizeOf(tFReqCtrl));
   FC:=nil;
 end;
end;

procedure GenerateMsg(A:tAddress;
                      S:PathStr;
                      mt:tMsgType;
                      AddAttr:word;
                      Flgs:string);
{-генеpация фpек/аттач/пулл писем}
var
 fT:file;
 myA:tAddress;
 i:byte;

begin
 if mt =mtAttach then
  if not ExistFile(s) then begin
    LogWrite(emCantFind,s,ld_SessAll);
    exit;
  end;

 FillChar(MsgHeader,SizeOf(tMsgHeader),0);
 myA:=A;
 MatchAkA(myA);

 with MsgHeader do begin
    if mt =mtPoll then
      FromName:=emPID
    else
      FromName:=fqmPID;
    ToName:='SysOp';
    Subj:=S;
    Date:=MsgDateStamp;
    DestNode:=A.Node;
    OrigNode:=myA.Node;
    OrigNet:=myA.Net;
    DestNet:=A.Net;
    CreateMsgTimeStamp(MsgWritten);
    Attribute:=bMsgFlag[_KillSent] or
               bMsgFlag[_Private] or
               bMsgFlag[_Local] or
               AddAttr;
    case mt of
      mtFReq: Attribute:=Attribute or bMsgFlag[_FReq];
      mtAttach: Attribute:=Attribute or bMsgFlag[_Attach];
    end;
  end; {*WITH*}

  with MsgFolderInfo, pCfgRec^ do begin
   CurMsgReal:=NewMsgNum(NetMail);
   WriteMsgHeader(NetMail+Long2str(CurMsgReal)+MsgXt,true);
   assign(fT,NetMail+Long2str(CurMsgReal)+MsgXt);
  end;
  reset(fT,1);
  seek(fT,FileSize(fT));

  if mt =mtPoll then s:=emPID+' '+emVID
  else s:=fqmPID+' '+fqmVID;

  AddKludges2file(fT,myA,A,s,Flgs);

  TextWrite(fT,#0);
  close(fT);

 if mt =mtAttach then begin
   s:=sMsgType[mtAttach]+' ('+JustFileName(MsgHeader.Subj)+')';
   if (Length(Flgs) <>0) and (AddAttr <>0) then
    Flgs:=MsgAttrs2str(AddAttr)+'/'+Flgs
   else
    if AddAttr <>0 then
     Flgs:=MsgAttrs2str(AddAttr);
   if Length(Flgs) <>0 then Flgs:='['+Flgs+']';
 end
 else begin
   s:=sMsgType[mt];
   Flgs:='';
 end;
 LogWrite(imGenMsg,s+#3+Long2str(MsgFolderInfo.CurMsgReal)+#3+
          Addr2str(A,true)+#3+Flgs,ld_All);
end;

end.
