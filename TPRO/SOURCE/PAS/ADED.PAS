{$X+,I-,S-,R-,B-,F+}

{.$I TPDEFINE.INC}

{*********************************************************}
{*                     ADed.PAS                          *}
{*-------------------------------------------------------*}
{*            (AD)vanced edition copyright by            *}
{*    Anton Deinow Software Research Laboratory, 1994.   *}
{*                Block engine appended.                 *}
{*********************************************************}

unit ADed;
  {-smal text editor}

interface

uses
  TpCrt,
  {$IFDEF UseMouse}
  TpMouse,
  {$ENDIF}
  Tstring_;

  {.F-}

type
 TaeCmd=(
  { fiction commands }
        aeNone,
        aeChar,
        aePass2user,
  { natural commands }
        aeCtrlChar,
        aeEnter,
        aeQuit,
        aeRestore,
        aeHome,
        aeEnd,
        aeLeft,
        aeRight,
        aeUp,
        aeDown,
        aeScrollUp,
        aeScrollDown,
        aePageUp,
        aePageDown,
        aeScreenTop,
        aeScreenBot,
        aeTopOfFile,
        aeEndOfFile,
        aeWordLeft,
        aeWordRight,
        aeBack,
        aeDel,
        aeDelEOL,
        aeDelLine,
        aeDelWord,
        aeTab,
        aeIns,
        aeIndent,
        aeWordWrap,
        aeReformatP,
        aeReformatG,
        aeHelp,
        aeMouse
 );

{.F+}

