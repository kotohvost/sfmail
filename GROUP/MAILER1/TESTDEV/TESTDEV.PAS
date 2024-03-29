Unit TestDev;

Interface

{$IFNDEF OS2}
Uses RelTQ;
  Type
    HFILE  = Word;

{$ELSE}
Uses Dos,Os2Base,Os2Def,Use32;

{$ENDIF}

  Const
    O_RDONLY  = $0;
    O_WRONLY  = $1;
    O_RDWR    = $2;
    SH_COMPAT = $0;
    SH_DENYWR = $20;
    SH_DENYRD = $30;
    SH_DENYNO = $40;

  (* �㭪�� �����頥�
    True �᫨ ����� �ਭ������� ���ன���
    ��� false �᫨ ����� �ਭ������� 䠩�� *)
  function IsDevice( FHandl :HFILE ):boolean;
  (* �㭪�� 䮧��頥� True �᫨ �� ����� �ࠢ� �� �믮������
  ����襭��� ����⢨� � 䠫�� ��� False �᫨ �� �����.
  � ��砥 �᫨ 䠫� �� ������� � �� �����頥� True ⠪ ��� ࠧ
  ��� ��� ����� ��� ����� ᮧ����.
  Mode - ०�� ������ - ����⠭�� ��।����� ���
  Access - �ਭ� - ����⠭�� ��।����� ��� *)
  function VerifyRights( var FName:string; Mode ,Access :byte  ):boolean;

Implementation

{$IFDEF OS2}

  function VerifyRights( var FName:string; Mode, Access :byte ):boolean;
  Var
    FHandl :HFILE;
    szName :array[0..259] of char;  {260 ᨬ����� - max full path on HPFS}
    ulError :ULONG;
    ulActionTaken :ULONG;
    ulOpenMode :ULONG;
  begin
    {��ନ�㥬 ASCIIZ ��ப� - �� ��᪠�� ��������}
    asm
      cld
      mov   esi,[FName]
      movzx ecx,byte ptr [esi]
      inc   esi
      lea   edi,[szName]
  rep movsb
      mov   byte ptr [edi],0
    end;

    ulOpenMode := ULONG( Mode ) or ULONG( Access ) or OPEN_FLAGS_FAIL_ON_ERROR;
    ulError := DosOpen( szName, FHandl, ulActionTaken, 0, 0,
                        OPEN_ACTION_OPEN_IF_EXISTS or OPEN_ACTION_FAIL_IF_NEW,
                        ulOpenMode, nil );

    if ulError <> 0 then
    begin
      if ulError >=5 then
        VerifyRights := false
      else
        VerifyRights := true;
    end
    else
    begin
    {�஢��塞 �� ���ன�⢮}
      if IsDevice( FHandl ) then
        VerifyRights := false
      else
        VerifyRights := true;
      DosClose( FHandl );
    end;
  end;


  function IsDevice( FHandl :HFILE):boolean;
  Var
    HndlType :ULONG;
    Flags :ULONG;
  begin
    if ( DosQueryHType( FHandl, HndlType, Flags ) = 0 )
         and (( HndlType and $FF ) = 0 ) then

      IsDevice := false
    else
      IsDevice := true;
  end;

{$ELSE}
  function VerifyRights( var FName:string; Mode ,Access :byte  ):boolean;
  Var
    FHandl :HFILE;
    szName :array[0..127] of char; {FAT maximum full path}
    fError :boolean;
  begin
    mtOsVer := 0;
    fError := false;

    {Move + �ନ஢���� �������饣� ���}
    {��ନ�㥬 ASCIIZ ��ப� - �� ��᪠�� ��������}
    asm
      cld
      push  ds
      lds   si,[FName]
      xor   cx,cx
      mov   cl,[si]
      inc   si
      push  ss
      pop   es
      lea   di,[szName]
  rep movsb
      mov   byte ptr es:[di],0
      pop   ds
    end;

    if mtOsVer = mtOS_2 then
      asm
        mov   ax,6C01h  {Undocumented OS/2 2.0+ Extended Open}
        mov   bl,[Mode]
        or    bl,[Access]
        mov   bh,20h    {return error rather Int 24, bit 6 - autocommit }
        mov   dx,1h    { fail if doesn't exist & open if exist }
        xor   cx,cx     { creation attributes }
        push  ds
        push  ss
        pop   ds
        lea   si,[szName] { ��� }
        push  0
        pop   es
        xor   di,di       { ES:DI - EAOP -> Extended OS/2 Attributes }
        int   21h
        pop   ds
        mov   [FHandl],ax
        mov   [fError],true
        jc    @@Exit
        mov   [fError],false
@@Exit:
      end

    else

      asm
       push ds
       mov  ah,3Dh  {���筮� ����⨥ 䠩��}
       mov  al,[Mode]
       or   al,[Access]
       xor  cx,cx
       push ss
       pop  ds
       lea  dx,[szName]
       int  21h
       pop  ds
       mov  [FHandl],ax
       mov  [fError],true;
       jc   @@Exit
       mov  [fError],false;
@@Exit:
      end;

    if fError then
    begin
      if FHandl >=5 then
        VerifyRights := false
      else
        VerifyRights := true;
    end
    else
    begin
    {�஢��塞 �� ���ன�⢮}
      if IsDevice( FHandl ) then
        VerifyRights := false
      else
        VerifyRights := true;
      asm
        mov   bx,[FHandl]
        mov   ah,3Eh
        int   21h
      end
    end;

  end;


  function IsDevice( FHandl :HFILE ):boolean;assembler;
  asm
    mov ax,4400h
    mov bx,FHandl
    int 21h
    mov ax,1
    jc  @@Device
    test  dx,80h  {�᫨ � ॣ���� dx ᥤ쬮� ��� ��⠭����� � �� ������}
    jnz @@Device
    xor ax,ax
@@Device:
  end;

{$ENDIF}
end.
