CLASS zcl_rak_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS call
      IMPORTING iv_api             TYPE string
                iv_path            TYPE string OPTIONAL
                iv_method          TYPE string DEFAULT 'GET'
                iv_payload         TYPE string OPTIONAL
                it_headers         TYPE tihttpnvp OPTIONAL
                it_params          TYPE tihttpnvp OPTIONAL
                it_url_replace     TYPE tihttpnvp OPTIONAL
                it_form            TYPE tihttpnvp OPTIONAL
                it_files           TYPE ztt_ega_my_attachment OPTIONAL
                iv_use_proxy       TYPE abap_bool DEFAULT abap_false
      EXPORTING ev_status          TYPE i
                ev_reason          TYPE string
                ev_xresponse       TYPE xstring
      RETURNING VALUE(ev_response) TYPE string.

  PRIVATE SECTION.

    CLASS-METHODS client
      IMPORTING iv_api           TYPE string
                iv_path          TYPE string
                it_url_replace   TYPE tihttpnvp
                iv_use_proxy     TYPE abap_bool
      RETURNING VALUE(eo_client) TYPE REF TO if_http_client.

ENDCLASS.



CLASS ZCL_RAK_HTTP IMPLEMENTATION.


  METHOD call.

    DATA(lo_client) = client( iv_api         = iv_api
                              iv_path        = iv_path
                              it_url_replace = it_url_replace
                              iv_use_proxy   = iv_use_proxy ).

    CHECK lo_client IS NOT INITIAL.

    lo_client->request->set_method( iv_method ).

    IF it_form[] IS NOT INITIAL OR it_files[] IS NOT INITIAL.
      lo_client->request->set_content_type( 'multipart/form-data' ).
      lo_client->request->set_header_field( name = 'Accept' value = '*/*' ).
      lo_client->request->set_formfield_encoding(
        formfield_encoding = cl_http_request=>if_http_entity~co_encoding_raw ).
    ELSEIF iv_payload IS NOT INITIAL.
      lo_client->request->set_content_type( 'application/json' ).
    ENDIF.

    IF it_headers[] IS NOT INITIAL.
      lo_client->request->set_header_fields( it_headers ).
    ENDIF.

    IF iv_payload IS NOT INITIAL.
      lo_client->request->set_cdata( iv_payload ).
    ENDIF.

    LOOP AT it_form INTO DATA(ls_form).
      DATA(lo_part) = lo_client->request->add_multipart( ).
      lo_part->set_header_field(
        name  = if_http_header_fields=>content_disposition
        value = |form-data;name="{ ls_form-name }"| ).
      lo_part->append_cdata( ls_form-value ).
    ENDLOOP.

    LOOP AT it_files INTO DATA(ls_file).
      lo_part = lo_client->request->add_multipart( ).
      lo_part->set_content_type( content_type = ls_file-file_mime_type ).
      lo_part->set_formfield_encoding(
        formfield_encoding = cl_http_request=>if_http_entity~co_encoding_raw ).
      lo_part->set_header_field(
        name  = if_http_header_fields=>content_disposition
        value = |form-data;name="{ ls_file-file_descr }";filename="{ ls_file-file_name }"| ).
      lo_part->set_data( data = ls_file-file_data ).
    ENDLOOP.

    IF it_params[] IS NOT INITIAL.
      lo_client->request->set_form_fields( it_params ).
    ENDIF.

    lo_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).

    lo_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    lo_client->response->get_status( IMPORTING code   = ev_status
                                               reason = DATA(lv_reason) ).
    ev_reason = lv_reason.

    IF ev_xresponse IS REQUESTED.
      ev_xresponse = lo_client->response->get_data( ).
    ELSE.
      ev_response = lo_client->response->get_cdata( ).
    ENDIF.

    lo_client->close( ).

  ENDMETHOD.


  METHOD client.

    DATA: BEGIN OF ls_cfg,
            url      TYPE string,
            username TYPE string,
            password TYPE string,
          END OF ls_cfg.

    ls_cfg-url      = 'https://rakqaecmicn.ega.lan/NOTARYES/api/v1'.

    CHECK sy-subrc = 0.

    DATA(lv_url) = |{ ls_cfg-url }{ iv_path }|.

    LOOP AT it_url_replace INTO DATA(ls_rep).
      REPLACE ALL OCCURRENCES OF ls_rep-name IN lv_url WITH ls_rep-value.
    ENDLOOP.

    DATA lv_proxy_host TYPE string.
    DATA lv_proxy_srvc TYPE string.

    IF iv_use_proxy = abap_true.
      zcl_rise_proxy_util=>get_rise_proxy_values(
        IMPORTING
          rise_proxy_host    = lv_proxy_host
          rise_proxy_service = lv_proxy_srvc ).
    ENDIF.

    cl_http_client=>create_by_url(
      EXPORTING
        url                = lv_url
        proxy_host         = lv_proxy_host
        proxy_service      = lv_proxy_srvc
        ssl_id             = 'ANONYM'
      IMPORTING
        client             = eo_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4 ).

    CHECK sy-subrc = 0.

    IF ls_cfg-username IS NOT INITIAL.
      eo_client->authenticate( username = CONV #( ls_cfg-username )
                               password = CONV #( ls_cfg-password ) ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
