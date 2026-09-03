*&---------------------------------------------------------------------*
*& Report ZRAK_M017_LOAD
*&---------------------------------------------------------------------*
*& M017 Comprehensive Investigation - feeder, not the migrator.
*&
*& Re-runnable: deletes its own rows first, then inserts. Not a
*& production journey in the ZCL_RAK_MIGRATOR sense, so the
*& "drive the migrator, do not hand-author" rule does not apply - this IS
*& the hand-authored path, chosen deliberately for the M0xx family.
*&
*& SCREENS, AND WHERE THEY COME FROM. ZEGA_T_CJ_UI_MAP for M017:
*&
*&     NCI_1_1   ATTACHMENT   rwmode 1
*&     NCI_1_2   INITIAL      rwmode 1     the fee read
*&     NCI_1_2   FEES_1       rwmode 2     the post that creates the case
*&     NCI_1_3   CPG_1        rwmode 1     the gateway
*&
*& So TWO CJS steps, and the gateway is a screen CJS never renders. That
*& is what PAY_SCREEN carries - see the field, and read the note there
*& before changing it.
*&
*& THE BACKEND IS THE MML ABSTRACT, NOT THE GRANTS ONE.
*& ZCL_EGA_CJ_ENH_IMPL_M017_V1 inherits ZCL_EGA_CJ_FW_RO_ABS_V1, so the
*& case is ZGCX, the owner role is TR0800, and the handler inherits
*& ZCL_RAK_MUN_LOGIC. M018/M019/M020 are the grants family and differ.
*&
*& NO PARCEL. This is the only journey in the set that selects nothing -
*& no selector, no property list, no PLDTL table. The backend's own
*& VALIDATE( ) has `properties IS INITIAL` COMMENTED OUT for exactly that
*& reason, so do not add a parcel requirement to make it match its
*& siblings.
*&
*& WHAT IS NOT VERIFIED. No /QNV/SB_UI_DEFIN export for NCI_1_* has been
*& read. CI_ENTITY_CODE, CI_NOTE, CHECKBOX_2 and CHECKBOX_3 are
*& CONFIRMED from ZCL_EGA_CJ_ENH_IMPL_M017_V1's own source; the
*& uploader's name is a guess and is marked REVIEW-BE at the row. A field
*& name that is not the legacy one still renders and still posts under
*& its TECH_NAME - what it loses is backend field control, silently.
*&---------------------------------------------------------------------*
REPORT zrak_m017_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M017'.

* ------------------------------------------------------------- teardown
* Every table this report writes, so a re-run replaces rather than
* duplicates. ZRAK_T_JNY_COL is included even though this journey seeds
* no grid: a previous version of the report may have, and a stale column
* row against a field that no longer exists is invisible until it draws.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- title
* The Arabic title is READ, never typed. ZEGA_T_CJ_IDT holds the
* department's own wording per language and SPRAS 'A' is Arabic - typing
* a translation here would drift from what the portal shows for the same
* service.
  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_en)
    WHERE journeyid = @c_jny AND spras = @sy-langu.
  IF lv_title_en IS INITIAL.
    lv_title_en = 'Comprehensive Investigation'.
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
    subtitle       = 'Request a comprehensive investigation and track the request.'
    subtitle_ar    = 'اطلب تحقيقاً شاملاً وتابع الطلب.'
    active         = 'X'
    handler_class  = 'ZCL_M017_CI_LOGIC'
*   THE BACKEND BLOCK IS WHAT MAKES THE QNV BRIDGE RUN AT ALL. Blank
*   BKND_ACTIVE and the journey renders, validates and posts nothing -
*   the quietest possible failure.
    bknd_active    = 'X'
    bknd_category  = 'MML'
    bknd_journey   = c_jny
    bknd_fm_post   = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read   = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* TWO STEPS. The stepper in the spec shows exactly these two, and the
* third backend screen (NCI_1_3) is the gateway, which is not a step.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'General information' title_ar = 'معلومات عامة'
      icon = 'sap-icon://document-text' bknd_screen = 'NCI_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NCI_1_2'
      active = 'X' ) ) ).

