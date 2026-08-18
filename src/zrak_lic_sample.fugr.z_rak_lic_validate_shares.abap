FUNCTION z_rak_lic_validate_shares.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_PERCENTAGES) TYPE  STRING
*"  EXPORTING
*"     VALUE(EV_TOTAL) TYPE  STRING
*"     VALUE(EV_VALID) TYPE  ABAP_BOOL
*"----------------------------------------------------------------------

  DATA lt_part  TYPE TABLE OF string.
  DATA lv_total TYPE decfloat34.

  SPLIT iv_percentages AT ',' INTO TABLE lt_part.

  LOOP AT lt_part INTO DATA(lv_part).
    CONDENSE lv_part.
    IF lv_part IS NOT INITIAL.
      lv_total = lv_total + CONV decfloat34( lv_part ).
    ENDIF.
  ENDLOOP.

  ev_total = |{ lv_total DECIMALS = 2 }|.
  ev_valid = xsdbool( lv_total = 100 ).

ENDFUNCTION.
