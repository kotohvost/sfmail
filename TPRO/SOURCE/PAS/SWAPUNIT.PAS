
UNIT SwapUnit;

INTERFACE
 function DosSwap(Path,Cmdl:string):integer;
 function SwapExec(Path,Cmdl:string):integer;
 
var
 pSwap    :function(SwapEnvID:byte; Path,Cmdl,SwapPath:string):integer;
 SwapEnvID:byte;
 SwapPath :string;
 
{����⠭�� ��� ��।������ �㤠 ࠧ���� ᢮�����.
��ꥤ������� � ������� ������ OR}
const
 XMS  = $01;
 EMS  = $02;
 EXT  = $04;
 HDD  = $08;

{����⠭�� �訡�� ����᪠ Swap}
 NOSWAP     = $8000;
 NOCHNGMCB  = $8001;
 NOTMEM     = $8002;
 EMOVXMS    = $8003;
 EMOVEMS    = $8004;
 EMOVHDD    = $8005;
 EMOVEXT    = $8006;
 EFREEXMS   = $8007;
 EFREEEMS   = $8008;
 EFREEHDD   = $8009;

{����⠭�� �訡�� �����饭�� ��ᮬ
 �᫨ �� ����稫��� ������� ���୨� �����}
 FNOTF =   $8102;   {file not found}
 PNOTF =   $8103;   {path not found}
 NOFHNDL = $8104;   {too many open files (no handles available)}
 SHVIOL =  $8105;   {access denied}
 MEMERR =  $8107;   {memory control block destroyed}
 NOMEM =   $8108;   {insufficient memory}
 BIGENV =  $810A;   {environment invalid (usually >32K in length)}
 WRDRV =   $810F;   {invalid drive}

IMPLEMENTATION

uses
 Dos;

const
 CurrentDrv=0;

{ �㭪�� ����᪠ �ணࠬ� �१ �������� ������
 ��� ���������� ������ ������ �� ��६����� �।� COMSPEC}
function DosSwap (Path,Cmdl :string):integer;
var
 RetCode:integer;
 
begin
 RetCode:=pSwap(SwapEnvID, GetEnv('COMSPEC'),'/C'+Path+' '+Cmdl,SwapPath);
                DosSwap:=RetCode;
end;

{ �㭪�� ����᪠ �ணࠬ�  - �� �ॡ�� ������� SwapEnvID � SwapPath
 �᫨ ��� �� �뫨 ���� ��२��樠����஢���, � ��⠭���������� �� 㬮�砭��
 SwapEnvID �  $F, � SwapPath �� ⥪���� ��४���  }
function SwapExec (Path,Cmdl :string):integer;
var
 RetCode :integer;

begin
 RetCode:=pSwap(SwapEnvID, Path, Cmdl, SwapPath);
 SwapExec:=RetCode;
end;

{Initialization}
{ ����� �ந�室�� ��ࢮ��砫쭠� ���樠������ ��६����� SwapEnvID
 � SwapPath. ��� �맮��  �⮩ ��� �㤥� ᣥ���஢�� ��������஬ � ��
 ���㫥 ��� �� �ᯮ���� ����� �����. ���⮬� �� ��᪮�쪮 㢥��稢���
 ��ꥬ ��������� � ����� (����� 10 ���� �������⥫쭮), � �᫨
 �� ��� �������� �⮣�, � ����� �᪫���� ��� ����. ���쪮 ⮣�� ��
 ���뢠�� �� ���樠������ ��� ��६����� }
begin
 SwapEnvID:=XMS or EMS or EXT or HDD;
 GetDir(CurrentDrv,SwapPath);
 SwapPath:=SwapPath+'\';
end.
