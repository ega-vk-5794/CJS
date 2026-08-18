CLASS zcl_rak_not_trace DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-DATA gv_on    TYPE abap_bool VALUE abap_true.
    CLASS-DATA gt_log   TYPE stringtab.

    CLASS-METHODS on
      IMPORTING iv_on TYPE abap_bool DEFAULT abap_true.

    CLASS-METHODS reset.

    CLASS-METHODS dump
      RETURNING VALUE(rt_log) TYPE stringtab.

    CLASS-METHODS add
      IMPORTING iv_text TYPE string.

    CLASS-METHODS http
      IMPORTING iv_method  TYPE string
                iv_path    TYPE string
                iv_payload TYPE string OPTIONAL
                iv_status  TYPE i      OPTIONAL
                iv_reason  TYPE string OPTIONAL
                iv_resp    TYPE string OPTIONAL.

    CLASS-METHODS cut
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(rv_out) TYPE string.

    CLASS-METHODS auth
      IMPORTING iv_handle_token TYPE string
                iv_static_token TYPE string
                iv_header       TYPE string.

    CLASS-METHODS peek
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(rv_out) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_NOT_TRACE IMPLEMENTATION.


  METHOD add.
    IF gv_on = abap_false.
      RETURN.
    ENDIF.
    APPEND |{ sy-uzeit+0(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) } { iv_text }| TO gt_log.
  ENDMETHOD.


  METHOD auth.

    IF gv_on = abap_false.
      RETURN.
    ENDIF.

    add( |AUTH handle-token { peek( iv_handle_token ) }| ).
    add( |AUTH static-token { peek( iv_static_token ) }| ).
    add( |AUTH header      { peek( iv_header ) }| ).

    IF iv_handle_token IS INITIAL.
      add( 'AUTH WARNING handle token is empty - Authorization sent blank' ).
    ENDIF.

    IF iv_handle_token <> iv_static_token.
      add( 'AUTH WARNING handle token differs from cached static token' ).
    ENDIF.

  ENDMETHOD.


  METHOD cut.
    rv_out = iv_in.
    IF strlen( rv_out ) > 2000.
      rv_out = |{ rv_out(2000) } ...|.
    ENDIF.
  ENDMETHOD.


  METHOD dump.
    rt_log = gt_log.
  ENDMETHOD.


  METHOD http.

    IF gv_on = abap_false.
      RETURN.
    ENDIF.

    IF iv_status IS INITIAL AND iv_resp IS INITIAL.
      add( |--> { iv_method } { iv_path }| ).
    ENDIF.

    IF iv_payload IS NOT INITIAL.
      add( |    req  { cut( iv_payload ) }| ).
    ENDIF.

    IF iv_status IS NOT INITIAL.
      add( |<-- { iv_status } { iv_reason } { iv_path }| ).
    ENDIF.

    IF iv_resp IS NOT INITIAL.
      add( |    resp { cut( iv_resp ) }| ).
    ENDIF.

  ENDMETHOD.


  METHOD on.
    gv_on = iv_on.
  ENDMETHOD.


  METHOD peek.
    IF iv_in IS INITIAL.
      rv_out = '<EMPTY>'.
      RETURN.
    ENDIF.
    IF strlen( iv_in ) <= 16.
      rv_out = |len={ strlen( iv_in ) } val=[{ iv_in }]|.
      RETURN.
    ENDIF.
    DATA(lv_tail) = substring( val = iv_in off = strlen( iv_in ) - 6 ).
    rv_out = |len={ strlen( iv_in ) } head=[{ iv_in(12) }] tail=[{ lv_tail }]|.
  ENDMETHOD.


  METHOD reset.
    CLEAR gt_log.
  ENDMETHOD.
ENDCLASS.
