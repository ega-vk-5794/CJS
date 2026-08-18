REPORT zrak_d009_load.

*&---------------------------------------------------------------------*
*& D009 - Changing the school's Location  (legacy ND009_1_1..1_4)
*&
*& The one DOKSL journey in this set - CATEGORY is 'DOKSL', not 'EPDA',
*& and its backend class is ZCL_EGA_CJ_ENH_IMPL_D009. Its screens come
*& from a different export file (ADDN) than the five E-code journeys,
*& which is why they are absent from the main EPDA extract.
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
*& THIS IS D009, NOT "D019 Academic Calendar". Confirmed from the real
*& field content, not from screenshots: ND009_1_3's uploads are the
*& ministry-approved floor plan, the civil-defence clearance certificate
*& and the RAK Municipality building-suitability certificate - the
*& document set for moving a school's premises. The journey's own
*& JOURNEYTYPE row also carries VALUE = 'D009' on every screen.
*&
*& STRUCTURE - 3 steps, not the 4 legacy screens:
*&   STP1  ND009_1_1  Select License
*&   STP2  ND009_1_2  School & New Location
*&   STP3  ND009_1_3  Documents & Declaration
*&   (ND009_1_4 is "Your Request was submitted!" with the request id,
*&    application type and application number - the engine appends its
*&    own confirmation step after submit, so migrating that screen would
*&    show it twice.)
*&
*& NO PAYMENT STEP. Verified against the export: there is no RAKPAY, no
*& RAKREMAININGFEES and no fee CLIST anywhere in ND009_1_*.
*&
*& THE STRUCTURAL TRAP ON STP2, and the reason this feeder is worth
*& reading before changing: the legacy screen shows the school's CURRENT
*& address, parcel id, telephone, location and PO box as disabled fields,
*& and then asks for the NEW ones in a second block - but BOTH blocks are
*& bound to the SAME five technical names (GS_DATA-SCHOOL-ADRESS,
*& -PARCEL_ID, -TELEPHONE, -LOCATION, -POBOX) and BOTH carry TOSAVE. The
*& CJS post layer sends every field that has a tech_name, so authoring
*& both would post each of those five twice and the later write would win
*& silently. Only the EDITABLE half is migrated. See the REVIEW-BE note
*& on the "New Location" section for what that costs and how to get the
*& current values back on screen properly.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'D009'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'D009'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* BKND_CATEGORY = 'DOKSL', from the export's own CATEGORY column on every
* ND009_1_* row. Getting this wrong is not a cosmetic error: the read and
* post BAdI filters key off it, so an EPDA category here would send this
* journey's traffic to the wrong implementation.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Changing the school''s Location'
    title_ar      = 'تغيير موقع المدرسة'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_D009_SCHOOL_LOCA_CHG_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'DOKSL'
    bknd_journey  = 'D009'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* No NEXT_REQUIRES on any step: the only legacy gate of that kind is a
* payment, and there is none here. STP3's footer offers Submit directly.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Select License' title_ar = 'اختيار الرخصة'
      icon = 'sap-icon://table-view' bknd_screen = 'ND009_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'School & New Location' title_ar = 'المدرسة والموقع الجديد'
      icon = 'sap-icon://map' bknd_screen = 'ND009_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'ND009_1_3' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* One control: the school licence whose location is changing. READONLY
