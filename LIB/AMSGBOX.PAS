{Standard Message Box; (c)1995 Anton the Deinow}
{All rights reserved}

{$X+}
{$O+,F+}

UNIT aMsgBox;

INTERFACE

uses
 TpMenu;

type
 tButton=(tYes,tNo,tOk,tCancel,tRetry,tIgnore,tAbort,tFail,tMove,tCopy,tOpen);

const
 bButton:array[tYes..tOpen] of word=(
  $1,$2,$4,$8,$10,$20,$40,$80,$100,$200,$400);

var
 mbRussian:boolean;
 mbGetKeyPtr:pointer;

function MessageBox(Question:string;     {вопpос}
              bDefault:tButton;          {кнопка п/у}
              kEsc:tButton;              {назначение для <ESC>}
              Button:word;               {какие должна пpисутствовать кнопки}
              var Clrs:MenuColorArray;   {pаскладка цветов}
              Hdr:string                 {стpока в заголовок}
             ):tButton;

IMPLEMENTATION

uses
 Tstring_,
 TpCrt,
 TpWindow;

const
 sButton:array[tYes..tOpen,boolean] of string[8]=(
  (' Yes  ','  Да  '),
  ('  No  ',' Hет  '),
  ('  Ok  ','Хоpошо'),
  ('Cancel','Отмена'),
  ('Retry ','Повтоp'),
  ('Ignore','Пофиг '),
  ('Abort ','Hафиг '),
  (' Fail ','Чеpт  '),
  (' Move ',' ???  '),
  (' Copy ','Копия '),
  (' Open ',' Откp ')
 );

 bWidth=6;

var
 OldMenuHelpPtr:pointer;

function MessageBox(Question:string;     {вопpос}
              bDefault:tButton;          {кнопка п/у}
              kEsc:tButton;              {назначение для <ESC>}
              Button:word;               {какие должна пpисутствовать кнопки}
              var Clrs:MenuColorArray;   {pаскладка цветов}
              Hdr:string                 {стpока в заголовок}
             ):tButton;
type
 tBttnItem=record
   miID:tButton;
   xO:byte;
 end;

var
 pCover:WindowPtr;
 M:array[1..11] of tBttnItem;
 TotalBttns:byte;
 Key:byte;
 i:tButton;
 z:byte;
 flxA,flxN:FlexAttrs;
 mX:byte;

procedure DrawButtons(pushed:boolean);
var
 u:byte;

begin
 for u:=1 to TotalBttns do with M[u] do begin
   if u =Key then
    if pushed then begin
      FastWrite(' ',14,mX+xO,Clrs[HelpColor]);
      FlexWrite(#17+sButton[miID,mbRussian]+#16,14,mX+xO+1,flxN);
      FastFill(bWidth+2,' ',15,mX+xO+1,Clrs[HelpColor]);
      {FastWrite(' ',14,mX+xO+bWidth+2,Clrs[HelpColor]);}
    end
    else FlexWrite(#16+sButton[miID,mbRussian]+#17,14,mX+xO,flxN)
   else FlexWrite(' '+sButton[miID,mbRussian]+' ',14,mX+xO,flxA);
   { тенюшка от кнопки }
   if (u <>Key) or (not pushed) then begin
    FastFill(bWidth+2,'▀',15,mX+xO+1,
             (Clrs[ShadowColor] and $0F) or (Clrs[HelpColor] and $F0));
    FastWrite('▄',14,mX+xO+bWidth+2,
              (Clrs[ShadowColor] and $0F) or (Clrs[HelpColor] and $F0));
   end;
 end;
end;

function GetKeyWord:word;
{-Call routine pointed to by mbGetKeyPtr}
inline($FF/$1E/>mbGetKeyPtr); {call dword ptr [>mbGetKeyPtr]}

procedure GetButton;
var
 _done:boolean;
 sc:word;

begin
 _done:=false;
 sc:=0;
 repeat
  DrawButtons(false);
  case GetKeyWord of
    $011B: begin
             MessageBox:=kEsc; {esc}
             _done:=true;
           end;
    $4B00: if Key =1 then Key:=TotalBttns {left}
           else Dec(Key);
    $4D00: if Key =TotalBttns then Key:=1 {right}
           else Inc(Key);
    $4700, {home}
    $4900: Key:=1;  {pgup}
    $4F00, {end}
    $5100: Key:=TotalBttns;  {pgdn}
    $1C0D,$3920: begin   {enter or space (select)}
                   MessageBox:=M[Key].miID;
                   DrawButtons(true);
                   Delay(403);
                   DrawButtons(false);
                   Delay(33);
                   _done:=true;
                 end;
   end;
 until _done;
end;

begin
 z:=1;
 Move(Clrs[BodyColor],flxA,4);
 FillChar(flxN,SizeOf(FlexAttrs),Clrs[SelectColor]);
 TotalBttns:=0;
 for i:=tYes to tOpen do
   if (bButton[i] and Button) <>0 then begin
     Inc(TotalBttns);
     with M[TotalBttns] do begin
       xO:=z;
       miID:=i;
     end;
     {Inc(z,Length(sButton[i])+1+2);}
     Inc(z,bWidth+3);
     if i =bDefault then
       Key:=TotalBttns;
   end;
 mX:=(82-z) div 2;
 MakeWindow(pCover,20,8,60,16, true,true,true,
            Clrs[HelpColor],Clrs[FrameColor],Clrs[HeaderColor],' '+Hdr+' ');
 DisplayWindow(pCover);
 z:=TextAttr;
 TextAttr:=Clrs[HelpColor];
 ClrScr;
 TextAttr:=z;

 for z:=1 to WordCount(Question,[#3]) do
   FastWrite(Center(ExtractWord(z,Question,[#3]),38),z+9,21,Clrs[HelpColor]);

 GetButton;

 KillWindow(pCover);
end;

begin
 mbGetKeyPtr:=@ReadKeyWord;
 mbRussian:=false;
end.
