*&---------------------------------------------------------------------*
*& E019 - Transport Used Oil   (legacy EPDA / NE019_1_1 .. NE019_1_6)
*&
*& THERE WAS NO FEEDER FOR THIS JOURNEY, and that is the defect behind
*& "the migration did not happen properly". E019..E022 were produced by
*& a run of ZCL_RAK_MIGRATOR, so their configuration existed only as
*& rows in the SAP tables: nothing in git held it, no diff could review
*& it, and a reseed lost it. ZRAK_CJ_FIXPACK patching E021/E022 step
*& titles after the fact is that same gap showing.
*&
*& Written from the real /QNV/SB_UI_DEFIN export for CATEGORY 'EPDA',
*& screens NE019_1_1..NE019_1_6, cross-checked field by field against
*& the department's own screenshots.
*&
*& ---- STRUCTURE: 5 steps, not the 6 legacy screens -------------------
*&   STP1  NE019_1_1  Applicant
*&   STP2  NE019_1_2  Company        (transporter)
*&   STP3  NE019_1_3  Materials      (vehicles + materials grids)
*&   STP4  NE019_1_4  Receiving Company
*&   STP5  NE019_1_5  Documents      - SUBMIT lives here
*&   (NE019_1_6 is "Your Request was submitted!" plus the happiness
*&    meter. The engine appends its own confirmation and feedback step
*&    after submit, so migrating that screen would show it twice - the
*&    same call E014/E015/E027 already made.)
*&
*& NO PAYMENT STEP, deliberately. NE019_1_6 carries the CPG item set
*& (AMOUNT, MERCHANTID, SECRETKEY, PAYCHANNEL, REDIRECTURL...) but every
*& one of those rows is NOT_UI, and the impl class's only call into
*& GET_CPG_DETAILS_OLD( ) is commented out at its call site. The stage
*& bar names six stages ending "Confirmation", never a fee. So this
*& service does not charge, no PAYFEE field is seeded, and no step
*& carries NEXT_REQUIRES = 'PAYFEE'.
*&
*& ---- WORDING IS READ, NEVER TYPED ----------------------------------
*& Every caption comes from /QNV/SB_LABELT through LCL_TXT below, keyed
*& on the code the export already carries, one row per SPRAS. Two things
*& make that non-obvious in this export and both cost a re-read:
*&
*&   - the caption code sits in a DIFFERENT COLUMN depending on the
*&     control. For a LABEL row it is in VALUE; for a TBUTTON, a table
*&     column or an uploader it is in LABEL_CON. That is the legacy's
*&     own inconsistency, not a reading error.
*&   - a few captions are LITERAL TEXT rather than a code - LABEL_13 on
*&     screen _1_1 is the word "Permit number", LABEL_6 on _1_3 is
*&     "Name". Those are passed as the fallback with no code, which is
*&     exactly what LCL_TXT's contract already handles.
*&
*& The fallback is always the wording the screenshots show, so a client
*& whose label table is not filled still renders a readable form.
*&
*& ---- FIELD NAMES: five had to be shortened, and it was forced -------
*& A migrated FIELD_NAME must BE the legacy one, because backend field
*& control is keyed on it end to end. Five uploaders on _1_5 make that
*& impossible: the model builds _VS/_VST/_IDTYPE/_NAME/_IX/_EXP
*& companions on every field name, so the real ceiling is 23 characters,
*& and GPS_TRACKING_REGISTRATION_DOCUMENTS is 35. Over the limit
*& CL_ABAP_STRUCTDESCR=>CREATE( ) raises CX_SY_STRUCT_COMP_NAME, which
*& BUILD_MODEL( ) does not catch - the whole app dies with UNCAUGHT
*& EXCEPTION rather than the field misbehaving.
*&
*& So they are shortened, and it is safe HERE for a reason specific to
*& this journey rather than a general one: the E019 BAdI does field
*& control on ONE screen only - ZCL_EGA_CJ_ENH_IMPL_E019's READ touches
*& ENABLED/MANDATORY inside IF ... screenname EQ 'NE019_1_2' and nowhere
*& else - and none of these five sit on that screen. Attachments are
*& identified to the backend by their document type (DTYPE: below), not
*& by field name, so nothing else keys on them either.
*&
*&   DOC_LETTER_SUPPLIER  <- LETTER_FROM_THE_SUPPLIER_COMPANY     (32)
*&   DOC_LETTER_RECEIVER  <- LETTER_FROM_THE_RECEIVING_COMPANY    (33)
*&   DOC_VEHICLE_DATA     <- OIL_TRANSPORT_VEHICLE_DATA           (26)
*&   DOC_EPDA_PERMIT      <- EPDA_ENVIRONMENTAL_PERMIT            (25)
*&   DOC_GPS_TRACKING     <- GPS_TRACKING_REGISTRATION_DOCUMENTS  (35)
*&
*& TRADE_LICENSE (13) and RAKUPLOADER_7 (13) fit and therefore keep
*& their legacy names, ugly as the second one is. Every other field on
*& every step is under the ceiling and unchanged.
*&
*& ---- WHY THE FIRST STEP'S SHOW/HIDE IS NOT RULES -------------------
*& E014/E015/E027 do this toggle in ZRAK_T_JNY_RULE and their handlers
*& carry a comment telling you not to use set_hidden( ). E019 cannot,
*& and the reason is worth reading before "fixing" it back: rules and
*& overrides are both keyed on the FIELD NAME ALONE, and this journey
*& carries REGISTERED_EMIRATES_1 and TRADE_LICENSE_1 on THREE of its
*& steps and ADDRESS_1 on two. Hiding step 1's pair hid the namesakes on
*& Company and Receiving Company, both REQUIRED - a form that will not
*& submit and does not say why.
*&
*& The handler therefore calls set_hidden( iv_step = ) so the override
*& lands on step 0 only. OWNER_1 and PERMIT_NUMBER_1 are unique names
*& and could have been rules; they go through the handler too, so the
*& whole of step 1's conditional behaviour is in one place rather than
*& half in config and half in code.
*&
*& ---- Re-runnable ---------------------------------------------------
*& Deletes its own rows first. Touches nothing outside journey_id 'E019'
*& and ZRAK_T_CJ_TXT number 900, which it owns.
*&---------------------------------------------------------------------*
REPORT zrak_e019_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'EPDA_E019_TRANS_USED_OIL'.

