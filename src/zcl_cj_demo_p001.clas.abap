class ZCL_CJ_DEMO_P001 definition
  public
  inheriting from Z2UI5_CL_EXT_WIDGETS
  create public .

public section.

  interfaces IF_SERIALIZABLE_OBJECT .
  interfaces Z2UI5_IF_APP .

  types:
    BEGIN OF ty_s_tab,
        selkz            TYPE abap_bool,
        product          TYPE string,
        create_date      TYPE string,
        create_by        TYPE string,
        storage_location TYPE string,
        quantity         TYPE i,
      END OF ty_s_tab .
  types:
    BEGIN OF ty_lic_no_list,
        intreno    TYPE recaintreno,
        recnnr     TYPE recnnumber,
        recntype   TYPE recncontracttype,
        recnbeg    TYPE recncnbeg,
        recnendabs TYPE recncnendabs,
        validfrom  TYPE rebpvalidfrom,
        validto    TYPE rebpvalidto,
        case_id    TYPE scmg_ext_key,
        recntxt    TYPE recntxt,
        selkz      TYPE abap_bool,
      END OF ty_lic_no_list .
  types:
    tt_lic_no_list TYPE STANDARD TABLE OF ty_lic_no_list WITH DEFAULT KEY .

  data:
    mt_table TYPE STANDARD TABLE OF ty_s_tab WITH EMPTY KEY .
  data MV_CHECK_POPOVER type ABAP_BOOL .
  data MV_PRODUCT type STRING .
  data GS_DATA type ZCL_EGA_CJ_PPD_ABS=>TY_DATA .

  methods VIEW_DISPLAY .
  methods POPOVER_DISPLAY
    importing
      !ID type STRING .
  methods SCREEN_NP001_1_1 .
  methods SCREEN_NP001_1_2 .
  methods SCREEN_NP001_1_3 .
  methods SCREEN_NP001_1_4 .
  methods SCREEN_NP001_1_5 .
protected section.
private section.

  methods INIT_JOURNEY .
  methods CSS
    returning
      value(CSS) type STRING .
  methods READ_CASE_DATA .
  methods CREATE_CASE
    importing
      !IV_CASE_TYPE type SCMGCASE_TYPE
      !IV_APPLN_TYPE type ZDE_DOK_APPLICATION_TYPE optional
      !IV_AMENDMENT type ZDE_DOK_AMEND_TYPE optional
      !IS_SUBMIT type FLAG
    returning
      value(ET_RETURN) type BAPIRET2_T .
  methods CASE_MAPPING
    importing
      value(GS_DATA) type ZCL_EGA_CJ_PPD_ABS=>TY_DATA
    returning
      value(LS_REQUEST) type ZCL_EGA_CJ_PPD_ABS=>TY_REQUEST .
  methods GET_CPG_DETAILS
    returning
      value(EV_URL) type STRING .
ENDCLASS.



CLASS ZCL_CJ_DEMO_P001 IMPLEMENTATION.


  METHOD CSS.

    DATA: lv_size_txt TYPE soli-line,
          ls_key      TYPE wwwdatatab,
          lv_len      TYPE i,
          lt_file     TYPE w3html_tab.

    CALL FUNCTION 'WWWPARAMS_READ'
      EXPORTING
        relid            = 'HT'
        objid            = 'Z2UI5_STYLES'
        name             = 'filesize'
      IMPORTING
        value            = lv_size_txt
      EXCEPTIONS
        entry_not_exists = 1
        OTHERS           = 2.
    IF sy-subrc EQ 0.
      ls_key-relid = 'HT'.
      ls_key-objid = 'Z2UI5_STYLES'.
      CALL FUNCTION 'WWWDATA_IMPORT'
        EXPORTING
          key               = ls_key
        TABLES
          html              = lt_file
        EXCEPTIONS
          wrong_object_type = 1
          import_error      = 2
          OTHERS            = 3.
      lv_len = lines( lt_file ) * 255.
      CALL FUNCTION 'SCMS_FTEXT_TO_STRING'
        EXPORTING
          length    = lv_len
        IMPORTING
          ftext     = css
        TABLES
          ftext_tab = lt_file.

      CONDENSE css.

    ENDIF.

  ENDMETHOD.


  METHOD init_journey.

    IF gs_data-partner_name IS INITIAL AND gs_data-partner IS NOT INITIAL.
      SELECT SINGLE zzreferencea AS name_ar, zzfull_name_eng AS name_en FROM but000 INTO @DATA(ls_name) WHERE partner EQ @gs_data-partner.
      IF sy-subrc EQ 0.
        CASE sy-langu.
          WHEN 'E'.
            gs_data-partner_name = ls_name-name_en.
          WHEN 'A'.
            gs_data-partner_name = ls_name-name_ar.
        ENDCASE.
      ENDIF.
      SELECT SINGLE idnumber FROM but0id INTO gs_data-partner_id
        WHERE partner EQ gs_data-partner
        AND   type    EQ 'YFS002'.
