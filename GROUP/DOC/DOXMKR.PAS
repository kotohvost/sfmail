(*******************************************************************
 Входной файл может содержать специальные макросы, которые
 следует задавать в первой позиции строки:

  .C   -- Add to the Table of Contents
          Строка будет занесена в Оглавление. Формат строки должен быть
          такой:

           .C  x.[y.[z.]]  Text of item

          Где x -- раздел, y -- пункт, z -- подпункт.

*******************************************************************)

{$I-}

uses
 Dos,
 TpCrt,
 TpWindow,
 AEH,
 tString_;

const
 PID:string[23]='The Documentation Maker';
 VID:string[22]='version 0.01/alpha0928';
 CID:string[26]='(C) Anton the Deinow, 1996';
 MaxContext=5;

type
 pContext=^tContext;
 tContext=array[1..MaxContext] of string;
 { for item numbering }
 tPunkt=array[1..3] of word;

var
 oldHalt:pointer;
 fIn,fOut,fTOC:text;
 CurStr:string;
 CurLen:byte absolute CurStr;
 MarkPos:byte;
 MarkSize:byte;
 CurPunkt:tPunkt;

const
 InFname:PathStr='';
 OutFname:PathStr='';
 TOCfName:PathStr='';
 Context:pContext=nil;
 LastContext:byte=0;
 SrcLn:word=0;
 CurHeight:byte=0;
 CurPage:word=1;
 ContextWnd:WindowPtr=nil;

