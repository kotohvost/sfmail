{$F+,O+,I-}
unit keyread;

interface

Uses Dos,
     SFInclud,
     tString_,
     Config,
     Fos_Lib,
     CRC_All,
     CryptLib;

{$I keytype.inc}
var
  keyDat   : key;
const
  CheckSN    : boolean = false;
  KeyPresent : boolean = false;

procedure ReadSN;

implementation

procedure ReadSN;
Var
  tempStr   : String;
  CheckPass : MDigest;
  i         : byte;
  l         : longint;
begin
  CheckSN:=false;
  If not KeyPresent then exit;
  With KeyDat do begin
    if not DesInit( @Passwords[0], @Passwords[8], 1) then begin
      Writeln( 'DES Tables were Changed!!! DES System Halted!!!');
      halt(255);
    end;
    Des_DeCrypt_CBC_Block(@SysopName, @pCfgRec^.Sysop, 40);
    Des_DeCrypt_CBC_Block(@SerialNumber, @SerialNo, 8);
    Des_DeCrypt_CBC_Block(@CRC32Table, @crc_32_tab, 1024);
    Des_DeCrypt_CBC_Block(@CRC16Table, @crctab, 512);
    Des_DeCrypt_CBC_Block(@CRC16Hydra, @crc16tab, 512);
    CheckSN:=true;
    l:=0;
    for i:=length(pCfgRec^.Sysop)+1 to 39 do
      l:=l+byte(pCfgRec^.Sysop[i]);
    if l<>0 then
      move(pCfgRec,CRC_32_Tab[2],15);
  end;
  DesDeInit;

  TempStr:=pCfgRec^.Sysop+SerialNo;
  MD5Digest(CheckPass,TempStr,length(TempStr)+1);

  If CompStruct(CheckPass,KeyDat.Passwords,16)<> Equal then
    move(CRC_32_Tab,pCfgRec^,1024);
end;

end.