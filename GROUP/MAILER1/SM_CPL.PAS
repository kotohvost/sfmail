{$I-,X+,O+,F+}

UNIT SM_Cpl;  {Subst compiler}

INTERFACE

uses
 Em_Cpl,
 Config;

const
 MaxSIsize=2048;    {¬ ªá p §¬¥p ¤ ­­ëå ®¤­®£® í«¥¬¥­â }

type
 { Item Header }
 pSiDat=^tSiDat;
 tSiDat=array[0..MaxSiSize] of byte;  { „ ­­ë¥ ¨§ áã¡áâ  ®¡ ã§«¥ }

 pSiHeader=^tSiHeader;
 tSiHeader=record
   siAddr:tAddress;        { ¤p¥á}
   LinkNext:PsiHeader;     {ãª § â¥«ì ­  á«¥¤.í«¥¬¥­â ¢ ¯ ¬ïâ¨}
   siLines:byte;           {ª-¢® «¨­¨© (0 == ®¤­  ®á­®¢­ ï)}
   siSize:word;            {Ž‹H›‰ p §¬¥p siDat}
   siDat:pSiDat;
 end;

 { â¨¯ë ¯®«¥© í«¥¬¥­â  }
 TsiFieldType=(
        siHidden,
        siTime,
        siFReq,
        siDial,
        siPhone,
        siWait,
        siZMode,
        siFlags,
        siMinBaud,
        siSessLimit,
        siTries,
        siScript,
        siHydra,

        siError   {unknown}
 );

procedure LoadSubstList;
{-çâ¥­¨¥ ¨ ª®¬¯¨«ïæ¨ï áã¡áâ }
procedure DisposeSubstList;
{-¢ëª¨¤ë¢ ­¨¥ ¨§ ¯ ¬ïâ¨}
(*procedure ShowSubstList;*)
{-¯®ª §ë¢ ¥â á®¤¥p¦¨¬®¥ á¯¨áª }
procedure ChangeDOW;
{-¯¥p¥ªpë¢ ¥â â¥ª.¤¥­ì ­¥¤¥«¨ (Config->CurDOW)}

const
 SubstListPtr:pSiHeader=nil;  {ãª § â¥«ì ­  ¯¥p¢ë© í«¥¬¥­â á¯¨áª }
 SubstListFtime:longint=0;    {¢p¥¬ï ä ©« }

IMPLEMENTATION

uses
 Dos,
 WriteLog,
 CRC_All,
 a002xs,
 MsgXs,
 aTime,
 Tstring_,
 EmStruct;

const
 DOverrFname='DOverr.';
 siFirst=siHidden;
 siLast=siHydra;

 SsiFieldType:array[siFirst..siLast] of string[7]=(
        'hidden',
        'time',
        'freq',
        'dial',
        'phone',
        'wait',
        'zmode',
        'flags',
        'minbaud',
        'limit',
        'tries',
        'script',
        'nohydra'
 );

 (*** áâpãªâãp  SubstList ¢ ¯ ¬ïâ¨ ***
 ÚÄÄÄÄÄÄÄÄÄÄÄÄ¿
 ³SubstListPtr³
 ÀÄÂÄÄÄÄÄÄÄÄÄÄÙ
   ³
   ³
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÒÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂúúúÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄ¿
³ ItemHeader   ºFieldType³FieldSize³FieldData³:::³FieldType³FieldSize³FieldData³
ÀÄÄÄÄÄÂÄÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁúúúÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÙ
      ³LinkNextº
      ÔÍÍÍÍÍÍÑÍ¼
   ÚÄÄÄÄÄÄÄÄÄÙ
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÒÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂúúúÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄ¿
³ ItemHeader   ºFieldType³FieldSize³FieldData³:::³FieldType³FieldSize³FieldData³
ÀÄÄÄÄÄÂÄÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁúúúÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÙ
      ³LinkNextº
      ÔÍÍÍÍÍÍÑÍ¼
   ÚÄ   ...
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÒÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂúúúÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄ¿
³ ItemHeader   ºFieldType³FieldSize³FieldData³:::³FieldType³FieldSize³FieldData³
ÀÄÄÄÄÄÂÄÄÄÄÄÄÄÄ×ÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁúúúÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÙ
      ³LinkNextº
      ÔÍÍÍÍÍÍÑÍ¼
            ÍÏÍ
*)

