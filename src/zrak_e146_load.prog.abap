REPORT zrak_e146_load.

*&---------------------------------------------------------------------*
*& E146 - Consultant Appeal  (legacy NE014_3_1..2_5)
*&
*& The third sub-flow of the E014 legacy screen family: registration is
*& NE014_1_*, renewal NE014_2_*, and this appeal NE014_3_*. Hand-authored
*& from the real /QNV/SB_UI_DEFIN export for the same reason as its two
*& siblings - the migrator's own header lists what it cannot derive
*& ("zsection, placeholder, fgroup AS A HEADING, min_len/max_len/min_val/
*& max_val, msg_ar, fstate"), which is exactly the set that decides
*& whether a page reads as a designed form or as a flat list of inputs.
*&
*& E146 is NOT an invented CJS code. NE014_3_* carries its own
*& JOURNEYTYPE row with VALUE = 'E146' on every screen, so the legacy
*& configuration already names this flow E146 while sharing screen
*& number 014 with the other two.
*&
*& STRUCTURE - 4 steps, not the 5 legacy screens:
*&   STP1  NE014_3_1  Select Case      (the APPEALS pick-list)
*&   STP2  NE014_3_2  Applicant, Company & Appeal
*&   STP3  NE014_3_3  Eligibility
*&   STP4  NE014_3_4  Payment
*&   (NE014_3_5 is "Your Request was submitted!" + the happiness meter -
*&    the engine appends its own confirmation and feedback step after
*&    submit, so migrating that screen would show it twice.)
*&
*& HAS A PAYMENT STEP, verified rather than assumed: NE014_3_4 carries a
*& RAKPAY control (field PAY, D3 = PAYMENT) and is field-for-field
*& identical to NE014_1_4, the registration flow's payment screen. That
*& is the structural difference from E142, which has no RAKPAY anywhere.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E146'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E146'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* BKND_JOURNEY = 'E014', NOT 'E146'. Every navigation button on
* NE014_3_* posts through ZFM_EGA_CJ_FW_POST_N / reads through
* ZFM_EGA_CJ_FW_READ_N under CATEGORY 'EPDA', and the backend class the
* screens name is ZCL_EGA_CJ_CONSULTANT_ABS - the SAME class the
* registration and renewal flows name. So the raw backend code the three
* share is E014; E146 is the CJS-side identity, which is what keeps the
* three flows' configuration apart.
*
* REVIEW-TECH: the legacy JOURNEYTYPE row does carry 'E146', so the
* backend is not entirely code-blind to the difference. If
* ZCL_EGA_CJ_CONSULTANT_ABS branches on JOURNEYTYPE rather than on the
* journey code, BKND_JOURNEY is right as it stands and the appeal is
* distinguished by the JOURNEYTYPE the read already sends. Confirm which
* of the two the class actually reads before go-live.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Consultant Appeal'
    title_ar      = 'استئناف المستشار'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_E146_CONSULT_APPEAL_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E014'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* NEXT_REQUIRES = PAYFEE on STP4 is what stops the footer offering Submit
* on an unpaid appeal - the step says so before the citizen presses,
* instead of the handler refusing afterwards.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Select Case' title_ar = 'اختيار الطلب'
      icon = 'sap-icon://table-view' bknd_screen = 'NE014_3_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Applicant & Appeal' title_ar = 'مقدم الطلب والاستئناف'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'NE014_3_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Eligibility' title_ar = 'الأهلية'
      icon = 'sap-icon://education' bknd_screen = 'NE014_3_3' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Payment' title_ar = 'الدفع'
      icon = 'sap-icon://credit-card' bknd_screen = 'NE014_3_4'
      next_requires = 'PAYFEE' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* One control: the case the consultant is appealing against. READONLY
* because the row is PICKED, not typed - the appealable cases come from
* the backend (D1 = ZFM_EGA_CJ_FW_READ_TABLE_DATAN, D2 = APPEALS) and an
* editable grid would let a citizen retype a permit number and appeal
* against a case that does not exist.
*
* The legacy MTABLE declares D3 = SingleSelectLeft: exactly one case per
* appeal, selected by a leading radio column. If an appeal is ever meant
* to cover several cases at once, that is a DATA3 change on the legacy
* side first.
*
* ZSECTION is blank on purpose: NE014_3_1 has no section LABEL row at
* all (its only VALUE text is the page title), so there is no legacy
* heading to carry and none is invented. ZLABEL carries the page title
* for the same reason its sibling STP1 on E142 does - the grid is the
* whole page and would otherwise render caption-less.
  INSERT zrak_t_jny_fld FROM @( VALUE #(
    mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
    field_name = 'APPEALS' ftype = 'EDITABLE_TABLE' readonly = 'X'
    zlabel = 'Consultant Appeal' zlabel_ar = 'استئناف المستشار'
    tech_name = 'GS_DATA-APPEAL[]' ) ).

