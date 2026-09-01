REPORT zrak_m_muni_load.

*&---------------------------------------------------------------------*
*& MUNICIPALITY BATCH - migrate the fifteen M0xx services into CJS
*&
*& Driver for ZCL_RAK_MIGRATOR over the Municipality service list. It
*& hand-authors NO ZRAK_T_JNY* row: every step, field, option, rule and
*& grid column is projected from /QNV/SB_UI_DEFIN, which is the only place
*& those definitions exist.
*&
*& ------------------------------------------------------------------
*& WHY THE MAPPING BELOW IS A TABLE AND NOT A DERIVATION
*&
*& An M-code is NOT a legacy screen name. MIGRATE( )'s default pattern is
*& N<journey>_* , and there is no screen called NM011_*. The Municipality
*& screens are named by mnemonic - NSUBDIVISION, NMERGE, NCBR, NOG - and
*& the M-code appears only as the VALUE of the JOURNEYTYPE row on each
*& screen. So the code -> screen-family mapping has to be carried, and
*& every line below was read off the JOURNEYTYPE rows of a full
*& /QNV/SB_UI_DEFIN export (43,726 rows), not inferred from the name.
*&
*& WHICH VARIANT. Each service exists three times in the legacy table:
*&   <FAM>_n    desktop, RAKSTAGEBAR + RAK_STEPBAR, a _0 landing screen,
*&              GETSTARTED/CONTINUELATER - the old design
*&   M<FAM>_n   the mobile twin - MRAKSTAGEBAR, MRAKREMAININGFEES
*&   N<FAM>_n   the current design - RAKPAY, RAKHAPPY, SAVE_AS_DRAFT,
*&              no landing screen, fewer and denser screens
*& N is the one to migrate, and it is what E023/E028/E029 already used.
*&
*& WHY IV_SCREEN_PREFIX IS ALWAYS PASSED. JOURNEY_OF_SCREEN( ) strips the
*& leading N and splits at the FIRST underscore, so NSUBDIVISION_1_* and
*& NSUBDIVISION_2_* both derive to SUBDIVISION and the default pattern
*& would merge two separate services into one seven-step journey. _1 and
*& _2 are not two halves of one wizard - _1 is apply-and-pay-initial-fee
*& and _2 is the later pay-final-fee/collect stage, raised as its own
*& request. They are migrated as two journey ids, and the second only
*& when P_ST2 is ticked.
*&
*& ------------------------------------------------------------------
*& UNRESOLVED - READ BEFORE A LIVE RUN
*&
*& 1. THE SIX TENANCY JOURNEYS ARE MAPPED BY MNEMONIC, NOT BY JOURNEYTYPE.
*&    The TEN screens do not carry their own code: NMTC (modify) says
*&    M032, NCTC (cancel), NPOA and NCPA all say M030, and NNTC and NRTC
*&    carry a mixture of blank / M016 / M030 / M032 / PG01 / "MPOA TODO".
*&    The mapping used here reads the mnemonic against the service title
*&    - NNTC new, NMTC amend, NRTC renew, NCTC cancel, NPOA grant a POA,
*&    NCPA cancel a POA - which is coherent and is the only reading that
*&    gives fifteen distinct journeys. It still needs confirming by
*&    whoever owns the TEN screens. Nothing else in this file is inferred.
*&
*& 2. M029 "Assign Consultant" HAS THREE FAMILIES under DML - NACO_1 (3
*&    screens), NACO_2 (1) and NACC_1 (1) - all three carrying M029.
*&    NACO_1 is taken as the service; NACC_1 and NACO_2 are left out
*&    because a one-screen family is a fragment, not a journey, and which
*&    fragment belongs to which flow is not decidable from the export.
*&
*& 3. M016's TITLE says "Building Regulations/Change of Land Use" but the
*&    code resolves to CBR (change of building regulations) ALONE. Change
*&    of land use is CLU, and CLU's JOURNEYTYPE is M015 - a separate
*&    service that is not on this list. Either the title is loose or M015
*&    is missing from the batch.
*&
*& 4. NMTC_1 AND NCTC_1 START AT SCREEN _3. NMTC_1 is _3,_4 and NCTC_1 is
*&    _3,_4,_5 - screens _1 and _2 are not in the table for those
*&    families. They will migrate as 2- and 3-step journeys that begin
*&    part-way through the flow. Confirm the missing screens are genuinely
*&    shared with NNTC and not simply absent from the export.
*&
*& 5. NRGR_1 EXISTS UNDER TWO CATEGORIES, GRANTS and PHD - SETTLED, no
*&    action. EXTRACT_ROWS( ) filters on one category, so migrating M020
*&    under GRANTS drops the PHD rows. The first live test run measured
*&    that gap at exactly 2 rows (274 against the export's combined 276),
*&    and the service owner has confirmed PHD is out of scope here. Left
*&    as it is deliberately - do not "fix" it by widening the category
*&    filter, which would pull PHD rows into a Municipality journey.
*&
*& 6. TWELVE OF THE FIFTEEN CARRY RAKPAY. The migrator DROPS PAYFEE and
*&    counts it, because without HANDLER_CLASS the engine renders a red
*&    "payment unavailable" strip at the citizen. Each of those journeys
*&    needs a handler class (a subclass of ZCL_RAK_JOURNEY_LOGIC) and its
*&    PAYFEE field added in the Studio before it is fit to show anyone.
*&    The run log names them.
*&
*& 7. TITLE_AR IS BLANK ON PURPOSE - the authoritative Arabic text is
*&    ZEGA_T_CJ_IDT for the legacy journey, and it is not invented here.
*&    Same decision as ZRAK_E028_LOAD / ZRAK_E029_LOAD.
*&
*& ------------------------------------------------------------------
*& TEST RUN IS THE DEFAULT. It writes nothing and instead counts, live in
*& this client, the rows each prefix will actually extract - so a table
*& that has moved on since the export is visible BEFORE fifteen journeys
*& are created from it.
*&
*& Re-runnable: MIGRATE( ) refuses an id that already exists. P_DOWN
*& removes only the ids this report owns - never TEARDOWN_ALL( ), which
*& would take every MIG_* journey in the client.
*&---------------------------------------------------------------------*

TYPES: BEGIN OF ty_svc,
         code    TYPE string,      " M-code, from the JOURNEYTYPE rows
         title   TYPE string,
         cat     TYPE string,      " /QNV/SB_UI_DEFIN-CATEGORY
         pfx1    TYPE string,      " stage-1 screen family
         pfx2    TYPE string,      " later stage, blank where there is none
         pay     TYPE abap_bool,   " RAKPAY on stage 1 -> PAYFEE will drop
       END OF ty_svc.
TYPES tt_svc TYPE STANDARD TABLE OF ty_svc WITH EMPTY KEY.

DATA gt_svc TYPE tt_svc.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_dept TYPE zega_t_cj_grp-department OBLIGATORY.
PARAMETERS p_main TYPE zega_t_cj_grp-journeyid DEFAULT '901'.
PARAMETERS p_pfx  TYPE c LENGTH 10 DEFAULT 'MIG_'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_st2  TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_2up  TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_down TYPE abap_bool AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN END OF BLOCK b2.

INITIALIZATION.
* Titles are ASCII-normalised (en dash, typographic apostrophe) - TITLE is
* CHAR(120) and is copied verbatim into the legacy portal description.
  gt_svc = VALUE #( pay = abap_true
    ( code = `M011` cat = `MML`    pfx1 = `NSUBDIVISION_1` pfx2 = `NSUBDIVISION_2`
      title = `Request for Plots Division - Ownership` )
    ( code = `M012` cat = `MML`    pfx1 = `NMERGE_1`       pfx2 = `NMERGE_2`
      title = `Request for Plots Merger - Ownership` )
    ( code = `M016` cat = `MML`    pfx1 = `NCBR_1`         pfx2 = `NCBR_2`
      title = `Request for Building Regulations/Change of Land Use - Ownership` )
    ( code = `M017` cat = `CI`     pfx1 = `NCI_1`
      title = `Request for a Property Investigation` )
    ( code = `M018` cat = `GRANTS` pfx1 = `NOG_1`          pfx2 = `NOG_2`
      title = `Request for a Residential Grant` )
    ( code = `M019` cat = `GRANTS` pfx1 = `NCPGR_1`        pfx2 = `NCPGR_2`
      title = `Convert a Valid Grant to a Program Grant Request` )
    ( code = `M020` cat = `GRANTS` pfx1 = `NRGR_1`         pfx2 = `NRGR_2`
      title = `Request to extend grant's validity period` )
    ( code = `M028` cat = `DML`    pfx1 = `NCOD_1`         pfx2 = `NCOD_3`
      title = `Preliminary Design Approval` )
    ( code = `M030` cat = `TEN`    pfx1 = `NNTC_1`
      title = `New Tenancy Contract` )
    ( code = `M032` cat = `TEN`    pfx1 = `NRTC_1`
      title = `Renew Tenancy Contract` )
    ( code = `M034` cat = `TEN`    pfx1 = `NPOA_1`
      title = `Power of Attorney (POA) Request` )
*   No RAKPAY on stage 1 of these four - PAYFEE has nothing to drop.
    pay = abap_false
    ( code = `M029` cat = `DML`    pfx1 = `NACO_1`
      title = `Assign Consultant` )
    ( code = `M031` cat = `TEN`    pfx1 = `NMTC_1`
      title = `Amend Tenancy Contract` )
    ( code = `M033` cat = `TEN`    pfx1 = `NCTC_1`
      title = `Cancel Tenancy Contract` )
    ( code = `M035` cat = `TEN`    pfx1 = `NCPA_1`
      title = `Power of Attorney (POA) Cancellation` ) ).

