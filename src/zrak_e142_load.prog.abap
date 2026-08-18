REPORT zrak_e142_load.

*&---------------------------------------------------------------------*
*& E142 - Renew Consultancy Registration  (legacy NE014_2_1..2_5)
*&
*& The renewal sub-flow that sits beside E014 (registration). Both are
*& hand-authored from the real /QNV/SB_UI_DEFIN export rather than run
*& through ZCL_RAK_MIGRATOR, for the same reason: the migrator's own
*& header lists what it cannot derive - "zsection, placeholder, fgroup
*& AS A HEADING, min_len/max_len/min_val/max_val, msg_ar, fstate" - and
*& that is precisely the set that decides whether a page reads as a
*& designed form or as a flat list of inputs. It also cannot know that
*& legacy screen _5 is the confirmation page the CJS engine already
*& draws for itself, nor that the seven RAKUPLOADER_n controls have to
*& be renamed before they can coexist in one journey-wide model.
*&
*& STRUCTURE - 4 steps, not the 5 legacy screens:
*&   STP1  NE014_2_1  Select License   (the licence grid)
*&   STP2  NE014_2_2  Applicant & Company
*&   STP3  NE014_2_3  Eligibility
*&   STP4  NE014_2_4  Documents & Declaration
*&   (NE014_2_5 is "Your Request was submitted!" + the happiness meter
*&    - the engine appends its own confirmation and feedback step after
*&    submit, so migrating that screen would show it twice.)
*&
*& NO PAYMENT STEP. Verified against the export: there is no RAKPAY,
*& no RAKREMAININGFEES and no fee CLIST anywhere in NE014_2_*, and the
*& NEXT button on the last screen carries D3=SUBMIT, not a pay event.
*& Renewal is collected without a portal payment, so STP4 is a
*& documents step, there is no PAYFEE field and no NEXT_REQUIRES. That
*& is the one structural difference from E014, whose STP4 is the
*& payment card.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E142'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E142'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* HANDLER_CLASS was blank here, on the argument that a handler exists to
* drive a payment card or run custom logic and this journey has neither -
* no RAKPAY on any screen, and no UI_FIELD_LOGICS row anywhere in the
* export. Both halves of that are true and the conclusion did not follow.
*
* STP2 carries the same three-way applicant-type group the registration
* journey has (PARTNER_OWNER_1 / PARTNER_PRO_1 / PARTNER_MANAGER_1, one
* shared legacy DATA1 group, three separate GS_DATA-PARTNER_* flags in the
* backend), and the SEGMENTED field it collapses into carries ONE value
* bound to ONE of those three members. Handler-less, a citizen who renews
* as a PRO writes 'PARTNER_PRO_1' into GS_DATA-PARTNER_OWNER and leaves
* GS_DATA-PARTNER_PRO blank: the application posts, nothing errors, and
* the backend records a renewal by the owner personally.
*
* ZCL_E142_RENEW_CONSULT_LOGIC does that one fan-out and nothing else.
* Everything else on this journey is still configuration.
*
* BKND_JOURNEY = 'E014', NOT 'E142'. NE014_2_* is a second sub-flow of
* the SAME legacy screen number as the registration journey (NE014_1_*),
* so the raw backend code the two share is E014: every button on these
* screens posts through ZFM_EGA_CJ_FW_POST_N under CATEGORY 'EPDA' with
* no renewal-specific code of its own. E142 is the CJS-side identity
* only, which is what keeps the two flows' config apart.
* REVIEW-TECH: if the backend actually distinguishes renewal from first
* registration by a STATUS flag, a JOURNEYTYPE value or a different BAdI
* filter, BKND_JOURNEY needs revisiting - as it stands a renewal will be
* read and posted exactly like a new registration, which is right only
* if the backend really is code-blind to the difference.
*
* TITLE_AR is the screens' own TITLE_TEXT VA, and it is renewal-specific
* ("Renew consultancy registration"), not the generic registration
* caption, so it is carried as-is with nothing to confirm.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Renew Consultancy Registration'
    title_ar      = 'تجديد تسجيل الاستشارة'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_E142_RENEW_CONSULT_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E014'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* No NEXT_REQUIRES on any step: the only legacy gate of that kind is a
