REPORT zrak_e028_load.

*&---------------------------------------------------------------------*
*& E028 - Issuance of New Berth Contract  (legacy NE028_1_1..1_4)
*&
*& Hand-authored from the real /QNV/SB_UI_DEFIN export (DEFIN.XLSX), with
*& every caption resolved through /QNV/SB_LABELT and /QNV/SB_VALUET and
*& every placeholder through /QNV/SB_PLACEHT.
*&
*& THIS IS THE REFERENCE FEEDER for the berth/store/housing family. E128,
*& E029, E129, E030 and E130 are all variations on it, and the notes here
*& are not repeated in full there - read this one first.
*&
*& STRUCTURE - 3 steps, not the 4 legacy screens:
*&   STP1  NE028_1_1  Select License
*&   STP2  NE028_1_2  Lease Details
*&   STP3  NE028_1_3  Documents
*&   (NE028_1_4 is the confirmation page - E003_APPLICATION_NUMBER,
*&    E003_APPLICATION_TYPE, FINAL_1_NOTIFICATION_SENT_MESSAGE - which
*&    the engine appends for itself after submit.)
*&
*& The step titles are the legacy STAGES list, which is NOT in the export:
*& ZCL_EGA_CJ_ENH_IMPL_E028->READ sets
*&     WHEN 'STAGES'. <definition>-additionaldata3 = 'Lease Details,Documents,Confirmation'
*& so those three are the stage names the citizen sees today. STP1 is the
*& licence picker, which the legacy screen treats as the entry point
*& rather than a stage (GET_SCREEN jumps straight to NE028_1_2 when
*& FROMLOBBY is blank), so it is not in that list and its title is
*& supplied here.
*&
*& NO PAYMENT. No RAKPAY, no RAKREMAININGFEES and no fee CLIST anywhere in
*& NE028_1_* - confirmed against the export, not assumed.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E028'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E028'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* BKND_CATEGORY = 'EPDA' and BKND_JOURNEY = 'E028' from the export's own
* CATEGORY column and the JOURNEYTYPE row on every screen. The backend
* class the screens name is ZCL_EGA_CJ_ENH_IMPL_E028, which inherits
* ZCL_EGA_CJ_FW_RO_EPDA_ABS - a different abstract from the E014 family's
* ZCL_EGA_CJ_CONSULTANT_ABS, so nothing about the consultancy journeys'
* backend behaviour can be assumed here.
*
* REVIEW-TEXT: TITLE is taken from the requirement document's own name.
* The legacy screens bind TITLE_TEXT to GS_DATA-TITLE, which the BAdI
* fills from ZEGA_T_CJ_IDT keyed on journey id and language - so the
* authoritative title lives in that table, not in the UI export, and
* TITLE_AR is left BLANK rather than invented. Read
* ZEGA_T_CJ_IDT( journeyid = 'E028', spras = 'A' ) and put its DESCRIPTION
* here before go-live.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Issuance of New Berth Contract'
    subtitle      = 'Apply for a new berth or parking contract at a fishing port.'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_E028_BERTH_NEW_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E028'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* No NEXT_REQUIRES on any step: the only legacy gate of that kind is a
* payment, and there is none here. STP3's footer offers Submit directly -
* gated instead by the APPROVE checkbox, which the legacy screen wires as
* 'NEXT-E' (it ENABLES Next). See the note on STP3.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Select License' title_ar = 'اختيار الرخصة'
      icon = 'sap-icon://table-view' bknd_screen = 'NE028_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Lease Details' title_ar = 'تفاصيل الإيجار'
      icon = 'sap-icon://addresses' bknd_screen = 'NE028_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE028_1_3' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* The fishing licence the berth contract will hang off, reachable two ways
* on the legacy screen - pick it from the grid, or search for it - and both
* are migrated because the export carries both and they are not
* interchangeable: the grid lists what this citizen already holds (the
* BAdI's CREATE fills GS_DATA-LICENSES from ZCL_EGA_EPDA_FSHRY_HANDLER_API
* ->LICENSE_SEARCH for case type ZE03), the search reaches one held by
* somebody else.
*
* LICENSES is READONLY because the row is PICKED, not typed, and the legacy
* MTABLE declares D3 = SingleSelectLeft: exactly one licence per contract.
*
* Legacy MTABLE_SEARCH_1 (a search box over the grid, D1 = LICENSES) is not
* migrated as a field - the engine's own grid renders its filter, so a
* configured search control would draw a second box that filters nothing.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'LICENSES' ftype = 'EDITABLE_TABLE' readonly = 'X'
      zlabel = 'Issuance of New Berth Contract' zlabel_ar = 'إصدار عقد مرسى جديد'
      tech_name = 'GS_DATA-LICENSES[]' )

