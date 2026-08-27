class ZCL_E026_TREE_REMOVAL_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_FIELDS
    redefinition .
protected section.
private section.

  constants C_MIN_SEARCH_LEN type I value 3 ##NO_TEXT.
  constants C_DEFAULT_IDTYPE type STRING value 'YFS002' ##NO_TEXT.
  constants C_TYPE_INDIVIDUAL type STRING value '1' ##NO_TEXT.
  constants C_TYPE_COMPANY type STRING value '2' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'PARTNER_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'APP_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'APP_EMAIL' ##NO_TEXT.
  constants C_ROLE type STRING value 'APP_ROLE' ##NO_TEXT.
  constants C_OWNER_BP type STRING value 'OWNER' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_E026_TREE_REMOVAL_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    CHECK to_upper( iv_name ) = 'TREES'.

*    " Column order matches the export's LIST_SEQUENCE on the TREES MTABLE's
*    " children: TREE_TYPE_1 (1), NO_OF_TREE_1 (2), ACTION_1 (3).
    rs_data-columns = VALUE #( ( `Type of Trees` ) ( `No.of Trees` ) ( `Action Required` ) ).

*    " REVIEW (NOTE 3): unlike a read-only picker, TREES is user-editable
*    " (MTABLE_CADD "Add Tree" / row MTABLE_DELETE). Returning the working
*    " set already accumulated in context rather than a fresh backend SELECT.
*    " Row key (first cell) is a synthetic sequence number so MTABLE_DELETE_1
*    " can address a specific row.
    DATA(lt_rows) = io_ctx->get_val( 'TREES' ).   " REVIEW: exact retrieval API for a working MTABLE's current rows is unconfirmed
    " ... deserialize lt_rows into the tree list here ...

    LOOP AT VALUE string_table( ) INTO DATA(lv_dummy).   " placeholder loop — replace with real row source
      APPEND VALUE #( ( `` ) ( `` ) ( `` ) ) TO rs_data-rows.
    ENDLOOP.
  ENDMETHOD.


METHOD zif_rak_journey_logic~on_before_fields.
  super->zif_rak_journey_logic~on_before_fields(
    EXPORTING
      io_ctx    = io_ctx
    CHANGING
      ct_fields = ct_fields ).
  IF io_ctx->get_case( ) IS NOT INITIAL.
    RETURN.
  ENDIF.

ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

*" No PAY_*/PAYFEE fields exist (payment is a server-side redirect —
* " see load report NOTE 8), but the strip is safe to keep regardless.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

