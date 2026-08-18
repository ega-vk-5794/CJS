*&---------------------------------------------------------------------*
*& ZCL_RAK_LICENSE_SAMPLE
*&
*& Standalone abap2UI5 sample: an investor's "open a new business
*& license" submission screen. Built the same way ZCL_RAK_DEMO_APP
*& was - no dependency on ZIF_RAK_JOURNEY, the backend factory, or any
*& journey customizing - but widened to showcase more of
*& Z2UI5_CL_XML_VIEW's control surface:
*&
*&   Header   - input, combobox, segmented_button (+ item), radio_button
*&              (grouped), step_input, switch, date_picker, text_area
*&   Items    - editable sap.m.Table (shareholders), add/delete rows by
*&              generated _UID, same pattern as ZCL_RAK_JOURNEY_GRID
*&   Attach   - same hidden-input + FileReader-onchange uploader as
*&              ZCL_RAK_DEMO_APP / ZCL_RAK_JOURNEY_RENDER->RENDER_UPLOADER
*&
*& All control APIs used here were verified against Z2UI5_CL_XML_VIEW's
*& own method signatures and against real call sites elsewhere in this
*& package (ZCL_RAK_JOURNEY_RENDER for segmented_button, ZCL_CJ_DEMO_P001
*& for radio_button) rather than guessed.
*&
*& To run it, register this class against an app id in your abap2UI5
*& app repository (Z2UI5_C_APPS or equivalent) and open it through your
*& usual abap2UI5 index.
*&---------------------------------------------------------------------*
CLASS zcl_rak_license_sample DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_serializable_object.
    INTERFACES z2ui5_if_app.

    TYPES: BEGIN OF ty_shareholder,
             _uid        TYPE string,
             full_name   TYPE string,
             nationality TYPE string,
             share_pct   TYPE string,
           END OF ty_shareholder,
           tt_shareholder TYPE STANDARD TABLE OF ty_shareholder WITH EMPTY KEY.

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

*   ---- Header: trade name / activity -----------------------------------
    DATA mv_trade_name    TYPE string.
    DATA mv_activity_key  TYPE string.       " combobox: business activity
    DATA mv_jurisdiction  TYPE string.       " segmented_button: Mainland / Free Zone
    DATA mv_legal_llc     TYPE abap_bool.    " radio group: legal structure
    DATA mv_legal_sole    TYPE abap_bool.
    DATA mv_legal_civil   TYPE abap_bool.
    DATA mv_shareholders_n TYPE string.      " step_input: number of shareholders (display only)
    DATA mv_needs_impexp  TYPE abap_bool.    " switch: import/export code required
    DATA mv_start_date    TYPE string.       " date_picker
    DATA mv_description   TYPE string.       " text_area

*   ---- Items: shareholders table ----------------------------------------
    DATA mt_shareholder TYPE tt_shareholder.

*   ---- Attachments --------------------------------------------------------
    DATA mt_attachment TYPE tt_attachment.
    DATA mv_att_name    TYPE string.
    DATA mv_att_b64     TYPE string.

    DATA mt_msg TYPE tt_msg.

  PRIVATE SECTION.

    DATA mo_client TYPE REF TO z2ui5_if_client.

    METHODS render.
    METHODS render_header      IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_shareholders IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_attachments IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS handle_submit.
    METHODS set_legal_structure IMPORTING iv_choice TYPE string.

ENDCLASS.



