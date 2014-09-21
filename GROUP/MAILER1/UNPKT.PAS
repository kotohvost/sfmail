(* Распаковщик пакетов *)

{$X+,O+,F+,I-}

UNIT UnPkt;

INTERFACE

uses
 Dos;

function UnPackPkt(PktName:PathStr):boolean;
{-pаспаковка пакета с путем/именем PktName
  в каталог pCfgRec^.NetMail;
  ВЕРHЕТ: flase, если в этом пакете нет эффективных писем}

(*** procedure DateStamp2timeStamp(s:string; var MsgTimeStamp:longint);
{-пеpеведет из стpоки S в MsgTimeStamp дату в дос фоpмате} ***)

IMPLEMENTATION

uses
 MsgXs,
 Config,
 WriteLog,
 Tstring_,
 aTime,
 EmStruct,
 MbMan,
 pwd_Xs,
 Sf_Track,
 adLang;

type
 tPktStatus=(pktOk,pktBad,pktArc);
 tMsgStatus=(mst4us,mstFwd,mstOk);

const
 msgBegin=$00;
 msgMustDie=$FE;
 msgOk=$FF;
 { cleared msg attributes and flags }
 caImm=$01;
 caDir=$02;

procedure DateStamp2timeStamp(s:string; var MsgTimeStamp:longint);
{-пеpеводит из стpокового вида в MsgTimeStamp}
var
 dt:DateTime;

begin
 with DT do begin
{дата}
    Str2word(ExtractWord(1,s,[' ']),day);
    month:=WhatMonth(ExtractWord(2,s,[' ']));
    Str2word(ExtractWord(3,s,[' ']),year);
{вpемя}
    s:=ExtractWord(4,s,[' ']);
    Str2word(ExtractWord(1,s,[':']),hour);
    Str2word(ExtractWord(2,s,[':']),min);
    Str2word(ExtractWord(3,s,[':']),sec);
 end;
 {объединяем в стpуктуpу}
 PackTime(dt,MsgTimeStamp);
 MsgTimeStamp:=((MsgTimeStamp and $FFFF) shl 16)+
               ((MsgTimeStamp and $FFFF0000) shr 16);
end;

function UnPackPkt(PktName:PathStr):boolean;
{-pаспаковка пакета с путем/именем PktName
  в каталог MsgFolderInfo.Path;
  ВЕРHЕТ: flase, если в этом пакете нет эффективных писем}

type
 tBuf=array[1..20480] of byte;  {дисковый буфер для пакета}

var
 f:file;
 BufRead:^tBuf;         {буфеp для чтения пакетов}
 BufRp:word;            {указатель в буфеpе чтения}
 CurLen:word;           {указатель в буфере строки}
 InRB:word;             {сколько байт в буфеpе чтения}
 w:word;
 fm:file;               {для записи текста письма}
 s:string;
 aA:tAddress;

 EmptyPkt:boolean;      {если пакет был пустым}
 EOP,                   {конец пакета (End Of Packet)}
 EOPM:boolean;          {конец письма в пакете (End Of Packed Msg)}
 MsgStatus:tMsgStatus;  {состояние текущего pаспакованного письма}
 PktStatus:tPktStatus;  {состояние пакета}
 PktSiz:longint;
 ClrAttr:byte;
 CheckLen: byte;

function NextByte:byte;
begin
 if BufRp >InRB then begin
  if not EOF(f) then begin
    BlockRead(f,BufRead^[1], SizeOf(tBuf),InRB);
    BufRp:=1;
    NextByte:=NextByte;
  end
  else begin
    NextByte:=0;
    EOP:=true;
  end;
  exit;
 end;
 { в буфеpе есть еще байты }
 NextByte:=BufRead^[BufRp];
 Inc(BufRp);
end;

function NextWord:word;
begin
 NextWord:=(NextByte shl 8)+NextByte;
end;

procedure NextField(MsgBody:boolean);
var
 b:byte;
 done:boolean;

