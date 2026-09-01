class ZCL_D003_SCHOOL_LIC_RNEW_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_min_search_len TYPE i      VALUE 3.
    CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.
ENDCLASS.



CLASS ZCL_D003_SCHOOL_LIC_RNEW_LOGIC IMPLEMENTATION.


    METHOD zif_rak_journey_logic~get_table.
      CHECK to_upper( iv_name ) = 'LICENSES'.
      CASE to_upper( iv_name ).
        WHEN 'LICENSES'.

          " Column order matches the export's LEVEL_CON='T' children of LICENSES:
          " License, School name, Issued at, Expiry date.
          rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expiry date` ) ).

          " REVIEW: replace with the real school-license read (the export names
          " FM ZFM_EGA_CJ_FW_READ_TABLE_DATAN / context LICENCES — call the
          " actual FM here rather than selecting a placeholder table directly).
*    SELECT license_no, school_name, issued_at, expired_at
*      FROM ztb_dok_licenses                              "#EC CI_NOORDBY
*      WHERE partner = @io_ctx->get_val( 'OWNER_BP' )
*      INTO TABLE @DATA(lt_lic).
*
*    LOOP AT lt_lic INTO DATA(ls_lic).
*      APPEND VALUE #( ( |{ ls_lic-license_no }| )
*                      ( |{ ls_lic-school_name }| )
*                      ( |{ ls_lic-issued_at DATE = USER }| )
*                      ( |{ ls_lic-expired_at DATE = USER }| ) ) TO rs_data-rows.
*    ENDLOOP.
*          DATA(lv_license_list) = io_ctx->get_val( 'LICENSES' ).
*          DATA(lv_license_sel) = io_ctx->get_val( 'LICENSE_SEL' ).
*          IF lv_license_sel IS INITIAL.
*            RETURN.
*          ENDIF.
*
*          DATA(lr_school) = NEW zcl_dok_appln_handler_api( ).
*
*          DATA(lv_login_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
*
*          lr_school->license_search(
*        EXPORTING
**          iv_bp_applicant = '3000124165'
*          iv_bp_applicant = CONV bu_partner( lv_login_bp )
*        IMPORTING
*          et_lic_no_list  = DATA(lt_list) ).
*
*          IF lt_list IS NOT INITIAL.
*            DELETE lt_list WHERE recnnr NE lv_license_sel.
*
*            LOOP AT lt_list ASSIGNING FIELD-SYMBOL(<ls_list>).
*              APPEND VALUE #( ( |{ <ls_list>-recnnr }| )          "Set License Number
*                              ( |{ <ls_list>-recntxt }| )         "Set School Name
*                              ( |{ <ls_list>-validfrom  DATE = USER }| )   "Set License Issued
*                              ( |{ <ls_list>-validto  DATE = USER }| ) ) TO rs_data-rows. "*Set License Expired
*            ENDLOOP.
*
*
*          ELSE.
*            APPEND VALUE #( ( |{ '1234' }| )
*                              ( |{ 'School1' }| )
*                              ( |{ '20260101' }| )
*                              ( |{ '20261230' }| ) ) TO rs_data-rows.
*            "Set License Number
*            io_ctx->set_val(
*              EXPORTING
*                iv_name  = 'LICNO'
*                iv_value = '1234'
*            ).
*            "Set School Name
*            io_ctx->set_val(
*              EXPORTING
*                iv_name  = 'SCHOOLNAMEEN'
*                iv_value = 'School1'
*            ).
**Set License Issued
*            io_ctx->set_val(
*              EXPORTING
*                iv_name  = 'LICISSUED'
*                iv_value = '20260101'
*            ).
**Set License Expired
*            io_ctx->set_val(
*              EXPORTING
*                iv_name  = 'LICEXPIRED'
*                iv_value = '20261231'
*            ).
*          ENDIF.
        WHEN 'OWNERS'.
*        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile Number` ) ( `E-mail` ) ).
      ENDCASE.
    ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.

    " NOTE: unlike every other DoK/EPDA journey so far, there is no
    " DECLARE checkbox to strip here — confirmed absent from the export
    " (see load report NOTE 5), not omitted by oversight.
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
*    CHECK to_upper( iv_field ) = 'LICENSE_SEL'.

