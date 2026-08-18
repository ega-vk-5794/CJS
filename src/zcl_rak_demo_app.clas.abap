*&---------------------------------------------------------------------*
*& ZCL_RAK_DEMO_APP
*&
*& Standalone abap2UI5 app demonstrating a header / items / attachments
*& scenario using the same z2ui5_cl_xml_view primitives the CJS
*& framework itself uses (see ZCL_RAK_JOURNEY_RENDER->RENDER_UPLOADER
*& and ZCL_RAK_JOURNEY_GRID->RENDER_GRID for the originals this was
*& modelled on). Deliberately has NO dependency on ZIF_RAK_JOURNEY,
*& the backend factory, or any journey customizing - it carries its
*& own data model and is meant to be activated and run on its own to
*& exercise the framework's UI mechanics: a header form, an editable
*& item table (add/delete rows), and a file attachment uploader built
*& from a hidden bound input + a hidden button fired by a FileReader
*& onchange handler.
*&
*& To actually run it as an app, register this class against an app
*& id in your abap2UI5 app repository (Z2UI5_C_APPS or equivalent) and
*& open it through /ui5/apps or your usual abap2UI5 index.
*&---------------------------------------------------------------------*
CLASS zcl_rak_demo_app DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_serializable_object.
    INTERFACES z2ui5_if_app.

    TYPES: BEGIN OF ty_item,
             _uid        TYPE string,
             description TYPE string,
             quantity    TYPE string,
             amount      TYPE string,
           END OF ty_item,
           tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    TYPES: BEGIN OF ty_attachment,
             file_name TYPE string,
             size_kb   TYPE string,
           END OF ty_attachment,
           tt_attachment TYPE STANDARD TABLE OF ty_attachment WITH EMPTY KEY.

    TYPES: BEGIN OF ty_msg,
             type TYPE string,
             text TYPE string,
           END OF ty_msg,
           tt_msg TYPE STANDARD TABLE OF ty_msg WITH EMPTY KEY.

    DATA mv_request_no   TYPE string.
    DATA mv_requester    TYPE string.
    DATA mv_request_date TYPE string.
    DATA mt_item         TYPE tt_item.
    DATA mt_attachment   TYPE tt_attachment.
    DATA mv_att_name     TYPE string.
    DATA mv_att_b64      TYPE string.
    DATA mt_msg          TYPE tt_msg.

  PRIVATE SECTION.

    DATA mo_client TYPE REF TO z2ui5_if_client.

    METHODS render.
    METHODS render_header      IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_items       IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_attachments IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS handle_submit.

ENDCLASS.



