REPORT zrak_e015_load.

*&---------------------------------------------------------------------*
*& E015 - Environmental Study  (legacy NE015_1_1..1_5)
*&
*& Hand-authored from the real /QNV/SB_UI_DEFIN export, with every
*& caption taken from the legacy label / value dictionaries
*& (/QNV/SB_LABELT, /QNV/SB_VALUET) rather than derived from a field
*& name - the migrator's own header lists what it cannot derive
*& ("zsection, placeholder, fgroup AS A HEADING, min_len/max_len/
*& min_val/max_val, msg_ar, fstate"), which is exactly the set that
*& decides whether a page reads as a designed form or as a flat list of
*& inputs.
*&
*& STRUCTURE - 4 steps, not the 5 legacy screens:
*&   STP1  NE015_1_1  Applicant & Project
*&   STP2  NE015_1_2  Study Details
*&   STP3  NE015_1_3  Documents & Declaration
*&   STP4  NE015_1_4  Payment
*&   (NE015_1_5 is "Your Request was submitted!" + the happiness meter -
*&    the engine appends its own confirmation and feedback step after
*&    submit, so migrating that screen would show it twice.)
*&
*& THE ONE THING THAT MAKES THIS JOURNEY DIFFERENT: STP2 is a THREE-WAY
*& branch, not a form. The legacy screen carries three complete blocks -
*& Industry, Development Project and Others - each bound to its own
*& backend structure (GS_DATA-ENVSTUDY_IND / _PROJ / _OTHER), and every
*& row in each block carries DATA4 = PROJECT_TYPE with DATA5 = 1, 2 or 9.
*& That is the legacy conditional-visibility mechanism, and it is
*& translated below into 14 SHOW rules on PROJECT_TYPE. Get this wrong
*& and the citizen sees all three blocks at once, which is how the same
*& page ends up posting three different study records.
*&
*& HAS A PAYMENT STEP: NE015_1_4 carries a RAKPAY control (field PAY,
*& D3 = PAYMENT) and is field-for-field identical to NE014_1_4, the
*& consultancy-registration payment screen.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E015'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E015'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* BKND_* are the real values off the legacy screens: every navigation
* button on NE015_1_* carries DATA1 = ZFM_EGA_CJ_FW_POST_N and
* DATA2 = ZFM_EGA_CJ_FW_READ_N under CATEGORY 'EPDA', and the screens
* name backend class ZCL_EGA_CJ_CONSULTANT_ABS. So this journey is wired
* live rather than shipped inert.
*
* BKND_JOURNEY = 'E015' - unlike the E014 family, this screen number is
* not shared with any other flow, so the CJS code and the legacy code are
* the same and there is nothing to reconcile.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Environmental Study'
    title_ar      = 'الدراسة البيئية'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_E015_ENV_STUDY_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E015'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* NEXT_REQUIRES = PAYFEE on STP4 is what stops the footer offering Submit
* on an unpaid application - the step says so before the citizen presses,
* instead of the handler refusing afterwards.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Applicant & Project' title_ar = 'مقدم الطلب والمشروع'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'NE015_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Study Details' title_ar = 'تفاصيل الدراسة'
      icon = 'sap-icon://detail-view' bknd_screen = 'NE015_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE015_1_3' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Payment' title_ar = 'الدفع'
      icon = 'sap-icon://credit-card' bknd_screen = 'NE015_1_4'
      next_requires = 'PAYFEE' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* ZSECTION carries the legacy section headings, VALUE-resolved:
* "Applicant Details" / "Owner details" / (the permit and project rows
* head no section of their own on the legacy screen).
*
* The four applicant fields are READONLY because on the legacy screen
* they are LABELs bound to GS_DATA-PARTNER_* - the portal session fills
* them, the citizen never types them.
*
* SHLP with ROLLNAME left BLANK on purpose: a rollname sends the engine's
* F4 resolver down the domain / value-table path, and these data elements
* have no value table, which renders an empty dropdown. The search help
* is what actually populates it.
*
* ERROR_1 (MESSAGE_STRIP on GS_DATA-ERROR) and ERROR_FILES (the CLIST of
* rejected files hanging off it) are not migrated: the engine renders
* backend and validation messages in its own message area, so a
* configured strip would duplicate it.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'APP_NAME' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Applicant name' zlabel_ar = 'اسم مقدم الطلب'
      tech_name = 'GS_DATA-PARTNER_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'APP_ID' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Emirates id Number' zlabel_ar = 'رقم الهوية الاماراتية'
      tech_name = 'GS_DATA-PARTNER_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'PARTNER_MOBILE_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Mobile Number' zlabel_ar = 'رقم الهاتف المتحرك'
      tech_name = 'GS_DATA-PARTNER_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 40
      field_name = 'PARTNER_EMAIL_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Email ID' zlabel_ar = 'البريد الإلكتروني'
      tech_name = 'GS_DATA-PARTNER_EMAIL' )
