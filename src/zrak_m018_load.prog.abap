*&---------------------------------------------------------------------*
*& Report ZRAK_M018_LOAD
*&---------------------------------------------------------------------*
*& M018 Grant Request - feeder. Five steps, the longest in the family.
*&
*& SCREENS, FROM ZEGA_T_CJ_UI_MAP for M018:
*&
*&     NOG_1_1   ATTACHMENT   rwmode 1     the identification document
*&     NOG_1_4   ATTACHMENT   rwmode 1     the documents page
*&     NOG_1_5   INITIAL      rwmode 1     the fee read
*&     NOG_1_5   FEES_1       rwmode 2     the post that creates the case
*&     NOG_1_6   CPG_1        rwmode 1     the gateway
*&
*& TWO ATTACHMENT SCREENS and both matter: a screen with no ATTACHMENT
*& row never calls GET_ATTACHMENT( ), so files staged on it come back
*& from nowhere on a resumed draft.
*&
*& THE GRANTS ABSTRACT, NOT THE MML ONE. This posts through
*& ZCL_EGA_CJ_FW_RO_GRANT_ABS_V1: case type ZGCR, owner role ZTR080, and
*& the party list in note CJ03 rather than the CJ02 parcel note. The
*& handler therefore inherits ZCL_RAK_GRANT_LOGIC.
*&
*& AND M018 IS THE ONE JOURNEY WHOSE FILES ARE NOT COPIED TO THE CASE.
*& CREATE_DUMMY_CASE( ) guards `IF mv_journeytype <> 'M018'` around the
*& for_case attachment read, so seven documents including a family book
*& stay against the draft instead of being duplicated into the container
*& case as base64. Deliberate on the backend side; nothing to fix here.
*&
*& WHAT IS NOT VERIFIED. No /QNV/SB_UI_DEFIN export for NOG_1_* has been
*& read, so EVERY field name below except the payment carriers is a
*& reading of the spec screenshots against the family's naming. They are
*& marked REVIEW-BE at each block. A wrong name still renders and still
*& posts under its TECH_NAME; what it loses is the backend's
*& FIELD_CONTROL( ), silently - which on this journey is what hides the
*& loan fields under "Without Loan" and the shared block under
*& "Individual".
*&---------------------------------------------------------------------*
REPORT zrak_m018_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M018'.

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
    lv_title_en = 'Grant Request'.
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
    subtitle       = 'Apply for a housing grant and track the request.'
    subtitle_ar    = 'تقدم بطلب منحة سكنية وتابع الطلب.'
    active         = 'X'
    handler_class  = 'ZCL_M018_OG_LOGIC'
    bknd_active    = 'X'
    bknd_category  = 'MML'
    bknd_journey   = c_jny
    bknd_fm_post   = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read   = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Grant Information' title_ar = 'معلومات المنحة'
      icon = 'sap-icon://request' bknd_screen = 'NOG_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Family Details' title_ar = 'بيانات الأسرة'
      icon = 'sap-icon://family-care' bknd_screen = 'NOG_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Program Details' title_ar = 'بيانات البرنامج'
      icon = 'sap-icon://detail-view' bknd_screen = 'NOG_1_3' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NOG_1_4' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 50
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NOG_1_5'
      active = 'X' ) ) ).

* -------------------------------------------- STP1 Grant Information
* REVIEW-BE: every FIELD_NAME on this step is a guess.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   RADIO, not SELECT. The spec draws two boxed options side by side,
*   which is a radio group; a dropdown would be a different control and
*   the legacy screen's own is what field control keys on.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'GRANT_TYPE' ftype = 'RADIO' required = 'X'
      zsection = 'Grant Type' zsection_ar = 'نوع المنحة'
      zlabel = 'Select a Grant Type' zlabel_ar = 'اختر نوع المنحة'
      msg = 'Choose a grant type' msg_ar = 'يرجى اختيار نوع المنحة' )

*   SEGMENTED, because the spec draws Individual / Shared as one joined
*   two-button control rather than two boxes. It is the same shape the
*   loan toggle uses on step 3.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'GRANT_BENEFICIARY' ftype = 'SEGMENTED' required = 'X'
      zlabel = 'Choose Grant beneficiary' zlabel_ar = 'اختر المستفيد من المنحة'
      msg = 'Choose whether the grant is individual or shared'
      msg_ar = 'يرجى اختيار ما إذا كانت المنحة فردية أو مشتركة' )

