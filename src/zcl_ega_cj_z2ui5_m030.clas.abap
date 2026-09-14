CLASS zcl_ega_cj_z2ui5_m030 DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_ext_widgets
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_serializable_object .
    INTERFACES z2ui5_if_app .

    TYPES:
      BEGIN OF ty_selection,
        rb_lessor               TYPE flag,
        rb_lessee               TYPE flag,
        rb_3rd                  TYPE flag,
        rb_investment           TYPE flag,
        rb_commercial           TYPE flag,
        rb_residential          TYPE flag,
        rb_family               TYPE flag,
        rb_collective_labor     TYPE flag,
        rb_shared_accommodation TYPE flag,
        context                 TYPE zde_cj_context,
      END OF ty_selection .
    TYPES:
      BEGIN OF ty_lessor,
        name        TYPE string,
        nationality TYPE string,
        eid         TYPE string,
        unid        TYPE string,
        passport    TYPE string,
        email       TYPE string,
        phone_no    TYPE string,
      END OF ty_lessor .
    TYPES:
      BEGIN OF ty_properties,
        index              TYPE i,
        selected           TYPE flag,
        aotype             TYPE string,
        aoid               TYPE string,
        ownername          TYPE string,
        deedtype           TYPE string,
        titledeedno        TYPE string,
        titledeedyear      TYPE string,
        parcelid           TYPE string,
        contractstatus     TYPE string,
        contractstatusdesc TYPE string,
        landuse            TYPE string,
        areatext           TYPE string,
        address            TYPE string,
      END OF ty_properties .
    TYPES:
      tt_properties TYPE STANDARD TABLE OF ty_properties WITH DEFAULT KEY .
    TYPES:
      BEGIN OF ty_pagination,
        lines_on_page    TYPE i,
        current_page     TYPE i,
        total_lines      TYPE i,
        total_page_count TYPE i,
        from_line        TYPE i,
        to_line          TYPE i,
        search           TYPE string,
      END OF ty_pagination .
    TYPES:
      BEGIN OF ty_data,
        bp          TYPE but000-partner,
        journeytype TYPE zde_cj_journeyid,
        description TYPE zde_cj_id_desc,
        caseid      TYPE scmg_ext_key,
        ref_caseid  TYPE scmg_ext_key,
        case_stat   TYPE string,
        role        TYPE string,
        partner     TYPE but000-partner,
        lessor      TYPE ty_lessor,
        lessor_old  TYPE zst_cj_lessor_det,
        company     TYPE but000-partner,
        selection   TYPE ty_selection,
        properties  TYPE tt_properties,
        fees        TYPE tt_fees,
        total_fee   TYPE zde_ega_amount,
        attachments TYPE /qnv/sbuild_attachments_tt,
        etisalat    TYPE flag,
      END OF ty_data .

    DATA gs_data TYPE ty_data .
    DATA ms_pagination TYPE ty_pagination .

    METHODS nntc_1_1 .
    METHODS nntc_1_2 .
    METHODS lease_properties
      RETURNING
        VALUE(et_properties) TYPE tt_properties .
protected section.
private section.


  methods GET_LR
    importing
      !IV_PARCEL type RELMPLNO
      !IV_AOID type REBDAOID
    exporting
      !EV_DISTRICT type RELMLRDISTRICT
      !EV_VOLUMENO type RELMLRVOLUMENO
      !EV_PAGENO type RELMLRPAGENO .
  methods SET_CONTEXT
    returning
      value(CONTEXT) type ZDE_CJ_CONTEXT .
  methods UPDATE_STAGES
    importing
      !CURRENT_SCREEN type STRING .
  methods INIT_JOURNEY .
  methods GET_BP_LESSOR
    importing
      value(PARTNER) type BU_PARTNER
    returning
      value(LESSOR) type ZST_CJ_LESSOR_DET .
  methods CTT
    importing
      value(C_T) type STRING optional
      value(I_D) type DATS optional
      value(I_T) type TIMS optional
    returning
      value(R_T) type TIMESTAMP .
  methods PARCEL_ADDRESS
    importing
      value(PARCEL) type RELMPLNO optional
    returning
      value(ADDRESS) type STRING .
  methods PROPERTIES_CSS
    returning
      value(EV_CSS) type STRING .
ENDCLASS.



CLASS ZCL_EGA_CJ_Z2UI5_M030 IMPLEMENTATION.


  METHOD get_bp_lessor.
    DATA: details TYPE zst_mun_bp_details,
          det     TYPE zst_ega_bp_details.

    CALL FUNCTION 'ZFM_MUN_ODATA_GET_BP_DETAILS'
      EXPORTING
        im_bp          = partner
      IMPORTING
        es_bp_detaills = details.

    CALL FUNCTION 'ZFM_EGA_GET_BP_DETAILS'
      EXPORTING
        ev_bp         = partner
      IMPORTING
        ev_bp_details = det.

    SELECT type, idnumber
      FROM but0id
      INTO TABLE @DATA(ids)
      WHERE partner = @partner
        AND type IN ( 'YFS001', 'YFS002', 'YFS005', 'YP0001' ).
