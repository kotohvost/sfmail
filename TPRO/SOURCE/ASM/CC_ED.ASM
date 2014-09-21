
        INCLUDE TpCommon.asm

DATA    SEGMENT BYTE PUBLIC

        EXTRN   VirtualWidth

DATA    ENDS

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  WriteVertAttr

        EXTRN   CalcOffset:NEAR               ;in TPFAST.OBJ

;--------------------------------------
Attr2CGA       MACRO   MVreg
               XCHG    AX,MVreg        ;Move video byte into AL !!.10
               STOSb                   ; and then to screen
               STI                     ;Allow interrupts
               XCHG    AX,MVreg        ;Restore value in MVreg !!.10
               dec     di
               ENDM

;****************************************************** WriteVertAttr
; procedure WriteVertAttr(St:string; Row,Col:byte);
; Write St string of attrs vertically at Row,Col

AVCol           EQU     BYTE PTR SS:[BX+4]
AVRow           EQU     BYTE PTR SS:[BX+6]
AVSt            EQU     DWORD PTR SS:[BX+8]

WriteVertAttr      PROC FAR
        StackFrame
        PUSH    DS                      ;Save DS
        PUSH    BP                      ;Save BP
        SetZero AH                      ;AH = 0
        MOV     AL,AVRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,AVCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        inc     di                      ;point to video-attr
        MOV     BP,WP VirtualWidth      ;BP = 2*(ScreenWidth-1) !!.10
        ;DEC     BP
        SHL     BP,1
        GetDSPtr AVSt                   ;DS:SI points to St[0]
        cld
        LODSB                           ;AL = Length(St); DS:SI -> St[1]
        SetZero CH                      ;CH = 0
        MOV     CL,AL                   ;CX = Length
        JCXZ    AVExit                  ;If string empty, exit
;        MOV     AH,AVAttr               ;AH = Attribute
        SHR     DL,1                    ;If snow checking is off...
        JNC     AVNoWait                ; use FVNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
AVGetNext:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        MOV     BX,AX                   ;Store video word in BX
        WaitForRetrace                  ;Wait for an opportunity to write
        Attr2CGA        BX
;        WordToCGA       BX              ;Move the word
        ADD     DI,BP                   ;Next row
        LOOP    AVGetNext               ;Get next character
        JMP     SHORT AVExit            ;Done
AVNoWait:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        STOSb                           ;Move video word into place
        dec     di
        ADD     DI,BP                   ;Next row
        LOOP    AVNoWait                ;Get next character
AVExit:
        POP     BP                      ;Restore regs
        POP     DS
        RET     8
WriteVertAttr        ENDP

CODE    ENDS

        END