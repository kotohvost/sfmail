(*** Change Main Address ***)

{$X+,O+,F+}

UNIT ChgMaddr;

INTERFACE

procedure ChangeMainAddr;

IMPLEMENTATION

uses
 EmStruct,
 Config,
 Tstring_,
 TpCrt,
 TpWindow,
 MsgXs,
 Sf_Pick;

procedure DrawChngAddr(n:word; y:byte; width:byte; sel:boolean);
begin
 with pCfgRec^ do
  if sel then
   FastWriteWindow(Pad(' '+Addr2str(MyAddress[n],true),width),y,1,
                   SfMailColors[pl_Marker])
  else
   FastWriteWindow(Pad(' '+Addr2str(MyAddress[n],true),width),y,1,
                   SfMailColors[pl_Item]);
end;

procedure ChangeMainAddr;
var
 curA,
 firstA:integer;
 win:WindowPtr;
 _A_:tAddress;
 cw:WindowPtr;

begin
 with pCfgRec^ do begin
  if AllAddress <=1 then exit;
  MakeWindow(win,3,5,22,6+AllAddress,true,true,true,
             SfMailColors[pl_Item],SfMailColors[pl_Border],
             SfMailColors[pl_Header],' Change AkA ');
  DisplayWindow(win);
  curA:=2;
  firstA:=1;
  DrawProc:=@DrawChngAddr;

  repeat
    PickBar(win,true,true,AllAddress,curA,firstA);
    if (PickExit =peSelect) and (curA <>1) then begin
     _A_:=MyAddress[1];
     MyAddress[1]:=MyAddress[curA];
     MyAddress[curA]:=_A_;
    end;
  until PickExit in [peSelect,peQuit];

  KillWindow(win);
 end;
end;

end.
