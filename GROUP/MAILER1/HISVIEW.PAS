{$X+,I-,O+,F+}

UNIT HisView;

INTERFACE

uses
 EmStruct;

procedure ViewHistory(ts:tSessionType);

IMPLEMENTATION
uses
 Config,
 Tstring_,
 TpCrt,
 EventMan,
 MsgXs;

const
 MaxPgHight=95;

type
 tViewCtl=record
   Total:word;
   Pages:byte;
   OnLastPage:byte;
   OnTop:word;
   CurPage:byte;
   Page:array[1..MaxPgHight] of tSessionStat;
 end;
 pViewCtl=^tViewCtl;

procedure ViewHistory(ts:tSessionType);
const
 wHeader:array[tSessionType] of string[8]=(
  'Inbound',
  'Outbound'
 );

var
 OldWind:WindowCoordinates;
 OldXY:word;
 Cover:pointer;
 f:file of tSessionStat;
 p:pViewCtl;
 NeedReDraw:boolean;
 done:boolean;
 cfa:FlexAttrs;
 PgHight:byte;

procedure NewPage;
var
 i,
 w:byte;
 l:longint;

begin
 ClrScr;

 with p^ do begin
  seek(f,pred(CurPage)*PgHight);

  if CurPage =Pages then w:=OnLastPage
  else w:=PgHight;

  for i:=1 to w do begin
   read(f,Page[i]);
   FastWriteWindow(DT2str(Page[i].SessionDateTime)+'  '+
                   Pad(Addr2str(Page[i].RemoteAddr,true),17)+
                   Copy(Pad(Page[i].RemoteName,27),1,27)+
                   LeftPad(vInShortBest(Page[i].TrafficIn),4)+' '+
                   LeftPad(vInShortBest(Page[i].TrafficOut),4),
                   i+2,1,pCfgRec^.SfMailColors[hv_SessInfo]);
   if Page[i].Status then
     FastWriteWindow('Err',i+2,76,pCfgRec^.SfMailColors[hv_StatusErr])
   else
     FastWriteWindow('Ok ',i+2,76,pCfgRec^.SfMailColors[hv_StatusOk]);
  end;

  FastWriteWindow('      Date/Time          Address             System name         Rcvd Sent St.',
                  1,1,pCfgRec^.SfMailColors[hv_TableHat]);
  FastVertWindow(CharStr('³',PgHight+2),1,21,pCfgRec^.SfMailColors[hv_Table]);
  FastVertWindow(CharStr('³',PgHight+2),1,38,pCfgRec^.SfMailColors[hv_Table]);
  FastVertWindow(CharStr('³',PgHight+2),1,65,pCfgRec^.SfMailColors[hv_Table]);
  FastVertWindow(CharStr('³',PgHight+2),1,70,pCfgRec^.SfMailColors[hv_Table]);
  FastVertWindow(CharStr('³',PgHight+2),1,75,pCfgRec^.SfMailColors[hv_Table]);
  FastWriteWindow('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÅÄÄÄÄÅÄÄÄ',
                  2,1,pCfgRec^.SfMailColors[hv_Table]);

  if Pages >1 then begin
    FastWrite('',4,80,pCfgRec^.SfMailColors[hv_ScrollBarArrows]);
    FastWrite('',ScreenHeight-2,80,pCfgRec^.SfMailColors[hv_ScrollBarArrows]);
    FastVert(CharStr('°',ScreenHeight-7),5,80,pCfgRec^.SfMailColors[hv_ScrollBar]);
    FastWrite('þ',5+(pred(CurPage)*(ScreenHeight-8)) div pred(Pages),80,
              pCfgRec^.SfMailColors[hv_ScrollBar]);
  end;
 end;
 needRedraw:=false;
end;

begin
 assign(f,HistoryFname[ts]);
 reset(f);
 if IoResult <>0 then exit;

 Move(pCfgRec^.SfMailColors[hv_Help],cfa,SizeOf(FlexAttrs));
 TextAttr:=pCfgRec^.SfMailColors[hv_SessInfo];
 GetMem(p,SizeOf(tViewCtl));
 PgHight:=ScreenHeight-5;

 with p^ do begin
  Total:=FileSize(f);
  Pages:=Total div PgHight;
  OnLastPage:=Total mod PgHight;
  if OnLastPage <>0 then Inc(Pages)
  else OnLastPage:=PgHight;

  OnTop:=1;
  CurPage:=1;
  done:=false;
  needRedraw:=true;
  CurPage:=Pages;

 { ¨­¨â¨¬ íªp ­ }
  OldXY:=WhereXY;
  StoreWindowCoordinates(OldWind);
  SaveWindow(1,1,80,pred(ScreenHeight),true,Cover);
  Window(2,2,79,ScreenHeight-2);
  FrameWindow(1,1,80,pred(ScreenHeight),pCfgRec^.SfMailColors[hv_Border],
              pCfgRec^.SfMailColors[hv_Header],' '+wHeader[ts]+' history ');
  FlexWriteWindow(' PgUp,PgDn:List history    Esc:Quit ',
                  ScreenHeight-2,22,cfa);
  repeat
   if needRedraw then NewPage;
   case ReadScanCode of
     keyPgUp,keyUp: if CurPage >1 then begin
                      needRedraw:=true;
                      Dec(CurPage);
                    end;
     keyPgDn,keyDn: if CurPage <Pages then begin
                      needRedraw:=true;
                      Inc(CurPage);
                    end;
     keyEsc,
     keyNull,
     keyAltI,
     keyAltO: done:=true; {Esc or AskExit}
   end;
  until done;
 end;

 close(f);
 FreeMem(p,SizeOf(tViewCtl));

 RestoreWindow(1,1,80,pred(ScreenHeight),true,Cover);
 RestoreWindowCoordinates(OldWind);
 TextAttr:=$7;
 GotoXYabs(System.Lo(OldXY),Hi(OldXY));
end;

end.
