{$I SfDefine.inc}

{$F+,O+,I-}
Unit FileMan;

Interface

Uses
     Dos;

Const TotalSave : LongInt = 0;
Var
   TempIORes   : Integer;
   RenNextName : pathStr;

(*** PATHS CONTROL ***)

procedure MkAllDir(s:PathStr);
{-создает все вложенные каталоги по пути s}

function ExistDir(s:PathStr):boolean;
{-пpовеpяет, существует ли каталог S}

(*** Files CONTROL ***)

function OpenFile(var CurFile : file; Name : PathStr; ofReadOnly : boolean):boolean;
function MakeFile(var CurFile : file; Name : PathStr):boolean;
function CloseFile (var CurFile : file): boolean;
function SeekFile(var CurFile : file; Position : LongInt):boolean;
function ReadFile(var CurFile : file; var Buffer; BytesToRead : word; Var RealRead : word) : boolean;
function WriteFile(var CurFile : file; var Buffer; BytesToWrite : word) : boolean;
function FindFile(Name : PathStr; Var Size, Time: LongInt): Boolean;
function RenameFile(PathName, OldName, NewName: PathStr): Boolean;
function CRC32File(var CurFile : file): LongInt;
procedure CommitFile(ComHandle : word);
procedure RenNextFile(FilePath,Name:String);

procedure SetFileTime(var CurFile : file; Time : LongInt);
procedure ClearFileAttr(var CurFile : file);
function TruncPathName(FullPathName:string; Count:byte):string;
procedure CheckPkt(Path: String; RecFile : string);
function VirtualDiskFree(Dr:byte):longInt;
function CvtLongName(TName:String):String;

Implementation
Uses Config,
     tString_,
     SFInclud,
     {$IFNDEF NoComm}
     Fos_Lib,
     {$ENDIF}
     Crc_All;

function IsDevice( FHandl :word):boolean;assembler;
asm
  push BP
  mov ax,4400h
  mov bx,FHandl
  int 21h
  mov ax,1
  jc  @@Device
  test  dx,80h  {если в регистре dx седьмой бит установлен то это девайс}
  jnz @@Device
  mov ax,0
@@Device:
  pop BP
end;

function CanOpen(FileName:String):boolean;
Var
  S : String;
begin
  CanOpen:=false;
  S:=stLoCase(JustFileName(FileName));
  if pos('.',S)<>0 then
    Delete(S,pos('.',S),255);
  if S='' then exit;
  if S='com1' then exit;
  if S='com2' then exit;
  if S='com3' then exit;
  if S='com4' then exit;
  CanOpen:=true;
end;

function OpenFile(var CurFile : file; Name : PathStr; ofReadOnly : boolean):boolean;
Var
  oldFileMode : byte;
begin
  OpenFile:=true;
  oldFileMode:=filemode;
  if ofReadOnly then
    filemode:=$20
  else begin
    TotalSave:=0;
    filemode:=$22;
  end;
  TempIORes :=IOResult;
  if not CanOpen(Name) then begin
    OpenFile:=false;
    exit;
  end;
  Assign(CurFile,Name);
  Reset(CurFile,1);
  filemode:=OldFileMode;
  if (IOResult=0) and (not IsDevice(FileRec(CurFile).Handle)) then exit;
  CloseFile(CurFile);
  OpenFile  :=false;
end;

function MakeFile(var CurFile : file; Name : PathStr):boolean;
Var
  oldFileMode : byte;
begin
  MakeFile:=true;
  oldFileMode:=filemode;
  filemode:=$22;
  TempIORes :=IOResult;
  TotalSave:=0;
  if not CanOpen(Name) then begin
    MakeFile:=false;
    exit;
  end;
  Assign(CurFile,Name);
  Rewrite(CurFile,1);
  Close(CurFile);
  SetFAttr(CurFile,Hidden);
  if IOResult<>0 then;
  Reset(CurFile,1);
  filemode:=OldFileMode;
  if (IOResult=0) and (not IsDevice(FileRec(CurFile).Handle)) then exit;
  CloseFile(CurFile);
  MakeFile:=false;
end;

