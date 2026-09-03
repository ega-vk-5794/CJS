class ZCL_D020_MOD_SCHOOL_DAY_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_FIELDS
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~RENDER_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
    redefinition .
protected section.
private section.

    " Constants only — no mutable attributes (see STATE RULE above).
  constants C_STAGE_PREKG type STRING value 'PREKG' ##NO_TEXT.
  constants C_STAGE_KG type STRING value 'KG' ##NO_TEXT.
  constants C_STAGE_CYC1 type STRING value 'CYCLE1' ##NO_TEXT.
  constants C_STAGE_CYC2 type STRING value 'CYCLE2' ##NO_TEXT.
  constants C_STAGE_CYC3 type STRING value 'CYCLE3' ##NO_TEXT.
  constants C_GRID type STRING value 'OWNERS_SEARCH' ##NO_TEXT.
  constants C_EVT_OWNEW type STRING value 'OWN_NEW' ##NO_TEXT.
  constants C_EVT_OWNSR type STRING value 'OWN_SEARCH' ##NO_TEXT.
  constants C_EVT_OWNOK type STRING value 'OWN_OK' ##NO_TEXT.
  constants C_EVT_OWNCX type STRING value 'OWN_CANCEL' ##NO_TEXT.
  constants C_OWN_ID type STRING value 'IDENTIFICATION_POP' ##NO_TEXT.
  constants C_POP_OWN type STRING value 'OWNER' ##NO_TEXT.
  data C_OWN_NAME type STRING value 'IDENTIFICATION_POP' ##NO_TEXT.
  data C_OWN_EID type STRING value 'EMIRATES_ID_POP' ##NO_TEXT.
  data C_OWN_NAT type STRING value 'NATIONALITY_POP' ##NO_TEXT.
  data C_OWN_SHARE type STRING value 'SHARES_POP' ##NO_TEXT.
  data C_PAY_POLLS type STRING value 'PAY_POLLS' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'PARTNER_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'PARTNER_EMAIL' ##NO_TEXT.
  constants C_DOB type STRING value 'DATE_OF_BIRTH_POP' ##NO_TEXT.

  methods RENDER_ACADEMIC_HOURS
    importing
      value(IO_CTX) type ref to ZIF_RAK_JOURNEY optional
    returning
      value(RV_HTML) type STRING .
ENDCLASS.



CLASS ZCL_D020_MOD_SCHOOL_DAY_LOGIC IMPLEMENTATION.


  METHOD render_academic_hours.
    " REVIEW: this is a structural sketch of the Standard/Ramadhan x
    " Pre-KG/Kindergarten/Cycle1-3 grid seen in the screenshots (school
    " start/end, break 1 start/end, break 2 start/end, lessons, lesson
    " duration per stage-row). Wire real ids/values from
    " io_ctx->get_val( |SCHOOLHOURS_{stage}_{field}| ) once the concrete
    " row-name scheme is agreed with the frontend — the export gives no
    " field-level detail for this control (CONTROL_TYPE=ACADEMIC_HOURS is
    " a native widget, not exported as discrete rows).
    DATA(lv_mode) = io_ctx->get_val( 'SCHOOLHOURS_MODE' ).
    IF lv_mode IS INITIAL.
      lv_mode = 'STANDARD'.
    ENDIF.

    rv_html =
      |<div class="rak-academic-hours">| &&
      |<div class="rak-tabs">| &&
      |<button type="button" onclick="sendPrompt('SCHOOLHOURS_MODE=STANDARD')">Standard</button>| &&
      |<button type="button" onclick="sendPrompt('SCHOOLHOURS_MODE=RAMADHAN')">Ramadhan</button>| &&
      |</div>|.

    LOOP AT VALUE string_table( ( c_stage_prekg ) ( c_stage_kg ) ( c_stage_cyc1 ) ( c_stage_cyc2 ) ( c_stage_cyc3 ) )
         INTO DATA(lv_stage).
      rv_html = rv_html &&
        |<div class="rak-stage-row" data-stage="{ lv_stage }">| &&
        |<input type="checkbox" name="SCHOOLHOURS_{ lv_stage }_ON"> { lv_stage }| &&
        |<label>School</label><input type="time" name="SCHOOLHOURS_{ lv_stage }_SCH_ST">-<input type="time" name="SCHOOLHOURS_{ lv_stage }_SCH_END">| &&
        |<label>Break 1</label><input type="time" name="SCHOOLHOURS_{ lv_stage }_BK1_ST">-<input type="time" name="SCHOOLHOURS_{ lv_stage }_BK1_END">| &&
        |<label>Break 2</label><input type="time" name="SCHOOLHOURS_{ lv_stage }_BK2_ST">-<input type="time" name="SCHOOLHOURS_{ lv_stage }_BK2_END">| &&
        |<label>Lessons</label><input type="number" name="SCHOOLHOURS_{ lv_stage }_LESSONS">| &&
        |<label>Lesson duration</label><input type="number" name="SCHOOLHOURS_{ lv_stage }_DURATION">| &&
        |</div>|.
    ENDLOOP.

    rv_html = rv_html && |</div>|.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
