{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$I OPLUS.INC}
{$ENDIF}

{*********************************************************}
{*                  TPASCIIZ.PAS 5.12                    *}
{*        Copyright (c) TurboPower Software 1987.        *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TPAsciiz;
  {-Routines to support ASCIIZ strings}

interface

uses
  Tstring_;

const
  MaxAsciiz = 1024;          {Maximum length of Asciiz - increase up to 65520}
  NotFound = $FFFF;          {Returned by the Pos functions if substring not found}

type
  Asciiz = array[0..MaxAsciiz] of Char;
  AsciizPtr = ^Asciiz;

function Asc2Str(var A : Asciiz) : string;
  {-Convert Asciiz to Turbo string, truncating if longer than 255 chars}

procedure Str2Asc(S : string; var A : Asciiz);
  {-Convert a Turbo string into an Asciiz}

function LenAsc(A : Asciiz) : Word;
  {-Return the length of an Asciiz string}
  inline
  ($5F/                      {pop  di       ;get pointer to ASCIIZ}
    $07/                     {pop  es       ; into es:di}
    $89/$FB/                 {mov  bx,di    ;store initial offset}
    $B9/$FF/$FF/             {mov  cx,$FFFF ;check maximum length}
    $B0/$00/                 {mov  al,0     ;look for null}
    $FC/                     {cld           ;forward direction}
    $F2/                     {repne}
    $AE/                     {scasb         ;scan while equal}
    $29/$DF/                 {sub  di,bx    ;get the number of bytes scanned}
    $89/$F8/                 {mov  ax,di    ;return in ax}
    $48);                    {dec  ax       ;null doesn't count}

procedure CopyAsc(var A : Asciiz; Start, Len : Word; var O : Asciiz);
  {-Return a substring of a. Note start=0 for first char in a}

procedure DeleteAsc(var A : Asciiz; Start, Len : Word);
  {-Delete len characters of a, starting at position start}

procedure ConcatAsc(var A, B, C : Asciiz);
  {-Concatenate two Asciiz strings, returning a third}

procedure ConcatStr(var A : Asciiz; S : string; var C : Asciiz);
  {-Concatenate a string to an asciiz, returning a new asciiz}

procedure InsertAsc(var Obj, A : Asciiz; Start : Word);
  {-Insert asciiz obj at position start of a}

procedure InsertStr(Obj : string; var A : Asciiz; Start : Word);
  {-Insert string obj at position start of a}

function PosStr(Obj : string; var A : Asciiz) : Word;
  {-Return the position of the string obj in a, returning NotFound if not found}

function PosAsc(var Obja, A : Asciiz) : Word;
  {-Return the position of obja in a, returning NotFound if not found}

function AscToHeap(var A : Asciiz) : AsciizPtr;
  {-Put Asciiz on heap, returning a pointer, nil if insufficient memory}

procedure AscFromHeap(P : AsciizPtr; var A : Asciiz);
  {-Return an Asciiz from the heap, empty if pointer is nil}

procedure DisposeAsc(P : AsciizPtr);
  {-Dispose of heap space pointed to by P}

function ReadLnAsc(var F : Text; var A : Asciiz) : Boolean;
  {-Read an Asciiz from text file, returning true if successful}

function WriteAsc(var F : Text; var A : Asciiz) : Boolean;
  {-Write an Asciiz to text file, returning true if successful}

procedure AscUpcase(var A, B : Asciiz);
  {-Uppercase the Asciiz in a, returning b}

procedure AscLocase(var A, B : Asciiz);
  {-Lowercase the Asciiz in a, returning b}

procedure AscCharStr(Ch : Char; Len : Word; var A : Asciiz);
  {-Return an Asciiz of length len filled with ch}

procedure AscPadCh(var A : Asciiz; Ch : Char; Len : Word; var B : Asciiz);
  {-Right-pad the Asciiz in a to length len with ch, returning b}

procedure AscPad(var A : Asciiz; Len : Word; var B : Asciiz);
  {-Right-pad the Asciiz in a to length len with blanks, returning b}

procedure AscLeftPadCh(var A : Asciiz; Ch : Char; Len : Word; var B : Asciiz);
  {-Left-pad the Asciiz in a to length len with ch, returning b}

procedure AscLeftPad(var A : Asciiz; Len : Word; var B : Asciiz);
  {-Left-pad the Asciiz in a to length len with blanks, returning b}

procedure AscTrimLead(var A, B : Asciiz);
  {-Return an Asciiz with leading white space removed}

procedure AscTrimTrail(var A, B : Asciiz);
  {-Return an Asciiz with trailing white space removed}

procedure AscTrim(var A, B : Asciiz);
  {-Return an Asciiz with leading and trailing white space removed}

procedure AscCenterCh(var A : Asciiz; Ch : Char; Width : Word; var B : Asciiz);
  {-Return an Asciiz centered in an Asciiz of Ch with specified width}

procedure AscCenter(var A : Asciiz; Width : Word; var B : Asciiz);
  {-Return an Asciiz centered in an Asciiz of blanks with specified width}

type
  AscCompareType = (AscLess, AscEqual, AscGreater);

function CompAsc(var a1, a2 : Asciiz) : AscCompareType;
  {-Return less, equal, greater if a1<a2, a1=a2, or a1>a2}

function CompUCAsc(var a1, a2 : Asciiz) : AscCompareType;
  {-Compare two Asciizs in a case insensitive manner}

  {==========================================================================}

implementation

const
  Null = #0;

  function Asc2Str(var A : Asciiz) : string;
    {-Convert ASCIIZ to Turbo string, truncating if longer than 255 chars}
  var
    S : string;
    Len : Word;
  begin
    Len := LenAsc(A);
    if Len > 255 then
      Len := 255;
    S[0] := Char(Len);
    Move(A, S[1], Len);
    Asc2Str := S;
  end;

  procedure Str2Asc(S : string; var A : Asciiz);
    {-Convert a Turbo string into an ASCIIZ}
  begin
    Move(S[1], A, Length(S));
    A[Length(S)] := Null;
  end;

  procedure CopyAsc(var A : Asciiz; Start, Len : Word; var O : Asciiz);
    {-Return a substring of a. Note start=0 for first char in a}
  var
    alen : Word;
  begin
    alen := LenAsc(A);
    if Start > alen then
      {Return null string}
      O[0] := Null
    else begin
      {Don't copy more than exists}
      if Longint(Start)+Len > alen then {!!.12}
        Len := alen-Start;
      Move(A[Start], O, Len);
      O[Len] := Null;
    end;
  end;

  procedure DeleteAsc(var A : Asciiz; Start, Len : Word);
    {-Delete len characters of a, starting at position start}
  var
    alen : Word;
    mid : Word;
  begin
    alen := LenAsc(A);
    if Start < alen then begin
      {Don't do anything if start position exceeds length of string}
      mid := Start+Len;
      if mid < alen then begin
        {Move right remainder of string left}
        Move(A[mid], A[Start], alen-mid);
        A[alen-Len] := Null;
      end else
        {Entire end of string deleted}
        A[Start] := Null;
    end;
  end;

  procedure ConcatAsc(var A, B, C : Asciiz);
    {-Concatenate two Asciiz strings, returning a third}
  var
    alen : Word;
    blen : Word;
  begin
    alen := LenAsc(A);
    blen := LenAsc(B);

    {Put a into the result}
    Move(A, C, alen);

    {Store as much of b as fits into result}
    if alen+blen > MaxAsciiz then
      blen := MaxAsciiz-alen;
    Move(B, C[alen], blen);

    {Terminate the result}
    C[alen+blen] := Null;
  end;

  procedure ConcatStr(var A : Asciiz; S : string; var C : Asciiz);
    {-Concatenate a string to an asciiz, returning a new asciiz}
  var
    alen : Word;
    slen : Word;
  begin
    alen := LenAsc(A);
    slen := Length(S);

    {Put a into the result}
    Move(A, C, alen);

    {Store as much of s as fits into result}
    if alen+slen > MaxAsciiz then
      slen := MaxAsciiz-alen;
    Move(S[1], C[alen], slen);

    {Terminate the result}
    C[alen+slen] := Null;
  end;

  procedure InsertAsc(var Obj, A : Asciiz; Start : Word);
    {-Insert asciiz obj at position start of a}
  var
    alen : Word;
    olen : Word;
    mid : Word;
  begin
    alen := LenAsc(A);
    olen := LenAsc(Obj);

    if Start > alen then
      {Concatenate if start exceeds alen}
      Start := alen

    else begin
      {Move right side characters right to make space for insert}
      mid := Start+olen;
      if mid < MaxAsciiz then
        {Room for at least some of the right side characters}
        if alen+olen < MaxAsciiz then
          {Room for all of the right side}
          Move(A[Start], A[mid], alen-Start)
        else
          {Room for part of the right side}
          Move(A[Start], A[mid], MaxAsciiz-mid);
    end;

    {Insert the obj string}
    if Start+olen >= MaxAsciiz then
      olen := MaxAsciiz-Start;
    Move(Obj, A[Start], olen);

    {Terminate the string}
    if alen+olen < MaxAsciiz then
      A[alen+olen] := Null
    else
      A[MaxAsciiz] := Null;
  end;

  procedure InsertStr(Obj : string; var A : Asciiz; Start : Word);
    {-Insert string obj at position start of a}
  var
    alen : Word;
    olen : Word;
    mid : Word;
  begin
    alen := LenAsc(A);
    olen := Length(Obj);

    if Start > alen then
      {Concatenate if start exceeds alen}
      Start := alen

    else begin
      {Move right side characters right to make space for insert}
      mid := Start+olen;
      if mid < MaxAsciiz then
        {Room for at least some of the right side characters}
        if alen+olen < MaxAsciiz then
          {Room for all of the right side}
          Move(A[Start], A[mid], alen-Start)
        else
          {Room for part of the right side}
          Move(A[Start], A[mid], MaxAsciiz-mid);
    end;

    {Insert the obj string}
    if Start+olen >= MaxAsciiz then
      olen := MaxAsciiz-Start;
    Move(Obj[1], A[Start], olen);

    {Terminate the string}
    if alen+olen < MaxAsciiz then
      A[alen+olen] := Null
    else
      A[MaxAsciiz] := Null;
  end;

  {$L TPASCIIZ}
  function Search(var Buffer; BufLength : Word; var Match; MatLength : Word) : Word;
    external;
  procedure AscUpcase(var A, B : Asciiz); external;
  procedure AscLocase(var A, B : Asciiz); external;
  function CompAsc(var a1, a2 : Asciiz) : AscCompareType; external;
  function CompUCAsc(var a1, a2 : Asciiz) : AscCompareType; external;

  function PosStr(Obj : string; var A : Asciiz) : Word;
    {-Return the position of the string obj in a, returning NotFound if not found}
  begin
    PosStr := Search(A, LenAsc(A), Obj[1], Length(Obj));
  end;

  function PosAsc(var Obja, A : Asciiz) : Word;
    {-Return the position of obja in a, returning NotFound if not found}
  begin
    PosAsc := Search(A, LenAsc(A), Obja, LenAsc(Obja));
  end;

  function AscToHeap(var A : Asciiz) : AsciizPtr;
    {-Put Asciiz on heap, returning a pointer, nil if insufficient memory}
  var
    alen : Word;
    P : AsciizPtr;
  begin
    alen := Succ(LenAsc(A));
    if MaxAvail >= alen then begin
      GetMem(P, alen);
      Move(A, P^, alen);
      AscToHeap := P;
    end else
      AscToHeap := nil;
  end;

  procedure AscFromHeap(P : AsciizPtr; var A : Asciiz);
    {-Return an Asciiz from the heap, empty if pointer is nil}
  begin
    if P = nil then
      A[0] := Null
    else
      Move(P^, A, Succ(LenAsc(P^)));
  end;

  procedure DisposeAsc(P : AsciizPtr);
    {-Dispose of heap space pointed to by P}
  begin
    if P <> nil then
      FreeMem(P, Succ(LenAsc(P^)));
  end;

  procedure AscCharStr(Ch : Char; Len : Word; var A : Asciiz);
    {-Return an Asciiz of length len filled with ch}
  begin
    if Len = 0 then
      A[0] := Null
    else begin
      if Len > MaxAsciiz then
        Len := MaxAsciiz;
      FillChar(A, Len, Ch);
      A[Len] := Null;
    end;
  end;

  procedure AscPadCh(var A : Asciiz; Ch : Char; Len : Word; var B : Asciiz);
    {-Right-pad the Asciiz in a to length len with ch, returning b}
  var
    alen : Word;
  begin
    alen := LenAsc(A);
    if alen >= Len then
      {Return the input string}
      Move(A, B, Succ(alen))
    else begin
      if Len > MaxAsciiz then
        Len := MaxAsciiz;
      Move(A, B, alen);
      FillChar(B[alen], Len-alen, Ch);
      B[Len] := Null;
    end;
  end;

  procedure AscPad(var A : Asciiz; Len : Word; var B : Asciiz);
    {-Right-pad the Asciiz in a to length len with blanks, returning b}
  begin
    AscPadCh(A, ' ', Len, B);
  end;

  procedure AscLeftPadCh(var A : Asciiz; Ch : Char; Len : Word; var B : Asciiz);
    {-Left-pad the Asciiz in a to length len with ch, returning b}
  var
    alen : Word;
  begin
    alen := LenAsc(A);
    if alen >= Len then
      {Return the input string}
      Move(A, B, Succ(alen))
    else begin
      FillChar(B, Len-alen, Ch);
      Move(A, B[Len-alen], alen);
      B[Len] := Null;
    end;
  end;

  procedure AscLeftPad(var A : Asciiz; Len : Word; var B : Asciiz);
    {-Left-pad the Asciiz in a to length len with blanks, returning b}
  begin
    AscLeftPadCh(A, ' ', Len, B);
  end;

  procedure AscTrimLead(var A, B : Asciiz);
    {-Return an Asciiz with leading white space removed}
  var
    alen : Word;
    apos : Word;
  begin
    alen := LenAsc(A);
    apos := 0;
    while (apos < alen) and (A[apos] <= ' ') do
      Inc(apos);
    Move(A[apos], B, Succ(alen-apos));
  end;

  procedure AscTrimTrail(var A, B : Asciiz);
    {-Return an Asciiz with trailing white space removed}
  var
    alen : Word;
  begin
    alen := LenAsc(A);
    while (alen > 0) and (A[Pred(alen)] <= ' ') do
      Dec(alen);
    Move(A, B, alen);
    B[alen] := Null;
  end;

  procedure AscTrim(var A, B : Asciiz);
    {-Return an Asciiz with leading and trailing white space removed}
  var
    blen : Word;
  begin
    AscTrimLead(A, B);
    blen := LenAsc(B);
    while (blen > 0) and (B[Pred(blen)] <= ' ') do
      Dec(blen);
    B[blen] := Null;
  end;

  procedure AscCenterCh(var A : Asciiz; Ch : Char; Width : Word; var B : Asciiz);
    {-Return an Asciiz centered in an Asciiz of Ch with specified width}
  var
    alen : Word;
  begin
    alen := LenAsc(A);
    if alen >= Width then
      {Return input}
      Move(A, B, Succ(alen))
    else begin
      FillChar(B, Width, Ch);
      Move(A, B[(Width-alen) shr 1], alen);
      B[Width] := Null;
    end;
  end;

  procedure AscCenter(var A : Asciiz; Width : Word; var B : Asciiz);
    {-Return an Asciiz centered in an Asciiz of blanks with specified width}
  begin
    AscCenterCh(A, ' ', Width, B);
  end;

type
  {text buffer}
  TextBuffer = array[0..65520] of Byte;

  {structure of a Turbo File Interface Block}
  FIB = record
          Handle : Word;
          Mode : Word;
          BufSize : Word;
          Private : Word;
          BufPos : Word;
          BufEnd : Word;
          BufPtr : ^TextBuffer;
          OpenProc : Pointer;
          InOutProc : Pointer;
          FlushProc : Pointer;
          CloseProc : Pointer;
          UserData : array[1..16] of Byte;
          Name : array[0..79] of Char;
          Buffer : array[0..127] of Char;
        end;

const
  FMClosed = $D7B0;
  FMInput = $D7B1;
  FMOutput = $D7B2;
  FMInOut = $D7B3;
  CR : Char = ^M;

  function ReadLnAsc(var F : Text; var A : Asciiz) : Boolean;
    {-Read an Asciiz from text file, returning true if successful}
  var
    CrPos : Word;
    alen : Word;
    blen : Word;

    function RefillBuf(var F : Text) : Boolean;
      {-Refill buffer}
    var
      Ch : Char;
    begin
      with FIB(F) do begin
        BufEnd := 0;
        BufPos := 0;
        Read(F, Ch);
        if IoResult <> 0 then begin
          {Couldn't read from file}
          RefillBuf := False;
          Exit;
        end;
        {Reset the buffer again}
        BufPos := 0;
        RefillBuf := True;
      end;
    end;


  begin
    with FIB(F) do begin

      {Initialize the Asciiz length and function result}
      alen := 0;
      ReadLnAsc := False;

      {Make sure file open for input}
      if Mode <> FMInput then
        Exit;

      {Make sure something is in buffer}
      if BufPos >= BufEnd then
        if not(RefillBuf(F)) then
          Exit;

      {Use the Turbo text file buffer to build the Asciiz}
      repeat

        {Search for the next carriage return in the file buffer}
        CrPos := Search(BufPtr^[BufPos], {Succ}(BufEnd-BufPos), CR, 1); {!!.10}

        if CrPos = $FFFF then begin
          {CR not found, save the portion of the buffer seen so far}
          blen := BufEnd-BufPos;
          if alen+blen > MaxAsciiz then
            blen := MaxAsciiz-alen;

          Move(BufPtr^[BufPos], A[alen], blen);
          Inc(alen, blen);

          {See if at end of file}
          if eof(F) then begin
            {Force exit with this line}
            CrPos := 0;
            {Remove trailing ^Z}
            while (alen > 0) and (A[Pred(alen)] = ^Z) do
              Dec(alen);
          end else if not(RefillBuf(F)) then
            Exit;

        end else begin
          {Save up to the CR}
          blen := CrPos;
          if alen+blen > MaxAsciiz then
            blen := MaxAsciiz-alen;
          Move(BufPtr^[BufPos], A[alen], blen);
          Inc(alen, blen);

          {Inform Turbo we used the characters}
          Inc(BufPos, Succ(CrPos));

          {Skip over following ^J}
          if BufPos < BufEnd then begin
            {Next character is within current buffer}
            if BufPtr^[BufPos] = Ord(^J) then
              Inc(BufPos);
          end else begin
            {Next character is not within current buffer}
            {Refill the buffer}
            if not(RefillBuf(F)) then
              Exit;
            if BufPos < BufEnd then
              if BufPtr^[BufPos] = Ord(^J) then
                Inc(BufPos);
          end;

        end;

      until (CrPos <> $FFFF) or (alen > MaxAsciiz);

      {Return success and terminate the Asciiz}
      ReadLnAsc := True;
      A[alen] := Null;

    end;
  end;

  function WriteAsc(var F : Text; var A : Asciiz) : Boolean;
    {-Write an Asciiz to text file, returning true if successful}
  var
    S : string;
    alen : Word;
    apos : Word;
    slen : Word;
  begin
    alen := LenAsc(A);
    apos := 0;
    WriteAsc := False;

    {Write the ASCIIZ as a series of strings}
    while apos < alen do begin
      slen := alen-apos;
      if slen > 255 then
        slen := 255;
      S[0] := Chr(slen);
      Move(A[apos], S[1], slen);
      Write(F, S);
      if IoResult <> 0 then
        Exit;
      Inc(apos, slen);
    end;

    WriteAsc := True;
  end;

end.
