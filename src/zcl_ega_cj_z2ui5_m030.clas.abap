class ZCL_EGA_CJ_Z2UI5_M030 definition
  public
  inheriting from Z2UI5_CL_EXT_WIDGETS
  final
  create public .

public section.

  interfaces IF_SERIALIZABLE_OBJECT .
  interfaces Z2UI5_IF_APP .

  types:
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
  types:
    BEGIN OF ty_lessor,
             name        TYPE string,
             nationality TYPE string,
             eid         TYPE string,
             unid        TYPE string,
             passport    TYPE string,
             email       TYPE string,
             phone_no    TYPE string,
           END OF ty_lessor .
  types:
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
        fees        TYPE tt_fees,
        total_fee   TYPE zde_ega_amount,
        attachments TYPE /qnv/sbuild_attachments_tt,
        etisalat    TYPE flag,
      END OF ty_data .

  data GS_DATA type TY_DATA .

  methods NNTC_1_1 .
  methods NNTC_1_2 .
protected section.
private section.

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
  methods LEASE_PROPERTIES .
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
    ENDCASE.
  ENDMETHOD.


  METHOD lease_properties.

    DATA:lr_role    TYPE /iwbep/t_cod_select_options,
         lr_partner TYPE /iwbep/t_cod_select_options.

    SELECT 'I' AS sign, 'EQ' AS option, partner1 AS low, partner1 AS high FROM but050
         INTO TABLE @lr_partner
         WHERE partner2 = @gs_data-partner
           AND date_to >= @sy-datum
           AND date_from <= @sy-datum
           AND reltyp IN ( 'Z00003','Z00004' ).
  ENDMETHOD.


  METHOD nntc_1_2.


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
ENDCLASS.
