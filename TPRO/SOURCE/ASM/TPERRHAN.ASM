;******************************************************
;		  TPERRHAN.ASM 5.12
;		Runtime	error recovery
;	 Copyright (c) TurboPower Software 1987.
; Portions copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to	TurboPower Software
;		 All rights reserved.
;******************************************************

	INCLUDE	TPCOMMON.ASM

;******************************************************	Data

DATA	SEGMENT	BYTE PUBLIC

	;Pascal	variables

	EXTRN	SystemContinue : DWORD	;Continuation of system	error handler
	EXTRN	UserHandler : DWORD	;Address of user error handler
	EXTRN	ErrorCode : WORD	;Stores	error code !!.12
	EXTRN	ErrorAddr : DWORD	;Stores	error location
	EXTRN	PrefixSeg : WORD	;Stores	PSP segment of program
	EXTRN	ExitProc : DWORD	;Address of exit handler

	SaveExitProc	DD	?	;Saves old ExitProc

DATA	ENDS

;******************************************************	Code

CODE	SEGMENT	BYTE PUBLIC

	ASSUME	CS:CODE,DS:DATA

	PUBLIC	Handler, ErrHanInt0, Trap8087errors

	FloatError	DB	0	;1 if floating point error occurred
	SaveInt02	Pointer	<>	;Old INT 2 handler
	SaveInt75	Pointer	<>	;Old INT 75 handler

;******************************************************	NewInt02
NewInt02:
	MOV	CS:FloatError,1
	JmpFar	CS:SaveInt02

;******************************************************	NewInt75
NewInt75:
	MOV	CS:FloatError,1
	JmpFar	CS:SaveInt75

;******************************************************	OurExitProc

;Invoked when a	program	is ending. Restore vectors.

OurExitProc	PROC FAR

	GetPtr	SaveExitProc		;ES:DI points to old ExitProc
	SetPtr	ExitProc, ES, DI	;Restore old ExitProc
	PUSH	DS
	LDS	DX,CS:SaveInt02		;Set new NMI vector
	DosCallAX 2502h
	LDS	DX,CS:SaveInt75		;Set INT $75 vector
	DosCallAX 2575h
	POP	DS
	RET

OurExitProc	ENDP

;******************************************************	Trap8087errors

;Install INT 2 and INT 75 handlers

Trap8087errors	PROC NEAR

	GetVector 02h, CS:SaveInt02	;NMI interrupt
	GetVector 75h, CS:SaveInt75	;8087 exception
	MOV	AX,OFFSET OurExitProc	;AX has	offset of OurExitProc
	GetPtr	ExitProc		;ES:DI points to ExitProc^
	SetPtr	SaveExitProc, ES, DI	;Save ExitProc
	SetPtr	ExitProc, CS, AX	;Replace with @OurExitProc
	PUSH	DS			;Save DS
	PUSH	CS			;DS = CS
	POP	DS
	MOV	DX,OFFSET NewInt02	;DX = Ofs(NewInt02)
	DosCallAX 2502h			;Set new NMI vector
	MOV	DX,OFFSET NewInt75	;DX = Ofs(NewInt75)
	DosCallAX 2575h			;Set INT $75 vector
	POP	DS			;Restore DS
	RET

Trap8087errors	ENDP

;******************************************************	ErrHanInt0

;interrupt 0 entry point

ErrHanInt0	PROC FAR

	STI				;Enable	interrupts
	MOV	AX,00C8h		;Error code for	divide by zero
	POP	CX			;Return	address	into BX:CX
	POP	BX
	POP	DX			;Take flags off	stack
					;Control continues in Handler
ErrHanInt0	ENDP

;******************************************************	Handler

;procedure Handler
;recover from Turbo runtime errors
;on entry BX:CX	has address to return to, more or less

Handler	PROC FAR

	MOV	DX,SEG DATA
	MOV	DS,DX			;Restore DS

	MOV	DX,BX			;Check for Ctrl-Break or normal	exit
	OR	DX,CX			;Is return address nil?
	JNZ	CheckErrorClass		;No, check error class
	JMP	NoRecover		;Yes, should not recover

CheckErrorClass:			;Check for classes of run time errors
	CMP	FloatError,1		;Is it an 8087 error?
	JZ	CantRecover		;Yes, can't recover
	CMP	AX,200			;Divide	by zero	error?
	JZ	CheckInstrClass		;Yes, check for	special	cases
	CMP	AX,202			;Stack overflow	error?
	JZ	CantRecover		;Yes, can't recover
	CMP	AX,203			;Heap overflow error?
	JZ	CantRecover		;Yes, can't recover
	CMP	AX,208			;Overlay error (208, 209)?
	JAE	CantRecover		;Yes, can't recover
	CMP	AX,204			;Floating point	error?
	JA	CheckInstrClass		;Yes, check for	special	cases
	JMP	SHORT Recover		;Else recover immediately

CheckInstrClass:			;Check for classes of erring instructions
	MOV	ES,BX			;Error segment
	MOV	DI,CX			;Error offset
	MOV	DX,ES:[DI]		;Get word at error
	MOV	SI,2			;Minimum two bytes for integer DIV
	CMP	DL,0F7h			;Was it	a DIV or IDIV?
	JZ	InstrLen		;Yes, must fix up return address
	CMP	DL,09Bh			;Was it	a WAIT?
	JZ	NoRecover		;Yes, can't recover, 8087 wiped out
	CMP	DL,0D8h			;Was it	a floating point instruction?
	JB	Recover
	CMP	DL,0DFh
	JA	Recover
CantRecover:
	JMP	SHORT NoRecover		;Can't recover, 8087 stack wiped out

InstrLen:
	MOV	DL,DH			;Copy second byte into DL
	PUSH	CX
	MOV	CL,6
	SHR	DL,CL			;Get Mod field
	POP	CX
	CMP	DL,3			;Is it register	addressing?
	JZ	Fixup			;Yes, no displacement bytes
	OR	DL,DL			;Is it direct addressing?
	JZ	Direct			;Yes, look further
	XOR	DH,DH
	ADD	SI,DX			;Add displacement bytes
	JMP	SHORT Fixup
Direct:
	AND	DH,7			;Get r/m field
	CMP	DH,6			;Direct	addressing?
	JNZ	Fixup			;No, two byte instruction
	ADD	SI,2			;Else two address bytes
Fixup:
	ADD	CX,SI			;Add length of instruction

Recover:
	MOV	ErrorCode,AX		;Save error code !!.12
	PUSH	BX			;Return	address	on stack
	PUSH	CX
	SUB	BX,PrefixSeg
	SUB	BX,10h			;Report	relative error segment
	MOV	SI,offset ErrorAddr
	MOV	[SI],CX			;Store error address offset
	MOV	[SI+2],BX		; and segment
	LES	DI,UserHandler		;Get address of	user handler
	MOV	AX,ES
	OR	AX,DI
	JZ	Done			;Skip call if pointer nil
	CALL	DWORD PTR UserHandler	;Else call user	pointer
	OR	AL,AL			;Did UserHandler return	true?
	JNZ	Done			;Yes, return to	program
	POP	CX			;Get error address back
	POP	BX
	MOV	AX,ErrorCode		;Get exitcode back !!.12
	JMP	SHORT NoRecover		;Back to system	handler
Done:
	RET				;Return	beyond error

NoRecover:
	JMP	DWORD PTR [SystemContinue]	;Transfer back to system handler

Handler	ENDP

CODE	ENDS
	END
