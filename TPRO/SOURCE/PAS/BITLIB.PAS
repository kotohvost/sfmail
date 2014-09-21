unit BitLib;
INTERFACE

function GetGlobalBit(Data:pointer; Count:word; Round:word):byte;
procedure SetGlobalBit(Data:pointer; Count:word; Bit:byte);
procedure ScaleBit(var Source : array of byte; SLen, SFill :Word;
                   var Dest   : array of byte; DLen : word);

IMPLEMENTATION

function GetGlobalBit(Data:pointer; Count:word; Round:word):byte;assembler;
asm
     xor   ax,ax
     mov   dx,Round
     shl   dx,3
     cmp   count,dx     { Round > Count }
     jae    @01
     les   si,Data
     mov   ax,Count
     mov   cx,ax
     shr   ax,3
     add   si,ax
     and   cx,7
     mov   ax,$80
     shr   al,cl
     and   al,[es:si]
     cmp   al,0
     jz    @01
     mov   al,1
@01:
end;

procedure SetGlobalBit(Data:pointer; Count:word; Bit:byte);assembler;
asm
     les   si,Data
     mov   ax,Count
     mov   cx,ax
     shr   ax,3
     add   si,ax
     shl   ax,3
     sub   cx,ax
     xor   ax,ax
     mov   al,$80
     shr   al,cl
     or    [es:si],al
     cmp   Bit,0
     jnz   @01
     xor   [es:si],al
@01:

end;

procedure ScaleBit(var Source : array of byte; SLen, SFill :Word;
                   var Dest   : array of byte; DLen : word);
Var
  i      : LongInt;
begin
  for i:=0 to (DLen*8-1) do
    SetGlobalBit(@Dest,i,GetGlobalBit(@Source,i*SFill div DLen,SLen));
end;

end.