CLASS zcl_rak_bp_popup DEFINITION
  PUBLIC
  CREATE PUBLIC.

* A reusable Partner Search popup. Draws the search form, runs it through
* ZCL_RAK_BP_SEARCH, and leaves the chosen partner in the journey's own model.
*
* PARTNER SEARCH, not Lessor Search. The live screens call the same control
* Lessor Details on one panel and Lessee Details on the next, and it is the same
* search both times - a tenancy has two, a licence transfer has two, a school has
* an owner and a manager. Naming it after one role is how you end up with two
* copies that drift.
*
*
* ============================ SUBJECT KEYED =============================
*
* iv_subject is which partner this is: 'LESSOR', 'LESSEE', 'OWNER', 'MANAGER'.
* Everything the popup reads and writes is prefixed with it, so two of these on
* one journey cannot see each other's answers - which is the failure the owner
* attachment key was added to fix, arriving here for the same reason.
*
* The fields are CONFIGURED, hidden, on the journey. Not popup-local state:
*
*   - bind( ) needs a real model member. There is nothing else to bind to.
*   - the values survive the round trip, the draft save and the resume for free.
*   - the partner reaches the BAdI with TECH_NAME like everything else, which is
*     the entire point of finding it.
*
* Eight fields per subject. <S> is the subject, and SUFFIXES( ) returns this
* list so a seed report and this class cannot disagree about it:
*
*   <S>_SEARCHBY   SELECT    which ID type
*   <S>_IDNUM      INPUT     the number typed, whichever type it is
*   <S>_DOB        DATE      not asked for a trade licence
*   <S>_NAT        SELECT    nationality, from T005T
*   <S>_PARTNER    READONLY  result: BP number
*   <S>_NAME       READONLY  result: name
*   <S>_PHONE      READONLY  result: phone
*   <S>_EMAIL      READONLY  result: email
*
* All eight HIDDEN = X. The popup is the only way in and the result card on the
* step is drawn from the last four.
*
* <S>_PPTYPE WAS A NINTH AND IS GONE - R20-3. It was drawn, bound, and read by
* nothing: RUN_SEARCH( ) never looked at it and ZCL_RAK_BP_SEARCH=>TY_REQ has no
* document-type component to carry it, so there was no route to the backend even
* if somebody had wanted one. The three legacy sources that collect a passport
* type all discard it too - ZCRM_MOI_CR_UPD packs it into ZMOI_PASS_DOCUMENT and
* its DOCUMENT_TYPE selection parameter is commented out. A journey that had not
* configured the field got a box that rendered, opened, accepted a pick and threw
* it away, because BIND_OF( ) answers blank for a component the model lacks and
* nothing says so.
*
*
* ============================ ATTACHING IT ==============================
*
* Three lines in a handler, and the only decision is which ID types the service
* accepts:
*
*   DATA(lo_bp) = NEW zcl_rak_bp_popup(
*                   io_ctx     = io_ctx
*                   iv_subject = 'P1'
*                   it_types   = VALUE #( ( zcl_rak_bp_popup=>c_eid ) )
*                   iv_strict  = abap_true ).
*
*   ON_RENDER_POPUP  lo_bp->render( io_popup ).
*   ON_POPUP_EVENT   IF lo_bp->handle( iv_event ) = abap_true. RETURN. ENDIF.
*
* IT_TYPES blank is the four, so every caller written before this is unchanged.
* One type pre-selects itself and the citizen never sees a dropdown with one
* answer in it.
*
* The four ID types each ask for a different set, exactly as the live screens do,
* and that is decided HERE rather than with rules. Twenty SHOW/HIDE rules per
* subject to express "a trade licence needs no date of birth" would be twenty
* rules restating one fact the popup already knows.
*
* =============================================================================

  PUBLIC SECTION.

*   The four types. Values are the BP ID type codes, so they go to the backend as
*   they stand rather than being translated on the way.
    CONSTANTS c_eid    TYPE string VALUE 'YFS002'.   " Emirates ID
    CONSTANTS c_tlic   TYPE string VALUE 'YP0001'.   " Trade licence
*   CONFIRMED, AND BOTH WERE WRONG. ZCRM_MOI_CR_UPD writes the identification
*   rows itself, so its own codes are authoritative:
*
*     ls_data-eid      -> ls_id-idtype = 'YFS002'   Emirates ID
*     ls_data-uid      -> ls_id-idtype = 'YFS001'   Unified ID
*     ls_data-passport -> ls_id-idtype = 'YFS005'   Passport
*     ls_data-visa     -> ls_id-idtype = 'YFS006'   Visa
*
*   ZWDC_EGA_EBP_SRCH_CREATE->SORT_IDTYPE reads them back with the same four in
*   the same meanings - two independent sources, one of them the writer.
*
*   So passport was YFS004, which appears in no source at all, and unified was
*   YFS005, which is the PASSPORT code. IDTYPE goes out as a filter, so a
*   passport search filtered on a type no partner holds and could never match,
*   while a unified search filtered on the passport type. Neither was visible in
*   testing because live traffic is almost entirely Emirates ID, where YFS002 is
*   correct.
    CONSTANTS c_pass   TYPE string VALUE 'YFS005'.   " Passport
    CONSTANTS c_unif   TYPE string VALUE 'YFS001'.   " Unified ID

*   R20-7. TWO EVENTS, NOT ONE. C_EV_GO backs the type dropdown's CHANGE and
*   only re-renders; C_EV_RUN backs the Search button and searches.
*
*   They were one, with a comment saying switching type "just re-renders".
*   It did not: the branch ran the search whenever IDNUM was filled, so a
*   citizen who typed an Emirates ID and then realised they wanted Passport
*   got an immediate search for a PASSPORT equal to that Emirates ID, which
*   matches nothing, and "No data found" against a form they had not
*   finished. One constant is the whole fix.
    CONSTANTS c_ev_go  TYPE string VALUE 'BPP_SEARCH'.
    CONSTANTS c_ev_run TYPE string VALUE 'BPP_RUN'.
    CONSTANTS c_ev_new TYPE string VALUE 'BPP_RESUME'.
    CONSTANTS c_ev_cxl TYPE string VALUE 'BPP_CLOSE'.

    METHODS constructor
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                iv_subject TYPE string
                iv_title   TYPE string OPTIONAL
*               A TEMPLATE, not a full request. The popup fills the five identity
*               fields from what the citizen typed - IDTYPE, EID, TRADE_LICENCE,
*               DOB, NATIONALITY - and takes EVERYTHING else from here verbatim:
*               NO_MOI_CALL, the three SKIP_ switches, MSG_TYPE, MAX_ROWS, FLAG,
*               ZP28, SEARCH_TERM.
*
*               Passing nothing reproduces the behaviour this popup has always
*               had, so every existing caller is unaffected. Typed as TY_REQ
*               rather than a private options structure so a field added to the
*               request in future needs no change here at all.
                is_search  TYPE zcl_rak_bp_search=>ty_req OPTIONAL
*               R20-2. WHICH ID TYPES THIS SERVICE OFFERS. Blank is the four,
*               exactly as before, so no existing caller changes.
*
*               A trade licence identifies a company. A service that collects
*               a divorcee and two witnesses - all natural persons - was
*               offering a route to a search that could not succeed, and the
*               citizen who took it got "No data found": the wrong answer to
*               a question they should not have been asked.
*
*               ONE TYPE PRE-SELECTS ITSELF. SEARCH_FORM( ) draws nothing
*               until a type is chosen, which for a single-type journey is a
*               dead first screen asking a question with one answer. Only
*               when the citizen has not chosen - a value they picked is
*               never overwritten.
                it_types   TYPE string_table OPTIONAL
