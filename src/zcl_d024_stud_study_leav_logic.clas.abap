class ZCL_D024_STUD_STUDY_LEAV_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
protected section.
private section.

  types:
*   One MOE payload per student. Held in the model as well as on the instance
*   because the instance does not survive the round trip and ON_VALUE_HELP is
*   called from RENDER_ONE on EVERY render, for both dropdowns. Without the
*   cache that is three MOE calls per round trip instead of one per search.
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

  constants C_F_STUDENT type STRING value 'STUDENT_1' ##NO_TEXT.
  constants C_F_YEAR type STRING value 'ACADEMIC_YEAR' ##NO_TEXT.
  constants C_F_TERM type STRING value 'TERM_ID' ##NO_TEXT.
  constants C_CACHE type STRING value 'MOE_CACHE' ##NO_TEXT.
  data MS_CACHE type TY_CACHE .

    "! The single MOE read. Serves from the instance, then from the model field,
    "! and only calls ZFE_CJ_STUDENT_SCHOOL when both miss.
  methods MOE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_FORCE type ABAP_BOOL default ABAP_FALSE
    returning
      value(RS_DATA) type TY_CACHE .
    "! The option list. ZFE_CJ_STUDENT_SCHOOL is the generic /QNV combobox source:
    "! CT_FIELDS names the driving fields, CT_VALUES holds their values, paired by
    "! position. The export's DATA2 is exactly that list - STUDENT_1 for the year
    "! dropdown, ACADEMIC_YEAR,STUDENT_1 for the term dropdown.
  methods MOE_OPTIONS
    importing
      !IV_SIS type CLIKE
      !IV_YEAR type CLIKE optional
    returning
      value(RT_PAIR) type TT_PAIR .
    "! The student card. A separate read - ZFE_CJ_STUDENT_SCHOOL returns options and
    "! nothing else, so the card cannot come from it.
  methods MOE_STUDENT
    importing
      !IV_SIS type CLIKE
    returning
      value(RS_CARD) type TY_CARD .
    "! Write the grey student card. Blank IS_CARD clears it.
  methods FILL_CARD
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IS_CARD type TY_CARD .
ENDCLASS.



CLASS ZCL_D024_STUD_STUDY_LEAV_LOGIC IMPLEMENTATION.


  method FILL_CARD.

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

  endmethod.


  method MOE.

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

  endmethod.


  method MOE_OPTIONS.

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

  endmethod.


  method MOE_STUDENT.

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

  endmethod.


  METHOD zif_rak_journey_logic~get_table.
*    CHECK to_upper( iv_name ) = 'STUDENTDETAILS'.
*
*    " REO_PANEL per v5: body rows come from get_table( ) as key/value
*    " pairs (column 1 = label, column 2 = value) rather than a data grid.
*    rs_data-columns = VALUE #( ( `Field` ) ( `Value` ) ).
*
*    DATA(lv_student_id) = io_ctx->get_val( 'STUDENTID' ).
*    IF lv_student_id IS INITIAL.
*      RETURN.
*    ENDIF.

    " REVIEW: replace with the real Ministry-of-Education student lookup
    " — the export gives no FM/table name for this at all (unlike the
    " LICENCES/OWNERS_DISP contexts seen on other journeys), since the
    " native STUDENT_SEARCH_MOE control handles it entirely internally.
    " Placeholder table/fields shown for the pattern only.
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


  METHOD zif_rak_journey_logic~on_before_post.
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

*    IF io_ctx->get_val( c_f_year ) IS INITIAL.
*      rt = VALUE #( ( type = 'Error' text = 'Select the academic year / school.' ) ).
*      RETURN.
*    ENDIF.
*
*    IF io_ctx->get_val( c_f_term ) IS INITIAL.
*      rt = VALUE #( ( type = 'Error' text = 'Select a term.' ) ).
*    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
*    CALL METHOD super->zif_rak_journey_logic~on_init
*      EXPORTING
*        io_ctx = io_ctx.
**
*    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
**
*    zcl_ega_cj_utility=>get_bp(
*      EXPORTING
*        qv_key  = user_data
*      IMPORTING
*        loginbp = DATA(loginbp)
*        rolebp  = DATA(rolebp)
*        role    = DATA(role)
*    ).
*
*    DATA lt_student TYPE STANDARD TABLE OF string.
*
*    APPEND 'Student SIS ID' TO lt_student.
*    APPEND 'Emirates ID' TO lt_student.
*
*
**    io_ctx->set_val(
**      iv_name  = 'PARTNER_ID'
**      iv_value = lt_student
**    ).
*
*
**
*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000000049' ).
*
**    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
**    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
*    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
*
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
*    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).

    super->zif_rak_journey_logic~on_init( io_ctx = io_ctx ).

    DATA(lv_user) = io_ctx->get_param( iv_name = 'USERDATA' ).

    zcl_ega_cj_utility=>get_bp(
      EXPORTING qv_key  = lv_user
      IMPORTING loginbp = DATA(lv_loginbp)
                rolebp  = DATA(lv_rolebp)
                role    = DATA(lv_role) ).

*   DEV FALLBACK - MUST NOT REACH PRODUCTION.
*   GS_DATA-PARTNER is what gates the fee read: ZCL_EGA_CJ_ENH_IMPL_D026->CREATE only
*   calls CJ_PAYMENT_SCR_FEE( 'ZK14' ) when the partner is filled, so a blank BP means
*   an empty fee list and "No open payments found for this case" on the way into the
*   payment step. GET_BP returns nothing on the dev box, which is why the original
*   version of this class had the number written in.
*
*   Guarded on SY-SYSID rather than deleted so the journey is testable on E10 and
*   cannot silently invent an applicant on E30. Remove once the dev box has BPs.

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

*   The trailing hardcoded name and Emirates ID that used to sit here are gone.
*   They ran AFTER the BUT000 / BUT0ID reads above and overwrote them, so every
*   applicant saw and posted the same test person's identity.
  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT.
*---------------------------------------------------------------------------------------*
* STATUS is what tells the BAdI what the post is FOR. ZCL_EGA_CJ_DOK_ABS->MAPPER
* branches on it and does nothing at all when it is blank: no CREATE_CASE, no case,
* no open item, no gateway - and no error either, because a post with no STATUS is
* a legitimate save-the-draft round trip.
*
* The legacy screen carried it on the control - DATA3 = PAYMENT on the RAKPAY button,
* SUBMIT on Next, SAVE_DRAFT on Save. CJS has no DATA3, so the handler writes it, and
* it has to be written BEFORE the post: the base class calls COMMIT_STEP( ) as the
* first thing it does on PAYNOW, and by the time PREPARE_PAYMENT( ) runs the post has
* already gone.
*
* Only PAYNOW. Step 1's Next carried no DATA3 in the export either - it moves the
* citizen forward and deliberately creates nothing, which is what keeps an abandoned
* journey from burning a case number.
*---------------------------------------------------------------------------------------*
    IF iv_event = c_pay_now.
      io_ctx->set_val( iv_name = 'STATUS' iv_value = 'PAYMENT' ).
    ENDIF.

    super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                 iv_id    = iv_id
                                                 iv_event = iv_event ).
  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.
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
*    io_ctx->set_val( iv_name = c_f_year iv_value = space ).
*    io_ctx->set_val( iv_name = c_f_term iv_value = space ).

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
  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP.
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
  endmethod.
ENDCLASS.
