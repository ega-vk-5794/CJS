CLASS zcl_c061_judgement_publ_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS zif_rak_journey_logic~on_init
      REDEFINITION .
    METHODS zif_rak_journey_logic~on_change
      REDEFINITION .
    METHODS zif_rak_journey_logic~on_value_help
      REDEFINITION .
    METHODS zif_rak_journey_logic~on_popup_event
      REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_start
      REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_after_field
      REDEFINITION .
    METHODS zif_rak_journey_logic~render_field
      REDEFINITION .
    METHODS zif_rak_journey_logic~get_table
      REDEFINITION .
    METHODS zif_rak_journey_logic~wants_feedback
      REDEFINITION .

  PRIVATE SECTION.

*&---------------------------------------------------------------------*
*& ZCL_C061_JUDGEMENT_PUBL_LOGIC — Judgement Publications (JP1)
*&
*& Migrated from WebDynpro component ZWDC_ESERV_JUD_PUBL (application
*& ZWDA_ESERV_JUD_PUBL). Configuration lives in ZRAK_T_JNY* and is written
*& by ZRAK_C061_JUDG_PUBL_LOAD; this class holds the logic the WD's MAIN and
*& VIEW_CASE_DETAILS controllers had.
*&
*& The service searches PUBLISHED court judgments and displays one. It
*& creates nothing - no service request, no fee, no attachment - which is
*& why there is no ON_SUBMIT, no ON_BEFORE_POST and no payment step, and
*& why ON_INIT sets NO_SUBMIT.
*&
*& WD method -> here
*&   INIT_DROPDOWN_LOAD        on_value_help (CASE_TYPE / CASE_YEAR)
*&   ONACTIONSET_CASE_TYPE_DD  on_value_help (CASE_TYPE) + on_change
*&   ONACTIONSEARCH_CASE       do_search
*&   ONACTIONCLEAR_SEL_OPTION  do_clear
*&   INIT_ALV                  get_table              (see the note there)
*&   SET_VISIBILITY            io_ctx->set_hidden( 'JUD_LIST' )
*&   ONSRCH_LIST_CLICK         on_change( 'SEL_GUID' ) -> load_judgment
*&   FORMAT_HEAD_TXT_1 / _2    head_txt_1 / head_txt_2
*&   FORMAT_BP_DETAILS         party_block
*&   FORM_DISPLAY and
*&   ONACTIONADOBEFORM_DISPLAY open_pdf     (one copy, not two - see there)
*&   DISPLAY_MESSAGE           io_ctx->add_msg
*&
*& NO INSTANCE STATE, and the asymmetry behind that is worth stating
*& because it is not obvious. z2ui5 serializes the ENGINE between
*& round-trips, but only its DATA attributes - which is exactly why
*& ZCL_RAK_JOURNEY_ENGINE re-runs CREATE OBJECT MO_LOGIC whenever that
*& reference comes back empty. So:
*&
*&   engine data survives      MV_STEP (the wizard would reset otherwise),
*&                             MT_OVR - which is what makes
*&                             io_ctx->set_hidden( ) last "for the rest of
*&                             the session" - and the model itself
*&   this class does NOT       an attribute written on one click may be
*&                             gone by the next
*&
*& Everything the journey has to remember therefore lives in a MODEL
*& field, written with io_ctx->set_val( ) and declared HIDDEN on step SRCH
*& in the loader. That is why the search result is packed into JUD_ROWS
*& rather than held in a table here.
*&---------------------------------------------------------------------*

    TYPES tt_cfg  TYPE STANDARD TABLE OF zdt_ega_jud_publ WITH EMPTY KEY.
    TYPES tt_desc TYPE STANDARD TABLE OF scmgcasetypet WITH EMPTY KEY.

*   Court types (domain ZDO_COURT_TYPE). The party functions below hang off
*   these three values and nothing else, exactly as FORMAT_BP_DETAILS's
*   CASE did.
    CONSTANTS c_court_first  TYPE string VALUE 'YL001'.   " First instance
    CONSTANTS c_court_appeal TYPE string VALUE 'YL002'.   " Appeal
    CONSTANTS c_court_cass   TYPE string VALUE 'YL003'.   " Cassation

    CONSTANTS c_pf_claimant   TYPE string VALUE 'Y0000210'.
    CONSTANTS c_pf_respondent TYPE string VALUE 'Y0000100'.
    CONSTANTS c_pf_appellant  TYPE string VALUE 'Y0000366'.
    CONSTANTS c_pf_appell_ag  TYPE string VALUE 'Y0000367'.
    CONSTANTS c_pf_suprem_app TYPE string VALUE 'Y0000417'.
    CONSTANTS c_pf_suprem_ag  TYPE string VALUE 'Y0000418'.

    CONSTANTS c_dom_court    TYPE ddobjname VALUE 'ZDO_COURT_TYPE'.
    CONSTANTS c_dom_classify TYPE ddobjname VALUE 'ZDO_COURT_CLASSIFY_TYPE'.

*   The oldest year the service offers. INIT_DROPDOWN_LOAD counted down
*   WHILE lv_year > 2013, so 2014 is the last year in the list.
    CONSTANTS c_first_year TYPE i VALUE 2014.

*   How many result rows are rendered. THIS IS NEW, and it is not a limit
*   copied from the WD - the ALV held every row the search returned and
*   scrolled ten at a time. The engine's FTYPE 'TABLE' has no paging: it
*   emits one sap.m.ColumnListItem per row into the view XML, so a search
*   on Court Type and Year alone - which is all the two mandatory fields
*   demand - would put every judgment of that year on one page. The citizen
*   is TOLD when the cut bites and asked to narrow the search, which is the
*   honest version of a list that silently stops.
    CONSTANTS c_max_rows TYPE i VALUE 200.

*   Model fields. The first five are the citizen's search criteria; JUD_ROWS
*   and SEL_GUID carry the result and the picked row; the JD_* group is
*   where load_judgment( ) parks the document for render_field( ) to draw.
*   Step indices, as ZIF_RAK_JOURNEY~GET_STEP( ) reports them: zero-based,
*   in SEQNR order, so SRCH is 0 and JDGM is 1.
    CONSTANTS c_step_srch  TYPE i      VALUE 0.
    CONSTANTS c_f_court    TYPE string VALUE 'COURT_TYPE'.
    CONSTANTS c_f_classify TYPE string VALUE 'CLASSIFY_TYPE'.
    CONSTANTS c_f_casetype TYPE string VALUE 'CASE_TYPE'.
    CONSTANTS c_f_caseyear TYPE string VALUE 'CASE_YEAR'.
    CONSTANTS c_f_casenum  TYPE string VALUE 'CASE_NUMBER'.
    CONSTANTS c_f_list     TYPE string VALUE 'JUD_LIST'.
    CONSTANTS c_f_sel      TYPE string VALUE 'SEL_GUID'.
    CONSTANTS c_f_rows     TYPE string VALUE 'JUD_ROWS'.
    CONSTANTS c_f_jdcourt  TYPE string VALUE 'JD_COURT'.
    CONSTANTS c_f_title2   TYPE string VALUE 'JD_TITLE2'.
    CONSTANTS c_f_head1    TYPE string VALUE 'JD_HEAD1'.
    CONSTANTS c_f_head2    TYPE string VALUE 'JD_HEAD2'.
    CONSTANTS c_f_bp1l     TYPE string VALUE 'JD_BP1L'.
    CONSTANTS c_f_bp1v     TYPE string VALUE 'JD_BP1V'.
    CONSTANTS c_f_bp2l     TYPE string VALUE 'JD_BP2L'.
    CONSTANTS c_f_bp2v     TYPE string VALUE 'JD_BP2V'.
    CONSTANTS c_f_jdgl     TYPE string VALUE 'JD_JDGL'.
    CONSTANTS c_f_jdgv     TYPE string VALUE 'JD_JDGV'.
    CONSTANTS c_f_note     TYPE string VALUE 'JD_NOTE'.
    CONSTANTS c_f_judgment TYPE string VALUE 'JUDGMENT'.

*   Button events. They travel as HPOP_<id> and come back through
*   ON_POPUP_EVENT, which is the engine's one general-purpose button
*   channel - io_ctx->event( ) is not popup-only, it is simply named after
*   where it was first used. 'CLOSE' is reserved by the engine, which ends
*   the journey on it, so nothing here may be called that.
    CONSTANTS c_ev_search TYPE string VALUE 'JPSEARCH'.
    CONSTANTS c_ev_clear  TYPE string VALUE 'JPCLEAR'.
    CONSTANTS c_ev_pdf    TYPE string VALUE 'JPPDF'.

*   PACKING. JUD_ROWS holds the whole result as one string because the
*   model is the only store that survives a round-trip. Rows are separated
*   by NEWLINE and cells by '~': neither can occur in a cell, which is a
*   CHAR column, a formatted date or an integer.
*
*   SEVEN cells are packed and SIX are shown. The seventh is the case type,
*   which no column displays but load_judgment( ) needs to find the court
*   the picked case belongs to. Carrying it here is what lets a row click
*   cost one call to ZFM_JUDGEMENT_PUBLICATION instead of two.
    CONSTANTS c_cell_sep TYPE string VALUE '~'.
    CONSTANTS c_cells    TYPE i      VALUE 7.

