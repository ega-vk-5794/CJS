CLASS zcl_rak_fees_api DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_cj_api
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& Fees, payment progress and journey stage, without the OData.
*&
*& The first domain API, and deliberately so: FeesSet, TrackerSet and
*& ProjectSet are the three CUSTOMERJOURNEY reads that do not touch
*& IO_TECH_REQUEST_CONTEXT at all, so this class proves the inheritance
*& seam in ZCL_RAK_CJ_API without also depending on a request-context
*& stub. If calling a DPC method from outside Gateway does not work, it
*& fails here, on eleven journeys' worth of read-only data, before any of
*& the parcel, tenancy or signing work is built on top of it.
*&
*& It also needs no new ftype. RAKREMAININGFEES already migrates to the
*& engine's FEES control and TRACKER to STAGE, so this is a data source
*& for controls CJS can already draw.
*&
*& WHAT THE FILTERS ARE. Read off the DPC, not guessed:
*&   FeesSet     Department Intreno JourneyId Partner Role
*&   TrackerSet  Intreno JourneyCode Partner Partnerguid Role ScreenId
*&   ProjectSet  CaseId Dept Partner
*& Note JourneyId on fees but JourneyCode on tracker, and Dept on projects
*& against Department on fees. They are not consistent and must not be
*& made consistent here - the DPC reads the name it reads.
*&
*& Rows and messages come back together, never an exception. Same shape
*& as ZCL_RAK_BP_SEARCH=>TY_RES, and for the same reason: a functional
*& call used as an expression cannot carry IMPORTING, so a returning
*& structure is what keeps call sites readable.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   A GENERATED MPC TABLE TYPE CANNOT TYPE A DATA OBJECT. The generator
*   writes them as `TT_X type standard table of TS_X .` with no key at
*   all, which leaves the key unspecified - and a table type with an
*   unspecified key is GENERIC: legal for a formal parameter or a field
*   symbol, rejected everywhere else. Activation says it in those words:
*   "TT_FEES is a generic type. Use this type only for typing field
*   symbols and formal parameters."
*
*   So the row type is taken FROM the MPC with LINE OF - never a guessed
*   TS_ name - and the table type is completed here. The DPC's own
*   ET_ENTITYSET keeps the generic type, and a standard table of the same
*   row type binds to it, so nothing on the call side changes.
*   AND IT CANNOT REUSE THE GENERATOR'S NAME EITHER. This class inherits
*   the generated DPC, so every type that chain declares is already in
*   scope - redeclaring one is "There is already a type called TT_X".
*   Hence the _ROW / _ROWS suffix, which the generator never emits.
    TYPES ty_fee_row     TYPE LINE OF zcl_zega_cj_mpc=>tt_fees.
    TYPES ty_track_row   TYPE LINE OF zcl_zega_cj_mpc=>tt_tracker.
    TYPES ty_project_row TYPE LINE OF zcl_zega_cj_mpc=>tt_project.

    TYPES tt_fee_rows     TYPE STANDARD TABLE OF ty_fee_row     WITH DEFAULT KEY.
    TYPES tt_track_rows   TYPE STANDARD TABLE OF ty_track_row   WITH DEFAULT KEY.
    TYPES tt_project_rows TYPE STANDARD TABLE OF ty_project_row WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_fees_res,
             rows TYPE tt_fee_rows,
             msg  TYPE bapiret2_t,
           END OF ty_fees_res.

    TYPES: BEGIN OF ty_tracker_res,
             rows TYPE tt_track_rows,
             msg  TYPE bapiret2_t,
           END OF ty_tracker_res.

    TYPES: BEGIN OF ty_project_res,
             rows TYPE tt_project_rows,
             msg  TYPE bapiret2_t,
           END OF ty_project_res.

*   The open fee items for this case. Feeds the FEES control and the
*   PAYFEE card; it does NOT decide whether the citizen may submit - that
*   stays with the PAID gate in ZCL_RAK_JOURNEY_LOGIC.
    METHODS fees
      RETURNING VALUE(rs) TYPE ty_fees_res.

*   Journey progress. IV_SCREEN overrides the context's screen for the
*   case where a step asks about a different one; blank uses MS_CTX-SCREEN.
    METHODS tracker
      IMPORTING iv_screen TYPE string OPTIONAL
      RETURNING VALUE(rs) TYPE ty_tracker_res.

*   Projects for the logged-on partner. M028 picks one here.
    METHODS projects
      IMPORTING iv_case   TYPE string OPTIONAL
      RETURNING VALUE(rs) TYPE ty_project_res.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rak_fees_api IMPLEMENTATION.


  METHOD fees.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

    filter( EXPORTING iv_property = `Intreno`   iv_value = ms_ctx-intreno    CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `JourneyId` iv_value = ms_ctx-journey    CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Partner`   iv_value = ms_ctx-partner    CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Role`      iv_value = ms_ctx-role       CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Department` iv_value = ms_ctx-department CHANGING ct_filter = lt_flt ).

    TRY.
        feesset_get_entityset(
          EXPORTING
            iv_entity_name           = `Fees`
            iv_entity_set_name       = `FeesSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
*           Harmless on these three - they never read it - but passed
*           anyway so no caller has to remember which sets are safe.
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = rs-rows ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD tracker.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

    DATA(lv_screen) = COND string( WHEN iv_screen IS NOT INITIAL THEN iv_screen ELSE ms_ctx-screen ).

    filter( EXPORTING iv_property = `Intreno`     iv_value = ms_ctx-intreno     CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `JourneyCode` iv_value = ms_ctx-journey     CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Partner`     iv_value = ms_ctx-partner     CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Partnerguid` iv_value = ms_ctx-partnerguid CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Role`        iv_value = ms_ctx-role        CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `ScreenId`    iv_value = lv_screen          CHANGING ct_filter = lt_flt ).

    TRY.
        trackerset_get_entityset(
          EXPORTING
            iv_entity_name           = `Tracker`
            iv_entity_set_name       = `TrackerSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
*           Harmless on these three - they never read it - but passed
*           anyway so no caller has to remember which sets are safe.
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = rs-rows ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD projects.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

*   ProjectSet reads Dept, not Department. Not a typo here.
    filter( EXPORTING iv_property = `CaseId`  iv_value = iv_case            CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Dept`    iv_value = ms_ctx-department  CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Partner` iv_value = ms_ctx-partner     CHANGING ct_filter = lt_flt ).

    TRY.
        projectset_get_entityset(
          EXPORTING
            iv_entity_name           = `Project`
            iv_entity_set_name       = `ProjectSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
*           Harmless on these three - they never read it - but passed
*           anyway so no caller has to remember which sets are safe.
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = rs-rows ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
