{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$I OPLUS.INC}
{$ENDIF}

{*********************************************************}
{*                    TPBCD.PAS 5.12                     *}
{*        Copyright (c) TurboPower Software 1987.        *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpBCD;
  {-Binary Coded Decimal routines}

interface

const
  BCDsize = 10;
type
  BCD = array[1..BCDsize] of Byte;

const
  {Pi in BCD format}
  PiBcd : BCD = ($40, $24, $93, $97, $58, $53, $26, $59, $41, $31);
const
  {0 in BCD format}
  ZeroBcd : BCD = ($0, $0, $0, $0, $0, $0, $0, $0, $0, $0);
const
  MoneySign : Char = '$';    {Used by Form for floating dollar sign}
  CommaForPeriod : Boolean = False; {replace '.' with ',' in Form masks}

procedure RealToBCD(R : Real; var B : BCD);
  {-Convert a real to a BCD}

procedure LongintToBCD(L : LongInt; var B : BCD);
  {-Convert a Longint to a BCD}

function BCDtoReal(B : BCD) : Real;
  {-Convert a BCD to a real}

function StrBCD(B : BCD; Width, Places : Byte) : string;
  {-Return a BCD as a string}

function StrExpBCD(B : BCD; Width : Byte) : string;
  {-Return B as a string in exponential format}

procedure ValBCD(S : string; var B : BCD; var Code : Word);
  {-Convert a string to a BCD}

procedure AbsBCD(B1 : BCD; var B2 : BCD);
  {-Returns absolute value of B1 in B2}

procedure FracBCD(B1 : BCD; var B2 : BCD);
  {-Returns the fractional part of B1 in B2}

procedure IntBCD(B1 : BCD; var B2 : BCD);
  {-Returns the integer part of B1 in B2}

function RoundBCD(B1 : BCD) : LongInt;
  {-Returns the value of B1 rounded to the nearest long integer}

function TruncBCD(B1 : BCD) : LongInt;
  {-Returns the greatest long integer less than or equal to B1}

function Form(Mask : string; B : BCD) : string;
  {-Returns a formatted string with digits from B merged into the Mask}

procedure AddBCD(B1, B2 : BCD; var B3 : BCD);
  {-Add B1 to B2 and put result in B3}

procedure SubBCD(B1, B2 : BCD; var B3 : BCD);
  {-Subtract B2 from B1 and put result in B3}

procedure MultBCD(B1, B2 : BCD; var B3 : BCD);
  {-Multiply B1 by B2 and put result in B3}

procedure DivBCD(B1, B2 : BCD; var B3 : BCD);
  {-Divide B1 by B2 and put result in B3}

function EqualBCD(B1, B2 : BCD) : Boolean;
  {-Returns true if B1 = B2}

function NotEqualBCD(B1, B2 : BCD) : Boolean;
  {-Returns true if B1 <> B2}

function GreaterBCD(B1, B2 : BCD) : Boolean;
  {-Returns true if B1 > B2}

function GreaterEqualBCD(B1, B2 : BCD) : Boolean;
  {-Returns true if B1 >= B2}

function LessBCD(B1, B2 : BCD) : Boolean;
  {-Returns true if B1 < B2}

function LessEqualBCD(B1, B2 : BCD) : Boolean;
  {-Returns true if B1 <= B2}

  {** transcendental functions **}

procedure ArcTanBCD(B1 : BCD; var B2 : BCD);
  {-Returns arc tangent of B1 in B2}

procedure CosBCD(B1 : BCD; var B2 : BCD);
  {-Returns cosine of B1 in B2}

procedure ExpBCD(B1 : BCD; var B2 : BCD);
  {-Returns the exponential of B1 in B2}

procedure LnBCD(B1 : BCD; var B2 : BCD);
  {-Returns the natural log of B1 in B2}

procedure SinBCD(B1 : BCD; var B2 : BCD);
  {-Returns the sine of B1 in B2}

procedure SqrBCD(B1 : BCD; var B2 : BCD);
  {-Returns the square of B1 in B2}

procedure SqrtBCD(B1 : BCD; var B2 : BCD);
  {-Returns the square root of B1 in B2}

  {==========================================================================}

implementation

type
  TempRealType = array[1..2, 1..BCDsize] of Byte;
var
  TempReal1 :
    record
      case Byte of
        0 : (TR : TempRealType);
        1 : (St : string[19]);
      end;
  TempReal2 : TempRealType;
  TempReal3 : array[1..4, 1..BCDsize] of Byte;
var
  TempReal4,
  TempReal5,
  TempReal6 : BCD;

  procedure SystemStr(R : Real; var S : string);
    {-Call the system Str routine to do work of Real to BCD conversion}
  begin
    {$IFOPT N+}          {!!.08}
      Str(R:19:-1, S);   {!!.08}
      Delete(S, 16, 2);  {!!.08}
    {$ELSE}              {!!.08}
      Str(R:17:-1, S);   {!!.08}
    {$ENDIF}             {!!.08}
  end;

  procedure SystemVal(S : string; var R : Real; var Code : Word);
    {-Call the system Val routine to do work of BCD to Real conversion}
  begin
    Val(S, R, Code);
  end;

  {$L TPBCD.OBJ}
  {$L BCDTRANS.OBJ}

  {$F-} {all non-interfaced externals are called NEAR}

  {routines in TPBCD needed by BCDTRANS}
  procedure LoadTempReal2; external;
  procedure SetUsersReal; external;
  procedure MultPrimitive; external;
  procedure DivPrimitive; external;
  procedure AddPrimitive; external;
  procedure CopyTempToTemp; external;
  procedure CopyUsersTo2; external;
  procedure ActualIntBCD; external;

  {routines in TPBCD}
  procedure RealToBCD(R : Real; var B : BCD); external;
  procedure LongintToBCD(L : LongInt; var B : BCD); external;
  function BCDtoReal(B : BCD) : Real; external;
  function StrBCD(B : BCD; Width, Places : Byte) : string; external;
  function StrExpBCD(B : BCD; Width : Byte) : string; external;
  procedure ValBCD(S : string; var B : BCD; var Code : Word); external;
  procedure AddBCD(B1, B2 : BCD; var B3 : BCD); external;
  procedure SubBCD(B1, B2 : BCD; var B3 : BCD); external;
  procedure MultBCD(B1, B2 : BCD; var B3 : BCD); external;
  procedure DivBCD(B1, B2 : BCD; var B3 : BCD); external;
  function EqualBCD(B1, B2 : BCD) : Boolean; external;
  function NotEqualBCD(B1, B2 : BCD) : Boolean; external;
  function GreaterBCD(B1, B2 : BCD) : Boolean; external;
  function GreaterEqualBCD(B1, B2 : BCD) : Boolean; external;
  function LessBCD(B1, B2 : BCD) : Boolean; external;
  function LessEqualBCD(B1, B2 : BCD) : Boolean; external;
  procedure AbsBCD(B1 : BCD; var B2 : BCD); external;
  procedure FracBCD(B1 : BCD; var B2 : BCD); external;
  procedure IntBCD(B1 : BCD; var B2 : BCD); external;

  {routines in BCDTRANS}
  procedure ArcTanBCD(B1 : BCD; var B2 : BCD); external;
  procedure CosBCD(B1 : BCD; var B2 : BCD); external;
  procedure ExpBCD(B1 : BCD; var B2 : BCD); external;
  procedure LnBCD(B1 : BCD; var B2 : BCD); external;
  procedure SinBCD(B1 : BCD; var B2 : BCD); external;
  procedure SqrBCD(B1 : BCD; var B2 : BCD); external;
  procedure SqrtBCD(B1 : BCD; var B2 : BCD); external;
  function RoundBCD(B1 : BCD) : LongInt; external;
  function TruncBCD(B1 : BCD) : LongInt; external;

  {$F+}

  function Form(Mask : string; B : BCD) : string;
    {-Returns a formatted string with digits from B merged into the Mask}
  type
    FillType = (Blank, Asterisk, Zero);
  const
    FormChars : string[8] = '#@*$-+,.';
    PlusArray : array[Boolean] of Char = ('+', '-');
    MinusArray : array[Boolean] of Char = (' ', '-');
    FillArray : array[FillType] of Char = (' ', '*', '0');
  var
    ExpB : Byte absolute B;  {B's sign/exponent byte}
    S : string;              {temporary string}
    Filler : FillType;       {char for unused digit slots: ' ', '*', '0'}
    WontFit,                 {true if number won't fit in the mask}
    AddMinus,                {true if minus sign needs to be added}
    Dollar,                  {true if floating dollar sign is desired}
    Negative : Boolean;      {true if B is negative}
    StartF,                  {starting point of the numeric field}
    EndF : Word;             {end of numeric field}
    DotPos,                  {position of '.' in Mask}
    Digits,                  {total # of digits}
    Places,                  {# of digits after the '.'}
    Blanks,                  {# of blanks returned by StrBcd}
    FirstDigit,              {pos. of first digit returned by Str}
    Extras,                  {# of extra digits needed for special cases}
    DigitPtr : Byte;         {pointer into temporary string of digits}
    I : Word;
  label
    EndFound,
    RedoCase,
    Done;
  begin
    {check for empty string}
    if Length(Mask) = 0 then
      goto Done;

    {initialize variables}
    Filler := Blank;
    DotPos := 0;
    Places := 0;
    Digits := 0;
    Dollar := False;
    AddMinus := True;
    StartF := 1;

    {store the sign of the real and make it positive}
    Negative := (ExpB and $80) <> 0;
    ExpB := ExpB and $7F;

    {find the starting point for the field}
    while (StartF <= Length(Mask)) and (Pos(Mask[StartF], FormChars) = 0) do
      Inc(StartF);
    if StartF > Length(Mask) then
      goto Done;

    {find the end point for the field}
    for EndF := StartF to Length(Mask) do
      case Mask[EndF] of
        '*' : Filler := Asterisk;
        '@' : Filler := Zero;
        '$' : Dollar := True;
        '-',
        '+' : AddMinus := False;
        '#' : {ignore} ;
        ',' :
          begin
            DotPos := EndF;
            if CommaForPeriod then
              Mask[EndF] := '.';
          end;
        '.' :
          begin
            DotPos := EndF;
            if CommaForPeriod then
              Mask[EndF] := ',';
          end;
      else
        goto EndFound;
      end;

    {if we get here at all, the last char was part of the field}
    Inc(EndF);

EndFound:
    {if we jumped to here instead, it wasn't}
    Dec(EndF);

    {disallow Dollar if Filler is Zero}
    if Filler = Zero then
      Dollar := False;

    {we need an extra slot if Dollar is True}
    Extras := Ord(Dollar);

    {get total # of digits and # after the decimal point}
    for I := StartF to EndF do
      case Mask[I] of
        '#', '@',
        '*', '$' :
          begin
            Inc(Digits);
            if (I > DotPos) and (DotPos <> 0) then
              Inc(Places);
          end;
      end;

    {need one more 'digit' if Places > 0}
    Inc(Digits, Ord(Places > 0));

  {also need an extra blank if (1) Negative is true, and (2) Filler is Blank,
   and (3) AddMinus is true}
    if Negative and AddMinus and (Filler = Blank) then
      Inc(Extras)
    else
      AddMinus := False;

    {translate the real to a string}
    S := StrBCD(B, Digits, Places);

    {count number of initial blanks}
    Blanks := 1;
    while S[Blanks] = ' ' do
      Inc(Blanks);
    FirstDigit := Blanks;
    Dec(Blanks);

  {the number won't fit if (a) S is longer than Digits or (b) the number of
   initial blanks is less than Extras}
    WontFit := (Length(S) > Digits) or (Blanks < Extras);

    {if it won't fit, fill decimal slots with '*'}
    if WontFit then begin
      for I := StartF to EndF do
        case Mask[I] of
          '#', '@', '*', '$' : Mask[I] := '*';
          '+' : Mask[I] := PlusArray[Negative];
          '-' : Mask[I] := MinusArray[Negative];
        end;
      goto Done;
    end;

    {fill initial blanks in S with Filler; insert floating dollar sign}
    if Blanks > 0 then begin
      FillChar(S[1], Blanks, FillArray[Filler]);

      {put floating dollar sign in last blank slot if necessary}
      if Dollar then begin
        S[Blanks] := MoneySign;
        Dec(Extras);
        Dec(Blanks);
      end;

      {insert a minus sign if necessary}
      if AddMinus then
        S[Blanks] := '-';
    end;

    {put in the digits / signs}
    DigitPtr := Length(S);
    for I := EndF downto StartF do begin
RedoCase:
      case Mask[I] of
        '#', '@', '*', '$' :
          if DigitPtr <> 0 then begin
            Mask[I] := S[DigitPtr];
            Dec(DigitPtr);
            if (S[DigitPtr] = '.') and (DigitPtr <> 0) then
              Dec(DigitPtr);
          end
          else
            Mask[I] := FillArray[Filler];
        ',', '.' :
          if (I < DotPos) and (DigitPtr < FirstDigit) then begin
            Mask[I] := '#';
            goto RedoCase;
          end;
        '+' : Mask[I] := PlusArray[Negative];
        '-' : Mask[I] := MinusArray[Negative];
      end;
    end;

Done:
    Form := Mask;
  end;

end.
