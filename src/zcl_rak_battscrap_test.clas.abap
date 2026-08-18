CLASS zcl_rak_battscrap_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES: BEGIN OF ty_mat,
             mtype TYPE string,
             qty   TYPE string,
             unit  TYPE string,
           END OF ty_mat,
           tt_mat TYPE STANDARD TABLE OF ty_mat WITH EMPTY KEY.

    " persisted across round-trips (same blob contract as the real handler)
    DATA mv_blob     TYPE string.
    " popup/add scratch, bound editable
    DATA mv_pop_mat  TYPE string.
    DATA mv_pop_qty  TYPE string.
    DATA mv_pop_unit TYPE string.
    " rebuilt each render, bound read-only to the table
    DATA mt_display  TYPE tt_mat.

  PRIVATE SECTION.
    CONSTANTS c_rowsep TYPE c LENGTH 1 VALUE '|'.
    CONSTANTS c_colsep TYPE c LENGTH 1 VALUE '~'.

    METHODS render
      IMPORTING client TYPE REF TO z2ui5_if_client.
    METHODS blob_read
      RETURNING VALUE(rt) TYPE tt_mat.
    METHODS blob_write
      IMPORTING it_mat TYPE tt_mat.
    METHODS to_num
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE decfloat34.
    METHODS add_row
      IMPORTING client TYPE REF TO z2ui5_if_client.
    METHODS del_row
      IMPORTING iv_mtype TYPE string.
ENDCLASS.



CLASS ZCL_RAK_BATTSCRAP_TEST IMPLEMENTATION.


  METHOD add_row.
    DATA(lv_m) = condense( mv_pop_mat ).
    DATA(lv_q) = condense( mv_pop_qty ).
    DATA(lv_u) = condense( mv_pop_unit ).

    IF lv_m IS INITIAL OR lv_q IS INITIAL OR lv_u IS INITIAL.
      client->message_toast_display( 'Material type, quantity and units are all required.' ).
      RETURN.
    ENDIF.
    IF lv_m CS c_rowsep OR lv_m CS c_colsep.
      client->message_toast_display( |Material type must not contain { c_rowsep } or { c_colsep }.| ).
      RETURN.
    ENDIF.
    IF to_num( lv_q ) <= 0.
      client->message_toast_display( 'Quantity must be a positive number.' ).
      RETURN.
    ENDIF.

    DATA(lt_mat) = blob_read( ).
    IF line_exists( lt_mat[ mtype = lv_m ] ).
      client->message_toast_display( |{ lv_m } is already in the list.| ).
      RETURN.
    ENDIF.

    APPEND VALUE #( mtype = lv_m qty = lv_q unit = lv_u ) TO lt_mat.
    blob_write( lt_mat ).
    CLEAR: mv_pop_mat, mv_pop_qty, mv_pop_unit.
  ENDMETHOD.


  METHOD blob_read.
    CHECK mv_blob IS NOT INITIAL.
    SPLIT mv_blob AT c_rowsep INTO TABLE DATA(lt_row).
    LOOP AT lt_row INTO DATA(lv_row).
      IF lv_row IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT lv_row AT c_colsep INTO DATA(lv_m) DATA(lv_q) DATA(lv_u).
      IF lv_m IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( mtype = lv_m qty = lv_q unit = lv_u ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD blob_write.
    DATA lv_blob TYPE string.
    LOOP AT it_mat INTO DATA(ls).
      DATA(lv_row) = |{ ls-mtype }{ c_colsep }{ ls-qty }{ c_colsep }{ ls-unit }|.
      lv_blob = COND #( WHEN lv_blob IS INITIAL
                        THEN lv_row
                        ELSE |{ lv_blob }{ c_rowsep }{ lv_row }| ).
    ENDLOOP.
    mv_blob = lv_blob.
  ENDMETHOD.


  METHOD del_row.
    DATA(lt_mat) = blob_read( ).
    DELETE lt_mat WHERE mtype = iv_mtype.
    blob_write( lt_mat ).
  ENDMETHOD.


  METHOD render.
    mt_display = blob_read( ).

    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'Batteries/Scrap - test harness' ).
    DATA(box)  = page->vbox( class = 'sapUiContentPadding' ).

    DATA(form) = box->simple_form( title    = 'Add material'
                                   editable = abap_true ).
    form->label( 'Material type' ).
    form->input( value = client->_bind_edit( mv_pop_mat ) ).
    form->label( 'Quantity' ).
    form->input( value = client->_bind_edit( mv_pop_qty ) ).
    form->label( 'Units' ).
    form->combobox( selectedkey = client->_bind_edit( mv_pop_unit )
                    placeholder = 'select'
      )->item( key = 'KG'     text = 'KG'
      )->item( key = 'Ton'    text = 'Ton'
      )->item( key = 'Pieces' text = 'Pieces'
      )->item( key = 'Litre'  text = 'Litre' ).

    box->button( text  = 'Add Material'
                 icon  = 'sap-icon://add'
                 type  = 'Emphasized'
                 class = 'sapUiSmallMarginTop sapUiSmallMarginBottom'
                 press = client->_event( 'ADD' ) ).

    box->title( 'Materials' ).

    DATA(tab) = box->table( items = client->_bind( mt_display ) ).
    tab->columns(
      )->column( )->text( 'Material Type'
      )->get_parent(
      )->column( )->text( 'Quantity'
      )->get_parent(
      )->column( )->text( 'Units'
      )->get_parent(
      )->column( width = '4rem' )->text( `` ).

    DATA(cells) = tab->items( )->column_list_item( )->cells( ).
    cells->text( '{MTYPE}' ).
    cells->text( '{QTY}' ).
    cells->text( '{UNIT}' ).
    cells->button( icon  = 'sap-icon://delete'
                   type  = 'Transparent'
                   press = client->_event( val   = 'DEL'
                                           t_arg = VALUE #( ( `${MTYPE}` ) ) ) ).

    client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD to_num.
    TRY.
        rv = CONV decfloat34( condense( iv ) ).
      CATCH cx_sy_conversion_no_number.
        CLEAR rv.
    ENDTRY.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      render( client ).
      RETURN.
    ENDIF.

    CASE client->get( )-event.
      WHEN 'ADD'.
        add_row( client ).
        render( client ).
      WHEN 'DEL'.
        del_row( client->get_event_arg( 1 ) ).
        render( client ).
    ENDCASE.

  ENDMETHOD.
ENDCLASS.