* --------------------------------------------------- STP2 fields
* ZSECTION carries the legacy section headings, VALUE-resolved:
* "Applicant Details" / "Owner" / "Company Details" / "Company Contact
* Verification" / "Appeal Details". Note "Company Contact Verification"
* is the renewal wording, not E014's "Company Contact Details" - this
* screen was built from the renewal template, and the heading says so.
*
* The four applicant fields and the four owner fields are READONLY
* because on the legacy screen they are LABELs bound to GS_DATA-PARTNER_*
* and GS_DATA-P_OWNER-* - the portal session and the case record fill
* them, the citizen never types them.
*
* SHLP with ROLLNAME left BLANK on purpose: a rollname sends the engine's
* F4 resolver down the domain / value-table path, and these data elements
* have no value table, which renders an empty dropdown. The search help
* is what actually populates it.
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
*   number, so it has no caption to carry and none is invented. Same open
*   item as E142's STP2, from the same shared header strip. It is kept
*   because it is bound and TOSAVE; supply a caption before go-live or it
*   renders label-less.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'REF_NAME_1' ftype = 'READONLY' readonly = 'X'
      tech_name = 'GS_DATA-REF_NAME' )

*   REVIEW-TEXT: on THIS screen the first applicant row is captioned
*   "Permit number" (EPDA_NE014_3_2 label), not "Applicant name" as on
*   E014 and E015 - but it is still bound to GS_DATA-PARTNER_NAME. Either
*   the caption is a copy-paste error on the legacy screen or the appeal
*   flow deliberately shows the permit under the applicant heading. The
*   legacy caption is carried as-is rather than corrected to match the
*   binding, because guessing which of the two is wrong would silently
*   relabel a field the reviewer is used to. Confirm with EPDA and fix
*   whichever end is actually wrong.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'APP_NAME' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Permit number' zlabel_ar = 'رقم التصريح'
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
*   options below and the handler's role fan-out agree on the source
*   field name.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )

*   REVIEW-CONTAINER: these four sit inside the legacy OWNER_FINDER >
*   PANEL_2 > VBOX_23..26 containers, which on the registration journey
*   (E014) are shown or hidden by the applicant-type buttons. NE014_3_2
*   carries NO UI_FIELD_LOGICS row - not one show, hide or enable
*   expression - so there is nothing to translate into a rule and they
*   are authored always-visible. Same deliberate non-guess as E142: if
*   the appeal screen is meant to behave like the registration one -
*   owner details only when a PRO or Manager appeals on the owner's
*   behalf - author these four HIDDEN and add two SHOW rules on
*   PARTNER_OWNER_1 = PARTNER_PRO_1 / PARTNER_MANAGER_1.
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

*   REQUIRED follows the legacy MAND flag, field by field. Four company
*   rows carry it here (both company names, the emirate and the e-mail);
*   the address, trade licence and the two phone numbers do not. That is
*   a different set from BOTH siblings - E014 marks six, E142 marks none
*   - so it is carried per-screen rather than harmonised across the
*   family.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'COMPANY_NAME_EN_1' ftype = 'INPUT' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Company Name English' zlabel_ar = 'اسم الشركة بالانجليزية'
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_EN' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'COMPANY_NAME_AR_1' ftype = 'INPUT' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Company Name Arabic' zlabel_ar = 'اسم الشركة عربي'
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_AR' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'REGISTERED_EMIRATES_1' ftype = 'SELECT' required = 'X'
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
      field_name = 'EMAIL_ID_1' ftype = 'EMAIL' required = 'X'
      zsection = 'Company Contact Verification'
      zlabel = 'E-mail ID' zlabel_ar = 'البريد الالكتروني'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-COMPANY-EMAIL_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 190
      field_name = 'TELEPHONE_NO_1' ftype = 'PHONE'
      zsection = 'Company Contact Verification'
      zlabel = 'Mobile Number 2' zlabel_ar = 'رقم الجوال 2'
      tech_name = 'GS_DATA-COMPANY-TELEPHONE_NO' )

