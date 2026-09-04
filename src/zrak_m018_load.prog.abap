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
*& FIELD NAMES ARE FROM THE EXPORT. Every FIELD_NAME below is the
*& legacy name as EXPORT_DEFIN.XLSX gives it for NOG_1_*, not a
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
REPORT zrak_m018_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M018'.

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
    bknd_category  = 'GRANTS'
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
* FIELD NAMES ON THIS STEP ARE THE EXPORT'S, for NOG_1_1: RB3 (with
* RB4/RB5 as its sibling options, so the grant type is a THREE-option
* radio group, not two), RB1/RB2 as one TBUTTON pair, NUMINPUT,
* TABLE_FETCHER (a CLIST), SHAERDID and GRANTTYPECOMBO.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   RADIO, AND THREE OPTIONS NOT TWO. The export gives RB3 with RB4
*   and RB5 as its siblings on NOG_1_1 - a three-button radio group -
*   where the spec page shows two boxes. Only RB3 is seeded, because
*   in CJS one RADIO field carries the whole group and its options are
*   ZRAK_T_JNY_OPT rows; RB4 and RB5 are the legacy control's other
*   buttons, not separate fields. Which means the option list here
*   needs THREE rows, and that is the one thing still unseeded.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'RB3' ftype = 'RADIO' required = 'X'
      tech_name = 'GTYPE_N'
      zsection = 'Grant Type' zsection_ar = 'نوع المنحة'
      zlabel = 'Select a Grant Type' zlabel_ar = 'اختر نوع المنحة'
      msg = 'Choose a grant type' msg_ar = 'يرجى اختيار نوع المنحة' )

*   SEGMENTED, because the spec draws Individual / Shared as one joined
*   two-button control rather than two boxes. It is the same shape the
*   loan toggle uses on step 3.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'RB1' ftype = 'SEGMENTED' required = 'X'
      tech_name = 'I_BENEFICIARY'
      zlabel = 'Choose Grant beneficiary' zlabel_ar = 'اختر المستفيد من المنحة'
      msg = 'Choose whether the grant is individual or shared'
      msg_ar = 'يرجى اختيار ما إذا كانت المنحة فردية أو مشتركة' )

*   ONLY UNDER "SHARED", and the rule below hides it otherwise. NUMBER,
*   so the handler's count comparison has something it can convert -
*   see the CONV i( ) guard in ZCL_M018_OG_LOGIC.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'NUMINPUT' ftype = 'NUMBER'
      tech_name = 'SHARED_NUM'
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
      field_name = 'TABLE_FETCHER' ftype = 'EDITABLE_TABLE'
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
      field_name = 'SHAERDID' ftype = 'SEARCH'
      zlabel = 'Find Business Partner' zlabel_ar = 'البحث عن شريك تجاري'
      attach_label = 'Identification Document'
      has_attach = 'X' attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' ) ) ).

*   THE PROGRAM-TYPE DROPDOWN, from the export (GRANTTYPECOMBO, search
*   help ZSH_CJ_GRANT_PGM_TYPE - the same help M019 reads). A separate
*   INSERT rather than a row spliced into the block above: a line-numbered
*   edit into a VALUE #( ) table has already corrupted a neighbouring row
*   in this family once.
  INSERT zrak_t_jny_fld FROM @( VALUE #(
    mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 60
    field_name = 'GRANTTYPECOMBO' ftype = 'SELECT' closed_list = 'X'
      tech_name = 'GRANT_TYPE'
    shlp = 'ZSH_CJ_GRANT_PGM_TYPE'
    zlabel = 'Grant Program Type' zlabel_ar = 'نوع برنامج المنحة' ) ).

  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'TABLE_FETCHER'
      col_name = 'BPNO'        seqnr = 1 zlabel = 'BP number' zlabel_ar = 'رقم الشريك'
      ctrl = 'INPUT' readonly = 'X' width = '9rem' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'TABLE_FETCHER'
      col_name = 'BPNAME'      seqnr = 2 zlabel = 'Name' zlabel_ar = 'الاسم'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'TABLE_FETCHER'
      col_name = 'NATIONALITY' seqnr = 3 zlabel = 'Nationality' zlabel_ar = 'الجنسية'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'TABLE_FETCHER'
      col_name = 'PHONE'       seqnr = 4 zlabel = 'Phone Number' zlabel_ar = 'رقم الهاتف'
      ctrl = 'INPUT' readonly = 'X' ) ) ).