*        AND valid_date_from LE @sy-datum
*        AND valid_date_to GE @sy-datum.

    LOOP AT ids INTO DATA(id).
      CASE id-type.
        WHEN 'YFS005'."Passport
          lessor-passport = id-idnumber.
        WHEN 'YFS001'."Unified ID
          lessor-uid_no = id-idnumber.
        WHEN 'YFS002'."EmiratesID
          lessor-eid = id-idnumber.
        WHEN 'YP0001'."TradeLicenseNumber
          lessor-trade_lic = id-idnumber.
      ENDCASE.
    ENDLOOP.

    SELECT SINGLE a~zzfull_name_eng b~natio50
      FROM but000 AS a
      LEFT OUTER JOIN t005t AS b
      ON a~natio = b~land1
      AND b~spras = sy-langu
      INTO ( lessor-name_en, lessor-natnl )
      WHERE partner = partner.

    lessor-name_ar = det-ev_name. "details-bp_name.
    lessor-name_en = COND #( WHEN lessor-name_en IS INITIAL THEN lessor-name_ar ELSE lessor-name_en ).
    lessor-mobile  = details-bp_mobile.
    lessor-email   = details-bp_email.
    IF  lessor-eid IS INITIAL.
      IF lessor-passport IS NOT INITIAL.
        lessor-eid = lessor-passport.
        lessor-label_en =  'Passport No.'.
        lessor-label_ar = 'رقم جواز السفر'.
      ELSEIF lessor-uid_no IS NOT INITIAL.
        lessor-eid = lessor-uid_no.
        lessor-label_en = 'Emirates ID'.
        lessor-label_ar = 'رقم الهويه'.
      ELSEIF lessor-trade_lic IS NOT INITIAL.
        lessor-eid = lessor-trade_lic.
        lessor-label_en = 'Trade Licence'.
        lessor-label_ar = 'رقم الرخصة'.
      ENDIF.
    ELSE.
      lessor-label_en = 'Emirates ID'.
      lessor-label_ar = 'رقم الهويه'.
    ENDIF.
  ENDMETHOD.


  METHOD init_journey.

    gs_data-lessor_old = me->get_bp_lessor( gs_data-partner ).
    CASE sy-langu.
      WHEN 'A'.
        gs_data-lessor-name         = gs_data-lessor_old-name_ar.
        gs_data-lessor-nationality  = gs_data-lessor_old-natnl.
        gs_data-lessor-eid          = gs_data-lessor_old-eid.
        gs_data-lessor-unid         = gs_data-lessor_old-uid_no.
        gs_data-lessor-passport     = gs_data-lessor_old-passport.
        gs_data-lessor-email        = gs_data-lessor_old-email.
        gs_data-lessor-phone_no     = gs_data-lessor_old-mobile.
      WHEN 'E'.
        gs_data-lessor-name         = gs_data-lessor_old-name_en.
        gs_data-lessor-nationality  = gs_data-lessor_old-natnl.
        gs_data-lessor-eid          = gs_data-lessor_old-eid.
        gs_data-lessor-unid         = gs_data-lessor_old-uid_no.
        gs_data-lessor-passport     = gs_data-lessor_old-passport.
        gs_data-lessor-email        = gs_data-lessor_old-email.
        gs_data-lessor-phone_no     = gs_data-lessor_old-mobile.
    ENDCASE.



    SELECT SINGLE description FROM zega_t_cj_idt
      INTO gs_data-description
      WHERE spras EQ sy-langu
      AND journeyid EQ gs_data-journeytype.



    APPEND INITIAL LINE TO mt_attach ASSIGNING FIELD-SYMBOL(<attach>).
    <attach>-label     = me->get_text_by_id( 'LABOUR_HOUSING_REPORT' ).
    <attach>-file_type = '1'.


    CLEAR: mt_stages[].
    SELECT textid AS stagelabel, screenid AS screen
      FROM zega_t_cj_track
      INTO CORRESPONDING FIELDS OF TABLE @mt_stages
      WHERE journeyid  EQ @gs_data-journeytype
      AND   contextkey EQ '2'
      AND   stepno     NE @space
      ORDER BY stepno.

  ENDMETHOD.


  METHOD nntc_1_1.

    DATA(view) = z2ui5_cl_xml_fragment=>factory( ).
    DATA(firstcontainer) = view->vbox( class = 'RAKEGA-firstContainer' ).
    DATA(card) = firstcontainer->vbox( class = 'RAKEGA-card' ).
    DATA(card_top) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(card_header) = card_top->hbox( class = 'RAKEGA-cardheader' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(card_header_begin) = card_header->hbox( class = 'RAKEGA-cardheader-begin RAKEGA-align-items-center-imp' alignitems = 'Center' ).
*    DATA(journeyname_image) = card_header_begin->hbox( class = 'RAKEGA-journey-municioality-image RAKEGA-hide-in-mobile' alignitems = 'Center' ).
    DATA(journeyname_image) = card_header_begin->image( src = '../css/img/services/SVG/MUN.svg' height = '2rem' ).
    " AMBIGUOUS(JOURNEYNAME): VALUE='Renew Tenancy contract' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(journeyname) = card_header_begin->label( text = 'Renew Tenancy contract'(100) class = 'H2_1 color-dark-blue RAKEGA-journeyname' ).
*    DATA(card_header_vseparator) = card_header_begin->vbox( class = 'RAKEGA-cardheader-vseparator RAKEGA-hide-in-mobile' ).
*    DATA(description_title) = card_header_begin->label( text = get_text_by_id( 'GENINFOHEADER' ) class = 'Body_1_3 color-gray5 RAKEGA-hide-in-mobile' ).
    DATA(card_header_end) = card_header->hbox( class = 'nowrap' alignitems = 'Center' ).
    DATA(savedraft) = card_header_end->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event(
  'SAVEDRAFTHOMEPOPUP' ) ).
    DATA(savedraft_icononly) = card_header_end->button( id = 'SAVEDRAFT_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOMEPOPUP' ) ).
    DATA(delete) = card_header_end->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = card_header_end->button( id = 'DELETE_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(description_panel) = card_top->vbox( class = 'RAKEGA-description-m-panel' alignitems = 'Start' visible = 'false' ).
    DATA(description_title_in_panel) = description_panel->label( text = get_text_by_id( 'GENINFOHEADER' ) class = 'Body_1_3 color-gray5' ).
    DATA(context_hbox_desktop) = card_top->hbox( class = 'RAKEGA-context-hbox-desktop' visible = 'false ' ).
    DATA(context1_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx1_d_label) = context1_d_cont->label( text = get_text_by_id( 'CONTRACT' ) class = 'Body_1_3 color-gray7' ).
    DATA(ctx1_d_value) = context1_d_cont->label( text = '{CONTRACT_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context1_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context2_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    " TODO(CTX2_D_LABEL): no VALUE and no TECHNICAL_NAME in source - binding unknown
    DATA(ctx2_d_label) = context2_d_cont->label( text = '' class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX2_D_VALUE): VALUE='Residential' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx2_d_value) = context2_d_cont->label( text = '{CONTRACT_TYPE}' class = 'Body_1_3 color-gray7' ).
    DATA(context2_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context3_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx3_d_label) = context3_d_cont->label( text = get_text_by_id( 'TEN_VILLAID' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX3_D_VALUE): VALUE='123456' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx3_d_value) = context3_d_cont->label( text = '{VILA_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context3_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context4_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx4_d_label) = context4_d_cont->label( text = get_text_by_id( 'TEN_BUILDINGID' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX4_D_VALUE): VALUE='1234' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx4_d_value) = context4_d_cont->label( text = '{BUILDING_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context4_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context5_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx5_d_label) = context5_d_cont->label( text = get_text_by_id( 'FLOOR_NO' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX5_D_VALUE): VALUE='1' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx5_d_value) = context5_d_cont->label( text = '{FLOOR_NUMBER}' class = 'Body_1_3 color-gray7' ).
    DATA(context5_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context6_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx6_d_label) = context6_d_cont->label( text = get_text_by_id( 'UNIT_NO' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX6_D_VALUE): VALUE='1001' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx6_d_value) = context6_d_cont->label( text = '{UNIT_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context6_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context7_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    " AMBIGUOUS(CTX7_D_VALUE): VALUE='2024-08-13T14:44:07Z' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx7_d_value) = context7_d_cont->label( text = '{EXPIRED}' class = 'Body_1_3' ).
    DATA(context_m_collapsed_hbox) = card_top->hbox( class = 'RAKEGA-context-m-collapsed-hbox' visible = 'false' ).
    DATA(context1_mc_cont) = context_m_collapsed_hbox->hbox( class = 'RAKEGA-context-cont-collapsed' ).
    DATA(ctx1_mc_label) = context1_mc_cont->label( text = get_text_by_id( 'CONTRACT' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX1_MC_VALUE): VALUE='12345678' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx1_mc_value) = context1_mc_cont->label( text = '{CONTRACT_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(ctx_more) = context_m_collapsed_hbox->button( id = 'CTX_MORE' text = get_text_by_id( 'MORE_DETAILS' ) class = 'RAKEGA-context-m-button' type = 'Transparent' ).
    " TODO(CTX_MORE): no EVENT in source - this button drives a client-side show/hide chain instead (UI_FIELD_LOGICS): CONTEXT_M_COLLAPSED_HBOX-V-F,CONTEXT_M_EXPANDED_VBOX-V-T
    DATA(context_m_expanded_vbox) = card_top->vbox( class = 'RAKEGA-context-m-expanded-vbox' visible = 'false' ).
    DATA(context1_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx1_me_label) = context1_me_cont->label( text = get_text_by_id( 'CONTRACT' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX1_ME_VALUE): VALUE='12345678' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx1_me_value) = context1_me_cont->label( text = '{CONTRACT_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context2_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    " TODO(CTX2_ME_LABEL): no VALUE and no TECHNICAL_NAME in source - binding unknown
    DATA(ctx2_me_label) = context2_me_cont->label( text = '' class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX2_ME_VALUE): VALUE='Residential' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx2_me_value) = context2_me_cont->label( text = '{CONTRACT_TYPE}' class = 'Body_1_3 color-gray7' ).
    DATA(context3_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx3_me_label) = context3_me_cont->label( text = get_text_by_id( 'TEN_VILLAID' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX3_ME_VALUE): VALUE='123456' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx3_me_value) = context3_me_cont->label( text = '{VILA_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context4_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx4_me_label) = context4_me_cont->label( text = get_text_by_id( 'TEN_BUILDINGID' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX4_ME_VALUE): VALUE='1234' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx4_me_value) = context4_me_cont->label( text = '{BUILDING_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context5_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx5_me_label) = context5_me_cont->label( text = get_text_by_id( 'FLOOR_NO' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX5_ME_VALUE): VALUE='1' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx5_me_value) = context5_me_cont->label( text = '{FLOOR_NUMBER}' class = 'Body_1_3 color-gray7' ).
    DATA(context6_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx6_me_label) = context6_me_cont->label( text = get_text_by_id( 'UNIT_NO' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX6_ME_VALUE): VALUE='1001' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx6_me_value) = context6_me_cont->label( text = '{UNIT_ID}' class = 'Body_1_3 color-gray7' ).
    DATA(context7_me_cont) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-cont' ).
    " AMBIGUOUS(CTX7_ME_VALUE): VALUE='2024-08-13T14:44:07Z' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx7_me_value) = context7_me_cont->label( text = '{EXPIRED}' class = 'Body_1_3' ).
    DATA(ctx_less_hbox) = context_m_expanded_vbox->hbox( class = 'RAKEGA-context-less-hbox' justifycontent = 'End' ).
    DATA(ctx_less) = ctx_less_hbox->button( id = 'CTX_LESS' text = get_text_by_id( 'LESS_DETAILS' ) class = 'RAKEGA-context-m-button' type = 'Transparent' ).
    " TODO(CTX_LESS): no EVENT in source - this button drives a client-side show/hide chain instead (UI_FIELD_LOGICS): CONTEXT_M_COLLAPSED_HBOX-V-T,CONTEXT_M_EXPANDED_VBOX-V-F
    me->rakstagebar( card_top ).
    DATA(description_details_cont) = card_top->vbox( class = 'RAKEGA-card-descriptioncont RAKEGA-hide-in-mobile sapUiSmallMarginTop' alignitems = 'Center' visible = 'false' ).
    DATA(description) = description_details_cont->label( text = get_text_by_id( 'DESCRIPTION_RA_SELECTPARCELORGRANTED_1_1' ) class = 'font1 weight400 color-gray6' ).
    DATA(description_details_panel) = card_top->vbox( class = 'RAKEGA-hide-in-desktop sapUiTinyMarginTop' alignitems = 'Start' visible = 'false' ).
    DATA(journey_description_mobile) = description_details_panel->text_area( value = get_text_by_id( 'DESCRIPTION_RA_SELECTPARCELORGRANTED_1_1' ) maxlength = '65' class = 'Body_1_3 color-gray7 RAKEGA-lobby-ex-text' ).
    DATA(part2) = card->vbox( class = 'RAKEGA-part2' ).
    DATA(applicant_details) = part2->label( text = get_text_by_id( 'APPLICANT_DETAILS' ) class = 'H3_1 color-dark-blue sapUiSmallMarginBottom' ).
    DATA(applicant_details_2_hbox) = part2->hbox( class = 'sapUiTinyMarginBottom' justifycontent = 'Start' ).
    DATA(applicant_details_2) = applicant_details_2_hbox->label( text = get_text_by_id( 'TENANCY_CONTRACT_RBS' ) class = 'Body_1_2 color-gray7' ).
    " AMBIGUOUS(APPLICANT_DETAILS_2_STAR): literal text, not an i18n key pattern - confirm
    DATA(applicant_details_2_star) = applicant_details_2_hbox->label( text = '*' class = 'Body_1_2 color-red' ).
    DATA(rbline) = part2->hbox( class = 'rbline' ).
    DATA(rb1) = rbline->radio_button( id = 'RB1' text = get_text_by_id( 'LESSOR' ) groupname = 'role' selected = '{/XX/GS_DATA/SELECTION/RB_LESSOR}' class = 'radioButton' ).
    " TODO(RB1): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: LESSOR_DETAILS-V-T,LESSEE_DETAILS-V-F,LESSOR_DETAILS_CONT-V-T,LESSOR_DETAILS_CONT2-V-T,ATTENTION_CONT-V-T,SEPARATOR1-V-T,SEPARAT
    DATA(rb2) = rbline->radio_button( id = 'RB2' text = get_text_by_id( 'LESSEE' ) groupname = 'role' selected = '{/XX/GS_DATA/SELECTION/RB_LESSEE}' class = 'radioButton' ).
    " TODO(RB2): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: LESSOR_DETAILS-V-F,LESSEE_DETAILS-V-T,LESSOR_DETAILS_CONT-V-T,LESSOR_DETAILS_CONT2-V-T,ATTENTION_CONT-V-T,SEPARATOR1-V-T,SEPARAT
    DATA(rb3) = rbline->radio_button( id = 'RB3' text = get_text_by_id( '3RD_PARTY' ) groupname = 'role' selected = '{/XX/GS_DATA/SELECTION/RB_3RD}' class = 'radioButton' ).
    " TODO(RB3): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: LESSOR_DETAILS-V-F,LESSEE_DETAILS-V-F,LESSOR_DETAILS_CONT-V-F,LESSOR_DETAILS_CONT2-V-F,ATTENTION_CONT-V-F,SEPARATOR1-V-T,SEPARAT
    DATA(separator1) = part2->hbox( class = 'sessions_card_hSeparator sapUiMediumMarginTopBottom' justifycontent = 'Start' alignitems = 'Start'
    visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE} || ${/XX/GS_DATA/SELECTION/RB_3RD}}'  ).
    DATA(lessor_details) = part2->label( text = get_text_by_id( 'LESSOR_DETAILS' ) class = 'H3_1 color-dark-blue sapUiSmallMarginBottom' visible = '{/XX/GS_DATA/SELECTION/RB_LESSOR}' ).
    DATA(lessee_details) = part2->label( text = get_text_by_id( 'LESSEE_DETAILS' ) class = 'H3_1 color-dark-blue sapUiSmallMarginBottom' visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSEE} || ${/XX/GS_DATA/SELECTION/RB_LESSEE}}' ).
    DATA(lessor_details_cont) = part2->hbox( class = 'width-100-mobile' alignitems = 'Start' visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE}}' ).
    DATA(lessor_name_cont) = lessor_details_cont->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_name_label) = lessor_name_cont->label( text = get_text_by_id( 'NAME' ) class = 'Body_1_2 color-gray7' ).
    DATA(lessor_name_value) = lessor_name_cont->label( text = '{/XX/GS_DATA/LESSOR/NAME}' class = 'Body_1_3 color-gray6' ).
    DATA(lessor_nationality_cont) = lessor_details_cont->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_nationality_label) = lessor_nationality_cont->label( text = get_text_by_id( 'NATIONALITY' ) class = 'Body_1_2 color-gray7' ).
    DATA(lessor_nationality_value) = lessor_nationality_cont->label( text = '{/XX/GS_DATA/LESSOR/NATIONALITY}' class = 'Body_1_3 color-gray6' ).
    DATA(lessor_eid_cont) = lessor_details_cont->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_eid_label) = lessor_eid_cont->label( text = get_text_by_id( 'EMIRATES_ID' ) class = 'Body_1_2 color-gray7' ).
    DATA(lessor_eid_value) = lessor_eid_cont->label( text = '{/XX/GS_DATA/LESSOR/EID}' class = 'Body_1_3 color-gray6' ).
    DATA(lessor_uid_cont) = lessor_details_cont->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_uid_label) = lessor_uid_cont->label( text = get_text_by_id( 'UNIFIED_ID' ) class = 'Body_1_2 color-gray7' ).
    DATA(lessor_uid_value) = lessor_uid_cont->label( text = '{/XX/GS_DATA/LESSOR/UNID}' class = 'Body_1_3 color-gray6' ).
    DATA(lessor_passport_cont) = lessor_details_cont->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_passport_label) = lessor_passport_cont->label( text = get_text_by_id( 'PASSPORT_NO' ) class = 'Body_1_2 color-gray7' ).
    DATA(lessor_passport_value) = lessor_passport_cont->label( text = '{/XX/GS_DATA/LESSOR/PASSPORT}' class = 'Body_1_3 color-gray6' ).
    DATA(lessor_details_cont2) = part2->hbox( class = 'width-100-mobile' alignitems = 'Start' visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE}}' ).
    DATA(lessor_email_cont) = lessor_details_cont2->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_email_label) = lessor_email_cont->label( text = get_text_by_id( 'EMAIL' ) class = 'Body_1_2 color-gray7' required = 'true' ).
    DATA(lessor_email_value) = lessor_email_cont->input( value = '{/XX/GS_DATA/LESSOR/EMAIL}' class = 'input' required = 'true' ).
    DATA(lessor_phone_cont) = lessor_details_cont2->vbox( class = 'width-100-mobile sapUiMediumMarginEnd sapUiSmallMarginBottom gap-3px' ).
    DATA(lessor_phone_label) = lessor_phone_cont->label( text = get_text_by_id( 'PHONE_NO' ) class = 'Body_1_2 color-gray7' required = 'true' ).
    DATA(lessor_phone_value) = lessor_phone_cont->input( value = '{/XX/GS_DATA/LESSOR/PHONE_NO}' class = 'input' required = 'true' ).
    DATA(attention_cont) = part2->hbox( visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE}}'  ).
    DATA(attention_icon) = attention_cont->icon( src = 'sap-icon://icomoon/attention' class = 'Body_2_3 color-dark-blue sapUiTinyMarginEnd' ).
    DATA(attention) = attention_cont->label( text = get_text_by_id( 'ATTENTION' ) class = 'Body_2_3 color-dark-blue' ).
    DATA(ewe_section) = part2->vbox( class = 'sapUiSmallMarginTop' visible = '{/XX/GS_DATA/SELECTION/RB_LESSEE}' ).
    DATA(checkbox_ewe) = ewe_section->check_box( text = get_text_by_id( 'TEN_NNTC_1_3_CHECKBOX_1' ) selected = '{EWE_CAT}' class = 'checkbox' ).
    DATA(separator2) = part2->hbox( class = 'sessions_card_hSeparator sapUiMediumMarginTopBottom' justifycontent = 'Start' alignitems = 'Start'
    visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE}}'  ).
    DATA(contract_detals) = part2->label( text = get_text_by_id( 'CONTRACT_DETALS' ) class = 'H3_1 color-gray7 sapUiSmallMarginBottom'
    visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE} || ${/XX/GS_DATA/SELECTION/RB_3RD}}'  ).
    DATA(contract_detals_2_hbox) = part2->hbox( class = 'sapUiTinyMarginBottom' alignitems = 'Start'
    visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE} || ${/XX/GS_DATA/SELECTION/RB_3RD}}' ).
    DATA(contract_detals_2) = contract_detals_2_hbox->label( text = get_text_by_id( 'CONTRACT_TYPE' ) class = 'Body_1_2 color-gray7' ).
    " AMBIGUOUS(CONTRACT_DETALS_2_STAR): literal text, not an i18n key pattern - confirm
    DATA(contract_detals_2_star) = contract_detals_2_hbox->label( text = '*' class = 'Body_1_2 color-red' ).
    DATA(rbline1) = part2->hbox( class = 'rbline' visible = '{= ${/XX/GS_DATA/SELECTION/RB_LESSOR} || ${/XX/GS_DATA/SELECTION/RB_LESSEE} || ${/XX/GS_DATA/SELECTION/RB_3RD}}' ).
    DATA(rb4) = rbline1->radio_button( id = 'RB4' text = get_text_by_id( 'INVESTMENT' ) groupname = 'role1' selected = '{/XX/GS_DATA/SELECTION/RB_INVESTMENT}' class = 'radioButton' ).
    " TODO(RB4): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: RESIDENTIAL_CATEGORY_2_HBOX-V-F,RBLINE2-V-F,LABEL_UPLOADER_HBOX-V-F,UPLOADER-V-F,NEXT-E-T,RB7-V-F2,RB8-V-F2,RB9-V-F2
    DATA(rb5) = rbline1->radio_button( id = 'RB5' text = get_text_by_id( 'COMMERCIAL' ) groupname = 'role1' selected = '{/XX/GS_DATA/SELECTION/RB_COMMERCIAL}' class = 'radioButton' ).
    " TODO(RB5): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: RESIDENTIAL_CATEGORY_2_HBOX-V-F,RBLINE2-V-F,LABEL_UPLOADER_HBOX-V-F,UPLOADER-V-F,NEXT-E-T,RB7-V-F2,RB8-V-F2,RB9-V-F2
    DATA(rb6) = rbline1->radio_button( id = 'RB6' text = get_text_by_id( 'RESIDENTIAL' ) groupname = 'role1' selected = '{/XX/GS_DATA/SELECTION/RB_RESIDENTIAL}' class = 'radioButton' ).
    " TODO(RB6): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: RESIDENTIAL_CATEGORY_2_HBOX-V-T,RBLINE2-V-T,NEXT-E-F,RB7-V-T,RB8-V-T,RB9-V-T
    DATA(residential_category_2_hbox) = part2->hbox( class = 'sapUiSmallMarginTop sapUiTinyMarginBottom' alignitems = 'Start' visible = '{/XX/GS_DATA/SELECTION/RB_RESIDENTIAL}' ).
    DATA(residential_category_2) = residential_category_2_hbox->label( text = get_text_by_id( 'RESIDENTIAL_CATEGORY' ) class = 'Body_1_2 color-gray7' ).
    " AMBIGUOUS(RESIDENTIAL_CATEGORY_2_STAR): literal text, not an i18n key pattern - confirm
    DATA(residential_category_2_star) = residential_category_2_hbox->label( text = '*' class = 'Body_1_2 color-red' ).
    DATA(rbline2) = part2->hbox( class = 'rbline' visible = '{/XX/GS_DATA/SELECTION/RB_RESIDENTIAL}' ).
    DATA(rb7) = rbline2->radio_button( id = 'RB7' text = get_text_by_id( 'FAMILY' ) groupname = 'role2' selected = '{/XX/GS_DATA/SELECTION/RB_FAMILY}' class = 'radioButton' ).
    " TODO(RB7): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: LABEL_UPLOADER_HBOX-V-F,NEXT-E-T
    DATA(rb8) = rbline2->radio_button( id = 'RB8' text = get_text_by_id( 'COLLECTIVE_LABOR' ) groupname = 'role2' selected = '{/XX/GS_DATA/SELECTION/RB_COLLECTIVE_LABOR}' class = 'radioButton' ).
    " TODO(RB8): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: LABEL_UPLOADER_HBOX-V-T,NEXT-E-T
    DATA(rb9) = rbline2->radio_button( id = 'RB9' text = get_text_by_id( 'SHARED_ACCOMMODATION' ) groupname = 'role2' selected = '{/XX/GS_DATA/SELECTION/RB_SHARED_ACCOMMODATION}' class = 'radioButton' ).
    " TODO(RB9): drives client-side show/hide/enable chain (UI_FIELD_LOGICS) not modeled in build_view: LABEL_UPLOADER_HBOX-V-F,NEXT-E-T
    DATA(label_uploader_hbox) = part2->vbox( class = 'sapUiMediumMarginTop' alignitems = 'Start' visible = '{/XX/GS_DATA/SELECTION/RB_COLLECTIVE_LABOR}' ).