*   REVIEW-F4: TYPE_1 is a COMBOBOX with NO search help, no CLIST and no
*   value list anywhere in the export - exactly the same gap E027's TYPE_1
*   has, on the same GS_DATA-EXECUTIVE-TYPE binding. The legacy screen
*   filled its options from the BAdI at runtime. It renders EMPTY until a
*   SHLP is supplied here or the handler adds on_value_help.
*   REVIEW-FE: its UI_FIELD_LOGICS lists LICENSE_TABLE and LICENSE_SEARCH
*   as BARE tokens - no -V-T / -V-F suffix - and neither target carries a
*   DATA4/DATA5 pair saying WHICH value shows which. So the intent (own
*   licence -> the grid, someone else's -> the search) is real but its
*   trigger value is not recoverable from this export. Both targets are
*   authored visible rather than guessed into a rule.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'TYPE_1' ftype = 'SELECT'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      placeholder = 'select'
      tech_name = 'GS_DATA-EXECUTIVE-TYPE' )

*   REVIEW-BE: legacy DATA1 = 'BOAT_LICENSE' names the search kind the
*   legacy finder called. on_search is not wired, so SEARCH renders but a
*   press returns nothing - the same open item as E014/E015/E027. One
*   licence-search API, one place to wire it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'LICENCE_NO_1' ftype = 'SEARCH'
      zlabel = 'Fisherman License' zlabel_ar = 'رقم رخصة الصيد'
      placeholder = 'Fisherman License'
      tech_name = 'GS_DATA-LICENCE_NO' ) ) ).

* --------------------------------------------------- STP2 fields
* ZSECTION carries the legacy headings, VALUE-resolved: "Applicant Details"
* / "Owner details". The berth block and the validity block head no
* section of their own on the legacy screen, so their captions are field
* labels rather than sections.
*
* Three rows from the legacy card header are carried as READONLY context -
* they tell the citizen WHICH licence this contract is against. No
* ZSECTION, because the legacy header strip has no heading row.
*
* ERROR_1 (MESSAGE_STRIP on GS_DATA-ERROR) is not migrated: the engine
* renders backend and validation messages in its own message area.
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

*   The four applicant rows are READONLY because on the legacy screen they
*   are LABELs bound to GS_DATA-PARTNER_* which the BAdI's CREATE fills
*   from BUT000 / ADR6 / ADR2 / BUT0ID for the logged-in partner. The
*   citizen never types them.
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

*   TWO legacy TBUTTONs, one shared DATA1 group: PARTNER_OWNER_1 /
*   PARTNER_REP_1 - Owner / Representative. The same two-way group E015 and
*   E027 have, and NOT E014's three-way. Collapsed into ONE segmented
*   field, named after the lowest-sequence member so the options below and
*   the handler's role fan-out agree on the source field name.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )

*   HIDDEN and revealed by R001. Straight from the legacy UI_FIELD_LOGICS -
*   OWNER_FINDER-V-F on Owner, OWNER_FINDER-V-T on Representative - which
*   is counter-intuitive but correct, and the same trap that had E015 and
*   E027 showing this lookup backwards: it identifies the party somebody
*   ELSE is applying for, so it appears for a representative and never for
*   the owner applying personally.
*
*   NOTE the binding: GS_DATA-REPRESENT_ID, not GS_DATA-OWNER. Despite the
*   container being OWNER_FINDER and the caption "Owner details", this
*   field records the REPRESENTATIVE - consistent with it only appearing
*   when one applies. Legacy caption carried as-is.
*   REVIEW-BE: on_search not wired; see the note on STP1.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'OWNER_1' ftype = 'SEARCH' hidden = 'X'
      zsection = 'Owner details'
      zlabel = 'Owner details' zlabel_ar = 'بيانات المالك'
      tech_name = 'GS_DATA-REPRESENT_ID' )

*   ---- the berth block, and the reason this journey needs a handler ----
*   DOK_PARKING_NUMBER_1 is REQUIRED from its LABEL row's MAND flag (the
*   combobox itself carries none - the legacy renderer takes the asterisk
*   from the label, which is the pairing rule this family follows).
*
*   The search help filters on a field called PORT: SH_FILTER_FIELDS =
*   'PORT'. That is why the hidden PORT field below has to exist - drop it
*   and the dropdown comes back either empty or unfiltered, showing berths
*   at every port in the emirate.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'DOK_PARKING_NUMBER_1' ftype = 'SELECT' required = 'X'
      zlabel = 'Dock/Parking Number' zlabel_ar = 'رقم المرسى'
      placeholder = 'select' shlp = 'ZSH_CJ_DOCK_PARKING_NUMBER'
      msg = 'Choose a dock/parking number, or join the waiting list'
      tech_name = 'GS_DATA-BERTH-AOID' )

