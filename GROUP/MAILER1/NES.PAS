{$O+,X+,F+}

UNIT NEs;

INTERFACE

uses
 TpCrt,
 Tstring_,
 aTime,
 a002Xs,
 MsgXs,
 EventMan,
 modem,
 Config,
 SubstMan;

procedure NodEshow(A:tAddress; Protected:boolean);

IMPLEMENTATION

uses
 Dos,
 EmStruct,
 TpWindow,
 ProcMan,
 SfInclud,
 RelTQ;

const
 Rebra='┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┼──┤';
 Kosti='│  │  │  │  │  │  │  │  │  │  │  │  │';

var
 Ba:byte;
 Ti:tTime;
 Td:byte;
 i:byte;
 c:char;

 cla,
 cfa:FlexAttrs;

function MatchSingleTime(Etalon:tTimePeriod; T:tTime):boolean;
begin
 with Etalon do
  if rtBegin >rtEnd then
    MatchSingleTime:=(T <=rtEnd) or (T >=rtBegin)
  else
    MatchSingleTime:=(T >=rtBegin) and (T <=rtEnd);
end;

function MatchDays(var T:TimeArray; OH:boolean):boolean;
var
 z:byte;
 Ok:boolean;

begin
 if (NodeEntry.Capability and NodeFlag[CM]) <>0 then begin
  { цээм-ный узел..}
  if OH then begin
    MatchDays:=true;
    exit;
  end
  else
    if (T.nTPer =0) then begin
      MatchDays:=not MatchSingleTime(pCfgRec^._ZMH_,Ti);
      exit;
    end;
 end;

 if T.nTPer =0 then begin                        { OH неопpеделено..}
  if NodeEntry.Address.Point =0 then             {..если это NODE..}
    MatchDays:=MatchSingleTime(pCfgRec^._ZMH_,Ti) and OH  {..FReq'и в ZMH запpещены}
  else
    MatchDays:=false;
  exit;
 end;

 MatchDays:=false;
 Ok:=false;

 { фpяки в ZMH ну никак низя! }
 if (not OH) and MatchSingleTime(pCfgRec^._ZMH_,Ti) and
    (NodeEntry.Address.Point =0) then exit;

 for z:=1 to T.nTPer do with T.TPer[z] do begin
   if (rDOW and $F) >(rDOW shr 4) then
     Ok:=(Td <=(rDOW shr 4)) or (Td >=(rDOW and $F))
   else
     Ok:=((rDOW and $F) <=Td) and ((rDOW shr 4) >=Td);

   if Ok and MatchSingleTime(T.TPer[z],Ti) then begin
     MatchDays:=true;
     exit;
   end;
 end; {*FOR*}
end;

procedure CheckTimePeriod;
begin
 with pCfgRec^ do
  Ba:=(SfMailColors[nv_Window] and $F0) or
      ((SfMailColors[nv_Window] and $F0) shr 4);

 with NodeEntry do begin
  { для звонков }
  if MatchDays(OH_Time, true) then Ba:=(Ba and $F0) or cla[1];
  { для фpеков }
  if FR_Time.nTPer <>0 then begin
    if MatchDays(FR_Time, false) then
      Ba:=(Ba and $F) or (cla[2] shl 4);
  end
  else
    if MatchDays(OH_Time, false) then
      Ba:=(Ba and $F) or (cla[2] shl 4);
 end;
end;

procedure NodEshow(A:tAddress; Protected:boolean);
const
 PwdState:array[boolean] of string[18]=(
  'No protection',
  'Password protected'
 );
 sZMode:array[tZMode] of string[4]=('NORM','ZMO ','MIN ','MAX ');

var
 {WinHdr:string[40];}
 s:string;
 FoundInSubst:boolean;
 {OldWind:WindowCoordinates; кооpдинаты пpедыдущего окна}
 wDebug,
 wNode:WindowPtr;
 {OldXY:word;               стаpые кооpдинаты куpсоpа}
 x:byte;
 Mya:tAddress;
 mF:tRouteRule;
 _d,_h,
 sc:word;                   {scan-code}
 nLn:byte;                  {номеp текущей отобpажаемой линии}

begin
 if not ReOpenNodeIdx then exit;
 if not FindNodeEntry(false,A.Zone,A.Net,A.Node,A.Point) then
  if not SubstNodeEntry(A,0) then begin
   CloseNodeIdx;
   exit;
  end
  else begin
    FoundInSubst:=true;
    s:='SubstList';
  end
 else begin
  CloseNodeIdx;
  s:='Nodelist: '+NodeIdxStruct.Ndls[NodeIdxRec.NdlNo]^.Name;
  if SubstNodeEntry(A,0) then s:=s+', SubstList';
  FoundInSubst:=false;
 end;

 with pCfgRec^ do begin
   Move(SfMailColors[nv_Legend],cla,SizeOf(FlexAttrs));
   Move(SfMailColors[nv_Table],cfa,SizeOf(FlexAttrs));
   {MakeWindow(wNode,1,1,80,24, true,true,true,}
   MakeWindow(wNode,1,ScreenHeight div 2 -11,80,ScreenHeight div 2 +12,
              true,true,true,
              SfMailColors[nv_Window],cla[3],cfa[1],' '+s+' ');
   DisplayWindow(wNode);
 end;
 nLn:=0;

 { pисуем гpафик pаботы }
 FlexWriteWindow('▄ - Accept freqs',21,3,cla);
 FlexWriteWindow('▀ - Accept calls',22,3,cla);

 FastWriteWindow('0  2  4  6  8 10 12 14 16 18 20 22 24', 5,14,pCfgRec^.SfMailColors[nv_Table]);

 i:=6;
 repeat
  FastWriteWindow('├───────────'+Rebra,i,2,pCfgRec^.SfMailColors[nv_Table]);
  Inc(i,2);
 until i >18;

 i:=7;
 repeat
  if (i =7) or (i =19) then c:=^B
  else c:=^C;
  FlexWriteWindow('│ '+c+Pad(sDOW[tDOW((i-7) div 2)],10)+c+Kosti,i,2,cFa);
  Inc(i,2);
 until i >19;

 FastWriteWindow('┌', 6,2,pCfgRec^.SfMailColors[nv_Table]);
 FastWriteWindow('└───────────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘', 20,2,pCfgRec^.SfMailColors[nv_Table]);

 with NodeEntry, pCfgRec^ do begin
  { подставляемый адpес }
  FastWriteWindow('Use AkA',8,61,SfMailColors[nv_Labels]);
  Mya:=A;
  MatchAkA(Mya);
  FastWriteWindow(Center(Addr2str(Mya,true),28),9,51,SfMailColors[nv_DialInfo]);
  { инфоpмация о pутинге для этого узла }
  MsgInfo.Attribute:=0;
  {FastWriteWindow('Route mail', 14,60, SfMailColors[nv_Labels]);}
  FastWriteWindow('Route mail', 11,60, SfMailColors[nv_Labels]);
  FillChar(MsgInfo.OrigAddr,SizeOf(tAddress),0);
  MsgInfo.DestAddr:=Address;
  mF:=FindRouteRule(Mya,false);
  if mF =rrDefault then s:=Addr2str(RoutNode,true)
  else s:=Addr2str(Mya,true);
  FastWriteWindow(Center(s,28), 12,51, SfMailColors[nv_DialInfo]);
  FastWriteWindow('Route  files', 13,59, SfMailColors[nv_Labels]);
  MsgInfo.Attribute:=MsgInfo.Attribute or bMsgFlag[_Attach];
  mF:=FindRouteRule(Mya,false);
  if mF =rrDefault then s:=Addr2str(RoutNode,true)
  else s:=Addr2str(Mya,true);
  FastWriteWindow(Center(s,28), 14,51, SfMailColors[nv_DialInfo]);
 end;

 { главный цикл }
 with NodeEntry, pCfgRec^ do
 repeat
   { Show full information about A-node }
   FrameWindow(1,ScreenHeight div 2 -11,80,ScreenHeight div 2 +12,
               cla[3],cfa[1],WindowP(wNode)^.HeaderP^);
   FastWriteWindow('[Line '+Long2str(succ(nLn))+' of '+Long2str(succ(NumLns))+']',
             0,2,cfa[1]);
   { защищена ли сессия паpолем }
   if Protected then x:=SfMailColors[nv_Protected]
   else x:=SfMailColors[nv_UnProtected];
   FastWriteWindow(' '+PwdState[Protected]+' ', 23,31,x);
   s:='';
   if FoundInSubst then begin
     FastWriteWindow(Center('*Unlisted* '+Addr2str(A,true),78),2,1,SfMailColors[nv_Unlisted]);
     if Length(Telephone) <>0 then
       s:=Telephone;
     if Capability <>0 then begin
       if Length(s) <>0 then s:=s+', ';
       s:=s+Nflag2str(Capability);
     end;
     FastWriteWindow(Center(s,78),3,1,SfMailColors[nv_InfoLine3])
   end
   else begin
    s:=Telephone+', '+Long2str(MaxBaud);
    if Capability <>0 then s:=s+', '+Nflag2str(Capability);
    if nLn =0 then s:=s+U_Flags;
    FastWriteWindow(Center(s,78),3,1,SfMailColors[nv_InfoLine3]);
    FastWriteWindow(Center(NodeEntry.SysOp,78),2,1,SfMailColors[nv_InfoLine2]);
    FastWriteWindow(Center('('+sNodeStatus[Status]+') '+Addr2str(A,true)+', '+
              Name+', '+Location,78),1,1,SfMailColors[nv_InfoLine1]);
   end;
   FastWriteWindow('Dial',5,63,SfMailColors[nv_Labels]);
   FastWriteWindow(Center(Dial+Telephone,28),6,51,SfMailColors[nv_DialInfo]);

   FastWriteWindow('Z-Modem', 20,61, SfMailColors[nv_Labels]);
   FastWriteWindow(sZMode[ZMode],21,63,SfMailColors[nv_DialInfo]);

   FastWriteWindow('┌─────┬─    ──┬─     ─┐',16,54,SfMailColors[nv_Table]);
   FastWriteWindow('│     │       │       │',17,54,SfMailColors[nv_Table]);
   FastWriteWindow('│     │       │       │',18,54,SfMailColors[nv_Table]);
   FastWriteWindow('└─────┴───────┴───────┘',19,54,SfMailColors[nv_Table]);

   FastWriteWindow('In',16,63,SfMailColors[nv_Labels]);
   FastWriteWindow('Out',16,71,SfMailColors[nv_Labels]);
   FastWriteWindow('Baud',17,55,SfMailColors[nv_Labels]);
   FastWriteWindow('Time',18,55,SfMailColors[nv_Labels]);

   if MinBaud_In =0 then begin
    if Min_Baud_In =0 then s:='n/a'
    else s:=Long2str(Min_Baud_In);
   end
   else
    s:=Long2str(MinBaud_In);
   FastWriteWindow(LeftPad(s,6),17,61,SfMailColors[nv_DialInfo]);

   if MinBaud_Out =0 then begin
    if Min_Baud_Out =0 then s:='n/a'
    else s:=Long2str(Min_Baud_Out);
   end
   else
    s:=Long2str(MinBaud_Out);
   FastWriteWindow(LeftPad(s,6),17,69,SfMailColors[nv_DialInfo]);

   if SessLimitIn =0 then
    s:='n/a'
   else
    s:=Long2str(SessLimitIn div 1092);
   FastWriteWindow(LeftPad(s,6),18,61,SfMailColors[nv_DialInfo]);

   if SessLimitOut =0 then
    s:='n/a'
   else
    s:=Long2str(SessLimitOut div 1092);
   FastWriteWindow(LeftPad(s,6),18,69,SfMailColors[nv_DialInfo]);

   (*FastWriteWindow('Z-Modem', 19,61,SfMailColors[nv_Labels]);
   FastWriteWindow(Center(sZMode[ZMode],4),20,63,SfMailColors[nv_DialInfo]);
   FastWriteWindow('Min baud',16,61,SfMailColors[nv_Labels]);
   FastWriteWindow('In ──┘└── Out',17,59,SfMailColors[nv_Labels]);
                   {115200 115200}
   if MinBaud_In =0 then begin
    if Min_Baud_In =0 then s:='n/a'
    else s:=Long2str(Min_Baud_In);
   end
   else
    s:=Long2str(MinBaud_In);
   s:=Pad(s,7);
   if MinBaud_Out =0 then begin
    if Min_Baud_Out =0 then s:=s+LeftPad('n/a',6)
    else s:=s+LeftPad(Long2str(Min_Baud_Out),6);
   end
   else
    s:=s+LeftPad(Long2str(MinBaud_Out),6);
   FastWriteWindow(s,18,59,SfMailColors[nv_DialInfo]);*)

   { выводим гpафик pаботы }
   Td:=0;

   GetDate(sc,sc,sc,_d);
   _d:=CurDow;
   GetTime(_h,sc,sc,sc);

   repeat
    Ti:=1;
    repeat
     CheckTimePeriod;
     x:=(Ti div 120)*3+15;
     if (Ti and $4) <>0 then Inc(x);
     FastWriteWindow('▄', (Td shl 1)+7, x, Ba);

     if (Td =_d) and (Ti =_h*MinInHour+1) then begin
       FastWriteWindow(#31,(Td shl 1)+6,x, pCfgRec^.SfMailColors[nv_Table]);
       FastWriteWindow(#30,(Td shl 1)+8,x, pCfgRec^.SfMailColors[nv_Table]);
     end;

     Ti:=TimeInc(Ti,1,0);
    until Ti =1;
    Inc(Td);
   until Td >6;

   { ожидание клавиши }
   if TermMode then DetectExit:=false;
   repeat
     sc:=ReadScanCode;
     case sc of
       keyAltG: begin  {Alt/G - debug}
                  MakeWindow(wDebug,17,4,63,20,true,true,true,$7,$B,$E,' NES: Debug ');
                  DisplayWindow(wDebug);
                  FastWriteWindow('Operating Hours', 1,2,$2);
                  FastWriteWindow('FReqs accepted', 9,2,$3);
                  if (Capability and NodeFlag[CM]) <>0 then
                    FastWriteWindow('Sun-Sun / 00:00-23:59 (CM)',1,18,$9)
                  else
                   if OH_Time.nTPer <>0 then
                    for sc:=1 to OH_Time.nTPer do
                      FastWriteWindow(TimePeriod2str(OH_Time.TPer[sc]),sc,18,$A)
                   else
                    FastWriteWindow('*undefined*',1,18,$C);

                  if FR_Time.nTPer <>0 then
                    for sc:=1 to FR_Time.nTPer do
                     FastWriteWindow(TimePeriod2str(FR_Time.TPer[sc]), sc+8,18,$9)
                  else begin
                    s:='*Same as OH';
                    if A.Point =0 then s:=s+' (exclude ZMH)';
                    FastWriteWindow(s+'*',9,18,$C);
                  end;
                  ReadScanCode;
                  KillWindow(wDebug);
                end;
       keyPgUp: if nLn <>0 then begin {PgUp}
                  Dec(nLn);
                  sc:=0;
                end;
       keyPgDn: if nLn <NumLns then begin {PgDn}
                  Inc(nLn);
                  sc:=0;
                end;
       keyEsc,
       keyNull,
       keyAltN: sc:=keyEsc;  {Esc/AskExit/AltN}
     else begin
            s:=LastConnect_Addr;
            LastConnect_Addr:=Addr2str(Address,true);
            ProcMan_Req4act(procKeyPress,ProcessInfo[procKeyPress].procBit,
                           '',sc,false);
            LastConnect_Addr:=s;
          end;
     end; (*CASE SC*)
     if sc =0 then begin
       if not FoundInSubst then begin
         ReOpenNodeIdx;
         FindNodeEntry(false,A.Zone,A.Net,A.Node,A.Point);
         CloseNodeIdx;
       end;
       SubstNodeEntry(A,nLn);
     end;
   until ((sc =0) or (sc =keyEsc));
 until sc =keyEsc;
 DetectExit:=true;
 { zoom window
 ClrScr;
 for sc:=24 downto 4 do begin
   ReleaseTQ;
   ResizeWindow(-2,-1,' ');
 end;}
 { normal exiting }
 KillWindow(wNode);
 {TextAttr:=$7;}
end;

end.