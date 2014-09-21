(* Sf-Mail Binary Config Reader *)

{$IFNDEF WINDOWS}
{$X+,I-,O+,F+}
{$ELSE}
{$X+,I-}
{$ENDIF}

UNIT ReadCfg;

INTERFACE

uses
 {$IFNDEF WINDOWS}
 Dos,
 tString_,
 RelTQ,
 {$ELSE}
 WinDos,
 Dos2win,
 tStringW,
 {$ENDIF}
 SfM_Api,
 Cfg;

type
 { read config status }
 tRCS=(rcsOk,rcsNoFile,rcsIoError,rcsTimeWarn,rcsVIDwarn,rcsOsWarn);

function Read_Config(AscFname:PathStr):tRCS;

IMPLEMENTATION

function Read_Config(AscFname:PathStr):tRCS;
var
 f:file;
 w:word;
 sr:SearchRec;
 CfgHeader:tCfgHeader;

begin
 Read_Config:=rcsNoFile;
 binXt[3]:=_32_table[Task];
 {$I+}
 {$IFDEF WINDOWS}
 AscFname:=AscFname+#0;
 FindFirst(@AscFname[1],Archive,sr);
 {$ELSE}
 FindFirst(AscFname,Archive,sr);
 {$ENDIF}
 {$I-}

 if DosError <>0 then exit;
 
 Read_Config:=rcsIoError;

 assign(f,ForceExtension(AscFname,binXt));
 reset(f,1);
 if IoResult =0 then begin
   BlockRead(f,CfgHeader,SizeOf(tCfgHeader));
   if IoResult =0 then begin
    if sr.Time <>CfgHeader.TextCfgTime then
     Read_Config:=rcsTimeWarn
    else
     if CfgHeader.Revision <>cfgVID then
      Read_Config:=rcsVIDwarn
     else
      if (mtOSVER and CfgHeader.UnderOs) =0 then
       Read_Config:=rcsOsWarn
      else begin
       {$IFNDEF WINDOWS}
       writeln('Loading configuration from '+
               ForceExtension(AscFname,binXt)+'..');
       {$ENDIF}
       BlockRead(f,pCfgRec^,SizeOf(tCfgRec));
       Read_Config:=rcsOk;
      end;
   end;
   close(f);
   if IoResult <>0 then;
 end;
end;

end.