* Long-text numbers for the declaration. Well clear of the engine
* catalogue in ZCL_RAK_TEXT, which currently ends at 138.
*
* TWO ROWS, NOT ONE, AND THE REASON IS A LENGTH LIMIT AGAIN.
* ZRAK_T_CJ_TXT-TEXT_EN is CHAR255 and the whole declaration is about
* 340 characters, so a single row would cut it on INSERT and the tail
* would be gone from the database rather than hidden - the identical
* failure ZLABEL(150) produces, one column further down the escape
* route. The legacy screen splits the same paragraph across
* DECLARATION_LONG1 and DECLARATION_LONG2 for the same reason, so this
* mirrors the split it already has rather than inventing one.
CONSTANTS c_txt_dcl1 TYPE symsgno VALUE '900'.
CONSTANTS c_txt_dcl2 TYPE symsgno VALUE '901'.

* ------------------------------------------------------- legacy wording
* /QNV/SB_LABELT holds the department's own text for every LABEL_CON
* code, one row per SPRAS. Typing the English off a spec and translating
* the Arabic by hand puts a guess on screen in place of wording the
* department owns - in a language most reviewers of this repository
* cannot check, so nothing reports the difference.
*
* THE FALLBACK IS THE LITERAL, NEVER BLANK, so a missing row leaves a
* readable label and this stays runnable on a client whose label table
* is empty.
*
* IV_CODE IS DDIC-TYPED ON PURPOSE: a TYPE string formal parameter
* cannot take a DDIC-typed actual by reference, and the value goes
* straight into an Open SQL comparison against the real column.
CLASS lcl_txt DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS en
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code OPTIONAL
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS ar
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code OPTIONAL
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
*   Fallback first, so every exit - the miss included - leaves the caller
*   holding readable text.
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

* -------------------------------------------------------------- runtime
* START-OF-SELECTION IS REQUIRED because LCL_TXT exists. A report's
* first executable statement normally opens an implicit
* START-OF-SELECTION, but a local CLASS ... IMPLEMENTATION is itself a
* processing block - so without the keyword everything after ENDCLASS
* belongs to no block and the first DELETE reports "Statement is not
* accessible", with the rest of the report silently unreachable.
START-OF-SELECTION.

* ------------------------------------------------------------- teardown
* ZRAK_T_JNY_COL is included because this journey does seed grids, and a
* stale column row against a field that no longer exists is invisible
* until it draws.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_cj_txt   WHERE msgno = @c_txt_dcl1.
  DELETE FROM zrak_t_cj_txt   WHERE msgno = @c_txt_dcl2.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- title
* Read, never typed - ZEGA_T_CJ_IDT holds the portal's own wording per
* language for this journey id.
  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_en)
    WHERE journeyid = 'E019' AND spras = @sy-langu.
  IF lv_title_en IS INITIAL.
    lv_title_en = 'Transport Used Oil'.
  ENDIF.

  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_ar)
    WHERE journeyid = 'E019' AND spras = 'A'.

