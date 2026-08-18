class ZCL_E017_NOC_EXP_CHEM_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
protected section.
private section.

  constants C_ROLE type STRING value 'APPLICANT_ROLE' ##NO_TEXT.
  constants C_PERMIT type STRING value 'PERMIT_HELD' ##NO_TEXT.
  constants C_GRID type STRING value 'CHEMICALS_DETAILS' ##NO_TEXT.
  constants C_OPEN_POPUP type STRING value 'CHEMICAL_POP' ##NO_TEXT.
  constants C_ADD_CHEMICAL type STRING value 'ADD_CHEMICAL' ##NO_TEXT.

  methods WRITE_FLAGS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods COMPANY_FIELDS
    returning
      value(RT) type ZIF_RAK_JOURNEY=>TT_STRING .
ENDCLASS.



CLASS ZCL_E017_NOC_EXP_CHEM_LOGIC IMPLEMENTATION.


  METHOD company_fields.
    rt = VALUE #(
      ( `COMPANY_NAME_EN` ) ( `COMPANY_NAME_AR` ) ( `CO_REG_EMIRATES` )
      ( `CO_ADDRESS` )      ( `CO_TRADE_LICENSE` ) ( `CO_MOBILE` )
      ( `CO_TELEPHONE` )    ( `CO_EMAIL` ) ).
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

    write_flags( io_ctx ).
    DELETE ct_kv WHERE key = 'APPLICANT_ROLE'.
    DELETE ct_kv WHERE key = 'PERMIT_HELD'.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

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


  METHOD zif_rak_journey_logic~on_custom_validate.

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
        DATA(ls_grid) = io_ctx->get_grid_data( c_grid ).
        IF ls_grid-rows IS INITIAL.
          APPEND VALUE #( type  = 'Error' "field = c_grid
                          text  = `Add at least one chemical row.` ) TO rt.
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx = io_ctx ).

    DATA(lv_user) = io_ctx->get_param( iv_name = 'USERDATA' ).

    zcl_ega_cj_utility=>get_bp(
      EXPORTING qv_key  = lv_user
      IMPORTING loginbp = DATA(lv_loginbp)
                rolebp  = DATA(lv_rolebp)
                role    = DATA(lv_role) ).

    IF lv_loginbp IS INITIAL.
      lv_loginbp = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
      lv_rolebp  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
      lv_role    = CAST zcl_rak_journey_engine( io_ctx )->mv_role.

*     "Login BP
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
    ENDIF.


  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
    CALL METHOD super->zif_rak_journey_logic~on_popup_event
      EXPORTING
        io_ctx   = io_ctx
        iv_id    = iv_id
        iv_event = iv_event.

        case iv_event.
        when c_Add_chemical.
        io_ctx->open_popup( c_open_popup ).
        endcase.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
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
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    super->zif_rak_journey_logic~on_render_popup(
      io_ctx   = io_ctx
      io_popup = io_popup
      iv_id    = iv_id
    ).

    CASE IV_ID.
    WHEN C_OPEN_POPUP.

    ENDCASE.
  ENDMETHOD.
ENDCLASS.
