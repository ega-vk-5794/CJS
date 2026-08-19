class ZCL_D011_SCHOOL_ADVERTIS_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

* D011 Advertisement Approval.
*
* Configuration renders the screen. This class exists only for the four things
* ZRAK_T_JNY_* cannot express, and each one is named below. If a method here starts
* drawing a form, the configuration is wrong rather than insufficient.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_consent TYPE string VALUE 'ADV_CONSENT'.

ENDCLASS.



CLASS ZCL_D011_SCHOOL_ADVERTIS_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    CALL METHOD super->zif_rak_journey_logic~get_table
      EXPORTING
        io_ctx  = io_ctx
        iv_name = iv_name
      RECEIVING
        rs_data = rs_data.

    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.
        DATA(lt_licenses) = io_ctx->get_grid_data( 'LICENSES' ).
        rs_data = io_ctx->get_backend_table( 'LICENSES' ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

*   ADV_CONSENT is a screen control and nothing on the backend reads it - the two
*   carriers do the work. Posting it would reach MAPPER with no TECH_NAME to assign
*   to, which is harmless, but it also puts an item in the payload that no one can
*   explain when they read the trace.
    DELETE ct_kv WHERE key = 'ADV_CONSENT'.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
    CALL METHOD super->zif_rak_journey_logic~on_before_tables
      EXPORTING
        io_ctx    = io_ctx
      CHANGING
        ct_tables = ct_tables.
    DATA(lv_sel) = io_ctx->get_val( 'LICENCE_NO_SEL' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel.
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

    CASE iv_field.

      WHEN c_consent.
*       ONE control, TWO backend flags.
*
*       In the /QNV export this was two TBUTTONs sharing one DATA1 - a segmented
*       control, drawn as a pair. The backend structure did not follow: CASE_MAPPING
*       reads GS_DATA-ADV_PERSONAL_DATA_Y and _N as separate flags, so a single posted
*       value cannot satisfy it and the two hidden carriers have to be written here.
*
*       Both are set on every change, never one. Setting only the chosen side leaves
*       the other holding the previous answer, so a citizen who switches from Yes to No
*       posts both flags true and the case is created saying two contradictory things.
        DATA(lv_answer) = io_ctx->get_val( c_consent ).
        io_ctx->set_val( iv_name  = 'ADV_PERSONAL_Y'
                         iv_value = COND #( WHEN lv_answer = 'Y' THEN 'X' ELSE '' ) ).
        io_ctx->set_val( iv_name  = 'ADV_PERSONAL_N'
                         iv_value = COND #( WHEN lv_answer = 'N' THEN 'X' ELSE '' ) ).

      WHEN OTHERS.
    ENDCASE.

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


*   Step 1 is the licence, step 2 the form. Steps count from zero in hooks.
    IF iv_step <> 1.
      RETURN.
    ENDIF.

*   ---- at least one advertisement type ----------------------------------------
*   Not a rule, and not a CHECKGROUP either.
*
*   A CHECKGROUP would have given this for free, but it stores a comma list and no
*   rule operator asks whether a list contains a value - so nothing downstream could
*   read it. As four booleans they map straight onto the backend structure, and the
*   price is that "at least one" has to be asked here.
*
*   The BAdI asks the same question on the post (message e045). Both sides have to
*   agree, or a citizen passes this check and is refused by the backend for something
*   they have already satisfied.
    IF io_ctx->get_val( 'TYPE_TEXT' )   IS INITIAL AND
       io_ctx->get_val( 'TYPE_PHOTOS' ) IS INITIAL AND
       io_ctx->get_val( 'TYPE_VIDEOS' ) IS INITIAL AND
       io_ctx->get_val( 'TYPE_AUDIO' )  IS INITIAL.
      APPEND VALUE #( type  = 'Error'
*                      field = 'TYPE_TEXT'
                      text  = `Select at least one advertisement type.` ) TO rt.
    ENDIF.

*   ---- the advertisement window ----------------------------------------------
*   Field against field, which SRC_VALUE cannot express - a rule compares a field to a
*   literal. Guarded on both being filled: REQUIRED already reports an empty date, and
*   reporting it twice reads as two faults.
    DATA(lv_from) = io_ctx->get_val( 'REQUEST_ON' ).
    DATA(lv_to)   = io_ctx->get_val( 'END_DATE' ).
    IF lv_from IS NOT INITIAL AND lv_to IS NOT INITIAL AND lv_to < lv_from.
      APPEND VALUE #( type  = 'Error'
*                      field = 'END_DATE'
                      text  = `The advertisement end date cannot be before the start date.` ) TO rt.
    ENDIF.

*   ---- the consent answer -----------------------------------------------------
*   REQUIRED on ADV_CONSENT covers the control, but the two carriers are what travel,
*   and a draft resumed from before this handler existed can arrive with the control
*   set and the carriers blank. Cheap to check, and the failure it prevents is a case
*   created with neither flag.
    IF io_ctx->get_val( c_consent ) IS NOT INITIAL
       AND io_ctx->get_val( 'ADV_PERSONAL_Y' ) IS INITIAL
       AND io_ctx->get_val( 'ADV_PERSONAL_N' ) IS INITIAL.
      APPEND VALUE #( type  = 'Error'
*                      field = c_consent
                      text  = `Re-select the consent answer before continuing.` ) TO rt.
    ENDIF.

  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
  EXPORTING
    IO_CTX = IO_CTX
    .
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

      io_ctx->set_val( iv_name = 'OWNER_BP' iv_value = |{ lv_loginbp }| ).

      IF sy-langu = 'E'.
        io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

      io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = |{ lv_role }| ).

    ENDIF.
  endmethod.
ENDCLASS.
