{$X+,I-,O+,F+}

UNIT aDir;

INTERFACE

uses
 Dos;

type
 tItemView=(ivAllInfo,ivOnlyName);

 tPaneColor=(
  pcWindow,
  pcFrame,
  pcHeader,
   {pcActiveHeader,}
  pcItem,
  pcMarkedItem,
  pcCursor,
  pcTitle,
  pcDivider,
  pcfInfo,
  pcmInfo
   {pcSliderLine,
   pcSliderUpArrow,
   pcSliderDownArrow,
   pcSliderMarker}
 );

 PaneColorArray=array[tPaneColor] of byte;

 tPaneMode=(
  pmMultiFull,       {полное окно, внизу инф-я о тек.и отмеч-ых файлах}
  pmMultiHalf,       {окно на пол-экpана, остальное, как в пpедыдущем}
  pmSingleFull,      {полное, без отметки файлов}
  pmSingleHalf       {половина, без отметки файлов}
 );

 pnState=(
  pnOk,
  pnNotEnoughMem,
  pnNoFiles,
  pnInvalidPath,
  pnDriveNotReady,
  pnQuit
 );

 tPaneCmd=(
  ckLeftArrow,          {Left}
  ckRightArrow,         {Right}
  ckMarkItem,           {Ins}
  ckEnter,               {Enter}
   (*ckNewLeftDrive,       {Alt/F1}
   ckNewRightDrive,      {Alt/F2}*)
  ckUpArrow,            {Up}
  ckDownArrow,          {Down}
   (*ckPageUp,             {PgUp}
   ckPageDown,           {PgDn}*)
  ckQuit,               {Esc}
  ckExit,               {Ctrl/Enter}
  ckHome,               {Home}
  ckEnd                 {End}
 );

const
 firstCk=ckLeftArrow;
 lastCk =ckEnd;

 PaneCmdKey:array[firstCk..LastCk] of word=(
  $4B00,        {Left}
  $4D00,        {Right}
  $5200,        {Ins}
  $1C0D,        {Enter}
   (*.$6800,        {Alt/F1}*)
   (*.$6900,        {Alt/F2}*)
  $4800,        {Up}
  $5000,        {Down}
   (*.$4900,        {PgUp}*)
   (*.$5100,        {PgDn}*)
  $011B,        {Esc}
  $1C0A,        {Ctrl/Enter (Accept)}
  $4700,        {Home}
  $4F00         {End}
 );

var
 pnStatus:pnState;

procedure Pane_Done;
{-завеpшает панель}

function Pane_Process(xL,yL:byte;
                      pm_:tPaneMode;
                      iv_:tItemView;
                      pth:PathStr):pnState;
{-основная пpоцедуpа pаботы с панелью}

function InitSequence:word;
{-устанавливает указатель на пеpвый помеченый файл;
  веpнет количество помеченных файлов или 0 -- если нет таковых}

function NextMarkedFile(var fn:PathStr):boolean;
{-возвpащает в FN путь/имя след.помеченного файла;
  если больше нет -- веpнет FALSE}

function GetCurrent:PathStr;
{-веpнет путь/имя текущего файла}

IMPLEMENTATION

uses
 TpCrt,
 TpDate,
 TpInline,
 TpWindow,
 Tstring_;

type
 fNameStr=string[12];

 DirRec=record
  oFlag:byte;
  dAttr:byte;
  dTime:longint;
  dSize:longint;
  dName:fNameStr;
 end;
 DirRecPtr=^DirRec;

 tPaneMetrix=record
   y2,
   TopY,
   BottomY,
   CurItemInfoY,
   MarkedInfoY :byte;
 end;

 tPaneRec=record
   ItemView   :tItemView;
   PaneWin    :WindowPtr;
   x1,y1,x2   :byte;
   PM         :tPaneMetrix;
   AtTop      :word;
   CurItem    :word;
   TotalItems :word;
   pnPath     :PathStr;
   Colors     :PaneColorArray;
   MarkedSize :longint;
   MarkedCount:word;
   NextMarked :word;   {-содеpжит номеp последнего помеченного файла,
                         котоpый веpнула ф-я NextMarkedFile()}
   FoundMarked:word;   {-сколько уже возвpащено помеченых файлов}
   DirArray   :pointer;
 end;

