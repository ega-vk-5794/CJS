CLASS zcl_rak_cj_req_ctx DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

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
*& THE ONE HEADER IT CARRIES, and why that is not a fabrication. The header
*& the DPC looks for is 'x-custom1'. GET_BP( ) uses it as the key into
*& ZEGA_T_CJ_US_LOG, reads the row where ACTIVE = 'X', AES-decrypts
*& ENCRYPT_KEY with USER_KEY to recover the internet user, and resolves the
*& partner from there.
*&
*& CJS ALREADY HOLDS THAT KEY. It arrives on the launch URL as &userdata=,
*& the engine keeps it in MV_USERDATA, and the engine already resolves the
*& login BP with it - ZCL_EGA_CJ_UTILITY=>GET_BP( qv_key = mv_userdata ).
*& So this is not a fabricated session: it is the citizen's own portal
*& session, created by the portal at login, passed back in the form the DPC
*& expects.
*&
*& This corrects an earlier decision recorded here. While no key was known,
*& sending nothing was right - a made-up one would either miss or hit
*& somebody else's session. That reasoning ended when MV_USERDATA turned out
*& to be exactly the value 'x-custom1' carries.
*&
*& WHAT IT BUYS. GET_BP( ) is called from 25 <Set>_GET_ENTITYSET methods,
*& and the partner it resolves is used downstream in about a dozen places
*& that are not the PORTAL1/RAKDIGI_USER gate - passed as IM_BP to
*& sub-methods, as IV_PAY_PARTNER, written to LOGINBP, and used in a
*& WHERE PARTNER = clause. Every one of those received BLANK before, and
*& said nothing about it. None of them can be reached through a filter.
*&
*& Blank is still handled, not assumed away: an expired or logged-out
*& session has no ACTIVE row, GET_BP( ) returns early, and the read comes
*& back empty rather than dumping. Identity ALSO still travels as filters -
*& the two are belt and braces, not alternatives.
*&
*& WHY IT IS A FACTORY AND NOT A SUBCLASS, which is the part that cost real
*& time. The first two attempts wrote it as INHERITING FROM
*& /IWBEP/CL_MGW_REQUEST with GET_REQUEST_HEADERS redefined. Neither
*& activated, and each failure only revealed the next unknown:
*&
*&   1. "There is already an attribute called MT_HEADERS"  - the parent owns it.
*&   2. "No value was passed to the mandatory parameter IR_REQUEST_DETAILS"
*&      - so the constructor is NOT parameterless, and its type is not
*&        readable from the environment this is written in.
*&   3. "Field RT_REQUEST_HEADERS is unknown" - the returning parameter is
*&      RT_HEADER.
*&
*& Every one of those is the same failure mode: source that hard-codes the
*& shape of a standard object nobody here can open. Implementing
*& /IWBEP/IF_MGW_REQ_ENTITYSET directly instead is worse, not better - it
*& carries ~45 methods plus its component interface, and a missing one is
*& again an activation error rather than a runtime one.
*&
*& So NOTHING here names a signature. The context is created by RTTI:
*& read the candidate class's own CONSTRUCTOR, build a PARAMETER-TABLE from
*& whatever it declares as mandatory, and instantiate it dynamically. The
*& class activates whatever those parameters turn out to be, and anything
*& still wrong surfaces at runtime, catchable, with a message - not as a
*& class that will not load.
*&
*& THE TWO CANDIDATES, in order:
*&
*&   /IWBEP/CL_MGW_REQUEST_UNITTST  "Unit test enabling Request Context",
*&       a subclass of /IWBEP/CL_MGW_REQUEST that SAP ships for exactly this
*&       situation - a request context for a DPC called with no HTTP request
*&       behind it. Tried first because being constructible outside Gateway
*&       is its whole purpose.
*&   /IWBEP/CL_MGW_REQUEST          the base class, whose constructor is
*&       (IR_REQUEST_DETAILS, IT_HEADERS, IO_MODEL). Tried second.
*&
*& If both fail, GET( ) returns an UNBOUND reference and WHY( ) says why.
*& That is deliberate and it is not a regression: every DPC call in this
*& layer already runs inside CATCH CX_ROOT -> TO_MSG( ), so an unbound
*& context degrades to a message on the screen, which is what the caller
*& would have got from a failed read anyway. DIAG( ) then prints both
*& constructors as the system actually declares them, which is the one fact
*& that has been missing all along - run it before theorising.
*&
*& Do NOT work around any of this by making the DPC methods tolerate an
*& unbound reference. That is the legacy namespace.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   The context to pass as IO_TECH_REQUEST_CONTEXT. Built once per session
*   and cached, including a failed build - retrying it on every read would
*   turn one missing class into an RTTI call per field per round trip.
*   IV_USERDATA is the portal session key from the launch URL - the engine's
*   MV_USERDATA, reachable as GET_PARAM( 'USERDATA' ). Blank still works and
*   still gives a usable context; it just resolves no user, which is the old
*   behaviour exactly.
    CLASS-METHODS get
      IMPORTING iv_userdata TYPE string OPTIONAL
      RETURNING VALUE(ro)   TYPE REF TO /iwbep/if_mgw_req_entityset.