*   TWO legacy TBUTTONs here, not three: this screen's DATA1 group is
*   PARTNER_OWNER_1,PARTNER_REP_1 - Owner / Representative - where E014's
*   is Owner / PRO / Manager. Confirmed from the real DATA1 group
*   membership, not assumed identical because the two screens share the
*   OWNER_FINDER building block. The group collapses into ONE segmented
*   field, named after the lowest-sequence member so the options and the
*   handler's role fan-out agree on the source field name.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 50
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )

*   HIDDEN by default and revealed by R001 below. The legacy
*   UI_FIELD_LOGICS is explicit and counter-intuitive, so it is worth
*   stating plainly: OWNER_FINDER-V-F sits on the Owner button and
*   OWNER_FINDER-V-T on Representative - i.e. the owner lookup appears
*   only when somebody applies ON BEHALF of the owner, never when the
*   owner applies personally. Authored HIDDEN with a single SHOW rule so
*   "not shown" is the resting state.
*   REVIEW-BE: this is a live business-partner lookup (PERSON_SEARCH).
*   SEARCH is a recognised ftype so the field renders, but a press
*   returns nothing until ZCL_E015_ENV_STUDY_LOGIC redefines on_search.
*   Same open item as E014's OWNER_FINDER_BP and E027's three lookups -
*   one BP-search API, one place to wire it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 60
      field_name = 'OWNER_1' ftype = 'SEARCH' hidden = 'X'
      zsection = 'Owner details'
      zlabel = 'Owner details' zlabel_ar = 'بيانات المالك'
      tech_name = 'GS_DATA-OWNER' )

*   The consultant's own EPDA registration number - the licence this
*   study is filed under. MAND on its label, so REQUIRED here.
*   REVIEW-BE: legacy DATA1 = 'REGISTRATION' names the search kind the
*   legacy finder called. on_search is not wired for it either; see the
*   note above.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 70
      field_name = 'PERMIT_NUMBER_2' ftype = 'SEARCH' required = 'X'
      zlabel = 'EPDA Consultant Registration Number' zlabel_ar = 'رقم تسجيل استشاري'
      placeholder = 'Consultant Registration Number'
      msg = 'The EPDA consultant registration number is required'
      tech_name = 'GS_DATA-PERMIT_NUMBER' )

*   The branch selector. Everything on STP2 hangs off this one value, and
*   so does REFER_CASE_ID below, which is why it lives on STP1 where the
*   citizen sets it before reaching the branched page.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 80
      field_name = 'PROJECT_TYPE' ftype = 'SELECT' required = 'X'
      zlabel = 'Type of Project' zlabel_ar = 'نوع المشروع'
      placeholder = 'Select' shlp = 'ZSH_CJ_EPDA_PROJ_TYPE'
      msg = 'The project type is required'
      tech_name = 'GS_DATA-ENVSTUDY_IND-PROJECT_TYPE' )

*   HIDDEN and revealed by R002: the legacy row carries DATA4 =
*   PROJECT_TYPE with DATA5 = 1, so this existing-permit reference is
*   asked for on the Industry branch only. PROJECT_TYPE's own
*   UI_FIELD_LOGICS lists REFER_CASE_ID and its container as bare tokens
*   (no -V-T / -V-F suffix), which is the legacy grammar's "the DATA4 /
*   DATA5 pair on the TARGET decides" - and it does, unambiguously.
*   REVIEW-BE: legacy DATA1 = 'CASE_ID' names the search kind. on_search
*   is not wired; see the note on OWNER_1.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 90
      field_name = 'REFER_CASE_ID' ftype = 'SEARCH' hidden = 'X' required = 'X'
      zlabel = 'Existing EPDA Permit case id' zlabel_ar = 'معرف حالة تصريح EPDA الحالي'
      placeholder = 'Existing EPDA Permit case id'
      msg = 'The existing EPDA permit case id is required for an industry study'
      tech_name = 'GS_DATA-ENVSTUDY_IND-REFER_CASE_ID' ) ) ).