*    DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
*    IF lv_license IS INITIAL.
*      RETURN.
*    ENDIF.

*    CASE to_upper( iv_field ).
*      WHEN 'LICENSE_LIST'.
*        DATA(lv_license_sel) = io_ctx->get_val( 'LICENSE_LIST' ).
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LICENSE_SEL'
*            iv_value = lv_license_sel
*        ).
** Get School Information
*        DATA(lr_school) = NEW zcl_dok_appln_handler_api( ).
*        lr_school->school_details(
*          EXPORTING
*            iv_recnnr         = CONV recnnumber( lv_license_sel )
**            iv_form_multlangu =                  " Boolean Variables (X=true, space=false)
*          IMPORTING
*            et_school_dt      = DATA(ls_school_data)
*            et_return         = DATA(lt_return)
*        ).
*        IF ls_school_data IS INITIAL.
*          RETURN.
*        ENDIF.
*
*        DATA(ls_school) = ls_school_data-school[ 1 ].
*        "LICNO  --> GS_DATA-LICENCE_NO
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LICNO'
*            iv_value = lv_license_sel
*        ).
** LICISSUED --> GS_DATA-LICENCE_VALID_FROM
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LICISSUED'
*            iv_value = |{ ls_school_data-permit_issue DATE = USER }|
*        ).
**
** LICEXPIRED --> GS_DATA-LICENCE_VALID_TO
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LICEXPIRED'
*            iv_value = |{ ls_school_data-permit_expire DATE = USER }|
*        ).
*
** applicant_type
** APPLICANTTYPE --> GS_DATA-APPLICANT_TYPE
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'APPLICANTTYPE'
*            iv_value = CONV #( ls_school_data-applicant_type )
*        ).
**
**SCHOOLNAMEEN --> GS_DATA-SCHOOL-SCHOOL_NAME_EN
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'SCHOOLNAMEEN'
*            iv_value = CONV #( ls_school-school_name_en )
*        ).
**
** SCHOOLNAMEAR --> GS_DATA-SCHOOL-SCHOOL_NAME_AB
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'SCHOOLNAMEAR'
*            iv_value = CONV #( ls_school-school_name_ab )
*        ).
** TRADELICAUTH --> GS_DATA-SCHOOL-REG_AUTHORITY
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'TRADELICAUTH'
*            iv_value = CONV #( ls_school-reg_authority )
*        ).
**
** CURRICULUM --> GS_DATA-SCHOOL-CURRICULUM
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'CURRICULUM'
*            iv_value = CONV #( ls_school-curriculum )
*        ).
**
** LOCATION --> GS_DATA-SCHOOL-LOCATION
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LOCATION'
*            iv_value = CONV #( ls_school-location )
*        ).
** CURRICULUMTYPE --> GS_DATA-SCHOOL-CURRICULUM_TYPE
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'CURRICULUMTYPE'
*            iv_value = CONV #( ls_school-curriculum_type )
*        ).
**
** SCHOOLADDRESS -> GS_DATA-SCHOOL-ADRESS
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'SCHOOLADDRESS'
*            iv_value = CONV #( ls_school-adress )
*        ).
**
** TELEPHONE --> GS_DATA-SCHOOL-TELEPHONE
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'TELEPHONE'
*            iv_value = CONV #( ls_school-telephone )
*        ).
** POBOX --> GS_DATA-SCHOOL-POBOX
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'POBOX'
*            iv_value = CONV #( ls_school-pobox )
*        ).
** PARCELID -->   GS_DATA-SCHOOL-PARCEL_ID
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'PARCELID'
*            iv_value = CONV #( ls_school-parcel_id )
*        ).
*
*
*
*
*      WHEN ''.
*      WHEN OTHERS.
*    ENDCASE.
    " REVIEW: replace with the real license-detail read (same source as
    " get_table( 'LICENSES' ) above, filtered to this one key) rather than
    " a placeholder SELECT.
