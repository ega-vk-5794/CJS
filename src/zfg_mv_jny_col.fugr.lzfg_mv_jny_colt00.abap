*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZMV_JNY_COL.....................................*
TABLES: ZMV_JNY_COL, *ZMV_JNY_COL. "view work areas
CONTROLS: TCTRL_ZMV_JNY_COL
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZMV_JNY_COL. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZMV_JNY_COL.
* Table for entries selected to show on screen
DATA: BEGIN OF ZMV_JNY_COL_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_COL.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_COL_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZMV_JNY_COL_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_COL.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_COL_TOTAL.

*.........table declarations:.................................*
TABLES: ZRAK_T_JNY_COL                 .
TABLES: ZRAK_T_JNY_FLD                 .
