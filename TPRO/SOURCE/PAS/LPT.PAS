{$R-,S-}
{
  ** LPT Unit **
  ** Copyright (c) 1988 Richard S. Sadowsky
  ** by Richard S. Sadowsky
  ** 1/12/88
  ** version 1.0
}

{$DEFINE AssignLstDevice}

unit Lpt;

interface

const
  fmClosed         = $D7B0; { magic numbers for Turbo }
  fmInput          = $D7B1;
  fmOutput         = $D7B2;
  fmInOut          = $D7B3;

  IO_Invalid       = $FC;    { invalid operation eg. attempt to write }
                             { to a file opened in fmInput mode       }

  LPTNames         : array[0..2] of String[4] = ('LPT1','LPT2','LPT3');

var
  Lst              : Text;   { for source compatability with TP3 }

function DoInt17(Ch : Char; LPTNo : Word) : Byte;
{ send a character to LPTNo via ROM BIOS int 17h func 0h }
{ implented as an inline "macro" for speed and the heck  }
{ of it! Bet you've seen this routine before!            }
Inline(
  $5A/         {  pop     DX    ; get printer number}
  $58/         {  pop     AX    ; get char}
  $B4/$00/     {  mov     AH,00 ; set AH for BIOS int 17h function 0}
  $CD/$17/     {  int     $17   ; do an int 17h}
  $86/$E0);    {  xchg    AL,AH ; put byte result in AL}

procedure AssignLst(var F : Text; LPTNumber : Word);
{ like Turbo's assign, except associates Text variable with one of the LPTs }

implementation

type
  TextBuffer       = array[0..127] of Char;

  TextRec          = record
                       Handle     : Word;
                       Mode       : Word;
                       BufSize    : Word;
                       Private    : Word;
                       BufPos     : Word;
                       BufEnd     : Word;
                       BufPtr     : ^TextBuffer;
                       OpenFunc   : Pointer;
                       InOutFunc  : Pointer;
                       FlushFunc  : Pointer;
                       CloseFunc  : Pointer;
                       { 16 byte user data area, I use 4 bytes }
                       PrintMode  : Word;  { not currently used}
                       LPTNo      : Word;  { LPT number in [0..2] }
                       UserData   : array[1..12] of Char;
                       Name       : array[0..79] of Char;
                       Buffer     : TextBuffer;
                     end;

procedure Out_Char(Ch : Char; LPTNo : Word; var ErrorCode : Integer);
{ call macro to send char to LPTNo.  If bit 4, the Printer Selected bit }
{ is not set upon return, it is assumed that an error has occurred.     }

begin
  ErrorCode := DoInt17(Ch,LPTNo);
  if (ErrorCode and $10) = $10 then { if bit 4 is set }
    ErrorCode := 0                  { no error }
  { if bit 4 is not set, error is passed untouched and placed in IOResult }
end;

{$F+} { <==The following routines MUST be compiler as FAR }

function LstIgnore(var F : TextRec) : Integer;
{ A do nothing, no error routine }
begin
  LstIgnore := 0 { return 0 for IOResult }
end;

function LstOutput(var F : TextRec) : Integer;
{ Send whatever has accumulated in the Buffer to int 17h   }
{ If error occurs, return in IOResult.  See Inside Turbo   }
{ Pascal chapter of TP4 manual for more info on TFDD       }
var
  I                : Word;
  ErrorCode        : Integer;

begin
  LstOutput := 0;
  with F do begin
    for I := 0 to Pred(BufPos) do begin
      Out_Char(BufPtr^[I],LPTNo,ErrorCode); { send each char to printer }
      if ErrorCode <> 0 then begin { if error }
        LstOutput := ErrorCode;    { return errorcode in IOResult }
        Exit                       { return from function }
      end
    end;
    BufPos := 0
  end;
end;

{$F-} { Near ok now }


procedure AssignLst(var F : Text; LPTNumber : Word);
{ like Turbo's assign, except associates Text variable with one of the LPTs }

begin
  with TextRec(F) do begin
    Mode       := fmClosed;
    BufSize    := SizeOf(Buffer);
    BufPtr     := @Buffer;
    OpenFunc   := @LstIgnore; { you don't open the BIOS printer functions }
    CloseFunc  := @LstIgnore; { nor do you close them }
    InOutFunc  := @LstOutput; { but you can Write to them }
    FlushFunc  := @LstOutput; { and you can WriteLn to them }
    LPTNo      := LPTNumber;  { user selected printer num (in [0..2]) }
    Move(LPTNames[LPTNumber],Name,4); { set name of device }
    BufPos := 0; { reset BufPos }
  end;
end;

begin

{$IFDEF AssignLstDevice}

  AssignLst(Lst,0); { set up turbo 3 compatable Lst device }
  Rewrite(Lst);

{$ENDIF}

end.
