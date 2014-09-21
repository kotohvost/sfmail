(*** Sf-Mail`s sound module ***)

{$X+,F+}

UNiT Sf_Snd;

INTERFACE

const
 MaxPattern=4;

type
 tSound=(
  TsndTick,      {вызываешь каждый Rescan Period}
  TsndRing,      {пpи появлении сигнала RING от модема (до поднятия тpубы)}
  TsndError,     {ошибка}
  TsndSessBegin, {я вызываю пpи BeginSession()}
  TsndSessOk,    {я вызываю пpи EndSession(FALSE)}
  TsndSessAbort, {я вызываю пpи EndSession(TRUE)}
  TsndHuman,     {ты вызываешь пеpед запуском Process_BBS}
  TsndUnpack     {я вызываю пpи pаспаковке Pkt}
 );

 tPattern=record
  Seq:word;
  Chg:integer;
  Dly:word;
  Num:word;
  MNum:word;
 end;

 tSoundArray=record
  Rep:word;
  Pat:array[1..MaxPattern] of tPattern;
 end;

 tAllSounds=array[tSound] of tSoundArray;

const
 Sound_Of:array[tSound] of word=(
  $1,   {TsndTick}
  $2,   {TsndRing}
  $4,   {TsndError}
  $8,   {TsndSessBegin}
  $10,  {TsndSessOk}
  $20,  {TsndSessAbort}
  $40,  {TsndHuman}
  $80   {TsndUnpack}
 );

 AllSounds:tAllSounds=(
 { описание звуков }
 {sndTick:tSoundArray=} (
  Rep:1;
  Pat:(
   (Seq:93;    Chg:0; Dly:5;   Num:1; MNum:1),
   (Seq:0;     Chg:0; Dly:350; Num:1; MNum:1),
   (Seq:113;   Chg:0; Dly:7;   Num:1; MNum:1),
   (Seq:$FFFF; Chg:0; Dly:0;   Num:0; MNum:0)
  )
 ),

 {sndRing:tSoundArray=} (
  Rep:4;
  Pat:(
   (Seq:3500; Chg:0; Dly:50; Num:1; MNum:1),
   (Seq:3000; Chg:0; Dly:50; Num:1; MNum:1),
   (Seq:4000; Chg:0; Dly:5;  Num:1; MNum:1),
   (Seq:$FFFF; Chg:0; Dly:0; Num:0; MNum:0)
  )
 ),

 {sndError:tSoundArray=} (
  Rep:1;
  Pat:(
   (Seq:200;   Chg:1;  Dly:2; Num:800; MNum:15),
   (Seq:1000;  Chg:-1; Dly:2; Num:800; MNum:15),
   (Seq:$FFFF; Chg:0;  Dly:0; Num:0;   MNum:0),
   (Seq:$FFFF; Chg:0; Dly:0;  Num:0;   MNum:0)
  )
 ),

 {sndSessBegin:tSoundArray=} (
  Rep:1;
  Pat:(
   (Seq:37;    Chg:1; Dly:10; Num:64; MNum:30),
   (Seq:$FFFF; Chg:0; Dly:0;  Num:0;  MNum:0),
   (Seq:$FFFF; Chg:0; Dly:0;  Num:0;  MNum:0),
   (Seq:$FFFF; Chg:0; Dly:0;  Num:0;  MNum:0)
  )
 ),

 {sndSessOk:tSoundArray=} (
  Rep:16;
  Pat:(
   (Seq:5700;  Chg:1500; Dly:2; Num:7; MNum:2),
   (Seq:$FFFF; Chg:0;    Dly:0; Num:0; MNum:0),
   (Seq:$FFFF; Chg:0;    Dly:0; Num:0; MNum:0),
   (Seq:$FFFF; Chg:0;    Dly:0; Num:0; MNum:0)
  )
 ),

 {sndSessAbort:tSoundArray=} (
  Rep:1;
  Pat:(
   (Seq:900;   Chg:1; Dly:5; Num:100; MNum:30),
   (Seq:$FFFF; Chg:0; Dly:0; Num:0;   MNum:0),
   (Seq:$FFFF; Chg:0; Dly:0; Num:0;   MNum:0),
   (Seq:$FFFF; Chg:0; Dly:0; Num:0;   MNum:0)
  )
 ),

 {sndHuman:tSoundArray=} (
  Rep:10;
  Pat:(
   (Seq:300;   Chg:150; Dly:6; Num:10; MNum:3),
   (Seq:$FFFF; Chg:0;   Dly:0; Num:0;  MNum:0),
   (Seq:$FFFF; Chg:0;   Dly:0; Num:0;  MNum:0),
   (Seq:$FFFF; Chg:0;   Dly:0; Num:0;  MNum:0)
  )
 ),

 {sndUnpack:tSoundArray=} (
  Rep:1;
  Pat:(
   (Seq:12000; Chg:-100; Dly:6; Num:100; MNum:30),
   (Seq:$FFFF; Chg:0;    Dly:0; Num:0;   MNum:0),
   (Seq:$FFFF; Chg:0;    Dly:0; Num:0;   MNum:0),
   (Seq:$FFFF; Chg:0;    Dly:0; Num:0;   MNum:0)
  )
 )
 ); (*AllSounds*)

(************************************)

procedure PlaySound(snd:tSound);

IMPLEMENTATION

uses
 Config,
 TpCrt,
 RelTQ;

const
 Silence=0;
 MTaskSndFlg= not (mtMS_DOs_5 or mtOS_2 or mtHLT or mtIPX or mtUndefined);

procedure PlaySound(snd:tSound);

procedure Play;
var
 W:integer;
 i:byte;
 n:word;
 z:word;
 LastPattern:byte;

procedure FindLastPattern;
var
 i:byte;

begin
 LastPattern:=0;
 for i:=1 to MaxPattern do with AllSounds[snd] do
   if Pat[i].Seq =$FFFF then begin
     LastPattern:=pred(i);
     if LastPattern =0 then Inc(LastPattern);
     exit;
   end
   else
    if (MTaskSndFlg and mtOSVER) <>0 then
      Pat[i].Num:=Pat[i].MNum;

 LastPattern:=MaxPattern;
end;

begin

 FindLastPattern;

 with AllSounds[snd] do
  for n:=1 to Rep do
   for i:=1 to LastPattern do begin
     W:=0;
     if Pat[i].Seq =0 then
       MSound(Silence,Pat[i].Dly)
     else
      for z:=1 to Pat[i].Num do begin
        MSound(Pat[i].Seq+W,Pat[i].Dly);
        Inc(W,Pat[i].Chg);
      end;
   end;

 MSound(Silence,Silence);
end;

begin
 if (pCfgRec^.SoundControl and Sound_Of[snd]) <>0 then Play;
 {case snd of
   TsndTick: Play(AllSounds[TsndTick]);
   TsndRing: Play(AllSounds[TsndRing]);
   TsndError: Play(AllSounds[TsndError]);}
   {TsndSessBegin: Play(sndSessBegin);
   TsndSessOk: Play(sndSessOk);
   TsndSessAbort: Play(sndSessAbort);
   TsndHuman: Play(sndHuman);
   TsndUnpack: Play(sndUnpack);
 end;}
end;

end.