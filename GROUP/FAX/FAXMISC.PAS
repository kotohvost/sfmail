
unit FaxMisc;

INTERFACE

uses
 Dos;

const
 MaxLines=4000;
 LineBufSize=512;
 MaxTreeRec=306;             {Maximum number of tree records}
 MaxData=4096;               {Max size of decompress buffer}

 PrnBufSize=2048;            {Print buffer size}
 PackBufSize=9216;           {Pack buffer size}

 DoubleIt:boolean=false;

(* MaxLnsPerPage=?;            { max raster lines/page }*)

 { PCL printer command strings }
 pclInit      :string[2]=#27'E';       {Init command}
 pcl300dpi    :string[7]=#27'*t300R';  {Enable 300 dpi mode}
 pcl150dpi    :string[7]=#27'*t150R';  {Enable 150 dpi mode}
 pclStartGraph:string[5]=#27'*r0A';    {Start raster graphics}
 pclEndGraph  :string[4]=#27'*rB';     {End raster graphics}
 pclXferS     :string[3]=#27'*b';      {Start data block command}
 pclXferE     :string[1]='W';          {End data block command}
 pclTiffMode  :string[5]=#27'*b2M';    {Enable TIFF compression}
 pclDeltaMode :string[5]=#27'*b3M';    {Enable delta compression}
 pclRepLine   :string[5]=#27'*b0W';    {Repeat previous line}
 pclBlankS    :string[3]= #27'*b';     {Start blank line command}
 pclBlankE    :string[1]='Y';          {End blank line command}
 pclSetMargin :string[5]=#27'&l1E';    {Set margin to first raster}

type
 SigArray=array[0..5] of char;       {Fax file signature array}

 TreeRec=record
  Next0:integer;
  Next1:integer;
 end;
 TreeArray=array[0..MaxTreeRec] of TreeRec;
 TreePtr=^TreeArray;

 { line list }
 pLine=^tLine;
 tLine=array[0..$FFF0] of byte;

 pNode=^tNode;
 tNode=record
  Data:pLine;
  Len:word;
 end;

 pList=^tList;
 tList=record
  Lines  :array[1..MaxLines] of pNode;
  LineCnt:word;
 end;

 {Generic byte buffer type}
 pByteBuffer=^tByteBuffer;
 tByteBuffer=array[0..$FFF0] of byte;

 pUnpacker=^tUnpacker;
 tUnpacker=record
  CurCode   :word;
  CurSig    :word;
  LineOfs   :word;            {current offset in line}
  LineBit   :word;            {current offset in byte}
  CurPage   :word;            {current page}
  Flags     :word;            {option flags}
  BadCodes  :word;            {number of bad codes}
  TreeLast  :integer;
  TreeNext  :integer;
  Match     :integer;
  WhiteTree :TreePtr;         {tree of White runlength codes}
  BlackTree :TreePtr;         {tree of black runlength codes}
  LineBuffer:pByteBuffer;     {buffer for decompression}
  FileBuffer:pByteBuffer;     {file I/O buffer}
  HalfWidth :boolean;         {True if halfwidth option set}
  UseLengthWords:boolean;
  Inverted  :boolean;         {true if view inverted view}
  NeedRedraw:boolean;
  { print controls }
  fPrn:file;
  PrintTo:PathStr;   { output fax to }
  PrnBufCnt:word;    { characters in the print buffer }
  PrintedLns:word;   { num of printed lines }
  PrnBuf:pByteBuffer;
  PackBuf:pByteBuffer;
 end;

 {APRO fax file header record}
 tFaxHeader=record
   Signature:SigArray;               {APRO FAX signature}
   FDateTime:longint;                {Date and time in DOS format}
   SenderID :string[20];             {Station ID of sender}
   Filler   :byte;                   {Alignment byte, unused}
   PageCount:word;                   {Number of pages in this file}
   PageOfs  :longint;                {Offset in file of first page}
   Padding  :array[39..64] of byte;  {Expansion room}
 end;

 {APRO fax page header record}
 tPageHeader=record
  ImgLength:longint;                 {Bytes of image data in this page}
  ImgFlags :word;                    {Image flags for width, res, etc}
  Padding  :array[7..16] of byte;    {Expansion room}
 end;

var
 FaxHeader:tFaxHeader;
 PageHeader:tPageHeader;
 Unpacker:pUnpacker;
 RasterList:tList;

procedure PrintTheFax;
procedure InverseTheFax;
procedure ShowDebugInfo;

IMPLEMENTATION

uses
 tString_,
 TpCrt,
 uvCrt,
 uvWin;

type
 pGauge=^tGauge;
 tGauge=record
  Win:WindowPtr;
  TotalSize,               { total size }
  CurrPos:word;            { current pos }
 end;

procedure ShowDebugInfo;
var
 win:WindowPtr;
 w,n:word;