*               R20-1. MAKE DATE OF BIRTH AND NATIONALITY REQUIRED TOO.
*
*               Off by default, which is today's behaviour for every caller.
*               On, it is the verification the form already collects: those
*               two are not search narrowing, they are what VALIDATE( )'s MOI
*               cross-check compares against - and that cross-check runs on
*               all three identity branches now. Blank fields mean the popup
*               asks for the verification, sends it, and has nothing to
*               compare. This closes that.
*
*               Never applies to a trade licence, which has neither.
                iv_strict  TYPE abap_bool DEFAULT abap_false.

*   THE FIELD SUFFIXES THIS POPUP READS AND WRITES, for a seed report to
*   create in ZRAK_T_JNY_FLD. Eight per subject, all HIDDEN = X.
*
*   Here rather than in each seed report because a ninth would otherwise be
*   added to the popup and to nothing else - which is how <S>_PPTYPE came to
*   be drawn on journeys that had never configured it.
    CLASS-METHODS suffixes
      RETURNING VALUE(rt) TYPE string_table.

*   Call from on_render_popup( ). Draws the dialog, or the found-partner card when
*   a search has already succeeded.
    METHODS render
      IMPORTING io_popup TYPE REF TO z2ui5_cl_xml_view.

*   Call from on_popup_event( ). abap_true when the event was one of this popup's,
*   so a handler with several popups can chain them.
    METHODS handle
      IMPORTING iv_event     TYPE string
      RETURNING VALUE(rv_ok) TYPE abap_bool.

*   The result, for the step's own read-only card. Blank until a search succeeds.
    METHODS partner
      RETURNING VALUE(rv) TYPE string.

  PROTECTED SECTION.
*   Short alias for ZCL_RAK_TEXT=>GET( ) so every label below fits one line.
*   This popup is shared across journeys, so its own wording belongs in the
*   framework catalogue (ZCL_RAK_TEXT), not hardcoded here - a bare literal
*   is what left the whole dialog untranslated on an Arabic run.
    METHODS t
      IMPORTING iv_no       TYPE symsgno
                iv_default  TYPE string
                iv_v1       TYPE string OPTIONAL
      RETURNING VALUE(rv)   TYPE string.

    METHODS fld
      IMPORTING iv_suffix TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS nationalities
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
*   STILL HERE, AND NO LONGER DRAWN. R20-3 removed the Passport Type box -
*   it bound a field nothing read, TY_REQ has no document-type component to
*   carry it, and the three legacy sources that collect one all discard it
*   (ZCRM_MOI_CR_UPD's DOCUMENT_TYPE selection is commented out). Kept
*   because the list itself is correct and a journey that finds a use for it
*   should not have to rebuild it.
    METHODS doc_types
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   The ID types this popup offers, as key/text. IT_TYPES where the caller
*   named some, the four otherwise. One reader, so the dropdown and the
*   single-type pre-select cannot disagree about what is on offer.
    METHODS types
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   The label for the number field, which is the name of whichever ID type is
*   chosen. ONE METHOD BECAUSE TWO THINGS SAY IT: the form labels the input
*   with it and R20-1's required message names the same thing. Written twice
*   they drift, and the message ends up naming a field the citizen cannot see.
    METHODS id_label
      IMPORTING iv_by     TYPE string
      RETURNING VALUE(rv) TYPE string.

*   R20-1. Everything the form needs before a search is worth sending, with
*   EVERY gap reported in one pass rather than one per press. ABAP_FALSE means
*   messages were added and RUN_SEARCH( ) must not run.
    METHODS validate_form
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS run_search.

*   Read a component by name, trying each candidate in turn, and return blank when
*   none of them is there.
*
*   Dynamic access for THREE FIELDS ONLY, and only because they are display text on
*   a card. Every component that decides anything - PARTNER, CATEGORY,
*   VALID_DATE_TO, EID, DOB, NATIONALITY - is named statically and checked by the
*   compiler, which is where that safety is worth having. Guessing at a name in a
*   validation would be indefensible; guessing at one in a label is a stopgap with a
*   visible failure: the card shows a blank where the name should be.
*
*   Replace with the real component names once SE11 has settled them. The candidate
*   lists then become one entry each and this stays honest.
*   A section heading on the detail view, and the two-column form that
*   follows it. Split because sap.m.SimpleForm cannot hold a heading of its
*   own that looks like the legacy one.
    METHODS section
      IMPORTING io_box   TYPE REF TO z2ui5_cl_xml_view
                iv_title TYPE string.

    METHODS form_of
      IMPORTING io_box        TYPE REF TO z2ui5_cl_xml_view
      RETURNING VALUE(ro_frm) TYPE REF TO z2ui5_cl_xml_view.

*   One label / value pair. A blank value renders an em dash rather than
*   nothing: an empty row beside a label reads as a field that failed to
*   load, where "-" reads as a partner who has no passport on file.
    METHODS pair
      IMPORTING io_form   TYPE REF TO z2ui5_cl_xml_view
                iv_label  TYPE string
                iv_suffix TYPE string.

    METHODS set_detail
      IMPORTING is_bp     TYPE zst_cs_ega_bo_bp_root
                iv_suffix TYPE string
                iv_names  TYPE string.

    METHODS pick
      IMPORTING is_bp        TYPE zst_cs_ega_bo_bp_root
                iv_names     TYPE string
      RETURNING VALUE(rv)    TYPE string.

    METHODS bp_name
      IMPORTING is_bp     TYPE zst_cs_ega_bo_bp_root
      RETURNING VALUE(rv) TYPE string.

  PRIVATE SECTION.
    DATA mo_ctx     TYPE REF TO zif_rak_journey.
    DATA mv_subject TYPE string.
    DATA mv_title   TYPE string.
    DATA ms_search  TYPE zcl_rak_bp_search=>ty_req.
    DATA mt_types   TYPE string_table.
    DATA mv_strict  TYPE abap_bool.
ENDCLASS.



CLASS ZCL_RAK_BP_POPUP IMPLEMENTATION.


  METHOD bp_name.
*   One field if there is one, otherwise build it. A person and an organisation do
*   not hold their name the same way anywhere in SAP BP, so a single candidate list
*   cannot cover both: category 2 keeps it in an org field, category 1 usually in
*   parts.
*   ENGLISH_FULL_NAME first, and ARABIC_FULL_NAME right after it: confirmed
*   against the live OData entity (EnglishFullName / ArabicFullName), which is
*   what actually holds the name on a person - the whole reason a search found
*   the partner but the card showed a blank title.
*   R20-6. THE LANGUAGE DECIDES WHICH OF THE TWO COMES FIRST. PICK( ) takes
*   the first candidate that is both present and filled, so a fixed list with
*   ENGLISH_FULL_NAME at the front reaches ARABIC_FULL_NAME only when the
*   English one is blank - which on real partners it rarely is. An Arabic
*   citizen found their partner and the card named them in English.
*
*   ZCL_RAK_TEXT=>LANG( ) RATHER THAN SY-LANGU, for the reason T( )'s own
*   header gives: this dialog is shared and must follow the engine's resolved
*   language, or a popup ends up in a different language from the step behind
*   it.
*
*   THE REMAINING NINE CANDIDATES DO NOT MOVE. They are the organisation and
*   name-part fallbacks and have no language, so re-ordering them would be
*   churn with nothing behind it.
    DATA(lv_pair) = COND string( WHEN zcl_rak_text=>lang( ) = 'A'
                                 THEN 'ARABIC_FULL_NAME,ENGLISH_FULL_NAME'
                                 ELSE 'ENGLISH_FULL_NAME,ARABIC_FULL_NAME' ).

    rv = pick( is_bp    = is_bp
               iv_names = lv_pair && ',' &&
                          'FULLNAME,NAME,NAME_TEXT,BP_NAME,NAME1,NAME_ORG1,NAME_LAST' ).
    IF rv IS NOT INITIAL.
*     A single field that already holds the whole name - which is what the live
*     screen showed, four name parts in one line.
      RETURN.
    ENDIF.

*   Assembled. Blank parts are skipped rather than leaving double spaces, and the
*   order is the order a name is read in.
    DATA(lv_f) = pick( is_bp = is_bp iv_names = 'NAME_FIRST,FIRSTNAME' ).
    DATA(lv_m) = pick( is_bp = is_bp iv_names = 'NAME_MIDDLE,MIDDLENAME,NAME_MID' ).
    DATA(lv_l) = pick( is_bp = is_bp iv_names = 'NAME_LAST,LASTNAME' ).

    rv = lv_f.
    IF lv_m IS NOT INITIAL.
      rv = COND #( WHEN rv IS INITIAL THEN lv_m ELSE |{ rv } { lv_m }| ).
    ENDIF.
    IF lv_l IS NOT INITIAL.
      rv = COND #( WHEN rv IS INITIAL THEN lv_l ELSE |{ rv } { lv_l }| ).
    ENDIF.
    CONDENSE rv.
  ENDMETHOD.


  METHOD constructor.
    mo_ctx     = io_ctx.
    mv_subject = to_upper( iv_subject ).
    mv_title   = COND #( WHEN iv_title IS NOT INITIAL THEN iv_title
                         ELSE t( iv_no = zcl_rak_text=>c_no-bpp_title iv_default = 'Partner Search' ) ).
    ms_search  = is_search.
    mv_strict  = iv_strict.

