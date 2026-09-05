*&---------------------------------------------------------------------*
*& Report ZRAK_M019_LOAD
*&---------------------------------------------------------------------*
*& M019 Convert To Program Grant Request - feeder.
*&
*& SCREENS, FROM ZEGA_T_CJ_UI_MAP for M019:
*&
*&     NCPGR_1_2   ATTACHMENT   rwmode 1
*&     NCPGR_1_3   INITIAL      rwmode 1     the fee read
*&     NCPGR_1_3   FEES_1       rwmode 2     the post that creates the case
*&     NCPGR_1_4   CPG_1        rwmode 1     the gateway
*&     NCPGR_1_5   CPG_1        rwmode 1     a SECOND gateway row
*&
*& TWO CPG_1 ROWS, WHICH IS UNIQUE IN THE TABLE. Every other journey has
*& one. PAY_SCREEN takes the EARLIER screen (NCPGR_1_4) - the earliest in
*& the flow, and what a sorted lookup would pick. If the payment read
*& comes back with no gateway payload, NCPGR_1_5 is the other candidate
*& and the trace prints which screen was asked, so swapping is a
*& one-value change.
*&
*& THE SELECTOR READS GRANTS, NOT OWNED PARCELS. Partnerrole YTR080 -
*& ZCL_RAK_PROPERTY_API=>C_ROLE_GRANT, reached by PARCELS( iv_grants =
*& abap_true ). On TR0800 the same control answers the citizen's OWNED
*& parcels: a list that renders perfectly and is the wrong one, which is
*& worse than an empty list because nothing looks broken. The spec
*& confirms it - one card, an "Expired On" date, and Favourites as the
*& only filter where the MML journeys show Owned / Property Agent /
*& Grants tabs.
*&
*& GRANTS ABSTRACT: case ZGCR, owner role ZTR080, party list in note
*& CJ03. The handler inherits ZCL_RAK_GRANT_LOGIC.
*&
*& FIELD NAMES ARE FROM THE EXPORT. Every FIELD_NAME below is the
*& legacy name as EXPORT_DEFIN.XLSX gives it for NCPGR_1_*, not a
*& reading of the spec screenshots - so backend FIELD_CONTROL and the
*& BAdI's own value mapping both key on them correctly.
*&
*& WHAT IS STILL NOT VERIFIED: the OPTION KEYS behind each radio and
*& dropdown, and the SEARCH HELP contents. The export gives the field
*& and its search help name, not the values; the keys used here come
*& from the legacy handler source where it names them and are marked
*& REVIEW-BE where they do not. A wrong option key does not stop the
*& screen - it stops a RULE, silently, so a field stays hidden or
*& shown against what the citizen picked.
*&---------------------------------------------------------------------*
REPORT zrak_m019_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M019'.

* ------------------------------------------------------- legacy wording
* LABELS AND OPTION TEXTS ARE READ, NEVER TYPED - the same rule the
* Arabic title above already follows, for the same reason.
*
* /QNV/SB_LABELT holds the department's own wording for every LABEL_CON
* code in the export, one row per SPRAS. The export gives the codes:
* OG_INDIVIDUAL, OG_SHARED, OG_NORMAL_GRANT, OG_HOUSING, OG_PROGRAM,
* WITHLOAN, WITHOUTLOAN, 0..4, and EPDA_NE014_1_4_CHECKBOX_2/_3 for the
* terms and donation lines. Typing the English off a spec document and
* translating the Arabic by hand puts a guess on the screen in place of
* text the department owns - and the difference is in a language most
* reviewers of this repository cannot check, so nothing reports it.
*
* THE FALLBACK IS THE LITERAL, NEVER BLANK. A missing row must leave a
* readable label rather than an empty one, so every call carries the
* wording it would have used. That also keeps this runnable on a client
* whose label table is not filled.
*
* IV_CODE IS DDIC-TYPED ON PURPOSE. A TYPE string formal parameter
* cannot take a DDIC-typed actual by reference, and the code goes
* straight into an Open SQL comparison against the real column.
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
*   Fallback first, so every exit - including the miss - leaves the
*   caller holding readable text.
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
* START-OF-SELECTION IS REQUIRED HERE, AND IT WAS NOT BEFORE.
* A report's first executable statement normally opens an implicit
* START-OF-SELECTION, which is why every other feeder runs without the
* keyword. A local CLASS ... IMPLEMENTATION is itself a processing
* block, so once LCL_TXT was added above, everything after ENDCLASS
* belonged to no block at all - "Statement is not accessible" on the
* first DELETE, with the rest of the report silently unreachable behind
* it. Adding the class means adding the event.
START-OF-SELECTION.

