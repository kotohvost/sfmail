uses MSGXs,
     Dos,
     CRC_All,
     AddrXs;
var
  Fl:longint;
  SR:SearchRec;
begin
  FindFirst('E:\fido\msg\net\mymail\*.msg',AnyFile,SR);
  while DosError=0 do begin
    if ParseMsg('E:\fido\msg\net\mymail\',TakeFirstLong(SR.Name))=meOK then begin
      with MsgHeader do begin
        WriteLn('#',MsgInfo.MsgNum,' ---  ',Date);
        WriteLn('From: ',FromName,', ',Addr2Str(MsgInfo.OrigAddr));
        WriteLn('To  : ',ToName,', ',Addr2Str(MsgInfo.DestAddr));
        WriteLn('Subj: ',Subj);
        WriteLn('======------');
        WriteLn('Attribute: ',Flags2Str(MsgInfo.Flags));
        If MsgInfo.MsgEmpty then
          WriteLn('Msg is Empty')
        else
          WriteLn('Msg is not Empty');
        WriteLn;
      end;
    end;
    FindNext(SR);
 end;

end.