*   UPPER-CASED AND CLEANED ON THE WAY IN, once, so every reader downstream
*   compares like with like. A caller writing 'yfs002' means the Emirates ID
*   and should not get an empty dropdown for a typo in the case.
    LOOP AT it_types INTO DATA(lv_t).
      lv_t = to_upper( condense( lv_t ) ).
      CHECK lv_t IS NOT INITIAL.
      APPEND lv_t TO mt_types.
    ENDLOOP.
  ENDMETHOD.


  METHOD suffixes.
    rt = VALUE #( ( `SEARCHBY` ) ( `IDNUM` ) ( `DOB` ) ( `NAT` )
                  ( `PARTNER` )  ( `NAME` )  ( `PHONE` ) ( `EMAIL` ) ).
  ENDMETHOD.


  METHOD types.
    DATA(lt_all) = VALUE zif_rak_journey=>tt_option(
      ( key = c_eid  text = t( iv_no = zcl_rak_text=>c_no-bpp_eid iv_default = 'Emirates ID' ) )
      ( key = c_pass
        text = t( iv_no = zcl_rak_text=>c_no-bpp_passport_ne iv_default = 'Passport (Non EID Holder only)' ) )
      ( key = c_unif
        text = t( iv_no = zcl_rak_text=>c_no-bpp_unified_ne iv_default = 'Unified ID (Non EID Holder only)' ) )
      ( key = c_tlic
        text = t( iv_no = zcl_rak_text=>c_no-bpp_trade_lic iv_default = 'Trade License Number' ) ) ).

    IF mt_types IS INITIAL.
      rt = lt_all.
      RETURN.
    ENDIF.

*   THE CALLER'S ORDER, NOT OURS. A service that leads with a passport should
*   draw the passport first; re-sorting into the popup's own order would take
*   that back for no reason.
*
*   A TYPE THIS POPUP DOES NOT KNOW IS DROPPED, NOT DRAWN. Its label would
*   have to be invented, and RUN_SEARCH( )'s WHEN OTHERS would send the
*   number as an Emirates ID - a search that answers confidently about the
*   wrong thing.
*   NO TRACE LINE FOR A TYPE THAT IS DROPPED, because ZIF_RAK_JOURNEY has no
*   trace channel and casting to the engine to get one would tie this popup
*   to it. It is not silent in practice: IT_TYPES is a constructor argument
*   an author sees the effect of on their first run - the type is simply not
*   in the dropdown.
    LOOP AT mt_types INTO DATA(lv_t).
      READ TABLE lt_all INTO DATA(ls_o) WITH KEY key = lv_t.
      IF sy-subrc = 0.
        APPEND ls_o TO rt.
      ENDIF.
    ENDLOOP.

*   EVERY TYPE REFUSED IS THE FOUR, not an empty dropdown. A caller who
*   mistypes all of them gets the old behaviour and a trace line, rather than
*   a popup with nothing to choose and no way to search at all.
    IF rt IS INITIAL.
      rt = lt_all.
    ENDIF.
  ENDMETHOD.


  METHOD id_label.
    rv = SWITCH string( iv_by
      WHEN c_eid  THEN t( iv_no = zcl_rak_text=>c_no-bpp_eid         iv_default = 'Emirates ID' )
      WHEN c_pass THEN t( iv_no = zcl_rak_text=>c_no-bpp_passport_no iv_default = 'Passport Number' )
      WHEN c_unif THEN t( iv_no = zcl_rak_text=>c_no-bpp_unified_id  iv_default = 'Unified ID' )
      ELSE             t( iv_no = zcl_rak_text=>c_no-bpp_trade_lic   iv_default = 'Trade License Number' ) ).
  ENDMETHOD.


  METHOD validate_form.
*   R20-1. A BLANK ID NUMBER USED TO DO NOTHING AT ALL - no search, no
*   message, no field state, and RV_OK true so the handler could not tell
*   either. The popup's own fields are invisible to MISSING_REQUIRED( ),
*   which walks ZRAK_T_JNY_FLD rows and these are drawn in code, so there is
*   no other layer that could have caught it. It is the popup's or nobody's.
*
*   EVERY GAP IN ONE PASS. Reporting the first and stopping means a citizen
*   who left three fields empty presses Search three times and is told about
*   one each time.
    rv_ok = abap_true.

    DATA(lv_by)  = mo_ctx->get_val( fld( 'SEARCHBY' ) ).
    DATA(lv_num) = condense( mo_ctx->get_val( fld( 'IDNUM' ) ) ).

    IF lv_by IS INITIAL.
*     Not reachable from the form - it returns before drawing Search when no
*     type is chosen - but the event is, and an event is not a screen.
      mo_ctx->add_msg( iv_type = 'Error'
                       iv_text = t( iv_no = zcl_rak_text=>c_no-required
                                    iv_default = '&1 is required'
                                    iv_v1 = t( iv_no = zcl_rak_text=>c_no-bpp_search_by
                                               iv_default = 'Search By' ) ) ).
      rv_ok = abap_false.
      RETURN.
    ENDIF.

    IF lv_num IS INITIAL.
      mo_ctx->add_msg( iv_type = 'Error'
                       iv_text = t( iv_no = zcl_rak_text=>c_no-required
                                    iv_default = '&1 is required'
                                    iv_v1 = id_label( lv_by ) ) ).
      rv_ok = abap_false.

    ELSEIF lv_by = c_eid AND strlen( zcl_rak_bp_search=>norm_eid( lv_num ) ) <> 15.
