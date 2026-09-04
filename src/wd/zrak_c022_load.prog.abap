*&---------------------------------------------------------------------*
*& Report ZRAK_C022_LOAD
*& Loader — Divorce & Marriage take off (AS3) journey configuration.
*& Populates the 5 ZRAK_T_JNY_* config tables + ZRAK_T_JNY_COL + portal
*& registration. Mirrors ZRAK_E026_TREE_REMOVAL_LOAD. Idempotent per journey_id.
*&---------------------------------------------------------------------*
REPORT zrak_c022_load.
*&---------------------------------------------------------------------*
*& EDIT THIS BLOCK ONLY
*&---------------------------------------------------------------------*
CONSTANTS:
  c_jid  TYPE zrak_t_jny-journey_id    VALUE 'AS3',
  c_bcod TYPE zrak_t_jny-bknd_journey  VALUE '',                 " no existing backend
  c_bcat TYPE zrak_t_jny-bknd_category VALUE '',                 " no backend category
  c_tile TYPE zrak_t_jny-tile_code     VALUE 'AS3',
  c_hcls TYPE zrak_t_jny-handler_class VALUE 'ZCL_C022_KHULA_CERTI_LOGIC',
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
  INSERT zrak_t_jny FROM @( VALUE #(
  mandt = sy-mandt journey_id = c_jid
  title = 'Create Marriage-Take-off Attestation Request'
  title_ar = |إنشاء طلب وثيقة خلع|
  layout_mode = 'WIZARD' theme_variant = 'PREMIUM' accent_type = 'Emphasized'
  brand_color = 'rgb(196,30,38)' navy_color = 'rgb(16,35,62)' density = 'Cozy'
  subtitle = 'Divorce & Marriage take off'
  subtitle_ar = |الطلاق و الخلع|
  show_actions = 'X' active = 'X'
  handler_class = c_hcls
  bknd_category = c_bcat bknd_journey = c_bcod
  bknd_active   = ''                           " no existing backend (bridge ignored)
  tile_code     = c_tile ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Header insert failed' TYPE 'E'. ENDIF.

* ---- Steps -----------------------------------------------------------
* 5 steps; DOCS is the last one, so the engine shows Submit there. No payment
* step: the payer is fixed to the divorcer, so it had nothing to render.
* COLUMNS: 2 where one column would scroll; 3 on PRTY (number|name|Add BP); 1 on DOCS.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' seqnr = 10 title = 'Marriage Contract' title_ar = |عقد الزواج| icon = 'sap-icon://document-text' columns = 2 )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' seqnr = 20 title = 'Divorce Details' title_ar = |تفاصيل الطلاق| icon = 'sap-icon://decision' columns = 2 )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' seqnr = 30 title = 'Marital Status & History' title_ar = |الحالة والتاريخ| icon = 'sap-icon://history' columns = 2 )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' seqnr = 40 title = 'Parties' title_ar = |الأطراف| icon = 'sap-icon://group' columns = 3 )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DOCS' seqnr = 50 title = 'Request & Documents' title_ar = |الطلب والمستندات| icon = 'sap-icon://attachment' columns = 1 )
  ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Step insert failed' TYPE 'E'. ENDIF.

* ---- Fields ----------------------------------------------------------
* PERS_INFO's grid COLUMNS live in ZRAK_T_JNY_COL (loaded further down) - the
* only place a grid column can carry an Arabic header. GRID_COLS reads that
* table first and returns before it parses DEFAULT_VAL, so a column list here
* would never be read; it is not carried.
*
* DEFAULT_VAL still carries the two DIRECTIVES, which have no ZRAK_T_JNY_COL
* equivalent: GRID_FIX and GRID_REACT each SPLIT the field's DEFAULT_VAL
* themselves, independently of GRID_COLS. Drop them and the add/delete chrome
* comes back and the reactive per-row gates stop firing.
*   FIX - fixed row set: no add-row button, no per-row delete column.
*   RX: - the columns whose change fires GRIDCHG_PERS_INFO~<COL> into ON_CHANGE,
*         which recomputes the <COL>_EN gates (see REACT_PERS_INFO).
*
* FIELD_NAME LENGTH - 19 characters or fewer is a readability preference, not a
* correctness rule. ZCL_RAK_JOURNEY_UTIL=>COMP_NAME caps a model component at 23
* characters so every companion the engine derives (_VS and _VST for the
* validation highlight, plus _IDTYPE, _NAME, _IX, _EXP) still fits the 30
* character limit; a longer name is truncated to 18 characters plus a four-digit
* fingerprint of the whole key, so two names sharing a prefix cannot collapse
* onto one component, and ZCL_RAK_CJS_XCHECK warns at save time as well.
*
* FTYPE 'INPUT' + MAX_LEN + REGEX carries the four counts on HIST - two digits
* each, one for the wives count, whose backend column ZZAFLD0000V3 is CHAR(1)
* and would keep only the first character of a longer value.
*
* NOT FTYPE 'NUMBER', which is the obvious choice and does not work. That branch
* renders sap.m.Input with TYPE = 'Number', and an HTML number input ignores
* MAXLENGTH - it is a browser rule, not an engine one, so the cap silently did
* nothing and eleven digits reached VALIDATE_STEP's server-side re-check. On a
* plain INPUT the cap holds at the keyboard, which is what the citizen needs.
*
* REGEX '^[0-9]+$' NOW OWNS "digits only", and it replaces the COUNT_CHECK( )
* method that used to do it in ZCL_C022_KHULA_CERTI_LOGIC. Checked against
* ZCL_RAK_JOURNEY_RULES before the swap, because the two have to be equivalent
* and one of them is being deleted:
*   - VALIDATE_STEP evaluates it, so it fires on Next and on Submit. Same
*     moment COUNT_CHECK fired, being an ON_CUSTOM_VALIDATE row.
*   - it SKIPS A BLANK VALUE ("IF lv_val IS INITIAL. CONTINUE."), so it does
*     not double up with REQUIRED. COUNT_CHECK returned early on blank too.
*   - it calls SET_FIELD_STATE( 'Error' ), so the field turns red with the
*     message as its tooltip - which is what FIELD_ERROR( ) was for.
*   - it runs AFTER MIN_LEN / MAX_LEN / MIN_VAL / MAX_VAL and each of those
*     CONTINUEs on failure, so an over-long value still reports its length
*     rather than its format. No two messages for one field.
*   - a pattern that will not compile is treated as NO CONSTRAINT and only
*     traced. So a typo here fails open, silently. That is the one thing this
*     route is worse at than code, and the reason to leave the pattern alone
*     unless it is re-tested.
*   - it is not enforced at the keyboard. Neither was COUNT_CHECK; nothing is
*     lost, and MAX_LEN remains the only client-side half.
*
* THE MESSAGE. A regex failure uses the field's own MSG / MSG_AR when set, else
* the framework's C_NO-BAD_FORMAT ("&1 has an invalid format" / "صيغة &1 غير
* صحيحة") with the label substituted - bilingual either way. MISSING_REQUIRED
* reads the SAME column for its "is required" text, and until engine point R8-2
* landed one column could not say both things: the two checks never fire
* together (required needs a blank value, a format check needs a filled one),
* but a field still had one sentence to write for both.
*
* R8-2 IS CLOSED AND MSG NOW TAKES KEYED CLAUSES, separated by ';':
*
*   REQUIRED:<text>;LEN:<text>;RANGE:<text>;NUMBER:<text>;FORMAT:<text>
*   *:<text>                              catch-all for any check with no
*                                         clause of its own
*
* Each clause splits on its FIRST colon, which is what lets a clause's own text
* be an OTR:<alias> or an @nnn (a ZRAK_T_CJ_TXT row). A clause missing for the
* check that fired means BLANK, and the caller then falls back to the
* catalogue - so a check needs a clause only where the catalogue is not already
* right. The keyed form is recognised only when the text BEGINS with a
* recognised key immediately followed by ':', so an ordinary sentence that
* happens to contain a colon is still plain wording.
*
* So the four count fields land like this:
*   CHILDREN_COUNT, CHILDREN_UNDER_21   never required, by flag or by rule, so
*                                       plain MSG is unambiguous and carries the
*                                       digits wording COUNT_CHECK produced
*   PREV_DIVORCES_COUNT (required by     plain MSG, the mandatory text. Its
*   rule R04)                            digits failure falls back to
*                                        C_NO-BAD_FORMAT, which names the field
*                                        and is right as it stands
*   WIVES_COUNT_HUSBAND                 KEYED, because it is the one field with
*                                       a WD message of its own to honour
*
* THE WIVES COUNT GETS ITS WD WORDING BACK. VALIDATE_NUMERIC in the WD read
* ZZAFLD0000V3 and nothing else, and reported it through OTR concept
* Z_RAKEGA_MUNI/ZWDC_DIV_REQUE_ATT_MSG. The FORMAT: clause carries that ALIAS
* rather than a transcription of its text, so MSG_TOKEN( ) resolves it at
* runtime in the engine's language - which is the rule about following a WD OTR
* text satisfied exactly, rather than approximated by copying words out of it.
*
* MAX_VAL = 9 ON THAT FIELD, and the "cannot be more than 9" check is gone from
* ON_CUSTOM_VALIDATE with it. VALIDATE_STEP's numeric gate covers FTYPE 'INPUT',
* and its message needs no RANGE: clause: C_NO-NUM_MAX is "&1 must be at most
* &2" / "يجب ألا يتجاوز &1 &2", which with the label and the bound reads better
* than the literal the handler used to build. The invariant behind the 9 is the
* backend column: ZZAFLD0000V3 is CHAR(1) and keeps only the first character of
* anything longer.
*
* CLOSED_LIST IS SET on all fourteen FTYPE 'SELECT' rows, and it was held back
* for months before it could be. Every field here is a genuinely closed list -
* nothing a citizen types into one can be accepted - so the type-ahead ComboBox
* the engine draws by default only invited pointless typing and popped a
* keyboard on a touch device for nothing.
*
* What blocked it was engine point R7-1: the CLOSED_LIST branch renders
* sap.m.Select, whose FORCESELECTION defaults to TRUE, and the engine did not
* pass it - so a field still holding nothing rendered showing its FIRST option
* while the model stayed empty. The screen disagreed with the data: rules keyed
* on the field did not fire, and a mandatory check refused a field the citizen
* could see filled in. A typable dropdown was the much smaller problem.
*
* Closed and activated 3 Sep - ZCL_RAK_JOURNEY_RENDER now passes
* FORCESELECTION = ABAP_FALSE on that branch.
*
* WATCH MARR_CONSUMMATED AND ISOLATION FIRST when testing this. sap.m.Select
* has no EDITABLE property - it is a picker, not a text field - so the engine
* maps READONLY / EDITABLE onto ENABLED instead, and those two are the only
* fields here toggled by rules (R16 / R17 on CASE_UPON_DIVORCE).
*
* FTYPE 'READONLY' carries CONTRACT_PLACE, DIVORCEE_PARTNER and
* DIVORCER_PARTNER, which are starred but written by a popup or by ON_INIT,
* never typed. MISSING_REQUIRED enforces their REQUIRED flag and the 'READONLY'
* render branch binds VALUESTATE, so they block the step and turn red like any
* other field. Their MSG / MSG_AR name the party, which the engine's generic
* required text cannot do for a field the citizen cannot click.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   STEP MARR ------------------------------------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'COURT' seqnr = 10 ftype = 'READONLY'
  readonly = 'X' zlabel = 'Court' zlabel_ar = |محكمة| fgroup = 'ROW:M1'
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000U4' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'EMIRATE' seqnr = 20
  ftype = 'READONLY' readonly = 'X' zlabel = 'Emirate' zlabel_ar = |الإمارة| fgroup = 'ROW:M1'
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UG' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'CONTRACT_PLACE' seqnr = 30
  ftype = 'READONLY' required = 'X' readonly = 'X' zlabel = 'Contract Place' zlabel_ar = |مكان الإصدار|
  fgroup = 'ROW:M2' tech_name = 'NO_DIV_MARR_TAKEOFF-ZZAFLD00004D'
  msg = 'Contract place is required' msg_ar = |مكان الإصدار مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'MARR_CONTRACT_NO' seqnr = 40
  ftype = 'INPUT' required = 'X' zlabel = 'Marriage contract number' zlabel_ar = |رقم عقد الزواج| fgroup = 'ROW:M2'
  max_len = 10 tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000U3'
  msg = 'Marriage contract number is required' msg_ar = |رقم عقد الزواج مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'MARR_CONTRACT_PLACE' seqnr = 50
  ftype = 'INPUT' required = 'X' zlabel = 'Marriage contract place' zlabel_ar = |مكان عقد الزواج| fgroup = 'ROW:M3'
  max_len = 60 tech_name = 'NO_DIV_MARR_TAKEOFF-ZZAFLD00008L'
  msg = 'Marriage contract place is required' msg_ar = |مكان عقد الزواج مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'FAM_GUIDANCE_APPR' seqnr = 60
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Family guidance approval' zlabel_ar = |عرض على التوجيه الأسري|
  fgroup = 'ROW:M3' domname = 'ZADTEL0001TL' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UN'
  msg = 'Family guidance approval is required' msg_ar = |عرض على التوجيه الأسري مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'MARR_GRANT_RECEIVED' seqnr = 70
  ftype = 'SELECT' closed_list = 'X' zlabel = 'Was a marriage grant received?' zlabel_ar = |هل تم إستلام منحة زواج|
  fgroup = 'ROW:M4' domname = 'ZADTEL0001TM' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UO' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'GRANT_SIDE' seqnr = 80
  ftype = 'INPUT' zlabel = 'Grant side' zlabel_ar = |جهة المنحة| fgroup = 'ROW:M4'
  max_len = 20 tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UH' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'LAST_MARR_DATE' seqnr = 90
  ftype = 'DATE' hidden = 'X' zlabel = 'Last marriage date' zlabel_ar = |تاريخ الزواج الأخير بين الطرفين|
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UC' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'LAST_MARR_CTR_DT' seqnr = 100
  ftype = 'DATE' hidden = 'X' zlabel = 'Last marriage contract date'
  zlabel_ar = |تاريخ عقد الزواج الأخير| tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UD' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'MARR' field_name = 'MARR_CONTRACT_DATE' seqnr = 110
  ftype = 'DATE' required = 'X' zlabel = 'Marriage contract date' zlabel_ar = |تاريخ عقد الزواج| fgroup = 'ROW:M5'
  tech_name = 'NO_DIV_MARR_TAKEOFF-ZZAFLD00008K'
  msg = 'Marriage contract date is required' msg_ar = |تاريخ عقد الزواج مطلوب| )