START-OF-SELECTION.

  DATA(lo_mig) = NEW zcl_rak_migrator( ).
  DATA lv_pfx TYPE string.
  lv_pfx = COND #( WHEN p_pfx IS INITIAL THEN zcl_rak_migrator=>c_sandbox
                   ELSE to_upper( CONV string( p_pfx ) ) ).

* ------------------------------------------------------------- teardown
  IF p_down = abap_true.
    IF p_test = abap_true.
      WRITE: / 'TEST RUN - teardown skipped. Untick Test run to remove.'.
      RETURN.
    ENDIF.
    WRITE: / |TEARDOWN - prefix { lv_pfx }|.
    ULINE.
    LOOP AT gt_svc INTO DATA(ls_td).
      DATA(lv_id1) = |{ lv_pfx }{ ls_td-code }|.
      lo_mig->teardown( EXPORTING iv_cjs_id = lv_id1 IMPORTING ev_msg = DATA(lv_tdm) ).
      zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_id1 ).
      WRITE: / lv_tdm.
      IF ls_td-pfx2 IS NOT INITIAL.
        DATA(lv_id2) = |{ lv_pfx }{ ls_td-code }B|.
        lo_mig->teardown( EXPORTING iv_cjs_id = lv_id2 IMPORTING ev_msg = lv_tdm ).
        zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_id2 ).
        WRITE: / lv_tdm.
      ENDIF.
    ENDLOOP.
    ULINE.
    RETURN.
  ENDIF.

