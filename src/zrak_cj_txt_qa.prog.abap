REPORT zrak_cj_txt_qa.

TABLES sscrfields.

SELECT-OPTIONS s_jrn FOR sy-lisel NO INTERVALS.

PARAMETERS p_detl RADIOBUTTON GROUP g1 DEFAULT 'X'.
PARAMETERS p_summ RADIOBUTTON GROUP g1.
PARAMETERS p_expt RADIOBUTTON GROUP g1.
*   THE FOURTH MODE, AND THE ONE THAT WAS MISSING. ZCL_RAK_CJ_TXT_IO has
*   had IMPORT( ) for as long as it has had EXPORT( ) and nothing ever
*   called it, so the round trip stopped half way: a journey's texts could
*   be exported for a translator and there was no way to put the Arabic
*   back except field by field in the Studio.
PARAMETERS p_impt RADIOBUTTON GROUP g1.
*   THE FIFTH MODE. Every label, section heading, message, placeholder and
*   option text on a MIGRATED screen already exists in both languages in
*   the legacy text tables - that is the standing rule, "migrated wording
*   is READ, never written, and never hand-translated". A journey missing
*   its Arabic does not need a translator; it needs the row the department
*   already owns.
*
*   So this mode does not translate anything. It looks the Arabic up and
*   fills it in, for every selected journey at once.
PARAMETERS p_fill RADIOBUTTON GROUP g1.

PARAMETERS p_path TYPE string LOWER CASE DEFAULT 'C:\temp\cjs_texts.xls'.

*   TEST RUN IS THE DEFAULT, and it is the same discipline as
*   ZRAK_CJ_ATT_PURGE: an import rewrites the wording of every journey in
*   the file, and a mistyped path or a spreadsheet saved in the wrong
*   format should show a log rather than change anything. IMPORT( ) itself
*   already takes IV_COMMIT and defaults it false - it builds the full log
*   either way and only writes at the end - so the test run reports exactly
*   what the real one would do.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.

*   BACKFILL ONLY, AND OFF BY DEFAULT. Assemble a caption the legacy
*   tables do not hold from the parts they do: "Grade 2 - Uniform Fee" is
*   not a row anywhere, but "Grade 2" and "Uniform Fee" both are.
*
*   It is the one thing in this report that PRODUCES Arabic rather than
*   reading it. Composing two of the department's own rows is not a hand
*   translation, but it is not a lookup either - so it stays a deliberate
*   tick, and every row it fills is logged as COMPOSED rather than CHANGE
*   so a reviewer can see exactly what was assembled.
PARAMETERS p_comp AS CHECKBOX DEFAULT ' '.


CLASS lcl_app DEFINITION FINAL.

  PUBLIC SECTION.

    CLASS-METHODS run.

  PRIVATE SECTION.

    CLASS-METHODS journeys
      RETURNING VALUE(rt_journey) TYPE zif_rak_cj_text_src=>ty_t_journey.

    CLASS-METHODS show_detail
      IMPORTING it_find TYPE zcl_rak_cj_txt_qa=>ty_t_find.

    CLASS-METHODS show_summary
      IMPORTING it_stat TYPE zcl_rak_cj_txt_qa=>ty_t_stat.

    CLASS-METHODS do_export
      IMPORTING it_journey TYPE zif_rak_cj_text_src=>ty_t_journey.

    CLASS-METHODS do_import.

    TYPES: BEGIN OF ty_pair,
             en  TYPE string,
             ar  TYPE string,
             amb TYPE abap_bool,
           END OF ty_pair.
    TYPES ty_t_pair TYPE HASHED TABLE OF ty_pair WITH UNIQUE KEY en.

