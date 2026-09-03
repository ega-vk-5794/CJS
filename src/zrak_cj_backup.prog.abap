REPORT zrak_cj_backup.

*&---------------------------------------------------------------------*
*& CJS CONFIGURATION BACKUP AND RESTORE
*&
*& A journey is rows in ZRAK_T_JNY*, not a program. abapGit carries the
*& ABAP and carries none of that: the configuration is client-dependent
*& table CONTENT, so a wrong feeder run, a bad Studio save or a mistaken
*& correction pack loses work that exists in exactly one place. This is
*& the fallback for that.
*&
*& WHY A TABLE IN SAP AND NOT A FILE DOWNLOAD
*&
*& A file was the obvious answer and is the weaker one. GUI_DOWNLOAD needs
*& SAPGUI, so it cannot run in a background job or from a transport-time
*& script; and the backup then lives on one developer's laptop, which is
*& the worst possible home for a disaster-recovery copy - it is not there
*& when the person is on leave, and nobody else can list what exists.
*&
*& So the PRIMARY store is ZRAK_CJ_BKP, inside the system, in the same
*& client as the config it protects. It is greppable with a SELECT, it
*& survives a client copy, it needs no GUI, and anyone can see what
*& snapshots exist. File export stays available as the SECONDARY copy for
*& taking a snapshot off-system, which is a real need - just not the
*& mechanism the recovery should depend on.
*&
*& An INDX cluster was considered and does not fit: SRTFD is CHAR22 and
*& ZRAK_JOURNEY_ID alone is CHAR30, so the key cannot carry journey plus
*& timestamp. A transport of copies (R3TR TABU) is the right tool for a
*& formal release and the wrong one for a developer taking a snapshot
*& before touching their own journey, which is what this is for.
*&
*& WHY CALL TRANSFORMATION id AND NOT JSON
*&
*& The payload is asXML from the kernel's identity transformation, which
*& is lossless and symmetric by construction - what goes in comes back
*& byte for byte, including blank fields and trailing spaces. The JSON
*& libraries here do not give that for free: Z2UI5_CL_AJSON's SET( )
*& defaults IV_IGNORE_EMPTY to ABAP_TRUE, so a blank ZLABEL_AR would be
*& dropped from the payload and come back as "never set" instead of
*& "deliberately empty". On a backup that is not a cosmetic difference.
*&
*& WHAT IT COVERS
*&
*& The seven journey-scoped tables plus the global text table. Layout is
*& included and is the one with a different key column - ZRAK_CJ_LAYOUT
*& calls it JOURNEY where every other table calls it JOURNEY_ID, which is
*& why the table list below carries the column name per table rather than
*& assuming one.
*&
*& RESTORE TAKES ITS OWN SNAPSHOT FIRST
*&
*& Restore deletes the journey's current rows and puts the snapshot's rows
*& back. A restore is therefore itself destructive, so before writing
*& anything it saves the CURRENT state as a snapshot of its own. A restore
*& from the wrong snapshot is then one more restore to undo, instead of
*& the end of the afternoon.
*&
*& Restore is also scoped: it only ever touches the journeys the snapshot
*& contains. It cannot empty a journey that was not in the backup.
*&
*& TEST RUN IS THE DEFAULT on every mode that writes.
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK bmode WITH FRAME.
PARAMETERS p_save RADIOBUTTON GROUP mod DEFAULT 'X' USER-COMMAND md.
PARAMETERS p_list RADIOBUTTON GROUP mod.
PARAMETERS p_show RADIOBUTTON GROUP mod.
PARAMETERS p_rest RADIOBUTTON GROUP mod.
PARAMETERS p_exp  RADIOBUTTON GROUP mod.
PARAMETERS p_imp  RADIOBUTTON GROUP mod.
SELECTION-SCREEN END OF BLOCK bmode.

SELECTION-SCREEN BEGIN OF BLOCK bsel WITH FRAME.
* THE JOURNEY. Blank means every journey - the whole-landscape snapshot.
* Filled means one journey, which is what a developer takes before
* touching their own service and what they restore afterwards.
PARAMETERS p_jrny TYPE zrak_journey_id.
PARAMETERS p_snap TYPE zrak_cj_bkp-snap_id.
PARAMETERS p_note TYPE zrak_cj_bkp-snapnote.
SELECTION-SCREEN END OF BLOCK bsel.

