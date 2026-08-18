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
* Nine fields per subject. <S> is the subject:
*
*   <S>_SEARCHBY   SELECT    which ID type - the four below
*   <S>_IDNUM      INPUT     the number typed, whichever type it is
*   <S>_DOB        DATE      not asked for a trade licence
*   <S>_NAT        SELECT    nationality, from T005T
*   <S>_PPTYPE     SELECT    passport type, from domain Z_MOI_DOC_TYPE
*   <S>_PARTNER    READONLY  result: BP number
*   <S>_NAME       READONLY  result: name
*   <S>_PHONE      READONLY  result: phone
*   <S>_EMAIL      READONLY  result: email
*
* All nine HIDDEN = X. The popup is the only way in and the result card on the
* step is drawn from the last four.
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
    CONSTANTS c_pass   TYPE string VALUE 'YFS004'.   " Passport      - CONFIRM, see below
    CONSTANTS c_unif   TYPE string VALUE 'YFS005'.   " Unified ID    - CONFIRM, see below

    CONSTANTS c_ev_go  TYPE string VALUE 'BPP_SEARCH'.
    CONSTANTS c_ev_new TYPE string VALUE 'BPP_RESUME'.
    CONSTANTS c_ev_cxl TYPE string VALUE 'BPP_CLOSE'.

    METHODS constructor
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                iv_subject TYPE string
                iv_title   TYPE string OPTIONAL.

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
    METHODS fld
      IMPORTING iv_suffix TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS nationalities
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS doc_types
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

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
ENDCLASS.



CLASS ZCL_RAK_BP_POPUP IMPLEMENTATION.


  METHOD bp_name.
*   One field if there is one, otherwise build it. A person and an organisation do
*   not hold their name the same way anywhere in SAP BP, so a single candidate list
*   cannot cover both: category 2 keeps it in an org field, category 1 usually in
*   parts.
    rv = pick( is_bp    = is_bp
               iv_names = 'FULLNAME,NAME,NAME_TEXT,BP_NAME,NAME1,NAME_ORG1,NAME_LAST' ).
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
    mv_title   = COND #( WHEN iv_title IS NOT INITIAL THEN iv_title ELSE 'Partner Search' ).
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


  METHOD handle.
    CASE iv_event.
      WHEN c_ev_go.
*       The same event backs the Search button AND the type dropdown's change, so
*       switching type just re-renders. Cheap, and it means the form cannot show a
*       passport type box next to an Emirates ID for one round trip.
        IF mo_ctx->get_val( fld( 'IDNUM' ) ) IS NOT INITIAL.
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
*   does. Written as SELECT ... INTO TABLE rather than SELECT ... ENDSELECT: the
*   loop form holds a database cursor open for the whole of the loop body, and
*   this one is a single round trip for about 240 rows.
    SELECT land1 AS key, landx50 AS text
      FROM t005t
      WHERE spras = @sy-langu
      ORDER BY land1 ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt.

*   Falling back to English rather than to nothing. A journey launched in a
*   language T005T has no rows for would otherwise show an empty nationality list,
*   which looks like a broken control rather than a missing translation.
    IF rt IS INITIAL AND sy-langu <> 'E'.
      SELECT land1 AS key, landx50 AS text
        FROM t005t
        WHERE spras = 'E'
        ORDER BY land1 ASCENDING
        INTO CORRESPONDING FIELDS OF TABLE @rt.
    ENDIF.
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
    DATA(lo_dlg) = io_popup->dialog( title = mv_title contentwidth = '46rem' ).

*   ---- already found: show, do not ask again -------------------------
*   Resume Search rather than a fresh form every time. A citizen who has found
*   the right partner and reopened the dialog to check a phone number should not
*   have to find them again, and a form pre-filled with the last search reads as
*   though nothing was found.
    IF partner( ) IS NOT INITIAL.
      DATA(lo_res) = lo_dlg->content(
        )->simple_form( editable  = abap_false
                        layout    = 'ResponsiveGridLayout'
                        columnsxl = '2' columnsl = '2' columnsm = '1'
        )->content( ns = 'form' ).

      lo_res->title( zcl_rak_journey_util=>esc( mo_ctx->get_val( fld( 'NAME' ) ) ) ).
      lo_res->label( 'Partner' ).
      lo_res->text( zcl_rak_journey_util=>esc( partner( ) ) ).
      lo_res->label( 'Nationality' ).
      lo_res->text( zcl_rak_journey_util=>esc( mo_ctx->get_val( fld( 'NAT' ) ) ) ).
      lo_res->label( 'Phone Number' ).
      lo_res->text( zcl_rak_journey_util=>esc( mo_ctx->get_val( fld( 'PHONE' ) ) ) ).
      lo_res->label( 'Email' ).
      lo_res->text( zcl_rak_journey_util=>esc( mo_ctx->get_val( fld( 'EMAIL' ) ) ) ).

      DATA(lo_rb) = lo_dlg->buttons( ).
      lo_rb->button( text  = 'Resume Search'
                     icon  = 'sap-icon://synchronize'
                     press = mo_ctx->event( c_ev_new ) ).
      lo_rb->button( text  = 'Use this partner'
                     type  = 'Emphasized'
                     icon  = 'sap-icon://accept'
                     press = mo_ctx->event( c_ev_cxl ) ).
      RETURN.
    ENDIF.