*   FOUR MAPS, NOT TWO: an EXACT one and a NORMALISED one per table.
*
*   Normalising alone was wrong, and the legacy data says so plainly:
*
*     DOKSL_ND001_1_3_CYCLE_1   "Cycle 1"   الدورة الأولى
*     DOKSL_ND001_2_4_CYCLE_1   "CYCLE 1"   المرحلة الأولى
*
*   Two rows, different Arabic, distinguished ONLY by case. Exactly they
*   are two keys and each matches its own journey correctly - which is
*   what the first run did. Upper-cased they collide, disagree, and both
*   become AMBIG: a working fill turned into manual work.
*
*   So exact wins and normalised is the fallback. A journey whose English
*   matches a legacy row character for character takes that row's Arabic;
*   only a text that matches nothing exactly falls through to the loose
*   key, which is where "Teacher Flag" and "Documents:" are recovered.
*   THE FOUR MAPS AS STATE, not as four exporting parameters threaded
*   through every caller. LOOKUP( ) needs all four and COMPOSE( ) needs
*   LOOKUP( ), and passing them down two levels was four parameters that
*   could be passed in the wrong order.
    CLASS-DATA gt_lbl     TYPE ty_t_pair.
    CLASS-DATA gt_val     TYPE ty_t_pair.
    CLASS-DATA gt_lbl_nrm TYPE ty_t_pair.
    CLASS-DATA gt_val_nrm TYPE ty_t_pair.

    CLASS-METHODS legacy_pairs.

*   ONE ENGLISH TEXT, LOOKED FOR EVERYWHERE IT COULD BE.
*
*   Four attempts in order: the kind's own table exactly, the OTHER table
*   exactly, then the same two normalised. IV_OPT only decides which table
*   is tried FIRST - it no longer decides which table is tried at all.
*
*   That split was wrong and the /QNV/SB_VALUET dump is what showed it:
*   "Books Fee", "Uniform Fee" and "School Fee" are all VALUET rows, and
*   every one of them is a LABEL on the CJS side. Searching LABELT alone
*   for a label meant they could never be found, however the key was
*   normalised.
    CLASS-METHODS lookup
      IMPORTING iv_en        TYPE string
                iv_opt       TYPE abap_bool
      RETURNING VALUE(rs_p)  TYPE ty_pair.

*   A COMPOSED CAPTION, ASSEMBLED FROM PARTS THAT ARE THEMSELVES REAL ROWS.
*
*   "Grade 2 - Uniform Fee" was never a legacy row and never will be: the
*   legacy screen drew a fee TABLE, with the grades down the side and the
*   fee kinds across the top, and the migration flattened it into one
*   caption per cell. Both halves exist though - "Grade 2" in SB_LABELT,
*   "Uniform Fee" in SB_VALUET - so the Arabic can be assembled from the
*   department's own words rather than invented.
*
*   OFF BY DEFAULT AND LOGGED APART. This is the one thing in this report
*   that PRODUCES Arabic rather than reading it, and the standing rule is
*   that migrated wording is read and never hand-translated. Composing two
*   real rows is not a hand translation, but it is not a lookup either -
*   so it needs a human to turn it on and a separate action code in the
*   log to review. Every part must resolve; one miss and the whole caption
*   is left as NOTFOUND rather than half-filled.
    CLASS-METHODS compose
      IMPORTING iv_en       TYPE string
                iv_opt      TYPE abap_bool
      RETURNING VALUE(rv_ar) TYPE string.

*   THE MATCH KEY, applied to BOTH sides so they cannot drift.
*
*   An exact, case-sensitive compare left most of the first run's misses
*   on the table for no good reason: a legacy caption written "Teacher
*   Flag" or "Documents:" is the same text as the journey's "Teacher flag"
*   and "Documents", and refusing to fill the Arabic over a colon helps
*   nobody. Upper-cased, condensed, and stripped of the trailing
*   punctuation a caption carries and a value never does.
*
*   IT CAN ONLY CREATE AMBIGUITY, NEVER A WRONG ANSWER - which is what
*   makes loosening it safe. Two legacy rows that normalise together and
*   disagree in Arabic are marked AMBIG and skipped exactly as before, so
*   the worst case is a row that used to be NOTFOUND becoming one a human
*   is asked about.
    CLASS-METHODS norm
      IMPORTING iv_txt        TYPE clike
      RETURNING VALUE(rv_key) TYPE string.

