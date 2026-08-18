CLASS zcl_d026_stud_repor_card_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS zif_rak_journey_logic~get_table
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_before_post
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_change
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_custom_validate
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_init
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_search
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_value_help
        REDEFINITION .
  PROTECTED SECTION.

PRIVATE SECTION.

  TYPES:
*   One MOE payload per student. Held in the model as well as on the instance
*   because the instance does not survive the round trip and ON_VALUE_HELP is
*   called from RENDER_ONE on EVERY render, for both dropdowns. Without the
*   cache that is three MOE calls per round trip instead of one per search.
    BEGIN OF ty_pair,
      key  TYPE string,
      text TYPE string,
    END OF ty_pair .
  TYPES:
    tt_pair TYPE STANDARD TABLE OF ty_pair WITH DEFAULT KEY .
  TYPES:
    BEGIN OF ty_card,
      student_nm  TYPE string,
      emirates_id TYPE string,
      sis_id      TYPE string,
      school      TYPE string,
      acad_year   TYPE string,
      cycle       TYPE string,
      grade_level TYPE string,
      curriculum  TYPE string,
      phone       TYPE string,
      nationality TYPE string,
      email       TYPE string,
    END OF ty_card .
  TYPES:
    BEGIN OF ty_cache,
      sis   TYPE string,
      card  TYPE ty_card,
      years TYPE tt_pair,
    END OF ty_cache .
  TYPES:
    BEGIN OF ty_enrol,
      sis         TYPE zst_cs_ega_student_bp-studentid,
      student_nm  TYPE string,
      emirates_id TYPE string,
      acad_year   TYPE numc4,
      school_id   TYPE zst_cs_ega_student_bp-schoolid,
      school_txt  TYPE string,
      curriculum  TYPE zdt_dok_sh_cur_m-curriculum,
      cycle       TYPE string,
      grade_level TYPE string,
      mobile      TYPE string,
      email       TYPE string,
    END OF ty_enrol .
  TYPES:
    tt_enrol TYPE STANDARD TABLE OF ty_enrol WITH DEFAULT KEY .
  TYPES:
    BEGIN OF ty_cache1,
      sis  TYPE string,
      rows TYPE tt_enrol,
    END OF ty_cache1 .

  CONSTANTS c_sep TYPE char1 VALUE '|' ##NO_TEXT.
  CONSTANTS c_cache_field TYPE string VALUE 'ENROL_CACHE' ##NO_TEXT.
  CONSTANTS c_bukrs TYPE bukrs VALUE 'RDOK' ##NO_TEXT.
  CONSTANTS c_f_student TYPE string VALUE 'STUDENT_1' ##NO_TEXT.
  CONSTANTS c_f_year TYPE string VALUE 'ACADEMIC_YEAR' ##NO_TEXT.
  CONSTANTS c_f_term TYPE string VALUE 'TERM_ID' ##NO_TEXT.
  CONSTANTS c_cache TYPE string VALUE 'MOE_CACHE' ##NO_TEXT.
  DATA ms_cache1 TYPE ty_cache1 .
  DATA ms_cache TYPE ty_cache .
  "! Single entry point for enrolment data. Serves from the instance memo, then
  "! from the model field, and only reaches the SIS when both miss.
  METHODS enrol
    IMPORTING
      !io_ctx         TYPE REF TO zif_rak_journey
      !iv_force       TYPE abap_bool DEFAULT abap_false
    RETURNING
      VALUE(rt_enrol) TYPE tt_enrol .
  "! The one and only SIS call in this class.
  METHODS read_sis
    IMPORTING
      !iv_sis         TYPE clike
    RETURNING
      VALUE(rt_enrol) TYPE tt_enrol .
  "! Resolve the selected ACADEMICYEARSCHOOL key back to its cached enrolment row.
  METHODS selected_enrol
    IMPORTING
      !io_ctx         TYPE REF TO zif_rak_journey
    EXPORTING
      !es_enrol       TYPE ty_enrol
    RETURNING
      VALUE(rv_found) TYPE abap_bool .
  "! Composite dropdown key. The school half is what lets the term step know
  "! which curriculum applies without a second lookup.
  METHODS year_key
    IMPORTING
      !is_enrol     TYPE ty_enrol
    RETURNING
      VALUE(rv_key) TYPE string .
  METHODS fill_card_1
    IMPORTING
      !io_ctx   TYPE REF TO zif_rak_journey
      !is_enrol TYPE ty_enrol .
  "! Blank the card and everything downstream of the search.
  METHODS clear_downstream
    IMPORTING
      !io_ctx TYPE REF TO zif_rak_journey .
  "! Append one label/value pair as a row. Uses LIKE LINE OF so the row type
  "! is taken from the table itself rather than inferred - a nested VALUE #( )
  "! cannot derive the inner row type from a returning parameter.
  METHODS add_row
    IMPORTING
      !iv_label TYPE string
      !iv_value TYPE string
    CHANGING
      !ct_rows  TYPE zif_rak_journey=>ty_table-rows .
  METHODS moe
    IMPORTING
      !io_ctx        TYPE REF TO zif_rak_journey
      !iv_force      TYPE abap_bool DEFAULT abap_false
    RETURNING
      VALUE(rs_data) TYPE ty_cache .
  METHODS moe_options
    IMPORTING
      !iv_sis        TYPE clike
      !iv_year       TYPE clike OPTIONAL
    RETURNING
      VALUE(rt_pair) TYPE tt_pair .
  METHODS moe_student
    IMPORTING
      !iv_sis        TYPE clike
    RETURNING
      VALUE(rs_card) TYPE ty_card .
  METHODS fill_card
    IMPORTING
      !io_ctx  TYPE REF TO zif_rak_journey
      !is_card TYPE ty_card .
