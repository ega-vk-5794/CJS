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
    METHODS zif_rak_journey_logic~on_render_before_field
      REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_after_field
      REDEFINITION .
    METHODS zif_rak_journey_logic~render_field
      REDEFINITION .
    METHODS zif_rak_journey_logic~get_table
      REDEFINITION .
    METHODS zif_rak_journey_logic~wants_feedback
      REDEFINITION .

protected section.
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

*   THERE IS NO ROW CAP, and its absence is the point of FETCH_ROWS( ).
*
*   THERE USED TO BE ONE - 200, then 500 - and it existed because the whole
*   result was packed into a hidden model field that crossed the wire on
*   every click. That made the cap a bound on the PAYLOAD, so raising it to
*   cover a four-thousand-row court year would have meant 800KB per press.
*   The rows are re-read per request now and the model carries one number,
*   so the cap has nothing left to protect and is gone: a search returns
*   what the court has, fifty are drawn, and the citizen pages or filters.
*
*   THE WD HAD NO CAP EITHER. Its ALV held every row the search returned and
*   scrolled ten at a time, so this is the legacy behaviour restored rather
*   than a new liberty taken.

*   How many of those rows are DRAWN at once. The cap above bounds what the
*   search keeps; this bounds what the page builds, and they are different
*   questions - 500 rows in the model is cheap, 500 rows of markup is not.
*   Paging is done here rather than with the table's own GROWING because
*   sap.m pages a BOUND items aggregation and the engine emits one static
*   row per record; see R17-2. Every page is ordinary static rows carrying
*   their own keys, so the row-pick event is untouched by any of this.
*   The page size the citizen has not chosen. PAGE_SIZE( ) reads JUD_PSIZE
*   and falls back to this, so a citizen who never opens the picker gets
*   this and nothing else.
*
*   TWENTY-FIVE, DOWN FROM FIFTY. Fifty rows is more than a screen at any
*   window height, so the citizen who never touches the picker was always
*   scrolling to see the end of their own page. Twenty-five is closer to a
*   screenful, and the four choices in the picker mean anyone who wants the
*   longer page can still have it.
    CONSTANTS c_page_size TYPE i VALUE 25.

*   THE READ, CACHED AGAINST THE CRITERIA THAT PRODUCED IT. FETCH_ROWS( )
*   is called by GET_TABLE( ), by both renderers and by ROW_CELLS( ), which
*   would be four reads of the same data in one round trip.
*
*   KEYED ON THE CRITERIA RATHER THAN ON THE REQUEST, and that is
*   deliberate. A per-request flag would need the handler to be discarded
*   between round trips, and it is NOT: ENSURE_PARTS( ) clears the engine's
*   five helpers and MO_PCL before serializing, and MO_LOGIC is not among
*   them. A signature is correct either way - if the handler survives, the
*   read happens once per distinct search; if it does not, once per round
*   trip, which is what ZCL_RAK_CJ_PARCEL does.
    DATA mt_fetch  TYPE zif_rak_journey=>tt_string.
    DATA mv_fetch_sig TYPE string.
*   THE READ FAILED, as distinct from the read finding nothing. Without it
*   DO_SEARCH( ) reads an empty result as "no data was found" and prints
*   that under the function module's own error - two messages, one of them
*   contradicting the other, and the citizen with no way to tell which.
    DATA mv_fetch_bad TYPE abap_bool.

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
*   HOW MANY THE LAST SEARCH FOUND, and nothing else. This replaced
*   JUD_ROWS, which carried the whole packed result and crossed the wire on
*   every round trip - a hidden field of 100KB at the old 500-row cap, and
*   the reason that cap existed. The rows are re-read per request now
*   (FETCH_ROWS( )) and the model carries one number.
*
*   IT IS ALSO THE "HAS A SEARCH BEEN RUN" FLAG. Blank means never searched
*   or cleared, which is what hides the table and the filter box. A search
*   that legitimately finds nothing never gets that far - DO_SEARCH( )
*   reports the WD's own EI 057 and leaves the list hidden.
    CONSTANTS c_f_hits     TYPE string VALUE 'JUD_HITS'.
*   The pager's memory. A hidden INPUT on SRCH holding the zero-based index
*   of the first row currently drawn.
*
*   A MODEL FIELD RATHER THAN AN INSTANCE ATTRIBUTE, and the reason is not
*   the one first written here. That said the engine re-instantiates the
*   handler every round trip, which is NOT established: ENSURE_PARTS( )
*   CLEARs MO_CSS, MO_GRID, MO_RENDER, MO_BE, MO_RULES and MO_PCL before
*   serializing and MO_LOGIC is not in that list, and it is only created
*   IF MO_LOGIC IS INITIAL - so a handler attribute may well survive, which
*   is exactly how ZCL_RAK_CJ_PARCEL keeps its own page and search term.
*   The real reason is that a field works either way, costs a few bytes for
*   a scalar, and is the same place this journey already keeps JUD_ROWS and
*   SEL_GUID. One store for the journey's memory, not two.
    CONSTANTS c_f_page     TYPE string VALUE 'JUD_PAGE'.
*   The in-table filter's text. A model field for the same reason as
*   JUD_PAGE - it has to survive the round trip the Search event causes.
    CONSTANTS c_f_filt     TYPE string VALUE 'JUD_FILT'.
*   The opening tag a filter match is wrapped in - see HL( ), which explains
*   why it is a span carrying a STYLE and not a class, a <mark> or a
*   <strong>. Here rather than inline because a literal this long inside the
*   concatenation in HL( ) pushes that statement past what is comfortable to
*   read, and because the colour is the one thing in it anybody will ever
*   want to change.
    CONSTANTS c_hl_open TYPE string
              VALUE '<span style="background-color:#FFF2A8;font-weight:bold">'.
*   The sort column, as the 1-based index of a cell in the packed row, and
*   the direction. Index rather than name because the columns are declared
*   in GET_TABLE( ) and have no config row to be named from.
    CONSTANTS c_f_sort     TYPE string VALUE 'JUD_SORT'.
    CONSTANTS c_f_dir      TYPE string VALUE 'JUD_DIR'.
    CONSTANTS c_f_psize    TYPE string VALUE 'JUD_PSIZE'.
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
    CONSTANTS c_ev_prev   TYPE string VALUE 'JPPREV'.
    CONSTANTS c_ev_next   TYPE string VALUE 'JPNEXT'.
    CONSTANTS c_ev_filt   TYPE string VALUE 'JPFILT'.
    CONSTANTS c_ev_fclr   TYPE string VALUE 'JPFCLR'.
    CONSTANTS c_ev_sort   TYPE string VALUE 'JPSORT'.
    CONSTANTS c_ev_dir    TYPE string VALUE 'JPDIR'.
    CONSTANTS c_ev_xls    TYPE string VALUE 'JPXLS'.
    CONSTANTS c_ev_psize  TYPE string VALUE 'JPPSIZE'.

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
*   ZEGA_CRM_JUDPUBLISH_VERDICT_PREVIEW is the WD's alias for the PDF's file
*   name and is NOT declared here any more. The name is chrome - a browser tab
*   and a download - so it goes through PICK( ) rather than OTR( ), and OTR( )
*   is the only reader of these constants. Recorded rather than deleted
*   silently, in case the alias is wanted again.

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

    METHODS all_rows
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE zif_rak_journey=>ty_table-rows.

    METHODS fetch_rows
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

    METHODS crit_sig
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE string.

    METHODS page_off
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE i.

    METHODS page_size
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE i.

    METHODS page_move
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
                iv_by  TYPE i.

    METHODS render_pager
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                io_view TYPE REF TO z2ui5_cl_xml_view.

    METHODS render_filter
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                io_view TYPE REF TO z2ui5_cl_xml_view.

    METHODS hl
      IMPORTING iv_text   TYPE string
                iv_filt   TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS rich_esc
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS sort_rows
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
      CHANGING  ct     TYPE zif_rak_journey=>ty_table-rows.

    METHODS col_labels
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

    METHODS export_xls
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS xml_esc
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS xlsx_bytes
      IMPORTING it_row    TYPE zif_rak_journey=>ty_table-rows
      RETURNING VALUE(rv) TYPE xstring.

    METHODS utf8
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE xstring.

    METHODS cell_ref
      IMPORTING iv_col    TYPE i
                iv_row    TYPE i
      RETURNING VALUE(rv) TYPE string.


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



CLASS ZCL_C061_JUDGEMENT_PUBL_LOGIC IMPLEMENTATION.


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
*& IT NO LONGER REACHES SRCH. NO_SUBMIT turns the last step's Submit into
*& Close, and the Close it used to leave on the SEARCH step is now removed by
*& NO_ACTION = 'X' in the loader - a step flag, not a model value, and read
*& before the three-way this one feeds. The two are not alternatives: JDGM
*& still needs the Close this line produces.
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
*       BILINGUAL, unlike the document it sits above. The judgment body is
*       Arabic on every session because the WD read it that way - LOAD_JUDGMENT( )
*       passes IV_LANGU = 'A' to ZFM_JUDGEMENT_PUBLICATION_TEXT - but this button
*       is chrome rather than document content, so it follows the reader.
*
*       PICK( ), NOT THE OTR. PDF_BUTTON's TEXT in the WD is an OTR CONCEPT
*       (9EFD37829E031EDA86CFC614B86007A0) rather than an alias, and
*       SOTR_GET_TEXT_KEY takes an alias - so the concept cannot be resolved at
*       runtime and its English text, if it has one, is not readable from here.
*       The Arabic below is verbatim from the live screen; THE ENGLISH IS OURS.
*
*       PICK( ) follows the ENGINE's resolved language, not SY-LANGU, which is
*       what makes it right: the step, its buttons and any popup then agree,
*       where SY-LANGU can differ from the language the journey is rendering in.
        io_view->button(
          text  = zcl_rak_text=>pick( iv_base = `View copy` iv_ar = |نسخة العرض| )
          icon  = 'sap-icon://pdf-attachment'
          type  = 'Emphasized'
          class = 'sapUiSmallMarginTop'
          press = io_ctx->event( c_ev_pdf ) ).

      WHEN c_f_list.
