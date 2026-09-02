*&---------------------------------------------------------------------*
*  ZCL_RAK_MIGRATOR  (v8 - side-by-side rows; v7 grid projection)        *
*                                                                      *
*  v8 replaces the step COLUMNS pass with real per-row pairing.          *
*                                                                      *
*   A. STEP COLUMNS never did anything. columnsL arranges SimpleForm     *
*      FormContainers, a container is started only by a core:Title, and  *
*      a core:Title comes only from FGROUP - which this projector has    *
*      never written (see the "not derivable" list below). So the 1-vs-2 *
*      decision v7 fixed was arranging a single container. Every         *
*      migrated journey has rendered single-column since v1. Now 1.      *
*                                                                      *
*   B. Fields are PAIRED instead, via ROW: tokens in FGROUP, which       *
*      ZCL_RAK_JOURNEY_ENGINE->ROW_KEY( ) renders as one HBox of         *
*      label+control cells. Two passes: affinity (bilingual twins,       *
*      from/to ranges) then fill (any two adjacent narrow controls).     *
*      iv_two_up = abap_false keeps only the affinity pairs.             *
*                                                                      *
*      FGROUP is therefore no longer blank on output - but only ever     *
*      with a ROW: token, never a heading, and only where it was blank.  *
*                                                                      *
*  v7 fixes four defects and closes the biggest projection gap.         *
*                                                                      *
*   A. STEP COLUMNS were inserted as 1, but apply_layout( ) only        *
*      updates rows still at 0 - so the 1-vs-2 decision was dead code   *
*      and every migrated journey stayed single-column. Now inserted 0. *
*                                                                      *
*   B. The per-field WIDTH pass is DELETED. The engine sizes controls    *
*      from ctrl_width( ) by ftype and never reads the width column, so  *
*      the UPDATEs did nothing and tripped the Studio lint warning on    *
*      every field.                                                     *
*                                                                      *
*   C. TABLE now projects as EDITABLE_TABLE with a real column spec      *
*      built from the LEVEL_CON='T' descendants (new grid_spec( )).      *
*      v9: DATA3 is read too. A legacy list declared SingleSelect* or    *
*      MultiSelect* is a PICK list, so the spec leads with a SEL:        *
*      directive, the grid is written READONLY, and a <NAME>_PICK        *
*      READONLY field is created to receive the chosen key(s).           *
*      Those columns were already detected and staged, then thrown away, *
*      leaving a plain TABLE that needs get_table( ) - i.e. an empty     *
*      grid on a handler-free journey. A table with no usable columns is  *
*      DROPPED and counted, not shipped as a stub.                       *
*                                                                      *
*   D. PAYFEE is DROPPED and counted. Without handler_class the engine    *
*      renders a red "payment unavailable" strip at the citizen.          *
*                                                                      *
*   E. attach_maxmb is written as 0 = follow the system default            *
*      (TVARVC ZRAK_CJ_ATT_MAXMB, built-in floor 2 MB). A per-field value  *
*      still overrides it. Older note: attach_maxmb 5 -> 2 because the     *
*      the column; it now honours it, so writing 5 silently raised every  *
*      migrated upload limit.                                            *
*                                                                      *
*   F. theme_variant PORTAL + an Arabic subtitle (was English-only).      *
*                                                                      *
*  STILL NOT DERIVABLE from /QNV/SB_UI_DEFIN, so left blank on purpose:  *
*    zsection, placeholder, default_val (except the grid spec),           *
*    fgroup AS A HEADING (v8 writes ROW: row tokens into it, never a      *
*    container caption - a real group heading is still not derivable),     *
*    min_len/max_len/min_val/max_val, msg_ar, fstate, a REVIEW step.      *
*    Step titles are best-effort from the lowest-seq section heading;      *
*    pass exact ones via iv_steps for any flagship journey.               *
*                                                                      *
*  --- v6.1 base (grammar rules, shlp-F4, step titles) ----------------  *
*                                                                      *
*  v6 takes the cream of both the v5 reconstructor and the hand-crafted*
*  ZRAK_EPDA_DEWATERING_LOAD golden seed. Changes over v5:             *
*                                                                      *
*   1. UI_FIELD_LOGICS is now PARSED into SHOW/HIDE rules (was staged   *
*      only). Grammar per trigger control: comma-separated             *
*      TARGET-V-T (show) / TARGET-V-F (hide). The rule SOURCE is the    *
*      segmented group the button belongs to (grp_sig); the rule VALUE  *
*      is the button's own field_name (= its option key). Bare targets  *
*      with no -V-T/-V-F suffix (e.g. a COMBOBOX's 'VEHICLE_BOX') are    *
*      ignored here - those are driven by DATA4/DATA5 in collect_rules,  *
*      which carries the real trigger key ('2') and BEATS the hand-craft*
*      (which guessed 'VEHICLE'). Logic-rules and DATA4/DATA5 rules are  *
*      merged and deduped on the full tuple.                            *
*                                                                      *
*   2. CONTAINER targets EXPAND to fields. A rule whose target is a     *
*      VBOX/HBOX/PANEL (PERMIT_FINDER, LICENSE_FINDER, OWNER_FINDER,     *
*      VEHICLE_BOX) is expanded to its projected interactive/display    *
*      descendant field(s) - the way the hand-craft targeted PERMITNO / *
*      LICENSENO directly. CJS rules are field-level, so a container     *
*      target that can't be projected is dropped rather than dangling.  *
*                                                                      *
*   3. SEGMENTED groups now project as ONE field per group (v5 emitted  *
*      one _FLD per button - a latent duplicate). The group field name  *
*      is deterministic (safe name of the lowest-seq member) so the     *
*      rule builder and the field projector agree on the source field.  *
*      Options are the members (opt_key = member field_name).           *
*                                                                      *
*   4. F4 SOURCE = shlp (SH_NAME); rollname stays BLANK. Writing a       *
*      rollname routes the engine's F4 resolver down the domain/value-   *
*      table path, and those data elements (ZRAK_EPDA_LOCATION etc.)     *
*      have no value table -> EMPTY dropdown. shlp-only is what actually  *
*      populates a handler-free combobox (the shlp comboboxes have empty *
*      DATA1; options come from the search help).                        *
*                                                                      *
*   4b. STEP TITLES. The RAKSTAGEBAR carries NO step names (DATA2 is the *
*      active-stage index, DATA3 icon keys), so titles are derived from  *
*      each screen's lowest-seq SECTION HEADING - a display row that is  *
*      not chrome, not a folded field caption, not a bare code. This is  *
*      best-effort; for a flagship journey pass exact titles via the new *
*      iv_steps / ty_job-steps override ("EN^AR|EN^AR|..."). Distinct    *
*      valid titles are never collapsed to "Step n" any more.            *
*                                                                      *
*   5. Attachment fields render as a PURE uploader: ftype='UPLOAD' (not  *
*      INPUT+has_attach, which adds an unused empty text box, since the   *
*      source was a pure RAKUPLOADER). has_attach='X' + the doc-code      *
*      tech_name are kept so the staging pipeline is unchanged.           *
*      attach_types='pdf,jpg,png' (v5 wrote DATA2 -> 'B6'/'FP'... which   *
*      is the DOC CODE, not a file type -> tech_name only). attach_maxmb  *
*      defaults 5-REVIEW (screen notice confirms 3 for E023).             *
*                                                                      *
*   6. cj_type DROPPED (no longer a field / not read / not written).    *
*      bknd_journey = raw BE code stays (the one-code decision).        *
*                                                                      *
*   7. UI JOURNEY NAME is ALWAYS PREFIXED (default 'MIG_'), enforced on   *
*      migrate() itself, not just migrate_many() - the UI journey_id    *
*      never equals the raw legacy code, so it can't collide with the   *
*      legacy code space regardless of category. bknd_journey keeps the *
*      raw code.                                                        *
*                                                                      *
*  Golden test: reproduce ZRAK_EPDA_DEWATERING_LOAD from the E023       *
*  /QNV/SB_UI_DEFIN config, beating the hand-craft on R3's trigger key  *
*  ('2') and reconstructing the owner-finder / permit-finder rules.     *
*                                                                      *
*  --- v5 base (unchanged principles) --------------------------------  *
*  Staging (ZRAK_T_MIG_RAW) is TOTAL: all cols, all rows, always.      *
*  Projection into shared tables is SELECTIVE: only renderable fields. *
*  Quality passes before projection: PAIR_LABELS (fold a LABEL caption  *
*  into the control it precedes), DETECT_CHROME (a display name on >=2  *
*  screens is a header/logo/breadcrumb -> dropped), IS_IN_TABLE (any    *
*  descendant of a TABLE container is a column, not a loose field),     *
*  IS_CODE_LABEL ("Label 26"/"F9" are never shown as captions), and a   *
*  COMBOBOX DATA1 guard (a truncated 250-char JSON array is discarded   *
*  -> fall back to shlp).                                              *
*                                                                      *
*  HONEST GAPS still staged, not auto-projected:                       *
*    - regex/msg auto-set for EMAIL only; other validations staged.     *
*    - Table (LEVEL_CON='T') column configs staged, wired via the TABLE *
*      ftype's own column mechanism / handler get_table.               *
*    - Placeholder 3rd translation table still not exported.            *

CLASS zcl_rak_migrator DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_report,
        screen    TYPE /qnv/sb_ui_defin-screen_name,
        step_id   TYPE string,
        title     TYPE string,
        src_rows  TYPE i,
        rendered  TYPE i,
        columns   TYPE i,
        container TYPE i,
        backend   TYPE i,
        options   TYPE i,
        rules     TYPE i,
        defaulted TYPE i,
        discarded TYPE i,
        staged    TYPE i,
      END OF ty_report,
      tt_report TYPE STANDARD TABLE OF ty_report WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_candidate,
        category TYPE /qnv/sb_ui_defin-category,
        journey  TYPE string,
        screens  TYPE i,
        rows     TYPE i,
        cjs_id   TYPE string,
      END OF ty_candidate,
      tt_candidate TYPE STANDARD TABLE OF ty_candidate WITH EMPTY KEY.

    " mandatory UI journey-name prefix. journey_id is ALWAYS <prefix><code>
    " so the UI journey code never collides with the legacy raw code space.
    CONSTANTS c_sandbox TYPE string VALUE 'MIG_'.

*   The portal tile is NOT the CJS journey id, and it is far shorter.
*   ZEGA_T_CJ_GRP-JOURNEYID and ZRAK_T_JNY-TILE_CODE are both
*   ZDE_CJ_JOURNEYID = CHAR(4), so the old <prefix><code> form
*   ('MIG_' && 'M011') was cut to 'MIG_' ON THE INSERT, silently: every
*   journey in a batch wrote the SAME tile and each MODIFY overwrote the
*   one before it, which is why a fifteen-journey run left one leaf.
*   TILE_CODE( ) builds a real four-character code instead.
    CONSTANTS c_tile_pfx TYPE string VALUE 'AI'.
    CONSTANTS c_tile_len TYPE i      VALUE 4.

*   Default portal group for migrated journeys. NEVER default this to a code
*   that already exists: '901' - the old default - is a live group carrying
*   ~25 production journeys, and the previous MODIFY relabelled it
*   "AI Driven Journeys" and rewrote its LEVELNO/ORDERNO from blank to 0/99.
*   MIGRATE( ) now refuses any group it did not create.
    CONSTANTS c_main_grp TYPE string VALUE 'AI00'.

*   THE POST PATH, WHICH THE MIGRATOR USED TO LEAVE OFF ENTIRELY.
*   Every hand-authored feeder in this repository - E014, E015, E027,
*   E028, E029, D009 - writes these three columns, and a migrated journey
*   wrote none of them: BKND_ACTIVE stayed blank and both function-module
*   names stayed empty. The result renders, validates, collects every
*   answer and then posts NOTHING, with no error anywhere, because the
*   engine has no backend to call. That is the whole of the "the M
*   journeys do not submit" problem - not missing plumbing, three columns.
    CONSTANTS c_fm_post TYPE string VALUE 'ZFM_EGA_CJ_FW_POST_N'.
    CONSTANTS c_fm_read TYPE string VALUE 'ZFM_EGA_CJ_FW_READ_N'.

    " one row per journey to migrate in a batch
    TYPES:
      BEGIN OF ty_job,
        category TYPE string,
        journey  TYPE string,          " e.g. 'E023' (screen NE023_1_n)
        title    TYPE string,
        title_ar TYPE string,
        steps    TYPE string,          " optional step titles, positional,
        " "EN^AR|EN^AR|..." (blank = auto-derive)
      END OF ty_job,
      tt_job TYPE STANDARD TABLE OF ty_job WITH EMPTY KEY.

    METHODS list_candidates
      RETURNING VALUE(rt) TYPE tt_candidate.

    " Batch-migrate many journeys. Each becomes <prefix><journey>
    " (MIG_E023 ...) and is dropped into the portal directly under the
    " 99 "AI Driven Journeys" tile.
    METHODS migrate_many
      IMPORTING it_jobs   TYPE tt_job
                iv_dept   TYPE string
                iv_main     TYPE string DEFAULT c_main_grp
                iv_prefix   TYPE string DEFAULT c_sandbox
                iv_tile_pfx TYPE string DEFAULT c_tile_pfx
                iv_bknd_active TYPE abap_bool DEFAULT abap_true
                iv_handler  TYPE string DEFAULT ''
                iv_badi     TYPE abap_bool DEFAULT abap_true
                iv_badi_all TYPE abap_bool DEFAULT abap_false
      EXPORTING et_report TYPE tt_report
                ev_log    TYPE string.

    " Wipe every journey created with the given prefix - journeys, steps,
    " fields, options, rules, staging rows and portal leaves.
    METHODS teardown_all
      IMPORTING iv_prefix TYPE string DEFAULT c_sandbox
      EXPORTING ev_log    TYPE string.

    METHODS migrate
      IMPORTING iv_category      TYPE string
                iv_journey       TYPE string
                iv_cjs_id        TYPE string
                iv_title         TYPE string
                iv_title_ar      TYPE string
                iv_tile          TYPE string
                iv_dept          TYPE string
                iv_main          TYPE string DEFAULT c_main_grp
                iv_prefix        TYPE string DEFAULT c_sandbox
                iv_tile_pfx      TYPE string DEFAULT c_tile_pfx
*               ON by default, the way every feeder has it. Blank migrates
*               a journey that renders but cannot post - useful only for
*               looking at a screen, never for testing one.
                iv_bknd_active   TYPE abap_bool DEFAULT abap_true
                iv_handler       TYPE string DEFAULT ''
*               Ask the BAdI what each screen really looks like - step
*               names and required flags the export does not carry. ON by
*               default; a journey whose BAdI is not registered simply
*               gets nothing back and migrates as before.
                iv_badi          TYPE abap_bool DEFAULT abap_true
*               Probe EVERY screen rather than the first. The stage list
*               is identical across a journey's screens, so this buys only
*               the per-screen MANDATORY flags - at one backend READ per
*               screen. Off by default: a fifteen-journey batch is sixty
*               reads with it on.
                iv_badi_all      TYPE abap_bool DEFAULT abap_false
                iv_steps         TYPE string DEFAULT ''   " optional step titles, positional
*               One legacy SCREEN_NAME (e.g. 'E023') can carry more than one
*               sub-flow under the SAME journey_of_screen( ) code - NE014_1_*
*               (registration), NE014_2_* (renewal) and NE014_3_* (appeal) all
*               derive to 'E014', because journey_of_screen( ) only strips the
*               leading N and splits at the FIRST '_'. Left blank (the default,
*               and every existing caller), extract_rows( ) keeps its original
*               'N<iv_journey>_*' match and behaviour does not change. Set this
*               to the full screen family instead ('NE014_2') to migrate just
*               that sub-flow as its own journey while iv_journey/bknd_journey
*               keep recording the shared raw legacy code.
                iv_screen_prefix TYPE string DEFAULT ''
      EXPORTING ev_ok       TYPE abap_bool
                ev_msg      TYPE string
                et_report   TYPE tt_report.

    METHODS teardown
      IMPORTING iv_cjs_id TYPE string
      EXPORTING ev_msg    TYPE string.

*   Four-character portal tile code for a legacy journey code, e.g.
*   'M011' -> 'AI11', 'E023' -> 'AI23'. The prefix names the space the tile
*   lives in; whatever room is left is filled from the END of the code,
*   because that is the part that distinguishes one journey from the next.
*   The result is never longer than C_TILE_LEN, so nothing is truncated by
*   the INSERT - and MIGRATE( ) refuses a code that is already taken rather
*   than writing over it.
    CLASS-METHODS tile_code
      IMPORTING iv_journey TYPE string
                iv_prefix  TYPE string DEFAULT c_tile_pfx
      RETURNING VALUE(rv)  TYPE string.
    " Post-projection layout pass. Pairs fields onto shared rows (ROW: tokens
    " in FGROUP - see the engine's row_key( )) and settles the step column
    " count. iv_two_up = abap_false restricts pairing to affinity pairs only
    " (bilingual twins and from/to ranges) and leaves everything else stacked.
    METHODS apply_layout
      IMPORTING iv_journey TYPE zrak_t_jny-journey_id
                iv_two_up  TYPE abap_bool DEFAULT abap_true
      EXPORTING ev_pairs   TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
    " ABAP component / z2ui5 attribute hard limit is 30. The engine appends
    " per-field STATE companions (<field>_VST etc.), so the BASE name must
    " leave headroom. 26 = 30 - 4.
    CONSTANTS c_name_max TYPE i VALUE 26.

    CONSTANTS:
      c_interact  TYPE char1 VALUE 'I',
      c_display   TYPE char1 VALUE 'D',
      c_action    TYPE char1 VALUE 'A',
      c_container TYPE char1 VALUE 'C',
      c_stage     TYPE char1 VALUE 'S',
      c_backend   TYPE char1 VALUE 'B',
      c_decor     TYPE char1 VALUE 'X',
      c_chrome    TYPE char1 VALUE 'H'.

    TYPES:
      BEGIN OF ty_row.
        INCLUDE TYPE /qnv/sb_ui_defin.
    TYPES: seq_key   TYPE i,
        text_en   TYPE string,
        text_ar   TYPE string,
        lbl_en    TYPE string,
        lbl_ar    TYPE string,
        ph_en     TYPE string,
        script    TYPE string,
        ftype     TYPE string,
        role      TYPE char1,
        is_col    TYPE abap_bool,
        defaulted TYPE abap_bool,
        grp_sig   TYPE string,
      END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_stage, stage TYPE string, type TYPE string,
                              icon TYPE string, text TYPE string, END OF ty_stage,
           tt_stage TYPE STANDARD TABLE OF ty_stage WITH EMPTY KEY,
           BEGIN OF ty_kv, key TYPE string, text TYPE string, END OF ty_kv,
           tt_kv TYPE STANDARD TABLE OF ty_kv WITH EMPTY KEY.

    " projected conditional-visibility rule (journey level - no step_id)
    TYPES: BEGIN OF ty_rule,
             rule_id   TYPE string,
             src_field TYPE string,
             src_op    TYPE string,
             src_value TYPE string,
             action    TYPE string,
             tgt_field TYPE string,
           END OF ty_rule,
           tt_rule TYPE STANDARD TABLE OF ty_rule WITH EMPTY KEY.

    " original-field -> safe (projected) field name, per screen
    TYPES: BEGIN OF ty_nm,
             screen TYPE /qnv/sb_ui_defin-screen_name,
             orig   TYPE string,
             safe   TYPE string,
           END OF ty_nm.

    TYPES:
      BEGIN OF ty_vt, spras TYPE spras, code TYPE /qnv/sb_valuet-value_code, txt TYPE string, END OF ty_vt,
        BEGIN OF ty_lt, spras TYPE spras, code TYPE /qnv/sb_labelt-label_code, txt TYPE string, END OF ty_lt.
    DATA mt_val TYPE HASHED TABLE OF ty_vt WITH UNIQUE KEY spras code.
    DATA mt_lbl TYPE HASHED TABLE OF ty_lt WITH UNIQUE KEY spras code.
    DATA mt_used_names TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA mt_name TYPE HASHED TABLE OF ty_nm WITH UNIQUE KEY screen orig.
    " safe field names that must start hidden (journey-unique names)
    DATA mt_hidden TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    " v5 quality-pass maps (keyed by RAW upper-case field_name, per screen)
    TYPES: BEGIN OF ty_cap,
             screen TYPE /qnv/sb_ui_defin-screen_name,
             field  TYPE string,       " raw field_name, upper
             en     TYPE string,
             ar     TYPE string,
           END OF ty_cap.
    DATA mt_caption  TYPE HASHED TABLE OF ty_cap WITH UNIQUE KEY screen field.
    DATA mt_consumed TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line. " |screen/RAW| label rows folded into a control
    DATA mt_chrome   TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line. " |screen/RAW| header/logo/breadcrumb

    METHODS load_text_caches.
    METHODS extract_rows
      IMPORTING iv_category      TYPE string
                iv_journey       TYPE string OPTIONAL
                iv_screen_prefix TYPE string OPTIONAL
      RETURNING VALUE(rt)        TYPE tt_row.
    METHODS classify
      CHANGING cs_row TYPE ty_row.
    METHODS stage_rows
      IMPORTING iv_cjs_id TYPE string it_rows TYPE tt_row.
    METHODS step_title
      IMPORTING it_rows   TYPE tt_row iv_screen TYPE /qnv/sb_ui_defin-screen_name iv_no TYPE i
      EXPORTING ev_en     TYPE string ev_ar TYPE string.
*   ---- composite control -> wrapper API binding ----------------------
*   A ShapeIt composite does NOT post through the QNV item pipeline. Its
*   TECHNICAL_NAME is blank in /QNV/SB_UI_DEFIN on purpose, because the
*   control writes through its own OData service rather than through
*   ct_item_data. So the field needs to say WHICH service instead - which
*   is what this binding is, and why no TECH_NAME is invented for it.
*
*   It rides DEFAULT_VAL behind an API: prefix, the same way TEXT:, OTR:
*   and SEL: already do. No DDIC column, no activation, no table adjust.
*
*       API:<api>:<entityset>[:<domain>[:<filter>]]
*
*   <api>       the CJS wrapper - PROPERTY, TENANCY, FEES, SIGN, VALUEHELP
*   <entityset> what it reads, so the wrapper needs no per-field CASE
*   <domain>    ValueHelp DomainName, where ValueHelp is the source
*   <filter>    ValueHelp DomainFilter - only ZCJ_BTYPE uses one ('10BU')
    TYPES: BEGIN OF ty_bind,
             ftype   TYPE string,
             api     TYPE string,
             eset    TYPE string,
             domain  TYPE string,
             dfilter TYPE string,
           END OF ty_bind.
    TYPES tt_bind TYPE STANDARD TABLE OF ty_bind WITH EMPTY KEY.

    METHODS bind_table
      RETURNING VALUE(rt) TYPE tt_bind.

*   The API: directive for one field, or blank when the ftype is not a
*   composite. Blank is the overwhelmingly common answer.
    METHODS api_bind
      IMPORTING iv_ftype  TYPE string
                iv_field  TYPE string OPTIONAL
      RETURNING VALUE(rv) TYPE string.

    METHODS combobox_options
      IMPORTING is_row    TYPE ty_row
      RETURNING VALUE(rt) TYPE tt_kv.
    METHODS build_name_map
      IMPORTING it_rows TYPE tt_row.
*   ---- what the BAdI says, gathered at migrate time ------------------
*   THE EXPORT IS HALF THE CONFIGURATION. /QNV/SB_UI_DEFIN describes the
*   screen as it was DESIGNED; ZIF_EGA_FW_CJI~READ describes it as it is
*   SERVED - the implementation mutates the definition rows it is handed,
*   and two of the things it writes are not in the export at all:
*
*     ADDITIONALDATA3 on the STAGES row - the step names the citizen sees
*         ("Parcel Selection,Documents,Fees & Payment" on M016), which is
*         why derived titles never matched the live service
*     MANDATORY per field - the required flags as the screen actually
*         enforces them, which can differ from the design-time column
*
*   The engine already reads this on every round trip (see
*   ZCL_RAK_QNV_BRIDGE->CTRL_OF). Reading it ONCE here, at migrate time,
*   is what lets a migrated journey start out right rather than be
*   corrected on first render.
    TYPES: BEGIN OF ty_badi_fld,
             screen TYPE string,
             field  TYPE string,
             mand   TYPE abap_bool,
           END OF ty_badi_fld,
           tt_badi_fld TYPE SORTED TABLE OF ty_badi_fld WITH UNIQUE KEY screen field.

    DATA mt_badi  TYPE tt_badi_fld.
    DATA mt_stage TYPE string_table.
    DATA mv_badi_ok TYPE abap_bool.

*   One screen, one call. Fills MT_BADI and - the first time a screen
*   answers one - MT_STAGE. Silent on failure: a journey whose BAdI is not
*   registered migrates exactly as it did before.
    METHODS badi_probe
      IMPORTING iv_category TYPE string
                iv_journey  TYPE string
                iv_screen   TYPE string
                it_rows     TYPE tt_row.

*   Is this legacy screen the post-submit confirmation page rather than a
*   step the citizen fills in? See the call site.
    METHODS is_confirmation
      IMPORTING it_rows   TYPE tt_row
                iv_screen TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.

    METHODS norm_name
      IMPORTING iv_name TYPE string iv_is_table TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv) TYPE string.
    METHODS safe_of
      IMPORTING iv_screen TYPE /qnv/sb_ui_defin-screen_name iv_orig TYPE string
      RETURNING VALUE(rv) TYPE string.
    METHODS is_descendant
      IMPORTING it_rows TYPE tt_row is_row TYPE ty_row iv_ancestor TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.
    METHODS collect_rules
      IMPORTING it_rows TYPE tt_row iv_screen TYPE /qnv/sb_ui_defin-screen_name
      RETURNING VALUE(rt) TYPE tt_rule.
    " v6: parse UI_FIELD_LOGICS (TARGET-V-T / -V-F) into SHOW/HIDE rules
    METHODS collect_logic_rules
      IMPORTING it_rows TYPE tt_row iv_screen TYPE /qnv/sb_ui_defin-screen_name
      RETURNING VALUE(rt) TYPE tt_rule.
    " v6: a container target -> its projected descendant field name(s)
    METHODS expand_target
      IMPORTING it_rows TYPE tt_row iv_screen TYPE /qnv/sb_ui_defin-screen_name iv_target TYPE string
      RETURNING VALUE(rt) TYPE string_table.
    " v6: does a row actually become a projected _FLD row?
    METHODS is_projected
      IMPORTING it_rows TYPE tt_row is_row TYPE ty_row
      RETURNING VALUE(rv) TYPE abap_bool.
    " v6: deterministic segmented-group field name (safe name of 1st member)
    METHODS seg_name
      IMPORTING it_rows TYPE tt_row iv_screen TYPE /qnv/sb_ui_defin-screen_name iv_grp TYPE string
      RETURNING VALUE(rv) TYPE string.
    METHODS is_nav_button
      IMPORTING is_row TYPE ty_row RETURNING VALUE(rv) TYPE abap_bool.
    METHODS pair_labels   IMPORTING it_rows TYPE tt_row.
    METHODS detect_chrome IMPORTING it_rows TYPE tt_row.
    METHODS is_in_table   IMPORTING it_rows TYPE tt_row is_row TYPE ty_row RETURNING VALUE(rv) TYPE abap_bool.
    METHODS is_code_label IMPORTING iv_text TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    " v7: guidance / notice text - a sentence, never a field caption or a
    " step title ("Each file maximum allowed size - 3MB", "*School Name
    " must include Private and School", "Your Request was submitted!").
    METHODS is_notice     IMPORTING iv_text TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    " v7: name a step from what it CONTAINS when no clean heading exists.
    METHODS step_from_content
      IMPORTING it_rows   TYPE tt_row
                iv_screen TYPE /qnv/sb_ui_defin-screen_name
                iv_no     TYPE i
                iv_last   TYPE abap_bool
      RETURNING VALUE(rv) TYPE string.
    METHODS step_icon IMPORTING iv_title  TYPE string
                                it_rows   TYPE tt_row
                                iv_screen TYPE /qnv/sb_ui_defin-screen_name
                      RETURNING VALUE(rv) TYPE string.
    METHODS journey_of_screen
      IMPORTING iv_screen TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS pretty
      IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    " classify() ftype -> the ftype the engine can actually render.
    " Blank result = the row must not become a _FLD row.
    METHODS render_ftype
      IMPORTING iv_ftype  TYPE string
      RETURNING VALUE(rv) TYPE string.
    " v7: build an EDITABLE_TABLE column spec from a legacy table's
    " LEVEL_CON='T' descendants -> "NAME:Label:TYPE|NAME:Label:TYPE|..."