SELECTION-SCREEN BEGIN OF BLOCK bfil WITH FRAME.
PARAMETERS p_file TYPE rlgrap-filename LOWER CASE.
SELECTION-SCREEN END OF BLOCK bfil.

SELECTION-SCREEN BEGIN OF BLOCK brun WITH FRAME.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK brun.

*&---------------------------------------------------------------------*
CLASS lcl_bkp DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS run.

  PRIVATE SECTION.

*   One config table, and the column on it that carries the journey.
*   ZRAK_CJ_LAYOUT is the odd one out - JOURNEY, not JOURNEY_ID - and
*   ZRAK_T_CJ_TXT has no journey column at all, so it is global: it goes
*   into every full snapshot and into no single-journey snapshot, because
*   restoring one journey must never rewrite the shared text pool.
    TYPES: BEGIN OF ty_tab,
             tabname TYPE tabname,
             jcol    TYPE fieldname,
           END OF ty_tab,
           tt_tab TYPE STANDARD TABLE OF ty_tab WITH EMPTY KEY.

    CLASS-METHODS tables RETURNING VALUE(rt) TYPE tt_tab.

    CLASS-METHODS do_save    IMPORTING iv_note       TYPE clike
                                       iv_quiet      TYPE abap_bool DEFAULT abap_false
                             RETURNING VALUE(rv_snap) TYPE zrak_cj_bkp-snap_id.
    CLASS-METHODS do_list.
    CLASS-METHODS do_show.
    CLASS-METHODS do_restore.
    CLASS-METHODS do_export.
    CLASS-METHODS do_import.

*   Every journey named in a snapshot. Restore is scoped to exactly this
*   set - a journey absent from the backup is never touched.
    CLASS-METHODS snap_journeys IMPORTING iv_snap   TYPE zrak_cj_bkp-snap_id
                                RETURNING VALUE(rt) TYPE string_table.

    CLASS-METHODS new_id RETURNING VALUE(rv) TYPE zrak_cj_bkp-snap_id.
    CLASS-METHODS where_for IMPORTING is_tab    TYPE ty_tab
                                      iv_jrny   TYPE clike
                            RETURNING VALUE(rv) TYPE string.
ENDCLASS.

CLASS lcl_bkp IMPLEMENTATION.

  METHOD tables.
    rt = VALUE tt_tab(
      ( tabname = 'ZRAK_T_JNY'      jcol = 'JOURNEY_ID' )
      ( tabname = 'ZRAK_T_JNY_STEP' jcol = 'JOURNEY_ID' )
      ( tabname = 'ZRAK_T_JNY_FLD'  jcol = 'JOURNEY_ID' )
      ( tabname = 'ZRAK_T_JNY_RULE' jcol = 'JOURNEY_ID' )
      ( tabname = 'ZRAK_T_JNY_OPT'  jcol = 'JOURNEY_ID' )
      ( tabname = 'ZRAK_T_JNY_COL'  jcol = 'JOURNEY_ID' )
      ( tabname = 'ZRAK_CJ_LAYOUT'  jcol = 'JOURNEY' )
      ( tabname = 'ZRAK_T_CJ_TXT'   jcol = '' ) ).
  ENDMETHOD.


  METHOD new_id.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    rv = |CJS{ lv_ts TIMESTAMP = ISO }|.
    REPLACE ALL OCCURRENCES OF '-' IN rv WITH ''.
    REPLACE ALL OCCURRENCES OF ':' IN rv WITH ''.
    REPLACE ALL OCCURRENCES OF 'T' IN rv WITH ''.
    REPLACE ALL OCCURRENCES OF '.' IN rv WITH ''.
    CONDENSE rv NO-GAPS.
  ENDMETHOD.


  METHOD where_for.
