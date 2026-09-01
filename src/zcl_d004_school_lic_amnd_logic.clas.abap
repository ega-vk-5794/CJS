class ZCL_D004_SCHOOL_LIC_AMND_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  constants C_OWN_ADD type STRING value 'OWNER_ADD' ##NO_TEXT.
  constants C_BLOB type STRING value 'OWNER_BLOB' ##NO_TEXT.

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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_BEFORE_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
    redefinition .
protected section.
private section.

  types:
    begin of ty_owner,
   IDENTIFICATION_POP TYPE string,
   EMIRATES_ID_POP TYPE string,
   DATE_OF_BIRTH_POP TYPE string,
   NATIONALITY_POP TYPE string,
   SHARES_POP         TYPE string,
   EMI_COPY_POP    TYPE string,
   end of ty_owner .
  types:
    tt_owner TYPE STANDARD TABLE OF ty_owner WITH EMPTY KEY .

  constants:
    c_rowsep TYPE c LENGTH 1 value '|' ##NO_TEXT.
  constants:
    c_colsep TYPE c LENGTH 1 value '~' ##NO_TEXT.
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

  methods OWNER_STEP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
    returning
      value(RV_STEP) type I .
  methods BLOB_READ
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
    returning
      value(RT) type TT_OWNER .
  methods RENDER_OWN_LIST
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_VIEW type ref to Z2UI5_CL_XML_VIEW .
  methods OWN_FORM_LOAD
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
  methods RENDER_OWN_POPUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_POPUP type ref to Z2UI5_CL_XML_VIEW .
  methods OWN_FORM_SAVE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods OWN_SEARCH
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods OWN_DELETE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING .
ENDCLASS.



CLASS ZCL_D004_SCHOOL_LIC_AMND_LOGIC IMPLEMENTATION.
  METHOD zif_rak_journey_logic~get_table.

    DATA: lv_recnnr TYPE vicncn-recnnr,
          lv_val    TYPE string.

    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.

        DATA(lt_licenses) = io_ctx->get_grid_data( 'LICENSES' ).
        rs_data = io_ctx->get_backend_table( 'LICENSES' ).
        DATA(lt_mat) = blob_read( io_ctx ).
****        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).
****
****        DATA(lv_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
****        DATA(lr_licence_api) = NEW zcl_dok_appln_handler_api( ).
****        DATA lv_login_bp TYPE  bu_partner.
****        lv_login_bp = lv_bp.
****        lr_licence_api->get_all_school_licenses(
****                                 EXPORTING
****                                   iv_partner             = lv_login_bp
****                                 IMPORTING
****                                   et_all_school_licenses = DATA(lt_license) ).
****        SORT lt_license BY recnnr.
****        LOOP AT lt_license ASSIGNING FIELD-SYMBOL(<lfs_license>).
****          APPEND VALUE #( ( |{ <lfs_license>-recnnr }| )
****                         ( |{ <lfs_license>-recntxt }| )
****                         ( |{ <lfs_license>-recnbeg DATE = USER }| )
****                         ( |{ <lfs_license>-recnendabs DATE = USER }| ) ) TO rs_data-rows.
****        ENDLOOP.
        " REVIEW: replace with the real school-license read (the export
        " names FM ZFM_EGA_CJ_FW_READ_TABLE_DATAN / context LICENCES).
*        DATA(lv_owner_bp) = io_ctx->get_val( 'OWNER_BP' ).
*        SELECT license_no, school_name, issued_at, expired_at
*          FROM ztb_dok_licenses                         "#EC CI_NOORDBY
*          INTO TABLE @DATA(lt_lic)
*          WHERE partner = @lv_owner_bp.
*
*        LOOP AT lt_lic INTO DATA(ls_lic).
*          APPEND VALUE #( ( |{ ls_lic-license_no }| )
*                          ( |{ ls_lic-school_name }| )
*                          ( |{ ls_lic-issued_at DATE = USER }| )
*                          ( |{ ls_lic-expired_at DATE = USER }| ) ) TO rs_data-rows.
*        ENDLOOP.

      WHEN 'OWNERS'.
