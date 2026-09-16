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
*            WHAT WAS ACTUALLY ASKED, in $filter form. An empty project list
*            has two completely different causes - this partner owns nothing,
*            or we filtered on something the live screen does not - and they
*            look identical on screen. The caller puts this in its note so one
*            run separates them instead of a round of theorising.
             flt  TYPE string,
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
*
*   PARTNER IS THE ONLY FILTER BY DEFAULT, and that is copied from the live
*   request, not chosen: the working portal screen asks
*
*     ProjectSet?sap-language=en&$filter=Partner eq '3000018329'
*
*   and gets 207 projects back. It sends no Dept and no CaseId, so neither
*   is sent here unless a caller explicitly asks for one.
*
*   THIS METHOD USED TO SEND BOTH AND RETURNED NOTHING. MS_CTX-DEPARTMENT is
*   derived, and ZCL_RAK_CJ_CTX's own header says the CJS category is not the
*   portal department - so a value that is merely plausible went out as
*   `Dept eq '<guess>'` and filtered 207 rows down to none, silently, with the
*   citizen shown "No project is registered against this partner". The same
*   trap is already recorded against FeesSet.
*
*   The two parameters stay available because the DPC really does declare
*   those filters and a later screen may want them. They are opt-in now, which
*   is the difference: a filter has to be asked for rather than arriving by
*   default from a field somebody guessed.
    METHODS projects
      IMPORTING iv_case   TYPE string OPTIONAL
                iv_dept   TYPE string OPTIONAL
      RETURNING VALUE(rs) TYPE ty_project_res.

*   CONFIRMED FROM THE DPC'S OWN SIGNATURE, not inferred. ET_ENTITYSET on
*   PAYMENTSET_GET_ENTITYSET is typed ZCL_ZEGA_CJ_MPC=>TT_PAYMENT, which was
*   read off the Class Builder rather than guessed from the sibling naming -
*   so this is a plain TYPES like the other three and needs no dynamic
*   CREATE DATA to stay safe.
*
*   LINE OF, for the reason written on TY_FEE_ROW above: the generator leaves
*   the table type with no key at all, which makes it GENERIC and illegal for
*   typing a data object. The row comes from the MPC, the table is completed
*   here.
    TYPES ty_pay_row  TYPE LINE OF zcl_zega_cj_mpc=>tt_payment.
    TYPES tt_pay_rows TYPE STANDARD TABLE OF ty_pay_row WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_pay_res,
*            SUCCESS / OPEN / FAILED exactly as the DPC writes them, or BLANK
*            when the call could not be made at all. Blank is not a status and
*            must never be treated as one - it means "ask somebody else", which
*            is what the caller's fallback is for.
             status TYPE string,
             msg    TYPE bapiret2_t,
           END OF ty_pay_res.

*   PAYMENT STATUS, ASKED OF THE DPC INSTEAD OF REIMPLEMENTED.
*
*   ZCL_RAK_PAY_ENGINE->POLL_STATUS( ) is a port of PAYMENTSET_GET_ENTITYSET
*   and its own header says so. Ports drift, and this one has: the original
*   handles a PP payment-id short link, a CRM billing document and a
*   BUS2000116 tenancy contract, none of which CJS knows about - and on ATB it
*   accepts CLOSED and CONFIRMED with ORDERSTATUS 2 as success, treats READY as
*   open and DECLINED or EXPIRED as FAILED, where the port tests only for the
*   literal 'Success' and calls everything else OPEN. So an ATB payment that
*   closes as CONFIRMED polls forever in CJS, and a declined one never reports
*   declined.
*
*   IT IS SAFE TO CALL OUTSIDE GATEWAY, and that is read off the method rather
*   than assumed: PAYMENTSET_GET_ENTITYSET never references
*   IO_TECH_REQUEST_CONTEXT. It takes one filter, Intreno, and nothing else.
*   That puts it with FeesSet, TrackerSet and ProjectSet in the safe group.
*
*   IV_INTRENO TAKES WHATEVER THE CALLER HOLDS. The DPC resolves a case ext_key,
*   an RE INTRENO, a CRM object id and a PP short link from that one filter, so
*   the resolution that CJS does before calling is not needed - but passing a
*   resolved case is harmless, because a case ext_key is one of the four shapes
*   it already handles.
    METHODS payment_status
      IMPORTING iv_intreno TYPE string
      RETURNING VALUE(rs)  TYPE ty_pay_res.

  PROTECTED SECTION.
  PRIVATE SECTION.