ENDCLASS.



CLASS ZCL_D026_STUD_REPOR_CARD_LOGIC IMPLEMENTATION.


  METHOD add_row.
    DATA ls_row LIKE LINE OF ct_rows.

    CLEAR ls_row.
    APPEND iv_label TO ls_row.
    APPEND iv_value TO ls_row.
    APPEND ls_row TO ct_rows.
  ENDMETHOD.


  METHOD clear_downstream.
*---------------------------------------------------------------------------------------*
* Called whenever the student changes or the search finds nothing. Without this a
* second search leaves the previous student's year and term selectable.
*---------------------------------------------------------------------------------------*
    io_ctx->set_val( iv_name = 'STUDENTNAME' iv_value = space ).
    io_ctx->set_val( iv_name = 'STUDENTEID' iv_value = space ).
    io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = space ).
    io_ctx->set_val( iv_name = 'ACADEMICYEAR' iv_value = space ).
    io_ctx->set_val( iv_name = 'CYCLE' iv_value = space ).
    io_ctx->set_val( iv_name = 'GRADELEVEL' iv_value = space ).
    io_ctx->set_val( iv_name = 'CURRICULUM' iv_value = space ).
    io_ctx->set_val( iv_name = 'STUDENTMOBILE' iv_value = space ).
    io_ctx->set_val( iv_name = 'STUDENTEMAIL' iv_value = space ).
    io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
    io_ctx->set_val( iv_name = 'TERM' iv_value = space ).
  ENDMETHOD.


  METHOD enrol.
*---------------------------------------------------------------------------------------*
* Three ways out, cheapest first. The instance memo covers repeated calls inside one
* round trip; the model field covers later round trips. The SIS is reached only on a
* forced read or a genuine miss, so a full search-to-submit journey costs one call
* per Search press and nothing else.
*
* The cached SIS id is compared on every hit. A stale row for a different student is
* discarded rather than served.
*---------------------------------------------------------------------------------------*
*    DATA ls_cache TYPE ty_cache.
*
*    DATA(lv_sis) = io_ctx->get_val( 'STUDENTSEARCH' ).
*
*    IF lv_sis IS INITIAL.
*      CLEAR ms_cache.
*      RETURN.
*    ENDIF.
*
*    IF iv_force = abap_false AND ms_cache-sis = lv_sis.
*      rt_enrol = ms_cache-rows.
*      RETURN.
*    ENDIF.
*
*    IF iv_force = abap_false.
*      DATA(lv_json) = io_ctx->get_val( c_cache_field ).
*      IF lv_json IS NOT INITIAL.
*        TRY.
*            /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_cache ).
*          CATCH cx_root.
*            CLEAR ls_cache.
*        ENDTRY.
*        IF ls_cache-sis = lv_sis AND ls_cache-rows IS NOT INITIAL.
*          ms_cache = ls_cache.
*          rt_enrol = ms_cache-rows.
*          RETURN.
*        ENDIF.
*      ENDIF.
*    ENDIF.
*
*    CLEAR ms_cache.
*    ms_cache-sis  = lv_sis.
*    ms_cache-rows = read_sis( lv_sis ).
*
*    io_ctx->set_val( iv_name  = c_cache_field
*                     iv_value = /ui2/cl_json=>serialize( ms_cache ) ).
*
*    rt_enrol = ms_cache-rows.
  ENDMETHOD.


  METHOD fill_card.
*    io_ctx->set_val( iv_name = 'STUDENTNAME' iv_value = |{ is_enrol-student_nm }| ).
*    io_ctx->set_val( iv_name = 'STUDENTEID' iv_value = |{ is_enrol-emirates_id }| ).
*    io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = |{ is_enrol-school_txt }| ).
*    io_ctx->set_val( iv_name = 'ACADEMICYEAR' iv_value = |{ is_enrol-acad_year }| ).
*    io_ctx->set_val( iv_name = 'CYCLE' iv_value = |{ is_enrol-cycle }| ).
*    io_ctx->set_val( iv_name = 'GRADELEVEL' iv_value = |{ is_enrol-grade_level }| ).
*    io_ctx->set_val( iv_name = 'CURRICULUM' iv_value = |{ is_enrol-curriculum }| ).
*    io_ctx->set_val( iv_name = 'STUDENTMOBILE' iv_value = |{ is_enrol-mobile }| ).
*    io_ctx->set_val( iv_name = 'STUDENTEMAIL' iv_value = |{ is_enrol-email }| ).

    io_ctx->set_val( iv_name = 'STUD_NAME'    iv_value = is_card-student_nm ).
    io_ctx->set_val( iv_name = 'STUD_EID'     iv_value = is_card-emirates_id ).
    io_ctx->set_val( iv_name = 'STUD_SIS'     iv_value = is_card-sis_id ).
    io_ctx->set_val( iv_name = 'STUD_SCHOOL'  iv_value = is_card-school ).
    io_ctx->set_val( iv_name = 'STUD_ACADYR'  iv_value = is_card-acad_year ).
    io_ctx->set_val( iv_name = 'STUD_CYCLE'   iv_value = is_card-cycle ).
    io_ctx->set_val( iv_name = 'STUD_GRADE'   iv_value = is_card-grade_level ).
    io_ctx->set_val( iv_name = 'STUD_CURR'    iv_value = is_card-curriculum ).
    io_ctx->set_val( iv_name = 'STUD_PHONE'   iv_value = is_card-phone ).
    io_ctx->set_val( iv_name = 'STUD_NATION'  iv_value = is_card-nationality ).
    io_ctx->set_val( iv_name = 'STUD_EMAIL'   iv_value = is_card-email ).
  ENDMETHOD.


  METHOD FILL_CARD_1.