*   Empty when GET( ) succeeded. Otherwise the reason, both candidates
*   concatenated, ready to be put in a BAPIRET2 row.
    CLASS-METHODS why
      RETURNING VALUE(rv) TYPE string.

*   Both candidate constructors as the system declares them, plus the last
*   error. Not called by the engine - it exists so one WRITE settles what
*   three activation rounds did not.
    CLASS-METHODS diag
      RETURNING VALUE(rv) TYPE string.

  PRIVATE SECTION.

    CONSTANTS c_unittst TYPE seoclsname VALUE '/IWBEP/CL_MGW_REQUEST_UNITTST'.
    CONSTANTS c_request TYPE seoclsname VALUE '/IWBEP/CL_MGW_REQUEST'.

    CLASS-DATA gv_tried TYPE abap_bool.
    CLASS-DATA go_ctx   TYPE REF TO /iwbep/if_mgw_req_entityset.
    CLASS-DATA gv_why   TYPE string.
*   The key the cached context was built WITH. A context carries its headers
*   from construction, so one built for a blank key cannot answer for a real
*   one - caching on the object alone would hand the second journey in a
*   session the first journey's identity, or none at all.
    CLASS-DATA gv_key   TYPE string.

    CLASS-METHODS build
      IMPORTING iv_class    TYPE seoclsname
                iv_userdata TYPE string
      RETURNING VALUE(ro)   TYPE REF TO /iwbep/if_mgw_req_entityset.

    CLASS-METHODS signature
      IMPORTING iv_class  TYPE seoclsname
      RETURNING VALUE(rv) TYPE string.

*   Put one row into whatever table IT_HEADERS turns out to be. Done through
*   RTTI and ASSIGN COMPONENT rather than by naming TIHTTPNVP, for the same
*   reason as everything else in this class: the type is a standard one this
*   environment cannot open, and a wrong guess about it should be a caught
*   runtime error, not a class that will not load.
    CLASS-METHODS fill_header
      IMPORTING ir_tab      TYPE REF TO data
                iv_userdata TYPE string.

*   Give a reference-typed constructor parameter something to point at, and
*   put the session key inside it where the standard code looks for it.
*   Does nothing for a parameter that is not a data reference, and nothing
*   for a reference to a class or interface - those cannot be fabricated.
    CLASS-METHODS bind_ref
      IMPORTING ir_slot     TYPE REF TO data
                iv_userdata TYPE string.

*   Where /IWBEP/CL_MGW_REQUEST keeps the headers inside the request
*   details, read off its own GET_REQUEST_HEADERS( ):
*       rt_header = mr_request->*-technical_request-request_header.
    CONSTANTS c_tech_comp TYPE string VALUE 'TECHNICAL_REQUEST'.
    CONSTANTS c_hdr_comp  TYPE string VALUE 'REQUEST_HEADER'.

