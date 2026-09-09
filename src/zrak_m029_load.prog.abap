*&---------------------------------------------------------------------*
*& Report ZRAK_M029_LOAD
*&---------------------------------------------------------------------*
*& M029 Assign Consultant - feeder, not the migrator.
*&
*& Re-runnable: deletes its own rows first, then inserts. Same deliberate
*& hand-authored path as ZRAK_M017_LOAD - see that report's header for why
*& the "drive the migrator, do not hand-author" rule does not apply to the
*& per-journey M0xx feeders.
*&
*& ------------------------------------------------------------------
*& WHERE EVERY NAME BELOW COMES FROM
*&
*& /QNV/SB_UI_DEFIN, category DML, screens NACO_1_1..1_3, read off the
*& full export - NOT from the walkthrough screenshots. The screenshots
*& give the step count and the layout; only the export gives FIELD_NAME,
*& and the backend's field control keys on the legacy name end to end.
*&
*&   NACO_1_1  PARCELSELECTOR   RAKPARCELSELECTOR   -> ftype PARCEL
*&   NACO_1_2  MY_COMPONENT     RAK_CONTRACTORCONTROL (DATA1 "Consultant")
*&             UPLOADER         RAKUPLOADER   MANDATORY
*&             PRM_PRJ_TYPE     COMBOBOX      MANDATORY  TOSAVE
*&             CHECKBOX1        CHECKBOX      TOSAVE   LABEL_CON ACC_1_1_RB1
*&             CHECKBOX_3       CHECKBOX      TOSAVE   LABEL_CON EPDA_NE014_1_4_CHECKBOX_2
*&             CHECKBOX_4       CHECKBOX      TOSAVE   LABEL_CON EPDA_NE014_1_4_CHECKBOX_3
*&             CONSULTANTNAME / CONSULTANT_BP / TRADELICENSE /
*&             LICENSEEXPIRY / GRADE   - carriers, TOSAVE, no control
*&   NACO_1_3  HAPPY            RAKHAPPY  -> the engine's own feedback step,
*&                                           never a CJS step of its own
*&
*& TWO STEPS, WHICH IS WHAT THE STAGE BAR SHOWS. The walkthrough's stepper
*& reads "Parcel Selection" then "Adding a Consultant" and nothing else.
*&
*& NO PAYMENT, AND THAT IS CONFIRMED ON BOTH SIDES. The walkthrough says
*& "No Payment screen in sequence" and the export agrees: there is no
*& RAKPAY control on any NACO_1_* screen, and ZRAK_M_MUNI_LOAD already
*& carries M029 in its pay = abap_false group. So no PAYFEE field, and the
*& handler's inherited PAID gate simply never has anything to refuse.
*&
*& ------------------------------------------------------------------
*& THE CONSULTANT GRID IS EDITABLE_TABLE, NOT TABLE.
*&
*& The rows are not typed - the citizen searches by trade licence, BP or
*& company name and presses Add, and ZCL_M029_ACO_LOGIC->ON_SEARCH( )
*& appends the row. EDITABLE_TABLE is still the right ftype: it renders
*& handler-free from the ZRAK_T_JNY_COL spec, and the engine already owns
*& row delete (GRIDDEL_ in ZCL_RAK_JOURNEY_ENGINE), which is the bin icon
*& the walkthrough shows on each row. A plain TABLE would need
*& GET_TABLE( ) plus a hand-drawn delete, for the same screen.
*&
*& THE COLUMN ORDER IS THE CONTRACT. ZRAK_T_JNY_COL-SEQNR here and the
*& handler's row build must agree: SET_GRID_DATA( ) maps by position, so
*& a cell appended out of order lands in the neighbouring column and one
*& past the last column is dropped, neither of which raises anything.
*&
*& ------------------------------------------------------------------
*& NOT VERIFIED FROM HERE - all three are named in the run log too:
*&
*& 1. ZEGA_T_CJ_UI_MAP must carry rows for NACO_1_1 and NACO_1_2, or the
*&    journey posts, returns success and creates nothing. ATTACHMENT is
*&    needed on NACO_1_2 for the uploader. Rule X16 in ZCL_RAK_CJS_XCHECK
*&    reports this from the CJS side once the journey exists.
*& 2. PRM_PRJ_TYPE has no option list here. The export names the field and
*&    its COMBOBOX type but no search help, so the values come from
*&    somewhere the definition table does not reach. An empty dropdown is
*&    deliberate: a hand-typed list that drifts from the backend lets a
*&    citizen pick a code the case cannot accept.
*& 3. The two numbered term paragraphs (TERM1/TERM11/TERM2/TERM21 in the
*&    export) carry no LABEL_CON, so their wording is not readable from
*&    /QNV/SB_LABELT. They are seeded as a TEXT: reference rather than
*&    typed in, because a legal paragraph hand-translated into Arabic is a
*&    guess nobody in this repository can check.
*&---------------------------------------------------------------------*
REPORT zrak_m029_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M029'.

