Program test;

Uses
    testdev;

Var
   rc :boolean;
   Name :string;
begin
 Name := 'SCREEN$';
 if VerifyRights( Name , O_RDWR, SH_DENYNO ) then
  Writeln(Name,' is valid filename') else
  Writeln(Name,' is not valid filename');
 Name := 'COM1';
 if VerifyRights( Name , O_RDWR, SH_DENYNO ) then
  Writeln(Name,' is valid filename') else
  Writeln(Name,' is not valid filename');
end.
