{$O+,F+,I-}
unit StatView;
interface
uses TPCRT,
     SFInclud,
     Dos,
     TPDos,
     fos_lib,
     eventman,
     fileMan,
     HM,
     TString_,
     Config,
     WriteLog,
     TPWindow;

procedure OpenHistory;
procedure ShowHistory;
procedure WriteHist;

Type
  tSession = record
   Info      : String[62];
   DateCall  : String[15];
  end;

Type
  tStatistic = record
   Sessions  : array [1..5] of tSession;
   AllSend   : LongInt;
   AllRecv   : LongInt;
   SessOk    : word;
   SessAb    : word;
   end;

Var
   Statistic : tStatistic;
   StatFile  : file of tStatistic;
   StatDate  : DateTime;
   StatDateL : LongInt;

implementation

procedure OpenHistory;
Var
  i : byte;
begin
  Assign(StatFile,'SF-Mail.st'+Copy(HexB(Task),2,1));
  Reset(StatFile);
  Read(StatFile,Statistic);
  If IOResult <> 0 then begin
    Rewrite(StatFile);
    with Statistic do begin
     for i:=1 to 5 do begin
       Sessions[i].Info:='';
       Sessions[i].DateCall:='';
     end;
     AllSend   :=0;
     AllRecv   :=0;
     SessOk    :=0;
     SessAb    :=0;
    end;
    Write(StatFile,Statistic);
  end;
  Close(StatFile);
end;

procedure ShowHistory;
Var
  i : byte;
begin
  Reset(StatFile);
  GetFTime(StatFile,StatDateL);
  UnPackTime(StatDateL,StatDate);
  If StatDate.Day<>Day then begin
    with Statistic do begin
      AllSend   :=0;
      AllRecv   :=0;
      SessOk    :=0;
      SessAb    :=0;
    end;
    Close(StatFile);
    Rewrite(StatFile);
    Write(StatFile,Statistic);
    Close(StatFile);
  end else begin
    Read(StatFile,Statistic);
    Close(StatFile);
  end;
  With Statistic do begin
    for i:=1 to 5 do begin
      FastWrite(Sessions[i].Info,ScreenHeight-9+i,18,pCfgRec^.SfMailColors[LastCall_Color]);
      ChangeAttribute(5, ScreenHeight-9+i, 63,
                      (pCfgRec^.SFMailColors[LastCall_Color] and $F0) or $0A);
      ChangeAttribute(5, ScreenHeight-9+i, 69,
                      (pCfgRec^.SFMailColors[LastCall_Color] and $F0) or $0C);
      FastWrite(Sessions[i].DateCall,ScreenHeight-9+i,2,pCfgRec^.SfMailColors[LastCall_Color]);
    end;
    FastWrite(Long2Str(MemAvail),ScreenHeight-2,57,pCfgRec^.SfMailColors[Info_Color]);
    If pCfgRec^.Inbound_Dir[2]<>':' then
      DiskSpace:=VirtualDiskFree(0)
    else begin
      if pCfgRec^.Inbound_Dir[1] in ['A'..'Z'] then
        DiskSpace:=VirtualDiskFree(byte(pCfgRec^.Inbound_Dir[1])-$40);
      if pCfgRec^.Inbound_Dir[1] in ['a'..'z'] then
        DiskSpace:=VirtualDiskFree(byte(pCfgRec^.Inbound_Dir[1])-$60);
    end;
  end;
  If DiskSpace < pCfgRec^.MinDiskSpace then begin
    If pCfgRec^.SysFlags and clrBlinking <> 0 then begin
     FastWrite(Pad(vinbestform(DiskSpace),6),ScreenHeight-2,29,(pCfgRec^.SfMailColors[Info_Color] and $F0) or $8C);
    end else begin
     FastWrite(Pad(vinbestform(DiskSpace),6),ScreenHeight-2,29,(pCfgRec^.SfMailColors[Info_Color] and $F0) or $0C);
    end;
  end else
    FastWrite(Pad(vinbestform(DiskSpace),6),ScreenHeight-2,29,pCfgRec^.SfMailColors[Info_Color]);
end;

procedure WriteHist;
begin
  If IOResult<>0 then {clear};
  Rewrite(StatFile);
  Write(StatFile,Statistic);
  Close(StatFile);
  TimeCounter:=0;
  If IOResult<>0 then {clear};
end;

end.
