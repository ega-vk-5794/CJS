REPORT zrak_m011_load.

*&---------------------------------------------------------------------*
*& M011 - Request for Plots Division (Ownership)
*&
*& THE REFERENCE FEEDER FOR THE MUNICIPALITY FAMILY. M012 and M016 carry
*& only their differences and point here for the reasoning. Read this one
*& first.
*&
*& Hand-authored from the real /QNV/SB_UI_DEFIN export (EXPORT_DEFIN.XLSX),
*& screens NSUBDIVISION_1_1..1_4, category MML - 276 export rows, of which
*& 245 are LABEL / HBOX / VBOX / IMAGE / ICON / BUTTON chrome the engine
*& draws itself. See NOT MIGRATED at the foot.
*&
*& A FEEDER, NOT THE MIGRATOR. ZCL_RAK_MIGRATOR is deliberately not used:
*& it derives a layout from the /QNV/ definition rather than designing one,
*& drops RAKPAY and counts it, and its output has to be re-run to pick up
*& any fix. Everything it would have got wrong for this journey is authored
*& here instead, and the four things it does that a hand feeder must not
*& forget are done explicitly and commented as such:
*&
*&   1. BKND_ACTIVE / BKND_FM_POST / BKND_FM_READ  - the migrator never
*&      wrote them, which is why every migrated M journey rendered,
*&      validated, collected every answer and posted NOTHING.
*&   2. TITLE_AR - read from ZEGA_T_CJ_IDT('M011', SPRAS 'A'), the row the
*&      legacy service renders its own name from. NOT left blank.
*&   3. NO REVIEW STEP. The migrator inserts one before payment, and this
*&      feeder did too - the reasoning was that review-then-pay is the
*&      live order. It is not: the legacy service has no review screen at
*&      all (NSUBDIVISION_1_* is parcel, documents, payment, confirmation),
*&      and on screen it read as a step between the citizen and paying.
*&      Removed on the owner's call. Three input steps, as the service has.
*&   4. PAYFEE exists. The migrator drops RAKPAY, so twelve migrated M
*&      journeys have no pay control at all.
*&
*& STRUCTURE - 3 steps, one per legacy input screen:
*&   STP1  NSUBDIVISION_1_1  Parcel Selection
*&   STP2  NSUBDIVISION_1_2  Documents
*&   STP3  NSUBDIVISION_1_3  Fees & Payment
*&   (NSUBDIVISION_1_4 is the engine's own confirmation page - RAKHAPPY and
*&    the request-id labels are framework chrome, not fields.)
*&
*& STAGE 2 IS A SEPARATE SERVICE AND IS NOT IN THIS FEEDER.
*& NSUBDIVISION_2_1..2_3 is the later stage - apply-and-pay-initial-fee is
*& stage 1, the final fee is stage 2 - and they are two services, not two
*& halves of one wizard. A second feeder is needed for it; deriving both
*& into one journey would give the citizen a wizard that stops for weeks in
*& the middle.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'M011'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M011'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ------------------------------------------------- the Arabic title
* READ, NOT INVENTED AND NOT LEFT BLANK. Every earlier loader in this
* codebase passed the Arabic title blank "because the authoritative text is
* ZEGA_T_CJ_IDT" and then left it blank, so every migrated journey showed an
* English title to an Arabic reader. It is one SELECT.
*
* SPRAS 'A' is Arabic in SAP's own language key, not 'AR'.
  SELECT SINGLE description FROM zega_t_cj_idt
    WHERE journeyid = @c_jny AND spras = 'A'
    INTO @DATA(lv_title_ar).
  IF sy-subrc <> 0.
    CLEAR lv_title_ar.
  ENDIF.

  SELECT SINGLE description FROM zega_t_cj_idt
    WHERE journeyid = @c_jny AND spras = 'E'
    INTO @DATA(lv_title_en).
  IF sy-subrc <> 0 OR lv_title_en IS INITIAL.
*   The requirement document's wording, used only when the legacy table has
*   no English row. Flagged so the fallback is never mistaken for the
*   authoritative text.
    lv_title_en = 'Request for Plots Division - Ownership'.
  ENDIF.