begin
 uvMakeWindow(win,1,1,25,5,true,true,true,
              dcmNormal,dcmInvert,dcmBold,'Debug info');
 uvDisplayWindow(Win);
 with Unpacker^ do begin
  uvWriteWin('Hight res:',1,2,dcmNormal);
  if DoubleIt then
   uvWriteWin('YES',1,13,dcmBold)
  else
   uvWriteWin('NO',1,13,dcmBold);
  w:=0;
  for n:=1 to RasterList.LineCnt do
    if RasterList.Lines[n]^.Len >w then
      w:=RasterList.Lines[n]^.Len;
  uvWriteWin('Max width:',2,2,dcmNormal);
  uvWriteWin(Long2str(w),2,14,dcmBold);
 end;
 ReadKey;
 uvDisposeWindow(uvEraseTopWindow);
end;

function NonZeroLen(var Src; Len:word):word; assembler;
{-Return number of leading non-zero bytes in Src}
asm
    mov   cx,Len
    jcxz  @2           {get out for zero length}
    les   di,Src       {ES:DI = buffer}
    add   di,cx
    dec   di           {di -> last valid byte}
    std                {backwards}
    xor   al,al
    repe  scasb
    cld                {in case someone else counts on cld}
    jnz   @1           {jump if any non-zeros found}
    mov   cx,-1        {force return of zero}
@1: inc   cx
@2: mov   ax,cx
end;

procedure SetRawMode(var f:file; On:boolean); assembler;
{-Set "raw" mode on or off for the specified file (must be a device)}
asm
    les   di,F
    mov   bx,es:[di]   { bx = file handle    }
    mov   ax,$4400     { get device info     }
    int   $21
    jc    @9           { jump if error       }
    xor   ax,ax        { clear error code    }
    test  dl,$80       { is a device?        }
    jz    @9           { jump if not         }
    and   dx,$00AF     { clear unwanted bits }
    or    dl,$20       { assume raw mode     }
    cmp   On,0         { is On non-zero?     }
    jne   @1           { jump if On = True   }
    and   dl,$DF
@1: mov   ax,$4401     { set device info     }
    int   $21
    jc    @9           { jump if error       }
    xor   ax,ax        { clear error code    }
@9: mov   DosError,ax
end;

{ Abstract print routines }
procedure Prn_Open;
begin
 with Unpacker^ do begin
  GetMem(PrnBuf,PrnBufSize);
  GetMem(PackBuf,PackBufSize);
  assign(fPrn,'prn');
  rewrite(fPrn,1);
  if IoResult <>0 then exit;
  SetRawMode(fPrn,true);
  { Init to show an empty print buffer }
  PrnBufCnt:=0;
 end;
end;

procedure Prn_FlushBuf;
begin
 with Unpacker^ do begin
  { Send current buffer contents }
  BlockWrite(fPrn,PrnBuf^[0],PrnBufCnt);
  if IoResult <>0 then;
  { Clear buffer contents counter }
  PrnBufCnt:=0;
  { Call user hook
  if CallWriteNotify(PrnBufCount) then
   SetAsyncStatus(ecUserAbort);}
 end;
end;

procedure Prn_Close;
begin
 with Unpacker^ do begin
  { Flush remaining data in buffer }
  if PrnBufCnt >0 then
   Prn_FlushBuf;
  { Close the device/file }
  Close(fPrn);
  if IoResult <>0 then {};
  FreeMem(PrnBuf,PrnBufSize);
  FreeMem(PackBuf,PackBufSize);
 end;
end;

procedure Prn_PrintData(var Data; Size:word);
var
 BytesToPrint:word;
 ByteOfs:word;