*   Insert a pair, or mark the key ambiguous when a second row disagrees.
*   One method because the same three lines were being written four times
*   - twice per table, once per map - which is how two of them end up
*   deciding ambiguity differently.
    CLASS-METHODS add_pair
      IMPORTING iv_en   TYPE string
                iv_ar   TYPE string
      CHANGING  ct_pair TYPE ty_t_pair.

    CLASS-METHODS do_backfill
      IMPORTING it_journey TYPE zif_rak_cj_text_src=>ty_t_journey.

    CLASS-METHODS show_import
      IMPORTING it_log TYPE zcl_rak_cj_txt_io=>ty_t_imp_log.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD journeys.
    LOOP AT s_jrn ASSIGNING FIELD-SYMBOL(<ls_r>) WHERE sign = 'I' AND option = 'EQ'.
      APPEND CONV zif_rak_cj_text_src=>ty_key( <ls_r>-low ) TO rt_journey.
    ENDLOOP.
  ENDMETHOD.


  METHOD show_detail.

    IF it_find IS INITIAL.
      MESSAGE 'Scan completed with no findings across the selected journeys.' TYPE 'S'.
      RETURN.
    ENDIF.

    DATA lt TYPE zcl_rak_cj_txt_qa=>ty_t_find.
    lt = it_find.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).
        lo_alv->get_display_settings( )->set_list_header( |CJS text findings: { lines( lt ) }| ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD show_summary.

    DATA lt TYPE zcl_rak_cj_txt_qa=>ty_t_stat.
    lt = it_stat.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).
        lo_alv->get_display_settings( )->set_list_header( |CJS translation coverage| ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD do_export.

    DATA lt_bin  TYPE solix_tab.
    DATA lv_len  TYPE i.

    DATA(lo_io)   = NEW zcl_rak_cj_txt_io( ).
    DATA(lv_xstr) = lo_io->export( it_journey ).

    lv_len = xstrlen( lv_xstr ).
    lt_bin = cl_bcs_convert=>xstring_to_solix( lv_xstr ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING bin_filesize = lv_len
                filename     = p_path
                filetype     = 'BIN'
      CHANGING  data_tab     = lt_bin
      EXCEPTIONS OTHERS      = 1 ).

    IF sy-subrc = 0.
      MESSAGE |Exported to { p_path }| TYPE 'S'.
    ELSE.
      MESSAGE 'Download failed' TYPE 'E'.
    ENDIF.

  ENDMETHOD.


  METHOD norm.
    rv_key = to_upper( condense( CONV string( iv_txt ) ) ).
*   Trailing caption punctuation only, and one pass is enough: a caption
*   carries at most a colon, an asterisk for required, or both.
    WHILE strlen( rv_key ) > 0
      AND ( substring( val = rv_key off = strlen( rv_key ) - 1 ) = ':'
         OR substring( val = rv_key off = strlen( rv_key ) - 1 ) = '*'
         OR substring( val = rv_key off = strlen( rv_key ) - 1 ) = ' ' ).
      rv_key = substring( val = rv_key len = strlen( rv_key ) - 1 ).
    ENDWHILE.
    rv_key = condense( rv_key ).
  ENDMETHOD.


  METHOD add_pair.
    IF iv_en IS INITIAL OR iv_ar IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE ct_pair ASSIGNING FIELD-SYMBOL(<p>) WITH TABLE KEY en = iv_en.
    IF sy-subrc = 0.
*     A SECOND ROW THAT AGREES IS NOT AMBIGUITY. Most duplicates are the
*     same caption on two screens with the same Arabic, and marking those
*     would refuse work for no reason.
      IF <p>-ar <> iv_ar.
        <p>-amb = abap_true.
      ENDIF.
    ELSE.
      INSERT VALUE #( en = iv_en ar = iv_ar ) INTO TABLE ct_pair.
    ENDIF.
  ENDMETHOD.


  METHOD lookup.
    CLEAR rs_p.
    DATA(lv_exact) = condense( iv_en ).
    DATA(lv_key)   = norm( iv_en ).

*   EXACT BEFORE NORMALISED, ALWAYS - "Cycle 1" and "CYCLE 1" carry
*   different Arabic and only the exact compare tells them apart. The
*   kind's own table is tried first at each level, so an OPTION still
*   prefers SB_VALUET and a label still prefers SB_LABELT; the other
*   table is a fallback rather than a competitor.
    IF iv_opt = abap_true.
      READ TABLE gt_val     INTO rs_p WITH TABLE KEY en = lv_exact.
      IF sy-subrc <> 0. READ TABLE gt_lbl     INTO rs_p WITH TABLE KEY en = lv_exact. ENDIF.
      IF sy-subrc <> 0. READ TABLE gt_val_nrm INTO rs_p WITH TABLE KEY en = lv_key.   ENDIF.
      IF sy-subrc <> 0. READ TABLE gt_lbl_nrm INTO rs_p WITH TABLE KEY en = lv_key.   ENDIF.
    ELSE.
      READ TABLE gt_lbl     INTO rs_p WITH TABLE KEY en = lv_exact.
      IF sy-subrc <> 0. READ TABLE gt_val     INTO rs_p WITH TABLE KEY en = lv_exact. ENDIF.
      IF sy-subrc <> 0. READ TABLE gt_lbl_nrm INTO rs_p WITH TABLE KEY en = lv_key.   ENDIF.
      IF sy-subrc <> 0. READ TABLE gt_val_nrm INTO rs_p WITH TABLE KEY en = lv_key.   ENDIF.
    ENDIF.

    IF sy-subrc <> 0.
      CLEAR rs_p.
    ENDIF.
  ENDMETHOD.


  METHOD compose.
    CLEAR rv_ar.

*   ONLY A HYPHEN-SEPARATED CAPTION. " - " with spaces, not a bare
*   hyphen: "Pre-KG" and "Non Teaching" must not be torn in half, and a
*   spaced hyphen is what the migration used to join the two parts.
    IF iv_en NS ' - '.
      RETURN.
    ENDIF.

    SPLIT iv_en AT ' - ' INTO TABLE DATA(lt_part).
    IF lines( lt_part ) < 2.
      RETURN.
    ENDIF.

    DATA lv_out TYPE string.
    LOOP AT lt_part INTO DATA(lv_part).
      DATA(ls_part) = lookup( iv_en = condense( lv_part ) iv_opt = iv_opt ).
*     ALL OR NOTHING. A caption half in Arabic and half in English is
*     worse than one still in English: it reads as a bug to the citizen
*     and it hides from this report, because the row stops being blank.
      IF ls_part-ar IS INITIAL OR ls_part-amb = abap_true.
        CLEAR rv_ar.
        RETURN.
      ENDIF.
      lv_out = COND #( WHEN lv_out IS INITIAL THEN ls_part-ar ELSE |{ lv_out } - { ls_part-ar }| ).
    ENDLOOP.

    rv_ar = lv_out.
  ENDMETHOD.


  METHOD legacy_pairs.

*   ENGLISH IS THE JOIN KEY, and it is a sound one rather than a
*   convenience. The migrator copied these texts OUT of these same tables
*   into ZRAK_T_JNY*, verbatim - LOAD_TEXT_CACHES( ) reads exactly the two
*   selects below - so the English sitting on a migrated field IS a
*   /QNV/ labeltext, character for character. Nothing else links the two:
*   the migrator keeps the resolved text and not the LABEL_CODE it came
*   from, so there is no id to join on.
*
*   AMBIGUITY IS RECORDED, NOT RESOLVED. Two label codes can share an
*   English text and carry DIFFERENT Arabic - "Name" is the obvious one.
*   Where that happens the pair is marked and the backfill skips it and
*   says so, because picking one at random would put the wrong Arabic on
*   a citizen's form and nothing downstream would ever flag it. Where the
*   duplicates agree, which is most of them, it is not ambiguous at all.
    CLEAR: gt_lbl, gt_val, gt_lbl_nrm, gt_val_nrm.

    SELECT spras, label_code, labeltext FROM /qnv/sb_labelt
      INTO TABLE @DATA(lt_l).                             "#EC CI_NOWHERE
    SELECT spras, value_code, value_desc FROM /qnv/sb_valuet
      INTO TABLE @DATA(lt_v).                             "#EC CI_NOWHERE

    DATA lv_en TYPE string.
    DATA lv_ar TYPE string.

    LOOP AT lt_l INTO DATA(ls_l) WHERE spras = 'E'.
      lv_en = condense( CONV string( ls_l-labeltext ) ).
      CHECK lv_en IS NOT INITIAL.
      READ TABLE lt_l INTO DATA(ls_la) WITH KEY spras = 'A' label_code = ls_l-label_code.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      lv_ar = condense( CONV string( ls_la-labeltext ) ).
      CHECK lv_ar IS NOT INITIAL.

      add_pair( EXPORTING iv_en = lv_en         iv_ar = lv_ar CHANGING ct_pair = gt_lbl ).
      add_pair( EXPORTING iv_en = norm( lv_en ) iv_ar = lv_ar CHANGING ct_pair = gt_lbl_nrm ).
    ENDLOOP.

    LOOP AT lt_v INTO DATA(ls_v) WHERE spras = 'E'.
      lv_en = condense( CONV string( ls_v-value_desc ) ).
      CHECK lv_en IS NOT INITIAL.
      READ TABLE lt_v INTO DATA(ls_va) WITH KEY spras = 'A' value_code = ls_v-value_code.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      lv_ar = condense( CONV string( ls_va-value_desc ) ).
      CHECK lv_ar IS NOT INITIAL.

      add_pair( EXPORTING iv_en = lv_en         iv_ar = lv_ar CHANGING ct_pair = gt_val ).
      add_pair( EXPORTING iv_en = norm( lv_en ) iv_ar = lv_ar CHANGING ct_pair = gt_val_nrm ).
    ENDLOOP.

  ENDMETHOD.


  METHOD do_backfill.

    legacy_pairs( ).

    IF gt_lbl IS INITIAL AND gt_val IS INITIAL.
      MESSAGE '/QNV/SB_LABELT and /QNV/SB_VALUET returned no EN/AR pairs in this client' TYPE 'E'.
    ENDIF.

    DATA(lo_src) = NEW zcl_rak_cj_text_src_cfg( ).
    DATA lt_log   TYPE zcl_rak_cj_txt_io=>ty_t_imp_log.
    DATA lt_write TYPE zif_rak_cj_text_src=>ty_t_txt.

    DATA lt_txt TYPE zif_rak_cj_text_src=>ty_t_txt.

    LOOP AT it_journey INTO DATA(lv_j).
*     Into a variable first: LOOP AT does not take a method call as its
*     source.
      lt_txt = lo_src->zif_rak_cj_text_src~read_journey( lv_j ).
      LOOP AT lt_txt INTO DATA(ls_t).

*       ONLY A GAP IS FILLED. An Arabic text already on the journey is
*       left alone whatever the legacy table says - somebody may have
*       corrected it since, and overwriting a correction with the row it
*       was correcting is the one way this could destroy work.
        IF ls_t-text_ar IS NOT INITIAL OR ls_t-text_en IS INITIAL.
          CONTINUE.
        ENDIF.

*       OPTION texts come from the VALUE table, everything else from the
*       LABEL table - the same split LOAD_TEXT_CACHES( ) makes.
        DATA(lv_opt) = xsdbool( ls_t-txt_kind = zcl_rak_cj_text_src_cfg=>c_kind-option ).
        DATA(ls_p)   = lookup( iv_en = ls_t-text_en iv_opt = lv_opt ).
        DATA lv_act TYPE c LENGTH 10.
        lv_act = 'CHANGE'.

        IF ls_p-amb = abap_true.
          APPEND VALUE #( journey = ls_t-journey elem_id = ls_t-elem_id
                          action  = 'AMBIG'      new_en  = ls_t-text_en
                          message = |This English has more than one Arabic in the legacy table - fill it by hand| ) TO lt_log.
          CONTINUE.
        ENDIF.

