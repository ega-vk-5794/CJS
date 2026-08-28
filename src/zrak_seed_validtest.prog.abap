REPORT zrak_seed_validtest.

* Seeds one small, self-contained journey exercising the scalar-field
* validation fixes from the AS3 migration audit (feature/dev, a4981c1) -
* the counterpart to ZRAK_SEED_GRIDTEST, which covers the two grid-level
* findings. Nothing here needs a handler: every field is plain config.
*
*   - TRIGGER_INPUT / DEPENDENT_FIELD: an INPUT-triggered rule. Typing X
*     into TRIGGER_INPUT and immediately pressing Next - one action, one
*     round trip - should now block on DEPENDENT_FIELD being required.
*     Before the fix, VALIDATE_STEP( ) checked against the PREVIOUS round
*     trip's rule state, so this exact sequence went through once and only
*     failed on the round trip after.
*   - RO_REQ_BLANK: READONLY and REQUIRED, no DEFAULT_VAL. The citizen
*     cannot type into it and nothing seeds it, so Submit must now refuse -
*     before the fix, MISSING_REQUIRED( ) excluded every READONLY field and
*     this blank value reached the backend silently.
*   - RO_REQ_SEEDED: READONLY and REQUIRED, WITH a DEFAULT_VAL. Stands in
*     for a popup- or ON_INIT-seeded value - proves the same fix does not
*     block a readonly+required field that some other route DID fill.
*   - BOUNDED_NUMBER: MIN_VAL / MAX_VAL on an INPUT field. Values outside
*     1-10 must now be rejected on Submit; before the fix INPUT ignored
*     both silently.
*   - SECTION_FIELD_1 / _2: share a ZSECTION / ZSECTION_AR pair. Switch the
*     journey to Arabic (?lang=A) and the section heading over these two
*     fields should read in Arabic - before ZSECTION_AR existed this
*     heading had no Arabic form at all.
*   - OTR_LABEL_TEST: ZLABEL is 'OTR:ZRAK_CJS_TEST_NONEXISTENT_ALIAS'. No
*     such OTR concept exists on a fresh system, so this only proves the
*     FALLBACK half of the feature - the label should render as that
*     literal string, not blank. Create the OTR concept via SOTR_EDIT with
*     that exact alias and re-open the journey to see the resolved half.
*
* Dev/test only. BKND_ACTIVE and HANDLER_CLASS are both left blank.
*
* Re-runnable: deletes its own rows first, so running it twice is safe.
* Nothing outside journey_id 'ZVALIDTEST' is touched.

START-OF-SELECTION.

  DATA(lv_jny)  = 'ZVALIDTEST'.
  DATA(lv_step) = 'STEP1'.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = lv_jny.
  COMMIT WORK AND WAIT.

  INSERT zrak_t_jny FROM @( VALUE #(
    mandt       = sy-mandt
    journey_id  = lv_jny
    title       = 'Scalar Validation Feature Test'
    active      = 'X'
    layout_mode = 'WIZARD' ) ).

  INSERT zrak_t_jny_step FROM @( VALUE #(
    mandt      = sy-mandt
    journey_id = lv_jny
    step_id    = lv_step
    seqnr      = 1
    title      = 'Validation'
    active     = 'X' ) ).

  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'TRIGGER_INPUT'
      seqnr = 1 ftype = 'INPUT'
      zlabel = 'Type X here, then press Next in the same click/tab-out' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'DEPENDENT_FIELD'
      seqnr = 2 ftype = 'INPUT'
      zlabel = 'Required only once TRIGGER_INPUT = X (rule-driven)' )

    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'RO_REQ_BLANK'
      seqnr = 3 ftype = 'INPUT' readonly = 'X' required = 'X'
      zlabel = 'Readonly + required, never seeded - must block Submit' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'RO_REQ_SEEDED'
      seqnr = 4 ftype = 'INPUT' readonly = 'X' required = 'X' default_val = 'SEEDED'
      zlabel = 'Readonly + required, seeded via DEFAULT_VAL - must NOT block' )

    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'BOUNDED_NUMBER'
      seqnr = 5 ftype = 'INPUT' min_val = '1' max_val = '10'
      msg = 'Enter a number from 1 to 10.'
      zlabel = 'A number from 1 to 10 (INPUT, not NUMBER)' )

    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'SECTION_FIELD_1'
      seqnr = 6 ftype = 'INPUT'
      zsection = 'Test Section (bilingual)' zsection_ar = 'القسم التجريبي'
      zlabel = 'First field of the bilingual section' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'SECTION_FIELD_2'
      seqnr = 7 ftype = 'INPUT'
      zsection = 'Test Section (bilingual)' zsection_ar = 'القسم التجريبي'
      zlabel = 'Second field, same section' )

    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'OTR_LABEL_TEST'
      seqnr = 8 ftype = 'INPUT'
      zlabel = 'OTR:ZRAK_CJS_TEST_NONEXISTENT_ALIAS' ) ) ).

  INSERT zrak_t_jny_rule FROM @( VALUE #(
    mandt = sy-mandt journey_id = lv_jny rule_id = '0001'
    src_field = 'TRIGGER_INPUT' src_op = 'EQ' src_value = 'X'
    action = 'REQUIRE' tgt_field = 'DEPENDENT_FIELD' ) ).

  COMMIT WORK AND WAIT.

  WRITE: / 'Seeded journey', lv_jny.
  WRITE: / 'Open it the same way you open any CJS journey, with journey=' && lv_jny.
  WRITE: / ' '.
  WRITE: / 'Round-trip timing: type X into TRIGGER_INPUT, then press Next straight away -'.
  WRITE: / 'one action. DEPENDENT_FIELD should be flagged required on THIS round trip, not'.
  WRITE: / 'only on the one after.'.
  WRITE: / ' '.
  WRITE: / 'Required-on-readonly: press Next/Submit without changing anything else.'.
  WRITE: / 'RO_REQ_BLANK should block it; RO_REQ_SEEDED (same flags, but pre-filled)'.
  WRITE: / 'should not.'.
  WRITE: / ' '.
  WRITE: / 'INPUT bounds: type 0 or 11 into BOUNDED_NUMBER and press Next - both should now'.
  WRITE: / 'be rejected with the configured message.'.
  WRITE: / ' '.
  WRITE: / 'Section AR: reopen with ?lang=A appended to the URL. The heading over'.
  WRITE: / 'SECTION_FIELD_1 / SECTION_FIELD_2 should read in Arabic.'.
  WRITE: / ' '.
  WRITE: / 'OTR fallback: OTR_LABEL_TEST''s label should read the literal string'.
  WRITE: / '"OTR:ZRAK_CJS_TEST_NONEXISTENT_ALIAS", not be blank - proving a missing OTR'.
  WRITE: / 'concept degrades to the stored text rather than an empty label.'.