*     THE FIFTEEN-DIGIT CHECK, AND NORM_EID( )'S OWN COMMENT ASKS FOR IT
*     HERE: "This method normalises; it does not validate. A caller that
*     needs to know whether what is left is a plausible Emirates ID can test
*     STRLEN( ) on the result." This popup is that caller.
*
*     Without it '784' is searched for and comes back "No data found", which
*     tells the citizen their partner does not exist rather than that they
*     stopped typing.
      mo_ctx->add_msg( iv_type = 'Error'
                       iv_text = t( iv_no = zcl_rak_text=>c_no-bad_format
                                    iv_default = '&1 has an invalid format'
                                    iv_v1 = id_label( lv_by ) ) ).
      rv_ok = abap_false.
    ENDIF.

*   THE STRICT HALF, AND NEVER FOR A TRADE LICENCE. A company has no date of
*   birth and no nationality, and the form does not ask for them there.
    IF mv_strict = abap_true AND lv_by <> c_tlic.

      IF mo_ctx->get_val( fld( 'DOB' ) ) IS INITIAL.
        mo_ctx->add_msg( iv_type = 'Error'
                         iv_text = t( iv_no = zcl_rak_text=>c_no-required
                                      iv_default = '&1 is required'
                                      iv_v1 = t( iv_no = zcl_rak_text=>c_no-bpp_dob
                                                 iv_default = 'Date of Birth' ) ) ).
        rv_ok = abap_false.
      ENDIF.

      IF mo_ctx->get_val( fld( 'NAT' ) ) IS INITIAL.
        mo_ctx->add_msg( iv_type = 'Error'
                         iv_text = t( iv_no = zcl_rak_text=>c_no-required
                                      iv_default = '&1 is required'
                                      iv_v1 = t( iv_no = zcl_rak_text=>c_no-bpp_nat
                                                 iv_default = 'Nationality' ) ) ).
        rv_ok = abap_false.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD doc_types.
*   Domain Z_MOI_DOC_TYPE fixed values: 1-9 and 13, ORDINARY PASSPORT through
*   SYRIAN TRAVEL DOCUMENT. Read from the domain rather than listed here, because
*   the day MOI adds a fourteenth this method should already know about it.
*
*   AS4LOCAL = 'A' is the active version. Without it a domain being reworked in a
*   transport can return the inactive value set as well and the list doubles.
    SELECT domvalue_l AS key, ddtext AS text
      FROM dd07t
      WHERE domname  = 'Z_MOI_DOC_TYPE'
        AND ddlanguage = @sy-langu
        AND as4local = 'A'
      ORDER BY domvalue_l ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt.

    IF rt IS INITIAL AND sy-langu <> 'E'.
      SELECT domvalue_l AS key, ddtext AS text
        FROM dd07t
        WHERE domname  = 'Z_MOI_DOC_TYPE'
          AND ddlanguage = 'E'
          AND as4local = 'A'
        ORDER BY domvalue_l ASCENDING
        INTO CORRESPONDING FIELDS OF TABLE @rt.
    ENDIF.
  ENDMETHOD.


  METHOD fld.
    rv = |{ mv_subject }_{ iv_suffix }|.
  ENDMETHOD.


  METHOD t.
    rv = zcl_rak_text=>get( iv_no = iv_no iv_default = iv_default iv_v1 = iv_v1 ).
  ENDMETHOD.


  METHOD handle.
    CASE iv_event.
      WHEN c_ev_go.
*       R20-7. THE TYPE DROPDOWN, AND IT ONLY RE-RENDERS NOW. It used to share
*       this branch with the Search button and search whenever IDNUM was
*       filled, so changing your mind about the type searched for the number
*       you had typed under the OLD type. The round trip is still wanted -
*       the form below the dropdown depends on the answer - it just must not
*       search.
        rv_ok = abap_true.

      WHEN c_ev_run.
*       R20-1. VALIDATED FIRST, AND A REFUSAL IS SAID OUT LOUD. A blank ID
*       number used to produce a round trip and an unchanged screen: no
*       search, no message, no field state, and RV_OK true so the handler
*       could not tell either.
        IF validate_form( ) = abap_true.
          run_search( ).
        ENDIF.
        rv_ok = abap_true.

      WHEN c_ev_new.
*       Resume Search clears the RESULT and nothing else. The search terms stay,
*       because the commonest reason to search again is a typo in one digit.
        mo_ctx->set_val( iv_name = fld( 'PARTNER' ) iv_value = '' ).
        mo_ctx->set_val( iv_name = fld( 'NAME' )    iv_value = '' ).
        mo_ctx->set_val( iv_name = fld( 'PHONE' )   iv_value = '' ).
        mo_ctx->set_val( iv_name = fld( 'EMAIL' )   iv_value = '' ).
        rv_ok = abap_true.

      WHEN c_ev_cxl.
        mo_ctx->close_popup( ).
        rv_ok = abap_true.

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD nationalities.
*   T005T, one language, ordered by code - the same read the OData domain service
*   does. The read itself now lives in ZCL_RAK_JOURNEY_UTIL so a handler that
*   does not inherit from this class can reach the SAME list: D001's owner popup
*   needs it and was hand-maintaining 106 items keyed '1' to '106' instead, with
*   no United Arab Emirates in them. Kept as a method here rather than replaced
*   at the call site, so this class's own contract does not change.
    rt = zcl_rak_journey_util=>nationalities( ).
  ENDMETHOD.


  METHOD partner.
    rv = mo_ctx->get_val( fld( 'PARTNER' ) ).
  ENDMETHOD.


  METHOD pick.
    SPLIT iv_names AT ',' INTO TABLE DATA(lt_try).
    LOOP AT lt_try INTO DATA(lv_try).
      ASSIGN COMPONENT to_upper( condense( lv_try ) ) OF STRUCTURE is_bp
             TO FIELD-SYMBOL(<c>).
      IF sy-subrc = 0 AND <c> IS NOT INITIAL.
        rv = |{ <c> }|.
        CONDENSE rv.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD render.
*   The width is a constructor argument on sap.m.Dialog - there is no setter -
*   so which of the two views we are about to draw has to be decided first. The
*   search form is four fields and sits comfortably in 46rem; the party detail
*   is three sections of paired columns and is cramped in anything under 62rem.
    DATA(lv_found) = xsdbool( partner( ) IS NOT INITIAL ).

    DATA(lo_dlg) = io_popup->dialog(
      title        = mv_title
      contentwidth = COND string( WHEN lv_found = abap_true THEN '62rem' ELSE '46rem' ) ).

*   ---- already found: show, do not ask again -------------------------
*   Resume Search rather than a fresh form every time. A citizen who has found
*   the right partner and reopened the dialog to check a phone number should not
*   have to find them again, and a form pre-filled with the last search reads as
*   though nothing was found.
    IF lv_found = abap_true.
*     PARTY INFORMATION - the legacy page, in the order it reads there:
*     General Info, then Contact Info, then Address Info.
*
*     Read-only throughout, as on the legacy screen. Every value came from
*     the BP and none of it is the citizen's to correct here; a form that
*     looks editable and silently discards an edit is worse than one that
*     plainly does not take any.
*
      DATA(lo_body) = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*     R20-5. A LABEL WITH DESIGN = BOLD, NOT A TITLE, AND THAT IS AN ARABIC