*   v9: DATA3 is read as well. A legacy list declared SingleSelect* or
*   MultiSelect* is a PICK list, not a data-entry grid, so the spec leads with a
*   SEL: directive, the caller is handed a target field name to create, and the
*   grid comes back marked read-only. RETURNING is gone because ABAP will not
*   allow it alongside EXPORTING.
    METHODS grid_spec
      IMPORTING it_rows     TYPE tt_row
                is_row      TYPE ty_row
      EXPORTING ev_spec     TYPE string
                ev_sel_tgt  TYPE string
                ev_readonly TYPE abap_bool.

*   v8: side-by-side pairing (apply_layout)
    TYPES: BEGIN OF ty_pf,
             field_name TYPE zrak_t_jny_fld-field_name,
             seqnr      TYPE zrak_t_jny_fld-seqnr,
             ftype      TYPE zrak_t_jny_fld-ftype,
             zlabel     TYPE zrak_t_jny_fld-zlabel,
             zsection   TYPE zrak_t_jny_fld-zsection,
             elig       TYPE abap_bool,
             tok        TYPE zrak_t_jny_fld-fgroup,
           END OF ty_pf,
           tt_pf TYPE STANDARD TABLE OF ty_pf WITH EMPTY KEY.

    " Can this ftype share a row? Narrow controls only. Blocks, full-width
    " controls and anything the engine renders through render_block are out -
    " the engine ends a row at a block anyway, so pairing one is dead config.
    METHODS pairable
      IMPORTING iv_ftype  TYPE zrak_t_jny_fld-ftype
      RETURNING VALUE(rv) TYPE abap_bool.
    " Split a trailing language word off a label or field name:
    " 'School Name English' -> base 'SCHOOL NAME', lang 'EN'. Blank lang means
    " the text carries no language marker.
    METHODS lang_base
      IMPORTING iv_text TYPE string
      EXPORTING ev_base TYPE string
                ev_lang TYPE string.
    " 'A' when the text names the start of a range, 'B' the end, blank neither.
    METHODS range_side
      IMPORTING iv_text   TYPE string
      RETURNING VALUE(rv) TYPE char1.
    " Do these two adjacent fields belong together on purpose (bilingual twins
    " or the two ends of one range), as opposed to merely both fitting?
    METHODS affinity
      IMPORTING is_a      TYPE ty_pf
                is_b      TYPE ty_pf
      RETURNING VALUE(rv) TYPE abap_bool.
ENDCLASS.



CLASS ZCL_RAK_MIGRATOR IMPLEMENTATION.


  METHOD affinity.

*   ---- bilingual twins ------------------------------------------------
*   Checked on the label first and the field name second, because the legacy
*   screens are more consistent about the caption ('School Name English') than
*   about the technical name. Both sides must resolve to the same base and to
*   OPPOSITE languages, so 'School Name English' does not pair with
*   'Principal Name English'.
    DATA lv_ab TYPE string.
    DATA lv_al TYPE string.
    DATA lv_bb TYPE string.
    DATA lv_bl TYPE string.

    lang_base( EXPORTING iv_text = CONV string( is_a-zlabel )
               IMPORTING ev_base = lv_ab ev_lang = lv_al ).
    lang_base( EXPORTING iv_text = CONV string( is_b-zlabel )
               IMPORTING ev_base = lv_bb ev_lang = lv_bl ).
    IF lv_al IS INITIAL OR lv_bl IS INITIAL.
      lang_base( EXPORTING iv_text = CONV string( is_a-field_name )
                 IMPORTING ev_base = lv_ab ev_lang = lv_al ).
      lang_base( EXPORTING iv_text = CONV string( is_b-field_name )
                 IMPORTING ev_base = lv_bb ev_lang = lv_bl ).
    ENDIF.
    IF lv_al IS NOT INITIAL AND lv_bl IS NOT INITIAL
       AND lv_al <> lv_bl AND lv_ab = lv_bb AND lv_ab IS NOT INITIAL.
      rv = abap_true.
      RETURN.
    ENDIF.

*   ---- two ends of one range ------------------------------------------
*   Deliberately narrow. 'To' and 'End' are ordinary words, so a range pair
*   also has to be the SAME ftype and that ftype has to be one where a range
*   is meaningful. Without those two guards this fires on any two inputs whose
*   captions happen to contain 'from' and 'to'.
    IF is_a-ftype <> is_b-ftype.
      RETURN.
    ENDIF.
    CASE is_a-ftype.
      WHEN 'DATE' OR 'TIME' OR 'DATETIME' OR 'NUMBER' OR 'CURRENCY'.
      WHEN OTHERS.
        RETURN.
    ENDCASE.

    DATA(lv_as) = range_side( CONV string( is_a-zlabel ) ).
    DATA(lv_bs) = range_side( CONV string( is_b-zlabel ) ).
    IF lv_as IS INITIAL OR lv_bs IS INITIAL.
      lv_as = range_side( CONV string( is_a-field_name ) ).
      lv_bs = range_side( CONV string( is_b-field_name ) ).
    ENDIF.
    rv = xsdbool( lv_as = 'A' AND lv_bs = 'B' ).

  ENDMETHOD.


  METHOD apply_layout.

    DATA(jid) = to_upper( iv_journey ).

*   v7: the per-field WIDTH pass is gone. ZCL_RAK_JOURNEY_ENGINE sizes every
*   control from ctrl_width( ), keyed on ftype, and never reads the width
*   column - so the UPDATEs achieved nothing AND tripped the Studio lint
*   warning "Width is saved but the engine sizes controls by type" on every
*   single field. A migrated journey opened in Author with dozens of them.

*   v8: the step COLUMNS pass is gone the same way, and for the same reason.
*   In SimpleForm, columnsL arranges FormContainers, and a container is only
*   started by a core:Title - i.e. by a field carrying FGROUP. This projector
*   has never written FGROUP (it is in the "still not derivable" list at the
*   top of this class), so every migrated step had exactly one container and
*   the 2 that v7 so carefully computed had nothing to arrange. Every migrated
*   journey has rendered single-column since v1 regardless of that column.
*
*   Side-by-side is now done properly, per row instead of per step: fields are
*   paired into ROW: tokens in FGROUP, which the engine's row_key( ) reads and
*   renders as one HBox of label+control cells. Two passes, because order
*   matters - a fill pass running first would pair X with A_EN and orphan A_AR:
*
*     1. AFFINITY. Bilingual twins ('School Name English' / 'School Name
*        Arabic') and the two ends of one range ('Issued' / 'Expired'). These
*        are pairs the legacy screen already implied, and they are why the
*        developers asked for this.
*     2. FILL (iv_two_up). Any two remaining adjacent narrow controls. This is
*        what the dead columns = 2 was reaching for - halve the scroll on a
*        long step - except it now works.
*
*   Adjacency is by SEQNR within one step and one ZSECTION. Nothing is
*   reordered: a legacy screen puts its twins next to each other already, and
*   resequencing to force a pair would move fields the citizen reads in order.
    SELECT step_id FROM zrak_t_jny_step
      WHERE journey_id = @jid
      ORDER BY step_id
      INTO TABLE @DATA(lt_step).

    DATA lv_rowno TYPE i.
    DATA lt_pf    TYPE tt_pf.

    LOOP AT lt_step INTO DATA(s).

      SELECT field_name, seqnr, ftype, zlabel, zsection, fgroup, hidden, has_attach
        FROM zrak_t_jny_fld
        WHERE journey_id = @jid AND step_id = @s-step_id
        ORDER BY seqnr
        INTO TABLE @DATA(lt_raw).

      CLEAR lt_pf.
      LOOP AT lt_raw INTO DATA(r).
        APPEND VALUE #(
          field_name = r-field_name
          seqnr      = r-seqnr
          ftype      = r-ftype
          zlabel     = r-zlabel
          zsection   = r-zsection
*         An author's own FGROUP is a real container heading and is never
*         stomped. hidden fields stay out: the engine consumes a hidden row
*         follower without rendering it, so pairing one just leaves its
*         partner alone in a two-cell row. has_attach fields carry an
*         uploader under the control and need the full measure.
          elig       = xsdbool( pairable( r-ftype ) = abap_true
                               AND r-fgroup     IS INITIAL
                               AND r-hidden     = space
                               AND r-has_attach = space ) ) TO lt_pf.
      ENDLOOP.

      DO 2 TIMES.
        DATA(lv_fill) = xsdbool( sy-index = 2 ).
        IF lv_fill = abap_true AND iv_two_up = abap_false.
          EXIT.
        ENDIF.

        DATA(ix) = 1.
        WHILE ix < lines( lt_pf ).
          DATA(iy) = ix + 1.
          DATA(a)  = lt_pf[ ix ].
          DATA(b)  = lt_pf[ iy ].
          IF a-elig = abap_false OR b-elig = abap_false
             OR a-tok IS NOT INITIAL OR b-tok IS NOT INITIAL
             OR a-zsection <> b-zsection.
            ix = ix + 1.
            CONTINUE.
          ENDIF.
          IF lv_fill = abap_false AND affinity( is_a = a is_b = b ) = abap_false.
            ix = ix + 1.
            CONTINUE.
          ENDIF.

          lv_rowno = lv_rowno + 1.
