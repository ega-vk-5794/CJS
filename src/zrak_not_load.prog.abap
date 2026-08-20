REPORT zrak_not_load.

*&---------------------------------------------------------------------*
*& NOT - Notary Public Declarations
*&
*& The first feeder for this journey. Every other journey in the repo has
*& a ZRAK_<code>_LOAD; Notary had none, so its configuration existed only
*& in the database - invisible to git, not re-runnable, and impossible to
*& review against the screens it is supposed to match.
*&
*& NOT migrated with ZCL_RAK_MIGRATOR. The migrator reads
*& /QNV/SB_UI_DEFIN, and Notary is not a ShapeIt screen - it is an
*& external REST API. There are no legacy rows to derive from, so this is
*& hand-authored like the E014/E015 family, and the source is named per
*& step below.
*&
*& STRUCTURE - the portal shows eight steps
*& (Screenshots/Step 2/EN/1.png has the whole strip); this journey has
*& NINE, and the extra one is forced by the API rather than chosen:
*&
*&   portal                          here          posts
*&   -----------------------------------------------------------------
*&   Service Classifications         STP1          -
*&   Service Definition              STP2          -
*&   Add First Party (Confessor)     STP3          PARTY1
*&   Add Second Party (for)          STP4          PARTY2
*&   Service Information             STP5          BO
*&     ...Other Info section         STP6          VISIT
*&   Legal Text                      STP7          LEGAL
*&   Service Documents               STP8          - (ATTACH hook)
*&   Preview                         STP9          BILLING
*&
*& The portal puts the visit radio inside Service Information. STEP_COMMIT( )
*& takes one screen per step, so a step named 'BO' posts the business object
*& and nothing else - keeping the visit on that page would mean it was never
*& sent. See the comment on STP6.
*&
*& The party step titles carry a declaration-specific suffix on the live
*& screen - "(The Confessor)" / "(The Confession for)". Those words belong
*& to the sub-service, not to the journey, so the titles here are the
*& neutral ones and the suffix is left to ZCL_RAK_CJ_TXT_IO per
*& sub-service. Hard-coding one declaration's wording into the journey
*& header would put "Confessor" on a marine vehicle sale.
*&
*& ONE BUSINESS OBJECT PER DECLARATION. Confirmed: the API is singular
*& (POST /businessobject, PUT/GET/DELETE /businessobject/{id}) and
*& ZCL_RAK_BE_NOT->BO_JSON( ) builds one flat object. The live screen
*& labels the section "Business Object/s" and offers an Add button, but
*& that plural is the portal's, not the contract's.
*&
*& So STP5 carries NO configured business-object fields. Every one of them
*& comes from the blueprint at runtime:
*&   ZCL_RAK_BE_NOT->DESCRIBE_STEP( 'BO' ) reads the sub-service JSON and
*&   returns name / label / label_ar / type / required / max_len / regex
*&   and the choices, and the engine's MERGE_DYNAMIC_STEPS( ) appends them
*&   to whichever step names BKND_SCREEN = 'BO'.
*& A field configured here would be a second, stale definition of
*& something the blueprint already describes - and for the declarations
*& whose businessFields is an empty array (Approval & Signature, No
*& Objection, Pledge, Clearance) the engine now drops the step entirely,
*& which a configured field would prevent.
*&
*& TRANSFER / VISIT is the "Transfer a request?" Disable / Enable radio,
*& and the visit fields are hidden until it says Enable. That is the rule
*& block at the end of this program - the reveal is configuration, exactly
*& as the house rule asks, not ABAP in on_change( ).
*&
*& The radio's TECH_NAME is visit_required and its Enable key is 'X',
*& because STEP_COMMIT( )'s VISIT branch tests
*&   field( 'visit_required' ) <> 'X' -> return
*& Any other key and the step would render, validate, and post nothing.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside
*& journey_id 'NOT'.
*&
*& STILL OPEN - do not read this program as a finished specification:
*&   - The Notary credential is rejected (Q1 in the clarification
*&     document), so none of this has been exercised end to end.
*&   - Fields are the ones the screenshots show.
*&     Where a screen was not captured the field is absent rather than
*&     guessed, and the section comment says so.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'NOT'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- header
* BKND_CATEGORY 'NOTARY' is what ZCL_RAK_BE_FACTORY matches to hand this
* journey to ZCL_RAK_BE_NOT. Anything it does not recognise falls through
* to the QNV bridge, which would post a Notary declaration into ShapeIt.
*
* WIZARD_LEFT, not WIZARD: eight steps do not fit across the top of the
* page, and the live portal itself wraps its strip onto two rows. The
* left rail also gives the citizen the step names in full.
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = 'Notary Public Declaration'
    title_ar      = 'إقرار الكاتب العدل'
    subtitle      = 'Declarations and attestations'
    subtitle_ar   = 'الإقرارات والتصديقات'
    layout_mode   = 'WIZARD_LEFT'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_RAK_NOT_APPROVAL_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'NOTARY' ) ).

