REPORT zrak_e027_load.

*&---------------------------------------------------------------------*
*& E027 - Sailing of a Vice Captain  (legacy NE027_1_1..1_5)
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
*& TITLE: the legacy screens disagree with themselves. NE027_1_1's
*& TITLE_TEXT resolves to "Vice Captain" and screens _1_2 through _1_5 to
*& "Sailing of a Vice Captain". The longer caption is used because four
*& screens carry it against one, and because it is the one that names the
*& service rather than the role.
*&
*& STRUCTURE - 4 steps, not the 5 legacy screens:
*&   STP1  NE027_1_1  Select License
*&   STP2  NE027_1_2  Applicant
*&   STP3  NE027_1_3  NOC & Vice Captain
*&   STP4  NE027_1_4  Documents & Declaration
*&   (NE027_1_5 is "Your Request was submitted!" + the happiness meter -
*&    the engine appends its own confirmation and feedback step after
*&    submit, so migrating that screen would show it twice.)
*&
*& NO PAYMENT STEP. Verified against the export: there is no RAKPAY, no
*& RAKREMAININGFEES and no fee CLIST anywhere in NE027_1_*, and the NEXT
*& button on the last screen carries D3 = SUBMIT, not a pay event. So
*& STP4 is a documents step, there is no PAYFEE field and no
*& NEXT_REQUIRES.
*&
*& THREE separate business-partner lookups, confirmed from
*& PARENT_CONTAINER rather than assumed to be one reused control:
*&   STP1  OWNER_ID_1  GS_DATA-OWNER_ID           standalone in VBOX_5
*&   STP2  OWNER_1     GS_DATA-REPRESENT_ID       inside OWNER_FINDER
*&   STP3  OWNER_ID_2  GS_DATA-CAPTAIN-OWNER_ID   inside CAPTAIN_FINDER
*& Three different backend fields, so three different people: the boat
*& owner, the representative applying on the owner's behalf, and the
*& vice-captain nominee.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'E027'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'E027'.

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
* button on NE027_1_* carries DATA1 = ZFM_EGA_CJ_FW_POST_N and
* DATA2 = ZFM_EGA_CJ_FW_READ_N under CATEGORY 'EPDA'. The backend class
* the screens name is ZCL_EGA_CJ_ENH_IMPL_E027 - its OWN class, not the
* shared ZCL_EGA_CJ_CONSULTANT_ABS the E014 family uses, which is another
* sign this screen number belongs to one flow only.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Sailing of a Vice Captain'
    title_ar      = 'إبحار نائب القبطان'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_E027_VICE_CAPTAIN_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E027'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* No NEXT_REQUIRES on any step: the only legacy gate of that kind is a
* payment, and there is none here. STP4's footer offers Submit directly.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Select License' title_ar = 'اختيار الرخصة'
      icon = 'sap-icon://table-view' bknd_screen = 'NE027_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Applicant' title_ar = 'مقدم الطلب'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'NE027_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Vice Captain' title_ar = 'نائب القبطان'
      icon = 'sap-icon://employee' bknd_screen = 'NE027_1_3' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE027_1_4' active = 'X' ) ) ).

* --------------------------------------------------- STP1 fields
* The licence the vice-captain will sail under, reachable two ways on the
* legacy screen: pick it out of the grid, or search for it. Both are
* migrated because the export carries both and they are not
* interchangeable - the grid lists what this citizen already holds, the
* search reaches a licence held by somebody else.
*
* LICENSES is READONLY because the row is PICKED, not typed - the
* licences come from the backend (D1 = ZFM_EGA_CJ_FW_READ_TABLE_DATAN,
* D2 = LICENSES) and an editable grid would let a citizen retype an
* expiry date and sail under a licence that does not exist. The legacy
* MTABLE declares D3 = SingleSelectLeft: exactly one licence per
* application, selected by a leading radio column.
*
* Legacy MTABLE_SEARCH_1 (a search box over the grid, D1 = LICENSES) is
* not migrated as a field: the engine's own grid renders its filter, so a
* configured search control would draw a second box that filters nothing.
*
* ZSECTION is blank on the grid because NE027_1_1 has no section LABEL row
* above it; the three lookup rows below sit under the legacy "Owner"
* heading.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'LICENSES' ftype = 'EDITABLE_TABLE' readonly = 'X'
      zlabel = 'Vice Captain' zlabel_ar = 'نائب نوخذة'
      tech_name = 'GS_DATA-LICENSES[]' )

