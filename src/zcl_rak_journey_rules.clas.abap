CLASS zcl_rak_journey_rules DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
*   Visibility, requiredness, read-only and validation - rule-driven and
*   handler-override alike.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

    METHODS eval_rules.
    METHODS is_hidden   IMPORTING is_field TYPE zif_rak_journey=>ty_field RETURNING VALUE(rv) TYPE abap_bool.
    METHODS is_required IMPORTING is_field TYPE zif_rak_journey=>ty_field RETURNING VALUE(rv) TYPE abap_bool.
    METHODS is_readonly IMPORTING is_field TYPE zif_rak_journey=>ty_field RETURNING VALUE(rv) TYPE abap_bool.
    METHODS set_prop  IMPORTING iv_field TYPE string iv_prop TYPE string iv_on TYPE abap_bool.
    METHODS prop_ovr  IMPORTING iv_field TYPE string iv_prop TYPE string
                      EXPORTING ev_found TYPE abap_bool ev_on TYPE abap_bool.
    METHODS validate_step IMPORTING iv_step TYPE i RETURNING VALUE(rt_msg) TYPE zif_rak_journey=>tt_msg.
    METHODS validate_all  RETURNING VALUE(rt_msg) TYPE zif_rak_journey=>tt_msg.
    METHODS missing_required IMPORTING iv_step   TYPE i
                             RETURNING VALUE(rt) TYPE zif_rak_cjs_types=>tt_miss.

  PRIVATE SECTION.
    DATA mo_e TYPE REF TO zcl_rak_journey_engine.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_RULES IMPLEMENTATION.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD eval_rules.
    CLEAR: mo_e->mt_rulehide, mo_e->mt_ruleshow, mo_e->mt_rulereq, mo_e->mt_rulero, mo_e->mt_ruleedit.
    LOOP AT mo_e->ms_config-rules INTO DATA(ls_rule).
      DATA(lv_src) = mo_e->val_get( ls_rule-src_field ).
      DATA(lv_hit) = abap_false.
      CASE ls_rule-src_op.
        WHEN 'EQ'.
          lv_hit = xsdbool( lv_src = ls_rule-src_value ).
        WHEN 'NE'.
          lv_hit = xsdbool( lv_src <> ls_rule-src_value ).
        WHEN 'INITIAL'.
          lv_hit = xsdbool( lv_src IS INITIAL ).
        WHEN 'NOTINITIAL'.
          lv_hit = xsdbool( lv_src IS NOT INITIAL ).
      ENDCASE.
      IF lv_hit = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_tgt) = to_upper( ls_rule-tgt_field ).
      CASE ls_rule-action.
        WHEN 'SHOW'.
          APPEND lv_tgt TO mo_e->mt_ruleshow.
        WHEN 'HIDE'.
          APPEND lv_tgt TO mo_e->mt_rulehide.
        WHEN 'REQUIRE'.
          APPEND lv_tgt TO mo_e->mt_rulereq.
        WHEN 'OPTIONAL'.
          DELETE mo_e->mt_rulereq WHERE table_line = lv_tgt.
        WHEN 'READONLY'.
          APPEND lv_tgt TO mo_e->mt_rulero.
          DELETE mo_e->mt_ruleedit WHERE table_line = lv_tgt.
        WHEN 'EDITABLE'.
          APPEND lv_tgt TO mo_e->mt_ruleedit.
          DELETE mo_e->mt_rulero WHERE table_line = lv_tgt.
        WHEN 'SET'.
          mo_e->val_set( iv_name = ls_rule-tgt_field iv_value = ls_rule-tgt_value ).
        WHEN 'CLEAR'.
          mo_e->val_set( iv_name = ls_rule-tgt_field iv_value = `` ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_hidden.
    DATA(lv_n) = to_upper( is_field-name ).
*   A handler that spoke about this field wins. It ran deliberately, for a case
*   the rule grammar could not express, so it outranks both the rules and the
*   configured flag. clear_props( ) hands control back.
    prop_ovr( EXPORTING iv_field = lv_n
                        iv_prop  = 'HIDDEN'
              IMPORTING ev_found = DATA(lv_hf)
                        ev_on    = DATA(lv_hn) ).
    IF lv_hf = abap_true.
      rv = lv_hn.
      RETURN.
    ENDIF.
    IF line_exists( mo_e->mt_rulehide[ table_line = lv_n ] ).
      rv = abap_true.
      RETURN.
    ENDIF.
    IF is_field-hidden = abap_true AND NOT line_exists( mo_e->mt_ruleshow[ table_line = lv_n ] ).
      rv = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_readonly.
*   EDITABLE wins over the configured flag, READONLY wins over everything. That
*   ordering is what lets a field be authored locked and released by a rule, as
*   well as the other way round. A handler outranks all three.
    DATA(lv_n) = to_upper( is_field-name ).
    prop_ovr( EXPORTING iv_field = lv_n
                        iv_prop  = 'READONLY'
              IMPORTING ev_found = DATA(lv_of)
                        ev_on    = DATA(lv_on) ).
    IF lv_of = abap_true.
      rv = lv_on.
      RETURN.
    ENDIF.
    IF line_exists( mo_e->mt_rulero[ table_line = lv_n ] ).
      rv = abap_true.
      RETURN.
    ENDIF.
    IF line_exists( mo_e->mt_ruleedit[ table_line = lv_n ] ).
      RETURN.
    ENDIF.
    rv = is_field-readonly.
  ENDMETHOD.


  METHOD is_required.
    prop_ovr( EXPORTING iv_field = is_field-name
                        iv_prop  = 'REQUIRED'
              IMPORTING ev_found = DATA(lv_rf)
                        ev_on    = DATA(lv_rn) ).
    IF lv_rf = abap_true.
      rv = lv_rn.
      RETURN.
    ENDIF.
    rv = xsdbool( is_field-validation-required = abap_true
              OR line_exists( mo_e->mt_rulereq[ table_line = to_upper( is_field-name ) ] ) ).
  ENDMETHOD.


  METHOD missing_required.
*   The ONLY place "is this required thing still outstanding" is decided.
*   validate_step( ) consumes it for its messages and REQPANEL renders from it, so
*   the checklist can never say complete while Submit refuses.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_ms) INDEX iv_step + 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT ls_ms-fields INTO DATA(ls_mf) WHERE readonly = abap_false.
      IF is_hidden( ls_mf ) = abap_true
         OR ls_mf-type = 'PAYFEE' OR ls_mf-type = 'REQPANEL'.
        CONTINUE.
      ENDIF.
      IF is_required( ls_mf ) = abap_false.
        CONTINUE.
      ENDIF.

      IF ls_mf-has_attach = abap_true OR ls_mf-type = 'UPLOAD'.