*         No WIDTH/PAD. The formatting option left-aligns and pads on the RIGHT
*         for a numeric operand, so a 3-wide zero pad turned row 1 into 'R100'
*         and row 10 into 'R100' as well - two unrelated rows merging the moment
*         they land next to each other. Unpadded is unique by construction.
          DATA(tok) = |ROW:R{ lv_rowno }|.
          lt_pf[ ix ]-tok = tok.
          lt_pf[ iy ]-tok = tok.
          ev_pairs = ev_pairs + 1.
          ix = ix + 2.
        ENDWHILE.
      ENDDO.

      LOOP AT lt_pf INTO DATA(p) WHERE tok IS NOT INITIAL.
        UPDATE zrak_t_jny_fld
          SET fgroup = @p-tok
          WHERE journey_id = @jid AND step_id = @s-step_id
            AND field_name = @p-field_name.
      ENDLOOP.

*     1, always. Two paired fields are one HBox inside one FormElement, so the
*     container count is still 1 and columnsL still has nothing to arrange -
*     writing 2 here would only re-plant the confusion v8 removed.
      UPDATE zrak_t_jny_step
        SET columns = 1
        WHERE journey_id = @jid AND step_id = @s-step_id AND columns = 0.
    ENDLOOP.

    COMMIT WORK.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = jid ).

  ENDMETHOD.


  METHOD build_name_map.
    CLEAR: mt_used_names, mt_name.
    LOOP AT it_rows INTO DATA(r)
         WHERE ( role = c_interact OR role = c_display )
           AND is_col = abap_false
           AND not_ui <> 'X'.
      DATA(base) = norm_name( iv_name     = CONV #( r-field_name )
                              iv_is_table = xsdbool( r-ftype = 'TABLE' ) ).
      DATA(uniq) = base.
      DATA n TYPE i VALUE 0.
      WHILE line_exists( mt_used_names[ table_line = uniq ] ).
        n = n + 1.
        DATA(sfx)  = |{ n }|.
        DATA(keep) = COND i( WHEN strlen( base ) > c_name_max - strlen( sfx )
                             THEN c_name_max - strlen( sfx ) ELSE strlen( base ) ).
        uniq = |{ substring( val = base len = keep ) }{ sfx }|.
      ENDWHILE.
      INSERT uniq INTO TABLE mt_used_names.
      INSERT VALUE #( screen = r-screen_name orig = to_upper( r-field_name ) safe = uniq )
             INTO TABLE mt_name.
    ENDLOOP.
  ENDMETHOD.


  METHOD bind_table.
*   Every row verified against the serving DPC, not inferred from a name.
*   CUSTOMERJOURNEY unless marked otherwise.
    rt = VALUE #(
*     ---- parcels and property: ZCL_RAK_PROPERTY_API -------------------
*     TAKEN FROM THE CONTROLS' OWN READS, not from the entity-set names.
*     Each ShapeIt control issues one doRead for its list and that is the
*     binding:
*
*       RAKPARCELSELECTOR / RAK_PARCELS / ADDPARCELS  /PropertiesSet
*       RAK_PROPERTIES                                /PropertiesSet
*       RAK_TITLEDEED                                 /PropertiesSet
*       RAK_FLOORUNIT                                 /FloorSet
*
*     PARCEL IS NOT FINDPARCELSET, which is what this table said first and
*     which would have been a real defect. FindParcel has no
*     _GET_ENTITYSET at all - it is a CREATE_DEEP_ENTITY target that opens
*     a ZGCF "I cannot find my property" case, refuses when one is already
*     open, and takes attachments. Binding a selector to it would have
*     posted a case every time a citizen looked at a list.
*
*     The three parcel controls differ only by the Type filter, which is
*     why they share a row and carry it in DFILTER: PROPERTIESSET reads
*     Type = 'Parcel' / 'Unit', and omits the filter for 'All'.
      ( ftype = 'PARCEL'    api = 'PROPERTY' eset = 'PropertiesSet'
        dfilter = 'Type=Parcel' )
      ( ftype = 'PROPERTY'  api = 'PROPERTY' eset = 'PropertiesSet' )
      ( ftype = 'TITLEDEED' api = 'PROPERTY' eset = 'PropertiesSet' )

*     FLOORUNIT IS BOUND BUT NOT YET SERVEABLE. FloorSet has no
*     _GET_ENTITYSET either - it exists only inside GET_EXPANDED_ENTITYSET
*     under iv_entity_name = GC_FLOOR, and that method dereferences
*     IO_EXPAND->GET_CHILDREN( ), an object this layer cannot yet build.
*     The binding is written so the field is not silently blank and so the
*     gap is visible in config rather than only in a comment.
      ( ftype = 'FLOORUNIT' api = 'PROPERTY' eset = 'FloorSet' )

*     ---- tenancy: ZCL_RAK_TENANCY_API ---------------------------------
      ( ftype = 'CONTRACT'  api = 'TENANCY'  eset = 'LeaseContractSet' )

*     ---- signing: ZCL_RAK_SIGN_API, on ZUAEPASS_SRV -------------------
*     Keyed on Intreno throughout. The flow state is NOT in the entity set -
*     it is in SAPscript text CJ01/CJ20/CJ22/CJ23 - so the wrapper owns it,
*     not the config.
      ( ftype = 'SIGN'      api = 'SIGN'     eset = 'SignMethodSet' )

*     ---- value help: ZCL_RAK_VALUEHELP_API, on zega_fw_fnd_srv --------
*     DOMAIN is NOT derivable from /QNV/SB_UI_DEFIN - it lives in the
*     ShapeIt control's own JS - so it is carried here, the same way
*     ZRAK_M_MUNI_LOAD carries the M-code map. ZDE_EGA_ENTITY additionally
*     depends on FILTER_DOMAIN( ), which moves index 22 to the front and
*     drops value '29'; the wrapper reproduces that, not this table.
      ( ftype = 'SELECT'    api = 'VALUEHELP' eset = 'ValueHelpSet'
        domain = 'ZDE_EGA_ENTITY' )

*     M028's building dialog is ONE control with five dropdowns inside it,
*     not five configurable fields - so the five domains belong to the
*     wrapper that draws it, not to this table. Recorded here so they are
*     not re-derived, and they go in as constants when ZCL_RAK_VALUEHELP_API
*     is written:
*
*       ZCJ_CTYPE  construction types  TIVBDAROBJTYPET aotype IN 10BU/10SB/50PF
*       ZCJ_FTYPE  foundation types    TIVBDCHARACTT   005301/005302/005303
*       ZCJ_BTYPE  building types      TIVBDARFUNCT    aotype = DomainFilter '10BU'
*       ZCJ_BSYS   system types        TIVBDCHARACTT   003100..003104
*       ZCJ_MUSGT  structure types     TIVBDCHARACTT   >= MU00 AND < MU25
*
*     None of the five is a domain: VALUEHELPSET_GET_ENTITYSET finds no
*     fixed values, falls through to FILL_CUSTOM_DOMAIN( ) and selects from
*     the real-estate tables. ZCJ_BTYPE is the only one that consults
*     DomainFilter; the rest accept one and ignore it.
      ( ftype = 'BUILDINGS' api = 'VALUEHELP' eset = 'ValueHelpSet' )

*     ---- EPDA composites on journeys already migrated -----------------
*     ChemicalHistorySet returns the citizen's PREVIOUS declarations for a
*     permit and trade licence. E016/E017/E018 hand-built the dialog and
*     none of them carries this lookup.
*     ChemicalHistorySet is on zega_fw_fnd_srv, NOT on CUSTOMERJOURNEY -
*     its row type is ZCL_ZEGA_FW_FND_MPC=>TS_CHEMICALHISTORY. Naming the
*     wrong service here would send the column derivation to the wrong MPC.
      ( ftype = 'CHEMICALS' api = 'FND'      eset = 'ChemicalHistorySet' )
*     PortAccommodationSet and WorkersListSet are on a FIFTH service,
*     ZEGA_EPDA_MAPLET_I_SRV, which is in no repository read so far. The
*     binding is written so the field is not silently blank; the wrapper
*     behind it does not exist yet and must report that rather than
*     returning no rows.
      ( ftype = 'ACCOM'     api = 'MAPLET'   eset = 'PortAccommodationSet' ) ).
  ENDMETHOD.


  METHOD api_bind.
    DATA(lv_ft) = to_upper( iv_ftype ).

*   SELECT is the one ftype that is usually NOT a composite - most selects
*   are a search help or a domain and resolve through the engine's own F4.
*   Only the handful named here are ValueHelp-backed, so a bare SELECT must
*   fall through rather than pick up the ZDE_EGA_ENTITY row by its ftype.
    IF lv_ft = 'SELECT'.
      IF to_upper( iv_field ) NS 'ENTITY'.
        RETURN.
      ENDIF.
    ENDIF.

    READ TABLE bind_table( ) INTO DATA(ls_b) WITH KEY ftype = lv_ft.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv = |API:{ ls_b-api }:{ ls_b-eset }|.

*   THE SLOTS ARE POSITIONAL. PARSE_DIR( ) reads segment 3 as the domain
*   and segment 4 as the filter, so a row that has a filter and NO domain
*   still has to emit the empty domain slot - 'API:PROPERTY:PropertiesSet::
*   Type=Parcel'. Skipping it would deliver the filter as the domain and
*   the field would silently query the wrong thing, which is exactly the
*   class of failure this file is full of.
    IF ls_b-domain IS NOT INITIAL OR ls_b-dfilter IS NOT INITIAL.
      rv = |{ rv }:{ ls_b-domain }|.
      IF ls_b-dfilter IS NOT INITIAL.
        rv = |{ rv }:{ ls_b-dfilter }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD classify.
    DATA(ct) = to_upper( cs_row-control_type ).

    IF cs_row-not_ui = 'X'.
      cs_row-ftype = 'BACKEND'. cs_row-role = c_backend. RETURN.
    ENDIF.

    IF to_upper( cs_row-field_name ) CS 'LOGO' OR ct CS 'LOGO'
       OR ct CS 'BREADCRUMB' OR ct CS 'HEADER'.
      cs_row-ftype = 'IMAGE'. cs_row-role = c_decor. RETURN.
    ENDIF.

    CASE ct.
      WHEN 'INPUT' OR 'INPUT_DIRECTED'.
        cs_row-ftype = COND #( WHEN to_upper( cs_row-data1 ) CS 'EMAIL'  THEN 'EMAIL'
                               WHEN to_upper( cs_row-data1 ) CS 'TEL'    THEN 'PHONE'
                               WHEN to_upper( cs_row-data1 ) CS 'NUMBER' THEN 'NUMBER'
                               ELSE 'INPUT' ).
        cs_row-role = c_interact.
      WHEN 'COMBOBOX' OR 'DROPDOWN' OR 'ISUGGEST'.
        cs_row-ftype = 'SELECT'.  cs_row-role = c_interact.
      WHEN 'DATEPICKER'.  cs_row-ftype = 'DATE'.      cs_row-role = c_interact.
      WHEN 'DATERANGE'.   cs_row-ftype = 'DATERANGE'. cs_row-role = c_interact.
      WHEN 'TIMEPICKER'.  cs_row-ftype = 'TIME'.      cs_row-role = c_interact.
      WHEN 'TEXTAREA' OR 'QUICKVIEW'. cs_row-ftype = 'TEXTAREA'. cs_row-role = c_interact.
      WHEN 'CHECKBOX'.    cs_row-ftype = 'CHECKBOX'.  cs_row-role = c_interact.
      WHEN 'RADIOBUTTON'. cs_row-ftype = 'RADIO'.     cs_row-role = c_interact.
      WHEN 'STEPINPUT'.   cs_row-ftype = 'STEPPER'.   cs_row-role = c_interact.
      WHEN 'TBUTTON' OR 'SEGMENTED'. cs_row-ftype = 'SEGMENTED'. cs_row-role = c_interact.
      WHEN 'MTABLE' OR 'SMART_TABLE' OR 'CLIST'.        cs_row-ftype = 'TABLE'.        cs_row-role = c_interact.
      WHEN 'MTABLE_CADD'.   cs_row-ftype = 'TABLE_ADD'.    cs_row-role = c_interact.
      WHEN 'MTABLE_DELETE'. cs_row-ftype = 'TABLE_DELETE'. cs_row-role = c_interact.
      WHEN 'MTABLE_SEARCH' OR 'MTABLE_WITHIN_DAYS' OR 'MTABLE_DATERANGE'.
        cs_row-ftype = 'TABLE_FILTER'. cs_row-role = c_interact.
      WHEN 'CLIST_TEMPLATE'. cs_row-ftype = 'TABLE_TPL'.   cs_row-role = c_container.
      WHEN 'RAKUPLOADER' OR 'FILEUPLOADER'. cs_row-ftype = 'UPLOAD'. cs_row-role = c_interact.
      WHEN 'RAKPAY'.         cs_row-ftype = 'PAYFEE'. cs_row-role = c_interact.
      WHEN 'PERSON_SEARCH' OR 'OWNERS_SEARCH' OR 'STUDENT_SEARCH_MOE' OR 'SEARCH_FIELD' OR 'SH'.
        cs_row-ftype = 'SEARCH'. cs_row-role = c_interact.
      WHEN 'ACADEMIC_CALENDAR'. cs_row-ftype = 'CALENDAR'. cs_row-role = c_interact.
      WHEN 'ACADEMIC_HOURS'.    cs_row-ftype = 'HOURS'.    cs_row-role = c_interact.
      WHEN 'LABEL' OR 'EXTEXT'.  cs_row-ftype = 'DISPLAY'. cs_row-role = c_display.
      WHEN 'RAKREMAININGFEES'.   cs_row-ftype = 'FEES'.    cs_row-role = c_display.
      WHEN 'RAKHAPPY'.           cs_row-ftype = 'STATUS'.  cs_row-role = c_display.
      WHEN 'MESSAGE_STRIP'.      cs_row-ftype = 'MESSAGE'. cs_row-role = c_display.
      WHEN 'ICON'.               cs_row-ftype = 'ICON'.    cs_row-role = c_display.
      WHEN 'IMAGE'.              cs_row-ftype = 'IMAGE'.   cs_row-role = c_display.
      WHEN 'TILE'.               cs_row-ftype = 'TILE'.    cs_row-role = c_display.
      WHEN 'IFRAME'.             cs_row-ftype = 'IFRAME'.  cs_row-role = c_display.
      WHEN 'LINK'.               cs_row-ftype = 'LINK'.    cs_row-role = c_action.
      WHEN 'BUTTON' OR 'TEMPLATE_BUTTON'.
        cs_row-ftype = 'BUTTON'.
        cs_row-role  = COND #( WHEN is_nav_button( cs_row ) THEN c_chrome ELSE c_action ).
      WHEN 'RAKSTAGEBAR' OR 'STAGEBAR'. cs_row-ftype = 'STAGE'. cs_row-role = c_stage.
      WHEN 'VBOX'.  cs_row-ftype = 'VBOX'.   cs_row-role = c_container.
      WHEN 'HBOX'.  cs_row-ftype = 'HBOX'.   cs_row-role = c_container.
      WHEN 'PANEL'. cs_row-ftype = 'PANEL'.  cs_row-role = c_container.
      WHEN 'GRID'.  cs_row-ftype = 'GRID'.   cs_row-role = c_container.
      WHEN 'ITB'.   cs_row-ftype = 'TABBAR'. cs_row-role = c_container.
      WHEN 'ITF'.   cs_row-ftype = 'TAB'.    cs_row-role = c_container.
      WHEN 'DUMMY'. cs_row-ftype = 'SPACER'. cs_row-role = c_container.
      WHEN 'GENERIC_CSS' OR 'HSEPARATOR'. cs_row-ftype = ''. cs_row-role = c_decor.
      WHEN 'SCRIPT'.  cs_row-ftype = 'SCRIPT'.  cs_row-role = c_backend.
      WHEN ''.        cs_row-ftype = 'BACKEND'. cs_row-role = c_backend.

*     ---- ShapeIt composite controls ------------------------------------
*     Every control below fell through to WHEN OTHERS until now, which
*     turned a parcel selector into a text box and a signature pad into a
*     label - and left DEFAULTED set, so the count said "reviewed" when
*     nothing had been.
*
*     NONE of them may be mapped to 'TABLE', however grid-like they look.
*     The grid pipeline at the end of MIGRATE( ) keys off ftype 'TABLE',
*     calls GRID_SPEC( ) for the LEVEL_CON='T' descendants, and DROPS a
*     table that yields no usable columns. Checked against the export:
*     CHEMICALS_DETAILS, ACCOMODATIONS, RAK_BUILDINGCONTROL,
*     RAKPARCELSELECTOR, RAK_PARCELS, RAK_PROPERTIES and RAK_CONTRACTS
*     have ZERO 'T' children between them, because their rows come from an
*     entity set rather than from the legacy screen definition. Calling
*     them TABLE would delete them.
*
*     An ftype the engine does not draw yet is safe: ZCL_RAK_JOURNEY_RENDER
*     ends its field CASE on an input, which is exactly what WHEN OTHERS
*     produced before. So naming them here is never worse than the default,
*     and the config stops being wrong - the renderer branch and the domain
*     API can be added later WITHOUT re-migrating the journey.
      WHEN 'RAKPARCELSELECTOR' OR 'RAK_PARCELS' OR 'ADDPARCELS'.
        cs_row-ftype = 'PARCEL'.    cs_row-role = c_interact.
      WHEN 'RAK_PROPERTIES'.
        cs_row-ftype = 'PROPERTY'.  cs_row-role = c_interact.
      WHEN 'RAK_FLOORUNIT'.
        cs_row-ftype = 'FLOORUNIT'. cs_row-role = c_interact.
      WHEN 'RAK_TITLEDEED'.
        cs_row-ftype = 'TITLEDEED'. cs_row-role = c_interact.
      WHEN 'RAK_FINDCONTRACT' OR 'RAK_CONTRACTS'.
        cs_row-ftype = 'CONTRACT'.  cs_row-role = c_interact.
      WHEN 'RAK_SIGNCONTRACT' OR 'RAK_SIGNATURE' OR 'SIGNATURE' OR 'SIGN_CONTRACT'.
        cs_row-ftype = 'SIGN'.      cs_row-role = c_interact.
      WHEN 'RAK_BUILDINGCONTROL'.
        cs_row-ftype = 'BUILDINGS'. cs_row-role = c_interact.

*     A dropdown whose options ShapeIt decides client-side. It is still a
*     select here; the dependent behaviour belongs in a rule or on_change.
      WHEN 'RAKSELECTUSAGETYPE' OR 'RAK_PROJECTLIST' OR 'ENTITY_SELECT'.
        cs_row-ftype = 'SELECT'.    cs_row-role = c_interact.