*    io_ctx->set_val( iv_name = 'STUDENTNAME' iv_value = |{ is_enrol-student_nm }| ).
*    io_ctx->set_val( iv_name = 'STUDENTEID' iv_value = |{ is_enrol-emirates_id }| ).
*    io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = |{ is_enrol-school_txt }| ).
*    io_ctx->set_val( iv_name = 'ACADEMICYEAR' iv_value = |{ is_enrol-acad_year }| ).
*    io_ctx->set_val( iv_name = 'CYCLE' iv_value = |{ is_enrol-cycle }| ).
*    io_ctx->set_val( iv_name = 'GRADELEVEL' iv_value = |{ is_enrol-grade_level }| ).
*    io_ctx->set_val( iv_name = 'CURRICULUM' iv_value = |{ is_enrol-curriculum }| ).
*    io_ctx->set_val( iv_name = 'STUDENTMOBILE' iv_value = |{ is_enrol-mobile }| ).
*    io_ctx->set_val( iv_name = 'STUDENTEMAIL' iv_value = |{ is_enrol-email }| ).
*


  ENDMETHOD.


  METHOD moe.
    DATA ls_cache TYPE ty_cache.
    DATA lv_json  TYPE string.

    DATA(lv_sis) = io_ctx->get_val( c_f_student ).

    IF lv_sis IS INITIAL.
      CLEAR ms_cache.
      RETURN.
    ENDIF.

    IF iv_force = abap_false AND ms_cache-sis = lv_sis.
      rs_data = ms_cache.
      RETURN.
    ENDIF.

    IF iv_force = abap_false.
      lv_json = io_ctx->get_val( c_cache ).
      IF lv_json IS NOT INITIAL.
        TRY.
            /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_cache ).
          CATCH cx_root.
            CLEAR ls_cache.
        ENDTRY.
        IF ls_cache-sis = lv_sis AND ls_cache-years IS NOT INITIAL.
          ms_cache = ls_cache.
          rs_data  = ms_cache.
          RETURN.
        ENDIF.
      ENDIF.
    ENDIF.

    CLEAR ms_cache.
    ms_cache-sis = lv_sis.

    ms_cache-card  = moe_student( lv_sis ).
    ms_cache-years = moe_options( lv_sis ).

    io_ctx->set_val( iv_name  = c_cache
                     iv_value = /ui2/cl_json=>serialize( ms_cache ) ).

    rs_data = ms_cache.
  ENDMETHOD.


  METHOD moe_options.
*---------------------------------------------------------------------------------------*
* ZFE_CJ_STUDENT_SCHOOL is the generic /QNV combobox source. It takes no named
* business parameters at all: CT_FIELDS carries the names of the fields that drive
* the list and CT_VALUES their current values, paired by position, and it decides
* which list to build from what it is given.
*
* The tokens are the TECHNICAL names, not the field names. The FM's own CASE tests
* for GS_DATA-ALMANAL-STUDENT_ID and GS_DATA-ALMANAL-ACADEMIC_YEAR, so the legacy
* framework translates DATA2 through TECHNICAL_NAME before calling. Passing the
* field names STUDENT_1 / ACADEMIC_YEAR falls through the CASE, leaves the FM's
* LV_STUDENT_ID initial, and its CHECK returns an empty list with no error.
*
* Blank IV_YEAR asks for the year list; a supplied IV_YEAR asks for that year's
* terms. That is the FM's own branch, not a convention imposed here.
*
* /QNV/COMBOBOX_STRING_OUTPUT is the generic ten-column string row - FIELD1 to
* FIELD10, no named components at all. Position carries the meaning, the same
* convention the bridge uses when it reads a grid with 'FIELD' && LIST_SEQUENCE
* in ZCL_EGA_CJ_DOK_ABS->READ. FIELD1 is the key, FIELD2 the display text.
*
* FIELD1 / FIELD2 confirmed from the FM source: for the year list FIELD1 is
* ACADEMIC_YEAR and FIELD2 is DISP_ACADEMIC_YEAR + '/' + the school name in the
* logon language; for the term list FIELD1 is 1/2/3/5 and FIELD2 the caption.
* Term 5 - Final grades - is always returned; 1 to 3 only when the school's
* curriculum is '08'.
*
* FIELD2 falls back to FIELD1 rather than rendering a blank line: a combobox whose
* text is empty shows nothing and looks like a failed read, and a visible raw key
* is at least something the citizen can report.
*---------------------------------------------------------------------------------------*
    DATA lt_fields TYPE /asu/string_t.
    DATA lt_values TYPE /asu/string_t.
    DATA lt_out    TYPE /qnv/combobox_string_output_tt.
    DATA lv_sis    TYPE string.
    DATA lv_year   TYPE string.

    lv_sis  = iv_sis.
    lv_year = iv_year.
    IF lv_sis IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_year IS NOT INITIAL.
      APPEND 'GS_DATA-ALMANAL-ACADEMIC_YEAR' TO lt_fields.
      APPEND lv_year                         TO lt_values.
    ENDIF.
    APPEND 'GS_DATA-ALMANAL-STUDENT_ID' TO lt_fields.
    APPEND lv_sis                       TO lt_values.

    CALL FUNCTION 'ZFE_CJ_STUDENT_SCHOOL'
      IMPORTING
        et_values = lt_out
      CHANGING
        ct_fields = lt_fields
        ct_values = lt_values.

    LOOP AT lt_out ASSIGNING FIELD-SYMBOL(<ls_out>).
      APPEND VALUE #( key  = <ls_out>-field1
                      text = COND #( WHEN <ls_out>-field2 IS NOT INITIAL
                                     THEN <ls_out>-field2 ELSE <ls_out>-field1 ) ) TO rt_pair.
    ENDLOOP.
  ENDMETHOD.


  METHOD moe_student.