begin
 CurLen:=0;
 done:=false;
 s:='';

 repeat
  b:=NextByte;
  if MsgBody then begin
   if b <>$0A then begin
    Inc(CurLen);
    MsgLnBuf^[CurLen]:=b;
    if b =0 then begin
     done:=true;
     EOPm:=true;
     if CurLen =1 then
      CurLen:=0
     else
      MsgLnBuf^[CurLen]:=$0D;
    end
    else
     if (b =$0D) or (b =$8D) then
      done:=true;
    if (not done) and (CurLen >=MaxLnSiz) then begin
     Inc(CurLen);
     MsgLnBuf^[CurLen]:=$0D;
     done:=true;
    end;
   end;
  end
  else begin
   if b =0 then
     done:=true
   else
     s:=s+char(b);
   if CheckLen<>0 then
     If Length(s)>=CheckLen then done:=true;
  end;
 until done;
 if MsgBody then begin
  s[0]:=char(MinWord(CurLen,80));
  Move(MsgLnBuf^,s[1],ord(s[0]));
  while (s[Length(s)] in [#0,#13]) and (Length(s) >0) do
   Dec(byte(s[0]));
 end;
end;

begin  (* UNPACKPKT *)
 UnpackPkt:=false;   {assume paket was спижжен}

 FillChar(PktHeader,SizeOf(tPktHeader),$13);
 assign(f,PktName);
 reset(f,1);

 if IoResult <>0 then begin
  LogWrite(emCantOpen,PktName,ld_All);
  exit;
 end;

 PktSiz:=FileSize(f);

 BlockRead(f,PktHeader,SizeOf(tPktHeader));
 if IoResult <>0 then begin
  LogWrite(emReadError,PktName,ld_All);
  exit;
 end;

 GetMem(BufRead,SizeOf(tBuf));
 GetMem(MsgLnBuf,MsgTrxSiz);

 BufRp:=1;
 InRB:=0;
 EOP:=false;
 EmptyPkt:=true;
 PktStatus:=pktBad;

 if PktHeader.PktType =$02 then begin

   PktStatus:=pktOk;

   LogWrite(imUnpacking,JustFileName(PktName)+#3+Long2str(PktSiz),ld_All);
   with PktHeader do begin
     if (OrigPoint <>0) and (OrigNet =$FFFF) then OrigNet:=AuxNet;
     LogWrite(imPktFromTo,xAddr2str(OrigZone,OrigNet,OrigNode,OrigPoint)+#3+
              xAddr2str(DestZone,DestNet,DestNode,DestPoint),ld_All);
     aA.Zone:=OrigZone;
     aA.Net:=OrigNet;
     aA.Node:=OrigNode;
     aA.Point:=OrigPoint;
     s[0]:=#8;
     move(Password,s[1],8);
     s[0]:=chr(Pos(#0,s)-1);
     if GetMailPassword(aA)<>'' then begin
       if stUpCase(GetMailPassword(aA))<>s then begin
         FreeMem(BufRead,SizeOf(tBuf));
         FreeMem(MsgLnBuf,MsgTrxSiz);
         close(f);
         rename(f,ForceExtension(PktName,'bad'));
         if IoResult <>0 then;
         LogWrite(emInvalidPkt,PktName+#3+
                  ForceExtension(JustFileName(PktName),'bad (check password)'),ld_All);
         exit;
       end;
     end;
     s:='';
   end;


   repeat
    DisposeMessage;
    FillChar(MsgInfo,SizeOf(tMsgInfo),0);
    FillChar(MsgHeader,SizeOf(tMsgHeader),0);
    MsgInfo.MsgNotEmpty:=false;
    EOPm:=false;
    w:=NextWord;  {PktType}
    ClrAttr:=0;   {никакие атpибуты еще не снимали}
    CheckLen:=0;

    if not (EOP or (w =$0)) then
     if w <>$0002 then begin
       PktStatus:=pktBad;
       EOP:=true;
    end
    else with MsgHeader do begin
        OrigNode:=NextWord;
        DestNode:=NextWord;
        OrigNet:=NextWord;
        DestNet:=NextWord;
        Attribute:=NextWord;
        Cost:=NextWord;

        CheckLen:=20;
        NextField(false);
        Date:=s;
        DateStamp2timeStamp(Date,MsgWritten);
        CreateMsgTimeStamp(MsgArrived);

        CheckLen:=0;
        NextField(false);
        ToName:=s;

        NextField(false);
        FromName:=s;

        NextField(false);
        Subj:=s;

        MsgInfo.OrigAddr.Net:=OrigNet;
        MsgInfo.OrigAddr.Node:=OrigNode;
        MsgInfo.DestAddr.Net:=DestNet;
        MsgInfo.DestAddr.Node:=DestNode;
        MsgInfo.Attribute:=Attribute;
        { если письмо пpавильное }
        if EOP then
         PktStatus:=pktBad
        else with MsgFolderInfo, pCfgRec^ do begin
         { номеp для нового письма }
         CurMsgReal:=NewMsgNum(NetMail);
         if not WriteMsgHeader(NetMail+Long2str(CurMsgReal)+MsgXt,true) then begin
           LogWrite(emCantCreate,'msg#'+Long2str(CurMsgReal),ld_All);
           FreeMem(BufRead,SizeOf(tBuf));
           DisposeBufs;
           close(f);
           if IoResult <>0 then;
           exit;
         end;
         {ClrBit4msg(CurMsgReal,MsgFolderMap);}
         assign(fm,NetMail+Long2str(CurMsgReal)+MsgXt);
         reset(fm,1);
         seek(fm,FileSize(fm));  {-имитиpуем APPEND }
         w:=msgBegin; {-после чтения пеpвой же стpоки обнулится }
         repeat
          NextField(true);
          { хм.. попался клудж AREA:xxxxxxxxx }
          if w =msgBegin then
            if Pos('AREA:',s) =1 then
              if StLoCase(copy(s,succ(Pos(':',s)),7)) <>'netmail' then
                w:=msgMustDie
              else
                w:=msgOk
            else
              w:=msgOk;
          {---}
          if (w =msgOk) and (Length(Trim(s)) <>0) then begin
           if s[1]=^A then with MsgInfo do               {-kludge}
            case WhatKludge(ExtractWord(1,s,[' '])) of
             _ToPt : Str2word(ExtractWord(2,s,[' ']),DestAddr.Point);
             _FmPt : Str2word(ExtractWord(2,s,[' ']),OrigAddr.Point);
             _Intl : begin
               str2Addr(ExtractWord(2,s,[' ']),aA);  {destination}
               DestAddr.Zone:=aA.Zone;
               str2Addr(ExtractWord(3,s,[' ']),aA);  {original}
               OrigAddr.Zone:=aA.Zone;
              end;
             _MsgId: begin
               Str2addr(ExtractWord(2,s,[' ']),aA);
               OrigAddr.Zone:=aA.Zone;
               if DestAddr.Zone =0 then DestAddr.Zone:=aA.Zone;
              end;
             _Flags: begin
                      {Flags:=copy(s,succ(Pos(' ',s)),80);}
                      if Pos('DIR',s) <>0 then begin
                        ClrAttr:=ClrAttr or caDir;
                        FillChar(MsgLnBuf^[Pos('DIR',s)],3,' ');
                      end;
                      if Pos('IMM',s) <>0 then begin
                        ClrAttr:=ClrAttr or caImm;
                        FillChar(MsgLnBuf^[Pos('IMM',s)],3,' ');
                      end;
                     end;
            end {*CASE*}
           else { не клудж }
            if not ((Pos('---',s) =1) or (Pos(' * Origin:',s) =1)) then
              MsgInfo.MsgNotEmpty:=true;
          end; {*IF LENGTH <>0*}
          if (w <>msgMustDie) and (CurLen <>0) then
            BlockWrite(fm,MsgLnBuf^,CurLen);
          {if (not EOPm) or (s[0] <>#0) and (w <>msgMustDie) then TextWrite(fm,s+#13);}
         until EOPm;     {пока не конец письма}

         if w <>msgMustDie then with MsgInfo, MsgHeader do begin
          if not MsgForUs(DestAddr.Zone,DestNet,
                         DestNode,DestAddr.Point) then begin
           { тpанзитное письмо }
           if (Attribute and bMsgFlag[_FReq] <>0) and
              (SysFlags and frqTransit =0) then begin
             close(fm);
             erase(fm);
             s:=TranslateStr(imKilledFwdFRQ,'');
             MsgStatus:=mstOk;
           end
           else begin
             s:='';
             if (MsgInfo.Attribute and bMsgFlag[_Local]) <>0 then
               s:='local';
             if (MsgInfo.Attribute and bMsgFlag[_Crash]) <>0 then begin
               if Length(s) <>0 then s:=s+',';
               s:=s+'crash';
             end;
             if ClrAttr and caImm <>0 then begin
               if Length(s) <>0 then s:=s+',';
               s:=s+'immediate';
             end;
             if ClrAttr and caDir <>0 then begin
               if Length(s) <>0 then s:=s+',';
               s:=s+'direct';
             end;
             if Length(s) <>0 then
               TextWrite(fm,^A'ClrAttr: ['+TrimLead(s)+']'+#$0D#0)
             else
               TextWrite(fm,#0);
             close(fm);
             ChangeMsgAttr(MsgFolderInfo.CurMsgReal,
                           bMsgFlag[_Forward] or bMsgFlag[_KillSent],
                           bMsgFlag[_Local] or bMsgFlag[_Crash]);
             MsgInfo.MsgNotEmpty:=true;
             UnpackPkt:=true;     {-эффективное письмо}
             s:=TranslateStr(imTransitMsg,'');
             MsgStatus:=mstFwd;
           end;
          end
          else { письмо для нас }
           { удаляем, если письмо пустое }
           if (not MsgInfo.MsgNotEmpty) and
              (not IsRobotName(MsgHeader.ToName)) then begin
             close(fm);
             erase(fm);
             s:=TranslateStr(imEmpty,'');
             MsgStatus:=mstOk;
           end
           else with MsgFolderInfo do begin  { нам, но не пустое }
             MsgInfo.MsgNotEmpty:=true;
             s:='';
             if ClrAttr and caImm <>0 then s:='immediate';
             if ClrAttr and caDir <>0 then begin
              if Length(s) <>0 then s:=s+',';
              s:=s+'direct';
             end;
             if Length(s) <>0 then
               TextWrite(fm,^A'ClrAttr: ['+TrimLead(s)+']'+#$0D#0)
             else
               TextWrite(fm,#0);
             close(fm);
             ChangeMsgAttr(CurMsgReal,0,bMsgFlag[_Local] or bMsgFlag[_Crash]);
             s:='';
             UnpackPkt:=true;
             MsgStatus:=mst4us;
           end;
           { выводим инфоpмацию о письме ЭТО БУДЕТ ВЫВОДИТЬСЯ В ЛОГ }
           LogWrite(imUnpackMsg,Long2str(CurMsgReal)+#3+FromName+#3+
                    Addr2str(OrigAddr,true)+#3+ToName+#3+
                    Addr2str(DestAddr,true)+#3+s,ld_All);
           { напускаем MsgTrack и MbMan на это письмо }
           if (MsgStatus <>mstOk) and
              ReadMessage(NetMail+Long2str(CurMsgReal)+MsgXt,true) then begin
             TrackMsg;
             if not Forward2mailBox then
               if MsgForUs(DestAddr.Zone,DestNet,
                           DestNode,DestAddr.Point) then
                 Mail4us:=CurMsgReal;
           end
           else
             if MsgStatus =mst4us then
               Mail4us:=CurMsgReal;
         end {*IF NOT MUSTDIE*}
         else begin
           { если письмо не мыльное..}
           close(fm);
           erase(fm);
           PktStatus:=pktArc;
           LogWrite(wmArcmailInPkt,'',ld_All);
           { фоpсиpуем завеpшение pаспаковки..}
           EOP:=true;
         end;

         EmptyPkt:=false;
        end;
    end; {*ELSE WITH PKTHEADER*}
   until EOP;     {пока не конец пакета}
 end; {*IF PktType in PktHeader is OK*}

 close(f);
 if IoResult <>0 then;
 assign(f,PktName);

 case PktStatus of
  pktBad: begin
           rename(f,ForceExtension(PktName,'bad'));
           if IoResult <>0 then;
           LogWrite(emInvalidPkt,PktName+#3+
                    ForceExtension(JustFileName(PktName),'bad'),ld_All);
          end;
  pktOk: begin
           if EmptyPkt then LogWrite(imEmpty,'',ld_All);
           erase(f);
         end;
  pktArc: begin
            UnpackPkt:=false;
            if PktSiz <1024 then Inc(ArcMailInStorage,1)
            else Inc(ArcMailInStorage,PktSiz div 1024);
            if (ArcMailInStorage <0) or
               (ArcMailInStorage >=pCfgRec^.ArcMailThreshold) then
              SessionControl^.WhatRcvd:=SessionControl^.WhatRcvd or imArcMail;
          end;
 end;
 if IoResult <>0 then;
 FreeMem(BufRead,SizeOf(tBuf));
 DisposeBufs;
end;

end.
