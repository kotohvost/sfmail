(*************************************)
(***    The Sf-Mail Queue viewer   ***)
(*** (c) by Anton the Deinow, 1995 ***)
(*************************************)

{$X+,I-}

program SfM_Que;

uses
 Cfg,
 SfM_Api,
 ReadCfg,
 _SfM_Que,
 Dos,
 TpDos,
 TpCrt,
 TpWindow,
 Tstring_,
 TpPick,
 _Que_Viw,
 aMsgBox,
 _LO_View;

const
 sCfgState:array[tRCS] of string[25]=(
  'Ok',
  'Config file not found',
  'Config I/O error',
  'Recompile config',
  'Invalid cfg version',
  'Cfg is not for current OS'
 );

{$F+}
procedure ShowMsgInfo(n:word);
var
 i:byte;
 s:string;

begin
 {memory info: FASTWRITE(long2str(MemAvail),1,1,$0B);}
 for i:=(ScreenHeight-6) to (ScreenHeight-2) do
   FastWrite(Pad('',78),i,2,qvColors[qvWindow]);
 with QueStuff[CurrStuff], QueTmp do begin
  if CurrStuff in [queMail..queHoldFReq] then begin
   if tQueBit(Data^[n]^).FileType =ftMsg then begin
    FastWrite('Msg #'+Pad(Long2str(tQueBit(Data^[n]^).MsgNo),4),ScreenHeight-6,3,qvColors[qvMsgHat]);
    FastWrite('(',ScreenHeight-6,12,qvColors[qvMsgHat]);
    FastWrite(CharStr('Ä',78),ScreenHeight-5,2,$2);
    case CurrStuff of
     queMail: s:='normal mail';
     queHoldMail: s:='hold mail';
     queAttach: s:='normal attach';
     queHoldAttach: s:='hold attach';
     queFReq: s:='normal freq';
     queHoldFReq: s:='hold freq';
    end;
    Fastwrite(s+')',ScreenHeight-6,13,qvColors[qvMsgHat]);
    FastWrite('Attrs',ScreenHeight-4,2,qvColors[qvMsgLabel]);
    FastWrite(MsgAttrs2str(tQueBit(Data^[n]^).MsgAttr),ScreenHeight-4,8,qvColors[qvMsgData]);
    if CurrStuff in [queMail..queHoldFReq] then begin
      if CurrStuff in [queAttach..queHoldFReq] then
        s:='Files'
      else
        s:=' Subj';
      FastWrite(s,ScreenHeight-3,2,qvColors[qvMsgLabel]);
      FastWrite(tQueBit(Data^[n]^).Name,ScreenHeight-3,8,qvColors[qvMsgData]);
      if CurrStuff in [queAttach,queHoldAttach] then begin
       case tQueBit(Data^[n]^).FileType of
        ftKFS: s:='erase-after-sent';
        ftTFS: s:='truncate-after-sent';
        ftNormal: s:='standard attach';
       end;
       FastWrite('Type',ScreenHeight-2,3,qvColors[qvMsgLabel]);
       FastWrite(s,ScreenHeight-2,8,qvColors[qvMsgData]);
      end;
    end;
   end
   else
    if tQueBit(Data^[n]^).FileType =ftBinkUT then begin
    end
    else begin {BinkLOnorm}
    end;
  end {MAIL..FREH}
  else begin
  end;
 end;
end;

procedure ShowQueHelp;
var
 hw:WindowPtr;
 sc:word;

begin
 MakeWindow(hw, 20,ScreenHeight div 2-4,60,ScreenHeight div 2+5,true,true,true,$10,$1F,$1E,' Help, press key.. ');
 DisplayWindow(hw);
 FastWriteWindow('Cursor keys Ä move cursor',2,2,$17);
 FastWriteWindow(        'Tab Ä jump to next column',3,10,$17);
 FastWriteWindow(  'Shift/Tab Ä jump to previous column',4,4,$17);
 FastWriteWindow(      'Enter Ä view message',5,8,$17);
 FastWriteWindow(        'Esc Ä quit',6,10,$17);
 FastWriteWindow(         'F8 Ä kill',7,11,$17);
 sc:=ReadScanCode;
 KillWindow(hw);
end;

procedure MyHalt;
begin
 SetBlink(pCfgRec^.SysFlags and clrBlinking <>0);
 RestoreCursorState(oldXY,oldScanL);
 Window(1,1,ScreenWidth,ScreenHeight);
 TextAttr:=$7;
 ClrScr;
 ExitProc:=oldHalt;
 halt(ExitCode);
