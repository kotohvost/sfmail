TITLE Turbo Pascal XMS support for loading overlays - By Wilbert van Leijen
PAGE 65, 132
        ideal
        model TPascal
        LOCALS @@
        jumps
        p286

        DataSeg

;  XMS block move record

struc XMMCTRL

ulBlLength      dd      ? ;Длина блока для пересылки
wSrcHndl        dw      ? ;Хэндл исходного блока ( 0 если в обычной памяти)
pSrcOffset      dd      ? ;32-бит смещение в исходном блоке (seg:off если )
wDestHndl       dw      ? ;Хэндл блока назначения ( 0 если в обычной памяти)
pDestOffset     dd      ? ;32-бит смещение в блоке назначения (seg:off если )

ends  XMMCTRL

;  TP overlay manager record

struc   OVRHEADER
           ReturnAddr   DD      ?         ; Virtual return address
           FileOfs      DD      ?         ; Offset into overlay file
           CodeSize     DW      ?         ; Size of overlay
           FixupSize    DW      ?         ; Size of fixup table
           EntryPts     DW      ?         ; Number of procedures
           CodeListNext DW      ?         ; Segment of next overlay
           LoadSeg      DW      ?         ; Start segment in memory
           Retrieved    DW      ?         ; Loaded in memory flag
           LoadListNext DW      ?         ; Segment of next in load list
           XmsOffset    DD      ?         ; Offset into allocated XMS block
           UserData     DW      3 DUP(?)
ends    OVRHEADER

pXmsEntry       DD      ?                   ; Entry point of XMS driver
pExitSave       DD      ?                   ; Pointer to previous exit proc
sXmsCtrl        XMMCTRL {}
OvrXmsHandle    DW    ?                   ; Returned by XMS driver
TmpWord         DW    ?                   ; для модулей нечетного pазмеpа

Extrn   PrefixSeg : word
Extrn   ExitProc : dword
Extrn   OvrResult : word
Extrn   OvrCodeList : word
Extrn   OvrDosHandle : word
Extrn   OvrHeapOrg : word
Extrn   OvrReadBuf : dword

        CodeSeg
Public  OvrInitXMS

ovrIOError     EQU     -4
ovrNoXmsDriver EQU     -7
ovrNoXmsMemory EQU     -8

proc    OvrXmsExit

; Release handle and XMS memory

        MOV    DX, [OvrXmsHandle]
        MOV    AH, 0Ah
        CALL   [pXmsEntry]

; Restore pointer to previous exit procedure

        LES    AX, [pExitSave]
        MOV    [word low ExitProc], AX
        MOV    [word high ExitProc], ES
        RET
endp    OvrXmsExit

proc    AllocateXms near

;  Determine the size of the XMS block to allocate:
;  Walk the CodeListNext chain
;  Store the total codesize in DX:AX

        mov    AX, 3FFh         ;Выравниваем на килобайт
                                ;тем самым у нас лишний килобайт
                                ;добавится только если он действительно нужен
                                ;- тоесть не нужна команда inc dx
        XOR    DX, DX
        MOV    BX, [OvrCodeList]
@@1:    ADD    BX, [PrefixSeg]
        ADD    BX, 10h
        MOV    ES, BX
        ADD    AX, [es:OVRHEADER.CodeSize]
        ADC    DX, 0
        test   [es:OVRHEADER.CodeSize], 1
        jz     @@Even
        add    ax, 1
        adc    dx, 0

@@Even:
        MOV    BX, [es:OVRHEADER.CodeListNext]
        OR     BX, BX
        JNZ    @@1

;  Obtain number of kilobytes to allocate

        MOV    BX, 400h
        DIV    BX
        XCHG   DX, AX

;  Allocate the block

        MOV    AH, 9
        CALL   [pXmsEntry]
        OR     AX, AX
        JZ     @@2
        MOV    [OvrXmsHandle], DX
@@2:    RET
endp    AllocateXms

;  Function XmsReadFunc(OvrSeg : Word) : Integer; Far;

proc    XmsReadFunc
        arg OvrSeg:word

