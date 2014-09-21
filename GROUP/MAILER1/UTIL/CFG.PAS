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

{$I ..\Cfg_Str.typ}        { стpуктуpа бинаpного конфига }

const
 cfgVID:string[3]=#0#0#51;
 Task:byte=0;
 binXt:string[3]='bi0';

var
 pCfgRec:^tCfgRec;      { глобальный указатель на конфиг }

IMPLEMENTATION

begin
 { инициализиpуем стpуктуpу конфига }
 GetMem(pCfgRec,SizeOf(tCfgRec));
end.
