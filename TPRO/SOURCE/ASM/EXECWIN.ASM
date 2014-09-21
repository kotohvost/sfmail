;EXECWIN.ASM
;Written by Kim Kokkonen, TurboPower Software
;10/88
;Released to the public domain

col        equ     (byte ptr 0)
row        equ     (byte ptr 1)

ofst       equ     (word ptr 0)
segm       equ     (word ptr 2)

ToDos      macro                        ;Transfer control to DOS
           jmp  dword ptr Int21CS
           endm

ToApp      macro                        ;Transfer control back to caller
           clc                          ;Clear error flag
           ret     2                    ;Return with flags intact
           endm

data       segment word public
           extrn   CurInt21 : dword     ;Previous $21 vector
           extrn   WindPos   : word     ;Cursor position in window
           extrn   WindLo    : word     ;Top left corner of window
           extrn   WindHi    : word     ;   and bottom right corner.
           extrn   WindAttr  : byte     ;Attribute with which to
                                        ;   display all characters.
data       ends

code       segment byte public
           assume  cs:code,ds:data,es:nothing
           public  SetCsInts
           public  NewInt21

Int21CS    dd      ?                    ;Old interrupt 21 in code segment

; Save ints in code segment
SetCsInts  proc    near
           les     ax,CurInt21
           mov     Int21CS.ofst,ax
           mov     Int21CS.segm,es
           ret
SetCsInts  endp

; Handle interrupt 21 to trap output calls
NewInt21   proc    far
           sti
           cmp     ah,2                 ;Just get functions that go to StdOut
           jz      DispOut
           cmp     ah,6
           jz      DirectOut
           cmp     ah,9
           jz      StringOut
           cmp     ah,40h               ;Or maybe to StdErr
           jz      BlockOut
           ToDos

;-----------
DispOut:                                ;DOS function 2
           push    ax
           mov     al,dl                ;Character to write in AL
           call    WriteChar            ;Write via video BIOS
           pop     ax
           ToApp                        ;Return successfully

;-----------
DirectOut:                              ;DOS function 6
           cmp     dl,0FFh              ;Console input?
           jnz     DispOut              ;Jump if not
           ToDos                        ;Else transfer to DOS

;------------
StringOut:                              ;DOS function 9
           push    ax                   ;Save AX
           push    bx                   ;Save string index
           mov     bx,dx                ;DS:BX -> string
StringOut1:
           mov     al,[bx]              ;AL = next character to write
           cmp     al,'$'               ;Terminator?
           jz      StringOut2           ;Exit if so
           call    WriteChar            ;Write it
           inc     bx                   ;Next character
           jmp     StringOut1           ;Loop
StringOut2:
           pop     bx
           pop     ax
           ToApp                        ;Back to application

;------------
BlockOut:                               ;DOS function 40h
           cmp     bx,1                 ;To StdOut?
           jz      BlockOut1            ;Jump if so
           cmp     bx,2                 ;To StdErr?
           jz      BlockOut1            ;Jump if so
           ToDos                        ;Else let DOS handle it
BlockOut1:
           jcxz    BlockOut3            ;Get out if none to write
           push    ax
           push    bx
           push    cx                   ;Save loop counter
           mov     bx,dx                ;DS:BX -> stuff to write
BlockOut2:
           mov     al,[bx]              ;Next character to write
           call    WriteChar            ;Write it
           inc     bx                   ;Next index
           loop    BlockOut2            ;Loop for all the characters
           pop     cx
           pop     bx
           pop     ax
           mov     ax,cx                ;Wrote all the characters
BlockOut3:
           ToApp                        ;Back to application

NewInt21 endp

;------------
; Write a character to current position via BIOS
; Entry: AL is character to write
; Must preserve all but AX
WriteChar  proc    near
           push    bp                   ;some versions of int 10 BIOS trash BP
           push    bx
           push    cx
           push    dx
           push    ds

           mov     bx,seg data          ;set up ds
           mov     ds,bx

           cmp     al,7                 ;Bell character?
           jz      BiosWriteDone        ;Don't write

           mov     dx,WindPos           ;Current cursor pos in DX

           cmp     al,8                 ;Backspace?
           jz      BackSpace
           cmp     al,9                 ;Tab?
           jz      Tab
           cmp     al,10                ;Line feed?
           jz      LineFeed
           cmp     al,13                ;Carriage return?
           jz      Carriage

           call    WriteOne             ;Write one normal character

BiosSetCursor:                          ;Position cursor
           xor     bh,bh
           mov     ah,2
           int     10h
           mov     WindPos,dx           ;Save new cursor position

BiosWriteDone:
           pop     ds
           pop     dx
           pop     cx
           pop     bx
           pop     bp
           ret

Carriage:  mov     dl,WindLo.col        ;Move to left edge
           jmp     BiosSetCursor

LineFeed:  cmp     dh,WindHi.row        ;Room to increment row?
           jb      LineFeed1
           mov     ax,0601h             ;Scroll up one line
           mov     cx,WindLo
           mov     dx,WindHi
           mov     bh,WindAttr
           int     10h
           jmp     BiosWriteDone
LineFeed1: inc     dh                   ;Increment row
           jmp     BiosSetCursor        ;Set cursor

Tab:       mov     cl,dl
           sub     cl,WindLo.Col        ;Characters beyond left edge
           add     cl,8
           and     cl,0F8h              ;To next tab stop
           add     cl,WindLo.Col        ;Window coords
           sub     cl,dl                ;Spaces to write
           xor     ch,ch                ;CX = spaces to write
Tab1:      mov     al,20h               ;Write spaces
           push    cx
           call    WriteOne             ;One at a time
           xor     bh,bh
           mov     ah,2
           int     10h
           mov     WindPos,dx           ;Save new cursor position
           pop     cx
           loop    Tab1                 ;Do all of them
           jmp     BiosWriteDone

BackSpace: cmp     dl,WindLo.col        ;Beyond left edge?
           jbe     BiosWriteDone        ;Exit if not
           dec     dl                   ;One left
           xor     bh,bh
           mov     ah,2                 ;Position cursor
           int     10h
           mov     WindPos,dx
           mov     cx,1                 ;Write character
           mov     bl,WindAttr
           mov     ax,0920h             ;Write a space
           int     10h
           jmp     BiosWriteDone        ;Done now

WriteChar  endp

;---------------
; Write one character and update cursor variable
WriteOne   proc    near
           mov     cx,1                 ;Write character
           mov     bl,WindAttr
           xor     bh,bh
           mov     ah,9
           int     10h

           cmp     dl,WindHi.col        ;Below right border?
           jb      IncCol               ;If so, just increment column
           cmp     dh,WindHi.row        ;Room for CR/LF?
           jb      IncRow               ;Jump if so

           mov     ax,0601h             ;Scroll up one line
           mov     cx,WindLo
           mov     dx,WindHi
           mov     bh,WindAttr
           int     10h
           dec     dh                   ;Compensate for inc to follow

IncRow:    inc     dh                   ;Next row
           mov     dl,WindLo.col        ;First col
           dec     dl                   ;Compensate for inc to follow

IncCol:    inc     dl                   ;Increment column
           ret
WriteOne   endp

code       ends
           end
