{$X+,I-,F+}

UNIT _Que_Viw;

INTERFACE

type
 mvExitCode=(mvec_Quit,mvec_Prev,mvec_Next);
 mvAction=(mva_ViewFirst,mva_ContView,mva_KillWin);

function ViewMsg(msgNo:word; mvA:mvAction):mvExitCode;

IMPLEMENTATION

uses
 TpCrt,
 Cfg,
 _SfM_Que,
 TpAsciiz,
 TpWindow,
 Tstring_,
 SfM_Api,
 aMsgBox;

type
 TmsgBuf=array[1..51200] of byte;
 TmsgHdr=record
  FromName   : array[1..36] of char; {.$0 Who from }
  ToName     : array[1..36] of char; {24 Who to   }
  Subj       : array[1..72] of char; {48 Message subject }
  Date       : array[1..20] of char; {90 Creation date (absolete) }
  TimesRead  : Word;       {A4 Number of times read }
  DestNode   : Word;       {A6 Destantion  node }
  OrigNode   : Word;       {A8 Originating node }
  Cost       : Word;       {AA Actual cost for this message }
  OrigNet    : Word;       {AC Originating net }
  DestNet    : Word;       {AE Destination net }
  MsgWritten : longint;    {B0 Creation time }
  MsgArrived : longint;    {B4 Arrival time  }
  Reply      : Word;       {B8 Thread to previous message }
  Attribute  : Word;       {BA Message flags }
  SeeAlso    : Word;       {BC Thread to next message }
  {Всего - 190 байт}
 end;

var
 bufSiz:word;
 buf:^TmsgBuf;
 fMsg:file;
 Only_Hdr:boolean;
 msgHdr:TmsgHdr;
 msgSiz:word;
 mw:WindowPtr;

 tearLn,      {No стpоки pазpеза}
 orgLn:word;  {No стpоки оpигина}

 _4Dfrom,
 _4Dto:tAddress;

 topLn:word;
 topOfs:word;
 totalLn:word;

 {$L TpMemo}
 function Scan(Limit:integer; ch:char; T:pointer):integer; external;

function A2S(var A):string;
var
 _A:Asciiz absolute A;

begin
 A2S:=Asc2str(_A);
end;

procedure FormatMsgText;
var
 i:word;
 z:byte;
 n:word;
 g,
 u:integer;
 s:string;

procedure ParseKludge;
var
 l:word;
 sk:string[7];

begin
 sk:=StLoCase(ExtractWord(1,s,[' ']));
 if sk =^A'intl' then begin
   Str2word(ExtractWord(2,s,[' ',':']),_4Dto.Zone);
   Str2word(ExtractWord(1,ExtractWord(3,s,[' ']),[':']),_4Dfrom.Zone);
 end
 else
  if sk =^A'topt' then
    Str2word(ExtractWord(2,s,[' ']),_4Dto.Point)
  else
   if sk =^A'fmpt' then
     Str2word(ExtractWord(2,s,[' ']),_4Dfrom.Point)
   else
    if sk =^A'msgid:' then begin
      Str2word(ExtractWord(2,s,[' ',':']),l);
      if _4Dfrom.Zone =0 then _4Dfrom.Zone:=l;
      if _4Dto.Zone =0 then _4Dto.Zone:=l;
    end;
end;

