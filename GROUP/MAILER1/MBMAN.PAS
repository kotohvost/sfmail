(*                         �m
      The MailBoxes Manager
   Especialy for Sf-Mail system
   -�-�-�-�-�-�-�-�-�-�-�-�-�-�
   ��p���p� �p������� ���⮢묨 �騪���
   ᮤ�p������ � ����� � ���� �������p��������
   ᯨ᪠ ����ᥩ.
   ���⮢� �騪 ����� ���� ����� �� ��p���������
   ���; �p� �⮬, �� ���쬠 �p�襤訥 �� ��
   ��� ���� ��p��p�襭� � ��⠫�� ���⮢��� �騪�.
   �p� ������ � ���⮢�� �騪�� ��ᥬ ��� ��p����,
   ��� ���� ��p��p�襭� � ��⠫�� �᭮����� �������.
*)

{$X+,O+,F+,I-}

UNIT MBman;

INTERFACE
uses
 Dos;

const
 mbox_RO=$01;
 mbox_WO=$02;
 mbox_RW=mbox_RO or mbox_WO;

type
 pMailBox=^tMailBox;
 tMailBox=record
  LinkNext:pMailBox;     {㪠��⥫� �� ᫥���騩 ��� NoLink}
  BoxMode:byte;          {p���� ����㯠, �. mbox_XX ���}
  BoxDesc:string[100];   {�� ���� ᮤ�p��� ��� nul-terminated ��p���,
                          ��p��� �� ���p�� -- ��� ��������,
                          ��p�� -- ��⠫�� ��� ��ᥬ �騪�}
 end;
 { robotname struct }
 pRobotName=^tRobotName;
 tRobotName=record
  NextRobot:pRobotName;
  Name:string[36];
 end;

const
 NoLink=nil;
 MailBoxList:pMailBox=NoLink;
 mboxHdrSiz=SizeOf(pointer)+2;
 mboxFullSiz=mboxHdrSiz+100;
 { robot`s names }
 RobotNameHead:pRobotName=NoLink;

procedure AddMailBox(Owner,Dir:string; Attr:byte);
{-������� ���⮢� �騪 � ᯨ᮪}

procedure DisposeMailBoxes;
{-�᢮�������� ����� �� ��� �騪��}

procedure ReadMailBoxes(var f:file);
{-�⥭�� � ����ᥭ�� � ������ �騪��}

procedure WriteMailBoxes(var f:file);
{-������ ���p��樨 � �騪�� � ����� ����p���� ���䨣�}

function Forward2mailBox:boolean;
{-�p���p�� � ��p���� ⥪�饣� ���쬠 � �騪}

procedure ManageMailBoxes;
{-��ᬮ�p��� � �騪�� ���� ���쬠 � ��p������� �� � �᭮���� NetMail}


(************************ Robot`s names *************************)

procedure AddRobotName(s:string);
{-�������� ��� � ᯨ᮪}

procedure DisposeRobotNames;

procedure ReadRobotNames(var f:file);
{-�⠥� ᯨ᮪ ���� � ⥪�饩 ����樨 䠩�� F}

procedure WriteRobotNames(var f:file);
{-���� ᯨ᮪ ���� � ⥪�饩 ����樨 䠩�� F}

function IsRobotName(s:string):boolean;
{-�஢���� �� ᯨ�� � ������ �� ��� � ��ப� S ������ ஡��}

IMPLEMENTATION

uses
 Config,
 MsgXs,
 fileMan,
 WriteLog,
 tString_,
 aTime;

const
 mbPID='Sf-MailBox Man';
 mbVID='ver 0.1.0';
 mbFwrdBy=#1'Forwarded by ';

procedure DisposeMailBoxes;
{-�᢮�������� ����� �� ��� �騪��}
var
 mb:pMailBox;

begin
 if MailBoxList <>NoLink then
  repeat
   mb:=MailBoxList^.LinkNext;
   FreeMem(MailBoxList,mboxHdrSiz+Length(MailBoxList^.BoxDesc));
   MailBoxList:=mb;
  until MailBoxList =NoLink;
 pCfgRec^.nMailBox:=0;
end;

procedure AddMailBox(Owner,Dir:string; Attr:byte);
var
 mb:tMailBox;

begin
 FillChar(mb,mboxHdrSiz,0);
 mb.BoxDesc:=Owner+#0+AddBackSlash(Dir);
 mb.BoxMode:=Attr;

 if MailBoxList =NoLink then mb.LinkNext:=NoLink
 else mb.LinkNext:=MailBoxList;

 GetMem(MailBoxList,mboxHdrSiz+Length(mb.BoxDesc));
 Move(mb,MailBoxList^,mboxHdrSiz+Length(mb.BoxDesc));

 MkAllDir(Dir);
