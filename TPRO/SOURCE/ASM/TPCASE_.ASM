;******************************************************
;		   TPCASE.ASM 5.12
;	       String handling routines
;	 Copyright (c) TurboPower Software 1987.
; Portions copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to	TurboPower Software
;		 All rights reserved.
;******************************************************

	INCLUDE	TPCOMMON.ASM

;******************************************************	Code

CODE	SEGMENT	BYTE PUBLIC

	ASSUME	CS:CODE

	PUBLIC	Upcase,	Locase
	PUBLIC	StUpcase, StLocase
	PUBLIC	UpCasePrim, LoCasePrim

;******************************************************	UpcasePrim

;Entry : character to upcase in	AL
;Exit  : uppercase in AL
;	 BX wiped out

UpCaseMap1 LABEL	BYTE		;Maps international characters
					;Starting with #129
;	DB	'Ъ', 'Р', 'A', 'О', 'A', 'П', 'А', 'E',	'E', 'E'
;	DB	'I', 'I', 'I', 'О', 'П', 'Р', 'Т', 'Т',	'O', 'Щ'
;	DB	'O', 'U', 'U', 'Y', 'Щ', 'Ъ', 'Ы', 'Ь',	'Э', 'Ю'
;	DB	'Я', 'A', 'I', 'O', 'U', 'е', 'е', 'A',	'O'

 DB 'А','Б','В','Г','Д','Е','Ж','З','И','Й','К','Л','М','H','О','П'

UpCaseMap2 LABEL BYTE
 DB 'Р','С','Т','У','Ф','Х','Ц','Ч','Ш','Щ','Ъ','Ы','Ь','Э','Ю','Я'

UpCasePrim PROC	FAR
UpCasePrimNear:				;!!.10
	CMP	AL,'a'
	JB	UpCaseDone		;Done if AL < 'a'
	CMP	AL,239
	JA	UpCaseDone		;Done if AL > #240

	CMP	AL,'z'
	JA	ExtUpCase		;Jump if extended uppercase
	SUB	AL,32			;Convert to uppercase
UpCaseDone:
	RET
ExtUpCase:				;International uppercase
	CMP	AL,160
	JB	UpCaseDone		;Done if AL < #160

	cmp al,224		;code >='p'
	jae ScndUpTable		;втоpой участок
	cmp al,176		;code <'░'
	jae UpCaseDone		;псевдогpафика

	SUB	AL,160			;Reduce	to range of map	table
	MOV	BX,OFFSET UpCaseMap1
	XLAT	CS:[BX]			;Use map table
	RET
ScndUpTable:
	Sub al,224
	Mov bx,OffSet UpCaseMap2
	Xlat	cs:[bx]
	Ret
UpCasePrim ENDP

;******************************************************	Upcase

;function UpCase(Ch : Char) : Char;
;Return	uppercase of char, with	international character	support

UpCase	PROC	FAR
	MOV	BX,SP
	MOV	AL,SS:[BX+4]		;AL = input character
	PUSH	CS			;!!.10
	CALL	UpcasePrimNear		;!!.10
	RET	2
UpCase	ENDP

;******************************************************	LocasePrim

;Entry : character to locase in	AL
;Exit  : lowercase in AL
;	 BX wiped out

LoCaseMap1 LABEL	BYTE		;Maps international characters
					;Starting with #128
;	DB	'З', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З',	'И', 'Й'
;	DB	'К', 'Л', 'М', 'Н', 'Д', 'Ж', 'В', 'С',	'С', 'У'
;	DB	'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Ф', 'Б', 'Ы',	'Ь', 'Э'
;	DB	'Ю', 'Я', 'а', 'б', 'в', 'г', 'д', 'д'

 DB 'а','б','в','г','д','е','ж','з','и','й','к','л','м','н','о','п'

LoCaseMap2 Label Byte
 DB 'p','с','т','у','ф','х','ц','ч','ш','щ','ъ','ы','ь','э','ю','я'

LoCasePrim PROC	FAR
LoCasePrimNear:				;!!.10
	CMP	AL,'A'
	JB	LoCaseDone		;Done if AL < 65 'A'
	CMP	AL,239
	JA	LoCaseDone		;Done if AL > 239 'я'
	CMP	AL,127                  ; > 127 ''
	JA	ExtLoCase		;Jump if Russian lowercase
        CMP     AL,91                   ; 65 'A' > al > 91 'Z'
        JA      LoCaseDone
	ADD	AL,32			;Convert to lowercase
LoCaseDone:
	RET
ExtLoCase:				;Russian lowercase
	CMP	AL,159
	Ja	LoCaseDone		;Done if AL > 159 'Я'

	Cmp al,143                      ; > 143 'П'
        Ja  ScndLoTable

	SUB	AL,128			;Reduce	to range of map	table
	MOV	BX,OFFSET LoCaseMap1
	XLAT	CS:[BX]			;Use map table
	RET
ScndLoTable:
	Sub al,144
	Mov bx,OffSet LoCaseMap2
	Xlat cs:[bx]
	Ret
LoCasePrim ENDP

;******************************************************	Locase

;function Locase(Ch : Char) : Char;
;Return	lowercase of char, with	international character	support

LoCase	PROC	FAR
	MOV	BX,SP
	MOV	AL,SS:[BX+4]		;AL = input character
	PUSH	CS			;!!.10
	CALL	LoCasePrimNear		;!!.10
	RET	2
LoCase	ENDP

;******************************************************	StCase
;Convert string	to one case or another,	depending on DX
StCase	PROC	FAR
StCaseNear:
	StackFrame
	PUSH	DS
	CLD				;go forward
	LDS	SI,SS:[BX+4]		;DS:SI => S
	LES	DI,SS:[BX+8]		;ES:DI => function result
	LODSB				;AL = Length(S)
	STOSB				;Set length of result
	SetZero	CH			;CH = 0
	MOV	CL,AL			;CX = Length(S)
	JCXZ	SUDone			;Done if CX is 0
SUNext:
	LODSB				;Next char into	AL
	PUSH	CS			;Fake a	FAR CALL
	CALL	DX			;Uppercase it
	STOSB				;Store char in result
	LOOP	SUNext			;repeat
SUDone:
	POP	DS
	RET	4
StCase	ENDP

;******************************************************	StUpcase

;function StUpcase(S : string) : string;
;Convert lower case letters in string to upper case

StUpcase PROC FAR
	MOV	DX,OFFSET UpcasePrim
	JMP	StCaseNear
StUpcase ENDP

;******************************************************	StLocase

;function StLocase(S : string) : string;
;Convert upper case letters in string to lower case

StLocase PROC FAR
	MOV	DX,OFFSET LocasePrim
	JMP	StCaseNear
StLocase ENDP


CODE	ENDS

	END
