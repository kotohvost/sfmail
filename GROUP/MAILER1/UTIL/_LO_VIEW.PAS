{$I-,X+}
{ *.?LO view module for Sf-Mail Que Manager }

UNIT _LO_VIEW;

INTERFACE

uses
 Dos;

procedure View_LO(loFname:PathStr);

IMPLEMENTATION

uses
 TpCrt,
 TpWindow,
 TpPick,
 _SfM_Que,
 aMsgBox,
 tString_,
 SfM_Api;

const
 MaxLO=650;

type
 pLoItem=^tLoItem;
 tLoItem=record
  fName:PathStr;
  Siz:longint;
  Tim:longint;
  Ofs:longint;
  Marked:boolean;
  fType:tFileType;
 end;

 tLO=array[1..MaxLO] of pLoItem;

var
 LO:^tLO;

{$F+}
procedure ShowLOhelp;
var
 hw:WindowPtr;
 sc:word;

begin
 MakeWindow(hw, 20,ScreenHeight div 2-3,60,ScreenHeight div 2+5,true,true,true,$10,$1F,$1E,' Help, press key.. ');
 DisplayWindow(hw);
 FastWriteWindow('Cursor keys Ä move cursor',2,5,$17);
 FastWriteWindow(        'Esc Ä return',3,13,$17);
 FastWriteWindow(      'Space Ä toggle selection',4,11,$17);
 FastWriteWindow(         'F8 Ä send to /dev/nul',5,14,$17);
 FastWriteWindow(    'Ctrl/F8 Ä erase from *.?LO',6,9,$17);
 sc:=ReadScanCode;
 KillWindow(hw);
end;

function GetLoItem(n:word):string;
var
 s:string;

begin
 with LO^[n]^ do begin
  if fName[1] ='*' then begin
   GetLoItem:=Center(fName,78);
   Pickable:=false;
  end
  else begin
   s:=fName;
   if Length(s) >58 then Delete(s,1,Length(s)-58);
   s:=Pad(s,63);
   if Siz =-1 then s:=s+Center('n/a',7)
   else s:=s+LeftPad(vInBestForm(Siz),7);
   case fType of
    ftBinkLoNorm: s:=s+' norm';
    ftBinkLoKFS: s:=s+'  kfs';
    ftBinkLoTFS: s:=s+'  tfs';
   end;
   GetLoItem:=' '+s;
  end;
  if Marked then
   AltPickAttr:=true;
 end;
end;

procedure ShowFtime(n:word);
var
 dt:DateTime;

begin
 FastWrite(CharStr('Í',18),ScreenHeight-5,5,qvColors[qvBorder]);
 with LO^[n]^ do
  if fName[1] <>'*' then
   if Tim <>0 then with dt do begin
    UnpackTime(Tim,dt);
    FastWrite(LeftPad(Long2str(Day),3)+'Ä'+Months[Month]+'Ä'+
              copy(Long2str(Year),3,2)+', '+LeftPad(Long2str(Hour),2)+':'+
              LeftPadCh(Long2str(Min),'0',2)+' ',ScreenHeight-5,5,$0B);
   end
   else
    FastWrite(' n/a ',ScreenHeight-5,5,$0B);
end;
{$F-}

procedure View_LO(loFname:PathStr);
var
 wLO:WindowPtr;
 curLO,topLO,
 totalLO:word;
 totalSiz:longint;
 f,f1:text;
 ff:file;
 s:string;
 SavScr:pointer;
 sr:SearchRec;

label
 Xit_LO;

function Scan_LO:boolean;
begin
 topLO:=1;
 totalLO:=0;
 curLO:=1;
 totalSiz:=0;
 Scan_LO:=false;
 { scan LO }
 assign(f,loFname);
 reset(f);
 if IoResult <>0 then begin
  {MessageBox('Error opening'#3'`'+loFname+#39,tAbort,tAbort,
             bButton[tAbort],ambClrs,'Error..');}
  MessageBox('Error opening `'+JustFilename(loFname)+#39,tAbort,tAbort,
             bButton[tAbort],ambClrs,'Error..');
  exit;
 end;
 repeat
  readln(f,s);
  s:=Trim(s);
  if Length(s) <>0 then begin
   if totalLO <maxLO then begin
    Inc(totalLO);
    GetMem(LO^[totalLO],SizeOf(tLoItem));
    FillChar(LO^[totalLO]^,SizeOf(tLoItem),0);
   end;
   if totalLO =maxLO then with LO^[totalLO]^ do
    fName:='*to many files*'
   else begin
    with LO^[totalLO]^ do begin
     case s[1] of
      '^': begin {KFS}
            Delete(s,1,1);
            fType:=ftBinkLoKFS;
           end;
      '#': begin {TFS}
            Delete(s,1,1);
            fType:=ftBinkLoTFS;
           end;
     else {NORMAL}
       fType:=ftBinkLoNorm;
     end;
     fName:=s;
     {$I+} FindFirst(fName,AnyFile-Directory-VolumeId,sr); {$I-}
     if DosError =0 then begin
      Siz:=sr.Size;
      Tim:=sr.Time;
      Inc(totalSiz,Siz);
     end
     else Siz:=-1;
    end;
   end;
  end; (*IF LENGTH <>0*)
 until EOF(f);
 close(f);
 if totalLO =0 then
  MessageBox('This ?lo is empty.'#3'Nothing to view.',tOk,tOk,
             bButton[tOk],mbClrs,'Oops!')
 else
  Scan_LO:=true;