*       THE PAGER, under the result table. This branch reaches a BLOCK field,
*       which is worth stating because the hooks differ: RENDER_FIELD( ) is
*       NOT called for a block type, so the judgment's DISPLAY route is not
*       available here - but AFTER_FIELD( ) is called for every field,
*       block or not (ZCL_RAK_JOURNEY_RENDER ~3560, RENDER_BLOCK( ) followed
*       immediately by AFTER_FIELD( )), and IO_VIEW is the block's own
*       container. So the buttons land under the table rather than beside it.
        render_pager( io_ctx = io_ctx io_view = io_view ).

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
      WHEN c_ev_prev.
        page_move( io_ctx = io_ctx iv_by = -1 ).
      WHEN c_ev_next.
        page_move( io_ctx = io_ctx iv_by = 1 ).
      WHEN c_ev_filt.
*       The text itself arrived with the round trip, committed by the button
*       press that moved focus out of the input. All this has to do is go
*       back to page one: the citizen who filters while on page 6 of the
*       unfiltered list would otherwise be shown a window past the end of a
*       much shorter one.
        io_ctx->set_val( iv_name = c_f_page iv_value = '0' ).
      WHEN c_ev_fclr.
        io_ctx->set_val( iv_name = c_f_filt iv_value = '' ).
        io_ctx->set_val( iv_name = c_f_page iv_value = '0' ).
      WHEN c_ev_sort.
*       BACK TO PAGE ONE ON A SORT TOO, and for a sharper reason than the
*       filter's. The row count does not change, so the offset stays valid -
*       but the rows at it are completely different ones, and a citizen who
*       sorts while on page 40 lands in the middle of an order they have not
*       seen the start of.
        io_ctx->set_val( iv_name = c_f_page iv_value = '0' ).
      WHEN c_ev_xls.
        export_xls( io_ctx ).
      WHEN c_ev_psize.
*       THE OFFSET IS LEFT WHERE IT IS, deliberately. Snapping back to page
*       one would throw away the citizen's place in four thousand rows for a
*       change that does not reorder anything - the row they were looking at
*       is still in the result and still at the same index. The offset need
*       not be a multiple of the new size: the pager reads it directly, so
*       "Showing 2001-2010 of 4000" is as true as any other window, and
*       paging back still walks down to zero without skipping a row.
      WHEN c_ev_dir.
        io_ctx->set_val( iv_name = c_f_dir
                         iv_value = COND string( WHEN io_ctx->get_val( c_f_dir ) = 'D'
                                                 THEN 'A' ELSE 'D' ) ).
        io_ctx->set_val( iv_name = c_f_page iv_value = '0' ).
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
*& EVERY COLUMN NAMES ITS WIDTH, as a PERCENTAGE. R12-1, engine commit
*& abdab55: COL_SPEC( ) splits the header on '|' and CSS_WIDTH( ) validates the
*& tail, so a refused unit leaves the column exactly as it renders without one.
*&
*& THE SHARE IS THE POINT, not the absolute size. sap.m.Table has FIXEDLAYOUT
*& true, so a column's width is decided by what it is given and NOT by what it
*& holds - and CASE_TEXT is up to 80 characters where the three date and period
*& columns hold ten, four and three. Left to itself the table gave all six an
*& equal sixth, so the one value the citizen reads wrapped onto three lines
*& while three columns sat mostly empty. 34 / 15 / 13 / 13 / 13 leaves about an
*& eighth for the pick button, which the engine appends with no width of its
*& own.
*&
*& PER CENT RATHER THAN rem, deliberately. Under FIXEDLAYOUT the columns are
*& shares of the table, so percentages keep their proportions as the page
*& narrows, where a rem width is an absolute that stops fitting. CSS_WIDTH( )
*& accepts both and refuses px for the same reason.
*&
*& ALIGNMENT IS THE THIRD PART, '|End'. R13-1, engine commit 0ef0d4d, and live:
*& COL_SPEC( ) answers a header, a width and an alignment, validated by
*& CSS_ALIGN( ) - the same validator the DISPLAY field's TEXT_ALIGN uses, so the
*& two cannot drift into accepting different words. A value it refuses answers
*& blank and the column renders as it does without one.
*&
*& THE TWO DATES AND THE DAY COUNT ARE RIGHT-ALIGNED; the case reference and the
*& court are left, which is the default and is left blank rather than written
*& out. The day count is a number and that half is not a judgment call. The
*& dates are: they are one fixed format, dd.MM.yyyy, and a column of them shares
*& an edge and reads as data instead of as prose - and it puts them with the
*& number beside them rather than with the text before them. 'Begin' on both is
*& one word away if the department reads it the other way.
*&
*& 'BEGIN' AND 'END', NOT 'LEFT' AND 'RIGHT'. CSS_ALIGN( ) accepts all six that
*& sap.m.Column takes, but the journey renders right-to-left in Arabic and only
*& the logical pair follows the reading direction.
*&
*& THE PIPE IS WHY THIS COLUMN LIST CANNOT COME FROM DEFAULT_VAL. In the
*& KEY:Label:TYPE spec '|' separates the COLUMNS, so a header there can never
*& carry one. Only GET_TABLE( ) can reach the width, by construction.
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

*   RICH ON ALL FIVE VISIBLE COLUMNS - R18-3, engine commit 5e29503. The
*   fourth part of the spec, behind the same separator as the width and the
*   alignment, asks the renderer to draw that column's cells with
*   FORMATTED_TEXT( ) instead of TEXT( ). It is what makes HL( ) able to mark
*   the part of a value the filter matched.
*
*   ALL FIVE RATHER THAN THE TWO TEXT ONES, because the filter matches across
*   every visible cell: filter on 2026 and the hit is in the dates, so
*   marking only the reference and the court would highlight some matches and
*   silently not others, which reads as the highlighting being broken.
*
*   THE PRICE IS THAT THESE CELLS ARE NO LONGER ESCAPED BY THE ENGINE. The
*   TEXT( ) path runs ESC( ) over every value; the FORMATTED_TEXT( ) path
*   deliberately does not, because escaping is the thing a rich cell exists
*   to avoid. HL( ) therefore escapes every value itself - HTML entities AND
*   the braces abap2UI5 reads as bindings - before it inserts any markup. A
*   RICH column whose values are not passed through HL( ) is a defect.
    rs_data-columns = VALUE zif_rak_journey=>tt_string(
      ( `-` )
      ( zcl_rak_text=>pick( iv_base = `Case No.`          iv_ar = |رقم القضية| )    && `|34%||RICH` )
      ( zcl_rak_text=>pick( iv_base = `Court`             iv_ar = |المحكمة| )       && `|15%||RICH` )
      ( zcl_rak_text=>pick( iv_base = `Registration Date` iv_ar = |تاريخ التسجيل| ) && `|13%|End|RICH` )
      ( zcl_rak_text=>pick( iv_base = `Judgment Date`     iv_ar = |تاريخ الحكم| )   && `|13%|End|RICH` )
      ( zcl_rak_text=>pick( iv_base = `Litigation Period` iv_ar = |مدة التقاضي| )   && `|13%|End|RICH` ) ).

*   ONE PAGE, NOT THE WHOLE RESULT. ALL_ROWS( ) unpacks everything the
*   search kept; this returns only the window the citizen is looking at, and
*   RENDER_PAGER( ) draws Previous / Next underneath. The row-pick event is
*   unaffected because every drawn row still carries its own GUID in cell 1 -
*   paging changes which rows are built, never how one is identified.
    DATA(lt_all) = all_rows( io_ctx ).
    DATA(lv_off) = page_off( io_ctx ).
*   CLAMPED AT RENDER TIME, NOT ONLY WHEN A BUTTON IS PRESSED. PAGE_MOVE( )
*   already clamps, but the result can SHRINK under a stationary offset -
*   the filter is the obvious way, and the citizen never pressed a pager
*   button to get there. ZCL_RAK_CJ_PARCEL clamps in the same place and for
*   the same reason; taken from there rather than found here.
    IF lv_off >= lines( lt_all ) AND lines( lt_all ) > 0.
      lv_off = ( ( lines( lt_all ) - 1 ) DIV page_size( io_ctx ) ) * page_size( io_ctx ).
      io_ctx->set_val( iv_name = c_f_page iv_value = |{ lv_off }| ).
    ENDIF.
    DATA(lv_ix)  = lv_off + 1.
    DATA(lv_end) = lv_off + page_size( io_ctx ).
    IF lv_end > lines( lt_all ).
      lv_end = lines( lt_all ).
    ENDIF.
