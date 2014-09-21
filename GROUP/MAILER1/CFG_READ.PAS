(* Sf-Mail Binary Config Reader *)

{$X+,I-,O+,F+}

UNIT Cfg_Read;

INTERFACE

uses
 Dos,
 SfM_Cfg,
 Config;

function Read_Config(AscFname:PathStr):boolean;

IMPLEMENTATION

uses
 EmStruct,
 MBman,
 FBman,
 Sf_Track,
 Tstring_,
 RelTQ,
 MsgXs;

function Read_Config(AscFname:PathStr):boolean;
var
 f:file;
 w:word;
 sr:SearchRec;
 CfgHeader:tCfgHeader;
 s:PathStr;

begin
 {-расширения бинарных файлов должны соответствовать номеру линии}
 with pCfgRec^ do begin
  if Task <>0 then begin
   binXt[3]:=_32_table[Task];
   savXt[3]:=_32_table[Task];
   HistoryFname[Inbound,10]:=_32_table[Task];
   HistoryFname[Outgoing,11]:=_32_table[Task];
   sntXt[4]:=_32_table[Task];
   rvdXt[4]:=_32_table[Task];
   srqXt[4]:=_32_table[Task];
   nplXt[4]:=_32_table[Task];
  end;
 end;

 CfgFileName:=AscFname;
 s:=JustPathName(CfgFileName);
 if Length(s) =0 then begin
   s:=AddBackSlash(JustPathName(ParamStr(0)));
   CfgFileName:=s+AscFname;
 end;

 Read_Config:=false;

 {$I+} FindFirst(AscFname,Archive,sr); {$I-}

 if DosError <>0 then exit;

 assign(f,ForceExtension(AscFname,binXt));
 reset(f,1);
 if IoResult =0 then begin
   BlockRead(f,CfgHeader,SizeOf(tCfgHeader));
   if (IoResult =0) and
      (sr.Time =CfgHeader.TextCfgTime) and
      (CfgHeader.Revision =cfgVID) and
      (FileSize(f) >=(SizeOf(tCfgHeader)+SizeOf(tCfgRec))) and
      (mtOSVER and CfgHeader.UnderOs <>0) then begin
     writeln('Loading configuration from '+
             ForceExtension(AscFname,binXt)+'..');
     BlockRead(f,pCfgRec^,SizeOf(tCfgRec));
     ReadMailBoxes(f);
     ReadTrackDat(f);
     ReadRobotNames(f);
     ReadBroadCast(f);
     close(f);
     Read_Config:=true;
     Move(pCfgRec^.MyAddress[1],MainAddress,SizeOf(tAddress));
     CfgFtime:=CfgHeader.TextCfgTime;
     DefCallPeriod:=pCfgRec^.CallPeriod;
     exit;
   end
   else close(f);
 end;
        (* Hе найден бинаpный конфиг,
           Ошибка чтения заголовка,
           Hе совпадает вpемя файла,
           Hе совпадает веpсия *)

 if not CompileConfig(AscFname,ForceExtension(AscFname,binXt)) then
   halt(220);  {Cann`t compile configuration file}

 Move(pCfgRec^.MyAddress[1],MainAddress,SizeOf(tAddress));
 Read_Config:=true;
 DefCallPeriod:=pCfgRec^.CallPeriod;
end;

end.