*   ONLY UNDER "SHARED", and the rule below hides it otherwise. NUMBER,
*   so the handler's count comparison has something it can convert -
*   see the CONV i( ) guard in ZCL_M018_OG_LOGIC.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'SHARED_GRANTEES' ftype = 'NUMBER'
      min_val = '2' max_val = '10'
      zlabel = 'Please enter number of shared Grantees'
      zlabel_ar = 'يرجى إدخال عدد المستفيدين المشتركين'
      msg = 'REQUIRED:State the number of shared grantees;RANGE:A shared grant needs between 2 and 10 grantees'
      msg_ar = 'REQUIRED:يرجى تحديد عدد المستفيدين المشتركين;RANGE:المنحة المشتركة تتطلب من 2 إلى 10 مستفيدين' )

*   THE PARTNER LIST. An EDITABLE_TABLE, so GET_GRID_DATA( ) reaches the
*   rows - the handler counts them against SHARED_GRANTEES. Per-column
*   READONLY rather than field-level READONLY: the field flag takes the
*   rows away from the search that fills them as well as from the
*   citizen.
*
*   NO TECH_NAME. The party list reaches the backend as note CJ03, which
*   the BAdI's UPDATE( ) writes from the items - not as table data. A
*   TECH_NAME here would post a second, competing list.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 40
      field_name = 'RAKBPLIST' ftype = 'EDITABLE_TABLE'
      zsection = 'Business Partner list' zsection_ar = 'قائمة الشركاء'
      zlabel = 'Business Partner list' zlabel_ar = 'قائمة الشركاء'
      default_val = 'BPNO:BP number:TEXT'      &&
                    '|BPNAME:Name:TEXT'        &&
                    '|NATIONALITY:Nationality:TEXT' &&
                    '|PHONE:Phone Number:TEXT' )

*   THE SEARCH ITSELF IS A CONTROL, NOT FIVE FIELDS. CJS draws the
*   partner search as a popup - ZCL_RAK_BP_POPUP, reached by an ftype
*   'SEARCH' field - and that popup already carries Search By, Emirates
*   ID, Date of Birth, Nationality and the results list. Seeding those as
*   individual fields would draw the search twice and leave the second
*   copy wired to nothing.
*
*   AND THE DOB GUARD IS ALREADY THERE: ZCL_RAK_BP_SEARCH=>SEARCH( )
*   normalises IS_REQ-DOB through NORM_DOB( ) and refuses a filled value
*   that will not parse, because a DatePicker writes unparseable typed
*   characters straight through the binding and BP_QUERY raises an
*   uncatchable CX_SY_CONVERSION_NO_DATE on them.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 50
      field_name = 'BPSEARCH' ftype = 'SEARCH'
      zlabel = 'Find Business Partner' zlabel_ar = 'البحث عن شريك تجاري'
      attach_label = 'Identification Document'
      has_attach = 'X' attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' ) ) ).

  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'RAKBPLIST'
      col_name = 'BPNO'        seqnr = 1 zlabel = 'BP number' zlabel_ar = 'رقم الشريك'
      ctrl = 'INPUT' readonly = 'X' width = '9rem' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'RAKBPLIST'
      col_name = 'BPNAME'      seqnr = 2 zlabel = 'Name' zlabel_ar = 'الاسم'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'RAKBPLIST'
      col_name = 'NATIONALITY' seqnr = 3 zlabel = 'Nationality' zlabel_ar = 'الجنسية'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'RAKBPLIST'
      col_name = 'PHONE'       seqnr = 4 zlabel = 'Phone Number' zlabel_ar = 'رقم الهاتف'
      ctrl = 'INPUT' readonly = 'X' ) ) ).

* ------------------------------------------------ STP2 Family Details
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   THE BP DETAILS TABLE IS THE BACKEND'S BPDTL, filled by
*   GET_PARTNERS( ) - five columns: partner, name, telephone, nationality,
*   email. The spec shows three of them; all five are seeded because the
*   backend fills five and a column short of the spec renders the
*   NEIGHBOURING value, cells being positional at both ends.
*
*   REVIEW-BE: the map puts BPDTL on NOG_2_1, the LATER stage, not on any
*   stage-1 screen. So this table may come back empty here - the read
*   only calls GET_PARTNERS( ) where a BPDTL row exists for the screen.
*   Seeded anyway because the spec draws it on this step; if it stays
*   empty, the row belongs in ZEGA_T_CJ_UI_MAP for NOG_1_2 and that is
*   legacy config, not CJS.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'RAKBPDTL' ftype = 'EDITABLE_TABLE'
      zsection = 'Business Partner Details' zsection_ar = 'بيانات الشريك'
      zlabel = 'Business Partner Details' zlabel_ar = 'بيانات الشريك'
      default_val = 'BPNO:BP number:TEXT'      &&
                    '|BPNAME:Name:TEXT'        &&
                    '|PHONE:Phone Number:TEXT' &&
                    '|NATIONALITY:Nationality:TEXT' &&
                    '|EMAIL:Email:TEXT' )

