class ZCL_E032_WELLDRILL_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_min_search_len TYPE i      VALUE 3.
    CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.
    CONSTANTS c_owner_bp       TYPE string VALUE 'OWNER_BP'.
    CONSTANTS c_permit_no      TYPE string VALUE 'PERMIT_NUMBER'.
    CONSTANTS c_permit_detail  TYPE string VALUE 'PERMIT_DETAIL'.
    CONSTANTS c_app_name       TYPE string VALUE 'APP_NAME'.
    CONSTANTS c_app_id         TYPE string VALUE 'APP_ID'.
    CONSTANTS c_app_mobile     TYPE string VALUE 'APP_MOBILE'.
    CONSTANTS c_app_email      TYPE string VALUE 'APP_EMAIL'.
    CONSTANTS c_login_bp       TYPE string VALUE 'LOGIN_BP'.
    CONSTANTS c_lang_en        TYPE string VALUE 'E' ##NO_TEXT.
    CONSTANTS c_app_role       TYPE string VALUE 'APP_ROLE'.
    CONSTANTS c_permit_mode    TYPE string VALUE 'PERMIT_MODE'.
    CONSTANTS c_permit_number  TYPE string VALUE 'PERMIT_NUMBER'.

    CONSTANTS c_owner_bp_idtype  TYPE string VALUE 'OWNER_BP_IDTYPE'.
    CONSTANTS c_owner_name  TYPE string VALUE 'OWNER_NAME'.
    CONSTANTS c_owner_mobile  TYPE string VALUE 'OWNER_MOBILE'.
    CONSTANTS c_owner_email  TYPE string VALUE 'OWNER_EMAIL'.
    CONSTANTS c_owner_dob  TYPE string VALUE 'OWNER_DOB'.
    CONSTANTS c_owner_nationality  TYPE string VALUE 'OWNER_NATIONALITY'.
    CONSTANTS c_owner_seg  TYPE string VALUE 'APP_ROLE'.
    CONSTANTS c_owner  TYPE string VALUE 'OWNER'.
    CONSTANTS c_rep  TYPE string VALUE 'REP'.








    " One row per segmented driver: its field, the option key that sets the
    " FIRST flag, and the two carrier field names. Data, not three copies of
    " the same code.
    TYPES: BEGIN OF ty_fan,
             src   TYPE string,   " segmented field
             key_a TYPE string,   " option key that sets flag_a = 'X'
             fld_a TYPE string,   " carrier for key_a
             fld_b TYPE string,   " carrier for the other option
           END OF ty_fan.
    TYPES tt_fan TYPE STANDARD TABLE OF ty_fan WITH EMPTY KEY.
    METHODS fan_map RETURNING VALUE(rt_fan) TYPE tt_fan.

    " Apply one driver's fan-out into ctx (used by on_change).
    METHODS fan_one
      IMPORTING is_fan TYPE ty_fan
                io_ctx TYPE REF TO zif_rak_journey.
ENDCLASS.



