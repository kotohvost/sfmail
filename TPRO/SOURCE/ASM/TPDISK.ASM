;******************************************************
;		   TPDISK.ASM 5.12
;		 Disk access routines
;	 Copyright (c) TurboPower Software 1987.
; Portions copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to	TurboPower Software
;		 All rights reserved.
;******************************************************

	INCLUDE	TPCOMMON.ASM

;******************************************************	Data

DATA	SEGMENT	WORD PUBLIC

	EXTRN	DosError : WORD			;Declared in DOS unit
	EXTRN	DSReadDrive : BYTE		;!!.10
	EXTRN	DSWriteDrive : BYTE		;!!.10
	EXTRN	DSReadBig : BYTE		;!!.10
	EXTRN	DSWriteBig : BYTE		;!!.10

	Packet	LABEL	BYTE
	StartLo	DW	?
	StartHi	DW	?
	Count	DW	?
	BufOfs	DW	?
	BufSeg	DW	?

DATA	ENDS

;******************************************************	Code

CODE	SEGMENT	BYTE PUBLIC

	ASSUME	CS:CODE,DS:DATA

	PUBLIC	NumberOfDrives,	SelectDrive, DefaultDrive
	PUBLIC	ReadDiskSectors, WriteDiskSectors, GetDiskInfo

;******************************************************	NumberOfDrives

;function NumberOfDrives : Byte;
;Returns the number of logical drives

NumberOfDrives	PROC FAR

	MOV	AH,19h			;Report	current	drive service
	INT	21h			;Call DOS
	MOV	DL,AL			;Current drive into DL
	MOV	AH,0Eh			;Select	current	drive service
					;Returns drive count in	AL
	INT	21h			;Call DOS
	SetZero	AH			;Clear AH
	RET

NumberOfDrives	ENDP

;******************************************************	SelectDrive

;procedure SelectDrive(Drive : Char);
;Selects the specified drive as	default	if possible

Drive	EQU	BYTE PTR SS:[BX+4]

SelectDrive	PROC FAR

	StackFrame
	MOV	DL,Drive		;DL = Drive
	CMP	DL,'z'			;Drive <= 'z'?
	JA	SelectExit		;If not, forget	it
	CMP	DL,'a'			;Drive in 'a'..'z'?
	JB	GotDriveLetter		;If not, continue
	SUB	DL,32			;Else convert to uppercase

GotDriveLetter:
	SUB	DL,'A'			;Convert to drive number
	MOV	AH,0Eh			;Select	current	drive service
	INT	21h			;Call DOS

SelectExit:
	RET	2

SelectDrive	ENDP

;******************************************************	DefaultDrive

;function DefaultDrive : Char;
;Returns the default drive as an uppercase letter

DefaultDrive	PROC FAR

	MOV	AH,19h			;Report	current	drive service
	INT	21h			;Call DOS
	ADD	AL,'A'			;Convert drive number to char
	RET

DefaultDrive	ENDP

;******************************************************	ReadWriteDiskSectors

;!!!!!!	numerous changes to this routine (ReadWriteDiskSectors)	!!.10

;Primitive routine to read/write absolute disk sectors,	used by
;  ReadDiskSectors and WriteDiskSectors
;On entry, DI contains 0 or 1 -- 1 to write, 0 to read

;Equates for parameters	(ReadDiskSectors and WriteDiskSectors have identical
; parameter lists)

DSDrive		EQU	WORD PTR SS:[BX+14]
DSFirstSect	EQU	DWORD PTR SS:[BX+10]
DSFirstSectLo	EQU	WORD PTR SS:[BX+10]
DSNumSects	EQU	WORD PTR SS:[BX+8]
DSBuffer	EQU	DWORD PTR SS:[BX+4]

ReadWriteDiskSectors	PROC FAR

	StackFrame
	PUSH	DS			;Save DS
	PUSH	BP			;Save BP -- destroyed by DOS

	MOV	DX,DSDrive		;DL = Drive
	INC	DL
	MOV	SI,Offset DSReadDrive	;DS:SI => DSReadDrive/DSWriteDrive
	ADD	SI,DI
	CMP	DL,[SI]			;Have we already checked this drive?
	JNE	DScheck			;If not, check it

DSchoose:
	CMP	BYTE PTR [SI+2],0	;Does drive have >64K sectors?
	JE	DSOld			;If not, use "old" method
	JMP	SHORT DSNew		;Else use "new"	method

DScheck:
	;call get disk info function

	MOV	[SI],DL			;Save drive number

	PUSH	BX			;Save BX and DI
	PUSH	DI
	MOV	AH,36h			;Get disk free space
	INT	21h			;call DOS
	POP	DI			;Restore BX and	DI
	POP	BX

	CMP	AX,0FFFFh		;Invalid drive?		 !!.12
	JNE	DSok			;If not, continue	 !!.12
	MOV	DosError,15		;Else, error		 !!.12
	SetZero	AL			;We failed		 !!.12
	POP	BP			;Restore BP		 !!.12
	POP	DS			;Restore DS		 !!.12
	RET	12			;Return	immediately	 !!.12

