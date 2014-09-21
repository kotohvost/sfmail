(*===========================*)
(*   FReq Statistics Viewer  *)
(* for Santa Fox Mail system *)
(*===========================*)

{$X+,I-,V-}

PROGRAM SfM_FSV;

uses
 Dos,
 Cfg,
 SfM_Api,
 ReadCfg,

 TpEntry,
 TpMenu,
 YesOrNo,
 TpCrt,
 TpWindow,
 TpPick,
 Tstring_;

const
 PID:string[22]='FReq Statistics Viewer';
 VID:string[15]='ver 0.1.2/beta';
 CID:string[44]='(c) Anton Deinow Software Research Lab, 1995';

 PickColors:PickColorArray=($1B,$1B,$30,$7F,$1F,$7E,$1C);
 flx:FlexAttrs=($7E, $70,$7F,$7B);
 fhp:FlexAttrs=($3F, $3C,$3B,$3E);
 Color4:MenuColorArray=($0B,$1E,$07,$71,$0F,$30,$37,$08);

 MaxRec=2500;

var
 StatArray:pointer;
 s:string;
 CfgFname:PathStr;
 wReclama,
 wData,
 wPick:WindowPtr;
 pCover:pointer;
 OldHalt:pointer;
 sRec:tFReqStatRec;
 f:file of tFReqStatRec;
 nRec:word;
 i:byte;
 l:longint;
 dt,td:DateTime;
 Modified,
 ok:boolean;

 FirstChoice,
 Choice:word;

type
 StatRecPtr=^tFReqStatRec;

function StatPtr(i:word):StatRecPtr;
type
 SO=record
  O:word;
  S:word;
 end;

var
 P:pointer;

begin
 P:=StatArray;
 Inc(SO(P).O,SizeOf(tFReqStatRec)*(i-1));
 StatPtr:=P;
end;

procedure DrawFReqData(i:word);
var
 c:byte;

begin
  with StatPtr(i)^, pCfgRec^ do begin
    UnpackTime(LastFReq,dt);

    FastWriteWindow(Pad(_4D2str(Addr),15),1,12,$70);
    FastWriteWindow(LeftPadCh(Long2str(dt.Day),'0',2)+'.'+
    LeftPadCh(Long2str(dt.Month),'0',2)+'.'+
    Copy(Long2str(dt.Year),3,2)+' at '+
    LeftPadCh(Long2str(dt.Hour),'0',2)+':'+
    LeftPadCh(Long2str(dt.Min),'0',2)+':'+
    LeftPadCh(Long2str(dt.Sec),'0',2)
    ,2,12,$70);
    {---}
    if FR_Daily_Limit =0 then begin
     FastWriteWindow(Center('***',12),6,38,$70);
     c:=$71;
    end
    else begin
     if onDay >=FR_Daily_Limit then c:=$7C
     else c:=$70;
     FastWriteWindow(LeftPad(Long2str(FR_Daily_Limit-onDay),9)+' Kb',6,38,c);
    end;
    FastWriteWindow(LeftPad(Long2str(onDay),8)+' Kb',6,25,c);

    if FR_Weekly_Limit =0 then begin
     FastWriteWindow(Center('***',12),7,38,$70);
     c:=$71;
    end
    else begin
     if onWeek >=FR_Weekly_Limit then c:=$7C
     else c:=$70;
     FastWriteWindow(LeftPad(Long2str(FR_Weekly_Limit-onWeek),9)+' Kb',7,38,c);
    end;
    FastWriteWindow(LeftPad(Long2str(onWeek),8)+' Kb',7,25,c);

    if FR_Monthly_Limit =0 then begin
     FastWriteWindow(Center('***',12),8,38,$70);
     c:=$71;
    end
    else begin
     if onMonth >=FR_Monthly_Limit then c:=$7C
     else c:=$70;
     FastWriteWindow(LeftPad(Long2str(FR_Monthly_Limit-onMonth),9)+' Kb',8,38,$70);
    end;
    FastWriteWindow(LeftPad(Long2str(onMonth),8)+' Kb',8,25,c);
  end;
end;

