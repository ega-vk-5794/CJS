class ZCL_C022_KHULA_CERTI_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_ATTACH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_AFTER_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SUBMIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  PRIVATE SECTION.
    CONSTANTS c_step_marr TYPE i VALUE 0.   " MARR  Marriage Contract        (seq 10)
    CONSTANTS c_step_divo TYPE i VALUE 1.   " DIVO  Divorce Details          (seq 20)
    CONSTANTS c_step_hist TYPE i VALUE 2.   " HIST  Marital Status & History (seq 30)
    CONSTANTS c_step_prty TYPE i VALUE 3.   " PRTY  Parties (grid + parties)  (seq 40)
    CONSTANTS c_step_docs TYPE i VALUE 4.   " DOCS  Request & Documents      (seq 50, last -> Submit)
*   THE PARTNER SEARCH IS THE ENGINE'S NOW - ZCL_RAK_BP_POPUP, instantiated
*   in BP_POPUP( ) below. It draws the dialog, runs ZCL_RAK_BP_SEARCH and
*   writes <SUBJECT>_PARTNER / _NAME / _PHONE / _EMAIL back onto the journey.
*
*   ABOUT 750 LINES CAME OUT WHEN THIS LANDED. What we had was the reference
*   implementation copied and improved; rounds 20 to 22 moved every one of
*   those improvements into the engine class - the required-field check that
*   reports every gap in one pass, the fifteen-digit Emirates ID test, the
*   restricted ID-type list, the label-above-control layout, the bold name
*   the Arabic CSS cannot flatten, the two events - so the copy had nothing
*   left that the original did not do, and in three places did it worse.
*
*   FOUR CONSTANTS WENT WITH IT. The three ID type codes are
*   ZCL_RAK_BP_POPUP=>C_EID / C_PASS / C_UNIF, and the popup's own event
*   names are its C_EV_* - both public, both the backend's interface rather
*   than ours to restate. The card's label width was a number in a method
*   this class no longer owns.
*
*   WHAT STAYED, AND WHY EACH ONE IS NOT THE POPUP'S: the three Add-BP open
*   events below, the button that carries them (BP_BUTTON_TEXT), the search
*   template (BP_SEARCH_OPTS), and the future-date-of-birth refusal
*   (BP_DOB_FUTURE) - see that method for why it is ours and why it needs no
*   subclass.
    CONSTANTS c_evt_bp_divorcee TYPE string VALUE 'BP_OPEN_DIVORCEE'.
    CONSTANTS c_evt_bp_witness1 TYPE string VALUE 'BP_OPEN_WITNESS1'.
    CONSTANTS c_evt_bp_witness2 TYPE string VALUE 'BP_OPEN_WITNESS2'.
    CONSTANTS c_default_service TYPE string VALUE 'AS3'.
    CONSTANTS c_att_key     TYPE comt_product_id VALUE 'AD01'. " doc-type DDLB key

    METHODS get_otr_text_for_alias
      IMPORTING iv_alias       TYPE sotr_alias
      RETURNING VALUE(rv_text) TYPE string.
    METHODS get_otr_text_by_alias
      IMPORTING iv_alias       TYPE sotr_alias
      RETURNING VALUE(rv_text) TYPE string.

    METHODS options_from_domain
      IMPORTING iv_domain TYPE ddobjname
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

    " The two partner functions PERS_INFO's fixed rows carry, in the logon
    " language. No domain behind them: the WD hardcoded the pair too. Used both
    " as ZZAFLD0000V2's value help - which is what RENDER_GRID resolves its
    " read-only cells through - and to name a row in a per-row message.
    METHODS party_type_opts
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

    " A count as the backend should receive it: trimmed, and with leading zeros
    " dropped so a narrow column cannot keep the wrong character. '09' -> '9',
    " '00' -> '0', anything non-numeric returned untouched for the caller's own
    " check to deal with.
    METHODS digits_only
      IMPORTING iv_value TYPE string
      RETURNING VALUE(rv) TYPE string.

    " One error row, naming the field it is about. VALIDATE_STEP calls
    " SET_FIELD_STATE( ) for every returned row whose FIELD is filled, so our
    " own failures get the red border and tooltip the engine's built-in checks
    " already give themselves. Exists only to keep each call site to one line.
    METHODS field_error
      IMPORTING iv_field  TYPE string
                iv_text   TYPE string
      RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_msg.

    METHODS t100_text
      IMPORTING iv_id          TYPE symsgid
                iv_no          TYPE symsgno
                iv_v1          TYPE symsgv DEFAULT space
                iv_v2          TYPE symsgv DEFAULT space
                iv_v3          TYPE symsgv DEFAULT space
                iv_v4          TYPE symsgv DEFAULT space
      RETURNING VALUE(rv_text) TYPE string.

    METHODS date_display
      IMPORTING iv_int    TYPE d
      RETURNING VALUE(rv) TYPE string.

    METHODS date_order_msg
      IMPORTING iv_a_en   TYPE string
                iv_a_ar   TYPE string
                iv_a_val  TYPE d
                iv_before TYPE abap_bool
                iv_b_en   TYPE string
                iv_b_ar   TYPE string
                iv_b_val  TYPE d
      RETURNING VALUE(rv) TYPE string.

    " Origin: VIEW_MAIN->E_GET_HELP_URL. Maps SERVICE_TYPE to a help code
    METHODS refresh_help_url
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    " Origin: COMPONENTCONTROLLER->GET_PARTNER_FUNCTIONS. Stamp the partner
    METHODS set_partner_functions
      CHANGING cs_partners TYPE zst_ega_court_service_partners.
    " closes the gated cells of THAT row (per-row state lives in the <COL>_EN
    METHODS react_pers_info
      IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                iv_field TYPE string.
    " ---- partner search: the engine's popup, configured from here --------
    " ONE FACTORY, CALLED FROM BOTH HOOKS. The popup is constructed twice per
    " round trip - once to render and once to handle - and the two
    " constructions must agree: a form drawn with three ID types and validated
    " as though it had four is worse than either behaviour on its own.
    METHODS bp_popup
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                iv_subject TYPE string
      RETURNING VALUE(ro)  TYPE REF TO zcl_rak_bp_popup.
    " Refuses a date of birth in the future and says so. ABAP_TRUE means a
    " message was added and the caller must NOT delegate to the popup.
    METHODS bp_dob_future
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                iv_subject TYPE string
      RETURNING VALUE(rv)  TYPE abap_bool.
    " The ZCL_RAK_BP_SEARCH request template: everything that is NOT one of the
    " five identity fields the citizen types.
    METHODS bp_search_opts
      RETURNING VALUE(rs) TYPE zcl_rak_bp_search=>ty_req.
    METHODS bp_button_text
      IMPORTING iv_partner     TYPE string
                iv_role_en     TYPE string
                iv_role_ar     TYPE string
      RETURNING VALUE(rv_text) TYPE string.
    " An external date string as internal YYYYMMDD; empty when the input is
    " empty OR invalid, so a caller tells the two apart by also testing the
    " raw value. Delegates to the ENGINE's parser - see the implementation for
    " why the dialog user's date format has no business deciding what a
    " citizen typed into a picker.
    METHODS conv_date_internal
      IMPORTING iv_ext        TYPE string
      RETURNING VALUE(rv_int) TYPE d.
ENDCLASS.


CLASS ZCL_C022_KHULA_CERTI_LOGIC IMPLEMENTATION.


  METHOD BP_BUTTON_TEXT.
*&---------------------------------------------------------------------*
*& bp_button_text — "Add <role>" until a partner is picked, then
*& "Change <role>". Arabic when sy-langu = 'A' (the engine renders the
*& screen in the logon language; code-drawn captions must follow it).
*&---------------------------------------------------------------------*
    IF sy-langu = 'A'.
      rv_text = COND string( WHEN iv_partner IS NOT INITIAL
      THEN |تغيير { iv_role_ar }|
      ELSE |اضافة { iv_role_ar }| ).
    ELSE.
      rv_text = COND string( WHEN iv_partner IS NOT INITIAL
      THEN |CHANGE { iv_role_en }|
      ELSE |ADD { iv_role_en }| ).
    ENDIF.
  ENDMETHOD.


  METHOD BP_POPUP.
*&---------------------------------------------------------------------*
*& bp_popup — the engine's partner search, configured for this service.
*&
*& ONE FACTORY, AND BOTH HOOKS CALL IT. ZCL_RAK_BP_POPUP is constructed
*& twice per round trip - once in ON_RENDER_POPUP to draw and once in
*& ON_POPUP_EVENT to handle - and the engine's own how-to warns that the
*& two constructions must agree. They cannot disagree if there is one
*& place that builds it.
*&
*& IT_TYPES - THREE, NOT FOUR. The engine offers Trade Licence as well,
*& and a trade licence identifies a COMPANY. Every party this service
*& collects is a natural person: a divorcee and two witnesses. The citizen
*& who picked it would get "No data found", which is the wrong answer to a
*& question they should not have been asked.
*&
*& IV_STRICT - DATE OF BIRTH AND NATIONALITY REQUIRED, not merely asked
*& for. They are not search narrowing: VALIDATE( )'s MOI cross-check
*& compares them against what the BP holds, and that check runs on all
*& three identity branches. Left off, the form collects the verification,
*& sends it, and has nothing to compare - a partner nobody verified.
*&
*& IT_DETAIL - NATV, AND NOTHING ELSE. The engine's blank default is name,
*& partner number, mobile and email; ours has always carried nationality
*& beside them, so one entry restores exactly the card AS3 shows today.
*&
*& NATV, NOT NAT, AND THE DIFFERENCE IS REAL. NAT is the QUESTION - bound
*& to the search form's select and sent as LS_REQ-NATIONALITY - and NATV is
*& the ANSWER, written from LS_BP-NATIONALITY and resolved to its T005T
*& description. That split is R22-1: before it the card drew NAT and
*& therefore echoed the citizen's own input back at them, as the country
*& CODE, and read blank on any journey that did not ask the question.
*&
*& PASSING 'NAT' ALSO WORKS AND IS THE WRONG THING TO RELY ON. WANTED( )
*& carries an explicit branch so a journey configured before R22-1 keeps
*& its row - a compatibility shim, named as one in its own comment. Ours
*& was written after the fix and should name the field it actually wants.
*& The full legacy card is IT_DETAIL = ( '*' ) - twenty-five fields across
*& General, Contact and Address - and it is not what this service should
*& show: the citizen searched for the OTHER party, and their ID number,
*& passport, date of birth and home address are not this form's business.
*& That was R21-1 and the engine made our four the default for everyone.
*&
*& IS_SEARCH - our own template, unchanged. See BP_SEARCH_OPTS( ): it is
*& the E10/E20 expiry waiver, and the popup takes everything that is not
*& an identity field from it verbatim.
*&
*& NOT PASSED: IV_ASK_DOB / IV_ASK_NAT, which suppress those two fields
*& entirely. Both default true and both must stay true here - they are the
*& verification IV_STRICT then requires, and turning one off would turn off
*& its check with it.
*&---------------------------------------------------------------------*
    ro = NEW zcl_rak_bp_popup(
      io_ctx     = io_ctx
      iv_subject = iv_subject
      iv_title   = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-bp_find
                                      iv_default = `Find Business Partner` )
      is_search  = bp_search_opts( )
      it_types   = VALUE #( ( zcl_rak_bp_popup=>c_eid )
                            ( zcl_rak_bp_popup=>c_pass )
                            ( zcl_rak_bp_popup=>c_unif ) )
      iv_strict  = abap_true
      it_detail  = VALUE #( ( `NATV` ) ) ).
  ENDMETHOD.


  METHOD BP_DOB_FUTURE.