type
 Tlong2str=record
   len:byte;
   long:longint;
 end;

procedure ChangeDOW;
{-¯¥p¥ªpë¢ ¥â â¥ª.¤¥­ì ­¥¤¥«¨ (Config->CurDOW)}
var
 yr,mnth,dy:word;
 nDOW:word;
 bDOW:byte;
 nDay:integer;
 f:file;

begin
 GetDate(yr,mnth,dy,nDOW);
 nDay:=DayNumber(dy,mnth,yr);
 assign(f,AddBackSlash(JustPathname(pCfgRec^.SubstList))+DOverrFname+binXt);
 reset(f,1);
 if IoResult =0 then begin
   seek(f,pred(nDay));
   BlockRead(f,bDOW,1);
   if (bDOW <7) then nDOW:=bDOW;  { $FF == day not overriden }
 end;
 close(f);
 if IoResult<>0 then {clear};
 CurDOW:=System.lo(nDOW);
end;

procedure DisposeSubstList;
{-ã¤ «¥­¨¥ ¨§ ¯ ¬ïâ¨ á¯¨áª }
var
 p:pSiHeader;

begin
 while SubstListPtr <>nil do begin
   p:=SubstListPtr^.LinkNext;
   if SubstListPtr^.siDat<> nil then
     FreeMem(SubstListPtr^.siDat,SubstListPtr^.siSize);
   FreeMem(SubstListPtr,SizeOf(TsiHeader));
   SubstListPtr:=p;
 end;
end;

procedure LoadSubstList;
{-çâ¥­¨¥/®¡p ¡®âª /§ £pã§ª  ä ©«  ¯®¤áâ ­®¢®ª}
type
 tDayOverride=array[1..366] of byte;

var
 f:text;
 Interval:TimeArray;
 ItemHeader:pSiHeader;
 substItem:tSiDat;
 _2beContin:boolean;  {¯p®¤®«¦¥­¨¥ ¤«ï ¬­®£®áâp®ç­ëå § ¯¨á¥©}
 siT:TsiFieldType;
 s:string;
 WordCur:byte;
 substLn:word;  {­®¬¥p áâp®ª¨ áã¡áâ }
 d,m,y:word;
 Overriden:boolean;
 DayOverride:^tDayOverride;
 fOverr:file;

procedure WhatSubstWord(sw:string);
var
 z:TsiFieldType;

begin
 for z:=siFirst to siLast do
   if sw =SsiFieldType[z] then begin
     siT:=z;
     exit;
   end;
 LogWrite(emBadCmd,sw+#3+Long2str(substLn),ld_All);
 siT:=siError;
end;

procedure AddSubstItem;
{-¤®¡ ¢«ï¥¬ ItemHeader+SubstItem ¢ á¯¨á®ª}
begin
 if ItemHeader^.SiSize<>0 then begin
   ItemHeader^.LinkNext:=SubstListPtr; { ¥á«¨ nil â® §­ ç¨â nil;)}
   GetMem(ItemHeader^.siDat,ItemHeader^.SiSize);
   Move(SubstItem,ItemHeader^.siDat^,ItemHeader^.SiSize);
   SubstListPtr:=ItemHeader;
 end else
   { H åp¥­  ­ ¬ â ª®©? }
   FreeMem(ItemHeader,SizeOf(tSiHeader));
end;

procedure AddSubstStr(s:string);
begin
 if Length(s) =0 then exit;

 if (ItemHeader^.siSize+succ(Length(s))) >=MaxSIsize then begin
   LogWrite(emSMdata2large,'',ld_All);
   exit;
 end;

 SubstItem[ItemHeader^.siSize]:=byte(siT);       {â¨¯ ¯®«ï}
 Move(s[0],SubstItem[succ(ItemHeader^.siSize)],succ(Length(s)));
 Inc(ItemHeader^.siSize,Length(s)+2);    {¤«¨­  áâp®ª¨ + â¨¯ ¯®«ï}