*     THE ONE GROUP THAT WORKS ON FIRST MIGRATION. All five are the same
*     business-partner search - person and company alike, which is what
*     BusinessPartnerSet is - and the engine already draws it, fed by
*     ZCL_RAK_BP_SEARCH. No new renderer branch, no new API.
*
*     'SEARCH', NOT 'BP'. This said 'BP' first, on the strength of a
*     WHEN 'BP' in ZCL_RAK_JOURNEY_RENDER - which is in RENDER_POPUP( ),
*     the search DIALOG, not in the field renderer. A field typed 'BP'
*     reaches RENDER_ONE( )'s WHEN OTHERS and draws a plain input box: the
*     citizen gets a text field where a partner search belongs, and
*     nothing reports it. The field ftype that draws the search - id-type
*     dropdown, input, Search and Browse, wired to SEARCH_ and BPOPEN_ -
*     is 'SEARCH', and it is a BLOCK type, so it also gets its own row.
      WHEN 'RAK_SINGLEID' OR 'RAK_MULTIID' OR 'CUSTOMER_IDENTIFICATION'
        OR 'RAK_VALIDATE_RB' OR 'RAK_CONTRACTORCONTROL'.
        cs_row-ftype = 'SEARCH'.    cs_row-role = c_interact.

*     The journey's own progress, which the engine draws as the stage bar
*     already. Chrome, not a field the citizen fills.
      WHEN 'TRACKER'.
        cs_row-ftype = 'STAGE'.     cs_row-role = c_stage.

*     ---- composites on journeys ALREADY migrated -----------------------
*     CHEMICALS_DETAILS is backed by ChemicalHistorySet, which returns the
*     citizen's previous declarations for a permit and trade licence.
*     E016/E017/E018 hand-built its dialog because this branch did not
*     exist, and none of them carries the lookup. ACCOMODATIONS is the same
*     shape on E030/E130 (PortAccommodationSet + WorkersListSet), and
*     RAK_BOATCONTROL the same on NE001/NE002, not yet migrated.
      WHEN 'CHEMICALS_DETAILS'.
        cs_row-ftype = 'CHEMICALS'. cs_row-role = c_interact.
      WHEN 'ACCOMODATIONS'.
        cs_row-ftype = 'ACCOM'.     cs_row-role = c_interact.
      WHEN 'RAK_BOATCONTROL'.
        cs_row-ftype = 'BOATS'.     cs_row-role = c_interact.
