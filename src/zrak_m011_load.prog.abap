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
*&   3. The REVIEW step goes BEFORE the payment step on a fee-bearing
*&      journey: review, then pay, then submit under the PAID gate. That is
*&      the live order.
*&   4. PAYFEE exists. The migrator drops RAKPAY, so twelve migrated M
*&      journeys have no pay control at all.
*&
*& STRUCTURE - 4 steps for the 3 legacy input screens:
*&   STP1  NSUBDIVISION_1_1  Parcel Selection
*&   STP2  NSUBDIVISION_1_2  Documents
*&   STPR  (none)            Review          <- inserted, seqnr 25
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
      next_requires = 'PARCELSEL' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Documents' title_ar = 'المستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NSUBDIVISION_1_2'
      active = 'X' )
*   THE REVIEW STEP, BEFORE PAYMENT. SEQNR 25 - the payment step's minus
*   five - and the id is STPR rather than STP3, so nothing renumbers:
*   ZCL_RAK_JOURNEY_REPO reads the steps ORDER BY SEQNR and the id is only
*   an identity. BKND_SCREEN is deliberately BLANK: there is no legacy
*   screen behind it and it must post nothing.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STPR' seqnr = 25
      title = 'Review' title_ar = 'مراجعة'
      icon = 'sap-icon://inspect' active = 'X' )
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
* FIELD NAME LENGTH: 'PARCELSEL' is nine characters. The real cap is 23,
* not 30 - BUILD_MODEL( ) also builds _VS, _VST, _IDTYPE, _NAME, _IX and
* _EXP companions on the same name, and CX_SY_STRUCT_COMP_NAME is uncaught,
* so an over-long name kills the whole app with UNCAUGHT EXCEPTION rather
* than hiding one field.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSEL' ftype = 'PARCEL' required = 'X'
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
      field_name = 'PLOTLONGTEXT' ftype = 'TEXTAREA' required = 'X'
      zsection = 'Request Details'
      zlabel = 'Describe the division you are requesting'
      zlabel_ar = 'اذكر تفاصيل التقسيم المطلوب'
      placeholder = 'Describe how the plot should be divided'
      placeholder_ar = 'اذكر كيفية تقسيم القطعة'
      msg = 'Describe the division you are requesting'
      msg_ar = 'يرجى ذكر تفاصيل التقسيم المطلوب'
      min_len = 10 max_len = 1000
      tech_name = 'PLOTLONGTEXT' )
*   DTYPE: IS THE LEGACY DOCUMENT TYPE, read from the export rather than
*   assigned. /QNV/SB_UI_DEFIN carries DATA2 on each uploader and the BAdI
*   files it as ZDT_EGA_CJ_ATTR-DIFFCRT; without it every file arrives
*   typed blank and the case cannot tell one document from another.
*
*   The mapping is evidence, not order-of-appearance: UPLOADER1 = 1,
*   UPLOADER2 = 2, UPLOADER3 = 3 on both NSUBDIVISION_1_2 and NCBR_1_2,
*   and the MANDATORY pattern in the export corroborates which field is
*   which - 1 and 2 mandatory, 3 optional, exactly as these rows are.
*
*   It rides DEFAULT_VAL behind a prefix, the same convention as TEXT: and
*   API:. An uploader has no use for a default value, and the engine's
*   seeding guard skips all three prefixes.
*   UPLOADER3 on the legacy screen: the sketch. MANDATORY blank there, so
*   optional here.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'DOC_SKETCH' ftype = 'UPLOAD'
      default_val = 'DTYPE:3'
      zsection = 'Attachments'
      zlabel = 'Proposed division sketch' zlabel_ar = 'مخطط التقسيم المقترح'
      has_attach = 'X' attach_label = 'Add sketch'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
