REPORT zrak_e029_load.

*&---------------------------------------------------------------------*
*& E029 - Issuance of New Store Contract  (legacy NE029_1_1..1_4)
*&
*& Hand-authored from the real /QNV/SB_UI_DEFIN export (DEFIN.XLSX), with
*& captions resolved through /QNV/SB_LABELT, /QNV/SB_VALUET and
*& /QNV/SB_PLACEHT.
*&
*& SISTER OF E028. ZRAK_E028_LOAD is the reference feeder for this family
*& and carries the full reasoning - read it first. Only the differences are
*& explained here.
*&
*& STRUCTURE - 3 steps, not the 4 legacy screens:
*&   STP1  NE029_1_1  Select License
*&   STP2  NE029_1_2  Lease Details
*&   STP3  NE029_1_3  Documents
*&   (NE029_1_4 is the engine's own confirmation page.)
*&
*& WHAT DIFFERS FROM E028, all confirmed by field-set diff against the
*& export rather than assumed from the family:
*&   - a STORAGE unit is chosen, not a berth: STORAGE_NUMBER_1 bound to
*&     GS_DATA-PORT_STORAGE-AOID through ZSH_CJ_DOCK_STORAGE_NUMBER
*&   - there is NO second unit. E028 has ADD_BERTH_1 plus a second
*&     dropdown; this screen has neither, so no reveal rule and no
*&     "must differ" check
*&   - validity offers TWO options, not five. The legacy DATA1 group is
*&     VALIDITY_YEAR1,VALIDITY_YEAR2 - 1 Year and 2 Years only
*&   - LABOR_LIST is NOT mandatory here (no MAND on its label row), where
*&     on E028 it is
*&
*& NO PAYMENT. No RAKPAY, no RAKREMAININGFEES and no fee CLIST anywhere in
*& NE029_1_* - confirmed against the export.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E029'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E029'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* Backend class ZCL_EGA_CJ_ENH_IMPL_E029, inheriting
* ZCL_EGA_CJ_FW_RO_EPDA_ABS. Case type on submit is ZE29.
*
* REVIEW-TEXT: TITLE from the requirement document; the authoritative text
* is ZEGA_T_CJ_IDT( 'E029' ), which is also where TITLE_AR must come from -
* left BLANK rather than invented. See the same note on E028.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Issuance of New Store Contract'
    subtitle      = 'Apply for a new store or warehouse contract at a fishing port.'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
*   ZCL_E029_NEW_STORE_LOGIC, not ZCL_E029_STORE_NEW_LOGIC. This named the
*   second, which has never had an implementation - only a .clas.xml shell,
*   so the journey would have been created pointing at a handler that does
*   not exist. E028 is the one journey whose rename to <THING>_<ACTION>
*   completed; E029, E030, E128, E129 and E130 keep their <ACTION>_<THING>
*   names, which are the ones carrying source.
    handler_class = 'ZCL_E029_NEW_STORE_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E029'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* Step titles are the legacy STAGES list the BAdI sets on READ -
* 'Lease Details,Documents,Confirmation' - with STP1's supplied, because
* the licence picker is the entry screen rather than a stage.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Select License' title_ar = 'اختيار الرخصة'
      icon = 'sap-icon://table-view' bknd_screen = 'NE029_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Lease Details' title_ar = 'تفاصيل الإيجار'
      icon = 'sap-icon://addresses' bknd_screen = 'NE029_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE029_1_3' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* Identical to E028's picker - same LICENSES grid off the same
* LICENSE_SEARCH for case type ZE03, same TYPE_1 gap, same inert
* LICENCE_NO_1. See ZRAK_E028_LOAD for the reasoning on all three.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'LICENSES' ftype = 'EDITABLE_TABLE' readonly = 'X'
      zlabel = 'Issuance of New Store Contract' zlabel_ar = 'إصدار عقد مخزن جديد'
      tech_name = 'GS_DATA-LICENSES[]' )
