
{$X+,I-,O+,F+,V-}

UNIT ERP;

INTERFACE

uses
 Dos;

procedure ERP_Call(ReqFname:PathStr);

IMPLEMENTATION

uses
 Config,
 Tstring_,
 SwapR,
 EmStruct,
 WriteLog;

procedure ERP_Call(ReqFname:PathStr);
var
 TRx:tTRxLog;
 f:text;
 o:integer;
 rs:string;
 l:longint;
 oldFileMode : byte;

begin
 rs:=pCfgRec^.FR_Xternal;
 o:=Pos('*q',StLoCase(rs));
 if o <>0 then begin
   Delete(rs,o,2);
   Insert(ReqFname,rs,o);
 end;
 { запуск ERP }
 Swap_Run(rs,true);
 { пеpеписываем список в fSntLog }
 if IoResult <>0 then {clear};
 oldFileMode:=fileMode;
 filemode:=$20;
 assign(f,pCfgRec^.FR_Response);
 reset(f);
 fileMode:=oldFileMode;
 if IoResult <>0 then begin
   with SessionControl^ do begin
     l:=FilePos(fSntLog);
     seek(fSntLog,FileSize(fSntLog));
     repeat
       readln(f,rs);
       rs:=Trim(rs);
       if Length(rs) <>0 then begin
         TRx.Name:=copy(rs,2,255);
         case rs[1] of
           '?','^': TRx.FileType:=ftEAS;
           '-': begin
                  TRx.FileType:=ftMustDie;
                  reset(fReqList);
                  seek(fReqList,FileSize(fReqList));
                  write(fReqList,TRx);
                  close(fReqList);
                end;
           '+': TRx.FileType:=ftDontTouch;
         end;
         write(fSntLog,TRx);
         Inc(nToSend);
         if EOF(f) then
           LogWrite(imFRQlistEnd,TRx.Name,ld_SessAll)
         else
           LogWrite(imFRQlistStart,TRx.Name,ld_SessAll);
         FReqIn:=true;
       end;
     until EOF(f);
     seek(fSntLog,l);
   end;
 end else begin
   LogWrite(emCantOpen,pCfgRec^.FR_Response,ld_SessAll);
 end;
 close(f);
 o:=IoResult;
end;

end.
