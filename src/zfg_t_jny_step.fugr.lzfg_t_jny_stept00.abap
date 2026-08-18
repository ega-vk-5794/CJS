*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZRAK_T_JNY_STEP.................................*
DATA:  BEGIN OF STATUS_ZRAK_T_JNY_STEP               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRAK_T_JNY_STEP               .
CONTROLS: TCTRL_ZRAK_T_JNY_STEP
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZRAK_T_JNY_STEP               .
TABLES: ZRAK_T_JNY_STEP                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
