(* Sf-Mail Binary Config Structures *)

UNIT Config;

INTERFACE

uses
 Dos;

{$I Cfg_Str.typ}        { ��p���p� ����p���� ���䨣� }

const
 cfgVID:string[3]=#0#0#51;
 Task:byte=0;             { line number }

var
 pCfgRec:^tCfgRec;      { �������� 㪠��⥫� �� ���䨣 }
 CfgFileName:PathStr;
 CurDOW:byte;
 CfgFtime:longint;
 DefCallPeriod:word;

IMPLEMENTATION

begin
 { ���樠����p㥬 ��p���p� ���䨣� }
 GetMem(pCfgRec,SizeOf(tCfgRec));
end.