*     DATA3 = 'X' is the multiple-files flag; ZRAK_E015_LOAD found this by
*     hand and mapped it to UPLOAD + ATTACH_MULTI. Same answer here.
      WHEN 'MASS_UPLOADER'.
        cs_row-ftype = 'UPLOAD'.    cs_row-role = c_interact.

      WHEN OTHERS.
        IF cs_row-technical_name IS NOT INITIAL OR cs_row-tosave = 'X'.
          cs_row-ftype = 'INPUT'.   cs_row-role = c_interact.
        ELSE.
          cs_row-ftype = 'DISPLAY'. cs_row-role = c_display.
        ENDIF.
        cs_row-defaulted = abap_true.
    ENDCASE.
  ENDMETHOD.


  METHOD collect_logic_rules.
    " Parse UI_FIELD_LOGICS on segmented trigger controls (TBUTTONs).
    "   grammar : comma-separated  TARGET-V-T (show) / TARGET-V-F (hide)
    "   source  : the segmented group the button belongs to (grp_sig)
    "   value   : the button's own field_name (= its option key)
    " Container targets are expanded to their projected descendant fields.
    " A bare token (no -V-T/-V-F, e.g. a COMBOBOX's 'VEHICLE_BOX') is
    " ignored - the DATA4/DATA5 path in collect_rules handles that with
    " the real trigger key.
    LOOP AT it_rows INTO DATA(t) WHERE screen_name = iv_screen
                                   AND ui_field_logics IS NOT INITIAL
                                   AND grp_sig IS NOT INITIAL.
      DATA(src) = seg_name( it_rows = it_rows iv_screen = iv_screen iv_grp = t-grp_sig ).
      IF src IS INITIAL. CONTINUE. ENDIF.
      DATA(val)  = to_upper( CONV string( t-field_name ) ).
      DATA(spec) = to_upper( CONV string( t-ui_field_logics ) ).
      REPLACE ALL OCCURRENCES OF ';' IN spec WITH ','.
      SPLIT spec AT ',' INTO TABLE DATA(lt_tok).

      LOOP AT lt_tok INTO DATA(tok).
        tok = condense( tok ).
        IF tok IS INITIAL. CONTINUE. ENDIF.

        DATA lv_act     TYPE string.
        DATA lv_tgt_raw TYPE string.
        CLEAR: lv_act, lv_tgt_raw.
        IF tok CP '*-V-T'.
          lv_act = 'SHOW'. lv_tgt_raw = substring( val = tok len = strlen( tok ) - 4 ).
        ELSEIF tok CP '*-V-F'.
          lv_act = 'HIDE'. lv_tgt_raw = substring( val = tok len = strlen( tok ) - 4 ).
        ELSE.
          CONTINUE.                                  " bare target -> DATA4/DATA5 path
        ENDIF.
        IF lv_tgt_raw IS INITIAL. CONTINUE. ENDIF.

        DATA(lt_tgt) = expand_target( it_rows = it_rows iv_screen = iv_screen iv_target = lv_tgt_raw ).
        LOOP AT lt_tgt INTO DATA(tf).
          IF tf IS INITIAL OR tf = src. CONTINUE. ENDIF.
          APPEND VALUE #( src_field = src src_op = 'EQ' src_value = val
                          action = lv_act tgt_field = tf ) TO rt.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD collect_rules.
    " Combobox-driven container visibility -> SHOW rules.
    " A VBOX/HBOX/PANEL whose DATA4 names a controlling field and whose
    " DATA5 lists the trigger key(s): every interactive/display descendant
    " is SHOWn when <controlling field> EQ <key>. This is the path that
    " reads the REAL vehicle-table trigger key ('2') from DATA5.
    LOOP AT it_rows INTO DATA(c) WHERE screen_name = iv_screen
                                   AND role = c_container
                                   AND data4 IS NOT INITIAL.
      DATA(src) = safe_of( iv_screen = iv_screen iv_orig = CONV #( c-data4 ) ).

      DATA(keys) = to_upper( CONV string( c-data5 ) ).
      REPLACE ALL OCCURRENCES OF ';' IN keys WITH ','.
      SPLIT keys AT ',' INTO TABLE DATA(lt_key).
      DELETE lt_key WHERE table_line IS INITIAL.
      IF lt_key IS INITIAL. APPEND 'X' TO lt_key. ENDIF.   " toggle-by-presence fallback

      LOOP AT it_rows INTO DATA(ch) WHERE screen_name = iv_screen
               AND ( role = c_interact OR role = c_display )
               AND is_col = abap_false.
        IF is_descendant( it_rows = it_rows is_row = ch iv_ancestor = CONV #( c-field_name ) ) = abap_false.
          CONTINUE.
        ENDIF.
        DATA(tgt) = safe_of( iv_screen = iv_screen iv_orig = CONV #( ch-field_name ) ).
        IF tgt = src. CONTINUE. ENDIF.
        LOOP AT lt_key INTO DATA(k).
          APPEND VALUE #( src_field = src src_op = 'EQ' src_value = k
                          action = 'SHOW' tgt_field = tgt ) TO rt.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD combobox_options.
    " Source: DATA1 = JSON array [{key,text}] (capped at 250 chars in QNV).
    " A DATA1 truncated at 250 chars deserializes into fragments; only a
    " well-formed array that opens '[' AND closes ']' is accepted, then only
    " rows with non-empty key AND text. Otherwise return nothing -> the
    " engine falls back to shlp (SH_NAME), the reliable path.
    DATA(d1) = condense( CONV string( is_row-data1 ) ).
    IF strlen( d1 ) < 2 OR d1(1) <> '['.
      RETURN.
    ENDIF.
    IF substring( val = d1 off = strlen( d1 ) - 1 len = 1 ) <> ']'.
      RETURN.
    ENDIF.
    DATA lt TYPE tt_kv.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = d1 CHANGING data = lt ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    LOOP AT lt INTO DATA(kv).
      IF kv-key IS NOT INITIAL AND kv-text IS NOT INITIAL.
        APPEND kv TO rt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD detect_chrome.
    CLEAR mt_chrome.
    TYPES: BEGIN OF ty_sig, sig TYPE string, screens TYPE i, END OF ty_sig.
    DATA lt      TYPE HASHED TABLE OF ty_sig WITH UNIQUE KEY sig.
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_rows INTO DATA(r) WHERE role = c_display.
      DATA(sig) = to_upper( r-field_name ).
      IF sig IS INITIAL. CONTINUE. ENDIF.
      DATA(key) = |{ sig }@{ r-screen_name }|.
      IF line_exists( lt_seen[ table_line = key ] ). CONTINUE. ENDIF.
      INSERT key INTO TABLE lt_seen.
      READ TABLE lt ASSIGNING FIELD-SYMBOL(<s>) WITH KEY sig = sig.
      IF sy-subrc <> 0.
        INSERT VALUE #( sig = sig screens = 1 ) INTO TABLE lt ASSIGNING <s>.
      ELSE.
        <s>-screens = <s>-screens + 1.
      ENDIF.
    ENDLOOP.

    LOOP AT it_rows INTO DATA(r2) WHERE role = c_display.
      DATA(sig2) = to_upper( r2-field_name ).
      READ TABLE lt INTO DATA(s2) WITH KEY sig = sig2.
      IF sy-subrc = 0 AND s2-screens >= 2.
        INSERT |{ r2-screen_name }/{ sig2 }| INTO TABLE mt_chrome. "#EC CI_SUBRC
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD expand_target.
    " Container target -> safe names of its projected interactive/display
    " descendant fields. A target that is itself a projected field -> its
    " own safe name. Anything else -> empty (rule dropped by caller).
    DATA(tu) = to_upper( iv_target ).
    LOOP AT it_rows INTO DATA(tr) WHERE screen_name = iv_screen.
      IF to_upper( tr-field_name ) <> tu. CONTINUE. ENDIF.
      IF tr-role = c_container.
        LOOP AT it_rows INTO DATA(d) WHERE screen_name = iv_screen.
          IF is_descendant( it_rows = it_rows is_row = d iv_ancestor = CONV #( tr-field_name ) ) = abap_false.
            CONTINUE.
          ENDIF.
          IF is_projected( it_rows = it_rows is_row = d ) = abap_false.
            CONTINUE.
          ENDIF.
          APPEND safe_of( iv_screen = iv_screen iv_orig = CONV #( d-field_name ) ) TO rt.
        ENDLOOP.
      ELSEIF is_projected( it_rows = it_rows is_row = tr ) = abap_true.
        APPEND safe_of( iv_screen = iv_screen iv_orig = CONV #( tr-field_name ) ) TO rt.
      ENDIF.
      EXIT.
    ENDLOOP.
    SORT rt. DELETE ADJACENT DUPLICATES FROM rt.
  ENDMETHOD.


  METHOD extract_rows.
    load_text_caches( ).

    DATA lt_src TYPE STANDARD TABLE OF /qnv/sb_ui_defin.
    SELECT * FROM /qnv/sb_ui_defin
      WHERE category = @iv_category
      INTO CORRESPONDING FIELDS OF TABLE @lt_src.

    SELECT screen_name, category, field_name, script FROM zdt_cj_scripts
      WHERE category = @iv_category INTO TABLE @DATA(lt_scr).
    SORT lt_scr BY screen_name field_name.

    DATA(lv_pat) = COND string( WHEN iv_screen_prefix IS NOT INITIAL THEN |{ iv_screen_prefix }_*|
                                WHEN iv_journey        IS NOT INITIAL THEN |N{ iv_journey }_*|
                                ELSE '' ).
    LOOP AT lt_src INTO DATA(ls).
      IF lv_pat IS NOT INITIAL AND ls-screen_name NP lv_pat.
        CONTINUE.
      ENDIF.
      DATA(r) = CORRESPONDING ty_row( ls ).
      r-seq_key = COND i( WHEN ls-sequence CO ' 0123456789' THEN ls-sequence ELSE 0 ).

      IF ls-value IS NOT INITIAL.
        r-text_en = VALUE #( mt_val[ spras = 'E' code = ls-value ]-txt DEFAULT CONV string( ls-value ) ).
        r-text_ar = VALUE #( mt_val[ spras = 'A' code = ls-value ]-txt OPTIONAL ).
      ENDIF.
      IF ls-label_con IS NOT INITIAL.
        r-lbl_en = VALUE #( mt_lbl[ spras = 'E' code = ls-label_con ]-txt DEFAULT CONV string( ls-label_con ) ).
        r-lbl_ar = VALUE #( mt_lbl[ spras = 'A' code = ls-label_con ]-txt OPTIONAL ).
      ENDIF.
      r-script = VALUE #( lt_scr[ screen_name = ls-screen_name field_name = ls-field_name ]-script OPTIONAL ).

      DATA(ct) = to_upper( ls-control_type ).
      IF ct = 'TBUTTON' OR ct = 'RADIOBUTTON'.
        r-grp_sig = to_upper( ls-data1 ).
      ENDIF.
      r-is_col = xsdbool( to_upper( ls-level_con ) = 'T' ).

      classify( CHANGING cs_row = r ).
      APPEND r TO rt.
    ENDLOOP.

    SORT rt BY screen_name seq_key.
  ENDMETHOD.


  METHOD grid_spec.
*   Legacy table columns were already detected (is_col / LEVEL_CON='T') and
*   staged into ZRAK_T_MIG_RAW, then thrown away. They carry everything the
*   engine's grid_cols( ) needs, so build the spec instead of discarding it.
*   Column control types collapse to INPUT / NUMBER / DATE: the engine's
*   SELECT column resolves through rollname, and this migrator writes shlp
*   (rollname would route down the empty value-table path), so a choice
*   column degrades to free text rather than to an empty dropdown.
    TYPES: BEGIN OF ty_col,
             seq  TYPE i,
             spec TYPE string,
           END OF ty_col.
    DATA lt_col      TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.
    DATA lt_seen     TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_any_edit TYPE abap_bool.

    LOOP AT it_rows INTO DATA(c) WHERE screen_name = is_row-screen_name
                                   AND is_col      = abap_true.
      IF c-role <> c_interact AND c-role <> c_display.
        CONTINUE.
      ENDIF.
      IF is_descendant( it_rows     = it_rows
                        is_row      = c
                        iv_ancestor = CONV #( is_row-field_name ) ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(cn) = norm_name( iv_name = CONV #( c-field_name ) ).
      IF cn IS INITIAL OR line_exists( lt_seen[ table_line = cn ] ).
        CONTINUE.
      ENDIF.
      INSERT cn INTO TABLE lt_seen.

      DATA lv_lbl TYPE string.
      lv_lbl = COND string( WHEN c-lbl_en  IS NOT INITIAL THEN c-lbl_en
                            WHEN c-text_en IS NOT INITIAL THEN c-text_en
                            ELSE pretty( cn ) ).
      IF is_code_label( lv_lbl ) = abap_true.
        lv_lbl = pretty( cn ).
      ENDIF.
*     ':' and '|' are the spec's own delimiters - a label carrying either
*     would silently shift every following column.
      REPLACE ALL OCCURRENCES OF ':' IN lv_lbl WITH ` `.
      REPLACE ALL OCCURRENCES OF '|' IN lv_lbl WITH ` `.
      lv_lbl = condense( lv_lbl ).
      IF lv_lbl IS INITIAL.
        lv_lbl = pretty( cn ).
      ENDIF.

      DATA(ctp) = COND string( WHEN c-ftype = 'NUMBER' THEN 'NUMBER'
                               WHEN c-ftype = 'DATE' OR c-ftype = 'DATERANGE' THEN 'DATE'
                               ELSE 'INPUT' ).

      DATA lv_cseq TYPE i.
      DATA(lv_ls) = condense( CONV string( c-list_sequence ) ).
      IF lv_ls IS NOT INITIAL AND lv_ls CO '0123456789'.
        lv_cseq = CONV i( lv_ls ).
      ELSE.
        lv_cseq = c-seq_key.
      ENDIF.

      IF c-role = c_interact.
        lv_any_edit = abap_true.
      ENDIF.
      APPEND VALUE #( seq = lv_cseq spec = |{ cn }:{ lv_lbl }:{ ctp }| ) TO lt_col.
*     The bridge maps at most 30 UI_TABLE_COLUMNn slots.
      IF lines( lt_col ) >= 30.
        EXIT.
      ENDIF.
    ENDLOOP.

    SORT lt_col BY seq.
    LOOP AT lt_col INTO DATA(x).
      ev_spec = COND string( WHEN ev_spec IS INITIAL THEN x-spec
                             ELSE |{ ev_spec }\|{ x-spec }| ).
    ENDLOOP.
    IF ev_spec IS INITIAL.
      RETURN.
    ENDIF.

*   DATA3 is the legacy select mode - SingleSelectLeft, SingleSelectMaster,
*   MultiSelect and friends. A list that declares one is something the citizen
*   PICKS from, so it gets a selection column and stops being editable.
    DATA(lv_d3) = to_upper( condense( CONV string( is_row-data3 ) ) ).
    DATA lv_mode TYPE string.
    IF lv_d3 CS 'MULTI'.
      lv_mode = 'MULTI'.
    ELSEIF lv_d3 CS 'SINGLE'.
      lv_mode = 'SINGLE'.
    ENDIF.

    IF lv_mode IS NOT INITIAL.
      DATA(lv_base) = to_upper( norm_name( iv_name = CONV #( is_row-field_name ) ) ).
      IF strlen( lv_base ) > 20.
        lv_base = lv_base(20).
      ENDIF.
*     _PICK, not _SEL: the engine reserves every name ending _SEL for the row
*     flag it keeps inside the grid, and is_scratch( ) rejects an authored field
*     with that suffix.
      ev_sel_tgt = |{ lv_base }_PICK|.

*     SEL: goes FIRST. DEFAULT_VAL is a character field and a spec longer than it
*     truncates silently, so the expendable part has to be the tail - losing a
*     column beats losing the whole selection column.
      ev_spec = |SEL:{ lv_mode }:{ ev_sel_tgt }\|{ ev_spec }|.
    ENDIF.

*   Read-only when the citizen picks rather than types: an explicit select mode,
*   or no interactive column anywhere in the table.
    ev_readonly = xsdbool( lv_mode IS NOT INITIAL OR lv_any_edit = abap_false ).
  ENDMETHOD.


  METHOD is_code_label.
    DATA(t) = condense( to_upper( iv_text ) ).
    IF t IS INITIAL. rv = abap_true. RETURN. ENDIF.
    FIND REGEX `^(LABEL|ERROR|FIELD|LBL|MSG|TEXT)\s*[0-9]+$` IN t.
    IF sy-subrc = 0. rv = abap_true. RETURN. ENDIF.
    IF strlen( t ) <= 3 AND t CA '0123456789'. rv = abap_true. RETURN. ENDIF.
  ENDMETHOD.


  METHOD is_descendant.
    DATA(pc) = to_upper( is_row-parent_container ).
    DO 20 TIMES.
      IF pc IS INITIAL. RETURN. ENDIF.
      IF pc = to_upper( iv_ancestor ). rv = abap_true. RETURN. ENDIF.
      READ TABLE it_rows INTO DATA(p)
        WITH KEY screen_name = is_row-screen_name field_name = pc.
      IF sy-subrc <> 0. RETURN. ENDIF.
      pc = to_upper( p-parent_container ).
    ENDDO.
  ENDMETHOD.


  METHOD is_in_table.
    DATA(pc) = to_upper( is_row-parent_container ).
    DO 20 TIMES.
      IF pc IS INITIAL. RETURN. ENDIF.
      READ TABLE it_rows INTO DATA(p)
        WITH KEY screen_name = is_row-screen_name field_name = pc.
      IF sy-subrc <> 0. RETURN. ENDIF.
      IF p-ftype = 'TABLE' OR p-ftype = 'TABLE_TPL'. rv = abap_true. RETURN. ENDIF.
      pc = to_upper( p-parent_container ).
    ENDDO.
  ENDMETHOD.


  METHOD is_nav_button.
    DATA(ev) = to_upper( is_row-event ).
    rv = xsdbool( ev = 'SAVE' OR ev = 'SAVEDRAFT' OR ev = 'SAVEDRAFTHOME'
               OR ev = 'DELETE' OR ev = 'HOME'
               OR to_upper( is_row-data1 ) CS 'ZFM_EGA_CJ_FW'
               OR to_upper( is_row-data2 ) CS 'ZFM_EGA_CJ_FW' ).
  ENDMETHOD.


  METHOD is_notice.
    DATA(t) = condense( iv_text ).
    IF t IS INITIAL.
      RETURN.
    ENDIF.
    IF t(1) = '*' OR t CS '!'.
      rv = abap_true. RETURN.
    ENDIF.
*   NOT "t CS 'MB'". CS is case-INSENSITIVE, so it matched "NuMBer" and
*   turned License Number / Telephone Number / Emirates id Number into
*   guidance text. Only a SIZE reads as a notice: digits then MB/KB.
    FIND REGEX `[0-9]\s*(MB|KB)` IN t IGNORING CASE.
    IF sy-subrc = 0.
      rv = abap_true. RETURN.
    ENDIF.
    IF strlen( t ) > 34.
      rv = abap_true. RETURN.
    ENDIF.
    SPLIT t AT ` ` INTO TABLE DATA(lt_w).
    DELETE lt_w WHERE table_line IS INITIAL.
    IF lines( lt_w ) > 5.
      rv = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_projected.
    " Mirrors the field-loop gate: exactly the rows that become _FLD rows.
    IF is_row-role <> c_interact AND is_row-role <> c_display. RETURN. ENDIF.
    IF is_row-is_col = abap_true. RETURN. ENDIF.
    IF is_in_table( it_rows = it_rows is_row = is_row ) = abap_true. RETURN. ENDIF.
    DATA(rk) = |{ is_row-screen_name }/{ to_upper( is_row-field_name ) }|.
    IF line_exists( mt_chrome[ table_line = rk ] ). RETURN. ENDIF.
    IF is_row-role = c_display AND line_exists( mt_consumed[ table_line = rk ] ). RETURN. ENDIF.
    rv = abap_true.
  ENDMETHOD.


  METHOD journey_of_screen.
    IF strlen( iv_screen ) > 1 AND iv_screen(1) = 'N'.
      SPLIT iv_screen+1 AT '_' INTO rv DATA(rest).
    ENDIF.
  ENDMETHOD.


  METHOD lang_base.

    CLEAR ev_base.
    CLEAR ev_lang.

    DATA(t) = to_upper( iv_text ).
    REPLACE ALL OCCURRENCES OF '_' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF '-' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF '(' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF ')' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF ':' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF '/' IN t WITH ' '.
    CONDENSE t.
    IF t IS INITIAL.
      RETURN.
    ENDIF.

    SPLIT t AT ' ' INTO TABLE DATA(lt_w).
    DELETE lt_w WHERE table_line IS INITIAL.
    DATA(n) = lines( lt_w ).
*   A one-word text cannot be a twin: stripping the marker would leave no base
*   to compare, and every EN field would then pair with every AR field.
    IF n < 2.
      RETURN.
    ENDIF.

    DATA(lastw) = lt_w[ n ].
    CASE lastw.
      WHEN 'ENGLISH' OR 'ENGLISHNAME' OR 'ENG' OR 'EN' OR 'LATIN'.
        ev_lang = 'EN'.
      WHEN 'ARABIC' OR 'ARABICNAME' OR 'ARB' OR 'AR' OR 'ARABI'.
        ev_lang = 'AR'.
      WHEN OTHERS.
        RETURN.
    ENDCASE.

    DELETE lt_w INDEX n.
    CONCATENATE LINES OF lt_w INTO ev_base SEPARATED BY ' '.

  ENDMETHOD.


  METHOD list_candidates.
    SELECT category, screen_name FROM /qnv/sb_ui_defin INTO TABLE @DATA(lt_all).
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT lt_all INTO DATA(ls).
      DATA(j) = journey_of_screen( CONV #( ls-screen_name ) ).
      IF j IS INITIAL. CONTINUE. ENDIF.
      READ TABLE rt WITH KEY category = ls-category journey = j ASSIGNING FIELD-SYMBOL(<c>).
      IF sy-subrc <> 0. APPEND VALUE #( category = ls-category journey = j ) TO rt ASSIGNING <c>. ENDIF.
      <c>-rows = <c>-rows + 1.
      DATA(sk) = |{ ls-category }/{ j }/{ ls-screen_name }|.
      IF NOT line_exists( lt_seen[ table_line = sk ] ).
        INSERT sk INTO TABLE lt_seen. <c>-screens = <c>-screens + 1.
      ENDIF.
    ENDLOOP.
    SORT rt BY category journey.
  ENDMETHOD.


  METHOD badi_probe.
    DATA ls_hdr TYPE /qnv/sbuild_getheader_st.
    DATA lt_def TYPE /qnv/sbuild_definition_tt.
    DATA lt_att TYPE /qnv/sbuild_attachments_tt.

*   Seeded exactly as ZCL_RAK_QNV_BRIDGE->READ( ) seeds it, because the
*   BAdI answers BY FIELD NAME: a row it is not given is a branch that
*   never fires.
    LOOP AT it_rows INTO DATA(ls_r) WHERE screen_name = iv_screen.
      DATA(lv_f) = to_upper( ls_r-field_name ).
      IF lv_f IS INITIAL OR line_exists( lt_def[ fieldname = lv_f ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( fieldname     = lv_f
                      technicalname = COND #( WHEN ls_r-technical_name IS NOT INITIAL
                                              THEN ls_r-technical_name ELSE lv_f )
                      screenname    = iv_screen
                      categoryname  = iv_category ) TO lt_def.
    ENDLOOP.

*   THE STAGES ROW IS NOT IN THE EXPORT and has to be asked for by name.
*   ZCL_EGA_CJ_ENH_IMPL_E028->READ does
*
*       WHEN 'STAGES'. <definition>-additionaldata3 = 'Lease Details,...'
*
*   so with no row called STAGES the step names never come back at all.
    IF NOT line_exists( lt_def[ fieldname = 'STAGES' ] ).
      APPEND VALUE #( fieldname     = 'STAGES'
                      technicalname = 'STAGES'
                      screenname    = iv_screen
                      categoryname  = iv_category ) TO lt_def.
    ENDIF.

*   PARAM2 names the journey when PARAM1 misses, which it does here -
*   there is no case and no draft at migrate time, and that is the normal
*   cold-read shape the bridge already relies on.
    ls_hdr-param2       = iv_journey.
    ls_hdr-param5       = 'CJS'.
    ls_hdr-screenname   = iv_screen.
    ls_hdr-categoryname = iv_category.

    TRY.
        CALL FUNCTION c_fm_read
          CHANGING cs_header     = ls_hdr
                   ct_definition = lt_def
                   ct_attacments = lt_att.
      CATCH cx_root ##NO_HANDLER.
*       A journey whose BAdI is not registered, or a screen it refuses,
*       migrates exactly as it did before this method existed.
        RETURN.
    ENDTRY.

    mv_badi_ok = abap_true.

    LOOP AT lt_def INTO DATA(ls_d).
      DATA(lv_name) = to_upper( CONV string( ls_d-fieldname ) ).

*     The stage list, taken from the FIRST screen that answers one. Every
*     screen of a journey returns the same list, and asking each of them
*     to overwrite it would only let a blank one win.
      IF lv_name = 'STAGES' AND mt_stage IS INITIAL.
        ASSIGN COMPONENT 'ADDITIONALDATA3' OF STRUCTURE ls_d TO FIELD-SYMBOL(<st>).
        IF sy-subrc = 0 AND <st> IS NOT INITIAL.
          SPLIT CONV string( <st> ) AT ',' INTO TABLE mt_stage.
        ENDIF.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT 'MANDATORY' OF STRUCTURE ls_d TO FIELD-SYMBOL(<mn>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( screen = iv_screen
                      field  = lv_name
                      mand   = xsdbool( <mn> = 'X' OR <mn> = 'x' ) )
             INTO TABLE mt_badi. "#EC CI_SUBRC
    ENDLOOP.
  ENDMETHOD.


  METHOD is_confirmation.
*   CONSERVATIVE ON PURPOSE. A screen with ANY interactive row is never a
*   confirmation page, whatever it is called - so a real step that happens
*   to display an application number keeps its inputs and survives. Only a
*   screen that asks for nothing AND announces a submitted application is
*   dropped.
    DATA lv_marker TYPE abap_bool.

    LOOP AT it_rows INTO DATA(ls) WHERE screen_name = iv_screen.
      IF ls-role = c_interact.
        RETURN.
      ENDIF.
      DATA(lv_n) = to_upper( ls-field_name ).
      IF lv_n CS 'APPLICATION_NUMBER' OR lv_n CS 'NOTIFICATION_SENT'
         OR lv_n CS 'APPLICATION_TYPE'.
        lv_marker = abap_true.
      ENDIF.
    ENDLOOP.

    rv = lv_marker.
  ENDMETHOD.


  METHOD load_text_caches.
    CLEAR: mt_val, mt_lbl.
    SELECT spras, value_code, value_desc FROM /qnv/sb_valuet INTO TABLE @DATA(lt_v).
    LOOP AT lt_v INTO DATA(lv).
      INSERT VALUE #( spras = lv-spras code = lv-value_code txt = lv-value_desc ) INTO TABLE mt_val. "#EC CI_SUBRC
    ENDLOOP.
    SELECT spras, label_code, labeltext FROM /qnv/sb_labelt INTO TABLE @DATA(lt_l).
    LOOP AT lt_l INTO DATA(ll).
      INSERT VALUE #( spras = ll-spras code = ll-label_code txt = ll-labeltext ) INTO TABLE mt_lbl. "#EC CI_SUBRC
    ENDLOOP.
  ENDMETHOD.


  METHOD migrate.
    CLEAR: ev_ok, ev_msg, et_report.

    " ---- ENFORCE the UI journey-name prefix (never the raw legacy code)
    DATA(pfx)  = COND string( WHEN iv_prefix IS INITIAL THEN c_sandbox ELSE iv_prefix ).
    DATA(jid)  = to_upper( pfx && iv_cjs_id ).
*   The journey id is CHAR(30) and keeps the long prefix; the TILE is a
*   separate CHAR(4) namespace and must be built, not concatenated.
    DATA(tile) = tile_code( iv_journey = iv_tile iv_prefix = iv_tile_pfx ).
    IF jid IS INITIAL OR tile IS INITIAL.
      ev_msg = 'CJS journey ID and tile code are required'. RETURN.
    ENDIF.
    IF strlen( tile ) > c_tile_len.
      ev_msg = |Tile { tile } is longer than { c_tile_len } characters - | &&
               |ZDE_CJ_JOURNEYID would truncate it. Shorten the tile prefix.|.
      RETURN.
    ENDIF.
    SELECT SINGLE @abap_true FROM zrak_t_jny WHERE journey_id = @jid INTO @DATA(lv_ex).
    IF lv_ex = abap_true. ev_msg = |{ jid } already exists - teardown first|. RETURN. ENDIF.

*   ---- the portal tables are the LIVE portal's, so every write below has to
*   prove the row is ours first. Nothing here is a MODIFY over an unknown key.
    DATA(lv_tile4) = CONV zrak_t_jny-tile_code( tile ).
    SELECT SINGLE journey_id FROM zrak_t_jny WHERE tile_code = @lv_tile4
      INTO @DATA(lv_towner).
    IF sy-subrc = 0.
      ev_msg = |Tile { tile } is already used by { lv_towner } - two journeys | &&
               |cannot share one portal code. Teardown first, or migrate under | &&
               |a different tile prefix.|.
      RETURN.
    ENDIF.
    SELECT SINGLE @abap_true FROM zega_t_cj_id WHERE journeyid = @lv_tile4
      INTO @DATA(lv_tex).
    IF lv_tex = abap_true.
      ev_msg = |Tile { tile } exists in the portal and was not created by CJS - | &&
               |refusing to write over a live journey.|.
      RETURN.
    ENDIF.

*   ---- and the group it will hang under. A group CJS did not create keeps
*   its own rows: this is the check that '901' needed and did not have.
    DATA(lv_dept4) = CONV zega_t_cj_grp-department( iv_dept ).
    DATA(lv_main4) = CONV zega_t_cj_grp-journeyid( iv_main ).
    IF lv_main4 IS INITIAL.
      ev_msg = 'Portal group code (IV_MAIN) is required'. RETURN.
    ENDIF.
    IF strlen( iv_main ) > c_tile_len.
      ev_msg = |Portal group { iv_main } is longer than { c_tile_len } characters | &&
               |- it would be truncated to { lv_main4 }.|.
      RETURN.
    ENDIF.
    DATA lv_alien TYPE i.
    SELECT journeyid FROM zega_t_cj_grp WHERE groupid = @lv_main4
      INTO TABLE @DATA(lt_kids).
    IF lt_kids IS NOT INITIAL.
      SELECT tile_code FROM zrak_t_jny WHERE tile_code <> @space
        INTO TABLE @DATA(lt_ours).
      LOOP AT lt_kids INTO DATA(lv_kid).
        IF NOT line_exists( lt_ours[ table_line = lv_kid ] ).
          lv_alien = lv_alien + 1.
        ENDIF.
      ENDLOOP.
    ENDIF.
    IF lv_alien > 0.
      ev_msg = |Portal group { lv_main4 } already carries { lv_alien } journey(s) | &&
               |CJS did not migrate - it is a live group, and relabelling it would | &&
               |rename what is already on the citizen's home screen. Pass a free | &&
               |code in IV_MAIN (the default is { c_main_grp }).|.
      RETURN.
    ENDIF.

    DATA(lt) = extract_rows( iv_category = iv_category iv_journey = iv_journey
                             iv_screen_prefix = iv_screen_prefix ).
    IF lt IS INITIAL.
      ev_msg = |No config rows for { iv_category } / | &&
               COND string( WHEN iv_screen_prefix IS NOT INITIAL THEN iv_screen_prefix ELSE iv_journey ).
      RETURN.
    ENDIF.

    stage_rows( iv_cjs_id = jid it_rows = lt ).

    " cj_type DROPPED. bknd_journey carries the raw BE code (one-code model).
    INSERT zrak_t_jny FROM @( VALUE #(
      mandt = sy-mandt journey_id = jid title = iv_title title_ar = iv_title_ar
      layout_mode = 'WIZARD' theme_variant = 'PORTAL'
      accent_type = 'Emphasized' brand_color = 'rgb(196,30,38)' navy_color = 'rgb(16,35,62)'
      density = 'Cozy'
      subtitle    = |Apply and track your request — one guided flow|
      subtitle_ar = |قدّم طلبك وتابعه في مسار واحد|
      show_actions = 'X' active = 'X'
      handler_class = to_upper( iv_handler )
*     See C_FM_POST. A journey migrated with BKND_ACTIVE blank and no
*     function modules is a journey that silently discards the citizen's
*     application at submit.
      bknd_active  = COND #( WHEN iv_bknd_active = abap_true THEN 'X' ELSE ' ' )
      bknd_fm_post = COND #( WHEN iv_bknd_active = abap_true THEN c_fm_post )
      bknd_fm_read = COND #( WHEN iv_bknd_active = abap_true THEN c_fm_read )
      bknd_category = iv_category bknd_journey = iv_journey tile_code = tile ) ).

    " ---- name map + quality passes FIRST (steps, rules & fields use them)
    build_name_map( lt ).
    pair_labels( lt ).      " fold LABEL captions into their controls
    detect_chrome( lt ).    " flag repeated header/logo/breadcrumb rows

    " ---- optional caller-supplied step titles ("EN^AR|EN^AR|...") -------
    " Positional, one per screen; blank entry / short list -> auto-derive.
    DATA lt_step_ovr TYPE string_table.
    IF iv_steps IS NOT INITIAL.
      SPLIT iv_steps AT '|' INTO TABLE lt_step_ovr.
    ENDIF.

    " ---- screens -> steps -----------------------------------------------
    DATA lt_screens TYPE SORTED TABLE OF /qnv/sb_ui_defin-screen_name WITH UNIQUE KEY table_line.
    LOOP AT lt INTO DATA(l0). INSERT l0-screen_name INTO TABLE lt_screens. ENDLOOP.

*   THE LAST LEGACY SCREEN IS USUALLY NOT A STEP. NE028_1_4 and its
*   equivalents carry E003_APPLICATION_NUMBER, E003_APPLICATION_TYPE and a
*   "notification sent" message - a confirmation page the legacy framework
*   shows AFTER the post. The engine appends its own Review-and-submit step
*   below, so keeping this one gives every migrated journey two terminal
*   steps, the first of which asks the citizen to submit a screen whose
*   only content is a case number that does not exist yet. Every feeder
*   drops it by hand; this does it by rule.
    DATA lv_conf_drp TYPE i.
    DATA lt_conf     TYPE string_table.
    LOOP AT lt_screens INTO DATA(lv_cs).
      IF is_confirmation( it_rows = lt iv_screen = CONV #( lv_cs ) ) = abap_true.
        APPEND CONV string( lv_cs ) TO lt_conf.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_conf INTO DATA(lv_cd).
      DELETE lt_screens WHERE table_line = lv_cd.
      lv_conf_drp = lv_conf_drp + 1.
    ENDLOOP.

*   ---- ask the BAdI what this screen really looks like ---------------
*   After the confirmation drop, so a screen that is not going to be a
*   step is not asked about either.
*   ONE CALL PER JOURNEY BY DEFAULT, not one per screen. Each probe is a
*   real backend READ through the legacy BAdI, and fifteen journeys of
*   four screens is sixty of them in a single batch - which is what turned
*   a migration that used to finish while you watched into one that looks
*   hung.
*
*   The stage list is the same on every screen of a journey, so the first
*   screen answers it and the rest add nothing. What the rest WOULD add is
*   per-screen MANDATORY, and that is what IV_BADI_ALL buys - useful, and
*   priced honestly rather than charged to everyone by default.
    CLEAR: mt_badi, mt_stage, mv_badi_ok.
    IF iv_badi = abap_true.
      LOOP AT lt_screens INTO DATA(lv_ps).
        badi_probe( iv_category = iv_category
                    iv_journey  = iv_journey
                    iv_screen   = CONV #( lv_ps )
                    it_rows     = lt ).
        IF iv_badi_all = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

*   THE STAGE LIST IS USED ONLY WHEN IT LINES UP. E028's list names three
*   stages for a journey whose first screen is a licence picker the legacy
*   framework does not count as one - so a positional map from step 1
*   would put "Documents" on the parcel step and be confidently wrong.
*   Equal lengths is the one case where the mapping cannot be ambiguous;
*   anything else is reported and the derived titles stand.
    DATA(lv_stage_fit) = xsdbool( mt_stage IS NOT INITIAL
                                  AND lines( mt_stage ) = lines( lt_screens ) ).

    DATA lv_stepno TYPE i.
    DATA lv_ten    TYPE string.
    DATA lv_tar    TYPE string.
    LOOP AT lt_screens INTO DATA(lv_scr).
      lv_stepno = lv_stepno + 1.
      DATA(sid) = |STP{ lv_stepno }|.
      CLEAR: lv_ten, lv_tar.

      " 1) caller override wins (blank entry falls through to auto-derive)
      IF line_exists( lt_step_ovr[ lv_stepno ] ).
        DATA(ovr) = condense( lt_step_ovr[ lv_stepno ] ).
        IF ovr CS '^'.
          SPLIT ovr AT '^' INTO lv_ten lv_tar.
          lv_ten = condense( lv_ten ).
          lv_tar = condense( lv_tar ).
        ELSE.
          lv_ten = ovr.
        ENDIF.
      ENDIF.

      " 1.5) the legacy STAGES list - the names the citizen actually reads
      IF lv_ten IS INITIAL AND lv_stage_fit = abap_true.
        lv_ten = condense( VALUE #( mt_stage[ lv_stepno ] OPTIONAL ) ).
      ENDIF.

      " 2) else derive the section heading (chrome-aware)
      IF lv_ten IS INITIAL.
        step_title( EXPORTING it_rows   = lt
                              iv_screen = lv_scr
                              iv_no     = lv_stepno
                    IMPORTING ev_en     = lv_ten
                              ev_ar     = lv_tar ).
      ENDIF.

      " 3) last resort - name the step from its CONTENT, not from the first
      "    display row (which produced "...allowed size - 3MB" titles)
      IF lv_ten IS INITIAL
         OR is_code_label( lv_ten ) = abap_true
         OR is_notice( lv_ten ) = abap_true.
        lv_ten = step_from_content( it_rows   = lt
                                    iv_screen = lv_scr
                                    iv_no     = lv_stepno
                                    iv_last   = xsdbool( lv_stepno = lines( lt_screens ) ) ).
        CLEAR lv_tar.
      ENDIF.

      INSERT zrak_t_jny_step FROM @( VALUE #(
        mandt = sy-mandt journey_id = jid step_id = sid seqnr = lv_stepno * 10
        title = lv_ten title_ar = lv_tar icon = step_icon( iv_title = lv_ten it_rows = lt iv_screen = lv_scr )
*       columns = 0 ON PURPOSE. apply_layout( ) decides 1 vs 2 at the end and
*       only touches rows still at 0 - writing 1 here made that pass dead code
*       and every migrated journey was single-column for good.
        columns = 0
        bknd_screen = lv_scr ) ).
      APPEND VALUE #( screen = lv_scr step_id = sid title = lv_ten ) TO et_report.
    ENDLOOP.

*   ---- REVIEW step ----------------------------------------------------
*   Listed as "not derivable" in this class's own header since v6, and it
*   is not derivable - the legacy screens have no review page, because
*   ShapeIt never had one. But the engine does: ftype REVIEW walks
*   MS_CONFIG-STEPS itself and renders every OTHER step's filled fields,
*   skipping the display-only types and anything a rule has hidden. So the
*   step needs exactly one field and no configuration at all - no labels,
*   no column spec, nothing to maintain.
*
*   It is appended AFTER the screen loop so it is always last, and it
*   carries NO BKND_SCREEN: there is no legacy screen behind it, so it must
*   never post. A step with a blank bknd_screen renders and validates and
*   creates nothing, which everywhere else in CJS is a bug - here it is the
*   whole point, and it is written down so nobody "fixes" it by filling the
*   column in.
    lv_stepno = lv_stepno + 1.
    DATA(lv_rvsid) = |STP{ lv_stepno }|.

    INSERT zrak_t_jny_step FROM @( VALUE #(
      mandt = sy-mandt journey_id = jid step_id = lv_rvsid seqnr = lv_stepno * 10
      title    = 'Review and submit'
      title_ar = 'مراجعة وإرسال'
      icon     = 'sap-icon://survey'
      columns  = 0
      bknd_screen = '' ) ).

    INSERT zrak_t_jny_fld FROM @( VALUE #(
      mandt = sy-mandt journey_id = jid step_id = lv_rvsid
      field_name = 'REVIEW' seqnr = 10
      ftype = 'REVIEW' ) ).

    APPEND VALUE #( screen = '' step_id = lv_rvsid title = 'Review and submit' )
           TO et_report.

    " ---- rules: DATA4/DATA5 container visibility + UI_FIELD_LOGICS ------
    CLEAR mt_hidden.
    DATA lt_raw_rules TYPE tt_rule.
    LOOP AT lt_screens INTO DATA(scr).
      APPEND LINES OF collect_rules( it_rows = lt iv_screen = scr )       TO lt_raw_rules.
      APPEND LINES OF collect_logic_rules( it_rows = lt iv_screen = scr ) TO lt_raw_rules.
    ENDLOOP.

    " dedupe on the full tuple
    DATA lt_rules TYPE tt_rule.
    LOOP AT lt_raw_rules INTO DATA(rr).
      IF line_exists( lt_rules[ src_field = rr-src_field src_op = rr-src_op
                                src_value = rr-src_value action = rr-action
                                tgt_field = rr-tgt_field ] ).
        CONTINUE.
      ENDIF.
      APPEND rr TO lt_rules.
    ENDLOOP.

    " any target with a SHOW rule defaults hidden; drop its redundant HIDE
    " rules (default-hidden + show-on-condition already covers them - gives
    " R1/R2 parity with the hand-craft). Targets with ONLY hide rules stay
    " visible and keep their HIDE rules.
    DATA lt_showtgt TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT lt_rules INTO DATA(sh) WHERE action = 'SHOW'.
      INSERT sh-tgt_field INTO TABLE lt_showtgt.          "#EC CI_SUBRC
    ENDLOOP.
    DATA lt_clean TYPE tt_rule.
    LOOP AT lt_rules INTO DATA(cr).
      IF cr-action = 'HIDE' AND line_exists( lt_showtgt[ table_line = cr-tgt_field ] ).
        CONTINUE.
      ENDIF.
      APPEND cr TO lt_clean.
    ENDLOOP.
    lt_rules = lt_clean.

    DATA lv_rid TYPE i.
    LOOP AT lt_rules ASSIGNING FIELD-SYMBOL(<ru>).
      lv_rid = lv_rid + 1.
      <ru>-rule_id = |R{ lv_rid }|.
      IF <ru>-action = 'SHOW'.
        INSERT <ru>-tgt_field INTO TABLE mt_hidden.       "#EC CI_SUBRC
      ENDIF.
    ENDLOOP.
    LOOP AT lt_rules INTO DATA(ir).
      INSERT zrak_t_jny_rule FROM @( VALUE #(
        mandt = sy-mandt journey_id = jid rule_id = ir-rule_id
        src_field = ir-src_field src_op = ir-src_op src_value = ir-src_value
        action = ir-action tgt_field = ir-tgt_field ) ).
    ENDLOOP.

    " ---- fields (interactive + display only) + options ------------------
    DATA lv_fseq TYPE i.
    DATA lt_seg_done TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_oseq TYPE i.
    DATA lv_shlp_cnt TYPE i.
    DATA lv_grid_cnt TYPE i.
    DATA lv_bind_cnt TYPE i.
    DATA lv_comp_drp TYPE i.
    DATA lv_grid_drp TYPE i.
    DATA lv_pick_cnt TYPE i.
    DATA lv_pay_drp  TYPE i.
    DATA lv_pay_kept TYPE i.

    LOOP AT lt INTO DATA(r).

*     THE BADI'S MANDATORY WINS WHEN IT SAYS YES, and it is applied HERE,
*     at the top of the loop, because three separate branches below build
*     a row from R-MANDATORY - the grid column, the pick target and the
*     field itself - and two of them CONTINUE before the bottom is
*     reached. Applied lower down it would have reached one of the three.
*
*     A UNION, not a replacement: the export's flag stands where the BAdI
*     said nothing, so an unregistered BAdI never makes a journey LESS
*     strict than it was.
      READ TABLE mt_badi INTO DATA(ls_bd)
           WITH TABLE KEY screen = CONV string( r-screen_name )
                          field  = to_upper( r-field_name ).
      IF sy-subrc = 0 AND ls_bd-mand = abap_true.
        r-mandatory = 'X'.
      ENDIF.
      ASSIGN et_report[ screen = r-screen_name ] TO FIELD-SYMBOL(<rep>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      <rep>-src_rows = <rep>-src_rows + 1.
      <rep>-staged   = <rep>-staged + 1.
      DATA(step) = <rep>-step_id.

      " role gate - ONLY interactive + display become _FLD rows.
      CASE r-role.
        WHEN c_decor.     <rep>-discarded = <rep>-discarded + 1. CONTINUE.
        WHEN c_chrome.    CONTINUE.
        WHEN c_stage.     CONTINUE.
        WHEN c_action.    CONTINUE.
        WHEN c_container. <rep>-container = <rep>-container + 1. CONTINUE.
        WHEN c_backend.   <rep>-backend   = <rep>-backend + 1.  CONTINUE.
      ENDCASE.

      " ---- SEGMENTED group: exactly ONE field per group -----------------
      IF r-ftype = 'SEGMENTED' AND r-grp_sig IS NOT INITIAL.
        DATA(segkey) = |{ r-screen_name }/{ r-grp_sig }|.
        IF line_exists( lt_seg_done[ table_line = segkey ] ).
          CONTINUE.                                    " group already emitted
        ENDIF.
        INSERT segkey INTO TABLE lt_seg_done.

        DATA(seg_fname) = seg_name( it_rows = lt iv_screen = r-screen_name iv_grp = r-grp_sig ).
        IF seg_fname IS INITIAL. CONTINUE. ENDIF.

        " group caption: paired LABEL on the member, else own label, else pretty
        DATA seg_en TYPE string.
        DATA seg_ar TYPE string.
        DATA(seg_cap) = REF #( mt_caption[ screen = r-screen_name field = to_upper( r-field_name ) ] OPTIONAL ).
        IF seg_cap IS BOUND.
          seg_en = seg_cap->en. seg_ar = seg_cap->ar.
        ELSE.
          seg_en = COND string( WHEN r-lbl_en IS NOT INITIAL THEN r-lbl_en ELSE r-text_en ).
          seg_ar = COND string( WHEN r-lbl_ar IS NOT INITIAL THEN r-lbl_ar ELSE r-text_ar ).
        ENDIF.
        IF seg_en IS INITIAL OR is_code_label( seg_en ) = abap_true.
          seg_en = pretty( CONV #( seg_fname ) ).
          CLEAR seg_ar.
          <rep>-defaulted = <rep>-defaulted + 1.
        ENDIF.

        <rep>-rendered = <rep>-rendered + 1.
        lv_fseq = lv_fseq + 1.
        DATA(seg_hidden) = xsdbool( line_exists( mt_hidden[ table_line = seg_fname ] ) ).

        INSERT zrak_t_jny_fld FROM @( VALUE #(
          mandt = sy-mandt journey_id = jid step_id = step
          field_name = seg_fname seqnr = lv_fseq * 10
          ftype = 'SEGMENTED' zlabel = seg_en zlabel_ar = seg_ar
          required = COND #( WHEN r-mandatory = 'X' THEN 'X' ELSE ' ' )
          hidden   = COND #( WHEN seg_hidden = abap_true THEN 'X' ELSE ' ' )
          tech_name = r-technical_name ) ).

        CLEAR lv_oseq.
        LOOP AT lt INTO DATA(mseg) WHERE screen_name = r-screen_name AND grp_sig = r-grp_sig.
          lv_oseq = lv_oseq + 10.
          INSERT zrak_t_jny_opt FROM @( VALUE #(
            mandt = sy-mandt journey_id = jid step_id = step field_name = seg_fname
            opt_key = to_upper( mseg-field_name ) seqnr = lv_oseq
            opt_text    = COND #( WHEN mseg-lbl_en IS NOT INITIAL THEN mseg-lbl_en ELSE pretty( CONV #( mseg-field_name ) ) )
            opt_text_ar = mseg-lbl_ar ) ).
          <rep>-options = <rep>-options + 1.
        ENDLOOP.
        CONTINUE.                                      " group done
      ENDIF.

      " ---- TABLE -> EDITABLE_TABLE (renders without a handler) ----------
      IF r-ftype = 'TABLE'.
        grid_spec( EXPORTING it_rows     = lt
                             is_row      = r
                   IMPORTING ev_spec     = DATA(lv_spec)
                             ev_sel_tgt  = DATA(lv_seltgt)
                             ev_readonly = DATA(lv_gro) ).
        IF lv_spec IS INITIAL.
*         No usable LEVEL_CON='T' columns, so there is nothing to render. A
*         bare EDITABLE_TABLE with no spec shows a warning strip instead of a
*         grid, so drop it and report the count rather than ship a stub.
          lv_grid_drp = lv_grid_drp + 1.
          <rep>-discarded = <rep>-discarded + 1.
          CONTINUE.
        ENDIF.

        DATA(gname) = safe_of( iv_screen = r-screen_name iv_orig = CONV #( r-field_name ) ).
        DATA glbl TYPE string.
        DATA glbl_ar TYPE string.
        DATA(gcap) = REF #( mt_caption[ screen = r-screen_name field = to_upper( r-field_name ) ] OPTIONAL ).
        IF gcap IS BOUND.
          glbl = gcap->en. glbl_ar = gcap->ar.
        ELSE.
          glbl    = COND string( WHEN r-lbl_en IS NOT INITIAL THEN r-lbl_en ELSE r-text_en ).
          glbl_ar = COND string( WHEN r-lbl_ar IS NOT INITIAL THEN r-lbl_ar ELSE r-text_ar ).
        ENDIF.
        IF glbl IS INITIAL OR is_code_label( glbl ) = abap_true.
          glbl = pretty( CONV #( gname ) ).
          CLEAR glbl_ar.
          <rep>-defaulted = <rep>-defaulted + 1.
        ENDIF.

        lv_grid_cnt = lv_grid_cnt + 1.
        <rep>-rendered = <rep>-rendered + 1.
        lv_fseq = lv_fseq + 1.

        INSERT zrak_t_jny_fld FROM @( VALUE #(
          mandt = sy-mandt journey_id = jid step_id = step
          field_name = gname seqnr = lv_fseq * 10
          ftype = 'EDITABLE_TABLE'
          zlabel = glbl zlabel_ar = glbl_ar
          attach_label = |Add { glbl }|
          default_val  = lv_spec
          readonly = COND #( WHEN lv_gro = abap_true THEN 'X' ELSE ' ' )
          required = COND #( WHEN r-mandatory = 'X' THEN 'X' ELSE ' ' )
          hidden   = COND #( WHEN line_exists( mt_hidden[ table_line = gname ] ) THEN 'X' ELSE ' ' )
*         EDITABLE_TABLE only posts when it has a tech_name, and the Studio
*         lints a blank one as an error, so fall back to the safe name.
          tech_name = COND string( WHEN r-technical_name IS NOT INITIAL
                                   THEN CONV string( r-technical_name ) ELSE gname ) ) ).

*       A SEL: directive is useless without somewhere for the picked key to land,
*       and the Studio lints a missing target as an error. READONLY so the engine
*       can overwrite it on every pick without fighting the citizen.
        IF lv_seltgt IS NOT INITIAL.
          lv_fseq = lv_fseq + 1.
          INSERT zrak_t_jny_fld FROM @( VALUE #(
            mandt = sy-mandt journey_id = jid step_id = step
            field_name = lv_seltgt seqnr = lv_fseq * 10
            ftype = 'READONLY'
            zlabel = |Selected { glbl }|
            readonly = 'X' ) ).
          lv_pick_cnt = lv_pick_cnt + 1.
        ENDIF.
        CONTINUE.
      ENDIF.

      " ---- payment needs a handler class ---------------------------------
*     AND NOW IT CAN HAVE ONE. The field was dropped unconditionally
*     because without a handler the engine renders a red "payment
*     unavailable" strip AT the citizen - true, but it made the drop
*     permanent: twelve of the fifteen Municipality journeys are
*     fee-bearing and ended up with no pay control at all, so the fee step
*     rendered empty and the journey could not be completed.
*
*     ZCL_RAK_JOURNEY_LOGIC is CREATE PUBLIC and concrete: it supplies the
*     payment card and the PAID gate with no subclass. So a caller that
*     names a handler gets the field, and one that does not keeps the old
*     behaviour exactly.
      IF r-ftype = 'PAYFEE' AND iv_handler IS INITIAL.
        lv_pay_drp = lv_pay_drp + 1.
        <rep>-discarded = <rep>-discarded + 1.
        CONTINUE.
      ENDIF.
      IF r-ftype = 'PAYFEE'.
        lv_pay_kept = lv_pay_kept + 1.
      ENDIF.

      DATA(rawkey) = |{ r-screen_name }/{ to_upper( r-field_name ) }|.

      DATA(lv_rt) = render_ftype( r-ftype ).
      IF lv_rt IS INITIAL.
*       COUNTED SEPARATELY WHEN IT IS A COMPOSITE. The four below are real
*       controls CLASSIFY( ) recognised and this gate still drops, because
*       nothing draws them yet - SIGN, and the three EPDA composites. Lumping
*       them into DISCARDED hides them among the logos and breadcrumbs, and
*       the whole reason the last round went wrong is that a dropped control
*       looks exactly like a screen that never had one. They show in the run
*       log instead, by name, so the gap is a number somebody can act on.
        CASE to_upper( r-ftype ).
*         ACCOM has come off this list - it renders now. CHEMICALS stays on
*         it deliberately: E016/E017/E018 draw that dialog themselves from
*         ON_RENDER_END( ), so a field for it would be a second, empty
*         control beside the real one.
          WHEN 'SIGN' OR 'CHEMICALS' OR 'BOATS'.
            lv_comp_drp = lv_comp_drp + 1.
        ENDCASE.
        <rep>-discarded = <rep>-discarded + 1. CONTINUE.
      ENDIF.

      " table columns / any descendant of a TABLE container -> staged only.
      IF r-is_col = abap_true OR is_in_table( it_rows = lt is_row = r ) = abap_true.
        <rep>-columns = <rep>-columns + 1. CONTINUE.
      ENDIF.

      " repeated header/logo/breadcrumb -> drop.
      IF line_exists( mt_chrome[ table_line = rawkey ] ).
        <rep>-discarded = <rep>-discarded + 1. CONTINUE.
      ENDIF.

      " a LABEL folded into the control it captions -> drop the standalone row.
      IF r-role = c_display AND line_exists( mt_consumed[ table_line = rawkey ] ).
        <rep>-discarded = <rep>-discarded + 1. CONTINUE.
      ENDIF.

      " resolve the caption.
      DATA lbl_en TYPE string.
      DATA lbl_ar TYPE string.
      DATA(cap_ref) = REF #( mt_caption[ screen = r-screen_name field = to_upper( r-field_name ) ] OPTIONAL ).
      IF cap_ref IS BOUND.
        lbl_en = cap_ref->en. lbl_ar = cap_ref->ar.
      ELSE.
        lbl_en = COND string( WHEN r-lbl_en  IS NOT INITIAL THEN r-lbl_en
                              WHEN r-text_en IS NOT INITIAL THEN r-text_en ELSE '' ).
        lbl_ar = COND string( WHEN r-lbl_ar IS NOT INITIAL THEN r-lbl_ar ELSE r-text_ar ).
      ENDIF.

      IF r-role = c_display AND ( lbl_en IS INITIAL OR is_code_label( lbl_en ) = abap_true ).
        <rep>-discarded = <rep>-discarded + 1. CONTINUE.
      ENDIF.

*     A guidance sentence is not a caption. Keep the wording, but render it
*     as DISPLAY text with NO label - previously it became the label of an
*     empty field ("*School Name must include Private and School:").
      IF r-role = c_display AND is_notice( lbl_en ) = abap_true.
        <rep>-rendered = <rep>-rendered + 1.
        lv_fseq = lv_fseq + 1.
        INSERT zrak_t_jny_fld FROM @( VALUE #(
          mandt = sy-mandt journey_id = jid step_id = step
          field_name  = safe_of( iv_screen = r-screen_name iv_orig = CONV #( r-field_name ) )
          seqnr       = lv_fseq * 10
          ftype       = 'DISPLAY'
          zlabel      = ' '
          default_val = lbl_en ) ).
        CONTINUE.
      ENDIF.

      IF lbl_en IS INITIAL OR is_code_label( lbl_en ) = abap_true.
        lbl_en = pretty( CONV #( r-field_name ) ).
        r-defaulted = abap_true.
      ENDIF.

      DATA(fname) = safe_of( iv_screen = r-screen_name iv_orig = CONV #( r-field_name ) ).
      <rep>-rendered = <rep>-rendered + 1.
      IF r-defaulted = abap_true. <rep>-defaulted = <rep>-defaulted + 1. ENDIF.
      lv_fseq = lv_fseq + 1.

      " Attachment fields render as a PURE uploader (ftype='UPLOAD') so the
      " engine shows only the file control - no stray empty text input. The
      " source control was a RAKUPLOADER (upload only, no data entry), so
      " INPUT+has_attach would add an unused input box. has_attach='X' and
      " the doc-code tech_name are kept so the attachment staging pipeline
      " (ZRAK_T_ATT_STG) is unchanged. attach_types default pdf,jpg,png;
      " the DATA2 doc code (B6/FP/FR/...) is tech_name, never a file type.
*     A display row that RECEIVED a paired caption and carries only its own
*     design-time VALUE is a read-only control. Render it as READONLY - the
*     grey disabled box the legacy screen shows - and drop the placeholder
*     text entirely; the caption is its label and the value comes from the
*     backend at runtime.
      DATA(is_roval) = xsdbool( r-role = c_display AND cap_ref IS BOUND
                                AND r-lbl_en IS INITIAL AND r-text_en IS NOT INITIAL ).
      DATA(is_upl)   = xsdbool( r-ftype = 'UPLOAD' ).
      DATA(is_email) = xsdbool( r-ftype = 'EMAIL' ).
      DATA(lv_ftype) = COND string( WHEN is_roval = abap_true THEN 'READONLY' ELSE lv_rt ).
      DATA(tech)     = COND string( WHEN is_upl = abap_true AND r-data2 IS NOT INITIAL
                                    THEN CONV string( r-data2 ) ELSE CONV string( r-technical_name ) ).

      " F4 SOURCE = shlp (SH_NAME). rollname is deliberately left BLANK:
      " these comboboxes resolve via the search help, and writing a
      " rollname routes the engine's F4 resolver down the domain/value-
      " table path (those data elements have no value table) -> EMPTY
      " dropdown. shlp-only is what actually populates handler-free F4.
      IF r-sh_name IS NOT INITIAL. lv_shlp_cnt = lv_shlp_cnt + 1. ENDIF.

      DATA(is_hidden) = xsdbool( line_exists( mt_hidden[ table_line = fname ] ) ).

      DATA(lv_dir) = api_bind( iv_ftype = lv_ftype iv_field = CONV #( r-field_name ) ).
      IF lv_dir IS NOT INITIAL.
        lv_bind_cnt = lv_bind_cnt + 1.
      ENDIF.

      INSERT zrak_t_jny_fld FROM @( VALUE #(
        mandt = sy-mandt journey_id = jid step_id = step
        field_name = fname seqnr = lv_fseq * 10
        ftype  = lv_ftype
        zlabel = lbl_en zlabel_ar = lbl_ar
        required = COND #( WHEN r-mandatory = 'X' THEN 'X' ELSE ' ' )
        hidden   = COND #( WHEN is_hidden = abap_true THEN 'X' ELSE ' ' )
        rollname = ' '
        shlp     = r-sh_name
        regex    = COND #( WHEN is_email = abap_true THEN '.+@.+\..+' ELSE '' )
        msg      = COND #( WHEN is_email = abap_true THEN 'Valid email required' ELSE '' )
        has_attach   = COND #( WHEN is_upl = abap_true THEN 'X' ELSE ' ' )
        attach_label = COND #( WHEN is_upl = abap_true
                               THEN COND string( WHEN lbl_en IS NOT INITIAL THEN |Upload { lbl_en }| ELSE 'Upload' )
                               ELSE '' )
        attach_types = COND #( WHEN is_upl = abap_true THEN 'pdf,jpg,png' ELSE '' )
*       2, not 5. The engine used to hard-code 2 MB and ignore this column;
*       it now honours it in both the browser check and the authoritative
*       server-side cap, so writing 5 silently RAISED every migrated limit.
*       Raise it per field in the Studio where a screen notice says more.
*       Zero, not 2. Zero means "use the system default", so raising
*       ZRAK_CJ_ATT_MAXMB lifts every migrated uploader at once. Writing 2 here
*       froze each one at the old floor and left an author to edit them one by
*       one - which nobody ever did.
        attach_maxmb = 0
*       A ShapeIt composite carries no TECHNICAL_NAME because it does not
*       post through ct_item_data - it writes through its own service. So
*       nothing is invented here; the DEFAULT_VAL directive says which
*       service instead, and the run log counts the fields that got one.
        default_val = lv_dir
        tech_name = tech ) ).

      " SELECT: static JSON options in DATA1 (else engine uses shlp/rollname)
      IF r-ftype = 'SELECT'.
        DATA(lt_kv) = combobox_options( r ).
        CLEAR lv_oseq.
        LOOP AT lt_kv INTO DATA(kv).
          lv_oseq = lv_oseq + 10.
          INSERT zrak_t_jny_opt FROM @( VALUE #(
            mandt = sy-mandt journey_id = jid step_id = step field_name = fname
            opt_key = kv-key seqnr = lv_oseq opt_text = kv-text ) ).
          <rep>-options = <rep>-options + 1.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    " ---- portal: main "AI Driven Journeys" tile - INSERTED ONCE, never
    " written over. It was checked free (or CJS-owned) at the top of the
    " method; an existing group keeps its own description, LEVELNO and
    " ORDERNO, because those belong to whoever created it.
    SELECT SINGLE @abap_true FROM zega_t_cj_grp
      WHERE department = @lv_dept4 AND groupid = @space AND journeyid = @lv_main4
      INTO @DATA(lv_mgrp).
    IF lv_mgrp <> abap_true.
      INSERT zega_t_cj_grp FROM @( VALUE #(
        mandt = sy-mandt department = lv_dept4 groupid = ''
        journeyid = lv_main4 levelno = 0 orderno = 99 drilldown = 'Y' ) ).
    ENDIF.
    SELECT SINGLE @abap_true FROM zega_t_cj_id WHERE journeyid = @lv_main4
      INTO @DATA(lv_mid).
    IF lv_mid <> abap_true.
      INSERT zega_t_cj_id  FROM @( VALUE #(
        mandt = sy-mandt journeyid = lv_main4 sip_code = lv_main4 ) ).
      INSERT zega_t_cj_idt FROM @( VALUE #(
        mandt = sy-mandt spras = 'E' journeyid = lv_main4
        description = 'AI Driven Journeys' ) ).
      INSERT zega_t_cj_idt FROM @( VALUE #(
        mandt = sy-mandt spras = 'A' journeyid = lv_main4
        description = |الرحلات الرقمية الذكية| ) ).
    ENDIF.

*   ---- this journey's own leaf. LEVELNO is the depth of the ROW, not a
*   constant: a journey sitting directly under a top-level group is level 1,
*   the way every child of 901/280/282 is in the live table. It was written
*   as 2 here, which is the depth of a journey under a SUB-group (D001 under
*   R160 under 280) - one level too deep to be found under its own parent.
    MODIFY zega_t_cj_grp FROM @( VALUE #(
      mandt = sy-mandt department = lv_dept4 groupid = lv_main4
      journeyid = lv_tile4 levelno = 1 orderno = lv_stepno * 10 drilldown = 'N' ) ).
    MODIFY zega_t_cj_id  FROM @( VALUE #(
      mandt = sy-mandt journeyid = lv_tile4 sip_code = lv_tile4 ) ).
    MODIFY zega_t_cj_idt FROM @( VALUE #(
      mandt = sy-mandt spras = 'E' journeyid = lv_tile4 description = iv_title ) ).
    MODIFY zega_t_cj_idt FROM @( VALUE #(
      mandt = sy-mandt spras = 'A' journeyid = lv_tile4 description = iv_title_ar ) ).

    COMMIT WORK.
    ev_ok = abap_true.
    DATA(tr)  = REDUCE i( INIT s = 0 FOR w IN et_report NEXT s = s + w-rendered ).
    DATA(tcx) = REDUCE i( INIT s = 0 FOR w IN et_report NEXT s = s + w-columns ).
    DATA(too) = REDUCE i( INIT s = 0 FOR w IN et_report NEXT s = s + w-options ).
    DATA(tb)  = REDUCE i( INIT s = 0 FOR w IN et_report NEXT s = s + w-backend ).
    DATA(td)  = REDUCE i( INIT s = 0 FOR w IN et_report NEXT s = s + w-defaulted ).
    ev_msg = |{ jid } (bknd { iv_journey }): { lv_stepno } steps; { tr } fields, | &&
             |{ lv_grid_cnt } grids from { tcx } table-cols, { too } options, | &&
             |{ lines( lt_rules ) } rules, { lv_shlp_cnt } shlp-F4, { tb } backend, | &&
             |{ td } defaulted-REVIEW (attach maxMB 2 - raise per field where a | &&
             |screen notice says more); { lines( lt ) } rows staged in ZRAK_T_MIG_RAW|.
    IF lv_bind_cnt > 0.
      ev_msg = ev_msg && | { lv_bind_cnt } composite field(s) bound to a wrapper API | &&
                         |through DEFAULT_VAL 'API:...' - those post through their own | &&
                         |service, not through ct_item_data, so a blank TECH_NAME on them | &&
                         |is correct.|.
    ENDIF.
    IF lv_comp_drp > 0.
      ev_msg = ev_msg && | { lv_comp_drp } composite control(s) DROPPED - signature, | &&
                         |chemicals or boats. Recognised but not drawn by any renderer | &&
                         |branch yet, so the step is missing that control.|.
    ENDIF.
    IF lv_pick_cnt > 0.
      ev_msg = ev_msg && | { lv_pick_cnt } of those are pick lists (DATA3 select mode): | &&
                         |READONLY, with a SEL: column and a _PICK target field each.|.
    ENDIF.
    IF lv_grid_drp > 0.
      ev_msg = ev_msg && | ** { lv_grid_drp } table(s) dropped: no LEVEL_CON='T' columns.|.
    ENDIF.
