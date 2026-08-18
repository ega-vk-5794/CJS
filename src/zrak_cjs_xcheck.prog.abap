REPORT zrak_cjs_xcheck.

PARAMETERS p_jny TYPE zrak_t_jny-journey_id OBLIGATORY.
PARAMETERS p_all AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  DATA lt_run TYPE STANDARD TABLE OF zrak_t_jny-journey_id WITH EMPTY KEY.

  IF p_all = abap_true.
    SELECT journey_id FROM zrak_t_jny INTO TABLE @lt_run ORDER BY journey_id.
  ELSE.
    APPEND p_jny TO lt_run.
  ENDIF.

  DATA lv_e TYPE i.
  DATA lv_w TYPE i.

  LOOP AT lt_run INTO DATA(lv_jny).
    DATA(lt_msg) = zcl_rak_cjs_xcheck=>check( lv_jny ).

    WRITE: / lv_jny COLOR COL_HEADING.
    LOOP AT lt_msg INTO DATA(ls_msg).
      CASE ls_msg-sev.
        WHEN 'E'. lv_e = lv_e + 1. FORMAT COLOR COL_NEGATIVE.
        WHEN 'W'. lv_w = lv_w + 1. FORMAT COLOR COL_TOTAL.
        WHEN OTHERS.                FORMAT COLOR COL_POSITIVE.
      ENDCASE.
      WRITE: /4 ls_msg-sev,
              6 ls_msg-rule,
             11 ls_msg-step,
             24 ls_msg-text.
      FORMAT COLOR OFF.
    ENDLOOP.
    SKIP.
  ENDLOOP.

  WRITE: / |{ lv_e } blocker(s), { lv_w } risk(s) across { lines( lt_run ) } journey(s).|.
