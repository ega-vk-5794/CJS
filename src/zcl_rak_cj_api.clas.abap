CLASS zcl_rak_cj_api DEFINITION
  PUBLIC
  INHERITING FROM zcl_zega_cj_dpc_ext
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& CJS -> CUSTOMERJOURNEY, with the OData taken off it.
*&
*& The base every Municipality/EPDA/DOK domain API inherits. It exists so
*& the seam between CJS and ZCL_ZEGA_CJ_DPC_EXT is drawn ONCE.
*&
*& THE CUT IS THE ONE ZCL_RAK_BP_SEARCH ALREADY MADE. Its header says it
*& plainly: a <Set>_GET_ENTITYSET is three things and only the first is
*& OData - build filters, do the work, wrap failures as
*& /IWBEP/CX_MGW_BUSI_EXCEPTION. We keep the first two and leave the third
*& with the DPC. Nothing in the legacy namespace is modified.
*&
*& WHY INHERIT RATHER THAN COPY. The <Set>_GET_ENTITYSET methods are
*& PROTECTED on ZCL_ZEGA_CJ_DPC (declared between its `protected section`
*& at line 22 and its `private section` at 3825), so a subclass may call
*& them and only a subclass may. Copying their bodies into CJS would fork
*& sixteen thousand lines that nobody will keep in step.
*&
*& ============================ READ BEFORE ADDING A METHOD ============
*&
*& NOT EVERY DPC METHOD CAN BE CALLED FROM HERE, and the difference is
*& not in the signature. IO_TECH_REQUEST_CONTEXT is OPTIONAL on all of
*& them, but several dereference it without checking:
*&
*&     DATA(lt_request_headers) = io_tech_request_context->get_request_headers( ).
*&
*& is the sixteenth line of PROPERTIESSET_GET_ENTITYSET. Called with the
*& parameter omitted that is CX_SY_REF_IS_INITIAL, not an empty table.
*& Checked at the time of writing:
*&
*&   safe, no reference at all : FeesSet, TrackerSet, ProjectSet
*&   dereferences it           : PropertiesSet, LeaseContractSet,
*&                               PartnerSet, OccupantSet, UserSet
*&
*& So this class starts with the safe three. The rest need a request
*& context object first - see the next block - and that work is deliberately
*& not started here, because everything else depends on this class being
*& right.
*&
*& AND CJS CANNOT IMPERSONATE THE PORTAL SESSION. Even given a context,
*& ZCL_ZEGA_CJ_UTILITY_DPC_EXT=>GET_BP( ) resolves the caller by reading an
*& 'x-custom1' request header, looking that key up in ZEGA_T_CJ_US_LOG and
*& AES-decrypting the row. CJS has no such row: it knows the partner
*& directly, from the journey's own launch parameter. Any DPC branch that
*& derives identity through GET_BP( ) will therefore see it BLANK.
*&
*& That is why identity travels in MS_CTX and goes out as FILTERS. Every
*& domain method the fifteen journeys need accepts it that way - Partner,
*& Partnerguid, Partnerrole and Intreno are filter properties on all of
*& them. Never rely on the DPC working the caller out for itself.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   What every call needs, gathered once instead of per method. The four
*   names repeat across every filter set in the service, which is what
*   makes a context struct worth having rather than four parameters.
    TYPES: BEGIN OF ty_ctx,
             partner     TYPE string,   " engine mv_loginbp
             partnerguid TYPE string,
             role        TYPE string,
             intreno     TYPE string,   " io_ctx->get_case( ) - never a cached id
             journey     TYPE string,
             screen      TYPE string,   " the step's bknd_screen
             department  TYPE string,
             langu       TYPE sy-langu,
           END OF ty_ctx.

    METHODS constructor
      IMPORTING is_ctx TYPE ty_ctx.

*   ---- the API: directive a migrated field carries ---------------------
    TYPES: BEGIN OF ty_dir,
             api     TYPE string,
             eset    TYPE string,
             domain  TYPE string,
             dfilter TYPE string,
             ok      TYPE abap_bool,
           END OF ty_dir.

*   Parse DEFAULT_VAL. Anything that does not start with the four
*   characters 'API:' comes back with OK unset and is left alone - the
*   column also carries TEXT: paragraphs and grid specs.
    CLASS-METHODS parse_dir
      IMPORTING iv_default TYPE string
      RETURNING VALUE(rs)  TYPE ty_dir.

