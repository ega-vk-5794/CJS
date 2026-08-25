CLASS zcl_rak_cjs DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_step,
        seqnr         TYPE string,
        step_id       TYPE string,
        title         TYPE string,
        title_ar      TYPE string,
        icon          TYPE string,
        columns       TYPE string,
        bknd_screen   TYPE string,
*       Names a field the citizen must satisfy before the footer button leaves
*       this step. Blank on nearly every step - it exists for the payment one.
        next_requires TYPE string,
        no_forward    TYPE abap_bool,
      END OF ty_step,
      tt_step TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_fld,
        seqnr        TYPE string,
        step_id      TYPE string,
        field_name   TYPE string,
        ftype        TYPE string,
        label        TYPE string,
        label_ar     TYPE string,
        placeholder  TYPE string,
        place_ar     TYPE string,
        default_val  TYPE string,
        fgroup       TYPE string,
        section      TYPE string,
        fstate       TYPE string,
        width        TYPE string,
        hidden       TYPE abap_bool,
        readonly     TYPE abap_bool,
        required     TYPE abap_bool,
        regex        TYPE string,
        min_len      TYPE string,
        max_len      TYPE string,
        min_val      TYPE string,
        max_val      TYPE string,
        msg          TYPE string,
        msg_ar       TYPE string,
        has_attach   TYPE abap_bool,
        attach_label TYPE string,
        att_types    TYPE string,
        att_maxmb    TYPE string,
        att_multi    TYPE abap_bool,
        rollname     TYPE string,
        shlp         TYPE string,
        domname      TYPE string,
        tech_name    TYPE string,
      END OF ty_fld,
      tt_fld TYPE STANDARD TABLE OF ty_fld WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_opt,
        seqnr       TYPE string,
        step_id     TYPE string,
        field_name  TYPE string,
        opt_key     TYPE string,
        opt_text    TYPE string,
        opt_text_ar TYPE string,
      END OF ty_opt,
      tt_opt TYPE STANDARD TABLE OF ty_opt WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_col,
        seqnr      TYPE string,
        step_id    TYPE string,
        field_name TYPE string,
        col_name   TYPE string,
        label      TYPE string,
        label_ar   TYPE string,
        ctrl       TYPE string,
        shlp       TYPE string,
        rollname   TYPE string,
        width      TYPE string,
        align      TYPE string,
        hidden     TYPE abap_bool,
        pinned     TYPE abap_bool,
        readonly   TYPE abap_bool,
        required   TYPE abap_bool,
        decimals   TYPE string,
        maxlen     TYPE string,
        total      TYPE abap_bool,
      END OF ty_col,
      tt_col TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_rule,
        rule_id   TYPE string,
        src_field TYPE string,
        src_op    TYPE string,
        src_value TYPE string,
        action    TYPE string,
        tgt_field TYPE string,
        tgt_value TYPE string,
        totable   TYPE string,
      END OF ty_rule,
      tt_rule TYPE STANDARD TABLE OF ty_rule WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_jny,
        journey_id TYPE string,
        title      TYPE string,
      END OF ty_jny,
      tt_jny TYPE STANDARD TABLE OF ty_jny WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_tpl,
        id      TYPE string,
        title   TYPE string,
        sub     TYPE string,
        icon    TYPE string,
        example TYPE string,
      END OF ty_tpl,
      tt_tpl TYPE STANDARD TABLE OF ty_tpl WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_roll_hit,
        rollname TYPE string,
        ddtext   TYPE string,
        domname  TYPE string,
        fixcnt   TYPE i,
      END OF ty_roll_hit,
      tt_roll_hit TYPE STANDARD TABLE OF ty_roll_hit WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_shlp_hit,
        shlp   TYPE string,
        ddtext TYPE string,
      END OF ty_shlp_hit,
      tt_shlp_hit TYPE STANDARD TABLE OF ty_shlp_hit WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_lint,
        type TYPE string,
        text TYPE string,
      END OF ty_lint,
      tt_lint TYPE STANDARD TABLE OF ty_lint WITH EMPTY KEY,
*     A lint finding with its step and field pulled out of the message, so the
*     field list can show it against the row it belongs to. Lint itself is not
*     touched - the rules already write "STEP/FIELD: message", and reading that
*     back beats editing fifty APPEND sites.
      BEGIN OF ty_lint_row,
        step  TYPE string,
        field TYPE string,
        type  TYPE string,
        text  TYPE string,
      END OF ty_lint_row,
      tt_lint_row TYPE STANDARD TABLE OF ty_lint_row WITH EMPTY KEY,
*     One row per field carrying a value help, with what the ENGINE'S resolver
*     actually returns for it. Testing one field at a time means the field nobody
*     thinks to test is the one that ships an empty dropdown.
      BEGIN OF ty_f4_scan,
        step  TYPE string,
        field TYPE string,
        src   TYPE string,
        cnt   TYPE i,
        ok    TYPE abap_bool,
      END OF ty_f4_scan,
      tt_f4_scan TYPE STANDARD TABLE OF ty_f4_scan WITH EMPTY KEY.

    " ---- toolbar / mode ----
    DATA mv_mode    TYPE string.
    DATA mv_sel     TYPE string.
    DATA mv_dsg_step TYPE string.
    DATA mv_dsg_fld  TYPE string.
    DATA mv_dsg_dev  TYPE string.
    DATA mv_dsg_en   TYPE string.
    DATA mv_dsg_ar   TYPE string.
    DATA mv_copy_to TYPE string.

    " ---- header ----
    DATA mv_journey_id  TYPE string.
*   One row per finding, across every journey. Lint on its own answers "is THIS
*   journey sound"; nobody was ever going to open fifty journeys one at a time to
*   ask it of the landscape - which is how three services shipped with the same
*   broken table and nobody knew until a developer tripped over it.
    TYPES: BEGIN OF ty_audit,
             journey TYPE string,
             title   TYPE string,
             active  TYPE abap_bool,
             type    TYPE string,
             text    TYPE string,
           END OF ty_audit,
           tt_audit TYPE STANDARD TABLE OF ty_audit WITH EMPTY KEY.
    DATA mt_audit    TYPE tt_audit.
    DATA mv_audit_ok TYPE abap_bool.
    DATA mv_title       TYPE string.
    DATA mv_title_ar    TYPE string.
    DATA mv_subtitle    TYPE string.
    DATA mv_subtitle_ar TYPE string.
    DATA mv_layout      TYPE string.
    DATA mv_variant     TYPE string.
    DATA mv_accent      TYPE string.
    DATA mv_brand       TYPE string.
    DATA mv_navy        TYPE string.
    DATA mv_density     TYPE string.
    DATA mv_theme_own   TYPE abap_bool.
    DATA mv_theme_id    TYPE c LENGTH 20.
*   One per token, all public - _bind_edit resolves against the PUBLIC attributes
*   of the serialised instance, so a private one raises BINDING_ERROR at render.
    DATA mv_th_brand    TYPE string.
    DATA mv_th_brand_dk TYPE string.
    DATA mv_th_brand_hi TYPE string.
    DATA mv_th_brand_lt TYPE string.
    DATA mv_th_navy     TYPE string.
    DATA mv_th_navy_md  TYPE string.
    DATA mv_th_page_bg  TYPE string.
    DATA mv_th_card_bg  TYPE string.
    DATA mv_th_line     TYPE string.
    DATA mv_th_radius   TYPE string.
    DATA mv_th_shadow   TYPE string.
    DATA mv_th_font     TYPE string.
    DATA mv_th_font_ar  TYPE string.
    DATA mv_th_layout   TYPE string.
    DATA mv_th_variant  TYPE string.
    DATA mv_th_accent   TYPE string.
    DATA mv_th_density  TYPE string.
    DATA mv_th_ui5      TYPE string.
*   Not colours. CSS_MIME decides WHICH STYLESHEET is on the page and CLS_SET
*   decides WHICH CLASS NAMES the renderer writes - the two fields that turn a
*   palette into "render like the application that is already live". They carry
*   through the form for one reason: LOAD copies a preset into these variables and
*   SAVE builds the stored theme back out of them, so a field missing here is a
*   field silently dropped on the next save. Loading LEGACY and pressing Save would
*   have stored a theme that looked legacy in the Studio and rendered rak* live.
    DATA mv_th_css_mime TYPE string.
    DATA mv_th_cls_set  TYPE string.
    METHODS theme_form_load.
    METHODS theme_form_save.
    DATA mv_handler     TYPE string.
    DATA mv_show_act    TYPE abap_bool.
    DATA mv_active      TYPE abap_bool.
    DATA mv_bknd_act    TYPE abap_bool.
    DATA mv_bknd_cat    TYPE string.
    DATA mv_bknd_jny    TYPE string.
    DATA mv_bknd_fmp    TYPE string.
    DATA mv_bknd_fmr    TYPE string.
    DATA mv_tile_code   TYPE string.

    " ---- step editor ----
    DATA sv_seq      TYPE string.
    DATA sv_step     TYPE string.
    DATA sv_title    TYPE string.
    DATA sv_title_ar TYPE string.
*   Names a field the citizen must satisfy before the footer button leaves this
*   step. Blank on nearly every step - it exists for the payment one.
    DATA sv_nextreq  TYPE string.
    DATA sv_nofwd    TYPE abap_bool.
    DATA sv_icon     TYPE string.
    DATA sv_cols     TYPE string.
    DATA sv_bscreen  TYPE string.

    " ---- field editor ----
    DATA fv_seq      TYPE string.
    DATA fv_step     TYPE string.
    DATA fv_field    TYPE string.
    DATA fv_type     TYPE string.
    DATA fv_label    TYPE string.
    DATA fv_label_ar TYPE string.
    DATA fv_place    TYPE string.
    DATA fv_place_ar TYPE string.
    DATA fv_default  TYPE string.
    DATA fv_group    TYPE string.
    DATA fv_sect     TYPE string.
    DATA fv_state    TYPE string.
    DATA fv_width    TYPE string.
    DATA fv_hidden   TYPE abap_bool.
    DATA fv_readonly TYPE abap_bool.
    DATA fv_req      TYPE abap_bool.
    DATA fv_regex    TYPE string.
    DATA fv_minlen   TYPE string.
    DATA fv_maxlen   TYPE string.
    DATA fv_minval   TYPE string.
    DATA fv_maxval   TYPE string.
    DATA fv_msg      TYPE string.
    DATA fv_msg_ar   TYPE string.
    DATA fv_tech     TYPE string.
    DATA fv_roll     TYPE string.
    DATA fv_shlp     TYPE string.
    DATA fv_dom      TYPE string.
    DATA fv_hasatt   TYPE abap_bool.
    DATA fv_attlabel TYPE string.
    DATA fv_atttypes TYPE string.
    DATA fv_attmb    TYPE string.
    DATA fv_attmulti TYPE abap_bool.
    DATA mv_roll_term TYPE string.
    DATA mv_shlp_term TYPE string.
    DATA mv_fld_filter TYPE string.
    DATA mv_only_bad   TYPE abap_bool.
    DATA mv_doc        TYPE string.

    " ---- option editor ----
    DATA ov_seq     TYPE string.
    DATA ov_step    TYPE string.
    DATA ov_field   TYPE string.
    DATA ov_key     TYPE string.
    DATA ov_text    TYPE string.
    DATA ov_text_ar TYPE string.

    " ---- column editor ----
    DATA cv_seq      TYPE string.
    DATA cv_step     TYPE string.
    DATA cv_field    TYPE string.
    DATA cv_col      TYPE string.
    DATA cv_label    TYPE string.
    DATA cv_label_ar TYPE string.
    DATA cv_ctrl     TYPE string.
    DATA cv_shlp     TYPE string.
    DATA cv_rollname TYPE string.
    DATA cv_width    TYPE string.
    DATA cv_align    TYPE string.
    DATA cv_hidden   TYPE abap_bool.
    DATA cv_pinned   TYPE abap_bool.
    DATA cv_readonly TYPE abap_bool.
    DATA cv_required TYPE abap_bool.
    DATA cv_decimals TYPE string.
    DATA cv_maxlen   TYPE string.
    DATA cv_total    TYPE abap_bool.

    " ---- rule editor ----
    DATA rv_id      TYPE string.
    DATA rv_srcf    TYPE string.
    DATA rv_srcop   TYPE string.
    DATA rv_srcval  TYPE string.
    DATA rv_action  TYPE string.
    DATA rv_tgtf    TYPE string.
    DATA rv_tgtval  TYPE string.
    DATA rv_totable TYPE string.

    " ---- migration cockpit ----
    DATA mg_cat      TYPE string.
    DATA mg_jny      TYPE string.
    DATA mg_id       TYPE string.
    DATA mg_title    TYPE string.
    DATA mg_title_ar TYPE string.
    DATA mg_tile     TYPE string.
    DATA mg_dept     TYPE string.

  PRIVATE SECTION.
    DATA mo_client    TYPE REF TO z2ui5_if_client.
    DATA mv_init      TYPE abap_bool.
    DATA mv_preview   TYPE string.
    DATA mv_prev_lang TYPE string.
    DATA mv_arm_evt   TYPE string.
*   Separate from MV_ARM_EVT on purpose. MV_ARM_EVT is keyed on the event name
*   and is cleared whenever the next event differs, which is right for a row
*   delete but wrong for the save gate: it made SAVE and SAVEPREV two unrelated
*   gates, and it let an arm raised on one journey wave the next one through.
*   This one holds the journey ID that is armed.
    DATA mv_arm_save  TYPE string.
    DATA mv_msg       TYPE string.
    DATA mv_mtype     TYPE string.
    TYPES: BEGIN OF ty_dsg,
             field TYPE string,
             ftype TYPE string,
             row   TYPE i,
             col   TYPE i,
             span  TYPE i,
           END OF ty_dsg,
           tt_dsg TYPE STANDARD TABLE OF ty_dsg WITH EMPTY KEY.

    DATA mt_steps        TYPE tt_step.
    DATA mt_fields       TYPE tt_fld.
    DATA mt_opts         TYPE tt_opt.
    DATA mt_cols         TYPE tt_col.
    DATA mt_rules        TYPE tt_rule.
    DATA mt_jny          TYPE tt_jny.
    DATA mt_roll_hits    TYPE tt_roll_hit.
    DATA mt_shlp_hits    TYPE tt_shlp_hit.
    DATA mt_roll_preview TYPE zif_rak_journey=>tt_option.
    DATA mv_f4_src       TYPE string.
    DATA mt_grid_preview TYPE zif_rak_cjs_types=>tt_gcol.
    DATA mv_grid_sel     TYPE string.
    DATA mv_grid_warn    TYPE string.
*   Lint, indexed by field. Rebuilt on load and on save rather than on every
*   render: lint( ) is ~470 lines of rules and the field list redraws constantly.
    DATA mt_lint_row     TYPE tt_lint_row.
*   The findings themselves, cached alongside the index. render_lint( ) used to
*   call lint( ) again on every draw while lint_index( ) only ran on load and
*   save, so the panel and the ! column could disagree - and did, for every edit
*   made between two saves. One pass per round trip now feeds both.
    DATA mt_lint         TYPE tt_lint.
    DATA mv_lint_ok      TYPE abap_bool.
*   ShapeIt cross-check findings, from ZCL_RAK_CJS_XCHECK. Kept SEPARATE from
*   MT_LINT on purpose, for two reasons:
*
*     They describe the SAVED journey, not the draft in front of the author.
*     XCHECK re-reads ZRAK_T_JNY* from the database and compares it against
*     /QNV/SB_UI_DEFIN, so mixing it into MT_LINT would put stale findings next
*     to live ones with nothing to tell them apart.
*
*     They must NOT reach BLOCKING_COUNT( ). A brand new journey has no rows in
*     ZRAK_T_JNY yet, so XCHECK opens with "journey does not exist" - and if that
*     counted as blocking, the save gate would refuse the very first save of
*     every new journey.
    DATA mt_xchk         TYPE tt_lint.
*   Unsaved work exists. Set by every edit, cleared by load / save / new. The
*   Studio had no way to say this, and lint_all( ) used to throw it away silently.
    DATA mv_dirty        TYPE abap_bool.
*   --- Author panel state ------------------------------------------------
*   sap.m.Panel's expanded flag is written into the view at construction, and
*   abap2UI5 rebuilds the whole view on every round trip. Hard-coding it meant
*   Options, Columns and Rules snapped shut on every single event: pressing Edit
*   on an option row filled the form and then hid it, which reads as the button
*   having done nothing. The flags below survive the round trip, the EXPAND event
*   keeps them in step with what the author actually did, and the ED* handlers
*   open the panel they just filled.
    DATA mv_pn_hdr       TYPE abap_bool.
    DATA mv_pn_steps     TYPE abap_bool.
    DATA mv_pn_flds      TYPE abap_bool.
    DATA mv_pn_opts      TYPE abap_bool.
    DATA mv_pn_cols      TYPE abap_bool.
    DATA mv_pn_rules     TYPE abap_bool.
    DATA mv_pn_doc       TYPE abap_bool.
*   Panel key to bring into view on THIS render, then cleared. Empty means the
*   page keeps the scroll position it had - see SCROLL_JS.
    DATA mv_focus        TYPE string.
    DATA mt_f4_scan      TYPE tt_f4_scan.
    DATA mv_f4_scanned   TYPE abap_bool.
    DATA mv_chg_by       TYPE string.
    DATA mv_chg_at       TYPE string.
*   Version tag on the first line of an exported document. Bump it if the shape
*   of a record ever changes, so an old file is refused rather than half-read.
    CONSTANTS c_doc TYPE string VALUE '#CJS1'.
    TYPES: BEGIN OF ty_draft,
             journey_id  TYPE string,
             title       TYPE string,
             title_ar    TYPE string,
             subtitle    TYPE string,
             subtitle_ar TYPE string,
             layout      TYPE string,
             variant     TYPE string,
             accent      TYPE string,
             brand       TYPE string,
             navy        TYPE string,
             density     TYPE string,
             theme_own   TYPE abap_bool,
             handler     TYPE string,
             tile_code   TYPE string,
             show_act    TYPE abap_bool,
             active      TYPE abap_bool,
             bknd_act    TYPE abap_bool,
             bknd_cat    TYPE string,
             bknd_jny    TYPE string,
             bknd_fmp    TYPE string,
             bknd_fmr    TYPE string,
             preview     TYPE string,
             sel         TYPE string,
             dirty       TYPE abap_bool,
             steps       TYPE tt_step,
             fields      TYPE tt_fld,
             opts        TYPE tt_opt,
             cols        TYPE tt_col,
             rules       TYPE tt_rule,
           END OF ty_draft.
    DATA mt_cand         TYPE zcl_rak_migrator=>tt_candidate.

    METHODS load_list.
    METHODS load_journey IMPORTING iv_quiet TYPE abap_bool DEFAULT abap_false.
    METHODS lint_all.
    METHODS render_audit IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS new_journey.
    METHODS save_journey.
    METHODS copy_journey       IMPORTING iv_strip_handler TYPE abap_bool DEFAULT abap_false.
    METHODS free_id            IMPORTING iv_base TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS deactivate_journey.
    METHODS clear_cache.
    METHODS add_payment_step.
    METHODS to_int      IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE i.
    METHODS type_list   RETURNING VALUE(rt) TYPE string_table.
    METHODS is_input    IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS is_choice   IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS is_reserved IMPORTING iv_field TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS next_fseq   IMPORTING iv_step TYPE string RETURNING VALUE(rv) TYPE string.
*   --- side-by-side rows -------------------------------------------------
*   A shared row is a FGROUP value of the form ROW:<token>. The engine
*   (ZCL_RAK_JOURNEY_ENGINE->ROW_KEY) puts consecutive fields carrying the
*   same token into one HBox of label+control cells, and emits no core:Title
*   for them. FGROUP is doing two jobs, so a ROW: field cannot also sit under
*   a group heading - that is the price of needing no new DDIC column.
    METHODS row_tok     IMPORTING iv_group TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS row_size    IMPORTING iv_step TYPE string iv_tok TYPE string RETURNING VALUE(rv) TYPE i.
    METHODS next_rowtok IMPORTING iv_step TYPE string RETURNING VALUE(rv) TYPE string.
*   Field name immediately above iv_field in the same step, by NUMERIC seq.
*   mt_fields is sorted on seqnr as a STRING, so '100' sorts before '20' and
*   table order is not the render order - never walk mt_fields for this.
    METHODS prev_field  IMPORTING iv_step TYPE string iv_field TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS pairable    IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS toggle_pair IMPORTING iv_step TYPE string iv_field TYPE string.
    METHODS next_oseq   IMPORTING iv_step TYPE string iv_field TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS next_cseq   IMPORTING iv_step TYPE string iv_field TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS next_ruleid RETURNING VALUE(rv) TYPE string.
    METHODS field_exists IMPORTING iv_field TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS lint        RETURNING VALUE(rt) TYPE tt_lint.
    METHODS auth_ok     IMPORTING iv_actvt  TYPE activ_auth
                        RETURNING VALUE(rv) TYPE abap_bool.
    METHODS clear_field_form.
    METHODS clear_rule_form.
    METHODS css         RETURNING VALUE(rv) TYPE string.
*   Keeps the Author page where the author left it. Two jobs in one script,
*   because they are the same decision: if an event named a panel, bring that
*   panel into view; otherwise put the page back at the scroll position it had
*   before the round trip. Without the second half every button press threw the
*   author back to the top of a page that runs to sixty fields.
    METHODS scroll_js   RETURNING VALUE(rv) TYPE string.
*   Opens one Author panel and asks the page to scroll to it. Called by the ED*
*   handlers - filling a form the author cannot see is the same as doing nothing.
    METHODS focus_panel IMPORTING iv_key TYPE string.
*   Two-press confirm for a destructive action that is not a DL_ row delete. The
*   row deletes in the tables have always armed before acting; Deactivate, the
*   Design tab Clear and Import did not, and all three are irreversible from the
*   Studio. Returns TRUE only on the second press of the same button.
    METHODS armed       IMPORTING iv_ev          TYPE string
                                  iv_warn        TYPE string
                        RETURNING VALUE(rv_go)   TYPE abap_bool.
    METHODS tpl_chips   IMPORTING iv_id TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS engine_url  IMPORTING iv_journey TYPE string iv_ar TYPE abap_bool DEFAULT abap_false
                                  iv_step TYPE i DEFAULT -1
                        RETURNING VALUE(rv) TYPE string.
    METHODS render.
    METHODS render_toolbar  IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_compose  IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_style    IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_theme    IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS swatch_row      IMPORTING iv_label  TYPE string
                                      iv_value  TYPE string
                            RETURNING VALUE(rv) TYPE string.
    METHODS render_patterns IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_author   IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_lint     IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_hdr      IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_steps    IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_fields   IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_opts     IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_cols     IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_rules    IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_preview  IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_migrate  IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_design   IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS dsg_plan  IMPORTING iv_step   TYPE string
                      RETURNING VALUE(rt) TYPE tt_dsg.
    METHODS dsg_save  IMPORTING iv_step TYPE string
                                it      TYPE tt_dsg.
    METHODS dsg_clear IMPORTING iv_step TYPE string.
    METHODS dsg_event IMPORTING iv_ev TYPE string.
    METHODS search_rollname  IMPORTING iv_term   TYPE string
                             RETURNING VALUE(rt) TYPE tt_roll_hit.
    METHODS search_shlp      IMPORTING iv_term   TYPE string
                             RETURNING VALUE(rt) TYPE tt_shlp_hit.
*   Resolve whichever of the three value-help sources this field carries, THROUGH
*   THE SAME RESOLVER THE ENGINE USES. That is the whole point: preview_rollname( )
*   reads dd07l directly, which is a different path from the runtime, so it can
*   show values a citizen will never see. This cannot - if it is empty here it is
*   empty on the page.
*
*   It exists because a search help had no preview at all, and a search help whose
*   rows come only from a search help EXIT resolves to nothing while testing green
*   in SE11. That combination renders an empty dropdown and reports no error, and
*   is not discoverable until somebody opens the journey.
*   Which of the three boxes was actually used, set by preview_f4( ). A member
*   rather than an EXPORTING parameter because a method with RETURNING cannot
*   also export when it is called in an expression.
*   Parse a DEFAULT_VAL column spec with the ENGINE'S OWN parser and report what
*   it produces. Lint already catches the static faults - SEL: on the wrong
*   control, SEL: with no target, a TABLE with no spec. This answers the other
*   question: given what is actually typed, which columns appear?
*
*   DEFAULT_VAL truncates from the end without warning, which is why SEL: has to
*   come first, and a truncated spec still parses - it just quietly loses its last
*   column. Seeing the column list is the only way to notice.
    METHODS preview_grid IMPORTING iv_spec TYPE string.
*   Run lint once and index it by step/field. The Audit panel is where findings
*   go to be ignored - today a field with no tech_name sat there while the
*   journey was tested, saved and run. On the row, it is unmissable.
    METHODS lint_refresh.
*   Runs ZCL_RAK_CJS_XCHECK against the SAVED journey and caches the result in
*   MT_XCHK. Called from the two places the database state actually changes - a
*   person-initiated load and a save - and not from the per-round-trip refresh:
*   the check SELECTs the whole /QNV/SB_UI_DEFIN category, which is not a query
*   to repeat on every keystroke.
    METHODS xcheck_refresh.
    METHODS blocking_count RETURNING VALUE(rv) TYPE i.
    METHODS preview_f4 IMPORTING iv_rollname TYPE string OPTIONAL
                                 iv_shlp     TYPE string OPTIONAL
                                 iv_domname  TYPE string OPTIONAL
                       RETURNING VALUE(rt)   TYPE zif_rak_journey=>tt_option.
*   Every value help in the journey, resolved in one pass through the engine's
*   own resolver. One field at a time is the wrong granularity: the dropdown that
*   ships empty is always the one nobody thought to press Test on.
    METHODS scan_f4 RETURNING VALUE(rt) TYPE tt_f4_scan.
    METHODS render_f4_scan IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
*   lint_all( ) reloads every journey in turn to lint it. Without these it also
*   discarded whatever the author had unsaved, with no warning and no way back.
    METHODS snapshot RETURNING VALUE(rs) TYPE ty_draft.
    METHODS restore  IMPORTING is_draft TYPE ty_draft.
*   A journey as one readable document, one record per line. Today it is rows
*   across five tables: nobody can review it, diff it, or see who changed what.
*   Line-per-record rather than one JSON blob on purpose - a blob is technically
*   a document and practically undiffable, and the point of this is the diff.
*   Import loads into the draft and writes nothing; Save still has to be pressed,
*   so an imported journey goes through the same blocking-errors gate as a typed
*   one.
*   Orders steps, fields and options on the NUMERIC value of seqnr. SORT on the
*   raw string put '20' after '100', while prev_field( ) - which decides what
*   Pair joins - has always read it through to_int( ). Two orderings, and the
*   list stopped agreeing with the pairing the moment one step held both a
*   two-digit and a three-digit sequence.
    METHODS resort.
    METHODS doc_export.
    METHODS doc_import.
    METHODS render_doc IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
ENDCLASS.



CLASS ZCL_RAK_CJS IMPLEMENTATION.


  METHOD z2ui5_if_app~main.
    mo_client = client.
    IF mv_init = abap_false.
      mv_init = abap_true.
      mv_mode = 'COMPOSE'.
*     The three panels that used to be hard-coded open. Options, Columns, Rules
*     and the document stay shut until the author opens them or an ED* event
*     needs one of them.
      mv_pn_hdr   = abap_true.
      mv_pn_steps = abap_true.
      mv_pn_flds  = abap_true.
      load_list( ).
      new_journey( ).
    ENDIF.

*   The lint cache is good for exactly one round trip. Header switches are
*   two-way bound and change with no event to invalidate on, so anything that
*   trusts a cache across a round trip is trusting a guess.
    CLEAR: mv_msg, mv_mtype, mv_lint_ok.
    DATA(ev) = mo_client->get( )-event.
    IF ev <> mv_arm_evt.
      CLEAR mv_arm_evt.
    ENDIF.
*   The blocking-errors gate arms per journey, not per button, so Save and
*   Save & Preview are one gate. Anything that is not a save disarms it.
    IF ev <> 'SAVE' AND ev <> 'SAVEPREV'.
      CLEAR mv_arm_save.
    ENDIF.

*   sap.m.Panel fires EXPAND on collapse as well as on expand and does not say
*   which, so the flag is toggled rather than set. It stays in step because the
*   next render writes the flag straight back onto the panel.
    IF strlen( ev ) > 4 AND substring( val = ev len = 4 ) = 'PNL~'.
      CASE substring( val = ev off = 4 ).
        WHEN 'HDR'.   mv_pn_hdr   = xsdbool( mv_pn_hdr   = abap_false ).
        WHEN 'STEPS'. mv_pn_steps = xsdbool( mv_pn_steps = abap_false ).
        WHEN 'FLDS'.  mv_pn_flds  = xsdbool( mv_pn_flds  = abap_false ).
        WHEN 'OPTS'.  mv_pn_opts  = xsdbool( mv_pn_opts  = abap_false ).
        WHEN 'COLS'.  mv_pn_cols  = xsdbool( mv_pn_cols  = abap_false ).
        WHEN 'RULES'. mv_pn_rules = xsdbool( mv_pn_rules = abap_false ).
        WHEN 'DOC'.   mv_pn_doc   = xsdbool( mv_pn_doc   = abap_false ).
      ENDCASE.
