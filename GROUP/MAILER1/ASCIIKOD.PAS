uses tpcrt,
     CRC_All;
var ch:char;
begin
Writeln('ScanCode Shower by Anton the Deinow (c)');
Writeln('{Press ESC for exit}');
Writeln('---');
repeat
ch := readkey;
if ch=#0 then begin
               ch:=readkey;
               writeln(hexbyte(byte(ch)),'00 hex');
               end else
writeln('00',hexbyte(byte(ch)),' hex');
until ch=#27;
Writeln('---');
end.