* ------------------------------------------------------------- teardown
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- title
  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_en)
    WHERE journeyid = @c_jny AND spras = @sy-langu.
  IF lv_title_en IS INITIAL.
    lv_title_en = 'Convert To Program Grant Request'.
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
    subtitle       = 'Convert an existing grant to a program grant, and track the request.'
    subtitle_ar    = 'حوّل منحة قائمة إلى منحة برنامج، وتابع الطلب.'
    active         = 'X'
    handler_class  = 'ZCL_M019_CPGR_LOGIC'
    bknd_active    = 'X'
    bknd_category  = 'GRANTS'
    bknd_journey   = c_jny
    bknd_fm_post   = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read   = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Grant Selection' title_ar = 'اختيار المنحة'
      icon = 'sap-icon://map' bknd_screen = 'NCPGR_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NCPGR_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NCPGR_1_3'
      active = 'X' ) ) ).

* --------------------------------------------- STP1 Grant Selection
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   THE GRANT CARD LIST. FTYPE 'PARCEL' is the single-select card list -
*   the same control M011 and M016 use - and the API: directive is what
*   points it at the grants role rather than the owned one. Without the
*   directive RENDER_ONE( ) would fall through to a DDIC resolver that
*   happens to share the field's name, and a wrong list is harder to
*   notice than no list.
*
*   REVIEW-BE: the API: directive's exact filter spelling for a grants
*   read is NOT confirmed. ZCL_RAK_CJ_OPTS=>RESOLVE( ) reads the
*   directive and ZCL_RAK_PROPERTY_API has C_ROLE_GRANT = 'YTR080' and a
*   PARCELS( iv_grants ) entry point, so the intent is unambiguous; what
*   is unverified is whether the directive takes Partnerrole as a filter
*   term in this form. If the list comes back as the citizen's OWNED
*   parcels, this is the line to correct.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSELECTOR' ftype = 'PARCEL' required = 'X'
      zsection = 'Please select a Grant from the list'
      zsection_ar = 'يرجى اختيار منحة من القائمة'
      zlabel = 'Grant' zlabel_ar = 'المنحة'
      default_val = 'API:PROPERTY:PropertiesSet::Type=Parcel&Partnerrole=YTR080'
      msg = 'Select the grant you are converting'
      msg_ar = 'يرجى اختيار المنحة المطلوب تحويلها' )

*   The hint under the list, as the spec draws it. A DISPLAY row, and its
*   text goes in DEFAULT_VAL behind TEXT: rather than in ZLABEL, because
*   ZLABEL is CHAR(150) and cuts on INSERT - a guidance paragraph that
*   loses its tail is gone from the database, not hidden by the renderer.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'CPGRHINT' ftype = 'DISPLAY' readonly = 'X'
      default_val = 'TEXT:Can''t find a Grant? Your properties are listed on your home page.'
      zlabel = '' zlabel_ar = '' ) ) ).