*&---------------------------------------------------------------------*
*& bp_dob_future — a date of birth in the future is refused here, before
*& the popup is asked to do anything.
*&
*& OURS, AND THE ENGINE SAYS SO TWICE. NORM_DOB( ) normalises and
*& deliberately does not judge a human being's birthday - "a caller
*& wanting to know whether the result is a plausible date of birth (not in
*& the future, not in 1823) owns that question" - and section 7 of the
*& partner-search how-to repeats it. The boundary is right: the class
*& makes a value sendable, the service decides whether it is sensible.
*&
*& AND IT NEEDS NO SUBCLASS, which is where round 20 left it and round 21
*& corrected. ON_POPUP_EVENT( ) is OUR method, C_EV_RUN is public and the
*& field is <SUBJECT>_DOB, so the guard runs before we delegate. Nothing
*& is inherited, and nothing here breaks when the engine next restructures
*& that class.
*&
*& THE WORDING IS THE WD'S OWN. ZEGA_BP_V_MAIN_DOB_MSG belongs to
*& ZWDC_EGA_EBP_SRCH_CREATE, whose VALIDATE_SCREEN has this check and
*& AS3's own WD does not - so the check is imported rather than migrated,
*& and following the OTR keeps the sentence single-sourced with the screen
*& a citizen may already know it from. SOTR_GET_TEXT_KEY swallows
*& NO_ENTRY_FOUND, so the literal fallback is the documented contract and
*& not defensive padding.
*&
*& AN UNPARSEABLE DATE IS NOT OURS TO REPORT. TO_DATS( ) returns empty for
*& anything it cannot read, and SEARCH( ) already refuses exactly that, in
*& both languages, at the choke point every popup goes through. Reporting
*& it here as well would draw two messages for one bad date - the mistake
*& the AS3 date guard was removed to avoid in round 18.
*&
*& COMPARED AS STRINGS ON PURPOSE. TO_DATS( ) returns YYYYMMDD in a string
*& and CONV string( sy-datum ) is the same eight characters. Note that
*& |{ sy-datum }| would NOT do: a string template formats a date in the
*& USER's format, giving 14.09.2026 and a nonsense comparison.
*&---------------------------------------------------------------------*
    DATA(lv_raw) = io_ctx->get_val( |{ to_upper( iv_subject ) }_DOB| ).
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_dob) = zcl_rak_journey_util=>to_dats( lv_raw ).
    IF lv_dob IS INITIAL OR lv_dob <= CONV string( sy-datum ).
      RETURN.
    ENDIF.

    DATA(lv_txt) = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZEGA_BP_V_MAIN_DOB_MSG' ).
    IF lv_txt IS INITIAL.
      lv_txt = zcl_rak_text=>pick( iv_base = `Date of Birth can not be a future date`
                                   iv_ar   = |لا يمكن أن يكون تاريخ الميلاد تاريخاً مستقبلياً| ).
    ENDIF.
    io_ctx->add_msg( iv_type = 'Error' iv_text = lv_txt ).
    rv = abap_true.
  ENDMETHOD.


  METHOD BP_SEARCH_OPTS.
*&---------------------------------------------------------------------*
*& BP_SEARCH_OPTS — the request template handed to ZCL_RAK_BP_SEARCH.
*& Only the non-identity switches belong here; bp_run_search fills EID /
*& TRADE_LICENCE / IDTYPE / DOB / NATIONALITY from what the citizen typed.
*&---------------------------------------------------------------------*
*   E10 / E20 ARE THE NON-PRODUCTION SYSTEMS, and only they get a waiver.
*   PRODUCTION SETS NEITHER SWITCH, so it keeps the full checks - an expired
*   Emirates ID and a MOI mismatch are both findings there, as they must be.
*
*   SKIP_EID_EXPIRY = ABAP_TRUE on E10 / E20. Their BP data is test data and
*   its Emirates IDs are long expired, so that finding is an artefact of the
*   data rather than a fact about the citizen - and because it is an error, it
*   would block every search on those systems. It suppresses the expiry FINDING
*   only: MOI is still called and the BP still updated from it, which is what
*   SKIP_EID_EXPIRY means and NO_MOI_CALL does not.
*
*   SKIP_MOI_MISMATCH = ABAP_FALSE, and this is the one that changed. It used to
*   be ABAP_TRUE here on the same test-data reasoning, and that reasoning does
*   not survive: the date-of-birth and nationality cross-check is the only thing
*   standing between a citizen's typing and a partner they have not been
*   verified against, engine round 10 was spent getting it to reach the passport
*   and unified branches at all, and waiving it on the two systems this journey
*   is TESTED on would have meant never once exercising it. A mismatch on test
*   data is a test-data problem to fix, not a verdict to switch off.
*
*   Assigning ABAP_FALSE is redundant against an initial RS and is written
*   anyway: it is the one value here that is a decision rather than a default,
*   and a branch that set only SKIP_EID_EXPIRY would not say it had been made.
*
*   SKIP_TL_EXPIRY is not set: the trade-licence branch is gone from this popup,
*   so there is no licence whose expiry could be judged. Leaving it would have
*   read as though this journey still searched for companies.
    IF sy-sysid = 'E10' OR sy-sysid = 'E20'.
      rs-skip_moi_mismatch = abap_false.
      rs-skip_eid_expiry   = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD CONV_DATE_INTERNAL.
*&---------------------------------------------------------------------*
*& conv_date_internal — date string -> SAP internal YYYYMMDD; empty on
*& blank or invalid input (so callers treat blank and invalid distinctly by
*& also testing the raw value). Contract unchanged; the body is now one
*& delegation.
*&
*& WHY IT NO LONGER PARSES ANYTHING ITSELF. It used to handle ISO
*& explicitly, pass an already-internal YYYYMMDD through, and fall back to
*& CONVERT_DATE_TO_INTERNAL for everything else - and that FM answers in the
*& DIALOG USER's date format. On a citizen-facing journey that user is
*& whichever ICF service user happens to be running the request, which is
*& not an input this service controls. All seven fields feeding this method
*& are FTYPE 'DATE', so each renders a sap.m.DatePicker, and an unparsed
*& DatePicker pushes the citizen's RAW TEXT into the bound value. So on a
*& month-first service user, a citizen typing 08/19/1987 over the picker had
*& 19 AUGUST accepted as valid.
*&
*& AND THIS ONE PERSISTS, which is what makes it worse than the same shape
*& in BP_DOB( ). That one misdirected a search: wrong or empty result, the
*& citizen sees it and retries. This one is posted. Seven of the fifteen
*& call sites write straight into the backend structures - ZZAFLD00008K and
*& 8N on the header, ZZAFLD0000UB..UF on the extension - so a date nobody
*& entered is written to a divorce record, and the other eight sites hand it
*& to the date-ordering checks, which then judge that same phantom date. It
*& was found by the engine team searching their tree for the shape our
*& BP_DOB( ) finding described; their copy of this class still has it.
*&
*& TO_DATS( ) reads a fixed set instead - eight digits, ISO yyyy-mm-dd, and
*& the day-first forms dd.mm.yyyy / dd/mm/yyyy / dd-mm-yyyy, telling ISO and
*& day-first apart by separator position - range-checks month 1-12 and day
*& 1-31, and returns BLANK for anything it cannot read unambiguously,
*& including month-first and partial dates. Blank is already the "invalid"
*& signal every caller here tests for, so no call site changes. It never
*& assigns to a TYPE D field either, so the CX_SY_CONVERSION_NO_DATE this
*& method used to be able to raise on its own ISO branch is gone with it.
*&
*& The IS NOT INITIAL test is deliberate rather than decorative: TO_DATS( )
*& returns a STRING and RV_INT is TYPE D, whose initial value is '00000000'.
*& Guarding the assignment says "leave the type's own initial value" without
*& depending on how a blank character source converts to a date.
*&---------------------------------------------------------------------*
    DATA(lv_dats) = zcl_rak_journey_util=>to_dats( iv_ext ).
    IF lv_dats IS NOT INITIAL.
      rv_int = lv_dats.
    ENDIF.
  ENDMETHOD.


  METHOD GET_OTR_TEXT_BY_ALIAS.
*&---------------------------------------------------------------------*
*& get_otr_text_by_alias — same, honouring sy-langu (kept from source).
*&---------------------------------------------------------------------*
    DATA lv_text TYPE sotr_txt.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = iv_alias
        langu           = sy-langu
      IMPORTING
        e_text          = lv_text
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0.
      rv_text = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD GET_OTR_TEXT_FOR_ALIAS.
*&---------------------------------------------------------------------*
*& get_otr_text_for_alias — resolve a message OTR alias (kept from source).
*&---------------------------------------------------------------------*
    DATA lv_text TYPE sotr_txt.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = iv_alias
      IMPORTING
        e_text          = lv_text
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0.
      rv_text = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD DATE_DISPLAY.
*&---------------------------------------------------------------------*
*& date_display — internal YYYYMMDD -> DD.MM.YYYY for a message.
*& io_ctx hands DATE fields over as ISO 'YYYY-MM-DD' and CONV_DATE_INTERNAL
*& turns that into YYYYMMDD; neither is what a citizen recognises mid-sentence.
*& One place to change if the portal ever shows a different format.
*&---------------------------------------------------------------------*
    IF iv_int IS INITIAL.
      RETURN.
    ENDIF.
    rv = |{ iv_int+6(2) }.{ iv_int+4(2) }.{ iv_int(4) }|.
  ENDMETHOD.


  METHOD DATE_ORDER_MSG.
*&---------------------------------------------------------------------*
*& date_order_msg — "<date A> cannot be after/before <date B>".
*& The WD raises ONE generic OTR text per date for every ordering rule that
*& date takes part in ("Please check date value for last divorce date"), so the
*& citizen cannot tell which comparison failed. These messages name both dates,
*& the direction, AND each date's value - five of the six comparisons read a date
*& owned by an earlier step, so without the values the citizen has to walk back
*& through the wizard to see what they entered. Deliberately not the OTR wording:
*& the field NAMES inside them are the OTR labels, but the sentence is ours.
*&---------------------------------------------------------------------*
    DATA(lv_a) = |{ iv_a_ar } ({ date_display( iv_a_val ) })|.
    DATA(lv_b) = |{ iv_b_ar } ({ date_display( iv_b_val ) })|.
    IF sy-langu = 'A'.
      rv = COND string( WHEN iv_before = abap_true
                        THEN |لا يمكن أن يكون { lv_a } قبل { lv_b }|
                        ELSE |لا يمكن أن يكون { lv_a } بعد { lv_b }| ).
    ELSE.
      lv_a = |{ iv_a_en } ({ date_display( iv_a_val ) })|.
      lv_b = |{ iv_b_en } ({ date_display( iv_b_val ) })|.
      rv = COND string( WHEN iv_before = abap_true
                        THEN |{ lv_a } cannot be before { lv_b }|
                        ELSE |{ lv_a } cannot be after { lv_b }| ).
    ENDIF.
  ENDMETHOD.


  METHOD T100_TEXT.
*&---------------------------------------------------------------------*
*& t100_text — a T100 message's text in the logon language.
*& The WD's mandatory messages are T100, not OTR: CHECK_INITIAL_FIELDS
*& renders whatever cl_wd_dynamic_tool returns through FORMAT_MESSAGE, and
*& substitutes its own id/number for one attribute. Reading them the same way
*& keeps the wording single-sourced with the legacy screen.
*& Returns BLANK when the message does not exist — FORMAT_MESSAGE swallows
*& everything via OTHERS = 0 — so every caller must have a fallback, exactly
*& as with get_otr_text_for_alias.
*&---------------------------------------------------------------------*
    DATA lv_text TYPE string.
    CALL FUNCTION 'FORMAT_MESSAGE'
      EXPORTING
        id     = iv_id
        lang   = sy-langu
        no     = iv_no
        v1     = iv_v1
        v2     = iv_v2
        v3     = iv_v3
        v4     = iv_v4
      IMPORTING
        msg    = lv_text
      EXCEPTIONS
        OTHERS = 0.
    rv_text = lv_text.
  ENDMETHOD.


  METHOD field_error.
    rs = VALUE #( type = 'Error' text = iv_text field = iv_field ).
  ENDMETHOD.


  METHOD digits_only.
    rv = condense( iv_value ).
    IF rv IS INITIAL OR rv CN '0123456789'.
      RETURN.
    ENDIF.
    SHIFT rv LEFT DELETING LEADING '0'.
    IF rv IS INITIAL.
      rv = '0'.
    ENDIF.
  ENDMETHOD.


  METHOD party_type_opts.
    IF sy-langu = 'A'.
      rt = VALUE #( ( key = `1` text = |المطلق| )
                    ( key = `2` text = |المطلقة| ) ).
    ELSE.
      rt = VALUE #( ( key = `1` text = |Divorcer| )
                    ( key = `2` text = |Divorcee| ) ).
    ENDIF.
  ENDMETHOD.


  METHOD OPTIONS_FROM_DOMAIN.
