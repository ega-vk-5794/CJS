CLASS zcl_rak_journey_be DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
*   The backend conversation: create, read, per-table read, commit, field and
*   attachment payloads.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

    METHODS backend_create.
    METHODS backend_read  IMPORTING iv_step TYPE i.
    METHODS backend_read_grids IMPORTING iv_step TYPE i.
    METHODS be_commit
      IMPORTING iv_step      TYPE i
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS be_fields
      RETURNING VALUE(rt) TYPE zif_rak_journey_backend=>tt_field.
    METHODS be_attach
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS tables_for_backend IMPORTING iv_step   TYPE i DEFAULT -1
                               RETURNING VALUE(rt) TYPE /qnv/sb_tabl_def_tt.
    METHODS attachments_for_backend RETURNING VALUE(rt) TYPE /qnv/sbuild_attachments_tt.
    METHODS post_items    IMPORTING iv_step   TYPE i DEFAULT -1
                          RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_item.
    METHODS items_from_kv IMPORTING it_kv     TYPE zif_rak_journey=>tt_kv
                          RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_item.
    METHODS flatten_kv    IMPORTING iv_step      TYPE i DEFAULT -1
                          RETURNING VALUE(rt_kv) TYPE zif_rak_journey=>tt_kv.

  PRIVATE SECTION.
    DATA mo_e TYPE REF TO zcl_rak_journey_engine.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_BE IMPLEMENTATION.


  METHOD attachments_for_backend.
    LOOP AT mo_e->mt_attach INTO DATA(ls_a).
      zcl_rak_cj_att_store=>get( EXPORTING iv_guid = ls_a-guid
                                 IMPORTING ev_b64  = DATA(lv_b64) ).
      IF lv_b64 IS INITIAL.
        CONTINUE.
      ENDIF.
*     identifier1 carries the field and, when the file belongs to one occurrence
*     of it, the key as well - FIELD_KEY. That is the legacy convention, not a
*     new one: the D0xx BAdI already reads an occurrence back out of identifier1
*     (OWNERS_SEARCH_<n> in ZCL_EGA_CJ_DOK_ABS), so a BAdI written against the
*     old framework needs no change to file these correctly.
      DATA(lv_id1) = COND string( WHEN ls_a-field IS NOT INITIAL
                                  THEN ls_a-field ELSE ls_a-tech ).
      IF ls_a-okey IS NOT INITIAL.
        lv_id1 = |{ lv_id1 }_{ ls_a-okey }|.
      ENDIF.
      APPEND VALUE #( identifier1  = lv_id1
                      identifier2  = ls_a-tech
                      file_name    = ls_a-name
                      file_content = lv_b64 ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD backend_create.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   Without a screen name the FM has nothing to dispatch on and the BAdI cannot
*   work out which screen it is creating for. Said out loud rather than posting
*   a request that would fail somewhere less obvious.
    IF ls_step-bknd_screen IS INITIAL.
      mo_e->trace_gate( |Step { ls_step-id }: BKND_ACTIVE is on but BKND_SCREEN is | &&
                        |empty. No draft is created and nothing this citizen types | &&
                        |will ever reach the backend.| ).
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Error'
        text = |Step { ls_step-id }: BKND_SCREEN is empty, so the backend draft cannot be created.| ) ).
      RETURN.
    ENDIF.

*   No iv_status. The update branch of the BAdI switches on the STATUS item and
*   create does not read it at all, so sending one here would only muddy a
*   contract that already works on a blank guid.
*
*   No tables and no attachments either: nothing has been entered yet, and the
*   legacy create ignores both.
    DATA(lt_ci) = post_items( 0 ).
    mo_e->trace( |CREATE  screen { ls_step-bknd_screen } · blank guid · { lines( lt_ci ) } items| ).

    DATA(lv_t0) = mo_e->tick( ).
    mo_e->mo_bridge->post(
      EXPORTING
        iv_screen = ls_step-bknd_screen
        iv_guid   = ``
        it_items  = lt_ci
      IMPORTING
        ev_guid   = DATA(lv_guid)
        et_msg    = DATA(lt_m) ).
    DATA(lv_ms) = mo_e->tock( lv_t0 ).

    mo_e->trace( |CREATE  returned draft { COND string( WHEN lv_guid IS NOT INITIAL THEN lv_guid ELSE '(NOTHING)' ) }| &&
           | · { lines( lt_m ) } message(s) · { lv_ms } ms| ).
    mo_e->trace_perf( iv_label = |CREATE { ls_step-bknd_screen }| iv_ms = lv_ms ).

    READ TABLE lt_m WITH KEY type = 'Error' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