end;

procedure ReadMailBoxes(var f:file);
{-�⥭�� � ����ᥭ�� � ������ �騪��}
var
 i:byte;
 mb:tMailBox;

begin
 for i:=1 to pCfgRec^.nMailBox do begin
   BlockRead(f,mb,mboxFullSiz);
   AddMailBox(copy(mb.BoxDesc,1,pred(Pos(#0,mb.BoxDesc))),
              copy(mb.BoxDesc,succ(Pos(#0,mb.BoxDesc)),100),mb.BoxMode);
 end;
end;

procedure WriteMailBoxes(var f:file);
{-������ ���p��樨 � �騪�� � ����� ����p���� ���䨣�}
var
 i:byte;
 mb:pMailBox;

begin
 mb:=MailBoxList;
 for i:=1 to pCfgRec^.nMailBox do begin
   {===
   WRITELN('MB: ',mb^.BoxDesc,' [',HexW(mb^.BoxMode),']');
   ===}
   BlockWrite(f,mb^,mboxFullSiz);
   mb:=mb^.LinkNext;
 end;
end;

(*** MailBoxes Management ***)

procedure ManageMailBoxes;
{-��ᬮ�p��� � �騪�� ���� ���쬠 � ��p������� �� � �᭮���� NetMail}
var
 p:pMailBox;
 sr:SearchRec;
 dt:DateTime;

procedure Forward2netMail;
{-��p���� ���쬠 �� �騪� � ��騩 ������}
var
 s:string;
 aw,w:word;
 f1:file;

begin
 if IOResult<>0 then {clear};
 assign(f1,ExtractWord(2,p^.BoxDesc,[#0])+sr.Name);
 reset(f1,1);
 if IoResult <>0 then begin
  Close(f1);
  if IOResult<>0 then {clear};
  LogWrite(emCantOpen,sr.Name,ld_All);
  exit;
 end;
 seek(f1,$BA);
 BlockRead(f1,w,2);
 if ((w and bMsgFlag[_Local]) =0) or            {�� �����쭮�}
    ((w and bMsgFlag[_Sent]) <>0) then begin
   close(f1);
   exit;                                        {㦥 ��᫠���}
 end;

 if not ReadMessage(ExtractWord(2,p^.BoxDesc,[#0])+sr.Name,false) then
  exit;

 { ������� ��㤦 ^AVia}
 s:=mbFwrdBy+mbPID+' '+mbVID+' '+
    Addr2str(pCfgRec^.MyAddress[1],true)+', '+MsgDateStamp+
    UTCstr+#13#0;
 ChangeLastMsgLn(s);

 if (MsgInfo.Attribute and bMsgFlag[_KillSent]) =0 then begin
   { ��� ��p���� K/S..}
   aw:=MsgInfo.Attribute or bMsgFlag[_Sent];
   seek(f1,$BA);
   BlockWrite(f1,aw,2);
   dt.Sec:=62;
   PackTime(dt,sr.Time);
   SetFtime(f1,sr.Time);
   close(f1);
   aw:=IoResult;
   MsgHeader.Attribute:=MsgHeader.Attribute or bMsgFlag[_KillSent];
   MsgInfo.Attribute:=MsgHeader.Attribute;
 end
 else begin
   close(f1);
   erase(f1);
   aw:=IoResult;
 end;

 w:=NewMsgNum(pCfgRec^.NetMail);
 LogWrite(imFwdIntoNetmail,Long2str(w)+#3+
          ExtractWord(1,p^.BoxDesc,[#0]),ld_All);
 WriteMsgHeader(pCfgRec^.NetMail+Long2str(w)+MsgXt,true);
 WriteMessage(pCfgRec^.NetMail+Long2str(w)+MsgXt);
end;

begin
 p:=MailBoxList;

 while p <>NoLink do begin
   if (p^.BoxMode and mbox_RO) <>0 then begin
    {$I+} FindFirst(ExtractWord(2,p^.BoxDesc,[#0])+'*.msg',Archive,sr); {$I-}
    while DosError =0 do begin
     { R/O ���쬠 ����p�p㥬 }
     if (sr.Attr and ReadOnly) =0 then begin
       UnpackTime(sr.Time,dt);
       if dt.Sec <>62 then Forward2netMail;
     end;
     {$I+} FindNext(sr); {$I-}
    end;
   end;
   p:=p^.LinkNext;
 end;
end;

function Forward2mailBox:boolean;
{-�p���p�� � ��p���� ⥪�饣� ���쬠 � �騪}
var
 f:file;
 w:word;
 p:pMailBox;
 pth:PathStr;
 nme:string;
 l:longint;
 dt:DateTime;
 aA:tAddress;

begin
 p:=MailBoxList;
 Forward2mailBox:=false;

 while p <>NoLink do begin
  if (p^.BoxMode and mbox_WO) <>0 then with MsgInfo do begin
   pth:=ExtractWord(2,p^.BoxDesc,[#0]);
   nme:=ExtractWord(1,p^.BoxDesc,[#0]);

   if (StLoCase(MsgHeader.ToName) =StLoCase(nme)) and
       MsgForUs(DestAddr.Zone,DestAddr.Net,
                DestAddr.Node,DestAddr.Point) then begin
    MsgHeader.Attribute:=MsgHeader.Attribute and (not bMsgFlag[_Local]);
    w:=NewMsgNum(pth);
    WriteMsgHeader(pth+Long2str(w)+MsgXt,true);
    LogWrite(imFwdIntoMailbox,Long2str(w)+#3+nme,ld_All);
    { �����p��� ���室�騩 AkA �� ᯨ᪠ ���� ��p�ᮢ }
    Move(MsgInfo.DestAddr,aA,SizeOf(tAddress));
    MatchAkA(aA);
    { �⠢�� ��㤦 ^AVia }
    nme:=mbFwrdBy+mbPID+' '+mbVID+' '+Addr2str(aA,true)+', '+
         MsgDateStamp+UTCstr+#$0D#0;
    ChangeLastMsgLn(nme);
    { �����뢠�� ⥪�� ���쬠 }
    WriteMessage(pth+Long2str(w)+MsgXt);
    { ���⠢�塞 䫠���, �� ���쬮 ���ࢠথ�� }
    assign(f,pth+Long2str(w)+MsgXt);
    reset(f,1);
    GetFtime(f,l);
    UnpackTime(l,dt);
    dt.Sec:=62;
    PackTime(dt,l);
    SetFtime(f,l);
    close(f);
    if IoResult <>0 then;
    assign(f,pCfgRec^.NetMail+Long2str(MsgFolderInfo.CurMsgReal)+MsgXt);
    erase(f);
    if IoResult <>0 then;
    if MsgFolderInfo.AddFolderMap <>nil then
     ClrBit4msg(MsgFolderInfo.CurMsgReal,MsgFolderInfo.AddFolderMap);
    Forward2mailBox:=true;
    exit;
   end;
  end; {IF MODE WO}
  p:=p^.LinkNext;
 end;
end;

(************************ Robot`s names *************************)

procedure AddRobotName(s:string);
{-�������� ��� � ᯨ᮪}
Var
  NewRobot : pRobotName;

begin
 s:=StLoCase(Trim(s));
 if Length(s)=0 then exit;
 if RobotNameHead = nil then begin
   New(RobotNameHead);
   FillChar(RobotNameHead^,SizeOf(tRobotName),0);
   RobotNameHead^.Name:=s;
 end else begin
   New(NewRobot);
   NewRobot^.Name:=s;
   NewRobot^.NextRobot:=RobotNameHead;
   RobotNameHead:=NewRobot;
 end;
end;

procedure DisposeRobotNames;
Var
  CurRobot : pRobotName;
begin
  While RobotNameHead <> nil do begin
    CurRobot:=RobotNameHead^.NextRobot;
    Dispose(RobotNameHead);
    RobotNameHead:=CurRobot;
  end;
 pCfgRec^.nRobotName:=0;
end;

procedure ReadRobotNames(var f:file);
{-�⠥� ᯨ᮪ ���� � ⥪�饩 ����樨 䠩�� F}
var
 i:byte;
 rn:tRobotName;

begin
 for i:=1 to pCfgRec^.nRobotName do begin
  BlockRead(f,rn,SizeOf(tRobotName));
  AddRobotName(rn.Name);
 end;
end;

procedure WriteRobotNames(var f:file);
{-���� ᯨ᮪ ���� � ⥪�饩 ����樨 䠩�� F}
var
 i:byte;
 p:pRobotName;

begin
 p:=RobotNameHead;
 for i:=1 to pCfgRec^.nRobotName do begin
  BlockWrite(f,p^,SizeOf(tRobotName));
  p:=p^.NextRobot;
 end;
end;

function IsRobotName(s:string):boolean;
{-�஢���� �� ᯨ�� ���� �� ��� � ��ப� S ������ ஡��}
Var
  CurRobot : pRobotName;

begin
 IsRobotName:=false;
 CurRobot:=RobotNameHead;
 S:=StLoCase(Trim(S));
 While CurRobot <> nil do begin
  If s=CurRobot^.Name then begin
    IsRobotName:=true;
    exit;
  end;
  CurRobot:=CurRobot^.NextRobot;
 end;
end;

end.
