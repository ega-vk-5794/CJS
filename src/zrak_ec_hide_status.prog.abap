REPORT zrak_ec_hide_status.

* Hides the STATUS column of the results grid on Track e-Complaint (EC02)
* and Track e-Suggestion (EC06).
*
* WHY. Both details steps show the status twice: once on the card above the
* table, which is where the citizen reads it, and once as a column in the
* table, which on every screenshot so far has been empty. Two answers to
* the same question, one of them blank.
*
* HIDDEN, NOT DELETED, and this is the part worth reading before changing
* it to a DELETE. A backend table's cells are positional at BOTH ends: the
* bridge assigns FIELD1..FIELDn in order to configured column 1..n, and the
* slot a value lands in comes from LIST_SEQUENCE in /QNV/SB_UI_DEFIN, not
* from the CJS spec. Nothing checks that the two agree. Remove a column and
* every cell after it shifts one place left - silently, with no error, just
* a department showing where a status used to be.
*
* STATUS is last today, so a delete would probably survive. It would stop
* surviving the first time somebody adds a column on the legacy side, and
* the failure would surface far from this report. Hiding keeps the column
* in the list, in the model and in the BAdI payload, and only stops it
* being drawn - see ZCL_RAK_JOURNEY_GRID->GRID_COLS( ), where HIDE is
* deliberately treated differently from the SEL and FIX directives for
* exactly this reason.
*
* TWO PATHS, because a grid can be configured either way and these two
* journeys were migrated, not authored. GRID_COLS( ) reads ZRAK_T_JNY_COL
* first and falls back to the packed spec in ZRAK_T_JNY_FLD-DEFAULT_VAL, so
* this follows the same order: if the grid has column rows, set HIDDEN on
* the STATUS row; if it has none, put HIDE in the type slot of the STATUS
* token in DEFAULT_VAL. Doing only one would work on one journey and do
* nothing at all on the other, and the report would still say it succeeded.
*
* Test run is the default. Nothing is written until P_COMMIT is ticked, and
* the test run prints exactly what a commit run would change.
*
* Re-runnable: setting a flag that is already set, or a slot that already
* says HIDE, changes nothing.

PARAMETERS p_commit TYPE abap_bool AS CHECKBOX DEFAULT abap_false.

START-OF-SELECTION.

  DATA lt_jny  TYPE TABLE OF zrak_t_jny-journey_id.
  DATA lv_done TYPE i.

  APPEND 'EC02' TO lt_jny.
  APPEND 'EC06' TO lt_jny.

  IF p_commit = abap_false.
    WRITE: / 'TEST RUN - nothing written. Tick "p_commit" to apply.'.
  ELSE.
    WRITE: / 'COMMIT RUN - changes will be written.'.
  ENDIF.
  SKIP.

  LOOP AT lt_jny INTO DATA(lv_jny).

*   Every grid on the journey, not just the one we happen to know about.
*   EC02 and EC06 have one each today; a journey that grows a second is not
*   a reason for this to start missing it.
    SELECT step_id, field_name, ftype, default_val
      FROM zrak_t_jny_fld
      WHERE journey_id = @lv_jny
        AND ( ftype = 'TABLE' OR ftype = 'EDITABLE_TABLE' )
      INTO TABLE @DATA(lt_fld).

    IF sy-subrc <> 0.
      WRITE: / lv_jny, ': no TABLE or EDITABLE_TABLE field - skipped.'.
      CONTINUE.
    ENDIF.

    LOOP AT lt_fld INTO DATA(ls_fld).

