class ZCL_D006_SCHOOL_MNG_CHG_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
protected section.
private section.

  constants C_MIN_SEARCH_LEN type I value 3 ##NO_TEXT.
  constants C_DEFAULT_IDTYPE type STRING value 'YFS002' ##NO_TEXT.
*  constants C_ROWSEP .

*  methods OWNER_STEP .
*  methods BLOB_READ .

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
ENDCLASS.



CLASS ZCL_D006_SCHOOL_MNG_CHG_LOGIC IMPLEMENTATION.


  method BLOB_READ.
  endmethod.


  METHOD owner_step.
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
  ENDMETHOD.


  method OWN_FORM_LOAD.
  endmethod.


  method OWN_FORM_SAVE.
  endmethod.


  method OWN_SEARCH.
  endmethod.


  method RENDER_OWN_LIST.
  endmethod.


  method RENDER_OWN_POPUP.
  endmethod.


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

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.

    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 2), not omitted by oversight.
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
    " TELEPHONE, POBOX, PARCELID, and the CURRENT MANAGERNAME/MANAGEREID/
    " MANAGERMOBILE/MANAGEREMAIL/MANAGERNATIONALITY here from the same
    " selected license/school record.
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

    CHECK iv_step = 1.   " zero-based: step 2 "Manager" in the wizard

*   'Error', not 'Warning'. The engine gates the step on type = 'Error' only, so
*   as a Warning this was displayed and then ignored - a manager change could be
*   submitted naming the manager it was replacing.
    IF io_ctx->get_val( 'NEWMANAGERSEARCH' ) IS NOT INITIAL
   AND io_ctx->get_val( 'NEWMANAGERSEARCH' ) = io_ctx->get_val( 'MANAGEREID' ).
      rt = VALUE #( BASE rt ( type = 'Error' text = 'The new manager must be different from the current manager.' ) ).
    ENDIF.
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
*       Validate before writing. Closing on an incomplete row and complaining
*       behind the dialog makes the citizen reopen it and guess what was wrong.
        IF io_ctx->get_val( c_own_eid ) IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Owner name and Emirates ID are both needed.' ).
          RETURN.
        ENDIF.
        own_form_save( io_ctx ).
        io_ctx->close_popup( ).
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |{ io_ctx->get_val( c_own_name ) } added to the owner list.| ).

      WHEN 'CANCEL'.
        io_ctx->close_popup( ).
      WHEN c_evt_owncx.
        io_ctx->close_popup( ).
    ENDCASE.

  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_BEFORE_FIELD.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_BEFORE_FIELD
*  EXPORTING
*    IO_CTX   =
*    IO_VIEW  =
*    IS_FIELD =
*    .
    CALL METHOD super->zif_rak_journey_logic~on_render_before_field
      EXPORTING
        io_ctx   = io_ctx
        io_view  = io_view
        is_field = is_field.
  endmethod.


  METHOD zif_rak_journey_logic~on_render_end.
    IF io_ctx->get_step( ) = 1.
      render_own_list( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    super->zif_rak_journey_logic~on_render_popup(
          io_ctx   = io_ctx
          io_popup = io_popup
          iv_id    = iv_id
        ).

**    CHECK iv_id = c_pop_mat.
    CASE iv_id.
      WHEN c_pop_own.
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
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
    super->zif_rak_journey_logic~on_render_start(
     io_ctx  = io_ctx
     io_view = io_view
   ).
    CHECK io_ctx->get_step( ) = owner_step( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    CHECK to_upper( iv_field ) = 'NEWMANAGERSEARCH'.

    DATA(lv_eid) = condense( io_ctx->get_val( 'NEWMANAGERSEARCH' ) ).
    IF strlen( lv_eid ) < c_min_search_len.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = |Enter at least { c_min_search_len } characters to search| ).
      RETURN.
    ENDIF.

    DATA(lv_idtype) = io_ctx->get_val( 'NEWMANAGERSEARCH_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      lv_idtype = c_default_idtype.
    ENDIF.

    DATA: lv_eid_no   TYPE bu_id_number,
          lv_eid_type TYPE bu_id_type.

    lv_eid_no = lv_eid.
    lv_eid_type = lv_idtype.
*    SELECT SINGLE a~partner, a~zzfull_name_eng, b~idnumber, a~zzmobile, a~zzemail, a~zznationality
*      FROM but000 AS a
*      LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idtype
*      WHERE b~idnumber = @lv_term OR a~partner = @lv_term
*      INTO @DATA(ls_bp).                                "#EC CI_NOORDBY
*
*    IF sy-subrc <> 0.
*      io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
*      RETURN.
*    ENDIF.

    " Reflect the NEW manager's identity immediately — reusing the same
    " display fields the CURRENT manager uses would overwrite the "before"
    " picture the user needs to compare against, so this writes to
    " distinct NEW* fields instead. If the real UI shows the found result
    " inline where the search box is (as the screenshot suggests) rather
    " than as separate fields, these 4 set_val calls are unnecessary —
    " confirm against the real rendering before relying on them.
*    io_ctx->set_val( iv_name = 'NEWMANAGERSEARCH' iv_value = |{ ls_bp-partner }| ).
*     io_ctx->set_val( iv_name = 'NEWMGRNAME'        iv_value = |{ ls_bp-zzfull_name_eng }| ).
*     io_ctx->set_val( iv_name = 'NEWMGRMOBILE'      iv_value = |{ ls_bp-zzmobile }| ).
*     io_ctx->set_val( iv_name = 'NEWMGREMAIL'       iv_value = |{ ls_bp-zzemail }| ).
*     io_ctx->set_val( iv_name = 'NEWMGRNATIONALITY' iv_value = |{ ls_bp-zznationality }| ).

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

    io_ctx->set_val( iv_name = 'NEWMGRNAME'        iv_value = ' ' ).
    io_ctx->set_val( iv_name = 'NEWMGRMOBILE'      iv_value = ' ' ).
    io_ctx->set_val( iv_name = 'NEWMGREMAIL'       iv_value = ' ' ).
    io_ctx->set_val( iv_name = 'NEWMGRDOB'         iv_value = ' ' ).
    io_ctx->set_val( iv_name = 'NEWMGRNATIONALITY' iv_value = ' ' ).


    io_ctx->set_val( iv_name = 'NEWMANAGERSEARCH'  iv_value = |{ lv_eid }| ).
    io_ctx->set_val( iv_name = 'NEWMGRNAME'        iv_value = |{ ev_name }| ).
    io_ctx->set_val( iv_name = 'NEWMGRMOBILE'      iv_value = |{ ev_phone }| ).
    io_ctx->set_val( iv_name = 'NEWMGREMAIL'       iv_value = |{ ev_email }| ).
    io_ctx->set_val( iv_name = 'NEWMGRDOB'         iv_value = |{ ev_date_of_birth }| ).
    io_ctx->set_val( iv_name = 'NEWMGRNATIONALITY' iv_value = |{ ev_nationality }| ).





  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP.
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
  endmethod.
ENDCLASS.
