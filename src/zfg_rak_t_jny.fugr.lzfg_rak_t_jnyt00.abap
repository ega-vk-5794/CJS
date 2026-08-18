*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZRAK_T_JNY......................................*
DATA:  BEGIN OF STATUS_ZRAK_T_JNY                    .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRAK_T_JNY                    .
CONTROLS: TCTRL_ZRAK_T_JNY
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZRAK_T_JNY                    .
TABLES: ZRAK_T_JNY                     .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
