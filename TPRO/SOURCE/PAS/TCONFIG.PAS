{
 Text-style config file processing library.
 (c)1994 AD SR-Lab. All rights reserved.
 version 2.01/beta
}
{$I-}

Unit Tconfig;

INTERFACE

uses
 CRC_All,
 HM,
 Dos,
 tString_;

type
 {-⨯� �p�㬥�⮢}
 ArgType=
 (
  ptSwitch,
  ptWord,
  ptByte,
  ptInt,
  ptLong,
  ptChar,
  ptString,
  ptQuote,
  ptPath,
  ptHword,
  ptHbyte,
  ptHlong,
  ptBlank
 );

 {-���ᠭ�� ���p� ��� ���p������ 䠩�� ���䨣�}
 tcfgReadBuf=^acfgReadBuf;
 acfgReadBuf=array[1..16384] of char;

 {-����� ��᫥���� ���p�樨 � ���䨣��}
 tCfgStatus=(stCfgOK,   {-no comments}
          stCfgError,   {-�뫠 �訡��}
          stCfgOpened,  {-���䨣 ��p��}
          stCfgEOF,     {-���⨣��� ����� 䠩��}
          stCfgClosed); {-���䨣 ���p��}

 {-���� �p������� ���䨣��}
 tCfgRecord=record
  CfgHandle:text;         {-�����}
  CfgName:PathStr;        {-��� ���䨣�}
  CfgStatus:tCfgStatus;   {-���ﭨ� ���䨣�}
  CfgErrorCode:integer;   {-��� �訡��}
  CfgLine:word;           {-��᫥���� ��p����뢠���� ��p��� ��p���}
  CfgReadBuf:tcfgReadBuf; {-㪠��⥫� �� ���-���p 16k}
 {-=-}
  OnOffSwitch:array[0..1] of string[3]; {-���� No/Yes}
  CommentChar:char;   {ᨬ��� ��砫� ������p��}
  QuoteChar:char;     {������⥫� ����窨 ��� ����p������}
 end;

const
 {-��p����p� default}
 {-��p�����⥫�}
 defOnOffSwitch:array[0..1] of string[3]=('no','yes');
 {-ᨬ��� ��砫� ������p�� � ��p���}
 defCommentChar:char=';';
 {-������⥫� ����祪}
 defQuoteChar:char='"';

 {-���� ����p����� �訡��}
 UnknowCtlWord :integer=5000;  {-����������� ����}
 ErrorArgument :integer=5001;  {-���p������ ap�㬥��}

 {-���祭�� ��� ��p����p��}
 ValSwitch:boolean=false; {ptSwitch}
 ValWord:word=0;          {ptWord, ptHword}
 ValByte:byte=0;          {ptByte, ptHbyte}
 ValInt:integer=0;        {ptInt}
 ValLong:longint=0;       {ptLong, ptHlong}
 ValChar:char=#0;         {ptChar}
 ValString:string='';     {ptString}

 {-����� �p������� ��᫥���� �p��⠭��� ���祢�� ᫮��}
 LastCtlWord:string='';

{�� Procedures}

function ConfigInit(var CfgRec:tCfgRecord; ConfigName:PathStr):boolean;
 {-��p뢠�� ���䨣 ConfigName ��� �⥭��.
   � ConfigHandl ������ 堭�� ��� ��p�⮣� ���䨣�}

function ConfigNextRead(var CfgRec:tCfgRecord;  {-堭��}
                        nCtlWords:word;       {-�ᥣ� ���祩}
                        NextWordfunc:pointer; {-㪠��⥫� �� FAR-�㭪��,
                                                ������ ᫥�.����}
                        WordTypefunc:pointer; {-㪠��⥫� �� FAR-�㭪��,
                                                ������ ⨯ ���� �� ����p�}
                        var CtlWordNum:word   {-No ��������� ����}
                       ):boolean;
 {-�⠥� ᫥������ ��p���, ��p����� ������p��
   ��p�� ����, ��� ��� � ᯨ᪥ � ��p����� �p�������
   �� �/� ���짮��⥫� ���㦨����� ������� ����}

procedure ConfigClose(var CfgRec:tCfgRecord);
 {-���p뢠�� ���䨣}

{�������������������������������������}
IMPLEMENTATION

function WasCfgError(var CfgRec:tCfgRecord):boolean;
{-T/F = �뫠 �訡��/�� �뫮}
var
 Err:integer;

begin
 with CfgRec do
 begin
  WasCfgError:=false;
  CfgErrorCode:=0;

  Err:=IOResult;
  if Err <>0 then
  begin
   CfgStatus:=stCfgError;
   CfgErrorCode:=Err;
   WasCfgError:=true;
  end;
 end;
end;

procedure ForceCfgError(var CfgRec:tCfgRecord; Err:integer);
{-�p��㤨⥫쭮 ���⠢��� 䫠� �訡�� Err}
begin
 with CfgRec do
 begin
  CfgStatus:=stCfgError;
  CfgErrorCode:=Err;
 end;
end;

function Str2byte(var CfgRec:tCfgRecord; s:string;var b:byte):boolean;
{-�p���p�� � �����p���}
var
 w:word;

begin
 Str2byte:=false;
 if not Str2word(s,w) then ForceCfgError(CfgRec,ErrorArgument)
 else
 begin
  Str2byte:=true;
  b:=Lo(w);
 end;
end;

function ConfigInit(var CfgRec:tCfgRecord; ConfigName:PathStr):boolean;
 {-��p뢠�� ���䨣 ConfigName ��� �⥭��.
   �������� ���� ����� �p������� ���䨣��}

