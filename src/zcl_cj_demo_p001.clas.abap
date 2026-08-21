class ZCL_CJ_DEMO_P001 definition
  public
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
  types:
    BEGIN OF ty_attach,
        file_name     TYPE string,
        file_data     TYPE string,
        file_type     TYPE string,
        allowed_types TYPE string,
        label         TYPE string,
        icon          TYPE string,
        required      TYPE flag,
        read_mode     TYPE flag,
      END OF ty_attach .
  types:
    tt_attach TYPE STANDARD TABLE OF ty_attach WITH DEFAULT KEY .
  types:
    BEGIN OF ty_payment,
        quick                TYPE flag,
        mrak                 TYPE flag,
        kiosk                TYPE flag,
        walkin               TYPE flag,
        edirham              TYPE flag,
        creditcard           TYPE flag,
        nextvisible          TYPE flag,
        donate               TYPE flag,
        busyindicatorvisible TYPE flag,
        title                TYPE string,
        text                 TYPE string,
      END OF ty_payment .
  types:
    BEGIN OF ty_happy,
        initilized   TYPE flag,
        rate         TYPE string,
        excellent    TYPE flag,
        good         TYPE flag,
        average      TYPE flag,
        poor         TYPE flag,
        verypoor     TYPE flag,
        textareatext TYPE string,
      END OF ty_happy .

  data:
    mt_table TYPE STANDARD TABLE OF ty_s_tab WITH EMPTY KEY .
  data MV_CHECK_POPOVER type ABAP_BOOL .
  data MV_PRODUCT type STRING .
  data GS_DATA type ZCL_EGA_CJ_PPD_ABS=>TY_DATA .
  data MT_STAGES type Z2UI5_CL_EXT_RAKSTAGEBAR=>TT_STAGES .
  data MT_RESULTS type WDY_KEY_VALUE_LIST .
  data MT_ATTACH type TT_ATTACH .
  data MS_PAYMENT type TY_PAYMENT .
  data MS_HAPPY type TY_HAPPY .

  methods VIEW_DISPLAY .
  methods POPOVER_DISPLAY
    importing
      !ID type STRING .
  methods SCREEN_NP001_1_1 .
  methods SCREEN_NP001_1_2 .
  methods SCREEN_NP001_1_3 .
  methods SCREEN_NP001_1_4 .
  methods SCREEN_NP001_1_5 .
  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

private section.

  methods RAKHAPPY_SAVE .
  methods GET_VALUE_LIST
    importing
      !PARENT type ref to Z2UI5_CL_XML_FRAGMENT
      !SHLPNAME type SHLPNAME optional
      !KEYFIELD type FIELDNAME optional
      !VALUEFIELD type FIELDNAME optional
      !IT_SELOPT type DDSHSELOPS optional .
  methods INIT_JOURNEY .
  methods CSS
    returning
      value(CSS) type STRING .
  methods GET_TEXT_BY_ID
    importing
      !ID type ANY
    returning
      value(TEXT) type STRING .
  methods READ_CASE_DATA .
  methods RAKUPLOADER
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT
      value(FILTER_BY) type STRING optional .
  methods RAKPAY
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT .
  methods RAKPAY_POPUP
    importing
      !IV_URL type STRING optional .
  methods RAKPAY_URL
    returning
      value(EV_URL) type STRING .
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
  methods RAKHAPPY .
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


  METHOD GET_TEXT_BY_ID.
    SELECT SINGLE value_desc FROM /qnv/sb_valuet
      INTO @DATA(lv_value)
      WHERE spras EQ @sy-langu
      AND   value_code EQ @id.
    IF sy-subrc NE 0.
      SELECT SINGLE labeltext FROM /qnv/sb_labelt
        INTO @lv_value
        WHERE spras EQ @sy-langu
        AND   label_code EQ @id.
    ENDIF.
    IF sy-subrc EQ 0.
      text = lv_value.
    ENDIF.
  ENDMETHOD.


  METHOD get_value_list.

    DATA: ls_shlp   TYPE shlp_descr,
          lt_return TYPE STANDARD TABLE OF ddshretval.
    CALL FUNCTION 'F4IF_GET_SHLP_DESCR'
      EXPORTING
        shlpname = shlpname
      IMPORTING
        shlp     = ls_shlp.
    ls_shlp-selopt = it_selopt.
    CALL FUNCTION 'F4IF_SELECT_VALUES'
      EXPORTING
        shlp           = ls_shlp
        call_shlp_exit = 'X'
      TABLES
        return_tab     = lt_return.
    DATA(lv_key_found) = abap_false.
    DATA(lv_value_found) = abap_false.
    LOOP AT lt_return INTO DATA(ls_return).
      CASE ls_return-fieldname.
        WHEN keyfield.
          DATA(lv_key) = ls_return-fieldval.
          lv_key_found = abap_true.
        WHEN valuefield.
          DATA(lv_value) = ls_return-fieldval.
          lv_value_found = abap_true.

      ENDCASE.
      IF lv_key_found EQ abap_true AND lv_value_found EQ abap_true.
        parent->item( key = lv_key text = lv_value ).
        CLEAR: lv_key_found, lv_value_found, lv_key, lv_value.
      ENDIF.
    ENDLOOP.
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

    client->_bind_edit( mt_stages ).