* ------------------------------------------------------- legacy wording
* LABELS AND OPTION TEXTS ARE READ, NEVER TYPED. Same helper, same rule
* and same reasoning as ZRAK_M017_LOAD: /QNV/SB_LABELT holds the
* department's own wording for every LABEL_CON code in the export, one row
* per SPRAS, and typing the English off a screenshot then translating the
* Arabic by hand substitutes a guess for text the department owns - in a
* language most reviewers of this repository cannot check.
*
* THE FALLBACK IS THE LITERAL, NEVER BLANK, so a client whose label table
* is not filled still renders a readable screen.
*
* IV_CODE IS DDIC-TYPED ON PURPOSE. A TYPE string formal parameter cannot
* take a DDIC-typed actual by reference, and the code goes straight into
* an Open SQL comparison against the real column.
CLASS lcl_txt DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS en
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS ar
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS pick
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code
                iv_spras  TYPE sy-langu
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
ENDCLASS.

CLASS lcl_txt IMPLEMENTATION.
  METHOD en.
    rv = pick( iv_code = iv_code iv_spras = sy-langu iv_fb = iv_fb ).
  ENDMETHOD.

  METHOD ar.
    rv = pick( iv_code = iv_code iv_spras = 'A' iv_fb = iv_fb ).
  ENDMETHOD.

  METHOD pick.
*   Fallback first, so every exit - including the miss - leaves the caller
*   holding readable text.
    rv = iv_fb.
    IF iv_code IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE labeltext FROM /qnv/sb_labelt
      INTO @DATA(lv_txt)
      WHERE label_code = @iv_code AND spras = @iv_spras.
    IF sy-subrc = 0 AND lv_txt IS NOT INITIAL.
      rv = lv_txt.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

* ------------------------------------------------------------- runtime
* START-OF-SELECTION IS REQUIRED, because a local CLASS ... IMPLEMENTATION
* is itself a processing block: without the event everything after
* ENDCLASS belongs to no block and the first DELETE is unreachable.
START-OF-SELECTION.

* ------------------------------------------------------------- teardown
* Every table this report writes, so a re-run replaces rather than
* duplicates. ZRAK_T_JNY_COL is included because this journey does seed a
* grid, and a stale column row against a field that no longer exists is
* invisible until it draws.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- title
* Both titles are READ. ZEGA_T_CJ_IDT holds the department's own wording
* per language and SPRAS 'A' is Arabic - typing a translation here would
* drift from what the portal shows for the same service.
  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_en)
    WHERE journeyid = @c_jny AND spras = @sy-langu.
  IF lv_title_en IS INITIAL.
    lv_title_en = 'Assign Consultant'.
  ENDIF.

  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_ar)
    WHERE journeyid = @c_jny AND spras = 'A'.

* --------------------------------------------------------------- header
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt          = sy-mandt
    journey_id     = c_jny
    title          = lv_title_en
    title_ar       = lv_title_ar
    subtitle       = 'Assign an engineering consultant to your plot.'
    subtitle_ar    = 'تعيين استشاري هندسي لقطعة أرضك.'
    active         = 'X'
    handler_class  = 'ZCL_M029_ACO_LOGIC'
*   THE BACKEND BLOCK IS WHAT MAKES THE QNV BRIDGE RUN AT ALL. Blank
*   BKND_ACTIVE and the journey renders, validates and posts nothing - the
*   quietest possible failure this framework has.
    bknd_active    = 'X'
    bknd_category  = 'DML'
    bknd_journey   = c_jny
    bknd_fm_post   = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read   = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* TWO STEPS. NACO_1_3 is RAKHAPPY - the engine appends its own feedback
