
function ParseStr(Str:string):string;
var
  i    : word;
  Res  : string;

procedure ParseSlash;
Var
  HexStr : String;
  Code   : integer;
  k      : byte;
begin
  Inc(i);
  if Str[i] in ['0'..'9','A'..'F','a'..'f'] then begin
    HexStr:='$'+Str[i];
    Inc(i);
    While (Str[i] in ['0'..'9','A'..'F','a'..'f']) and (i<=length(Str)) do begin
      HexStr:=HexStr+Str[i];
      Inc(i);
    end;
    Dec(i);
    Val(HexStr,k,code);
    if code =0 then
    Res:=Res+Chr(k);
  end else begin
    Res:=Res+Str[i];
  end;
end;

begin
  i:=1;
  Res:='';
  while i<=length(Str) do begin
    if Str[i]='\' then ParseSlash
    else
      Res:=Res+Str[i];
    inc(i);
  end;
  ParseStr:=Res;
end;

function DelComments(Str:String):String;
var
  i    : word;
  Res  : string;
begin
  i:=1;
  Res:='';
  while i<=length(Str) do begin
    if Str[i]=';' then begin
      if (i=1) or (Str[i-1]<>'\') then i:=255 else
      Res:=Res+Str[i];
    end else
      Res:=Res+Str[i];
    inc(i);
  end;
  DelComments:=Res;
end;

Var s : string;
begin
  s:='M\;odemString AT+FLI"C\0F8\9 - Robocop"\;~ATA ; Modem String define';
  WriteLn('   Было: <',s,'>');
  WriteLn('уpезано: <',DelComments(s),'>');
  WriteLn('  Стало: <',ParseStr(DelComments(s)),'>');
end.