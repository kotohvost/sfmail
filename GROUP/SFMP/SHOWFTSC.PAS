
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
 writeln('� '+HexB(ord(s[2]))+HexB(ord(s[1]))+' � '+
         Pad(copy(s,3,length(s)-4),28)+' �');
end;

procedure Show;
var
 i:word;

{ [len] [minor] [major] [asciz] }

begin
 writeln('�������������������������������������Ŀ');
 writeln('� Code �        Product name          �');
 writeln('�������������������������������������Ĵ');
 i:=3;
 while (i <bufsiz) and (buf^[i] <>0) do begin
  ShowLn(buf^[i]);
  Inc(i,buf^[i]);
 end;
 writeln('���������������������������������������');
end;

begin
 Init;
 Show;
end.
