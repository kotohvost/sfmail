(*** ADDRESS-PROCESSING ***)
unit AddrXs;
interface

type
 tAddress=record   { ��p���p� ��p�� }
  Zone,
  Net,
  Node,
  Point:word;
 end;

function xAddr2str(z,n,f,p:word):string;
{-����p�頥� ��p�� � ���� ��p���}

function Addr2str(A:tAddress):string;
{-����p�頥� ��p�� � ���� ��p���}

procedure Str2addr(sA:string; var Address:tAddress);
{-��p���� �� ��p��� � ��p��}

implementation

uses tstring_;

function xAddr2str(z,n,f,p:word):string;
{-����p�頥� ��p�� � ���� ��p���}
begin
 xAddr2str:=Long2str(z)+':'+Long2str(n)+'/'+Long2str(f)+'.'+Long2str(p);
end;

function Addr2str(A:tAddress):string;
{-����p�頥� ��p�� � ���� ��p���}
begin
 with A do
  if point<>0 then
   Addr2str:=Long2str(Zone)+':'+Long2str(Net)+'/'+Long2str(Node)+
             '.'+Long2str(Point)
  else
   Addr2str:=Long2str(Zone)+':'+Long2str(Net)+'/'+Long2str(Node);
end;

procedure Str2addr(sA:string; var Address:tAddress);
{-��p���� �� ��p��� � ��p��}
begin
 FillChar(Address,SizeOf(tAddress),0);
 sA:=Trim(sA);
 if Pos(':',sA)<>0 then begin
  { ���� ���� }
  if not Str2Word(extractWord(1,sA,[':']),Address.Zone) then
    Address.Zone:=0;
  sA:=ExtractWord(2,sA,[':','@']);
 end;
 if Pos('/',sA)<>0 then begin
  { ���� ���� }
  if not Str2Word(extractWord(1,sA,['/']),Address.Net) then
    Address.Net:=0;
  sA:=ExtractWord(2,sA,['/']);
 end;
 if not Str2Word(extractWord(1,sA,['.']),Address.Node) then
    Address.Node:=0;
 sA:=ExtractWord(2,sA,['.']);

 if Length(sA)<>0 then begin
  { ����� ���� }
   if not Str2Word(sA,Address.Point) then
     Address.Point:=0;
 end;
end;

end.