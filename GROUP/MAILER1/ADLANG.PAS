(*
                      advanced Language Engine
                     (c) Anton the Deinow, 1996
*)

{$O+,F+,I-}

unit adLang;

INTERFACE

uses
 Dos;

const
 MaxLngIdx=10000;
 MaxLngArray=$FF00;

type
 tLngSign=string[27];
 tLngHdr=record
  LngSign:tLngSign;
  TotalMsgs:word;
  LngArraySiz:word;
 end;

 tLngIdxRec=record
  MsgCode:word;
  MsgOfs:word;
 end;

 pLngIdx=^tLngIdx;
 tLngIdx=array[1..MaxLngIdx] of tLngIdxRec;

 pLngArray=^tLngArray;
 tLngArray=array[1..MaxLngArray] of byte;

const
 DefLngSign:tLngSign='(ad) Language file v0.0.1/a';
 LngIdx:pLngIdx=nil;
 LngIdxSiz:word=0;
 LngArray:pLngArray=nil;
 LngArraySiz:word=0;

function Language_Init(lfn:PathStr):boolean;
procedure Language_Done;

function TranslateStr(mc:word; par:string):string;

IMPLEMENTATION

uses
 tString_;

function Language_Init(lfn:PathStr):boolean;
var
 f:file;
 hdr:tLngHdr;
begin
 Language_Init:=false;
 FileMode:=$20;
 assign(f,lfn);
 reset(f,1);
 FileMode:=$2;
 if IoResult <>0 then exit;
 BlockRead(f,hdr,SizeOf(tLngHdr));
 if hdr.LngSign <>DefLngSign then begin
  writeln('Incorrect language file version.');
  exit;
 end;
 LngIdxSiz:=hdr.TotalMsgs;
 LngArraySiz:=hdr.LngArraySiz;
 GetMem(LngIdx,SizeOf(tLngIdxRec)*LngIdxSiz);
 BlockRead(f,LngIdx^,SizeOf(tLngIdxRec)*LngIdxSiz);
 GetMem(LngArray,LngArraySiz);
 BlockRead(f,LngArray^,LngArraySiz);
 close(f);
 Language_Init:=true;
end;

procedure Language_Done;
begin
 if LngIdx <>nil then
  FreeMem(LngIdx,SizeOf(tLngIdxRec)*LngIdxSiz);
 if LngArray <>nil then
  FreeMem(LngArray,LngArraySiz);
end;

function TranslateStr(mc:word; par:string):string;
var
 s,s1:string;
 w:word;
 i:byte;

begin
 for w:=1 to LngIdxSiz do
   if mc =LngIdx^[w].MsgCode then begin
    Move(LngArray^[LngIdx^[w].MsgOfs],s[0],LngArray^[LngIdx^[w].MsgOfs]+1);
    i:=1;
    repeat
     if s[i] ='%' then begin
      Inc(i);
      if Str2word(copy(s,i,1),w) then begin
       s1:=ExtractWord(w,par,[#3]);
       Delete(s,pred(i),2);
       Insert(s1,s,pred(i));
       Inc(i,Length(s1));
      end;
     end
     else
      Inc(i);
    until i >=Length(s);
    TranslateStr:=s;
    exit;
   end;
 TranslateStr:='(*UNDEFINED MSG CODE #'+Long2str(mc)+'*)';
end;

end.
