REPORT zrak_cj_cfg_wipe.

*&---------------------------------------------------------------------*
*& CLEAR THE CJS CONFIGURATION FOR ONE OR MORE JOURNEY PREFIXES.
*&
*& WRITTEN FOR A QUALITY SYSTEM CARRYING DUPLICATE DOK AND EPDA ROWS,
*& and general enough to be pointed anywhere. It exists because there was
*& no runnable entry point for TEARDOWN_ALL( ) at all - only per-id
*& TEARDOWN( ), reachable from inside ZRAK_M_MUNI_LOAD.
*&
*& TEST RUN IS THE DEFAULT, the same discipline as ZRAK_CJ_ATT_PURGE. A
*& wipe of two whole families is not something to discover you have done.
*& The test run prints exactly what the real one would delete, table by
*& table, and nothing is touched.
*&
*& AND IT DIAGNOSES BEFORE IT DELETES, which is the actual point. "Double
*& entries" is two different faults with two different remedies:
*&
*&   DUPLICATE FIELDS inside one journey - the same JOURNEY_ID/STEP_ID/NAME
*&   more than once. That is a load report run WITHOUT teardown first.
*&   Wiping fixes it; reloading over the top reproduces it exactly, so if
*&   this list is long the loader is what to fix, not the data.
*&
*&   ORPHANS - child rows whose ZRAK_T_JNY header is gone. TEARDOWN( )
*&   cannot remove these: it reads the header first and returns "not found"
*&   when there is none, so the children survive every wipe and are
*&   invisible to the Studio. They are reported here and removed only by
*&   the orphan sweep below.
*&
*& IT NEVER TOUCHES THE PORTAL TILES. TEARDOWN( ) used to delete
*& ZEGA_T_CJ_GRP, _ID and _IDT along with the CJS rows, and run over a family
*& prefix in quality that took out the landing page. Those DELETEs are gone
*& from the migrator and the tick that used to select them is gone from here.
*& A journey wiped by this report disappears from the Studio and keeps its
*& place on the portal, which is what makes a wipe-and-reload safe to do
*& while other people are testing.
*&---------------------------------------------------------------------*

SELECT-OPTIONS s_pfx FOR sy-lisel NO INTERVALS.

PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_orph AS CHECKBOX DEFAULT ' '.

CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_j,
             journey TYPE zrak_journey_id,
             tile    TYPE zrak_t_jny-tile_code,
           END OF ty_j,
           tt_j TYPE STANDARD TABLE OF ty_j WITH EMPTY KEY.

    CLASS-METHODS patterns RETURNING VALUE(rt) TYPE string_table.
    CLASS-METHODS collect  RETURNING VALUE(rt) TYPE tt_j.
    CLASS-METHODS counts   IMPORTING it_j TYPE tt_j.
    CLASS-METHODS dupes    IMPORTING it_j TYPE tt_j.
    CLASS-METHODS orphans.
    CLASS-METHODS wipe     IMPORTING it_j TYPE tt_j.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD patterns.
*   A PREFIX, NOT A JOURNEY ID. 'DOK' and 'DOK_' both work; the % is added
*   here so nobody has to remember SQL in a selection field.
    LOOP AT s_pfx ASSIGNING FIELD-SYMBOL(<r>) WHERE sign = 'I' AND option = 'EQ'.
      CHECK <r>-low IS NOT INITIAL.
      APPEND |{ to_upper( condense( CONV string( <r>-low ) ) ) }%| TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD collect.
    DATA(lt_pat) = patterns( ).
    LOOP AT lt_pat INTO DATA(lv_pat).
      SELECT journey_id AS journey, tile_code AS tile
        FROM zrak_t_jny
        WHERE journey_id LIKE @lv_pat
        APPENDING CORRESPONDING FIELDS OF TABLE @rt.
    ENDLOOP.
*   A journey matched by two prefixes must not be torn down twice - the
*   second pass would report "not found" and read as a failure.
    SORT rt BY journey.
    DELETE ADJACENT DUPLICATES FROM rt COMPARING journey.
  ENDMETHOD.


  METHOD counts.
    DATA lv_s TYPE i.
    DATA lv_f TYPE i.
    DATA lv_o TYPE i.
    DATA lv_r TYPE i.
    DATA lv_l TYPE i.

    WRITE: / 'JOURNEY', 42 'STEPS', 50 'FIELDS', 60 'OPTS', 68 'RULES', 77 'LAYOUT', 86 'TILE'.
    ULINE.
    LOOP AT it_j INTO DATA(ls_j).
      SELECT COUNT(*) FROM zrak_t_jny_step INTO @lv_s WHERE journey_id = @ls_j-journey.
      SELECT COUNT(*) FROM zrak_t_jny_fld  INTO @lv_f WHERE journey_id = @ls_j-journey.
      SELECT COUNT(*) FROM zrak_t_jny_opt  INTO @lv_o WHERE journey_id = @ls_j-journey.
      SELECT COUNT(*) FROM zrak_t_jny_rule INTO @lv_r WHERE journey_id = @ls_j-journey.