end;
{$F-}

var
 i:byte;
 mvA:mvAction;
 w:word;
 rcs:tRCS;

begin
 oldHalt:=ExitProc;
 ExitProc:=@MyHalt;
 GetCursorState(oldXY,oldScanL);
 HiddenCursor;
 pCfgRec^.SysFlags:=pCfgRec^.SysFlags or clrBlinking;
 SetBlink(false);
 { SfM_Que <Addr> <Ln> <CfgFname> [<NdlName> <NdlOfs>] }
 if ParamCount <3 then halt(255);
 if not Str2word(ParamStr(2),w) then begin
   MessageBox('This program requiredSfM Operation system',
              tOk,tOk,bButton[tOk] or bButton[tCancel] or bButton[tRetry],
              ambClrs,'StartUp error..');
   halt(255);
 end;
 Task:=w;
 Str2addr(ParamStr(1),queAddr);
 if (queAddr.Zone =0) or (queAddr.Net =0) then begin
  MessageBox('Internal stack overflow,'#3'ok to crash system?',
             tOk,tOk,bButton[tOk] or bButton[tCancel] or bButton[tRetry],
             ambClrs,'Trap #000d');
  halt(255);
 end;
 CfgFname:=ParamStr(3);
 rcs:=Read_Config(CfgFname);
 if rcs <>rcsOk then begin
  MessageBox(sCfgState[rcs],tOk,tOk,bButton[tOk],
             ambClrs,'Config error..');
  halt(254);
 end;
 if not LoadQueue then begin
  MessageBox('Unable to find que'#3'for '+_4D2str(queAddr),
             tAbort,tAbort,bButton[tAbort],ambClrs,'Fatal!');
  halt(253);
 end;
 Path4addr(false,queAddr,quePath);
 NdlStr:='';

 with pCfgRec^ do begin
   { ç¨â ¥¬ áâp®ªã ¨§ ­®¤«¨áâ , ¥á«¨ ãª § ­® }
   if ParamCount =5 then begin
     assign(fNdl,Nodelist+ParamStr(4));
     reset(fNdl);
     if IoResult =0 then begin
       Str2long(ParamStr(5),NdlOfs);
       TextSeek(fNdl,NdlOfs);
       readln(fNdl,NdlStr);
     end;
     if IOResult<>0 then ;
     close(fNdl);
   end;
   if Length(NdlStr) =0 then
     NdlStr:='*Unlisted node*';
   { £¥­¥p æ¨ï íªp ­  }
   TextAttr:=$7;
   ClrScr;
   FastCenter(PID+' '+VID+' '+CID,ScreenHeight,$9);
   TextAttr:=qvColors[qvWindow];
   {Window(2,2,79,23);}
   {ClrScr;}
   FrameWindow(1,1,80,pred(ScreenHeight), qvColors[qvBorder],
               qvColors[qvHeader],' '+_4D2str(queAddr)+' ');

   { ¨­ä  ®¡ ã§«¥ }
   if Length(NdlStr) =15 then
     FastCenter(NdlStr,2,qvColors[qvUnlistedNode])
   else begin
     if NdlStr[1] =',' then nn:=2
     else nn:=3;
     FastCenter(_2space(ExtractWord(nn,NdlStr,[',']))+', '+       {system}
                _2space(ExtractWord(nn+2,NdlStr,[',']))+'  at  '+ {sysop}
                _2space(ExtractWord(nn+1,NdlStr,[','])),          {location}
                2,qvColors[qvNodeInfo1]);
                                                              {phone, flags}
     FastCenter(copy(NdlStr,pos(ExtractWord(nn+3,NdlStr,[',']),NdlStr),78),3,qvColors[qvNodeInfo2]);
   end;

   FastWrite('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÒÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÒÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÒÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ',4,2,qvColors[qvTable]);
   FastWrite('º               º               º',5,18,qvColors[qvTable]);
   FastWrite('Mails',5,8,qvColors[qvTableTxt]);
   FastWrite('Attaches',5,22,qvColors[qvTableTxt]);
   FastWrite('FReqs',5,39,qvColors[qvTableTxt]);
   FastWrite('Boxes',5,63,qvColors[qvTableTxt]);
   FastWrite('ÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄ',6,2,qvColors[qvTable]);
   for i:=7 to (ScreenHeight-11) do
     FastWrite('        ³       º       ³       º       ³       º              ³',i,2,qvColors[qvTable]);
   FastWrite('ÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄ',
             ScreenHeight-12,2,qvColors[qvTable]);
   FastWrite('ÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄĞÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄĞÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄĞÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄ',
             ScreenHeight-10,2,qvColors[qvTable]);
   for i:=0 to 2 do
     FastWrite('Normal',7,4+i*16,qvColors[qvTableTxt]);
   FastWrite('Normal',7,55,qvColors[qvTableTxt]);
   for i:=0 to 2 do
     FastWrite('Hold',7,12+i*16,qvColors[qvTableTxt]);
   FastWrite('Hold',7,71,qvColors[qvTableTxt]);

   y2:=ScreenHeight-13;

   PickHelpPtr:=@ShowQueHelp;
   {SetVerticalPick;}
   if not InitMemory then begin
    MessageBox('Que entry is not correspodsto real stuff, aborting',
               tOk,tOk,bButton[tOk],ambClrs,
               'General fault..');
    halt(250);
   end;
   NextStuff;
   PickUserPtr:=@ShowMsgInfo;
   AddPickCommand(PKSuser0,1,$0F09,0);  {Tab}
   AddPickCommand(PKSuser1,1,$0F00,0);  {Shift/Tab}
   AddPickCommand(PKSuser2,1,$4200,0);  {F8}
   AddPickCommand(PKSuser3,1,$3920,0);  {Space}
   AddPickCommand(PKSuser4,1,$6500,0);  {Ctrl/F8}

   {Shadow:=true;}

   ShadowAttr:=$8;
   FastWrite(' press F1 for help..',pred(Screenheight),58,$F);
   ShowHIPflags;
   repeat
    with QueStuff[CurrStuff] do
     {MessageBox(':'+long2str(total)+':'+long2str(curr)+':'+long2str(first)+':'#3+
                'mem '+long2str(memavail)+'/'+long2str(maxavail),
                tOk,tOk,bButton[tOk],
                mbClrs,'Debug..');}
    with QueStuff[CurrStuff] do
      PickBar(W,@GetQueStuff,Total,PickColors,true,Curr,First);
    case PickCmdNum of
      PKSuser0: NextStuff;
      PKSuser1: PrevStuff;
      PKSuser2: with QueStuff[CurrStuff] do begin
                 KillStuff;
                 ActivateWindow(W);
                 ClrScr;
                 if Total <Curr then Dec(Curr);
                 if First >Curr then Dec(First);
                 if Total =0 then begin
                  with WindowP(W)^ do
                    ChangeAttribute(succ(XH-XL),pred(YL),XL,$03);
                  if not NextStuff then begin
                    MessageBox('No outbound for '+_4D2str(queAddr)+';'#3+
                               'quit SfM_Que, exit Internal que manager'#3+
                               'and press Space button for rescan.',tOk,tOk,
                               bButton[tOk],ambClrs,'Que empty..');
                    halt(0);
                  end;
                 end;
                end;
      PKSselect: if CurrStuff in [queMail..queHoldFReq] then with QueStuff[CurrStuff] do begin
                   if tQueBit(Data^[Curr]^).FileType in [ftMsg,ftKFS,ftTFS,ftNormal] then begin
                    i:=1;
                    mvA:=mva_ViewFirst;
                    repeat
                     case ViewMsg(tQueBit(Data^[Curr]^).MsgNo,mvA) of
                       mvec_Quit: i:=0;
                       mvec_Prev: if Curr <>1 then Dec(Curr);
                       mvec_Next: if (Curr <Total) and
                                     (tQueBit(Data^[succ(Curr)]^).FileType<ftBoxed) then Inc(Curr);
                     end;
                     mvA:=mva_ContView;
                    until i =0;
                   end
                   else
                    if tQueBit(Data^[Curr]^).FileType =ftBinkLoNorm then
                     View_LO(tQueBit(Data^[Curr]^).Name)
                    else
                     MessageBox('This feature was notimplemented yet..',tOk,tOk,bButton[tOk],
                                ambClrs,'Oops!..');
                   PickUserPtr:=@ShowMsgInfo;
                   PickHelpPtr:=@ShowQueHelp;
                 end;
    end;
   until PickCmdNum =PKsexIt;
 end;
 { exit via MyHalt }
end.
