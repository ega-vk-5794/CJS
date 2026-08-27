class Z2UI5_CL_EXT_WIDGETS definition
  public
  create public .

public section.

  types:
    BEGIN OF ty_params,
        journey TYPE zde_cj_journeyid,
        role    TYPE string,
        partner TYPE but000-partner,
        company TYPE but000-partner,
      END OF ty_params .
  types:
    BEGIN OF ty_stages,
        status          TYPE string,
        stagenumber     TYPE string,
        stagelabel      TYPE string,
        grayleftline    TYPE flag,
        greenleftline   TYPE flag,
        redcircle       TYPE flag,
        greencircle     TYPE flag,
        graycircle      TYPE flag,
        grayrightline   TYPE flag,
        greenrightline  TYPE flag,
        redstagelabel   TYPE flag,
        graystagelabel  TYPE flag,
        greenstagelabel TYPE flag,
        graygap         TYPE flag,
        greengap        TYPE flag,
        islast          TYPE flag,
        screen          TYPE string,
        current         TYPE flag,
      END OF ty_stages .
  types:
    tt_stages TYPE STANDARD TABLE OF ty_stages WITH DEFAULT KEY .
  types:
    BEGIN OF ty_fees,
        description TYPE string,
        fee         TYPE zde_ega_amount,
        product_id  TYPE comt_product_id,
      END OF ty_fees .
  types:
    tt_fees TYPE STANDARD TABLE OF ty_fees WITH DEFAULT KEY .
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
        status               TYPE string,
        description          TYPE string,
        title                TYPE string,
        text                 TYPE string,
        fees                 TYPE tt_fees,
      END OF ty_payment .
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

  data MT_STAGES type TT_STAGES .
  data MS_PAYMENT type TY_PAYMENT .
  data CLIENT type ref to Z2UI5_IF_CLIENT .
  data MT_RESULTS type WDY_KEY_VALUE_LIST .
  data MT_ATTACH type TT_ATTACH .
  data MS_HAPPY type TY_HAPPY .
  data FUNCTIONS type STRING .
  data STYLES type STRING .
  data MS_PARAMS type TY_PARAMS .

  methods STEP_FORWARD
    importing
      !DIRECTION type CHAR1 optional
      !CONTROL type ref to OBJECT
    returning
      value(ET_STAGES) type TT_STAGES .
  methods GET_CURRENT_SCREEN
    returning
      value(SCREEN) type STRING .
  methods RAKSTAGEBAR
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT .
  methods CONSTRUCTOR
    importing
      !MT_STAGES type TT_STAGES optional .
  methods RAKPAY
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT .
  methods RAKPAY_POPUP
    importing
      !IV_URL type STRING .
  methods RAKPAY_RESULT
    importing
      !IV_CASEID type SCMG_EXT_KEY .
  methods INIT .
  methods ADD_FUNCTION
    importing
      !IV_FUNCTION type STRING .
  methods FUNCTIONS_TO_FRONT
    returning
      value(EV_FUNCTION) type STRING .
  methods GET_TEXT_BY_ID
    importing
      !ID type ANY
    returning
      value(TEXT) type STRING .
  methods RAKUPLOADER
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT
      !FILTER_BY type STRING optional .
  methods ADD_STYLE
    importing
      !IV_CSS type STRING .
  methods RAKHAPPY .
  methods RAKHAPPY_SAVE
    importing
      !IV_CASE_TYPE type ANY
      !IV_CASEID type ANY .
  methods GET_VALUE_LIST
    importing
      !PARENT type ref to Z2UI5_CL_XML_FRAGMENT
      !SHLPNAME type SHLPNAME optional
      !KEYFIELD type FIELDNAME optional
      !VALUEFIELD type FIELDNAME optional
      !IT_SELOPT type DDSHSELOPS optional .
  PROTECTED SECTION.
private section.

  data FUNCTIONS_COLLECTIONS type STRING_TABLE .
  data STYLES_COLLECTIONS type STRING_TABLE .

  methods RAKSTAGEBAR_CSS
    returning
      value(EV_CSS) type STRING .
  methods RAKPAY_CSS
    returning
      value(EV_CSS) type STRING .
  methods RAKPAY_GET_STATUS
    importing
      !IV_CASEID type SCMG_EXT_KEY .
  methods RAKPAY_TIMER
    returning
      value(EV_FUNCTION) type STRING .
  methods RAKUPLOADER_FUNCTIONS
    returning
      value(EV_FUNCTION) type STRING .
  methods RAKUPLOADER_CSS
    returning
      value(EV_CSS) type STRING .
  methods RAKHAPPY_CSS
    returning
      value(EV_CSS) type STRING .
  methods GENERAL_CSS
    returning
      value(EV_CSS) type STRING .
ENDCLASS.