*    " PARTNER_TYPE was synthesized as one CJS field but the backend expects
*    " two separate flags (GS_DATA-PARTNER_OWNER / GS_DATA-PARTNER_REP per
*    " the export's TECHNICAL_NAME on PARTNER_OWNER_1/PARTNER_REP_1). Map it
*    " back here rather than seeding two competing SEGMENTED rows.
    READ TABLE ct_kv WITH KEY key = 'PARTNER_TYPE' INTO DATA(ls_type).
    IF sy-subrc = 0.
      ct_kv = VALUE #( BASE ct_kv
        ( key = 'GS_DATA-PARTNER_OWNER' value = COND #( WHEN ls_type-value = 'PARTNER_OWNER_1' THEN 'X' ELSE '' ) )
        ( key = 'GS_DATA-PARTNER_REP'   value = COND #( WHEN ls_type-value = 'PARTNER_REP_1'   THEN 'X' ELSE '' ) ) ).
      DELETE ct_kv WHERE key = 'PARTNER_TYPE'.
    ENDIF.

*    " UI-only scratch keys with no backend meaning.
    DELETE ct_kv WHERE key = 'FOUND_FLAG'.
    DELETE ct_kv WHERE key = 'DECLARE'.

*    " REVIEW: substitute {APPLICANT_NAME} in the DECLARE field's rendered
*    " text with the actual applicant/owner name once that source field is
*    " confirmed — placeholder left as-is here since it is UI text, not
*    " posted data.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate - it refuses a submit while PAYFEE is not
*   'PAID'. A redefinition REPLACES it, so without this call the gate is simply
*   not there for this journey. It must come before any CHECK below: a CHECK that
*   fails exits the method, and anything after it would never run.
*
*   Self-guarding - PAY_FIELD_STEP returns -1 when the journey has no PAYFEE
*   field, so this is a no-op on a journey with no payment step.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*    CHECK iv_step = 1.   " zero-based: step 2 "NOC Details" in the wizard

*    DATA(lv_trees) = io_ctx->get_val( 'TREES' ).
*    IF lv_trees IS INITIAL.
*      rt = VALUE #( ( type = 'Error' text = 'Add at least one tree before continuing.' ) ).
*    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
**    io_ctx->set_val( iv_name = 'PARTNER_TYPE' iv_value = 'OWNER' ).
**     DATA(user_data) = io_ctx->get_param( iv_name = 'PARAM1' ).
**
**    zcl_ega_cj_utility=>get_bp(
**      EXPORTING
**        qv_key  = user_data
**      IMPORTING
**        loginbp = DATA(loginbp)
**        rolebp  = DATA(rolebp)
**        role    = DATA(role)
**    ).
**
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000124165' ).
**
**     IF loginbp-bp_name_en IS NOT INITIAL.
**      io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
**    ELSE.
**      io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( ls_login_bp-bp_name_ar ) ).
**    ENDIF.
**
**    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
**    io_ctx->set_val( iv_name = 'APP_MOBILE' iv_value = CONV #( ls_login_bp-mobile_number ) ).
**    io_ctx->set_val( iv_name = 'APP_EMAIL' iv_value = CONV #( ls_login_bp-email_address ) ).
**
**
**    io_ctx->set_val( iv_name = 'PERMIT_NUMBER' iv_value = 'E21DI04468' ).

*    io_ctx->set_val( iv_name = 'PARTNER_TYPE' iv_value = 'OWNER' ).
*
*    DATA(lr_noc_api) = NEW zcl_epda_consult_noc_handl_api( ).
*    DATA lv_login_bp TYPE  bu_partner VALUE '3000000043'.
*
*    lr_noc_api->get_bp_details(
*      EXPORTING
*        iv_bp_id      = lv_login_bp
*      IMPORTING
*        es_bp_details = DATA(ls_login_bp) ).
*
*    IF ls_login_bp-bp_name_en IS NOT INITIAL.
*      io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*    ELSE.
*      io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( ls_login_bp-bp_name_ar ) ).
*    ENDIF.
*
*    io_ctx->set_val( iv_name = 'OWNER' iv_value = CONV #( ls_login_bp-emirates_id ) ).
*    io_ctx->set_val( iv_name = 'APP_MOBILE' iv_value = CONV #( ls_login_bp-mobile_number ) ).
*    io_ctx->set_val( iv_name = 'APP_EMAIL' iv_value = CONV #( ls_login_bp-email_address ) ).
*    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( ls_login_bp-partner ) ).
*
*
*    io_ctx->set_val( iv_name = 'PERMIT_NUMBER' iv_value = 'E21DI04468' ).
*
*
*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000000043' ).


*     io_ctx->set_val( iv_name = 'PARTNER_TYPE' iv_value = 'OWNER' ).

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

      io_ctx->set_val( iv_name = 'OWNER' iv_value = ' ' ).


    ENDIF.

  endmethod.


  METHOD zif_rak_journey_logic~on_search.
    CHECK to_upper( iv_field ) = 'OWNER'.

    DATA(lv_eid) = condense( io_ctx->get_val( 'OWNER' ) ).
    IF strlen( lv_eid ) < c_min_search_len.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = |Enter at least { c_min_search_len } characters to search| ).
      RETURN.
    ENDIF.

*    " The engine generates OWNER_IDTYPE and OWNER_NAME for you.
    DATA(lv_idtype) = io_ctx->get_val( 'OWNER_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      lv_idtype = c_default_idtype.
    ENDIF.

*    SELECT SINGLE a~partner, a~zzfull_name_eng, a~NAME1_TEXT,  b~idnumber
**              "   a~zzcompany_name, a~zztrade_license, a~zzmobile, a~zzemail
*
*      FROM but000 AS a
*      LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idtype
*      WHERE b~idnumber = @lv_term "OR a~partner = @lv_term    "commented by rabindra
*      INTO @DATA(ls_bp).
*
*    IF sy-subrc <> 0.
*      io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
*      io_ctx->set_val( iv_name = 'FOUND_FLAG' iv_value = '' ).
*      RETURN.
*    ENDIF.
*
**    " Contact fields shown regardless of individual/company (rules R4/R5).
*    io_ctx->set_val( iv_name = 'OWNER' iv_value = |{ ls_bp-partner }| ).
**    io_ctx->set_val( iv_name = 'EXECMOBILE' iv_value = |{ ls_bp-zzmobile }| ).   " REVIEW: field names on BUT000 are placeholders
**    io_ctx->set_val( iv_name = 'EXECEMAIL' iv_value = |{ ls_bp-zzemail }| ).    " REVIEW: field names on BUT000 are placeholders
*
*    " Individual-branch fields (rules R6/R7 show these when OWNERTYPE = 1).
*    io_ctx->set_val( iv_name = 'EXECFULLNAME' iv_value = |{ ls_bp-zzfull_name_eng }| ).
*    io_ctx->set_val( iv_name = 'EXECID' iv_value = |{ ls_bp-idnumber }| ).
*
*    " Company-branch fields (rules R8/R9 show these when OWNERTYPE = 2).
**    io_ctx->set_val( iv_name = 'EXECCOMPANY' iv_value = |{ ls_bp-zzcompany_name }| ).   " REVIEW: field names are placeholders
**    io_ctx->set_val( iv_name = 'EXECLICENSE' iv_value = |{ ls_bp-zztrade_license }| ).  " REVIEW: field names are placeholders
*
*    " Flip the bridge flag so rules R3-R5 can reveal OWNERTYPE/contact fields.
*    io_ctx->set_val( iv_name = 'FOUND_FLAG' iv_value = 'X' ).

    DATA: lv_eid_no   TYPE bu_id_number,
          lv_eid_type TYPE bu_id_type.

    IF to_upper( iv_field ) = c_owner_bp.
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

      io_ctx->set_val( iv_name = 'EXECFULLNAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_PHONE'      iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXECMOBILE'       iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_DOB'         iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_NATIONALITY' iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'EXEC_TYPE' iv_value = ' ' ).

*
      io_ctx->set_val( iv_name = 'FOUND_FLAG' iv_value = 'X' ).
      io_ctx->set_val( iv_name = 'OWNER'  iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = 'EXECFULLNAME'        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = 'EXECMOBILE'      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = 'EXECEMAIL'       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = 'EXEC_DOB'         iv_value = |{ ev_date_of_birth DATE = USER }| ).
      io_ctx->set_val( iv_name = 'EXEC_NATIONALITY' iv_value = |{ ev_nationality }| ).
    ELSE.
      io_ctx->set_val( iv_name = 'FOUND_FLAG' iv_value = ' ' ).
    ENDIF.


  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .
    DATA(lv_step) = io_ctx->get_step( ).
    CASE iv_field.
      WHEN 'TREES.TREE_TYPE'.

        DATA(lt_values) = VALUE dd07v_tab( ).

        CALL FUNCTION 'DD_DOMVALUES_GET'
          EXPORTING
            domname        = 'ZDO_EPDA_TREE_TYPE'
            text           = 'X'
            langu          = Sy-langu
*           BYPASS_BUFFER  = ' '
*         IMPORTING
*           RC             =
          TABLES
            dd07v_tab      = lt_values
          EXCEPTIONS
            wrong_textflag = 1
            OTHERS         = 2.
        IF sy-subrc <> 0.
* Implement suitable error handling here
        ENDIF.

        IF sy-subrc = 0.
          " Build a simplified result table with VALUE and FOR
          rt = VALUE #(
                FOR ls_value IN lt_values
                 ( key = ls_value-domvalue_l text =  ls_value-ddtext )
                   ).
        ENDIF.
      WHEN 'TREES.ACTION'.

        CALL FUNCTION 'DD_DOMVALUES_GET'
          EXPORTING
            domname        = 'ZDO_EPDA_ACTION'
            text           = 'X'
            langu          = Sy-langu
*           BYPASS_BUFFER  = ' '
*         IMPORTING
*           RC             =
          TABLES
            dd07v_tab      = lt_values
          EXCEPTIONS
            wrong_textflag = 1
            OTHERS         = 2.
        IF sy-subrc <> 0.
* Implement suitable error handling here
        ENDIF.

        IF sy-subrc = 0.
          " Build a simplified result table with VALUE and FOR
          rt = VALUE #(
                FOR ls_value IN lt_values
                 ( key = ls_value-domvalue_l text =  ls_value-ddtext )
                   ).
        ENDIF.
*    	WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