* payment, and there is none here. STP4's footer offers Submit directly.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Select License' title_ar = 'اختيار الرخصة'
      icon = 'sap-icon://table-view' bknd_screen = 'NE014_2_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Applicant & Company' title_ar = 'مقدم الطلب والشركة'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'NE014_2_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Eligibility' title_ar = 'الأهلية'
      icon = 'sap-icon://education' bknd_screen = 'NE014_2_3' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE014_2_4' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* One control: the licence the citizen is renewing. It is READONLY
* because the row is PICKED, not typed - the licences come from the
* backend (D1 = ZFM_EGA_CJ_FW_READ_TABLE_DATAN, D2 = LICENSE) and an
* editable grid would let a citizen retype an expiry date and renew a
* licence that does not exist. The selected row is what the rest of the
* journey hangs off, so it has to stay the backend's own data.
*
* The legacy MTABLE declares D3 = SingleSelectLeft: exactly one licence
* per application, selected by a leading radio column. The grid renders
* single-select accordingly; if renewal is ever meant to cover several
* licences at once, that is a DATA3 change on the legacy side first.
*
* ZSECTION is blank on purpose: NE014_2_1 has no section LABEL row at
* all (its only VALUE text is the page title), so there is no legacy
* heading to carry and none is invented.
  INSERT zrak_t_jny_fld FROM @( VALUE #(
    mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
    field_name = 'LICENSE' ftype = 'EDITABLE_TABLE' readonly = 'X'
    zlabel = 'Renew Consultancy Registration' zlabel_ar = 'تجديد تسجيل الاستشارة'
    tech_name = 'GS_DATA-LICENSE_NOC[]' ) ).

* --------------------------------------------------- STP2 fields
* ZSECTION carries the legacy section headings, VALUE-resolved:
* "Applicant Details" / "Owner" / "Company Details" / "Company Contact
* Verification". Note the last one is NOT E014's "Company Contact
* Details" - the renewal screen asks the citizen to verify the contact
* details already on file, and the heading says so.
*
* The four applicant fields and the four owner fields are READONLY
* because on the legacy screen they are LABELs bound to GS_DATA-PARTNER_*
* and GS_DATA-P_OWNER-* - the portal session and the licence record fill
* them, the citizen never types them.
*
* SHLP with ROLLNAME left BLANK on purpose: a rollname sends the engine's
* F4 resolver down the domain / value-table path, and these data elements
* have no value table, which renders an empty dropdown. The search help
* is what actually populates it.
*
* Two rows from the legacy card header are carried as READONLY context
* rather than dropped, because on a renewal they are the whole point of
* the page - they tell the citizen WHICH licence this application is
* against. They have no ZSECTION because the legacy header strip has no
* heading row.
*
* ERROR_1 (MESSAGE_STRIP on GS_DATA-ERROR) is not migrated: the engine
* renders backend and validation messages in its own message area, so a
* configured strip would duplicate it.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'CTX1_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'License number' zlabel_ar = 'رقم الرخصة'
      tech_name = 'GS_DATA-REF_RECNNR' )
*   REVIEW-TEXT: REF_NAME_1 has no LABEL_CON and no VALUE_CON in the
*   export - the legacy header renders it as bare text beside the licence
*   number, so it has no caption to carry and none is invented. It is
*   kept because it is bound and TOSAVE; supply a caption (the licence
*   holder's name, presumably) before go-live or it renders label-less.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'REF_NAME_1' ftype = 'READONLY' readonly = 'X'
      tech_name = 'GS_DATA-REF_NAME' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'APP_NAME' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Applicant name' zlabel_ar = 'اسم مقدم الطلب'
      tech_name = 'GS_DATA-PARTNER_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'APP_ID' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Emirates id Number' zlabel_ar = 'رقم الهوية الاماراتية'
      tech_name = 'GS_DATA-PARTNER_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'PARTNER_MOBILE_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Mobile Number' zlabel_ar = 'رقم الهاتف المتحرك'
      tech_name = 'GS_DATA-PARTNER_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'PARTNER_EMAIL_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Email ID' zlabel_ar = 'البريد الإلكتروني'
      tech_name = 'GS_DATA-PARTNER_EMAIL' )
