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

    CONSTANTS c_ev_go  TYPE string VALUE 'BPP_SEARCH'.
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
                is_search  TYPE zcl_rak_bp_search=>ty_req OPTIONAL.

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
    rv = pick( is_bp    = is_bp
               iv_names = 'ENGLISH_FULL_NAME,ARABIC_FULL_NAME,' &&
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
      lo_body->title( text  = zcl_rak_journey_util=>esc( mo_ctx->get_val( fld( 'NAME' ) ) )
                      level = 'H4' ).
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
    DATA(lv_by) = mo_ctx->get_val( fld( 'SEARCHBY' ) ).

    DATA(lo_form) = lo_dlg->content(
      )->simple_form( editable  = abap_true
                      layout    = 'ResponsiveGridLayout'
                      columnsxl = '2' columnsl = '2' columnsm = '1'
      )->content( ns = 'form' ).

    lo_form->label( t( iv_no = zcl_rak_text=>c_no-bpp_search_by iv_default = 'Search By' ) ).
    DATA(lo_by) = lo_form->combobox( selectedkey = mo_ctx->bind( fld( 'SEARCHBY' ) )
                                     change      = mo_ctx->event( c_ev_go ) ).
    lo_by->item( key = c_eid  text = t( iv_no = zcl_rak_text=>c_no-bpp_eid iv_default = 'Emirates ID' ) ).
    lo_by->item( key = c_pass
      text = t( iv_no = zcl_rak_text=>c_no-bpp_passport_ne iv_default = 'Passport (Non EID Holder only)' ) ).
    lo_by->item( key = c_unif
      text = t( iv_no = zcl_rak_text=>c_no-bpp_unified_ne iv_default = 'Unified ID (Non EID Holder only)' ) ).
    lo_by->item( key = c_tlic
      text = t( iv_no = zcl_rak_text=>c_no-bpp_trade_lic iv_default = 'Trade License Number' ) ).

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
    lo_form->label( SWITCH string( lv_by
      WHEN c_eid  THEN t( iv_no = zcl_rak_text=>c_no-bpp_eid         iv_default = 'Emirates ID' )
      WHEN c_pass THEN t( iv_no = zcl_rak_text=>c_no-bpp_passport_no iv_default = 'Passport Number' )
      WHEN c_unif THEN t( iv_no = zcl_rak_text=>c_no-bpp_unified_id  iv_default = 'Unified ID' )
      ELSE             t( iv_no = zcl_rak_text=>c_no-bpp_trade_lic   iv_default = 'Trade License Number' ) ) ).
    lo_form->input( value = mo_ctx->bind( fld( 'IDNUM' ) ) ).

*   A trade licence is a company. It has no date of birth and no nationality, and
*   asking for them is how a form gets abandoned.
    IF lv_by <> c_tlic.
      lo_form->label( t( iv_no = zcl_rak_text=>c_no-bpp_dob iv_default = 'Date of Birth' ) ).
*     DDMMYYYY on screen, YYYYMMDD in the value. The MOI cross-check compares the
*     date sent against the date the BP holds as strings, so a display format
*     reaching the request would fail every comparison and read as a data
*     mismatch rather than a format one.
      lo_form->date_picker( value        = mo_ctx->bind( fld( 'DOB' ) )
                            displayformat = 'dd.MM.yyyy'
                            valueformat   = 'yyyyMMdd' ).

      lo_form->label( t( iv_no = zcl_rak_text=>c_no-bpp_nat iv_default = 'Nationality' ) ).
      DATA(lo_nat) = lo_form->combobox( selectedkey = mo_ctx->bind( fld( 'NAT' ) ) ).
      LOOP AT nationalities( ) INTO DATA(ls_n).
        lo_nat->item( key = ls_n-key text = ls_n-text ).
      ENDLOOP.
    ENDIF.

*   Passport type only for a passport. The domain has ten values and nine of them
*   are meaningless against any other ID.
    IF lv_by = c_pass.
      lo_form->label( t( iv_no = zcl_rak_text=>c_no-bpp_pass_type iv_default = 'Passport Type' ) ).
      DATA(lo_pt) = lo_form->combobox( selectedkey = mo_ctx->bind( fld( 'PPTYPE' ) ) ).
      LOOP AT doc_types( ) INTO DATA(ls_p).
        lo_pt->item( key = ls_p-key text = ls_p-text ).
      ENDLOOP.
    ENDIF.

    DATA(lo_btns) = lo_dlg->buttons( ).
    lo_btns->button( text  = t( iv_no = zcl_rak_text=>c_no-search iv_default = 'Search' )
                     type  = 'Emphasized'
                     icon  = 'sap-icon://search'
                     press = mo_ctx->event( c_ev_go ) ).
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
    io_box->title( text  = iv_title
                   level = 'H5'
                   class = 'sapUiSmallMarginTop sapUiTinyMarginBottom' ).
  ENDMETHOD.


  METHOD form_of.
    ro_frm = io_box->simple_form( editable  = abap_false
                                  layout    = 'ResponsiveGridLayout'
                                  columnsxl = '2' columnsl = '2' columnsm = '1'
                    )->content( ns = 'form' ).
  ENDMETHOD.


  METHOD pair.
    DATA(lv_val) = mo_ctx->get_val( fld( iv_suffix ) ).
    io_form->label( iv_label ).
    io_form->text( zcl_rak_journey_util=>esc(
      COND string( WHEN lv_val IS NOT INITIAL THEN lv_val ELSE `-` ) ) ).
  ENDMETHOD.


  METHOD set_detail.
*   One party attribute onto the scratch model. Blank is written as blank
*   rather than skipped, so a second search that finds a partner without a
*   passport does not leave the previous partner's passport on the screen.
    mo_ctx->set_val( iv_name  = fld( iv_suffix )
                     iv_value = pick( is_bp = is_bp iv_names = iv_names ) ).
  ENDMETHOD.
ENDCLASS.