*   ---- the search form -----------------------------------------------
    DATA(lv_by) = mo_ctx->get_val( fld( 'SEARCHBY' ) ).

    DATA(lo_form) = lo_dlg->content(
      )->simple_form( editable  = abap_true
                      layout    = 'ResponsiveGridLayout'
                      columnsxl = '2' columnsl = '2' columnsm = '1'
      )->content( ns = 'form' ).

    lo_form->label( 'Search By' ).
    DATA(lo_by) = lo_form->combobox( selectedkey = mo_ctx->bind( fld( 'SEARCHBY' ) )
                                     change      = mo_ctx->event( c_ev_go ) ).
    lo_by->item( key = c_eid  text = 'Emirates ID' ).
    lo_by->item( key = c_pass text = 'Passport (Non EID Holder only)' ).
    lo_by->item( key = c_unif text = 'Unified ID (Non EID Holder only)' ).
    lo_by->item( key = c_tlic text = 'Trade License Number' ).

*   Nothing else until a type is chosen. The live screen asks one question first
*   for a reason: the answer decides what the rest of the form even is.
    IF lv_by IS INITIAL.
      lo_dlg->buttons( )->button( text = 'Close' press = mo_ctx->event( c_ev_cxl ) ).
      RETURN.
    ENDIF.

*   The number, labelled as whatever was chosen. One field, four labels - a
*   second input per type would be four model members holding one answer, and
*   then a question about which of them the backend should believe.
    lo_form->label( SWITCH string( lv_by
                     WHEN c_eid  THEN 'Emirates ID'
                     WHEN c_pass THEN 'Passport Number'
                     WHEN c_unif THEN 'Unified ID'
                     ELSE             'Trade License Number' ) ).
    lo_form->input( value = mo_ctx->bind( fld( 'IDNUM' ) ) ).

*   A trade licence is a company. It has no date of birth and no nationality, and
*   asking for them is how a form gets abandoned.
    IF lv_by <> c_tlic.
      lo_form->label( 'Date of Birth' ).
*     DDMMYYYY on screen, YYYYMMDD in the value. The MOI cross-check compares the
*     date sent against the date the BP holds as strings, so a display format
*     reaching the request would fail every comparison and read as a data
*     mismatch rather than a format one.
      lo_form->date_picker( value        = mo_ctx->bind( fld( 'DOB' ) )
                            displayformat = 'dd/MM/yyyy'
                            valueformat   = 'yyyyMMdd' ).

      lo_form->label( 'Nationality' ).
      DATA(lo_nat) = lo_form->combobox( selectedkey = mo_ctx->bind( fld( 'NAT' ) ) ).
      LOOP AT nationalities( ) INTO DATA(ls_n).
        lo_nat->item( key = ls_n-key text = ls_n-text ).
      ENDLOOP.
    ENDIF.

*   Passport type only for a passport. The domain has ten values and nine of them
*   are meaningless against any other ID.
    IF lv_by = c_pass.
      lo_form->label( 'Passport Type' ).
      DATA(lo_pt) = lo_form->combobox( selectedkey = mo_ctx->bind( fld( 'PPTYPE' ) ) ).
      LOOP AT doc_types( ) INTO DATA(ls_p).
        lo_pt->item( key = ls_p-key text = ls_p-text ).
      ENDLOOP.
    ENDIF.

    DATA(lo_btns) = lo_dlg->buttons( ).
    lo_btns->button( text  = 'Search'
                     type  = 'Emphasized'
                     icon  = 'sap-icon://search'
                     press = mo_ctx->event( c_ev_go ) ).
    lo_btns->button( text = 'Close' press = mo_ctx->event( c_ev_cxl ) ).
  ENDMETHOD.


  METHOD run_search.
    DATA ls_req TYPE zcl_rak_bp_search=>ty_req.

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
        ls_req-call_moi = abap_true.
      WHEN c_tlic.
        ls_req-trade_licence = lv_num.
      WHEN OTHERS.
*       Passport and Unified ID. See the note at the end of this file: the request
*       field these belong in is the one thing here I could not verify.
        ls_req-eid = lv_num.
    ENDCASE.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

    DATA(lv_err) = abap_false.
    LOOP AT ls_res-msg INTO DATA(ls_m).
      mo_ctx->add_msg( iv_type = COND #( WHEN ls_m-type = 'E' OR ls_m-type = 'A' THEN 'Error'
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
      RETURN.
    ENDIF.

*   PARTNER and TELEPHONE_NUMBER are the real names - the first proven by the DPC,
*   the second by the compiler. Name and email go through the candidate list.
    mo_ctx->set_val( iv_name = fld( 'PARTNER' ) iv_value = CONV string( ls_bp-partner ) ).
    mo_ctx->set_val( iv_name = fld( 'PHONE' )   iv_value = CONV string( ls_bp-telephone_number ) ).
    mo_ctx->set_val( iv_name = fld( 'NAME' )    iv_value = bp_name( ls_bp ) ).
    mo_ctx->set_val( iv_name = fld( 'EMAIL' )
                     iv_value = pick( is_bp    = ls_bp
                                      iv_names = 'SMTP_ADDR,EMAIL,E_MAIL,EMAILADDRESS,EMAIL_ADDRESS' ) ).
  ENDMETHOD.
ENDCLASS.
