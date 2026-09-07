CLASS zcl_rak_battscrap_edit_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES: BEGIN OF ty_mat,
             row_uid TYPE string,
             mtype   TYPE string,
             qty     TYPE string,
             unit    TYPE string,
           END OF ty_mat,
           tt_mat TYPE STANDARD TABLE OF ty_mat WITH EMPTY KEY.

    " bound editable; persists because the app instance is serialized
    DATA mt_material TYPE tt_mat.

  PRIVATE SECTION.
    METHODS render
      IMPORTING client TYPE REF TO z2ui5_if_client.
    METHODS add_row.
    METHODS del_row
      IMPORTING iv_uid TYPE string.
ENDCLASS.



CLASS ZCL_RAK_BATTSCRAP_EDIT_TEST IMPLEMENTATION.


  METHOD add_row.
    APPEND VALUE #( row_uid = cl_system_uuid=>create_uuid_c32_static( ) ) TO mt_material.
  ENDMETHOD.


  METHOD del_row.
    DELETE mt_material WHERE row_uid = iv_uid.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'Batteries/Scrap - editable test' ).
    DATA(box)  = page->vbox( class = 'sapUiContentPadding' ).

    box->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center'
      )->title( 'Materials'
      )->get_parent( )->button(
          text  = 'Add Material'
          icon  = 'sap-icon://add'
          type  = 'Emphasized'
          press = client->_event( 'ADD_ROW' ) ).

    DATA(tab) = box->table( items = client->_bind_edit( mt_material ) ).
    tab->columns(
      )->column( )->text( 'Material Type'
      )->get_parent(
      )->column( )->text( 'Quantity'
      )->get_parent(
      )->column( )->text( 'Units'
      )->get_parent(
      )->column( width = '4rem' )->text( `` ).

    DATA(cells) = tab->items( )->column_list_item( )->cells( ).
    cells->input( value = `{MTYPE}` ).
    cells->input( value = `{QTY}` ).
    cells->combobox( selectedkey = `{UNIT}`
                     placeholder = 'select'
      )->item( key = 'KG'     text = 'KG'
      )->item( key = 'Ton'    text = 'Ton'
      )->item( key = 'Pieces' text = 'Pieces'
      )->item( key = 'Litre'  text = 'Litre' ).
    cells->button( icon  = 'sap-icon://delete'
                   type  = 'Transparent'
                   press = client->_event( val   = 'DEL_ROW'
                                           t_arg = VALUE #( ( `${ROW_UID}` ) ) ) ).

    client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
*   ---- DEVELOPMENT ONLY. THIS IS A TEST HARNESS. --------------------
*   Refuses anywhere but E10, before it touches anything.
*
*   The allowlist in Z2UI5_CL_CORE_ACTION->FACTORY_FIRST_START( ) already
*   stops this class being launched by app_start outside development, and
*   this is the second lock rather than a duplicate of the first: the
*   allowlist governs one entry point, whereas the class itself is what
*   any OTHER route would reach - a stack call, a bookmarked draft, a
*   later refactor of the handler, or a fourth name somebody adds to that
*   list without asking what the class does.
*
*   It exists because these classes CANNOT BE KEPT OUT OF PRODUCTION.
*   They are already in the package and the transport, and the ones that
*   carry hardcoded case ids, partner numbers and payment references are
*   exactly the ones that must not run against production data.
*
*   A test app is the one place where refusing on the wrong system is
*   free: there is no citizen to inconvenience and nothing to degrade to.
    IF zcl_rak_journey_util=>is_dev( ) = abap_false.
      client->message_box_display(
        text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-not_authorized
                                  iv_default = 'Not authorized.' )
        type = 'error' ).
      RETURN.
    ENDIF.


    IF client->check_on_init( ).
      render( client ).
      RETURN.
    ENDIF.

    CASE client->get( )-event.
      WHEN 'ADD_ROW'.
        add_row( ).
        render( client ).
      WHEN 'DEL_ROW'.
        del_row( client->get_event_arg( 1 ) ).
        render( client ).
    ENDCASE.

  ENDMETHOD.
ENDCLASS.
