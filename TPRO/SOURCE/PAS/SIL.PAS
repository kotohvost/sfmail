{ Standard Input Line unit
  ver. 1.01/alpha
  (c) 1994 Anton the Deinow
}
{$O+,F+}
unit SiL;

INTERFACE

uses
 TpCrt,
 TpWindow,
 TpEdit,
 Tstring_;

function InputLine(Hdr:string;   {��������� ���� �����}
                   var S:string; {p�����p㥬�� ��p���}
                   cilWindow,cilFrame,cilHeader,cilLine:byte; {梥�}
                   Wdth:byte     {����� ��p��� �����}
                  ):boolean;     {T==Ok/F==Esc}
{-��p뢠�� ���� (���������: Hdr), �⠥� ��p��� (S) p����p�� wdth
  ����p�頥� � S ��p����p������� ��p���}

IMPLEMENTATION

function InputLine(Hdr:string;   {��������� ���� �����}
                   var S:string; {p�����p㥬�� ��p���}
                   cilWindow,cilFrame,cilHeader,cilLine:byte; {梥�}
                   Wdth:byte     {����� ��p��� �����}
                  ):boolean;     {T==Ok/F==Esc}
{-��p뢠�� ���� (���������: Hdr), �⠥� ��p��� (S) p����p�� wdth
  ����p�頥� � S ��p����p������� ��p���}
var
 ilW:WindowPtr;
 x1,x2,ml:byte;
 e:boolean;

begin
 if Length(Hdr) >Wdth then ml:=Length(Hdr)
 else ml:=Wdth;

 x1:=(76-ml) div 2;
 x2:=x1+ml+2;

 InputLine:=false;

 if not MakeWindow(ilW, x1,12,x2,14,
                   true,true,true,
                   cilWindow,
                   cilFrame,
                   cilHeader,
                   ' '+Hdr+' ') then exit;

 if not DisplayWindow(ilW) then exit;

 Inc(ml,2);

 FastWriteWindow(Pad('',Wdth), 1,(ml-Wdth) div 2, cilLine);
 ReadString('', 13,x1+((ml-Wdth) div 2), Wdth, $7,cilLine,$8C, e, S);

 KillWindow(ilW);

 InputLine:=not e;
end;

end.