const
 UserAction:byte=0;  {¤«ï KeyReMaper' }

 MaxLineLength : Byte = 127; {!do not make larger than 127!}

 { error message codes }
 taBufferFull    = 1;       {edit buffer is full}
 taLineTooLong   = 2;       {line too long, CRLF inserted}
 taTooManyLines  = 3;       {max line limit would be exceeded}
 taOverLineLimit = 4;       {max line limit already exceeded}

 { if True, reformatting routine treats blank space at start of line as
   signalling the start of a new paragraph }
 IndentStartsParagraph:boolean =false;

 { if True, pressing <Del> when beyond the end of the current line will pull
   up the following line, just as <CtrlT> does}
 DeleteJoinsLines:boolean =true;

const
 AllowTruncation:boolean=true; {read partial files?}

type
 TaeBuffer = array[1..65521] of Char;
 TaeControlBlock=record
   XL, YL, XH, YH : Byte; {coordinates for edit window}
   BufPtr : ^TaeBuffer;    {pointer to text buffer}
   BufSize : Word;        {size of buffer}
   MaxLines : Integer;    {maximum number of lines}
   TotalBytes : Word;     {bytes in buffer}
   TotalLines : Integer;  {lines in buffer}
   LineAtTop : Integer;   {line at top of edit window}
   BufPosTop : Word;      {index into buffer for start of line at top}
   CurLine : Integer;     {line number of current line}
   BufPos : Word;         {index into buffer for start of current line}
   CurCol : Byte;         {position of cursor within current line}
   ColDelta : Byte;       {for horizontal scrolling}
   KnownLine : Integer;   {used to speed up scrolling/searching}
   KnownOfs : Word;       {"    "  "     "  "}
   BlkBeg :Integer;       {ÜAD begin block line}
   BlkEnd :Integer;       {ÜAD end block line}
   TAttr : Byte;          {attribute for normal text}
   CAttr : Byte;          {attribute for control characters}
   BAttr :byte;           {ÜAD attribute for marked text}
   NewLine :boolean;      {ÜAD true if cursor moved to new line}
   InsertMode : Boolean;  {True if in insert mode}
   IndentMode : Boolean;  {True if in auto-indent mode}
   ReadOnlyMode : Boolean;{True if in read-only mode}
   WordWrap : Boolean;    {True if word wrap is on}
   Modified : Boolean;    {True if edits have been made}
   TabDelta : Byte;       {distance between tab stops}
   Margin : Byte;         {right margin}
   HelpTopic : Word;      {help topic}
 end;

 aeStatusType = (
  aestOK, aestNotFound, aestInvalidName, aestReadError, aestTooLarge,
  aestTruncated, aestCreationError, aestWriteError, aestCloseError);

const
 aeUserKeyPtr : Pointer = nil; {ãª § â¥«ì ­  ¯®«ì§.¯p®æ-pã ®¡p ¡®âª¨ ª« ¢¨è}
 aeHelpPtr : Pointer = nil; {pointer to routine to display help}
 aeStatusPtr : Pointer = nil; {pointer to routine to display status line}
 aeErrorPtr : Pointer = nil; {pointer to routine to display error messages}
 HelpForMemo = TpCrt.HelpForMemo; {special code for help routine calls}

const
 { the commands in this set are disallowed in read-only mode }
 DisallowedInReadOnlyMode:Set of TaeCmd =
    [aeChar..aeEnter, aeRestore, aeBack..aeReformatG];

const
 { used only by aeStatus }
 StatusRow : Byte = 1;
 StatusAttr : Byte = $7F;

const
 { used only by aeError }
 ErrorRow : Byte = 25;     {default to top line of screen for error messages}
 ErrorAttr : Byte = $C;    {attribute for error message line}

  {$IFDEF UseMouse}
const
 { True if mouse support is enabled }
 aeMouseEnabled : Boolean = False;
  {$ENDIF}
{.F+}

procedure InitControlBlock(var AECB : TaeControlBlock;
                           XLow, YLow, XHigh, YHigh : Byte;
                           TextAttr, CtrlAttr,BlkAttr : Byte;
                           InsertOn, IndentOn, WordWrapOn : Boolean;
                           TabSize : Byte; HelpIndex : Word;
                           RightMargin : Byte; LineLimit : Integer;
                           BufferSize : Word; var Buffer);
  {-Initialize a memo editor control block}

function EditBuffer(var AECB : TaeControlBlock;
                  ReadOnly : Boolean):TaeCmd;
  {-Edit a buffer filled with text}

procedure aeStatusLine(var AECB:TaeControlBlock);
  {-Display status line}

procedure aeSayError(var AECB : TaeControlBlock; ErrorCode : Word);
  {-Display error message and wait for key press}

{$IFDEF UseMouse}
procedure EnableAEmouse;
  {-Enable mouse support in TPMEMO}

procedure DisableAEmouse;
  {-Disable mouse support in TPMEMO}

{$ENDIF}

{file handling routines}

function ReadTextFile(var Buffer; BufferSize : Word;
                      FName : string; var FSize : LongInt) : aeStatusType;
  {-Read a file into Buffer, returning a status code}

function SaveTextFile(var AECB : TaeControlBlock; FName : string;
                      MakeBackup : Boolean) : aeStatusType;
  {-Save the current file in the text buffer associated with EMCB}

  {.F-}
const
 firstAEkey=aeCtrlChar;
 lastAEkey =aeHelp;

 { default key assignments }
 aeKeySet:array[firstAEkey..lastAEkey] of word=(
  $1910,     { aeCtrlChar }
  $1C0D,     { aeEnter }
  $011B,     { aeQuit  }
  $0000,     { aeRestore }
  $4700,     { aeHome }
  $4F00,     { aeEnd  }
  $4B00,     { aeLeft }
  $4D00,     { aeRight}
  $4800,     { aeUp   }
  $5000,     { aeDown }
  $1600,     { aeScrollUp, Alt/U}
  $1100,     { aeScrollDown, Alt/W}
  $4900,     { aePageUp   }
  $5100,     { aePageDown }
  $7700,     { aeScreenTop, Ctrl/Home}
  $7500,     { aeScreenBot, Ctrl/End}
  $8400,     { aeTopOfFile, Ctrl/PgUp}
  $7600,     { aeEndOfFile, Ctrl/PgDn}
  $7300,     { aeWordLeft  }
  $7400,     { aeWordRight }
  $0E08,     { aeBack }
  $5300,     { aeDel  }
  $1205,     { aeDelEOL, Ctrl/E}
  $1519,     { aeDelLine, Ctrl/Y}
  $1117,     { aeDelWord, Ctrl/W}
  $0F09,     { aeTab }
  $5200,     { aeIns }
  $1709,     { aeIndent, Ctrl/I}
  $180F,     { aeWordWrap, Ctrl/O}
  $3002,     { aeReformatP, Ctrl/B}
  $2207,     { aeReformatG, Ctrl/G}
  $0000      { aeHelp   }
 );
{.F+}

function FindLineIndex(var AECB : TaeControlBlock; LineNum : Integer) : Word;
  {-Return the index into the edit buffer for the specified line number.
    LineNum must be <= EMCB.TotalLines.}

function FindLineLength(var AECB : TaeControlBlock; LineNum : Integer) : Word;
  {-Find the length of the specified line}

procedure InitBufferState(var AECB :TaeControlBlock;
                          BufferSize : Word; var Buffer);
  {-Initialize the edit buffer status fields in a control block}

procedure GetLine(var AECB :TaeControlBlock; var S : string; LineNum : Integer);
  {-Get the LineNum'th line from the buffer for the specified control block
    and store it in S. If line is longer than 255 characters, only the first
    255 characters will be loaded into S.}

procedure DrawLine(var AECB :TaeControlBlock; St : String; LineNum : Integer);
  {-Draw the string St, which represents the specified line number}

procedure FastWriteCtrl(St :string; Row, Col, Attr, Ctrl : Byte);
  {-Write St at Row,Col in Attr (video attribute) without snow.
    Control characters displayed in Ctrl as upper-case letters}

  {==========================================================================}

implementation

const
 SafetyMargin = 2;
 CtrlZ : Char = ^Z;
 CRLF : array[1..2] of Char = ^M^J;
 SearchFailed = $FFFF;

var
 LastCmd:TaeCmd;

  {$L TPMEMO}

  procedure FastWriteCtrl(St :string; Row, Col, Attr, Ctrl : Byte);
    {-Write St at Row,Col in Attr (video attribute) without snow.
      Control characters displayed in Ctrl as upper-case letters}
    external;

  function Scan(Limit : Integer; Ch : Char; T : Pointer) : Integer;
    {-Scan limit chars for Ch; Ch not found if Result=Limit}
    external;

  procedure HelpRoutine(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
    {-Call routine pointed to by MemoHelpPtr}
  inline(
    $FF/$1E/>aeHelpPtr);   {call dword ptr [>aeHelpPtr]}

procedure StatusRoutine(var AECB:TaeControlBlock);
{-Call routine pointed to by aeStatusPtr}
inline(
  $FF/$1E/>aeStatusPtr); {call dword ptr [>aeStatusPtr]}

procedure ErrorRoutine(var AECB :TaeControlBlock; ErrorCode : Word);
{-Call routine pointed to by aeErrorPtr}
inline(
  $FF/$1E/>aeErrorPtr); {call dword ptr [>aeErrorPtr]}

function UserRequestExit(KW:word):boolean;
{-Call routine pointed to aeUserKeyPtr}
inline(
  $FF/$1E/>aeUserKeyPtr);    {call dword ptr [>aeUserKeyPtr]}

function GetAEcmd:word;
var
 KW:word;
 i:TaeCmd;

begin
 KW:=ReadKeyWord;
 GetAEcmd:=KW;

 for i:=firstAEkey to lastAEkey do
   if aeKeySet[i] =KW then begin
     LastCmd:=i;
     exit;
   end;

 { ¬®¦¥â ¡ëâì î§¥p á ¬ íâ® ®¡p ¡®â ¥â? }
 if aeUserKeyPtr <>nil then
   if UserRequestExit(KW) then begin
     LastCmd:=aePass2user;
     exit;
   end;

 { ¬®¦¥â íâ® ¡ãª¢ /æ¨äp /etc? }
 if (lo(KW) =0) or (lo(KW) <$20) then LastCmd:=aeNone
 else LastCmd:=aeChar;
end;

 {$IFDEF UseMouse}
  procedure HideMousePrim(var MouseState : Boolean);
    {-Save state of mouse cursor in MouseState and hide it}
  begin
    MouseState := MouseCursorOn;
    HideMouse;
  end;

  procedure ShowMousePrim(MouseOn : Boolean);
    {-Hide or unhide the mouse cursor}
  begin
    if MouseOn then
      ShowMouse
    else
      HideMouse;
  end;
 {$ENDIF}

  procedure InitBufferState(var AECB :TaeControlBlock;
                            BufferSize : Word; var Buffer);
    {-Initialize the edit buffer status fields in a control block}
  var
    I, J : Word;
    Buf : TaeBuffer absolute Buffer;
  begin
    with AECB do begin
      {reset edit buffer state variables}
      Modified := False;
      BufSize := BufferSize;
      BufPtr := @Buffer;
      BufPos := 1;
      BufPosTop := 1;
       BlkBeg :=0;    {þAD}
       BlkEnd :=0;    {þAD}
       NewLine:=true; {þAD}
      KnownLine := 1;
      KnownOfs := 1;
      CurLine := 1;
      CurCol := 1;
      ColDelta := 0;
      LineAtTop := 1;

      {find end of text buffer}
      I := Search(Buffer, BufferSize, CtrlZ, 1);

      if (I = SearchFailed) or (I = 0) then begin
        {buffer is empty}
        TotalBytes := 1;
        TotalLines := 1;
        Buf[1] := CtrlZ;
      end
      else begin
        TotalBytes := I+1;

        {count total number of rows}
        TotalLines := 1;
        I := 1;
        repeat
          J := Search(Buf[I], Succ(TotalBytes-I), CRLF, 2);
          if J <> SearchFailed then begin
            Inc(TotalLines);
            Inc(I, J+2);
          end;
        until (J = SearchFailed) or (I >= TotalBytes);
      end;
    end;
  end;

  procedure InitControlBlock(var AECB :TaeControlBlock;
                             XLow, YLow, XHigh, YHigh : Byte;
                             TextAttr, CtrlAttr,BlkAttr : Byte;
                             InsertOn, IndentOn, WordWrapOn : Boolean;
                             TabSize : Byte; HelpIndex : Word;
                             RightMargin : Byte; LineLimit : Integer;
                             BufferSize : Word; var Buffer);
    {-Initialize a memo editor control block}
  begin
    with AECB do begin
      XL := XLow;
      YL := YLow;
      XH := XHigh;
      YH := YHigh;
      TAttr := TextAttr;
      CAttr := CtrlAttr;
       BAttr := BlkAttr;        {þAD}
      InsertMode := InsertOn;
      IndentMode := IndentOn;
      ReadOnlyMode := False;
      WordWrap := WordWrapOn;
      TabDelta := TabSize;
      if RightMargin = 0 then
        Margin := Succ(XH-XL)
      else if RightMargin > MaxLineLength then
        Margin := MaxLineLength
      else
        Margin := RightMargin;
      if LineLimit <= 0 then
        MaxLines := MaxInt
      else
        MaxLines := LineLimit;
      HelpTopic := HelpIndex;

      {initialize TotalLines, TotalBytes, etc.}
      InitBufferState(AECB, BufferSize, Buffer);
    end;
  end;

procedure aeStatusLine(var AECB :TaeControlBlock);
{-Display status line}
const
 Ins:array[Boolean] of string[3]=('Ovr','Ins');
 Idn:array[Boolean] of string[3]=('   ','Idn');
 Wrp:array[Boolean] of string[3]=('   ','Wrp');
 Save :array[Boolean] of char =(' ',#15);
 StatusLine:string[80] =
{         1         2         3         4         5         6         7         8}
{12345678901234567890123456789012345678901234567890123456789012345678901234567890}
' Line: xxxxx  Column: xxx  100%                                 Ins³Wrp³Idn   * ';
var
 S:string[5];
 {$IFDEF UseMouse}
 SaveMouse : Boolean;
 {$ENDIF}
begin
 with AECB do begin
   {insert line number}
   S := Long2Str(CurLine);
   S := Pad(S, 5);
   Move(S[1], StatusLine[8], 5);

   {insert column number}
   S := Long2Str(CurCol);
   S := Pad(S, 3);
   Move(S[1], StatusLine[23], 3);

   {insert percentage of buffer used}
   S := Real2Str(Trunc((TotalBytes*100.0)/(BufSize-SafetyMargin)), 3, 0);
   Move(S[1], StatusLine[28], 3);

   {insert remaining fields}
   Move(Ins[InsertMode][1], StatusLine[65], 3);
   Move(Idn[IndentMode][1], StatusLine[73], 3);
   Move(Wrp[WordWrap][1],   StatusLine[69], 3);
   StatusLine[79]:=Save[Modified];

   {$IFDEF UseMouse}
   HideMousePrim(SaveMouse);
   {$ENDIF}

   {display status line}
   FastWrite(StatusLine, StatusRow, 1, StatusAttr);

   {$IFDEF UseMouse}
   ShowMousePrim(SaveMouse);
   {$ENDIF}
 end;
end;

procedure aeSayError(var AECB:TaeControlBlock; ErrorCode : Word);
{-Display error message and wait for key press}
var
  S : string[80];
  I : Word;
  {$IFDEF UseMouse}
  SaveMouse : Boolean;
  {$ENDIF}
begin
  case ErrorCode of
    taBufferFull  :
      S := 'Edit buffer is full';
    taLineTooLong :
      S := 'Line too long, carriage return inserted';
    taTooManyLines :
      S := 'Limit on number of lines has been reached';
    taOverLineLimit :
      S := 'Limit on number of lines has been exceeded';
    else
      S := 'Unknown error';
  end;
  S := S+'. Press any key..';

  {$IFDEF UseMouse}
  HideMousePrim(SaveMouse);
  {$ENDIF}

  {display error message}
  FastWrite(Pad(S, ScreenWidth), ErrorRow, 1, ErrorAttr);

  {$IFDEF UseMouse}
  ShowMousePrim(SaveMouse);
  {$ENDIF}

  {flush the keyboard buffer}
  while KeyPressed do ReadKey;

  {wait for key press}
  I := ReadKeyWord;

  {clear error message line}
  FastWrite(CharStr(' ', ScreenWidth), ErrorRow, 1, ErrorAttr);
end;

function FindLineIndex(var AECB :TaeControlBlock; LineNum : Integer) : Word;
  {-Return the index into the edit buffer for the specified line number}
var
  I : Integer;
begin
  with AECB do begin
    if LineNum = 1 then begin
      KnownLine := 1;
      KnownOfs := 1;
    end
    else if LineNum >= KnownLine then
      while KnownLine < LineNum do begin
        I := Succ(TotalBytes-KnownOfs);
        if I < 0 then
          I := MaxInt;
        Inc(KnownOfs, Succ(Scan(I, ^J, @BufPtr^[KnownOfs])));
        Inc(KnownLine);
      end
    else begin
      {linenum < knownline, search backwards}
      Dec(KnownOfs, 2);
      while KnownLine > LineNum do begin
        I := KnownOfs;
        if I < 0 then
          I := MaxInt;
        Inc(Integer(KnownOfs), Pred(Scan(-I, ^J, @BufPtr^[KnownOfs])));
        Dec(KnownLine);
      end;

      {point to start of next line}
      Inc(KnownOfs, 2);
    end;

    FindLineIndex := KnownOfs;
  end;
end;

function FindLineLength(var AECB:TaeControlBlock; LineNum : Integer) : Word;
  {-Find the length of the specified line}
var
  I, J : Word;
begin
  with AECB do
    if LineNum > TotalLines then
      FindLineLength := 0
    else begin
      {find starting index for line}
      J := FindLineIndex(AECB, LineNum);

      {calculate length}
      I := Search(BufPtr^[J], Succ(TotalBytes-J), CRLF, 2);
      if I = SearchFailed then
        FindLineLength := TotalBytes-J
      else
        FindLineLength := I;
    end;
end;

procedure GetLine(var AECB :TaeControlBlock; var S : string; LineNum : Integer);
  {-Get the LineNum'th line from the buffer for the specified control block,
    and store it in S}
var
  I, J : Word;
  SLen : Byte absolute S;
begin
  with AECB do
    if LineNum > TotalLines then
      SLen := 0
    else begin
      {find starting index and length for line}
      J := FindLineIndex(AECB, LineNum);
      I := FindLineLength(AECB, LineNum);

      {truncate if line is too long}
      if I > 255 then
        SLen := 255
      else
        SLen := I;

      Move(BufPtr^[J], S[1], SLen);
    end;
end;

procedure DrawLine(var AECB :TaeControlBlock; St : String; LineNum : Integer);
  {-Draw the string St, which represents the specified line number}
var
  StLen : Byte absolute St;
  WinWidth : Byte;
   L:integer;                {þAD}
begin
   L:=LineNum;               {þAD}
  {calculate screen row}
  Dec(LineNum, Pred(AECB.LineAtTop));
  Inc(LineNum, Pred(AECB.YL));

  with AECB do begin
    WinWidth := Succ(XH-XL);

    {adjust for ColDelta}
    if (ColDelta > 0) and (StLen > 0) then
      if ColDelta >= StLen then
        StLen := 0
      else begin
        Move(St[ColDelta+1], St[1], StLen-ColDelta);
        Dec(StLen, ColDelta);
      end;
  end;

  {pad the end of the string}
  if StLen < WinWidth then
    FillChar(St[Succ(StLen)], WinWidth-StLen, ' ');

  {change the length}
  StLen := WinWidth;

  {draw the string}
  with AECB do
   if (L>=BlkBeg)and(L<=BlkEnd) then            {þAD}
    FastWrite(St, LineNum, XL, BAttr)           {þAD}
   else
    if CAttr =TAttr then
      FastWrite(St, LineNum, XL, TAttr)
    else
      FastWriteCtrl(St, LineNum, XL, TAttr, CAttr);
end;

function EditBuffer(var AECB:TaeControlBlock;
                    ReadOnly:boolean):TaeCmd;
  {-Edit a buffer filled with text}
{type
  CmdListType = array[1..100] of EMtype;}
var
  ChWord : Word;
  Ch : Char absolute ChWord;
  OldSt, St : string;      {text of current line}
  OldCol : Byte;
  OldModified : Boolean;
  StLen : Byte absolute St;
  I, J : Word;
  CursorSL : Word;
  CursorXY : Word;
  SaveBreak : Boolean;
  ForceRedraw : Boolean;
  DoingChars : Boolean;
  Done, OK : Boolean;
  WinWidth : Byte;
{  EMC : TaeCmd;}
{  UserCmdList : CmdListType absolute CmdList;}
{  NextUserCmd : Word; }
  {$IFDEF UseMouse}
  SaveWaitState : Boolean;
  SaveMouse : Boolean;
  {$ENDIF}

  procedure CallErrorRoutine(Code : Integer);
    {-Call the user-defined error routine}
  begin
    if aeErrorPtr <> nil then
      ErrorRoutine(AECB, Code);
  end;

  procedure TrimSpaces;
    {-Trim trailing blanks from current line}
  begin
    while St[StLen] = ' ' do
      Dec(StLen);
  end;

  function InsertOK(N : Integer) : Boolean;
    {-Return True if OK to insert N bytes into the edit buffer. Calls user
      error handler if not OK.}
  var
    I : LongInt;
  begin
    with AECB do begin
      {allow a safety margin}
      I := TotalBytes+SafetyMargin;

      {calculate actual TotalBytes+N}
      Inc(I, LongInt(N)+(LongInt(StLen)-Length(OldSt)));

      if I <= BufSize then
        InsertOK := True
      else begin
        InsertOK := False;
        CallErrorRoutine(taBufferFull);
      end;
    end;
  end;

  procedure ToggleInsertMode;
    {-Toggle between insert and overtype mode, keeping BIOS keyboard flag up
      to date}
  var
    BiosKbdFlag : Byte absolute $0040 : $0017;
  begin
    with AECB do begin
      {toggle insert flag}
      InsertMode := not InsertMode;

      {use fat cursor if inserting}
      if InsertMode then begin
        FatCursor;
        BiosKbdFlag := BiosKbdFlag or $80;
      end
      else begin
        NormalCursor;
        BiosKbdFlag := BiosKbdFlag and $7F;
      end;
    end;
  end;

  procedure DrawCurrentLine;
    {-Draw the current line}
    {$IFDEF UseMouse}
    var
      SaveMouse : Boolean;
    {$ENDIF}
  begin
    {$IFDEF UseMouse}
    HideMousePrim(SaveMouse);
    {$ENDIF}

    {draw the current line}
    DrawLine(AECB, St, AECB.CurLine);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}
  end;

  procedure RedrawScreen;
    {-Redraw entire screen}
  var
    I, J : Integer;
    S : String;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    {$IFDEF UseMouse}
    HideMousePrim(SaveMouse);
    {$ENDIF}

    with AECB do begin
      J := LineAtTop+(YH-YL);
      for I := LineAtTop to J do begin
        if (I = CurLine) then
          DrawLine(AECB, St, I)
        else begin
          GetLine(AECB, S, I);
          DrawLine(AECB, S, I);
        end;
      end;
    end;

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    ForceRedraw := False;
  end;

  procedure SaveCurrentLine(Trim : Boolean);
    {-Patch the current line back into place}
  var
    I, J : Word;
    K : Integer;
  begin
    with AECB do begin
      if Trim then
        TrimSpaces;
      if St = OldSt then
        Exit;

      {find the actual length of the current line}
      I := BufPos;
      J := FindLineLength(AECB, CurLine);

      {calculate difference in size}
      K := Integer(StLen)-J;

      if K > 0 then
        {make room for new text}
        Move(BufPtr^[I], BufPtr^[I+K], Succ(TotalBytes-I))
      else
        {delete excess characters}
        Move(BufPtr^[I-K], BufPtr^[I], Succ(TotalBytes-I)+K);

      {insert the text}
      Move(St[1], BufPtr^[I], StLen);
      Inc(TotalBytes, K);

      KnownLine := LineAtTop;
      KnownOfs := BufPosTop;
      OldSt := St;
      Modified := True;
      OldModified := True;
    end;
  end;

  procedure ScrollDisplay(Lines : Integer);
    {-Scroll the editing window up or down}
  var
    S : string;
    SaveTextAttr : Byte;
    I, J, K : Integer;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    if Lines = 0 then
      Exit;
    with AECB do begin
      SaveTextAttr := TextAttr;
      TextAttr := TAttr;

      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      if Lines < 0 then
        ScrollWindowDown(XL, YL, XH, YH, -Lines)
      else
        ScrollWindowUp(XL, YL, XH, YH, Lines);

      BufPosTop := FindLineIndex(AECB, LineAtTop+Lines);
      Inc(LineAtTop, Lines);

      if Lines < 0 then begin
        J := LineAtTop;
        K := Pred(J-Lines);
      end
      else begin
        J := LineAtTop+(YH-YL)-Pred(Lines);
        K := Pred(J+Lines);
      end;

      {draw the line(s) replacing the one(s) that scrolled off}
      for I := J to K do begin
        GetLine(AECB, S, I);
        DrawLine(AECB, S, I);
      end;

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}

      TextAttr := SaveTextAttr;
    end;
  end;

  function TooManyLinesCheck : Boolean;
    {-Check to see if there are too many lines}
  begin
    with AECB do
      if Word(TotalLines) >= Word(MaxLines) then begin
        CallErrorRoutine(taTooManyLines);
        OK := False;
        TooManyLinesCheck := True;
      end
      else
        TooManyLinesCheck := False;
  end;

  procedure InsLinePrim(LineNum, Col : Integer);
    {-Primitive routine to insert a line break}
  var
    I, J : Word;
  begin
    with AECB do begin
      if TooManyLinesCheck then
        Exit;

      {find the place to insert the line break}
      I := FindLineIndex(AECB, LineNum)+Pred(Col);

      {see if we need to trim some blanks}
      J := Pred(I);
      while (J > 0) and (BufPtr^[J] = ' ') do
        Dec(J);
      Inc(J);

      if J <> I then begin
        {see if there's room}
        OK := InsertOK(2-(I-J));
        if not OK then
          Exit;

        {make room for a CRLF}
        Move(BufPtr^[I], BufPtr^[J+2], Succ(TotalBytes-I));

        {insert the CRLF}
        Move(CRLF, BufPtr^[J], 2);

        {adjust counters}
        Inc(TotalLines);
        TotalBytes := (TotalBytes+2)-(I-J);
      end
      else begin
        {see if there's room}
        OK := InsertOK(2);
        if not OK then
          Exit;

        {make room for a CRLF}
        Move(BufPtr^[I], BufPtr^[I+2], Succ(TotalBytes-I));

        {insert the CRLF}
        Move(CRLF, BufPtr^[I], 2);

        {adjust counters}
        Inc(TotalLines);
        Inc(TotalBytes, 2);
      end;

      OldModified := True; {!!.10}
      Modified := True;

      NewLine:=true;             {ÄÄÄAD}

      if BlkBeg >0 then
      begin
       if (LineNum <BlkBeg)or(LineNum =BlkBeg)and(Col=1) then Inc(BlkBeg);
       if BlkEnd >=LineNum then Inc(BlkEnd);
      end;                       {ÄÄÄAD}

    end;
  end;

  procedure LoadLine(LineNum : Integer; Truncate : Boolean);
    {-Load the specified line}
  var
    I, J, K, N, Max : Word;
  begin
    with AECB do begin
      {find the line we're moving to}
      BufPos := FindLineIndex(AECB, LineNum);
      CurLine := LineNum;

      {find the length of the line}
      I := FindLineLength(AECB, LineNum);

      {calc max length of line}
      if Truncate then
        Max := MaxLineLength
      else
        Max := 255;

      {insert carriage return if line is too long}
      if I > Max then begin
        {determine where to break the line}
        K := Max;
        N := FindLineIndex(AECB, LineNum);
        J := N+Pred(K);
        while (J > N) and (BufPtr^[J] <> ' ') do begin
          Dec(J);
          Dec(K);
        end;
        if J = N then
          K := Max;

        {try to break the line}
        Inc(MaxLines);
        InsLinePrim(LineNum, K);
        Dec(MaxLines);

        if not OK then begin
          {something overflowed--force the line break}
          Inc(N, K);
          BufPtr^[N] := ^M;
          BufPtr^[N+1] := ^J;
          Inc(TotalLines);
        end;

        {report the break}
        CallErrorRoutine(taLineTooLong);

        {force screen to be redrawn}
        ForceRedraw := True;

        {recalculate the length}
        I := FindLineLength(AECB, LineNum);
      end;

      {load the line into St and OldSt}
      StLen := I;
      Move(BufPtr^[BufPos], St[1], StLen);
      OldSt := St;
      OldCol := CurCol;
      Modified := OldModified;
    end;
  end;

  procedure GotoLine(LineNum : Integer; Trim : Boolean);
    {-Save the current line and move the cursor to the LineNum'th line}
  var
    I : Word;
  begin
    with AECB do begin
      {don't go too far}
      if LineNum > TotalLines then
        LineNum := TotalLines;

      {save the line we've been editing}
      SaveCurrentLine(Trim);

      {scroll the display if necessary}
      if LineNum < LineAtTop then
        ScrollDisplay(LineNum-LineAtTop)
      else begin
        I := LineAtTop+(YH-YL);
        if LineNum > I then
          ScrollDisplay(LineNum-I);
      end;

      {load the line}
      LoadLine(LineNum, Trim);

       NewLine:=true;          {þAD}
    end;
  end;

  procedure DelLinePrim(LineNum : Integer);
    {-Primitive routine to delete a line}
  var
    I, J : Word;
  begin
    with AECB do begin
      {find the line we're deleting}
      I := FindLineIndex(AECB, LineNum);

      {find the length of the line}
      J := Search(BufPtr^[I], Succ(TotalBytes-I), CRLF, 2);
      if J = SearchFailed then
        J := TotalBytes-BufPos
      else
        Inc(J, 2);

      {delete it}
      Move(BufPtr^[I+J], BufPtr^[I], Succ(TotalBytes-I)-J);
      Dec(TotalLines);
      if TotalLines = 0 then begin
        TotalLines := 1;
        TotalBytes := 1;
        BufPtr^[1] := ^Z;
      end
      else
        Dec(TotalBytes, J);

      Modified := True;
      OldModified := True;

      NewLine:=true;        {ÄÄÄAD}

      if BlkBeg >0 then
       if (LineNum=BlkBeg)and(LineNum=BlkEnd) then
       begin
        BlkBeg:=0;
        BlkEnd:=0;
       end
       else
       begin
        if LineNum <BlkBeg then Dec(BlkBeg);
        if LineNum <=BlkEnd then Dec(BlkEnd);
       end;                 {ÄÄÄAD}

    end;
  end;

  procedure JoinLinePrim(LineNum : Integer);
    {-Primitive routine to join two lines}
  var
    I : Word;
  begin
    with AECB do begin
      {find the place to join the lines}
      I := FindLineIndex(AECB, LineNum);

      {delete CRLF}
      Move(BufPtr^[I], BufPtr^[I-2], Succ(TotalBytes-I));

      Dec(TotalLines);
      Dec(TotalBytes, 2);
      BufPtr^[TotalBytes+1] := ^Z;

      Modified := True;
      OldModified := True;

      NewLine:=true;                           {ÄÄÄAD}

      if BlkBeg >0 then
       if (LineNum=BlkBeg)and(LineNum=BlkEnd) then
       begin
        BlkBeg:=0;
        BlkEnd:=0;
       end
       else
       begin
        if LineNum <=BlkBeg then Dec(BlkBeg);
        if LineNum <=BlkEnd then Dec(BlkEnd);
       end;                                    {ÄÄÄAD}

    end;
  end;

  procedure PutLineAtTop(LineNum : Integer);
    {-Position the specified line at top of editing window}
  begin
    with AECB do begin
      if LineNum < 1 then
        LineNum := 1
      else if LineNum > TotalLines then
        LineNum := TotalLines;
      SaveCurrentLine(True); {!!}
      BufPosTop := FindLineIndex(AECB, LineNum);
      LineAtTop := LineNum;
      RedrawScreen;
    end;
  end;

  function GetIndent(S : string) : Byte;
    {-Get the indentation level of S}
  var
    I : Word;
    SLen : Byte absolute S;
  begin
    I := 0;
    while S[SLen] = ' ' do
      Dec(SLen);
    while (I < SLen) and (S[I+1] = ' ') do
      Inc(I);
    GetIndent := I;
  end;

  procedure JustifyStr(var S:string);
  var
   ns,  {-áª®«ìª® ¯p®¡¥«®¢ ¬¥¦¤ã ¢á¥¬¨ á«®¢ ¬¨}
   ds,  {-áª®«ìª® ¯¥p¢ëå á«®¢ á ¤®¯.¯p®¡¥« ¬¨}
   i:byte;
   nw:integer;
   sx,ss:string;
   HowIdn:byte;
   oops:boolean;
   Sl:byte absolute S;

  begin
   nw:=1;
   oops:=false;
   ss:='';

   if s[1] =' ' then
     HowIdn:=Sl-Length(TrimLead(s))
   else
     HowIdn:=0;

   repeat
    sx:=ExtractWord(nw,s,[' ']);
    if Length(sx) <>0 then ss:=ss+sx+' '
    else oops:=true;
    Inc(nw);
   until oops;

   ss:=Pad('',HowIdn)+TrimTrail(ss);
   Dec(nw,3);

   if (Length(ss) <AECB.Margin) and (nw >1) then begin
     S:=Pad('',HowIdn);
     ns:=succ(AECB.Margin-Length(ss)) div nw; {ª-¢® ¯p®¡¥«®¢ ¬¥¦¤ã á«®¢ ¬¨}
     ds:=succ(AECB.Margin-Length(ss)) mod nw; {ª-¢® ¯p®¬¥¦ãâª®¢ á ¤®¯.¯p®¡¥« ¬¨}

     for i:=1 to succ(nw) do begin
      S:=S+ExtractWord(i,ss,[' '])+' '+CharStr(' ',ns);
    if i<=ds then S:=S+' ';
   end;

   Dec(Sl);
   exit;
   end;

   S:=ss;
  end;

  procedure WrapLine(Trim:boolean);
  {-Word wrap the current line}
  var
   I:integer;
   Temp,SaveSt:string;

  begin
    with AECB do begin
      if TooManyLinesCheck then exit;

      SaveSt := St;
      Tstring_.WordWrap(St, St, Temp, Margin, False);

      if IndentMode then begin
        I:=GetIndent(St);
        if I <>0 then
          Insert(CharStr(' ', I), Temp,1);
      end;

      JustifyStr(St);

      I:=Length(Temp)-(Length(SaveSt)-CurCol);
      if I < 1 then
        I := 1;
      SaveCurrentLine(True);
      DrawCurrentLine;
      InsLinePrim(CurLine, StLen+1);
      if OK then begin
        GotoLine(CurLine+1, Trim);
        St := Temp;
        SaveCurrentLine(True);
        ColDelta := 0;
        CurCol := I;
        OldCol := I;
      end
      else begin
        St := SaveSt;
        SaveCurrentLine(True);
      end;
    end;
  end;

  procedure ReformatParagraph;
   {-Reformat a paragraph starting at the current line}
    var
      SaveMax, I : Integer;
    begin
      with AECB do begin
        SaveCurrentLine(True);

        if StLen = 0 then begin
          GotoLine(CurLine+1, True);
          Exit;
        end;

        {ignore line limit when reformatting}
        SaveMax := MaxLines;
        MaxLines := MaxInt;

        while (CurLine < TotalLines) and (OK = True) do begin
          while (StLen > Margin) and OK do
            WrapLine(False);
          if OK then
            OK := FindLineLength(AECB, CurLine+1) <> 0;
          if OK and IndentStartsParagraph then
            OK := BufPtr^[KnownOfs] <> ' ';

          if OK then begin
            Inc(StLen);
            St[StLen] := ' ';
            I := Succ(StLen);
            SaveCurrentLine(False);
            JoinLinePrim(CurLine+1);
            LoadLine(CurLine, False);
            while (I < StLen) and (St[I] = ' ') do
              Delete(St, I, 1);
            TrimSpaces;
          end;
        end;

        OK := True;
        while (StLen > Margin) and OK do
          WrapLine(False);

        RedrawScreen;
        GotoLine(CurLine+1, True);
        if CurLine = TotalLines then
          CurCol := Succ(StLen)
        else
          CurCol := 1;
        OldCol := CurCol;
        MaxLines := SaveMax;
      end;
    end;

    procedure DeleteWordPrim;
      {-Primitive routine to delete a word}
    var
      DelEnd : Word;
    begin
      with AECB do begin
        if CurCol > StLen then
          Exit;

        {start deleting at the cursor}
        DelEnd := CurCol;

        {delete all of the current word, if any}
        if St[CurCol] <> ' ' then
          while (St[DelEnd] <> ' ') and (DelEnd <= StLen) do
            Inc(DelEnd);

        {delete any spaces prior to the next word, if any}
        while (St[DelEnd] = ' ') and (DelEnd <= StLen) do
          Inc(DelEnd);

        Delete(St, CurCol, DelEnd-CurCol);
      end;
    end;

    procedure JoinAtEndOfLine;
      {-Join the following line with the current one at the cursor}
    begin
      with AECB do
        if (CurLine < TotalLines) and InsertOK(CurCol-StLen) then begin
          FillChar(St[Succ(StLen)], CurCol-StLen, ' ');
          StLen := Pred(CurCol);
          I := CurCol;
          SaveCurrentLine(False);
          JoinLinePrim(CurLine+1);
          LoadLine(CurLine, True);
          CurCol := I;
          ForceRedraw := True;
          OldCol := CurCol;
        end;
    end;

    {$IFDEF UseMouse}

    procedure MouseSelect;
      {-Move cursor to position of mouse}
    var
      CurRow, TargetLine : Integer;
      TargetRow, TargetCol : Integer;
    begin
      {convert mouse X and Y coordinates to absolute row and col}
      TargetRow := MouseKeyWordY+MouseYLo;
      TargetCol := MouseKeyWordX+MouseXLo;

      with AECB do
        {make sure mouse is within edit window}
        if (TargetCol >= XL) and (TargetCol <= XH)
        and (TargetRow >= YL) and (TargetRow <= YH) then begin
          {calculate current screen row}
          CurRow := Word(YL)+(CurLine-LineAtTop);

          {calculate target line number}
          TargetLine := CurLine+(TargetRow-CurRow);

          if TargetLine <= TotalLines then begin
            {move cursor to desired location}
            CurCol := TargetCol-Pred(XL)+ColDelta;
            GotoLine(TargetLine, True);
          end;
        end;
    end;

    {$ENDIF}

    procedure TopOfFile;
      {-Reset for top of file}
    begin
      with AECB do begin
        PutLineAtTop(1);
        GotoLine(1, True);
        CurCol := 1;
        OldCol := 1;
        RedrawScreen;
      end;
    end;

    procedure ReformatGlobally;
      {-Reformat entire file}
    begin
      with AECB do begin
        {skip all this if the file is empty}
        if TotalBytes = 1 then
          Exit;

        {go to top of file}
        TopOfFile;

        {while not at last line, reformat paragraphs}
        while CurLine < TotalLines do
          ReformatParagraph;
      end;
    end;

    procedure CheckLineLimit;
      {-Display error message if line limit exceeded}
    begin
      with AECB do
        if TotalLines > MaxLines then begin
          RedrawScreen;
          CallErrorRoutine(taOverLineLimit);
        end;
    end;

  begin {ÛEditMemo}
    with AECB do begin
      {Store cursor position and shape}
      GetCursorState(CursorXY, CursorSL);

      {Save break checking state}
      SaveBreak := CheckBreak;
      CheckBreak := False;

      {set cursor shape}
      InsertMode := not InsertMode;
      ToggleInsertMode;

      {initialize miscellaneous variables}
      WinWidth := Succ(XH-XL);
{      NextUserCmd := 1;}
      KnownLine := 1;
      KnownOfs := 1;
      OldModified := Modified;
      ReadOnlyMode := ReadOnly;

      {$IFDEF UseMouse}
      SaveMouse := MouseCursorOn;
      {$ENDIF}

      {get the first line}
      LoadLine(AECB.CurLine, True);

      {draw whole screen}
      ForceRedraw := True;

      {see if we exceeded the line limit}
      CheckLineLimit;

      {loop while reading keys}
      Done := False;
      DoingChars := False;
      repeat
        OK := True;

        {update screen}
        if CurCol > MaxLineLength+1 then
          CurCol := MaxLineLength+1;
        if CurCol > WinWidth+ColDelta then begin
          ColDelta := CurCol-WinWidth;
          RedrawScreen;
        end
        else if CurCol < Succ(ColDelta) then begin
          ColDelta := Pred(CurCol);
          RedrawScreen;
        end
        else if ForceRedraw then
          RedrawScreen
        else
          DrawCurrentLine;

        {position cursor}
        GoToXYAbs(XL+Pred(CurCol)-ColDelta, YL+(CurLine-LineAtTop));

        {set modified flag}
        TrimSpaces;
        Modified := OldModified or (St <> OldSt);

        {display status line}
        if aeStatusPtr <> nil then begin
          {update TotalBytes field for status routine}
          J := TotalBytes;
          Inc(TotalBytes, Integer(StLen)-Length(OldSt));

          {call status routine}
          StatusRoutine(AECB);

          {reset TotalBytes field}
          TotalBytes := J;
        end;

        {$IFDEF UseMouse}
        if MemoMouseEnabled then begin
          SaveWaitState := WaitForButtonRelease;
          WaitForButtonRelease := True;
        end;
        {$ENDIF}

        {see if there is a user command left to process}
(*
        EMC := UserCmdList[NextUserCmd];
        if DoingChars then begin
          if EMC = EMchar then begin
            {EMchar acts as toggle}
            EMC := EMnone;
            DoingChars := False;
          end
          else begin
            {treat the command as a character}
            Ch := Char(EMC);
            EMC := EMchar;
          end;
          Inc(NextUserCmd);
        end
        else
         if EMC = EMnone then
           {read from the keyboard}
           EMC := GetCommand(MemoKeySet, MemoKeyPtr, ChWord)
         else begin
          {process next user command}
          Inc(NextUserCmd);
          if EMC = EMchar then begin
            DoingChars := True;
            EMC := EMnone;
          end;
         end;
*)
        ChWord:=GetAEcmd;    {Anton`s Editor Keyboard processor}

        {make sure command is allowable if in read-only mode
        if ReadOnlyMode then
          if EMC in DisallowedInReadOnlyMode then
            EMC :=aeNone;}

        {reinterpret potentially troublesome control characters}
        if LastCmd =aeChar then
          case Ch of
            ^M : LastCmd := aeEnter;
            ^J, ^Z : LastCmd := aeNone;
          end;

        {$IFDEF UseMouse}
        if MemoMouseEnabled then
          WaitForButtonRelease := SaveWaitState;
        {$ENDIF}

        {deal with control characters if desired}
        if LastCmd =aeCtrlChar then
          {don't allow control characters if attributes are the same}
          if (CAttr = TAttr) then
            LastCmd:=aeNone
          else begin
            BlockCursor;
            ChWord:=ReadKeyWord;
            LastCmd:=aeChar;
            if InsertMode then
              FatCursor
            else
              NormalCursor;
          end;

        case LastCmd of
          aeChar :             {A character to enter the string}
            if CurCol <= MaxLineLength then begin
              if CurCol > StLen then
                FillChar(St[Succ(StLen)], CurCol-StLen, ' ');

              if not InsertMode then begin
                {overtype mode}
                if (CurCol <= MaxLineLength) then begin
                  St[CurCol] := Ch;
                  if (Ch <> ' ') and (CurCol > StLen) then begin {!!.12}
                    if InsertOK(CurCol-StLen) then begin         {!!.12}
                      StLen := CurCol;                           {!!.12}
                      Inc(CurCol);                               {!!.12}
                    end;                                         {!!.12}
                  end                                            {!!.12}
                  else                                           {!!.12}
                    Inc(CurCol);                                 {!!.12}
                end;
              end
              else if StLen < MaxLineLength then begin
                {insert mode}
                if CurCol > StLen then begin
                  if Ch = ' ' then
                    Inc(CurCol)
                  else if InsertOK(CurCol-StLen) then begin
                    StLen := CurCol;
                    St[CurCol] := Ch;
                    Inc(CurCol);
                  end;
                end
                else if InsertOK(1) then begin
                  Insert(Ch, St, CurCol);
                  Inc(CurCol);
                end;
              end;

              if WordWrap and (CurCol > Margin) and (StLen > Margin) then begin
                WrapLine(True);
                ForceRedraw := True;
              end;
            end;

          aeEnter :            {new line}
            begin
              I := GetIndent(St);
              if InsertMode then begin
                if IndentMode and (CurCol <= StLen) and (I > 0) then
                  Insert(CharStr(' ', I), St, CurCol);
                SaveCurrentLine(True);
                if CurCol > StLen then
                  CurCol := Succ(StLen);
                InsLinePrim(CurLine, CurCol);
              end;

              if OK then begin
                GotoLine(CurLine+1, True);
                if IndentMode and InsertMode then
                  CurCol := Succ(I)
                else
                  CurCol := 1;
                OldCol := CurCol;
                if InsertMode then
                  ForceRedraw := True;
              end;
            end;

          aePass2user,   {user-defined exit commands}
          aeQuit :       {exit from editor}
            begin
              SaveCurrentLine(True);
              Done:=true;
            end;

          aeHome : CurCol := 1;          {Cursor to beginning of line}

          aeEnd : CurCol := Succ(StLen); {Cursor to end of line}

          aeDelEOL :           {Delete from cursor to end of line}
            if StLen >= CurCol then StLen := Pred(CurCol);

          aeDelLine :          {Delete entire line}
            if CurLine = TotalLines then begin
              StLen := 0;
              CurCol := 1;
              SaveCurrentLine(True);
            end
            else begin
              DelLinePrim(CurLine);
              CurCol := 1;
              LoadLine(CurLine, True);
              ForceRedraw := True;
            end;

          aeRestore :          {Restore default and continue}
            begin
              St := OldSt;
              CurCol := OldCol;
            end;

          aeLeft :             {Cursor left by one character}
            if CurCol > 1 then
              Dec(CurCol);

          aeRight :            {Cursor right by one character}
            Inc(CurCol);

          aeUp :               {Cursor up one line}
            if CurLine > 1 then
              GotoLine(CurLine-1, True);

          aeDown :             {Cursor down one line}
            if CurLine < TotalLines then
              GotoLine(CurLine+1, True);

          aeScrollUp :         {Scroll display up one line}
            if LineAtTop > 1 then begin
              SaveCurrentLine(True);  {!!.10}
              ScrollDisplay(-1);
              I := LineAtTop+(YH-YL);
              if CurLine > I then
                GotoLine(I, True);
            end;

          aeScrollDown :       {Scroll display down one line}
            if LineAtTop < TotalLines then begin
              SaveCurrentLine(True);  {!!.10}
              ScrollDisplay(1);
              if CurLine < LineAtTop then
                GotoLine(LineAtTop, True);
            end;

          aePageUp :           {Scroll display up one page}
            if LineAtTop > 1 then begin
              I := (YH-YL);
              if I > CurLine then begin
                PutLineAtTop(1);
                GotoLine(1, True);
              end
              else begin
                J := CurLine-LineAtTop;
                PutLineAtTop(LineAtTop-I);
                GotoLine(LineAtTop+J, True);
              end;
            end
            else
              GotoLine(1, True);

          aePageDown :         {Scroll display down one page}
            begin
              I := Succ(YH-YL);
              if (TotalLines > I) or not ReadOnlyMode then
                if LineAtTop < TotalLines then begin
                  if TotalLines <= I then begin
                    PutLineAtTop(TotalLines);
                    GotoLine(TotalLines, True);
                  end
                  else begin
                    J := CurLine-LineAtTop;
                    PutLineAtTop(LineAtTop+Pred(I));
                    GotoLine(LineAtTop+J, True);
                  end;
                end;
            end;

          aeScreenTop :        {Cursor to top of screen}
            GotoLine(LineAtTop, True);

          aeScreenBot :        {Cursor to bottom of screen}
            GotoLine(LineAtTop+(YH-YL), True);

          aeTopOfFile : TopOfFile;  {Cursor to top of file}

          aeEndOfFile :        {Cursor to bottom of file}
            begin
              I := YH-YL;
              if CurLine < TotalLines-I then
                PutLineAtTop(TotalLines-I);
              GotoLine(TotalLines, True);
              CurCol := Succ(StLen);
              OldCol := CurCol;
            end;

          aeTab :              {Tab}
            begin
              I := Succ(Succ(Pred(CurCol) div TabDelta) * TabDelta);
              if (not InsertMode) or (CurCol > StLen) then
                CurCol := I
              else if (CurCol <= StLen) then begin
                if InsertOK(I-CurCol) and (Margin-StLen > I-CurCol) then begin
                  Insert(CharStr(' ', I-CurCol), St, CurCol);
                  CurCol := I;
                end;
              end
            end;

          aeWordLeft :         {Cursor left one word}
            if CurCol > 1 then begin
              Dec(CurCol);
              while (CurCol >= 1) and ((CurCol > StLen) or (St[CurCol] = ' ')) do
                Dec(CurCol);
              while (CurCol >= 1) and (St[CurCol] <> ' ') do
                Dec(CurCol);
              Inc(CurCol);
            end
            else if CurLine > 1 then begin
              GotoLine(CurLine-1, True);
              CurCol := Succ(StLen);
              OldCol := CurCol;
            end;

          aeWordRight :        {Cursor right one word}
            begin
              if CurCol <= StLen then begin
                Inc(CurCol);
                while (CurCol <= StLen) and (St[CurCol] <> ' ') do
                  Inc(CurCol);
                while (CurCol <= StLen) and (St[CurCol] = ' ') do
                  Inc(CurCol);
              end
              else if CurLine < TotalLines then begin
                GotoLine(CurLine+1, True);
                CurCol := 1;
                OldCol := 1;
              end;
            end;

          aeDel :              {Delete current character}
            if CurCol <= StLen then
              Delete(St, CurCol, 1)
            else if DeleteJoinsLines then
              JoinAtEndOfLine;

          aeBack :             {Backspace one character}
            if CurCol > 1 then begin
              Dec(CurCol);
              Delete(St, CurCol, 1);
            end
            else if CurLine > 1 then begin
              GotoLine(CurLine-1, True);
              CurCol := Succ(StLen);
              JoinLinePrim(CurLine+1);
              LoadLine(CurLine, True);
              ForceRedraw := True;
              OldCol := CurCol;
            end;

          aeDelWord :          {Delete word to right of cursor}
            if CurCol <= StLen then
              DeleteWordPrim
            else
              JoinAtEndOfLine;

          aeIns : ToggleInsertMode;       {Toggle insert mode}


          aeIndent : IndentMode := not IndentMode; {Toggle auto-indent mode}


          aeWordWrap : WordWrap := not WordWrap;  {Toggle word wrap}


          aeReformatP :        {Reformat paragraph}
            if WordWrap then begin {!!.10}
              ReformatParagraph;
              CheckLineLimit;
            end;

          aeReformatG :        {Global reformat}
            if WordWrap then begin {!!.10}
              ReformatGlobally;
              CheckLineLimit;
            end;

          {$IFDEF UseMouse}

          aeMouse :            {Mouse select}
            if MemoMouseEnabled then
              MouseSelect;

          {$ENDIF}

          aeHelp :             {Help}
            if aeHelpPtr <> nil then
              HelpRoutine(HelpForMemo, @AECB, HelpTopic);
        end;

      until Done;

      {redraw the screen one last time}
      RedrawScreen;

      {restore break checking status}
      CheckBreak := SaveBreak;

      {Restore cursor position and shape}
      RestoreCursorState(CursorXY, CursorSL);

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}

      {return exit code}
      EditBuffer:=LastCmd;
    end;
  end;

(*
  {$IFDEF UseMouse}
  procedure EnableMemoMouse;
    {-Enable mouse support in TPMEMO}
  begin
    if MouseInstalled and not MemoMouseEnabled then begin
      MemoKeyPtr := @ReadKeyOrButton;
      EnableEventHandling;
      MemoMouseEnabled := True;
    end;
  end;

  procedure DisableMemoMouse;
    {-Disable mouse support in TPMEMO}
  begin
    if MemoMouseEnabled then begin
      MemoKeyPtr := @ReadKeyWord;
      DisableEventHandling;
      MemoMouseEnabled := False;
    end;
  end;
  {$ENDIF}
*)

  function ReadTextFile(var Buffer; BufferSize : Word;
                        FName : string; var FSize : LongInt) : aeStatusType;
    {-Read a file into Buffer, returning a status code}
  var
    Buf : array[1..65521] of Char absolute Buffer;
    F : file;
    I, BytesRead, BytesToRead : Word;
    MaxSize : LongInt;
  begin
    ReadTextFile := aestNotFound;
    FSize := 0;
    Buf[1] := ^Z;
    if Length(FName) = 0 then
      Exit;

    {try to open file}
    Assign(F, FName);
    Reset(F, 1);
    I := IoResult;

    {check for invalid pathname}
    if I = 3 then
      ReadTextFile := aestInvalidName;

    if I <> 0 then
      Exit;

    {check the file size}
    FSize := FileSize(F);
    MaxSize := LongInt(BufferSize)-Succ(SafetyMargin);
    if (FSize <= MaxSize) then
      BytesToRead := FSize
    else if AllowTruncation then
      BytesToRead := MaxSize
    else begin
      {file too big}
      ReadTextFile := aestTooLarge;
      Close(F);
      I := IoResult;
      Exit;
    end;

    {read the file into the buffer}
    BlockRead(F, Buf, BytesToRead, BytesRead);
    if (BytesRead <> BytesToRead) then begin
      ReadTextFile := aestReadError;
      Close(F);
      I := IoResult;
    end
    else begin
      Close(F);
      if IoResult = 0 then
        if FSize > MaxSize then
          ReadTextFile := aestTruncated
        else
          ReadTextFile := aestOK
      else
        ReadTextFile := aestCloseError;
    end;

    {make sure there's a ^Z at the end of the buffer}
    Buf[BytesToRead+1] := ^Z;
  end;

  function SaveTextFile(var AECB:TaeControlBlock; FName : string;
                        MakeBackup : Boolean):aeStatusType;
    {-Save the current file in the text buffer associated with AECB}
  var
    F : file;
    I, BytesWritten : Word;

    function Exist(FName : string; var F : file) : Boolean;
      {-Return true and assigned file handle if file exists}
    var
      I : Word;
    begin
      Assign(F, FName);
      Reset(F);
      Exist := (IoResult = 0);
      Close(F);
      I := IoResult;
    end;

    procedure MakeBakFile(NewName : string);
      {-Make a backup file}
    var
      NF, BF : file;
      BakName : string;
    begin
      if Exist(NewName, NF) then begin
        BakName := ForceExtension(NewName, 'BAK');
        if Exist(BakName, BF) then
          Erase(BF);
        Rename(NF, BakName);
      end;
    end;

  begin
    with AECB do begin
      if MakeBackup then
        MakeBakFile(FName);

      Assign(F, FName);
      Rewrite(F, 1);
      if IoResult <> 0 then begin
        SaveTextFile:=aestCreationError;
        Close(F);
        I := IoResult;
        Exit;
      end;
                            {vvv--not save ^Z marker!}
      BlockWrite(F, BufPtr^, pred(TotalBytes), BytesWritten);
      if (BytesWritten <> pred(TotalBytes)) or (IoResult <> 0) then begin
        SaveTextFile := aestWriteError;
        Close(F);
        Exit;
      end;

      Close(F);
      if IoResult <> 0 then begin
        SaveTextFile := aestCloseError;
        Exit;
      end;

      {reset modified flag}
      Modified := False;

      SaveTextFile := aestOK;
    end;
  end;

begin
 aeUserKeyPtr:=nil;
end.
