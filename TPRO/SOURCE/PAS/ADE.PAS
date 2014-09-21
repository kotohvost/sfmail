(*
  Anton`s Dialog Engine: Resource Access
  ver 0.0.2/alpha
  (C) Anton the Deinow, 1995
*)

{$X+,I-,O+,F+,B-}

UNIT aDE;

INTERFACE

uses
 Dos;

function Dialog_Exec(resFname:PathStr; dlgIdName:string; ppHandleEvent:pointer):word;
{ Exit codes:
              $FF         - escape pressed
              $00         - default button press
              [$01..$8000]  - button press (bitmaped)
}

IMPLEMENTATION

uses
 TpCrt,
 TpWindow,
 tString_,
 aDE_Strc;

type
 tResourceError=(
  reUnable2open,
  reUnable2find,
  reVerMismatch
 );

const
 HandleEventProc:pointer=nil;
 doGrpFocus=$FEFE;
 doRedraw  =$FFFF;
 doAxCheck =$FF00;

procedure CallHandleEvent(p:pointer;
                          msg:tDlgMsg;
                          b:byte;
                          w:word;
                          l:longint);
inline($FF/$1E/>HandleEventProc);  {CALL DWORD PTR [>HandleEventProc]}

function Dialog_Exec(resFname:PathStr; dlgIdName:string; ppHandleEvent:pointer):word;
var
 Dialog:pDialogCtrl;
 s:string;
 z,i:byte;
 pLastGrp:pGroupRec;
 p:pGroupRec;
 cursXY,cursSL:word;
 _done:boolean;
 oldFrameCh:FrameArray;
 sc:word;
 Msg:tDlgMsg;

procedure Resource_Error(re:tResourceError);
begin
 case re of
  reUnable2open: s:='Unable to open `'+resFname+#39;
  reUnable2find: s:='Dialog `'+dlgIdName+#39+' not found';
  reVerMismatch: s:='Resource ver mismatch';
 end;
 TextAttr:=$0C;
 write('ADE-F-',301+ord(re),': ',s);
 TextAttr:=$07;
 writeln('press any key..');
 ReadKey;
 halt;
end;

procedure Resource_Open;
var
 f:file;
 resHdr:tDlgResHdr;
 resIdx:tDlgIdx;
 i:byte;

begin
 if IoResult <>0 then;
 assign(f,resFname);
 reset(f,1);
 if IoResult <>0 then Resource_Error(reUnable2open);
 BlockRead(f,resHdr,SizeOf(tDlgResHdr));
 if aDE_SIGN <>resHdr.aDE_VID then Resource_Error(reVerMismatch);
 for i:=1 to resHdr.dlgTotal do begin
   BlockRead(f,resIdx,SizeOf(tDlgIdx));
   if resIdx.dlgName =dlgIdName then begin
     seek(f,SizeOf(tDlgResHdr)+SizeOf(tDlgIdx)*resHdr.dlgTotal+resIdx.dlgOfs);
     GetMem(Dialog,SizeOf(tDialogCtrl));
     GetMem(Dialog^.dlgStuff,SizeOf(tDialog));
     { ç¨â ¥¬ § £®«®¢®ª ¤¨ «®£  }
     BlockRead(f,Dialog^.dlgStuff^,SizeOf(tDialog));
     Dialog^.dlgStuff^.GroupHead:=nil;
     pLastGrp:=nil;
     { ç¨â ¥¬ £pã¯¯ë }
     for i:=1 to Dialog^.dlgStuff^.TotalGroups do with Dialog^.dlgStuff^ do begin
       if GroupHead =nil then begin
         GetMem(GroupHead,SizeOf(tGroupRec));
         pLastGrp:=GroupHead;
         BlockRead(f,pLastGrp^,SizeOf(tGroupRec));
       end
       else begin
         GetMem(pLastGrp^.NextGroup,SizeOf(tGroupRec));
         BlockRead(f,pLastGrp^.NextGroup^,SizeOf(tGroupRec));
         pLastGrp^.NextGroup^.PrevGroup:=pLastGrp;
         pLastGrp:=pLastGrp^.NextGroup;
       end;
       { read items of group }
       GetMem(pLastGrp^.Ctrls,SizeOf(tCtrlRec)*pLastGrp^.TotalCtrls);
       BlockRead(f,pLastGrp^.Ctrls^,SizeOf(tCtrlRec)*pLastGrp^.TotalCtrls);
     end;
     close(f);
     Dialog^.dlgStuff^.GroupTail:=pLastGrp;
     HandleEventProc:=ppHandleEvent;
     { video initialization }
     GetCursorState(cursXY,cursSL);
     Move(FrameChars,oldFrameCh,SizeOf(FrameArray));
     with Dialog^ do begin
       pCurGroup:=dlgStuff^.GroupHead;
       CurCtrl:=1;
     end;
     exit;
   end;
 end;
 Resource_Error(reUnable2find);
end;

procedure Resource_Done;
begin
 CallHandleEvent(Dialog,dm_Close,0,0,0);
 with Dialog^ do begin
  p:=dlgStuff^.GroupHead;
  repeat
    pLastGrp:=p^.NextGroup;
    { dispose group controls }
    FreeMem(p^.Ctrls,SizeOf(tCtrlRec)*p^.TotalCtrls);
    { dispose group info }
    FreeMem(p,SizeOf(tGroupRec));
    p:=pLastGrp;
  until p =nil;
  KillWindow(dlgWin);
  FreeMem(dlgStuff,SizeOf(tDialog));
  FreeMem(Dialog,SizeOf(tDialogCtrl));
 end;
 RestoreCursorState(cursXY,cursSL);
 Move(oldFrameCh,FrameChars,SizeOf(FrameArray));
end;

procedure Ctrl_MoveSelect(movUp:boolean);
begin
 with Dialog^, Dialog^.pCurGroup^ do begin
  i:=CurCtrl;
  repeat
   if movUp then
     if i =1 then i:=TotalCtrls
     else Dec(i)
   else
     if i =TotalCtrls then i:=1
     else Inc(i);
   if ((1 shl pred(i)) and ctrlDsbld) =0 then CurCtrl:=i;
  until (i =CurCtrl);
 end;
end;

procedure CheckBox_Draw;
var
 i:byte;
 x1,y1,x2,y2:byte;

begin
 { draw group box, etc. }
 with p^ do begin
  if (grpFlag and cmf_Framed) <>0 then begin
   SetFrameChars('³','Ä','Ù','¿','À','Ú');
  end
  else
   FillChar(FrameChars,SizeOf(FrameArray),$20);
  if (grpFlag and (cmf_Framed or cmf_Header)) <>0 then begin
    x1:=succ(grpXL);
    y1:=succ(grpYL);
    x2:=pred(grpXH);
    y2:=pred(grpYH);
    i:=ord(HeaderJstfy);
    if (grpFlag and cmf_HdrLeft) <>0 then HeaderJstfy:=hjLeft
    else
     if (grpFlag and cmf_HdrRight) <>0 then HeaderJstfy:=hjRight
     else
      HeaderJstfy:=hjCenter;
    with Dialog^ do begin
     FrameWindow(pred(grpXL)+WindowP(dlgWin)^.XL,
                 pred(grpYL)+WindowP(dlgWin)^.YL,
                 pred(grpXH)+WindowP(dlgWin)^.XL,
                 pred(grpYH)+WindowP(dlgWin)^.YL,
                 dlgStuff^.dlgClrs[cbc_Frame],
                 dlgStuff^.dlgClrs[cbc_Header],
                 grpHdr);
     HeaderJstfy:=tHeaderJstfy(i);
     if grpAxel.axChr <>#0 then begin
      FastReadWindow(grpXH-grpXL,grpYL,grpXL,s);
      i:=Pos(grpAxel.axChr,grpHdr);
      if i <>0 then
       ChangeAttributeWindow(1,grpYL,grpXL+i,dlgStuff^.dlgClrs[cbc_HdrHlt]);
     end;
    end;
  end
  else begin
    x1:=grpXL;
    y1:=grpYL;
    x2:=grpXH;
    y2:=grpYH;
  end;
 end;
 { draw items }
 for i:=1 to p^.TotalCtrls do with p^.Ctrls^[i] do begin
   if (p^.ctrlDsbld and (1 shl pred(i))) <>0 then begin
     z:=Dialog^.dlgStuff^.dlgClrs[cbc_Disabled];
     s[1]:='°';
   end
   else begin
    if (p^.ctrlChkd and (1 shl pred(i))) <>0 then s[1]:='û'
    else s[1]:=' ';
    if (Dialog^.pCurGroup =p) and (Dialog^.CurCtrl =i) then
      z:=Dialog^.dlgStuff^.dlgClrs[cbc_Select]
    else
      z:=Dialog^.dlgStuff^.dlgClrs[cbc_Item];
   end;
   FastWriteWindow(' ['+s[1]+'] '+Pad(copy(ctrlName,1,x2-x1-4),x2-x1-4),
                   pred(y1+i),x1,z);
   if (p^.ctrlDsbld and (1 shl pred(i)) =0) and
      ((Dialog^.pCurGroup <>p) or (Dialog^.CurCtrl <>i)) then begin
    z:=Pos(ctrlAxel.axChr,ctrlName);
    if z <>0 then ChangeAttributeWindow(1,pred(y1+i),x1+4+z,
                           Dialog^.dlgStuff^.dlgClrs[cbc_ItemHlt]);
   end;
 end;
 if Dialog^.pCurGroup =p then GotoXY(x1+2,pred(y1+Dialog^.CurCtrl));
end;

procedure RadioButton_Draw;
var
 i:byte;
 x1,y1,x2,y2:byte;

begin
 { draw group box, etc. }
 with p^ do begin
  if (grpFlag and cmf_Framed) <>0 then begin
   SetFrameChars('³','Ä','Ù','¿','À','Ú');
  end
  else
   FillChar(FrameChars,SizeOf(FrameArray),$20);
  if (grpFlag and (cmf_Framed or cmf_Header)) <>0 then begin
    x1:=succ(grpXL);
    y1:=succ(grpYL);
    x2:=pred(grpXH);
    y2:=pred(grpYH);
    i:=ord(HeaderJstfy);
    if (grpFlag and cmf_HdrLeft) <>0 then HeaderJstfy:=hjLeft
    else
     if (grpFlag and cmf_HdrRight) <>0 then HeaderJstfy:=hjRight
     else
      HeaderJstfy:=hjCenter;
    with Dialog^ do begin
     FrameWindow(pred(grpXL)+WindowP(dlgWin)^.XL,
                 pred(grpYL)+WindowP(dlgWin)^.YL,
                 pred(grpXH)+WindowP(dlgWin)^.XL,
                 pred(grpYH)+WindowP(dlgWin)^.YL,
                 dlgStuff^.dlgClrs[cbc_Frame],
                 dlgStuff^.dlgClrs[cbc_Header],
                 grpHdr);
     HeaderJstfy:=tHeaderJstfy(i);
     if grpAxel.axChr <>#0 then begin
      FastReadWindow(grpXH-grpXL,grpYL,grpXL,s);
      i:=Pos(grpAxel.axChr,grpHdr);
      if i <>0 then
       ChangeAttributeWindow(1,grpYL,grpXL+i,dlgStuff^.dlgClrs[cbc_HdrHlt]);
     end;
    end;
  end
  else begin
    x1:=grpXL;
    y1:=grpYL;
    x2:=grpXH;
    y2:=grpYH;
  end;
 end;
 { draw items }
 for i:=1 to p^.TotalCtrls do with p^.Ctrls^[i] do begin
   if (p^.ctrlDsbld and (1 shl pred(i))) <>0 then begin
     z:=Dialog^.dlgStuff^.dlgClrs[cbc_Disabled];
     s[1]:='°';
   end
   else begin
    if (p^.ctrlChkd and (1 shl pred(i))) <>0 then s[1]:=#7
    else s[1]:=' ';
    if (Dialog^.pCurGroup =p) and (Dialog^.CurCtrl =i) then
      z:=Dialog^.dlgStuff^.dlgClrs[cbc_Select]
    else
      z:=Dialog^.dlgStuff^.dlgClrs[cbc_Item];
   end;
   FastWriteWindow(' ('+s[1]+') '+Pad(copy(ctrlName,1,x2-x1-4),x2-x1-4),
                   pred(y1+i),x1,z);
   if (p^.ctrlDsbld and (1 shl pred(i)) =0) and
      ((Dialog^.pCurGroup <>p) or (Dialog^.CurCtrl <>i)) then begin
    z:=Pos(ctrlAxel.axChr,ctrlName);
    if z <>0 then ChangeAttributeWindow(1,pred(y1+i),x1+4+z,
                           Dialog^.dlgStuff^.dlgClrs[cbc_ItemHlt]);
   end;
 end;
 if Dialog^.pCurGroup =p then GotoXY(x1+2,pred(y1+Dialog^.CurCtrl));
end;

procedure PushButton_Draw(pushed:boolean);
var
 i:byte;
 x1,y1,x2,y2:byte;

begin
 with p^, Dialog^ do
  for i:=1 to TotalCtrls do with p^.Ctrls^[i] do begin
    x1:=pred(ctrlXL)+WindowP(dlgWin)^.XL;
    y1:=pred(ctrlYL)+WindowP(dlgWin)^.YL;
    x2:=pred(ctrlXH)+WindowP(dlgWin)^.XL;
    y2:=pred(ctrlYH)+WindowP(dlgWin)^.YL;
    if (i =CurCtrl) and (p =pCurGroup) then
      z:=dlgStuff^.dlgClrs[pbc_Select]
    else
     if (p^.ctrlDsbld and (1 shl pred(i))) <>0 then
       z:=dlgStuff^.dlgClrs[pbc_Disabled]
     else
      if (ctrlFlag and cmf_Default) <>0 then
        z:=dlgStuff^.dlgClrs[pbc_Default]
      else
        z:=dlgStuff^.dlgClrs[pbc_Item];
    if ((ctrlFlag and cmf_Framed) <>0) or
       ((grpFlag and cmf_Framed) <>0) then begin
      if (i =CurCtrl) and (p =pCurGroup) and pushed then
        SetFrameChars('º','Í','¼','»','È','É')
      else
        SetFrameChars('³','Ä','Ù','¿','À','Ú');
      FrameWindow(x1,y1,x2,y2,dlgStuff^.dlgClrs[pbc_Shadow],$00,'');
      if (i =CurCtrl) and (p =pCurGroup) then
        s:=#16+Center(ctrlName,x2-x1-3)+#17
      else
        s:=Center(ctrlName,pred(x2-x1));
      FastWrite(s,succ(y1),succ(x1),z);
      z:=Pos(ctrlAxel.axChr,s);
      if (z <>0) and ((p^.ctrlDsbld and (1 shl pred(i))) =0) and
         ((i <>CurCtrl) or (p <>pCurGroup)) then
        ChangeAttribute(1,succ(y1),(x1+z),dlgStuff^.dlgClrs[pbc_Hilite]);
    end
    else begin
      if (i =CurCtrl) and (p =pCurGroup) then
        s:=#16+Center(ctrlName,x2-x1-2)+#17
      else
        s:=Center(ctrlName,x2-x1);
      if (i =CurCtrl) and (p =pCurGroup) and pushed then begin
        FastWrite(' ',y1,x1,dlgStuff^.dlgClrs[pbc_Shadow]);
        FastFill(x2-x1,' ',y2,succ(x1),dlgStuff^.dlgClrs[pbc_Shadow]);
        FastWrite(s,y1,succ(x1),z);
      end
      else begin
        FastWrite(s,y1,x1,z);
        z:=Pos(ctrlAxel.axChr,s);
        if (z <>0) and ((p^.ctrlDsbld and (1 shl pred(i))) =0) and
           ((i <>CurCtrl) or (p <>pCurGroup)) then
          ChangeAttribute(1,y1,pred(x1+z),dlgStuff^.dlgClrs[pbc_Hilite]);
        { draw shadow }
        FastFill(x2-x1,'ß',y2,succ(x1),dlgStuff^.dlgClrs[pbc_Shadow]);
        FastWrite('Ü',y1,x2,dlgStuff^.dlgClrs[pbc_Shadow]);
      end;
    end;
  end;
end;

procedure Dialog_Draw(Focus:boolean; ffe:byte);
{ if Focus == true then current group must search first enabled control }
{ if ffe <>0 then need to find first enabled, else set it to ffe }
begin
 with Dialog^, Dialog^.dlgStuff^ do begin
  { draw all groups }
  p:=GroupHead;
  z:=1;
  repeat
    with p^ do begin
     if Focus and (p =pCurGroup) then
      if ffe =0 then begin
        CurCtrl:=TotalCtrls;
        Ctrl_MoveSelect(false);
      end
      else
        CurCtrl:=ffe;
     if (grpFlag and cmf_PushBttn) <>0 then PushButton_Draw(false)
     else
      if (grpFlag and cmf_RadioBttn) <>0 then RadioButton_Draw
      else { it`s a checkboxes }
        CheckBox_Draw;
    end;
    p:=p^.NextGroup;
    Inc(z);
  until p =nil;
  if (pCurGroup^.grpFlag and cmf_PushBttn) <>0 then HiddenCursor
  else NormalCursor;
 end;
end;

procedure CheckAxel;
var
 i:byte;

begin
 with Dialog^, Dialog^.dlgStuff^ do begin
  p:=GroupHead;
  repeat
    if p^.grpAxel.axSC =hi(sc) then begin
      CallHandleEvent(p,dm_GrpLoseFocus,0,0,0);
      pCurGroup:=p;
      CallHandleEvent(p,dm_GrpGetFocus,0,0,0);
      sc:=doGrpFocus;
      exit;
    end
    else with p^ do
      for i:=1 to TotalCtrls do
        if ((ctrlDsbld and (1 shl pred(i))) =0) and
           (Ctrls^[i].ctrlAxel.axSc =hi(sc)) then begin
          CallHandleEvent(p,dm_GrpLoseFocus,0,0,0);
          pCurGroup:=p;
          CallHandleEvent(p,dm_GrpGetFocus,0,0,0);
          sc:=doAxCheck or i;
          exit;
        end;
    p:=p^.nextGroup;
  until p =nil;
 end;
end;

begin
 Dialog_Exec:=$FF;  { assume ESC pressed }
 dlgIdName:=copy(dlgIdName,1,16);
 Resource_Open;
 { main loop }
 with Dialog^, Dialog^.dlgStuff^ do begin
   MakeWindow(dlgWin, dlgXL,dlgYL,dlgXH,dlgYH, true,true,true,
              dlgClrs[dlc_BkGrnd],dlgClrs[dlc_Frame],dlgClrs[dlc_Header],
              dlgHdr);
   DisplayWindow(dlgWin);
   CallHandleEvent(Dialog,dm_Open,0,0,0);
   _done:=false;
   Dialog_Draw(true,0);
   { byte param=0 => not moved }
   CallHandleEvent(pCurGroup,dm_GrpGetFocus,0,0,0);
   sc:=0;
   repeat
     { redraw the  dialog }
     if (hi(sc) =hi(doAxCheck)) and (lo(sc) <>hi(doAxCheck)) then begin
      Dialog_Draw(true,lo(sc));
      sc:=$3920; { space for change state }
     end
     else begin
      if sc =doGrpFocus then Dialog_Draw(true,0)
      else
       if sc =doRedraw then Dialog_Draw(false,0);
      { waiting for keypress..}
      sc:=ReadKeyWord;
     end;
     case sc of
       { moving }
       $4800, {up or left}
       $4B00: begin Ctrl_MoveSelect(true); sc:=doRedraw; end;
       $5000, {down or right}
       $4D00: begin Ctrl_MoveSelect(false); sc:=doRedraw; end;
       { change focus }
       $0F09: begin {tab}
               if pCurGroup^.NextGroup =nil then
                 pCurGroup:=GroupHead
               else
                 pCurGroup:=pCurGroup^.NextGroup;
               { byte param=1 => forward }
               CallHandleEvent(pCurGroup,dm_GrpGetFocus,1,0,0);
               sc:=doGrpFocus;
              end;
       $0F00: begin {shift/tab}
               if pCurGroup^.PrevGroup =nil then
                 pCurGroup:=GroupTail
               else
                 pCurGroup:=pCurGroup^.PrevGroup;
               { byte param=$FF => backward }
               CallHandleEvent(pCurGroup,dm_GrpGetFocus,$FF,0,0);
               sc:=doGrpFocus;
              end;
       { change state }
       $3920: with pCurGroup^ do begin {space}
                if (grpFlag and cmf_RadioBttn) <>0 then begin
                  if (ctrlChkd and (1 shl pred(CurCtrl))) <>0 then
                    Msg:=dm_None
                  else
                    Msg:=dm_Check;
                  ctrlChkd:=1 shl pred(CurCtrl)
                end
                else
                 if (grpFlag and cmf_PushBttn) <>0 then begin
                   Dialog_Exec:=1 shl pred(CurCtrl);
                   p:=pCurGroup;
                   PushButton_Draw(true);
                   Delay(403);
                   PushButton_Draw(false);
                   Delay(33);
                   _done:=true;
                 end
                 else { it`s a checkbox } begin
                   ctrlChkd:=ctrlChkd xor (1 shl pred(CurCtrl));
                   if (ctrlChkd and (1 shl pred(CurCtrl))) <>0 then
                     Msg:=dm_Check
                   else
                     Msg:=dm_UnCkeck
                 end;
               if ((grpFlag and cmf_PushBttn) =0) and (Msg <>dm_None) then begin
                 CallHandleEvent(pCurGroup,Msg,1 shl pred(CurCtrl),0,0);
                 sc:=doRedraw;
               end;
              end;
       { exiting }
       $011B: _done:=true; {esc}
       $1C0D: begin {enter}
                _done:=true;
                if (pCurGroup^.grpFlag and cmf_PushBttn) =0 then
                  Dialog_Exec:=0
                else
                  Dialog_Exec:=1 shl pred(CurCtrl);
              end;
     else { check for accelerators }
      if lo(sc) =0 then CheckAxel;
     end;
   until _done;
 end;
 { dispose dinamic structures }
 Resource_Done;
end;

end.
