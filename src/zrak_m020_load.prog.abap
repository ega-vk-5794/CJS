*&---------------------------------------------------------------------*
*& Report ZRAK_M020_LOAD
*&---------------------------------------------------------------------*
*& M020 Renewal Grant Request - feeder.
*&
*& SCREENS, FROM ZEGA_T_CJ_UI_MAP for M020:
*&
*&     NRGR_1_2   ATTACHMENT   rwmode 1
*&     NRGR_1_3   INITIAL      rwmode 1     the fee read
*&     NRGR_1_3   FEES_1       rwmode 2     the post that creates the case
*&     NRGR_1_4   CPG_1        rwmode 1     the gateway
*&
*& THE SELECTOR READS GRANTS. The stepper calls step 1 "Parcel Selection"
*& where M019 says "Grant Selection", but the control and the role are
*& the same: Partnerrole YTR080. Reading it with TR0800 answers the
*& citizen's OWNED parcels, which renders perfectly and is wrong.
*&
*& THE DOCUMENT SET IS MOSTLY OPTIONAL. From the spec, only the mortgage
*& NOC and the free-text details carry an asterisk; the Sheikh Zayed
*& letter, the justification and the extra file do not. That asymmetry is
*& the point of the screen and is reproduced exactly - marking the
*& optional ones REQUIRED would block a valid application.
*&
*& GRANTS ABSTRACT: case ZGCR, owner role ZTR080, party list in note
*& CJ03. The handler inherits ZCL_RAK_GRANT_LOGIC.
*&
*& WHAT IS NOT VERIFIED. No /QNV export for NRGR_1_* has been read.
*& JUST_DETAILS is confirmed from the grants abstract's own READ( ) - it
*& is the CJ11 long text - and every other name is a reading of the spec.
*&---------------------------------------------------------------------*
REPORT zrak_m020_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M020'.

* ------------------------------------------------------------- teardown
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
    lv_title_en = 'Renewal Grant Request'.
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
    subtitle       = 'Apply to renew a grant you hold, and track the request.'
    subtitle_ar    = 'تقدم بطلب تجديد منحة قائمة، وتابع الطلب.'
    active         = 'X'
    handler_class  = 'ZCL_M020_RGR_LOGIC'
    bknd_active    = 'X'
    bknd_category  = 'MML'
    bknd_journey   = c_jny
    bknd_fm_post   = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read   = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Parcel Selection' title_ar = 'اختيار القطعة'
      icon = 'sap-icon://map' bknd_screen = 'NRGR_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NRGR_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NRGR_1_3'
      active = 'X' ) ) ).

* -------------------------------------------- STP1 Parcel Selection
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   REVIEW-BE: the API: directive's grants filter spelling is unverified,
*   exactly as on M019. If the list comes back as the citizen's OWNED
*   parcels rather than their grants, this is the line to correct - the
*   Partnerrole term must resolve to YTR080
*   (ZCL_RAK_PROPERTY_API=>C_ROLE_GRANT).
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSELECTOR' ftype = 'PARCEL' required = 'X'
      zsection = 'Please select the grant to renew'
      zsection_ar = 'يرجى اختيار المنحة المطلوب تجديدها'
      zlabel = 'Grant' zlabel_ar = 'المنحة'
      default_val = 'API:PROPERTY:PropertiesSet::Type=Parcel&Partnerrole=YTR080'
      msg = 'Select the grant you are renewing'
      msg_ar = 'يرجى اختيار المنحة المطلوب تجديدها' )

*   TEXT: in DEFAULT_VAL, not ZLABEL. ZLABEL is CHAR(150) and cuts on
*   INSERT, and a guidance line that loses its tail is gone from the
*   database rather than hidden by the renderer.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'RGRHINT' ftype = 'DISPLAY' readonly = 'X'
      default_val = 'TEXT:Can''t find a Grant? Your properties are listed on your home page.'
      zlabel = '' zlabel_ar = '' ) ) ).

* ---------------------------------------------------- STP2 Documents
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'RGRHEAD' ftype = 'DISPLAY' readonly = 'X'
      zsection = 'Please attach the following documents'
      zsection_ar = 'يرجى إرفاق المستندات التالية'
      zlabel = '' zlabel_ar = '' )