DSok:								;!!.12
	;AX has	sectors/cluster, DX has	total clusters
	MUL	DX			;DX:AX has total sectors
	OR	DL,DH			;Is DX 0?
	MOV	[SI+2],DL		;Save (DL or DH)
	JZ	DSOld			;If DX is 0, use "old" method

	;Load parameters into packet, load new info into registers
DSNew:
	LES	AX,DSFirstSect		;Put first sector into packet
	MOV	StartLo,AX
	MOV	StartHi,ES
	MOV	AX,DSNumSects		;Put sector count into packet
	MOV	Count,AX
	LES	AX,DSBuffer		;Put buffer pointer into packet
	MOV	BufOfs,AX
	MOV	BufSeg,ES
	MOV	CX,0FFFFh		;Extended identifier
	MOV	AX,DSDrive		;AX = Drive
	MOV	BX,Offset Packet	;DS:BX => Packet
	JMP	SHORT DSGo

DSOld:	;load parameters into registers

	MOV	AX,DSDrive		;AL = Drive
	MOV	CX,DSNumSects		;CX = NumSects
	MOV	DX,DSFirstSectLo	;DX = FirstSect
	LDS	BX,DSBuffer		;DS:BX points to Buf

DSGo:	;see if	we're reading or writing

	SHR	DI,1			;Rotate	DI right by one	bit
	JC	DSWrite			;Write if carry	flag set
	INT	25h			;DOS interrupt for absolute disk read
	JMP	SHORT DSCheckCarry	;Check carry flag

DSWrite:
	INT	26h			;DOS interrupt for absolute disk write

DSCheckCarry:
	MOV	BL,0			;Assume	failure
	JC	DSDone			;Error code in AX if carry flag	set
	SetZero	AX			;Otherwise, AX = 0
	INC	BL			;BX = Ord(True)
DSDone:
	FakePOPF			;DOS leaves flags on the stack!
	POP	BP			;Restore BP
	POP	DS			;Restore DS
	MOV	DosError,AX		;Error code in DosError
	MOV	AL,BL			;Boolean result	into AX
	RET	12

ReadWriteDiskSectors	ENDP

;******************************************************	ReadDiskSectors

;function ReadDiskSectors(Drive	: Word;	FirstSect : LongInt;
;			  NumSects : Word; var Buf) : Boolean;
;Read absolute disk sectors

ReadDiskSectors	PROC FAR

	SetZero	DI			;DI = 0	(Read)
	JMP	ReadWriteDiskSectors	;Jump to primitive read/write routine

ReadDiskSectors	ENDP

;******************************************************	WriteDiskSectors

;function WriteDiskSectors(Drive : Word; FirstSect : LongInt;
;			   NumSects : Word; var	Buf) : Boolean;
;Write absolute	disk sectors.

WriteDiskSectors	PROC FAR

	MOV	DI,1			;DI = 1	(Write)
	JMP	ReadWriteDiskSectors	;Jump to primitive read/write routine

WriteDiskSectors	ENDP

;******************************************************	GetDiskInfo

;function GetDiskInfo(Drive : Byte; var	ClustersAvailable, TotalClusters,
;		      BytesPerSector, SectorsPerCluster: Word) : Boolean;
;Return	technical info about the specified drive

GDDrive		EQU	BYTE PTR [BP+22]
GDClustAvail	EQU	DWORD PTR [BP+18]
GDTotalClust	EQU	DWORD PTR [BP+14]
GDBytesPerSec	EQU	DWORD PTR [BP+10]
GDSecPerClust	EQU	DWORD PTR [BP+6]

GetDiskInfo	PROC FAR

	StackFrameBP
	MOV	DL,GDDrive		;DL = Drive
	MOV	AH,36h			;Get disk free space
	INT	21h			;call DOS
	CMP	AX,0FFFFh		;invalid drive?
	JE	GDIerror		;error if so
	CLD				;go forward
	LES	DI,GDSecPerClust	;ES:DI => SectorsPerCluster
	STOSW				;value in AX
	LES    DI,GDBytesPerSec		;ES:DI => BytesPerSector
	MOV    AX,CX			;value in CX
	STOSW
	LES    DI,GDTotalClust		;ES:DI => TotalClusters
	MOV    AX,DX			;value in DX
	STOSW
	LES    DI,GDClustAvail		;ES:DI => ClustersAvailable
	MOV    AX,BX			;value in BX
	STOSW
	MOV	AX,1			;set OK	flag
GDIdone:
	Exit_Code 18			;!!.12
GDIerror:
	SetZero	AX			;AX = 0
	JMP SHORT GDIdone		;exit

GetDiskInfo	ENDP

CODE	ENDS

	END