* because the row is PICKED, not typed - the licences come from the
* backend (D1 = ZFM_EGA_CJ_FW_READ_TABLE_DATAN, D2 = LICENCES) and an
* editable grid would let a citizen retype an expiry date and move a
* school that does not exist.
*
* The legacy MTABLE declares D3 = SingleSelectLeft: exactly one licence
* per application, selected by a leading radio column.
*
* ZSECTION is blank on purpose: ND009_1_1 has no section LABEL row at all
* (its only VALUE text is the page title), so there is no legacy heading
* to carry and none is invented. ZLABEL carries the page title so the grid
* does not render caption-less, the same way E142's and E146's STP1 do.
*
* NOTE the legacy backend context is spelled 'LICENCES' (D2) while the
* control is named LICENSES. Both spellings are carried exactly as
* exported - the control name here, the context in the backend read - and
* neither is "corrected", because the backend matches on its own spelling.
  INSERT zrak_t_jny_fld FROM @( VALUE #(
    mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
    field_name = 'LICENSES' ftype = 'EDITABLE_TABLE' readonly = 'X'
    zlabel = 'Changing the school''s Location' zlabel_ar = 'تغيير موقع المدرسة'
    tech_name = 'GS_DATA-LICENSES[]' ) ).

* --------------------------------------------------- STP2 fields
* ZSECTION carries the legacy panel and section headings, VALUE-resolved:
* "Applicant Details" / "School Details" / "Managment" (the legacy
* spelling) / and one supplied caption, flagged below.
*
* Three rows from the legacy card header are carried as READONLY context
* rather than dropped, because they are what tell the citizen WHICH
* licence this application is against. They have no ZSECTION because the
* legacy header strip has no heading row.
*
* Everything in "School Details" and "Managment" is READONLY because on
* the legacy screen every one of those controls carries ENABLED = blank -
* they are the school as it stands today, filled by the backend read. The
* three comboboxes among them (registered authority, curriculum,
* curriculum type) are declared SELECT with READONLY so that the value
* still resolves through its search help for display rather than showing
* a raw key.
*
* ERROR_1 (MESSAGE_STRIP on GS_DATA-ERROR) is not migrated: the engine
* renders backend and validation messages in its own message area, so a
* configured strip would duplicate it.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'CTX1_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'License Number' zlabel_ar = 'رقم الرخصة'
      tech_name = 'GS_DATA-LICENCE_NO' )
*   REVIEW-TEXT: the legacy caption on this row is "Issued" but it is
*   bound to GS_DATA-LICENCE_NAME - a name, not a date. Its sibling
*   journeys put the issue DATE here. Either the caption is wrong or the
*   binding is; the legacy pair is carried as-is rather than guessing
*   which end to fix, because renaming it would hide the discrepancy
*   instead of surfacing it. Confirm with DOK which was intended.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'CTX3_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'Issued' zlabel_ar = 'أصدر'
      tech_name = 'GS_DATA-LICENCE_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'CTX4_D_VALUE' ftype = 'READONLY' readonly = 'X'
      zlabel = 'Expired' zlabel_ar = 'منتهي الصلاحية'
      tech_name = 'GS_DATA-LICENCE_VALID_TO' )

*   REVIEW-BE: the legacy "Applicant Details" block has THREE captions -
*   "Applicant name", "Emirates id Number" and "Applicant Type" - but only
*   the third has anything behind it. APP_NAME and APP_ID are LABEL rows
*   with no TECHNICAL_NAME and no VALUE: the legacy screen filled them at
*   runtime and there is nothing in the export to bind. They are therefore
*   NOT authored, rather than authored as two permanently blank rows.
*
*   They are also not bound to GS_DATA-PARTNER_NAME / _ID the way the five
*   E-code journeys are, because this journey's structure does not have
*   those fields - the only applicant member ND009_1_* exposes anywhere is
*   GS_DATA-PARTNER, a bare BP number, and labelling a BP number "Emirates
*   id Number" would be worse than showing nothing. To display the
*   applicant's name and ID here, the DOKSL read has to expose them first.
*
*   APP_TYPE is READONLY because its legacy control carries ENABLED =
*   blank - the portal knows what kind of applicant is signed in, the
*   citizen does not choose it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'APP_TYPE' ftype = 'SELECT' readonly = 'X'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      shlp = 'ZSH_CJ_APPLICANT_TYPE'
      tech_name = 'GS_DATA-APPLICANT_TYPE' )

