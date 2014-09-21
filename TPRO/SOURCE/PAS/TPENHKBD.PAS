{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$F-,O-,A-}  {No overlays}
{$ENDIF}

{!!.12} {Copied with minor modifications from Object Professional OPENHKBD}

{*********************************************************}
{*                  TPENHKBD.PAS 5.12                    *}
{*        Copyright (c) TurboPower Software 1987.        *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpEnhKbd;
  {-Enhanced keyboard routines}

interface

const
  EnableEnhanced : Boolean = True; {Set false to temporarily disable handlers}
var
  HasEnhancedKbd : Boolean;  {True when enhanced keyboard is detected}
  FiltersEnhanced : Boolean; {!!.01}{True when keyboard BIOS filters enhanced keys}

procedure RestoreKbdVectors;
  {-Restores original vectors for INT's $09 and $16}

procedure InitKbdVectors;
  {-Save and setup interrupt vectors. This routine should be called only if
    RestoreKbdVectors has been called first}

  {=========================================================================}

implementation

var
  SaveExit : Pointer;

  {$L TPENHKBD}

  procedure NewInt09; external;
  procedure NewInt16; external;
  function EnhancedKbd : Boolean; external;
  function FiltersEnhancedKeys : Boolean; external; {!!.01}

  {$F+}
  procedure InitKbdVectors; external;
  procedure RestoreKbdVectors; external;
  procedure FixOldBios; external; {!!.02}

  procedure ExitHandler;
    {-Deactive interrupt handlers}
  begin
    ExitProc := SaveExit;
    RestoreKbdVectors;
  end;
  {$F-}

begin
  {Correct invalid BufferStart and BufferEnd for old BIOS chips that
   don't initialize them}
  FixOldBios; {!!.02}

  {See if enhanced keyboard BIOS installed}
  HasEnhancedKbd := EnhancedKbd;

  {See if the keyboard BIOS will try to filter out the keys we add}
  FiltersEnhanced := FiltersEnhancedKeys; {!!.01}

  {Initialize interrupt vectors}
  InitKbdVectors;

  {Install exit handler}
  SaveExit := ExitProc;
  ExitProc := @ExitHandler;
end.
