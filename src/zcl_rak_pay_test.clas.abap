CLASS zcl_rak_pay_test DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_caseid  TYPE string.
    DATA mv_bp      TYPE string.
    DATA mv_intreno TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_feerow,
        desc   TYPE string,
        amount TYPE string,
      END OF ty_feerow,
      tt_feerow TYPE STANDARD TABLE OF ty_feerow WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_oprow,
        fieldname TYPE string,
        action    TYPE string,
        value     TYPE string,
      END OF ty_oprow,
      tt_oprow TYPE STANDARD TABLE OF ty_oprow WITH EMPTY KEY.

    DATA mo_client TYPE REF TO z2ui5_if_client.
    DATA mt_fee    TYPE tt_feerow.
    DATA mv_total  TYPE string.
    DATA mt_op     TYPE tt_oprow.
    DATA mv_status TYPE string.
    DATA mt_msg    TYPE zif_rak_journey=>tt_msg.

    METHODS render.
    METHODS do_fees.
    METHODS do_route.
    METHODS do_poll.
    METHODS esc IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_PAY_TEST IMPLEMENTATION.


  METHOD do_fees.
    CLEAR: mt_fee, mv_total.
    DATA(lo_pay) = NEW zcl_rak_pay_engine(
      iv_caseid  = CONV #( mv_caseid )
      iv_intreno = mv_intreno
      iv_bp      = CONV #( mv_bp ) ).

    lo_pay->get_fees( IMPORTING et_fee = DATA(lt_fee) ev_total = DATA(lv_total) ).

    LOOP AT lt_fee INTO DATA(ls_f).
      APPEND VALUE #( desc = ls_f-desc amount = |{ ls_f-amount NUMBER = USER }| ) TO mt_fee.
    ENDLOOP.
    mv_total = |{ lv_total NUMBER = USER }|.

    mt_msg = COND #( WHEN lt_fee IS INITIAL
      THEN VALUE #( ( type = 'Warning' text = |No open fees found for case { mv_caseid } (dfkkop empty or already cleared).| ) )
      ELSE VALUE #( ( type = 'Success' text = |{ lines( lt_fee ) } fee line(s) read from live data.| ) ) ).
  ENDMETHOD.


  METHOD do_poll.
    DATA(lo_pay) = NEW zcl_rak_pay_engine( iv_caseid = CONV #( mv_caseid ) iv_intreno = mv_intreno iv_bp = CONV #( mv_bp ) ).
    mv_status = lo_pay->poll_status( iv_intreno = mv_intreno ).

    mt_msg = VALUE #( ( type = COND #( WHEN mv_status = 'SUCCESS' THEN 'Success'
                                       WHEN mv_status = 'FAILED'  THEN 'Error'
                                       ELSE 'Information' )
                        text = |poll_status returned: { mv_status }| ) ).
  ENDMETHOD.


  METHOD do_route.
    CLEAR mt_op.
    DATA(lo_pay) = NEW zcl_rak_pay_engine( iv_caseid = CONV #( mv_caseid ) iv_intreno = mv_intreno iv_bp = CONV #( mv_bp ) ).
    DATA(lt_ops) = lo_pay->route_gateway( ).

    LOOP AT lt_ops INTO DATA(ls_o).
      APPEND VALUE #( fieldname = ls_o-fieldname action = ls_o-action value = ls_o-value ) TO mt_op.
    ENDLOOP.

    DATA(lv_atb) = VALUE #( lt_ops[ fieldname = 'ATB_FLAG' action = 'SET_LABEL' ]-value OPTIONAL ).
    mt_msg = VALUE #( ( type = 'Information'
      text = COND #( WHEN lv_atb IS NOT INITIAL THEN |Gateway routing: ATB { lv_atb }.|
                     ELSE |Routing produced { lines( lt_ops ) } field op(s).| ) ) ).
  ENDMETHOD.


  METHOD esc.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'CJS - Payment engine test (live case)' ).

    LOOP AT mt_msg INTO DATA(ls_m).
      page->message_strip( text = esc( ls_m-text ) type = ls_m-type showicon = abap_true class = 'sapUiSmallMargin' ).
    ENDLOOP.

    DATA(lo_cfg) = page->panel( headertext = 'Live case' expandable = abap_true expanded = abap_true
                                class = 'sapUiSmallMarginBeginEnd' ).
    DATA(lo_f) = lo_cfg->simple_form( editable = abap_true layout = 'ResponsiveGridLayout'
                                      columnsxl = '1' columnsl = '1' columnsm = '1' )->content( ns = 'form' ).
    lo_f->label( 'Case ext_key' ).
    lo_f->input( value = mo_client->_bind_edit( mv_caseid ) ).
    lo_f->label( 'Intreno (for poll)' ).
    lo_f->input( value = mo_client->_bind_edit( mv_intreno ) ).
    lo_f->label( 'BP' ).
    lo_f->input( value = mo_client->_bind_edit( mv_bp ) ).
    DATA(lo_bar) = lo_cfg->hbox( class = 'sapUiSmallMargin' ).
    lo_bar->button( text = 'Get fees'      icon = 'sap-icon://receipt'       press = mo_client->_event( 'FEES' ) ).
    lo_bar->button( text = 'Route gateway' icon = 'sap-icon://split'         press = mo_client->_event( 'ROUTE' ) class = 'sapUiTinyMarginBegin' ).
    lo_bar->button( text = 'Poll status'   icon = 'sap-icon://refresh' type = 'Emphasized' press = mo_client->_event( 'POLL' ) class = 'sapUiTinyMarginBegin' ).

    IF mv_status IS NOT INITIAL.
      DATA(lv_state) = COND string( WHEN mv_status = 'SUCCESS' THEN 'Success'
                                    WHEN mv_status = 'FAILED'  THEN 'Error'
                                    ELSE 'Warning' ).
      page->object_status( title = 'poll_status' text = mv_status state = lv_state
                           icon = COND #( WHEN mv_status = 'SUCCESS' THEN 'sap-icon://accept'
                                          WHEN mv_status = 'FAILED'  THEN 'sap-icon://error'
                                          ELSE 'sap-icon://pending' )
                           class = 'sapUiMediumMarginBegin sapUiSmallMarginTop' ).
    ENDIF.

    IF mt_fee IS NOT INITIAL.
      DATA(lo_fc) = page->vbox( class = 'sapUiContentPadding' ).
      lo_fc->title( text = 'Fees (get_fees, live)' ).
      DATA(lo_ft) = lo_fc->table( ).
      DATA(lo_fcol) = lo_ft->columns( ).
      lo_fcol->column( )->text( 'Description' ).
      lo_fcol->column( halign = 'End' )->text( 'Amount' ).
      DATA(lo_fitems) = lo_ft->items( ).
      LOOP AT mt_fee INTO DATA(ls_fe).
        DATA(lo_fcells) = lo_fitems->column_list_item( )->cells( ).
        lo_fcells->text( esc( ls_fe-desc ) ).
        lo_fcells->text( ls_fe-amount ).
      ENDLOOP.
      DATA(lo_tot) = lo_fc->hbox( justifycontent = 'End' alignitems = 'Center' class = 'sapUiSmallMarginTop' ).
      lo_tot->label( 'Total' ).
      lo_tot->object_number( number = mv_total numberunit = 'AED' emphasized = abap_true class = 'sapUiSmallMarginBegin' ).
    ENDIF.

    IF mt_op IS NOT INITIAL.
      DATA(lo_oc) = page->vbox( class = 'sapUiContentPadding' ).
      lo_oc->title( text = 'Gateway routing ops (route_gateway, live)' ).
      DATA(lo_ot) = lo_oc->table( ).
      DATA(lo_ocol) = lo_ot->columns( ).
      lo_ocol->column( )->text( 'Field' ).
      lo_ocol->column( )->text( 'Action' ).
      lo_ocol->column( )->text( 'Value' ).
      DATA(lo_oitems) = lo_ot->items( ).
      LOOP AT mt_op INTO DATA(ls_op).
        DATA(lo_ocells) = lo_oitems->column_list_item( )->cells( ).
        lo_ocells->text( esc( ls_op-fieldname ) ).
        lo_ocells->text( esc( ls_op-action ) ).
        lo_ocells->text( esc( ls_op-value ) ).
      ENDLOOP.
    ENDIF.

    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
    mo_client = client.
    IF mv_caseid IS INITIAL.
      mv_caseid  = '1958731'.
      mv_bp      = '1000116563'.
      mv_intreno = '1958731'.
    ENDIF.

    DATA(lv_event) = mo_client->get( )-event.
    CLEAR mt_msg.

    CASE lv_event.
      WHEN 'FEES'.  do_fees( ).
      WHEN 'ROUTE'. do_route( ).
      WHEN 'POLL'.  do_poll( ).
    ENDCASE.

    render( ).
  ENDMETHOD.
ENDCLASS.