*     Do not proceed to the read. A failed create means there is no draft to
*     read, and reading anyway produced a second, more confusing error.
      APPEND LINES OF lt_m TO mo_e->mt_msg.
      RETURN.
    ENDIF.
    APPEND LINES OF lt_m TO mo_e->mt_msg.

    IF lv_guid IS INITIAL.
*     The create came back clean and empty. Every later POST then carries a
*     blank INTRENO_JOURNEY, which the FM reads as another create - so the
*     citizen fills in four steps against four different drafts and none of
*     them is the one on the confirmation screen.
      mo_e->trace_gate( |CREATE on screen { ls_step-bknd_screen } returned no draft | &&
                        |reference and no error. Check the D0xx create BAdI is | &&
                        |registered for BE journey { mo_e->ms_config-backend-journey } | &&
                        |and category { mo_e->ms_config-backend-category }.| ).
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Error'
        text = 'The backend did not return a draft reference. The application cannot be started.' ) ).
      RETURN.
    ENDIF.
    mo_e->mv_case_guid = lv_guid.
  ENDMETHOD.


  METHOD backend_read.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX iv_step + 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lt_ri) = post_items( iv_step ).
    mo_e->trace( |READ    screen { ls_step-bknd_screen } · guid { mo_e->mv_case_guid } · { lines( lt_ri ) } fields asked| ).

    DATA(lv_rt0) = mo_e->tick( ).
    mo_e->mo_bridge->read(
      EXPORTING
        iv_screen      = ls_step-bknd_screen
        iv_guid        = mo_e->mv_case_guid
        it_items       = lt_ri
*       PARAM3. ZIF_EGA_FW_CJI~READ takes no LOGINBP - unlike CREATE and UPDATE,
*       which both do - so the header is the only channel a read has for identity,
*       and every ShapeIt launch carries it there:
*
*           ...&param2=D001&param1=202411280001&param3=1000116563
*
*       Without it a cold read has no partner. GS_DATA-PARTNER is filled either
*       from the INDX(CJ) buffer, which a fresh session has not written yet, or
*       from LS_DATA-APPLICANT_ID inside READ_CASE, which only runs once a draft
*       or case has been found. So on journey entry the applicant name and
*       Emirates ID render empty and nothing says why.
*
*       Passed explicitly even though ENSURE_CONFIG( ) already copies MV_LOGINBP
*       into BACKEND-LOGINBP_DEV, which the bridge falls back to. That fallback
*       works by accident of naming: the day someone gates LOGINBP_DEV on
*       sy-sysid <> 'E30', as its name invites, every read on production loses
*       its partner silently.
        iv_loginbp     = mo_e->mv_loginbp
      IMPORTING
        et_values      = DATA(lt_val)
        et_attachments = DATA(lt_beatt)
*       The key as the backend currently understands it. See the adoption block
*       below - this is the half of the contract that was missing.
        ev_guid        = DATA(lv_rguid)
        ev_case        = DATA(lv_rcase)
        et_msg         = DATA(lt_m) ).
    DATA(lv_rms) = mo_e->tock( lv_rt0 ).

    mo_e->trace( |READ    { lines( lt_val ) } value(s) back · { lines( lt_beatt ) } attachment(s) · { lines( lt_m ) } message(s) · { lv_rms } ms| ).
    mo_e->trace_perf( iv_label = |READ { ls_step-bknd_screen }| iv_ms = lv_rms ).

*   ---- adopt what the read said about the key ------------------------------
*   A READ can move the key just as a POST can, and until now only POST was
*   listened to. Two BAdI methods re-point GV_GUID at the case id:
*
*       ZIF_EGA_FW_CJI~GET_SCREEN   gv_guid = caseid            (launched on a case)
*       CREATE_CASE                 me->gv_guid = gs_data-caseid
*
*   and the read hands that value straight back through INTRENO_JOURNEY:
*
*       CASE <definition>-fieldname.
*         WHEN 'INTRENO_JOURNEY'. <definition>-value = gv_guid.
*
*   The backend has been announcing the key on every read for as long as this has
*   existed. Nothing was listening.
*
*   Same rule as BACKEND_CREATE and the three POST paths, worded identically so
*   the four cannot drift apart:
*
*     EV_GUID  only ever fills when we went in with NOTHING, and it is the draft
*              key the backend minted - the one case where the journey's identity
*              legitimately changes. Guarded anyway: adopting a key over one we
*              already hold is the exact failure the EV_GUID / EV_CASE split was
*              introduced to stop.
*
*     EV_CASE  is a DIFFERENT fact about the same request, not a correction to the
*              key. It goes through TAKE_CASE( ), which stays the single writer
*              for the case number and publishes CASE_NUMBER into the model -
*              which is what PAY_ENGINE( ) and PREPARE_PAYMENT( ) read, and why a
*              journey resumed on a case could not pay. Idempotent, so a step read
*              that returns the same case every time costs one compare.
    IF lv_rguid IS NOT INITIAL AND mo_e->mv_case_guid IS INITIAL.
      mo_e->mv_case_guid = lv_rguid.
      mo_e->trace( |READ    backend supplied journey key { lv_rguid }| ).
    ENDIF.
    IF lv_rcase IS NOT INITIAL.
      mo_e->take_case( lv_rcase ).
    ENDIF.

