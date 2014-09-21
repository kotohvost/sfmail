{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$I OMINUS.INC}
{$ENDIF}

{*********************************************************}
{*                  TPERRHAN.PAS 5.12                    *}
{*        Copyright (c) TurboPower Software 1987.        *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpErrHan;
  {-Allow recovery from Turbo runtime errors}

interface

uses
  Dos;

var
  CanRecover : Boolean;      {True when the error handler is successfully installed}

procedure ErrorRecovery(On : Boolean; UserRoutine : Pointer);
  {-Turn error recovery on and off, and attach to a user error routine}

  {==========================================================================}

implementation

type
  BytePtr = ^Byte;
  CharPtr = ^Char;
  PatchArray = array[1..5] of Byte;
var
  Int0 : Pointer;   {!!.06}
  UserHandler : Pointer;
  SystemHandler : Pointer;
  SystemContinue : Pointer;
  SaveErrorEntry : PatchArray;
  NewErrorEntry : PatchArray;
  ErrorCode : Word absolute ExitCode; {!!.12}

  {$L TPERRHAN}
  procedure ErrHanInt0;
    {-Interrupt 0 handler}
  external;
  procedure Handler;
    {-Handle recovery from errors}
  external;
  procedure Trap8087errors;
    {-Install INT 2 and INT 75 handlers}
  external;

  procedure ErrorRecovery(On : Boolean; UserRoutine : Pointer);
    {-Patch into or out of system error handler to allow error recovery}
  begin
    if not CanRecover then
      Exit;

    if On then begin
      {Patch the system error handler}
      Move(NewErrorEntry, SystemHandler^, 5);

      {Assure current error value is zeroed out}
      ExitCode := 0;

      {Store the address of the UserHandler}
      UserHandler := UserRoutine;

      {Take over interrupt 0 so we can balance the stack}
      SetIntVec(0, @ErrHanInt0);          {!!.06}
    end
    else begin
      {Unpatch the system error handler}
      Move(SaveErrorEntry, SystemHandler^, 5);

      {Give interrupt 0 back to SYSTEM}
      SetIntVec(0, Int0);                 {!!.06}
    end;
  end;

  function AddPtr(P : Pointer; Num : Word) : Pointer;
    {-Add Num to a pointer - no normalization}
  begin
    AddPtr := Ptr(Seg(P^), Ofs(P^)+Num);
  end;

  function Search(Start : Pointer; MaxLen : Word; Match : string) : Pointer;
    {-Search memory starting at Start for the string Match, returning nil if not found}
  var
    MemPos : Word;
    MatPos : Word;
    Matched : Boolean;
    P : Pointer;
    Q : Pointer;
  begin
    P := Start;
    for MemPos := 1 to MaxLen do begin
      if CharPtr(P)^ = Match[1] then begin
        {First byte matches, check the rest}
        Q := P;
        Matched := True;
        MatPos := 1;
        while Matched and (MatPos <= Length(Match)) do begin
          Matched := (CharPtr(Q)^ = Match[MatPos]);
          Q := AddPtr(Q, 1);
          Inc(MatPos);
        end;
        if Matched then begin
          {Matched entire length, return pointer to beginning of match}
          Search := P;
          Exit;
        end;
      end;
      P := AddPtr(P, 1);
    end;

    {Not found}
    Search := nil;
  end;

  function Initialize : Boolean;
    {-Find system error handler, returning true if found}
  var
    Int23 : Pointer;
    P : Pointer;
    E1 : Pointer;
    E2 : Pointer;
  begin
    {Assume failure}
    Initialize := False;

    {The system error handler is near the int0 and int23 handlers}
    GetIntVec(0, Int0);
    GetIntVec($23, Int23);
    if Seg(Int0^) <> Seg(Int23^) then
      {Both routines are not in the system library}
      Exit;

    {Search for the error handler two ways and make sure they agree}
    P := Search(Int0, 32, #$59#$5B#$EB);
    if P = nil then
      Exit;
    P := AddPtr(P, 3);
    E1 := AddPtr(P, BytePtr(P)^+1);

    P := Search(Int23, 32, #$33#$C9#$33#$DB);
    if P = nil then
      Exit;
    E2 := AddPtr(P, 4);

    if E1 <> E2 then
      Exit;

    {Save the five bytes at the start of the system handler}
    Move(E1^, SaveErrorEntry, 5);

    {Store the patch code for a jump to the recovery handler}
    NewErrorEntry[1] := $EA; {JMP DWORD PTR}
    P := @Handler;
    Move(P, NewErrorEntry[2], SizeOf(Pointer));

    {Store address of system error handler}
    SystemHandler := E1;
    {Store address after the jump to be patched in}
    SystemContinue := AddPtr(E1, 5);

    {Take over interrupt 0 so we can balance the stack}
    SetIntVec(0, @ErrHanInt0);

    {Take over interrupts 2 and 75 so we can catch floating point errors}
    Trap8087errors;

    {Successful initialization}
    Initialize := True;
  end;

begin
  {Find the system error handler}
  CanRecover := Initialize;
  if CanRecover then
    {Turn on error recovery}
    ErrorRecovery(True, nil);
end.
