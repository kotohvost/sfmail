{$I-}

program DomainCutter;

uses
 Objects,
 Dos,
 TpCrt,
 AEH,
 tString_;

const
 PID:string[12]='DomainCutter';
 VID:string[18]='version 0.01/alpha';
 CID:string[42]='(C) SantaFox Team (Anton the Deinow), 1996';
 TicPath:PathStr='';
 Gauge:array[1..4] of char=('-','\','|','/');

var
 TicList:pStringCollection;
 GaugePhase:byte;

procedure ShowError(s1,s2:string); far;
begin
 if Length(s2) <>0 then
  s1:=s1+': '+s2;
 TextAttr:=$0C;
 writeln(#13#10+s1+^G);
 TextAttr:=$07;
end;

procedure TurnGauge;
begin
 write(^H+Gauge[GaugePhase]);
 if GaugePhase =4 then
  GaugePhase:=1
 else
  Inc(GaugePhase);
end;

procedure DC_Init;
begin
 TextAttr:=$07;
 ClrScr;
 FastFill(ScreenWidth*2,' ',2,1,$70);
 FastCenter(PID+' '+VID,2,$7E);
 FastCenter('Copyright '+CID+'. All rights reserved.',3,$7F);
 FastFill(ScreenWidth-1,'Ä',1,2,$7F);
 FastVert('Ú'+CharStr('³',2)+'À',1,1,$7F);
 FastFill(ScreenWidth-1,'Ä',4,2,$78);
 FastWrite('¿',1,ScreenWidth,$7F);
 FastVert(CharStr('³',2)+'Ù',2,ScreenWidth,$78);
 GotoXY(1,6);
 { --- }
 TicList:=New(pStringCollection,Init(10,10));
 TicPath:=AddBackslash(ParamStr(1));
 ShowErrorPtr:=@ShowError;
 GaugePhase:=1;
end;

procedure DC_Done;
begin
 Dispose(TicList,Done);
 writeln(#13#10'Situation under control! Don`t panic. ;)'#13#10);
end;

procedure DC_Run;
var
 sr:SearchRec;
 i:integer;
 f1,f2:text;
 s:string;

begin
 FindFirst(TicPath+'*.tic',Archive,sr);
 if DosError =3 then
  ForceDosError(3,TicPath,true);
 { searching for TICs }
 while DosError =0 do begin
  TicList^.Insert(NewStr(StLoCase(sr.Name)));
  FindNext(sr);
 end;
 { cut all domains! }
 if TicList^.Count =0 then
  writeln('No bad TICs found')
 else begin
  for i:=0 to pred(TicList^.Count) do begin
   write('Processing '+pString(TicList^.At(i))^+'  ');
   assign(f1,TicPath+pString(TicList^.At(i))^);
   reset(f1);
   assign(f2,TicPath+'$$$dc$$$.$$$');
   rewrite(f2);
   { --- }
   repeat
    readln(f1,s);
    if (WordCount(s,[' ',^I]) =2) and
       (StLoCase(ExtractWord(1,s,[' ',^I])) ='from') then
     s:='From '+ExtractWord(1,ExtractWord(2,s,[' ',^I]),['@']);
    writeln(f2,s);
    TurnGauge;
   until EOF(f1);
   { --- }
   writeln(^H' ');
   close(f1);
   erase(f1);
   close(f2);
   rename(f2,TicPath+pString(TicList^.At(i))^);
  end;
 end;
end;

begin
 DC_Init;
 DC_Run;
 DC_Done;
end.
