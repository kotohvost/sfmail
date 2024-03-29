{$I-}
{旼컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴캠
 �            FTS-001 Message Access unit               �
 �                 version 1.00 beta                    �
 �              (c)1996, Santa-Fox Team                 �
 �   All rights reserved by Author Right Guarding Law.  �
 突袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴袴暠
}
unit MsgXs;
interface
uses
  AddrXs;

{$I MsgXs.inc}

Const
  RobotNames : pRobotName = nil;

Var
  MsgHeader: tMsgHeader;
  MsgInfo  : tMsgInfo;

function Flags2Str(Flags:LongInt):String;
{ 뢱��죖젳��猶졻� 氏젫� � 飡p�ゃ }

function ParseMsg(NetDir:String;MsgNum:LongInt):byte;
{ 룧p醒p �ⓤ弛� }

procedure AddRobot(Name:String);
{ 꽡줎˙畑� º�췅 p�‘獸� }

function InRobot(Name:String):boolean;
{ 롡��歲恂� エ 飡p�첓 � º�췅� p�‘獸� }

procedure DelRobots;
{ 롧ⓤ洙� 召ⓤ첓 p�‘獸� }

implementation
uses
  TString_;

function Flags2Str(Flags:LongInt):String;
{ 뢱��죖젳��猶졻� 氏젫� � 飡p�ゃ }
Var
  S:string;
begin
  S:='';
 if (Flags and mfPrivate) <>0 then S:='Pvt ';
 if (Flags and mfCrash) <> 0 then S:=S+'CRA ';
 if (Flags and mfRecd) <> 0 then S:=S+'Rcv ';
 if (Flags and mfSent) <> 0 then S:=S+'Snt ';
 if (Flags and mfAttach) <> 0 then S:=S+'Att ';
 if (Flags and mfTransit) <> 0 then S:=S+'Trs ';
 if (Flags and mfOrphan) <> 0 then S:=S+'Orp ';
 if (Flags and mfKillSent) <> 0 then S:=S+'K/S ';
 if (Flags and mfLocal) <> 0 then S:=S+'Loc ';
 if (Flags and mfHold) <> 0 then S:=S+'Hld ';
 if (Flags and mfFrq) <> 0 then S:=S+'FRQ ';
 if (Flags and mfRRQ) <> 0 then S:=S+'RRQ ';
 if (Flags and mfIRR) <> 0 then S:=S+'RRC ';
 if (Flags and mfARQ) <> 0 then S:=S+'ARQ ';
 if (Flags and mfUpdFrq) <> 0 then S:=S+'UFR ';
 if (Flags and mfDirect) <> 0 then S:=S+'Dir ';
 if (Flags and mfHUB) <> 0 then S:=S+'HUB ';
 if (Flags and mfImm) <> 0 then S:=S+'Imm ';
 if (Flags and mfKFS) <> 0 then S:=S+'KFS ';
 if (Flags and mfTFS) <> 0 then S:=S+'TFS ';
 if (Flags and mfLOK) <> 0 then S:=S+'LOK ';
 if length(S)<>0 then Dec(byte(S[0]));
 Flags2Str:=S;
end;

function A2S(var A):string;
Var
  Res : string;
Const
  Some : byte = 0;
begin
 move(A,Res[1],255);
 byte(Res[0]):=lo(Search(A,255,Some,1));
 A2S:=Res;
end;

procedure ParseKludge(s:String);
Var
  tA : tAddress;
begin
 with MsgInfo do begin
  { Detect ^AFLAGS }
  if Pos(^A'FLAGS',s)=1 then begin
    if Pos('DIR',s)<>0 then Flags:=Flags or mfDirect;
    if Pos('HUB',s)<>0 then Flags:=Flags or mfHUB;
    if Pos('IMM',s)<>0 then Flags:=Flags or mfImm;
    if Pos('KFS',s)<>0 then Flags:=Flags or mfKFS;
    if Pos('TFS',s)<>0 then Flags:=Flags or mfTFS;
    if Pos('LOK',s)<>0 then Flags:=Flags or mfLOK;
    exit;
  end;
  if Pos(^A'INTL',s)=1 then begin
    Str2Addr(ExtractWord(2,s,[' ']),tA);  {destination}
    DestAddr.Zone:=tA.Zone;
    Str2Addr(ExtractWord(3,s,[' ']),tA);  {original}
    OrigAddr.Zone:=tA.Zone;
    exit;
  end;
  if Pos(^A'MSGID:',s)=1 then begin
    Str2addr(ExtractWord(2,s,[' ']),tA);
    if OrigAddr.Zone =0 then OrigAddr.Zone:=tA.Zone;
    if DestAddr.Zone =0 then DestAddr.Zone:=tA.Zone;
    exit;
  end;
  if Pos(^A'TOPT',s)=1 then begin
    Str2word(ExtractWord(2,s,[' ']),DestAddr.Point);
    exit;
  end;
  if Pos(^A'FMPT',s)=1 then begin
    Str2word(ExtractWord(2,s,[' ']),OrigAddr.Point);
    exit;
  end;
  if Pos(^A'REPLY:',s)=1 then begin
    if DestAddr.Zone =0 then begin
      Str2addr(ExtractWord(2,s,[' ']),tA);
      DestAddr.Zone:=tA.Zone;
    end;
    exit;
  end;
 end;
