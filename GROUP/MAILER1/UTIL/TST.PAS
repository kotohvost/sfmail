{$X+}
uses
 tpwindow,
 tpcrt,
 tstring_,
 Dos;

const
 currentC=$0F;
 totalC  =$02;
 emptyC  =$17;

 allCube =20;

var
 totalL,currentL:longint;
 totCur,curCur:longint;
 wp:windowptr;

procedure ShowGauge;
var
 s:string;
 totCube,
 curCube:longint;

begin
 FastWrite(Pad('  Total: '+Long2str(totCur)+' of '+Long2str(totalL),80),24,1,$E);
 FastWrite(Pad('Current: '+Long2str(curCur)+' of '+Long2str(currentL),80),25,1,$E);

 totCube:=(totCur*allCube) div totalL;
 if totCube >allCube then totCube:=allCube;
 curCube:=(curCur*allCube) div currentL;
 if curCube >allCube then curCube:=allcube;

 {s:=CharStr('щ',allCube);
 FastWriteWindow(s,1,10,emptyC);}

 FastWrite(Pad(Long2str(totCube),3),24,75,$F);
 FastWrite(Pad(Long2str(curCube),3),25,75,$F);

 {if totCube =curCube then
   FastWriteWindow(CharStr('Ь',curCube),1,10,(totalC shl 4) or currentC)
 else
  if totCube >curCube then begin
    FastWriteWindow(CharStr('Ь',curCube),1,10,(totalC shl 4) or currentC);
    FastWriteWindow(CharStr('Я',totCube-curCube),1,10+curCube,totalC or (emptyC and $F0));
  end
  else begin
    FastWriteWindow(CharStr('Ь',totCube),1,10,(totalC shl 4) or currentC);
    FastWriteWindow(CharStr('Ь',curCube-totCube),1,10+totCube,currentC or (emptyC and $F0));
  end;}

 {if totCube >curCube then
   FastWriteWindow(CharStr('Ы',curCube)+
                   CharStr('Я',totCube-curCube)+
                   CharStr('Д',20-totCube),2,10,$17)
 else
   FastWriteWindow(CharStr('Ы',totCube)+
                   CharStr('Ь',curCube-totCube)+
                   CharStr('Д',20-curCube),2,10,$17);}

 if totCube >curCube then begin
   FastWriteWindow(CharStr('Ь',curCube),2,10,$20 or $07);
   FastWriteWindow(CharStr('Я',totCube-curCube),2,10+curCube,$12);
   FastWriteWindow(CharStr('-',allCube-totCube),2,10+totCube,$17);
 end
 else begin
   FastWriteWindow(CharStr('Ь',totCube),2,10,$20 or $07);
   FastWriteWindow(CharStr('Ь',curCube-totCube),2,10+totCube,$10 or $07);
   FastWriteWindow(CharStr('-',allCube-curCube),2,10+curCube,$17);
 end;
end;

function _Random:longint;
var
 l:longint;

begin
 repeat
  l:=Random($FFFF);
 until (l >120);
 _Random:=l;
end;

begin
 Randomize;
 HiddenCursor;
 totalL:=1024000;
 currentL:=0;
 totCur:=0;
 curCur:=0;
 MakeWindow(wp,20,10,59,14, true,true,true, $1B,$1F,$1E, ' Џp®ЈpҐбб Ё­¤ЁЄ в®p ');
 DisplayWindow(wp);
 FastWriteWindow(CharStr('Д',8)+'['+CharStr('-',20)+']'+CharStr('Д',8),2,1,$17);

 while totCur <totalL do begin
  curCur:=0;
  currentL:=_Random;
  while curCur <currentL do begin
    Inc(curCur,300);
    Delay(50);
    if KeyPressed then begin
      KillWindow(wp);
      NormalCursor;
      exit;
    end;
    ShowGauge;
  end;
  Inc(totCur,currentL);
 end;

 NormalCursor;
 KillWindow(wp);
end.
