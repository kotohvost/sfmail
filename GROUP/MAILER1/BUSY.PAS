{$I-,O+,F+}
unit Busy;
interface

uses
  Dos,
  SFInclud,
  TpDos,
  MsgXs,
  Flags,
  tString_,
  Config,
  RelTQ,
  FileMan,
  WriteLog;

procedure KillEmptyDir(DirName:String);
function AddressBusy(A:tAddress):boolean;
procedure SetBusy(A:tAddress);
procedure ClearBusy(A:tAddress);
function CSYBusy(A:tAddress):boolean;
procedure SetCSY(A:tAddress);
procedure ClearCSY(A:tAddress);

implementation

procedure KillEmptyDir(DirName:String);
Var
  SR:SearchRec;
begin
  if AlienSemaphore(pCfgRec^.Flags_Dir+'binkbsy.sf') then exit;
  {$I+}
  FindFirst(DirName+'\*.*',AnyFile-VolumeId,SR);
  While (DosError=0) and (SR.Name[1]='.') do
    FindNext(SR);
  {$I-}
  If (DosError=18) then
    rmDir(DirName);
end;

function AddressBusy(A:tAddress):boolean;
Var
  pPath : pathStr;
begin
  AddressBusy:=true;
  {Bink Out}
  if length(pCfgRec^.BinkOutbound)<>0 then begin
    Path4addr(true,A,pPath);
    if ExistFile(pPath+'.bsy') then begin
      LogWrite(wmAddrOccuped,Addr2str(A,A.point<>0),ld_All);
      exit;
    end;
  end;
  {Packets}
  Path4addr(false,A,pPath);
  if pCfgRec^.SysFlags and amaScan <>0 then
    if AlienSemaphore(pPath+'.bs') then begin
      LogWrite(wmAddrOccuped,Addr2str(A,A.point<>0),ld_All);
      exit;
    end;
  AddressBusy:=false;
end;

function CSYBusy(A:tAddress):boolean;
Var
  pPath : pathStr;
begin
  CSYBusy:=true;
  {Bink Out}
  if length(pCfgRec^.BinkOutbound)<>0 then begin
    Path4addr(true,A,pPath);
    if AlienSemaphore(pPath+'.cs') then begin
      LogWrite(wmAddrOccuped,Addr2str(A,A.point<>0),ld_All);
      exit;
    end;
  end;
  {Packets}
  Path4addr(false,A,pPath);
  if pCfgRec^.SysFlags and amaScan <>0 then
    if AlienSemaphore(pPath+'.cs') then begin
      LogWrite(wmAddrOccuped,Addr2str(A,A.point<>0),ld_All);
      exit;
    end;
  CSYBusy:=false;
end;

procedure SetBusy(A:tAddress);
Var
  pPath : pathStr;
begin
  if length(pCfgRec^.BinkOutbound)<>0 then begin
    Path4addr(true,A,pPath);
    MkAllDir(JustPathName(pPath));
    CreateFlag(pPath+'.bsy');
  end;
  {Packets}
  if pCfgRec^.SysFlags and amaScan <>0 then begin
    Path4addr(false,A,pPath);
    MkAllDir(JustPathName(pPath));
    CreateSemaphore(pPath+'.bs')
  end;
end;

procedure SetCSY(A:tAddress);
Var
  pPath : pathStr;
begin
  if length(pCfgRec^.BinkOutbound)<>0 then begin
    Path4addr(true,A,pPath);
    MkAllDir(JustPathName(pPath));
    CreateSemaphore(pPath+'.cs')
  end;
  {Packets}
  if pCfgRec^.SysFlags and amaScan <>0 then begin
    Path4addr(false,A,pPath);
    MkAllDir(JustPathName(pPath));
    CreateSemaphore(pPath+'.cs')
  end;
end;

procedure ClearCSY(A:tAddress);
Var
  pPath : pathStr;
  SR    : SearchRec;

begin
  if length(pCfgRec^.BinkOutbound)<>0 then begin
    Path4addr(true,A,pPath);
    EraseSemaphore(pPath+'.cs');
  end;
  {Packets}
  if pCfgRec^.SysFlags and amaScan <>0 then begin
    Path4addr(false,A,pPath);
    EraseSemaphore(pPath+'.cs');
  end;
end;

procedure ClearLo(SomeLo:String);
Var
  OldLo : text;
  NewLo : text;
  TmpS  : String;
  EmptyLo : boolean;
  SomeLo1 : String;

Label
  CriticalExit;

begin
  If IOResult<>0 then {clear};
  Assign(OldLo,SomeLo);
  SomeLo1:=SomeLo;
  SomeLo1[length(SomeLo1)-2]:='t';
  Assign(NewLo,SomeLo1);
  EmptyLo:=true;
  Reset(OldLo);
  if IOresult<>0 then begin
   Goto CriticalExit;
  end;
  Rewrite(NewLo);
  if IOresult<>0 then begin
   Goto CriticalExit;
  end;

  repeat
    readln(OldLo,TmpS);
    If IOResult<>0 then begin
     Close(NewLo);
     If IOResult<>0 then {clear};
     Erase(NewLo);
     Goto CriticalExit;
    end;
    if Length(Trim(TmpS)) <>0 then begin
      WriteLn(NewLo,TmpS);
      EmptyLo:=false;
    end;
  until EOF(OldLo);

  Close(OldLo);
  If IOResult<>0 then {clear};
  Close(NewLo);
  If IOResult<>0 then {clear};

  If EmptyLo then begin
    Erase(OldLo);
    If IOResult<>0 then {clear};
    Erase(NewLo);
    If IOResult<>0 then {clear};
    exit;
  end;

  Erase(OldLo);
  If IOResult<>0 then {clear};
  Rename(NewLo,SomeLo);
  If IOResult<>0 then {clear};
  exit;

CriticalExit:
  Close(OldLo);
  If IOResult<>0 then {clear};
  Close(NewLo);
  If IOResult<>0 then {clear};
end;

procedure ClearBusy(A:tAddress);
Var
  pPath : pathStr;
  SR    : SearchRec;

begin
  if length(pCfgRec^.BinkOutbound)<>0 then begin
    Path4addr(true,A,pPath);
    {$I+} FindFirst(pPath+'.?lo',Archive,SR); {$I-}
    while DosError =0 do begin
      ClearLo(pPath+'.'+JustExtension(SR.Name));
      {$I+} FindNext(SR); {$I-}
    end;
    DeleteFlag(pPath+'.bsy');
    if (A.Point <>0) or (A.Zone <>MainAddress.Zone) then
      KillEmptyDir(JustPathName(pPath));
    if IOResult = 0 then {clear};
    if (A.Point <>0) and (A.Zone <>MainAddress.Zone) then
      KillEmptyDir(JustPathName(JustPathName(pPath)));
    if IOResult = 0 then {clear};
  end;

  {Packets}
  if pCfgRec^.SysFlags and amaScan <>0 then begin
    Path4addr(false,A,pPath);
    EraseSemaphore(pPath+'.bs');
    KillEmptyDir(JustPathName(pPath));
    if IOResult = 0 then {clear};
    if A.Point<>0 then
      KillEmptyDir(JustPathName(JustPathName(pPath)));
    if IOResult = 0 then {clear};
  end;
end;

end.