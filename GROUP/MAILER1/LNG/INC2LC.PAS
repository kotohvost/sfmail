
uses
 tString_;

var
 s,s3:string;
 s1,s2:string;
 fIn,fOut,fNew:text;
 nLast:char;
 PrevN:word;
 i:byte;

begin
 assign(fIn,ParamStr(1));
 reset(fIn);
 assign(fOut,ParamStr(2));
 rewrite(fOut);
 assign(fNew,ForceExtension(ParamStr(1),'cst'));
 rewrite(fNew);
 { --- }
 PrevN:=0;
 repeat
  readln(fIn,s3);
  s:=Trim(s3);
  if (Length(s) <>0) and (s[2] ='m') then begin
   s1:=ExtractWord(1,s,[' ',^I,'=']);
   s2:=Trim(ExtractWord(2,s,['=',';']));
   if nLast <>s2[1] then begin
    nLast:=s2[1];
    s2:=s2[1]+CharStr('0',Length(s2)-1);
    Str2word(s2,PrevN);
   end;
   Inc(PrevN);
   s2:=copy(s,Pos('{',s)+2,255);
   s2:=copy(s2,1,Pos('}',s2)-2);
{!}s1:=Long2str(PrevN)+','+pad(s1,20)+'='+s2;
   writeln(fOut,s1);
   { correct ID in *.inc }
   i:=Pos('=',s3);
   while i <Length(s3) do
    if s3[i] in ['1'..'9'] then begin
     s2:=Long2str(PrevN);
     Move(s2[1],s3[i],Length(s2));
     i:=255;
    end
    else
     Inc(i);
  end;
  writeln(fNew,s3);
 until EOF(fIn);
 { --- }
 close(fIn);
 close(fOut);
 close(fNew);
end.