*   'x-custom1' is compared CASE-SENSITIVELY by GET_BP( ) -
*   READ TABLE ... WITH KEY name = 'x-custom1' against a STRING component.
*   Upper-casing it here would send a header nothing reads.
    CONSTANTS c_hdr_name TYPE string VALUE 'x-custom1'.
    CONSTANTS c_hdr_parm TYPE string VALUE 'IT_HEADERS'.

ENDCLASS.



CLASS zcl_rak_cj_req_ctx IMPLEMENTATION.


  METHOD get.
*   Rebuilt when the key changes, not only on the first call. The headers are
*   fixed at construction, so a context built for one session cannot serve
*   another.
    IF gv_tried = abap_true AND gv_key = iv_userdata.
      ro = go_ctx.
      RETURN.
    ENDIF.
    gv_tried = abap_true.
    gv_key   = iv_userdata.
    CLEAR go_ctx.

    go_ctx = build( iv_class = c_unittst iv_userdata = iv_userdata ).
    IF go_ctx IS NOT INITIAL.
      CLEAR gv_why.
      ro = go_ctx.
      RETURN.
    ENDIF.

*   Keep the first reason - if the second candidate also fails, the reader
*   needs both, not just the last one.
    DATA(lv_first) = gv_why.
    go_ctx = build( iv_class = c_request iv_userdata = iv_userdata ).
    IF go_ctx IS NOT INITIAL.
      CLEAR gv_why.
    ELSE.
      gv_why = |{ lv_first } / { gv_why }|.
    ENDIF.
    ro = go_ctx.
  ENDMETHOD.


  METHOD why.
    rv = gv_why.
  ENDMETHOD.


  METHOD build.
    DATA lo_type TYPE REF TO cl_abap_typedescr.
    DATA lo_cls  TYPE REF TO cl_abap_classdescr.
    DATA lo_par  TYPE REF TO cl_abap_datadescr.
    DATA lt_p    TYPE abap_parmbind_tab.
    DATA ls_p    TYPE abap_parmbind.
    DATA lo_obj  TYPE REF TO object.

*   CALL METHOD, not a functional call: DESCRIBE_BY_NAME raises a CLASSICAL
*   exception, so the result has to be read through SY-SUBRC.
    CALL METHOD cl_abap_typedescr=>describe_by_name
      EXPORTING  p_name         = iv_class
      RECEIVING  p_descr_ref    = lo_type
      EXCEPTIONS type_not_found = 1
                 OTHERS         = 2.
    IF sy-subrc <> 0.
      gv_why = |{ iv_class } is not in this system|.
      RETURN.
    ENDIF.

    TRY.
        lo_cls ?= lo_type.
      CATCH cx_sy_move_cast_error.
        gv_why = |{ iv_class } is not a class|.
        RETURN.
    ENDTRY.

*   No CONSTRUCTOR row at all means a parameterless one - LT_P stays empty
*   and CREATE OBJECT below is the plain form.
    READ TABLE lo_cls->methods INTO DATA(ls_m) WITH KEY name = 'CONSTRUCTOR'.
    IF sy-subrc = 0.
      LOOP AT ls_m-parameters INTO DATA(ls_par)
           WHERE parm_kind   = cl_abap_objectdescr=>importing
             AND is_optional = abap_false.