* ------------------------------------------------ declaration long text
* OVER 150 CHARACTERS, so it cannot live in ZLABEL - that column cuts on
* INSERT and the tail is gone from the database, not merely hidden. It
* goes in ZRAK_T_CJ_TXT and is reached by DEFAULT_VAL = 'TEXT:@900',
* which ZCL_RAK_JOURNEY_REPO re-resolves per language on every round
* trip, so a wording change needs no reseed.
*
* The legacy screen carries the two halves as E003_DECLARATION_TEXT1 and
* E003_DECLARATION_TEXT2 and concatenates them at render with the
* applicant's name in front. The name is the handler's job - it is per
* citizen - so what is stored here is the sentence WITHOUT it, and the
* handler prepends "I, <name>," in ON_AFTER_READ.
*
* NO STRING TEMPLATES HERE ON PURPOSE. A line break is legal inside a
* template's embedded expression and illegal inside its literal text,
* which makes a multi-line |{ meth( ) }| a dialect gamble for no gain -
* and a syntax error in a report is a report that will not run at all.
* Plain variables and && say the same thing and cannot be got wrong.
  DATA lv_dcl1_en TYPE string.
  DATA lv_dcl1_ar TYPE string.
  DATA lv_dcl2_en TYPE string.
  DATA lv_dcl2_ar TYPE string.

  lv_dcl1_en = lcl_txt=>en(
    iv_code = 'E003_DECLARATION_TEXT1'
    iv_fb   = 'as the company owner, hereby declare that all information ' &&
              'provided in this application and in attached documents are ' &&
              'true and accurate, that I will be responsible for any ' &&
              'consequences of them,' ).
  lv_dcl1_ar = lcl_txt=>ar( iv_code = 'E003_DECLARATION_TEXT1'
                            iv_fb   = lv_dcl1_en ).

  lv_dcl2_en = lcl_txt=>en(
    iv_code = 'E003_DECLARATION_TEXT2'
    iv_fb   = 'and I will be abide by all relevant regular conditions, ' &&
              'instructions and guidelines to avoid legal action in case ' &&
              'of violations and that I authorize our representative to ' &&
              'follow up all the related to the activity.' ).
  lv_dcl2_ar = lcl_txt=>ar( iv_code = 'E003_DECLARATION_TEXT2'
                            iv_fb   = lv_dcl2_en ).

  INSERT zrak_t_cj_txt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt msgno = c_txt_dcl1
      text_en = lv_dcl1_en text_ar = lv_dcl1_ar )
    ( mandt = sy-mandt msgno = c_txt_dcl2
      text_en = lv_dcl2_en text_ar = lv_dcl2_ar ) ) ).

* ---------------------------------------------------------------- header
* BKND_* are the real values off the export: every navigation button on
* NE019_1_* carries DATA1 = ZFM_EGA_CJ_FW_POST_N and
* DATA2 = ZFM_EGA_CJ_FW_READ_N under CATEGORY 'EPDA', and every screen
* carries a JOURNEYTYPE row whose value is E019. So this is wired live
* rather than shipped inert.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = lv_title_en
    title_ar      = COND #( WHEN lv_title_ar IS NOT INITIAL THEN lv_title_ar
                            ELSE 'نقل الزيت المستعمل' )
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_EPDA_E019_TRANS_USED_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'EPDA'
    bknd_journey  = 'E019'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ----------------------------------------------------------------- steps
* Titles from the impl class's own STAGES row, which sets
* additionaldata3 = 'Applicant,Company,Materials,Receiving Company,' &&
* 'Documents,Confirmation' behind text symbols (001)/(002) - so these
* are the department's stage names, not invented ones.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Applicant' title_ar = 'مقدم الطلب'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'NE019_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Company' title_ar = 'الشركة'
      icon = 'sap-icon://building' bknd_screen = 'NE019_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Materials' title_ar = 'المواد'
      icon = 'sap-icon://product' bknd_screen = 'NE019_1_3' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Receiving Company' title_ar = 'الشركة المستلمة'
      icon = 'sap-icon://shipping-status' bknd_screen = 'NE019_1_4' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 50
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NE019_1_5' active = 'X' ) ) ).

* ============================================================ STP1 fields
* The four applicant rows are LABELs on the legacy screen, bound to
* GS_DATA-PARTNER_* - the portal session fills them and the citizen never
* types them - so READONLY, not INPUT.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'APP_NAME' ftype = 'READONLY' readonly = 'X'
      zsection    = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_1_APPLICANT' iv_fb = 'Applicant Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_1_1_APPLICANT' iv_fb = 'بيانات مقدم الطلب' )
      zlabel      = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_1_APP_NAME_TEXT' iv_fb = 'Applicant name' )
      zlabel_ar   = lcl_txt=>ar( iv_code = 'DOKSL_ND001_1_1_APP_NAME_TEXT' iv_fb = 'اسم مقدم الطلب' )
      tech_name = 'GS_DATA-PARTNER_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'APP_ID' ftype = 'READONLY' readonly = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_1_APP_ID_TEXT' iv_fb = 'Emirates id Number' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_1_1_APP_ID_TEXT' iv_fb = 'رقم الهوية الاماراتية' )
      tech_name = 'GS_DATA-PARTNER_ID' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'PARTNER_MOBILE_1' ftype = 'READONLY' readonly = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_APP_MOBILE_TXT' iv_fb = 'Mobile Number' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_APP_MOBILE_TXT' iv_fb = 'رقم الهاتف المتحرك' )
      tech_name = 'GS_DATA-PARTNER_MOBILE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 40
      field_name = 'PARTNER_EMAIL_1' ftype = 'READONLY' readonly = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_APP_EMAIL_TXT' iv_fb = 'Email ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_APP_EMAIL_TXT' iv_fb = 'البريد الإلكتروني' )
      tech_name = 'GS_DATA-PARTNER_EMAIL' )

