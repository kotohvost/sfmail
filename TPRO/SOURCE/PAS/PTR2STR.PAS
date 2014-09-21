{$S-,R-,I-,V-,F-,B-}

UNIT Ptr2str;

INTERFACE

function Pointer2String(P : Pointer) : string;
  {-Convert a pointer to a string suitable for passing on command line}

function String2Pointer(S : string) : Pointer;
  {-Convert a string formatted by Pointer2String to a pointer
    Returns nil if S is an invalid string}

IMPLEMENTATION

{$L PTR2STR}
function Pointer2String(P : Pointer) : string; external {PTR2STR} ;
function String2Pointer(S : string) : Pointer; external {PTR2STR} ;

end.
