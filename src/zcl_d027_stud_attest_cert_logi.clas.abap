class ZCL_D027_STUD_ATTEST_CERT_LOGI definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
protected section.
private section.

  types:
    BEGIN OF ty_pair,
      key  TYPE string,
      text TYPE string,
    END OF ty_pair .
  types:
    tt_pair TYPE STANDARD TABLE OF ty_pair WITH DEFAULT KEY .
  types:
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
  types:
    BEGIN OF ty_cache,
      sis   TYPE string,
      card  TYPE ty_card,
      years TYPE tt_pair,
    END OF ty_cache .

  data MS_CACHE type TY_CACHE .
  constants C_CACHE_FIELD type STRING value 'ENROL_CACHE' ##NO_TEXT.
  constants C_CACHE type STRING value 'MOE_CACHE' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_APP_NAME type STRING value 'PARENTNAME' ##NO_TEXT.
  constants C_APP_ID type STRING value 'PARENTEID' ##NO_TEXT.

  methods MOE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_FORCE type ABAP_BOOL default ABAP_FALSE
    returning
      value(RS_DATA) type TY_CACHE .
  methods MOE_OPTIONS
    importing
      !IV_SIS type CLIKE
      !IV_YEAR type CLIKE optional
    returning
      value(RT_PAIR) type TT_PAIR .
  methods MOE_STUDENT
    importing
      !IV_SIS type CLIKE
    returning
      value(RS_CARD) type TY_CARD .
  methods FILL_CARD
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IS_CARD type TY_CARD .
ENDCLASS.



CLASS ZCL_D027_STUD_ATTEST_CERT_LOGI IMPLEMENTATION.


  METHOD fill_card.
    io_ctx->set_val( iv_name = 'FULL_NAME'      iv_value = is_card-student_nm ).
    io_ctx->set_val( iv_name = 'EMIRETS_ID'     iv_value = is_card-emirates_id ).
    io_ctx->set_val( iv_name = 'STUDENT_ID'     iv_value = is_card-sis_id ).
    io_ctx->set_val( iv_name = 'SCHOOL_NAME'    iv_value = is_card-school ).
    io_ctx->set_val( iv_name = 'ACD_YEAR'       iv_value = is_card-acad_year ).
    io_ctx->set_val( iv_name = 'CYCLE'          iv_value = is_card-cycle ).
    io_ctx->set_val( iv_name = 'GRADE_ID'       iv_value = is_card-grade_level ).
    io_ctx->set_val( iv_name = 'CURR'           iv_value = is_card-curriculum ).
    io_ctx->set_val( iv_name = 'TELEPHONE'      iv_value = is_card-phone ).
    io_ctx->set_val( iv_name = 'COUNTRY'        iv_value = is_card-nationality ).
    io_ctx->set_val( iv_name = 'EMAIL'          iv_value = is_card-email ).
  ENDMETHOD.


  METHOD moe.
    DATA ls_cache TYPE ty_cache.
    DATA lv_json  TYPE string.

    DATA(lv_sis) = io_ctx->get_val( 'STUDENTID' ).

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


  METHOD zif_rak_journey_logic~get_table.
*    CHECK to_upper( iv_name ) = 'STUDENTDETAILS'.
*
*    rs_data-columns = VALUE #( ( `Field` ) ( `Value` ) ).
*
*    DATA(lv_student_id) = io_ctx->get_val( 'STUDENTID' ).
*    IF lv_student_id IS INITIAL.
*      RETURN.
*    ENDIF.

    " REVIEW: replace with the real Ministry-of-Education student lookup
    " — placeholder table/fields shown for the pattern only, same as the
    " other MOE-student journeys in this set.
*    SELECT SINGLE student_name, sisid, school_name, academic_year,
*                  cycle, grade_level, curriculum, mobile, email
*      FROM ztb_dok_almanal_student
*      WHERE student_id = @lv_student_id
*      INTO @DATA(ls_student).
*
*    IF sy-subrc = 0.
*      APPEND VALUE #( ( `Student Name` )  ( ls_student-student_name ) )  TO rs_table-rows.
*      APPEND VALUE #( ( `SISID` )         ( ls_student-sisid ) )         TO rs_table-rows.
*      APPEND VALUE #( ( `School` )        ( ls_student-school_name ) )   TO rs_table-rows.
*      APPEND VALUE #( ( `Academic Year` ) ( ls_student-academic_year ) ) TO rs_table-rows.
*      APPEND VALUE #( ( `Cycle` )         ( ls_student-cycle ) )         TO rs_table-rows.
*      APPEND VALUE #( ( `Grade Level` )   ( ls_student-grade_level ) )   TO rs_table-rows.
*      APPEND VALUE #( ( `Curriculum` )    ( ls_student-curriculum ) )    TO rs_table-rows.
*      APPEND VALUE #( ( `Mobile` )        ( ls_student-mobile ) )        TO rs_table-rows.
*      APPEND VALUE #( ( `E-mail` )        ( ls_student-email ) )         TO rs_table-rows.
*    ELSE.
*      io_ctx->add_msg( iv_type = 'Error' iv_text = |No student found for { lv_student_id }| ).
*    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*    CHECK to_upper( iv_field ) = 'STUDENTID'.
*
*    DATA(lv_student_id) = io_ctx->get_val( 'STUDENTID' ).
*    IF lv_student_id IS INITIAL.
*      RETURN.
*    ENDIF.

    " REVIEW: replace with the real read — same unconfirmed source as
    " get_table( 'STUDENTDETAILS' ) above.
