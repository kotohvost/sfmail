{$X+,O+,F+}

{$I SfDefine.inc}

UNIT aQM;

INTERFACE

procedure QueueManager;

IMPLEMENTATION

uses
 Config,
 Dos,
 TpCrt,
 TpWindow,
 Tstring_,
 aTime,
 MsgXs,
 EmStruct,
 EventMan,
 a002xs,
 SubstMan,
 Em_Cpl,
 SwapR,
 RelTQ,
 NES,
 WriteLog,
 ProcMan,
 SfInclud,
 Pwd_Xs,
 Sf_Pick,
 Flags;
 {HIPman;}

procedure QueMan_Help;
var
 queHlpW:WindowPtr;

begin
 with pCfgRec^ do begin
   MakeWindow(queHlpW,14,ScreenHeight div 2 -10,65,ScreenHeight div 2 +9,
              true,true,true,SfMailColors[Session_Border],
              SfMailColors[Session_Border],SfMailColors[Session_Header],
              ' Help for que manager ');
   DisplayWindow(queHlpW);
   FastWriteWindow(    #24#25'  - one item up/down',2,11,SfMailColors[Session_File]);
   FastWriteWindow(  'Home/End  - goto beginning/end of que',3,5,SfMailColors[Session_File]);
   FastWriteWindow( 'PgUp/PgDn  - one page up/down',4,4,SfMailColors[Session_File]);
   FastWriteWindow(         'P  - toggle PRIOrity status',5,12,SfMailColors[Session_File]);
   FastWriteWindow(         'I  - toggle IMMediate status',6,12,SfMailColors[Session_File]);
   FastWriteWindow(         'H  - toggle HOLD status',7,12,SfMailColors[Session_File]);
   FastWriteWindow(         'X  - toggle HXT status',8,12,SfMailColors[Session_File]);
   FastWriteWindow(         'Q  - toggle HRQ status',9,12,SfMailColors[Session_File]);
   FastWriteWindow(         'C  - reset ALL flags for item',10,12,SfMailColors[Session_File]);
   FastWriteWindow(         'U  - toggle UNDIALABLE status',11,12,SfMailColors[Session_File]);
   FastWriteWindow(        'BS  - unpack',12,11,SfMailColors[Session_File]);
   FastWriteWindow(       'Del  - unpack`n`kill Sf-Mail robot msgs',13,10,SfMailColors[Session_File]);
   FastWriteWindow('Ctrl/Enter  - set que pointer on current item',14,3,SfMailColors[Session_File]);
   FastWriteWindow(     'Alt/N  - show info about node',15,8,SfMailColors[Session_File]);
   FastWriteWindow(       'Esc  - return to main window',16,10,SfMailColors[Session_File]);
   FastWriteWindow(     'Enter  - run xternal que manager',17,8,SfMailColors[Session_File]);
   FastWrite(' press any key..',ScreenHeight div 2 +9,48,SfMailColors[Session_Header]);
 end;
 ReadScanCode;
 KillWindow(queHlpW);
end;

function UndialableAddr(n:word):boolean;
begin
 with NodeEntry, pCfgRec^ do begin
   Max_Tries:=CallTries;
   SubstNodeEntry(Que[n]^.DestAddr,0);
   UndialableAddr:=Que[n]^.Try >=Max_Tries;
 end;
end;

procedure WriteItem(n:word; y:byte; width:byte; Selected:boolean);
var
 sa:string[19];
 c:char;
 qc:tSfMailColors;

begin
 if Que[n] =nil then
  FastWriteWindow(Pad('',width),y,1, pCfgRec^.SfMailColors[qm_Window])
 else with Que[n]^ do begin
  if (Que[n]^.omMask and omNamedPoll) <>0 then begin
   sa:=Pad(NamedPoll2str(Que[n]^.DestAddr),19);
   if not Selected then
    qc:=qm_ActiveAddr
   else
    qc:=qm_ActiveMarker;
  end
  else begin
   sa:=Pad(Addr2str(DestAddr,DestAddr.Point <>0),19);
   { пpовеpка на Undialable }
   if UndialableAddr(n) then begin
    if not Selected then
     qc:=qm_Undialable
    else
     qc:=qm_UndialMarker;
   end
   else
    if ActiveItem then
     if Selected then
      qc:=qm_ActiveMarker
     else
      qc:=qm_ActiveAddr
    else
     if Selected then
      qc:=qm_Marker
     else
      qc:=qm_NormalAddr;
  end;
  { метим текущий элемент }
  if ((Que[succ(CurQue)] =nil) and (n =1)) or (n =succ(CurQue)) then c:=#16
  else c:=' ';

  FastWriteWindow(c+sa+
    LeftPad(Long2str(Try),5)+
    LeftPad(vInBestForm(MailSize),10)+
    LeftPad(vInBestForm(FileSize+NormalBoxSize),8)+
    LeftPad(vInBestForm(HoldMailSize+HoldFileSize+HoldBoxSize),8)+' ',
    y,2,pCfgRec^.SfMailColors[qc]);

  with pCfgRec^ do begin
   { IMM }
   if CheckHIP(DestAddr,tpImm) then
    FastWriteWindow('Imm', y,55,pCfgRec^.SfMailColors[qm_ImmAttr])
   else
    FastWriteWindow('···', y,55,pCfgRec^.SfMailColors[qm_NormalAddr]);
   { PRIO }
   if CheckHIP(DestAddr,tpPrio) then
    FastWriteWindow('Prio', y,59,pCfgRec^.SfMailColors[qm_PrioAttr])
   else
    FastWriteWindow('····', y,59,pCfgRec^.SfMailColors[qm_NormalAddr]);
   { HOLD }
   if CheckHIP(DestAddr,tpHold) then
    FastWriteWindow('Hold', y,64,pCfgRec^.SfMailColors[qm_HoldAttr])
   else
    FastWriteWindow('····', y,64,pCfgRec^.SfMailColors[qm_NormalAddr]);
   { HXT }
   if CheckHIP(DestAddr,tpHXT) then
    FastWriteWindow('HXT', y,69,pCfgRec^.SfMailColors[qm_HXTattr])
   else
    FastWriteWindow('···', y,69,pCfgRec^.SfMailColors[qm_NormalAddr]);
   { HRQ }
   if CheckHIP(DestAddr,tpHRQ) then
    FastWriteWindow('HRQ', y,73,pCfgRec^.SfMailColors[qm_HRQattr])
   else
    FastWriteWindow('···', y,73,pCfgRec^.SfMailColors[qm_NormalAddr]);
  end;
 end; (*WITH Que[n]^*)
end;

procedure QueueManager;
var
 OldWind:WindowCoordinates; {кооpдинаты пpедыдущего окна}
 OldXY:word;                {стаpые кооpдинаты куpсоpа}
 wQue:WindowPtr;

 nTopItem,            {# пункт в веpхней строке}
 nCurItem,            {# тек.пункт}
 nTotalItems:integer; {всего элементов в очереди}

 RedrawQue,
 SetMarker:boolean;

 tmpStr:string[19];
 w:word;

procedure SetItemPriority(prio:tPriority);
var
 _z:word;

begin
 with Que[nCurItem]^ do
  if (omMask and omNamedPoll) <>0 then
   exit
  else begin
   FillChar(HIPtmp.hipEnd,SizeOf(tHIPend),$FF);
   Move(DestAddr,HIPtmp.hipAddr,SizeOf(tAddress));
   _z:=FindHIP4addr(DestAddr);
   if _z <>0 then
    Move(HIParray[_z]^,HIPtmp,SizeOf(tHIPflag));
 end;

 if HIPtmp.hipEnd[prio] <>NoPriority then
  { reset priority }
  HIPtmp.hipEnd[prio]:=NoPriority
 else
  { set priority }
  HIPtmp.hipEnd[prio]:=CurUnixTime+SecInMin*pCfgRec^.HIP_Time;

 AddHIP;
 CorrectHIP;
 Que[nCurItem]^.ActiveItem:=CanCallNode(nCurItem);
 SetMarker:=true;
end;

procedure ClrItemPriority;
var
 _z:word;

begin
 with Que[nCurItem]^ do
  if (omMask and omNamedPoll) =0 then begin
    SetMarker:=true;
    _z:=FindHIP4addr(DestAddr);
    if _z <>0 then begin
      FillChar(HIParray[_z]^.hipEnd,SizeOf(tHIPend),$FF);
      CorrectHIP;
      Que[nCurItem]^.ActiveItem:=CanCallNode(nCurItem);
    end;
  end;
end;

procedure ToggleUndialable;
begin
 if (Que[nCurItem]^.omMask and omNamedPoll) =0 then begin
  if UndialableAddr(nCurItem) then
   Que[nCurItem]^.Try:=0
  else
   Que[nCurItem]^.Try:=255;
  SetMarker:=true;
 end;
end;

begin
 OldXY:=WhereXY;
 StoreWindowCoordinates(OldWind);
 with pCfgRec^ do begin
  MakeWindow(wQue,1,1,80,pred(ScreenHeight),true,true,true,
             SfMailColors[qm_Window],SfMailColors[qm_Border],
             SfMailColors[qm_Header],'');
  DisplayWindow(wQue);
  FastWrite(
  '══════ Node ═══════ Tries ═══ Mail ══ File ══ Hold ═════════ Flags ═════════',
  1,3,SfMailColors[qm_Header]);
                                                       {Imm Prio Hold HXT HRQ}
  TextAttr:=SfMailColors[qm_Window];
 end;

 FillChar(QueTmp,SizeOf(tQueueRec),0);
 nTotalItems:=0;
 for nCurItem:=1 to MaxQue do
   if Que[nCurItem] <>nil then with Que[nCurItem]^ do begin
     Inc(nTotalItems);
     Inc(QueTmp.MailSize,MailSize);
     Inc(QueTmp.FileSize,FileSize);
     Inc(QueTmp.HoldMailSize,HoldMailSize);
     Inc(QueTmp.HoldFileSize,HoldFileSize);
     Inc(QueTmp.HoldBoxSize,HoldBoxSize);
     Inc(QueTmp.NormalBoxSize,NormalBoxSize);
     if CheckHIP(DestAddr,tpHold) or (omMask and omActive =0) then
      ActiveItem:=false
     else
      if (Que[nCurItem]^.omMask and omNamedPoll) <>0 then
       ActiveItem:=true
      else
       ActiveItem:=CanCallNode(nCurItem);
   end;

 with QueTmp do
  FastWrite('Total:  Mail '+vInBestForm(MailSize+HoldMailSize)+
            ' Files '+vInBestForm(FileSize+HoldFileSize)+
            ' Boxes '+vInBestForm(NormalBoxSize+HoldBoxSize),
            ScreenHeight-1,4,pCfgRec^.SfMailColors[qm_Header]);

 {done:=false;}
 nTopItem:=1;
 nCurItem:=1;
 DrawProc:=@WriteItem;
 RedrawQue:=true;

 repeat
  if nTotalItems <>0 then begin
   PickBar(wQue,RedrawQue,SetMarker,nTotalItems,nCurItem,nTopItem);
   case PickExit of
    peSelect: {run xternal queue manager}
        if (Que[nCurItem]^.omMask and omNamedPoll) =0 then begin
         SaveQueue;
         if ReopenNodeIdx then with Que[nCurItem]^ do begin
          if FindNodeEntry(true,DestAddr.Zone,DestAddr.Net,
                           DestAddr.Node,DestAddr.Point) then begin
           CloseNodeIdx;
           {$IFNDEF NoComm}
           Swap_Run('{!}'+pCfgRec^.SfM_Que_Path+'SfM_Que.exe '+
                    Addr2str(DestAddr,true)+' '+
                    Long2str(Task)+' '+CfgFileName+
                    ' '+NodeIdxStruct.Ndls[NodeIdxRec.NdlNo]^.Name+
                    ' '+Long2str(NodeIdxRec.NdlOfs),false);
           {$ELSE}
           TextAttr:=$40; write(^G);
           {$ENDIF}
          end
          else begin
           CloseNodeIdx;
           {$IFNDEF NoComm}
           Swap_Run('{!}'+pCfgRec^.SfM_Que_Path+'SfM_Que.exe '+
                    Addr2str(DestAddr,true)+' '+
                    Long2str(Task)+' '+CfgFileName,false);
           {$ELSE}
           TextAttr:=$40;
           {$ENDIF}
          end;
          TextAttr:=pCfgRec^.SfMailColors[qm_Window];
         end;
        end;
    peUser:
      case PickCode of
       keyAltB: PickExit:=peQuit;
       (*keyAltF: begin
                 HIPmanager;
                 DrawProc:=@WriteItem;
                 TextAttr:=pCfgRec^.SfMailColors[qm_Window];
                 RedrawQue:=true;
                 PickExit:=peNone;
                end;*)
       keyP,keyShP: SetItemPriority(tpPrio);
       keyH,keyShH: SetItemPriority(tpHold);
       keyI,keyShI: SetItemPriority(tpImm);
       keyQ,keyShQ: SetItemPriority(tpHRQ);
       keyX,keyShX: SetItemPriority(tpHXT);
       keyC,keyShC: ClrItemPriority;
       keyU,keyShU: ToggleUndialable;
       keyAltN: {Alt/N: Show about node}
         if (Que[nCurItem]^.omMask and omNamedPoll) =0 then with Que[nCurItem]^ do
          NodeShow(DestAddr,CheckPassword(DestAddr));
       keyDel: {удалить элемент очеpеди и письма от Sf-Mail robot`а}
         with Que[nCurItem]^ do begin
          if (omMask and omNamedPoll) <>0 then begin
           DeleteFlag(pCfgRec^.Flags_Dir+NamedPoll2str(DestAddr)+nplXt);
           Squeze_Que(nCurItem);
           Dec(QLsize,SizeOf(tQueueRec));
          end
          else
           EraseQueue(nCurItem,true);
          RedrawQue:=true;
          Dec(nTotalItems);
         end;
       keyBS: {удалить элемент очеpеди}
         if (Que[nCurItem]^.omMask and omNamedPoll) =0 then begin
          Dec(nTotalItems);
          EraseQueue(nCurItem,false);
          RedrawQue:=true;
         end;
       keyCtrlEnter: {уст.ук.на тек элемент}
        begin
         if nCurItem =1 then begin
          w:=1;
          while w <=MaxQue do
           if Que[w] =nil then begin
            CurQue:=pred(w);
            w:=MaxQue_reserv;
           end
           else
            Inc(w);
         end
         else
          CurQue:=pred(nCurItem);
         RedrawQue:=true;
         {SetMarker:=true;}
        end;
      else with Que[nCurItem]^ do begin
            tmpStr:=LastConnect_Addr;
            if (omMask and omNamedPoll) <>0 then
             LastConnect_Addr:=NamedPoll2str(DestAddr)
            else
             LastConnect_Addr:=Addr2str(DestAddr,true);
            ProcMan_Req4act(procKeyPress,ProcessInfo[procKeyPress].procBit,
                            '',PickCode,false);
            LastConnect_Addr:=tmpStr;
           end;
      end; (*CASE PICKCODE*)
    peHelp: QueMan_Help;
    peQuit: PickExit:=peQuit;
   end; (*CASE PICKEXIT*)
  end
  else with pCfgRec^ do begin { que is empty }
   ClrScr;
   FastCenter('<*Mail queue is empty*>',6,SfMailColors[qm_Undialable]);
   PickCode:=ReadScanCode;
   if (PickCode =keyEsc) or (PickCode =keyNull) or
      (PickCode =keyAltB) then
    PickExit:=peQuit;
  end;
 until PickExit =peQuit;

 KillWindow(wQue);
 RestoreWindowCoordinates(OldWind);
 GotoXYabs(System.lo(OldXY),hi(OldXY));
 TextAttr:=$07;
 SaveQueue;
end;

end.