* --------------------------------------------------- STP2 fields
* The three-way branch. ZSECTION carries the legacy block headings,
* VALUE-resolved: "Industry" / "Development Project" / "Others".
*
* Every field in the Development Project and Others blocks is authored
* HIDDEN and revealed by the rules below, so "not shown" is the resting
* state and a PROJECT_TYPE value nobody anticipated cannot leave two
* blocks on screen at once.
*
* The Industry block is the exception, and deliberately so. Its four
* read-only rows (company name, trade licence, contact number, e-mail)
* carry NO DATA4 / DATA5 pair in the export - unlike its two editable
* rows, which carry DATA5 = 1 - so the legacy screen shows them
* unconditionally. They are the consultant's own registered details,
* which are worth showing whichever branch is chosen, so this reads as
* deliberate rather than as a gap.
* REVIEW-FE: if EPDA meant the whole Industry block to hide with its
* branch, add hidden = 'X' to those four and four more SHOW rules on
* PROJECT_TYPE = 1. That is a DATA4/DATA5 change on the legacy screen
* first, which is why it is not pre-empted here.
*
* PROJECT_TYPE is NOT re-authored on this step even though NE015_1_2
* carries a second control of that name bound to the same
* GS_DATA-ENVSTUDY_IND-PROJECT_TYPE. A CJS model member is journey-wide,
* so the STP1 field is already readable here and the rules below evaluate
* against it. Authoring it twice would put two controls on one backend
* field, and the later write would win silently.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   --- Industry (PROJECT_TYPE = 1) - read-only registered details
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'COMPANY_NAME_3' ftype = 'READONLY' readonly = 'X'
      zsection = 'Industry'
      zlabel = 'Company Name' zlabel_ar = 'اسم الشركة'
      tech_name = 'GS_DATA-ENVSTUDY_IND-COMPANY_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'TRADE_LICENSE_2' ftype = 'READONLY' readonly = 'X'
      zsection = 'Industry'
      zlabel = 'Trade Licene Number' zlabel_ar = 'رقم الرخصة التجارية'
      tech_name = 'GS_DATA-ENVSTUDY_IND-TRADE_LICENSE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'MOBILE_2' ftype = 'READONLY' readonly = 'X'
      zsection = 'Industry'
      zlabel = 'Contact Number' zlabel_ar = 'رقم الاتصال'
      tech_name = 'GS_DATA-ENVSTUDY_IND-MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'EMAIL_3' ftype = 'READONLY' readonly = 'X'
      zsection = 'Industry'
      zlabel = 'E-mail Id' zlabel_ar = 'البريد الالكتروني'
      tech_name = 'GS_DATA-ENVSTUDY_IND-EMAIL' )
*   --- Industry - the two the citizen actually fills (DATA5 = 1)
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'LOCATION_1' ftype = 'SELECT' hidden = 'X' required = 'X'
      zsection = 'Industry'
      zlabel = 'Location ID' zlabel_ar = 'كود الموقع'
      placeholder = 'Select' shlp = 'ZSH_CJ_LOCATION_ID'
      tech_name = 'GS_DATA-ENVSTUDY_IND-LOCATION' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'STUDY_TYPE_1' ftype = 'SELECT' hidden = 'X' required = 'X'
      zsection = 'Industry'
      zlabel = 'Type of Study' zlabel_ar = 'نوع الدراسة'
      placeholder = 'Select' shlp = 'ZSH_CJ_EPDA_ENVSTUDY'
      tech_name = 'GS_DATA-ENVSTUDY_IND-STUDY_TYPE' )

*   --- Development Project (PROJECT_TYPE = 2)
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'PROJECT_NAME_1' ftype = 'INPUT' hidden = 'X' required = 'X'
      zsection = 'Development Project'
      zlabel = 'Project Name' zlabel_ar = 'اسم المشروع'
      tech_name = 'GS_DATA-ENVSTUDY_PROJ-PROJECT_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'MOBILE_1' ftype = 'PHONE' hidden = 'X' required = 'X'
      zsection = 'Development Project'
      zlabel = 'Contact Number' zlabel_ar = 'رقم الاتصال'
      tech_name = 'GS_DATA-ENVSTUDY_PROJ-MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'EMAIL_1' ftype = 'EMAIL' hidden = 'X' required = 'X'
      zsection = 'Development Project'
      zlabel = 'E-mail Id' zlabel_ar = 'البريد الالكتروني'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-ENVSTUDY_PROJ-EMAIL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'LOCATION_2' ftype = 'SELECT' hidden = 'X' required = 'X'
      zsection = 'Development Project'
      zlabel = 'Location ID' zlabel_ar = 'كود الموقع'
      placeholder = 'Select' shlp = 'ZSH_CJ_LOCATION_ID'
      tech_name = 'GS_DATA-ENVSTUDY_PROJ-LOCATION' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'STUDY_TYPE_2' ftype = 'SELECT' hidden = 'X' required = 'X'
      zsection = 'Development Project'
      zlabel = 'Type of Study' zlabel_ar = 'نوع الدراسة'
      placeholder = 'Select' shlp = 'ZSH_CJ_EPDA_ENVSTUDY'
      tech_name = 'GS_DATA-ENVSTUDY_PROJ-STUDY_TYPE' )