*   Ticking Waiting List DISABLES both berth dropdowns - legacy logic
*   'DOK_PARKING_NUMBER_1-E,CB_DOK_PARKING_NUMBER_2-E', confirmed by the
*   BAdI's own READ: "WHEN 'DOK_PARKING_NUMBER_1' OR
*   'CB_DOK_PARKING_NUMBER_2'. IF gs_data-berth-waiting IS NOT INITIAL.
*   <definition>-enabled = abap_false." Translated as READONLY rules
*   R002/R003 - the engine has no ENABLE/DISABLE action, and READONLY is
*   what "greyed out but still shown" means here.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'WAITING_1' ftype = 'CHECKBOX'
      zlabel = 'Waiting List' zlabel_ar = 'قائمة الانتظار'
      tech_name = 'GS_DATA-BERTH-WAITING' )

*   Legacy logic on ADD_BERTH_1 is 'CB_DOK_PARKING_NUMBER_2-V' - a -V with
*   no -T/-F, which in this grammar means "reveal the target". So the
*   second dropdown is authored HIDDEN with one SHOW rule (R004).
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'ADD_BERTH_1' ftype = 'CHECKBOX'
      zlabel = 'Add Another Dock/Parking Number' zlabel_ar = 'مرسى اضافي'
      tech_name = 'GS_DATA-ADD_BERTH' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'CB_DOK_PARKING_NUMBER_2' ftype = 'SELECT' hidden = 'X'
      zlabel = 'Second Dock/Parking Number' zlabel_ar = 'رقم المرسى الثاني'
      placeholder = 'select' shlp = 'ZSH_CJ_DOCK_PARKING_NUMBER'
      tech_name = 'GS_DATA-BERTH2-AOID' )

*   The filter carrier for both berth dropdowns. VISIBLE is blank on the
*   legacy row and TOSAVE is set - it is a hidden value, not a control -
*   so it is authored HIDDEN. GS_DATA-PORT_FILTER is built by the BAdI as
*   either "<caseid>|C" or "<port>|P", which is why it is not simply the
*   port code.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'PORT' ftype = 'DISPLAY' hidden = 'X'
      tech_name = 'GS_DATA-PORT_FILTER' )

*   The port map. Legacy CONTROL_TYPE is TEMPLATE_BUTTON with
*   DATA8 = 'Port_map.pdf' - a button that opens a stored PDF.
*   REVIEW-FE: TEMPLATE_BUTTON is NOT a CJS ftype (checked against
*   ZCL_RAK_JOURNEY_RENDER). Authored as LINK, which IS recognised, so the
*   citizen still gets something clickable - but LINK has no notion of a
*   template document, so the target has to be supplied. The legacy BAdI
*   serves the bytes by base64-encoding ZDT_EPDA_BOATP-CONTENT for the
*   selected port; wire that through get_attach_url or a render_field
*   redefinition before go-live, or the link goes nowhere.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 150
      field_name = 'PORT_MAP' ftype = 'LINK'
      zlabel = 'Port Map' zlabel_ar = 'خريطة الميناء' )

*   Five legacy TBUTTONs in one DATA1 group (1 to 5 years) collapse into
*   one segmented field. E029 offers only two of these and E030 seven -
*   the option list is per journey and is not shared.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 160
      field_name = 'VALIDITY_YEAR1' ftype = 'SEGMENTED' required = 'X'
      zlabel = 'Validity' zlabel_ar = 'الصلاحية'
      msg = 'Choose how long the contract should run'
      tech_name = 'GS_DATA-VALIDITY_YEAR1' )

*   REVIEW-BE: these two share their technical names with the READONLY
*   applicant rows above - GS_DATA-PARTNER_MOBILE and
*   GS_DATA-PARTNER_EMAIL each appear twice on the legacy screen, once as
*   a display row under "Applicant Details" and once as an editable
*   "Owner ..." input. BOTH are migrated, which is the opposite of the
*   call made on D009, and deliberately so: there the duplicate pair was
*   current-vs-new and pre-filling the new one was actively wrong, whereas
*   here both halves are the same fact about the same person, so the
*   editable row arriving pre-filled with the session's contact details is
*   the intended behaviour. The post's last-write-wins therefore lands on
*   the editable row, which is where the citizen's correction is.
*   If EPDA ever wants the owner's contact recorded SEPARATELY from the
*   applicant's, that needs its own backend member - one field cannot hold
*   both.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 170
      field_name = 'PARTNER_MOBILE_2' ftype = 'PHONE' required = 'X'
      zlabel = 'Owner Contact Number' zlabel_ar = 'رقم التواصل مع المالك'
      msg = 'An owner contact number is required'
      tech_name = 'GS_DATA-PARTNER_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 180
      field_name = 'PARTNER_EMAIL_2' ftype = 'EMAIL' required = 'X'
      zlabel = 'Owner Email ID' zlabel_ar = 'البريد الإلكتروني للمالك'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-PARTNER_EMAIL' ) ) ).