*   A global table (no journey column) is only ever taken whole, and only
*   in a full snapshot. Returning a WHERE that matches nothing would put
*   an empty payload in the backup and look like a successful save.
    CLEAR rv.
    IF is_tab-jcol IS INITIAL OR iv_jrny IS INITIAL.
      RETURN.
    ENDIF.
    rv = |{ is_tab-jcol } = '{ iv_jrny }'|.
  ENDMETHOD.


  METHOD do_save.
    rv_snap = new_id( ).

    IF iv_quiet = abap_false.
      WRITE: / 'Snapshot', rv_snap.
      IF p_jrny IS INITIAL.
        WRITE: / 'Scope: EVERY journey, plus the global text table.'.
      ELSE.
        WRITE: / 'Scope: journey', p_jrny.
      ENDIF.
      SKIP.
    ENDIF.

    DATA lv_total TYPE i.
    DATA(lt_cfg) = tables( ).

    LOOP AT lt_cfg INTO DATA(ls_t).

*     A single-journey snapshot skips the global text table on purpose.
*     Restoring one journey must not rewrite text every other journey
*     reads - see the note on TABLES( ).
      IF ls_t-jcol IS INITIAL AND p_jrny IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      DATA lr_tab TYPE REF TO data.
      CREATE DATA lr_tab TYPE STANDARD TABLE OF (ls_t-tabname).
      ASSIGN lr_tab->* TO FIELD-SYMBOL(<tab>).

*     ONE STATEMENT, WITH THE CONDITION IN AN INTERNAL TABLE.
*
*     This was an IF/ELSE around two SELECTs that differed only by the
*     WHERE, and it kept coming back from the syntax check as "the
*     INTO/APPENDING clause must be at the end of the SELECT" - the two
*     forms are easy to correct in one branch and miss in the other, and
*     that is exactly what happened twice.
*
*     A dynamic WHERE given as an INTERNAL TABLE is ignored when the table
*     is empty, so the unfiltered case and the per-journey case are the
*     same statement and there is only one INTO left to get right.
      DATA lt_where TYPE TABLE OF string.
      CLEAR lt_where.
      DATA(lv_where) = where_for( is_tab = ls_t iv_jrny = p_jrny ).
      IF lv_where IS NOT INITIAL.
        APPEND lv_where TO lt_where.
      ENDIF.

      SELECT * FROM (ls_t-tabname) WHERE (lt_where) INTO TABLE @<tab>.

      DATA(lv_cnt) = lines( <tab> ).
      lv_total = lv_total + lv_cnt.

*     THE IDENTITY TRANSFORMATION, not a serializer of ours. Lossless and
*     symmetric by construction - a blank column comes back blank rather
*     than missing.
      DATA lv_xml TYPE string.
      CLEAR lv_xml.
      CALL TRANSFORMATION id SOURCE tab = <tab> RESULT XML lv_xml.

      IF iv_quiet = abap_false.
        WRITE: / ls_t-tabname, 34 lv_cnt, 46 'row(s)'.
      ENDIF.

      IF p_test = abap_false.
        DATA ls_b TYPE zrak_cj_bkp.
        CLEAR ls_b.
        ls_b-snap_id    = rv_snap.
        ls_b-tabname    = ls_t-tabname.
        ls_b-journey_id = p_jrny.
        ls_b-rowcnt     = lv_cnt.
        ls_b-snapnote   = iv_note.
        ls_b-created_by = sy-uname.
        GET TIME STAMP FIELD ls_b-created_at.
        ls_b-payload    = lv_xml.
        INSERT zrak_cj_bkp FROM ls_b.
      ENDIF.
    ENDLOOP.

    IF iv_quiet = abap_false.
      SKIP.
      IF p_test = abap_true.
        WRITE: / 'TEST RUN - nothing was stored.' COLOR col_total.
        WRITE: / 'Untick Test run to write snapshot', rv_snap.
      ELSE.
        COMMIT WORK.
        WRITE: / 'Stored', lv_total, 'row(s) as snapshot', rv_snap
                 COLOR col_positive.
      ENDIF.
    ELSEIF p_test = abap_false.
      COMMIT WORK.
    ENDIF.
  ENDMETHOD.


  METHOD do_list.