*   ---- SOURCES, named. -----------------------------------------------
*   A journey is built from seven artifacts and each carries something none
*   of the others do - see doc/migration/sources.md. A run that does not
*   say which of them answered cannot be reviewed: an empty step title
*   looks identical whether the BAdI was silent or the screen genuinely
*   has none, and a composite with no API directive looks identical
*   whether the model was consulted or the control was simply dropped.
*   So the log names them, answered or not.
    ev_msg = ev_msg && | SOURCES: export { lines( lt ) } row(s)| &&
             |; BAdI { COND string( WHEN iv_badi = abap_false THEN 'not asked'
                                    WHEN mv_badi_ok = abap_true THEN 'answered'
                                    ELSE 'SILENT' ) }| &&
             |{ COND string( WHEN iv_badi = abap_true AND iv_badi_all = abap_false
                             THEN ' (first screen only)' ) }| &&
             |; OData bindings { lv_bind_cnt }| &&
             |; captions { lines( mt_val ) + lines( mt_lbl ) } cached| &&
             |; portal group { lv_main4 }| &&
             |. Control sources and the live screens are read by hand - | &&
             |doc/controls/shapeit-reads.md and doc/journeys/.|.

    IF iv_badi = abap_true.
      IF mv_badi_ok = abap_false.
        ev_msg = ev_msg && | ** The BAdI answered nothing for this journey: | &&
                           |step names and required flags are the export's own.|.
      ELSEIF mt_stage IS INITIAL.
        ev_msg = ev_msg && | BAdI read OK, no STAGES row - step names derived.|.
      ELSEIF lv_stage_fit = abap_true.
        ev_msg = ev_msg && | Step names from the legacy STAGES list: | &&
                           |{ concat_lines_of( table = mt_stage sep = ` / ` ) }.|.
      ELSE.
        ev_msg = ev_msg && | ** REVIEW: the STAGES list has | &&
                           |{ lines( mt_stage ) } name(s) for { lines( lt_screens ) } step(s) - | &&
                           |{ concat_lines_of( table = mt_stage sep = ` / ` ) } - so it was NOT | &&
                           |applied. Map them by hand or pass IV_STEPS.|.
      ENDIF.
    ENDIF.
    IF lv_conf_drp > 0.
      ev_msg = ev_msg && | { lv_conf_drp } confirmation screen(s) dropped: the engine | &&
                         |appends its own Review and submit step.|.
    ENDIF.
    IF iv_bknd_active = abap_false.
      ev_msg = ev_msg && | ** BKND_ACTIVE is blank: this journey renders but | &&
                         |POSTS NOTHING at submit.|.
    ENDIF.
    IF lv_pay_kept > 0.
      ev_msg = ev_msg && | { lv_pay_kept } payment field(s) kept, handled by | &&
                         |{ to_upper( iv_handler ) }.|.
    ENDIF.
    IF lv_pay_drp > 0.
      ev_msg = ev_msg && | ** { lv_pay_drp } payment step(s) dropped: set handler_class | &&
                         |(subclass of ZCL_RAK_JOURNEY_LOGIC) and add PAYFEE in the Studio.|.
    ENDIF.

    DATA lv_prow TYPE i.
    apply_layout( EXPORTING iv_journey = CONV #( jid )
                  IMPORTING ev_pairs   = lv_prow ).
    IF lv_prow > 0.
      ev_msg = ev_msg && | { lv_prow } field pair(s) placed side by side.|.
    ENDIF.


  ENDMETHOD.


  METHOD migrate_many.
    CLEAR: et_report, ev_log.
    LOOP AT it_jobs INTO DATA(job).
      migrate(
        EXPORTING
          iv_category = job-category
          iv_journey  = job-journey
          iv_cjs_id   = job-journey          " -> <prefix><journey>
          iv_tile     = job-journey
          iv_title    = COND #( WHEN job-title IS NOT INITIAL THEN job-title ELSE job-journey )
          iv_title_ar = job-title_ar
          iv_dept     = iv_dept
          iv_main     = iv_main
          iv_prefix      = iv_prefix
          iv_tile_pfx    = iv_tile_pfx
          iv_bknd_active = iv_bknd_active
          iv_handler     = iv_handler
          iv_badi        = iv_badi
          iv_badi_all    = iv_badi_all
          iv_steps       = job-steps
        IMPORTING
          ev_ok       = DATA(lv_ok)
          ev_msg      = DATA(lv_msg)
          et_report   = DATA(lt_rep) ).
      APPEND LINES OF lt_rep TO et_report.
      ev_log = ev_log && COND string( WHEN lv_ok = abap_true THEN |[OK] | ELSE |[SKIP] | )
                       && lv_msg && |{ cl_abap_char_utilities=>newline }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD norm_name.
    DATA(lv) = to_upper( iv_name ).
    IF lv CS '-'.                       " GS_DATA-COMPANY-EMAIL_ID -> EMAIL_ID
      SPLIT lv AT '-' INTO TABLE DATA(seg).
      lv = seg[ lines( seg ) ].
    ENDIF.
    REPLACE ALL OCCURRENCES OF '[]' IN lv WITH ``.   " VEHICLES[] -> VEHICLES
    IF iv_is_table = abap_true.
      REPLACE ALL OCCURRENCES OF '_' IN lv WITH ``.   " TABLE names: no '_' (ROWPICK)
    ENDIF.
    REPLACE ALL OCCURRENCES OF REGEX `[^A-Z0-9_]` IN lv WITH ``.
    IF lv IS INITIAL. lv = 'FLD'. ENDIF.
    IF lv(1) CO '0123456789_'. lv = |F{ lv }|. ENDIF.
    IF strlen( lv ) > c_name_max. lv = lv(c_name_max). ENDIF.
    rv = lv.
  ENDMETHOD.


  METHOD pairable.