* ---------------------------------------------------- STP2 Documents
* THE SPEC CALLS THIS STEP "Documents" AND IT IS MOSTLY NOT DOCUMENTS.
* Two sections of scalar fields and one upload at the end - the naming is
* the legacy screen's, kept so the stepper matches what the citizen has
* seen before.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   FOUR FIELDS IN ONE ROW on screen. FGROUP 'ROW:GRANT' is what puts
*   them side by side instead of stacking them.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'REFNUM' ftype = 'INPUT' required = 'X'
      tech_name = 'REF_NUM'
      max_len = '20' fgroup = 'ROW:GRANT'
      zsection = 'Grant Type' zsection_ar = 'نوع المنحة'
      zlabel = 'Letter Reference Number' zlabel_ar = 'رقم مرجع الخطاب'
      msg = 'Enter the letter reference number'
      msg_ar = 'يرجى إدخال رقم مرجع الخطاب' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'GRANTREFNUM' ftype = 'INPUT' required = 'X'
      tech_name = 'GRANT_REF_NUM'
      max_len = '20' fgroup = 'ROW:GRANT'
      zlabel = 'Grant Reference Number' zlabel_ar = 'رقم مرجع المنحة'
      msg = 'Enter the grant reference number'
      msg_ar = 'يرجى إدخال رقم مرجع المنحة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'COMBOBOX' ftype = 'SELECT' required = 'X'
      tech_name = 'GRANT_TYPE'
      shlp = 'ZSH_CJ_GRANT_PGM_TYPE'
      closed_list = 'X' fgroup = 'ROW:GRANT'
      zlabel = 'Program Type' zlabel_ar = 'نوع البرنامج'
      msg = 'Choose the program type' msg_ar = 'يرجى اختيار نوع البرنامج' )

*   THE HANDLER CHECKS THIS DATE AGAINST TODAY, and it normalises through
*   TO_DATS( ) first - a DatePicker does not discard input it cannot
*   parse, it flags its own valueState and writes the typed characters
*   through the binding anyway. So this field can hold anything, and the
*   handler only has an opinion about a value it can read.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'DATEPICKER' ftype = 'DATE' required = 'X'
      tech_name = 'EXP_DATE'
      fgroup = 'ROW:GRANT'
      zlabel = 'Grant letter Expiry Date' zlabel_ar = 'تاريخ انتهاء خطاب المنحة'
      msg = 'REQUIRED:Enter the grant letter expiry date;RANGE:The grant letter has expired'
      msg_ar = 'REQUIRED:يرجى إدخال تاريخ انتهاء خطاب المنحة;RANGE:انتهت صلاحية خطاب المنحة' )

*   ---- grant status ---------------------------------------------------
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'RB1' ftype = 'SEGMENTED' required = 'X'
      tech_name = 'WITH_LOAN'
      zsection = 'Grant status' zsection_ar = 'حالة المنحة'
      zlabel = 'Loan Status' zlabel_ar = 'حالة القرض'
      msg = 'Choose whether the grant carries a loan'
      msg_ar = 'يرجى اختيار ما إذا كانت المنحة بقرض' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'LOANVALUEINPUT' ftype = 'CURRENCY' fgroup = 'ROW:LOAN'
      tech_name = 'LOAN_VAL'
      zlabel = 'Loan Value' zlabel_ar = 'قيمة القرض' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'FROMDATE' ftype = 'DATE' fgroup = 'ROW:LOAN'
      tech_name = 'FROM_DATE'
      zlabel = 'From Date' zlabel_ar = 'من تاريخ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'TODATE' ftype = 'DATE' fgroup = 'ROW:LOAN'
      tech_name = 'TO_DATE'
      zlabel = 'To Date' zlabel_ar = 'إلى تاريخ' )

*   ---- the one document -----------------------------------------------
*   REQUIRED on an uploader is enforced against the staged list by field
*   name, with a fallback to the GET_ATTACHMENTS( ) hook so a document
*   the backend already holds satisfies it on a resumed draft.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'UPLOADER' ftype = 'UPLOAD' required = 'X'
      zsection = 'Documents' zsection_ar = 'المستندات'
      zlabel = 'Sheikh Zayd Program Approval'
      zlabel_ar = 'موافقة برنامج الشيخ زايد'
      attach_label = 'Sheikh Zayd Program Approval'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' ) ) ).

* ----------------------------------------------- STP3 Fees & Payment
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )

*   PAY_SCREEN ONLY, and the EARLIER of this journey's two CPG_1 screens.
*   NCPGR_1_5 is the other. Never PAY_JOURNEY - it becomes
*   CS_HEADER-PARAM2 and changes the BAdI filter, and a value with no
*   implementation returns the screen's definition keys with every value
*   empty.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 15
      field_name = 'PAY_SCREEN' ftype = 'DISPLAY'
      readonly = 'X' hidden = 'X'
      default_val = 'NCPGR_1_4'
      zlabel = 'Payment screen' zlabel_ar = 'شاشة الدفع' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'TOTALVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_4_CHECKBOX_2'
                               iv_fb   = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_4_CHECKBOX_2'
                               iv_fb   = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع' )
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_4_CHECKBOX_3'
                               iv_fb   = 'I would like to donate five dirhams to Ajer Charity Foundation.' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_4_CHECKBOX_3'
                               iv_fb   = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.' )
      tech_name = 'DONATE' ) ) ).

* ---------------------------------------------------------------- rules
* The loan block only, and the same caveat as M018: WITH is the word on
* screen, not a confirmed option key. The handler compares the same word
* with CS, so correct both together.
* -------------------------------------------------------------- options
* THE OPTION KEY IS THE LEGACY BUTTON FIELD_NAME - E028 convention: the
* segmented group is ONE field named after its first member, and each
* member is an option keyed on its own FIELD_NAME. The export gives
* NCPGR_1_2 RB1 = WITH_LOAN / LABEL_CON WITHLOAN and RB2 = NO_LOAN /
* LABEL_CON WITHOUTLOAN, so WITHLOAN is a LABEL code and never a value.
* A rule comparing against it could not have fired, and the loan fields
* would have stayed hidden with nothing reported.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB1' opt_key = 'RB1' seqnr = 10
      opt_text    = lcl_txt=>en( iv_code = 'WITHLOAN' iv_fb = 'With Loan' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'WITHLOAN' iv_fb = 'بقرض' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB1' opt_key = 'RB2' seqnr = 20
      opt_text    = lcl_txt=>en( iv_code = 'WITHOUTLOAN' iv_fb = 'Without Loan' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'WITHOUTLOAN' iv_fb = 'بدون قرض' ) ) ) ).

* ---------------------------------------------------------------- rules
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R01'
      src_field = 'RB1' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'LOANVALUEINPUT' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R02'
      src_field = 'RB1' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'FROMDATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R03'
      src_field = 'RB1' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'TODATE' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* --------------------------------------------------------------- report
  WRITE: / 'M019 Convert To Program Grant Request - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT for SPRAS A.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'Steps    : STP1 Grant Selection  NCPGR_1_1'.
  WRITE: / '           STP2 Documents        NCPGR_1_2  8 fields + 1 upload'.
  WRITE: / '           STP3 Fees & Payment   NCPGR_1_3'.
  WRITE: / '           (NCPGR_1_4 is the CPG screen - PAY_SCREEN)'.
  WRITE: / ''.
  WRITE: / 'Handler  : ZCL_M019_CPGR_LOGIC (inherits ZCL_RAK_GRANT_LOGIC)'.
  WRITE: / 'Backend  : GRANTS / ZGCR / owner role ZTR080 / RO_GRANT_ABS_V1'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO:'.
  WRITE: / '  1. PROGRAM_TYPE and LOAN_STATUS have NO option list. Read'.
  WRITE: / '     the /QNV export for NCPGR_1_2 and fill ROLLNAME, DOMNAME'.
  WRITE: / '     or SHLP - or seed ZRAK_T_JNY_OPT rows from it.'.
  WRITE: / '  2. The selector API: directive is unverified. If step 1'.
  WRITE: / '     lists the citizen OWNED parcels rather than their grants,'.
  WRITE: / '     the Partnerrole term on PARCELSELECTOR is what to fix -'.
  WRITE: / '     it must resolve to YTR080.'.
  WRITE: / '  3. This journey has TWO CPG_1 rows in the UI map. PAY_SCREEN'.
  WRITE: / '     uses NCPGR_1_4; if the gateway read answers with no CPG'.
  WRITE: / '     payload, try NCPGR_1_5.'.
  WRITE: / '  4. Field names on STP2 are read off the spec, not an export.'.
