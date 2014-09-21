;*******************************************************
;                   PTR2STR.ASM 6.00
;        Copyright (c) TurboPower Software 1987.
;                 All rights reserved.
;*******************************************************

DSEG    SEGMENT WORD PUBLIC
DSEG    ENDS

CSEG    SEGMENT BYTE PUBLIC

        ASSUME  CS:CSEG,DS:DSEG

        PUBLIC  Pointer2String
        PUBLIC  String2Pointer

ofst    EQU     (WORD PTR 0)
segm    EQU     (WORD PTR 2)

;*********************************************************** Pointer2String
;   function Pointer2String(P : pointer) : string;

Pointer2String PROC FAR
        MOV     BX,SP                           ;Set up stack frame
        PUSH    DS                              ;Save DS
        PUSH    SS
        POP     DS                              ;DS = SS
        LEA     SI,DWORD PTR SS:[BX+4]          ;DS:SI => P parameter
        LES     DI,DWORD PTR SS:[BX+8]          ;ES:DI => Result
        CLD
        MOV     CX,8                            ;Eight bytes in string
        MOV     AL,CL
        STOSB                                   ;Store length byte
        SHR     CX,1                            ;Four input bytes
        MOV     DX,0F30h                        ;DH/DL are constants

P2SNext:
        LODSB                                   ;Next byte
        MOV     AH,AL                           ;Save it
        AND     AL,DH                           ;Low nibble
        ADD     AL,DL                           ;Bias into ASCII
        STOSB                                   ;Store in string
        MOV     AL,AH                           ;Restore byte
        SHR     AL,1
        SHR     AL,1
        SHR     AL,1
        SHR     AL,1                            ;High nibble
        ADD     AL,DL
        STOSB                                   ;Store in string
        LOOP    P2SNext                         ;Do four bytes

        POP     DS                              ;Restore DS
        RET     4                               ;Remove parameter and return
Pointer2String ENDP

;*********************************************************** String2Pointer
;   function String2Pointer(S : string) : pointer;

;Parameters and locals
S               EQU     DWORD PTR [BP+6]
ResultHigh      EQU     WORD PTR [BP-2]
ResultLow       EQU     WORD PTR [BP-4]
Result          EQU     BYTE PTR [BP-4]

String2Pointer PROC FAR
        PUSH    BP
        MOV     BP,SP
        SUB     SP,4                             ;Space for locals
        PUSH    DS                               ;Save DS

        LDS     SI,S                             ;DS:SI => S
        CLD                                      ;Forward
        XOR     CX,CX                            ;Prepare for error
        LODSB                                    ;AL = length byte
        CMP     AL,8                             ;Proper length?
        MOV     DX,CX                            ;Nil in DX
        JNZ     S2PDone                          ;Wrong length, return nil

        PUSH    SS
        POP     ES
        LEA     DI,Result                        ;ES:DI => Result
        MOV     CX,4                             ;4 words in string
        MOV     DL,'0'                           ;Constant

S2PNext:
        LODSW                                    ;First two bytes in AX
        SUB     AH,DL                            ;Debias ASCII
        SHL     AH,1
        SHL     AH,1
        SHL     AH,1
        SHL     AH,1
        SUB     AL,DL                            ;Debias ASCII
        OR      AL,AH                            ;Put bytes back together
        STOSB                                    ;Store in result
        LOOP    S2PNext

        MOV     CX,ResultLow                     ;Get result in registers
        MOV     DX,ResultHigh

S2PDone:
        MOV     AX,CX                            ;Store low word
        POP     DS                               ;Restore DS
        MOV     SP,BP
        POP     BP
        RET     4                                ;Remove parameter and return
String2Pointer ENDP

CSEG    ENDS

        END