*    CHECK to_upper( iv_name ) = 'LICENSES'.

    " Column order matches the export's LEVEL_CON='T' children of LICENSES:
    " LICENSE, SCHOOL_NAME, ISSUED_AT, EXPIRED_AT.
*    rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).

    " REVIEW: replace with the real school-license read (the export names
    " FM ZFM_EGA_CJ_FW_READ_TABLE_DATAN / context LICENCES — call the actual
    " FM here rather than selecting a placeholder table directly).
*    DATA(partner) = io_ctx->get_val( 'OWNER_BP' ).
*    SELECT license_no, school_name, issued_at, expired_at
*      FROM ztb_dok_licenses                             "#EC CI_NOORDBY
*      WHERE partner = @partner
*      INTO TABLE @DATA(lt_lic).
*
*    LOOP AT lt_lic INTO DATA(ls_lic).
*      APPEND VALUE #( ( |{ ls_lic-license_no }| )
*                      ( |{ ls_lic-school_name }| )
*                      ( |{ ls_lic-issued_at DATE = USER }| )
*                      ( |{ ls_lic-expired_at DATE = USER }| ) ) TO rs_table-rows.
*    ENDLOOP.

*    CALL METHOD super->zif_rak_journey_logic~on_init
*      EXPORTING
*        io_ctx = io_ctx.
**


    CASE to_upper( iv_name ).

*      WHEN 'LICENSES'.
*        rs_data-columns = VALUE #( ( `License` ) ( `School Name` ) ( `Issued At` ) ( `Expired At` ) ).
*
*
*        DATA lv_lic TYPE string.
*        lv_lic =  io_ctx->get_val( 'LICENCE_LIST' ).
*        DATA(lv_name) = io_ctx->get_val( 'SCHOOLNAME' ).
*        DATA(lv_start) = io_ctx->get_val( 'PERMIT_ISSUE' ).
*        DATA(lv_end) = io_ctx->get_val( 'PERMIT_VALIDTO' ).
*        rs_data-rows = VALUE #(
*         ( VALUE zif_rak_journey=>tt_string( ( lv_lic ) ( lv_name ) ( lv_start ) ( lv_end ) ) ) ).

*   CASE to_upper( iv_name ).

      WHEN 'LICENSES'.

*        " License, School name, Issued at, Expired at.
****        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).