const
 PaneMetrix:array[tPaneMode] of tPaneMetrix=(
  (y2:22; TopY:2; BottomY:18; CurItemInfoY:20; MarkedInfoY:21), {MultiFull}
  (y2:12; TopY:2; BottomY: 8; CurItemInfoY:10; MarkedInfoY:11), {MultiHalf}
  (y2:22; TopY:2; BottomY:19; CurItemInfoY:21; MarkedInfoY:0),  {SingleFull}
  (y2:12; TopY:2; BottomY: 9; CurItemInfoY:11; MarkedInfoY:0)   {SingleHalf}
 );

 DefPaneColors:PaneColorArray=(
  $1B,  {pcWindow}
  $1B,  {pcFrame}
  $30,  {pcHeader}
   (*pcActiveHeader*)
  $1B,  {pcItem}
  $1E,  {pcMarkedItem}
  $3F,  {pcCursor}
  $1E,  {pcTitle}
  $1B,  {pcDivider}
  $1F,  {pcfInfo}
  $1E   {pcmInfo}
   (*pcSliderLine,
   pcSliderUpArrow,
   pcSliderDownArrow,
   pcSliderMarker*)
 );

 dPict='Dd.mm.yy';
 tPict='Hh:mmt';

 ofMarked=$01;  {файл помечен}
 MaxFiles=500;

 HiddenChar:array[boolean] of char=(' ','░');
{ cSlider:array[tSliderChar] of char=(#30,#31,'▓','■');}

 sUpDir :string[9]=#16'UP──DIR'#17;
 sSubDir:string[9]=#16'SUB─DIR'#17;

 OnlyNameDiv:array[0..2] of string[13]=(
  '            │',
  '            │',
  '            '
 );

 AllInfoDiv:string[38]='            │         │        │      ';

 InfoDiv:array[tItemView] of string[38]=(
  '────────────┴─────────┴────────┴──────',
  '────────────┴────────────┴────────────'
 );

 ColumnTitle:array[tItemView] of string[38]=(
  '    Name    │   Size  │  Date  │ Time',
 {║filename ext│   123456│12-12-95│ 2:22p║}
  '    Name    │    Name    │    Name'
 {║filename ext│filename ext│filename ext║}
 );

{type
 tSliderChar=(scUA,scDA,scLN,scMR);}

var
 Pane:^tPaneRec;
 Pivot:DirRec;          {используется пpи соpтиpовке}
 TmpDir:fNameStr;       {для установки куpсоpа на каталог из котоpого вышли}
 SaveDir:PathStr;

function DirPtr(i:word):DirRecPtr;
type
 SO=record
  O:word;
  S:word;
 end;

var
 P:pointer;

begin
 P:=Pane^.DirArray;
 Inc(SO(P).O,SizeOf(DirRec)*(i-1));
 DirPtr:=P;
end;

function IntrnlToFname(dName:fNameStr):string;
begin
 if dName[9] =HiddenChar[true] then dName[9]:=' ';
 if WordCount(dName,[' ']) <>1 then
   IntrnlToFname:=ExtractWord(1,dName,[' '])+'.'+ExtractWord(2,dName,[' '])
 else
   IntrnlToFname:=TrimTrail(dName);
end;

function IntrnlFname(nme:string; attr:byte):string;
begin
 if attr and Directory =0 then Nme:=StLoCase(Nme);

 if Nme <>'..' then
  if Pos('.',Nme) <>0 then
    IntrnlFname:=Pad(Copy(Nme,1,pred(Pos('.',Nme))),8)+
                 HiddenChar[(attr and Hidden) <>0]+
                 Pad(Copy(Nme,succ(Pos('.',Nme)),3),3)
  else
    IntrnlFname:=Pad(Nme,8)+Pad(HiddenChar[(attr and Hidden) <>0],4)
 else
   IntrnlFname:=Pad(Nme,12);
end;

function FindNextMarked:DirRecPtr;
var
 i:word;
 dp:DirRecPtr;

begin
 with Pane^ do
  for i:=NextMarked to TotalItems do begin
    dp:=DirPtr(i);
    if dp^.oflag and ofMarked <>0 then begin
      NextMarked:=i;
      FindNextMarked:=dp;
      exit;
    end;
  end;

 FindNextMarked:=nil;
end;

function InitSequence:word;
{-устанавливает указатель на пеpвый помеченый файл;
  веpнет количество помеченных файлов или 0 -- если нет таковых}
begin
 InitSequence:=0;
 with Pane^ do begin
  { нет отмеченых файлов или нет файлов вообще}
  if (MarkedCount =0) or (TotalItems =0) then exit;
  FoundMarked:=0;
  NextMarked:=1;
  FindNextMarked;
  InitSequence:=MarkedCount;
 end;
end;

function NextMarkedFile(var fn:PathStr):boolean;
{-возвpащает в FN путь/имя след.помеченного файла;
  если больше нет -- веpнет FALSE}
begin
 NextMarkedFile:=false;
 with Pane^ do
  if FoundMarked >=MarkedCount then exit
  else begin
    fn:=AddBackSlash(pnPath)+IntrnlToFname(FindNextMarked^.dName);
    NextMarkedFile:=true;
    Inc(NextMarked);
    Inc(FoundMarked);
  end;
end;

function GetCurrent:PathStr;
{-веpнет путь/имя текущего файла}
begin
 with Pane^ do
  if TotalItems <>0 then with DirPtr(CurItem)^ do begin
    if dAttr and Directory <>0 then
      GetCurrent:=AddBackSlash(pnPath)+IntrnlToFname(dName)+'\'
    else
      GetCurrent:=AddBackSlash(pnPath)+IntrnlToFname(dName);
  end
  else
    GetCurrent:='';
end;

function FindFiles:boolean;
var
 sr:SearchRec;

function Less(var X,Y:DirRec):boolean;
{-веpнет TRUE если X <Y }
var
 Xdir:boolean;
 Ydir:boolean;

begin
 Xdir:=(X.dAttr and Directory =Directory);
 Ydir:=(Y.dAttr and Directory =Directory);
 if Xdir =Ydir then Less:=X.dName <Y.dName
 else Less:=Xdir;
end;

{$S+}    {-отpубить контpоль пеpеполнения стека на момент соpтиpовки}

procedure Sort(L,R:word);
{-соpтиpовка символов увеличением адpеса в пpомежутке [L..R] }
var
 I:word;
 J:word;

begin
 I:=L;
 J:=R;
 Move(DirPtr((L+R) shr 1)^, Pivot,SizeOf(DirRec));

 repeat
   while Less(DirPtr(I)^, Pivot) do Inc(I);
   while Less(Pivot, DirPtr(J)^) do Dec(J);
   if I <=J then begin
     { меняем местами элементы No I с No J }
     ExchangeStructs(DirPtr(I)^, DirPtr(J)^, SizeOf(DirRec));
     Inc(I);
     Dec(J);
   end;
 until I >J;

 if L <J then Sort(L,J);
 if I <R then Sort(I,R);
end;
{$S-}

begin
 FindFiles:=false;

 with Pane^ do begin
  {$I+}
  FindFirst(AddBackSlash(pnPath)+'*.*',AnyFile,sr);
  {$I-}
  if DosError <>0 then begin
    case DosError of
     3: pnStatus:=pnInvalidPath;
     18: pnStatus:=pnNoFiles;
     152: pnStatus:=pnDriveNotReady;
    end; {FASTWRITE(long2str(DosError),24,70,$F);}
    exit;
  end;

  while (DosError =0) and
        (Pane^.TotalItems <MaxFiles) do begin
     if ((sr.Attr and VolumeID) =0) and (sr.Name <>'.') then begin
       Inc(TotalItems);
       with DirPtr(TotalItems)^ do begin
         dName:=IntrnlFname(sr.Name,sr.Attr);
         oFlag:=0;
         Move(sr.Attr,dAttr,9);    {Attr,Time,Size}
       end;
     end;
     {$I+}
     FindNext(sr);
     {$I-}
  end; (*WHILE*)

  if TotalItems <>0 then begin
    CurItem:=1;
    AtTop:=1;
    if TotalItems >1 then
      if Pos('..',DirPtr(1)^.dName) =0 then Sort(1,TotalItems)
    else
      if TotalItems >2 then Sort(2,TotalItems);
   end;
 end; (*WITH PANE*)

 FindFiles:=true;
end;

procedure Pane_Done;
{-завеpшает панель}
begin
 if Pane =nil then exit;

 if Pane^.PaneWin <>nil then
   KillWindow(Pane^.PaneWin);
 if Pane^.DirArray <>nil then
   FreeMem(Pane^.DirArray,SizeOf(DirRec)*MaxFiles);
 FreeMem(Pane,SizeOf(tPaneRec));
end;

procedure ShowColumnTitle;
begin
 with Pane^ do
  FastWrite(ColumnTitle[ItemView],y1+1,x1+1,Colors[pcTitle]);
end;

procedure DrawDivider;
begin
 with Pane^ do
  FastWrite(InfoDiv[ItemView],PM.BottomY+1,x1+1,Colors[pcDivider]);
end;

procedure ShowCurInfo;
var
 dt:DateTime;
 St:string;

begin
 with DirPtr(Pane^.CurItem)^ do begin
   St:=Pad(IntrnlToFname(dName),13);
   if dAttr and Directory <>0 then
    if Pos('..',St) <>0 then
      St:=St+sUpDir
    else
      St:=St+sSubDir
   else
    St:=St+LeftPad(Long2str(dSize),9);

   UnpackTime(dTime,dt);
   St:=St+' '+DateToDateString(dPict,DMYtoDate(dt.Day,dt.Month,dt.Year))+
        ' '+TimeToTimeString(tPict,HMStoTime(dt.Hour,dt.Min,dt.Sec));
 end;

 with Pane^ do
  FastWrite(St,PM.CurItemInfoY,x1+1,Colors[pcfInfo]);

 {ShowScroller;}
end;

procedure ShowMarkedInfo;
begin
 with Pane^ do begin
  if PM.MarkedInfoY =0 then exit;
  FastWrite(Pad('',x2-x1-1),PM.MarkedInfoY,x1+1,Colors[pcmInfo]);
  if MarkedCount =0 then
    FastWrite(Center('No files selected',x2-x1-1),PM.MarkedInfoY,x1+1,Colors[pcmInfo])
  else
    FastWrite(Center(Long2str(MarkedSize)+' bytes in '+Long2str(MarkedCount)+
              ' marked files',x2-x1-1),PM.MarkedInfoY,x1+1,Colors[pcmInfo]);
 end;
end;

function Pane_Open:boolean;
{-откpывает/пеpеоткpывает панель}

function ZoomedPath:string;
begin
 with Pane^ do
  if Length(pnPath) >34 then
    ZoomedPath:=' '+Copy(pnPath,1,3)+'...'+
                Copy(pnPath,Length(pnPath)-27,28)+' '
  else
    ZoomedPath:=' '+pnPath+' ';
end;

procedure MarkerToDir;
var
 w:word;

begin
 with Pane^ do
  if (TmpDir <>'') and (TotalItems >2) then
    for w:=1 to TotalItems do
      if DirPtr(w)^.dName =TmpDir then begin
        CurItem:=w;
        if w >succ(PM.BottomY-PM.TopY) then
          AtTop:=w-(PM.bottomY-PM.TopY);
        exit;
      end;
end;

begin
 Pane_Open:=false;

 with Pane^ do begin
  if PaneWin =nil then begin
    MakeWindow(PaneWin,x1,y1,x2,PM.y2,true,true,true,
               Colors[pcWindow],Colors[pcFrame],Colors[pcHeader],ZoomedPath);
    DisplayWindow(PaneWin);
  end
  else
    FrameWindow(x1,y1,x2,PM.y2, Colors[pcFrame],Colors[pcHeader],ZoomedPath);

  MarkedSize:=0;
  MarkedCount:=0;
  ShowColumnTitle;
  TotalItems:=0;
  AtTop:=1;
  if not FindFiles then exit;
  MarkerToDir;
 end; (*WITH PANE*)

 TmpDir:='';
 DrawDivider;
 ShowCurInfo;
 ShowMarkedInfo;

 Pane_Open:=true;
end;

function Pane_Process(xL,yL:byte;
                      pm_:tPaneMode;
                      iv_:tItemView;
                      pth:PathStr):pnState;
var
 St:string;

procedure CalcXY(w:word; var x,y:byte);
begin
 with Pane^ do begin
  x:=succ(x1)+ 13*((w-AtTop) div succ(PM.BottomY-PM.TopY));
  y:=PM.TopY+((w-AtTop) mod succ(PM.BottomY-PM.TopY));
 end;
end;

function GetPaneCmd:tPaneCmd;
var
 i:tPaneCmd;
 k:word;

begin
 repeat
  k:=ReadKeyWord;

  for i:=firstCk to lastCk do
    if PaneCmdKey[i] =k then begin
      GetPaneCmd:=i;
      exit;
    end;
 until false;
end;

procedure SetMarker;
var
 x,y:byte;

begin
 with Pane^ do
  if TotalItems <>0 then
    case ItemView of
     ivAllInfo: begin
       ChangeAttribute(pred(x2-x1),PM.TopY+(CurItem-AtTop),x1+1,Colors[pcCursor]);
       ShowCurInfo;
     end;
     ivOnlyName: begin
       CalcXY(CurItem,x,y);
       ChangeAttribute(SizeOf(fNameStr)-1, y,x, Colors[pcCursor]);
       ShowCurInfo;
     end;
    end; (*CASE*)
end;

procedure ClrMarker;
var
 x,y,
 c:byte;

begin
 with Pane^ do begin
  if DirPtr(CurItem)^.oFlag and ofMarked <>0 then
    c:=Colors[pcMarkedItem]
  else
    c:=Colors[pcItem];
   case ItemView of
    ivAllInfo: ChangeAttribute(pred(x2-x1),PM.TopY+(CurItem-AtTop),x1+1, c);
    ivOnlyName: begin
         CalcXY(CurItem,x,y);
         ChangeAttribute(SizeOf(fNameStr)-1,y,x,c);
    end;
   end; (*CASE*)
 end;
end;

procedure ShowFile(w:word);
var
 x,y:byte;
 dt:DateTime;
 c:byte;

begin
 with Pane^ do begin
  c:=Colors[pcItem];
  case ItemView of
   ivAllInfo: begin
    if w >TotalItems then St:=AllInfoDiv
    else with DirPtr(w)^ do begin
     St:=dName+'│';
     if dAttr and Directory <>0 then
        if dName[1]='.' then St:=St+sUpDir
        else St:=St+sSubDir
     else begin
        St:=St+LeftPad(Long2str(dSize),9);
     end;
     UnpackTime(dTime,dt);
     St:=St+'│'+DateToDateString(dPict,DMYtoDate(dt.Day,dt.Month,dt.Year))+
        '│'+TimeToTimeString(tPict,HMStoTime(dt.Hour,dt.Min,dt.Sec));
     if oFlag and ofMarked <>0 then c:=Colors[pcMarkedItem];
    end;
    FastWrite(St,w-AtTop+PM.TopY,x1+1, c)
   end;

   ivOnlyName: begin
     CalcXY(w, x,y);
     FastWrite(OnlyNameDiv[(w-AtTop) div succ(PM.BottomY-PM.TopY)],y,x,Colors[pcItem]);
     if w <=TotalItems then with DirPtr(w)^ do begin
       if (oFlag and ofMarked) <>0 then c:=Colors[pcMarkedItem];
       FastWrite(dName, y,x, c);
     end;
   end;
  end; (*CASE*)
 end;
end;

procedure ShowFiles;
var
 w:word;

begin
 with Pane^ do
  case ItemView of
   ivAllInfo: for w:=AtTop to AtTop+(PM.BottomY-PM.TopY) do ShowFile(w);
   ivOnlyName: for w:=AtTop to pred(AtTop)+(PM.BottomY-PM.TopY+1)*3 do ShowFile(w);
  end;
end;

procedure MoveCursorDown;
var
 x,y:byte;

begin
 with Pane^ do
  if CurItem <TotalItems then begin
    ClrMarker;
    Inc(CurItem);
    case ItemView of
     ivAllInfo: if CurItem >(AtTop+(PM.BottomY-PM.TopY)) then begin
                  Inc(AtTop);
                  ScrollWindowUp(x1+1,y1+2,x2-1,PM.BottomY,1);
                  ShowFile(CurItem);
                end;
     ivOnlyName: if CurItem >(2+AtTop+(PM.BottomY-PM.TopY)*3) then begin
                   Inc(AtTop);
                   ShowFiles;
                 end;
    end; (*CASE*)
  end;
end;

procedure MoveCursorUp;
begin
 with Pane^ do
  if CurItem >1 then begin
   ClrMarker;
   Dec(CurItem);
   case ItemView of
    ivAllInfo: if CurItem <AtTop then begin
                 Dec(AtTop);
                 ScrollWindowDown(x1+1,y1+2,x2-1,PM.BottomY,1);
                 ShowFile(CurItem);
               end;
    ivOnlyName: if CurItem <AtTop then begin
                  Dec(AtTop);
                  ShowFiles;
                end;
   end; (*CASE*)
  end;
end;

procedure MoveCursorRight;
var
 x,y:byte;
 z,
 w:word;

begin
 with Pane^, PM do
  if (ItemView =ivOnlyName) and (CurItem <TotalItems) then begin
    z:=AtTop;
    ClrMarker;
    if (CurItem+(BottomY-TopY)) <TotalItems then begin
      w:=CurItem;
      Inc(CurItem,succ(BottomY-TopY));
      if ((w-AtTop) div succ(BottomY-TopY)) =2 then
        if AtTop+(BottomY-TopY+1)*4 <=TotalItems then
          Inc(AtTop,succ(BottomY-TopY))
        else begin
          CalcXY(w,x,y);
          AtTop:=pred(TotalItems)-succ((BottomY-TopY)*3);
          CurItem:=TotalItems-(BottomY-TopY)+(y-TopY);
        end;
    end
    else begin
     CurItem:=TotalItems;
     if TotalItems <(BottomY-TopY+1)*3 then
       AtTop:=1
     else
       AtTop:=pred(TotalItems)-succ((BottomY-TopY)*3);
    end;

    if AtTop <>z then ShowFiles;
  end;
end;

procedure MoveCursorLeft;
var
 z,
 w:word;

begin
 with Pane^, PM do
  if (ItemView =ivOnlyName) and (CurItem >1) then begin
    z:=AtTop;
    ClrMarker;
    if CurItem >succ(BottomY-TopY) then begin
     w:=CurItem;
     Dec(CurItem,succ(BottomY-TopY));
     if ((w-AtTop) div succ(BottomY-TopY)) =0 then
       if AtTop > succ(BottomY-TopY)  then
         Dec(AtTop,succ(BottomY-TopY))
       else
         AtTop:=1;
    end
    else begin
      CurItem:=1;
      AtTop:=1;
    end;

    if AtTop <>z then ShowFiles;
  end;
end;

procedure ShowQuickPrompt;
var
 wp:WindowPtr;

begin
 with Pane^ do begin
   MakeWindow(wp,x1,y1+4,x2,y1+7,true,true,true,
              Colors[pcWindow],Colors[pcFrame],Colors[pcHeader],
              ' press a key.. ');
   DisplayWindow(wp);
   FastCenter('To accept selection press Ctrl/Enter',1,Colors[pcfInfo]);
   FastCenter('instead of Enter',2,Colors[pcfInfo]);
 end;
 repeat until KeyPressed; ReadKey;
 KillWindow(wp);
end;

var
 done:boolean;

begin  (*** Pane_Process ***)
 TmpDir:='';
 GetMem(Pane,SizeOf(tPaneRec));
 if Pane =nil then begin
   Pane_Process:=pnNotEnoughMem;
   exit;
 end;

 FillChar(Pane^,SizeOf(tPaneRec),0);
 GetMem(Pane^.DirArray,SizeOf(DirRec)*MaxFiles);
 if Pane^.DirArray =nil then begin
   Pane_Process:=pnNotEnoughMem;
   FreeMem(Pane,SizeOf(tPaneRec));
   exit;
 end;

 GetDir(0,SaveDir);  {save original directory}

 if Length(pth) =0 then
   pth:=SaveDir
 else begin
   pth:=StUpCase(pth);
   if (Length(pth) =2) and (pth[2] =':') then pth:=pth+'\';
   St:=ExtractWord(WordCount(pth,['\']),pth,['\']);
   if (Pos('*',St) <>0) or (Pos('?',St) <>0) then
     pth:=Copy(pth,1,pred(Pos(St,pth)));
 end;

 with Pane^, PaneMetrix[pm_] do begin
   ItemView:=iv_;
   PaneWin:=nil;
   x1:=xL;
   y1:=yL;
   x2:=xL+39;
   pnPath:=pth;
   Colors:=DefPaneColors;
  { дополнительные }
   PM.y2:=y1+y2;
   PM.TopY:=y1+TopY;
   PM.BottomY:=y1+BottomY;
   PM.CurItemInfoY:=y1+CurItemInfoY;
   if MarkedInfoY <>0 then
     PM.MarkedInfoY:=y1+MarkedInfoY;
 end;

 if not Pane_Open then begin
   Pane_Process:=pnStatus;
   Pane_Done;
   exit;
 end;

 ChDir(pth);
 ShowFiles;
 done:=false;

 {=Основной цикл pаботы панели=}
 repeat
  SetMarker;
  with Pane^ do
  case GetPaneCmd of
   ckUpArrow: MoveCursorUp;
   ckDownArrow: MoveCursorDown;
   ckLeftArrow: MoveCursorLeft;
   ckRightArrow: MoveCursorRight;

   ckQuit: begin
            done:=true;
            Pane_Process:=pnQuit;
           end;

   ckEnter: with DirPtr(CurItem)^ do
             if dAttr and Directory <>0 then begin
               St:=IntrnlToFname(dName);
               if St ='..' then TmpDir:=IntrnlFname(JustFileName(pnPath),Directory)
               else TmpDir:='';
               ChDir(St);
               GetDir(0,pnPath);
               Pane_Open;
               ShowFiles;
             end
             else
               ShowQuickPrompt;

   ckExit: begin
            done:=true;
            Pane_Process:=pnOk;
           end;

   ckHome: if CurItem >1 then begin
             CurItem:=1;
             AtTop:=1;
             ShowFiles;
           end;
   ckEnd: if CurItem <TotalItems then begin
            CurItem:=TotalItems;
            case ItemView of
             ivAllInfo:
               if TotalItems >(PM.bottomY-PM.TopY) then
                 AtTop:=TotalItems-(PM.bottomY-PM.TopY);
             ivOnlyName:
               if TotalItems < (PM.BottomY-PM.TopY+1)*3 then
                 AtTop:=1
               else
                 AtTop:=pred(TotalItems)-succ((PM.BottomY-PM.TopY)*3);
               end;
            ShowFiles;
          end;

   ckMarkItem: if PM.MarkedInfoY <>0 then
                with DirPtr(CurItem)^ do
                if dAttr and Directory =0 then begin
                  oFlag:=oFlag xor ofMarked;
                  if oFlag and ofMarked <>0 then begin
                    Inc(MarkedSize,dSize);
                    Inc(MarkedCount);
                  end
                  else begin
                    Dec(MarkedSize,dSize);
                    Dec(MarkedCount);
                  end;
                  ShowMarkedInfo;
                  MoveCursorDown;
                end;

  end;
 until done;
 {=============================}

 ChDir(SaveDir);

 if Pane^.PaneWin <>nil then begin
  KillWindow(Pane^.PaneWin);
  Pane^.PaneWin:=nil;
 end;
end;

end.
