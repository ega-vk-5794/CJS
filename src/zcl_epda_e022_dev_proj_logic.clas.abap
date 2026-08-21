class ZCL_EPDA_E022_DEV_PROJ_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  methods OWNER_FINDER_FIELDS
    returning
      value(RT) type STRING_TABLE .
  methods PERMIT_FINDER_FIELDS
    returning
      value(RT) type STRING_TABLE .
  methods LICENSE_FINDER_FIELDS
    returning
      value(RT) type STRING_TABLE .
  methods SET_GROUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_PICK type STRING
      !IT_ALL type STRING_TABLE
      !IT_TECH type STRING_TABLE .
  methods SHOW_ONLY
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IT_ON type STRING_TABLE
      !IT_OFF type STRING_TABLE .

  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
protected section.
private section.

  constants C_PARTNER_OWNER_1 type STRING value 'PARTNER_OWNER_1' ##NO_TEXT.
  constants C_PERMIT_YES type STRING value 'PERMIT_YES' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'PARTNER_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'PARTNER_EMAIL' ##NO_TEXT.
    " constants C_ROLE type STRING value 'STAFF_ROLE' ##NO_TEXT.
*    CONSTANTS c_role TYPE string VALUE 'STAFF_ROLE' ##NO_TEXT.
*    CONSTANTS c_login_bp TYPE string VALUE 'OWNER_BP' ##NO_TEXT.
*    CONSTANTS c_partner_name TYPE string VALUE 'APP_NAME' ##NO_TEXT.
*    CONSTANTS c_partner_id TYPE string VALUE 'APP_ID' ##NO_TEXT.
*    CONSTANTS c_applicanttype TYPE string VALUE 'APP_TYPE' ##NO_TEXT.
*    CONSTANTS c_lang_en TYPE string VALUE 'E' ##NO_TEXT.
*    CONSTANTS c_partner_mobile TYPE string VALUE 'PARTNER_MOBILE_1' ##NO_TEXT.
*    CONSTANTS c_partner_email TYPE string VALUE 'PARTNER_EMAIL_1' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_ROLE type STRING value 'APPLICANT_ROLE' ##NO_TEXT.
  constants C_PERMIT type STRING value 'PERMIT_HELD' ##NO_TEXT.

  methods WRITE_FLAGS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods COMPANY_FIELDS
    returning
      value(RT) type ZIF_RAK_JOURNEY=>TT_STRING .
ENDCLASS.



CLASS ZCL_EPDA_E022_DEV_PROJ_LOGIC IMPLEMENTATION.


  METHOD license_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD owner_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD permit_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD set_group.
