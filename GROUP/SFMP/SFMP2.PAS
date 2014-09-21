
{$I-}
{$M 32768,0,10240}

PROGRAM SfMp2;  {SantaFox Mail Packer for OS/2}

uses
 Use32,
 SfMpMain;

begin
 SfMp_Init;
 SfMp_Run;
 SfMp_Done;
end.