*---------------------------------------------------------------------------------------*
* The grey card. ZCL_EGA_CJ_DOK_ABS->CASE_MAPPING calls this same function module the
* same way, so the signature and STUDENTID / NATIONALID / SCHOOLID are certain.
*
* UNVERIFIED - the rest of ZST_CS_EGA_STUDENT_BP. SCHOOL_NAME, ACADEMIC_YEAR, CYCLE,
* GRADE_LEVEL, CURRICULUM, MOBILE, NATIONALITY and EMAIL are read off the legacy
* screen, not off the DDIC, because the control that drew them was EXTENDED = X and
* the export describes none of its inner fields. SE11 on ZST_CS_EGA_STUDENT_BP names
* the real ones; delete any line here that has no counterpart rather than guessing
* a second time.
*
* NOT filtered on ISBLOCKED or EXIT_DATE. ZFE_CJ_STUDENT_SCHOOL reads the same table
* and filters neither, so filtering here would show a card for a student whose year
* list is empty, or the reverse. The block check that matters is already in
* ZCL_EGA_CJ_ENH_IMPL_D026->UPDATE, which refuses the submit with message 093.
*
* IV_STUDENT_ID is CHAR12 because that is what ZFE_CJ_STUDENT_SCHOOL passes it.
*---------------------------------------------------------------------------------------*
    DATA lv_sis     TYPE char12.
    DATA lt_student TYPE ztt_cs_ega_student_bp.

    lv_sis = iv_sis.
    IF lv_sis IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'ZFE_CJ_GET_STUDENT_BP'
      EXPORTING
        iv_student_id = lv_sis
      IMPORTING
        et_student    = lt_student.

    SORT lt_student BY academic_year DESCENDING.

    LOOP AT lt_student INTO DATA(ls_student).
      rs_card-student_nm  = |{ ls_student-full_name_en }|.
      rs_card-sis_id      = |{ ls_student-studentid }|.
      rs_card-emirates_id = |{ ls_student-nationalid }|.
      rs_card-acad_year   = |{ ls_student-disp_academic_year }|.
      rs_card-cycle       = |{ ls_student-cycle }|.
      rs_card-grade_level = |{ ls_student-gradelevelid }|.
      rs_card-phone       = |{ ls_student-phone_number }|.
      rs_card-nationality = |{ ls_student-nationality_en }|.
      rs_card-email       = |{ ls_student-student_email }|.

      rs_card-school = COND #(
        WHEN sy-langu = 'A' AND ls_student-school_name_ar IS NOT INITIAL
        THEN |{ ls_student-school_name_ar }| ELSE |{ ls_student-school_name_en }| ).

      rs_card-curriculum = COND #(
        WHEN sy-langu = 'A' AND ls_student-curriculum_arabic IS NOT INITIAL
        THEN |{ ls_student-curriculum_arabic }| ELSE |{ ls_student-curriculum_english }| ).

*     STUDENT NAME and PHONE are the two the compiler could not name. It offered
*     STUDENT_EMAIL for the first and nothing for the second, so neither is a near
*     miss and guessing again would just cost another activation. Left out rather
*     than guessed: the card renders without them, and adding each is one line once
*     SE11 on ZST_CS_EGA_STUDENT_BP says what they are called.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_sis.
*---------------------------------------------------------------------------------------*
* Blocked and exited enrolments are dropped here so no caller has to remember to
* filter them. The RE contract carries the school name; the school master carries
* the curriculum that drives the term list.
*---------------------------------------------------------------------------------------*
    DATA lv_sis     TYPE zst_cs_ega_student_bp-studentid.
    DATA lt_student TYPE ztt_cs_ega_student_bp.

    lv_sis = iv_sis.
    IF lv_sis IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'ZFE_CJ_GET_STUDENT_BP'
      EXPORTING
        iv_student_id = lv_sis
      IMPORTING
        et_student    = lt_student.

    LOOP AT lt_student INTO DATA(ls_student).
*      IF ls_student-isblocked IS NOT INITIAL.
*        CONTINUE.
*      ENDIF.
*      IF ls_student-exit_date IS NOT INITIAL AND ls_student-exit_date LT sy-datum.
*        CONTINUE.
*      ENDIF.
*      IF ls_student-schoolid IS INITIAL.
*        CONTINUE.
*      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = ls_student-schoolid
        IMPORTING
          output = ls_student-schoolid.

      APPEND INITIAL LINE TO rt_enrol ASSIGNING FIELD-SYMBOL(<e>).
      <e>-sis         = ls_student-studentid.
      <e>-student_nm  = ls_student-full_name_en.
      <e>-emirates_id = ls_student-nationalid.
      <e>-acad_year   = ls_student-academic_year.
      <e>-school_id   = ls_student-schoolid.
      <e>-cycle       = ls_student-cycle.
      <e>-grade_level = ls_student-gradelevelid.
      <e>-mobile      = ls_student-mobile_number.
      <e>-email       = ls_student-email_id.

      SELECT SINGLE recntxt
        FROM vicncn
        WHERE bukrs      EQ @c_bukrs
          AND recntxtold EQ @ls_student-schoolid
        INTO @<e>-school_txt.