function CloseFile(var CurFile : file): boolean;
begin
  TempIORes :=IOResult;
  Close(CurFile);
  CloseFile  := (IOresult = 0);
end;

function SeekFile(var CurFile : file; Position : LongInt):boolean;
begin
  TempIORes :=IOResult;
  Seek(CurFile,Position);
  SeekFile  := (IOresult = 0);
end;

function ReadFile(var CurFile : file; var Buffer; BytesToRead : word; Var RealRead : word) : boolean;
begin
  {$IFNDEF NoComm}
  If (pCfgRec^.SysFlags and mscHoldRX) <>0 then ReceiveCtrl(0);
  {$ENDIF}
  TempIORes :=IOResult;
  BlockRead(CurFile, Buffer, BytesToRead, RealRead);
  ReadFile  := (IOresult = 0);
  {$IFNDEF NoComm}
  If (pCfgRec^.SysFlags and mscHoldRX) <>0 then ReceiveCtrl(1);
  {$ENDIF}
end;

function WriteFile(var CurFile : file; var Buffer; BytesToWrite : word) : boolean;
begin
  {$IFNDEF NoComm}
  If (pCfgRec^.SysFlags and mscHoldRX) <>0 then ReceiveCtrl(0);
  {$ENDIF}
  TempIORes :=IOResult;
  BlockWrite(CurFile, Buffer, BytesToWrite);
  WriteFile  := (IOresult = 0);
  {$IFNDEF NoComm}
  If (pCfgRec^.SysFlags and mscHoldRX) <>0 then ReceiveCtrl(1);
  {$ENDIF}
end;

function FindFile(Name : PathStr; Var Size, Time: LongInt): Boolean;
  Var
    Sr   : SearchRec;
begin
  TempIORes :=IOResult;
  FindFirst(Name,Archive+Hidden,Sr);
  If (DosError <> 0) then
    FindFile:=false
  else begin
    FindFile:=true;
    Size := Sr.Size;
    Time := Sr.Time;
  end;
  TempIORes :=IOResult;
end;

procedure SetFileTime(var CurFile : file; Time : LongInt);
begin
  SetFTime(CurFile,Time);
  CommitFile(FileRec(CurFile).Handle);
  SetFTime(CurFile,Time);
{  CommitFile(FileRec(CurFile).Handle);}
  TempIORes :=IOResult;
end;

procedure ClearFileAttr(var CurFile : file);
begin
  SetFAttr(CurFile, Archive);
end;

function RenameFile(PathName, OldName, NewName: PathStr): Boolean;
Var
   CurDir  : String;
   F       : file;
begin
  TempIORes:=IOresult;
  If PathName[length(PathName)]='\' then
     Dec(byte(PathName[0]));
  GetDir(0, CurDir);
  ChDir(PathName);
  Assign(f,OldName);
  Rename(f,NewName);
  RenameFile:=(IOResult=0);
  ChDir(CurDir);
end;

procedure RenNextFile(FilePath,Name:String);
Var
  ReplN : String;
  FSize,
  FTime : LongInt;
begin
  ReplN := Name;
  ReplN[Byte(ReplN[0])] := '/';
  Repeat
    Inc(Byte(ReplN[Byte(ReplN[0])]));
    If ReplN[Byte(ReplN[0])] = ':' then
      ReplN[Byte(ReplN[0])]:='A';
  Until (Not (FindFile(FilePath + ReplN,FSize,FTime))) or
        (ReplN[Byte(ReplN[0])] > 'Y');
  RenameFile(FilePath, Name, ReplN);
  RenNextName :=FilePath+ReplN;
end;

function CRC32File(var CurFile : file): LongInt;
Var
    SomeBuff : array [1..2048] of byte;
    CRC32    : LongInt;
    N,
    Bread    : Word;
Begin
  TempIORes:=IOresult;
  CRC32 := $FFFFFFFF;
  SeekFile(CurFile,0);

  {$IFNDEF NoComm}
  If (pCfgRec^.SysFlags and mscHoldRX) <>0 then ReceiveCtrl(0);
  {$ENDIF}
  Repeat
    ReadFile(CurFile, SomeBuff, 2048, Bread);
    For N := 1 To Bread Do
        CRC32 := UpdC32(SomeBuff[n], CRC32)
  Until (Bread < 2048);
  {$IFNDEF NoComm}
  If (pCfgRec^.SysFlags and mscHoldRX) <>0 then ReceiveCtrl(1);
  {$ENDIF}

  SeekFile(CurFile, 0);
  CRC32File := not CRC32;
  TempIORes:=IOresult;
