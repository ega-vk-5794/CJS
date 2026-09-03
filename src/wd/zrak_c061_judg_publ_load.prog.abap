*&---------------------------------------------------------------------*
*& Report ZRAK_C061_JUDG_PUBL_LOAD
*& Loader — Judgement Publications (JP1) journey configuration.
*& Populates ZRAK_T_JNY / _STEP / _FLD / _COL / _OPT / _RULE plus the
*& portal registration. Mirrors ZRAK_C022_LOAD. Idempotent per journey_id.
*&
*& Migrated from WebDynpro component ZWDC_ESERV_JUD_PUBL (application
*& ZWDA_ESERV_JUD_PUBL). Read-only service: it searches published court
*& judgments and displays one. Nothing is created, so there is no Submit
*& and no payment - see the NO_SUBMIT note on the handler.
*&---------------------------------------------------------------------*
REPORT zrak_c061_judg_publ_load.
*&---------------------------------------------------------------------*
*& EDIT THIS BLOCK ONLY
*&---------------------------------------------------------------------*
CONSTANTS:
  c_jid  TYPE zrak_t_jny-journey_id    VALUE 'JP1',
  c_bcod TYPE zrak_t_jny-bknd_journey  VALUE '',                 " no existing backend
  c_bcat TYPE zrak_t_jny-bknd_category VALUE '',                 " no backend category
  c_tile TYPE zrak_t_jny-tile_code     VALUE 'JP1',
  c_hcls TYPE zrak_t_jny-handler_class VALUE 'ZCL_C061_JUDGEMENT_PUBL_LOGIC',
  c_dept TYPE zega_t_cj_grp-department VALUE '1',
  c_main TYPE zega_t_cj_grp-journeyid  VALUE '901'.              " "AI Driven Journeys" group

PARAMETERS p_simul AS CHECKBOX DEFAULT ' '.   " tick = validate only, nothing committed

START-OF-SELECTION.

* ---- Idempotency: clear this journey's own rows ----------------------
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jid.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jid.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jid.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jid.
  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jid.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jid.