*    DATA(label_uploader) = label_uploader_hbox->label( text = get_text_by_id( 'LABOUR_HOUSING_REPORT' ) class = 'Body_1_2 color-gray7' ).

    me->rakuploader( io_parent = label_uploader_hbox filter_by = '1' ).
    DATA(label_filetype) = label_uploader_hbox->label( text = get_text_by_id( 'TEN_FILE_TYPE_AND_SIZE' ) class = 'Body_1_3 color-gray6 sapUiMediumMarginTop' ).
    DATA(footer) = firstcontainer->hbox( class = 'RAKEGA-footer RAKEGA-next-btn-end' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left'
    press = client->_event( 'BACK' ) visible = 'false' ).
    DATA(next) = footer->button( id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' iconfirst = 'false' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' )
    enabled = '{= ${/XX/GS_DATA/SELECTION/RB_INVESTMENT} || ${/XX/GS_DATA/SELECTION/RB_COMMERCIAL} || ${/XX/GS_DATA/SELECTION/RB_FAMILY} || ${/XX/GS_DATA/SELECTION/RB_COLLECTIVE_LABOR} || ${/XX/GS_DATA/SELECTION/RB_SHARED_ACCOMMODATION}}' ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_init( ).

      me->init( ).
      gs_data-journeytype = ms_params-journey.
      gs_data-role        = ms_params-role.
      gs_data-partner     = ms_params-partner.
      gs_data-company     = ms_params-company.
      client->_bind_edit( gs_data ).
      client->_bind_edit( ms_pagination ).

      init_journey( ).
      ms_payment-description = gs_data-description.
      ms_payment-fees[]      = gs_data-fees[].

      me->step_forward( control = me ).
      RETURN.
    ENDIF.

    CASE client->get( )-event.
      WHEN 'SAVE'.
        CASE me->get_current_screen( ).
          WHEN 'NNTC_1_1'.
            me->update_stages( me->get_current_screen( ) ).
        ENDCASE.
        me->step_forward( control = me direction = '+' ).
      WHEN 'BACK'.
        me->step_forward( control = me direction = '-' ).
      WHEN 'SEARCH_PROP'.
        ms_pagination-current_page = 1.
        me->step_forward( control = me direction = '=' ).
      WHEN 'SEARCH_PROP1'.
        SUBTRACT 1 FROM ms_pagination-current_page.
        IF ms_pagination-current_page LE 0.
          ms_pagination-current_page = 1.
        ENDIF.
        me->step_forward( control = me direction = '=' ).
      WHEN 'SEARCH_PROP2'.
        ADD 1 TO ms_pagination-current_page.
        IF ms_pagination-current_page GT ms_pagination-total_page_count.
          ms_pagination-current_page = ms_pagination-total_page_count.
        ENDIF.
        me->step_forward( control = me direction = '=' ).
      WHEN 'SEARCH_PROP3'.
        ms_pagination-current_page = 1.
        me->step_forward( control = me direction = '=' ).
      WHEN 'SEARCH_PROP4'.
        ms_pagination-current_page = ms_pagination-total_page_count.
        me->step_forward( control = me direction = '=' ).
    ENDCASE.
  ENDMETHOD.


  METHOD lease_properties.

    TYPES: BEGIN OF ty_property,
             aoid         TYPE rebdaoid,
             aotype       TYPE rebdaotype,
             intreno      TYPE recaintreno,
             objnr        TYPE recaobjnr,
             objid        TYPE recabusobjid,
             objtype      TYPE recabusobjtype,
             parentid     TYPE relmplno,
             intreno_p    TYPE recaintreno,
             objnr_p      TYPE recaobjnr,
             partner      TYPE bu_partner,
             role         TYPE rebprole,
             is_mortgaged TYPE boolean,
             is_grant     TYPE boolean,
             granttype    TYPE string,
             validto      TYPE recncnendabs,
             ownmethod    TYPE zown_mth,
             ownershpmthd TYPE string,
             favourite    TYPE boolean,
           END OF ty_property,
           tt_property TYPE STANDARD TABLE OF ty_property WITH DEFAULT KEY.

    DATA:lr_role      TYPE /iwbep/t_cod_select_options,
         lr_partner   TYPE /iwbep/t_cod_select_options,
         lr_building  TYPE RANGE OF vibdao-aotype,
         et_entityset TYPE zcl_zega_cj_mpc=>tt_properties.

    DATA:plno        TYPE relmplno,
         temp        TYPE string,
         partnerguid TYPE bu_partner_guid,
         partnerrole TYPE string,
         ls_entity   TYPE zcl_zega_cj_mpc=>ts_properties,
         lt_entity   TYPE zcl_zega_cj_mpc=>tt_properties,
         deed        TYPE relmlrvolumeno,
         year        TYPE relmlrpageno,
         deed_type   TYPE string,
         owntyp      TYPE char01.

    DATA: lt_properties TYPE tt_property,
          ls_property   TYPE ty_property.

    DATA(role) = 'LESSOR'.

    IF gs_data-partner IS INITIAL.
      gs_data-partner = '1000116563'.
    ENDIF.

    SHIFT year LEFT DELETING LEADING '0'.
    IF year < '2014'.
      DATA(lv_ownind) = abap_true.
    ELSEIF year = '2014' AND deed LE 3000.
      lv_ownind = abap_true.
    ELSE.
      lv_ownind = abap_false.
    ENDIF.

    SELECT 'I' AS sign, 'EQ' AS option, partner1 AS low, partner1 AS high FROM but050
         INTO TABLE @lr_partner
         WHERE partner2  EQ @gs_data-partner
           AND date_to   GE @sy-datum
           AND date_from LE @sy-datum
           AND reltyp    IN ('Z00003', 'Z00004', 'Y00100').

    lr_partner = VALUE #( BASE lr_partner ( sign = 'I' option = 'EQ' low = gs_data-partner ) ).

    lr_role = VALUE #( BASE lr_role ( sign = 'I' option = 'EQ' low = 'ZLESOR' )
                                    ( sign = 'I' option = 'EQ' low = 'ZINVES' )
                                    ( sign = 'I' option = 'EQ' low = 'TR0800' ) ).

    APPEND 'IEQ10IB    ' TO lr_building.
    APPEND 'IEQ10BU    ' TO lr_building.
    APPEND 'IEQ10CV    ' TO lr_building.
    APPEND 'IEQ10SF    ' TO lr_building.
    APPEND 'IEQ10SU    ' TO lr_building.
    APPEND 'IEQ10SB    ' TO lr_building.
    APPEND 'IEQ10DE    ' TO lr_building.

    SELECT a~intreno, a~objnr, a~aotype, a~aoid, a~intreno AS parent,
      b~partner, b~role, b~validfrom, b~validto,
      'I0' AS objtype
        FROM vibdao AS a
        INNER JOIN vibpobjrel AS b ON a~intreno EQ b~intreno
        WHERE b~partner   IN @lr_partner
        AND   b~role      IN @lr_role
        AND   b~validfrom LE @sy-datum
        AND   b~validto   GE @sy-datum
        AND   a~zzbuild_stat NOT IN ( '05' , '06' )
      UNION SELECT a~intreno, a~objnr, @abap_false AS aotype, a~plno AS aoid, a~intreno AS parent,
      b~partner, b~role, b~validfrom, b~validto,
      'I8' AS objtype
      FROM vilmpl AS a INNER JOIN vibpobjrel AS b
       ON  a~intreno EQ b~intreno
       INNER JOIN jest AS c
       ON  a~objnr EQ c~objnr
       WHERE b~partner   IN @lr_partner
       AND   b~role      IN @lr_role
       AND   b~validfrom LE @sy-datum
       AND b~validto     GE @sy-datum
       AND c~stat        IN ( 'E0011' , 'E0012' , 'E0013' )
      ORDER BY intreno
      INTO TABLE @DATA(lt_ao).
    IF lt_ao[] IS NOT INITIAL.
      DATA(lt_next)     = lt_ao[].
      DATA: lt_building LIKE lt_ao[].
      WHILE sy-subrc EQ 0.
        SELECT a~intreno, a~objnr, a~aotype, a~aoid, vibdnode~parent
        FROM vibdao AS a
        INNER JOIN vibdnode
        ON vibdnode~intreno EQ a~intreno
        FOR ALL ENTRIES IN @lt_next
        WHERE vibdnode~intreno EQ @lt_next-parent
        INTO TABLE @DATA(lt_result).
        IF sy-subrc EQ 0.
          APPEND LINES OF lt_result TO lt_building.
          MOVE-CORRESPONDING lt_result TO lt_next.
        ENDIF.
      ENDWHILE.
      SORT lt_building BY intreno.
      IF lt_building IS NOT INITIAL.
        SELECT a~plno, a~intreno, a~objnr, b~objnrtrg FROM vilmpl AS a
          INNER JOIN vibdobjass AS b ON a~objnr EQ b~objnrsrc
          AND b~objasstype EQ '20' AND b~validfrom LE @sy-datum AND b~validto GE @sy-datum
          FOR ALL ENTRIES IN @lt_building WHERE b~objnrtrg EQ @lt_building-objnr
          INTO TABLE @DATA(lt_parent).
        SORT lt_parent BY objnrtrg.
      ENDIF.

      DATA: ls_building   LIKE LINE OF lt_building.

      LOOP AT lt_ao INTO DATA(ls_ao).
        CASE ls_ao-objtype.
          WHEN 'I0'.
            MOVE-CORRESPONDING ls_ao TO ls_building.
            DO.
              IF ls_building-aotype IN lr_building.
                READ TABLE lt_parent INTO DATA(ls_parent) WITH KEY objnrtrg = ls_building-objnr BINARY SEARCH.
                EXIT.
              ELSE.
                READ TABLE lt_building INTO ls_building WITH KEY intreno = ls_building-parent BINARY SEARCH.
                IF sy-subrc NE 0 OR ls_building-intreno EQ ls_building-parent.
                  EXIT.
                ENDIF.
              ENDIF.
            ENDDO.
            IF ls_parent IS INITIAL.
              CONTINUE.
            ENDIF.
            ls_property-aoid      = ls_ao-aoid.
            ls_property-aotype    = ls_ao-aotype.
            ls_property-intreno   = ls_ao-intreno.
            ls_property-intreno_p = ls_parent-intreno.
            ls_property-objnr     = ls_ao-objnr.
            ls_property-objnr_p   = ls_parent-objnr.
            ls_property-objid     = ls_ao-aoid.
            ls_property-objtype   = ls_ao-objtype.
            ls_property-parentid  = ls_parent-plno.
            ls_property-partner   = ls_ao-partner.
            ls_property-role      = ls_ao-role.

            CLEAR: ls_parent.
          WHEN 'I8'.
            ls_property-intreno   = ls_ao-intreno.
            ls_property-intreno_p = ls_ao-intreno.
            ls_property-objnr     = ls_ao-objnr.
            ls_property-objnr_p   = ls_ao-objnr.
            ls_property-objid     = ls_ao-aoid.
            ls_property-objtype   = ls_ao-objtype.
            ls_property-parentid  = ls_ao-aoid.
            ls_property-partner   = ls_ao-partner.
            ls_property-role      = ls_ao-role.
        ENDCASE.
        APPEND ls_property TO lt_properties.
        CLEAR: ls_property.
      ENDLOOP.
    ENDIF.
    SELECT a~intreno, a~objnr, a~plno, a~xpl, b~partner, b~role, b~validfrom, b~validto,
        vibdcharact~fixfitcharact, tivbdcharactt~xfixfitcharact, tivajrlrasrch~rlragrpchct, tivajchctgroupt~xrlragrpchct,
        tivbdlochier~lochier AS area, tivbdlochier~xlochier AS areatext,
        sector~lochier AS sector, sector~xlochier AS sectortext,
        ex_status~stat
       FROM vilmpl AS a INNER JOIN vibpobjrel AS b
       ON  a~intreno EQ b~intreno
       INNER JOIN jest AS c
       ON  a~objnr EQ c~objnr
       LEFT OUTER JOIN jest AS ex_status
       ON  ex_status~objnr EQ c~objnr
       AND ex_status~stat  EQ 'I8912'
       AND ex_status~inact EQ @abap_false
       LEFT OUTER JOIN vibdcharact
       ON  vibdcharact~intreno       EQ a~intreno
       AND vibdcharact~fixfitcharact IN ( 'L300' , 'L301' , 'L302' , 'L303' , 'L304' , 'L305' , 'L306' , 'L307' , 'L308' , 'L309' , 'L310' )
       AND vibdcharact~validfrom     LE @sy-datum
       AND vibdcharact~validto       GE @sy-datum
       LEFT OUTER JOIN tivbdcharactt   ON vibdcharact~fixfitcharact EQ tivbdcharactt~fixfitcharact AND tivbdcharactt~spras        EQ @sy-langu
       LEFT OUTER JOIN tivajrlrasrch   ON vibdcharact~fixfitcharact EQ tivajrlrasrch~fixfitcharact AND tivajrlrasrch~rlragrpchct  EQ 'USAGE'
       LEFT OUTER JOIN tivajchctgroupt ON tivajrlrasrch~rlragrpchct EQ tivajchctgroupt~rlragrpchct AND tivajchctgroupt~spras      EQ @sy-langu
       LEFT OUTER JOIN vibdlochier     ON vibdlochier~intreno       EQ a~intreno                   AND vibdlochier~locsys         EQ 'RAK'
       LEFT OUTER JOIN tivbdlochier    ON tivbdlochier~locsys       EQ vibdlochier~locsys          AND tivbdlochier~lochier       EQ vibdlochier~lochier
       LEFT OUTER JOIN tivbdlochier AS sector
       ON  sector~locsys       EQ tivbdlochier~locsys
       AND sector~lochier      EQ tivbdlochier~locitem01
       WHERE b~partner IN @lr_partner
       AND b~role      IN @lr_role
       AND b~validfrom LE @sy-datum
       AND b~validto   GE @sy-datum
       AND c~stat      IN ( 'E0011' , 'E0012' , 'E0013' )
       AND c~inact     EQ @abap_false
      ORDER BY a~intreno
      INTO TABLE @DATA(lt_parcel).
    DELETE lt_parcel WHERE stat EQ 'I8912'.
    DELETE ADJACENT DUPLICATES FROM lt_parcel COMPARING intreno.