*   FIVE OPTIONS, 0..4, drawn as a radio group. The children dropdowns
*   below are shown one per wife declared, by rule.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'NO_OF_WIVES' ftype = 'RADIO' required = 'X'
      zsection = 'Family Details' zsection_ar = 'بيانات الأسرة'
      zlabel = 'Number of Wives' zlabel_ar = 'عدد الزوجات'
      msg = 'Please state the number of wives'
      msg_ar = 'يرجى تحديد عدد الزوجات' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 25
      field_name = 'CHILD_HEAD' ftype = 'DISPLAY' readonly = 'X'
      zsection = 'Enter the Number of Children for each wife'
      zsection_ar = 'أدخل عدد الأطفال لكل زوجة'
      zlabel = '' zlabel_ar = '' )

*   ONE PER WIFE, each hidden until the radio says there is one. The
*   MSG carries a per-check wording because these are both REQUIRED and
*   range-limited - see MSG_FOR( ) and the REQUIRED:/RANGE: keys.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'CHILDREN_W1' ftype = 'SELECT' closed_list = 'X'
      zlabel = 'First Wife' zlabel_ar = 'الزوجة الأولى'
      msg = 'REQUIRED:State the number of children for the first wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الأولى' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'CHILDREN_W2' ftype = 'SELECT' closed_list = 'X'
      zlabel = 'Second Wife' zlabel_ar = 'الزوجة الثانية'
      msg = 'REQUIRED:State the number of children for the second wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الثانية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'CHILDREN_W3' ftype = 'SELECT' closed_list = 'X'
      zlabel = 'Third Wife' zlabel_ar = 'الزوجة الثالثة'
      msg = 'REQUIRED:State the number of children for the third wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الثالثة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'CHILDREN_W4' ftype = 'SELECT' closed_list = 'X'
      zlabel = 'Fourth Wife' zlabel_ar = 'الزوجة الرابعة'
      msg = 'REQUIRED:State the number of children for the fourth wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الرابعة' ) ) ).

  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKBPDTL'
      col_name = 'BPNO'        seqnr = 1 zlabel = 'BP number' zlabel_ar = 'رقم الشريك'
      ctrl = 'INPUT' readonly = 'X' width = '9rem' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKBPDTL'
      col_name = 'BPNAME'      seqnr = 2 zlabel = 'Name' zlabel_ar = 'الاسم'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKBPDTL'
      col_name = 'PHONE'       seqnr = 3 zlabel = 'Phone Number' zlabel_ar = 'رقم الهاتف'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKBPDTL'
      col_name = 'NATIONALITY' seqnr = 4 zlabel = 'Nationality' zlabel_ar = 'الجنسية'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKBPDTL'
      col_name = 'EMAIL'       seqnr = 5 zlabel = 'Email' zlabel_ar = 'البريد الإلكتروني'
      ctrl = 'INPUT' readonly = 'X' ) ) ).

* ----------------------------------------------- STP3 Program Details
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'HOUSING_REF_NO' ftype = 'INPUT' required = 'X'
      max_len = '20'
      zsection = 'Program Details' zsection_ar = 'بيانات البرنامج'
      zlabel = 'Housing Reference Number' zlabel_ar = 'رقم المرجع السكني'
      msg = 'Enter the housing reference number'
      msg_ar = 'يرجى إدخال رقم المرجع السكني' )

*   THE TOGGLE THAT GOVERNS THE THREE FIELDS BELOW. The handler's
*   LOAN_INCOMPLETE( ) only has an opinion when this says With Loan, so
*   a Without Loan application is never blocked by fields the backend has
*   hidden.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'LOAN_STATUS' ftype = 'SEGMENTED' required = 'X'
      zlabel = 'Loan Status' zlabel_ar = 'حالة القرض'
      msg = 'Choose whether the grant carries a loan'
      msg_ar = 'يرجى اختيار ما إذا كانت المنحة بقرض' )

