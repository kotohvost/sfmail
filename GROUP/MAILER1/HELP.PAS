{$O+,F+,I-}
unit help;
interface
procedure Draw_Help;

implementation
uses TPCRT,
     WriteLog,
     RelTQ,
     EventMan,
     TString_,
     SFInclud,
     Config,
     Keyb,
     Modem,
     TPWindow;

procedure Draw_Help;
  Var
    CH      : char;
    hlp     : text;
    ReadHlp : boolean;
    TempStr : String [58];
    Line    : byte;
begin
  ReadHlp:=false;
  MakeWindow(PWin,10,ScreenHeight div 2 - 7,70,ScreenHeight div 2 + 7,true,true,true,
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Header],
             'µ Help Æ');
  DisplayWindow(Pwin);
  ClrScr;
  Assign(hlp,'sf-Mail.hlp');
  Reset(hlp);
  If IOResult<>0 then
     FastWriteWindow('Help File not available;(',7,18,pCfgRec^.SfMailColors[Session_Param])
     else Readhlp:=true;

  If Readhlp then
     begin
     Line:=1;
     Repeat
       ReadLn(hlp,TempStr);
       FastWriteWindow(TempStr,Line,1,pCfgRec^.SfMailColors[Session_File]);
       Inc(Line);
       If Line=12 then begin
                       FastCenter('Press any key to continue `Esc` exit',Line+1,pCfgRec^.SfMailColors[Session_File] or $80);
                       Line:=1;
                       ch:=#0;
                       repeat
                       If AskExit then
                          begin
                          KillWindow(PWin);
                          Close(hlp);
                          exit;
                          end;
                       if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
                          if keypressed then
                             begin
                             ch:=readkey;
                             case ch of
                               #0  : ch:=ReadKey;
                               #27 : begin
                                     KillWindow(PWin);
                                     Close(hlp);
                                     exit;
                                     end;
                             end;
                             end else
                             IfKeyPress:=0;
                          end;
                       ReleaseTQ;
                       until Ch<>#0;
                       ClrScr;
                       end;
     until eof(hlp);
     end;

  FastCenter('Press any key to exit',13,pCfgRec^.SfMailColors[Session_File] or $80);
  ch:=#0;
  repeat
   If AskExit then
   Ch:=#27;
   if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
      if keypressed then
         begin
         ch:=readkey;
         if ch=#0 then ch:=ReadKey;
         end;
         end else
         IfKeyPress:=0;
         ReleaseTQ;
      until CH<>#0;

Close(hlp);
if IOResult = 0 then ;
KillWindow(PWin);

end;

end.
