unit Swaper;

Interface
        const

    {Swap constants}
    XMS = $01;
    EMS = $02;
    EXT = $04;
    HDD = $08;

    {OS2 constants}
    SES_AUTO          = 0;
    SES_OS2FULL       = 1;
    SES_OS2WIN        = 2;
    SES_PM            = 3;
    SES_VDMFULL       = 4;
    SES_VDMWIN        = 7; {возможно в доке опечатка и должно быть 5 ??}
  Var
     SwapEnvID:byte;

function  aSwap(ProgName:string; CmdLine: string):Integer;

implementation
uses  SfInclud,
      Config,
      Dos,
      Strings;

function  aSwap(ProgName:string; CmdLine: string):Integer;
begin
   aswap:=pSwap(SwapEnvID,ProgName,CmdLine,pCfgRec^.SwapDir);
end;

end.
