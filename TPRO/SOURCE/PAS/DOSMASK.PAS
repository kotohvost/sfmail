(* This is an xample program for compare dos` filenames with wildcards
   (c) Anton the Deinow, 1994
   All rights reserved.
   For NonCommercial usage only
*)

UNIT DosMask;

INTERFACE

function CheckDosMask(fName,Mask:string):boolean;

IMPLEMENTATION

uses
 Tstring_,
 Dos;

function CheckDosMask(fName,Mask:string):boolean;
var
 m_Nm,m_Xt:string;
 f_Nm,f_Xt,
 s,s1:PathStr;
 i:byte;

begin
 fName:=StLoCase(fName);
 Mask:=StLoCase(Mask);

 if Pos('.',Mask) <>0 then begin
  m_Nm:=Pad(Copy(Mask,1,pred(Pos('.',Mask))),8);
  m_Xt:=Copy(Mask,succ(Pos('.',Mask)),3);
 end
 else begin
  m_Nm:=Pad(Mask,8);
  m_Xt:='';
 end;

 if Pos('.',fName) <>0 then begin
  f_Nm:=Pad(Copy(fName,1,pred(Pos('.',fName))),8);
  f_Xt:=Copy(fName,succ(Pos('.',fName)),3);
 end
 else begin
  f_Nm:=Pad(fName,8);
  f_Xt:='';
 end;

 { удалим все `?' }

 while Pos('?',m_Nm) <>0 do begin
  i:=Pos('?',m_Nm);
  Delete(m_Nm,i,1);
  Delete(f_Nm,i,1);
 end;

 while Pos('?',m_Xt) <>0 do begin
  i:=Pos('?',m_Xt);
  Delete(m_Xt,i,1);
  Delete(f_Xt,i,1);
 end;


 { обpаботаем `*' }

 if Pos('*',m_Nm) <>0 then begin
  i:=Pos('*',m_Nm);
  Delete(m_Nm,i,8);
  Delete(f_Nm,i,8);
 end;

 if Pos('*',m_Xt) <>0 then begin
  i:=Pos('*',m_Xt);
  Delete(m_Xt,i,8);
  Delete(f_Xt,i,8);
 end;

 CheckDosMask:=(f_Nm =m_Nm) and (f_Xt =m_Xt);
end;

end.
