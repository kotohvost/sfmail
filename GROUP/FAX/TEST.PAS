uses TPCrt;

const
  SegA000 : pointer = Ptr($0A000,0);

procedure UVHLine(X1,X2,Y:integer;Mask:byte;Invert:boolean);assembler;
asm
       cld
       les   DI,SegA000       { Video offset  --> ES:DI }
       mov   BX,Y             { Take Y offset --> BX }
       mov   SI,BX
       shl   BX,4
       shl   SI,6
       add   BX,SI            {(y << 4)+(y << 6)}
       mov   SI,X1            { Take X offset --> SI }
       shr   SI,3
       mov   AL,Mask          { Mask in AL }
       add   BX,SI            { Global offest --> BX }
       add   DI,BX

       mov   CX, X2
       inc   CX
       sub   CX, X1
       shr   CX,3
       cmp   Invert,0
       jne   @01
  REP  Stosb
       jmp   @02
  @01: mov   AH,ES:[DI]
       xor   AH,AL
       mov   ES:[DI],AH
       inc   DI
       loop  @01
  @02:
end;

var i:integer;
begin
  TextMode($12);
  fillchar(mem[$0A000:0000],38400,$0FF);
  for i:=0 to 479 do
   UVHLine(i,640,i,i,true);
  readln;
  TextMode(co80);
end.