*   --- Others (PROJECT_TYPE = 9)
*   EMAIL_2's label is the one row in this block with no MAND, so it is
*   the one field here that is not REQUIRED. Carried per-row rather than
*   harmonised with the sibling blocks, where the e-mail IS mandatory.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'COMPANY_NAME_2' ftype = 'INPUT' hidden = 'X' required = 'X'
      zsection = 'Others'
      zlabel = 'Company Name' zlabel_ar = 'اسم الشركة'
      tech_name = 'GS_DATA-ENVSTUDY_OTHER-COMPANY_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'PROJECT_NAME_2' ftype = 'INPUT' hidden = 'X' required = 'X'
      zsection = 'Others'
      zlabel = 'Project Name' zlabel_ar = 'اسم المشروع'
      tech_name = 'GS_DATA-ENVSTUDY_OTHER-PROJECT_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'MOBILE_3' ftype = 'PHONE' hidden = 'X' required = 'X'
      zsection = 'Others'
      zlabel = 'Contact Number' zlabel_ar = 'رقم الاتصال'
      tech_name = 'GS_DATA-ENVSTUDY_OTHER-MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 150
      field_name = 'EMAIL_2' ftype = 'EMAIL' hidden = 'X'
      zsection = 'Others'
      zlabel = 'E-mail Id' zlabel_ar = 'البريد الالكتروني'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-ENVSTUDY_OTHER-EMAIL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 160
      field_name = 'LOCATION_3' ftype = 'SELECT' hidden = 'X' required = 'X'
      zsection = 'Others'
      zlabel = 'Location ID' zlabel_ar = 'كود الموقع'
      placeholder = 'Select' shlp = 'ZSH_CJ_LOCATION_ID'
      tech_name = 'GS_DATA-ENVSTUDY_OTHER-LOCATION' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 170
      field_name = 'STUDY_TYPE_3' ftype = 'SELECT' hidden = 'X' required = 'X'
      zsection = 'Others'
      zlabel = 'Type of Study' zlabel_ar = 'نوع الدراسة'
      placeholder = 'Select' shlp = 'ZSH_CJ_EPDA_ENVSTUDY'
      tech_name = 'GS_DATA-ENVSTUDY_OTHER-STUDY_TYPE' ) ) ).

* --------------------------------------------------- STP3 fields
* ATTACH_MAXMB = 3 across the step, from this screen's own notice
* ("Each file maximum allowed size - 3MB") rather than the framework
* default.
*
* MASS_UPLOADER_1 is the one control on this journey the other five do
* not have: a legacy MASS_UPLOADER with DATA3 = 'X', which is the
* multiple-files flag. It becomes an UPLOAD with ATTACH_MULTI - the
* environmental study itself is a set of documents, not one file.
*
* TECH_NAME on an upload is the legacy document code (DATA2), which is
* what the attachment pipeline files against - not the control name.
*
* REVIEW-TEXT: the declaration and disclaimer paragraphs are carried in
* DEFAULT_VAL (CHAR1000) as DISPLAY text. Their Arabic originals are in
* the legacy dictionary but there is only ONE default_val per field and
* ZLABEL_AR is 80 characters, so the Arabic of these three sentences is
* NOT carried. Everything shorter in this journey is fully bilingual.
*
* REVIEW-TEXT: DECLARATION_LONG1's VALUE text is cut off in the export
* extract at "...are true and ac". The tail below is completed from the
* identical caption on the E014 registration screen, which resolves to
* the same legacy value; confirm against /QNV/SB_VALUET before go-live.
* That is also why the declaration reads mid-clause ("as the company
* owner, hereby declare...") - legacy DECLARATION_NAME is an empty LABEL
* the legacy screen filled at runtime with the declaring owner's name,
* and there is nothing in the export to render in its place.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = 'Each file maximum allowed size - 3MB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'ENV_STUDY_UPL' ftype = 'UPLOAD'
      zsection = 'Required Documents'
      zlabel = 'Environmental Study' zlabel_ar = 'دراسة بيئية'
      has_attach = 'X' attach_label = 'Upload Environmental Study'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3 attach_multi = 'X'
      tech_name = 'FW' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'TRADE_LICENSE_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Trade license' zlabel_ar = 'رخصة تجارية'
      has_attach = 'X' attach_label = 'Upload Trade license'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = '11' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'OTHERS_UPL' ftype = 'UPLOAD'
      zsection = 'Required Documents'
      zlabel = 'Others or Supporting' zlabel_ar = 'اخرى'
      has_attach = 'X' attach_label = 'Upload Others or Supporting'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3 attach_multi = 'X'
      tech_name = 'P6' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'DECLARATION_L1' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'as the company owner, hereby declare that all information provided in ' &&
                    'this application and in attached documents are true and accurate and ' &&
                    'in compliance with the law' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 60
      field_name = 'DECLARATION_L2' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'And I will be abide by all relevant regular conditions, instructions ' &&
                    'and guidelines to avoid legal action in case of violations' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 70
      field_name = 'DISCLAIMER_TXT' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'Note: Once you submit, you can''t cancel the application.' ) ) ).

