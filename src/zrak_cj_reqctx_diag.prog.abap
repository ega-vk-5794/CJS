*&---------------------------------------------------------------------*
*& Report ZRAK_CJ_REQCTX_DIAG
*&
*& What request context can this system actually give a DPC called
*& outside Gateway?
*&
*& Every <Set>_GET_ENTITYSET on ZCL_ZEGA_CJ_DPC_EXT that reads a header
*& does it the same way - IO_TECH_REQUEST_CONTEXT->GET_REQUEST_HEADERS( ),
*& unguarded - so the whole wrapper layer stands or falls on being able to
*& hand it an object. ZCL_RAK_CJ_REQ_CTX builds one by RTTI from a standard
*& class rather than naming a constructor nobody here can open; this report
*& prints what that lookup found.
*&
*& Read it as: if BOUND, nothing to do - the layer has its context. If not,
*& the two CONSTRUCTOR lines below are the exact fact that was missing, and
*& the error line says which step failed.
*&---------------------------------------------------------------------*
REPORT zrak_cj_reqctx_diag.

START-OF-SELECTION.

* Everything reaches WRITE through a variable. WRITE takes data objects,
* not expressions, and a method call in the operand is the kind of thing
* that fails at activation for a reason unrelated to what is being tested.
  DATA lv_state TYPE string.
  DATA lv_diag  TYPE string.
  DATA lv_why   TYPE string.

  DATA(lo_ctx) = zcl_rak_cj_req_ctx=>get( ).

  IF lo_ctx IS BOUND.
    lv_state = 'BOUND - the wrapper layer has its context'.
  ELSE.
    lv_state = 'NOT bound - see the constructors and the reason below'.
  ENDIF.
  WRITE: / 'Request context:', lv_state.
  SKIP.

* Split on the separator the class uses, so a long signature wraps into
* readable lines instead of running off the list.
  lv_diag = zcl_rak_cj_req_ctx=>diag( ).
  SPLIT lv_diag AT '//' INTO TABLE DATA(lt_line).
  LOOP AT lt_line INTO DATA(lv_line).
    WRITE: / lv_line.
  ENDLOOP.

  IF lo_ctx IS NOT BOUND.
    lv_why = zcl_rak_cj_req_ctx=>why( ).
    SKIP.
    WRITE: / 'Why:', lv_why.
  ENDIF.