* ---- Header ----------------------------------------------------------
* SHOW_ACTIONS stays BLANK, unlike AS3. It is the switch for Save-as-Draft
* and Delete in the page header, and neither has any meaning here: there is
* no application to save and none to delete. A Delete button on a search
* screen is not merely useless, it invites the citizen to press it.
*
* DRAFT_MODE is left blank for the same reason - RESOLVE_DRAFT_MODE( )
* answers "off" and the engine keeps no draft row for this journey.
*
* The English title comes from OTR concept 9EFD37829E031EDA81A7E3B4AF80841A
* ("Judgement Publications"), which the WD assigns to SH_HEADER_TITLE. That
* element carries VISIBLE = 01, so the legacy screen never actually showed
* it and the concept has no Arabic text recorded. The Arabic below is
* therefore OURS, not the WD's - have it confirmed before go-live.
  INSERT zrak_t_jny FROM @( VALUE #(
  mandt = sy-mandt journey_id = c_jid
  title = 'Judgement Publications'
  title_ar = |نشر الأحكام|
  layout_mode = 'WIZARD' theme_variant = 'PREMIUM' accent_type = 'Emphasized'
  brand_color = 'rgb(196,30,38)' navy_color = 'rgb(16,35,62)' density = 'Cozy'
  subtitle = 'Search and view a published court judgment'
  subtitle_ar = |البحث عن حكم منشور وعرضه|
  show_actions = '' active = 'X'
  handler_class = c_hcls
  bknd_category = c_bcat bknd_journey = c_bcod
  bknd_active   = ''                           " no existing backend (bridge ignored)
  tile_code     = c_tile ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Header insert failed' TYPE 'E'. ENDIF.

* ---- Steps -----------------------------------------------------------
* Two steps, and the SECOND ONE IS WHAT SUPPRESSES "NEXT" ON THE FIRST.
* ZCL_RAK_JOURNEY_RENDER->RENDER_FOOTER( ) walks the steps after the current
* one and, when every one of them is a "result step", draws no Next at all;
* IS_RESULT_STEP( ) calls a step that only when each of its visible fields is
* DISPLAY, READONLY or RESULT. JDGM carries exactly one visible field,
* JUDGMENT, of FTYPE 'DISPLAY' - so SRCH ends with Close rather than Next,
* which is right: nothing on the search screen is answered by moving forward.
* The way into JDGM is picking a row, which the handler does with
* ADVANCE_STEP( ). Add any input-like field to JDGM and Next comes back on
* SRCH, so keep JDGM's state in the hidden fields carried on SRCH.
*
* COLUMNS 3 on SRCH matches the WD's two rows of three; 1 on JDGM because the
* judgment is one column of running text.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' seqnr = 10 title = 'Search Option' title_ar = |خيارات البحث| icon = 'sap-icon://search' columns = 3 active = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'JDGM' seqnr = 20 title = 'Judgment' title_ar = |الحكم| icon = 'sap-icon://document-text' columns = 1 active = 'X' )
  ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Step insert failed' TYPE 'E'. ENDIF.

* ---- Fields ----------------------------------------------------------
* LABELS come from the screenshots of the live screen, English and Arabic
* side by side, because the five search labels are OTR CONCEPTS (GUIDs on the
* view's TEXT property) rather than OTR ALIASES: SOTR_GET_TEXT_KEY takes an
* alias, so a concept cannot be read at runtime the way the judgment screen's
* nineteen aliases can. LB_CLASSIFY_TYPE has no OTR text at all in the WD -
* its caption exists only on screen - so "Classification" / "تصنيف" is read
* off the screenshots for that one either way.
*
* REQUIRED follows the WD's own STATE property: DD_COURT_TYPE and
* DD_CASE_YEAR carry STATE = 01 (mandatory, and the screenshots show the red
* asterisk on both); DD_CLASSIFY_TYPE, DD_CASE_TYPE and IN_CASE_NUMBER carry
* STATE = 00. Note that nothing in the ENGINE enforces REQUIRED here - it
* draws the asterisk, but MISSING_REQUIRED only runs from COMMIT_STEP( ) and
* this step has no Next to trigger it. The Search button is the gate, and the
* handler checks both fields itself before it calls the RFC, exactly as the
* WD's CHECK_MANDATORY_ATTR_ON_VIEW did.
*
* CLOSED_LIST is deliberately NOT set on the four dropdowns, for the same
* reason it is held back on AS3 and re-verified against feature/dev at
* 20a59be: the CLOSED_LIST branch renders sap.m.Select without passing
* FORCESELECTION, Z2UI5_CL_XML_VIEW omits a property whose value is blank,
* and UI5's own default for FORCESELECTION is true - so a field still holding
* nothing would render showing the FIRST option while the model stayed empty.
* On this journey that is worse than on AS3: Court Type is mandatory, so a
* screen that looks answered when it is not would let the citizen press
* Search and be told to fill in a field they can see filled in. This is
* engine point R7-1; reinstate when it passes FORCESELECTION = ABAP_FALSE.
*
* THE PRICE OF HOLDING IT BACK, and it is not only cosmetic. A ComboBox is
* TYPABLE, so all four of these accept anything - which the WD's own
* DropDownByKey did not. CASE_YEAR is then moved into a local typed
* ZADTEL00008R to be handed to ZFM_JUDGEMENT_PUBLICATION, and if that data
* element is numeric a typed 'abcd' is CX_SY_CONVERSION_NO_NUMBER on the
* assignment - the same uncatchable shape as the date dump AS3 hit. So
* ZCL_C061_JUDGEMENT_PUBL_LOGIC's OPT_REJECT( ) refuses any value that is not
* one of the options the handler itself offered, before the search runs.
* Delete that guard when CLOSED_LIST goes back on.
*
* DOMNAME is carried on the two domain-backed dropdowns even though the
* handler answers them in ON_VALUE_HELP, which the renderer consults FIRST
* (config options, then ON_VALUE_HELP, then API:, then the DDIC resolver). It
* is not dead: it documents where the values come from, and it is what the
* DDIC resolver would fall back to if the handler ever stopped answering.
*
* THE HIDDEN FIELDS ARE THE JOURNEY'S MEMORY. The handler is re-instantiated
* per round-trip whenever the engine's own instance did not survive, so no
* instance attribute can be relied on to hold the search result or the
* judgment between one click and the next. Everything both steps need is
* therefore a model field, and every one of them lives on SRCH so that JDGM
* keeps its single-visible-field shape (see the step note above).
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   STEP SRCH - the search form -------------------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'COURT_TYPE' seqnr = 10
  ftype = 'SELECT' required = 'X' zlabel = 'Court Type' zlabel_ar = |درجة القضاء|
  fgroup = 'ROW:S1' domname = 'ZDO_COURT_TYPE'
  tech_name = 'SEARCH_OPTION-COURT_TYPE'
  msg = 'Court Type is required' msg_ar = |درجة القضاء مطلوبة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'CLASSIFY_TYPE' seqnr = 20
  ftype = 'SELECT' zlabel = 'Classification' zlabel_ar = |تصنيف|
  fgroup = 'ROW:S1' domname = 'ZDO_COURT_CLASSIFY_TYPE'
  tech_name = 'SEARCH_OPTION-CLASSIFY_TYPE' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'CASE_TYPE' seqnr = 30
  ftype = 'SELECT' zlabel = 'Case/File Type' zlabel_ar = |نوع القضية/الملف|
  fgroup = 'ROW:S1'
  tech_name = 'SEARCH_OPTION-CASE_TYPE' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'CASE_YEAR' seqnr = 40
  ftype = 'SELECT' required = 'X' zlabel = 'Case Year' zlabel_ar = |السنة|
  fgroup = 'ROW:S2'
  tech_name = 'SEARCH_OPTION-CASE_YEAR'
  msg = 'Case Year is required' msg_ar = |السنة مطلوبة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'CASE_NUMBER' seqnr = 50
  ftype = 'INPUT' max_len = 8 zlabel = 'Case/File No.' zlabel_ar = |رقم القضية/الملف|
  fgroup = 'ROW:S2'
  tech_name = 'SEARCH_OPTION-CASE_NUMBER' )
*   The result list. FTYPE 'TABLE' is a BLOCK type, which means the renderer
*   reaches it through RENDER_BLOCK( ) and never calls RENDER_FIELD( ) for
*   it - so the handler cannot draw this one itself and supplies its rows
*   through GET_TABLE( ) instead. Columns and headers come from there too,
*   which is what makes the headers bilingual: unlike the KEY:Label:TYPE
*   spec in DEFAULT_VAL, GET_TABLE( ) is code and can pick a language.
*
*   DEFAULT_VAL names the field a picked row is written to. That single
*   value is what turns the table from a list into a selector: the renderer
*   makes every row Active with a ROWPICK_JUD_LIST~<key> event, the engine
*   answers it with VAL_SET( 'SEL_GUID', <key> ) followed by
*   ON_CHANGE( 'SEL_GUID' ), and the key is the row's FIRST CELL. That is
*   why GET_TABLE( ) puts the case GUID in column 1 and gives it the header
*   '-', which the renderer reads as "hide this column": the key has to be
*   there, the citizen must not see it.
*
*   HIDDEN = 'X' is the initial state, not the permanent one. The WD called
*   SET_VISIBILITY( '01' / '02' ) to hide the ALV until a search returned
*   rows; the handler does the same with SET_HIDDEN( ), which outranks this
*   flag for the rest of the session.
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JUD_LIST' seqnr = 60
  ftype = 'TABLE' hidden = 'X' default_val = 'SEL_GUID'
  zlabel = 'Search Result' zlabel_ar = |نتيجة البحث| )
