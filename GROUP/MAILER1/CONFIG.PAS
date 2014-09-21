(* Sf-Mail Binary Config Structures *)

UNIT Config;

INTERFACE

uses
 Dos;

{$I Cfg_Str.typ}        { стpуктуpа бинаpного конфига }

const
 cfgVID:string[3]=#0#0#51;
 Task:byte=0;             { line number }

var
 pCfgRec:^tCfgRec;      { глобальный указатель на конфиг }
 CfgFileName:PathStr;
 CurDOW:byte;
 CfgFtime:longint;
 DefCallPeriod:word;

IMPLEMENTATION

begin
 { инициализиpуем стpуктуpу конфига }
 GetMem(pCfgRec,SizeOf(tCfgRec));
end.