*   The judgment screen's OTR ALIASES. Aliases, not concepts, so
*   SOTR_GET_TEXT_KEY can read them at runtime and the wording stays
*   single-sourced with the legacy screen - which is the rule this project
*   works to. otr( ) takes an English/Arabic pair as the fallback for a
*   missing alias, because SOTR_GET_TEXT_KEY answers one with BLANK and a
*   blank heading on a court judgment is worse than a hard-coded one.
    CONSTANTS c_a_head1 TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_HEADTXT_LINE_1'.
    CONSTANTS c_a_head2 TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_HEADTXT_LINE_2'.
    CONSTANTS c_a_head4 TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_HEADTXT_LINE_4'.
    CONSTANTS c_a_head5 TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_HEADTXT_LINE_5'.
    CONSTANTS c_a_claimant TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_CLAIMANT'.
    CONSTANTS c_a_respond TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_RESPONDENT'.
    CONSTANTS c_a_appellant TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_APPELLANT'.
    CONSTANTS c_a_appell_ag TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_APPELL_AGAINST'.
    CONSTANTS c_a_apl_judg TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_APPEAL_JUDGMENT'.
    CONSTANTS c_a_apl_base TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_JUD_APPL_BASECAS'.
    CONSTANTS c_a_sup_appl TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_APPELLANT_SUPREM'.
    CONSTANTS c_a_sup_ag TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_APPELL_AGAINST_S'.
    CONSTANTS c_a_sup_judg TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_SUPREME_JUDGMENT'.
    CONSTANTS c_a_sup_base TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_JUD_SUPR_BASECAS'.
    CONSTANTS c_a_as_of TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_JUD_BASECAS_ASOF'.
    CONSTANTS c_a_verdict_ttl TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_VERDICT_TITLE'.
    CONSTANTS c_a_verdict_prv TYPE sotr_alias
      VALUE 'Z_RAKEGA_MUNI/ZEGA_CRM_JUDPUBLISH_VERDICT_PREVIEW'.

*   HEADTXT_LINE_3 is deliberately NOT in that list. Its OTR alias holds
*   Arabic in BOTH language columns, so reading it in English returns
*   Arabic - which is why the screenshot captioned "English" shows an
*   Arabic court name. The confirmed English is "Ras Al Khaimah Court", so
*   that one line comes from PICK( ) and not from the OTR.

    CONSTANTS c_form TYPE fpname VALUE 'ZAF_COURT_JUDGEMENT_PUBLICAT'.

*   A field's label as the citizen sees it, read from the configuration the
*   engine already resolved to the session language. Beats passing an
*   English/Arabic pair into every message helper: the label can then only
*   ever be the one printed above the control.
    METHODS fld_label
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_field  TYPE string
      RETURNING VALUE(rv) TYPE string.

*   One OTR alias in the ENGINE's resolved language, never SY-LANGU.
    METHODS otr
      IMPORTING iv_alias  TYPE sotr_alias
                iv_en     TYPE string
                iv_ar     TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS t100_text
      IMPORTING iv_id     TYPE symsgid
                iv_no     TYPE symsgno
      RETURNING VALUE(rv) TYPE string.

*   IV_LANGU is optional and blank means "the engine's resolved language",
*   which is what the search step wants. The JUDGMENT PAGE passes Arabic
*   explicitly - see the note on OTR( ). Without it the court name arrived in
*   the citizen's language and landed inside an Arabic sentence.
    METHODS dom_opts
      IMPORTING iv_domain TYPE ddobjname
                iv_langu  TYPE sylangu OPTIONAL
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

    METHODS dom_text
      IMPORTING iv_domain TYPE ddobjname
                iv_key    TYPE string
                iv_langu  TYPE sylangu OPTIONAL
      RETURNING VALUE(rv) TYPE string.

    METHODS jud_cfg
      RETURNING VALUE(rt) TYPE tt_cfg.

    METHODS case_desc
      RETURNING VALUE(rt) TYPE tt_desc.

    METHODS case_type_opts
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

    METHODS year_opts
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

    METHODS case_range
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE zta_case_type_range.

    METHODS date_ext
      IMPORTING iv_date   TYPE d
      RETURNING VALUE(rv) TYPE string.

    METHODS text_lines
      IMPORTING iv_text   TYPE string
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

    METHODS row_cells
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_guid   TYPE string
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

    METHODS do_search
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS do_clear
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS load_judgment
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS head_txt_1
      IMPORTING iv_court_txt TYPE string
      RETURNING VALUE(rv)    TYPE string.

    METHODS head_txt_2
      IMPORTING iv_court_txt TYPE string
                iv_case_txt  TYPE string
                iv_jud_date  TYPE d
      RETURNING VALUE(rv)    TYPE string.

    METHODS party_block
      IMPORTING io_ctx       TYPE REF TO zif_rak_journey
                iv_court     TYPE string
                it_partner   TYPE ztt_judgement_publis_partner
                is_base_case TYPE zst_judgement_publis_base_case.

    METHODS partner_names
      IMPORTING it_partner TYPE ztt_judgement_publis_partner
                iv_fct     TYPE string
      RETURNING VALUE(rv)  TYPE string.

    METHODS base_case_text
      IMPORTING iv_head_alias TYPE sotr_alias
                iv_head_en    TYPE string
                iv_head_ar    TYPE string
                is_base_case  TYPE zst_judgement_publis_base_case
      RETURNING VALUE(rv)     TYPE string.

    METHODS log_view
      IMPORTING iv_guid      TYPE string
                iv_case_type TYPE string.

    METHODS open_pdf
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS pdf_failed
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

ENDCLASS.



