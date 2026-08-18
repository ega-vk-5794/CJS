class ZCL_D014_STAFF_EXP_CERT_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
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



CLASS ZCL_D014_STAFF_EXP_CERT_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.
*       CONFIRMED — same pattern as every other journey's license picker.
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

      WHEN 'CANDIDATESELECT'.
*       DRAFT — entire construct is a hypothesis (see load report NOTE 2).
*       RECORDCARD per v5: first cell is the stored key, the rest is card
*       text. An "Other" row is included so on_change( ) (not yet written
*       here, since its exact trigger is unconfirmed) can reveal
*       CANDIDATESEARCH when it is picked.
        rs_data-columns = VALUE #( ( `Name` ) ( `Job Title` ) ).   " REVIEW: column set guessed

        " REVIEW: replace with a real read of prior staff appointed at
        " this school, once the real backend structure is known.
*        SELECT partner_name, job_title
*          FROM ztb_dok_staff                            "#EC CI_NOORDBY
*          WHERE license_no = @io_ctx->get_val( 'LICENSE_SEL' )
*          INTO TABLE @DATA(lt_staff).
*
*        LOOP AT lt_staff INTO DATA(ls_staff).
*          APPEND VALUE #( ( |{ ls_staff-partner_name }| ) ( |{ ls_staff-job_title }| ) ) TO rs_table-rows.
*        ENDLOOP.
        APPEND VALUE #( ( `OTHER` ) ( `Other — staff not listed` ) ) TO rs_data-rows.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey (DRAFT assumption,
    " same as the rest of the family), but the strip is safe to keep.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " DRAFT — mirrors D013's APPOINTMENTTYPE/STAFFTYPE split exactly,
    " since this journey's Appointment Details panel was carried over
    " from D013 as a hypothesis. Confirm real flag names once the real
    " export exists — do not assume these are correct for D014.
    READ TABLE ct_kv WITH KEY key = 'APPOINTMENTTYPE' INTO DATA(ls_apptype).
    IF sy-subrc = 0.
      ct_kv = VALUE #( BASE ct_kv
        ( key = 'GS_DATA-APPOINTMENT_PERMANENT' value = COND #( WHEN ls_apptype-value = 'APP_1' THEN 'X' ELSE '' ) )
        ( key = 'GS_DATA-APPOINTMENT_TEMPORARY' value = COND #( WHEN ls_apptype-value = 'APP_2' THEN 'X' ELSE '' ) ) ).
      DELETE ct_kv WHERE key = 'APPOINTMENTTYPE'.
    ENDIF.

    READ TABLE ct_kv WITH KEY key = 'STAFFTYPE' INTO DATA(ls_stafftype).
    IF sy-subrc = 0.
      ct_kv = VALUE #( BASE ct_kv
        ( key = 'GS_DATA-STAFF_TEACHING' value = COND #( WHEN ls_stafftype-value = 'STAFF_1' THEN 'X' ELSE '' ) )
        ( key = 'GS_DATA-STAFF_NON'      value = COND #( WHEN ls_stafftype-value = 'STAFF_2' THEN 'X' ELSE '' ) ) ).
      DELETE ct_kv WHERE key = 'STAFFTYPE'.
    ENDIF.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.
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
    io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
*    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).

*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
    io_ctx->set_val( iv_name = 'APP_TYPE' iv_value = 'Investor' ).

    io_ctx->set_val( iv_name = 'NAME_EN' iv_value = 'UAE School' ).
    io_ctx->set_val( iv_name = 'NAME_AR' iv_value = 'UAE School Arabic' ).
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


    io_ctx->set_val( iv_name = 'CANDIDATESEARCH'  iv_value = |{ lv_eid }| ).
    io_ctx->set_val( iv_name = 'CAND_NAME'        iv_value = |{ ev_name }| ).
    io_ctx->set_val( iv_name = 'CAND_MOBILE'      iv_value = |{ ev_phone }| ).
    io_ctx->set_val( iv_name = 'CAND_EMAIL'       iv_value = |{ ev_email }| ).
    io_ctx->set_val( iv_name = 'SEARCH_DOB'       iv_value = |{ ev_date_of_birth }| ).
    io_ctx->set_val( iv_name = 'SEARCH_NAT'       iv_value = |{ ev_nationality }| ).

  ENDMETHOD.
ENDCLASS.
