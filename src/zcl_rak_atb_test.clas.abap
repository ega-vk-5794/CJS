CLASS zcl_rak_atb_test DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_case     TYPE string.
    DATA mv_screen   TYPE string.
    DATA mv_journey  TYPE string.
    DATA mv_category TYPE string.
    DATA mv_userdata TYPE string.
    DATA mv_loginbp  TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_kv,
        key   TYPE string,
        value TYPE string,
      END OF ty_kv,
      tt_kv TYPE STANDARD TABLE OF ty_kv WITH EMPTY KEY.

    DATA mo_client TYPE REF TO z2ui5_if_client.
    DATA mt_out    TYPE tt_kv.
    DATA mv_appurl TYPE string.
    DATA mv_open   TYPE abap_bool.
    DATA mt_msg    TYPE zif_rak_journey=>tt_msg.

    METHODS run.
    METHODS render.
    METHODS seed_items RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_item.
    METHODS open_url_html IMPORTING iv_url TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS esc IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS esc_js IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_ATB_TEST IMPLEMENTATION.


  METHOD esc.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD esc_js.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `\` IN rv WITH `\\`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `\'`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `\"`.
  ENDMETHOD.


  METHOD open_url_html.
    DATA(lv_js) = |window.open('| && esc_js( iv_url ) && |','_blank');this.remove();|.
    DATA(lv_html) = |<div><img src="data:," style="display:none" onerror="| && lv_js && |"/></div>|.
    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    rv = lv_html.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'CJS - ATB launch test (real bridge + BAdI)' ).

    IF mv_open = abap_true AND mv_appurl IS NOT INITIAL.
      page->html( content = open_url_html( mv_appurl ) sanitizecontent = abap_false ).
    ENDIF.

    LOOP AT mt_msg INTO DATA(ls_m).
      page->message_strip( text = esc( ls_m-text ) type = ls_m-type showicon = abap_true class = 'sapUiSmallMargin' ).
    ENDLOOP.

    DATA(lo_cfg) = page->panel( headertext = 'BAdI read parameters' expandable = abap_true expanded = abap_true
                                class = 'sapUiSmallMarginBeginEnd' ).
    DATA(lo_f) = lo_cfg->simple_form( editable = abap_true layout = 'ResponsiveGridLayout'
                                      columnsxl = '1' columnsl = '1' columnsm = '1' )->content( ns = 'form' ).
    lo_f->label( 'Case (param1)' ).
    lo_f->input( value = mo_client->_bind_edit( mv_case ) ).
    lo_f->label( 'Screen name' ).
    lo_f->input( value = mo_client->_bind_edit( mv_screen ) placeholder = 'NPAY_1_1 / PAY_1_1' ).
    lo_f->label( 'Journey (param2)' ).
    lo_f->input( value = mo_client->_bind_edit( mv_journey ) ).
    lo_f->label( 'Category' ).
    lo_f->input( value = mo_client->_bind_edit( mv_category ) ).
    lo_f->label( 'Userdata (portal session key, optional)' ).
    lo_f->input( value = mo_client->_bind_edit( mv_userdata ) ).
    lo_f->label( 'Dev login BP (optional)' ).
    lo_f->input( value = mo_client->_bind_edit( mv_loginbp ) ).

    DATA(lo_bar) = lo_cfg->hbox( class = 'sapUiSmallMargin' ).
    lo_bar->button( text = 'Call read (get ATB URL)' icon = 'sap-icon://synchronize' type = 'Emphasized'
                    press = mo_client->_event( 'RUN' ) ).

    IF mv_appurl IS NOT INITIAL.
      DATA(lo_url) = page->vbox( class = 'sapUiContentPadding' ).
      lo_url->object_status( title = 'APPLICATIONURL' text = 'received' state = 'Success' icon = 'sap-icon://accept' ).
      lo_url->text( text = esc( mv_appurl ) class = 'sapUiTinyMarginTop' ).
      lo_url->button( text = 'Open ATB gateway' icon = 'sap-icon://cart' type = 'Emphasized'
                      class = 'sapUiSmallMarginTop' press = mo_client->_event( 'OPEN' ) ).
    ENDIF.

    IF mt_out IS NOT INITIAL.
      DATA(lo_oc) = page->vbox( class = 'sapUiContentPadding' ).
      lo_oc->title( text = 'Definition returned by BAdI read (live)' ).
      DATA(lo_t) = lo_oc->table( ).
      DATA(lo_cols) = lo_t->columns( ).
      lo_cols->column( )->text( 'Field' ).
      lo_cols->column( )->text( 'Value' ).
      DATA(lo_items) = lo_t->items( ).
      LOOP AT mt_out INTO DATA(ls_o).
        DATA(lo_cells) = lo_items->column_list_item( )->cells( ).
        lo_cells->text( esc( ls_o-key ) ).
        lo_cells->text( esc( ls_o-value ) ).
      ENDLOOP.
    ENDIF.

    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD run.
    CLEAR: mt_out, mv_appurl.

    DATA ls_cfg TYPE zif_rak_journey=>ty_config.
    ls_cfg-journey_id       = mv_journey.
    ls_cfg-cj_type          = mv_journey.
    ls_cfg-backend-active   = abap_true.
    ls_cfg-backend-journey  = mv_journey.
    ls_cfg-backend-category = mv_category.
    ls_cfg-backend-fm_read  = 'ZFM_EGA_CJ_FW_READ_N'.
    ls_cfg-backend-fm_post  = 'ZFM_EGA_CJ_FW_POST_N'.
    ls_cfg-backend-userdata    = mv_userdata.
    ls_cfg-backend-loginbp_dev = mv_loginbp.

    DATA(lo_bridge) = NEW zcl_rak_qnv_bridge( ls_cfg ).

    lo_bridge->read(
      EXPORTING
        iv_screen = mv_screen
        iv_guid   = mv_case
        it_items  = seed_items( )
      IMPORTING
        et_values = DATA(lt_vals)
        et_msg    = DATA(lt_msg) ).

    LOOP AT lt_vals INTO DATA(ls_v).
      IF ls_v-key IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( key = ls_v-key value = ls_v-value ) TO mt_out.
      IF to_upper( ls_v-key ) = 'APPLICATIONURL' AND ls_v-value IS NOT INITIAL.
        mv_appurl = ls_v-value.
      ENDIF.
    ENDLOOP.

    SORT mt_out BY key.
    DELETE ADJACENT DUPLICATES FROM mt_out COMPARING key value.

    APPEND LINES OF lt_msg TO mt_msg.

    mt_msg = VALUE #( BASE mt_msg
      ( type = COND #( WHEN mv_appurl IS NOT INITIAL THEN 'Success' ELSE 'Warning' )
        text = COND #( WHEN mv_appurl IS NOT INITIAL
                       THEN |APPLICATIONURL returned - press Open ATB gateway.|
                       ELSE |No APPLICATIONURL came back for screen { mv_screen }.| ) ) ).
  ENDMETHOD.


  METHOD seed_items.
    rt = VALUE #(
      ( field = 'APPLICATIONURL'   tech = 'APPLICATIONURL' )
      ( field = 'REDIRECTURL'      tech = 'REDIRECTURL' )
      ( field = 'MERCHANTID'       tech = 'MERCHANTID' )
      ( field = 'TERMINALID'       tech = 'TERMINALID' )
      ( field = 'SECRETKEY'        tech = 'SECRETKEY' )
      ( field = 'SERVICEID'        tech = 'SERVICEID' )
      ( field = 'REFERENCEID'      tech = 'REFERENCEID' )
      ( field = 'ESERVICECODE'     tech = 'ESERVICECODE' )
      ( field = 'SERVICESESSIONID' tech = 'SERVICESESSIONID' )
      ( field = 'PAYCHANNEL'       tech = 'PAYCHANNEL' )
      ( field = 'PAYTYPE'          tech = 'PAYTYPE' )
      ( field = 'SERVICELIST'      tech = 'SERVICELIST' )
      ( field = 'AMOUNT'           tech = 'AMOUNT' )
      ( field = 'EMAIL'            tech = 'EMAIL' )
      ( field = 'USERID'           tech = 'USERID' )
      ( field = 'LANG'             tech = 'LANG' )
      ( field = 'TOTALFEESVALUE'   tech = 'TOTALFEESVALUE' )
      ( field = 'OWNER_BP'         tech = 'OWNER_BP' )
      ( field = 'CASE'             tech = 'CASE' )
      ( field = 'INTRENO_JOURNEY'  tech = 'INTRENO_JOURNEY' )
      ( field = 'ATB_FLAG'         tech = 'ATB_FLAG' )
      ( field = 'PW_RB1'           tech = 'PW_RB1' )
      ( field = 'PW_RB2'           tech = 'PW_RB2' ) ).
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
    mo_client = client.
    IF mv_case IS INITIAL.
      mv_case     = '1958731'.
      mv_screen   = 'NPAY_1_1'.
      mv_journey  = 'PG01'.
      mv_category = 'PAY'.
    ENDIF.

    DATA(lv_event) = mo_client->get( )-event.
    CLEAR: mt_msg, mv_open.

    CASE lv_event.
      WHEN 'RUN'.  run( ).
      WHEN 'OPEN'.
        IF mv_appurl IS NOT INITIAL.
          mv_open = abap_true.
          mt_msg = VALUE #( ( type = 'Information' text = |Opening ATB gateway in a new tab...| ) ).
        ENDIF.
    ENDCASE.

    render( ).
  ENDMETHOD.
ENDCLASS.