CLASS ZCL_E032_WELLDRILL_LOGIC IMPLEMENTATION.


  METHOD fan_map.
    rt_fan = VALUE #(
      ( src = 'APP_ROLE'    key_a = 'REP'  fld_a = 'PARTNER_REP_FLG'     fld_b = 'PARTNER_OWNER_FLG' )
      ( src = 'PERMIT_MODE' key_a = 'YES'  fld_a = 'PERMIT_YES_FLG'      fld_b = 'PERMIT_NO_FLG' )
      ( src = 'BENEFICIARY' key_a = 'COMP' fld_a = 'BENEFIT_COMPANY_FLG' fld_b = 'BENEF_INDIVIDUAL_FLG' ) ).
  ENDMETHOD.


  METHOD fan_one.
    DATA(lv_val) = to_upper( condense( io_ctx->get_val( is_fan-src ) ) ).
    io_ctx->set_val( iv_name  = is_fan-fld_a
                     iv_value = COND string( WHEN lv_val = is_fan-key_a THEN `X` ELSE `` ) ).
    io_ctx->set_val( iv_name  = is_fan-fld_b
                     iv_value = COND string( WHEN lv_val = is_fan-key_a THEN `` ELSE `X` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No payment step, but keep the guard in case a PAYFEE is added later.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " Re-derive every flag straight from the payload — the user can reach
    " submit without a change event (draft resume / back-nav). flatten_kv
    " has already swept the segmented values into ct_kv.
    LOOP AT fan_map( ) INTO DATA(ls_fan).
      DATA lv_val TYPE string.
      CLEAR lv_val.
      READ TABLE ct_kv INTO DATA(ls_src) WITH KEY key = ls_fan-src.
      IF sy-subrc = 0.
        lv_val = to_upper( condense( CONV string( ls_src-value ) ) ).
      ENDIF.
      LOOP AT ct_kv ASSIGNING FIELD-SYMBOL(<kv>)
           WHERE key = ls_fan-fld_a OR key = ls_fan-fld_b.
        IF <kv>-key = ls_fan-fld_a.
          <kv>-value = COND string( WHEN lv_val = ls_fan-key_a THEN `X` ELSE `` ).
        ELSE.
          <kv>-value = COND string( WHEN lv_val = ls_fan-key_a THEN `` ELSE `X` ).
        ENDIF.
      ENDLOOP.
      " The segmented driver itself has no tech_name -> drop it.
      DELETE ct_kv WHERE key = ls_fan-src.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    DATA(lv_field) = to_upper( iv_field ).
    LOOP AT fan_map( ) INTO DATA(ls_fan) WHERE src = lv_field.
      fan_one( is_fan = ls_fan io_ctx = io_ctx ).
    ENDLOOP.
    " NB. do NOT resolve the permit here — permit_selection reads master
    " data and belongs to the bridge. (And ZCL_EGA_BP_BO_API->BP_QUERY has a
    " WAIT that would commit the step; never call it from on_change.)
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    IF iv_field = c_owner_bp.


      CHECK to_upper( iv_field ) = c_owner_bp."'OWNER_BP'.

      DATA(lv_eid) = condense( io_ctx->get_val( c_owner_bp ) ).
*    IF strlen( lv_eid ) < c_min_search_len.
*      io_ctx->add_msg( iv_type = 'Warning'
*                       iv_text = |Enter at least { c_min_search_len } characters to search| ).
*      RETURN.
*    ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( c_owner_bp_idtype ).
      IF lv_idtype IS INITIAL.
        lv_idtype = c_default_idtype.
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

      io_ctx->set_val( iv_name = c_owner_name        iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_mobile      iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_email       iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_dob         iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_nationality iv_value = ' ' ).


      io_ctx->set_val( iv_name = c_owner_bp          iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = c_owner_name        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = c_owner_mobile      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = c_owner_email       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = c_owner_dob         iv_value = |{ ev_date_of_birth }| ).
      io_ctx->set_val( iv_name = c_owner_nationality iv_value = |{ ev_nationality }| ).

    ELSEIF iv_field = c_permit_no.
      DATA(lv_permit) = condense( io_ctx->get_val( c_permit_no ) ).

      IF lv_permit IS NOT INITIAL.
        SELECT SINGLE contractname FROM zv_epdapmmast INTO @DATA(lv_contrat) WHERE permitid = @lv_permit.

        IF lv_contrat IS NOT INITIAL.
          io_ctx->set_val( iv_name = c_permit_no  iv_value = |{ lv_permit }| ).
          io_ctx->set_val( iv_name = c_permit_detail  iv_value = |{ lv_contrat }| ).
*          gs_data-permit_number = lv_permit.
        ELSE.
          io_ctx->set_val( iv_name = c_permit_detail iv_value = ' ' ).
          io_ctx->add_msg( iv_type = 'Error'
                           iv_text = |Enter Valid Permit No to search| ).
        ENDIF.

      ENDIF.
    ENDIF.


  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

      DATA: lv_loginbp TYPE bu_partner.
      lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
      DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
      DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

      IF lv_loginbp IS INITIAL AND syst-sysid = 'E10'.
        lv_loginbp = '1000116563'.
      ENDIF.

      IF lv_loginbp IS NOT INITIAL.
        NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
          EXPORTING
            iv_bp_id      = lv_loginbp
          IMPORTING
            es_bp_details = DATA(ls_bp) ).

        io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).

        IF sy-langu = c_lang_en.
          io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name ) ).
        ELSE.
          io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
        ENDIF.

        io_ctx->set_val( iv_name = c_app_id     iv_value = CONV #( ls_bp-emirates_id ) ).
        io_ctx->set_val( iv_name = c_app_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
        io_ctx->set_val( iv_name = c_app_email  iv_value = CONV #( ls_bp-email_address ) ).
*      io_ctx->set_val( iv_name = c_app_role iv_value = |{ lv_role }| ).
        io_ctx->set_val( iv_name = c_app_role iv_value = |{ c_rep }| ).


      ELSE.


*      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000180559' ). "'1000116563' )
*      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '1000116563' ). "'1000116563' ).
*
**    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
**    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
*
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
*      io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).

      ENDIF.


    ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.

*    DATA(lv_owner_seg) = io_ctx->get_val( c_owner_seg ).
*    IF lv_owner_seg = c_owner.
*      io_ctx->set_hidden( c_owner_name ).
*      io_ctx->set_hidden( c_owner_mobile ).
*      io_ctx->set_hidden( c_owner_mobile ).
*      io_ctx->set_hidden( c_owner_dob ).
*      io_ctx->set_hidden( c_owner_nationality ).
*    ENDIF.

  ENDMETHOD.
ENDCLASS.
