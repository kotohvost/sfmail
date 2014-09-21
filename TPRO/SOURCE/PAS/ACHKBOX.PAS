(*
   /================================================================\
   |        Anton Deinow`s Custom Controls library (ADCCl)          |
   |       (C) Anton the Deinow, 1995. All rights reserved.         |
   |               ver 0.0.1/alpha of 22.Aug.95                     |
   ------------------------------------------------------------------
   |CheckBoxes are group of multichoise 3-state elements            |
   |RadioButtons are group of 3-state elements `One-Of-Many' concept|
   |Buttons are group of `Push-Button' controls                     |
   \================================================================/
*)

{$X+,V-}

{$O+,F+}

UNIT aChkBox;

INTERFACE

type
 { checkbox, radiobutton stuff }
 TcbAnswer=(cba_Enter,cba_Tab,cba_ShTab,cba_Esc);
 tCbColor=(cbc_Window,cbc_Frame,cbc_Header,cbc_Item,cbc_Select,
           cbc_Disabled);
 tCbColors=array[tCbColor] of byte;
 { pushbutton stuff }
 tPbColor=(pbc_Item,pbc_Hilite,pbc_Default,pbc_Disabled,
           pbc_Select,pbc_Shadow);
 tPbColors=array[tPbColor] of byte;
 tPbRec=record
   reserv:byte;       {reserved for future use}
   x1,y1,x2,y2:byte;  {absolute coordinates of button}
   bmFlag:word;       {bitmaped state flags}
 end;

const
 { checkbox mode bit flags (word) }
 cbf_Frame    =$0001;
 cbf_Header   =$0002;
 cbf_RadioBttn=$0004;
 cbf_HdrLeft  =$0008;
 cbf_HdrRight =$0010;
 cbf_OnlyDraw =$0020;
 { pushbutton mode bit flags (word) }
 pbf_Frame    =$0001;
 pbf_Default  =$0002;
 pbf_Disabled =$0004;
 pbf_OnlyDraw =$0008;

function _3StateCheckBox(fpGetString:pointer;   {pointer to string func}
                         ppChangeState:pointer; {pointer to change state proc}
                         x1,y1,x2,y2:byte;      {coords of groop frame}
                         cbFlag:word;           {mode flags, see cbf_XXX}
                         cbTotal:byte;          {number of checkboxes}
                         var cbChkd:longint;    {bitmaped check states}
                         var cbDsbld:longint;   {bitmaped disabled states}
                         var cbColor:tCbColors; {color map}
                         cbGroupHdr:string      {header of group frame}
                         ):TcbAnswer;

function ExecPushButton(fpGetPbStr:pointer;   {pointer to string func}
                        fpGetPbState:pointer; {pointer to state func}
                        pbFlag:word;          {bitmaped pushbutton states}
                        pbTotal:byte;         {total number of pushbuttons}
                        pbColor:tPbColors     {color palette}
                        ):byte;
{ if return value >$0F then it represents Num of pessed button,
  else it is a cba_XXX constant }

IMPLEMENTATION

uses
 tString_,
 TpCrt;

(******************* PushButton stuff ************************)
const
 pbStrFunc:pointer=nil;
 pbGetStateFn:pointer=nil;

function pbGetStr(Item:word):string;
{-Return the name of each checkbox}
inline($FF/$1E/>pbStrFunc);   {CALL DWORD PTR [>pbStrFunc]}

function pbGetState(Item:word):string;
{-Return state of each pushbutton}
inline($FF/$1E/>pbGetStateFn);  {CALL DWORD PTR [>pbGetStateFn]}

function ExecPushButton(fpGetPbStr:pointer;   {pointer to string func}
                        fpGetPbState:pointer; {pointer to state func}
                        pbFlag:word;          {bitmaped pushbutton states}
                        pbTotal:byte;         {total number of pushbuttons}
                        pbColor:tPbColors     {color palette}
                        ):byte;
var
 cursXY,cursSL:word;
 sc:word;
 curPb:byte;

procedure pbDraw(pushed:boolean);
var
 i,z:byte;
 {s1,s2:string[SizeOf(tPbRec)-1];}
 s1,s2:string[20];
 pbr:tPbRec absolute s2;
 oldFrameCh:FrameArray;

begin
 for i:=1 to pbTotal do begin
   s2:=pbGetState(i);
   s1:=pbGetStr(i);
   with pbr do begin
    if i =curPb then z:=pbColor[pbc_Select]
    else
     if (bmFlag and pbf_Disabled) <>0 then z:=pbColor[pbc_Disabled]
     else
      if (bmFlag and pbf_Default) <>0 then z:=pbColor[pbc_Default]
      else
       z:=pbColor[pbc_Item];
    if (pbFlag and pbf_Frame) <>0 then begin
      Move(FrameChars,oldFrameCh,SizeOf(FrameArray));
      if pushed and (i =curPb) then
        SetFrameChars('º','Í','¼','»','È','É')
      else
        SetFrameChars('³','Ä','Ù','¿','À','Ú');
      FrameWindow(x1,y1,x2,y2,pbColor[pbc_Shadow],$00,'');
      Move(oldFrameCh,FrameChars,SizeOf(FrameArray));
      if i =curPb then s1:=#16+Center(s1,x2-x1-3)+#17
      else s1:=Center(s1,pred(x2-x1));
      FastWrite(s1,succ(y1),succ(x1),z);
    end
    else begin
      if i =curPb then s1:=#16+Center(s1,x2-x1-2)+#17
      else s1:=Center(s1,x2-x1);
      if pushed and (i =curPb) then begin
        FastWrite(' ',y1,x1,pbColor[pbc_Shadow]);
        FastFill(x2-x1,' ',y2,succ(x1),pbColor[pbc_Shadow]);
        FastWrite(s1,y1,succ(x1),z);
      end
      else begin
        FastWrite(s1,y1,x1,z);
        { draw shadow }
        FastFill(x2-x1,'ß',y2,succ(x1),pbColor[pbc_Shadow]);
        FastWrite('Ü',y1,x2,pbColor[pbc_Shadow]);
      end;
    end;
   end;
 end;
end;

procedure pbMoveSelection(movUp:boolean);
var
 i:byte;
 s:string[SizeOf(tPbRec)-1];
 pbr:tPbRec absolute s;

begin
 i:=curPb;
 repeat
  if movUp then
    if i =1 then i:=pbTotal
    else Dec(i)
  else
    if i =pbTotal then i:=1
    else Inc(i);
  s:=pbGetState(i);
  if (pbr.bmFlag and pbf_Disabled) =0 then curPb:=i;
 until (i =curPb);
end;

begin
 GetCursorState(cursXY,cursSL);
 HiddenCursor;
 pbStrFunc:=fpGetPbStr;
 pbGetStateFn:=fpGetPbState;

 curPb:=$FF;
 if (pbFlag and pbf_OnlyDraw) <>0 then pbDraw(false)
 else begin
   curPb:=1;
   repeat
     pbDraw(false);
     sc:=ReadKeyWord;
     case sc of
      { moving }
      $4800,$4B00: pbMoveSelection(true); {up or left}
      $5000,$4D00: pbMoveSelection(false); {down or right}
      { end buttons }
      $011B: ExecPushButton:=ord(cba_Esc); {esc}
      $3920,$1C0D: ExecPushButton:=$0F+curPb; {space or enter => push putton}
      $0F09: ExecPushButton:=ord(cba_Tab); {tab}
      $0F00: ExecPushButton:=ord(cba_ShTab); {shift/tab}
     end;
   until (sc =$011B) or (sc =$0F09) or (sc =$3920) or (sc =$1C0D) or (sc =$0F00);
 end;

 if (sc =$3920) or (sc =$1C0D) then begin
   pbDraw(true);
   Delay(403);
   pbDraw(false);
   Delay(33);
 end;

 RestoreCursorState(cursXY,cursSL);
end;

(************** CheckBox/RadioButton stuff *******************)
type
 tCbDelimit=record
   cbLeft,cbRight:char;
 end;

const
 { FALSE: checkbox / TRUE: radiobutton }
 cbMarkCh:array[boolean] of char=('û',#7);
 cbDelimit:array[boolean] of tCbDelimit=(
  (cbLeft:'['; cbRight:']'),
  (cbLeft:'('; cbRight:')')
 );
 cbStrFunc:pointer=nil;
 cbChgState:pointer=nil;

function cbGetStr(Item:word):string;
{-Return the name of each checkbox}
inline($FF/$1E/>cbStrFunc);   {CALL DWORD PTR [>cbStrFunc]}

procedure cbChangeState(Item:word);
{-Call after checkbox changes his state}
inline($FF/$1E/>cbChgState);  {CALL DWORD PTR [>cbChgState]}

function _3StateCheckBox(fpGetString:pointer;   {pointer to string func}
                         ppChangeState:pointer; {pointer to change state proc}
                         x1,y1,x2,y2:byte;      {coords of groop frame}
                         cbFlag:word;           {mode flags, see cbf_XXX}
                         cbTotal:byte;          {number of checkboxes}
                         var cbChkd:longint;    {bitmaped check states}

                         var cbDsbld:longint;   {bitmaped disabled states}
                         var cbColor:tCbColors; {color map}
                         cbGroupHdr:string      {header of group frame}
                         ):TcbAnswer;
var
 { save prev status vars }
 cursXY,cursSL:word;
 WC:WindowCoordinates;
 oldFrameCh:FrameArray;
 oldTA:byte;
 { work vars }
 curCb:byte; {current selected checkbox}
 sc:word;    {scancode storage}
 i:byte;     {yet another var}
 ccb:char;

procedure cbMoveSelection(movUp:boolean);
begin
 i:=curCb;
 repeat
  if movUp then
    if i =1 then i:=cbTotal
    else Dec(i)
  else
    if i =cbTotal then i:=1
    else Inc(i);
  if ((1 shl pred(i)) and cbDsbld) =0 then curCb:=i;
 until (i =curCb);
end;

procedure cbDraw;
var
 z:byte;

begin
 for z:=1 to cbTotal do begin
   if ((1 shl pred(z)) and cbDsbld) <>0 then begin
     i:=cbColor[cbc_Disabled];
     cCb:='°';
   end
   else begin
     if ((1 shl pred(z)) and cbChkd) <>0 then
      cCb:=cbMarkCh[(cbFlag and cbf_RadioBttn) <>0]
     else
      cCb:=' ';
     i:=cbColor[cbc_Item];

   end;
   if curCb =z then i:=cbColor[cbc_Select];
   FastWriteWindow(' '+cbDelimit[(cbFlag and cbf_RadioBttn) <>0].cbLeft+
                   +cCb+cbDelimit[(cbFlag and cbf_RadioBttn) <>0].cbRight+' '+
                   Pad(copy(cbGetStr(z),1,x2-x1-6),x2-x1-6),
                   z,1,i);
 end;
 GotoXY(3,curCb);
end;

begin
 GetCursorState(cursXY,cursSL);
 NormalCursor;
 oldTA:=TextAttr;
 StoreWindowCoordinates(WC);
 cbStrFunc:=fpGetString;
 cbChgState:=ppChangeState;

 if (cbFlag and cbf_Frame) <>0 then begin
   { frame enabled }
   Window(succ(x1),succ(y1),pred(x2),pred(y2));
   if (cbFlag and cbf_OnlyDraw) <>0 then begin
     TextAttr:=cbColor[cbc_Window];
     ClrScr;
     Move(FrameChars,oldFrameCh,SizeOf(FrameArray));
     SetFrameChars('³','Ä','Ù','¿','À','Ú');
     i:=ord(HeaderJstfy);
     if (cbFlag and cbf_HdrLeft) <>0 then HeaderJstfy:=hjLeft
     else
      if (cbFlag and cbf_HdrRight) <>0 then HeaderJstfy:=hjRight
      else
       HeaderJstfy:=hjCenter;
     FrameWindow(x1,y1,x2,y2,cbColor[cbc_Frame],cbColor[cbc_Header],cbGroupHdr);
     HeaderJstfy:=tHeaderJstfy(i);
     Move(oldFrameCh,FrameChars,SizeOf(FrameArray));
   end;
 end
 else begin
   { no frame..}
   if (cbFlag and cbf_Header) <>0 then begin
     {..but header allowed }
     if (cbFlag and cbf_OnlyDraw) <>0 then begin
       if (cbFlag and cbf_HdrLeft) <>0 then i:=succ(x1)
       else
        if (cbFlag and cbf_HdrRight) <>0 then i:=pred(x2-Length(cbGroupHdr))
        else
         i:=((x2-x1-Length(cbGroupHdr)) div 2)+x1;
       FastWrite(cbGroupHdr,y1,i,cbColor[cbc_Header]);
     end;
     Window(x1,succ(y1),x2,y2);
   end
   else
     { no frame, no header }
     Window(x1,y1,x2,y2);
   if (cbFlag and cbf_OnlyDraw) <>0 then begin
     TextAttr:=cbColor[cbc_Window];
     ClrScr;
   end;
 end;

 curCb:=$FF;
 if (cbFlag and cbf_OnlyDraw) <>0 then cbDraw  { draw group and exit immediately }
 else begin
   curCb:=cbTotal;
   cbMoveSelection(false);  {-find first anabled item }
   repeat
    cbDraw;
    sc:=ReadKeyWord;
    case sc of
      { moving }
      $4800, {up or..}
      $4B00: cbMoveSelection(true); {..left}
      $5000, {down or..}
      $4D00: cbMoveSelection(false); {..right}
      { change state }
      $3920: begin {space}
               if (cbFlag and cbf_RadioBttn) <>0 then cbChkd:=0;
               cbChkd:=cbChkd xor (1 shl (pred(curCb)));
               if cbChgState <>nil then cbChangeState(curCb);
             end;
      { exit codes }
      $011B: _3StateCheckBox:=cba_Esc; {esc}
      $1C0D: _3StateCheckBox:=cba_Enter; {enter}
      $0F09: _3StateCheckBox:=cba_Tab; {tab}
      $0F00: _3StateCheckBox:=cba_ShTab; {shift/tab}
    end;
   until (sc =$011B) or (sc =$1C0D) or (sc =$0F09) or (sc =$0F00);
 end;
 RestoreWindowCoordinates(WC);
 RestoreCursorState(cursXY,cursSL);
 TextAttr:=oldTA;
end;

end.