*   --- School Details: the school as it stands today, all read-only.
*   The five members that ALSO appear in the editable block below
*   (address, parcel id, telephone, location, PO box) are deliberately
*   absent here - see the header note and the REVIEW-BE on "New Location".
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'SCHOOL_NAME_EN_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'School Details'
      zlabel = 'School Name English' zlabel_ar = 'اسم المدرسة باللغة الإنجليزية'
      tech_name = 'GS_DATA-SCHOOL-SCHOOL_NAME_EN' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'SCHOOL_NAME_AR_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'School Details'
      zlabel = 'School Name Arabic' zlabel_ar = 'اسم المدرسة باللغة العربية'
      tech_name = 'GS_DATA-SCHOOL-SCHOOL_NAME_AB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'REG_AUTHORITY_1' ftype = 'SELECT' readonly = 'X'
      zsection = 'School Details'
      zlabel = 'Trade License Registered Authority' zlabel_ar = 'الجهة المسجلة للرخصة التجارية'
      shlp = 'ZSH_CJ_TRADE_AUTHORITY'
      tech_name = 'GS_DATA-SCHOOL-REG_AUTHORITY' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'TRADE_LIC_2' ftype = 'READONLY' readonly = 'X'
      zsection = 'School Details'
      zlabel = 'Trade License Number' zlabel_ar = 'رقم الرخصة التجارية'
      tech_name = 'GS_DATA-SCHOOL-TRADE_LIC' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'CURRICULUM_COMB' ftype = 'SELECT' readonly = 'X'
      zsection = 'School Details'
      zlabel = 'Curriculum' zlabel_ar = 'المنهج'
      shlp = 'ZSH_CJ_CURRICULUM'
      tech_name = 'GS_DATA-SCHOOL-CURRICULUM' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 100
      field_name = 'CURRICULUM_TYPE_1' ftype = 'SELECT' readonly = 'X'
      zsection = 'School Details'
      zlabel = 'Curriculum Type' zlabel_ar = 'نوع المنهج'
      shlp = 'ZSH_CJ_CURRICULUM_TYPE'
      tech_name = 'GS_DATA-SCHOOL-CURRICULUM_TYPE' )

*   --- Managment: the legacy panel spelling is kept because it is the
*   heading the citizen sees today and changing it is a text decision, not
*   a migration one.
*
*   OWNERS is a display-only list - the legacy MTABLE has NO DATA3
*   select directive, unlike the licence grids, so nothing is picked from
*   it. It is authored EDITABLE_TABLE + READONLY so its five columns come
*   from ZRAK_T_JNY_COL below rather than from a handler get_table( )
*   redefinition: config that a functional consultant can change beats
*   ABAP that needs a transport, and the backend read (D2 = OWNERS_DISP)
*   already returns the rows.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 110
      field_name = 'OWNERS' ftype = 'EDITABLE_TABLE' readonly = 'X'
      zsection = 'Managment'
      zlabel = 'Owners' zlabel_ar = 'الملاك'
      tech_name = 'GS_DATA-OWNERS[]' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 120
      field_name = 'MANAGER_NAME_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Managment'
      zlabel = 'Manager' zlabel_ar = 'المدير'
      tech_name = 'GS_DATA-MANAGER_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 130
      field_name = 'MANAGER_EMIRATES_ID_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Managment'
      zlabel = 'Emirates ID' zlabel_ar = 'رقم الهوية الإماراتية'
      tech_name = 'GS_DATA-MANAGER_EMIRATES_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 140
      field_name = 'MANAGER_NATIONALITY_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Managment'
      zlabel = 'Nationality' zlabel_ar = 'الجنسية'
      tech_name = 'GS_DATA-MANAGER_NATIONALITY' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 150
      field_name = 'MANAGER_MOBILE_NUMBER_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Managment'
      zlabel = 'Mobile number' zlabel_ar = 'رقم الهاتف المحمول'
      tech_name = 'GS_DATA-MANAGER_MOBILE_NUMBER' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 160
      field_name = 'MANAGER_EMAIL_ADDRESS_1' ftype = 'READONLY' readonly = 'X'
      zsection = 'Managment'
      zlabel = 'E-mail' zlabel_ar = 'البريد الإلكتروني'
      tech_name = 'GS_DATA-MANAGER_EMAIL_ADDRESS' )