*     FIX. On an Arabic journey ZCL_RAK_JOURNEY_CSS emits a universal family
*     override - .sapUiBody,.sapUiBody *:not(.sapUiIcon){font-family:...
*     !important} - which sets the FAMILY and never a weight. Anything whose
*     boldness came from the theme's own font family loses it, and a plain
*     sap.m.Title has nothing of its own to survive on: the partner's name,
*     the one line on this card meant to stand out, rendered normal weight in
*     Arabic and bold in English.
*
*     DESIGN is a font-weight ON THE CONTROL, which a family swap cannot take
*     away. Proven in Arabic already - it is what JP1's head lines use.
*     WRAPPING because a Label defaults it FALSE where a Title does not, so a
*     long partner name would truncate with an ellipsis instead of wrapping.
*     The cost is body size rather than H4, which is the smaller loss.
*
*     .rakBlkTitle was considered and rejected: another theme variant gives
*     that class a margin and a font-size of its own, so borrowing it would
*     move and resize this line as a side effect.
      lo_body->label( text     = zcl_rak_journey_util=>esc( mo_ctx->get_val( fld( 'NAME' ) ) )
                      design   = 'Bold'
                      wrapping = abap_true ).
      lo_body->object_status(
        text  = t( iv_no = zcl_rak_text=>c_no-bpp_partner_no iv_default = 'Partner &1' iv_v1 = partner( ) )
        state = 'Success'
        class = 'sapUiTinyMarginBottom' ).

      section( io_box = lo_body iv_title = t( iv_no = zcl_rak_text=>c_no-bpp_general iv_default = 'General Info' ) ).
      DATA(lo_res) = form_of( lo_body ).
      pair( io_form = lo_res iv_suffix = 'FIRSTNAME'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_first_name  iv_default = 'First Name' ) ).
      pair( io_form = lo_res iv_suffix = 'FATHERNAME'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_father_name iv_default = 'Father Name' ) ).
      pair( io_form = lo_res iv_suffix = 'GRANDNAME'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_grand_name  iv_default = 'Grandfather Name' ) ).
      pair( io_form = lo_res iv_suffix = 'FOURTHNAME'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_fourth_name iv_default = 'Fourth Name' ) ).
      pair( io_form = lo_res iv_suffix = 'LASTNAME'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_last_name   iv_default = 'Last Name' ) ).
      pair( io_form = lo_res iv_suffix = 'GENDER'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_gender      iv_default = 'Gender' ) ).
      pair( io_form = lo_res iv_suffix = 'IDNO'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_id_no       iv_default = 'ID Number' ) ).
      pair( io_form = lo_res iv_suffix = 'IDEXP'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_id_exp      iv_default = 'ID Expiry date' ) ).
      pair( io_form = lo_res iv_suffix = 'UNIFIED'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_unified_num iv_default = 'Unified Number' ) ).
      pair( io_form = lo_res iv_suffix = 'PPNO'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_passport_no iv_default = 'Passport Number' ) ).
      pair( io_form = lo_res iv_suffix = 'PPFROM'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_pp_issue    iv_default = 'Date of passport Issue' ) ).
      pair( io_form = lo_res iv_suffix = 'PPPLACE'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_pp_country  iv_default = 'Country of passport Issue' ) ).
      pair( io_form = lo_res iv_suffix = 'PPTO'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_pp_exp      iv_default = 'Passport Expiry Date' ) ).
      pair( io_form = lo_res iv_suffix = 'NAT'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_nat         iv_default = 'Nationality' ) ).
      pair( io_form = lo_res iv_suffix = 'OCC'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_occupation  iv_default = 'Occupation' ) ).
      pair( io_form = lo_res iv_suffix = 'DOBV'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_dob         iv_default = 'Date of Birth' ) ).

      section( io_box = lo_body iv_title = t( iv_no = zcl_rak_text=>c_no-bpp_contact iv_default = 'Contact Info' ) ).
      DATA(lo_con) = form_of( lo_body ).
      pair( io_form = lo_con iv_suffix = 'PHONE'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_mobile    iv_default = 'Mobile Number' ) ).
      pair( io_form = lo_con iv_suffix = 'EMAIL'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_email     iv_default = 'Email' ) ).
      pair( io_form = lo_con iv_suffix = 'TEL'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_telephone iv_default = 'Telephone' ) ).

      section( io_box = lo_body iv_title = t( iv_no = zcl_rak_text=>c_no-bpp_address iv_default = 'Address Info' ) ).
      DATA(lo_adr) = form_of( lo_body ).
      pair( io_form = lo_adr iv_suffix = 'COUNTRY'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_country  iv_default = 'Country Of Living' ) ).
      pair( io_form = lo_adr iv_suffix = 'REGION'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_region   iv_default = 'Region' ) ).
      pair( io_form = lo_adr iv_suffix = 'CITY'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_city     iv_default = 'City' ) ).
      pair( io_form = lo_adr iv_suffix = 'STREET'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_street   iv_default = 'Street Name' ) ).
      pair( io_form = lo_adr iv_suffix = 'HOUSE'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_house_no iv_default = 'Home Number' ) ).
      pair( io_form = lo_adr iv_suffix = 'POBOX'
            iv_label = t( iv_no = zcl_rak_text=>c_no-bpp_pobox    iv_default = 'PO Box' ) ).

      DATA(lo_rb) = lo_dlg->buttons( ).
      lo_rb->button( text  = t( iv_no = zcl_rak_text=>c_no-bpp_resume iv_default = 'Resume Search' )
                     icon  = 'sap-icon://synchronize'
                     press = mo_ctx->event( c_ev_new ) ).
      lo_rb->button( text  = t( iv_no = zcl_rak_text=>c_no-bpp_use_partner iv_default = 'Use this partner' )
                     type  = 'Emphasized'
                     icon  = 'sap-icon://accept'
                     press = mo_ctx->event( c_ev_cxl ) ).
      RETURN.
    ENDIF.

*   ---- the search form -----------------------------------------------
    DATA(lt_types) = types( ).
    DATA(lv_by)    = mo_ctx->get_val( fld( 'SEARCHBY' ) ).

*   R20-2. ONE TYPE ANSWERS ITSELF. A service that accepts only an Emirates
*   ID has no question to ask, and the form draws nothing until a type is
*   chosen - so without this the citizen's first screen is a dropdown with
*   one item and no way forward until they open it.
*
*   ONLY WHEN BLANK. A type the citizen picked is never overwritten, so this
*   cannot fight them on a multi-type journey.
    IF lv_by IS INITIAL AND lines( lt_types ) = 1.
      lv_by = VALUE #( lt_types[ 1 ]-key OPTIONAL ).
      mo_ctx->set_val( iv_name = fld( 'SEARCHBY' ) iv_value = lv_by ).
    ENDIF.

*   R20-4. NO SIMPLEFORM, AND THIS IS THE ARABIC FIX.
*
*   SimpleForm + ResponsiveGridLayout put the label and its control at
*   OPPOSITE EDGES of the row in Arabic, with the gap between them, and the
*   label column was too narrow for "رقم الهوية الإماراتية" - which wrapped
*   to two lines and pushed its own control down a row. LABELSPAN with
*   ADJUSTLABELSPAN off changed nothing. ColumnLayout is not the answer
*   either: it refuses sap.m.Title as form content and takes the whole app
*   down rather than the field.
*
*   So: no form. A VBOX with the label ABOVE the control at full width. The
*   gap is a number in one place instead of something negotiated with a
*   layout algorithm, and it reads the same in both directions because a box
*   follows the page.
*
*   NO WIDTH ON THE BOX, deliberately. A width '100%' box carrying
*   SAPUISMALLMARGIN overflows its container by 2rem and the dialog grows a
*   horizontal scrollbar. Left off, a block-level box with width auto fills
*   its container minus its margins - and its used width is then DEFINITE,
*   which is what gives a child's '100%' something real to resolve against.
    DATA(lo_form) = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

    lo_form->label( text     = t( iv_no = zcl_rak_text=>c_no-bpp_search_by iv_default = 'Search By' )
                    wrapping = abap_true ).

