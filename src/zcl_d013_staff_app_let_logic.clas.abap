class ZCL_D013_STAFF_APP_LET_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_min_search_len TYPE i      VALUE 3.
    CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.

ENDCLASS.



CLASS ZCL_D013_STAFF_APP_LET_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
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
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " COMINGFROM -> GS_DATA-RAK_PRIVATE_SCHOOL / GS_DATA-OUTSIDE_RAK_SCHOOL
    READ TABLE ct_kv WITH KEY key = 'COMINGFROM' INTO DATA(ls_coming).
    IF sy-subrc = 0.
      ct_kv = VALUE #( BASE ct_kv
        ( key = 'GS_DATA-RAK_PRIVATE_SCHOOL' value = COND #( WHEN ls_coming-value = 'RAK_PRIVATE_SCHOOL_1' THEN 'X' ELSE '' ) )
        ( key = 'GS_DATA-OUTSIDE_RAK_SCHOOL' value = COND #( WHEN ls_coming-value = 'OUTSIDE_RAK_SCHOOL_1' THEN 'X' ELSE '' ) ) ).
      DELETE ct_kv WHERE key = 'COMINGFROM'.
    ENDIF.

    " APPOINTMENTTYPE -> GS_DATA-APPOINTMENT_PERMANENT / GS_DATA-APPOINTMENT_TEMPORARY
    READ TABLE ct_kv WITH KEY key = 'APPOINTMENTTYPE' INTO DATA(ls_apptype).
    IF sy-subrc = 0.
      ct_kv = VALUE #( BASE ct_kv
        ( key = 'GS_DATA-APPOINTMENT_PERMANENT' value = COND #( WHEN ls_apptype-value = 'APP_1' THEN 'X' ELSE '' ) )
        ( key = 'GS_DATA-APPOINTMENT_TEMPORARY' value = COND #( WHEN ls_apptype-value = 'APP_2' THEN 'X' ELSE '' ) ) ).
      DELETE ct_kv WHERE key = 'APPOINTMENTTYPE'.
    ENDIF.

    " STAFFTYPE -> GS_DATA-STAFF_TEACHING / GS_DATA-STAFF_NON
    READ TABLE ct_kv WITH KEY key = 'STAFFTYPE' INTO DATA(ls_stafftype).
    IF sy-subrc = 0.
      ct_kv = VALUE #( BASE ct_kv
        ( key = 'GS_DATA-STAFF_TEACHING' value = COND #( WHEN ls_stafftype-value = 'STAFF_1' THEN 'X' ELSE '' ) )
        ( key = 'GS_DATA-STAFF_NON'      value = COND #( WHEN ls_stafftype-value = 'STAFF_2' THEN 'X' ELSE '' ) ) ).
      DELETE ct_kv WHERE key = 'STAFFTYPE'.
    ENDIF.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.

    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 5), not omitted by oversight.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES.
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

  endmethod.


  METHOD zif_rak_journey_logic~on_change.
    CHECK to_upper( iv_field ) = 'LICENSE_SEL'.

    DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
    IF lv_license IS INITIAL.
      RETURN.
    ENDIF.

    " REVIEW: replace with the real license/school/manager detail read —
    " placeholder shown for the pattern only.
*    SELECT SINGLE license_no, issued_at, expired_at
*      FROM ztb_dok_licenses
*      WHERE license_no = @lv_license
*      INTO @DATA(ls_lic).
*
*    IF sy-subrc = 0.
*      io_ctx->set_val( iv_name = 'LICNO' iv_value = |{ ls_lic-license_no }| ).
*      io_ctx->set_val( iv_name = 'LICISSUED' iv_value = |{ ls_lic-issued_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_lic-expired_at DATE = USER }| ).
*    ENDIF.

    " REVIEW: populate SCHOOLNAMEEN/AR, TRADELICNO, SCHOOLADDRESS,
    " TELEPHONE, POBOX, PARCELID, and the 5 MANAGER* fields here from the
    " same selected license/school record.
    " io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = |{ ls_school-name_en }| ).
    " io_ctx->set_val( iv_name = 'MANAGERNAME'  iv_value = |{ ls_school-manager_name }| ).
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

    CHECK iv_step = 1.   " zero-based: step 2 "Appointment" in the wizard
    CHECK io_ctx->get_val( 'STAFFTYPE' ) = 'STAFF_1'.   " Teaching only

*    DATA(lv_grades) = VALUE string_table(
*      ( 'GRADEPREKG' ) ( 'GRADEKG1' ) ( 'GRADEKG2' )
*      ( 'GRADE1' ) ( 'GRADE2' ) ( 'GRADE3' ) ( 'GRADE4' ) ( 'GRADE5' ) ( 'GRADE6' )
*      ( 'GRADE7' ) ( 'GRADE8' ) ( 'GRADE9' ) ( 'GRADE10' ) ( 'GRADE11' ) ( 'GRADE12' ) ).
*
*    DATA(lv_any) = abap_false.
*    LOOP AT lv_grades INTO DATA(lv_grade).
*      IF io_ctx->get_val( lv_grade ) = abap_true.
*        lv_any = abap_true.
*      ENDIF.
*    ENDLOOP.
*
*    IF lv_any = abap_false.
*      rt_msg = VALUE #( ( type = 'Error' text = 'Select at least one grade for a Teaching appointment.' ) ).
*    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).

    zcl_ega_cj_utility=>get_bp(
      EXPORTING
        qv_key  = user_data
      IMPORTING
        loginbp = DATA(loginbp)
        rolebp  = DATA(rolebp)
        role    = DATA(role)
    ).
    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000000049' ).

    io_ctx->set_val( iv_name = 'LICNO' iv_value = '0000002500009' ).
    io_ctx->set_val( iv_name = 'LICISSUED' iv_value = 'yyyy.mm.dd' ).
    io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = 'yyyy.mm.dd' ).

*    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
    io_ctx->set_val( iv_name = 'APPLICANTNAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
*    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
    io_ctx->set_val( iv_name = 'APPLICANT_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).

*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Investor' ).

    io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = 'UAE School' ).
    io_ctx->set_val( iv_name = 'SCHOOLNAMEAR' iv_value = 'UAE School Arabic' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    CHECK to_upper( iv_field ) = 'CANDIDATESEARCH'.

    DATA(lv_eid) = condense( io_ctx->get_val( 'CANDIDATESEARCH' ) ).
    IF strlen( lv_eid ) < c_min_search_len.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = |Enter at least { c_min_search_len } characters to search| ).
      RETURN.
    ENDIF.

    DATA(lv_idtype) = io_ctx->get_val( 'CANDIDATESEARCH_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      lv_idtype = c_default_idtype.
    ENDIF.

    DATA: lv_eid_no   TYPE bu_id_number,
          lv_eid_type TYPE bu_id_type.

    lv_eid_no = lv_eid.
    lv_eid_type = lv_idtype.

*    SELECT SINGLE a~partner, a~zzfull_name_eng, b~idnumber, a~zzmobile, a~zzemail
*      FROM but000 AS a
*      LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idtype
*      WHERE b~idnumber = @lv_term OR a~partner = @lv_term
*      INTO @DATA(ls_bp).                                "#EC CI_NOORDBY

*    IF sy-subrc <> 0.
*      io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
*      RETURN.
*    ENDIF.

*    io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = |{ ls_bp-partner }| ).
    " REVIEW: the screenshot shows the found candidate's name/mobile/email
    " displayed inline where the search box is — if that needs separate
    " READONLY fields (rather than the search control rendering it
    " natively), seed CANDIDATENAME/CANDIDATEMOBILE/CANDIDATEEMAIL fields
    " and set_val them here.


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
*       IV_APP             = IV_APP
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


    io_ctx->set_val( iv_name = 'CANDIDATESEARCH'    iv_value = |{ lv_eid }| ).
    io_ctx->set_val( iv_name = 'MANAGERNAME'        iv_value = |{ ev_name }| ).
    io_ctx->set_val( iv_name = 'MANAGERMOBILE'      iv_value = |{ ev_phone }| ).
    io_ctx->set_val( iv_name = 'MANAGEREMAIL'       iv_value = |{ ev_email }| ).
    io_ctx->set_val( iv_name = 'DOB'                iv_value = |{ ev_date_of_birth }| ).
    io_ctx->set_val( iv_name = 'MANAGERNATIONALITY' iv_value = |{ ev_nationality }| ).

  ENDMETHOD.
ENDCLASS.