*   THE TWO LEGACY TBUTTONS COLLAPSE INTO ONE SEGMENTED FIELD, named
*   after the lower-sequence member so the handler's constant and the
*   option keys agree.
*
*   NO TECH_NAME ON THE CONTROL, and that is the whole point.
*   A LEGACY TOGGLE GROUP IS N BOOLEAN ITEMS, NOT ONE VALUE. The export
*   gives each button its own row with its own TECHNICAL_NAME -
*   PARTNER_OWNER_1 is GS_DATA-PARTNER_OWNER, PARTNER_REP_1 is
*   GS_DATA-PARTNER_REP - and CASE_MAPPING( ) reads them that way:
*
*       CASE abap_true.
*         WHEN gs_data-partner_owner.  applicant_type = '2' ...
*         WHEN gs_data-partner_rep.    applicant_type = '1' ...
*
*   A single TECH_NAME here would post the chosen OPT_KEY -
*   'PARTNER_OWNER_1' - into a FLAG that is tested for 'X', where it
*   truncates to 'P', while the sibling flag never arrives at all. The
*   carriers below do the posting; ON_CHANGE( ) sets exactly one and
*   clears the other, and ON_AFTER_READ( ) reads them back so a resumed
*   draft redraws on the right option. Same defect and same fix as
*   M018's four radio groups.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 50
      field_name = 'PARTNER_OWNER_1' ftype = 'SEGMENTED' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_1_APP_TYPE_TEXT' iv_fb = 'Applicant Type' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_1_1_APP_TYPE_TEXT' iv_fb = 'نوع مقدم الطلب' )
      default_val = 'PARTNER_OWNER_1' )

*   OWNER_1 is the legacy PERSON_SEARCH inside container OWNER_FINDER.
*   HIDDEN here and revealed by the handler, because the legacy
*   UI_FIELD_LOGICS is explicit and counter-intuitive: OWNER_FINDER-V-F
*   on the Owner button and OWNER_FINDER-V-T on Representative - the
*   owner lookup appears only when somebody applies ON BEHALF of the
*   owner, never when the owner applies personally.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 60
      field_name = 'OWNER_1' ftype = 'SEARCH' hidden = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE016_1_1_LABEL_14' iv_fb = 'Owner' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE016_1_1_LABEL_14' iv_fb = 'المالك' )
      tech_name = 'GS_DATA-OWNER' )

*   The permit question. Same two-TBUTTON shape, group PERMIT_YES /
*   PERMIT_NO, and REQUIRED - the screenshot marks it with an asterisk
*   and everything below it depends on the answer.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 70
      field_name = 'PERMIT_YES' ftype = 'SEGMENTED' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE016_1_1_LABEL_12' iv_fb = 'Do you have EPDA permit no' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE016_1_1_LABEL_12' iv_fb = 'هل لديك رقم تصريح من هيئة حماية البيئة والتنمية؟' )
      default_val = 'PERMIT_YES' )

*   THE FOUR CARRIERS. Hidden, readonly, and the only rows on this step
*   that carry the group members' TECH_NAMEs. Readonly as well as hidden
*   because a hidden field is still a field: nothing should be able to
*   type into a value the handler owns.
*
*   They sit on STP1 with the controls they carry - FLATTEN_KV( IV_STEP )
*   flattens one step per post, so a carrier on another step would not
*   travel with the answer that set it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 71
      field_name = 'CY_PARTNER_OWNER' ftype = 'INPUT' hidden = 'X' readonly = 'X'
      tech_name = 'GS_DATA-PARTNER_OWNER' zlabel = 'Applicant type - owner' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 72
      field_name = 'CY_PARTNER_REP' ftype = 'INPUT' hidden = 'X' readonly = 'X'
      tech_name = 'GS_DATA-PARTNER_REP' zlabel = 'Applicant type - representative' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 73
      field_name = 'CY_PERMIT_YES' ftype = 'INPUT' hidden = 'X' readonly = 'X'
      tech_name = 'GS_DATA-PERMIT_YES' zlabel = 'Has EPDA permit - yes' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 74
      field_name = 'CY_PERMIT_NO' ftype = 'INPUT' hidden = 'X' readonly = 'X'
      tech_name = 'GS_DATA-PERMIT_NO' zlabel = 'Has EPDA permit - no' )

*   PERMIT_FINDER's one input. The legacy screen has TWO rows against
*   the same GS_DATA-PERMIT_NUMBER - PERMIT_NUMBER_1 (INPUT) and
*   PERMIT_NUMBER_2 (SEARCH_FIELD, EXTENDED) - which is one control plus
*   its search affordance, not two fields.
*
*   INPUT, NOT 'SEARCH'. In CJS 'SEARCH' means the BUSINESS PARTNER
*   lookup - that is what the ftype draws and what ZCL_RAK_BP_SEARCH
*   answers - and a permit number is not a partner, so it would open a
*   dialog that can never find it. The resolution genuinely happens on
*   the backend already: ZCL_EGA_CJ_CONSULTANT_ABS->PERMIT_SELECTION( )
*   reads ZV_EPDAPMMAST on the permit number during the post and fills
*   GS_DATA-COMPANY, so the company block arrives filled on the next
*   read with no CJS-side lookup at all. That is also what draws the
*   resolved company name under the field on the screenshot.
*
*   LABEL_13 carries LITERAL text in the export rather than a code, so
*   there is no code to read and the literal is the value.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 80
      field_name = 'PERMIT_NUMBER_1' ftype = 'INPUT' hidden = 'X'
      zlabel = 'Permit number' zlabel_ar = 'رقم التصريح'
      placeholder = 'E21IX02692'
      tech_name = 'GS_DATA-PERMIT_NUMBER' )