* ---------------------------------------------------------------- header
* Backend class ZCL_EGA_CJ_ENH_IMPL_M011, inheriting
* ZCL_EGA_CJ_FW_RO_ABS_V1. The journey object is an RE rental object -
* company 2000, business entity CJMUN, usage type 3000, RO type RU, with
* PROPERTY carrying the journey code - and the container case on submit is
* ZGCX through ZFM_EGA_CREATE_CASE_GEN.
*
* THE FOUR BACKEND COLUMNS ARE THE WHOLE POST PATH. Without BKND_ACTIVE the
* engine has no backend at all; without the two function modules it has
* nowhere to send the payload. This is the single most expensive thing the
* migrator omitted.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = lv_title_en
    title_ar      = lv_title_ar
    subtitle      = 'Apply to divide a plot you own, and track the request.'
    subtitle_ar   = 'تقديم طلب لتقسيم قطعة أرض تملكها ومتابعة الطلب.'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_M011_DIVIDE_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'MML'
    bknd_journey  = 'M011'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N'
*   DRAFT_MODE left BLANK on purpose so the engine derives it. The
*   derivation is the rule: a backend that creates and re-opens the case IS
*   the draft, and this one does - the RE rental object created on
*   ZIF_EGA_FW_CJI~CREATE is the draft, keyed by INTRENO_JOURNEY. So CJS
*   delegates and keeps no second copy. Forcing NATIVE here would report an
*   error rather than a false success, because there is no CJS-side draft
*   store yet.
    ) ).

* ---------------------------------------------------------------- steps
* STEP TITLES ARE THE LEGACY STAGE LIST, not derived from screen content.
* The BAdI sets them on READ in the STAGES row's ADDITIONALDATA3 and they
* are in no /QNV/ column, which is why derived titles never matched the live
* service. Taken from the requirement document's stage bar.
*
* NEXT_REQUIRES on STP1 is the parcel: the footer will not offer Next until
* one is chosen. It duplicates the handler's own check on purpose - the
* handler's message explains, this stops the press.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Parcel Selection' title_ar = 'اختيار القطعة'
      icon = 'sap-icon://map' bknd_screen = 'NSUBDIVISION_1_1'
      next_requires = 'PARCELSELECTOR' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NSUBDIVISION_1_2'
      active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NSUBDIVISION_1_3'
*     NEXT_REQUIRES is NOT needed for payment - a PAYFEE control is its own
*     gate, and the PAID check in ZCL_RAK_JOURNEY_LOGIC is what refuses the
*     submit. Setting it here would add a second, weaker gate.
      active = 'X' ) ) ).

* --------------------------------------------------- STP1 Parcel Selection
* ONE REAL CONTROL ON THE WHOLE SCREEN. The export's 37 rows for
* NSUBDIVISION_1_1 are: a stage bar, a journey title, three description
* labels, a mobile EXTEXT, a panel heading, and PARCELSELECTOR.
*
* FTYPE 'PARCEL' plus the API: directive is what makes this the real
* control rather than an empty box. ZCL_RAK_CJ_PARCEL draws the paginated
* card list with the owner switch, the favourites toggle, the search box,
* the List/Map toggle and the details dialog, reading the citizen's own
* parcels live through ZCL_RAK_PROPERTY_API -> PropertiesSet.
*
* THE DIRECTIVE RIDES DEFAULT_VAL, and the empty domain slot before the
* filter is required - 'API:<api>:<eset>:<domain>:<filter>'. PropertiesSet
* takes Type = 'Parcel' / 'Unit' and omits the filter for All.
*
* IT IS NOT FindParcelSet. That set has no _GET_ENTITYSET at all - it is a
* CREATE_DEEP_ENTITY target that opens a ZGCF "I cannot find my property"
* case - so a selector bound to it would have POSTED A CASE every time a
* citizen looked at a list.
*
* TECH_NAME 'INTRENO_PARCEL' is the name the legacy VALIDATE( ) reads the
* single chosen parcel from:
*     READ TABLE ct_item_data ... WITH KEY technicalname = 'INTRENO_PARCEL'
* and the backend then stores it on characteristic CJ02. Without a
* TECH_NAME the field renders, survives every round trip and reaches the
* backend as nothing.
*
* FIELD NAME LENGTH: 'PARCELSELECTOR' is 14 characters. The real cap is 23,
* not 30 - BUILD_MODEL( ) also builds _VS, _VST, _IDTYPE, _NAME, _IX and
* _EXP companions on the same name, and CX_SY_STRUCT_COMP_NAME is uncaught,
* so an over-long name kills the whole app with UNCAUGHT EXCEPTION rather
* than hiding one field.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSELECTOR' ftype = 'PARCEL' required = 'X'
      zlabel = 'Parcel Selection' zlabel_ar = 'اختيار القطعة'
      msg = 'Select the parcel you want to divide'
      msg_ar = 'اختر القطعة التي ترغب في تقسيمها'
      default_val = 'API:PROPERTY:PropertiesSet::Type=Parcel'
      tech_name = 'INTRENO_PARCEL' )