*   STEP DIVO ------------------------------------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_DECL_TYPE' seqnr = 10
  ftype = 'SELECT' closed_list = 'X' zlabel = 'Type of divorce declaration' zlabel_ar = |نوع إقرار الطلاق|
  fgroup = 'ROW:D1' domname = 'ZADTEL0001TN' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UP' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_TYPE' seqnr = 20
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Type of divorce' zlabel_ar = |نوع الطلاق| fgroup = 'ROW:D1'
  domname = 'ZADTEL0001TO' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UQ'
  msg = 'Type of divorce is required' msg_ar = |نوع الطلاق مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_APPLICANT' seqnr = 30
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Divorce applicant' zlabel_ar = |طالب الطلاق| fgroup = 'ROW:D2'
  domname = 'ZADTEL0001TP' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UR'
  msg = 'Divorce applicant is required' msg_ar = |طالب الطلاق مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_METHOD' seqnr = 40
  ftype = 'SELECT' closed_list = 'X' zlabel = 'The method of divorce' zlabel_ar = |طريقة الطلاق| fgroup = 'ROW:D2'
  domname = 'ZADTEL0001TQ' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000US' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_WORDS' seqnr = 50
  ftype = 'INPUT' zlabel = 'Divorce words' zlabel_ar = |صيغة الطلاق| fgroup = 'ROW:D3' max_len = 60
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UI' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_PLACE' seqnr = 60
  ftype = 'INPUT' zlabel = 'Divorce Place' zlabel_ar = |مكان الطلاق| fgroup = 'ROW:D3'
  max_len = 20 tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UJ' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_REASON' seqnr = 70
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Divorce reason' zlabel_ar = |سبب الطلاق| fgroup = 'ROW:D4'
  domname = 'ZADTEL0001TR' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UT'
  msg = 'Divorce reason is required' msg_ar = |سبب الطلاق مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_REASON_DETAILS' seqnr = 80
  ftype = 'INPUT' zlabel = 'Divorce reason details' zlabel_ar = |سبب الطلاق بالتفصيل| fgroup = 'ROW:D4'
  max_len = 60 tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UK' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DIVO' field_name = 'DIV_KHULA_DATE' seqnr = 90
  ftype = 'DATE' required = 'X' zlabel = 'Date of divorce or khula' zlabel_ar = |تاريخ الطلاق أو الخلع أو التطليق|
  fgroup = 'ROW:D5' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UB'
  msg = 'Date of divorce or khula is required' msg_ar = |تاريخ الطلاق أو الخلع أو التطليق مطلوب| )
