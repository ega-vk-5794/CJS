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

* The portal session key, if you want to test the identity path as well as
* the context. Paste the &userdata= value from a journey launch URL.
*
* PARAMETERS cannot be TYPE STRING - a selection-screen field has to be flat
* and fixed-length - so this is CHAR 132 and converted on the way in.
PARAMETERS p_key TYPE c LENGTH 132 LOWER CASE.

START-OF-SELECTION.

* Everything reaches WRITE through a variable. WRITE takes data objects,
* not expressions, and a method call in the operand is the kind of thing
* that fails at activation for a reason unrelated to what is being tested.
  DATA lv_state TYPE string.
  DATA lv_diag  TYPE string.
  DATA lv_why   TYPE string.

* Either form works. Paste the raw USER_KEY that ZRAK_CJ_TESTKEY prints, or
* the whole &userdata= JSON off a launch URL - SESSION_KEY_OF( ) unwraps the
* second and passes the first through. The DPC's GET_BP( ) only ever accepts
* the raw key, so this is where the difference has to be resolved.
  DATA(lv_key) = zcl_rak_cj_ctx=>session_key_of( CONV string( p_key ) ).
  IF lv_key <> CONV string( p_key ).
    WRITE: / 'Unwrapped &userdata= to the session key inside it.'.
  ENDIF.
  DATA(lo_ctx) = zcl_rak_cj_req_ctx=>get( lv_key ).

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
    RETURN.
  ENDIF.

* THE FALLBACK LIST, PRINTED FIRST - on purpose.
*
* GET_REQUEST_HEADERS( ) below can dump with DATREF_NOT_ASSIGNED, and that
* one is NOT catchable: a TRY around the call does not stop it. If it does,
* everything after it is lost - so the thing we would need next is printed
* before the risk, not after.
*
* What we would need next is this list. If a standard request context cannot
* be made to answer GET_REQUEST_HEADERS( ), the remaining route is a class
* of our own implementing /IWBEP/IF_MGW_REQ_ENTITYSET - every method empty
* except that one. Implementing an interface method needs only its NAME, so
* this list is the whole specification for that class.
  SKIP.
  WRITE: / '--- /IWBEP/IF_MGW_REQ_ENTITYSET, for the fallback route ---'.
  DATA lo_itf TYPE REF TO cl_abap_typedescr.
  CALL METHOD cl_abap_typedescr=>describe_by_name
    EXPORTING  p_name         = '/IWBEP/IF_MGW_REQ_ENTITYSET'
    RECEIVING  p_descr_ref    = lo_itf
    EXCEPTIONS type_not_found = 1
               OTHERS         = 2.
  IF sy-subrc <> 0.
    WRITE: / '  not in this system'.
  ELSE.
    TRY.
        DATA(lo_id) = CAST cl_abap_intfdescr( lo_itf ).
        LOOP AT lo_id->methods INTO DATA(ls_im).
          WRITE: / '  ', ls_im-name.
        ENDLOOP.
        WRITE: / '  (', lines( lo_id->methods ), 'methods )'.
      CATCH cx_root INTO DATA(lx_itf).
        WRITE: / '  ', lx_itf->get_text( ).
    ENDTRY.
  ENDIF.

* Does the header actually reach the context? This is the whole question the
* identity change turns on: GET_BP( ) reads 'x-custom1' off exactly this
* table, so if it is not here, the DPC resolves nobody and says nothing.
  SKIP.
  DATA lv_hdr TYPE string.
  TRY.
      DATA(lt_hdr) = lo_ctx->get_request_headers( ).
      READ TABLE lt_hdr INTO DATA(ls_hdr) WITH KEY name = 'x-custom1'.
      IF sy-subrc = 0.
        lv_hdr = |x-custom1 IS on the context, { strlen( ls_hdr-value ) } characters|.
      ELSE.
        lv_hdr = COND string( WHEN lv_key IS INITIAL
                              THEN 'no x-custom1 - no key was entered, so this is expected'
                              ELSE 'no x-custom1 - the key did NOT reach the context' ).
      ENDIF.
    CATCH cx_root INTO DATA(lx).
      lv_hdr = |get_request_headers failed: { lx->get_text( ) }|.
  ENDTRY.
  WRITE: / 'Headers:', lv_hdr.

* And does the DPC resolve a caller from it? This is the payoff - the dozen
* code paths that consume the resolved partner rather than a filter.
  IF lv_key IS INITIAL.
    RETURN.
  ENDIF.

  SKIP.
  DATA lv_user TYPE string.
  DATA lv_bp   TYPE bu_partner.
  TRY.
      zcl_zega_cj_utility_dpc_ext=>get_bp(
        EXPORTING io_tech_request_context = lo_ctx
        IMPORTING user                    = lv_user
                  partner                 = lv_bp ).
    CATCH cx_root INTO DATA(lx_bp).
      lv_user = lx_bp->get_text( ).
  ENDTRY.
  WRITE: / 'GET_BP user:   ', lv_user.
  WRITE: / 'GET_BP partner:', lv_bp.
  IF lv_bp IS INITIAL.
    WRITE: / 'A blank partner means no ACTIVE row in ZEGA_T_CJ_US_LOG for that key'.
  ENDIF.
