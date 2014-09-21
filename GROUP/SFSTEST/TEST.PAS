Uses
  modem,
  Fos_Lib;

Var
  ComPort : byte;
  i : integer;
begin
  Val(ParamStr(1),ComPort,i);
  ErrorCode:=InitFosLib(ComPort, 38400, false);
  WriteLn('Инициализаиpуем библиотеку:',ErrorCode);
  ErrorCode:=CloseFosLib;
  WriteLn('Закpываем библиотеку:',ErrorCode);
end.