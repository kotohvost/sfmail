{$I-}

PROGRAM SfM_QueW;

{$R SfQW}

uses
 {Objects,}
 WinDos,
 WinTypes,
 WinProcs,
 oWindows,
 oDialogs,
 {---}
 {Dos2win,}
 _SfM_Que;
 {tStringW,}
 {Cfg,}
 {SfM_API,}
 {ReadCfg,}
 {UnixTime;}

type
 tSFQApp=object(tApplication)
  constructor Init;
  destructor Done; virtual;
  procedure InitMainWindow; virtual;
 end;

(*** SFQApp methods ***)
constructor tSFQApp.Init;
begin
 tApplication.Init(AppName);
end;

destructor tSFQApp.Done;
begin
 tApplication.Done;
end;

procedure tSFQApp.InitMainWindow;
begin
 MainWindow:=New(pMainWin,Init);
end;

var
 SFQApp:tSFQApp;

begin
 SFQApp.Init;
 SFQApp.Run;
 SFQApp.Done;
end.
