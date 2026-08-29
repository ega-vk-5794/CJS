CLASS zcl_cj_demo_d011 DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_serializable_object .
    INTERFACES z2ui5_if_app .

    TYPES:
      BEGIN OF ty_s_tab,
        selkz            TYPE abap_bool,
        product          TYPE string,
        create_date      TYPE string,
        create_by        TYPE string,
        storage_location TYPE string,
        quantity         TYPE i,
      END OF ty_s_tab .
    TYPES:
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
    TYPES:
      tt_lic_no_list TYPE STANDARD TABLE OF ty_lic_no_list WITH DEFAULT KEY .

    TYPES: BEGIN OF ty_stages,
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
           END OF ty_stages,
           tt_stages TYPE STANDARD TABLE OF ty_stages WITH DEFAULT KEY.

    DATA:
      mt_table TYPE STANDARD TABLE OF ty_s_tab WITH EMPTY KEY .
    DATA mv_check_popover TYPE abap_bool .
    DATA mv_product TYPE string .
    DATA mt_licenses TYPE tt_lic_no_list .
    DATA gs_data TYPE zcl_ega_cj_dok_abs=>ty_data .
    DATA mt_stages TYPE tt_stages .

    METHODS set_data .
    METHODS view_display .
    METHODS popover_display
      IMPORTING
        !id TYPE string .
    METHODS screen_nd011_1_1 .
    METHODS screen_nd011_1_2 .
    METHODS get_licenses .
  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

private section.

  methods CHECK_LICENSE
    returning
      value(RESULT) type FLAG .
  methods CSS
    returning
      value(CSS) type STRING .
  methods READ_CASE
    importing
      value(IV_DRAFT) type ANY optional
      value(IV_CASE_ID) type ANY optional
      value(IV_LICENSE_NO) type ANY optional
    returning
      value(EV_FOUND) type FLAG .
  methods GET_TEXT_BY_ID
    importing
      !ID type ANY
    returning
      value(TEXT) type STRING .
  methods RAKSTAGEBAR
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_VIEW .
ENDCLASS.



CLASS ZCL_CJ_DEMO_D011 IMPLEMENTATION.


  METHOD check_license.

    DATA: message TYPE string.

    READ TABLE mt_licenses INTO DATA(ls_license) WITH KEY selkz = 'X'.
    IF sy-subrc EQ 0.
      IF ( sy-datum GT ls_license-recnendabs ).
        MESSAGE e100(slic) INTO message.
        client->message_box_display(
            text = message
            type = `error` ).
        result = abap_false.
        RETURN.
      ELSE.
        IF ( read_case( iv_license_no = ls_license-recnnr ) EQ abap_true ).
          result = abap_true.
        ENDIF.
      ENDIF.
    ELSE.
      MESSAGE e507(cpe) INTO message.
      client->message_box_display(
                  text = message
                  type = `error` ).

      result = abap_false.
      RETURN.
    ENDIF.


  ENDMETHOD.


  METHOD css.

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


  METHOD get_licenses.

    NEW zcl_dok_appln_handler_api( )->license_search(
    EXPORTING
    iv_case_type    = ''
    iv_bp_applicant = '1000116563'
  IMPORTING
    et_lic_no_list = DATA(lt_licenses) ).

    MOVE-CORRESPONDING lt_licenses TO mt_licenses.
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


  METHOD rakstagebar.


    APPEND INITIAL LINE TO mt_stages ASSIGNING FIELD-SYMBOL(<stage>).
    <stage>-stagenumber = '1'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagenumber = '2'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagenumber = '3'.
    APPEND INITIAL LINE TO mt_stages ASSIGNING <stage>.
    <stage>-stagenumber = '4'.

    EXIT.

    DATA(line) = io_parent->vbox( class = 'rak-stagebar-margin' width = '100%' id = 'id-rak-stagebar' rendertype = 'Bare' )->items( )->hbox(
     width = '100%' height = '10rem' rendertype = 'Bare' )->items( )->hbox(
     justifycontent = 'Start' alignitems = 'Start'  rendertype = 'Bare' )->items( client->_bind( val = mt_stages ) )->hbox(
     rendertype = 'Bare' )->items( )->vbox(
     width = '{STEPVBOXWIDTH}' justifycontent = 'Start' alignitems = 'Center  class = rak-stagebar-step-cont' rendertype = 'Bare' )->items( )->hbox(
     justifycontent = 'Start' alignitems = 'Start' rendertype = 'Bare' ).
    DATA(left_line) = line->items( )->hbox( width = '2.8125rem' height = '0.9375rem' rendertype = 'Bare' ).
    left_line->items( )->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYLEFTLINE}' rendertype = 'Bare' ).
    left_line->items( )->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENLEFTLINE}' rendertype = 'Bare' ).
    DATA(circle) = line->items( )->hbox( width = '1.875rem' height = '1.875rem' rendertype = 'Bare' ).
    DATA(red_circle) = circle->items( )->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-red' visible = '{oStageBarData>RedCircle}' rendertype = 'Bare' ).
    red_circle->items( )->text( class = 'Body_2_2 color-white' text = '{STAGENUMBER}' ).


