
                (*****************************************
                 *        Anton`s Resource Engine        *
                 *   (C) UNIVERSAL SOFTWARE Inc, 1996    *
                 *****************************************)

unit aRE;

INTERFACE

uses
 Dos;

type
 tRscSign=array[1..10] of char;
 tRscName=string[35];

 { resource file hdr }
 tRscFhdr=record
  RscSign:tRscSign;      {rsc ver identifier}
  TotalRsc:word;         {number of rsc in index}
 end;

 { resource index (follows imm after header) }
 tRscIdx=record
  RscType:integer;       {rsc type identifier}
  RscName:tRscName;      {name}
  RscOfs:longint;        {offset in file}
 end;

 { header for each rsc data }
 pRscHdr=^tRscHdr;
 tRscHdr=record
  SizeY,
  SizeX:integer;    { dimensions of img }
  DatSize:word;     { actual size of rsc data }
 end;

const
 DefRscSign:tRscSign='aRE 0.01a'#26;
 { abstract rsc type }
 rtAbstract=0;

type
 { abstract resource }
 pAbsRsc=^tAbsRsc;
 tAbsRsc=object
  RscType:integer;
  RscOk:boolean;
  constructor Init(rType:integer);
  constructor Load(rType:integer; rName:tRscName);
  destructor Done; virtual;
 end;

var
 RscFname:PathStr;
 fRsc:file;
 RscFhdr:tRscFhdr;

function InitRscFile(fName:PathStr):boolean;
procedure DoneRscFile;

IMPLEMENTATION

uses
 tString_;

(******************** general purpose *********************)

function InitRscFile(fName:PathStr):boolean;
begin
 InitRscFile:=false;
 RscFname:=fName;
 assign(fRsc,RscFname);
 reset(fRsc,1);
 BlockRead(fRsc,RscFhdr,SizeOf(tRscFhdr));
 InitRscFile:=(IoResult =0) and (RscFhdr.RscSign =DefRscSign);
end;

procedure DoneRscFile;
begin
 close(fRsc);
 if IoResult <>0 then {do nothing};
end;

function SeekRscFile(rType:word; rName:tRscName):boolean;
var
 w:word;
 RscIdx:tRscIdx;

begin
 rName:=StUpCase(rName);
 seek(fRsc,SizeOf(tRscFhdr));
 for w:=1 to RscFhdr.TotalRsc do begin
  BlockRead(fRsc,RscIdx,SizeOf(tRscIdx));
  if (RscIdx.RscType =rType) and (RscIdx.RscName =rName) then begin
   SeekRscFile:=true;
   seek(fRsc,longint(SizeOf(tRscFhdr))+
        longint(RscFhdr.TotalRsc*SizeOf(tRscIdx))+RscIdx.RscOfs);
   exit;
  end;
 end;
 SeekRscFile:=false;
end;

(******************* abstract resource ********************)

constructor tAbsRsc.Init(rType:integer);
begin
 RscType:=rType;
 RscOk:=true;
end;

constructor tAbsRsc.Load(rType:integer; rName:tRscName);
begin
 Init(rType);
 RscOk:=SeekRscFile(rType,rName);
end;

destructor tAbsRsc.Done;
begin
end;

end.