*   Whitelist, not a blacklist: an ftype this projector learns to emit later is
*   stacked full width until somebody decides it shares well, which is the safe
*   default. Excluded on purpose and why:
*     TEXTAREA SLIDER RATING PROGRESS  - want the full measure
*     RADIO SEGMENTED CHECKGROUP       - options flow horizontally already
*     DISPLAY REVIEW RO_PANEL STATUS   - read-only prose or a block of rows
*     OBJNUM LINK                      - inline, no label/control geometry
*     TABLE EDITABLE_TABLE UPLOAD      - the engine ends a row at any block,
*     SEARCH PAYFEE RECORDCARD REQPANEL  so pairing one is dead config
    CASE to_upper( iv_ftype ).
      WHEN 'INPUT' OR 'READONLY' OR 'DATE' OR 'TIME' OR 'DATETIME'
        OR 'NUMBER' OR 'CURRENCY' OR 'PHONE' OR 'EMAIL'
        OR 'SELECT' OR 'MULTISELECT' OR 'STEPPER' OR 'CHECKBOX' OR 'SWITCH'.
        rv = abap_true.
      WHEN OTHERS.
        rv = abap_false.
    ENDCASE.

  ENDMETHOD.


  METHOD pair_labels.
    CLEAR: mt_caption, mt_consumed.
    DATA lt_scr TYPE SORTED TABLE OF /qnv/sb_ui_defin-screen_name WITH UNIQUE KEY table_line.
    LOOP AT it_rows INTO DATA(x). INSERT x-screen_name INTO TABLE lt_scr. ENDLOOP.

    LOOP AT lt_scr INTO DATA(scr).
      DATA pend_raw  TYPE string.
      DATA pend_en   TYPE string.
      DATA pend_ar   TYPE string.
      DATA has_pend  TYPE abap_bool.
      CLEAR: pend_raw, pend_en, pend_ar, has_pend.

      LOOP AT it_rows INTO DATA(r) WHERE screen_name = scr.
        CASE r-role.
          WHEN c_display.
            IF r-ftype = 'DISPLAY'.