*   LICENSE_FINDER's pair, shown only when the answer is No. BOTH NAMES
*   REPEAT ON LATER STEPS, which is why the handler scopes its
*   set_hidden( ) to step 0 - see the header.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 90
      field_name = 'REGISTERED_EMIRATES_1' ftype = 'SELECT' hidden = 'X'
      shlp = 'ZSH_CJ_UAE_REGION'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_15' iv_fb = 'Company Registration Emirates' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_15' iv_fb = 'إمارة تسجيل الشركة' )
      tech_name = 'GS_DATA-REGISTERED_EMIRATES' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 100
      field_name = 'TRADE_LICENSE_1' ftype = 'INPUT' hidden = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'DOKSL_ND001_2_5_TRADE_LICENSE_ATT_TXT' iv_fb = 'Trade License' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_2_5_TRADE_LICENSE_ATT_TXT' iv_fb = 'الرخصة التجارية' )
      tech_name = 'GS_DATA-TRADE_LICENSE' )

* ============================================================ STP2 fields
*   Transporter details. Every one of these is MANDATORY = X in the
*   export and marked with an asterisk on the screenshot.
*
*   The legacy INPUT_DIRECTED on the two name fields is an input with a
*   forced text direction (DATA4 = LTR / RTL). CJS has no direction
*   column; the Arabic field renders right-to-left from the page
*   direction when the citizen is in Arabic, and an Arabic company name
*   typed into an English session is the one case that differs. Recorded
*   rather than silently dropped.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'COMPANY_NAME_EN_1' ftype = 'INPUT' required = 'X'
      zsection    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_COMPANY_DETAILS_TXT' iv_fb = 'Transporter Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_COMPANY_DETAILS_TXT' iv_fb = 'بيانات الناقل' )
      zlabel      = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_13' iv_fb = 'Company Name English' )
      zlabel_ar   = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_13' iv_fb = 'اسم الشركة بالانجليزية' )
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_EN' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'COMPANY_NAME_AR_1' ftype = 'INPUT' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_14' iv_fb = 'Company Name Arabic' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_14' iv_fb = 'اسم الشركة بالعربية' )
      tech_name = 'GS_DATA-COMPANY-COMPANY_NAME_AR' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'REGISTERED_EMIRATES_1' ftype = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_UAE_REGION'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_15' iv_fb = 'Company Registration Emirates' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_15' iv_fb = 'إمارة تسجيل الشركة' )
      tech_name = 'GS_DATA-COMPANY-REGISTERED_EMIRATES' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'ADDRESS_1' ftype = 'TEXTAREA' required = 'X' ta_rows = 3
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_16' iv_fb = 'Company Address' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_16' iv_fb = 'عنوان الشركة' )
      tech_name = 'GS_DATA-COMPANY-ADDRESS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'TRADE_LICENSE_1' ftype = 'INPUT' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'DOKSL_ND001_2_5_TRADE_LICENSE_ATT_TXT' iv_fb = 'Trade License' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_2_5_TRADE_LICENSE_ATT_TXT' iv_fb = 'الرخصة التجارية' )
      tech_name = 'GS_DATA-COMPANY-TRADE_LICENSE' )

*   Contact block. MOBILE_NO_1 and TELEPHONE_NO_1 are captioned "Mobile
*   Number 1" and "Mobile Number 2" on the screen even though the second
*   one's field and backend component both say TELEPHONE - the caption is
*   read, so the screen keeps saying what it says today. Neither is
*   MANDATORY in the export; only the e-mail is.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 60
      field_name = 'MOBILE_NO_1' ftype = 'PHONE'
      zsection    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_COMPANY_CONTACT_TXT' iv_fb = 'Company Contact Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_COMPANY_CONTACT_TXT' iv_fb = 'بيانات الاتصال بالشركة' )
      zlabel      = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_18' iv_fb = 'Mobile Number 1' )
      zlabel_ar   = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_18' iv_fb = 'رقم الهاتف المتحرك 1' )
      tech_name = 'GS_DATA-COMPANY-MOBILE_NO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 70
      field_name = 'TELEPHONE_NO_1' ftype = 'PHONE'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_19' iv_fb = 'Mobile Number 2' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_19' iv_fb = 'رقم الهاتف المتحرك 2' )
      tech_name = 'GS_DATA-COMPANY-TELEPHONE_NO' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 80
      field_name = 'EMAIL_ID_1' ftype = 'EMAIL' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_LABEL_20' iv_fb = 'E-mail ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_LABEL_20' iv_fb = 'البريد الإلكتروني' )
      tech_name = 'GS_DATA-COMPANY-EMAIL_ID' )

* ============================================================ STP3 fields
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'MATERIAL_ORIGIN_1' ftype = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_EPDA_MATERIAL_ORIGIN'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_MATERIAL_ORIGIN_SOURCE_TXT' iv_fb = 'Material Origin source' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_MATERIAL_ORIGIN_SOURCE_TXT' iv_fb = 'مصدر المادة' )
      default_val = '1'
      tech_name = 'GS_DATA-COMPANY-MATERIAL_ORIGIN' )
*   LABEL_6 is literal text in the export, not a code.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'MATERIAL_TEXT_1' ftype = 'INPUT' required = 'X' max_len = 100
      zlabel = 'Name' zlabel_ar = 'الاسم'
      tech_name = 'GS_DATA-COMPANY-MATERIAL_TEXT' )

