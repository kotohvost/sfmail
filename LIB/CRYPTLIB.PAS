(* Интерфейсный модуль к крипто-библиотеке *)

{$DEFINE __CRYPT_LIB__}
{$O+,F+}
Unit CryptLib;

Interface
{$IFDEF OS2}

  Uses Os2def, Os2base, Use32;
  {$Cdecl+,AlignRec-,Orgname+}
  {$L SFCRYPT.LIB}

{$ELSE}

  {$O+,F+}

  {$L des_func.obj}
  {$L md5c.obj}

{$ENDIF}

{$IFNDEF VIRTUALPASCAL}
(* Warning!!!! Don't Change This Tables!!!! There are DES S-boxes *)
  Const S1 : array[0..63] of byte = (
      $0E0, $000, $040, $0F0, $0D0, $070, $010, $040,
      $020, $0E0, $0F0, $020, $0B0, $0D0, $080, $010,
      $030, $0A0, $0A0, $060, $060, $0C0, $0C0, $0B0,
      $050, $090, $090, $050, $000, $030, $070, $080,
      $040, $0F0, $010, $0C0, $0E0, $080, $080, $020,
      $0D0, $040, $060, $090, $020, $010, $0B0, $070,
      $0F0, $050, $0C0, $0B0, $090, $030, $070, $0E0,
      $030, $0A0, $0A0, $000, $050, $060, $000, $0D0
      );

  Const S2 : array[0..63] of byte = (
     $0F, $03, $01, $0D, $08, $04, $0E, $07,
     $06, $0F, $0B, $02, $03, $08, $04, $0E,
     $09, $0C, $07, $00, $02, $01, $0D, $0A,
     $0C, $06, $00, $09, $05, $0B, $0A, $05,
     $00, $0D, $0E, $08, $07, $0A, $0B, $01,
     $0A, $03, $04, $0F, $0D, $04, $01, $02,
     $05, $0B, $08, $06, $0C, $07, $06, $0C,
     $09, $00, $03, $05, $02, $0E, $0F, $09
     );

  Const S3 : array[0..63] of byte = (
     $0A0, $0D0, $000, $070, $090, $000, $0E0, $090,
     $060, $030, $030, $040, $0F0, $060, $050, $0A0,
     $010, $020, $0D0, $080, $0C0, $050, $070, $0E0,
     $0B0, $0C0, $040, $0B0, $020, $0F0, $080, $010,
     $0D0, $010, $060, $0A0, $040, $0D0, $090, $000,
     $080, $060, $0F0, $090, $030, $080, $000, $070,
     $0B0, $040, $010, $0F0, $020, $0E0, $0C0, $030,
     $050, $0B0, $0A0, $050, $0E0, $020, $070, $0C0
     );

  Const S4 : array[0..63] of byte = (
     $07, $0D, $0D, $08, $0E, $0B, $03, $05,
     $00, $06, $06, $0F, $09, $00, $0A, $03,
     $01, $04, $02, $07, $08, $02, $05, $0C,
     $0B, $01, $0C, $0A, $04, $0E, $0F, $09,
     $0A, $03, $06, $0F, $09, $00, $00, $06,
     $0C, $0A, $0B, $01, $07, $0D, $0D, $08,
     $0F, $09, $01, $04, $03, $05, $0E, $0B,
     $05, $0C, $02, $07, $08, $02, $04, $0E
     );

  Const S5 : array[0..63] of byte = (
     $020, $0E0, $0C0, $0B0, $040, $020, $010, $0C0,
     $070, $040, $0A0, $070, $0B0, $0D0, $060, $010,
     $080, $050, $050, $000, $030, $0F0, $0F0, $0A0,
     $0D0, $030, $000, $090, $0E0, $080, $090, $060,
     $040, $0B0, $020, $080, $010, $0C0, $0B0, $070,
     $0A0, $010, $0D0, $0E0, $070, $020, $080, $0D0,
     $0F0, $060, $090, $0F0, $0C0, $000, $050, $090,
     $060, $0A0, $030, $040, $000, $050, $0E0, $030
     );

  Const S6 : array[0..63] of byte = (
     $0C, $0A, $01, $0F, $0A, $04, $0F, $02,
     $09, $07, $02, $0C, $06, $09, $08, $05,
     $00, $06, $0D, $01, $03, $0D, $04, $0E,
     $0E, $00, $07, $0B, $05, $03, $0B, $08,
     $09, $04, $0E, $03, $0F, $02, $05, $0C,
     $02, $09, $08, $05, $0C, $0F, $03, $0A,
     $07, $0B, $00, $0E, $04, $01, $0A, $07,
     $01, $06, $0D, $00, $0B, $08, $06, $0D
     );

  Const S7 : array[0..63] of byte = (
     $040, $0D0, $0B0, $000, $020, $0B0, $0E0, $070,
     $0F0, $040, $000, $090, $080, $010, $0D0, $0A0,
     $030, $0E0, $0C0, $030, $090, $050, $070, $0C0,
     $050, $020, $0A0, $0F0, $060, $080, $010, $060,
     $010, $060, $040, $0B0, $0B0, $0D0, $0D0, $080,
     $0C0, $010, $030, $040, $070, $0A0, $0E0, $070,
     $0A0, $090, $0F0, $050, $060, $000, $080, $0F0,
     $000, $0E0, $050, $020, $090, $030, $020, $0C0
     );


  Const S8 : array[0..63] of byte = (
     $0D, $01, $02, $0F, $08, $0D, $04, $08,
     $06, $0A, $0F, $03, $0B, $07, $01, $04,
     $0A, $0C, $09, $05, $03, $06, $0E, $0B,
     $05, $00, $00, $0E, $0C, $09, $07, $02,
     $07, $02, $0B, $01, $04, $0E, $01, $07,
     $09, $04, $0C, $0A, $0E, $08, $02, $0D,
     $00, $0F, $06, $0C, $0A, $09, $0D, $00,
     $0F, $03, $03, $05, $05, $06, $08, $0B
     );

{$ENDIF}

  Const
    (* Методы шифровки *)
    ECB = 0;
    CBC = 1;
    (* Шифровка/Дешифровка *)
    ENCRYPT = 0;
    DECRYPT = 1;
  Type
    MD5_CTX = record
      State : array[0..3] of longint;
      Count : array[0..1] of longint;
      Buff  : array[0..63] of byte;
    end;
    MDigest = array[0..15] of byte;
    DESKeys = array[0..127] of byte;

{Функции DES модуля}

{$IFNDEF VIRTUALPASCAL}

  function  DesInit( Pass,IV : pointer; Crypt:byte ):boolean;far;
  procedure DesDeInit;far;
  procedure Des_Crypt_CBC_Block( Src, Dest : pointer; Size:word );far;
  procedure Des_DeCrypt_CBC_Block( Src, Dest : pointer; Size:word );far;
  procedure Des_Crypt_ECB( Src, Dest : pointer; Keys : DESKeys );far;
  procedure Des_Crypt_ECB_Block( Src, Dest : pointer; Size:word; Crypt:byte );far;



{Функции MD5 модуля}
  procedure MD5Digest( var Digest :MDigest; var Block; Size :word );far;
  procedure MD5Init( var MD5Context :MD5_CTX );far;
  procedure MD5Update( var MD5Context :MD5_CTX; var Block; Size :word);far;
  procedure MD5Final( var Digest :MDigest; var MD5Context :MD5_CTX );far;

{$ELSE}

  function  DesInit( Pass,IV : pointer; Crypt:byte ):boolean;
  procedure DesDeInit;
  procedure Des_Crypt_CBC_Block( Src, Dest : pointer; Size:ULONG );
  procedure Des_DeCrypt_CBC_Block( Src, Dest : pointer; Size:ULONG );
  procedure Des_Crypt_ECB( Src, Dest : pointer; Keys : DESKeys );
  procedure Des_Crypt_ECB_Block( Src, Dest : pointer; Size:ULONG; Crypt:byte );



{Функции MD5 модуля}
  procedure MD5Digest( var Digest :MDigest; var Block; Size :ULONG );
  procedure MD5Init( var MD5Context :MD5_CTX );
  procedure MD5Update( var MD5Context :MD5_CTX; var Block; Size :ULONG);
  procedure MD5Final( var Digest :MDigest; var MD5Context :MD5_CTX );

{$ENDIF}

Implementation

  function  DesInit;                    external; {Ordinal 5}
  procedure DesDeInit;                  external; {Ordinal 6}
  procedure Des_Crypt_CBC_Block;        external; {Ordinal 7}
  procedure Des_DeCrypt_CBC_Block;      external; {Ordinal 8}
  procedure Des_Crypt_ECB;              external; {Ordinal 10}
  procedure Des_Crypt_ECB_Block;        external; {Ordinal 11}
  procedure GenEncryptKeys;             external; {Ordinal 12}
  procedure GenDecryptKeys;             external; {Ordinal 13}

{Функции MD5 модуля}
  procedure MD5Init;                    external; {Ordinal 1}
  procedure MD5Update;                  external; {Ordinal 2}
  procedure MD5Final;                   external; {Ordinal 3}
  procedure MD5Digest;                  external; {Ordinal 4}

end.