*   --- New Location: the five fields the citizen actually fills in, and
*   the entire purpose of the journey.
*
*   REVIEW-TEXT: "New Location" is a SUPPLIED caption, not a migrated one.
*   The legacy container is called CHANGE_DATA and carries no heading
*   LABEL row at all, so these five would otherwise sit visually merged
*   into the read-only Managment block above them - on a form whose whole
*   point is telling the two apart. There is no Arabic for it for the same
*   reason. Add the heading to the legacy screen (or approve an Arabic
*   translation here) and this becomes a migrated caption like the rest.
*
*   REVIEW-BE: each of these five shares its technical name with a
*   disabled "current value" control on the legacy screen, and both carry
*   TOSAVE. Only the editable one is authored. The reason is worth stating
*   precisely, because the obvious reason is not the real one.
*
*   The obvious objection is a double post: the CJS post layer sends every
*   field that has a tech_name, READONLY included, so a pair would write
*   the same backend member twice. That is true but survivable - the later
*   field in step order wins, and the editable one sits after the display
*   one here.
*
*   The real problem is the READ. The engine asks the read BAdI for each
*   field by name WITH its tech name, so a pair bound to one member comes
*   back with BOTH halves carrying the current value - which means the
*   "New Location" inputs would arrive PRE-FILLED with the school's
*   existing address, parcel id, telephone, location and PO box. On a
*   change-of-location application that is the worst possible default: the
*   citizen can press Next through a pre-filled form and submit a request
*   to move the school to where it already is, and nothing anywhere would
*   flag it. Blank inputs make the applicant state the new location.
*
*   The cost of dropping the display half is that the citizen no longer
*   sees the current values beside the new ones. Getting that back
*   properly needs the DOKSL read to expose five SEPARATE read-only
*   members (a GS_DATA-SCHOOL_CURRENT-* group, or similar) - and so does a
*   "the new location must differ from the current one" check, which is
*   why ZCL_D009_SCHOOL_LOCA_CHG_LOGIC has no such validation rather than
*   a comparison against a field that cannot hold the old value.
*
*   None of the five carries MAND on the legacy screen, so none is
*   REQUIRED here.
*   REVIEW-FE: on a change-of-location application that is surprising -
*   submitting all five blank would post a request that changes nothing.
*   If DOK expects at least the address and location to be mandatory, that
*   is a MAND change on the legacy screen and these REQUIRED flags follow
*   it; a cross-field "at least one changed" rule needs a handler check,
*   which the config has no expression for.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 170
      field_name = 'ADRESS_1' ftype = 'INPUT'
      zsection = 'New Location'
      zlabel = 'School Adress' zlabel_ar = 'عنوان المدرسة'
      tech_name = 'GS_DATA-SCHOOL-ADRESS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 180
      field_name = 'LOCATION_1' ftype = 'SELECT'
      zsection = 'New Location'
      zlabel = 'Location' zlabel_ar = 'الموقع'
      placeholder = 'Select' shlp = 'ZSH_CJ_LOCATION_ID'
      tech_name = 'GS_DATA-SCHOOL-LOCATION' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 190
      field_name = 'PARCEL_ID_1' ftype = 'INPUT'
      zsection = 'New Location'
      zlabel = 'Parcel ID' zlabel_ar = 'رقم الطرد'
      tech_name = 'GS_DATA-SCHOOL-PARCEL_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 200
      field_name = 'TELEPHONE_1' ftype = 'PHONE'
      zsection = 'New Location'
      zlabel = 'Telephone Number' zlabel_ar = 'رقم الهاتف'
      tech_name = 'GS_DATA-SCHOOL-TELEPHONE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 210
      field_name = 'POBOX_1' ftype = 'INPUT'
      zsection = 'New Location'
      zlabel = 'PO Box No' zlabel_ar = 'رقم صندوق البريد'
      tech_name = 'GS_DATA-SCHOOL-POBOX' ) ) ).

