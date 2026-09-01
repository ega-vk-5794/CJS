class ZCL_D002_SCHOOL_LIC_NEW_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
protected section.
private section.

*    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_validity       TYPE string VALUE 'VALIDITY_YEAR1'  ##NO_TEXT.
    CONSTANTS c_step_lease     TYPE i      VALUE 1.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_permit_yes TYPE string VALUE 'PERMIT_YES' ##NO_TEXT.
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
    CONSTANTS c_partner_name  TYPE string VALUE 'APP_NAME' .
    CONSTANTS c_partner_id  TYPE string VALUE 'APP_ID' .
    CONSTANTS c_applicant_type  TYPE string VALUE 'APP_TYPE'.
  types:
    BEGIN OF ty_stage,
             flag  TYPE string,
             label TYPE string,
             keys  TYPE string,
           END OF ty_stage .
  types:
    tt_stage TYPE STANDARD TABLE OF ty_stage WITH EMPTY KEY .



  methods STAGES
    returning
      value(RT) type TT_STAGE .
  methods STAGE_HAS_FEE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_KEYS type STRING
    returning
      value(RV_OK) type ABAP_BOOL .
  methods CLEAR_STAGE_FEES
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_KEYS type STRING .
ENDCLASS.



CLASS ZCL_D002_SCHOOL_LIC_NEW_LOGIC IMPLEMENTATION.


  METHOD clear_stage_fees.
    SPLIT iv_keys AT ',' INTO TABLE DATA(lt_key).
    LOOP AT lt_key INTO DATA(lv_key).
      io_ctx->set_val( iv_name = |SCH_{ lv_key }| iv_value = '' ).
      io_ctx->set_val( iv_name = |BKS_{ lv_key }| iv_value = '' ).
      io_ctx->set_val( iv_name = |UNI_{ lv_key }| iv_value = '' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD stages.
    rt = VALUE #(
      ( flag = `PREKG`        label = `Pre-KG`       keys = `PREKG` )
      ( flag = `KINDERGARTEN` label = `Kindergarten` keys = `KG1,KG2` )
      ( flag = `CYCLE_1`      label = `Cycle 1`      keys = `G1,G2,G3,G4` )
      ( flag = `CYCLE_2`      label = `Cycle 2`      keys = `G5,G6,G7,G8` )
      ( flag = `CYCLE_3`      label = `Cycle 3`      keys = `G9,G10,G11,G12` ) ).
  ENDMETHOD.


  METHOD stage_has_fee.
    SPLIT iv_keys AT ',' INTO TABLE DATA(lt_key).
    LOOP AT lt_key INTO DATA(lv_key).
      IF io_ctx->get_val( |SCH_{ lv_key }| ) IS NOT INITIAL
         OR io_ctx->get_val( |BKS_{ lv_key }| ) IS NOT INITIAL
         OR io_ctx->get_val( |UNI_{ lv_key }| ) IS NOT INITIAL.
        rv_ok = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~GET_TABLE.
    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.
        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).

        " REVIEW: replace with the real school-license read (the export
        " names FM ZFM_EGA_CJ_FW_READ_TABLE_DATAN / context LICENCES).