*      SELECT SINGLE curriculum
*        FROM zdt_dok_school_r
*        WHERE school_id EQ @ls_student-schoolid
*        INTO @<e>-curriculum.
    ENDLOOP.

    SORT rt_enrol BY acad_year DESCENDING school_id ASCENDING.
    DELETE ADJACENT DUPLICATES FROM rt_enrol COMPARING acad_year school_id.
  ENDMETHOD.


  METHOD selected_enrol.
    DATA lv_year TYPE numc4.

    CLEAR es_enrol.

    DATA(lv_key) = io_ctx->get_val( 'ACADEMICYEARSCHOOL' ).
    IF lv_key IS INITIAL OR lv_key = 'TBD'.
      RETURN.
    ENDIF.

    SPLIT lv_key AT c_sep INTO DATA(lv_year_s) DATA(lv_school_s).
    IF lv_school_s IS INITIAL.
      RETURN.
    ENDIF.
    lv_year = lv_year_s.

    READ TABLE enrol( io_ctx ) INTO es_enrol
      WITH KEY acad_year = lv_year school_id = lv_school_s.
    IF sy-subrc <> 0.
      CLEAR es_enrol.
      RETURN.
    ENDIF.

    rv_found = abap_true.
  ENDMETHOD.


  METHOD year_key.
    rv_key = |{ is_enrol-acad_year }{ c_sep }{ is_enrol-school_id }|.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
**---------------------------------------------------------------------------------------*
** Fed from the enrolment cache, not from its own read. This was the third SIS call
** per round trip before the cache went in.
**
** Rows are built through ADD_ROW rather than a nested VALUE #( ): the inner row type
** cannot be derived when the outer table is a returning parameter component.
**---------------------------------------------------------------------------------------*
*    CHECK to_upper( iv_name ) = 'STUDENTDETAILS'.
*
*    DATA ls_e TYPE ty_enrol.
*
*    rs_data-columns = VALUE #( ( `Field` ) ( `Value` ) ).
*
*    IF io_ctx->get_val( 'STUDENTSEARCH' ) IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    DATA(lt_enrol) = enrol( io_ctx ).
*    IF lt_enrol IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    IF selected_enrol( EXPORTING io_ctx = io_ctx IMPORTING es_enrol = ls_e ) = abap_false.
*      ls_e = lt_enrol[ 1 ].
*    ENDIF.
*
*    add_row( EXPORTING iv_label = `Student Name`
*                       iv_value = |{ ls_e-student_nm }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Emirates ID`
*                       iv_value = |{ ls_e-emirates_id }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Student SIS ID`
*                       iv_value = |{ ls_e-sis }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `School`
*                       iv_value = |{ ls_e-school_txt }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Academic Year`
*                       iv_value = |{ ls_e-acad_year }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Cycle`
*                       iv_value = |{ ls_e-cycle }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Grade Level`
*                       iv_value = |{ ls_e-grade_level }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Curriculum`
*                       iv_value = |{ ls_e-curriculum }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `Mobile`
*                       iv_value = |{ ls_e-mobile }|
*             CHANGING  ct_rows  = rs_data-rows ).
*    add_row( EXPORTING iv_label = `E-mail`
*                       iv_value = |{ ls_e-email }|
*             CHANGING  ct_rows  = rs_data-rows ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " This journey DOES have real PAYFEE fields — do NOT blanket-strip
    " PAY_*/PAYFEE here (that would break the fee actually being posted).
    " No other scratch keys need stripping.
*    DELETE ct_kv WHERE key = c_cache_field.
*---------------------------------------------------------------------------------------*
* Deliberately does NOT call SUPER. The base strips PAY_* and PAYFEE, which is right
* for a journey with no fee and wrong here - D026 has a real PAYFEE step and the fee
* has to reach the backend.
*
* MOE_CACHE and the STUD_* card fields are scratch. The card is what the MOE returned,
* the backend already has it, and MOE_CACHE is a serialised payload several KB long
* that no /QNV field will accept.
*---------------------------------------------------------------------------------------*
    DELETE ct_kv WHERE key = c_cache.
    DELETE ct_kv WHERE key CP 'STUD_*'.

*   The payment context and the payment state. PAY_BUKRS, PAY_MATERIAL, PAY_CASES_FOR
*   and PAY_ETISALAT tell ZCL_RAK_PAY_ENGINE which department it is acting for;
*   PAY_STARTED, PAY_REFERENCE, PAY_APPURL and PAY_TOTAL are its working state. None
*   of them is a /QNV field and none belongs in the post.
*
*   PAYFEE itself is NOT stripped - the base class strips it and this journey needs
*   the fee to reach the backend, which is why SUPER is not called.
    DELETE ct_kv WHERE key CP 'PAY_*'.

*   CASE_NUMBER is read-back only. It maps to GS_DATA-CASEID so the BAdI's READ fills
*   it, but MAPPER assigns whatever the POST carries, so sending it back empty would
*   blank the case id the journey had just been given.
    DELETE ct_kv WHERE key = 'CASE_NUMBER'.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*    CASE to_upper( iv_field ).


********************Commented *******************************

*      WHEN 'STUDENTSEARCH'.
*        CLEAR ms_cache.
*        io_ctx->set_val( iv_name = c_cache_field iv_value = space ).
*        clear_downstream( io_ctx ).
*
*      WHEN 'ACADEMICYEARSCHOOL'.
*        io_ctx->set_val( iv_name = 'TERM' iv_value = space ).
*
*        DATA ls_e TYPE ty_enrol.
*        IF selected_enrol( EXPORTING io_ctx = io_ctx IMPORTING es_enrol = ls_e ) = abap_true.
*          fill_card( io_ctx = io_ctx is_enrol = ls_e ).
*        ENDIF.
**
**      WHEN 'ACADEMICYEARSCHOOL'.
**        io_ctx->set_val( iv_name = 'TERM' iv_value = space ).
**
***      WHEN 'STUDENTSEARCH'.
**        DATA(lv_student_id) = io_ctx->get_val( 'STUDENTSEARCH' ).
**        IF lv_student_id IS INITIAL.
**          RETURN.
**        ENDIF.
*
*        " REVIEW: replace with the real read — same unconfirmed source as
*        " get_table( 'STUDENTDETAILS' ) above.
**        SELECT SINGLE license_no, issued_at, expired_at, school_name_en
**          FROM ztb_dok_almanal_student
**          WHERE student_id = @lv_student_id
**          INTO @DATA(ls_ctx).
**
**        IF sy-subrc = 0.
**          io_ctx->set_val( iv_name = 'LICNO'      iv_value = |{ ls_ctx-license_no }| ).
**          io_ctx->set_val( iv_name = 'LICISSUED'  iv_value = |{ ls_ctx-issued_at DATE = USER }| ).
**          io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_ctx-expired_at DATE = USER }| ).
**          io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = |{ ls_ctx-school_name_en }| ).
**        ENDIF.
*
*      WHEN 'ACADEMICYEARSCHOOL'.
*        " REVIEW: this fires (gated by rule R02) whenever the academic
*        " year/school changes, but without a confirmed on_value_help( )
*        " signature there is no template-documented way from here to
*        " push a fresh option list into TERM at runtime. Left as a no-op
*        " placeholder — see the class-level NOTE for what needs
*        " confirming before this can do anything real.
*    ENDCASE.

