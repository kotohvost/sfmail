;*******************************************************
;                    CHAIN.ASM 6.00
;        Copyright (c) TurboPower Software 1987.
;                 All rights reserved.
;*******************************************************

DSEG    SEGMENT WORD PUBLIC

        EXTRN   CloseFilesBeforeChaining:BYTE   ;Variable in CHAIN.PAS
        EXTRN   PrefixSeg:WORD                  ;Variable in SYSTEM

DSEG    ENDS

CSEG    SEGMENT BYTE PUBLIC

        ASSUME  CS:CSEG,DS:DSEG

        PUBLIC  Chain4
        PUBLIC  SetIntVec
        EXTRN   RestoreVectors:NEAR             ;Routine to restore vectors

;The following values must be exact
;They'll need changing if anything after label CodeToRelocate changes
CodeLen        EQU     02Ch                     ;Bytes of code to relocate
MaxCmdLen      EQU     052h                     ;Maximum length of command line

;Although more reliable, the following generates several NOPs in object code
;CodeLen = offset Dummy-offset CodeToRelocate   ;Length of code in PSP
;MaxCmdLen = 07Eh-CodeLen                       ;Maximum length of command line

FirstHandle     EQU     5                       ;First file handle to close

;**************************************************************** SetIntVec
; procedure SetIntVec(Num : Byte; Vec : pointer);
;   set interrupt Num to point to Vec

SetIntVec PROC NEAR
        MOV     BX,SP                           ;Stack frame
        MOV     CX,DS                           ;Save DS
        MOV     AH,25h                          ;Set vector
        MOV     AL,SS:[BX+6]                    ;AL = Num
        LDS     DX,SS:[BX+2]                    ;DS:DX = Vec
        INT     21h
        MOV     DS,CX                           ;Restore DS
        RET     6
SetIntVec ENDP

;**************************************************************** Chain4
; function Chain4(Path, CmdLine : string) : word;
;   Turbo 4 equivalent of chaining

;Parameters
PathArg         EQU     DWORD PTR [BP+10]       ;File to chain to
CmdLine         EQU     DWORD PTR [BP+6]        ;Command line to pass

;Local variables
CsInit          EQU     WORD PTR [BP-30+16h]    ;Fields within EXE header
IpInit          EQU     WORD PTR [BP-30+14h]    ; ...
StackPtr        EQU     WORD PTR [BP-30+10h]
StackSeg        EQU     WORD PTR [BP-30+0Eh]
MinHeap         EQU     WORD PTR [BP-30+0Ah]
EXEPages        EQU     WORD PTR [BP-30+04h]
EXEHeader       EQU     WORD PTR [BP-30]        ;EXE header from file
Path            EQU     BYTE PTR [BP-94]        ;ASCIIZ path string

Chain4  PROC    FAR

        PUSH    BP
        MOV     BP,SP                           ;Set up stack frame
        SUB     SP,94                           ;Make space for locals

;Validate pathname and convert to ASCIIZ
        PUSH    DS                              ;Save DS for later
        PUSH    SS
        POP     ES                              ;ES = SS
        LEA     DI,Path                         ;ES:DI => ASCIIZ path
        MOV     BX,DI                           ;Save offset of ASCIIZ
        LDS     SI,PathArg                      ;DS:SI => file path in Turbo string
        ASSUME  DS:nothing
        CLD                                     ;Forward
        LODSB                                   ;Get length byte
        CMP     AL,63                           ;Longer than 63 characters?
        JB      StoreASCIIZ
        MOV     AL,63                           ;Truncate it
StoreASCIIZ:
        MOV     CL,AL                           ;CX = length
        XOR     CH,CH
        REP     MOVSB                           ;Copy to local Path
        XOR     AL,AL                           ;Make ASCIIZ
        STOSB

;Assure file exists
        PUSH    SS
        POP     DS                              ;DS = SS
        MOV     DX,BX                           ;DS:DX => ASCIIZ path
        MOV     AX,3D00h                        ;Open file read-only
        INT     21h
        JNC     FileFound                       ;OK, file was found

Error:  POP     DS                              ;Restore DS
        ASSUME  DS:DSEG
Error1: MOV     SP,BP                           ;Return with error code in AX
        POP     BP                              ;Restore BP
        RET     8                               ;Remove parameters from stack