* --------------------------------------------------- STP3 fields
* Twelve required certificates plus an optional supporting bucket - the
* document set that identifies this journey as a premises move rather than
* anything else.
*
* ATTACH_MAXMB = 3 across the step, from this screen's own notice
* ("Each file maximum allowed size - 3MB") rather than the framework
* default.
*
* TECH_NAME on an upload is the legacy document code (DATA2), which is
* what the attachment pipeline files against - not the control name. All
* thirteen codes here are distinct (DL D9 EL RB D3 D2 D4 11 DK DO DH EI P6),
* so unlike the E014 family this journey has no shared-bucket collision to
* flag.
*
* Field names are shortened from the legacy control names, which run to 48
* characters (RAK_MUNCIAPLITY_BUILDING_SUITABILITY_CERTIFICATE) and would
* not fit ZRAK_JOURNEY_FIELD. The legacy names are recoverable from the
* document code, which is what the backend keys on.
*
* Order follows the legacy SEQUENCE, which reads down COL1 and then COL2 -
* the two-column layout is a rendering choice the CJS engine makes for
* itself from the section, so the columns are not reproduced as structure.
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
* the legacy screen filled at runtime with the declaring owner's name.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = 'Each file maximum allowed size - 3MB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'FLOOR_PLAN_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Ministry Approved Floor Plan' zlabel_ar = 'مخطط الطابق المعتمد من الوزارة'
      has_attach = 'X' attach_label = 'Upload Ministry Approved Floor Plan'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'DL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'FACILITIES_FORM_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Facilities form' zlabel_ar = 'استمارة المرافق'
      has_attach = 'X' attach_label = 'Upload Facilities form'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'D9' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'DOCTOR_NURSE_LIC_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Doctor & Nurse License / An external clinic agreement'
      zlabel_ar = 'رخصة الطبيب والممرضة / اتفاقية العيادة الخارجية'
      has_attach = 'X' attach_label = 'Upload Doctor & Nurse License'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'EL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'LEASE_CONTRACT_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Lease Contract / Title Deed' zlabel_ar = 'عقد الإيجار / سند الملكية'
      has_attach = 'X' attach_label = 'Upload Lease Contract / Title Deed'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'RB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 60
      field_name = 'CIVIL_DEFENSE_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Civil Defense clearance certificate' zlabel_ar = 'شهادة براءة ذمة من الدفاع المدني'
      has_attach = 'X' attach_label = 'Upload Civil Defense clearance certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'D3' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 70
      field_name = 'BUILDING_SUITABILITY_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'RAK Munciaplity- Building Suitability Certificate'
      zlabel_ar = 'بلدية رأس الخيمة- شهادة صلاحية البناء'
      has_attach = 'X' attach_label = 'Upload Building Suitability Certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'D2' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 80
      field_name = 'SCHOOL_CLINIC_LIC_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'School Clinic License' zlabel_ar = 'رخصة العيادة المدرسية'
      has_attach = 'X' attach_label = 'Upload School Clinic License'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'D4' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 90
      field_name = 'TRADE_LICENSE_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Trade License' zlabel_ar = 'الرخصة التجارية'
      has_attach = 'X' attach_label = 'Upload Trade License'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = '11' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 100
      field_name = 'ARCHITECTURAL_MAP_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Architectural map' zlabel_ar = 'الخريطة المعمارية'
      has_attach = 'X' attach_label = 'Upload Architectural map'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'DK' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 110
      field_name = 'PROJECT_TIME_PLAN_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Project Time Plan' zlabel_ar = 'الخطة الزمنية للمشروع'
      has_attach = 'X' attach_label = 'Upload Project Time Plan'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'DO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 120
      field_name = 'PARENT_NOTIFICATION_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Parent''s Notification Plan' zlabel_ar = 'خطة إخطار الوالدين'
      has_attach = 'X' attach_label = 'Upload Parent''s Notification Plan'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'DH' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 130
      field_name = 'GRA_READINESS_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'General Resource Authority Readiness Certificate (GRA)'
      zlabel_ar = 'شهادة جاهزية هيئة الموارد العامة'
      has_attach = 'X' attach_label = 'Upload GRA Readiness Certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'EI' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 140
      field_name = 'OTHERS_UPL' ftype = 'UPLOAD'
      zsection = 'Required Documents'
      zlabel = 'Others or Supporting' zlabel_ar = 'اخرى'
      has_attach = 'X' attach_label = 'Upload Others or Supporting'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3 attach_multi = 'X'
      tech_name = 'P6' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 150
      field_name = 'DECLARATION_L1' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'as the company owner, hereby declare that all information provided in ' &&
                    'this application and in attached documents are true and accurate and ' &&
                    'in compliance with the law' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 160
      field_name = 'DECLARATION_L2' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'And I will be abide by all relevant regular conditions, instructions ' &&
                    'and guidelines to avoid legal action in case of violations' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 170
      field_name = 'DISCLAIMER_TXT' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'Note: Once you submit, you can''t cancel the application.' ) ) ).