begin
 FillChar(CfgRec,SizeOf(tCfgRecord),0);
 with CfgRec do
 begin
  CfgName:=ConfigName;
  GetMem(CfgReadBuf,SizeOf(aCfgReadBuf));

  assign(CfgHandle,ConfigName);
  SetTextBuf(CfgHandle,CfgReadBuf^);

  reset(CfgHandle);

  if not WasCfgError(CfgRec) then
  begin
   CfgStatus:=stCfgOpened;
   ConfigInit:=true;
   {-���樠����p㥬 ��䮫⮢� ����}
   Move(defOnOffSwitch[0], OnOffSwitch[0], SizeOf(defOnOffSwitch));
   CommentChar:=defCommentChar;
   QuoteChar:=defQuoteChar;
  end
  else begin
   FreeMem(CfgReadBuf,SizeOf(aCfgReadBuf));
   ConfigInit:=false;
  end;
 end;
end;

function ConfigNextRead(var CfgRec:tCfgRecord;  {-堭��}
                        nCtlWords:word;       {-�ᥣ� ���祩}
                        NextWordfunc:pointer; {-㪠��⥫� �� FAR-�㭪��,
                                                ������ ᫥�.����}
                        WordTypefunc:pointer; {-㪠��⥫� �� FAR-�㭪��,
                                                ������ ⨯ ���� �� ����p�}
                        var CtlWordNum:word   {-No ��������� ����}
                       ):boolean;
 {-�⠥� ᫥������ ��p���, ��p����� ������p��
   ��p�� ����, ��� ��� � ᯨ᪥ � ��p����� �p�������
   �� �/� ���짮��⥫� ���㦨����� ������� ����}
var
 at:ArgType;
 n,nn:byte;
 i,
 w:word;
 y:integer;
 l:longint;
 s,
 ss:string;

function CallNextWordfunc(w:word):longint;
 {-Call UserRoutine with an action code}
inline(
 $FF/$5E/<NextWordfunc); {call far dword ptr [bp+<NextWordfunc]}

function CallWordTypefunc(w:word):ArgType;
 {-Call UserRoutine with an action code}
inline(
 $FF/$5E/<WordTypefunc); {call far dword ptr [bp+<WordTypefunc]}

begin  {-ConfigNextRead}
 with CfgRec do
 repeat
  readln(CfgHandle,s);
  Inc(CfgLine);

   if WasCfgError(CfgRec) then begin
     ConfigNextRead:=false;
     exit;
   end;

  s:=Trim(s);
  n:=Pos(CommentChar,s);
  if n<>0 then s:=Copy(s,1,pred(n));

  if Length(s) <>0 then
  begin
   LastCtlWord:=ExtractWord(1,s,[' ',^I]);
   ss:=StLoCase(LastCtlWord);
   l:=strCRC32(ss);
   for i:=1 to nCtlWords do
    if CallNextWordfunc(i) =l then
    begin
     CtlWordNum:=i;
     at:=CallWordTypefunc(i);
     ss:=ExtractWord(2,s,[' ',^I]);
     ConfigNextRead:=false;
      Case at of
       ptSwitch: if StLoCase(ss)=OnOffSwitch[0] then ValSwitch:=false
                 else
                  if StLoCase(ss)=OnOffSwitch[1] then ValSwitch:=true
                  else exit;
       ptWord: if not Str2word(ss,w) then
               begin
                ForceCfgError(CfgRec,ErrorArgument);
                exit;
               end
               else ValWord:=w;

       ptByte: if not Str2byte(CfgRec,ss,n) then exit
               else ValByte:=n;

       ptInt:  if not Str2int(ss,y) then
               begin
                ForceCfgError(CfgRec,ErrorArgument);
                exit;
               end
               else ValInt:=y;

       ptLong: if not Str2long(ss,l) then
               begin
                ForceCfgError(CfgRec,ErrorArgument);
                exit;
               end
               else ValLong:=l;

       ptChar: ValChar:=ss[1];
       ptQuote: begin
                  s:=Copy(s,succ(Pos(QuoteChar,s)),255);
                  ValString:=Copy(s,1,pred(Pos(QuoteChar,s)));
                 end;
       ptPath,
       ptString: begin
                  n:=Pos(' ',s);
                  nn:=Pos(^I,s);
                  if (n=0)and(nn=0) then ForceCfgError(CfgRec,ErrorArgument)
                  else
                   if (n=0) or ((nn<>0)and(nn<n)) then n:=nn;
                  ValString:=Trim(Copy(s,succ(n),255));
                  if at =ptPath then ValString:=AddBackSlash(ValString);
                 end;

       ptHbyte: ValByte:=Hex2Byte(ss);
       ptHword: ValWord:=Hex2Word(ss);
       ptHlong: ValLong:=Hex2Long(ss);
       {ptBlank: = Dummy}
      end;

     ConfigNextRead:=true;
     exit;
    end;
   ConfigNextRead:=false;
   CfgStatus:=stCfgError;
   CfgErrorCode:=UnknowCtlWord;  {-����������� ����}
   exit;
  end;
 until EOF(CfgHandle);

 CfgRec.CfgStatus:=stCfgEOF;
 ConfigNextRead:=true;
end;

procedure ConfigClose(var CfgRec:tCfgRecord);
 {-���p뢠�� ���䨣}
begin
 if TextRec(CfgRec.cfgHandle).Mode<>fmClosed then
 begin
  Close(CfgRec.CfgHandle);
  if not WasCfgError(CfgRec) then CfgRec.CfgStatus:=stCfgClosed;
  FreeMem(CfgRec.CfgReadBuf,SizeOf(aCfgReadBuf));
 end;
end;

begin
end.