CLASS Z2UI5_CL_EXT_WIDGETS IMPLEMENTATION.


  METHOD add_function.
    APPEND iv_function TO functions_collections.
  ENDMETHOD.


  METHOD CONSTRUCTOR.
  ENDMETHOD.


  METHOD functions_to_front.

    IF me->functions_collections[] IS NOT INITIAL.

      DATA(lv_lines) = lines( functions_collections ).

      ev_function = 'sap.ui.define([], function () {' && |\n| &&
        '        return {' && |\n|.
      LOOP AT me->functions_collections INTO DATA(lv_function).
        DATA(lv_tabix) = sy-tabix.
        IF lv_tabix NE lv_lines.
          DATA(lv_len) = strlen( lv_function ).
          DATA(lv_offset) = lv_len - 1.
          IF lv_function+lv_offset(1) NE ','.
            lv_function = lv_function && ','.
          ENDIF.
        ENDIF.
        ev_function = ev_function && lv_function.
      ENDLOOP.

      ev_function = ev_function &&
      '     };' && |\n| &&
      '   });'.

      me->functions = ev_function.
    ENDIF.

    IF me->styles_collections IS NOT INITIAL.
      DATA: lv_styles TYPE string.

      LOOP AT me->styles_collections INTO DATA(ls_style).
        lv_styles = lv_styles && |\n| && ls_style.
      ENDLOOP.

      me->styles = lv_styles.
    ENDIF.
  ENDMETHOD.


  METHOD GET_CURRENT_SCREEN.
    READ TABLE mt_stages ASSIGNING FIELD-SYMBOL(<stage>) WITH KEY current = abap_true.
    IF sy-subrc EQ 0.
      screen = <stage>-screen.
    ENDIF.
  ENDMETHOD.


  METHOD get_text_by_id.
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


  METHOD init.

    DATA(lv_params) = client->get( )-s_config-search.
    IF lv_params IS NOT INITIAL.
      SPLIT lv_params AT '?' INTO DATA(dummy) lv_params.
      SPLIT lv_params AT '&' INTO TABLE DATA(lt_params).
      LOOP AT lt_params INTO DATA(lv_param).
        SPLIT lv_param AT '=' INTO DATA(lv_key) DATA(lv_value).
        TRANSLATE lv_key TO UPPER CASE.
        CASE lv_key.
          WHEN 'JOURNEY'.
            ms_params-journey = lv_value.
          WHEN 'ROLE'.
            ms_params-role = lv_value.
          WHEN 'PARTNER'.
            ms_params-partner = lv_value.
          WHEN 'COPMPANY'.
            ms_params-company = lv_value.
        ENDCASE.
      ENDLOOP.
    ENDIF.

    me->general_css( ).


    client->_bind_edit( mt_stages ).
    client->_bind_edit( mt_attach ).
    client->_bind_edit( ms_payment ).
    client->_bind_edit( functions ).
    client->_bind_edit( styles ).

  ENDMETHOD.


  METHOD rakpay.

    me->rakpay_css( ).
    me->rakpay_timer( ).


    ms_payment-quick = abap_true.
    ms_payment-edirham = abap_true.

    DATA(view)  = io_parent.
    DATA(firstcontainer) = view->vbox( class = 'RAKEGA-firstContainer RAKEGA-pay-initial' ).
    DATA(card) = firstcontainer->vbox( class = 'RAKEGA-card' ).
    DATA(card_top) = card->vbox( class = 'RAKEGA-card-top' ).
    DATA(back_hbox) = card_top->hbox( class = 'RAKEGA-pay-hide-in-initial RAKEGA-pay-hide-in-final' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(paybuttonback) = back_hbox->button( id = 'PAYBUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'RAKEGA-lobby-button-back' icon = 'sap-icon://icomoon/left-arrow' press = client->_event( 'BACK' ) ).
    DATA(card_header_pay) = card_top->hbox( class = 'RAKEGA-pay-hide-in-initial RAKEGA-pay-hide-in-final' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(payment_screen_name) = card_header_pay->label( text = get_text_by_id( 'TITLEPM' ) class = 'font1375 weight600 color-dark-blue' ).
    DATA(card_header) = card_top->hbox( class = 'RAKEGA-pay-hide-in-pay' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(card_header_begin) = card_header->hbox( alignitems = 'Center' ).
    DATA(journeyname_image) = card_header_begin->hbox( class = 'sapUiTinyMarginEnd RAKEGA-hide-in-mobile' alignitems = 'Center' ).
    DATA(title) = card_header_begin->label( text = '{/XX/MS_PAYMENT/DESCRIPTION}' class = 'font1375 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(card_header_vseparator) = card_header_begin->vbox( class = 'RAKEGA-cardheader-vseparator RAKEGA-hide-in-mobile sapUiSmallMarginEnd RAKEGA-pay-hide-in-pay' ).
    DATA(description_title) = card_header_begin->label( text = get_text_by_id( 'TITLEPART_PAYINITIAL_FEE' ) class = 'font1 weight400 color-gray5 RAKEGA-hide-in-mobile RAKEGA-pay-hide-in-pay' ).
    DATA(card_header_end) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = card_header_end->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event(
  'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = card_header_end->button( id = 'SAVEDRAFT_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = card_header_end->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = card_header_end->button( id = 'DELETE_ICONONLY' class = 'RAKEGA-cardheader-topbtn RAKEGA-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(description_panel) = card_top->vbox( class = 'RAKEGA-hide-in-desktop  RAKEGA-pay-hide-in-pay' alignitems = 'Start' ).
    DATA(description_title_in_panel) = description_panel->label( text = get_text_by_id( 'TITLEPART_PAYINITIAL_FEE' ) class = 'font1 weight400 color-gray5' ).

    DATA(stages) = card_top->hbox( class = 'RAKEGA-pay-hide-in-pay sapUiLargeMarginBegin' ).
    me->rakstagebar( stages ).

    DATA(description_details_cont) = card_top->vbox( class = 'RAKEGA-card-descriptioncont RAKEGA-hide-in-mobile sapUiSmallMarginTop RAKEGA-pay-hide-in-pay' alignitems = 'Center' ).
    DATA(description) = description_details_cont->label( text = get_text_by_id( 'DESCRIPTION_RA_SELECTPARCELORGRANTED_1_1' ) class = 'font1 weight400 color-gray6' ).
    DATA(description_details_panel) = card_top->vbox( class = 'RAKEGA-hide-in-desktop sapUiTinyMarginTop RAKEGA-pay-hide-in-pay' alignitems = 'Start' ).
    DATA(journey_description_mobile) = description_details_panel->text_area( value = get_text_by_id( 'DESCRIPTION_RA_SELECTPARCELORGRANTED_1_1' ) maxlength = '65' class = 'Body_1_3 color-gray7 RAKEGA-lobby-ex-text' ).
    DATA(part2) = card->vbox( class = 'RAKEGA-part2' ).
    DATA(payment_container) = part2->vbox( class = 'RAKEGA-pay-payment-container' ).
    DATA(fees_vbox) = payment_container->vbox( class = 'RAKEGA-pay-fees-vbox' ).
    DATA(initialfeelabel) = fees_vbox->label( text = get_text_by_id( 'INITIALFEELABEL' ) class = 'H3_1 color-gray7 RAKEGA-pay-hide-in-pay RAKEGA-pay-hide-in-final' ).
    DATA(finalfeelabel) = fees_vbox->label( text = get_text_by_id( 'FINAL_FEE' ) class = 'H3_1 color-gray7 RAKEGA-pay-hide-in-pay RAKEGA-pay-hide-in-initial' ).
    DATA(feelabel) = fees_vbox->label( text = get_text_by_id( 'FEE' ) class = 'H3_1 color-gray7 RAKEGA-pay-hide-in-initial RAKEGA-pay-hide-in-final' ).
    DATA(fees_inner_vbox) = fees_vbox->vbox( class = 'RAKEGA-pay-fees-inner-vbox' ).
    DATA(feeslist) = fees_inner_vbox->list( items = '{/XX/MS_PAYMENT/FEES}' ).  " TODO(FEESLIST): assumes a class-level table attribute mt_fees - declare it, populated via DATA1=ZFM_EGA_CJ_FW_READ_TABLE_DATAN/DATA2=FEESLIST
    DATA(feeslistitem) = feeslist->items( )->custom_list_item( ).
    DATA(feeslistitemcontent) = feeslistitem->hbox( class = 'feesDialog-list-item' ).
    DATA(descriptioncontainer) = feeslistitemcontent->hbox( class = 'feesDialog-list-description-container' ).
    DATA(feeslistitemdescription) = descriptioncontainer->label( text = '{DESCRIPTION}' class = 'Body_1_3 color-gray6' ).
    DATA(valuescontainer) = feeslistitemcontent->hbox( class = 'feesDialog-list-amount-container' ).
    DATA(aed) = valuescontainer->label( text = get_text_by_id( 'AED' ) class = 'Body_1_3 color-gray6 sapUiTinyMarginEnd' ).
    DATA(feeslistitemvalue) = valuescontainer->label( text = '{FEE}' class = 'Body_1_3 color-gray6' ).
    DATA(total_hbox) = fees_inner_vbox->hbox( class = 'RAKEGA-pay-total-hbox' ).
    DATA(remainingfees_hbox_desktop) = total_hbox->hbox( class = 'RAKEGA-hide-in-mobile' ).
    DATA(remainingfeescontainer) = remainingfees_hbox_desktop->hbox( class = 'RAKEGA-pay-hide-in-pay RAKEGA-pay-hide-in-final' alignitems = 'End' ).
    DATA(remainingfeeslabel) = remainingfeescontainer->label( text = get_text_by_id( 'REMAININGFEESLABEL' ) class = 'Body_2_3 color-gray6 sapUiTinyMarginEnd' ).
    " DEFERRED(REMAININGFEES): RAKREMAININGFEES - link that opens a popup dialog with fee breakdown. Leaving as placeholder for now.
    DATA(remainingfees) = remainingfeescontainer->link( text = '' class = '' ).  " placeholder - see DEFERRED note above
    DATA(cantundocontainer) = remainingfees_hbox_desktop->hbox( class = 'RAKEGA-pay-hide-in-pay RAKEGA-pay-hide-in-initial' ).
    DATA(cantundoicon) = cantundocontainer->icon( src = 'sap-icon://icomoon/info' class = 'RAKEGA-pay-cantdo-icon sapUiTinyMarginEnd' ).
    DATA(cantundolabel) = cantundocontainer->label( text = get_text_by_id( 'CANT_UNDO' ) class = 'Body_1_2 color-red' ).
    DATA(total_inner_hbox) = total_hbox->hbox( ).
    DATA(totallabel) = total_inner_hbox->label( text = get_text_by_id( 'TOTALLABEL' ) class = 'Body_1_1 color-gray6 sapUiTinyMarginEnd' ).
    DATA(aedtoatal) = total_inner_hbox->label( text = get_text_by_id( 'AED' ) class = 'Body_1_1 color-gray6 sapUiTinyMarginEnd' ).
    DATA(totalvalue) = total_inner_hbox->label( text = '{TOTAL_FEE}' class = 'Body_1_1 color-gray6' ).
    DATA(aedtoatal_old) = total_inner_hbox->label( text = get_text_by_id( 'AED' ) class = 'Body_1_1 color-gray6' ).
    DATA(remainingfees_hbox_mobile) = fees_inner_vbox->hbox( class = 'RAKEGA-pay-hide-in-pay RAKEGA-hide-in-desktop' ).
    DATA(remainingfeescontainerm) = remainingfees_hbox_mobile->hbox( class = 'RAKEGA-pay-hide-in-final' ).
    DATA(remainingfeeslabelm) = remainingfeescontainerm->label( text = get_text_by_id( 'REMAININGFEESLABEL' ) class = 'Body_2_3 color-gray6 sapUiTinyMarginEnd' ).
    " DEFERRED(REMAININGFEESM): RAKREMAININGFEES - link that opens a popup dialog with fee breakdown. Leaving as placeholder for now.
    DATA(remainingfeesm) = remainingfeescontainerm->link( text = '' class = '' ).  " placeholder - see DEFERRED note above
    DATA(cantundocontainerm) = remainingfees_hbox_mobile->hbox( class = 'RAKEGA-pay-hide-in-initial' ).
    DATA(cantundoiconm) = cantundocontainerm->icon( src = 'sap-icon://icomoon/info' class = 'RAKEGA-pay-cantdo-icon sapUiTinyMarginEnd' ).
    DATA(cantundolabelm) = cantundocontainerm->label( text = get_text_by_id( 'CANT_UNDO' ) class = 'Body_1_2 color-red' ).
    DATA(payment_vbox) = payment_container->vbox( class = 'RAKEGA-pay-payment-vbox' ).
    DATA(payment_method_cont) = payment_vbox->vbox( class = 'RAKEGA-pay-payment-method-cont' ).
    DATA(payment_method_title) = payment_method_cont->label( text = get_text_by_id( 'PAYMENT_METHOD_TITLE' ) class = 'H3_1 color-gray7' ).
    DATA(rbline) = payment_method_cont->hbox( class = 'rbline' ).
    DATA(rb1) = rbline->radio_button( id = 'RB1' text = get_text_by_id( 'MML_SUBDIVISION_RB1' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/QUICK}' class = 'radioButton' ).
    DATA(rb2) = rbline->radio_button( id = 'RB2' text = get_text_by_id( 'MML_SUBDIVISION_RB2' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/MRAK}' class = 'radioButton' ).
    DATA(rb3) = rbline->radio_button( id = 'RB3' text = get_text_by_id( 'MML_SUBDIVISION_RB3' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/KIOSK}' class = 'radioButton' ).
    DATA(rb4) = rbline->radio_button( id = 'RB4' text = get_text_by_id( 'MML_SUBDIVISION_RB4' ) groupname = 'paymentWay' selected = '{/XX/MS_PAYMENT/WALKIN}' class = 'radioButton' ).
    DATA(payment_method1_cont) = payment_method_cont->vbox( visible = '{/XX/MS_PAYMENT/QUICK}'  ).
    DATA(please1) = payment_method1_cont->hbox( class = 'RAKEGA-pay-please1' ).
    DATA(please_icon1) = please1->icon( src = 'sap-icon://icomoon/info' class = 'RAKEGA-pay-cantdo-icon' ).
    DATA(please1_hbox) = please1->hbox( class = 'RAKEGA-pay-please-hbox' ).
    DATA(please_label1) = please1_hbox->label( text = get_text_by_id( 'PLEASE_ALLOW_POPUPS' ) class = 'Body_1_2 color-red' ).
    DATA(payment_method2_cont) = payment_method_cont->vbox( class = 'RAKEGA-pay-method2-cont' visible = '{= !${/XX/MS_PAYMENT/QUICK}}' ).
    DATA(account_details_cont) = payment_method2_cont->vbox( class = 'RAKEGA-pay-account-details-cont' ).
    DATA(account_details) = account_details_cont->label( text = get_text_by_id( 'ACCOUNT_DETAILS' ) class = 'H3_1 color-gra7' ).
    DATA(account_details_hbox) = account_details_cont->hbox( class = 'RAKEGA-pay-account-details-hbox' ).
    DATA(acountnumber) = account_details_hbox->vbox( class = 'RAKEGA-pay-account-number' ).
    DATA(antitle) = acountnumber->label( text = get_text_by_id( 'NUMBER' ) class = 'Body_1_2 color-gray7' ).
    DATA(ansum) = acountnumber->label( text = '{ACCOUNT}' class = 'Body_1_3 color-gray6' ).
    DATA(casenumber) = account_details_hbox->vbox( class = 'RAKEGA-pay-account-number' ).
    DATA(cntitle) = casenumber->label( text = get_text_by_id( 'CNTITLE' ) class = 'Body_1_2 color-gray7' ).
    DATA(cnsum) = casenumber->label( text = '{CASE}' class = 'Body_1_3 color-gray6' ).
    DATA(service_details_cont) = payment_method2_cont->hbox( class = 'RAKEGA-pay-service-details-cont' ).
    DATA(please2) = service_details_cont->hbox( class = 'RAKEGA-pay-please2' visible = '{/XX/MS_PAYMENT/MRAK}' ).
    DATA(please_image2) = please2->image( src = 'css/css/RAKEGA_extentions/Images/pay-mRak.png' densityaware = 'false' ).
    DATA(please2_hbox) = please2->hbox( class = 'RAKEGA-pay-please-hbox' ).
    DATA(please_label2) = please2_hbox->label( text = get_text_by_id( 'PLEASE_PAY_MOBILE' ) class = 'Body_1_2 color-red' wrapping = 'true' ).
    DATA(please3) = service_details_cont->hbox( class = 'RAKEGA-pay-please2' visible = '{/XX/MS_PAYMENT/KIOSK}' ).
    DATA(please_image3) = please3->image( src = 'css/css/RAKEGA_extentions/Images/pay-KIOSK.png' ).
    DATA(please3_hbox) = please3->hbox( class = 'RAKEGA-pay-please-hbox' ).
    DATA(please_label3) = please3_hbox->label( text = get_text_by_id( 'PLEASE_PAY_KIOSK' ) class = 'Body_1_2 color-red' wrapping = 'true' ).
    DATA(please4) = service_details_cont->hbox( class = 'RAKEGA-pay-please2' visible = '{/XX/MS_PAYMENT/WALKIN}' ).
    DATA(please_image4) = please4->image( src = 'css/css/RAKEGA_extentions/Images/pay-Walk-in.png' ).
    DATA(please4_hbox) = please4->hbox( class = 'RAKEGA-pay-please-hbox' ).
    DATA(please_label4) = please4_hbox->label( text = get_text_by_id( 'PLEASE_PAY_OFFICE' ) class = 'Body_1_2 color-red' wrapping = 'true' ).
    DATA(sendemail) = service_details_cont->check_box( selected = '{/XX/MS_PAYMENT/DONATE}' text = get_text_by_id( 'SENDEMAIL' ) class = 'checkbox' ).
    DATA(paywith_cont) = payment_vbox->vbox( class = 'RAKEGA-pay-paywith-cont' visible = '{/XX/MS_PAYMENT/QUICK}' ).
    DATA(pay_with_title) = paywith_cont->label( text = get_text_by_id( 'PAY_WITH' ) class = 'Body_1_2 color-gray7' ).
    DATA(pw_rbline) = paywith_cont->hbox( class = 'RAKEGA-pay-pw-rbline' ).
    DATA(rb_group2) = pw_rbline->radio_button_group( ).
    DATA(pw_hbox2) = pw_rbline->hbox( class = 'RAKEGA-pay-pw-hbox' ).
    DATA(pw_rb2) = pw_hbox2->radio_button( id = 'PW_RB2' groupname = 'paymentMethod' selected = '{/XX/MS_PAYMENT/EDIRHAM}' class = 'RAKEGA-pay-radio-button' ).
    DATA(pw_img21) = pw_hbox2->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-rak-pay.png' height = '1.75rem' ).
    DATA(pw_hbox1) = pw_rbline->hbox( class = 'RAKEGA-pay-pw-hbox' ).
    DATA(pw_rb1) = pw_hbox1->radio_button( id = 'PW_RB1' groupname = 'paymentMethod' selected = '{/XX/MS_PAYMENT/CREDITCARD}' class = 'RAKEGA-pay-radio-button' ).
    DATA(pw_images1) = pw_hbox1->hbox( class = 'RAKEGA-pay-pw-images1' ).
    DATA(pw_img11) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card1.png' height = '1.613rem' ).
    DATA(pw_img12) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card2.png' height = '1.613rem' ).
    DATA(pw_img13) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card3.png' height = '1.613rem' ).
    DATA(pw_img14) = pw_images1->image( src = 'css/css/RAKEGA_extentions/Images/pay-pw-card4.png' height = '1.613rem' ).
    DATA(footer) = firstcontainer->hbox( class = 'RAKEGA-footer' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border RAKEGA-pay-hide-in-pay' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(pay_btn) = footer->button(
                       visible   = '{= !${/XX/MS_PAYMENT/NEXTVISIBLE} }'
                       text      = 'Pay'
                       icon      = 'sap-icon://icomoon/Right'
                       press     = client->_event( 'PAY' )
                       class     = 'regularBTN'
                       iconfirst = 'false' ).

    DATA(next_btn) = footer->button(
                       visible   = '{= ${/XX/MS_PAYMENT/NEXTVISIBLE} }'
                       text      = 'Next'
                       icon      = 'sap-icon://icomoon/Right'
                       press     = client->_event( 'SAVE' )
                       class     = 'regularBTN'
                       iconfirst = 'false' ).
  ENDMETHOD.


  METHOD rakpay_get_status.
    DATA: lt_cases          TYPE ztt_cases_qp,
          case_key          TYPE scmg_ext_key,
          i_serviceid       TYPE string,
          i_referencenumber TYPE string,
          bankapprovalcode  TYPE string,
          transactionid     TYPE string,
          amount            TYPE string,
          finalizedamount   TYPE string,
          paymentsuccess    TYPE string,
          result            TYPE zdt_ega_gw_payment_response,
          zzext_key         TYPE scmg_ext_key,
          lt_open           TYPE zdt_ega_bp_open_tt.

    DATA(intreno) = iv_caseid.

    DATA: lv_input_code  TYPE string,
          lv_output_code TYPE string,
          lv_pp_position TYPE i.

    lv_pp_position = find( val = intreno sub = 'PP' ).

    IF sy-sysid EQ 'E10'.
*    IF sy-sysid EQ 'E10' OR sy-sysid EQ 'E20'."Temporary Fix for Payment to Tenancy Contract
      ms_payment-status = 'SUCCESS'.
      RETURN.
    ENDIF.

    IF lv_pp_position < 1.

      DATA: lv_object_id       TYPE crmt_object_id,
            lv_object_id_xblnr TYPE xblnr_kk.
      lv_object_id = |{ intreno ALPHA = OUT }|.

      SELECT SINGLE objtype_h, object_id
        FROM crms4d_btx_h INTO @DATA(ls_crms4d_btx_h)
        WHERE object_id = @lv_object_id.

** PP short link scenario
      IF sy-subrc = 0 .
        IF ls_crms4d_btx_h-objtype_h = 'BUS2000116'.
          lv_object_id_xblnr = |{ lv_object_id ALPHA = IN }|.
          SELECT betrh , xblnr , zzext_key , zzcrmbill_doc INTO TABLE @DATA(lt_dfkkop)
              FROM dfkkop WHERE augst NE '9' AND xblnr EQ @lv_object_id_xblnr.
          IF sy-subrc = 0.
            READ  TABLE lt_dfkkop INTO DATA(ls_dfkkop) INDEX 1.
            SELECT * FROM zetislat_transac INTO TABLE @DATA(transactions) WHERE payment_id EQ @ls_dfkkop-zzcrmbill_doc AND status <> 'C'.
          ENDIF.

        ELSE.
          SELECT betrh , xblnr , zzext_key, zzcrmbill_doc INTO TABLE @lt_dfkkop
                         FROM dfkkop WHERE augst NE '9' AND zzcrmbill_doc EQ @lv_object_id.
          IF sy-subrc = 0.
            SELECT * FROM zetislat_transac INTO TABLE @transactions WHERE payment_id EQ @lv_object_id AND status <> 'C'.
          ENDIF.
        ENDIF.
      ELSE.
** MUN short link scenario
        IF strlen( intreno ) > 13.
          ms_payment-status = 'FAILED'.
          RETURN.
        ENDIF.
        SELECT SINGLE supplementinfo INTO @DATA(caseid)
          FROM vibdcharact WHERE intreno EQ @intreno AND fixfitcharact EQ 'CJ12'.

        IF sy-subrc <> 0 OR caseid IS INITIAL.
          DATA(cases) = zcl_cj_gen_utils=>get_cases( intreno = CONV #( intreno ) ).
          IF cases[] IS NOT INITIAL.
            caseid = VALUE #( cases[ 1 ]-fieldname OPTIONAL ).
          ELSE.
            case_key = |{ intreno ALPHA = IN }|.
            SELECT SINGLE ext_key INTO @DATA(key) FROM scmg_t_case_attr WHERE ext_key EQ @case_key.
            IF sy-subrc  <> 0 AND key IS NOT INITIAL.
              ms_payment-status = 'FAILED'.
              RETURN.
            ELSE.
              SELECT * FROM zetislat_transac INTO TABLE @transactions WHERE ext_key EQ @case_key AND status <> 'C'.
            ENDIF.
          ENDIF.
        ENDIF.

        IF caseid IS NOT INITIAL.
          case_key = CONV #( caseid ).
        ENDIF.

        IF case_key IS INITIAL.
          ms_payment-status = 'FAILED'.
          RETURN.
        ENDIF.

      ENDIF.

    ENDIF.

    IF lv_pp_position > 0.
      DATA: lv_before     TYPE string,
            lv_payment_id TYPE vbeln.

      SPLIT intreno AT 'PP' INTO lv_before lv_payment_id.
      SELECT * FROM zetislat_transac INTO TABLE @transactions WHERE payment_id EQ @lv_payment_id AND status <> 'C'.
    ELSEIF transactions IS INITIAL.
      case_key = |{ case_key ALPHA = IN }|.
      SELECT * FROM zetislat_transac INTO TABLE @transactions WHERE ext_key EQ @case_key AND status <> 'C'.
    ENDIF.


    IF sy-subrc <> 0.
      ms_payment-status = 'FAILED'.
      RETURN.
    ENDIF.

    SORT transactions BY date_init DESCENDING time_init DESCENDING.
    READ TABLE transactions INTO DATA(transaction) INDEX 1.
    IF sy-subrc <> 0.
      ms_payment-status = 'FAILED'.
      RETURN.
    ENDIF.

    IF transaction-status EQ 'C'.
      ms_payment-status = 'FAILED'.
      RETURN.
    ENDIF.

    IF transaction-gateway = 'ATB'.
      DATA(lv_checkout_id) = transaction-checkoutid.
      CALL METHOD zcl_ega_payment_utility=>call_atb_details
        EXPORTING
          iv_ref_id          = CONV zde_ega_pay_transaction_id( transaction-transaction_id )
          iv_checkoutid      = CONV #( lv_checkout_id )
        IMPORTING
          ev_urn             = DATA(urn)
          ev_pay_succ        = DATA(lv_paysucc)
          ev_order_status    = DATA(orderstatus)
          ev_amount          = DATA(lv_amount)
          ev_checkoutstatus  = DATA(lv_checkoutstatus)
          ev_disp_status_msg = DATA(lv_dispstatusmsg)
          ev_settlementdate  = DATA(settlementdate).
      IF ( lv_dispstatusmsg EQ 'Success' OR lv_dispstatusmsg = 'CLOSED' OR lv_dispstatusmsg = 'CONFIRMED' ) AND orderstatus = '2'.
        ms_payment-status = 'SUCCESS' .
      ELSEIF lv_dispstatusmsg = 'READY'.
        ms_payment-status = 'OPEN'.
      ELSEIF lv_dispstatusmsg = 'DECLINED' OR lv_dispstatusmsg = 'EXPIRED'.
        ms_payment-status = 'FAILED'.
      ELSE.
        ms_payment-status = 'OPEN'.
      ENDIF.

      RETURN.
    ENDIF.

    i_serviceid =  transaction-service_id.
    i_referencenumber = transaction-transaction_id.

    CALL FUNCTION 'ZREAD_PAY_STATUS_DEST'
      EXPORTING
        i_serviceid       = i_serviceid
        i_referencenumber = i_referencenumber
      IMPORTING
        bankapprovalcode  = bankapprovalcode
        transactionid     = transactionid
        amount            = amount
        finalizedamount   = finalizedamount
        paymentsuccess    = paymentsuccess
        result            = result.

    IF result-status EQ '0000'.
      ms_payment-status = 'SUCCESS'.
    ELSE.
      ms_payment-status = 'OPEN'.
    ENDIF.
  ENDMETHOD.


  METHOD rakpay_popup.
    DATA(popup) = z2ui5_cl_xml_fragment=>factory( ).

    IF iv_url IS NOT INITIAL.
      ms_payment-title = 'Payment Processing' .
      ms_payment-text  = 'Please don’t close the window until the processing is done'.
      ms_payment-busyindicatorvisible = abap_true.
    ENDIF.

    " TODO: ->dialog( ) - not yet confirmed against z2ui5_cl_xml_view's actual API surface,
    " same caveat as file_uploader/progress_indicator/custom_data earlier.
    DATA(pay_dialog) = popup->dialog(
                          id                   = 'payDialog'
                          showheader           = 'false'
                          horizontalscrolling  = 'false'
                          afteropen            = '.afterOpen'
                          class                = 'confirmDialog payDialogBorderTopGray' ).

    pay_dialog->custom_data( )->core_custom_data( key = 'URL' value = iv_url ).

    DATA(outer_vbox) = pay_dialog->vbox( width = '100%' class = 'confirmDialog-vbox' ).
    DATA(inner_vbox) = outer_vbox->vbox( width = '100%' class = 'confirmDialog-inner-vbox' ).

    DATA(header_row) = inner_vbox->hbox( width = '100%' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title_text) = header_row->text( text = ms_payment-title class = 'color-black font1125 weight500' ).
    DATA(lv_ind) = ms_payment-busyindicatorvisible.
    IF lv_ind EQ abap_true.
      lv_ind = abap_false.
    ELSE.
      lv_ind = abap_true.
    ENDIF.
    DATA(close_icon) = header_row->icon(
                           visible = lv_ind
                           src     = 'sap-icon://icomoon/close'
                           color   = '#10233E'
                           size    = '1.5rem'
                           press   = '.destroyPopup' ).

    DATA(body_text) = inner_vbox->text( text = ms_payment-text class = 'color-black font1 weight400' ).

    DATA(busy_row) = inner_vbox->hbox( class = 'payDialog-busy-hbox' width = '100%' justifycontent = 'Center' alignitems = 'Center' ).
    DATA(busy_indicator) = busy_row->busy_indicator( visible = ms_payment-busyindicatorvisible ).

    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.


  METHOD rakpay_result.
    me->rakpay_get_status( iv_caseid ).
    CASE ms_payment-status.
      WHEN 'FAILED'.
        ms_payment-title                = 'Payment failed'.
        ms_payment-busyindicatorvisible = abap_false.
        ms_payment-nextvisible          = abap_false.

      WHEN 'SUCCESS'.
        ms_payment-title                = 'Payment successful'.
        ms_payment-busyindicatorvisible = abap_false.
        ms_payment-nextvisible          = abap_true.
      WHEN 'OPEN'.

    ENDCASE.
  ENDMETHOD.


  METHOD rakpay_timer.
    ev_function =
'           afterOpen: function (oEvent) {' && |\n| &&
'             var url = oEvent.getSource().getCustomData().find(item => item.getKey() === "URL");' && |\n| &&
'             var oModel = oEvent.getSource().getModel();' && |\n| &&
'             if (oModel.getProperty("/XX/MS_PAYMENT/STATUS") === "FAILED"){' && |\n| &&
'               this._z2ui5Popup.addStyleClass("payDialogBorderTopRed");' && |\n| &&
'             }' && |\n| &&
'             if (oModel.getProperty("/XX/MS_PAYMENT/STATUS") === "SUCCESS"){' && |\n| &&
'               this._z2ui5Popup.addStyleClass("payDialogBorderTopGreen");' && |\n| &&
'             }' && |\n| &&
'             if (url && url.getValue() || oModel.getProperty("/XX/MS_PAYMENT/STATUS") === "OPEN"){' && |\n| &&
'             if (url && url.getValue()){' && |\n| &&
'               window.open(url.getValue(), "_blank");' && |\n| &&
'             }' && |\n| &&
'               setTimeout(function () {' && |\n| &&
'             var S_FRONT = oModel.getProperty("/S_FRONT");' && |\n| &&
'             S_FRONT.VIEW = "MAIN";' && |\n| &&
'             S_FRONT.EVENT = "PAYCHECK";' && |\n| &&
'             this.readBackend();' && |\n| &&
'           }.bind(this), 5000);' && |\n| &&
'           oModel.refresh(false);' && |\n| &&
'         }' && |\n| &&
'       }'.
    me->add_function( ev_function ).

    functions = me->functions_to_front( ).
  ENDMETHOD.


  METHOD rakstagebar.

    me->rakstagebar_css( ).

    DATA(id_rak_stagebar) = io_parent->vbox( id = 'id-rak-stagebar' width = '100%' class = 'rak-stagebar-margin' rendertype = 'Bare' ).

    " ===================== DESKTOP =====================
    DATA(desktop) = id_rak_stagebar->hbox( width = '100%' visible = 'true' rendertype = 'Bare' ).

    " repeating aggregation - one HBox per stage, bound to oStageBarData>/stages
    DATA(stages) = desktop->hbox( items = '{/XX/MT_STAGES}' justifycontent = 'Start' alignitems = 'Start' rendertype = 'Bare' ).
*    LOOP AT mt_stages INTO DATA(ls_stage).
    DATA(stage_item) = stages->hbox( rendertype = 'Bare' ).

    " ---- STEP VBOX ----
    DATA(step_cont) = stage_item->vbox( width = '120px' justifycontent = 'Start' alignitems = 'Center' class = 'rak-stagebar-step-cont' rendertype = 'Bare' ).

    " -- lines & circle row --
    DATA(lines_circle) = step_cont->hbox( justifycontent = 'Start' alignitems = 'Start' rendertype = 'Bare' ).

    " left line
    DATA(left_line) = lines_circle->hbox( width = '2.8125rem' height = '0.9375rem' rendertype = 'Bare' ).
    DATA(left_line_gray) = left_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYLEFTLINE}' rendertype = 'Bare' ).
    DATA(left_line_green) = left_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENLEFTLINE}' rendertype = 'Bare' ).

    " circle
    DATA(circle) = lines_circle->hbox( width = '1.875rem' height = '1.875rem' rendertype = 'Bare' ).

    DATA(circle_red) = circle->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-red' visible = '{REDCIRCLE}' rendertype = 'Bare' ).
    DATA(circle_red_text) = circle_red->text( text = '{STAGENUMBER}' class = 'Body_2_2 color-white' ).

    DATA(circle_green) = circle->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-green' visible = '{GREENCIRCLE}' rendertype = 'Bare' ).
    DATA(circle_green_icon) = circle_green->icon( src = 'sap-icon://icomoon/fi_check' color = '#53A56E' class = 'rak-stagebar-step-done-icon' ).

    DATA(circle_gray) = circle->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-gray' visible = '{GRAYCIRCLE}' rendertype = 'Bare' ).
    DATA(circle_gray_text) = circle_gray->text( text = '{STAGENUMBER}' class = 'Body_2_3 color-gray4' ).

    " right line
    DATA(right_line) = lines_circle->hbox( width = '2.8125rem' height = '0.9375rem' rendertype = 'Bare' ).
    DATA(right_line_gray) = right_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYRIGHTLINE}' rendertype = 'Bare' ).
    DATA(right_line_green) = right_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENRIGHTLINE}' rendertype = 'Bare' ).

    " -- text row --
    DATA(text_row) = step_cont->hbox( width = '100%' justifycontent = 'Center' alignitems = 'Start' rendertype = 'Bare' ).
    DATA(text_red) = text_row->text( text = '{STAGELABEL}' class = 'Body_2_3 color-red rak-stagebar-text-align-desktop' visible = '{REDSTAGELABEL}' ).
    DATA(text_gray) = text_row->text( text = '{STAGELABEL}' class = 'Body_2_3 color-gray4 rak-stagebar-text-align-desktop' visible = '{GRAYSTAGELABEL}' ).
    DATA(text_green) = text_row->text( text = '{STAGELABEL}' class = 'Body_2_3 color-green rak-stagebar-text-align-desktop' visible = '{GREENSTAGELABEL}' ).

    " ---- GAP VBOX ----
    " NOTE: width is set programmatically client-side (StepBarInit()), same as source fragment's own comment.
    DATA(gap) = stage_item->vbox( width = '72px' height = '0.9375rem' justifycontent = 'Start'
                                   visible = '{ISLAST}' rendertype = 'Bare' ).
    DATA(gap_gray) = gap->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYGAP}' rendertype = 'Bare' ).
    DATA(gap_green) = gap->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENGAP}' rendertype = 'Bare' ).

*    ENDLOOP.

    " ===================== MOBILE =====================
    DATA(mobile) = id_rak_stagebar->vbox( alignitems = 'Start' visible = 'false' width = '20.5rem' rendertype = 'Bare' ).

    DATA(mobile_label_row) = mobile->hbox( justifycontent = 'Start' rendertype = 'Bare' ).
    DATA(mobile_label) = mobile_label_row->text( text = '{oStageBarData>/settings/CurrentStageLabel}' class = 'Body_1_1 color-Gray7' ).

    DATA(mobile_progress_row) = mobile->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' width = '100%' rendertype = 'Bare' ).
    DATA(mobile_progress_bar) = mobile_progress_row->hbox( width = '70%' height = '0.375rem' rendertype = 'Bare' ).
    DATA(mobile_progress_indicator) = mobile_progress_bar->progress_indicator(
                                          displayonly  = 'true'
                                          percentvalue = '{oStageBarData>/settings/ProgressPercent}'
                                          height       = '100%'
                                          width        = '100%'
                                          class        = 'rak-stagebar-progress-indicator' ).

    " {i18n>step} X {i18n>of} Y - two i18n text-pool fragments interpolated around bound numbers.
    DATA(mobile_step_text) = mobile_progress_row->text(
                                text  = '{i18n>step} {oStageBarData>/settings/CurrentStage} {i18n>of} {oStageBarData>/settings/TotalStages}'
                                class = 'Body_2_3 color-gray7' ).
  ENDMETHOD.


  METHOD rakuploader.

    me->rakuploader_css( ).
    me->rakuploader_functions( ).

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

    DATA(attachments) = io_parent->vbox( items = lv_binding ).
    DATA(root) = attachments->vbox( ).

    DATA(attach_txt) = root->label( text = '{LABEL}' required = '{REQUIRED}' class = 'font1 weight500 color-gray7 sapUiMediumMarginTop' ).
    " ===================== STATE 1: no file yet, show uploader =====================
    DATA(state_empty) = root->vbox( class = 'sapUiTinyMarginTop' height = '2.6875rem' width = '100%'
                                     visible = '{= ${FILE_NAME} || ${READ_MODE} ? false : true }' ).

    DATA(select_row) = state_empty->hbox( class = 'brdrRed rakuploader-hbox' rendertype = 'Bare' ).
    DATA(select_text) = select_row->text( text = '{i18n>SelectFile}' class = 'color-gray4 font0875 weight400' ).

    DATA(uploader_box) = select_row->hbox( class = 'rakuploader-uploader-hbox' rendertype = 'Bare' ).
*    DATA(file_uploader) = uploader_box->icon( src = 'sap-icon://icomoon/Attach' color = '#10233E'
*                                              press = '.onUploadStart'
*                                              size = '1.25rem'
*                                              visible = '{= ${READ_MODE} ? false : true }' ).
    DATA(file_uploader) = uploader_box->file_uploader(
                              buttononly             = 'true'
                              class                  = 'FileUploader'
                              filetype               = 'JPG,JPEG,jpeg,jpg,PNG,png,doc,docx,pdf,PDF'
                              icononly               = 'true'
                              samefilenameallowed    = 'true'
                              change                 = '.onChangeUploadedFile'
                              icon                   = 'sap-icon://icomoon/Attach'
                              typemissmatch          = '.UploaderTypeMissmatch'
                              valuestate             = 'Error' ).


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


  METHOD rakuploader_functions.

    ev_function =
'       onChangeUploadedFile: function(oEvent){' && |\n| &&
'       var item = oEvent.getSource().getBindingContext().getObject();' && |\n| &&
'       var oModel = oEvent.getSource().getModel();   ' && |\n| &&
'       var oFile = oEvent.getParameter("files")[0];' && |\n| &&
'       if (!oFile) {' && |\n| &&
'         return;' && |\n| &&
'       }' && |\n| &&
'       item.FILE_NAME = oFile.name;' && |\n| &&
'       var oReader = new FileReader();' && |\n| &&
'' && |\n| &&
'       oReader.onload = function (oLoadEvent) {' && |\n| &&
'	      item.FILE_DATA = oLoadEvent.target.result;          // "data:application/pdf;base64,JVBERi0x..."' && |\n| &&
'	      oModel.refresh(false);' && |\n| &&
'       };' && |\n| &&
'       oReader.onerror = function (oErrorEvent) {' && |\n| &&
'       };' && |\n| &&
'       oReader.readAsDataURL(oFile); ' && |\n| &&
'        }'.
    me->add_function( ev_function ).
    ev_function =
'      onDeleteUploadedFile: function(oEvent){ ' && |\n| &&
'       var item = oEvent.getSource().getBindingContext().getObject(); ' && |\n| &&
'       var oModel = oEvent.getSource().getModel(); ' && |\n| &&
'       item.FILE_NAME = ""; ' && |\n| &&
'       item.FILE_DATA = ""; ' && |\n| &&
'       oModel.refresh(false); ' && |\n| &&
'     }'.
    me->add_function( ev_function ).
    ev_function =
'     onDisplayUploadedFile: function(oEvent){' && |\n| &&
'       var item = oEvent.getSource().getBindingContext().getObject();' && |\n| &&
'       var a = document.createElement("a");' && |\n| &&
'       a.download = encodeURI(item.FILE_NAME);' && |\n| &&
'       a.href = item.FILE_DATA;' && |\n| &&
'       a.target = "_blank";' && |\n| &&
'       a.click();' && |\n| &&
'     }    '.
    me->add_function( ev_function ).

    functions = me->functions_to_front( ).
  ENDMETHOD.


  METHOD STEP_FORWARD.
    READ TABLE mt_stages ASSIGNING FIELD-SYMBOL(<stage>) WITH KEY current = abap_true.
    IF sy-subrc EQ 0.
      DATA(lv_tabix) = sy-tabix.
      <stage>-current = abap_false.
      CASE direction.
        WHEN '-'.
          SUBTRACT 1 FROM lv_tabix.
        WHEN '+'.
          ADD 1 TO lv_tabix.
        WHEN '='.
        WHEN OTHERS.
      ENDCASE.
      IF lv_tabix GT 0.
        READ TABLE mt_stages ASSIGNING <stage> INDEX lv_tabix.
      ELSE.
        READ TABLE mt_stages ASSIGNING <stage> INDEX 1.
      ENDIF.
    ELSE.
      READ TABLE mt_stages ASSIGNING <stage> INDEX 1.
    ENDIF.
    IF sy-subrc EQ 0.
      lv_tabix = sy-tabix.

      LOOP AT mt_stages ASSIGNING FIELD-SYMBOL(<next_stage>).
        DATA(lv_line) = sy-tabix.
        <next_stage>-stagenumber = lv_line.
        SHIFT <next_stage>-stagenumber LEFT DELETING LEADING space.

        <next_stage>-grayleftline      = ''.
        <next_stage>-greenleftline     = ''.
        <next_stage>-redcircle         = ''.
        <next_stage>-greencircle       = ''.
        <next_stage>-graycircle        = ''.
        <next_stage>-grayrightline     = ''.
        <next_stage>-greenrightline    = ''.
        <next_stage>-redstagelabel     = ''.
        <next_stage>-graystagelabel    = ''.
        <next_stage>-greenstagelabel   = ''.
        <next_stage>-graygap           = ''.
        <next_stage>-greengap          = ''.
        <next_stage>-islast            = 'X'.
        IF lv_line EQ lines( mt_stages ).
          <next_stage>-islast          = ''.
        ENDIF.

        IF lv_line LT lv_tabix.
          <next_stage>-status          = 'Completed'.
          IF lv_line GT 1.
            <next_stage>-greenleftline   = 'X'.
          ENDIF.
          <next_stage>-greenrightline  = 'X'.
          <next_stage>-greengap        = 'X'.
          <next_stage>-greencircle     = 'X'.
          <next_stage>-greenstagelabel = 'X'.
        ENDIF.
        IF lv_line GT lv_tabix.
          <next_stage>-status          = 'Disabled'.
          <next_stage>-graycircle      = 'X'.
          <next_stage>-graystagelabel  = 'X'.
          <next_stage>-grayleftline   = 'X'.
          IF <next_stage>-islast EQ 'X'.
            <next_stage>-grayrightline = 'X'.
            <next_stage>-graygap       = 'X'.
          ENDIF.
        ENDIF.
      ENDLOOP.

      <stage>-current                  = abap_true.
      <stage>-status                   = 'Current'.
      <stage>-redcircle                = 'X'.
      <stage>-redstagelabel            = 'X'.
      <stage>-grayrightline            = 'X'.
      <stage>-graygap                  = 'X'.
      IF lv_tabix GT 1.
        <stage>-greenleftline          = 'X'.
      ENDIF.
      CALL METHOD control->(<stage>-screen).

      et_stages[] = me->mt_stages[].


    ENDIF.
  ENDMETHOD.


  METHOD add_style.
    APPEND iv_css TO styles_collections.
  ENDMETHOD.


  METHOD rakhappy.

    CHECK ms_happy-initilized EQ abap_false.

    me->rakhappy_css( ).
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
                                 maxlength   = '300' ).
*    DATA(textarea_counter) = textarea_inner->text( text = '{= ${/XX/MS_HAPPY/TEXTAREATEXT}.lenght}/300' class = 'Body_2_3 color-gray4' ).

    " ---- footer ----
    DATA(footer) = outer_cont->hbox( class = 'happyDialog-footer' rendertype = 'Bare' ).
    DATA(done_btn) = footer->button( text = 'Done' class = 'regularBTN' press = client->_event( 'RAKHAPPY' )
                                     enabled = '{= ${/XX/MS_HAPPY/EXCELLENT} || ${/XX/MS_HAPPY/GOOD} || ${/XX/MS_HAPPY/AVERAGE} || ${/XX/MS_HAPPY/POOR} || ${/XX/MS_HAPPY/VERYPOOR}}' ).

    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.


  METHOD rakhappy_css.

    DATA: excellent     TYPE string,
          excellent_sel TYPE string,
          good          TYPE string,
          good_sel      TYPE string,
          average       TYPE string,
          average_sel   TYPE string,
          poor          TYPE string,
          poor_sel      TYPE string,
          verypoor      TYPE string,
          verypoor_sel  TYPE string,
          xstring       TYPE xstring.

    excellent =
'<svg width="67" height="66" viewBox="0 0 67 66" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<g filter="url(#filter0_d_2633_7050)">' &&
'<rect width="52" height="52" rx="8" transform="matrix(-1 0 0 1 59.5 7)" fill="white" shape-rendering="crispEdges"/>' &&
'<rect x="-0.5" y="0.5" width="51" height="51" rx="7.5" transform="matrix(-1 0 0 1 58.5 7)" stroke="#E6E6E6" shape-rendering="crispEdges"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 48.5 18)" fill="#53A56E"/>' &&
'<path d="M38.7905 35C39.1826 35 39.5043 35.3193 39.4585 35.7087C39.1079 38.6884 36.5739 41 33.5 41C30.4261 41 27.8921 38.6884 27.5414 35.7087C27.4956' &&
' 35.3193 27.8173 35 28.2094 35C29.2209 35 31.2107 35 33.5 35C35.7892 35 37.779 35 38.7905 35Z" fill="#202020"/>' &&
'<path d="M35.5117 29.629C35.5267 29.5789 35.5564 29.5333 35.5977 29.4966L36.2275 28.9382C37.6044 27.7173 39.8222 27.6838 41.2451 28.8623L41.394' &&
' 28.9855C41.4853 29.0611 41.5213 29.1757 41.4875 29.2823C41.4394 29.4338 41.2663 29.5255 41.0935 29.4909L40.4458 29.3613C39.3949 29.1511 38.298' &&
' 29.2146 37.2867 29.5444L35.9462 29.9815C35.6941 30.0636 35.4424 29.8595 35.5117 29.629Z" fill="#202020"/>' &&
'<path d="M31.4883 29.629C31.4733 29.5789 31.4436 29.5333 31.4023 29.4966L30.7725 28.9382C29.3956 27.7173 27.1778 27.6838 25.7549' &&
' 28.8623L25.606 28.9855C25.5147 29.0611 25.4787 29.1757 25.5125 29.2823C25.5606 29.4338 25.7337 29.5255 25.9065 29.4909L26.5542' &&
' 29.3613C27.6051 29.1511 28.702 29.2146 29.7133 29.5444L31.0538 29.9815C31.3059 30.0636 31.5576 29.8595 31.4883 29.629Z" fill="#202020"/>' &&
'</g>' &&
'<defs>' &&
'<filter id="filter0_d_2633_7050" x="0.5" y="0" width="66" height="66" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">' &&
'<feFlood flood-opacity="0" result="BackgroundImageFix"/>' &&
'<feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>' &&
'<feOffset/>' &&
'<feGaussianBlur stdDeviation="3.5"/> ' &&
'<feComposite in2="hardAlpha" operator="out"/> ' &&
'<feColorMatrix type="matrix" values="0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0.25 0"/>' &&
'<feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_2633_7050"/>' &&
'<feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_2633_7050" result="shape"/>' &&
'</filter>' &&
'</defs>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = excellent
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = excellent.
    excellent = 'data:image/svg+xml;base64,' && excellent.

    excellent_sel =
    '<svg width="53" height="52" viewBox="0 0 53 52" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
    '<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" fill="white"/>' &&
    '<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" stroke="#10233E" stroke-width="2"/>' &&
    '<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 41.5 11)" fill="#53A56E"/>' &&
    '<path d="M31.7905 28C32.1826 28 32.5043 28.3193 32.4585 28.7087C32.1079 31.6884 29.5739 34 26.5 34C23.4261 34 20.8921' &&
    ' 31.6884 20.5414 28.7087C20.4956 28.3193 20.8173 28 21.2094 28C22.2209 28 24.2107 28 26.5 28C28.7892 28 30.779 28 31.7905 28Z" fill="#202020"/>' &&
    '<path d="M28.5117 22.629C28.5267 22.5789 28.5564 22.5333 28.5977 22.4966L29.2275 21.9382C30.6044 20.7173 32.8222 20.6838' &&
    ' 34.2451 21.8623L34.394 21.9855C34.4853 22.0611 34.5213 22.1757 34.4875 22.2823C34.4394 22.4338 34.2663 22.5255 34.0935' &&
    ' 22.4909L33.4458 22.3613C32.3949 22.1511 31.298 22.2146 30.2867 22.5444L28.9462 22.9815C28.6941 23.0636 28.4424 22.8595 28.5117 22.629Z" fill="#202020"/>' &&
    '<path d="M24.4883 22.629C24.4733 22.5789 24.4436 22.5333 24.4023 22.4966L23.7725 21.9382C22.3956 20.7173 20.1778 20.6838' &&
    ' 18.7549 21.8623L18.606 21.9855C18.5147 22.0611 18.4787 22.1757 18.5125 22.2823C18.5606 22.4338 18.7337 22.5255 18.9065' &&
    ' 22.4909L19.5542 22.3613C20.6051 22.1511 21.702 22.2146 22.7133 22.5444L24.0538 22.9815C24.3059 23.0636 24.5576 22.8595 24.4883 22.629Z" fill="#202020"/>' &&
    '</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = excellent_sel
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = excellent_sel.
    excellent_sel = 'data:image/svg+xml;base64,' && excellent_sel.

    good =
'<svg width="67" height="66" viewBox="0 0 67 66" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<g filter="url(#filter0_d_2633_7020)">' &&
'<rect width="52" height="52" rx="8" transform="matrix(-1 0 0 1 59.5 7)" fill="white" shape-rendering="crispEdges"/>' &&
'<rect x="-0.5" y="0.5" width="51" height="51" rx="7.5" transform="matrix(-1 0 0 1 58.5 7)" stroke="#E6E6E6" shape-rendering="crispEdges"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 48.5 18)" fill="#8FC36F"/>' &&
'<path d="M39.342 29.1565C39.342 30.2175 38.4819 31.0775 37.421 31.0775C36.3601 31.0775 35.5 30.2175 35.5 29.1565C35.5 28.0956' &&
' 36.3601 27.2356 37.421 27.2356C38.4819 27.2356 39.342 28.0956 39.342 29.1565Z" fill="#202020"/>' &&
'<path d="M27.658 29.1565C27.658 30.2175 28.5181 31.0775 29.579 31.0775C30.6399 31.0775 31.5 30.2175 31.5 29.1565C31.5' &&
' 28.0956 30.6399 27.2356 29.579 27.2356C28.5181 27.2356 27.658 28.0956 27.658 29.1565Z" fill="#202020"/>' &&
'<path d="M39.5 38C39.5 38 37.0376 40 34 40C30.9624 40 28.5 38 28.5 38" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'</g>' &&
'<defs>' &&
'<filter id="filter0_d_2633_7020" x="0.5" y="0" width="66" height="66" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">' &&
'<feFlood flood-opacity="0" result="BackgroundImageFix"/>' &&
'<feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>' &&
'<feOffset/>' &&
'<feGaussianBlur stdDeviation="3.5"/>' &&
'<feComposite in2="hardAlpha" operator="out"/>' &&
'<feColorMatrix type="matrix" values="0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0.25 0"/>' &&
'<feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_2633_7020"/>' &&
'<feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_2633_7020" result="shape"/>' &&
'</filter>' &&
'</defs>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = good
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = good.
    good = 'data:image/svg+xml;base64,' && good.

    good_sel =
'<svg width="53" height="52" viewBox="0 0 53 52" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" fill="white"/>' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" stroke="#10233E" stroke-width="2"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 41.5 11)" fill="#8FC36F"/>' &&
'<path d="M32.342 22.1565C32.342 23.2175 31.4819 24.0775 30.421 24.0775C29.3601 24.0775 28.5 23.2175 28.5 22.1565C28.5 21.0956' &&
' 29.3601 20.2356 30.421 20.2356C31.4819 20.2356 32.342 21.0956 32.342 22.1565Z" fill="#202020"/>' &&
'<path d="M20.658 22.1565C20.658 23.2175 21.5181 24.0775 22.579 24.0775C23.6399 24.0775 24.5 23.2175 24.5 22.1565C24.5 21.0956' &&
' 23.6399 20.2356 22.579 20.2356C21.5181 20.2356 20.658 21.0956 20.658 22.1565Z" fill="#202020"/>' &&
'<path d="M32.5 31C32.5 31 30.0376 33 27 33C23.9624 33 21.5 31 21.5 31" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = good_sel
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = good_sel.
    good_sel = 'data:image/svg+xml;base64,' && good_sel.

    average =
'<svg width="67" height="66" viewBox="0 0 67 66" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<g filter="url(#filter0_d_2633_6996)">' &&
'<rect width="52" height="52" rx="8" transform="matrix(-1 0 0 1 59.5 7)" fill="white" shape-rendering="crispEdges"/>' &&
'<rect x="-0.5" y="0.5" width="51" height="51" rx="7.5" transform="matrix(-1 0 0 1 58.5 7)" stroke="#E6E6E6" shape-rendering="crispEdges"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 48.5 18)" fill="#FFB648"/>' &&
'<path d="M28 38C28 38 30.4625 38 33.5 38C36.5375 38 38.9998 38 38.9998 38" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'<circle cx="28.5" cy="29" r="2" fill="#202020"/>' &&
'<circle cx="38.5" cy="29" r="2" fill="#202020"/>' &&
'</g>' &&
'<defs>' &&
'<filter id="filter0_d_2633_6996" x="0.5" y="0" width="66" height="66" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">' &&
'<feFlood flood-opacity="0" result="BackgroundImageFix"/>' &&
'<feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>' &&
'<feOffset/>' &&
'<feGaussianBlur stdDeviation="3.5"/>' &&
'<feComposite in2="hardAlpha" operator="out"/>' &&
'<feColorMatrix type="matrix" values="0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0.25 0"/>' &&
'<feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_2633_6996"/>' &&
'<feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_2633_6996" result="shape"/>' &&
'</filter>' &&
'</defs>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = average
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = average.
    average = 'data:image/svg+xml;base64,' && average.

    average_sel =
'<svg width="53" height="52" viewBox="0 0 53 52" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" fill="white"/>' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" stroke="#10233E" stroke-width="2"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 41.5 11)" fill="#FFB648"/>' &&
'<path d="M21 31C21 31 23.4625 31 26.5 31C29.5375 31 31.9998 31 31.9998 31" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'<circle cx="21.5" cy="22" r="2" fill="#202020"/>' &&
'<circle cx="31.5" cy="22" r="2" fill="#202020"/>' &&
'</svg>'.

    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = average_sel
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = average_sel.
    average_sel = 'data:image/svg+xml;base64,' && average_sel.

    poor =
'<svg width="67" height="66" viewBox="0 0 67 66" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<g filter="url(#filter0_d_2633_6962)">' &&
'<rect width="52" height="52" rx="8" transform="matrix(-1 0 0 1 59.5 7)" fill="white" shape-rendering="crispEdges"/>' &&
'<rect x="-0.5" y="0.5" width="51" height="51" rx="7.5" transform="matrix(-1 0 0 1 58.5 7)" stroke="#E6E6E6" shape-rendering="crispEdges"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 48.5 18)" fill="#FF6B00"/>' &&
'<path d="M39.342 29.1565C39.342 30.2175 38.4819 31.0775 37.421 31.0775C36.3601 31.0775 35.5 30.2175 35.5 29.1565C35.5 28.0956' &&
' 36.3601 27.2356 37.421 27.2356C38.4819 27.2356 39.342 28.0956 39.342 29.1565Z" fill="#202020"/>' &&
'<path d="M27.658 29.1565C27.658 30.2175 28.5181 31.0775 29.579 31.0775C30.6399 31.0775 31.5 30.2175 31.5 29.1565C31.5 28.0956' &&
' 30.6399 27.2356 29.579 27.2356C28.5181 27.2356 27.658 28.0956 27.658 29.1565Z" fill="#202020"/>' &&
'<path d="M28.5 39C28.5 39 30.9624 37 34 37C37.0376 37 39.5 39 39.5 39" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'</g>' &&
'<defs>' &&
'<filter id="filter0_d_2633_6962" x="0.5" y="0" width="66" height="66" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">' &&
'<feFlood flood-opacity="0" result="BackgroundImageFix"/>' &&
'<feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>' &&
'<feOffset/>' &&
'<feGaussianBlur stdDeviation="3.5"/>' &&
'<feComposite in2="hardAlpha" operator="out"/>' &&
'<feColorMatrix type="matrix" values="0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0.25 0"/>' &&
'<feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_2633_6962"/>' &&
'<feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_2633_6962" result="shape"/>' &&
'</filter>' &&
'</defs>' &&
'</svg>'.

    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = poor
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = poor.
    poor = 'data:image/svg+xml;base64,' && poor.

    poor_sel =
'<svg width="53" height="52" viewBox="0 0 53 52" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" fill="white"/>' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" stroke="#10233E" stroke-width="2"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 41.5 11)" fill="#FF6B00"/>' &&
'<path d="M32.342 22.1565C32.342 23.2175 31.4819 24.0775 30.421 24.0775C29.3601 24.0775 28.5 23.2175 28.5 22.1565C28.5' &&
' 21.0956 29.3601 20.2356 30.421 20.2356C31.4819 20.2356 32.342 21.0956 32.342 22.1565Z" fill="#202020"/>' &&
'<path d="M20.658 22.1565C20.658 23.2175 21.5181 24.0775 22.579 24.0775C23.6399 24.0775 24.5 23.2175 24.5 22.1565C24.5' &&
' 21.0956 23.6399 20.2356 22.579 20.2356C21.5181 20.2356 20.658 21.0956 20.658 22.1565Z" fill="#202020"/>' &&
'<path d="M21.5 32C21.5 32 23.9624 30 27 30C30.0376 30 32.5 32 32.5 32" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = poor_sel
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = poor_sel.
    poor_sel = 'data:image/svg+xml;base64,' && poor_sel.

    verypoor =
'<svg width="67" height="66" viewBox="0 0 67 66" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<g filter="url(#filter0_d_2633_6915)">' &&
'<rect width="52" height="52" rx="8" transform="matrix(-1 0 0 1 59.5 7)" fill="white" shape-rendering="crispEdges"/>' &&
'<rect x="-0.5" y="0.5" width="51" height="51" rx="7.5" transform="matrix(-1 0 0 1 58.5 7)" stroke="#E6E6E6" shape-rendering="crispEdges"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 48.5 18)" fill="#E53939"/>' &&
'<path fill-rule="evenodd" clip-rule="evenodd" d="M38.5232 27.583C38.6306 27.4337 39.0251 27.0506 39.4972 26.8299C39.7882 26.6939' &&
' 40.0827 26.5985 40.2889 26.5405C40.4326 26.5 40.5256 26.3552 40.4938 26.2093C40.4642 26.0736 40.3359 25.9823 40.1985 26.0029C38.4133' &&
' 26.2705 36.9645 27.0105 36.226 27.6524C36.0933 27.7579 35.9749 27.8807 35.8742 28.0172C35.8389 28.0635 35.8085 28.1086 35.7833' &&
' 28.1519C35.6036 28.4442 35.5 28.7883 35.5 29.1565C35.5 30.2175 36.3601 31.0775 37.421 31.0775C38.4819 31.0775 39.342 30.2175 39.342' &&
' 29.1565C39.342 28.5057 39.0183 27.9305 38.5232 27.583Z" fill="#202020"/>' &&
'<path fill-rule="evenodd" clip-rule="evenodd" d="M28.4768 27.583C28.3694 27.4337 27.9749 27.0506 27.5028 26.8299C27.2118 26.6939' &&
' 26.9173 26.5985 26.7111 26.5405C26.5674 26.5 26.4744 26.3552 26.5062 26.2093C26.5358 26.0736 26.6641 25.9823 26.8015 26.0029C28.5867' &&
' 26.2705 30.0355 27.0105 30.774 27.6524C30.9067 27.7579 31.0251 27.8807 31.1258 28.0172C31.1611 28.0635 31.1915 28.1086 31.2167' &&
' 28.1519C31.3964 28.4442 31.5 28.7883 31.5 29.1565C31.5 30.2175 30.6399 31.0775 29.579 31.0775C28.5181 31.0775 27.658 30.2175 27.658' &&
' 29.1565C27.658 28.5057 27.9817 27.9305 28.4768 27.583Z" fill="#202020"/>' &&
'<path d="M28.5 39C28.5 39 30.9624 36.5 34 36.5C37.0376 36.5 39.5 39 39.5 39" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'</g>' &&
'<defs>' &&
'<filter id="filter0_d_2633_6915" x="0.5" y="0" width="66" height="66" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">' &&
'<feFlood flood-opacity="0" result="BackgroundImageFix"/>' &&
'<feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>' &&
'<feOffset/>' &&
'<feGaussianBlur stdDeviation="3.5"/>' &&
'<feComposite in2="hardAlpha" operator="out"/>' &&
'<feColorMatrix type="matrix" values="0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0 0.679167 0 0 0 0.25 0"/>' &&
'<feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_2633_6915"/>' &&
'<feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_2633_6915" result="shape"/>' &&
'</filter>' &&
'</defs>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = verypoor
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = verypoor.
    verypoor = 'data:image/svg+xml;base64,' && verypoor.

    verypoor_sel =
'<svg width="53" height="52" viewBox="0 0 53 52" fill="none" xmlns="http://www.w3.org/2000/svg">' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" fill="white"/>' &&
'<rect x="-1" y="1" width="50" height="50" rx="7" transform="matrix(-1 0 0 1 50.5 0)" stroke="#10233E" stroke-width="2"/>' &&
'<rect width="30" height="30" rx="15" transform="matrix(-1 0 0 1 41.5 11)" fill="#E53939"/>' &&
'<path fill-rule="evenodd" clip-rule="evenodd" d="M31.5232 20.583C31.6306 20.4337 32.0251 20.0506 32.4972 19.8299C32.7882' &&
' 19.6939 33.0827 19.5985 33.2889 19.5405C33.4326 19.5 33.5256 19.3552 33.4938 19.2093C33.4642 19.0736 33.3359 18.9823' &&
' 33.1985 19.0029C31.4133 19.2705 29.9645 20.0105 29.226 20.6524C29.0933 20.7579 28.9749 20.8807 28.8742 21.0172C28.8389' &&
' 21.0635 28.8085 21.1086 28.7833 21.1519C28.6036 21.4442 28.5 21.7883 28.5 22.1565C28.5 23.2175 29.3601 24.0775 30.421' &&
' 24.0775C31.4819 24.0775 32.342 23.2175 32.342 22.1565C32.342 21.5057 32.0183 20.9305 31.5232 20.583Z" fill="#202020"/>' &&
'<path fill-rule="evenodd" clip-rule="evenodd" d="M21.4768 20.583C21.3694 20.4337 20.9749 20.0506 20.5028 19.8299C20.2118' &&
' 19.6939 19.9173 19.5985 19.7111 19.5405C19.5674 19.5 19.4744 19.3552 19.5062 19.2093C19.5358 19.0736 19.6641 18.9823' &&
' 19.8015 19.0029C21.5867 19.2705 23.0355 20.0105 23.774 20.6524C23.9067 20.7579 24.0251 20.8807 24.1258 21.0172C24.1611' &&
' 21.0635 24.1915 21.1086 24.2167 21.1519C24.3964 21.4442 24.5 21.7883 24.5 22.1565C24.5 23.2175 23.6399 24.0775 22.579' &&
' 24.0775C21.5181 24.0775 20.658 23.2175 20.658 22.1565C20.658 21.5057 20.9817 20.9305 21.4768 20.583Z" fill="#202020"/>' &&
'<path d="M21.5 32C21.5 32 23.9624 29.5 27 29.5C30.0376 29.5 32.5 32 32.5 32" stroke="#202020" stroke-width="1.41994" stroke-linecap="round"/>' &&
'</svg>'.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = verypoor_sel
      IMPORTING
        buffer = xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = xstring
      IMPORTING
        output = verypoor_sel.
    verypoor_sel = 'data:image/svg+xml;base64,' && verypoor_sel.


    ev_css =
'.happyDialog { ' &&
'    width: clamp(20.5rem, 29.3125rem, 90svw); ' &&
'    padding: 0 !important; ' &&
'    border-radius: 0.5rem; ' &&
'    border: 1px solid var(--Gray3); ' &&
'    background: #FFF; ' &&
'    box-shadow: 0px 0px 12.3px 0px rgba(0, 0, 0, 0.11); ' &&
'} ' &&

'.happyDialog-outer-cont { ' &&
'    width: clamp(20.5rem, 29.3125rem, 90svw); ' &&
'    display: flex; ' &&
'    padding: 1.25rem 1.5rem; ' &&
'    flex-direction: column; ' &&
'    align-items: center; ' &&
'    gap: 1.5rem; ' &&
'} ' &&

'.happyDialog-main-cont { ' &&
'    display: flex; ' &&
'    flex-direction: column; ' &&
'    align-items: center; ' &&
'    gap: 1rem; ' &&
'    align-self: stretch; ' &&
'} ' &&

'.happyDialog-header-hbox-desktop { ' &&
'    display: flex; ' &&
'    justify-content: space-between; ' &&
'    align-items: center; ' &&
'    align-self: stretch; ' &&
'} ' &&

'.happyDialog-header-vbox-mobile { ' &&
'    display: none; ' &&
'} ' &&

'.happyDialog-align-center { ' &&
'    text-align: center !important; ' &&
'} ' &&

'.happyDialog-images-hbox { ' &&
'    display: flex; ' &&
'    align-items: flex-start; ' &&
'    gap: 0.75rem; ' &&
'} ' &&

'.happyDialog-image-vbox { ' &&
'    display: flex; ' &&
'    width: 4.25rem; ' &&
'    flex-direction: column; ' &&
'    align-items: center; ' &&
'    gap: 0.375rem; ' &&
'} ' &&

'.happyDialog-image-hbox { ' &&
'    display: flex; ' &&
'    width: 3.25rem; ' &&
'    height: 3.25rem; ' &&
'    justify-content: center; ' &&
'    align-items: center; ' &&
'    border-radius: 0.5rem; ' &&
'} ' &&

'.happyDialog-rate-txt[data-text-selected="X"] { ' &&
'    font-weight: 500; ' &&
'} ' &&

'.happyDialog-image-hbox .sapMImgFocusable:focus { ' &&
'    outline: none; ' &&
'} ' &&

'.happyDialog-textarea-vbox { ' &&
'    display: flex; ' &&
'    flex-direction: column; ' &&
'    align-items: flex-start; ' &&
'    gap: 0.4375rem; ' &&
'    align-self: stretch; ' &&
'} ' &&

'.happyDialog-textarea-inner-vbox { ' &&
'    display: flex; ' &&
'    flex-direction: column; ' &&
'    align-items: flex-end; ' &&
'    gap: 0.25rem; ' &&
'    align-self: stretch; ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMTextArea { ' &&
'    border: none; ' &&
'    width: 100%; ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMTextArea .sapMInputBaseContentWrapper { ' &&
'    height: 3rem; ' &&
'    min-width: 10rem; ' &&
'    width: 100%; ' &&
'    padding: 0.75rem 0.9375rem; ' &&
'    flex: 1 0 0; ' &&
'    border-radius: 0.375rem; ' &&
'    border: 1px solid var(--Gray3); ' &&
'    background: var(--White); ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMTextArea .sapMInputBaseInner { ' &&
'    padding: 0; ' &&
'    outline: none; ' &&
'    color: var(--Dark-Blue); ' &&

'    /* Body 2_3 - 14PX Regular */ ' &&
'    font-family: var(--fontname); ' &&
'    font-size: 0.875rem; ' &&
'    font-style: normal; ' &&
'    font-weight: 400; ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMTextArea .sapMInputBaseInner:lang(ar) { ' &&
'    line-height: 1.5rem; /* 24px converted to rems */ ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMTextArea .sapMInputBaseInner::placeholder { ' &&
'    color: var(--Gray5); ' &&

'    /* Body 2_3 - 14PX Regular */ ' &&
'    font-family: var(--fontname); ' &&
'    font-size: 0.875rem; ' &&
'    font-style: normal; ' &&
'    font-weight: 400; ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMTextArea .sapMInputBaseInner::placeholder:lang(ar) { ' &&
'    line-height: 1.5rem; /* 24px converted to rems */ ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase:not(.sapMFocus) .sapMInputBaseContentWrapper:not(.sapMInputBaseReadonlyWrapper):not(.sapMInputBaseContentWrapperState):not(.sapMInputBaseDisabledWrapper):hover { ' &&
'    background: none; ' &&
'    background-color: #fff; ' &&
'    border-color: var(--Gray3); ' &&
'    box-shadow: none; ' &&
'} ' &&

'.happyDialog-textarea.sapMFocus:not(.sapMInputBaseReadonly):not(.sapMInputBaseContentWrapperState):not(.sapMInputBaseDisabled):hover { ' &&
'    border-color: var(--Dark-Blue); ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBase.sapMFocus .sapMInputBaseContentWrapper:hover:not(.sapMInputBaseReadonlyWrapper):not(.sapMInputBaseContentWrapperState):not(.sapMInputBaseDisabledWrapper) { ' &&
'    border-color: var(--Dark-Blue); ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBaseContentWrapper:hover:not(.sapMInputBaseContentWrapperState):not(.sapMInputBaseDisabledWrapper):not(.sapMInputBaseReadonlyWrapper) { ' &&
'    border-color: var(--Gray3); ' &&
'} ' &&

'.happyDialog-textarea.sapMInputBaseContentWrapper:not(.sapMInputBaseReadonlyWrapper):not(.sapMInputBaseContentWrapperState):not(.sapMInputBaseDisabledWrapper):hover { ' &&
'    border-color: var(--Gray3); ' &&
'} ' &&

'.happyDialog-footer { ' &&
'    justify-content: flex-end; ' &&
'    align-items: flex-end; ' &&
'    align-self: stretch; ' &&
'} ' &&

'.happyDialog-radio.sapMRb{ ' &&
'	height: 4rem; ' &&
'    width: 4rem; ' &&
'	background-position: center; ' &&
'	background-repeat: no-repeat; ' &&
'} ' &&
'.happyDialog-radio .sapMRbSvg{ ' &&
'	visibility: hidden; ' &&
'} ' &&
'.happyDialog-radio.sapMRb:focus:before { ' &&
'    border: unset; ' &&
'} ' &&
'.happyDialog-radio-Excellent.sapMRb{ ' &&
'	background-image: url("' && excellent && '"); ' &&
'} ' &&
'.happyDialog-radio-Excellent.sapMRbSel{ ' &&
'  background-image: url("' && excellent_sel && '"); ' &&
'} ' &&
'.happyDialog-radio-Good.sapMRb{ ' &&
'	background-image: url("' && good && '"); ' &&
'} ' &&
'.happyDialog-radio-Good.sapMRbSel{ ' &&
'  background-image: url("' && good_sel && '"); ' &&
'} ' &&
'.happyDialog-radio-Average.sapMRb{ ' &&
'	background-image: url("' && average && '"); ' &&
'} ' &&
'.happyDialog-radio-Average.sapMRbSel{ ' &&
'  background-image: url("' && average_sel && '"); ' &&
'} ' &&
'.happyDialog-radio-Poor.sapMRb{ ' &&
'	background-image: url("' && poor && '"); ' &&
'} ' &&
'.happyDialog-radio-Poor.sapMRbSel{ ' &&
'  background-image: url("' && poor_sel && '"); ' &&
'} ' &&
'.happyDialog-radio-VeryPoor.sapMRb{ ' &&
'	background-image: url("' && verypoor && '"); ' &&
'} ' &&
'.happyDialog-radio-VeryPoor.sapMRbSel{ ' &&
'  background-image: url("' && verypoor_sel && '"); ' &&
'} ' &&

'/* mobile screens up to 900px  */ ' &&
'@media only screen and (max-width: 900px) { ' &&

'    .happyDialog-outer-cont { ' &&
'        padding: 1rem; ' &&
'    } ' &&

'    .happyDialog-header-hbox-desktop { ' &&
'        display: none; ' &&
'    } ' &&

'    .happyDialog-header-vbox-mobile { ' &&
'        display: flex; ' &&
'        flex-direction: column; ' &&
'        align-items: flex-end; ' &&
'        gap: 0.25rem; ' &&
'        align-self: stretch; ' &&
'    } ' &&

'    .happyDialog-header-text-hbox-mobile { ' &&
'        display: flex; ' &&
'        justify-content: center; ' &&
'        align-items: flex-start; ' &&
'        align-self: stretch; ' &&
'    } ' &&

'    .happyDialog-images-hbox { ' &&
'        gap: 0.5625rem; ' &&
'    } ' &&

'    .happyDialog-image-vbox { ' &&
'        display: flex; ' &&
'        width: 3.25rem; ' &&
'        height: 3.25rem; ' &&
'        flex-direction: column; ' &&
'        align-items: center; ' &&
'        justify-content: center; ' &&
'    } ' &&

'    .happyDialog-footer .regularBTN { ' &&
'    	width: 100%; ' &&
'    } ' &&

'}     '.

    me->add_style( ev_css ).
    me->functions_to_front( ).
  ENDMETHOD.


  METHOD rakhappy_save.

    DATA:lv_username     TYPE string,
         ls_feedback     TYPE zdt_hm_feedback,
         lv_feedback     TYPE string,
         lv_departmentid TYPE string.

    ls_feedback-sessionid = NEW cl_random_number( )->if_random_number~get_random_int( i_limit = 1000000000 ).
    ls_feedback-casetype  = iv_case_type.
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
    ls_feedback-caseid    = iv_caseid.
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

    client->popover_destroy( ).
  ENDMETHOD.


  METHOD rakpay_css.
    ev_css =
'.payment-iframe{ ' &&
'	width:100%; ' &&
'	height:100%; ' &&
'	border:1px solid var(--Red); ' &&
'} ' &&

'.busyDialogPayment.sapMDialog{ ' &&
'	border-radius: 0 !important; ' &&
'} ' &&

'.busyDialogPayment .sapUiLocalBusyIndicatorAnimation>div::before { ' &&
'    background: var(--Red); ' &&
'} ' &&

'.busyDialogPayment .sapMLabel.sapMBusyDialogLabel{ ' &&
'	 font-family: var(--fontname); ' &&
'} ' &&
'.payDialogBorderTopGray.sapMDialog{ ' &&
'	border-top: 0.5rem solid var(--Gray4) !important; ' &&
'} ' &&

'.payDialogBorderTopGreen.sapMDialog{ ' &&
'	border-top: 0.5rem solid var(--Green) !important; ' &&
'} ' &&
'.payDialogBorderTopRed.sapMDialog{ ' &&
'	border-top: 0.5rem solid var(--Red) !important; ' &&
'} ' &&

'.payDialog-busy-hbox .sapUiLocalBusyIndicatorAnimation { ' &&
'	background: var(--White); ' &&
'} ' &&
'/* used to hide fields according to pay (generic pay)/initial fees/final fees */ ' &&
'.RAKEGA-pay-pay .RAKEGA-pay-hide-in-pay { ' &&
'    display: none; ' &&
'} ' &&

'.RAKEGA-pay-initial .RAKEGA-pay-hide-in-initial { ' &&
'    display: none; ' &&
'} ' &&

'.RAKEGA-pay-final .RAKEGA-pay-hide-in-final { ' &&
'    display: none; ' &&
'} ' &&

'.RAKEGA-pay-pay .RAKEGA-footer { ' &&
'    justify-content: flex-end; ' &&
'} ' &&

'.RAKEGA-pay-payment-container { ' &&
'    width: 100%; ' &&
'    gap: 2rem; ' &&
'} ' &&

'.RAKEGA-pay-fees-vbox { ' &&
'    width: 100%; ' &&
'    gap: 0.75rem; ' &&
'} ' &&

'.RAKEGA-pay-fees-inner-vbox { ' &&
'    width: 100%; ' &&
'    gap: 0.625rem; ' &&
'} ' &&

'.RAKEGA-pay-total-hbox { ' &&
'    width: 100%; ' &&
'    justify-content: space-between; ' &&
'    align-items: center; ' &&
'} ' &&

'.RAKEGA-pay-cantdo-icon { ' &&
'    font-size: 1.5rem; ' &&
'    color: var(--Red); ' &&
'} ' &&

'.RAKEGA-pay-payment-vbox { ' &&
'    width: 100%; ' &&
'    gap: 1rem; ' &&
'} ' &&

'.RAKEGA-pay-payment-method-cont { ' &&
'    width: 100%; ' &&
'   gap: 0.75rem; ' &&
'} ' &&

'.RAKEGA-pay-please1 { ' &&
'    gap: 0.5rem; ' &&
'    align-items: center; ' &&
'    flex-wrap: nowrap; ' &&
'} ' &&

'.RAKEGA-pay-please-hbox { ' &&
'    min-width: 15rem; ' &&
'    justify-self: stretch; ' &&
'} ' &&

'.RAKEGA-pay-method2-cont { ' &&
'    padding: 0.9375rem 1.5625rem; ' &&
'    align-items: flex-start; ' &&
'    gap: 1rem; ' &&
'    width: 100%; ' &&
'    /*max-width: 58.375rem;*/ ' &&
'    border-radius: 0.375rem; ' &&
'    background: var(--Gray0); ' &&
'} ' &&

'.RAKEGA-pay-account-details-cont { ' &&
'    align-items: flex-start; ' &&
'    gap: 0.5rem; ' &&
'    align-self: stretch; ' &&
'} ' &&

'.RAKEGA-pay-account-details-hbox { ' &&
'    width: 100%; ' &&
'    align-items: flex-start; ' &&
'    gap: 1.5rem; ' &&
'} ' &&

'.RAKEGA-pay-account-number { ' &&
'    align-items: flex-start; ' &&
'    gap: 0.1875rem; ' &&
'} ' &&

'.RAKEGA-pay-service-details-cont { ' &&
'    justify-content: space-between; ' &&
'    align-items: center; ' &&
'    align-content: center; ' &&
'    gap: 1rem; ' &&
'    align-self: stretch; ' &&
'    flex-wrap: wrap; ' &&
'} ' &&

'.RAKEGA-pay-please2 { ' &&
'    min-width: 15rem; ' &&
'    align-items: center; ' &&
'    gap: 0.625rem; ' &&
'    flex: 1 0 0; ' &&
'    flex-wrap: nowrap; ' &&
'} ' &&

'.RAKEGA-pay-paywith-cont { ' &&
'    align-items: flex-start; ' &&
'    align-content: flex-start; ' &&
'    gap: 0.625rem; ' &&
'} ' &&

'.RAKEGA-pay-pw-rbline { ' &&
'    align-items: flex-start; ' &&
'    align-content: flex-start; ' &&
'    gap: 1.25rem; ' &&
'} ' &&

'.RAKEGA-pay-pw-hbox { ' &&
'    height: 3.0625rem; ' &&
'    width: 16.125rem; ' &&
'    padding: 0 1rem; ' &&
'    align-items: center; ' &&
'    gap: 0.8125rem; ' &&
'    border-radius: 0.375rem; ' &&
'    border: 1px solid var(--Gray3); ' &&
'    background: var(--White); ' &&
'} ' &&

'.RAKEGA-pay-pw-images1 { ' &&
'    width: 12.25rem; ' &&
'    height: 1.613rem; ' &&
'    justify-content: space-between; ' &&
'    align-items: center; ' &&
'} ' &&

'/* RAKEGA-pay-radio-button */ ' &&

'.RAKEGA-pay-radio-button.sapMRb { ' &&
'    width: 0.875rem !important; ' &&
'    height: 0.875rem !important; ' &&
'    float: left; ' &&
'    clear: left; ' &&
'    outline: none; ' &&
'    overflow: visible; ' &&
'    text-overflow: ellipsis; ' &&
'    position: relative; ' &&
'    white-space: nowrap; ' &&
'    max-width: 100%; ' &&
'    display: flex; ' &&
'    align-items: center; ' &&
'    background: var(--White, #FFF); ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb .sapMRbB .sapMRbBOut { ' &&
'    height: 100%; ' &&
'    width: 100%; ' &&
'    translate: -35% -35%; ' &&
'    /*margin: 0.825rem;*/ ' &&
'    margin: 0; ' &&
'    padding: 1px; ' &&
'    stroke: var(--Primary-Red, #BF1313); ' &&
'    fill: #fff; ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb .sapMRbBOut { ' &&
'    stroke-width: 1px !important; ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb .sapMRbBOut:disabled { ' &&
'    stroke-width: 1px !important; ' &&
'    stroke: black; ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRbSel .sapMRbBInn { ' &&
'    translate: -35% -35%; ' &&
'    fill: var(--Red); ' &&
'    stroke: none; ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb:focus:before { ' &&
'    border: none; ' &&
'} ' &&

'.RAKEGA-pay-radio-button .sapMRbSvg { ' &&
'    height: 0.875rem; ' &&
'    width: 0.875rem; ' &&
'    /*margin: 0.575rem;*/ ' &&
'    margin: 0; ' &&
'    overflow: visible; ' &&
'} ' &&


'.RAKEGA-pay-radio-button .sapMRbBLabel { ' &&
'    vertical-align: top; ' &&
'    /*height: 2.5rem;*/ ' &&
'    height: 0; ' &&
'    width: 0; ' &&
'    /*line-height: 2.5rem;*/ ' &&
'    cursor: default; ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb .sapMRbB { ' &&
'    /*height: 2.5rem;*/ ' &&
'    /*width: 2.5rem;*/ ' &&
'    height: 0.875rem; ' &&
'    width: 0.875rem; ' &&
'    display: inline-block; ' &&
'    font-size: 1rem; ' &&
'} ' &&

'/*LABEL*/ ' &&
'.RAKEGA-pay-radio-button .sapMLabel { ' &&
'    color: var(--Dark-Blue); ' &&
'    font-size: .875rem; ' &&
'    font-family: var(--fontname); ' &&
'    font-weight: 400; ' &&
'    display: inline-block; ' &&
'    white-space: nowrap; ' &&
'    cursor: text; ' &&
'    overflow: hidden; ' &&
'} ' &&

'/*HOVER */ ' &&
'.RAKEGA-pay-radio-button.sapMRb:not(.sapMRbDis):hover { ' &&
'    cursor: pointer; ' &&
'    background: var(--Gray0); ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb:not(.sapMRbErr):not(.sapMRbWarn):not(.sapMRbInfo):not(.sapMRbSucc) .sapMRbHoverable:hover .sapMRbBOut { ' &&
'    stroke: var(--Red); ' &&
'    fill: #fff; ' &&
'} ' &&

'/* DISABELED */ ' &&
'.RAKEGA-pay-radio-button.sapMRb.sapMRbDis { ' &&
'    opacity: 1; ' &&
'    background: var(--Gray0); ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb.sapMRbDis .sapMLabel { ' &&
'    color: var(--Gray4); ' &&
'} ' &&

'.RAKEGA-pay-radio-button.sapMRb.sapMRbDis .sapMRbB .sapMRbBOut { ' &&
'    stroke: var(--Gray3); ' &&
'    fill: var(--Gray0); ' &&
'} ' &&



'/* not to wrap in desktop screen */ ' &&
'.RAKEGA-pay-payment-vbox .rbline { ' &&
'    flex-wrap: nowrap; ' &&
'} ' &&

'@media only screen and (max-width: 1366px) { ' &&

'    /* wrap in small screens */ ' &&
'    .RAKEGA-pay-payment-vbox .rbline { ' &&
'        flex-wrap: wrap !important; ' &&
'    } ' &&
'} ' &&

'.RAKEGA-pay-payment-vbox .radioButton.sapMRb { ' &&
'    height: 2.5rem !important; ' &&
'    float: left; ' &&
'    clear: left; ' &&
'    outline: none; ' &&
'    overflow: hidden; ' &&
'    text-overflow: ellipsis; ' &&
'    position: relative; ' &&
'    white-space: nowrap; ' &&
'    max-width: 100%; ' &&
'    display: flex; ' &&
'    align-items: center; ' &&
'    border-radius: 0.375rem; ' &&
'    border: 1px solid var(--Gray-3, #D1D5DB); ' &&
'    background: var(--White, #FFF); ' &&
'} ' &&

'/* increasing the radiobutton width in payment containers */ ' &&
'.RAKEGA-pay-payment-vbox .radioButton.sapMRb { ' &&
'    width: 16rem !important; ' &&
'    justify-content: flex-start; ' &&
'} ' &&


'/* end RAKEGA-pay-radio-button */ ' &&

'/* mobile screens up to 900px  */ ' &&
'@media only screen and (max-width: 900px) { ' &&

'    .RAKEGA-pay-payment-container { ' &&
'        gap: 1.5rem; ' &&
'    } ' &&

'    .RAKEGA-pay-fees-vbox { ' &&
'        gap: 0.9375rem; ' &&
'    } ' &&

'    .RAKEGA-pay-total-hbox { ' &&
'        justify-content: flex-end; ' &&
'    } ' &&

'    /* increasing the radiobutton width in payment containers for small screens */ ' &&
'    .RAKEGA-pay-payment-vbox .radioButton.sapMRb { ' &&
'        width: 20.5rem !important; ' &&
'    } ' &&

'    .RAKEGA-pay-pw-hbox { ' &&
'        width: 20.5rem; ' &&
'    } ' &&
'}' &&
'/* fees list */' &&

'.feesDialog-list-container {' &&
'    width: 100%;' &&
'}' &&

'.feesDialog-list-item {' &&
'    width: 100%;' &&
'    align-items: center;' &&
'    justify-content: space-between;' &&
'    padding: 0.75rem 0rem;' &&
'    border-bottom: 1px solid var(--Gray2);' &&
'}' &&

'.feesDialog-list-description-container {' &&
'	width: 65%;' &&
'}' &&

'.feesDialog-list-amount-container {' &&
'	min-width: 4.625rem;' &&
'    /*max-width: 20%;*/' &&
'}'.


    me->add_style( ev_css ).
  ENDMETHOD.


  METHOD rakstagebar_css.
    ev_css =

'.rak-stagebar-margin { ' &&
'    margin-top: 1.5rem; ' &&
'} ' &&

'.rak-stagebar-step-cont { ' &&
'    gap: 0.375rem; ' &&
'} ' &&

'.rak-stagebar-circle-cont { ' &&
'    width: 1.875rem; ' &&
'    height: 1.875rem; ' &&
'    justify-content: center; ' &&
'    align-items: center; ' &&
'    flex-shrink: 0; ' &&
'   border-radius: 2.9375rem; ' &&
'} ' &&

'.rak-stagebar-circle-cont.rak-stagebar-circle-red { ' &&
'    border: 1px solid var(--Red); ' &&
'    background: var(--Gradient, linear-gradient(100deg, #EB3642 -17.3%, #990808 120.1%)); ' &&
'} ' &&

'.rak-stagebar-circle-cont.rak-stagebar-circle-green { ' &&
'    border: 1px solid var(--Green); ' &&
'    background: var(--Soft-Green); ' &&
'} ' &&

'.rak-stagebar-step-done-icon { ' &&
'    color: var(--Green); ' &&
'} ' &&

'html[dir=rtl] .rak-stagebar-step-done-icon.sapUiIconMirrorInRTL:not(.sapUiIconSuppressMirrorInRTL)::before, ' &&
'html[dir=rtl] .rak-stagebar-step-done-icon.sapUiIconMirrorInRTL:not(.sapUiIconSuppressMirrorInRTL)::after { ' &&
'    transform: scale(1, 1); ' &&
'    webkit-transform: scale(1, 1); ' &&
'} ' &&

'.rak-stagebar-circle-cont.rak-stagebar-circle-gray { ' &&
'    border: 1px solid var(--Gray4); ' &&
'    background: var(--Gray1); ' &&
'} ' &&

'.rak-stagebar-line-gray3 { ' &&
'    border-bottom: 1px solid var(--Gray3); ' &&
'} ' &&

'.rak-stagebar-line-green { ' &&
'    border-bottom: 1px solid var(--Green); ' &&
'} ' &&

'.rak-stagebar-text-align-desktop { ' &&
'	text-align: center !important; ' &&
'} ' &&

'.rak-stagebar-progress-indicator.sapMPIDisplayOnly:not(.sapMPIBarDisabled) .sapMPIBarNeutral { ' &&
'	background: var(--Gradient-Red); ' &&
'} ' &&

'.rak-stagebar-progress-indicator.sapMPI.sapMPIDisplayOnly { ' &&
'	min-height: 0; ' &&
'} ' &&

'.rak-stagebar-progress-indicator .sapMPIBarRemaining { ' &&
'	background: var(--Gray2); ' &&
'	border: none; ' &&
'} ' &&

'/* mobile screens up to 900px  */ ' &&
'@media only screen and (max-width: 900px) { ' &&

'    .rak-stagebar-margin { ' &&
'        margin-top: 0.75rem; ' &&
'    } ' &&
'}'.
    me->add_style( ev_css ).
    me->functions_to_front( ).
  ENDMETHOD.


  method RAKUPLOADER_CSS.
    ev_css =
'/*RAK_UPLOADER FRG*/ ' &&
'.rakuploader-hbox { ' &&
'    box-sizing: border-box; ' &&
'    width: 20.5rem !important; ' &&
'    height: 2.6875rem; ' &&
'    min-width: 12.5rem; ' &&
'    padding: 0.6875rem 0rem 0.6875rem 0.9375rem; ' &&
'    padding-inline-start: 0.9375rem; ' &&
'    padding-inline-end: 0; ' &&
'    justify-content: space-between; ' &&
'    align-items: center; ' &&
'    gap: 0.625rem; ' &&
'    border-radius: 0.375rem; ' &&
'    border: 1px solid var(--Gray3); ' &&
'    background: var(--White); ' &&
'} ' &&

'.rakuploader-uploader-hbox { ' &&
'    box-sizing: border-box; ' &&
'    width: 2.6875rem; ' &&
'    height: 2.6875rem; ' &&
'    padding: 0.5625rem; ' &&
'    justify-content: center; ' &&
'    align-items: center; ' &&
'    flex-shrink: 0; ' &&
'    border-inline-start: 1px solid var(--Gray3); ' &&
'} ' &&

'.rakuploader-animate-progress { ' &&
'    height: 1rem; ' &&
'    animation-name: animateupload; ' &&
'    animation-duration: 2s; ' &&
'    animation-iteration-count: infinite; ' &&
'    animation-timing-function: linear; ' &&
'} ' &&

'@keyframes animateupload { ' &&
'    from { ' &&
'        transform: rotate(0deg); ' &&
'    } ' &&

'    to { ' &&
'        transform: rotate(360deg); ' &&
'    } ' &&
'} ' &&

'.rakuploader-previewlink { ' &&
'    color: var(--Gray6); ' &&
'    font-family: var(--fontname); ' &&
'    font-size: 0.875rem; ' &&
'    font-style: normal; ' &&
'    font-weight: 400; ' &&
'    text-decoration-line: underline; ' &&
'} ' &&

'.FileUploader .sapMBtnInner { ' &&
'    color: var(--Dark-Blue); ' &&
'    border: none; ' &&
'    background: unset; ' &&
'    /*display: none;*/ ' &&
'} ' &&

'.FileUploader .sapUiFup:hover .sapMBtnHoverable { ' &&
'    background-image: none; ' &&
'    background-color: unset !important; ' &&
'} ' &&

'.FileUploader.sapUiFup:hover .sapMBtnHoverable { ' &&
'    background-image: none; ' &&
'    background-color: transparent; ' &&
'} ' &&

'.FileUploader .sapMBtnInner, .sapMTB-Transparent-CTX .sapUiFup .sapMBtnInner:active,  ' &&
'.sapUiFup .sapMBtnTransparent.sapMBtnHoverable:active,  ' &&
'.sapMTB-Transparent-CTX .sapUiFup .sapMBtnTransparent.sapMBtnHoverable:active,  ' &&
'.sapUiFup .sapMBtnInner:active.sapMBtnTransparent.sapMBtnHoverable:not(.sapMToggleBtnPressed):not(.sapMBtnEmphasized):not(.sapMBtnAccept):not(.sapMBtnReject):not(.sapMBtnActive),  ' &&
'.sapMTB-Transparent-CTX .sapUiFup .sapMBtnInner:active.sapMBtnTransparent.sapMBtnHoverable:not(.sapMToggleBtnPressed):not(.sapMBtnEmphasized):not(.sapMBtnAccept):not(.sapMBtnReject):not(.sapMBtnActive) { ' &&
'    background-color: transparent !important; ' &&
'    border-color: none; ' &&
'} ' &&

'.FileUploader .sapMBtnIcon { ' &&
'    color: var(--Dark-Blue) !important; ' &&
'    font-size: 1.25rem; ' &&
'    line-height: 2.625rem; ' &&
'} ' &&

'.FileUploader .sapMBtn .sapMBtnBase { ' &&
'    background-color: unset !important; ' &&
'} ' &&

'.errorText { ' &&
'    background: #ffebeb; ' &&
'    color: #32363a; ' &&
'    font-size: .75rem; ' &&
'    font-family: "72", "72full", Arial, Helvetica, sans-serif; ' &&
'    padding: 0.3rem 0.625rem; ' &&
'    min-width: 6rem; ' &&
'} ' &&

'.uploaderErrorPos { ' &&
'    position: absolute; ' &&
'    top: 58px; ' &&
'} ' &&

'.brdrRed[data-upload="X"] { ' &&
'    border-color: var(--Bright-Red) !important; ' &&
'} ' &&

'.fileUploaderError { ' &&
'    margin: 0.25rem 0; ' &&
'} ' &&

'.fileUploaderError::before { ' &&
'    color: var(--Bright-Red); ' &&
'} ' &&

'@media only screen and (max-width: 900px) { ' &&
'	.NIOC .rakuploader-hbox { ' &&
'       width: 20.5rem; ' &&

'	} ' &&

'} '.


     me->add_style( ev_css ).
  endmethod.


  METHOD general_css.

*ev_css =
*'.RAKEGA-firstContainer { ' &&
*'    background: #F3F3F3; ' &&
*'    width: 100%; ' &&
*'    /* subtract header height */ ' &&
*'    min-height: calc(100svh - 3.125rem); ' &&
*'} ' &&
*
*'.RAKEGA-card { ' &&
*'    background: #FFF; ' &&
*'    width: clamp(22.5rem, 100%, 75rem); ' &&
*'    /* subtract header & footer height */ ' &&
*'    min-height: calc(100svh - 3.125rem - 3.75rem); ' &&
*'    margin: 0 auto; ' &&
*'    justify-content: flex-start; ' &&
*'} ' &&
*
*'.RAKEGA-card-top { ' &&
*'    padding: 3rem 3.75rem 0; ' &&
*'    width: 100%; ' &&
*'    justify-content: flex-start; ' &&
*'    /*align-items: flex-start;*/ ' &&
*'} ' &&
*
*'.RAKEGA-footer { ' &&
*'    border-inline-start: 1px solid var(--Grey3); ' &&
*'    background: var(--Gray2); ' &&
*'    width: clamp(22.5rem, 100%, 75rem); ' &&
*'    padding: 0 3.75rem; ' &&
*'    align-items: center; ' &&
*'    justify-content: space-between; ' &&
*'    margin: 0 auto; ' &&
*'    height: clamp(3.75rem, 3.75rem, 3.75rem); ' &&
*'} ' &&
*
*'.RAKEGA-next-btn-end { ' &&
*'    justify-content: end !important; ' &&
*'} ' &&
*
*'.RAKEGA-cardheader-vseparator { ' &&
*'    height: 1.125rem; ' &&
*'    width: 0.0625rem; ' &&
*'    background: #D9D9D9; ' &&
*'} ' &&
*
*'.RAKEGA-cardheader-topbtn .sapMBtnInner { ' &&
*'    color: var(--Dark-Blue) !important; ' &&
*'    background: transparent !important; ' &&
*'    border: none !important; ' &&
*'    font-family: var(--fontname); ' &&
*'    font-size: 1rem; ' &&
*'    font-style: normal; ' &&
*'    font-weight: 400; ' &&
*'    line-height: normal; ' &&
*'    padding: 0 0.25rem; ' &&
*'} ' &&
*
*'.RAKEGA-cardheader-topbtn.sapMBtn:hover>.sapMBtnHoverable.sapMBtnInner .sapMBtnContent { ' &&
*'    text-decoration: underline; ' &&
*'} ' &&
*
*'.RAKEGA-cardheader-topbtn .sapMBtnIcon { ' &&
*'    color: var(--Dark-Blue) !important; ' &&
*'} ' &&
*
*'.RAKEGA-card-descriptioncont { ' &&
*'    max-width: 55.125rem; ' &&
*'    align-items: flex-start; ' &&
*'} ' &&
*
*'.RAKEGA-card-descriptionpanel .sapMPanelContent { ' &&
*'    border: none; ' &&
*'} ' &&
*
*'.RAKEGA-card-descriptionpanel .sapMPanelWrappingDiv { ' &&
*'    border: none; ' &&
*'} ' &&
*
*'.RAKEGA-card-descriptionpanel .sapMPanelHdr { ' &&
*'    overflow: hidden; ' &&
*'    color: var(--Dark-Blue); ' &&
*'    text-overflow: ellipsis; ' &&
*'    font-family: var(--fontname); ' &&
*'    font-size: 1rem; ' &&
*'    font-style: normal; ' &&
*'    font-weight: 400; ' &&
*'} ' &&
*
*'.RAKEGA-card-descriptionpanel .sapMPanelWrappingDiv>.sapUiIcon { ' &&
*'    color: var(--Dark-Blue); ' &&
*'} ' &&
*
*'.RAKEGA-hide-in-desktop { ' &&
*'    display: none; ' &&
*'} ' &&
*
*'.RAKEGA-journey-municioality-image { ' &&
*'    background: url(Images/Extend_Land_Img.png), url(/sap/bc/ui5_ui5/sap/zRAKEGA/css/RAKEGA1120/Images/Extend_Land_Img.png); ' &&
*'    background-repeat: no-repeat; ' &&
*'    background-size: cover; ' &&
*'    width: 1.0625rem; ' &&
*'    height: 1.0625rem; ' &&
*'} ' &&
*
*'.RAKEGA-part2 { ' &&
*'    padding: 2rem 3.75rem 3rem; ' &&
*'    justify-content: flex-start; ' &&
*'    /*align-items: flex-start;*/ ' &&
*'} ' &&
*
*'/* Containing HBox for several RadioButtons */ ' &&
*'.rbline { ' &&
*'    gap: 1rem; ' &&
*'} ' &&
*
*'.toggle-line .toggle.sapMBtn { ' &&
*'    width: 7.625rem; ' &&
*'    min-width: 7.625rem; ' &&
*'} ' &&
*
*'.toggle-line .toggle .sapMBtnContent { ' &&
*'    top: 0rem; ' &&
*'} ' &&
*
*'.toggle-line .toggle-left-round-border .sapMBtnInner, ' &&
*'.toggle-line .toggle-right-round-border .sapMBtnInner, ' &&
*'.toggle-line .toggle-square-borders .sapMBtnInner { ' &&
*'    width: 7.625rem; ' &&
*'} ' &&
*
*'.part2-gap { ' &&
*'    gap: 2rem; ' &&
*'} ' &&
*
*'.gap-15 { ' &&
*'    gap: 1.5rem; ' &&
*'} ' &&
*
*'.gap-1 { ' &&
*'    gap: 1rem; ' &&
*'} ' &&
*
*'.gap-2 { ' &&
*'    gap: 2rem; ' &&
*'} ' &&
*
*'.gap-05 { ' &&
*'    gap: 0.5rem; ' &&
*'} ' &&
*
*'.gap-3 { ' &&
*'    gap: 3rem; ' &&
*'} ' &&
*
*'.gap0 { ' &&
*'    gap: 0 !important ' &&
*'} ' &&
*
*'.gap-062 { ' &&
*'    gap: 0.62rem; ' &&
*'} ' &&
*
*'.gap-075 { ' &&
*'    gap: 0.75rem; ' &&
*'} ' &&
*
*'.gap-02 { ' &&
*'    gap: 0.2rem; ' &&
*'} ' &&
*
*'.nca-min-height { ' &&
*'    min-height: 3rem; ' &&
*'} ' &&
*
*'/* mobile screens up to 900px  */ ' &&
*
*'@media only screen and (max-width: 900px) { ' &&
*
*'    .RAKEGA-card-top { ' &&
*'        padding: 1rem; ' &&
*'        border-bottom: 1px solid var(--Gray2); ' &&
*'        background: var(--Gray0); ' &&
*'    } ' &&
*
*'    .RAKEGA-footer { ' &&
*'        padding: 0 0.625rem; ' &&
*'    } ' &&
*
*
*'    .RAKEGA-part2 { ' &&
*'        padding: 1rem; ' &&
*'    } ' &&
*
*'    .RAKEGA-hide-in-desktop { ' &&
*'        display: unset; ' &&
*'    } ' &&
*
*'    .RAKEGA-hide-in-mobile { ' &&
*'        display: none !important; ' &&
*'    } ' &&
*
*'    .hide-in-mobile { ' &&
*'        visibility: hidden; ' &&
*'    } ' &&
*
*'    .width-100-mobile { ' &&
*'        width: 100%; ' &&
*'    } ' &&
*
*'    .gap-1-mobile { ' &&
*'        gap: 1rem; ' &&
*'    } ' &&
*
*'    .RAKEGA-cardheader-topbtn.sapMBtn, ' &&
*'    .RAKEGA-cardheader-topbtn .sapMBtnInner { ' &&
*'        height: 24px; ' &&
*'    } ' &&
*
*'    .RAKEGA-cardheader-topbtn .sapMBtnIcon { ' &&
*'        line-height: 14px; ' &&
*'    } ' &&
*
*'    .RAKEGA-cardheader { ' &&
*'        align-items: flex-start !important; ' &&
*'        flex-wrap: nowrap; ' &&
*'    } ' &&
*
*'    .RAKEGA-part2 .input.sapMInputBase, ' &&
*'    .RAKEGA-part2 .datepicker.sapMInputBase, ' &&
*'    .RAKEGA-part2 .datepicker .sapMInputBaseContentWrapper:not(.sapMInputBaseReadonlyWrapper):not(.sapMInputBaseContentWrapperState), ' &&
*'    .RAKEGA-part2 .datepicker .sapMInputBaseContentWrapperError { ' &&
*'        width: 20.5rem !important; ' &&
*'        max-width: 20.5rem !important; ' &&
*'    } ' &&
*
*
*'    .toggle-line { ' &&
*'        width: 20.5rem; ' &&
*'    } ' &&
*
*'    .toggle-line .toggle.sapMBtn { ' &&
*'        width: 50% !important; ' &&
*'    } ' &&
*
*'    .toggle-line .toggle-left-round-border .sapMBtnInner, ' &&
*'    .toggle-line .toggle-right-round-border .sapMBtnInner, ' &&
*'    .toggle-line .toggle-square-borders .sapMBtnInner { ' &&
*'        width: 100% !important; ' &&
*'    } ' &&
*
*'    .rbline { ' &&
*'        flex-direction: column; ' &&
*'        align-items: flex-start; ' &&
*'    } ' &&
*'} ' &&
*
*'@media only screen and (max-width: 500px) { ' &&
*
*'   .WV_Container .input.sapMInputBase, ' &&
*'    .WV_Container .datepicker.sapMInputBase, ' &&
*'    .WV_Container .datepicker .sapMInputBaseContentWrapper:not(.sapMInputBaseReadonlyWrapper):not(.sapMInputBaseContentWrapperState) { ' &&
*'        width: 100% !important; ' &&
*'        max-width: 100rem !important; ' &&
*'    } ' &&
*
*' .mobileFullWidth { ' &&
*'        width: 100% !important; ' &&
*'    } ' &&
*'}'.

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
          ftext     = ev_css
        TABLES
          ftext_tab = lt_file.

      CONDENSE ev_css.

    ENDIF.
    me->add_style( ev_css ).
    me->functions_to_front( ).
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
        parent->core_item( key = lv_key text = lv_value ).
        CLEAR: lv_key_found, lv_value_found, lv_key, lv_value.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