*     Deliberately NOT returning here. MV_LINT_OK was cleared at the top of this
*     method, so a short-circuit would render the field list with an empty !
*     column and the findings would appear to have gone away. Falling through
*     reaches the lint pass at the bottom; nothing else in the chain matches a
*     PNL~ event.
    ENDIF.

    IF strlen( ev ) > 8 AND substring( val = ev len = 8 ) = 'PREVIEW_'.
      mv_preview = substring( val = ev off = 8 ).
      mv_mode = 'PREVIEW'.

    ELSEIF strlen( ev ) > 7 AND substring( val = ev len = 7 ) = 'USETPL_'.
      DATA(lv_tpl) = substring( val = ev off = 7 ).
      mv_sel = lv_tpl.
      DATA(lv_base) = lv_tpl.
      REPLACE FIRST OCCURRENCE OF 'DEMO_' IN lv_base WITH ''.
      mv_copy_to = free_id( |ZC_{ lv_base }| ).
      copy_journey( iv_strip_handler = abap_true ).
      IF mv_mtype = 'Success'.
        mv_mode = 'AUTHOR'.
        mv_msg  = |{ to_upper( mv_journey_id ) } created from { lv_tpl } — rename ID/title, then Save|.
      ENDIF.

    ELSEIF strlen( ev ) > 9 AND substring( val = ev len = 9 ) = 'PICKROLL_'.
      fv_roll = substring( val = ev off = 9 ).
      mt_roll_preview = preview_f4( iv_rollname = fv_roll ).
      CLEAR mt_roll_hits.

    ELSEIF strlen( ev ) > 9 AND substring( val = ev len = 9 ) = 'PICKSHLP_'.
      fv_shlp = substring( val = ev off = 9 ).
      CLEAR mt_shlp_hits.

    ELSEIF strlen( ev ) > 8 AND substring( val = ev len = 8 ) = 'ROWPAIR_'.
      SPLIT substring( val = ev off = 8 ) AT '~' INTO DATA(lv_rps) DATA(lv_rpf).
      toggle_pair( iv_step = lv_rps iv_field = lv_rpf ).
      IF mv_mtype = 'Success'.
        mv_dirty = abap_true.
      ENDIF.

    ELSEIF strlen( ev ) > 7 AND substring( val = ev len = 7 ) = 'DUPFLD_'.
      SPLIT substring( val = ev off = 7 ) AT '~' INTO DATA(lv_dfs) DATA(lv_dff).
      READ TABLE mt_fields INTO DATA(ls_dup) WITH KEY step_id = lv_dfs field_name = lv_dff.
      IF sy-subrc = 0.
        clear_field_form( ).
        fv_step = ls_dup-step_id. fv_field = |{ ls_dup-field_name }2|. fv_type = ls_dup-ftype.
        fv_label = ls_dup-label. fv_label_ar = ls_dup-label_ar. fv_place = ls_dup-placeholder. fv_place_ar = ls_dup-place_ar.
        fv_default = ls_dup-default_val. fv_group = ls_dup-fgroup. fv_sect = ls_dup-section.
        fv_state = ls_dup-fstate. fv_width = ls_dup-width.
        fv_hidden = ls_dup-hidden. fv_readonly = ls_dup-readonly. fv_req = ls_dup-required.
        fv_regex = ls_dup-regex. fv_minlen = ls_dup-min_len. fv_maxlen = ls_dup-max_len.
        fv_minval = ls_dup-min_val. fv_maxval = ls_dup-max_val. fv_msg = ls_dup-msg. fv_msg_ar = ls_dup-msg_ar.
        fv_tech = ls_dup-tech_name. fv_roll = ls_dup-rollname. fv_shlp = ls_dup-shlp. fv_dom = ls_dup-domname.
        fv_hasatt = ls_dup-has_attach. fv_attlabel = ls_dup-attach_label. fv_atttypes = ls_dup-att_types.
        fv_attmb = ls_dup-att_maxmb. fv_attmulti = ls_dup-att_multi.
        focus_panel( 'FLDS' ).
        mv_msg = |Duplicated { ls_dup-field_name } → rename '{ fv_field }' and Add / update field|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 7 AND substring( val = ev len = 7 ) = 'EDSTEP_'.
      DATA(lv_es) = substring( val = ev off = 7 ).
      READ TABLE mt_steps INTO DATA(ls_es) WITH KEY step_id = lv_es.
      IF sy-subrc = 0.
        sv_seq = ls_es-seqnr. sv_step = ls_es-step_id. sv_title = ls_es-title.
        sv_title_ar = ls_es-title_ar. sv_icon = ls_es-icon.
        sv_cols = ls_es-columns. sv_bscreen = ls_es-bknd_screen.
        sv_nextreq = ls_es-next_requires. sv_nofwd = ls_es-no_forward.
        focus_panel( 'STEPS' ).
        mv_msg = |Step { lv_es } loaded — change values, then Add / update step|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'EDFLD_'.
      SPLIT substring( val = ev off = 6 ) AT '~' INTO DATA(lv_efs) DATA(lv_eff).
      READ TABLE mt_fields INTO DATA(ls_ef) WITH KEY step_id = lv_efs field_name = lv_eff.
      IF sy-subrc = 0.
        fv_seq = ls_ef-seqnr. fv_step = ls_ef-step_id. fv_field = ls_ef-field_name. fv_type = ls_ef-ftype.
        fv_label = ls_ef-label. fv_label_ar = ls_ef-label_ar. fv_place = ls_ef-placeholder. fv_place_ar = ls_ef-place_ar.
        fv_default = ls_ef-default_val. fv_group = ls_ef-fgroup. fv_sect = ls_ef-section.
        fv_state = ls_ef-fstate. fv_width = ls_ef-width.
        fv_hidden = ls_ef-hidden. fv_readonly = ls_ef-readonly. fv_req = ls_ef-required.
        fv_regex = ls_ef-regex. fv_minlen = ls_ef-min_len. fv_maxlen = ls_ef-max_len.
        fv_minval = ls_ef-min_val. fv_maxval = ls_ef-max_val. fv_msg = ls_ef-msg. fv_msg_ar = ls_ef-msg_ar.
        fv_tech = ls_ef-tech_name. fv_roll = ls_ef-rollname. fv_shlp = ls_ef-shlp. fv_dom = ls_ef-domname.
        fv_hasatt = ls_ef-has_attach. fv_attlabel = ls_ef-attach_label. fv_atttypes = ls_ef-att_types.
        fv_attmb = ls_ef-att_maxmb. fv_attmulti = ls_ef-att_multi.
        focus_panel( 'FLDS' ).
        mv_msg = |Field { lv_efs }/{ lv_eff } loaded — change values, then Add / update field|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'EDOPT_'.
      SPLIT substring( val = ev off = 6 ) AT '~' INTO DATA(lv_eos) DATA(lv_eof) DATA(lv_eok).
      READ TABLE mt_opts INTO DATA(ls_eo) WITH KEY step_id = lv_eos field_name = lv_eof opt_key = lv_eok.
      IF sy-subrc = 0.
        ov_seq = ls_eo-seqnr. ov_step = ls_eo-step_id. ov_field = ls_eo-field_name.
        ov_key = ls_eo-opt_key. ov_text = ls_eo-opt_text. ov_text_ar = ls_eo-opt_text_ar.
        focus_panel( 'OPTS' ).
        mv_msg = |Option { lv_eok } loaded — change values, then Add / update option|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'EDCOL_'.
      SPLIT substring( val = ev off = 6 ) AT '~' INTO DATA(lv_ecs) DATA(lv_ecf) DATA(lv_eck).
      READ TABLE mt_cols INTO DATA(ls_ec) WITH KEY step_id = lv_ecs field_name = lv_ecf col_name = lv_eck.
      IF sy-subrc = 0.
        cv_seq = ls_ec-seqnr. cv_step = ls_ec-step_id. cv_field = ls_ec-field_name. cv_col = ls_ec-col_name.
        cv_label = ls_ec-label. cv_label_ar = ls_ec-label_ar. cv_ctrl = ls_ec-ctrl.
        cv_shlp = ls_ec-shlp. cv_rollname = ls_ec-rollname. cv_width = ls_ec-width. cv_align = ls_ec-align.
        cv_hidden = ls_ec-hidden. cv_pinned = ls_ec-pinned. cv_readonly = ls_ec-readonly. cv_required = ls_ec-required.
        cv_decimals = ls_ec-decimals. cv_maxlen = ls_ec-maxlen. cv_total = ls_ec-total.
        focus_panel( 'COLS' ).
        mv_msg = |Column { lv_eck } loaded — change values, then Add / update column|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 7 AND substring( val = ev len = 7 ) = 'EDRULE_'.
      DATA(lv_er) = substring( val = ev off = 7 ).
      READ TABLE mt_rules INTO DATA(ls_er) WITH KEY rule_id = lv_er.
      IF sy-subrc = 0.
        rv_id = ls_er-rule_id. rv_srcf = ls_er-src_field. rv_srcop = ls_er-src_op.
        rv_srcval = ls_er-src_value. rv_action = ls_er-action.
        rv_tgtf = ls_er-tgt_field. rv_tgtval = ls_er-tgt_value. rv_totable = ls_er-totable.
        focus_panel( 'RULES' ).
        mv_msg = |Rule { lv_er } loaded — change values, then Add / update rule|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 7 AND substring( val = ev len = 7 ) = 'MIGSEL_'.
      SPLIT substring( val = ev off = 7 ) AT '~' INTO DATA(lv_mc) DATA(lv_mj).
      mg_cat = lv_mc. mg_jny = lv_mj.
      mg_id  = lv_mj.
      IF strlen( lv_mj ) >= 4.
        mg_tile = |Z{ lv_mj+1(3) }|.
      ENDIF.
      mg_title = |{ lv_mj } (migrated)|.
      IF mg_dept IS INITIAL. mg_dept = '6'. ENDIF.
      mv_msg = |{ lv_mc }/{ lv_mj } loaded — the migrator prefixes with { zcl_rak_migrator=>c_sandbox }. Adjust names, then Migrate now|.
      mv_mtype = 'Information'.

    ELSEIF strlen( ev ) > 3 AND substring( val = ev len = 3 ) = 'DL_'.
      IF ev <> mv_arm_evt.
        mv_arm_evt = ev.
        mv_msg = 'Click the red delete icon again to confirm removal of this row'. mv_mtype = 'Warning'.
      ELSE.
        CLEAR mv_arm_evt.
        DATA(lv_dl) = substring( val = ev off = 3 ).
        SPLIT lv_dl AT '~' INTO TABLE DATA(lt_dk).
        CASE lt_dk[ 1 ].
          WHEN 'STEP'.
            DATA(lv_dstep) = lt_dk[ 2 ].
            DELETE mt_steps  WHERE step_id = lv_dstep.
            DELETE mt_fields WHERE step_id = lv_dstep.
            DELETE mt_opts   WHERE step_id = lv_dstep.
            DELETE mt_cols   WHERE step_id = lv_dstep.
            mv_msg = |Step { lv_dstep } and its fields/options/columns removed|. mv_mtype = 'Success'.
          WHEN 'FLD'.
            DELETE mt_fields WHERE step_id = lt_dk[ 2 ] AND field_name = lt_dk[ 3 ].
            DELETE mt_opts   WHERE step_id = lt_dk[ 2 ] AND field_name = lt_dk[ 3 ].
            DELETE mt_cols   WHERE step_id = lt_dk[ 2 ] AND field_name = lt_dk[ 3 ].
            mv_msg = |Field { lt_dk[ 3 ] } removed|. mv_mtype = 'Success'.
          WHEN 'OPT'.
            DELETE mt_opts WHERE step_id = lt_dk[ 2 ] AND field_name = lt_dk[ 3 ] AND opt_key = lt_dk[ 4 ].
            mv_msg = |Option { lt_dk[ 4 ] } removed|. mv_mtype = 'Success'.
          WHEN 'COL'.
            DELETE mt_cols WHERE step_id = lt_dk[ 2 ] AND field_name = lt_dk[ 3 ] AND col_name = lt_dk[ 4 ].
            mv_msg = |Column { lt_dk[ 4 ] } removed|. mv_mtype = 'Success'.
          WHEN 'RULE'.
            DELETE mt_rules WHERE rule_id = lt_dk[ 2 ].
            mv_msg = |Rule { lt_dk[ 2 ] } removed|. mv_mtype = 'Success'.
        ENDCASE.
        mv_dirty = abap_true.
      ENDIF.

    ELSE.
      CASE ev.
        WHEN 'M_COMPOSE'. mv_mode = 'COMPOSE'.
        WHEN 'M_AUTHOR'.  mv_mode = 'AUTHOR'.
        WHEN 'M_PREVIEW'.
          mv_mode = 'PREVIEW'.
          IF mv_preview IS INITIAL AND mv_journey_id IS NOT INITIAL.
            mv_preview = to_upper( mv_journey_id ).
          ENDIF.
        WHEN 'M_AUDIT'.
          mv_mode = 'AUDIT'.
          lint_all( ).
        WHEN 'M_DESIGN'.
          mv_mode = 'DESIGN'.
          IF mv_dsg_step IS INITIAL AND mt_steps IS NOT INITIAL.
            mv_dsg_step = mt_steps[ 1 ]-step_id.
          ENDIF.
        WHEN 'M_MIGRATE'.
          mv_mode = 'MIGRATE'.
          mt_cand = NEW zcl_rak_migrator( )->list_candidates( ).
          IF mt_cand IS INITIAL.
            mv_msg = 'No legacy journeys detected in /QNV/SB_UI_DEFIN'. mv_mtype = 'Warning'.
          ENDIF.

        WHEN 'PL_EN'. mv_prev_lang = 'EN'.
        WHEN 'PL_AR'. mv_prev_lang = 'AR'.

        WHEN 'LOAD'. load_journey( ).
        WHEN 'NEW'.  new_journey( ).
        WHEN 'SAVE'. save_journey( ).
        WHEN 'SAVEPREV'. save_journey( ). IF mv_mtype = 'Success'. mv_preview = to_upper( mv_journey_id ). mv_mode = 'PREVIEW'. ENDIF.
        WHEN 'COPY'. copy_journey( ).
        WHEN 'DEACT'.
*         Nothing selected is not something to confirm - it is something to say.
*         Arming first would ask the author to confirm deactivating a blank id, and
*         the second press would then tell them to pick a journey. DEACTIVATE_JOURNEY
*         already words that case, so let it.
          IF mv_sel IS INITIAL.
            deactivate_journey( ).
          ELSEIF armed( iv_ev   = 'DEACT'
                        iv_warn = |Deactivate { to_upper( mv_sel ) }? It disappears from launch | &&
                                  |immediately. Press Deactivate again to confirm.| ) = abap_true.
            deactivate_journey( ).
          ENDIF.
        WHEN 'CFGCLR'. clear_cache( ).
        WHEN 'THEMELOAD'.
*         Load the preset into the FORM only. Nothing is stored until Save, so a
*         preset can be inspected and adjusted before it goes live.
          DATA(lt_pre) = zcl_rak_cj_theme=>presets( ).
          READ TABLE lt_pre INTO DATA(ls_pre) WITH KEY theme_id = mv_theme_id.
          IF sy-subrc = 0.
            mv_th_brand    = ls_pre-brand.     mv_th_brand_dk = ls_pre-brand_dk.
            mv_th_brand_hi = ls_pre-brand_hi.  mv_th_brand_lt = ls_pre-brand_lt.
            mv_th_navy     = ls_pre-navy.      mv_th_navy_md  = ls_pre-navy_md.
            mv_th_page_bg  = ls_pre-page_bg.   mv_th_card_bg  = ls_pre-card_bg.
            mv_th_line     = ls_pre-line_clr.  mv_th_radius   = ls_pre-radius.
            mv_th_shadow   = ls_pre-shadow.    mv_th_font     = ls_pre-font.
            mv_th_font_ar  = ls_pre-font_ar.   mv_th_layout   = ls_pre-layout.
            mv_th_variant  = ls_pre-variant.   mv_th_accent   = ls_pre-accent.
            mv_th_density  = ls_pre-density.   mv_th_ui5      = ls_pre-ui5_theme.
            mv_th_css_mime = ls_pre-css_mime.  mv_th_cls_set  = ls_pre-cls_set.
            mv_msg   = |{ ls_pre-name } loaded into the form. Press Save to apply it.|.
            mv_mtype = 'Information'.
          ELSE.
            mv_msg = |Unknown theme { mv_theme_id }|. mv_mtype = 'Error'.
          ENDIF.
        WHEN 'THEMESAVE'. theme_form_save( ).
        WHEN 'PAYTPL'. add_payment_step( ). IF mv_mtype = 'Success'. mv_dirty = abap_true. ENDIF.

        WHEN 'CLR_STEP'. CLEAR: sv_seq, sv_step, sv_title, sv_title_ar, sv_icon, sv_cols, sv_bscreen, sv_nextreq, sv_nofwd.
        WHEN 'CLR_FLD'.  clear_field_form( ).
        WHEN 'CLR_OPT'.  CLEAR: ov_seq, ov_key, ov_text, ov_text_ar.
        WHEN 'CLR_COL'.  CLEAR: cv_seq, cv_col, cv_label, cv_label_ar, cv_ctrl, cv_shlp, cv_rollname,
                                 cv_width, cv_align, cv_hidden, cv_pinned, cv_readonly, cv_required,
                                 cv_decimals, cv_maxlen, cv_total.
        WHEN 'CLR_RULE'. clear_rule_form( ).

        WHEN 'SEARCHROLL'.
          mt_roll_hits = search_rollname( mv_roll_term ).
          IF mt_roll_hits IS INITIAL.
            mv_msg = |No data elements with fixed values found for "{ mv_roll_term }"|. mv_mtype = 'Warning'.
          ENDIF.
        WHEN 'SEARCHSHLP'.
          mt_shlp_hits = search_shlp( mv_shlp_term ).
          IF mt_shlp_hits IS INITIAL.
            mv_msg = |No search helps found for "{ mv_shlp_term }"|. mv_mtype = 'Warning'.
          ENDIF.
        WHEN 'PREVGRID'.
          IF fv_default IS INITIAL.
            mv_msg = 'Fill Default value with a column spec first'. mv_mtype = 'Warning'.
          ELSE.
            preview_grid( fv_default ).
            IF mv_grid_warn IS NOT INITIAL.
              mv_msg = mv_grid_warn. mv_mtype = 'Warning'.
            ELSEIF mt_grid_preview IS INITIAL.
              mv_msg = 'That spec produces NO columns. The grid renders a warning strip, ' &&
                       'not a table. Entries are name:label:type separated by |.'.
              mv_mtype = 'Error'.
            ELSE.
              mv_msg = |{ lines( mt_grid_preview ) } column(s)| &&
                       COND #( WHEN mv_grid_sel IS NOT INITIAL THEN |, { mv_grid_sel }| ).
              mv_mtype = 'Success'.
            ENDIF.
          ENDIF.

        WHEN 'PREVROLL'.
          IF fv_roll IS INITIAL AND fv_shlp IS INITIAL AND fv_dom IS INITIAL.
            mv_msg = 'Fill a data element, a domain or a search help first'. mv_mtype = 'Warning'.
          ELSE.
            mt_roll_preview = preview_f4( iv_rollname = fv_roll
                                          iv_shlp     = fv_shlp
                                          iv_domname  = fv_dom ).
            IF mt_roll_preview IS INITIAL.
*             Deliberately worded as a fault, not a shrug. Zero options here means
*             an empty dropdown on the page with nothing to explain it, and this
*             message is the only moment anybody is looking.
              mv_msg = |{ mv_f4_src } resolves to NO options. The dropdown will be | &&
                       |empty on the page. Check the source is spelt right and | &&
                       |sits in the correct box - and that a search help has a | &&
                       |selection method or text table, not only an exit.|.
              mv_mtype = 'Error'.
            ELSE.
              mv_msg = |{ mv_f4_src } resolves to { lines( mt_roll_preview ) } option(s)|.
              mv_mtype = 'Success'.
            ENDIF.
          ENDIF.

        WHEN 'PREVALL'.
*         Resolve every value help in the journey in one pass. A zero here is the
*         same fault the single-field test catches, found without anybody having
*         to suspect the field first.
          mt_f4_scan    = scan_f4( ).
          mv_f4_scanned = abap_true.
          IF mt_f4_scan IS INITIAL.
            mv_msg   = 'No field in this journey carries a data element, domain or search help'.
            mv_mtype = 'Information'.
          ELSE.
            DATA(lv_f4bad) = REDUCE i( INIT k = 0 FOR e IN mt_f4_scan
                                       WHERE ( ok = abap_false ) NEXT k = k + 1 ).
            mv_msg   = COND #( WHEN lv_f4bad = 0
                               THEN |All { lines( mt_f4_scan ) } value help(s) resolve to options|
                               ELSE |{ lv_f4bad } of { lines( mt_f4_scan ) } value help(s) resolve to NO options — | &&
                                    |those dropdowns render empty on the page and report nothing| ).
            mv_mtype = COND string( WHEN lv_f4bad = 0 THEN 'Success' ELSE 'Error' ).
          ENDIF.

        WHEN 'FLDFILT'.
          IF mv_fld_filter IS INITIAL.
            mv_msg = 'Filter cleared — showing every field'. mv_mtype = 'Information'.
          ENDIF.
        WHEN 'FLDBAD'.
          mv_only_bad = xsdbool( mv_only_bad = abap_false ).
        WHEN 'FLDALL'.
          CLEAR: mv_fld_filter, mv_only_bad.

        WHEN 'DOCEXP'. doc_export( ).
        WHEN 'DOCIMP'.
*         Same reasoning as DEACT: an empty box is a message, not a confirmation.
          IF mv_doc IS INITIAL.
            doc_import( ).
          ELSEIF armed( iv_ev   = 'DOCIMP'
                        iv_warn = 'Import replaces every step, field, option, column and rule in ' &&
                                  'the loaded draft. Unsaved edits are lost. Press Import again to confirm.' ) = abap_true.
            doc_import( ).
          ENDIF.

        WHEN 'MIGGO'.
          IF auth_ok( '02' ) = abap_true.
            NEW zcl_rak_migrator( )->migrate(
              EXPORTING
                iv_category = CONV #( mg_cat )
                iv_journey  = to_upper( mg_jny )
                iv_cjs_id   = mg_id
                iv_title    = mg_title
                iv_title_ar = mg_title_ar
                iv_tile     = mg_tile
                iv_dept     = mg_dept
              IMPORTING
                ev_ok       = DATA(lv_mig_ok)
                ev_msg      = mv_msg ).
            mv_mtype = COND string( WHEN lv_mig_ok = abap_true THEN 'Success' ELSE 'Error' ).
            IF lv_mig_ok = abap_true.
*             Every other write path in this class invalidates and this one did
*             not, so a re-migrate over an existing ID wrote correct rows and
*             left every work process serving the previous config. That is the
*             "moved the full content and nothing changed" report.
              DATA(lv_mig_id) = to_upper( zcl_rak_migrator=>c_sandbox && mg_id ).
              zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_mig_id ).
              load_list( ).
              mt_cand = NEW zcl_rak_migrator( )->list_candidates( ).
              mv_preview = lv_mig_id.
              CLEAR: mg_cat, mg_jny, mg_id, mg_title, mg_title_ar, mg_tile.
            ENDIF.
          ENDIF.

        WHEN 'ASTEP'.
          IF sv_step IS NOT INITIAL.
            READ TABLE mt_steps ASSIGNING FIELD-SYMBOL(<s>) WITH KEY step_id = to_upper( sv_step ).
            IF sy-subrc <> 0. APPEND INITIAL LINE TO mt_steps ASSIGNING <s>. ENDIF.
            <s> = VALUE #( seqnr = sv_seq step_id = to_upper( sv_step ) title = sv_title title_ar = sv_title_ar
                           icon = sv_icon columns = sv_cols bknd_screen = to_upper( sv_bscreen )
                           next_requires = to_upper( sv_nextreq ) no_forward = sv_nofwd ).
            resort( ).
            CLEAR: sv_seq, sv_step, sv_title, sv_title_ar, sv_icon, sv_cols, sv_bscreen, sv_nextreq, sv_nofwd.
            mv_dirty = abap_true.
          ENDIF.

        WHEN 'AFLD'.
          IF fv_step IS NOT INITIAL AND fv_field IS NOT INITIAL.
            IF is_reserved( fv_field ) = abap_true AND to_upper( fv_type ) <> 'PAYFEE'
               AND to_upper( fv_field ) <> 'PAYFEE'.
              mv_msg = |'{ to_upper( fv_field ) }' is a framework-reserved name. Use "Add payment step" instead.|.
              mv_mtype = 'Warning'.
            ELSE.
              READ TABLE mt_fields ASSIGNING FIELD-SYMBOL(<f>) WITH KEY step_id = to_upper( fv_step ) field_name = to_upper( fv_field ).
              IF sy-subrc <> 0. APPEND INITIAL LINE TO mt_fields ASSIGNING <f>. ENDIF.
              DATA(lv_fseq) = COND string( WHEN fv_seq IS NOT INITIAL THEN fv_seq ELSE next_fseq( fv_step ) ).
              <f> = VALUE #( seqnr = lv_fseq step_id = to_upper( fv_step ) field_name = to_upper( fv_field )
                             ftype = to_upper( fv_type ) label = fv_label label_ar = fv_label_ar
                             placeholder = fv_place place_ar = fv_place_ar default_val = fv_default
                             fgroup = fv_group section = fv_sect fstate = fv_state width = fv_width
                             hidden = fv_hidden readonly = fv_readonly required = fv_req
                             regex = fv_regex min_len = fv_minlen max_len = fv_maxlen
                             min_val = fv_minval max_val = fv_maxval msg = fv_msg msg_ar = fv_msg_ar
                             has_attach = fv_hasatt attach_label = fv_attlabel att_types = fv_atttypes
                             att_maxmb = fv_attmb att_multi = fv_attmulti
                             rollname = to_upper( fv_roll ) shlp = to_upper( fv_shlp ) domname = to_upper( fv_dom ) tech_name = fv_tech ).
              resort( ).
              clear_field_form( ).
              CLEAR: mv_roll_term, mt_roll_hits, mt_roll_preview, mv_shlp_term, mt_shlp_hits.
              mv_dirty = abap_true.
            ENDIF.
          ENDIF.

        WHEN 'AOPT'.
          IF ov_step IS NOT INITIAL AND ov_field IS NOT INITIAL AND ov_key IS NOT INITIAL.
            READ TABLE mt_opts ASSIGNING FIELD-SYMBOL(<o>) WITH KEY step_id = to_upper( ov_step ) field_name = to_upper( ov_field ) opt_key = ov_key.
            IF sy-subrc <> 0. APPEND INITIAL LINE TO mt_opts ASSIGNING <o>. ENDIF.
            DATA(lv_oseq) = COND string( WHEN ov_seq IS NOT INITIAL THEN ov_seq ELSE next_oseq( iv_step = ov_step iv_field = ov_field ) ).
            <o> = VALUE #( seqnr = lv_oseq step_id = to_upper( ov_step ) field_name = to_upper( ov_field )
                           opt_key = ov_key opt_text = ov_text opt_text_ar = ov_text_ar ).
            resort( ).
            CLEAR: ov_seq, ov_key, ov_text, ov_text_ar.
            mv_dirty = abap_true.
          ENDIF.

        WHEN 'ACOL'.
          IF cv_step IS NOT INITIAL AND cv_field IS NOT INITIAL AND cv_col IS NOT INITIAL.
            READ TABLE mt_cols ASSIGNING FIELD-SYMBOL(<c>) WITH KEY step_id = to_upper( cv_step ) field_name = to_upper( cv_field ) col_name = to_upper( cv_col ).
            IF sy-subrc <> 0. APPEND INITIAL LINE TO mt_cols ASSIGNING <c>. ENDIF.
            DATA(lv_cseq) = COND string( WHEN cv_seq IS NOT INITIAL THEN cv_seq ELSE next_cseq( iv_step = cv_step iv_field = cv_field ) ).
            <c> = VALUE #( seqnr = lv_cseq step_id = to_upper( cv_step ) field_name = to_upper( cv_field )
                           col_name = to_upper( cv_col ) label = cv_label label_ar = cv_label_ar
                           ctrl = to_upper( cv_ctrl ) shlp = to_upper( cv_shlp ) rollname = to_upper( cv_rollname )
                           width = cv_width align = cv_align hidden = cv_hidden pinned = cv_pinned
                           readonly = cv_readonly required = cv_required decimals = cv_decimals maxlen = cv_maxlen
                           total = cv_total ).
            resort( ).
            CLEAR: cv_seq, cv_col, cv_label, cv_label_ar, cv_ctrl, cv_shlp, cv_rollname,
                   cv_width, cv_align, cv_hidden, cv_pinned, cv_readonly, cv_required,
                   cv_decimals, cv_maxlen, cv_total.
            mv_dirty = abap_true.
          ELSE.
            mv_msg = 'A column needs a step, a grid field and a column name'. mv_mtype = 'Warning'.
          ENDIF.

        WHEN 'ARULE'.
          IF rv_srcf IS NOT INITIAL AND rv_action IS NOT INITIAL.
            DATA(lv_rid) = COND string( WHEN rv_id IS NOT INITIAL THEN to_upper( rv_id ) ELSE next_ruleid( ) ).
            READ TABLE mt_rules ASSIGNING FIELD-SYMBOL(<r>) WITH KEY rule_id = lv_rid.
            IF sy-subrc <> 0. APPEND INITIAL LINE TO mt_rules ASSIGNING <r>. ENDIF.
            <r> = VALUE #( rule_id = lv_rid src_field = to_upper( rv_srcf ) src_op = rv_srcop src_value = rv_srcval
                           action = rv_action tgt_field = to_upper( rv_tgtf ) tgt_value = rv_tgtval totable = rv_totable ).
            SORT mt_rules BY rule_id.
            clear_rule_form( ).
            mv_dirty = abap_true.
          ELSE.
            mv_msg = 'A rule needs at least a source field and an action'. mv_mtype = 'Warning'.
          ENDIF.

        WHEN OTHERS.
          dsg_event( ev ).
      ENDCASE.
    ENDIF.

*   Exactly one lint pass per round trip in Author, feeding both the Validation
*   panel and the ! column from the same result. load_journey( ) and
*   save_journey( ) run it themselves and set the flag, so this does not repeat it.
    IF mv_mode = 'AUTHOR' AND mv_lint_ok = abap_false.
      lint_refresh( ).
    ENDIF.

    render( ).
  ENDMETHOD.


  METHOD deactivate_journey.
    IF auth_ok( '02' ) = abap_false.
      RETURN.
    ENDIF.
    IF mv_sel IS INITIAL.
      mv_msg = 'Pick a journey to deactivate'. mv_mtype = 'Warning'. RETURN.
    ENDIF.
    UPDATE zrak_t_jny SET active = ' ' WHERE journey_id = @mv_sel.
    COMMIT WORK.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = mv_sel ).
    load_list( ).
    mv_msg = |{ mv_sel } deactivated — hidden from launch, still here to re-activate (load + Save)|. mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD load_list.
    SELECT journey_id, title, active FROM zrak_t_jny ORDER BY journey_id INTO TABLE @DATA(lt).
    CLEAR mt_jny.
    LOOP AT lt INTO DATA(ls).
      APPEND VALUE #( journey_id = ls-journey_id
                      title      = COND string( WHEN ls-active = 'X' THEN ls-title
                                                ELSE |{ ls-title } (inactive)| ) ) TO mt_jny.
    ENDLOOP.
  ENDMETHOD.


  METHOD new_journey.
    CLEAR: mv_journey_id, mv_title, mv_title_ar, mv_subtitle, mv_subtitle_ar, mv_handler,
           mt_steps, mt_fields, mt_opts, mt_cols, mt_rules, mv_preview, mv_tile_code,
           mv_bknd_act, mv_bknd_cat, mv_bknd_jny, mv_bknd_fmp, mv_bknd_fmr,
           mv_roll_term, mt_roll_hits, mt_roll_preview, mv_shlp_term, mt_shlp_hits,
           mt_lint, mt_lint_row, mt_xchk, mv_dirty, mt_f4_scan, mv_f4_scanned,
           mv_fld_filter, mv_only_bad, mv_doc, mv_chg_by, mv_chg_at.
    clear_field_form( ).
    clear_rule_form( ).
    CLEAR: sv_seq, sv_step, sv_title, sv_title_ar, sv_icon, sv_cols, sv_bscreen,
           ov_seq, ov_step, ov_field, ov_key, ov_text, ov_text_ar,
           cv_seq, cv_step, cv_field, cv_col, cv_label, cv_label_ar, cv_ctrl, cv_shlp, cv_rollname,
           cv_width, cv_align, cv_hidden, cv_pinned, cv_readonly, cv_required, cv_decimals, cv_maxlen, cv_total.
    mv_layout = 'WIZARD'. mv_variant = 'CLEAN'. mv_accent = 'Emphasized'.
    mv_brand = 'rgb(196,30,38)'. mv_navy = 'rgb(16,35,62)'. mv_density = 'Cozy'.
    mv_show_act = abap_true. mv_active = abap_true. mv_theme_own = abap_false.
  ENDMETHOD.


  METHOD load_journey.
    IF mv_sel IS INITIAL.
      mv_msg = 'Pick a journey to load'. mv_mtype = 'Warning'. RETURN.
    ENDIF.
    SELECT SINGLE * FROM zrak_t_jny INTO @DATA(h) WHERE journey_id = @mv_sel.
    IF sy-subrc <> 0.
      mv_msg = 'Journey not found'. mv_mtype = 'Error'. RETURN.
    ENDIF.
    CLEAR: mt_steps, mt_fields, mt_opts, mt_cols, mt_rules.
    mv_journey_id = h-journey_id. mv_title = h-title. mv_title_ar = h-title_ar.
    mv_layout = h-layout_mode. mv_variant = h-theme_variant. mv_accent = h-accent_type.
    mv_brand = h-brand_color. mv_navy = h-navy_color. mv_density = h-density.
    mv_theme_own = xsdbool( h-theme_own = 'X' ).
    mv_subtitle = h-subtitle. mv_subtitle_ar = h-subtitle_ar. mv_handler = h-handler_class.
    mv_show_act = xsdbool( h-show_actions = 'X' ). mv_active = xsdbool( h-active = 'X' ).
    mv_bknd_act = xsdbool( h-bknd_active = 'X' ).
    mv_bknd_cat = h-bknd_category. mv_bknd_jny = h-bknd_journey.
    mv_bknd_fmp = h-bknd_fm_post.  mv_bknd_fmr = h-bknd_fm_read.
    mv_tile_code = h-tile_code.

    mv_chg_by = h-changed_by.
    CLEAR mv_chg_at.
    IF h-changed_at IS NOT INITIAL.
      CONVERT TIME STAMP h-changed_at TIME ZONE sy-zonlo
              INTO DATE DATA(lv_cd) TIME DATA(lv_ct).
      mv_chg_at = |{ lv_cd DATE = USER } { lv_ct TIME = USER }|.
    ENDIF.

    SELECT * FROM zrak_t_jny_step INTO TABLE @DATA(ls) WHERE journey_id = @mv_sel ORDER BY seqnr.
    LOOP AT ls INTO DATA(s).
      APPEND VALUE #( seqnr = |{ s-seqnr }| step_id = s-step_id title = s-title title_ar = s-title_ar
                      icon = s-icon columns = |{ s-columns }| bknd_screen = s-bknd_screen
                      next_requires = s-next_requires no_forward = s-no_forward ) TO mt_steps.
    ENDLOOP.
    SELECT * FROM zrak_t_jny_fld INTO TABLE @DATA(lf) WHERE journey_id = @mv_sel ORDER BY step_id, seqnr.
    LOOP AT lf INTO DATA(f).
      APPEND VALUE #( seqnr = |{ f-seqnr }| step_id = f-step_id field_name = f-field_name ftype = f-ftype
                      label = f-zlabel label_ar = f-zlabel_ar placeholder = f-placeholder place_ar = f-placeholder_ar
                      default_val = f-default_val fgroup = f-fgroup section = f-zsection fstate = f-fstate width = f-width
                      hidden = xsdbool( f-hidden = 'X' ) readonly = xsdbool( f-readonly = 'X' ) required = xsdbool( f-required = 'X' )
                      regex = f-regex min_len = |{ f-min_len }| max_len = |{ f-max_len }| min_val = f-min_val max_val = f-max_val
                      msg = f-msg msg_ar = f-msg_ar
                      has_attach = xsdbool( f-has_attach = 'X' ) attach_label = f-attach_label att_types = f-attach_types
                      att_maxmb = |{ f-attach_maxmb }| att_multi = xsdbool( f-attach_multi = 'X' )
                      rollname = f-rollname shlp = f-shlp domname = f-domname tech_name = f-tech_name ) TO mt_fields.
    ENDLOOP.
    SELECT * FROM zrak_t_jny_opt INTO TABLE @DATA(lo) WHERE journey_id = @mv_sel ORDER BY step_id, field_name, seqnr.
    LOOP AT lo INTO DATA(o).
      APPEND VALUE #( seqnr = |{ o-seqnr }| step_id = o-step_id field_name = o-field_name
                      opt_key = o-opt_key opt_text = o-opt_text opt_text_ar = o-opt_text_ar ) TO mt_opts.
    ENDLOOP.
    SELECT * FROM zrak_t_jny_col INTO TABLE @DATA(lc) WHERE journey_id = @mv_sel ORDER BY step_id, field_name, seqnr.
    LOOP AT lc INTO DATA(c).
      APPEND VALUE #( seqnr = |{ c-seqnr }| step_id = c-step_id field_name = c-field_name col_name = c-col_name
                      label = c-zlabel label_ar = c-zlabel_ar ctrl = c-ctrl shlp = c-shlp rollname = c-rollname
                      width = c-width align = c-align
                      hidden = xsdbool( c-hidden = 'X' ) pinned = xsdbool( c-pinned = 'X' )
                      readonly = xsdbool( c-readonly = 'X' ) required = xsdbool( c-required = 'X' )
                      decimals = |{ c-decimals }| maxlen = |{ c-maxlen }|
                      total = xsdbool( c-total = 'X' ) ) TO mt_cols.
    ENDLOOP.
    SELECT * FROM zrak_t_jny_rule INTO TABLE @DATA(lr) WHERE journey_id = @mv_sel ORDER BY rule_id.
    LOOP AT lr INTO DATA(r).
      APPEND VALUE #( rule_id = r-rule_id src_field = r-src_field src_op = r-src_op src_value = r-src_value
                      action = r-action tgt_field = r-tgt_field tgt_value = r-tgt_value totable = r-totable ) TO mt_rules.
    ENDLOOP.
*   The database ORDER BY sorts the stored column, which is padded or
*   right-aligned and therefore already numeric-correct. The draft is not: an
*   author types 20, not 020. Re-ordering here means the list looks the same
*   before a save and after one, which it did not.
    resort( ).

    mv_preview = mv_journey_id.
    CLEAR: mv_dirty, mt_f4_scan, mv_f4_scanned, mv_fld_filter, mv_only_bad.

*   lint_all( ) reloads fifty journeys in a loop and lints each one itself.
*   Without this it linted every one of them twice and wrote a message nobody
*   would ever see, once per journey.
    IF iv_quiet = abap_true.
      RETURN.
    ENDIF.

*   Invalidate on LOAD, and it is not redundant with the Save that may follow.
*
*   This method reads the five tables DIRECTLY, so the Studio has always shown
*   the truth and never needed the cache cleared for its own sake. Preview and
*   the live journey both go through zcl_rak_cj_cfg_cache=>get( ), and they are
*   the two places an author looks next.
*
*   So what this buys is: what you have just loaded is what Preview will render.
*   Without it, loading a journey that a seed report rewrote an hour ago shows
*   the new config in Author and the old one in Preview - and two halves of the
*   Studio disagreeing is a very slow thing to work out.
*
*   AFTER the iv_quiet return, deliberately. Quiet is the bulk path - lint_all( )
*   walks every journey in the system through here - and invalidating inside that
*   loop is the blanket flush avoided everywhere else: every work process
*   rebuilding every journey because somebody pressed Audit all.
*
*   The rule, then: a load a PERSON asked for clears the cache; a load the Studio
*   did to itself does not.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = mv_sel ).

    lint_refresh( ).
    xcheck_refresh( ).
    mv_msg = |Loaded { mv_sel }|.
    DATA(lv_bad) = REDUCE i( INIT k = 0 FOR w IN mt_lint_row
                             WHERE ( type = 'Error' ) NEXT k = k + 1 ).
*   Say it on load, not only in the Audit panel. A journey opened with findings
*   already against its fields should announce that before anybody edits it.
    IF mt_lint_row IS NOT INITIAL.
      mv_msg = |{ mv_msg } — { lines( mt_lint_row ) } field finding(s)| &&
               COND string( WHEN lv_bad > 0 THEN |, { lv_bad } blocking| ) &&
               |. See the ! column.|.
      mv_mtype = COND string( WHEN lv_bad > 0 THEN 'Warning' ELSE 'Information' ).
    ELSE.
      mv_mtype = 'Success'.
    ENDIF.
  ENDMETHOD.


  METHOD save_journey.
    IF auth_ok( '02' ) = abap_false.
      RETURN.
    ENDIF.
    IF mv_journey_id IS INITIAL.
      mv_msg = 'Journey ID is required'. mv_mtype = 'Error'. RETURN.
    ENDIF.
    IF mt_steps IS INITIAL.
      mv_msg = 'Add at least one step before saving'. mv_mtype = 'Warning'. RETURN.
    ENDIF.