*&=====================================================================*
*& PRIVATE HELPERS
*&=====================================================================*
*&---------------------------------------------------------------------*
*& options_from_domain — DDIC domain fixed values -> tt_option (key/text)
*& Replaces the per-dropdown DDUT_DOMVALUES_GET blocks (fill_dropdown_*).
*&---------------------------------------------------------------------*
    DATA lt_dd07v TYPE TABLE OF dd07v.
    CALL FUNCTION 'DDUT_DOMVALUES_GET'
      EXPORTING
        name          = iv_domain
        langu         = sy-langu
      TABLES
        dd07v_tab     = lt_dd07v
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.
    CHECK sy-subrc = 0.
    LOOP AT lt_dd07v INTO DATA(ls).
      APPEND VALUE #( key = ls-domvalue_l text = ls-ddtext ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD REACT_PERS_INFO.
*&---------------------------------------------------------------------*
*& REACT_PERS_INFO — per-row reactive behaviour of the personal-information
*& grid, as in the WebDynpro:
*&   Residence status = '01' (Citizen)  -> Village number editable
*&   Job status       = '01' (Employed) -> Main profession / Profession /
*&                                         Employer / Employer Emirate editable
*& A cell template is shared by every row, so the state cannot be rendered per
*& row — it lives in the hidden boolean <COL>_EN columns, which the renderer
*& binds to 'editable'.
*& The gates are recomputed for EVERY row from that row's own trigger values,
*& so the handler does not depend on the row index in the event name (the grid
*& has two fixed rows, so the cost is nil and the result is identical).
*& Closing a gate ALWAYS clears the target: a disabled cell keeps whatever was
*& typed before and would otherwise still post to the backend.
*&---------------------------------------------------------------------*
    DATA(ls_g) = io_ctx->get_grid_data( 'PERS_INFO' ).
    IF ls_g-rows IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_tt)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TT' ] ).
    DATA(lv_tw)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TW' ] ).
    DATA(lv_tu)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TU' ] ).
    DATA(lv_tu_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TU_EN' ] ).
    DATA(lv_tx)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TX' ] ).
    DATA(lv_tx_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TX_EN' ] ).
    DATA(lv_u2)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000U2' ] ).
    DATA(lv_u2_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000U2_EN' ] ).
    DATA(lv_ty)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TY' ] ).
    DATA(lv_ty_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TY_EN' ] ).
    DATA(lv_tz)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TZ' ] ).
    DATA(lv_tz_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TZ_EN' ] ).

    DATA lv_cells   TYPE i.
    DATA lv_open_tu TYPE abap_bool.
    DATA lv_open_em TYPE abap_bool.
    DATA lv_flag    TYPE string.
    FIELD-SYMBOLS <row> TYPE zif_rak_journey=>tt_string.

    LOOP AT ls_g-rows ASSIGNING <row>.
      lv_cells = lines( <row> ).

      " ---- Residence status = Citizen -> village number ----------------
      IF lv_tt > 0 AND lv_tt <= lv_cells AND lv_tu_en > 0 AND lv_tu_en <= lv_cells.
        lv_open_tu = xsdbool( <row>[ lv_tt ] = '01' ).
        <row>[ lv_tu_en ] = COND string( WHEN lv_open_tu = abap_true THEN 'X' ELSE '' ).
        IF lv_open_tu = abap_false AND lv_tu > 0 AND lv_tu <= lv_cells.
          CLEAR <row>[ lv_tu ].
        ENDIF.
      ENDIF.

      " ---- Job status = Employed -> the employment block ---------------
      IF lv_tw > 0 AND lv_tw <= lv_cells.
        lv_open_em = xsdbool( <row>[ lv_tw ] = '01' ).
        lv_flag    = COND string( WHEN lv_open_em = abap_true THEN 'X' ELSE '' ).
        IF lv_tx_en > 0 AND lv_tx_en <= lv_cells.
          <row>[ lv_tx_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_tx > 0 AND lv_tx <= lv_cells.
            CLEAR <row>[ lv_tx ].
          ENDIF.
        ENDIF.
        IF lv_u2_en > 0 AND lv_u2_en <= lv_cells.
          <row>[ lv_u2_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_u2 > 0 AND lv_u2 <= lv_cells.
            CLEAR <row>[ lv_u2 ].
          ENDIF.
        ENDIF.
        IF lv_ty_en > 0 AND lv_ty_en <= lv_cells.
          <row>[ lv_ty_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_ty > 0 AND lv_ty <= lv_cells.
            CLEAR <row>[ lv_ty ].
          ENDIF.
        ENDIF.
        IF lv_tz_en > 0 AND lv_tz_en <= lv_cells.
          <row>[ lv_tz_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_tz > 0 AND lv_tz <= lv_cells.
            CLEAR <row>[ lv_tz ].
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    io_ctx->set_grid_data( iv_field = 'PERS_INFO' is_data = ls_g ).
  ENDMETHOD.


  METHOD REFRESH_HELP_URL.
*&---------------------------------------------------------------------*
*& refresh_help_url — Origin: VIEW_MAIN->SELECTED_SERVICE_PROCESS (help
*& branch) + E_GET_HELP_URL. Resolves the help URL via
*& ZFM_EGA_GET_ESERVICE_HELP_URL and stores it in HELP_URL.
*& Single-service class: AS3 always maps to help code 'YSR2'.
*&---------------------------------------------------------------------*
    DATA lv_url TYPE zde_ega_wdp_url_help.
    DATA lv_wdp_id TYPE zde_ega_wdp_id_url VALUE 'YSR2'.   " AS3 help code
    CALL FUNCTION 'ZFM_EGA_GET_ESERVICE_HELP_URL'
      EXPORTING
        iv_wdp_id   = lv_wdp_id
        iv_language = sy-langu       " language-aware (FM default is 'A')
      IMPORTING
        ev_help_url = lv_url.
    io_ctx->set_val( iv_name = 'HELP_URL' iv_value = |{ lv_url }| ).
  ENDMETHOD.


  METHOD SET_PARTNER_FUNCTIONS.
*&---------------------------------------------------------------------*
*& set_partner_functions — Origin: COMPONENTCONTROLLER->GET_PARTNER_FUNCTIONS.
*& For every party BP that is filled, stamp its partner-function code onto
*& the matching _FT component. Only the AS3-relevant roles are populated;
*& the others stay initial (harmless if the component is absent for a role).
*&---------------------------------------------------------------------*
    IF cs_partners-husband_bp      IS NOT INITIAL. cs_partners-husband_ft      = 'Y0000447'. ENDIF.
    IF cs_partners-wife_bp         IS NOT INITIAL. cs_partners-wife_ft         = 'Y0000407'. ENDIF.
    IF cs_partners-marriage_reg_bp IS NOT INITIAL. cs_partners-marriage_reg_ft = 'Y0000410'. ENDIF.
    IF cs_partners-witness1_bp     IS NOT INITIAL. cs_partners-witness1_ft     = 'Y0000110'. ENDIF.
    IF cs_partners-witness2_bp     IS NOT INITIAL. cs_partners-witness2_ft     = 'Y0000110'. ENDIF.
    IF cs_partners-divorcee_bp     IS NOT INITIAL. cs_partners-divorcee_ft     = 'Y0000420'. ENDIF.
    IF cs_partners-divorcer_bp     IS NOT INITIAL. cs_partners-divorcer_ft     = 'Y0000450'. ENDIF.
    IF cs_partners-attester_bp     IS NOT INITIAL. cs_partners-attester_ft     = 'Y0000446'. ENDIF.
    IF cs_partners-sponsor_bp      IS NOT INITIAL. cs_partners-sponsor_ft      = 'Y0000200'. ENDIF.
    IF cs_partners-guardian_bp     IS NOT INITIAL. cs_partners-guardian_ft     = 'Y0000442'. ENDIF.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_ATTACH.
*&---------------------------------------------------------------------*
*& ON_ATTACH — fires after a file is staged for iv_field (the upload
*& FIELD NAME). The engine has already done the size check and stored the
*& file, so the only remaining check (Origin: CHECK_ENTRIES) is the
*& allowed-extension check against the system master list.
*& The staged file is read via io_ctx->get_attachment_files( ), whose
*& IDENTIFIER1 column carries the upload field name — so the file(s) for
*& this field are the rows where identifier1 = iv_field.
*&---------------------------------------------------------------------*
    CHECK iv_field IS NOT INITIAL.

    DATA lt_allowed TYPE ztt_ega_file_extensions.
    DATA lt_ext_ret TYPE bapiret2_t.
    CALL FUNCTION 'ZFM_EGA_GET_FILE_EXT_WD_UPLOAD'
      IMPORTING
        et_file_extensions = lt_allowed
        et_return          = lt_ext_ret.

    DATA ls_file    TYPE /qnv/sbuild_attachments_st.
    DATA lv_ext     TYPE c LENGTH 40.
    DATA lv_ext_msg TYPE string.
    LOOP AT io_ctx->get_attachment_files( ) INTO ls_file
    WHERE identifier1 = iv_field.
      CLEAR lv_ext.
      CALL FUNCTION 'TRINT_FILE_GET_EXTENSION'
        EXPORTING
          filename  = ls_file-file_name
          uppercase = 'X'
        IMPORTING
          extension = lv_ext.
      IF NOT line_exists( lt_allowed[ file_extension = lv_ext ] ).
        MESSAGE ID 'ZMSG_EGA_CM' TYPE 'E' NUMBER '111' WITH lv_ext INTO lv_ext_msg.
        io_ctx->add_msg( iv_type = 'Error' iv_text = lv_ext_msg ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE.
*&---------------------------------------------------------------------*
*& ON_CHANGE — folds the WD's field-change handlers. Two kinds:
*&  (a) clear-on-change: when a driver dropdown changes, blank the now-
*&      irrelevant dependent fields (Origin: SET_PREV_DIV / SET_MARR_CONS /
*&      SET_GRANT / CHECK_NO_PREV_DIV). EDITABLE/READONLY/REQUIRE toggles for
*&      the same drivers are declarative rules (ZRAK_T_JNY_RULE); only the
*&      value-clearing lives here, as the engine drives clearing via on_change.
*&  (b) value derivations: pin SERVICE_TYPE; resolve typed party BPs to names.
*&  (c) reactive PERS_INFO grid: a grid change arrives as
*&      'PERS_INFO.<COL>#<ROW>' and is routed to react_pers_info( ).
*&---------------------------------------------------------------------*

    DATA(lv_ev) = to_upper( iv_field ).
    IF lv_ev CS 'PERS_INFO.ZZAFLD0000TT'
    OR lv_ev CS 'PERS_INFO.ZZAFLD0000TW'.
      react_pers_info( io_ctx = io_ctx iv_field = iv_field ).
      RETURN.
    ENDIF.

    CASE iv_field.
      WHEN 'EARLIER_MARRIAGES'.        " Earlier marriages
        "   Origin: ONACTIONSET_PREV_DIV — clears both dependents on any change.
        io_ctx->set_val( iv_name = 'PREV_DIVORCES_COUNT' iv_value = space ). " no. previous divorces
        io_ctx->set_val( iv_name = 'FIRST_MARR_CTR_DT' iv_value = space ). " first marriage contract date

      WHEN 'CASE_UPON_DIVORCE'.        " Divorced case upon divorce
        "   Origin: ONACTIONSET_MARR_CONS — clears both dependents on any change.
        io_ctx->set_val( iv_name = 'MARR_CONSUMMATED' iv_value = space ). " marriage consummated
        io_ctx->set_val( iv_name = 'ISOLATION' iv_value = space ). " isolation

      WHEN 'MARR_GRANT_RECEIVED'.        " Was a marriage grant received
        "   Origin: ONACTIONSET_GRANT — clears grant side on any change.
        io_ctx->set_val( iv_name = 'GRANT_SIDE' iv_value = space ). " grant side

      WHEN 'PREV_DIVORCES_COUNT'.        " No. of previous divorces
        "   Origin: CHECK_NO_PREV_DIV — clear last divorce date only when there
        " is no prior divorce (UM <= 0). UM arrives as a STRING, so it must not
        DATA(lv_prev_div) = condense( io_ctx->get_val( 'PREV_DIVORCES_COUNT' ) ).
        IF lv_prev_div IS INITIAL
        OR ( lv_prev_div CO '0123456789' AND lv_prev_div = 0 ).
          io_ctx->set_val( iv_name = 'LAST_DIV_DATE' iv_value = space ). " last divorce date
        ENDIF.

      WHEN 'IF_SERVICE_TYPE'.
        "   Origin: ONACTIONSELECT_SERVICE -> SELECTED_SERVICE_PROCESS.
        io_ctx->set_val( iv_name = 'SERVICE_TYPE' iv_value = c_default_service ).
        refresh_help_url( io_ctx ).

      WHEN OTHERS.
        " onactiononselect_non_eid / onactionrb_payer1 / onactionrb_payer2
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE.
*&---------------------------------------------------------------------*
*& ON_CUSTOM_VALIDATE — runs per step (and for every step on submit).
*& CONTRACT: RETURN the messages in rt (tt_msg). The engine appends rt to
*& the step's message set and BLOCKS the step when any row is type 'Error'.
*& Do NOT use io_ctx->add_msg here — that shows a strip but does not block.
*& Folds 15 methods; is_valid_* / get_fld_list / modify_val_witness_list
*& were aggregation helpers whose checks are inlined under the step guard.
*&---------------------------------------------------------------------*
    rt = super->zif_rak_journey_logic~on_custom_validate(
    io_ctx = io_ctx iv_step = iv_step ).

*   NO DATE-FORMAT GUARD HERE ANY MORE, AND THAT IS THE POINT OF R18-4.
*
*   There was one: BAD_DATES( ) refused any date field TO_DATS( ) could not
*   read, because VALIDATE_STEP's DATE branch ran only when MIN_VAL or
*   MAX_VAL was set and skipped an unparseable value inside it - so 37122010
*   passed every check and reached the backend as BLANK.
*
*   THE ENGINE ASKS THE QUESTION ITSELF NOW, on every DATE field whether or
*   not it carries a range, with a DATE_BAD catalogue message a field's
*   FORMAT: clause can override. TO_DATS( ) also learned the calendar in the
*   same round, so 31.02.2026 is refused as well - which our guard never
*   caught, because it only asked TO_DATS( ) and TO_DATS( ) checked the shape
*   rather than the days in the month.
*
*   KEEPING IT WOULD HAVE BEEN THE DEFECT. Both checks append, so one bad
*   date would have drawn TWO error lines - the thing the guard's own comment
*   warned against.
    DATA(lv_today) = |{ sy-datum }|.
    CASE iv_step.
      WHEN c_step_marr.
        "   MARR — Marriage Contract. Origin: VALIDATE_DATES_FILE_SIZE — the
        "   marriage-contract date (8K) must not be in the future. (AS3 has no
        DATA(lv_contr_dat) = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ).
        IF lv_contr_dat IS NOT INITIAL AND lv_contr_dat > lv_today.
          APPEND field_error( iv_field = 'MARR_CONTRACT_DATE'
          iv_text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_COURT_ATT_VALIDATE_FUTURE_DATE' ) ) TO rt.
        ENDIF.

      WHEN c_step_divo.
        "   DIVO — Divorce Details. Only the contract-vs-divorce ordering lives
        " here: DIVO is the last step that owns either of those two dates. The
        " two comparisons involving FIRST_MARR_CTR_DT and LAST_DIV_DATE moved to
        " HIST when those fields did - validate on the step that owns the field,
        " or the check runs before the citizen can have entered a value.
        DATA(lv_div_dat)  = conv_date_internal( io_ctx->get_val( 'DIV_KHULA_DATE' ) ). " Date of divorce or khula
        DATA(lv_marr_dat) = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ). " Marriage contract date
        IF lv_marr_dat IS NOT INITIAL AND lv_div_dat IS NOT INITIAL AND lv_marr_dat > lv_div_dat.
          "   Was the generic OTR text ZEGA_SRC_V_MAIN_LAST_MARR_CONTR_DATE,
          " "Please check date value for last marriage contract" - which names
          " neither field in the comparison. The contract date is owned by MARR,
          " a step back from here, so its value goes in the message too.
          "   Marked on DIV_KHULA_DATE, not on the contract date: MARR owns that
          " one and it is a step back, so a red border there is out of sight.
          " The rule is always marked on the field the CURRENT step owns.
          APPEND field_error( iv_field = 'DIV_KHULA_DATE'
          iv_text = date_order_msg(
          iv_a_en = 'Marriage contract date' iv_a_ar = |تاريخ عقد الزواج| iv_a_val = lv_marr_dat
          iv_before = abap_false
          iv_b_en = 'Date of divorce or khula' iv_b_ar = |تاريخ الطلاق أو الخلع أو التطليق|
          iv_b_val = lv_div_dat ) ) TO rt.
        ENDIF.

      WHEN c_step_hist.
        "   DIGITS ONLY IS NO LONGER HERE. All four counts on this step took the
        " same rule through a COUNT_CHECK( ) method; it is gone, replaced by
        " REGEX '^[0-9]+$' on each of the four rows in ZRAK_C022_LOAD. The
        " engine's own check is equivalent in every respect that matters - same
        " moment (VALIDATE_STEP), skips a blank value, calls SET_FIELD_STATE so
        " the field still turns red, and runs after MAX_LEN so an over-long
        " value still reports its length rather than its format. The loader
        " carries the full comparison, including which two fields can keep the
        " old wording in MSG and which two fall back to the framework's
        " "&1 has an invalid format".
        "   One thing did not survive: the wives count passed the WD's own OTR
        " text (Z_RAKEGA_MUNI/ZWDC_DIV_REQUE_ATT_MSG) as its digits message, and
        " that text can only come back through MSG, which is the mandatory
        " wording on that field. Flagged in the loader.
        DATA(lv_prev_div) = condense( io_ctx->get_val( 'PREV_DIVORCES_COUNT' ) ).

        "   THE "NOT MORE THAN 9" CHECK IS NO LONGER HERE. It is MAX_VAL = 9 on
        " the WIVES_COUNT_HUSBAND row in ZRAK_C022_LOAD; VALIDATE_STEP's numeric
        " gate covers FTYPE 'INPUT', and its message needs no clause of its own
        " because C_NO-NUM_MAX ("&1 must be at most &2") reads better with the
        " label and the bound than the literal built here did. What kept it in
        " ABAP was that the range message fell back to the field's single MSG
        " column, which carries the mandatory wording - engine point R8-2 closed
        " that by letting MSG be written per check.
        "   The invariant behind the 9 is unchanged and worth keeping in view:
        " ZZAFLD0000V3 is CHAR(1) and keeps only the FIRST character of anything
        " longer, so 12 wives would post as 1. MAX_LEN = 1 stops a second digit
        " at the keyboard, MAX_VAL = 9 stops it on the step, and DIGITS_ONLY( )
        " in ON_SUBMIT is the backstop.
        "   Moved here with the two dates themselves. HIST is now the last step
        " that owns FIRST_MARR_CTR_DT and LAST_DIV_DATE, so this is where the
        " ordering can be judged with every value present. The two dates read
        " from earlier steps need their own locals: inline DATA( ) is
        " method-scoped, so the DIVO branch's lv_div_dat / lv_marr_dat cannot be
        " redeclared here.
        DATA(lv_khula_dat) = conv_date_internal( io_ctx->get_val( 'DIV_KHULA_DATE' ) ). " Date of divorce or khula
        DATA(lv_ctr_dat)   = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ). " Marriage contract date
        DATA(lv_fst_marr)  = conv_date_internal( io_ctx->get_val( 'FIRST_MARR_CTR_DT' ) ). " First marriage contract date
        DATA(lv_lst_div)   = conv_date_internal( io_ctx->get_val( 'LAST_DIV_DATE' ) ). " Last divorce date
        "   One check per comparison, each naming both dates. The WD ORs three
        " comparisons together per date and raises a single generic OTR text, so
        " the citizen is told only that a date is wrong, never which pair
        " disagrees. Note the WD also tests first-marriage > last-divorce AND
        " last-divorce < first-marriage - the same comparison twice, so one
        " violation produced two messages. It is asserted once here.
        IF lv_fst_marr IS NOT INITIAL AND lv_khula_dat IS NOT INITIAL
        AND lv_fst_marr > lv_khula_dat.
          APPEND field_error( iv_field = 'FIRST_MARR_CTR_DT'
          iv_text = date_order_msg(
          iv_a_en = 'First marriage contract date' iv_a_ar = |تاريخ عقد الزواج الأول بين الطرفين| iv_a_val = lv_fst_marr
          iv_before = abap_false
          iv_b_en = 'Date of divorce or khula' iv_b_ar = |تاريخ الطلاق أو الخلع أو التطليق| iv_b_val = lv_khula_dat ) ) TO rt.
        ENDIF.
        IF lv_fst_marr IS NOT INITIAL AND lv_ctr_dat IS NOT INITIAL
        AND lv_fst_marr > lv_ctr_dat.
          APPEND field_error( iv_field = 'FIRST_MARR_CTR_DT'
          iv_text = date_order_msg(
          iv_a_en = 'First marriage contract date' iv_a_ar = |تاريخ عقد الزواج الأول بين الطرفين| iv_a_val = lv_fst_marr
          iv_before = abap_false
          iv_b_en = 'Marriage contract date' iv_b_ar = |تاريخ عقد الزواج| iv_b_val = lv_ctr_dat ) ) TO rt.
        ENDIF.
        IF lv_fst_marr IS NOT INITIAL AND lv_lst_div IS NOT INITIAL
        AND lv_fst_marr > lv_lst_div.
          APPEND field_error( iv_field = 'FIRST_MARR_CTR_DT'
          iv_text = date_order_msg(
          iv_a_en = 'First marriage contract date' iv_a_ar = |تاريخ عقد الزواج الأول بين الطرفين| iv_a_val = lv_fst_marr
          iv_before = abap_false
          iv_b_en = 'Last divorce date' iv_b_ar = |تاريخ الطلاق السابق| iv_b_val = lv_lst_div ) ) TO rt.
        ENDIF.
        IF lv_lst_div IS NOT INITIAL AND lv_khula_dat IS NOT INITIAL
        AND lv_lst_div > lv_khula_dat.
          APPEND field_error( iv_field = 'LAST_DIV_DATE'
          iv_text = date_order_msg(
          iv_a_en = 'Last divorce date' iv_a_ar = |تاريخ الطلاق السابق| iv_a_val = lv_lst_div
          iv_before = abap_false
          iv_b_en = 'Date of divorce or khula' iv_b_ar = |تاريخ الطلاق أو الخلع أو التطليق| iv_b_val = lv_khula_dat ) ) TO rt.
        ENDIF.
        IF lv_lst_div IS NOT INITIAL AND lv_ctr_dat IS NOT INITIAL
        AND lv_lst_div > lv_ctr_dat.
          APPEND field_error( iv_field = 'LAST_DIV_DATE'
          iv_text = date_order_msg(
          iv_a_en = 'Last divorce date' iv_a_ar = |تاريخ الطلاق السابق| iv_a_val = lv_lst_div
          iv_before = abap_false
          iv_b_en = 'Marriage contract date' iv_b_ar = |تاريخ عقد الزواج| iv_b_val = lv_ctr_dat ) ) TO rt.
        ENDIF.
        "   Origin: CHECK_INITIAL_FIELDS — for ZZAFLD0000UM alone the WD swaps
        " the framework's mandatory text for ZMSG_ECOURT 000, "Number of
        " divorces can't be Zero". That wording is the giveaway: the framework
        " check tests whether the bound attribute is INITIAL, and on a numeric
        " attribute initial and zero are the same value, so the mandatory check
        " doubles as a zero check. MISSING_REQUIRED tests IS INITIAL on the
        " STRING form instead, where '0' is a non-empty string and passes - so
        " the blank case is covered by rule R04 plus the field's MSG, and only
        " zero needs catching here. Gated on EARLIER_MARRIAGES = 1 because that
        " is what makes the field mandatory at all (ONACTIONSET_PREV_DIV sets
        " STC_PREV_DIV = '01' only for UY = '1'), so a zero left behind on the
        " No branch must not block the step.
        " CO '0' matches '0', '00' and '000' without converting the string to a
        " number, which would raise CX_SY_CONVERSION_NO_NUMBER on any typo.
        IF io_ctx->get_val( 'EARLIER_MARRIAGES' ) = '1'
        AND lv_prev_div IS NOT INITIAL
        AND lv_prev_div CO '0'.
          DATA(lv_zero_msg) = t100_text( iv_id = 'ZMSG_ECOURT' iv_no = '000' ).
          IF lv_zero_msg IS INITIAL.
            lv_zero_msg = COND string(
            WHEN sy-langu = 'A'
            THEN |لا يمكن لعدد حالات الطلاق السابقة بين الطرفين أن يساوي صفر|
            ELSE |Number of divorces can't be Zero| ).
          ENDIF.
          APPEND field_error( iv_field = 'PREV_DIVORCES_COUNT'
          iv_text = lv_zero_msg ) TO rt.
        ENDIF.
        DATA(lv_prov_dat) = conv_date_internal( io_ctx->get_val( 'MARR_PROVING_DATE' ) ).
        IF lv_prov_dat IS NOT INITIAL AND lv_prov_dat > lv_today.
          APPEND field_error( iv_field = 'MARR_PROVING_DATE'
          iv_text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_COURT_ATT_VALIDATE_FUTURE_DATE' ) ) TO rt.
        ENDIF.

      WHEN c_step_prty.
        "   PRTY — Parties. Both witnesses filled or both empty, and no BP
        "   repeated across the four roles (Origin: VALIDATE_WITNESS /
        "   No divorcee check here. The engine enforces REQUIRED on the field
        "   itself, so a hand-written one would only add a second error line
        "   saying the same thing. The wording is configuration instead:
        "   ZRAK_C022_LOAD sets MSG / MSG_AR on DIVORCEE_PARTNER, which
        "   MISSING_REQUIRED prefers over its generic text.
        "   Village number holds digits in the backend, so refuse anything else
        " before it gets there. The engine re-checks a grid column's REQUIRED
        " and MAXLEN per row now, but it has no per-column type or pattern, so
        " this is the one grid rule that still has to be written out.
        "   Read through GET_GRID_DATA rather than the model: its COLUMNS come
        " from ZRAK_T_JNY_COL in the configured order, so LINE_INDEX finds the
        " cell wherever the column is moved to, and the <COL>_TXT companions the
        " engine now builds for SELECT columns stay invisible to it. Both rows
        " are reported, named by their party, because fixing one and being told
        " about the other on the next click is a wasted round.
        DATA(ls_pers) = io_ctx->get_grid_data( 'PERS_INFO' ).
        DATA(lv_vn_i) = line_index( ls_pers-columns[ table_line = 'ZZAFLD0000TU' ] ).
        DATA(lv_pt_i) = line_index( ls_pers-columns[ table_line = 'ZZAFLD0000V2' ] ).
        DATA(lt_popt) = party_type_opts( ).
        IF lv_vn_i > 0.
          LOOP AT ls_pers-rows INTO DATA(lt_prow).
*           Captured here, not read at the APPEND below: a table expression is
*           documented not to set SY-TABIX, but two of them sit in between and
*           the row number is the fallback label.
            DATA(lv_rowno) = sy-tabix.
            IF lines( lt_prow ) < lv_vn_i.
              CONTINUE.
            ENDIF.
            DATA(lv_vnum) = condense( lt_prow[ lv_vn_i ] ).
            IF lv_vnum IS INITIAL OR lv_vnum CO '0123456789'.
              CONTINUE.
            ENDIF.
*           The cell holds the partner-function CODE, so it is resolved through
*           the same option list the read-only column is rendered from. The
*           <COL>_TXT companion RENDER_GRID resolves into is not reachable here:
*           GET_GRID_DATA builds its columns from ZRAK_T_JNY_COL, which the
*           companion is not part of.
            DATA(lv_party) = |{ lv_rowno }|.
            IF lv_pt_i > 0 AND lines( lt_prow ) >= lv_pt_i.
              DATA(lv_pkey) = lt_prow[ lv_pt_i ].
              READ TABLE lt_popt INTO DATA(ls_popt) WITH KEY key = lv_pkey.
              IF sy-subrc = 0.
                lv_party = ls_popt-text.
              ENDIF.
            ENDIF.
*           A CELL, not a scalar field, so FIELD carries the compound
*           '<grid>.<col>#<row>' the engine parses in SET_CELL_STATE( ) - the
*           same shape ON_CHANGE already hands us for a grid change. LV_ROWNO is
*           the 1-based table index it expects, not the row's _UID.
*           The party stays in the message text as well as the border: the strip
*           is read on its own, above the grid, and "enter numbers only" without
*           saying whose row is no more use there than it ever was.
            APPEND field_error(
            iv_field = |PERS_INFO.ZZAFLD0000TU#{ lv_rowno }|
            iv_text = COND string(
            WHEN sy-langu = 'A'
            THEN |الرجاء ادخال ارقام فقط في حقل رقم البلدة ({ lv_party })|
            ELSE |Please enter numbers only for Village number ({ lv_party })| ) ) TO rt.
          ENDLOOP.
        ENDIF.
        DATA(lv_wit1_bp) = io_ctx->get_val( 'WITNESS1_PARTNER' ).
        DATA(lv_wit2_bp) = io_ctx->get_val( 'WITNESS2_PARTNER' ).
        IF NOT ( ( lv_wit1_bp IS NOT INITIAL AND lv_wit2_bp IS NOT INITIAL )
        OR ( lv_wit1_bp IS INITIAL     AND lv_wit2_bp IS INITIAL ) ).
          "   Marked on whichever witness is the missing one - the rule is "both
          " or neither", so the filled one is not the problem.
          APPEND field_error(
          iv_field = COND string( WHEN lv_wit1_bp IS INITIAL THEN 'WITNESS1_PARTNER'
                                  ELSE 'WITNESS2_PARTNER' )
          iv_text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/CIVIL_COURT_WITNESS_ERROR_MSG' ) ) TO rt.
        ENDIF.
        "   Was a sort-and-count on the values alone, which answered "is one of
        " these repeated" but not "which one". The roles are carried alongside
        " the values now, so the message can name a field and turn it red
        " instead of leaving the citizen to compare four numbers by eye. The
        " blanks are skipped rather than deleted: an entry has to keep its
        " position for LT_ROLE to still line up with it.
*       Backquotes, not apostrophes. TT_STRING's line type is STRING and a
*       VALUE constructor for an elementary line type wants a COMPATIBLE value,
*       not merely a convertible one - a '...' literal is type C and is
*       rejected outright. The values this table used to be built from were
*       GET_VAL( ) results, already STRING, which is why the shape only started
*       failing when the role names replaced them.
        DATA(lt_role) = VALUE zif_rak_journey=>tt_string(
              ( `DIVORCEE_PARTNER` ) ( `DIVORCER_PARTNER` )
              ( `WITNESS1_PARTNER` ) ( `WITNESS2_PARTNER` ) ).
        DATA lt_bp TYPE zif_rak_journey=>tt_string.
        CLEAR lt_bp.
        LOOP AT lt_role INTO DATA(lv_role).
          APPEND io_ctx->get_val( lv_role ) TO lt_bp.
        ENDLOOP.

*       One row per message, so the field named is the FIRST role holding a
*       repeated BP - the other end of the clash is one of the three fields
*       beside it. Marking both ends would need a second row carrying the same
*       sentence, and two identical lines in the strip read as two problems.
        DATA(lv_dup_fld) = ``.
        LOOP AT lt_bp INTO DATA(lv_bp).
*         Captured before the inner LOOP, which resets SY-TABIX.
          DATA(lv_bp_i) = sy-tabix.
          IF lv_bp IS INITIAL.
            CONTINUE.
          ENDIF.
          DATA(lv_seen) = 0.
          LOOP AT lt_bp TRANSPORTING NO FIELDS WHERE table_line = lv_bp.
            lv_seen = lv_seen + 1.
          ENDLOOP.
          IF lv_seen > 1.
            lv_dup_fld = lt_role[ lv_bp_i ].
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_dup_fld IS NOT INITIAL.
          APPEND field_error( iv_field = lv_dup_fld
          iv_text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_COURT_ATT_DUPLICATE_PARTIES_INV' ) ) TO rt.
        ENDIF.

      WHEN c_step_docs.
        " cross-attachment re-check here. The payer is fixed to the divorcer, so
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
*&---------------------------------------------------------------------*
*& CLASS OVERVIEW (kept inside on_init so the class-builder can store it)
*&---------------------------------------------------------------------*
*& ZCL_C022_KHULA_CERTI_LOGIC  —  journey-engine handler
*&---------------------------------------------------------------------*
*& Generated from the WebDynpro migration of ZWDC_EGA_ECREATE_SR_COURT.
*& Source handler: ZCL_ECREATE_SR_COURT_HANDLER (186 methods).
*& Mapping:        ZCL_ECREATE_SR_COURT_method_mapping.xlsx
*& Template:       ZCL_RAK_<NAME>_LOGIC / productive sample ZCL_RAK_E020_LOGIC.
*&
*& LOCKED CONVENTIONS APPLIED
*&  - INHERITS FROM zcl_rak_journey_logic; redefines only the callbacks used.
*&  - No mutable class attributes. State lives in io_ctx (get_val/set_val).
*&  - Event/notification messages via io_ctx->add_msg( iv_type = <sev> iv_text = )
*&    where <sev> is the z2ui5 long form 'Error' / 'Warning' / 'Success'
*&    (NOT the short 'E' — the engine renders type verbatim and gates on 'Error').
*&    add_msg takes only iv_type / iv_text.
*&  - on_custom_validate does NOT use add_msg: it must RETURN its messages in
*&    rt (tt_msg, type = 'Error'); the engine appends rt to the step's error set
*&    and blocks the step when any row is type 'Error'. add_msg there would show
*&    a strip but would NOT block the step.
*&  - SERVICE_TYPE seeded in on_init and read with io_ctx->get_val everywhere.
*&  - Message-alias OTR texts kept as private runtime helpers
*&    (get_otr_text_for_alias / get_otr_text_by_alias -> SOTR_GET_TEXT_KEY).
*&  - Domain-backed dropdowns served by on_value_help via private helper
*&    options_from_domain( iv_domain ).
*&
*& OPEN ITEMS (current; see GENERATION_DECISIONS.md + the *_addenda xlsx):
*&  MANDATORY FIELDS — switched on. Verified against the live WD, which on a
*&   blank Submit names 11 fields plus the attachment; every one of those is
*&   REQUIRED in the config, with no gap in that direction. Three routes,
*&   because the engine enforces them differently:
*&    - 12 ordinary fields + ATTACHMENT: MISSING_REQUIRED reads the REQUIRED
*&      flag on ZRAK_T_JNY_FLD directly. ATTACHMENT rides its HAS_ATTACH
*&      branch, which also accepts a document already filed in the backend so
*&      resuming a draft is not a dead end.
*&    - 3 grid columns (ZZAFLD0000V2 / TT / TW): REQUIRED on ZRAK_T_JNY_COL.
*&      PERS_INFO itself also carries REQUIRED = 'X' and that is a
*&      prerequisite, not decoration: MISSING_REQUIRED skips a field whose own
*&      IS_REQUIRED is false before it reaches the per-column loop.
*&    - CONTRACT_PLACE / DIVORCEE_PARTNER / DIVORCER_PARTNER are filled by a
*&      popup or by ON_INIT, never typed. FTYPE 'READONLY', and MISSING_REQUIRED
*&      reads their REQUIRED flag like any other field's. Only DIVORCEE_PARTNER
*&      can actually be left blank; the other two are seeded in ON_INIT. Their
*&      MSG / MSG_AR give the citizen a sentence naming the party rather than
*&      the engine's generic one.
*&   Deliberately NOT required: FIRST_MARR_CTR_DT and PREV_DIVORCES_COUNT
*&   are made mandatory by rules R02 / R04 when EARLIER_MARRIAGES = 1;
*&   CHILDREN_UNDER_21 stays optional: its control G_TAKEOFF_ZZAFLD0000UL
*&   carries STATE = '00', the screen prefills it with 0 and shows no asterisk.
*&   DOCUMENT_TYPE is required — DD_DOCUMENT_TYPE_CP carries STATE = '01' in
*&   VIEW_ADD_ATTACHMENT (the Open_Mandatory sheet had it as unstarred, read
*&   off the main screen, where that control does not appear).
*&   WIVES_COUNT_HUSBAND is required because its control
*&   G_TAKEOFF_ZZAFLD0000V3 carries STATE = '01', and it is the field the WD's
*&   VALIDATE_NUMERIC checks. The plain REQUIRED flag is right for "not blank,
*&   0 valid" — MISSING_REQUIRED tests IS INITIAL on the string form, so '0'
*&   passes; ON_CUSTOM_VALIDATE adds the numeric test.
*&   NOTE — these two fields map to the OPPOSITE backend columns from what an
*&   earlier reading assumed. LABEL_FOR is broken on both labels (each points at
*&   G_TAKEOFF_ZZAFLD0000UL), but label naming, layout order (V3 label+input at
*&   47/48, UL at 49/50) and the STATE flags all agree: V3 = number of wives,
*&   UL = children under 21. Confirmed against the screen.
*&  CONDITIONAL MANDATORY — the WD binds each control's STATE property to an
*&   attribute of its STATE context node and the ONACTIONSET_* handlers write
*&   '01' / '00' into it, so mandatory is data-driven there, not hard-coded.
*&   Those flags are ported as REQUIRE rules, not as code:
*&    R16  CASE_UPON_DIVORCE = 1 -> ISOLATION        (stc_isolation)
*&    R17  CASE_UPON_DIVORCE = 2 -> MARR_CONSUMMATED (stc_marr_cons)
*&    R11  PREV_DIVORCES_COUNT  > 0 -> LAST_DIV_DATE     (stc_last_div)
*&    R02 / R04 EARLIER_MARRIAGES = 1 -> FIRST_MARR_CTR_DT +
*&              PREV_DIVORCES_COUNT                      (stc_prev_div)
*&   GRANT_SIDE gets no REQUIRE: ONACTIONSET_GRANT touches ms_input_allowed
*&   only and never STATE. CHILDREN_COUNT / MARR_PROVING_DATE bind
*&   STC_DIV_MARR_TAKEOFF_1, which AS3 sets to 0.
*&   ON_CHANGE still clears the dependents on every trigger change; only the
*&   EDITABLE / READONLY / REQUIRE toggles are declarative.
*&  MESSAGE TEXTS — three sources, in the order MISSING_REQUIRED consults them.
*&   A field's own MSG / MSG_AR on ZRAK_T_JNY_FLD wins where the loader sets
*&   one, which it does wherever the WD had a specific sentence to honour or
*&   where a generic one would name nothing (the parties, the divorcee).
*&   Otherwise the ENGINE's own text: ZCL_RAK_TEXT msgno 013 ('&1 is required')
*&   and 051 ('&1: attachment is required'), &1 replaced by the field's ZLABEL
*&   or ZLABEL_AR, overridable per journey through ZRAK_T_CJ_TXT.
*&   The date / witness / duplicate-party errors are the WD's, resolved from
*&   its own OTR aliases. The count-field and grid-cell rules below are worded
*&   here, because neither the WD nor the engine has a sentence for them.
*&  CONFIRMATIONS (defaults in place):
*&   - step codes MARR/DIVO/HIST/PRTY/DOCS (ZRAK_T_JNY_STEP.STEP_ID); no PAY step.
*&   - DOCUMENT_TYPE filter iv_attach='AD01' — fixed value, no mapping.
*&   - PERS_INFO grid read/write via io_ctx get_grid_data/set_grid_data (wired).
*&   - on_submit header/header_ext mapping matches SUBMIT_DEV_MARRIAGE_TAKEOF
*&     (MOVE-CORRESPONDING set + the fixed values) — confirmed against the WD.
*&   - ATTACH_TYPES: AVI,BMP,DOC,DOCX,DWG,JPEG,JPG,MP4,PDF,PNG,PPT,RAR,TIF,TIFF,
*&     XLS,XLSX,ZIP (confirmed allowed set).
*&  ATTACHMENT VALIDATION (implemented in on_attach):
*&   - The engine does the size check + storage before firing on_attach, so the
*&     logic does the allowed-extension check only. The staged file is read via
*&     io_ctx->get_attachment_files( ) filtered on IDENTIFIER1 = iv_field (the
*&     upload field name); extension via TRINT_FILE_GET_EXTENSION checked against
*&     the master list ZFM_EGA_GET_FILE_EXT_WD_UPLOAD (error ZMSG_EGA_CM 111).
*&  GRID + ATTACHMENTS (implemented via the engine accessors):
*&   - PERS_INFO is a fixed 2-row EDITABLE_TABLE; seeded in on_init via
*&     set_grid_data (V2 = 1 Divorcer / 2 Divorcee), read in on_submit +
*&     on_custom_validate. The WD's own grid completeness checks are dead code
*&     (unconditional RETURN in CHECK_PERS_INFO, confirmed at runtime: a blank
*&     Submit reports no grid error), so they are not ported as code — the
*&     intent is carried by REQUIRED on the ZRAK_T_JNY_COL rows instead, which
*&     MISSING_REQUIRED does enforce against every existing row.
*&     The WD's UI-only row flags READ_ONLY / READ_ONLY1 are not columns here.
*&   - attachment submission posts each staged file (io_ctx->get_attachment_files)
*&     via ZFM_WDA_CREATE_AI_ATTACHMENT_U in on_submit.
*&   - on_submit fires on the SUBMIT action; on_save is draft-only (not used).
*&     No double-post risk: with no backend and no bridge the engine's own
*&     post path is not taken, so this class is the only writer.
*&  DEFERRED / ENHANCE (need input):
*&   - update_dummy_witnesses ported via customizing FM ZREAD_WITT( service ):
*&     dummies fire only when SKIP_WITNESS = 'X'. AS3 is WITH_WITNESS = 'X'
*&     (skip blank), so it does not fire.
*&
*& STATUS: ported from the WD source, activated, and walked end to end on the
*& live journey - the mandatory set cross-checked against the WD's own
*& blank-Submit error list, and every validation below seen to fire.
*&---------------------------------------------------------------------*
*& ON_INIT — journey open: seed SERVICE_TYPE, header/help, texts, card
*& Folds: e_get_help_url, get_header_title, get_new_header_title,
*&        init_dropdowns, parse_portal_username, populate_card_data,
*&        populate_texts.  (dropdown POPULATION itself is dropped — the
*&        engine binds on_value_help options; init_dropdowns collapses to
*&        nothing here.)
*&---------------------------------------------------------------------*

    io_ctx->set_val( iv_name = 'SERVICE_TYPE' iv_value = c_default_service ).

    "   Origin: COMPONENTCONTROLLER->PARSE_PORTAL_USERNAME + HANDLEFROM_WINDOW_MAIN
    " it as the public attribute MV_LOGINBP, so the WD's internet-user chain
    DATA lv_loginbp TYPE bu_partner.
    lv_loginbp = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.

    "   Origin: HANDLEFROM_WINDOW_MAIN / POPULATE_CARD_DATA — seed the card.
    " The WD raised no error for a missing login BP, so none is raised here.
    IF lv_loginbp IS NOT INITIAL.
      DATA ls_bpdata TYPE zmoi_bp_str.
      CALL FUNCTION 'ZBP_GET_DATA'
        EXPORTING
          iv_partner = lv_loginbp
        IMPORTING
          ev_bp_data = ls_bpdata.

      DATA(lv_bpname) = COND string(
            WHEN ls_bpdata-zengname IS NOT INITIAL THEN |{ ls_bpdata-zengname }|
            ELSE condense( |{ ls_bpdata-zfname } { ls_bpdata-zfaname } { ls_bpdata-zgfname } { ls_bpdata-z4thname } { ls_bpdata-zlname }| ) ).

      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
      io_ctx->set_val( iv_name = 'APP_NAME' iv_value = lv_bpname ).
      io_ctx->set_val( iv_name = 'APP_ID'   iv_value = |{ ls_bpdata-zeid }| ).

      " The applicant of this service IS the divorcer, so pre-fill that party
      " from the logged-in BP (the WD screen shows the divorcer already filled
      io_ctx->set_val( iv_name = 'DIVORCER_PARTNER' iv_value = |{ lv_loginbp }| ).
      io_ctx->set_val( iv_name = 'DIVORCER_NAME'    iv_value = lv_bpname ).
    ENDIF.

    "   Origin: VIEW_MAIN->SET_DEF_VALUES — service-INDEPENDENT constant
    " rather than re-deriving on each service selection as the WD did.
    io_ctx->set_val( iv_name = 'CONTRACT_PLACE'          " Contract Place
    iv_value = get_otr_text_by_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_RAK' ) ).
    io_ctx->set_val( iv_name = 'COURT'         " Court
    iv_value = get_otr_text_by_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_COURT_RAK' ) ).
    io_ctx->set_val( iv_name = 'EMIRATE'          " Emirate
    iv_value = get_otr_text_by_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_EMIRATE_RAK' ) ).
    " NOTE: the WD set the Contract Place on four section structures
    " (marriage_certif / div_marr_takeoff / attestation_srv / marriage_cont);

    "   Origin: VIEW_MAIN->E_GET_HELP_URL — help link is service-type driven;
    " compute it for the seeded SERVICE_TYPE (and again in on_change).
    refresh_help_url( io_ctx ).

    "   Origin: VIEW_MAIN->GET_NEW_HEADER_TITLE — the WD read the page header
    " from the application's OTR alias. That text is now ZRAK_T_JNY.TITLE, so
    " there is nothing to set here: HEADER_TITLE was never a field on the
    " journey and SET_VAL against a name that is not in ZRAK_T_JNY_FLD is legal
    " and does nothing.

    "   Origin: (fill_dropdown_all row-build) — PERS_INFO is a fixed 2-row
    " EDITABLE_TABLE seeded with the partner-function code, as the WD does.
    " GET_GRID_DATA returns the configured columns with no rows at load.
    DATA(ls_seed) = io_ctx->get_grid_data( 'PERS_INFO' ).
    IF ls_seed-rows IS INITIAL.
      DATA(lv_v2_i) = line_index( ls_seed-columns[ table_line = 'ZZAFLD0000V2' ] ).
      DATA lt_r1 TYPE zif_rak_journey=>tt_string.
      DATA lt_r2 TYPE zif_rak_journey=>tt_string.
      DATA lv_ncols TYPE i.
      CLEAR: lt_r1, lt_r2.
      lv_ncols = lines( ls_seed-columns ).
      DO lv_ncols TIMES.
        APPEND `` TO lt_r1.
        APPEND `` TO lt_r2.
      ENDDO.
      " exactly two rows, fixed: row 1 = Divorcer, row 2 = Divorcee. V2 carries
      " the partner-function CODE, exactly as the WD sends it, and is also the
      " visible "Partner type" column - a read-only SELECT, which RENDER_GRID
      " resolves to its option label per row through ON_VALUE_HELP. Only the
      " code is seeded; nothing here writes the label.
      " ZZAFLD0000V0 is left untouched and hidden, which is what the WD does
      " with it (set_visible( visibility_none ), never written) - it used to
      " carry the label and was posting a value the legacy screen never sent.
      IF lv_v2_i > 0.
        lt_r1[ lv_v2_i ] = '1'.   " Divorcer
        lt_r2[ lv_v2_i ] = '2'.   " Divorcee
      ENDIF.
      APPEND lt_r1 TO ls_seed-rows.
      APPEND lt_r2 TO ls_seed-rows.
      io_ctx->set_grid_data( iv_field = 'PERS_INFO' is_data = ls_seed ).
    ENDIF.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT.
*&---------------------------------------------------------------------*
*& ON_POPUP_EVENT — the partner search is ZCL_RAK_BP_POPUP's, and this
*& method routes three things and owns one:
*&  (a) the popup's own events (BPP_*) go to the popup for the subject
*&      named by IV_ID,
*&  (b) the three Add-BP open events open BP_<SUBJECT>, and
*&  (c) everything else - the payment PAYNOW/PAYPOLL flow - is the
*&      superclass's.
*& The one thing owned here is the future-date-of-birth refusal, which runs
*& BEFORE (a) delegates. Subjects: DIVORCEE, WITNESS1, WITNESS2.
*&---------------------------------------------------------------------*

*   THE SUBJECT COMES FROM IV_ID, NOT FROM A FIELD OF OUR OWN. The engine
*   passes MV_POPUP_ID as IV_ID on every popup event (ZCL_RAK_JOURNEY_ENGINE
*   ~779), and ON_RENDER_POPUP already derives the subject the same way -
*   so both hooks read ONE value and cannot disagree about which party is
*   being searched. BP_ACTIVE_SUBJECT was a second copy of that answer and
*   is gone with the popup it served.
    IF iv_event CP 'BPP_*' AND iv_id CP 'BP_*'.
      DATA(lv_subj) = substring_after( val = iv_id sub = 'BP_' ).

*     OUR ONE CHECK, BEFORE THE ENGINE'S. A future date of birth is the
*     journey's question, not the popup's - see BP_DOB_FUTURE( ) - and it
*     is asked here rather than in a subclass because this method is
*     already ours. On refusal we do NOT delegate: the search must not run.
*
*     THE COST, STATED: a future date is then reported on its own, where
*     VALIDATE_FORM( ) would have listed it beside any other gap. For a
*     typo this rare that is a better trade than an inheritance.
      IF iv_event = zcl_rak_bp_popup=>c_ev_run
         AND bp_dob_future( io_ctx = io_ctx iv_subject = lv_subj ) = abap_true.
        RETURN.
      ENDIF.

      bp_popup( io_ctx = io_ctx iv_subject = lv_subj )->handle( iv_event ).
      RETURN.
    ENDIF.

    CASE iv_event.
      WHEN c_evt_bp_divorcee.
        io_ctx->open_popup( 'BP_DIVORCEE' ).
      WHEN c_evt_bp_witness1.
        io_ctx->open_popup( 'BP_WITNESS1' ).
      WHEN c_evt_bp_witness2.
        io_ctx->open_popup( 'BP_WITNESS2' ).
      WHEN OTHERS.
        super->zif_rak_journey_logic~on_popup_event(
        io_ctx = io_ctx iv_id = iv_id iv_event = iv_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_AFTER_FIELD.
*&---------------------------------------------------------------------*
*& ON_RENDER_AFTER_FIELD — the Add-BP button for each party, rendered
*& INLINE at the end of that party's row (same layout as the WD screen,
*& where "Add BP" sits directly beside the party field).
*& Buttons are NOT field configuration: they are drawn here and wired to an
*& event with io_ctx->event( ). io_view is this field's own cell, so the
*& button attaches to that row only. The caption flips Add -> Change by
*& reading the popup's write-back field <SUBJECT>_PARTNER.
*&---------------------------------------------------------------------*
    DATA lv_txt TYPE string.
    CASE to_upper( is_field-name ).
      WHEN 'PERS_INFO'.
        " Heading for the parties block that follows the grid. ZSECTION gained
        " its ZSECTION_AR twin on feature/dev, so the old reason for drawing it
        " here - a configured section header stuck in one language - is gone.
        " It stays here anyway for a layout reason: a section opens its own
        " sap.m.Panel and the fields inside it lose the 'rakCard' class, so
        " moving this heading into configuration would restyle the whole parties
        " block, not just print its title. That is a design decision, not a
        " free swap. The grid above needs no heading of its own — its
        " ZLABEL/ZLABEL_AR already prints one.
        IF sy-langu = 'A'.
          lv_txt = 'بيانات الاطراف'.
        ELSE.
          lv_txt = 'Parties involved'.
        ENDIF.
        io_view->title( text = lv_txt class = 'rakBlkTitle sapUiSmallMarginTop' ).

      WHEN 'DIVORCEE_NAME'.
        io_view->button(
        text  = bp_button_text( iv_partner = io_ctx->get_val( 'DIVORCEE_PARTNER' )
        iv_role_en = 'divorcee' iv_role_ar = 'المطلقة' )
        icon  = 'sap-icon://search'
        type  = 'Emphasized'
        press = io_ctx->event( c_evt_bp_divorcee ) ).
      WHEN 'DIVORCER_NAME'.
        " No Add/Change button for the divorcer: that party IS the applicant and
        " nothing to search for. Only the fee-payer marker is drawn, exactly as
        IF sy-langu = 'A'.
          lv_txt = 'دافع الرسوم'.
        ELSE.
          lv_txt = 'Fee payer'.
        ENDIF.
        io_view->text( text = lv_txt class = 'sapUiSmallMarginBegin' ).
      WHEN 'WITNESS1_NAME'.
        io_view->button(
        text  = bp_button_text( iv_partner = io_ctx->get_val( 'WITNESS1_PARTNER' )
        iv_role_en = 'witness 1' iv_role_ar = 'الشاهد الأول' )
        icon  = 'sap-icon://search'
        type  = 'Emphasized'
        press = io_ctx->event( c_evt_bp_witness1 ) ).
      WHEN 'WITNESS2_NAME'.
        io_view->button(
        text  = bp_button_text( iv_partner = io_ctx->get_val( 'WITNESS2_PARTNER' )
        iv_role_en = 'witness 2' iv_role_ar = 'الشاهد الثاني' )
        icon  = 'sap-icon://search'
        type  = 'Emphasized'
        press = io_ctx->event( c_evt_bp_witness2 ) ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP.
*&---------------------------------------------------------------------*
*& ON_RENDER_POPUP — draw the BP_<SUBJECT> partner-search dialog. The subject
*& is the id after 'BP_'. Non-BP popups fall through to the superclass.
*&---------------------------------------------------------------------*
    IF iv_id CP 'BP_*'.
      bp_popup( io_ctx     = io_ctx
                iv_subject = substring_after( val = iv_id sub = 'BP_' ) )->render( io_popup ).
      RETURN.
    ENDIF.
    super->zif_rak_journey_logic~on_render_popup(
    io_ctx = io_ctx io_popup = io_popup iv_id = iv_id ).
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_SUBMIT.
*&---------------------------------------------------------------------*
*& ON_SUBMIT( io_ctx ) RETURNING rt — final backend creation for AS3.
*& The engine calls on_submit on the SUBMIT action (handle_submit); on_save
*& is the draft handler and is NOT where a case is created. Since this
*& journey creates its own case (no QNV bridge), on_submit is the engine's
*& designated moment to do it and to call io_ctx->set_reference( ) with the
*& real request number so the confirmation screen shows it. Returning an
*& 'Error' row in rt blocks the submit and keeps the citizen on the page.
*& Origin: VIEW_MAIN->ONACTIONSUBMIT_CASE (AS2/AS3 branch) ->
*&         SUBMIT_DEV_MARRIAGE_TAKEOF -> RFC_REQUEST_SUBMIT
*&         (ZFM_ECC_WDA_CREATE_REQUEST) + GET_PARTNER_FUNCTIONS.
*&---------------------------------------------------------------------*
    DATA ls_header      TYPE zst_ega_court_service_header.
    DATA ls_header_ext  TYPE zst_ega_court_service_head_div.
    DATA lt_item_ext1   TYPE zst_ega_court_service_tab1.
    DATA ls_partners    TYPE zst_ega_court_service_partners.
    DATA lt_bapireturn  TYPE bapiret2_t.
    DATA(lv_applicant)  = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.

    "   Origin: VIEW_MAIN->UPDATE_DUMMY_WITNESSES (+ READ_WITNESS_HANDLE_DATA).
    " Whether witnesses are skipped for a service is customizing, read per
    DATA lv_skip_witness TYPE c LENGTH 1.   " CHAR1
    DATA lv_with_witness TYPE c LENGTH 1.   " CHAR1
    CALL FUNCTION 'ZREAD_WITT'
      EXPORTING
        iv_service   = CONV char40( c_default_service )   " AS3
      IMPORTING
        skip_witness = lv_skip_witness
        with_witness = lv_with_witness.
    IF lv_skip_witness = abap_true.
      io_ctx->set_val( iv_name = 'WITNESS1_PARTNER' iv_value = 'DUMMY_WIT1' ).
      io_ctx->set_val( iv_name = 'WITNESS2_PARTNER' iv_value = 'DUMMY_WIT2' ).
    ENDIF.

    ls_partners-divorcee_bp = io_ctx->get_val( 'DIVORCEE_PARTNER' ).
    ls_partners-divorcer_bp = io_ctx->get_val( 'DIVORCER_PARTNER' ).
    ls_partners-witness1_bp = io_ctx->get_val( 'WITNESS1_PARTNER' ).
    ls_partners-witness2_bp = io_ctx->get_val( 'WITNESS2_PARTNER' ).

    " payer: for AS3 the fee is always paid by the DIVORCER — the WD's payer
    " radio sits on the divorcer row and is not a choice for this service, so
    ls_partners-payer_ft = '00000004'.
    ls_partners-payer_bp = ls_partners-divorcer_bp.

    set_partner_functions( CHANGING cs_partners = ls_partners ).

    ls_header-process_type = 'YSR2'.
    ls_header-product      = c_default_service.
    ls_header-ordered_prod = c_default_service.
    ls_header-status       = 'E0003'.
    ls_header-quantity     = '1'.
    ls_header-zzafld0000ax = 'X'.
    ls_header-zzafld0000ay = lv_applicant.
    ls_header-zzafld0000dr = 'X'.

    " main-header divorce type (8O) are other-service fields — not populated for
    " AS3 (AS3's divorce type is UQ on header_ext).
    ls_header-text_z11     = io_ctx->get_val( 'REQUEST_TEXT' ).
    ls_header-zzafld00004d = io_ctx->get_val( 'CONTRACT_PLACE' ). " Contract Place
    ls_header-zzafld00008k = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ). " Marriage contract date (ISO -> YYYYMMDD)
    ls_header-zzafld00008l = io_ctx->get_val( 'MARR_CONTRACT_PLACE' ). " Marriage contract place
    ls_header-zzafld00008m = io_ctx->get_val( 'CHILDREN_COUNT' ). " No. of children
    ls_header-zzafld00008n = conv_date_internal( io_ctx->get_val( 'MARR_PROVING_DATE' ) ). " Marriage proving date (ISO -> YYYYMMDD)

    " ---- header extension: divorce takeoff-form fields --------------
    ls_header_ext-zzafld0000u4 = io_ctx->get_val( 'COURT' ).
    ls_header_ext-zzafld0000ug = io_ctx->get_val( 'EMIRATE' ).
    ls_header_ext-zzafld0000u3 = io_ctx->get_val( 'MARR_CONTRACT_NO' ).
    ls_header_ext-zzafld0000un = io_ctx->get_val( 'FAM_GUIDANCE_APPR' ).
    ls_header_ext-zzafld0000uo = io_ctx->get_val( 'MARR_GRANT_RECEIVED' ).
    ls_header_ext-zzafld0000uh = io_ctx->get_val( 'GRANT_SIDE' ).
    ls_header_ext-zzafld0000up = io_ctx->get_val( 'DIV_DECL_TYPE' ).
    ls_header_ext-zzafld0000uq = io_ctx->get_val( 'DIV_TYPE' ).
    " Origin: SUBMIT_DEV_MARRIAGE_TAKEOF — a divorce-type of '00' is the
    " "unset" placeholder; blank it before the backend call.
    IF ls_header_ext-zzafld0000uq = '00'.
      CLEAR ls_header_ext-zzafld0000uq.
    ENDIF.
    ls_header_ext-zzafld0000ur = io_ctx->get_val( 'DIV_APPLICANT' ).
    ls_header_ext-zzafld0000us = io_ctx->get_val( 'DIV_METHOD' ).
    ls_header_ext-zzafld0000ui = io_ctx->get_val( 'DIV_WORDS' ).
    ls_header_ext-zzafld0000uj = io_ctx->get_val( 'DIV_PLACE' ).
    ls_header_ext-zzafld0000ut = io_ctx->get_val( 'DIV_REASON' ).
    ls_header_ext-zzafld0000uk = io_ctx->get_val( 'DIV_REASON_DETAILS' ).
    ls_header_ext-zzafld0000u6 = io_ctx->get_val( 'RELATIVE_RELATION' ).
    ls_header_ext-zzafld0000uu = io_ctx->get_val( 'STATUS_UPON_MARR' ).
    ls_header_ext-zzafld0000uv = io_ctx->get_val( 'CASE_UPON_DIVORCE' ).
    ls_header_ext-zzafld0000uw = io_ctx->get_val( 'MARR_CONSUMMATED' ).
    ls_header_ext-zzafld0000ux = io_ctx->get_val( 'ISOLATION' ).
*   Leading zeros stripped before the assignment. ZZAFLD0000V3 is CHAR(1), so
*   it keeps the FIRST character of whatever it is given: '09' arrived in the
*   backend as '0'. MAX_LEN = 1 stops a second digit at the keyboard and
*   VALIDATE_STEP re-checks it, and REGEX refuses a non-digit, so this is the
*   backstop for a value that reached ON_SUBMIT another way.
    ls_header_ext-zzafld0000v3 = digits_only( io_ctx->get_val( 'WIVES_COUNT_HUSBAND' ) ).
    ls_header_ext-zzafld0000um = io_ctx->get_val( 'PREV_DIVORCES_COUNT' ). " NUMC
    ls_header_ext-zzafld0000uy = io_ctx->get_val( 'EARLIER_MARRIAGES' ).
    ls_header_ext-zzafld0000ub = conv_date_internal( io_ctx->get_val( 'DIV_KHULA_DATE' ) ).
    ls_header_ext-zzafld0000uc = conv_date_internal( io_ctx->get_val( 'LAST_MARR_DATE' ) ).
    ls_header_ext-zzafld0000ud = conv_date_internal( io_ctx->get_val( 'LAST_MARR_CTR_DT' ) ).
    ls_header_ext-zzafld0000ue = conv_date_internal( io_ctx->get_val( 'FIRST_MARR_CTR_DT' ) ).
    ls_header_ext-zzafld0000uf = conv_date_internal( io_ctx->get_val( 'LAST_DIV_DATE' ) ).
    ls_header_ext-zzafld0000ul = io_ctx->get_val( 'CHILDREN_UNDER_21' ).

    " PERS_INFO is a fixed 2-row grid (row 1 Divorcer, row 2 Divorcee). Read
    DATA(ls_grid) = io_ctx->get_grid_data( 'PERS_INFO' ).
    DATA lt_cells   TYPE zif_rak_journey=>tt_string.
    DATA ls_item    TYPE zst_ega_court_service_str_tab1.
    DATA lv_colname TYPE string.
    DATA lv_ci      TYPE i.
    DATA lv_cellval TYPE string.
    DATA lv_row     TYPE i.
    FIELD-SYMBOLS <comp> TYPE any.
    LOOP AT ls_grid-rows INTO lt_cells.
      CLEAR ls_item.
      lv_row = sy-tabix.
      LOOP AT ls_grid-columns INTO lv_colname.
        lv_ci = sy-tabix.
        ASSIGN COMPONENT lv_colname OF STRUCTURE ls_item TO <comp>.
        IF sy-subrc = 0.
          READ TABLE lt_cells INDEX lv_ci INTO lv_cellval.
          IF sy-subrc = 0.
            <comp> = lv_cellval.   " string -> component type (NUMC TU converts)
          ENDIF.
        ENDIF.
      ENDLOOP.
      " Screen column 11 "Partner" (UZ) is the BP of this row's party. It is a
      " read-only display the citizen never fills, so stamp it here from the
      " fixed row order: row 1 = Divorcer, row 2 = Divorcee.
      ls_item-zzafld0000uz = COND #( WHEN lv_row = 1 THEN ls_partners-divorcer_bp
      ELSE ls_partners-divorcee_bp ).
      APPEND ls_item TO lt_item_ext1.
    ENDLOOP.

    CALL FUNCTION 'ZFM_ECC_WDA_CREATE_REQUEST'
      EXPORTING
        partners     = ls_partners
        header       = ls_header
        header_ext   = ls_header_ext
        item_ext1    = lt_item_ext1
      TABLES
        t_bapireturn = lt_bapireturn.

    " any 'Error' row and keeps the citizen on the page).
    "   Origin: VIEW_MAIN->DISPLAY_ERROR_MESSAGES — the FM often returns a row
    " with MESSAGE blank but ID, NUMBER and MESSAGE_V1..V4 filled, so the text
    " has to be built from the T100 entry. The WD does this with
    " MESSAGE_TEXT_BUILD; T100_TEXT( ) reaches the same text through
    " FORMAT_MESSAGE with lang = sy-langu. Appending the raw MESSAGE without
    " this produced an error strip with nothing in it, which blocks the citizen
    " on the page with no way to know what the backend rejected.
    " Last resort if even the T100 lookup comes back empty: say something
    " rather than block behind an empty strip, and name the id/number so the
    " failure is traceable in support.
    LOOP AT lt_bapireturn INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      DATA(lv_rtxt) = CONV string( ls_ret-message ).
      IF lv_rtxt IS INITIAL.
        lv_rtxt = t100_text( iv_id = ls_ret-id
                             iv_no = ls_ret-number
                             iv_v1 = ls_ret-message_v1
                             iv_v2 = ls_ret-message_v2
                             iv_v3 = ls_ret-message_v3
                             iv_v4 = ls_ret-message_v4 ).
      ENDIF.
      IF lv_rtxt IS INITIAL.
        lv_rtxt = COND string(
        WHEN sy-langu = 'A'
        THEN |تعذر إنشاء الطلب. رمز الخطأ { ls_ret-id } { ls_ret-number }|
        ELSE |The request could not be created. Error code { ls_ret-id } { ls_ret-number }| ).
      ENDIF.
      APPEND VALUE #( type = 'Error' text = lv_rtxt ) TO rt.
    ENDLOOP.
    IF line_exists( rt[ type = 'Error' ] ).
      RETURN.
    ENDIF.

    " On success the new service id is returned in the 'S' row's MESSAGE_V1;
    " MESSAGE_V2 is the service GUID passed to ZFM_WDA_CREATE_AI_ATTACHMENT_U.
    READ TABLE lt_bapireturn INTO DATA(ls_ok) WITH KEY type = 'S'.
    IF sy-subrc = 0.
      DATA(lv_service_id) = ls_ok-message_v1.   " AS3 request number
      DATA(lv_guid)       = ls_ok-message_v2.    " GUID of the service — used for attachments
      " The engine owns the success screen and reads the number from here. There
      " is no confirmation STEP and no field for it, so set_reference( ) is the
      " only publication.
      io_ctx->set_reference( |{ lv_service_id }| ).

      " Origin: RFC_ATTACHEMNT_SUBMIT — attach the staged files to the new
      " Field map QNV (/QNV/SBUILD_ATTACHMENTS_ST) -> WD ls_attachments -> FM:
      DATA(lt_att) = io_ctx->get_attachment_files( ).
      DATA ls_att      TYPE /qnv/sbuild_attachments_st.
      DATA lv_mime     TYPE w3conttype.
      DATA lv_att_ext  TYPE c LENGTH 40.
      DATA lv_xcontent TYPE xstring.
      LOOP AT lt_att INTO ls_att.
        lv_mime = ls_att-file_mime.
        IF lv_mime IS INITIAL AND ls_att-file_name IS NOT INITIAL.
          CLEAR lv_att_ext.
          CALL FUNCTION 'TRINT_FILE_GET_EXTENSION'
            EXPORTING
              filename  = ls_att-file_name
              uppercase = 'X'
            IMPORTING
              extension = lv_att_ext.
          CALL FUNCTION 'SDOK_MIMETYPE_GET'
            EXPORTING
              extension = lv_att_ext
            IMPORTING
              mimetype  = lv_mime.
        ENDIF.

        " FILE_CONTENT arrives as a base64 data URL ('data:<mime>;base64,<payload>'),
        " and the FM wants raw XSTRING: drop the prefix before the comma, then
        " base64-decode the payload.
        CLEAR lv_xcontent.
        TRY.
            SPLIT ls_att-file_content AT ',' INTO DATA(lv_prefix) DATA(lv_payload).
            CALL FUNCTION 'SCMS_BASE64_DECODE_STR'
              EXPORTING
                input  = lv_payload
              IMPORTING
                output = lv_xcontent.
          CATCH cx_bcs INTO DATA(lx_bcs).
            APPEND VALUE #( type = 'Error'
            text = |{ ls_att-file_name }: { lx_bcs->get_text( ) }| ) TO rt.
            CONTINUE.
        ENDTRY.

        CALL FUNCTION 'ZFM_WDA_CREATE_AI_ATTACHMENT_U'
          EXPORTING
            guid         = CONV scmg_case_guid( lv_guid )
            filename     = CONV string( ls_att-identifier1 )
            file_descr   = CONV string( ls_att-file_name )
            filecontent  = lv_xcontent
            filemimetype = CONV string( lv_mime )
            langu        = sy-langu
            sap_object   = 'BUS2000116'.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP.
*&---------------------------------------------------------------------*
*& ON_VALUE_HELP — domain-backed dropdowns (open-q#5: options_from_domain)
*& Folds fill_dropdown_service / _wife_status / _divorce_type / _doc_type
*& and the bundled fill_dropdown_all. One WHEN per SELECT field; the DDIC
*& domain + meaning is kept as an inline comment.
*&---------------------------------------------------------------------*

    CASE iv_field.
      WHEN 'FAM_GUIDANCE_APPR'.
        rt = options_from_domain( 'ZADTEL0001TL' ).              " Family guidance approval
      WHEN 'MARR_GRANT_RECEIVED'.
        rt = options_from_domain( 'ZADTEL0001TM' ).              " Marriage grant
      WHEN 'DIV_DECL_TYPE'.
        rt = options_from_domain( 'ZADTEL0001TN' ).              " Type of divorce declaration
      WHEN 'DIV_TYPE'.
        rt = options_from_domain( 'ZADTEL0001TO' ).              " Type of divorce
      WHEN 'DIV_APPLICANT'.
        rt = options_from_domain( 'ZADTEL0001TP' ).              " Divorce applicant
      WHEN 'DIV_METHOD'.
        rt = options_from_domain( 'ZADTEL0001TQ' ).              " Method of divorce
      WHEN 'DIV_REASON'.
        rt = options_from_domain( 'ZADTEL0001TR' ).              " Divorce reason
      WHEN 'RELATIVE_RELATION'.
        rt = options_from_domain( 'ZADTEL0001T4' ).              " Relative relation
      WHEN 'STATUS_UPON_MARR'.
        rt = options_from_domain( 'ZADTEL0001TS' ).              " Status of divorced upon marriage
      WHEN 'CASE_UPON_DIVORCE'.
        rt = options_from_domain( 'ZADTEL0001TT' ).              " Divorced case upon divorce
      WHEN 'MARR_CONSUMMATED'.
        rt = options_from_domain( 'ZADTEL0001TU' ).              " Marriage consummated
      WHEN 'ISOLATION'.
        rt = options_from_domain( 'ZADTEL0001TV' ).              " Isolation
      WHEN 'EARLIER_MARRIAGES'.
        rt = options_from_domain( 'ZADTEL0001TW' ).              " Earlier marriages

      WHEN 'DOCUMENT_TYPE'.
        "   Origin: VIEW_ADD_ATTACHMENT->FILL_DROPDOWN_DOC_TYPE
        " through FM ZFM_ECC_WDA_ATT_DDLB_VALUE (open-q#3). The WD also hid
        DATA lt_attach TYPE zatt_docu_type_1.
        CALL FUNCTION 'ZFM_ECC_WDA_ATT_DDLB_VALUE'
          EXPORTING
            iv_attach        = c_att_key     " AD01 — fixed value, no per-service mapping
            iv_langu         = sy-langu
          TABLES
            et_document_type = lt_attach.
        LOOP AT lt_attach INTO DATA(ls_attach).
          APPEND VALUE #( key = ls_attach-id text = ls_attach-descrption ) TO rt.
        ENDLOOP.

        " the grid column spec carries the domain in its 'src' the engine
      WHEN 'PERS_INFO.ZZAFLD0000TT'.
        rt = options_from_domain( 'ZADTEL0001S2' ).              " Residence status
      WHEN 'PERS_INFO.ZZAFLD0000TV'.
        rt = options_from_domain( 'ZADTEL0001S4' ).              " Doctrine
      WHEN 'PERS_INFO.ZZAFLD0000TW'.
        rt = options_from_domain( 'ZADTEL0001S5' ).              " Job status
      WHEN 'PERS_INFO.ZZAFLD0000TX'.
        rt = options_from_domain( 'ZADTEL0001S6' ).              " Main profession
      WHEN 'PERS_INFO.ZZAFLD0000TZ'.
        rt = options_from_domain( 'ZADTEL0001S8' ).              " Employer Emirate
      WHEN 'PERS_INFO.ZZAFLD0000V2'.
*       Read-only, so this is never a dropdown the citizen opens: RENDER_GRID
*       asks for the options to resolve each row's stored key to its label.
        rt = party_type_opts( ).                                 " Partner type

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
