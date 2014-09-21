{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$I OMINUS.INC}
{$ENDIF}

{*********************************************************}
{*                   TPINT24.PAS 5.12                    *}
{*        Copyright (c) TurboPower Software 1987.        *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpInt24;
  {-DOS critical error handler}

interface

function Int24Result : Word;
  {-Returns DOS critical error code in high byte, IoResult in low byte.}

procedure Int24On;
  {-Install DOS critical error handler.}

procedure Int24Off(RestoreDosHandler : Boolean);
  {-Restore DOS's critical error handler or Turbo's.}

  {==============================================================================}

implementation

var
  SaveExitProc : Pointer;

  function IoResultPrimitive : Word;
    {-Calls IoResult for Int24Result}
  begin
    IoResultPrimitive := IoResult;
  end;

  {$L TPINT24.OBJ}

  function Int24Result : Word; external;
  procedure Int24On; external;
  procedure Int24Off(RestoreDosHandler : Boolean); external;
  procedure Int24Init; external;
  {-Save Turbo's vector}

  {$F+}
  procedure Int24ExitProc;
    {-Disable critical error handler on exit.}
  begin
    ExitProc := SaveExitProc;
    Int24Off(False);
  end;
  {$F-}

begin
  {activate critical error handler}
  Int24Init;
  Int24On;

  {set up exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @Int24ExitProc;
end.