*   --- blocking findings gate -------------------------------------------------
*   A journey with errors renders, posts and looks correct - it just does not do
*   what the configuration says. That is the whole class of fault this Studio
*   exists for, and reporting it in a panel was not enough: a field with no
*   tech_name sat in one all afternoon while the journey was tested, saved and
*   run. First press refuses and says how many; second press saves anyway, the
*   same two-click confirm used for row deletion. Lint is re-run here rather than
*   trusting the cached pass, because the header switches are two-way bound and
*   change with no event that would have invalidated it.
    lint_refresh( ).
    DATA(jid)     = to_upper( mv_journey_id ).
    DATA(lv_gate) = blocking_count( ).
    IF lv_gate > 0 AND mv_arm_save <> jid.
      mv_arm_save = jid.
*     Warning, not Error, and it says outright that nothing was written. As an
*     Error next to a red icon this read as a failed save, so authors walked
*     away from a journey that had never been written and then reported the
*     config as stale.
      mv_msg      = |Nothing saved yet — { lv_gate } blocking error(s) in { jid }. Open Validation, or use | &&
                    |Findings only in the field list. Fix them, or press Save again to save regardless.|.
      mv_mtype    = 'Warning'.
      RETURN.
    ENDIF.
    CLEAR mv_arm_save.

*   --- serialise concurrent authors -------------------------------------------
*   This method is DELETE x5 + INSERT x5. Without a lock two authors silently
*   overwrite each other and the loser never finds out.
    DATA lv_key TYPE rstable-varkey.
    DATA lv_err TYPE abap_bool.
    lv_key = jid.

    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = 'ZRAK_T_JNY'
        varkey         = lv_key
        _scope         = '1'
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      mv_msg   = |{ jid } is being edited by { sy-msgv1 } — try again in a moment|.
      mv_mtype = 'Error'.
      RETURN.
    ENDIF.

    DELETE FROM zrak_t_jny      WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_step WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_fld  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_opt  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_col  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_rule WHERE journey_id = @jid.

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    INSERT zrak_t_jny FROM @( VALUE #( mandt = sy-mandt journey_id = jid title = mv_title title_ar = mv_title_ar
      layout_mode = mv_layout theme_variant = mv_variant accent_type = mv_accent brand_color = mv_brand
      navy_color = mv_navy density = mv_density subtitle = mv_subtitle subtitle_ar = mv_subtitle_ar
      theme_own     = COND string( WHEN mv_theme_own = abap_true THEN 'X' ELSE ' ' )
      handler_class = to_upper( mv_handler )
      show_actions  = COND string( WHEN mv_show_act = abap_true THEN 'X' ELSE ' ' )
      active        = COND string( WHEN mv_active   = abap_true THEN 'X' ELSE ' ' )
      bknd_active   = COND string( WHEN mv_bknd_act = abap_true THEN 'X' ELSE ' ' )
      bknd_category = mv_bknd_cat
      bknd_journey  = to_upper( mv_bknd_jny )
      bknd_fm_post  = to_upper( mv_bknd_fmp )
      bknd_fm_read  = to_upper( mv_bknd_fmr )
      tile_code     = to_upper( mv_tile_code )
      changed_by    = sy-uname
      changed_at    = lv_now ) ).
    IF sy-subrc <> 0.
      lv_err = abap_true.
    ENDIF.

    LOOP AT mt_steps INTO DATA(s).
      INSERT zrak_t_jny_step FROM @( VALUE #( mandt = sy-mandt journey_id = jid step_id = s-step_id
        seqnr = to_int( s-seqnr ) title = s-title title_ar = s-title_ar icon = s-icon
        columns = to_int( s-columns ) bknd_screen = s-bknd_screen
        next_requires = s-next_requires no_forward = s-no_forward ) ).
      IF sy-subrc <> 0.
        lv_err = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_fields INTO DATA(f).
      INSERT zrak_t_jny_fld FROM @( VALUE #( mandt = sy-mandt journey_id = jid step_id = f-step_id
        field_name = f-field_name seqnr = to_int( f-seqnr ) ftype = f-ftype
        zlabel = f-label zlabel_ar = f-label_ar placeholder = f-placeholder placeholder_ar = f-place_ar
        default_val = f-default_val fgroup = f-fgroup zsection = f-section fstate = f-fstate width = f-width
        hidden   = COND string( WHEN f-hidden   = abap_true THEN 'X' ELSE ' ' )
        readonly = COND string( WHEN f-readonly = abap_true THEN 'X' ELSE ' ' )
        required = COND string( WHEN f-required = abap_true THEN 'X' ELSE ' ' )
        regex = f-regex min_len = to_int( f-min_len ) max_len = to_int( f-max_len )
        min_val = f-min_val max_val = f-max_val msg = f-msg msg_ar = f-msg_ar
        has_attach = COND string( WHEN f-has_attach = abap_true THEN 'X' ELSE ' ' )
        attach_label = f-attach_label attach_types = f-att_types attach_maxmb = to_int( f-att_maxmb )
        attach_multi = COND string( WHEN f-att_multi = abap_true THEN 'X' ELSE ' ' )
        rollname = f-rollname shlp = f-shlp domname = f-domname tech_name = f-tech_name ) ).
      IF sy-subrc <> 0.
        lv_err = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_opts INTO DATA(o).
      INSERT zrak_t_jny_opt FROM @( VALUE #( mandt = sy-mandt journey_id = jid step_id = o-step_id
        field_name = o-field_name opt_key = o-opt_key seqnr = to_int( o-seqnr )
        opt_text = o-opt_text opt_text_ar = o-opt_text_ar ) ).
      IF sy-subrc <> 0.
        lv_err = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_cols INTO DATA(c).
      INSERT zrak_t_jny_col FROM @( VALUE #( mandt = sy-mandt journey_id = jid step_id = c-step_id
        field_name = c-field_name col_name = c-col_name seqnr = to_int( c-seqnr )
        zlabel = c-label zlabel_ar = c-label_ar ctrl = c-ctrl shlp = c-shlp rollname = c-rollname
        width = c-width align = c-align
        hidden   = COND string( WHEN c-hidden   = abap_true THEN 'X' ELSE ' ' )
        pinned   = COND string( WHEN c-pinned   = abap_true THEN 'X' ELSE ' ' )
        readonly = COND string( WHEN c-readonly = abap_true THEN 'X' ELSE ' ' )
        required = COND string( WHEN c-required = abap_true THEN 'X' ELSE ' ' )
        decimals = to_int( c-decimals ) maxlen = to_int( c-maxlen )
        total    = COND string( WHEN c-total    = abap_true THEN 'X' ELSE ' ' ) ) ).
      IF sy-subrc <> 0.
        lv_err = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_rules INTO DATA(r).
      INSERT zrak_t_jny_rule FROM @( VALUE #( mandt = sy-mandt journey_id = jid rule_id = r-rule_id
        src_field = r-src_field src_op = r-src_op src_value = r-src_value action = r-action
        tgt_field = r-tgt_field tgt_value = r-tgt_value totable = r-totable ) ).
      IF sy-subrc <> 0.
        lv_err = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

*   --- all or nothing --------------------------------------------------------
*   The DELETEs already ran. If any INSERT failed (duplicate key from two rows
*   with the same step/field/option) COMMIT here would leave a half-saved,
*   silently broken journey live for citizens.
    IF lv_err = abap_true.
      ROLLBACK WORK.
      CALL FUNCTION 'DEQUEUE_E_TABLE'
        EXPORTING
          mode_rstable = 'E'
          tabname      = 'ZRAK_T_JNY'
          varkey       = lv_key
          _scope       = '1'.
      mv_msg   = |Save failed for { jid } — nothing was written. Look for two rows sharing a step ID, field name or option key.|.
      mv_mtype = 'Error'.
      RETURN.
    ENDIF.

    COMMIT WORK AND WAIT.
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = 'ZRAK_T_JNY'
        varkey       = lv_key
        _scope       = '1'.

    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = jid ).
    load_list( ). mv_sel = jid.
    lint_refresh( ).
    xcheck_refresh( ).
    CLEAR mv_dirty.
    mv_msg = |Saved { jid } — { lines( mt_steps ) } steps, { lines( mt_fields ) } fields, { lines( mt_rules ) } rules| &&
             COND string( WHEN mt_lint IS NOT INITIAL
                          THEN |. { lines( mt_lint ) } finding(s) still open| ).
    mv_mtype = COND string( WHEN blocking_count( ) > 0 THEN 'Warning' ELSE 'Success' ).
  ENDMETHOD.


  METHOD copy_journey.
    IF auth_ok( '02' ) = abap_false.
      RETURN.
    ENDIF.
    IF mv_sel IS INITIAL OR mv_copy_to IS INITIAL.
      mv_msg = 'Pick a source journey and a new ID to copy into'. mv_mtype = 'Warning'. RETURN.
    ENDIF.
    DATA(lv_to) = to_upper( mv_copy_to ).
    SELECT SINGLE @abap_true FROM zrak_t_jny WHERE journey_id = @lv_to INTO @DATA(lv_ex).
    IF lv_ex = abap_true.
      mv_msg = |{ lv_to } already exists|. mv_mtype = 'Error'. RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrak_t_jny INTO @DATA(h) WHERE journey_id = @mv_sel.
    h-journey_id = lv_to. h-title = |{ h-title } (copy)|.
    h-changed_by = sy-uname.
    GET TIME STAMP FIELD h-changed_at.
    IF iv_strip_handler = abap_true.
      CLEAR h-handler_class.
    ENDIF.
    INSERT zrak_t_jny FROM @h.

    SELECT * FROM zrak_t_jny_step INTO TABLE @DATA(ls) WHERE journey_id = @mv_sel.
    LOOP AT ls ASSIGNING FIELD-SYMBOL(<s>). <s>-journey_id = lv_to. ENDLOOP.
    IF ls IS NOT INITIAL. INSERT zrak_t_jny_step FROM TABLE @ls. ENDIF.
    SELECT * FROM zrak_t_jny_fld INTO TABLE @DATA(lf) WHERE journey_id = @mv_sel.
    LOOP AT lf ASSIGNING FIELD-SYMBOL(<f>). <f>-journey_id = lv_to. ENDLOOP.
    IF lf IS NOT INITIAL. INSERT zrak_t_jny_fld FROM TABLE @lf. ENDIF.
    SELECT * FROM zrak_t_jny_opt INTO TABLE @DATA(lo) WHERE journey_id = @mv_sel.
    LOOP AT lo ASSIGNING FIELD-SYMBOL(<o>). <o>-journey_id = lv_to. ENDLOOP.
    IF lo IS NOT INITIAL. INSERT zrak_t_jny_opt FROM TABLE @lo. ENDIF.
    SELECT * FROM zrak_t_jny_col INTO TABLE @DATA(lc) WHERE journey_id = @mv_sel.
    LOOP AT lc ASSIGNING FIELD-SYMBOL(<c>). <c>-journey_id = lv_to. ENDLOOP.
    IF lc IS NOT INITIAL. INSERT zrak_t_jny_col FROM TABLE @lc. ENDIF.
    SELECT * FROM zrak_t_jny_rule INTO TABLE @DATA(lr) WHERE journey_id = @mv_sel.
    LOOP AT lr ASSIGNING FIELD-SYMBOL(<r>). <r>-journey_id = lv_to. ENDLOOP.
    IF lr IS NOT INITIAL. INSERT zrak_t_jny_rule FROM TABLE @lr. ENDIF.

    COMMIT WORK.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_to ).
    load_list( ). mv_sel = lv_to. load_journey( ). CLEAR mv_copy_to.
    mv_msg = |Copied to { lv_to }|. mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD to_int.
*   Was CO '0123456789 ', which lets an embedded blank through: a Seq typed as
*   '1 2' passed the test and then dumped on the assignment. Condense first, and
*   do not allow a blank at all after that.
    DATA(lv) = condense( iv ).
    IF lv IS NOT INITIAL AND lv CO '0123456789'.
      rv = lv.
    ENDIF.
  ENDMETHOD.


  METHOD type_list.
    rt = VALUE #(
      ( `INPUT` ) ( `EMAIL` ) ( `PHONE` ) ( `NUMBER` ) ( `CURRENCY` ) ( `TEXTAREA` )
      ( `DATE` ) ( `TIME` ) ( `DATETIME` ) ( `SELECT` ) ( `MULTISELECT` ) ( `RADIO` )
      ( `CHECKBOX` ) ( `SWITCH` ) ( `SEGMENTED` ) ( `CHECKGROUP` ) ( `SLIDER` ) ( `STEPPER` ) ( `RATING` )
      ( `DISPLAY` ) ( `READONLY` ) ( `STATUS` ) ( `OBJNUM` ) ( `PROGRESS` ) ( `LINK` )
      ( `SEARCH` ) ( `TABLE` ) ( `EDITABLE_TABLE` ) ( `RECORDCARD` ) ( `RO_PANEL` ) ( `REVIEW` ) ( `REQPANEL` ) ( `UPLOAD` ) ( `PAYFEE` ) ).
  ENDMETHOD.


  METHOD css.
    DATA(c) =
      `.rakHero { background: linear-gradient(135deg, rgb(196,30,38), rgb(166,18,22)); color:#fff; padding:22px 26px; border-radius:16px; margin:10px; box-shadow:0 10px 30px rgba(196,30,38,0.26); }` &&
      `.rakHero h1 { margin:0; font-size:1.6rem; font-weight:700; }` &&
      `.rakHero p { margin:6px 0 0; opacity:0.92; }` &&
      `.rakSec { color: rgb(16,35,62); font-weight:700; font-size:1.05rem; margin:16px 14px 2px; }` &&
      `.rakCard { background:#fff; border:1px solid #eceff3; border-radius:14px; padding:14px; box-shadow:0 2px 10px rgba(16,35,62,0.06); }` &&
      `.rakCard:hover { box-shadow:0 10px 22px rgba(16,35,62,0.12); }` &&
      `.rakCardT { font-weight:700; color: rgb(16,35,62); font-size:0.92rem; }` &&
      `.rakCardD { color:#5b6b7f; font-size:0.78rem; }` &&
      `.rakChips { margin:2px 0 6px; }` &&
      `.rakChip { display:inline-block; background:#f2f5f9; color:#33475e; border:1px solid #e2e8f0; border-radius:999px; padding:2px 8px; font-size:0.7rem; margin:0 4px 4px 0; }` &&
      `.rakCardX { color:#8a97a8; font-size:0.72rem; font-style:italic; }` &&
*     Design tab. The twelve-segment width bar, and the tint that marks the one
*     field whose label is open in the text editor above - without it the editor
*     names a field and nothing on the list says which row that is.
      `.rakDsgBar { display:inline-flex; gap:2px; width:120px; flex:none; }` &&
      `.rakDsgBar i { flex:1; height:12px; border-radius:2px; background:#e6eaf0; }` &&
      `.rakDsgBar i.on { background: rgb(196,30,38); }` &&
      `.rakDsgSel { background:#fdf3f4; border-inline-start:3px solid rgb(196,30,38); ` &&
      `border-radius:6px; padding-inline-start:6px; }` &&
      `.rakLintMsg { flex:1 1 auto; min-width:0; }` &&
*     Bottom right, not top: the toolbar and the panel headers are what the author
*     is aiming at, and a banner across the top covers exactly those. z-index 90
*     sits above the page and below UI5's own dialogs, which start around 1000 -
*     a value help must never open behind this.
      `.rakToast { position:fixed; right:1.5rem; bottom:1.5rem; z-index:90; ` &&
      `max-width:34rem; animation:rakToastIn .18s ease-out; }` &&
      `.rakToast .sapMMsgStrip { box-shadow:0 10px 28px rgba(16,35,62,0.22); border-radius:10px; }` &&
      `@keyframes rakToastIn { from { opacity:0; transform:translateY(10px); } ` &&
      `to { opacity:1; transform:none; } }`.
    REPLACE ALL OCCURRENCES OF `{` IN c WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN c WITH `\}`.
    rv = `<div><style>` && c && `</style></div>`.
  ENDMETHOD.


  METHOD armed.
*   MV_ARM_EVT is cleared at the top of MAIN whenever the next event differs, so an
*   arm cannot survive the author going off to do something else and coming back.
*   Same mechanism the DL_ row deletes use - one arm at a time, on purpose.
    IF mv_arm_evt = iv_ev.
      CLEAR mv_arm_evt.
      rv_go = abap_true.
      RETURN.
    ENDIF.
    mv_arm_evt = iv_ev.
    mv_msg     = iv_warn.
    mv_mtype   = 'Warning'.
  ENDMETHOD.


  METHOD focus_panel.
    CASE to_upper( iv_key ).
      WHEN 'HDR'.   mv_pn_hdr   = abap_true.
      WHEN 'STEPS'. mv_pn_steps = abap_true.
      WHEN 'FLDS'.  mv_pn_flds  = abap_true.
      WHEN 'OPTS'.  mv_pn_opts  = abap_true.
      WHEN 'COLS'.  mv_pn_cols  = abap_true.
      WHEN 'RULES'. mv_pn_rules = abap_true.
      WHEN 'DOC'.   mv_pn_doc   = abap_true.
      WHEN OTHERS.  RETURN.
    ENDCASE.
    mv_mode  = 'AUTHOR'.
    mv_focus = to_upper( iv_key ).
  ENDMETHOD.


  METHOD scroll_js.
*   The Studio rebuilds its whole view on every round trip, so the new DOM opens at
*   scrollTop 0 and the author is thrown back to the top of a page that runs to
*   sixty fields. This records the position and puts it back.
*
*   The scroll container is deliberately NOT found by class name. sap.m.Page
*   renders an OUTER div carrying sapMPageEnableScrolling, which is overflow
*   hidden, and an INNER section that does the actual scrolling. A listener that
*   compared e.target with the outer div therefore never matched, nothing was ever
*   written, and the restore below always read back a zero - the whole mechanism
*   was inert. PICK takes whichever candidate is genuinely scrollable instead, so
*   it does not matter which element UI5 chose to put the overflow on.
*
*   Note for the engine: ZCL_RAK_JOURNEY_CSS->SCROLL_KEEPER still compares against
*   sapMPageEnableScrolling the same way and has the same problem.
    DATA(lv_js) =
      `var K='cjsScroll';` &&
      `var pick=function(){` &&
      `var l=document.querySelectorAll('.sapMPageScroll,.sapMPageEnableScrolling,` &&
      `.sapMScrollCont,.sapUiScrollDelegate,section');var b=null;` &&
      `for(var i=0;i<l.length;i++){var e=l[i];` &&
      `if(e.scrollHeight-e.clientHeight>20&&(!b||e.scrollHeight>b.scrollHeight)){b=e;}}` &&
      `return b;};` &&
      `var put=function(){var s=pick();` &&
      `if(s){try{sessionStorage.setItem(K,s.scrollTop);}catch(x){}}};` &&
*     Debounced on scroll, because scroll fires continuously and PICK walks the
*     DOM. Also on mousedown: a press landing inside the debounce window would
*     otherwise round-trip with a stale position recorded, which is exactly the
*     case that matters - the author scrolls to a button and presses it.
      `if(!window._cjsWired){window._cjsWired=1;var t=null;` &&
      `document.addEventListener('scroll',function(){` &&
      `if(t){clearTimeout(t);}t=setTimeout(put,80);},true);` &&
      `document.addEventListener('mousedown',put,true);}`.

    IF mv_focus IS NOT INITIAL.
*     A panel that was collapsed a moment ago has not finished its expand
*     animation, so its height is still wrong on the first frame. Retry for a few
*     frames rather than measuring once and landing short.
*
*     PUT( ) after the scroll, so the position the author was TAKEN to becomes the
*     remembered one. Without it the next action would restore the position they
*     were at before pressing Edit and undo the navigation.
      lv_js = lv_js &&
        `var n=0;var f=function(){n=n+1;` &&
        `var g=document.querySelector('.rakPnl` && to_upper( mv_focus ) && `');` &&
        `if(g){g.scrollIntoView({block:'start'});put();` &&
        `if(n<12){requestAnimationFrame(f);}return;}` &&
        `if(n<40){requestAnimationFrame(f);}};requestAnimationFrame(f);`.
      CLEAR mv_focus.
    ELSE.
*     Keep re-asserting for a few frames after the first success. UI5 lays the
*     form out in stages, so a single assignment lands and is then overwritten.
      lv_js = lv_js &&
        `var p=0;try{p=parseInt(sessionStorage.getItem(K)||'0',10);}catch(x){}` &&
        `if(p>0){var n=0;var f=function(){n=n+1;var s=pick();` &&
        `if(s&&(s.scrollHeight-s.clientHeight)>=p){s.scrollTop=p;` &&
        `if(n<12){requestAnimationFrame(f);}return;}` &&
        `if(n<60){requestAnimationFrame(f);}};requestAnimationFrame(f);}`.
    ENDIF.

    lv_js = lv_js && `this.remove();`.
    DATA(lv_html) = `<div><img src="data:," style="display:none" onerror="` && lv_js && `"/></div>`.
    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    rv = lv_html.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'RAK Customer Journey Studio' class = 'sapUiSizeCompact' ).
    page->html( content = css( ) sanitizecontent = abap_false ).
    page->html( content = scroll_js( ) sanitizecontent = abap_false ).
    render_toolbar( page ).
*   Floating, not in the flow. An inline strip appears and disappears between the
*   toolbar and the panels, so every action that produced a message pushed the
*   whole page down or let it snap back up under the author - and the message could
*   only be read from the top of the page anyway. position:fixed costs no layout in
*   either direction, so nothing moves, and it stays legible wherever the author
*   happens to be scrolled to.
*
*   Closable, because it is now overlaying content rather than sitting above it.
*   Closing is a client-side act with no round trip, so it cannot lose anything.
    IF mv_msg IS NOT INITIAL.
      page->vbox( class = 'rakToast' )->message_strip( text            = mv_msg
                                                       type            = mv_mtype
                                                       showicon        = abap_true
                                                       showclosebutton = abap_true ).
    ENDIF.
    CASE mv_mode.
      WHEN 'AUTHOR'.  render_author( page ).
      WHEN 'PREVIEW'. render_preview( page ).
      WHEN 'MIGRATE'. render_migrate( page ).
      WHEN 'AUDIT'.   render_audit( page ).
      WHEN 'DESIGN'.  render_design( page ).
      WHEN OTHERS.    render_compose( page ).
    ENDCASE.
    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD render_toolbar.
    DATA(bar) = io->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    DATA(cb) = bar->combobox( selectedkey = mo_client->_bind_edit( mv_sel ) placeholder = 'Select journey' width = '20rem' ).
    LOOP AT mt_jny INTO DATA(j).
      cb->item( key = j-journey_id text = |{ j-journey_id } — { j-title }| ).
    ENDLOOP.
    bar->button( text = 'Load' icon = 'sap-icon://open-folder' press = mo_client->_event( 'LOAD' ) class = 'sapUiTinyMarginBegin' ).
    bar->button( text = 'New'  icon = 'sap-icon://add-document' press = mo_client->_event( 'NEW' ) ).
    DATA(lv_armed) = xsdbool( mv_arm_save IS NOT INITIAL AND mv_arm_save = to_upper( mv_journey_id ) ).
    bar->button( text  = COND string( WHEN lv_armed = abap_true THEN 'Save anyway' ELSE 'Save' )
                 icon  = 'sap-icon://save'
                 type  = COND string( WHEN lv_armed = abap_true THEN 'Reject' ELSE 'Emphasized' )
                 press = mo_client->_event( 'SAVE' ) ).
    bar->input( value = mo_client->_bind_edit( mv_copy_to ) placeholder = 'Copy to (new ID)' width = '12rem' class = 'sapUiTinyMarginBegin' ).
    bar->button( text = 'Copy' icon = 'sap-icon://copy' press = mo_client->_event( 'COPY' ) ).
*   Armed state on the control itself, not only in the message. The same shape the
*   row deletes use: red, an alert icon and a tooltip that says what a second press
*   will do - so the button that is now dangerous looks different from the one that
*   merely asked a question.
    DATA(lv_arm_de) = xsdbool( mv_arm_evt = 'DEACT' ).
    bar->button( text    = COND string( WHEN lv_arm_de = abap_true THEN 'Deactivate anyway' ELSE 'Deactivate' )
                 icon    = COND string( WHEN lv_arm_de = abap_true THEN 'sap-icon://alert' ELSE 'sap-icon://pause' )
                 type    = COND string( WHEN lv_arm_de = abap_true THEN 'Reject' )
                 tooltip = COND string( WHEN lv_arm_de = abap_true
                                   THEN 'Click again to take this journey off launch' )
                 press   = mo_client->_event( 'DEACT' )
                 class   = 'sapUiTinyMarginBegin' ).
*   Clear cache. Save, Copy, Deactivate and Migrate already invalidate, and so
*   does Load now - which leaves exactly one case for this button: config changed
*   OUTSIDE the Studio. A seed report, a direct table update, a transport import.
*   That is precisely when nobody thinks of the cache, which is the argument for
*   putting it on the bar rather than in a note somewhere.
    bar->button( text  = 'Clear cache'
                 icon  = 'sap-icon://refresh'
                 press = mo_client->_event( 'CFGCLR' ) ).
*   The Studio held edits in memory with nothing on screen to say so, and Load,
*   New and Audit all would each take them away without asking.
    IF mv_dirty = abap_true.
      bar->object_status( text  = 'unsaved changes'
                          state = 'Warning'
                          class = 'sapUiSmallMarginBegin' ).
    ENDIF.

    DATA(seg) = io->hbox( class = 'sapUiSmallMarginBegin sapUiSmallMarginBottom' ).
    seg->button( text  = 'Compose'
                 icon  = 'sap-icon://palette'
                 type  = COND string( WHEN mv_mode = 'COMPOSE' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'M_COMPOSE' ) ).
    seg->button( text  = 'Author'
                 icon  = 'sap-icon://edit'
                 type  = COND string( WHEN mv_mode = 'AUTHOR' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'M_AUTHOR' ) ).
    seg->button( text  = 'Preview'
                 icon  = 'sap-icon://show'
                 type  = COND string( WHEN mv_mode = 'PREVIEW' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'M_PREVIEW' ) ).
    seg->button( text  = 'Migrate'
                 icon  = 'sap-icon://journey-arrive'
                 type  = COND string( WHEN mv_mode = 'MIGRATE' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'M_MIGRATE' ) ).
    seg->button( text  = 'Audit all'
                 icon  = 'sap-icon://validate'
                 type  = COND string( WHEN mv_mode = 'AUDIT' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'M_AUDIT' ) ).
    seg->button( text  = 'Design'
                 icon  = 'sap-icon://screen-split-two'
                 type  = COND string( WHEN mv_mode = 'DESIGN' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'M_DESIGN' ) ).
  ENDMETHOD.


  METHOD render_compose.
    io->html( content         = `<div class="rakHero"><h1>RAK Customer Journey Studio</h1><p>Pick a pattern to start a new service, or restyle the one you have &mdash; theme, colours and branding. The full configuration lives in Author.</p></div>`
              sanitizecontent = abap_false ).
    DATA(split) = io->hbox( alignitems = 'Stretch' class = 'sapUiSmallMargin' ).
    DATA(left)  = split->vbox( width = '60%' class = 'sapUiSmallMarginEnd' ).
    DATA(right) = split->vbox( width = '26rem' ).
    render_theme( left ).
    render_style( left ).
    render_patterns( right ).
  ENDMETHOD.


  METHOD render_author.
    render_lint( io ).
    render_hdr( io ).
    render_steps( io ).
    render_fields( io ).
    render_opts( io ).
    render_cols( io ).
    render_rules( io ).
    render_doc( io ).
  ENDMETHOD.


  METHOD render_hdr.
    DATA(p) = io->panel( headertext = 'Journey header'
                         expandable = abap_true
                         expanded   = mv_pn_hdr
                         expand     = mo_client->_event( 'PNL~HDR' )
                         class      = 'sapUiSmallMarginBeginEnd rakPnlHDR' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).
    f->title( ns = 'core' text = 'Identity' ).
    f->label( 'UI journey code (generated)' ). f->input( value = mo_client->_bind_edit( mv_journey_id ) ).
    f->label( 'Title (EN)' ).    f->input( value = mo_client->_bind_edit( mv_title ) ).
    f->label( 'Title (AR)' ).    f->input( value = mo_client->_bind_edit( mv_title_ar ) placeholder = 'العنوان' ).
    f->label( 'Subtitle (EN)' ). f->input( value = mo_client->_bind_edit( mv_subtitle ) ).
    f->label( 'Subtitle (AR)' ). f->input( value = mo_client->_bind_edit( mv_subtitle_ar ) ).
    f->label( 'Handler class' ). f->input( value = mo_client->_bind_edit( mv_handler ) placeholder = 'ZCL_RAK_<ID>_LOGIC (optional)' ).
    f->label( 'Tile code' ).     f->input( value = mo_client->_bind_edit( mv_tile_code ) placeholder = 'portal tile CHAR4' ).
