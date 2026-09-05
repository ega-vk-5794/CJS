REPORT zrak_ec_captcha_load.

* Adds the CAPTCHA control to the Track e-Complaint (EC02) and Track
* e-Suggestion (EC06) search steps, on the security team's recommendation.
*
* WHY A FEEDER AND NOT A HAND-EDITED ROW. Both journeys are live config
* that this repository does not carry, so the row has to be created in the
* system rather than committed. A report is the version of that which can
* be read, reviewed and re-run; a row typed into SM30 is not.
*
* WHAT IT DOES NOT DO, deliberately: it never deletes a journey, a step, or
* any field other than the CAPTCHA one it owns. Every other seed report in
* this repository opens by clearing its own journey, which is right for a
* test journey and would be catastrophic here.
*
* THE STEP IS DISCOVERED, NOT TYPED. The captcha belongs on the SEARCH
* step - the one where the citizen enters the id and the mobile number -
* and that is the first step of both journeys. Reading it from
* ZRAK_T_JNY_STEP rather than hard-coding 'STEP1' means this still lands
* correctly if either journey was migrated with different step ids, which
* is not something to find out from a captcha appearing on the results
* screen.
*
* Test run is the default. Nothing is written until P_COMMIT is ticked.
*
* Re-runnable: the CAPTCHA row is deleted and re-inserted, so running it
* twice leaves one row, not two.

PARAMETERS p_commit TYPE abap_bool AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  DATA lt_jny TYPE TABLE OF zrak_t_jny-journey_id.
  DATA lv_seq TYPE zrak_t_jny_fld-seqnr.

  APPEND 'EC02' TO lt_jny.
  APPEND 'EC06' TO lt_jny.

  IF p_commit = abap_false.
    WRITE: / 'TEST RUN - nothing written. Tick "p_commit" to apply.'.
  ELSE.
    WRITE: / 'COMMIT RUN - rows will be written.'.
  ENDIF.
  SKIP.

  LOOP AT lt_jny INTO DATA(lv_jny).

    SELECT SINGLE journey_id FROM zrak_t_jny
      WHERE journey_id = @lv_jny
      INTO @DATA(lv_found).
    IF sy-subrc <> 0.
      WRITE: / lv_jny, ': journey not found - skipped.'.
      CONTINUE.
    ENDIF.

*   The first step by SEQNR is the search step on both journeys. Read
*   rather than assumed - see the header.
*   SELECT SINGLE does not take ORDER BY - it is UP TO 1 ROWS that does,
*   and the two are not interchangeable however alike they read.
    DATA lv_step TYPE zrak_t_jny_step-step_id.
    CLEAR lv_step.
    SELECT step_id FROM zrak_t_jny_step
      WHERE journey_id = @lv_jny
      ORDER BY seqnr
      INTO @lv_step
      UP TO 1 ROWS.
    ENDSELECT.
    IF lv_step IS INITIAL.
      WRITE: / lv_jny, ': no steps configured - skipped.'.
      CONTINUE.
    ENDIF.

*   Last on the step. The captcha is the final thing the citizen deals
*   with before pressing Next, and putting it above the fields it guards
*   reads as an obstacle placed before the form rather than after it.
    SELECT MAX( seqnr ) FROM zrak_t_jny_fld
      WHERE journey_id = @lv_jny
        AND step_id    = @lv_step
      INTO @lv_seq.
    lv_seq = lv_seq + 1.

    WRITE: / lv_jny, ': step', lv_step, '- CAPTCHA at seqnr', lv_seq.

    IF p_commit = abap_false.
      CONTINUE.
    ENDIF.

    DELETE FROM zrak_t_jny_fld
      WHERE journey_id = @lv_jny
        AND field_name = 'CAPTCHA'.

*   TECH_NAME AND REQUIRED ARE BOTH LEFT BLANK, and both are deliberate.
*
*   TECH_NAME blank: every other field on a journey needs it or the value
*   reaches the backend as nothing. A captcha answer is a gate, not data -
*   posting it would file the citizen's five digits in the case record for
*   no reason at all.
*
*   REQUIRED blank: ZCL_RAK_JOURNEY_RULES->VALIDATE_STEP( ) checks the
*   control itself and treats an empty box as a mismatch, and
*   MISSING_REQUIRED( ) skips FTYPE 'CAPTCHA' precisely so that ticking
*   this does not produce two errors for one blank field.
    INSERT zrak_t_jny_fld FROM @( VALUE #(
      mandt      = sy-mandt
      journey_id = lv_jny
      step_id    = lv_step
      field_name = 'CAPTCHA'
      seqnr      = lv_seq
      ftype      = 'CAPTCHA'
      zlabel     = 'Verification'
      zlabel_ar  = 'التحقق' ) ).
    IF sy-subrc <> 0.
      WRITE: / '  INSERT failed - row not written.'.
    ENDIF.

  ENDLOOP.

  IF p_commit = abap_true.
    COMMIT WORK AND WAIT.
    SKIP.
    WRITE: / 'Done. ZCL_RAK_JOURNEY_ENGINE, _RENDER, _RULES, _UTIL, _CSS,'.
    WRITE: / 'ZCL_RAK_CJS, ZCL_RAK_JOURNEY_DESIGNER and ZCL_RAK_TEXT must all be'.
    WRITE: / 'pulled and ACTIVATED first, or the field renders as a plain input'.
    WRITE: / 'and validates nothing - which looks exactly like a captcha that is'.
    WRITE: / 'switched on and broken.'.
    SKIP.
    WRITE: / 'Verify by content, not status: open the journey and look for the'.
    WRITE: / 'five-digit picture. Then type the wrong code and press Next - the'.
    WRITE: / 'step must refuse AND the picture must change.'.
  ENDIF.
