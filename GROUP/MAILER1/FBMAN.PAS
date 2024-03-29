(*** The FileBox Manager for Santa Fox Mail system ***)

{$X+,I-,O+,F+}

UNIT FbMan;

INTERFACE

uses
 Dos,
 EmStruct,
 Config;

type
 pBroadCast=^tBroadCast;
 tBroadCast=record
  NextBroadCast:pBroadCast;
  BroadCastData:string[165];
  BroadCastType:tSessionType;
 end;

const
 bcHdrSiz=SizeOf(pointer)+1;
 BroadCastHead:pBroadCast=nil;

var
 BoxFileInfo:SearchRec;
 SortTRx:pSortTRx;

procedure ScanFileBoxes;
{-�p�ᬮ�p�� 䠩�-����� � ������� � ��p��� ��ꥬ� 䠩��� � ���}

procedure FromFileBox(AtBegin:boolean; A:tAddress; Hld:boolean);
{-�����뢠�� ����� 䠩��� �� ����
  ��� ��p�� A (H:TRUE/FALSE -- Hold/Normal box)
  ��� 㤠������ ��⥬� � SessionControl^.fSntLog}

procedure Insert2sntLog;
{-��⠢�� 䠩�� � SndLog}

(*** BroadCast ***)
procedure AddBroadCast(bcData:string);

procedure BroadCastFile;

procedure DisposeBroadCast;

procedure ReadBroadCast(var f:file);
procedure WriteBroadCast(var f:file);

IMPLEMENTATION

uses
 EM_Cpl,
 MsgXs,
 Busy,
 Tstring_,
 TPDos,
 WriteLog;

Const
 LogLargeAlert : boolean = false;

procedure Insert2sntLog;
{
 ��P����:
 1. Packets
 2. ArcMail         (sorted by date)
 3. FileBoxes       (sorted by date)
 4. MultiAttaches, FReqs, etc.
 5. Attach Packets
}
var
 ii:word;
 _srt:tSrt;

procedure TRxMoveApart;
{ p�������� � ���ᨢ� }
begin
 Move(SortTRx^[ii],SortTRx^[succ(ii)],(MaxTRxLog-ii)*SizeOf(tSortTRxRec));
end;

procedure InsertSort;
var
 zz:word;

begin
 with SessionControl^ do
  case _srt of
   srt_PKT: begin
      if not (SortTRx^[pred(nToSend)].FileType in [ftBinkUt,ftHoldPacket,ftPacket]) then
       for zz:=1 to pred(nToSend) do
        if not (SortTRx^[zz].FileType in [ftBinkUt,ftHoldPacket,ftPacket]) then begin
         ii:=zz;
         TRxMoveApart;
         exit;
        end;
    end;
   srt_AMA: begin
    { ArcMail }
      for zz:=1 to pred(nToSend) do with SortTRx^[zz] do begin
        if ((Srt =_srt) and (fTime >=BoxFileInfo.Time)) or
           (Srt >_srt) then begin
          ii:=zz;
          TRxMoveApart;
          exit;
        end;
      end;
    end;
   srt_ANY: begin
      if SortTRx^[pred(nToSend)].SRT<=srt_ANY then
        ii:=nToSend
      else begin
        ii:=1;
        for zz:=pred(nToSend) downto 1 do with SortTRx^[zz] do begin
          if (Srt <=srt_ANY) then begin
            ii:=zz+1;
            if ii<>nToSend then
            TRxMoveApart;
            exit;
          end;
        end;
      end;
    end;
   else
     ii:=nToSend;
  end;
end;

