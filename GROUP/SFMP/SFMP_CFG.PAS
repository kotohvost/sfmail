{$X+,I-}

UNIT SfMp_Cfg;

INTERFACE

uses
 {$IFDEF OS2}
 Use32,
 {$ENDIF}
 SfMp_Var;

procedure ParseConfig;
procedure InternalError(ie:tInternalError; s:string; _halt:boolean);
procedure SayError(s1,s2:string);
procedure LinkEvent(var ev:tEventRec);
procedure SaveEvents;

IMPLEMENTATION

uses
 Dos,
 AEH,
 SfMp_Log,
 tConfig,
 tString_;

const
 MaxCfgWord=18;

type
 tCfgWords=array[1..MaxCfgWord] of longint;
 tCfgTypes=array[1..MaxCfgWord] of ArgType;

const
 CfgWords:tCfgWords=(
   $7E90B1F2  {1 Address},
   $DF01A8BF  {2 Change},
   $4AEA0BA8  {3 FReq},
   $36CD6F2D  {4 Inbound},
   $8BBC139D  {5 NetMail},
   $71A8D9DE  {6 Outbound},
   $729375A5  {7 Post},
   $B1EAE8DF  {8 Direct},
   $B342D8F4  {9 Route-to},
   $A5ECB268  {10 Route-from},
   $746F23F5  {11 DirectFiles},
   $7AADD263  {12 Files-to},
   $41E83F42  {13 Files-from},
   $32C58C58  {14 Send},
   $663C7985  {15 Nodelist},
   $43B5D658  {16 RobotName},
   $8E15566B  {17 Secured_Inbound},
   $92D6430B  {18 FTSCprod_List});

 CfgTypes:tCfgTypes=(
   ptString  {1 Address},
   ptString  {2 Change},
   ptString  {3 FReq},
   ptPath    {4 Inbound},
   ptPath    {5 NetMail},
   ptString  {6 Outbound},
   ptString  {7 Post},
   ptString  {8 Direct},
   ptString  {9 Route-to},
   ptString  {10 Route-from},
   ptString  {11 DirectFiles},
   ptString  {12 Files-to},
   ptString  {13 Files-from},
   ptString  {14 Send},
   ptPath    {15 Nodelist},
   ptString  {16 RobotName},
   ptPath    {17 Secured_Inbound},
   ptString  {18 FTSCprod_List});

var
 CfgCB:tCfgRecord;
 nWord:word;

{$F+}
function GetWord(w:word):longint;
begin
 GetWord:=CfgWords[w];
end;

function GetType(w:word):ArgType;
begin
 GetType:=CfgTypes[w];
end;

procedure SayError(s1,s2:string);
begin
 if Length(s2) <>0 then
  s1:=s1+' `'+s2+#39;
 Log_Write(lfError,s1,lwtBoth);
end;
{$F-}

procedure InternalError(ie:tInternalError; s:string; _halt:boolean);
begin
 case ie of
  ieBadSwitch: s:='Unrecognized switch `'+s+#39;
  ieBadCmdLine: s:='Unrecognized commandline parameter `'+s+#39;
  ieCantOpenCfg: s:='Unable to open config file: '+s;
  ieBadWord: s:='Unknown identifier `'+LastCtlWord+#39;
  ieWrongArgument: s:='Wrong argument for '+LastCtlWord;
  ieBadFlavour: s:='Bad flavour '+s;
  ieNotDefined: s:=s+' not defined';
 end;
 SayError(s,'');
 if _halt then
  halt(800+integer(ie));
end;

procedure SaveEvents;
var
 p:pEventRec;
 Ev:tEventRec;
 f:file;

begin
 Log_Write(lfDebug,'Storing events in '+EvFname,lwtBoth);
 assign(f,EvFname);
 rewrite(f,1);
 BlockWrite(f,EvFhdr,SizeOf(tEventFhdr));
 p:=EvHead;
 while p <>nil do begin
  FillChar(Ev,SizeOf(tEventRec),0);
  Move(p^,Ev,SizeOf(tEventH)+Length(p^.EvStr));
  BlockWrite(f,Ev,SizeOf(tEventRec));
  p:=p^.NextEvent;
 end;
 close(f);
