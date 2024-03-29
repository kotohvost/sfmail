(*************************************************
 �室�� ��p��� ����� ���:

 Msg_Track  [!][~]<toname>,[!]<toaddr>,<attrs>,  <name>,<addr>,<attrs>
             ����, �㤠 ��p�ᮢ���, ��p�����          �� �� ������

 ���� <attrs> -- ᯨ᮪ (�p�� �p����) ��p���⮢;
 �᫨ ��p�� ��p���⮬ �⮨� ���� `+'

 �p���p:

 Msg_Track  *,2:5030/143.0,-F/A,  T0$h,2:5030/143.1,*
*************************************************)

{$O+,F+,I-,X+,V-}

unit Sf_Track;

INTERFACE

uses
 Dos,
 Config;

type
 { ������� }
 tTrackCmd=(trackForward,trackReturn);
 { ��p���p� ����� }
 pTrackRec=^tTrackRec;
 tTrackRec=record
   LinkNext:pTrackRec;
   (* trackCmd:TtrackCmd;    { forward, return, etc. } *)
   OrgAddr:string[25];      { �� ����� ��p.���쬮 }
   ChgAddr:string[25];      { �� ����� ��p�� ��p��p������ }
   OrgAttrsP:word;
   OrgAttrsM:word;
   ChgAttrsP:word;
   ChgAttrsM:word;
   trackName:string[73];  { �� �� ��� ���쬮,#0,�� ����� ��� �������� }
 end;
 { ��p���p� ����� }
 pTrackHdr=^tTrackHdr;
 tTrackHdr=record
   LinkNext:pTrackHdr;
   (* trackCmd:TtrackCmd;    { forward, return, etc. } *)
   OrgAddr:string[25];      { �� ����� ��p.���쬮 }
   ChgAddr:string[25];      { �� ����� ��p�� ��p��p������ }
   OrgAttrsP:word;
   OrgAttrsM:word;
   ChgAttrsP:word;
   ChgAttrsM:word;
   trackName:byte;  { �� �� ��� ���쬮,#0,�� ����� ��� �������� }
 end;

function AddTrackDat(var sd:string):boolean;
procedure LinkTrackDat(var td:tTrackRec);
function TrackMsg:boolean;
procedure ReadTrackDat(var f:file);
procedure WriteTrackDat(var f:file);
procedure DisposeTrackDat;

IMPLEMENTATION

uses
 TpAsciiz,
 Tstring_,
 WriteLog,
 MsgXs,
 EmStruct,
 aTime;

const
 TrackHead:pTrackRec=nil;
 TrackTail:pTrackRec=nil;
 sTrackCmd:array[tTrackCmd] of string[3]=('fwd','ret');
 trackPID='SfM Msg-Track';
 trackVID='v0.0.3';

function Flag2word(s:string):word;
{-����p�頥� ��⠭������ ��� ��� 䫠�� � ��p������ ���� � S}
var
 flg:tMsgFlag;

begin
 Flag2word:=0;
 if s[1] in ['-','+'] then Delete(s,1,1);
 for flg:=_Private to _URq do
   if StLoCase(sMsgFlag[flg]) =s then begin
    Flag2word:=bMsgFlag[flg];
    exit;
   end;
end;

procedure DisposeTrackDat;
begin
 if TrackHead <>nil then
  repeat
   TrackTail:=TrackHead^.LinkNext;
   FreeMem(TrackHead,SizeOf(tTrackHdr)+Length(TrackHead^.trackName));
   TrackHead:=TrackTail;
  until TrackHead =nil;
 TrackTail:=nil;
end;

procedure LinkTrackDat(var td:tTrackRec);
begin
 td.LinkNext:=nil;
 if TrackTail <>nil then begin
   GetMem(TrackTail^.LinkNext,SizeOf(tTrackHdr)+Length(td.trackName));
   TrackTail:=TrackTail^.LinkNext;
 end
 else begin
   GetMem(TrackHead,SizeOf(tTrackHdr)+Length(td.trackName));
   TrackTail:=TrackHead;
 end;
 Move(td,TrackTail^,SizeOf(tTrackHdr)+Length(td.trackName))
end;

procedure WriteTrackDat(var f:file);
{-������ ���p��樨 � �騪�� � ����� ����p���� ���䨣�}
var
 i:byte;
 p:pTrackRec;

begin
 p:=TrackHead;
 for i:=1 to pCfgRec^.nMsgTrack do begin
   BlockWrite(f,p^,SizeOf(tTrackRec));
   p:=p^.LinkNext;
   {WRiTELN('///'^G);}
 end;
end;

procedure ReadTrackDat(var f:file);
var
 i:byte;
 td:tTrackRec;

begin
 for i:=1 to pCfgRec^.nMsgTrack do begin
   BlockRead(f,td,SizeOf(tTrackRec));
   LinkTrackDat(td);
 end;
end;

function AddTrackDat(var sd:string):boolean;
var
 td:tTrackRec;
 s,s1:string;
 i:byte;

begin
 AddTrackDat:=false;  { assume invalid track data }

 while Pos(#0,sd) <>0 do Delete(sd,Pos(#0,sd),1);

 if WordCount(sd,[',']) <>6 then
   sd:='INCORRECT NUMBER OF PARAMS FOR Msg_Track'
 else begin
   FillChar(td,SizeOf(tTrackRec),0);
   with td do begin
    trackName:=Trim(ExtractWord(1,sd,[',']))+#0+Trim(ExtractWord(4,sd,[',']));
    OrgAddr:=Trim(ExtractWord(2,sd,[',']));
    ChgAddr:=Trim(ExtractWord(5,sd,[',']));
    s:=Trim(ExtractWord(3,sd,[',']));
    if s <>'*' then
      for i:=1 to WordCount(s,[' ']) do begin
        s1:=StLoCase(ExtractWord(i,s,[' ']));
        if s1[1] ='-' then
          OrgAttrsM:=OrgAttrsM or Flag2word(s1)
        else
          OrgAttrsP:=OrgAttrsP or Flag2word(s1);
      end;
    s:=Trim(ExtractWord(6,sd,[',']));
    if s <>'*' then
      for i:=1 to WordCount(s,[' ']) do begin
        s1:=StLoCase(ExtractWord(i,s,[' ']));
        if s1[1] ='-' then
          ChgAttrsM:=ChgAttrsM or Flag2word(s1)
        else
          ChgAttrsP:=ChgAttrsP or Flag2word(s1);
      end;
    LinkTrackDat(td);
    Inc(pCfgRec^.nMsgTrack);
    AddTrackDat:=true;
   end; (*WITH TD*)
 end;
end;

function TrackMsg:boolean;
var
 cZ,cN,cF,cP:string[5];
 p:pTrackHdr;
 p_:pTrackRec absolute p;
 orgName,chgName:string[35];
 cntName:boolean;
 notName:boolean;

function WillBeTracked:boolean;
var
 Ok:boolean;

begin
 Ok:=false;
 SetDefaultAddr(MainAddress,false);
 SplitAddr(p^.OrgAddr, cZ,cN,cF,cP, false);
 if (cF ='*') or MatchAddrList(MsgInfo.DestAddr,p^.OrgAddr,rsUnknown) then begin
  if orgName <>'*' then
   if cntName then
    if (Pos(StLoCase(orgName),StLoCase(MsgHeader.ToName)) <>0) then
      Ok:=not notName
    else
      Ok:=notName
   else
    if StLoCase(MsgHeader.ToName) =StLoCase(orgName) then Ok:=not notName
    else Ok:=notName
  else
   Ok:=true;
  { �p���p塞 䫠�� }
  { ���p� � - OrgAttrsP ������ ��易⥫쭮 �p�����⢮���� }
  {           - OrgAttrsM ������ �����᢮���� }
  if Ok then
    Ok:=((p_^.OrgAttrsP and MsgHeader.Attribute) =p_^.OrgAttrsP) and
        ((p_^.OrgAttrsM and MsgHeader.Attribute) =0);
 end;
 WillBeTracked:=Ok;
end;

procedure ChangeKludge(kludge:tKludge; st:string);
var
 w,z:word;
 sl:byte absolute st;
 pl1,pl2:pMsgLn;

begin
 { prepare new line }
 st:=A2S(ascKludge[kludge])+' '+st+#13;
 with MsgInfo do begin
   pl1:=FirstLn;
   while pl1 <>nil do with pl1^ do begin
    w:=Search(Ln,LnLen,ascKludge[kludge],5);
    if w =0 then begin
     { ��諨 ��㤦 }
     if (NextLn =nil) and (Ln[LnLen] <>0) then
      st:=st+#0;
     GetMem(pl2,MsgLnSiz+sl);
     Move(st[1],pl2^.Ln,sl);
     pl2^.LnLen:=sl;
     if PrevLn =nil then  {��ࢠ� � ᯨ᪥}
      FirstLn:=pl2
     else
      PrevLn^.NextLn:=pl2;
     pl2^.PrevLn:=PrevLn;
     if NextLn =nil then {��᫥���� � ᯨ᪥}
      LastLn:=pl2
     else
      NextLn^.PrevLn:=pl2;
     pl2^.NextLn:=NextLn;
     FreeMem(pl1,MsgLnSiz+LnLen);
     exit;
    end;
    pl1:=NextLn;
   end;
   { �� ��諨 ��㤦 -- ��⠢�� ��ࢮ� ��ப��}
   GetMem(pl2,MsgLnSiz+sl);
   with pl2^ do begin
    Move(st[1],Ln,sl);
    LnLen:=sl;
    PrevLn:=nil;
    NextLn:=FirstLn;
    NextLn^.PrevLn:=pl2;
    FirstLn:=pl2;
    Inc(TotalLn);
   end;
 end;
end;

procedure Do_Track;
var
 writeHdr:boolean;
 writeTxt:boolean;
 s:string;
 {f:file;}
 aA:tAddress;

begin
 writeHdr:=false;
 writeTxt:=false;
 with MsgHeader do begin
   s:='';
   { ��p���塞 ��� ��p���..}
   if chgName <>'*' then begin
     ToName:=chgName;
     writeHdr:=true;
     s:='ToName: '+chgName;
   end;
   { ��p���塞 ��p����� ���쬠..}
   Attribute:=(Attribute or p^.ChgAttrsP) and (not p^.ChgAttrsM);
   if Attribute <>MsgInfo.Attribute then begin
     if Length(s) <>0 then
       s:=s+', ';
     s:=s+'Attrs:';
     if (p^.ChgAttrsM <>0) and (p^.ChgAttrsM and MsgInfo.Attribute <>0) then
       s:=s+' -['+MsgAttrs2str(p^.ChgAttrsM and MsgInfo.Attribute)+']';
     if (p^.ChgAttrsP <>0) and (p^.ChgAttrsP and (not MsgInfo.Attribute) <>0) then
       s:=s+' +['+MsgAttrs2str(p^.ChgAttrsP and (not MsgInfo.Attribute))+']';
     writeHdr:=true;
   end;
   MsgInfo.Attribute:=Attribute;
   { �㦭� �� ������ ��p�� �����祭��?..}
   SplitAddr(p^.ChgAddr, cZ,cN,cF,cP, false);
   if cF <>'*' then with MsgInfo do begin
     if Long2str(DestAddr.Point) <>cP then begin
       ChangeKludge(_topt,cP);
       Str2word(cP,DestAddr.Point);
       writeTxt:=true;
     end;
     {---}
     if (Long2str(DestNet) <>cN) or
        (Long2str(DestNode) <>cF) or
        (Long2str(DestAddr.Zone) <>cZ) then begin
       Str2word(cN,DestNet);
       Str2word(cF,DestNode);
       Str2word(cN,DestAddr.Net);
       DestAddr.Node:=DestNode;
       Str2word(cZ,DestAddr.Zone);
       ChangeKludge(_intl,Addr2str(DestAddr,false)+' '+
                    Addr2str(OrigAddr,false));
       writeHdr:=true;
       writeTxt:=true;
     end;
     {---}
     if Length(s) <>0 then
       s:=s+', ';
     s:=s+'Dest: '+p^.ChgAddr;
   end;
   { ᮮ�饭�� � ���..}
   if Length(s) <>0 then
     LogWrite(imMTchanged,Long2str(MsgFolderInfo.CurMsgReal)+#3+s,ld_All);
   { �����뢠�� ��������� ���쬠..}
   if writeHdr then begin
     WriteMsgHeader(pCfgRec^.NetMail+Long2str(MsgFolderInfo.CurMsgReal)+MsgXt,false);
     TrackMsg:=true;
   end;
   { ������塞 ��㤦 ^aVIA, �᫨ ���쬮 ��pp���p�������..}
   if writeHdr or writeTxt then
     with MsgInfo do begin
       Move(DestAddr,aA,SizeOf(tAddress));
       MatchAkA(aA);
       s:=^A'Via '+Addr2str(aA,true)+', '+MsgDateStamp+
          UTCstr+' '+trackPID+' '+trackVID+#13#0;
       ChangeLastMsgLn(s);
       writeTxt:=true;
     end;
   if writeTxt then begin
     { �����뢠�� ⥫� ���쬠 }
     WriteMessage(pCfgRec^.NetMail+Long2str(MsgFolderInfo.CurMsgReal)+MsgXt);
     TrackMsg:=true;
     {if IoResult <>0 then WRITELOGALL('(!) I/O ERROR');}
   end;
 end;
end;

begin
 TrackMsg:=false;
 if TrackHead <>nil then begin
   p:=pTrackHdr(TrackHead);
   repeat
     with p_^ do begin
      orgName:=copy(trackName,1,pred(Pos(#0,trackName)));
      chgName:=copy(trackName,succ(Pos(#0,trackName)),35);
      if orgName[1] ='!' then begin
        Delete(orgName,1,1);
        notName:=true;
      end
      else
        notName:=false;
      if orgName[1] ='~' then begin
        Delete(orgName,1,1);
        cntName:=true;
      end
      else
        cntName:=false;
     end;
     { �p���p塞 ⥪�饥 ���쬮 }
     if WillBeTracked then begin
       Do_Track;
       p:=nil;
     end
     else
       p:=pTrackHdr(p^.LinkNext);
   until p =nil;
 end;
end;

end.