*
*      <VBox class="rak-stagebar-margin" width="100%" id="id-rak-stagebar" renderType="Bare">
*    <HBox width="100%" visible="{oStageBarData>/settings/bIsDesktop}" renderType="Bare">
*      <HBox items="{oStageBarData>/stages}" justifyContent="Start" alignItems="Start" renderType="Bare">
*        <HBox renderType="Bare">
*          <!-- STEP VBOX -->
*          <VBox width="{oStageBarData>/settings/StepVboxWidth}" justifyContent="Start" alignItems="Center" class="rak-stagebar-step-cont" renderType="Bare">
*            <!-- LINES & CIRCLE HBOX -->
*            <HBox justifyContent="Start" alignItems="Start" renderType="Bare">
*              <!-- LEFT LINE -->
*              <HBox width="2.8125rem" height="0.9375rem" renderType="Bare">
*                <HBox width="100%" height="100%" class="rak-stagebar-line-gray3" visible="{oStageBarData>GrayLeftLine}" renderType="Bare"/>
*                <HBox width="100%" height="100%" class="rak-stagebar-line-green" visible="{oStageBarData>GreenLeftLine}" renderType="Bare"/>
*              </HBox>
*              <!-- CIRCLE -->
*              <HBox width="1.875rem" height="1.875rem" renderType="Bare">
*                <!-- RED CIRCLE -->
*                <HBox class="rak-stagebar-circle-cont rak-stagebar-circle-red" visible="{oStageBarData>RedCircle}" renderType="Bare">
*                  <Text class="Body_2_2 color-white" text="{oStageBarData>StageNumber}"></Text>
*                </HBox>
*                <!-- GREEN CIRCLE -->
*                <HBox class="rak-stagebar-circle-cont rak-stagebar-circle-green" visible="{oStageBarData>GreenCircle}" renderType="Bare">
*                  <core:Icon src="sap-icon://icomoon/fi_check" color="#53A56E" class="rak-stagebar-step-done-icon"/>
*                </HBox>
*                <!-- GRAY CIRCLE -->
*                <HBox class="rak-stagebar-circle-cont rak-stagebar-circle-gray" visible="{oStageBarData>GrayCircle}" renderType="Bare">
*                  <Text class="Body_2_3 color-gray4" text="{oStageBarData>StageNumber}"></Text>
*                </HBox>
*              </HBox>
*              <!-- RIGHT LINE -->
*              <HBox width="2.8125rem" height="0.9375rem" renderType="Bare">
*                <HBox width="100%" height="100%" class="rak-stagebar-line-gray3" visible="{oStageBarData>GrayRightLine}" renderType="Bare"/>
*                <HBox width="100%" height="100%" class="rak-stagebar-line-green" visible="{oStageBarData>GreenRightLine}" renderType="Bare"/>
*              </HBox>
*            </HBox>
*            <!-- TEXT HBOX -->
*            <HBox width="100%" justifyContent="Center" alignItems="Start" renderType="Bare">
*              <Text text="{oStageBarData>StageLabel}" class="Body_2_3 color-red rak-stagebar-text-align-desktop" visible="{oStageBarData>RedStageLabel}"/>
*              <Text text="{oStageBarData>StageLabel}" class="Body_2_3 color-gray4 rak-stagebar-text-align-desktop" visible="{oStageBarData>GrayStageLabel}"/>
*              <Text text="{oStageBarData>StageLabel}" class="Body_2_3 color-green rak-stagebar-text-align-desktop" visible="{oStageBarData>GreenStageLabel}"/>
*            </HBox>
*          </VBox>
*          <!-- GAP VBOX -->
*          <!-- it's width is set programatically in StepBarInit() according to vw -->
*          <VBox width="{oStageBarData>/settings/GapWidth}" height="0.9375rem" justifyContent="Start" visible="{= !${oStageBarData>isLast}}" renderType="Bare">
*            <HBox width="100%" height="100%" class="rak-stagebar-line-gray3" visible="{oStageBarData>GrayGap}" renderType="Bare"/>
*            <HBox width="100%" height="100%" class="rak-stagebar-line-green" visible="{oStageBarData>GreenGap}" renderType="Bare"/>
*          </VBox>
*        </HBox>
*      </HBox>
*    </HBox>
*    <VBox alignItems="Start" visible="{oStageBarData>/settings/bIsMobile}" width="20.5rem" renderType="Bare">
*      <HBox justifyContent="Start" renderType="Bare">
*        <Text text="{oStageBarData>/settings/CurrentStageLabel}" class="Body_1_1 color-Gray7"/>
*      </HBox>
*      <HBox justifyContent="SpaceBetween" alignItems="Center" width="100%" renderType="Bare">
*        <HBox width="70%" height="0.375rem" renderType="Bare">
*          <ProgressIndicator displayOnly="true"
*            percentValue="{oStageBarData>/settings/ProgressPercent}"
*            class="rak-stagebar-progress-indicator" height="100%" width="100%"/>
*        </HBox>
*        <Text text="{i18n>step} {oStageBarData>/settings/CurrentStage} {i18n>of} {oStageBarData>/settings/TotalStages}" class="Body_2_3 color-gray7"/>
*      </HBox>
*    </VBox>
*  </VBox>
  ENDMETHOD.


  METHOD read_case.

    DATA(lo_imp) = NEW zcl_ega_cj_enh_impl_d011( ).
    ev_found = lo_imp->read_case( iv_license_no = iv_license_no ).

    gs_data = lo_imp->gs_data.

  ENDMETHOD.


  METHOD screen_nd011_1_1.

