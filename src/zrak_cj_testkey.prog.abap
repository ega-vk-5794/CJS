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
          CALL FUNCTION 'ZFM_EGA_GET_BP_FROM_INTERNET_U'
            EXPORTING
              iv_internet_user    = ls_cand-id
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
      WRITE: / 'ZEGA_T_CJ_US_LOG has no row whose ID maps to it. Supply the'.
      WRITE: / 'internet user by hand in the second field.'.
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
      CALL FUNCTION 'ZFM_EGA_GET_BP_FROM_INTERNET_U'
        EXPORTING
          iv_internet_user    = lv_user
        IMPORTING
          ev_business_partner = lv_bp.
    CATCH cx_root INTO DATA(lx_fm).
      WRITE: / 'ZFM_EGA_GET_BP_FROM_INTERNET_U failed:', lx_fm->get_text( ).
      RETURN.
  ENDTRY.

  IF lv_bp <> p_bp.
    WRITE: / 'Refused. Internet user', lv_user, 'resolves to partner', lv_bp.
    WRITE: / 'which is not', p_bp.
    RETURN.
  ENDIF.
  WRITE: / 'Verified:', lv_user, '->', lv_bp.
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
    PERFORM show_usage USING lv_have.
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
  IF lv_back_bp = p_bp.
    WRITE: / 'Round trip OK.'.
    SKIP.
    PERFORM show_usage USING lv_key.
  ELSE.
    WRITE: / 'ROUND TRIP FAILED. The row was written but GET_BP( ) does not'.
    WRITE: / 'resolve it. Deactivating so it cannot be used.'.
    UPDATE zega_t_cj_us_log SET active = @space WHERE user_key = @lv_key.
    COMMIT WORK.
  ENDIF.

*&---------------------------------------------------------------------*
FORM show_usage USING iv_key TYPE xstring.
  WRITE: / 'Use it in either place:'.
  WRITE: /  '  ZRAK_CJ_REQCTX_DIAG, in the session key field'.
  WRITE: /  '  a launch URL, as &userdata=<key>'.
ENDFORM.
