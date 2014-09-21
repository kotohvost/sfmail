unit viewer;

interface

function OpenFileView(name:String):boolean;
function CloseFileView(name:String):boolean;

implementation

uses FileMan;

Type
  tDataBuff  = record
    DataOffs : LongInt;
    Data     : array [0..4192] of byte;
  end;
  
Var
  ViewFile  : file;
  CurPos    : LongInt;


Const
  pData     : ^tDataBuff = nil;

function OpenFileView(name:String):boolean;
begin
  OpenFileView:=false;
  if not OpenFile(ViewFile,name,true) then exit;
  If pData=nil then GetMem(pData,SizeOf(tDataBuff));
  ReadFile
  OpenFileView:=true;
end;

function CloseFileView(name:String):boolean;
begin
  OpenFileView:=false;
  if not OpenFile(ViewFile,name,true) then exit;
  If pData=nil then GetMem(pData,SizeOf(tDataBuff));
  OpenFileView:=true;
end;

end.