*   REVIEW-F4: TYPE_1 is a COMBOBOX with NO search help, no CLIST and no
*   value list anywhere in the export - the legacy screen filled its
*   options from ZCL_EGA_CJ_ENH_IMPL_E027 at runtime. It is authored as a
*   SELECT so the control is right, but it will render EMPTY until either
*   a search help is supplied here or the handler redefines
*   on_value_help. It also has no caption of its own in the export, so
*   ZLABEL is the container's heading.
*   REVIEW-FE: its UI_FIELD_LOGICS lists LICENSE_TABLE and LICENSE_SEARCH
*   as BARE tokens - no -V-T / -V-F suffix - and neither target carries a
*   DATA4/DATA5 pair to say WHICH value shows which. So the legacy intent
*   (probably: own licence -> the grid, someone else's -> the search) is
*   real but its trigger value is not recoverable from this export. Both
*   are therefore authored always-visible rather than guessed into a rule
*   that would hide one of them at the wrong time. Once the TYPE_1 option
*   keys are known, add two SHOW rules and author the two targets HIDDEN.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'TYPE_1' ftype = 'SELECT'
      zlabel = 'Owner' zlabel_ar = 'المالك'
      placeholder = 'Select'
      tech_name = 'GS_DATA-EXECUTIVE-TYPE' )

*   REVIEW-BE: legacy DATA1 = 'BOAT_LICENSE' names the search kind the
*   legacy finder called. on_search is not wired, so SEARCH renders but a
*   press returns nothing - same open item as the other two lookups on
*   this journey and as E014/E015. One BP/licence-search API, one place to
*   wire it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'LICENCE_NO_1' ftype = 'SEARCH'
      zlabel = 'Fisherman License' zlabel_ar = 'رقم رخصة الصيد'
      placeholder = 'Fisherman License'
      tech_name = 'GS_DATA-LICENCE_NO' )

*   The boat owner. Standalone in VBOX_5 with the legacy "Owner" heading
*   above it - NOT inside an OWNER_FINDER container, so no applicant-type
*   toggle governs it and it is authored plainly visible.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 40
      field_name = 'OWNER_ID_1' ftype = 'SEARCH'
      zsection = 'Owner'
      zlabel = 'Owner' zlabel_ar = 'المالك'
      tech_name = 'GS_DATA-OWNER_ID' ) ) ).

* --------------------------------------------------- STP2 fields
* ZSECTION carries the legacy section headings, VALUE-resolved:
* "Applicant Details" / "Owner details".
*
* The four applicant fields are READONLY because on the legacy screen
* they are LABELs bound to GS_DATA-PARTNER_* - the portal session fills
* them, the citizen never types them.
*
* Three rows from the legacy card header are carried as READONLY context
* rather than dropped, because they are what tell the citizen WHICH
* licence this application is against. They have no ZSECTION because the
* legacy header strip has no heading row.
*
* ERROR_1 (MESSAGE_STRIP on GS_DATA-ERROR) is not migrated: the engine
* renders backend and validation messages in its own message area, so a
* configured strip would duplicate it.
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
*   TWO legacy TBUTTONs, not three: this screen's DATA1 group is
*   PARTNER_OWNER_1,PARTNER_REP_1 - Owner / Representative - the same
*   two-way group E015 has and NOT E014's three-way Owner / PRO /
*   Manager. Confirmed from the real DATA1 group membership.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED'
      zsection = 'Applicant Details'
      zlabel = 'Applicant Type' zlabel_ar = 'نوع المقدم'
      tech_name = 'GS_DATA-PARTNER_OWNER' )

*   HIDDEN by default and revealed by R001 below, from the legacy
*   UI_FIELD_LOGICS: OWNER_FINDER-V-F on the Owner button,
*   OWNER_FINDER-V-T on Representative - the lookup appears only when
*   somebody applies ON BEHALF of the owner, never when the owner applies
*   personally.
*
*   NOTE the binding: GS_DATA-REPRESENT_ID, not GS_DATA-OWNER. Despite
*   the container being called OWNER_FINDER and the caption reading
*   "Owner details", this field identifies the REPRESENTATIVE - which is
*   consistent with it only appearing when a representative applies. The
*   legacy caption is carried as-is; the binding is what decides who the
*   backend records.
*   REVIEW-TEXT: if that caption confuses reviewers, "Representative
*   details" is the honest one - but changing it means diverging from the
*   legacy dictionary, so it is left alone here and flagged instead.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 90
      field_name = 'OWNER_1' ftype = 'SEARCH' hidden = 'X'
      zsection = 'Owner details'
      zlabel = 'Owner details' zlabel_ar = 'بيانات المالك'
      tech_name = 'GS_DATA-REPRESENT_ID' ) ) ).

