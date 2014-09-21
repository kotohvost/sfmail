{$O+,F+}
unit debug;
interface
procedure WriteDebug;
procedure Draw_Debug;
procedure Show_Stati;

implementation
uses TPCRT,
     ProcMan,
     WriteLog,
     EventMan,
     HShow,
     RelTQ,
     Modem,
     Em_Cpl,
     StatView,
     EmStruct,
     TString_,
     SFInclud,
     SF_Dbg,
     CRC_All,
     Config,
     Keyb,
     TPWindow;

procedure WriteDebug;
begin
  LogWrite(0,'Debug Statistic:',ld_File);
  LogWrite(0,'MemAvail:    '+Long2Str(MemAvail),ld_File);
  LogWrite(0,'MaxAvail:    '+Long2Str(MaxAvail),ld_File);
  LogWrite(0,'HeapPtr:    $'+HexW(Seg(HeapPtr^))+':'+HexW(Ofs(HeapPtr^)),ld_File);
  LogWrite(0,'Route Size:  '+Long2Str(RLSize),ld_File);
  LogWrite(0,'Queue Size:  '+Long2Str(QLSize),ld_File);
  LogWrite(0,'Events Size: '+Long2Str(ELSize),ld_File);
  LogWrite(0,'SS Reg:     $'+HexWord(SSeg),ld_File);
  LogWrite(0,'SP Reg:     $'+HexWord(SPtr),ld_File);
  LogWrite(0,'Free Stack space: '+Long2Str(SPtr),ld_File);
end;

procedure Draw_Debug;
  Var
    CH  : char;
