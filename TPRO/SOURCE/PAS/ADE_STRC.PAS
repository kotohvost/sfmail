(*
 Anton`s Dialog Engine
 ver 0.0.1/alpha
 (C) Anton the Deinow, 1995
 All rights reserved.
 ==========================
 tDialog is a record includes any controls, as CheckBoxes,
 RadioButtons, Buttons, EditLines, etc.
*)

{$X+,I-,O+,F+}

UNIT aDE_Strc;

INTERFACE

uses
 TpWindow,
 tString_;

const
 aDE_SIGN:string[8]='aDE[002]';
 MaxCtrl=32;
 { Control`s mode flags }
 cmf_Framed   =$0001;  { group has a frame }
 cmf_Header   =$0002;  { group has header (can be w/o frame) }
 cmf_RadioBttn=$0004;  { this group is a collection of radiobuttons }
 cmf_HdrLeft  =$0008;  {\ by default group header }
 cmf_HdrRight =$0010;  {/ will be centered        }
 cmf_PushBttn =$0020;  { this group is a collection of pushbuttons }
 cmf_Default  =$0040;  { default pushbutton }

type
 { dialog colors }
 tDlgColors=(
   dlc_BkGrnd,dlc_Frame,dlc_Header,
   cbc_BkGrnd,cbc_Frame,cbc_Header,cbc_HdrHlt,cbc_Item,cbc_ItemHlt,
    cbc_Select,cbc_Disabled,
   pbc_Item,pbc_Hilite,pbc_Default,pbc_Disabled,pbc_Select,pbc_Shadow
 );
 tDlgColor=array[tDlgColors] of byte;
 { accelerators struct }
 tAxel=record
   axChr:char; { (lo) char }
   axSC:byte;  { (hi) scan-code }
 end;
 { structure for each control in group: }
 pCtrlRec=^tCtrlRec;
 tCtrlRec=record
   ctrlFlag:word;                     { bitmaped flags see cmf_XXX }
   ctrlAxel:tAxel;                    { item accelerator }
   ctrlName:string[30];               { name of item }
   ctrlXL,ctrlYL,ctrlXH,ctrlYH:byte;  { coordinates of item }
 end;
 pCtrlArray=^tCtrlArray;
 tCtrlArray=array[1..MaxCtrl] of tCtrlRec;
 { each group of controls consist of: }
 pGroupRec=^tGroupRec;
 tGroupRec=record
   grpFlag:word;                  { bitmaped flags see cmf_XXX }
   grpAxel:tAxel;                 { group accelerator }
   grpHdr:string[30];             { group header }
   grpXL,grpYL,grpXH,grpYH:byte;  { coordinates of group frame }
   ctrlChkd:longint;
   ctrlDsbld:longint;
   TotalCtrls:byte;               { number of controls in group }
   Ctrls:pCtrlArray;              { descriptions of controls in group }
   prevGroup:pGroupRec;           { pointer to prev group of controls }
   nextGroup:pGroupRec;           { pointer to next group of controls }
 end;
 { dialog control structure }
 pDialog=^tDialog;

 tDialog=record
   dlgXL,dlgYL,dlgXH,dlgYH:byte;  { coodinates of dialog window }
   dlgClrs:tDlgColor;             { colors of dialog }
   dlgHdr:string[33];             { dialog header }
   TotalGroups:byte;              { total number of groups in dialog }
   GroupHead:pGroupRec;           { pointer to first group }
   GroupTail:pGroupRec;           { pointer to last group }
 end;

(* Structure of *.res file
   ~~~~~~~~~~~~~~~~~~~~~~~
 [Header]
 [{Dialog_Header_1}{Control_Group_1}..{Control_Group_X}]
       : : :
 [{Dialog_Header_N}{Control_Group_N}..{Control_Group_X}]

   Structure of *.res file Header
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 [aDE_SIGN]
 [Num_of_Dialogs]
 [{Dialog_name_1}{Offset_in_file}]
       : : :
 [{Dailog_name_N}{Offset_in_file}]
*)

 tDlgIdx=record
   dlgName:string[16];  {если тут меняешь, меняй и в aDE пpи иницализации!}
   dlgOfs:longint;
 end;

 tDlgResHdr=record
  aDE_VID:string[8];
  dlgTotal:byte;       { total number of dialogs in resource file }
 end;

 { runtime dialog structures }
 pDialogCtrl=^tDialogCtrl;
 tDialogCtrl=record
   dlgWin:WindowPtr;
   dlgStuff:pDialog;
    { === }
   pCurGroup:pGroupRec;  { group with focus }
   CurCtrl:byte;         { selected item }
 end;

 { notification messages }
 tDlgMsg=(
   dm_Open,          { after dialog window was drawn }
   dm_Close,         { before dialog is about to be done }
   dm_CtrlGetFocus,  { control get focus }
   dm_CtrlLoseFocus, { control lose focus }
   dm_GrpGetFocus,   { group receive the focus }
   dm_GrpLoseFocus,  { group lose the foucus }
   dm_Check,         { checkbox or radiobutton was checked }
   dm_UnCkeck,       { cb or rb was Unchecked }
   dm_None           { nothing }
 );

IMPLEMENTATION

end.