*   THE TWO GRIDS ARE EDITABLE_TABLE, not TABLE. The citizen adds and
*   deletes rows - MTABLE_CADD_2 "Add Vehicle" and MTABLE_CADD_1 "Add
*   Material", with MTABLE_DELETE per row - and only EDITABLE_TABLE lets
*   a handler reach the rows to count them.
*
*   THE COLUMN ORDER IS THE LEGACY LIST_SEQUENCE, and it is load-bearing
*   in both directions: ZCL_EGA_CJ_ECOMP_ABS fills FIELD<n> from
*   LIST_SEQUENCE, and ZCL_RAK_JOURNEY_BE hands cell n to configured
*   column n of this spec. A column out of order renders the neighbouring
*   value and nothing reports it.
*     VEHICLES       1 EMIRATE  2 CODE  3 PLATE_NO
*     MATERIALS_DET  1 MATERIAL_NAME  2 QUANTITY  3 UNIT
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'VEHICLES' ftype = 'EDITABLE_TABLE'
      zsection    = 'Vehicles' zsection_ar = 'المركبات'
      default_val = 'EMIRATE:Issuing Emirate:TEXT'   &&
                    '|CODE:Vehicle Code:TEXT'        &&
                    '|PLATE_NO:Vehicle Plate Number:TEXT'
      tech_name = 'GS_DATA-VEHICLES[]' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'MATERIALS_DET' ftype = 'EDITABLE_TABLE'
      zsection    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_LABEL_2' iv_fb = 'Materials Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_LABEL_2' iv_fb = 'تفاصيل المواد' )
      default_val = 'MATERIAL_NAME:Material Type:TEXT' &&
                    '|QUANTITY:Quantity:NUMBER'        &&
                    '|UNIT:Units:TEXT'
      tech_name = 'GS_DATA-MATERIALS[]' )

* ============================================================ STP4 fields
*   Receiving company. All six are MANDATORY in the export and asterisked
*   on the screenshot. LABEL_2's caption is the legacy's own spelling,
*   "Receiving Company Detals" - read, not corrected here; a typo in the
*   department's text table is theirs to fix, and silently spelling it
*   differently from the live screen is the drift this rule exists to
*   prevent.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'COMPANY_NAME_1' ftype = 'INPUT' required = 'X' max_len = 100
      zsection    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_4_LABEL_2' iv_fb = 'Receiving Company Detals' )
      zsection_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_4_LABEL_2' iv_fb = 'بيانات الشركة المستلمة' )
      zlabel      = lcl_txt=>en( iv_code = 'EPDA_NE019_1_4_LABEL_3' iv_fb = 'Company Name' )
      zlabel_ar   = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_4_LABEL_3' iv_fb = 'اسم الشركة' )
      tech_name = 'GS_DATA-SUPPLIER-COMPANY_NAME' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 20
      field_name = 'ADDRESS_1' ftype = 'TEXTAREA' required = 'X' max_len = 250 ta_rows = 3
      zlabel    = lcl_txt=>en( iv_code = 'ADDRESS_LABLE' iv_fb = 'Address' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'ADDRESS_LABLE' iv_fb = 'العنوان' )
      tech_name = 'GS_DATA-SUPPLIER-ADDRESS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 30
      field_name = 'REGISTERED_EMIRATES_1' ftype = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_UAE_REGION'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_4_LABEL_7' iv_fb = 'Registered Emirate' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_4_LABEL_7' iv_fb = 'الإمارة المسجلة' )
      tech_name = 'GS_DATA-SUPPLIER-REGISTERED_EMIRATES' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      field_name = 'TRADE_LICENSE_1' ftype = 'INPUT' required = 'X' max_len = 60
      zlabel    = lcl_txt=>en( iv_code = 'DOKSL_ND001_2_5_TRADE_LICENSE_ATT_TXT' iv_fb = 'Trade License' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_2_5_TRADE_LICENSE_ATT_TXT' iv_fb = 'الرخصة التجارية' )
      tech_name = 'GS_DATA-SUPPLIER-TRADE_LICENSE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 50
      field_name = 'CONTACT_PERSON_1' ftype = 'INPUT' required = 'X' max_len = 100
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_4_LABEL_5' iv_fb = 'Contact Person' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_4_LABEL_5' iv_fb = 'الشخص المسؤول' )
      tech_name = 'GS_DATA-SUPPLIER-CONTACT_PERSON' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 60
      field_name = 'MOBILE_1' ftype = 'PHONE' required = 'X' max_len = 15
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_4_LABEL_6' iv_fb = 'Contact Person Mobile Number' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_4_LABEL_6' iv_fb = 'رقم هاتف الشخص المسؤول' )
      tech_name = 'GS_DATA-SUPPLIER-MOBILE' )

* ============================================================ STP5 fields
*   THE SIZE NOTE FIRST, as on the legacy screen - it is guidance, so
*   DISPLAY with no label rather than a caption looking for a control.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 10
      field_name = 'FILE_SIZE_LIMIT' ftype = 'DISPLAY'
      default_val = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_4_FILE_SIZE_LIMIT'
                                 iv_fb = 'Each file maximum allowed size - 3MB' ) )

