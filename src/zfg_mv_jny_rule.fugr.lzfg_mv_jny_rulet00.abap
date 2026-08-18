*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZMV_JNY_RULE....................................*
TABLES: ZMV_JNY_RULE, *ZMV_JNY_RULE. "view work areas
CONTROLS: TCTRL_ZMV_JNY_RULE
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZMV_JNY_RULE. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZMV_JNY_RULE.
* Table for entries selected to show on screen
DATA: BEGIN OF ZMV_JNY_RULE_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_RULE.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_RULE_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZMV_JNY_RULE_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZMV_JNY_RULE.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZMV_JNY_RULE_TOTAL.

*.........table declarations:.................................*
TABLES: ZRAK_T_JNY                     .
TABLES: ZRAK_T_JNY_RULE                .
