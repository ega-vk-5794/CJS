*&---------------------------------------------------------------------*
*& Report ZRAK_CJ_TESTKEY
*&
*& A portal session key for testing, without a portal.
*&
*& WHY THIS EXISTS. Every <Set>_GET_ENTITYSET on ZCL_ZEGA_CJ_DPC_EXT
*& resolves its caller through GET_BP( ), which reads 'x-custom1' as a key
*& into ZEGA_T_CJ_US_LOG. A real journey gets that key on its launch URL as
*& &userdata=. Testing the wrapper layer from SE38 or a bare launch has no
*& portal in front of it, so there is no key and no row - and every one of
*& the dozen code paths that consume the resolved partner reads blank.
*&
*& This creates the row the portal would have created, and hands back the
*& key to paste into ZRAK_CJ_REQCTX_DIAG or onto a launch URL.
*&
*& IT IS A COPY, NOT AN IMITATION. The key generation and encryption below
*& are lifted verbatim from ZCL_ZEGA_CJ_UTILITY_DPC_EXT->
*& ENCRYPTUSERSET_GET_ENTITYSET, which is what the portal actually calls.
*& That includes one thing that looks like a mistake and must not be
*& "fixed": the row is written with
*&
*&     encrypt_iv( ... algorithm = co_aes256_algorithm_pem )
*&
*& and read back by GET_BP( ) with
*&
*&     decrypt( ... algorithm = co_aes256_algorithm )
*&
*& Different constants, and an IV on the way in but not on the way out.
*& Whatever the reason, that pairing is what every live portal row uses, so
*& a row written any other way would decrypt to nothing. Copy it exactly.
*&
*& E10 ONLY. Guarded on SY-SYSID before anything else runs. This writes a
*& session row that GET_BP( ) will trust, which is a credential in every
*& sense that matters - it has no business existing outside development.
*&
*& NOTHING IS WRITTEN UNLESS YOU ASK. The default is a dry run: it resolves
*& and verifies, and reports what it would have done.
*&---------------------------------------------------------------------*
REPORT zrak_cj_testkey.

TABLES sscrfields.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_bp   TYPE bu_partner DEFAULT '1000116563'.
*  The internet user whose row this is. Left blank, the report finds it:
*  ZEGA_T_CJ_US_LOG-ID holds the internet user in CLEAR TEXT (only the
*  copy in ENCRYPT_KEY is encrypted), so an existing row for the same
*  citizen names it.
PARAMETERS p_user TYPE zega_t_cj_us_log-id.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_list  AS CHECKBOX.
PARAMETERS p_write AS CHECKBOX.
PARAMETERS p_deact AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b02.

START-OF-SELECTION.

* ---------------------------------------------------------------------
* The guard, first, before anything is read or written.
* ---------------------------------------------------------------------
  IF sy-sysid <> 'E10'.
    WRITE: / 'Refused. This report writes a session row GET_BP( ) will trust,'.
    WRITE: / 'which is a credential. It runs in E10 only.'.
    WRITE: / 'This system is', sy-sysid.
    RETURN.
  ENDIF.

  DATA lv_user TYPE zega_t_cj_us_log-id.
  DATA lv_bp   TYPE bu_partner.

* THE FUNCTION MODULE TAKES A STRING, and it is strict about it.
* ZFM_EGA_GET_BP_FROM_INTERNET_U's IV_INTERNET_USER would not accept a
* variable typed ZEGA_T_CJ_US_LOG-ID - "a field may have been assigned to the
* parameter IV_INTERNET_USER whose type is not compatible with this
* parameter" - and the call raised on every row.
*
* Caught and cleared, that looked exactly like a function module that
* resolves nobody, and it was read that way: the list showed a blank partner
* for every user and the conclusion drawn was that E10 has no resolvable
* users. It has. GET_BP( ) resolves them fine, because it declares
* USER TYPE STRING and passes that.
*
* Every call below goes through LV_FM_USER for that reason.
  DATA lv_fm_user TYPE string.