procedure SayError(s1,s2:string); far;
begin
 if Length(s2) <>0 then
  s1:=s1+': "'+s2;
 TextAttr:=$0C;
 writeln(#13#10+s1+^G);
 TextAttr:=$07;
end;

procedure Usage;
begin
 TextAttr:=$0E;
 writeln('SYNTAX: DoxMkr[.exe] <InFile> [OutFile]');
 halt(255);
end;

procedure DM_Done; far;
begin
 if Context <>nil then Dispose(Context);
 if ContextWnd <>nil then KillWindow(ContextWnd);
 if TextRec(fIn).Mode <>fmClosed then close(fIn);
 if TextRec(fOut).Mode <>fmClosed then close(fOut);
 if TextRec(fTOC).Mode <>fmClosed then close(fTOC);
 writeln(SrcLn,'/',CurPage,' lines/pages found in '+InFname);
 TextAttr:=$0F;
 writeln(#13#10'Have a nice dox!');
 TextAttr:=$07;
 writeln;
 ExitProc:=oldHalt;
 halt(ExitCode);
end;

procedure DM_Init;
var
 i:byte;

begin
 oldHalt:=ExitProc;
 ExitProc:=@DM_Done;
 ShowErrorPtr:=@SayError;
 TextRec(fIn).Mode:=fmClosed;
 TextRec(fOut).Mode:=fmClosed;
 TextRec(fTOC).Mode:=fmClosed;
 New(Context);
 FillChar(CurPunkt,SizeOf(tPunkt),0);
 { show logo }
 TextAttr:=$07;
 ClrScr;
 FastFill(ScreenWidth*2,' ',2,1,$70);
 FastCenter(PID+' '+VID,2,$7E);
 FastCenter(CID,3,$7F);
 FastFill(ScreenWidth-1,'─',1,2,$7F);
 FastVert('┌'+CharStr('│',2)+'└',1,1,$7F);
 FastFill(ScreenWidth-1,'─',4,2,$78);
 FastWrite('┐',1,ScreenWidth,$7F);
 FastVert(CharStr('│',2)+'┘',2,ScreenWidth,$78);
 GotoXY(1,6);
 { parse command line }
 for i:=1 to ParamCount do begin
  CurStr:=ParamStr(i);
  if CurStr[1] in ['-','/'] then begin
   case LoCase(CurStr[2]) of
    'h': Usage;
   end;
  end
  else
   if Length(InFname) =0 then
    InFname:=DefaultExtension(CurStr,'doc')
   else
    if Length(OutFname) =0 then
     OutFname:=DefaultExtension(CurStr,'dmo')
    else
     TOCfName:=DefaultExtension(CurStr,'toc');
 end;
 { check command line parameters }
 if Length(InFname) =0 then Usage;
 if Length(OutFname) =0 then
  OutFname:=ForceExtension(InFname,'dmo');
 if Length(TOCfName) =0 then
  TOCfName:=ForceExtension(InFname,'toc');
 { assign & check files }
 assign(fIn,InFname);
 reset(fIn);
 CheckError(InFname,true);
 assign(fOut,OutFname);
 rewrite(fOut);
 CheckError(OutFname,true);
 assign(fTOC,TOCfName);
 rewrite(fTOC);
 CheckError(TOCfName,true);
 { display information }
 writeln('Translating '+InFname+' -> '+OutFname+', '+TOCfName);
 { create & display the context view window }
 MakeWindow(ContextWnd,1,1,ScreenWidth,MaxContext+2,true,true,false,
            $70,$7F,$7E,' Context ');
 DisplayWindow(ContextWnd);
end;

function CutPad(s:string; l:byte):string;
begin
 CutPad:=Pad(copy(s,1,l),l);
end;

procedure ShowContext;
var
 i:byte;

begin
 for i:=1 to MaxContext do
  if i >LastContext then
   FastWriteWindow(CharStr(' ',ScreenWidth-2),i,1,$78)
  else
   FastWriteWindow(CutPad(Context^[i],ScreenWidth-2),i,1,$78);
 if MarkPos <>0 then begin
  ChangeAttributeWindow(MarkSize,LastContext,MarkPos,$3E);
  ReadKey;
 end;
end;

procedure AddStr2context;
begin
 if LastContext =MaxContext then
  Move(Context^[2],Context^[1],SizeOf(tContext)-SizeOf(string))
 else
  Inc(LastContext);
 Context^[LastContext]:=CurStr;
 MarkPos:=0;
end;

procedure DM_Run;
var
 i,b:byte;
 pst:byte;    {the parser stage}
 punkt:byte;  {item level: 1, 2, 3}
 c:char;      {current char}
 s:string;

begin
 repeat
  readln(fIn,CurStr);
  Inc(SrcLn);
  Inc(CurHeight);
  AddStr2context;
  { parse current string }
  CurStr:=TrimTrail(CurStr);
  if (CurHeight >=60) or
     ((Length(CurStr) <>0) and (CurStr[1] =#12)) then begin
   writeln(fOut,#12);
   if (Length(CurStr) <>0) and (CurStr[1] =#12) then
    Delete(CurStr,1,1);
   CurHeight:=0;
   Inc(CurPage);
  end;
  pst:=0;
  punkt:=0;
  i:=1;
  while i <=CurLen do begin
    c:=LoCase(CurStr[i]);
    case pst of
     0: if c ='x' then
         pst:=1
        else
         if c <>' ' then
          pst:=10;
     1: if c ='.' then
         pst:=2
        else
         pst:=10;
     2: if c ='y' then
         pst:=3
        else
         if c <>' ' then
          pst:=10
         else begin
          pst:=99;
          punkt:=1;
         end;
     3: if c ='.' then
         pst:=4
        else
         pst:=10;
     4: if c ='z' then
         pst:=5
        else
         if c <>' ' then
          pst:=10
         else begin
          pst:=99;
          punkt:=2;
         end;
     5: if c ='.' then
         pst:=6
        else
         pst:=10;
     6: if c <>' ' then
         pst:=10
        else begin
         pst:=99;
         punkt:=3;
        end;
     { --- }
     10: {do nothing yet} ;
     { --- }
     99: begin
          for b:=3 downto succ(punkt) do
           CurPunkt[b]:=0;
          Inc(CurPunkt[punkt]);
          case punkt of
           1: s:=CharStr(' ',5);
           2: s:=CharStr(' ',7);
           3: s:=CharStr(' ',11);
          end;
          for b:=1 to punkt do
           s:=s+Long2str(CurPunkt[b])+'.';
          s:=PadCh(s+' '+copy(CurStr,i,255)+' ','.',63);
          writeln(fTOC,s,' ',CurPage);
          i:=254;
         end;
    end;
    Inc(i);
  end;
  { show context screen }
  ShowContext;
  { write current string to the output file }
  writeln(fOut,CurStr);
 until EOF(fIn);
end;

begin
 DM_Init;
 DM_Run;
 DM_Done;
end.
