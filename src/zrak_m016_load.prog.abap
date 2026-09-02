REPORT zrak_m016_load.

*&---------------------------------------------------------------------*
*& M016 - Change Building Regulations
*&
*& ZRAK_M011_LOAD IS THE REFERENCE FEEDER FOR THIS FAMILY and carries the
*& full reasoning. Read it first. Only the differences are explained here.
*&
*& Hand-authored from the /QNV/SB_UI_DEFIN export, screens NCBR_1_1..1_4,
*& category MML.
*&
*& STRUCTURE - same four steps as M011:
*&   STP1  NCBR_1_1  Parcel Selection
*&   STP2  NCBR_1_2  Regulation & Documents
*&   STP3  NCBR_1_3  Fees & Payment
*&
*& WHAT DIFFERS FROM M011:
*&   - NCBR_1_2 carries RAKSELECTUSAGETYPE, the usage type being applied
*&     for. Neither M011 nor M012 has one.
*&   - four uploaders rather than three (UPLOADER, UPLOADER1, UPLOADER2,
*&     UPLOADER3), of which UPLOADER1 and UPLOADER2 are MANDATORY.
*&   - the handler is ZCL_M016_CBR_LOGIC.
*&
*& THE PROPERTY AGENT SCREENSHOTS ARE NOT A FEATURE OF THIS JOURNEY. Four of
*& the seven images in the requirement document show a property-agent
*& selection. That is the family's tasheel flow and it is already handled in
*& ZCL_EGA_CJ_FW_RO_ABS_V1->MAPPER( ): a BP value longer than ten characters
*& is read as a tasheel transaction id, ZEGA_T_CJ_BP_REL resolves it to the
*& owner/applicant pair, and it is stored on characteristic CJ10. No CJS
*& field, no CJS code - the launch parameter decides it.
*&
*& REVIEW-BE: the requirement document is titled "Building Regulations /
*& Change of Land Use" and those are two services. The NCBR screens resolve
*& to CBR alone; change of land use is M015, which is out of scope and has no
*& feeder. Flagged rather than merged - one CJS journey has one
*& BKND_JOURNEY, so merging is a decision for the owning team.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside 'M016'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M016'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ------------------------------------------------- the Arabic title
  SELECT SINGLE description FROM zega_t_cj_idt
    WHERE journeyid = @c_jny AND spras = 'A'
    INTO @DATA(lv_title_ar).
  IF sy-subrc <> 0.
    CLEAR lv_title_ar.
  ENDIF.

  SELECT SINGLE description FROM zega_t_cj_idt
    WHERE journeyid = @c_jny AND spras = 'E'
    INTO @DATA(lv_title_en).
  IF sy-subrc <> 0 OR lv_title_en IS INITIAL.
    lv_title_en = 'Change Building Regulations'.
  ENDIF.

* ---------------------------------------------------------------- header
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = lv_title_en
    title_ar      = lv_title_ar
    subtitle      = 'Apply to change the building regulations on a plot you own.'
    subtitle_ar   = 'تقديم طلب لتغيير أنظمة البناء على قطعة أرض تملكها.'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_M016_CBR_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'MML'
    bknd_journey  = 'M016'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* STEP TITLES: the legacy stage list for M016 is
* "Parcel Selection,Documents,Fees & Payment" - set by the BAdI's READ in the
* STAGES row's ADDITIONALDATA3 and present in no /QNV/ column. STP2 is named
* "Regulation & Documents" instead, because the usage type is the point of
* this journey and "Documents" hides it.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Parcel Selection' title_ar = 'اختيار القطعة'
      icon = 'sap-icon://map' bknd_screen = 'NCBR_1_1'
      next_requires = 'PARCELSELECTOR' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Regulation & Documents' title_ar = 'النظام والمستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NCBR_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NCBR_1_3'
      active = 'X' ) ) ).