*   A read that asks for fields and gets nothing back is the quietest failure in
*   the framework: the page renders, every field is blank, and it looks exactly
*   like a citizen who has not typed anything yet. On a RESUMED application it
*   means the draft was not found or the read BAdI is not registered.
    IF lt_val IS INITIAL AND lt_ri IS NOT INITIAL AND lt_m IS INITIAL
       AND mo_e->mv_case_guid IS NOT INITIAL.
      mo_e->trace_gate( |READ on screen { ls_step-bknd_screen } asked for | &&
                        |{ lines( lt_ri ) } field(s), got nothing back and reported | &&
                        |no error. Either the read BAdI is not registered for BE | &&
                        |journey { mo_e->ms_config-backend-journey }, or guid | &&
                        |{ mo_e->mv_case_guid } does not exist on the backend.| ).
    ENDIF.

*   Merged rather than replaced. Attachments are case-level but a read is
*   screen-level, so a later step that returns none would otherwise wipe what an
*   earlier one found. Keyed on the two identifiers plus the file name, which is
*   what the backend itself uses to de-duplicate.
    backend_read_grids( iv_step ).

    LOOP AT lt_beatt INTO DATA(ls_be).
      READ TABLE mo_e->mt_be_attach TRANSPORTING NO FIELDS
        WITH KEY identifier1 = ls_be-identifier1
                 identifier2 = ls_be-identifier2
                 file_name   = ls_be-file_name.
      IF sy-subrc <> 0.
        APPEND ls_be TO mo_e->mt_be_attach.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_val INTO DATA(ls_v).
      IF ls_v-value IS INITIAL OR zcl_rak_journey_util=>is_scratch( ls_v-key ) = abap_true.
        CONTINUE.
      ENDIF.
      DATA(ls_gf) = mo_e->safe_field( ls_v-key ).
      IF ls_gf-type = 'EDITABLE_TABLE'.
        mo_e->mo_grid->grid_from_json( iv_field = ls_v-key iv_json = ls_v-value ).
      ELSE.
        mo_e->val_set( iv_name = ls_v-key iv_value = ls_v-value ).
      ENDIF.
    ENDLOOP.
    APPEND LINES OF lt_m TO mo_e->mt_msg.
  ENDMETHOD.


  METHOD backend_read_grids.
* Replaces ZCL_RAK_JOURNEY_BE->BACKEND_READ_GRIDS in full.
* Additions are marked ASSERT-1 and ASSERT-2; everything else is unchanged.

*   The main read returns no table data - the legacy OData layer makes a separate
*   call per table and so must we. One extra round trip per grid per step read,
*   which is why this only runs for grids on the step being read and not for the
*   whole journey.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX iv_step + 1.
    IF sy-subrc <> 0 OR ls_step-bknd_screen IS INITIAL.
      RETURN.
    ENDIF.

*   ASSERT-1 -----------------------------------------------------------------
*   What every grid on this step came back with, so the answers can be compared
*   against each other once they are all in.
*
*   The framework asks the backend for one named table at a time and has never
*   looked at what it gets. On D008 that meant seven read_table calls - OWNERS_1,
*   OWNERS_DISP, FEES_PREKG, FEES_KG, FEES_C1, FEES_C2, FEES_C3 - and seven
*   copies of the owners rows, accepted without a word. The fee tables rendered
*   a partner's nationality and share percentage and nobody could tell whether
*   the fault was ours or the BAdI's, because nothing in the trace compared one
*   answer to the next.
*
*   Two named tables returning byte-identical content is not a thing a correct
*   backend does. It means the requested name was ignored.
    TYPES: BEGIN OF ty_fp,
             field TYPE string,
             rows  TYPE i,
             sig   TYPE string,
           END OF ty_fp.
    DATA lt_fp TYPE STANDARD TABLE OF ty_fp WITH EMPTY KEY.
*   --------------------------------------------------------------------------

