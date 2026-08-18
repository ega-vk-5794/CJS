*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZMV_JNY_OPT.....................................*
TABLES: ZMV_JNY_OPT, *ZMV_JNY_OPT. "view work areas
CONTROLS: TCTRL_ZMV_JNY_OPT
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZMV_JNY_OPT. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZMV_JNY_OPT.
* Table for entries selected to show on screen
DATA: BEGIN OF ZMV_JNY_OPT_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_OPT.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_OPT_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZMV_JNY_OPT_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_OPT.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_OPT_TOTAL.

*.........table declarations:.................................*
TABLES: ZRAK_T_JNY_FLD                 .
TABLES: ZRAK_T_JNY_OPT                 .