begin
 tearLn:=0;
 orgLn:=0;

 i:=0;
 z:=0;
 totalLn:=0;

 while i <msgSiz do begin
   Inc(i);
   if buf^[i] =$0D then z:=0
   else
    if buf^[i] =$8D then begin
      buf^[i]:=$0D;
      z:=0;
    end
    else
     if buf^[i] =$0A then begin  { убиpаем лишний код}
       move(buf^[i+1],buf^[i],msgSiz-i);
       Dec(msgSiz);
       Dec(i);
       if z =0 then
         Dec(totalLn);
     end
     else
      if z >76 then begin
        n:=i;
        while not (buf^[n] in [$20,$0D]) do Dec(n);
        if buf^[n] =$20 then begin
          buf^[n]:=$0D;
          i:=n;
        end
        else begin
          move(buf^[i],buf^[i+1],succ(msgSiz-i));
          buf^[i]:=$0D;
          Inc(msgSiz);
        end;
        z:=0;
      end
      else Inc(z);

   if z =0 then
     Inc(totalLn);
 end;

 topLn:=1;
 topOfs:=1;

 { посмотpим клуджи }
 n:=1;
 u:=msgSiz;
 i:=1;
 repeat
   g:=Scan(u,#$0D,@buf^[i]);
   if g <>0 then begin
     move(buf^[i],s[1],g);
     s[0]:=chr(g);
     if s[1] =^A then ParseKludge
     else
      if Pos('--- ',s) =1 then
        tearLn:=n
      else
       if Pos(' * Origin: ',s) =1 then
         orgLn:=n;
   end;
   Inc(n);
   Dec(u,succ(g));
   Inc(i,succ(g));
 until i >=msgSiz;
end;

procedure ShowScrollBar;
var
 b:byte;

begin
 if totalLn <=ScreenHeight-8 then
   b:=ScreenHeight-8
 else
   b:=(pred(topLn)+ScreenHeight-8)*(ScreenHeight-8) div pred(totalLn);
 FastVert(CharStr('█',b),7,80,$7);
 FastVert(CharStr('║',(ScreenHeight-8)-b),7+b,80,$7);
end;

procedure ShowMsgText;
var
 i:word;
 x,y:byte;

procedure ShowMsgLn;
var
 s:string;
 c:byte;

begin
 if i >msgSiz then begin
   s:='';
   c:=$7;
 end
 else begin
   s:='';
   while not (buf^[i] in [0,$0D]) do begin
     s:=s+chr(buf^[i]);
     Inc(i);
   end;
   Inc(i);
   if s[1] =#01 then
     c:=$8
   else
    if (topLn+(y-7) =tearLn) or (topLn+(y-7) =orgLn) then
      c:=$C
    else begin
     c:=Pos('>',s);
     if (c <>0) and (c <=10) then
       c:=$2
     else
       c:=$7;
    end;
 end;
 FastWrite(Pad(s,78),y,2,c);
end;

begin
 if Only_Hdr then begin
   FastCenter('·∙■ Not enough memory for message body ■∙·',12,$C);
   exit;
 end;
 i:=topOfs;
 for y:=7 to (ScreenHeight-2) do ShowMsgLn;

 ShowScrollBar;
end;

procedure UpLn;
var
 i:integer;

begin
 if Only_Hdr or (topLn =1) then exit;

 if topLn <>2 then begin
   i:=topOfs;
   Dec(topOfs,2);
   Inc(integer(topOfs),{pred} (Scan(-i,#$0D,@buf^[topOfs]))+1);
 end
 else
   topOfs:=1;
 Dec(topLn);

 ShowMsgText;
end;

procedure DownLn;
var
 i:integer;

begin
 if Only_Hdr or ((topLn+(ScreenHeight-8)) >totalLn) then exit;

 i:=succ(msgSiz-topOfs);
 Inc(topOfs,succ(Scan(i,#$0D,@buf^[topOfs])));
 Inc(topLn);

 ShowMsgText;
end;

procedure Go_To_Bottom;
var
 i:integer;

begin
 if Only_Hdr or
    (totalLn <(ScreenHeight-7)) or
    (topLn >=(totalLn-(ScreenHeight-8))) then exit;

 topLn:=1;
 topOfs:=1;
 repeat
   i:=succ(msgSiz-topOfs);
   Inc(topOfs,succ(Scan(i,#$0D,@buf^[topOfs])));
   Inc(topLn);
 until topLn =(totalLn-(ScreenHeight-9));

 ShowMsgText;
end;

procedure ShowViwHelp;
var
 hw:WindowPtr;

begin
 MakeWindow(hw, 24,ScreenHeight div 2 -3,56,ScreenHeight div 2 +4,
            true,true,true,$10,$1F,$1E,' Help, press key.. ');
 DisplayWindow(hw);
 FastWriteWindow( 'Up, Down - scroll text',2,4,$17);
 FastWriteWindow('Home, End - goto top, bottom',3,3,$17);
 FastWriteWindow(#26','#27' - next, prev msg',4,9,$17);
 FastWriteWindow(      'Esc - quit',5,9,$17);
 ReadKeyWord;
 KillWindow(hw);
end;

function ViewMsg(msgNo:word; mvA:mvAction):mvExitCode;
var
 c:byte;
 s:string;
 _done:boolean;
 mvec:mvExitCode;

begin
 ViewMsg:=mvec_Quit;
 if mvA =mva_ViewFirst then begin
  MakeWindow(mw,1,1,80,pred(ScreenHeight),true,true,true,
             $7,$7,$B,' Msg #'+Long2str(msgNo)+' ');
  DisplayWindow(mw);
  { выставляем метки }
  FastWrite('From:',3,2,$F);
  FastWrite('To:',4,4,$F);
  FastWrite('Subj:',5,2,$F);
 end
 else
  if mvA =mva_KillWin then begin
   KillWindow(mw);
   exit;
  end
  else { continue view }
   FrameWindow(1,1,80,pred(ScreenHeight),$7,$B,' Msg #'+Long2str(msgNo)+' ');

 FillChar(_4Dfrom,SizeOf(tAddress),0);
 FillChar(_4Dto,SizeOf(tAddress),0);
 FastWrite(CharStr('─',78),6,2,$E);

 assign(fMsg,pCfgRec^.NetMail+Long2str(msgNo)+'.msg');
 reset(fMsg,1);
 if IoResult <>0 then begin
   MessageBox('Unable to open '+Long2str(msgNo)+' msg',
              tOk,tOk,bButton[tOk],ambClrs,'Error..');
   KillWindow(mw);
   exit;
 end;

 if FileSize(fMsg) >=MaxAvail then begin
   Only_Hdr:=true;
   MessageBox('Not enough memory to view '+Long2str(msgNo)+' msg',
              tOk,tOk,bButton[tOk],ambClrs,'Error..');
 end
 else begin
   Only_Hdr:=false;
   FastWrite(' '+Long2str(FileSize(fMsg))+' ',6,4,$B);
   bufSiz:=FileSize(fMsg)-189;
   GetMem(buf,bufSiz);
   FillChar(buf^,bufSiz,0);
   BlockRead(fMsg,msgHdr,SizeOf(TmsgHdr));
   BlockRead(fMsg,buf^,FileSize(fMsg)-189,msgSiz);
   FormatMsgText;
 end;
 close(fMsg);

 with msgHdr do begin
  with _4Dfrom do begin
    Net:=OrigNet;
    Node:=OrigNode;
  end;
  with _4Dto do begin
    Net:=DestNet;
    Node:=DestNode;
  end;
 end;

 { вывод шапки }
 FastWrite(A2S(msgHdr.Date),2,4,$3);
 s:=A2S(msgHdr.FromName);
 if StLoCase(s) =StLoCase(pCfgRec^.SysOp) then c:=$E
 else c:=$7;
 FastWrite(Pad(s,70),3,8,c);
 FastWrite(Pad(A2S(msgHdr.ToName),70),4,8,$7);
 FastWrite(Pad(A2S(msgHdr.Subj),70),5,8,$7);
 FastWrite(_4D2str(_4Dfrom),3,46,$7);
 FastWrite(_4D2str(_4Dto),4,46,$7);
 FastWrite(LeftPad(MsgAttrs2str(msgHdr.Attribute),32),2,47,$C);

 FastWrite(' press F1 for help..',pred(ScreenHeight),58,$F);

 ShowMsgText;
 _done:=false;
 mvec:=mvec_Quit;

 repeat
  case ReadKeyWord of
   $011B: _done:=true; {esc}
   $4800: UpLn;        {up}
   $5000: DownLn;      {down}
   $4700: if (totalLn >(ScreenHeight-8)) and (not Only_Hdr) then begin {home}
            topLn:=1;
            topOfs:=1;
            ShowMsgText;
          end;
   $4F00: Go_To_Bottom;   {end}
   $3B00: ShowViwHelp;    {F1}
   { list messages }
   $4B00: begin {left (previouse)}
           _done:=true;
           mvec:=mvec_Prev;
          end;
   $4D00: begin {right (next)}
           _done:=true;
           mvec:=mvec_Next;
          end;
  end;
 until _done;

 if not Only_Hdr then FreeMem(buf,bufSiz);
 if mvec =mvec_Quit then KillWindow(mw);
 ViewMsg:=mvec;
end;

end.