* --------------------------------------------------- STP3 fields
* ZSECTION carries the legacy headings, VALUE-resolved: "NOC Details" and
* "Vice Captain Details".
*
* BOAT_SELECT is the one search help on this journey with a NON-default
* key/value pair: SH_EL_KEY = BOAT_ID, SH_EL_VALUE = BOAT_NAME, where
* every other lookup here uses KEY/VALUE. The pair is not carried in
* ZRAK_T_JNY_FLD - the table has SHLP but no key/value override columns -
* so the engine's F4 resolver has to find them itself.
* REVIEW-F4: run ZRAK_CJS_XCHECK on ZSH_CJ_EPDA_LICENSE_2_BOAT and
* confirm the resolver picks BOAT_ID / BOAT_NAME. If it defaults to
* KEY/VALUE, this dropdown comes back empty and the fix belongs in the
* resolver or in a handler on_value_help, not here.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'BOAT_SELECT' ftype = 'SELECT' required = 'X'
      zsection = 'NOC Details'
      zlabel = 'Boat Number' zlabel_ar = 'رقم القارب'
      placeholder = 'Select' shlp = 'ZSH_CJ_EPDA_LICENSE_2_BOAT'
      msg = 'The boat number is required'
      tech_name = 'GS_DATA-BOAT_DETAILS-BOAT_ID' )
*   The licence number again, shown beside the boat so the citizen can see
*   the two together.
*
*   THREE fields on this journey are bound to GS_DATA-LICENCE_NO -
*   LICENCE_NO_1 (STP1, the search the citizen fills), CTX1_D_VALUE (STP2)
*   and this one - which needs saying out loud because the CJS post layer
*   sends EVERY field that has a tech_name, READONLY included, and the
*   last one in step order wins. That is harmless here, but not for the
*   reason it first appears: it is not that readonly fields do not post
*   (they do), it is that all three are filled from the same read. The
*   engine asks the read BAdI for each field by name WITH its tech name,
*   so all three come back carrying the identical value, and the duplicate
*   writes are idempotent.
*
*   REVIEW-BE: that idempotence is a property of the read, not a
*   guarantee. If the read ever answers one of the three and not the
*   others, the blank one is what posts - so if a licence number starts
*   arriving empty at the backend, this is the first place to look, and
*   the fix is to leave only LICENCE_NO_1 bound and drop tech_name from
*   the two displays.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'LICENSE' ftype = 'READONLY' readonly = 'X'
      zsection = 'NOC Details'
      zlabel = 'License Number' zlabel_ar = 'رقم الرخصة'
      tech_name = 'GS_DATA-LICENCE_NO' )

*   The vice-captain nominee. MAND on the legacy control itself, so
*   REQUIRED here. Inside CAPTAIN_FINDER, whose only live child this is -
*   there is nothing else in that container to show or hide, which is why
*   no rule governs it.
*   REVIEW-BE: on_search not wired; see the note on STP1.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'OWNER_ID_2' ftype = 'SEARCH' required = 'X'
      zsection = 'Vice Captain Details'
      zlabel = 'Vice Captain' zlabel_ar = 'نائب القبطان'
      msg = 'The vice captain must be identified'
      tech_name = 'GS_DATA-CAPTAIN-OWNER_ID' )
*   MAX_LEN = 100 is the legacy control's own DATA3 value, not a framework
*   default - the legacy INPUT declares 100 and the backend field is sized
*   for it, so a longer text would be silently truncated on post rather
*   than refused here.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'RELATIONSHIP_1' ftype = 'INPUT' required = 'X'
      zsection = 'Vice Captain Details'
      zlabel = 'Relationship with Owner' zlabel_ar = 'العلاقة مع المالك'
      max_len = 100
      msg = 'The relationship with the owner is required (100 characters maximum)'
      tech_name = 'GS_DATA-CAPTAIN-RELATIONSHIP' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'MOBILE_NO_1' ftype = 'PHONE' required = 'X'
      zsection = 'Vice Captain Details'
      zlabel = 'Mobile Number 1' zlabel_ar = 'رقم الجوال 1'
      msg = 'A contact number is required'
      tech_name = 'GS_DATA-CAPTAIN-RELAT_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 60
      field_name = 'EMAIL_ID_1' ftype = 'EMAIL'
      zsection = 'Vice Captain Details'
      zlabel = 'E-mail ID' zlabel_ar = 'البريد الالكتروني'
      regex = '.+@.+\..+' msg = 'Valid email required'
      tech_name = 'GS_DATA-CAPTAIN-RELAT_EMAIL' ) ) ).

