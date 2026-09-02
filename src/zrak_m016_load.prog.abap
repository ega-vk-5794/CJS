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
*&   STPR  (none)    Review
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
      next_requires = 'PARCELSEL' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Regulation & Documents' title_ar = 'النظام والمستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NCBR_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STPR' seqnr = 25
      title = 'Review' title_ar = 'مراجعة'
      icon = 'sap-icon://inspect' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NCBR_1_3'
      active = 'X' ) ) ).

* --------------------------------------------------- STP1 Parcel Selection
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSEL' ftype = 'PARCEL' required = 'X'
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
      field_name = 'USAGETYPE' ftype = 'SELECT' required = 'X'
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
      field_name = 'PLOTLONGTEXT' ftype = 'TEXTAREA' required = 'X'
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
*   indistinguishable, and a BAdI could map field name to type. The type
*   is now sent as well - ZCL_RAK_JOURNEY_BE writes DIFFCRT from the
*   field's own DTYPE: below - so the case can tell a title deed from an
*   Emirates ID without any BAdI change.
*
*   ATTACH_MULTI IS STILL OFF, and the type does not change that: two
*   files on the SAME field share a field and therefore share a type, so
*   they de-duplicate to one on re-read exactly as before. Multi-file
*   needs the OCCURRENCE key in identifier1, which is a different
*   mechanism. One file per field remains the shape that survives.
*   DTYPE: IS THE LEGACY DOCUMENT TYPE, read from the export rather than
*   assigned. /QNV/SB_UI_DEFIN carries DATA2 on each uploader and the BAdI
*   files it as ZDT_EGA_CJ_ATTR-DIFFCRT; without it every file arrives
*   typed blank and the case cannot tell one document from another.
*
*   The mapping is evidence, not order-of-appearance: NCBR_1_2 carries
*   UPLOADER1 = 1, UPLOADER2 = 2, UPLOADER3 = 3, and its MANDATORY pattern
*   corroborates which field is which - 1 and 2 mandatory, 3 optional,
*   exactly as these rows are. DOC_SUPPORT has no legacy counterpart on
*   that screen and therefore gets no type, which is the honest answer
*   rather than a fourth number nobody published.
*
*   It rides DEFAULT_VAL behind a prefix, the same convention as TEXT: and
*   API:. An uploader has no use for a default value, and the engine's
*   seeding guard skips all three prefixes.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'DOC_TITLEDEED' ftype = 'UPLOAD'
      default_val = 'DTYPE:1' required = 'X'
      zsection = 'Attachments'
      zlabel = 'Title deed' zlabel_ar = 'سند الملكية'
      msg = 'The title deed is required'
      msg_ar = 'سند الملكية مطلوب'
      has_attach = 'X' attach_label = 'Add title deed'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'DOC_ID' ftype = 'UPLOAD'
      default_val = 'DTYPE:2' required = 'X'
      zsection = 'Attachments'
      zlabel = 'Emirates ID of the owner' zlabel_ar = 'الهوية الإماراتية للمالك'
      msg = 'The owner''s Emirates ID is required'
      msg_ar = 'هوية المالك الإماراتية مطلوبة'
      has_attach = 'X' attach_label = 'Add Emirates ID'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'DOC_SITEPLAN' ftype = 'UPLOAD'
      default_val = 'DTYPE:3'
      zsection = 'Attachments'
      zlabel = 'Site plan' zlabel_ar = 'مخطط الموقع'
      has_attach = 'X' attach_label = 'Add site plan'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'DOC_SUPPORT' ftype = 'UPLOAD'
      zsection = 'Attachments'
      zlabel = 'Supporting document' zlabel_ar = 'مستند مؤيد'
      has_attach = 'X' attach_label = 'Add document'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 ) ) ).

* --------------------------------------------------- STPR Review
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STPR' seqnr = 10
      field_name = 'REVIEW' ftype = 'REVIEW'
      zlabel = 'Review your request' zlabel_ar = 'راجع طلبك' ) ) ).

* --------------------------------------------------- STP3 Fees & Payment
* Identical to M011's - see that feeder.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'TOTALFEESVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'ACCEPT_TERMS' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'DONATE' ftype = 'CHECKBOX'
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
  WRITE: / '  STPR Review                  (no screen) 1 field'.
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
  WRITE: / '  3. Step 2: choose the usage type, describe the change, attach'.
  WRITE: / '     the title deed and the owner''s Emirates ID.'.
  WRITE: / '  4. Review, then pay. Submit is gated on PAYFEE = PAID.'.
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
  WRITE: / '  DOC_*       uploads post through the attachment channel'.
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