*   R14-1. SELECT, NOT COMBOBOX - AND FORCESELECTION PASSED EXPLICITLY.
*
*   These four keys are appended by this method. There is no free-text case,
*   so a typable box offers a keyboard on a touch device and accepts input
*   that can never match. That is what CLOSED_LIST fixed on configured
*   fields, and then this popup opened on top of them still typable -
*   CLOSED_LIST cannot reach here, because these are the engine's own
*   controls and not ZRAK_T_JNY_FLD rows.
*
*   FORCESELECTION = ABAP_FALSE IS NOT OPTIONAL AND NOT A DEFAULT.
*   An unsupplied z2ui5 OPTIONAL arrives blank, XML_GET_PARTS( ) drops every
*   blank property from the markup, and sap.m.Select's own default of TRUE
*   then applies - so an untouched Search By would DRAW "Emirates ID" while
*   the model still held nothing.
*
*   On this screen that is worse than on a form field. The very next
*   statement is IF lv_by IS INITIAL -> buttons, RETURN. So the citizen
*   would see a dropdown reading "Emirates ID", no number field beneath it,
*   and a popup offering nothing but Close: a screen that looks answered and
*   is empty. ABAP_FALSE works because it is typed ABAP_BOOL and renders the
*   literal string 'false', which is not blank and survives the filter.
*
*   NO BLANK LEADING ITEM HERE. The form cannot proceed without an answer, so
*   this is required in everything but the column, and a blank item would be
*   a value the citizen can pick that takes the form back to nothing. That is
*   R13-8's own rule, which gates its leading item on REQUIRED = FALSE.
    DATA(lo_by) = lo_form->select( selectedkey    = mo_ctx->bind( fld( 'SEARCHBY' ) )
                                   width          = '100%'
                                   forceselection = abap_false
                                   change         = mo_ctx->event( c_ev_go ) ).
    LOOP AT lt_types INTO DATA(ls_ty).
      lo_by->item( key = ls_ty-key text = ls_ty-text ).
    ENDLOOP.

*   Nothing else until a type is chosen. The live screen asks one question first
*   for a reason: the answer decides what the rest of the form even is.
    IF lv_by IS INITIAL.
      lo_dlg->buttons( )->button( text = t( iv_no = zcl_rak_text=>c_no-close iv_default = 'Close' )
                                  press = mo_ctx->event( c_ev_cxl ) ).
      RETURN.
    ENDIF.

*   The number, labelled as whatever was chosen. One field, four labels - a
*   second input per type would be four model members holding one answer, and
*   then a question about which of them the backend should believe.
*   THROUGH ID_LABEL( ), which R20-1's required message also calls - so
*   "Passport Number is required" always names the field the citizen is
*   looking at.
*   REQUIRED UNCONDITIONALLY, unlike the two below. A search with no number
*   is not a narrower search, it is no search - which is why R20-1 refuses it
*   whatever IV_STRICT says, and the marker has to agree with the refusal or
*   it is the looks-optional-and-will-not-submit bug in a popup.
    lo_form->label( text     = id_label( lv_by )
                    required = abap_true
                    wrapping = abap_true
                    class    = 'sapUiTinyMarginTop' ).
    lo_form->input( value = mo_ctx->bind( fld( 'IDNUM' ) ) width = '100%' ).

*   A trade licence is a company. It has no date of birth and no nationality, and
*   asking for them is how a form gets abandoned.
    IF lv_by <> c_tlic.
      lo_form->label( text     = t( iv_no = zcl_rak_text=>c_no-bpp_dob iv_default = 'Date of Birth' )
                      required = mv_strict
                      wrapping = abap_true
                      class    = 'sapUiTinyMarginTop' ).
*     DDMMYYYY on screen, YYYYMMDD in the value. The MOI cross-check compares the
*     date sent against the date the BP holds as strings, so a display format
*     reaching the request would fail every comparison and read as a data
*     mismatch rather than a format one.
      lo_form->date_picker( value        = mo_ctx->bind( fld( 'DOB' ) )
                            width         = '100%'
                            displayformat = 'dd.MM.yyyy'
                            valueformat   = 'yyyyMMdd' ).

      lo_form->label( text     = t( iv_no = zcl_rak_text=>c_no-bpp_nat iv_default = 'Nationality' )
                      required = mv_strict
                      wrapping = abap_true
                      class    = 'sapUiTinyMarginTop' ).
*     Closed by construction: the list is NATIONALITIES( ). Same reasoning and
*     the same explicit FORCESELECTION as Search By above.
*
*     A BLANK LEADING ITEM, unlike Search By. Nationality is not required to
*     search - ADD_FLT( ) only rejects a blank value, it never demands this
*     one - so without a way back the first nationality in the list becomes
*     the search's nationality the moment the box is drawn, silently
*     narrowing a search the citizen never narrowed. That is exactly the
*     case R13-8's leading item is for.
*     NO BLANK LEADING ITEM UNDER IV_STRICT. The leading item exists so the
*     first nationality cannot become the search's nationality by being drawn
*     first - a real hazard while the field is optional. Where the journey
*     has made it required, that same item is a value the citizen can pick
*     which fails the check they are about to meet, so it goes.
      DATA(lo_nat) = lo_form->select( selectedkey    = mo_ctx->bind( fld( 'NAT' ) )
                                      width          = '100%'
                                      forceselection = abap_false ).
      IF mv_strict = abap_false.
        lo_nat->item( key  = ``
                      text = t( iv_no = zcl_rak_text=>c_no-opt_none iv_default = '(none)' ) ).
      ENDIF.
      LOOP AT nationalities( ) INTO DATA(ls_n).
        lo_nat->item( key = ls_n-key text = ls_n-text ).
      ENDLOOP.
    ENDIF.

*   R20-3. THE PASSPORT TYPE BOX WAS HERE AND IS GONE. It bound <S>_PPTYPE,
*   which RUN_SEARCH( ) never read and TY_REQ has no component to carry - so
*   the citizen was asked a question with no destination, and on a journey
*   that had not configured the field the control rendered, opened, accepted
*   a pick and discarded it in silence. DOC_TYPES( ) stays for whoever finds
*   a use for the list; nothing draws it today.

    DATA(lo_btns) = lo_dlg->buttons( ).
*   C_EV_RUN, NOT C_EV_GO - R20-7. The dropdown keeps C_EV_GO and only
*   re-renders; this is the only control that searches.
    lo_btns->button( text  = t( iv_no = zcl_rak_text=>c_no-search iv_default = 'Search' )
                     type  = 'Emphasized'
                     icon  = 'sap-icon://search'
                     press = mo_ctx->event( c_ev_run ) ).
    lo_btns->button( text  = t( iv_no = zcl_rak_text=>c_no-close iv_default = 'Close' )
                     press = mo_ctx->event( c_ev_cxl ) ).
  ENDMETHOD.


  METHOD run_search.
*   Start from the caller's template so NO_MOI_CALL, the SKIP_ switches, MSG_TYPE
*   and MAX_ROWS are theirs. Only the identity fields below are the popup's.
    DATA(ls_req) = ms_search.

    DATA(lv_by)  = mo_ctx->get_val( fld( 'SEARCHBY' ) ).
    DATA(lv_num) = mo_ctx->get_val( fld( 'IDNUM' ) ).

    ls_req-idtype      = lv_by.
    ls_req-dob         = mo_ctx->get_val( fld( 'DOB' ) ).
    ls_req-nationality = mo_ctx->get_val( fld( 'NAT' ) ).

    CASE lv_by.
      WHEN c_eid.
        ls_req-eid = lv_num.