* --------------------------------------------------- STP3 fields
* ATTACH_MAXMB = 3 from this screen's own notice, not the framework
* default. TECH_NAME on an upload is the legacy document code (DATA2),
* which is what the attachment pipeline files against.
*
* Both document codes are distinct (2P, P6), so unlike the E014 family
* there is no shared-bucket collision to flag.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = 'Each file maximum allowed size - 3MB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'LABOR_LIST' ftype = 'UPLOAD' required = 'X'
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

*   The licence agreement the citizen is agreeing to. Legacy
*   CONTROL_TYPE is TEMPLATE_BUTTON, DATA8 = 'LicenseAgreement.pdf', and
*   the BAdI serves it by base64-encoding ZDT_EPDA_BOATP-CONTENT for
*   port '00'. Authored as LINK for the same reason as PORT_MAP - see
*   the REVIEW-FE note there; the same wiring serves both.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'LICENSE_AGREEMENT' ftype = 'LINK'
      zsection = 'Declaration'
      zlabel = 'License Agreement' zlabel_ar = 'اتفاقية الترخيص' )

*   REVIEW-TEXT: the legacy DECLARATION_LONG1 / DECLARATION_LONG2 rows
*   carry VISIBLE = blank - they are NOT shown. What the citizen actually
*   reads is DECLARATION_NAME, which the BAdI composes at runtime as
*   "I, <partner name> as the company owner, hereby declare ...". So the
*   default text below is that sentence without its name prefix, readable
*   on its own, and ZCL_E028_BERTH_NEW_LOGIC->ON_AFTER_READ replaces it
*   with the name-prefixed version once the name is known. If the handler
*   is ever removed, the citizen still sees a complete declaration.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'DECLARATION_NAME' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'As the company owner, I hereby declare that all information provided in ' &&
                    'this application and in attached documents are true and accurate, that I ' &&
                    'will be responsible for any consequences of them, and I will be abide by ' &&
                    'all relevant regular conditions, instructions and guidelines to avoid ' &&
                    'legal action in case of violations and that I authorize our representative ' &&
                    'to follow up all the related to the activity.' )

*   The legacy screen wires APPROVE as 'NEXT-E' - it ENABLES the Next
*   button. REQUIRED is the closest configuration equivalent: it makes
*   ticking a condition of leaving the step.
*   REVIEW-FE: required-validation refuses the press with a message rather
*   than greying the button out the way the legacy screen did. If the exact
*   behaviour matters it needs a render_field redefinition, not config.
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
* The four LEVEL_CON=T columns under the legacy LICENSES table, in LSEQ
* order. Legacy CTRL is LABEL on all four - the grid is display-only - but
* CTRL here is a control type rather than a rendering hint, so the two
* dates are DATE and the identifier and port name INPUT. READONLY on every
* column keeps the display-only behaviour regardless.
*
* COL_NAME is the legacy column name, which is what the backend table
* returns. DESCRIPTION is kept even though its caption is "Port Name" -
* renaming it here would simply blank the column.
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
* R001 is the OWNER_FINDER toggle: OWNER_FINDER-V-T on PARTNER_REP_1. One
* SHOW rule and no HIDE rule, because the field is authored HIDDEN - "not
* shown" is its resting state.
*
* R002/R003 are the Waiting List gate. The engine has SHOW / HIDE /
* REQUIRE / OPTIONAL / READONLY / EDITABLE and no ENABLE, so the legacy
* '-E' disable becomes READONLY: tick Waiting List and both berth
* dropdowns grey out, which is what the BAdI does by clearing ENABLED.
*
* R004 is the second-berth reveal: ADD_BERTH_1 ticked shows
* CB_DOK_PARKING_NUMBER_2, which is authored HIDDEN.
*
* SRC_VALUE = 'X' for all three checkbox sources - the convention already
* used by HIDE_QTY, VISIT_REQUIRED and STATUS elsewhere in this repo.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R001'
      src_field = 'PARTNER_OWNER_1' src_op = 'EQ' src_value = 'PARTNER_REP_1'
      action = 'SHOW' tgt_field = 'OWNER_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R002'
      src_field = 'WAITING_1' src_op = 'EQ' src_value = 'X'
      action = 'READONLY' tgt_field = 'DOK_PARKING_NUMBER_1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R003'
      src_field = 'WAITING_1' src_op = 'EQ' src_value = 'X'
      action = 'READONLY' tgt_field = 'CB_DOK_PARKING_NUMBER_2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R004'
      src_field = 'ADD_BERTH_1' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'CB_DOK_PARKING_NUMBER_2' )