* ---------------------------------------------------------------- steps
* BKND_SCREEN is what the engine hands to DESCRIBE_STEP( ) and
* STEP_COMMIT( ), so these are the backend's own names and not screen
* numbers. 'BO' is the one DESCRIBE_STEP answers.
*
* No NEXT_REQUIRES on STP4. Whether a second party is mandatory depends on
* the declaration and the blueprint is what knows - a gate configured here
* would demand one on every declaration, including the ones the
* clarification table lists as Optional.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
*   STP1 and STP2 name NO backend screen, and that is not an omission.
*   The draft is created in ZCL_RAK_BE_NOT->INIT( ) - POST
*   /request/events/draft - which the engine runs when the journey starts,
*   before any step commits. STEP_COMMIT( ) answers PARTY1, PARTY2, BO,
*   VISIT/TRANSFER, LEGAL and BILLING and nothing else, so a screen name it
*   does not know would fall to WHEN OTHERS and post nothing while looking
*   configured. A blank screen says the truth: these two steps choose the
*   declaration, they do not send anything.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Service Classifications' title_ar = 'تصنيفات الخدمة'
      icon = 'sap-icon://tree' columns = 2 active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Service Definition' title_ar = 'تعريف الخدمة'
      icon = 'sap-icon://document-text' columns = 2 active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'First Party' title_ar = 'الطرف الأول'
      icon = 'sap-icon://person-placeholder' bknd_screen = 'PARTY1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 40
      title = 'Second Party' title_ar = 'الطرف الثاني'
      icon = 'sap-icon://group' bknd_screen = 'PARTY2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 50
      title = 'Service Information' title_ar = 'معلومات الخدمة'
      icon = 'sap-icon://form' bknd_screen = 'BO' columns = 2 active = 'X' )
*   The visit is a STEP OF ITS OWN, and this is the one place the journey
*   diverges from the portal on purpose. The live screen puts the "Transfer
*   a request?" radio in Service Information's Other Info section, on the
*   same page as the business object. It cannot go there here: STEP_COMMIT( )
*   is called once per step with that step's screen, so a step named 'BO'
*   posts the business object and only the business object - the visit would
*   never be sent.
*
*   Costs nothing when the citizen does not want a visit. STEP_COMMIT( )'s
*   VISIT branch returns early unless visit_required = 'X', so an untouched
*   step posts nothing at all.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 60
      title = 'Visit Request' title_ar = 'طلب زيارة'
      icon = 'sap-icon://addresses' bknd_screen = 'VISIT' columns = 2 active = 'X' )
*   'LEGAL', not 'LEGALTEXT'. STEP_COMMIT( ) matches 'LEGAL' and would have
*   dropped the longer name into WHEN OTHERS - the legal text would have been
*   shown, edited and never PUT.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP7' seqnr = 70
      title = 'Legal Text' title_ar = 'النص القانوني'
      icon = 'sap-icon://legal-section' bknd_screen = 'LEGAL' active = 'X' )
*   Attachments do NOT go through STEP_COMMIT( ). The engine calls
*   ZIF_RAK_JOURNEY_BACKEND~ATTACH( ) for staged files, which is why
*   CAPABILITIES reports attachments = true. A screen name here would post
*   an empty body on top of that.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP8' seqnr = 80
      title = 'Service Documents' title_ar = 'مستندات الخدمة'
      icon = 'sap-icon://attachment' active = 'X' )
