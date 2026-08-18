CLASS zcl_rak_env_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_fee_calc       REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post     REDEFINITION.
ENDCLASS.



CLASS ZCL_RAK_ENV_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_before_post.
    APPEND VALUE #( key = 'SOURCE_CHANNEL' value = 'PORTAL' ) TO ct_kv.
    APPEND VALUE #( key = 'DEPARTMENT'     value = 'ENVIRONMENT' ) TO ct_kv.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
    IF io_ctx->get_val( 'HAZARDOUS' ) = 'Y' AND io_ctx->get_val( 'EIA_REF' ) IS INITIAL.
      APPEND VALUE #( type = 'Error'
        text = 'An EIA Reference is required when hazardous materials are involved' ) TO rt.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_fee_calc.
    DATA lv_years TYPE i.
    DATA(lv_raw) = io_ctx->get_val( 'PERMIT_YEARS' ).
    IF lv_raw IS NOT INITIAL AND lv_raw CO '0123456789. '.
      lv_years = lv_raw.
    ENDIF.
    IF lv_years < 1.
      lv_years = 1.
    ENDIF.

    DATA(lv_base) = 2500.
    DATA(lv_fee)  = lv_base * lv_years.
    IF io_ctx->get_val( 'HAZARDOUS' ) = 'Y'.
      lv_fee = lv_fee + 5000.
    ENDIF.

    io_ctx->set_val( iv_name = 'FEE' iv_value = |AED { lv_fee NUMBER = USER }| ).
  ENDMETHOD.
ENDCLASS.
