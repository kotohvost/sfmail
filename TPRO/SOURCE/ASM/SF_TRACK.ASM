;        INCLUDE TPCOMMON.ASM
;****************************************************** Data
DATA    SEGMENT BYTE PUBLIC
        ;Pascal variables
;        EXTRN   CheckSnow : BYTE                ;If true, check for retrace
;        EXTRN   VirtualSegment : WORD           ;Segment of Video Memory--alt
;        EXTRN   VirtualWidth : BYTE             ;Current width of virtual display
DATA    ENDS
;****************************************************** Code
CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  Scan
;****************************************************** Scan
;function Scan(Limit:integer; Ch:char; T:pointer):integer;
;Scan limit chars for char, ch not found if rslt=limit

ScT     EQU     DWORD PTR [BP+6]
ScCh    EQU     BYTE PTR [BP+10]
ScLimit EQU     WORD PTR [BP+12]

Scan    PROC FAR

        PUSH    BP                      ;Save BP
        MOV     BP,SP                   ;Set up stack frame
        CLD                             ;assume forward
        MOV     AL,ScCh                 ;char to search for
        MOV     CX,ScLimit              ;bytes to search
        OR      CX,CX                   ;check sign
        PUSHF                           ;save flags
        JNS     X1
        NEG     CX                      ;make positive
        STD                             ;but search in reverse
X1:
        MOV     DX,CX                   ;save full count
        LES     DI,ScT                  ;ptr to start
        REPNE   SCASB                   ;search
        JNE     X2
        INC     CX                      ;found a match
X2:
        SUB     DX,CX                   ;find count to match
        MOV     AX,DX                   ;ready for return
        POPF
        JNS     X3
        NEG     AX                      ;make negative if reverse
X3:
        MOV     SP,BP                   ;Restore SP
        POP     BP                      ;Restore BP
        RET     8                       ;Remove parameters and return

Scan    ENDP

CODE    ENDS

        END
