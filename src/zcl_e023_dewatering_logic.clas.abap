class ZCL_E023_DEWATERING_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_min_search_len TYPE i      VALUE 3.
    CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.
    CONSTANTS c_owner_bp       TYPE string VALUE 'OWNER_BP'.
    CONSTANTS c_step_dewater   TYPE i      VALUE 2.   " 0-based: APPL,COMP,DEWATER
    TYPES: BEGIN OF ty_fan,
             src   TYPE string,
             key_a TYPE string,
             fld_a TYPE string,
             fld_b TYPE string,
           END OF ty_fan.
    TYPES: tt_fan TYPE STANDARD TABLE OF ty_fan WITH EMPTY KEY.
    METHODS fan_map RETURNING VALUE(rt) TYPE tt_fan.

ENDCLASS.



CLASS ZCL_E023_DEWATERING_LOGIC IMPLEMENTATION.


  METHOD fan_map.
    rt = VALUE #(
      ( src = 'APP_ROLE'    key_a = 'REP' fld_a = 'PARTNER_REP_FLG' fld_b = 'PARTNER_OWNER_FLG' )
      ( src = 'PERMIT_MODE' key_a = 'YES' fld_a = 'PERMIT_YES_FLG'  fld_b = 'PERMIT_NO_FLG' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.
    LOOP AT fan_map( ) INTO DATA(ls).
      DATA lv_v TYPE string.
      CLEAR lv_v.
      READ TABLE ct_kv INTO DATA(ls_s) WITH KEY key = ls-src.
      IF sy-subrc = 0. lv_v = to_upper( condense( CONV string( ls_s-value ) ) ). ENDIF.
      LOOP AT ct_kv ASSIGNING FIELD-SYMBOL(<kv>) WHERE key = ls-fld_a OR key = ls-fld_b.
        IF <kv>-key = ls-fld_a.
          <kv>-value = COND string( WHEN lv_v = ls-key_a THEN `X` ELSE `` ).
        ELSE.
          <kv>-value = COND string( WHEN lv_v = ls-key_a THEN `` ELSE `X` ).
        ENDIF.
      ENDLOOP.
      DELETE ct_kv WHERE key = ls-src.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    DATA(lv_f) = to_upper( iv_field ).
    LOOP AT fan_map( ) INTO DATA(ls) WHERE src = lv_f.
      DATA(lv_v) = to_upper( condense( io_ctx->get_val( ls-src ) ) ).
      io_ctx->set_val( iv_name = ls-fld_a iv_value = COND string( WHEN lv_v = ls-key_a THEN `X` ELSE `` ) ).
      io_ctx->set_val( iv_name = ls-fld_b iv_value = COND string( WHEN lv_v = ls-key_a THEN `` ELSE `X` ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   THE BASE CALL IS THE PAID GATE - it refuses a submit while PAYFEE <> 'PAID'.
*   It has to run BEFORE the CHECK below: a failing CHECK exits the method, so a
*   CHECK placed first skips the gate on every step this handler does not own,
*   which is every step where payment is actually decided. RT is extended with
*   VALUE #( BASE rt ... ) further down rather than assigned, so the gate's own
*   messages survive.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

    CHECK iv_step = c_step_dewater.
    " Belt-and-braces: config MIN_VAL/MAX_VAL already gate this, but the
    " legacy journey enforced 1..60 in code, so mirror it.
    DATA(lv_days) = io_ctx->get_val( 'DW_DURATION' ).
    IF lv_days IS NOT INITIAL.
      DATA lv_n TYPE i.
      TRY.
          lv_n = lv_days.
        CATCH cx_sy_conversion_no_number.
          rt = VALUE #( BASE rt ( type = 'Error' text = 'Duration must be a number of days between 1 and 60' ) ).
          RETURN.
      ENDTRY.
      IF lv_n < 1 OR lv_n > 60.
        rt  = VALUE #( BASE rt ( type = 'Error' text = 'Duration must be between 1 and 60 days' ) ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
**    CHECK to_upper( iv_field ) = c_owner_bp.
**    DATA(lv_term) = condense( io_ctx->get_val( c_owner_bp ) ).
**    IF strlen( lv_term ) < c_min_search_len.
**      io_ctx->add_msg( iv_type = 'Warning' iv_text = |Enter at least { c_min_search_len } characters to search| ).
**      RETURN.
**    ENDIF.
**    DATA(lv_idt) = io_ctx->get_val( |{ c_owner_bp }_IDTYPE| ).
**    IF lv_idt IS INITIAL. lv_idt = c_default_idtype. ENDIF.
**    SELECT SINGLE a~partner, a~zzfull_name_eng
**      FROM but000 AS a LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idt
**      WHERE b~idnumber = @lv_term OR a~partner = @lv_term INTO @DATA(ls_bp).
**    IF sy-subrc <> 0.
**      io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
**      RETURN.
**    ENDIF.
**    io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-partner }| ).
**    io_ctx->set_val( iv_name = |{ c_owner_bp }_NAME| iv_value = |{ ls_bp-zzfull_name_eng }| ).

    CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
  EXPORTING
    IO_CTX   = IO_CTX
    IV_FIELD = IV_FIELD
    .

     IF iv_field = 'OWNER_BP'.

      CHECK to_upper( iv_field ) = 'OWNER_BP'.

      DATA(lv_eid) = condense( io_ctx->get_val( 'OWNER_BP' ) ).
      IF lv_eid IS INITIAL.
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Enter Emirates ID to search| ).
        RETURN.
      ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( 'OWNER_SEARCH_IDTYPE' ).
      IF lv_idtype IS INITIAL.
        lv_idtype = 'YFS002'.
      ENDIF.

      DATA: lv_eid_no   TYPE bu_id_number,
            lv_eid_type TYPE bu_id_type.

      lv_eid_no = lv_eid.
      lv_eid_type = lv_idtype.

      DATA ev_partner         TYPE partner.
      DATA ev_id_number       TYPE bu_id_number.
      DATA ev_passport        TYPE bu_id_number.
      DATA ev_name            TYPE bu_name1tx.
      DATA ev_phone           TYPE farp_mobile.
      DATA ev_email           TYPE ad_smtpadr.
      DATA ev_nationality     TYPE natio50.
      DATA ev_nationality_key TYPE bu_natio.
      DATA ev_date_of_birth   TYPE bu_birthdt.
      DATA ev_message         TYPE bapiret2-message.

      CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
        EXPORTING
          iv_type            = lv_eid_type
          iv_idnumber        = lv_eid_no