*   REVIEW-F4 / REVIEW-FE: no search help, and bare-token logic with no
*   DATA4/DATA5 - same two gaps as E028's TYPE_1, same reasons.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'TYPE_1' ftype = 'SELECT'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      placeholder = 'select'
      tech_name = 'GS_DATA-EXECUTIVE-TYPE' )
*   REVIEW-BE: legacy search kind 'BOAT_LICENSE'; on_search not wired.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'LICENCE_NO_1' ftype = 'SEARCH'
      zlabel = 'Fisherman License' zlabel_ar = 'رقم رخصة الصيد'
      placeholder = 'Fisherman License'
      tech_name = 'GS_DATA-LICENCE_NO' ) ) ).

* --------------------------------------------------- STP2 fields
* The applicant block, the OWNER_FINDER toggle and the duplicated
* owner-contact rows are all identical to E028 - see ZRAK_E028_LOAD for
* why OWNER_1 is authored HIDDEN, why it binds GS_DATA-REPRESENT_ID
* despite its caption, and why PARTNER_MOBILE_2 / PARTNER_EMAIL_2 are
* migrated even though they share technical names with the read-only rows.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'CTX1_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'License Number' zlabel_ar = 'رقم الرخصة'
      tech_name = 'GS_DATA-LICENCE_NO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'CTX3_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'Port name' zlabel_ar = 'اسم الميناء'
      tech_name = 'GS_DATA-PORT_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'CTX4_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'Expired' zlabel_ar = 'منتهي الصلاحية'
      tech_name = 'GS_DATA-LICENCE_VALID_TO' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'APP_NAME' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Applicant name' zlabel_ar = 'اسم مقدم الطلب'
      tech_name = 'GS_DATA-PARTNER_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'APP_ID' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Emirates id Number' zlabel_ar = 'رقم الهوية الاماراتية'
      tech_name = 'GS_DATA-PARTNER_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'PARTNER_MOBILE_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Mobile Number' zlabel_ar = 'رقم الهاتف المتحرك'
      tech_name = 'GS_DATA-PARTNER_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'PARTNER_EMAIL_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Email ID' zlabel_ar = 'البريد الإلكتروني'
      tech_name = 'GS_DATA-PARTNER_EMAIL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'OWNER_1' ftype = 'SEARCH' hidden = 'X'
      zsection = 'Owner details'
      zlabel = 'Owner details' zlabel_ar = 'بيانات المالك'
      tech_name = 'GS_DATA-REPRESENT_ID' )

*   ---- the storage block -----------------------------------------------
*   REQUIRED from the LABEL row's MAND flag, as everywhere in this family.
*   The search help filters on the hidden PORT field below
*   (SH_FILTER_FIELDS = 'PORT') - drop it and the dropdown lists stores at
*   every port.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'STORAGE_NUMBER_1' ftype = 'SELECT' required = 'X'
      zlabel = 'Storage Number' zlabel_ar = 'رقم المخزن'
      placeholder = 'select' shlp = 'ZSH_CJ_DOCK_STORAGE_NUMBER'
      msg = 'Choose a storage number, or join the waiting list'
      tech_name = 'GS_DATA-PORT_STORAGE-AOID' )

*   Legacy logic is 'STORAGE_NUMBER_1-E' - ONE target, where E028's
*   equivalent names two. Translated as READONLY rule R002, plus R003 to
*   drop the REQUIRED flag; see ZRAK_E028_LOAD on why both are needed.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'WAITING_1' ftype = 'CHECKBOX'
      zlabel = 'Waiting List' zlabel_ar = 'قائمة الانتظار'
      tech_name = 'GS_DATA-PORT_STORAGE-WAITING' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'PORT' ftype = 'DISPLAY' hidden = 'X'
      tech_name = 'GS_DATA-PORT_FILTER' )

*   REVIEW-FE: legacy TEMPLATE_BUTTON (DATA8 = 'Port_map.pdf'), which is
*   not a CJS ftype. Authored as LINK with no target yet - same open item
*   as E028, same fix serves both.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'PORT_MAP' ftype = 'LINK'
      zlabel = 'Port Map' zlabel_ar = 'خريطة الميناء' )

