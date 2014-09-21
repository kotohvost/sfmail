{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$I OPLUS.INC}
{$ENDIF}

{*********************************************************}
{*                  TPCLONE.PAS 1.00                     *}
{*                by TurboPower Software                 *}
{*********************************************************}

unit TpClone;
  {-Clone typed constants into a program}

interface

uses
  Dos,
  Tstring_,
  TpMemChk;

type
  ClonePack =
    record
      CloneF : File;
      CloneT : LongInt;
    end;
  DateUpdateType = (UpdateNone, UpdateDate, UpdateAll);
const
  DateUpdate : DateUpdateType = UpdateDate;
var
  CloneError : Word;

procedure OpenForCloning(FName : string; var CP : ClonePack);
  {-Open file for cloning}

function FindDefaultsEnd(var CP : ClonePack; var ID; IdSize : Word; Skip : LongInt) : LongInt;
  {-Find the ID in the clone file, searching from the end backward}
  {Offset returned is the start of the IDString}

function FindDefaultsStart(var CP : ClonePack; var ID; IdSize : Word; Skip : LongInt) : LongInt;
  {-Find the ID in the clone file, searching from the start forward}
  {Offset returned is the start of the IDString}

function InitForCloning(FName : string; var CP : ClonePack; var ID; IdSize : Word) : LongInt;
  {-Open file and find ID. Uses FindDefaultsEnd}

procedure LoadDefaults(var CP : ClonePack; FileOfs : LongInt; var Defaults; Bytes : Word);
  {-Seek to position FileOfs and read defaults there}

procedure StoreDefaults(var CP : ClonePack; FileOfs : LongInt; var Defaults; Bytes : Word);
  {-Seek to position FileOfs and store defaults there}

procedure CloseForCloning(var CP : ClonePack);
  {-Close the current clone file}

  {=================================================================}

implementation

  procedure OpenForCloning(FName : string; var CP : ClonePack);
    {-Open file for cloning}
  begin
    {Open file}
    Assign(CP.CloneF, FName);
    Reset(CP.CloneF, 1);
    CloneError := IoResult;
    if CloneError <> 0 then
      Exit;

    {Save the original date/time}
    GetFTime(CP.CloneF, CP.CloneT);
  end;

  function FindDefaultsEnd(var CP : ClonePack; var ID; IdSize : Word; Skip : LongInt) : LongInt;
    {-Find the ID string in the clone file}
  label
    ExitPoint;
  type
    SearchBuffer = array[0..4095] of Char;
  var
    BufPtr : ^SearchBuffer;
    BufSize : Word;
    BufLessId : Word;
    BufPos : Word;
    BytesRead : Word;
    FilePtr : LongInt;
  begin
    FindDefaultsEnd := 0;

    {Allocate buffer space}
    if not GetMemCheck(BufPtr, SizeOf(SearchBuffer)) then begin
      CloneError := 203;
      Exit;
    end;

    {Initialize for search}
    BufSize := SizeOf(SearchBuffer);
    BufLessId := BufSize-IdSize;

    {Initialize file position}
    FilePtr := FileSize(CP.CloneF)-Skip-BufSize;
    if FilePtr < 0 then
      FilePtr := 0;
    Seek(CP.CloneF, FilePtr);

    {Fill the buffer}
    BlockRead(CP.CloneF, BufPtr^, BufSize, BytesRead);
    CloneError := IoResult;
    if CloneError <> 0 then
      goto ExitPoint;

    {Search the buffer}
    BufPos := Search(BufPtr^, BytesRead, ID, IdSize);

    {Loop until Id found or beginning of file reached}
    while (BufPos = $FFFF) and (FilePtr > 0) do begin
      {Move the front end of the buffer to the tail of the buffer}
      Move(BufPtr^, BufPtr^[BufLessId], IdSize);

      {Back up the file pointer}
      Dec(FilePtr, BufLessId);
      if FilePtr < 0 then
        FilePtr := 0;
      Seek(CP.CloneF, FilePtr);

      {Fill the front part of the buffer}
      BlockRead(CP.CloneF, BufPtr^, BufLessId, BytesRead);
      CloneError := IoResult;
      if CloneError <> 0 then
        goto ExitPoint;

      if BytesRead < BufLessId then
        {Move things forward if necessary}
        Move(BufPtr^[BufLessId], BufPtr^[BytesRead], IdSize);

      if BytesRead > 0 then begin
        {Adjust BytesRead to indicate the actual number of bytes in the buffer}
        Inc(BytesRead, IdSize);
        {Search the buffer for Id}
        BufPos := Search(BufPtr^, BytesRead, ID, IdSize);
      end;
    end;

    if BufPos <> $FFFF then
      {Calculate the actual position in the file}
      FindDefaultsEnd := FilePtr+BufPos;