*       CallMoi with Flag blank is the full check: MOI is called, the BP is
*       updated from it, and a date of birth or nationality that disagrees is
*       rejected. That is the point of asking for those two on this branch - they
*       are not search narrowing, they are the verification.
*
*       Only when the template has not already said NO_MOI_CALL. Setting
*       CALL_MOI = X and then relying on ZCL_RAK_BP_SEARCH's "NO_MOI_CALL wins"
*       precedence to cancel it back out sends a CallMoi parameter that does not
*       match the caller's actual intent - a light-search template like Notary's
*       (see ZCL_RAK_NOT_APPROVAL_LOGIC=>BP_OPTS) asked for CALL_MOI to stay
*       blank, and it should leave this method blank rather than arrive true and
*       be cancelled downstream.
        IF ls_req-no_moi_call = abap_false.
          ls_req-call_moi = abap_true.
        ENDIF.
      WHEN c_tlic.
        ls_req-trade_licence = lv_num.
      WHEN c_pass.
*       ITS OWN FIELD NOW, not EID. The backend has a named property per
*       identifier - 'DOCUMENT_NUMBER' for a passport, 'UID' for a unified
*       number - so sending either under 'EId' asked which partner holds an
*       Emirates ID equal to a passport number, matched nothing, and reported
*       "No data found". See the note on ZCL_RAK_BP_SEARCH=>TY_REQ.
        ls_req-document_number = lv_num.
*       CALL_MOI HERE TOO, for the same reason it is set on the EId branch.
*       SEARCH_FORM( ) collects a date of birth and a nationality on every
*       branch except the trade licence - the guard there is only
*       IF lv_by <> c_tlic - and VALIDATE( )'s cross-check is gated on
*       CALL_MOI. Setting it only for an Emirates ID meant a passport or
*       unified search ASKED the citizen for both fields, SENT both, and
*       compared neither: a partner nobody had verified came back and nothing
*       on screen said so.
*
*       Three sources agree that verification is not Emirates-ID-only:
*       ZCRM_MOI_CR_UPD appends CallMoi = 'X' ahead of its branch and guards
*       the cross-check with only IF lv_selection NE '4', SET_MOI_QUERY_PARAM
*       appends it ahead of its branch too, and VALIDATE_MOI_TO_INPUT runs for
*       sel_index ne 4 and ne 5.
*
*       Every opt-out is intact: NO_MOI_CALL still suppresses the call,
*       SKIP_MOI_MISMATCH still keeps the call and drops the verdict, and
*       FLAG = 'X' still does the same for an older caller. A journey that
*       wants the previous behaviour on these branches sets one field.
*
*       Note this does NOT make a wrong nationality reportable on the passport
*       branch: a passport number is only unique within its issuing country, so
*       nationality is part of that key and a wrong one finds nobody at all -
*       VALIDATE( ) returns on the empty READ and "No data found" is the only
*       message. It is the DATE OF BIRTH this recovers there, and both fields
*       on the unified branch.
        IF ls_req-no_moi_call = abap_false.
          ls_req-call_moi = abap_true.
        ENDIF.
      WHEN c_unif.
        ls_req-uid = lv_num.
        IF ls_req-no_moi_call = abap_false.
          ls_req-call_moi = abap_true.
        ENDIF.
      WHEN OTHERS.
*       An id type this popup does not know. EID stays the fallback rather than
*       dropping the number silently.
        ls_req-eid = lv_num.
    ENDCASE.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

    DATA(lv_err) = abap_false.
    LOOP AT ls_res-msg INTO DATA(ls_m).
      mo_ctx->add_msg( iv_type = COND string( WHEN ls_m-type = 'E' OR ls_m-type = 'A' THEN 'Error'
                                         WHEN ls_m-type = 'W' THEN 'Warning'
                                         ELSE 'Information' )
                       iv_text = CONV string( ls_m-message ) ).
      IF ls_m-type = 'E' OR ls_m-type = 'A'.
        lv_err = abap_true.
      ENDIF.
    ENDLOOP.

*   An expired licence is an error and must NOT become a found partner. The whole
*   reason the expiry rules moved into ZCL_RAK_BP_SEARCH is that a caller which
*   ignores them is worse than one that never had them.
    IF lv_err = abap_true.
      RETURN.
    ENDIF.

    READ TABLE ls_res-rows INTO DATA(ls_bp) INDEX 1.
    IF sy-subrc <> 0.

*     "No data found" and nothing else, which cannot distinguish the handful of
*     things that actually produce it: the partner not existing in THIS client,
*     BUT0ID holding a different identification type, a normalisation that did
*     not fire, or a CallMoi that came back with nothing. Under trace, say what
*     was searched for so the answer is one glance instead of four guesses.
*
*     The normalised number is the important half. 784-1988-2718131-8 and
*     784198827181318 are the same Emirates ID and only one of them is what
*     BUT0ID holds, so seeing which form went to the query settles the question
*     that NORM_EID exists to answer.
      IF mo_ctx->get_param( 'trace' ) IS NOT INITIAL.
*       Built up in steps rather than as one nested template. The alternative
*       needs a string template inside an embedded expression inside another
*       template, which ABAP allows and no reader should have to unpick.
        DATA(lv_dg) = |TRACE  BP  no rows · client { sy-mandt }|.

        lv_dg = lv_dg && ` · idtype `
             && COND string( WHEN ls_req-idtype IS NOT INITIAL
                             THEN ls_req-idtype ELSE '(blank)' ).

        IF ls_req-eid IS NOT INITIAL.
          lv_dg = lv_dg && | · searched [{ ls_req-eid }]|.
        ENDIF.
        IF ls_req-trade_licence IS NOT INITIAL.
          lv_dg = lv_dg && | · licence [{ ls_req-trade_licence }]|.
        ENDIF.

        lv_dg = lv_dg
             && COND string( WHEN ls_req-dob IS NOT INITIAL
                             THEN | · dob { ls_req-dob }| ELSE ` · dob not given` )
             && COND string( WHEN ls_req-nationality IS NOT INITIAL
                             THEN | · nat { ls_req-nationality }| ELSE ` · nat not given` )
             && COND string( WHEN ls_req-call_moi = abap_true
                             THEN ` · MOI called` ELSE ` · MOI not called` ).

        mo_ctx->add_msg( iv_type = 'Information' iv_text = lv_dg ).
      ENDIF.

      RETURN.
    ENDIF.

*   PARTNER and TELEPHONE_NUMBER are the real names - the first proven by the DPC,
*   the second by the compiler. Name and email go through the candidate list.
*
*   TELEPHONE_NUMBER first, MOBILE_NUMBER as a fallback: confirmed against the
*   live OData entity, TelephoneNumber is blank on plenty of real partners while
*   MobileNumber carries the number - a landline field left empty is not "this
*   partner has no phone", and a card that only ever reads the landline showed
*   blank next to a partner the citizen had just typed a mobile search on.
    DATA(lv_phone) = CONV string( ls_bp-telephone_number ).
    IF lv_phone IS INITIAL.
      lv_phone = pick( is_bp = ls_bp iv_names = 'MOBILE_NUMBER,MOBILE,CELLPHONE' ).
    ENDIF.

    mo_ctx->set_val( iv_name = fld( 'PARTNER' ) iv_value = CONV string( ls_bp-partner ) ).
    mo_ctx->set_val( iv_name = fld( 'PHONE' )   iv_value = lv_phone ).
    mo_ctx->set_val( iv_name = fld( 'NAME' )    iv_value = bp_name( ls_bp ) ).
    mo_ctx->set_val( iv_name = fld( 'EMAIL' )
                     iv_value = pick( is_bp    = ls_bp
                                      iv_names = 'EMAIL_ID,SMTP_ADDR,EMAIL,E_MAIL,EMAILADDRESS,EMAIL_ADDRESS' ) ).