*       COMPOSITION IS THE LAST RESORT AND ONLY WHEN ASKED FOR. A whole
*       caption that exists as a legacy row always wins over one assembled
*       from halves - the department's own wording for the whole thing is
*       better than our joining of its parts, and it is only reached when
*       nothing matched at all.
        IF ls_p-ar IS INITIAL AND p_comp = abap_true.
          ls_p-ar = compose( iv_en = ls_t-text_en iv_opt = lv_opt ).
          IF ls_p-ar IS NOT INITIAL.
            lv_act = 'COMPOSED'.
          ENDIF.
        ENDIF.

        IF ls_p-ar IS INITIAL.
          APPEND VALUE #( journey = ls_t-journey elem_id = ls_t-elem_id
                          action  = 'NOTFOUND'   new_en  = ls_t-text_en
                          message = |No row in either legacy text table with this English| ) TO lt_log.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( journey = ls_t-journey elem_id = ls_t-elem_id
                        action  = lv_act       new_en  = ls_t-text_en
                        new_ar  = ls_p-ar
                        message = COND #( WHEN lv_act = 'COMPOSED'
                                          THEN |Assembled from the legacy Arabic of each part - review before committing| ) ) TO lt_log.

        ls_t-text_ar = ls_p-ar.
        APPEND ls_t TO lt_write.

      ENDLOOP.
    ENDLOOP.

    IF lt_log IS INITIAL.
      MESSAGE 'Nothing missing - every selected journey already has its Arabic' TYPE 'S'.
      RETURN.
    ENDIF.

