{$X+,O+,F+,V-,I-}

UNIT SfM_Dlg;

INTERFACE

procedure AttachFiles;

IMPLEMENTATION

uses
 Dos,
 Config,
 aDir,
 tString_,
 WriteLog,
 TpCrt,
 TpWindow,
 fileMan,
 EdLn,
 FReqMan,
 EmStruct,
 Em_Cpl,
 MsgXs,
 Sf_Bink,
 adE,
 adE_Strc,
 TpMemChk;

{$I SfM_Dlg.inc}

var
 attchVia:byte;
 attchAttr:byte;
 multiFile:boolean;

procedure HandleEvent(p:pointer;
                      msg:tDlgMsg;
                      b:byte;
                      w:word;
                      l:longint);
var
 pDlg:pDialogCtrl absolute p;
 pGrp:pGroupRec absolute p;
 pCtrl:pCtrlRec absolute p;

begin
 case msg of
  dm_Open: with pCfgRec^, pDlg^, dlgStuff^.GroupHead^ do begin
            with WindowP(dlgWin)^ do begin
             FastWrite('File',YL,XL+3,$70);
             FastWrite(' '+Pad(JustFilename(tmpSt),18),succ(YL),XL+2,$1F);
            end;
            {SaveWindow(1,ScreenHeight,ScreenWidth,ScreenHeight,true,scrHlp);}
            if (SysFlags and amaPack) =0 then begin
              ctrlDsbld:=rb_Message;
              nextGroup^.ctrlDsbld:=cb_Direct;
              ctrlChkd:=rb_Filebox;
            end;
            if Length(File_Boxes) =0 then begin
              ctrlDsbld:=ctrlDsbld or rb_Filebox;
              if ctrlChkd =rb_Filebox then ctrlChkd:=rb_Bink_DLo;
            end;
            if Length(BinkOutbound) =0 then
              ctrlDsbld:=ctrlDsbld or rb_Bink_DLo;
            if not multiFile then
             nextGroup^.nextGroup^.ctrlDsbld:=pb_All;
           end;
  dm_Close: with pDlg^, pDlg^.dlgStuff^.GroupHead^ do begin
              if (ctrlChkd and rb_Message) <>0 then
               attchVia:=rb_Message
              else
               if (ctrlChkd and rb_Bink_DLo) <>0 then
                attchVia:=rb_Bink_DLo
               else
                attchVia:=rb_Filebox;
              with dlgStuff^.GroupHead^.nextGroup^ do
               attchAttr:=ctrlChkd;
              {FASTWRITE(HexB(attchAttr),2,1,$0C);}
              {RestoreWindow(1,ScreenHeight,ScreenWidth,ScreenHeight,true,scrHlp);}
            end;
  dm_GrpGetFocus: with pGrp^ do begin
                {if (grpFlag and cmf_RadioBttn) <>0 then
                 s:='Method of attach: via msg, via filebox, via bink-?lo'
                else
                 if (grpFlag and cmf_PushBttn) <>0 then
                  s:='Press: Ok to accept, Cancel to abort and All to accept for all files'
                 else
                  s:='Atributes: direct (default), hold for pickup, kill file after sent';
                FastWrite(Pad(' '+s,ScreenWidth),ScreenHeight,1,$1E);}
               end;
  dm_GrpLoseFocus: {FastWrite('Lose focus..',23,1,$0A)};
  dm_Check: if (pGrp^.grpFlag and cmf_RadioBttn) <>0 then with pGrp^.nextGroup^ do begin
              if (b and (rb_Filebox or rb_Bink_DLo)) <>0 then begin
               ctrlDsbld:=cb_Direct;
               ctrlChkd:=ctrlChkd and (not cb_Direct);
              end
              else begin  {via message}
               ctrlDsbld:=0;
               ctrlChkd:=ctrlChkd or cb_Direct;
              end;
            end
            else
             if (pGrp^.grpFlag and cmf_PushBttn) =0 then with pGrp^.prevGroup^ do
              Ctrls^[2].ctrlName[7]:='H';
  dm_UnCkeck: if (pGrp^.grpFlag and (cmf_PushBttn or cmf_RadioBttn)) =0 then
              with pGrp^.prevGroup^ do
               Ctrls^[2].ctrlName[7]:='D';
  dm_None: {do nothing};
 end;
end;

procedure AttachFiles;
var
 ans:byte;
 _all:boolean;
 aA:tAddress;
 s:string;
 w:word;

function Make_Attach:boolean;
var
 fIn,fOut:file;
 l:longint;
 oldFileMode : byte;

