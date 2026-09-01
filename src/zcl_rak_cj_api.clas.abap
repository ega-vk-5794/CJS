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

*   The context this instance was built with, so a caller that holds the
*   API does not have to hold the context separately.
    METHODS ctx
      RETURNING VALUE(rs) TYPE ty_ctx.

  PROTECTED SECTION.

    DATA ms_ctx TYPE ty_ctx.

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
  ENDMETHOD.


  METHOD ctx.
    rs = ms_ctx.
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