*   BILLING sets the paying party - step 12 of the API flow, and it runs
*   before submit. SUBMIT itself is not a step screen: the engine calls
*   ZIF_RAK_JOURNEY_BACKEND~SUBMIT( ) from the footer.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP9' seqnr = 90
      title = 'Preview' title_ar = 'المعاينة'
      icon = 'sap-icon://inspection' bknd_screen = 'BILLING' active = 'X' ) ) ).

* --------------------------------------------------- STP1 / STP2 fields
* Service Classification and Main Service are fixed on the live screen -
* "declaration attestation, this is the one you cannot change" - so they
* are DISPLAY, not selects. Only the sub-service is chosen, and its list
* is a live endpoint, so no OPT rows: ON_VALUE_HELP on the handler answers
* SUBSERVICE.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'CLASSIFICATION' ftype = 'DISPLAY'
      zlabel = 'Service Classification' zlabel_ar = 'تصنيف الخدمة'
      default_val = 'Declaration Attestation' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'MAINSERVICE' ftype = 'DISPLAY'
      zlabel = 'Main Service' zlabel_ar = 'الخدمة الرئيسية'
      default_val = 'Declaration Attestation' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'SUBSERVICE' ftype = 'SELECT' required = 'X'
      zlabel = 'Declaration Type' zlabel_ar = 'نوع الإقرار'
      placeholder = 'Choose the declaration'
      tech_name = 'subServiceId' )

*   The request the draft call returns. Held so a resumed journey can find
*   its own draft again, and shown because the live screen puts it in the
*   success toast ("Request with request id : 13,243 created successfully").
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'REQUEST_ID' ftype = 'DISPLAY' readonly = 'X'
      zlabel = 'Request' zlabel_ar = 'الطلب' ) ) ).

* --------------------------------------------------- STP3 / STP4 fields
* The party STEPS are lists, not forms: Party Name / Mobile Number /
* Nationality / Action, with view and contact icons per row and an Add
* Party button underneath. So the visible control on each step is a TABLE
* fed by the handler, and the identity fields belong to the popup that
* adds a row - they are not laid out here.
*
* PARTY1 / PARTY2 are READONLY tables for the same reason E027's licence
* grid is: a row is added through the search, not typed. Letting a citizen
* edit a name in the grid would send the officer a party MOI never
* confirmed.
*
* The Add-party popup, the view popup and the contact edit are NOT
* configured fields. They are handler-owned dialogs -
* ON_RENDER_POPUP( ) - because each is a search plus a result plus an
* attachment, which is exactly the case dialog_form( ) cannot express.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PARTY1' ftype = 'TABLE' readonly = 'X'
      zlabel = 'First Party' zlabel_ar = 'الطرف الأول'
      default_val = 'NAME:Party Name:TEXT|MOBILE:Mobile Number:TEXT|NAT:Nationality:TEXT' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP4' seqnr = 10
      field_name = 'PARTY2' ftype = 'TABLE' readonly = 'X'
      zlabel = 'Second Party' zlabel_ar = 'الطرف الثاني'
      default_val = 'NAME:Party Name:TEXT|MOBILE:Mobile Number:TEXT|NAT:Nationality:TEXT' ) ) ).

* --------------------------------------------------------- STP5 fields
* General Info first, read-only, exactly the four the live screen shows.
* They repeat what STP1/STP2 hold: the live screen restates them here
* because Service Information is where the citizen checks they picked the
* right declaration before filling it in.
*
* Then NOTHING for the business object. Every business-object field comes
* from the blueprint through DESCRIBE_STEP( 'BO' ) - see the header. This
* is the one step whose form is genuinely built at runtime.
*
* Then Other Info: the transfer radio and the visit fields it reveals.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 10
      field_name = 'GI_CLASSIFICATION' ftype = 'DISPLAY'
      zsection = 'General Info'
      zlabel = 'Service Classification' zlabel_ar = 'تصنيف الخدمة' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 20
      field_name = 'GI_MAINSERVICE' ftype = 'DISPLAY'
      zsection = 'General Info'
      zlabel = 'Main Service' zlabel_ar = 'الخدمة الرئيسية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 30
      field_name = 'GI_SUBSERVICE' ftype = 'DISPLAY'
      zsection = 'General Info'
      zlabel = 'Sub Service' zlabel_ar = 'الخدمة الفرعية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP5' seqnr = 40
      field_name = 'GI_APPLICANT' ftype = 'DISPLAY'
      zsection = 'General Info'
      zlabel = 'Applicant' zlabel_ar = 'مقدم الطلب' )

