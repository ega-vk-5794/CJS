CLASS zcl_rak_cj_req_ctx DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_request
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& The request context CJS hands a Gateway DPC that has no Gateway.
*&
*& WHY THIS EXISTS AT ALL. IO_TECH_REQUEST_CONTEXT is OPTIONAL on every
*& <Set>_GET_ENTITYSET, but the bodies do not check it:
*&
*&     DATA(lt_request_headers) = io_tech_request_context->get_request_headers( ).
*&
*& is the sixteenth line of PROPERTIESSET_GET_ENTITYSET and it is not
*& guarded. Called with the parameter omitted that is CX_SY_REF_IS_INITIAL,
*& not an empty table - which is why ZCL_RAK_FEES_API could only take the
*& three sets that never touch it. FindParcelSet, PropertiesSet,
*& LeaseContractSet, PartnerSet and OccupantSet all do, and between them
*& they are almost everything the fifteen journeys draw.
*&
*& AND IT ONLY HAS TO DO ONE THING. Counted across ZCL_ZEGA_CJ_DPC_EXT and
*& ZCL_ZEGA_CJ_UTILITY_DPC_EXT, exactly one method is ever called on the
*& context - GET_REQUEST_HEADERS( ), 25 times, and nothing else. So this is
*& not a simulation of a Gateway request. It is a header table with an
*& object around it.
*&
*& WHAT IT DELIBERATELY DOES NOT CARRY. The header the DPC looks for is
*& 'x-custom1', which GET_BP( ) uses as a key into ZEGA_T_CJ_US_LOG and
*& then AES-decrypts to recover the portal user. CJS has no such row - it
*& knows the partner directly, from the journey's launch parameter - so
*& supplying a fabricated key would be worse than supplying none: it would
*& either miss and return blank anyway, or hit somebody else's session.
*&
*& The headers therefore come back EMPTY unless a caller sets them, GET_BP( )
*& returns a blank partner, and identity reaches the DPC as FILTERS instead.
*& That is the rule written into ZCL_RAK_CJ_API and it is why this class can
*& be as thin as it is.
*&
*& SETTLED AT ACTIVATION. /IWBEP/CL_MGW_REQUEST was not readable from the
*& environment this was written in, so whether it could be inherited and
*& what its constructor wanted were both open. The first activation
*& answered both: it is inheritable, super->constructor( ) takes no
*& arguments, and the ONLY complaint was a name clash on MT_HEADERS, which
*& the parent already owns. Hence MT_HDR below.
*&
*& If a future release changes that, the fallback is to implement
*& /IWBEP/IF_MGW_REQ_ENTITYSET directly instead of inheriting: every method
*& empty except GET_REQUEST_HEADERS( ). More code, no more logic, because
*& of the single-method finding above. Do NOT work around it by making the
*& DPC methods tolerate an unbound reference - that is the legacy
*& namespace.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING it_headers TYPE tihttpnvp OPTIONAL.

*   Redefined so it answers from MT_HDR rather than from a live HTTP
*   request there is none of.
    METHODS /iwbep/if_mgw_req_entityset~get_request_headers
      REDEFINITION.

  PROTECTED SECTION.
*   MT_HDR, not MT_HEADERS. /IWBEP/CL_MGW_REQUEST already owns a protected
*   MT_HEADERS, and redeclaring it fails activation with "There is already
*   an attribute called MT_HEADERS" - which is how we learned the class
*   inherits cleanly and takes a parameterless super->constructor( ).
*   The inherited one is left strictly alone: its type and the parent's use
*   of it are not documented anywhere reachable, and writing to an
*   attribute whose owner may also write to it is how a subclass breaks a
*   superclass quietly.
    DATA mt_hdr TYPE tihttpnvp.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rak_cj_req_ctx IMPLEMENTATION.


  METHOD constructor.
*   UNVERIFIED - see the class header. If /IWBEP/CL_MGW_REQUEST's own
*   constructor demands parameters, activation names them and they are
*   added here; nothing else in this class moves.
    super->constructor( ).
    mt_hdr = it_headers.
  ENDMETHOD.


  METHOD /iwbep/if_mgw_req_entityset~get_request_headers.
*   Empty is the correct answer, not a gap. See the class header: the only
*   header the DPC reads is 'x-custom1', and CJS cannot supply a truthful
*   one. Returning nothing makes GET_BP( ) fall through to a blank partner,
*   which is exactly what the filter-based identity in ZCL_RAK_CJ_API
*   expects.
    rt_request_headers = mt_hdr.
  ENDMETHOD.
ENDCLASS.
