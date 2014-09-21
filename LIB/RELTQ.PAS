Unit RelTQ;
{$F+}
interface

const

  mtOS_2       =  $0001;
  mtDesQ       =  $0002;
  mtPSMOS      =  $0004;
  mtGeneric    =  $0008;
  mtWinNT      =  $0010;
  mtWin95      =  $0020;
  mtWindows    =  $0040;
  mtMS_DOs_4   =  $0080;
  mtMS_Dos_5   =  $0100;
  mtDoubleDos  =  $0200;
  mtRTS_386    =  $0400;
  mtHLT        =  $0800;
  mtIPX        =  $1000;
  mtUndefined  =  $2000;
  mtLinux      =  $4000;

mtNames1 = 'OS/2 version';
mtNames2 = 'DesQView version';
mtNames3 = 'PC-MOS/386 version';
mtNames4 = 'Generic time slice service detected';
mtNames5 = 'MS Windows''95 version';
mtNames6 = 'MS Windows version';
mtNames7 = 'DoubleDos version';
mtNames8 = 'RTS - 386 version';
mtNames9 = 'MS(PC)-Dos version';
mtNames10= 'IPX Relinquish';
mtNames11= 'MS(PC)-DOS (using Int28)';
mtNames12= 'Linux DOSemu version';
mtNames13= 'Windows NT';

type

 CPUXID=record
   bLength:byte;
   bXID:byte;
   bModel:byte;
   bStep:byte;
   aVendor:String[12];
 end;

Var
 mtOSVER    : Integer;
 mtVer      : word;
 sCPUXID    : CPUXID;

 function GetCPUxID(var CPUXID):integer;
 function GetOS:LongInt;
 function ChangeTQ(TQ:integer):boolean;
 function ReleaseTQ:boolean;
 function ChangeOSword(Force:word):boolean;
 function GetVirtualScreen(pScreen:pointer):pointer;
 function MSound(Frequancy:word; Duration:word):boolean;
 function DoDelay(Period:word):boolean;
 procedure EndNTService;
 function NameMultiTasker:string;

implementation
uses
   Dos,
   TPCRT;

Var
   ver : word;

{$L TIMSLC_P.OBJ}
{$L GETCPUID.OBJ}

 function GetCPUxID(var CPUXID):integer;external;
 function GetOS:LongInt; external;
 function ChangeTQ(TQ:integer):boolean; external;
 function ReleaseTQ:boolean; external;
 function GetVirtualScreen(pScreen:pointer):pointer; external;
 function ChangeOSword(Force:word):boolean; external;
 function MSound(Frequancy:word; Duration:word):boolean; external;
 function DoDelay(Period:word):boolean; external;
 procedure EndNTService; external;

function NameMultiTasker:string;
   var
     VerStr : string;
begin
 case mtOSVER of
  mtOS_2        : begin
                   if mtVer =$141E then begin
                     NameMultiTasker:=mtNames1+' 3.00 (Warp)';
                   end else begin
                     if mtVer =$1428 then
                       NameMultiTasker:=mtNames1+' 4.00 (Merlin)'
                     else begin
                       Str(Hi(mtVER)/10+Lo(mtVER)/100:4:2,VerStr);
                       NameMultiTasker:=mtNames1+' '+VerStr;
                     end;
                   end;
  end;
  mtDesQ        : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames2+' '+VerStr;
  end;
  mtPSMOS       : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames3+' '+VerStr;
  end;
  mtGeneric     : NameMultiTasker:=mtNames4;
  mtWin95       : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames5+' '+VerStr;
                  end;
  mtWindows     : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames6+' '+VerStr;
                  end;
  mtDoubleDos   : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames7+' '+VerStr;
  end;
  mtRTS_386     : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames8+' '+VerStr;
  end;
  mtIPX         : NameMultiTasker:=mtNames10;
  mtUndefined   : NameMultiTasker:=mtNames11;
  mtMS_Dos_5,
  mtMS_DOs_4    : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames9+' '+VerStr;
  end;
  mtLinux       : begin
                   Str(Hi(mtVER)+Lo(mtVER)/100:4:2,VerStr);
                   NameMultiTasker:=mtNames12+' '+VerStr;
  end;
  mtWinNT       : begin
                   if mtVer =$FFFF then
                     NameMultiTasker:=mtNames13+' & SF-NTsrv'
                   else
                     NameMultiTasker:=mtNames13+' Generic';
  end;
 end;
end;

type
 verylong = array[1..2] of integer;

var
 tmp  : longInt;
 temp : verylong absolute tmp;

begin
  GetCPUxID(sCPUXID);
  tmp := GetOS;
  mtOSVER := temp[1];
  mtVER   := temp[2];

  if mtOSVER = mtDesQ then begin
     DetectMultiTasking := True;
     GetCrtMode;
  end else begin
     DetectMultiTasking := False;
     GetCrtMode;
     MultiTaskingOn := False;
  end;
end.