* step to every journey, so seeding it here would draw it twice.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Parcel Selection' title_ar = 'اختيار قطعة الأرض'
      icon = 'sap-icon://map' bknd_screen = 'NACO_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Adding a Consultant' title_ar = 'اضافة استشاري'
      icon = 'sap-icon://employee' bknd_screen = 'NACO_1_2'
      active = 'X' ) ) ).

* ----------------------------------------------- STP1 Parcel Selection
* ONE FIELD, AND IT IS THE WHOLE STEP. ftype PARCEL renders through
* ZCL_RAK_JOURNEY_RENDER's SELECT branch fed by ZCL_RAK_CJ_OPTS off the
* API: directive, so nothing else belongs on this screen.
*
* NOT REQUIRED HERE, DELIBERATELY. ZCL_RAK_MUN_LOGIC->ON_CUSTOM_VALIDATE( )
* already refuses step 0 when no parcel is chosen, with wording in both
* languages. Setting REQUIRED as well would produce two messages for one
* condition.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSELECTOR' ftype = 'PARCEL'
      zlabel = 'Parcel Selection' zlabel_ar = 'اختيار قطعة الأرض' ) ) ).

* ------------------------------------------- STP2 Adding a Consultant
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(

*   ---- the consultant search ----------------------------------------
*   MY_COMPONENT is the legacy RAK_CONTRACTORCONTROL, and its DATA1 is
*   literally "Consultant". ZCL_RAK_MIGRATOR->CLASSIFY( ) maps that
*   control to ftype SEARCH - the id-type dropdown, the input, Search and
*   Browse, wired to SEARCH_ and BPOPEN_ - which is exactly the three-way
*   Search Method the walkthrough shows.
*
*   'SEARCH', NEVER 'BP'. A field typed 'BP' reaches RENDER_ONE( )'s
*   WHEN OTHERS and draws a plain input box: the citizen gets a text
*   field where a partner search belongs, and nothing reports it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'MY_COMPONENT' ftype = 'SEARCH' required = 'X'
      zsection = 'Add a consultant' zsection_ar = 'إضافة استشاري'
      zlabel = 'Search Method' zlabel_ar = 'طريقة البحث'
      msg = 'REQUIRED:Search for a consultant and press Add'
      msg_ar = 'REQUIRED:يرجى البحث عن استشاري ثم الضغط على إضافة' )

*   ---- the added consultants ----------------------------------------
*   EDITABLE_TABLE, columns in ZRAK_T_JNY_COL below. The handler appends
*   a row on a successful search; the engine's own GRIDDEL_ handles the
*   bin icon. Every column is READONLY - these values came from the
*   partner read, not from the citizen, and letting them be typed over
*   would send an edited company name to the case.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'CONSULTANTS' ftype = 'EDITABLE_TABLE' required = 'X'
      zlabel = 'Consultant' zlabel_ar = 'الاستشاري'
      msg = 'REQUIRED:Add at least one consultant'
      msg_ar = 'REQUIRED:يرجى إضافة استشاري واحد على الأقل' )

*   ---- project type --------------------------------------------------
*   CLOSED_LIST because the backend accepts a fixed set of project types
*   and a typable ComboBox lets a citizen submit one that is not in it.
*   No ZRAK_T_JNY_OPT rows on purpose - see note 2 in the header.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'PRM_PRJ_TYPE' ftype = 'SELECT' required = 'X'
      closed_list = 'X'
      zlabel = 'Project Type' zlabel_ar = 'نوع المشروع'
      msg = 'REQUIRED:Choose the project type'
      msg_ar = 'REQUIRED:يرجى اختيار نوع المشروع' )

*   ---- the letter ----------------------------------------------------
*   MANDATORY in the export. REQUIRED on an uploader is enforced properly
*   by ZCL_RAK_JOURNEY_RULES - it checks the staged list by FIELD NAME and
*   falls back to the GET_ATTACHMENTS( ) hook, so a document the backend
*   already holds satisfies it on a resumed draft. Do not add a handler
*   check for this.
*
*   NO DTYPE: DEFAULT. The export gives this uploader no DATA2, so
*   ZDT_EGA_CJ_ATTR-DIFFCRT arrives blank - which is what the legacy
*   screen does too. Do not invent a document type here.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'UPLOADER' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Consultant appointment letter'
      zlabel_ar = 'خطاب تعيين الاستشاري'
      attach_label = 'Consultant appointment letter'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      msg = 'REQUIRED:Attach the appointment letter'
      msg_ar = 'REQUIRED:يرجى إرفاق خطاب التعيين' )

