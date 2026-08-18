CLASS zcl_rak_gv_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_search      REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post REDEFINITION.
ENDCLASS.



CLASS ZCL_RAK_GV_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_before_post.
    APPEND VALUE #( key = 'SOURCE_CHANNEL' value = 'PORTAL' ) TO ct_kv.
    APPEND VALUE #( key = 'DEPARTMENT'     value = 'RESIDENCY' ) TO ct_kv.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    DATA(lv_idval) = io_ctx->get_val( iv_field ).
    IF lv_idval IS INITIAL.
      RETURN.
    ENDIF.

*   WIRE HERE: call the BP search (bp_query / businesspartners_get_entityset)
*   using lv_idval and the chosen id type io_ctx->get_val( |{ iv_field }_IDTYPE| ),
*   then io_ctx->set_val(...) from the returned structure.
    io_ctx->set_val( iv_name = 'NAME'        iv_value = 'Moaaz Hassan Al Hassan' ).
    io_ctx->set_val( iv_name = 'EMIRATES_ID' iv_value = '784-1956-6257327-7' ).
    io_ctx->set_val( iv_name = 'NATIONALITY' iv_value = 'United Arab Emirates' ).
    io_ctx->set_val( iv_name = 'SUM_NAME'    iv_value = 'Moaaz Hassan Al Hassan' ).
    io_ctx->set_val( iv_name = 'STATUS'      iv_value = 'Eligible - documents pending review' ).
  ENDMETHOD.
ENDCLASS.
