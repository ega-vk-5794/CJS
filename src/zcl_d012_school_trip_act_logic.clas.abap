class ZCL_D012_SCHOOL_TRIP_ACT_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

* D012 School Activities Approvals.
*
* Two checks, both of a shape no rule can carry, and nothing else. The form is entirely
* configuration.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
protected section.
private section.

  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'Applicant Name' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'Emirates Id Number' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'Applicant Type' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_VALID_TO type STRING value 'LICENCE_VALID_TO' ##NO_TEXT.

*   The fifteen grade fields, in the order the citizen reads them. Held as a list
*   rather than fifteen IFs: a chain of fifteen conditions is where exactly one gets
*   mistyped, and that one silently lets an activity through with no grade selected.
  methods GRADE_FIELDS
    returning
      value(RT) type ZIF_RAK_JOURNEY=>TT_STRING .
ENDCLASS.



CLASS ZCL_D012_SCHOOL_TRIP_ACT_LOGIC IMPLEMENTATION.


  METHOD grade_fields.
*   Backticks, not quotes. A '...' literal is C(n) and VALUE #( ) on an elementary row
*   type demands compatibility rather than convertibility, so quotes are rejected
*   against STRING - and the error points at the constructor, not at the literal.
    rt = VALUE #(
      ( `GR_PREKG` )   ( `GR_KG1` )     ( `GR_KG2` )
      ( `GR_GRADE_1` ) ( `GR_GRADE_2` ) ( `GR_GRADE_3` )
      ( `GR_GRADE_4` ) ( `GR_GRADE_5` ) ( `GR_GRADE_6` )
      ( `GR_GRADE_7` ) ( `GR_GRADE_8` ) ( `GR_GRADE_9` )
      ( `GR_GRADE_10` ) ( `GR_GRADE_11` ) ( `GR_GRADE_12` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_TABLES =
*    .

    DATA(lv_sel) = io_ctx->get_val( 'LIC_SELECT' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   Step 1 is the licence, step 2 the activity form. Steps count from zero.
    IF iv_step <> 1.
      RETURN.
    ENDIF.

*   ---- at least one targeted grade --------------------------------------------
*   Fifteen independent booleans on ZST_CS_EGA_DOK_APPLN_OP_ACTV, so fifteen CHECKBOX
*   fields rather than one CHECKGROUP - a required group is satisfied by ticking any
*   one option, and a comma list is not something the backend structure can receive.
*
*   The cost of that decision is this loop. It is the right trade: the alternative was
*   one group plus a handler written to unpick it.
    DATA(lv_any) = abap_false.
    LOOP AT grade_fields( ) INTO DATA(lv_grade).
      IF io_ctx->get_val( lv_grade ) IS NOT INITIAL.
        lv_any = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_any = abap_false.
      APPEND VALUE #( type  = 'Error'
*                      field = 'GR_PREKG'
                      text  = `Select at least one targeted grade.` ) TO rt.
    ENDIF.

*   ---- the activity window ----------------------------------------------------
*   Date AND time, compared as one value. Comparing the dates alone passes an activity
*   that starts at 14:00 and ends at 09:00 on the same day, which is the case a citizen
*   is most likely to enter by accident - they set the date once and then adjust the
*   times.
*
*   Both halves are REQUIRED already, so an empty one is reported there; this only
*   speaks when all four are filled and still wrong.
    DATA(lv_sd) = io_ctx->get_val( 'START_DATE' ).
    DATA(lv_st) = io_ctx->get_val( 'START_TIME' ).
    DATA(lv_ed) = io_ctx->get_val( 'END_DATE' ).
    DATA(lv_et) = io_ctx->get_val( 'END_TIME' ).

    IF lv_sd IS NOT INITIAL AND lv_ed IS NOT INITIAL
       AND lv_st IS NOT INITIAL AND lv_et IS NOT INITIAL.

      IF |{ lv_ed }{ lv_et }| < |{ lv_sd }{ lv_st }|.
        APPEND VALUE #( type  = 'Error'
*                        field = 'END_DATE'
                        text  = `The activity must end after it starts.` ) TO rt.
      ENDIF.

    ELSEIF lv_sd IS NOT INITIAL AND lv_ed IS NOT INITIAL AND lv_ed < lv_sd.
*     Times not both filled yet, but the dates are already the wrong way round. Worth
*     saying now rather than waiting for the times to be entered.
      APPEND VALUE #( type  = 'Error'
*                      field = 'END_DATE'
                      text  = `The activity end date cannot be before the start date.` ) TO rt.
    ENDIF.

*   ---- supervisors ------------------------------------------------------------
*   Not a business rule anyone wrote down, and deliberately NOT enforced here. The BRD
*   shows 2 supervisors for 70 students but names no ratio, and inventing one would
*   refuse applications the department would have approved. MIN_VAL = 1 in the config
*   is as far as the evidence goes.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.


    DATA: lv_loginbp TYPE bu_partner.

    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role.

    IF lv_loginbp IS NOT INITIAL.
      NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
        EXPORTING
          iv_bp_id      = lv_loginbp
        IMPORTING
          es_bp_details = DATA(ls_bp) ).

*      "Login BP
      io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).
*      "Applicant Name
      IF sy-langu = c_lang_en.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.
*      "Emirates Id
      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).
*      "Applicant Type
      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).
*      "Valid to
      io_ctx->set_val( iv_name = c_valid_to iv_value = CONV #( ls_bp-EID_expiry_on ) ).

    ENDIF.

  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .

  endmethod.


  METHOD zif_rak_journey_logic~on_value_help.
    DATA(lv_step) = io_ctx->get_step( ).
    IF iv_field = 'LICENSE_SEL'.

      DATA(lv_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
      DATA(lr_licence_api) = NEW zcl_dok_appln_handler_api( ).
      DATA lv_login_bp TYPE  bu_partner.
      lv_login_bp = lv_bp.
      lr_licence_api->get_all_school_licenses(
                               EXPORTING
                                 iv_partner             = lv_login_bp
                               IMPORTING
                                 et_all_school_licenses = DATA(lt_license) ).
      SORT lt_license BY recnnr.
      DELETE lt_license WHERE recnnr IS INITIAL.
      rt = VALUE #(
               FOR ls_license IN lt_license
                ( key = ls_license-recnnr text =  ls_license-recntxt )
                  ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