* --------------------------------------------------- STP4 fields
* ATTACH_MAXMB = 3 across the step, from this screen's own notice
* ("Each file maximum allowed size - 3MB") rather than the framework
* default.
*
* TECH_NAME on an upload is the legacy document code (DATA2), which is
* what the attachment pipeline files against - not the control name. All
* four codes here are distinct (6P / FV / FY / P6), so unlike the E014
* family this journey has no shared-bucket collision to flag.
*
* The three certificates carry MAND on their legacy label rows, so they
* are REQUIRED; "Others or Supporting" does not and is optional, and
* multi-file because supporting evidence is rarely one document.
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
* REVIEW-TEXT: on THIS journey that wording is doubly odd - the applicant
* is a boat owner, not a company owner. The legacy text is carried as-is
* rather than reworded, but it is worth EPDA's attention.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = 'Each file maximum allowed size - 3MB' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 20
      field_name = 'POLICE_CLEARANCE_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Police Clearance Certificate' zlabel_ar = 'شهادة الحالة الجنائية'
      has_attach = 'X' attach_label = 'Upload Police Clearance Certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = '6P' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 30
      field_name = 'MEDICAL_FITNESS_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Medical Fitness Certificate' zlabel_ar = 'شهادة اللياقة الطبية'
      has_attach = 'X' attach_label = 'Upload Medical Fitness Certificate'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'FV' )
*   The legacy caption names two alternatives ("Boat Driving License /
*   Previous Vice Captain or Captain card") under ONE document code, which
*   is deliberate on the legacy side: either document satisfies the
*   requirement. Carried as one upload, as exported.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      field_name = 'BOAT_DRIVING_LIC_UPL' ftype = 'UPLOAD' required = 'X'
      zsection = 'Required Documents'
      zlabel = 'Boat Driving License / Previous Vice Captain or Captain card'
      zlabel_ar = 'رخصة قيادة القارب / بطاقة نائب القبطان أو القبطان السابق'
      has_attach = 'X' attach_label = 'Upload Boat Driving License'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3
      tech_name = 'FY' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 50
      field_name = 'OTHERS_UPL' ftype = 'UPLOAD'
      zsection = 'Required Documents'
      zlabel = 'Others or Supporting' zlabel_ar = 'اخرى'
      has_attach = 'X' attach_label = 'Upload Others or Supporting'
      attach_types = 'pdf,jpg,png' attach_maxmb = 3 attach_multi = 'X'
      tech_name = 'P6' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 60
      field_name = 'DECLARATION_L1' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'as the company owner, hereby declare that all information provided in ' &&
                    'this application and in attached documents are true and accurate and ' &&
                    'in compliance with the law' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 70
      field_name = 'DECLARATION_L2' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'And I will be abide by all relevant regular conditions, instructions ' &&
                    'and guidelines to avoid legal action in case of violations' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 80
      field_name = 'DISCLAIMER_TXT' ftype = 'DISPLAY' zsection = 'Declaration'
      default_val = 'Note: Once you submit, you can''t cancel the application.' ) ) ).

* ------------------------------------------------------- grid columns
* The four LEVEL_CON=T columns under the legacy LICENSES table, in LSEQ
* order, with their own resolved captions.
*
* Legacy CTRL is LABEL on all four - the legacy grid was display-only -
* but CTRL here takes a control type, not a rendering hint, so the two
* validity dates are declared DATE and the identifier and port name INPUT
* so the grid formats them the way the citizen expects. READONLY on every
* column keeps the display-only behaviour regardless: the CTRL value
* decides formatting, not editability.
*
* COL_NAME is the legacy column name, which is what the backend table
* actually returns.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'LICENCE' seqnr = 10 ctrl = 'INPUT' readonly = 'X'
      width = '30%' align = 'Begin'
      zlabel = 'License' zlabel_ar = 'رقم الرخصة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'ISSUED_AT' seqnr = 20 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Issued at' zlabel_ar = 'تاريخ الإصدار' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'EXPIRED_AT' seqnr = 30 ctrl = 'DATE' readonly = 'X'
      width = '20%' align = 'Center'
      zlabel = 'Expired at' zlabel_ar = 'انتهت صلاحيتها في' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'LICENSES'
      col_name = 'PORT_NAME' seqnr = 40 ctrl = 'INPUT' readonly = 'X'
      width = '30%' align = 'Begin'
      zlabel = 'Port Name' zlabel_ar = 'الميناء' ) ) ).