*    DATA(lo_obj) = NEW zcl_ega_mun_cj_odata_api_v2( partner = lr_partner role = lr_role ).
*
*    DATA(mt_properties) = lo_obj->properties.
*    DATA(parcel) = lo_obj->get_pl_header( ). "Get associated parcel
*    DATA(ao) = lo_obj->get_ao_header( ).     "Get associated AO
*    DATA(location) = lo_obj->get_location( )."Get associated location
*    DATA(status) = lo_obj->get_status( ).    "Get associated status

    LOOP AT lt_parcel INTO DATA(ls_parcel).

      APPEND INITIAL LINE TO et_properties ASSIGNING FIELD-SYMBOL(<property>).

      READ TABLE lt_properties INTO ls_property WITH KEY intreno = ls_parcel-intreno BINARY SEARCH.
      IF sy-subrc NE 0.
        CLEAR ls_property.
      ENDIF.

      <property>-aotype             = ls_property-aotype.
      <property>-aoid               = ls_property-aoid.
      <property>-ownername          = ''.
      <property>-deedtype           = ''.
      <property>-titledeedno        = ''.
      <property>-titledeedyear      = ''.
      <property>-parcelid           = ls_parcel-plno.
      <property>-contractstatus     = ''.
      <property>-contractstatusdesc = ''.
      <property>-landuse            = ''.
      <property>-areatext           = ls_parcel-areatext.
      <property>-address            = parcel_address( parcel = ls_parcel-plno ).

    ENDLOOP.

*    LOOP AT lt_ao INTO ls_ao.
*
*      APPEND INITIAL LINE TO et_properties ASSIGNING <property>.
*      <property>-aotype             = ls_ao-aotype.
*      <property>-aoid               = ls_ao-aoid.
*      <property>-ownername          = ''.
*      <property>-deedtype           = ''.
*      <property>-titledeedno        = ''.
*      <property>-titledeedyear      = ''.
*      <property>-parcelid           = ''.
*      <property>-contractstatus     = ''.
*      <property>-contractstatusdesc = ''.
*      <property>-landuse            = ''.
*      <property>-areatext           = ''.
*      <property>-address            = ''.
*    ENDLOOP.

*    et_entityset = VALUE #( BASE et_entityset FOR wa IN lt_parcel (  parcelid = wa-plno
*                                                                  parceldesc = wa-xpl
*                                                                  locationdesc = wa-xpl
*                                                                  landuse = COND #( WHEN VALUE #( lt_properties[ intreno = wa-intreno ]-ownershpmthd OPTIONAL ) IS INITIAL THEN wa-xfixfitcharact ELSE
*                                                                                          VALUE #( lt_properties[ intreno = wa-intreno ]-ownershpmthd OPTIONAL ) )
*                                                                  parcelvalidfrom = COND #( WHEN wa-validfrom IS NOT INITIAL THEN ctt( i_d = wa-validfrom i_t = '000000' ) )
*                                                                  parcelvalidto = COND #( WHEN VALUE #( lt_properties[ intreno = wa-intreno ]-is_grant OPTIONAL ) EQ 'X'
*                                                                  THEN
*                                                                  COND #( WHEN VALUE #( lt_properties[ intreno = wa-intreno ]-validto OPTIONAL ) IS NOT INITIAL
*                                                                  THEN ctt( i_d = VALUE #( lt_properties[ intreno = wa-intreno ]-validto OPTIONAL ) i_t = '000000' ) )
*                                                                  ELSE
*                                                                  COND #( WHEN wa-validto IS NOT INITIAL THEN ctt( i_d = wa-validto i_t = '000000' ) ) )
*                                                                  type = 'Parcel'
*                                                                  intreno = wa-intreno
*                                                                  parcelstatus = VALUE #( status[ objnr =  VALUE #( mt_properties[ intreno = wa-intreno ]-objnr OPTIONAL ) ]-txt30  OPTIONAL )
*                                                                  sector = VALUE #( location[ intreno = wa-intreno ]-sector OPTIONAL )
*                                                                  sectortext = VALUE #( location[ intreno = wa-intreno ]-sectortext OPTIONAL )
*                                                                  area = VALUE #( location[ intreno = wa-intreno ]-area OPTIONAL )
*                                                                  areatext = VALUE #( location[ intreno = wa-intreno ]-areatext OPTIONAL )
*                                                                  favourite = VALUE #( lt_properties[ intreno = wa-intreno ]-favourite OPTIONAL )
*                                                                  address = parcel_address( parcel = wa-plno )
*                                                                  ownershpmthd = VALUE #( lt_properties[ intreno = wa-intreno ]-ownershpmthd OPTIONAL )
*                                                                  ownershiptype =  VALUE #( lt_properties[ intreno = wa-intreno ]-ownmethod OPTIONAL )
*                                                                  granttype =  VALUE #( lt_properties[ intreno = wa-intreno ]-granttype OPTIONAL )
*                                                                  departmentcode = 'MUN'
*                                                                  departmentname = COND #( WHEN sy-langu EQ 'E' THEN 'Municipality' ELSE 'بلدية رأس الخيمة' )
*                                                                  ownertypeindicator = lv_ownind
*                                                                  ) ).

*    IF status IS NOT INITIAL.
*      "Check other not allowed status
*      SELECT a~objnr , b~plno FROM jest AS a INNER JOIN vilmpl AS b ON a~objnr EQ b~objnr
*        INTO TABLE @DATA(na_objnr) FOR ALL ENTRIES IN @status
*        WHERE a~objnr EQ @status-objnr AND stat EQ 'I8912' AND inact EQ @abap_false.
*      IF sy-subrc EQ 0.
*        LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<ls_entity>).
*          READ TABLE na_objnr ASSIGNING FIELD-SYMBOL(<na_objnr>) WITH KEY plno = <ls_entity>-parcelid.
*          IF sy-subrc EQ 0.
*            DELETE et_entityset WHERE parcelid EQ <ls_entity>-parcelid.
*          ENDIF.
*        ENDLOOP.
*      ENDIF.
*    ENDIF.

