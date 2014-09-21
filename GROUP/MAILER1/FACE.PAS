{$O+,F+}
Unit face;

interface
procedure DrawUpLine;
procedure Draw_Face;

implementation
uses TPCRT,
     SFINCLUD,
     Config,
     KeyRead,
     Flags,
     adir,
     msgXs,
     TString_;

procedure DrawUpLine;
Var
  i : byte;
  s : string;
begin
  {–Ά¥β Ά¥pε­¥© αβp®ª¨}
  If pCfgRec^.SysFlags and clrBlinking <> 0 then
    i:=$70 else i:=$80;
  {¥¦¨¬ p ΅®βλ ¬¥©«¥p }
  with pCfgRec^ do begin
    if Length(BinkOutbound) <>0 then begin
      s:='Bink';
      if (SysFlags and amaPack <>0) and (SysFlags and amaUnpack <>0) then
        s:=s+'/Ama'
      else
       if (SysFlags and amaPack) <>0 then
         s:=s+'/Pack'
       else begin
         if (SysFlags and amaUnpack) <>0 then
         s:=s+'/Unp';
       end;
    end else
      s:='Ama';
    if (SysFlags and amaScan) <>0 then
         s:=s+'*';
  end;
  {‚λΆ®¤ ‹¥Ά®© ―®«®Ά¨­λ}
  FastWrite(Pad(' '+PID+'/'+VID+NID+' ('+s+')',48),1,1,i+$0E);
  {‚λΆ®¤  ¤p¥α }
  S:=Addr2Str(pCfgRec^.MyAddress[1],pCfgRec^.MyAddress[1].point<>0)+' ';
  FastWrite(LeftPad('Address: ',32-Length(S)),1,49,i+$02);
  FastWrite(S,1,81-Length(S),i+$0F);
end;

procedure Draw_Face;
 var i:byte;
     Str : string[23];
     s: string;
     s1: string;
begin
 {* Calculate Len of Session Log *}
 If ScreenHeight>27 then
   SessionLines:=ScreenHeight-22
 else
   SessionLines:=5;

 TextAttr:=pCfgRec^.SfMailColors[Border_Color];
 ClrScr;

 FastWrite('Υ'+PadCh('','Ν',62)+'Ρ'+PadCh('','Ν',15)+'Έ'
           ,2,1,pCfgRec^.SfMailColors[Border_Color]);
 FastWrite('³',3,1,pCfgRec^.SfMailColors[Border_Color]);
 FastWrite('³',3,64,pCfgRec^.SfMailColors[Border_Color]);
 FastWrite('³',3,80,pCfgRec^.SfMailColors[Border_Color]);
 FastWrite('Γ'+PadCh('','Δ',62)+'Ε'+PadCh('','Δ',15)+'΄'
           ,4,1,pCfgRec^.SfMailColors[Border_Color]);
 for i:=5 to ScreenHeight-10 do begin
   FastWrite('³',i,1,pCfgRec^.SfMailColors[Border_Color]);
   FastWrite('³',i,64,pCfgRec^.SfMailColors[Border_Color]);
   FastWrite('³',i,80,pCfgRec^.SfMailColors[Border_Color]);
 end;

 FastWrite('Γ'+PadCh('','Δ',62)+'Α'+PadCh('','Δ',15)+'΄'
           ,ScreenHeight-9,1,pCfgRec^.SfMailColors[Border_Color]);
 for i:=ScreenHeight-8 to ScreenHeight-4 do begin
   FastWrite('³',i,1,pCfgRec^.SfMailColors[Border_Color]);
   {FastWrite('³',i,64,pCfgRec^.SfMailColors[Border_Color]);}
   FastWrite('³',i,80,pCfgRec^.SfMailColors[Border_Color]);
 end;
 FastWrite('Γ'+PadCh('','Δ',62)+'Β'+PadCh('','Δ',15)+'΄'
           ,ScreenHeight-3,1,pCfgRec^.SfMailColors[Border_Color]);

 FastWrite('³',ScreenHeight-2,1,pCfgRec^.SfMailColors[Border_Color]);
 FastWrite('³',ScreenHeight-2,64,pCfgRec^.SfMailColors[Border_Color]);
 FastWrite('³',ScreenHeight-2,80,pCfgRec^.SfMailColors[Border_Color]);

 FastWrite('Τ'+PadCh('','Ν',62)+'Ο'+PadCh('','Ν',15)+'Ύ'
           ,ScreenHeight-1,1,pCfgRec^.SfMailColors[Border_Color]);

 FastWrite('Date:',3,3,pCfgRec^.SfMailColors[Date_Color]);
 FastWrite('Log Echo',3,28,pCfgRec^.SfMailColors[Header_Color]);
 FastWrite('Time:',3,49,pCfgRec^.SfMailColors[Date_Color]);
 FastWrite('Modem  Status',3,66,pCfgRec^.SfMailColors[Header_Color]);

  DrawUpLine;

  FastWrite('Task:     Free Disk Space:        Timing:         Mem:',ScreenHeight-2,2,pCfgRec^.SfMailColors[Stat_Color]);
  FastWrite(long2Str(Task),ScreenHeight-2,8,pCfgRec^.SfMailColors[Info_Color]);

  If not checkSN then begin
    s:='Press F1 for Help';
    s1:='³  F1 for Help   ';
  end else begin
    s:='Registered version, S/N: '+SerialNo;
    s1:='³  S/N: '+SerialNo+'  ';
  end;
  If pCfgRec^.SysFlags and clrBlinking <> 0 then begin
    If not (pCfgRec^.Modem_Lamps) then
      FastWrite(Center(s,80),ScreenHeight,1,$7F) else
      FastWrite(LeftPad(s1,80),ScreenHeight,1,$7F);
    ILColors[1]:=$1E;
    ILColors[2]:=$1F;
    GrayPane:=false;
  end else begin
    If not (pCfgRec^.Modem_Lamps) then
      FastWrite(Center(s,80),ScreenHeight,1,$8F) else
      FastWrite(LeftPad(s1,80),ScreenHeight,1,$8F);
    ILColors[1]:=$8B;
    ILColors[2]:=$8F;
    GrayPane:=true;
  end;
end;

end.