* --------------------------------------------------- STP4 fields
* PAYFEE is the only control the payment card needs - ZCL_RAK_JOURNEY_LOGIC
* draws the fee list, the total, the method and channel blocks, the
* charges, the pop-up notice, the Pay button and the poll. The legacy
* screen's own radio groups (RB1..RB4 method, PW_RB1/PW_RB2 channel) and
* its FEESLIST CLIST are that same card, so they are deliberately NOT
* re-created as fields - the handler feeds their real captions into
* PAY_METHOD / PAY_CHANNEL / PAY_CHARGES instead.
*
* ACCEPT_TERMS is kept because it is a real gate: on the legacy screen its
* UI_FIELD_LOGICS is 'PAY-E' - it ENABLES the Pay button.
* REVIEW-FE: required-validation makes it a condition of leaving the step;
* it does not grey out the Pay button inside the card the way the legacy
* screen did. If that exact behaviour is wanted, it needs a render_field
* redefinition in the handler, not config.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 20
      field_name = 'ACCEPT_TERMS' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      tech_name = 'ACCEPT_TERMS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 30
      field_name = 'DONATE' ftype = 'CHECKBOX'
      zlabel = 'I would like to donate five dirhams to Ajer Charity Foundation.'
      zlabel_ar = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.'
      tech_name = 'DONATE' ) ) ).

* ---------------------------------------------------------------- rules
* R001 is the OWNER_FINDER toggle, straight from the legacy
* UI_FIELD_LOGICS: OWNER_FINDER-V-T on PARTNER_REP_1. One SHOW rule and
* no HIDE rule, because the field is authored HIDDEN - "not shown" is its
* resting state, and a third applicant type added later cannot
* accidentally leave the finder on screen.
*
* R002..R015 are the STP2 branch, from each target row's own DATA4 =
* PROJECT_TYPE / DATA5 = <value> pair. One rule per target field because
* ZRAK_T_JNY_RULE carries a single TGT_FIELD; grouping them would need a
* TOTABLE expression, which is for grid-scoped rules, not step fields.
*
* REVIEW-F4: the three DATA5 values are carried verbatim - 1, 2 and 9.
* Which one is Industry, which Development Project and which Others is
* read off the legacy block each row sits in (LABEL_3 "Industry" over the
* DATA5=1 rows, LABEL_4 "Development Project" over DATA5=2, LABEL_5
* "Others" over DATA5=9), NOT off the search help, because
* ZSH_CJ_EPDA_PROJ_TYPE's key list is not in this export. Run
* ZRAK_CJS_XCHECK and confirm the search help really returns 1 / 2 / 9 -
* if it returns text keys instead, these fourteen SRC_VALUEs are what
* needs changing and every branch stays hidden until they do.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R001'
      src_field = 'PARTNER_OWNER_1' src_op = 'EQ' src_value = 'PARTNER_REP_1'
      action = 'SHOW' tgt_field = 'OWNER_1' )

    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R002'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '1'
      action = 'SHOW' tgt_field = 'REFER_CASE_ID' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R003'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '1'
      action = 'SHOW' tgt_field = 'LOCATION_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R004'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '1'
      action = 'SHOW' tgt_field = 'STUDY_TYPE_1' )

    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R005'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '2'
      action = 'SHOW' tgt_field = 'PROJECT_NAME_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R006'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '2'
      action = 'SHOW' tgt_field = 'MOBILE_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R007'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '2'
      action = 'SHOW' tgt_field = 'EMAIL_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R008'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '2'
      action = 'SHOW' tgt_field = 'LOCATION_2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R009'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '2'
      action = 'SHOW' tgt_field = 'STUDY_TYPE_2' )

    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R010'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '9'
      action = 'SHOW' tgt_field = 'COMPANY_NAME_2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R011'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '9'
      action = 'SHOW' tgt_field = 'PROJECT_NAME_2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R012'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '9'
      action = 'SHOW' tgt_field = 'MOBILE_3' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R013'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '9'
      action = 'SHOW' tgt_field = 'EMAIL_2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R014'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '9'
      action = 'SHOW' tgt_field = 'LOCATION_3' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R015'
      src_field = 'PROJECT_TYPE' src_op = 'EQ' src_value = '9'
      action = 'SHOW' tgt_field = 'STUDY_TYPE_3' ) ) ).