*     ---- PATH 1: ZRAK_T_JNY_COL ----------------------------------------
*     Checked first because GRID_COLS( ) checks it first: a grid with rows
*     here never reaches the DEFAULT_VAL parse at all, so editing the spec
*     on such a grid is a change that does nothing and reports success.
*     Read the rows and match in ABAP rather than with UPPER( ) in the
*     WHERE. COL_NAME is free text on the column editor so the comparison
*     has to be case-insensitive, but an SQL function in a WHERE is a
*     release-dependent thing to write and this cannot be compiled here.
*     TO_UPPER( ) on the ABAP side costs a few rows and no risk.
      SELECT col_name, zlabel, hidden
        FROM zrak_t_jny_col
        WHERE journey_id = @lv_jny
          AND step_id    = @ls_fld-step_id
          AND field_name = @ls_fld-field_name
        INTO TABLE @DATA(lt_col).
      DATA(lv_ncol) = lines( lt_col ).

      DATA lv_cname TYPE zrak_t_jny_col-col_name.
      DATA lv_chid  TYPE abap_bool.
      CLEAR: lv_cname, lv_chid.
      LOOP AT lt_col INTO DATA(ls_col).
*       NAME OR LABEL. The heading a citizen reads is ZLABEL; the column
*       NAME under it is whatever the migration produced. On EC02 the two
*       happened to agree - the spec there reads STATUS:@122 - but that is
*       not something to rely on for the next journey.
        IF to_upper( condense( CONV string( ls_col-col_name ) ) ) = 'STATUS'
           OR to_upper( condense( CONV string( ls_col-zlabel ) ) ) = 'STATUS'.
          lv_cname = ls_col-col_name.
          lv_chid  = ls_col-hidden.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_cname IS NOT INITIAL.
        IF lv_chid = abap_true.
          WRITE: / lv_jny, ls_fld-field_name, ': STATUS column already hidden.'.
        ELSE.
          WRITE: / lv_jny, ls_fld-field_name, ': ZRAK_T_JNY_COL - set HIDDEN on STATUS.'.
          IF p_commit = abap_true.
            UPDATE zrak_t_jny_col
              SET hidden = @abap_true
              WHERE journey_id = @lv_jny
                AND step_id    = @ls_fld-step_id
                AND field_name = @ls_fld-field_name
                AND col_name   = @lv_cname.
            lv_done = lv_done + 1.
          ENDIF.
        ENDIF.
        CONTINUE.
      ENDIF.

*     A grid with ANY column rows is on that path, so a STATUS row missing
*     from it means the column is not configured there and the spec is not
*     where it lives either. Say so rather than falling through and editing
*     a DEFAULT_VAL that nothing reads.
      IF lv_ncol > 0.
        WRITE: / lv_jny, ls_fld-field_name,
                 ': has ZRAK_T_JNY_COL rows, none named or labelled STATUS.'.
        LOOP AT lt_col INTO DATA(ls_shw).
          WRITE: /   '   column:', ls_shw-col_name, '/', ls_shw-zlabel.
        ENDLOOP.
        CONTINUE.
      ENDIF.

*     ---- PATH 2: the packed DEFAULT_VAL spec ---------------------------
*     name:label:type:src:label_ar, columns separated by |. HIDE goes in
*     the TYPE slot; the column stays in the list and keeps its position.
      IF ls_fld-default_val IS INITIAL.
        WRITE: / lv_jny, ls_fld-field_name, ': no column rows and no spec - skipped.'.
        CONTINUE.
      ENDIF.

      DATA lv_new  TYPE string.
      DATA lv_hit  TYPE abap_bool.
      DATA lv_was  TYPE abap_bool.
      CLEAR: lv_new, lv_hit, lv_was.

      SPLIT CONV string( ls_fld-default_val ) AT '|' INTO TABLE DATA(lt_tok).
      LOOP AT lt_tok INTO DATA(lv_tok).
        SPLIT lv_tok AT ':' INTO DATA(lv_n) DATA(lv_l) DATA(lv_t) DATA(lv_s) DATA(lv_a).

*       Slot 1 is the column name, slot 2 the heading - which on these
*       migrated grids is a TEXT reference such as @122 rather than a word,
*       so the name is usually the only readable half. Both are checked.
        IF to_upper( condense( lv_n ) ) = 'STATUS'
           OR to_upper( condense( lv_l ) ) = 'STATUS'.
          lv_hit = abap_true.
          IF condense( lv_l ) = '-' AND to_upper( condense( lv_t ) ) = 'HIDE'.
            lv_was = abap_true.
          ENDIF.