*   ---- the rest of the party, for the detail view ---------------------
*
*   The legacy Party Information page shows about twenty-five fields across
*   General, Contact and Address. Five of them were being kept and the rest
*   thrown away, so the CJS step could only ever show a quarter of what the
*   officer sees - and there was no way to check a passport expiry or a
*   home address before adding the party.
*
*   These names are NOT configured fields, and that is deliberate: VAL_SET( )
*   falls back to the engine's scratch table for a name the model does not
*   carry, and VAL_GET( ) reads it straight back. So the whole party survives
*   the round trip without twenty rows per party in ZRAK_T_JNY_FLD - which
*   would also have had to be seeded twice, once for each side.
*
*   PICK( ) rather than a static component read throughout. It takes the
*   first name that both exists and is filled, so a component missing on an
*   older BP structure yields blank instead of refusing to activate.
    set_detail( is_bp = ls_bp iv_suffix = 'FIRSTNAME'  iv_names = 'FIRST_NAME' ).
    set_detail( is_bp = ls_bp iv_suffix = 'FATHERNAME' iv_names = 'SECOND_NAME' ).
    set_detail( is_bp = ls_bp iv_suffix = 'GRANDNAME'  iv_names = 'THIRD_NAME' ).
    set_detail( is_bp = ls_bp iv_suffix = 'FOURTHNAME' iv_names = 'FOURTH_NAME' ).
    set_detail( is_bp = ls_bp iv_suffix = 'LASTNAME'   iv_names = 'FIFTH_NAME' ).
    set_detail( is_bp = ls_bp iv_suffix = 'GENDER'     iv_names = 'GENDER_DESCRIPTION,SEX' ).
    set_detail( is_bp = ls_bp iv_suffix = 'IDNO'       iv_names = 'EID,IDNUMBER' ).
    set_detail( is_bp = ls_bp iv_suffix = 'IDEXP'      iv_names = 'VALID_DATE_TO' ).
    set_detail( is_bp = ls_bp iv_suffix = 'UNIFIED'    iv_names = 'UID' ).
    set_detail( is_bp = ls_bp iv_suffix = 'PPNO'       iv_names = 'PASSPORT' ).
    set_detail( is_bp = ls_bp iv_suffix = 'PPFROM'     iv_names = 'P_VALID_DATE_FROM' ).
    set_detail( is_bp = ls_bp iv_suffix = 'PPTO'       iv_names = 'P_VALID_DATE_TO' ).
    set_detail( is_bp = ls_bp iv_suffix = 'PPPLACE'    iv_names = 'ISSUEPLACEEN,ISSUEPLACEAR' ).
    set_detail( is_bp = ls_bp iv_suffix = 'OCC'        iv_names = 'OCCUPATION' ).
    set_detail( is_bp = ls_bp iv_suffix = 'DOBV'       iv_names = 'DOB,DATE_OF_BIRTH' ).
    set_detail( is_bp = ls_bp iv_suffix = 'TEL'        iv_names = 'TELEPHONE_NUMBER' ).
    set_detail( is_bp = ls_bp iv_suffix = 'COUNTRY'    iv_names = 'COUNTRY' ).
*   REGION before EMIRATE: on this structure both are REGIO and the legacy
*   screen labels the value Region, so the field that shares its name wins.
    set_detail( is_bp = ls_bp iv_suffix = 'REGION'     iv_names = 'REGIONAR,REGION,EMIRATE_DESC,EMIRATE' ).
    set_detail( is_bp = ls_bp iv_suffix = 'CITY'       iv_names = 'CITY,DISTRICT' ).
    set_detail( is_bp = ls_bp iv_suffix = 'STREET'     iv_names = 'STREET_INTL,STREET' ).
    set_detail( is_bp = ls_bp iv_suffix = 'HOUSE'      iv_names = 'HOUSE_NUMBER,BUILDING' ).
    set_detail( is_bp = ls_bp iv_suffix = 'POBOX'      iv_names = 'POBOX' ).
  ENDMETHOD.


  METHOD section.
*   A BOLD LABEL, NOT A TITLE, for the reason set out at the partner's name
*   in RENDER( ): a Title's boldness comes from the theme's font family and
*   the Arabic override replaces the family without setting a weight. Three
*   section headings on this card had the same defect as the name, and were
*   not raised only because nobody expects a heading to be bold in one
*   language and not the other until they see it.
*
*   IT ALSO LEAVES NO SAP.M.TITLE ON THE CARD AT ALL, which is what
*   ColumnLayout refuses as form content - so if that layout is ever wanted
*   here, this is no longer what blocks it.
    io_box->label( text     = iv_title
                   design   = 'Bold'
                   wrapping = abap_true
                   class    = 'sapUiSmallMarginTop sapUiTinyMarginBottom' ).
  ENDMETHOD.


  METHOD form_of.
*   R20-4. A PLAIN BOX. The SimpleForm that used to be here put the label at
*   the opposite edge of the row from its value in Arabic - see the search
*   form for the full reasoning and the two traps that come with replacing
*   it. Each row is drawn by PAIR( ) below.
    ro_frm = io_box->vbox( ).
  ENDMETHOD.


  METHOD pair.
*   ONE ROW: a fixed-width label and the value beside it.
*
*   AN HBOX, AND THE LABEL WIDTH IS A REM RATHER THAN A PERCENTAGE. A
*   percentage width inside an HBOX row collapses, because a flex item's
*   width comes from its content and that is indefinite - the same property
*   that fills the container on the VBOX in the search form does nothing
*   here. The one number is 16rem, which holds the longest Arabic caption on
*   this card without wrapping.
*
*   THE ORDER IS THE PAGE'S, NOT OURS. An HBOX follows the reading direction,
*   so label-then-value comes out right-to-left in Arabic with no second
*   layout and no mirroring rule.
    DATA(lv_val) = mo_ctx->get_val( fld( iv_suffix ) ).
    DATA(lo_row) = io_form->hbox( class = 'sapUiTinyMarginBottom' ).

    lo_row->label( text     = iv_label
                   width    = '16rem'
                   wrapping = abap_true ).
*   A BLANK VALUE RENDERS AN EM DASH rather than nothing: an empty row beside
*   a label reads as a field that failed to load, where "-" reads as a
*   partner who has no passport on file.
    lo_row->text( text     = zcl_rak_journey_util=>esc(
                               COND string( WHEN lv_val IS NOT INITIAL THEN lv_val ELSE `-` ) )
                  wrapping = abap_true ).
  ENDMETHOD.


  METHOD set_detail.
*   One party attribute onto the scratch model. Blank is written as blank
*   rather than skipped, so a second search that finds a partner without a
*   passport does not leave the previous partner's passport on the screen.
    mo_ctx->set_val( iv_name  = fld( iv_suffix )
                     iv_value = pick( is_bp = is_bp iv_names = iv_names ) ).
  ENDMETHOD.
ENDCLASS.