*   The three legacy TBUTTONs (PARTNER_OWNER_1 / PARTNER_PRO_1 /
*   PARTNER_MANAGER_1, one shared DATA1 group) collapse into ONE
*   segmented field, named after the lowest-sequence member so that the
*   options below and anything that later reads the group agree on the
*   source field name.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )

*   REVIEW-CONTAINER: these four sit inside the legacy OWNER_FINDER >
*   PANEL_2 > OWNER container, which on the registration journey (E014)
*   is shown or hidden by the applicant-type buttons. This export
*   carries NO UI_FIELD_LOGICS rows for any NE014_2_* screen, so there
*   is nothing to translate into a rule and they are authored
*   always-visible. If the renewal screen is meant to behave like the
*   registration one - owner details only when a PRO or Manager applies
*   on the owner's behalf - author these four HIDDEN and add two SHOW
*   rules on PARTNER_OWNER_1 = PARTNER_PRO_1 / PARTNER_MANAGER_1. That
*   is a deliberate non-guess: inventing the rule would hide four fields
*   the legacy screen may well always show.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'NAME_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Owner'
      zlabel = 'Owner name' zlabel_ar = 'اسم المالك'
      tech_name = 'GS_DATA-P_OWNER-NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'ID_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Owner'
      zlabel = 'Emirates id Number' zlabel_ar = 'رقم الهوية الاماراتية'
      tech_name = 'GS_DATA-P_OWNER-ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'MOBILE_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Owner'
      zlabel = 'Mobile Number' zlabel_ar = 'رقم الهاتف المتحرك'
      tech_name = 'GS_DATA-P_OWNER-MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'EMAIL_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Owner'
      zlabel = 'Email ID' zlabel_ar = 'البريد الإلكتروني'
      tech_name = 'GS_DATA-P_OWNER-EMAIL' )

*   REQUIRED is set from the legacy MAND flag alone. None of the company
*   rows on NE014_2_2 carries MAND - unlike E014's equivalent screen,
*   where six of them do - which fits a renewal that pre-fills from the
*   licence record and only asks the citizen to correct what changed.
*   REVIEW-FE: if EPDA expects renewal to enforce the same mandatory set
*   as registration, that is a MAND change on the legacy screen, and
*   these REQUIRED flags follow it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'COMPANY_NAME_EN_1' ftype = 'INPUT'
      zsection = 'Company Details'
      zlabel = 'Company Name English' zlabel_ar = 'اسم الشركة بالانجليزية'
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_EN' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'COMPANY_NAME_AR_1' ftype = 'INPUT'
      zsection = 'Company Details'
      zlabel = 'Company Name Arabic' zlabel_ar = 'اسم الشركة عربي'
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_AR' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'REGISTERED_EMIRATES_1' ftype = 'SELECT'
      zsection = 'Company Details'
      zlabel = 'Company Registration Emirates' zlabel_ar = 'تسجيل الشركة الإمارات'
      placeholder = 'Select' shlp = 'ZSH_CJ_UAE_REGION'
      tech_name = 'GS_DATA-COMPANY-REGISTERED_EMIRATES' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 150
      field_name = 'ADDRESS_1' ftype = 'TEXTAREA'
      zsection = 'Company Details'
      zlabel = 'Company Address' zlabel_ar = 'عنوان الشركة'
      tech_name = 'GS_DATA-COMPANY-ADDRESS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 160
      field_name = 'TRADE_LICENSE_1' ftype = 'INPUT'
      zsection = 'Company Details'
      zlabel = 'Trade License' zlabel_ar = 'رخصة تجارية'
      tech_name = 'GS_DATA-COMPANY-TRADE_LICENSE' )

*   Order follows the legacy SEQUENCE (Mobile 1, E-mail, Mobile 2), not
*   the container order, because SEQUENCE is what the legacy renderer
*   actually laid out.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 170
      field_name = 'MOBILE_NO_1' ftype = 'PHONE'
      zsection = 'Company Contact Verification'
      zlabel = 'Mobile Number 1' zlabel_ar = 'رقم الجوال 1'
      tech_name = 'GS_DATA-COMPANY-MOBILE_NO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 180
      field_name = 'EMAIL_ID_1' ftype = 'EMAIL'
      zsection = 'Company Contact Verification'
      zlabel = 'E-mail ID' zlabel_ar = 'البريد الالكتروني'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-COMPANY-EMAIL_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 190
      field_name = 'TELEPHONE_NO_1' ftype = 'PHONE'
      zsection = 'Company Contact Verification'
      zlabel = 'Mobile Number 2' zlabel_ar = 'رقم الجوال 2'
      tech_name = 'GS_DATA-COMPANY-TELEPHONE_NO' ) ) ).