CLASS zcl_c061_judgement_publ_logic IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.
*&---------------------------------------------------------------------*
*& on_init — once, at launch.
*&
*& NO_SUBMIT is the whole of it. The engine's footer draws Submit on the
*& last step unless this model value is 'X', in which case it draws Close.
*& A service that reads published judgments and creates nothing has nothing
*& to submit, and a Submit would run HANDLE_SUBMIT, VALIDATE_ALL and the
*& confirmation card for a request that does not exist.
*&
*& Nothing else is seeded. Court Type and Case Year are mandatory and start
*& EMPTY on purpose: INIT_DROPDOWN_LOAD has the one line that would have
*& defaulted the year commented out, and ONACTIONCLEAR_SEL_OPTION has the
*& same line commented out again, so the legacy screen deliberately made
*& the citizen choose.
*&---------------------------------------------------------------------*
    io_ctx->set_val( iv_name = 'NO_SUBMIT' iv_value = 'X' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~wants_feedback.
*&---------------------------------------------------------------------*
*& wants_feedback — no.
*& The base class says yes and the engine then draws the rating card once
*& the journey closes. It is declined here because the base ON_FEEDBACK is
*& empty and this class does not redefine it: the card would collect a
*& rating and a comment and drop both. Asking a citizen for feedback that
*& is thrown away is worse than not asking.
*&---------------------------------------------------------------------*
    rv = abap_false.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
*&---------------------------------------------------------------------*
*& on_value_help — the four dropdowns.
*&
*& The renderer asks here BEFORE it falls back to the DDIC resolver, and it
*& asks on every render. That second half is what makes the Case/File Type
*& list narrow itself the moment Court Type or Classification changes: the
*& WD needed ONACTIONSET_CASE_TYPE_DD to rebind a context node, and here
*& the list is simply recomputed from whatever the two fields now hold.
*&---------------------------------------------------------------------*
    CASE to_upper( iv_field ).
      WHEN c_f_court.
        rt = dom_opts( iv_domain = c_dom_court ).
      WHEN c_f_classify.
        rt = dom_opts( iv_domain = c_dom_classify ).
      WHEN c_f_casetype.
        rt = case_type_opts( io_ctx ).
      WHEN c_f_caseyear.
        rt = year_opts( ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*&---------------------------------------------------------------------*
*& on_change — two jobs.
*&
*& COURT_TYPE / CLASSIFY_TYPE: drop a Case/File Type the new filter no
*& longer offers. The list recomputes by itself (see on_value_help), but a
*& value already chosen would survive in the model and reach the search even
*& though the citizen can no longer see it in the dropdown - so the screen
*& and the search would disagree about what was asked for.
*&
*& SEL_GUID: a row was picked. The engine writes the row key into this
*& field and calls here, and that is the whole of the navigation - the
*& search step has no Next. Load the judgment, then ADVANCE_STEP( ).
*&---------------------------------------------------------------------*
    CASE to_upper( iv_field ).

      WHEN c_f_court OR c_f_classify.
        DATA(lv_ct) = io_ctx->get_val( c_f_casetype ).
        IF lv_ct IS NOT INITIAL.
          DATA(lt_opt) = case_type_opts( io_ctx ).
          IF NOT line_exists( lt_opt[ key = lv_ct ] ).
            io_ctx->set_val( iv_name = c_f_casetype iv_value = '' ).
          ENDIF.
        ENDIF.

      WHEN c_f_sel.
        IF io_ctx->get_val( c_f_sel ) IS NOT INITIAL.
          load_judgment( io_ctx ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
*&---------------------------------------------------------------------*
*& on_render_start — forget the picked row while the search step is drawn.
*&
*& THE ROW STOPS BEING CLICKABLE AFTER BACK, and this is the whole of it.
*& RENDER_BLOCK( ) decides per row whether to draw a Select BUTTON or a
*& "Selected" OBJECT_STATUS, on LV_SEL = ( VAL_GET( <default_val> ) =
*& row key ) - and the object_status has no PRESS. So once SEL_GUID holds
*& the GUID of the row the citizen opened, coming Back leaves that row
*& showing a status with nothing behind it: it looks answered, it looks
*& clickable, and it does nothing. Every OTHER row still works, which is
*& what makes it read as a broken button rather than as a selection.
*&
*& Clearing SEL_GUID on the way back in restores the button and makes the
*& next pick a real change. Guarded on the STEP so it only runs while SRCH
*& is the one being drawn: LOAD_JUDGMENT( ) sets SEL_GUID and immediately
*& ADVANCE_STEP( )s, so JDGM renders with the value intact and nothing here
*& touches it.
*&
*& Not in ON_CHANGE and not in DO_SEARCH: the citizen can also reach this
*& step by the footer Back, which raises neither.
*&---------------------------------------------------------------------*
    IF io_ctx->get_step( ) = c_step_srch
       AND io_ctx->get_val( c_f_sel ) IS NOT INITIAL.
      io_ctx->set_val( iv_name = c_f_sel iv_value = '' ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_after_field.
*&---------------------------------------------------------------------*
*& on_render_after_field — the buttons.
*&
*& Buttons are not field configuration: ZRAK_T_JNY_FLD has no button type,
*& so they are drawn here and wired with io_ctx->event( ).
*&
*& IO_VIEW is the field's OWN CELL and that cell is a vbox, so these
*& buttons stack UNDERNEATH their field rather than beside it. That is the
*& engine's layout, not a choice made here: only a cell whose FLOW flag is
*& set turns into a row, and FLOW lives in ZCL_RAK_CJ_LAY's Design tab
*& rather than in ZRAK_T_JNY_FLD. Turn FLOW on for the cell if they should
*& share a line with the field above them.
*&
*& THEY HANG OFF CASE_YEAR, NOT CASE_NUMBER. Both are in the second row, so
*& the choice is only which column the pair sits under - and under CASE_YEAR
*& they start at the left edge of the form, reading as a third row of their
*& own. Under CASE_NUMBER they sat mid-form under a field they have nothing
*& to do with. Same reason the WD put them at the end of the criteria block
*& rather than beside one criterion.
*&
*& Search takes its caption from the framework catalogue, which already
*& holds "Search" / "بحث" - the WD's own two texts. Clear has no catalogue
*& entry, so it is a PICK( ) pair read off the screenshots.
*&
*& BOTH BUTTONS CARRY THE ACCENT TYPE. Clear was 'Transparent', which is the
*& sap.m default for a secondary action and renders as plain text - on this
*& screen it read as a link rather than a button next to an Emphasized
*& Search. The WD drew both as buttons of equal weight, so they match here.
*&---------------------------------------------------------------------*
    CASE to_upper( is_field-name ).

      WHEN c_f_caseyear.
        DATA(lo_btn) = io_view->hbox( alignitems = 'End' class = 'sapUiSmallMarginTop' ).
        lo_btn->button(
          text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-search iv_default = 'Search' )
          icon  = 'sap-icon://search'
          type  = 'Emphasized'
          press = io_ctx->event( c_ev_search ) ).
        lo_btn->button(
          text  = zcl_rak_text=>pick( iv_base = `Clear` iv_ar = |مسح| )
          icon  = 'sap-icon://clear-all'
          type  = 'Emphasized'
          class = 'sapUiTinyMarginBegin'
          press = io_ctx->event( c_ev_clear ) ).

      WHEN c_f_judgment.
*       The WD had two identical copies of the PDF action - FORM_DISPLAY on
*       MAIN and ONACTIONADOBEFORM_DISPLAY on VIEW_CASE_DETAILS, the same
*       eighty lines twice, with the MAIN one already commented out at its
*       only call site. Only one is migrated.
*       ARABIC CAPTION, like the page it sits on. The WD's own button read
*       "نسخة العرض" whatever the logon language.
        io_view->button(
          text  = |نسخة العرض|
          icon  = 'sap-icon://pdf-attachment'
          type  = 'Emphasized'
          class = 'sapUiSmallMarginTop'
          press = io_ctx->event( c_ev_pdf ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
*&---------------------------------------------------------------------*
*& on_popup_event — the three buttons above.
*& OTHERS chains the superclass, which owns the payment events. This
*& journey has no payment step so that chain is inert here, but dropping
*& it would be a trap for whoever copies this class next.
*&---------------------------------------------------------------------*
    CASE iv_event.
      WHEN c_ev_search.
        do_search( io_ctx ).
      WHEN c_ev_clear.
        do_clear( io_ctx ).
      WHEN c_ev_pdf.
        open_pdf( io_ctx ).
      WHEN OTHERS.
        super->zif_rak_journey_logic~on_popup_event(
          io_ctx = io_ctx iv_id = iv_id iv_event = iv_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
*&---------------------------------------------------------------------*
*& get_table — the result list's columns and rows.
*&
*& WHY THE COLUMNS ARE HERE AND NOT IN CONFIGURATION. The WD read
*& ZDT_EGA_CRMCSDIS for USER_TYPE 'JUDPUB' / ALV_NAME 'JUDPUBLST' and used
*& it to set each ALV column's position, width, header OTR alias and
*& cell-editor flags, hiding every column the table did not list. Not one
*& of those has a target in the engine's FTYPE 'TABLE': it draws one
*& sap.m.Column per entry in RS-COLUMNS, in that order, with no width and
*& no per-column editor. So that table is not read - reading it could not
*& change anything - and the six columns the live screen shows are declared
*& here instead.
*&
*& The headers are BILINGUAL, which is the one thing this route buys that
*& configuration cannot: a TABLE column header written into DEFAULT_VAL has
*& no Arabic twin, and the CRMCSDIS OTR aliases resolve to Arabic only
*& because the WD passed LANGUAGE = 'A' everywhere - which is why the
*& English screenshot has Arabic headers. The Arabic below is verbatim from
*& the live screen; the English is new, because the legacy screen had none.
*&
*& COLUMN 1 IS THE CASE GUID AND ITS HEADER IS '-'. Both halves matter. The
*& renderer takes a picked row's key from the row's FIRST CELL, and it
*& hides any column whose header is blank or '-'. So the key the ROWPICK
*& event needs is present and the citizen never sees it.
*&
*& THE WD's SIXTH COLUMN IS NOT HERE. It held the literal 'نص الحكم' and
*& was configured as a link that opened the judgment. The engine draws that
*& affordance itself - a trailing Select button on every row, because the
*& field's DEFAULT_VAL names a pick target - so carrying the column too
*& would put a dead label beside a live button.
*&---------------------------------------------------------------------*
    IF to_upper( iv_name ) <> c_f_list.
      RETURN.
    ENDIF.

    rs_data-columns = VALUE zif_rak_journey=>tt_string(
      ( `-` )
      ( zcl_rak_text=>pick( iv_base = `Case No.`          iv_ar = |رقم القضية| ) )
      ( zcl_rak_text=>pick( iv_base = `Court`             iv_ar = |المحكمة| ) )
      ( zcl_rak_text=>pick( iv_base = `Registration Date` iv_ar = |تاريخ التسجيل| ) )
      ( zcl_rak_text=>pick( iv_base = `Judgment Date`     iv_ar = |تاريخ الحكم| ) )
      ( zcl_rak_text=>pick( iv_base = `Litigation Period` iv_ar = |مدة التقاضي| ) ) ).

    DATA lt_cell  TYPE zif_rak_journey=>tt_string.
    DATA lt_show  TYPE zif_rak_journey=>tt_string.
    DATA lv_one   TYPE string.
    DATA lv_ix    TYPE i.
    DATA lv_shown TYPE i.

    DATA(lt_packed) = text_lines( io_ctx->get_val( c_f_rows ) ).
    LOOP AT lt_packed INTO DATA(lv_packed).
      CLEAR: lt_cell, lt_show.
      SPLIT lv_packed AT c_cell_sep INTO TABLE lt_cell.
*     A row that does not carry all seven packed cells is dropped rather
*     than padded. The renderer hides column 1 BY POSITION and refuses to
*     hide anything at all once the rows stop agreeing on their width, so
*     one short row would expose every case GUID on the page.
      IF lines( lt_cell ) <> c_cells.
        CONTINUE.
      ENDIF.
*     Six of the seven. The seventh is the case type, which load_judgment( )
*     needs and no column shows.
      lv_shown = lines( rs_data-columns ).
      lv_ix    = 1.
      WHILE lv_ix <= lv_shown.
        READ TABLE lt_cell INTO lv_one INDEX lv_ix.
        APPEND lv_one TO lt_show.
        lv_ix = lv_ix + 1.
      ENDWHILE.
      APPEND lt_show TO rs_data-rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
*&---------------------------------------------------------------------*
*& render_field — the judgment, drawn the way VIEW_CASE_DETAILS drew it:
*& two centred header blocks, the parties, the underlined verdict title,
*& then the body.
*&
*& This hook is reached because JUDGMENT is FTYPE 'DISPLAY'. Had it been a
*& block type - TABLE, PDF, REQPANEL - the renderer would have gone through
*& RENDER_BLOCK( ) and never called here at all. That is also why the
*& result list cannot be drawn this way and goes through GET_TABLE( ).
*&
*& ONE CONTROL PER LINE rather than one control holding the newlines. The
*& WD used a TextView per block and let the newlines inside it break the
*& lines; sap.m.Text only honours them when RENDERWHITESPACE is set, and
*& each of these lines has to be centred in its own right anyway.
*&---------------------------------------------------------------------*
    IF to_upper( is_field-name ) <> c_f_judgment.
*     Chained rather than returned blank. The base RENDER_FIELD draws the
*     payment card for the PAYFEE field; this journey has none, so the call
*     is inert today, but a copy of this class that grows a payment step
*     would otherwise lose its fee card with nothing to say why.
      rv_done = super->zif_rak_journey_logic~render_field(
                  io_ctx = io_ctx io_form = io_form is_field = is_field ).
      RETURN.
    ENDIF.
    rv_done = abap_true.

    DATA(lo_doc) = io_form->vbox( class = 'sapUiSmallMargin' width = '100%' ).

*   Header block 1 - the three OTR lines with the court on the third.
    DATA(lt_h1) = text_lines( io_ctx->get_val( c_f_head1 ) ).
    LOOP AT lt_h1 INTO DATA(lv_h1).
      lo_doc->text( text      = zcl_rak_journey_util=>esc( lv_h1 )
                    textalign = 'Center'
                    width     = '100%'
                    class     = 'sapUiTinyMarginBottom' ).
    ENDLOOP.

*   Header block 2 - the hearing line and the case line.
    DATA(lt_h2) = text_lines( io_ctx->get_val( c_f_head2 ) ).
    IF lt_h2 IS NOT INITIAL.
      DATA(lo_b2) = lo_doc->vbox( class = 'sapUiMediumMarginTop' width = '100%' ).
      LOOP AT lt_h2 INTO DATA(lv_h2).
        lo_b2->text( text      = zcl_rak_journey_util=>esc( lv_h2 )
                     textalign = 'Center'
                     width     = '100%'
                     class     = 'sapUiTinyMarginBottom' ).
      ENDLOOP.
    ENDIF.

*   The parties, and on appeal and cassation the judgment being contested.
    DATA(lo_pty) = lo_doc->vbox( class = 'sapUiMediumMarginTop' width = '100%' ).

    DATA(lv_l1) = io_ctx->get_val( c_f_bp1l ).
    IF lv_l1 IS NOT INITIAL.
      DATA(lo_p1) = lo_pty->hbox( alignitems = 'Start' class = 'sapUiTinyMarginBottom' ).
      lo_p1->label( text = zcl_rak_journey_util=>esc( lv_l1 ) ).
      DATA(lo_v1) = lo_p1->vbox( class = 'sapUiSmallMarginBegin' ).
      DATA(lt_v1) = text_lines( io_ctx->get_val( c_f_bp1v ) ).
      LOOP AT lt_v1 INTO DATA(lv_v1).
        lo_v1->text( zcl_rak_journey_util=>esc( lv_v1 ) ).
      ENDLOOP.
    ENDIF.

    DATA(lv_l2) = io_ctx->get_val( c_f_bp2l ).
    IF lv_l2 IS NOT INITIAL.
      DATA(lo_p2) = lo_pty->hbox( alignitems = 'Start' class = 'sapUiTinyMarginBottom' ).
      lo_p2->label( text = zcl_rak_journey_util=>esc( lv_l2 ) ).
      DATA(lo_v2) = lo_p2->vbox( class = 'sapUiSmallMarginBegin' ).
      DATA(lt_v2) = text_lines( io_ctx->get_val( c_f_bp2v ) ).
      LOOP AT lt_v2 INTO DATA(lv_v2).
        lo_v2->text( zcl_rak_journey_util=>esc( lv_v2 ) ).
      ENDLOOP.
    ENDIF.

*   BP_INFO-JUDGMENT_VISIBLE in the WD: '01' on first instance, which hid
*   this block, '02' on appeal and cassation. Here the label being empty is
*   the same signal - PARTY_BLOCK( ) only fills it on the two court types
*   that have a contested judgment.
    DATA(lv_lj) = io_ctx->get_val( c_f_jdgl ).
    IF lv_lj IS NOT INITIAL.
      DATA(lo_pj) = lo_pty->hbox( alignitems = 'Start' class = 'sapUiTinyMarginBottom' ).
      lo_pj->label( text = zcl_rak_journey_util=>esc( lv_lj ) ).
      DATA(lo_vj) = lo_pj->vbox( class = 'sapUiSmallMarginBegin' ).
      DATA(lt_vj) = text_lines( io_ctx->get_val( c_f_jdgv ) ).
      LOOP AT lt_vj INTO DATA(lv_vj).
        lo_vj->text( zcl_rak_journey_util=>esc( lv_vj ) ).
      ENDLOOP.
    ENDIF.

*   "Made the following judgment", centred, then the body.
    DATA(lv_t2) = io_ctx->get_val( c_f_title2 ).
    IF lv_t2 IS NOT INITIAL.
      lo_doc->title( text      = zcl_rak_journey_util=>esc( lv_t2 )
                     level     = 'H4'
                     textalign = 'Center'
                     width     = '100%'
                     class     = 'sapUiMediumMarginTop sapUiSmallMarginBottom' ).
    ENDIF.

    DATA(lt_body) = text_lines( io_ctx->get_val( c_f_note ) ).
    DATA(lo_body) = lo_doc->vbox( width = '100%' ).
    LOOP AT lt_body INTO DATA(lv_body).
      lo_body->text( text  = zcl_rak_journey_util=>esc( lv_body )
                     width = '100%' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD do_search.
*&---------------------------------------------------------------------*
*& do_search — ONACTIONSEARCH_CASE.
*&
*& THE MANDATORY CHECK IS OURS, not the engine's. MISSING_REQUIRED runs
*& from COMMIT_STEP( ), which is what Next calls, and this step has no
*& Next - the second step is a result step, so the footer suppresses it.
*& The Search button is therefore the only gate, exactly as the WD's
*& CHECK_MANDATORY_ATTR_ON_VIEW was. The wording comes from the framework
*& catalogue (C_NO-REQUIRED, "&1 is required" / "&1 مطلوب") so it reads
*& like every other required message in CJS.
*&---------------------------------------------------------------------*
    DATA(lv_court) = io_ctx->get_val( c_f_court ).
    DATA(lv_year)  = io_ctx->get_val( c_f_caseyear ).
    DATA(lv_bad)   = abap_false.

    IF lv_court IS INITIAL.
      io_ctx->add_msg(
        iv_type = 'Error'
        iv_text = zcl_rak_text=>get(
                    iv_no      = zcl_rak_text=>c_no-required
                    iv_default = 'Court Type is required'
                    iv_v1      = fld_label( io_ctx = io_ctx iv_field = c_f_court ) ) ).
      lv_bad = abap_true.
    ENDIF.
    IF lv_year IS INITIAL.
      io_ctx->add_msg(
        iv_type = 'Error'
        iv_text = zcl_rak_text=>get(
                    iv_no      = zcl_rak_text=>c_no-required
                    iv_default = 'Case Year is required'
                    iv_v1      = fld_label( io_ctx = io_ctx iv_field = c_f_caseyear ) ) ).
      lv_bad = abap_true.
    ENDIF.
    IF lv_bad = abap_true.
      RETURN.
    ENDIF.

*   NO TYPED-VALUE GUARD HERE ANY MORE. An OPT_REJECT( ) used to refuse any
*   value that was not one of the options this handler had offered, because
*   CLOSED_LIST was held back by engine point R7-1 and a sap.m.ComboBox is
*   typable - so CASE_YEAR could reach the ZADTEL00008R local below as 'abcd'.
*   R7-1 is closed and CLOSED_LIST is set on all four dropdowns in the loader,
*   so a sap.m.Select is the only control drawn and there is nothing to type
*   into. Put the guard back if CLOSED_LIST is ever taken off again.

    DATA lv_num TYPE zadtel00008n.
    DATA lv_yr  TYPE zadtel00008r.
    DATA lt_jdg TYPE zfm_judgement_publisher_t.

    lv_num = io_ctx->get_val( c_f_casenum ).
    lv_yr  = lv_year.

    DATA(lt_range) = case_range( io_ctx ).
    DATA(lv_lang)  = zcl_rak_text=>lang( ).

*   A LOCAL CALL, and the same is true of the other two function modules in
*   this class. The WD passed DESTINATION, resolved through
*   ZFKK_RFC_DETERMINATION; CJS runs on the system that owns this data, so
*   there is no RFC scenario and both are dropped. The wd2class skill states
*   that as a rule and its generator strips them, so reintroducing them here
*   would be a defect rather than fidelity to the source.
*
*   Two consequences worth spelling out. SYSTEM_FAILURE and
*   COMMUNICATION_FAILURE must NOT be declared: they are implicit only on a
*   call WITH DESTINATION, and on a local call the syntax check rejects an
*   exception that is not in the FM's interface. And a class-based exception
*   raised inside the FM does propagate to the caller, which is what the TRY
*   is for - on an RFC call it would not have.
    TRY.
        CALL FUNCTION 'ZFM_JUDGEMENT_PUBLICATION'
          EXPORTING
            iv_case_number = lv_num
            iv_case_year   = lv_yr
            iv_case_type   = lt_range
            iv_langu       = lv_lang
          IMPORTING
            et_zjdg        = lt_jdg.
      CATCH cx_root INTO DATA(lx_srch).
        io_ctx->add_msg( iv_type = 'Error' iv_text = lx_srch->get_text( ) ).
        RETURN.
    ENDTRY.

*   LANGUAGE FALLBACK, and only where it is unambiguous. CASE_TEXT is the
*   composed "437 / 2026 تجاري يومي" the first column shows, and IV_LANGU
*   decides the case-type half of it. The WD asked for Arabic
*   unconditionally, so whether CRM holds an English text at all is
*   unverified. Asking in the citizen's language is the right thing to try;
*   a page of blank case numbers is not an acceptable way to discover it
*   was not there, so if EVERY row came back without one, ask again in
*   Arabic. An EMPTY result is never retried - no rows is a real answer,
*   not a language problem.
    IF lt_jdg IS NOT INITIAL AND lv_lang <> zcl_rak_text=>c_langu_ar.
      DATA(lv_any) = abap_false.
      LOOP AT lt_jdg INTO DATA(ls_probe).
        IF ls_probe-case_text IS NOT INITIAL.
          lv_any = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_any = abap_false.
        TRY.
            CALL FUNCTION 'ZFM_JUDGEMENT_PUBLICATION'
              EXPORTING
                iv_case_number = lv_num
                iv_case_year   = lv_yr
                iv_case_type   = lt_range
                iv_langu       = zcl_rak_text=>c_langu_ar
              IMPORTING
                et_zjdg        = lt_jdg.
          CATCH cx_root.
*           The Arabic retry is a best effort on top of a call that already
*           succeeded, so a failure here leaves the English rows standing
*           rather than throwing away a result the citizen can use.
        ENDTRY.
      ENDIF.
    ENDIF.

    io_ctx->set_val( iv_name = c_f_sel  iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_rows iv_value = '' ).

    IF lt_jdg IS INITIAL.
*     The WD's own no-results message, read from T100 the way it read it:
*     EI 057, built with MESSAGE_TEXT_BUILD there and FORMAT_MESSAGE here.
*     The message exists in both languages - confirmed - but T100 rows are
*     per language and FORMAT_MESSAGE answers a missing one with BLANK
*     rather than an exception, so the fallback stays: an error strip with
*     no text blocks the citizen with nothing on screen to explain it. It
*     carries the SAME wording as the T100 row, so a gap in one language
*     cannot produce a differently worded error from the other.
      io_ctx->set_hidden( iv_field = c_f_list iv_on = abap_true ).
      DATA(lv_none) = t100_text( iv_id = 'EI' iv_no = '057' ).
      IF lv_none IS INITIAL.
        lv_none = zcl_rak_text=>pick(
                    iv_base = `No data was found for the selection criteria`
                    iv_ar   = |لم يتم العثور على أي بيانات توافق معايير التحديد| ).
      ENDIF.
      io_ctx->add_msg( iv_type = 'Error' iv_text = lv_none ).
      RETURN.
    ENDIF.

*   Pack the rows. The court text is resolved through ZDT_EGA_JUD_PUBL
*   exactly as the WD resolved it: ET_ZJDG carries the case type, the
*   config table maps that to a court type, and the domain supplies the
*   text. AGE is the WD's own arithmetic - judgment date minus registration
*   date plus one - but only when BOTH dates are filled: on one missing
*   date the subtraction produces a six-digit number, which the WD would
*   have printed as the litigation period.
    DATA(lt_cfg)  = jud_cfg( ).
    DATA lv_rows  TYPE string.
    DATA lv_count TYPE i.
    DATA lv_age   TYPE i.
    DATA(lv_cut)  = abap_false.

    LOOP AT lt_jdg INTO DATA(ls_jdg).
      IF lv_count >= c_max_rows.
        lv_cut = abap_true.
        EXIT.
      ENDIF.

      DATA(lv_court_txt) = ``.
      READ TABLE lt_cfg INTO DATA(ls_map) WITH KEY case_type = ls_jdg-case_type.
      IF sy-subrc = 0.
        lv_court_txt = dom_text( iv_domain = c_dom_court
                                 iv_key    = CONV string( ls_map-court_type ) ).
      ENDIF.

      DATA(lv_age_txt) = ``.
      IF ls_jdg-zzafld00005j IS NOT INITIAL AND ls_jdg-zzafld000073 IS NOT INITIAL.
        lv_age = ls_jdg-zzafld00005j - ls_jdg-zzafld000073 + 1.
        lv_age_txt = |{ lv_age }|.
      ENDIF.

      DATA(lv_line) = |{ ls_jdg-guid }{ c_cell_sep }{ ls_jdg-case_text }|
                   && |{ c_cell_sep }{ lv_court_txt }|
                   && |{ c_cell_sep }{ date_ext( ls_jdg-zzafld000073 ) }|
                   && |{ c_cell_sep }{ date_ext( ls_jdg-zzafld00005j ) }|
                   && |{ c_cell_sep }{ lv_age_txt }|
                   && |{ c_cell_sep }{ ls_jdg-case_type }|.

      IF lv_rows IS INITIAL.
        lv_rows = lv_line.
      ELSE.
        lv_rows = lv_rows && cl_abap_char_utilities=>newline && lv_line.
      ENDIF.
      lv_count = lv_count + 1.
    ENDLOOP.

    io_ctx->set_val( iv_name = c_f_rows iv_value = lv_rows ).
    io_ctx->set_hidden( iv_field = c_f_list iv_on = abap_false ).

    IF lv_cut = abap_true.
      io_ctx->add_msg(
        iv_type = 'Warning'
        iv_text = zcl_rak_text=>pick(
                    iv_base = |Only the first { c_max_rows } judgments are shown. | &&
                              |Add a Case/File Type or a Case/File No. to narrow the search.|
                    iv_ar   = |يتم عرض أول { c_max_rows } حكم فقط. | &&
                              |أضف نوع القضية أو رقم القضية لتضييق نطاق البحث.| ) ).
    ENDIF.
  ENDMETHOD.


  METHOD case_range.
*&---------------------------------------------------------------------*
*& case_range — IV_CASE_TYPE for ZFM_JUDGEMENT_PUBLICATION.
*&
*& One I EQ row for the chosen Case/File Type, or - when the citizen left
*& it blank - one row per ZDT_EGA_JUD_PUBL entry matching the Court Type
*& and Classification they did choose. The WD built the same range with a
*& dynamic WHERE (lv_query) over an in-memory copy of that table; a plain
*& IF over the same rows says it more directly and cannot be handed a
*& malformed condition.
*&---------------------------------------------------------------------*
    DATA ls_range TYPE zst_case_type_range.
    ls_range-sign   = 'I'.
    ls_range-option = 'EQ'.

    DATA(lv_ct) = io_ctx->get_val( c_f_casetype ).
    IF lv_ct IS NOT INITIAL.
      ls_range-low = lv_ct.
      APPEND ls_range TO rt.
      RETURN.
    ENDIF.

    DATA(lv_court) = io_ctx->get_val( c_f_court ).
    DATA(lv_class) = io_ctx->get_val( c_f_classify ).
    DATA(lt_cfg)   = jud_cfg( ).

    LOOP AT lt_cfg INTO DATA(ls_cfg).
      IF lv_court IS NOT INITIAL AND ls_cfg-court_type <> lv_court.
        CONTINUE.
      ENDIF.
      IF lv_class IS NOT INITIAL AND ls_cfg-classify_type <> lv_class.
        CONTINUE.
      ENDIF.
      ls_range-low = ls_cfg-case_type.
      APPEND ls_range TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD do_clear.
*&---------------------------------------------------------------------*
*& do_clear — ONACTIONCLEAR_SEL_OPTION. The five criteria, the packed
*& result and the picked row all go, and the list returns to hidden, which
*& is what SET_VISIBILITY( '01' ) did. The JD_* group is left alone
*& deliberately: nothing reads it while the citizen is on the search step,
*& and picking another row overwrites all of it at once.
*&---------------------------------------------------------------------*
    io_ctx->set_val( iv_name = c_f_court    iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_classify iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_casetype iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_caseyear iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_casenum  iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_rows     iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_sel      iv_value = '' ).
    io_ctx->set_hidden( iv_field = c_f_list iv_on = abap_true ).
  ENDMETHOD.


  METHOD row_cells.
*&---------------------------------------------------------------------*
*& row_cells — the packed cells of one result row, found by its GUID.
*& Empty when the row is not in JUD_ROWS, which can only happen if the
*& model was tampered with, so every caller has to cope with it.
*&---------------------------------------------------------------------*
    DATA lt_cell TYPE zif_rak_journey=>tt_string.

    DATA(lt_rows) = text_lines( io_ctx->get_val( c_f_rows ) ).
    LOOP AT lt_rows INTO DATA(lv_row).
      CLEAR lt_cell.
      SPLIT lv_row AT c_cell_sep INTO TABLE lt_cell.
      IF lines( lt_cell ) <> c_cells.
        CONTINUE.
      ENDIF.
      READ TABLE lt_cell INTO DATA(lv_first) INDEX 1.
      IF lv_first = iv_guid.
        rt = lt_cell.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_judgment.
*&---------------------------------------------------------------------*
*& load_judgment — ONSRCH_LIST_CLICK.
*&
*& Reads the judgment for the picked case, formats every block the display
*& step needs into the JD_* model fields, writes the view log, and advances
*& to that step.
*&
*& IV_LANGU IS 'A', and that is not an oversight carried over from the WD.
*& What comes back is the DOCUMENT - the ruling text, the parties' names,
*& the base case - and a court judgment exists in the language it was
*& handed down in. The labels around it do follow the citizen's language,
*& because those are ours: the head lines, the party captions and the
*& verdict title all come from OTR aliases read in the resolved language.
*& The result is a page whose furniture is bilingual and whose judgment is
*& in Arabic, which is the honest rendering of what exists.
*&
*& The case type and the case text come from the PACKED ROW rather than
*& from a second call to ZFM_JUDGEMENT_PUBLICATION - that is what the
*& seventh packed cell is for. ES_FORM does carry a case number, type and
*& year of its own, but not the COMPOSED "437 / 2026 تجاري يومي" the head
*& line prints and the result list shows, which is CASE_TEXT from the
*& search. Composing it here from three fields would risk formatting it
*& differently from the row the citizen just clicked.
*&---------------------------------------------------------------------*
    DATA(lv_guid) = io_ctx->get_val( c_f_sel ).

    DATA(lt_cell) = row_cells( io_ctx = io_ctx iv_guid = lv_guid ).
    IF lt_cell IS INITIAL.
      io_ctx->add_msg(
        iv_type = 'Error'
        iv_text = zcl_rak_text=>pick( iv_base = `That judgment is no longer in the result list.`
                                      iv_ar   = |هذا الحكم لم يعد ضمن نتائج البحث.| ) ).
      RETURN.
    ENDIF.
    DATA(lv_case_txt)  = lt_cell[ 2 ].
    DATA(lv_case_type) = lt_cell[ 7 ].

*   ES_FORM is typed ZJUDGEMENT_PUBLISHER_TEXT_S on the FM and assigned to a
*   ZST_JUDGEMENT_PUBLISHER_TEXT work area, which is what the WD did. The
*   structure is confirmed: JUDGMENT_DATE (DATS), BASE_CASE
*   (ZST_JUDGEMENT_PUBLIS_BASE_CASE), ET_PARTNER
*   (ZTT_JUDGEMENT_PUBLIS_PARTNER) and ET_TEXT (TEXT_LH, a table of ITCLH
*   whose LINES component holds TDFORMAT / TDLINE) - the four components
*   read below - plus a case number, type and year this journey does not
*   need.
    DATA ls_txt   TYPE zst_judgement_publisher_text.
    DATA lv_cguid TYPE crmt_object_guid.
    lv_cguid = lv_guid.

    TRY.
        CALL FUNCTION 'ZFM_JUDGEMENT_PUBLICATION_TEXT'
          EXPORTING
            iv_guid  = lv_cguid
            iv_langu = zcl_rak_text=>c_langu_ar
          IMPORTING
            es_form  = ls_txt.
      CATCH cx_root INTO DATA(lx_txt).
        io_ctx->add_msg( iv_type = 'Error' iv_text = lx_txt->get_text( ) ).
        RETURN.
    ENDTRY.

*   The picked case's court, through ZDT_EGA_JUD_PUBL. It decides the party
*   captions and whether there is a contested judgment to show at all.
    DATA(lv_court)     = ``.
    DATA(lv_court_txt) = ``.
    DATA(lt_cfg)       = jud_cfg( ).
    READ TABLE lt_cfg INTO DATA(ls_map) WITH KEY case_type = lv_case_type.
    IF sy-subrc = 0.
      lv_court     = ls_map-court_type.
      lv_court_txt = dom_text( iv_domain = c_dom_court
                               iv_key    = lv_court
                               iv_langu  = zcl_rak_text=>c_langu_ar ).
    ENDIF.
    io_ctx->set_val( iv_name = c_f_jdcourt iv_value = lv_court ).

*   TITLE_1 in the WD was the screen's own caption; the step title in
*   ZRAK_T_JNY_STEP carries that here, so only the verdict title is stored.
    io_ctx->set_val( iv_name  = c_f_title2
                     iv_value = otr( iv_alias = c_a_verdict_ttl
                                     iv_en    = `Made the following judgment`
                                     iv_ar    = |أصـدرت الحكـم التـالي| ) ).

    io_ctx->set_val( iv_name  = c_f_head1
                     iv_value = head_txt_1( lv_court_txt ) ).
    io_ctx->set_val( iv_name  = c_f_head2
                     iv_value = head_txt_2( iv_court_txt = lv_court_txt
                                            iv_case_txt  = lv_case_txt
                                            iv_jud_date  = ls_txt-judgment_date ) ).

    party_block( io_ctx       = io_ctx
                 iv_court     = lv_court
                 it_partner   = ls_txt-et_partner
                 is_base_case = ls_txt-base_case ).

*   THE BODY, by the WD's rule exactly: every TDLINE joined by a space,
*   with a newline inserted wherever TDFORMAT contains '*' - which is how
*   SAPscript marks the start of a paragraph.
    DATA lv_note TYPE string.
    LOOP AT ls_txt-et_text INTO DATA(ls_text).
      LOOP AT ls_text-lines INTO DATA(ls_tline).
        IF ls_tline-tdformat CA '*'.
          lv_note = lv_note && cl_abap_char_utilities=>newline.
        ENDIF.
        IF lv_note IS INITIAL.
          lv_note = ls_tline-tdline.
        ELSE.
          lv_note = |{ lv_note } { ls_tline-tdline }|.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    io_ctx->set_val( iv_name = c_f_note iv_value = lv_note ).

    log_view( iv_guid = lv_guid iv_case_type = lv_case_type ).

    io_ctx->advance_step( ).
  ENDMETHOD.


  METHOD head_txt_1.
*&---------------------------------------------------------------------*
*& head_txt_1 — FORMAT_HEAD_TXT_1. Three lines, with the court name on the
*& third. See the note on HEADTXT_LINE_3 in the declaration part for why
*& only that line does not come from its OTR alias.
*&---------------------------------------------------------------------*
    DATA(lv_l1) = otr( iv_alias = c_a_head1
                       iv_en    = `In the name of of Allah the Merciful`
                       iv_ar    = |بسم الله الرحمن الرحيم| ).
    DATA(lv_l2) = otr( iv_alias = c_a_head2
                       iv_en    = `On behalf of His Highness Sheikh Saud bin Saqr bin ` &&
                                  `Mohammed Al Qasimi, Ruler of Ras Al Khaimah`
                       iv_ar    = |باسم حضرة صاحب السمو/ الشيخ سعود بن صقر بن محمد | &&
                                  |القاسمي حاكم إمارة رأس الخيمة| ).
*   ARABIC, NOT PICK( ). The other two lines of this block come from OTR( ),
*   which is Arabic-only now, so a PICK( ) here would put the one English line
*   in the middle of an Arabic document.
    DATA(lv_l3) = |محكمة رأس الخيمة|.

    rv = lv_l1
      && cl_abap_char_utilities=>newline && lv_l2
      && cl_abap_char_utilities=>newline && condense( |{ lv_l3 } { iv_court_txt }| ).
  ENDMETHOD.


  METHOD head_txt_2.
*&---------------------------------------------------------------------*
*& head_txt_2 — FORMAT_HEAD_TXT_2. The hearing line, with the judgment
*& date in &1 and the court in &2, then the case line.
*&---------------------------------------------------------------------*
    DATA(lv_l4) = otr( iv_alias = c_a_head4
                       iv_en    = `Public hearing held on &1 at Ras Al Khaimah Courts of &2`
                       iv_ar    = |بالجلسة العلنية المنعقدة يوم &1 بمقر محاكم رأس الخيمة &2| ).
    REPLACE FIRST OCCURRENCE OF '&1' IN lv_l4 WITH date_ext( iv_jud_date ).
    REPLACE FIRST OCCURRENCE OF '&2' IN lv_l4 WITH iv_court_txt.

    DATA(lv_l5) = otr( iv_alias = c_a_head5
                       iv_en    = `In Case No.`
                       iv_ar    = |في الدعـوى رقــم| ).

    rv = lv_l4 && cl_abap_char_utilities=>newline
      && condense( |{ lv_l5 } { iv_case_txt }| ).
  ENDMETHOD.


  METHOD party_block.
*&---------------------------------------------------------------------*
*& party_block — FORMAT_BP_DETAILS. Which two party functions to show, and
*& what to call them, depends only on the court type. First instance shows
*& claimant and respondent and no contested judgment; appeal and cassation
*& show their own two roles plus the judgment being contested, with the
*& base case beneath it.
*&---------------------------------------------------------------------*
    io_ctx->set_val( iv_name = c_f_bp1l iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_bp1v iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_bp2l iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_bp2v iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_jdgl iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_jdgv iv_value = '' ).

    CASE iv_court.

      WHEN c_court_first.
        io_ctx->set_val( iv_name  = c_f_bp1l
                         iv_value = otr( iv_alias = c_a_claimant
                                         iv_en    = `Claimant`
                                         iv_ar    = |مدعى| ) ).
        io_ctx->set_val( iv_name  = c_f_bp1v
                         iv_value = partner_names( it_partner = it_partner
                                                   iv_fct     = c_pf_claimant ) ).
        io_ctx->set_val( iv_name  = c_f_bp2l
                         iv_value = otr( iv_alias = c_a_respond
                                         iv_en    = `Respondent`
                                         iv_ar    = |مدعى عليه| ) ).
        io_ctx->set_val( iv_name  = c_f_bp2v
                         iv_value = partner_names( it_partner = it_partner
                                                   iv_fct     = c_pf_respondent ) ).

      WHEN c_court_appeal.
        io_ctx->set_val( iv_name  = c_f_bp1l
                         iv_value = otr( iv_alias = c_a_appellant
                                         iv_en    = `Appellant`
                                         iv_ar    = |مستأنف| ) ).
        io_ctx->set_val( iv_name  = c_f_bp1v
                         iv_value = partner_names( it_partner = it_partner
                                                   iv_fct     = c_pf_appellant ) ).
        io_ctx->set_val( iv_name  = c_f_bp2l
                         iv_value = otr( iv_alias = c_a_appell_ag
                                         iv_en    = `Appellant Against Him`
                                         iv_ar    = |مستأنف ضده| ) ).
        io_ctx->set_val( iv_name  = c_f_bp2v
                         iv_value = partner_names( it_partner = it_partner
                                                   iv_fct     = c_pf_appell_ag ) ).
        io_ctx->set_val( iv_name  = c_f_jdgl
                         iv_value = otr( iv_alias = c_a_apl_judg
                                         iv_en    = `Appealed Judgment`
                                         iv_ar    = |الحكم المستأنــف| ) ).
        io_ctx->set_val( iv_name  = c_f_jdgv
                         iv_value = base_case_text(
                                      iv_head_alias = c_a_apl_base
                                      iv_head_en    = `Base Case Appeal No.`
                                      iv_head_ar    = |الصادر بالاستئناف رقم|
                                      is_base_case  = is_base_case ) ).

      WHEN c_court_cass.
        io_ctx->set_val( iv_name  = c_f_bp1l
                         iv_value = otr( iv_alias = c_a_sup_appl
                                         iv_en    = `Supreme Appellant`
                                         iv_ar    = |طاعن| ) ).
        io_ctx->set_val( iv_name  = c_f_bp1v
                         iv_value = partner_names( it_partner = it_partner
                                                   iv_fct     = c_pf_suprem_app ) ).
        io_ctx->set_val( iv_name  = c_f_bp2l
                         iv_value = otr( iv_alias = c_a_sup_ag
                                         iv_en    = `Supreme Appealed Against`
                                         iv_ar    = |مطعون ضده| ) ).
        io_ctx->set_val( iv_name  = c_f_bp2v
                         iv_value = partner_names( it_partner = it_partner
                                                   iv_fct     = c_pf_suprem_ag ) ).
        io_ctx->set_val( iv_name  = c_f_jdgl
                         iv_value = otr( iv_alias = c_a_sup_judg
                                         iv_en    = `Supreme Judgment`
                                         iv_ar    = |الحكم المطعون فيه| ) ).
        io_ctx->set_val( iv_name  = c_f_jdgv
                         iv_value = base_case_text(
                                      iv_head_alias = c_a_sup_base
                                      iv_head_en    = `Appeal Base Case No.`
                                      iv_head_ar    = |الصادر بالطعن رقم|
                                      is_base_case  = is_base_case ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD partner_names.
*&---------------------------------------------------------------------*
*& partner_names — every FULL_NAME carrying one partner function, one per
*& line. A case can have several claimants or several respondents, which is
*& why this is a list and not a single name.
*&---------------------------------------------------------------------*
    LOOP AT it_partner INTO DATA(ls_p) WHERE partner_fct = iv_fct.
      IF rv IS INITIAL.
        rv = ls_p-full_name.
      ELSE.
        rv = rv && cl_abap_char_utilities=>newline && ls_p-full_name.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD base_case_text.
*&---------------------------------------------------------------------*
*& base_case_text — the contested judgment's own case, in the WD's shape:
*&   <heading> <number> / <year>, <type>
*&   <as of> <judgment date>
*&---------------------------------------------------------------------*
    DATA(lv_head) = otr( iv_alias = iv_head_alias
                         iv_en    = iv_head_en
                         iv_ar    = iv_head_ar ).
    DATA(lv_as_of) = otr( iv_alias = c_a_as_of
                          iv_en    = `As Of`
                          iv_ar    = |بتاريخ| ).

    DATA(lv_case) = |{ is_base_case-case_number } / { is_base_case-case_year }, | &&
                    |{ is_base_case-case_type }|.

    rv = condense( |{ lv_head } { lv_case }| )
      && cl_abap_char_utilities=>newline
      && condense( |{ lv_as_of } { date_ext( is_base_case-judgment_date ) }| ).
  ENDMETHOD.


  METHOD open_pdf.
*&---------------------------------------------------------------------*
*& open_pdf — ONACTIONADOBEFORM_DISPLAY.
*&
*& The form and its nine parameters are the WD's. What differs is the last
*& step: the WD called CL_WD_RUNTIME_SERVICES=>ATTACH_FILE_TO_RESPONSE,
*& which is WebDynpro's own streaming API and does not exist here. The
*& engine's equivalent is the pair its attachment viewer already uses -
*& park the bytes in ZRAK_CJ_ATTX as a data URL through
*& ZCL_RAK_CJ_ATT_STORE, then open the relative ICF path that streams them
*& back. The row is owned by SY-UNAME and the ICF handler refuses a GUID
*& belonging to somebody else, so the link cannot be passed around.
*&
*& OPEN_URL( ) is given the ICF path and NOT the data URL: OPEN_URL_HTML( )
*& resolves to window.open( ), and browsers refuse a top-level data:
*& navigation.
*&---------------------------------------------------------------------*
    DATA lv_fm       TYPE rs38l_fnam.
    DATA ls_docparam TYPE sfpdocparams.
    DATA ls_outparam TYPE sfpoutputparams.
    DATA ls_output   TYPE fpformoutput.

    CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
      EXPORTING
        i_name     = c_form
      IMPORTING
        e_funcname = lv_fm.
    IF lv_fm IS INITIAL.
      pdf_failed( io_ctx ).
      RETURN.
    ENDIF.

    ls_outparam-getpdf = 'X'.
    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outparam
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
      pdf_failed( io_ctx ).
      RETURN.
    ENDIF.

    CALL FUNCTION lv_fm
      EXPORTING
        /1bcdwb/docparams  = ls_docparam
        judment_note       = io_ctx->get_val( c_f_note )
        header_txt         = io_ctx->get_val( c_f_head2 )
        bp_type_1_label    = io_ctx->get_val( c_f_bp1l )
        bp_type_1          = io_ctx->get_val( c_f_bp1v )
        bp_type_2_label    = io_ctx->get_val( c_f_bp2l )
        bp_type_2          = io_ctx->get_val( c_f_bp2v )
        judement_dt_label  = io_ctx->get_val( c_f_jdgl )
        judement_dt        = io_ctx->get_val( c_f_jdgv )
      IMPORTING
        /1bcdwb/formoutput = ls_output
      EXCEPTIONS
        usage_error        = 1
        system_error       = 2
        internal_error     = 3
        OTHERS             = 4.
    DATA(lv_rc) = sy-subrc.

*   FP_JOB_CLOSE runs whatever happened above, because FP_JOB_OPEN
*   succeeded and an open spool job left behind would outlive this request.
    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.

    IF lv_rc <> 0 OR ls_output-pdf IS INITIAL.
      pdf_failed( io_ctx ).
      RETURN.
    ENDIF.

    DATA(lv_b64) = |data:application/pdf;base64,| &&
                   z2ui5_cl_util=>conv_encode_x_base64( ls_output-pdf ).

    DATA(lv_name) = otr( iv_alias = c_a_verdict_prv
                         iv_en    = `Verdict Preview`
                         iv_ar    = |عرض الحكم| ).

    DATA lv_guid TYPE string.
    DATA lv_msg  TYPE string.
    CALL METHOD zcl_rak_cj_att_store=>put
      EXPORTING
        iv_name = |{ lv_name }.pdf|
        iv_b64  = lv_b64
      IMPORTING
        ev_msg  = lv_msg
      RECEIVING
        rv_guid = lv_guid.

    IF lv_guid IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error' iv_text = lv_msg ).
      RETURN.
    ENDIF.

    io_ctx->open_url( zcl_rak_journey_util=>att_url( lv_guid ) ).
  ENDMETHOD.


  METHOD pdf_failed.
    io_ctx->add_msg(
      iv_type = 'Error'
      iv_text = zcl_rak_text=>pick( iv_base = `The judgment copy could not be produced.`
                                    iv_ar   = |لم يتم إنشاء نسخة الحكم.| ) ).
  ENDMETHOD.


  METHOD log_view.
*&---------------------------------------------------------------------*
*& log_view — the ZDT_CRT_PBJD_LOG row the WD writes every time a judgment
*& is opened (added there on 10/09/2025). The case id, number and year come
*& from the activity header joined to the case attributes, exactly as there.
*&
*& LOCAL reads, as in the WD. CJS runs on the system that owns this data, so
*& these three tables are here - the same reason ZDT_EGA_JUD_PUBL is read
*& with a plain SELECT in jud_cfg( ) and every function module in this class
*& is called without a DESTINATION.
*&
*& A failed log must never stop the citizen reading the judgment, so the
*& INSERT is checked and its failure is not reported.
*&---------------------------------------------------------------------*
    IF iv_guid IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_guid TYPE crmt_object_guid.
    lv_guid = iv_guid.

    SELECT SINGLE b~ext_key,
                  a~zzafld00003y_ach,
                  a~zzafld00003z_ach
      FROM crms4d_actv_h AS a
      LEFT OUTER JOIN scmg_t_case_attr AS b
        ON b~case_guid = a~zzafld00005d_ach
      WHERE a~header_guid = @lv_guid
      INTO @DATA(ls_case).

    DATA ls_log TYPE zdt_crt_pbjd_log.
    ls_log-header_guid = lv_guid.
    ls_log-case_type   = iv_case_type.
    ls_log-case_id     = ls_case-ext_key.
    ls_log-case_number = ls_case-zzafld00003y_ach.
    ls_log-case_year   = ls_case-zzafld00003z_ach.
    ls_log-log_date    = sy-datum.
    ls_log-log_time    = sy-uzeit.

    INSERT zdt_crt_pbjd_log FROM ls_log.
    IF sy-subrc = 0.
      COMMIT WORK.
    ENDIF.
  ENDMETHOD.


  METHOD fld_label.
*&---------------------------------------------------------------------*
*& fld_label — a field's label, from the configuration.
*& ZCL_RAK_JOURNEY_REPO already picked ZLABEL or ZLABEL_AR by the resolved
*& language when it built the config, so this is the exact text printed
*& above the control. Falls back to the field name, because a message with
*& a blank subject is worse than a technical one.
*&---------------------------------------------------------------------*
    DATA(ls_cfg) = io_ctx->get_config( ).
    LOOP AT ls_cfg-steps INTO DATA(ls_step).
      READ TABLE ls_step-fields INTO DATA(ls_fld) WITH KEY name = to_upper( iv_field ).
      IF sy-subrc = 0.
        rv = ls_fld-label.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF rv IS INITIAL.
      rv = iv_field.
    ENDIF.
  ENDMETHOD.


  METHOD otr.
*&---------------------------------------------------------------------*
*& otr — one OTR alias, ALWAYS IN ARABIC.
*&
*& THE JUDGMENT PAGE IS AN ARABIC DOCUMENT, NOT A BILINGUAL SCREEN. It was
*& built the other way: the ruling text came back in Arabic (LOAD_JUDGMENT( )
*& passes IV_LANGU = 'A') while the furniture around it - the head lines, the
*& party captions, the verdict title - followed the citizen's language. That
*& reads as "genuinely bilingual" in a specification and as a mistake on
*& screen: English labels wrapped around Arabic names, in a block that is one
*& continuous quotation from a court document. The WD rendered the whole page
*& in Arabic whatever the logon language, and it was right to.
*&
*& So this reads C_LANGU_AR rather than ZCL_RAK_TEXT=>LANG( ). Every one of
*& the seventeen aliases goes through here, which is the whole reason the
*& helper exists - the alternative was seventeen call sites to remember.
*&
*& SCOPE: this method and the two literals that do not come from an alias
*& (HEADTXT_LINE_3, and the View-copy caption). It does NOT touch the search
*& step, which stays bilingual - OTR( ) is called from LOAD_JUDGMENT( ) and
*& its helpers and from nowhere else. Nor the engine's own chrome: the wizard
*& step titles and the footer buttons come from the framework catalogue in the
*& resolved language and are not ours to force.
*&
*& SOTR_GET_TEXT_KEY answers a missing alias with BLANK rather than
*& anything worth propagating, so every caller needs a fallback and gets
*& one here instead of at each of the seventeen call sites.
*&---------------------------------------------------------------------*
    DATA lv_text TYPE sotr_txt.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = iv_alias
        langu           = zcl_rak_text=>c_langu_ar
      IMPORTING
        e_text          = lv_text
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0.
      rv = condense( CONV string( lv_text ) ).
    ENDIF.
*   THE FALLBACK IS THE ARABIC SIDE, for the same reason. IV_EN is kept on the
*   signature rather than deleted: it documents what each alias says, which is
*   the only readable record of these seventeen texts for anyone who cannot
*   read the Arabic, and it is what to fall back to if the page is ever made
*   bilingual again.
    IF rv IS INITIAL.
      rv = iv_ar.
    ENDIF.
  ENDMETHOD.


  METHOD t100_text.
*&---------------------------------------------------------------------*
*& t100_text — a T100 message's text, the same helper AS3 carries. The WD
*& built EI 057 with MESSAGE_TEXT_BUILD; this reads the same row. Returns
*& BLANK when the message does not exist - FORMAT_MESSAGE swallows
*& everything through OTHERS = 0 - so the caller must have a fallback.
*&---------------------------------------------------------------------*
    CALL FUNCTION 'FORMAT_MESSAGE'
      EXPORTING
        id     = iv_id
        lang   = zcl_rak_text=>lang( )
        no     = iv_no
      IMPORTING
        msg    = rv
      EXCEPTIONS
        OTHERS = 0.
  ENDMETHOD.


  METHOD dom_opts.
*&---------------------------------------------------------------------*
*& dom_opts — a domain's fixed values as key/text options.
*&
*& One FM for both domain dropdowns AND for the court text the result list
*& and the judgment header show. The WD used DD_DOMA_GET for the text and
*& nothing at all for the dropdowns, which were bound to a context node;
*& going through one place means the text beside a row and the text in the
*& dropdown cannot disagree.
*&---------------------------------------------------------------------*
    DATA lt_dd07v TYPE STANDARD TABLE OF dd07v.
    DATA(lv_langu) = COND sylangu( WHEN iv_langu IS NOT INITIAL THEN iv_langu
                                   ELSE zcl_rak_text=>lang( ) ).
    CALL FUNCTION 'DDUT_DOMVALUES_GET'
      EXPORTING
        name          = iv_domain
        langu         = lv_langu
      TABLES
        dd07v_tab     = lt_dd07v
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT lt_dd07v INTO DATA(ls_dd).
      APPEND VALUE #( key = ls_dd-domvalue_l text = ls_dd-ddtext ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD dom_text.
*&---------------------------------------------------------------------*
*& dom_text — one domain value's text, blank when the key is unknown.
*&---------------------------------------------------------------------*
    IF iv_key IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_o) = dom_opts( iv_domain = iv_domain iv_langu = iv_langu ).
    READ TABLE lt_o INTO DATA(ls_o) WITH KEY key = iv_key.
    IF sy-subrc = 0.
      rv = ls_o-text.
    ENDIF.
  ENDMETHOD.


  METHOD jud_cfg.
*&---------------------------------------------------------------------*
*& jud_cfg — ZDT_EGA_JUD_PUBL, the (court type, classification, case type)
*& mapping the whole search is built on. It decides which case types the
*& Case/File Type dropdown offers, and it turns a result row's case type
*& back into a court so the court column and the judgment header can name
*& it. Its CONTENTS are configuration maintained in SM30, which is why
*& nothing in this repository carries a copy of them.
*&
*& A plain local SELECT, as in the WD: this table is on the system CJS runs
*& on.
*&---------------------------------------------------------------------*
    SELECT * FROM zdt_ega_jud_publ INTO TABLE @rt.
  ENDMETHOD.


  METHOD case_desc.
*&---------------------------------------------------------------------*
*& case_desc — the case types' descriptions, from ZJDG_CASE_TYPES.
*&
*& Asked for in the citizen's language, then topped up from Arabic for any
*& row that came back without one. The WD asked in SY-LANGU and accepted
*& whatever it got, which on an English logon could leave a dropdown of
*& blank entries; a dropdown with no text in it is unusable, and the Arabic
*& is at least readable by the citizens this service is for.
*&---------------------------------------------------------------------*
    DATA(lv_lang) = zcl_rak_text=>lang( ).

    TRY.
        CALL FUNCTION 'ZJDG_CASE_TYPES'
          EXPORTING
            iv_langu     = lv_lang
          TABLES
            et_case_type = rt.
      CATCH cx_root.
        CLEAR rt.
        RETURN.
    ENDTRY.

    IF lv_lang = zcl_rak_text=>c_langu_ar.
      RETURN.
    ENDIF.

    DATA(lv_gap) = abap_false.
    LOOP AT rt INTO DATA(ls_chk).
      IF ls_chk-description IS INITIAL.
        lv_gap = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lv_gap = abap_false.
      RETURN.
    ENDIF.

    DATA lt_ar TYPE tt_desc.
    TRY.
        CALL FUNCTION 'ZJDG_CASE_TYPES'
          EXPORTING
            iv_langu     = zcl_rak_text=>c_langu_ar
          TABLES
            et_case_type = lt_ar.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT rt ASSIGNING FIELD-SYMBOL(<ls_d>) WHERE description IS INITIAL.
      READ TABLE lt_ar INTO DATA(ls_ar) WITH KEY case_type = <ls_d>-case_type.
      IF sy-subrc = 0.
        <ls_d>-description = ls_ar-description.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD case_type_opts.
*&---------------------------------------------------------------------*
*& case_type_opts — INIT_DROPDOWN_LOAD and ONACTIONSET_CASE_TYPE_DD in one
*& method, because they only ever differed in whether a filter was applied
*& and this is asked afresh on every render.
*&
*& ZDT_EGA_JUD_PUBL supplies the case types allowed for the chosen Court
*& Type and Classification; CRM supplies their descriptions. A case type
*& listed in the config table but unknown to CRM keeps its key as its text
*& rather than vanishing - a missing description is a data problem to be
*& seen, not one to hide.
*&---------------------------------------------------------------------*
    DATA(lv_court) = io_ctx->get_val( c_f_court ).
    DATA(lv_class) = io_ctx->get_val( c_f_classify ).
    DATA(lt_desc)  = case_desc( ).
    DATA(lt_cfg)   = jud_cfg( ).

    LOOP AT lt_cfg INTO DATA(ls_cfg).
      IF lv_court IS NOT INITIAL AND ls_cfg-court_type <> lv_court.
        CONTINUE.
      ENDIF.
      IF lv_class IS NOT INITIAL AND ls_cfg-classify_type <> lv_class.
        CONTINUE.
      ENDIF.
      IF line_exists( rt[ key = ls_cfg-case_type ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_txt) = CONV string( ls_cfg-case_type ).
      READ TABLE lt_desc INTO DATA(ls_desc) WITH KEY case_type = ls_cfg-case_type.
      IF sy-subrc = 0 AND ls_desc-description IS NOT INITIAL.
        lv_txt = ls_desc-description.
      ENDIF.
      APPEND VALUE #( key = ls_cfg-case_type text = lv_txt ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD year_opts.
*&---------------------------------------------------------------------*
*& year_opts — the current year down to C_FIRST_YEAR, newest first, which
*& is the order INIT_DROPDOWN_LOAD sorted its own list into.
*&---------------------------------------------------------------------*
    DATA lv_year TYPE i.
    lv_year = sy-datum(4).
    WHILE lv_year >= c_first_year.
      APPEND VALUE #( key = |{ lv_year }| text = |{ lv_year }| ) TO rt.
      lv_year = lv_year - 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD date_ext.
*&---------------------------------------------------------------------*
*& date_ext — a date in the user's own external format, through the same
*& FM the WD used, so the judgment reads the way the legacy screen did. An
*& initial date returns blank rather than 00.00.0000.
*&---------------------------------------------------------------------*
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    CALL FUNCTION 'CONVERT_DATE_TO_EXTERNAL'
      EXPORTING
        date_internal            = iv_date
      IMPORTING
        date_external            = rv
      EXCEPTIONS
        date_internal_is_invalid = 1
        OTHERS                   = 2.
    IF sy-subrc <> 0.
      CLEAR rv.
    ENDIF.
  ENDMETHOD.


  METHOD text_lines.
*&---------------------------------------------------------------------*
*& text_lines — split a stored block into its lines. Empty in, empty out,
*& and a trailing newline does not produce a blank line at the end.
*&---------------------------------------------------------------------*
    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT iv_text AT cl_abap_char_utilities=>newline INTO TABLE rt.

    DATA lv_last TYPE string.
    DATA lv_n    TYPE i.
    lv_n = lines( rt ).
    WHILE lv_n > 0.
      READ TABLE rt INTO lv_last INDEX lv_n.
      IF lv_last IS NOT INITIAL.
        EXIT.
      ENDIF.
      DELETE rt INDEX lv_n.
      lv_n = lv_n - 1.
    ENDWHILE.
  ENDMETHOD.
ENDCLASS.
