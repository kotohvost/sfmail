;*******************************************************
;                    GETMEM.ASM 6.00
;        Copyright (c) TurboPower Software 1987.
;                 All rights reserved.
;*******************************************************

DSEG    SEGMENT WORD PUBLIC

        EXTRN   PrefixSeg:WORD                  ;Variables in SYSTEM
        EXTRN   FreePtr:DWORD
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
        SUB     AX,1000h                        ;FreePtr segment
        MOV     FreePtr.segm,AX                 ;Store new FreePtr
        XOR     AX,AX
        MOV     FreePtr.ofst,AX

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

;See if moving the free list down will fit the request
;Ignore the DOS free block since it may not be contiguous with the Turbo heap
        LES     AX,FreePtr                      ;ES:AX = FreePtr
        MOV     DX,ES                           ;DX:AX = FreePtr
        PUSH    DX                              ;Save FreeSeg
        PUSH    AX                              ;Save FreeOfs
        OR      AX,AX                           ;FreeList empty?
        JNZ     FreeListNotEmpty
        MOV     AX,1000h                        ;Empty FreeList => +64K free
        JMP SHORT GetFreeSpace
FreeListNotEmpty:
        MOV     CL,4
        SHR     AX,CL                           ;Convert FreeOfs to paras
GetFreeSpace:
        ADD     DX,AX                           ;DX = segment of
                                                ;     lowest free list entry
        LES     BX,HeapPtr                      ;ES:BX = HeapPtr
        MOV     AX,ES                           ;AX is seg(HeapPtr^)
        INC     AX                              ;Ignore up to 16 bytes
        SUB     DX,AX                           ;DX = paragraphs free at
                                                ;  top of heap
        CMP     DX,DI                           ;Is free amount >= request?
        JB      Error                           ;No, error

;Move free list down into free heap
        POP     SI                              ;SI = FreeOfs
        POP     DX                              ;DX = FreeSeg
        PUSH    DI                              ;Save Paragraphs+1
        MOV     CX,DX                           ;CX = FreeSeg
        SUB     CX,DI                           ;CX = seg of new free list
        MOV     ES,CX                           ;ES = seg of new free list
        OR      SI,SI                           ;Is FreeList empty?
        JZ      StoreFreePtr                    ;Yes, skip the move

        PUSH    DS                              ;Save DS
        MOV     DS,DX                           ;DS:SI => old free list
        CLD                                     ;Forward avoids overwrite
        MOV     DI,SI                           ;ES:DI => new free list
        MOV     CX,SI                           ;CX = FreeOfs
        NEG     CX                              ;CX = 10000h-FreeOfs
        SHR     CX,1                            ;Always even number of bytes
        REP     MOVSW                           ;Copy the free list
        POP     DS                              ;Restore DS

;Store the new free list pointer
StoreFreePtr:
        POP     DI                              ;Restore Paragraphs+1
        MOV     WORD PTR [FreePtr+2],ES         ;Store new FreeSeg

;Shrink memory block for this process
        MOV     BX,ES                           ;BX = NewFreeSeg
        ADD     BX,1000h                        ;BX = Top of NewFreeSeg
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