* ------------------------------------------------ STP2 Family Details
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   THERE IS NO PARTNER TABLE ON THIS STEP, AND RAKBPDTL DOES NOT
*   EXIST. This block used to seed an EDITABLE_TABLE called RAKBPDTL
*   here, reasoning from the spec screenshot. The export has no such
*   field on any NOG screen: NOG_1_2 carries TABLE_FETCHER and
*   SHAERDID - the SAME two controls as NOG_1_1 - so the partner list
*   on this screen is the step-1 list shown again, not a second table.
*
*   It cannot be seeded twice either. BUILD_MODEL( ) skips a name it
*   has already built, so a second TABLE_FETCHER row would share ONE
*   model component with step 1's and the two grids would be the same
*   grid. The list lives on STP1, where the shared-grantee count is
*   checked against it, and that is the only place it belongs.
*
*   STILL UNSEEDED, AND KNOWN TO EXIST: NTNLINPUT (nationality) and
*   CHNUMINPUT (children count) on NOG_1_2, both plain INPUTs. They
*   are part of the add-a-party form behind the search, not the
*   family block below, and the spec pages do not show what labels
*   they carry - so they are named here rather than guessed at.

*   FIVE OPTIONS, 0..4, drawn as a radio group. The children dropdowns
*   below are shown one per wife declared, by rule.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'RB0' ftype = 'RADIO' required = 'X'
      tech_name = 'WIFE0'
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
      field_name = 'CHILD1CB' ftype = 'SELECT' closed_list = 'X'
      tech_name = 'CHILDREN_WIFE1'
      shlp = 'ZSH_CJ_GRANTS_CHILDREN'
      zlabel = 'First Wife' zlabel_ar = 'الزوجة الأولى'
      msg = 'REQUIRED:State the number of children for the first wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الأولى' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'CHILD2CB' ftype = 'SELECT' closed_list = 'X'
      tech_name = 'CHILDREN_WIFE2'
      shlp = 'ZSH_CJ_GRANTS_CHILDREN'
      zlabel = 'Second Wife' zlabel_ar = 'الزوجة الثانية'
      msg = 'REQUIRED:State the number of children for the second wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الثانية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'CHILD3CB' ftype = 'SELECT' closed_list = 'X'
      tech_name = 'CHILDREN_WIFE3'
      shlp = 'ZSH_CJ_GRANTS_CHILDREN'
      zlabel = 'Third Wife' zlabel_ar = 'الزوجة الثالثة'
      msg = 'REQUIRED:State the number of children for the third wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الثالثة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'CHILD4CB' ftype = 'SELECT' closed_list = 'X'
      tech_name = 'CHILDREN_WIFE4'
      shlp = 'ZSH_CJ_GRANTS_CHILDREN'
      zlabel = 'Fourth Wife' zlabel_ar = 'الزوجة الرابعة'
      msg = 'REQUIRED:State the number of children for the fourth wife'
      msg_ar = 'REQUIRED:يرجى تحديد عدد أطفال الزوجة الرابعة' ) ) ).

* ----------------------------------------------- STP3 Program Details
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'HOUSEREFINPUT' ftype = 'INPUT' required = 'X'
      tech_name = 'BUILDING_NUMBER'
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
*   RB1_LOAN, NOT RB1 - AND THAT IS DELIBERATE. The export names this
*   field RB1 on NOG_1_3 and the beneficiary toggle RB1 on NOG_1_1:
*   legacy names are per SCREEN, and CJS BUILD_MODEL( ) is flat per
*   JOURNEY. BUILD_MODEL( ) skips a name it has already built, so the
*   two would have shared ONE model component - picking Shared on
*   step 1 would have set the loan status on step 3, and the rules
*   keyed on either would have fired off the other.
*
*   The value still reaches the backend: ZCL_RAK_QNV_BRIDGE sends
*   FIELDNAME from the CJS name and TECHNICALNAME from TECH_NAME, and
*   the grants abstract maps values by TECHNICALNAME - which is RB1
*   here. What is lost is FIELD_CONTROL on this one field, because
*   CTRL_OF( ) matches on FIELDNAME. That degrades correctly: a miss
*   is now read as NO INSTRUCTION rather than as forced-optional (see
*   the SEED_CTRL note in CLAUDE.md), so the configured flags stand
*   and the rules below do the hiding the backend would have done.
      field_name = 'RB1_LOAN' ftype = 'SEGMENTED' required = 'X'
      tech_name = 'WITH_LOAN'
      zlabel = 'Loan Status' zlabel_ar = 'حالة القرض'
      msg = 'Choose whether the grant carries a loan'
      msg_ar = 'يرجى اختيار ما إذا كانت المنحة بقرض' )