*       MANDATORY ONLY, on purpose. An optional parameter left out is the
*       constructor's own default; an optional parameter supplied initial is
*       a value, and the two are not the same thing. IT_HEADERS is exactly
*       that case - an empty table passed explicitly and an omitted table
*       may take different branches inside, and empty-by-default is what we
*       want anyway.
        CLEAR ls_p.

        CALL METHOD lo_cls->get_method_parameter_type
          EXPORTING  p_method_name       = ls_m-name
                     p_parameter_name    = ls_par-name
          RECEIVING  p_descr_ref         = lo_par
          EXCEPTIONS parameter_not_found = 1
                     method_not_found    = 2
                     OTHERS              = 3.
        IF sy-subrc <> 0.
          gv_why = |{ iv_class }: cannot type CONSTRUCTOR parameter { ls_par-name }|.
          RETURN.
        ENDIF.

        ls_p-name = ls_par-name.
        ls_p-kind = cl_abap_objectdescr=>exporting.

*       An anonymous data object of the parameter's own declared type, left
*       initial. For IR_REQUEST_DETAILS - a data reference - that is an
*       initial reference, which is correct: this context describes no
*       request. If a constructor turns out to dereference it, that is a
*       catchable runtime error below, and WHY( ) will say so.
        CREATE DATA ls_p-value TYPE HANDLE lo_par.

*       A REFERENCE PARAMETER GETS SOMETHING TO POINT AT.
*
*       This was the whole failure. CREATE DATA on a REF TO <struct>
*       parameter makes an INITIAL reference - a null pointer - and
*       /IWBEP/CL_MGW_REQUEST's own GET_REQUEST_HEADERS( ) does
*
*           rt_header = mr_request->*-technical_request-request_header.
*
*       straight into it. DATREF_NOT_ASSIGNED, and NOT catchable: a TRY
*       around the call does not stop it. So the context constructed
*       perfectly and dumped the moment anything used it - which means
*       every DPC read through this layer would have dumped too, header or
*       no header. Construction succeeding proved nothing.
        bind_ref( ir_slot = ls_p-value iv_userdata = iv_userdata ).

*       IT_HEADERS as well, where the constructor takes one. Kept because
*       /IWBEP/CL_MGW_REQUEST_UNITTST declares it mandatory and may read it
*       in preference to the request details.
        IF iv_userdata IS NOT INITIAL AND to_upper( CONV string( ls_par-name ) ) = c_hdr_parm.
          fill_header( ir_tab = ls_p-value iv_userdata = iv_userdata ).
        ENDIF.

        INSERT ls_p INTO TABLE lt_p.
      ENDLOOP.
    ENDIF.

    TRY.
        CREATE OBJECT lo_obj TYPE (iv_class) PARAMETER-TABLE lt_p.
        ro ?= lo_obj.
      CATCH cx_root INTO DATA(lx).
*       Includes CREATE PRIVATE/PROTECTED, an abstract class, a parameter
*       mismatch, and anything the constructor itself raises. All of them
*       mean "try the next candidate", none of them mean "stop the journey".
        CLEAR ro.
        gv_why = |{ iv_class }: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD bind_ref.
    FIELD-SYMBOLS <slot> TYPE any.

    ASSIGN ir_slot->* TO <slot>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lo_dd TYPE REF TO cl_abap_datadescr.

    TRY.
        DATA(lo_ref) = CAST cl_abap_refdescr(
                         cl_abap_typedescr=>describe_by_data( <slot> ) ).
