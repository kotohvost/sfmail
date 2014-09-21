Program DESTEST;

Uses Dos,
     CryptLib,
     Strings;

Var
  ReadBuff:pointer;
  RealRead:word;
  Password : array[0..7] of char;
  InitVect : array[0..7] of char;
  workFile : file;
begin
  Password:='SAMDURAK';
  InitVect:='12345678';
  GetMem(ReadBuff,$8000);
  if not DesInit( @Password[0], @InitVect[0], 0 ) then begin
    Writeln( 'DES Tables were Changed!!! DES System Halted!!!');
    halt(255);
  end;

  Assign(workFile,'Test.txt');
  Reset(workFile,1);
  BlockRead(workFile,ReadBuff^,$8000, RealRead );
  RealRead:= RealRead and ( not $7 );
  Des_Crypt_CBC_Block( ReadBuff, ReadBuff, RealRead );
  Close(workFile);

  Assign(workFile,'Test.des');
  Rewrite(workFile,1);
  BlockWrite(workfile,ReadBuff^,RealRead);
  Close(workFile);

  DesInit( @Password[0], @InitVect[0], 1 );
  Assign(workFile,'Test.Des');
  Reset(workFile,1);
  BlockRead(workFile,ReadBuff^,$8000,RealRead );
  RealRead:= RealRead and ( not $7 );
  Des_DeCrypt_CBC_Block( ReadBuff, ReadBuff, RealRead );
  Close(WorkFile);

  Assign(workFile,'Test1.doc');
  Rewrite(workfile,1);
  BlockWrite(workfile,ReadBuff^,RealRead);
  Close(workFile);
  DesDeInit;
end.