*   Blueprint business-object fields are merged in at seqnr 100+ by the
*   engine, between General Info above and Other Info below.

*   RADIO, not SEGMENTED. The live control is a two-option radio that
*   opens with Disable already chosen, and a SEGMENTED with no default
*   renders its first option selected - which for a fee-bearing visit
*   would be a citizen submitting an answer they never gave. DEFAULT_VAL
*   names the neutral option explicitly.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 200
      field_name = 'VISIT_REQUIRED' ftype = 'RADIO' required = 'X'
      zsection = 'Other Info'
      zlabel = 'Transfer a request?' zlabel_ar = 'طلب زيارة؟'
*     visit_required / 'X' is not a style choice - see the header. Anything
*     else and STEP_COMMIT( ) returns before it posts.
      tech_name = 'visit_required'
      default_val = 'N' )

*   Everything below is hidden until the radio says Enable - the rule block below.
*   HIDDEN is set here as well as ruled: a rule fires on evaluation, and the
*   first render of the step happens before the citizen has touched anything.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 210
      field_name = 'VISIT_REASONID' ftype = 'SELECT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Reason' zlabel_ar = 'السبب'
      tech_name = 'visit_reasonId' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 220
      field_name = 'VISIT_REASONOTHER' ftype = 'INPUT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Reason (other)' zlabel_ar = 'سبب آخر'
      tech_name = 'visit_reasonOther' max_len = 200 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 230
      field_name = 'VISIT_EMIRATEID' ftype = 'SELECT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Emirate' zlabel_ar = 'الإمارة'
      tech_name = 'visit_emirateId' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 240
      field_name = 'VISIT_CITY' ftype = 'SELECT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'City' zlabel_ar = 'المدينة'
      tech_name = 'visit_city' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 250
      field_name = 'VISIT_REGION' ftype = 'SELECT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Region' zlabel_ar = 'المنطقة'
      tech_name = 'visit_region' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 260
      field_name = 'VISIT_STREETNAME' ftype = 'INPUT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Street' zlabel_ar = 'الشارع'
      tech_name = 'visit_streetName' max_len = 100 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 270
      field_name = 'VISIT_HOUSENUMBER' ftype = 'INPUT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'House number' zlabel_ar = 'رقم المنزل'
      tech_name = 'visit_houseNumber' max_len = 20 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 280
      field_name = 'VISIT_ADDRESS' ftype = 'TEXTAREA' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Address' zlabel_ar = 'العنوان'
      tech_name = 'visit_address' max_len = 250 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 290
      field_name = 'VISIT_CONTACTNUMBER' ftype = 'INPUT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Contact number' zlabel_ar = 'رقم الاتصال'
      tech_name = 'visit_contactNumber' max_len = 20 )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 300
      field_name = 'VISIT_DATE' ftype = 'DATE' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Visit date' zlabel_ar = 'تاريخ الزيارة'
      tech_name = 'visit_date' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 310
      field_name = 'VISIT_TIME' ftype = 'INPUT' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Visit time' zlabel_ar = 'وقت الزيارة'
      tech_name = 'visit_time' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6' seqnr = 320
      field_name = 'VISIT_NOTES' ftype = 'TEXTAREA' hidden = 'X'
      zsection = 'Visit Details'
      zlabel = 'Notes' zlabel_ar = 'ملاحظات'
      tech_name = 'visit_transferNotes' max_len = 250 ) ) ).

* ---------------------------------------------------- VISIT_REQUIRED opts
* Disable first, and it is the default. The live screen opens on Disable.
  INSERT zrak_t_jny_opt FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6'
      field_name = 'VISIT_REQUIRED' opt_key = 'N' seqnr = 10
      opt_text = 'Disable' opt_text_ar = 'تعطيل' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP6'
      field_name = 'VISIT_REQUIRED' opt_key = 'X' seqnr = 20
      opt_text = 'Enable' opt_text_ar = 'تمكين' ) ) ).