*    SELECT SINGLE license_no, issued_at, expired_at, school_name_en
*      FROM ztb_dok_almanal_student
*      WHERE student_id = @lv_student_id
*      INTO @DATA(ls_ctx).
*
*    IF sy-subrc = 0.
*      io_ctx->set_val( iv_name = 'LICNO'      iv_value = |{ ls_ctx-license_no }| ).
*      io_ctx->set_val( iv_name = 'LICISSUED'  iv_value = |{ ls_ctx-issued_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_ctx-expired_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = |{ ls_ctx-school_name_en }| ).
*    ENDIF.

    DATA ls_blank TYPE ty_card.

    CASE to_upper( iv_field ).

      WHEN 'STUDENTID'.
        CLEAR ms_cache.
        io_ctx->set_val( iv_name = c_cache  iv_value = space ).
        io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
        fill_card( io_ctx = io_ctx is_card = ls_blank ).

*      WHEN 'ACADEMICYEARSCHOOL'.
*        io_ctx->set_val( iv_name = c_f_term iv_value = space ).

*      WHEN 'ACADEMICYEARSCHOOL'.
*        CLEAR ms_cache.
*        io_ctx->set_val( iv_name = c_cache  iv_value = space ).
*        io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
**        io_ctx->set_val( iv_name = c_f_term iv_value = space ).
*        fill_card( io_ctx = io_ctx is_card = ls_blank ).
*
*      WHEN c_f_year.
*        io_ctx->set_val( iv_name = c_f_term iv_value = space ).

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*    CHECK iv_step = 0.   " zero-based: step 1 "Student" in the wizard
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).
    IF rt IS NOT INITIAL OR iv_step <> 0.
      RETURN.
    ENDIF.

    IF io_ctx->get_val( 'STUDENTID' ) IS INITIAL.
      rt = VALUE #( ( type = 'Error' text = 'Search for and confirm a student before continuing.' ) ).
      RETURN.
    ENDIF.

    IF io_ctx->get_val( 'ACADEMICYEARSCHOOL' ) IS INITIAL OR io_ctx->get_val( 'ACADEMICYEARSCHOOL' ) = 'TBD'.
      rt = VALUE #( ( type = 'Error' text = 'Select the academic year / school.' ) ).
    ENDIF.

    IF io_ctx->get_val( 'CERTTYPE' ) IS INITIAL.
      rt = VALUE #( ( type = 'Error' text = 'Select a certificate type.' ) ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

     super->zif_rak_journey_logic~on_init( io_ctx = io_ctx ).

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

       IF sy-langu = 'E'.
        io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