{$F+}
procedure MyHalt;
begin
 TextAttr:=$7;

 if pCover <>nil then
   RestoreWindow(1,1,80,25,true,pCover);

 ExitProc:=OldHalt;
 writeln('-Done (#',ExitCode,')'#10);
 NormalCursor;
 halt(ExitCode);
end;

function GetRec(w:word):string;
begin
 GetRec:=_4D2str(StatPtr(w)^.Addr);
end;

procedure ShowFReqData(w:word);
begin
 DrawFReqData(w);
end;

procedure PostEd(var ESR:ESrecord);
begin
 Modified:=CurrentFieldModified(ESR);
end;
{$F-}

procedure Usage;
begin
 TextAttr:=$A;
 writeln(#10'Usage:');
 TextAttr:=$D;
 writeln('       FrStView [/cCfgFile] [/nL]'#13#10+
         '         /cCfgFile defines the name of Sf-Mail`s configuration file');
 writeln('         /nL defines line number'#10);
 halt(213);
end;

procedure ShowReclama;
var
 c:byte;

procedure JustWait;
var
 i:word;

begin
 for i:=0 to 300 do if KeyPressed then;
end;

procedure ShowSfMail;
begin
 FastCenter('  ÜÜÜ   ÜÜ     Ü    Ü         ß   Ü ', 4,c);
 FastCenter(' ÛÛ  ß Û  Û    ÛÛ   Û ÜßßßÜ  ßÛ  ßÛ ', 5,c);
 FastCenter('  ßÛÜ ßÛß      Û Û ÛÛ   ÜßÛ  ÛÛ  ÛÛ ', 6,c);
 FastCenter('Ü ÜÛÛ ÛÛ      Û  Ûß Û  Û  ßÜ  Û   Û ', 7,c);
 FastCenter(' ßßß  ß      ß       ß  ßß ß   ß   ß', 8,c);
end;

begin
 HiddenCursor;
 MakeWindow(wReclama,3,14,54,23,true,true,true,$7,$B,$7,'');
 DisplayWindow(wReclama);
 FastCenter('E n j o y   t h e',2,$F);
 FastCenter('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ',3,$E);
 for c:=1 to $F do begin
   ShowSfMail;
   JustWait;
 end;
 c:=$A;
 ShowSfMail;
 FastWriteWindow(#3,6,20,$C);
end;

function NeedPack:boolean;
var
 i:word;

begin
 for i:=1 to nRec do with StatPtr(i)^ do
   if (onDay =0) and (onWeek =0) and (onMonth =0) then begin
     NeedPack:=true;
     exit;
   end;
 NeedPack:=false;
end;

procedure PackAndWrite(OnlyWrite:boolean);
var
 i:word;

begin
 i:=1;
 if not OnlyWrite then
  repeat
   with StatPtr(i)^ do
    if (onDay =0) and (onWeek =0) and (onMonth =0) then begin
      move(StatPtr(i+1)^,StatPtr(i)^,SizeOf(tFReqStatRec)*(nRec-i));
      Dec(nRec);
    end
    else
     Inc(i);
  until i >nRec;

 assign(f,StatFname);
 if nRec =0 then
   erase(f)
 else begin
   rewrite(f);
   for i:=1 to nRec do
     write(f,StatPtr(i)^);
   close(f);
 end;
end;

procedure EditData;
var
 L1,L2,L3:longint;
 ESR:ESrecord;
 XitCmd:EStype;

begin
 InitESrecord(ESR);
 SetPostEditPtr(ESR,@PostEd);

 with StatPtr(Choice)^ do begin
  L1:=onDay;
  L2:=onWeek;
  L3:=onMonth;

  AddLongField(ESR,'', 9,28,'99999999', 9,28, 0, 0,99999999,L1);
  AddLongField(ESR,'',10,28,'99999999',10,28, 0, 0,99999999,L2);
  AddLongField(ESR,'',11,28,'99999999',11,28, 0, 0,99999999,L3);

  XitCmd:=EditScreen(ESR,0,false);
  if XitCmd =ESdone then with StatPtr(Choice)^ do begin
    CreateMsgTimeStamp(LastFReq);
    onDay:=L1;
    onWeek:=L2;
    onMonth:=L3
  end;
 end;
end;

begin
 TextAttr:=$F;
 writeln(#10+PID+'; '+VID);
 TextAttr:=$E;
 writeln(CID+#10);
 TextAttr:=$7;

 pCover:=nil;
 OldHalt:=ExitProc;
 ExitProc:=@MyHalt;

 CfgFname:='Sf-Mail.cfg';

 for i:=1 to ParamCount do begin
   s:=ParamStr(i);
   if (s[1] ='/') or (s[1] ='-') then
    case LoCase(s[2]) of
     'h','?': Usage;
     'c': CfgFname:=DefaultExtension(copy(s,3,127),'cfg');
     'n': if Str2word(copy(s,3,2),nRec) then
           Task:=nRec;
    end;
 end;

 if Read_Config(CfgFname)<>rcsOk then begin
   writeln('Unable to read ',CfgFname);
   halt(254);
 end;

 assign(f,StatFname);
 reset(f);
 if IoResult <>0 then begin
   writeln('Unable to open '+StatFname+'!');
   halt(255);
 end;

 nRec:=word(FileSize(f));

 if nRec =0 then begin
   writeln('Statistics file is empty!'^G);
   halt(252);
 end;

 if nRec >MaxRec then begin
   writeln('Maximum records limit exceed!'#13#10+
           'Use SfM_fsv /Pack for shoot this problem.'^G);
   halt(253);
 end;

 CreateMsgTimeStamp(l);
 UnpackTime(l,td);

 GetMem(StatArray,SizeOf(tFReqStatRec)*MaxRec);
 for Choice:=1 to nRec do begin
   read(f,StatPtr(Choice)^);
   with StatPtr(Choice)^ do begin
    UnpackTime(LastFReq,dt);
    if DateType(l).Date <>DateType(LastFReq).Date then onDay:=0;
    if dt.Month <>td.Month then onMonth:=0;
    if (DateType(l).Date div 7) <>(DateType(LastFReq).Date div 7) then onWeek:=0;
   end;
 end;
 close(f);

 SaveWindow(1,1,80,25,true,pCover);

 FastFill(80*25,'°',1,1,$17);
 FastFill(80,' ',1,1,$3E);
 FastWrite(PID,1,2,$3B);
 FastWrite('³ '+VID,1,63,$3B);
 FastFill(80,' ',25,1,$3F);
 FlexWrite('Enter Edit ³ Esc Exit',25,2,fhp);

 Shadow:=true;
 ShadowAttr:=$80;

 ShowReclama;

 {-¨­¨â¨¬ ¤ ­­ë¥ ¤«ï p¥¤ ªâ®p -}
 SetFieldAttr($3F);
 SetStringAttr($1F);
 SetClearFirstChar(true);

 Modified:=false;

 MakeWindow(wPick,58,3,77,23, true,true,true, $1B,$1B,$1E, ' Addresses ');
 DisplayWindow(wPick);

 MakeWindow(wData,3,3,54,12, true,true,true, $70,$7B,$01,'');
 DisplayWindow(wData);
 FastWriteWindow('Node',1,7,$7E);
 FastWriteWindow('Last FReq',2,2,$7E);
 FlexWrite('ÃÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄ´',6,3,flx);
 FlexWrite('³    Limit     ³   Today     ³    Rest',7,11,flx);
 FlexWrite('ÃÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄ´',8,3,flx);
 FlexWrite('Day   ³              ³             ³             ',9,5,flx);
 FlexWrite('Week  ³              ³             ³             ',10,5,flx);
 FlexWrite('Month ³              ³             ³             ',11,5,flx);
 FastWrite('ÔÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¾',12,3,$7B);
 with pCfgRec^ do begin
  if FR_Daily_Limit =0 then
    FastWriteWindow(Center('<unlimited>',12),6,10,$7A)
  else
    FastWriteWindow(LeftPad(Long2str(FR_Daily_Limit),9)+' Kb',6,10,$70);
  if FR_Weekly_Limit =0 then
    FastWriteWindow(Center('<unlimited>',12),7,10,$7A)
  else
    FastWriteWindow(LeftPad(Long2str(FR_Weekly_Limit),9)+' Kb',7,10,$70);
  if FR_Monthly_Limit =0 then
    FastWriteWindow(Center('<unlimited>',12),8,10,$7A)
  else
    FastWriteWindow(LeftPad(Long2str(FR_Monthly_Limit),9)+' Kb',8,10,$70);
 end;

 Choice:=1;
 FirstChoice:=1;
 PickUserPtr:=@ShowFReqData;

 FillPickWindow(wPick,@GetRec,nRec,PickColors,1,1);

 repeat
   PickBar(wPick,@GetRec,nRec,PickColors,true,Choice,FirstChoice);
   case PickCmdNum of
    PKSselect: EditData;
    PKsexIt: if NeedPack then
              case ButtonMenu('Pack statistics file?',tYes,tCancel,
                    bButton[tYes] or bButton[tNo] or bButton[tCancel],Horizontal,
                    FrameChars,Color4,'Confirmation..') of
               tYes: PackAndWrite(false);
               tCancel: PickCmdNum:=PKSnone;
              end
             else
              if Modified then
                case ButtonMenu('Data modified,'#3'ok to save?',tYes,tCancel,
                      bButton[tYes] or bButton[tNo] or bButton[tCancel],Horizontal,
                      FrameChars,Color4,'Confirmation..') of
                 tYes: PackAndWrite(true);
                 tCancel: PickCmdNum:=PKSnone;
                end;
   end;
 until PickCmdNum =PKsexIt;

 KillWindow(wData);
 KillWindow(wPick);
 KillWindow(wReclama);
end.