*   UPLOADER1 and UPLOADER2: MANDATORY = X in the export, and visible.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'DOC_TITLEDEED' ftype = 'UPLOAD'
      default_val = 'DTYPE:1' required = 'X'
      zsection = 'Attachments'
      zlabel = 'Title deed' zlabel_ar = 'سند الملكية'
      msg = 'The title deed is required'
      msg_ar = 'سند الملكية مطلوب'
      has_attach = 'X' attach_label = 'Add title deed'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'DOC_ID' ftype = 'UPLOAD'
      default_val = 'DTYPE:2' required = 'X'
      zsection = 'Attachments'
      zlabel = 'Emirates ID of the owner' zlabel_ar = 'الهوية الإماراتية للمالك'
      msg = 'The owner''s Emirates ID is required'
      msg_ar = 'هوية المالك الإماراتية مطلوبة'
      has_attach = 'X' attach_label = 'Add Emirates ID'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 ) ) ).

* --------------------------------------------------- STPR Review
* ONE FIELD, AND THE ENGINE DRAWS THE REST. FTYPE 'REVIEW' renders every
* answer collected so far; there is nothing to configure per journey and
* nothing to post, which is why the step has no BKND_SCREEN.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STPR' seqnr = 10
      field_name = 'REVIEW' ftype = 'REVIEW'
      zlabel = 'Review your request' zlabel_ar = 'راجع طلبك' ) ) ).

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
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'TOTALFEESVALUE' ftype = 'DISPLAY' readonly = 'X'
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
      field_name = 'ACCEPT_TERMS' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
*   TWO INDEPENDENT BOOLEANS ARE TWO FIELDS, never one required CHECKGROUP:
*   a group is satisfied by ticking EITHER option, which is how a citizen
*   donates their way past terms they never accepted.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'DONATE' ftype = 'CHECKBOX'
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
  WRITE: / '  STPR Review             (no backend screen) 1 field'.
  WRITE: / '  STP3 Fees & Payment     NSUBDIVISION_1_3   4 fields'.
  WRITE: / ''.
  WRITE: / 'WALKTHROUGH'.
  WRITE: / '  1. Launch with &journey=M011 and a real &userdata= session,'.
  WRITE: / '     or on E10/200 let ZCL_RAK_CJ_CTX simulate one. Without an'.
  WRITE: / '     identity the parcel list is EMPTY and correctly so.'.
  WRITE: / '  2. Step 1 shows the parcel card list - the citizen''s own'.
  WRITE: / '     parcels, live. Press Full Details for the map dialog.'.
  WRITE: / '     Press Select on one; Next will not offer until you do.'.
  WRITE: / '  3. Step 2: describe the division, attach title deed and ID.'.
  WRITE: / '  4. Step 3 Review shows every answer.'.
  WRITE: / '  5. Step 4 draws the payment card. Submit is refused until'.
  WRITE: / '     PAYFEE reads PAID - that is the gate in the base handler.'.
  WRITE: / '  6. Confirm a container case exists: ZGCX, characteristic CJ12'.
  WRITE: / '     on the RE rental object under CJMUN.'.
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
  WRITE: / '  - ATTACHMENT DOCUMENT TYPE IS NOT SENT. The legacy uploaders'.
  WRITE: / '    carry DATA2 = 1/2/3 as the document type and the BAdI files'.
  WRITE: / '    it as ZDT_EGA_CJ_ATTR-DIFFCRT. But'.
  WRITE: / '    ZCL_RAK_JOURNEY_BE->ATTACHMENTS_FOR_BACKEND( ) sets only'.
  WRITE: / '    identifier1/2, file_name and file_content, so DIFFCRT'.
  WRITE: / '    arrives blank - and CREATE_ATTACHMENT only checks OBJTRG'.
  WRITE: / '    and OBJSRC, so it passes silently. The case cannot then'.
  WRITE: / '    tell a title deed from an Emirates ID, and because'.
  WRITE: / '    GET_ATTACHMENT( ) de-duplicates on'.
  WRITE: / '    (objsrc, diffcrt, objsrctype, objtrgtype), two files on ONE'.
  WRITE: / '    field come back as one on re-read. That is why ATTACH_MULTI'.
  WRITE: / '    is off on every uploader here. Affects M012 and M016 too.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-TECH  (fields with no TECH_NAME, each deliberate)'.
  WRITE: / '  PARCELHINT  guidance paragraph, nothing to post'.
  WRITE: / '  REVIEW      the engine''s review renderer'.
  WRITE: / '  PAYFEE      the payment card; the card owns the payment state'.
  WRITE: / '  DOC_*       uploads post through the attachment channel'.
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