*    lt_entity = et_entityset.
*
*    DATA:idx TYPE i.
*    LOOP AT lt_entity ASSIGNING FIELD-SYMBOL(<fs_entity>).
*      idx = sy-tabix.
*      zcl_cj_tenancy_api=>rel_bld_to_pl(
*        EXPORTING
*          parcel  = CONV #( <fs_entity>-parcelid )                " Parcel Number
*          partner = gs_data-partner                 " Business Partner Number
*        RECEIVING
*          t_aoid  = DATA(lt_aoids)                 " Identification of Architectural Object
*      ).
*      IF lt_aoids IS NOT INITIAL.
*        IF deed IS INITIAL.
*          DELETE et_entityset WHERE parcelid EQ <fs_entity>-parcelid.
*        ENDIF.
*      ENDIF.
*      LOOP AT lt_aoids ASSIGNING FIELD-SYMBOL(<ls_aoid>).
*        DATA(hier) = zcl_cj_tenancy_api=>rel_units_to_bld( aoid = <ls_aoid>-aoid  ).
*        MOVE-CORRESPONDING <fs_entity> TO ls_entity.
*        LOOP AT hier INTO DATA(ls_hier).
*          LOOP AT ls_hier-units INTO DATA(ls_units).
*            IF ls_hier-units IS NOT INITIAL.
*              SELECT a~intreno, a~objnr, a~aoid, b~partner, b~role, b~validfrom, b~validto
*             INTO TABLE @DATA(lt_ao) FROM vibdao AS a INNER JOIN vibpobjrel AS b ON a~intreno = b~intreno
*             FOR ALL ENTRIES IN @ls_hier-units
*             WHERE aoid = @ls_hier-units-unid
*             AND b~partner NE @gs_data-partner
*             AND b~validfrom LE @sy-datum AND b~validto GE @sy-datum.
*
*              IF NOT line_exists( ao[ aoid = ls_units-unid ] ).
*                " get the unitis where owner is same as entered
*                IF NOT line_exists( lt_ao[ aoid = ls_units-unid ] ).
*                  ao = VALUE #( BASE ao (  intreno = ls_units-intreno
*                                           aoid    = ls_units-unid
*                                           xao     = ls_units-xao
*                                           bldaoid = <ls_aoid>-aoid
*                                           bldxao  = 'I0'
*                                           flraoid = ls_hier-fl_id
*                                           flrxao  = ls_hier-xao
*                                           aonr    = <ls_aoid>-aoid
*                                           zzold_unnr  = ls_units-zzold_unnr
*                                           zzfewa_acc  = ls_units-zzfewa_acc
*                                           xmaotype   = ls_units-xmaotype
*                                           xmaofunction = ls_units-xmaofunction
*                                           validfrom    = ls_units-validfrom
*                                           validto      = ls_units-validto ) ).
*
*                  mt_properties = VALUE #( BASE mt_properties (  intreno  = ls_units-intreno
*                                                                 objnr    = ls_units-objnr
*                                                                 objid    = ls_units-unid
**                                                                 objtype  = ''
*                                                                 parentid = <fs_entity>-parcelid
*                                                                 intreno_p  = <fs_entity>-intreno
*                                                                 objnr_p    =  mt_properties[ intreno_p = <fs_entity>-intreno ]-objnr_p
*                                                                 partner    = gs_data-partner
*                                                                 role       = ''
*                                                                 ownmethod  = <fs_entity>-ownershiptype
*                                                                 ownershpmthd = <fs_entity>-ownershpmthd ) ).
*                ENDIF.
*
*              ENDIF.
*            ENDIF.
*          ENDLOOP.
*        ENDLOOP.
*
*        TRANSLATE <ls_aoid>-aoty TO UPPER CASE.
*        ls_entity-aoid = <ls_aoid>-aoid.
*        ls_entity-aotype = <ls_aoid>-aoty.
*        ls_entity-deedtype = '2'."lo_obj->get_deed_type( CONV recaintreno( ls_entity-intreno ) ).
*        ls_entity-deedtypedesc = TEXT-017.
*        ls_entity-ao_assign = COND #( WHEN line_exists( ao[ bldaoid = <ls_aoid>-aoid  xmaotype(2) = '30' ] ) THEN abap_true ELSE abap_false ) .
*        IF ls_entity-ao_assign = abap_true. " code added
*          IF deed IS INITIAL.
*            DELETE ao WHERE bldaoid = <ls_aoid>-aoid AND  xmaotype(2) = '30' .
*          ELSE.
*            DELETE ao WHERE bldaoid = <ls_aoid>-aoid AND  xmaotype(2) = '30' AND bldxao  = 'I0'.
*          ENDIF.
*        ENDIF.
*        APPEND ls_entity TO et_entityset.
*      ENDLOOP.
*      CLEAR: ls_entity,lt_aoids.
*    ENDLOOP.
*
*    DELETE ao WHERE xmaotype(2) = '05'.
*    et_entityset = VALUE #( BASE et_entityset FOR wa1 IN ao (   aoid = wa1-aoid
*                                                                parcelid = VALUE #( mt_properties[ intreno = wa1-intreno ]-parentid OPTIONAL )
*                                                                aoname = wa1-xao
*                                                                aostatus = VALUE #( status[ objnr = VALUE #( mt_properties[ intreno = wa1-intreno ]-objnr OPTIONAL ) ]-txt30 OPTIONAL )
*                                                                aotype = wa1-xmaotype
*                                                                aofunction = wa1-xmaofunction
*                                                                intreno = wa1-intreno
*                                                                sector = VALUE #( location[ intreno = VALUE #( mt_properties[ intreno = wa1-intreno ]-intreno_p OPTIONAL ) ]-sector OPTIONAL )
*                                                                sectortext = VALUE #( location[ intreno = VALUE #( mt_properties[ intreno = wa1-intreno ]-intreno_p OPTIONAL ) ]-sectortext OPTIONAL )
*                                                                area = VALUE #( location[ intreno = VALUE #( mt_properties[ intreno = wa1-intreno ]-intreno_p OPTIONAL ) ]-area OPTIONAL )
*                                                                areatext = VALUE #( location[ intreno = VALUE #( mt_properties[ intreno = wa1-intreno ]-intreno_p OPTIONAL ) ]-areatext OPTIONAL )
*                                                                deedtype = '2'
*                                                                deedtypedesc  = TEXT-017
*                                                                type    = COND #( WHEN wa1-xmaofunction CS 'Villa' THEN '' ELSE 'Unit' ) "'Unit'
*                                                                favourite = VALUE #( mt_properties[ intreno = wa1-intreno ]-favourite OPTIONAL )
*                                                                aovalidfrom = COND #( WHEN wa1-validfrom IS NOT INITIAL THEN ctt( i_d = wa1-validfrom i_t = '000000' ) )
*                                                                aovalidto =  COND #( WHEN wa1-validto IS NOT INITIAL THEN ctt( i_d = wa1-validto i_t = '000000' ) )
*                                                                floor = wa1-flraoid
*                                                                floorname = wa1-flrxao
*                                                                building = wa1-bldaoid
*                                                                buildingname = wa1-bldxao
*                                                                externalunitno = wa1-zzold_unnr
*                                                                ownershiptype = VALUE #( mt_properties[ intreno = wa1-intreno ]-ownmethod OPTIONAL )
*                                                                ownershpmthd =  VALUE #( mt_properties[ intreno = wa1-intreno ]-ownershpmthd OPTIONAL )
*                                                                fewa = wa1-zzfewa_acc
*                                                                address = parcel_address( parcel = VALUE #( parcel[ intreno = VALUE #( mt_properties[ intreno = wa1-intreno ]-intreno_p OPTIONAL ) ] OPTIONAL ) )
*                                                                departmentcode = 'MUN'
*                                                                departmentname = COND #( WHEN sy-langu EQ 'E' THEN 'Municipality' ELSE 'بلدية رأس الخيمة' )
*                                                                ownertypeindicator = lv_ownind
*                                                                ao_assign = COND #( WHEN wa1-xmaotype(2) = '30' THEN abap_true ELSE abap_false )
*                                                                )
*                                                                ).
*
*    DELETE et_entityset WHERE type IS INITIAL.
*    LOOP AT et_entityset ASSIGNING <fs_entity>.
*      IF <fs_entity>-type EQ 'Parcel'.
*        get_lr(
*          EXPORTING
*            iv_parcel   = CONV #( <fs_entity>-parcelid )
*            iv_aoid     = ''
*          IMPORTING
*            ev_volumeno = DATA(vol)
*            ev_pageno   = DATA(pgno) ).
*      ELSE.
*        get_lr(
*          EXPORTING
*            iv_parcel   = CONV #( <fs_entity>-parcelid )
*            iv_aoid     = CONV #( <fs_entity>-aoid )
*          IMPORTING
*            ev_volumeno = vol
*            ev_pageno   = pgno ).
*
**        IF <fs_entity>-deedtype IS INITIAL.
**          <fs_entity>-deedtype = lo_obj->get_deed_type( CONV recaintreno( <fs_entity>-intreno ) ).
**          <fs_entity>-deedtypedesc = COND #( WHEN <fs_entity>-deedtype = 1 THEN TEXT-017 ELSE TEXT-016 ).
**        ENDIF.
*      ENDIF.
*      IF role = 'LESSEE' AND deed IS NOT INITIAL AND year IS NOT INITIAL.
*        vol = deed.
*        pgno = year.
*      ENDIF.
*
*
*      <fs_entity>-titledeed = vol.
*      <fs_entity>-titledeedyear = pgno.
*
*
*
*      SELECT SINGLE zzown_mth FROM vilmlr INTO @<fs_entity>-ownershpmthd WHERE lrvolumeno = @<fs_entity>-titledeed AND lrpageno = @<fs_entity>-titledeedyear.
*      IF sy-subrc IS INITIAL.
**          <fs_property>-ownmethod = ownmthd.
*        SELECT SINGLE description FROM zdt_refx_ownmtt INTO @<fs_entity>-ownershiptype WHERE own_mth EQ @<fs_entity>-ownershpmthd AND spras EQ @sy-langu. "<fs_property>-ownershpmthd
*      ENDIF.
*      IF role = 'LESSEE' AND deed IS NOT INITIAL AND year IS NOT INITIAL AND lines( et_entityset ) > 1.
*        IF <fs_entity>-type NE 'Unit'.
*          CLEAR: <fs_entity>-aoid.
*        ENDIF.
*      ENDIF.
*    ENDLOOP.
*
*    IF role = 'LESSEE' AND deed IS NOT INITIAL AND year IS NOT INITIAL AND lines( et_entityset ) > 1.
*      IF line_exists( et_entityset[ type = 'Unit' ] ).
*        DELETE et_entityset WHERE type NE 'Unit'.
*      ENDIF.
*      SORT et_entityset BY parcelid.
*      DELETE ADJACENT DUPLICATES FROM et_entityset COMPARING parcelid.
*    ENDIF.