********************Commented *******************************
*---------------------------------------------------------------------------------------*
* The DEPENDENT_FIELD chain from the export: STUDENT_1 -> ACADEMIC_YEAR -> TERM_ID.
* Clears the VALUE only. The option lists are pulled by ON_VALUE_HELP on the way back
* down, so building one here would be a second source of truth that drifts.
*---------------------------------------------------------------------------------------*
        DATA ls_blank TYPE ty_card.

        CASE to_upper( iv_field ).

          WHEN c_f_student.
            CLEAR ms_cache.
            io_ctx->set_val( iv_name = c_cache  iv_value = space ).
            io_ctx->set_val( iv_name = c_f_year iv_value = space ).
            io_ctx->set_val( iv_name = c_f_term iv_value = space ).
            fill_card( io_ctx = io_ctx is_card = ls_blank ).

          WHEN c_f_year.
            io_ctx->set_val( iv_name = c_f_term iv_value = space ).

        ENDCASE.

      ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

***********Commented 10-08-2026*************

*    CHECK iv_step = 0.   " zero-based: step 1 "Student" in the wizard
*    DATA(lv_step) = io_ctx->get_step( ).
*
*    CASE lv_step.
*      WHEN '1'.
*        io_ctx->set_val( iv_name = 'STATUS' iv_value = 'SUBMIT' ).
**  WHEN .
*      WHEN OTHERS.
*    ENDCASE.

*    ***********Commented 10-08-2026**********************
*---------------------------------------------------------------------------------------*
* Step 0 only. The payment step is validated by the base class, which holds SUBMIT
* until PAYFEE reads PAID - calling SUPER keeps that.
*
* The MOE score read in ZCL_EGA_CJ_ENH_IMPL_D026->UPDATE needs all three of student,
* year and term. Missing any one of them comes back as message 097, "Unable to
* retrieve the student's academic details", which reads like a MOE outage rather
* than an empty field. Catching it here says which field.
*---------------------------------------------------------------------------------------*
       rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).
    IF rt IS NOT INITIAL OR iv_step <> 0.
      RETURN.
    ENDIF.

    IF io_ctx->get_val( c_f_student ) IS INITIAL.
      rt = VALUE #( ( type = 'Error' text = 'Search for and confirm a student before continuing.' ) ).
      RETURN.
    ENDIF.

    IF io_ctx->get_val( c_f_year ) IS INITIAL.
      rt = VALUE #( ( type = 'Error' text = 'Select the academic year / school.' ) ).
      RETURN.
    ENDIF.

    IF io_ctx->get_val( c_f_term ) IS INITIAL.
      rt = VALUE #( ( type = 'Error' text = 'Select a term.' ) ).
    ENDIF.



*    IF io_ctx->get_val( 'SCHOOLNAME' ) IS INITIAL.
*      rt = VALUE #( ( type = 'Error' text = 'Search for and confirm a student before continuing.' ) ).
*      RETURN.
*    ENDIF.
*
*    DATA(lv_year_key) = io_ctx->get_val( 'ACADEMICYEARSCHOOL' ).
*    IF lv_year_key IS INITIAL OR lv_year_key = 'TBD'.
*      rt = VALUE #( ( type = 'Error' text = 'Select the academic year / school.' ) ).
*      RETURN.
*    ENDIF.
*    DATA ls_e TYPE ty_enrol.
*    IF selected_enrol( EXPORTING io_ctx = io_ctx IMPORTING es_enrol = ls_e ) = abap_false.
*      rt = VALUE #( ( type = 'Error'
*                      text = 'The selected academic year / school is no longer valid for this student. Search again.' ) ).
*      RETURN.
*    ENDIF.
*
*    DATA(lv_term) = io_ctx->get_val( 'TERM' ).
*    IF lv_term IS INITIAL OR lv_term = 'TBD'.
*      rt = VALUE #( ( type = 'Error' text = 'Select a term.' ) ).
*      RETURN.
*    ENDIF.
*
*    SELECT SINGLE @abap_true
*      FROM zdt_dok_sh_cur_m
*      WHERE curriculum EQ @ls_e-curriculum
*        AND line_type  EQ @lv_term
*      INTO @DATA(lv_ok).
*    IF lv_ok <> abap_true.
*      rt = VALUE #( ( type = 'Error'
*                      text = 'The selected term does not belong to this academic year. Select it again.' ) ).
*    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.
*
    DATA(lv_user) = io_ctx->get_param( iv_name = 'USERDATA' ).