* -------------------------------------------------------------- options
* The segmented group's TWO members - Owner and Representative, not
* E014's three. OPT_KEY is the legacy field name of each button, which is
* what the handler's role fan-out writes back to GS_DATA-PARTNER_OWNER /
* GS_DATA-PARTNER_REP.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_OWNER_1' seqnr = 10
      opt_text = 'Owner' opt_text_ar = 'المالك' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_REP_1' seqnr = 20
      opt_text = 'Representative' opt_text_ar = 'الوكيل' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Environmental Study'.
  WRITE: / '  4 steps (legacy NE015_1_1..1_4; _1_5 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Applicant & Project   9 fields, 2 sections'.
  WRITE: / '  STP2 Study Details        17 fields, 3 sections (a THREE-WAY branch)'.
  WRITE: / '  STP3 Documents             7 fields, 3 uploads'.
  WRITE: / '  STP4 Payment               3 fields (PAYFEE card + terms + donation)'.
  WRITE: / '  15 rules, 2 segmented options'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-F4    R002..R015 branch on PROJECT_TYPE = 1 / 2 / 9, read off the'.
  WRITE: / '              legacy DATA5 values and the block each row sits in.'.
  WRITE: / '              ZSH_CJ_EPDA_PROJ_TYPE''s key list is NOT in this export -'.
  WRITE: / '              confirm it returns 1/2/9 and not text keys, or every'.
  WRITE: / '              branch on STP2 stays hidden.'.
  WRITE: / ' REVIEW-FE    the 4 read-only Industry rows carry no DATA4/DATA5 and are'.
  WRITE: / '              authored always-visible, matching the legacy screen. If the'.
  WRITE: / '              whole block should hide with its branch, add hidden and 4'.
  WRITE: / '              more SHOW rules.'.
  WRITE: / ' REVIEW-BE    3 live lookups (OWNER_1, PERMIT_NUMBER_2, REFER_CASE_ID)'.
  WRITE: / '              render but return nothing - ZCL_E015_ENV_STUDY_LOGIC does'.
  WRITE: / '              not redefine on_search yet. Legacy search kinds are'.
  WRITE: / '              REGISTRATION and CASE_ID.'.
  WRITE: / ' REVIEW-BE    PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR are not in the UI'.
  WRITE: / '              export - set them in ZCL_E015_ENV_STUDY_LOGIC->ON_INIT'.
  WRITE: / '              once EPDA Finance confirms. Pay stays inert until then.'.
  WRITE: / ' REVIEW-TEXT  DECLARATION_LONG1 is truncated in the export extract; its'.
  WRITE: / '              tail was completed from the identical E014 caption.'.
  WRITE: / ' REVIEW-TEXT  the declaration reads mid-clause because legacy'.
  WRITE: / '              DECLARATION_NAME (empty label, filled at runtime) is dropped.'.
  WRITE: / ' REVIEW-TEXT  the 3 declaration/disclaimer sentences carry English only'.
  WRITE: / '              (one DEFAULT_VAL per field; ZLABEL_AR is 80 chars).'.
  WRITE: / ' REVIEW-F4    every SELECT resolves through SHLP; run ZRAK_CJS_XCHECK to'.
  WRITE: / '              confirm each search help returns options in this client.'.
