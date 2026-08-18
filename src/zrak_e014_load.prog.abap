REPORT zrak_e014_load.

*&---------------------------------------------------------------------*
*& E014 - Environmental Consultants Registration  (legacy NE014_1_1..5)
*&
*& Hand-authored from the real /QNV/SB_UI_DEFIN export, with every
*& caption taken from the legacy label / value dictionaries
*& (/QNV/SB_LABELT, /QNV/SB_VALUET) rather than derived from a field
*& name. That is the whole reason this is a feeder and not a run of
*& ZCL_RAK_MIGRATOR: the migrator's own header lists what it cannot
*& derive - "zsection, placeholder, fgroup AS A HEADING, min_len/
*& max_len/min_val/max_val, msg_ar, fstate" - which is exactly the set
*& that decides whether a page reads as a designed form or as a flat
*& list of inputs. It also cannot know that legacy screen _5 is the
*& confirmation page the CJS engine already draws for itself.
*&
*& STRUCTURE - 4 steps, not the 5 legacy screens:
*&   STP1  NE014_1_1  Applicant & Company details
*&   STP2  NE014_1_2  Eligibility
*&   STP3  NE014_1_3  Documents & Declaration
*&   STP4  NE014_1_4  Payment
*&   (NE014_1_5 is "Your Request was submitted!" + the happiness meter
*&    - the engine appends its own confirmation and feedback step after
*&    submit, so migrating that screen would show it twice.)
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E014'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E014'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* BKND_* are the real values off the legacy screen: every navigation
* button on NE014_1_* carries DATA1 = ZFM_EGA_CJ_FW_POST_N and
* DATA2 = ZFM_EGA_CJ_FW_READ_N, under CATEGORY 'EPDA'. So this journey
* is wired live rather than shipped inert.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Consultancy Registration'
    title_ar      = 'تسجيل الاستشارات'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_E014_CONSULT_REG_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E014'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Applicant & Company' title_ar = 'مقدم الطلب والشركة'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'NE014_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Eligibility' title_ar = 'الأهلية'
      icon = 'sap-icon://education' bknd_screen = 'NE014_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE014_1_3' active = 'X' )
*   NEXT_REQUIRES = PAYFEE is what stops the footer offering Submit on an
*   unpaid application - the step says so before the citizen presses,
*   instead of the handler refusing afterwards.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Payment' title_ar = 'الدفع'
      icon = 'sap-icon://credit-card' bknd_screen = 'NE014_1_4'
      next_requires = 'PAYFEE' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* ZSECTION carries the legacy section headings (VALUE-resolved:
* "Applicant Details" / "Company Details" / "Company Contact Details").
* The four applicant fields are READONLY because on the legacy screen
* they are LABELs bound to GS_DATA-PARTNER_* - the portal session fills
* them, the citizen never types them.
*
* SHLP with rollname left BLANK on purpose: a rollname sends the engine's
* F4 resolver down the domain / value-table path, and these data elements
* have no value table, which renders an empty dropdown. The search help
* is what actually populates it.
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
*   The three legacy TBUTTONs (PARTNER_OWNER_1 / PARTNER_PRO_1 /
*   PARTNER_MANAGER_1, one DATA1 group) collapse into ONE segmented
*   field, named after the lowest-sequence member so the handler and the
*   rules below agree on the source field name.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 50
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )
*   HIDDEN by default and revealed by R001/R002 below. The legacy
*   UI_FIELD_LOGICS is explicit and counter-intuitive: OWNER_FINDER-V-F
*   on the Owner button, OWNER_FINDER-V-T on PRO and Manager - i.e. the
*   owner lookup appears only when somebody applies ON BEHALF of the
*   owner, never when the owner applies personally.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 60
      field_name = 'OWNER_FINDER_BP' ftype = 'SEARCH' hidden = 'X' required = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Owner' zlabel_ar = 'المالك'
      tech_name = 'GS_DATA-OWNER' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 70
      field_name = 'COMPANY_NAME_EN_1' ftype = 'INPUT' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Company Name English' zlabel_ar = 'اسم الشركة بالانجليزية'
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_EN' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 80
      field_name = 'COMPANY_NAME_AR_1' ftype = 'INPUT' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Company Name Arabic' zlabel_ar = 'اسم الشركة عربي'
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_AR' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 90
      field_name = 'REGISTERED_EMIRATES_1' ftype = 'SELECT' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Company Registration Emirates' zlabel_ar = 'تسجيل الشركة الإمارات'
      placeholder = 'Select' shlp = 'ZSH_CJ_UAE_REGION'
      tech_name = 'GS_DATA-COMPANY-REGISTERED_EMIRATES' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 100
      field_name = 'ADDRESS_1' ftype = 'TEXTAREA' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Company Address' zlabel_ar = 'عنوان الشركة'
      tech_name = 'GS_DATA-COMPANY-ADDRESS' )
