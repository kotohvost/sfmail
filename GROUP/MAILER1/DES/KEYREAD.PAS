unit keyread;

interface

procedure ReadKey;

implementation

Uses Dos,
     CRC_All,
     CryptLib;

{$I keytype.inc}

procedure ReadKey;
Var
  f        : file of key;
  keyDat   : key;
  TempStr  : String;

begin
  Assign(f,'sf-mail.key');
  Reset(f);
  Read(f,KeyDat);
  Close(f);
  With KeyDat do begin
    if not DesInit( @Passwords[0], @Passwords[8], 1) then begin
      Writeln( 'DES Tables were Changed!!! DES System Halted!!!');
      halt(255);
    end;
    Des_DeCrypt_CBC_Block(@SysopName, @SysopName, 40);
    Des_DeCrypt_CBC_Block(@SerialNumber, @SerialNumber, 8);
    Des_DeCrypt_CBC_Block(@CRC32Table, @CRC32Table, 1024);
    Des_DeCrypt_CBC_Block(@CRC16Table, @CRC16Table, 512);
    Des_DeCrypt_CBC_Block(@CRC16Hydra, @CRC16Hydra, 512);
  end;
  DesDeInit;

  TempStr:=KeyDat.SysopName+KeyDat.SerialNumber;
  MD5Digest(KeyDat.Passwords,TempStr,length(TempStr)+1);

  Assign(f,'sf-mail1.key');
  Rewrite(f);
  Write(f,KeyDat);
  Close(f);
end;

end.