*    DATA(rakstagebar) = NEW z2ui5_cl_ext_rakstagebar( me->client ).
  ENDMETHOD.


  METHOD POPOVER_DISPLAY.

    DATA(lo_popover) = z2ui5_cl_xml_view=>factory_popup( ).

    lo_popover->popover( placement    = `Right`
                         title        = |abap2UI5 - Popover - { mv_product }|
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
    DATA(fisrt) = view->vbox( class = 'shapeIT-firstContainer' ).
    DATA(card) = fisrt->vbox( class = 'shapeIT-card' ).
    DATA(card_top) = card->vbox( class = 'shapeIT-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title) = card_header->hbox( alignitems = 'Center' ).
    DATA(ppd_logo) = title->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    " AMBIGUOUS(TITLE_TEXT): VALUE='DOKSL_ND016_1_1_TITLE_TEXT' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(title_text) = title->label(
    text = '{/XX/GS_DATA/DESCRIPTION}'
    class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    " TODO(STAGES): RAKSTAGEBAR is a custom extension control (EXTENDED=X) - exact z2ui5 API not yet confirmed.
    "   source data: steps=4 current=1
    DATA(stages) = card->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder - see TODO above
    NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->rakstagebar( stages ).

    DATA(body) = card->vbox( class = 'shapeIT-part2' ).
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
    DATA(footer) = fisrt->hbox( class = 'shapeIT-footer shapeIT-next-btn-end' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' visible = 'false' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(next) = footer->button( iconfirst = 'false' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).

    client->view_display( view->stringify( ) ).


  ENDMETHOD.


  METHOD screen_np001_1_2.

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(fisrt) = view->vbox( class = 'shapeIT-firstContainer' ).
    DATA(card) = fisrt->vbox( class = 'shapeIT-card' ).
    DATA(card_top) = card->vbox( class = 'shapeIT-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title) = card_header->hbox( alignitems = 'Center' ).
    DATA(ppd_logo) = title->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    " AMBIGUOUS(TITLE_TEXT): VALUE='DOKSL_ND016_1_1_TITLE_TEXT' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(title_text) = title->label( text = '{/XX/GS_DATA/DESCRIPTION}' class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).

    DATA(context_hbox_desktop) = card_header->hbox( class = 'shapeIT-context-hbox-desktop' ).
    DATA(context1_d_cont) = context_hbox_desktop->hbox( class = 'shapeIT-context-cont' ).
    " AMBIGUOUS(CTX1_D_LABEL): literal text 'CNTITLE', not an i18n key pattern - confirm
    DATA(ctx1_d_label) = context1_d_cont->label( text = get_text_by_id( 'CNTITLE' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX1_D_VALUE): VALUE='F9' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx1_d_value) = context1_d_cont->label( text = '{/XX/GS_DATA/CASE/CASE_NUMBER}' class = 'Body_1_3 color-gray7' ).
    DATA(context1_d_separator) = context_hbox_desktop->vbox( class = 'shapeIT-context-separator' ).
    DATA(context3_d_cont) = context_hbox_desktop->hbox( class = 'shapeIT-context-cont' ).
    DATA(ctx3_d_label) = context3_d_cont->label( text = get_text_by_id( 'PPD_NP001_1_1_LABEL_8' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX3_D_VALUE): VALUE='Aug 23, 2023' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx3_d_value) = context3_d_cont->label( text = '{/XX/GS_DATA/CASE/YEAR}' class = 'Body_1_3 color-gray7' ).
    DATA(context3_d_separator) = context_hbox_desktop->vbox( class = 'shapeIT-context-separator' ).
    DATA(context4_d_cont) = context_hbox_desktop->hbox( class = 'shapeIT-context-cont' ).
    " AMBIGUOUS(CTX4_D_LABEL): VALUE='Case Description' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx4_d_label) = context4_d_cont->label( text = '{/XX/GS_DATA/CASE/DESCRIPTION}' class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX4_D_VALUE): VALUE='Aug 23, 2023' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx4_d_value) = context4_d_cont->label( text = '{/XX/GS_DATA/PUBLIC_COURT/ORDER_DESCR}' class = 'Body_1_3 color-gray7' ).

    DATA(buttons) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = buttons->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = buttons->button( id = 'SAVEDRAFT_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = buttons->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = buttons->button( id = 'DELETE_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(error_1) = card_top->message_strip( text = '{/XX/GS_DATA/ERROR}' visible = '{= ${/XX/GS_DATA/ERROR} !== '''' }'
    type = 'Error' showicon = 'true' showclosebutton = 'true' ).  " TODO(ERROR_1): EXTENDED=X, param names assumed - confirm
    " TODO(STAGES): RAKSTAGEBAR - source data: steps=4 current=1 texts=First,Second,Third,Fourth
    DATA(stages) = card->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder
    NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->rakstagebar( stages ).

    DATA(body) = card->vbox( class = 'shapeIT-part2' ).
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
    DATA(hseparator_1) = body->hbox( class = 'sapUiMediumMarginTop shapeIT-hr' ).  " horizontal rule
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
    DATA(footer) = fisrt->hbox( class = 'shapeIT-footer' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(next) = footer->button( iconfirst = 'false' id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD screen_np001_1_3.

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(firstcontainer) = view->vbox( class = 'shapeIT-firstContainer' ).
    DATA(card) = firstcontainer->vbox( class = 'shapeIT-card' ).
    DATA(card_top) = card->vbox( class = 'shapeIT-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(card_header_title) = card_header->hbox( alignitems = 'Center' ).
    DATA(ppd_logo) = card_header_title->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    " AMBIGUOUS(TITLE_TEXT): VALUE='DOKSL_ND016_1_1_TITLE_TEXT' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(title_text) = card_header_title->label( text = '{/XX/GS_DATA/DESCRIPTION}' class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(card_header_end) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = card_header_end->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event(
  'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = card_header_end->button( id = 'SAVEDRAFT_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = card_header_end->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = card_header_end->button( id = 'DELETE_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    " TODO(STAGES): RAKSTAGEBAR - source data: steps=4 current=2 texts=First,Second,Third,Fourth
    DATA(stages) = card_top->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder
    NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->rakstagebar( stages ).

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
    DATA(footer) = firstcontainer->hbox( class = 'shapeIT-footer' ).
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

    ms_payment-quick = abap_true.
    ms_payment-edirham = abap_true.

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(firstcontainer) = view->vbox( class = 'shapeIT-firstContainer shapeIT-pay-initial' ).
    DATA(card) = firstcontainer->vbox( class = 'shapeIT-card' ).
    DATA(card_top) = card->vbox( class = 'shapeIT-card-top' ).
    DATA(back_hbox) = card_top->hbox( class = 'shapeIT-pay-hide-in-initial shapeIT-pay-hide-in-final' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(paybuttonback) = back_hbox->button( id = 'PAYBUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'shapeIT-lobby-button-back' icon = 'sap-icon://icomoon/left-arrow' press = client->_event( 'BACK' ) ).
    DATA(card_header_pay) = card_top->hbox( class = 'shapeIT-pay-hide-in-initial shapeIT-pay-hide-in-final' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(payment_screen_name) = card_header_pay->label( text = get_text_by_id( 'TITLEPM' ) class = 'font1375 weight600 color-dark-blue' ).
    DATA(card_header) = card_top->hbox( class = 'shapeIT-pay-hide-in-pay' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(card_header_begin) = card_header->hbox( alignitems = 'Center' ).
    DATA(journeyname_image) = card_header_begin->hbox( class = 'sapUiTinyMarginEnd shapeIT-hide-in-mobile' alignitems = 'Center' ).
    DATA(title) = card_header_begin->label( text = '{/XX/GS_DATA/DESCRIPTION}' class = 'font1375 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(card_header_vseparator) = card_header_begin->vbox( class = 'shapeIT-cardheader-vseparator shapeIT-hide-in-mobile sapUiSmallMarginEnd shapeIT-pay-hide-in-pay' ).
    DATA(description_title) = card_header_begin->label( text = get_text_by_id( 'TITLEPART_PAYINITIAL_FEE' ) class = 'font1 weight400 color-gray5 shapeIT-hide-in-mobile shapeIT-pay-hide-in-pay' ).
    DATA(card_header_end) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = card_header_end->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event(
  'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = card_header_end->button( id = 'SAVEDRAFT_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = card_header_end->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = card_header_end->button( id = 'DELETE_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(description_panel) = card_top->vbox( class = 'shapeIT-hide-in-desktop  shapeIT-pay-hide-in-pay' alignitems = 'Start' ).
    DATA(description_title_in_panel) = description_panel->label( text = get_text_by_id( 'TITLEPART_PAYINITIAL_FEE' ) class = 'font1 weight400 color-gray5' ).

    DATA(stages) = card_top->hbox( class = 'shapeIT-pay-hide-in-pay' ).  " placeholder - see TODO above
    NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->rakstagebar( stages ).

    DATA(description_details_cont) = card_top->vbox( class = 'shapeIT-card-descriptioncont shapeIT-hide-in-mobile sapUiSmallMarginTop shapeIT-pay-hide-in-pay' alignitems = 'Center' ).
    DATA(description) = description_details_cont->label( text = get_text_by_id( 'DESCRIPTION_RA_SELECTPARCELORGRANTED_1_1' ) class = 'font1 weight400 color-gray6' ).
    DATA(description_details_panel) = card_top->vbox( class = 'shapeIT-hide-in-desktop sapUiTinyMarginTop shapeIT-pay-hide-in-pay' alignitems = 'Start' ).
    DATA(journey_description_mobile) = description_details_panel->text_area( value = get_text_by_id( 'DESCRIPTION_RA_SELECTPARCELORGRANTED_1_1' ) maxlength = '65' class = 'Body_1_3 color-gray7 shapeIT-lobby-ex-text' ).
    DATA(part2) = card->vbox( class = 'shapeIT-part2' ).
    DATA(payment_container) = part2->vbox( class = 'shapeIT-pay-payment-container' ).
    DATA(fees_vbox) = payment_container->vbox( class = 'shapeIT-pay-fees-vbox' ).
    DATA(initialfeelabel) = fees_vbox->label( text = get_text_by_id( 'INITIALFEELABEL' ) class = 'H3_1 color-gray7 shapeIT-pay-hide-in-pay shapeIT-pay-hide-in-final' ).
    DATA(finalfeelabel) = fees_vbox->label( text = get_text_by_id( 'FINAL_FEE' ) class = 'H3_1 color-gray7 shapeIT-pay-hide-in-pay shapeIT-pay-hide-in-initial' ).
    DATA(feelabel) = fees_vbox->label( text = get_text_by_id( 'FEE' ) class = 'H3_1 color-gray7 shapeIT-pay-hide-in-initial shapeIT-pay-hide-in-final' ).
    DATA(fees_inner_vbox) = fees_vbox->vbox( class = 'shapeIT-pay-fees-inner-vbox' ).
    DATA(feeslist) = fees_inner_vbox->list( items = '{/XX/GS_DATA/FEES}' ).  " TODO(FEESLIST): assumes a class-level table attribute mt_fees - declare it, populated via DATA1=ZFM_EGA_CJ_FW_READ_TABLE_DATAN/DATA2=FEESLIST
    DATA(feeslistitem) = feeslist->items( )->custom_list_item( ).
    DATA(feeslistitemcontent) = feeslistitem->hbox( class = 'feesDialog-list-item' ).
    DATA(descriptioncontainer) = feeslistitemcontent->hbox( class = 'feesDialog-list-description-container' ).
    DATA(feeslistitemdescription) = descriptioncontainer->label( text = '{DESCRIPTION}' class = 'Body_1_3 color-gray6' ).
    DATA(valuescontainer) = feeslistitemcontent->hbox( class = 'feesDialog-list-amount-container' ).
    DATA(aed) = valuescontainer->label( text = get_text_by_id( 'AED' ) class = 'Body_1_3 color-gray6 sapUiTinyMarginEnd' ).
    DATA(feeslistitemvalue) = valuescontainer->label( text = '{FEE}' class = 'Body_1_3 color-gray6' ).
    DATA(total_hbox) = fees_inner_vbox->hbox( class = 'shapeIT-pay-total-hbox' ).
    DATA(remainingfees_hbox_desktop) = total_hbox->hbox( class = 'shapeIT-hide-in-mobile' ).
    DATA(remainingfeescontainer) = remainingfees_hbox_desktop->hbox( class = 'shapeIT-pay-hide-in-pay shapeIT-pay-hide-in-final' alignitems = 'End' ).
    DATA(remainingfeeslabel) = remainingfeescontainer->label( text = get_text_by_id( 'REMAININGFEESLABEL' ) class = 'Body_2_3 color-gray6 sapUiTinyMarginEnd' ).
    " DEFERRED(REMAININGFEES): RAKREMAININGFEES - link that opens a popup dialog with fee breakdown. Leaving as placeholder for now.
    DATA(remainingfees) = remainingfeescontainer->link( text = '' class = '' ).  " placeholder - see DEFERRED note above
    DATA(cantundocontainer) = remainingfees_hbox_desktop->hbox( class = 'shapeIT-pay-hide-in-pay shapeIT-pay-hide-in-initial' ).
    DATA(cantundoicon) = cantundocontainer->icon( src = 'sap-icon://icomoon/info' class = 'shapeIT-pay-cantdo-icon sapUiTinyMarginEnd' ).
    DATA(cantundolabel) = cantundocontainer->label( text = get_text_by_id( 'CANT_UNDO' ) class = 'Body_1_2 color-red' ).
    DATA(total_inner_hbox) = total_hbox->hbox( ).
    DATA(totallabel) = total_inner_hbox->label( text = get_text_by_id( 'TOTALLABEL' ) class = 'Body_1_1 color-gray6 sapUiTinyMarginEnd' ).
    DATA(aedtoatal) = total_inner_hbox->label( text = get_text_by_id( 'AED' ) class = 'Body_1_1 color-gray6 sapUiTinyMarginEnd' ).
    DATA(totalvalue) = total_inner_hbox->label( text = '{TOTAL_FEE}' class = 'Body_1_1 color-gray6' ).
    DATA(aedtoatal_old) = total_inner_hbox->label( text = get_text_by_id( 'AED' ) class = 'Body_1_1 color-gray6' ).
    DATA(remainingfees_hbox_mobile) = fees_inner_vbox->hbox( class = 'shapeIT-pay-hide-in-pay shapeIT-hide-in-desktop' ).
    DATA(remainingfeescontainerm) = remainingfees_hbox_mobile->hbox( class = 'shapeIT-pay-hide-in-final' ).
    DATA(remainingfeeslabelm) = remainingfeescontainerm->label( text = get_text_by_id( 'REMAININGFEESLABEL' ) class = 'Body_2_3 color-gray6 sapUiTinyMarginEnd' ).
    " DEFERRED(REMAININGFEESM): RAKREMAININGFEES - link that opens a popup dialog with fee breakdown. Leaving as placeholder for now.
    DATA(remainingfeesm) = remainingfeescontainerm->link( text = '' class = '' ).  " placeholder - see DEFERRED note above
    DATA(cantundocontainerm) = remainingfees_hbox_mobile->hbox( class = 'shapeIT-pay-hide-in-initial' ).
    DATA(cantundoiconm) = cantundocontainerm->icon( src = 'sap-icon://icomoon/info' class = 'shapeIT-pay-cantdo-icon sapUiTinyMarginEnd' ).
    DATA(cantundolabelm) = cantundocontainerm->label( text = get_text_by_id( 'CANT_UNDO' ) class = 'Body_1_2 color-red' ).
    DATA(payment_vbox) = payment_container->vbox( class = 'shapeIT-pay-payment-vbox' ).
    DATA(payment_method_cont) = payment_vbox->vbox( class = 'shapeIT-pay-payment-method-cont' ).
    DATA(payment_method_title) = payment_method_cont->label( text = get_text_by_id( 'PAYMENT_METHOD_TITLE' ) class = 'H3_1 color-gray7' ).
    DATA(rbline) = payment_method_cont->hbox( class = 'rbline' ).
    DATA(rb1) = rbline->radio_button( id = 'RB1' text = get_text_by_id( 'MML_SUBDIVISION_RB1' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/QUICK}' class = 'radioButton' ).
    DATA(rb2) = rbline->radio_button( id = 'RB2' text = get_text_by_id( 'MML_SUBDIVISION_RB2' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/MRAK}' class = 'radioButton' ).
    DATA(rb3) = rbline->radio_button( id = 'RB3' text = get_text_by_id( 'MML_SUBDIVISION_RB3' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/KIOSK}' class = 'radioButton' ).
    DATA(rb4) = rbline->radio_button( id = 'RB4' text = get_text_by_id( 'MML_SUBDIVISION_RB4' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/WALKIN}' class = 'radioButton' ).
    DATA(payment_method1_cont) = payment_method_cont->vbox( visible = '{/XX/MS_PAYMENT/QUICK}'  ).
    DATA(please1) = payment_method1_cont->hbox( class = 'shapeIT-pay-please1' ).
    DATA(please_icon1) = please1->icon( src = 'sap-icon://icomoon/info' class = 'shapeIT-pay-cantdo-icon' ).
    DATA(please1_hbox) = please1->hbox( class = 'shapeIT-pay-please-hbox' ).
    DATA(please_label1) = please1_hbox->label( text = get_text_by_id( 'PLEASE_ALLOW_POPUPS' ) class = 'Body_1_2 color-red' ).
    DATA(payment_method2_cont) = payment_method_cont->vbox( class = 'shapeIT-pay-method2-cont' visible = '{= !${/XX/MS_PAYMENT/QUICK}}' ).
    DATA(account_details_cont) = payment_method2_cont->vbox( class = 'shapeIT-pay-account-details-cont' ).
    DATA(account_details) = account_details_cont->label( text = get_text_by_id( 'ACCOUNT_DETAILS' ) class = 'H3_1 color-gra7' ).
    DATA(account_details_hbox) = account_details_cont->hbox( class = 'shapeIT-pay-account-details-hbox' ).
    DATA(acountnumber) = account_details_hbox->vbox( class = 'shapeIT-pay-account-number' ).
    DATA(antitle) = acountnumber->label( text = get_text_by_id( 'NUMBER' ) class = 'Body_1_2 color-gray7' ).
    DATA(ansum) = acountnumber->label( text = '{ACCOUNT}' class = 'Body_1_3 color-gray6' ).
    DATA(casenumber) = account_details_hbox->vbox( class = 'shapeIT-pay-account-number' ).
    DATA(cntitle) = casenumber->label( text = get_text_by_id( 'CNTITLE' ) class = 'Body_1_2 color-gray7' ).
    DATA(cnsum) = casenumber->label( text = '{CASE}' class = 'Body_1_3 color-gray6' ).
    DATA(service_details_cont) = payment_method2_cont->hbox( class = 'shapeIT-pay-service-details-cont' ).
    DATA(please2) = service_details_cont->hbox( class = 'shapeIT-pay-please2' visible = '{/XX/MS_PAYMENT/MRAK}' ).
    DATA(please_image2) = please2->image( src = 'css/css/RAKEGA_extentions/Images/pay-mRak.png' densityaware = 'false' ).
    DATA(please2_hbox) = please2->hbox( class = 'shapeIT-pay-please-hbox' ).
    DATA(please_label2) = please2_hbox->label( text = get_text_by_id( 'PLEASE_PAY_MOBILE' ) class = 'Body_1_2 color-red' wrapping = 'true' ).
    DATA(please3) = service_details_cont->hbox( class = 'shapeIT-pay-please2' visible = '{/XX/MS_PAYMENT/KIOSK}' ).
    DATA(please_image3) = please3->image( src = 'css/css/RAKEGA_extentions/Images/pay-KIOSK.png' ).
    DATA(please3_hbox) = please3->hbox( class = 'shapeIT-pay-please-hbox' ).
    DATA(please_label3) = please3_hbox->label( text = get_text_by_id( 'PLEASE_PAY_KIOSK' ) class = 'Body_1_2 color-red' wrapping = 'true' ).
    DATA(please4) = service_details_cont->hbox( class = 'shapeIT-pay-please2' visible = '{/XX/MS_PAYMENT/WALKIN}' ).
    DATA(please_image4) = please4->image( src = 'css/css/RAKEGA_extentions/Images/pay-Walk-in.png' ).
    DATA(please4_hbox) = please4->hbox( class = 'shapeIT-pay-please-hbox' ).
    DATA(please_label4) = please4_hbox->label( text = get_text_by_id( 'PLEASE_PAY_OFFICE' ) class = 'Body_1_2 color-red' wrapping = 'true' ).
    DATA(sendemail) = service_details_cont->check_box( selected = '{/XX/MS_PAYMENT/DONATE}' text = get_text_by_id( 'SENDEMAIL' ) class = 'checkbox' ).
    DATA(paywith_cont) = payment_vbox->vbox( class = 'shapeIT-pay-paywith-cont' visible = '{/XX/MS_PAYMENT/QUICK}' ).
    DATA(pay_with_title) = paywith_cont->label( text = get_text_by_id( 'PAY_WITH' ) class = 'Body_1_2 color-gray7' ).
    DATA(pw_rbline) = paywith_cont->hbox( class = 'shapeIT-pay-pw-rbline' ).
    DATA(rb_group2) = pw_rbline->radio_button_group( ).
    DATA(pw_hbox2) = pw_rbline->hbox( class = 'shapeIT-pay-pw-hbox' ).
    DATA(pw_rb2) = pw_hbox2->radio_button( id = 'PW_RB2' groupname = 'paymentMethod' selected = '{/XX/MS_PAYMENT/EDIRHAM}' class = 'shapeIT-pay-radio-button' ).
    DATA(pw_img21) = pw_hbox2->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-rak-pay.png' height = '1.75rem' ).
    DATA(pw_hbox1) = pw_rbline->hbox( class = 'shapeIT-pay-pw-hbox' ).
    DATA(pw_rb1) = pw_hbox1->radio_button( id = 'PW_RB1' groupname = 'paymentMethod' selected = '{/XX/MS_PAYMENT/CREDITCARD}' class = 'shapeIT-pay-radio-button' ).
    DATA(pw_images1) = pw_hbox1->hbox( class = 'shapeIT-pay-pw-images1' ).
    DATA(pw_img11) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card1.png' height = '1.613rem' ).
    DATA(pw_img12) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card2.png' height = '1.613rem' ).
    DATA(pw_img13) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card3.png' height = '1.613rem' ).
    DATA(pw_img14) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card4.png' height = '1.613rem' ).
    DATA(footer) = firstcontainer->hbox( class = 'shapeIT-footer' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border shapeIT-pay-hide-in-pay' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
*    DATA(next_method2) = footer->button( id = 'NEXT_METHOD2' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) visible = '{= !${/XX/MS_PAYMENT/QUICK}}' ).
*  DATA(next) = footer->button( id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).
    me->rakpay( footer ).
*  DATA(pay) = footer->button( id = 'PAY' press = client->_event( 'SAVE' ) visible = '{/XX/MS_PAYMENT/QUICK}' ).
    " TODO(PAY): RAKPAY is a custom control (EXTENDED=X) that navigates to an external payment screen - no LABEL_CON/icon in source (the custom control likely supplies its own),
    "rendered as a plain button for now

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD screen_np001_1_5.

    DATA(view)  = z2ui5_cl_xml_fragment=>factory( ).
    DATA(first_container) = view->vbox( class = 'shapeIT-firstContainer' ).
    DATA(card) = first_container->vbox( class = 'shapeIT-card' ).
    DATA(stage_cont) = card->vbox( class = 'shapeIT-card-top' ).
    DATA(header_text_cont) = stage_cont->hbox( justifycontent = 'SpaceBetween' ).
    DATA(label_cont) = header_text_cont->hbox( justifycontent = 'Start' alignitems = 'Center' aligncontent = 'Center' ).
    DATA(ppd_logo) = label_cont->image( src = '../css/img/services/SVG/PP.svg' height = '2rem' ).
    DATA(title_text) = label_cont->label( text = '{/XX/GS_DATA/DESCRIPTION}' class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(stages) = header_text_cont->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder - see TODO above
    NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->rakstagebar( stages ).

    DATA(general) = header_text_cont->hbox( justifycontent = 'SpaceBetween' ).
    DATA(results_box) = general->vbox( ).
    DATA(request_1_txt) = results_box->label( text = get_text_by_id( 'E003_REQUEST_SUBMITTED' ) class = 'font1 weight600 color-dark-blue sapUiMediumMarginTop' ).
    DATA(request_2_txt) = results_box->label( text = get_text_by_id( 'DOKSL_ND001_1_6_REQUEST_2_TXT' ) class = 'font1 weight400 color-gray7 sapUiSmallMarginTop' ).
    DATA(line1) = results_box->hbox( class = 'sapUiTinyMarginTop' ).
    DATA(icon_1) = line1->icon( src = 'sap-icon://icomoon/fi_check' class = 'color-green shapeIT-v-icon-dir sapUiSmallMarginEnd' ).
    DATA(request_id_txt) = line1->label( text = get_text_by_id( 'REQUEST_ID_TEXT' ) class = 'font1 weight400 color-gray6 sapUiSmallMarginEnd' ).
    DATA(request_id) = line1->label( text = '{/XX/GS_DATA/CASEID}' class = 'font1 weight500 color-gray7' ).
    " VISIBLE is NOT 'X' for LINE2 (its siblings LINE1/LINE3 both have VISIBLE=X) - this whole row
    " (application type icon+labels) is presumably conditional on something not captured elsewhere
    " in the export. Placeholder binding below - please confirm the real field.
    DATA(line2) = results_box->hbox( class = 'sapUiTinyMarginTop' visible = '{TODO_LINE2_VISIBLE}' ).
    DATA(icon_2) = line2->icon( src = 'sap-icon://icomoon/fi_check' class = 'color-green shapeIT-v-icon-dir sapUiSmallMarginEnd' ).
    DATA(application_type_txt) = line2->label( text = get_text_by_id( 'E003_APPLICATION_TYPE' ) class = 'font1 weight400 color-gray6 sapUiSmallMarginEnd' ).
    DATA(application_type) = line2->label( text = '{/XX/GS_DATA/CASE_STAT}' class = 'font1 weight500 color-gray7' ).
    DATA(line3) = results_box->hbox( class = 'sapUiTinyMarginTop' ).
    DATA(icon_3) = line3->icon( src = 'sap-icon://icomoon/fi_check' class = 'color-green shapeIT-v-icon-dir sapUiSmallMarginEnd' ).
    DATA(application_number_txt) = line3->label( text = get_text_by_id( 'PPD_NP001_1_5_APPLICATION_NUMBER_TXT' ) class = 'font1 weight400 color-gray6 sapUiSmallMarginEnd' ).
    DATA(application_number) = line3->label( text = '{/XX/GS_DATA/APPL_NO}' class = 'font1 weight500 color-gray7' ).
    DATA(notification_txt) = results_box->label( text = get_text_by_id( 'FINAL_1_NOTIFICATION_SENT_MESSAGE' ) class = 'font1 weight400 color-gray7 sapUiMediumMarginTop' ).
    DATA(print) = results_box->button( id = 'PRINT' text = get_text_by_id( 'PRINT' ) class = 'shapeIT-cardheader-topbtn shapeIT-final-footer-btn' icon = 'sap-icon://icomoon/print' press = client->_event( 'PRINT' ) ).
    DATA(buttonback) = results_box->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_TO_HOME_BUTTON' ) class = 'regularBTN shapeIT-final-footer-btn sapUiMediumMarginTop' icon = 'sap-icon://icomoon/Left' press = client->_event( 'HOME' ) ).
    DATA(flamingo_box) = general->vbox( ).
    DATA(flamingo) = flamingo_box->image( src = '/css/css/RAKEGA_extentions/Images/ShapeIT-Final.png' height = '10rem' ).

    client->view_display( view->stringify( ) ).
    me->rakhappy( ).

  ENDMETHOD.


  METHOD VIEW_DISPLAY.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).

    DATA(page) = view->page( id = `page_main`
            title               = `abap2UI5 - List Report Features`
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

      DATA(lv_params) = client->get( )-s_config-search.
      IF lv_params IS NOT INITIAL.
        SPLIT lv_params AT '?' INTO DATA(dummy) lv_params.
        SPLIT lv_params AT '&' INTO TABLE DATA(lt_params).
        LOOP AT lt_params INTO DATA(lv_param).
          SPLIT lv_param AT '=' INTO DATA(lv_key) DATA(lv_value).
          TRANSLATE lv_key TO UPPER CASE.
          CASE lv_key.
            WHEN 'JOURNEY'.
              gs_data-journeytype = lv_value.
            WHEN 'ROLE'.
              gs_data-role = lv_value.
            WHEN 'PARTNER'.
              gs_data-partner = lv_value.
            WHEN 'COPMPANY'.
              gs_data-company = lv_value.
          ENDCASE.
        ENDLOOP.
      ENDIF.
      client->_bind_edit( gs_data ).
      client->_bind_edit( mt_attach ).
      client->_bind_edit( ms_payment ).
      init_journey( ).
      me->mt_stages = NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->step_forward( control = me ).
      RETURN.
    ENDIF.


    CASE client->get( )-event.
      WHEN 'SAVE'.
        CASE NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->get_current_screen( ).
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
        me->mt_stages = NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->step_forward( control = me direction = '+' ).
      WHEN 'BACK'.
        me->mt_stages = NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->step_forward( control = me direction =  '-' ).
      WHEN 'PAY'.
        me->mt_stages = NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->step_forward( control = me direction =  '=' ).
        me->rakpay_popup( me->get_cpg_details( ) ).

      WHEN 'RAKHAPPY'.
        rakhappy_save( ).
        client->popover_destroy( ).
        me->mt_stages = NEW z2ui5_cl_ext_rakstagebar( me->mt_stages )->step_forward( control = me direction =  '=' ).
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


  METHOD rakpay.

    DATA(root) = io_parent.

    DATA(pay_btn) = root->button(
                       visible   = '{= !${/XX/MS_PAYMENT/NEXTVISIBLE} }'
                       text      = 'Pay'
                       icon      = 'sap-icon://icomoon/Right'
                       press     = client->_event( 'PAY' )
                       class     = 'regularBTN'
                       iconfirst = 'false' ).

    DATA(next_btn) = root->button(
                       visible   = '{= ${/XX/MS_PAYMENT/NEXTVISIBLE} }'
                       text      = 'Next'
                       icon      = 'sap-icon://icomoon/Right'
                       press     = client->_event( 'SAVE' )
                       class     = 'regularBTN'
                       iconfirst = 'false' ).

  ENDMETHOD.


  METHOD rakpay_popup.

*    DATA(lv_url) = me->rakpay_url( ).
**    DATA(lv_url) = 'www.google.com'.

    DATA(popup) = z2ui5_cl_xml_fragment=>factory( ).
    ms_payment-title = 'Payment Processing' .
    ms_payment-text  = 'Please don’t close the window until the processing is done'.
    ms_payment-busyindicatorvisible = abap_true.

    " TODO: ->dialog( ) - not yet confirmed against z2ui5_cl_xml_view's actual API surface,
    " same caveat as file_uploader/progress_indicator/custom_data earlier.
    DATA(pay_dialog) = popup->dialog(
                          id                   = 'payDialog'
                          showheader           = 'false'
                          horizontalscrolling  = 'false'
                          class                = 'confirmDialog payDialogBorderTopGray' ).

    pay_dialog->custom_data( )->core_custom_data( key = 'URL' value = iv_url ).

    DATA(outer_vbox) = pay_dialog->vbox( width = '100%' class = 'confirmDialog-vbox' ).
    DATA(inner_vbox) = outer_vbox->vbox( width = '100%' class = 'confirmDialog-inner-vbox' ).

    DATA(header_row) = inner_vbox->hbox( width = '100%' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title_text) = header_row->text( text = '{/XX/MS_PAYMENT/TITLE}' class = 'color-black font1125 weight500' ).
    DATA(close_icon) = header_row->icon(
                           visible = '{= !${/XX/MS_PAYMENT/BUSYINDICATORVISIBLE} }'
                           src     = 'sap-icon://icomoon/close'
                           color   = '#10233E'
                           size    = '1.5rem'
                           press   = '.destroyPopup' ).

    DATA(body_text) = inner_vbox->text( text = '{/XX/MS_PAYMENT/TEXT}' class = 'color-black font1 weight400' ).

    DATA(busy_row) = inner_vbox->hbox( class = 'payDialog-busy-hbox' width = '100%' justifycontent = 'Center' alignitems = 'Center' ).
    DATA(busy_indicator) = busy_row->busy_indicator( visible = '{/XX/MS_PAYMENT/BUSYINDICATORVISIBLE}' ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.


  METHOD rakpay_url.

    DATA: caseid TYPE scmg_ext_key.

    IF gs_data-caseid IS INITIAL.
      gs_data-caseid = '1955546'.
      gs_data-partner = '3000022038'.
    ENDIF.

    caseid = |{ gs_data-caseid ALPHA = IN }|.
    IF caseid IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zega_t_cj_payupd INTO @DATA(paydtl) WHERE caseid EQ @caseid.
    IF sy-subrc <> 0.
      paydtl-caseid = caseid.
      paydtl-bp     = |{ gs_data-partner ALPHA = IN }|.
    ENDIF.

    paydtl-creditcard = ms_payment-creditcard.
    paydtl-edirham    = ms_payment-edirham.
    paydtl-kiosk      = ms_payment-kiosk.
    paydtl-mrak       = ms_payment-mrak.
    paydtl-quick      = ms_payment-quick.
    paydtl-walkin     = ms_payment-walkin.
    paydtl-donate     = ms_payment-donate.

    MODIFY zega_t_cj_payupd FROM paydtl.

    DATA lt_def TYPE /qnv/sbuild_definition_tt.
    lt_def = VALUE #( ( technicalname = 'REFERENCEID' )
                      ( technicalname = 'APPLICATIONURL' ) ).

    NEW zcl_rak_cpg_adapter( )->fill(
      EXPORTING
        case_key = CONV #( caseid )
        etisalat = abap_true
      CHANGING
        ct_definition = lt_def ).

    ev_url  = lt_def[ technicalname = 'APPLICATIONURL' ]-value.

  ENDMETHOD.


  METHOD rakuploader.

    DATA: lv_binding TYPE string VALUE 'path: ''/XX/MT_ATTACH''',
          lv_filter  TYPE string,
          lv_filters TYPE string.

    IF filter_by IS NOT INITIAL.
      SPLIT filter_by AT ',' INTO TABLE DATA(lt_file_types).
      LOOP AT lt_file_types INTO DATA(lv_file_type).
        CONDENSE lv_file_type NO-GAPS.
        lv_filter = '{ path : ''FILE_TYPE'', operator : ''EQ'', value1 : ''' && lv_file_type && '''}'.
        IF lv_filters IS INITIAL.
          lv_filters = lv_filter.
        ELSE.
          CONCATENATE lv_filters lv_filter INTO lv_filters SEPARATED BY ', '.
        ENDIF.
      ENDLOOP.
      IF lv_filters IS NOT INITIAL.
        lv_filters = 'filters : [' && lv_filters && ']'.
        CONCATENATE lv_binding lv_filters INTO lv_binding SEPARATED BY ', '.
      ENDIF.
    ENDIF.
    lv_binding = '{' && lv_binding && '}'.

    DATA(attachments) = io_parent->list( items = lv_binding class = 'list' ).
    DATA(attachment_item) = attachments->items( )->custom_list_item( ).
    DATA(root) = attachment_item->vbox( ).

    DATA(attach_txt) = root->label( text = '{LABEL}' required = '{REQUIRED}' class = 'font1 weight500 color-gray7 sapUiMediumMarginTop' ).
    " ===================== STATE 1: no file yet, show uploader =====================
    DATA(state_empty) = root->vbox( class = 'sapUiTinyMarginTop' height = '2.6875rem' width = '100%'
                                     visible = '{= ${FILE_NAME} || ${READ_MODE} ? false : true }' ).

    DATA(select_row) = state_empty->hbox( class = 'brdrRed rakuploader-hbox' rendertype = 'Bare' ).
    DATA(select_text) = select_row->text( text = '{i18n>SelectFile}' class = 'color-gray4 font0875 weight400' ).

    DATA(uploader_box) = select_row->hbox( class = 'rakuploader-uploader-hbox' rendertype = 'Bare' ).
    DATA(file_uploader) = uploader_box->icon( src = 'sap-icon://icomoon/Attach' color = '#10233E'
                                              press = '.onUploadStart'
                                              size = '1.25rem'
                                              visible = '{= ${READ_MODE} ? false : true }' ).
*    DATA(file_uploader) = uploader_box->_z2ui5( )->file_uploader(
*                              buttononly           = 'true'
**                              class                 = 'FileUploader'
*                              filetype               = '{FileModel>/allowedFileType}'
*                              icononly               = 'true'
**                              samefilenameallowed    = 'true'
**                              change                 = '.extension.RAKUPLOADER.onChangeUploadedFile'
*                              icon                   = 'sap-icon://icomoon/Attach'
**                              typemissmatch          = '.extension.RAKUPLOADER.typeMissmatch'
**                              valuestate             = 'Error'
*                               ).
    " TODO: data:control="{FileModel>/control}" inline custom-data - exact z2ui5 syntax for
    " CustomData/data: shorthand not yet confirmed. Best guess:
*    file_uploader->custom_data( key = 'control' value = '{FileModel>/control}' ).

    " <customData><core:CustomData key="upload" .../></customData> - explicit aggregation form,
    " same TODO as above re: exact method name/signature.
*    select_row->custom_data( key = 'upload' value = '{FileModel>/upload}' writetodom = 'true' ).

    DATA(mandatory_msg) = state_empty->text( text = '{i18n>MandatoryMessage}' class = 'sapMValueStateMessageError'
                                              visible = '{= ${FileModel>/mandatoryMsg} ? true : false }' ).

    DATA(special_char_row) = state_empty->hbox( visible = '{= ${FileModel>/mandatoryMsg} ? false : true }' ).
    DATA(special_char_text) = special_char_row->text( text = '{i18n>fileSpecialChar}' class = 'sapMValueStateMessageError'
                                                        visible = '{= ${FileModel>/fileSpecialChar} ? true : false }' ).


    " ===================== STATE 2: uploaded (file present, done) =====================
    DATA(state_done) = root->vbox( class = 'sapUiTinyMarginTop' height = '2.6875rem'
                                    visible = '{= ${FILE_NAME} ? true : false }' ).

    DATA(done_row) = state_done->hbox( class = 'rakuploader-hbox' rendertype = 'Bare' ).
    DATA(done_link) = done_row->link( text = '{FILE_NAME}' class = 'rakuploader-previewlink'
                                       press = '.onDisplayUploadedFile' ).
*    done_link->custom_data( key = 'control' value = '{FileModel>/control}' ).

    DATA(done_uploader_box) = done_row->hbox( class = 'rakuploader-uploader-hbox' rendertype = 'Bare' ).
    DATA(delete_icon) = done_uploader_box->icon( src = 'sap-icon://icomoon/Delete' color = '#10233E'
                                                  press = '.onDeleteUploadedFile'
                                                  size = '1.25rem'
                                                  visible = '{= ${FileModel>/readMode} ? false : true }' ).
*    delete_icon->custom_data( key = 'controlObj' value = '{FileModel>/control}' ).

    DATA(done_special_char) = state_done->text( text = '{i18n>fileSpecialChar}' class = 'sapMValueStateMessageError'
                                                 visible = '{= ${FileModel>/fileSpecialChar} ? true : false }' ).

  ENDMETHOD.


  METHOD rakhappy.

    CHECK ms_happy-initilized EQ abap_false.
    ms_happy-initilized = abap_true.
    client->_bind_edit( ms_happy ).

    DATA(popup) = z2ui5_cl_xml_fragment=>factory( ).
    DATA(happy_dialog) = popup->dialog(
                               id                  = 'happyDialog'
                               showheader          = 'false'
                               class               = 'happyDialog'
                               horizontalscrolling = 'false' ).

    DATA(outer_cont) = happy_dialog->vbox( class = 'happyDialog-outer-cont' ).
    DATA(main_cont) = outer_cont->vbox( class = 'happyDialog-main-cont' rendertype = 'Bare' ).

    " ---- header: desktop ----
    DATA(header_desktop) = main_cont->hbox( class = 'happyDialog-header-hbox-desktop' rendertype = 'Bare' ).
    DATA(header_desktop_text) = header_desktop->text( text = 'How was your experience?' class = 'H2_1 color-gray7' ).
    DATA(header_desktop_close) = header_desktop->icon( src = 'sap-icon://icomoon/close' color = '#10233E' size = '1.5rem'
                                                         press = '.destroyPopup' ).

    " ---- header: mobile ----
    DATA(header_mobile) = main_cont->vbox( class = 'happyDialog-header-vbox-mobile' rendertype = 'Bare' ).
    DATA(header_mobile_close) = header_mobile->icon( src = 'sap-icon://icomoon/close' color = '#10233E' size = '1.5rem'
                                                       press = '.extension.RAKHAPPY.closeHappyDialog' ).
    DATA(header_mobile_text_row) = header_mobile->hbox( class = 'happyDialog-header-text-hbox-mobile' rendertype = 'Bare' ).
    DATA(header_mobile_text) = header_mobile_text_row->text( text = 'How was your experience?' class = 'H2_1 color-gray7' ).

    " ---- rating images row (5 static entries: Excellent / Good / Average / Poor / VeryPoor) ----
    DATA(images_row) = main_cont->hbox( class = 'happyDialog-images-hbox' rendertype = 'Bare' ).

    " Excellent
    DATA(rate_excellent_vbox) = images_row->vbox( class = 'happyDialog-image-vbox' rendertype = 'Bare' ).
    DATA(rate_excellent_img_row) = rate_excellent_vbox->hbox( class = 'happyDialog-image-hbox' rendertype = 'Bare' ).
    DATA(radio_btn) = rate_excellent_img_row->radio_button( selected = '{/XX/MS_HAPPY/EXCELLENT}' class = 'happyDialog-radio happyDialog-radio-Excellent' groupname = 'Happy' ).
*    DATA(rate_excellent_img) = rate_excellent_img_row->image(
*                                   src   = '{= ${/XX/MS_HAPPY/RATE} === ''Excellent'' ? ''css/css/RAKEGA_extentions/Images/Excellent-selected.svg'' : ''css/css/RAKEGA_extentions/Images/Excellent.svg''}'
*                                   press = '.extension.RAKHAPPY.onImagePress($event, ''Excellent'')' ).
    DATA(rate_excellent_text) = rate_excellent_vbox->text( text = 'Excellent' class = 'Body_2_3 color-gray7 shapeIT-hide-in-mobile happyDialog-rate-txt' ).
*    rate_excellent_text->custom_data( )->core_custom_data( key = 'text-selected' value = '{= ${happyModel>/Rate} === ''Excellent'' ? ''X'' : ''''}' write_to_dom = 'true' ).

    " Good
    DATA(rate_good_vbox) = images_row->vbox( class = 'happyDialog-image-vbox' rendertype = 'Bare' ).
    DATA(rate_good_img_row) = rate_good_vbox->hbox( class = 'happyDialog-image-hbox' rendertype = 'Bare' ).
    DATA(radio_btn_good) = rate_good_img_row->radio_button( selected = '{/XX/MS_HAPPY/GOOD}' class = 'happyDialog-radio happyDialog-radio-Good' groupname = 'Happy' ).
*    DATA(rate_good_img) = rate_good_img_row->image(
*                              src   = '{= ${/XX/MS_HAPPY/RATE} ===''Good'' ? ''css/css/RAKEGA_extentions/Images/Good-selected.svg'' : ''css/css/RAKEGA_extentions/Images/Good.svg''}'
*                              press = '.extension.RAKHAPPY.onImagePress($event, ''Good'')' ).
    DATA(rate_good_text) = rate_good_vbox->text( text = 'Good' class = 'Body_2_3 color-gray7 shapeIT-hide-in-mobile happyDialog-rate-txt' ).
*    rate_good_text->custom_data( )->core_custom_data( key = 'text-selected' value = '{= ${happyModel>/Rate} ===''Good'' ? ''X'' : ''''}' write_to_dom = 'true' ).

    " Average
    DATA(rate_average_vbox) = images_row->vbox( class = 'happyDialog-image-vbox' rendertype = 'Bare' ).
    DATA(rate_average_img_row) = rate_average_vbox->hbox( class = 'happyDialog-image-hbox' rendertype = 'Bare' ).
    DATA(radio_btn_avg) = rate_average_img_row->radio_button( selected = '{/XX/MS_HAPPY/AVERAGE}' class = 'happyDialog-radio happyDialog-radio-Average' groupname = 'Happy' ).
*    DATA(rate_average_img) = rate_average_img_row->image(
*                                 src   = '{= ${/XX/MS_HAPPY/RATE} ===''Average'' ? ''css/css/RAKEGA_extentions/Images/Average-selected.svg'' : ''css/css/RAKEGA_extentions/Images/Average.svg''}'
*                                 press = '.extension.RAKHAPPY.onImagePress($event, ''Average'')' ).
    DATA(rate_average_text) = rate_average_vbox->text( text = 'Average' class = 'Body_2_3 color-gray7 shapeIT-hide-in-mobile happyDialog-rate-txt' ).
*    rate_average_text->custom_data( )->core_custom_data( key = 'text-selected' value = '{= ${happyModel>/Rate} ===''Average'' ? ''X'' : ''''}' write_to_dom = 'true' ).

    " Poor
    DATA(rate_poor_vbox) = images_row->vbox( class = 'happyDialog-image-vbox' rendertype = 'Bare' ).
    DATA(rate_poor_img_row) = rate_poor_vbox->hbox( class = 'happyDialog-image-hbox' rendertype = 'Bare' ).
    DATA(radio_btn_poor) = rate_poor_img_row->radio_button( selected = '{/XX/MS_HAPPY/POOR}' class = 'happyDialog-radio happyDialog-radio-Poor' groupname = 'Happy' ).
*    DATA(rate_poor_img) = rate_poor_img_row->image(
*                              src   = '{= ${/XX/MS_HAPPY/RATE} ===''Poor'' ? ''css/css/RAKEGA_extentions/Images/Poor-selected.svg'' : ''css/css/RAKEGA_extentions/Images/Poor.svg''}'
*                              press = '.extension.RAKHAPPY.onImagePress($event, ''Poor'')' ).
    DATA(rate_poor_text) = rate_poor_vbox->text( text = 'Poor' class = 'Body_2_3 color-gray7 shapeIT-hide-in-mobile happyDialog-rate-txt' ).
*    rate_poor_text->custom_data( )->core_custom_data( key = 'text-selected' value = '{= ${happyModel>/Rate} ===''Poor'' ? ''X'' : ''''}' write_to_dom = 'true' ).

    " VeryPoor
    DATA(rate_verypoor_vbox) = images_row->vbox( class = 'happyDialog-image-vbox' rendertype = 'Bare' ).
    DATA(rate_verypoor_img_row) = rate_verypoor_vbox->hbox( class = 'happyDialog-image-hbox' rendertype = 'Bare' ).
    DATA(radio_btn_crap) = rate_verypoor_img_row->radio_button( selected = '{/XX/MS_HAPPY/VERYPOOR}' class = 'happyDialog-radio happyDialog-radio-VeryPoor' groupname = 'Happy' ).
*    DATA(rate_verypoor_img) = rate_verypoor_img_row->image(
*                                  src   = '{= ${/XX/MS_HAPPY/RATE} ===''VeryPoor'' ? ''css/css/RAKEGA_extentions/Images/VeryPoor-selected.svg'' : ''css/css/RAKEGA_extentions/Images/VeryPoor.svg''}'
*                                  press = '.extension.RAKHAPPY.onImagePress($event, ''VeryPoor'')' ).
    DATA(rate_verypoor_text) = rate_verypoor_vbox->text( text = 'Very Poor' class = 'Body_2_3 color-gray7 shapeIT-hide-in-mobile happyDialog-rate-txt' ).
*    rate_verypoor_text->custom_data( )->core_custom_data( key = 'text-selected' value = '{= ${happyModel>/Rate} ===''VeryPoor'' ? ''X'' : ''''}' write_to_dom = 'true' ).

    " ---- optional feedback textarea ----
    DATA(textarea_vbox) = outer_cont->vbox( class = 'happyDialog-textarea-vbox' visible = '{/XX/MS_HAPPY/VERYPOOR}' rendertype = 'Bare' ).
    DATA(textarea_label) = textarea_vbox->text( text = 'Can you tell us Why?' class = 'H3_2 color-gray7' ).
    DATA(textarea_inner) = textarea_vbox->vbox( class = 'happyDialog-textarea-inner-vbox' rendertype = 'Bare' ).
    DATA(feedback_textarea) = textarea_inner->text_area(
                                 value       = '{/XX/MS_HAPPY/TEXTAREATEXT}'
                                 class       = 'happyDialog-textarea'
                                 livechange  = '.extension.RAKHAPPY.onTextAreaChange'
                                 maxlength   = '300' ).
*    DATA(textarea_counter) = textarea_inner->text( text = '{= ${/XX/MS_HAPPY/TEXTAREATEXT}.lenght}/300' class = 'Body_2_3 color-gray4' ).

    " ---- footer ----
    DATA(footer) = outer_cont->hbox( class = 'happyDialog-footer' rendertype = 'Bare' ).
    DATA(done_btn) = footer->button( text = 'Done' class = 'regularBTN' press = client->_event( 'RAKHAPPY' )
                                     enabled = '{= ${/XX/MS_HAPPY/EXCELLENT} || ${/XX/MS_HAPPY/GOOD} || ${/XX/MS_HAPPY/AVERAGE} || ${/XX/MS_HAPPY/POOR} || ${/XX/MS_HAPPY/VERYPOOR}}' ).

    client->popup_display( popup->stringify( ) ).
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


  METHOD rakhappy_save.

    DATA:lv_username     TYPE string,
         ls_feedback     TYPE zdt_hm_feedback,
         lv_feedback     TYPE string,
         lv_departmentid TYPE string.

    ls_feedback-sessionid = NEW cl_random_number( )->if_random_number~get_random_int( i_limit = 1000000000 ).
    ls_feedback-casetype  = gs_data-journeytype.
    CASE abap_true.
      WHEN ms_happy-excellent.
        ls_feedback-feedback = '1'.
      WHEN ms_happy-good.
        ls_feedback-feedback = '4'.
      WHEN ms_happy-average.
        ls_feedback-feedback = '3'.
      WHEN ms_happy-poor.
        ls_feedback-feedback = '5'.
      WHEN ms_happy-verypoor.
        ls_feedback-feedback = '2'.
    ENDCASE.

    ls_feedback-uname     = COND #( WHEN lv_username IS INITIAL THEN sy-uname ELSE lv_username ).
    ls_feedback-caseid    = gs_data-caseid.
    ls_feedback-comments  = ms_happy-textareatext.
    ls_feedback-crdate    = sy-datum.
    ls_feedback-crtime    = sy-uzeit+0(2) && ':' && sy-uzeit+2(2) && ':' && sy-uzeit+4(2).
    ls_feedback-step      = '2'.

*    CASE ls_data-department.
*      WHEN 'EPDA'.
*        ls_feedback-departmentid    = '1'.
*      WHEN 'MUN'.
*        ls_feedback-departmentid    = '2'.
*      WHEN 'COURT'.
*        ls_feedback-departmentid    = '3'.
*      WHEN 'PP'.
*        ls_feedback-departmentid    = '4'.
*      WHEN OTHERS.
*    ENDCASE.

    TRY.
        MODIFY zdt_hm_feedback FROM ls_feedback.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
