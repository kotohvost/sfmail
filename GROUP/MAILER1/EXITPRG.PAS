unit ExitPrg;
interface
uses Dos,
     SFInclud,
     Fos_Lib,
     keyb,
     TString_,
     TPCRT,
     SF_Snd,
     TPWindow,
     Crc_All,
     Debug,
     flags,
     EventMan,
     Em_Cpl,
     EmStruct,
     WriteLog,
     Config,
     MsgXs;

procedure MyExit;

implementation

{$F+}
procedure MyExit;
begin
 ExitProc:=OldExitProc;
 RestoreInt9;
 If TimeAES then
 DeleteAESClient(TimeHandl);
 If LampsAES then
 DeleteAESClient(LampsHandl);
 FullClose;
 TextAttr:=$07;
 ClrScr;

   case ExitCode of
     0       : begin
               Writeln('Exiting: forced by operator');
               LogWrite(imNormalExit,'',ld_File);
               end;
     20..100 : begin
               Writeln('User exit, errorlevel '+long2Str(ExitCode));
               LogWrite(imUserExit,long2Str(ExitCode),ld_File);
               end;
     208,209 : Writeln('Error exit: access to overlay denied');
     210     : begin
               Writeln('Error exit: access to fossil denied');
               LogWrite(emFossilNotFound,'',ld_File);
               end;
     211     : begin
               Writeln('Error exit: can''t init modem');
               LogWrite(emCantInitModem,'',ld_File);
               end;
     220     : Writeln('Error exit: can''t read config file');
     221     : Writeln('Error exit: can''t open log file');
     222,223 : begin
               Writeln('Error exit: Nodelist error');
               end;
     225     : Writeln('Error exit: sf-mail.lng error');
     230     : begin
               Writeln('Error exit: can''t init event manager');
               LogWrite(emCantInitEvents,'',ld_File);
               end;
     231     : begin
               Writeln('Error exit: can''t init NodeList access module');
               LogWrite(emCantInitNdlXs,'',ld_File);
               end;
       else
           if ErrorAddr<> nil then begin
             Writeln('Error exit: errorlevel ',ExitCode,' at ',HexPtr(ErrorAddr));
             LogWrite(emUndefinedError,long2Str(ExitCode)+' ('+HexPtr(ErrorAddr)+')',ld_File);
           end else begin
             Writeln('Error exit: errorlevel ',ExitCode);
             LogWrite(emUndefinedError,long2Str(ExitCode),ld_File);
           end;
           WriteDebug;
  end;

 If (ExitCode>100) and (ExitCode<>240) then PlaySound(TSndError);
 If (RLSize<>0) and (QLSize<>0) and (ELSize<>0) then
    CloseEventMan;
 If (ExitCode<>222) and (ExitCode<>230) and (ExitCode<>231) then
 EraseSemaphore(pCfgRec^.Flags_Dir+'sf-mail.wr');

 CloseLogFile;

 CheckBreak  := SaveBreak;
 SetCBreak(SaveDosBreak);
  Dispose(LogBuffer);
  Dispose(ModBuffer);
  Dispose(FileLogBuffer);
  Dispose(SesBuffer);
  Dispose(EMSI_DAT_R);

 SetBlink(true);
 NormalCursor;

 Halt(ExitCode);
end;
{$F-}

end.