* ------------------------------------------------------- live row count
* Counted the way EXTRACT_ROWS( ) counts: same category filter, same
* '<prefix>_*' CP pattern. A zero here means the migrate would create
* nothing, and it is seen before anything is written.
  SELECT category, screen_name FROM /qnv/sb_ui_defin INTO TABLE @DATA(lt_def).
  IF sy-subrc <> 0.
    WRITE: / 'No rows in /QNV/SB_UI_DEFIN in this client.'.
    RETURN.
  ENDIF.

  TYPES: BEGIN OF ty_plan,
           id      TYPE string,
           code    TYPE string,
           title   TYPE string,
           cat     TYPE string,
           pfx     TYPE string,
           pay     TYPE abap_bool,
           rows    TYPE i,
           screens TYPE i,
         END OF ty_plan.
  TYPES tt_plan TYPE STANDARD TABLE OF ty_plan WITH EMPTY KEY.
  DATA lt_plan TYPE tt_plan.

  LOOP AT gt_svc INTO DATA(ls_s).
    APPEND VALUE #( id = |{ ls_s-code }| code = ls_s-code title = ls_s-title
                    cat = ls_s-cat pfx = ls_s-pfx1 pay = ls_s-pay ) TO lt_plan.
    IF p_st2 = abap_true AND ls_s-pfx2 IS NOT INITIAL.
      APPEND VALUE #( id = |{ ls_s-code }B| code = ls_s-code
                      title = |{ ls_s-title } - later stage|
                      cat = ls_s-cat pfx = ls_s-pfx2 pay = abap_true ) TO lt_plan.
    ENDIF.
  ENDLOOP.

  LOOP AT lt_plan ASSIGNING FIELD-SYMBOL(<p>).
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    CLEAR lt_seen.
    DATA(lv_pat) = |{ <p>-pfx }_*|.
    LOOP AT lt_def INTO DATA(ls_d).
      IF ls_d-category <> <p>-cat OR ls_d-screen_name NP lv_pat.
        CONTINUE.
      ENDIF.
      <p>-rows = <p>-rows + 1.
      DATA(lv_sn) = CONV string( ls_d-screen_name ).
      IF NOT line_exists( lt_seen[ table_line = lv_sn ] ).
        INSERT lv_sn INTO TABLE lt_seen.
        <p>-screens = <p>-screens + 1.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

