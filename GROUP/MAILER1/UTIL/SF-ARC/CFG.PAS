(* Sf-Mail Binary Config Structures *)

UNIT Cfg;

INTERFACE

uses
 {$IFNDEF WINDOWS}
 Dos;
 {$ELSE}
 Dos2win,
 WinDos;
 {$ENDIF}

{$I ..\..\Cfg_Str.typ}        { ��p���p� ����p���� ���䨣� }

const
 cfgVID:string[3]=#0#0#51;
 Task:byte=0;
 binXt:string[3]='bi0';

var
 pCfgRec:^tCfgRec;      { �������� 㪠��⥫� �� ���䨣 }

IMPLEMENTATION

begin
 { ���樠����p㥬 ��p���p� ���䨣� }
 GetMem(pCfgRec,SizeOf(tCfgRec));
end.