;Read file header
FileFound:
        MOV     BX,AX                           ;BX = file handle
        LEA     DX,ExeHeader                    ;DS:DX => ExeHeader
        MOV     CX,28                           ;Read 28 bytes
        MOV     AH,3Fh                          ;DOS read file
        INT     21h
        JC      Error                           ;Error if carry set
        CMP     AX,2                            ;At least 2 bytes read?
        MOV     AX,30                           ;Prepare for Read Fault error
        JB      Error                           ;Error if 2 bytes not read

;Determine how much memory program needs
        CMP     ExeHeader,5A4Dh                 ;Is it EXE format?
        JE      ExeFileSize                     ;Yes, treat it as such

;Get non-EXE file size
        MOV     AX,4202h                        ;Seek to end of file
        XOR     CX,CX
        XOR     DX,DX
        INT     21h
        JC      Error                           ;Error if carry set
        MOV     CX,4                            ;Divide bytes by 16
NextShiftR:
        SHR     DX,1                            ;Shift a LongInt right
        RCR     AX,1
        LOOP    NextShiftR
        JMP SHORT CloseFile                     ;DX:AX has paragraphs needed

;Get EXE image size
ExeFileSize:
        MOV     AX,EXEPages                     ;Get pages in EXE image
        XOR     DX,DX
        MOV     CX,5                            ;Multiply by 32
NextShiftL:
        SHL     AX,1                            ;Shift a LongInt left
        RCL     DX,1
        LOOP    NextShiftL                      ;DX:AX has paragraphs
        ADD     AX,MinHeap                      ;Add minimum data/stack/heap
        ADC     DX,0

;Close file (DOS will reopen it)
CloseFile:
        MOV     CX,AX                           ;Save paragraphs in CX
        MOV     AH,3Eh                          ;Close file
        INT     21h
        JC      Error                           ;Error if carry set

;See if more than 640K bytes requested
        MOV     AX,8                            ;Prepare for insufficient memory
        OR      DX,DX                           ;DX must be zero
        JNZ     Error                           ;Error if more than 640K

;Determine available memory space
        POP     DS                              ;Restore DS
        ASSUME  DS:DSEG
        MOV     ES,PrefixSeg                    ;Main program segment

        MOV     AX,3000h                        ;DOS version number
        PUSH    BX                              ;Call may trash BX,CX
        PUSH    CX
        INT     21h
        POP     CX
        POP     BX
        MOV     AH,4Ah                          ;Setblock
        CMP     AL,3
        JAE     Dos3                            ;Jump if DOS 3.0 or later

        MOV     BX,CX                           ;Kludge for DOS 2.X
        ADD     BX,1000h
        INT     21h                             ;BX = Required space+64K bytes
        JMP     SHORT AllocAll
Dos3:                                           ;Correct method for DOS 3+
        MOV     BX,0FFFFh                       ;Ask for everything
        INT     21h
        MOV     AX,BX                           ;BX has available paragraphs
        SUB     AX,10h                          ;Leave space for PSP
        CMP     AX,CX                           ;Sufficient space?
        MOV     AX,8                            ;Prepare for insufficient memory
        JNB     AllocAll                        ;Jump if sufficient
        JMP     Error1

;Allocate all available space
AllocAll:
        MOV     AH,4Ah                          ;Ask again for what we can get
        INT     21h
        JNC     MoveStack
        JMP     Error1

;Prepare to move stack to top of memory
MoveStack:
        MOV     AX,ES                           ;Base of program
        ADD     AX,BX                           ;Add all available paragraphs
        SUB     AX,1000h                        ;Room for full stack segment
        MOV     CS:TmpSS,AX                     ;Store temporary SS for later