End;

procedure CommitFile(ComHandle : word);assembler;
asm
  push BP
  mov ah,0Dh
  int 21h
  mov ah,68h
  mov bx,ComHandle
  int 21h
  pop BP
end;

function TruncPathName(FullPathName:string; Count:byte):string;
Var
  lPth  : byte;
  from  : byte;
begin
  TruncPathName:=FullPathName;
  lPth:=length(FullPathName);
  if lPth<=Count then exit;
  if FullPathName[2] =':' then begin
    if FullPathName[3] ='\' then
      from:=4
    else
      from:=3;
  end else begin
    if FullPathName[1] ='\' then
      from:=2
    else
      from:=1;
  end;
  Delete(FullPathName,from,lPth-Count+3);
  Insert('...',FullPathName,from);
  TruncPathName:=FullPathName;
end;

procedure CheckPkt(Path: String; RecFile : string);
Var
  f : file;
begin
{$I-}
  RecFile:=StUpCase(RecFile);
  If (Pos('.PKT',RecFile) <> 0) or
     (Pos('.REQ',RecFile) <> 0) then begin
     Assign(f,Path+RecFile);
     Erase(f);
  end;
{$I+}
end;

function ExistDir(s:PathStr):boolean;
{-пpовеpяет, существует ли каталог S}
var
 dr:SearchRec;

begin
 {$I+}
 FindFirst(s,Directory,dr);
 {$I-}

 if DosError <>0 then ExistDir:=false
 else ExistDir:=true;
end;

procedure MkAllDir(s:PathStr);
{-создает все вложенные каталоги}
var
 o:integer;
 i,z:byte;
 s1:PathStr;

begin
 s1:=ExtractWord(1,s,['\']);

 z:=1;

 if s1 ='.' then begin
   z:=2;
   s1:='';
 end
 else begin
   z:=2;
   s:=FullPathName(s);
   s1:=ExtractWord(1,s,['\']);
 end;

 for i:=z to WordCount(s,['\']) do begin
   if s1[0] <>#0 then s1:=s1+'\';
   s1:=s1+ExtractWord(i,s,['\']);

   { пpовеpяем, есть ли этот каталог,
     и если нет -- создаем}

   if not ExistDir(s1) then {begin
     WriteLn('Creating Dir: '+S1);}
     MkDir(s1);
{   end;}
 end;

 o:=IoResult;
end;

function VirtualDiskFree(Dr:byte):longInt;
begin
  If IgnoreFreeSpace then
    VirtualDiskFree:=$7FFFFFFF
  else
    VirtualDiskFree:=DiskFree(Dr);
end;

function CvtLongName(TName:String):String;
Var
  TmpStr,
  Tmp1Str  : String;
begin
  While (Pos(':', TName) > 0) Do Delete(TName, 1, Pos(':', TName));
  While (Pos('\', TName) > 0) Do Delete(TName, 1, Pos('\', TName));

  Tmp1Str:=TName; { Original Name }
  If Pos('.',TName) <> 0 then begin
    TmpStr:= Copy(TName,1,Pos('.',TName)-1);
    Delete(TName, 1, Pos('.', TName));
    If Pos('.',TName) <> 0 then
      TName := Copy(TName,1,Pos('.',TName)-1);
  end else begin
    TmpStr:=TName;
    TName:='';
  end;

  If (byte(TmpStr[0])>8) or (byte(TName[0])>3) then
  TmpStr:=Copy(TmpStr,1,5)+'~'+HexByte(byte(CRCBlock(0,@Tmp1Str[1],length(Tmp1Str))));
  If byte(TName[0])>3 then TName[0] := #3;
  If length(TName)<>0 then
    TName:=TmpStr+'.'+TName else
    TName:=TmpStr;

  CvtLongName := StUpCase(TName);
  
end;

end.