*   FGROUP 'ROW:LOAN' puts From and To side by side, which is how the
*   spec draws them.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'LOAN_FROM_DATE' ftype = 'DATE' fgroup = 'ROW:LOAN'
      zlabel = 'From Date' zlabel_ar = 'من تاريخ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'LOAN_TO_DATE' ftype = 'DATE' fgroup = 'ROW:LOAN'
      zlabel = 'To Date' zlabel_ar = 'إلى تاريخ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'LOAN_VALUE' ftype = 'CURRENCY'
      zlabel = 'Loan Value' zlabel_ar = 'قيمة القرض' ) ) ).

* ---------------------------------------------------- STP4 Documents
* SEVEN UPLOADS, in the spec's order. Five required, two optional.
* REQUIRED on an uploader is enforced against the STAGED LIST by field
* name and falls back to the GET_ATTACHMENTS( ) hook - do not write a
* handler check for any of these.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'UPLOADER' ftype = 'UPLOAD' required = 'X'
      zsection = 'Documents' zsection_ar = 'المستندات'
      zlabel = 'Emirates ID / Passport' zlabel_ar = 'الهوية الإماراتية / جواز السفر'
      attach_label = 'Emirates ID / Passport'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 20
      field_name = 'UPLOADER2' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Family Book' zlabel_ar = 'خلاصة القيد'
      attach_label = 'Family Book'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 30
      field_name = 'UPLOADER3' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Sheikh Zayed Program Pledge Approval'
      zlabel_ar = 'موافقة تعهد برنامج الشيخ زايد'
      attach_label = 'Sheikh Zayed Program Pledge Approval'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      field_name = 'UPLOADER4' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Financial Ability' zlabel_ar = 'القدرة المالية'
      attach_label = 'Financial Ability'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 50
      field_name = 'UPLOADER5' ftype = 'UPLOAD' required = 'X'
      zlabel = 'To Whom It May Concern from SZHP'
      zlabel_ar = 'إلى من يهمه الأمر من برنامج الشيخ زايد للإسكان'
      attach_label = 'To Whom It May Concern from SZHP'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 60
      field_name = 'UPLOADER6' ftype = 'UPLOAD'
      zlabel = 'Others' zlabel_ar = 'أخرى'
      attach_label = 'Others'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 70
      field_name = 'UPLOADER7' ftype = 'UPLOAD'
      zlabel = 'Owner Continuity Of Marriage (Optional)'
      zlabel_ar = 'استمرارية الزواج للمالك (اختياري)'
      attach_label = 'Owner Continuity Of Marriage'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' ) ) ).

* ------------------------------------------------ STP5 Fees & Payment
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )

*   PAY_SCREEN ONLY. The gateway is NOG_1_6, one screen past the fee
*   read, because that is where ZEGA_T_CJ_UI_MAP puts CPG_1. Never
*   PAY_JOURNEY - it becomes CS_HEADER-PARAM2 and changes the BAdI
*   filter - and never PAY_CATEGORY, which blank means "the journey's
*   own", MML, and that is what finds the CPG row.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 15
      field_name = 'PAY_SCREEN' ftype = 'DISPLAY'
      readonly = 'X' hidden = 'X'
      default_val = 'NOG_1_6'
      zlabel = 'Payment screen' zlabel_ar = 'شاشة الدفع' )

*   TOTALFEESVALUE OR NO CASE. UPDATE( ) reaches CREATE_DUMMY_CASE( )
*   only on finding it in the items with a FEES_1 row for the screen.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 20
      field_name = 'TOTALVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 30
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel = 'I would like to donate five dirhams to Ajer Charity Foundation.'
      zlabel_ar = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.'
      tech_name = 'DONATE' ) ) ).

