
UNIT SwapUnit;

INTERFACE
 function DosSwap(Path,Cmdl:string):integer;
 function SwapExec(Path,Cmdl:string):integer;
 
var
 pSwap    :function(SwapEnvID:byte; Path,Cmdl,SwapPath:string):integer;
 SwapEnvID:byte;
 SwapPath :string;
 
{константы для определения куда разрешать свопится.
Объеденяются с помощью оператора OR}
const
 XMS  = $01;
 EMS  = $02;
 EXT  = $04;
 HDD  = $08;

{константы ошибок запуска Swap}
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

{константы ошибок возвращенные досом
 если не получилось запустит дочерний процесс}
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

{ Функция запуска программ через командный процессор
 имя командного процессора берется из переменной среды COMSPEC}
function DosSwap (Path,Cmdl :string):integer;
var
 RetCode:integer;
 
begin
 RetCode:=pSwap(SwapEnvID, GetEnv('COMSPEC'),'/C'+Path+' '+Cmdl,SwapPath);
                DosSwap:=RetCode;
end;

{ Функция запуска программ  - не требует задания SwapEnvID и SwapPath
 Если они не были вами переинициализированы, то устанавливаются по умолчанию
 SwapEnvID в  $F, а SwapPath на текущую директорию  }
function SwapExec (Path,Cmdl :string):integer;
var
 RetCode :integer;

begin
 RetCode:=pSwap(SwapEnvID, Path, Cmdl, SwapPath);
 SwapExec:=RetCode;
end;

{Initialization}
{ Здесь происходит первоначальная инициализация переменных SwapEnvID
 и SwapPath. Код вызова  этой части будет сгенерирован компилятором в любом
 модуле где вы используете данный модуль. Поэтому это несколько увеличивает
 объем занимаемый в памяти (около 10 байт дополнительно), и если
 вы хотите избежать этого, то можете исключить эту часть. Только тогда не
 забывайте про инициализацию этих переменных }
begin
 SwapEnvID:=XMS or EMS or EXT or HDD;
 GetDir(CurrentDrv,SwapPath);
 SwapPath:=SwapPath+'\';
end.