*   The inventory, read without touching the payloads - PAYLOAD is a LOB
*   and pulling it back to count snapshots would be pointless traffic.
    SELECT snap_id, journey_id, tabname, rowcnt, snapnote,
           created_by, created_at
      FROM zrak_cj_bkp
      ORDER BY snap_id DESCENDING, tabname ASCENDING
      INTO TABLE @DATA(lt_b).

    IF lines( lt_b ) = 0.
      WRITE: / 'No snapshots yet.' COLOR col_total.
      RETURN.
    ENDIF.

    DATA lv_last TYPE char32.
    LOOP AT lt_b INTO DATA(ls_b).
      IF ls_b-snap_id <> lv_last.
        SKIP.
        DATA(lv_scope) = COND string( WHEN ls_b-journey_id IS INITIAL
                                      THEN '(all journeys)'
                                      ELSE CONV string( ls_b-journey_id ) ).
        FORMAT COLOR col_group.
        WRITE: / ls_b-snap_id, 36 lv_scope, 70 ls_b-created_by,
               84 ls_b-snapnote.
        FORMAT COLOR OFF.
        lv_last = ls_b-snap_id.
      ENDIF.
      WRITE: /4 ls_b-tabname, 38 ls_b-rowcnt, 50 'row(s)'.
    ENDLOOP.
  ENDMETHOD.


  METHOD do_show.
    IF p_snap IS INITIAL.
      WRITE: / 'Give a snapshot id. Run List first.' COLOR col_negative.
      RETURN.
    ENDIF.

    SELECT tabname, journey_id, rowcnt, snapnote, created_by, created_at
      FROM zrak_cj_bkp
      WHERE snap_id = @p_snap
      ORDER BY tabname
      INTO TABLE @DATA(lt_b).

    IF lines( lt_b ) = 0.
      WRITE: / 'No such snapshot:', p_snap COLOR col_negative.
      RETURN.
    ENDIF.

    WRITE: / 'Snapshot', p_snap.
    SKIP.

*   What is in the backup against what is in the tables NOW. This is the
*   comparison that tells somebody whether a restore would change
*   anything, before they run it.
    WRITE: / 'Table', 34 'in snapshot', 50 'live now'.
    ULINE.

    DATA(lt_cfg) = tables( ).
    LOOP AT lt_b INTO DATA(ls_b).
      READ TABLE lt_cfg INTO DATA(ls_t) WITH KEY tabname = ls_b-tabname.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