* ---------------------------------------------------------------------
* 0. What does the table already hold?
*
*    "No internet user found" has two very different causes - the table
*    has rows but none for this partner, or the table is empty in this
*    system. They need opposite next steps and look identical from the
*    outside, so this shows which.
*
*    It also answers the more useful question: if this partner cannot be
*    tested with, WHICH ONE CAN.
* ---------------------------------------------------------------------
  IF p_list = abap_true.
    SELECT id, user_key, active, usertype, date_init
      FROM zega_t_cj_us_log
      ORDER BY date_init DESCENDING
      INTO TABLE @DATA(lt_all)
      UP TO 100 ROWS.

    IF lt_all IS INITIAL.
      WRITE: / 'ZEGA_T_CJ_US_LOG is EMPTY in', sy-sysid, '- nobody has logged in'.
      WRITE: / 'through the portal on this system, so there is no row to copy and'.
      WRITE: / 'no internet user to find. Supply one by hand, or use a system'.
      WRITE: / 'where the portal has been used.'.
      RETURN.
    ENDIF.

    WRITE: /  'Internet user', 32 'Active', 41 'Type', 48 'Created', 60 'Resolves to BP'.
    ULINE.
    LOOP AT lt_all INTO DATA(ls_all).
      CLEAR lv_bp.
      IF ls_all-id IS NOT INITIAL AND ls_all-id <> 'ANON'.
        TRY.
            lv_fm_user = ls_all-id.
            CALL FUNCTION 'ZFM_EGA_GET_BP_FROM_INTERNET_U'
              EXPORTING
                iv_internet_user    = lv_fm_user
              IMPORTING
                ev_business_partner = lv_bp.
          CATCH cx_root.
            CLEAR lv_bp.
        ENDTRY.
      ENDIF.
      WRITE: /  ls_all-id,
             32 ls_all-active,
             41 ls_all-usertype,
             48 ls_all-date_init,
             60 lv_bp.
    ENDLOOP.
    SKIP.
    WRITE: / 'Pick a row whose Active is X and whose BP is not blank, then run'.
    WRITE: / 'again with that BP - or with that internet user in the second field.'.
    WRITE: / 'A blank BP means the function module does not know that user.'.
    RETURN.
  ENDIF.

  lv_user = p_user.

* ---------------------------------------------------------------------
* 1. Which internet user is this partner?
*
*    There is no reverse of ZFM_EGA_GET_BP_FROM_INTERNET_U and
*    ZEGA_T_CJ_US_LOG has no partner column, so the mapping cannot be
*    looked up. It CAN be searched: ID holds the internet user in clear,
*    so every distinct one is a candidate to run forwards through the FM.
*    Bounded, because this is a convenience and not a scan job.
* ---------------------------------------------------------------------
  IF lv_user IS INITIAL.
    SELECT DISTINCT id FROM zega_t_cj_us_log
      WHERE id <> @space AND id <> 'ANON'
      INTO TABLE @DATA(lt_cand)
      UP TO 500 ROWS.

    LOOP AT lt_cand INTO DATA(ls_cand).
      CLEAR lv_bp.
      TRY.
          lv_fm_user = ls_cand-id.
          CALL FUNCTION 'ZFM_EGA_GET_BP_FROM_INTERNET_U'
            EXPORTING
              iv_internet_user    = lv_fm_user
            IMPORTING
              ev_business_partner = lv_bp.
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
      IF lv_bp = p_bp.
        lv_user = ls_cand-id.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_user IS INITIAL.
      WRITE: / 'No internet user found for partner', p_bp.
      WRITE: / 'ZEGA_T_CJ_US_LOG has no row whose ID maps to it.'.
      SKIP.
      WRITE: / 'Two ways on:'.
      WRITE: / '  - tick "List what the table holds" to see which partners CAN'.
      WRITE: / '    be tested with on this system'.
      WRITE: / '  - or type the internet user for this partner in the second'.
      WRITE: / '    field. It is the portal login, not the SAP user.'.
      RETURN.
    ENDIF.
    WRITE: / 'Found internet user', lv_user, 'for partner', p_bp.
  ENDIF.

* ---------------------------------------------------------------------
* 2. Verify it really is that partner, forwards, through the same
*    function module GET_BP( ) will use. Refuse rather than write a row
*    that resolves to somebody else.
* ---------------------------------------------------------------------
  CLEAR lv_bp.
  TRY.
      lv_fm_user = lv_user.
      CALL FUNCTION 'ZFM_EGA_GET_BP_FROM_INTERNET_U'
        EXPORTING
          iv_internet_user    = lv_fm_user
        IMPORTING
          ev_business_partner = lv_bp.
    CATCH cx_root INTO DATA(lx_fm).
      WRITE: / 'ZFM_EGA_GET_BP_FROM_INTERNET_U raised:', lx_fm->get_text( ).
  ENDTRY.

  IF lv_bp IS NOT INITIAL AND lv_bp <> p_bp.
