*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZMV_JNY_FIELD...................................*
TABLES: ZMV_JNY_FIELD, *ZMV_JNY_FIELD. "view work areas
CONTROLS: TCTRL_ZMV_JNY_FIELD
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZMV_JNY_FIELD. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZMV_JNY_FIELD.
* Table for entries selected to show on screen
DATA: BEGIN OF ZMV_JNY_FIELD_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_FIELD.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_FIELD_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZMV_JNY_FIELD_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_FIELD.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_FIELD_TOTAL.

*.........table declarations:.................................*
TABLES: ZRAK_T_JNY_FLD                 .
TABLES: ZRAK_T_JNY_STEP                .
