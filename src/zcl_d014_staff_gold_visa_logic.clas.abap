class ZCL_D014_STAFF_GOLD_VISA_LOGIC definition
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
protected section.
private section.

  constants C_ROLE type STRING value 'STAFF_ROLE' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'PARTNER_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'PARTNER_EMAIL' ##NO_TEXT.

  methods WRITE_ROLE_FLAGS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
ENDCLASS.



CLASS ZCL_D014_STAFF_GOLD_VISA_LOGIC IMPLEMENTATION.


  METHOD write_role_flags.
    DATA(lv_role) = io_ctx->get_val( c_role ).
    io_ctx->set_val( iv_name  = 'PARTNER_PRINCIPAL'
                     iv_value = COND #( WHEN lv_role = 'L' THEN 'X' ELSE '' ) ).
    io_ctx->set_val( iv_name  = 'PARTNER_TEACHER'
                     iv_value = COND #( WHEN lv_role = 'T' THEN 'X' ELSE '' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.

    IF io_ctx->get_val( c_role ) IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF io_ctx->get_val( 'PARTNER_TEACHER' ) IS NOT INITIAL.
      io_ctx->set_val( iv_name = c_role iv_value = 'T' ).
    ELSEIF io_ctx->get_val( 'PARTNER_PRINCIPAL' ) IS NOT INITIAL.
      io_ctx->set_val( iv_name = c_role iv_value = 'L' ).
    ENDIF.
*
*    io_ctx->set_val(
*      iv_name  = 'DECLARATION'
*      iv_value = zcl_rak_text=>get( iv_no      =   zcl_rak_text=>c_no-confirm
*                                    iv_default = 'I, &1, as the applicant, hereby declare...'
*                                    iv_v1      = io_ctx->get_val( c_partner_name ) ) ).

*
*    io_ctx->set_val(
*      iv_name  = 'DECLARATION'
*      iv_value = 'test declaration text'   ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

    write_role_flags( io_ctx ).
    DELETE ct_kv WHERE key = 'STAFF_ROLE'.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

    IF iv_field = c_role.
      write_role_flags( io_ctx ).
      IF io_ctx->get_val( c_role ) <> 'L'.
        io_ctx->set_val( iv_name = 'PRINCIPAL_TYPE' iv_value = '' ).
      ENDIF.
    ENDIF.

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


    IF iv_step <> 0.
      RETURN.
    ENDIF.

    DATA(lv_role) = io_ctx->get_val( c_role ).

    IF lv_role IS NOT INITIAL
       AND io_ctx->get_val( 'PARTNER_PRINCIPAL' ) IS INITIAL
       AND io_ctx->get_val( 'PARTNER_TEACHER' )   IS INITIAL.
      APPEND VALUE #( type  = 'Error'
*                      field = c_role
                      text  = `Re-select Leadership or Teacher before continuing.` ) TO rt.
    ENDIF.

    IF lv_role = 'L' AND io_ctx->get_val( 'PRINCIPAL_TYPE' ) IS INITIAL.
      APPEND VALUE #( type  = 'Error'
*                      field = 'PRINCIPAL_TYPE'
                      text  = `Select the position.` ) TO rt.
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

      io_ctx->set_val( iv_name = c_PARTNER_MOBILE iv_value = CONV #( ls_bp-mobile_number ) ).
      io_ctx->set_val( iv_name = c_PARTNER_EMAIL iv_value = CONV #( ls_bp-email_address ) ).


      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

    ENDIF.

  ENDMETHOD.
ENDCLASS.