begin

  MakeWindow(PWin,10,ScreenHeight div 2 - 7,70,ScreenHeight div 2 + 7,true,true,true,
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Header],
             'µ Debug Info Æ');
  DisplayWindow(Pwin);
  ClrScr;

  FastWriteWindow('ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´',4,0,pCfgRec^.SfMailColors[Session_Border]);
  FastWriteWindow('MemAvail: '+Long2Str(MemAvail),1,2,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('MaxAvail: '+Long2Str(MaxAvail),2,2,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('HeapPtr:  '+HexW(Seg(HeapPtr^))+':'+HexW(Ofs(HeapPtr^)),3,2,pCfgRec^.SfMailColors[Session_File]);

  FastWriteWindow('Route Size:  '+Long2Str(RLSize),1,30,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Queue Size:  '+Long2Str(QLSize),2,30,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Events Size: '+Long2Str(ELSize),3,30,pCfgRec^.SfMailColors[Session_File]);

  FastWriteWindow('SS Reg:   $'+HexWord(SSeg),5,2,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('SP Reg:   $'+HexWord(SPtr),6,2,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Free Stack space: '+Long2Str(SPtr),7,2,pCfgRec^.SfMailColors[Session_File]);

  If EMSI_DatFile then
  FastWriteWindow('EMSI Dat Debug Mode: On ',5,30,pCfgRec^.SfMailColors[Session_File])
     else
  FastWriteWindow('EMSI Dat Debug Mode: Off',5,30,pCfgRec^.SfMailColors[Session_File]);

  If TraceMode then
  FastWriteWindow('Protocol Trace File: On ',8,30,pCfgRec^.SfMailColors[Session_File])
     else
  FastWriteWindow('Protocol Trace File: Off',8,30,pCfgRec^.SfMailColors[Session_File]);

  If MsgDebugMode then
  FastWriteWindow('Msg Debug Mode: On ',8,2,pCfgRec^.SfMailColors[Session_File])
     else
  FastWriteWindow('Msg Debug Mode: Off',8,2,pCfgRec^.SfMailColors[Session_File]);

  FastWriteWindow('xMailer Count: '+Long2Str(TotalxMail),6,30,pCfgRec^.SfMailColors[Session_File]);
  If ArcMailInStorage <> MaxInt then
   FastWriteWindow('ArcMail Recv.: '+Long2Str(ArcMailInStorage)+' kB',7,30,pCfgRec^.SfMailColors[Session_File]) else
   FastWriteWindow('ArcMail Recv.: No sessions',7,30,pCfgRec^.SfMailColors[Session_File]);

  FastWriteWindow('Press ''Enter'' for save Debug Info, ',11,2,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Other key ---> Exit from Debug Info. ',12,2,pCfgRec^.SfMailColors[Session_File]);

  repeat
     If AskExit then begin
        KillWindow(PWin);
        exit;
     end;
     if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
        if keypressed then begin
          ch:=readkey;
          case ch of
          #13 : begin
                 WriteDebug;
                 KillWindow(PWin);
                 exit;
          end;
          #8  : begin
                 EMSI_DatFile:= not EMSI_DatFile;
                 If EMSI_DatFile then
                   FastWriteWindow('EMSI Dat Debug Mode: On ',5,30,pCfgRec^.SfMailColors[Session_File])
                 else
                   FastWriteWindow('EMSI Dat Debug Mode: Off',5,30,pCfgRec^.SfMailColors[Session_File]);
          end;
          #0  : begin
                 ch:=readkey;
                 case ch of
                 #44: begin
                       TraceMode:=not TraceMode;
                       If TraceMode then
                         FastWriteWindow('Protocol Trace File: On ',8,30,pCfgRec^.SfMailColors[Session_File])
                       else
                         FastWriteWindow('Protocol Trace File: Off',8,30,pCfgRec^.SfMailColors[Session_File]);
                 end;
                 #50: begin
                       MsgDebugMode:=not MsgDebugMode;
                       If MsgDebugMode then
                         FastWriteWindow('Msg Debug Mode: On ',8,2,pCfgRec^.SfMailColors[Session_File])
                       else
                         FastWriteWindow('Msg Debug Mode: Off',8,2,pCfgRec^.SfMailColors[Session_File]);
                      end;
                 #68: begin
                       ShowOurFiles;
                      end;
                 else
                   KillWindow(PWin);
                   exit;
                 end;
          end;
          else
           KillWindow(PWin);
           exit;
          end;
        end else
        IfKeyPress:=0;
     end;
  releaseTQ;
  until false;
end;

procedure Show_Stati;
  Var
    CH  : char;
begin
  ShowHistory;
  MakeWindow(PWin,21,ScreenHeight div 2 - 4,60,ScreenHeight div 2 + 4,true,true,true,
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Border],
             pCfgRec^.SfMailColors[Session_Header],
             'µ Statistic Viewer Æ');
  DisplayWindow(Pwin);
  ClrScr;

  FastWriteWindow('ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´',2,0,pCfgRec^.SfMailColors[Session_Border]);
  FastWriteWindow('ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´',5,0,pCfgRec^.SfMailColors[Session_Border]);

  FastWriteWindow('Today Statistic:',1,12,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Today Send       : '+Long2Str(Statistic.AllSend),3,2,pCfgRec^.SfMailColors[Session_File]);
  FastWriteWindow('Today Receive    : '+Long2Str(Statistic.AllRecv),4,2,pCfgRec^.SfMailColors[Session_File]);
  If Statistic.SessOk+Statistic.SessAb <> 0 then begin
    FastWriteWindow('Session complete : '+Long2Str(Statistic.SessOk)+' ('+
                    Long2Str(round((Statistic.SessOk / (Statistic.SessOk+Statistic.SessAb))* 100))+'%)',
                    6,2,pCfgRec^.SfMailColors[Session_File]);

    FastWriteWindow('Session aborted  : '+Long2Str(Statistic.SessAb)+' ('+
                    Long2Str(round((Statistic.SessAb / (Statistic.SessOk+Statistic.SessAb))* 100))+'%)',
                    7,2,pCfgRec^.SfMailColors[Session_File]);
  end else begin
    FastWriteWindow('Session complete : 0 (0%)',
                     6,2,pCfgRec^.SfMailColors[Session_File]);

    FastWriteWindow('Session aborted  : 0 (0%)',
                     7,2,pCfgRec^.SfMailColors[Session_File]);
  end;

  repeat
     If AskExit then
        begin
        KillWindow(PWin);
        exit;
        end;
    if (IfKeyPress<>0) or ((pCfgRec^.SysFlags and mscPollKbd) <> 0) then begin
     if keypressed then
        begin
        ch:=readkey;
        if ch=#0 then ch:=ReadKey;
        KillWindow(PWin);
        exit;
        end else
        IfKeyPress:=0;
     end;
  ReleaseTQ;
  until false;
end;

end.