*       A document already filed in the backend satisfies the requirement. Without
*       this, resuming a draft is a dead end: mo_e->mo_render->render_attach( ) counts the filed
*       document and HIDES the uploader, then validation demands an attachment.
        DATA(lv_has_att) = xsdbool( line_exists( mo_e->mt_attach[ field = to_upper( ls_mf-name ) ] ) ).
        IF lv_has_att = abap_false AND mo_e->mo_logic IS BOUND.
          TRY.
              lv_has_att = xsdbool(
                mo_e->mo_logic->get_attachments( io_ctx = mo_e iv_field = ls_mf-name ) IS NOT INITIAL ).
            CATCH cx_root.
              CLEAR lv_has_att.
          ENDTRY.
        ENDIF.
        IF lv_has_att = abap_false.
          APPEND VALUE #( name = ls_mf-name label = ls_mf-label kind = 'ATT' ) TO rt.
        ENDIF.
      ENDIF.

      IF ls_mf-type = 'DISPLAY' OR ls_mf-type = 'READONLY' OR ls_mf-type = 'TABLE'
         OR ls_mf-type = 'UPLOAD' OR ls_mf-type = 'STATUS' OR ls_mf-type = 'OBJNUM'
         OR ls_mf-type = 'PROGRESS' OR ls_mf-type = 'LINK' OR ls_mf-type = 'EDITABLE_TABLE'.
        CONTINUE.
      ENDIF.

      IF mo_e->val_get( ls_mf-name ) IS INITIAL.
        APPEND VALUE #( name  = ls_mf-name
                        label = ls_mf-label
                        kind  = 'VAL'
                        msg   = ls_mf-validation-msg ) TO rt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD prop_ovr.
    CLEAR: ev_found, ev_on.
    READ TABLE mo_e->mt_ovr INTO DATA(ls_o)
      WITH KEY field = to_upper( condense( iv_field ) ) prop = iv_prop.
    IF sy-subrc = 0.
      ev_found = abap_true.
      ev_on    = ls_o-on.
    ENDIF.
  ENDMETHOD.


  METHOD set_prop.
    DATA(lv_f) = to_upper( condense( iv_field ) ).
    IF lv_f IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE mo_e->mt_ovr ASSIGNING FIELD-SYMBOL(<o>)
      WITH KEY field = lv_f prop = iv_prop.
    IF sy-subrc = 0.
      <o>-on = iv_on.
    ELSE.
      APPEND VALUE #( field = lv_f prop = iv_prop on = iv_on ) TO mo_e->mt_ovr.
    ENDIF.
  ENDMETHOD.


  METHOD validate_all.
    DATA lv_i TYPE i.
    DO lines( mo_e->ms_config-steps ) TIMES.
      APPEND LINES OF validate_step( lv_i ) TO rt_msg.
      lv_i = lv_i + 1.
    ENDDO.
  ENDMETHOD.


  METHOD validate_step.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX iv_step + 1.

    LOOP AT missing_required( iv_step ) INTO DATA(ls_miss).
      zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-val_fail
                           iv_step_no = mo_e->mv_step
                           iv_result  = 'BLOCK'
                           iv_detail  = ls_miss-name ).

      DATA(lv_mtxt) = COND string(
        WHEN ls_miss-kind = 'ATT'
        THEN zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-att_required
                                iv_default = `&1: attachment is required`
                                iv_v1      = ls_miss-label )
        WHEN ls_miss-msg IS NOT INITIAL  THEN ls_miss-msg
        ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-required
                                iv_default = `&1 is required`
                                iv_v1      = ls_miss-label ) ).
      APPEND VALUE #( type = 'Error' text = lv_mtxt ) TO rt_msg.
      mo_e->set_field_state( iv_name = ls_miss-name iv_state = 'Error' iv_text = lv_mtxt ).
    ENDLOOP.

    LOOP AT ls_step-fields INTO DATA(ls_f) WHERE readonly = abap_false.
      IF is_hidden( ls_f ) = abap_true.
        CONTINUE.
      ENDIF.

      IF ls_f-type = 'PAYFEE' OR ls_f-type = 'REQPANEL'.
        CONTINUE.
      ENDIF.

      IF ls_f-type = 'DISPLAY' OR ls_f-type = 'READONLY' OR ls_f-type = 'TABLE'
         OR ls_f-type = 'UPLOAD' OR ls_f-type = 'STATUS' OR ls_f-type = 'OBJNUM'
         OR ls_f-type = 'PROGRESS' OR ls_f-type = 'LINK' OR ls_f-type = 'EDITABLE_TABLE'.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = mo_e->val_get( ls_f-name ).
      DATA(lv_v)   = ls_f-validation.