*   Every flag in the group, every time. IT_ALL and IT_TECH are positional:
*   the nth option writes the nth technical name. A short IT_TECH would
*   silently stop writing the tail of the group, so it is checked.
    IF lines( it_all ) <> lines( it_tech ).
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |Handler misconfigured: { lines( it_all ) } options |
                                 && |against { lines( it_tech ) } backend fields| ).
      RETURN.
    ENDIF.

    LOOP AT it_all INTO DATA(lv_opt).
      DATA(lv_i) = sy-tabix.
      io_ctx->set_val( iv_name  = it_tech[ lv_i ]
                       iv_value = COND string( WHEN lv_opt = iv_pick
                                               THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD show_only.
*   Both directions. SHOW alone leaves the other panel on screen after its
*   trigger is cleared, still holding values and still posting them.
    LOOP AT it_on INTO DATA(lv_on).
      io_ctx->set_hidden( iv_field = lv_on iv_on = abap_false ).
    ENDLOOP.
    LOOP AT it_off INTO DATA(lv_off).
      io_ctx->set_hidden( iv_field = lv_off iv_on = abap_true ).
      io_ctx->set_val( iv_name = lv_off iv_value = '' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD write_flags.
    DATA(lv_role) = io_ctx->get_val( c_role ).
    io_ctx->set_val( iv_name  = 'PARTNER_OWNER'
                     iv_value = COND #( WHEN lv_role = 'O' THEN 'X' ELSE '' ) ).
    io_ctx->set_val( iv_name  = 'PARTNER_REP'
                     iv_value = COND #( WHEN lv_role = 'R' THEN 'X' ELSE '' ) ).

    DATA(lv_permit) = io_ctx->get_val( c_permit ).
    io_ctx->set_val( iv_name  = 'PERMIT_YES'
                     iv_value = COND #( WHEN lv_permit = 'Y' THEN 'X' ELSE '' ) ).
    io_ctx->set_val( iv_name  = 'PERMIT_NO'
                     iv_value = COND #( WHEN lv_permit = 'N' THEN 'X' ELSE '' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
*  EXPORTING
*    IO_CTX =
*    .

*    show_only(
*      io_ctx = io_ctx
*      it_on  = COND #( WHEN io_ctx->get_val( c_partner_owner_1 ) = `PARTNER_REP_1`
*                       THEN owner_finder_fields( ) )
*      it_off = COND #( WHEN io_ctx->get_val( c_partner_owner_1 ) <> `PARTNER_REP_1`
*                       THEN owner_finder_fields( ) ) ).
*    IF io_ctx->get_val( c_permit_yes ) = `PERMIT_YES`.
*      show_only( io_ctx = io_ctx
*                 it_on  = permit_finder_fields( )
*                 it_off = license_finder_fields( ) ).
*    ELSE.
*      show_only( io_ctx = io_ctx
*                 it_on  = license_finder_fields( )
*                 it_off = permit_finder_fields( ) ).
*    ENDIF.

    IF io_ctx->get_val( c_role ) IS INITIAL.
      IF io_ctx->get_val( 'PARTNER_REP' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_role iv_value = 'R' ).
      ELSEIF io_ctx->get_val( 'PARTNER_OWNER' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_role iv_value = 'O' ).
      ENDIF.
    ENDIF.

    IF io_ctx->get_val( c_permit ) IS INITIAL.
      IF io_ctx->get_val( 'PERMIT_NO' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_permit iv_value = 'N' ).
      ELSEIF io_ctx->get_val( 'PERMIT_YES' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_permit iv_value = 'Y' ).
      ENDIF.
    ENDIF.

    IF io_ctx->get_val( 'PERMIT_LOADED' ) IS NOT INITIAL.
      LOOP AT company_fields( ) INTO DATA(lv_field).
        io_ctx->set_readonly( iv_field = lv_field iv_on = abap_true ).
        io_ctx->set_required( iv_field = lv_field iv_on = abap_false ).
      ENDLOOP.
    ENDIF.



  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
*  EXPORTING
*    IO_CTX =
*  CHANGING
*    CT_KV  =
*    .

    write_flags( io_ctx ).
    DELETE ct_kv WHERE key = 'APPLICANT_ROLE'.
    DELETE ct_kv WHERE key = 'PERMIT_HELD'.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .

    CASE iv_field.
      WHEN c_role.
        write_flags( io_ctx ).
        IF io_ctx->get_val( c_role ) <> 'R'.
          io_ctx->set_val( iv_name = 'OWNER' iv_value = '' ).
        ENDIF.

      WHEN c_permit.
        write_flags( io_ctx ).
        IF io_ctx->get_val( c_permit ) = 'Y'.
          io_ctx->set_val( iv_name = 'REGISTERED_EMIRATES' iv_value = '' ).
          io_ctx->set_val( iv_name = 'TRADE_LICENSE' iv_value = '' ).
        ELSE.
          io_ctx->set_val( iv_name = 'PERMIT_NUMBER' iv_value = '' ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

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

      io_ctx->set_val( iv_name = c_partner_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
      io_ctx->set_val( iv_name = c_partner_email iv_value = CONV #( ls_bp-email_address ) ).


      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

    ENDIF.

    io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).


  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .
    IF iv_field = 'OWNER_SEARCH'.

      CHECK to_upper( iv_field ) = 'OWNER_SEARCH'.

      DATA(lv_eid) = condense( io_ctx->get_val( 'OWNER_SEARCH' ) ).
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
  endmethod.


  METHOD company_fields.
    rt = VALUE #(
      ( `COMPANY_NAME_EN` ) ( `COMPANY_NAME_AR` ) ( `CO_REG_EMIRATES` )
      ( `CO_ADDRESS` )      ( `CO_TRADE_LICENSE` ) ( `CO_MOBILE` )
      ( `CO_TELEPHONE` )    ( `CO_EMAIL` ) ).
*    rt = VALUE #(
*      ( 'COMPANY_NAME_EN' ) ( 'COMPANY_NAME_AR' ) ( 'CO_REG_EMIRATES' )
*      ( 'CO_ADDRESS' )      ( 'CO_TRADE_LICENSE' ) ( 'CO_MOBILE' )
*      ( 'CO_TELEPHONE' )    ( 'CO_EMAIL' ) ).
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE.
*   The base method IS the PAID gate - it refuses a submit while PAYFEE is not
*   'PAID'. A redefinition REPLACES it, so without this call the gate is simply
*   not there for this journey. It must come before any CHECK below: a CHECK that
*   fails exits the method, and anything after it would never run.
*
*   Removed by the abapGit round trip in 3f50a18 - the older SAP copy was staged
*   over the newer git one - which is how an unpaid application could be submitted.
*
*   Self-guarding - PAY_FIELD_STEP returns -1 when the journey has no PAYFEE
*   field, so this is a no-op on a journey with no payment step.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

    CASE iv_step.

      WHEN 0.
        IF io_ctx->get_val( c_role ) IS NOT INITIAL
           AND io_ctx->get_val( 'PARTNER_OWNER' ) IS INITIAL
           AND io_ctx->get_val( 'PARTNER_REP' )   IS INITIAL.
          APPEND VALUE #( type  = 'Error' "field = c_role
                          text  = `Re-select Owner or Representative before continuing.` ) TO rt.
        ENDIF.

        IF io_ctx->get_val( c_permit ) IS NOT INITIAL
           AND io_ctx->get_val( 'PERMIT_YES' ) IS INITIAL
           AND io_ctx->get_val( 'PERMIT_NO' )  IS INITIAL.
          APPEND VALUE #( type  = 'Error' "field = c_permit
                          text  = `Re-select the permit answer before continuing.` ) TO rt.
        ENDIF.

      WHEN 2.
*        DATA(ls_grid) = io_ctx->get_grid_data( c_grid ).
*        IF ls_grid-rows IS INITIAL.
*          APPEND VALUE #( type  = 'Error' "field = c_grid
*                          text  = `Add at least one chemical row.` ) TO rt.
*        ENDIF.

      WHEN OTHERS.
    ENDCASE.
  endmethod.
ENDCLASS.
