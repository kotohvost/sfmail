{Execute xternal process in 'QUIET-mode'
(c)1994 by Anton Deinow Software Research Lab.}

{$R-,S-,I-,B-,F-,V-}

unit ExecQt;
  {-Exec a program in a QUIET-mode}

interface

uses
  Dos,
  TpDos;

function ExecQuiet(Command :string; UserRoutine:pointer) : Integer;
  {-Exec a program in a QUIET-mode.
    Command and UseSecond are defined just as for ExecDos.
    Returns error codes just like ExecDos.}

  {=======================================================================}

implementation

var
  CurInt21,          {Old Int 21h vector}
  CurInt10: Pointer; {Old Int 10h vector}

  {$L EXECqt}
  procedure SetCsInts; external;
  procedure NewInt21; external;
  procedure NewInt10; external;

  function ExecQuiet(Command :string; UserRoutine:pointer):Integer;
 {-Exec a program in a QUIET-mode}

 {$IFDEF Ver60}
  var
    TmpInt21 :Pointer;
{$ENDIF}

  begin
    {Take over interrupt}
    GetIntVec($10, CurInt10);
    GetIntVec($21, CurInt21);
    SetCsInts;
    SetIntVec($21, @NewInt21);
    SetIntVec($10, @NewInt10);

  {$IFDEF Ver60}
    {Prevent SwapVectors from undoing our int21 change}
    TmpInt21  :=SaveInt21;
    SaveInt21 :=@NewInt21;
  {$ENDIF}

    {Exec the program}
    ExecQuiet := ExecDos(Command, false, UserRoutine);

  {$IFDEF Ver60}
    SaveInt21 := TmpInt21;
  {$ENDIF}

    {Restore interrupt}
    SetIntVec($21, CurInt21);
    SetIntVec($10, CurInt10);
  end;
end.