*     Required is handled above. An empty value has nothing left to check.
      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_v-min_len > 0 AND strlen( lv_val ) < lv_v-min_len.
        DATA(lv_nmin) = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-too_short
                                           iv_default = `&1 must be at least &2 characters`
                                           iv_v1      = ls_f-label
                                           iv_v2      = |{ lv_v-min_len }| ).
        APPEND VALUE #( type = 'Error' text = lv_nmin ) TO rt_msg.
        mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_nmin ).
        CONTINUE.
      ENDIF.
      IF lv_v-max_len > 0 AND strlen( lv_val ) > lv_v-max_len.
        DATA(lv_nmax) = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-too_long
                                           iv_default = `&1 must be at most &2 characters`
                                           iv_v1      = ls_f-label
                                           iv_v2      = |{ lv_v-max_len }| ).
        APPEND VALUE #( type = 'Error' text = lv_nmax ) TO rt_msg.
        mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_nmax ).
        CONTINUE.
      ENDIF.
*     Numeric range: min_val / max_val were declared and loaded but never
*     enforced on submit - a NUMBER/CURRENCY field accepted any value. Bounds
*     for SLIDER/STEPPER/RATING are enforced by their controls, so only the
*     free-entry numeric types are checked here. DATE range is intentionally
*     not handled yet (bind format must be confirmed first).
      IF ( ls_f-type = 'NUMBER' OR ls_f-type = 'CURRENCY' )
         AND ( lv_v-min_val IS NOT INITIAL OR lv_v-max_val IS NOT INITIAL ).
        TRY.
            DATA(lv_num) = CONV decfloat34( lv_val ).
            IF lv_v-min_val IS NOT INITIAL AND lv_num < CONV decfloat34( lv_v-min_val ).
              DATA(lv_vmin) = COND string( WHEN lv_v-msg IS NOT INITIAL THEN lv_v-msg
                ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-num_min
                                        iv_default = `&1 must be at least &2`
                                        iv_v1      = ls_f-label
                                        iv_v2      = |{ lv_v-min_val }| ) ).
              APPEND VALUE #( type = 'Error' text = lv_vmin ) TO rt_msg.
              mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_vmin ).
              CONTINUE.
            ENDIF.
            IF lv_v-max_val IS NOT INITIAL AND lv_num > CONV decfloat34( lv_v-max_val ).
              DATA(lv_vmax) = COND string( WHEN lv_v-msg IS NOT INITIAL THEN lv_v-msg
                ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-num_max
                                        iv_default = `&1 must be at most &2`
                                        iv_v1      = ls_f-label
                                        iv_v2      = |{ lv_v-max_val }| ) ).
              APPEND VALUE #( type = 'Error' text = lv_vmax ) TO rt_msg.
              mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_vmax ).
              CONTINUE.
            ENDIF.
          CATCH cx_sy_conversion_no_number.
            DATA(lv_vnan) = COND string( WHEN lv_v-msg IS NOT INITIAL THEN lv_v-msg
              ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-not_number
                                      iv_default = `&1 must be a valid number`
                                      iv_v1      = ls_f-label ) ).
            APPEND VALUE #( type = 'Error' text = lv_vnan ) TO rt_msg.
            mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_vnan ).
            CONTINUE.
        ENDTRY.
      ENDIF.
