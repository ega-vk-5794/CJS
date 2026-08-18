*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZMV_JNY_STEP....................................*
TABLES: ZMV_JNY_STEP, *ZMV_JNY_STEP. "view work areas
CONTROLS: TCTRL_ZMV_JNY_STEP
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZMV_JNY_STEP. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZMV_JNY_STEP.
* Table for entries selected to show on screen
DATA: BEGIN OF ZMV_JNY_STEP_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_STEP.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_STEP_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZMV_JNY_STEP_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_STEP.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_STEP_TOTAL.

*.........table declarations:.................................*
TABLES: ZRAK_T_JNY                     .
TABLES: ZRAK_T_JNY_STEP                .
