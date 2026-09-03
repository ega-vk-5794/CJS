class ZCL_E031_MATSTORAGE_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
protected section.
private section.

  types:
    BEGIN OF ty_fan, src TYPE string, key_a TYPE string, fld_a TYPE string, fld_b TYPE string, END OF ty_fan .
  types:
    tt_fan TYPE STANDARD TABLE OF ty_fan WITH EMPTY KEY .

  constants C_MIN_SEARCH_LEN type I value 3 ##NO_TEXT.
  constants C_DEFAULT_IDTYPE type STRING value 'YFS002' ##NO_TEXT.
  constants C_OWNER_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_STEP_STORAGE type I value 2 ##NO_TEXT.  " 0-based: APPL,COMP,STORAGE
  constants C_APP_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_APP_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APP_MOBILE type STRING value 'APP_MOBILE' ##NO_TEXT.
  constants C_APP_EMAIL type STRING value 'APP_EMAIL' ##NO_TEXT.
  constants C_PERMIT_MODE type STRING value 'PERMIT_MODE' ##NO_TEXT.
  constants C_PERMIT_NUMBER type STRING value 'PERMIT_NUMBER' ##NO_TEXT.
  constants C_OWNER_BP_IDTYPE type STRING value 'OWNER_BP_IDTYPE' ##NO_TEXT.
  constants C_OWNER_NAME type STRING value 'OWNER_NAME' ##NO_TEXT.
  constants C_OWNER_MOBILE type STRING value 'OWNER_PHONE' ##NO_TEXT.
  constants C_OWNER_EMAIL type STRING value 'OWNER_EMAIL' ##NO_TEXT.
  constants C_OWNER_DOB type STRING value 'OWNER_DOB' ##NO_TEXT.
  constants C_OWNER_NATIONALITY type STRING value 'OWNER_NATIONALITY' ##NO_TEXT.
  constants C_OWNER_SEG type STRING value 'APP_ROLE' ##NO_TEXT.
  constants C_OWNER type STRING value 'OWNER' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_APP_ROLE type STRING value 'APP_ROLE' ##NO_TEXT.
  constants C_REP type STRING value 'REP' ##NO_TEXT.
  constants C_PERMIT_LOADED type STRING value 'PERMIT_LOADED' ##NO_TEXT.

  methods FAN_MAP
    returning
      value(RT) type TT_FAN .
ENDCLASS.



CLASS ZCL_E031_MATSTORAGE_LOGIC IMPLEMENTATION.


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
*   which is every step where payment is actually decided. Nothing here assigns
*   RT today; when the block below is revived it must EXTEND it with
*   VALUE #( BASE rt ... ), never assign over it, or the gate's own messages go.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

    CHECK iv_step = c_step_storage.
    " STILL DEAD. The block below was written against an assumed get_grid( )
    " that does not exist: the real accessor is io_ctx->get_grid_data( <field> ),
    " which returns ty_table - COLUMNS plus ROWS as plain string tables, NOT the
    " typed row structure this code reads (<row>-material_type and friends). See
    " ZCL_E016/E017/E018 for the shape that works. Reviving it also needs the
    " grid field name confirmed and a decision on whether >=1 row is really
    " required, so it is left off rather than guessed at.