*
    zcl_ega_cj_utility=>get_bp(
     EXPORTING qv_key  = lv_user
     IMPORTING loginbp = DATA(lv_loginbp)
               rolebp  = DATA(lv_rolebp)
               role    = DATA(lv_role) ).


    DATA lt_student TYPE STANDARD TABLE OF string.

    APPEND 'Student SIS ID' TO lt_student.
    APPEND 'Emirates ID' TO lt_student.


    IF lv_loginbp IS INITIAL AND sy-sysid <> 'E30'.
      lv_loginbp = '3000000049'.
    ENDIF.

    IF lv_loginbp IS INITIAL.
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).

    SELECT SINGLE zzreferencea AS name_ar, zzfull_name_eng AS name_en
      FROM but000
      WHERE partner EQ @lv_loginbp
      INTO @DATA(ls_name).
    IF sy-subrc = 0.
      io_ctx->set_val( iv_name  = 'PARTNER_NAME'
                       iv_value = COND #( WHEN sy-langu = 'A' AND ls_name-name_ar IS NOT INITIAL
                                          THEN |{ ls_name-name_ar }| ELSE |{ ls_name-name_en }| ) ).
    ENDIF.

    SELECT SINGLE idnumber FROM but0id
      WHERE partner EQ @lv_loginbp
        AND type    EQ 'YFS002'
      INTO @DATA(lv_eid).
    IF sy-subrc = 0.
      io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = |{ lv_eid }| ).
    ENDIF.

    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*  METHOD zif_rak_journey_logic~on_search.
**SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH(
**    IO_CTX   = IO_CTX
**    IV_FIELD = IV_FIELD
**       ).
*
*
*    CASE iv_field.
*      WHEN 'STUDENTSEARCH'.
*      WHEN ''.
*      WHEN OTHERS.
*    ENDCASE.
*  ENDMETHOD.

    CASE to_upper( iv_field ).
      WHEN 'STUDENTSEARCH'.

*        DATA(lv_sis) = io_ctx->get_val( 'STUDENTSEARCH' ).
*        IF lv_sis IS INITIAL.
*          io_ctx->add_msg( iv_type = 'Error' iv_text = 'Enter a student id before searching.' ).
*          RETURN.
*        ENDIF.
*
*        DATA(lt_enrol) = NEW zcl_cj_moe_api( )->get_student_v1(
*                                               EXPORTING
**                                                 iv_emirates_id = iv_emirates_id " Identification Number
*                                                 iv_student_id  = CONV #( lv_sis )
**                                               IMPORTING
**                                                 messages       = messages       " Return table
*                                             ).
*        IF lt_enrol IS INITIAL.
*          io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = space ).
*          io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
*          io_ctx->set_val( iv_name = 'TERM' iv_value = space ).
*          io_ctx->add_msg( iv_type = 'Error' iv_text = |No active enrolment found for { lv_sis }| ).
*          RETURN.
*        ENDIF.
*
*        DATA(ls_first) = lt_enrol[ 1 ].
**
**        io_ctx->set_val( iv_name = 'SCHOOLNAME'         iv_value = |{ ls_first-school_txt }| ).
**        io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
**        io_ctx->set_val( iv_name = 'TERM'               iv_value = space ).
*
*        IF lines( lt_enrol ) = 1.
**          io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL'
**                           iv_value = |{ ls_first-acad_year }\|{ ls_first-school_id }| ).
*        ENDIF.


********************************Commented 10/08/2026*****************************
*        DATA(lv_sis) = io_ctx->get_val( 'STUDENTSEARCH' ).
*        IF lv_sis IS INITIAL.
*          io_ctx->add_msg( iv_type = 'Error' iv_text = 'Enter a student id before searching.' ).
*          RETURN.
*        ENDIF.
*
*        CLEAR ms_cache.
*        io_ctx->set_val( iv_name = c_cache_field iv_value = space ).
*
*        DATA(lt_enrol) = enrol( io_ctx = io_ctx iv_force = abap_true ).
*
*        IF lt_enrol IS INITIAL.
*          clear_downstream( io_ctx ).
*          io_ctx->add_msg( iv_type = 'Error' iv_text = |No active enrolment found for { lv_sis }| ).
*          RETURN.
*        ENDIF.
*
*        io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
*        io_ctx->set_val( iv_name = 'TERM' iv_value = space ).
*
*        fill_card( io_ctx = io_ctx is_enrol = lt_enrol[ 1 ] ).
*
*        IF lines( lt_enrol ) = 1.
*          io_ctx->set_val( iv_name  = 'ACADEMICYEARSCHOOL'
*                           iv_value = year_key( lt_enrol[ 1 ] ) ).
*        ENDIF.
*        DATA(ls_first)     = lt_enrol[ 1 ].
*        DATA(lv_year_from) = ls_first-acad_year - 1.
*        io_ctx->set_val( iv_name  = 'ACADEMICYEAR'
*                         iv_value = |{ lv_year_from }-{ ls_first-acad_year }/{ ls_first-school_txt }| ).
*
**        io_ctx->set_val( iv_name  = 'ACADEMICYEARSCHOOL'
**                         iv_value = |{ lv_year_from }-{ lv_year_to }/{ lv_school_name }| ).

********************************Commented 10/08/2026*****************************


    ENDCASE.