*   REVIEW-BE: the legacy screen also carries TRADE_LICENSE_2, a
*   SEARCH_FIELD on the SAME technical name as this input. Only the
*   input is migrated - two controls bound to one backend field would
*   post the value twice and the second write would win silently. If the
*   trade-license lookup is actually wanted, it belongs here as ftype
*   SEARCH with on_search wired, not as a second field.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 110
      field_name = 'TRADE_LICENSE_1' ftype = 'INPUT' required = 'X'
      zsection = 'Company Details'
      zlabel = 'Trade License' zlabel_ar = 'رخصة تجارية'
      tech_name = 'GS_DATA-COMPANY-TRADE_LICENSE' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 120
      field_name = 'MOBILE_NO_1' ftype = 'PHONE'
      zsection = 'Company Contact Details'
      zlabel = 'Mobile Number 1' zlabel_ar = 'رقم الجوال 1'
      tech_name = 'GS_DATA-COMPANY-MOBILE_NO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 130
      field_name = 'TELEPHONE_NO_1' ftype = 'PHONE'
      zsection = 'Company Contact Details'
      zlabel = 'Mobile Number 2' zlabel_ar = 'رقم الجوال 2'
      tech_name = 'GS_DATA-COMPANY-TELEPHONE_NO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 140
      field_name = 'EMAIL_ID_1' ftype = 'EMAIL' required = 'X'
      zsection = 'Company Contact Details'
      zlabel = 'E-mail ID' zlabel_ar = 'البريد الالكتروني'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-COMPANY-EMAIL_ID' ) ) ).

* --------------------------------------------------- STP2 fields
* Six legacy sections, each a combobox + its supporting document. The
* uploaders are renamed from RAKUPLOADER_n to what they actually carry:
* the legacy names repeat across screens (RAKUPLOADER_1 is the Emirates
* ID here and the Company Profile on STP3), and a model member is
* journey-wide, so keeping the legacy names would have both uploads
* sharing one member and one attachment list.
*
* TECH_NAME on an upload is the legacy document code (DATA2), which is
* what the attachment pipeline files against.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'OWNER_TYPE_1' ftype = 'SELECT' required = 'X'
      zsection = 'Nationality'
      zlabel = 'Owner Nationality' zlabel_ar = 'جنسية المالك'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_OWNER'
      tech_name = 'GS_DATA-CONSULTANT-OWNER_TYPE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'EID_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Nationality'
      zlabel = 'Emirates ID' zlabel_ar = 'رقم الهوية الإماراتية'
      has_attach = 'X' attach_label = 'Upload Emirates ID'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'N7' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'EID_NOTE' ftype = 'DISPLAY' zsection = 'Nationality'
      default_val = '*Add all Document in single file and attach' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'MANAGER_EXP_1' ftype = 'SELECT' required = 'X'
      zsection = 'Manager'
      zlabel = 'Experience' zlabel_ar = 'خبرة'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_MNG_EX'
      tech_name = 'GS_DATA-CONSULTANT-MANAGER_EXP' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'MANAGER_CV_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Manager'
      zlabel = 'CV Copy' zlabel_ar = 'نسخة من السيرة الذاتية'
      has_attach = 'X' attach_label = 'Upload CV Copy'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'FF' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'MANAGER_DEG_1' ftype = 'SELECT' required = 'X'
      zsection = 'Manager'
      zlabel = 'Degree' zlabel_ar = 'الدرجة'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_MNG_DEG'
      tech_name = 'GS_DATA-CONSULTANT-MANAGER_DEG' )