* --------------------------------------------------- STP1 Parcel Selection
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSELECTOR' ftype = 'PARCEL' required = 'X'
      zlabel = 'Parcel Selection' zlabel_ar = 'اختيار القطعة'
      msg = 'Select the parcel whose building regulations you want to change'
      msg_ar = 'اختر القطعة التي ترغب في تغيير أنظمة البناء الخاصة بها'
      default_val = 'API:PROPERTY:PropertiesSet::Type=Parcel'
      tech_name = 'INTRENO_PARCEL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'PARCELHINT' ftype = 'DISPLAY'
      default_val = 'Can''t find a parcel? Your properties are listed on ' &&
                    'your home page.' ) ) ).

* --------------------------------------------------- STP2 Regulation & Documents
* USAGETYPE IS SEEDED WITH NO OPTIONS, AND THAT IS DELIBERATE.
*
* RAKSELECTUSAGETYPE is EXTENDED in the export - a composite drawn by
* JavaScript - and its row carries NOTHING that names a list: SH_NAME blank,
* DATA1..DATA10 all blank, no TECHNICAL_NAME. So the export does not say what
* the choices are, and neither does anything else available from here.
*
* Inventing four plausible usage types would produce a dropdown that looks
* finished and posts values the backend has never heard of, which is worse
* than an empty one: a wrong list is harder to notice than no list. So the
* field is authored, labelled and bound, and its ZRAK_T_JNY_OPT rows are
* left for whoever can read the live control.
*
* REVIEW-F4: three ways to fill it, in order of preference -
*   1. ZRAK_T_JNY_OPT rows, if the list is short and stable;
*   2. DOMNAME, if it turns out to be a domain (M028's five building
*      dropdowns are NOT domains - VALUEHELPSET falls through to
*      FILL_CUSTOM_DOMAIN( ) and selects from the real-estate tables, so
*      this one may be the same shape);
*   3. an API: directive once ZCL_RAK_VALUEHELP_API exists. It does not yet.
*
* CLOSED_LIST is set: a usage type the citizen types freely cannot be
* accepted, so the typable ComboBox default only invites pointless typing
* and pops a keyboard on a touch device. Note CLOSED_LIST is one of the four
* DDIC columns that are in git but need activation and a table adjust before
* the code reading them behaves.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'RAKSELECTUSAGETYPE' ftype = 'SELECT' required = 'X'
      closed_list = 'X'
      zsection = 'Requested Regulation'
      zlabel = 'Requested usage type' zlabel_ar = 'نوع الاستخدام المطلوب'
      placeholder = 'Select a usage type'
      placeholder_ar = 'اختر نوع الاستخدام'
      msg = 'Select the usage type you are applying for'
      msg_ar = 'اختر نوع الاستخدام المطلوب'
*     REVIEW-BE: no TECHNICAL_NAME on the legacy control, so the name the
*     backend expects is unknown. USAGETYPE matches the control's own name,
*     which is the convention the other fields on this screen follow, but it
*     is a GUESS - and a field whose TECH_NAME the backend does not
*     recognise renders, validates, posts and arrives as nothing.
      tech_name = 'USAGETYPE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'ENTERTEXT' ftype = 'TEXTAREA' required = 'X'
      zsection = 'Request Details'
      zlabel = 'Describe the change you are requesting'
      zlabel_ar = 'اذكر تفاصيل التغيير المطلوب'
      placeholder = 'Describe the building regulation change'
      placeholder_ar = 'اذكر تفاصيل تغيير نظام البناء'
      msg = 'Describe the change you are requesting'
      msg_ar = 'يرجى ذكر تفاصيل التغيير المطلوب'
      min_len = 10 max_len = 1000
      tech_name = 'PLOTLONGTEXT' )