*   ---- the journey's memory, all hidden ---------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'SEL_GUID' seqnr = 100
  ftype = 'INPUT' hidden = 'X' zlabel = 'Selected case GUID' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JUD_ROWS' seqnr = 110
  ftype = 'INPUT' hidden = 'X' zlabel = 'Packed search result' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_COURT' seqnr = 120
  ftype = 'INPUT' hidden = 'X' zlabel = 'Court type of the picked case' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_TITLE2' seqnr = 130
  ftype = 'INPUT' hidden = 'X' zlabel = 'Verdict title' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_HEAD1' seqnr = 140
  ftype = 'INPUT' hidden = 'X' zlabel = 'Header block 1' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_HEAD2' seqnr = 150
  ftype = 'INPUT' hidden = 'X' zlabel = 'Header block 2' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_BP1L' seqnr = 160
  ftype = 'INPUT' hidden = 'X' zlabel = 'Party 1 label' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_BP1V' seqnr = 170
  ftype = 'INPUT' hidden = 'X' zlabel = 'Party 1 names' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_BP2L' seqnr = 180
  ftype = 'INPUT' hidden = 'X' zlabel = 'Party 2 label' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_BP2V' seqnr = 190
  ftype = 'INPUT' hidden = 'X' zlabel = 'Party 2 names' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_JDGL' seqnr = 200
  ftype = 'INPUT' hidden = 'X' zlabel = 'Appealed judgment label' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_JDGV' seqnr = 210
  ftype = 'INPUT' hidden = 'X' zlabel = 'Appealed judgment value' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'SRCH' field_name = 'JD_NOTE' seqnr = 220
  ftype = 'INPUT' hidden = 'X' zlabel = 'Judgment body' )