*   TWO validity options here, not E028's five. The legacy DATA1 group is
*   VALIDITY_YEAR1,VALIDITY_YEAR2 and nothing else - so a store contract
*   runs for one or two years where a berth can run for five. Carried
*   per-journey rather than harmonised across the family.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'VALIDITY_YEAR1' ftype = 'SEGMENTED' required = 'X'
      zlabel = 'Validity' zlabel_ar = 'الصلاحية'
      msg = 'Choose how long the contract should run'
      tech_name = 'GS_DATA-VALIDITY_YEAR1' )

*   REVIEW-BE: same duplicated technical names as E028 - see the long note
*   there. Both halves are the same fact about the same person, so the
*   editable row arriving pre-filled is intended.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 150
      field_name = 'PARTNER_MOBILE_2' ftype = 'PHONE' required = 'X'
      zlabel = 'Owner Contact Number' zlabel_ar = 'رقم التواصل مع المالك'
      msg = 'An owner contact number is required'
      tech_name = 'GS_DATA-PARTNER_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 160
      field_name = 'PARTNER_EMAIL_2' ftype = 'EMAIL' required = 'X'
      zlabel = 'Owner Email ID' zlabel_ar = 'البريد الإلكتروني للمالك'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-PARTNER_EMAIL' ) ) ).

* --------------------------------------------------- STP3 fields
* LABOR_LIST is NOT required here. Its legacy label row carries no MAND,
* where E028's and E030's do.
* REVIEW-FE: on a store contract that may well be right - there may be no
* labour to declare - but it is the one place this family disagrees with
* itself, so confirm with EPDA rather than harmonising it silently.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = 'Each file maximum allowed size - 3MB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'LABOR_LIST' ftype = 'UPLOAD'
      zsection = 'Required Documents'
      zlabel = 'Labor List' zlabel_ar = 'كشف العمال'
      has_attach = 'X' attach_label = 'Upload Labor List'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = '2P' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'OTHERS' ftype = 'UPLOAD'
      zsection = 'Required Documents'
      zlabel = 'Others or Supporting' zlabel_ar = 'اخرى'
      has_attach = 'X' attach_label = 'Upload Others or Supporting'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3 attach_multi = 'X'
      tech_name = 'P6' )

*   The licence agreement. On this screen the legacy control is called
*   TEMPLATE_BUTTON_1 rather than E028's LICENSE_AGREEMENT, but it is the
*   same TEMPLATE_BUTTON on the same DATA8 = 'LicenseAgreement.pdf'. The
*   legacy field name is kept.
*   REVIEW-FE: not a CJS ftype; authored as LINK with no target - see E028.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'TEMPLATE_BUTTON_1' ftype = 'LINK'
      zsection = 'Declaration'
      zlabel = 'License Agreement' zlabel_ar = 'اتفاقية الترخيص' )

*   REVIEW-TEXT: the visible declaration is DECLARATION_NAME, composed by
*   the BAdI with the applicant's name. Seeded here without the name so it
*   reads correctly on its own; the handler replaces it. See E028.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'DECLARATION_NAME' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'As the company owner, I hereby declare that all information provided in ' &&
                    'this application and in attached documents are true and accurate, that I ' &&
                    'will be responsible for any consequences of them, and I will be abide by ' &&
                    'all relevant regular conditions, instructions and guidelines to avoid ' &&
                    'legal action in case of violations and that I authorize our representative ' &&
                    'to follow up all the related to the activity.' )

*   Legacy 'NEXT-E' - it ENABLES Next. REQUIRED is the config equivalent;
*   see the REVIEW-FE note in ZRAK_E028_LOAD on the difference.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 60
      field_name = 'APPROVE' ftype = 'CHECKBOX' required = 'X'
      zsection = 'Declaration'
      zlabel = 'Agree to Terms and Conditions' zlabel_ar = 'اوافق على الشروط والأحكام'
      msg = 'The Terms and Conditions must be accepted before submitting'
      tech_name = 'GS_DATA-APPROVE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 70
      field_name = 'DISCLAIMER_TXT' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'Note: Once you submit, you can''t cancel the application.' ) ) ).