begin
 Make_Attach:=false;
 { dialog execution }
 if not _all then begin
  ans:=Dialog_Exec('SfM_Dlg.res','SENDFILE OPTIONS',@HandleEvent);
  case ans of
   $FF,pb_Cancel: begin
                    LogWrite(wmAttachDroped,'',ld_All);
                    exit;
                  end;
   pb_All: _all:=true;
  end;
 end;
 { make attach..}
 s:='';
 w:=0;
 case attchVia of
  rb_Message: begin
               if (attchAttr and cb_Direct) <>0 then s:='DIR';
               if (attchAttr and cb_Kill_File_Sent) <>0 then s:=s+' KFS';
               if (attchAttr and cb_Hold) <>0 then w:=bMsgFlag[_Hold];
               GenerateMsg(aA,tmpSt,mtAttach, w,s);
              end;
  rb_Bink_DLo: GenerateBinkAttch(aA,tmpSt,(attchAttr and cb_Kill_File_Sent) <>0,
                                (attchAttr and cb_Hold) <>0);
  rb_Filebox: begin
                if (attchAttr and cb_Kill_File_Sent <>0) and
                   (attchAttr and cb_Hold <>0) then
                  s:='[Hold/KFS]'
                else
                 if (attchAttr and cb_Hold) <>0 then
                  s:='[Hold]'
                 else
                  if (attchAttr and cb_Kill_File_Sent) <>0 then
                   s:='[KFS]';
                LogWrite(imGenBoxAtch,JustFileName(tmpSt)+#3+
                         Addr2str(aA,true)+#3+s,ld_All);
                { копиpование/пеpемещение файла в ящик }
                s:=pCfgRec^.File_Boxes+
                   AddrTo32(aA,(attchAttr and cb_Hold) <>0);
                MkAllDir(s);
                assign(fIn,tmpSt);
                if (attchAttr and cb_Kill_File_Sent <>0) and
                   (LoCase(tmpSt[1]) =LoCase(s[1])) then
                  rename(fIn,s+'\'+JustFilename(tmpSt))
                else
                 if not GetMemCheck(HugeBuf,HugeBufSiz) then
                  LogWrite(emCLM,'for trx buffer',ld_All)
                 else begin
                  oldFileMode:=filemode;
                  filemode:=$20;
                  reset(fIn,1);
                  filemode:=OldFileMode;
                  if IoResult <>0 then
                   LogWrite(emCantOpen,tmpSt,ld_All)
                  else begin
                   { взяли дату/вpемя пеpемещаемого файла }
                   GetFtime(fIn,l);
                   assign(fOut,s+'\'+JustFileName(tmpSt));
                   rewrite(fOut,1);
                   repeat
                     BlockRead(fIn,HugeBuf^,HugeBufSiz,w);
                     BlockWrite(fOut,HugeBuf^,w);
                   until w <HugeBufSiz;
                   { устанавливаем новому файлу стаpую дату }
                   SetFtime(fOut,l);
                   close(fIn);
                   close(fOut);
                   if IoResult <>0 then;
                   if (attchAttr and cb_Kill_File_Sent) <>0 then erase(fIn);
                   if IoResult <>0 then;
                  end;
                  FreeMem(HugeBuf,HugeBufSiz);
                 end;
              end;
 end;
 Make_Attach:=true;
end;

procedure Do_Attach;
begin
 if InitSequence <>0 then begin
   multiFile:=true;
   while NextMarkedFile(tmpSt) do
     if not Make_Attach then exit;
 end
 else begin
   tmpSt:=GetCurrent;
   if TmpSt[Length(TmpSt)]<>'\' then Make_Attach;
 end;
end;

begin
 s:='';
 tmpSt:='';
 _all:=false;
 multiFile:=false;
 SetDefaultAddr(MainAddress,false);
 if InputLine('Send to address',s,$70,$71,$7E,$1F,26,26,true) and
    InputLine('Input path',tmpSt,$70,$71,$7E,$1F,81,70,false) then
  if xStr2addr(s,aA) then begin
   if ScreenHeight >25 then
    ans:=ord(pmMultiFull)
   else
    ans:=ord(pmMultiHalf);
   case Pane_Process(20,3,tPaneMode(ans),ivOnlyName,tmpSt) of
    pnOk: begin
           Do_Attach;
           Pane_Done;
          end;
    pnNotEnoughMem: LogWrite(emCLM,'for files',ld_Screen);
    pnNoFiles: LogWrite(emNoFilesFound,'',ld_Screen);
    pnInvalidPath: LogWrite(emBadPath,tmpSt,ld_Screen);
    pnDriveNotReady: LogWrite(emDriveNotReady,'',ld_Screen);
    pnQuit: begin
              Pane_Done;
            end;
   end;(*CASE*)
  end;
 WaitMsg;
end;

end.