* --------------------------------------------------- STP3 fields
* Six legacy sections, each a combobox plus its supporting document.
*
* The uploaders are renamed from RAKUPLOADER_n to what they actually
* carry, and on this journey the need is provable rather than
* theoretical: RAKUPLOADER_1 is the Emirates ID here (document N7) and
* the Company Profile on STP4 (document DT); RAKUPLOADER_3 is the
* Manager's attested certificate here (FG) and the trade licence
* document there (DU); RAKUPLOADER_7 is the project list here (FI) and
* "Others" there (P6). A CJS model member is journey-wide, so keeping
* the legacy names would have three pairs of unrelated uploads sharing
* one member and one attachment list.
*
* TECH_NAME on an upload is the legacy document code (DATA2), which is
* what the attachment pipeline files against - not the control name.
*
* ATTACH_MAXMB is omitted throughout: unlike E014's document screen,
* neither NE014_2_3 nor NE014_2_4 carries a file-size notice, so the
* framework default applies rather than a number invented here.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'OWNER_TYPE_1' ftype = 'SELECT' required = 'X'
      zsection = 'Nationality'
      zlabel = 'Owner Nationality' zlabel_ar = 'جنسية المالك'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_OWNER'
      tech_name = 'GS_DATA-CONSULTANT-OWNER_TYPE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'EID_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Nationality'
      zlabel = 'Emirates ID' zlabel_ar = 'رقم الهوية الإماراتية'
      has_attach = 'X' attach_label = 'Upload Emirates ID'
      attach_types = 'pdf,jpg,png'
      tech_name = 'N7' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'MANAGER_EXP_1' ftype = 'SELECT' required = 'X'
      zsection = 'Manager'
      zlabel = 'Experience' zlabel_ar = 'الخبرة'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_MNG_EX'
      tech_name = 'GS_DATA-CONSULTANT-MANAGER_EXP' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'MANAGER_CV_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Manager'
      zlabel = 'CV Copy' zlabel_ar = 'نسخة من السيرة الذاتية'
      has_attach = 'X' attach_label = 'Upload CV Copy'
      attach_types = 'pdf,jpg,png'
      tech_name = 'FF' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'MANAGER_DEG_1' ftype = 'SELECT' required = 'X'
      zsection = 'Manager'
      zlabel = 'Degree' zlabel_ar = 'الدرجة'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_MNG_DEG'
      tech_name = 'GS_DATA-CONSULTANT-MANAGER_DEG' )
*   REVIEW-BE: this document and MANAGEMENT's "Certificate Copy" below
*   both carry legacy document code 'FG' - the same collision E014 has,
*   which confirms it is inherited from the shared screen family rather
*   than a typo in one export. Two different documents filed under one
*   code is either a deliberate shared bucket or a legacy data-entry
*   error; if it is the latter, the second upload overwrites the first
*   in the backend and the reviewer sees only one certificate.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 60
      field_name = 'MANAGER_CERT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Manager'
      zlabel = 'Attested Certificate' zlabel_ar = 'شهادة مصدقة'
      has_attach = 'X' attach_label = 'Upload Attested Certificate'
      attach_types = 'pdf,jpg,png'
      tech_name = 'FG' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 70
      field_name = 'COORDINATOR_1' ftype = 'SELECT' required = 'X'
      zsection = 'Co-ordinator'
      zlabel = 'Education' zlabel_ar = 'التعليم'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_COORDINA'
      tech_name = 'GS_DATA-CONSULTANT-COORDINATOR' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 80
      field_name = 'COORD_CERT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Co-ordinator'
      zlabel = 'Attested Certificate' zlabel_ar = 'شهادة مصدقة'
      has_attach = 'X' attach_label = 'Upload Attested Certificate'
      attach_types = 'pdf,jpg,png'
      tech_name = '76' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 90
      field_name = 'TEAM_1' ftype = 'SELECT' required = 'X'
      zsection = 'Technical'
      zlabel = 'Team' zlabel_ar = 'الفريق'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_TEAM'
      tech_name = 'GS_DATA-CONSULTANT-TEAM' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 100
      field_name = 'TEAM_EID_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Technical'
      zlabel = 'Emirates ID' zlabel_ar = 'رقم الهوية الإماراتية'
      has_attach = 'X' attach_label = 'Upload Emirates ID'
      attach_types = 'pdf,jpg,png'
      tech_name = '60' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 110
      field_name = 'CERTIFICATE_1' ftype = 'SELECT' required = 'X'
      zsection = 'Management'
      zlabel = 'ISO Certifications' zlabel_ar = 'شهادات الأيزو'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_CERTI'
      tech_name = 'GS_DATA-CONSULTANT-CERTIFICATE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 120
      field_name = 'ISO_CERT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Management'
      zlabel = 'Certificate Copy' zlabel_ar = 'نسخة الشهادة'
      has_attach = 'X' attach_label = 'Upload Certificate Copy'
      attach_types = 'pdf,jpg,png'
      tech_name = 'FG' )