*   A real mismatch: the function module knows this user and says it is
*   somebody else. Never write that row.
    WRITE: / 'Refused. Internet user', lv_user, 'resolves to partner', lv_bp.
    WRITE: / 'which is not', p_bp.
    RETURN.
  ENDIF.

  IF lv_bp IS INITIAL.
*   A BLANK resolve is a different thing entirely, and on a development
*   system it is the normal thing. It means the function module does not
*   know this internet user - not that the session row would be wrong.
*   None of the users already in ZEGA_T_CJ_US_LOG on E10 resolve.
*
*   So: refuse when the user was GUESSED, because a guess that cannot be
*   confirmed is worth nothing. Continue when the user was SUPPLIED, because
*   then it is the tester's assertion and the row still proves everything
*   this report exists to prove - that the key, the row and the decrypt
*   round-trip. The partner lookup is downstream of all of that.
    IF p_user IS INITIAL.
      WRITE: / 'Refused. The internet user was found by searching, and'.
      WRITE: / 'ZFM_EGA_GET_BP_FROM_INTERNET_U does not resolve it, so there'.
      WRITE: / 'is nothing to confirm it against. Supply the user explicitly'.
      WRITE: / 'if you know it is right.'.
      RETURN.
    ENDIF.
    WRITE: / 'Warning:', lv_user, 'does not resolve to any partner here.'.
    WRITE: / 'Continuing because you supplied it. The row and the decrypt will'.
    WRITE: / 'still be proved; GET_BP( ) will return the user but a blank'.
    WRITE: / 'partner, which is the function module, not this layer.'.
  ELSE.
    WRITE: / 'Verified:', lv_user, '->', lv_bp.
  ENDIF.
  SKIP.

* ---------------------------------------------------------------------
* 3. An ACTIVE row may already exist. Reuse it - the portal does not
*    create a second one per login either, and a spare active row is a
*    spare credential.
* ---------------------------------------------------------------------
  SELECT SINGLE user_key FROM zega_t_cj_us_log
    WHERE id = @lv_user AND active = @abap_true
    INTO @DATA(lv_have).
  IF sy-subrc = 0.
    WRITE: / 'An ACTIVE row already exists for this user. Use its key:'.
    WRITE: / lv_have.
    SKIP.
    PERFORM show_usage.
    IF p_deact = abap_true.
      UPDATE zega_t_cj_us_log SET active = @space
        WHERE user_key = @lv_have.
      COMMIT WORK.
      WRITE: / 'Deactivated, as asked. GET_BP( ) will no longer resolve it.'.
    ENDIF.
    RETURN.
  ENDIF.

* ---------------------------------------------------------------------
* 4. Build the row exactly as ENCRYPTUSERSET_GET_ENTITYSET does.
* ---------------------------------------------------------------------
  DATA lv_iv        TYPE xstring.
  DATA lv_key       TYPE xstring.
  DATA lv_enc       TYPE xstring.
  DATA lv_data      TYPE string.
  DATA lv_data_x    TYPE xstring.
  DATA ls_login     TYPE zega_t_cj_us_log.

  TRY.
      lv_iv    = '00000000000000000000000000000000'.
      lv_key   = cl_sec_sxml_writer=>generate_key( algorithm = cl_sec_sxml_writer=>co_aes256_algorithm ).
      lv_data  = lv_user.
      lv_data_x = cl_bcs_convert=>string_to_xstring( iv_string = lv_data ).

*     _PEM here and NOT _PEM in GET_BP( )'s decrypt. See the header - this
*     asymmetry is the live behaviour, not a slip to correct.
      cl_sec_sxml_writer=>encrypt_iv(
        EXPORTING
          plaintext  = lv_data_x
          key        = lv_key
          iv         = lv_iv
          algorithm  = cl_sec_sxml_writer=>co_aes256_algorithm_pem
        IMPORTING
          ciphertext = lv_enc ).
    CATCH cx_root INTO DATA(lx_enc).
      WRITE: / 'Encryption failed:', lx_enc->get_text( ).
      RETURN.
  ENDTRY.

  IF lv_enc IS INITIAL.
    WRITE: / 'Encryption produced nothing. No row written.'.
    RETURN.
  ENDIF.

  ls_login-user_key   = lv_key.
  ls_login-encrypt_key = lv_enc.
  ls_login-id         = lv_user.
  ls_login-date_init  = sy-datum.
  ls_login-time_init  = sy-timlo.
  ls_login-active     = abap_true.