*---------------------------------------------------------------------------------------*
* The only forced MOE read. Pressing Search again on the same student re-reads
* deliberately - that is what a Search button is for.
*
* This does NOT fill the dropdown. It writes the card and, when the student has one
* enrolment, preselects the year. RENDER_ONE asks ON_VALUE_HELP for the list itself,
* later in this same round trip, and only when the field carries no configured
* options - which is why ACADEMIC_YEAR and TERM_ID must have no ZRAK_T_JNY_OPT rows.
*---------------------------------------------------------------------------------------*
    DATA ls_blank TYPE ty_card.

    CHECK to_upper( iv_field ) = c_f_student.

    DATA(lv_sis) = io_ctx->get_val( c_f_student ).
    IF lv_sis IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error' iv_text = 'Enter a student id before searching.' ).
      RETURN.
    ENDIF.

    DATA(lv_idtype) = io_ctx->get_val( 'STUDENT_1_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |Select ID Type (Emirates ID or Student SIS ID) to search| ).
      RETURN.
    ENDIF.

    CLEAR ms_cache.
    io_ctx->set_val( iv_name = c_cache  iv_value = space ).
    io_ctx->set_val( iv_name = c_f_year iv_value = space ).
    io_ctx->set_val( iv_name = c_f_term iv_value = space ).

    DATA(ls_moe) = moe( io_ctx = io_ctx iv_force = abap_true ).

    IF ls_moe-years IS INITIAL.
      fill_card( io_ctx = io_ctx is_card = ls_blank ).
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |No enrolment was found for student { lv_sis }.| ).
      RETURN.
    ENDIF.

    fill_card( io_ctx = io_ctx is_card = ls_moe-card ).

    IF lines( ls_moe-years ) = 1.
      io_ctx->set_val( iv_name = c_f_year iv_value = ls_moe-years[ 1 ]-key ).
    ENDIF.


  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.

**    DATA(lo_enrol) = NEW zcl_rak_stud_enrol( ).
*    DATA(lv_sis)   = io_ctx->get_val( 'STUDENTSEARCH' ).
*
*    CASE to_upper( iv_field ).
*
*      WHEN 'ACADEMICYEARSCHOOL'.
**        LOOP AT lo_enrol->year_options( lv_sis ) INTO DATA(ls_year).
**          APPEND VALUE #( key = ls_year-key text = ls_year-text ) TO rt.
**        ENDLOOP.
*
*      WHEN 'TERM'.
*        DATA(lv_year_key) = io_ctx->get_val( 'ACADEMICYEARSCHOOL' ).
*        IF lv_year_key IS INITIAL OR lv_year_key = 'TBD'.
*          RETURN.
*        ENDIF.
**        LOOP AT lo_enrol->term_options( iv_sis_id   = lv_sis
**                                        iv_year_key = lv_year_key ) INTO DATA(ls_term).
**          APPEND VALUE #( key = ls_term-key text = ls_term-text ) TO rt.
**        ENDLOOP.
*
*    ENDCASE.

****************Commented****************************************

*  rt = VALUE #( ( key = 'X' text = 'HOOK FIRED' ) ).
*
*
*    DATA lv_from TYPE numc4.
*
*    CASE to_upper( iv_field ).
*
*      WHEN 'ACADEMICYEARSCHOOL'.
*        LOOP AT enrol( io_ctx ) INTO DATA(ls_e).
*          lv_from = ls_e-acad_year - 1.
*          APPEND VALUE #( key  = year_key( ls_e )
*                          text = |{ lv_from }-{ ls_e-acad_year }/{ ls_e-school_txt }| ) TO rt.
*        ENDLOOP.
*
*      WHEN 'TERM'.
*        IF selected_enrol( EXPORTING io_ctx = io_ctx IMPORTING es_enrol = ls_e ) = abap_false.
*          RETURN.
*        ENDIF.
*
**        SELECT line_type, line_type_tx
**          FROM zdt_dok_sh_cur_m
**          WHERE curriculum EQ @ls_e-curriculum
**          INTO TABLE @DATA(lt_term).
**
**        LOOP AT lt_term INTO DATA(ls_term).
**          APPEND VALUE #( key  = |{ ls_term-line_type }|
**                          text = |{ ls_term-line_type_tx }| ) TO rt.
**        ENDLOOP.
*
*    ENDCASE.
****************Commented****************************************
*---------------------------------------------------------------------------------------*
* RENDER_ONE calls this for every field on every render, but only when the field has
* no configured options - see the LT_OPT IS INITIAL guard there. A single leftover
* ZRAK_T_JNY_OPT row on either field shadows this method completely and silently.
*
* The year list is cached. The term list is not: it is keyed on the selected year as
* well as the student, and a citizen who changes year twice would be served the first
* year's terms. One MOE call per year change is the honest cost.
*---------------------------------------------------------------------------------------*
    DATA lt_term TYPE tt_pair.

    CASE to_upper( iv_field ).

      WHEN c_f_year.
        LOOP AT moe( io_ctx )-years INTO DATA(ls_y).
          APPEND VALUE #( key = ls_y-key text = ls_y-text ) TO rt.
        ENDLOOP.

      WHEN c_f_term.
        DATA(lv_year) = io_ctx->get_val( c_f_year ).
        IF lv_year IS INITIAL.
          RETURN.
        ENDIF.
        DATA(lv_sis) = io_ctx->get_val( c_f_student ).
        IF lv_sis IS INITIAL.
          RETURN.
        ENDIF.

        lt_term = moe_options( iv_sis = lv_sis iv_year = lv_year ).

        LOOP AT lt_term INTO DATA(ls_t).
          APPEND VALUE #( key = ls_t-key text = ls_t-text ) TO rt.
        ENDLOOP.

    ENDCASE.
  ENDMETHOD.
ENDCLASS.