ExitPoint:
    {Deallocate buffer space}
    FreeMemCheck(BufPtr, SizeOf(SearchBuffer));
  end;

  function FindDefaultsStart(var CP : ClonePack; var ID; IdSize : Word; Skip : LongInt) : LongInt;
    {-Find the ID string in the clone file}
  label
    ExitPoint;
  type
    SearchBuffer = array[0..4095] of Char;
  var
    BufPtr : ^SearchBuffer;
    BufSize : Word;
    BufPos : Word;
    BytesRead : Word;
    FilePtr : LongInt;
  begin
    FindDefaultsStart := 0;

    {Allocate buffer space}
    if not GetMemCheck(BufPtr, SizeOf(SearchBuffer)) then begin
      CloneError := 203;
      Exit;
    end;

    {Initialize for search}
    BufSize := SizeOf(SearchBuffer);
    Seek(CP.CloneF, Skip);

    {Read the first bufferful}
    BlockRead(CP.CloneF, BufPtr^, BufSize, BytesRead);
    CloneError := IoResult;
    if CloneError <> 0 then
      goto ExitPoint;
    FilePtr := BytesRead;

    {Search the buffer}
    BufPos := Search(BufPtr^, BytesRead, ID, IdSize);

    {Loop until ID found or end of file reached}
    while (BufPos = $FFFF) and (BytesRead >= IdSize) do begin
      {Move the tail end of the buffer to the front of the buffer}
      Move(BufPtr^[BytesRead-IdSize], BufPtr^, IdSize);
      {Read the next bufferful}
      BlockRead(CP.CloneF, BufPtr^[IdSize], BufSize-IdSize, BytesRead);
      if BytesRead > 0 then begin
        Inc(FilePtr, BytesRead);
        Inc(BytesRead, IdSize);
        BufPos := Search(BufPtr^, BytesRead, ID, IdSize);
      end;
    end;

    if BufPos <> $FFFF then
      FindDefaultsStart := FilePtr-BytesRead+BufPos;

ExitPoint:
    {Deallocate buffer space}
    FreeMemCheck(BufPtr, SizeOf(SearchBuffer));
  end;

  function InitForCloning(FName : string; var CP : ClonePack; var ID; IdSize : Word) : LongInt;
    {-Open file and find ID}
  begin
    OpenForCloning(FName, CP);
    if CloneError <> 0 then
      InitForCloning := 0
    else
      InitForCloning := FindDefaultsEnd(CP, ID, IdSize, 0);
  end;

  procedure LoadDefaults(var CP : ClonePack; FileOfs : LongInt; var Defaults; Bytes : Word);
    {-Seek to position FileOfs and read defaults there}
  var
    BytesRead : Word;
  begin
    Seek(CP.CloneF, FileOfs);
    CloneError := IoResult;
    if CloneError = 0 then begin
      {Read defaults}
      BlockRead(CP.CloneF, Defaults, Bytes, BytesRead);
      CloneError := IoResult;
      if (CloneError = 0) and (BytesRead <> Bytes) then
        CloneError := 100;
    end;
  end;

  procedure StoreDefaults(var CP : ClonePack; FileOfs : LongInt; var Defaults; Bytes : Word);
    {-Seek to position FileOfs and store defaults there}
  var
    BytesWritten : Word;
  begin
    Seek(CP.CloneF, FileOfs);
    CloneError := IoResult;
    if CloneError = 0 then begin
      {Write defaults}
      BlockWrite(CP.CloneF, Defaults, Bytes, BytesWritten);
      CloneError := IoResult;
      if (CloneError = 0) and (BytesWritten <> Bytes) then
        CloneError := 101;
    end;
  end;

  procedure CloseForCloning(var CP : ClonePack);
    {-Close the current clone file}
  var
    Status : Word;
    DT : DateTime;
  begin
    case DateUpdate of
      UpdateNone : {Set original date/time}
        SetFTime(CP.CloneF, CP.CloneT);
      UpdateDate : {Change the date but not the time}
        begin
          UnpackTime(CP.CloneT, DT);
          with DT do
            GetDate(Year, Month, Day, Status);
          PackTime(DT, CP.CloneT);
          SetFTime(CP.CloneF, CP.CloneT);
        end;
      UpdateAll :  {Let new date and time take effect}
        ;
    end;

    Close(CP.CloneF);
    CloneError := IoResult;
  end;

end.
