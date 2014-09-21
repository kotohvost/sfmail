{$A+,G+,B-,D-,E-,F+,I-,L-,N-,O+,P+,Q-,T-,R-,S+,V+,Y-}
{$M 32768,170000,655360}
{$L Uniswap.obj}
Program SFmail;

uses Ovr_Init,
     SFInclud,
     SF_Init;

{$O ADE}
{$O ADir}
{$O AQM}
{$O Answ}
{$O Busy}
{$O CFG_Read}
{$O Call}
{$O ChgMaddr}
{$O CryptLib}
{$O Debug}
{$O EMSI}
{$O ERP}
{$O EdLn}
{$O EmStruct}
{$O Em_Cpl}
{$O Error}
{$O Face}
{$O FbMan}
{$O FileMan}
{$O Flags}
{$O FreQMan}
{$O HM}
{$O HShow}
{$O Help}
{$O HisView}
{$O Hydra}
{$O KeyRead}
{$O MbMan}
{$O Nes}
{$O ProcMan}
{$O Pwd_Xs}
{$O Script}
{$O SFM_CFG}
{$O SFM_DLG}
{$O SF_dbg}
{$O SessCtl}
{$O Session}
{$O SF_Bink}
{$O SF_Fax}
{$O Sf_Lc}
{$O Sf_Shell}
{$O Sf_Track}
{$O SF_Pick}
{$O Sm_Cpl}
{$O StatView}
{$O TPWindow}
{$O Terminal}
{$O UnPkt}
{$O UnixTime}
{$O WriteLog}
{$O Show}
{$O ZModem}

{$IFDEF bVirtual}
{$O OvlMgTm}
{$O OvlMgEm}
{$O OvlMgXm}
{$ENDIF}

function Swap(a:byte;b,c,d :string):integer;far;external;

begin
 pSwap:=Swap;
 Run;
end.