begin
 with SessionControl^ do begin
   if nToSend >=MaxTRxLog then begin
     If not LogLargeAlert then begin
       LogWrite(wmTooLarge,'SEND-LOG',ld_All);
       LogLargeAlert:=true;
     end;
     exit;
   end;
   LogLargeAlert:=false;
   if not (SntCurFile.FileType in [ftBoxed,ftBinkUt]) then begin
     {$I+}
     FindFirst(SntCurFile.Name,AnyFile-Directory-VolumeId,BoxFileInfo);
     {$I-}
     if DosError <>0 then BoxFileInfo.Size:=0;
     BoxFileInfo.Name:=StLoCase(JustFileName(SntCurFile.Name));
   end;
   if ((SntCurFile.FileType in [ftPacket,ftHoldPacket,ftBinkUt,ftAttPacket,ftHAttPacket]) and
      (BoxFileInfo.Size <=60)) or
      (SntCurFile.FileType in [ftFRqAccomp,ftFRhAccomp]) then
     BoxFileInfo.Size:=0;

   Inc(TRAF_out,BoxFileInfo.Size);
   Inc(nToSend);
   ii:=nToSend;
   { � �� 䠩�-�?}
   case SntCurFile.FileType of
    ftBinkLoKFS,ftBinkLoTFS,
    ftBinkLoNorm,ftBoxed:
     if Pos(StLoCase(copy(BoxFileInfo.Name,Pos('.',BoxFileInfo.Name),3)),ArcMailXt) <>0 then
       _srt:=srt_AMA
     else
       _srt:=srt_ANY;
    ftBinkUt,ftPacket,ftHoldPacket: _srt:=srt_PKT;
    ftAttPacket,
    ftHAttPacket: _srt:=srt_AttPkt;
    ftBinkFReq,
    ftFReq,ftFReh,
    ftFRqAccomp,ftFRhAccomp: _srt:=srt_ANY;
    ftKFS,ftTFS,ftNormal:
     if Pos(StLoCase(copy(BoxFileInfo.Name,Pos('.',BoxFileInfo.Name),3)),ArcMailXt) <>0 then
       _srt:=srt_AMA
     else
       _srt:=srt_ANY;
   else
    _srt:=srt_ANY;
   end;
   { ��⠢�塞 � ���ᨢ}
   if (nToSend >1) then
    InsertSort;
   { ��⠢�塞 䠩� � ���ᨢ }
   Move(SntCurFile,SortTRx^[ii],SizeOf(tTRxLog));
   SortTRx^[ii].Srt:=_srt;
   SortTRx^[ii].fTime:=BoxFileInfo.Time;
 end;
end;

procedure ScanFileBoxes;
{-�p�ᬮ�p�� 䠩�-����� � ������� � ��p��� ��ꥬ� 䠩��� � ���}
var
 pth:PathStr;
 di:SearchRec;

procedure CountFileBox;
{-��⠥� ��ꥬ 䠩��� � �騪� <pCfgRec^.FileBoxes>\di.Name\*.*}
var
 sr:SearchRec;
 o:integer;
 i:word;
 hld:boolean;