end;

procedure LinkEvent(var ev:tEventRec);
begin
 if EvHead =nil then begin
  GetMem(EvHead,SizeOf(tEventH)+Length(Ev.EvStr));
  EvHead^.NextEvent:=EvHead;
  EvTail:=EvHead;
 end
 else begin
  GetMem(EvTail^.NextEvent,SizeOf(tEventH)+Length(Ev.EvStr));
  EvTail:=EvTail^.NextEvent;
 end;
 Move(ev,EvTail^,SizeOf(tEventH)+Length(Ev.EvStr));
 EvTail^.NextEvent:=nil;
end;

function FlavourName2char(fn:string; ForLo:boolean):char;
 {                                         normal direct crash imm hold
 LO_mode:array[lo_Normal..lo_Hold] of char=('f',  'd',    'c',  'i','h');
 UT_mode:array[lo_Normal..lo_Hold] of char=('o',  'd',    'c',  'i','h');}
begin
 if fn ='normal' then begin
  if ForLo then FlavourName2char:='f'
  else FlavourName2char:='o';
 end
 else
  if fn ='direct' then FlavourName2char:='d'
  else
   if fn ='crash' then FlavourName2char:='c'
   else
    if fn ='imm' then FlavourName2char:='i'
    else
     if fn ='hold' then FlavourName2char:='h'
     else
      InternalError(ieBadFlavour,fn+' at line '+
                    Long2str(CfgCB.CfgLine),true);
end;

procedure AddEvent(ev:tEvent);
var
 Event:tEventRec;