*   The ENQUEUE stops two authors overwriting each other at the same moment.
*   Nothing answered who changed a live journey yesterday, which is the question
*   that actually gets asked.
    IF mv_chg_by IS NOT INITIAL.
      f->label( 'Last changed' ).
      f->text( text = |{ mv_chg_by } · { mv_chg_at }| ).
    ENDIF.

    f->title( ns = 'core' text = 'SAP S4 Backend' ).
    f->label( 'Backend active' ).       f->switch( state = mo_client->_bind_edit( mv_bknd_act ) ).
    f->label( 'Backend category' ).     f->input( value = mo_client->_bind_edit( mv_bknd_cat ) placeholder = 'e.g. DOKSL' ).
    f->label( 'BAdI journey code (legacy)' ). f->input( value = mo_client->_bind_edit( mv_bknd_jny ) placeholder = 'e.g. M001 / E001 / DK01' ).
    f->label( 'FM Post (blank=default)' ). f->input( value = mo_client->_bind_edit( mv_bknd_fmp ) ).
    f->label( 'FM Read (blank=default)' ). f->input( value = mo_client->_bind_edit( mv_bknd_fmr ) ).

    f->title( ns = 'core' text = 'Behaviour' ).
    f->label( 'Show actions' ). f->switch( state = mo_client->_bind_edit( mv_show_act ) ).
    f->label( 'Active' ).       f->switch( state = mo_client->_bind_edit( mv_active ) ).

    DATA(b) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    b->button( text = 'Save & Preview' icon = 'sap-icon://play' type = 'Emphasized' press = mo_client->_event( 'SAVEPREV' ) ).
    IF mv_journey_id IS NOT INITIAL.
      b->link( text   = 'Open in new tab ↗'
               target = '_blank'
               class  = 'sapUiSmallMarginBegin'
               href   = engine_url( iv_journey = mv_journey_id ) ).
    ENDIF.
  ENDMETHOD.


  METHOD render_steps.
    DATA(p) = io->panel( headertext = |Steps — { lines( mt_steps ) }|
                         expandable = abap_true
                         expanded   = mv_pn_steps
                         expand     = mo_client->_event( 'PNL~STEPS' )
                         class      = 'sapUiSmallMarginBeginEnd rakPnlSTEPS' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '4' columnsl = '4' columnsm = '2' )->content( ns = 'form' ).
    f->label( 'Seq' ).            f->input( value = mo_client->_bind_edit( sv_seq ) ).
    f->label( 'Step ID' ).        f->input( value = mo_client->_bind_edit( sv_step ) ).
    f->label( 'Title (EN)' ).     f->input( value = mo_client->_bind_edit( sv_title ) ).
    f->label( 'Title (AR)' ).     f->input( value = mo_client->_bind_edit( sv_title_ar ) ).
    f->label( 'Icon' ).           f->input( value = mo_client->_bind_edit( sv_icon ) ).
    f->label( 'Columns (1-4)' ).  f->input( value = mo_client->_bind_edit( sv_cols ) placeholder = '1' ).
    f->label( 'Backend screen' ). f->input( value = mo_client->_bind_edit( sv_bscreen ) placeholder = 'e.g. ND011_1_2 — this step POSTs here' ).
    f->label( 'Next requires' ).  f->input( value = mo_client->_bind_edit( sv_nextreq )
    placeholder = 'field name — Next/Submit stays disabled until it has a value, e.g. PAYFEE' ).
    f->label( 'No forward button' ). f->checkbox( selected = mo_client->_bind_edit( sv_nofwd )
    text = 'ends the journey without submitting' ).
    DATA(b) = p->hbox( class = 'sapUiSmallMargin' ).
    b->button( text = 'Add / update step' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ASTEP' ) ).
    b->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_STEP' ) class = 'sapUiTinyMarginBegin' ).
    DATA(t) = p->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(c) = t->columns( ).
    c->column( )->text( 'Seq' ). c->column( )->text( 'Step ID' ). c->column( )->text( 'Title' ).
    c->column( )->text( 'Cols' ). c->column( )->text( 'Backend screen' ). c->column( )->text( 'Fields' ). c->column( )->text( '' ).
    DATA(it) = t->items( ).
    LOOP AT mt_steps INTO DATA(r).
      DATA(lv_dev) = |DL_STEP~{ r-step_id }|.
      DATA(cells) = it->column_list_item( )->cells( ).
      DATA lv_fcnt TYPE i.
      CLEAR lv_fcnt.
      LOOP AT mt_fields TRANSPORTING NO FIELDS WHERE step_id = r-step_id.
        lv_fcnt = lv_fcnt + 1.
      ENDLOOP.
      cells->text( r-seqnr )->text( r-step_id )->text( r-title )->text( r-columns
        )->text( r-bknd_screen )->text( |{ lv_fcnt }| ).
      DATA(act) = cells->hbox( ).
      act->button( icon = 'sap-icon://edit' type = 'Transparent' tooltip = 'Edit' press = mo_client->_event( |EDSTEP_{ r-step_id }| ) ).
      act->button( icon = COND string( WHEN mv_arm_evt = lv_dev THEN 'sap-icon://alert' ELSE 'sap-icon://delete' )
                   type = COND string( WHEN mv_arm_evt = lv_dev THEN 'Reject' ELSE 'Transparent' )
                   tooltip = COND string( WHEN mv_arm_evt = lv_dev THEN 'Click again to confirm delete' ELSE 'Delete' )
                   press = mo_client->_event( lv_dev ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_fields.
*   How many fields, and how many of them carry a finding, before the panel is
*   even opened. A count in the header is what makes somebody open it.
    DATA lv_flagged TYPE i.
    LOOP AT mt_fields INTO DATA(cf).
      READ TABLE mt_lint_row TRANSPORTING NO FIELDS
           WITH KEY step = to_upper( cf-step_id ) field = to_upper( cf-field_name ).
      IF sy-subrc = 0.
        lv_flagged = lv_flagged + 1.
      ENDIF.
    ENDLOOP.

    DATA(p) = io->panel(
      headertext = |Fields — { lines( mt_fields ) }| &&
                   COND string( WHEN lv_flagged > 0 THEN |, { lv_flagged } with findings| ) &&
                   COND string( WHEN mv_only_bad = abap_true      THEN ` · showing findings only`
                                WHEN mv_fld_filter IS NOT INITIAL THEN ` · filtered` )
      expandable = abap_true
      expanded   = mv_pn_flds
      expand     = mo_client->_event( 'PNL~FLDS' )
      class      = 'sapUiSmallMarginBeginEnd rakPnlFLDS' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).

    f->title( ns = 'core' text = 'Basics' ).
    f->label( 'Step ID' ).    f->input( value = mo_client->_bind_edit( fv_step ) ).
    f->label( 'Field name' ). f->input( value = mo_client->_bind_edit( fv_field ) ).
    f->label( 'Seq' ).        f->input( value = mo_client->_bind_edit( fv_seq ) placeholder = 'blank = auto' ).
    f->label( 'Type' ).       DATA(ct) = f->combobox( selectedkey = mo_client->_bind_edit( fv_type ) ).
    LOOP AT type_list( ) INTO DATA(ty). ct->item( key = ty text = ty ). ENDLOOP.
    f->label( 'Label (EN)' ). f->input( value = mo_client->_bind_edit( fv_label ) ).
    f->label( 'Label (AR)' ). f->input( value = mo_client->_bind_edit( fv_label_ar ) ).
    f->label( 'Placeholder (EN)' ). f->input( value = mo_client->_bind_edit( fv_place ) ).
    f->label( 'Placeholder (AR)' ). f->input( value = mo_client->_bind_edit( fv_place_ar ) ).
    f->label( 'Default value' ). f->input( value = mo_client->_bind_edit( fv_default )
    placeholder = 'grid cols name:label:type|... plus SEL:SINGLE:TARGET or SEL:MULTI:TARGET for a tick column (put SEL first)' ).
    f->label( '' ).
    f->button( text  = 'Test column spec'
               icon  = 'sap-icon://table-view'
               press = mo_client->_event( 'PREVGRID' )
               width = '12rem' ).
    f->label( 'Group' ).      f->input( value = mo_client->_bind_edit( fv_group )
    placeholder = 'container heading, OR ROW:name to share a row with the neighbouring ROW:name fields' ).
    f->label( 'Section' ).    f->input( value = mo_client->_bind_edit( fv_sect ) ).
*   Stored in ZRAK_T_JNY_FLD-WIDTH, but ZCL_RAK_JOURNEY_UTIL=>CTRL_WIDTH( )
*   never reads it - the renderer calls that method and it returns a per-type
*   default and nothing else. Say so rather than let an author set a width and
*   then hunt for why the control did not move.
    f->label( 'Width (not applied yet)' ).
    f->input( value = mo_client->_bind_edit( fv_width )
      placeholder = 'stored, but CTRL_WIDTH( ) still returns the per-type default' ).
    f->label( 'State' ).      DATA(fs) = f->combobox( selectedkey = mo_client->_bind_edit( fv_state ) ).
    fs->item( key = '' text = '(none)' ).
    fs->item( key = 'None' text = 'None' ).
    fs->item( key = 'Success' text = 'Success' ).
    fs->item( key = 'Warning' text = 'Warning' ).
    fs->item( key = 'Error' text = 'Error' ).
    fs->item( key = 'Information' text = 'Information' ).
    f->label( 'Hidden by default' ). f->checkbox( selected = mo_client->_bind_edit( fv_hidden ) ).
    f->label( 'Read only' ).  f->checkbox( selected = mo_client->_bind_edit( fv_readonly ) ).

    f->title( ns = 'core' text = 'Validation' ).
    f->label( 'Required' ).   f->checkbox( selected = mo_client->_bind_edit( fv_req ) ).
    f->label( 'Regex' ).      f->input( value = mo_client->_bind_edit( fv_regex ) ).
    f->label( 'Min length' ). f->input( value = mo_client->_bind_edit( fv_minlen ) ).
    f->label( 'Max length' ). f->input( value = mo_client->_bind_edit( fv_maxlen ) ).
    f->label( 'Min value' ).  f->input( value = mo_client->_bind_edit( fv_minval ) placeholder = 'slider/stepper/number floor' ).
    f->label( 'Max value' ).  f->input( value = mo_client->_bind_edit( fv_maxval ) placeholder = 'slider/stepper/rating ceiling' ).
    f->label( 'Message (EN)' ). f->input( value = mo_client->_bind_edit( fv_msg ) ).
    f->label( 'Message (AR)' ). f->input( value = mo_client->_bind_edit( fv_msg_ar ) ).

    f->title( ns = 'core' text = 'Backend & value help' ).
    f->label( 'Technical name (backend)' ). f->input( value = mo_client->_bind_edit( fv_tech ) placeholder = 'e.g. GS_DATA-PARTNER_NAME / doc code / grid JSON field' ).
    f->label( 'Data element (F4 options)' ). f->input( value = mo_client->_bind_edit( fv_roll ) ).
    f->label( 'Domain (fixed values)' ). f->input( value = mo_client->_bind_edit( fv_dom ) placeholder = 'e.g. ZRAK_STATUS - fixed values direct' ).
    f->label( 'Search help' ). f->input( value = mo_client->_bind_edit( fv_shlp ) ).

    f->title( ns = 'core' text = 'Attachment' ).
    f->label( 'Has attachment' ). f->checkbox( selected = mo_client->_bind_edit( fv_hasatt ) ).
    f->label( 'Attach label' ).   f->input( value = mo_client->_bind_edit( fv_attlabel ) ).
    f->label( 'Allowed types' ).  f->input( value = mo_client->_bind_edit( fv_atttypes ) placeholder = 'pdf,jpg,png' ).
    f->label( 'Attach max MB' ).  f->input( value = mo_client->_bind_edit( fv_attmb ) ).
    f->label( 'Allow multiple' ). f->checkbox( selected = mo_client->_bind_edit( fv_attmulti ) ).

    DATA(rf) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBegin sapUiTinyMarginBottom' ).
    rf->label( text = 'Find data element:' class = 'sapUiTinyMarginEnd' ).
    rf->input( value = mo_client->_bind_edit( mv_roll_term ) placeholder = 'e.g. country, gender, yes/no' width = '16rem' ).
    rf->button( text = 'Search' icon = 'sap-icon://search' press = mo_client->_event( 'SEARCHROLL' ) class = 'sapUiTinyMarginBegin' ).
    rf->button( text = 'Test value help' icon = 'sap-icon://show' press = mo_client->_event( 'PREVROLL' ) class = 'sapUiTinyMarginBegin' ).
    rf->button( text    = 'Test every value help'
                icon    = 'sap-icon://validate'
                tooltip = 'Resolve every data element, domain and search help in this journey through the resolver the engine uses'
                press   = mo_client->_event( 'PREVALL' )
                class   = 'sapUiTinyMarginBegin' ).

    IF mt_roll_hits IS NOT INITIAL.
      DATA(ro_tab) = p->table( class = 'sapUiSmallMarginBeginEnd sapUiTinyMarginBottom' ).
      DATA(ro_col) = ro_tab->columns( ).
      ro_col->column( )->text( 'Data element' ). ro_col->column( )->text( 'Description' ).
      ro_col->column( )->text( 'Domain' ). ro_col->column( )->text( '# values' ). ro_col->column( )->text( '' ).
      DATA(ro_it) = ro_tab->items( ).
      LOOP AT mt_roll_hits INTO DATA(rh).
        ro_it->column_list_item( )->cells(
          )->text( rh-rollname )->text( rh-ddtext )->text( rh-domname )->text( |{ rh-fixcnt }|
          )->button( text = 'Use' icon = 'sap-icon://accept' press = mo_client->_event( |PICKROLL_{ rh-rollname }| ) ).
      ENDLOOP.
    ENDIF.

    IF mt_roll_preview IS NOT INITIAL.
      DATA(pv) = p->hbox( class = 'sapUiSmallMarginBeginEnd sapUiTinyMarginBottom' ).
      pv->label( text  = |{ lines( mt_roll_preview ) } option(s), first { COND i( WHEN lines( mt_roll_preview ) > 15 THEN 15 ELSE lines( mt_roll_preview ) ) }:|
                 class = 'sapUiTinyMarginEnd' ).
      LOOP AT mt_roll_preview INTO DATA(pr).
        pv->object_status( text = |{ pr-key }={ pr-text }| class = 'sapUiTinyMarginEnd' ).
      ENDLOOP.
    ENDIF.

    IF mt_grid_preview IS NOT INITIAL OR mv_grid_sel IS NOT INITIAL.
      DATA(gv) = p->hbox( class = 'sapUiSmallMarginBeginEnd sapUiTinyMarginBottom' wrap = 'Wrap' ).
      gv->label( text = 'Grid renders:' class = 'sapUiTinyMarginEnd' ).
      IF mv_grid_sel IS NOT INITIAL.
        gv->object_status( text  = |[tick] { mv_grid_sel }|
                           state = 'Information'
                           class = 'sapUiTinyMarginEnd' ).
      ENDIF.
      LOOP AT mt_grid_preview INTO DATA(gc).
        gv->object_status( text = |{ gc-label } ({ gc-ctype })| class = 'sapUiTinyMarginEnd' ).
      ENDLOOP.
    ENDIF.

    DATA(sf) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBegin sapUiTinyMarginBottom' ).
    sf->label( text = 'Find search help:' class = 'sapUiTinyMarginEnd' ).
    sf->input( value = mo_client->_bind_edit( mv_shlp_term ) placeholder = 'e.g. business partner' width = '16rem' ).
    sf->button( text = 'Search' icon = 'sap-icon://search' press = mo_client->_event( 'SEARCHSHLP' ) class = 'sapUiTinyMarginBegin' ).

    IF mt_shlp_hits IS NOT INITIAL.
      DATA(sh_tab) = p->table( class = 'sapUiSmallMarginBeginEnd sapUiTinyMarginBottom' ).
      DATA(sh_col) = sh_tab->columns( ).
      sh_col->column( )->text( 'Search help' ). sh_col->column( )->text( 'Description' ). sh_col->column( )->text( '' ).
      DATA(sh_it) = sh_tab->items( ).
      LOOP AT mt_shlp_hits INTO DATA(sh).
        sh_it->column_list_item( )->cells(
          )->text( sh-shlp )->text( sh-ddtext
          )->button( text = 'Use' icon = 'sap-icon://accept' press = mo_client->_event( |PICKSHLP_{ sh-shlp }| ) ).
      ENDLOOP.
    ENDIF.

    render_f4_scan( p ).

    DATA(b) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    b->button( text = 'Add / update field' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'AFLD' ) ).
    b->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_FLD' ) class = 'sapUiTinyMarginBegin' ).
    DATA(ps) = b->combobox( selectedkey = mo_client->_bind_edit( fv_step )
                            placeholder = 'target step'
                            width       = '10rem'
                            class       = 'sapUiTinyMarginBegin' ).
    LOOP AT mt_steps INTO DATA(pstep).
      ps->item( key = pstep-step_id text = pstep-step_id ).
    ENDLOOP.
    b->button( text    = 'Add payment step'
               icon    = 'sap-icon://credit-card'
               tooltip = 'Adds PAYFEE + the three hidden PAY_* fields to the selected step'
               press   = mo_client->_event( 'PAYTPL' )
               class   = 'sapUiTinyMarginBegin' ).

*   A real journey runs to fifty or sixty fields and the list is a wall of rows.
*   Filtering is not a nicety at that size - it is the difference between fixing
*   the three flagged fields and scrolling past them.
    DATA(ff) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBegin sapUiTinyMarginBottom' ).
    ff->label( text = 'Filter:' class = 'sapUiTinyMarginEnd' ).
    ff->input( value       = mo_client->_bind_edit( mv_fld_filter )
               placeholder = 'field, label, type, step, tech name or value help'
               width       = '20rem' ).
    ff->button( text  = 'Apply'
                icon  = 'sap-icon://filter'
                press = mo_client->_event( 'FLDFILT' )
                class = 'sapUiTinyMarginBegin' ).
    ff->button( text    = 'Findings only'
                icon    = 'sap-icon://alert'
                type    = COND string( WHEN mv_only_bad = abap_true THEN 'Emphasized' ELSE 'Transparent' )
                tooltip = 'Show only the fields carrying a lint finding'
                press   = mo_client->_event( 'FLDBAD' )
                class   = 'sapUiTinyMarginBegin' ).
    IF mv_only_bad = abap_true OR mv_fld_filter IS NOT INITIAL.
      ff->button( text  = 'Show all'
                  icon  = 'sap-icon://clear-filter'
                  press = mo_client->_event( 'FLDALL' )
                  class = 'sapUiTinyMarginBegin' ).
    ENDIF.

    DATA(t) = p->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(c) = t->columns( ).
    c->column( )->text( 'Seq' ). c->column( )->text( 'Step' ). c->column( )->text( 'Field' ). c->column( )->text( 'Type' ).
    c->column( )->text( 'Label' ). c->column( )->text( 'Tech' ). c->column( )->text( 'Roll' ).
    c->column( )->text( 'Req' ). c->column( )->text( 'Hid' ). c->column( )->text( 'Att' ). c->column( )->text( 'AR' ).
    c->column( )->text( 'Row' ).
    c->column( )->text( '!' ).
    c->column( )->text( '' ).
    DATA(it) = t->items( ).
    LOOP AT mt_fields INTO DATA(r).
      IF mv_fld_filter IS NOT INITIAL.
        DATA(lv_hay) = to_upper( |{ r-step_id } { r-field_name } { r-ftype } { r-label } | &&
                                 |{ r-tech_name } { r-rollname } { r-shlp } { r-domname }| ).
        IF lv_hay NS to_upper( mv_fld_filter ).
          CONTINUE.
        ENDIF.
      ENDIF.
      IF mv_only_bad = abap_true.
        READ TABLE mt_lint_row TRANSPORTING NO FIELDS
             WITH KEY step = to_upper( r-step_id ) field = to_upper( r-field_name ).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
      ENDIF.
      DATA(lv_dev) = |DL_FLD~{ r-step_id }~{ r-field_name }|.
      DATA(cells) = it->column_list_item( )->cells( ).
      cells->text( r-seqnr )->text( r-step_id )->text( r-field_name )->text( r-ftype
        )->text( r-label )->text( r-tech_name )->text( r-rollname
        )->text( COND string( WHEN r-required = abap_true THEN 'X' ELSE '' )
        )->text( COND string( WHEN r-hidden = abap_true THEN 'X' ELSE '' )
        )->text( COND string( WHEN r-has_attach = abap_true THEN 'X' ELSE '' )
        )->text( COND string( WHEN r-label_ar IS NOT INITIAL THEN 'X' ELSE '' ) ).
*     The pair toggle lives in the Row cell, NOT in the action cluster. Putting
*     it first among the actions pushed Edit / Duplicate / Delete past the right
*     edge of a table that had just gained a twelfth column, so Delete looked
*     like it had been removed. Text, not icons: sap-icon://combine does not
*     exist in this UI5 version and rendered as an empty button.
      DATA(lv_rtok) = row_tok( r-fgroup ).
      DATA(rowc) = cells->hbox( alignitems = 'Center' ).
      IF lv_rtok IS NOT INITIAL.
        rowc->text( text = substring( val = lv_rtok off = 4 ) class = 'sapUiTinyMarginEnd' ).
      ENDIF.
      rowc->button( text    = COND string( WHEN lv_rtok IS NOT INITIAL THEN 'Unpair' ELSE 'Pair' )
                    type    = 'Transparent'
                    tooltip = COND string( WHEN lv_rtok IS NOT INITIAL
                                      THEN 'Take this field off the shared row'
                                      ELSE 'Put this field on the same row as the field above' )
                    press   = mo_client->_event( |ROWPAIR_{ r-step_id }~{ r-field_name }| ) ).

*     Lint, on the row it belongs to. The Audit panel is a list somebody has to
*     choose to read; a field with no tech_name sat in it all afternoon while the
*     journey was tested, saved and run. Errors show red, warnings amber, the
*     text goes in the tooltip, and a clean field shows nothing at all so the
*     column only ever draws attention when there is something to see.
      DATA(lv_marker) = cells->hbox( alignitems = 'Center' ).
      LOOP AT mt_lint_row INTO DATA(ls_lr)
           WHERE step = to_upper( r-step_id ) AND field = to_upper( r-field_name ).
        lv_marker->button(
          icon    = COND string( WHEN ls_lr-type = 'Error' THEN 'sap-icon://error'
                            ELSE 'sap-icon://alert' )
          type    = COND string( WHEN ls_lr-type = 'Error' THEN 'Reject' ELSE 'Transparent' )
          tooltip = ls_lr-text
          press   = mo_client->_event( |EDFLD_{ r-step_id }~{ r-field_name }| ) ).
      ENDLOOP.

      DATA(act) = cells->hbox( ).
      act->button( icon    = 'sap-icon://edit'
                   type    = 'Transparent'
                   tooltip = 'Edit'
                   press   = mo_client->_event( |EDFLD_{ r-step_id }~{ r-field_name }| ) ).
      act->button( icon    = 'sap-icon://duplicate'
                   type    = 'Transparent'
                   tooltip = 'Duplicate'
                   press   = mo_client->_event( |DUPFLD_{ r-step_id }~{ r-field_name }| ) ).
      act->button( icon = COND string( WHEN mv_arm_evt = lv_dev THEN 'sap-icon://alert' ELSE 'sap-icon://delete' )
                   type = COND string( WHEN mv_arm_evt = lv_dev THEN 'Reject' ELSE 'Transparent' )
                   tooltip = COND string( WHEN mv_arm_evt = lv_dev THEN 'Click again to confirm delete' ELSE 'Delete' )
                   press = mo_client->_event( lv_dev ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_opts.
    DATA(p) = io->panel( headertext = |Options — { lines( mt_opts ) }|
                         expandable = abap_true
                         expanded   = mv_pn_opts
                         expand     = mo_client->_event( 'PNL~OPTS' )
                         class      = 'sapUiSmallMarginBeginEnd rakPnlOPTS' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '3' columnsl = '3' columnsm = '1' )->content( ns = 'form' ).
    f->label( 'Step ID' ).    f->input( value = mo_client->_bind_edit( ov_step ) ).
    f->label( 'Field name' ). f->input( value = mo_client->_bind_edit( ov_field ) ).
    f->label( 'Seq' ).        f->input( value = mo_client->_bind_edit( ov_seq ) placeholder = 'blank = auto' ).
    f->label( 'Option key' ). f->input( value = mo_client->_bind_edit( ov_key ) ).
    f->label( 'Option text (EN)' ). f->input( value = mo_client->_bind_edit( ov_text ) ).
    f->label( 'Option text (AR)' ). f->input( value = mo_client->_bind_edit( ov_text_ar ) ).
    DATA(b) = p->hbox( class = 'sapUiSmallMargin' ).
    b->button( text = 'Add / update option' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'AOPT' ) ).
    b->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_OPT' ) class = 'sapUiTinyMarginBegin' ).
    DATA(t) = p->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(c) = t->columns( ).
    c->column( )->text( 'Seq' ). c->column( )->text( 'Step' ). c->column( )->text( 'Field' ).
    c->column( )->text( 'Key' ). c->column( )->text( 'Text' ). c->column( )->text( '' ).
    DATA(it) = t->items( ).
    LOOP AT mt_opts INTO DATA(r).
      DATA(lv_dev) = |DL_OPT~{ r-step_id }~{ r-field_name }~{ r-opt_key }|.
      DATA(cells) = it->column_list_item( )->cells( ).
      cells->text( r-seqnr )->text( r-step_id )->text( r-field_name )->text( r-opt_key )->text( r-opt_text ).
      DATA(act) = cells->hbox( ).
      act->button( icon    = 'sap-icon://edit'
                   type    = 'Transparent'
                   tooltip = 'Edit'
                   press   = mo_client->_event( |EDOPT_{ r-step_id }~{ r-field_name }~{ r-opt_key }| ) ).
      act->button( icon = COND string( WHEN mv_arm_evt = lv_dev THEN 'sap-icon://alert' ELSE 'sap-icon://delete' )
                   type = COND string( WHEN mv_arm_evt = lv_dev THEN 'Reject' ELSE 'Transparent' )
                   tooltip = COND string( WHEN mv_arm_evt = lv_dev THEN 'Click again to confirm delete' ELSE 'Delete' )
                   press = mo_client->_event( lv_dev ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_cols.
*   Grid columns for an EDITABLE_TABLE/TABLE field - ZRAK_T_JNY_COL, read by
*   ZCL_RAK_JOURNEY_GRID->GRID_COLS( ) in preference to the pipe-separated
*   Default value spec on the field itself. Same shape and the same
*   step/field-scoping convention as Options above: Step ID / Field name are
*   plain inputs the author must match to an existing grid field by hand,
*   not auto-filled from the Fields panel.
    DATA(p) = io->panel( headertext = |Columns (grid fields) — { lines( mt_cols ) }|
                         expandable = abap_true
                         expanded   = mv_pn_cols
                         expand     = mo_client->_event( 'PNL~COLS' )
                         class      = 'sapUiSmallMarginBeginEnd rakPnlCOLS' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '3' columnsl = '3' columnsm = '1' )->content( ns = 'form' ).
    f->label( 'Step ID' ).       f->input( value = mo_client->_bind_edit( cv_step ) ).
    f->label( 'Grid field name' ). f->input( value = mo_client->_bind_edit( cv_field ) ).
    f->label( 'Seq' ).           f->input( value = mo_client->_bind_edit( cv_seq ) placeholder = 'blank = auto' ).
    f->label( 'Column name' ).   f->input( value = mo_client->_bind_edit( cv_col ) ).
    f->label( 'Label (EN)' ).    f->input( value = mo_client->_bind_edit( cv_label ) ).
    f->label( 'Label (AR)' ).    f->input( value = mo_client->_bind_edit( cv_label_ar ) ).
    f->label( 'Control' ).
    DATA(cc) = f->combobox( selectedkey = mo_client->_bind_edit( cv_ctrl ) ).
    LOOP AT VALUE string_table( ( `INPUT` ) ( `NUMBER` ) ( `DATE` ) ( `SELECT` ) ( `TEXT` ) ( `DISPLAY` ) ( `CHECKBOX` ) )
         INTO DATA(lv_ct).
      cc->item( key = lv_ct text = lv_ct ).
    ENDLOOP.
    f->label( 'Search help (captured, no F4 yet)' ).
    f->input( value = mo_client->_bind_edit( cv_shlp )
      placeholder = 'stored, but SELECT still resolves via data element or the handler' ).
    f->label( 'Data element (SELECT)' ). f->input( value = mo_client->_bind_edit( cv_rollname ) ).
    f->label( 'Width' ).         f->input( value = mo_client->_bind_edit( cv_width ) placeholder = 'e.g. 8rem' ).
    f->label( 'Align' ).
    DATA(ca) = f->combobox( selectedkey = mo_client->_bind_edit( cv_align ) ).
    LOOP AT VALUE string_table( ( `Begin` ) ( `Center` ) ( `End` ) ) INTO DATA(lv_ca).
      ca->item( key = lv_ca text = lv_ca ).
    ENDLOOP.
    f->label( 'Hidden' ).        f->checkbox( selected = mo_client->_bind_edit( cv_hidden ) ).
*   PINNED IS NOT IMPLEMENTABLE, and saying so on the control is the only honest
*   option. sap.m.Table has no frozen / sticky column feature, so there is nothing
*   for this flag to bind to and no renderer change that would give it one.
*
*   Disabled rather than deleted: the column still exists in ZRAK_T_JNY_COL and
*   journeys already carry values in it. Removing the control would leave those
*   values on rows with nothing on screen to explain where they came from.
    f->label( 'Pinned (not supported)' ).
    f->checkbox( selected = mo_client->_bind_edit( cv_pinned ) enabled = abap_false ).
    f->label( 'Read only' ).     f->checkbox( selected = mo_client->_bind_edit( cv_readonly ) ).
*   Still editable, unlike PINNED - per-row required validation is missing, not
*   impossible. It is simply not wired into VALIDATE_STEP / MISSING_REQUIRED yet,
*   so a grid with an empty mandatory cell passes validation and submits.
    f->label( 'Required (not enforced yet)' ).
    f->checkbox( selected = mo_client->_bind_edit( cv_required ) ).
    f->label( 'Decimals (not applied yet)' ).
    f->input( value = mo_client->_bind_edit( cv_decimals )
      placeholder = 'stored, but no decimal formatting is applied to the cell' ).
    f->label( 'Max length' ).    f->input( value = mo_client->_bind_edit( cv_maxlen ) ).
    f->label( 'Total (sum in footer)' ). f->checkbox( selected = mo_client->_bind_edit( cv_total ) ).
    DATA(bc) = p->hbox( class = 'sapUiSmallMargin' ).
    bc->button( text = 'Add / update column' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ACOL' ) ).
    bc->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_COL' ) class = 'sapUiTinyMarginBegin' ).
    DATA(tc) = p->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(cco) = tc->columns( ).
    cco->column( )->text( 'Seq' ). cco->column( )->text( 'Step' ). cco->column( )->text( 'Field' ).
    cco->column( )->text( 'Column' ). cco->column( )->text( 'Label' ). cco->column( )->text( 'Ctrl' ). cco->column( )->text( '' ).
    DATA(itc) = tc->items( ).
    LOOP AT mt_cols INTO DATA(rc).
      DATA(lv_devc) = |DL_COL~{ rc-step_id }~{ rc-field_name }~{ rc-col_name }|.
      DATA(cellsc) = itc->column_list_item( )->cells( ).
      cellsc->text( rc-seqnr )->text( rc-step_id )->text( rc-field_name )->text( rc-col_name )->text( rc-label )->text( rc-ctrl ).
      DATA(actc) = cellsc->hbox( ).
      actc->button( icon    = 'sap-icon://edit'
                    type    = 'Transparent'
                    tooltip = 'Edit'
                    press   = mo_client->_event( |EDCOL_{ rc-step_id }~{ rc-field_name }~{ rc-col_name }| ) ).
      actc->button( icon = COND string( WHEN mv_arm_evt = lv_devc THEN 'sap-icon://alert' ELSE 'sap-icon://delete' )
                    type = COND string( WHEN mv_arm_evt = lv_devc THEN 'Reject' ELSE 'Transparent' )
                    tooltip = COND string( WHEN mv_arm_evt = lv_devc THEN 'Click again to confirm delete' ELSE 'Delete' )
                    press = mo_client->_event( lv_devc ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_rules.
    DATA(p) = io->panel( headertext = |Rules (side effects) — { lines( mt_rules ) }|
                         expandable = abap_true
                         expanded   = mv_pn_rules
                         expand     = mo_client->_event( 'PNL~RULES' )
                         class      = 'sapUiSmallMarginBeginEnd rakPnlRULES' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).
    f->title( ns = 'core' text = 'When (condition)' ).
    f->label( 'Rule ID' ).      f->input( value = mo_client->_bind_edit( rv_id ) placeholder = 'blank = auto' ).
    f->label( 'Source field' ). DATA(rs) = f->combobox( selectedkey = mo_client->_bind_edit( rv_srcf ) ).
    LOOP AT mt_fields INTO DATA(sfld). rs->item( key = sfld-field_name text = sfld-field_name ). ENDLOOP.
    f->label( 'Operator' ).     DATA(op) = f->combobox( selectedkey = mo_client->_bind_edit( rv_srcop ) ).
    op->item( key = 'EQ' text = 'equals' ).
    op->item( key = 'NE' text = 'not equal' ).
    op->item( key = 'INITIAL' text = 'is empty' ).
    op->item( key = 'NOTINITIAL' text = 'is not empty' ).
    op->item( key = 'GT' text = 'greater than' ).
    op->item( key = 'LT' text = 'less than' ).
    op->item( key = 'GE' text = 'greater or equal' ).
    op->item( key = 'LE' text = 'less or equal' ).
    f->label( 'Source value' ). f->input( value = mo_client->_bind_edit( rv_srcval )
      placeholder = 'compared value - a number for greater/less than' ).

    f->title( ns = 'core' text = 'Then (action)' ).
    f->label( 'Action' ).       DATA(ac) = f->combobox( selectedkey = mo_client->_bind_edit( rv_action ) ).
    ac->item( key = 'SHOW' text = 'SHOW target' ).
    ac->item( key = 'HIDE' text = 'HIDE target' ).
    ac->item( key = 'REQUIRE' text = 'REQUIRE target' ).
    ac->item( key = 'OPTIONAL' text = 'OPTIONAL target' ).
    ac->item( key = 'READONLY' text = 'READONLY target' ).
    ac->item( key = 'EDITABLE' text = 'EDITABLE target' ).
    ac->item( key = 'SET' text = 'SET target value' ).
    ac->item( key = 'CLEAR' text = 'CLEAR target' ).
    f->label( 'Target field' ). DATA(tg) = f->combobox( selectedkey = mo_client->_bind_edit( rv_tgtf ) ).
    LOOP AT mt_fields INTO DATA(tfld). tg->item( key = tfld-field_name text = tfld-field_name ). ENDLOOP.
    f->label( 'Target value (SET)' ). f->input( value = mo_client->_bind_edit( rv_tgtval ) ).
    f->label( 'To-table' ).     f->input( value = mo_client->_bind_edit( rv_totable ) placeholder = 'optional — leave blank unless needed' ).

    DATA(b) = p->hbox( class = 'sapUiSmallMargin' ).
    b->button( text = 'Add / update rule' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ARULE' ) ).
    b->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_RULE' ) class = 'sapUiTinyMarginBegin' ).
    DATA(t) = p->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(c) = t->columns( ).
    c->column( )->text( 'ID' ). c->column( )->text( 'When field' ). c->column( )->text( 'Op' ). c->column( )->text( 'Value' ).
    c->column( )->text( 'Action' ). c->column( )->text( 'Target' ). c->column( )->text( 'Set to' ). c->column( )->text( '' ).
    DATA(it) = t->items( ).
    LOOP AT mt_rules INTO DATA(r).
      DATA(lv_dev) = |DL_RULE~{ r-rule_id }|.
      DATA(cells) = it->column_list_item( )->cells( ).
      cells->text( r-rule_id )->text( r-src_field )->text( r-src_op )->text( r-src_value
        )->text( r-action )->text( r-tgt_field )->text( r-tgt_value ).
      DATA(act) = cells->hbox( ).
      act->button( icon = 'sap-icon://edit' type = 'Transparent' tooltip = 'Edit' press = mo_client->_event( |EDRULE_{ r-rule_id }| ) ).
      act->button( icon = COND string( WHEN mv_arm_evt = lv_dev THEN 'sap-icon://alert' ELSE 'sap-icon://delete' )
                   type = COND string( WHEN mv_arm_evt = lv_dev THEN 'Reject' ELSE 'Transparent' )
                   tooltip = COND string( WHEN mv_arm_evt = lv_dev THEN 'Click again to confirm delete' ELSE 'Delete' )
                   press = mo_client->_event( lv_dev ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_preview.
    IF mv_preview IS INITIAL.
      io->message_strip( text = 'Save a journey (or pick a pattern) to preview it live here' type = 'Information' showicon = abap_true class = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.
    io->html( content = `<div class="rakSec">Live preview &mdash; ` && mv_preview && `</div>` sanitizecontent = abap_false ).
    DATA(lt) = io->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBegin' ).
    lt->label( text = 'Preview language:' class = 'sapUiTinyMarginEnd' ).
    lt->button( text  = 'English'
                press = mo_client->_event( 'PL_EN' )
                type  = COND string( WHEN mv_prev_lang = 'AR' THEN 'Transparent' ELSE 'Emphasized' ) ).
    lt->button( text  = 'العربية'
                press = mo_client->_event( 'PL_AR' )
                type  = COND string( WHEN mv_prev_lang = 'AR' THEN 'Emphasized' ELSE 'Transparent' ) ).
    lt->link( text = 'Open in new tab ↗' target = '_blank' class = 'sapUiSmallMarginBegin'
              href = engine_url( iv_journey = mv_preview iv_ar = xsdbool( mv_prev_lang = 'AR' ) ) ).
    IF field_exists( 'PAYFEE' ) = abap_true.
      io->message_strip( text     = 'This journey has a payment step. Preview opens the live gateway - do not press Pay now.'
                         type     = 'Warning'
                         showicon = abap_true
                         class    = 'sapUiSmallMargin' ).
    ENDIF.
    io->html(
      content = `<div style="padding:10px"><iframe src="` && engine_url( iv_journey = mv_preview iv_ar = xsdbool( mv_prev_lang = 'AR' ) )
             && `" style="width:100%;height:660px;border:0;border-radius:14px;box-shadow:0 10px 30px rgba(16,35,62,0.16)"></iframe></div>`
      sanitizecontent = abap_false ).
  ENDMETHOD.


  METHOD add_payment_step.
    IF fv_step IS INITIAL.
      mv_msg = 'Pick the target step in the Fields "Step ID" box (or the payment-step dropdown), then press Add payment step'.
      mv_mtype = 'Warning'. RETURN.
    ENDIF.
    DATA(lv_step) = to_upper( fv_step ).
    READ TABLE mt_steps TRANSPORTING NO FIELDS WITH KEY step_id = lv_step.
    IF sy-subrc <> 0.
      mv_msg = |Step { lv_step } does not exist|. mv_mtype = 'Error'. RETURN.
    ENDIF.
    IF field_exists( 'PAYFEE' ) = abap_true.
      mv_msg = 'This journey already has a PAYFEE field'. mv_mtype = 'Warning'. RETURN.
    ENDIF.

    DATA(lv_seq) = to_int( next_fseq( lv_step ) ).
    APPEND VALUE #( seqnr = |{ lv_seq }| step_id = lv_step field_name = 'PAYFEE'
                    ftype = 'PAYFEE' label = 'Payment' ) TO mt_fields.
    APPEND VALUE #( seqnr = |{ lv_seq + 10 }| step_id = lv_step field_name = 'PAY_STARTED'
                    ftype = 'INPUT' label = 'Payment started' hidden = abap_true ) TO mt_fields.
    APPEND VALUE #( seqnr = |{ lv_seq + 20 }| step_id = lv_step field_name = 'PAY_REFERENCE'
                    ftype = 'INPUT' label = 'Payment reference' hidden = abap_true ) TO mt_fields.
    APPEND VALUE #( seqnr = |{ lv_seq + 30 }| step_id = lv_step field_name = 'PAY_APPURL'
                    ftype = 'INPUT' label = 'Gateway URL' hidden = abap_true ) TO mt_fields.
    resort( ).

    mv_dirty = abap_true.
    mv_msg = |Payment step added to { lv_step }. Set handler_class and override prepare_payment.|.
    mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD auth_ok.
*   The Studio writes the live configuration of citizen-facing services and had no
*   authority check at all: anyone who could start the app could save or delete a
*   production journey.
*
*   S_DEVELOP is used as the guard because it exists on every system, so this
*   activates as-is: open to developers in DEV/QA, closed in PRD. For a dedicated
*   role, create Z_RAK_CJS in SU21 with field ACTVT (02 change / 03 display /
*   06 delete) and swap the object name below.
*   ---- TEMPORARY BYPASS - REVERT BEFORE ANY TRANSPORT PAST DEV ----------
*   Set LV_BYPASS to ABAP_FALSE to put the authority check back. Left as a
*   flag rather than deleting the check so restoring it is one character.
    DATA lv_bypass TYPE abap_bool.
    lv_bypass = abap_true.
    IF lv_bypass = abap_true.
      rv = abap_true.
      RETURN.
    ENDIF.

    AUTHORITY-CHECK OBJECT 'S_DEVELOP'
      ID 'DEVCLASS' DUMMY
      ID 'OBJTYPE'  FIELD 'TABL'
      ID 'OBJNAME'  FIELD 'ZRAK_T_JNY'
      ID 'P_GROUP'  DUMMY
      ID 'ACTVT'    FIELD iv_actvt.

    rv = xsdbool( sy-subrc = 0 ).
    IF rv = abap_false.
      mv_msg   = |You are not authorised for this action (activity { iv_actvt }). Ask Basis for the Journey Studio role.|.
      mv_mtype = 'Error'.
    ENDIF.
  ENDMETHOD.


  METHOD blocking_count.
    LOOP AT mt_lint TRANSPORTING NO FIELDS WHERE type = 'Error'.
      rv = rv + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD clear_cache.
*   THE LOADED JOURNEY, not everything.
*
*   invalidate( ) takes a journey id, and a blanket flush would have every work
*   process rebuild every cached journey on its next request. Fine on Dev at 4pm,
*   thoroughly unpleasant on Prod at 9am - and this Studio runs on both.
    DATA(lv_id) = COND #( WHEN mv_journey_id IS NOT INITIAL THEN mv_journey_id ELSE mv_sel ).

    IF lv_id IS INITIAL.
      mv_msg   = 'Load a journey first — there is nothing to clear'.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( lv_id ) ).

*   Saying what it did NOT do. The cache is not the page: a Preview already open
*   holds a journey rendered before this ran and will keep holding it. A button
*   that silently fails to refresh what is on screen gets reported as broken, so
*   the message names the next step instead of implying there isn't one.
    mv_msg   = |Cache cleared for { to_upper( lv_id ) } — reopen Preview, or relaunch the journey, to see the change|.
    mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD clear_field_form.
    CLEAR: mt_grid_preview, mv_grid_sel, mv_grid_warn.
    CLEAR: fv_seq, fv_field, fv_type, fv_label, fv_label_ar, fv_place, fv_place_ar, fv_default,
           fv_group, fv_sect, fv_state, fv_width, fv_hidden, fv_readonly, fv_req, fv_regex,
           fv_minlen, fv_maxlen, fv_minval, fv_maxval, fv_msg, fv_msg_ar, fv_tech, fv_roll, fv_shlp, fv_dom,
           fv_hasatt, fv_attlabel, fv_atttypes, fv_attmb, fv_attmulti.
  ENDMETHOD.


  METHOD clear_rule_form.
    CLEAR: rv_id, rv_srcf, rv_srcop, rv_srcval, rv_action, rv_tgtf, rv_tgtval, rv_totable.
  ENDMETHOD.


  METHOD doc_export.
    IF mv_journey_id IS INITIAL.
      mv_msg = 'Load or start a journey first — there is nothing to export'. mv_mtype = 'Warning'. RETURN.
    ENDIF.

*   The header goes out through snapshot( ), so the document and the audit
*   restore path can never describe a different set of fields. Session state -
*   which journey is selected, what is being previewed, whether there are
*   unsaved edits - is not part of the journey and is cleared before writing.
    DATA(ls_h) = snapshot( ).
    CLEAR: ls_h-sel, ls_h-preview, ls_h-dirty,
           ls_h-steps, ls_h-fields, ls_h-opts, ls_h-cols, ls_h-rules.

    DATA lt_out TYPE string_table.
    APPEND |{ c_doc } { to_upper( mv_journey_id ) }| TO lt_out.
    APPEND |H { /ui2/cl_json=>serialize( data = ls_h compress = abap_true ) }| TO lt_out.
    LOOP AT mt_steps INTO DATA(ls_s).
      APPEND |S { /ui2/cl_json=>serialize( data = ls_s compress = abap_true ) }| TO lt_out.
    ENDLOOP.
    LOOP AT mt_fields INTO DATA(ls_f).
      APPEND |F { /ui2/cl_json=>serialize( data = ls_f compress = abap_true ) }| TO lt_out.
    ENDLOOP.
    LOOP AT mt_opts INTO DATA(ls_o).
      APPEND |O { /ui2/cl_json=>serialize( data = ls_o compress = abap_true ) }| TO lt_out.
    ENDLOOP.
    LOOP AT mt_cols INTO DATA(ls_c).
      APPEND |C { /ui2/cl_json=>serialize( data = ls_c compress = abap_true ) }| TO lt_out.
    ENDLOOP.
    LOOP AT mt_rules INTO DATA(ls_r).
      APPEND |R { /ui2/cl_json=>serialize( data = ls_r compress = abap_true ) }| TO lt_out.
    ENDLOOP.

    CONCATENATE LINES OF lt_out INTO mv_doc SEPARATED BY cl_abap_char_utilities=>newline.
    mv_msg   = |{ to_upper( mv_journey_id ) } written as { lines( lt_out ) } line(s) — copy it into the repository, a ticket or a diff|.
    mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD doc_import.
    IF mv_doc IS INITIAL.
      mv_msg = 'Paste a journey document into the box first'. mv_mtype = 'Warning'. RETURN.
    ENDIF.

    DATA(lv_src) = mv_doc.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_src
            WITH cl_abap_char_utilities=>newline.
    SPLIT lv_src AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_in).

    DATA ls_d   TYPE ty_draft.
    DATA lv_tag TYPE abap_bool.
    DATA lv_bad TYPE i.

    LOOP AT lt_in INTO DATA(lv_line).
      DATA(lv_l) = lv_line.
      SHIFT lv_l LEFT DELETING LEADING space.
      IF strlen( lv_l ) < 2.
        CONTINUE.
      ENDIF.
      DATA(lv_kind) = lv_l(1).
      DATA(lv_json) = substring( val = lv_l off = 1 ).
      SHIFT lv_json LEFT DELETING LEADING space.

      IF lv_kind = '#'.
        IF lv_l CS c_doc.
          lv_tag = abap_true.
        ENDIF.
        CONTINUE.
      ENDIF.

*     One bad line is counted and skipped rather than thrown. A document that
*     lost a row in transit should still load the rest and say what it dropped -
*     refusing the whole file leaves the author with nothing to work from.
      TRY.
          CASE lv_kind.
            WHEN 'H'.
              /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_d ).
            WHEN 'S'.
              DATA ls_s TYPE ty_step.
              CLEAR ls_s.
              /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_s ).
              APPEND ls_s TO ls_d-steps.
            WHEN 'F'.
              DATA ls_f TYPE ty_fld.
              CLEAR ls_f.
              /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_f ).
              APPEND ls_f TO ls_d-fields.
            WHEN 'O'.
              DATA ls_o TYPE ty_opt.
              CLEAR ls_o.
              /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_o ).
              APPEND ls_o TO ls_d-opts.
            WHEN 'C'.
              DATA ls_c TYPE ty_col.
              CLEAR ls_c.
              /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_c ).
              APPEND ls_c TO ls_d-cols.
            WHEN 'R'.
              DATA ls_r TYPE ty_rule.
              CLEAR ls_r.
              /ui2/cl_json=>deserialize( EXPORTING json = lv_json CHANGING data = ls_r ).
              APPEND ls_r TO ls_d-rules.
            WHEN OTHERS.
              lv_bad = lv_bad + 1.
          ENDCASE.
        CATCH cx_root.
          lv_bad = lv_bad + 1.
      ENDTRY.
    ENDLOOP.

    IF lv_tag = abap_false.
      mv_msg = |That does not start with { c_doc }, so it is not a journey document written by this Studio.|.
      mv_mtype = 'Error'. RETURN.
    ENDIF.
    IF ls_d-journey_id IS INITIAL OR ls_d-steps IS INITIAL.
      mv_msg = 'The document carries no journey ID or no steps — nothing was loaded.'.
      mv_mtype = 'Error'. RETURN.
    ENDIF.

*   Deliberately does NOT write. The draft is replaced, the author reviews it,
*   and Save puts it through the same blocking-errors gate as anything typed by
*   hand. An import that saved itself would be the one way into the database
*   that skips every check the Studio has.
    ls_d-sel = mv_sel.
    restore( ls_d ).
    resort( ).
    SORT mt_rules BY rule_id.
    mv_dirty = abap_true.
    CLEAR: mt_f4_scan, mv_f4_scanned, mv_fld_filter, mv_only_bad.

    mv_msg = |Loaded { to_upper( ls_d-journey_id ) } from the document — { lines( mt_steps ) } steps, | &&
             |{ lines( mt_fields ) } fields, { lines( mt_rules ) } rules| &&
             COND string( WHEN lv_bad > 0 THEN |, { lv_bad } line(s) unreadable and skipped| ) &&
             |. Nothing is written until you Save.|.
    mv_mtype = COND string( WHEN lv_bad > 0 THEN 'Warning' ELSE 'Success' ).
  ENDMETHOD.


  METHOD dsg_clear.

    zcl_rak_cj_lay=>get_instance( )->reset_block(
      iv_journey = CONV #( to_upper( mv_journey_id ) )
      iv_step    = CONV #( to_upper( iv_step ) )
      iv_block   = '*' ).

    zcl_rak_cj_cfg_cache=>invalidate( to_upper( mv_journey_id ) ).

    mv_msg   = |Layout cleared for { iv_step } — the step renders the classic way again|.
    mv_mtype = 'Success'.

  ENDMETHOD.


  METHOD dsg_event.

    IF iv_ev NP 'DSG_*'.
      RETURN.
    ENDIF.

    SPLIT iv_ev AT '~' INTO TABLE DATA(lt_k).
    DATA(lv_cmd) = CONV string( lt_k[ 1 ] ).

    IF lv_cmd = 'DSG_CLR'.
      IF armed( iv_ev   = 'DSG_CLR'
                iv_warn = |Clear the layout for { to_upper( mv_dsg_step ) }? Every row and width | &&
                          |on this step goes, and it renders the classic way again. | &&
                          |Press Clear again to confirm.| ) = abap_true.
        dsg_clear( mv_dsg_step ).
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_cmd = 'DSG_DEV'.
      IF lines( lt_k ) >= 2.
        mv_dsg_dev = to_upper( CONV string( lt_k[ 2 ] ) ).
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_cmd = 'DSG_STEP'.
      CLEAR: mv_dsg_fld, mv_dsg_en, mv_dsg_ar.
      RETURN.
    ENDIF.

    IF lv_cmd = 'DSG_TXCA'.
      CLEAR: mv_dsg_fld, mv_dsg_en, mv_dsg_ar.
      RETURN.
    ENDIF.

    IF lv_cmd = 'DSG_TXOK'.
      READ TABLE mt_fields ASSIGNING FIELD-SYMBOL(<tf>)
           WITH KEY step_id = to_upper( mv_dsg_step ) field_name = to_upper( mv_dsg_fld ).
      IF sy-subrc = 0.
        <tf>-label    = mv_dsg_en.
        <tf>-label_ar = mv_dsg_ar.
        NEW zcl_rak_cj_text_src_cfg( )->zif_rak_cj_text_src~write(
          VALUE #( ( journey  = to_upper( mv_journey_id )
                     step_id  = to_upper( mv_dsg_step )
                     block_id = <tf>-section
                     elem_id  = to_upper( mv_dsg_fld )
                     txt_kind = zcl_rak_cj_text_src_cfg=>c_kind-label
                     text_en  = mv_dsg_en
                     text_ar  = mv_dsg_ar ) ) ).
        mv_msg   = |{ mv_dsg_fld } text saved|.
        mv_mtype = 'Success'.
      ENDIF.
      CLEAR: mv_dsg_fld, mv_dsg_en, mv_dsg_ar.
      RETURN.
    ENDIF.

    IF lv_cmd = 'DSG_SEED'.
      dsg_save( iv_step = mv_dsg_step it = dsg_plan( mv_dsg_step ) ).
      mv_msg   = |{ mv_dsg_step } is now laid out — existing pairs were kept|.
      mv_mtype = 'Success'.
      RETURN.
    ENDIF.

    IF lines( lt_k ) < 2.
      RETURN.
    ENDIF.

    DATA(lv_fld) = to_upper( CONV string( lt_k[ 2 ] ) ).

    IF lv_cmd = 'DSG_TX'.
      READ TABLE mt_fields INTO DATA(ls_tx)
           WITH KEY step_id = to_upper( mv_dsg_step ) field_name = lv_fld.
      IF sy-subrc = 0.
        mv_dsg_fld = lv_fld.
        mv_dsg_en  = ls_tx-label.
        mv_dsg_ar  = ls_tx-label_ar.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(lt)     = dsg_plan( mv_dsg_step ).

    READ TABLE lt ASSIGNING FIELD-SYMBOL(<d>) WITH KEY field = lv_fld.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   Highest row currently in use, and how many fields share the moved field's