*   REVIEW-BE: this document and MANAGEMENT's "Certificate Copy" below
*   both carry legacy document code 'FG'. Two different documents filed
*   under one code is either a legacy data-entry error or a deliberate
*   shared bucket - confirm with EPDA before go-live, because if it is an
*   error the second upload overwrites the first in the backend.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'MANAGER_CERT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Manager'
      zlabel = 'Attested Certificate' zlabel_ar = 'شهادة مصدقة'
      has_attach = 'X' attach_label = 'Upload Attested Certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'FG' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'MANAGER_NOTE' ftype = 'DISPLAY' zsection = 'Manager'
      default_val = '*Add all Document in single file and attach' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'COORDINATOR_1' ftype = 'SELECT' required = 'X'
      zsection = 'Co-ordinator'
      zlabel = 'Education' zlabel_ar = 'التعليم'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_COORDINA'
      tech_name = 'GS_DATA-CONSULTANT-COORDINATOR' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'COORD_CERT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Co-ordinator'
      zlabel = 'Attested Certificate' zlabel_ar = 'شهادة مصدقة'
      has_attach = 'X' attach_label = 'Upload Attested Certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = '76' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'TEAM_1' ftype = 'SELECT' required = 'X'
      zsection = 'Technical'
      zlabel = 'Team' zlabel_ar = 'الفريق'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_TEAM'
      tech_name = 'GS_DATA-CONSULTANT-TEAM' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'TEAM_EID_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Technical'
      zlabel = 'Emirates ID' zlabel_ar = 'رقم الهوية الإماراتية'
      has_attach = 'X' attach_label = 'Upload Emirates ID'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = '60' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'TEAM_NOTE' ftype = 'DISPLAY' zsection = 'Technical'
      default_val = '*Add all Document in single file and attach' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'CERTIFICATE_1' ftype = 'SELECT' required = 'X'
      zsection = 'Management'
      zlabel = 'ISO Certifications' zlabel_ar = 'شهادات الأيزو'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_CERTI'
      tech_name = 'GS_DATA-CONSULTANT-CERTIFICATE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 150
      field_name = 'ISO_CERT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Management'
      zlabel = 'Certificate Copy' zlabel_ar = 'نسخة الشهادة'
      has_attach = 'X' attach_label = 'Upload Certificate Copy'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'FG' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 160
      field_name = 'BRANCHES_TXT' ftype = 'DISPLAY' zsection = 'Management'
      default_val = 'Branches' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 170
      field_name = 'BRANCH_LOC_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'Local Branch' zlabel_ar = 'الفرع المحلي'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_LOC' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 180
      field_name = 'BRANCH_REG_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'Regional Branch' zlabel_ar = 'الفرع الإقليمي'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_REG' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 190
      field_name = 'BRANCH_INT_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'International Branch' zlabel_ar = 'الفرع الدولي'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_INT' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 200
      field_name = 'BRANCH_LINK_1' ftype = 'CHECKBOX' zsection = 'Management'
      zlabel = 'International Branch Links' zlabel_ar = 'روابط الفروع الدولية'
      tech_name = 'GS_DATA-CONSULTANT-BRANCH_LINK' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 210
      field_name = 'STUDY_PROJ_1' ftype = 'SELECT' required = 'X'
      zsection = 'Studies'
      zlabel = 'General Project' zlabel_ar = 'المشروع العام'
      placeholder = 'Select' shlp = 'ZSH_CJ_CONSULT_PROJ'
      tech_name = 'GS_DATA-CONSULTANT-STUDY_PROJ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 220
      field_name = 'PROJ_LIST_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Studies'
      zlabel = 'List of Project' zlabel_ar = 'قائمة المشروع'
      has_attach = 'X' attach_label = 'Upload List of Project'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'FI' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 230
      field_name = 'STUDY_NOTE' ftype = 'DISPLAY' zsection = 'Studies'
      default_val = '*Add all Document in single file and attach' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 240
      field_name = 'SPECIALITY_TXT' ftype = 'DISPLAY' zsection = 'Studies'
      default_val = 'Speciality' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 250
      field_name = 'SPEC_GOVER_1' ftype = 'CHECKBOX' zsection = 'Studies'
      zlabel = 'Governmant Project' zlabel_ar = 'مشروع الحكومة'
      tech_name = 'GS_DATA-CONSULTANT-SPEC_GOVER' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 260
      field_name = 'SPEC_MAJOR_1' ftype = 'CHECKBOX' zsection = 'Studies'
      zlabel = 'Major Development Project' zlabel_ar = 'مشروع تنموي كبير'
      tech_name = 'GS_DATA-CONSULTANT-SPEC_MAJOR' ) ) ).

