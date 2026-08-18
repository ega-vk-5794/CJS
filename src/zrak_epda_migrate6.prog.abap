REPORT zrak_epda_migrate6.

*&---------------------------------------------------------------------*
*& Migrates six legacy /QNV/SB_UI_DEFIN journeys into ZRAK_T_JNY* by
*& DRIVING the existing ZCL_RAK_MIGRATOR - not by hand-authoring INSERTs
*& that would drift from its classify() / grid_spec() / pair_labels() /
*& collect_rules() logic, which already IS the project's field-mapping
*& authority (CONTROL_TYPE -> FTYPE, label/value-list resolution via
*& /QNV/SB_LABELT + /QNV/SB_VALUET, grid column projection, show/hide
*& rule extraction from DATA4/DATA5 and UI_FIELD_LOGICS).
*&
*&   E014  NE014_1_*  Environmental Consultants Registration
*&   E142  NE014_2_*  Renew Consultancy Registration
*&   E146  NE014_3_*  Consultant Appeal
*&   E015  NE015_1_*  Environmental Study
*&   E027  NE027_1_*  Vice Captain
*&   D009  ND009_1_*  School Location Change
*&
*& REVIEW-TECH: NE014_1 / _2 / _3 are three sub-flows of ONE legacy
*& screen number (E014) - journey_of_screen() derives 'E014' for all
*& three, so ZCL_RAK_MIGRATOR needed a small patch (IV_SCREEN_PREFIX on
*& EXTRACT_ROWS/MIGRATE, additive and blank-by-default - every existing
*& caller is unaffected) to migrate each sub-flow as its own journey.
*& BKND_JOURNEY is left as the shared raw code 'E014' for all three
*& (one legacy screen number, one BAdI journey in the one-code model);
*& if the backend actually routes renewal/appeal through a STATUS flag
*& or a different BAdI filter, fix BKND_JOURNEY / add the flag here.
*&
*& REVIEW-TECH: D019 (Academic Calendar) is NOT included. No technical
*& /QNV/SB_UI_DEFIN export was ever supplied for it across two source
*& files, and ND009 - initially suspected to be it - is confirmed by
*& its own field content (MINISTRY_APPROVED_FLOOR_PLAN,
*& CIVIL_DEFENSE_CLEARANCE_CERTIFICATE, ...) to be a different, already
*& partly-built journey: D009, School Location Change. D019 needs a
*& real source export before it can be migrated at all.
*&
*& Idempotent: TEARDOWN runs before every MIGRATE, so re-running this
*& report is safe and always reflects the current /QNV/SB_UI_DEFIN
*& content and the JOB table below.
*&
*& PAYFEE handling: ZCL_RAK_MIGRATOR deliberately DROPS every RAKPAY
*& control rather than ship a payment step with no handler behind it
*& (a migrated PAYFEE with no HANDLER_CLASS renders as a red "payment
*& unavailable" strip at the citizen). E014 / E146 / E015 each had one
*& RAKPAY (their step 4); this report puts the PAYFEE field straight
*& back on that step once HANDLER_CLASS is wired, so the base class's
*& own payment machinery (ZCL_RAK_JOURNEY_LOGIC - fee card, gateway
*& hand-off, PAID gate) takes over exactly as it does on every other
*& payment-bearing journey in this system. E142 and E027 carry no
*& RAKPAY in the real export at all (E142's screenshots agree - no
*& Payment step is shown for renewal), so neither gets one back.
*&---------------------------------------------------------------------*

PARAMETERS: p_dept(10) TYPE c OBLIGATORY LOWER CASE.
* REVIEW-BE: department code for the portal tile grouping
* (ZEGA_T_CJ_GRP-DEPARTMENT). Purely a Studio-side grouping key, entered
* by hand on every other call to MIGRATE() in this system (see
* ZCL_RAK_CJS's Studio migration tab) - there is no fixed value to
* default it to. Set it to whatever this landscape uses before running.

START-OF-SELECTION.

  TYPES: BEGIN OF ty_job,
           jid        TYPE string,   " -> ZRAK_T_JNY-JOURNEY_ID (bare, no MIG_ prefix -
                                      "    matches the existing ZCL_<jid>_..._LOGIC class names)
           category   TYPE string,   " /QNV/SB_UI_DEFIN-CATEGORY
           bknd       TYPE string,   " raw legacy code -> BKND_JOURNEY / BKND_CATEGORY input
           scr_prefix TYPE string,   " blank = whole BKND family; set only to split a shared code
           title      TYPE string,
           title_ar   TYPE string,   " REVIEW-BE: blank - needs a real Arabic title from Comms/Legal
           handler    TYPE string,   " blank = no handler needed (no payment, no custom logic)
           pay_screen TYPE string,   " BKND_SCREEN of the step whose dropped PAYFEE gets restored
         END OF ty_job.

  DATA lt_jobs TYPE STANDARD TABLE OF ty_job WITH EMPTY KEY.
  lt_jobs = VALUE #(
    ( jid = 'E014' category = 'EPDA'  bknd = 'E014' scr_prefix = 'NE014_1'
      title = 'Environmental Consultants Registration'
      handler = 'ZCL_E014_CONSULT_REG_LOGIC'   pay_screen = 'NE014_1_4' )
    ( jid = 'E142' category = 'EPDA'  bknd = 'E014' scr_prefix = 'NE014_2'
      title = 'Renew Consultancy Registration'
      handler = ''                              pay_screen = '' )
    ( jid = 'E146' category = 'EPDA'  bknd = 'E014' scr_prefix = 'NE014_3'
      title = 'Consultant Appeal'
      handler = 'ZCL_E146_CONSULT_APPEAL_LOGIC' pay_screen = 'NE014_3_4' )
    ( jid = 'E015' category = 'EPDA'  bknd = 'E015' scr_prefix = ''
      title = 'Environmental Study'
      handler = 'ZCL_E015_ENV_STUDY_LOGIC'      pay_screen = 'NE015_1_4' )
    ( jid = 'E027' category = 'EPDA'  bknd = 'E027' scr_prefix = ''
      title = 'Vice Captain'
      handler = 'ZCL_E027_VICE_CAPTAIN_LOGIC'   pay_screen = '' )
    ( jid = 'D009' category = 'DOKSL' bknd = 'D009' scr_prefix = ''
      title = 'School Location Change'
      handler = 'ZCL_D009_SCHOOL_LOCA_CHG_LOGIC' pay_screen = '' ) ).

  DATA(lo_mig) = NEW zcl_rak_migrator( ).

  LOOP AT lt_jobs INTO DATA(ls_job).
    WRITE: / '----', ls_job-jid, '-', ls_job-title.

    lo_mig->teardown( EXPORTING iv_cjs_id = ls_job-jid IMPORTING ev_msg = DATA(lv_td) ).
    WRITE: / '  teardown:', lv_td.

    lo_mig->migrate(
      EXPORTING
        iv_category      = ls_job-category
        iv_journey        = ls_job-bknd
        iv_cjs_id         = ls_job-jid
        iv_title          = ls_job-title
        iv_title_ar       = ls_job-title_ar
        iv_tile           = ls_job-jid
        iv_dept           = CONV string( p_dept )
        iv_prefix         = ''                 " bare journey_id - see class-naming note above
        iv_screen_prefix  = ls_job-scr_prefix
      IMPORTING
        ev_ok             = DATA(lv_ok)
        ev_msg            = DATA(lv_msg) ).

    WRITE: / '  migrate :', lv_ok, lv_msg.

    IF lv_ok = abap_false.
      CONTINUE.
    ENDIF.

    IF ls_job-handler IS NOT INITIAL.
      UPDATE zrak_t_jny SET handler_class = ls_job-handler
        WHERE journey_id = ls_job-jid.
      WRITE: / '  handler :', ls_job-handler.
    ENDIF.

    IF ls_job-pay_screen IS NOT INITIAL.
      SELECT SINGLE step_id FROM zrak_t_jny_step
        WHERE journey_id  = @ls_job-jid
          AND bknd_screen = @ls_job-pay_screen
        INTO @DATA(lv_pay_step).
      IF sy-subrc = 0.
        SELECT SINGLE MAX( seqnr ) FROM zrak_t_jny_fld
          WHERE journey_id = @ls_job-jid AND step_id = @lv_pay_step
          INTO @DATA(lv_max_seq).
        INSERT zrak_t_jny_fld FROM @( VALUE #(
          mandt      = sy-mandt
          journey_id = ls_job-jid
          step_id    = lv_pay_step
          field_name = 'PAYFEE'
          seqnr      = lv_max_seq + 10
          ftype      = 'PAYFEE'
          zlabel     = 'Payment' ) ).
        WRITE: / '  payfee  : restored on step', lv_pay_step, '(', ls_job-pay_screen, ')'.
      ELSE.
        WRITE: / '  payfee  : REVIEW - step for', ls_job-pay_screen, 'not found, not restored'.
      ENDIF.
    ENDIF.

    COMMIT WORK AND WAIT.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = ls_job-jid ).
  ENDLOOP.

  WRITE: / '----'.
  WRITE: / 'Done. Open each journey in the Studio and check:'.
  WRITE: / ' - PAY_SCREEN / PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR on E014 / E146 / E015 -'.
  WRITE: / '   set in each handler''s on_init, all flagged REVIEW-BE (see the class comments) -'.
  WRITE: / '   the fee will not raise until those are confirmed for the EPDA department.'.
  WRITE: / ' - TITLE_AR is blank on every journey - needs a confirmed Arabic title.'.
  WRITE: / ' - Run ZRAK_CJS_XCHECK per journey_id before going live.'.