*   The reason for the appeal, and the one field that makes this journey
*   different from its two siblings. MAX_LEN = 250 is the legacy control's
*   own DATA1 value, not a framework default - the legacy TEXTAREA
*   declares 250 and the backend field is sized for it, so a longer text
*   would be silently truncated on post rather than refused here.
*
*   The legacy screen puts the "Enter the Appeal reason" label above the
*   box and carries MAND on that label rather than on the TEXTAREA. The
*   caption becomes ZLABEL and the MAND becomes REQUIRED here, which is
*   the same label-pairing rule the rest of this family follows.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 200
      field_name = 'APPEAL_REASON_1' ftype = 'TEXTAREA' required = 'X'
      zsection = 'Appeal Details'
      zlabel = 'Enter the Appeal reason' zlabel_ar = 'أدخل سبب الاستئناف'
      max_len = 250
      msg = 'The appeal reason is required (250 characters maximum)'
      tech_name = 'GS_DATA-APPEAL_REASON' ) ) ).

* --------------------------------------------------- STP3 fields
* Six legacy sections, each a combobox plus its supporting document -
* the same eligibility screen the registration and renewal flows carry,
* with one difference noted below.
*
* The uploaders are renamed from RAKUPLOADER_n to what they actually
* carry: the legacy names repeat across screens within one journey
* (RAKUPLOADER_1 is the Emirates ID here) and a CJS model member is
* journey-wide, so keeping the legacy names would have unrelated uploads
* sharing one member and one attachment list.
*
* TECH_NAME on an upload is the legacy document code (DATA2), which is
* what the attachment pipeline files against - not the control name.
*
* ATTACH_MAXMB is omitted throughout: unlike E014's document screen,
* NE014_3_3 carries no file-size notice, so the framework default applies
* rather than a number invented here.
*
* Unlike E014's equivalent screen, this one has NO "*Add all Document in
* single file and attach" notices - the four LABEL rows that carry them
* on NE014_1_2 are absent from NE014_3_3 (confirmed by field-set diff,
* not by omission). So no DISPLAY note fields are authored.
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
*   both carry legacy document code 'FG'. All three sub-flows of this
*   screen family have the same collision, which makes it inherited from
*   the shared template rather than a typo in one export. Two different
*   documents filed under one code is either a deliberate shared bucket
*   or a legacy data-entry error; if it is the latter, the second upload
*   overwrites the first and the reviewer sees only one certificate.
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
*   "Branches" and "Speciality" are legacy LABEL rows that head a
*   checkbox group rather than label a single control, so they are
*   carried as DISPLAY text inside their section instead of becoming a
*   ZSECTION of their own - splitting Management and Studies in two would
*   lose the grouping the legacy screen actually draws.
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
      zlabel = 'Governmant Project' zlabel_ar = 'مشروع حكومي'
      tech_name = 'GS_DATA-CONSULTANT-SPEC_GOVER' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 220
      field_name = 'SPEC_MAJOR_1' ftype = 'CHECKBOX' zsection = 'Studies'
      zlabel = 'Major Development Project' zlabel_ar = 'مشروع تطوير كبير'
      tech_name = 'GS_DATA-CONSULTANT-SPEC_MAJOR' ) ) ).

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

* ------------------------------------------------------- grid columns
* The five LEVEL_CON=T columns under the legacy APPEALS table, in LSEQ
* order, with their own resolved captions.
*
* Legacy CTRL is LABEL on all five - the legacy grid was display-only -
* but CTRL here takes a control type, not a rendering hint, so the two
* validity dates are declared DATE and the three identifiers INPUT so the
* grid formats them the way the citizen expects. READONLY on every column
* keeps the display-only behaviour regardless: the CTRL value decides
* formatting, not editability.
*
* COL_NAME is the legacy column name, which is what the backend table
* actually returns - APPLICATION_NAME is kept even though its caption is
* "Registration number", because renaming it here would simply blank the
* column.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'APPEALS'
      col_name = 'APPLICATION' seqnr = 10 ctrl = 'INPUT' readonly = 'X'
      width = '20%' align = 'Begin'
      zlabel = 'Application' zlabel_ar = 'الطلب' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'APPEALS'
      col_name = 'APPLICATION_NAME' seqnr = 20 ctrl = 'INPUT' readonly = 'X'
      width = '20%' align = 'Begin'
      zlabel = 'Registration number' zlabel_ar = 'رقم التسجيل' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'APPEALS'
      col_name = 'RECNTXT_1' seqnr = 30 ctrl = 'INPUT' readonly = 'X'
      width = '30%' align = 'Begin'
      zlabel = 'Company name' zlabel_ar = 'اسم الشركة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'APPEALS'
      col_name = 'PERMIT_ISSUE_DATE_1' seqnr = 40 ctrl = 'DATE' readonly = 'X'
      width = '15%' align = 'Center'
      zlabel = 'Issued at' zlabel_ar = 'تاريخ الإصدار' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'APPEALS'
      col_name = 'PERMIT_EXPIRY_DATE_1' seqnr = 50 ctrl = 'DATE' readonly = 'X'
      width = '15%' align = 'Center'
      zlabel = 'Expired at' zlabel_ar = 'انتهت صلاحيتها في' ) ) ).