* --------------------------------------------------- STP3 fields
* ATTACH_MAXMB = 3 across the journey, from this screen's own notice
* ("Each file maximum allowed size - 3MB") rather than the framework
* default.
*
* REVIEW-TEXT: the declaration and disclaimer paragraphs are carried in
* DEFAULT_VAL (CHAR1000) as DISPLAY text. Their Arabic originals are in
* the legacy dictionary but there is only ONE default_val per field and
* ZLABEL_AR is 80 characters, so the Arabic text of these three long
* paragraphs is NOT carried. Everything shorter is fully bilingual.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = 'Each file maximum allowed size - 3MB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'COMPANY_PROFILE_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Company Profile' zlabel_ar = 'الملف الشخصي للشركة'
      has_attach = 'X' attach_label = 'Upload Company Profile'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'DT' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'TRADE_LIC_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Trade License Document' zlabel_ar = 'وثيقة الرخصة التجارية'
      has_attach = 'X' attach_label = 'Upload Trade License Document'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'DU' )
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
* screen's own radio groups and fee CLIST are that same card, so they are
* deliberately NOT re-created as fields.
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
* Straight from the legacy UI_FIELD_LOGICS on the three applicant-type
* buttons. Two SHOW rules and no HIDE rule: the field is authored
* HIDDEN, so "not shown" is its resting state and there is nothing for a
* HIDE rule to do - which also means a third applicant type added later
* cannot accidentally leave the finder on screen.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R001'
      src_field = 'PARTNER_OWNER_1' src_op = 'EQ' src_value = 'PARTNER_PRO_1'
      action = 'SHOW' tgt_field = 'OWNER_FINDER_BP' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R002'
      src_field = 'PARTNER_OWNER_1' src_op = 'EQ' src_value = 'PARTNER_MANAGER_1'
      action = 'SHOW' tgt_field = 'OWNER_FINDER_BP' ) ) ).

* -------------------------------------------------------------- options
* The segmented group's three members. OPT_KEY is the legacy field name
* of each button, which is what the handler's set_group( ) writes back to
* GS_DATA-PARTNER_OWNER / _PRO / _MANAGER.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_OWNER_1' seqnr = 10
      opt_text = 'Owner' opt_text_ar = 'المالك' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_PRO_1' seqnr = 20
      opt_text = 'PRO' opt_text_ar = 'PRO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_MANAGER_1' seqnr = 30
      opt_text = 'Manager' opt_text_ar = 'المدير' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Consultancy Registration'.
  WRITE: / '  4 steps (legacy NE014_1_1..1_4; _1_5 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Applicant & Company  14 fields, 3 sections'.
  WRITE: / '  STP2 Eligibility          26 fields, 6 sections, 7 uploads'.
  WRITE: / '  STP3 Documents             7 fields, 3 uploads'.
  WRITE: / '  STP4 Payment               3 fields (PAYFEE card + terms + donation)'.
  WRITE: / '  2 rules, 3 segmented options'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-BE  PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR are not in the UI'.
  WRITE: / '            export - set them in ZCL_E014_CONSULT_REG_LOGIC->ON_INIT'.
  WRITE: / '            once EPDA Finance confirms. Pay stays inert until then.'.
  WRITE: / ' REVIEW-BE  document code FG is used by BOTH the Manager attested'.
  WRITE: / '            certificate and the ISO certificate copy.'.
  WRITE: / ' REVIEW-BE  TRADE_LICENSE_2 (a SEARCH_FIELD on the same technical name'.
  WRITE: / '            as TRADE_LICENSE_1) was not migrated - see the note above.'.
  WRITE: / ' REVIEW-F4  every SELECT resolves through SHLP; run ZRAK_CJS_XCHECK to'.
  WRITE: / '            confirm each search help returns options in this client.'.
  WRITE: / ' REVIEW-TEXT the 3 long declaration/disclaimer paragraphs carry English'.
  WRITE: / '            only (one DEFAULT_VAL per field; ZLABEL_AR is 80 chars).'.