begin
 if RecompileEvents then begin
  SetDefaultAddr(CfgRec^.MyAddress[1]);
  FillChar(Event,SizeOf(tEventRec),0);
  with Event do begin
   EventType:=Ev;
   case Ev of
    evFReq: begin
             { FReq Address file|pwd,file|pwd TimaArray }
             xStr2addr(ExtractWord(1,valString,[' ',^I]),TargetAddr);
             EvStr:=ExtractWord(2,valString,[' ',^I]); {список файлов через `,'}
             Str2timePeriod(ExtractWord(3,valString,[' ',^I]),When);
            end;
    evPost,
    evSend: begin
             { Post Flavour Address file TimeArray }
             { Send Flavour Address file TimeArray }
             FlavourTo:=FlavourName2char(StLoCase(ExtractWord(1,valString,[' ',^I])),ev =evSend);
             xStr2addr(ExtractWord(2,valString,[' ',^I]),TargetAddr);
             EvStr:=ExtractWord(3,valString,[' ',^I]);
             Str2timePeriod(ExtractWord(4,valString,[' ',^I]),When);
            end;
    evChange: begin
               { Change FlavourFrom FlavourTo AddressList TimeArray }
               FlavourFrom:=FlavourName2char(StLoCase(ExtractWord(1,valString,[' ',^I])),true);
               FlavourTo:=FlavourName2char(StLoCase(ExtractWord(2,valString,[' ',^I])),true);
               EvStr:=ExtractWord(3,valString,[' ',^I]);
               Str2timePeriod(ExtractWord(4,valString,[' ',^I]),When);
              end;
   end;
  end;
  LinkEvent(Event);
  Log_Write(lfDebug,'Adding event ['+LastCtlWord+']',lwtBoth);
 end;
end;

procedure AddRule(rr:tRouteRule);
var
 Rule:tRouteRec;
 i:byte;

begin
 { Direct      Flavour        AddressList TimeArray }
 { Route-to    Flavour Target AddressList TimeArray }
 { Route-from  Flavour Target AddressList TimeArray }
 { DirectFiles Flavour        AddressList TimeArray }
 { Files-to    Flavour Target AddressList TimeArray }
 { Files-from  Flavour Target AddressList TimeArray }
 FillChar(Rule,SizeOf(tRouteRec),0);
 SetDefaultAddr(CfgRec^.MyAddress[1]);
 with Rule do begin
  RuleType:=rr;
  RuleFlavour:=FlavourName2char(StLoCase(ExtractWord(1,valString,[' ',^I])),false);
  if rr in [rrRouteTo,rrRouteFrom,rrFilesTo,rrFilesFrom] then begin
   xStr2addr(ExtractWord(2,valString,[' ',^I]),TargetAddr);
   i:=3;
  end
  else
   i:=2;
  RuleStr:=ExtractWord(i,valString,[' ',^I]);
  Str2timeArray(ExtractWord(i+1,valString,[' ',^I]),When);
 end;
 { append new rule to the end of routing-list }
 if RouteHead =nil then begin
  GetMem(RouteHead,SizeOf(tRouteH)+Length(Rule.RuleStr));
  RouteHead^.NextRule:=RouteHead;
  RouteTail:=RouteHead;
 end
 else begin
  GetMem(RouteTail^.NextRule,SizeOf(tRouteH)+Length(Rule.RuleStr));
  RouteTail:=RouteTail^.NextRule;
 end;
 Move(Rule,RouteTail^,SizeOf(tRouteH)+Length(Rule.RuleStr));
 RouteTail^.NextRule:=nil;
end;

procedure AddRobotName;
var
 p:pRobotName;

begin
 if Length(valString) <>0 then begin
  GetMem(p,rnHdrSiz+Length(valString));
  p^.NextRobot:=nil;
  p^.Name:=valString;
  if RobotNameHead <>nil then
   p^.NextRobot:=RobotNameHead;
  RobotNameHead:=p;
 end;
end;

procedure ParseConfig;
begin
 if not ConfigInit(CfgCB,CfgFname) then
  InternalError(ieCantOpenCfg,CfgFname,true);

 Log_Write(lfNormal,'Loading config '+CfgFname,lwtBoth);

 with CfgCB do begin
       QuoteChar:=#39;
     CommentChar:=#59;
  OnOffSwitch[0]:='no';
  OnOffSwitch[1]:='yes';
 end;

 repeat
  if not ConfigNextRead(CfgCB,MaxCfgWord, @GetWord,@GetType,nWord) then
  with CfgCB do begin
   if CfgErrorCode =UnknowCtlWord then
    InternalError(ieBadWord,'',true)
   else
    if CfgErrorCode =ErrorArgument then
     InternalError(ieWrongArgument,'',true)
    else
     ForceDosError(CfgErrorCode,CfgFname,true);
  end;
  if RecompileEvents then with EvFhdr do begin
   GetFtime(CfgCB.CfgHandle,valLong);
   CfgFtime:=valLong;
   EventsId:=EvId;
  end;
  if CfgCB.CfgStatus <>stCfgEOF then with CfgRec^ do begin
   case nWord of
    1: if AllAddress <MaxAddress then begin
        Inc(AllAddress);
        Str2addr(valString,MyAddress[AllAddress]);
       end;
    2: AddEvent(evChange);
    3: AddEvent(evFReq);
    4: Inbound:=valString;
    5: NetMail:=valString;
    6: begin
        Outbound:=valString;
        if Outbound[Length(Outbound)] ='\' then
         Dec(byte(Outbound[0]));
       end;
    7: AddEvent(evPost);
    8: AddRule(rrDirect);
    9: AddRule(rrRouteTo);
    10: AddRule(rrRouteFrom);
    11: AddRule(rrDirectFiles);
    12: AddRule(rrFilesTo);
    13: AddRule(rrFilesFrom);
    14: AddEvent(evSend);
    15: Nodelist:=valString;
    16: AddRobotName;
    17: SecInbound:=valString;
    18: FTSCprod:=valString;     { FTS Product Ids (from FastEcho packet) }
   end;
  end;
 until CfgCB.CfgStatus=stCfgEOF;
 ConfigClose(CfgCB);
 if RecompileEvents then
  SaveEvents;
end;

end.
