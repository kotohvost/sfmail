
(*** dos -> windows types redefinitions ***)

UNIT Dos2win;

INTERFACE

uses
 WinTypes,
 WinDos;

type
 SearchRec=tSearchRec;
 PathStr=string[79];
 DateTime=tDateTime;

const
 ReadOnly =faReadOnly;
 Hidden   =faHidden;
 SysFile  =faSysFile;
 VolumeId =faVolumeId;
 Directory=faDirectory;
 Archive  =faArchive;
 AnyFile  =faAnyFile;

IMPLEMENTATION

end.