*    DATA(view) = z2ui5_cl_xml_view=>factory( ).

*    DATA(first) = view->vbox( class = 'shapeIT-firstContainer' ).
*    DATA(card) = first->items( )->vbox( class = 'shapeIT-card' ).
*    DATA(card_top) = card->items( )->vbox( class = 'shapeIT-card-top' ).
*    DATA(card_header) = card_top->items( )->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
*    DATA(title) = card_top->items( )->hbox( alignitems = 'Center' ).
*    DATA(dok_logo) = title->items( )->image( src = '../css/img/services/SVG/DOK.svg' ).
*    DATA(title_text) = title->items( )->label( text = get_text_by_id( 'DOKSL_ND011_1_1_TITLE_TEXT' ) class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
*
*    DATA(body) = card->items( )->vbox( class = 'shapeIT-part2' ).
*
*
*    DATA(licenses) = body->items( )->table( mode = 'SingleSelectLeft'
*                             class = 'shapeItMTable mTableSingle MTableGray'
*                             items = client->_bind_edit( val = mt_licenses ) ).
*
*    DATA(lo_columns) = licenses->columns( ).
*    lo_columns->column( )->text( text = '' ).
*    lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_LICENCE' ) ).
*    lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_SCHOOL_NAME' ) ).
*    lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_ISSUED_AT' ) ).
*    lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_EXPIRED_AT' ) ).
*
*    DATA(lo_cells) = licenses->items( )->column_list_item( selected = '{SELKZ}' ).
*    lo_cells->text( '{SELKZ}' ).
*    lo_cells->text( '{RECNNR}' ).
*    lo_cells->text( '{RECNTXT}' ).
*    lo_cells->text( '{path: ''RECNBEG''}' ).
*    lo_cells->text( '{RECNENDABS}' ).
*
*    DATA(footer) = card->items( )->hbox( class = 'shapeIT-footer shapeIT-next-btn-end' justifycontent = 'End' ).
**    DATA(buttonback) = footer->items( )->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'SAVE' ) ).
*    DATA(next) = footer->items( )->button( id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' iconfirst = 'false' press = client->_event( 'NEXT' ) ).
*
*    DATA(lv_xml) = view->stringify( ).
*    REPLACE FIRST OCCURRENCE OF '</mvc:View>' IN lv_xml WITH '</core:FragmentDefinition>'.
*    REPLACE FIRST OCCURRENCE OF '<mvc:View' IN lv_xml WITH '<core:FragmentDefinition'.
*    client->view_display( lv_xml ).

  DATA(view)  = z2ui5_cl_xml_view=>factory( ).
  DATA(first) = view->vbox( class = 'shapeIT-firstContainer' ).

  " ---- CARD -----------------------------------------------------------
  DATA(card)     = first->items( )->vbox( class = 'shapeIT-card' ).
  DATA(card_top) = card->items( )->vbox( class = 'shapeIT-card-top' ).

  DATA(card_header) = card_top->items( )->hbox( justifycontent = 'SpaceBetween'
                                                 alignitems     = 'Center' ).
  DATA(title) = card_header->items( )->hbox( alignitems = 'Center' ).

  DATA(dok_logo)   = title->items( )->image( src = '../css/img/services/SVG/DOK.svg' ).
  DATA(title_text) = title->items( )->label( text  = get_text_by_id( 'DOKSL_ND011_1_1_TITLE_TEXT' )
                                              class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).

  " ---- BODY / LICENSES table -------------------------------------------
  DATA(body) = card->items( )->vbox( class = 'shapeIT-part2' ).

  DATA(licenses) = body->items( )->table( mode  = 'SingleSelectLeft'
                                           class = 'shapeItMTable mTableSingle MTableGray'
                                           items = client->_bind_edit( val = mt_licenses ) ).

  DATA(lo_columns) = licenses->columns( ).
  lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_LICENCE' ) ).
  lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_SCHOOL_NAME' ) ).
  lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_ISSUED_AT' ) ).
  lo_columns->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_1_EXPIRED_AT' ) ).

  DATA(lo_cells) = licenses->items( )->column_list_item( selected = '{SELKZ}' ).
  lo_cells->text( '{RECNNR}' ).
  lo_cells->text( '{RECNTXT}' ).
  lo_cells->text( '{path: ''RECNBEG''}' ).
  lo_cells->text( '{RECNENDABS}' ).

  " ---- FOOTER -----------------------------------------------------------
  DATA(footer) = first->items( )->hbox( class          = 'shapeIT-footer shapeIT-next-btn-end'
                                         justifycontent = 'End' ).

  DATA(buttonback) = footer->items( )->button( id    = 'BUTTONBACK'
                                                text  = get_text_by_id( 'BACK_BUTTON' )
                                                class = 'regularBTN_with_border'
                                                icon  = 'sap-icon://icomoon/Left'
                                                press = client->_event( 'BACK' ) ).

  DATA(next) = footer->items( )->button( id        = 'NEXT'
                                          text      = get_text_by_id( 'NEXT_BUTTON' )
                                          class     = 'regularBTN'
                                          icon      = 'sap-icon://icomoon/Right'
                                          iconfirst = 'false'
                                          press     = client->_event( 'NEXT' ) ).

  client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD screen_nd011_1_2.

    client->_bind_edit( val = gs_data ).

    SELECT domvalue_l AS key, ddtext AS value
      FROM dd07t
      INTO TABLE @DATA(lt_applicant_type)
      WHERE domname EQ 'ZDO_DOK_APPLICANT_TYPE'
      AND   ddlanguage EQ @sy-langu
      ORDER BY domvalue_l.

    DATA(view)  = z2ui5_cl_xml_view=>factory( ).
    DATA(fisrt) = view->vbox( class = 'shapeIT-firstContainer' ).
    DATA(card) = fisrt->vbox( class = 'shapeIT-card' ).
    DATA(card_top) = card->vbox( class = 'shapeIT-card-top' ).
    DATA(card_header) = card_top->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title) = card_header->hbox( alignitems = 'Center' ).
    DATA(dok_logo) = title->image( src = '../css/img/services/SVG/DOK.svg' height = '2rem' ).
    DATA(title_text) = title->label( text = get_text_by_id( 'DOKSL_ND011_1_1_TITLE_TEXT' ) class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(buttons) = card_header->hbox( alignitems = 'Center' ).
    DATA(savedraft) = buttons->button( id = 'SAVEDRAFT' text = get_text_by_id( 'SAVE_AS_DRAFT' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile sapUiSmallMarginEnd' icon = 'sap-icon://icomoon/Save' press = client->_event(
  'SAVEDRAFTHOME' ) ).
    DATA(savedraft_icononly) = buttons->button( id = 'SAVEDRAFT_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Save' press = client->_event( 'SAVEDRAFTHOME' ) ).
    DATA(delete) = buttons->button( id = 'DELETE' text = get_text_by_id( 'DELETE' ) class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-mobile' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(delete_icononly) = buttons->button( id = 'DELETE_ICONONLY' class = 'shapeIT-cardheader-topbtn shapeIT-hide-in-desktop' icon = 'sap-icon://icomoon/Delete' press = client->_event( 'DELETE' ) ).
    DATA(context_hbox_desktop) = card_header->hbox( class = 'shapeIT-context-hbox-desktop' ).
    DATA(context1_d_cont) = context_hbox_desktop->hbox( class = 'shapeIT-context-cont' ).
    DATA(ctx1_d_label) = context1_d_cont->label( text = get_text_by_id( 'DOKSL_ND011_1_2_CTX1_D_LABEL' ) class = 'Body_1_3 color-gray7' ).
    " AMBIGUOUS(CTX1_D_VALUE): VALUE='F9' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(ctx1_d_value) = context1_d_cont->label( text = '{/XX/GS_DATA/LICENCE_NO}' class = 'Body_1_3 color-gray7' ).
    DATA(context1_d_separator) = context_hbox_desktop->vbox( class = 'shapeIT-context-separator' ).
    DATA(hbox_18) = context_hbox_desktop->hbox( class = 'shapeIT-context-cont' ).
    DATA(licence_name_1) = hbox_18->label( text = '{/XX/GS_DATA/LICENCE_NAME}' class = 'Body_1_3 color-gray7' ).
    DATA(error_1) = card_top->message_strip( text = '{ERROR}' type = 'Warning' showicon = 'true' showclosebutton = 'true' ).  " TODO(ERROR_1): EXTENDED=X, param names assumed from sap.m.MessageStrip API - confirm
    " TODO(STAGES): RAKSTAGEBAR is a custom extension control (EXTENDED=X) - exact z2ui5 API not yet confirmed.
    "   source data: steps=3 current=1 texts=First,Second,Third,Fourth
    DATA(stages) = card->hbox( class = 'sapUiLargeMarginBegin' ).  " placeholder - see TODO above
    DATA(body) = card->vbox( class = 'shapeIT-part2' ).
    DATA(applicant) = body->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APPLICANT' ) class = 'font1 weight600 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(applicant_top) = body->hbox( justifycontent = 'SpaceBetween' alignitems = 'Start' ).
    DATA(app_name_box) = applicant_top->vbox( aligncontent = 'Start' ).
    DATA(app_name_text) = app_name_box->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APP_NAME_TEXT' ) class = 'font1 weight400 color-gray6' ).
    " TODO(APP_NAME): no VALUE and no TECHNICAL_NAME in source - binding unknown
    DATA(app_name) = app_name_box->label( text = '' class = 'font1 weight500 color-gray7 sapUiSmallMarginTop' ).
    DATA(app_id_box) = applicant_top->vbox( aligncontent = 'Start' ).
    DATA(app_id_text) = app_id_box->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APP_ID_TEXT' ) class = 'font1 weight400 color-gray6' ).
    " TODO(APP_ID): no VALUE and no TECHNICAL_NAME in source - binding unknown
    DATA(app_id) = app_id_box->label( text = '' class = 'font1 weight500 color-gray7 sapUiSmallMarginTop' ).
    DATA(app_type_box) = applicant_top->vbox( aligncontent = 'Start' ).
    DATA(app_type_text) = app_type_box->label( text = get_text_by_id( 'DOKSL_ND001_1_1_APP_TYPE_TEXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(app_type) = app_type_box->combobox( selectedkey = '{/XX/GS_DATA/APPLICANT_TYPE}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    LOOP AT lt_applicant_type INTO DATA(ls_applicant_type).
      app_type->item( key = ls_applicant_type-key text = ls_applicant_type-value ).
    ENDLOOP.

    " TODO(APP_TYPE): items come from search-help ZSH_CJ_APPLICANT_TYPE (key=KEY, value=VALUE) - value-list binding pattern not yet confirmed, items aggregation omitted
    DATA(hseparator_1) = body->hbox( class = 'sapUiMediumMarginTop shapeIT-hr' ).  " horizontal rule: shapeIT-hr = width:100%; border-top/bottom:1px solid
    DATA(school_block) = body->vbox( class = 'sapUiMediumMarginTop' ).
    DATA(school) = school_block->panel( headertext  = get_text_by_id( 'DOK_SCHOOL_DETAILS' )
                                              expandable = 'true'
                                              expanded   = 'false'
                                              class      = 'panel' ).
    DATA(school_name) = school->hbox( class = 'sapUiSmallMarginTop' justifycontent = 'SpaceBetween' ).
    DATA(name_en) = school_name->vbox( ).
    DATA(name_en_text) = name_en->label( text = get_text_by_id( 'DOKSL_ND001_1_1_NAME_EN_TEXT' ) class = 'font1 weight400 color-gray6' ).
    " AMBIGUOUS(LABEL_18): VALUE='*School Name must include Private and School' also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(label_18) = name_en->label( text = '{/XX/GS_DATA/SCHOOL/SCHOOL_NAME_EN}' class = 'font1 weight500 color-dark-blue' ).
    DATA(name_ar) = school_name->vbox( alignitems = 'End' ).
    DATA(name_ar_text) = name_ar->label( text = get_text_by_id( 'DOKSL_ND001_1_1_NAME_AR_TEXT' ) class = 'font1 weight400 color-gray6' ).
    " AMBIGUOUS(LABEL_19): VALUE=Arabic instructional text also set in source (ignored here, using TECHNICAL_NAME binding) - see note below
    DATA(label_19) = name_ar->label( text = '{/XX/GS_DATA/SCHOOL/SCHOOL_NAME_AB}' class = 'font1 weight500 color-dark-blue' ).
    DATA(school_data) = school->vbox( ).
    DATA(hbox_7) = school_data->hbox( class = 'sapUiSmallMarginTop' justifycontent = 'SpaceBetween' alignitems = 'Start' ).
    DATA(vbox_19) = hbox_7->vbox( aligncontent = 'Start' ).
    DATA(trade_license) = vbox_19->vbox( class = 'trade_license' ).
    DATA(trade_license_txt) = trade_license->label( text = get_text_by_id( 'DOKSL_ND001_2_2_TRADE_LICENSE_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(reg_authority_1) = trade_license->combobox( selectedkey = '{/XX/GS_DATA/SCHOOL/REG_AUTHORITY}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    " TODO(REG_AUTHORITY_1): items come from search-help ZSH_CJ_TRADE_AUTHORITY - value-list binding not yet confirmed
    DATA(trade_license_box) = vbox_19->vbox( ).
    DATA(trade_license_num_txt) = trade_license_box->label( text = get_text_by_id( 'DOKSL_ND001_3_2_TRADE_LICENSE_NUM_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(trade_lic_2) = trade_license_box->label( text = '{/XX/GS_DATA/SCHOOL/TRADE_LIC}' class = 'font1 weight500 color-dark-blue' ).
    DATA(phone_number) = vbox_19->vbox( ).
    DATA(phone_number_txt) = phone_number->label( text = get_text_by_id( 'DOKSL_ND001_1_1_PHONE_NUMBER_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(label_27) = phone_number->label( text = '{/XX/GS_DATA/SCHOOL/TELEPHONE}' class = 'font1 weight500 color-dark-blue' ).
    DATA(vbox_20) = hbox_7->vbox( aligncontent = 'Start' ).
    DATA(curriculum) = vbox_20->vbox( ).
    DATA(curriculum_txt) = curriculum->label( text = get_text_by_id( 'DOKSL_ND001_1_1_CURRICULUM_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(curriculum_comb) = curriculum->combobox( selectedkey = '{/XX/GS_DATA/SCHOOL/CURRICULUM}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    " TODO(CURRICULUM_COMB): items come from search-help ZSH_CJ_CURRICULUM - value-list binding not yet confirmed
    DATA(curriculum_type) = vbox_20->vbox( ).
    DATA(curriculum_type_txt) = curriculum_type->label( text = get_text_by_id( 'DOKSL_ND001_1_1_CURRICULUM_TYPE_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(curriculum_type_1) = curriculum_type->combobox( selectedkey = '{/XX/GS_DATA/SCHOOL/CURRICULUM_TYPE}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    " TODO(CURRICULUM_TYPE_1): items come from search-help ZSH_CJ_CURRICULUM_TYPE - value-list binding not yet confirmed
    DATA(po_box_no) = vbox_20->vbox( ).
    DATA(po_box_no_txt) = po_box_no->label( text = get_text_by_id( 'DOKSL_ND001_1_1_PO_BOX_NO_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(label_28) = po_box_no->label( text = '{/XX/GS_DATA/SCHOOL/POBOX}' class = 'font1 weight500 color-dark-blue' ).
    DATA(vbox_21) = hbox_7->vbox( aligncontent = 'Start' ).
    DATA(location) = vbox_21->vbox( ).
    DATA(location_txt) = location->label( text = get_text_by_id( 'DOKSL_ND001_1_1_LOCATION_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(location_comb) = location->combobox( selectedkey = '{/XX/GS_DATA/SCHOOL/LOCATION}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    " TODO(LOCATION_COMB): items come from search-help ZSH_CJ_LOCATION_ID - value-list binding not yet confirmed
    DATA(school_adress) = vbox_21->vbox( ).
    DATA(school_adress_txt) = school_adress->label( text = get_text_by_id( 'DOKSL_ND001_1_1_SCHOOL_ADRESS_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(label_26) = school_adress->label( text = '{/XX/GS_DATA/SCHOOL/ADRESS}' class = 'font1 weight500 color-dark-blue' ).
    DATA(parcel) = vbox_21->vbox( ).
    DATA(parcel_id_txt) = parcel->label( text = get_text_by_id( 'PARCEL_ID' ) class = 'font1 weight400 color-gray6' ).
    DATA(parcel_id) = parcel->label( text = '{/XX/GS_DATA/SCHOOL/PARCEL_ID}' class = 'font1 weight500 color-dark-blue' ).
    DATA(managment) = school_block->panel( headertext  = get_text_by_id( 'DOKSL_ND001_3_2_MANAGMENT' )
                                              expandable = 'true'
                                              expanded   = 'false'
                                              class      = 'panel' ).
    DATA(owners) = managment->vbox( ).
    DATA(owners_txt) = owners->label( text = get_text_by_id( 'DOKSL_ND004_1_2_OWNERS_TXT' ) class = 'font1 weight500 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(owners_1) = owners->table( class = 'shapeItMTable MTableGray'
                                 items = '{/XX/GS_DATA/OWNERS}' ).

    DATA(lo_columns_owners_1) = owners_1->columns( ).
    lo_columns_owners_1->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_2_NAME_1' ) ).  " NAME_1
    lo_columns_owners_1->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_2_NATIONALITY_1' ) ).  " NATIONALITY_1
    lo_columns_owners_1->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_2_SHARE_PER_1' ) ).  " SHARE_PER_1
    lo_columns_owners_1->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_2_MOBILE_NUMBER_1' ) ).  " MOBILE_NUMBER_1
    lo_columns_owners_1->column( )->text( text = get_text_by_id( 'DOKSL_ND004_1_2_EMAIL_ADDRESS_1' ) ).  " EMAIL_ADDRESS_1

    DATA(lo_cells_owners_1) = owners_1->column_list_item( ).
    lo_cells_owners_1->text( '{NAME}' ).  " NAME_1
    lo_cells_owners_1->text( '{NATIONALITY}' ).  " NATIONALITY_1
    lo_cells_owners_1->text( '{SHARE_PER}' ).  " SHARE_PER_1
    lo_cells_owners_1->text( '{MOBILE_NUMBER}' ).  " MOBILE_NUMBER_1
    lo_cells_owners_1->text( '{EMAIL_ADDRESS}' ).  " EMAIL_ADDRESS_1
    DATA(hseparator_2) = managment->hbox( class = 'shapeIT-hr' ).  " horizontal rule
    DATA(manager) = managment->vbox( ).
    DATA(manager_txt) = manager->label( text = get_text_by_id( 'DOKSL_ND001_1_2_MANAGER_TXT' ) class = 'font1 weight500 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(manager_name_1) = manager->label( text = '{/XX/GS_DATA/MANAGER_NAME}' class = 'font1 weight500 color-dark-blue sapUiSmallMarginTop' ).
    DATA(manager_line_1) = manager->hbox( justifycontent = 'SpaceBetween' alignitems = 'Start' ).
    DATA(vbox_26) = manager_line_1->vbox( ).
    DATA(emirates_id_txt) = vbox_26->label( text = get_text_by_id( 'EMIRATES_ID' ) class = 'font1 weight400 color-gray6' ).
    DATA(manager_emirates_id_1) = vbox_26->label( text = '{/XX/GS_DATA/MANAGER_EMIRATES_ID}' class = 'font1 weight500 color-dark-blue' ).
    DATA(vbox_27) = manager_line_1->vbox( ).
    DATA(managet_nationality_txt) = vbox_27->label( text = get_text_by_id( 'DOKSL_ND001_2_3_MANAGET_NATIONALITY_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(manager_nationality_1) = vbox_27->label( text = '{/XX/GS_DATA/MANAGER_NATIONALITY}' class = 'font1 weight500 color-dark-blue' ).
    DATA(manager_mobile_number_box) = manager_line_1->vbox( ).
    DATA(manager_mobile_number_txt) = manager_mobile_number_box->label( text = get_text_by_id( 'DOKSL_ND001_3_2_MANAGER_MOBILE_NUMBER_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(manager_mobile_number_1) = manager_mobile_number_box->label( text = '{/XX/GS_DATA/MANAGER_MOBILE_NUMBER}' class = 'font1 weight500 color-dark-blue' ).
    DATA(vbox_29) = manager_line_1->vbox( ).
    DATA(manager_email_txt) = vbox_29->label( text = get_text_by_id( 'DOKSL_ND001_3_2_MANAGER_EMAIL_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(manager_email_address_1) = vbox_29->label( text = '{/XX/GS_DATA/MANAGER_EMAIL_ADDRESS}' class = 'font1 weight500 color-dark-blue' ).
    DATA(change_data) = body->vbox( class = 'sapUiSmallMarginTopBottom' ).
    DATA(advertisement_details_txt) = change_data->label( text = get_text_by_id( 'DOKSL_ND011_1_2_ADVERTISEMENT_DETAILS_TXT' ) class = 'font1 weight500 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(advertisement_details_1) = change_data->hbox( justifycontent = 'SpaceBetween' alignitems = 'Start' ).
    DATA(media_platform) = advertisement_details_1->vbox( aligncontent = 'Start' ).
    DATA(media_platform_txt) = media_platform->label( text = get_text_by_id( 'DOKSL_ND011_1_2_MEDIA_PLATFORM_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(media_1) = media_platform->combobox( selectedkey = '{/XX/GS_DATA/ADVERTISE/MEDIA}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    " TODO(MEDIA_1): items come from search-help ZSH_CJ_MEDIA_PLATFORM_TYPE - value-list binding not yet confirmed
    DATA(advertisement_type) = advertisement_details_1->vbox( aligncontent = 'Start' ).
    DATA(advertisement_type_txt) = advertisement_type->label( text = get_text_by_id( 'DOKSL_ND011_1_2_ADVERTISEMENT_TYPE_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(hbox_15) = advertisement_type->hbox( justifycontent = 'Center' ).
    DATA(vbox_37) = hbox_15->vbox( ).
    DATA(type_text_1) = vbox_37->checkbox( text = get_text_by_id( 'DOKSL_ND011_1_2_TYPE_TEXT_1' ) selected = '{ADVERTISE/TYPE_TEXT}' class = 'checkbox' ).
    DATA(type_photos_1) = vbox_37->checkbox( text = get_text_by_id( 'DOKSL_ND011_1_2_TYPE_PHOTOS_1' ) selected = '{ADVERTISE/TYPE_PHOTOS}' class = 'checkbox' ).
    DATA(type_videos_1) = vbox_37->checkbox( text = get_text_by_id( 'DOKSL_ND011_1_2_TYPE_VIDEOS_1' ) selected = '{ADVERTISE/TYPE_VIDEOS}' class = 'checkbox' ).
    DATA(type_audio_1) = vbox_37->checkbox( text = get_text_by_id( 'DOKSL_ND011_1_2_TYPE_AUDIO_1' ) selected = '{ADVERTISE/TYPE_AUDIO}' class = 'checkbox' ).
    DATA(advertisement_request_date) = advertisement_details_1->vbox( ).
    DATA(advertisement_request_date_txt) = advertisement_request_date->label( text = get_text_by_id( 'DOKSL_ND011_1_2_ADVERTISEMENT_REQUEST_DATE_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(request_on_1) = advertisement_request_date->date_picker( value = '{/XX/GS_DATA/ADVERTISE/REQUEST_ON}' displayformat = 'dd/MM/yyyy' valueformat = 'yyyy-MM-dd' placeholder = 'dd/MM/yyyy' class = 'datepicker' ).
    DATA(hbox_16) = advertisement_request_date->hbox( ).
    DATA(vbox_42) = hbox_16->vbox( ).
    DATA(advertisement_request_end_txt) = vbox_42->label( text = get_text_by_id( 'DOKSL_ND011_1_2_ADVERTISEMENT_REQUEST_END_TXT' ) class = 'font1 weight400 color-gray6 sapUiMediumMarginTop' ).
    DATA(end_date_1) = vbox_42->date_picker( value = '{/XX/GS_DATA/ADVERTISE/END_DATE}' displayformat = 'dd/MM/yyyy' valueformat = 'yyyy-MM-dd' placeholder = 'dd/MM/yyyy' class = 'datepicker' ).
    DATA(advertisement_details_2) = change_data->hbox( justifycontent = 'SpaceBetween' alignitems = 'Start' ).
    DATA(content_of_advertisement) = advertisement_details_2->vbox( class = 'width100' ).
    DATA(advertisement_description_txt) = content_of_advertisement->label( text = get_text_by_id( 'DOKSL_ND011_1_2_CONTENT_OF_ADVERTISEMENT_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(advert_content_1) = content_of_advertisement->text_area( value = '{/XX/GS_DATA/ADVERTISE/ADVERT_CONTENT}' maxlength = '250' class = 'textarea' ).
    DATA(hbox_19) = advertisement_details_2->hbox( class = 'sapUiMediumMarginTop' ).
    DATA(vbox_43) = hbox_19->vbox( ).
    DATA(person_info_included_txt) = vbox_43->label( text = get_text_by_id( 'DOKSL_ND011_1_2_PERSON_INFO_INCLUDED_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(hbox_17) = vbox_43->hbox( class = 'toggle-line' ).
    DATA(adv_1) = hbox_17->toggle_button( text = get_text_by_id( 'RB_YES' ) pressed = '{ADV_PERSONAL_DATA_Y}' class = 'toggle toggle-left-round-border' ).
    DATA(adv_2) = hbox_17->toggle_button( text = get_text_by_id( 'RB_NO' ) pressed = '{ADV_PERSONAL_DATA_N}' class = 'toggle toggle-right-round-border' ).
    DATA(hseparator_3) = change_data->hbox( class = 'sapUiSmallMarginTop shapeIT-hr' ).  " horizontal rule
    DATA(contact_person_details_txt) = change_data->label( text = get_text_by_id( 'DOKSL_ND011_1_2_CONTACT_PERSON_DETAILS_TXT' ) class = 'font1 weight500 color-dark-blue sapUiSmallMarginEnd' ).
    DATA(contact_person_1) = change_data->hbox( class = 'sapUiSmallMarginTop' alignitems = 'Start' ).
    DATA(vbox_40) = contact_person_1->vbox( ).
    DATA(person_type_txt) = vbox_40->label( text = get_text_by_id( 'DOKSL_ND011_1_2_PERSON_TYPE_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(contact_ptype_1) = vbox_40->combobox( selectedkey = '{/XX/GS_DATA/ADVERTISE/CONTACT_PTYPE}' placeholder = get_text_by_id( 'SELECT' ) class = 'combobox' ).
    " TODO(CONTACT_PTYPE_1): items come from search-help ZSH_CJ_CONTACT_PERSON - value-list binding not yet confirmed
    DATA(contact_person_2) = change_data->hbox( class = 'sapUiSmallMarginTop' justifycontent = 'SpaceBetween' alignitems = 'Start' ).
    DATA(vbox_38) = contact_person_2->vbox( class = 'width49' ).
    DATA(email_txt) = vbox_38->label( text = get_text_by_id( 'DOKSL_ND011_1_2_EMAIL_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(email_1) = vbox_38->input( value = '{/XX/GS_DATA/ADVERTISE/EMAIL}' type = 'Email' class = 'inputNoMax' ).
    DATA(vbox_39) = contact_person_2->vbox( class = 'width49' ).
    DATA(mobile_txt) = vbox_39->label( text = get_text_by_id( 'DOKSL_ND011_1_2_MOBILE_TXT' ) class = 'font1 weight400 color-gray6' ).
    DATA(mobile_1) = vbox_39->input( value = '{/XX/GS_DATA/ADVERTISE/MOBILE}' type = 'Tel' class = 'inputNoMax' ).
    DATA(footer) = fisrt->hbox( class = 'shapeIT-footer shapeIT-next-btn-end' justifycontent = 'SpaceBetween' ).
    DATA(buttonback) = footer->button( id = 'BUTTONBACK' text = get_text_by_id( 'BACK_BUTTON' ) class = 'regularBTN_with_border' icon = 'sap-icon://icomoon/Left' press = client->_event( 'BACK' ) ).
    DATA(next) = footer->button( id = 'NEXT' text = get_text_by_id( 'NEXT_BUTTON' ) class = 'regularBTN' icon = 'sap-icon://icomoon/Right' press = client->_event( 'SAVE' ) ).


    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD SET_DATA.

    mt_table = VALUE #(
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 )
        ( product = `table` create_date = `01.01.2023` create_by = `Peter` storage_location = `AREA_001` quantity = 400 )
        ( product = `chair` create_date = `01.01.2022` create_by = `James` storage_location = `AREA_001` quantity = 123 )
        ( product = `sofa` create_date = `01.05.2021` create_by = `Simone` storage_location = `AREA_001` quantity = 700 )
        ( product = `computer` create_date = `27.01.2023` create_by = `Theo` storage_location = `AREA_001` quantity = 200 )
        ( product = `printer` create_date = `01.01.2023` create_by = `Hannah` storage_location = `AREA_001` quantity = 90 )
        ( product = `table2` create_date = `01.01.2023` create_by = `Julia` storage_location = `AREA_001` quantity = 110 ) ).

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

*      view_display( ).
      screen_nd011_1_1( ).
      get_licenses( ).
*      set_data( ).
      RETURN.
    ENDIF.


    CASE client->get( )-event.
      WHEN 'NEXT'.
        IF check_license( ) EQ abap_true.
          screen_nd011_1_2( ).
        ENDIF.

      WHEN `BUTTON_DETAILS`.
        client->popover_destroy( ).

      WHEN `POPOVER_DETAIL`.
        mv_check_popover = abap_true.
        mv_product = client->get_event_arg( 2 ).
        popover_display( client->get_event_arg( 1 ) ).
    ENDCASE.
    client->view_model_update( ).

  ENDMETHOD.
ENDCLASS.
