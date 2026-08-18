REPORT zrak_cj_txt_seed.

*&---------------------------------------------------------------------*
*& Fills ZRAK_T_CJ_TXT from ZCL_RAK_TEXT=>CATALOGUE so a functional
*& consultant opens SM30 to fifty editable rows instead of an empty
*& table and a list of numbers to type by hand.
*&
*& Idempotent. Rows that already exist are left exactly as they are, so
*& running it again after a new text is added to the catalogue tops up
*& the missing rows and never overwrites wording somebody has corrected.
*&---------------------------------------------------------------------*

PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.

START-OF-SELECTION.

  DATA lt_ins TYPE STANDARD TABLE OF zrak_t_cj_txt WITH EMPTY KEY.

  SELECT msgno FROM zrak_t_cj_txt INTO TABLE @DATA(lt_have).

  LOOP AT zcl_rak_text=>catalogue( ) INTO DATA(ls_cat).
    IF line_exists( lt_have[ table_line = ls_cat-msgno ] ).
      CONTINUE.
    ENDIF.
    APPEND VALUE zrak_t_cj_txt( msgno   = ls_cat-msgno
                                text_en = ls_cat-en
                                text_ar = ls_cat-ar ) TO lt_ins.
  ENDLOOP.

  cl_demo_output=>write_text( |Catalogue : { lines( zcl_rak_text=>catalogue( ) ) }| ).
  cl_demo_output=>write_text( |Already in table : { lines( lt_have ) }| ).
  cl_demo_output=>write_text( |To insert : { lines( lt_ins ) }| ).

  IF lt_ins IS INITIAL.
    cl_demo_output=>write_text( |Nothing to do.| ).
    cl_demo_output=>display( ).
    RETURN.
  ENDIF.

  LOOP AT lt_ins INTO DATA(ls_show).
    cl_demo_output=>write_text( |{ ls_show-msgno }  { ls_show-text_en }| ).
  ENDLOOP.

  IF p_test = abap_true.
    cl_demo_output=>write_text( |Test mode - nothing written. Untick to commit.| ).
    cl_demo_output=>display( ).
    RETURN.
  ENDIF.

  INSERT zrak_t_cj_txt FROM TABLE @lt_ins.

  IF sy-subrc = 0.
    COMMIT WORK AND WAIT.
    zcl_rak_text=>reset( ).
    cl_demo_output=>write_text( |{ lines( lt_ins ) } row(s) inserted. Edit them in SM30.| ).
  ELSE.
    ROLLBACK WORK.
    cl_demo_output=>write_text( |Insert failed - nothing committed.| ).
  ENDIF.

  cl_demo_output=>display( ).
