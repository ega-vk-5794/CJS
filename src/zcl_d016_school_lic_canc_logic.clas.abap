class ZCL_D016_SCHOOL_LIC_CANC_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZCL_D016_SCHOOL_LIC_CANC_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    DATA: lv_recnnr TYPE vicncn-recnnr,
          lv_val    TYPE string.

    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.

*        " License, School name, Issued at, Expired at.
        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).
        DATA(lt_licenses) = io_ctx->get_grid_data( 'LICENSES' ).
        rs_data = io_ctx->get_backend_table( 'LICENSES' ).
        REFRESH rs_data-columns[].
        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).


      WHEN 'OWNERS'.
*        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile Number` ) ( `E-mail` ) ).
*
*        DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
*        DATA(lr_licence_api1) = NEW zcl_dok_appln_handler_api( ).
*        lv_recnnr = lv_license.
*        lr_licence_api1->school_details(
*          EXPORTING
*            iv_recnnr         = lv_recnnr
*            iv_form_multlangu = sy-langu
*          IMPORTING
*            et_school_dt      = DATA(ls_school)
*            et_return         = DATA(lt_return)
*           ) .
*
*        LOOP AT ls_school-partner INTO DATA(ls_partner).
*          APPEND VALUE #( ( |{ ls_partner-bp_name_en }| )
*                            ( |{ ls_partner-nationality_en }|   )
*                            ( |{ ls_partner-share_per }|     )
*                            ( |{ ls_partner-mobile_number }|        )
*                            ( |{ ls_partner-email_address }|         ) ) TO rs_data-rows.
*        ENDLOOP.


*      WHEN 'OWNERCHANGES'.
*        " Column order matches the screenshot's "Add Owner" grid: Owner
*        " Name, Nationality, Owner Shares, Owner Phone, Owner Email, Status.
*        rs_data-columns = VALUE #( ( `Owner Name` ) ( `Nationality` ) ( `Owner Shares` ) ( `Owner Phone` ) ( `Owner Email` ) ( `Status` ) ).

        " REVIEW (NOTE 2 in the load report): unlike LICENSES/OWNERS, this
        " is a user-editable working set (add a new owner, mark an
        " existing one for withdrawal), not a straight backend SELECT.
        " Returning whatever has been captured in context so far, same
        " approach as the TREES/BUILDINGS/OWNERSTABLE tables on the other
        " journeys — exact retrieval API unconfirmed.
*        DATA(lt_changes) = io_ctx->get_val( 'OWNERCHANGES' ).   " REVIEW: retrieval API unconfirmed
        " ... deserialize lt_changes into rs_table-rows here ...

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.

    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 3), not omitted by oversight.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_TABLES =
*    .
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SEL' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*    CHECK to_upper( iv_field ) = 'LICENSE_SEL'.

*    DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
*    IF lv_license IS INITIAL.
*      RETURN.
*    ENDIF.

*    CASE iv_field.
*      WHEN 'LICENSE_LIST'.
*        DATA(lv_license_sel) = io_ctx->get_val( 'LICENSE_LIST' ).
*        IF lv_license_sel IS INITIAL.
**          RETURN.
*        ENDIF.
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LICENSE_SEL'
*            iv_value = lv_license_sel
*        ).
* Get School Information
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
**          RETURN.
*        ENDIF.

*        DATA(ls_school) = ls_school_data-school[ 1 ].

*        DATA: ls_school TYPE zst_cs_ega_dok_appln_school .
*
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
*            iv_value = '20201208' "sy-datum "|{ ls_school_data-permit_issue DATE = USER }|
*        ).
**
** LICEXPIRED --> GS_DATA-LICENCE_VALID_TO
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'LICEXPIRED'
*            iv_value = '20221209' "sy-datum "|{ ls_school_data-permit_expire DATE = USER }|
*        ).
*
** applicant_type
** APPLICANTTYPE --> GS_DATA-APPLICANT_TYPE
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'APPLICANTTYPE'
*            iv_value = 'Test Application Type' "CONV #( ls_school_data-applicant_type )
*        ).
**
**SCHOOLNAMEEN --> GS_DATA-SCHOOL-SCHOOL_NAME_EN
*        io_ctx->set_val(
*          EXPORTING
*            iv_name  = 'SCHOOLNAMEEN'
*            iv_value = 'Test School' "CONV #( ls_school-school_name_en )
*        ).
**
** SCHOOLNAMEAR --> GS_DATA-SCHOOL-SCHOOL_NAME_AB
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'SCHOOLNAMEAR'
**            iv_value = CONV #( ls_school-school_name_ab )
**        ).
** TRADELICAUTH --> GS_DATA-SCHOOL-REG_AUTHORITY
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'TRADELICAUTH'
**            iv_value = CONV #( ls_school-reg_authority )
**        ).
**
** CURRICULUM --> GS_DATA-SCHOOL-CURRICULUM
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'CURRICULUM'
**            iv_value = CONV #( ls_school-curriculum )
**        ).
**
** LOCATION --> GS_DATA-SCHOOL-LOCATION
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'LOCATION'
**            iv_value = CONV #( ls_school-location )
**        ).
** CURRICULUMTYPE --> GS_DATA-SCHOOL-CURRICULUM_TYPE
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'CURRICULUMTYPE'
**            iv_value = CONV #( ls_school-curriculum_type )
**        ).
**
** SCHOOLADDRESS -> GS_DATA-SCHOOL-ADRESS
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'SCHOOLADDRESS'
**            iv_value = CONV #( ls_school-adress )
**        ).
**
** TELEPHONE --> GS_DATA-SCHOOL-TELEPHONE
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'TELEPHONE'
**            iv_value = CONV #( ls_school-telephone )
**        ).
** POBOX --> GS_DATA-SCHOOL-POBOX
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'POBOX'
**            iv_value = CONV #( ls_school-pobox )
**        ).
** PARCELID -->   GS_DATA-SCHOOL-PARCEL_ID
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'PARCELID'
**            iv_value = CONV #( ls_school-parcel_id )
**        ).
** Set Owners to IO_CTX to fetch in GET_TABLE method
*        DATA: lv_string TYPE string.
**          rs_data-rows = VALUE zif_rak_journey=>tt_string( FOR ls_row IN lt_owners
**                                   ( ls_row-bp_name_en )
**                                   ( ls_row-nationality_en )
**                                   ( ls_row-share_per )
**                                   ( ls_row-mobile_number )
**                                   ( ls_row-email_address )
**                                ).
*        TYPES: BEGIN OF ty_partner,
*                 name          TYPE text100,
*                 nationality   TYPE natio50,
*                 share_per     TYPE char10,
*                 mobile_number TYPE char20,
*                 email         TYPE text100,
*               END OF ty_partner,
*               ty_t_partner TYPE STANDARD TABLE OF ty_partner WITH EMPTY KEY.
***        DATA(lt_partner) = VALUE ty_t_partner( FOR ls_temp IN ls_school_data-partner
***                                               ( name = ls_temp-bp_name_en
***                                                nationality = ls_temp-nationality_en
***                                               share_per = ls_temp-share_per
***                                               mobile_number = ls_temp-mobile_number
***                                               email = ls_temp-email_address )
***                                             ).
***        CALL FUNCTION 'SWA_STRING_FROM_TABLE'
***          EXPORTING
***            character_table            = lt_partner
****           NUMBER_OF_CHARACTERS       =
****           LINE_SIZE                  =
***            keep_trailing_spaces       = 'X'
****           CHECK_TABLE_TYPE           = ' '
***          IMPORTING
***            character_string           = lv_string
***          EXCEPTIONS
***            no_flat_charlike_structure = 1
***            OTHERS                     = 2.
***        IF sy-subrc IS INITIAL.
***          DATA(lt_rows) = VALUE zif_rak_journey=>tt_string( ( lv_string ) ).
***          io_ctx->set_grid_data(
***            EXPORTING
***              iv_field = 'OWNERS'
***              is_data  = VALUE #(
***                             columns = VALUE #( ( `name` ) ( `nationality` ) ( `Share_per` ) ( `mobile_number` ) ( `email_address` ) )
***                             rows = VALUE #( ( lt_rows ) ) )
***          ).
***        ENDIF.
*
** MANAGERNAME -->   GS_DATA-MANAGER_NAME
**        io_ctx->set_val(
**          EXPORTING
**            iv_name  = 'MANAGERNAME'
**            iv_value = CONV #( ls_school_data- )
**        ).
*      WHEN ''.
*      WHEN OTHERS.
*    ENDCASE.
*
*
*    " REVIEW: replace with the real license/school/manager detail read —
*    " placeholder SELECT shown for the pattern only; real source table(s)
*    " and field names unconfirmed. The OWNERS table itself is read
*    " separately via get_table( 'OWNERS' ) above; this just covers the
*    " context header + read-only school + manager fields.
**    SELECT SINGLE license_no, issued_at, expired_at
**      FROM ztb_dok_licenses
**      WHERE license_no = @lv_license
**      INTO @DATA(ls_lic).
**
**    IF sy-subrc = 0.
**      io_ctx->set_val( iv_name = 'LICNO' iv_value = |{ ls_lic-license_no }| ).
**      io_ctx->set_val( iv_name = 'LICISSUED' iv_value = |{ ls_lic-issued_at DATE = USER }| ).
**      io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_lic-expired_at DATE = USER }| ).
**    ENDIF.
*
*    " REVIEW: populate the read-only school fields (SCHOOLNAMEEN/AR,
*    " TRADELICAUTH, CURRICULUM, LOCATION, TRADELICNO, CURRICULUMTYPE,
*    " SCHOOLADDRESS, TELEPHONE, POBOX, PARCELID) and the manager fields
*    " (MANAGERNAME, MANAGEREID, MANAGERMOBILE, MANAGEREMAIL,
*    " MANAGERNATIONALITY) here from the same selected license/school
*    " record — placeholders shown for the pattern only, real source
*    " fields unconfirmed.
**     io_ctx->set_val( iv_name = 'LICNO' iv_value = '12345678' ). "|{ ls_school-name_en }| ).
    " io_ctx->set_val( iv_name = 'MANAGERNAME'  iv_value = |{ ls_school-manager_name }| ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate - it refuses a submit while PAYFEE is not
*   PAID. It has to run before the CHECK below, because a failing CHECK leaves
*   the method and would take the gate with it.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

    CHECK iv_step = 1.   " zero-based: step 2 "School name" in the wizard

    IF io_ctx->get_val( 'NEWNAMEEN1' ) = io_ctx->get_val( 'SCHOOLNAMEEN' )
   AND io_ctx->get_val( 'NEWNAMEAR1' ) = io_ctx->get_val( 'SCHOOLNAMEAR' ).
      rt = VALUE #( BASE rt ( type = 'Error' text = 'The new name must be different from the school''s current name.' ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.
*
    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
**
*    zcl_ega_cj_utility=>get_bp(
*      EXPORTING
*        qv_key  = user_data
*      IMPORTING
*        loginbp = DATA(loginbp)
*        rolebp  = DATA(rolebp)
*        role    = DATA(role)
*    ).
**
*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).

    DATA: lv_loginbp TYPE bu_partner.
    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
    io_ctx->set_val( iv_name = 'OWNER_BP' iv_value = |{ lv_loginbp }| ).

    NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
      EXPORTING
        iv_bp_id      = CONV bu_partner( lv_loginbp )
      IMPORTING
        es_bp_details = DATA(ls_bp_real) ).
    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = COND #(
      WHEN sy-langu <> 'E' AND ls_bp_real-bp_name_ar IS NOT INITIAL
      THEN CONV string( ls_bp_real-bp_name_ar )
      ELSE CONV string( ls_bp_real-bp_name ) ) ).
    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( ls_bp_real-emirates_id ) ).
    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
*  EXPORTING
*    IO_CTX  =
*    IO_VIEW =
*    .
*    super->zif_rak_journey_logic~on_render_start(
*     io_ctx  = io_ctx
*     io_view = io_view
*   ).
*    CHECK io_ctx->get_step( ) = owner_step( io_ctx ).
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .
  endmethod.


  METHOD zif_rak_journey_logic~on_value_help.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .

*    DATA ls_rt TYPE zif_rak_journey=>ty_option.
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
*
*        lt_list = VALUE #(
*          ( recnnr = '2400087'
*            recntxt = 'RAK Academy EN3'
*            validfrom = '20250910'
*            validto = '99991231' )
*
*          ( recnnr = '2400144'
*            recntxt = 'Sheikh saud bin saqr educational charitable private school branch-2'
*            validfrom = '20260928'
*            validto = '99991231' )
*
*          ( recnnr = '2500001'
*            recntxt = 'Test School'
*            validfrom = '20261103'
*            validto = '99991231' )
*
*          ( recnnr = '2500002'
*            recntxt = 't123332'
*            validfrom = '20261104'
*            validto = '99991231' )
*
*          ( recnnr = '2500003'
*            recntxt = 'Indian Private School B1'
*            validfrom = '20261104'
*            validto = '99991231' )
*
*          ( recnnr = '2500004'
*            recntxt = 'UK School'
*            validfrom = '20261112'
*            validto = '99991231' )
*
*          ( recnnr = '2500005'
*            recntxt = 'b111'
*            validfrom = '20261112'
*            validto = '99991231' )
*
*          ( recnnr = '2500006'
*            recntxt = 'aassas1'
*            validfrom = '20261211'
*            validto = '99991231' )
*        ).
*
*
*
*
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
**          SHIFT ls_rt-key LEFT DELETING LEADING '0'.
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
*      WHEN OTHERS.
*    ENDCASE.

  ENDMETHOD.
ENDCLASS.
