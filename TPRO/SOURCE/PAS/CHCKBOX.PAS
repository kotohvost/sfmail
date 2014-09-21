{Check Boxes unit
 (c)1994 Anton the Deinow
 ver 1.01/alpha}

unit ChckBox;
INTERFACE
uses
 TpEntry;

type
 TcbColor=(
  cbcWindow,
  cbcHeader,
  cbcFrame,
  cbcLabel,
  cbcString,
  cbcField,
  cbcHelp);

 TcbColorArray:array[TcbColor] of byte;

var
 cbESR:ESrecord;

procedure GetCheckBox(cbHeader:string;
                      
                      var Colors:TcbColorArray;
                       );

IMPLEMENTATION

{$F+}
function GetUser
{$F-}


end.
