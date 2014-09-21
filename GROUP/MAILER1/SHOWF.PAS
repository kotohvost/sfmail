{$F+}
unit ShowF;

interface
uses SFInclud,
     Config,
     TPCRT,
     Date,
     RelTQ,
     TString_,
     Show;

procedure ShowBytes(ShowBytes : word);

Var
  DrawTime     : byte;
  LenSizes     : byte;

implementation

procedure ShowBytes(ShowBytes : word);
var
  y : byte;
begin
  If TermMode then y:=7 else y:=9;
  If ShowBytes=0 then ReleaseTQ;
  FastWriteWindow(LeftPad(long2Str(TransferStart + TransferBytes + ShowBytes),lenSizes),
                  y,41,pCfgRec^.SfMailColors[Session_Param]);
  If DrawTime>5 then begin
    if not TermMode then begin
      ShowTime;
      ShowSessTime;
    end;
    if ReceiveSize<>0 then
      FastWriteWindow('('+LeftPad(
                 long2Str(((TransferStart + TransferBytes + ShowBytes)*100)
                 div ReceiveSize),3)+'%)',
                 y,52,pCfgRec^.SfMailColors[Session_Param]) else
      FastWriteWindow('(100%)',y,52,pCfgRec^.SfMailColors[Session_Param]);
    DrawTime:=0;
  end else
    Inc(DrawTime);
end;

end.