*   The guidance paragraph under the selector. A DISPLAY field with the text
*   in DEFAULT_VAL, NOT in ZLABEL: ZLABEL is CHAR(150) and cuts on INSERT,
*   in the database, so the tail would be gone rather than hidden and no
*   rendering change could recover it. DEFAULT_VAL is CHAR(1000).
*
*   REVIEW-TEXT: DEFAULT_VAL has no _AR twin, so this paragraph shows its
*   English to an Arabic reader. The bilingual form is 'TEXT:@nnn' against a
*   ZRAK_T_CJ_TXT row; that needs a text number allocating, which is a
*   decision rather than a guess, so the literal is used and flagged.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'PARCELHINT' ftype = 'DISPLAY'
      default_val = 'Can''t find a parcel? Your properties are listed on ' &&
                    'your home page. Only parcels you own can be divided.' ) ) ).

* --------------------------------------------------- STP2 Documents
* PLOTLONGTEXT IS THE ONE FIELD ON THIS SCREEN THAT SAVES. The export shows
* TOSAVE = X and TECHNICAL_NAME = PLOTLONGTEXT on the TEXTAREA and on
* nothing else here - the uploaders carry their files through the attachment
* channel, not through an item value.
*
* It lands on characteristic CJ11 and is ALSO written to an RE note:
* ZIF_EGA_FW_CJI~UPDATE( ) calls POST_NOTE with
* tdname = <intreno>#CJ11#00000000, object RE, id CDCD. That is the copy the
* container case reads back as CASE_NOTE, so the field is load-bearing
* rather than decorative.
*
* THE THREE _DELETED UPLOADERS ARE NOT MIGRATED. UPLOADER1_DELETED and
* UPLOADER2_DELETED carry MANDATORY = X and VISIBLE = blank in the export -
* mandatory and invisible, which is the signature of a control switched off
* by leaving its visibility empty rather than by deleting the row. Carrying
* them would make the step unsubmittable for a file nobody can attach. Named
* in NOT MIGRATED so the omission is not read as an oversight.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'ENTERTEXT' ftype = 'TEXTAREA' required = 'X'
      zsection = 'Request Details'
      zlabel = 'Describe the division you are requesting'
      zlabel_ar = 'اذكر تفاصيل التقسيم المطلوب'
      placeholder = 'Describe how the plot should be divided'
      placeholder_ar = 'اذكر كيفية تقسيم القطعة'
      msg = 'Describe the division you are requesting'
      msg_ar = 'يرجى ذكر تفاصيل التقسيم المطلوب'
      min_len = 10 max_len = 1000
      tech_name = 'PLOTLONGTEXT' )
