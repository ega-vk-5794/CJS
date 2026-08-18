CLASS zcl_rak_att_test DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_att_name TYPE string.
    DATA mv_att_b64  TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_row,
        name TYPE string,
        mime TYPE string,
        guid TYPE string,
      END OF ty_row,
      tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA mo_client TYPE REF TO z2ui5_if_client.
    DATA mt_att    TYPE tt_row.
    DATA mt_msg    TYPE zif_rak_journey=>tt_msg.

    METHODS render.
    METHODS uploader IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view.
    METHODS esc IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_ATT_TEST IMPLEMENTATION.


  METHOD esc.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'CJS - Attachment test harness' ).

    LOOP AT mt_msg INTO DATA(ls_m).
      page->message_strip( text = esc( ls_m-text ) type = ls_m-type showicon = abap_true class = 'sapUiSmallMargin' ).
    ENDLOOP.

    DATA(lo_card) = page->vbox( class = 'sapUiContentPadding' ).
    lo_card->title( text = 'Same-session: table (ZRAK_CJ_ATTX) + REST view' ).
    lo_card->text( text = 'Upload a file, confirm it stores and reads back, then click View to stream it through /sap/bc/rest/zrak_cj_att.' ).

    DATA(lo_tab) = lo_card->table( class = 'sapUiSmallMarginTop' ).
    DATA(lo_cols) = lo_tab->columns( ).
    lo_cols->column( )->text( '#' ).
    lo_cols->column( )->text( 'File' ).
    lo_cols->column( )->text( 'MIME' ).
    lo_cols->column( )->text( 'GUID' ).
    lo_cols->column( halign = 'End' )->text( '' ).
    DATA(lo_items) = lo_tab->items( ).
    DATA lv_i TYPE i.
    LOOP AT mt_att INTO DATA(ls_a).
      lv_i = sy-tabix.
      DATA(lo_cells) = lo_items->column_list_item( )->cells( ).
      lo_cells->text( |{ lv_i }| ).
      lo_cells->text( ls_a-name ).
      lo_cells->text( ls_a-mime ).
      lo_cells->text( ls_a-guid ).
      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( text  = 'View'
                      icon  = 'sap-icon://display'
                      type  = 'Transparent'
                      press = mo_client->_event( |VIEW{ lv_i }| ) ).
      lo_act->button( icon  = 'sap-icon://decline'
                      type  = 'Transparent'
                      tooltip = 'Remove'
                      press = mo_client->_event( |DEL{ lv_i }| ) ).
    ENDLOOP.

    uploader( lo_card ).

    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD uploader.
    io_box->input( value = mo_client->_bind_edit( mv_att_name ) class = 'rakHide rakAtN' ).
    io_box->input( value = mo_client->_bind_edit( mv_att_b64 )  class = 'rakHide rakAtB' ).
    io_box->button( text = 'go' class = 'rakHide rakAtG' press = mo_client->_event( 'ATTSAVE' ) ).

    DATA(lv_js) =
      `var f=this.files[0];if(!f)return;` &&
      `if(f.size>2097152){alert('Max 2 MB in this harness');this.value='';return;}` &&
      `var r=new FileReader();var me=this;` &&
      `r.onload=function(){` &&
      `var g=function(c){var el=document.querySelector(c);return sap.ui.getCore().byId(el.id);};` &&
      `g('.rakAtN').setValue(f.name);` &&
      `g('.rakAtB').setValue(r.result);` &&
      `g('.rakAtG').firePress();me.value='';};` &&
      `r.readAsDataURL(f);`.

    DATA(lv_html) =
      `<div class="rakUp"><input type="file" accept=".pdf,.jpg,.jpeg,.png" onchange="` && lv_js && `"/></div>` &&
      `<div><style>.rakHide{position:absolute!important;left:-9999px!important;width:1px!important;height:1px!important;overflow:hidden!important;}` &&
      `.rakUp input[type=file]{padding:.4rem;border:1px dashed #c7ccd4;border-radius:8px;background:#fafbfc;font-size:.82rem;max-width:22rem;margin-top:.6rem;}</style></div>`.

    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    io_box->html( content = lv_html sanitizecontent = abap_false ).
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
    mo_client = client.
    DATA(lv_event) = mo_client->get( )-event.

    IF lv_event = 'ATTSAVE'.
      CLEAR mt_msg.
      IF mv_att_b64 IS INITIAL.
        mt_msg = VALUE #( ( type = 'Warning' text = 'No file received (too large, or inline script blocked).' ) ).
      ELSE.
        DATA lv_msg TYPE string.
        DATA(lv_guid) = zcl_rak_cj_att_store=>put( EXPORTING iv_name = mv_att_name
                                                             iv_b64  = mv_att_b64
                                                   IMPORTING ev_msg  = lv_msg ).
        IF lv_guid IS INITIAL.
          mt_msg = VALUE #( ( type = 'Error' text = |{ mv_att_name }: { lv_msg }| ) ).
        ELSE.
          zcl_rak_cj_att_store=>get( EXPORTING iv_guid = lv_guid
                                     IMPORTING ev_name = DATA(lv_gn)
                                               ev_mime = DATA(lv_gm) ).
          APPEND VALUE #( name = lv_gn mime = lv_gm guid = lv_guid ) TO mt_att.
          mt_msg = VALUE #( ( type = 'Success' text = |{ mv_att_name } stored ({ lv_gm }) and read back OK| ) ).
        ENDIF.
      ENDIF.
      CLEAR: mv_att_name, mv_att_b64.

    ELSEIF strlen( lv_event ) > 4 AND substring( val = lv_event len = 4 ) = 'VIEW'.
      DATA(lv_v) = substring( val = lv_event off = 4 ).
      IF lv_v CO '0123456789'.
        READ TABLE mt_att INTO DATA(ls_v) INDEX CONV i( lv_v ).
        IF sy-subrc = 0.
          mo_client->follow_up_action(
            mo_client->_event_client(
              val   = z2ui5_if_client=>cs_event-open_new_tab
              t_arg = VALUE #( ( |/sap/bc/rest/zrak_cj_att?guid={ ls_v-guid }| ) ) ) ).
        ENDIF.
      ENDIF.

    ELSEIF strlen( lv_event ) > 3 AND substring( val = lv_event len = 3 ) = 'DEL'.
      DATA(lv_d) = substring( val = lv_event off = 3 ).
      IF lv_d CO '0123456789'.
        DATA(lv_ix) = CONV i( lv_d ).
        READ TABLE mt_att INTO DATA(ls_d) INDEX lv_ix.
        IF sy-subrc = 0.
          zcl_rak_cj_att_store=>delete( ls_d-guid ).
          DELETE mt_att INDEX lv_ix.
          mt_msg = VALUE #( ( type = 'Success' text = |{ ls_d-name } deleted from store| ) ).
        ENDIF.
      ENDIF.
    ENDIF.

    render( ).
  ENDMETHOD.
ENDCLASS.