*   STEP JDGM - the judgment ----------------------------------------
*   ONE visible field, and FTYPE 'DISPLAY' for two reasons that both matter.
*   It is not a block type, so RENDER_ONE( ) runs and with it
*   RENDER_FIELD( ), which is where the handler draws the whole document -
*   header lines, parties, title, body - with the centring and the
*   line-by-line layout the legacy screen had. And DISPLAY is one of the
*   three types IS_RESULT_STEP( ) accepts, which is what keeps Next off the
*   search step. ZLABEL stays blank: RENDER_FIELD( ) returns ABAP_TRUE and
*   the engine draws no label of its own.
  ( mandt = sy-mandt journey_id = c_jid step_id = 'JDGM' field_name = 'JUDGMENT' seqnr = 10
  ftype = 'DISPLAY' )
  ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Field insert failed' TYPE 'E'. ENDIF.

* ---- Grid columns ----------------------------------------------------
* ZRAK_T_JNY_COL stays EMPTY for this journey. It configures the columns of
* an FTYPE 'EDITABLE_TABLE', and JP1 has none - the result list is a
* read-only FTYPE 'TABLE' whose columns come from the handler's GET_TABLE( ).
* The DELETE above already cleared any rows a previous run left behind.

* ---- Options ---------------------------------------------------------
* Also EMPTY, and for a reason worth stating: every one of the four dropdowns
* is answered at RUNTIME, so a fixed option row here would be wrong rather
* than merely redundant - the renderer reads this table FIRST and would stop
* before it ever asked the handler.
*   COURT_TYPE     domain ZDO_COURT_TYPE          (3 fixed values)
*   CLASSIFY_TYPE  domain ZDO_COURT_CLASSIFY_TYPE (3 fixed values)
*   CASE_TYPE      ZDT_EGA_JUD_PUBL joined to ZJDG_CASE_TYPES over RFC, and
*                  re-filtered by whatever COURT_TYPE / CLASSIFY_TYPE hold
*   CASE_YEAR      current year down to 2014, newest first

* ---- Rules -----------------------------------------------------------
* Also EMPTY. The one dependency on this journey - Court Type and
* Classification narrowing the Case/File Type list - is not expressible as a
* value rule: ZRAK_T_JNY_RULE actions change a field's STATE (show, hide,
* enable, require), and what has to change here is a field's OPTION LIST.
* ON_VALUE_HELP is re-consulted on every render, so the list narrows by
* itself; ON_CHANGE only has to drop a Case/File Type that the new filter no
* longer offers, which is a value change and equally not a rule action.

* ---- Portal: register under the 901 "AI Driven Journeys" group -------
  MODIFY zega_t_cj_grp FROM @( VALUE #( mandt = sy-mandt department = c_dept groupid = ''
  journeyid = c_main levelno = 0 orderno = 99 drilldown = 'Y' ) ).
  MODIFY zega_t_cj_id  FROM @( VALUE #( mandt = sy-mandt journeyid = c_main sip_code = c_main ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'E' journeyid = c_main description = 'AI Driven Journeys' ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'A' journeyid = c_main description = |الرحلات الرقمية الذكية| ) ).

* This journey's leaf under 901. zrak_t_jny.tile_code must equal this journeyid.
  MODIFY zega_t_cj_grp FROM @( VALUE #( mandt = sy-mandt department = c_dept groupid = c_main
  journeyid = c_tile levelno = 2 orderno = 20 drilldown = 'N' ) ).
  MODIFY zega_t_cj_id  FROM @( VALUE #( mandt = sy-mandt journeyid = c_tile sip_code = c_tile ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'E' journeyid = c_tile description = 'Judgement Publications' ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'A' journeyid = c_tile description = |نشر الأحكام| ) ).

* ---- Commit ----------------------------------------------------------
  IF p_simul = abap_true.
    ROLLBACK WORK.
    WRITE: / 'SIMULATION — nothing committed. Journey', c_jid, 'validated.'.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.

* ---- Make the engine notice ------------------------------------------
* ZCL_RAK_CJ_CFG_CACHE holds a journey's configuration for 300 seconds and
* only reloads early when the counter in ZRAK_CJ_CFG_VER moves. Committing
* the tables is therefore not enough: without this call a session already
* open keeps serving the previous configuration until the TTL expires, and
* so does every other work process, which is why a re-run could look like it
* had done nothing. INVALIDATE( ) bumps the counter for everyone and clears
* this process's own copy.
  zcl_rak_cj_cfg_cache=>invalidate( CONV string( c_jid ) ).

  WRITE: / 'Seeded', c_jid, '— launch tile', c_tile, 'under group', c_main.
  WRITE: / 'Configuration cache invalidated — the next request reloads.'.
  WRITE: / 'Handler required and must be active:', c_hcls.