* --------------------------------------------------- STP1 General info
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   A heading, not a field. The spec's "Please enter the details below"
*   sits above the three controls and is a DISPLAY row in the legacy
*   screen, which is what ZSECTION reproduces without drawing a control.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'CI_HEAD' ftype = 'DISPLAY' readonly = 'X'
      zsection = 'Please enter the details below'
      zsection_ar = 'يرجى إدخال التفاصيل أدناه'
      zlabel = '' zlabel_ar = '' )

*   REVIEW-BE: THE UPLOADER'S FIELD_NAME IS A GUESS. No /QNV export for
*   NCI_1_1 has been read; UPLOADER is what the other Municipality
*   screens call their first uploader. The upload works regardless -
*   attachments travel in the attachment table, not by field name - but
*   MANDATORY / ENABLED / VISIBLE arriving from the backend's
*   FIELD_CONTROL( ) are keyed on the legacy name and will silently not
*   apply if this is wrong.
*
*   REQUIRED ON AN UPLOADER IS ENFORCED, and correctly:
*   ZCL_RAK_JOURNEY_RULES checks the staged list by FIELD NAME
*   ( mt_attach[ field = ... ] ) and falls back to the GET_ATTACHMENTS( )
*   hook, so a document the backend already holds satisfies it on a
*   resumed draft. Do not write a handler check for this.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'UPLOADER' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Family Book' zlabel_ar = 'خلاصة القيد'
      attach_label = 'Family Book' attach_types = 'pdf,jpg,jpeg,png'
      attach_maxmb = '5'
      msg = 'Attach the family book' msg_ar = 'يرجى إرفاق خلاصة القيد' )

*   CONFIRMED NAME. Read by the implementation class's own VALIDATE( ) as
*   CI_ENTITY_CODE - it is the entity the open-case check keys on, joined
*   to characteristic CJ07.
*
*   REVIEW-BE: the OPTION LIST is not seeded. The spec shows one value
*   ("To whom it concerns") and the real list is a domain or a search
*   help on the legacy control, which the export would name. Left with no
*   ZRAK_T_JNY_OPT rows on purpose: a hand-typed list that drifts from
*   the backend's own is worse than an empty dropdown, because the
*   citizen can pick a code the case cannot accept. Fill ROLLNAME,
*   DOMNAME or SHLP once the export is read - see config-tables.md on
*   the four option sources.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'CI_ENTITY_CODE' ftype = 'SELECT' required = 'X'
      closed_list = 'X'
      zlabel = 'Entity' zlabel_ar = 'الجهة'
      placeholder = 'To whom it concerns'
      placeholder_ar = 'إلى من يهمه الأمر'
      msg = 'Choose the entity this investigation is for'
      msg_ar = 'يرجى اختيار الجهة المعنية بالتحقيق' )

*   CONFIRMED NAME. CI_NOTE is the CJ11 long text - the implementation
*   class reads it back through READ_NOTE( ) on the RE note, which is why
*   it is a TEXTAREA and not an INPUT.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 40
      field_name = 'CI_NOTE' ftype = 'TEXTAREA'
      max_len = '1000'
      zlabel = 'Add a Comment (optional)' zlabel_ar = 'أضف تعليقاً (اختياري)'
      tech_name = 'CI_NOTE' ) ) ).

* ------------------------------------------------- STP2 Fees & Payment
* PAYFEE IS THE WHOLE CARD. ZCL_RAK_JOURNEY_LOGIC->RENDER_FIELD( ) draws
* the fee list, the total, the method and channel blocks, the bank
* charges, the pop-up notice, the Pay button and the poll. The legacy
* screen's RB1..RB4, PW_RB1/PW_RB2, FEESLIST, REMAININGFEES and ATB_FLAG
* are all inside it - seeding them would draw the payment screen twice.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )

*   ---- PAY_SCREEN ONLY. NEVER PAY_JOURNEY, NEVER PAY_CATEGORY --------
*   The gateway lives on NCI_1_3, one screen past the fee read, because
*   that is where ZEGA_T_CJ_UI_MAP puts CPG_1. PAY_SCREEN moves the
*   payment read there and nothing else changes.
*
*   DO NOT ADD PAY_JOURNEY. It becomes CS_HEADER-PARAM2 and
*   ZFM_EGA_CJ_FW_READ_N does `journeytype = cs_header-param2` then
*   `GET BADI cj_badi FILTERS journey_type = journeytype` - so a value
*   with no implementation behind it returns the screen's definition keys
*   with every value empty. The screen exists; the BAdI does not. Same
*   for PAY_CATEGORY: blank means "use the journey's own", which is MML,
*   and that is what makes the map lookup find the CPG row.
*
*   AND DO NOT WAIT FOR APPLICATIONURL. ROUTE_GATEWAY( ) picks from
*   ZDT_PG_DEP_MAP - an ATB department gets a ready-made URL, everything
*   else goes to the standard CPG through the payments Web Dynpro where
*   no pre-built URL exists.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 15
      field_name = 'PAY_SCREEN' ftype = 'DISPLAY'
      readonly = 'X' hidden = 'X'
      default_val = 'NCI_1_3'
      zlabel = 'Payment screen' zlabel_ar = 'شاشة الدفع' )

