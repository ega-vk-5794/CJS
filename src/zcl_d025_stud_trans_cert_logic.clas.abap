class ZCL_D025_STUD_TRANS_CERT_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
protected section.
private section.

  constants C_MIN_SEARCH_LEN type I value 3 ##NO_TEXT.
  constants C_DEFAULT_IDTYPE type STRING value 'YFS002' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_D025_STUD_TRANS_CERT_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
*   CHECK to_upper( iv_name ) = 'STUDENTDETAILS'.

    " REO_PANEL per v5: body rows come from get_table( ) as key/value
    " pairs (column 1 = label, column 2 = value) rather than a data grid.
    rs_data-columns = VALUE #( ( `Field` ) ( `Value` ) ).

*    DATA(lv_student_id) = io_ctx->get_val( 'STUDENTID' ).
*    IF lv_student_id IS INITIAL.
*      RETURN.
*    ENDIF.
*
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
    " This journey DOES have real PAYFEE fields — do NOT blanket-strip
    " PAY_*/PAYFEE here (that would break the fee actually being posted).
    " No other scratch keys need stripping — STUDENTID/STUDENTDETAILS are
    " both real, tech_name-bound fields, not UI-only scratch state.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*    CHECK to_upper( iv_field ) = 'STUDENTID'.
*
*    DATA(lv_student_id) = io_ctx->get_val( 'STUDENTID' ).
*    IF lv_student_id IS INITIAL.
*      RETURN.
*    ENDIF.

    " REVIEW: replace with the real read — same unconfirmed source as
    " get_table( 'STUDENTDETAILS' ) above; this just covers the license/
    " school context fields instead of the RO_PANEL body.
*    SELECT SINGLE license_no, issued_at, expired_at, school_name_en
*      FROM ztb_dok_almanal_student
*      WHERE student_id = @lv_student_id
*      INTO @DATA(ls_ctx).
*
*    IF sy-subrc = 0.
*      io_ctx->set_val( iv_name = 'LICNO' iv_value = |{ ls_ctx-license_no }| ).
*      io_ctx->set_val( iv_name = 'LICISSUED' iv_value = |{ ls_ctx-issued_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_ctx-expired_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'SCHOOLNAME' iv_value = |{ ls_ctx-school_name_en }| ).
*    ENDIF.
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

    ENDIF.

  ENDMETHOD.


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
      io_ctx->set_val( iv_name = 'STATUS' iv_value = 'PAY' ).
    ENDIF.

    super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                 iv_id    = iv_id
                                                 iv_event = iv_event ).
  endmethod.


  METHOD zif_rak_journey_logic~on_search.

    CHECK to_upper( iv_field ) = 'STUDENTID'.

    DATA(lv_eid) = condense( io_ctx->get_val( 'STUDENTID' ) ).

    DATA: lv_emirates_id TYPE bu_id_number,
          lv_student_id  TYPE char12.


    DATA(lv_idtype) = io_ctx->get_val( 'STUDENTID_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = |Select ID Type (Emirates ID or Student SIS ID) to search| ).
    ENDIF.

    IF lv_idtype = 'YFS002'.
      lv_emirates_id = lv_eid.
    ELSEIF lv_idtype = 'YFS001'.
      lv_student_id = lv_eid.
    ENDIF.

    DATA(lt_student) = zcl_cj_moe_api=>get_student_v1( iv_emirates_id = lv_emirates_id iv_student_id = lv_student_id ).
    IF lt_student IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |No Student found for given search| ).
    ENDIF.
    CHECK lt_student[] IS NOT INITIAL.

    SORT lt_student BY academic_year DESCENDING.
    DATA(ls_student) = VALUE #( lt_student[ 1 ] OPTIONAL ).


    io_ctx->set_val( iv_name = 'FULL_NAME'        iv_value = |{ ls_student-full_name_en }| ).
    io_ctx->set_val( iv_name = 'EMIRETS_ID'        iv_value = |{ ls_student-nationalid }| ).
    io_ctx->set_val( iv_name = 'STUDENT_ID'      iv_value = |{ ls_student-studentid }| ).
    io_ctx->set_val( iv_name = 'SCHOOL_NAME'       iv_value = |{ ls_student-school_name_en }| ).
    io_ctx->set_val( iv_name = 'ACD_YEAR'         iv_value = |{ ls_student-academic_year }| ).
    io_ctx->set_val( iv_name = 'CYCLE' iv_value = |{ ls_student-cycle }| ).
*
* |{ ls_student-STUDENT_NAME }| ).
    io_ctx->set_val( iv_name = 'GRADE_ID'  iv_value = |{ ls_student-gradelevelid }| ).
    io_ctx->set_val( iv_name = 'CURR'        iv_value = |{ ls_student-curriculum_english }| ).
    io_ctx->set_val( iv_name = 'TELEPHONE'      iv_value = |{ ls_student-phone_number }| ).
    io_ctx->set_val( iv_name = 'COUNTRY'       iv_value = |{ ls_student-nationality_en }| ).
    io_ctx->set_val( iv_name = 'EMAIL'         iv_value = |{ ls_student-student_email }| ).

  ENDMETHOD.
ENDCLASS.