end;

procedure AddZMode(s:string);
var
 i:tZMode;

begin
 i:=CvtZMode(s);
 s:=char(i);
 AddSubstStr(s);
end;

procedure AddSubstByte(s:string);
var
 b:word;

begin
 if not Str2word(s,b) then exit;
 s:=char(b);
 AddSubstStr(s);
end;

procedure AddSubstFlags(st:string);
var
 flgs:Tlong2str;
 fs:string absolute flgs;
 m:byte;

begin
 with flgs do begin
   long:=0;
   len:=4;
   for m:=1 to WordCount(st,[',']) do
     long:=long or Str2NodeFlag(ExtractWord(m,st,[',']));
   if long <>0 then
     AddSubstStr(fs)
 end;
end;

procedure AddSubstLimits(st:string; SessLim:boolean);
{ MinBaud/SessLimit }
var
 minb:tLong2str;
 fs:string absolute minb;

begin
 with minb do begin
  len:=4;
  long:=0;
  if ItemHeader^.siLines =0 then begin
   { ¤«ï mainline § ¯®¬¨­ ¥¬ ª ª minbaud_in/sesslimit_in, }
   { â ª ¨ minbaud_out/sesslimit_out }
   if Pos('/',st) =0 then begin
    if Str2long(st,long) then begin
     if SessLim then long:=long*1092;
     long:=long or LongPrefix;
     AddSubstStr(fs);
    end;
   end
   else begin
    if Str2long(ExtractWord(1,st,['/']),long) then begin
     if SessLim then long:=long*1092;
     AddSubstStr(fs);
    end;
    if Str2long(ExtractWord(2,st,['/']),long) then begin
     if SessLim then long:=long*1092;
     long:=long or LongPrefix;
     AddSubstStr(fs);
    end;
   end;
  end
  else begin
   { ¤«ï hidden ¬®¦¥âì ¡ëâì ¯p®¯¨á ­ â®«ìª® minbaud_out/sesslimit_out }
   if Pos('/',st) <>0 then begin
    if not Str2long(ExtractWord(2,st,['/']),long) then exit;
   end
   else
    if not Str2long(st,long) then exit;
   if SessLim then long:=long*1092;
   long:=long or LongPrefix;
   AddSubstStr(fs);
  end;
 end;
end;

procedure AddSubstTime;
begin
 if (ItemHeader^.siSize+2+(Interval.nTPer)*SizeOf(tTimePeriod)) >=MaxSIsize then begin
   LogWrite(emSMdata2large,'',ld_All);
   exit;
 end;

 SubstItem[ItemHeader^.siSize]:=byte(siT);
 Move(Interval,SubstItem[succ(ItemHeader^.siSize)],succ(SizeOf(tTimePeriod)*Interval.nTPer));
 Inc(ItemHeader^.siSize,SizeOf(tTimePeriod)*Interval.nTPer+2);
end;

procedure ParseSubstItem;
Var
 WordTotal : byte;
begin
 if s[Length(s)] ='+' then begin
   _2beContin:=true;
   Delete(s,Length(s),1);
   s:=Trim(s);
 end
 else _2beContin:=false;

 WordTotal:=WordCount(s,[' ',^I]);
 while WordCur <= WordTotal do begin
   WhatSubstWord(StLoCase(ExtractWord(WordCur,s,[' ',^I])));
   case siT of
     siHidden: begin
        Inc(ItemHeader^.siLines);
        AddSubstByte(Long2str(ItemHeader^.siLines));
     end;
     siHydra: begin
        AddSubstByte('0');
     end;
     siPhone,siDial: begin
        Inc(WordCur);
        AddSubstStr(ExtractWord(WordCur,s,[' ',^I]));
     end;
     siFReq,siTime: begin
        Inc(WordCur);
        if Str2timeArray(ExtractWord(WordCur,s,[' ',^I]),Interval) then
          AddSubstTime;
     end;
     siZMode: begin
        Inc(WordCur);
        AddZMode(StLoCase(ExtractWord(WordCur,s,[' ',^I])));
     end;
     siTries,siWait: begin
        Inc(WordCur);
        AddSubstByte(ExtractWord(WordCur,s,[' ',^I]));
     end;
     siFlags: begin
        Inc(WordCur);
        AddSubstFlags(StUpCase(ExtractWord(WordCur,s,[' ',^I])));
     end;
     siMinBaud,
     siSessLimit: begin
        Inc(WordCur);
        AddSubstLimits(ExtractWord(WordCur,s,[' ',^I]),siT =siSessLimit);
     end;
     siScript : begin
        Inc(WordCur);
        AddSubstStr(ExtractWord(WordCur,s,[' ',^I]));
     end;
   end;
   { next field }
   Inc(WordCur);
 end; {*WHILE*}

 if not _2beContin then AddSubstItem;