*   OPTIONAL, AND THE SPEC SAYS SO - no asterisk on either of the first
*   two. Marking them REQUIRED would refuse a submit the department
*   accepts.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'UPLOADER' ftype = 'UPLOAD'
      zlabel = 'Sheikh Zayed Program Letter' zlabel_ar = 'خطاب برنامج الشيخ زايد'
      attach_label = 'Sheikh Zayed Program Letter'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'UPLOADER2' ftype = 'UPLOAD'
      zlabel = 'Justification' zlabel_ar = 'المبرر'
      attach_label = 'Justification'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )

*   THE ONLY REQUIRED DOCUMENT. Enforced by this flag alone - the
*   required check for an UPLOAD tests the STAGED LIST by field name and
*   falls back to the GET_ATTACHMENTS( ) hook. A handler check on
*   GET_VAL( ) would refuse every submit, because BUILD_MODEL( ) gives an
*   UPLOAD field no model component at all.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'UPLOADER3' ftype = 'UPLOAD' required = 'X'
      zlabel = 'N.O.C From the Mortgaged Holder'
      zlabel_ar = 'شهادة عدم اعتراض من الجهة المرتهنة'
      attach_label = 'N.O.C From the Mortgaged Holder'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      msg = 'Attach the N.O.C from the mortgaged holder'
      msg_ar = 'يرجى إرفاق شهادة عدم اعتراض من الجهة المرتهنة' )

*   CONFIRMED NAME. JUST_DETAILS is the grants abstract's own name for
*   the CJ11 long text - its READ( ) reads the RE note into it - so this
*   one is not a guess. TEXTAREA, and the placeholder is the spec's own
*   wording.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'JUST_DETAILS' ftype = 'TEXTAREA' required = 'X'
      max_len = '1000'
      zlabel = 'Renewal Grant Request Details'
      zlabel_ar = 'تفاصيل طلب تجديد المنحة'
      placeholder = 'Please enter more details about the Renewal Grant request'
      placeholder_ar = 'يرجى إدخال المزيد من التفاصيل حول طلب تجديد المنحة'
      msg = 'REQUIRED:Describe the renewal you are requesting;LEN:Keep the description under 1000 characters'
      msg_ar = 'REQUIRED:يرجى وصف التجديد المطلوب;LEN:يرجى إدخال أقل من 1000 حرف'
      tech_name = 'JUST_DETAILS' )

*   PAIRS WITH THE TEXT ABOVE and is optional. The spec's label is
*   literally "Upload a File to describe your text above".
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'UPLOADER4' ftype = 'UPLOAD'
      zlabel = 'Upload a File to describe your text above'
      zlabel_ar = 'أرفق ملفاً يوضح النص أعلاه'
      attach_label = 'Supporting file'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' ) ) ).

* ----------------------------------------------- STP3 Fees & Payment
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )

*   PAY_SCREEN ONLY - NRGR_1_4, where the UI map puts CPG_1. Never
*   PAY_JOURNEY, which changes the BAdI filter, and never PAY_CATEGORY,
*   which blank means the journey's own MML.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 15
      field_name = 'PAY_SCREEN' ftype = 'DISPLAY'
      readonly = 'X' hidden = 'X'
      default_val = 'NRGR_1_4'
      zlabel = 'Payment screen' zlabel_ar = 'شاشة الدفع' )

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
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel = 'I would like to donate five dirhams to Ajer Charity Foundation.'
      zlabel_ar = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.'
      tech_name = 'DONATE' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* --------------------------------------------------------------- report
  WRITE: / 'M020 Renewal Grant Request - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT for SPRAS A.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'Steps    : STP1 Parcel Selection  NRGR_1_1'.
  WRITE: / '           STP2 Documents         NRGR_1_2  4 uploads + details'.
  WRITE: / '           STP3 Fees & Payment    NRGR_1_3'.
  WRITE: / '           (NRGR_1_4 is the CPG screen - PAY_SCREEN)'.
  WRITE: / ''.
  WRITE: / 'Handler  : ZCL_M020_RGR_LOGIC (inherits ZCL_RAK_GRANT_LOGIC)'.
  WRITE: / 'Backend  : GRANTS / ZGCR / owner role ZTR080 / RO_GRANT_ABS_V1'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO:'.
  WRITE: / '  1. The selector API: directive is unverified. If step 1'.
  WRITE: / '     lists OWNED parcels rather than grants, correct the'.
  WRITE: / '     Partnerrole term - it must resolve to YTR080.'.
  WRITE: / '  2. Only the NOC and the details text are REQUIRED, per the'.
  WRITE: / '     spec. Do not tighten the other three uploads.'.
  WRITE: / '  3. Field names other than JUST_DETAILS are read off the'.
  WRITE: / '     spec, not a /QNV export.'.