*   THE SEVEN UPLOADERS. DTYPE: carries the legacy DATA2, which the BAdI
*   files as ZDT_EGA_CJ_ATTR-DIFFCRT - without it the case cannot tell a
*   supplier letter from a trade licence, and CREATE_ATTACHMENT only
*   checks OBJTRG/OBJSRC so it passes silently.
*
*   REQUIRED follows MANDATORY in the export exactly. Five are required;
*   the EPDA permit of the receiving company and "Others or Supporting"
*   are not - which matches the asterisks on the screenshot.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 20
      field_name = 'DOC_LETTER_SUPPLIER' ftype = 'UPLOAD' required = 'X'
      default_val = 'DTYPE:FN'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_5_LETTER_FROM_THE_SUPPLIER_COMPANY_TXT'
                               iv_fb = 'Letter from the Supplier Company' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_5_LETTER_FROM_THE_SUPPLIER_COMPANY_TXT'
                               iv_fb = 'خطاب من الشركة الموردة' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 30
      field_name = 'DOC_LETTER_RECEIVER' ftype = 'UPLOAD' required = 'X'
      default_val = 'DTYPE:FO'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_5_LETTER_FROM_THE_RECEIVING_COMPANY_TXT'
                               iv_fb = 'Letter from the Receiving Company' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_5_LETTER_FROM_THE_RECEIVING_COMPANY_TXT'
                               iv_fb = 'خطاب من الشركة المستلمة' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 40
      field_name = 'DOC_VEHICLE_DATA' ftype = 'UPLOAD' required = 'X'
      default_val = 'DTYPE:QA'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_5_OIL_TRANSPORT_VEHICLE_DATA_TXT'
                               iv_fb = 'Oil Transport Vehicle Data (Registration Card Copy)' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_5_OIL_TRANSPORT_VEHICLE_DATA_TXT'
                               iv_fb = 'بيانات مركبة نقل الزيت (صورة بطاقة التسجيل)' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 50
      field_name = 'DOC_EPDA_PERMIT' ftype = 'UPLOAD'
      default_val = 'DTYPE:P7'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_5_EPDA_ENVIRONMENTAL_PERMIT_TXT'
                               iv_fb = 'EPDA Environmental Permit (Company Receiving Used Oil)' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_5_EPDA_ENVIRONMENTAL_PERMIT_TXT'
                               iv_fb = 'التصريح البيئي للشركة المستلمة للزيت المستعمل' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 60
      field_name = 'DOC_GPS_TRACKING' ftype = 'UPLOAD' required = 'X'
      default_val = 'DTYPE:FP'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_5_GPS_TRACKING_REGISTRATION_DOCUMENTS_TXT'
                               iv_fb = 'GPS tracking registration documents' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_5_GPS_TRACKING_REGISTRATION_DOCUMENTS_TXT'
                               iv_fb = 'مستندات تسجيل نظام التتبع' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 70
      field_name = 'TRADE_LICENSE' ftype = 'UPLOAD' required = 'X'
      default_val = 'DTYPE:11'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_5_TRADE_LICENSE_TXT'
                               iv_fb = 'Transporter Trade license' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_5_TRADE_LICENSE_TXT'
                               iv_fb = 'الرخصة التجارية للناقل' ) )
*   RAKUPLOADER_7 keeps its legacy name because it fits the 23-character
*   ceiling. Its caption is the one that says what it is.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 80
      field_name = 'RAKUPLOADER_7' ftype = 'UPLOAD'
      default_val = 'DTYPE:P6'
      zlabel    = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_4_OTHERS_TXT' iv_fb = 'Others or Supporting' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_1_4_OTHERS_TXT' iv_fb = 'أخرى أو مستندات مساندة' ) )

*   THE DECLARATION. ZSECTION draws the heading, so the field itself
*   carries no ZLABEL - both set prints the heading twice.
*
*   TEXT:@900 and @901 are the two halves seeded above. ON_AFTER_READ
*   overwrites DECLARATION_NAME's VALUE with the first half carrying the
*   applicant's name in front, the way the legacy READ builds it; the
*   second half never varies and is left to its default.
*
*   A TEXT: default is never seeded as a field's value, so the
*   personalised sentence is what the citizen sees and @900 is only what
*   shows if the handler did not run.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 90
      field_name = 'DECLARATION_NAME' ftype = 'DISPLAY'
      zsection    = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_4_DECLARATION_TXT' iv_fb = 'Declaration' )
      zsection_ar = lcl_txt=>ar( iv_code = 'DOKSL_ND001_1_4_DECLARATION_TXT' iv_fb = 'الإقرار' )
      default_val = 'TEXT:@900' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 95
      field_name = 'DECLARATION_2' ftype = 'DISPLAY'
      default_val = 'TEXT:@901' )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 100
      field_name = 'DISCLAIMER_TXT' ftype = 'DISPLAY'
      default_val = lcl_txt=>en( iv_code = 'DOKSL_ND001_1_4_DISCLAIMER_TXT'
                                 iv_fb = 'Note: Once you submit, you can''t cancel the application.' ) ) ) ).

* ---------------------------------------------------------- grid columns
* CTRL PER COLUMN, matching the legacy child controls: the emirate and
* the unit are dropdowns off their own search helps, the rest are inputs.
* MAXLEN is the legacy DATA3 where it set one - 2 on the vehicle code,
* 5 on the plate.
*
* REQUIRED IS SET PER COLUMN AND IT IS ENFORCED, unlike field-level
* REQUIRED which never reaches grid rows. It applies to rows that
* already exist; whether at least ONE row exists is the handler's check.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' field_name = 'VEHICLES'
      col_name = 'EMIRATE'  seqnr = 1 ctrl = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_UAE_EMIRATE_PLATE' width = '12rem'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_EMIRATE_1' iv_fb = 'Issuing Emirate' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_EMIRATE_1' iv_fb = 'إمارة الإصدار' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' field_name = 'VEHICLES'
      col_name = 'CODE'     seqnr = 2 ctrl = 'INPUT' required = 'X' maxlen = 2 width = '9rem'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_CODE_1' iv_fb = 'Vehicle Code' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_CODE_1' iv_fb = 'رمز المركبة' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' field_name = 'VEHICLES'
      col_name = 'PLATE_NO' seqnr = 3 ctrl = 'INPUT' required = 'X' maxlen = 5
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_PLATE_NO_1' iv_fb = 'Vehicle Plate Number' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_PLATE_NO_1' iv_fb = 'رقم لوحة المركبة' ) )