*    SELECT SINGLE license_no, issued_at, expired_at
*      FROM ztb_dok_licenses
*      WHERE license_no = @lv_license
*      INTO @DATA(ls_lic).
*
*    IF sy-subrc = 0.
*      io_ctx->set_val( iv_name = 'LICNO'       iv_value = |{ ls_lic-license_no }| ).
*      io_ctx->set_val( iv_name = 'LICISSUED'   iv_value = |{ ls_lic-issued_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'LICEXPIRED'  iv_value = |{ ls_lic-expired_at DATE = USER }| ).

    " REVIEW: the school-identity READONLY fields (SCHOOLNAMEEN/AR,
    " SCHOOLADDRESS, TELEPHONE, POBOX, PARCELID) should also be
    " populated here from the same selected license/school record —
    " placeholder shown for the pattern only, real source fields
    " unconfirmed.
    " io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = |{ ls_school-name_en }| ).
*    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.
*
    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
*
    zcl_ega_cj_utility=>get_bp(
      EXPORTING
        qv_key  = user_data
      IMPORTING
        loginbp = DATA(loginbp)
        rolebp  = DATA(rolebp)
        role    = DATA(role)
    ).
*
*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = CONV string( loginbp ) ).
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
*    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*   The signed-in citizen, read from the business partner register. What stood
*   here was a fixed name and Emirates ID, written AFTER the real read, so every
*   applicant saw and posted the same test person.
    NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
      EXPORTING
        iv_bp_id      = CONV bu_partner( loginbp )
      IMPORTING
        es_bp_details = DATA(ls_bp_real) ).
    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = COND #(
      WHEN sy-langu <> 'E' AND ls_bp_real-bp_name_ar IS NOT INITIAL
      THEN CONV string( ls_bp_real-bp_name_ar )
      ELSE CONV string( ls_bp_real-bp_name ) ) ).
    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( ls_bp_real-emirates_id ) ).
*    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).

*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
   CASE to_upper( iv_field ).
      WHEN 'COMPANYSEARCH'.
        DATA(lv_term_co) = condense( io_ctx->get_val( 'COMPANYSEARCH' ) ).
        IF strlen( lv_term_co ) < c_min_search_len.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Enter at least { c_min_search_len } characters to search| ).
          RETURN.
        ENDIF.

        DATA(lv_idtype_co) = io_ctx->get_val( 'COMPANYSEARCH_IDTYPE' ).
        IF lv_idtype_co IS INITIAL.
          lv_idtype_co = c_default_idtype.   " REVIEW: a dedicated trade-license id-type may be more correct — see load report NOTE 3
        ENDIF.

        SELECT SINGLE a~partner, a~zzfull_name_eng, b~idnumber
          FROM but000 AS a
          LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idtype_co
          WHERE b~idnumber = @lv_term_co OR a~partner = @lv_term_co
          INTO @DATA(ls_co).

        IF sy-subrc <> 0.
          io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term_co }| ).
          RETURN.
        ENDIF.

        io_ctx->set_val( iv_name = 'COMPANYSEARCH' iv_value = |{ ls_co-partner }| ).

      WHEN 'MANAGERSEARCH'.
        DATA(lv_term_mg) = condense( io_ctx->get_val( 'MANAGERSEARCH' ) ).
        IF strlen( lv_term_mg ) < c_min_search_len.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Enter at least { c_min_search_len } characters to search| ).
          RETURN.
        ENDIF.

        DATA(lv_idtype_mg) = io_ctx->get_val( 'MANAGERSEARCH_IDTYPE' ).
        IF lv_idtype_mg IS INITIAL.
          lv_idtype_mg = c_default_idtype.
        ENDIF.