*   "Branches" and "Speciality" below are legacy LABEL rows that head a
*   checkbox group rather than label a single control, so they are
*   carried as DISPLAY text inside their section instead of becoming a
*   ZSECTION of their own - splitting Management and Studies in two
*   would lose the grouping the legacy screen actually draws.
*   REVIEW-FE: both heading rows carry MAND in the export. A DISPLAY has
*   nothing to validate, so the flag is not carried; if MAND there means
*   "at least one box in this group", that is a group-level rule the
*   config has no expression for and it needs a handler check.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 130
      field_name = 'BRANCHES_TXT' ftype = 'DISPLAY' zsection = 'Management'
      default_val = 'Branches' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 140
      field_name = 'BRANCH_LOC_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'Local Branch' zlabel_ar = 'فرع محلي'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_LOC' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 150
      field_name = 'BRANCH_REG_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'Regional Branch' zlabel_ar = 'الفرع الإقليمي'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_REG' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 160
      field_name = 'BRANCH_INT_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'International Branch' zlabel_ar = 'الفرع الدولي'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_INT' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 170
      field_name = 'BRANCH_LINK_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'International Branch Links' zlabel_ar = 'روابط الفروع الدولية'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_LINK' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 180
      field_name = 'STUDY_PROJ_1' ftype = 'SELECT' required = 'X'
      zsection = 'Studies'
      zlabel = 'General Project' zlabel_ar = 'المشروع العام'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_PROJ'
      tech_name = 'GS_DATA-CONSULTANT-STUDY_PROJ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 190
      field_name = 'PROJ_LIST_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Studies'
      zlabel = 'List of Project' zlabel_ar = 'قائمة المشروع'
      has_attach = 'X' attach_label = 'Upload List of Project'
      attach_types = 'pdf,jpg,png'
      tech_name = 'FI' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 200
      field_name = 'SPECIALITY_TXT' ftype = 'DISPLAY' zsection = 'Studies'
      default_val = 'Speciality' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 210
      field_name = 'SPEC_GOVER_1' ftype = 'CHECKBOX' zsection = 'Studies'
      zlabel = 'Governmant Project' zlabel_ar = 'مشروع حكومى'
      tech_name = 'GS_DATA-CONSULTANT-SPEC_GOVER' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 220
      field_name = 'SPEC_MAJOR_1' ftype = 'CHECKBOX' zsection = 'Studies'
      zlabel = 'Major Development Project' zlabel_ar = 'مشروع تنموي كبير'
      tech_name = 'GS_DATA-CONSULTANT-SPEC_MAJOR' ) ) ).