* ------------------------------------------------------- grid columns
* Two grids on this journey, so two column sets.
*
* Legacy CTRL is LABEL on every column - both legacy grids were
* display-only - but CTRL here takes a control type, not a rendering hint,
* so validity dates are declared DATE and identifiers and names INPUT so
* the grid formats them the way the citizen expects. READONLY on every
* column keeps the display-only behaviour regardless: the CTRL value
* decides formatting, not editability.
*
* COL_NAME is the legacy column name, which is what the backend table
* actually returns.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
*   STP1 - the licence picker (LSEQ 1..4)
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'LICENCE' seqnr = 10 ctrl = 'INPUT' readonly = 'X'
      width = '25%' align = 'Begin'
      zlabel = 'License' zlabel_ar = 'رقم الرخصة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'SCHOOL_NAME' seqnr = 20 ctrl = 'INPUT' readonly = 'X'
      width = '35%' align = 'Begin'
      zlabel = 'School name' zlabel_ar = 'اسم المدرسة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'ISSUED_AT' seqnr = 30 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Issued at' zlabel_ar = 'تاريخ الإصدار' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'EXPIRED_AT' seqnr = 40 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Expired at' zlabel_ar = 'انتهت صلاحيتها في' )

*   STP2 - the current owners list (LSEQ 1..5). Legacy column names are
*   NAME_1 / NATIONALITY_1 / SHARE_PER_1 / MOBILE_NUMBER_1 /
*   EMAIL_ADDRESS_1 and are kept exactly, suffix included: renaming them
*   to read nicer would simply blank the column.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'OWNERS'
      col_name = 'NAME_1' seqnr = 10 ctrl = 'INPUT' readonly = 'X'
      width = '28%' align = 'Begin'
      zlabel = 'Name' zlabel_ar = 'الاسم' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'OWNERS'
      col_name = 'NATIONALITY_1' seqnr = 20 ctrl = 'INPUT' readonly = 'X'
      width = '17%' align = 'Begin'
      zlabel = 'Nationality' zlabel_ar = 'الجنسية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'OWNERS'
      col_name = 'SHARE_PER_1' seqnr = 30 ctrl = 'NUMBER' readonly = 'X'
      width = '10%' align = 'End' decimals = 2
      zlabel = 'Shares' zlabel_ar = 'نسبة الشراكة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'OWNERS'
      col_name = 'MOBILE_NUMBER_1' seqnr = 40 ctrl = 'INPUT' readonly = 'X'
      width = '20%' align = 'Begin'
      zlabel = 'Mobile number' zlabel_ar = 'رقم الهاتف المتحرك' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'OWNERS'
      col_name = 'EMAIL_ADDRESS_1' seqnr = 50 ctrl = 'INPUT' readonly = 'X'
      width = '25%' align = 'Begin'
      zlabel = 'E-mail' zlabel_ar = 'البريد الإلكتروني' ) ) ).