*        SELECT license_no, school_name, issued_at, expired_at
*          FROM ztb_dok_licenses                         "#EC CI_NOORDBY
*          WHERE partner = @io_ctx->get_val( 'OWNER_BP' )
*          INTO TABLE @DATA(lt_lic).
*
*        LOOP AT lt_lic INTO DATA(ls_lic).
*          APPEND VALUE #( ( |{ ls_lic-license_no }| )
*                          ( |{ ls_lic-school_name }| )
*                          ( |{ ls_lic-issued_at DATE = USER }| )
*                          ( |{ ls_lic-expired_at DATE = USER }| ) ) TO rs_table-rows.
*        ENDLOOP.

      WHEN 'OWNERS'.
        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile Number` ) ( `E-mail` ) ).

        " REVIEW: replace with the real current-owners read for the
        " SELECTED license (export context OWNERS_DISP).
*        SELECT partner_name, nationality, share_pct, mobile, email
*          FROM ztb_dok_owners                           "#EC CI_NOORDBY
*          WHERE license_no = @io_ctx->get_val( 'LICENSE_SEL' )
*          INTO TABLE @DATA(lt_own).
*
*        LOOP AT lt_own INTO DATA(ls_own).
*          APPEND VALUE #( ( |{ ls_own-partner_name }| )
*                          ( |{ ls_own-nationality }|   )
*                          ( |{ ls_own-share_pct }|     )
*                          ( |{ ls_own-mobile }|        )
*                          ( |{ ls_own-email }|         ) ) TO rs_table-rows.
*        ENDLOOP.

    ENDCASE.
  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ.
    DATA(ls_owners) = io_ctx->get_grid_data( 'OWNERS_TABLE' ).
    IF ls_owners-rows IS INITIAL.

    ENDIF.

   DATA(ls_g) = io_ctx->get_backend_table( 'OWNERS_TABLE' ).
    IF ls_g-rows IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_map TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    lt_map = VALUE #( ( 1 ) ( 2 ) ( 3 ) ( 4 ) ( 5 ) ( 7 ) ( 9 ) ).

    DATA(ls_out) = VALUE zif_rak_journey=>ty_table(
      columns = VALUE #( ( `PARTNER` ) ( `NAME` ) ( `MOBILE_NUMBER` ) ( `EMAIL_ADDRESS` )
                         ( `SHARE_PER` ) ( `EMIRATES_ID` ) ( `NATIONALITY` ) ) ).

    LOOP AT ls_g-rows INTO DATA(lt_row).
      DATA lt_cells TYPE zif_rak_journey=>tt_string.
      CLEAR lt_cells.
      LOOP AT lt_map INTO DATA(lv_ix).
        DATA(lv_cell) = VALUE string( lt_row[ lv_ix ] OPTIONAL ).
        APPEND lv_cell TO lt_cells.
      ENDLOOP.
      APPEND lt_cells TO ls_out-rows.
    ENDLOOP.

    io_ctx->set_grid_data( iv_field = 'OWNERS_TABLE' is_data = ls_out ).


  endmethod.


  METHOD zif_rak_journey_logic~on_before_tables.
    DATA(lv_sel) = io_ctx->get_val( 'NOC_SEL' ).
    IF lv_sel IS NOT INITIAL.
      LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'NOC_APPROVED' AND ui_table_column1 = lv_sel..
        IF <t>-ui_table_column1 = lv_sel.
          <t>-ui_table_column29 = 'S'.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA(ls_owners) = io_ctx->get_grid_data( 'OWNERS_TABLE' ).
    IF ls_owners-rows IS INITIAL.
*      APPEND VALUE #( type  = 'Error'
**                          field = 'OWNERS'
*                      text  = `Add at least one owner.` ) TO rt.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

    LOOP AT stages( ) INTO DATA(ls_stage) WHERE flag = iv_field.
      IF io_ctx->get_val( ls_stage-flag ) IS INITIAL.
        clear_stage_fees( io_ctx = io_ctx iv_keys = ls_stage-keys ).
      ENDIF.
      EXIT.
    ENDLOOP.

    IF iv_field = 'CYCLE_2' AND io_ctx->get_val( 'CYCLE_2' ) IS INITIAL.
      io_ctx->set_val( iv_name = 'CYCLE_2_GENDER' iv_value = '' ).
    ENDIF.
    IF iv_field = 'CYCLE_3' AND io_ctx->get_val( 'CYCLE_3' ) IS INITIAL.
      io_ctx->set_val( iv_name = 'CYCLE_3_GENDER' iv_value = '' ).
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


    CASE iv_step.

      WHEN 2.
        DATA(ls_owners) = io_ctx->get_grid_data( 'OWNERS_TABLE' ).
        IF ls_owners-rows IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = 'OWNERS'
                          text  = `Add at least one owner.` ) TO rt.
        ENDIF.

      WHEN 3.
        DATA(lv_any) = abap_false.

        LOOP AT stages( ) INTO DATA(ls_stage).
          IF io_ctx->get_val( ls_stage-flag ) IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_any = abap_true.

          IF stage_has_fee( io_ctx = io_ctx iv_keys = ls_stage-keys ) = abap_false.
            APPEND VALUE #( type  = 'Error'
*                            field = ls_stage-flag
                            text  = |{ ls_stage-label } is selected but has no fees entered.| ) TO rt.
          ENDIF.
        ENDLOOP.

        IF lv_any = abap_false.
          APPEND VALUE #( type  = 'Error'
*                          field = 'PREKG'
                          text  = `Select at least one educational stage.` ) TO rt.
        ENDIF.

        DATA(ls_build) = io_ctx->get_grid_data( 'BUILDINGS' ).
        IF ls_build-rows IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = 'BUILDING'
                          text  = `Add at least one building block.` ) TO rt.
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

    DATA: lv_loginbp TYPE bu_partner.
    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

    io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).
    io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ lv_loginbp }| ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.
    DATA(ls_owners) = io_ctx->get_grid_data( 'OWNERS_TABLE' ).
    IF ls_owners-rows IS NOT INITIAL.
      LOOP AT ls_owners-rows ASSIGNING FIELD-SYMBOL(<ls_row>).
        IF sy-subrc IS INITIAL.

        ENDIF.
      ENDLOOP.

      LOOP AT ls_owners-columns ASSIGNING FIELD-SYMBOL(<ls_column>).
        IF sy-subrc IS INITIAL.

        ENDIF.
      ENDLOOP.

      CONSTANTS c_grid TYPE string VALUE 'OWNERS_TABLE' ##NO_TEXT.
      io_ctx->set_grid_data( iv_field = c_grid is_data = ls_owners ).

    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    CONSTANTS c_min_search_len TYPE string VALUE 5.
*    CHECK to_upper( iv_field ) = 'MANAGERSEARCH'.
    IF iv_field = 'MANAGERSEARCH'.

      DATA(lv_eid) = condense( io_ctx->get_val( 'MANAGERSEARCH' ) ).
      IF strlen( lv_eid ) < 5 . "c_min_search_len.
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Enter at least { c_min_search_len } characters to search| ).
        RETURN.
      ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( 'MANAGERSEARCH_IDTYPE' ).
      IF lv_idtype IS INITIAL.
        lv_idtype = 'YFS002' . "c_default_idtype.
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

      io_ctx->set_val( iv_name = 'NEWMGRNAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'MANAGER_EID'       iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'MANAGER_MOBILE'    iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'MANAGER_EMAIL'     iv_value = ' ' ).
*    io_ctx->set_val( iv_name = 'NEWMGRDOB'         iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'MANAGER_NATION'    iv_value = ' ' ).


      io_ctx->set_val( iv_name = 'MANAGER_EID'     iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = 'NEWMGRNAME'        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = 'MANAGER_MOBILE'    iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = 'MANAGER_EMAIL'     iv_value = |{ ev_email }| ).
*    io_ctx->set_val( iv_name = 'NEWMGRDOB'         iv_value = |{ ev_date_of_birth }| ).
      io_ctx->set_val( iv_name = 'MANAGER_NATION'    iv_value = |{ ev_nationality }| ).

    ENDIF.

*    CHECK to_upper( iv_field ) = 'TRADESEARCH'.
    IF iv_field = 'TRADESEARCH'.

      io_ctx->set_val( iv_name = 'TRADE_NAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'TRADE_MOBILE'      iv_value = ' ' ).

      DATA(lv_trade_id) = condense( io_ctx->get_val( 'TRADESEARCH' ) ).

      IF lv_trade_id IS INITIAL.
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Enter valid Trade ID to search| ).
      ELSE.
        SELECT SINGLE partner FROM but0id INTO @DATA(lv_trade_partner) WHERE idnumber EQ @lv_trade_id AND type EQ 'YP0001'.
        IF lv_trade_partner IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                iv_text = |No  valid Business Partner Found for Entered Trade ID| ).
        ENDIF.
      ENDIF.

      IF lv_trade_partner IS NOT INITIAL.
        NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
            EXPORTING
               iv_bp_id      = lv_trade_partner
            IMPORTING
               es_bp_details = DATA(ls_bp) ).

        io_ctx->set_val( iv_name = 'TRADE_NAME'        iv_value = |{ ls_bp-bp_name }| ).
        io_ctx->set_val( iv_name = 'TRADE_MOBILE'      iv_value = |{ ls_bp-mobile_number }| ).

      endif.


      ENDIF.

    ENDMETHOD.
ENDCLASS.