*        DATA(lv_license_list) = io_ctx->get_val( 'LICENSES' ).
*        DATA(lv_license_sel) = io_ctx->get_val( 'LICENSE_SEL' ).
        DATA(lt_licenses) = io_ctx->get_grid_data( 'LICENSES' ).
        rs_data = io_ctx->get_backend_table( 'LICENSES' ).

      WHEN 'HOURS'.
        DATA(lt_HOURS) = io_ctx->get_grid_data( 'HOURS' ).
        rs_data = io_ctx->get_backend_table( 'HOURS' ).
        DATA(lv_PREKG) = io_ctx->get_val( 'PREKG' ).
        DATA(lv_KG) = io_ctx->get_val( 'KG' ).
        DATA(lv_CYCLE1) = io_ctx->get_val( 'CYCLE1' ).
        DATA(lv_CYCLE2) = io_ctx->get_val( 'CYCLE2' ).
        DATA(lv_CYCLE3) = io_ctx->get_val( 'CYCLE3' ).
        DATA(prekg_sch_st) = io_ctx->get_val( 'PREKG_SCH_ST' ).
        DATA(prekg_sch_end) = io_ctx->get_val( 'PREKG_SCH_END' ).
        DATA(prekg_bk1_st) = io_ctx->get_val( 'PREKG_BK1_ST' ).
        DATA(prekg_bk1_end) = io_ctx->get_val( 'PREKG_BK1_END' ).
        DATA(prekg_bk2_st) = io_ctx->get_val( 'PREKG_BK2_ST' ).
        DATA(prekg_bk2_end) = io_ctx->get_val( 'PREKG_BK2_END' ).
        DATA(prekg_lessons) = io_ctx->get_val( 'PREKG_LESSONS' ).
        DATA(prekg_duration) = io_ctx->get_val( 'PREKG_DURATION' ).
        DATA(kg_sch_st) = io_ctx->get_val( 'KG_SCH_ST' ).
        DATA(kg_sch_end) = io_ctx->get_val( 'KG_SCH_END' ).
        DATA(kg_bk1_st) = io_ctx->get_val( 'KG_BK1_ST' ).
        DATA(kg_bk1_end) = io_ctx->get_val( 'KG_BK1_END' ).
        DATA(kg_bk2_st) = io_ctx->get_val( 'KG_BK2_ST' ).
        DATA(kg_bk2_end) = io_ctx->get_val( 'KG_BK2_END' ).
        DATA(kg_lessons) = io_ctx->get_val( 'KG_LESSONS' ).
        DATA(kg_duration) = io_ctx->get_val( 'KG_DURATION' ).
        DATA(cycle1_sch_st) = io_ctx->get_val( 'CYCLE1_SCH_ST' ).
        DATA(cycle1_sch_end) = io_ctx->get_val( 'CYCLE1_SCH_END' ).
        DATA(cycle1_bk1_st) = io_ctx->get_val( 'CYCLE1_BK1_ST' ).
        DATA(cycle1_bk1_end) = io_ctx->get_val( 'CYCLE1_BK1_END' ).
        DATA(cycle1_bk2_st) = io_ctx->get_val( 'CYCLE1_BK2_ST' ).
        DATA(cycle1_bk2_end) = io_ctx->get_val( 'CYCLE1_BK2_END' ).
        DATA(cycle1_lessons) = io_ctx->get_val( 'CYCLE1_LESSONS' ).
        DATA(cycle1_duration) = io_ctx->get_val( 'CYCLE1_DURATION' ).
        DATA(cycle2_sch_st) = io_ctx->get_val( 'CYCLE2_SCH_ST' ).
        DATA(cycle2_sch_end) = io_ctx->get_val( 'CYCLE2_SCH_END' ).
        DATA(cycle2_bk1_st) = io_ctx->get_val( 'CYCLE2_BK1_ST' ).
        DATA(cycle2_bk1_end) = io_ctx->get_val( 'CYCLE2_BK1_END' ).
        DATA(cycle2_bk2_st) = io_ctx->get_val( 'CYCLE2_BK2_ST' ).
        DATA(cycle2_bk2_end) = io_ctx->get_val( 'CYCLE2_BK2_END' ).
        DATA(cycle2_lessons) = io_ctx->get_val( 'CYCLE2_LESSONS' ).
        DATA(cycle2_duration) = io_ctx->get_val( 'CYCLE2_DURATION' ).
        DATA(cycle3_sch_st) = io_ctx->get_val( 'CYCLE3_SCH_ST' ).
        DATA(cycle3_sch_end) = io_ctx->get_val( 'CYCLE3_SCH_END' ).
        DATA(cycle3_bk1_st) = io_ctx->get_val( 'CYCLE3_BK1_ST' ).
        DATA(cycle3_bk1_end) = io_ctx->get_val( 'CYCLE3_BK1_END' ).
        DATA(cycle3_bk2_st) = io_ctx->get_val( 'CYCLE3_BK2_ST' ).
        DATA(cycle3_bk2_end) = io_ctx->get_val( 'CYCLE3_BK2_END' ).
        DATA(cycle3_lessons) = io_ctx->get_val( 'CYCLE3_LESSONS' ).
        DATA(cycle3_duration) = io_ctx->get_val( 'CYCLE3_DURATION' ).

        IF lv_prekg IS NOT INITIAL OR lv_kg IS NOT INITIAL OR lv_cycle1 IS NOT INITIAL
          OR lv_cycle2 IS NOT INITIAL OR lv_cycle3 IS NOT INITIAL.
          CLEAR rs_data-rows.
        ENDIF.
        IF lv_prekg IS NOT INITIAL.
          APPEND VALUE #( ( || )
                          ( || )
                          ( || )
                          ( || )
                          ( |{ prekg_sch_st }| )
                          ( |{ prekg_sch_end }| )
                          ( |{ prekg_bk1_st }| )
                          ( |{ prekg_bk1_end }| )
                          ( |{ prekg_bk2_st }| )
                          ( |{ prekg_bk2_st }| )
                          ( |{ prekg_lessons }| )
                          ( |{ prekg_lessons }| )
                          ( |' '| )
                          ( |{ lv_PREKG }| ) ) TO rs_data-rows.
        ENDIF.
        IF lv_kg IS NOT INITIAL.
          APPEND VALUE #( ( |{ lv_KG }| )
                          ( | | )
                          ( | | )
                          ( | | )
                          ( |{ kg_sch_st }| )
                          ( |{ kg_sch_end }| )
                          ( |{ kg_bk1_st }| )
                          ( |{ kg_bk1_end }| )
                          ( |{ kg_bk2_st }| )
                          ( |{ kg_bk2_st }| )
                          ( |{ kg_lessons }| )
                          ( |{ kg_lessons }| )
                          ( | | )
                          ( | | ) ) TO rs_data-rows.
        ENDIF.
        IF lv_cycle1 IS NOT INITIAL.
          APPEND VALUE #( ( |' '| )
                         ( |{ lv_cycle1 }| )
                         ( |' '| )
                         ( |' '| )
                         ( |{ cycle1_sch_st }| )
                         ( |{ cycle1_sch_end }| )
                         ( |{ cycle1_bk1_st }| )
                         ( |{ cycle1_bk1_end }| )
                         ( |{ cycle1_bk2_st }| )
                         ( |{ cycle1_bk2_st }| )
                         ( |{ cycle1_lessons }| )
                         ( |{ cycle1_lessons }| )
                         ( |' '| )
                         ( |' '| ) ) TO rs_data-rows.
        ENDIF.
        IF lv_cycle3 IS NOT INITIAL.
          APPEND VALUE #( ( |' '| )
                         ( |{ lv_cycle3 }| )
                         ( |' '| )
                         ( |' '| )
                         ( |{ cycle3_sch_st }| )
                         ( |{ cycle3_sch_end }| )
                         ( |{ cycle3_bk1_st }| )
                         ( |{ cycle3_bk1_end }| )
                         ( |{ cycle3_bk2_st }| )
                         ( |{ cycle3_bk2_st }| )
                         ( |{ cycle3_lessons }| )
                         ( |{ cycle3_lessons }| )
                         ( |' '| )
                         ( |' '| ) ) TO rs_data-rows.
        ENDIF.
        IF lv_cycle2 IS NOT INITIAL.
          APPEND VALUE #( ( |' '| )
                         ( |' '| )
                         ( |{ lv_cycle2 }| )
                         ( |' '| )
                         ( |{ cycle2_sch_st }| )
                         ( |{ cycle2_sch_end }| )
                         ( |{ cycle2_bk1_st }| )
                         ( |{ cycle2_bk1_end }| )
                         ( |{ cycle2_bk2_st }| )
                         ( |{ cycle2_bk2_st }| )
                         ( |{ cycle2_lessons }| )
                         ( |{ cycle2_lessons }| )
                         ( |' '| )
                         ( |' '| ) ) TO rs_data-rows.

        ENDIF.