*   The grid columns for a bound entity set, in the engine's own
*   'KEY:Label:TYPE' spec, derived from the MPC row structure at RUNTIME.
*
*   WHY NOT SEEDED BY THE MIGRATOR. A composite's rows come from an entity
*   set, so its columns are the entity type's properties - which the model
*   provider already declares. Freezing them into DEFAULT_VAL would (a)
*   collide with the API: directive that has to live in the same column,
*   and (b) go stale the moment a property is added to the service. Read
*   instead, so the grid follows the model.
*
*   Returns blank when the structure cannot be resolved. Blank is the
*   honest answer - the caller then shows nothing rather than an empty grid
*   that looks like "no data".
    CLASS-METHODS columns_of
      IMPORTING iv_api    TYPE string
                iv_eset   TYPE string
      RETURNING VALUE(rv) TYPE string.

*   The context this instance was built with, so a caller that holds the
*   API does not have to hold the context separately.
    METHODS ctx
      RETURNING VALUE(rs) TYPE ty_ctx.

  PROTECTED SECTION.

    DATA ms_ctx TYPE ty_ctx.

*   The request context handed to any DPC method that dereferences it.
*   Built once in the constructor, because it is stateless - it answers an
*   empty header table and nothing else. See ZCL_RAK_CJ_REQ_CTX for why
*   empty is the right answer rather than a gap.
*
*   IT CAN BE UNBOUND, and the layer is built so that this degrades rather
*   than dumps. The context is a standard Gateway object instantiated
*   dynamically; if neither candidate class can be created here, GET( )
*   returns initial and ZCL_RAK_CJ_REQ_CTX=>WHY( ) says why. Every call site
*   in this layer already runs inside CATCH CX_ROOT -> TO_MSG( ), so the
*   citizen gets a message on a read that failed, not a short dump - and the
*   three sets that never touch the context keep working regardless.
*
*   Pass it to EVERY <Set>_GET_ENTITYSET call, including the three that do
*   not read it. They cost nothing for having it, and a domain API added
*   later should not have to know which sets are safe - the whole point of
*   the earlier split was that the difference is invisible in a signature.
    DATA mo_req TYPE REF TO /iwbep/if_mgw_req_entityset.

*   name/value -> /IWBEP/T_MGW_SELECT_OPTION, which is the only shape the
*   DPC reads filters in. One place, so that no domain API hand-builds a
*   select-option range and gets SIGN or OPTION subtly wrong.
*
*   A blank value adds NOTHING. That is deliberate: the DPC methods test
*   `IS INITIAL` on what they read out, and an I/EQ/'' row is not initial -
*   it is an equality test against the empty string, which matches no row.
    METHODS filter
      IMPORTING iv_property TYPE string
                iv_value    TYPE string
      CHANGING  ct_filter   TYPE /iwbep/t_mgw_select_option.

*   A DPC exception, flattened into the message shape CJS already carries
*   everywhere else. Callers get rows and messages, never an exception -
*   the same decision ZCL_RAK_BP_SEARCH made.
    METHODS to_msg
      IMPORTING io_exc    TYPE REF TO cx_root
      CHANGING  ct_msg    TYPE bapiret2_t.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rak_cj_api IMPLEMENTATION.


  METHOD constructor.
*   UNVERIFIED FROM THIS ENVIRONMENT: ZCL_ZEGA_CJ_DPC's own constructor is
*   not in the repository this was written against, so whether it takes
*   mandatory parameters could not be checked. If it does, activation names
*   them here and they are added to this call - nothing else moves.
    super->constructor( ).
    ms_ctx = is_ctx.
    IF ms_ctx-langu IS INITIAL.
      ms_ctx-langu = sy-langu.
    ENDIF.
*   ZCL_RAK_CJ_REQ_CTX is a FACTORY, not the context itself - it builds a
*   standard Gateway request object by RTTI rather than naming a signature
*   nothing here can read. It may come back UNBOUND; that is handled, not
*   ignored - see the note on MO_REQ and ZCL_RAK_CJ_REQ_CTX=>WHY( ).
    mo_req = zcl_rak_cj_req_ctx=>get( ).
  ENDMETHOD.


  METHOD ctx.
    rs = ms_ctx.
  ENDMETHOD.


  METHOD parse_dir.
    DATA lt TYPE string_table.

    IF strlen( iv_default ) < 4 OR iv_default(4) <> 'API:'.
      RETURN.
    ENDIF.

    SPLIT iv_default+4 AT ':' INTO TABLE lt.
    rs-api     = VALUE #( lt[ 1 ] OPTIONAL ).
    rs-eset    = VALUE #( lt[ 2 ] OPTIONAL ).
    rs-domain  = VALUE #( lt[ 3 ] OPTIONAL ).
    rs-dfilter = VALUE #( lt[ 4 ] OPTIONAL ).
    rs-ok      = xsdbool( rs-api IS NOT INITIAL AND rs-eset IS NOT INITIAL ).
  ENDMETHOD.


  METHOD columns_of.