*   MARKED HERE AND NOWHERE ELSE, which is the point of doing it in
*   GET_TABLE( ) rather than in ALL_ROWS( ). ALL_ROWS( ) is also what
*   EXPORT_XLS( ) reads and what the pager counts, and a spreadsheet full of
*   <strong> tags would be the obvious consequence of marking one level down.
*   Only the rows actually drawn are touched.
*
*   CELL 1 IS LEFT ALONE. It is the case GUID, hidden by the renderer and not
*   a RICH column, so escaping it as rich text would be wrong in both
*   directions - it is neither shown nor safe to mark.
    DATA(lv_filt) = condense( io_ctx->get_val( c_f_filt ) ).
    WHILE lv_ix <= lv_end.
      READ TABLE lt_all INTO DATA(lt_one) INDEX lv_ix.
      IF sy-subrc = 0.
        DATA(lv_cx) = 0.
        LOOP AT lt_one ASSIGNING FIELD-SYMBOL(<cell>).
          lv_cx = lv_cx + 1.
          IF lv_cx = 1.
            CONTINUE.
          ENDIF.
          <cell> = hl( iv_text = <cell> iv_filt = lv_filt ).
        ENDLOOP.
        APPEND lt_one TO rs_data-rows.
      ENDIF.
      lv_ix = lv_ix + 1.
    ENDWHILE.
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
*
*   BOLD, AND A LABEL RATHER THAN A TEXT TO GET THERE. The legacy screen draws
*   this block in bold and the hearing and case lines under it in normal weight;
*   both were plain sap.m.Text here, so the document opened with no hierarchy at
*   all. sap.m.Text has no weight property, and the only bold the engine's
*   stylesheet offers is .rakBlkTitle - a block-title class with its own colour,
*   which would couple this document to a rule written for table headings.
*   sap.m.Label carries DESIGN 'Bold' as a first-class property instead.
*
*   WRAPPING IS NOT OPTIONAL WITH IT. A Label defaults WRAPPING to false where a
*   Text defaults it to true, so line 2 - the longest line on the page - would
*   have been truncated with an ellipsis rather than wrapped. Read off the
*   signature in Z2UI5_CL_XML_VIEW, not assumed from the control it replaces.
    DATA(lt_h1) = text_lines( io_ctx->get_val( c_f_head1 ) ).
    LOOP AT lt_h1 INTO DATA(lv_h1).
      lo_doc->label( text      = zcl_rak_journey_util=>esc( lv_h1 )
                     design    = 'Bold'
                     wrapping  = abap_true
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
      lo_p1->label( text   = zcl_rak_journey_util=>esc( lv_l1 )
                    design = 'Bold' ).
      DATA(lo_v1) = lo_p1->vbox( class = 'sapUiSmallMarginBegin' ).
      DATA(lt_v1) = text_lines( io_ctx->get_val( c_f_bp1v ) ).
      LOOP AT lt_v1 INTO DATA(lv_v1).
        lo_v1->text( zcl_rak_journey_util=>esc( lv_v1 ) ).
      ENDLOOP.
    ENDIF.

    DATA(lv_l2) = io_ctx->get_val( c_f_bp2l ).
    IF lv_l2 IS NOT INITIAL.
      DATA(lo_p2) = lo_pty->hbox( alignitems = 'Start' class = 'sapUiTinyMarginBottom' ).
      lo_p2->label( text   = zcl_rak_journey_util=>esc( lv_l2 )
                    design = 'Bold' ).
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
      lo_pj->label( text   = zcl_rak_journey_util=>esc( lv_lj )
                    design = 'Bold' ).
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

*   THE READ ITSELF LIVES IN FETCH_ROWS( ), because it is no longer only
*   this method's. The rows are re-read on the round trips that need them -
*   a page press, a filter, opening a judgment - so the FM call, the court
*   text and the litigation-period arithmetic all belong somewhere both this
*   and those can reach. What stays here is what only a SEARCH does:
*   refusing blank criteria above, reporting an empty result, and resetting
*   the page, the filter and the picked row.
*   THE CACHE IS DROPPED FIRST. A Search press means "read it again", even
*   when the criteria have not moved - the citizen pressing the button a
*   second time is asking for a fresh answer, and after a failed read it is
*   the only way back to one.
    CLEAR: mt_fetch, mv_fetch_sig, mv_fetch_bad.
    DATA(lt_hit) = fetch_rows( io_ctx ).

    io_ctx->set_val( iv_name = c_f_sel  iv_value = '' ).

*   A FAILED READ IS NOT AN EMPTY ONE. FETCH_ROWS( ) has already reported
*   the function module's own error; saying "no data was found" underneath
*   it would contradict it, and the citizen would have two sentences and no
*   way to tell which one happened.
    IF mv_fetch_bad = abap_true.
      io_ctx->set_val( iv_name = c_f_hits iv_value = '' ).
      io_ctx->set_hidden( iv_field = c_f_list iv_on = abap_true ).
      RETURN.
    ENDIF.

    IF lt_hit IS INITIAL.
*     The WD's own no-results message, read from T100 the way it read it:
*     EI 057, built with MESSAGE_TEXT_BUILD there and FORMAT_MESSAGE here.
*     The message exists in both languages - confirmed - but T100 rows are
*     per language and FORMAT_MESSAGE answers a missing one with BLANK
*     rather than an exception, so the fallback stays: an error strip with
*     no text blocks the citizen with nothing on screen to explain it. It
*     carries the SAME wording as the T100 row, so a gap in one language
*     cannot produce a differently worded error from the other.
      io_ctx->set_val( iv_name = c_f_hits iv_value = '' ).
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

    io_ctx->set_val( iv_name = c_f_hits iv_value = |{ lines( lt_hit ) }| ).
*   A NEW SEARCH STARTS AT PAGE ONE, AND THE FILTER GOES WITH IT. A filter
*   left over from the previous result would silently hide most of a new
*   search - the citizen would see the criteria they typed next to a result
*   that does not match them - and an offset left at page six would open a
*   window past the end of a shorter one.
    io_ctx->set_val( iv_name = c_f_page iv_value = '0' ).
    io_ctx->set_val( iv_name = c_f_filt iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_sort iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_dir  iv_value = '' ).
    io_ctx->set_hidden( iv_field = c_f_list iv_on = abap_false ).
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
    io_ctx->set_val( iv_name = c_f_hits     iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_sel      iv_value = '' ).
    io_ctx->set_hidden( iv_field = c_f_list iv_on = abap_true ).
    io_ctx->set_val( iv_name = c_f_page iv_value = '0' ).
    io_ctx->set_val( iv_name = c_f_filt iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_sort iv_value = '' ).
    io_ctx->set_val( iv_name = c_f_dir  iv_value = '' ).
  ENDMETHOD.


  METHOD fetch_rows.
*&---------------------------------------------------------------------*
*& fetch_rows — the search, run again, packed one row to a line.
*&
*& WHY THE READ IS REPEATED RATHER THAN THE RESULT KEPT. The result used to
*& live in a hidden model field, which meant every row crossed the wire on
*& every round trip - a press of Next, a filter, opening a judgment - and
*& that is what made a row cap necessary. Reading again costs one call to a
*& function module that was going to be called anyway; carrying the answer
*& costs the whole result on every click for as long as the citizen is on
*& the step. ZCL_RAK_CJ_PARCEL reached the same conclusion for a 677-row
*& list: "read once per round trip... holding them in the serialized app
*& state instead would put them on the wire twice per click".
*&
*& CACHED ON THE CRITERIA. Four callers want these rows in one round trip -
*& GET_TABLE( ), the pager, the filter box and ROW_CELLS( ) - and the
*& signature stops that being four reads. Keyed on the criteria rather than
*& on the request because the handler is not reliably discarded between
*& round trips; see the note at MT_FETCH.
*&
*& AND IT IS A READ-ONLY SEARCH, which is what makes repeating it safe. The
*& worst a re-read can do is pick up a judgment published since the citizen
*& pressed Search, and a list that is one round trip fresher is not a defect.
*&---------------------------------------------------------------------*
    DATA(lv_sig) = crit_sig( io_ctx ).
    IF mv_fetch_sig = lv_sig AND lv_sig IS NOT INITIAL.
      rt = mt_fetch.
      RETURN.
    ENDIF.
    CLEAR: mt_fetch, mv_fetch_sig, mv_fetch_bad.

    DATA lv_num TYPE zadtel00008n.
    DATA lv_yr  TYPE zadtel00008r.
    DATA lt_jdg TYPE zfm_judgement_publisher_t.

    lv_num = io_ctx->get_val( c_f_casenum ).
    lv_yr  = io_ctx->get_val( c_f_caseyear ).

    DATA(lt_range) = case_range( io_ctx ).

*   IV_LANGU IS 'A', UNCONDITIONALLY, BECAUSE THE WD ASKED THAT WAY. What this
*   FM composes into CASE_TEXT is "0 / 2026 مدني كلي" - a case number, a year
*   and the case type's description - and that reference is DOCUMENT DATA. It
*   is printed on the judgment, on the Adobe form and in the result list, and
*   the legacy screen shows all three in Arabic whatever the logon language.
*
*   This asked in the CITIZEN's language and fell back to Arabic only when
*   EVERY row came back with a blank CASE_TEXT. The fallback never fired,
*   because CRM does hold an English text - so an English session read
*   "0 / 2026 Total Civil Case" on a page that is otherwise an Arabic document,
*   and the same string went into the PDF. The fallback is removed with it:
*   it existed only to cover asking in a language that might have no text.

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
            iv_langu       = zcl_rak_text=>c_langu_ar
          IMPORTING
            et_zjdg        = lt_jdg.

        DATA : ls_case  TYPE LINE OF zfm_judgement_publisher_t.

        DO 4000 TIMES.
          CLEAR ls_case.

          ls_case-object_id    = |{ sy-index WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.     " 0000000001 ...
          ls_case-case_type    = 'ZDUM'.
          ls_case-zzafld00000o = sy-index.                                             " NUMC 0001 ...
          ls_case-stat         = 'E0001'.
          ls_case-posting_date = sy-datum - sy-index.
          ls_case-description  = |Dummy description { sy-index }|.
          ls_case-txt30        = |Dummy status TEXT { sy-index }|.
          ls_case-case_id      = |CASE{ sy-index WIDTH = 8 ALIGN = RIGHT PAD = '0' }|.  " CASE00000001
          ls_case-case_text    = |Dummy CASE TEXT FOR test entry NUMBER { sy-index }|.
          ls_case-zzafld000073 = sy-datum + sy-index.
          ls_case-zzafld00005j = sy-datum.

          TRY.
              ls_case-guid = cl_system_uuid=>create_uuid_x16_static( ).
            CATCH cx_uuid_error.
              CLEAR ls_case-guid.
          ENDTRY.

          APPEND ls_case TO lt_jdg.
        ENDDO.

      CATCH cx_root INTO DATA(lx_srch).
*       THE SIGNATURE IS STAMPED ON A FAILURE TOO, and that is not tidiness.
*       Four callers reach this method in one render; without the stamp each
*       would retry the failed call and add its own copy of the same error,
*       and the citizen would get the same sentence four times over an empty
*       table. Stamped, the first failure is reported once and the rest of
*       the round trip sees an empty result.
*
*       IT DOES NOT STICK, because DO_SEARCH( ) drops the cache before it
*       reads. A transient failure therefore costs one search, not the rest
*       of the session - which would otherwise be indistinguishable from
*       "no data found" and a great deal harder to report.
        mv_fetch_sig = lv_sig.
        mv_fetch_bad = abap_true.
        io_ctx->add_msg( iv_type = 'Error' iv_text = lx_srch->get_text( ) ).
        RETURN.
    ENDTRY.

*   Pack the rows. The court text is resolved through ZDT_EGA_JUD_PUBL
*   exactly as the WD resolved it: ET_ZJDG carries the case type, the
*   config table maps that to a court type, and the domain supplies the
*   text. AGE is the WD's own arithmetic - judgment date minus registration
*   date plus one - but only when BOTH dates are filled: on one missing
*   date the subtraction produces a six-digit number, which the WD would
*   have printed as the litigation period.
    DATA(lt_cfg)  = jud_cfg( ).
    DATA lv_age   TYPE i.

    LOOP AT lt_jdg INTO DATA(ls_jdg).
      DATA(lv_court_txt) = ``.
      READ TABLE lt_cfg INTO DATA(ls_map) WITH KEY case_type = ls_jdg-case_type.
      IF sy-subrc = 0.
        lv_court_txt = dom_text( iv_domain = c_dom_court
                                 iv_key    = CONV string( ls_map-court_type ) ).
      ENDIF.

*     THE LITIGATION PERIOD IS COMPUTED UNCONDITIONALLY, as the WD computed it.
*     This carried a guard - both dates filled or the cell stayed blank - written
*     to avoid the six-digit number one missing date produces. The guard was
*     wrong, and wrong in the only case the live data actually exercises: with
*     BOTH dates empty the arithmetic is 0 - 0 + 1 = 1, which is what the legacy
*     screen prints and what the citizen sees there. Suppressing it left our
*     column blank against the WD's 1 on the same case.
*     The six-digit case is real and stays: the WD printed it too, and inventing
*     a blank the legacy screen never showed is the larger error of the two.
      lv_age = ls_jdg-zzafld00005j - ls_jdg-zzafld000073 + 1.
      DATA(lv_age_txt) = |{ lv_age }|.

      DATA(lv_line) = |{ ls_jdg-guid }{ c_cell_sep }{ ls_jdg-case_text }|
                   && |{ c_cell_sep }{ lv_court_txt }|
                   && |{ c_cell_sep }{ date_ext( ls_jdg-zzafld000073 ) }|
                   && |{ c_cell_sep }{ date_ext( ls_jdg-zzafld00005j ) }|
                   && |{ c_cell_sep }{ lv_age_txt }|
                   && |{ c_cell_sep }{ ls_jdg-case_type }|.

      APPEND lv_line TO rt.
    ENDLOOP.

    mt_fetch     = rt.
    mv_fetch_sig = lv_sig.
  ENDMETHOD.


  METHOD crit_sig.
*&---------------------------------------------------------------------*
*& crit_sig — the five search criteria as one string.
*&
*& The cache key. Two searches with the same criteria return the same rows,
*& so the read can be skipped; change any criterion and the signature moves
*& and the rows are read again. The separator is the cell separator already
*& used for packing, so a value containing it cannot make two different
*& criteria sets collide - it would have to contain a NEWLINE to do that,
*& and none of the five can.
*&---------------------------------------------------------------------*
    rv = io_ctx->get_val( c_f_court )    && c_cell_sep &&
         io_ctx->get_val( c_f_classify ) && c_cell_sep &&
         io_ctx->get_val( c_f_casetype ) && c_cell_sep &&
         io_ctx->get_val( c_f_caseyear ) && c_cell_sep &&
         io_ctx->get_val( c_f_casenum ).
  ENDMETHOD.


  METHOD all_rows.
*&---------------------------------------------------------------------*
*& all_rows — every result row unpacked, in the shape GET_TABLE( ) hands
*& back. Split out of GET_TABLE( ) when paging arrived so that the window
*& and the pager's row count come from ONE reading of JUD_ROWS. Counting
*& packed lines separately would have been the shorter change and would
*& have drifted the first time a row was dropped below.
*&---------------------------------------------------------------------*
    DATA lt_cell TYPE zif_rak_journey=>tt_string.
    DATA lt_show TYPE zif_rak_journey=>tt_string.
    DATA lv_one  TYPE string.
    DATA lv_ix   TYPE i.
    DATA lv_hay  TYPE string.

*   UPPER-CASED ONCE, not per row. TO_UPPER on Arabic is a no-op, so an
*   Arabic filter matches by exact characters and an English one matches
*   whatever case the citizen typed.
    DATA(lv_filt) = to_upper( condense( io_ctx->get_val( c_f_filt ) ) ).

    DATA(lt_packed) = fetch_rows( io_ctx ).
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
      lv_ix = 1.
      WHILE lv_ix <= c_cells - 1.
        READ TABLE lt_cell INTO lv_one INDEX lv_ix.
        APPEND lv_one TO lt_show.
        lv_ix = lv_ix + 1.
      ENDWHILE.
*     THE IN-TABLE FILTER, applied HERE rather than in GET_TABLE( ) so that
*     the pager counts what the citizen can actually see. Filtering after the
*     window is picked would page through the unfiltered result and show two
*     matches on page 1 and none on page 2.
*
*     THE HAYSTACK SKIPS CELL 1, the case GUID. It is a hidden column, so a
*     filter that matched it would leave the citizen with rows that contain
*     their text nowhere on screen.
      IF lv_filt IS NOT INITIAL.
        CLEAR lv_hay.
        LOOP AT lt_show INTO DATA(lv_hcell) FROM 2.
          lv_hay = lv_hay && ` ` && lv_hcell.
        ENDLOOP.
        IF NOT to_upper( lv_hay ) CS lv_filt.
          CONTINUE.
        ENDIF.
      ENDIF.
      APPEND lt_show TO rt.
    ENDLOOP.

*   SORTED AFTER FILTERING AND BEFORE THE WINDOW IS PICKED, which is the
*   only order that makes sense: sorting first would be work thrown away on
*   rows the filter drops, and sorting after the window would order fifty
*   rows among themselves while leaving the other three thousand where they
*   were - a "sort" that moves nothing between pages.
    sort_rows( EXPORTING io_ctx = io_ctx CHANGING ct = rt ).
  ENDMETHOD.


  METHOD page_off.
*&---------------------------------------------------------------------*
*& page_off — the zero-based index of the first row now drawn.
*&
*& GUARDED, because JUD_PAGE is a model field and a model field is a string
*& that something else could have written. CONV i( ) on a non-numeric
*& string raises CX_SY_CONVERSION_NO_NUMBER and would take the whole step
*& down over a pager; anything unreadable is treated as the first page,
*& which is the state the citizen can always recover from.
*&---------------------------------------------------------------------*
    DATA(lv_raw) = condense( io_ctx->get_val( c_f_page ) ).
    IF lv_raw IS INITIAL OR lv_raw CN '0123456789'.
      RETURN.
    ENDIF.
    rv = CONV i( lv_raw ).
  ENDMETHOD.


  METHOD page_size.
*&---------------------------------------------------------------------*
*& page_size — how many rows the citizen wants drawn at once.
*&
*& ONLY THE FOUR OFFERED VALUES ARE ACCEPTED. JUD_PSIZE is a model field,
*& so its content is a string something else could have written, and an
*& arbitrary number reaching here would be a way to ask the server to build
*& four thousand rows of markup - which is the exact cost paging exists to
*& avoid. Anything not on the list reads as the default.
*&
*& THE DEFAULT IS THE OLD CONSTANT, so a citizen who never opens the picker
*& sees what they saw before, and a journey that copies this one without
*& drawing the picker needs no configuration.
*&---------------------------------------------------------------------*
    rv = c_page_size.
    DATA(lv_raw) = condense( io_ctx->get_val( c_f_psize ) ).
    IF lv_raw = '10' OR lv_raw = '25' OR lv_raw = '50' OR lv_raw = '100'.
      rv = CONV i( lv_raw ).
    ENDIF.
  ENDMETHOD.


  METHOD page_move.
*&---------------------------------------------------------------------*
*& page_move — one page back or forward, clamped at both ends.
*&
*& CLAMPED HERE RATHER THAN TRUSTED FROM THE BUTTONS. RENDER_PAGER( )
*& already disables Previous on the first page and Next on the last, but a
*& button's ENABLED state is a statement about the screen and not about the
*& model - the event can still arrive from a stale page. An offset past the
*& end would render an empty table with no way back to the rows.
*&---------------------------------------------------------------------*
    DATA(lv_total) = lines( all_rows( io_ctx ) ).
    DATA(lv_off)   = page_off( io_ctx ) + iv_by * page_size( io_ctx ).
    IF lv_off >= lv_total.
      lv_off = lv_off - page_size( io_ctx ).
    ENDIF.
    IF lv_off < 0.
      lv_off = 0.
    ENDIF.
    io_ctx->set_val( iv_name = c_f_page iv_value = |{ lv_off }| ).
  ENDMETHOD.


  METHOD render_pager.
*&---------------------------------------------------------------------*
*& render_pager — Previous / Next and the position line, under the table.
*&
*& NOTHING IS DRAWN FOR A SINGLE PAGE. A pager under a list that fits is
*& noise, and worse, it implies there is somewhere else to go.
*&
*& THE POSITION LINE IS THE POINT, not the buttons. "Showing 51-100 of 500"
*& is what tells the citizen the list did not stop; a bare Next says only
*& that something more exists. It also makes the cap visible - when the
*& search hit C_MAX_ROWS the total here and the warning strip above agree.
*&
*& BILINGUAL through PICK( ), which follows the ENGINE's resolved language
*& rather than SY-LANGU, so the pager cannot end up in a different language
*& from the table it sits under.
*&
*& EMPHASIZED, NOT TRANSPARENT, and this is the second time on this screen.
*& 'Transparent' is sap.m's default weight for a secondary action and it
*& renders as coloured text with no button behind it - on the theme's red
*& accent it reads as a link. Clear was drawn that way first and was changed
*& for the same reason; the pager repeated the mistake and is corrected the
*& same way, so all four buttons on the step now carry one weight.
*&
*& CENTRED WITH A MARGIN ON THE TEXT, not spread with SpaceBetween. The hbox
*& is only as wide as its content, so SpaceBetween had no space to
*& distribute and put both buttons hard against the label.
*&---------------------------------------------------------------------*
    DATA(lv_total) = lines( all_rows( io_ctx ) ).

*   A FILTER THAT MATCHES NOTHING NEEDS SAYING SO. Without this the citizen
*   gets column headings over blank space and no clue whether the search
*   failed, the filter is too narrow, or the screen is broken. Borrowed from
*   ZCL_RAK_CJ_PARCEL, which draws the same thing for the same reason.
    IF lv_total = 0 AND io_ctx->get_val( c_f_filt ) IS NOT INITIAL.
      io_view->illustrated_message(
        illustrationtype = 'sapIllus-NoFilterResults'
        illustrationsize = 'Spot'
        title            = zcl_rak_text=>pick( iv_base = `No judgment matches`
                                               iv_ar   = |لا يوجد حكم مطابق| )
        description      = zcl_rak_text=>pick(
          iv_base = `Clear the filter to see the whole result again.`
          iv_ar   = |امسح التصفية لعرض النتيجة كاملة مرة أخرى.| ) ).
      RETURN.
    ENDIF.

    IF lv_total <= page_size( io_ctx ).
      RETURN.
    ENDIF.

    DATA(lv_off)   = page_off( io_ctx ).
    DATA(lv_from)  = lv_off + 1.
    DATA(lv_to)    = lv_off + page_size( io_ctx ).
    IF lv_to > lv_total.
      lv_to = lv_total.
    ENDIF.

    DATA(lo_bar) = io_view->hbox( justifycontent = 'Center'
                                  alignitems     = 'Center'
                                  class          = 'sapUiSmallMarginTop' ).
    lo_bar->button(
      text     = zcl_rak_text=>pick( iv_base = `Previous` iv_ar = |السابق| )
      icon     = 'sap-icon://navigation-left-arrow'
      type     = 'Emphasized'
      enabled  = xsdbool( lv_off > 0 )
      press    = io_ctx->event( c_ev_prev ) ).
    lo_bar->text(
      class = 'sapUiMediumMarginBeginEnd'
      text  = zcl_rak_text=>pick(
                iv_base = |Showing { lv_from }-{ lv_to } of { lv_total }|
                iv_ar   = |عرض { lv_from }-{ lv_to } من { lv_total }| ) ).
    lo_bar->button(
      text      = zcl_rak_text=>pick( iv_base = `Next` iv_ar = |التالي| )
      icon      = 'sap-icon://navigation-right-arrow'
      iconfirst = abap_false
      type      = 'Emphasized'
      enabled   = xsdbool( lv_to < lv_total )
      press     = io_ctx->event( c_ev_next ) ).

*   ---- rows per page --------------------------------------------------
*   BESIDE THE PAGER, NOT WITH THE FILTER. It answers "how big is a page",
*   which is a question about this bar; the filter bar answers "which rows",
*   which is a different one. A citizen looking for it will look here.
*
*   IT IS ONLY DRAWN WITH THE PAGER, so a result that fits on one page
*   offers no way to change a page size that is not doing anything.
    DATA(lo_ps) = lo_bar->select(
      selectedkey = io_ctx->bind( c_f_psize )
      width       = '7rem'
      class       = 'sapUiMediumMarginBegin'
      change      = io_ctx->event( c_ev_psize ) ).
    LOOP AT VALUE zif_rak_journey=>tt_string( ( `10` ) ( `25` ) ( `50` ) ( `100` ) )
         INTO DATA(lv_ps).
      lo_ps->item( key  = lv_ps
                   text = zcl_rak_text=>pick( iv_base = |{ lv_ps } per page|
                                              iv_ar   = |{ lv_ps } لكل صفحة| ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_before_field.
*&---------------------------------------------------------------------*
*& on_render_before_field — the in-table filter, above the result table.
*&
*& BEFORE_FIELD( ) is called for a BLOCK field just as AFTER_FIELD( ) is -
*& ZCL_RAK_JOURNEY_RENDER ~3559, before_field( ) then render_block( ) then
*& after_field( ) - with IO_VIEW set to the block's own container. So the
*& filter lands above the table and the pager below it, which is the order
*& a reader expects and not a coincidence of the hooks.
*&---------------------------------------------------------------------*
    IF to_upper( is_field-name ) = c_f_list.
      render_filter( io_ctx = io_ctx io_view = io_view ).
    ENDIF.
  ENDMETHOD.


  METHOD col_labels.
*&---------------------------------------------------------------------*
*& col_labels — the five sortable column headings, in cell order.
*&
*& CELL 1 IS NOT HERE. It is the case GUID, hidden by the renderer, and a
*& sort on it would look random. So index 1 in this list is cell 2, and
*& SORT_ROWS( ) adds the one back.
*&
*& THE SAME WORDS AS THE COLUMN HEADERS, deliberately duplicated rather
*& than parsed back out of GET_TABLE( )'s spec strings - those carry the
*& width and alignment tokens behind a '|' and picking them apart to get a
*& label would break the moment a token is added.
*&---------------------------------------------------------------------*
    rt = VALUE #(
      ( zcl_rak_text=>pick( iv_base = `Case No.`          iv_ar = |رقم القضية| ) )
      ( zcl_rak_text=>pick( iv_base = `Court`             iv_ar = |المحكمة| ) )
      ( zcl_rak_text=>pick( iv_base = `Registration Date` iv_ar = |تاريخ التسجيل| ) )
      ( zcl_rak_text=>pick( iv_base = `Judgment Date`     iv_ar = |تاريخ الحكم| ) )
      ( zcl_rak_text=>pick( iv_base = `Litigation Period` iv_ar = |مدة التقاضي| ) ) ).
  ENDMETHOD.


  METHOD render_filter.
*&---------------------------------------------------------------------*
*& render_filter — filter and sort, above the result table.
*&
*& A PLAIN INPUT AND A BUTTON, NOT A SEARCHFIELD, and the change is the fix
*& for "the filter does nothing". A two-way binding commits on the
*& control's CHANGE event, and sap.m.SearchField raises SEARCH when its
*& magnifier is clicked WITHOUT the field having been left - so the event
*& reached the server carrying the previous value, which on the first use
*& is blank. Pressing Enter happened to work, clicking the glass did not,
*& and the two look identical to the citizen.
*&
*& A BUTTON CANNOT HAVE THAT PROBLEM: pressing it moves focus out of the
*& input, CHANGE fires, the binding commits, and only then does the event
*& go. It is the same shape as Search and Clear on the criteria above,
*& where a typed CASE_NUMBER has always reached DO_SEARCH( ) correctly -
*& so this is the mechanism already proven on this screen rather than a
*& second one. SUBMIT keeps the Enter key working, which is the habit
*& anyone typing in a box beside a magnifier already has.
*&
*& THE ENGINE TEAM HIT THE SAME WALL from the other side (commit 8638be3,
*& "the demo's search did nothing, because typing does not round-trip")
*& and answered it with an explicit button too.
*&
*& NOTHING IS DRAWN UNTIL THERE IS A RESULT - the field is hidden with the
*& table and after Clear, so this would otherwise offer to narrow nothing.
*&---------------------------------------------------------------------*
    IF io_ctx->get_val( c_f_hits ) IS INITIAL.
      RETURN.
    ENDIF.

*   ---- ICON ONLY, AND PUSHED TO THE RIGHT ------------------------------
*   THE TOOLBAR OF A SMART TABLE, which is the shape a court user has seen
*   in every other SAP list they have ever used: the actions sit top-right
*   of the table they act on, as icons, and the words live in the tooltip.
*   Five labelled buttons in a row were reading as a form to fill in rather
*   than as a toolbar, and the longest of them - "Export to Excel" - was
*   setting the height of the whole bar for a control nobody reads twice.
*
*   TOOLTIP IS NOT OPTIONAL HERE. Dropping TEXT drops the only thing naming
*   the button, so every one of them gains a TOOLTIP in the same two
*   languages the text used to carry. An icon-only button with no tooltip
*   is a guess, and it is a guess a screen reader cannot make at all.
*
*   WIDTH '100%' IS WHAT MAKES JUSTIFYCONTENT DO ANYTHING. An hbox is as
*   wide as what it holds unless it is told otherwise, and 'End' on a box
*   with no spare room has nothing to push against - the same mistake that
*   was made once on the pager and is worth not making twice.
*
*   TYPE 'Default', NOT 'Transparent'. Transparent is what a real smart
*   table uses, and this screen has already shown once (the Clear button,
*   round 18) that a transparent button on a white card reads as absent
*   rather than as quiet. A bordered button is one shade louder and cannot
*   be missed.
    DATA(lo_bar) = io_view->hbox( alignitems     = 'Center'
                                  wrap           = 'Wrap'
                                  width          = '100%'
                                  justifycontent = 'End'
                                  class          = 'sapUiSmallMarginBottom' ).

    lo_bar->input(
      value          = io_ctx->bind( c_f_filt )
      placeholder    = zcl_rak_text=>pick( iv_base = `Filter in these results`
                                           iv_ar   = |تصفية ضمن هذه النتائج| )
      showclearicon  = abap_true
      width          = '18rem'
      submit         = io_ctx->event( c_ev_filt ) ).
*   THE BUTTON STAYS, EVEN THOUGH ENTER NOW WORKS. SUBMIT covers the person
*   who types and presses Enter; it does nothing at all for the person who
*   types and reaches for the mouse, and that person currently has nothing
*   to click. It is also the button that made the filter work in the first
*   place - see the note above on SearchField - so removing it would be
*   removing the mechanism and keeping only the shortcut.
    lo_bar->button(
      icon    = 'sap-icon://filter'
      tooltip = zcl_rak_text=>pick( iv_base = `Filter` iv_ar = |تصفية| )
      type    = 'Default'
      class   = 'sapUiTinyMarginBegin'
      press   = io_ctx->event( c_ev_filt ) ).
    lo_bar->button(
      icon    = 'sap-icon://clear-filter'
      tooltip = zcl_rak_text=>pick( iv_base = `Clear filter` iv_ar = |مسح التصفية| )
      type    = 'Default'
      class   = 'sapUiTinyMarginBegin'
      enabled = xsdbool( io_ctx->get_val( c_f_filt ) IS NOT INITIAL )
      press   = io_ctx->event( c_ev_fclr ) ).

*   ---- sort -----------------------------------------------------------
*   A SELECT AND A DIRECTION TOGGLE, not clickable column headers. The
*   engine's TABLE branch builds every sap.m.Column itself out of
*   RS_DATA-COLUMNS and exposes no header press, so a heading cannot be
*   made to do anything from here. SAP.M.COLUMN does carry SORTINDICATOR,
*   but the engine passes only width and alignment through COL_SPEC( ), so
*   even the arrow is out of reach without an engine change. This is the
*   affordance that CAN be built locally, and it is the one the legacy ALV
*   offered too.
    DATA(lo_sel) = lo_bar->select(
      selectedkey = io_ctx->bind( c_f_sort )
      width       = '12rem'
      class       = 'sapUiMediumMarginBegin'
      change      = io_ctx->event( c_ev_sort ) ).
*   ITEM( ) STRAIGHT ON THE SELECT, not through ITEMS( ) - that is how
*   RENDER_ONE( ) builds every dropdown in the engine, and the aggregation
*   is implicit.
    lo_sel->item( key  = ''
                  text = zcl_rak_text=>pick( iv_base = `Sort by - none`
                                             iv_ar   = |الترتيب - بدون| ) ).
    DATA(lt_lbl) = col_labels( ).
    DATA(lv_ci)  = 0.
    LOOP AT lt_lbl INTO DATA(lv_lbl).
      lv_ci = lv_ci + 1.
      lo_sel->item( key = |{ lv_ci }| text = lv_lbl ).
    ENDLOOP.

*   THE DIRECTION TOGGLE IS THE ONE BUTTON THAT LOSES SOMETHING by shedding
*   its text, so it keeps saying which way it is pointing - in the tooltip
*   now instead of beside the icon. The icon already carries the answer, and
*   the tooltip repeats it in words for anyone the arrow does not reach.
    lo_bar->button(
      icon    = COND string( WHEN io_ctx->get_val( c_f_dir ) = 'D'
                             THEN 'sap-icon://sort-descending'
                             ELSE 'sap-icon://sort-ascending' )
      tooltip = COND string( WHEN io_ctx->get_val( c_f_dir ) = 'D'
                             THEN zcl_rak_text=>pick( iv_base = `Descending` iv_ar = |تنازلي| )
                             ELSE zcl_rak_text=>pick( iv_base = `Ascending`  iv_ar = |تصاعدي| ) )
      type    = 'Default'
      class   = 'sapUiTinyMarginBegin'
      enabled = xsdbool( io_ctx->get_val( c_f_sort ) IS NOT INITIAL )
      press   = io_ctx->event( c_ev_dir ) ).

*   ---- export ---------------------------------------------------------
*   EVERY ROW, NOT THE PAGE. See EXPORT_XLS( ) for what "every" means when a
*   filter is on.
    lo_bar->button(
      icon    = 'sap-icon://excel-attachment'
      tooltip = zcl_rak_text=>pick( iv_base = `Export to Excel` iv_ar = |تصدير إلى إكسل| )
      type    = 'Default'
      class   = 'sapUiMediumMarginBegin'
      press   = io_ctx->event( c_ev_xls ) ).
  ENDMETHOD.


  METHOD rich_esc.
*&---------------------------------------------------------------------*
*& rich_esc — a value made safe to put in a FORMATTED_TEXT( ) cell.
*&
*& TWO ESCAPES, NOT ONE, and missing either is a different failure.
*&
*&   THE HTML ENTITIES, because a rich cell is not escaped by the renderer.
*&   Without them a court name containing an ampersand or an angle bracket
*&   would be read as markup - swallowed at best, and at worst the citizen's
*&   own data deciding how the page is drawn.
*&
*&   THE BRACES, because the TEXT( ) path this replaces ran ESC( ) and the
*&   FORMATTED_TEXT( ) path does not. { and } are abap2UI5's binding
*&   delimiters, so a value carrying one would be read as a model path
*&   rather than as text. This is the escape it is easiest to forget,
*&   because nothing on screen says a binding was attempted.
*&
*& AMPERSAND FIRST, or the escaping escapes itself and < becomes &amp;lt;.
*&---------------------------------------------------------------------*
    rv = iv.
    REPLACE ALL OCCURRENCES OF `&` IN rv WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN rv WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN rv WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD hl.
*&---------------------------------------------------------------------*
*& hl — one cell, with every occurrence of the filter text marked.
*&
*& THE MATCH IS FOUND IN THE RAW VALUE AND THE PIECES ARE ESCAPED AFTER,
*& which is the only order that works. Escaping first would move every
*& offset the moment a value contained an ampersand - & becomes five
*& characters - and the mark would land beside the match rather than on it.
*&
*& A COLOURED SPAN, AND THE COLOUR IS THE PART THAT HAD TO BE CHECKED.
*& sap.m.FormattedText does not render arbitrary HTML - it sanitises
*& HTMLTEXT against a fixed list - so the list was read in OpenUI5's own
*& FormattedText.js rather than guessed at on the screen:
*&
*&   SPAN is allowed, and so are its STYLE and CLASS attributes, in BOTH
*&   the default rule set and the limited one the control uses when it
*&   carries controls of its own. So this survives either.
*&
*&   MARK IS IN NEITHER LIST, which is why the first cut of this used
*&   <strong>: a <mark> would have vanished silently, leaving a filter
*&   that highlighted nothing and no clue on screen as to why.
*&
*& STYLE RATHER THAN CLASS, and not out of preference. A class would have
*& to be defined somewhere, and the stylesheet is ZCL_RAK_JOURNEY_CSS -
*& an engine class we do not touch - so there is nowhere for this journey
*& to put one. STYLE is the half of the pair we can actually reach.
*&
*& THE DOUBLE QUOTES ARE SAFE. This string leaves as an XML attribute
*& value, and Z2UI5_CL_XML_VIEW passes every attribute through
*& ESCAPE( FORMAT = CL_ABAP_FORMAT=>E_XML_ATTR ), so a quote travels as
*& &quot; and reaches the sanitiser as a quote again. Braces get no such
*& help from anyone, which is why RICH_ESC( ) still has to do them.
*&
*& THE BOLD IS KEPT, inside the span rather than wrapped around it. On a
*& light table row the background alone is the weaker of the two signals,
*& and one tag per match is less to go wrong than two.
*&
*& EVERY OCCURRENCE, not the first. A citizen filtering on a year sees it in
*& the reference and in both dates, and marking one of the three reads as
*& the other two not being matches.
*&
*& IGNORING CASE, to agree with the filter itself - ALL_ROWS( ) compares
*& upper-cased, so a cell that was kept because it matched must be marked on
*& the same terms or a lower-case hit would be kept and not shown.
*&---------------------------------------------------------------------*
    IF iv_filt IS INITIAL OR iv_text IS INITIAL.
      rv = rich_esc( iv_text ).
      RETURN.
    ENDIF.

    DATA(lv_rest) = iv_text.
    DATA lv_off  TYPE i.
    DATA lv_len  TYPE i.

    WHILE lv_rest IS NOT INITIAL.
      FIND FIRST OCCURRENCE OF iv_filt IN lv_rest
           IGNORING CASE MATCH OFFSET lv_off MATCH LENGTH lv_len.
      IF sy-subrc <> 0.
        rv = rv && rich_esc( lv_rest ).
        EXIT.
      ENDIF.

*     A ZERO-LENGTH MATCH CANNOT HAPPEN - the caller has already tested that
*     the filter is not blank - but a WHILE that trusts that and is wrong
*     never ends, and a hung round trip is a far worse failure than a
*     missing highlight.
      IF lv_len <= 0.
        rv = rv && rich_esc( lv_rest ).
        EXIT.
      ENDIF.

      rv = rv && rich_esc( substring( val = lv_rest off = 0 len = lv_off ) )
              && c_hl_open
              && rich_esc( substring( val = lv_rest off = lv_off len = lv_len ) )
              && `</span>`.
      lv_rest = substring( val = lv_rest off = lv_off + lv_len ).
    ENDWHILE.
  ENDMETHOD.


  METHOD sort_rows.
*&---------------------------------------------------------------------*
*& sort_rows — order the filtered rows by one column.
*&
*& SORTED ON A KEY, NOT ON THE CELL. Three of the five columns do not sort
*& correctly as the text they display:
*&
*&   The two dates read dd.MM.yyyy, so as strings they order by DAY - every
*&   1st of every month together, then every 2nd. The key reverses them to
*&   yyyyMMdd, which is the only form that sorts.
*&
*&   The litigation period is a number and can be NEGATIVE - the six-digit
*&   and minus cases are both real, see the note in FETCH_ROWS( ). As a
*&   string '-198' sorts beside '-1' and after '9'. The key is an integer
*&   field, guarded with CO so a cell that is not a number cannot dump.
*&
*&   The case reference and the court are text and sort as text, upper-cased
*&   so an English filter's case does not split the order.
*&
*& STABLE ENOUGH: SORT on one key leaves equal rows in the order the
*& function module returned them, which is the order the citizen saw before
*& they sorted. Rows with an unparseable key collect at one end rather than
*& scattering.
*&---------------------------------------------------------------------*
    DATA(lv_raw) = condense( io_ctx->get_val( c_f_sort ) ).
    IF lv_raw IS INITIAL OR lv_raw CN '0123456789'.
      RETURN.
    ENDIF.
    DATA(lv_col) = CONV i( lv_raw ).
    IF lv_col < 1 OR lv_col > lines( col_labels( ) ).
      RETURN.
    ENDIF.

*   +1 because cell 1 is the hidden GUID and COL_LABELS( ) starts at cell 2.
    DATA(lv_cell) = lv_col + 1.
    DATA(lv_num)  = xsdbool( lv_col = 5 ).
    DATA(lv_date) = xsdbool( lv_col = 3 OR lv_col = 4 ).

    TYPES: BEGIN OF ty_k,
             ks  TYPE string,
             kn  TYPE i,
             row TYPE zif_rak_journey=>tt_string,
           END OF ty_k.
    DATA lt_k TYPE STANDARD TABLE OF ty_k WITH EMPTY KEY.
    DATA ls_k TYPE ty_k.

    LOOP AT ct INTO DATA(lt_row).
      CLEAR ls_k.
      ls_k-row = lt_row.
      READ TABLE lt_row INTO DATA(lv_v) INDEX lv_cell.
      IF sy-subrc <> 0.
        CLEAR lv_v.
      ENDIF.
      lv_v = condense( lv_v ).

      IF lv_num = abap_true.
        DATA(lv_sign) = 1.
        DATA(lv_dig)  = lv_v.
        IF strlen( lv_dig ) > 0 AND lv_dig(1) = '-'.
          lv_sign = -1.
          lv_dig  = lv_dig+1.
        ENDIF.
        IF lv_dig IS NOT INITIAL AND lv_dig CO '0123456789'.
          ls_k-kn = CONV i( lv_dig ) * lv_sign.
        ENDIF.
      ELSEIF lv_date = abap_true AND strlen( lv_v ) = 10.
*       dd.MM.yyyy -> yyyyMMdd. Anything else keeps a blank key and
*       collects at one end; a blank judgment date is a real row.
        ls_k-ks = lv_v+6(4) && lv_v+3(2) && lv_v(2).
      ELSE.
        ls_k-ks = to_upper( lv_v ).
      ENDIF.
      APPEND ls_k TO lt_k.
    ENDLOOP.

    DATA(lv_desc) = xsdbool( io_ctx->get_val( c_f_dir ) = 'D' ).
    IF lv_num = abap_true.
      IF lv_desc = abap_true.
        SORT lt_k BY kn DESCENDING.
      ELSE.
        SORT lt_k BY kn ASCENDING.
      ENDIF.
    ELSE.
      IF lv_desc = abap_true.
        SORT lt_k BY ks DESCENDING.
      ELSE.
        SORT lt_k BY ks ASCENDING.
      ENDIF.
    ENDIF.

    CLEAR ct.
    LOOP AT lt_k INTO ls_k.
      APPEND ls_k-row TO ct.
    ENDLOOP.
  ENDMETHOD.


  METHOD xml_esc.
*&---------------------------------------------------------------------*
*& xml_esc — the five XML character entities.
*&
*& NOT ZCL_RAK_JOURNEY_UTIL=>ESC( ), which was the first thing reached for
*& here and is the wrong tool: it escapes { and } because those are
*& abap2UI5's binding delimiters, and it does not touch & or < at all. One
*& ampersand in a court name would have produced a document Excel refuses
*& to open, with nothing on screen to say why.
*&
*& AMPERSAND FIRST, or the escaping escapes itself and < becomes &amp;lt;.
*&---------------------------------------------------------------------*
    rv = iv.
    REPLACE ALL OCCURRENCES OF `&` IN rv WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN rv WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN rv WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `&quot;`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `&apos;`.
  ENDMETHOD.


  METHOD utf8.
*&---------------------------------------------------------------------*
*& utf8 — a string as UTF-8 bytes.
*& Every part of the package is declared UTF-8 in its own XML prologue,
*& so every part has to be written in it. CONVERT_TO( ) defaults to UTF-8
*& and the default is named here rather than relied on silently.
*&---------------------------------------------------------------------*
    rv = cl_abap_codepage=>convert_to( source = iv codepage = `UTF-8` ).
  ENDMETHOD.


  METHOD cell_ref.
*&---------------------------------------------------------------------*
*& cell_ref — A1, B1, C1 ... for a 1-based column and row.
*&
*& SINGLE LETTER ONLY, and that is a decision rather than a limitation
*& nobody noticed: this sheet has five columns. Past Z the reference would
*& need two letters, so rather than write arithmetic that is never
*& exercised, the caller omits the attribute entirely - which the format
*& allows, and Excel infers position from order.
*&---------------------------------------------------------------------*
    IF iv_col < 1 OR iv_col > 26.
      RETURN.
    ENDIF.
    rv = |{ substring( val = `ABCDEFGHIJKLMNOPQRSTUVWXYZ` off = iv_col - 1 len = 1 ) }{ iv_row }|.
  ENDMETHOD.


  METHOD xlsx_bytes.
*&---------------------------------------------------------------------*
*& xlsx_bytes — the result as a real .xlsx.
*&
*& AN XLSX IS A ZIP OF XML PARTS, not one document, which is the whole
*& reason this is longer than what it replaces. The previous export wrote
*& SpreadsheetML 2003 and called it .xls: Excel opened it, but newer
*& versions first warn that "the file format and extension don't match",
*& because the extension promises a ZIP and the bytes are XML. That
*& warning is the reason for this change - the file was always readable
*& and always looked broken.
*&
*& FIVE PARTS, WHICH IS THE MINIMUM THAT OPENS. Content types, the package
*& relationship, the workbook, the workbook's relationship to its sheet,
*& and the sheet. Drop any one and Excel reports the file as corrupt
*& rather than saying which part is missing.
*&
*& INLINE STRINGS, SO THERE IS NO SIXTH PART. A normal xlsx keeps its text
*& in xl/sharedStrings.xml and each cell holds an index into it - smaller
*& for a sheet that repeats values, and an extra part and an extra
*& indirection for one that does not. t="inlineStr" puts the text in the
*& cell, which for a few thousand unique case references is both smaller
*& and much harder to get wrong.
*&
*& EVERY CELL IS A STRING, deliberately, exactly as in the version this
*& replaces: it is what stops a case reference like "0 / 2026" being read
*& as a date and a litigation period of -198 as a formula.
*&---------------------------------------------------------------------*
    DATA(lv_sheet) = |<?xml version="1.0" encoding="UTF-8" standalone="yes"?>| &&
      |<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">| &&
      |<sheetData>|.

    DATA(lv_r) = 0.

    DATA(lt_lbl) = col_labels( ).
    lv_r = 1.
    lv_sheet = lv_sheet && |<row r="{ lv_r }">|.
    DATA(lv_c) = 0.
    LOOP AT lt_lbl INTO DATA(lv_lbl).
      lv_c = lv_c + 1.
      lv_sheet = lv_sheet && |<c r="{ cell_ref( iv_col = lv_c iv_row = lv_r ) }" t="inlineStr">| &&
                 |<is><t>| && xml_esc( lv_lbl ) && |</t></is></c>|.
    ENDLOOP.
    lv_sheet = lv_sheet && |</row>|.

    LOOP AT it_row INTO DATA(lt_cell).
      lv_r = lv_r + 1.
      lv_sheet = lv_sheet && |<row r="{ lv_r }">|.
      lv_c = 0.
*     FROM 2 - cell one is the case GUID, which the table hides and nobody
*     reading a spreadsheet of judgments has any use for.
      LOOP AT lt_cell INTO DATA(lv_cell) FROM 2.
        lv_c = lv_c + 1.
        lv_sheet = lv_sheet && |<c r="{ cell_ref( iv_col = lv_c iv_row = lv_r ) }" t="inlineStr">| &&
                   |<is><t>| && xml_esc( lv_cell ) && |</t></is></c>|.
      ENDLOOP.
      lv_sheet = lv_sheet && |</row>|.
    ENDLOOP.

    lv_sheet = lv_sheet && |</sheetData></worksheet>|.

    DATA(lv_ct) = |<?xml version="1.0" encoding="UTF-8" standalone="yes"?>| &&
      |<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">| &&
      |<Default Extension="rels" | &&
      |ContentType="application/vnd.openxmlformats-package.relationships+xml"/>| &&
      |<Default Extension="xml" ContentType="application/xml"/>| &&
      |<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxml| &&
      |formats-officedocument.spreadsheetml.sheet.main+xml"/>| &&
      |<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxml| &&
      |formats-officedocument.spreadsheetml.worksheet+xml"/>| &&
      |</Types>|.

    DATA(lv_rels) = |<?xml version="1.0" encoding="UTF-8" standalone="yes"?>| &&
      |<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">| &&
      |<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/| &&
      |2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>|.

    DATA(lv_wb) = |<?xml version="1.0" encoding="UTF-8" standalone="yes"?>| &&
      |<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" | &&
      |xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">| &&
      |<sheets><sheet name="Judgments" sheetId="1" r:id="rId1"/></sheets></workbook>|.

    DATA(lv_wbr) = |<?xml version="1.0" encoding="UTF-8" standalone="yes"?>| &&
      |<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">| &&
      |<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/| &&
      |2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>|.

    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = `[Content_Types].xml`     content = utf8( lv_ct ) ).
    lo_zip->add( name = `_rels/.rels`             content = utf8( lv_rels ) ).
    lo_zip->add( name = `xl/workbook.xml`         content = utf8( lv_wb ) ).
    lo_zip->add( name = `xl/_rels/workbook.xml.rels` content = utf8( lv_wbr ) ).
    lo_zip->add( name = `xl/worksheets/sheet1.xml` content = utf8( lv_sheet ) ).
    rv = lo_zip->save( ).
  ENDMETHOD.


  METHOD export_xls.
*&---------------------------------------------------------------------*
*& export_xls — the whole result as a spreadsheet.
*&
*& EVERY ROW, NEVER THE PAGE. Paging is a property of the screen and an
*& export that honoured it would be a silent trap - the citizen who exports
*& from page three would get fifty rows and no indication that the other
*& three thousand were left behind.
*&
*& THE FILTER AND THE SORT DO APPLY, and that is deliberate rather than an
*& oversight. ALL_ROWS( ) is what the table represents, so the file matches
*& what the citizen is looking at, in the order they put it in. A filter is
*& something they asked for; a page is something the screen imposed. Clear
*& the filter and export again for the unnarrowed result.
*&
*& A REAL .XLSX, BUILT IN XLSX_BYTES( ). This wrote SpreadsheetML 2003
*& under an .xls name first. Excel opened it, and then warned every time
*& that "the file format and extension don't match" - because the extension
*& promises a ZIP and the bytes were XML. The file was always readable and
*& always looked broken, which is the worst combination to hand a citizen.
*&
*& DELIVERED THE WAY THE PDF IS, because the mechanism is already proven on
*& this screen: park the bytes in ZRAK_CJ_ATTX as a data URL and open the
*& relative ICF path that streams them. See OPEN_PDF( ) and the note on
*& OPEN_URL( ) - a browser refuses a top-level data: navigation, so the
*& URL cannot be handed over directly.
*&---------------------------------------------------------------------*
    DATA(lt_row) = all_rows( io_ctx ).
    IF lt_row IS INITIAL.
      io_ctx->add_msg(
        iv_type = 'Warning'
        iv_text = zcl_rak_text=>pick( iv_base = `There is nothing to export.`
                                      iv_ar   = |لا يوجد ما يمكن تصديره.| ) ).
      RETURN.
    ENDIF.

    DATA lv_x TYPE xstring.
    TRY.
        lv_x = xlsx_bytes( lt_row ).
      CATCH cx_root INTO DATA(lx_xl).
        io_ctx->add_msg( iv_type = 'Error' iv_text = lx_xl->get_text( ) ).
        RETURN.
    ENDTRY.
    IF lv_x IS INITIAL.
      io_ctx->add_msg(
        iv_type = 'Error'
        iv_text = zcl_rak_text=>pick( iv_base = `The export could not be built.`
                                      iv_ar   = |تعذر إنشاء ملف التصدير.| ) ).
      RETURN.
    ENDIF.

*   THE MIME TYPE MUST MATCH THE EXTENSION, which is the whole point of the
*   change from SpreadsheetML. Excel checks one against the other and warns
*   when they disagree.
    DATA(lv_b64) = |data:application/vnd.openxmlformats-officedocument.| &&
                   |spreadsheetml.sheet;base64,| &&
                   z2ui5_cl_util=>conv_encode_x_base64( lv_x ).
    DATA(lv_name) = zcl_rak_text=>pick( iv_base = `Judgments`
                                        iv_ar   = |الأحكام| ).
    DATA lv_guid TYPE string.
    DATA lv_msg  TYPE string.
    CALL METHOD zcl_rak_cj_att_store=>put
      EXPORTING
        iv_name = |{ lv_name }.xlsx|
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


  METHOD row_cells.
*&---------------------------------------------------------------------*
*& row_cells — the packed cells of one result row, found by its GUID.
*&
*& SERVED FROM FETCH_ROWS( ), so the picked row is looked up in the result
*& as it is NOW rather than as it was packed into the model. Empty when the
*& GUID is not in the result, which a stale press can genuinely produce -
*& every caller has to cope with it.
*&---------------------------------------------------------------------*
    DATA lt_cell TYPE zif_rak_journey=>tt_string.

    DATA(lt_rows) = fetch_rows( io_ctx ).
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

*   THE FILE NAME IS CHROME, NOT DOCUMENT CONTENT, so it follows the reader
*   through PICK( ) rather than being forced Arabic through OTR( ). It is what
*   the browser puts on the tab and what a download is saved as - the WD's own
*   tab reads "Verdict Preview.pdf" - and neither is part of the judgment.
*
*   Going through OTR( ) is what made ours read "cjattviewer.pdf": the name
*   stored was the Arabic, the viewer sends it as Content-Disposition
*   filename="...", and what the tab showed instead was the last segment of the
*   URL. Whether a non-ASCII name can survive that header at all is UNVERIFIED
*   from here - if an Arabic session still shows cjattviewer.pdf, that is the
*   next thing to look at and it is the engine's ZCL_RAK_CJ_ATT_HTTP, not this.
    DATA(lv_name) = zcl_rak_text=>pick( iv_base = `Verdict Preview`
                                        iv_ar   = |عرض الحكم| ).

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
*& SCOPE: this method and HEADTXT_LINE_3, the one document line that does not
*& come from an alias. It does NOT cover the two things that are chrome rather
*& than document - the View-copy button's caption and the PDF's file name -
*& which both go through PICK( ) and follow the reader. It does NOT touch the search
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
