{
����������������������������������Ŀ
� AEH: Anton`s Error Handling unit �
�       version: 1.01/beta         �
�       revision: 2 Aug 93         �
�    (c)1994 Anton the Deinow      �
������������������������������������
}

{$X+,I-,F+}

{$DEFINE FullDebug}

unit AEH;

INTERFACE

uses
 Tstring_;

var
 ShowErrorPtr:pointer;   {㪠��⥫� �� Far-�p�楤�p� ������ �訡��}

const
 ErrS:boolean=false;     {�᫨ true, ����� �p� ��᫥���� �맮�� �뫠 �訡��}
 LastErr:integer=0;      {��᫥���� �訡��}
 LastErrStr:string='';   {�������� ��᫥���� �訡��}

function CheckError(eText:string; ForceHalt:boolean):boolean;
{-�p���p�� IOresult �� ����稥 �訡��}

procedure ForceDosError(eCode:integer; eText:string; ForceHalt:boolean);
{-�p��㤨⥫쭮 ��뢠�� ᮮ�饭�� �� �訡��}

IMPLEMENTATION

procedure CallShowError(sErr_1,sErr_2:string);
inline
 ($FF/$1E/>ShowErrorPtr);  {Call DWord ptr [>ShowErrorPtr]}

procedure ShowError(eText:string);
begin
 Case LastErr of
  2 :LastErrStr:='File not found|'+eText;
  3 :LastErrStr:='Path not found|'+eText;
  4 :LastErrStr:='Too many open files';
  5 :LastErrStr:='File access denied|'+eText;

{$IFDEF FullDebug}
{  1 :LastErrStr:='Invalid function number';}

{  6 :LastErrStr:='Invalid file handle';}
{ 12 :LastErrStr:='Invalid file access code';}
 15 :LastErrStr:='Invalid drive number|'+eText;
{ 16 :LastErrStr:='Cannot remove current directory';}
{ 17 :LastErrStr:='Cannot rename across drives|'+eText;}

{102 :LastErrStr:='File not assigned|'+eText;}

{106 :LastErrStr:='Invalid numeric format';}

{200 :LastErrStr:='Division by zero';}
{201 :LastErrStr:='Range check error';}
{202 :LastErrStr:='Stack overflow error';}
{203 :LastErrStr:='Heap overflow error';}
{204 :LastErrStr:='Invalid pointer operation';}
{205 :LastErrStr:='Floating point overflow';}
{206 :LastErrStr:='Floating point underflow';}
{207 :LastErrStr:='Invalid floating point operation';}
{$ENDIF}

  100 :LastErrStr:='Disk read error|'+eText;
  101 :LastErrStr:='Disk write error|'+eText;
  103 :LastErrStr:='File not open|'+eText;
  104 :LastErrStr:='File not open for input|'+eText;
  105 :LastErrStr:='File not open for output|'+eText;
  150 :LastErrStr:='Disk is write-protected|'+eText;
  151 :LastErrStr:='DOS internal error';
  152 :LastErrStr:='Drive not ready|'+eText;
  154 :LastErrStr:='CRC error in data|'+eText;
  156 :LastErrStr:='Disk seek error|'+eText;
  157 :LastErrStr:='Unknown media type|'+eText;
  158 :LastErrStr:='Sector Not Found|'+eText;
  160 :LastErrStr:='Device write fault|'+eText;
  161 :LastErrStr:='Device read fault|'+eText;
  162 :LastErrStr:='Hardware failure|';

 else LastErrStr:='Unknow error #'+Long2Str(LastErr)+'|'+eText;
 end;

 if ShowErrorPtr <>nil then
   if Pos('|',LastErrStr)=0 then CallShowError(LastErrStr,'')
   else CallShowError(Copy(LastErrStr,1,pred(Pos('|',LastErrStr))),
                      Copy(LastErrStr,succ(Pos('|',LastErrStr)),200));
 ErrS:=true;
end;

function CheckError(eText:string; ForceHalt:boolean):boolean;
{�p���p�� IOresult �� ����稥 �訡��}
begin
 ErrS:=false;
 LastErr:=IOResult;
 if LastErr <>0 then begin
  ShowError(eText);
  If ForceHalt then begin  {�᫨ �㤥� ��室���, � ���p뢠�� ����}
{   repeat until EraseTopWindow=nil; }
   Halt(LastErr);
  end;
 end;
 CheckError:=ErrS;
end;

procedure ForceDosError(eCode:integer; eText:string; ForceHalt:boolean);
{-�p��㤨⥫쭮 ��뢠�� ᮮ�饭�� �� �訡��}
begin
 LastErr:=eCode;
 if LastErr <>0 then begin
   ShowError(eText);
   if ForceHalt then begin
{    repeat until EraseTopWindow=nil; }
    Halt(LastErr);
   end;
 end;
end;

begin
 ShowErrorPtr:=nil;
end.