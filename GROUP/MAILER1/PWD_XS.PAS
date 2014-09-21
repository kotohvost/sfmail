{$F+,O+,I-}
unit pwd_xs;

INTERFACE

uses
 tString_,
 MsgXs,
 Config;

type
 tPwdCompareStatus=(
  pcs_NotFound,
  pcs_Invalid,
  pcs_Valid
 );

procedure Read_Pwd;
function CheckPassword(A:tAddress):boolean;
procedure Clear_Pwd;
procedure MatchPwdFtime;
function GetPassword(A:tAddress):string;
function GetMailPassword(A:tAddress):string;
function ComparePassword(A:tAddress; s:string):tPwdCompareStatus;

IMPLEMENTATION

uses
 Dos,
 WriteLog;

type
 pPassWord=^tPassWord;
 tPassWord=record
  nextPwd:pPassWord;
  addr:tAddress;
  pwd:string[14];
  mailpwd:string[8];
 end;

var
 PwdHead:pPassWord; {or nil ;-}
 PwdTail:pPassWord;
 PwdFtime:longint;

procedure Read_Pwd;
var
 tmpStr:string;
 pwdFile:text;
 p:pPassWord;
begin
 PwdHead:=nil;
 PwdTail:=nil;
 if pCfgRec^.Passwords <>'' then begin
   LogWrite(imLoading,pCfgRec^.Passwords,ld_All);
   FileMode:=$20;
   assign(PwdFile, pCfgRec^.Passwords);
   reset(PwdFile);
   FileMode:=$2;
   if IoResult =0 then begin
     GetFtime(pwdFile,PwdFtime);
     repeat
       ReadLn(PwdFile,tmpStr);
       If Pos(';',TmpStr)<>0 then
         Delete(TmpStr,Pos(';',TmpStr),255);
       tmpStr:=trim(tmpStr);
       if WordCount(tmpStr, [' ',^I]) in [2,3] then begin
         GetMem(p,SizeOf(tPassWord));
         FillChar(p^,SizeOf(tPassWord),0);
         Str2Addr(ExtractWord(1,tmpStr,[' ',^I]),p^.addr);
         p^.pwd:=StUpCase(ExtractWord(2,tmpStr,[' ',^I]));
         if WordCount(tmpStr, [' ',^I]) = 3 then
           p^.mailpwd:=StUpCase(ExtractWord(3,tmpStr,[' ',^I]));
         if PwdTail =nil then
          PwdHead:=p
         else
          PwdTail^.nextPwd:=p;
         PwdTail:=p;
       end;
     until EOF(PwdFile);
     close(PwdFile);
     if IoResult <>0 then;
   end
   else
    LogWrite(wmPwdNotUsed,'',ld_All);
 end;
end;

function CheckPassword(A:tAddress):boolean;
var
 p:pPassWord;

begin
 CheckPassword:=false;
 p:=PwdHead;
 while p <>nil do
  if CompWordStruct(p^.addr,A,SizeOf(tAddress)) =Equal then begin
   CheckPassword:=true;
   exit;
  end
  else
   p:=p^.nextPwd;
end;

function GetPassword(A:tAddress):string;
var
 p:pPassWord;

begin
 GetPassword:='';
 p:=PwdHead;
 while p <>nil do
  if CompWordStruct(p^.addr,A,SizeOf(tAddress)) =Equal then begin
   GetPassword:=p^.pwd;
   exit;
  end
  else
   p:=p^.nextPwd;
end;

function GetMailPassword(A:tAddress):string;
var
 p:pPassWord;

begin
 GetMailPassword:='';
 p:=PwdHead;
 while p <>nil do
  if CompWordStruct(p^.addr,A,SizeOf(tAddress)) =Equal then begin
   GetMailPassword:=p^.mailpwd;
   exit;
  end
  else
   p:=p^.nextPwd;
end;

function ComparePassword(A:tAddress; s:string):tPwdCompareStatus;
var
 p:pPassWord;

begin
 ComparePassword:=pcs_NotFound;
 s:=StUpCase(s);
 p:=PwdHead;
 while p <>nil do
  if CompWordStruct(p^.addr,A,SizeOf(tAddress)) =Equal then begin
   if p^.pwd =s then
    ComparePassword:=pcs_Valid
   else
    ComparePassword:=pcs_Invalid;
   exit;
  end
  else
   p:=p^.nextPwd;
end;

procedure Clear_Pwd;
begin
 while PwdHead <>nil do begin
  PwdTail:=PwdHead^.nextPwd;
  FreeMem(PwdHead,SizeOf(tPassWord));
  PwdHead:=PwdTail;
 end;
end;

procedure MatchPwdFtime;
var
 sr:SearchRec;

begin
 if Length(pCfgRec^.Passwords) <>0 then begin
  {$I+} FindFirst(pCfgRec^.Passwords,Archive,sr); {$I-}
  if (DosError =0) and (PwdFtime <>sr.Time) then begin
    LogWrite(wmPwdTimeWarn,'',ld_All);
    Clear_Pwd;
    Read_Pwd;
  end;
 end;
end;

end.