*    DATA(lt_rows) = io_ctx->get_grid( 'MATERIALS' ).
*    IF lt_rows IS INITIAL.
*      rt = VALUE #( ( type = 'Error' text = 'Add at least one material row' ) ).
*      RETURN.
*    ENDIF.
*    IF lines( lt_rows ) > 2.
*      rt = VALUE #( ( type = 'Error' text = 'A maximum of two material rows is allowed' ) ).
*      RETURN.
*    ENDIF.
*    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<row>).
*      IF     <row>-material_type    IS INITIAL
*          OR <row>-quantity         IS INITIAL
*          OR <row>-unit             IS INITIAL
*          OR <row>-outside_duration IS INITIAL.
*        rt_msg = VALUE #( ( type = 'Error' text = 'Complete every column on each material row' ) ).
*        RETURN.
*      ENDIF.
*    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    IF iv_field = c_owner_bp.
*      CHECK to_upper( iv_field ) = c_owner_bp.
*      DATA(lv_term) = condense( io_ctx->get_val( c_owner_bp ) ).
*      IF strlen( lv_term ) < c_min_search_len.
*        io_ctx->add_msg( iv_type = 'Warning' iv_text = |Enter at least { c_min_search_len } characters to search| ).
*        RETURN.
*      ENDIF.
*      DATA(lv_idt) = io_ctx->get_val( |{ c_owner_bp }_IDTYPE| ).
*      IF lv_idt IS INITIAL. lv_idt = c_default_idtype. ENDIF.
*      SELECT SINGLE a~partner, a~zzfull_name_eng
*        FROM but000 AS a LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idt
*        WHERE b~idnumber = @lv_term OR a~partner = @lv_term INTO @DATA(ls_bp).
*      IF sy-subrc <> 0.
*        io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
*        RETURN.
*      ENDIF.
*      io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-partner }| ).
*      io_ctx->set_val( iv_name = |{ c_owner_bp }_NAME| iv_value = |{ ls_bp-zzfull_name_eng }| ).

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

    ELSEIF iv_field = c_permit_number.
      DATA(lv_permit) = condense( io_ctx->get_val( c_permit_number ) ).

      IF lv_permit IS NOT INITIAL.
        SELECT SINGLE contractname
        FROM zv_epdapmmast
        INTO @DATA(lv_contrat)
        WHERE permitid = @lv_permit.

        IF lv_contrat IS NOT INITIAL.
          io_ctx->set_val( iv_name = c_permit_number  iv_value = |{ lv_permit }| ).
          io_ctx->set_val( iv_name = c_permit_loaded  iv_value = |{ lv_contrat }| ).
        ELSE.
          io_ctx->set_val( iv_name = c_permit_loaded  iv_value  = ' ' ).
          io_ctx->add_msg( iv_type = 'Error'
                             iv_text = |Enter Valid Permit No to search| ).
        ENDIF.
      ENDIF.

    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .

*    DATA: lv_loginbp TYPE bu_partner.
*    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
*    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
*    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner
*
*
*    IF lv_loginbp IS NOT INITIAL.
*      NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
*        EXPORTING
*          iv_bp_id      = lv_loginbp
*        IMPORTING
*          es_bp_details = DATA(ls_bp) ).
*
*      io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).
*
*      IF sy-langu = c_lang_en.
*        io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name ) ).
*      ELSE.
*        io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
*      ENDIF.
*
*      io_ctx->set_val( iv_name = c_app_id     iv_value = CONV #( ls_bp-emirates_id ) ).
*      io_ctx->set_val( iv_name = c_app_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
*      io_ctx->set_val( iv_name = c_app_email  iv_value = CONV #( ls_bp-email_address ) ).
**      io_ctx->set_val( iv_name = c_app_role iv_value = |{ lv_role }| ).
*      io_ctx->set_val( iv_name = c_app_role iv_value = |{ c_rep }| ).

*    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.

    DATA(lv_step) = io_ctx->get_step( ).
    CASE iv_field.
      WHEN 'MATERIALS_DET.MATERIAL_TYPE'.

        rt = VALUE #( ( key = '001' text = 'Coal' )
                      ( key = '002' text = 'Clinker' )
                    ).

      WHEN 'MATERIALS_DET.UNIT'.
        rt = VALUE #( ( key = '001' text = 'KG' )
                      ( key = '002' text = 'MT' )
                    ).

      WHEN 'MATERIALS_DET.DURATION_DAYS'.

        rt = VALUE #( ( key = '01' text = '10 Days' )
                      ( key = '02' text = '30 Days' )
                      ( key = '03' text = '60 Days' )
                      ( key = '04' text = '90 Days' ) ).
    ENDCASE.

  ENDMETHOD.
ENDCLASS.