*   Every table-ish control, not only EDITABLE_TABLE. The narrower loop was the
*   reason the table FM never fired for a field configured as TABLE - and for
*   TABLE, RECORDCARD and RO_PANEL there is also no model member, so the rows
*   have to be parked somewhere a handler can reach them. That is mo_e->mt_be_table,
*   read back through get_backend_table( ).
*   PAYFEE is in this list, which looks odd until you see where the fee card
*   used to get its lines: ZCL_RAK_PAY_ENGINE->GET_FEES( ) selects dfkkop
*   directly, keyed on an ext_key it derives from the case. That bypasses the
*   BAdI entirely, so a backend that knows the fees has no way to say so, and a
*   journey whose fees are not open items yet shows an empty card with no error.
*
*   Read through the bridge like every other table and the backend owns the
*   list. The handler still falls back to GET_FEES( ) when nothing comes back,
*   so journeys that were working keep working.
    LOOP AT ls_step-fields INTO DATA(ls_f)
         WHERE type = 'EDITABLE_TABLE' OR type = 'TABLE'
            OR type = 'RECORDCARD'     OR type = 'RO_PANEL'
            OR type = 'PAYFEE'.

      DATA(lt_gc) = mo_e->mo_grid->grid_cols( ls_f ).

      mo_e->mo_bridge->read_table(
        EXPORTING
          iv_screen = ls_step-bknd_screen
          iv_guid   = mo_e->mv_case_guid
          iv_field  = ls_f-name
*         The type, so the bridge can send FEESLIST for a fee control instead of
*         the field name. Fees are the one table on this loop whose backend name
*         is fixed by the FM contract rather than by /QNV configuration, and the
*         only way the bridge can tell is if we say which control this is.
          iv_type   = ls_f-type
*         And the escape hatch from that fixed name. FEESLIST is right for a case
*         whose open items the backend has raised; a journey that prices itself
*         from its own table has no open items and needs to say where its fees
*         actually live. TECH_NAME is where an author says it, and the bridge
*         reads it on PAYFEE controls only - every other type still resolves
*         through DATA2 exactly as before.
          iv_table  = ls_f-tech_name
*         PARAM3, as on the main read. The grid read reaches the same BAdI through
*         the same header and had the same blind spot - and a grid whose rows are
*         filtered by partner comes back EMPTY rather than wrong, which is far
*         harder to notice than a visibly bad row.
          iv_loginbp = mo_e->mv_loginbp
        IMPORTING
          et_rows   = DATA(lt_rows)
          et_msg    = DATA(lt_gm) ).
*     A blank DATA2, or no /QNV row at all, is OUR configuration problem and a
*     citizen applying for a licence can do nothing about it - yet it was being
*     printed in yellow at the top of their form. It is a blocker, so it goes to
*     the gate, where it is counted and reported under trace. Only a genuine
*     backend Error still reaches the strip.
      LOOP AT lt_gm INTO DATA(ls_gmsg).
        IF ls_gmsg-type = 'Error'.
          APPEND ls_gmsg TO mo_e->mt_msg.
        ELSE.
          mo_e->trace_gate( ls_gmsg-text ).
        ENDIF.
      ENDLOOP.
      mo_e->trace( |READ    grid { ls_f-name } · { lines( lt_rows ) } row(s)| ).

*     Nothing back leaves the grid alone. A read is screen-level and a grid may
*     legitimately have rows the citizen entered earlier that the backend has no
*     opinion about on this screen; replacing with an empty table would wipe them.
      IF lt_rows IS INITIAL.
        CONTINUE.
      ENDIF.

*     FIELD1..N by position. With a DEFAULT_VAL spec the columns get their real
*     names; without one - which is every TABLE / RECORDCARD / RO_PANEL - they are
*     named FIELD1..N, because the backend sends cells by position and there is
*     nothing else to call them.
      DATA ls_grid TYPE zif_rak_journey=>ty_table.
      CLEAR ls_grid.
      DATA(lv_w) = 0.
*     ASSERT-2 ---------------------------------------------------------------
*     The widest column the backend actually populated, measured even when the
*     spec decides the width. Below, lv_w is set from the spec and anything the
*     backend sent past it is dropped silently - which is how a column that has
*     been added on the legacy side but not in CJS disappears without trace.
      DATA(lv_be_w) = 0.
      LOOP AT lt_rows INTO DATA(ls_probe_w).
        DO 30 TIMES.
          ASSIGN COMPONENT |FIELD{ sy-index }| OF STRUCTURE ls_probe_w TO FIELD-SYMBOL(<pw>).
          IF sy-subrc <> 0.
            EXIT.
          ENDIF.
          IF <pw> IS NOT INITIAL AND sy-index > lv_be_w.
            lv_be_w = sy-index.
          ENDIF.
        ENDDO.
      ENDLOOP.
*     ------------------------------------------------------------------------
      IF lt_gc IS NOT INITIAL.
        LOOP AT lt_gc INTO DATA(ls_c).
          APPEND ls_c-name TO ls_grid-columns.
        ENDLOOP.
        lv_w = lines( lt_gc ).