*   THE FOUR UPLOADERS, AND THE DOCUMENT-TYPE INDEX THEY CARRY.
*
*   Each legacy uploader row holds DATA1 = ZFM_EGA_CJ_FW_READ_ATTACHMENTN and
*   DATA2 = 1, 2 or 3. DATA2 is the document type: the BAdI reads it as
*   CT_ATTACMENTS-FILE_TYPE, passes it to CREATE_ATTACHMENT as DOC_TYPE, and
*   files it as ZDT_EGA_CJ_ATTR-DIFFCRT.
*
*   REVIEW-BE, AND THIS ONE IS NOT COSMETIC: CJS DOES NOT SEND IT.
*   ZCL_RAK_JOURNEY_BE->ATTACHMENTS_FOR_BACKEND( ) sets identifier1,
*   identifier2, file_name and file_content and nothing else, so FILE_TYPE
*   arrives blank and every document is filed with a blank DIFFCRT.
*   CREATE_ATTACHMENT's own mandatory check only tests OBJTRG and OBJSRC, so
*   a blank type passes silently. Two consequences:
*
*     - the case cannot tell a title deed from a site plan;
*     - GET_ATTACHMENT( ) de-duplicates on
*       ( objsrc, diffcrt, objsrctype, objtrgtype ), so two files uploaded to
*       ONE field come back as one - the newest - on re-read.
*
*   identifier1 does carry the CJS field name, so the documents are not
*   indistinguishable, and a BAdI could map field name to type. But nothing
*   does that today. ATTACH_MULTI is therefore left OFF on every uploader
*   here: one file per field is the shape that survives a round trip.
*   UPLOADER - parent UPLOADERBOX, optional, and the ONE uploader M011 does
*   not have. It carries no DATA2 at all, where the other three carry 1, 2
*   and 3, so it is not one of the numbered document types.
*
*   REVIEW-TEXT: captions for this and UPLOADER3 come from their LABEL rows
*   through /QNV/SB_LABELT and are not in the export dump. Both are neutral
*   stand-ins, not the live wording.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'UPLOADER' ftype = 'UPLOAD'
      zsection = 'Attachments'
      zlabel = 'Current building regulation' zlabel_ar = 'نظام البناء الحالي'
      has_attach = 'X' attach_label = 'Add document'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
*   UPLOADER3 - parent PART2, optional, DATA2 = 3.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
*   DTYPE: IS THE LEGACY DOCUMENT TYPE, read from the export rather than
*   assigned. Each uploader row carries DATA2 and the BAdI files it as
*   ZDT_EGA_CJ_ATTR-DIFFCRT; without it every file arrives typed blank and
*   the case cannot tell one document from another - and CREATE_ATTACHMENT
*   only checks OBJTRG and OBJSRC, so it passes silently.
*
*   The type belongs to the UPLOADER row, not to the container the CJS
*   field is named after, and both screens agree:
*
*     UPLOADER1  parent NOCCONT     DATA2=1   -> field NOCCONT
*     UPLOADER2  parent LETTERCONT  DATA2=2   -> field LETTERCONT
*     UPLOADER3  parent PART2       DATA2=3   -> field UPLOADER3
*     UPLOADER   no DATA2                     -> no DTYPE:, deliberately
*
*   It rides DEFAULT_VAL behind a prefix, the same convention as TEXT: and
*   API:, and for the same reason: an uploader has no use for a default
*   value, and a new DDIC column would need an activation and a table
*   adjust first. The engine's seeding guard skips all three prefixes.
*
*   IT DOES NOT UNLOCK ATTACH_MULTI. Two files on the SAME field share a
*   field and therefore share a type, and GET_ATTACHMENT( ) de-duplicates
*   on (objsrc, diffcrt, objsrctype, objtrgtype). Multi-file needs the
*   occurrence key in identifier1, which is a different mechanism.
      field_name = 'UPLOADER3' ftype = 'UPLOAD'
      default_val = 'DTYPE:3'
      zsection = 'Attachments'
      zlabel = 'Supporting document' zlabel_ar = 'مستند مؤيد'
      has_attach = 'X' attach_label = 'Add document'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