*     Same one-statement form as DO_SAVE( ) - an empty condition table
*     means no WHERE, so the full-table count and the per-journey count are
*     the same statement.
      DATA lt_where TYPE TABLE OF string.
      CLEAR lt_where.
      DATA(lv_where) = where_for( is_tab = ls_t iv_jrny = ls_b-journey_id ).
      IF lv_where IS NOT INITIAL.
        APPEND lv_where TO lt_where.
      ENDIF.

      DATA lv_live TYPE i.
      SELECT COUNT(*) FROM (ls_t-tabname) WHERE (lt_where) INTO @lv_live.

      WRITE: / ls_b-tabname, 34 ls_b-rowcnt, 50 lv_live.
      IF lv_live <> ls_b-rowcnt.
        WRITE: 62 'differs' COLOR col_negative.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD snap_journeys.
    SELECT DISTINCT journey_id FROM zrak_cj_bkp
      WHERE snap_id = @iv_snap
      INTO TABLE @DATA(lt_j).
    LOOP AT lt_j INTO DATA(ls_j).
      APPEND CONV string( ls_j-journey_id ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD do_restore.
    IF p_snap IS INITIAL.
      WRITE: / 'Give a snapshot id. Run List first.' COLOR col_negative.
      RETURN.
    ENDIF.

    SELECT * FROM zrak_cj_bkp
      WHERE snap_id = @p_snap ORDER BY tabname
      INTO TABLE @DATA(lt_b).
    IF lines( lt_b ) = 0.
      WRITE: / 'No such snapshot:', p_snap COLOR col_negative.
      RETURN.
    ENDIF.

    WRITE: / 'Restoring snapshot', p_snap.
    IF p_test = abap_true.
      WRITE: / 'TEST RUN - nothing is written.' COLOR col_total.
    ENDIF.
    SKIP.

*   THE SAFETY SNAPSHOT. Restore overwrites, so the state it overwrites is
*   saved first and its id printed. A restore from the wrong snapshot is
*   then one more restore to undo.
    IF p_test = abap_false.
      DATA(lv_pre) = do_save( iv_note  = |PRE-RESTORE of { p_snap }|
                              iv_quiet = abap_true ).
      WRITE: / 'Current state saved first as', lv_pre COLOR col_positive.
      WRITE: / 'If this restore is wrong, restore that id to undo it.'.
      SKIP.
    ENDIF.

    DATA(lt_cfg) = tables( ).
    LOOP AT lt_b INTO DATA(ls_b).
      READ TABLE lt_cfg INTO DATA(ls_t) WITH KEY tabname = ls_b-tabname.
      IF sy-subrc <> 0.
        WRITE: / ls_b-tabname, 34 'not a known config table - skipped'
                 COLOR col_negative.
        CONTINUE.
      ENDIF.

      DATA lr_tab TYPE REF TO data.
      CREATE DATA lr_tab TYPE STANDARD TABLE OF (ls_t-tabname).
      ASSIGN lr_tab->* TO FIELD-SYMBOL(<tab>).

      DATA(lv_xml) = ls_b-payload.
      TRY.
          CALL TRANSFORMATION id SOURCE XML lv_xml RESULT tab = <tab>.
        CATCH cx_root INTO DATA(lx).
          WRITE: / ls_b-tabname, 34 'payload unreadable:', lx->get_text( )
                   COLOR col_negative.
          CONTINUE.
      ENDTRY.

      DATA(lv_where) = where_for( is_tab = ls_t iv_jrny = ls_b-journey_id ).

      DATA(lv_back) = lines( <tab> ).
      WRITE: / ls_b-tabname, 34 lv_back, 46 'row(s) back'.

      IF p_test = abap_true.
        CONTINUE.
      ENDIF.

*     Scoped delete. A blank WHERE only happens for a full snapshot of a
*     global table, which is the one case where replacing the whole table
*     is what was asked for.
      IF lv_where IS INITIAL.
        DELETE FROM (ls_t-tabname).
      ELSE.
        DELETE FROM (ls_t-tabname) WHERE (lv_where).
      ENDIF.

      IF lines( <tab> ) > 0.
        INSERT (ls_t-tabname) FROM TABLE @<tab>.
      ENDIF.
    ENDLOOP.

    IF p_test = abap_false.
      COMMIT WORK.
      SKIP.
      WRITE: / 'Restored.' COLOR col_positive.
      WRITE: / 'Journeys touched:'.
      DATA(lt_touched) = snap_journeys( p_snap ).
      LOOP AT lt_touched INTO DATA(lv_j).
        DATA(lv_jshow) = COND string( WHEN lv_j IS INITIAL
                                      THEN '(all journeys)' ELSE lv_j ).
        WRITE: /4 lv_jshow.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD do_export.
*   THE SECONDARY COPY. One file per snapshot, for taking it off-system.
*   GUI_DOWNLOAD needs SAPGUI, so this mode alone cannot run in a
*   background job - which is exactly why it is not the primary store.
    IF p_snap IS INITIAL OR p_file IS INITIAL.
      WRITE: / 'Give a snapshot id and a file path.' COLOR col_negative.
      RETURN.
    ENDIF.

    SELECT * FROM zrak_cj_bkp
      WHERE snap_id = @p_snap ORDER BY tabname
      INTO TABLE @DATA(lt_b).
    IF lines( lt_b ) = 0.
      WRITE: / 'No such snapshot:', p_snap COLOR col_negative.
      RETURN.
    ENDIF.

    DATA lt_line TYPE STANDARD TABLE OF string.
    LOOP AT lt_b INTO DATA(ls_b).
*     One table per record, delimited so IMPORT can split it back. The
*     payload is XML and never contains this marker.
      APPEND |*CJSBKP*{ ls_b-tabname }*{ ls_b-journey_id }*{ ls_b-rowcnt }| TO lt_line.
      APPEND ls_b-payload TO lt_line.
    ENDLOOP.

    DATA(lv_path) = p_file.
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename                = lv_path
        filetype                = 'ASC'
        codepage                = '4110'
      TABLES
        data_tab                = lt_line
      EXCEPTIONS
        file_write_error        = 1
        no_authority            = 2
        OTHERS                  = 3.
    IF sy-subrc <> 0.
      WRITE: / 'Download failed, sy-subrc', sy-subrc COLOR col_negative.
      RETURN.
    ENDIF.
    WRITE: / 'Wrote', lines( lt_b ), 'table(s) to', lv_path COLOR col_positive.
  ENDMETHOD.


  METHOD do_import.
    IF p_file IS INITIAL.
      WRITE: / 'Give a file path.' COLOR col_negative.
      RETURN.
    ENDIF.

    DATA lt_line TYPE STANDARD TABLE OF string.
    DATA(lv_path) = p_file.
    CALL FUNCTION 'GUI_UPLOAD'
      EXPORTING
        filename                = lv_path
        filetype                = 'ASC'
        codepage                = '4110'
      TABLES
        data_tab                = lt_line
      EXCEPTIONS
        file_open_error         = 1
        no_authority            = 2
        OTHERS                  = 3.
    IF sy-subrc <> 0.
      WRITE: / 'Upload failed, sy-subrc', sy-subrc COLOR col_negative.
      RETURN.
    ENDIF.

    DATA lv_snap TYPE zrak_cj_bkp-snap_id.
    lv_snap = COND #( WHEN p_snap IS NOT INITIAL THEN p_snap ELSE new_id( ) ).
    WRITE: / 'Importing into snapshot', lv_snap.
    IF p_test = abap_true.
      WRITE: / 'TEST RUN - nothing is stored.' COLOR col_total.
    ENDIF.
    SKIP.

    DATA lv_tab  TYPE tabname.
    DATA lv_jrny TYPE zrak_journey_id.
    DATA lv_open TYPE abap_bool.

    LOOP AT lt_line INTO DATA(lv_line).
      IF lv_line CP '*CJSBKP**'.
        SPLIT lv_line AT '*' INTO TABLE DATA(lt_p).
*       1 blank, 2 CJSBKP, 3 table, 4 journey, 5 rows
        lv_tab  = VALUE #( lt_p[ 3 ] OPTIONAL ).
        lv_jrny = VALUE #( lt_p[ 4 ] OPTIONAL ).
        lv_open = abap_true.
        CONTINUE.
      ENDIF.

      IF lv_open = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_ishow) = COND string( WHEN lv_jrny IS INITIAL
                                    THEN '(all)' ELSE CONV string( lv_jrny ) ).
      WRITE: / lv_tab, 34 lv_ishow.
      IF p_test = abap_false.
        DATA ls_b TYPE zrak_cj_bkp.
        CLEAR ls_b.
        ls_b-snap_id    = lv_snap.
        ls_b-tabname    = lv_tab.
        ls_b-journey_id = lv_jrny.
        ls_b-snapnote   = |imported from { lv_path }|.
        ls_b-created_by = sy-uname.
        GET TIME STAMP FIELD ls_b-created_at.
        ls_b-payload    = lv_line.
        INSERT zrak_cj_bkp FROM ls_b.
      ENDIF.
      lv_open = abap_false.
    ENDLOOP.

    IF p_test = abap_false.
      COMMIT WORK.
      WRITE: / 'Imported as snapshot', lv_snap COLOR col_positive.
      WRITE: / 'It is only stored, not applied. Restore it to apply.'.
    ENDIF.
  ENDMETHOD.


  METHOD run.
    WRITE: / 'CJS configuration backup'.
    ULINE.

*   THE JOURNEY GOES INTO A DYNAMIC WHERE, so it is checked before it gets
*   there. A quote in the value would not "just fail" - it would change the
*   statement, and on the restore path that statement is a DELETE. Journey
*   ids here are codes like E016 or M011, so anything outside this set is a
*   typo or worse, and either way the answer is to stop.
    CONSTANTS lc_ok TYPE string
      VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_- '.
    IF p_jrny IS NOT INITIAL AND p_jrny CN lc_ok.
      WRITE: / 'Journey id contains characters that cannot go into a dynamic WHERE.'
               COLOR col_negative.
      WRITE: / 'Use the plain journey code, for example E016.'.
      RETURN.
    ENDIF.

    CASE abap_true.
      WHEN p_save. do_save( p_note ).
      WHEN p_list. do_list( ).
      WHEN p_show. do_show( ).
      WHEN p_rest. do_restore( ).
      WHEN p_exp.  do_export( ).
      WHEN p_imp.  do_import( ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  lcl_bkp=>run( ).