*     DATE range: compare on a normalized yyyymmdd. zcl_rak_journey_util=>to_dats( ) accepts ISO,
*     yyyymmdd and day-first locale forms and returns empty for anything it
*     cannot parse unambiguously, so an unexpected/month-first format is SKIPPED
*     rather than wrongly rejected. This reads the model value only - it does not
*     change what is posted to the backend.
      IF ls_f-type = 'DATE'
         AND ( lv_v-min_val IS NOT INITIAL OR lv_v-max_val IS NOT INITIAL ).
        DATA(lv_dv) = zcl_rak_journey_util=>to_dats( lv_val ).
        IF lv_dv IS NOT INITIAL.
          DATA(lv_dmin) = zcl_rak_journey_util=>to_dats( lv_v-min_val ).
          DATA(lv_dmax) = zcl_rak_journey_util=>to_dats( lv_v-max_val ).
          IF lv_dmin IS NOT INITIAL AND lv_dv < lv_dmin.
            DATA(lv_dminm) = COND string( WHEN lv_v-msg IS NOT INITIAL THEN lv_v-msg
              ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-date_min
                                      iv_default = `&1 must be on or after &2`
                                      iv_v1      = ls_f-label
                                      iv_v2      = |{ lv_v-min_val }| ) ).
            APPEND VALUE #( type = 'Error' text = lv_dminm ) TO rt_msg.
            mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_dminm ).
            CONTINUE.
          ENDIF.
          IF lv_dmax IS NOT INITIAL AND lv_dv > lv_dmax.
            DATA(lv_dmaxm) = COND string( WHEN lv_v-msg IS NOT INITIAL THEN lv_v-msg
              ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-date_max
                                      iv_default = `&1 must be on or before &2`
                                      iv_v1      = ls_f-label
                                      iv_v2      = |{ lv_v-max_val }| ) ).
            APPEND VALUE #( type = 'Error' text = lv_dmaxm ) TO rt_msg.
            mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_dmaxm ).
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.
      IF lv_v-regex IS NOT INITIAL.
        TRY.
            IF cl_abap_matcher=>matches( pattern = lv_v-regex text = lv_val ) = abap_false.
              DATA(lv_rxm) = COND string( WHEN lv_v-msg IS NOT INITIAL THEN lv_v-msg
                ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-bad_format
                                        iv_default = `&1 has an invalid format`
                                        iv_v1      = ls_f-label ) ).
              APPEND VALUE #( type = 'Error' text = lv_rxm ) TO rt_msg.
              mo_e->set_field_state( iv_name = ls_f-name iv_state = 'Error' iv_text = lv_rxm ).
            ENDIF.
          CATCH cx_root.
        ENDTRY.
      ENDIF.
    ENDLOOP.

    IF mo_e->mo_logic IS BOUND.
      TRY.
          APPEND LINES OF mo_e->mo_logic->on_custom_validate( io_ctx = mo_e iv_step = iv_step ) TO rt_msg.
        CATCH cx_root INTO DATA(lx_val).
          APPEND VALUE #( type = 'Error'
            text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-val_error
                                      iv_default = `Validation error: &1`
                                      iv_v1      = lx_val->get_text( ) ) ) TO rt_msg.
      ENDTRY.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
