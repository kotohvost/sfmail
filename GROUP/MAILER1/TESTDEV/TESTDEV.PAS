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

  (* Функция возвращает
    True если хэндл принадлежит устройству
    или false если хэндл принадлежит файлу *)
  function IsDevice( FHandl :HFILE ):boolean;
  (* Функция фозвращает True если мы имеем права на выполнение
  запрошенных действий с фалом или False если не имеем.
  В случае если фала не существует то мы возвращаем True так как раз
  его нет значит его можно создать.
  Mode - режим открытия - константы определены выше
  Access - шаринг - константы определены выше *)
  function VerifyRights( var FName:string; Mode ,Access :byte  ):boolean;

Implementation

{$IFDEF OS2}

  function VerifyRights( var FName:string; Mode, Access :byte ):boolean;
  Var
    FHandl :HFILE;
    szName :array[0..259] of char;  {260 символов - max full path on HPFS}
    ulError :ULONG;
    ulActionTaken :ULONG;
    ulOpenMode :ULONG;
  begin
    {Формируем ASCIIZ строку - на паскале заебешся}
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
    {проверяем на устройство}
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

    {Move + формирование завершающего нуля}
    {Формируем ASCIIZ строку - на паскале заебешся}
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
        lea   si,[szName] { Имя }
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
       mov  ah,3Dh  {обычное открытие файла}
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
    {проверяем на устройство}
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
    test  dx,80h  {если в регистре dx седьмой бит установлен то это девайс}
    jnz @@Device
    xor ax,ax
@@Device:
  end;

{$ENDIF}
end.