*       ASSERT-2 continued. Narrower than the spec is ordinary - a backend need
*       not fill every column. Wider is not: those cells exist, carry data, and
*       are being thrown away one line below.
        IF lv_be_w > lv_w.
          mo_e->trace_gate( |Grid { to_upper( ls_f-name ) }: the backend populated | &&
                            |{ lv_be_w } column(s) but the spec declares { lv_w }. | &&
                            |Column(s) { lv_w + 1 } to { lv_be_w } are being discarded. | &&
                            |Either add them to DEFAULT_VAL (as HIDE if they are not | &&
                            |for the citizen) or find out why the backend is sending them.| ).
        ENDIF.
      ELSE.
*       Widest row wins, so a ragged result does not lose its right-hand columns.
        lv_w = lv_be_w.
        DO lv_w TIMES.
          APPEND |FIELD{ sy-index }| TO ls_grid-columns.
        ENDDO.
      ENDIF.
      IF lv_w = 0.
*       Rows arrived but no FIELDn component held anything. The BAdI builds cell
*       names as 'FIELD' && LIST_SEQUENCE, so a blank or zero LIST_SEQUENCE on the
*       column definitions produces FIELD0 / FIELD, the ASSIGN misses, and every
*       cell stays empty while the row count looks right.
        mo_e->trace( |READ    grid { to_upper( ls_f-name ) } · { lines( lt_rows ) } row(s) but every cell empty| &&
               | · check LIST_SEQUENCE on the column rows in /QNV/SB_UI_DEFIN| ).
        CONTINUE.
      ENDIF.

      DATA lt_cells TYPE zif_rak_journey=>tt_string.
      DATA lv_cell  TYPE string.
      LOOP AT lt_rows INTO DATA(ls_row).
        CLEAR lt_cells.
*       One cell per spec column, FIELD1..N by position. DO rather than LOOP:
*       only the count is needed, and TRANSPORTING NO FIELDS is not allowed
*       without a WHERE.
        DATA lv_i TYPE i.
        DO lv_w TIMES.
          lv_i = sy-index.
          CLEAR lv_cell.
          ASSIGN COMPONENT |FIELD{ lv_i }| OF STRUCTURE ls_row TO FIELD-SYMBOL(<c>).
          IF sy-subrc = 0.
            lv_cell = <c>.
            CONDENSE lv_cell.
          ENDIF.
          APPEND lv_cell TO lt_cells.
        ENDDO.
        APPEND lt_cells TO ls_grid-rows.
      ENDLOOP.

*     ASSERT-1 continued. The whole content, not just the first row: two grids
*     legitimately sharing an opening row is common - a country column, a fee
*     label - while two sharing every cell of every row is not. Built from the
*     cells that were actually kept, so it compares what the citizen will see.
      DATA lv_sig TYPE string.
      CLEAR lv_sig.
      LOOP AT ls_grid-rows INTO DATA(lt_sr).
        lv_sig = |{ lv_sig }\|{ concat_lines_of( table = lt_sr sep = `~` ) }|.
      ENDLOOP.
      APPEND VALUE #( field = to_upper( ls_f-name )
                      rows  = lines( ls_grid-rows )
                      sig   = lv_sig ) TO lt_fp.

*     Parked for every type, so a handler can serve get_table( ) from it.
*     Exactly what went into the store, under exactly which key. get_backend_table( )
*     matches on this key, so a handler asking for the DATA2 spelling rather than
*     the field name gets nothing and cannot tell why.
      mo_e->trace( |READ    grid { to_upper( ls_f-name ) } stored · { lines( ls_grid-rows ) } row(s)| &&
             | x { lines( ls_grid-columns ) } col(s) · ask for it with get_backend_table( '{ to_upper( ls_f-name ) }' )| ).

      READ TABLE mo_e->mt_be_table ASSIGNING FIELD-SYMBOL(<bt>) WITH KEY field = to_upper( ls_f-name ).
      IF sy-subrc = 0.
        <bt>-data = ls_grid.
      ELSE.
        APPEND VALUE #( field = to_upper( ls_f-name ) data = ls_grid ) TO mo_e->mt_be_table.
      ENDIF.

*     Only a grid has a model member to write into. The other three are drawn
*     from get_table( ), which is why they get the store and nothing else.
      IF ls_f-type = 'EDITABLE_TABLE'.
        mo_e->zif_rak_journey~set_grid_data( iv_field = ls_f-name is_data = ls_grid ).
      ENDIF.
    ENDLOOP.