**        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile Number` ) ( `E-mail` ) ).
**
**        DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
**        DATA(lr_licence_api1) = NEW zcl_dok_appln_handler_api( ).
**        lv_recnnr = lv_license.
**        lr_licence_api1->school_details(
**          EXPORTING
**            iv_recnnr         = lv_recnnr
**            iv_form_multlangu = sy-langu
**          IMPORTING
**            et_school_dt      = DATA(ls_school)
**            et_return         = DATA(lt_return)
**           ) .
**
**        LOOP AT ls_school-partner INTO DATA(ls_partner).
**          APPEND VALUE #( ( |{ ls_partner-bp_name_en }| )
**                            ( |{ ls_partner-nationality_en }|   )
**                            ( |{ ls_partner-share_per }|     )
**                            ( |{ ls_partner-mobile_number }|        )
**                            ( |{ ls_partner-email_address }|         ) ) TO rs_data-rows.
**        ENDLOOP.
        " REVIEW: replace with the real current-owners read for the
        " SELECTED license (export context OWNERS_DISP).
****        SELECT partner_name, nationality, share_pct, mobile, email
****          FROM ztb_dok_owners                           "#EC CI_NOORDBY
****          WHERE license_no = @lv_license   "io_ctx->get_val( 'LICENSE_SEL' )
****          INTO TABLE @DATA(lt_own).
****
****        LOOP AT lt_own INTO DATA(ls_own).
****          APPEND VALUE #( ( |{ ls_own-partner_name }| )
****                          ( |{ ls_own-nationality }|   )
****                          ( |{ ls_own-share_pct }|     )
****                          ( |{ ls_own-mobile }|        )
****                          ( |{ ls_own-email }|         ) ) TO rs_data-rows.
****        ENDLOOP.

      WHEN 'OWNERCHANGES'.
        " Column order matches the screenshot's "Add Owner" grid: Owner
        " Name, Nationality, Owner Shares, Owner Phone, Owner Email, Status.
        rs_data-columns = VALUE #( ( `Owner Name` ) ( `Nationality` ) ( `Owner Shares` ) ( `Owner Phone` ) ( `Owner Email` ) ( `Status` ) ).

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
    DATA: lv_recnnr TYPE vicncn-recnnr,
          lv_val    TYPE string.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
**    DELETE ct_kv WHERE key = 'LICENSE_SEL'.
*    DATA(lr_licence_api) = NEW zcl_dok_appln_handler_api( ).
*    LOOP AT ct_kv INTO DATA(ls_kv) WHERE key = 'LICENSE_SEL'.
*      lv_recnnr = ls_kv-value.
*      lr_licence_api->school_details(
*        EXPORTING
*          iv_recnnr         = lv_recnnr
*          iv_form_multlangu = sy-langu
*        IMPORTING
*          et_school_dt      = DATA(ls_school)
*          et_return         = DATA(lt_return)
*         ) .
*      IF ls_school IS NOT INITIAL.
*        lv_val = ls_school-permit_id.
*        io_ctx->set_val( iv_name = 'LICNO' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school-permit_issue.
*        io_ctx->set_val( iv_name = 'LICISSUED' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school-permit_expire.
*        io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school-appln_type.
*        io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = lv_val ).
*        CLEAR lv_val.
*       LOOP AT ls_school-school into data(ls_school_details).
*        lv_val = ls_school_details-school_name_en.
*        io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-school_name_ab.
*        io_ctx->set_val( iv_name = 'SCHOOLNAMEAR' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-reg_authority_tx.
*        io_ctx->set_val( iv_name = 'TRADELICAUTH' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-curriculum_tx.
*        io_ctx->set_val( iv_name = 'CURRICULUM' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-location_tx.
*        io_ctx->set_val( iv_name = 'LOCATION' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-curriculum_type.
*        io_ctx->set_val( iv_name = 'CURRICULUMTYPE' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-trade_lic.
*        io_ctx->set_val( iv_name = 'TRADELICNO' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-adress.
*        io_ctx->set_val( iv_name = 'SCHOOLADDRESS' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-telephone.
*        io_ctx->set_val( iv_name = 'TELEPHONE' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-pobox.
*        io_ctx->set_val( iv_name = 'POBOX' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_school_details-parcel_id.
*        io_ctx->set_val( iv_name = 'PARCELID' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        ENDLOOP.
*        READ TABLE ls_school-partner into data(ls_partner) with key part_type = '4'.
*        IF sy-subrc is INITIAL.
*           lv_val = ls_partner-bp_name_en.
*        io_ctx->set_val( iv_name = 'MANAGERNAME' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_partner-emirates_id.
*        io_ctx->set_val( iv_name = 'MANAGEREID' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_partner-mobile_number.
*        io_ctx->set_val( iv_name = 'MANAGERMOBILE' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_partner-email_address.
*        io_ctx->set_val( iv_name = 'MANAGEREMAIL' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        lv_val = ls_partner-nationality_en.
*        io_ctx->set_val( iv_name = 'MANAGERNATIONALITY' iv_value = lv_val ).
*        CLEAR lv_val.
*
*        ENDIF.
*      ENDIF.
*
*    ENDLOOP.

    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 4), not omitted by oversight.
  ENDMETHOD.


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
    " same selected license/school record. Note TRADELICAUTH/CURRICULUM/
    " LOCATION/CURRICULUMTYPE are editable SELECT fields on this journey
    " (see load report NOTE 3) — set their current values here too so the
    " dropdowns open pre-populated, but do not treat them as read-only.
    " io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = |{ ls_school-name_en }| ).
    " io_ctx->set_val( iv_name = 'MANAGERNAME'  iv_value = |{ ls_school-manager_name }| ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

**    CHECK iv_step = 1.   " zero-based: step 2 "Owner" in the wizard

**    DATA(lv_changes) = io_ctx->get_val( 'OWNERCHANGES' ).
**    IF lv_changes IS INITIAL.
**      rt = VALUE #( ( type = 'Error' text = 'Add or mark at least one owner for withdrawal before continuing.' ) ).
**    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
** CALL METHOD super->zif_rak_journey_logic~on_init
**      EXPORTING
**        io_ctx = io_ctx.
**    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
***    DATA(user_data) = io_ctx->get_val( iv_name = 'PARAM1' ).
***    user_data = ''.
**    zcl_ega_cj_utility=>get_bp(
**      EXPORTING
**        qv_key  = user_data
**      IMPORTING
**        loginbp = DATA(loginbp)
**        rolebp  = DATA(rolebp)
**        role    = DATA(role)
**    ).
**
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000000049' ).
**
***    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
**    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
***    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
**    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
**
***    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
**    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).
**


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

  endmethod.


  METHOD zif_rak_journey_logic~on_value_help.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .
    DATA(lv_step) = io_ctx->get_step( ).
    IF iv_field = 'LICENSE_SEL'.

      DATA(lv_bp) = io_ctx->get_val( iv_name = 'LOGIN_BP' ).
      DATA(lr_licence_api) = NEW zcl_dok_appln_handler_api( ).
      DATA lv_login_bp TYPE  bu_partner.
      lv_login_bp = lv_bp.
      lr_licence_api->get_all_school_licenses(
                               EXPORTING
                                 iv_partner             = lv_login_bp
                               IMPORTING
                                 et_all_school_licenses = DATA(lt_license) ).
      SORT lt_license BY recnnr.
      DELETE lt_license WHERE recnnr IS INITIAL.
      rt = VALUE #(
               FOR ls_license IN lt_license
                ( key = ls_license-recnnr text =  ls_license-recntxt )
                  ).
    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES.
CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
  EXPORTING
    IO_CTX    = IO_CTX
  CHANGING
    CT_TABLES = CT_TABLES
    .
 DATA(lv_sel) = io_ctx->get_val( 'LICENSE_SEL' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  endmethod.


  method BLOB_READ.
    DATA(lv_blob) = io_ctx->get_val( c_blob ).
    CHECK lv_blob IS NOT INITIAL.

    SPLIT lv_blob AT c_rowsep INTO TABLE DATA(lt_row).
    LOOP AT lt_row INTO DATA(lv_row).
      IF lv_row IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT lv_row AT c_colsep INTO DATA(lv_m) DATA(lv_q) DATA(lv_u).
      IF lv_m IS INITIAL.
        CONTINUE.
      ENDIF.
**      APPEND VALUE #( mtype = lv_m qty = lv_q unit = lv_u ) TO rt.
    ENDLOOP.
  endmethod.


  method OWNER_STEP.
     rv_step = -1.
    DATA lv_ix TYPE i.
    DATA(ls_cfg) = io_ctx->get_config( ).
    LOOP AT ls_cfg-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF to_upper( ls_f-name ) = 'TELEPHONE'.
          rv_step = lv_ix.
          RETURN.
        ENDIF.
      ENDLOOP.
      lv_ix = lv_ix + 1.
    ENDLOOP.
  endmethod.


  METHOD zif_rak_journey_logic~on_popup_event.

    super->zif_rak_journey_logic~on_popup_event(
         io_ctx   = io_ctx
         iv_id    = iv_id
         iv_event = iv_event ).

    CASE iv_event.
      WHEN c_evt_ownew.
        own_form_load( io_ctx ).          " no id = a new owner
        io_ctx->open_popup( c_pop_own ).

      WHEN c_evt_ownsr.
        own_search( io_ctx ).

      WHEN c_evt_ownok.

       IF io_ctx->get_val( c_own_name )  IS INITIAL
           OR io_ctx->get_val( c_own_eid ) IS INITIAL
           OR io_ctx->get_val( c_dob ) IS INITIAL
           OR io_ctx->get_val( c_own_nat ) IS INITIAL.

          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Kindly fill required details.' ).
          RETURN.
        ELSEIF io_ctx->get_val( c_own_share ) IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Kindly enter shares as 100' ).
          RETURN.
        ENDIF.

*       784-XXXX-XXXXXXX-X - the same shape as the field's own placeholder.
        DATA(lv_eid_chk) = condense( io_ctx->get_val( c_own_eid ) ).
        FIND REGEX '^784-\d{4}-\d{7}-\d$' IN lv_eid_chk.
        IF sy-subrc <> 0.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Emirates ID must be in the format 784-XXXX-XXXXXXX-X.' ).
          RETURN.
        ENDIF.

        own_form_save( io_ctx ).

        io_ctx->close_popup( ). "Close pop-up screen after adding data
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |{ io_ctx->get_val( c_own_name ) } added to the owner list.| ).


*       Validate before writing. Closing on an incomplete row and complaining
*       behind the dialog makes the citizen reopen it and guess what was wrong.
*       Identification and Shares carry the same rakReq marker as Emirates ID
*       in RENDER_OWN_POPUP( ) but used to slip through unchecked here.
***        IF io_ctx->get_val( c_own_name )  IS INITIAL
***           OR io_ctx->get_val( c_own_eid )   IS INITIAL
***           OR io_ctx->get_val( c_own_share ) IS INITIAL.
***          io_ctx->add_msg( iv_type = 'Warning'
***                           iv_text = 'Kindly fill required details.' ).
***          RETURN.
***        ENDIF.
***
****       784-XXXX-XXXXXXX-X - the same shape as the field's own placeholder.
***        DATA(lv_eid_chk) = condense( io_ctx->get_val( c_own_eid ) ).
***        FIND REGEX '^784-\d{4}-\d{7}-\d$' IN lv_eid_chk.
***        IF sy-subrc <> 0.
***          io_ctx->add_msg( iv_type = 'Warning'
***                           iv_text = 'Emirates ID must be in the format 784-XXXX-XXXXXXX-X.' ).
***          RETURN.
***        ENDIF.
***
***        own_form_save( io_ctx ).
***        io_ctx->close_popup( ).
***        io_ctx->add_msg( iv_type = 'Success'
***                         iv_text = |{ io_ctx->get_val( c_own_name ) } added to the owner list.| ).

      WHEN 'CANCEL'.
        io_ctx->close_popup( ).
      WHEN c_evt_owncx.
        io_ctx->close_popup( ).

      WHEN OTHERS.
*       Row actions carry their subject in the event id, same as D001's owner
*       list. These were rendered on every row (RENDER_OWN_LIST) with no
*       handler at all - Edit and Delete pressed and did nothing.
        IF iv_event CP 'OWN_EDIT_*'.
          own_form_load( io_ctx = io_ctx iv_id = substring( val = iv_event off = 9 ) ).
          io_ctx->open_popup( c_pop_own ).
          RETURN.
        ENDIF.
        IF iv_event CP 'OWN_DEL_*'.
          own_delete( io_ctx = io_ctx iv_id = substring( val = iv_event off = 8 ) ).
          RETURN.
        ENDIF.
    ENDCASE.

  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP.
super->zif_rak_journey_logic~on_render_popup(
      io_ctx   = io_ctx
      io_popup = io_popup
      iv_id    = iv_id
    ).

**    CHECK iv_id = c_pop_mat.
    CASE iv_id.
      when c_pop_own.
      render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
      RETURN.
      WHEN c_own_add.


        dialog_form(
          io_ctx     = io_ctx
          io_popup   = io_popup
          iv_title   = 'Add Owner'
          it_fields  = VALUE #(
                                ( name = 'OWNER_DETAIL'        label = 'Detail' type = 'SEARCH' )
                                ( name = 'IDENTIFICATION_POP'  label = 'Identification' )
                                ( name = 'EMIRATES_ID_POP'     label = 'Emirates Id' )
                                ( name = 'DATE_OF_BIRTH_POP'   label = 'Date of Birth' )
                                ( name = 'NATIONALITY_POP'     label = 'Nationality' )
                                ( name = 'SHARES_POP'          label = 'Shares' )
                                ( name = 'EMI_COPY_POP'        label = 'Emirates ID copy' type = 'UPLOAD' )
*                                ( name = 'DATE_OF_BIRTH_POP' label = 'Date of Birth' )
*                                ( name = 'DATE_OF_BIRTH_POP' label = 'Date of Birth' )
                                 )
          iv_ok_text = 'Add'
          iv_ok_evt  = c_own_add ).

      WHEN OTHERS.
    ENDCASE.
  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START.

     super->zif_rak_journey_logic~on_render_start(
      io_ctx  = io_ctx
      io_view = io_view
    ).
    CHECK io_ctx->get_step( ) = owner_step( io_ctx ).

**    DATA(lo_bar) = io_view->hbox( alignitems = 'Center'
**                                  class      = 'sapUiSmallMarginBegin sapUiTinyMarginTop' ).
**    lo_bar->button( text  = 'Add Owner'
**                    icon  = 'sap-icon://add'
**                    type  = 'Emphasized'
**                    press = io_ctx->event( c_own_add ) ).
  endmethod.


  METHOD zif_rak_journey_logic~on_render_before_field.
    CALL METHOD super->zif_rak_journey_logic~on_render_before_field
      EXPORTING
        io_ctx   = io_ctx
        io_view  = io_view
        is_field = is_field.

**    CHECK is_field-name = 'OWNERS_SEARCH'.
**    DATA(lo_bar) = io_view->hbox(   justifycontent = 'End'
**                                    alignitems = 'Center'
**                                    class      = 'sapUiSmallMarginBegin sapUiTinyMarginTop' ).
**    lo_bar->button( text  = 'Add Owner'
**                    icon  = 'sap-icon://add'
**                    type  = 'Emphasized'
**                    press = io_ctx->event( c_own_add ) ).
  ENDMETHOD.


  method OWN_FORM_LOAD.
       io_ctx->set_val( iv_name = c_own_name  iv_value = '' ).
    io_ctx->set_val( iv_name = c_own_eid   iv_value = '' ).
    io_ctx->set_val( iv_name = c_own_nat   iv_value = '' ).
    io_ctx->set_val( iv_name = c_own_share iv_value = '' ).
    io_ctx->set_val( iv_name = 'NAME_POP'      iv_value = '' ).
    io_ctx->set_val( iv_name = 'TELEPHONE_POP' iv_value = '' ).
    io_ctx->set_val( iv_name = 'EMAIL_POP'     iv_value = '' ).

    IF iv_id IS INITIAL.
*     New owner. The id is minted NOW and not on save, because the uploaders in
*     the dialog key their files on it - a file attached before the row exists
*     still has to belong to the right person. This used to mint the SAME
*     fixed id ('YFS002') for every new owner, so OWN_FORM_SAVE's "does this
*     id already exist" check matched the first owner every time and every
*     later Add overwrote them instead of appending - a timestamp is unique
*     per press.
      DATA lv_ts TYPE timestampl.
      GET TIME STAMP FIELD lv_ts.
      io_ctx->set_val( iv_name  = c_own_id
                       iv_value = |{ lv_ts }| ).
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).
*   By column name, matching what OWN_FORM_SAVE( ) writes. This read eight
*   positions from a five-column grid, and from position 6 it was off by one
*   against the writer as well - so the phone arrived in the name field, the
*   e-mail in the phone field, and the last three came back empty.
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    LOOP AT ls_g-rows INTO DATA(lt_r).
      CHECK zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns
                                           it_row  = lt_r
                                           iv_name = 'NAME' ) = iv_id.

*     Not C_OWN_NAME - that constant holds 'IDENTIFICATION_POP', which is the
*     ID-type SELECT, not a name field. Writing the owner's name into it leaves
*     the dropdown matching no key, so it renders blank.
      io_ctx->set_val( iv_name = 'NAME_POP'
        iv_value = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'NAME' ) ).
      io_ctx->set_val( iv_name = c_own_nat
        iv_value = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'NATIONALITY' ) ).
      io_ctx->set_val( iv_name = c_own_share
        iv_value = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'SHARE_PER' ) ).
      io_ctx->set_val( iv_name = 'TELEPHONE_POP'
        iv_value = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'MOBILE_NUMBER' ) ).
      io_ctx->set_val( iv_name = 'EMAIL_POP'
        iv_value = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'EMAIL_ADDRESS' ) ).
      io_ctx->set_val( iv_name = c_own_eid
        iv_value = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'EMIRATES_ID' ) ).
      EXIT.
    ENDLOOP.
  endmethod.


  METHOD own_form_save.
    DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.

*   OWNERS_SEARCH has FIVE columns, from its DEFAULT_VAL spec - there are no
*   ZRAK_T_JNY_COL rows for it, so GRID_COLS( ) falls through to the packed one:
*
*     PARTNER | NATIONALITY | SHARE_PER | MOBILE_NUMBER | EMAIL_ADDRESS
*
*   Seven cells used to be APPENDed into those five. SET_GRID_DATA( ) takes cell
*   N for configured column N, so everything landed two places out and the last
*   two were dropped: SHARE_PER received the owner's EMIRATES ID. The backend
*   reads the columns by name, parsed '784-1956-6257327-7' as an amount, and
*   refused the step with "The Total of the Share (0.00%) is not equal to 100%"
*   - while the list on screen showed 100, because it read the same positions
*   back and the two shifts cancelled.
*
*   By name, so the row follows the spec instead of assuming it. LOGIN_BP and the
*   Emirates ID have no column here and are simply not stored; PARTNER carries
*   the owner's NAME, which is what its own label and the OWNERS_DISP grid beside
*   it both say it holds.
    DATA(lt_new_row) = zcl_rak_journey_util=>blank_row( ls_g-columns ).

*   NAME carries the owner's name; PARTNER carries the BP number. They were the
*   same column while the spec had PARTNER labelled "Owner Name", which is how
*   the partner number ended up rendered as the name.
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'NAME'
                iv_val  = io_ctx->get_val( 'NAME_POP' )
      CHANGING  ct_row  = lt_new_row ).
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'PARTNER'
                iv_val  = io_ctx->get_val( 'OWNER_PARTNER' )
      CHANGING  ct_row  = lt_new_row ).
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'NATIONALITY'
                iv_val  = io_ctx->get_val( c_own_nat )
      CHANGING  ct_row  = lt_new_row ).
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'SHARE_PER'
                iv_val  = io_ctx->get_val( c_own_share )
      CHANGING  ct_row  = lt_new_row ).
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'MOBILE_NUMBER'
                iv_val  = io_ctx->get_val( 'TELEPHONE_POP' )
      CHANGING  ct_row  = lt_new_row ).
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'EMAIL_ADDRESS'
                iv_val  = io_ctx->get_val( 'EMAIL_POP' )
      CHANGING  ct_row  = lt_new_row ).

*   No EMIRATES_ID column on this grid, so the Emirates ID is not stored. Add a
*   ZRAK_T_JNY_COL row named EMIRATES_ID and the line below starts persisting it
*   with no further code change.
    zcl_rak_journey_util=>put_cell(
      EXPORTING it_cols = ls_g-columns iv_name = 'EMIRATES_ID'
                iv_val  = io_ctx->get_val( c_own_eid )
      CHANGING  ct_row  = lt_new_row ).

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns
                                        it_row  = lt_r
                                        iv_name = 'NAME' ) = lv_id.
        lv_found = abap_true.
        APPEND lt_new_row TO ls_new-rows.
      ELSE.
        APPEND lt_r TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      APPEND lt_new_row TO ls_new-rows.
    ENDIF.

    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
  ENDMETHOD.


  METHOD own_search.

    DATA: lv_recnnr TYPE vicncn-recnnr,
          lv_val    TYPE string.
*   Search fills the form from the business partner record. It does NOT create
*   the row - that is still Add - so a citizen can search, look at what came
*   back, and close without having changed anything.
    DATA(lv_eid) = condense( io_ctx->get_val( c_own_eid ) ).
    IF strlen( lv_eid ) < 3.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Type at least 3 characters of the Emirates ID first.' ).
      RETURN.
    ENDIF.

*   Exactly the two columns the engine's own BP search reads, and no more.
*   BUT000 carries nationality under different names across landscapes, and a
*   demo is the wrong place to guess at one: an author who wants it can add the
*   column here once they have checked which it is in their system.
*
*   YFS002 is the Emirates ID type here - the same one the engine defaults to.
*   A journey looking up trade licences instead would read the id type from a
*   field rather than hard-coding it.
    SELECT SINGLE a~partner, a~zzfull_name_eng AS name
      FROM but000 AS a
      INNER JOIN but0id AS b
        ON  b~partner = a~partner
        AND b~type    = 'YFS002'
      WHERE b~idnumber = @lv_eid
      INTO @DATA(ls_bp).

    IF ls_bp IS NOT INITIAL.
**DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
      DATA(lr_licence_api1) = NEW zcl_dok_appln_handler_api( ).
      lv_recnnr = lv_eid.
      lr_licence_api1->get_bp_details(
        EXPORTING
          iv_bp_id         = ls_bp-partner
*        iv_form_multlangu = sy-langu
        IMPORTING
          es_bp_details      = DATA(ls_bp_details)
*        et_return         = DATA(lt_return)
         ) .
    ENDIF.

    io_ctx->set_val( iv_name = 'IDENTIFICATION_POP' iv_value = 'YFS002'  ).
    lv_val = ls_bp_details-bp_name_en.
    IF lv_val IS INITIAL.
      lv_val = ls_bp_details-bp_name_ar.
    ENDIF.
    io_ctx->set_val( iv_name = 'NAME_POP' iv_value = lv_val  ).
    CLEAR lv_val.
    lv_val = ls_bp_details-mobile_number.
    io_ctx->set_val( iv_name = 'TELEPHONE_POP' iv_value = lv_val  ).
    CLEAR lv_val.
    lv_val = ls_bp_details-email_address.
    io_ctx->set_val( iv_name = 'EMAIL_POP' iv_value = lv_val  ).
    CLEAR lv_val.
    lv_val = ls_bp_details-nationality_en.

    io_ctx->set_val( iv_name = 'NATIONALITY_POP' iv_value = lv_val  ).
**    LOOP AT ls_school-partner INTO DATA(ls_partner).
**      lv_val = ls_partner-bp_name_en.
**      io_ctx->set_val( iv_name = 'NAME_POP' iv_value = lv_val  ).
**      CLEAR lv_val.
**      lv_val = ls_partner-mobile_number.
**      io_ctx->set_val( iv_name = 'TELEPHONE_POP' iv_value = lv_val  ).
**      CLEAR lv_val.
**      lv_val = ls_partner-email_address.
**      io_ctx->set_val( iv_name = 'EMAIL_POP' iv_value = lv_val  ).
**      CLEAR lv_val.
**      lv_val = ls_partner-nationality_en.
**      io_ctx->set_val( iv_name = 'NATIONALITY_POP' iv_value = lv_val  ).
**    ENDLOOP.


    IF sy-subrc <> 0.
*     Say what was searched for. "Not found" on its own leaves the citizen
*     wondering whether the ID was wrong or the search was.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = |No business partner holds Emirates ID { lv_eid }. | &&
                                 |Type the details in by hand, or check the number.| ).
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = c_own_name iv_value = CONV string( ls_bp-name ) ).
    io_ctx->add_msg( iv_type = 'Success'
                     iv_text = |Found { ls_bp-name } ({ ls_bp-partner }). | &&
                               |Add the nationality and shares, then press Add.| ).
  ENDMETHOD.


  METHOD render_own_list.
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    DATA(lo_hd) = io_view->hbox( justifycontent = 'SpaceBetween'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
    lo_hd->title( text = 'Owner' class = 'rakBlkTitle' ).
    lo_hd->button( text  = 'Add Owner'
                   type  = 'Emphasized'
                   icon  = 'sap-icon://add'
                   press = io_ctx->event( c_evt_ownew ) ).

    DATA(lo_t)  = io_view->table( alternaterowcolors = abap_true ).
    DATA(lo_cl) = lo_t->columns( ).
    lo_cl->column( )->text( 'Owner Name' ).
    lo_cl->column( )->text( 'Nationality' ).
    lo_cl->column( )->text( 'Owner Shares' ).
    lo_cl->column( )->text( 'Documents' ).
    lo_cl->column( halign = 'End' )->text( '' ).

*   Read once, not once per row - a ~240-row T005T select.
    DATA(lt_nat) = zcl_rak_journey_util=>nationalities( ).

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
*     By column name. These five positions happened to line up with what the
*     writer produced, which is why the list looked correct while the values sat
*     in the wrong named columns and the backend read a share of nought.
      DATA(lv_nam) = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'NAME' ).
      DATA(lv_eid) = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'EMIRATES_ID' ).
      DATA(lv_shr) = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'SHARE_PER' ).
      DATA(lv_id)  = lv_nam.

*     The row keeps LAND1; show the country. An unknown code falls back to
*     itself rather than rendering blank - 'AW' on screen was the raw code.
      DATA(lv_natkey) = zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = 'NATIONALITY' ).
      DATA(lv_nat)    = lv_natkey.
      IF lv_natkey IS NOT INITIAL.
        lv_nat = VALUE #( lt_nat[ key = lv_natkey ]-text DEFAULT lv_natkey ).
      ENDIF.

*     How many files this owner has. Counting them here is the only way the
*     citizen can see, from the list, whose documents are still missing.
      DATA lv_docs TYPE i.
      CLEAR lv_docs.
      LOOP AT io_ctx->get_attachment_files( ) INTO DATA(ls_af).
        IF ls_af-identifier1 CS |_{ lv_id }|.
          lv_docs = lv_docs + 1.
        ENDIF.
      ENDLOOP.

      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
*     Name over Emirates ID, as the legacy screen had it.
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_nam ).
      lo_nm->text( text = lv_eid class = 'rakRecMeta' ).
      lo_cells->text( lv_nat ).
      lo_cells->text( lv_shr ).
      lo_cells->object_status(
        text  = |{ lv_docs } file(s)|
        state = COND #( WHEN lv_docs > 0 THEN 'Success' ELSE 'Warning' )
        icon  = COND #( WHEN lv_docs > 0 THEN 'sap-icon://attachment' ELSE 'sap-icon://alert' ) ).
*     Two buttons rather than the legacy overflow menu: one press instead of
*     two, and nothing hidden behind an icon a citizen has to discover.
      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = 'Edit owner details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_id }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_id }| ) ).
    ENDLOOP.

    IF ls_g-rows IS INITIAL.
      io_view->message_strip( text     = 'No owners yet. Press Add Owner to enter the first one.'
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiSmallMarginTop' ).
    ENDIF.
  ENDMETHOD.


  METHOD render_own_popup.


*   ONE dialog: the owner's details and their documents. No drill-down, no
*   second popup - the list is on the step behind and this is the form that
*   adds one line to it.
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = 'Owner' contentwidth = '54rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

    lo_c->title( text = 'Owner Details' class = 'rakBlkTitle' ).

*   Same two-column SimpleForm/ResponsiveGridLayout combination DIALOG_FORM( )
*   uses in ZCL_RAK_JOURNEY_LOGIC (it cannot be called directly here - it owns
*   and closes its own dialog, with no room for the Documents section below -
*   but its layout is copied so this reads like every other popup). Search
*   moves off the section header and onto the Emirates ID field's own
*   value-help icon, the same F4_EVT affordance DIALOG_FORM( ) offers per
*   field; pressing it or Enter both still fire C_EVT_OWNSR into the
*   on_popup_event handler below, unchanged.
    DATA(lo_form) = lo_c->simple_form( editable                = abap_true
                                       layout                  = 'ResponsiveGridLayout'
                                       columnsxl               = '2'
                                       columnsl                = '2'
                                       columnsm                = '2'
                                       labelspanxl             = '12'
                                       labelspanl              = '12'
                                       labelspanm              = '12'
                                       adjustlabelspan         = 'false'
                                       singlecontainerfullsize = abap_false
      )->content( ns = 'form' ).

    lo_form->label( text = 'Identification' required = abap_true ).
*   Emirates ID is the only option, and OWN_FORM_LOAD now defaults it - so
*   there is nothing left for the citizen to pick from this dropdown.
**    DATA(lo_nat1) =
    lo_form->combobox( selectedkey = io_ctx->bind( c_own_name )
**                        editable    = abap_false
                        placeholder = 'select'
      )->item( key = '1'     text = 'Emirates ID' ).
*      )->item( key = '2'    text = 'Passport' ).

    lo_form->label( text = 'Emirates ID' required = abap_true ).
*   The search icon and Enter both do the same thing. Somebody who has just
*   typed fifteen digits should not have to reach for the mouse.
    lo_form->input( value            = io_ctx->bind( c_own_eid )
                    placeholder      = '784-xxxx-xxxxxxx-x'
                    showvaluehelp    = abap_true
                    valuehelprequest = io_ctx->event( c_evt_ownsr )
                    submit           = io_ctx->event( c_evt_ownsr ) ).
            lo_form->button( text = 'Check' press = io_ctx->event( c_evt_ownsr ) ).

    lo_form->label( text = 'Owner name' required = abap_true ).
    lo_form->input( value = io_ctx->bind( 'NAME_POP' ) type = 'Text' ).

    lo_form->label( text = 'Telephone' required = abap_true ).
    lo_form->input( value = io_ctx->bind( 'TELEPHONE_POP' ) type = 'Number' ).

    lo_form->label( text = 'Email' required = abap_true ).
    lo_form->input( value = io_ctx->bind( 'EMAIL_POP' ) type = 'Text' ).

    lo_form->label( text = 'Birth Date' required = abap_true ).
    lo_form->date_picker( value         = io_ctx->bind( c_dob )
                          valueformat   = 'yyyy-MM-dd'
                          displayformat = 'dd.MM.yyyy' ).

    lo_form->label( text = 'Nationality' required = abap_true ).
    DATA(lo_nat) = lo_form->combobox( selectedkey = io_ctx->bind( c_own_nat )
                                      placeholder = 'select' ).
*   T005T, not a hand-typed list. The 106-item literal this replaced stopped
*   at "Kenya" and never had United Arab Emirates in it at all - or anything
*   else L through Z. Same source ZCL_RAK_BP_POPUP already reads for its own
*   nationality dropdown, so a country missing here can't happen again the
*   same way, and it comes back correctly per language for free.
    SELECT land1 AS key, landx50 AS text
      FROM t005t
      WHERE spras = @sy-langu
      ORDER BY land1 ASCENDING
      INTO TABLE @DATA(lt_nat).
    IF lt_nat IS INITIAL AND sy-langu <> 'E'.
      SELECT land1 AS key, landx50 AS text
        FROM t005t
        WHERE spras = 'E'
        ORDER BY land1 ASCENDING
        INTO TABLE @lt_nat.
    ENDIF.
    LOOP AT lt_nat INTO DATA(ls_nat).
      lo_nat->item( key = ls_nat-key text = ls_nat-text ).
    ENDLOOP.

    lo_form->label( text = 'Shares %' required = abap_true ).
    lo_form->input( value = io_ctx->bind( c_own_share ) type = 'Number' ).



*****************
*****************
******************   ONE dialog: the owner's details and their documents. No search, no drill-
******************   down, no second popup - the list is on the step behind and this is the form
******************   that adds one line to it.
*****************    DATA(lv_id) = io_ctx->get_val( c_own_id ).
*****************
*****************    DATA(lo_dlg) = io_popup->dialog( title = 'Owner' contentwidth = '40rem' ).
*****************    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).
*****************
******************   Search sits ON the section title, not under the Emirates ID field, because
******************   it acts on the whole form: type the ID, press Search, and the rest fills in.
*****************    DATA(lo_hdr) = lo_c->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
*****************    lo_hdr->title( text = 'Owner Details' class = 'rakBlkTitle' ).
*****************    lo_hdr->button( text  = 'Search'
*****************                    type  = 'Emphasized'
*****************                    icon  = 'sap-icon://search'
*****************                    press = io_ctx->event( c_evt_ownsr ) ).
*****************
******************   Two per row, the way the legacy dialog laid it out.
*****************    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
*****************    DATA(lo_c1) = lo_r1->vbox( class = 'rakCell' ).
*****************    lo_c1->label( text = 'Identification' required = abap_true ).
*****************    lo_c1->input( value = io_ctx->bind( c_own_name ) width = '17rem' ).
*****************    DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).
*****************    lo_c2->label( text = 'Emirates ID' required = abap_true ).
******************   Enter in the ID box does the same as pressing Search. Somebody who has just
******************   typed fifteen digits should not have to reach for the mouse.
*****************    lo_c2->input( value       = io_ctx->bind( c_own_eid )
*****************                  width       = '17rem'
*****************                  placeholder = '784-xxxx-xxxxxxx-x'
*****************                  submit      = io_ctx->event( c_evt_ownsr ) ).
*****************
*****************    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
*****************    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
*****************    lo_c5->label( text = 'Owner name' ).
*****************    lo_c5->input( value = io_ctx->bind( 'NAME_POP' ) width = '17rem' ).
*****************    DATA(lo_c6) = lo_r2->vbox( class = 'rakCell' ).
*****************    lo_c6->label( text = 'Telephone' ).
*****************    lo_c6->input( value = io_ctx->bind( 'TELEPHONE_POP' ) width = '17rem' ).
*****************    DATA(lo_c7) = lo_r2->vbox( class = 'rakCell' ).
*****************    lo_c7->label( text = 'Email' ).
*****************    lo_c7->input( value = io_ctx->bind( 'EMAIL_POP' ) width = '17rem' ).
*****************    DATA(lo_c3) = lo_r2->vbox( class = 'rakCell' ).
*****************    lo_c3->label( text = 'Nationality' ).
*****************    lo_c3->input( value = io_ctx->bind( c_own_nat ) width = '17rem' ).
*****************    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
*****************    lo_c4->label( text = 'Shares %' required = abap_true ).
*****************    lo_c4->input( value = io_ctx->bind( c_own_share ) type = 'Number' width = '17rem' ).

*   ---- their documents ------------------------------------------------
*   iv_key is what makes a repeating list work. Every uploader here is keyed on
*   THIS owner's id, so the chips shown are only theirs and the file reaches the
*   backend as identifier1 = MAIN_DOC_<owner id> - the shape the D0xx BAdI
*   already reads for OWNERS_SEARCH_<n>.
*
*   Without the key every owner's files would land in one chip list with nothing
*   to tell them apart, and the delete button beside a chip would remove
*   somebody else's document.
     DATA(lo_dr1) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d1)  = lo_dr1->vbox( class = 'rakCell' ).
    lo_d1->label( text = 'Emirates ID Copy' ).
    io_ctx->render_upload( io_view = lo_d1 iv_field = 'EMI_COPY_POP' iv_key = lv_id ).
    DATA(lo_d2)  = lo_dr1->vbox( class = 'rakCell' ).
    lo_d2->label( text = 'Passport Copy' ).
    io_ctx->render_upload( io_view = lo_d2 iv_field = 'PASSPORT_COPY_POP' iv_key = lv_id ).

    DATA(lo_dr2) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d3)  = lo_dr2->vbox( class = 'rakCell' ).
    lo_d3->label( text = 'Introductory Statement' ).
    io_ctx->render_upload( io_view = lo_d3 iv_field = 'INTRODUCTORY_POP' iv_key = lv_id ).
    DATA(lo_d4)  = lo_dr2->vbox( class = 'rakCell' ).
    lo_d4->label( text = 'Criminal Clearance certificate' ).
    io_ctx->render_upload( io_view = lo_d4 iv_field = 'CRIMINAL_CLEAR_POP' iv_key = lv_id ).

**    lo_c->title( text = 'Documents' class = 'rakBlkTitle sapUiSmallMarginTop' ).
**    lo_c->label( text = 'Emirates ID copy' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'EMI_COPY_POP' iv_key = lv_id ).
**    lo_c->label( text = 'Passport copy' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'PASSPORT_COPY_POP' iv_key = lv_id ).
**    lo_c->label( text = 'Introductory Statement' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'INTRODUCTORY_POP' iv_key = lv_id ).
**    lo_c->label( text = 'Criminal clearance certificate' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'CRIMINAL_CLEAR_POP' iv_key = lv_id ).

    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = 'Add'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_ownok ) ).
    lo_b->button( text = 'Close' press = io_ctx->event( c_evt_owncx ) ).
  ENDMETHOD.


  METHOD own_delete.
    DATA(ls_g)   = io_ctx->get_grid_data( c_grid ).
    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
*     Matched on PARTNER, the same value RENDER_OWN_LIST( ) puts on the button.
      CHECK zcl_rak_journey_util=>cell_of( it_cols = ls_g-columns
                                           it_row  = lt_r
                                           iv_name = 'NAME' ) <> iv_id.
      APPEND lt_r TO ls_new-rows.
    ENDLOOP.
    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
*  EXPORTING
*    IO_CTX  =
*    IO_VIEW =
*    .
     IF io_ctx->get_step( ) = 1.
      render_own_list( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.
  endmethod.
ENDCLASS.