*   A TEST PARTNER, FOR E10 ONLY, AND ONLY FOR PROJECTS.
*   3000018329 is the partner whose ProjectSet answers 207 rows on the live
*   portal - the number in the walkthrough screenshots. The partner CJS
*   resolves on E10 owns none, so M028 step 1 had nothing to draw and no way
*   to tell a broken read from an empty portfolio.
*
*   It is used as a FALLBACK by PROJECTS( ), never as an identity. See the
*   block there for the three conditions that gate it. DELETE THIS CONSTANT
*   AND THAT BLOCK once the resolved partner owns projects of its own.
    CONSTANTS c_test_partner TYPE string VALUE '3000018329'.

*   The read itself, with the partner as a parameter rather than taken from
*   MS_CTX. Extracted for exactly one reason: the fallback has to issue the
*   same call twice with two different partners, and a second hand-written
*   copy of a nine-parameter DPC call is how the two drift apart.
    METHODS read_projects
      IMPORTING iv_partner TYPE string
                iv_case    TYPE string OPTIONAL
                iv_dept    TYPE string OPTIONAL
      RETURNING VALUE(rs)  TYPE ty_project_res.

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

*   THE REAL PARTNER FIRST, ALWAYS. The test partner below is a fallback and
*   never a replacement - so the moment identity resolves correctly this
*   method behaves as though the fallback were not there, and nobody has to
*   remember to take it out before it stops being harmless.
    rs = read_projects( iv_partner = ms_ctx-partner
                        iv_case    = iv_case
                        iv_dept    = iv_dept ).

*   ---- DEV-ONLY TEST PARTNER -----------------------------------------
*   WHY THIS EXISTS. ProjectSet answers 207 projects for 3000018329 on the
*   live portal, and the partner CJS resolves on E10 owns none - so step 1
*   of M028 had nothing to draw and no way to tell a broken read from an
*   empty portfolio. This makes the step testable while the identity
*   question is settled separately.
*
*   THREE THINGS KEEP IT SAFE, and each is deliberate:
*
*   IS_DEV( ) - E10 only. The same gate DEV_MSG( ) and TRACE_OK( ) use. On
*   E20 and E30 this block does not exist, so no citizen can ever be shown
*   another partner's projects.
*
*   FALLBACK, NOT OVERRIDE - it runs only when the real read came back with
*   NO ROWS AND NO ERROR. A partner who owns projects sees their own; an
*   error is left alone, because substituting data on top of a failed read
*   is how a broken service starts looking healthy.
*
*   PROJECTS ONLY - this is not an identity change. MS_CTX-PARTNER is
*   untouched, so fees, parcels, the tracker and every post still run as
*   the real citizen. A test partner that leaked into identity would be a
*   far worse bug than the empty list it fixes.
*
*   AND IT SAYS SO. RS-FLT is what the caller prints, and it names the test
*   partner in capitals - test data that does not announce itself is how a
*   demo ends up quoted as a real figure.
*
*   REMOVE THIS BLOCK AND C_TEST_PARTNER once the partner CJS resolves owns
*   projects of its own. It is one constant and one IF.
    IF rs-rows IS INITIAL
       AND rs-msg IS INITIAL
       AND ms_ctx-partner <> c_test_partner
       AND zcl_rak_journey_util=>is_dev( ) = abap_true.

      DATA(ls_test) = read_projects( iv_partner = c_test_partner
                                     iv_case    = iv_case
                                     iv_dept    = iv_dept ).
      IF ls_test-rows IS NOT INITIAL.
        rs-rows = ls_test-rows.
*       BOTH HALVES, because the first one is the finding. Overwriting the
*       real filter with the test one would hide the very thing worth
*       knowing - that the partner this journey actually resolved owns no
*       projects - behind a list that now looks healthy.
        rs-flt = |{ rs-flt } → 0 rows; retried as { ls_test-flt } | &&
                 |— TEST PARTNER, E10 ONLY, NOT THIS USER|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD payment_status.