*   ASSERT-1 continued. Every answer is in; compare them.
*
*   Sorted so identical signatures sit together and one pass finds them. Only
*   non-empty results are compared: two grids the backend has nothing for are
*   both empty, both correct, and would otherwise report every step of every
*   journey that has not been filled in yet.
    DELETE lt_fp WHERE rows = 0.
    IF lines( lt_fp ) > 1.
      SORT lt_fp BY sig field.
      DATA lv_prev_sig  TYPE string.
      DATA lv_prev_fld  TYPE string.
      DATA lv_dupes     TYPE string.
      LOOP AT lt_fp INTO DATA(ls_fp).
        IF ls_fp-sig = lv_prev_sig.
          lv_dupes = COND #( WHEN lv_dupes IS INITIAL
                             THEN |{ lv_prev_fld }, { ls_fp-field }|
                             ELSE |{ lv_dupes }, { ls_fp-field }| ).
        ELSE.
          IF lv_dupes IS NOT INITIAL.
            mo_e->trace_gate( |Screen { ls_step-bknd_screen }: the backend returned | &&
                              |IDENTICAL content for differently named tables | &&
                              |({ lv_dupes }). It is not reading the table name it was | &&
                              |asked for. Every one of these grids is showing another | &&
                              |table's rows.| ).
            CLEAR lv_dupes.
          ENDIF.
          lv_prev_sig = ls_fp-sig.
          lv_prev_fld = ls_fp-field.
        ENDIF.
      ENDLOOP.
      IF lv_dupes IS NOT INITIAL.
        mo_e->trace_gate( |Screen { ls_step-bknd_screen }: the backend returned | &&
                          |IDENTICAL content for differently named tables | &&
                          |({ lv_dupes }). It is not reading the table name it was | &&
                          |asked for. Every one of these grids is showing another | &&
                          |table's rows.| ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD be_attach.
    rv_ok = abap_true.
    IF mo_e->mt_attach IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_handle) = mo_e->ms_handle.

*   A journey that never ran be_commit (single step, or attachments only) has no
*   case yet — create it before attaching to it.
    IF ls_handle-request_id IS INITIAL.
      DATA lt_ai TYPE bapiret2_t.
      mo_e->mo_backend->init(
        EXPORTING
          it_fields = be_fields( )
        IMPORTING
          et_return = lt_ai
        CHANGING
          cs_handle = ls_handle ).
      mo_e->ms_handle = ls_handle.
      LOOP AT lt_ai INTO DATA(ls_ai) WHERE type = 'E'.
        APPEND VALUE #( type = 'Error' text = ls_ai-message ) TO mo_e->mt_msg.
      ENDLOOP.
      IF line_exists( lt_ai[ type = 'E' ] ).
        rv_ok = abap_false.
        RETURN.
      ENDIF.
    ENDIF.

    LOOP AT mo_e->mt_attach ASSIGNING FIELD-SYMBOL(<ls_a>) WHERE filed = abap_false.
      zcl_rak_cj_att_store=>get( EXPORTING iv_guid = <ls_a>-guid
                                 IMPORTING ev_b64  = DATA(lv_b64) ).
      IF lv_b64 IS INITIAL.
*       Was a silent CONTINUE: the document vanished and nobody was told.
        APPEND VALUE #( type = 'Error'
          text = |{ <ls_a>-name }: the staged file is gone and was not attached| ) TO mo_e->mt_msg.
        rv_ok = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_pos)  = find( val = lv_b64 sub = ',' ).
      DATA(lv_pure) = COND string( WHEN lv_pos >= 0
                                   THEN substring( val = lv_b64 off = lv_pos + 1 )
                                   ELSE lv_b64 ).

      DATA lv_x TYPE xstring.
      CLEAR lv_x.
      TRY.
          lv_x = cl_web_http_utility=>decode_x_base64( lv_pure ).
        CATCH cx_root.
          CLEAR lv_x.
      ENDTRY.
      IF lv_x IS INITIAL.