*         BOTH SLOTS, because TABLE and EDITABLE_TABLE hide a column by
*         different means and a migrated journey can be either.
*
*         EDITABLE_TABLE goes through GRID_COLS( ), which reads HIDE out of
*         the TYPE slot and sets GC-HIDE. That is the documented way and it
*         is what this report set on the first run.
*
*         TABLE does not use GC-HIDE at all. RENDER_BLOCK( )'s own TABLE
*         branch re-parses DEFAULT_VAL into name / header / type, keeps the
*         header, and IGNORES the type - so HIDE in the type slot changed
*         nothing on EC02 and the column kept rendering. What that branch
*         hides is a column whose resolved header is blank or '-'. Blank is
*         no use, because an empty header falls back to the column NAME and
*         is therefore never empty. '-' is the only lever there is.
*
*         So the header becomes '-' and the type stays HIDE: the first hides
*         it on a TABLE, the second on an EDITABLE_TABLE, and neither harms
*         the other. COL_HEADER( ) returns anything not starting with @
*         untouched, so '-' survives to the comparison.
          lv_l = '-'.
          lv_t = 'HIDE'.
        ENDIF.

*       Rebuilt with all five slots every time, and the trailing empties
*       trimmed below. Writing back only the slots that were present would
*       drop a label_ar from a column that had one.
        DATA(lv_re) = |{ lv_n }:{ lv_l }:{ lv_t }:{ lv_s }:{ lv_a }|.
        WHILE strlen( lv_re ) > 0 AND substring( val = lv_re off = strlen( lv_re ) - 1 len = 1 ) = ':'.
          lv_re = substring( val = lv_re len = strlen( lv_re ) - 1 ).
        ENDWHILE.

        lv_new = COND #( WHEN lv_new IS INITIAL THEN lv_re ELSE |{ lv_new }\|{ lv_re }| ).
      ENDLOOP.

      IF lv_hit = abap_false.
*       PRINT THE SPEC. "Nothing to hide" on its own is the least useful
*       thing this report can say: it is indistinguishable from a column
*       that is there under a name nobody guessed. The spec is short and
*       settles it on the spot.
        WRITE: / lv_jny, ls_fld-field_name, ': no column named or labelled STATUS.'.
        WRITE: /   '   spec:', ls_fld-default_val.
        CONTINUE.
      ENDIF.
      IF lv_was = abap_true.
        WRITE: / lv_jny, ls_fld-field_name, ': STATUS already HIDE in the spec.'.
        CONTINUE.
      ENDIF.

*     DEFAULT_VAL is CHAR(1000) and truncates on INSERT rather than
*     complaining. HIDE is four characters longer than most type slots it
*     replaces, so a spec already near the limit could lose its last column
*     to this - which would look exactly like the bug this report exists to
*     avoid.
      IF strlen( lv_new ) > 1000.
        WRITE: / lv_jny, ls_fld-field_name,
                 ': REFUSED - the rewritten spec is', strlen( lv_new ),
                 'characters and DEFAULT_VAL holds 1000. Move this grid to',
                 'ZRAK_T_JNY_COL instead.'.
        CONTINUE.
      ENDIF.

      WRITE: / lv_jny, ls_fld-field_name, ': DEFAULT_VAL - STATUS type slot set to HIDE.'.
      WRITE: /   '  was:', ls_fld-default_val.
      WRITE: /   '  now:', lv_new.

      IF p_commit = abap_true.
        UPDATE zrak_t_jny_fld
          SET default_val = @lv_new
          WHERE journey_id = @lv_jny
            AND step_id    = @ls_fld-step_id
            AND field_name = @ls_fld-field_name.
        lv_done = lv_done + 1.
      ENDIF.

    ENDLOOP.
  ENDLOOP.

  IF p_commit = abap_true.
    COMMIT WORK AND WAIT.
    SKIP.
    WRITE: / 'Done -', lv_done, 'row(s) changed.'.
    WRITE: / 'No class needs activating for this: it is configuration only.'.
    WRITE: / 'Reopen EC02, search a complaint, and confirm the table no longer'.
    WRITE: / 'carries a Status column while the card above it still does.'.
  ENDIF.