*         IV_APP             = IV_APP
        IMPORTING
          ev_partner         = ev_partner
          ev_id_number       = ev_id_number
          ev_passport        = ev_passport
          ev_name            = ev_name
          ev_phone           = ev_phone
          ev_email           = ev_email
          ev_nationality     = ev_nationality
          ev_nationality_key = ev_nationality_key
          ev_date_of_birth   = ev_date_of_birth
          ev_message         = ev_message.

      io_ctx->set_val( iv_name = 'OWNER_NAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_PHONE'      iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_EMAIL'       iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_DOB'         iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_NATIONALITY' iv_value = ' ' ).

*

      io_ctx->set_val( iv_name = 'OWNER_SEARCH'  iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = 'OWNER_NAME'        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = 'OWNER_PHONE'      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = 'OWNER_EMAIL'       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = 'OWNER_DOB'         iv_value = |{ ev_date_of_birth DATE = USER }| ).
      io_ctx->set_val( iv_name = 'OWNER_NATIONALITY' iv_value = |{ ev_nationality }| ).

    ELSEIF iv_field = 'PERMIT_NUMBER'.
      DATA(lv_permit) = condense( io_ctx->get_val( 'PERMIT_NUMBER' ) ).

      IF lv_permit IS NOT INITIAL.
        SELECT SINGLE contractname FROM zv_epdapmmast INTO @DATA(lv_contrat) WHERE permitid = @lv_permit.

        IF lv_contrat IS NOT INITIAL.
          io_ctx->set_val( iv_name = 'PERMIT_NUMBER'  iv_value = |{ lv_permit }| ).
          io_ctx->set_val( iv_name = 'PERMIT_LOADED'  iv_value = |{ lv_contrat }| ).
        ELSE.
          io_ctx->set_val( iv_name = 'PERMIT_LOADED' iv_value = ' ' ).
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Enter Valid Permit No to search| ).
        ENDIF.

      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

    CONSTANTS c_login_bp TYPE string VALUE 'LOGIN_BP' ##NO_TEXT.
    CONSTANTS c_owner_bp TYPE string VALUE 'OWNER_BP' ##NO_TEXT.

    CONSTANTS c_partner_name TYPE string VALUE 'APP_NAME' ##NO_TEXT.
    CONSTANTS c_partner_id TYPE string VALUE 'PARTNER_ID' ##NO_TEXT.
    CONSTANTS c_applicanttype TYPE string VALUE 'APPLICANTTYPE' ##NO_TEXT.
    CONSTANTS c_lang_en TYPE string VALUE 'E' ##NO_TEXT.




    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

    DATA: lv_loginbp TYPE bu_partner.

    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner


    IF lv_loginbp IS INITIAL AND sy-sysid <> 'E30'.
      lv_loginbp = '3000000049'.
    ENDIF.

    IF lv_loginbp IS NOT INITIAL.
      NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
        EXPORTING
          iv_bp_id      = lv_loginbp
        IMPORTING
          es_bp_details = DATA(ls_bp) ).

      io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).

      IF sy-langu = c_lang_en.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

      io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-owner_id }| ).

    ENDIF.


    io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
  ENDMETHOD.
ENDCLASS.