* ------------------------------------------------------- grid columns
* Same four columns as E028, same LSEQ order, same display-only treatment.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'LICENCE' seqnr = 10 ctrl = 'INPUT' readonly = 'X'
      width = '30%' align = 'Begin'
      zlabel = 'License' zlabel_ar = 'رقم الرخصة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'DESCRIPTION' seqnr = 20 ctrl = 'INPUT' readonly = 'X'
      width = '30%' align = 'Begin'
      zlabel = 'Port Name' zlabel_ar = 'الميناء' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'ISSUED_AT' seqnr = 30 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Issued at' zlabel_ar = 'تاريخ الإصدار' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'EXPIRED_AT' seqnr = 40 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Expired at' zlabel_ar = 'انتهت صلاحيتها في' ) ) ).

* ---------------------------------------------------------------- rules
* Three rules, one fewer group than E028 because there is no second
* storage unit to reveal.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R001'
      src_field = 'PARTNER_OWNER_1' src_op = 'EQ' src_value = 'PARTNER_REP_1'
      action = 'SHOW' tgt_field = 'OWNER_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R002'
      src_field = 'WAITING_1' src_op = 'EQ' src_value = 'X'
      action = 'READONLY' tgt_field = 'STORAGE_NUMBER_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R003'
      src_field = 'WAITING_1' src_op = 'EQ' src_value = 'X'
      action = 'OPTIONAL' tgt_field = 'STORAGE_NUMBER_1' ) ) ).

* -------------------------------------------------------------- options
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_OWNER_1' seqnr = 10
      opt_text = 'Owner' opt_text_ar = 'المالك' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_REP_1' seqnr = 20
      opt_text = 'Representative' opt_text_ar = 'الوكيل' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'VALIDITY_YEAR1' opt_key = 'VALIDITY_YEAR1' seqnr = 10
      opt_text = '1 Year' opt_text_ar = 'عام' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'VALIDITY_YEAR1' opt_key = 'VALIDITY_YEAR2' seqnr = 20
      opt_text = '2 Years' opt_text_ar = 'عامين' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Issuance of New Store Contract'.
  WRITE: / '  3 steps (legacy NE029_1_1..1_3; _1_4 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Select License    3 fields (licence grid, 4 columns, read-only)'.
  WRITE: / '  STP2 Lease Details    16 fields, 2 sections'.
  WRITE: / '  STP3 Documents         7 fields, 2 uploads'.
  WRITE: / '  3 rules, 4 segmented options across 2 groups, 4 grid columns'.
  WRITE: / '  No payment step - confirmed absent from the export, not omitted.'.
  WRITE: /.
  WRITE: / 'Differences from E028, all read off the export:'.
  WRITE: / '  a STORAGE unit is chosen, not a berth; there is NO second unit;'.
  WRITE: / '  validity offers 1 or 2 years only; LABOR_LIST is not mandatory.'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-TEXT  TITLE_AR is BLANK - read ZEGA_T_CJ_IDT( E029, A ).'.
  WRITE: / ' REVIEW-FE    PORT_MAP and TEMPLATE_BUTTON_1 are legacy TEMPLATE_BUTTONs,'.
  WRITE: / '              not a CJS ftype. Both are LINK with no target yet.'.
  WRITE: / ' REVIEW-F4    TYPE_1 has no search help - it renders EMPTY.'.
  WRITE: / ' REVIEW-FE    TYPE_1''s bare-token logic could not be authored as a rule.'.
  WRITE: / ' REVIEW-FE    LABOR_LIST is optional here and mandatory on E028/E030 -'.
  WRITE: / '              the one place this family disagrees with itself. Confirm.'.
  WRITE: / ' REVIEW-BE    PARTNER_MOBILE_2 / PARTNER_EMAIL_2 share technical names'.
  WRITE: / '              with the read-only applicant rows - deliberate, see source.'.
  WRITE: / ' REVIEW-BE    LICENCE_NO_1 and OWNER_1 render but return nothing.'.
  WRITE: / ' REVIEW-F4    the storage dropdown filters on the hidden PORT field.'.
