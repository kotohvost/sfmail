Uses
  modem,
  Fos_Lib;

Var
  ComPort : byte;
  i : integer;
begin
  Val(ParamStr(1),ComPort,i);
  ErrorCode:=InitFosLib(ComPort, 38400, false);
  WriteLn('���樠�����p㥬 ������⥪�:',ErrorCode);
  ErrorCode:=CloseFosLib;
  WriteLn('���p뢠�� ������⥪�:',ErrorCode);
end.