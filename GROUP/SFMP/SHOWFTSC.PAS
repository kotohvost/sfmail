
program ShowFTSC;

uses
 tString_;

type
 pBuf=^tBuf;
 tBuf=array[1..$EFFF] of byte;

var
 f:file;
 buf:pbuf;
 bufsiz:word;

procedure Init;
begin
 if ParamCount =0 then begin
  writeln('Path and filename of FTSCprod.fe list requered!'^G);
  halt;
 end;
 assign(f,ParamStr(1));
 reset(f,1);
 bufsiz:=FileSize(f);
 GetMem(buf,bufsiz);
 BlockRead(f,buf^,bufsiz);
 close(f);
end;

procedure ShowLn(var _s);
var
 s:string absolute _s;

begin
 writeln('³ '+HexB(ord(s[2]))+HexB(ord(s[1]))+' ³ '+
         Pad(copy(s,3,length(s)-4),28)+' ³');
end;

procedure Show;
var
 i:word;

{ [len] [minor] [major] [asciz] }

begin
 writeln('ÚÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿');
 writeln('³ Code ³        Product name          ³');
 writeln('ÃÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´');
 i:=3;
 while (i <bufsiz) and (buf^[i] <>0) do begin
  ShowLn(buf^[i]);
  Inc(i,buf^[i]);
 end;
 writeln('ÀÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ');
end;

begin
 Init;
 Show;
end.