****        REFRESH rs_data-columns[].
****        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).


*        IF lv_license_list IS INITIAL.
**          RETURN.
*        ENDIF.

*        DATA(lr_school) = NEW zcl_dok_appln_handler_api( ).
*
*        DATA(lv_login_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
*
*        lr_school->license_search(
*      EXPORTING
*        iv_case_type    = ''
*        iv_bp_applicant = '3000124165'
**            iv_bp_applicant = lv_login_bp
*      IMPORTING
*        et_lic_no_list  = DATA(lt_list) ).
*
*        IF lt_list IS NOT INITIAL.
*          LOOP AT lt_list INTO DATA(ls_list).
*            DATA(lv_recnnr) = ls_list-recnnr.
*            SHIFT lv_recnnr LEFT DELETING LEADING '0'.
*            APPEND VALUE #( ( |{ lv_recnnr }| )
*                            ( |{ ls_list-recntxt }|   )
*                            ( |{ ls_list-validfrom DATE = USER }|     )
*                            ( |{ ls_list-validto DATE = USER }|        ) ) TO rs_data-rows.
*          ENDLOOP.
*          DELETE lt_list WHERE recnnr NE lv_license_list.
*        ELSE.



*      WHEN 'OWNERSTABLE'.
*        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile number` ) ( `E-mail` ) ).
    ENDCASE.

  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_FIELDS.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_FIELDS
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_FIELDS =
*    .
  endmethod.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch keys with no backend meaning.
**    DELETE ct_kv WHERE key = 'DECLARE'.
**    DELETE ct_kv WHERE key = 'LICENSE_SEL'.
**    DELETE ct_kv WHERE key = 'SCHOOLHOURS_MODE'.

    " REVIEW: fold the per-stage SCHOOLHOURS_* scratch keys captured by
    " render_academic_hours( ) into the real GS_DATA-SCHOOL_TIME[] rows the
    " backend expects, then delete the scratch keys — placeholder shown for
    " one stage only; repeat/loop over all five once the backend structure
    " is confirmed.
    " ct_kv = VALUE #( BASE ct_kv
    "   ( key = 'GS_DATA-SCHOOL_TIME-PREKG-SCH_ST' value = ct_kv[ key = 'SCHOOLHOURS_PREKG_SCH_ST' ]-value ) ).
**    DELETE ct_kv WHERE key CP 'SCHOOLHOURS_*'.

**io_ctx->set_val( iv_name = 'HOURS' iv_value = iv_id ).
    DATA(ls_g) = io_ctx->get_grid_data( 'HOURS' ).
    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.
    DATA(lt_new_row) = zcl_rak_journey_util=>blank_row( ls_g-columns ).

    DATA(lv_prekg) = io_ctx->get_val( 'PREKG' ).
    IF lv_prekg IS NOT INITIAL.
      zcl_rak_journey_util=>put_cell(
         EXPORTING it_cols = ls_g-columns iv_name = 'PREKG_1'
                   iv_val  = io_ctx->get_val( 'PREKG' )
         CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_ST_5'
                 iv_val  = io_ctx->get_val( 'PREKG_SCH_ST' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_END_5'
                  iv_val  = io_ctx->get_val( 'PREKG_SCH_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_ST_5'
                  iv_val  = io_ctx->get_val( 'PREKG_BK1_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_END_5'
                  iv_val  = io_ctx->get_val( 'PREKG_BK1_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_ST_5'
                  iv_val  = io_ctx->get_val( 'PREKG_BK2_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_END_5'
                  iv_val  = io_ctx->get_val( 'PREKG_BK2_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSONS_5'
                  iv_val  = io_ctx->get_val( 'PREKG_LESSONS' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSON_DURAT_5'
                  iv_val  = io_ctx->get_val( 'PREKG_DURATION' )
        CHANGING  ct_row  = lt_new_row ).
      APPEND lt_new_row TO ls_new-rows.
      io_ctx->set_grid_data( iv_field = 'HOURS' is_data = ls_new ).
      CLEAR: lt_new_row.
    ENDIF.

    lt_new_row = zcl_rak_journey_util=>blank_row( ls_g-columns ).
    DATA(lv_kg) = io_ctx->get_val( 'KG' ).
    IF lv_kg IS NOT INITIAL.
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'KINDERGARTEN_1'
                 iv_val  = io_ctx->get_val( 'KG' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_ST_5'
                 iv_val  = io_ctx->get_val( 'KG_SCH_ST' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_END_5'
                  iv_val  = io_ctx->get_val( 'KG_SCH_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_ST_5'
                  iv_val  = io_ctx->get_val( 'KG_BK1_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_END_5'
                  iv_val  = io_ctx->get_val( 'KG_BK1_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_ST_5'
                  iv_val  = io_ctx->get_val( 'KG_BK2_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_END_5'
                  iv_val  = io_ctx->get_val( 'KG_BK2_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSONS_5'
                  iv_val  = io_ctx->get_val( 'KG_LESSONS' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSON_DURAT_5'
                  iv_val  = io_ctx->get_val( 'KG_DURATION' )
        CHANGING  ct_row  = lt_new_row ).
      APPEND lt_new_row TO ls_new-rows.
      io_ctx->set_grid_data( iv_field = 'HOURS' is_data = ls_new ).
      CLEAR: lt_new_row.
    ENDIF.

    lt_new_row = zcl_rak_journey_util=>blank_row( ls_g-columns ).
    DATA(lv_cycle1) = io_ctx->get_val( 'CYCLE1' ).
    IF lv_cycle1 IS NOT INITIAL.
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'CYCLE_1_1'
                  iv_val  = io_ctx->get_val( 'CYCLE1' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_SCH_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_SCH_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_BK1_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_BK1_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_BK2_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_BK2_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSONS_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_LESSONS' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSON_DURAT_5'
                  iv_val  = io_ctx->get_val( 'CYCLE1_DURATION' )
        CHANGING  ct_row  = lt_new_row ).
      APPEND lt_new_row TO ls_new-rows.
      io_ctx->set_grid_data( iv_field = 'HOURS' is_data = ls_new ).
      CLEAR: lt_new_row.
    ENDIF.

    lt_new_row = zcl_rak_journey_util=>blank_row( ls_g-columns ).
    DATA(lv_cycle2) = io_ctx->get_val( 'CYCLE2' ).
    IF lv_cycle2 IS NOT INITIAL.
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'CYCLE_2_1'
                 iv_val  = io_ctx->get_val( 'CYCLE2' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_ST_5'
                 iv_val  = io_ctx->get_val( 'CYCLE2_SCH_ST' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_SCH_END' )
        CHANGING  ct_row  = lt_new_row ).

      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_BK1_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_BK1_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_BK2_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_BK2_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSONS_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_LESSONS' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSON_DURAT_5'
                  iv_val  = io_ctx->get_val( 'CYCLE2_DURATION' )
        CHANGING  ct_row  = lt_new_row ).
      APPEND lt_new_row TO ls_new-rows.
      io_ctx->set_grid_data( iv_field = 'HOURS' is_data = ls_new ).
      CLEAR: lt_new_row.
    ENDIF.

    lt_new_row = zcl_rak_journey_util=>blank_row( ls_g-columns ).
    DATA(lv_cycle3) = io_ctx->get_val( 'CYCLE3' ).
    IF lv_cycle3 IS NOT INITIAL.
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'CYCLE_3_1'
                 iv_val  = io_ctx->get_val( 'CYCLE3' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
       EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_ST_5'
                 iv_val  = io_ctx->get_val( 'CYCLE3_SCH_ST' )
       CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'SCHOOL_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_SCH_END' )
        CHANGING  ct_row  = lt_new_row ).

      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_BK1_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_1_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_BK1_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_ST_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_BK2_ST' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'BK_2_END_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_BK2_END' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSONS_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_LESSONS' )
        CHANGING  ct_row  = lt_new_row ).
      zcl_rak_journey_util=>put_cell(
        EXPORTING it_cols = ls_g-columns iv_name = 'LESSON_DURAT_5'
                  iv_val  = io_ctx->get_val( 'CYCLE3_DURATION' )
        CHANGING  ct_row  = lt_new_row ).
      APPEND lt_new_row TO ls_new-rows.
      io_ctx->set_grid_data( iv_field = 'HOURS' is_data = ls_new ).
      CLEAR: lt_new_row.
    ENDIF.

**    zcl_rak_journey_util=>put_cell(
**      EXPORTING it_cols = ls_g-columns iv_name = 'RAMADAN_1'
**                iv_val  = io_ctx->get_val( 'TELEPHONE_POP' )
**      CHANGING  ct_row  = lt_new_row ).

**IF ls_g is NOT INITIAL.
**
**ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*    super->zif_rak_journey_logic~on_before_tables(
*      EXPORTING
*        io_ctx    = io_ctx
*      CHANGING
*        ct_tables = ct_tables
*    ).

     DATA(lv_sel) = io_ctx->get_val( 'LIC_SELECT' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel.
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    " ROWPICK_LICENSES fires when a license row is selected in step 1.
    " The engine writes the row key into the field named in
    " zrak_t_jny_fld-default for LICENSES, i.e. LICENSE_SEL — this method
    " just needs to react to it if any derived context must be refreshed.
*****    CHECK to_upper( iv_field ) = 'LICENSE_SEL'.
*****
*****    DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
*****    IF lv_license IS INITIAL.
*****      RETURN.
*****    ENDIF.
****    DATA(lv_license) = '1000116563'.
****
****    DATA lv_recnnr TYPE recnnumber.
*****    DATA lt_school  TYPE TY_DOK_APPLN.
****    lv_recnnr = CONV recnnumber( lv_license ).
****
****    DATA(lo_school) = NEW zcl_dok_appln_handler_api( ).
****
*****    lo_school->school_details(
*****      EXPORTING
*****        iv_recnnr          = lv_recnnr
******        iv_form_multilangu = abap_false
*****      IMPORTING
*****        et_school_dt       = lt_school
*****        et_return          = DATA(lt_return)
*****    ).
****
****    lo_school->school_details(
****EXPORTING
**** iv_recnnr          = lv_recnnr
**** iv_form_multlangu = abap_false
****IMPORTING
**** et_school_dt       = DATA(ls_school_dt)
**** et_return          = DATA(lt_return)
****).
****
****    READ TABLE ls_school_dt-school
****      INTO DATA(ls_school)
****      INDEX 1.
****
*****      CALL METHOD NEW zcl_dok_appln_handler_api( )->SCHOOL_DETAILS
*****        EXPORTING
*****          iv_recnbr          = lv_recnbr
*****          iv_form_multilangu = abap_false
*****        IMPORTING
*****          et_school_dt       = DATA(lt_school)
*****          et_return          = DATA(lt_return).
****
*****    READ TABLE lt_school INTO DATA(ls_school) INDEX 1.
****
****    IF sy-subrc <> 0.
****      RETURN.
****    ENDIF.
****
****    "PreKG
****    io_ctx->set_val(
****      iv_name  = 'PREKG'
****      iv_value = CONV #( ls_school-prekg )
****    ).
****
****    IF ls_school-prekg = 'X'.
****
****      io_ctx->set_val(
****        iv_name  = 'PREKG'
****        iv_value = 'X'
****      ).
****    ELSE.
****      io_ctx->set_val(
****        iv_name  = 'PREKG'
****        iv_value = ''
****      ).
****    ENDIF.
****
****    "Kindergarten
****    io_ctx->set_val(
****      iv_name  = 'KG'
****      iv_value = CONV #( ls_school-kindergarten )
****    ).
****
****    IF ls_school-kindergarten = 'X'.
****
****      io_ctx->set_val(
****        iv_name  = 'KG'
****        iv_value = 'X'
****      ).
****    ELSE.
****      io_ctx->set_val(
****        iv_name  = 'KG'
****        iv_value = ''
****      ).
****    ENDIF.
****
****    "Cycle 1
****    io_ctx->set_val(
****      iv_name  = 'CYCLE1'
****      iv_value = CONV #( ls_school-cycle_1 )
****    ).
****
****    IF ls_school-cycle_1 = 'X'.
****
****      io_ctx->set_val(
****        iv_name  = 'CYCLE1'
****        iv_value = 'X'
****      ).
****    ELSE.
****      io_ctx->set_val(
****        iv_name  = 'CYCLE1'
****        iv_value = ''
****      ).
****    ENDIF.
****
****    "Cycle 2
****    io_ctx->set_val(
****      iv_name  = 'CYCLE2'
****      iv_value = CONV #( ls_school-cycle_2 )
****    ).
****
****    IF ls_school-cycle_2 = 'X'.
****
****      io_ctx->set_val(
****        iv_name  = 'CYCLE2'
****        iv_value = 'X'
****      ).
****    ELSE.
****      io_ctx->set_val(
****        iv_name  = 'CYCLE2'
****        iv_value = ''
****      ).
****    ENDIF.
****
****    "Cycle 3
****    io_ctx->set_val(
****      iv_name  = 'CYCLE3'
****      iv_value = CONV #( ls_school-cycle_3 )
****    ).
****
****    IF ls_school-cycle_3 = 'X'.
****
****      io_ctx->set_val(
****        iv_name  = 'CYCLE3'
****        iv_value = 'X'
****      ).
****    ELSE.
****      io_ctx->set_val(
****        iv_name  = 'CYCLE3'
****        iv_value = ''
****      ).
****    ENDIF.
****
****    DATA lv_show_time TYPE abap_bool.
****
****    CLEAR lv_show_time.
****
****    IF ls_school-prekg        = 'X'
****    OR ls_school-kindergarten = 'X'
****    OR ls_school-cycle_1      = 'X'
****    OR ls_school-cycle_2      = 'X'
****    OR ls_school-cycle_3      = 'X'.
****
****      lv_show_time = abap_true.
****
****    ENDIF.
****
****    "One common flag for complete Time section
****    io_ctx->set_val(
****      iv_name  = 'SHOW_TIME'
****      iv_value = CONV #( lv_show_time )
****    ).
****
*****ENDCASE.


    " Nothing further to derive here — the step 2 context header (License
    " number / Issued / Expired) is chrome bound directly to LICENSE_SEL
    " (see NOTE 5 in the load report). If that chrome does not exist,
    " set_val the CTX* display fields here instead.
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

*    CHECK iv_step = 1.   " zero-based: step 2 "School Day" in the wizard

*    DATA(lv_any_on) = abap_false.
*    LOOP AT VALUE string_table( ( c_stage_prekg ) ( c_stage_kg ) ( c_stage_cyc1 ) ( c_stage_cyc2 ) ( c_stage_cyc3 ) )
*         INTO DATA(lv_stage).
*      IF io_ctx->get_val( |SCHOOLHOURS_{ lv_stage }_ON| ) = abap_true.
*        lv_any_on = abap_true.
*      ENDIF.
*    ENDLOOP.
*
*    IF lv_any_on = abap_false.
*      rt = VALUE #( ( type = 'Error' text = 'Select at least one education stage and enter its school hours.' ) ).
*    ENDIF.
*
*    DATA(lt_data) = io_ctx->get_grid_data( 'LICENSES' ).
*    DATA(lv_sel_lic) = io_ctx->get_val( 'LIC_SEL' ).

*    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs_data>) WHERE .
*
*    ENDLOOP.



  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

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

*      io_ctx->set_val( iv_name = 'OWNER_BP' iv_value = |{ lv_loginbp }| ).
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).

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

****    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
*****    DATA(user_data) = io_ctx->get_val( iv_name = 'PARAM1' ).
*****    user_data = ''.
****    zcl_ega_cj_utility=>get_bp(
****      EXPORTING
****        qv_key  = user_data
****      IMPORTING
****        loginbp = DATA(loginbp)
****        rolebp  = DATA(rolebp)
****        role    = DATA(role)
****    ).
****
****    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
****
*****    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*****   The signed-in citizen, read from the business partner register. What stood
*****   here was a fixed name and Emirates ID, written AFTER the real read, so every
*****   applicant saw and posted the same test person.
****    NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
****      EXPORTING
****        iv_bp_id      = CONV bu_partner( loginbp )
****      IMPORTING
****        es_bp_details = DATA(ls_bp_real) ).
****    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = COND #(
****      WHEN sy-langu <> 'E' AND ls_bp_real-bp_name_ar IS NOT INITIAL
****      THEN CONV string( ls_bp_real-bp_name_ar )
****      ELSE CONV string( ls_bp_real-bp_name ) ) ).
****    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_bp_real-emirates_id ) ).
*****    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
****
*****    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
****    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.
    super->zif_rak_journey_logic~on_render_end(
      io_ctx  = io_ctx
      io_view = io_view
    ).
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START.
*SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START(
*    IO_CTX  = IO_CTX
*    IO_VIEW = IO_VIEW
*       ).
  endmethod.


  METHOD zif_rak_journey_logic~on_value_help.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .
    DATA ls_rt TYPE zif_rak_journey=>ty_option.

    CASE iv_field.
      WHEN 'LICENCE_LIST'.
        DATA(lr_school) = NEW zcl_dok_appln_handler_api( ).
        DATA(lv_login_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
        lr_school->license_search(
          EXPORTING
            iv_bp_applicant = '3000124165'
*            iv_bp_applicant = lv_login_bp
          IMPORTING
            et_lic_no_list  = DATA(lt_list) ).
        DATA: ls_list1 LIKE LINE OF lt_list.

        ls_list1-recnnr = '1234'.
        ls_list1-recntxt = 'test'.
        ls_list1-recnbeg    = '20260101'.
        ls_list1-recnendabs = '20261231'.
        APPEND ls_list1 TO lt_list.

        LOOP AT lt_list INTO DATA(ls_list).
          CLEAR ls_rt.
          ls_rt-key =  ls_list-recnnr.
          SHIFT ls_rt-key LEFT DELETING LEADING '0'.
          ls_rt-text = ls_list-recntxt.
          APPEND ls_rt TO rt.
        ENDLOOP.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
*   THE BASE RENDER_FIELD IS THE PAYMENT CARD. It reads the fee rows from
*   GET_BACKEND_TABLE( PAYFEE ), falls back to ZCL_RAK_PAY_ENGINE=>GET_FEES( )
*   with a visible warning when no /QNV/SB_UI_DEFIN row exists, and calls
*   PAY_RENDER( ) with the polling flag. An empty redefinition REPLACES all of
*   that, so this journey lost its fee card without anything being reported.
*
*   Chaining is safe on every other field: the base opens with
*   rv_done = abap_false and CHECKs is_field-name = c_pay_field, so for
*   anything that is not PAYFEE it does nothing and returns false, which is
*   exactly what an unclaimed field should return.
*
*   The commented-out SCHOOLHOURS attempt below was written against an older
*   signature - IV_NAME, RV_HTML and RV_HANDLED are none of them parameters of
*   this method any more (it is IO_CTX, IO_FORM, IS_FIELD, returning RV_DONE),
*   so it could not have compiled as written. Reviving it means rewriting it
*   against the current signature and returning RV_DONE, and it has to leave
*   the PAYFEE case to super->.
    rv_done = super->zif_rak_journey_logic~render_field( io_ctx   = io_ctx
                                                        io_form  = io_form
                                                        is_field = is_field ).
  ENDMETHOD.
ENDCLASS.
