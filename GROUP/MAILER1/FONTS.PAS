Unit Fonts;
{ Copyright (c) 1994 by Andrew Eigus  Fidonet: 2:5100/33 }

(*
  This unit provides EGA/VGA font management routines and enables you
  to save/restore characters or charsets and also makes it easy for you
  to set your own (custom) characters or charsets in EGA/VGA modes

  8x8 font:  for EGA 80x43 or VGA 80x50 modes,
  8x14 font: for EGA 80x25 mode,
  8x16 font: for VGA 80x25 mode
*)

interface

type
  { 8x8 font table type }
  P8x8Charset = ^T8x8Charset;
  T8x8Charset = array[0..255, 1..8] of Byte;

  { 8x14 font table type }
  P8x14Charset = ^T8x14Charset;
  T8x14Charset = array[0..255,1..14] of Byte;

  { 8x16 font table type }
  P8x16Charset = ^T8x16Charset;
  T8x16Charset = array[0..255, 1..16] of Byte;

const
  { ROM table pointer request codes to use with #SaveROMFont#: }

  reqInt1F = 0; { return current Int 1Fh graphics font address }
  reqInt44 = 1; { return current Int 44h graphics font address }
  req8x14  = 2; { return ROM 8x14 font table address }
  req8x8   = 3; { return ROM 8x8 double dot font table address }
  req8x8t  = 4; { return ROM 8x8 double dot address (top) }
  req9x14  = 5; { return ROM 9x14 alternate table address }
  req8x16  = 6; { return ROM 8x16 font table address }


function EGAInstalled : boolean;
{ Determines whether EGA/VGA is installed or not. If EGA/VGA is installed,
  True is returned and you may freely use all of those routines in this
  unit.

  See also #GetScanLines# }

function GetScanLines : byte;
{ Performs auto detection of scan lines per one character in active video
  mode.

  for 80x43 EGA or 80x50 VGA mode - 8,
  for 80x25 EGA mode - 14,
  and
  for 80x25 VGA mode - 16 }

procedure SaveCharset(var Buffer; StartChar, Count, ScanLines : word);
{ Saves Count characters from video memory into Buffer starting with
  StartChar ASCII code and using the ScanLines number for each character
  matrix. To determine number of scan lines in active video font,
  use function #GetScanLines#. (see #SaveFont# procedure) }

procedure LoadCharset(var Buffer; StartChar, Count, ScanLines : word);
{ Loads Count characters from Buffer into video memory starting with
  StartChar ASCII code and using the ScanLines for each character matrix.
  To determine number of scan lines in active video font,
  use function #GetScanLines#. (see #LoadFont# procedure) }

procedure LoadROMCharset(var Buffer; StartChar, Count, ScanLines : word);
{ Loads Count characters from ROM charset into video memory starting with
  StartChar ASCII code and using the ScanLines for each character matrix.
  To determine number a number of scan lines in active video font,
  use function #GetScanLines#. }

procedure SaveROMFont(var Font; Code : byte);
{ Saves ROM font table into Buffer for the specified table pointer
  request code. See ROM table pointer request codes for more information. }

procedure SaveFont(var Font; ScanLines : byte);
{ Saves the whole active video font into Buffer and uses the value of
  ScanLines to calculate the font size. }

procedure LoadFont(var Font; ScanLines : byte);
{ Loads the whole into video memory and uses the value of
  ScanLines to calculate the font size. }


implementation

Procedure OpenRegs; near; assembler;
{ This is used internally and required by the unit }
Asm
  cli
  mov dx,03C4h
  mov ax,0402h
  out dx,ax
  mov ax,0704h
  out dx,ax
  mov dl,0CEh { port 03CEh }
  mov ax,0204h
  out dx,ax
  mov ax,0005h
  out dx,ax
  mov ax,0406h
  out dx,ax
End; { OpenRegs }

Procedure CloseRegs; near; assembler;
{ This is used internally and required by the unit. }
Asm
  mov dx,03C4h
  mov ax,0302h
  out dx,ax
  mov ax,0304h
  out dx,ax
  mov dl,0CEh { port 03CEh }
  mov ax,0004h
  out dx,ax
  mov ax,1005h
  out dx,ax
  mov es,Seg0040
  mov ax,0E06h
  cmp byte ptr es:[0049h],07h
  jne @color
  mov ax,0A06h
@color:
  out dx,ax
  sti
End; { CloseRegs }

Function EGAInstalled; assembler;
Asm
  mov ax,1200h
  mov bx,0010h
  xor cx,cx
  int 10h
  xor al,al { mov al,False }
  or  cx,0  { still cx the same? yes, there's no EGA }
  jz  @noega
  inc al { al gets True }
@noega:
End; { EGAInstalled }

Function GetScanLines; assembler;
Asm
  mov es,Seg0040
  mov al,byte ptr es:[0085h]
End; { GetScanLines }

Procedure SaveCharset; assembler;
Asm
  call OpenRegs
  push ds
  mov ax,SegA000
  mov ds,ax
  mov ax,StartChar
  mov bx,32
  mul bx
  mov si,ax
  les di,Buffer
  cld
  mov ax,Count
  mul bx
  mov dx,ScanLines
@@1:
  mov cx,dx
  rep movsb
  mov cx,bx
  sub cx,dx
  add si,cx
  sub ax,bx
  cmp ax,0
  jnz @@1
  pop ds
  call CloseRegs
End; { SaveCharset }

Procedure LoadCharset; assembler;
Asm
  call OpenRegs
  push ds
  mov es,SegA000
  mov ax,StartChar
  mov bx,32
  mul bx
  mov di,ax
  mov ax,Count
  mul bx
  mov dx,ScanLines
  lds si,Buffer
  cld
@@1:
  mov cx,dx
  rep movsb
  mov cx,bx
  sub cx,dx
  add di,cx
  sub ax,bx
  cmp ax,0
  jnz @@1
  pop ds
  call CloseRegs
End; { LoadCharset }

Procedure SaveROMFont; assembler;
Asm
  mov ax,1130h
  mov bh,Code
  les bp,Font
  int 10h
End; { SaveROMFont }

Procedure LoadROMCharset; assembler;
Asm
  mov ah,11h
  xor al,al
  mov cx,Count
  mov dx,StartChar
  xor bl,bl
  mov bh,byte ptr ScanLines
  les bp,Buffer
  int 10h
End; { LoadROMCharset }

Procedure SaveFont;
Begin
  SaveCharset(Font, 0, 256, ScanLines)
End; { SaveFont }

Procedure LoadFont;
Begin
  LoadCharset(Font, 0, 256, ScanLines)
End; { LoadFont }

End.