*   ---- the terms paragraphs ------------------------------------------
*   TEXT: RATHER THAN A TYPED PARAGRAPH. The export carries this wording
*   as TERM1/TERM11/TERM2/TERM21 with NO LABEL_CON, so it cannot be read
*   from /QNV/SB_LABELT the way the checkbox labels below can. ZLABEL is
*   CHAR(150) and would cut it mid-sentence in any case.
*
*   TEXT:@nnn resolves ZRAK_T_CJ_TXT by SY-LANGU, so one row per language
*   gives a bilingual paragraph that can be reworded with no reseed -
*   DEFAULT_VAL has no _AR twin, so a literal paragraph here would show
*   its English to an Arabic reader. The key is named in the run log.
*
*   A TEXT: default is never seeded as the field's value, so this cannot
*   accidentally pre-fill anything.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'TERMS_TEXT' ftype = 'DISPLAY' readonly = 'X'
      default_val = 'TEXT:@290'
      zsection = 'Read and Accept the terms & conditions'
      zsection_ar = 'اقرأ ووافق على الشروط والأحكام' )

*   ---- the three declarations ----------------------------------------
*   THREE INDEPENDENT BOOLEANS ARE THREE FIELDS, never one required
*   CHECKGROUP: a group is satisfied by ticking ANY option, which is how a
*   citizen ticks their way past terms they never accepted.
*
*   The label codes are the export's own and are confirmed present on
*   NACO_1_2, so the department's wording is what renders. The fallbacks
*   are the English the walkthrough shows.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'CHECKBOX1' ftype = 'CHECKBOX' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'ACC_1_1_RB1' iv_fb = 'I Agree' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'ACC_1_1_RB1' iv_fb = 'أوافق' )
      msg = 'REQUIRED:The terms must be accepted before continuing'
      msg_ar = 'REQUIRED:يجب قبول الشروط قبل المتابعة' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_4_CHECKBOX_2'
                               iv_fb   = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_4_CHECKBOX_2'
                               iv_fb   = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع' )
      msg = 'REQUIRED:The declaration must be accepted before continuing'
      msg_ar = 'REQUIRED:يجب قبول الإقرار قبل المتابعة' )

*   CHECKBOX_4 IS THE CHARITY DONATION AND IS OPTIONAL. Marking it
*   required would make a five-dirham donation compulsory before a citizen
*   could continue - which nearly happened on M017 under a label about
*   terms and conditions.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_4_CHECKBOX_3'
                               iv_fb   = 'I would like to donate five dirhams to Ajer Charity Foundation.' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_4_CHECKBOX_3'
                               iv_fb   = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.' ) )

*   ---- carriers ------------------------------------------------------
*   TOSAVE in the export, no control on the screen: the backend expects
*   them in the payload and the citizen never sees them. Hidden and
*   readonly, written by the handler when a consultant is picked.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'CONSULTANT_BP' ftype = 'DISPLAY'
      hidden = 'X' readonly = 'X'
      zlabel = 'Consultant BP' zlabel_ar = 'الشريك التجاري للاستشاري' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'CONSULTANTNAME' ftype = 'DISPLAY'
      hidden = 'X' readonly = 'X'
      zlabel = 'Consultant name' zlabel_ar = 'اسم الاستشاري' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'TRADELICENSE' ftype = 'DISPLAY'
      hidden = 'X' readonly = 'X'
      zlabel = 'Trade licence' zlabel_ar = 'الرخصة التجارية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'LICENSEEXPIRY' ftype = 'DISPLAY'
      hidden = 'X' readonly = 'X'
      zlabel = 'Licence expiry' zlabel_ar = 'انتهاء الرخصة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'GRADE' ftype = 'DISPLAY'
      hidden = 'X' readonly = 'X'
      zlabel = 'Grade' zlabel_ar = 'التصنيف' ) ) ).