*      DATA(lv_role_bp) = rolebp.
*      IF lv_role_bp IS INITIAL.
*        lv_role_bp = loginbp.
*      ENDIF.
    ENDIF.

    SELECT SINGLE description FROM zega_t_cj_idt
      INTO gs_data-description
      WHERE spras EQ sy-langu
      AND journeyid EQ gs_data-journeytype.

    SELECT SINGLE rechar FROM zega_t_cj_2_obj INTO @gs_data-case-product_id
      WHERE journeyid EQ @gs_data-journeytype
      AND   journeyfield EQ 'PRODUCT_ID'.

    APPEND INITIAL LINE TO gs_data-service_price ASSIGNING FIELD-SYMBOL(<service_price>).
    <service_price>-product_id = gs_data-case-product_id.

    CALL FUNCTION 'ZFM_FILL_SERVICE_PRICE'
      EXPORTING
        i_date           = sy-datum
      CHANGING
        et_service_price = gs_data-service_price.
    READ TABLE gs_data-service_price ASSIGNING <service_price> INDEX 1.
    IF sy-subrc EQ 0.
      APPEND INITIAL LINE TO gs_data-fees ASSIGNING FIELD-SYMBOL(<fee>).
      <fee>-fee = <service_price>-kbetr.
      gs_data-total_fee = <service_price>-kbetr.

      DATA: lt_dropdown TYPE zta_wda_drop_values.
      APPEND INITIAL LINE TO lt_dropdown ASSIGNING FIELD-SYMBOL(<dropdown>).
      <dropdown>-key = gs_data-case-product_id.
      CALL FUNCTION 'ZWDA_GET_ITEM_DESCR'
        EXPORTING
          i_langu     = sy-langu
        CHANGING
          ct_dropdown = lt_dropdown.
      READ TABLE lt_dropdown ASSIGNING <dropdown> INDEX 1.
      IF sy-subrc EQ 0.
        <fee>-description = <dropdown>-value.
      ENDIF.
    ENDIF.
    "
    CLEAR: mt_stages[].
    APPEND INITIAL LINE TO mt_stages ASSIGNING FIELD-SYMBOL(<stage>).
    <stage>-stagelabel      = 'Case details'.
    <stage>-screen          = 'SCREEN_NP001_1_1'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Case details'.
    <stage>-screen          = 'SCREEN_NP001_1_2'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Documents'.
    <stage>-screen          = 'SCREEN_NP001_1_3'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Payment'.
    <stage>-screen          = 'SCREEN_NP001_1_4'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Confirmation'.
    <stage>-screen          = 'SCREEN_NP001_1_5'.

  ENDMETHOD.


  METHOD POPOVER_DISPLAY.

    DATA(lo_popover) = z2ui5_cl_xml_view=>factory_popup( ).

    lo_popover->popover( placement    = `Right`
                         title        = |CJS - Popover - { mv_product }|
                         contentwidth = `50%`
      )->simple_form( editable = abap_true
      )->content( `form`
          )->label( `Product`
          )->text( mv_product
          )->label( `info2`
          )->text( `this is a text`
          )->label( `info3`
          )->text( `this is a text`
          )->text( `this is a text`
        )->get_parent( )->get_parent(
        )->footer(
         )->overflow_toolbar(
            )->toolbar_spacer(
            )->button(
                text  = `details`
                press = client->_event( `BUTTON_DETAILS` )
                type  = `Emphasized` ).
    client->popover_display( xml   = lo_popover->stringify( )
                             by_id = id ).

  ENDMETHOD.


  method READ_CASE_DATA.


  endmethod.


  METHOD screen_np001_1_1.
    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(fisrt) = view->vbox( class = 'RAKEGA-firstContainer' ).
    DATA(card) = fisrt->vbox( class = 'RAKEGA-card' ).
    DATA(card_top) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title) = card_header->hbox( alignitems = 'Center' ).
    DATA(ppd_logo) = title->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    " AMBIGUOUS(TITLE_TEXT): VALUE='DOKSL_ND016_1_1_TITLE_TEXT' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(title_text) = title->label(
    text = '{/XX/GS_DATA/DESCRIPTION}'
    class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    " TODO(STAGES): RAKSTAGEBAR is a custom extension control (EXTENDED=X) - exact z2ui5 API not yet confirmed.
    "   source data: steps=4 current=1
    DATA(stages) = card_top->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder - see TODO above
    me->rakstagebar( stages ).

    DATA(body) = card->vbox( class = 'RAKEGA-part2' ).
    DATA(hbox_4) = body->hbox( justifycontent = 'Center' ).
    DATA(vbox_9) = hbox_4->vbox( class = 'sapUiLargeMarginTop page-bg' alignitems = 'Center' aligncontent = 'Center' ).
    DATA(vbox_8) = vbox_9->vbox( class = 'sapUiLargeMarginTopBottom sapUiLargeMarginBeginEnd' ).
    DATA(label_9) = vbox_8->label( text = get_text_by_id( 'PPD_NP001_1_1_LABEL_9' ) class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    " VBOX_5/VBOX_6/VBOX_7 have no children anywhere in the source export - rendered as empty spacer boxes.
*    DATA(vbox_6) = vbox_8->vbox( class = 'sapUiMediumMarginTop' ).
*    DATA(vbox_7) = vbox_8->vbox( class = 'sapUiMediumMarginTop' ).
*    DATA(vbox_5) = vbox_8->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(hbox_5) = vbox_8->hbox( class = 'sapUiMediumMarginTop' justifycontent = 'SpaceBetween' ).
    DATA(label_7) = hbox_5->label( text = get_text_by_id( 'PPD_NP001_1_1_LABEL_7' ) class = 'Body_1_3 color-gray6 sapUiSmallMarginBeginEnd' required = 'true'  ).
    DATA(case_number_1) = hbox_5->input(
    value = '{path: ''/XX/GS_DATA/CASE/CASE_NUMBER'', type: ''sap.ui.model.odata.type.String'', constraints: { isDigitSequence: true, maxLength: 8}}'
    required = 'true' class = 'input noMax' width = '12rem' ).
    DATA(hbox_6) = vbox_8->hbox( class = 'sapUiMediumMarginTop' justifycontent = 'SpaceBetween' ).
    DATA(label_8) = hbox_6->label( text = get_text_by_id( 'PPD_NP001_1_1_LABEL_8' ) class = 'Body_1_3 color-gray6 sapUiSmallMarginBeginEnd' required = 'true'  ).
    DATA(year_1) = hbox_6->input( value = '{path: ''/XX/GS_DATA/CASE/YEAR'', type: ''sap.ui.model.odata.type.String'', constraints: { isDigitSequence: true, maxLength: 4}}'
    required = 'true'  class = 'input noMax' width = '12rem' ).
    DATA(hbox_7) = vbox_8->hbox( class = 'sapUiMediumMarginTop' justifycontent = 'SpaceBetween' ).
    DATA(label_6) = hbox_7->label( text = get_text_by_id( 'PPD_NP001_1_1_LABEL_6' ) class = 'Body_1_3 color-gray6 sapUiSmallMarginBeginEnd' required = 'true' ).


    DATA(case_type_1) = hbox_7->combo_box( selectedkey = '{/XX/GS_DATA/CASE/CASE_TYPE}' placeholder = get_text_by_id( 'SELECT' ) required = 'true' class = 'combobox noMax' width = '12rem' ).
    get_value_list( parent = case_type_1 shlpname = 'ZSH_CJ_PPD_CASE_TYPE' keyfield = 'KEY' valuefield = 'VALUE' ).

    " TODO(CASE_TYPE_1): items come from search-help ZSH_CJ_PPD_CASE_TYPE - value-list binding pattern not yet confirmed
*    DATA(journey) = hbox_7->label( text = '{JOURNEYTYPE}' ).
    DATA(footer) = fisrt->hbox( class = 'RAKEGA-footer RAKEGA-next-btn-end' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' visible = 'false' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(next) = footer->button( iconfirst = 'false' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).

    client->view_display( view->stringify( ) ).


  ENDMETHOD.


  METHOD screen_np001_1_2.

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(fisrt) = view->vbox( class = 'RAKEGA-firstContainer' ).
    DATA(card) = fisrt->vbox( class = 'RAKEGA-card' ).
    DATA(card_top) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title) = card_header->hbox( alignitems = 'Center' ).
    DATA(ppd_logo) = title->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    " AMBIGUOUS(TITLE_TEXT): VALUE='DOKSL_ND016_1_1_TITLE_TEXT' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(title_text) = title->label( text = gs_data-description class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).

    DATA(context_hbox_desktop) = card_header->hbox( class = 'RAKEGA-context-hbox-desktop' ).
    DATA(context1_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    " AMBIGUOUS(CTX1_D_LABEL): literal text 'CNTITLE', not an i18n key pattern - confirm
    DATA(ctx1_d_label) = context1_d_cont->label( text = get_text_by_id( 'CNTITLE' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX1_D_VALUE): VALUE='F9' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx1_d_value) = context1_d_cont->label( text = gs_data-case-case_number class = 'Body_1_3 color-gray7' ).
    DATA(context1_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context3_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    DATA(ctx3_d_label) = context3_d_cont->label( text = get_text_by_id( 'PPD_NP001_1_1_LABEL_8' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX3_D_VALUE): VALUE='Aug 23, 2023' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx3_d_value) = context3_d_cont->label( text = gs_data-case-year class = 'Body_1_3 color-gray7' ).
    DATA(context3_d_separator) = context_hbox_desktop->vbox( class = 'RAKEGA-context-separator' ).
    DATA(context4_d_cont) = context_hbox_desktop->hbox( class = 'RAKEGA-context-cont' ).
    " AMBIGUOUS(CTX4_D_LABEL): VALUE='Case Description' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx4_d_label) = context4_d_cont->label( text = gs_data-case-description class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX4_D_VALUE): VALUE='Aug 23, 2023' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx4_d_value) = context4_d_cont->label( text = gs_data-public_court-order_descr class = 'Body_1_3 color-gray7' ).

    DATA(buttons) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = buttons->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = buttons->button( id = 'SAVEDRAFT_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = buttons->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = buttons->button( id = 'DELETE_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(error_1) = card_top->message_strip( text = '{/XX/GS_DATA/ERROR}' visible = '{= ${/XX/GS_DATA/ERROR} !== '''' }'
    type = 'Error' showicon = 'true' showclosebutton = 'true' ).  " TODO(ERROR_1): EXTENDED=X, param names assumed - confirm
    " TODO(STAGES): RAKSTAGEBAR - source data: steps=4 current=1 texts=First,Second,Third,Fourth
    DATA(stages) = card_top->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder
    me->rakstagebar( stages ).

    DATA(body) = card->vbox( class = 'RAKEGA-part2' ).
    DATA(hbox_10) = body->hbox( justifycontent = 'SpaceBetween' ).
    DATA(vbox_11) = hbox_10->vbox( class = 'width49' ).
    DATA(applicant) = vbox_11->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APPLICANT' ) class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(applicant_top) = vbox_11->hbox( justifycontent = 'Start' alignitems = 'Start' ).
    DATA(app_name_box) = applicant_top->vbox( aligncontent = 'Start' ).
    DATA(app_name_text) = app_name_box->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APP_NAME_TEXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(app_name) = app_name_box->label( text = '{/XX/GS_DATA/PARTNER_NAME}' class = 'font1 weight500 color-gray7 sapUiSmallMarginTop' ).
    DATA(app_id_box) = applicant_top->vbox( class = 'sapUiLargeMarginBegin' aligncontent = 'Start' ).
    DATA(app_id_text) = app_id_box->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APP_ID_TEXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(app_id) = app_id_box->label( text = '{/XX/GS_DATA/PARTNER_ID}' class = 'font1 weight500 color-gray7 sapUiSmallMarginTop' ).
    DATA(vbox_12) = hbox_10->vbox( width = '49%' ).
    DATA(partner) = vbox_12->label( text = get_text_by_id( 'PPD_NP001_1_2_PARTNER' ) class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(hbox_11) = vbox_12->hbox( justifycontent = 'Start' alignitems = 'Start' ).
    DATA(vbox_13) = hbox_11->vbox( aligncontent = 'Start' ).
    DATA(label_17) = vbox_13->label( text = get_text_by_id( 'PPD_NP001_1_2_LABEL_17' ) class = 'font1 weight400 color-gray6' ).
    DATA(partner_name_1) = vbox_13->label( text = '{/XX/GS_DATA/CASE/PARTNER_NAME}' class = 'font1 weight500 color-gray7 sapUiSmallMarginTop' ).
    DATA(vbox_14) = hbox_11->vbox( class = 'sapUiLargeMarginBegin' aligncontent = 'Start' ).
    DATA(label_18) = vbox_14->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APP_ID_TEXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(partner_id_1) = vbox_14->label( text = '{/XX/GS_DATA/CASE/PARTNER_ID}' class = 'font1 weight500 color-gray7 sapUiSmallMarginTop' ).
    DATA(hseparator_1) = body->hbox( class = 'sapUiMediumMarginTop RAKEGA-hr' ).  " horizontal rule
    DATA(hbox_12) = body->hbox( class = 'sapUiMediumMarginTop' ).
    DATA(label_21) = hbox_12->label( text = get_text_by_id( 'PPD_NP001_1_2_LABEL_21' ) class = 'font1 weight500 color-gray6' ).
    DATA(category_txt_1) = hbox_12->label( text = '{/XX/GS_DATA/PUBLIC_COURT/CATEGORY_TXT}' class = 'font1 weight500 color-blue sapUiMediumMarginBeginEnd' ).
    DATA(vbox_9) = body->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(label_13) = vbox_9->label( text = get_text_by_id( 'PPD_NP001_1_2_LABEL_13' ) class = 'font1 weight500 color-gray6' ).
    DATA(category_1) = vbox_9->combo_box( selectedkey = '{/XX/GS_DATA/CATEGORY}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).

    DATA: lt_selopt TYPE ddshselops.
    CLEAR: lt_selopt[].
    APPEND INITIAL LINE TO lt_selopt ASSIGNING FIELD-SYMBOL(<selopt>).
    <selopt>-shlpname  = 'ZSH_CJ_PPD_CATEGORY'.
    <selopt>-shlpfield = 'CASE_TYPE'.
    <selopt>-sign      = 'I'.
    <selopt>-option    = 'EQ'.
    <selopt>-low       = gs_data-case-case_type.
    <selopt>-high      = gs_data-case-case_type.

    get_value_list( parent = category_1 shlpname = 'ZSH_CJ_PPD_CATEGORY' keyfield = 'KEY' valuefield = 'VALUE' it_selopt = lt_selopt ).

*    DATA(case_type) = vbox_9->label( text = '{/XX/GS_DATA/CASE/CASE_TYPE}' ).
    DATA(delivery) = body->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(delivery_text) = delivery->label( text = get_text_by_id( 'PPD_NP001_1_2_DELIVERY_TEXT' ) class = 'font1 weight500 color-gray6' ).
    DATA(delivery_val) = delivery->combo_box( selectedkey = '{/XX/GS_DATA/DELIVERY}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).

    CLEAR: lt_selopt[].
    APPEND INITIAL LINE TO lt_selopt ASSIGNING <selopt>.
    <selopt>-shlpname  = 'ZSH_CJ_PPD_DELIVERY'.
    <selopt>-shlpfield = 'PRODUCT_ID'.
    <selopt>-sign      = 'I'.
    <selopt>-option    = 'EQ'.
    <selopt>-low       = gs_data-case-product_id.
    <selopt>-high      = gs_data-case-product_id.
    get_value_list( parent = delivery_val shlpname = 'ZSH_CJ_PPD_DELIVERY' keyfield = 'KEY' valuefield = 'VALUE' it_selopt = lt_selopt ).

*    DATA(product_id) = delivery->label( text = '{XX/GS_DATA/CASE/PRODUCT_ID}' ).
    DATA(vbox_10) = body->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(notes_text) = vbox_10->label( text = get_text_by_id( 'PPD_NP001_1_2_NOTES_TEXT' ) class = 'font1 weight500 color-gray6' ).
    DATA(notes) = vbox_10->text_area( value = '{XX/GS_DATA/NOTES}' class = 'textarea' ).
    DATA(footer) = fisrt->hbox( class = 'RAKEGA-footer' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(next) = footer->button( iconfirst = 'false' id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD screen_np001_1_3.

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(firstcontainer) = view->vbox( class = 'RAKEGA-firstContainer' ).
    DATA(card) = firstcontainer->vbox( class = 'RAKEGA-card' ).
    DATA(card_top) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(card_header_title) = card_header->hbox( alignitems = 'Center' ).
    DATA(ppd_logo) = card_header_title->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    " AMBIGUOUS(TITLE_TEXT): VALUE='DOKSL_ND016_1_1_TITLE_TEXT' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(title_text) = card_header_title->label( text = '{/XX/GS_DATA/DESCRIPTION}' class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(card_header_end) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = card_header_end->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event(
  'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = card_header_end->button( id = 'SAVEDRAFT_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = card_header_end->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = card_header_end->button( id = 'DELETE_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(stages) = card_top->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder
    me->rakstagebar( stages ).

    DATA(body) = card_top->vbox( ).
    DATA(size_warning) = body->vbox( ).
    DATA(hbox_7) = size_warning->hbox( ).
    DATA(icon_info2) = hbox_7->icon( src = 'sap-icon://icomoon/info' class = 'font1 weight400 color-azure' ).
    DATA(file_size_limit) = hbox_7->label( text = get_text_by_id( 'DOKSL_ND001_1_4_FILE_SIZE_LIMIT' ) class = 'font1 weight400 color-azure sapUiSmallMarginBegin' ).

    rakuploader( body ).

*    DATA(attach_10) = attachments->file_uploader( id = 'ATTACH_10' ).
    DATA(vbox_6) = body->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(others_txt) = vbox_6->label( text = get_text_by_id( 'DOKSL_ND001_1_4_OTHERS_TXT' ) class = 'font1 weight500 color-gray7 sapUiMediumMarginTop' ).
*    DATA(others) = vbox_6->file_uploader( id = 'OTHERS' ).
    DATA(declaration_cont) = vbox_6->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(declaration_txt) = declaration_cont->label( text = get_text_by_id( 'DOKSL_ND001_1_4_DECLARATION_TXT' ) class = 'font1 weight600 color-gray7' ).
    DATA(declaration) = declaration_cont->hbox( class = 'sapUiSmallMarginTop' ).
    " TODO(DECLARATION_NAME): no VALUE and no TECHNICAL_NAME in source - binding unknown
    DATA(declaration_name) = declaration->label( text = '' class = 'font1 weight400 color-gray7' ).
    DATA(lv_declaration) = get_text_by_id( 'E003_DECLARATION_TEXT1' ).
    DATA(lv_declaration2) = get_text_by_id( 'E003_DECLARATION_TEXT2' ).
    CONCATENATE lv_declaration lv_declaration2 INTO lv_declaration SEPARATED BY space.
    DATA(declaration_long1) = declaration->label( text = lv_declaration class = 'font1 weight400 color-gray7' wrapping = 'true').
    DATA(disclaimer) = declaration_cont->hbox( class = 'sapUiMediumMarginTopBottom' ).
    DATA(icon_info) = disclaimer->icon( src = 'sap-icon://icomoon/info' class = 'font1 weight400 color-red' ).
    DATA(disclaimer_txt) = disclaimer->label( text = get_text_by_id( 'DOKSL_ND001_1_4_DISCLAIMER_TXT' ) class = 'font1 weight400 color-red sapUiSmallMarginBegin' wrapping = 'true' ).
    DATA(footer) = firstcontainer->hbox( class = 'RAKEGA-footer' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(pay) = footer->button( iconfirst = 'false' id = 'PAY' text = get_text_by_id( 'PAY_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).
    " VISIBLE is NOT 'X' for NEXT (the only control on this whole screen where that's true) - PAY and
    " NEXT both fire EVENT=SAVE and sit in the same footer, so this looks exactly like the "PAY vs
    " NEXT" toggle you asked about earlier: show PAY when a payment is due, NEXT/Submit otherwise.
    " Nothing in DEPENDENT_FIELD/UI_FIELD_LOGICS names the driving flag, so this is a placeholder.
*    DATA(next) = footer->button( id = 'NEXT' text = get_text_by_id( 'SUBMIT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' visible = '{TODO_PAYMENT_NOT_DUE}' press = client->_event( 'SAVE' ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD screen_np001_1_4.
    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).

    me->rakpay( view ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD screen_np001_1_5.

    me->rakhappy( ).

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(first_container) = view->vbox( class = 'RAKEGA-firstContainer' ).
    DATA(card) = first_container->vbox( class = 'RAKEGA-card' ).
    DATA(stage_cont) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(header_text_cont) = stage_cont->vbox( justifycontent = 'SpaceBetween' ).
    DATA(label_cont) = header_text_cont->hbox( justifycontent = 'Start' alignitems = 'Center' aligncontent = 'Center' ).
    DATA(ppd_logo) = label_cont->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    DATA(title_text) = label_cont->label( text = '{/XX/GS_DATA/DESCRIPTION}' class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(stages) = stage_cont->hbox( class = 'sapUiLargeMarginBegin' ).
    me->rakstagebar( stages ).

    DATA: flamingo TYPE string,
          xstring  TYPE xstring.

    flamingo =
'<svg width="300" height="190" viewBox="0 0 300 190" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<g clip-path="url(#clip0_3635_9480)">' &&
'<ellipse cx="210.25" cy="174.5" rx="54.75" ry="13" fill="#BF1313" fill-opacity="0.25"/>' &&
'<path d="M94.9641 72.5L95.766 70.8149L97.2361 67.9851C98.8805 64.8182 100.972 61.9071 103.448 59.333L116.208 41.9067C116.621' &&
' 41.3431 117.062 40.7969 117.527 40.2797C119.084 38.5423 120.909 37.078 122.943 35.9391L139.061 26.8861C141.653 25.4276' &&
' 144.123 23.7599 146.435 21.8889C153.083 16.5198 158.957 10.2559 163.885 3.27144L165.831 0.505553C166.162 0.0348878' &&
' 166.895 0.337044 166.703 1.49918L166.157 4.7183C164.902 12.1153 162.438 19.2508 158.847 25.8343C156.395 30.3434 153.425' &&
' 35.7241 150.259 41.0816C143.03 53.3131 133.233 63.8304 121.554 71.9189L121.699 72.1165C122.617 73.389 124.041 74.2025' &&
' 125.604 74.3536L125.958 74.3884C132.129 74.9637 137.957 77.4797 142.612 81.5646L142.769 81.6983C145.099 83.7437 146.9' &&
' 86.3236 148.027 89.2115C148.411 90.1935 148.754 91.0767 148.94 91.5474C148.992 91.6752 148.858 91.7973 148.73 91.7392L146.18' &&
' 90.5538L151.595 100.507C151.676 100.664 151.531 100.839 151.363 100.781C149.596 100.17 148.021 99.0955 146.813 97.6661L145.651' &&
' 96.2947C143.942 94.2784 141.804 92.6631 139.398 91.5706C137.028 90.4899 134.448 89.9378 131.845 89.9553L126.394' &&
' 89.9843C125.999 89.9843 125.639 90.1993 125.447 90.548C125.18 91.0361 125.319 91.6462 125.778 91.96L130.003 94.9176L132.083' &&
' 96.533C132.553 96.8991 132.629 97.5847 132.251 98.0438L131.519 98.9328C131.176 99.3512 130.578 99.4441 130.125 99.1478L127.463' &&
' 97.422C124.866 95.7369 121.891 94.7491 118.817 94.5341C118.05 94.4818 117.277 94.4528 116.51 94.3714L115.65 94.2842C114.052' &&
' 94.1157 112.472 93.8601 110.903 93.523L110.461 93.4243C107.678 92.8199 104.854 92.4248 102.012 92.2505C98.805 92.0529 95.6149' &&
' 91.6694 92.4481 91.0942C88.7002 90.4143 84.9813 89.595 81.2916 88.6421L79.5425 88.1888C78.9731 88.0436 78.3862 87.9622 77.7935' &&
' 87.9506H77.7064C77.073 87.9332 76.4396 88.0029 75.8237 88.1423C72.7499 88.8338 62.4591 90.7281 56.5322 86.6432L54.8994' &&
' 85.3765C52.6797 83.6565 50.6286 81.7273 48.7691 79.6239C47.0085 77.625 45.428 75.475 44.0451 73.1914L40.0764 66.6312L37.8567' &&
' 63.8072C37.0316 62.7554 36.0263 61.8548 34.8932 61.1459C33.9809 60.5764 32.9989 60.1406 31.9704 59.8385L30.204 59.3271C29.4486' &&
' 59.1121 28.6758 58.9669 27.8913 58.9088L27.38 58.8681C25.5729 58.7286 23.7832 58.3684 22.0632 57.7989C21.2788 57.5433 20.5118' &&
' 57.2411 19.7622 56.8983L18.449 56.2998" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M99.5544 63.9059L98.5666 64.057C96.8931 64.3127 95.2429 64.6846 93.6275 65.1727C90.8442 66.0152 88.1829 67.2296' &&
' 85.725 68.7811L85.2659 69.2053C84.4408 69.9665 83.1392 71.2623 82.378 72.0874L82.3664 72.099L80.844 73.7551C78.6824 76.1026' &&
' 76.0909 78.0201 73.2088 79.403C71.8374 80.0596 70.3731 80.4954 68.8682 80.693L66.9739 80.9429C65.1784 81.1811 63.3596' &&
' 81.0765 61.6048 80.6349L60.3671 80.3269C58.6356 79.8911 56.9969 79.1416 55.5385 78.1073C54.1265 77.1078 52.9004 75.8585' &&
' 51.93 74.4175L49.9311 71.4598C46.2123 65.9571 41.9879 60.8205 37.3045 56.108C36.8745 55.6722 36.4736 55.2073 36.1133' &&
' 54.7076L34.8059 52.9063C33.975 51.7558 32.9407 50.768 31.7611 49.9835C30.0702 48.8621 28.1236 48.1938 26.1015 48.0369L24.6663' &&
' 47.9265C23.6552 47.851 22.6383 47.9033 21.6447 48.0834L21.052 48.188C19.9945 48.3798 18.9892 48.7807 18.0828 49.3618" stroke="#BF1313" stroke-miterlimit="10"/>' &&
'<path d="M24.9569 52.058C25.4511 52.058 25.8517 51.6574 25.8517 51.1632C25.8517 50.6689 25.4511 50.2683 24.9569 50.2683C24.4626' &&
' 50.2683 24.062 50.6689 24.062 51.1632C24.062 51.6574 24.4626 52.058 24.9569 52.058Z" stroke="#BF1313" stroke-miterlimit="10"/>' &&
'<path d="M132.612 97.8345L156.389 110.234C158.033 111.007 159.579 111.989 160.973 113.157L161.032 113.21C161.334 113.459 161.555' &&
' 113.791 161.682 114.163C162.037 115.232 162.618 116.208 163.385 117.033L192.711 148.602L192.874 148.742C194.036 149.759' &&
' 195.518 150.34 197.058 150.381C197.982 150.404 198.871 150.752 199.568 151.357L210.132 160.503C210.393 160.729 210.289' &&
' 161.159 209.952 161.235L208.563 161.554C208.243 161.63 207.918 161.647 207.593 161.607L206.675 161.491C206.512 161.473' &&
' 206.355 161.438 206.204 161.392C204.6 160.898 203.147 159.991 202.003 158.765L197.976 154.471C197.703 154.181 197.389' &&
' 153.931 197.04 153.733C193.525 152.374 190.387 150.2 187.883 147.382L160.602 116.684C159.66 115.627 158.62 114.662 157.493' &&
' 113.808C156.662 113.175 155.785 112.611 154.866 112.106L131.292 99.1361" stroke="#BF1313" stroke-miterlimit="10"/' &&
'<path d="M114.377 93.5115L116.289 97.6254C116.638 98.375 117.521 98.712 118.276 98.3867L118.788 98.1658C119.578 97.8288 119.938' &&
' 96.8991 119.572 96.1147L118.73 94.2959" stroke="#BF1313" stroke-miterlimit="10"/>' &&
'<path d="M117.684 98.7119L135.592 122.722C135.755 122.937 135.877 123.187 135.947 123.448L136.069 123.878C136.272 124.599 136.092' &&
' 125.371 135.598 125.929C135.343 126.22 135.011 126.441 134.639 126.563L133.442 126.958C133.344 126.993 133.245 127.016 133.14' &&
' 127.033L97.8055 133.419C96.1843 133.716 94.5341 133.861 92.8838 133.861L90.6583 133.797C88.7815 133.745 86.9221 134.244 85.3241' &&
' 135.232L85.2021 135.308C84.8767 135.511 84.5571 135.732 84.255 135.976L74.9927 142.298C74.5918 142.571 74.7661 143.199 75.2542' &&
' 143.222L76.1549 143.268C77.1834 143.321 78.2118 143.268 79.2345 143.123L80.7627 142.902C81.4426 142.803 82.1166 142.664 82.7791' &&
' 142.484C84.9116 141.897 86.9046 140.874 88.6304 139.486L89.9378 138.434C90.8094 137.731 91.8612 137.295 92.971 137.173C93.5869' &&
' 137.103 94.197 136.999 94.8014 136.853L99.171 135.802L128.317 130.02C129.259 129.857 130.212 129.753 131.165 129.706L134.198' &&
' 129.567L135.935 129.427H135.993C138.591 129.195 140.131 126.406 138.928 124.087C138.55 123.361 138.114 122.669 137.626 122.019L119.2 97.637" stroke="#BF1313" stroke-miterlimit="10"/>' &&
'<path d="M119.979 67.5085L121.652 57.241C122.21 53.8243 123.303 50.5181 124.889 47.4384C126.638 44.0566 128.957 41.0001' &&
' 131.746 38.4086L134.076 36.247C135.581 34.8466 137.219 33.5915 138.963 32.4991L144.425 29.065C146.377 27.8389 148.196' &&
' 26.4095 149.846 24.8058L154.367 20.4129C157.022 17.8329 159.224 14.8288 160.88 11.5167L166.401 0.604248" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M88.1192 67.2761C88.1192 67.2761 84.7955 50.8376 83.151 45.6835C82.4712 43.5626 82.2446 39.4603 83.6972 34.5096C85.7252' &&
' 27.5891 89.3743 21.2496 94.11 15.805C96.4633 13.0972 99.0258 10.5696 101.768 8.25109L108.91 2.21379C109.369 1.82447 110.031' &&
' 2.34162 109.77 2.88202L105.342 12.0513C102.75 17.4262 101.408 23.3589 101.751 29.3206C101.966 33.0976 102.809 37.0953' &&
' 104.964 40.2273C107.3 43.6208 108.753 47.328 109.514 50.8376" stroke="#BF1313" stroke-miterlimit="10"/' &&
'<path d="M109.311 2.38818L98.7991 16.7929C97.451 18.6407 96.3877 20.7035 95.8705 22.9348C95.8705 22.9522 95.8647 22.9638 95.8589' &&
' 22.9813C95.5509 24.3119 95.394 25.6716 95.394 27.0371V27.4962C95.394 32.2958 96.4923 37.0373 98.6015 41.3488C99.0141 42.1856' &&
' 99.3569 43.0572 99.6358 43.952C101.234 49.1294 102.047 54.5101 102.047 59.9314V61.0761" stroke="#BF1313" stroke-miterlimit="10"/>' &&
'<path d="M0.429975 59.7863C0.226601 59.4609 0.244033 59.0483 0.47065 58.7403L4.65435 53.0401C5.71189 51.6048 7.13551 50.4834' &&
' 8.77993 49.7977C9.15763 49.6408 9.55857 49.5537 9.97113 49.5478L16.8742 49.3851C18.2223 49.3503 19.4484 50.1405 19.9829' &&
' 51.3782C20.2909 52.0929 20.3374 52.8948 20.1108 53.6386L19.9423 54.1964C19.6459 55.1784 18.908 55.9628 17.9492 56.3289L17.0834' &&
' 56.6543C16.6244 56.8286 16.1305 56.8984 15.6365 56.8577L14.1723 56.7357C11.9642 56.5497 9.7387 56.7763 7.61199 57.4039C5.81067' &&
' 57.9327 4.0849 58.6822 2.46372 59.6236L1.71414 60.0942C1.27252 60.3732 0.691456 60.2337 0.418354 59.7921L0.429975 59.7863Z" fill="#BF1313" stroke="#BF1313" stroke-miterlimit="10"/>' &&
'<path d="M228.639 173.315C229.609 173.734 230.15 174.193 230.15 174.675C230.15 176.552 221.986 178.074 211.916 178.074C207.796' &&
' 178.074 203.99 177.819 200.939 177.389C196.529 176.767 193.682 175.785 193.682 174.675C193.682 174.158 194.304 173.664' &&
' 195.419 173.222" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M182.037 179.324C175.64 178.028 171.729 176.296 171.729 174.39C171.729 173.281 173.065 172.223 175.454 171.282" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M225.263 181.16C220.783 181.491 215.896 181.677 210.783 181.677C201.956 181.677 193.816 181.131 187.273' &&
' 180.213C186.802 180.149 186.337 180.079 185.878 180.009" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M246.594 171.485C248.674 172.374 249.831 173.362 249.831 174.39C249.831 177.203 241.271 179.649 228.744 180.858" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M201.631 184.751C194.193 184.443 187.354 183.844 181.479 183.019C179.945 182.804 178.475 182.572 177.081 182.328" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M260.801 171.351C263.585 172.543 265.13 173.856 265.13 175.239C265.13 177.319 261.626 179.248 255.665 180.834" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M211.265 189.44C196.831 189.44 183.513 188.545 172.822 187.04C157.383 184.867 148.411 181.282 147.406 177.528C146.761' &&
' 175.122 151.438 172.967 154.204 171.636C155.082 171.212 155.831 171.02 155.186 170.288L155.151 170.247C154.872 169.933 154.477' &&
' 169.753 154.059 169.759C151.578 169.777 138.887 172.136 129.567 172.409C119.729 172.699 112.106 172.769 101.873 172.572C95.2547' &&
' 172.444 88.6421 172.002 82.0702 171.264L73.8423 170.34" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M275.124 177.534C275.124 182.671 257.692 187.046 233.264 188.72" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M299.709 170.753C295.334 171.258 285.177 173.124 271.417 170.753" stroke="#BF1313" stroke-miterlimit="10" stroke-linecap="round"/>' &&
'<path d="M129.75 39.25C121.87 43.5656 122.75 65.25 122.75 65.25C122.75 65.25 145.773 42.0326 152.5 33.5C159.798 24.2421 166 6.5' &&
' 166 6.5C166 6.5 140.25 33.5 129.75 39.25Z" fill="#BF1313" fill-opacity="0.3"/>' &&
'</g>' &&
'<defs>' &&
'<clipPath id="clip0_3635_9480">' &&
'<rect width="300" height="189.731" fill="white"/>' &&
'</clipPath>' &&
'</defs>' &&
'</svg>'.

    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = flamingo
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = flamingo.
    flamingo = 'data:image/svg+xml;base64,' && flamingo.


    DATA(general) = stage_cont->hbox( justifycontent = 'SpaceBetween' ).
    DATA(results_box) = general->vbox( ).
    DATA(request_1_txt) = results_box->label( text = get_text_by_id( 'E003_REQUEST_SUBMITTED' ) class = 'font1 weight600 color-dark-blue sapUiMediumMarginTop' ).
    DATA(request_2_txt) = results_box->label( text = get_text_by_id( 'DOKSL_ND001_1_6_REQUEST_2_TXT' ) class = 'font1 weight400 color-gray7 sapUiSmallMarginTop' ).
    DATA(line1) = results_box->hbox( class = 'sapUiTinyMarginTop' ).
    DATA(icon_1) = line1->icon( src = 'sap-icon://icomoon/fi_check' class = 'color-green RAKEGA-v-icon-dir sapUiSmallMarginEnd' ).
    DATA(request_id_txt) = line1->label( text = get_text_by_id( 'REQUEST_ID_TEXT' ) class = 'font1 weight400 color-gray6 sapUiSmallMarginEnd' ).
    DATA(request_id) = line1->label( text = gs_data-caseid class = 'font1 weight500 color-gray7' ).
    " VISIBLE is NOT 'X' for LINE2 (its siblings LINE1/LINE3 both have VISIBLE=X) - this whole row
    " (application type icon+labels) is presumably conditional on something not captured elsewhere
    " in the export. Placeholder binding below - please confirm the real field.
    DATA(line2) = results_box->hbox( class = 'sapUiTinyMarginTop' visible = '{TODO_LINE2_VISIBLE}' ).
    DATA(icon_2) = line2->icon( src = 'sap-icon://icomoon/fi_check' class = 'color-green RAKEGA-v-icon-dir sapUiSmallMarginEnd' ).
    DATA(application_type_txt) = line2->label( text = get_text_by_id( 'E003_APPLICATION_TYPE' ) class = 'font1 weight400 color-gray6 sapUiSmallMarginEnd' ).
    DATA(application_type) = line2->label( text = gs_data-case_stat class = 'font1 weight500 color-gray7' ).
    DATA(line3) = results_box->hbox( class = 'sapUiTinyMarginTop' ).
    DATA(icon_3) = line3->icon( src = 'sap-icon://icomoon/fi_check' class = 'color-green RAKEGA-v-icon-dir sapUiSmallMarginEnd' ).
    DATA(application_number_txt) = line3->label( text = get_text_by_id( 'PPD_NP001_1_5_APPLICATION_NUMBER_TXT' ) class = 'font1 weight400 color-gray6 sapUiSmallMarginEnd' ).
    DATA(application_number) = line3->label( text = gs_data-appl_no class = 'font1 weight500 color-gray7' ).
    DATA(notification_txt) = results_box->label( text = get_text_by_id( 'FINAL_1_NOTIFICATION_SENT_MESSAGE' ) class = 'font1 weight400 color-gray7 sapUiMediumMarginTop' ).
    DATA(print) = results_box->button( id = 'PRINT' text = get_text_by_id( 'PRINT' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-final-footer-btn' icon = 'sap-icon://icomoon/print' press = client->_event( 'PRINT' ) ).
    DATA(buttonback) = results_box->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_TO_HOME_BUTTON' ) class = 'regularBTN RAKEGA-final-footer-btn sapUiMediumMarginTop' icon = 'sap-icon://icomoon/Left' press = client->_event( 'HOME' ) ).
    DATA(flamingo_box) = general->vbox( class = 'sapUiLargeMarginTop' ).
    DATA(flamingo_img) = flamingo_box->image( src = '/css/css/RAKEGA_extentions/Images/ShapeIT-Final.png' height = '10rem' ).
*    DATA(flamingo_img) = flamingo_box->image( src = flamingo ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD VIEW_DISPLAY.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->page( id = `page_main`
            title               = `CJS - List Report Features`
            navbuttonpress      = client->_event_nav_app_leave( )
            shownavbutton       = client->check_app_prev_stack( ) ).

    page = page->dynamic_page( headerexpanded = abap_true
                               headerpinned   = abap_true ).

    DATA(cont) = page->content( `f` ).
    DATA(tab) = cont->table( id    = `tab`
                             items = client->_bind_edit( val = mt_table ) ).

    DATA(lo_columns) = tab->columns( ).
    lo_columns->column( )->text( `Product` ).
    lo_columns->column( )->text( `Date` ).
    lo_columns->column( )->text( `Name` ).
    lo_columns->column( )->text( `Location` ).
    lo_columns->column( )->text( `Quantity` ).

    DATA(lo_cells) = tab->items( )->column_list_item( ).
    lo_cells->link( id    = `link`
                    text  = `{PRODUCT}`
                    press = client->_event( val = `POPOVER_DETAIL` t_arg = VALUE #( ( `${$source>/id}` ) ( `${PRODUCT}` ) ) ) ).
    lo_cells->text( `{CREATE_DATE}` ).
    lo_cells->text( `{CREATE_BY}` ).
    lo_cells->text( `{STORAGE_LOCATION}` ).
    lo_cells->text( `{QUANTITY}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_init( ).

*      me->functions = 'sap.ui.define([], function () {' && |\n| &&
*'        return {' && |\n| &&
**'           afterOpen: function (oEvent) {' && |\n| &&
**'             var url = oEvent.getSource().getCustomData().find(item => item.getKey() === "URL");' && |\n| &&
**'             if (url && url.getValue()){' && |\n| &&
**'               window.open(url.getValue(), "_blank");' && |\n| &&
**'               setTimeout(function () {' && |\n| &&
**'             that._checkIfPaymentCompleted(that, oModel.getProperty("/XX/GS_DATA/CASEID"), that._z2ui5Popup);' && |\n| &&
**'           }, 5000);' && |\n| &&
**'         }' && |\n| &&
**'       }' && |\n| &&
*'     };' && |\n| &&
*'   });'.


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
          WHEN 'SCREEN_NP001_1_1'.
            DATA: lt_public_court TYPE ztt_case_head_details.
            CALL FUNCTION 'ZWDA_CASE_HEAD_DEATLS'
              EXPORTING
                case_number            = gs_data-case-case_number
                case_year              = gs_data-case-year
                case_type              = gs_data-case-case_type
                langu                  = sy-langu
              IMPORTING
                et_case_header_details = lt_public_court.

            READ TABLE lt_public_court INTO gs_data-public_court INDEX 1.
            IF sy-subrc EQ 0.
              SELECT SINGLE scmgcasetypet~description
                FROM scmgcasetypet
                INTO gs_data-case-description
                WHERE langu     EQ sy-langu
                AND   case_type EQ gs_data-case-case_type.
              gs_data-ref_caseid = gs_data-public_court-ext_key.
            ELSE.
              MESSAGE e000(zmsg_ega_court_wda) INTO DATA(message).
              client->message_box_display(
                          text = message
                          type = 'Error' ).
              RETURN.
            ENDIF.
          WHEN 'SCREEN_NP001_1_2'.
            SELECT noattachment, descrption
              FROM zcourt_att_desc INTO TABLE @DATA(lt_att)
              WHERE product_id EQ @gs_data-case-product_id
              AND   category   EQ @gs_data-category
              AND   spras      EQ @sy-langu
              ORDER BY noattachment.
            CLEAR: mt_attach[].
            LOOP AT lt_att INTO DATA(ls_att).
              APPEND INITIAL LINE TO mt_attach ASSIGNING FIELD-SYMBOL(<attach>).
              <attach>-label     = ls_att-descrption.
              <attach>-file_type = ls_att-noattachment.
              <attach>-required  = 'X'.
            ENDLOOP.
            APPEND INITIAL LINE TO mt_attach ASSIGNING <attach>.
            <attach>-label     = 'Others or Supporting'.
            <attach>-file_type = 'P6'.
          WHEN 'SCREEN_NP001_1_3'.
            DATA(lt_messages) = create_case( iv_case_type = 'ZK02' is_submit = abap_true iv_appln_type = '4' iv_amendment = ' ' ).
            LOOP AT lt_messages INTO DATA(ls_message) WHERE type EQ 'E'.
              MESSAGE ID ls_message-id TYPE ls_message-type NUMBER ls_message-number
              WITH ls_message-message_v1 ls_message-message_v2 ls_message-message_v3 ls_message-message_v4
              INTO message.

              client->message_box_display(
                          text = message
                          type = 'Error' ).
            ENDLOOP.
        ENDCASE.
        me->step_forward( control = me direction = '+' ).
      WHEN 'BACK'.
        me->step_forward( control = me direction =  '-' ).
      WHEN 'PAY'.
        me->rakpay_popup( me->get_cpg_details( ) ).
      WHEN 'PAYCHECK'.
        me->rakpay_result( gs_data-caseid ).
        me->rakpay_popup( '' ).
      WHEN 'RAKHAPPY'.
        rakhappy_save( iv_case_type = gs_data-journeytype iv_caseid = gs_data-caseid ).

        me->step_forward( control = me direction =  '=' ).
      WHEN `BUTTON_DETAILS`.
        client->popover_destroy( ).

      WHEN `POPOVER_DETAIL`.
        mv_check_popover = abap_true.
        mv_product = client->get_event_arg( 2 ).
        popover_display( client->get_event_arg( 1 ) ).
    ENDCASE.
    client->view_model_update( ).

  ENDMETHOD.


  METHOD case_mapping.
    ls_request-case_number = gs_data-case-case_number.
    ls_request-case_type   = gs_data-case-case_type.
    ls_request-case_year   = gs_data-case-year.
    ls_request-org_unit    = '1007105010'.

    ls_request-header-process_type = 'YVA2'.
    ls_request-header-zzafld0000bo = gs_data-category.
    ls_request-header-description  = gs_data-description.
    ls_request-header-zzafld0000ef = ''."ls_gn_header_view-description_other.
    ls_request-header-zzafld0000h5 = gs_data-delivery. "Delivery Mode
    ls_request-header-zzafld0000ay = gs_data-partner.
    ls_request-header-zzafld0000ax = 'X'.
    ls_request-header-status       = 'E0009'.
    ls_request-header-zzafld0000dr = 'S'.
    ls_request-header-text_yese    = gs_data-notes.

    ls_request-header-ordered_prod = gs_data-case-product_id.


    ls_request-no_parties_involved-payer_bp       = gs_data-partner.
    ls_request-no_parties_involved-payer_ft       = '00000001'.
    ls_request-no_parties_involved-attester_name  = sy-uname.
    ls_request-no_parties_involved-attester_ft    = '00000014'.

    APPEND INITIAL LINE TO ls_request-items ASSIGNING FIELD-SYMBOL(<item>).
    <item>-ordered_prod = ls_request-header-ordered_prod.
  ENDMETHOD.


  METHOD create_case.

    CHECK sy-uname eq 'PORTAL1'.
    DATA(ls_req) = case_mapping( gs_data ).


    IF gs_data-caseid IS INITIAL.
      CALL FUNCTION 'ZFM_ECC_WDA_CREATE_REQUEST2'
        EXPORTING
          partners     = ls_req-no_parties_involved
          header       = ls_req-header
          case_type    = ls_req-case_type
          case_year    = ls_req-case_year
          case_num     = ls_req-case_number
          org_unit     = ls_req-org_unit
        TABLES
          t_services   = ls_req-items
          t_bapireturn = et_return.
      READ TABLE et_return INTO DATA(ls_bapireturn)
      WITH KEY type = 'S'.
      IF sy-subrc EQ 0.
        gs_data-object_id = gs_data-caseid = ls_bapireturn-message_v1.
        gs_data-root-root_key = ls_bapireturn-message_v2.

        DATA : lv_noti_partner TYPE bu_partner,
               lv_noti_obj(10) TYPE c,
               lv_noti_pro(4)  TYPE c,
               lv_mail_form    TYPE string,
               lv_sms_type(4)  TYPE c,
               lv_guid         TYPE scmg_case_guid.

        CASE gs_data-case-product_id.
          WHEN 'SC006' OR 'SC092' OR 'SC047' OR 'SC104' .
            lv_mail_form = 'ZCMG_NOTIFICATION_IMG _SERVICE'.
            lv_sms_type = 'ZIMG'.
          WHEN OTHERS.
            lv_mail_form = 'ZCMG_NOTIFICATION_CAS _SERVICE'.
        ENDCASE.

        lv_noti_obj     = gs_data-caseid.
        lv_noti_partner = gs_data-partner.
        lv_noti_pro     = ls_req-header-process_type.
        CALL FUNCTION 'ZFM_ECC_WDA_SEND_NOTIFICATION'
          EXPORTING
            iv_partner      = lv_noti_partner
            iv_object_id    = lv_noti_obj
            iv_process_type = lv_noti_pro
            iv_sms_type     = lv_sms_type
            iv_mail_form    = lv_mail_form.

        CALL FUNCTION 'ZFM_ECC_WDA_RELEASE_BILLING'
          EXPORTING
            iv_object_id   = gs_data-object_id
            iv_bill_type   = lv_noti_pro
          IMPORTING
            ev_billing_doc = gs_data-billing_doc.
        COMMIT WORK AND WAIT.

        gs_data-appl_no = gs_data-billing_doc.

      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD get_cpg_details.

    TYPES:
      BEGIN OF ty_paydtl,
        email            TYPE string,
        userid           TYPE string,
        amount           TYPE string,
        currency         TYPE string,
        serviceid        TYPE string,
        referenceid      TYPE string,
        merchantid       TYPE string,
        lang             TYPE string,
        eservicecode     TYPE string,
        terminalid       TYPE string,
        secretkey        TYPE string,
        redirecturl      TYPE string,
        applicationurl   TYPE string,
        paytype          TYPE string,
        servicesessionid TYPE string,
        paychannel       TYPE string,
        servicelist      TYPE string,
      END OF ty_paydtl .

    DATA mun          TYPE xfeld.
    DATA lv_language  TYPE sy-langu.
    DATA lt_cases     TYPE ztt_cases_qp.
    DATA:ls_transaction_data TYPE zetislat_transac,
         ext_key             TYPE scmg_ext_key,
         details             TYPE ty_paydtl,
         bp_partner          TYPE bu_partner.

    IF sy-uname NE 'PORTAL1'.
      ev_url = 'https://www.google.com'.
      RETURN.
    ENDIF.

    DATA: sessionid TYPE thfb_session_id.

    DATA(caseid) = gs_data-caseid.
    bp_partner = gs_data-partner.

    CHECK gs_data-billing_doc IS NOT INITIAL OR gs_data-billing_docs[] IS NOT INITIAL.
    IF gs_data-billing_docs[] IS INITIAL.
      APPEND INITIAL LINE TO gs_data-billing_docs ASSIGNING FIELD-SYMBOL(<doc>).
      <doc>-billing_doc = gs_data-billing_doc.
      <doc>-product_id  = gs_data-case-product_id.
      <doc>-case_type   = gs_data-case-case_type.
    ENDIF.


    IF sy-sysid = 'E30'.
      DATA: partner     TYPE char10,
            portal_user TYPE char50,
            username    TYPE string,
            user_email  TYPE string.

      partner = bp_partner.

      CALL FUNCTION 'ZGET_INT_USER_FROM_BP'
        EXPORTING
          iv_partner = partner
        IMPORTING
          ev_user    = portal_user.

      username = portal_user.

      portal_user = 'sap_prod'.

      CALL FUNCTION 'ZFM_WS_PORTAL_USER_FIND_UNAME'
        EXPORTING
          iv_username   = username
        IMPORTING
          ev_user_email = user_email.

    ENDIF.

    DATA(lv_gateway) = COND #( WHEN ms_payment-creditcard EQ abap_true THEN 'ETISALAT' ELSE 'EDIRHAM' ).
    IF caseid IS INITIAL.
      RETURN.
    ENDIF.
    lt_cases = VALUE #( ( case_id = caseid  ) ).

    SELECT SINGLE * FROM zdt_merch_rakpay INTO @DATA(ls_merchant) WHERE bukrs EQ 'RPPD' AND gateway = @lv_gateway.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA :lv_object   TYPE nrobj,
          lv_nr_range TYPE nrnr.

    CLEAR :lv_object,lv_nr_range.

    CALL METHOD zcl_ega_payment_utility=>get_nr_object_init_payment
      IMPORTING
        ev_object   = lv_object     " Name of number range object
        ev_nr_range = lv_nr_range.    " Number range number


    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = lv_nr_range "'01'
        object                  = lv_object "  'ZEGA_PAY_T'
      IMPORTING
        number                  = details-referenceid
      EXCEPTIONS
        interval_not_found      = 1
        number_range_not_intern = 2
        object_not_found        = 3
        quantity_is_0           = 4
        quantity_is_not_1       = 5
        interval_overflow       = 6
        buffer_overflow         = 7
        OTHERS                  = 8.

    LOOP AT gs_data-billing_docs ASSIGNING <doc>.

      DO 300 TIMES.
        SELECT SINGLE dfkkop~opbel AS invoice_number, dfkkop~xblnr,
          dfkkop~betrh AS due_amount, dfkkop~waers
          FROM dfkkop
          INTO @DATA(ls_open)
          WHERE zzcrmbill_doc EQ @<doc>-billing_doc
          AND   dfkkop~augst EQ @space
          AND   dfkkop~betrh GT 0
          AND   dfkkop~bukrs EQ 'RPPD'.

        IF sy-subrc EQ 0.
          EXIT.
        ELSE.
          WAIT UP TO '0.2' SECONDS.
        ENDIF.
      ENDDO.
      CHECK ls_open IS NOT INITIAL.
*    SELECT SINGLE vbeln INTO @DATA(invoice) FROM vbrp WHERE aubel EQ @vbeln_va.

      DATA(invoice) = <doc>-billing_doc.
*start


      SELECT SINGLE * FROM zdt_edirham_serv INTO @DATA(ls_pay_serv) WHERE bukrs EQ 'RPPD' AND material EQ @<doc>-product_id.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.



      details-userid       = COND #( WHEN sy-sysid = 'E30' THEN portal_user ELSE '1376184' ).
      details-amount       = ls_open-due_amount.
      details-currency     = ls_open-waers.
      details-serviceid    = ls_pay_serv-service_id.
      details-merchantid   = ls_merchant-merchant_id.
      details-lang         = sy-langu.
      details-eservicecode = ls_pay_serv-serv_code_main && '-' && ls_pay_serv-serv_code_sub.
      details-terminalid   = ls_merchant-terminal_id.
      details-secretkey    = ls_merchant-secret_key.
      details-paytype      = '2'.

      CALL FUNCTION 'TH_GET_SESSION_ID'
        IMPORTING
          session_id = sessionid.

      details-servicesessionid = sessionid.



      IF sy-sysid = 'E30'.
        details-paychannel = COND #( WHEN ms_payment-creditcard EQ abap_true THEN 'https://www.rak.ae/etcpg/cpg/reg/' ELSE 'https://www.rak.ae/cpgconnector/cpg/1' ).
      ELSE.
        details-paychannel = COND #( WHEN ms_payment-creditcard EQ abap_true THEN 'https://stg.rak.ae/etcpg/cpg/reg/' ELSE 'https://stg.rak.ae/cpgconnector/cpg/1' ).
      ENDIF.
      CONCATENATE 'eserviceid=' ls_pay_serv-serv_code_main '-' ls_pay_serv-serv_code_sub ',quantity=1,price=' details-amount ';' INTO details-servicelist.
      CONDENSE details-servicelist NO-GAPS.

      CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
        EXPORTING
          i_datlo     = sy-datum
          i_timlo     = sy-uzeit
          i_tzone     = 'UTC'
        IMPORTING
          e_timestamp = ls_transaction_data-date_initialized.

      ls_transaction_data-transaction_id = details-referenceid.
      ls_transaction_data-amount         = details-amount.
      ls_transaction_data-currency       = details-currency.
      ls_transaction_data-payment_id     = invoice.
      ls_transaction_data-opbel          = ls_open-invoice_number.

      DATA: vbelv TYPE vbeln_von, xblnr TYPE xblnr.
      SELECT SINGLE xblnr FROM dfkkop INTO xblnr WHERE opbel EQ ls_transaction_data-opbel.
      IF sy-subrc EQ 0.
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
          EXPORTING
            input  = xblnr
          IMPORTING
            output = vbelv.

        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input  = vbelv
          IMPORTING
            output = vbelv.
      ENDIF.
      ls_transaction_data-transaction_desc_short = vbelv.
      ls_transaction_data-status                 = 'I'.
      ls_transaction_data-user_erp               = 'PORTAL1'.
      ls_transaction_data-user_portal            = COND #( WHEN sy-sysid = 'E30' THEN portal_user ELSE 'ARJUN.C' ).
      ls_transaction_data-ext_key                = caseid.
      ls_transaction_data-case_type              = <doc>-case_type.
      ls_transaction_data-gateway                = lv_gateway.
      ls_transaction_data-date_init              = sy-datum.
      ls_transaction_data-time_init              = sy-uzeit.
      ls_transaction_data-service_id             = details-serviceid.
      ls_transaction_data-transaction_desc_long  = ls_open-invoice_number.
      ls_transaction_data-source_system          = '02'.
      ls_transaction_data-cases_for              = 'QP'.
      INSERT INTO zetislat_transac VALUES ls_transaction_data.

      ev_url = COND #(
        WHEN sy-sysid = 'E30' THEN 'https://grpportal.rak.ae/sap/bc/webdynpro/sap/zwda_ega_euser_payments?sap-language=EN?referenceId=' && details-referenceid
        WHEN sy-sysid EQ 'E10' THEN 'https://devgrpportal.rak.ae/sap/bc/webdynpro/sap/ZWDA_EGA_EUSER_PAYMENTS?sap-language=EN?referenceId=' && details-referenceid
        ELSE 'https://devgrpportal.rak.ae:444/sap/bc/webdynpro/sap/ZWDA_EGA_EUSER_PAYMENTS?sap-language=EN?referenceId=' && details-referenceid ).

    ENDLOOP.


  ENDMETHOD.
ENDCLASS.