;  Swap the code from XMS to the heap

        Push   BP
        MOV    ES, [OvrSeg]
        MOV    AX, [es:OVRHEADER.CodeSize]
        Sub    BX,BX
        test   AX, 1
        jz     @@NoNeedAdd
        Inc    BX
        Dec    AX

@@NoNeedAdd:
        MOV    [word low sXmsCtrl.ulBlLength], AX
        Sub    AX, AX
        MOV    [word high sXmsCtrl.ulBlLength], AX
        MOV    AX, [OvrXmsHandle]
        MOV    [sXmsCtrl.wSrcHndl], AX
        MOV    AX, [word low es:OVRHEADER.XmsOffset]
        MOV    [word low sXmsCtrl.pSrcOffset], AX
        MOV    AX, [word high es:OVRHEADER.XmsOffset]
        MOV    [word high sXmsCtrl.pSrcOffset], AX
        Sub    AX, AX
        MOV    [sXmsCtrl.wDestHndl], AX
        MOV    [word low sXmsCtrl.pDestOffset], AX
        MOV    AX, [es:OVRHEADER.LoadSeg]
        MOV    [word high sXmsCtrl.pDestOffset], AX
        MOV    AH, 0Bh
        LEA    SI, [sXmsCtrl]
        Push   BX
        CALL   [pXmsEntry]
        Pop    BX
        OR     AX, AX
        JZ     @@1
        DEC    AX
        JMP    @@2

@@1:
        MOV    AX, ovrIOError
        Jmp    @@3
@@2:
        Test   BX,1
        Jz     @@3

        Mov    ES, [OvrSeg]
        Mov    AX,2
        Mov    [word low sXmsCtrl.ulBlLength], AX
        Sub    AX, AX
        Mov    [word high sXmsCtrl.ulBlLength], AX

        Sub    BX,BX
        Mov    AX, [word low es:OVRHEADER.XmsOffset]
        Add    AX, [es:OVRHEADER.CodeSize]
        Adc    BX,0
        Dec    AX
        Sbb    BX,0
        Mov    [word low sXmsCtrl.pSrcOffset], AX

        Mov    AX, [word high es:OVRHEADER.XmsOffset]
        Add    AX,BX
        Mov    [word high sXmsCtrl.pSrcOffset], AX

        Mov    AX, Offset TmpWord
        Mov    [word low sXmsCtrl.pDestOffset], AX
        Mov    AX, Seg TmpWord
        Mov    [word high sXmsCtrl.pDestOffset], AX
        Mov    AH, 0Bh
        Lea    SI, [sXmsCtrl]
        Call   [pXmsEntry]
        Or     AX, AX
        Jz     @@1

        Mov    ES, [OvrSeg]
        Mov    SI, [es:OVRHEADER.CodeSize]
        Dec    SI
        Mov    AX, [es:OVRHEADER.LoadSeg]
        Mov    ES,AX
        Mov    AX, [TmpWord]
        Mov    [ES:SI],AL
        Sub    AX,AX

@@3:
        Pop    BP
        RET
endp    XmsReadFunc

;  Copy an overlaid unit from the heap to XMS
;  If successful, carry flag is cleared
;  In/Out:
;    BX:DI = offset into XMS memory block

proc    CopyUnitToXms near

;  Get the fields of the XMS block move structure
        MOV    DX, [es:OVRHEADER.CodeSize]
        TEST   DX, 1
        JZ     @@1
        INC    DX
;        INC    [es:OVRHEADER.CodeSize]


@@1:
        MOV    [word low sXmsCtrl.ulBlLength], DX
        XOR    AX, AX
        MOV    [word high sXmsCtrl.ulBlLength], AX
        MOV    [sXmsCtrl.wSrcHndl], AX
        MOV    [word low sXmsCtrl.pSrcOffset], AX
        MOV    AX, [OvrHeapOrg]
        MOV    [word high sXmsCtrl.pSrcOffset], AX
        MOV    AX, [OvrXmsHandle]
        MOV    [sXmsCtrl.wDestHndl], AX
        MOV    [word low sXmsCtrl.pDestOffset], DI
        MOV    [word high sXmsCtrl.pDestOffset], BX
        push   bx      ;modified by some menegers - BL = 00 on success!!!
        MOV    AH, 0Bh
        LEA    SI, [sXmsCtrl]
        CALL   [pXmsEntry]
        pop    bx      ;restore bx

