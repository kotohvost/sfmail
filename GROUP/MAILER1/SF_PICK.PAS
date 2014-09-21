
{$X+,I-,O+,F+}

UNIT Sf_Pick;

INTERFACE

uses
 TpWindow;

type
 tPickExit=(
  peNone,
  peUser,
  peHelp,
  peSelect,
  peQuit
 );

var
 DrawProc:pointer;

var
 PickExit:tPickExit;
 PickCode:word;

procedure PickBar(pw:WindowPtr; RedrawList,SetMarker:boolean;
                  NumItems:integer; var Choice,FirstChoice:integer);

IMPLEMENTATION

uses
 Config,
 TpCrt,
 tString_,
 EmStruct;

procedure DrawItem(Item:word; Row:byte; Width:byte; Selected:boolean);
{-Draw each pick item}
inline($FF/$1E/>DrawProc);      {CALL DWORD PTR [>DrawProc]}

procedure PickBar(pw:WindowPtr; RedrawList,SetMarker:boolean;
                  NumItems:integer; var Choice,FirstChoice:integer);
var
 Row:integer;
 XSiz:byte;
 YSiz:byte;

procedure DrawScrollBar;
begin
 with WindowP(pw)^, Draw, pCfgRec^ do
  if NumItems >(YSiz) then begin
   FastVert(#30+CharStr('±',YH-YL-1)+#31,YL,XH+1,
            SfMailColors[pl_ScrollBarPage]);
   FastWrite(#4,succ(YL)+((Choice-1)*(pred(YH)-succ(YL))) div pred(NumItems),
             XH+1,SfMailColors[pl_ScrollBarIcons]);
  end
  else
   FastVert(CharStr('³',(YSiz)),YL,XH+1,FAttr);
end;

procedure ScrollPickList(Lines:integer);
var
 i,j,k:integer;

begin
 if Lines =0 then exit;
 with WindowP(pw)^ do begin
  Inc(FirstChoice,Lines);
  if Lines <0 then begin
   if -Lines <YSiz then
    ScrollWindowDown(XL,YL,XH,YH,-Lines)
   else
    Lines:=-YSiz;
  end
  else begin
   if Lines <YSiz then
    ScrollWindowUp(XL,YL,XH,YH,Lines)
   else
    Lines:=YSiz;
  end;
  if Lines <0 then begin
   j:=FirstChoice;
   k:=pred(j-Lines);
  end
  else begin
   j:=FirstChoice+(YH-YL)-pred(Lines);
   k:=pred(j+Lines);
  end;
  { draw line(s) replacing the ones that scrolled off }
  for i:=j to k do
   DrawItem(i,i-FirstChoice+1,XSiz,Choice =i);
 end;
end;

begin
 { perform common choice validation }
 if (Choice <1) or (Choice >NumItems) then begin
  Choice:=1;
  FirstChoice:=1;
 end;
 with WindowP(pw)^ do begin
  YSiz:=YH-YL+1;
  XSiz:=XH-XL+1;
 end;
 { force FirstChoice into a valid range }
 if FirstChoice >Choice then
  FirstChoice:=Choice;
 with WindowP(pw)^ do
  if NumItems >=YSiz then begin
   if YSiz >(NumItems-FirstChoice+1) then
    FirstChoice:=(NumItems-YSiz+1);
  end
  else
   FirstChoice:=1;

 { return item number based on FirstChoice, Row }
 (*Row:=NumItems-FirstChoice+1; PickChoiceVert:=FirstChoice+(Row-1);*)

 PickExit:=peNone;

 repeat
   if RedrawList then with WindowP(pw)^ do begin
    for Row:=0 to (YH-YL) do
     DrawItem(FirstChoice+Row,Row+1,XSiz,(FirstChoice+Row) =Choice);
   end
   else
    if SetMarker then
     DrawItem(Choice,Choice-FirstChoice+1,XSiz,true);
   RedrawList:=false;
   SetMarker:=false;
   DrawScrollBar;
   PickCode:=ReadScanCode;
   case PickCode of
    keyUp,keyLeft: if Choice >1 then begin
                    DrawItem(Choice,Choice-FirstChoice+1,XSiz,false);
                    Dec(Choice);
                    if Choice <FirstChoice then with WindowP(pw)^ do begin
                     FirstChoice:=Choice;
                     ScrollWindowDown(XL,YL,XH,YH,1);
                    end;
                    SetMarker:=true;
                   end;
    keyDn,keyRight: if Choice <NumItems then with WindowP(pw)^ do begin
                     DrawItem(Choice,Choice-FirstChoice+1,XSiz,false);
                     Inc(Choice);
                     if Choice >FirstChoice+(YH-YL) then begin
                      Inc(FirstChoice);
                      ScrollWindowUp(XL,YL,XH,YH,1);
                     end;
                     SetMarker:=true;
                    end;
    keyHome: if Choice >1 then begin
              DrawItem(Choice,Choice-FirstChoice+1,XSiz,false);
              Choice:=1;
              if FirstChoice >1 then
               ScrollPickList(-pred(FirstChoice))
              else
               SetMarker:=true;
             end;
    KeyEnd: if Choice <NumItems then with WindowP(pw)^ do begin
             DrawItem(Choice,Choice-FirstChoice+1,XSiz,false);
             Choice:=NumItems;
             Row:=FirstChoice+(YH-YL);
             if Choice >Row then
              ScrollPickList(Choice-Row)
             else
              SetMarker:=true;
            end;
    keyPgUp: if Choice >1 then with WindowP(pw)^ do begin
              DrawItem(Choice,Choice-FirstChoice+1,XSiz,false);
              Dec(Choice,YSiz div 2);
              if (Choice <1) or (Choice >NumItems) then
               Choice:=1;
              if FirstChoice >Choice then
               ScrollPickList(Choice-FirstChoice)
              else
               SetMarker:=true;
             end;
    keyPgDn: if Choice <NumItems then with WindowP(pw)^ do begin
              DrawItem(Choice,Choice-FirstChoice+1,XSiz,false);
              Inc(Choice,YSiz div 2);
              if (Choice >NumItems) then
               Choice:=NumItems;
              if NumItems >YSiz then begin
               if (Choice-FirstChoice) >(YH-YL) then begin
                Row:=Choice-(YH-YL);
                ScrollPickList(Row-FirstChoice);
               end
               else
                SetMarker:=true;
              end
              else
               SetMarker:=true;
            end;
    keyEnter: PickExit:=peSelect;
    keyEsc,keyNull: PickExit:=peQuit;
    keyF1: PickExit:=peHelp;
   else
    PickExit:=peUser;
   end;
 until PickExit <>peNone;
end;

end.
