{$X+}
program _AAA_;
uses
 TpCrt,
 TpMenu,
 aMsgBox;

const
 mbClrs :MenuColorArray=($70,$7F,$2F,$1F,$2E,$70, $7C,$08);
 ambClrs:MenuColorArray=($47,$4E,$2F,$1F,$2E,$4F, $4C,$08);

begin
  HiddenCursor;
   MessageBox('This program requiredSfM Operation system',
              tOk,tOk,bButton[tOk] or bButton[tCancel] or bButton[tRetry],
              ambClrs,'Startup error..');
   MessageBox('This program requiredSfM Operation system',
              tOk,tOk,bButton[tOk] or bButton[tCancel] or bButton[tAbort],
              mbClrs,'Startup error..');
  NormalCursor;
end.
