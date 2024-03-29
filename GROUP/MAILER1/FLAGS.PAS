{$X+,I-,F+,O+}

(*** ����� CheckFlag �ᯮ�짮����: ***)

{ function ExistFile(Fname:string):boolean;}
(*** ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ***)
(* �p��⠫? H� ����� ��������p���! ;)) *)

unit Flags;

INTERFACE

uses
 Tstring_,
 TpDos,
 Dos;

{------------------------------------------}
procedure CreateSemaphore(sn:PathStr);
{
  ᮧ���� ᥬ��p � ��⥬/������ � SN
  ��� ����H� ���������� ��� ����� �������H��,
  ������ ���������� ��������� Task � Hex-�᫮ � ����� ��p��

  �p���p:
   (�p� Task==0)

   CreateSemaphore('Y:\FLAGS\Alive.sf');

  ����砥� ᥬ��p:

   Y:\FLAGS\Alive.sf0
}

function CheckSemaphore(sn:PathStr):boolean;
{
 �p���p�� ����稥 ᥬ��p� � ������ � SN
 �p�������� � ����� -- ��� � � CreateSemaphore()
}

function AlienSemaphore(sn:PathStr):boolean;
{
 ����p�頥� TRUE, �᫨ ���� ᥬ��p ���⠢����
 �p㣮� ����祩, �� ��襩.

 �p�������� � ����� �. CreateSemaphore()
}

procedure EraseSemaphore(sn:PathStr);
{
 㤠��� ᥬ��p � ������ � SN
 �p�������� � ����� �. CreateSemaphore()
---------------------------------------}

function CreateFlag(Flag:PathStr):boolean;
function DeleteFlag(Flag:PathStr):boolean;

IMPLEMENTATION
uses
 Config;

function CreateFlag(Flag:PathStr):boolean;
var
 f:file;

begin
 assign(f,Flag);
 rewrite(f);
 close(f);
 CreateFlag:=IoResult =0;
end;

function DeleteFlag(Flag:PathStr):boolean;
var
 f:file;

begin
 assign(f,Flag);
 SetFattr(f,Archive);
 erase(f);
 DeleteFlag:=IoResult =0;
end;

procedure CreateSemaphore(sn:PathStr);
begin
 CreateFlag(sn+Copy(HexB(Task),2,1));
end;

function CheckSemaphore(sn:PathStr):boolean;
begin
 CheckSemaphore:=ExistFile(sn+Copy(HexB(Task),2,1));
end;

procedure EraseSemaphore(sn:PathStr);
begin
 DeleteFlag(sn+Copy(HexB(Task),2,1));
end;

function AlienSemaphore(sn:PathStr):boolean;
var
 c:string[1];
 sr:SearchRec;

begin
 c:=Copy(HexB(Task),2,1);
 AlienSemaphore:=true;
 {$I+}
 FindFirst(sn+'?',Archive,sr);
 while DosError =0 do
  if sr.Name[Length(sr.Name)] <>c[1] then exit
  else
    FindNext(sr);
 {$I-}
 AlienSemaphore:=false;
end;

end.