*        SELECT SINGLE a~partner, a~zzfull_name_eng, b~idnumber, a~zzmobile, a~zzemail, a~zznationality
*          FROM but000 AS a
*          LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idtype_mg
*          WHERE b~idnumber = @lv_term_mg OR a~partner = @lv_term_mg
*          INTO @DATA(ls_mg).                                 "#EC CI_NOORDBY
*
*        IF sy-subrc <> 0.
*          io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term_mg }| ).
*          RETURN.
*        ENDIF.
*
*        io_ctx->set_val( iv_name = 'MANAGERSEARCH'      iv_value = |{ ls_mg-partner }| ).
*        io_ctx->set_val( iv_name = 'MANAGERNAME'        iv_value = |{ ls_mg-zzfull_name_eng }| ).
*        io_ctx->set_val( iv_name = 'MANAGEREID'         iv_value = |{ ls_mg-idnumber }| ).
*        io_ctx->set_val( iv_name = 'MANAGERMOBILE'      iv_value = |{ ls_mg-zzmobile }| ).      " REVIEW: BUT000 field names are placeholders
*        io_ctx->set_val( iv_name = 'MANAGEREMAIL'       iv_value = |{ ls_mg-zzemail }| ).        " REVIEW: BUT000 field names are placeholders
*        io_ctx->set_val( iv_name = 'MANAGERNATIONALITY' iv_value = |{ ls_mg-zznationality }| ).  " REVIEW: BUT000 field names are placeholders

    ENDCASE.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .
*     DATA ls_rt TYPE zif_rak_journey=>ty_option.
*
*    CASE iv_field.
*      WHEN 'LICENSE_LIST'.
*        DATA(lr_school) = NEW zcl_dok_appln_handler_api( ).
*        DATA(lv_login_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
*        lr_school->license_search(
*          EXPORTING
*            iv_bp_applicant = '3000124165'
**            iv_bp_applicant = lv_login_bp
*          IMPORTING
*            et_lic_no_list  = DATA(lt_list) ).
*        DATA: ls_list1 LIKE LINE OF lt_list.
*        IF lt_list IS INITIAL.
*          ls_list1-recnnr = '1234'.
*          ls_list1-recntxt = 'test'.
*          APPEND ls_list1 TO lt_list.
*        ENDIF.
*
*        LOOP AT lt_list INTO DATA(ls_list).
*          CLEAR ls_rt.
*          ls_rt-key =  ls_list-recnnr.
*          SHIFT ls_rt-key LEFT DELETING LEADING '0'.
*          ls_rt-text = ls_list-recntxt.
*          APPEND ls_rt TO rt.
*        ENDLOOP.
**
*        TYPES:
*          BEGIN OF ty_lic_no_list,
*            intreno    TYPE string,
*            recnnr     TYPE string,
*            recntype   TYPE string,
*            recnbeg    TYPE string,
*            recnendabs TYPE string,
*            validfrom  TYPE string,
*            validto    TYPE string,
*            case_id    TYPE string,
*            recntxt     TYPE string,
*          END OF ty_lic_no_list,
*          ty_tt_lic_no_list TYPE STANDARD TABLE OF ty_lic_no_list.
**    DATA: ls_list2 TYPE ty_lic_no_list.
*        DATA(lt_list2) = CORRESPONDING ty_tt_lic_no_list( lt_list ).
*
**        DATA(lv_string) = REDUCE string(
**            INIT str = ||
**            FOR ls_list2 IN lt_list2
**            NEXT str = str && ls_list2 && cl_abap_char_utilities=>cr_lf
**        ).
*        DATA: lv_string TYPE string.
*        CALL FUNCTION 'SWA_STRING_FROM_TABLE'
*          EXPORTING
*            character_table            = lt_list
**           NUMBER_OF_CHARACTERS       =
**           LINE_SIZE                  =
*            keep_trailing_spaces       = 'X'
**           CHECK_TABLE_TYPE           = ' '
*          IMPORTING
*            character_string           = lv_string
*          EXCEPTIONS
*            no_flat_charlike_structure = 1
*            OTHERS                     = 2.
*        IF sy-subrc IS INITIAL.
*          io_ctx->set_val(
*            EXPORTING
*              iv_name  = 'LICENSES'
*              iv_value = lv_string
*          ).
*        ENDIF.
**      ENDIF.
*
*    WHEN OTHERS.
*  ENDCASE.
  endmethod.
ENDCLASS.