begin
 with Unpacker^ do begin
  ByteOfs:=0;
  repeat
   { Limit block to PrnBufSize }
   if Size >PrnBufSize then
    BytesToPrint:=PrnBufSize
   else
    BytesToPrint:=Size;

   { Dump buffer to output if the block won't fit }
   if PrnBufCnt+BytesToPrint >PrnBufSize then
     Prn_FlushBuf;

   { Move this data into the print buffer }
   Move(tByteBuffer(Data)[ByteOfs],PrnBuf^[PrnBufCnt],BytesToPrint);

   Inc(PrnBufCnt,BytesToPrint);
   Inc(ByteOfs,BytesToPrint);
   Dec(Size,BytesToPrint);
  until Size =0;
 end;
end;

{---------- HP_Printer object ----------}
procedure HP_PrintData(var Data; Size:word);
var
 S:string[21];
 i:integer;

begin
 with Unpacker^ do begin
  { Any pending blank lines are printed first }
  (***
  if (BlankLinesToPrint > 0) then begin
   if fpOptionsAreOn(fpPrinter, fpSuppressBlanks) then begin
    if BlankLinesToPrint > MinBlankSpace then begin
     { Reduce the running line count by this amount }
     Dec(PrintedLineCount, BlankLinesToPrint - MinBlankSpace);
     BlankLinesToPrint := MinBlankSpace;
    end;
   end;
   s:=pclXferS+'0'+pclXferE;
   for i:=1 to BlankLinesToPrint do
    Prn_PrintData(s[1],length(s));
   { Clear blank line count }
   BlankLinesToPrint:=0;
  end;
  ***)

  { Call ancestor to do the rest }
  Prn_PrintData(Data,Size);
 end;
end;

procedure HP_PrintStr(s:string);
begin
 HP_PrintData(s[1],length(s));
end;

procedure HP_StartNewPage;
var
 i:byte;

begin
 with Unpacker^ do begin
  HP_PrintStr(pclInit);
  (*HP_PrintStr(pclSetMargin+pcl150DPI);*)
  HP_PrintStr(pclSetMargin+pcl300DPI);
  { Print header line }
  HP_PrintStr('* Dis fax was printed via SantaFox Fax printing utility *');
  { Start graphics mode }
  HP_PrintStr(pclStartGraph);
  { print some blank lines }
  for i:=1 to 4 do
   HP_PrintStr(#27'*b0W');
  { underscore header line }
  FillChar(PackBuf^,150,#$252);
  HP_PrintStr(#27'*b150W');
  HP_PrintData(PackBuf^,150);
  PrintedLns:=0;
 end;
end;

procedure HP_PrintOpen;
begin
 Prn_Open;
 HP_StartNewPage;
end;

procedure HP_PrintClose;
begin
 HP_PrintStr(pclEndGraph+pclInit);
 Prn_Close;
end;

procedure InverseTheFax;
var
 y,x:word;

begin
 with RasterList do
  for y:=1 to LineCnt do
    if (Lines[y] <>nil) and (Lines[y]^.Len <>0) then with Lines[y]^ do
      for x:=0 to Len-1 do
        Data^[x]:=not Data^[x];
 Unpacker^.NeedRedraw:=true;
end;

procedure Gauge_Init(var pg:pGauge; Total:word; Caption:string);
begin
 New(pg);
 FillChar(pg^,SizeOf(tGauge),0);
 with pg^ do begin
  if not uvMakeWindow(Win,20,12,60,16,true,true,true,
                      dcmNormal,dcmInvert,
                      dcmBold,Caption) then write(^G);
  uvDisplayWindow(Win);
  TotalSize:=Total;
 end;
end;

procedure Gauge_Inc(pg:pGauge; n:word);
const
 allCube=30;

var
 s:string[30];
 w:word;

begin
 s:=CharStr('°',allCube);
 with pg^ do begin
  Inc(CurrPos,n);
  w:=(CurrPos*allCube) div TotalSize;
  if w >allCube then
   w:=allCube;
  FillChar(s[1],w,'Û');
  uvWriteWin(s,1,5,dcmNormal);
 end;
end;

procedure Gauge_Done(var pg:pGauge);
begin
 if pg <>nil then begin
  uvDisposeWindow(uvEraseTopWindow);
  Dispose(pg);
  pg:=nil;
 end;
end;

function HP_ScaleRasterLine(var Data; Len:word):word;
var
 newLen:word;
 i:word;
 n:byte;
 l:longint;
 a:array[1..4] of byte absolute l;
 b:array[1..3] of byte;

begin
 if DoubleIt then begin
  newLen:=0;
  i:=0;
  Dec(Len);
  while i <Len do begin
   l:=0;
   b[1]:=tByteBuffer(Data)[i];
   Inc(i);
   if i <Len then
    b[2]:=tByteBuffer(Data)[i]
   else
    b[2]:=0;
   Inc(i);
   if i <Len then
    b[3]:=tByteBuffer(Data)[i]
   else
    b[3]:=0;
   Inc(i);
   { converting }
   a[4]:=b[1] and $3F;
   a[3]:=((b[1] and $C0) shr 6)+((b[2] and $0F) shl 2);
   a[2]:=((b[2] and $F0) shr 4)+((b[3] and $03) shl 4);
   a[1]:=(b[3] and $FC) shr 2;
   for n:=4 downto 1 do
    a[n]:=(a[n] and $03) or ((a[n] and $02) shl 1) or
          ((a[n] and $0C) shl 1) or ((a[n] and $08) shl 2) or
          ((a[n] and $30) shl 2);
   Move(l,Unpacker^.PackBuf^[newLen],4);
   Inc(newLen,4);
  end;
  HP_ScaleRasterLine:=newLen;
 end
 else begin
 end;
end;

procedure PrintTheFax;
var
 w:word;
 ScaledLen:word;
 Gauge:pGauge;

begin
 HP_PrintOpen;
 with Unpacker^ do begin
  Gauge_Init(Gauge,RasterList.LineCnt,#242#243'        Now printing fax..        '#244#245);
  if not Inverted then
   InverseTheFax;
  for w:=1 to RasterList.LineCnt do begin
    if RasterList.Lines[w] =nil then
     HP_PrintStr(#27'*b0W')
    else with RasterList.Lines[w]^ do begin
     if NonZeroLen(Data^,Len) =0 then
      HP_PrintStr(#27'*b0W')
     else begin
      ScaledLen:=HP_ScaleRasterLine(Data^,Len);
      HP_PrintStr(#27'*b'+Long2str(ScaledLen)+'W');
      HP_PrintData(PackBuf^,ScaledLen);
     end;
    end;
    Gauge_Inc(Gauge,1);
  end;
 end;
 HP_PrintClose;
 Gauge_Done(Gauge);
 if not Unpacker^.Inverted then
  InverseTheFax;
end;

end.
