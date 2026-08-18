*---------------------------------------------------------------------*
*    program for:   TABLEFRAME_ZFG_T_JNY_STEP
*---------------------------------------------------------------------*
FUNCTION TABLEFRAME_ZFG_T_JNY_STEP     .

  PERFORM TABLEFRAME TABLES X_HEADER X_NAMTAB DBA_SELLIST DPL_SELLIST
                            EXCL_CUA_FUNCT
                     USING  CORR_NUMBER VIEW_ACTION VIEW_NAME.

ENDFUNCTION.
