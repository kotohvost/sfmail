Program DESTEST;
Uses Dos,
     CRC_All,
     CryptLib;

{$I keytype.inc}

Var
  f        : file of key;
  keyDat   : key;
  TempStr  : String;

begin
  With KeyDat do begin
    Write('Sysop:');ReadLn(SysopName);
    Write('S/N  :');ReadLn(SerialNumber);
    TempStr:=SysopName+SerialNumber;
    MD5Digest(Passwords,TempStr,length(TempStr)+1);
    move(crc_32_tab,CRC32Table,1024);
    move(crctab,CRC16Table,512);
    move(crc16tab,CRC16Hydra,512);
    if not DesInit( @Passwords[0], @Passwords[8], 0 ) then begin
      Writeln( 'DES Tables were Changed!!! DES System Halted!!!');
      halt(255);
    end;
    Des_Crypt_CBC_Block(@SysopName, @SysopName, 40);
    Des_Crypt_CBC_Block(@SerialNumber, @SerialNumber, 8);
    Des_Crypt_CBC_Block(@CRC32Table, @CRC32Table, 1024);
    Des_Crypt_CBC_Block(@CRC16Table, @CRC16Table, 512);
    Des_Crypt_CBC_Block(@CRC16Hydra, @CRC16Hydra, 512);
  end;

  Assign(f,'sf-mail.key');
  Rewrite(f);
  Write(f,KeyDat);
  Close(f);
  DesDeInit;
end.