* --------------------------------------------------- the grid columns
* THE ORDER HERE IS THE CONTRACT the handler builds its rows against -
* see ZCL_M029_ACO_LOGIC->ADD_ROW( ), which carries the same list in the
* same order and says so. SET_GRID_DATA( ) maps by position.
*
* The five columns are the walkthrough's, left to right.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'CONSULTANTS' col_name = 'COMPANY' seqnr = 10
      zlabel = 'Company' zlabel_ar = 'الشركة'
      ctrl = 'TEXT' readonly = 'X' width = '30%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'CONSULTANTS' col_name = 'ADDRESS' seqnr = 20
      zlabel = 'Address' zlabel_ar = 'العنوان'
      ctrl = 'TEXT' readonly = 'X' width = '25%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'CONSULTANTS' col_name = 'GRADE' seqnr = 30
      zlabel = 'Grade' zlabel_ar = 'التصنيف'
      ctrl = 'TEXT' readonly = 'X' width = '12%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'CONSULTANTS' col_name = 'BPID' seqnr = 40
      zlabel = 'Company BP ID' zlabel_ar = 'رقم الشريك التجاري'
      ctrl = 'TEXT' readonly = 'X' width = '18%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'CONSULTANTS' col_name = 'EMAIL' seqnr = 50
      zlabel = 'Email' zlabel_ar = 'البريد الإلكتروني'
      ctrl = 'TEXT' readonly = 'X' width = '15%' ) ) ).

  COMMIT WORK AND WAIT.

* INVALIDATE, ALWAYS. A versioned per-work-process cache means another
* work process keeps serving the old configuration, and the change then
* looks exactly like a report that did not run.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* --------------------------------------------------------------- report
  WRITE: / 'M029 Assign Consultant - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT for SPRAS A - the'.
    WRITE: / '           Arabic header will fall back to English.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'Steps    : STP1 Parcel Selection      NACO_1_1   1 field'.
  WRITE: / '           STP2 Adding a Consultant   NACO_1_2  13 fields'.
  WRITE: / '           (NACO_1_3 is RAKHAPPY - the engine appends its own'.
  WRITE: / '            feedback step, so it is not a step here)'.
  WRITE: / ''.
  WRITE: / 'Handler  : ZCL_M029_ACO_LOGIC (inherits ZCL_RAK_MUN_LOGIC)'.
  WRITE: / 'Backend  : DML / ZFM_EGA_CJ_FW_POST_N / _READ_N'.
  WRITE: / 'Payment  : NONE - no RAKPAY on any NACO_1_* screen, and the'.
  WRITE: / '           walkthrough says the same. No PAYFEE field seeded.'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO - none of these are code:'.
  WRITE: / '  1. ZEGA_T_CJ_UI_MAP must carry NACO_1_1 and NACO_1_2, with'.
  WRITE: / '     ATTACHMENT on NACO_1_2 for the uploader. A screen correct'.
  WRITE: / '     in /QNV and missing from the map posts, returns success'.
  WRITE: / '     and creates nothing. Run ZCL_RAK_CJS_XCHECK rule X16.'.
  WRITE: / '  2. PRM_PRJ_TYPE has NO option list. The export names the'.
  WRITE: / '     field but no search help. Fill ROLLNAME, DOMNAME or SHLP'.
  WRITE: / '     once the source is known - an empty dropdown is'.
  WRITE: / '     deliberate, a hand-typed one lets the citizen pick a code'.
  WRITE: / '     the case cannot accept.'.
  WRITE: / '  3. ZRAK_T_CJ_TXT key 290 is not seeded. Create one row per'.
  WRITE: / '     language for TERMS_TEXT, holding the two numbered'.
  WRITE: / '     paragraphs the live screen shows (Building Regulation Law'.
  WRITE: / '     No. 1 of 2009 / Civil Transactions Law No. 5 of 1985).'.
  WRITE: / '     Until then that field renders empty. The Arabic is NOT'.
  WRITE: / '     typed here on purpose - take it from the live screen.'.
  WRITE: / '  4. Confirm on screen whether the EDITABLE_TABLE draws its own'.
  WRITE: / '     Add-row button beside the search Add. If it does, hide it'.
  WRITE: / '     in the Studio - two Add buttons on one grid is confusing'.
  WRITE: / '     and a blank typed row is not a consultant.'.
