CLASS zcl_rak_cj_att_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.
    METHODS decode_data_url
      IMPORTING iv_content     TYPE string
      EXPORTING ev_mime        TYPE string
                ev_bin         TYPE xstring.
ENDCLASS.



CLASS ZCL_RAK_CJ_ATT_HTTP IMPLEMENTATION.


  METHOD decode_data_url.
    CLEAR: ev_mime, ev_bin.
    DATA lv_b64 TYPE string.

    IF strlen( iv_content ) >= 5 AND substring( val = iv_content len = 5 ) = 'data:'.
      DATA(lv_head) = substring_before( val = iv_content sub = ';base64,' ).
      IF lv_head IS NOT INITIAL.
        ev_mime = substring( val = lv_head off = 5 ).
      ENDIF.
      lv_b64 = substring_after( val = iv_content sub = ';base64,' ).
    ELSE.
      lv_b64 = iv_content.
    ENDIF.

    IF lv_b64 IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        ev_bin = cl_http_utility=>decode_x_base64( lv_b64 ).
      CATCH cx_root.
        CLEAR ev_bin.
    ENDTRY.
  ENDMETHOD.


  METHOD if_http_extension~handle_request.
    DATA(lv_guid) = server->request->get_form_field( 'guid' ).
    DATA(lv_dl)   = server->request->get_form_field( 'dl' ).

    IF lv_guid IS INITIAL.
      server->response->set_status( code = 400 reason = 'Missing guid' ).
      server->response->set_cdata( 'Missing guid parameter.' ).
      RETURN.
    ENDIF.

    zcl_rak_cj_att_store=>get(
      EXPORTING iv_guid  = lv_guid
                iv_uname = sy-uname
      IMPORTING ev_name  = DATA(lv_name)
                ev_mime  = DATA(lv_mime)
                ev_b64   = DATA(lv_content) ).

    IF lv_content IS INITIAL.
      server->response->set_status( code = 404 reason = 'Not found' ).
      server->response->set_cdata( 'Attachment not found or not accessible.' ).
      RETURN.
    ENDIF.

    decode_data_url(
      EXPORTING iv_content = lv_content
      IMPORTING ev_mime    = DATA(lv_hdr_mime)
                ev_bin     = DATA(lv_bin) ).

    IF lv_bin IS INITIAL.
      server->response->set_status( code = 500 reason = 'Decode failed' ).
      server->response->set_cdata( 'Attachment could not be decoded.' ).
      RETURN.
    ENDIF.

    DATA(lv_type) = COND string( WHEN lv_mime IS NOT INITIAL THEN lv_mime
                                 WHEN lv_hdr_mime IS NOT INITIAL THEN lv_hdr_mime
                                 ELSE 'application/octet-stream' ).

    DATA(lv_disp) = COND string( WHEN lv_dl = 'X'
                                 THEN |attachment; filename="{ lv_name }"|
                                 ELSE |inline; filename="{ lv_name }"| ).

    server->response->set_header_field( name = 'Content-Type'        value = lv_type ).
    server->response->set_header_field( name = 'Content-Disposition' value = lv_disp ).
    server->response->set_header_field( name = 'Cache-Control'       value = 'private, max-age=0, no-store' ).
    server->response->set_header_field( name = 'X-Content-Type-Options' value = 'nosniff' ).
    server->response->set_data( lv_bin ).
    server->response->set_status( code = 200 reason = 'OK' ).
  ENDMETHOD.
ENDCLASS.