* --------------------------------------------------- STP6 / STP7 / STP8
* LEGAL_TEXT is a TABLE because the blueprint sends HTML and the handler
* already splits it into paragraphs - GET_TABLE( 'ARABICLEGALTEXT' ). One
* paragraph per row reads as a document; one long string in a TEXTAREA
* does not.
*
* Editing it is deliberately NOT offered. The live portal has an Edit
* button, and when asked whether a citizen is meant to rewrite the legal
* text of a notarised instrument the answer on the call was "business-wise,
* I don't know... you need to ask Mostafa". Until somebody says yes, the
* text is shown and not typed over.
*
* TRANSLATION is here rather than on the legal-text section of some other
* step because it changes the fee, and the fee is quoted at Preview.
*
* ATTACHMENTS: no configured fields. The blueprint carries the document
* list per declaration - id, name, mandatory, multiple, accepted mime
* types - and DESCRIBE_STEP is the way that reaches the engine. Naming
* documents here would hard-code one declaration's list onto all of them.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP7' seqnr = 10
      field_name = 'LEGAL_TEXT' ftype = 'TABLE' readonly = 'X'
      zlabel = 'Legal Text' zlabel_ar = 'النص القانوني'
      tech_name = 'ARABICLEGALTEXT' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP7' seqnr = 20
      field_name = 'TRANSLATION' ftype = 'CHECKBOX'
      zlabel = 'Translate the declaration' zlabel_ar = 'ترجمة الإقرار'
      default_val = '' )

*   INTERIM, and the comment is the point. The blueprint carries the real
*   document list per declaration - attachment id, name, mandatory, multiple,
*   accepted mime types - and DOC_TYPES( ) already exposes it, but nothing
*   RENDERS it: DESCRIBE_STEP( ) answers 'BO' and nothing else, so a
*   documents step driven by the blueprint is not expressible yet. Without
*   this field STP8 draws a heading and nothing else.
*
*   So one multi-file uploader, and the per-document list is the follow-up.
*   ATTACH( ) already validates what arrives against DOC_TYPES( ), so a file
*   the declaration does not accept is still refused - the citizen just is
*   not told up front which documents are expected, or which are mandatory.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP8' seqnr = 10
      field_name = 'DOCUMENTS' ftype = 'UPLOAD'
      zlabel = 'Service Documents' zlabel_ar = 'مستندات الخدمة'
      has_attach = 'X' attach_multi = 'X'
      attach_label = 'Attach the declaration documents'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 10 )

*   Preview is the engine's own summary plus the fee. PAYFEE draws the
*   payment card; the Notary API owns the initial payment end to end, which
*   is why CAPABILITIES reports payment = true.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP9' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Fees' zlabel_ar = 'الرسوم' ) ) ).

* ---------------------------------------------------------------- rules
* The visit reveal. One SHOW per field rather than one rule over a group,
* because ZRAK_T_JNY_RULE targets a field and FGROUP is already carrying
* the shared-row token on this journey.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R001'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_REASONID' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R002'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_EMIRATEID' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R003'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_CITY' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R004'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_REGION' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R005'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_STREETNAME' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R006'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_ADDRESS' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R007'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_DATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R008'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_TIME' )

*   The remaining visit fields are optional detail, revealed the same way.
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R009'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_REASONOTHER' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R010'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_HOUSENUMBER' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R011'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_CONTACTNUMBER' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R012'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'VISIT_NOTES' )

*   Required only once the visit is asked for. A visit date the citizen
*   cannot see must not block Next.
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R013'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'REQUIRE' tgt_field = 'VISIT_DATE' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R014'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'REQUIRE' tgt_field = 'VISIT_EMIRATEID' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R015'
      src_field = 'VISIT_REQUIRED' src_op = 'EQ' src_value = 'X'
      action = 'REQUIRE' tgt_field = 'VISIT_CONTACTNUMBER' ) ) ).

  COMMIT WORK AND WAIT.

  WRITE: / 'NOT journey loaded.'.
  WRITE: / '  8 steps. Business-object and attachment fields come from the'.
  WRITE: / '  blueprint at runtime - none are configured here on purpose.'.
  WRITE: / '  Run ZRAK_CJS_XCHECK afterwards.'.
  WRITE: / '  NOT exercised end to end: the Notary credential is rejected'.
  WRITE: / '  (Q1 in the clarification document).'.