* --------------------------------------------------- STP4 fields
* The last legacy screen, and the last step: its NEXT button is captioned
* "Submit" with D3 = SUBMIT, which is where the engine takes over.
*
* The three uploads have no ZSECTION because NE014_2_4 puts them
* straight into BODY with no heading row above them - the sibling
* registration screen has a "Required Documents" heading, this one does
* not, and a heading is not invented to match. Adding one to the legacy
* screen (or accepting an English-only one here) would group them.
*
* REVIEW-TEXT: the declaration and disclaimer paragraphs are carried in
* DEFAULT_VAL (CHAR1000) as DISPLAY text. Their Arabic originals are in
* the legacy dictionary but there is only ONE default_val per field and
* ZLABEL_AR is 80 characters, so the Arabic of these three sentences is
* NOT carried. Everything shorter in this journey is fully bilingual.
*
* REVIEW-TEXT: DECLARATION_LONG1's VALUE text is cut off in the export
* extract at "...are true and ac". The tail below is completed from the
* identical caption on the registration screen, which resolves to the
* same legacy value; confirm against /QNV/SB_VALUET before go-live, and
* if the two flows' texts have since diverged, this one wins.
*
* Legacy DECLARATION_NAME is dropped: it is an empty LABEL with neither
* a caption nor a technical name, which the legacy screen filled at
* runtime with the declaring owner's name. There is nothing in the
* export to render.
* REVIEW-TEXT: that is why the declaration below starts mid-clause ("as
* the company owner, hereby declare..."). With no handler there is
* nowhere to prefix the name, so it reads as exported. If the full
* sentence matters, the owner's name has to be prepended - which means
* either a handler or a re-worded legacy caption that stands alone.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'COMPANY_PROFILE_UPL' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Company Profile' zlabel_ar = 'ملف الشركة'
      has_attach = 'X' attach_label = 'Upload Company Profile'
      attach_types = 'pdf,jpg,png'
      tech_name = 'DT' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 20
      field_name = 'TRADE_LIC_UPL' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Trade License Document' zlabel_ar = 'وثيقة الرخصة التجارية'
      has_attach = 'X' attach_label = 'Upload Trade License Document'
      attach_types = 'pdf,jpg,png'
      tech_name = 'DU' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 30
      field_name = 'OTHERS_UPL' ftype = 'UPLOAD'
      zlabel = 'Others or Supporting' zlabel_ar = 'اخرى'
      has_attach = 'X' attach_label = 'Upload Others or Supporting'
      attach_types = 'pdf,jpg,png'
      tech_name = 'P6' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      field_name = 'DECLARATION_L1' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'as the company owner, hereby declare that all information provided in ' &&
                    'this application and in attached documents are true and accurate and ' &&
                    'in compliance with the law' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 50
      field_name = 'DECLARATION_L2' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'And I will be abide by all relevant regular conditions, instructions ' &&
                    'and guidelines to avoid legal action in case of violations' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 60
      field_name = 'DISCLAIMER_TXT' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'Note: Once you submit, you can''t cancel the application.' ) ) ).

* ------------------------------------------------------- grid columns
* The four LEVEL_CON=T columns under the legacy LICENSE table, in LSEQ
* order, with their own resolved captions.
*
* Legacy CTRL is LABEL on all four - the legacy grid was display-only -
* but CTRL here takes a control type, not a rendering hint, so the two
* validity dates are declared DATE and the two identifiers INPUT so the
* grid formats them the way the citizen expects. READONLY on every
* column keeps the display-only behaviour regardless: the CTRL value
* decides formatting, not editability.
*
* SCHOOL_NAME is the legacy column name and it is kept as-is even though
* its caption is "Company name" - COL_NAME has to match what the backend
* table actually returns, and renaming it here would simply blank the
* column.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSE'
      col_name = 'APPLICATION' seqnr = 10 ctrl = 'INPUT' readonly = 'X'
      width = '25%' align = 'Begin'
      zlabel = 'Registration number' zlabel_ar = 'رقم التسجيل' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSE'
      col_name = 'SCHOOL_NAME' seqnr = 20 ctrl = 'INPUT' readonly = 'X'
      width = '35%' align = 'Begin'
      zlabel = 'Company name' zlabel_ar = 'اسم الشركة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSE'
      col_name = 'VALIDFROM_1' seqnr = 30 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Issued at' zlabel_ar = 'تاريخ الإصدار' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSE'
      col_name = 'VALIDTO_1' seqnr = 40 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Expired at' zlabel_ar = 'انتهت صلاحيتها في' ) ) ).