*   THE WRITE GOES THROUGH THE SAME SOURCE THE IMPORT USES, so a backfilled
*   text and a translated one land the same way and there is one writer
*   rather than two.
    IF p_test = abap_false AND lt_write IS NOT INITIAL.
      lo_src->zif_rak_cj_text_src~write( lt_write ).
    ENDIF.

    show_import( lt_log ).

  ENDMETHOD.


  METHOD do_import.

    DATA lt_bin TYPE solix_tab.
    DATA lv_len TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING filename   = p_path
                filetype   = 'BIN'
      IMPORTING filelength = lv_len
      CHANGING  data_tab   = lt_bin
      EXCEPTIONS OTHERS    = 1 ).

    IF sy-subrc <> 0.
      MESSAGE |Could not read { p_path }| TYPE 'E'.
    ENDIF.

    DATA(lv_xstr) = cl_bcs_convert=>solix_to_xstring( it_solix = lt_bin iv_size = lv_len ).

*   NO JOURNEY FILTER ON AN IMPORT, deliberately. The file names its own
*   journeys in column 1 and IMPORT( ) rejects any key the system does not
*   have, so the selection screen's journey list would be a second filter
*   that can only disagree with the file. Export a subset, translate it,
*   import it back - the subset is decided once, at export.
    DATA(lo_io)  = NEW zcl_rak_cj_txt_io( ).
    DATA(lt_log) = lo_io->import( iv_xstr   = lv_xstr
                                  iv_commit = xsdbool( p_test = abap_false ) ).

    IF lt_log IS INITIAL.
      MESSAGE 'Nothing to change - every text in the file already matches the system' TYPE 'S'.
      RETURN.
    ENDIF.

    show_import( lt_log ).

  ENDMETHOD.


  METHOD show_import.

    DATA(lt_log) = it_log.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt_log ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).

