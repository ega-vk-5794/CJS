*---------------------------------------------------------------------*
*    program for:   TABLEFRAME_ZCJ_Z2UI5_APPS
*---------------------------------------------------------------------*
FUNCTION TABLEFRAME_ZCJ_Z2UI5_APPS     .

  PERFORM TABLEFRAME TABLES X_HEADER X_NAMTAB DBA_SELLIST DPL_SELLIST
                            EXCL_CUA_FUNCT
                     USING  CORR_NUMBER VIEW_ACTION VIEW_NAME.

ENDFUNCTION.
