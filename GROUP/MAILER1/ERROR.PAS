{$O+,F+}
unit Error;
interface
procedure ErrorMessage(ErrorStr : String; HaltCode:byte);

implementation
uses TPCRT,
     Fos_Lib,
     TString_;

procedure ErrorMessage(ErrorStr : String; HaltCode:byte);
begin
  FastWrite(Center(ErrorStr,80),ScreenHeight,1,$4F);
  ClrScr;
  FastWrite(Center(ErrorStr,80),1,1,$4F);
  TextAttr:=$07;
  Halt(HaltCode);
end;

end.