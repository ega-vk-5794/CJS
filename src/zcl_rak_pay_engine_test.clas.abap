CLASS zcl_rak_pay_engine_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*---------------------------------------------------------------------------------------*
* Program Title     : CJS Payment Engine - test harness
* Object Description: Disposable abap2UI5 app to validate ZCL_RAK_PAY_ENGINE methods
*                     (poll_status / get_fees / route_gateway / check_lock) against
*                     real data. Launch: ?app_start=zcl_rak_pay_engine_test
*                     NOT part of the framework - delete once the engine renders RAKPAY.
*---------------------------------------------------------------------------------------*

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app .

    DATA mv_caseid  TYPE string .
    DATA mv_intreno TYPE string .
    DATA mv_bp      TYPE string .
    DATA mv_out     TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_client TYPE REF TO z2ui5_if_client .

    METHODS render .
    METHODS run_fees .
    METHODS run_route .
    METHODS run_lock .
    METHODS run_poll .
ENDCLASS.



CLASS ZCL_RAK_PAY_ENGINE_TEST IMPLEMENTATION.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'Payment Engine Test' ).

    DATA(form) = page->simple_form( title = 'Context' editable = abap_true
      )->content( ns = 'form' ).

    form->label( 'Case ID (ext_key)' ).
    form->input( mo_client->_bind_edit( mv_caseid ) ).

    form->label( 'Intreno (poll)' ).
    form->input( mo_client->_bind_edit( mv_intreno ) ).

    form->label( 'BP' ).
    form->input( mo_client->_bind_edit( mv_bp ) ).

    DATA(bar) = page->hbox( ).
    bar->button( text = 'Get Fees'      press = mo_client->_event( 'FEES' ) ).
    bar->button( text = 'Route Gateway' press = mo_client->_event( 'ROUTE' ) ).
    bar->button( text = 'Check Lock'    press = mo_client->_event( 'LOCK' ) ).
    bar->button( text = 'Poll Status'   press = mo_client->_event( 'POLL' )
                 type  = 'Emphasized' ).

    page->text_area(
      value    = mo_client->_bind( mv_out )
      rows     = '18'
      width    = '100%'
      editable = abap_false ).

    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD run_fees.
    DATA lo_pay TYPE REF TO zcl_rak_pay_engine.

    lo_pay = NEW zcl_rak_pay_engine( iv_caseid = CONV #( mv_caseid ) ).

    lo_pay->get_fees( IMPORTING et_fee = DATA(lt_fee) ev_total = DATA(lv_total) ).

    mv_out = |GET_FEES for case { mv_caseid }\n|.
    IF lt_fee IS INITIAL.
      mv_out = mv_out && |(no fee rows returned)\n|.
    ENDIF.
    LOOP AT lt_fee ASSIGNING FIELD-SYMBOL(<f>).
      mv_out = mv_out && |{ <f>-desc }  :  { <f>-amount NUMBER = USER }\n|.
    ENDLOOP.
    mv_out = mv_out && |------------------------------\n|.
    mv_out = mv_out && |TOTAL : { lv_total NUMBER = USER }|.
  ENDMETHOD.


  METHOD run_lock.
    DATA lo_pay TYPE REF TO zcl_rak_pay_engine.
    DATA lt_msg TYPE bapiret2_t.

    lo_pay = NEW zcl_rak_pay_engine( iv_caseid = CONV #( mv_caseid )
                                     iv_bp     = CONV #( mv_bp ) ).

    DATA(lv_stop) = lo_pay->check_lock( IMPORTING et_messages = lt_msg ).

    mv_out = |CHECK_LOCK for case { mv_caseid }\n|.
    mv_out = mv_out && |STOP = { lv_stop }\n|.
    LOOP AT lt_msg ASSIGNING FIELD-SYMBOL(<m>).
      mv_out = mv_out && |{ <m>-type } { <m>-id }/{ <m>-number } | &&
               |v1={ <m>-message_v1 } v2={ <m>-message_v2 }\n|.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_poll.
    DATA lo_pay TYPE REF TO zcl_rak_pay_engine.

    lo_pay = NEW zcl_rak_pay_engine( iv_intreno = mv_intreno ).

    DATA(lv_status) = lo_pay->poll_status( iv_intreno = mv_intreno ).

    mv_out = |POLL_STATUS for intreno { mv_intreno }\n|.
    mv_out = mv_out && |RESULT = { lv_status }\n\n|.
    mv_out = mv_out && |( SUCCESS / FAILED = terminal, spinner stops\n|.
    mv_out = mv_out && |  OPEN = keep revolving, poll again )|.
  ENDMETHOD.


  METHOD run_route.
    DATA lo_pay TYPE REF TO zcl_rak_pay_engine.

    lo_pay = NEW zcl_rak_pay_engine( iv_caseid = CONV #( mv_caseid ) ).

    DATA(lt_ops) = lo_pay->route_gateway( ).

    mv_out = |ROUTE_GATEWAY for case { mv_caseid }\n|.
    IF lt_ops IS INITIAL.
      mv_out = mv_out && |(no ops - no dfkkop / zdt_pg_dep_map entry)\n|.
    ENDIF.
    LOOP AT lt_ops ASSIGNING FIELD-SYMBOL(<o>).
      mv_out = mv_out && |{ <o>-fieldname }  ->  { <o>-action }| &&
               COND #( WHEN <o>-value IS NOT INITIAL THEN | = { <o>-value }| ) && |\n|.
    ENDLOOP.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
    mo_client = client.

    IF client->check_on_init( ).
      render( ).
      RETURN.
    ENDIF.

    CASE client->get( )-event.
      WHEN 'FEES'.  run_fees( ).
      WHEN 'ROUTE'. run_route( ).
      WHEN 'LOCK'.  run_lock( ).
      WHEN 'POLL'.  run_poll( ).
    ENDCASE.

    mo_client->view_model_update( ).
  ENDMETHOD.
ENDCLASS.
