{ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
 ³             HexMagic (HM)                   ³
 ³              v1.01/beta                     ³
 ³ (C)1994 Anton Deinow Software Research Lab. ³
 ³            All rights reserved.             ³
 ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´
 ³ This unut contains very useful routines to  ³
 ³ convertation data between hex and decimal.  ³
 ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ}

{$O+,F+}
Unit HM;

INTERFACE

function HexOne(H:char):byte;
{-¯¥p¥¢®¤¨â á¨¬¢®« ('0'..'9','A'..'F') ¢ ¥£® ¯®«ã-¡ ©â®¢ë© íª¢¨¢ «¥­â}

function Hex2Byte(s:string):byte;
{-áâp®ªã HEX -> ¢ ¡ ©â}

function Hex2Word(s:string):word;
{-áâp®ªã HEX -> ¢ á«®¢®}

function Hex2Long(s:string):longint;
{-áâp®ªã HEX -> ¢ ¤¢®©­®¥ á«®¢®}


IMPLEMENTATION

function HexOne(H:char):byte;
{-¯¥p¥¢®¤¨â á¨¬¢®« ('0'..'9','A'..'F') ¢ ¥£® ¡ ©â®¢ë© íª¢¨¢ «¥­â}

begin
 HexOne:=0;
 if H in ['A'..'F'] then HexOne:=ord(H)-$37
 else if H in ['0'..'9'] then HexOne:=ord(H)-$30;
end;

function Hex2Byte(s:string):byte;
{-áâp®ªã HEX -> ¢ ¡ ©â}
var
 b,i:byte;

begin
 b:=0;
 for i:=1 to Length(s) do b:=(b shl 4)+HexOne(s[i]);
 Hex2Byte:=b;
end;

function Hex2Word(s:string):word;
{-áâp®ªã HEX -> ¢ á«®¢®}
var
 w:word;
 i:byte;

begin
 w:=0;
 for i:=1 to Length(s) do w:=(w shl 4)+HexOne(s[i]);
 Hex2Word:=w;
end;

function Hex2Long(s:string):longint;
{-áâp®ªã HEX -> ¢ ¤¢®©­®¥ á«®¢®}
var
 L:longint;
 i:byte;

begin
 L:=0;
 for i:=1 to Length(s) do L:=(L shl 4)+HexOne(s[i]);
 Hex2Long:=L;
end;

end. {-the end of unit}
