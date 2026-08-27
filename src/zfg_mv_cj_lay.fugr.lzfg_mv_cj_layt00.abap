*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZMV_CJ_LAY......................................*
TABLES: ZMV_CJ_LAY, *ZMV_CJ_LAY. "view work areas
CONTROLS: TCTRL_ZMV_CJ_LAY
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZMV_CJ_LAY. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZMV_CJ_LAY.
* Table for entries selected to show on screen
DATA: BEGIN OF ZMV_CJ_LAY_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZMV_CJ_LAY.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_CJ_LAY_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZMV_CJ_LAY_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZMV_CJ_LAY.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_CJ_LAY_TOTAL.

*.........table declarations:.................................*
TABLES: ZRAK_CJ_LAY                    .
TABLES: ZRAK_T_JNY_STEP                .