CLASS zcl_rak_demo_app IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    mo_client = client.
    CLEAR mt_msg.

    DATA(ls_get)   = client->get( ).
    DATA(lv_event) = ls_get-event.

    CASE lv_event.

      WHEN 'ITEM_ADD'.
        APPEND VALUE #( _uid = cl_system_uuid=>create_uuid_c32_static( ) ) TO mt_item.

      WHEN 'ITEM_DEL'.
        DELETE mt_item WHERE _uid = client->get_event_arg( 1 ).

      WHEN 'ATTACH_SAVE'.
        IF mv_att_b64 IS INITIAL.
          mt_msg = VALUE #( ( type = 'Warning' text = 'Choose a file before attaching.' ) ).
        ELSE.
          DATA(lv_kb) = CONV decfloat34( strlen( mv_att_b64 ) ) * 3 / 4 / 1024.
          APPEND VALUE #( file_name = mv_att_name
                          size_kb   = |{ lv_kb DECIMALS = 1 }| ) TO mt_attachment.
          mt_msg = VALUE #( ( type = 'Success' text = |{ mv_att_name } attached.| ) ).
          CLEAR: mv_att_name, mv_att_b64.
        ENDIF.

      WHEN 'SUBMIT'.
        handle_submit( ).

    ENDCASE.

    render( ).

  ENDMETHOD.


  METHOD handle_submit.

    IF mv_requester IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Requester name is required.' ) ).
      RETURN.
    ENDIF.

    IF mt_item IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Add at least one item before submitting.' ) ).
      RETURN.
    ENDIF.

    IF mt_attachment IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Attach at least one supporting document.' ) ).
      RETURN.
    ENDIF.

    mt_msg = VALUE #( ( type = 'Success'
      text = |Scenario submitted - { lines( mt_item ) } item(s), | &&
             |{ lines( mt_attachment ) } attachment(s).| ) ).

  ENDMETHOD.


  METHOD render.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page(
      title         = 'CJS Framework Demo - Header / Items / Attachments'
      shownavbutton = abap_false ).

    page->html( content = `<style>.rakHide\{display:none;\}</style>` sanitizecontent = abap_false ).

    LOOP AT mt_msg INTO DATA(ls_msg).
      page->message_strip( text     = ls_msg-text
                            type     = ls_msg-type
                            showicon = abap_true
                            class    = 'sapUiSmallMargin' ).
    ENDLOOP.

    render_header( page ).
    render_items( page ).
    render_attachments( page ).

    page->button( text  = 'Submit'
                  type  = 'Emphasized'
                  class = 'sapUiSmallMargin'
                  press = mo_client->_event( 'SUBMIT' ) ).

    mo_client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD render_header.

    DATA(lo_panel) = io_parent->panel( headertext = 'Header'
                                       expandable = abap_false
                                       class      = 'sapUiSmallMargin' ).

    DATA(lo_row1) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' ).
    lo_row1->label( text = 'Request No.' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row1->input( value = mo_client->_bind_edit( mv_request_no ) width = '12rem' ).

    DATA(lo_row2) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' ).
    lo_row2->label( text = 'Requester Name' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row2->input( value = mo_client->_bind_edit( mv_requester ) width = '18rem' ).

    DATA(lo_row3) = lo_panel->hbox( ).
    lo_row3->label( text = 'Request Date' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row3->date_picker( value = mo_client->_bind_edit( mv_request_date ) ).

  ENDMETHOD.


  METHOD render_items.

    DATA(lo_panel) = io_parent->panel( headertext = 'Items'
                                       expandable = abap_false
                                       class      = 'sapUiSmallMargin' ).

    DATA(lo_bar) = lo_panel->hbox( justifycontent = 'End' class = 'sapUiTinyMarginBottom' ).
    lo_bar->button( text  = 'Add Item'
                    icon  = 'sap-icon://add'
                    type  = 'Emphasized'
                    press = mo_client->_event( 'ITEM_ADD' ) ).

    DATA(lo_tab) = lo_panel->table( items              = mo_client->_bind_edit( mt_item )
                                    alternaterowcolors = abap_true ).

    DATA(lo_cols) = lo_tab->columns( ).
    lo_cols->column( )->text( `Description` ).
    lo_cols->column( )->text( `Quantity` ).
    lo_cols->column( )->text( `Amount` ).
    lo_cols->column( width = '4rem' halign = 'End' )->text( `` ).

    DATA(lo_cells) = lo_tab->items( )->column_list_item( )->cells( ).
    lo_cells->input( value = `{description}` ).
    lo_cells->input( value = `{quantity}` type = 'Number' ).
    lo_cells->input( value = `{amount}`   type = 'Number' ).
    lo_cells->button(
      icon  = 'sap-icon://delete'
      type  = 'Transparent'
      press = mo_client->_event( val = 'ITEM_DEL' t_arg = VALUE #( ( `${_UID}` ) ) ) ).

  ENDMETHOD.


  METHOD render_attachments.

    DATA(lo_panel) = io_parent->panel( headertext = 'Attachments'
                                       expandable = abap_false
                                       class      = 'sapUiSmallMargin' ).

    DATA(lo_tab) = lo_panel->table( items = mo_client->_bind_edit( mt_attachment ) ).
    DATA(lo_cols) = lo_tab->columns( ).
    lo_cols->column( )->text( `File` ).
    lo_cols->column( )->text( `Size (KB)` ).

    DATA(lo_cells) = lo_tab->items( )->column_list_item( )->cells( ).
    lo_cells->text( text = `{file_name}` ).
    lo_cells->text( text = `{size_kb}` ).

*   Hidden bound fields + hidden button, driven by a FileReader onchange
*   handler - the same trick ZCL_RAK_JOURNEY_RENDER->RENDER_UPLOADER
*   uses, because a plain sap.m.FileUploader does not two-way bind to an
*   ABAP string in this z2ui5 version.
    DATA(lo_up) = lo_panel->vbox( class = 'sapUiSmallMarginTop' ).

    lo_up->input( value = mo_client->_bind_edit( mv_att_name ) class = 'rakHide rakDemoAttName' ).
    lo_up->input( value = mo_client->_bind_edit( mv_att_b64 )  class = 'rakHide rakDemoAttB64' ).
    lo_up->button( text  = 'go'
                   class = 'rakHide rakDemoAttGo'
                   press = mo_client->_event( 'ATTACH_SAVE' ) ).

    DATA(lv_js) =
      `var f=this.files[0];if(!f)return;` &&
      `if(f.size>2097152){alert('Maximum file size is 2 MB');this.value='';return;}` &&
      `var r=new FileReader();var me=this;` &&
      `r.onload=function(){` &&
      `var g=function(c){var el=document.querySelector(c);return sap.ui.getCore().byId(el.id);};` &&
      `g('.rakDemoAttName').setValue(f.name);` &&
      `g('.rakDemoAttB64').setValue(r.result);` &&
      `g('.rakDemoAttGo').firePress();me.value='';};` &&
      `r.readAsDataURL(f);`.

    DATA(lv_html) =
      `<div><label style="cursor:pointer;color:#0854a0;"><span>Choose file to attach</span>` &&
      `<input type="file" style="display:none" onchange="` && lv_js && `"/></label></div>`.

    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.

    lo_up->html( content = lv_html sanitizecontent = abap_false ).

  ENDMETHOD.

ENDCLASS.