end;

procedure ParseDayOverride;
{ Day 13.04  0 }
var
 dy,yr,mnth,
 nDay:word;
 oDOW:word;
 i:byte;

begin
 GetDate(yr,dy,dy,dy);
 if (not Str2word(ExtractWord(3,s,[' ',^I]),oDOW)) or (oDOW >6) then exit;
 s:=ExtractWord(2,s,[' ',^I]);
 if (not Str2word(copy(s,1,pred(Pos('.',s))),dy)) or (dy >31) then exit;
 if (not Str2word(copy(s,succ(Pos('.',s)),2),mnth)) or (mnth >12) then exit;
 nDay:=DayNumber(dy,mnth,yr);
 DayOverride^[nDay]:=System.lo(oDOW);
 Overriden:=true;
end;

begin {*LOADSUBSTLIST*}
 DisposeSubstList;      {ã¤ «ï¥¬ ¨§ ¯ ¬ïâ¨}

 assign(f,pCfgRec^.SubstList);
 reset(f);
 if IoResult <>0 then begin    {­¥ã¤ «®áì ®âªpëâì ä ©«}
   LogWrite(emCantOpen,pCfgRec^.SubstList,ld_All);
   exit;
 end;

 LogWrite(imLoading,pCfgRec^.SubstList,ld_Screen);
 GetFtime(f,SubstListFtime);

 GetMem(DayOverride,SizeOf(tDayOverride));
 FillChar(DayOverride^,SizeOf(tDayOverride),$FF);
 Overriden:=false;

 _2beContin:=false;
 substLn:=0;

 repeat
   readln(f,s);
   Inc(substLn);
   if Pos(';',s) <>0 then s:=copy(s,1,pred(Pos(';',s)));
   s:=Trim(s);
   if Length(s) <>0 then begin
     if _2beContin then begin
       WordCur:=1;
       ParseSubstItem;
     end
     else
       if StLoCase(ExtractWord(1,s,[' ',^I])) ='day' then
         ParseDayOverride
       else begin
         { ‘®§¤ ¥¬ ¥«¥¬¥­â }
         GetMem(ItemHeader,SizeOf(tSIHeader));
         { —¨áâ¨¬ ¥£® }
         FillChar(ItemHeader^,SizeOf(tSiHeader),0);
         { —¨áâ¨¬ ¨­äã }
         FillChar(SubstItem,SizeOf(SubstItem),0);
         { ‡ ¯®«­ï¥¬  ¤p¥á }
         xStr2Addr(ExtractWord(1,s,[' ',^I]),ItemHeader^.siAddr);
         WordCur:=2;
         ParseSubstItem;
       end;
   end;
 until EOF(f);
 close(f);
 if IoResult <>0 then {clear};
 assign(fOverr,AddBackSlash(JustPathname(pCfgRec^.SubstList))+DOverrFname+binXt);
 if Overriden then begin
   rewrite(fOverr,1);
   BlockWrite(fOverr,DayOverride^,SizeOf(tDayOverride));
   close(fOverr);
 end
 else
   erase(fOverr);
 if IoResult <>0 then {clear};
 { dispose day-override list }
 FreeMem(DayOverride,SizeOf(tDayOverride));
 { set current dow }
 ChangeDOW;
end;

end.
