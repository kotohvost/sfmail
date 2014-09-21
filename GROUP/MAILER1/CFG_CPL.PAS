uses
 Dos,
 SFM_Cfg;

begin
 writeln(#10'Sf-Mail Configuration file compiler'#10);

 if ParamCount <>2 then begin
  writeln(#10'USAGE: Cfg_Cpl.exe <AscConfig> <BinConfig>'#10#7);
  halt;
 end;

 writeln(' Input file: '+ParamStr(1)+#13#10' Output file: '+ParamStr(2)+#10);
 if not CompileConfig(ParamStr(1),ParamStr(2)) then
   writeln('UNABLE to COMPILE '+ParamStr(1)+' into '+ParamStr(2)+'!')
 else
   writeln('-Done!');
end.