*   UPLOADER3 - parent PART2, MANDATORY blank, DATA2 = 3. Unconditional and
*   optional: the only one of the three that is always on screen.
*
*   REVIEW-TEXT: its caption comes from the LABEL3 row through
*   /QNV/SB_LABELT, which is not in the export dump. "Supporting document"
*   is a neutral stand-in, not the live wording.
*   DTYPE: IS THE LEGACY DOCUMENT TYPE, read from the export rather than
*   assigned. Each uploader row carries DATA2 and the BAdI files it as
*   ZDT_EGA_CJ_ATTR-DIFFCRT; without it every file arrives typed blank and
*   the case cannot tell one document from another - and CREATE_ATTACHMENT
*   only checks OBJTRG and OBJSRC, so it passes silently.
*
*   The type belongs to the UPLOADER row, not to the container the CJS
*   field is named after, and both screens agree:
*
*     UPLOADER1  parent NOCCONT     DATA2=1   -> field NOCCONT
*     UPLOADER2  parent LETTERCONT  DATA2=2   -> field LETTERCONT
*     UPLOADER3  parent PART2       DATA2=3   -> field UPLOADER3
*     UPLOADER   no DATA2                     -> no DTYPE:, deliberately
*
*   It rides DEFAULT_VAL behind a prefix, the same convention as TEXT: and
*   API:, and for the same reason: an uploader has no use for a default
*   value, and a new DDIC column would need an activation and a table
*   adjust first. The engine's seeding guard skips all three prefixes.
*
*   IT DOES NOT UNLOCK ATTACH_MULTI. Two files on the SAME field share a
*   field and therefore share a type, and GET_ATTACHMENT( ) de-duplicates
*   on (objsrc, diffcrt, objsrctype, objtrgtype). Multi-file needs the
*   occurrence key in identifier1, which is a different mechanism.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'UPLOADER3' ftype = 'UPLOAD'
      default_val = 'DTYPE:3'
      zsection = 'Attachments'
      zlabel = 'Supporting document' zlabel_ar = 'مستند مؤيد'
      has_attach = 'X' attach_label = 'Add document'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
*   ======== THE TWO CONDITIONAL DOCUMENT GROUPS ========================
*
*   THE FIRST VERSION OF THIS FEEDER HAD THESE TWO BADLY WRONG. It called
*   UPLOADER1 "Title deed" and UPLOADER2 "Emirates ID of the owner" and made
*   both unconditionally REQUIRED - which would have blocked every sole
*   owner of an unmortgaged parcel behind two uploads the live service does
*   not even show them. The export says what they actually are:
*
*     UPLOADER1  parent NOCCONT     MANDATORY=X  DATA2=1
*     UPLOADER2  parent LETTERCONT  MANDATORY=X  DATA2=2
*
*   and ZCL_EGA_CJ_FW_RO_ABS_V1->FIELD_CONTROL( ) is what decides whether
*   either is shown. It reads characteristic CJ02 for the parcel, the TR0800
*   partner, and then ZCL_EGA_MUN_CJ_ODATA_API:
*
*     is_mortgaged = false          -> CLEAR isvisible on CONTROLGROUP 'NOC'
*     fewer than 2 TR0800 owners    -> CLEAR isvisible on CONTROLGROUP 'LETTER'
*
*   The wording is the BAdI's own, from GET_PL_TABLE( )'s field7:
*   'Attach NOC from bank' and 'Letter of consent'.
*
*   THE CJS FIELD IS NAMED AFTER THE CONTAINER, NOT THE UPLOADER, and that
*   is what makes the hide arrive. The BAdI clears ISVISIBLE on the row
*   whose CONTROLGROUP matches - NOCCONT and LETTERCONT, both VBOXes - and
*   never on UPLOADER1/UPLOADER2. The bridge then reports back keyed on that
*   row's FIELDNAME and APPLY_CTRL( ) calls SET_HIDDEN( 'NOCCONT' ). A CJS
*   field called UPLOADER1 would never hear it. In CJS there are no
*   containers, so the group collapses to its one real control and takes the
*   container's name - the mechanism does the work and nothing is
*   duplicated. See ZCL_RAK_MUN_LOGIC's constants.
*
*   REQUIRED IS SAFE HERE. Mandatory is right when shown, and
*   ZCL_RAK_JOURNEY_RULES->VALIDATE_STEP( ) skips hidden fields, so a hidden
*   one cannot block the step. Verified in that method rather than assumed,
*   because the alternative failure is a step nobody can leave.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'NOCCONT' ftype = 'UPLOAD'
      default_val = 'DTYPE:1' required = 'X'
      zsection = 'Attachments'
      zlabel = 'NOC from the bank' zlabel_ar = 'شهادة عدم اعتراض من البنك'
      msg = 'A mortgaged parcel needs the bank''s no-objection certificate'
      msg_ar = 'القطعة المرهونة تتطلب شهادة عدم اعتراض من البنك'
      has_attach = 'X' attach_label = 'Attach NOC from bank'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'LETTERCONT' ftype = 'UPLOAD'
      default_val = 'DTYPE:2' required = 'X'
      zsection = 'Attachments'
      zlabel = 'Letter of consent' zlabel_ar = 'خطاب موافقة'
      msg = 'A parcel with more than one owner needs the other owners'' consent'
      msg_ar = 'القطعة التي لها أكثر من مالك تتطلب موافقة الملاك الآخرين'
      has_attach = 'X' attach_label = 'Letter of consent'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 ) ) ).