* ---------------------------------------------------------------- rules
* NONE on STP2, and deliberately so - see REVIEW-CONTAINER above. The
* only UI_FIELD_LOGICS rows in the whole NE014_3_* family sit on the
* payment screen (the RB1..RB4 method radios and ACCEPT_TERMS's 'PAY-E'),
* and those are the payment card the handler draws, not configurable
* fields. The DELETE at the top still covers ZRAK_T_JNY_RULE so a rule
* added by hand is cleared on the next run.

* -------------------------------------------------------------- options
* The segmented group's three members. OPT_KEY is the legacy field name
* of each button, which is what the handler's role fan-out writes back to
* GS_DATA-PARTNER_OWNER / _PRO / _MANAGER.
*
* OPT_TEXT for the third is title-cased from the legacy 'MANAGER' so it
* reads beside "Owner" and "PRO"; the legacy caption is upper-case
* because the legacy button styled it that way, not because the word is
* an acronym. PRO is left upper-case because it is one.
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
  WRITE: / 'Seeded journey', c_jny, '- Consultant Appeal'.
  WRITE: / '  4 steps (legacy NE014_3_1..3_4; _3_5 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Select Case           1 field  (appeals grid, 5 columns, read-only)'.
  WRITE: / '  STP2 Applicant & Appeal   20 fields, 5 sections'.
  WRITE: / '  STP3 Eligibility          22 fields, 6 sections, 7 uploads'.
  WRITE: / '  STP4 Payment               3 fields (PAYFEE card + terms + donation)'.
  WRITE: / '  0 rules, 3 segmented options, 5 grid columns'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-TECH  BKND_JOURNEY is E014, the legacy code this appeal flow'.
  WRITE: / '              shares with registration and renewal. The legacy'.
  WRITE: / '              JOURNEYTYPE row does say E146, so confirm whether'.
  WRITE: / '              ZCL_EGA_CJ_CONSULTANT_ABS branches on the journey code or'.
  WRITE: / '              on JOURNEYTYPE.'.
  WRITE: / ' REVIEW-BE    PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR are not in the UI'.
  WRITE: / '              export - set them in ZCL_E146_CONSULT_APPEAL_LOGIC->ON_INIT'.
  WRITE: / '              once EPDA Finance confirms. An APPEAL fee is very likely a'.
  WRITE: / '              DIFFERENT material from the registration fee it shares a'.
  WRITE: / '              screen family with. Pay stays inert until then.'.
  WRITE: / ' REVIEW-TEXT  APP_NAME is captioned "Permit number" on this screen but'.
  WRITE: / '              bound to GS_DATA-PARTNER_NAME. Legacy caption carried'.
  WRITE: / '              as-is; confirm which end is wrong.'.
  WRITE: / ' REVIEW-TEXT  REF_NAME_1 has no caption anywhere in the export and'.
  WRITE: / '              renders label-less until one is supplied.'.
  WRITE: / ' REVIEW-CONTAINER  the legacy OWNER_FINDER panel (owner name / ID /'.
  WRITE: / '              mobile / email on STP2) is authored always-visible: this'.
  WRITE: / '              screen has NO UI_FIELD_LOGICS rows, so E014''s'.
  WRITE: / '              show-on-PRO/Manager behaviour was not invented here.'.
  WRITE: / ' REVIEW-BE    document code FG is used by BOTH the Manager attested'.
  WRITE: / '              certificate and the ISO certificate copy on STP3.'.
  WRITE: / ' REVIEW-FE    MAND on the "Branches" / "Speciality" heading labels is not'.
  WRITE: / '              carried; a "tick at least one" group check needs a handler.'.
  WRITE: / ' REVIEW-F4    every SELECT resolves through SHLP; run ZRAK_CJS_XCHECK to'.
  WRITE: / '              confirm each search help returns options in this client.'.