*       THE TITLE CARRIES THE MODE, because the two runs otherwise produce
*       an identical-looking list and the only difference is whether the
*       database moved. Counting CHANGE rows rather than all rows: SKIP and
*       REJECT lines are reported and written nowhere.
        DATA(lv_chg) = REDUCE i( INIT n = 0 FOR ls IN it_log
                                 NEXT n = COND #( WHEN ls-action = 'CHANGE' THEN n + 1 ELSE n ) ).
*       THE OTHER TWO OUTCOMES BELONG IN THE TITLE TOO. A run that fills
*       230 and leaves 400 unmatched is a different result from one that
*       fills 230 and leaves none, and the first list scrolls too far to
*       see which you got. NOTFOUND wants a translator; AMBIG wants a
*       person to choose - so they are counted apart rather than lumped.
        DATA(lv_nf)  = REDUCE i( INIT n = 0 FOR l2 IN it_log
                                 NEXT n = COND #( WHEN l2-action = 'NOTFOUND' THEN n + 1 ELSE n ) ).
        DATA(lv_amb) = REDUCE i( INIT n = 0 FOR l3 IN it_log
                                 NEXT n = COND #( WHEN l3-action = 'AMBIG' THEN n + 1 ELSE n ) ).
*       COMPOSED IS COUNTED APART FROM CHANGE, because it is the only
*       figure in this line that somebody has to look at rather than
*       accept. A run of 300 CHANGE is a lookup; 300 COMPOSED is 300
*       captions this report assembled.
        DATA(lv_cmp) = REDUCE i( INIT n = 0 FOR l4 IN it_log
                                 NEXT n = COND #( WHEN l4-action = 'COMPOSED' THEN n + 1 ELSE n ) ).
        DATA(lv_rest) = COND string(
          WHEN lv_nf > 0 OR lv_amb > 0 OR lv_cmp > 0
          THEN | · { lv_cmp } composed from parts · { lv_nf } not in the legacy tables, { lv_amb } ambiguous| ).

        lo_alv->get_display_settings( )->set_list_header(
          COND #( WHEN p_test = abap_true
                  THEN |TEST RUN - { lv_chg } text(s) WOULD change. Nothing written.{ lv_rest }|
                  ELSE |{ lv_chg } text(s) written.{ lv_rest }| ) ).

        lo_alv->display( ).
      CATCH cx_salv_msg.
        MESSAGE 'ALV could not be displayed' TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD run.

*   IMPORT FIRST, BEFORE THE JOURNEY LIST IS RESOLVED. The file names its
*   own journeys, so an import needs neither the selection screen's list
*   nor the "text source returned no journeys" guard below - which would
*   otherwise refuse the one mode that can put translations INTO a system
*   that has none.
    IF p_impt = abap_true.
      do_import( ).
      RETURN.
    ENDIF.

    DATA(lt_journey) = journeys( ).
    DATA(lo_qa)      = NEW zcl_rak_cj_txt_qa( ).

    IF lt_journey IS INITIAL.
      lt_journey = lo_qa->available_journeys( ).
      IF lt_journey IS INITIAL.
        MESSAGE 'Text source returned no journeys. Check c_tab and the field constants in ZCL_RAK_CJ_TEXT_SRC_STD.' TYPE 'E'.
      ENDIF.
    ENDIF.

    CASE abap_true.
      WHEN p_expt.
        IF lt_journey IS INITIAL.
          MESSAGE 'Select at least one journey to export' TYPE 'E'.
        ENDIF.
        do_export( lt_journey ).
      WHEN p_fill.
        do_backfill( lt_journey ).
      WHEN p_summ.
        show_summary( lo_qa->summarise( lt_journey ) ).
      WHEN OTHERS.
        show_detail( lo_qa->scan( lt_journey ) ).
    ENDCASE.

  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  lcl_app=>run( ).
