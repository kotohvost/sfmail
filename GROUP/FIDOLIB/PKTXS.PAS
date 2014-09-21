Unit PktXs;

interface

{$I PktXs.inc}

Var
  PktHeader : tPktHeader;
  PktSize   : LongInt;

function UnPackPkt(PktName:String;NetMail:String):byte;
{Распаковка Пакета}

implementation

function UnPackPkt(PktName:String;NetMail:String):byte;
{Распаковка Пакета}
Var
  f : file;
begin
  If IOResult<>0 then {clear};
  Assign(f,PktName);
  FileMode:=$20;
  Reset(f,1);
  FileMode:=$2;
  If IOResult<>0 then begin
   UnPackPkt:=peOpen;
   exit;
  end;
  PktSize:=FileSize(f);
  BlockRead(f,PktHeader,SizeOf(tPktHeader));
  if IoResult <>0 then begin
   UnPackPkt:=peRead;
   exit;
  end;

  
end;

end.