*       A failed decode used to be swallowed and the case submitted regardless.
        APPEND VALUE #( type = 'Error'
          text = |{ <ls_a>-name }: file could not be decoded and was not attached| ) TO mo_e->mt_msg.
        rv_ok = abap_false.
        CONTINUE.
      ENDIF.

      DATA lv_ext TYPE string.
      CLEAR lv_ext.
      SPLIT <ls_a>-name AT '.' INTO TABLE DATA(lt_np).
      IF lines( lt_np ) > 1.
        lv_ext = to_lower( lt_np[ lines( lt_np ) ] ).
      ELSE.
        lv_ext = 'pdf'.
      ENDIF.

      DATA lt_ar TYPE bapiret2_t.
      CLEAR lt_ar.
      mo_e->mo_backend->attach(
        EXPORTING
          is_file   = VALUE #( name      = <ls_a>-name
                               mime      = 'application/octet-stream'
                               extension = lv_ext
                               doc_type  = <ls_a>-tech
                               xdata     = lv_x )
        IMPORTING
          et_return = lt_ar
        CHANGING
          cs_handle = ls_handle ).
      mo_e->ms_handle = ls_handle.

      LOOP AT lt_ar INTO DATA(ls_am) WHERE type = 'E'.
        APPEND VALUE #( type = 'Error' text = ls_am-message ) TO mo_e->mt_msg.
      ENDLOOP.
      IF line_exists( lt_ar[ type = 'E' ] ).
        rv_ok = abap_false.
      ELSE.
        <ls_a>-filed = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD be_commit.
    rv_ok = abap_true.

    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX iv_step + 1.
    IF sy-subrc <> 0 OR ls_step-bknd_screen IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_init   TYPE bapiret2_t.
    DATA lt_ret    TYPE bapiret2_t.
    DATA(ls_handle) = mo_e->ms_handle.

    IF ls_handle-request_id IS INITIAL.
      mo_e->mo_backend->init(
        EXPORTING
          it_fields = be_fields( )
        IMPORTING
          et_return = lt_init
        CHANGING
          cs_handle = ls_handle ).
      mo_e->ms_handle = ls_handle.
      LOOP AT lt_init INTO DATA(ls_i) WHERE type = 'E'.
        APPEND VALUE #( type = 'Error' text = ls_i-message ) TO mo_e->mt_msg.
      ENDLOOP.
      IF line_exists( lt_init[ type = 'E' ] ).
        rv_ok = abap_false.
        RETURN.
      ENDIF.
    ENDIF.

*   DRAFT is a step whose entire job is to create the case, the way the Notary
*   portal's Start Service button does. The INIT( ) block above has just run and
*   there is nothing further to send, so this returns having posted nothing.
*
*   It is a NAMED branch and not a WHEN OTHERS fall-through, and that is the whole
*   point: a screen name the backend does not know posts nothing while looking
*   configured, which is the failure this repository already documents. DRAFT says
*   out loud that the step sends nothing because the case creation IS the send.
*
*   Put it on the last step before the first screened one. Everything downstream
*   then has a case to work against - including whatever the create call itself
*   returns, which for Notary is the applicant already added as first party. Left
*   to the first screened step instead, the case is created on the way OUT of that
*   step and the step renders with nothing the create call returned.
    IF to_upper( ls_step-bknd_screen ) = 'DRAFT'.
      RETURN.
    ENDIF.

    IF to_upper( ls_step-bknd_screen ) = 'ATTACH'.
      rv_ok = be_attach( ).
      RETURN.
    ENDIF.

    mo_e->mo_backend->step_commit(
      EXPORTING
        iv_step   = ls_step-bknd_screen
        it_fields = be_fields( )
      IMPORTING
        et_return = lt_ret
      CHANGING
        cs_handle = ls_handle ).
    mo_e->ms_handle = ls_handle.

    LOOP AT lt_ret INTO DATA(ls_m) WHERE type = 'E'.
      APPEND VALUE #( type = 'Error' text = ls_m-message ) TO mo_e->mt_msg.
    ENDLOOP.
    IF line_exists( lt_ret[ type = 'E' ] ).
      rv_ok = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD be_fields.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF ls_f-type = 'UPLOAD' OR ls_f-type = 'TABLE' OR ls_f-type = 'PAYFEE'
           OR ls_f-type = 'REQPANEL'.
          CONTINUE.
        ENDIF.
        IF ls_f-type = 'EDITABLE_TABLE'.
*         Grids were missing from this skip list, so mo_e->val_get( ) was called on a
*         structured table. Post them as JSON, on the same contract flatten_kv( )
*         already uses: only when the author gave the field a tech_name.
          IF ls_f-tech_name IS NOT INITIAL.
            APPEND VALUE #( name  = ls_f-name
                            value = mo_e->mo_grid->grid_to_json( ls_f-name ) ) TO rt.
          ENDIF.
          CONTINUE.
        ENDIF.
        APPEND VALUE #( name  = ls_f-name
                        value = mo_e->val_get( ls_f-name ) ) TO rt.
      ENDLOOP.
    ENDLOOP.
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_before_fields( EXPORTING io_ctx = mo_e CHANGING ct_fields = rt ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD flatten_kv.
    DATA(lv_from) = COND i( WHEN iv_step >= 0 THEN iv_step + 1 ELSE 1 ).
    DATA(lv_to)   = COND i( WHEN iv_step >= 0 THEN iv_step + 1 ELSE lines( mo_e->ms_config-steps ) ).
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step) FROM lv_from TO lv_to.
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF ls_f-type = 'UPLOAD' OR ls_f-type = 'TABLE' OR ls_f-type = 'REQPANEL'.
          CONTINUE.
        ENDIF.
        IF ls_f-type = 'EDITABLE_TABLE'.
          IF ls_f-tech_name IS NOT INITIAL.
            APPEND VALUE #( key = to_upper( ls_f-name ) value = mo_e->mo_grid->grid_to_json( ls_f-name ) ) TO rt_kv.
          ENDIF.
          CONTINUE.
        ENDIF.
        APPEND VALUE #( key = to_upper( ls_f-name ) value = mo_e->val_get( ls_f-name ) ) TO rt_kv.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD items_from_kv.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        DATA(lv_key) = to_upper( ls_f-name ).
        READ TABLE it_kv INTO DATA(ls_kv) WITH KEY key = lv_key.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        APPEND VALUE #( field = lv_key tech = ls_f-tech_name value = ls_kv-value ) TO rt.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD post_items.