* --------------------------------------------------- STP3 Fees & Payment
* PAYFEE IS THE WHOLE CARD. ZCL_RAK_JOURNEY_LOGIC->RENDER_FIELD( ) draws the
* fee list, the total, the method and channel blocks, the bank charges, the
* pop-up notice, the Pay button and the poll.
*
* SO THE LEGACY SCREEN'S OWN CONTROLS ARE DELIBERATELY NOT RE-CREATED AS
* FIELDS. NSUBDIVISION_1_3 has 134 export rows including RB1..RB4 (method:
* QUICK / MRAK / KIOSK / WALKIN), PW_RB1 / PW_RB2 (channel: CREDITCARD /
* EDIRHAM), the FEESLIST CLIST with its CLIST_TEMPLATE, REMAININGFEES and
* REMAININGFEESM, TOTALVALUE and the ATB_FLAG - and every one of those is
* part of the card. Seeding them would draw the payment screen twice.
*
* TOTALFEESVALUE IS THE EXCEPTION AND IT MUST POST. The legacy
* ZIF_EGA_FW_CJI~UPDATE( ) branches on it: reading it is what triggers
* PAYMENT_CHECK( ), the container-case creation and the write to
* ZDT_EGA_CAAT_GEN-GEN_DEPOSIT_AMOUNT. The card owns the value; this field
* is how it reaches the backend, so it is READONLY and hidden from the
* citizen rather than absent.
*
* REVIEW-BE: whether the engine's card writes TOTALFEESVALUE into the model
* under this field name is NOT verified from this environment. If the post
* arrives with it blank, the fee never reaches ZDT_EGA_CAAT_GEN and the case
* is created with a zero deposit - so this is the first thing to check on
* the first real submit, and it is why the field is here rather than left to
* the card.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )
*   ---- PAY_SCREEN: THE CARRIER, NOT DECORATION ------------------------
*   PREPARE_PAYMENT( ) refuses to open the gateway without it, and its
*   own message names the value: the payment step's own BKND_SCREEN. The
*   read BAdI behind that screen is what resolves the open item, picks
*   the gateway, draws the reference and returns APPLICATIONURL.
*
*   WITHOUT THIS ROW M011 GOT ALL THE WAY THERE AND STOPPED. The ZGCX
*   case was created, the parcel, both partners and all three attachments
*   were linked, the sales order was raised - and then "Payment cannot
*   start: PAY_SCREEN is not set", because one string naming a screen the
*   engine already knew was blank.
*
*   ZCL_RAK_CJS_XCHECK LOOKS FOR EXACTLY THIS ROW on the payment step and
*   calls it the carrier, and it checks the value against the step's own
*   BKND_SCREEN - so the two must not drift.
*
*   HIDDEN AND READONLY: it is configuration the citizen has no business
*   seeing. It still posts, which is harmless, and FLATTEN_KV( ) filters
*   on TYPE rather than on either flag, so hiding it does not stop it
*   reaching the model.
*
*   ZCL_RAK_JOURNEY_LOGIC NOW DERIVES THIS WHEN BLANK, from the current
*   step's BKND_SCREEN, so a journey that forgets the row still pays. The
*   row stays anyway: it is the documented mechanism, XCHECK expects it,
*   and a derived value is a fallback rather than a design.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 15
      field_name = 'PAY_SCREEN' ftype = 'DISPLAY'
      readonly = 'X' hidden = 'X'
      default_val = 'NSUBDIVISION_1_3'
      zlabel = 'Payment screen' zlabel_ar = 'شاشة الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'TOTALVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )
*   ACCEPT_TERMS is a real gate, not chrome: its legacy UI_FIELD_LOGICS is
*   'PAY-E', which ENABLES the Pay button.
*
*   REVIEW-FE: required-validation here makes it a condition of LEAVING the
*   step; it does not grey out the Pay button inside the card the way the
*   legacy screen did. Matching that exactly needs a RENDER_FIELD
*   redefinition in the handler - which would then have to chain super or it
*   would delete the payment card.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
*   TWO INDEPENDENT BOOLEANS ARE TWO FIELDS, never one required CHECKGROUP:
*   a group is satisfied by ticking EITHER option, which is how a citizen
*   donates their way past terms they never accepted.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel = 'I would like to donate five dirhams to Ajer Charity Foundation.'
      zlabel_ar = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.'
      tech_name = 'DONATE' ) ) ).

  COMMIT WORK AND WAIT.

* INVALIDATE, ALWAYS. A versioned per-work-process cache means another work
* process keeps serving the old configuration, and the change then looks
* exactly like a report that did not run.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'M011 Request for Plots Division - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT - the journey will show'.
    WRITE: / '           its English title to an Arabic reader. Add the'.
    WRITE: / '           SPRAS A row and re-run.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'STEPS'.
  WRITE: / '  STP1 Parcel Selection   NSUBDIVISION_1_1   2 fields'.
  WRITE: / '  STP2 Documents          NSUBDIVISION_1_2   4 fields'.
  WRITE: / '  STP3 Fees & Payment     NSUBDIVISION_1_3   4 fields'.
  WRITE: / '  (no Review step - the legacy service has none)'.
  WRITE: / '  (the success page and the happiness meter are the engine''s'.
  WRITE: / '   own - drawn on MV_SUBMITTED, not seeded here)'.
  WRITE: / ''.
  WRITE: / 'WALKTHROUGH'.
  WRITE: / '  1. Launch with &journey=M011 and a real &userdata= session,'.
  WRITE: / '     or on E10/200 let ZCL_RAK_CJ_CTX simulate one. Without an'.
  WRITE: / '     identity the parcel list is EMPTY and correctly so.'.
  WRITE: / '  2. Step 1 shows the parcel card list - the citizen''s own'.
  WRITE: / '     parcels, live. Press Full Details for the map dialog.'.
  WRITE: / '     Press Select on one; Next will not offer until you do.'.
  WRITE: / '  3. Step 2: describe the division, attach title deed and ID.'.
  WRITE: / '  4. Step 3 draws the payment card. Pay is refused without the'.
  WRITE: / '     Terms checkbox and without a fee total - the legacy PAY-E'.
  WRITE: / '     semantic, enforced at the press in the base handler,'.
  WRITE: / '     because the card draws its own Pay button and no config'.
  WRITE: / '     can grey it out.'.
  WRITE: / '  5. Pay creates the ZGCX case - UPDATE( ) branches on finding'.
  WRITE: / '     TOTALFEESVALUE in the items - then the gateway opens, then'.
  WRITE: / '     the engine''s own success page and happiness meter. Neither'.
  WRITE: / '     of those last two is seeded: the engine draws them from'.
  WRITE: / '     MV_SUBMITTED and WANTS_FEEDBACK.'.
  WRITE: / '  6. Confirm the case: ZGCX, characteristic CJ12 on the RE'.
  WRITE: / '     rental object under CJMUN.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-BE'.
  WRITE: / '  - The nine domain validations (one location hierarchy, no'.
  WRITE: / '    open container, owner role present, no grant role, nothing'.
  WRITE: / '    under construction, parcel status, duplicate parcels,'.
  WRITE: / '    ZCM_CASE_PARCEL_CHARACT_PERMIT) are NOT re-implemented in'.
  WRITE: / '    CJS. They run in ZCL_EGA_CJ_FW_RO_ABS_V1->VALIDATE( ) on'.
  WRITE: / '    the post. A rejection surfaces as an engine message.'.
  WRITE: / '  - TOTALFEESVALUE must reach the backend or the container case'.
  WRITE: / '    is created with a zero deposit. Unverified from here.'.
  WRITE: / '  - Initial fees come from ZCL_EGA_MUN_CJ_FEES_M011'.
  WRITE: / '    ->GET_INITIAL_FEE. The estimated-remaining-fees link behind'.
  WRITE: / '    RAKREMAININGFEES is a separate read and is not identified.'.
  WRITE: / '  - ATTACHMENT DOCUMENT TYPE IS SENT. Each uploader declares'.
  WRITE: / '    its legacy DATA2 as DTYPE: in DEFAULT_VAL, and'.
  WRITE: / '    ATTACHMENTS_FOR_BACKEND( ) writes it into the attachment'.
  WRITE: / '    row - FILE_TYPE first in a candidate list, which is what'.
  WRITE: / '    the BAdI reads and passes to CREATE_ATTACHMENT as DOC_TYPE'.
  WRITE: / '    before filing it as ZDT_EGA_CJ_ATTR-DIFFCRT. The trace'.
  WRITE: / '    line ATTACH names which component took it, so one run'.
  WRITE: / '    cuts that list to the answer.'.
  WRITE: / '  - ATTACH_MULTI IS STILL OFF, and the type does not change it.'.
  WRITE: / '    Two files on the SAME field share a field and so share a'.
  WRITE: / '    type, and GET_ATTACHMENT( ) de-duplicates on'.
  WRITE: / '    (objsrc, diffcrt, objsrctype, objtrgtype). Multi-file needs'.
  WRITE: / '    the OCCURRENCE key in identifier1 - a different mechanism.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-TECH  (fields with no TECH_NAME, each deliberate)'.
  WRITE: / '  PARCELHINT  guidance paragraph, nothing to post'.
  WRITE: / '  REVIEW      the engine''s review renderer'.
  WRITE: / '  PAYFEE      the payment card; the card owns the payment state'.
  WRITE: / '  UPLOADER3   posts through the attachment channel'.
  WRITE: / '  NOCCONT     conditional NOC upload; attachment channel'.
  WRITE: / '  LETTERCONT  conditional consent upload; attachment channel'.
  WRITE: / ''.
  WRITE: / 'REVIEW-TEXT'.
  WRITE: / '  PARCELHINT sits in DEFAULT_VAL, which has no _AR twin, so it'.
  WRITE: / '  shows English to an Arabic reader. Bilingual needs a'.
  WRITE: / '  ZRAK_T_CJ_TXT row and a TEXT:@nnn reference.'.
  WRITE: / '  ACCEPT_TERMS is 97 chars, DONATE 62 - both clear of the 150'.
  WRITE: / '  ceiling where ZLABEL cuts silently on INSERT.'.
  WRITE: / ''.
  WRITE: / 'NOT MIGRATED  (chrome the engine draws itself)'.
  WRITE: / '  STAGES / RAKSTAGEBAR        the wizard''s own stepper'.
  WRITE: / '  JOURNEYNAME, DESCRIPTION*   header and subtitle'.
  WRITE: / '  JOURNEY_DESCRIPTION_MOBILE  mobile-only EXTEXT'.
  WRITE: / '  BACKHOME and 111 BUTTONs    framework navigation'.
  WRITE: / '  RB1..RB4, PW_RB1, PW_RB2    inside the PAYFEE card'.
  WRITE: / '  FEESLIST + CLIST_TEMPLATE   inside the PAYFEE card'.
  WRITE: / '  REMAININGFEES(M), ATB_FLAG  inside the PAYFEE card'.
  WRITE: / '  RAKHAPPY, SHAPEITFINAL*     engine confirmation page'.
  WRITE: / '  UPLOADER1_DELETED,          MANDATORY=X and VISIBLE=blank in'.
  WRITE: / '  UPLOADER2_DELETED,          the export - carrying them would'.
  WRITE: / '  LABEL/STAR *_DELETED        make the step unsubmittable'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO'.
  WRITE: / '  - Run ZCL_RAK_CJS_XCHECK for M011. A step whose BKND_SCREEN'.
  WRITE: / '    has no legacy rows renders, validates, posts and creates'.
  WRITE: / '    nothing.'.
  WRITE: / '  - Stage 2 (NSUBDIVISION_2_1..2_3) is a SEPARATE service and'.
  WRITE: / '    has no feeder yet.'.
  WRITE: / '  - Nothing here has been activated or run against a backend.'.
