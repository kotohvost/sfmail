{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$I OPLUS.INC}
{$ENDIF}

{*********************************************************}
{*                  TPSWITCH.PAS 1.00                    *}
{*                by TurboPower Software                 *}
{*********************************************************}

unit TpSwitch;
  {-Routine for switching screens on dual-display systems}

interface

uses
  TpCrt;

type
  WhichScreen = (Screen1, Screen2);
const
  MonoMode : Word = Mono;
  ColorMode : Word = CO80;
var
  CurrentScreen : WhichScreen;
  HasDualDisplays : Boolean;

procedure SwitchScreens(SC : WhichScreen);
  {-Switch from the current screen to the specified screen}

  {==================================================================}

implementation

type
  VidDispDataType =
    record
      { $40:$49 } CrtMode : Byte;
      { $40:$4A } CrtCols : Word;
      { $40:$4C } CrtLen : Word;
      { $40:$4E } CrtStart : Word;
      { $40:$50 } CursorPosn : array[0..7] of Word;
      { $40:$60 } CursorMode : Word;
      { $40:$62 } ActivePage : Byte;
      { $40:$63 } Addr6845 : Word;
      { $40:$65 } CrtModeSet : Byte;
      { $40:$66 } CrtPalette : Byte;
    end;
  EgaTableType = array[1..5] of Byte;
  EgaPtrType = ^EgaSavePtrs;
  EgaSavePtrs = array[1..4] of ^EgaSaveArea;
  EgaSaveArea =
    record
      case Boolean of
        True : (Table : array[0..255] of Byte);
        False : (Pntr : EgaPtrType);
    end;
var
  SaveVidDispTable : array[WhichScreen] of
    record
      Part1 : VidDispDataType;
      Part2 : EgaTableType;
      Part3 : EgaSaveArea;
    end;
  SaveEquipFlag : array[WhichScreen] of Byte;
  VidDispTable1 : VidDispDataType absolute $40 : $49;
  VidDispTable2 : EgaTableType absolute $40 : $84;
  VidDispTable3 : EgaPtrType absolute $40 : $A8;
  SaveWindMin, SaveWindMax : array[WhichScreen] of Word;
  EquipFlag : Byte absolute $40 : $10;
const
  SwitchedOnce : Boolean = False;

  procedure SaveCrtTable(SC : WhichScreen);
    {-Save all three parts of the EGA tables when switching screens.}
  begin
    with SaveVidDispTable[SC] do begin
      Part1 := VidDispTable1; {needed for all adapters}
      if (EnhancedDisplay >= EGA) and (EnhancedDisplay <= VGA) then begin
        {needed only for EGA/VGA}
        Part2 := VidDispTable2;
        Part3.Pntr := VidDispTable3;
      end;
    end;
    SaveWindMin[SC] := WindMin;
    SaveWindMax[SC] := WindMax;
  end;

  procedure RestoreCrtTable(SC : WhichScreen);
    {-Restore all three parts of the EGA tables when switching screens}
  begin
    with SaveVidDispTable[SC] do begin
      VidDispTable1 := Part1; {needed for all adapters}
      if (EnhancedDisplay >= EGA) and (EnhancedDisplay <= VGA) then begin
        {needed only for EGA/VGA}
        VidDispTable2 := Part2;
        VidDispTable3 := Part3.Pntr;
      end;
    end;
    WindMin := SaveWindMin[SC];
    WindMax := SaveWindMax[SC];
  end;

  procedure SwitchScreens(SC : WhichScreen);
    {-Switch from the current screen to the specified screen}
  begin
    {exit if dual displays not found or we're already on right screen}
    if (SC = CurrentScreen) or (not HasDualDisplays) then
      Exit;

    SaveCrtTable(CurrentScreen);
    SaveEquipFlag[CurrentScreen] := EquipFlag;

    if SwitchedOnce then begin
      EquipFlag := SaveEquipFlag[SC];
      RestoreCrtTable(SC);
    end
    else begin
      {we haven't switched before--we'll have to reset the video mode}
      if CurrentMode = 7 then begin
        EquipFlag := EquipFlag and $EF; {clear bit 4}
        TextMode(ColorMode);
      end
      else begin
        EquipFlag := EquipFlag or $10; {set bit 4}
        TextMode(MonoMode);
      end;
      SaveEquipFlag[SC] := EquipFlag;
      SaveCrtTable(SC);
      SwitchedOnce := True;
    end;

    {we've made the switch}
    CurrentScreen := SC;

    {reinitialize TPCRT}
    if Font8x8Selected then
      {this resets everything but WindMin, WindMax, and CheckSnow} ;
  end;

  function HasDualDisplaysPrim : Boolean;
    {-Return true if dual displays are installed}
  var
    SaveWord, VSeg : Word;
  begin
    if VideoSegment = $B000 then
      VSeg := $B800
    else
      VSeg := $B000;
    SaveWord := MemW[VSeg:0];
    MemW[VSeg:0] := $5555;
    HasDualDisplaysPrim := (MemW[VSeg:0] = $5555);
    MemW[VSeg:0] := SaveWord;
  end;

begin
  {initialize variables}
  HasDualDisplays := HasDualDisplaysPrim;
  CurrentScreen := Screen1;
  SaveEquipFlag[Screen1] := EquipFlag;
  SaveCrtTable(Screen1);
end.
