{$X+,I-,O+,F+}
UNIT Sf_Dbg;

INTERFACE

procedure ShowOurFiles;

IMPLEMENTATION

uses
 EmStruct,
 TString_,
 TpWindow,
 TpCrt;

type
 tHandleRec=record
   numRefer:word; {00h    WORD    number of file handles referring to this file}
                  {FFFFh if in use but not referenced}
   openMode:word; {02h    WORD    file open mode (see AX=6C00h,#0627 at AH=3Dh)}
                  {bit 15 set if this file opened via FCB}
   fileAttr:byte; {04h    BYTE    file attribute (see #0643 at AX=4301h)}
   deviceInfo:word; {05h    WORD    device info word (see also #0646 at AX=4400h)
                  bit 15 set if remote file
                  bit 14 set means do not set file date/time on closing
                  bit 13 set if named pipe
                  bit 12 set if no inherit
                  bit 11 set if network spooler
                  bit 7  set if device, clear if file (only if local)
                  bits 6-0 as for AX=4400h}
   pDeviceDrv:pointer; {07h    DWORD   pointer to device driver header if character device}
                       {else pointer to DOS Drive Parameter Block}
                       {(see #0620 at AH=32h) or REDIR data}
   startCluster:word; {0Bh    WORD    starting cluster of file (local files only)}
   packedTime:word; {0Dh    WORD    file time in packed format (see #0876)}
   packedDate:word; {0Fh    WORD    file date in packed format (see #0877)}
   fileSiz:longint; {11h    DWORD   file size}
   curOfs:longint;  {15h    DWORD   current offset in file (SFT)}
                    {LRU counters (FCB table, two WORDs)}
  {---local file---}
   relativCluster:word;  {19h    WORD    relative cluster within file of last cluster accessed}
   sectors4dire:longint; {1Bh    DWORD   number of sector containing directory entry}
   direPerSector:byte;   {1Fh    BYTE    number of dir entry within sector (byte offset/32)}
  {---network redirector---}
  (* pReDirFis:pointer; {19h    DWORD   pointer to REDIRIFS record}
   bRsrvd:array[1..3] of byte;       {1Dh  3 BYTEs   ???}
   {dummy:array[1..6] of byte;} *)
  {------}
   {20h 11 BYTEs   filename in FCB format (no path/period, blank-padded)}
   fileName:array[1..11] of char;
   prevSFT:pointer; {2Bh    DWORD   (SHARE.EXE) pointer to previous SFT sharing same file}
   netNum:word; {2Fh    WORD    (SHARE.EXE) network machine number which opened file}
                {(Windows Enhanced mode DOSMGR uses the virtual machine}
                {ID as the machine number; see INT 2F/AX=1683h)}
   ownerPSPseg:word; {31h    WORD    PSP segment of file's owner (see #0603 at AH=26h)}
                     {(first three entries for AUX/CON/PRN contain segment}
                     {of IO.SYS startup code)}
   shareRecOfs:word; {33h    WORD    offset within SHARE.EXE code segment of}
                     {sharing record (see #0808)  0000h = none}
   absCluster:word; {35h    WORD    (local) absolute cluster number of last clustr accessed}
                    {(redirector) ???
   pIFSdrv:pointer; {37h    DWORD   pointer to IFS driver for file, 0000000h if native DOS}
   dummy:array[1..4] of byte;
 end;

 pHandleTbl=^tHandleTbl;
 tHandleTbl=record
  nextHandleTbl:pointer; {00h   DWORD   pointer to next file table (offset FFFFh if last) end;}
  numFiles:word;         {04h   WORD    number of files in this table}
  { 06h  3Bh bytes per file (for 4.0-6.0 DOS) }
  Handles:array[1..255] of tHandleRec;
 end;

 SO=record
  O,S:word;
 end;

procedure ShowOurFiles;
var
 wDbg:WindowPtr;
 p:pointer;
 HandleTbl:pHandleTbl absolute p;
 pSO:SO absolute p;
 i,z,y:byte;
 _done:boolean;
 s:string;

begin
 MakeWindow(wDbg,1,2,80,ScreenHeight-1,true,true,true,
            $87,$87,$8F,' We have files: ');
 DisplayWindow(wDbg);
 {---}
 asm
  mov ah,52h
  int 21h
  mov ax,0FFFFh
  cmp ax,es:[bx+4]
  je  @NoHandleTbl
  mov ax,0FFFFh
  cmp ax,es:[bx+6]
  je  @NoHandleTbl
  mov ax,es:[bx+4]
  mov pSO.O,ax
  mov ax,es:[bx+6]
  mov pSO.S,ax
  mov _done,0
  jmp @Xit
@NoHandleTbl:
  mov _done,1
@Xit:
  nop
 end;
 if not _done then begin
  y:=2;
  repeat
   with HandleTbl^ do begin
    FastWriteWindow('Table contains '+Long2str(numFiles)+' handles',
                    y,2,$8F);
    Inc(y);
    for i:=1 to numFiles do with Handles[i] do begin
     s:='';
     for z:=1 to 11 do s:=s+fileName[z];
     if ownerPSPseg =PrefixSeg then begin
       FastWriteWindow('['+s+']:{'+HexW(openMode)+'} /'+Long2str(numRefer),
                       y,5,$87);
       Inc(y);
     end;
    end;
    if SO(nextHandleTbl).O =$FFFF then
     _done:=true
    else
     Move(nextHandleTbl,p,SizeOf(pointer));
   end;
  until _done;
 end
 else
  FastCenter('This feature not supported by your OS',ScreenHeight div 2,$8E);
 {---}
 ReadScanCode;
 KillWindow(wDbg);
end;

end.