* ---------------------------------------------------------------- rules
* THE THREE CONDITIONAL BLOCKS. Show/hide belongs in config, not in the
* handler - that is the "config before code" rule, and a rule-hidden
* field is also excluded from the required check, which is what stops a
* hidden loan field blocking a Without Loan submit.
*
* REVIEW-BE: the SRC_VALUE keys are guesses, exactly as the option keys
* are. SHARED and WITH are the words on screen; the legacy control's
* stored keys could be anything. Read the export and correct these two
* values - the handler compares with CS on the same words, so the two
* have to be corrected together.
* THE TABLE HAS NO STEP_ID, NO SEQNR AND NO ACTIVE. Its columns are
* MANDT, JOURNEY_ID, RULE_ID, SRC_FIELD, SRC_OP, SRC_VALUE, TGT_FIELD,
* TGT_VALUE and TOTABLE - a rule is journey-wide and keyed on the source
* FIELD, not on a step. Writing STEP_ID or SEQNR here does not compile,
* and RULE_ID is CHAR3, so R01..R09 are safe where GS01..GS15 would
* truncate to GS0/GS1 and dump on a duplicate key.
*
* SRC_OP IS EXPLICIT. Every working rule in the repository sets it - the
* E014/E015/E027 feeders all write src_op = 'EQ' - and leaving it blank
* is a comparison with no operator.
*
* NO_OF_WIVES USES GE, NOT EQ. Three wives means the second and third
* dropdowns are both wanted, so each rule shows its field from its own
* count upwards; with EQ, declaring 3 would show only the third and
* silently hide the first two the citizen had already answered.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R01'
      src_field = 'GRANT_BENEFICIARY' src_op = 'EQ' src_value = 'SHARED'
      action = 'SHOW' tgt_field = 'SHARED_GRANTEES' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R02'
      src_field = 'GRANT_BENEFICIARY' src_op = 'EQ' src_value = 'SHARED'
      action = 'SHOW' tgt_field = 'RAKBPLIST' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R03'
      src_field = 'GRANT_BENEFICIARY' src_op = 'EQ' src_value = 'SHARED'
      action = 'SHOW' tgt_field = 'BPSEARCH' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R04'
      src_field = 'LOAN_STATUS' src_op = 'EQ' src_value = 'WITH'
      action = 'SHOW' tgt_field = 'LOAN_FROM_DATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R05'
      src_field = 'LOAN_STATUS' src_op = 'EQ' src_value = 'WITH'
      action = 'SHOW' tgt_field = 'LOAN_TO_DATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R06'
      src_field = 'LOAN_STATUS' src_op = 'EQ' src_value = 'WITH'
      action = 'SHOW' tgt_field = 'LOAN_VALUE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R07'
      src_field = 'NO_OF_WIVES' src_op = 'GE' src_value = '2'
      action = 'SHOW' tgt_field = 'CHILDREN_W2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R08'
      src_field = 'NO_OF_WIVES' src_op = 'GE' src_value = '3'
      action = 'SHOW' tgt_field = 'CHILDREN_W3' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R09'
      src_field = 'NO_OF_WIVES' src_op = 'GE' src_value = '4'
      action = 'SHOW' tgt_field = 'CHILDREN_W4' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* --------------------------------------------------------------- report
  WRITE: / 'M018 Grant Request - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT for SPRAS A.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'Steps    : STP1 Grant Information  NOG_1_1'.
  WRITE: / '           STP2 Family Details     NOG_1_2'.
  WRITE: / '           STP3 Program Details    NOG_1_3'.
  WRITE: / '           STP4 Documents          NOG_1_4  7 uploads'.
  WRITE: / '           STP5 Fees & Payment     NOG_1_5'.
  WRITE: / '           (NOG_1_6 is the CPG screen - PAY_SCREEN)'.
  WRITE: / ''.
  WRITE: / 'Handler  : ZCL_M018_OG_LOGIC (inherits ZCL_RAK_GRANT_LOGIC)'.
  WRITE: / 'Backend  : GRANTS / ZGCR / owner role ZTR080 / RO_GRANT_ABS_V1'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO - config and config only:'.
  WRITE: / '  1. NO OPTION LISTS are seeded. GRANT_TYPE, GRANT_BENEFICIARY,'.
  WRITE: / '     LOAN_STATUS, NO_OF_WIVES and the four CHILDREN_W* need'.
  WRITE: / '     either ZRAK_T_JNY_OPT rows or a ROLLNAME / DOMNAME / SHLP.'.
  WRITE: / '     Left empty on purpose: a hand-typed key that differs from'.
  WRITE: / '     the legacy one posts a value the case cannot accept.'.
  WRITE: / '  2. The rule SRC_VALUEs SHARED and WITH are guesses and must'.
  WRITE: / '     match the real option keys. The handler compares the same'.
  WRITE: / '     words with CS, so correct both together.'.
  WRITE: / '  3. Every FIELD_NAME on STP1..STP4 is a guess. Read the /QNV'.
  WRITE: / '     export for NOG_1_1..NOG_1_4 - field control is keyed on'.
  WRITE: / '     the legacy name and fails silently on a wrong one.'.
  WRITE: / '  4. BPDTL sits on NOG_2_1 in the UI map, not on a stage-1'.
  WRITE: / '     screen, so RAKBPDTL on STP2 may come back empty. If it'.
  WRITE: / '     does, the map needs a row for NOG_1_2.'.
