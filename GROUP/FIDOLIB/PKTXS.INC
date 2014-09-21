const
  peOk      = 0;
  peRead    = 1;
  peWrite   = 2;
  peOpen    = 3;
  peCorrupt = 4;
  peClose   = 5;
  peArcMail = 6;

Type
 tPktHeader =record     {заголовок пакета}
  OrigNode,             {.$0}
  DestNode,             {02}
  Year,                 {04 дата создания: год}
  Month,                {06 месяц}
  Day,                  {08 число}
  Hour,                 {0A час}
  Minute,               {0C минута}
  Second,               {0E секунда}
  Baud,                 {10 ???}
  PktType,              {12 тип пакета: #2#0 (2+)}
  OrigNet,              {14 }
  DestNet  :word;       {16 }

  PCodeLo,                      {18 Product code (low-order)}
  PRevMajor:byte;               {19 Major version}
  Password:array[1..8] of char; {1A..21 Packet password (not ASCIIZ)}
  QMOrigZone,                   {22 Originating zone (QMail)}
  QMDestZone,                   {24 Destination zone (QMail)}
  AuxNet,                       {26 Auxillary net (unused)}
  CWValidate:word;              {28 CapWord validation}
  PCodeHi,                      {2A Product code (high-order)}
  PRevMinor:byte;               {2B Minor version}
  CWCapWord,                    {2C Capabilities}
  OrigZone,                     {2E Originating zone (FSC-39)}
  DestZone,                     {30 Destination zone (FSC-39)}
  OrigPoint,                    {32 Originating point (FSC-39)}
  DestPoint:word;               {34 Destination point (FSC-39)}
  LongData:longint;             {36..39 Product dependent information}
  {Всего - $39 (57) байт}
 end;
