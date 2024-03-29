{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$I OMINUS.INC}
{$ENDIF}

{$I TPDEFINE.INC}

{*********************************************************}
{*                    TPTSR.PAS 5.12                     *}
{*        Copyright (c) TurboPower Software 1987.        *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpTsr;
  {-TSR management routines}

interface

uses
  Dos, TpInt;

type
  IfcPtr = ^IfcRecord;
  IfcRecord =
    record                   {** don't change order **}
      NamePtr : ^string;
      Version : Word;
      CmdEntryPtr : Pointer;
      PrevIfc,
      NextIfc : IfcPtr;
    end;
const
  MaxPopups = 8;             {maximum number of popup routines}
  SideKickLoaded : Boolean = False; {if True, SideKick is loaded}
  Int5Handle = 1;            {ISR handles used by our interrupt handlers}
  Int8Handle = 2;
  Int9Handle = 3;
  Int10Handle = 4;
  Int13Handle = 5;
  Int14Handle = 6;
  Int16Handle = 7;
  Int17Handle = 8;
  Int25Handle = 9;
  Int26Handle = 10;
  Int28Handle = 11;
var
  ThisIfc : IfcRecord;

  {Flags for popups in use}
  PopupInUse : array[1..MaxPopups] of Boolean;

  {pointers to variables hidden in TPTSR.OBJ}
  PopTickerPtr : ^Word;      {Points to var. indicating if we are trying to pop up}
  PopupsEnabledPtr : ^Boolean; {Points to flag indicating if popups are enabled}
  PopupToCallPtr : ^Byte;    {Points to var. with the handle of a popup to call}

{$IFNDEF Ver40}
const
 ReleaseEms : Boolean = False;
{$ENDIF}

function ParagraphsToKeep : Word;
  {-Returns #. of paragraphs currently used for code, data, stack, and heap.}

function TerminateAndStayResident(ParasToKeep : Word; ExitCode : Byte) : Boolean;
 {-Terminate and stay resident, freeing up all our memory except ParasToKeep.
   Returns False if unable to release memory.}

procedure PopupsOn;
  {-Turns popups on}

procedure PopupsOff;
  {-Turns popups off}

function DefinePopProc(var Handle : Byte; Routine, StackPtr : Pointer) : Boolean;
 {-Defines a routine that can be triggered by calling SetPopTicker. Returns
   false if no more Popup handles are available.}

procedure DeletePopProc(Handle : Byte);
 {-Deletes a popup routine defined with DefinePopProc.  Its handle may then
   be used for other popups.}

function DefinePop(HotKey : Word; Routine, StackPtr : Pointer;
                   DosWait : Boolean) : Boolean;
 {-Defines a popup routine associated with a particular hotkey. Returns
   False if no more Popup handles are available.}

procedure DeletePop(HotKey : Word);
  {-Deletes the popup routine associated with HotKey.  Its handle may then
    be used for other popups.}

function ChangeHotKey(OldHotKey, NewHotKey : Word) : Boolean;
  {-Change a popup's hotkey from OldHotKey to NewHotKey}

procedure SetPopTicker(Handle : Byte; TimeOut : Word);
 {-Sets the pop ticker for the indicated procedure, clears interrupts,
   then returns.  No range checking is performed.}

procedure RemovePops;
 {-Removes all popup routines from the system and releases all associated
   interrupt vectors.}

procedure InitPops;
  {-Must be called before any other popup specific routines.}

function INT24Result : Word;
  {-Returns the latest result from the INT $24 handler}

function DisableTSR : Boolean;
 {-Disable TSR by restoring interrupt vectors and releasing memory. This
   does *not* halt the program. Returns false if it's not safe.}

procedure InstallModule(var ModuleName : string; CmdEntryRoutine : Pointer);
 {-Installs this program as a resident module that can be located and
   accessed by other programs.}

procedure UninstallModule;
  {-Uninstalls the module from the linked list of modules.}

function ModulePtrByName(var ModuleName : string) : IfcPtr;
  {-Returns a pointer to the IfcRecord for the module named ModuleName or Nil.}

function ModuleInstalled(var ModuleName : string) : Boolean;
  {-Returns true if ModuleName is installed.}

function DosBusyFlag : Byte;
  {-Returns current value of DOS busy flag}

function DosCriticalFlag : Byte;
  {-Returns current value of DOS critical flag}

  {==========================================================================}

implementation

type
  SegOfs =
    record
      O, S : Word;
    end;
const
  WentResident : Boolean = False;
  IfcInstalled : Boolean = False;
  Initialized : Boolean = False;
  MaxScanCode = $58;         {highest scan code we can use -- do not change}
  IfcSignature = $0F0F0;     {*** do not change!! ***}
  IfcSignature2 = $0E0E0;    {*** do not change!! ***}
  IfcVersion = $400;         {version number of interface}
  IRET : Byte = $CF;
var
  DosVersion : Word;
  SaveExitProc : Pointer;
  SaveSSeg : Word;
  TopOfHeap : Pointer;

  {Addresses of popup routines}
  PopupAddrs : array[1..MaxPopups] of Pointer;

  {Stacks for popup routines}
  PopupStacks : array[1..MaxPopups] of Pointer;

  {Flags to indicate popups that need access to DOS}
  DosWaitFlags : array[1..MaxPopups] of Boolean;

  {Table linking scan codes to their associated popups}
  PopupKeys : array[0..MaxScanCode] of Byte;

  {contains the high byte of each popup's hotkey}
  ShiftKeys : array[0..MaxScanCode] of Byte;

  procedure Save3Fvector; forward;

  function ParagraphsToKeep : Word;
    {-Returns # of paragraphs currently used for code, data, stack, and heap.}
  begin
    {keep everything from PSP to top of heap}
    ParagraphsToKeep := Succ(Seg(HeapPtr^)-PrefixSeg);
  end;

{$IFNDEF Heap6} {!!.11}
  function HeapEnd : Pointer;
    {-Returns a pointer to the end of the free list}
  begin
    if Ofs(FreePtr^) = 0 then
      {Free list is empty}
      HeapEnd := Ptr(Seg(FreePtr^)+$1000, 0)
    else
      HeapEnd := Ptr(Seg(FreePtr^)+Ofs(FreePtr^) shr 4, Ofs(FreePtr^) and $F);
  end;
{$ENDIF}        {!!.11}

  function PtrDiff(H, L : Pointer) : LongInt;
    {-Return the number of bytes between H^ and L^. H is the higher address}
  var
    High : SegOfs absolute H;
    Low : SegOfs absolute L;
  begin
    PtrDiff := (LongInt(High.S) shl 4+High.O)-(LongInt(Low.S) shl 4+Low.O);
  end;

  procedure PopupsOn;
    {-Turns popups on}
  const
    Saved3F : Boolean = False;
  begin
    PopupsEnabledPtr^ := True;

    if not Saved3F then begin
      {save the current INT $3F vector}
      Save3Fvector;
      Saved3F := True;
    end;
  end;

  procedure PopupsOff;
    {-Turns popups off}
  begin
    PopupsEnabledPtr^ := False;
  end;

  function ChangeHotKey(OldHotKey, NewHotKey : Word) : Boolean;
    {-Change a hotkey from OldHotKey to NewHotKey}
  var
    Handle : Byte;
    OldScan : Byte absolute OldHotKey;
    NewScan : Byte absolute NewHotKey;
  begin
    ChangeHotKey := False;
    case NewScan of            {!!.09}
      1..MaxScanCode : {ok} ;  {!!.09}
      else Exit;               {!!.09}
    end;                       {!!.09}
    case Lo(OldHotKey) of
      1..MaxScanCode :
        if (PopupKeys[OldScan] <> 0) and
        ((OldScan = NewScan) or (PopupKeys[NewScan] = 0)) then begin
          {with interrupts off, switch hot keys}
          InterruptsOff;

          {get rid of the current assignment}
          Handle := PopupKeys[OldScan];
          PopupKeys[OldScan] := 0;
          ShiftKeys[OldScan] := 0;

          PopupKeys[NewScan] := Handle;
          ShiftKeys[NewScan] := Hi(NewHotKey);
          InterruptsOn;
          ChangeHotKey := True;
        end;
    end;
  end;

  procedure DeletePop(HotKey : Word);
  {-Deletes the popup routine associated with HotKey.  Its handle may then
    be used for other popups.}
  begin
    case Lo(HotKey) of
      1..MaxScanCode :
        if (PopupKeys[Lo(HotKey)] <> 0) then begin
          {with interrupts off, disable the popup}
          InterruptsOff;
          PopupAddrs[PopupKeys[Lo(HotKey)]] := nil;
          PopupKeys[Lo(HotKey)] := 0;
          ShiftKeys[Lo(HotKey)] := 0;
          InterruptsOn;
        end;
    end;
  end;

  function DefinePopProc(var Handle : Byte; Routine, StackPtr : Pointer) : Boolean;
  {-Defines a routine that can be triggered by calling SetPopTicker. Returns
    false if no more Popup handles are available.}
  var
    B : Byte;
  begin
    {search for an available handle}
    for B := 1 to MaxPopups do
      if (PopupAddrs[B] = nil) then begin
        {assign the handle}
        Handle := B;

        {install the popup}
        PopupAddrs[B] := Routine;
        PopupStacks[B] := StackPtr;
        PopupInUse[B] := False;

        {assume that waiting is necessary}
        DosWaitFlags[B] := True;

        {signal success}
        DefinePopProc := True;
        Exit;
      end;

    {if we get to here we failed}
    DefinePopProc := False;
  end;

  procedure DeletePopProc(Handle : Byte);
  {-Deletes a popup routine defined with DefinePopProc.  Its handle may then
    be used for other popups.}
  begin
    case Handle of
      1..MaxPopups : PopupAddrs[Handle] := nil;
    end;
  end;

  function DefinePop(HotKey : Word; Routine, StackPtr : Pointer;
                     DosWait : Boolean) : Boolean;
  {-Defines a popup routine associated with a particular hotkey. Returns
    False if no more Popup handles are available.}
  var
    B : Byte;
  begin
    {assume failure}
    DefinePop := False;

    case Lo(HotKey) of
      1..MaxScanCode :
        if PopupKeys[Lo(HotKey)] = 0 then
          if DefinePopProc(B, Routine, StackPtr) then begin
            {set the DOS wait flag}
            DosWaitFlags[B] := DosWait;

            {set the shift key}
            ShiftKeys[Lo(HotKey)] := Hi(HotKey);

            {If popups are on, next statement makes this one active}
            PopupKeys[Lo(HotKey)] := B;
            DefinePop := True;
          end;
    end;
  end;

  procedure SetPopTicker(Handle : Byte; TimeOut : Word);
    {-Sets the pop ticker for the indicated procedure, clears interrupts,
      then returns.  No range checking is performed.}
  begin
    if PopupsEnabledPtr^ then
      if (PopupAddrs[Handle] <> nil) and not PopupInUse[Handle] then begin
        {Turn interrupts off}
        InterruptsOff;

        if PopTickerPtr^ <> 0 then
          PopupInUse[PopupToCallPtr^] := False;
        PopupInUse[Handle] := True;
        PopupToCallPtr^ := Handle;
        PopTickerPtr^ := TimeOut;
      end;
  end;

  procedure RemovePops;
    {-Disables all popups and releases all interrupt vectors.}
  begin
    PopupsOff;
    RestoreAllVectors;
    Initialized := False;
  end;

  {$L TPTSR.OBJ}

  {see TPTSR.ASM for documentation}
  procedure Int9; external;
  procedure Int28; external;
  procedure Int8; external;
  procedure Int5; external;
  procedure Int10; external;
  procedure Int13; external;
  procedure Int14; external;
  procedure Int16; external;
  procedure Int17; external;
  procedure Int25; external;
  procedure Int26; external;
  procedure EmergencyExit; external;
    {-Called by exit/error handler in case of runtime error while popped up}
  procedure Save3Fvector; external;

  function INT24Result : Word; external;
  procedure InitTsrPtrs; external;
    {-Initializes pointers to hidden variables and pointers that indicate when
      DOS is active.}
  function DosBusyFlag : Byte; external;
    {-Returns current value of DOS busy flag}
  function DosCriticalFlag : Byte; external;
    {-Returns current value of DOS critical flag}

  function IoResultPrim : Byte;
    {-Calls IoResult for Int24Result}
  begin
    IoResultPrim := IoResult;
  end;

  {!!.11} {Various changes for Heap6}
  function TerminateAndStayResident(ParasToKeep : Word; ExitCode : Byte) : Boolean;
  {-Terminate and stay resident, freeing up all memory except ParasToKeep.
    Returns False if unable to release memory.}
  var
    TopOfMem : Pointer;
    MaxParas : Word;
{$IFDEF Heap6}
    SaveHeapEnd : Pointer;
{$ELSE}
    SaveFreePtr,
    NewFreePtr : Pointer;
    NewFreeSeg,
    FreeListSize : Word;
{$ENDIF}
    Regs : Registers;
  begin
    {if we return from this call, we failed to go resident}
    TerminateAndStayResident := False;

    {exit if SideKick is loaded and couldn't be thwarted}
    if SideKickLoaded then
      Exit;

    {reject requests for less than the bare minimum or more than the maximum}
    TopOfMem := Ptr(PrefixSeg, 2);
    MaxParas := Word(TopOfMem^)-PrefixSeg;
    if (ParasToKeep < ParagraphsToKeep) or (ParasToKeep > MaxParas) then
      Exit;

{$IFDEF Heap6}
    SaveHeapEnd := HeapEnd;
    HeapEnd := Ptr(PrefixSeg+ParasToKeep, 0);
{$ELSE}
    {Calculate the number of bytes to move}
    FreeListSize := PtrDiff(TopOfHeap, HeapEnd);

    {save the current value of FreePtr}
    SaveFreePtr := FreePtr;

    {calculate new location of the free list}
    NewFreeSeg := (PrefixSeg+ParasToKeep)-$1000;
    if FreeListSize = 0 then
      NewFreePtr := Ptr(NewFreeSeg, 0)
    else
      NewFreePtr := Ptr(NewFreeSeg, Ofs(FreePtr^));

    {Move the free list down}
    if FreeListSize <> 0 then
      Move(FreePtr^, NewFreePtr^, FreeListSize);
    FreePtr := NewFreePtr;
{$ENDIF}

    {set flag for error/exit handler}
    WentResident := True;

    {restore vectors captured by runtime library}
    SetIntVec($00, SaveInt00);
    SetIntVec($02, SaveInt02);
    {$IFNDEF Ver40}
    SetIntVec($1B, SaveInt1B);
    {$ENDIF}
    SetIntVec($23, SaveInt23);
    SetIntVec($24, SaveInt24);
    {$IFNDEF Ver40}
    SetIntVec($34, SaveInt34);
    SetIntVec($35, SaveInt35);
    SetIntVec($36, SaveInt36);
    SetIntVec($37, SaveInt37);
    SetIntVec($38, SaveInt38);
    SetIntVec($39, SaveInt39);
    SetIntVec($3A, SaveInt3A);
    SetIntVec($3B, SaveInt3B);
    SetIntVec($3C, SaveInt3C);
    SetIntVec($3D, SaveInt3D);
    SetIntVec($3E, SaveInt3E);
    SetIntVec($3F, SaveInt3F);
    {$ENDIF}
    SetIntVec($75, SaveInt75);

    {go resident}
    Regs.AH := $31;          {DOS Keep function}
    Regs.AL := ExitCode;     {return code for DOS}
    Regs.DX := ParasToKeep;  {paragraphs to keep}
    MsDos(Regs);

    {if we get this far, we failed, so restore FreePtr}
{$IFDEF Heap6}
    HeapEnd := SaveHeapEnd;
{$ELSE}
    FreePtr := SaveFreePtr;
{$ENDIF}
    WentResident := False;
  end;

  procedure InitPops;
    {-Must be called before any other popup specific routines.}

    {$IFDEF ThwartSideKick}
  type
    Array4 = array[0..3] of Char;   {!!.09}
    {$ENDIF}

  const
    {                I B K S}
    SideKickFlag = $49424B53;
    SideKickPlus = $CB;

    {$IFDEF ThwartSideKick}
    SideKickCode : Array4 = (       {!!.09}
      #$8C, #$CB,  {MOV  BX,CS}
      #$3B, #$C3); {CMP  AX,BX}
     {#$74          JZ   xxxx <-- if found, change the JZ to a JMP SHORT}
    {$ENDIF}

  var
    P : Pointer;
    PSO : SegOfs absolute P;
    {$IFDEF ThwartSideKick}
    PA4 : ^Array4;                  {!!.09}
    I : Word;
    {$ENDIF}

    procedure InitVectorPrim(IntNumber, Handle : Byte; UserRoutine : Pointer);
      {-Sets up an interrupt service routine}
    begin
      if not InitVector(IntNumber, Handle, UserRoutine) then begin
        WriteLn('Unable to install TSR manager');
        Halt(1);
      end;
    end;

  begin
    {don't do this twice}
    if Initialized then
      Exit;

    {test for SideKick: 'SKBI' just before start of INT $8 handler. A RETF
     instruction just before SKBI signals SideKickPlus, which we can load
     after.}
    GetIntVec($08, P);
    SideKickLoaded :=
      (MemL[PSO.S:PSO.O-4] = SideKickFlag) and
      (Mem[PSO.S:PSO.O-5] <> SideKickPlus);

    {$IFDEF ThwartSideKick}                {!!.09} {whole section changed}
    if SideKickLoaded then begin
      {see if we can thwart its INT 9 grabber so we can go resident}
      PA4 := P;
      {search for the tell-tale code}
      for I := 0 to 100 do begin
        {have we found it?}
        if PA4^ = SideKickCode then begin
          {if so, disable the INT 9 grabber...}
          Inc(Word(PA4), 4);
          {make sure it's OK to change it}
          if (PA4^[0] = #$74) or (PA4^[0] = #$EB) then begin
            InterruptsOff;
            PA4^[0] := #$EB; {turn the conditional jump into a short jump}
            InterruptsOn;

            {...and clear the SideKick flag}
            SideKickLoaded := False;
          end;
        end;
        Inc(Word(PA4));
      end;
    end;
    {$ENDIF}

    {Initialize our tables}
    FillChar(PopupAddrs, SizeOf(PopupAddrs), 0);
    FillChar(PopupStacks, SizeOf(PopupStacks), 0);
    FillChar(PopupInUse, SizeOf(PopupInUse), 0);
    FillChar(PopupKeys, SizeOf(PopupKeys), 0);
    FillChar(ShiftKeys, SizeOf(ShiftKeys), 0);
    FillChar(DosWaitFlags, SizeOf(DosWaitFlags), 0);

    {do low-level initialization}
    InitTsrPtrs;

    {initialize our interrupt vectors}
    InitVectorPrim($05, Int5Handle, @Int5);
    InitVectorPrim($08, Int8Handle, @Int8);
    InitVectorPrim($09, Int9Handle, @Int9);
    InitVectorPrim($13, Int13Handle, @Int13);
    InitVectorPrim($16, Int16Handle, @Int16);
    InitVectorPrim($25, Int25Handle, @Int25);
    InitVectorPrim($26, Int26Handle, @Int26);
    InitVectorPrim($28, Int28Handle, @Int28);

    {don't filter the following interrupts unless we're running under OS/2}
    if Hi(DosVersion) >= 10 then begin
      InitVectorPrim($10, Int10Handle, @Int10);
      InitVectorPrim($14, Int14Handle, @Int14);
      InitVectorPrim($17, Int17Handle, @Int17);
    end;

    Initialized := True;
  end;

  function GetLastModulePtr : Pointer;
    {-Return a pointer to the last TPRO TSR loaded before us}
  var
    FoundIfc : Boolean;
    P : IfcPtr;
    IACAptr : Pointer absolute $40:$F0;
    SaveIACA : Pointer;
  begin
    {assume failure}
    P := nil;
    SaveIACA := IACAptr;
    IACAptr := nil;
    FoundIfc := False;                                    {!!.12}

    {since Intr() in TP 4.0 is not re-entrant, and this might be called from
     inside a popup, we use inline}
    inline(
      $B8/>IfcSignature/     {mov ax,>IfcSignature   ;standard interface function code}
      $31/$FF/               {xor di,di              ;es:di = nil}
      $8E/$C7/               {mov es,di}
      $CD/$16/               {int $16                ;call INT 16}
      $F7/$D0/               {not ax                 ;flip bits}
      $3D/>IfcSignature/     {cmp ax,>IfcSignature   ;AX = IfcSignature only if INT 16 flipped bits}
      $75/$1E/               {jne Done               ;Ifc handler not found?}
      $8C/$C0/               {mov ax,es              ;use second method if es:di = nil}
      $09/$F8/               {or ax,di}
      $74/$08/               {jz NotFound}
      $89/$7E/<P/            {mov [bp+<P],di         ;offset of list pointer in P}
      $8C/$46/<P+2/          {mov [bp+<P+2],es       ;segment of list pointer in P}
      $EB/$0C/               {jmp short Found}
                             {NotFound:              ;try second method - SuperKey can defeat the first}
      $B8/>IfcSignature2/    {mov ax,>IfcSignature2  ;secondary function code}
      $CD/$16/               {int $16                ;call INT 16}
      $F7/$D0/               {not ax                 ;AX = not AX}
      $3D/>IfcSignature2/    {cmp ax,>IfcSignature2  ;AX = IfcSignature2?}
      $75/$04/               {jne Done               ;Ifc handler not found?}
                             {Found:}
      $C6/$46/<FoundIfc/$01);{mov [bp+<FoundIfc],1   ;set Found flag}
                             {Done:}

      if not FoundIfc then
        GetLastModulePtr := nil
      else if P <> nil then
        GetLastModulePtr := P
      else
        GetLastModulePtr := IACAptr;

      {restore intra-applications comm. area}
      IACAptr := SaveIACA;
  end;

  procedure InstallModule(var ModuleName : string; CmdEntryRoutine : Pointer);
  {-Installs this program as a resident module that can be located and
    accessed by other programs.}
  var
    P : IfcPtr;
  begin
    if not IfcInstalled then
      with ThisIfc do begin
        {see if anyone else is home}
        P := GetLastModulePtr;
        if P <> nil then begin
          P^.NextIfc := @ThisIfc;
          PrevIfc := P;
        end
        else
          PrevIfc := nil;

        {initialize the other fields in the record}
        NamePtr := @ModuleName;
        NextIfc := nil;
        Version := IfcVersion;
        if CmdEntryRoutine = nil then
          CmdEntryPtr := @IRET
        else
          CmdEntryPtr := CmdEntryRoutine;

        IfcInstalled := True;
      end;
  end;

  procedure UninstallModule;
    {-Uninstalls the module from the linked list of modules.}
  begin
    if IfcInstalled then
      with ThisIfc do begin
        {fix the linked list of modules}
        if PrevIfc <> nil then
          PrevIfc^.NextIfc := NextIfc;
        if NextIfc <> nil then
          NextIfc^.PrevIfc := PrevIfc;
        IfcInstalled := False;
      end;
  end;

  function ModulePtrByName(var ModuleName : string) : IfcPtr;
    {-Returns a pointer to the IfcRecord for the module named ModuleName or Nil.}
  var
    P : IfcPtr;
  begin
    {get pointer to previous module}
    P := GetLastModulePtr;
    ModulePtrByName := nil;

    {search backward through the list}
    while (P <> nil) do
      with P^ do
        if NamePtr^ = ModuleName then begin
          ModulePtrByName := P;
          Exit;
        end
        else
          P := P^.PrevIfc;
  end;

  function ModuleInstalled(var ModuleName : string) : Boolean;
    {-Returns true if ModuleName is installed.}
  begin
    {let ModulePtrByName do the searching}
    ModuleInstalled := ModulePtrByName(ModuleName) <> nil;
  end;

  function DisableTSR : Boolean;
    {-Disable TSR by restoring interrupt vectors and releasing memory. This
      does *not* halt the program. Returns false if it's not safe.}
  var
    Regs : Registers;
    Safe : Boolean;
    I : Word;
    P : Pointer;
    VecsGrabbed : set of Byte;
  begin
    {see if it's safe to disable the TSR}
    Safe := WentResident;

    {initialize VecsGrabbed entries to false}
    FillChar(VecsGrabbed, SizeOf(VecsGrabbed), 0);

    {go backwards, looking for changed vectors that have been grabbed only once}
    for I := MaxIsrs downto 1 do
      with ISR_Array[I] do
        if Captured then begin
          GetIntVec(IntNum, P);
          if (IntNum <> 5) and (P <> NewAddr) and not(IntNum in VecsGrabbed) then
            Safe := False;
          VecsGrabbed := VecsGrabbed+[Lo(IntNum)];
        end;

    {don't disable if it's not safe}
    DisableTSR := Safe;
    if not Safe then
      Exit;

    {disable popups and restore any other vectors taken over}
    PopupsOff;
    Initialized := False;
    RestoreAllVectors;
    UninstallModule;

    with Regs do begin
      {close all file handles, ignoring error codes}
      for I := 0 to 19 do begin
        AH := $3E;           {close file handle function}
        BX := I;             {handle}
        MsDos(Regs);
      end;

      {release environment}
      AH := $49;             {free allocated memory function}
      ES := MemW[PrefixSeg:$2C]; {segment of environment from PSP}
      MsDos(Regs);

      {release program's memory}
      AH := $49;
      ES := PrefixSeg;
      MsDos(Regs);

   {$IFNDEF StonyBrook}     {!!.13}
   {$IFNDEF Ver40}
   if ReleaseEms then begin
     DX := OvrEmsHandle;
     AH := $45;
     Intr($67, Regs);
   end;
   {$ENDIF}
   {$ENDIF}                 {!!.13}

    end;
  end;

  {$F+}
  procedure TpTsrExit;
    {-Error/exit handler}
  begin
    {restore previous exit handler}
    ExitProc := SaveExitProc;

    {uninstall the module and turn popups off}
    UninstallModule;
    PopupsOff;

    if WentResident then begin                                 {!!.10}
      {try to disable the TSR}                                 {!!.10}
      if DisableTSR then ;                                     {!!.10}

      {try to exit semi-gracefully by calling an ASM routine
       that tries to salvage the system}
      EmergencyExit;                                           {!!.10}
    end;                                                       {!!.10}
  end;
  {$F-}

begin
  {initialize interface record}
  FillChar(ThisIfc, SizeOf(ThisIfc), 0);

  {save top of heap for later}
{$IFDEF Heap6}                               {!!.11}
  TopOfHeap := HeapEnd;                      {!!.11}
{$ELSE}                                      {!!.11}
  TopOfHeap := Ptr(Seg(FreePtr^)+$1000, 0);
{$ENDIF}                                     {!!.11}

  {save SSeg for later}
  SaveSSeg := SSeg;

  {prepare for popups}
  InitPops;

  {set up error/exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @TpTsrExit;
end.