*    MOVE-CORRESPONDING et_entityset TO et_properties.

    LOOP AT et_properties ASSIGNING <property>.
      <property>-index = sy-tabix.
      DATA(lv_index) = 1.
      DO.
        ASSIGN COMPONENT lv_index OF STRUCTURE <property> TO FIELD-SYMBOL(<field>).
        IF sy-subrc EQ 0.
          ADD 1 TO lv_index.
          IF <field> IS NOT INITIAL.
            DESCRIBE FIELD <field> TYPE DATA(lv_type).
            CASE lv_type.
              WHEN 'C' OR 'N' OR 'g'.
                SHIFT <field> LEFT DELETING LEADING '0'.
            ENDCASE.
          ENDIF.
        ELSE.
          EXIT.
        ENDIF.
      ENDDO.
    ENDLOOP.

  ENDMETHOD.


  METHOD nntc_1_2.

    IF ms_pagination IS INITIAL.
      gs_data-properties = me->lease_properties( ).

      me->properties_css( ).
      me->functions_to_front( ).

      ms_pagination-lines_on_page = 5.
      ms_pagination-current_page  = 1.
      ms_pagination-total_lines   = lines( gs_data-properties ).
      ms_pagination-total_page_count = ms_pagination-total_lines / ms_pagination-lines_on_page.
      IF ms_pagination-total_lines MOD ms_pagination-lines_on_page GT 0.
        ADD 1 TO ms_pagination-total_page_count.
      ENDIF.

    ENDIF.


    DATA(view) = z2ui5_cl_xml_fragment=>factory( ).
    DATA(firstcontainer) = view->vbox( class = 'RAKEGA-firstContainer' ).
    DATA(card) = firstcontainer->vbox( class = 'RAKEGA-card' ).
    DATA(card_top) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(card_header) = card_top->hbox( class = 'RAKEGA-cardheader' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(card_header_begin) = card_header->hbox( class = 'RAKEGA-cardheader-begin RAKEGA-align-items-center-imp' alignitems = 'Center' ).
    DATA(journeyname_image) = card_header_begin->image( src = '../css/img/services/SVG/MUN.svg' height = '2rem' ).
    DATA(journeyname) = card_header_begin->label( text = 'New Tenancy contract'(100) class = 'H2_1 color-dark-blue RAKEGA-journeyname' ).
    DATA(card_header_vseparator) = card_header_begin->vbox( class = 'RAKEGA-cardheader-vseparator RAKEGA-hide-in-mobile' ).
    DATA(description_title) = card_header_begin->label( text = get_text_by_id( 'GENINFOHEADER' ) class = 'Body_1_3 color-gray5 RAKEGA-hide-in-mobile' ).
    DATA(card_header_end) = card_header->hbox( class = 'nowrap' alignitems = 'Center' ).
    DATA(savedraft) = card_header_end->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile sapUiSmallMarginEnd'
    icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOMEPOPUP' ) ).
    DATA(savedraft_icononly) = card_header_end->button( id = 'SAVEDRAFT_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop'
    icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOMEPOPUP' ) ).
    DATA(delete) = card_header_end->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile'
    icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = card_header_end->button( id = 'DELETE_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    me->rakstagebar( card_top ).

    DATA(part2) = card->vbox( class = 'RAKEGA-part2' ).


    DATA(properties_scroll) = part2->vbox( id = 'idRakPropertiesScroll' width = '100%' rendertype = 'Bare' ).

    " ==================== HEADER ROW: title + owner-select + search ====================
    DATA(header_row) = properties_scroll->hbox( justifycontent = 'SpaceBetween' class = 'responsive-box p-gap-05-mobile' rendertype = 'Bare' ).

    DATA(selection_info_vbox) = header_row->vbox( class = 'properties-gap-012' rendertype = 'Bare' ).
    DATA(property_selection_title) = selection_info_vbox->text( text = 'Property Selection'(102) class = 'H3_1 color-gray7 p-none-mobile' ).
    DATA(select_property_list_text) = selection_info_vbox->text( text = 'Select Property List'(103) class = 'Body_1_3 color-gray6' ).

    DATA(controls_hbox) = header_row->hbox( class = 'responsive-box responsive-box-nowrap' alignitems = 'Center' rendertype = 'Bare' ).


    " TODO: SearchField - first use, method name guessed
    DATA(search_field) = controls_hbox->search_field(
*                             id          = 'searchField'
                             value       = '{/XX/MS_PAGINATION/SEARCH}'
                             placeholder = 'Search'(104)
                             class       = 'searchField'
                             search      = client->_event( 'SEARCH_PROP' ) ).

    " ==================== COUNT ROW ====================
    DATA(count_row) = properties_scroll->hbox( class = 'p-margin-top-05-mobile' rendertype = 'Bare' ).
    DATA(properties_count_text) = count_row->text( text = '{PModel>/tableData/count} {i18n>PropertiesFound}' class = 'Body_2_3 color-gray7' ).

    " (select-all-properties row removed - was POA-only, now permanently visible=false)

    " ==================== PROPERTY LIST ====================
    DATA(property_list) = properties_scroll->list(
                              id        = 'pList'
                              items     = '{/XX/GS_DATA/MT_PROPERTIES}'
                              class     = 'list p-propertyList'
                              mode      = 'SingleSelectMaster'
                              itempress = '.extension.RAK_PROPERTIES.onPropertyPress'
                              select    = '.extension.RAK_PROPERTIES.onItemSelect' ).

*    DATA: lt_properties          LIKE gs_data-properties,
*          lt_properties_filtered LIKE gs_data-properties.
*    IF ms_pagination-search IS INITIAL.
*      lt_properties_filtered[] = gs_data-properties[].
*    ELSE.
*      LOOP AT gs_data-properties INTO DATA(ls_property).
*        DATA(lv_found) = abap_false.
*        DATA(lv_index) = 1.
*        DO.
*          ASSIGN COMPONENT lv_index OF STRUCTURE ls_property TO FIELD-SYMBOL(<field>).
*          IF sy-subrc NE 0.
*            EXIT.
*          ENDIF.
*          IF <field> CS ms_pagination-search.
*            lv_found = abap_true.
*            EXIT.
*          ENDIF.
*          ADD 1 TO lv_index.
*        ENDDO.
*        IF lv_found EQ abap_true.
*          APPEND ls_property TO lt_properties_filtered.
*        ENDIF.
*      ENDLOOP.
*    ENDIF.
*    ms_pagination-total_lines   = lines( lt_properties_filtered ).
*    ms_pagination-total_page_count = ms_pagination-total_lines / ms_pagination-lines_on_page.
*    IF ms_pagination-total_lines MOD ms_pagination-lines_on_page GT 0.
*      ADD 1 TO ms_pagination-total_page_count.
*    ENDIF.
*
*    ms_pagination-from_line = ( ms_pagination-current_page * ms_pagination-lines_on_page ) - ms_pagination-lines_on_page + 1.
*    ms_pagination-to_line   = ( ms_pagination-current_page * ms_pagination-lines_on_page ).
*    WHILE lines( lt_properties ) LT ms_pagination-lines_on_page.
*      READ TABLE lt_properties_filtered INTO ls_property INDEX ms_pagination-from_line.
*      IF sy-subrc EQ 0.
*        APPEND ls_property TO lt_properties.
*      ELSE.
*        EXIT.
*      ENDIF.
*      ADD 1 TO ms_pagination-from_line.
*    ENDWHILE.

    DATA(list_item_template) = property_list->items( )->custom_list_item( type = 'Active' class = 'listItem' selected = '{SELECTED}' ).

    " ---- AVAILABLE-UNITS branch ----
    DATA(available_vbox) = list_item_template->vbox(
                               class   = 'p-margin-top-1 p-margin-bottom-1'
                               tooltip = '{= ${AOTYPE} === '''' ? ${i18n>tooltip} : '''' }' ).

    DATA(decoration_normal) = available_vbox->hbox( visible = '{= ${AOTYPE} !== '''' ? true : false }' class = 'p-liDecoration' ).
    DATA(decoration_orange) = available_vbox->hbox( visible = '{= ${AOTYPE} === '''' ? true : false }' class = 'p-liDecoration-orange' ).

    " title-deed line - was duplicated for POA/non-POA; POA branch removed, this is now
    " unconditionally visible (always rendered, no visible= attribute needed).
    DATA(titledeed_row) = available_vbox->hbox( class = 'p-margin-bottom-1' justifycontent = 'SpaceBetween' ).
    DATA(titledeed_hbox) = titledeed_row->hbox( class = 'responsive-box p-gap-05-mobile p-titledeed-hbox' ).
    DATA(owner_name) = titledeed_hbox->text( visible = 'false' text = '{OWNERNAME}' class = 'Body_1_1 color-dark-blue color-dark-blue-imp' ).
    DATA(name_sep) = titledeed_hbox->hbox( visible = 'false' height = '0.75rem' class = 'p-seperator p-none-mobile' ).
    DATA(multi_deeds) = titledeed_hbox->text( visible = '{= ${DEEDTYPE} === ''1'' }' text = '{i18n>MultipleDeeds}' class = 'Body_1_3 color-dark-blue color-dark-blue-imp' ).
    DATA(title_deed) = titledeed_hbox->text(
        visible = '{= ${DEEDTYPE} === ''2'' }'
        text    = '{i18n>TitleDeed} {TITLEDEEDNO}/{TITLEDEEDYEAR}'
        class   = 'Body_1_3 color-dark-blue color-dark-blue-imp' ).
    DATA(parcel_sep) = titledeed_hbox->hbox(
        visible = '{= ${PARCELID} !== '''' && ${DEEDTYPE} !== '''' ? true : false }'
        height  = '0.75rem' class = 'p-seperator p-none-mobile' ).
    DATA(parcel_text) = titledeed_hbox->text(
        visible = '{= ${PARCELID} !== '''' ? true : false }'
        text    = '{i18n>Parcel} {PARCELID}'
        class   = 'Body_1_3 color-dark-blue color-dark-blue-imp' ).
    DATA(status_hbox) = titledeed_row->hbox( class = 'p-none-mobile' ).
    DATA(status_active) = status_hbox->text( visible = '{= ${CONTRACTSTATUS} === ''2'' ? true : false }' text = '{CONTRACTSTATUSDESC}' class = 'color-green color-green-imp Small_text_2 case-tag bg-soft-Green' ).
    DATA(status_progress) = status_hbox->text( visible = '{= ${CONTRACTSTATUS} === ''1'' ? true : false }' text = '{CONTRACTSTATUSDESC}' class = 'color-azure color-azure-imp Small_text_2 case-tag bg-soft-Blue' ).

    " (POA-variant title-deed row removed entirely - was permanently visible=false)

    " building / land-use / area / address lines
    DATA(building_info_hbox) = available_vbox->hbox( class = 'responsive-box' ).
    DATA(building_image_hbox) = building_info_hbox->hbox( ).
*    DATA(ao_image) = building_image_hbox->image(
*        src   = '{PModel>/imageUrlPrefix}{path : ''PModel>AOType'',formatter:''.extension.RAK_PROPERTIES.AOTypeImage''}'
*        class = 'sapUiTinyMarginEnd p-img-top' ).
    DATA(no_building) = building_image_hbox->text( visible = '{=${AOTYPE}===''''? true : false}' text = '{i18n>NoBuilding}' class = 'Body_2_3 color-gray6 color-gray6-imp' ).
    DATA(building_type) = building_image_hbox->text( visible = '{=${AOTYPE}!==''''? true : false}' text = '{AOTYPE} {AOID}' class = 'Body_2_3 color-gray6 color-gray6-imp' ).
    DATA(landuse_sep) = building_info_hbox->hbox( visible = '{= ${LANDUSE} !== '''' ? true : false }' height = '0.75rem' class = 'p-seperator p-none-mobile' ).
    DATA(landuse_text) = building_info_hbox->text( text = '{LANDUSE}' class = 'Body_2_3 color-gray6 color-gray6-imp' ).

    DATA(area_address_hbox) = available_vbox->hbox( ).
    DATA(area_text) = area_address_hbox->text( text = '{AREATEXT}' class = 'Body_2_3 color-gray6 color-gray6-imp' ).
    DATA(address_sep) = area_address_hbox->hbox( visible = '{= ${ADDRESS} !== '''' ? true : false }' height = '0.75rem' class = 'p-seperator p-none-mobile' ).
    DATA(address_text) = area_address_hbox->text( text = '{ADDRESS}' class = 'Body_2_3 color-gray7 color-gray7-imp' ).

    DATA(status_hbox_mobile) = available_vbox->hbox( class = 'p-none-desktop p-margin-top-025' ).
    DATA(status_active_mobile) = status_hbox_mobile->text( visible = '{= ${CONTRACTSTATUS} === ''2'' ? true : false }' text = '{CONTRACTSTATUSDESC}' class = 'color-green color-green-imp Small_text_2 case-tag bg-soft-Green' ).
    DATA(status_progress_mobile) = status_hbox_mobile->text( visible = '{= ${CONTRACTSTATUS} === ''1'' ? true : false }' text = '{CONTRACTSTATUSDESC}' class = 'color-azure color-azure-imp Small_text_2 case-tag bg-soft-Blue' ).

*    LOOP AT lt_properties  INTO ls_property.
*
*      DATA(list_item_template) = property_list->items( )->custom_list_item( type = 'Active' class = 'listItem' ).
**    list_item_template->core_custom_data(
**        key       = 'disabled'
**        value     = 'X'
**        write_to_dom = '{= ${PModel>AvailableUnits} === ''0'' }' ).
*
*      " ---- AVAILABLE-UNITS branch ----
*      DATA(available_vbox) = list_item_template->vbox(
*                                 class   = 'p-margin-top-1 p-margin-bottom-1'
*                                 tooltip = ls_property-aotype ).
*      IF ls_property-aotype IS NOT INITIAL.
*        DATA(decoration_normal) = available_vbox->hbox( class = 'p-liDecoration' ).
*      ELSE.
*        DATA(decoration_orange) = available_vbox->hbox( class = 'p-liDecoration-orange' ).
*      ENDIF.
*
*      " title-deed line - was duplicated for POA/non-POA; POA branch removed, this is now
*      " unconditionally visible (always rendered, no visible= attribute needed).
*      DATA(titledeed_row) = available_vbox->hbox( class = 'p-margin-bottom-1' justifycontent = 'SpaceBetween' ).
*      DATA(titledeed_hbox) = titledeed_row->hbox( class = 'responsive-box p-gap-05-mobile p-titledeed-hbox' ).
*      DATA(owner_name) = titledeed_hbox->text( visible = 'false' text = ls_property-ownername class = 'Body_1_1 color-dark-blue color-dark-blue-imp' ).
*      DATA(name_sep) = titledeed_hbox->hbox( visible = 'false' height = '0.75rem' class = 'p-seperator p-none-mobile' ).
*      IF ls_property-deedtype EQ '2'.
*        DATA(title_deed) = titledeed_hbox->text(
*            text    = 'TitleDeed ' &&  ls_property-titledeedno && '/' && ls_property-titledeedyear
*            class   = 'Body_1_3 color-dark-blue color-dark-blue-imp' ).
*      ENDIF.
*      IF ls_property-parcelid IS NOT INITIAL.
*        DATA(parcel_sep) = titledeed_hbox->hbox(
*            height  = '0.75rem' class = 'p-seperator p-none-mobile' ).
*        DATA(parcel_text) = titledeed_hbox->text(
*            text    = 'Parcel ' &&  ls_property-parcelid
*            class   = 'Body_1_3 color-dark-blue color-dark-blue-imp' ).
*      ENDIF.
*      DATA(status_hbox) = titledeed_row->hbox( class = 'p-none-mobile' ).
*      IF ls_property-contractstatus EQ '2'.
*        DATA(status_active) = status_hbox->text( text = ls_property-contractstatusdesc class = 'color-green color-green-imp Small_text_2 case-tag bg-soft-Green' ).
*      ELSEIF ls_property-contractstatus EQ '1'.
*        DATA(status_progress) = status_hbox->text( text = ls_property-contractstatusdesc class = 'color-azure color-azure-imp Small_text_2 case-tag bg-soft-Blue' ).
*      ENDIF.
*
*      " (POA-variant title-deed row removed entirely - was permanently visible=false)
*
*      " building / land-use / area / address lines
*      DATA(building_info_hbox) = available_vbox->hbox( class = 'responsive-box' ).
*      DATA(building_image_hbox) = building_info_hbox->hbox( ).
*      DATA(ao_image) = building_image_hbox->image(
*          src   = '{PModel>/imageUrlPrefix}{path : ''PModel>AOType'',formatter:''.extension.RAK_PROPERTIES.AOTypeImage''}'
*          class = 'sapUiTinyMarginEnd p-img-top' ).
*      IF ls_property-aotype IS INITIAL.
*        DATA(no_building) = building_image_hbox->text( text = 'NoBuilding' class = 'Body_2_3 color-gray6 color-gray6-imp' ).
*      ELSE.
*        DATA(building_type) = building_image_hbox->text(  text = ls_property-aotype && ls_property-aoid class = 'Body_2_3 color-gray6 color-gray6-imp' ).
*      ENDIF.
*      IF ls_property-landuse IS NOT INITIAL.
*        DATA(landuse_sep) = building_info_hbox->hbox( height = '0.75rem' class = 'p-seperator p-none-mobile' ).
*        DATA(landuse_text) = building_info_hbox->text( text = ls_property-landuse class = 'Body_2_3 color-gray6 color-gray6-imp' ).
*      ENDIF.
*
*      DATA(area_address_hbox) = available_vbox->hbox( ).
*      DATA(area_text) = area_address_hbox->text( text = ls_property-areatext class = 'Body_2_3 color-gray6 color-gray6-imp' ).
*      IF ls_property-address IS NOT INITIAL.
*        DATA(address_sep) = area_address_hbox->hbox( height = '0.75rem' class = 'p-seperator p-none-mobile' ).
*        DATA(address_text) = area_address_hbox->text( text = ls_property-address class = 'Body_2_3 color-gray7 color-gray7-imp' ).
*      ENDIF.
*
*      DATA(status_hbox_mobile) = available_vbox->hbox( class = 'p-none-desktop p-margin-top-025' ).
*      IF ls_property-contractstatus EQ '2'.
*        DATA(status_active_mobile) = status_hbox_mobile->text( text = ls_property-contractstatusdesc class = 'color-green color-green-imp Small_text_2 case-tag bg-soft-Green' ).
*      ELSEIF ls_property-contractstatus EQ '1'.
*        DATA(status_progress_mobile) = status_hbox_mobile->text( text = ls_property-contractstatusdesc class = 'color-azure color-azure-imp Small_text_2 case-tag bg-soft-Blue' ).
*      ENDIF.
*
**      " ---- UNAVAILABLE-UNITS branch (AvailableUnits === '0') - same structure, gray palette ----
**      DATA(unavailable_vbox) = list_item_template->vbox( class = 'p-margin-top-1 p-margin-bottom-1' ).
**      DATA(decoration_gray) = unavailable_vbox->hbox( class = 'p-liDecoration p-liDecoration-gray' ).
**
**      DATA(titledeed_row_disabled) = unavailable_vbox->hbox( class = 'p-margin-bottom-1 rak_properties_disabled_list_hbox' justifycontent = 'SpaceBetween' ).
***      titledeed_row_disabled->core_custom_data( key = 'journey' value = '{PModel>/journey}' write_to_dom = 'true' ).
**      DATA(titledeed_hbox_disabled) = titledeed_row_disabled->hbox( class = 'responsive-box p-gap-05-mobile p-titledeed-hbox' ).
**      DATA(owner_name_disabled) = titledeed_hbox_disabled->text( visible = 'false' text = '{PModel>OwnerName}' class = 'Body_1_1 color-gray5 color-gray5-imp' ).
**      DATA(name_sep_disabled) = titledeed_hbox_disabled->hbox( visible = 'false' height = '0.75rem' class = 'p-seperator p-none-mobile' ).
***      DATA(multi_deeds_disabled) = titledeed_hbox_disabled->text( visible = '{= ${PModel>DeedType} === ''1'' }' text = '{i18n>MultipleDeeds}' class = 'Body_1_3 color-gray5 color-gray5-imp' ).
**      DATA(title_deed_disabled) = titledeed_hbox_disabled->text(
**          text    = 'TitleDeed' &&  ls_property-titledeedno && '/' && ls_property-titledeedyear
**          class   = 'Body_1_3 color-gray5 color-gray5-imp' ).
**      IF ls_property-deedtype IS NOT INITIAL.
**        DATA(parcel_sep_disabled) = titledeed_hbox_disabled->hbox(
**            height  = '0.75rem' class = 'p-seperator p-none-mobile' ).
**      ENDIF.
**      IF ls_property-parcelid IS NOT INITIAL.
**        DATA(parcel_text_disabled) = titledeed_hbox_disabled->text(
**            text    = ls_property-parcelid
**            class   = 'Body_1_3 color-gray5 color-gray5-imp' ).
**      ENDIF.
**      DATA(status_hbox_disabled) = titledeed_row_disabled->hbox( class = 'p-none-mobile' ).
**      IF ls_property-contractstatus EQ '2'.
**        DATA(status_active_disabled) = status_hbox_disabled->text( text = ls_property-contractstatusdesc class = 'color-green color-green-imp Small_text_2 case-tag bg-soft-Green' ).
**      ELSEIF ls_property-contractstatus EQ '1'.
**        DATA(status_progress_disabled) = status_hbox_disabled->text( text = ls_property-contractstatusdesc class = 'color-azure color-azure-imp Small_text_2 case-tag bg-soft-Blue' ).
**      ENDIF.
**
**      DATA(building_info_hbox_gray) = unavailable_vbox->hbox( class = 'responsive-box' ).
**      DATA(building_image_hbox_gray) = building_info_hbox_gray->hbox( ).
***      DATA(ao_image_gray) = building_image_hbox_gray->image(
***          src   = '{PModel>/imageUrlPrefix}{path : ''PModel>AOType'',formatter:''.extension.RAK_PROPERTIES.AOTypeImage''}'
***          class = 'sapUiTinyMarginEnd' ).
**      IF ls_property-aotype IS NOT INITIAL.
**        DATA(no_building_gray) = building_image_hbox_gray->text( text = 'NoBuilding' class = 'Body_2_3 color-gray5 color-gray5-imp' ).
**      ELSE.
**        DATA(building_type_gray) = building_image_hbox_gray->text( text = ls_property-aotype && ls_property-aoid class = 'Body_2_3 color-gray5 color-gray5-imp' ).
**      ENDIF.
**      IF ls_property-landuse IS NOT INITIAL.
**        DATA(landuse_sep_gray) = building_info_hbox_gray->hbox( height = '0.75rem' class = 'p-seperator p-none-mobile' ).
**        DATA(landuse_text_gray) = building_info_hbox_gray->text( text = ls_property-landuse class = 'Body_2_3 color-gray5 color-gray5-imp' ).
**      ENDIF.
**
**      DATA(area_address_hbox_gray) = unavailable_vbox->hbox( ).
**      DATA(area_text_gray) = area_address_hbox_gray->text( text = ls_property-areatext class = 'Body_2_3 color-gray5 color-gray5-imp' ).
**      IF ls_property-address IS NOT INITIAL.
**        DATA(address_sep_gray) = area_address_hbox_gray->hbox( height = '0.75rem' class = 'p-seperator p-none-mobile' ).
**        DATA(address_text_gray) = area_address_hbox_gray->text( text = ls_property-address class = 'Body_2_3 color-gray5 color-gray5-imp' ).
**      ENDIF.
**
**      DATA(status_hbox_mobile_gray) = unavailable_vbox->hbox( class = 'p-none-desktop p-margin-top-025' ).
**      IF ls_property-contractstatus EQ '2'.
**        status_active_disabled = status_hbox_disabled->text( text = ls_property-contractstatusdesc class = 'color-green color-green-imp Small_text_2 case-tag bg-soft-Green' ).
**      ELSEIF ls_property-contractstatus EQ '1'.
**        status_progress_disabled = status_hbox_disabled->text( text = ls_property-contractstatusdesc class = 'color-azure color-azure-imp Small_text_2 case-tag bg-soft-Blue' ).
**      ENDIF.
*    ENDLOOP.
*
    " ==================== FOOTER: cant-find-link / registered-property / pagination ====================
    DATA(footer_row) = properties_scroll->hbox( class = 'sapUiTinyMarginTop responsive-box' justifycontent = 'SpaceBetween' ).

    DATA(cant_find_hbox) = footer_row->hbox( alignitems = 'Center' rendertype = 'Bare' ).
    DATA(cant_find_link) = cant_find_hbox->formatted_text( id = 'cantFindLink' ).

    IF lines( gs_data-properties ) GT ms_pagination-lines_on_page.
      DATA(pagination_row) = footer_row->hbox( class = 'p-margin-top-05-mobile' ).
      DATA(pagination_inner) = pagination_row->hbox( justifycontent = 'SpaceAround' alignitems = 'Center' height = '3rem' width = '15rem' ).
      DATA(btn_first) = pagination_inner->button( icon = 'sap-icon://close-command-field' press = client->_event( 'SEARCH_PROP3' ) tooltip = 'FIRST PAGE' class = 'paginationBTN' ).
      DATA(btn_prev) = pagination_inner->button( icon = 'sap-icon://navigation-left-arrow' press = client->_event( 'SEARCH_PROP1' ) tooltip = 'PREVIUS PAGE' class = 'paginationBTN' ).
      DATA(page_info_text) = pagination_inner->text(
          text  = ms_pagination-current_page && '/' && ms_pagination-total_page_count
          class = 'weight500 font0875' ).
      DATA(btn_next) = pagination_inner->button( icon = 'sap-icon://navigation-right-arrow' press = client->_event( 'SEARCH_PROP2' ) tooltip = 'NEXT PAGE' class = 'paginationBTN' ).
      DATA(btn_last) = pagination_inner->button( icon = 'sap-icon://open-command-field' press = client->_event( 'SEARCH_PROP4' ) tooltip = 'LAST PAGE' class = 'paginationBTN' ).

      DATA(registered_property_footer2) = properties_scroll->hbox( class = 'p-margin-top-05-mobile' ).
      DATA(registered_icon_2) = registered_property_footer2->icon( src = 'sap-icon://icomoon/info' size = '1rem' color = '#10233E' class = 'info-icon p-icon-margin-1px sapUiTinyMarginEnd' ).
      DATA(registered_text_2) = registered_property_footer2->text( text = 'Registered Property' class = 'Body_2_3 color-dark-blue' ).
    ENDIF.


    DATA(footer) = firstcontainer->hbox( class = 'RAKEGA-footer' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(next) = footer->button( id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' iconfirst = 'false' press = client->_event( 'SAVE' ) ).

    client->view_display( view->stringify( ) ).


  ENDMETHOD.


  METHOD set_context.
    CASE abap_true.
      WHEN gs_data-selection-rb_lessor.
        gs_data-selection-context = '3'.
      WHEN gs_data-selection-rb_lessee.
        gs_data-selection-context = '2'.
      WHEN gs_data-selection-rb_3rd.
        gs_data-selection-context = '6'.
    ENDCASE.

    context = gs_data-selection-context.
  ENDMETHOD.


  METHOD update_stages.
    DATA(lv_context) = me->set_context( ).

    CLEAR: mt_stages[].
    SELECT textid AS stagelabel, screenid AS screen
      FROM zega_t_cj_track
      INTO CORRESPONDING FIELDS OF TABLE @mt_stages
      WHERE journeyid  EQ @gs_data-journeytype
      AND   contextkey EQ @lv_context
      AND   stepno     NE @space
      ORDER BY stepno.

    READ TABLE mt_stages ASSIGNING FIELD-SYMBOL(<stage>) WITH KEY screen = current_screen.
    IF sy-subrc EQ 0.
      <stage>-current = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD ctt.
    DATA:d              TYPE dats, t TYPE tims, c_initial_date TYPE string.

    d = i_d.
    t = i_t.

    IF c_t IS NOT INITIAL.
      TRY.
          c_initial_date = c_t(10).
          cl_abap_datfm=>conv_date_ext_to_int(
            EXPORTING
              im_datext   = CONV #( c_initial_date )
              im_datfmdes = '6'
            IMPORTING
              ex_datint   = d
          ).
        CATCH cx_abap_datfm_format_unknown .
      ENDTRY.
    ENDIF.

    CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
      EXPORTING
        i_datlo     = d
        i_timlo     = t
        i_tzone     = 'UTC'
      IMPORTING
        e_timestamp = r_t.

  ENDMETHOD.


METHOD get_lr.
  DATA: lv_ao     TYPE rebdaoid,
        lv_parcel TYPE relmplno.

  lv_ao = |{ iv_aoid ALPHA = IN }|  .
  lv_parcel = |{ iv_parcel ALPHA = IN }|.

  IF lv_ao IS NOT INITIAL.
    SELECT objnrsrc INTO TABLE @DATA(lt_objsrc) FROM zdt_refx_objas WHERE aoid EQ @lv_ao.
    IF lt_objsrc IS NOT INITIAL.
      SELECT intreno,lrdistrict,lrvolumeno,lrpageno,objnr,zzreg_stat INTO TABLE @DATA(lt_lr) FROM vilmlr FOR ALL ENTRIES IN @lt_objsrc
                WHERE objnr EQ @lt_objsrc-objnrsrc AND validto GE @sy-datum..
      IF lt_lr IS NOT INITIAL.
        SELECT intreno,validfrom INTO TABLE @DATA(lt_lr_bp) FROM vibpobjrel
                                 FOR ALL ENTRIES IN @lt_lr
                                 WHERE intreno EQ @lt_lr-intreno AND validfrom IS NOT NULL.
        SORT lt_lr_bp DESCENDING BY validfrom.
        LOOP AT lt_lr_bp ASSIGNING FIELD-SYMBOL(<fs_lr_bp>) WHERE validfrom IS NOT INITIAL.
          READ TABLE lt_lr INTO DATA(ls_lr) WITH KEY intreno = <fs_lr_bp>-intreno.
          IF sy-subrc EQ 0.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ELSE.
      " get the title deed from the parcel which is assigned to the building
      IF lv_parcel IS NOT INITIAL.
        get_lr(
                EXPORTING
                  iv_parcel   = CONV #( lv_parcel )
                  iv_aoid     = ''
                IMPORTING
                  ev_district = DATA(dist)
                  ev_volumeno = DATA(vol)
                  ev_pageno   = DATA(pgno) ).

        ls_lr-lrdistrict = dist.
        ls_lr-lrpageno = pgno.
        ls_lr-lrvolumeno = vol.
      ENDIF.

    ENDIF.
  ELSEIF lv_parcel IS NOT INITIAL.
    SELECT SINGLE objnr INTO @DATA(lv_objnr) FROM vilmpl  WHERE plno EQ @lv_parcel.
    IF sy-subrc EQ 0.
      SELECT intreno INTO TABLE @DATA(lt_objsrc2) FROM vilmrg WHERE plobjnr EQ @lv_objnr.
      IF lt_objsrc2 IS NOT INITIAL.
        SELECT intreno,lrdistrict,lrvolumeno,lrpageno,objnr,zzreg_stat INTO TABLE @lt_lr FROM vilmlr FOR ALL ENTRIES IN @lt_objsrc2
                 WHERE intreno EQ @lt_objsrc2-intreno AND validto GE @sy-datum..
        IF lt_lr IS NOT INITIAL.
          SELECT objnrsrc INTO TABLE @lt_objsrc FROM zdt_refx_objas FOR ALL ENTRIES IN @lt_lr WHERE objnrsrc EQ @lt_lr-objnr. " find if unit assigned to any land register
          IF sy-subrc IS INITIAL.
            LOOP AT lt_objsrc INTO DATA(ls_objrc).
              DELETE lt_lr WHERE objnr = ls_objrc.
            ENDLOOP.
          ENDIF.
          IF lt_lr IS NOT INITIAL.
            SELECT intreno,validfrom INTO TABLE @lt_lr_bp FROM vibpobjrel
                                     FOR ALL ENTRIES IN @lt_lr
                                     WHERE intreno EQ @lt_lr-intreno AND validfrom IS NOT NULL.
            SORT lt_lr_bp DESCENDING BY validfrom.
            LOOP AT lt_lr_bp ASSIGNING <fs_lr_bp> WHERE validfrom IS NOT INITIAL.
              READ TABLE lt_lr INTO ls_lr WITH KEY intreno = <fs_lr_bp>-intreno.
              IF sy-subrc EQ 0.
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

  ev_district = ls_lr-lrdistrict.
  ev_pageno = ls_lr-lrpageno.
  ev_volumeno = ls_lr-lrvolumeno.

ENDMETHOD.


  METHOD parcel_address.

    DATA parceloflandnumber TYPE bapi_re_parcel_land_key-parcel_of_land_number.
    DATA parcel_of_land     TYPE bapi_re_parcel_land.
    DATA address_t            TYPE STANDARD TABLE OF bapi_re_multi_addr.
    DATA addr            TYPE bapi_re_multi_addr.
    DATA return             TYPE STANDARD TABLE OF bapiret2.

    parceloflandnumber = parcel.

    CALL FUNCTION 'BAPI_RE_PL_GET_DETAIL'
      EXPORTING
        locationhierarchy  = ' '
        subdivisionnumber  = ' '
        parceloflandnumber = parceloflandnumber
      IMPORTING
        parcel_of_land     = parcel_of_land
      TABLES
        address            = address_t
        return             = return.

    addr = VALUE #( address_t[ 1 ] OPTIONAL ).

    address = addr-house_no && COND #( WHEN addr-house_no IS NOT INITIAL THEN ',' )
              && addr-street_lng && COND #( WHEN addr-street_lng IS NOT INITIAL THEN ',' )
              && addr-str_suppl1 && COND #( WHEN addr-str_suppl1 IS NOT INITIAL THEN ',' )
              && addr-str_suppl2 && COND #( WHEN addr-str_suppl2 IS NOT INITIAL THEN ',' )
              && addr-str_suppl3 && COND #( WHEN addr-str_suppl3 IS NOT INITIAL THEN ',' )
              && addr-location && COND #( WHEN addr-location IS NOT INITIAL THEN ',' )
              && addr-district.
*              && COND #( WHEN addr-district IS NOT INITIAL THEN ',' ).
*              && addr-postl_cod1.

  ENDMETHOD.


  METHOD properties_css.

    ev_css =
'.p-item-cont {' &&
'    display: flex;' &&
'    height: 6.875rem;' &&
'    padding: 0rem 0.9375rem 0rem 1.5625rem;' &&
'    flex-direction: column;' &&
'    justify-content: center;' &&
'    align-items: flex-start;' &&
'    /*gap: 0.9375rem;*/' &&
'    align-self: stretch;' &&
'    border-radius: 0.375rem;' &&
'    border: 1px solid var(--Gray-2, #D9D9D9);' &&
'    background: var(--White, #FFF);' &&
'' &&
'    /* tile */' &&
'    box-shadow: 0px 0px 7px 0px rgba(173, 173, 173, 0.25);' &&
'}' &&
'' &&
'.p-img-top {' &&
'    position: relative;' &&
'    top: 1px;' &&
'}' &&
'' &&
'.p-img-top:lang(ar) {' &&
'    position: relative;' &&
'    top: 5px;' &&
'}' &&
'' &&
'.p-item-cont-gray {' &&
'   background: var(--Gray0, #F9F9F9) !important;' &&
'}' &&
'' &&
'.properties-gap-012 {' &&
'    gap: 0.12rem;' &&
'}' &&
'' &&
'.p-margin-bottom-1 {' &&
'    margin-bottom: 1rem;' &&
'}' &&
'' &&
'.p-margin-inline-start-2 {' &&
'    margin-inline-start: 2rem;' &&
'}' &&
'' &&
'.rak_properties_disabled_list_hbox[data-journey="POA"] {' &&
'    margin-inline-start: 2rem;' &&
'}' &&
'' &&
'.p-margin-top-1 {' &&
'    margin-top: 1rem;' &&
'}' &&
'' &&
'.p-margin-bottom-05 {' &&
'    margin-bottom: 0.5rem;' &&
'}' &&
'' &&
'.p-seperator {' &&
'    margin-inline-start: 0.5rem !important;' &&
'    margin-inline-end: 0.5rem !important;' &&
'    border-left: 1px solid var(--Gray3);' &&
'    align-self: center;' &&
'}' &&
'' &&
'.case-tag {' &&
'    padding: 0.25rem 0.75rem;' &&
'    border-radius: 0.25rem;' &&
'}' &&
'' &&
'.bg-soft-Green {' &&
'    background: var(--Soft-Green);' &&
'}' &&
'' &&
'.bg-soft-Blue {' &&
'    background: var(--Soft-Azure);' &&
'}' &&
'' &&
'.p-liDecoration {' &&
'    position: absolute;' &&
'    top: 0;' &&
'    left: 0;' &&
'    background: var(--Red);' &&
'    height: 100%;' &&
'    width: 5px;' &&
'    border-start-start-radius: 0.5rem;' &&
'    border-end-start-radius: 0.5rem;' &&
'}' &&
'' &&
'.p-liDecoration:lang(ar) {' &&
'    right: 0;' &&
'}' &&
'' &&
'.p-liDecoration-orange {' &&
'    position: absolute;' &&
'    top: 0;' &&
'    left: 0;' &&
'    background: var(--Orange);' &&
'    height: 100%;' &&
'    width: 5px;' &&
'    border-start-start-radius: 0.5rem;' &&
'    border-end-start-radius: 0.5rem;' &&
'}' &&
'' &&
'.p-liDecoration-orange:lang(ar) {' &&
'    right: 0;' &&
'}' &&
'' &&
'.p-liDecoration-gray {' &&
'    background: var(--Gray4) !important;' &&
'}' &&
'' &&
'.p-propertyList .sapMLIB.sapMLIBSelected {' &&
'    border: 1.5px solid var(--Red) !important;' &&
'}' &&
'' &&
'.p-propertyList .sapMCb {' &&
'    margin-inline-end: -0.2rem;' &&
'    top: 2.5px;' &&
'    /*left: 25px;*/' &&
'    position: absolute;' &&
'}' &&
'' &&
'.p-propertyList .sapMCb:lang(ar) {' &&
'    left: unset;' &&
'    right 25px;' &&
'}' &&
'' &&
'.p-propertyList .sapMCbBg {' &&
'    border: 1px solid var(--Dark-Blue, #10233E);' &&
'    border-radius: 0.125rem;' &&
'    height: 1rem;' &&
'    width: 1rem;' &&
'    font-size: 0.75rem;' &&
'    margin-top: 4px;' &&
'}' &&
'' &&
'.p-propertyList .sapMCbBg.sapMCbMarkChecked {' &&
'    background: var(--Primary-Red, #BF1313);' &&
'    border: 1px solid var(--Primary-Red, #BF1313);' &&
'}' &&
'' &&
'.p-propertyList .sapMCbBg.sapMCbMarkChecked:before {' &&
'    color: white !important;' &&
'}' &&
'' &&
'.list.p-propertyList .listItem .sapMLIB .sapMListBGTranslucent,' &&
'.list.p-propertyList .listItem {' &&
'    padding: 0rem 0.9375rem 0rem 1.5625rem !important;' &&
'}' &&
'' &&
'.listItem.sapMLIBHoverable:hover[data-disabled="X"] {' &&
'    border: 1px solid var(--Gray2, #D9D9D9) !important;' &&
'    background: var(--Gray0) !important;' &&
'}' &&
'' &&
'.listItem.sapMLIBSelected[data-disabled="X"] {' &&
'    border: 1px solid var(--Gray2, #D9D9D9) !important;' &&
'    background: var(--Gray0) !important;' &&
'}' &&
'' &&
'.list.p-propertyList .listItem[data-disabled="X"] {' &&
'    background: var(--Gray0) !important;' &&
'}' &&
'' &&
'.p-icon-margin-1px {' &&
'    margin-top: 1px;' &&
'}' &&
'' &&
'.p-icon-margin-inline-end-3px {' &&
'    margin-inline-end: 3px;' &&
'}' &&
'' &&
'.responsive-box {' &&
'    display: flex;' &&
'    flex-wrap: wrap;' &&
'}' &&
'' &&
'.responsive-box-nowrap {' &&
'    flex-wrap: nowrap;' &&
'}' &&
'' &&
'.color-dark-blue-imp {' &&
'    color: var(--Dark-Blue) !important;' &&
'}' &&
'' &&
'.color-green-imp {' &&
'    color: var(--Green) !important;' &&
'}' &&
'' &&
'.color-azure-imp {' &&
'    color: var(--Azure) !important;' &&
'}' &&
'' &&
'.color-gray6-imp {' &&
'    color: var(--Gray6) !important;' &&
'}' &&
'' &&
'.color-gray7-imp {' &&
'    color: var(--Gray7) !important;' &&
'}' &&
'' &&
'.color-gray5-imp {' &&
'    color: var(--Gray5) !important;' &&
'}' &&
'' &&
'.p-margin-end-1-mobile {' &&
'    margin-inline-end: 1rem !important;' &&
'}' &&
'' &&
'.link-underline {' &&
'    text-decoration: underline !important;' &&
'}' &&
'' &&
'.p-margin-top-025 {' &&
'	margin-top: 0.25rem;' &&
'}' &&
'' &&
'@media only screen and (max-width: 900px) {' &&
'    .p-none-mobile {' &&
'        display: none;' &&
'    }' &&
'' &&
'    .responsive-box {' &&
'        flex-direction: column;' &&
'    }' &&
'' &&
'    .responsive-box>HBox {' &&
'        margin-top: 10px;' &&
'    }' &&
'' &&
'    .p-gap-05-mobile {' &&
'        gap: 0.5rem;' &&
'    }' &&
'' &&
'    .p-margin-top-05-mobile {' &&
'        margin-top: 0.5rem;' &&
'    }' &&
'' &&
'    .p-margin-bottom-05-mobile {' &&
'        margin-bottom: 0.5rem !important;' &&
'    }' &&
'' &&
'    .p-margin-end-1-mobile {' &&
'        margin-inline-end: 0rem !important;' &&
'    }' &&
'' &&
'    .p-margin-inline-start-2 {' &&
'        margin-inline-start: 0;' &&
'    }' &&
'' &&
'    .p-titledeed-hbox {' &&
'        margin-inline-start: 0 !important;' &&
'        margin-top: 30px !important;' &&
'    }' &&
'' &&
'    .rak_properties_disabled_list_hbox[data-journey="POA"] {' &&
'        margin-inline-start: 0;' &&
'    }' &&
'}' &&
'' &&
'@media only screen and (min-width: 901px) {' &&
'    .p-none-desktop {' &&
'        display: none;' &&
'    }' &&
'}    '.

    me->add_style( ev_css ).
  ENDMETHOD.
ENDCLASS.