*   TOTALFEESVALUE IS WHAT MAKES THE BACKEND CREATE THE CASE.
*   ZIF_EGA_FW_CJI~UPDATE( ) branches on finding it in the posted items
*   with a FEES_1 row for the screen, and only then reaches
*   PAYMENT_CHECK( ) and CREATE_DUMMY_CASE( ). No item, no ZGCX case, no
*   open item, and the gateway opens against nothing. The handler's
*   inherited Pay press writes the value from the fee grid.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'TOTALVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )

*   CONFIRMED NAMES, and both are real fields: the implementation class's
*   READ( ) forces TOSAVE on CHECKBOX_2 and CHECKBOX_3, which means the
*   backend intends to store what they hold.
*
*   CHECKBOX_3 is the terms gate. Its legacy UI_FIELD_LOGICS is 'PAY-E' -
*   it ENABLES the Pay button - and CJS cannot reproduce that from
*   config, because the Pay button is inside the PAYFEE card that
*   RENDER_FIELD( ) draws whole. ZCL_RAK_MUN_LOGIC refuses the press
*   without it instead, which is the same outcome one step later and with
*   a reason given.
*
*   TWO INDEPENDENT BOOLEANS ARE TWO FIELDS, never one required
*   CHECKGROUP: a group is satisfied by ticking EITHER option, which is
*   how a citizen ticks their way past terms they never accepted.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'CHECKBOX_2' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I declare that the information provided is correct'
      zlabel_ar = 'أقر بأن المعلومات المقدمة صحيحة'
      msg = 'The declaration must be accepted before payment'
      msg_ar = 'يجب قبول الإقرار قبل الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع' ) ) ).

  COMMIT WORK AND WAIT.

* INVALIDATE, ALWAYS. A versioned per-work-process cache means another
* work process keeps serving the old configuration, and the change then
* looks exactly like a report that did not run.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* --------------------------------------------------------------- report
  WRITE: / 'M017 Comprehensive Investigation - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT for SPRAS A - the'.
    WRITE: / '           Arabic header will fall back to English.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'Steps    : STP1 General information   NCI_1_1   4 fields'.
  WRITE: / '           STP2 Fees & Payment        NCI_1_2   5 fields'.
  WRITE: / '           (NCI_1_3 is the CPG screen - PAY_SCREEN, not a step)'.
  WRITE: / ''.
  WRITE: / 'Handler  : ZCL_M017_CI_LOGIC (inherits ZCL_RAK_MUN_LOGIC)'.
  WRITE: / 'Backend  : MML / ZGCX / owner role TR0800 / RO_ABS_V1'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO - none of these are code:'.
  WRITE: / '  1. CI_ENTITY_CODE has NO option list. Read the /QNV export'.
  WRITE: / '     for NCI_1_1 and fill ROLLNAME, DOMNAME or SHLP. An empty'.
  WRITE: / '     dropdown is deliberate - a hand-typed list that drifts'.
  WRITE: / '     from the backend lets a citizen pick a code the case'.
  WRITE: / '     cannot accept.'.
  WRITE: / '  2. The uploader FIELD_NAME is a guess (UPLOADER). Backend'.
  WRITE: / '     field control keys on the legacy name and will silently'.
  WRITE: / '     not apply if it is wrong.'.
  WRITE: / '  3. ZEGA_T_CJ_UI_MAP must have ATTACHMENT on NCI_1_1,'.
  WRITE: / '     INITIAL + FEES_1 on NCI_1_2 and CPG_1 on NCI_1_3.'.
  WRITE: / '     Confirmed present for M017 in the exported map.'.