;  Bump code size

        ADD    DI, DX
        ADC    BX, 0

;  Check return code from XMS driver

        OR     AX, AX
        JZ     @@2
        CLC
        RET

@@2:    STC
        RET
endp    CopyUnitToXms

proc    OvrXmsLoad near

;  Walk the CodeList chain
;  First segment is PrefixSeg+10h+OvrCodeList
;  Push each element of overlaid unit list on the stack
;  Keep the size of the linked list in CX

        MOV    AX, [OvrCodeList]
        XOR    CX, CX
@@1:    ADD    AX, [PrefixSeg]
        ADD    AX, 10h
        MOV    ES, AX
        PUSH   AX
        INC    CX
        MOV    AX, [es:OVRHEADER.CodeListNext]
        OR     AX, AX
        JNZ    @@1

;  Loop:
;    Pop each element of the overlaid unit list from the stack

        XOR    BX, BX
        XOR    DI, DI
@@2:    POP    ES
        PUSH   CX
        MOV    AX, [OvrHeapOrg]
        MOV    [es:OVRHEADER.LoadSeg], AX
        MOV    [word low es:OVRHEADER.XmsOffset], DI
        MOV    [word high es:OVRHEADER.XmsOffset], BX

;  Load overlay from disk

        PUSH   BX
        PUSH   DI
        PUSH   ES
        CALL   [OvrReadBuf] Pascal, ES
        POP    ES
        POP    DI
        POP    BX

;  Flag unit as 'unloaded'; check return code

        MOV    [es:OVRHEADER.LoadSeg], 0
        NEG    AX       ;если ReadBuff вернул ноль то здесь кари небудет
        JC     @@3      ;иначе накушавшись Карри выходим по ошибке

        CALL   CopyUnitToXms    ;BX:DI увеличиваются внутри CopyUnit
        JC     @@3

        POP    CX
        LOOP   @@2

@@3:
        RET
endp    OvrXmsLoad

proc    OvrInitXMS

;  Make sure the file's been opened

        XOR    AX, AX
        CMP    AX, [OvrDosHandle]
        JNE    @@1
        DEC    AX                      ; ovrError
        JMP    @@5

;  Check presence of XMS driver

@@1:    MOV    AX, 4300h
        INT    2Fh
        CMP    AL, 80h
        JE     @@2
        MOV    AX, ovrNoXmsDriver
        JMP    @@5

;  Get XMS driver's entry point

@@2:    MOV    AX, 4310h
        INT    2Fh
        MOV    [word low pXmsEntry], BX
        MOV    [word high pXmsEntry], ES
        CALL   AllocateXms
        JNZ    @@3
        MOV    AX, ovrNoXmsMemory
        JMP    @@5

;  Load the overlay into XMS

@@3:    CALL   OvrXmsLoad
        JNC    @@4

;  An error occurred.  Release handle and XMS memory

        MOV    DX, [OvrXmsHandle]
        MOV    AH, 0Ah
        CALL   [pXmsEntry]
        MOV    AX, ovrIOError
        JMP    @@5

;  Close file

@@4:    MOV    BX, [OvrDosHandle]
        MOV    AH, 3Eh
        INT    21h

;  OvrReadBuf := XmsReadFunc

        MOV    [word low OvrReadBuf], Offset XmsReadFunc
        MOV    [word high OvrReadBuf], CS

;  ExitSave := ExitProc
;  ExitProc := OvrXmsExit

        LES    AX, [ExitProc]
        MOV    [word low pExitSave], AX
        MOV    [word high pExitSave], ES
        MOV    [word low ExitProc], Offset OvrXmsExit
        MOV    [word high ExitProc], CS

;  Return result of initialisation

        XOR    AX, AX
@@5:    MOV    [OvrResult], AX
        RET
endp    OvrInitXMS

END