*   Re-collect before every transmission. The click event already writes the target
*   field, but a grid whose rows were replaced by set_grid_data( ) after that click
*   would otherwise post a stale target.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_pstep).
      LOOP AT ls_pstep-fields INTO DATA(ls_pf) WHERE type = 'EDITABLE_TABLE'.
        mo_e->mo_grid->grid_sel_collect( ls_pf-name ).
      ENDLOOP.
    ENDLOOP.

    DATA(lt_kv) = flatten_kv( iv_step ).
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_before_post( EXPORTING io_ctx = mo_e CHANGING ct_kv = lt_kv ).
        CATCH cx_root INTO DATA(lx_bp).
          mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
            text = |on_before_post failed: { lx_bp->get_text( ) }| ) ).
      ENDTRY.
    ELSE.
      DELETE lt_kv WHERE key CP 'PAY_*'.
      DELETE lt_kv WHERE key = 'PAYFEE'.
    ENDIF.
    rt = items_from_kv( lt_kv ).
  ENDMETHOD.


  METHOD tables_for_backend.
    DATA(lv_from) = COND i( WHEN iv_step >= 0 THEN iv_step + 1 ELSE 1 ).
    DATA(lv_to)   = COND i( WHEN iv_step >= 0 THEN iv_step + 1 ELSE lines( mo_e->ms_config-steps ) ).

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step) FROM lv_from TO lv_to.
      LOOP AT ls_step-fields INTO DATA(ls_f) WHERE type = 'EDITABLE_TABLE'.
        DATA(lt_gc) = mo_e->mo_grid->grid_cols( ls_f ).
        IF lt_gc IS INITIAL.
          CONTINUE.
        ENDIF.

        ASSIGN COMPONENT to_upper( ls_f-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
        ASSIGN <tab> TO <t>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

*       UI_TABLE_NAME must be the FIELD name, never TECH_NAME. The BAdI mapper
*       joins the table rows to the grid's item with
*         READ TABLE table_data WITH KEY ui_table_name = <item>-fieldname
*       and that fieldname is the CJS field name - LICENSES - while TECH_NAME is
*       the ABAP path, GS_DATA-LICENSES[]. Sending the path meant the READ TABLE
*       never hit, so the rows arrived and were skipped. It only ever worked on
*       journeys whose grid had no TECH_NAME, which is why one service was fine
*       and the rest were not.
        DATA(lv_uitab) = to_upper( ls_f-name ).
        DATA lv_seq TYPE i.
        CLEAR lv_seq.
        LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
          lv_seq = lv_seq + 1.
          DATA ls_td TYPE /qnv/sb_tabl_def_st.
          CLEAR ls_td.
          ls_td-screen_name   = ls_step-bknd_screen.
          ls_td-categoryname  = mo_e->ms_config-backend-category.
          ls_td-ui_table_name = lv_uitab.
          ls_td-sequence      = |{ lv_seq }|.
          DATA lv_ci TYPE i.
          CLEAR lv_ci.
          LOOP AT lt_gc INTO DATA(gc).
            lv_ci = lv_ci + 1.
            IF lv_ci > 30.
              EXIT.
            ENDIF.
            ASSIGN COMPONENT gc-name OF STRUCTURE <row> TO FIELD-SYMBOL(<c>).
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.
            ASSIGN COMPONENT |UI_TABLE_COLUMN{ lv_ci }| OF STRUCTURE ls_td TO FIELD-SYMBOL(<col>).
            IF sy-subrc = 0.
              <col> = <c>.
            ENDIF.
          ENDLOOP.
          APPEND ls_td TO rt.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

*   The only hook on the TABLE payload. on_before_post( ) and on_before_fields( )
*   both hand over items; the tables were built here and passed straight to the
*   bridge with no way for a handler to touch them - so a marker column, a row
*   flag or a filter on the outgoing rows was impossible without 29 spec columns
*   to reach UI_TABLE_COLUMN29.
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_before_tables( EXPORTING io_ctx = mo_e CHANGING ct_tables = rt ).
        CATCH cx_root INTO DATA(lx_bt).
          mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
            text = |on_before_tables failed: { lx_bt->get_text( ) }| ) ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