*   STEP HIST ------------------------------------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'RELATIVE_RELATION' seqnr = 10
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Relative relation' zlabel_ar = |صلة القرابة بين المطلقين| fgroup = 'ROW:H1'
  domname = 'ZADTEL0001T4' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000U6'
  msg = 'Relative relation is required' msg_ar = |صلة القرابة بين المطلقين مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'STATUS_UPON_MARR' seqnr = 20
  ftype = 'SELECT' closed_list = 'X' zlabel = 'Status of the divorced upon marriage'
  zlabel_ar = |حالة المطلقة عند عقد الزواج| fgroup = 'ROW:H1' domname = 'ZADTEL0001TS'
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UU' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'CASE_UPON_DIVORCE' seqnr = 30
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Divorced case upon divorce' zlabel_ar = |حالة المطلقة عند الطلاق|
  fgroup = 'ROW:H2' domname = 'ZADTEL0001TT' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UV'
  msg = 'Divorced case upon divorce is required' msg_ar = |حالة المطلقة عند الطلاق مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'MARR_CONSUMMATED' seqnr = 40
  ftype = 'SELECT' closed_list = 'X' zlabel = 'Marriage consummated' zlabel_ar = |تم الدخول| fgroup = 'ROW:H2'
  domname = 'ZADTEL0001TU' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UW'
  msg = 'Marriage consummated is required' msg_ar = |تم الدخول مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'ISOLATION' seqnr = 50
  ftype = 'SELECT' closed_list = 'X' zlabel = 'Isolation' zlabel_ar = |تمت الخلوة| fgroup = 'ROW:H3'
  domname = 'ZADTEL0001TV' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UX'
  msg = 'Isolation is required' msg_ar = |تمت الخلوة مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'CHILDREN_COUNT' seqnr = 60
  ftype = 'INPUT' zlabel = 'No. of children' zlabel_ar = |عدد الابناء| fgroup = 'ROW:H3'
  max_len = 2 regex = '^[0-9]+$' tech_name = 'NO_DIV_MARR_TAKEOFF-ZZAFLD00008M'
  msg = 'Please enter numbers only for No. of children'
  msg_ar = |الرجاء ادخال ارقام فقط في حقل عدد الابناء| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'MARR_PROVING_DATE' seqnr = 70
  ftype = 'DATE' zlabel = 'Marriage proving date' zlabel_ar = |تاريخ الدخول| fgroup = 'ROW:H4'
  tech_name = 'NO_DIV_MARR_TAKEOFF-ZZAFLD00008N' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'CHILDREN_UNDER_21' seqnr = 80
  ftype = 'INPUT' zlabel = 'Children under 21' zlabel_ar = |عدد الأولاد أقل من 21 سنة| fgroup = 'ROW:H4'
  max_len = 2 regex = '^[0-9]+$' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UL'
  msg = 'Please enter numbers only for Children under 21'
  msg_ar = |الرجاء ادخال ارقام فقط في حقل عدد الأولاد أقل من 21 سنة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'WIVES_COUNT_HUSBAND' seqnr = 90
  ftype = 'INPUT' required = 'X' zlabel = 'Number of waives for husband' zlabel_ar = |عدد الزوجات في عصمة الزوج|
  fgroup = 'ROW:H5' max_len = 1 regex = '^[0-9]+$' max_val = '9'
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000V3'
  msg = 'REQUIRED:Number of waives for husband is required;' &&
        'FORMAT:OTR:Z_RAKEGA_MUNI/ZWDC_DIV_REQUE_ATT_MSG'
  msg_ar = |REQUIRED:عدد الزوجات في عصمة الزوج مطلوب;| &&
           |FORMAT:OTR:Z_RAKEGA_MUNI/ZWDC_DIV_REQUE_ATT_MSG| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'EARLIER_MARRIAGES' seqnr = 100
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Earlier marriages' zlabel_ar = |هل تم الزواج من قبل بين الطرفين|
  fgroup = 'ROW:H5' domname = 'ZADTEL0001TW' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UY'
  msg = 'Earlier marriages is required' msg_ar = |هل تم الزواج من قبل بين الطرفين مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'FIRST_MARR_CTR_DT' seqnr = 105
  ftype = 'DATE' zlabel = 'First marriage contract date' zlabel_ar = |تاريخ عقد الزواج الأول بين الطرفين|
  fgroup = 'ROW:H6' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UE'
  msg = 'First marriage contract date is required' msg_ar = |تاريخ عقد الزواج الأول بين الطرفين مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'PREV_DIVORCES_COUNT' seqnr = 110
  ftype = 'INPUT' zlabel = 'The number of previous divorces'
  zlabel_ar = |عدد حالات الطلاق السابقة بين الطرفين| fgroup = 'ROW:H6'
  max_len = 2 regex = '^[0-9]+$' tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UM'
  msg = 'The number of previous divorces is required' msg_ar = |عدد حالات الطلاق السابقة بين الطرفين مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'HIST' field_name = 'LAST_DIV_DATE' seqnr = 120
  ftype = 'DATE' zlabel = 'Last divorce date' zlabel_ar = |تاريخ الطلاق السابق| fgroup = 'ROW:H7'
  tech_name = 'NO_DIV_MARR_TAKEOF-ZZAFLD0000UF'
  msg = 'Last divorce date is required' msg_ar = |تاريخ الطلاق السابق مطلوب| )
