Type
  Key = record
   Passwords     : MDigest;
   SysopName     : string[39];
   SerialNumber  : string[7];
   CRC32Table    : array [0..255] of longInt;
   CRC16Table    : array [0..255] of word;
   CRC16Hydra    : array [0..255] of word;
  end;
