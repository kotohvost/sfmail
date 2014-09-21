;EXECqt.ASM
;Written by Kim Kokkonen, TurboPower Software
;10/88
;Changed for execute xternal processes in 'QUIET-mode'
;by Anton Deinow (Anton Deinow Software Research Lab.
;29-Mar-94

ofst       equ     (word ptr 0)
segm       equ     (word ptr 2)

ToDos      macro                        ;Transfer control to DOS
           jmp  dword ptr Int21CS
           endm

ToApp      macro                        ;Transfer control back to caller
           clc                          ;Clear error flag
           ret     2                    ;Return with flags intact
           endm

ToBIOS     macro
           jmp  dword ptr Int10CS
           endm

data segment word public
      extrn CurInt21 :dword  ;Previous $21 vector
      extrn CurInt10 :dword  ;Previous $10 vector
data ends

code       segment byte public
           assume  cs:code,ds:data,es:nothing
           public  SetCsInts
           public  NewInt21
           public  NewInt10

Int21CS    dd      ?     ;Old interrupt 21 in code segment
Int10CS    dd      ?     ;Old int $10 in code segment

; Save ints in code segment
SetCsInts  proc near
     les ax,CurInt21
     mov Int21CS.ofst,ax
     mov Int21CS.segm,es

     les ax,CurInt10
     mov Int10CS.ofst,ax
     mov Int10CS.segm,es
     ret
SetCsInts  endp

; Handle interrupt 21 to trap output calls
NewInt21   proc far
    sti
    cmp ah,2                 ;Just get functions that go to StdOut
    jz  QuietDispDos
    cmp ah,6
    jz  QuietDispDos
    cmp ah,9
    jz  QuietDispDos
    cmp ah,40h               ;Or maybe to StdErr
    jz  BlockOut

    ToDos  ;Allow DOS to execute this function
;-----------
QuietDispDos: ToApp  ;Move all information from process to NUL

;------------
BlockOut:                               ;DOS function 40h
           cmp     bx,1                 ;To StdOut?
           jz      BlockOut1            ;Jump if so
           cmp     bx,2                 ;To StdErr?
           jz      BlockOut1            ;Jump if so
           ToDos                        ;Else let DOS handle it
BlockOut1:
           jcxz    BlockOut3            ;Get out if none to write
BlockOut2:
           mov ax,cx
           clc
BlockOut3:
           ToApp                        ;Back to application
NewInt21 endp

; New Int 10h handler
NewInt10 proc far
    cmp ah,2 ;GotoXY
    jz  QuietDispBIOS
    cmp ah,6 ;Scroll Up
    jz  QuietDispBIOS
    cmp ah,7 ;Scroll Down
    jz  QuietDispBIOS
    cmp ah,9 ;Write char & attr
    jz  QuietDispBIOS
    cmp ah,0Ah ;Write char
    jz  QuietDispBIOS
    cmp ah,0Eh ;Write char in Teletype mode
    jz  QuietDispBIOS

    ToBIOS  ;Allow BIOS to execute this function

QuietDispBIOS:
    ToApp

NewInt10 endp

code       ends
           end

;-) That's all