* ---------------------------------------------------------------- plan
  WRITE: / 'MUNICIPALITY BATCH',
        30 COND string( WHEN p_test = abap_true THEN 'TEST RUN - nothing written'
                                                ELSE 'LIVE - journeys will be created' ).
  WRITE: / |prefix { lv_pfx }, portal dept { p_dept }, tile group { p_main }, | &&
           |later stages { COND string( WHEN p_st2 = abap_true THEN 'INCLUDED' ELSE 'excluded' ) }|.
  ULINE.
  WRITE: /  'Journey', 16 'Cat', 24 'Screen family', 42 'Scr', 47 'Rows', 54 'Note'.
  ULINE.

  DATA lv_bad TYPE i.
  LOOP AT lt_plan INTO DATA(ls_p).
    DATA(lv_note) = COND string( WHEN ls_p-screens = 0 THEN `NOT IN THIS CLIENT - will be skipped`
                                 WHEN ls_p-pay = abap_true THEN `RAKPAY -> PAYFEE drops, needs handler_class`
                                 ELSE `` ).
    IF ls_p-screens = 0.
      lv_bad = lv_bad + 1.
    ENDIF.
    WRITE: / |{ lv_pfx }{ ls_p-id }|, 16 ls_p-cat, 24 ls_p-pfx,
*          An untyped integer WRITEs eleven characters wide, so `42 screens`
*          spans columns 42-52 and the next field at 47 lands inside it. The
*          counts came out unreadable on the first live test run. Formatted to
*          a string first, which writes exactly as long as it is.
           42 |{ ls_p-screens }|, 47 |{ ls_p-rows }|, 54 lv_note.
  ENDLOOP.
  ULINE.
  WRITE: / |{ lines( lt_plan ) } journeys planned, { lv_bad } with no rows in this client|.

  IF p_test = abap_true.
    WRITE: / 'TEST RUN - untick Test run to create the journeys above.'.
    RETURN.
  ENDIF.

