(*
                  Created by Anton`s Dialog Engine compiler
*)
const
 { DIALOG: SENDFILE OPTIONS }
 { GROUP: Method }
 rb_Message         =$01;  {message}
 rb_Bink_Dlo        =$02;  {bink .DLO}
 rb_Filebox         =$04;  {filebox}

 { GROUP: Attribute }
 cb_Direct          =$01;  {direct}
 cb_Kill_File_Sent  =$02;  {kill-file-sent}
 cb_Hold            =$04;  {hold}

 { GROUP: o }
 pb_Ok              =$01;  {Ok}
 pb_All             =$02;  {All}
 pb_Cancel          =$04;  {Cancel}