end;

function KillFromLO(toDevNul:boolean):boolean;
{-if toDevNul == true then erase from ?LO and kill/trunc/none files}
var
 EmptyLO:boolean;

begin
 KillFromLO:=false;
 if toDevNul then
  s:='send marked files to'#3'\dev\nul?'
 else
  s:='erase marked files from'#3'this ?LO';
 if MessageBox('Do you really want to'#3+s,tYes,tNo,bButton[tYes] or bButton[tNo],mbClrs,
               'Confirmation..') =tNo then
   exit;
 assign(f,loFname);
 reset(f);
 assign(f1,JustPathName(loFname)+'\_temp_._lo');
 rewrite(f1);
 curLO:=1;
 EmptyLO:=true;
 repeat
  readln(f,s);
  s:=Trim(s);
  if Length(s) <>0 then with LO^[curLO]^ do begin
   if s[1] in ['#','^'] then
    Delete(s,1,1);
   if fName[1] <>'*' then begin
    if Marked then begin
     if toDevNul then begin
      if fType <>ftBinkLoNorm then
       assign(ff,fName);
      case fType of
        ftBinkLoKFS: begin
                      erase(ff);
                      if IoResult <>0 then;
                     end;
        ftBinkLoTFS: begin
                      reset(ff,1);
                      if IoResult =0 then begin
                       Truncate(ff);
                       close(ff);
                      end;
                     end;
      end;
     end;
    end
    else begin (*NOT MARKED => WRITE TO *.?LO*)
     case fType of
      ftBinkLoKFS: s:='^'+s;
      ftBinkLoTFS: s:='#'+s;
     end;
     writeln(f1,s);
     EmptyLO:=false;
    end;
    Inc(curLO);
   end;
  end;
  if EOF(f) then begin
    close(f);
    close(f1);
    erase(f);
    if not EmptyLO then
     rename(f1,loFname)
    else
     erase(f1);
    if IoResult <>0 then write(^G);
    KillFromLO:=true;
    SetRepackSem;
    exit;
  end;
 until false;
end;

begin
 PickUserPtr:=@ShowFtime;
 PickHelpPtr:=@ShowLOhelp;
 GetMem(LO,SizeOf(tLO));
 if not Scan_LO then goto Xit_LO;
 SaveWindow(1,4,80,ScreenHeight-5,true,SavScr);
 s:=JustExtension(loFname);
 case LoCase(s[1]) of
  'f','d': s:='Normal';
  'c': s:='Crash';
  'i': s:='Immediate';
  'h': s:='Hold';
 end;
 MakeWindow(wLO,2,7,79,ScreenHeight-6,false,true,false,
            qvColors[qvWindow],qvColors[qvWindow],qvColors[qvWindow],'');
 FrameWindow(1,4,80,ScreenHeight-5,qvColors[qvBorder],qvColors[qvHeader],
             ' '+s+' attach ');
 { --- }
 FastWrite(Pad('File',59)+' Size   Attr',5,8,qvColors[qvMsgHat]);
 FastWrite('³',5,66,qvColors[qvTable]);
 FastWrite('³',5,73,qvColors[qvTable]);
 FastWrite(CharStr('Ä',64)+'ÁÄÄÄÄÄÄÁÄÄÄÄÄ',6,2,qvColors[qvTable]);
 FastWrite(' '+vInBestForm(totalSiz)+' ',ScreenHeight-5,67,$B);
 { walk lo-list }
 FillPickWindow(wLO,@GetLoItem,totalLO,PickColors,curLO,1);
 repeat
   PickBar(wLO,@GetLoItem,totalLO,PickColors,true,curLO,topLO);
   case PickCmdNum of
    PKSselect: MessageBox('This feature will be'#3'allowed in future.',
                          tOk,tOk,bButton[tOk],mbClrs,'Sorry..');
    PKSuser3: begin {Space}
                LO^[curLO]^.Marked:=not LO^[curLO]^.Marked;
                PickCmdNum:=PKSdown;
                EvaluatePickCommand(wLO,@GetLoItem,totalLO,curLO,topLO,
                                    PickCmdNum);
              end;
    PKSuser2,
    PKSuser4: {F8,Ctrl/F8} begin
                KillFromLO(PickCmdNum =PKSuser2);
                for curLO:=1 to totalLO do
                  FreeMem(LO^[curLO],SizeOf(tLoItem));
                if not Scan_LO then PickCmdNum:=PKsexIt;
                ClrScr;
              end;
   end;
 until PickCmdNum =PKsexIt;
 { free memory }
 KillWindow(wLO);
 RestoreWindow(1,4,80,ScreenHeight-5,true,SavScr);
 { exit point }
Xit_LO:
 for curLO:=1 to totalLO do
  FreeMem(LO^[curLO],SizeOf(tLoItem));
 FreeMem(LO,SizeOf(tLO));
 PickCmdNum:=PKSnone;
end;

end.
