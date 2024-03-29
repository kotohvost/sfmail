{$I-,X+}
UNIT SubstMan;

INTERFACE

uses
 Config;

procedure MatchSubstFtime;
{-�᫨ �p��� 䠩�� SubstListName ���������� -- ��p���뢠��}
function SubstNodeEntry(A:tAddress; nLn:byte):boolean;
{-�饬 � ᯨ᪥ ���p���� �� 㧫� A � ����ᨬ �� � NodeEntry}

IMPLEMENTATION

uses
 Dos,
 WriteLog,
 CRC_All,
 a002xs,
 MsgXs,
 aTime,
 EmStruct,
 Tstring_,
 SM_Cpl;

(*
 ������������Ŀ
 �SubstListPtr�
 ��������������
   �
   �
�����������������������������������������������������������������������������Ŀ
� ItemHeader   �FieldType�FieldSize�FieldData�:::�FieldType�FieldSize�FieldData�
��������������������������������������������������������������������������������
      �LinkNext�
      ��������ͼ
   �����������
�����������������������������������������������������������������������������Ŀ
� ItemHeader   �FieldType�FieldSize�FieldData�:::�FieldType�FieldSize�FieldData�
��������������������������������������������������������������������������������
      �LinkNext�
      ��������ͼ
   ��   ...
�����������������������������������������������������������������������������Ŀ
� ItemHeader   �FieldType�FieldSize�FieldData�:::�FieldType�FieldSize�FieldData�
��������������������������������������������������������������������������������
      �LinkNext�
      ��������ͼ
            ���
*)

procedure MatchSubstFtime;
{-�᫨ �p��� 䠩�� SubstListName ���������� -- ��p���뢠��}
var
 f:file;
 T:longint;

begin
 if length(pCfgRec^.SubstList)=0 then exit;
 assign(f,pCfgRec^.SubstList);
 reset(f,1);
 GetFtime(f,T);
 close(f);
 if IOResult<>0 then {clear};

 if T <>SubstListFtime then begin           {��ᮢ������ �� ��⠬}
   LogWrite(wmSubstTimeWarn,'',ld_All);
   LoadSubstList;
   WaitMsg;
 end;
end;

function SubstNodeEntry(A:tAddress; nLn:byte):boolean;
{-�饬 � ᯨ᪥ ���p���� �� 㧫� A � ����ᨬ �� � NodeEntry}
var
 Al:longInt;
 p:pSiHeader;
 s:string;
 w:word;
 hLn:byte;

begin
 SubstNodeEntry:=false;
 if SubstListPtr =nil then exit;     {ᯨ᮪ ����p������}

 p:=SubstListPtr;

 repeat
  if compWordStruct(p^.siAddr,A,SizeOf(tAddress))=Equal then
   with NodeEntry do begin
   SubstNodeEntry:=true;
   Address:=A;
   NumLns:=p^.siLines;
   w:=0;
   hLn:=0;  { Assume Main Line }
   NoHydra:=false;  { �� 㬮�砭�� ���p� ����祭� }

   while w <p^.siSize do with p^ do begin
    case TsiFieldType(siDat^[w]) of
     siHidden: begin
         Inc(hLn); {:=siDat^[w+2];} { Next Line description }
         Inc(w,3);
        end;
     siHydra: begin
         if hLn =nLn then
           NoHydra:=true;    { ����� �� �㤥� ���p� }
         Inc(w,3);
        end;
     siTime: begin         { �p��� p����� }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
           Move(siDat^[succ(w)],OH_Time,succ(SizeOf(tTimePeriod)*siDat^[succ(w)]));
         Inc(w,(SizeOf(tTimePeriod)*siDat^[succ(w)])+2);
        end;
     siFReq: begin         { �p��� �p���� }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
            Move(siDat^[succ(w)],FR_Time,succ(SizeOf(tTimePeriod)*siDat^[succ(w)]));
         Inc(w,(SizeOf(tTimePeriod)*siDat^[succ(w)])+2);
        end;
     siDial: begin         { Dial Preffix }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
            Move(siDat^[succ(w)],Dial[0],81);
         Inc(w,2+siDat^[succ(w)]);
        end;
     siPhone: begin        { ����䮭 }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
            Move(siDat^[succ(w)],Telephone[0],41);
         Inc(w,2+siDat^[succ(w)]);
        end;
     siZMode: begin        { ZMode }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
             ZMode:=tZMode(siDat^[w+2]);
         Inc(w,3);
        end;
     siTries: begin        { Tries }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
           Max_Tries:=siDat^[w+2];
         Inc(w,3);
        end;
     siWait: begin         { Wait CD }
         if hLn =nLn then  { �᫨ �᪮��� ����� }
            Wait:=siDat^[w+2];
         Inc(w,3);
        end;
     siFlags: begin
         if hLn =nLn then begin
           Move(siDat^[w+2],Al,SizeOf(longint));
           Capability:=Capability or Al;
         end;
         Inc(w,2+siDat^[succ(w)]);
        end;
     siMinBaud: begin
         Move(siDat^[w+2],Al,SizeOf(longint));
         if (Al and LongPrefix) =0 then
          { minbaud_in }
          MinBaud_In:=Al
         else
          { minbaud_out }
           if hLn =nLn then
              MinBaud_Out:=Al and (not LongPrefix);
         Inc(w,2+siDat^[succ(w)]);
        end;
     siSessLimit: begin
         Move(siDat^[w+2],Al,SizeOf(longint));
         if (Al and LongPrefix) =0 then
          { sesslimit_in }
          SessLimitIn:=Al
         else
          { sesslimit_out }
           if hLn =nLn then
            SessLimitOut:=Al and (not LongPrefix);
         Inc(w,2+siDat^[succ(w)]);
        end;
     siScript: begin
         if hLn =nLn then
            Move(siDat^[succ(w)],Script[0],255);
         Inc(w,2+siDat^[succ(w)]);
        end;
    else begin
          LogWrite(0,'���p������ ID ���� ('+long2str(siDat^[w])+
                   ' at '+long2str(w)+')',ld_All);
          Inc(w,2+siDat^[succ(w)]);
          {Inc(w);}
         end;
    end;
    if hLn >nLn then w:=p^.siSize;
   end; {*WHILE*}

   if OH_Time.nTPer <>0 then
     Capability:=Capability and (not NodeFlag[CM]);
   exit;
  end; {*IF Al=siAddr*}

  p:=p^.LinkNext;
 until p =nil;
end;

end.