* ---------------------------------------------------------------- rules
* NONE, and deliberately so. The export carries no UI_FIELD_LOGICS row on
* any ND009_1_* screen - not one show, hide or enable expression - and no
* DATA4/DATA5 conditional pair either, so there is nothing to translate.
* The DELETE at the top still covers ZRAK_T_JNY_RULE so a rule added by
* hand is cleared on the next run.

* -------------------------------------------------------------- options
* NONE. This journey has no TBUTTON group and no segmented field: its
* applicant type is a disabled COMBOBOX filled from the session, not a
* choice the citizen makes, so there is no option list to seed.

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Changing the school''s Location'.
  WRITE: / '  3 steps (legacy ND009_1_1..1_3; _1_4 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Select License        1 field  (licence grid, 4 columns, read-only)'.
  WRITE: / '  STP2 School & New Location 21 fields, 4 sections (owners grid, 5 columns)'.
  WRITE: / '  STP3 Documents            17 fields, 13 uploads'.
  WRITE: / '  0 rules, 0 options, 9 grid columns across 2 grids'.
  WRITE: / '  CATEGORY is DOKSL, not EPDA - the BAdI filters key off it.'.
  WRITE: / '  No payment step - confirmed absent from the export, not omitted.'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-BE    the 5 New Location fields each SHARE a technical name with a'.
  WRITE: / '              disabled "current value" control on the legacy screen, and'.
  WRITE: / '              both carry TOSAVE. Only the editable half is migrated, so the'.
  WRITE: / '              citizen no longer sees the current values beside the new'.
  WRITE: / '              ones. Fixing that properly needs 5 separate read-only'.
  WRITE: / '              members from the DOKSL read - and so does any'.
  WRITE: / '              "must differ from current" validation.'.
  WRITE: / ' REVIEW-BE    the legacy "Applicant name" and "Emirates id Number" rows'.
  WRITE: / '              have NO binding in the export and are not authored. This'.
  WRITE: / '              journey''s only applicant member is GS_DATA-PARTNER, a bare'.
  WRITE: / '              BP number. Expose name/ID in the DOKSL read to show them.'.
  WRITE: / ' REVIEW-TEXT  "New Location" is a SUPPLIED section heading - the legacy'.
  WRITE: / '              CHANGE_DATA container has none - and has no Arabic.'.
  WRITE: / ' REVIEW-TEXT  CTX3_D_VALUE is captioned "Issued" but bound to'.
  WRITE: / '              GS_DATA-LICENCE_NAME, a name and not a date. Legacy pair'.
  WRITE: / '              carried as-is; confirm which end is wrong.'.
  WRITE: / ' REVIEW-FE    none of the 5 New Location fields carries MAND, so a blank'.
  WRITE: / '              application posts a change of nothing. Confirm that is'.
  WRITE: / '              intended, or set MAND on the legacy screen.'.
  WRITE: / ' REVIEW-TEXT  the "Managment" section keeps the legacy misspelling, which'.
  WRITE: / '              is the heading in production today.'.
  WRITE: / ' REVIEW-TEXT  DECLARATION_LONG1 is truncated in the export extract; its'.
  WRITE: / '              tail was completed from the identical E014 caption.'.
  WRITE: / ' REVIEW-F4    every SELECT resolves through SHLP; run ZRAK_CJS_XCHECK to'.
  WRITE: / '              confirm each search help returns options in this client.'.
