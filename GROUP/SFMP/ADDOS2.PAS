
(***                  (Ad)vanced Dos unit for OS/2                  ***)
(***  Copyright (C) Anton the Deinow [UNIVERSAL SOFTWARE Inc], 1996 ***)
(***                      All rights reserved                       ***)

{$X+,I-}

unit adDos2;

INTERFACE

uses
 Use32,
 Os2def,
 Os2base,
 Dos;

const
 faNormal=AnyFile-(VolumeID and Directory);

function ExistFile(fName:PathStr):boolean;
{ checks a file existance }

function TimeMs:longint;
{ returns time in msecs past midnight }

IMPLEMENTATION

function ExistFile(fName:PathStr):boolean;
{ checks a file existance }
var
 sr:SearchRec;

begin
 if Length(fName) =0 then ExistFile:=false
 else begin
  FindFirst(fName,AnyFile,sr);
  ExistFile:=(DosError =0) and (sr.Attr and (VolumeId or Directory) =0);
 end;
end;

function TimeMs:longint;
{ returns time in msecs past midnight }
var
 dt:Os2base.DateTime;

begin
 DosGetDateTime(dt);
 with dt do
  TimeMs:=1000*(seconds+60*(minutes+60*hours))+10*hundredths;
end;

end.