*             LABEL_CON present  -> this row is a CAPTION.
*             VALUE only         -> this row is the design-time placeholder
*                                   of a READ-ONLY control ("Aug 23, 2023"),
*                                   so it CONSUMES the pending caption and
*                                   becomes the field. It must never become a
*                                   caption itself - that is how a sample date
*                                   ended up rendered as a field label.
              IF r-lbl_en IS INITIAL AND r-text_en IS NOT INITIAL
                 AND has_pend = abap_true.
                INSERT VALUE #( screen = scr field = to_upper( r-field_name )
                                en = pend_en ar = pend_ar ) INTO TABLE mt_caption. "#EC CI_SUBRC
                INSERT |{ scr }/{ pend_raw }| INTO TABLE mt_consumed. "#EC CI_SUBRC
                CLEAR has_pend.
              ELSE.
                DATA(cap) = COND string( WHEN r-lbl_en IS NOT INITIAL THEN r-lbl_en ELSE r-text_en ).
                IF cap IS NOT INITIAL AND is_code_label( cap ) = abap_false.
                  pend_raw = to_upper( r-field_name ).
                  pend_en  = cap.
                  pend_ar  = COND string( WHEN r-lbl_ar IS NOT INITIAL THEN r-lbl_ar ELSE r-text_ar ).
                  has_pend = abap_true.
                ENDIF.
              ENDIF.
            ENDIF.
          WHEN c_interact.
            IF has_pend = abap_true.
              INSERT VALUE #( screen = scr field = to_upper( r-field_name )
                              en = pend_en ar = pend_ar ) INTO TABLE mt_caption. "#EC CI_SUBRC
              INSERT |{ scr }/{ pend_raw }| INTO TABLE mt_consumed. "#EC CI_SUBRC
              CLEAR has_pend.
            ENDIF.
          WHEN c_container.
            " keep pending - a label often sits in an HBOX just before its field

          WHEN c_backend OR c_stage.
*           AN INVISIBLE ROW DOES NOT BREAK A PAIR. A legacy screen
*           interleaves its JOURNEYTYPE / INTRENO_JOURNEY carriers and its
*           stage list between the visible controls. Clearing the pending
*           caption on one of those is how "Parcel Selection:" ended up
*           rendering as a field of its own - a grey disabled box - while
*           RAKPARCELSELECTOR next to it was labelled "Parcelselector",
*           from its own field name, because it never received the caption
*           sitting two rows above it.
*
*           The citizen cannot see these rows, so they cannot be what
*           separates a caption from the control it belongs to.

          WHEN OTHERS.
            CLEAR has_pend.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD pretty.
    rv = to_lower( iv ).
    REPLACE ALL OCCURRENCES OF '_' IN rv WITH ` `.
    IF strlen( rv ) > 0. rv = to_upper( rv(1) ) && rv+1. ENDIF.
  ENDMETHOD.


  METHOD range_side.

    DATA(t) = to_upper( iv_text ).
    REPLACE ALL OCCURRENCES OF '_' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF '-' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF '(' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF ')' IN t WITH ' '.
    REPLACE ALL OCCURRENCES OF ':' IN t WITH ' '.
    CONDENSE t.
    IF t IS INITIAL.
      RETURN.
    ENDIF.

    SPLIT t AT ' ' INTO TABLE DATA(lt_w).
    DELETE lt_w WHERE table_line IS INITIAL.

*   Whole words only. Substring matching turns 'CUSTOMER' into an end-of-range
*   marker on the 'TO' inside it.
    LOOP AT lt_w INTO DATA(w).
      CASE w.
        WHEN 'FROM' OR 'START' OR 'STARTS' OR 'BEGIN' OR 'ISSUE' OR 'ISSUED'
          OR 'ISSUANCE' OR 'COMMENCEMENT' OR 'OPENING' OR 'EFFECTIVE'.
          rv = 'A'.
          RETURN.
        WHEN 'TO' OR 'END' OR 'ENDS' OR 'UNTIL' OR 'TILL' OR 'EXPIRY'
          OR 'EXPIRED' OR 'EXPIRE' OR 'EXPIRES' OR 'EXPIRATION' OR 'CLOSING'.
          rv = 'B'.
          RETURN.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_ftype.
*   TABLE and PAYFEE are deliberately NOT here.
*     TABLE  -> handled before this gate and projected as EDITABLE_TABLE,
*               which renders handler-free from a column spec. A plain TABLE
*               is fed by mo_logic->get_table( ) and a migrated journey has
*               no handler, so it rendered as an empty grid.
*     PAYFEE -> needs handler_class + prepare_payment. Without one the engine
*               renders a red "payment unavailable" strip AT the citizen, so
*               the field is dropped and counted into ev_msg instead.
    CASE to_upper( iv_ftype ).
      WHEN 'INPUT' OR 'EMAIL' OR 'PHONE' OR 'NUMBER' OR 'TEXTAREA' OR 'DATE' OR 'TIME'
        OR 'SELECT' OR 'CHECKBOX' OR 'RADIO' OR 'STEPPER' OR 'SEGMENTED'
        OR 'UPLOAD' OR 'SEARCH' OR 'DISPLAY' OR 'LINK' OR 'STATUS'.
        rv = to_upper( iv_ftype ).
*     THE API-BACKED COMPOSITES PASS THROUGH UNCHANGED, and until they did,
*     nothing else in this file mattered. This method is a WHITELIST and its
*     WHEN OTHERS clears RV; the caller reads a cleared RV as "discard the
*     row". So every RAKPARCELSELECTOR, RAK_PROPERTIES, RAK_TITLEDEED,
*     RAK_FLOORUNIT, RAK_CONTRACTS and RAK_BUILDINGCONTROL that CLASSIFY( )
*     had just correctly identified was thrown away one gate later - and
*     because the row was gone, API_BIND( ) never saw it either, so no
*     DEFAULT_VAL directive was ever written for any of them.
*
*     What reached the screen was the control's CAPTION, which is a separate
*     display row and survives on its own: the grey "Parcel Selection:" box
*     on M011 step 1 is a label with its control deleted out from under it.
*     That is why the journey looked empty rather than broken.
*
*     They are here now because they RENDER: ZCL_RAK_JOURNEY_RENDER draws all
*     six through the SELECT branch, fed by ZCL_RAK_CJ_OPTS off the directive.
*     The TABLE/PAYFEE reasoning above does not apply - those are dropped
*     because they would render WRONGLY without a handler, and these do not.
      WHEN 'PARCEL' OR 'PROPERTY' OR 'TITLEDEED'
        OR 'FLOORUNIT' OR 'CONTRACT' OR 'BUILDINGS'
*       ACCOM joins them now that ZCL_RAK_ACCOM_API serves it. It was in the
*       counted-drop list below while nothing could answer a port
*       accommodation query; ZEGA_CJ_EPDA_PORT_OBJECTS answers it.
        OR 'ACCOM'.
        rv = to_upper( iv_ftype ).
*     PAYFEE passes through. The field loop above decides whether to keep
*     it - it has IV_HANDLER and this method does not - so a blanket drop
*     here would overrule that decision one gate later, which is exactly
*     how the API-backed composites were lost.
      WHEN 'PAYFEE'.
        rv = 'PAYFEE'.
      WHEN 'DATERANGE' OR 'CALENDAR'.
        rv = 'DATE'.
      WHEN 'HOURS'.
        rv = 'NUMBER'.
      WHEN 'FEES' OR 'MESSAGE'.
        rv = 'DISPLAY'.
      WHEN OTHERS.
        CLEAR rv.
    ENDCASE.
  ENDMETHOD.


  METHOD safe_of.
    DATA(hit) = VALUE #( mt_name[ screen = iv_screen orig = to_upper( iv_orig ) ]-safe OPTIONAL ).
    rv = COND #( WHEN hit IS NOT INITIAL THEN hit
                 ELSE norm_name( iv_name = iv_orig ) ).
  ENDMETHOD.


  METHOD seg_name.
    " Deterministic name for a segmented group: the safe name of the
    " lowest-seq member (rows arrive sorted by screen, seq). Used by both
    " the field projector and the rule builder so they agree on the source.
    LOOP AT it_rows INTO DATA(m) WHERE screen_name = iv_screen AND grp_sig = iv_grp.
      rv = safe_of( iv_screen = iv_screen iv_orig = CONV #( m-field_name ) ).
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_rows.
    DATA lt_raw TYPE STANDARD TABLE OF zrak_t_mig_raw.
    DATA lv_n TYPE i.
    LOOP AT it_rows INTO DATA(r).
      lv_n = lv_n + 1.
      APPEND VALUE #(
        mandt = sy-mandt cjs_id = iv_cjs_id rawid = lv_n
        screen_name = r-screen_name field_name = r-field_name
        seq_key = r-seq_key control_type = r-control_type
        ftype = r-ftype role = r-role defaulted = r-defaulted
        parent_container = r-parent_container
        text_en = r-text_en text_ar = r-text_ar lbl_en = r-lbl_en lbl_ar = r-lbl_ar
        technical_name = r-technical_name script = r-script
        raw_json = /ui2/cl_json=>serialize( data = r ) ) TO lt_raw.
    ENDLOOP.
    DELETE FROM zrak_t_mig_raw WHERE cjs_id = @iv_cjs_id.
    MODIFY zrak_t_mig_raw FROM TABLE @lt_raw.
    COMMIT WORK.
  ENDMETHOD.


  METHOD step_from_content.
*   Derived from what the screen actually holds. Far better than the old
*   fallback, which took the lowest-seq display row and produced step names
*   like "Each file maximum allowed size - 3MB" and "Your Request was
*   submitted!". Still a fallback - pass iv_steps for a flagship journey.
    DATA lv_upl  TYPE abap_bool.
    DATA lv_pay  TYPE abap_bool.
    DATA lv_tbl  TYPE abap_bool.
    DATA lv_int  TYPE i.

    LOOP AT it_rows INTO DATA(r) WHERE screen_name = iv_screen.
      CASE r-ftype.
        WHEN 'UPLOAD'. lv_upl = abap_true.
        WHEN 'PAYFEE'. lv_pay = abap_true.
        WHEN 'TABLE'.  lv_tbl = abap_true.
      ENDCASE.
      IF r-role = c_interact AND r-is_col = abap_false.
        lv_int = lv_int + 1.
      ENDIF.
    ENDLOOP.

    rv = COND string(
      WHEN lv_pay = abap_true                          THEN 'Payment'
      WHEN lv_upl = abap_true                          THEN 'Documents'
      WHEN iv_last = abap_true AND lv_int = 0          THEN 'Confirmation'
      WHEN iv_last = abap_true                         THEN 'Review'
      WHEN iv_no = 1                                   THEN 'Selection'
      WHEN lv_tbl = abap_true                          THEN 'Details'
      ELSE |Step { iv_no }| ).
  ENDMETHOD.


  METHOD step_icon.
    DATA(t) = to_lower( iv_title ).
    IF t IS INITIAL OR t CS 'step '.
      LOOP AT it_rows INTO DATA(r) WHERE screen_name = iv_screen
                                     AND ( role = c_interact OR role = c_display ).
        t = |{ t } { to_lower( r-lbl_en ) } { to_lower( r-text_en ) }|.
      ENDLOOP.
    ENDIF.
    rv = COND string(
      WHEN t CS 'applicant' OR t CS 'person'  OR t CS 'owner' OR t CS 'emirates id'
        THEN 'sap-icon://person-placeholder'
      WHEN t CS 'company'  OR t CS 'establish' OR t CS 'organi' OR t CS 'entity'
        THEN 'sap-icon://building'
      WHEN t CS 'document' OR t CS 'attach'    OR t CS 'upload' OR t CS 'certificate'
        THEN 'sap-icon://attachment'
      WHEN t CS 'payment'  OR t CS 'fee'       OR t CS 'pay'
        THEN 'sap-icon://credit-card'
      WHEN t CS 'confirm'  OR t CS 'review'    OR t CS 'summary' OR t CS 'declaration'
        THEN 'sap-icon://accept'
      WHEN t CS 'location' OR t CS 'address'   OR t CS 'map'    OR t CS 'plot' OR t CS 'parcel'
        THEN 'sap-icon://map'
      WHEN t CS 'contact'  OR t CS 'telephone' OR t CS 'mobile' OR t CS 'email'
        THEN 'sap-icon://email'
      WHEN t CS 'license'  OR t CS 'permit'    OR t CS 'trade'
        THEN 'sap-icon://official-service'
      WHEN t CS 'school'   OR t CS 'student'   OR t CS 'academic' OR t CS 'education'
        THEN 'sap-icon://education'
      ELSE 'sap-icon://form' ).
  ENDMETHOD.


  METHOD step_title.
    " The RAKSTAGEBAR does NOT carry step names (its DATA2 is just the
    " active-stage index, DATA3 icon keys). So derive the title from the
    " screen's lowest-seq SECTION HEADING: a DISPLAY row with resolved
    " text that is NOT chrome (repeated header/logo/breadcrumb), NOT a
    " field caption already folded into a control, and NOT a bare code.
    " Requires build_name_map / pair_labels / detect_chrome to have run.
    CLEAR: ev_en, ev_ar.
    DATA lv_best TYPE i VALUE 999999.
    LOOP AT it_rows INTO DATA(l) WHERE screen_name = iv_screen
                                   AND role = c_display
                                   AND text_en IS NOT INITIAL.
      DATA(rk) = |{ iv_screen }/{ to_upper( l-field_name ) }|.
      IF line_exists( mt_chrome[ table_line = rk ] ).   CONTINUE. ENDIF.  " repeated header/logo
      IF line_exists( mt_consumed[ table_line = rk ] ). CONTINUE. ENDIF.  " folded field caption
*     A row that RECEIVED a caption is a CONTROL, not a heading. Without this
*     the read-only value row won the contest and the step was titled with its
*     design-time placeholder ("Aug 23, 2023").
      IF line_exists( mt_caption[ screen = iv_screen
                                  field  = to_upper( l-field_name ) ] ). CONTINUE. ENDIF.
*     A bound row is a control too, whatever text it carries.
      IF l-technical_name IS NOT INITIAL OR l-tosave = 'X'. CONTINUE. ENDIF.
      IF is_code_label( l-text_en ) = abap_true.        CONTINUE. ENDIF.
      IF is_notice( l-text_en ) = abap_true.            CONTINUE. ENDIF.  " guidance, not a heading
      IF l-seq_key < lv_best.
        lv_best = l-seq_key.
        ev_en   = l-text_en.
        ev_ar   = l-text_ar.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD tile_code.
    DATA(lv_p) = to_upper( COND string( WHEN iv_prefix IS INITIAL
                                        THEN c_tile_pfx ELSE iv_prefix ) ).
    DATA(lv_j) = to_upper( iv_journey ).
*   '_' and '-' are legal in a CJS journey id and meaningless in a tile.
    REPLACE ALL OCCURRENCES OF REGEX '[^A-Z0-9]' IN lv_j WITH ``.
    IF strlen( lv_p ) >= c_tile_len.
      rv = substring( val = lv_p off = 0 len = c_tile_len ).
      RETURN.
    ENDIF.
    DATA(lv_room) = c_tile_len - strlen( lv_p ).
    IF strlen( lv_j ) > lv_room.
*     keep the TAIL: 'M011' and 'M035' differ in their last characters,
*     their heads are identical.
      lv_j = substring( val = lv_j off = strlen( lv_j ) - lv_room len = lv_room ).
    ENDIF.
    rv = lv_p && lv_j.
  ENDMETHOD.


  METHOD teardown.
    DATA(jid) = to_upper( iv_cjs_id ).
    SELECT SINGLE tile_code FROM zrak_t_jny INTO @DATA(lv_tile) WHERE journey_id = @jid.
    IF sy-subrc <> 0. ev_msg = |{ jid } not found|. RETURN. ENDIF.
    DELETE FROM zrak_t_jny      WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_step WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_fld  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_opt  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_rule WHERE journey_id = @jid.
    DELETE FROM zrak_t_mig_raw  WHERE cjs_id     = @jid.
    IF lv_tile IS NOT INITIAL.
      DELETE FROM zega_t_cj_grp WHERE journeyid = @lv_tile.
      DELETE FROM zega_t_cj_id  WHERE journeyid = @lv_tile.
      DELETE FROM zega_t_cj_idt WHERE journeyid = @lv_tile.
    ENDIF.
    COMMIT WORK.
    ev_msg = |{ jid } and tile { lv_tile } removed|.
  ENDMETHOD.


  METHOD teardown_all.
    DATA(lv_pat) = |{ to_upper( iv_prefix ) }%|.
    SELECT journey_id FROM zrak_t_jny
      WHERE journey_id LIKE @lv_pat
      INTO TABLE @DATA(lt_jny).
    IF lt_jny IS INITIAL.
      ev_log = |Nothing to remove for prefix { iv_prefix }|. RETURN.
    ENDIF.
    LOOP AT lt_jny INTO DATA(lv_jid).
      teardown( EXPORTING iv_cjs_id = CONV #( lv_jid ) IMPORTING ev_msg = DATA(lv_msg) ).
      ev_log = ev_log && lv_msg && |{ cl_abap_char_utilities=>newline }|.
    ENDLOOP.
    DELETE FROM zrak_t_mig_raw WHERE cjs_id LIKE @lv_pat.
    COMMIT WORK.
    ev_log = ev_log && |{ lines( lt_jny ) } sandbox journeys removed|.
  ENDMETHOD.
ENDCLASS.