*   row. Both are needed before the move: a lone field in the last row has
*   nowhere to go downwards, and pressing Down anyway used to increment a row
*   number nobody could see, leaving the screen unchanged and one press of Up
*   needed to undo an invisible change.
    DATA lv_maxrow TYPE i.
    DATA lv_kin    TYPE i.
    LOOP AT lt INTO DATA(ls_mx).
      IF ls_mx-row > lv_maxrow.
        lv_maxrow = ls_mx-row.
      ENDIF.
      IF ls_mx-row = <d>-row.
        lv_kin = lv_kin + 1.
      ENDIF.
    ENDLOOP.

*   Which fields shared the row being left. After the move these two sets - the
*   row the field went to, and the row it came from - are the only ones whose
*   membership changed, so they are the only ones that get re-spaced. Re-spacing
*   every row (which is what this did) threw away every width the author had set
*   anywhere on the step, for the sake of moving one field one row.
    DATA lt_left TYPE string_table.
    LOOP AT lt INTO DATA(ls_lf) WHERE row = <d>-row.
      IF ls_lf-field <> lv_fld.
        APPEND ls_lf-field TO lt_left.
      ENDIF.
    ENDLOOP.

    CASE lv_cmd.
      WHEN 'DSG_RU'.
        IF <d>-row <= 1.
          RETURN.
        ENDIF.
        <d>-row = <d>-row - 1.
      WHEN 'DSG_RD'.
*       Past the last row only if the field is not already alone there.
        IF <d>-row >= lv_maxrow AND lv_kin <= 1.
          RETURN.
        ENDIF.
        <d>-row = <d>-row + 1.
      WHEN 'DSG_ML' OR 'DSG_MR'.
        DATA(lv_dir) = COND i( WHEN lv_cmd = 'DSG_ML' THEN -1 ELSE 1 ).
        DATA(lv_tgt) = <d>-col + lv_dir.
        READ TABLE lt ASSIGNING FIELD-SYMBOL(<s>)
             WITH KEY row = <d>-row col = lv_tgt.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        <s>-col = <d>-col.
        <d>-col = lv_tgt.
      WHEN 'DSG_SM'.
        IF <d>-span <= 1.
          RETURN.
        ENDIF.
        <d>-span = <d>-span - 1.
      WHEN 'DSG_SP'.
        IF <d>-span >= 12.
          RETURN.
        ENDIF.
        <d>-span = <d>-span + 1.
      WHEN OTHERS.
        RETURN.
    ENDCASE.

*   Close any gap the move opened. Moving the only field out of row 2 used to
*   leave rows 1 and 3, and the editor then labelled them "Row 1" and "Row 3"
*   with no Row 2 in between.
    SORT lt BY row ASCENDING col ASCENDING.
    DATA lv_seen TYPE i.
    DATA lv_next TYPE i.
    LOOP AT lt ASSIGNING FIELD-SYMBOL(<g>).
      IF <g>-row <> lv_seen.
        lv_seen = <g>-row.
        lv_next = lv_next + 1.
      ENDIF.
      <g>-row = lv_next.
    ENDLOOP.

    SORT lt BY row ASCENDING col ASCENDING.
    DATA lv_prow TYPE i.
    DATA lv_pcol TYPE i.
    LOOP AT lt ASSIGNING FIELD-SYMBOL(<c>).
      IF <c>-row <> lv_prow.
        lv_pcol = 0.
        lv_prow = <c>-row.
      ENDIF.
      lv_pcol  = lv_pcol + 1.
      <c>-col  = lv_pcol.
    ENDLOOP.

    IF lv_cmd = 'DSG_RU' OR lv_cmd = 'DSG_RD'.
*     The two rows whose membership changed, found by field rather than by row
*     number - the compaction above may have renumbered both of them.
      DATA lt_touch TYPE STANDARD TABLE OF i WITH EMPTY KEY.
      READ TABLE lt INTO DATA(ls_now) WITH KEY field = lv_fld.
      IF sy-subrc = 0.
        APPEND ls_now-row TO lt_touch.
      ENDIF.
      LOOP AT lt_left INTO DATA(lv_was).
        READ TABLE lt INTO DATA(ls_old) WITH KEY field = lv_was.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
*       Not COLLECT: the line type is a bare integer, so every component is
*       numeric and COLLECT would sum the row numbers into one line instead of
*       keeping them distinct.
        READ TABLE lt_touch TRANSPORTING NO FIELDS WITH KEY table_line = ls_old-row.
        IF sy-subrc <> 0.
          APPEND ls_old-row TO lt_touch.
        ENDIF.
      ENDLOOP.

      DATA lv_mem TYPE i.
      LOOP AT lt_touch INTO DATA(lv_r).
        lv_mem = 0.
        LOOP AT lt TRANSPORTING NO FIELDS WHERE row = lv_r.
          lv_mem = lv_mem + 1.
        ENDLOOP.
        IF lv_mem < 1.
          CONTINUE.
        ENDIF.
        LOOP AT lt ASSIGNING FIELD-SYMBOL(<a>) WHERE row = lv_r.
          <a>-span = COND i( WHEN 12 / lv_mem < 1 THEN 1 ELSE 12 / lv_mem ).
        ENDLOOP.
      ENDLOOP.
    ENDIF.

    dsg_save( iv_step = mv_dsg_step it = lt ).

*   Read the moved field back out of LT - <d> pointed into the table before it
*   was sorted twice, so it no longer names the field the message is about.
    READ TABLE lt INTO DATA(ls_msg) WITH KEY field = lv_fld.
    IF sy-subrc = 0.
      DATA lv_fill TYPE i.
      LOOP AT lt INTO DATA(ls_fi) WHERE row = ls_msg-row.
        lv_fill = lv_fill + ls_fi-span.
      ENDLOOP.
      mv_msg   = |{ lv_fld }: row { ls_msg-row }, position { ls_msg-col }, | &&
                 |span { ls_msg-span } of 12 — row now { lv_fill } of 12| &&
                 COND string( WHEN lv_fill > 12 THEN ` (over: the row will wrap)` ).
      mv_mtype = COND string( WHEN lv_fill > 12 THEN 'Warning' ELSE 'Success' ).
    ENDIF.

  ENDMETHOD.


  METHOD dsg_plan.

    TYPES: BEGIN OF ty_ord,
             seq TYPE i,
             fld TYPE ty_fld,
           END OF ty_ord.

    DATA lt_ord  TYPE STANDARD TABLE OF ty_ord WITH EMPTY KEY.
    DATA lt_elem TYPE zcl_rak_cj_lay=>ty_t_elem.
    DATA lv_row  TYPE i.
    DATA lv_tok  TYPE string.
    DATA lv_n    TYPE i.

    DATA(lv_st) = to_upper( iv_step ).
    IF lv_st IS INITIAL OR mv_journey_id IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT mt_fields INTO DATA(ls_f) WHERE step_id = lv_st.
      IF ls_f-hidden = abap_true.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( seq = to_int( ls_f-seqnr ) fld = ls_f ) TO lt_ord.
    ENDLOOP.
    SORT lt_ord BY seq ASCENDING.

    DATA(lo_lay) = zcl_rak_cj_lay=>get_instance( ).
    DATA(lv_jny) = CONV zcl_rak_cj_lay=>ty_key( to_upper( mv_journey_id ) ).
    DATA(lv_key) = CONV zcl_rak_cj_lay=>ty_key( lv_st ).

    IF lo_lay->has_layout( iv_journey = lv_jny iv_step = lv_key ) = abap_true.

      LOOP AT lt_ord INTO DATA(ls_o1).
        APPEND CONV zcl_rak_cj_lay=>ty_key( ls_o1-fld-field_name ) TO lt_elem.
      ENDLOOP.

      DATA(lt_rows) = lo_lay->plan( iv_journey = lv_jny
                                    iv_step    = lv_key
                                    iv_block   = space
                                    it_elem    = lt_elem ).

      LOOP AT lt_rows INTO DATA(ls_r).
        LOOP AT ls_r-cells INTO DATA(ls_c).
          READ TABLE lt_ord INTO DATA(ls_o2)
               WITH KEY fld-field_name = CONV string( ls_c-elem_id ).
          APPEND VALUE #( field = ls_c-elem_id
                          ftype = ls_o2-fld-ftype
                          row   = ls_r-row_no
                          col   = COND i( WHEN ls_c-attr-col_start > 0
                                          THEN ls_c-attr-col_start
                                          ELSE sy-tabix )
                          span  = ls_c-attr-col_span ) TO rt.
        ENDLOOP.
      ENDLOOP.

      RETURN.

    ENDIF.

    LOOP AT lt_ord INTO DATA(ls_o3).
      DATA(lv_t) = row_tok( ls_o3-fld-fgroup ).
      IF lv_t IS INITIAL OR lv_t <> lv_tok.
        lv_row = lv_row + 1.
      ENDIF.
      lv_tok = lv_t.
      APPEND VALUE #( field = ls_o3-fld-field_name
                      ftype = ls_o3-fld-ftype
                      row   = lv_row
                      col   = sy-tabix
                      span  = 12 ) TO rt.
    ENDLOOP.

    LOOP AT rt ASSIGNING FIELD-SYMBOL(<d>).
      lv_n = 0.
      LOOP AT rt TRANSPORTING NO FIELDS WHERE row = <d>-row.
        lv_n = lv_n + 1.
      ENDLOOP.
      IF lv_n < 1.
        lv_n = 1.
      ENDIF.
      <d>-span = COND i( WHEN 12 / lv_n < 1 THEN 1 ELSE 12 / lv_n ).
    ENDLOOP.

  ENDMETHOD.


  METHOD dsg_save.

    DATA(lo_lay) = zcl_rak_cj_lay=>get_instance( ).
    DATA(lv_jny) = CONV zcl_rak_cj_lay=>ty_key( to_upper( mv_journey_id ) ).
    DATA(lv_key) = CONV zcl_rak_cj_lay=>ty_key( to_upper( iv_step ) ).

    LOOP AT it INTO DATA(ls).
      lo_lay->persist( iv_journey = lv_jny
                       iv_step    = lv_key
                       iv_block   = '*'
                       iv_elem    = CONV #( ls-field )
                       is_attr    = VALUE #( row_no    = ls-row
                                             col_start = ls-col
                                             col_span  = ls-span ) ).
    ENDLOOP.

    zcl_rak_cj_cfg_cache=>invalidate( to_upper( mv_journey_id ) ).

  ENDMETHOD.


  METHOD engine_url.
    DATA(cfg) = mo_client->get( )-s_config.
    rv = |{ cfg-origin }{ cfg-pathname }?sap-client={ sy-mandt }| &&
         |&app_start=ZCL_RAK_JOURNEY_ENGINE&journey={ to_upper( iv_journey ) }|.
    IF iv_ar = abap_true.
      rv = rv && `&lang=ar&sap-ui-rtl=true`.
    ENDIF.
    IF iv_step >= 0.
      rv = rv && |&step={ iv_step }|.
    ENDIF.
  ENDMETHOD.


  METHOD field_exists.
    READ TABLE mt_fields TRANSPORTING NO FIELDS WITH KEY field_name = to_upper( iv_field ).
    rv = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD free_id.
*   Was an unbounded DO: a SELECT that keeps hitting spins the work process
*   forever. 99 tries, then fall back to a time-stamped id that cannot collide.
    DATA lv_ex TYPE abap_bool.
    DATA(base) = to_upper( iv_base ).
    rv = base.
    DO 99 TIMES.
      SELECT SINGLE @abap_true FROM zrak_t_jny WHERE journey_id = @rv INTO @lv_ex.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      rv = |{ base }{ sy-index + 1 }|.
    ENDDO.
    rv = |{ base }{ sy-uzeit }|.
  ENDMETHOD.


  METHOD is_choice.
    DATA(t) = to_upper( iv_type ).
    rv = xsdbool( t = 'SELECT' OR t = 'RADIO' OR t = 'MULTISELECT' OR t = 'SEGMENTED' OR t = 'CHECKGROUP' ).
  ENDMETHOD.


  METHOD is_input.
*   Types that never carry a value to the backend. REVIEW / RO_PANEL / RECORDCARD
*   were added to the engine later and were missing here, which made lint( ) emit a
*   bogus "no tech_name" warning for every one of them.
*   EDITABLE_TABLE stays IN: it does post, as grid JSON, and it needs a tech_name.
    DATA(t) = to_upper( iv_type ).
    rv = xsdbool( t <> 'DISPLAY'  AND t <> 'READONLY'   AND t <> 'TABLE'    AND t <> 'UPLOAD'
              AND t <> 'STATUS'   AND t <> 'OBJNUM'     AND t <> 'PROGRESS' AND t <> 'LINK'
              AND t <> 'PAYFEE'   AND t <> 'REVIEW'     AND t <> 'RO_PANEL'
              AND t <> 'RECORDCARD' AND t <> 'REQPANEL' ).
  ENDMETHOD.


  METHOD is_reserved.
    DATA(f) = to_upper( iv_field ).
*   Also block the names the ENGINE synthesises into the model for itself:
*   <FIELD>_VS / <FIELD>_VST (value state) and the DUMMY fallback component.
    rv = xsdbool( f = 'PAYFEE'
               OR f = 'PAY_STARTED'   OR f CP 'PAY_STARTED_*'
               OR f = 'PAY_REFERENCE' OR f CP 'PAY_REFERENCE_*'
               OR f = 'PAY_APPURL'    OR f CP 'PAY_APPURL_*'
               OR f CP '*_BLOB'
               OR f = 'DUMMY'
               OR f CP '*_VS'
               OR f CP '*_VST'
               OR f CP '*_EXP' ).
  ENDMETHOD.


  METHOD lint.
    LOOP AT mt_fields INTO DATA(f).
      IF is_choice( f-ftype ) = abap_true.
        DATA lv_opts TYPE i.
        lv_opts = 0.
        LOOP AT mt_opts INTO DATA(o) WHERE step_id = f-step_id AND field_name = f-field_name.
          lv_opts = lv_opts + 1.
        ENDLOOP.
        IF lv_opts = 0 AND f-rollname IS INITIAL AND f-shlp IS INITIAL AND f-domname IS INITIAL.
          APPEND VALUE #( type = 'Error'
            text = |{ f-step_id }/{ f-field_name }: { f-ftype } has no options, rollname, domain or search help → renders EMPTY| ) TO rt.
        ENDIF.
      ENDIF.

      IF is_input( f-ftype ) = abap_true AND f-tech_name IS INITIAL AND is_reserved( f-field_name ) = abap_false.
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: no tech_name → value won't post to the backend| ) TO rt.
      ENDIF.

      READ TABLE mt_steps TRANSPORTING NO FIELDS WITH KEY step_id = f-step_id.
      IF sy-subrc <> 0.
        APPEND VALUE #( type = 'Error'
          text = |{ f-step_id }/{ f-field_name }: references step '{ f-step_id }' which is not defined| ) TO rt.
      ENDIF.

      IF f-required = abap_true AND f-hidden = abap_true.
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: required AND hidden → user can never fill it, submit blocks| ) TO rt.
      ENDIF.

*     A CHOICE CONTROL THAT ANSWERS ITSELF.
*
*     SEGMENTED renders with its first option selected when the field is empty -
*     sap.m.SegmentedButton offers no unselected state, unlike RADIO, which the
*     renderer drives with an index of -1 for exactly this reason. So the citizen
*     is shown an answer they never gave, and REQUIRED cannot catch it because the
*     control is not empty as far as the screen is concerned.
*
*     On a consent or declaration question that is not cosmetic. DOK_ADV_EVGENY_DEMO
*     shipped with CONSENT_REQUIRED defaulted to YES - 'does the advertisement
*     include participants that would require consent' answered affirmatively for
*     everyone who scrolled past it.
*
*     Warning and not Error, because a two-option control with a genuine default is
*     legitimate. The author is the one who can tell those apart.
      IF to_upper( f-ftype ) = 'SEGMENTED' AND f-default_val IS INITIAL.
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: SEGMENTED with no default → the first | &&
                 |option renders SELECTED, so a citizen can submit an answer they never | &&
                 |gave. Set default_val to the neutral option, or use RADIO, which can | &&
                 |render unselected.| ) TO rt.
      ENDIF.

*     The opposite failure, and the one that actually shipped: a default on a
*     question whose whole purpose is that the citizen answers it. Nothing can tell
*     from the type alone that a field is a declaration, so this reads the LABEL -
*     crude, but it is the only place the intent is written down.
      IF is_choice( f-ftype ) = abap_true AND f-default_val IS NOT INITIAL
         AND ( to_upper( f-label ) CS 'CONSENT' OR to_upper( f-label ) CS 'DECLAR'
            OR to_upper( f-label ) CS 'AGREE'   OR to_upper( f-label ) CS 'CERTIF' ).
        APPEND VALUE #( type = 'Error'
          text = |{ f-step_id }/{ f-field_name }: reads as a consent or declaration and | &&
                 |carries default '{ f-default_val }' → the answer is recorded whether | &&
                 |the citizen read the question or not. Clear the default.| ) TO rt.
      ENDIF.

*     A shared sequence leaves the order between the two arbitrary - resort( )
*     holds them steady in the session, but nothing decides which comes back
*     first after a save, so the page can render them either way round.
      LOOP AT mt_fields INTO DATA(ds) WHERE step_id = f-step_id
                                        AND field_name <> f-field_name.
        IF to_int( ds-seqnr ) = to_int( f-seqnr ).
          APPEND VALUE #( type = 'Warning'
            text = |{ f-step_id }/{ f-field_name }: sequence { f-seqnr } is also used by { ds-field_name }. | &&
                   |Which one renders first is not decided by anything - give them separate numbers.| ) TO rt.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF to_int( f-min_len ) > 0 AND to_int( f-max_len ) > 0 AND to_int( f-min_len ) > to_int( f-max_len ).
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: min_len { f-min_len } > max_len { f-max_len }| ) TO rt.
      ENDIF.

      IF to_upper( f-field_name ) = 'PAYFEE'.
        IF to_upper( f-ftype ) <> 'PAYFEE'.
          APPEND VALUE #( type = 'Error'
            text = |PAYFEE must have type PAYFEE, not { f-ftype } → renders as a text box| ) TO rt.
        ENDIF.
        IF f-required = abap_true.
          APPEND VALUE #( type = 'Warning'
            text = 'PAYFEE marked required → the user sees a duplicate "is required" message. Uncheck it.' ) TO rt.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF mv_handler IS INITIAL.
      LOOP AT mt_fields INTO DATA(gt)
           WHERE ftype = 'RECORDCARD' OR ftype = 'TABLE' OR ftype = 'RO_PANEL'.
        APPEND VALUE #( type = 'Error'
          text = |{ gt-step_id }/{ gt-field_name }: { gt-ftype } is filled by the handler's get_table( ) — with no handler_class it renders empty| ) TO rt.
      ENDLOOP.
    ENDIF.

*   ---- values that reach UI5 as enum members --------------------------------
*   ACCENT and DENSITY are not compared against anything in our code - they are
*   handed STRAIGHT to sap.m as enum members, and sap.m's enums are
*   case-sensitive. 'EMPHASIZED' is not sap.m.ButtonType Emphasized; it is an
*   invalid value, the control falls back to Default, and the primary action on
*   every step renders as a plain white button. 'COZY' fails one level up:
*   density_class( ) matches 'Cozy' exactly and returns blank, so no density
*   class is applied at all.
*
*   Neither failure says anything at runtime. The journey definition reads
*   exactly as the author intended and the page is simply wrong - which is how
*   D008 ran with a white Submit while its header and step dots were correctly
*   branded, and why it took a screenshot and a table dump to find.
*
*   THEME VARIANT and LAYOUT are deliberately NOT checked this way: those are
*   ours, compared uppercase against uppercase literals in the CSS builder, so
*   any case works there.
    IF mv_accent IS NOT INITIAL.
*     Through a real local rather than a constructor expression inline: a table
*     row selection needs an addressable table, and VALUE #( )[ ] in a
*     line_exists( ) argument is not one.
      DATA(lt_btype) = VALUE string_table(
             ( `Emphasized` ) ( `Default` ) ( `Transparent` ) ( `Ghost` )
             ( `Accept` ) ( `Reject` ) ( `Attention` ) ( `Critical` )
             ( `Negative` ) ( `Neutral` ) ( `Success` ) ).
      IF NOT line_exists( lt_btype[ table_line = mv_accent ] ).
        APPEND VALUE #( type = 'Error'
          text = |Accent '{ mv_accent }' is not a sap.m.ButtonType. The enum is | &&
                 |CASE-SENSITIVE, so every primary button on this journey silently | &&
                 |falls back to a plain Default button. Expected exactly one of | &&
                 |Emphasized, Default, Transparent, Ghost, Accept, Reject, Attention, | &&
                 |Critical, Negative, Neutral, Success.| ) TO rt.
      ENDIF.
    ENDIF.

    IF mv_density IS NOT INITIAL AND mv_density <> 'Cozy' AND mv_density <> 'Compact'.
      APPEND VALUE #( type = 'Error'
        text = |Density '{ mv_density }' is neither 'Cozy' nor 'Compact' — and the match | &&
               |is case-sensitive, so no density class is applied and the journey | &&
               |renders at the shell default.| ) TO rt.
    ENDIF.

*   ---- a grid spec that names one column twice -----------------------------
*   Grid columns become MODEL MEMBERS, and a structure cannot hold the same
*   component twice: build_model( ) dedupes on name and the second definition is
*   dropped. The grid still draws BOTH headers, both bound to the same cell, so
*   two columns show one value and whichever the citizen types into overwrites
*   the other.
*
*   Found on D003 LICENSES, where VALIDTO was used for both 'Issued at' and
*   'Expired at' - a licence that appeared to expire on the day it was issued.
    LOOP AT mt_fields INTO DATA(gs) WHERE ftype = 'EDITABLE_TABLE' AND default_val IS NOT INITIAL.
      SPLIT gs-default_val AT '|' INTO TABLE DATA(lt_gspec).
      DATA lt_gseen TYPE string_table.
      CLEAR lt_gseen.
      LOOP AT lt_gspec INTO DATA(lv_gcol).
        SPLIT condense( lv_gcol ) AT ':' INTO DATA(lv_gn) DATA(lv_grest).
        lv_gn = to_upper( condense( lv_gn ) ).
*       SEL and FIX are directives, not columns - grid_cols( ) skips both, so
*       neither can collide with anything and neither reaches the model.
        IF lv_gn IS INITIAL OR lv_gn = 'SEL' OR lv_gn = 'FIX'.
          CONTINUE.
        ENDIF.
        READ TABLE lt_gseen TRANSPORTING NO FIELDS WITH KEY table_line = lv_gn.
        IF sy-subrc = 0.
          APPEND VALUE #( type = 'Error'
            text = |{ gs-step_id }/{ gs-field_name }: column '{ lv_gn }' is defined | &&
                   |twice. Both headers bind to one model member, so the two columns | &&
                   |show the same value and overwrite each other. Give the second one | &&
                   |its own name.| ) TO rt.
        ELSE.
          APPEND lv_gn TO lt_gseen.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    IF field_exists( 'PAYFEE' ) = abap_true.
      IF mv_handler IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = 'PAYFEE present but handler_class is empty → payment cannot render. Set a subclass of ZCL_RAK_JOURNEY_LOGIC.' ) TO rt.
      ENDIF.
      LOOP AT VALUE string_table( ( `PAY_STARTED` ) ( `PAY_REFERENCE` ) ( `PAY_APPURL` ) ) INTO DATA(lv_need).
        IF field_exists( lv_need ) = abap_false.