* USERTYPE stays blank, which is anything other than '1'. That matters:
* GET_BP( ) treats '1' as the SOP1 back door and takes the partner from
* TVARVC parameter ZCJSOP1BP instead of from this row, which would give
* every test the same partner regardless of what was asked for.
  CLEAR ls_login-usertype.

  IF p_write = abap_false.
    WRITE: / 'DRY RUN. Tick "Write the row" to create it.'.
    WRITE: / 'Would write ZEGA_T_CJ_US_LOG: id =', lv_user.
    WRITE: / '  active = X, usertype = blank, date/time = now'.
    RETURN.
  ENDIF.

  MODIFY zega_t_cj_us_log FROM ls_login.
  IF sy-subrc <> 0.
    WRITE: / 'MODIFY failed, sy-subrc', sy-subrc.
    RETURN.
  ENDIF.
  COMMIT WORK AND WAIT.
  WRITE: / 'Row written.'.
  SKIP.

* ---------------------------------------------------------------------
* 5. Prove it round-trips. Writing a row that cannot be decrypted back is
*    the one failure this report must never report as success.
* ---------------------------------------------------------------------
  DATA lv_back_user TYPE string.
  DATA lv_back_bp   TYPE bu_partner.
  TRY.
      zcl_zega_cj_utility_dpc_ext=>get_bp(
        EXPORTING key     = lv_key
        IMPORTING user    = lv_back_user
                  partner = lv_back_bp ).
    CATCH cx_root INTO DATA(lx_back).
      lv_back_user = lx_back->get_text( ).
  ENDTRY.

  WRITE: / 'GET_BP( key ) returns user   :', lv_back_user.
  WRITE: / 'GET_BP( key ) returns partner:', lv_back_bp.
  SKIP.

* THE ROUND TRIP IS THE USER, NOT THE PARTNER. Everything this report is
* responsible for ends at the decrypted user coming back: the key was
* generated, the row was found by it, ACTIVE was honoured, and the
* ciphertext decrypted to what went in. The partner is one function-module
* call further on and can be blank for reasons that have nothing to do with
* any of that - on E10, no internet user in the table resolves at all.
*
* Judging success on the partner would deactivate a perfectly good row.
  IF lv_back_user = lv_user.
    WRITE: / 'Round trip OK - the key resolves to the user it was written for.'.
    SKIP.
*   THE KEY ITSELF. It was missing: the existing-row branch printed it, the
*   freshly-written one did not, so the one path that creates a key never
*   handed it over.
    WRITE: / 'Session key:'.
    WRITE: / lv_key.
    IF lv_back_bp IS INITIAL.
      WRITE: / 'The partner is blank because the function module does not know'.
      WRITE: / 'this user on this system. That is downstream of this report.'.
    ELSEIF lv_back_bp <> p_bp.
      WRITE: / 'But the partner is', lv_back_bp, 'and not', p_bp.
    ENDIF.
    SKIP.
    PERFORM show_usage.
  ELSE.
    WRITE: / 'ROUND TRIP FAILED. The row was written but GET_BP( ) does not'.
    WRITE: / 'return the user it was written for. Deactivating so it cannot'.
    WRITE: / 'be used.'.
    UPDATE zega_t_cj_us_log SET active = @space WHERE user_key = @lv_key.
    COMMIT WORK.
  ENDIF.

*&---------------------------------------------------------------------*
* No parameter. It took one, typed XSTRING, and never read it - and
* ZEGA_T_CJ_US_LOG-USER_KEY is not plain XSTRING, so the inline DATA( ) from
* SELECT was a different type and PERFORM rejected it. A FORM types its
* parameters strictly; an unused one is pure risk.
FORM show_usage.
  WRITE: / 'Use it in either place:'.
  WRITE: /  '  ZRAK_CJ_REQCTX_DIAG, in the session key field'.
  WRITE: /  '  a launch URL, as &userdata=<key>'.
ENDFORM.
