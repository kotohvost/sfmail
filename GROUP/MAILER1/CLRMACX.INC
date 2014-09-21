(*** The Sf-Mail Color-processor ***)

type
 tColorId=(
  clrBlack,
  clrBlue,
  clrGreen,
  clrCyan,
  clrRed,
  clrMagenta,
  clrBrown,
  clrLightGray,

  clrDarkGray,
  clrLightBlue,
  clrLightGreen,
  clrLightCyan,
  clrLightRed,
  clrLightMagenta,
  clrYellow,
  clrWhite
 );

const
 ClrMacro:array[tColorId] of longint=(
  $D7457A76,  {clrBlack}
  $4B35C961,  {clrBlue}
  $DE11652F,  {clrGreen}
  $683DE47A,  {clrCyan}
  $70A09E05,  {clrRed}
  $21761F5F,  {clrMagenta}
  $AB6BE692,  {clrBrown}
  $D87B5A6E,  {clrLightGray}

  $EAC30EEF,  {clrDarkGray}
  $8A8E9375,  {clrLightBlue}
  $43B912C3,  {clrLightGreen}
  $A986BE6E,  {clrLightCyan}
  $6C2E795E,  {clrLightRed}
  $DB45FD43,  {clrLightMagenta}
  $6013FB2F,  {clrYellow}
  $5B3230BD   {clrWhite}
 );
 