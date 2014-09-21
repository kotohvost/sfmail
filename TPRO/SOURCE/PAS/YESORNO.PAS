{StdDialog menu; (c)1993 Anton the Deinow
 ver 2.01/beta}

{$O+,X+}

Unit YesOrNo;

INTERFACE

uses
 Tstring_,
 TPcrt,
 TpWindow,
 TPmenu;

type
 tButton=(tYes,tNo,tOk,tCancel,tRetry,tIgnore,tAbort,tFail,
          tMove,tCopy,tOpen);

const
 bButton:array[tYes..tOpen] of word=(
  $1,$2,$4,$8,$10,$20,$40,$80,
  $100,$200,$400);

 sButton:array[tYes..tOpen] of string[6]=(
  'Yes','No','Ok','Cancel','Retry','Ignore','Abort','Fail',
  'Move','Copy','Open');

function ButtonMenu(Question:string;     {вопpос}
              bDefault:tButton;          {кнопка п/у}
              kEsc:tButton;              {назначение для <ESC>}
              Button:word;               {какие должна пpисутствовать кнопки}
              Orient:Orientation;        {Vertical/Horisontal}
              var Frame1:FrameArray;     {pамка}
              var Color4:MenuColorArray; {цвет}
              Hdr:string		 {стpока в заголовок}
             ):tButton;
{-фоpмиpует меню с вопpосом Question в заголовке и пунктами,
  указаными в Button}

IMPLEMENTATION

function ButtonMenu(Question:string;           {вопpос}
              bDefault:tButton;          {кнопка п/у}
              kEsc:tButton;              {назначение для <ESC>}
              Button:word;               {какие должна пpисутствовать кнопки}
              Orient:Orientation;        {Vertical/Horisontal}
              var Frame1:FrameArray;     {pамка}
              var Color4:MenuColorArray; {цвет}
              Hdr:string		 {стpока в заголовок}
             ):tButton;
var
 pCover:WindowPtr;
 M  : Menu;
 Key: MenuKey;
 Ch : Char;
 aButton:array[tYes..tOpen] of boolean;
 i:tButton;
 Wu,
 z,bd:byte;

{ WC:WindowCoordinates;}
 mX,mY,mW,mH:byte;

begin
 FillChar(aButton,SizeOf(aButton),0);
 M:=NewMenu([], nil);

 if Orient=Horizontal then begin
{   StoreWindowCoordinates(WC);}
   z:=1;
   for i:=tYes to tOpen do
     if (bButton[i] and Button)<>0 then Inc(z,Length(sButton[i])+1);
   mW:=z;
   mH:=9;
   mX:=(82-mW) div 2;
   mY:=14;
{   SaveWindow(20,8,60,16,true,pCover);}
   FrameChars:=Frame1;
{   FrameWindow(20,8,60,16,Color4[FrameColor],
               Color4[HeaderColor],'Confirmation');}
{   Window(21,9,59,15);}
   MakeWindow(pCover,20,8,60,16, true,true,true,
              Color4[BodyColor],Color4[FrameColor],Color4[HeaderColor],' '+Hdr+' ');
   DisplayWindow(pCover);
   z:=TextAttr;
   TextAttr:=Color4[BodyColor];
   ClrScr;
   TextAttr:=z;
   SubMenu(mX,mY,NoHelp,Orient,NoFrame,Color4,'');
 end
 else begin
   mW:=Length(Question)+6;
   mH:=1;
   mX:=(74-Length(Question)) div 2;
   mY:=12;
   SubMenu(mX,mY,NoHelp,Orient,Frame1,Color4,' '+Question+' ');
   MenuWidth(mW);
   MenuHeight(mH);
 end;

 MenuMode(false,false,true);

 if Orient=Horizontal then
   for z:=1 to WordCount(Question,[#3]) do
    FastWrite(Center(ExtractWord(z,Question,[#3]),38),z+9,21,
              Color4[BodyColor]);

 z:=1;
 wu:=1;
 for i:=tYes to tOpen do
  if (bButton[i] and Button)<>0 then begin
    MenuItem(sButton[i],wu,1,z,'');
    aButton[i]:=true;
    if bDefault=i then bd:=z;
    Inc(wu,Length(sButton[i])+1);
    Inc(z);
  end;

 PopSublevel;
 ResetMenu(M);

 ButtonMenu:=bDefault;
 SelectMenuItem(M,bd);  {кнопка п/у}

 Key:=MenuChoice(M, Ch);
 {EraseMenu(M,true);}
 DisposeMenu(M);

 if Orient=Horizontal then begin
{   RestoreWindow(20,8,60,16,true,pCover);
   RestoreWindowCoordinates(WC);}
   KillWindow(pCover);
 end;

 z:=1;
 If Ch=#27 then ButtonMenu:=kEsc
 else
  for i:=tYes to tOpen do
    if (bButton[i] and Button)<>0 then
     if z =Key then begin
      ButtonMenu:=i;
      exit;
     end
     else Inc(z);
end;

end.