*   ======== THE TWO CONDITIONAL DOCUMENT GROUPS ========================
*   Identical to M011's, and for the identical reason - NCBR_1_2 carries the
*   same NOCCONT and LETTERCONT VBOXes holding UPLOADER1 (DATA2=1) and
*   UPLOADER2 (DATA2=2), both MANDATORY = X, and the same
*   ZCL_EGA_CJ_FW_RO_ABS_V1->FIELD_CONTROL( ) decides whether either shows:
*   NOC hidden unless the parcel is mortgaged, LETTER hidden unless it has
*   more than one TR0800 owner.
*
*   THE CJS FIELD TAKES THE CONTAINER'S NAME so the hide lands on it - the
*   BAdI clears ISVISIBLE on the CONTROLGROUP row, which is the container,
*   never the uploader. Full reasoning in ZRAK_M011_LOAD and in
*   ZCL_RAK_MUN_LOGIC's constants. M012 has NEITHER group, which was
*   checked rather than assumed from the family.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'NOCCONT' ftype = 'UPLOAD'
      default_val = 'DTYPE:1' required = 'X'
      zsection = 'Attachments'
      zlabel = 'NOC from the bank' zlabel_ar = 'شهادة عدم اعتراض من البنك'
      msg = 'A mortgaged parcel needs the bank''s no-objection certificate'
      msg_ar = 'القطعة المرهونة تتطلب شهادة عدم اعتراض من البنك'
      has_attach = 'X' attach_label = 'Attach NOC from bank'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'LETTERCONT' ftype = 'UPLOAD'
      default_val = 'DTYPE:2' required = 'X'
      zsection = 'Attachments'
      zlabel = 'Letter of consent' zlabel_ar = 'خطاب موافقة'
      msg = 'A parcel with more than one owner needs the other owners'' consent'
      msg_ar = 'القطعة التي لها أكثر من مالك تتطلب موافقة الملاك الآخرين'
      has_attach = 'X' attach_label = 'Letter of consent'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 ) ) ).

