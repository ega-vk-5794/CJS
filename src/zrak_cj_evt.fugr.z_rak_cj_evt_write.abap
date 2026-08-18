FUNCTION z_rak_cj_evt_write.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_EVT) TYPE  ZRAK_TT_CJ_EVT
*"----------------------------------------------------------------------

  IF it_evt IS INITIAL.
    RETURN.
  ENDIF.

  TRY.
      INSERT zrak_t_cj_evt FROM TABLE @it_evt ACCEPTING DUPLICATE KEYS.

      IF sy-subrc = 0.
        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.

    CATCH cx_root.
      ROLLBACK WORK.
  ENDTRY.

ENDFUNCTION.
