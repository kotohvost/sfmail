;*******************************************************
;                    GETMEM.ASM 6.00
;        Copyright (c) TurboPower Software 1987.
;                 All rights reserved.
;*******************************************************

DSEG    SEGMENT WORD PUBLIC

        EXTRN   PrefixSeg:WORD                  ;Variables in SYSTEM
        EXTRN   HeapEnd:DWORD
        EXTRN   HeapPtr:DWORD
        EXTRN   HeapOrg:DWORD

DSEG    ENDS

CSEG    SEGMENT BYTE PUBLIC

        ASSUME  CS:CSEG,DS:DSEG

        PUBLIC  SetMaxHeap
        PUBLIC  GetMemDos

ofst    EQU     (WORD PTR 0)
segm    EQU     (WORD PTR 2)

;*********************************************************** SetMaxHeap
;  procedure SetMaxHeap(Bytes : LongInt);
;    Set maximum heap and adjust DOS memory allocation block

SetMaxHeap PROC FAR
        MOV     BX,SP
        LES     AX,SS:[BX+4]
        MOV     DX,ES                           ;DX:AX = bytes we want
        ADD     AX,0Fh                          ;Add 15 bytes to round up
        ADC     DX,0
        MOV     CX,4                            ;Divide bytes by 16
SetMaxR:
        SHR     DX,1                            ;Shift a LongInt right
        RCR     AX,1
        LOOP    SetMaxR
        OR      DX,DX                           ;More than 640K?
        JNZ     SetMaxDone                      ;Jump if so

        MOV     ES,[PrefixSeg]                  ;ES = base of program
        MOV     DX,ES:[0002h]                   ;DX = Top of memory
        MOV     BX,HeapOrg.segm                 ;BX = base of heap
        SUB     DX,BX                           ;DX = paragraphs of heap now
        CMP     DX,AX                           ;Space left to give away?
        JBE     SetMaxDone                      ;Jump if not

        MOV     DX,ES                           ;DX = base of program
        SUB     BX,DX                           ;BX = paras to base of heap
        ADD     BX,AX                           ;BX = paras we want
        MOV     AH,4Ah
        INT     21h                             ;DOS SetBlock
        JC      SetMaxDone                      ;Jump if error

        MOV     AX,ES
        ADD     AX,BX                           ;AX = top of program segment
        MOV     ES:[0002h],AX                   ;Store in PSP
        MOV     HeapEnd.segm,AX                 ;Store new HeapEnd
        XOR     AX,AX
        MOV     HeapEnd.ofst,AX

SetMaxDone:
        RET     4
SetMaxHeap ENDP

;**************************************************************** GetMemDos
;  procedure GetMemDos(var P : pointer; Bytes : longint);

;Parameters
P               EQU     DWORD PTR [BP+10]       ;Pointer to initialize
Bytes           EQU     DWORD PTR [BP+6]        ;Bytes to allocate

GetMemDos PROC    FAR

        PUSH    BP
        MOV     BP,SP                           ;Set up stack frame

;Get requested bytes and convert to paragraphs
        LES     AX,Bytes                        ;Get the bytes longint
        MOV     DX,ES                           ;DX:AX has bytes to allocate
        ADD     AX,0Fh                          ;Add 15 bytes to round up
        ADC     DX,0
        MOV     CX,4                            ;Divide bytes by 16
NextShiftR:
        SHR     DX,1                            ;Shift a LongInt right
        RCR     AX,1
        LOOP    NextShiftR
        OR      DX,DX                           ;Requesting more than 640K?
        JNZ     Error                           ;Error

;Try to get memory from DOS without affecting this process
        MOV     BX,AX                           ;Paragraphs to request
        INC     AX                              ;Ask for extra paragraph later
        MOV     DI,AX                           ;DI = Paragraphs+1
        MOV     AH,48h                          ;Allocate memory
        INT     21h
        JNC     Store                           ;Success if no carry

;See if contracting the end of the heap will fit the request
;Ignore the DOS free block since it may not be contiguous with the Turbo heap
        MOV     DX,HeapEnd.segm                 ;DX = segment beyond program
        MOV     AX,HeapPtr.segm                 ;AX = segment of HeapPtr
        INC     AX                              ;Ignore up to 16 bytes
        SUB     DX,AX                           ;DX = paragraphs free at
                                                ;  top of heap
        CMP     DX,DI                           ;Is free amount >= request?
        JB      Error                           ;No, error

;Move end of heap down
        MOV     BX,HeapEnd.segm
        SUB     BX,DI
        MOV     HeapEnd.segm,BX

;Shrink memory block for this process
        MOV     AX,[PrefixSeg]                  ;AX = base segment of process
        SUB     BX,AX                           ;BX = paras to keep
        MOV     ES,AX                           ;ES = segment of memory block
        MOV     AH,4Ah                          ;DOS SetBlock
        INT     21h
        JC      Error                           ;Error

;Try to get the requested block again
Get2:   MOV     BX,DI                           ;BX = Paragraphs+1
        DEC     BX                              ;BX = Paragraphs
        MOV     AH,48h                          ;Allocate memory
        INT     21h
        JNC     Store                           ;Success if no carry

Error:  XOR     AX,AX                           ;Error, return nil

Store:  LES     DI,P                            ;ES:DI => result pointer
        MOV     WORD PTR ES:[DI],0              ;Store the return pointer
        MOV     ES:[DI+2],AX                    ;Segment in AX

        MOV     SP,BP
        POP     BP
        RET     8

GetMemDos ENDP

CSEG    ENDS

        END