* ---------------------------------------------------------------- rules
* One rule, and it is the OWNER_FINDER toggle - straight from the legacy
* UI_FIELD_LOGICS: OWNER_FINDER-V-T on PARTNER_REP_1. One SHOW rule and
* no HIDE rule, because the field is authored HIDDEN - "not shown" is its
* resting state, and a third applicant type added later cannot
* accidentally leave the finder on screen.
*
* The other logic row on this journey - TYPE_1's LICENSE_TABLE /
* LICENSE_SEARCH pair on STP1 - is NOT translated, because its trigger
* value is not recoverable from this export. See the REVIEW-FE note on
* TYPE_1 above.
  INSERT zrak_t_jny_rule FROM @( VALUE #(
    mandt = sy-mandt journey_id = c_jny rule_id = 'R001'
    src_field = 'PARTNER_OWNER_1' src_op = 'EQ' src_value = 'PARTNER_REP_1'
    action = 'SHOW' tgt_field = 'OWNER_1' ) ).

* -------------------------------------------------------------- options
* The segmented group's TWO members - Owner and Representative. OPT_KEY is
* the legacy field name of each button, which is what the handler's role
* fan-out writes back to GS_DATA-PARTNER_OWNER / GS_DATA-PARTNER_REP.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_OWNER_1' seqnr = 10
      opt_text = 'Owner' opt_text_ar = 'المالك' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'PARTNER_OWNER_1' opt_key = 'PARTNER_REP_1' seqnr = 20
      opt_text = 'Representative' opt_text_ar = 'الوكيل' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'Seeded journey', c_jny, '- Sailing of a Vice Captain'.
  WRITE: / '  4 steps (legacy NE027_1_1..1_4; _1_5 is the engine''s own confirmation)'.
  WRITE: / '  STP1 Select License        4 fields (licence grid, 4 columns, read-only)'.
  WRITE: / '  STP2 Applicant             9 fields, 2 sections'.
  WRITE: / '  STP3 Vice Captain          6 fields, 2 sections'.
  WRITE: / '  STP4 Documents             8 fields, 4 uploads'.
  WRITE: / '  1 rule, 2 segmented options, 4 grid columns'.
  WRITE: / '  No payment step - confirmed absent from the export, not omitted.'.
  WRITE: /.
  WRITE: / 'Open REVIEW items (also flagged in the source):'.
  WRITE: / ' REVIEW-F4    TYPE_1 (STP1) has NO search help and no value list anywhere'.
  WRITE: / '              in the export - the legacy screen filled it from'.
  WRITE: / '              ZCL_EGA_CJ_ENH_IMPL_E027 at runtime. It renders EMPTY until'.
  WRITE: / '              a SHLP is supplied or the handler adds on_value_help.'.
  WRITE: / ' REVIEW-FE    TYPE_1''s LICENSE_TABLE / LICENSE_SEARCH logic uses BARE'.
  WRITE: / '              tokens with no DATA4/DATA5 on either target, so the trigger'.
  WRITE: / '              value is unknown. Both targets are authored visible rather'.
  WRITE: / '              than guessed into a rule.'.
  WRITE: / ' REVIEW-F4    ZSH_CJ_EPDA_LICENSE_2_BOAT declares key BOAT_ID / value'.
  WRITE: / '              BOAT_NAME, not the usual KEY/VALUE. ZRAK_T_JNY_FLD cannot'.
  WRITE: / '              carry that override - confirm the F4 resolver finds them.'.
  WRITE: / ' REVIEW-BE    3 live lookups (OWNER_ID_1, OWNER_1, OWNER_ID_2) render but'.
  WRITE: / '              return nothing - ZCL_E027_VICE_CAPTAIN_LOGIC does not'.
  WRITE: / '              redefine on_search yet. Legacy search kind on LICENCE_NO_1'.
  WRITE: / '              is BOAT_LICENSE.'.
  WRITE: / ' REVIEW-TEXT  OWNER_1 is captioned "Owner details" but bound to'.
  WRITE: / '              GS_DATA-REPRESENT_ID - it identifies the REPRESENTATIVE.'.
  WRITE: / '              Legacy caption carried as-is.'.
  WRITE: / ' REVIEW-TEXT  the declaration says "as the company owner" on a journey'.
  WRITE: / '              whose applicant is a boat owner. Legacy text carried as-is.'.
  WRITE: / ' REVIEW-TEXT  DECLARATION_LONG1 is truncated in the export extract; its'.
  WRITE: / '              tail was completed from the identical E014 caption.'.
  WRITE: / ' REVIEW-F4    every SELECT resolves through SHLP; run ZRAK_CJS_XCHECK to'.
  WRITE: / '              confirm each search help returns options in this client.'.