;Close secondary file handles (don't touch StdIn,StdOut,StdErr,StdPrn)
        CMP     CloseFilesBeforeChaining,0      ;Should we close files?
        JZ      RestoreInts                     ;No, skip this
        MOV     BX,FirstHandle                  ;Start with handle 5
        MOV     CX,20-FirstHandle               ;20 handles total
NextHandle:
        MOV     AH,3Eh                          ;DOS close file
        INT     21h
        INC     BX                              ;Ignore errors
        LOOP    NextHandle

;Restore interrupt vectors taken over by SYSTEM library
RestoreInts:
        PUSH    ES
        CALL    RestoreVectors
        POP     ES

;Set up command line for chained program
        LDS     SI,CmdLine                      ;DS:SI points to command line
        MOV     DI,80h                          ;ES:DI => command line in PSP
        LODSB                                   ;Get length byte
        CMP     AL,MaxCmdLen                    ;Is is too long?
        JB      StoreCmdLine                    ;No, don't truncate
        MOV     AL,MaxCmdLen                    ;Truncate
StoreCmdLine:
        STOSB                                   ;Store length byte
        MOV     BX,DI                           ;Save start of command line
        MOV     CL,AL
        XOR     CH,CH
        REP     MOVSB                           ;Copy parameter to command line
        MOV     AL,0Dh                          ;Terminate with <Enter>
        STOSB

;Initialize FCB's for new program
        PUSH    ES
        POP     DS                              ;DS = ES
        MOV     SI,BX                           ;DS:SI => command line to parse
        MOV     DI,005Ch                        ;ES:DI => FCB1
        MOV     AX,2901h                        ;Init FCB1
        INT     21h
        MOV     DI,006Ch                        ;ES:DI => FCB2
        MOV     AX,2901h                        ;Init FCB2
        INT     21h

;Save initialization data for new program
        MOV     BX,ES                           ;Store prefix seg in BX
        MOV     CS:NewCS,BX                     ;Assume COM file
        MOV     CS:NewSS,BX
        ADD     BX,10h                          ;BX = base segment of image
        CMP     ExeHeader,5A4Dh                 ;Is it EXE format?
        JNE     MoveCode                        ;No, COM file already initialized
        MOV     AX,CsInit                       ;Get initial CS from EXE header,
        ADD     AX,BX                           ;   relocate segment,
        MOV     CS:NewCS,AX                     ;   save it for later
        MOV     AX,IpInit                       ;Initial IP
        MOV     CS:NewIP,AX
        MOV     AX,StackSeg                     ;Initial SS
        ADD     AX,BX
        MOV     CS:NewSS,AX
        MOV     AX,StackPtr                     ;Initial SP
        MOV     CS:NewSP,AX

;Move code into PSP
MoveCode:
        MOV     CX,CodeLen                      ;Bytes to move
        MOV     DI,100h                         ;DI => end of new code
        SUB     DI,CX                           ;ES:DI => destination of new code
        MOV     CS:TmpIP,DI                     ;Store address to jump to
        MOV     CS:TmpCS,ES
        PUSH    CS
        POP     DS                              ;DS = CS
        MOV     SI,offset CodeToRelocate        ;DS:SI => code to relocate
        REP     MOVSB                           ;Copy the code to PSP

;Prepare for EXEC call
        MOV     AX,BX                           ;AX = Base segment
        STOSW
        STOSW                                   ;Initialize EXEC block
        PUSH    SS
        POP     DS                              ;DS = SS
        LEA     DX,Path                         ;DS:DX => Path of file
        MOV     BX,100h                         ;ES:BX => EXEC block
        MOV     AX,4B03H                        ;Load Overlay
        CLI
        MOV     SS,CS:TmpSS                     ;Put stack at top
        MOV     SP,0FFFEh                       ;  of memory
        STI
        DB      0EAh                            ;JMP FAR to code in PSP
TmpIP   DW      0                               ;Patched in with offset
TmpCS   DW      0                               ;Patched in with segment
TmpSS   DW      0                               ;Temporary stack segment

;-----------------------------------------------------------------------------
;Code relocated to and executed in PSP
CodeToRelocate:
        INT     21h                             ;Call DOS EXEC
        JNC     GoodLoad                        ;Check for error
        INT     20h                             ;Error is rare
                                                ; just halt if EXEC failed
GoodLoad:
        MOV     DX,CS                           ;Get base of program
        MOV     DS,DX                           ;Initialize DS
        MOV     ES,DX                           ;Initialize ES
        MOV     AH,4Ah                          ;DOS SetBlock
        MOV     BX,0FFFFh                       ;Ask for everything
        INT     21h                             ;BX has available paragraphs
        ADD     BX,DX                           ;Top of memory
        MOV     DS:[0002h],BX                   ;Store in PSP that Turbo uses
        CLI                                     ;Interrupts off
        MOV     SS,DS:[0FEh]                    ;Initialize stack
        MOV     SP,DS:[0FCh]
        STI                                     ;Interrupts on again
        DB      0EAh                            ;JMP FAR to start of code
NewIP   DW      100h                            ;Patched in with start offset
NewCS   DW      0                               ;Patched in with start segment
NewSP   DW      0FFFEh                          ;Patched in with new SP
NewSS   DW      0                               ;Patched in with new SS

Chain4  ENDP

Dummy   LABEL   BYTE                            ;Used to measure code to move

CSEG    ENDS

        END