*   STEP PRTY ------------------------------------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO' seqnr = 10
  ftype = 'EDITABLE_TABLE' required = 'X' zlabel = 'Personal information' zlabel_ar = |البيانات الشخصية للاطراف|
  default_val = 'FIX|RX:ZZAFLD0000TT,ZZAFLD0000TW' tech_name = 'PERS_INFO' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_PARTNER' seqnr = 20
  ftype = 'READONLY' required = 'X' readonly = 'X' zlabel = 'Divorcee' zlabel_ar = |المطلقة| fgroup = 'ROW:P1'
  max_len = 10 tech_name = 'NO_PARTIES_INVOLVED2-DIVORCEE_BP'
  msg = 'The divorcee is required' msg_ar = |يجب إضافة المطلقة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_NAME' seqnr = 30
  ftype = 'READONLY' readonly = 'X' zlabel = 'Divorcee name' zlabel_ar = |اسم المطلقة| fgroup = 'ROW:P1'
  max_len = 35 tech_name = 'NO_PARTIES_INVOLVED2-DIVORCEE_NAME' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_PARTNER' seqnr = 40
  ftype = 'READONLY' required = 'X' readonly = 'X' zlabel = 'Divorcer' zlabel_ar = |المطلق| fgroup = 'ROW:P2'
  max_len = 10 tech_name = 'NO_PARTIES_INVOLVED2-DIVORCER_BP'
  msg = 'The divorcer is required' msg_ar = |يجب إضافة المطلق| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_NAME' seqnr = 50
  ftype = 'READONLY' readonly = 'X' zlabel = 'Divorcer name' zlabel_ar = |اسم المطلق| fgroup = 'ROW:P2'
  max_len = 35 tech_name = 'NO_PARTIES_INVOLVED2-DIVORCER_NAME' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_PARTNER' seqnr = 60
  ftype = 'READONLY' readonly = 'X' zlabel = 'Witness 1' zlabel_ar = |الشاهد الأول| fgroup = 'ROW:P3'
  max_len = 10 tech_name = 'NO_PARTIES_INVOLVED2-WITNESS1_BP' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_NAME' seqnr = 70
  ftype = 'READONLY' readonly = 'X' zlabel = 'Witness 1 name' zlabel_ar = |اسم الشاهد الأول|
  fgroup = 'ROW:P3' max_len = 35 tech_name = 'NO_PARTIES_INVOLVED2-WITNESS1_NAME' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_PARTNER' seqnr = 80
  ftype = 'READONLY' readonly = 'X' zlabel = 'Witness 2' zlabel_ar = |الشاهد الثاني| fgroup = 'ROW:P4'
  max_len = 10 tech_name = 'NO_PARTIES_INVOLVED2-WITNESS2_BP' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_NAME' seqnr = 90
  ftype = 'READONLY' readonly = 'X' zlabel = 'Witness 2 name' zlabel_ar = |اسم الشاهد الثاني|
  fgroup = 'ROW:P4' max_len = 35 tech_name = 'NO_PARTIES_INVOLVED2-WITNESS2_NAME' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_SEARCHBY' seqnr = 100
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcee — Search by (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_IDNUM' seqnr = 110
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcee — ID number (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_DOB' seqnr = 120
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcee — Date of birth (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_NAT' seqnr = 130
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcee — Nationality (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_PHONE' seqnr = 150
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcee — Phone (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCEE_EMAIL' seqnr = 160
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcee — Email (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_SEARCHBY' seqnr = 170
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcer — Search by (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_IDNUM' seqnr = 180
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcer — ID number (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_DOB' seqnr = 190
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcer — Date of birth (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_NAT' seqnr = 200
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcer — Nationality (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_PHONE' seqnr = 220
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcer — Phone (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'DIVORCER_EMAIL' seqnr = 230
  ftype = 'INPUT' hidden = 'X' zlabel = 'Divorcer — Email (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_SEARCHBY' seqnr = 240
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness1 — Search by (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_IDNUM' seqnr = 250
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness1 — ID number (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_DOB' seqnr = 260
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness1 — Date of birth (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_NAT' seqnr = 270
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness1 — Nationality (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_PHONE' seqnr = 290
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness1 — Phone (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS1_EMAIL' seqnr = 300
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness1 — Email (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_SEARCHBY' seqnr = 310
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness2 — Search by (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_IDNUM' seqnr = 320
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness2 — ID number (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_DOB' seqnr = 330
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness2 — Date of birth (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_NAT' seqnr = 340
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness2 — Nationality (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_PHONE' seqnr = 360
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness2 — Phone (BP popup)' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'WITNESS2_EMAIL' seqnr = 370
  ftype = 'INPUT' hidden = 'X' zlabel = 'Witness2 — Email (BP popup)' )
*   STEP DOCS ------------------------------------------------------
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DOCS' field_name = 'REQUEST_TEXT' seqnr = 10
  ftype = 'TEXTAREA' required = 'X' zlabel = 'Request text' zlabel_ar = |نص الطلب|
  tech_name = 'NO_DIV_MARR_TAKEOFF-TEXT_Z11'
  msg = 'Request text is required' msg_ar = |نص الطلب مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DOCS' field_name = 'DOCUMENT_TYPE' seqnr = 20
  ftype = 'SELECT' closed_list = 'X' required = 'X' zlabel = 'Document Type' zlabel_ar = |نوع المرفق| domname = 'ZDO_EGA_DOCUMENT_TYPE'
  tech_name = 'SELECTED_DD_VALUES-SELECTED_DOC_TYPE'
  msg = 'Document Type is required' msg_ar = |نوع المرفق مطلوب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'DOCS' field_name = 'ATTACHMENT' seqnr = 30
  ftype = 'UPLOAD' required = 'X' zlabel = 'Attachment' zlabel_ar = |المرفقات| has_attach = 'X'
  attach_types = 'AVI,BMP,DOC,DOCX,DWG,JPEG,JPG,MP4,PDF,PNG,PPT,RAR,TIF,TIFF,XLS,XLSX,ZIP'
  attach_maxmb = 5 tech_name = 'ATTACHMENT-FILE_DATA' )
  ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Field insert failed' TYPE 'E'. ENDIF.

* ---- Grid columns (PERS_INFO) ----------------------------------------
* ZRAK_T_JNY_COL is the per-column config table and the ONLY definition of
* PERS_INFO's columns - the field's DEFAULT_VAL carries directives only.
* GRID_COLS calls COL_ROWS_OF first and returns as soon as it finds rows, so
* these rows are what the model builder, the renderer, the backend payload and
* MISSING_REQUIRED all see. This is also the only mechanism that carries an
* Arabic column header: RENDER_GRID picks ZLABEL_AR when mv_lang = 'A' and it
* is filled, else ZLABEL.
*
* Three rules this block obeys:
*  - ROLLNAME stays EMPTY on every SELECT column. It is the grid's option
*    source and it WINS over the handler: a filled ROLLNAME makes F4_OPTS
*    resolve the list and ON_VALUE_HELP is never called, so a domain put here
*    renders an empty dropdown. ZCL_C022_KHULA_CERTI_LOGIC answers the dotted
*    key PERS_INFO.<COLUMN> for all five domain-backed columns.
*  - The reactive gates keep their own rows. RENDER_GRID looks up the gate as
*    lt_gc[ name = '<COL>_EN' ] in this same column list, so each _EN column
*    must exist here too, HIDDEN = 'X'. Its CTRL is never drawn but must be a
*    valid type, so INPUT.
*  - HIDDEN is its own column here. In the DEFAULT_VAL spec, HIDE lived in the
*    type slot; in this table the real type goes in CTRL and HIDDEN carries the
*    flag, so a hidden column can be turned back on without losing its type.
*
* REQUIRED is set on the three columns the WD screen stars: ZZAFLD0000V2
* (Partner type), ZZAFLD0000TT (Residence status), ZZAFLD0000TW (Job status).
* MISSING_REQUIRED checks a required column against every row that already
* exists and blocks the step on the first blank cell; RENDER_GRID appends ' *'
* to the header. The PERS_INFO field row above carries REQUIRED = 'X' as well,
* and that is a prerequisite rather than decoration: MISSING_REQUIRED skips a
* field whose own IS_REQUIRED is false before it ever reaches the per-column
* loop, so the column flags alone would enforce nothing. The grid field itself
* is never reported as empty - the EDITABLE_TABLE branch CONTINUEs past the
* scalar value check.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000V2' seqnr = 10 ctrl = 'SELECT' readonly = 'X' required = 'X'
  zlabel = 'Partner type' zlabel_ar = |نوع الطرف| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000V0' seqnr = 15 ctrl = 'INPUT' hidden = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TT' seqnr = 20 ctrl = 'SELECT' required = 'X'
  zlabel = 'Residence status' zlabel_ar = |حالة الإقامة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TU_EN' seqnr = 30 ctrl = 'INPUT' hidden = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TU' seqnr = 40 ctrl = 'INPUT' maxlen = 7
  zlabel = 'Village number' zlabel_ar = |رقم البلدة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TV' seqnr = 50 ctrl = 'SELECT'
  zlabel = 'Doctrine' zlabel_ar = |المذهب| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TW' seqnr = 60 ctrl = 'SELECT' required = 'X'
  zlabel = 'Job status' zlabel_ar = |الحالة الوظيفية| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TX_EN' seqnr = 70 ctrl = 'INPUT' hidden = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TX' seqnr = 80 ctrl = 'SELECT'
  zlabel = 'The main profession' zlabel_ar = |المهنة الرئيسية| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000U2_EN' seqnr = 90 ctrl = 'INPUT' hidden = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000U2' seqnr = 100 ctrl = 'INPUT' maxlen = 100
  zlabel = 'Profession' zlabel_ar = |المهنة بالتفصيل| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TY_EN' seqnr = 110 ctrl = 'INPUT' hidden = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TY' seqnr = 120 ctrl = 'INPUT' maxlen = 100
  zlabel = 'Employer' zlabel_ar = |جهة العمل| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TZ_EN' seqnr = 130 ctrl = 'INPUT' hidden = 'X' )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000TZ' seqnr = 140 ctrl = 'SELECT'
  zlabel = 'Employer Emirate' zlabel_ar = |إمارة العمل| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000U0' seqnr = 150 ctrl = 'INPUT' maxlen = 2
  zlabel = 'Children number under incubation' zlabel_ar = |عدد الاولاد تحت الحضانة| )
  ( mandt = sy-mandt journey_id = c_jid step_id = 'PRTY' field_name = 'PERS_INFO'
  col_name = 'ZZAFLD0000UZ' seqnr = 160 ctrl = 'INPUT' hidden = 'X'
  zlabel = 'Partner' zlabel_ar = |الطرف| )
  ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Grid column insert failed' TYPE 'E'. ENDIF.

* ---- Options ---------------------------------------------------------
* AS3 has NO fixed (non-domain) option sets, so this table stays empty:
*  - every SELECT dropdown is domain-backed and resolved at runtime by the
*    handler's on_value_help (DDUT_DOMVALUES_GET);
*  - the payer is not a choice for this service (the divorcer always pays, set
*    in on_submit), so the WD's payer radio is not rendered;
*  - the BP-search ID-type combobox belongs to the reusable Add-BP popup
*    (ZCL_RAK_BP_POPUP), not to this journey's fields.
* The DELETE above already cleared any previously loaded rows.

* ---- Rules -----------------------------------------------------------
* Field dependencies from the WD (set_grant / set_marr_cons / set_prev_div /
* check_no_prev_div). Actions: EDITABLE / READONLY (input enable/disable),
* REQUIRE (mandatory), CLEAR (blank the field on trigger change).
* Domain key '1' = Yes (confirmed). src_value holds the domain key, not label.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
*   -- UY Earlier marriages -> First marriage contract date (UE) + No. of
*      previous divorces (UM): editable + mandatory when Yes, else read-only.
*      UE/UM are cleared whenever UY changes.
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R01' src_field = 'EARLIER_MARRIAGES' src_op = 'EQ' src_value = '1' action = 'EDITABLE' tgt_field = 'FIRST_MARR_CTR_DT' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R02' src_field = 'EARLIER_MARRIAGES' src_op = 'EQ' src_value = '1' action = 'REQUIRE'  tgt_field = 'FIRST_MARR_CTR_DT' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R03' src_field = 'EARLIER_MARRIAGES' src_op = 'EQ' src_value = '1' action = 'EDITABLE' tgt_field = 'PREV_DIVORCES_COUNT' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R04' src_field = 'EARLIER_MARRIAGES' src_op = 'EQ' src_value = '1' action = 'REQUIRE'  tgt_field = 'PREV_DIVORCES_COUNT' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R05' src_field = 'EARLIER_MARRIAGES' src_op = 'NE' src_value = '1' action = 'READONLY' tgt_field = 'FIRST_MARR_CTR_DT' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R06' src_field = 'EARLIER_MARRIAGES' src_op = 'NE' src_value = '1' action = 'READONLY' tgt_field = 'PREV_DIVORCES_COUNT' )
*   -- UM No. of previous divorces -> Last divorce date (UF): editable when
*      there is at least one prior divorce (UM > 0), else read-only + cleared.
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R09' src_field = 'PREV_DIVORCES_COUNT' src_op = 'GT' src_value = '0' action = 'EDITABLE' tgt_field = 'LAST_DIV_DATE' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R10' src_field = 'PREV_DIVORCES_COUNT' src_op = 'LE' src_value = '0' action = 'READONLY' tgt_field = 'LAST_DIV_DATE' )
*      The WD pairs that enable/disable with a MANDATORY flag: CHECK_NO_PREV_DIV
*      sets ms_state-stc_last_div = '01' on the same UM > 0 branch, and
*      G_TAKEOFF_ZZAFLD0000UF binds its STATE to STATE-STC_LAST_DIV.
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R11' src_field = 'PREV_DIVORCES_COUNT' src_op = 'GT' src_value = '0' action = 'REQUIRE'  tgt_field = 'LAST_DIV_DATE' )
*   -- UV Divorced case upon divorce (1=Virgin, 2=Not virgin, 3=Unspecified) ->
*      Marriage consummated (UW) / Isolation (UX). 1: UX editable, UW read-only;
*      2: UW editable, UX read-only; 3: both read-only. UW/UX cleared on change.
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R12' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '1' action = 'EDITABLE' tgt_field = 'ISOLATION' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R13' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '1' action = 'READONLY' tgt_field = 'MARR_CONSUMMATED' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R14' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '2' action = 'EDITABLE' tgt_field = 'MARR_CONSUMMATED' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R15' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '2' action = 'READONLY' tgt_field = 'ISOLATION' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R15A' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '3' action = 'READONLY' tgt_field = 'MARR_CONSUMMATED' )  " 3 = Unspecified
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R15B' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '3' action = 'READONLY' tgt_field = 'ISOLATION' )
*      Same pairing on this branch. ONACTIONSET_MARR_CONS sets
*      stc_isolation = '01' when UV = 1 and stc_marr_cons = '01' when UV = 2;
*      ZZAFLD0000UX binds STATE-STC_ISOLATION and ZZAFLD0000UW binds
*      STATE-STC_MARR_CONS. UV = 3 sets both to '00', and because EVAL_RULES
*      rebuilds MT_RULEREQ from scratch every render, no OPTIONAL row is
*      needed to undo them.
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R16' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '1' action = 'REQUIRE'  tgt_field = 'ISOLATION' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R17' src_field = 'CASE_UPON_DIVORCE' src_op = 'EQ' src_value = '2' action = 'REQUIRE'  tgt_field = 'MARR_CONSUMMATED' )
*   -- UO Was a marriage grant received -> Grant side (UH): editable when Yes,
*      read-only otherwise; UH cleared whenever UO changes.
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R18' src_field = 'MARR_GRANT_RECEIVED' src_op = 'EQ' src_value = '1' action = 'EDITABLE' tgt_field = 'GRANT_SIDE' )
  ( mandt = sy-mandt journey_id = c_jid rule_id = 'R19' src_field = 'MARR_GRANT_RECEIVED' src_op = 'NE' src_value = '1' action = 'READONLY' tgt_field = 'GRANT_SIDE' )
  ) ).
  IF sy-subrc <> 0. ROLLBACK WORK. MESSAGE 'Rule insert failed' TYPE 'E'. ENDIF.
* Supported src_op: EQ | NE | GT | LT | GE | LE | INITIAL | NOTINITIAL
* Supported action: SHOW | HIDE | EDITABLE | READONLY | REQUIRE | OPTIONAL | SET | CLEAR
* A REQUIRE whose trigger sits on a LATER step than its target only bites at
* Submit, not on the earlier step's Next. R02 (HIST -> MARR) and R11 (HIST ->
* DIVO) are both that shape. This is correct, not a gap: MISSING_REQUIRED is
* per step, so on MARR's Next the trigger is still unanswered and demanding the
* target would be wrong - while HANDLE_SUBMIT calls VALIDATE_ALL, which loops
* every step, so nothing escapes at the end. It also matches the WD, which has
* no wizard and evaluates every mandatory field once, on Submit.
* NOTE: clear-on-change is NOT declarative — the engine drives field clearing
* through the handler's on_change (SET_PREV_DIV/SET_MARR_CONS/SET_GRANT/
* CHECK_NO_PREV_DIV). Only EDITABLE/READONLY/REQUIRE value-rules live here.

* ---- Portal: register under the 901 "AI Driven Journeys" group -------
  MODIFY zega_t_cj_grp FROM @( VALUE #( mandt = sy-mandt department = c_dept groupid = ''
  journeyid = c_main levelno = 0 orderno = 99 drilldown = 'Y' ) ).
  MODIFY zega_t_cj_id  FROM @( VALUE #( mandt = sy-mandt journeyid = c_main sip_code = c_main ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'E' journeyid = c_main description = 'AI Driven Journeys' ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'A' journeyid = c_main description = |الرحلات الرقمية الذكية| ) ).

* This journey's leaf under 901. zrak_t_jny.tile_code must equal this journeyid.
  MODIFY zega_t_cj_grp FROM @( VALUE #( mandt = sy-mandt department = c_dept groupid = c_main
  journeyid = c_tile levelno = 2 orderno = 10 drilldown = 'N' ) ).
  MODIFY zega_t_cj_id  FROM @( VALUE #( mandt = sy-mandt journeyid = c_tile sip_code = c_tile ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'E' journeyid = c_tile description = 'Divorce & Marriage take off' ) ).
  MODIFY zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt spras = 'A' journeyid = c_tile description = |الطلاق و الخلع| ) ).

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
* Passing the journey narrows it to ours - other journeys keep their entries.
  zcl_rak_cj_cfg_cache=>invalidate( CONV string( c_jid ) ).

  WRITE: / 'Seeded', c_jid, '— launch tile', c_tile, 'under group', c_main.
  WRITE: / 'Configuration cache invalidated — the next request reloads.'.
  WRITE: / 'Handler required and must be active:', c_hcls.
