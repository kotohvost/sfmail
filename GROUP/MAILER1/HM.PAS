{���������������������������������������������Ŀ
 �             HexMagic (HM)                   �
 �              v1.01/beta                     �
 � (C)1994 Anton Deinow Software Research Lab. �
 �            All rights reserved.             �
 ���������������������������������������������Ĵ
 � This unut contains very useful routines to  �
 � convertation data between hex and decimal.  �
 �����������������������������������������������}

{$O+,F+}
Unit HM;

INTERFACE

function HexOne(H:char):byte;
{-��p������ ᨬ��� ('0'..'9','A'..'F') � ��� ����-���⮢� ����������}

function Hex2Byte(s:string):byte;
{-��p��� HEX -> � ����}

function Hex2Word(s:string):word;
{-��p��� HEX -> � ᫮��}

function Hex2Long(s:string):longint;
{-��p��� HEX -> � ������� ᫮��}


IMPLEMENTATION

function HexOne(H:char):byte;
{-��p������ ᨬ��� ('0'..'9','A'..'F') � ��� ���⮢� ����������}

begin
 HexOne:=0;
 if H in ['A'..'F'] then HexOne:=ord(H)-$37
 else if H in ['0'..'9'] then HexOne:=ord(H)-$30;
end;

function Hex2Byte(s:string):byte;
{-��p��� HEX -> � ����}
var
 b,i:byte;

begin
 b:=0;
 for i:=1 to Length(s) do b:=(b shl 4)+HexOne(s[i]);
 Hex2Byte:=b;
end;

function Hex2Word(s:string):word;
{-��p��� HEX -> � ᫮��}
var
 w:word;
 i:byte;

begin
 w:=0;
 for i:=1 to Length(s) do w:=(w shl 4)+HexOne(s[i]);
 Hex2Word:=w;
end;

function Hex2Long(s:string):longint;
{-��p��� HEX -> � ������� ᫮��}
var
 L:longint;
 i:byte;

begin
 L:=0;
 for i:=1 to Length(s) do L:=(L shl 4)+HexOne(s[i]);
 Hex2Long:=L;
end;

end. {-the end of unit}