*         Warning, not Error, and no longer "payment will not survive
*         round-trips" - that stopped being true when BUILD_MODEL began
*         synthesising these three members for any journey with a PAYFEE
*         control. The slots now exist whether or not anyone authored them.
*
*         Still worth saying. A journey missing them was almost certainly
*         built by dropping a PAYFEE into the field grid by hand rather than
*         pressing Add payment step, and whatever else that author skipped is
*         not covered by an engine default.
          APPEND VALUE #( type = 'Warning'
            text = |PAYFEE present but { lv_need } was never authored. The engine supplies | &&
                   |the slot, so payment works - but this journey did not come from | &&
                   |Add payment step, so check the rest of the step by hand.| ) TO rt.
        ENDIF.
      ENDLOOP.
      READ TABLE mt_fields INTO DATA(lp) WITH KEY field_name = 'PAYFEE'.
      IF sy-subrc = 0.
        READ TABLE mt_steps INTO DATA(lps) WITH KEY step_id = lp-step_id.
        IF sy-subrc = 0 AND to_int( lps-seqnr ) <= to_int( VALUE #( mt_steps[ 1 ]-seqnr OPTIONAL ) ).
          APPEND VALUE #( type = 'Warning'
            text = |Payment sits on the first step ({ lp-step_id }) → get_case( ) is still empty there. Move it after a step that saves the case.| ) TO rt.
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT mt_fields INTO DATA(a) WHERE tech_name IS NOT INITIAL.
      LOOP AT mt_fields INTO DATA(b) WHERE tech_name = a-tech_name AND field_name <> a-field_name.
        IF a-field_name < b-field_name.
          APPEND VALUE #( type = 'Error'
            text = |tech_name '{ a-tech_name }' shared by { a-field_name } and { b-field_name } → they overwrite in the backend| ) TO rt.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT mt_steps INTO DATA(stp) WHERE bknd_screen IS INITIAL.
      LOOP AT mt_fields INTO DATA(mf) WHERE step_id = stp-step_id AND tech_name IS NOT INITIAL.
        APPEND VALUE #( type = 'Warning'
          text = |Step { stp-step_id } has mapped fields but no backend screen → their POST has no target| ) TO rt.
        EXIT.
      ENDLOOP.
    ENDLOOP.

*   NEXT_REQUIRES is a hand-typed field name with nothing checking it, so this
*   does. The engine fails OPEN on a bad name - the button stays live and the
*   trace explains - which is right at runtime and useless at authoring time,
*   because nobody reads a trace for a gate that quietly did nothing.
    LOOP AT mt_steps INTO DATA(stq) WHERE next_requires IS NOT INITIAL.
      IF field_exists( stq-next_requires ) = abap_false.
        APPEND VALUE #( type = 'Error'
          text = |Step { stq-step_id }/NEXT_REQUIRES: '{ stq-next_requires }' is not a field on | &&
                 |this journey → the gate is ignored and the button is always enabled| ) TO rt.
        CONTINUE.
      ENDIF.
*     The gate reads the field's VALUE, so a field the citizen cannot fill and
*     nothing else writes locks the step for good. PAYFEE is the case it was
*     built for and is written by the payment poll; anything else needs a rule,
*     a handler or the citizen behind it.
      READ TABLE mt_fields INTO DATA(gf)
        WITH KEY step_id = stq-step_id field_name = to_upper( stq-next_requires ).
      IF sy-subrc <> 0.
        APPEND VALUE #( type = 'Warning'
          text = |Step { stq-step_id }/NEXT_REQUIRES: '{ stq-next_requires }' is on a DIFFERENT step. | &&
                 |That works, but check something fills it before the citizen gets here| ) TO rt.
      ELSEIF gf-readonly = 'X' AND to_upper( gf-ftype ) <> 'PAYFEE'.
        APPEND VALUE #( type = 'Warning'
          text = |Step { stq-step_id }/NEXT_REQUIRES: '{ stq-next_requires }' is read-only. | &&
                 |Unless a rule or handler writes it, this step cannot be left| ) TO rt.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_rules INTO DATA(r).
      IF r-totable IS NOT INITIAL.
*       Grid-scoped (ZCL_RAK_JOURNEY_RULES routes these separately, see
*       LOAD_GRID_RULES). TGT_FIELD must be a column of the TOTABLE grid.
*       SRC_FIELD is valid either as a column of that same grid (per row)
*       or as an ordinary field (whole column) - checking FIELD_EXISTS
*       alone here would flag every per-row rule as broken.
        IF r-tgt_field IS NOT INITIAL
           AND NOT line_exists( mt_cols[ field_name = to_upper( r-totable ) col_name = to_upper( r-tgt_field ) ] ).
          APPEND VALUE #( type = 'Error'
            text = |Rule { r-rule_id }: tgt_field '{ r-tgt_field }' is not a column of grid { r-totable } → no effect| ) TO rt.
        ENDIF.
        IF r-src_field IS NOT INITIAL
           AND field_exists( r-src_field ) = abap_false
           AND NOT line_exists( mt_cols[ field_name = to_upper( r-totable ) col_name = to_upper( r-src_field ) ] ).
          APPEND VALUE #( type = 'Error'
            text = |Rule { r-rule_id }: src_field '{ r-src_field }' is neither a defined field nor a column of grid { r-totable } → rule never fires| ) TO rt.
        ENDIF.
      ELSE.
        IF r-src_field IS NOT INITIAL AND field_exists( r-src_field ) = abap_false.
          APPEND VALUE #( type = 'Error'
            text = |Rule { r-rule_id }: src_field '{ r-src_field }' is not a defined field → rule never fires| ) TO rt.
        ENDIF.
        IF r-tgt_field IS NOT INITIAL AND field_exists( r-tgt_field ) = abap_false.
          APPEND VALUE #( type = 'Error'
            text = |Rule { r-rule_id }: tgt_field '{ r-tgt_field }' is not a defined field → no effect| ) TO rt.
        ENDIF.
      ENDIF.
      IF r-src_op <> 'EQ' AND r-src_op <> 'NE' AND r-src_op <> 'INITIAL' AND r-src_op <> 'NOTINITIAL'
         AND r-src_op <> 'GT' AND r-src_op <> 'LT' AND r-src_op <> 'GE' AND r-src_op <> 'LE'.
        APPEND VALUE #( type = 'Error'
          text = |Rule { r-rule_id }: operator '{ r-src_op }' is not one of EQ/NE/INITIAL/NOTINITIAL/GT/LT/GE/LE → never fires| ) TO rt.
      ENDIF.
*     READONLY/EDITABLE were missing here even though ZCL_RAK_JOURNEY_RULES
*     has always accepted them (see EVAL_RULES) - every rule using either
*     action was flagged as broken when it was not. Confirmed live on
*     journey AS3, rules R09/R10/R12-R15B/R18/R19.
      IF r-action <> 'SHOW' AND r-action <> 'HIDE' AND r-action <> 'REQUIRE'
         AND r-action <> 'OPTIONAL' AND r-action <> 'READONLY' AND r-action <> 'EDITABLE'
         AND r-action <> 'SET' AND r-action <> 'CLEAR'.
        APPEND VALUE #( type = 'Error'
          text = |Rule { r-rule_id }: action '{ r-action }' is not a valid action → no effect| ) TO rt.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_fields INTO DATA(tc) WHERE ftype = 'TABLE' AND default_val CP 'CHK:*'.
      DATA(lv_cneed) = to_upper( substring( val = tc-default_val off = 4 ) ).
      IF field_exists( lv_cneed ) = abap_false.
        APPEND VALUE #( type = 'Error'
          text = |{ tc-step_id }/{ tc-field_name }: checkbox table needs a hidden field '{ lv_cneed }' to hold the checked keys| ) TO rt.
      ENDIF.
    ENDLOOP.

*   === same field name on two steps ==========================================
*   The engine builds ONE model component per upper-cased field name across the
*   whole journey. Two steps using the same name share one value.
    LOOP AT mt_fields INTO DATA(d1).
      LOOP AT mt_fields INTO DATA(d2) WHERE field_name = d1-field_name
                                        AND step_id   <> d1-step_id.
        IF d1-step_id < d2-step_id.
          APPEND VALUE #( type = 'Error'
            text = |'{ d1-field_name }' exists on { d1-step_id } and { d2-step_id } — one model slot, they overwrite each other| ) TO rt.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

*   === names the engine creates for itself ===================================
    LOOP AT mt_fields INTO DATA(rn).
      DATA(lv_rn) = to_upper( rn-field_name ).
      IF lv_rn CP '*_VS' OR lv_rn CP '*_VST' OR lv_rn CP '*_EXP' OR lv_rn = 'DUMMY'.
        APPEND VALUE #( type = 'Error'
          text = |{ rn-step_id }/{ lv_rn }: the engine generates <FIELD>_VS, <FIELD>_VST, <FIELD>_EXP and DUMMY itself — rename this field| ) TO rt.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_fields INTO DATA(sr) WHERE ftype = 'SEARCH'.
      LOOP AT VALUE string_table( ( `_NAME` ) ( `_IDTYPE` ) ) INTO DATA(lv_sfx).
        IF field_exists( |{ sr-field_name }{ lv_sfx }| ) = abap_true.
          APPEND VALUE #( type = 'Error'
            text = |{ sr-field_name }{ lv_sfx } collides with the slot SEARCH field { sr-field_name } creates automatically| ) TO rt.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

*   === curly braces in authored text =========================================
*   UI5 parses { } in an XML view attribute as a binding path. One brace in a
*   label takes the whole screen down at render time, for that citizen only.
    LOOP AT mt_fields INTO DATA(bc).
      IF bc-label CA '{}' OR bc-label_ar CA '{}' OR bc-placeholder CA '{}'
         OR bc-place_ar CA '{}' OR bc-msg CA '{}' OR bc-msg_ar CA '{}'
         OR bc-section CA '{}' OR bc-fgroup CA '{}'.
        APPEND VALUE #( type = 'Error'
          text = |{ bc-step_id }/{ bc-field_name }: text contains a curly brace — UI5 reads it as a binding path and the screen fails to render| ) TO rt.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_steps INTO DATA(bs).
      IF bs-title CA '{}' OR bs-title_ar CA '{}'.
        APPEND VALUE #( type = 'Error'
          text = |Step { bs-step_id }: title contains a curly brace — breaks the wizard stepper HTML| ) TO rt.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_opts INTO DATA(bo).
      IF bo-opt_text CA '{}' OR bo-opt_text_ar CA '{}'.
        APPEND VALUE #( type = 'Error'
          text = |Option { bo-field_name }/{ bo-opt_key }: text contains a curly brace| ) TO rt.
      ENDIF.
    ENDLOOP.

*   === EDITABLE_TABLE needs a column spec and a tech_name ====================
*   A column spec now comes from either place GRID_COLS( ) itself reads:
*   the packed Default value, or one or more ZRAK_T_JNY_COL rows. Checking
*   only Default value would flag every grid already migrated to the
*   Columns panel as an error it does not have.
    LOOP AT mt_fields INTO DATA(et) WHERE ftype = 'EDITABLE_TABLE'.
      IF et-default_val IS INITIAL
         AND NOT line_exists( mt_cols[ step_id = et-step_id field_name = et-field_name ] ).
        APPEND VALUE #( type = 'Error'
          text = |{ et-step_id }/{ et-field_name }: no column spec — renders a warning strip, not a grid. Set Default value to pipe-separated name:label:type entries, or add rows in the Columns panel| ) TO rt.
      ENDIF.
      IF et-tech_name IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = |{ et-step_id }/{ et-field_name }: no tech_name — the grid JSON is silently dropped and never posted| ) TO rt.
      ENDIF.
    ENDLOOP.

*   === SEARCH with no ID types ===============================================
    LOOP AT mt_fields INTO DATA(se) WHERE ftype = 'SEARCH'.
      READ TABLE mt_opts TRANSPORTING NO FIELDS
           WITH KEY step_id = se-step_id field_name = se-field_name.
      IF sy-subrc <> 0.
        APPEND VALUE #( type = 'Warning'
          text = |{ se-step_id }/{ se-field_name }: SEARCH has no options — the ID-type dropdown renders empty and the lookup falls back to YFS002| ) TO rt.
      ENDIF.
    ENDLOOP.

*   === authored, stored, but not read by the engine ==========================
    LOOP AT mt_fields INTO DATA(nh).
      IF nh-width IS NOT INITIAL.
        APPEND VALUE #( type = 'Warning'
          text = |{ nh-step_id }/{ nh-field_name }: Width is saved but the engine sizes controls by type — it has no effect| ) TO rt.
      ENDIF.
      IF to_int( nh-att_maxmb ) > 0
         AND nh-has_attach = abap_false AND to_upper( nh-ftype ) <> 'UPLOAD'.
        APPEND VALUE #( type = 'Warning'
          text = |{ nh-step_id }/{ nh-field_name }: Attach max MB is set but this field has no attachment| ) TO rt.
      ENDIF.
      IF ( nh-min_val IS NOT INITIAL OR nh-max_val IS NOT INITIAL )
         AND to_upper( nh-ftype ) <> 'SLIDER'   AND to_upper( nh-ftype ) <> 'STEPPER'
         AND to_upper( nh-ftype ) <> 'RATING'   AND to_upper( nh-ftype ) <> 'NUMBER'
         AND to_upper( nh-ftype ) <> 'CURRENCY' AND to_upper( nh-ftype ) <> 'DATE'.
        APPEND VALUE #( type = 'Warning'
          text = |{ nh-step_id }/{ nh-field_name }: min/max value has no effect on { nh-ftype } — enforced on submit for NUMBER/CURRENCY/DATE, a control bound on SLIDER/STEPPER/RATING| ) TO rt.
      ENDIF.
    ENDLOOP.

*   === attachment size ========================================================
*   There is a real ceiling and it is not the disk. An upload travels as base64
*   inside the page state, so it inflates by a third and rides every round trip.
*   Large files do not fail cleanly - the session gets slow and then falls over.
    LOOP AT mt_fields INTO DATA(ls_amb)
         WHERE has_attach = 'X' OR ftype = 'UPLOAD'.
      DATA(lv_amb) = to_int( ls_amb-att_maxmb ).
      IF lv_amb > 10.
*       Now an Error, not a Warning: the engine caps at 10 and the author's
*       number is simply not honoured, so leaving it in place is a lie in the
*       configuration rather than a risky setting.
        APPEND VALUE #( type = 'Error'
          text = |{ ls_amb-step_id }/{ ls_amb-field_name }: { lv_amb } MB is above the framework limit of 10 MB and will be capped to 10. Set 10 or less so the configuration says what actually happens.| ) TO rt.
      ENDIF.
*     No line when the size is unset. Every uploader on every journey would
*     carry one, and "the default applies" is not a finding - it is the normal
*     case. Lint is for things that are wrong.
    ENDLOOP.

*   === reserved name suffixes =================================================
*   backend_read( ) skips any value the backend returns for a name the framework
*   owns, so a field named like one of these renders and posts but is never filled
*   from the backend - and nothing says why.
    LOOP AT mt_fields INTO DATA(ls_rsv).
      DATA(lv_rsvn) = to_upper( ls_rsv-field_name ).
      IF lv_rsvn CP '*_SEL'.
        APPEND VALUE #( type = 'Error'
          text = |{ ls_rsv-step_id }/{ ls_rsv-field_name }: names ending _SEL are reserved for the row flag inside a grid. A backend value for this field is discarded. Rename it, e.g. { ls_rsv-field_name }ECT or _PICK.| ) TO rt.
      ENDIF.
      IF lv_rsvn CP '*_IX'.
        APPEND VALUE #( type = 'Error'
          text = |{ ls_rsv-step_id }/{ ls_rsv-field_name }: names ending _IX are reserved for a RADIO's selected index. A backend value for this field is discarded. Rename it.| ) TO rt.
      ENDIF.
*     _EXP is NOT checked here. The rule above already reports it as an Error and
*     names _VS, _VST and DUMMY with it, so a second Warning on the same field was
*     pure noise - ZTEST_LINT showed PANEL_EXP twice.
    ENDLOOP.

*   === SEL: on a control that cannot use it ==================================
*   Silently ignored, and on a TABLE it is worse than ignored: DEFAULT_VAL there
*   means the pick-target field, so a SEL: directive destroys the selection the
*   author was trying to configure.
    LOOP AT mt_fields INTO DATA(ls_sw)
         WHERE default_val CS 'SEL:' AND ftype <> 'EDITABLE_TABLE'.
      APPEND VALUE #( type = 'Error'
        text = |{ ls_sw-step_id }/{ ls_sw-field_name }: SEL: only works on EDITABLE_TABLE. On { ls_sw-ftype } this is ignored{ COND string( WHEN ls_sw-ftype = 'TABLE' THEN ' and it overwrites the pick-target that DEFAULT_VAL carries for a TABLE' ) }.| )
TO rt.
    ENDLOOP.

*   === grid row selection (SEL: directive) ====================================
*   All silent: a malformed directive just means no selection column appears.
    LOOP AT mt_fields INTO DATA(ls_sfl).
      IF to_upper( ls_sfl-ftype ) <> 'EDITABLE_TABLE' OR ls_sfl-default_val IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT ls_sfl-default_val AT '|' INTO TABLE DATA(lt_sc).
      DATA lv_seln TYPE i.
      CLEAR lv_seln.
      LOOP AT lt_sc INTO DATA(lv_sc).
        SPLIT condense( lv_sc ) AT ':' INTO DATA(lv_s1) DATA(lv_s2) DATA(lv_s3).
        IF to_upper( condense( lv_s1 ) ) <> 'SEL'.
          CONTINUE.
        ENDIF.
        lv_seln = lv_seln + 1.
        DATA(lv_smode) = to_upper( condense( lv_s2 ) ).
        DATA(lv_stgt)  = to_upper( condense( lv_s3 ) ).

        IF lv_smode <> 'SINGLE' AND lv_smode <> 'MULTI'.
          APPEND VALUE #( type = 'Error'
            text = |{ ls_sfl-step_id }/{ ls_sfl-field_name }: SEL mode '{ lv_s2 }' is not SINGLE or MULTI, so no selection column is drawn.| ) TO rt.
        ENDIF.
        IF lv_stgt IS INITIAL.
          APPEND VALUE #( type = 'Error'
            text = |{ ls_sfl-step_id }/{ ls_sfl-field_name }: SEL has no target field, so the picked key has nowhere to go. Use SEL:{ lv_smode }:FIELDNAME.| ) TO rt.
        ELSE.
          READ TABLE mt_fields INTO DATA(ls_stg) WITH KEY field_name = lv_stgt.
          IF sy-subrc <> 0.
            APPEND VALUE #( type = 'Error'
              text = |{ ls_sfl-step_id }/{ ls_sfl-field_name }: SEL target { lv_stgt } is not a field in this journey.| ) TO rt.
          ELSEIF ls_stg-readonly IS INITIAL AND ls_stg-hidden IS INITIAL
                 AND to_upper( ls_stg-ftype ) <> 'READONLY'
                 AND to_upper( ls_stg-ftype ) <> 'DISPLAY'.
            APPEND VALUE #( type = 'Warning'
              text = |{ ls_sfl-step_id }/{ ls_sfl-field_name }: SEL target { lv_stgt } is editable. The engine overwrites it on every pick, so make it READONLY or HIDDEN.| ) TO rt.
          ENDIF.
        ENDIF.
      ENDLOOP.
      IF lv_seln > 1.
        APPEND VALUE #( type = 'Error'
          text = |{ ls_sfl-step_id }/{ ls_sfl-field_name }: { lv_seln } SEL directives in one spec. Only the first is read.| ) TO rt.
      ENDIF.
    ENDLOOP.

*   === backend wiring ========================================================
*   All silent today. A journey with BKND_ACTIVE set and any of these missing
*   calls the FM, instantiates the BAdI, and then does nothing useful - because
*   the BAdI selects its field mapping on the journey code and dispatches on the
*   screen name. Nothing is raised, so it looks like the BAdI was never called.
    IF mv_bknd_act = abap_true.
      IF mv_bknd_jny IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = 'Backend is active but BE journey code is empty. The BAdI reads its field mapping with this code, so nothing will map.' ) TO rt.
      ENDIF.
      IF mv_bknd_cat IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = 'Backend is active but BE category is empty. Every post and read carries it in the header.' ) TO rt.
      ENDIF.
      LOOP AT mt_steps INTO DATA(ls_bes) WHERE bknd_screen IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = |{ ls_bes-step_id }: backend is active but the step has no BE screen. Its post and read cannot be dispatched, and the first step also blocks the draft being created.| ) TO rt.
      ENDLOOP.
    ENDIF.

*   === table fields against the legacy screen definition =====================
*   The one that cost a week. A table's rows are fetched by a SEPARATE backend
*   call, and that call needs the table's name - which the framework looks up in
*   /QNV/SB_UI_DEFIN by SCREEN_NAME + CATEGORY + FIELD_NAME. So a table field
*   whose name does not exist in the legacy screen has nothing to resolve
*   against, and no amount of correct CJS configuration will produce rows.
*
*   Scalars are NOT affected and are deliberately not checked: their values ride
*   the main read on definition rows the bridge supplies itself, so they need no
*   legacy row at all. Only tables are looked up by name.
*
*   One SELECT for the whole journey rather than one per field - a lint pass
*   should not cost a round trip per grid.
    IF mv_bknd_act = abap_true AND mv_bknd_cat IS NOT INITIAL.
      DATA lt_qvscr TYPE RANGE OF /qnv/sb_ui_defin-screen_name.
      CLEAR lt_qvscr.
      LOOP AT mt_steps INTO DATA(ls_qvs) WHERE bknd_screen IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_qvs-bknd_screen ) TO lt_qvscr.
      ENDLOOP.

      IF lt_qvscr IS NOT INITIAL.
        DATA lv_qvcat TYPE /qnv/sb_ui_defin-category.
        lv_qvcat = mv_bknd_cat.
        SELECT screen_name, field_name, data2
          FROM /qnv/sb_ui_defin
          INTO TABLE @DATA(lt_qvrow)
          WHERE screen_name IN @lt_qvscr
            AND category    = @lv_qvcat.

        LOOP AT mt_fields INTO DATA(ls_qvf)
             WHERE ftype = 'EDITABLE_TABLE' OR ftype = 'TABLE'
                OR ftype = 'RECORDCARD'     OR ftype = 'RO_PANEL'.

          READ TABLE mt_steps INTO DATA(ls_qvst) WITH KEY step_id = ls_qvf-step_id.
          IF sy-subrc <> 0 OR ls_qvst-bknd_screen IS INITIAL.
            CONTINUE.
          ENDIF.

          DATA lv_qvscn TYPE /qnv/sb_ui_defin-screen_name.
          DATA lv_qvfld TYPE /qnv/sb_ui_defin-field_name.
          lv_qvscn = ls_qvst-bknd_screen.
          lv_qvfld = to_upper( ls_qvf-field_name ).

          READ TABLE lt_qvrow INTO DATA(ls_qvhit)
            WITH KEY screen_name = lv_qvscn field_name = lv_qvfld.
          IF sy-subrc <> 0.
            APPEND VALUE #( type = 'Error'
              text = |{ ls_qvf-step_id }/{ ls_qvf-field_name }: no control of that name on screen { lv_qvscn } in the legacy definition, so its rows can never be fetched. Rename the field to match a control that already exists there.| ) TO rt.
          ELSEIF ls_qvhit-data2 IS INITIAL.
            APPEND VALUE #( type = 'Warning'
              text = |{ ls_qvf-step_id }/{ ls_qvf-field_name }: the control exists on { lv_qvscn } but DATA2 is blank, so the backend has no name for the table. The framework will try the field name; if that returns nothing, DATA2 has to be filled.| )
TO rt.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDIF.

*   === side-by-side rows =====================================================
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
*   The engine joins a field to the row above only while the two are ADJACENT
*   and in the same section, so every one of these is a silent no-op rather
*   than an error: the fields render stacked and nobody is told why.
    LOOP AT mt_fields INTO DATA(rw).
      DATA(lv_lt) = row_tok( rw-fgroup ).
      IF lv_lt IS INITIAL.
        CONTINUE.
      ENDIF.

      IF pairable( rw-ftype ) = abap_false.
        APPEND VALUE #( type = 'Warning'
          text = |{ rw-step_id }/{ rw-field_name }: { rw-ftype } is on row { substring( val = lv_lt off = 4 ) } but cannot share one — it renders full width (a block ends the row outright)| ) TO rt.
      ENDIF.

      IF rw-hidden = abap_true.
        APPEND VALUE #( type = 'Warning'
          text = |{ rw-step_id }/{ rw-field_name }: hidden AND on row { substring( val = lv_lt off = 4 ) } — the engine consumes it without drawing it, so its partner ends up alone in the row| ) TO rt.
      ENDIF.

      DATA lv_cnt2 TYPE i.
      DATA lv_lo   TYPE i.
      DATA lv_hi   TYPE i.
      DATA lv_sect TYPE string.
      CLEAR: lv_cnt2, lv_lo, lv_hi, lv_sect.
      LOOP AT mt_fields INTO DATA(rm) WHERE step_id = rw-step_id.
        IF row_tok( rm-fgroup ) <> lv_lt.
          CONTINUE.
        ENDIF.
        DATA(sq) = to_int( rm-seqnr ).
        IF lv_cnt2 = 0 OR sq < lv_lo.
          lv_lo = sq.
        ENDIF.
        IF sq > lv_hi.
          lv_hi = sq.
        ENDIF.
        IF lv_cnt2 = 0.
          lv_sect = rm-section.
        ELSEIF rm-section <> lv_sect.
          lv_sect = '?'.
        ENDIF.
        lv_cnt2 = lv_cnt2 + 1.
      ENDLOOP.

*     Row-level findings are reported once, on whichever member is met first.
*     Keyed on step + token, not on the raw FGROUP string, so a hand-typed
*     'row:r001' still counts as the same row as 'ROW:R001'.
      IF line_exists( lt_seen[ table_line = |{ rw-step_id }/{ lv_lt }| ] ).
        CONTINUE.
      ENDIF.
      INSERT |{ rw-step_id }/{ lv_lt }| INTO TABLE lt_seen.

      IF lv_cnt2 < 2.
        APPEND VALUE #( type = 'Warning'
          text = |{ rw-step_id }: row { substring( val = lv_lt off = 4 ) } has one field ({ rw-field_name }) — a one-cell row renders exactly like no row. Pair it or clear the Group.| ) TO rt.
      ENDIF.

      IF lv_cnt2 > 4.
        APPEND VALUE #( type = 'Warning'
          text = |{ rw-step_id }: row { substring( val = lv_lt off = 4 ) } holds { lv_cnt2 } fields — cells are 14rem minimum, so beyond four they wrap and the row buys nothing| ) TO rt.
      ENDIF.

      IF lv_sect = '?'.
        APPEND VALUE #( type = 'Error'
          text = |{ rw-step_id }: row { substring( val = lv_lt off = 4 ) } spans two sections — each section opens its own card, so the engine ends the row at the boundary and the token is ignored| ) TO rt.
      ENDIF.

*     A gap means some other field sits between the members by seq. The engine
*     scans forward from the first member and stops at the first field whose
*     token does not match, so everything after the gap renders stacked.
      IF lv_cnt2 >= 2.
        DATA lv_between TYPE i.
        CLEAR lv_between.
        LOOP AT mt_fields INTO DATA(rb) WHERE step_id = rw-step_id.
          DATA(sb) = to_int( rb-seqnr ).
          IF sb > lv_lo AND sb < lv_hi AND row_tok( rb-fgroup ) <> lv_lt.
            lv_between = lv_between + 1.
          ENDIF.
        ENDLOOP.
        IF lv_between > 0.
          APPEND VALUE #( type = 'Error'
            text = |{ rw-step_id }: row { substring( val = lv_lt off = 4 ) } is split by { lv_between } field(s) in between (seq { lv_lo }..{ lv_hi }) — the row must be consecutive by seq or the engine breaks it| ) TO rt.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lint_all.
*   Runs the existing lint( ) against every journey in turn. The rules themselves
*   needed no change - they read whatever is currently loaded - so this is a loop
*   that loads, lints, collects, and puts back what the author was working on.
    CLEAR: mt_audit, mv_audit_ok.

*   Take the whole draft, not just mv_sel. The loop below reloads every journey
*   in the system from the database, so restoring by re-loading - which is what
*   this did - silently threw away every unsaved edit the author had made. An
*   audit is a read; it must not be able to lose work.
    DATA(ls_keep) = snapshot( ).
    DATA(lv_kmsg) = mv_msg.
    DATA(lv_kmty) = mv_mtype.

    SELECT journey_id, title, active FROM zrak_t_jny
      ORDER BY journey_id INTO TABLE @DATA(lt_j).

    LOOP AT lt_j INTO DATA(ls_j).
      mv_sel = ls_j-journey_id.
      load_journey( iv_quiet = abap_true ).
      LOOP AT lint( ) INTO DATA(ls_f).
        APPEND VALUE #( journey = ls_j-journey_id
                        title   = ls_j-title
                        active  = xsdbool( ls_j-active = 'X' )
                        type    = ls_f-type
                        text    = ls_f-text ) TO mt_audit.
      ENDLOOP.
    ENDLOOP.

    restore( ls_keep ).
    mv_msg   = lv_kmsg.
    mv_mtype = lv_kmty.

    mv_audit_ok = abap_true.
  ENDMETHOD.


  METHOD lint_refresh.
    CLEAR: mt_lint, mt_lint_row.
    mt_lint = lint( ).

    LOOP AT mt_lint INTO DATA(ls_l).
*     Field-level rules are written "STEP/FIELD: message" and are indexed off
*     that prefix - reading it back still beats editing fifty APPEND sites. The
*     step/field pair is verified against the journey, so a message that merely
*     happens to contain a slash is not mistaken for a field finding.
      SPLIT ls_l-text AT ':' INTO DATA(lv_head) DATA(lv_rest).
      IF lv_rest IS NOT INITIAL AND lv_head CS '/'.
        SPLIT lv_head AT '/' INTO DATA(lv_step) DATA(lv_field).
        DATA(lv_s) = to_upper( condense( lv_step ) ).
        DATA(lv_f) = to_upper( condense( lv_field ) ).
        IF lv_s IS NOT INITIAL AND lv_f IS NOT INITIAL.
          READ TABLE mt_fields TRANSPORTING NO FIELDS
               WITH KEY step_id = lv_s field_name = lv_f.
          IF sy-subrc = 0.
            APPEND VALUE #( step  = lv_s
                            field = lv_f
                            type  = ls_l-type
                            text  = condense( lv_rest ) ) TO mt_lint_row.
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.

*     Everything else falls through to here, and this is the part that was
*     missing. Roughly a third of the rules do not write the prefix - duplicate
*     tech_name, the same field name on two steps, a SEARCH slot collision, the
*     PAYFEE checks - and every one of them is a FIELD fault that was reaching
*     the Audit panel and nothing else. Matching the field name as a whole word
*     puts them on the row where somebody will see them. Underscore counts as a
*     word character, so OWNER does not match OWNER_NAME.
      LOOP AT mt_fields INTO DATA(ls_fx).
        DATA(lv_fn) = to_upper( ls_fx-field_name ).
*       Anything outside the DDIC character set is skipped rather than escaped:
*       a hand-typed name with a regex metacharacter in it would otherwise raise
*       CX_SY_INVALID_REGEX and take the Studio down over a lint marker.
        IF lv_fn IS INITIAL OR lv_fn CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
          CONTINUE.
        ENDIF.
*       Case-sensitive, against the original text. Field names are stored upper
*       case and the rules interpolate them as-is, while the prose around them is
*       lower case - so an upper-case match finds the reference and not the word.
*       Matching a folded copy would pin every finding containing "name" or
*       "code" onto a field called NAME or CODE, and a marker that cries wolf is
*       worse than no marker.
        FIND REGEX |\\b{ lv_fn }\\b| IN ls_l-text.
        IF sy-subrc = 0.
          APPEND VALUE #( step  = to_upper( ls_fx-step_id )
                          field = lv_fn
                          type  = ls_l-type
                          text  = ls_l-text ) TO mt_lint_row.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    mv_lint_ok = abap_true.
  ENDMETHOD.


  METHOD xcheck_refresh.
*   CJS and ShapeIt fail SILENTLY when they disagree - a step pointing at a
*   screen with no /QNV rows renders, validates and posts, the BAdI reads an
*   empty LT_DEFIN and does nothing, and there is no error anywhere. That is
*   what ZCL_RAK_CJS_XCHECK exists to catch, and until now it was reachable
*   only from ZRAK_CJS_XCHECK, a report nobody remembers to run.
    CLEAR mt_xchk.

*   Nothing saved, nothing to cross-check. A new journey has no ZRAK_T_JNY row
*   yet, and XCHECK would open with "journey does not exist" - true, useless,
*   and alarming on the screen where the author is still typing the id.
    IF mv_journey_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_jid TYPE zrak_t_jny-journey_id.
    DATA lt_x   TYPE zcl_rak_cjs_xcheck=>tt_msg.

    lv_jid = to_upper( mv_journey_id ).

*   Wrapped because this reaches OUTSIDE the CJS tables: /QNV/SB_UI_DEFIN and
*   ZEGA_T_CJ_2_OBJ belong to the legacy stack, and on a system where they are
*   absent or restricted the SELECT raises. A cross-check is a convenience; it
*   must never be the reason the Studio will not open.
    TRY.
        lt_x = zcl_rak_cjs_xcheck=>check( iv_journey = lv_jid ).
      CATCH cx_root INTO DATA(lx).
        mt_xchk = VALUE #( ( type = 'Information'
          text = |Cross-check could not run: { lx->get_text( ) }| ) ).
        RETURN.
    ENDTRY.

    LOOP AT lt_x INTO DATA(ls_x).
      APPEND VALUE #(
        type = SWITCH string( ls_x-sev
                              WHEN 'E' THEN 'Error'
                              WHEN 'W' THEN 'Warning'
                              ELSE 'Information' )