begin
 if di.Name[1] ='.' then exit; {ignore `.' and `..' directories}

 {$I+}
 FindFirst(pCfgRec^.File_Boxes+di.Name+'\*.*',Archive,sr);
 {$I-}

(* WRITELOGALL('I- Scaning: '+pCfgRec^.File_Boxes+di.Name+'\'); *)

 FillChar(QueTmp,SizeOf(tQueueRec),0);
 Hld:=_32toAddr(di.Name,QueTmp.DestAddr);

 with QueTmp.DestAddr do          {check for valid filebox..}
 if (Zone =0) or (Net =0) or
    (Zone >1023) or (Net >32767) or (Node >32767) or (Point >1023) then exit;

 if DosError =18 then begin             {��� 䠩��� � �騪�..}
   KillEmptyDir(pCfgRec^.File_Boxes+di.Name);  {..㤠�塞 ��� �騪}
   o:=IoResult;
   i:=FindAddrInQueue(QueTmp.DestAddr);
   if i <>0 then with Que[i]^ do begin
     if Hld then begin
       HoldBoxSize:=0;
       omMask:=omMask and (not omHoldBox);
     end
     else begin
       NormalBoxSize:=0;
       omMask:=omMask and (not omNormalBox);
     end;
     if omMask =0 then DelQueue(Addr2str(DestAddr,true));
   end;
   exit;
 end;

 if DosError <>0 then exit;  {��-� ��� �� ⠪ -- ��室��}

 i:=FindAddrInQueue(QueTmp.DestAddr);
 if i =0 then begin
   i:=AddQueue;
   if i =0 then exit;  {imho, ��p��� ��p����������}
   Inc(PktCreated);
 end
 else with Que[i]^ do begin
   if Hld then
     HoldBoxSize:=0
   else
     NormalBoxSize:=0;
 end;

 if Hld then
   Que[i]^.omMask:=Que[i]^.omMask or omHoldBox
 else
   Que[i]^.omMask:=Que[i]^.omMask or omNormalBox;

 while DosError =0 do with Que[i]^ do begin
   if Hld then
     Inc(HoldBoxSize,sr.Size)
   else
     Inc(NormalBoxSize,sr.Size);
   {$I+}
   FindNext(sr);
   {$I-}
 end;
end;

begin
 {$I+} FindFirst(pCfgRec^.File_Boxes+'*.*',Directory,di); {$I-}
 while DosError =0 do begin
  CountFileBox;
  {$I+} FindNext(di); {$I-}
 end;

 if Que[CurQue] =nil then CurQue:=1;
end;

procedure FromFileBox(AtBegin:boolean; A:tAddress; Hld:boolean);
{-�����뢠�� ����� 䠩��� �� ����
  ��� ��p�� A (H:TRUE/FALSE -- Hold/Normal box)
  ��� 㤠������ ��⥬� � SessionControl^.fSntLog}
var
 {TRx:tTRxLog;}
 {sr:SearchRec;}
 pth:PathStr;

begin
 if Length(pCfgRec^.File_Boxes) =0 then exit;  {-file-boxes not allowed}

 with SessionControl^ do begin
   SntCurFile.FileType:=ftBoxed;
   pth:=pCfgRec^.File_Boxes+AddrTo32(A,Hld)+'\';
   {$I+} FindFirst(pth+'*.*',Archive,BoxFileInfo); {$I-}
   while DosError =0 do begin
     SntCurFile.Name:=pth+BoxFileInfo.Name;
     if AtBegin then
       Insert2sntLog
     else begin
       Inc(nToSend);
       write(fSntLog,SntCurFile);
     end;
     {$I+} FindNext(BoxFileInfo); {$I-}
   end;
 end;
end;

(*** BroadCast ***)
procedure AddBroadCast(bcData:string);
var
 p:pBroadCast;

begin
 if Length(bcData) <>0 then begin
  GetMem(p,bcHdrSiz+Length(bcData)+1);
  p^.NextBroadCast:=nil;
  p^.BroadCastData:=bcData;
  if (WordCount(bcData,[#0])>2) and
     (stLoCase(ExtractWord(3,bcData,[#0])) = 'out' ) then
     p^.BroadCastType:=Outgoing
  else
     p^.BroadCastType:=Inbound;
  if BroadCastHead <>nil then
   p^.NextBroadCast:=BroadCastHead;
  BroadCastHead:=p;
 end;
end;

procedure BroadCastFile;
var
 p:pBroadCast;

begin
 p:=BroadCastHead;
 SetDefaultAddr(MainAddress,false);
 while p <>nil do with SessionControl^ do begin
  if (SessionType=p^.BroadCastType) and
     (MatchAddrList(pRemoteInfo^.RemoteAddr[1],
                   ExtractWord(1,p^.BroadCastData,[#0]),
                   pRemoteInfo^.RemoteStatus)) then begin
   SntCurFile.FileType:=ftDontTouch;
   SntCurFile.Name:=ExtractWord(2,p^.BroadCastData,[#0]);
   If ExistFile(SntCurFile.Name) then begin
     LogWrite(imBroadCastFile,SntCurFile.Name,ld_All);
     Insert2SntLog;
   end;
  end;
  p:=p^.NextBroadCast;
 end;
end;

procedure DisposeBroadCast;
var
 p:pBroadCast;

begin
 while BroadCastHead <>nil do begin
  p:=BroadCastHead^.NextBroadCast;
  FreeMem(BroadCastHead,bcHdrSiz+Length(BroadCastHead^.BroadCastData)+1);
  BroadCastHead:=p;
 end;
 pCfgRec^.nBroadCast:=0;
end;

procedure ReadBroadCast(var f:file);
var
 i:byte;
 bc:tBroadCast;

begin
 for i:=1 to pCfgRec^.nBroadCast do begin
  BlockRead(f,bc,SizeOf(tBroadCast));
  AddBroadCast(bc.BroadCastData);
 end;
end;

procedure WriteBroadCast(var f:file);
var
 i:byte;
 p:pBroadCast;

begin
 p:=BroadCastHead;
 for i:=1 to pCfgRec^.nBroadCast do begin
  BlockWrite(f,p^,SizeOf(tBroadCast));
  p:=p^.NextBroadCast;
 end;
end;

end.