*   The model provider that owns the entity set. The API name in the
*   directive is what decides it - ChemicalHistorySet looks like a
*   CUSTOMERJOURNEY set and is not one.
    DATA(lv_mpc) = SWITCH string( to_upper( iv_api )
      WHEN 'VALUEHELP' OR 'FND' THEN 'ZCL_ZEGA_FW_FND_MPC'
      WHEN 'SIGN'               THEN 'ZCL_ZUAEPASS_MPC'
      ELSE                           'ZCL_ZEGA_CJ_MPC' ).

*   <Name>Set -> TS_<NAME>. The generated MPC convention, checked against
*   FeesSet/TS_FEES, LeaseContractSet/TS_LEASECONTRACT and
*   ChemicalHistorySet/TS_CHEMICALHISTORY.
    DATA(lv_set) = to_upper( iv_eset ).
    IF strlen( lv_set ) > 3 AND substring( val = lv_set off = strlen( lv_set ) - 3 ) = 'SET'.
      lv_set = substring( val = lv_set len = strlen( lv_set ) - 3 ).
    ENDIF.

    DATA(lv_type) = |{ lv_mpc }=>TS_{ lv_set }|.

    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    TRY.
        lo_struct ?= cl_abap_typedescr=>describe_by_name( lv_type ).
      CATCH cx_root.
*       An entity set with no bound structure, or a name this convention
*       does not reach - get_owner_prop_docs is a method, not a set. The
*       caller draws nothing rather than an empty grid.
        RETURN.
    ENDTRY.

    LOOP AT lo_struct->get_components( ) INTO DATA(ls_c).
*     MANDT is a client column on the bound DDIC structures and never a
*     column the citizen should see.
      IF ls_c-name = 'MANDT'.
        CONTINUE.
      ENDIF.

*     The label is the component name made readable. The migrator has a
*     PRETTY( ) that does this, but it is private to that class and
*     ZCL_RAK_JOURNEY_UTIL has no equivalent - so it is inlined rather than
*     calling something that does not exist. The service's real texts live
*     in the MPC's own text elements and are not reachable from here; a
*     caller with better text overrides the label.
*     CONV string first: ls_c-name is ABAP_COMPNAME, a CHAR30, and its
*     trailing blanks would ride into the spec and into the column header.
      DATA(lv_lbl) = CONV string( ls_c-name ).
      CONDENSE lv_lbl.
      REPLACE ALL OCCURRENCES OF '_' IN lv_lbl WITH ` `.
      IF strlen( lv_lbl ) > 1.
        lv_lbl = |{ to_upper( substring( val = lv_lbl len = 1 ) ) }| &&
                 |{ to_lower( substring( val = lv_lbl off = 1 ) ) }|.
      ENDIF.

*     Column types collapse the same way GRID_SPEC( ) collapses them:
*     INPUT unless the component is plainly numeric or a date.
      DATA(lv_ctp) = SWITCH string( ls_c-type->type_kind
        WHEN cl_abap_typedescr=>typekind_date                                   THEN 'DATE'
        WHEN cl_abap_typedescr=>typekind_int  OR cl_abap_typedescr=>typekind_int1
          OR cl_abap_typedescr=>typekind_int2 OR cl_abap_typedescr=>typekind_packed
          OR cl_abap_typedescr=>typekind_float                                  THEN 'NUMBER'
        ELSE                                                                         'INPUT' ).

      rv = COND string( WHEN rv IS INITIAL THEN |{ ls_c-name }:{ lv_lbl }:{ lv_ctp }|
                        ELSE |{ rv }\|{ ls_c-name }:{ lv_lbl }:{ lv_ctp }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD filter.
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE ct_filter ASSIGNING FIELD-SYMBOL(<ls_f>)
         WITH KEY property = iv_property.
    IF sy-subrc <> 0.
      APPEND VALUE #( property = iv_property ) TO ct_filter ASSIGNING <ls_f>.
    ENDIF.

    APPEND VALUE #( sign = 'I' option = 'EQ' low = iv_value )
           TO <ls_f>-select_options.
  ENDMETHOD.


  METHOD to_msg.
    CHECK io_exc IS BOUND.
    APPEND VALUE #( type = 'E' id = 'ZRAK' number = '000'
                    message = io_exc->get_text( ) ) TO ct_msg.
  ENDMETHOD.
ENDCLASS.