*      "Emirates Id/Applicant ID
      io_ctx->set_val( iv_name = c_app_id  iv_value = CONV #( ls_bp-emirates_id ) ).

    ENDIF.

    io_ctx->set_val( iv_name = 'STUDENTID_IDTYPE'      iv_value = CONV #( 'YFS001' ) ).

*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
*    super->zif_rak_journey_logic~on_init( io_ctx = io_ctx ).
*
*    DATA(lv_user) = io_ctx->get_param( iv_name = 'USERDATA' ).
*
*    zcl_ega_cj_utility=>get_bp(
*      EXPORTING qv_key  = lv_user
*      IMPORTING loginbp = DATA(lv_loginbp)
*                rolebp  = DATA(lv_rolebp)
*                role    = DATA(lv_role) ).
*
*
*
*    IF lv_loginbp IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
*
**   The signed-in citizen, read from the business partner register. What stood
**   here was a fixed name and Emirates ID, written AFTER the real read, so every
**   applicant saw and posted the same test person.
*    NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
*      EXPORTING
*        iv_bp_id      = CONV bu_partner( lv_loginbp )
*      IMPORTING
*        es_bp_details = DATA(ls_bp_real) ).
*    io_ctx->set_val( iv_name = 'PARENTNAME' iv_value = COND #(
*      WHEN sy-langu <> 'E' AND ls_bp_real-bp_name_ar IS NOT INITIAL
*      THEN CONV string( ls_bp_real-bp_name_ar )
*      ELSE CONV string( ls_bp_real-bp_name ) ) ).
*    io_ctx->set_val( iv_name = 'PARENTEID' iv_value = CONV #( ls_bp_real-emirates_id ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .
*    CHECK to_upper( iv_field ) = 'STUDENTID'.
*
*    DATA(lv_eid) = condense( io_ctx->get_val( 'STUDENTID' ) ).
*
*    DATA: lv_emirates_id TYPE bu_id_number,
*          lv_student_id  TYPE char12.
*
*
*    DATA(lv_idtype) = io_ctx->get_val( 'STUDENTID_IDTYPE' ).
*    IF lv_idtype IS INITIAL.
*      io_ctx->add_msg( iv_type = 'Warning'
*                       iv_text = |Select ID Type (Emirates ID or Student SIS ID) to search| ).
*    ENDIF.
*
*    IF lv_idtype = 'YFS002'.
*      lv_emirates_id = lv_eid.
*    ELSEIF lv_idtype = 'YFS001'.
*      lv_student_id = lv_eid.
*    ENDIF.
*
*    DATA(lt_student) = zcl_cj_moe_api=>get_student_v1( iv_emirates_id = lv_emirates_id iv_student_id = lv_student_id ).
*    IF lt_student IS INITIAL.
*      io_ctx->add_msg( iv_type = 'Error'
*                       iv_text = |No Student found for given search| ).
*    ENDIF.
*    CHECK lt_student[] IS NOT INITIAL.
*
*    SORT lt_student BY academic_year DESCENDING.
*    DATA(ls_student) = VALUE #( lt_student[ 1 ] OPTIONAL ).
*
*
*    io_ctx->set_val( iv_name = 'FULL_NAME'        iv_value = |{ ls_student-full_name_en }| ).
*    io_ctx->set_val( iv_name = 'EMIRETS_ID'        iv_value = |{ ls_student-nationalid }| ).
*    io_ctx->set_val( iv_name = 'STUDENT_ID'      iv_value = |{ ls_student-studentid }| ).
*    io_ctx->set_val( iv_name = 'SCHOOL_NAME'       iv_value = |{ ls_student-school_name_en }| ).
*    io_ctx->set_val( iv_name = 'ACD_YEAR'         iv_value = |{ ls_student-academic_year }| ).
*    io_ctx->set_val( iv_name = 'CYCLE' iv_value = |{ ls_student-cycle }| ).
**
** |{ ls_student-STUDENT_NAME }| ).
*    io_ctx->set_val( iv_name = 'GRADE_ID'  iv_value = |{ ls_student-gradelevelid }| ).
*    io_ctx->set_val( iv_name = 'CURR'        iv_value = |{ ls_student-curriculum_english }| ).
*    io_ctx->set_val( iv_name = 'TELEPHONE'      iv_value = |{ ls_student-phone_number }| ).
*    io_ctx->set_val( iv_name = 'COUNTRY'       iv_value = |{ ls_student-nationality_en }| ).
*    io_ctx->set_val( iv_name = 'EMAIL'         iv_value = |{ ls_student-student_email }| ).
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

    CHECK to_upper( iv_field ) = 'STUDENTID'.

    DATA(lv_sis) = io_ctx->get_val( 'STUDENTID' ).
    IF lv_sis IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error' iv_text = 'Enter a student id before searching.' ).
      RETURN.
    ENDIF.

    DATA(lv_idtype) = io_ctx->get_val( 'STUDENTID_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |Select ID Type (Emirates ID or Student SIS ID) to search| ).
      RETURN.
    ENDIF.

    CLEAR ms_cache.
    io_ctx->set_val( iv_name = c_cache  iv_value = space ).
    io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = space ).
*    io_ctx->set_val( iv_name = c_f_term iv_value = space ).

    DATA(ls_moe) = moe( io_ctx = io_ctx iv_force = abap_true ).
*
    IF ls_moe-years IS INITIAL.
      fill_card( io_ctx = io_ctx is_card = ls_blank ).
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |No enrolment was found for student { lv_sis }.| ).
      RETURN.
    ENDIF.

    fill_card( io_ctx = io_ctx is_card = ls_moe-card ).

    IF lines( ls_moe-years ) = 1.
      io_ctx->set_val( iv_name = 'ACADEMICYEARSCHOOL' iv_value = ls_moe-years[ 1 ]-key ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .

    DATA lt_term TYPE tt_pair.

    CASE to_upper( iv_field ).

      WHEN 'ACADEMICYEARSCHOOL'.
        LOOP AT moe( io_ctx )-years INTO DATA(ls_y).
          APPEND VALUE #( key = ls_y-key text = ls_y-text ) TO rt.
        ENDLOOP.

    ENDCASE.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST.
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
  endmethod.
ENDCLASS.
