class ZCL_E025_BEEKEEPING_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
protected section.
private section.

  constants C_MIN_SEARCH_LEN type I value 3 ##NO_TEXT.
  constants C_DEFAULT_IDTYPE type STRING value 'YFS002' ##NO_TEXT.
  constants C_OWNER_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  " The applicant's own partner goes to LOGIN_BP, the same field every other
  " journey uses. It used to say 'OWNER_BP', which is the OWNER SEARCH INPUT on
  " this journey (see ON_SEARCH) - so ON_INIT filled the search box with the
  " applicant's partner number, the line further down blanked it again, and the
  " applicant BP reached neither the model nor the backend.  CJSMIG-703.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'APP_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'APP_EMAIL' ##NO_TEXT.
  constants C_ROLE type STRING value 'APP_ROLE' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_E025_BEEKEEPING_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_before_post.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.
    " Re-derive the single flag pair and drop the UI-only driver.
    DATA lv_v TYPE string.
    READ TABLE ct_kv INTO DATA(ls_src) WITH KEY key = 'APP_ROLE'.
    IF sy-subrc = 0. lv_v = to_upper( condense( CONV string( ls_src-value ) ) ). ENDIF.
    LOOP AT ct_kv ASSIGNING FIELD-SYMBOL(<kv>)
         WHERE key = 'PARTNER_REP_FLG' OR key = 'PARTNER_OWNER_FLG'.
      IF <kv>-key = 'PARTNER_REP_FLG'.
        <kv>-value = COND string( WHEN lv_v = 'REP' THEN `X` ELSE `` ).
      ELSE.
        <kv>-value = COND string( WHEN lv_v = 'REP' THEN `` ELSE `X` ).
      ENDIF.
    ENDLOOP.
    DELETE ct_kv WHERE key = 'APP_ROLE'.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CHECK to_upper( iv_field ) = 'APP_ROLE'.
    DATA(lv_v) = to_upper( condense( io_ctx->get_val( 'APP_ROLE' ) ) ).
    io_ctx->set_val( iv_name = 'PARTNER_REP_FLG'   iv_value = COND string( WHEN lv_v = 'REP' THEN `X` ELSE `` ) ).
    io_ctx->set_val( iv_name = 'PARTNER_OWNER_FLG' iv_value = COND string( WHEN lv_v = 'REP' THEN `` ELSE `X` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*    CHECK to_upper( iv_field ) = c_owner_bp.
*    DATA(lv_term) = condense( io_ctx->get_val( c_owner_bp ) ).
*    IF strlen( lv_term ) < c_min_search_len.
*      io_ctx->add_msg( iv_type = 'Warning' iv_text = |Enter at least { c_min_search_len } characters to search| ).
*      RETURN.
*    ENDIF.
*    DATA(lv_idt) = io_ctx->get_val( |{ c_owner_bp }_IDTYPE| ).
*    IF lv_idt IS INITIAL. lv_idt = c_default_idtype. ENDIF.
*    SELECT SINGLE a~partner, a~zzfull_name_eng
*      FROM but000 AS a LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idt
*      WHERE b~idnumber = @lv_term OR a~partner = @lv_term INTO @DATA(ls_bp).
*    IF sy-subrc <> 0.
*      io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
*      RETURN.
*    ENDIF.
*    io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-partner }| ).
*    io_ctx->set_val( iv_name = |{ c_owner_bp }_NAME| iv_value = |{ ls_bp-zzfull_name_eng }| ).
    IF to_upper( iv_field ) = c_owner_bp.

      CHECK to_upper( iv_field ) = c_owner_bp.

      DATA(lv_eid) = condense( io_ctx->get_val( c_owner_bp ) ).
      IF lv_eid IS INITIAL.
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Enter Emirates ID to search| ).
        RETURN.
      ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( 'OWNER_BP_IDTYPE' ).
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

      io_ctx->set_val( iv_name = 'EXEC_NAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_PHONE'      iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_EMAIL'       iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_DOB'         iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_NATIONALITY' iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_TYPE' iv_value = ' ' ).

*
      io_ctx->set_val( iv_name = 'EXEC_TYPE' iv_value = lv_idtype ).
      io_ctx->set_val( iv_name = 'OWNER_BP'  iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = 'EXEC_NAME'        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = 'EXEC_PHONE'      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = 'EXEC_EMAIL'       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = 'EXEC_DOB'         iv_value = |{ ev_date_of_birth DATE = USER }| ).
      io_ctx->set_val( iv_name = 'EXEC_NATIONALITY' iv_value = |{ ev_nationality }| ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .

    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

    DATA: lv_loginbp TYPE bu_partner.

    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

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

      io_ctx->set_val( iv_name = c_partner_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
      io_ctx->set_val( iv_name = c_partner_email iv_value = CONV #( ls_bp-email_address ) ).


      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

      " leave the owner search box empty - it is the citizen's to fill in
      io_ctx->set_val( iv_name = c_owner_bp iv_value = ' ' ).

    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
*  EXPORTING
*    IO_CTX =
*    .
    IF io_ctx->get_val( c_role ) IS INITIAL.
      IF io_ctx->get_val( 'PARTNER_REP' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_role iv_value = 'REP' ).
      ELSEIF io_ctx->get_val( 'PARTNER_OWNER' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_role iv_value = 'OWNER' ).
      ENDIF.
    ENDIF.
  endmethod.
ENDCLASS.