* ------------------------------------------------------------- migrate
* MIGRATE_MANY( ) is not used: it takes no IV_SCREEN_PREFIX, and it
* neither invalidates the config cache nor runs the layout pass. A
* migrated journey that is not invalidated is still served from the
* previous config by every work process that already holds it - the
* "moved the full content and nothing changed" report that ZCL_RAK_CJS
* hit on its own Migrate button.
  ULINE.
  WRITE: / 'MIGRATING'.
  ULINE.

  DATA lv_done TYPE i.
  DATA lt_needs_pay TYPE string_table.

  LOOP AT lt_plan INTO DATA(ls_m).
    IF ls_m-screens = 0.
      WRITE: / '[SKIP]', |{ ls_m-pfx } has no rows in { ls_m-cat }|.
      CONTINUE.
    ENDIF.

    DATA lv_ok  TYPE abap_bool.
    DATA lv_msg TYPE string.
    CLEAR: lv_ok, lv_msg.

    lo_mig->migrate(
      EXPORTING
        iv_category      = ls_m-cat
        iv_journey       = ls_m-code          " raw legacy code -> BKND_JOURNEY
        iv_cjs_id        = ls_m-id
        iv_tile          = ls_m-id
        iv_title         = ls_m-title
        iv_title_ar      = ``                 " see note 7 in the header
        iv_dept          = CONV string( p_dept )
        iv_main          = CONV string( p_main )
        iv_prefix        = lv_pfx
        iv_screen_prefix = ls_m-pfx           " never the default N<code>_*
      IMPORTING
        ev_ok            = lv_ok
        ev_msg           = lv_msg ).

    IF lv_ok = abap_true.
      lv_done = lv_done + 1.
      DATA(lv_jid) = to_upper( |{ lv_pfx }{ ls_m-id }| ).

      DATA lv_pairs TYPE i.
      CLEAR lv_pairs.
      lo_mig->apply_layout( EXPORTING iv_journey = CONV #( lv_jid )
                                      iv_two_up  = p_2up
                            IMPORTING ev_pairs   = lv_pairs ).
      zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_jid ).

      WRITE: / '[OK]  ', lv_msg.
      WRITE: / '      ', |layout: { lv_pairs } field pairs on shared rows|.
      IF ls_m-pay = abap_true.
*       ZCL_RAK_JOURNEY_LOGIC is CREATE PUBLIC and concrete, so it is a
*       usable HANDLER_CLASS in its own right - it carries the payment
*       card (RENDER_FIELD) and the PAID gate (ON_CUSTOM_VALIDATE) with
*       no subclass at all. Setting it here means the only thing still
*       missing on these journeys is the PAYFEE FIELD, which the migrator
*       dropped and which has to be re-added per journey in the Studio.
*       A journey that later needs its own routing gets a subclass then.
        UPDATE zrak_t_jny SET handler_class = 'ZCL_RAK_JOURNEY_LOGIC'
          WHERE journey_id = @lv_jid.
        COMMIT WORK AND WAIT.
        zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_jid ).
        APPEND lv_jid TO lt_needs_pay.
      ENDIF.
    ELSE.
      WRITE: / '[SKIP]', lv_msg.
    ENDIF.
  ENDLOOP.

  ULINE.
  WRITE: / |{ lv_done } of { lines( lt_plan ) } journeys created|.

  IF lt_needs_pay IS NOT INITIAL.
    ULINE.
    WRITE: / 'NOT YET FIT TO SHOW A CITIZEN - PAYFEE was dropped on these.'.
    WRITE: / 'HANDLER_CLASS has been set to ZCL_RAK_JOURNEY_LOGIC, which'.
    WRITE: / 'supplies the payment card and the PAID gate. The PAYFEE FIELD'.
    WRITE: / 'itself still has to be re-added per journey in the Studio -'.
    WRITE: / 'until then the step has no pay control at all:'.
    LOOP AT lt_needs_pay INTO DATA(lv_np).
      WRITE: / '  ', lv_np.
    ENDLOOP.
  ENDIF.

  ULINE.
  WRITE: / 'Then, per journey:'.
  WRITE: / '  1. ZRAK_CJS_XCHECK - a migrated journey has no ZSECTION, no'.
  WRITE: / '     placeholders, no length/range checks and no REVIEW step.'.
  WRITE: / '  2. TITLE_AR and the tile Arabic text from ZEGA_T_CJ_IDT.'.
  WRITE: / '  3. Check every TABLE column against its /QNV/SB_UI_DEFIN'.
  WRITE: / '     LIST_SEQUENCE - cell order is positional at both ends and'.
  WRITE: / '     nothing verifies the two agree.'.