*       A reference to a CLASS or INTERFACE cannot be given a target - there
*       is nothing to create. Only a data reference can.
        lo_dd = CAST cl_abap_datadescr( lo_ref->get_referenced_type( ) ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

*   CREATE DATA onto the field symbol, which IS the reference variable.
*   That is what makes the parameter bound rather than null, and it needs no
*   cast: the created object takes the type the reference already declares.
    TRY.
        CREATE DATA <slot> TYPE HANDLE lo_dd.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    IF iv_userdata IS INITIAL.
      RETURN.
    ENDIF.

*   And the session key, into the component the standard getter reads.
*   Every step is guarded: a structure without these components simply keeps
*   an empty request, which is still infinitely better than a null one.
    FIELD-SYMBOLS <req>  TYPE any.
    FIELD-SYMBOLS <tech> TYPE any.
    FIELD-SYMBOLS <hdr>  TYPE ANY TABLE.

    ASSIGN <slot>->* TO <req>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT c_tech_comp OF STRUCTURE <req> TO <tech>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT c_hdr_comp OF STRUCTURE <tech> TO <hdr>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lr_hdr TYPE REF TO data.
    GET REFERENCE OF <hdr> INTO lr_hdr.
    fill_header( ir_tab = lr_hdr iv_userdata = iv_userdata ).
  ENDMETHOD.


  METHOD fill_header.
    FIELD-SYMBOLS <tab> TYPE ANY TABLE.
    FIELD-SYMBOLS <row> TYPE any.
    DATA lr_row TYPE REF TO data.

    ASSIGN ir_tab->* TO <tab>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   LO_LINE is a variable, not the call itself. TYPE HANDLE takes a type
*   description OBJECT, and a functional method call is not allowed in that
*   position - 'CREATE DATA ... TYPE HANDLE lo_tt->get_table_line_type( )'
*   fails with "No method can be specified in the current position", which
*   names neither TYPE HANDLE nor the call. Same family as VALUE needing a
*   type name: the message describes where the parser gave up, not what is
*   wrong.
    DATA lo_line TYPE REF TO cl_abap_datadescr.

    TRY.
        DATA(lo_tt) = CAST cl_abap_tabledescr(
                        cl_abap_typedescr=>describe_by_data( <tab> ) ).
        lo_line = lo_tt->get_table_line_type( ).
        CREATE DATA lr_row TYPE HANDLE lo_line.
      CATCH cx_root.
*       Not a table, or a line type that cannot be created. The context is
*       still built, just without a header - which is where this class
*       started, so it degrades to the old behaviour rather than failing.
        RETURN.
    ENDTRY.

    ASSIGN lr_row->* TO <row>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'NAME' OF STRUCTURE <row> TO FIELD-SYMBOL(<n>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT 'VALUE' OF STRUCTURE <row> TO FIELD-SYMBOL(<v>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    <n> = c_hdr_name.
    <v> = iv_userdata.

    INSERT <row> INTO TABLE <tab>.
  ENDMETHOD.


  METHOD signature.
    DATA lo_type TYPE REF TO cl_abap_typedescr.
    DATA lo_cls  TYPE REF TO cl_abap_classdescr.

    CALL METHOD cl_abap_typedescr=>describe_by_name
      EXPORTING  p_name         = iv_class
      RECEIVING  p_descr_ref    = lo_type
      EXCEPTIONS type_not_found = 1
                 OTHERS         = 2.
    IF sy-subrc <> 0.
      rv = |{ iv_class }: not in this system|.
      RETURN.
    ENDIF.

    TRY.
        lo_cls ?= lo_type.
      CATCH cx_sy_move_cast_error.
        rv = |{ iv_class }: not a class|.
        RETURN.
    ENDTRY.

    READ TABLE lo_cls->methods INTO DATA(ls_m) WITH KEY name = 'CONSTRUCTOR'.
    IF sy-subrc <> 0.
      rv = |{ iv_class } CONSTRUCTOR: none declared (parameterless)|.
      RETURN.
    ENDIF.

    rv = |{ iv_class } CONSTRUCTOR:|.
    LOOP AT ls_m-parameters INTO DATA(ls_par).
      DATA(lv_opt) = COND string( WHEN ls_par-is_optional = abap_true
                                  THEN `opt` ELSE `MANDATORY` ).
      rv = |{ rv } { ls_par-name }[{ ls_par-parm_kind },{ lv_opt }]|.
    ENDLOOP.
  ENDMETHOD.


  METHOD diag.
    rv = |{ signature( c_unittst ) }|.
    rv = |{ rv } // { signature( c_request ) }|.
    IF gv_why IS NOT INITIAL.
      rv = |{ rv } // last error: { gv_why }|.
    ENDIF.
  ENDMETHOD.


ENDCLASS.
