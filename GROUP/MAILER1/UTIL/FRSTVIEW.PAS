{$X+,I-}

uses
 Cfg,
 ReadCfg,
 Tstring_,
 SfM_Api,
 Dos;

const
 PID='Sf-Mail freq statistics viewer';
 VID='ver 0.1.1/alpha';
 CID='(c) Anton the Deinow, 1994';

type
 tFReqStatRec=record
  Addr:tAddress;
  LastFReq:longint;
  onDay,
  onWeek,
  onMonth:longint;
 end;

var
 CfgFname:PathStr;
 f:file of tFReqStatRec;
 sRec:tFReqStatRec;
 l:longint;
 td,
 dt:DateTime;
 s:string;

begin
 writeln(#13#10+PID+'; '+VID+#13#10+CID+#13#10);

 if ParamCount =0 then CfgFname:='Sf-Mail.cfg'
 else begin
   s:=ParamStr(1);
   if (s[1] ='/') or (s[1] ='-') then begin
     writeln(#10'Usage: FrStView[.exe] <CfgFile>'#13#10#10+
             'where <CfgFile> is the name of Sf-Mail`s configuration file'#10);
     halt(213);
   end;
   CfgFname:=DefaultExtension(ParamStr(1),'cfg');
 end;

 if not Read_Config(CfgFname) then begin
   writeln('Unable to read ',CfgFname);
   halt(254);
 end;

 assign(f,StatFname);
 reset(f);
 if IoResult <>0 then begin
   writeln('Unable to open '+StatFname+'!');
   halt(255);
 end;

 CreateMsgTimeStamp(l);
 UnpackTime(l,td);

 writeln(PadCh(' Ú','Ä',56)+'¿');
 writeln(' ³°±² File request statistics on '+Pad(MsgDateStamp,20)+'²±°³');
 writeln(PadCh(' À','Ä',56)+'Ù');

 repeat
  read(f,sRec);
  with sRec, pCfgRec^ do begin
    UnpackTime(LastFReq,dt);
    writeln(Pad(#13#10'şNode: '+_4D2str(sRec.Addr),30),
            'Last freq: ',dt.Day,'.',dt.Month,'.',dt.Year,' at ',
            dt.Hour,':',dt.Min,':',dt.Sec);

    if DateType(l).Date <>DateType(LastFReq).Date then onDay:=0;
    if dt.Month <>td.Month then onMonth:=0;
    if (DateType(l).Date div 7) <>(DateType(LastFReq).Date div 7) then onWeek:=0;

    writeln(' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·');
    writeln(' ³       ³     Limit     ³     Today     ³      Rest     º');
    writeln(' ³ÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄº');

    writeln(' ³ Day   ³ '+LeftPad(Long2str(FR_Daily_Limit),10)+' Kb ³ '+
             LeftPad(Long2str(onDay),10)+' Kb ³ '+
             LeftPad(Long2str(FR_Daily_Limit-onDay),10)+' Kb º');

    writeln(' ³ Week  ³ '+LeftPad(Long2str(FR_Weekly_Limit),10)+' Kb ³ '+
             LeftPad(Long2str(onWeek),10)+' Kb ³ '+
             LeftPad(Long2str(FR_Weekly_Limit-onWeek),10)+' Kb º');

    writeln(' ³ Month ³ '+LeftPad(Long2str(FR_Monthly_Limit),10)+' Kb ³ '+
             LeftPad(Long2str(onMonth),10)+' Kb ³ '+
             LeftPad(Long2str(FR_Monthly_Limit-onMonth),10)+' Kb º');

    writeln(' ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼'#13#10);
  end;
 until EOF(f);

 close(f);
end.