* --------------------------------------------------- STP3 Fees & Payment
* Identical to M011's - see that feeder.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'TOTALVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel = 'I would like to donate five dirhams to Ajer Charity Foundation.'
      zlabel_ar = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.'
      tech_name = 'DONATE' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'M016 Change Building Regulations - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT - add the SPRAS A row'.
    WRITE: / '           and re-run, or Arabic readers see English.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'STEPS'.
  WRITE: / '  STP1 Parcel Selection        NCBR_1_1   2 fields'.
  WRITE: / '  STP2 Regulation & Documents  NCBR_1_2   6 fields'.
  WRITE: / '  STP3 Fees & Payment          NCBR_1_3   4 fields'.
  WRITE: / ''.
  WRITE: / '*** THIS JOURNEY WILL NOT SUBMIT UNTIL USAGETYPE HAS OPTIONS ***'.
  WRITE: / '    It is REQUIRED and its option list is deliberately empty -'.
  WRITE: / '    see REVIEW-F4. Either seed ZRAK_T_JNY_OPT rows or clear'.
  WRITE: / '    REQUIRED before testing the rest of the flow.'.
  WRITE: / ''.
  WRITE: / 'WALKTHROUGH'.
  WRITE: / '  1. Launch &journey=M016 with a real session. For the property'.
  WRITE: / '     agent path, launch with a tasheel transaction id as the BP'.
  WRITE: / '     parameter - MAPPER( ) resolves the owner/applicant pair.'.
  WRITE: / '  2. Step 1: pick the parcel. Next is blocked until you do.'.
  WRITE: / '  3. Step 2: choose the usage type, describe the change, and'.
  WRITE: / '     attach whatever the backend asks for - the NOC upload'.
  WRITE: / '     appears only for a mortgaged parcel and the consent'.
  WRITE: / '     upload only for one with more than one owner. Both are'.
  WRITE: / '     hidden by FIELD_CONTROL( ), not by a CJS rule.'.
  WRITE: / '  4. Step 3 is the payment card.'.
  WRITE: / '  Pay is refused without the Terms checkbox and without a fee'.
  WRITE: / '  total - the legacy PAY-E semantic, enforced at the press in'.
  WRITE: / '  ZCL_RAK_MUN_LOGIC, because the PAYFEE card draws its own Pay'.
  WRITE: / '  button and no configuration can grey it out.'.
  WRITE: / '  Pay then creates the ZGCX case, the gateway opens, and the'.
  WRITE: / '  engine draws its own success page and happiness meter from'.
  WRITE: / '  MV_SUBMITTED and WANTS_FEEDBACK - neither is seeded here.'.
  WRITE: / '  There is NO Review step: the legacy service has none.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-F4'.
  WRITE: / '  USAGETYPE has NO options. RAKSELECTUSAGETYPE is EXTENDED and'.
  WRITE: / '  its export row carries no SH_NAME, no DATA1..DATA10 and no'.
  WRITE: / '  TECHNICAL_NAME - nothing names the list. Options were NOT'.
  WRITE: / '  invented: a wrong list is harder to notice than no list, and'.
  WRITE: / '  it would post values the backend never heard of. Fill from'.
  WRITE: / '  ZRAK_T_JNY_OPT, or DOMNAME if it is a domain, or an API:'.
  WRITE: / '  directive once ZCL_RAK_VALUEHELP_API exists (it does not).'.
  WRITE: / ''.
  WRITE: / 'REVIEW-BE'.
  WRITE: / '  - USAGETYPE''s TECH_NAME is a GUESS. The legacy control has no'.
  WRITE: / '    TECHNICAL_NAME, so the name the backend expects is unknown.'.
  WRITE: / '    A wrong one posts nothing, silently.'.
  WRITE: / '  - ATTACHMENT DOCUMENT TYPE IS NOT SENT. The legacy uploaders'.
  WRITE: / '    carry DATA2 = 1/2/3 as the document type; the BAdI files it'.
  WRITE: / '    as ZDT_EGA_CJ_ATTR-DIFFCRT. ATTACHMENTS_FOR_BACKEND( ) sets'.
  WRITE: / '    only identifier1/2, file_name and file_content, so DIFFCRT'.
  WRITE: / '    arrives blank and passes the mandatory check. The case then'.
  WRITE: / '    cannot tell a title deed from a site plan, and because'.
  WRITE: / '    GET_ATTACHMENT( ) de-duplicates on'.
  WRITE: / '    (objsrc, diffcrt, objsrctype, objtrgtype), two files on one'.
  WRITE: / '    field come back as one. ATTACH_MULTI is off everywhere here'.
  WRITE: / '    for that reason. Affects M011 and M012 identically.'.
  WRITE: / '  - The domain validations run in the BAdI on post and are not'.
  WRITE: / '    re-implemented in CJS. See ZCL_RAK_MUN_LOGIC.'.
  WRITE: / '  - Fees come from ZCL_EGA_MUN_CJ_FEES_M016->GET_INITIAL_FEE.'.
  WRITE: / '  - M015 Change of Land Use shares this requirement document''s'.
  WRITE: / '    title and is a DIFFERENT service. Not migrated.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-TECH  (fields with no TECH_NAME, each deliberate)'.
  WRITE: / '  PARCELHINT  guidance paragraph'.
  WRITE: / '  REVIEW      the engine''s review renderer'.
  WRITE: / '  PAYFEE      the payment card'.
  WRITE: / '  UPLOADER(3) post through the attachment channel'.
  WRITE: / '  NOCCONT     conditional NOC upload; attachment channel'.
  WRITE: / '  LETTERCONT  conditional consent upload; attachment channel'.
  WRITE: / ''.
  WRITE: / 'NOT MIGRATED'.
  WRITE: / '  As M011 - stage bar, header labels, buttons, the payment'.
  WRITE: / '  card''s own radios and fee list, the confirmation page,'.
  WRITE: / '  UPLOADER1_DELETED / UPLOADER2_DELETED (MANDATORY=X with'.
  WRITE: / '  VISIBLE=blank). Plus the property-agent screens, which are'.
  WRITE: / '  the launch-parameter tasheel flow and not fields.'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO'.
  WRITE: / '  - Fill USAGETYPE''s options. Nothing else blocks the journey.'.
  WRITE: / '  - Run ZCL_RAK_CJS_XCHECK for M016.'.
  WRITE: / '  - Stage 2 (NCBR_2_1..2_3) is a separate service.'.
  WRITE: / '  - Nothing here has been activated or run.'.