*       The rule id travels with the text. XCHECK names its rules X01..X12 and
*       those ids are what its own documentation is written against, so a
*       finding pasted into a ticket stays traceable to the rule that raised it.
        text = |[{ ls_x-rule }]| &&
               COND string( WHEN ls_x-step IS NOT INITIAL THEN | { ls_x-step }| ) &&
               | { ls_x-text }| ) TO mt_xchk.
    ENDLOOP.
  ENDMETHOD.


  METHOD next_fseq.
    DATA lv_max TYPE i.
    LOOP AT mt_fields INTO DATA(f) WHERE step_id = to_upper( iv_step ).
      DATA(n) = to_int( f-seqnr ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD next_oseq.
    DATA lv_max TYPE i.
    LOOP AT mt_opts INTO DATA(o) WHERE step_id = to_upper( iv_step ) AND field_name = to_upper( iv_field ).
      DATA(n) = to_int( o-seqnr ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD next_cseq.
    DATA lv_max TYPE i.
    LOOP AT mt_cols INTO DATA(c) WHERE step_id = to_upper( iv_step ) AND field_name = to_upper( iv_field ).
      DATA(n) = to_int( c-seqnr ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD next_rowtok.
*   Tokens only have to be unique inside a step, and only so that two rows that
*   happen to end up adjacent are not read as one four-cell row. Scan for the
*   highest Rnnn in use rather than counting rows, so re-pairing after an
*   unpair cannot reuse a token still held by a neighbour.
    DATA lv_max TYPE i.
    LOOP AT mt_fields INTO DATA(f) WHERE step_id = to_upper( iv_step ).
      DATA(t) = row_tok( f-fgroup ).
      IF t IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(n) = to_int( substring( val = t off = 5 ) ).
      IF n > lv_max.
        lv_max = n.
      ENDIF.
    ENDLOOP.
*   No WIDTH/PAD - it left-aligns and pads on the right for a numeric operand,
*   which made row 1 and row 10 both 'R100'.
    rv = |ROW:R{ lv_max + 1 }|.
  ENDMETHOD.


  METHOD next_ruleid.
    DATA lv_max TYPE i.
    LOOP AT mt_rules INTO DATA(r).
      DATA(lv_num) = r-rule_id.
      REPLACE ALL OCCURRENCES OF 'R' IN lv_num WITH ''.
      DATA(n) = to_int( lv_num ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |R{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD pairable.
*   Mirrors ZCL_RAK_MIGRATOR->PAIRABLE. Whitelist, so a type added to
*   type_list( ) later is stacked full width until somebody decides it shares
*   well. The blocks (TABLE / EDITABLE_TABLE / UPLOAD / SEARCH / PAYFEE /
*   RECORDCARD / REQPANEL) are excluded because the engine ENDS a row at any
*   block - pairing one is config that renders nothing.
    CASE to_upper( iv_type ).
      WHEN 'INPUT' OR 'READONLY' OR 'DATE' OR 'TIME' OR 'DATETIME'
        OR 'NUMBER' OR 'CURRENCY' OR 'PHONE' OR 'EMAIL'
        OR 'SELECT' OR 'MULTISELECT' OR 'STEPPER' OR 'CHECKBOX' OR 'SWITCH'.
        rv = abap_true.
      WHEN OTHERS.
        rv = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD preview_f4.
    CLEAR mv_f4_src.
    IF iv_rollname IS INITIAL AND iv_shlp IS INITIAL AND iv_domname IS INITIAL.
      RETURN.
    ENDIF.
*   Name the source in the result so the author can see WHICH of the three boxes
*   the engine will actually use. Three boxes where only one usually applies is
*   how a search help ends up in the data-element slot, resolving to nothing.
    mv_f4_src = COND #(
      WHEN iv_shlp     IS NOT INITIAL THEN |search help { to_upper( iv_shlp ) }|
      WHEN iv_rollname IS NOT INITIAL THEN |data element { to_upper( iv_rollname ) }|
      ELSE                                 |domain { to_upper( iv_domname ) }| ).
    TRY.
        rt = NEW zcl_rak_f4_resolver( )->resolve(
               iv_rollname = to_upper( iv_rollname )
               iv_shlp     = to_upper( iv_shlp )
               iv_domname  = to_upper( iv_domname ) ).
      CATCH cx_root.
*       Same posture as the engine: a value help that blows up leaves a plain
*       field rather than taking the page down. Here it leaves an empty preview,
*       which the caller reports.
        CLEAR rt.
    ENDTRY.
  ENDMETHOD.


  METHOD preview_grid.
    CLEAR: mt_grid_preview, mv_grid_sel, mv_grid_warn.
    IF iv_spec IS INITIAL.
      RETURN.
    ENDIF.

*   The engine's parser, not a copy of it. grid_cols( ) touches no engine state -
*   that was checked when the engine was split, and it is why an unbound engine
*   reference is safe here. If anyone ever makes it read mo_e, this dumps in the
*   Studio rather than going quietly wrong, which is the failure mode to prefer.
    DATA lo_engine TYPE REF TO zcl_rak_journey_engine.
    DATA(lo_grid)  = NEW zcl_rak_journey_grid( io_engine = lo_engine ).
    mt_grid_preview = lo_grid->grid_cols( VALUE #( default = iv_spec ) ).

*   SEL: is a directive, not a column, so grid_cols( ) drops it. Read it back out
*   separately - an author who cannot see it has no way to tell a spec with a tick
*   column from one without.
    SPLIT iv_spec AT '|' INTO TABLE DATA(lt_seg).
    LOOP AT lt_seg INTO DATA(lv_seg).
*     sy-tabix is captured before anything else runs. It was read several
*     statements later, after two SPLITs, which is a bet on nothing in between
*     touching it.
      DATA(lv_ix) = sy-tabix.
      DATA(lv_s)  = condense( lv_seg ).
      DATA(lv_u)  = to_upper( lv_s ).
*     Prefix, not CS. 'MYSEL:X' contains 'SEL:' and was being read as a
*     directive, which reported a tick column that the engine never draws.
      IF strlen( lv_u ) < 4 OR lv_u(4) <> 'SEL:'.
        CONTINUE.
      ENDIF.
      SPLIT lv_s AT ':' INTO DATA(lv_d) DATA(lv_mode) DATA(lv_tgt).
      DATA(lv_mm) = to_upper( condense( lv_mode ) ).
      DATA(lv_tg) = to_upper( condense( lv_tgt ) ).
      mv_grid_sel = |{ lv_mm } pick into { lv_tg }|.
*     Both faults can be present at once and both matter. The second used to
*     overwrite the first, so a spec that was misplaced AND had no target only
*     ever reported the target.
      IF lv_ix > 1.
        mv_grid_warn = mv_grid_warn &&
                       COND string( WHEN mv_grid_warn IS NOT INITIAL THEN ` ` ) &&
                       'SEL: is not first. DEFAULT_VAL truncates from the end, ' &&
                       'so the tick column is the one you lose. Move it to the front.'.
      ENDIF.
      IF lv_tg IS INITIAL.
        mv_grid_warn = mv_grid_warn &&
                       COND string( WHEN mv_grid_warn IS NOT INITIAL THEN ` ` ) &&
                       'SEL: has no target field, so a picked key has nowhere to go.'.
      ENDIF.
    ENDLOOP.

*   A final segment that carries no colon is what a truncated spec looks like:
*   the name survives, the label and type are cut off, and it still parses.
    DATA(lv_last) = condense( VALUE #( lt_seg[ lines( lt_seg ) ] OPTIONAL ) ).
    IF lv_last IS NOT INITIAL AND lv_last NS ':' AND lines( lt_seg ) > 1
       AND mv_grid_warn IS INITIAL.
      mv_grid_warn = |Last entry "{ lv_last }" has no colon. Either it is meant to | &&
                     |be a bare column name, or the spec was truncated - | &&
                     |DEFAULT_VAL cuts from the end and says nothing.|.
    ENDIF.
  ENDMETHOD.


  METHOD prev_field.
    DATA(st) = to_upper( iv_step ).
    DATA(fl) = to_upper( iv_field ).

    READ TABLE mt_fields INTO DATA(me_f) WITH KEY step_id = st field_name = fl.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_my) = to_int( me_f-seqnr ).

    DATA lv_best TYPE i.
    lv_best = -1.
    LOOP AT mt_fields INTO DATA(f) WHERE step_id = st.
      IF f-field_name = fl.
        CONTINUE.
      ENDIF.
      DATA(n) = to_int( f-seqnr ).
      IF n < lv_my AND n > lv_best.
        lv_best = n.
        rv      = f-field_name.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD render_audit.
    IF mv_audit_ok = abap_false.
      io->message_strip( text     = 'Press Audit all to check every journey in this system.'
                         type     = 'Information'
                         showicon = abap_true
                         class    = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.

*   Count first. The headline number is what somebody wants before a transport:
*   how many services are unsound, not how many findings exist in total.
    DATA lt_bad TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_err TYPE i.
    DATA lv_wrn TYPE i.
    LOOP AT mt_audit INTO DATA(a).
      IF a-type = 'Error'.
        lv_err = lv_err + 1.
        INSERT a-journey INTO TABLE lt_bad.
      ELSE.
        lv_wrn = lv_wrn + 1.
      ENDIF.
    ENDLOOP.

    SELECT COUNT(*) FROM zrak_t_jny INTO @DATA(lv_tot).

    DATA(hp) = io->panel( headertext = |Audit — { lv_tot } journeys checked|
                          expandable = abap_false
                          expanded   = abap_true
                          class      = 'sapUiSmallMarginBeginEnd' ).
    IF mt_audit IS INITIAL.
      hp->message_strip( text     = 'Every journey in this system passes. Nothing to fix.'
                         type     = 'Success'
                         showicon = abap_true
                         class    = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.
    hp->message_strip(
      text     = |{ lines( lt_bad ) } journey(s) with errors · { lv_err } error(s) · { lv_wrn } warning(s). | &&
                 |A journey with errors will not behave as configured - clear those before it goes to QA.|
      type     = COND string( WHEN lt_bad IS INITIAL THEN 'Warning' ELSE 'Error' )
      showicon = abap_true
      class    = 'sapUiSmallMargin' ).

*   Grouped by journey, worst first: a service with errors is a different
*   conversation from one with only warnings, and scrolling past forty warnings
*   to find the one broken journey is how a report gets ignored.
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_pass TYPE i.

    DO 2 TIMES.
      lv_pass = sy-index.
      CLEAR lt_seen.
      LOOP AT mt_audit INTO DATA(g).
        IF lv_pass = 1 AND NOT line_exists( lt_bad[ table_line = g-journey ] ).
          CONTINUE.
        ENDIF.
        IF lv_pass = 2 AND line_exists( lt_bad[ table_line = g-journey ] ).
          CONTINUE.
        ENDIF.
        IF line_exists( lt_seen[ table_line = g-journey ] ).
          CONTINUE.
        ENDIF.
        INSERT g-journey INTO TABLE lt_seen.

        DATA lv_je TYPE i.
        DATA lv_jw TYPE i.
        CLEAR: lv_je, lv_jw.
        LOOP AT mt_audit INTO DATA(c) WHERE journey = g-journey.
          IF c-type = 'Error'.
            lv_je = lv_je + 1.
          ELSE.
            lv_jw = lv_jw + 1.
          ENDIF.
        ENDLOOP.

        DATA(jp) = io->panel(
          headertext = |{ g-journey } — { g-title }| &&
                       COND string( WHEN g-active = abap_false THEN ` (inactive)` ) &&
                       |  ·  { lv_je } error(s), { lv_jw } warning(s)|
          expandable = abap_true
          expanded   = xsdbool( lv_je > 0 )
          class      = 'sapUiSmallMarginBeginEnd sapUiTinyMarginTop' ).

        LOOP AT mt_audit INTO DATA(m) WHERE journey = g-journey.
          jp->message_strip( text     = |{ m-journey } · { m-text }|
                             type     = m-type
                             showicon = abap_true
                             class    = 'sapUiSmallMarginBegin sapUiSmallMarginEnd sapUiTinyMarginTop' ).
        ENDLOOP.
      ENDLOOP.
    ENDDO.
  ENDMETHOD.


  METHOD render_design.

    DATA lv_last TYPE i.

    IF mv_journey_id IS INITIAL.
      io->message_strip( text = 'Load a journey first' type = 'Information' class = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.

    DATA(bar) = io->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    bar->label( text = 'Step:' class = 'sapUiTinyMarginEnd' ).
    DATA(cb) = bar->combobox( selectedkey = mo_client->_bind_edit( mv_dsg_step )
                              change      = mo_client->_event( 'DSG_STEP' )
                              width       = '16rem' ).
    LOOP AT mt_steps INTO DATA(ls_s).
      cb->item( key = ls_s-step_id text = |{ ls_s-step_id } — { ls_s-title }| ).
    ENDLOOP.

    DATA(lv_on) = zcl_rak_cj_lay=>get_instance( )->has_layout(
                    iv_journey = CONV #( to_upper( mv_journey_id ) )
                    iv_step    = CONV #( to_upper( mv_dsg_step ) ) ).

    bar->object_status( text  = COND string( WHEN lv_on = abap_true THEN 'layout active' ELSE 'classic rendering' )
                        state = COND string( WHEN lv_on = abap_true THEN 'Success' ELSE 'None' )
                        class = 'sapUiSmallMarginBegin' ).

    bar->button( text  = COND string( WHEN lv_on = abap_true THEN 'Re-seed' ELSE 'Take over layout' )
                 icon  = 'sap-icon://grid'
                 type  = COND string( WHEN lv_on = abap_true THEN 'Transparent' ELSE 'Emphasized' )
                 press = mo_client->_event( 'DSG_SEED' )
                 class = 'sapUiSmallMarginBegin' ).

    IF lv_on = abap_true.
      DATA(lv_arm_cl) = xsdbool( mv_arm_evt = 'DSG_CLR' ).
      bar->button( text    = COND string( WHEN lv_arm_cl = abap_true THEN 'Clear anyway' ELSE 'Clear' )
                   icon    = COND string( WHEN lv_arm_cl = abap_true THEN 'sap-icon://alert' ELSE 'sap-icon://reset' )
                   type    = COND string( WHEN lv_arm_cl = abap_true THEN 'Reject' )
                   tooltip = COND string( WHEN lv_arm_cl = abap_true
                                     THEN 'Click again to drop every row and width on this step'
                                     ELSE 'Drop the layout and render this step the classic way' )
                   press   = mo_client->_event( 'DSG_CLR' ) ).
    ENDIF.

    DATA(lt) = dsg_plan( mv_dsg_step ).
    IF lt IS INITIAL.
      io->message_strip( text = 'No visible fields on this step' type = 'Information' class = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.

    DATA(split) = io->hbox( alignitems = 'Stretch' class = 'sapUiSmallMargin' ).
    DATA(left)  = split->vbox( width = '42%' ).
    DATA(right) = split->vbox( width = '58%' ).

    DATA lv_sidx TYPE i.
    lv_sidx = -1.
    LOOP AT mt_steps INTO DATA(ls_ix).
      IF to_upper( ls_ix-step_id ) = to_upper( mv_dsg_step ).
        lv_sidx = sy-tabix - 1.
        EXIT.
      ENDIF.
    ENDLOOP.

    DATA(pl) = right->hbox( alignitems = 'Center' class = 'sapUiTinyMarginBottom' ).
    pl->label( text = 'Preview:' class = 'sapUiTinyMarginEnd' ).
    pl->button( text  = 'English'
                press = mo_client->_event( 'PL_EN' )
                type  = COND string( WHEN mv_prev_lang = 'AR' THEN 'Transparent' ELSE 'Emphasized' ) ).
    pl->button( text  = 'العربية'
                press = mo_client->_event( 'PL_AR' )
                type  = COND string( WHEN mv_prev_lang = 'AR' THEN 'Emphasized' ELSE 'Transparent' ) ).
    pl->button( text  = 'Desktop'
                icon  = 'sap-icon://sys-monitor'
                type  = COND string( WHEN mv_dsg_dev = 'PHONE' OR mv_dsg_dev = 'TABLET' THEN 'Transparent' ELSE 'Emphasized' )
                press = mo_client->_event( 'DSG_DEV~DESKTOP' )
                class = 'sapUiSmallMarginBegin' ).
    pl->button( text  = 'Tablet'
                icon  = 'sap-icon://ipad'
                type  = COND string( WHEN mv_dsg_dev = 'TABLET' THEN 'Emphasized' ELSE 'Transparent' )
                press = mo_client->_event( 'DSG_DEV~TABLET' ) ).
    pl->button( text  = 'Phone'
                icon  = 'sap-icon://iphone'
                type  = COND string( WHEN mv_dsg_dev = 'PHONE' THEN 'Emphasized' ELSE 'Transparent' )
                press = mo_client->_event( 'DSG_DEV~PHONE' ) ).

    pl->link( text   = 'Open in new tab ↗'
              target = '_blank'
              class  = 'sapUiSmallMarginBegin'
              href   = engine_url( iv_journey = to_upper( mv_journey_id )
                                   iv_ar      = xsdbool( mv_prev_lang = 'AR' )
                                   iv_step    = lv_sidx ) ).

    DATA(lv_fw) = SWITCH string( mv_dsg_dev
                                 WHEN 'PHONE'  THEN '390px'
                                 WHEN 'TABLET' THEN '768px'
                                 ELSE '100%' ).
    DATA(lv_fb) = COND string( WHEN mv_dsg_dev = 'PHONE' OR mv_dsg_dev = 'TABLET'
                               THEN `border:1px solid #c9c9c4;margin:0 auto;display:block;`
                               ELSE `border:0;` ).

    right->html(
      content = `<div style="width:100%;overflow-x:auto"><iframe src="` && engine_url( iv_journey = to_upper( mv_journey_id )
                                               iv_ar      = xsdbool( mv_prev_lang = 'AR' )
                                               iv_step    = lv_sidx )
             && `" style="width:` && lv_fw && `;height:620px;` && lv_fb
             && `border-radius:14px;box-shadow:0 10px 30px rgba(16,35,62,0.16)"></iframe></div>`
      sanitizecontent = abap_false ).

    IF mv_dsg_fld IS NOT INITIAL.
      DATA(tp) = left->panel( headertext = |Text — { mv_dsg_fld }|
                              class      = 'sapUiTinyMarginBottom' )->content( ).
      DATA(tf1) = tp->hbox( alignitems = 'Center' class = 'sapUiTinyMarginBottom' ).
      tf1->label( text = 'EN' width = '3rem' ).
      tf1->input( value = mo_client->_bind_edit( mv_dsg_en ) width = '20rem' ).
      DATA(tf2) = tp->hbox( alignitems = 'Center' class = 'sapUiTinyMarginBottom' ).
      tf2->label( text = 'AR' width = '3rem' ).
      tf2->input( value = mo_client->_bind_edit( mv_dsg_ar ) width = '20rem' ).
      DATA(tf3) = tp->hbox( ).
      tf3->button( text  = 'Apply'
                   type  = 'Emphasized'
                   press = mo_client->_event( 'DSG_TXOK' ) ).
      tf3->button( text  = 'Cancel'
                   press = mo_client->_event( 'DSG_TXCA' ) ).
    ENDIF.

*   Row totals up front, so each row header can say how much of the twelve
*   columns is spoken for and every arrow can be disabled when the move it offers
*   does not exist. A button that is enabled and does nothing was the most
*   confusing thing here: the author cannot tell "there is nowhere to go" from
*   "the editor is broken".
    DATA lv_maxrow TYPE i.
    LOOP AT lt INTO DATA(ls_mr).
      IF ls_mr-row > lv_maxrow.
        lv_maxrow = ls_mr-row.
      ENDIF.
    ENDLOOP.

    DATA(box) = left->vbox( ).

    box->message_strip(
      text     = 'Twelve columns to a row. Every change saves at once and the preview reloads. Clear puts the whole step back to classic rendering.'
      type     = 'Information'
      showicon = abap_true
      class    = 'sapUiTinyMarginBottom' ).

    LOOP AT lt INTO DATA(ls_d).

      IF ls_d-row <> lv_last.
        lv_last = ls_d-row.

        DATA lv_fill TYPE i.
        DATA lv_mem  TYPE i.
        CLEAR: lv_fill, lv_mem.
        LOOP AT lt INTO DATA(ls_rf) WHERE row = ls_d-row.
          lv_fill = lv_fill + ls_rf-span.
          lv_mem  = lv_mem + 1.
        ENDLOOP.

        DATA(hdr) = box->hbox( alignitems = 'Center' class = 'sapUiSmallMarginTop' ).
        hdr->title( text = |Row { ls_d-row }| class = 'sapUiTinyMarginEnd' ).
*       Success only at exactly twelve. Under twelve is not wrong, it just leaves
*       white space, so it reads as information rather than as a fault.
        hdr->object_status(
          text  = |{ lv_fill } of 12| &&
                  COND string( WHEN lv_fill < 12 THEN |, { 12 - lv_fill } free| ) &&
                  COND string( WHEN lv_fill > 12 THEN ` - over, the row wraps` )
          state = COND string( WHEN lv_fill > 12 THEN 'Warning'
                               WHEN lv_fill = 12 THEN 'Success'
                               ELSE 'Information' )
          class = 'sapUiTinyMarginEnd' ).
        hdr->object_status( text  = |{ lv_mem } field| && COND string( WHEN lv_mem <> 1 THEN `s` )
                            state = 'None' ).
      ENDIF.

*     How many fields share the row this one is on. That is what decides whether
*     earlier / later / down are available at all.
      DATA lv_rmem TYPE i.
      CLEAR lv_rmem.
      LOOP AT lt TRANSPORTING NO FIELDS WHERE row = ls_d-row.
        lv_rmem = lv_rmem + 1.
      ENDLOOP.

      DATA(lv_sel) = xsdbool( to_upper( mv_dsg_fld ) = to_upper( ls_d-field ) ).

      DATA(row) = box->hbox( alignitems = 'Center'
                             class      = COND string( WHEN lv_sel = abap_true
                                                       THEN 'sapUiTinyMarginBottom rakDsgSel'
                                                       ELSE 'sapUiTinyMarginBottom' ) ).

*     Twelve segments, the first SPAN of them filled. The number was already on
*     screen; what was missing was being able to put two fields side by side and
*     see at a glance that one is twice the width of the other.
      DATA lv_bar TYPE string.
      DATA lv_seg TYPE i.
      lv_bar = `<div class="rakDsgBar">`.
      lv_seg = 1.
      WHILE lv_seg <= 12.
        lv_bar = lv_bar && COND string( WHEN lv_seg <= ls_d-span
                                        THEN `<i class="on"></i>`
                                        ELSE `<i></i>` ).
        lv_seg = lv_seg + 1.
      ENDWHILE.
      lv_bar = lv_bar && `</div>`.
      REPLACE ALL OCCURRENCES OF `{` IN lv_bar WITH `\{`.
      REPLACE ALL OCCURRENCES OF `}` IN lv_bar WITH `\}`.
      row->html( content = lv_bar sanitizecontent = abap_false ).

*     WIDTH AND WRAPPING, BOTH REQUIRED.
*
*     This is an hbox, so the field name is a flex item with no width of its
*     own. Flex gives such an item min-content width, and a wrapping text
*     whose min-content is one character wide renders one character per
*     line - DIVORCEE_PARTNER comes out as a vertical stripe sixteen rows
*     tall, dragging the whole row down with it.
*
*     Turning wrapping off alone would stop the stripe but leave the name
*     column ragged, since each row would size to its own text. The fixed
*     width also lines the type and span badges up down the list, which is
*     what makes a long row of fields readable at a glance. A name longer
*     than the width gets an ellipsis, and the field is identified again in
*     the label editor behind the Tt button.
      row->text( text     = ls_d-field
                 width    = '15rem'
                 wrapping = 'false'
                 class    = 'sapUiSmallMarginBegin sapUiSmallMarginEnd' ).
      row->object_status( text = ls_d-ftype state = 'None' class = 'sapUiSmallMarginEnd' ).
      row->object_status( text  = |{ ls_d-span }/12|
                          state = COND string( WHEN ls_d-span = 12 THEN 'None' ELSE 'Information' )
                          class = 'sapUiSmallMarginEnd' ).

      row->button( icon    = 'sap-icon://text-formatting'
                   type    = COND string( WHEN lv_sel = abap_true THEN 'Emphasized' ELSE 'Transparent' )
                   tooltip = 'Edit English / Arabic label'
                   press   = mo_client->_event( |DSG_TX~{ ls_d-field }| )
                   class   = 'sapUiTinyMarginEnd' ).
      row->button( icon    = 'sap-icon://navigation-left-arrow'
                   type    = 'Transparent'
                   enabled = xsdbool( ls_d-col > 1 )
                   tooltip = COND string( WHEN ls_d-col > 1
                                          THEN 'Move earlier in this row'
                                          ELSE 'Already first in this row' )
                   press   = mo_client->_event( |DSG_ML~{ ls_d-field }| ) ).
      row->button( icon    = 'sap-icon://navigation-right-arrow'
                   type    = 'Transparent'
                   enabled = xsdbool( ls_d-col < lv_rmem )
                   tooltip = COND string( WHEN ls_d-col < lv_rmem
                                          THEN 'Move later in this row'
                                          ELSE 'Already last in this row' )
                   press   = mo_client->_event( |DSG_MR~{ ls_d-field }| ) ).
      row->button( icon    = 'sap-icon://navigation-up-arrow'
                   type    = 'Transparent'
                   enabled = xsdbool( ls_d-row > 1 )
                   tooltip = COND string( WHEN ls_d-row > 1
                                          THEN 'Move up a row'
                                          ELSE 'Already on the first row' )
                   press   = mo_client->_event( |DSG_RU~{ ls_d-field }| ) ).
*     Down is available while there is a row below, or while this row has company
*     - a field alone on the last row would only move to a new last row.
      row->button( icon    = 'sap-icon://navigation-down-arrow'
                   type    = 'Transparent'
                   enabled = xsdbool( ls_d-row < lv_maxrow OR lv_rmem > 1 )
                   tooltip = COND string( WHEN ls_d-row < lv_maxrow OR lv_rmem > 1
                                          THEN 'Move down a row'
                                          ELSE 'Already alone on the last row' )
                   press   = mo_client->_event( |DSG_RD~{ ls_d-field }| ) ).
      row->button( icon    = 'sap-icon://less'
                   type    = 'Transparent'
                   enabled = xsdbool( ls_d-span > 1 )
                   tooltip = COND string( WHEN ls_d-span > 1
                                          THEN 'Narrower'
                                          ELSE 'Already at the minimum of one column' )
                   press   = mo_client->_event( |DSG_SM~{ ls_d-field }| )
                   class   = 'sapUiTinyMarginBegin' ).
      row->button( icon    = 'sap-icon://add'
                   type    = 'Transparent'
                   enabled = xsdbool( ls_d-span < 12 )
                   tooltip = COND string( WHEN ls_d-span < 12
                                          THEN 'Wider'
                                          ELSE 'Already the full twelve columns' )
                   press   = mo_client->_event( |DSG_SP~{ ls_d-field }| ) ).

    ENDLOOP.

  ENDMETHOD.


  METHOD render_doc.
    DATA(p) = io->panel( headertext = 'Journey document (export / import)'
                         expandable = abap_true
                         expanded   = mv_pn_doc
                         expand     = mo_client->_event( 'PNL~DOC' )
                         class      = 'sapUiSmallMarginBeginEnd rakPnlDOC' ).
    p->message_strip(
      text     = 'One record per line, so two versions of a journey can be diffed and a change can be reviewed. ' &&
                 'Import replaces the draft in memory only — press Save afterwards, and it goes through the same checks as hand-authored config.'
      type     = 'Information'
      showicon = abap_true
      class    = 'sapUiSmallMargin' ).
    DATA(b) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    b->button( text  = 'Export to box'
               icon  = 'sap-icon://download'
               type  = 'Emphasized'
               press = mo_client->_event( 'DOCEXP' ) ).
    DATA(lv_arm_im) = xsdbool( mv_arm_evt = 'DOCIMP' ).
    b->button( text    = COND string( WHEN lv_arm_im = abap_true THEN 'Import anyway' ELSE 'Import from box' )
               icon    = COND string( WHEN lv_arm_im = abap_true THEN 'sap-icon://alert' ELSE 'sap-icon://upload' )
               type    = COND string( WHEN lv_arm_im = abap_true THEN 'Reject' )
               tooltip = COND string( WHEN lv_arm_im = abap_true
                                 THEN 'Click again to replace the loaded draft'
                                 ELSE 'Replaces the loaded draft. Nothing is written until Save.' )
               press   = mo_client->_event( 'DOCIMP' )
               class   = 'sapUiTinyMarginBegin' ).
    p->text_area( value = mo_client->_bind_edit( mv_doc )
                  rows  = '18'
                  width = '100%'
                  class = 'sapUiSmallMarginBeginEnd' ).
  ENDMETHOD.


  METHOD render_f4_scan.
    IF mv_f4_scanned = abap_false.
      RETURN.
    ENDIF.
    IF mt_f4_scan IS INITIAL.
      io->message_strip( text     = 'No field in this journey carries a data element, domain or search help.'
                         type     = 'Information'
                         showicon = abap_true
                         class    = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.
    DATA(t) = io->table( class = 'sapUiSmallMarginBeginEnd sapUiTinyMarginBottom' ).
    DATA(c) = t->columns( ).
    c->column( )->text( 'Step' ).   c->column( )->text( 'Field' ).
    c->column( )->text( 'Source the engine will use' ). c->column( )->text( 'Resolves to' ).
    DATA(it) = t->items( ).
    LOOP AT mt_f4_scan INTO DATA(s).
      it->column_list_item( )->cells(
        )->text( s-step )->text( s-field )->text( s-src
        )->object_status(
             text  = COND #( WHEN s-ok = abap_true THEN |{ s-cnt } option(s)|
                             ELSE 'NO options - renders an empty dropdown' )
             state = COND string( WHEN s-ok = abap_true THEN 'Success' ELSE 'Error' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_lint.
*   The cached pass, not a fresh one. This used to call lint( ) on every draw
*   while the ! column was only rebuilt on load and save, so the panel and the
*   markers could disagree for every edit made in between - and the panel was
*   the one telling the truth, which is the wrong way round for a marker that
*   sits on the row somebody is editing.
    DATA(lt) = mt_lint.
    DATA(p) = io->panel(
*     Was 'issue(s)' and rendered as 'issue(' - the closing bracket and the s
*     never survived to the screen. Not worth chasing which layer eats it when
*     a proper plural reads better anyway.
*     Name the journey. The findings say S2/OWNERS and nothing more, which is
*     fine while you are looking at the Studio but useless the moment somebody
*     pastes one into a ticket or an email - the reader has no idea which service
*     it came from. Putting it in the header means it travels with a copied block.
      headertext = COND #( WHEN lt IS INITIAL
                           THEN |Validation — { to_upper( mv_journey_id ) } — no issues|
                           ELSE |Validation — { to_upper( mv_journey_id ) } — { lines( lt ) } issue{ COND string( WHEN lines( lt ) = 1 THEN `` ELSE `s` ) }| )
      expandable = abap_true
      expanded   = xsdbool( lt IS NOT INITIAL )
      class      = 'sapUiSmallMarginBeginEnd' ).
    IF lt IS INITIAL.
      p->message_strip( text = 'No structural problems detected in the current draft.' type = 'Success' showicon = abap_true class = 'sapUiSmallMargin' ).
    ELSE.
*   The journey goes on every line, not only in the header. A finding reads
*   "L1/NO_OPTIONS: ..." - step and field - which is enough while you are looking
*   at the Studio and useless the moment one line is pasted into a ticket or a
*   chat, where the reader has no idea which service it came from.
*
*   Prefixed here rather than inside lint( ) so that the rules stay free of any
*   assumption about which journey they are checking - which is what will let the
*   same lint( ) run over every journey in one pass later.
    DATA(lv_jny) = to_upper( mv_journey_id ).
    LOOP AT lt INTO DATA(m).
      DATA(lo_row) = p->hbox( alignitems = 'Center'
                              class      = 'sapUiSmallMarginBegin sapUiSmallMarginEnd sapUiTinyMarginTop' ).
*     rakLintMsg only exists because sap.m.MessageStrip has no width property and
*     an HBox does not grow its children. Without it a long finding wrapped into a
*     narrow column with the button stranded beside it.
      lo_row->message_strip(
        text     = COND string( WHEN lv_jny IS INITIAL THEN m-text
                                ELSE |{ lv_jny } · { m-text }| )
        type     = m-type
        showicon = abap_true
        class    = 'rakLintMsg' ).

*     Reading a finding and then hunting for the field it names is the slow half
*     of fixing it, and the field list runs to sixty rows. Where the rule wrote
*     the "STEP/FIELD:" prefix - the same prefix LINT_REFRESH indexes on - the
*     finding can carry the button that loads that field into the editor. Rules
*     without the prefix simply get no button; the parse is verified against the
*     journey so a message that merely contains a slash does not grow one.
      SPLIT m-text AT ':' INTO DATA(lv_lh) DATA(lv_lr).
      IF lv_lr IS NOT INITIAL AND lv_lh CS '/'.
        SPLIT lv_lh AT '/' INTO DATA(lv_ls) DATA(lv_lf).
        DATA(lv_gs) = to_upper( condense( lv_ls ) ).
        DATA(lv_gf) = to_upper( condense( lv_lf ) ).
        IF lv_gs IS NOT INITIAL AND lv_gf IS NOT INITIAL.
          READ TABLE mt_fields TRANSPORTING NO FIELDS
               WITH KEY step_id = lv_gs field_name = lv_gf.
          IF sy-subrc = 0.
            lo_row->button( text    = 'Fix'
                            icon    = 'sap-icon://edit'
                            type    = 'Transparent'
                            tooltip = |Load { lv_gs }/{ lv_gf } into the field editor|
                            press   = mo_client->_event( |EDFLD_{ lv_gs }~{ lv_gf }| )
                            class   = 'sapUiTinyMarginBegin' ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.
    ENDIF.

*   ShapeIt cross-check, in a panel of its own. Deliberately NOT merged into the
*   Validation panel above: that one describes the DRAFT in front of the author,
*   this one describes the journey AS SAVED. Two different objects, and showing
*   them as one list would make a stale finding look current.
*
*   Collapsed unless something blocks, because the healthy answer is a single
*   "CJS and ShapeIt agree" line and an author does not need that unfolded.
    IF mt_xchk IS NOT INITIAL.
      DATA(lv_xbad) = REDUCE i( INIT k = 0 FOR x IN mt_xchk
                                WHERE ( type = 'Error' ) NEXT k = k + 1 ).
      DATA(px) = io->panel(
        headertext = |ShapeIt cross-check — { to_upper( mv_journey_id ) } — | &&
                     COND string( WHEN lv_xbad = 0
                                  THEN |{ lines( mt_xchk ) } note{ COND string( WHEN lines( mt_xchk ) = 1 THEN `` ELSE `s` ) }|
                                  ELSE |{ lv_xbad } blocker{ COND string( WHEN lv_xbad = 1 THEN `` ELSE `s` ) }| ) &&
*                    Say so when the draft has moved on. Without this the panel
*                    reads as a verdict on what is on screen, which it is not.
                     COND string( WHEN mv_dirty = abap_true THEN ` · as last saved, not the current draft` )
        expandable = abap_true
        expanded   = xsdbool( lv_xbad > 0 )
        class      = 'sapUiSmallMarginBeginEnd' ).
      LOOP AT mt_xchk INTO DATA(mx).
        px->message_strip(
          text     = mx-text
          type     = mx-type
          showicon = abap_true
          class    = 'sapUiSmallMarginBegin sapUiSmallMarginEnd sapUiTinyMarginTop' ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD render_migrate.
    io->html( content         = `<div class="rakHero"><h1>Migration Cockpit</h1><p>Pick a legacy journey, migrate it in one click &mdash; config, studio journey and portal tile. Delete to reset the demo and run it again.</p></div>`
              sanitizecontent = abap_false ).

    DATA(p1) = io->panel( headertext = 'Legacy journeys detected (/QNV/SB_UI_DEFIN)' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(t1) = p1->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(c1) = t1->columns( ).
    c1->column( )->text( 'Category' ). c1->column( )->text( 'Journey' ).
    c1->column( )->text( 'Screens' ).  c1->column( )->text( 'Config rows' ).
    c1->column( )->text( 'Status' ).   c1->column( )->text( '' ).
    DATA(i1) = t1->items( ).
    LOOP AT mt_cand INTO DATA(cd).
      DATA(cells1) = i1->column_list_item( )->cells( ).
      cells1->text( cd-category )->text( cd-journey )->text( |{ cd-screens }| )->text( |{ cd-rows }|
        )->text( COND #( WHEN cd-cjs_id IS NOT INITIAL THEN |Migrated → { cd-cjs_id }| ELSE 'Legacy' ) ).
      cells1->button( text    = 'Use'
                      icon    = 'sap-icon://journey-arrive'
                      type    = 'Transparent'
                      enabled = xsdbool( cd-cjs_id IS INITIAL )
                      press   = mo_client->_event( |MIGSEL_{ cd-category }~{ cd-journey }| ) ).
    ENDLOOP.

    DATA(p2) = io->panel( headertext = 'Migration settings' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(f) = p2->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).
    f->label( 'Category' ).           f->input( value = mo_client->_bind_edit( mg_cat ) ).
    f->label( 'Legacy journey' ).     f->input( value = mo_client->_bind_edit( mg_jny ) ).
    f->label( 'New CJS journey ID' ). f->input( value = mo_client->_bind_edit( mg_id )
    placeholder = |migrator prefixes { zcl_rak_migrator=>c_sandbox }| ).
    f->label( 'Tile title (EN)' ).    f->input( value = mo_client->_bind_edit( mg_title ) ).
    f->label( 'Tile title (AR)' ).    f->input( value = mo_client->_bind_edit( mg_title_ar ) ).
    f->label( 'Tile code' ).          f->input( value = mo_client->_bind_edit( mg_tile )
    placeholder = |migrator prefixes { zcl_rak_migrator=>c_sandbox }| ).
    f->label( 'Department' ).         f->input( value = mo_client->_bind_edit( mg_dept ) ).
    p2->hbox( class = 'sapUiSmallMargin'
      )->button( text = 'Migrate now' icon = 'sap-icon://process' type = 'Emphasized' press = mo_client->_event( 'MIGGO' ) ).

    DATA(p3) = io->panel( headertext = 'Migrated journeys (demo control)' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    SELECT journey_id, title, tile_code FROM zrak_t_jny WHERE tile_code <> @space ORDER BY journey_id INTO TABLE @DATA(lt_mig).
    DATA(t3) = p3->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(c3) = t3->columns( ).
    c3->column( )->text( 'Journey' ). c3->column( )->text( 'Title' ). c3->column( )->text( 'Tile' ). c3->column( )->text( '' ).
    DATA(i3) = t3->items( ).
    LOOP AT lt_mig INTO DATA(mg).
      DATA(cells3) = i3->column_list_item( )->cells( ).
      cells3->text( mg-journey_id )->text( mg-title )->text( mg-tile_code ).
      DATA(act3) = cells3->hbox( ).
      act3->button( icon = 'sap-icon://show' type = 'Transparent' tooltip = 'Preview' press = mo_client->_event( |PREVIEW_{ mg-journey_id }| ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_patterns.
    io->html( content = `<div class="rakSec">Start from a journey pattern</div>` sanitizecontent = abap_false ).
    DATA(tpls) = VALUE tt_tpl(
      ( id = 'DEMO_TRADE_LIC'   icon = 'sap-icon://org-chart'
        title = 'Multi-step wizard' sub = 'Applications with distinct stages and a final review' example = 'e.g. Trade License' )
      ( id = 'DEMO_ENV_PERMIT'  icon = 'sap-icon://tree'
        title = 'Accordion with rules' sub = 'Conditional sections that show/hide based on answers' example = 'e.g. Environmental Permit' )
      ( id = 'DEMO_GOLDEN_VISA' icon = 'sap-icon://search'
        title = 'Premium with BP lookup' sub = 'High-touch services that verify an existing partner' example = 'e.g. Golden Visa' )
      ( id = 'DEMO_FEEDBACK'    icon = 'sap-icon://feedback'
        title = 'Single page' sub = 'Short forms completed in one screen' example = 'e.g. Service Feedback' )
    ( id = 'ZDEMO_SHOWCASE' icon = 'sap-icon://sample'
title = 'Showcase — all controls' sub = 'Every field type and capability, for reference' example = 'developer reference journey' ) ).
    LOOP AT tpls INTO DATA(t).
      DATA(card) = io->vbox( class = 'rakCard sapUiSmallMarginBeginEnd sapUiSmallMarginBottom' ).
      DATA(hd) = card->hbox( alignitems = 'Center' ).
      hd->icon( src = t-icon class = 'sapUiTinyMarginEnd' ).
      hd->text( text = t-title class = 'rakCardT' ).
      card->text( text = t-sub class = 'rakCardD' ).
      DATA(lv_chips) = tpl_chips( t-id ).
      IF lv_chips IS NOT INITIAL.
        card->html( content = `<div class="rakChips">` && lv_chips && `</div>` sanitizecontent = abap_false ).
      ENDIF.
      card->html( content = `<div class="rakCardX">` && t-example && `</div>` sanitizecontent = abap_false ).
      DATA(bt) = card->hbox( class = 'sapUiTinyMarginTop' ).
      bt->button( text  = 'Use this pattern'
                  icon  = 'sap-icon://duplicate'
                  type  = 'Emphasized'
                  press = mo_client->_event( |USETPL_{ t-id }| ) ).
      bt->button( icon    = 'sap-icon://show'
                  type    = 'Transparent'
                  tooltip = 'Preview live'
                  press   = mo_client->_event( |PREVIEW_{ t-id }| )
                  class   = 'sapUiTinyMarginBegin' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_style.
    io->html( content = `<div class="rakSec">Style &amp; branding</div>` sanitizecontent = abap_false ).
    IF mv_journey_id IS INITIAL.
      io->message_strip( text     = 'Pick a pattern on the right to start a new journey, or Load one from the toolbar — then restyle it here. Fields, steps and rules are edited in Author.'
                         type     = 'Information'
                         showicon = abap_true
                         class    = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.
    DATA(p) = io->panel( headertext = |Styling { to_upper( mv_journey_id ) }| expandable = abap_false expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(f) = p->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '1' columnsl = '1' columnsm = '1' )->content( ns = 'form' ).
    f->label( 'Title (EN)' ).    f->input( value = mo_client->_bind_edit( mv_title ) ).
    f->label( 'Title (AR)' ).    f->input( value = mo_client->_bind_edit( mv_title_ar ) placeholder = 'العنوان' ).
    f->label( 'Subtitle (EN)' ). f->input( value = mo_client->_bind_edit( mv_subtitle ) ).
    f->label( 'Subtitle (AR)' ). f->input( value = mo_client->_bind_edit( mv_subtitle_ar ) ).
    f->label( 'Own theme' ).
    f->checkbox( text     = 'Ignore the global theme and use the colours below'
                 selected = mo_client->_bind_edit( mv_theme_own )
                 wrapping = abap_true ).
    f->label( 'Layout' ).        DATA(l1) = f->combobox( selectedkey = mo_client->_bind_edit( mv_layout ) ).
    l1->item( key = 'WIZARD' text = 'WIZARD — steps across the top' ).
    l1->item( key = 'WIZARD_LEFT' text = 'WIZARD_LEFT — steps down the side' ).
    l1->item( key = 'TABS' text = 'TABS' ).
    l1->item( key = 'ACCORDION' text = 'ACCORDION' ).
    l1->item( key = 'SINGLE' text = 'SINGLE' ).
    f->label( 'Theme variant' ). DATA(l2) = f->combobox( selectedkey = mo_client->_bind_edit( mv_variant ) ).
    l2->item( key = 'CLEAN' text = 'CLEAN' ).
    l2->item( key = 'PREMIUM' text = 'PREMIUM' ).
    l2->item( key = 'FLAMINGO' text = 'FLAMINGO' ).
    l2->item( key = 'PORTAL' text = 'PORTAL — large title, sticky footer' ).
    f->label( 'Accent' ).        DATA(l3) = f->combobox( selectedkey = mo_client->_bind_edit( mv_accent ) ).
    l3->item( key = 'Emphasized' text = 'Emphasized' ).
    l3->item( key = 'Accept' text = 'Accept' ).
    l3->item( key = 'Reject' text = 'Reject' ).
    l3->item( key = 'Attention' text = 'Attention' ).
    f->label( 'Density' ).       DATA(l4) = f->combobox( selectedkey = mo_client->_bind_edit( mv_density ) ).
    l4->item( key = 'Cozy' text = 'Cozy' ).
    l4->item( key = 'Compact' text = 'Compact' ).
    f->label( 'Brand colour' ).  f->input( value = mo_client->_bind_edit( mv_brand ) placeholder = 'rgb(196,30,38)' ).
    f->label( 'Navy colour' ).   f->input( value = mo_client->_bind_edit( mv_navy ) placeholder = 'rgb(16,35,62)' ).

    DATA(b) = p->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    b->button( text = 'Save & Preview' icon = 'sap-icon://play' type = 'Emphasized' press = mo_client->_event( 'SAVEPREV' ) ).
    b->link( text   = 'Open in new tab ↗'
             target = '_blank'
             class  = 'sapUiSmallMarginBegin'
             href   = engine_url( iv_journey = mv_journey_id ) ).
  ENDMETHOD.


  METHOD render_theme.
    DATA(ls_g) = zcl_rak_cj_theme=>active( ).

    io->html( content = `<div class='rakSec'>Global theme &mdash; ` && ls_g-name && `</div>` sanitizecontent = abap_false ).

    DATA(pt) = io->panel( headertext = |Applies to every journey in client { sy-mandt }|
                          expandable = abap_true
                          expanded   = abap_true
                          class      = 'sapUiSmallMarginBeginEnd' ).
    DATA(ct) = pt->content( ).

    IF zcl_rak_cj_theme=>c_allow_own = abap_false.
      ct->message_strip( text     = 'Locked. Every journey renders with this palette, including any that'
                                    && ' tick Own theme. Set C_ALLOW_OWN to ABAP_TRUE in ZCL_RAK_CJ_THEME to'
                                    && ' let journeys opt out again.'
                         type     = 'Warning'
                         showicon = abap_true
                         class    = 'sapUiSmallMarginBottom' ).
    ELSEIF mv_theme_own = abap_true AND mv_journey_id IS NOT INITIAL.
      ct->message_strip( text     = |{ to_upper( mv_journey_id ) } opts out. It renders with its own |
                                    && |Layout, Variant, Accent, Density, Brand and Navy from the panel |
                                    && |below, not with the theme shown here. Untick Own theme to bring |
                                    && |it back in line.|
                         type     = 'Warning'
                         showicon = abap_true
                         class    = 'sapUiSmallMarginBottom' ).
    ELSE.
      ct->message_strip( text     = 'This is the default for every journey. A journey takes its own colours'
                                    && ' only by ticking Own theme in the panel below.'
                         type     = 'Information'
                         showicon = abap_true
                         class    = 'sapUiSmallMarginBottom' ).
    ENDIF.

*   The chooser, above the swatches - the swatches are a preview of whatever is
*   selected, not a fixed list.
    IF mv_theme_id IS INITIAL.
      theme_form_load( ).
    ENDIF.

*   Said before the swatches, because the swatches are the thing the message is
*   about: on a borrowed stylesheet they are a picture of numbers nothing reads.
    IF mv_th_css_mime IS NOT INITIAL.
      ct->message_strip( text     = |Borrowed stylesheet. Every journey is painted by Web Repository |
                                    && |object { to_upper( mv_th_css_mime ) } (SE80 -> MIME/Web Repository), |
                                    && |not by the palette below - the colours here only feed these |
                                    && |swatches, so editing one and saving will appear to do nothing. |
                                    && |Clear the field to go back to the generated stylesheet.|
                         type     = 'Warning'
                         showicon = abap_true
                         class    = 'sapUiSmallMarginBottom' ).
    ENDIF.

    DATA(tb) = ct->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBottom' ).
    tb->label( text = 'Start from' class = 'sapUiTinyMarginEnd' ).
    DATA(tcb) = tb->combobox( selectedkey = mo_client->_bind_edit( mv_theme_id )
                              width       = '18rem' ).
    LOOP AT zcl_rak_cj_theme=>presets( ) INTO DATA(ls_pr).
      tcb->item( key  = CONV string( ls_pr-theme_id )
                 text = |{ ls_pr-name } ({ ls_pr-theme_id })| ).
    ENDLOOP.
    tb->button( text  = 'Load'
                press = mo_client->_event( 'THEMELOAD' )
                class = 'sapUiTinyMarginBegin' ).
    tb->button( text  = 'Save as global'
                type  = 'Emphasized'
                press = mo_client->_event( 'THEMESAVE' )
                class = 'sapUiTinyMarginBegin' ).

*   The swatches preview the FORM, not the stored theme, so an edit is visible
*   before it is saved.
    ct->html( content         = swatch_row( iv_label = 'Brand' iv_value = mv_th_brand )
                                && swatch_row( iv_label = 'Brand deep' iv_value = mv_th_brand_dk )
                                && swatch_row( iv_label = 'Brand light' iv_value = mv_th_brand_hi )
                                && swatch_row( iv_label = 'Brand tint' iv_value = mv_th_brand_lt )
                                && swatch_row( iv_label = 'Navy' iv_value = mv_th_navy )
                                && swatch_row( iv_label = 'Navy muted' iv_value = mv_th_navy_md )
                                && swatch_row( iv_label = 'Page' iv_value = mv_th_page_bg )
                                && swatch_row( iv_label = 'Card' iv_value = mv_th_card_bg )
                                && swatch_row( iv_label = 'Hairline' iv_value = mv_th_line )
              sanitizecontent = abap_false ).

    DATA(ft) = ct->simple_form( editable = abap_false layout = 'ResponsiveGridLayout' columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).
*   Dropdowns where the value set is fixed, inputs where it is free text. The
*   layout and variant lists are the same ones the journey Style panel offers -
*   two places listing them is already one too many, but inventing a third
*   spelling here would be worse.
    ft->label( 'Layout' ).
    DATA(gl) = ft->combobox( selectedkey = mo_client->_bind_edit( mv_th_layout ) ).
    gl->item( key = 'WIZARD' text = 'WIZARD - steps across the top' ).
    gl->item( key = 'WIZARD_LEFT' text = 'WIZARD_LEFT - steps down the side' ).
    gl->item( key = 'TABS' text = 'TABS' ).
    gl->item( key = 'ACCORDION' text = 'ACCORDION' ).
    gl->item( key = 'SINGLE' text = 'SINGLE' ).

    ft->label( 'Theme variant' ).
    DATA(gv) = ft->combobox( selectedkey = mo_client->_bind_edit( mv_th_variant ) ).
    gv->item( key = 'CLEAN' text = 'CLEAN' ).
    gv->item( key = 'PREMIUM' text = 'PREMIUM' ).
    gv->item( key = 'FLAMINGO' text = 'FLAMINGO' ).
    gv->item( key = 'PORTAL' text = 'PORTAL - large title, sticky footer' ).

    ft->label( 'Accent' ).
    DATA(ga) = ft->combobox( selectedkey = mo_client->_bind_edit( mv_th_accent ) ).
    ga->item( key = 'Emphasized' text = 'Emphasized' ).
    ga->item( key = 'Default' text = 'Default' ).
    ga->item( key = 'Transparent' text = 'Transparent' ).
    ga->item( key = 'Ghost' text = 'Ghost' ).
    ga->item( key = 'Attention' text = 'Attention' ).

    ft->label( 'Density' ).
    DATA(gd) = ft->combobox( selectedkey = mo_client->_bind_edit( mv_th_density ) ).
    gd->item( key = 'Cozy' text = 'Cozy' ).
    gd->item( key = 'Compact' text = 'Compact' ).

    ft->label( 'UI5 theme' ).
    DATA(gu) = ft->combobox( selectedkey = mo_client->_bind_edit( mv_th_ui5 ) ).
    gu->item( key = 'sap_horizon' text = 'sap_horizon' ).
    gu->item( key = 'sap_fiori_3' text = 'sap_fiori_3' ).

    ft->label( 'Brand colour' ).      ft->input( value = mo_client->_bind_edit( mv_th_brand ) ).
    ft->label( 'Brand deep' ).        ft->input( value = mo_client->_bind_edit( mv_th_brand_dk ) ).
    ft->label( 'Brand light' ).       ft->input( value = mo_client->_bind_edit( mv_th_brand_hi ) ).
    ft->label( 'Brand tint' ).        ft->input( value = mo_client->_bind_edit( mv_th_brand_lt ) ).
    ft->label( 'Navy colour' ).       ft->input( value = mo_client->_bind_edit( mv_th_navy ) ).
    ft->label( 'Navy muted' ).        ft->input( value = mo_client->_bind_edit( mv_th_navy_md ) ).
    ft->label( 'Page background' ).   ft->input( value = mo_client->_bind_edit( mv_th_page_bg ) ).
    ft->label( 'Card background' ).   ft->input( value = mo_client->_bind_edit( mv_th_card_bg ) ).
    ft->label( 'Hairline' ).          ft->input( value = mo_client->_bind_edit( mv_th_line ) ).
    ft->label( 'Corner radius' ).     ft->input( value = mo_client->_bind_edit( mv_th_radius ) ).
    ft->label( 'Shadow' ).            ft->input( value = mo_client->_bind_edit( mv_th_shadow ) ).
    ft->label( 'Font (LTR)' ).        ft->input( value = mo_client->_bind_edit( mv_th_font ) ).
    ft->label( 'Font (RTL)' ).        ft->input( value = mo_client->_bind_edit( mv_th_font_ar ) ).

*   Last, and free text rather than a dropdown. The list of stylesheets that could
*   legitimately go here is whatever is in SMW0 on this system, which this class
*   has no business enumerating - and hardcoding Z2UI5_STYLES as the only option
*   would make the next borrowed stylesheet a code change.
    ft->label( 'Stylesheet object' ).
    ft->input( value       = mo_client->_bind_edit( mv_th_css_mime )
               placeholder = 'blank = generate our own; Z2UI5_STYLES = the legacy sheet' ).
    ft->label( 'Class vocabulary' ).
    DATA(gc) = ft->combobox( selectedkey = mo_client->_bind_edit( mv_th_cls_set ) ).
    gc->item( key = '' text = 'Framework - rakCard, rakFooter, rakVal' ).
    gc->item( key = 'LEGACY' text = 'LEGACY - shapeIT-card, regularBTN, font1 weight600' ).

*   The pairing is the whole mechanism and the only way to get it wrong is to set
*   one without the other, so say so where both are visible.
    IF ( mv_th_cls_set IS NOT INITIAL AND mv_th_css_mime IS INITIAL )
    OR ( mv_th_cls_set IS INITIAL     AND mv_th_css_mime IS NOT INITIAL ).
      ct->message_strip( text     = 'Those two belong together. A class vocabulary with no stylesheet'
                                    && ' emits names nothing defines; a stylesheet with no vocabulary is'
                                    && ' loaded and then never referenced. Set both, or neither.'
                         type     = 'Error'
                         showicon = abap_true
                         class    = 'sapUiSmallMarginTop' ).
    ENDIF.

    ct->message_strip( text     = 'Direction is derived, not configured: any journey rendered in Arabic switches to RTL and the font above on its own. There is nothing to set per journey.'
                       type     = 'Information'
                       showicon = abap_true
                       class    = 'sapUiSmallMarginTop' ).
  ENDMETHOD.


  METHOD resort.
*   Sorting an index of numeric keys and rebuilding, rather than adding a
*   numeric component to ty_fld. The structure is what doc_export( ) writes and
*   snapshot( ) carries, so a transient sort key in it would leak into the
*   document and have to be explained forever.
*   The table index is the tiebreaker, so rows sharing a sequence keep the order
*   they already had instead of shuffling on every redraw. Two fields sharing a
*   sequence is a fault in its own right and lint( ) now says so.
    TYPES: BEGIN OF ty_k,
             k1  TYPE string,
             k2  TYPE string,
             num TYPE i,
             idx TYPE i,
           END OF ty_k.
    DATA lt_k TYPE STANDARD TABLE OF ty_k WITH EMPTY KEY.

    CLEAR lt_k.
    LOOP AT mt_steps INTO DATA(ls_s).
      DATA(lv_i1) = sy-tabix.
      APPEND VALUE #( num = to_int( ls_s-seqnr ) idx = lv_i1 ) TO lt_k.
    ENDLOOP.
    SORT lt_k BY num ASCENDING idx ASCENDING.
    DATA lt_s TYPE tt_step.
    LOOP AT lt_k INTO DATA(lk1).
      APPEND mt_steps[ lk1-idx ] TO lt_s.
    ENDLOOP.
    mt_steps = lt_s.

    CLEAR lt_k.
    LOOP AT mt_fields INTO DATA(ls_f).
      DATA(lv_i2) = sy-tabix.
      APPEND VALUE #( k1 = ls_f-step_id num = to_int( ls_f-seqnr ) idx = lv_i2 ) TO lt_k.
    ENDLOOP.
    SORT lt_k BY k1 ASCENDING num ASCENDING idx ASCENDING.
    DATA lt_f TYPE tt_fld.
    LOOP AT lt_k INTO DATA(lk2).
      APPEND mt_fields[ lk2-idx ] TO lt_f.
    ENDLOOP.
    mt_fields = lt_f.

    CLEAR lt_k.
    LOOP AT mt_opts INTO DATA(ls_o).
      DATA(lv_i3) = sy-tabix.
      APPEND VALUE #( k1  = ls_o-step_id
                      k2  = ls_o-field_name
                      num = to_int( ls_o-seqnr )
                      idx = lv_i3 ) TO lt_k.
    ENDLOOP.
    SORT lt_k BY k1 ASCENDING k2 ASCENDING num ASCENDING idx ASCENDING.
    DATA lt_o TYPE tt_opt.
    LOOP AT lt_k INTO DATA(lk3).
      APPEND mt_opts[ lk3-idx ] TO lt_o.
    ENDLOOP.
    mt_opts = lt_o.

    CLEAR lt_k.
    LOOP AT mt_cols INTO DATA(ls_c).
      DATA(lv_i4) = sy-tabix.
      APPEND VALUE #( k1  = ls_c-step_id
                      k2  = ls_c-field_name
                      num = to_int( ls_c-seqnr )
                      idx = lv_i4 ) TO lt_k.
    ENDLOOP.
    SORT lt_k BY k1 ASCENDING k2 ASCENDING num ASCENDING idx ASCENDING.
    DATA lt_c TYPE tt_col.
    LOOP AT lt_k INTO DATA(lk4).
      APPEND mt_cols[ lk4-idx ] TO lt_c.
    ENDLOOP.
    mt_cols = lt_c.
  ENDMETHOD.


  METHOD restore.
    mv_journey_id = is_draft-journey_id.  mv_title       = is_draft-title.
    mv_title_ar   = is_draft-title_ar.    mv_subtitle    = is_draft-subtitle.
    mv_subtitle_ar = is_draft-subtitle_ar.
    mv_layout     = is_draft-layout.      mv_variant     = is_draft-variant.
    mv_accent     = is_draft-accent.      mv_brand       = is_draft-brand.
    mv_navy       = is_draft-navy.        mv_density     = is_draft-density.
    mv_theme_own  = is_draft-theme_own.
    mv_handler    = is_draft-handler.     mv_tile_code   = is_draft-tile_code.
    mv_show_act   = is_draft-show_act.    mv_active      = is_draft-active.
    mv_bknd_act   = is_draft-bknd_act.    mv_bknd_cat    = is_draft-bknd_cat.
    mv_bknd_jny   = is_draft-bknd_jny.    mv_bknd_fmp    = is_draft-bknd_fmp.
    mv_bknd_fmr   = is_draft-bknd_fmr.
    mv_preview    = is_draft-preview.     mv_sel         = is_draft-sel.
    mv_dirty      = is_draft-dirty.
    mt_steps      = is_draft-steps.       mt_fields      = is_draft-fields.
    mt_opts       = is_draft-opts.        mt_rules       = is_draft-rules.
    mt_cols       = is_draft-cols.
    CLEAR: mt_lint, mt_lint_row, mv_lint_ok.
  ENDMETHOD.


  METHOD row_size.
    IF iv_tok IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT mt_fields INTO DATA(f) WHERE step_id = to_upper( iv_step ).
      IF row_tok( f-fgroup ) = iv_tok.
        rv = rv + 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD row_tok.
    DATA(g) = to_upper( condense( iv_group ) ).
    IF strlen( g ) > 4 AND g(4) = 'ROW:'.
      rv = g.
    ENDIF.
  ENDMETHOD.


  METHOD scan_f4.
*   preview_f4( ) names the source it used in mv_f4_src as a side effect, which
*   is read straight back here - the whole value of the line is knowing WHICH of
*   the three boxes the engine picked, not just how many rows came out.
    LOOP AT mt_fields INTO DATA(ls_f).
      IF ls_f-rollname IS INITIAL AND ls_f-shlp IS INITIAL AND ls_f-domname IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lt_opt) = preview_f4( iv_rollname = ls_f-rollname
                                 iv_shlp     = ls_f-shlp
                                 iv_domname  = ls_f-domname ).
      APPEND VALUE #( step  = ls_f-step_id
                      field = ls_f-field_name
                      src   = mv_f4_src
                      cnt   = lines( lt_opt )
                      ok    = xsdbool( lt_opt IS NOT INITIAL ) ) TO rt.
    ENDLOOP.
    CLEAR mv_f4_src.
  ENDMETHOD.


  METHOD search_rollname.
    IF iv_term IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_term) = '%' && to_upper( iv_term ) && '%'.
    SELECT a~rollname, b~ddtext, a~domname
      FROM dd04l AS a
      LEFT JOIN dd04t AS b
        ON  b~rollname   = a~rollname
        AND b~ddlanguage = @sy-langu
      WHERE ( a~rollname LIKE @lv_term OR upper( b~ddtext ) LIKE @lv_term )
        AND a~domname <> @space
      ORDER BY a~rollname
      INTO TABLE @DATA(lt) UP TO 50 ROWS.
    IF lt IS INITIAL.
      RETURN.
    ENDIF.
    SELECT domname, valpos FROM dd07l FOR ALL ENTRIES IN @lt
      WHERE domname = @lt-domname AND as4local = 'A'
      INTO TABLE @DATA(lt_vals).
    LOOP AT lt INTO DATA(ls).
      DATA(lv_cnt) = 0.
      LOOP AT lt_vals TRANSPORTING NO FIELDS WHERE domname = ls-domname.
        lv_cnt = lv_cnt + 1.
      ENDLOOP.
      IF lv_cnt > 0.
        APPEND VALUE #( rollname = ls-rollname ddtext = ls-ddtext domname = ls-domname fixcnt = lv_cnt ) TO rt.
        IF lines( rt ) >= 20.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD search_shlp.
    IF iv_term IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_term) = '%' && to_upper( iv_term ) && '%'.
    SELECT a~shlpname AS shlp, b~ddtext
      FROM dd30l AS a
      LEFT JOIN dd30t AS b
        ON  b~shlpname   = a~shlpname
        AND b~ddlanguage = @sy-langu
      WHERE ( a~shlpname LIKE @lv_term OR upper( b~ddtext ) LIKE @lv_term )
      ORDER BY a~shlpname
      INTO TABLE @rt UP TO 20 ROWS.
  ENDMETHOD.


  METHOD snapshot.
    rs = VALUE #( journey_id = mv_journey_id  title     = mv_title
                  title_ar   = mv_title_ar    subtitle  = mv_subtitle
                  subtitle_ar = mv_subtitle_ar
                  layout     = mv_layout      variant   = mv_variant
                  accent     = mv_accent      brand     = mv_brand
                  navy       = mv_navy        density   = mv_density
                  theme_own  = mv_theme_own
                  handler    = mv_handler     tile_code = mv_tile_code
                  show_act   = mv_show_act    active    = mv_active
                  bknd_act   = mv_bknd_act    bknd_cat  = mv_bknd_cat
                  bknd_jny   = mv_bknd_jny    bknd_fmp  = mv_bknd_fmp
                  bknd_fmr   = mv_bknd_fmr
                  preview    = mv_preview     sel       = mv_sel
                  dirty      = mv_dirty
                  steps      = mt_steps       fields    = mt_fields
                  opts       = mt_opts        rules     = mt_rules
                  cols       = mt_cols ).
  ENDMETHOD.


  METHOD swatch_row.
    rv = `<div style='display:flex;align-items:center;margin:5px 14px;font-size:.875rem;'>`
      && `<span style='width:28px;height:16px;border-radius:3px;margin-right:10px;`
      && `border:1px solid rgba(16,35,62,.18);display:inline-block;background:`
      && iv_value && `;'></span>`
      && `<span style='color:rgb(16,35,62);font-weight:600;display:inline-block;min-width:7rem;'>`
      && iv_label && `</span>`
      && `<code style='color:rgb(92,107,122);'>` && iv_value && `</code>`
      && `</div>`.
  ENDMETHOD.


  METHOD theme_form_load.
    DATA(ls_g) = zcl_rak_cj_theme=>active( ).
    mv_theme_id    = ls_g-theme_id.
    mv_th_brand    = ls_g-brand.     mv_th_brand_dk = ls_g-brand_dk.
    mv_th_brand_hi = ls_g-brand_hi.  mv_th_brand_lt = ls_g-brand_lt.
    mv_th_navy     = ls_g-navy.      mv_th_navy_md  = ls_g-navy_md.
    mv_th_page_bg  = ls_g-page_bg.   mv_th_card_bg  = ls_g-card_bg.
    mv_th_line     = ls_g-line_clr.  mv_th_radius   = ls_g-radius.
    mv_th_shadow   = ls_g-shadow.    mv_th_font     = ls_g-font.
    mv_th_font_ar  = ls_g-font_ar.   mv_th_layout   = ls_g-layout.
    mv_th_variant  = ls_g-variant.   mv_th_accent   = ls_g-accent.
    mv_th_density  = ls_g-density.   mv_th_ui5      = ls_g-ui5_theme.
    mv_th_css_mime = ls_g-css_mime.  mv_th_cls_set  = ls_g-cls_set.
  ENDMETHOD.


  METHOD theme_form_save.
    mv_msg = zcl_rak_cj_theme=>save( VALUE #(
      theme_id  = mv_theme_id
      name      = |Edited from { mv_theme_id }|
      brand     = mv_th_brand    brand_dk = mv_th_brand_dk
      brand_hi  = mv_th_brand_hi brand_lt = mv_th_brand_lt
      navy      = mv_th_navy     navy_md  = mv_th_navy_md
      page_bg   = mv_th_page_bg  card_bg  = mv_th_card_bg
      line_clr  = mv_th_line     radius   = mv_th_radius
      shadow    = mv_th_shadow   font     = mv_th_font
      font_ar   = mv_th_font_ar  layout   = mv_th_layout
      variant   = mv_th_variant  accent   = mv_th_accent
      density   = mv_th_density  ui5_theme = mv_th_ui5
      css_mime  = mv_th_css_mime cls_set   = mv_th_cls_set ) ).
    mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD toggle_pair.
    DATA(st) = to_upper( iv_step ).
    DATA(fl) = to_upper( iv_field ).

    IF zcl_rak_cj_lay=>get_instance( )->has_layout(
         iv_journey = CONV #( to_upper( mv_journey_id ) )
         iv_step    = CONV #( st ) ) = abap_true.
      mv_msg   = |{ st } is managed in Design mode — pairing here would be ignored. Change the row there, or Clear its layout first.|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    READ TABLE mt_fields ASSIGNING FIELD-SYMBOL(<f>) WITH KEY step_id = st field_name = fl.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   ---- already paired: leave the row -----------------------------------
    DATA(lv_tok) = row_tok( <f>-fgroup ).
    IF lv_tok IS NOT INITIAL.
      CLEAR <f>-fgroup.
*     A one-cell row is not a row. Dropping to a single member releases the
*     token entirely, otherwise the survivor keeps a ROW: group that renders
*     exactly as it would with no group at all - config that lies.
      IF row_size( iv_step = st iv_tok = lv_tok ) < 2.
        LOOP AT mt_fields ASSIGNING FIELD-SYMBOL(<o>) WHERE step_id = st.
          IF row_tok( <o>-fgroup ) = lv_tok.
            CLEAR <o>-fgroup.
          ENDIF.
        ENDLOOP.
      ENDIF.
      mv_msg   = |{ fl } unpaired — it renders on its own row again|.
      mv_mtype = 'Success'.
      RETURN.
    ENDIF.

*   ---- an authored group heading is not ours to overwrite ---------------
    IF <f>-fgroup IS NOT INITIAL.
      mv_msg   = |{ fl } is in group '{ <f>-fgroup }'. FGROUP carries either a heading or a row token, not both — clear the Group first.|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    IF pairable( <f>-ftype ) = abap_false.
      mv_msg   = |{ <f>-ftype } cannot share a row — the engine gives it the full width (or ends the row at it, if it is a block)|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    DATA(lv_prev) = prev_field( iv_step = st iv_field = fl ).
    IF lv_prev IS INITIAL.
      mv_msg   = |{ fl } is the first field in { st } — pair joins the field ABOVE, so there is nothing to join|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    READ TABLE mt_fields ASSIGNING FIELD-SYMBOL(<p>) WITH KEY step_id = st field_name = lv_prev.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF pairable( <p>-ftype ) = abap_false.
      mv_msg   = |{ lv_prev } ({ <p>-ftype }) above it cannot share a row|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    IF <p>-hidden = abap_true OR <f>-hidden = abap_true.
      mv_msg   = 'A hidden field is consumed by the row but never drawn, leaving its partner alone in a two-cell row. Unhide it first.'.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    IF <p>-section <> <f>-section.
      mv_msg   = |Different sections ('{ <p>-section }' / '{ <f>-section }') — each section opens its own card, so the engine ends the row between them|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

*   ---- join the row above, or open a new one ----------------------------
    DATA(lv_ptok) = row_tok( <p>-fgroup ).
    IF lv_ptok IS NOT INITIAL.
*     Cells are flex:1 1 14rem, so a fifth one wraps rather than shrinking.
*     Four is the point at which pairing stops helping.
      IF row_size( iv_step = st iv_tok = lv_ptok ) >= 4.
        mv_msg   = 'That row already holds four fields — start a new row instead'.
        mv_mtype = 'Warning'.
        RETURN.
      ENDIF.
      <f>-fgroup = lv_ptok.
      mv_msg     = |{ fl } added to the row with { lv_prev } ({ row_size( iv_step = st iv_tok = lv_ptok ) } fields)|.
      mv_mtype   = 'Success'.
      RETURN.
    ENDIF.

    IF <p>-fgroup IS NOT INITIAL.
      mv_msg   = |{ lv_prev } is in group '{ <p>-fgroup }' — clear its Group before pairing|.
      mv_mtype = 'Warning'.
      RETURN.
    ENDIF.

    DATA(lv_new) = next_rowtok( st ).
    <p>-fgroup = lv_new.
    <f>-fgroup = lv_new.
    mv_msg     = |{ lv_prev } and { fl } now share one row — Save to apply|.
    mv_mtype   = 'Success'.
  ENDMETHOD.


  METHOD tpl_chips.
    DATA lt_chip TYPE string_table.
    DATA(ls_cfg) = zcl_rak_cj_cfg_cache=>get( iv_journey = iv_id iv_lang = CONV #( sy-langu ) ).
    IF ls_cfg-journey_id IS INITIAL.
      RETURN.
    ENDIF.
    IF ls_cfg-theme-layout_mode IS NOT INITIAL.
      APPEND ls_cfg-theme-layout_mode TO lt_chip.
    ENDIF.
    IF ls_cfg-theme-variant = 'PREMIUM'.
      APPEND `PREMIUM` TO lt_chip.
    ENDIF.
    IF lines( ls_cfg-steps ) > 1.
      APPEND |{ lines( ls_cfg-steps ) } steps| TO lt_chip.
    ENDIF.
    DATA: lv_search TYPE abap_bool, lv_upload TYPE abap_bool, lv_pay TYPE abap_bool.
    LOOP AT ls_cfg-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_fld).
        CASE ls_fld-type.
          WHEN 'SEARCH'.
            lv_search = abap_true.
          WHEN 'UPLOAD'.
            lv_upload = abap_true.
          WHEN 'PAYFEE'.
            lv_pay    = abap_true.
        ENDCASE.
        IF ls_fld-has_attach = abap_true. lv_upload = abap_true. ENDIF.
      ENDLOOP.
    ENDLOOP.
    IF lv_search = abap_true. APPEND `BP lookup`   TO lt_chip. ENDIF.
    IF lv_upload = abap_true. APPEND `Attachments` TO lt_chip. ENDIF.
    IF lv_pay    = abap_true. APPEND `Payment`     TO lt_chip. ENDIF.
    IF lines( ls_cfg-rules ) > 0.
      APPEND |{ lines( ls_cfg-rules ) } rules| TO lt_chip.
    ENDIF.
    LOOP AT lt_chip INTO DATA(lv_c).
      rv = rv && `<span class="rakChip">` && lv_c && `</span>`.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