CLASS zcl_rak_license_sample IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    mo_client = client.
    CLEAR mt_msg.

    DATA(ls_get)   = client->get( ).
    DATA(lv_event) = ls_get-event.

    CASE lv_event.

      WHEN 'SHARE_ADD'.
        APPEND VALUE #( _uid = cl_system_uuid=>create_uuid_c32_static( ) ) TO mt_shareholder.

      WHEN 'SHARE_DEL'.
        DELETE mt_shareholder WHERE _uid = client->get_event_arg( 1 ).

      WHEN 'LEGAL_LLC'.
        set_legal_structure( 'LLC' ).

      WHEN 'LEGAL_SOLE'.
        set_legal_structure( 'SOLE' ).

      WHEN 'LEGAL_CIVIL'.
        set_legal_structure( 'CIVIL' ).

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


  METHOD set_legal_structure.
    mv_legal_llc   = xsdbool( iv_choice = 'LLC' ).
    mv_legal_sole  = xsdbool( iv_choice = 'SOLE' ).
    mv_legal_civil = xsdbool( iv_choice = 'CIVIL' ).
  ENDMETHOD.


  METHOD handle_submit.

    IF mv_trade_name IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Proposed trade name is required.' ) ).
      RETURN.
    ENDIF.

    IF mv_activity_key IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Select a business activity.' ) ).
      RETURN.
    ENDIF.

    IF mv_legal_llc = abap_false AND mv_legal_sole = abap_false AND mv_legal_civil = abap_false.
      mt_msg = VALUE #( ( type = 'Error' text = 'Choose a legal structure.' ) ).
      RETURN.
    ENDIF.

    IF mt_shareholder IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Add at least one shareholder.' ) ).
      RETURN.
    ENDIF.

    DATA lv_total TYPE decfloat34.
    LOOP AT mt_shareholder INTO DATA(ls_sh).
      lv_total = lv_total + CONV decfloat34( ls_sh-share_pct ).
    ENDLOOP.
    IF lv_total <> 100.
      mt_msg = VALUE #( ( type = 'Error'
        text = |Shareholder ownership must total 100%. It currently totals { lv_total }%.| ) ).
      RETURN.
    ENDIF.

    IF mt_attachment IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error' text = 'Attach at least one supporting document.' ) ).
      RETURN.
    ENDIF.

    mt_msg = VALUE #( ( type = 'Success'
      text = |License application submitted for "{ mv_trade_name }" - | &&
             |{ lines( mt_shareholder ) } shareholder(s), { lines( mt_attachment ) } attachment(s).| ) ).

  ENDMETHOD.


  METHOD render.

    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page(
      title         = 'New Business License Application'
      shownavbutton = abap_false ).

    page->html( content = `<style>.rakHide\{display:none;\}</style>` sanitizecontent = abap_false ).

    LOOP AT mt_msg INTO DATA(ls_msg).
      page->message_strip( text     = ls_msg-text
                            type     = ls_msg-type
                            showicon = abap_true
                            class    = 'sapUiSmallMargin' ).
    ENDLOOP.

    render_header( page ).
    render_shareholders( page ).
    render_attachments( page ).

    page->button( text  = 'Submit Application'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://paper-plane'
                  class = 'sapUiSmallMargin'
                  press = mo_client->_event( 'SUBMIT' ) ).

    mo_client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD render_header.

    DATA(lo_panel) = io_parent->panel( headertext = 'Business Details'
                                       expandable = abap_false
                                       class      = 'sapUiSmallMargin' ).

    DATA(lo_row1) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row1->label( text = 'Proposed Trade Name' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row1->input( value = mo_client->_bind_edit( mv_trade_name ) width = '18rem' required = abap_true ).

    DATA(lo_row2) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row2->label( text = 'Business Activity' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    DATA(lo_cb) = lo_row2->combobox( selectedkey = mo_client->_bind_edit( mv_activity_key ) width = '14rem' ).
    lo_cb->item( key = 'TRADING'      text = 'Trading' ).
    lo_cb->item( key = 'CONSULTING'   text = 'Consulting' ).
    lo_cb->item( key = 'MANUFACTURING' text = 'Manufacturing' ).
    lo_cb->item( key = 'IT_SERVICES'  text = 'IT Services' ).
    lo_cb->item( key = 'OTHER'        text = 'Other' ).

    DATA(lo_row3) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row3->label( text = 'Jurisdiction' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    DATA(lo_seg) = lo_row3->segmented_button( selected_key = mo_client->_bind_edit( mv_jurisdiction ) )->items( ).
    lo_seg->segmented_button_item( key = 'MAINLAND'  text = 'Mainland' ).
    lo_seg->segmented_button_item( key = 'FREEZONE'  text = 'Free Zone' ).

    DATA(lo_row4) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row4->label( text = 'Legal Structure' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row4->radio_button( text      = 'LLC'
                           groupname = 'legalStructure'
                           selected  = mo_client->_bind_edit( mv_legal_llc )
                           select    = mo_client->_event( 'LEGAL_LLC' ) ).
    lo_row4->radio_button( text      = 'Sole Establishment'
                           groupname = 'legalStructure'
                           selected  = mo_client->_bind_edit( mv_legal_sole )
                           select    = mo_client->_event( 'LEGAL_SOLE' ) ).
    lo_row4->radio_button( text      = 'Civil Company'
                           groupname = 'legalStructure'
                           selected  = mo_client->_bind_edit( mv_legal_civil )
                           select    = mo_client->_event( 'LEGAL_CIVIL' ) ).

    DATA(lo_row5) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row5->label( text = 'Expected Shareholder Count' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row5->step_input( value = mo_client->_bind_edit( mv_shareholders_n ) min = '1' max = '20' width = '8rem' ).

    DATA(lo_row6) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row6->label( text = 'Requires Import/Export Code' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row6->switch( state = mo_client->_bind_edit( mv_needs_impexp ) ).

    DATA(lo_row7) = lo_panel->hbox( class = 'sapUiSmallMarginBottom' alignitems = 'Center' ).
    lo_row7->label( text = 'Requested Start Date' class = 'sapUiFormLabelNoColon sapUiSmallMarginEnd' ).
    lo_row7->date_picker( value = mo_client->_bind_edit( mv_start_date ) ).

    DATA(lo_row8) = lo_panel->vbox( ).
    lo_row8->label( text = 'Business Activity Description' class = 'sapUiFormLabelNoColon' ).
    lo_row8->text_area( value = mo_client->_bind_edit( mv_description ) rows = '3' width = '100%' ).

  ENDMETHOD.


  METHOD render_shareholders.

    DATA(lo_panel) = io_parent->panel( headertext = 'Shareholders'
                                       expandable = abap_false
                                       class      = 'sapUiSmallMargin' ).

    DATA(lo_bar) = lo_panel->hbox( justifycontent = 'End' class = 'sapUiTinyMarginBottom' ).
    lo_bar->button( text  = 'Add Shareholder'
                    icon  = 'sap-icon://add'
                    type  = 'Emphasized'
                    press = mo_client->_event( 'SHARE_ADD' ) ).

    DATA(lo_tab) = lo_panel->table( items              = mo_client->_bind_edit( mt_shareholder )
                                    alternaterowcolors = abap_true ).

    DATA(lo_cols) = lo_tab->columns( ).
    lo_cols->column( )->text( `Full Name` ).
    lo_cols->column( )->text( `Nationality` ).
    lo_cols->column( )->text( `Ownership %` ).
    lo_cols->column( width = '4rem' halign = 'End' )->text( `` ).

    DATA(lo_cells) = lo_tab->items( )->column_list_item( )->cells( ).
    lo_cells->input( value = `{full_name}` ).
    lo_cells->input( value = `{nationality}` ).
    lo_cells->input( value = `{share_pct}` type = 'Number' ).
    lo_cells->button(
      icon  = 'sap-icon://delete'
      type  = 'Transparent'
      press = mo_client->_event( val = 'SHARE_DEL' t_arg = VALUE #( ( `${_UID}` ) ) ) ).

  ENDMETHOD.


  METHOD render_attachments.

    DATA(lo_panel) = io_parent->panel( headertext = 'Supporting Documents'
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
*   handler - the same trick ZCL_RAK_JOURNEY_RENDER->RENDER_UPLOADER and
*   ZCL_RAK_DEMO_APP use, because a plain sap.m.FileUploader does not
*   two-way bind to an ABAP string in this z2ui5 version.
    DATA(lo_up) = lo_panel->vbox( class = 'sapUiSmallMarginTop' ).

    lo_up->input( value = mo_client->_bind_edit( mv_att_name ) class = 'rakHide rakLicAttName' ).
    lo_up->input( value = mo_client->_bind_edit( mv_att_b64 )  class = 'rakHide rakLicAttB64' ).
    lo_up->button( text  = 'go'
                   class = 'rakHide rakLicAttGo'
                   press = mo_client->_event( 'ATTACH_SAVE' ) ).

    DATA(lv_js) =
      `var f=this.files[0];if(!f)return;` &&
      `if(f.size>5242880){alert('Maximum file size is 5 MB');this.value='';return;}` &&
      `var r=new FileReader();var me=this;` &&
      `r.onload=function(){` &&
      `var g=function(c){var el=document.querySelector(c);return sap.ui.getCore().byId(el.id);};` &&
      `g('.rakLicAttName').setValue(f.name);` &&
      `g('.rakLicAttB64').setValue(r.result);` &&
      `g('.rakLicAttGo').firePress();me.value='';};` &&
      `r.readAsDataURL(f);`.

    DATA(lv_html) =
      `<div><label style="cursor:pointer;color:#0854a0;"><span>Choose passport copy / trade name certificate / NOC</span>` &&
      `<input type="file" style="display:none" accept=".pdf,.jpg,.jpeg,.png" onchange="` && lv_js && `"/></label></div>`.

    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.

    lo_up->html( content = lv_html sanitizecontent = abap_false ).

  ENDMETHOD.

ENDCLASS.