*     JOURNEY, not JOURNEY_ID. The layout table names its column differently
*     from every other config table, which is how it stayed out of TEARDOWN( )
*     for as long as it did.
      SELECT COUNT(*) FROM zrak_cj_layout  INTO @lv_l WHERE journey    = @ls_j-journey.
      WRITE: / ls_j-journey, 42 lv_s, 50 lv_f, 60 lv_o, 68 lv_r, 77 lv_l, 86 ls_j-tile.
    ENDLOOP.
    ULINE.
    WRITE: / |{ lines( it_j ) } journey(s) matched|.
  ENDMETHOD.


  METHOD dupes.
*   THE DIAGNOSIS THAT DECIDES WHETHER WIPING IS EVEN THE ANSWER. A field
*   appearing twice under the same journey and step is a loader that ran
*   without a teardown in front of it. Wiping clears today's mess; only
*   fixing the loader stops tomorrow's.
    DATA lv_any TYPE abap_bool.
    SKIP.
    WRITE: / 'DUPLICATE FIELDS (same journey, step and name more than once)'.
    ULINE.
    LOOP AT it_j INTO DATA(ls_j).
*     FIELD_NAME, not NAME. ZRAK_T_JNY_FLD and ZRAK_T_JNY_OPT both call the
*     column FIELD_NAME; the engine's own TY_FIELD calls it NAME, which is
*     what this was written from and why it did not compile.
      SELECT journey_id, step_id, field_name, COUNT(*) AS cnt
        FROM zrak_t_jny_fld
        WHERE journey_id = @ls_j-journey
        GROUP BY journey_id, step_id, field_name
        HAVING COUNT(*) > 1
        INTO TABLE @DATA(lt_d).
      LOOP AT lt_d INTO DATA(ls_d).
        lv_any = abap_true.
        WRITE: / ls_d-journey_id, 42 ls_d-step_id, 50 ls_d-field_name, 80 ls_d-cnt.
      ENDLOOP.
    ENDLOOP.
    IF lv_any = abap_false.
      WRITE: / 'None. The duplication is not inside these journeys - look for two',
             / 'JOURNEY_IDs covering the same screen instead.'.
    ENDIF.
  ENDMETHOD.


  METHOD orphans.
*   CHILD ROWS WITH NO HEADER. TEARDOWN( ) reads ZRAK_T_JNY first and gives up
*   with "not found" when the header is gone, so these survive every wipe,
*   never appear in the Studio, and are exactly what makes a reload look like
*   it duplicated something.
    DATA(lt_pat) = patterns( ).
    SKIP.
    WRITE: / 'ORPHANED FIELD ROWS (no ZRAK_T_JNY header)'.
    ULINE.
    DATA lv_tot TYPE i.
    LOOP AT lt_pat INTO DATA(lv_pat).
      SELECT DISTINCT f~journey_id
        FROM zrak_t_jny_fld AS f
        LEFT JOIN zrak_t_jny AS j ON j~journey_id = f~journey_id
        WHERE f~journey_id LIKE @lv_pat AND j~journey_id IS NULL
        INTO TABLE @DATA(lt_orph).
      LOOP AT lt_orph INTO DATA(lv_oj).
        lv_tot = lv_tot + 1.
        WRITE: / lv_oj, 42 'orphaned'.
        IF p_orph = abap_true AND p_test = abap_false.
          DELETE FROM zrak_t_jny_step WHERE journey_id = @lv_oj.
          DELETE FROM zrak_t_jny_fld  WHERE journey_id = @lv_oj.
          DELETE FROM zrak_t_jny_opt  WHERE journey_id = @lv_oj.
          DELETE FROM zrak_t_jny_rule WHERE journey_id = @lv_oj.
          DELETE FROM zrak_cj_layout  WHERE journey    = @lv_oj.
          DELETE FROM zrak_t_mig_raw  WHERE cjs_id     = @lv_oj.
          COMMIT WORK.
          zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV string( lv_oj ) ).
          WRITE: 55 'removed'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    IF lv_tot = 0.
      WRITE: / 'None.'.
    ELSEIF p_orph = abap_false.
      WRITE: / 'Tick "Also sweep orphans" to remove these. TEARDOWN( ) cannot.'.
    ENDIF.
  ENDMETHOD.


  METHOD wipe.
    DATA(lo_mig) = NEW zcl_rak_migrator( ).
    SKIP.
    WRITE: / 'TEARDOWN'.
    ULINE.
    LOOP AT it_j INTO DATA(ls_j).
      lo_mig->teardown( EXPORTING iv_cjs_id = CONV string( ls_j-journey )
                        IMPORTING ev_msg    = DATA(lv_msg) ).
      WRITE: / lv_msg.
    ENDLOOP.
    ULINE.
    WRITE: / |{ lines( it_j ) } journey(s) removed|.
    WRITE: / 'Portal tiles untouched - this report cannot remove them.'.
  ENDMETHOD.


  METHOD run.
    IF patterns( ) IS INITIAL.
      MESSAGE 'Enter at least one journey prefix, e.g. DOK_ and EPDA_' TYPE 'E'.
    ENDIF.

    DATA(lt_j) = collect( ).

    counts( lt_j ).
    dupes( lt_j ).
    orphans( ).

    IF p_test = abap_true.
      SKIP.
      ULINE.
      WRITE: / 'TEST RUN - nothing was deleted. Untick "Test run" to apply.'.
      RETURN.
    ENDIF.

    IF lt_j IS INITIAL.
      RETURN.
    ENDIF.

    wipe( lt_j ).
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  lcl_app=>run( ).
