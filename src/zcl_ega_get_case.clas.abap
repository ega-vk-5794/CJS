class ZCL_EGA_GET_CASE definition
  public
  create public .

public section.

  interfaces IF_HTTP_EXTENSION .
protected section.
private section.
ENDCLASS.



CLASS ZCL_EGA_GET_CASE IMPLEMENTATION.


METHOD if_http_extension~handle_request.

*  DATA(lv_res) = server->request->get_method( ).
*  IF lv_res EQ 'GET'.
*    DATA(lv_resp) = z2ui5_cl_fw_http_handler=>http_get( ).
*  ELSEIF lv_res EQ 'POST'.
*    lv_resp =  z2ui5_cl_fw_http_handler=>http_post( server->request->get_cdata( ) ).
*  ENDIF.
*
*  server->response->set_header_field( name = `cache-control` value = `no-cache` ).
*  server->response->set_cdata( lv_resp ).
*  server->response->set_status( code = 200 reason = `success` ).


  z2ui5_cl_http_handler=>run( server ).

ENDMETHOD.
ENDCLASS.