*   A STATIC CALL WITH A DYNAMIC TABLE, and the first version had that the
*   wrong way round. It called PAYMENTSET_GET_ENTITYSET through a
*   PARAMETER-TABLE carrying the four parameters that looked interesting, and
*   the runtime said what the three static sibling calls in this class already
*   showed: "the mandatory parameter IV_SOURCE_NAME was not filled". The
*   generated DPC declares ELEVEN exporting parameters and every one of them is
*   mandatory, so a hand-built parameter table is a list to keep in step with a
*   signature nobody here can read - the exact failure mode dynamic calls are
*   supposed to avoid, reintroduced by hand.
*
*   Called statically the COMPILER keeps that list in step, and it costs
*   nothing extra: this class already inherits the DPC and already calls
*   FEESSET, TRACKERSET and PROJECTSET the same way, so the chain is in its
*   load graph regardless.
*
*   NOTHING IS DYNAMIC ANY MORE. The row type was the last unknown and it is
*   now read off the signature - ET_ENTITYSET is ZCL_ZEGA_CJ_MPC=>TT_PAYMENT -
*   so the CREATE DATA that existed to make a wrong guess catchable has no
*   guess left to protect and is gone. IO_TECH_REQUEST_CONTEXT is the only
*   optional parameter on the method; the other ten are mandatory, which is
*   what the first version fell over.
    DATA lt_pay TYPE tt_pay_rows.

    TRY.
        DATA lt_flt TYPE /iwbep/t_mgw_select_option.
        filter( EXPORTING iv_property = `Intreno` iv_value = iv_intreno
                CHANGING  ct_filter   = lt_flt ).

        paymentset_get_entityset(
          EXPORTING
            iv_entity_name           = `Payment`
            iv_entity_set_name       = `PaymentSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
*           Passed like the other three. This one never reads it either - the
*           method takes a single Intreno filter and nothing else - but leaving
*           it out would make a reader wonder which sets are safe.
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = lt_pay ).

*       ONE ROW, ONE COMPONENT. The DPC answers a single-row table and the only
*       component worth reading is STATUS - it writes nothing else.
*
*       ASSIGN COMPONENT rather than <r>-status, even though the type is now
*       known and the direct read would be compiler-checked. The difference is
*       what happens if the generated MPC is ever regenerated with that
*       component renamed: a direct read fails ACTIVATION, taking this class and
*       everything that calls it down, where the assign misses at runtime,
*       leaves the status blank, and POLL_STATUS( ) falls back to the port it
*       has always had. On a payment poll that is the right way round.
        LOOP AT lt_pay ASSIGNING FIELD-SYMBOL(<r>).
          ASSIGN COMPONENT 'STATUS' OF STRUCTURE <r> TO FIELD-SYMBOL(<s>).
          IF sy-subrc = 0.
            rs-status = to_upper( condense( CONV string( <s> ) ) ).
          ENDIF.
          EXIT.
        ENDLOOP.

      CATCH cx_root INTO DATA(lx).
        CLEAR rs-status.
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD read_projects.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

*   PARTNER ONLY, unless the caller named the other two. See the header:
*   the live screen sends exactly this one and gets the full list.
*   ProjectSet reads Dept, not Department. Not a typo here.
    filter( EXPORTING iv_property = `CaseId`  iv_value = iv_case    CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Dept`    iv_value = iv_dept    CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Partner` iv_value = iv_partner CHANGING ct_filter = lt_flt ).

*   Readable back exactly as the portal writes it, so it can be compared with
*   a browser URL character for character. Built by appending only the parts
*   that were actually sent - a VALUE #( ) with blank rows would concatenate
*   into " and  and Partner eq ...", which is worse than no diagnostic.
    DATA lt_show TYPE string_table.
    IF iv_case IS NOT INITIAL.
      APPEND |CaseId eq '{ iv_case }'| TO lt_show.
    ENDIF.
    IF iv_dept IS NOT INITIAL.
      APPEND |Dept eq '{ iv_dept }'| TO lt_show.
    ENDIF.
    IF iv_partner IS NOT INITIAL.
      APPEND |Partner eq '{ iv_partner }'| TO lt_show.
    ELSE.
*     The one that matters most. No partner means no filter at all went out
*     on the property the live screen keys on, and "no projects" then says
*     nothing about the citizen's projects.
      APPEND |Partner NOT RESOLVED| TO lt_show.
    ENDIF.
    rs-flt = concat_lines_of( table = lt_show sep = ` and ` ).

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