*   FGROUP 'ROW:LOAN' puts From and To side by side, which is how the
*   spec draws them.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'FROMDATE' ftype = 'DATE' fgroup = 'ROW:LOAN'
      tech_name = 'FROM_DATE'
      zlabel = 'From Date' zlabel_ar = 'من تاريخ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'TODATE' ftype = 'DATE' fgroup = 'ROW:LOAN'
      tech_name = 'TO_DATE'
      zlabel = 'To Date' zlabel_ar = 'إلى تاريخ' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'LOANVALUEINPUT' ftype = 'CURRENCY'
      tech_name = 'LOAN_VAL'
      zlabel = 'Loan Value' zlabel_ar = 'قيمة القرض' ) ) ).

* ---------------------------------------------------- STP4 Documents
* SEVEN UPLOADS, in the spec's order. Five required, two optional.
* REQUIRED on an uploader is enforced against the STAGED LIST by field
* name and falls back to the GET_ATTACHMENTS( ) hook - do not write a
* handler check for any of these.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'UPLOADER1' ftype = 'UPLOAD' required = 'X'
      zsection = 'Documents' zsection_ar = 'المستندات'
      zlabel = 'Emirates ID / Passport' zlabel_ar = 'الهوية الإماراتية / جواز السفر'
      attach_label = 'Emirates ID / Passport'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:1' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 20
      field_name = 'UPLOADER2' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Family Book' zlabel_ar = 'خلاصة القيد'
      attach_label = 'Family Book'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:2' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 30
      field_name = 'UPLOADER3' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Sheikh Zayed Program Pledge Approval'
      zlabel_ar = 'موافقة تعهد برنامج الشيخ زايد'
      attach_label = 'Sheikh Zayed Program Pledge Approval'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:3' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      field_name = 'UPLOADER4' ftype = 'UPLOAD' required = 'X'
      zlabel = 'Financial Ability' zlabel_ar = 'القدرة المالية'
      attach_label = 'Financial Ability'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:4' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 50
      field_name = 'UPLOADER5' ftype = 'UPLOAD' required = 'X'
      zlabel = 'To Whom It May Concern from SZHP'
      zlabel_ar = 'إلى من يهمه الأمر من برنامج الشيخ زايد للإسكان'
      attach_label = 'To Whom It May Concern from SZHP'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:5' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 60
      field_name = 'UPLOADER6' ftype = 'UPLOAD'
      zlabel = 'Others' zlabel_ar = 'أخرى'
      attach_label = 'Others'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:6' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 70
      field_name = 'UPLOADER7' ftype = 'UPLOAD'
      zlabel = 'Owner Continuity Of Marriage (Optional)'
      zlabel_ar = 'استمرارية الزواج للمالك (اختياري)'
      attach_label = 'Owner Continuity Of Marriage'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5'
      default_val = 'DTYPE:7' ) ) ).

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
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_4_CHECKBOX_2'
                               iv_fb   = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_4_CHECKBOX_2'
                               iv_fb   = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع' )
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_4_CHECKBOX_3'
                               iv_fb   = 'I would like to donate five dirhams to Ajer Charity Foundation.' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_4_CHECKBOX_3'
                               iv_fb   = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.' )
      tech_name = 'DONATE' ) ) ).