*   Waiting List and a chosen berth are alternatives, so joining the queue
*   must also drop the REQUIRED flag off the dropdown or the citizen can
*   never leave the step. The legacy screen got this for free by disabling
*   the control; the engine validates REQUIRED independently of READONLY,
*   so it has to be said.
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R005'
      src_field = 'WAITING_1' src_op = 'EQ' src_value = 'X'
      action = 'OPTIONAL' tgt_field = 'DOK_PARKING_NUMBER_1' ) ) ).

* -------------------------------------------------------------- options
* Two segmented groups on this step.
*
* The applicant type's OPT_KEY is the legacy field name of each button,
* which is what the handler's role fan-out writes back to
* GS_DATA-PARTNER_OWNER / GS_DATA-PARTNER_REP.
*
* The validity group's OPT_KEY is likewise the legacy button name, and the
* handler fans it out into GS_DATA-VALIDITY_YEAR1..5 - five separate
* backend flags behind one control, the same shape as the applicant type.
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
      opt_text = '2 Years' opt_text_ar = 'عامين' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'VALIDITY_YEAR1' opt_key = 'VALIDITY_YEAR3' seqnr = 30
      opt_text = '3 Years' opt_text_ar = 'ثلاث سنوات' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'VALIDITY_YEAR1' opt_key = 'VALIDITY_YEAR4' seqnr = 40
      opt_text = '4 Years' opt_text_ar = 'أربع سنوات' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'VALIDITY_YEAR1' opt_key = 'VALIDITY_YEAR5' seqnr = 50
      opt_text = '5 Years' opt_text_ar = 'خمس سنوات' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Issuance of New Berth Contract'.
  WRITE: / '  3 steps (legacy NE028_1_1..1_3; _1_4 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Select License    3 fields (licence grid, 4 columns, read-only)'.
  WRITE: / '  STP2 Lease Details    18 fields, 2 sections'.
  WRITE: / '  STP3 Documents         7 fields, 2 uploads'.
  WRITE: / '  5 rules, 7 segmented options across 2 groups, 4 grid columns'.
  WRITE: / '  No payment step - confirmed absent from the export, not omitted.'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-TEXT  TITLE comes from the requirement document; the authoritative'.
  WRITE: / '              text is ZEGA_T_CJ_IDT( E028 ). TITLE_AR is BLANK - read it'.
  WRITE: / '              from that table with SPRAS = A before go-live.'.
  WRITE: / ' REVIEW-FE    PORT_MAP and LICENSE_AGREEMENT are legacy TEMPLATE_BUTTONs.'.
  WRITE: / '              That is not a CJS ftype, so both are LINK and have no target'.
  WRITE: / '              yet. The BAdI serves the PDFs from ZDT_EPDA_BOATP-CONTENT.'.
  WRITE: / ' REVIEW-F4    TYPE_1 has NO search help and no value list anywhere in the'.
  WRITE: / '              export - it renders EMPTY until one is supplied.'.
  WRITE: / ' REVIEW-FE    TYPE_1''s LICENSE_TABLE / LICENSE_SEARCH logic uses bare'.
  WRITE: / '              tokens with no DATA4/DATA5, so no rule could be authored.'.
  WRITE: / ' REVIEW-BE    PARTNER_MOBILE_2 / PARTNER_EMAIL_2 share their technical'.
  WRITE: / '              names with the read-only applicant rows. Both are migrated'.
  WRITE: / '              on purpose - see the note in the source.'.
  WRITE: / ' REVIEW-BE    LICENCE_NO_1 and OWNER_1 render but return nothing:'.
  WRITE: / '              on_search is not wired. Legacy search kind is BOAT_LICENSE.'.
  WRITE: / ' REVIEW-F4    both berth dropdowns filter on the hidden PORT field'.
  WRITE: / '              (SH_FILTER_FIELDS = PORT). Run ZRAK_CJS_XCHECK and confirm'.
  WRITE: / '              ZSH_CJ_DOCK_PARKING_NUMBER returns berths for one port only.'.