end;

function ParseMsg(NetDir:String;MsgNum:LongInt):byte;
{ 룧p醒p �ⓤ弛� }
Var
 f    : file;
 Buff : array [0..MsgHeadLen] of byte;
 MsgBody : pBuffer;
 MsgPoint: word;
 MsgRead : word;
 EOM  : boolean;
 s    : string;

procedure GetNextLn;
begin
 S:='';
 repeat
  if MsgPoint>MsgRead then begin
    BlockRead(f,MsgBody^,4096,MsgRead);
    MsgPoint:=0;
    if (MsgRead=0) or (IOResult<>0) then begin
      EOM:=true;
      exit;
    end;
  end;
  if MsgBody^[MsgPoint]=0 then begin
    EOM:=true;
    exit;
  end;
  if MsgBody^[MsgPoint]=13 then begin
    Inc(MsgPoint);
    exit;
  end;
  if MsgBody^[MsgPoint]<>10 then
    S:=S+chr(MsgBody^[MsgPoint]);
  Inc(MsgPoint);
 until false;
end;

begin
 {�∼乘畑� MsgInfo}
 FillChar(MsgInfo,SizeOf(tMsgInfo),0);
 If IOResult<>0 then {clear};
 {�洙p猶젰� �ⓤ弛�}
 Assign(f,NetDir+long2Str(MsgNum)+'.msg');
 Reset(f,1);
 If IOResult<>0 then begin
  ParseMsg:=meOpen;
  exit;
 end;
 {뿨�젰� Header}
 BlockRead(f,Buff,MsgHeadLen);
 If IOResult<>0 then begin
  ParseMsg:=meRead;
  exit;
 end;
 {뇿��キ畑� 飡p丞栒p�}
 with MsgHeader do begin
  FromName:=A2S(Buff[0]);
  ToName:=A2S(Buff[$24]);
  Subj:=A2S(Buff[$48]);
  Date:=A2S(Buff[$90]);
  move(Buff[$0A4],TimesRead,SizeOf(Word)*13);
 end;
 with MsgInfo,MsgHeader do begin
  DestAddr.Net:=DestNet;
  DestAddr.Node:=DestNode;
  OrigAddr.Net:=OrigNet;
  OrigAddr.Node:=OrigNode;
  Flags:=Attribute;
  MsgEmpty:=true;
 end;
 {룧p歲� 뮙め� 췅 췅エ葉� か蝨┘�}
 GetMem(MsgBody,4096);
 EOM:=false;
 MsgPoint:=1;
 MsgRead:=0;
 repeat
   GetNextLn;
   if S[1]=#1 then ParseKludge(s)
   else begin
     if MsgInfo.MsgEmpty and (Trim(S)<>'') and (not ((Pos('---',s) =1) or (Pos(' * Origin:',s) =1))) then
       MsgInfo.MsgEmpty:=False;
   end;
 until EOM;
 FreeMem(MsgBody,4096);
 {뇿챥猶젰� �ⓤ弛�}
 Close(f);
 If IOResult<>0 then begin
  ParseMsg:=meClose;
  exit;
 end;
 {룧p歲�� 쭬ぎ�曄�}
 MsgInfo.MsgNum:=MsgNum;
 ParseMsg:=meOk;
end;

procedure AddRobot(Name:String);
{ 꽡줎˙畑� º�췅 p�‘獸� }
Var
  NewRobot : pRobotName;
begin
  Name:=StLoCase(Trim(Name));
  if Length(Name)=0 then exit;
  if RobotNames = nil then begin
    New(RobotNames);
    FillChar(RobotNames^,SizeOf(tRobotName),0);
    RobotNames^.Name:=Name;
  end else begin
    New(NewRobot);
    NewRobot^.Name:=Name;
    NewRobot^.Next:=RobotNames;
    RobotNames:=NewRobot;
  end;
end;

function InRobot(Name:String):boolean;
{ 롡��歲恂� エ 飡p�첓 � º�췅� p�‘獸� }
Var
  CurRobot : pRobotName;
begin
  InRobot:=false;
  CurRobot:=RobotNames;
  Name:=StLoCase(Trim(Name));
  While CurRobot <> nil do begin
    If Name=CurRobot^.Name then begin
      InRobot:=true;
      exit;
    end;
    CurRobot:=CurRobot^.Next;
  end;
end;

procedure DelRobots;
{ 롧ⓤ洙� 召ⓤ첓 p�‘獸� }
Var
  CurRobot : pRobotName;
begin
  While RobotNames <> nil do begin
    CurRobot:=RobotNames^.Next;
    Dispose(RobotNames);
    RobotNames:=CurRobot;
  end;
end;

end.