*   MATERIAL_TYPE_1 and QUANTITY_1 are NOT mandatory in the export -
*   only the emirate, the code and the plate are - so only UNIT carries
*   no marker either. Left as the export has it rather than tightened:
*   a required marker CJS enforces and the legacy screen never did would
*   refuse a submit the department accepts today.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' field_name = 'MATERIALS_DET'
      col_name = 'MATERIAL_NAME' seqnr = 1 ctrl = 'INPUT'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_MATERIAL_TYPE_1' iv_fb = 'Material Type' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_MATERIAL_TYPE_1' iv_fb = 'نوع المادة' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' field_name = 'MATERIALS_DET'
      col_name = 'QUANTITY'      seqnr = 2 ctrl = 'INPUT' width = '9rem' align = 'End'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_QUANTITY_1' iv_fb = 'Quantity' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_QUANTITY_1' iv_fb = 'الكمية' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' field_name = 'MATERIALS_DET'
      col_name = 'UNIT'          seqnr = 3 ctrl = 'SELECT'
      shlp = 'ZSH_CJ_UOM_VOLUME_TYPES' width = '12rem'
      zlabel    = lcl_txt=>en( iv_code = 'EPDA_NE019_1_3_UNIT_1' iv_fb = 'Units' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EPDA_NE019_1_3_UNIT_1' iv_fb = 'الوحدات' ) ) ) ).

* --------------------------------------------------------------- options
* THE SEGMENTED OPTION KEYS ARE THE LEGACY FIELD NAMES, because that is
* what the group is: DATA1 on each TBUTTON lists its whole group -
* "PARTNER_OWNER_1,PARTNER_REP_1" and "PERMIT_YES,PERMIT_NO" - and the
* handler writes one backend flag per member. A key invented here would
* stop the handler's CASE matching and the toggle would set nothing,
* silently.
*
* Option TEXTS are read from the label dictionary like everything else.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'PARTNER_OWNER_1'
      seqnr = 1 opt_key = 'PARTNER_OWNER_1'
      opt_text    = lcl_txt=>en( iv_code = 'EPDA_NE014_1_1_TBUTTON_1' iv_fb = 'Owner' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'EPDA_NE014_1_1_TBUTTON_1' iv_fb = 'المالك' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'PARTNER_OWNER_1'
      seqnr = 2 opt_key = 'PARTNER_REP_1'
      opt_text    = lcl_txt=>en( iv_code = 'EPDA_NE017_1_1_PARTNER_REP_1' iv_fb = 'Representative' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'EPDA_NE017_1_1_PARTNER_REP_1' iv_fb = 'مفوض' ) )

    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'PERMIT_YES'
      seqnr = 1 opt_key = 'PERMIT_YES'
      opt_text    = lcl_txt=>en( iv_code = 'EPDA_NE017_1_1_PERMIT_YES' iv_fb = 'Yes' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'EPDA_NE017_1_1_PERMIT_YES' iv_fb = 'نعم' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' field_name = 'PERMIT_YES'
      seqnr = 2 opt_key = 'PERMIT_NO'
      opt_text    = lcl_txt=>en( iv_code = 'EPDA_NE017_1_1_PERMIT_NO' iv_fb = 'No' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'EPDA_NE017_1_1_PERMIT_NO' iv_fb = 'لا' ) ) ) ).

  COMMIT WORK AND WAIT.

* ------------------------------------------------------------- run report
  WRITE: / 'E019 Transport Used Oil - configuration loaded.'.
  WRITE: / '  journey_id      ', c_jny.
  WRITE: / '  steps           5  (NE019_1_1 .. NE019_1_5)'.
  WRITE: / '  handler         ZCL_EPDA_E019_TRANS_USED_LOGIC'.
  WRITE: / '  long text       ZRAK_T_CJ_TXT 900 (declaration)'.
  WRITE: /.
  WRITE: / 'Read from the legacy dictionaries, not typed here:'.
  WRITE: / '  captions and option texts  /QNV/SB_LABELT per SPRAS'.
  WRITE: / '  journey title              ZEGA_T_CJ_IDT per SPRAS'.
  WRITE: / 'A caption showing its fallback means no /QNV/SB_LABELT row'.
  WRITE: / 'answered for that code - check the code before retyping text.'.
  WRITE: /.
  WRITE: / 'Still to confirm against the backend:'.
  WRITE: / '  ZEGA_T_CJ_UI_MAP needs an ATTACHMENT row for NE019_1_5,'.
  WRITE: / '  or the seven uploads post, return success and store'.
  WRITE: / '  nothing. XCHECK rule X16 reports it from the CJS side.'.
