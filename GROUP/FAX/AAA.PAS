uses bitlib;
var
  a  : array [1..200] of byte;
  b  : array [1..400] of byte;
  i  : word;
  k  : word;
begin
  a[100]:=$92;
  a[101]:=$FF;
  a[102]:=$AA;
  for i:=1 to 2{000} do
     ScaleBit(a,200,200,b,400);
  for i:=800 to 863 do
  write(getglobalbit(@a,i,200));

  writeLn;
  for i:=1600 to 1663 do
  write(getglobalbit(@b,i,400));
end.