* ---------------------------------------------------------- rules table
* THE TABLE HAS NO STEP_ID, NO SEQNR AND NO ACTIVE. Its columns are
* MANDT, JOURNEY_ID, RULE_ID, SRC_FIELD, SRC_OP, SRC_VALUE, TGT_FIELD,
* TGT_VALUE and TOTABLE - a rule is journey-wide and keyed on the source
* FIELD, not on a step. Writing STEP_ID or SEQNR here does not compile,
* and RULE_ID is CHAR3, so R01..R17 are safe where GS01..GS15 would
* truncate to GS0/GS1 and dump on a duplicate key.
*
* SRC_OP IS EXPLICIT. Every working rule in the repository sets it - the
* E014/E015/E027 feeders all write src_op = 'EQ' - and leaving it blank
* is a comparison with no operator.
*
* Show/hide belongs in config, not in the handler - that is the
* "config before code" rule, and a rule-hidden field is also excluded
* from the required check, which is what stops a hidden loan field
* blocking a Without Loan submit.
* -------------------------------------------------------------- options
* EVERY OPTION KEY IS THE LEGACY BUTTON FIELD_NAME, which is the
* convention E028 already follows: a radio or segmented group is ONE CJS
* field named after its first member, and each member becomes an option
* whose key is that member FIELD_NAME.
*
* The export rows, with LABEL_CON giving the wording:
*
*   NOG_1_1  RB3 GTYPE_N OG_NORMAL_GRANT (VALUE=X, the default)
*            RB4 GTYPE_G OG_HOUSING
*            RB5 GTYPE_P OG_PROGRAM
*   NOG_1_1  RB1 I_BENEFICIARY OG_INDIVIDUAL
*            RB2 S_BENEFICIARY OG_SHARED
*   NOG_1_2  RB0..RB4 WIFE0..WIFE4, LABEL_CON 0..4 (RB0 VALUE=X)
*   NOG_1_3  RB1 WITH_LOAN WITHLOAN / RB2 NO_LOAN WITHOUTLOAN
*
* SO OG_SHARED AND WITHLOAN WERE NOT WRONG, they were the wrong COLUMN -
* they are LABEL_CON codes, not values. Using one as a rule SRC_VALUE
* would have compared against something the field can never hold, and
* the rule would simply never have fired: the shared block and the loan
* dates would have stayed hidden with no error anywhere.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'RB3' opt_key = 'RB3' seqnr = 10
      opt_text    = lcl_txt=>en( iv_code = 'OG_NORMAL_GRANT' iv_fb = 'Normal Grant' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'OG_NORMAL_GRANT' iv_fb = 'منحة عادية' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'RB3' opt_key = 'RB4' seqnr = 20
      opt_text    = lcl_txt=>en( iv_code = 'OG_HOUSING' iv_fb = 'Housing Grant' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'OG_HOUSING' iv_fb = 'منحة سكنية' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'RB3' opt_key = 'RB5' seqnr = 30
      opt_text    = lcl_txt=>en( iv_code = 'OG_PROGRAM' iv_fb = 'Program Grant' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'OG_PROGRAM' iv_fb = 'منحة برنامج' ) )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'RB1' opt_key = 'RB1' seqnr = 10
      opt_text    = lcl_txt=>en( iv_code = 'OG_INDIVIDUAL' iv_fb = 'Individual' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'OG_INDIVIDUAL' iv_fb = 'فردية' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1'
      field_name = 'RB1' opt_key = 'RB2' seqnr = 20
      opt_text    = lcl_txt=>en( iv_code = 'OG_SHARED' iv_fb = 'Shared' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'OG_SHARED' iv_fb = 'مشتركة' ) )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB0' opt_key = 'RB0' seqnr = 10 opt_text = lcl_txt=>en( iv_code = '0' iv_fb = '0' )
      opt_text_ar = lcl_txt=>ar( iv_code = '0' iv_fb = '0' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB0' opt_key = 'RB1' seqnr = 20 opt_text = lcl_txt=>en( iv_code = '1' iv_fb = '1' )
      opt_text_ar = lcl_txt=>ar( iv_code = '1' iv_fb = '1' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB0' opt_key = 'RB2' seqnr = 30 opt_text = lcl_txt=>en( iv_code = '2' iv_fb = '2' )
      opt_text_ar = lcl_txt=>ar( iv_code = '2' iv_fb = '2' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB0' opt_key = 'RB3' seqnr = 40 opt_text = lcl_txt=>en( iv_code = '3' iv_fb = '3' )
      opt_text_ar = lcl_txt=>ar( iv_code = '3' iv_fb = '3' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'RB0' opt_key = 'RB4' seqnr = 50 opt_text = lcl_txt=>en( iv_code = '4' iv_fb = '4' )
      opt_text_ar = lcl_txt=>ar( iv_code = '4' iv_fb = '4' ) )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3'
      field_name = 'RB1_LOAN' opt_key = 'RB1' seqnr = 10
      opt_text    = lcl_txt=>en( iv_code = 'WITHLOAN' iv_fb = 'With Loan' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'WITHLOAN' iv_fb = 'بقرض' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3'
      field_name = 'RB1_LOAN' opt_key = 'RB2' seqnr = 20
      opt_text    = lcl_txt=>en( iv_code = 'WITHOUTLOAN' iv_fb = 'Without Loan' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'WITHOUTLOAN' iv_fb = 'بدون قرض' ) ) ) ).

* ---------------------------------------------------------------- rules
* TAKEN FROM UI_FIELD_LOGICS, not from the spec pages. That column
* spells the reveal out per button as TARGET-V-T / -V-F, and the wives
* radio is the one the screenshots got wrong: each button names exactly
* which child containers it shows, so this is EQ per option and not a
* GE on a count.
*
*   RB0  every CHILDnCONT-V-F        RB1  CHILD1CONT-V-T
*   RB2  CHILD1+CHILD2-V-T           RB3  CHILD1+2+3-V-T
*   RB4  all four -V-T
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R01'
      src_field = 'RB1' src_op = 'EQ' src_value = 'RB2'
      action = 'SHOW' tgt_field = 'NUMINPUT' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R02'
      src_field = 'RB1' src_op = 'EQ' src_value = 'RB2'
      action = 'SHOW' tgt_field = 'TABLE_FETCHER' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R03'
      src_field = 'RB1' src_op = 'EQ' src_value = 'RB2'
      action = 'SHOW' tgt_field = 'SHAERDID' )
*   The program-type dropdown, from RB5 -> PROGRAMCONTAINER-V-T.
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R04'
      src_field = 'RB3' src_op = 'EQ' src_value = 'RB5'
      action = 'SHOW' tgt_field = 'GRANTTYPECOMBO' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R05'
      src_field = 'RB1_LOAN' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'FROMDATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R06'
      src_field = 'RB1_LOAN' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'TODATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R07'
      src_field = 'RB1_LOAN' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'LOANVALUEINPUT' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R08'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB1'
      action = 'SHOW' tgt_field = 'CHILD1CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R09'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB2'
      action = 'SHOW' tgt_field = 'CHILD1CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R10'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB2'
      action = 'SHOW' tgt_field = 'CHILD2CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R11'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB3'
      action = 'SHOW' tgt_field = 'CHILD1CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R12'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB3'
      action = 'SHOW' tgt_field = 'CHILD2CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R13'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB3'
      action = 'SHOW' tgt_field = 'CHILD3CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R14'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB4'
      action = 'SHOW' tgt_field = 'CHILD1CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R15'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB4'
      action = 'SHOW' tgt_field = 'CHILD2CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R16'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB4'
      action = 'SHOW' tgt_field = 'CHILD3CB' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R17'
      src_field = 'RB0' src_op = 'EQ' src_value = 'RB4'
      action = 'SHOW' tgt_field = 'CHILD4CB' ) ) ).

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
  WRITE: / '  1. NO OPTION LISTS are seeded. RB3 (three options), RB1'.
  WRITE: / '     and RB1_LOAN and RB0 need ZRAK_T_JNY_OPT rows.'.
  WRITE: / '     CHILD1CB..CHILD4CB and GRANTTYPECOMBO carry the search'.
  WRITE: / '     helps the export names, so they fill themselves. Left'.
  WRITE: / '     empty on purpose: a hand-typed key that differs from'.
  WRITE: / '     the legacy one posts a value the case cannot accept.'.
  WRITE: / '  2. The rule SRC_VALUEs are OG_SHARED and WITHLOAN, from'.
  WRITE: / '     the legacy option values. The handler compares the'.
  WRITE: / '     shorter words with CS, so a rename still matches.'.
  WRITE: / '  3. Field names come from EXPORT_DEFIN.XLSX, not the spec.'.
  WRITE: / '     Option KEYS still do not - OG_SHARED and WITHLOAN are'.
  WRITE: / '     from the legacy handler; the rest of each list is not'.
  WRITE: / '     seeded. A wrong key breaks a RULE, not the screen.'.
  WRITE: / '  4. NTNLINPUT and CHNUMINPUT on NOG_1_2 are NOT seeded -'.
  WRITE: / '     the export names them, the spec pages do not label'.
  WRITE: / '     them. Add them once someone can say what they are.'.