* ---------------------------------------------------------------- rules
* NONE, and deliberately so. The export carries no UI_FIELD_LOGICS row
* on any NE014_2_* screen - not one show, hide or enable expression -
* so there is nothing to translate. The convention this journey would
* otherwise follow is the one E014 uses: author a target that has any
* SHOW rule as HIDDEN and emit only the SHOW rules, so "not shown" is
* the resting state and a later trigger value cannot accidentally leave
* a conditional field on screen.
* The one place that convention would apply is the OWNER_FINDER panel -
* see REVIEW-CONTAINER on STP2. The DELETE above still covers
* ZRAK_T_JNY_RULE so a rule added by hand is cleared on the next run.

* -------------------------------------------------------------- options
* The segmented group's three members. OPT_KEY is the legacy field name
* of each button, which is what the group writes back to
* GS_DATA-PARTNER_OWNER / _PRO / _MANAGER.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_OWNER_1' seqnr = 10
      opt_text = 'Owner' opt_text_ar = 'المالك' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_PRO_1' seqnr = 20
      opt_text = 'PRO' opt_text_ar = 'PRO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_MANAGER_1' seqnr = 30
      opt_text = 'Manager' opt_text_ar = 'المدير' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Renew Consultancy Registration'.
  WRITE: / '  4 steps (legacy NE014_2_1..2_4; _2_5 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Select License        1 field  (licence grid, 4 columns, read-only)'.
  WRITE: / '  STP2 Applicant & Company  19 fields, 4 sections'.
  WRITE: / '  STP3 Eligibility          22 fields, 6 sections, 7 uploads'.
  WRITE: / '  STP4 Documents             6 fields, 3 uploads'.
  WRITE: / '  0 rules, 3 segmented options, 4 grid columns'.
  WRITE: / '  No payment step - confirmed absent from the export, not omitted.'.
  WRITE: / '  Handler ZCL_E142_RENEW_CONSULT_LOGIC fans the segmented applicant'.
  WRITE: / '  type back out into GS_DATA-PARTNER_OWNER / _PRO / _MANAGER.'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-TECH  BKND_JOURNEY is E014, the legacy code this renewal flow'.
  WRITE: / '              shares with the registration journey. Revisit if the'.
  WRITE: / '              backend distinguishes renewal by STATUS, JOURNEYTYPE or a'.
  WRITE: / '              different BAdI filter.'.
  WRITE: / ' REVIEW-CONTAINER  the legacy OWNER_FINDER panel (owner name / ID /'.
  WRITE: / '              mobile / email on STP2) is authored always-visible: this'.
  WRITE: / '              export has NO UI_FIELD_LOGICS rows, so the show-on-PRO/'.
  WRITE: / '              Manager behaviour E014 has was not invented here.'.
  WRITE: / ' REVIEW-BE    document code FG is used by BOTH the Manager attested'.
  WRITE: / '              certificate and the ISO certificate copy on STP3.'.
  WRITE: / ' REVIEW-FE    no company field on NE014_2_2 carries MAND, so none is'.
  WRITE: / '              REQUIRED here - confirm renewal really is that permissive.'.
  WRITE: / ' REVIEW-FE    MAND on the "Branches" / "Speciality" heading labels is not'.
  WRITE: / '              carried; a "tick at least one" group check needs a handler.'.
  WRITE: / ' REVIEW-F4    every SELECT resolves through SHLP; run ZRAK_CJS_XCHECK to'.
  WRITE: / '              confirm each search help returns options in this client.'.
  WRITE: / ' REVIEW-TEXT  DECLARATION_LONG1 is truncated in the export extract; its'.
  WRITE: / '              tail was completed from the identical registration caption.'.
  WRITE: / ' REVIEW-TEXT  the declaration reads mid-clause because legacy'.
  WRITE: / '              DECLARATION_NAME (empty label, filled at runtime) is dropped.'.
  WRITE: / ' REVIEW-TEXT  the 3 declaration/disclaimer sentences carry English only'.
  WRITE: / '              (one DEFAULT_VAL per field; ZLABEL_AR is 80 chars).'.
  WRITE: / ' REVIEW-TEXT  REF_NAME_1 on STP2 has no caption anywhere in the export'.
  WRITE: / '              and renders label-less until one is supplied.'.
  WRITE: / ' REVIEW-TEXT  STP4''s three uploads have no legacy section heading, so'.
  WRITE: / '              they sit outside any section (the sibling screen has one).'.
