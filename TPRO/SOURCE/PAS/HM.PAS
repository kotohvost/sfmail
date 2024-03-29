{旼컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
 �             HexMagic (HM)                   �
 �              v1.01/beta                     �
 � (C)1994 Anton Deinow Software Research Lab. �
 �            All rights reserved.             �
 쳐컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
 � This unut contains very useful routines to  �
 � convertation data between hex and decimal.  �
 읕컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�}

Unit HM;

INTERFACE

function HexOne(H:char):byte;
{-�쩺ⅱ�ㄸ� 歲Б�� ('0'..'9','A'..'F') � ⅲ� ��ャ-줎⒱��硫 咨˘쥯ゥ��}

function Hex2Byte(s:string):byte;
{-飡p�ゃ HEX -> � 줎⒱}

function Hex2Word(s:string):word;
{-飡p�ゃ HEX -> � 笹�¡}

function Hex2Long(s:string):longint;
{-飡p�ゃ HEX -> � ㄲ�þ�� 笹�¡}


IMPLEMENTATION

function HexOne(H:char):byte;
{-�쩺ⅱ�ㄸ� 歲Б�� ('0'..'9','A'..'F') � ⅲ� 줎⒱��硫 咨˘쥯ゥ��}

begin
 HexOne:=0;
 if H in ['A'..'F'] then HexOne:=ord(H)-$37
 else if H in ['0'..'9'] then HexOne:=ord(H)-$30;
end;

function Hex2Byte(s:string):byte;
{-飡p�ゃ HEX -> � 줎⒱}
var
 b,i:byte;

begin
 b:=0;
 for i:=1 to Length(s) do b:=(b shl 4)+HexOne(s[i]);
 Hex2Byte:=b;
end;

function Hex2Word(s:string):word;
{-飡p�ゃ HEX -> � 笹�¡}
var
 w:word;
 i:byte;

begin
 w:=0;
 for i:=1 to Length(s) do w:=(w shl 4)+HexOne(s[i]);
 Hex2Word:=w;
end;

function Hex2Long(s:string):longint;
{-飡p�ゃ HEX -> � ㄲ�þ�� 笹�¡}
var
 L:longint;
 i:byte;

begin
 L:=0;
 for i:=1 to Length(s) do L:=(L shl 4)+HexOne(s[i]);
 Hex2Long:=L;
end;

end. {-the end of unit}
