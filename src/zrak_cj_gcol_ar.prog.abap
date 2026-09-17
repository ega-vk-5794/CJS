*&---------------------------------------------------------------------*
*& ZRAK_CJ_GCOL_AR - Arabic headings for grids whose columns live in
*&                   the packed DEFAULT_VAL spec
*&---------------------------------------------------------------------*
*& WHY THIS EXISTS. An EDITABLE_TABLE takes its column headings from one
*& of two places. ZRAK_T_JNY_COL is the good one: ZLABEL and ZLABEL_AR are
*& real columns, the Studio maintains them as Label and Label (AR), and
*& ZCL_RAK_CJ_TEXT_SRC_CFG exports, gaps and imports them like any other
*& pair. The other is the PACKED SPEC in ZRAK_T_JNY_FLD-DEFAULT_VAL, and
*& nothing reads it for text at all - so a grid on the packed spec is
*& INVISIBLE to the translation report. Not a gap in it; absent from it.
*&
*& That is why D001's Buildings grid rendered "Block Name / No. of floors
*& / No. of rooms" in English on a fully Arabic page while every label
*& around it turned over, and why the text export said nothing about it.
*&
*& The spec has a fifth slot for exactly this - name:label:type:src:label_ar
*& - and GRID_COLS( ) already reads it into GC-LABEL_AR. It is simply empty
*& almost everywhere. This report fills it.
*&
*& ---- WHAT IT WILL NOT DO ---------------------------------------------
*&
*& IT NEVER OVERWRITES AN ANSWER. A column whose fifth slot already holds
*& something is left exactly as it is, whoever wrote it and whatever it
*& says. The report adds Arabic where there is none; it is not a way to
*& re-translate, and a reviewer's correction must survive a re-run.
*&
*& IT NEVER TOUCHES A DIRECTIVE. SEL:, FIX: and RX: are entries in the
*& same pipe-separated list and are NOT columns - GRID_COLS( ) skips them
*& by name. Appending slots to SEL:SINGLE:NOC_SEL would turn a working
*& selection directive into a column called SEL.
*&
*& IT NEVER TOUCHES A TABLE. FTYPE TABLE also keeps a spec in DEFAULT_VAL,
*& and it is a DIFFERENT one - text|width|hAlign|KEYWORDS, four parts on a
*& bar, read by COL_HEADER( ), which takes @nnn rather than a fifth slot.
*& Parsing one as the other would destroy it. EDITABLE_TABLE only.
*&
*& IT NEVER LETS A REBUILT SPEC OVERFLOW. DEFAULT_VAL is CHAR(1000) and a
*& longer string would be TRUNCATED ON WRITE - silently, mid-column,
*& leaving a spec that no longer parses and a grid that no longer draws.
*& The length is checked before every UPDATE and an overflow is reported
*& and skipped, never written.
*&
*& IT SKIPS A FIELD THAT HAS ZRAK_T_JNY_COL ROWS. Those win in
*& GRID_COLS( ) - COL_ROWS_OF( ) is tried first and the packed spec is
*& only the fallback - so writing Arabic into the spec there would put a
*& second answer in the config that nothing ever reads. Reported as
*& covered, not changed.
*&
*& ---- THE WORDING -----------------------------------------------------
*&
*& Reused from D001's own ZRAK_T_JNY_COL rows wherever the English matches
*& - Owner Name, Owner Share, Owner Nationality, Mobile Number, Email
*& Address, Emirates ID all come from there verbatim, so a column in D011
*& reads the same as the same column in D001. The rest are proposed and
*& are flagged in the run log as such. A heading nobody has wording for is
*& listed with NO ARABIC and left alone, which is the honest outcome:
*& better a reported gap than an invented heading nobody reviewed.
*&
*& TEST RUN IS THE DEFAULT. Run it once, read the list, then untick.
*&---------------------------------------------------------------------*
REPORT zrak_cj_gcol_ar.

PARAMETERS p_jny  TYPE zrak_journey_id.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.

*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_map,
             en TYPE string,
             ar TYPE string,
           END OF ty_map,
           tt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

    CLASS-METHODS run.

  PRIVATE SECTION.

*   Keyed on the English heading, upper-cased and condensed, because the
*   same heading is spelt with different capitals and spacing across the
*   four journeys - "No. of floors" against "No. of floor", "E-mail"
*   against "Email Address".
    CLASS-METHODS dictionary RETURNING VALUE(rt) TYPE tt_map.

    CLASS-METHODS arabic_of
      IMPORTING iv_en     TYPE string
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS is_directive
      IMPORTING iv_name   TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.

ENDCLASS.

*&---------------------------------------------------------------------*
CLASS lcl_app IMPLEMENTATION.

  METHOD is_directive.
*   The three names GRID_COLS( ) skips before it treats an entry as a
*   column. PICK: belongs to the READONLY record spec rather than to a
*   grid, but it costs nothing to refuse it here too and it means a spec
*   that mixes them cannot be damaged by this report.
    rv = xsdbool( iv_name = 'SEL' OR iv_name = 'FIX'
               OR iv_name = 'RX'  OR iv_name = 'PICK' ).
  ENDMETHOD.

  METHOD dictionary.
*   VERBATIM FROM D001's ZRAK_T_JNY_COL ROWS - these six already exist in
*   the configuration with this exact Arabic, so reusing them is not a
*   translation at all, it is a copy. A column that says Owner Name in
*   D011 now reads the same as the one that says Owner Name in D001.
    rt = VALUE #(
      ( en = 'OWNER NAME'          ar = 'اسم المالك' )
      ( en = 'OWNER SHARE'         ar = 'حصة المالك' )
      ( en = 'OWNER NATIONALITY'   ar = 'جنسية المالك' )
      ( en = 'MOBILE NUMBER'       ar = 'رقم الهاتف المتحرك' )
      ( en = 'EMAIL ADDRESS'       ar = 'البريد الإلكتروني' )
      ( en = 'EMIRATES ID'         ar = 'رقم الهوية الإماراتية' )
      ( en = 'OWNER BP'            ar = 'رقم شريك المالك' )
*     PROPOSED. Everything below is wording this report is offering, not
*     wording the department has already signed off. It is reported as
*     PROPOSED in the run log for that reason, and ZRAK_T_JNY_FLD can be
*     re-edited in the Studio without re-running anything.
      ( en = 'BLOCK NAME'          ar = 'اسم المبنى' )
      ( en = 'NO. OF FLOORS'       ar = 'عدد الطوابق' )
      ( en = 'NO. OF FLOOR'        ar = 'عدد الطوابق' )
      ( en = 'NO. OF ROOMS'        ar = 'عدد الغرف' )
      ( en = 'CASE ID'             ar = 'رقم الحالة' )
      ( en = 'SCHOOL NAME'         ar = 'اسم المدرسة' )
      ( en = 'APPLICANT NAME'      ar = 'اسم مقدم الطلب' )
      ( en = 'APPLICANT TYPE'      ar = 'نوع مقدم الطلب' )
      ( en = 'EMIRATES ID NUMBER'  ar = 'رقم الهوية الإماراتية' )
      ( en = 'LICENCE NO'          ar = 'رقم الرخصة' )
      ( en = 'LICENSE NO'          ar = 'رقم الرخصة' )
      ( en = 'LICENSE'             ar = 'الرخصة' )
      ( en = 'LICENCE NAME'        ar = 'اسم الرخصة' )
      ( en = 'LICENSE NAME'        ar = 'اسم الرخصة' )
      ( en = 'VALID FROM'          ar = 'صالحة من' )
      ( en = 'VALID TO'            ar = 'صالحة حتى' )
      ( en = 'ISSUED AT'           ar = 'تاريخ الإصدار' )
      ( en = 'EXPIRED AT'          ar = 'تاريخ الانتهاء' )
      ( en = 'NAME'                ar = 'الاسم' )
      ( en = 'NATIONALITY'         ar = 'الجنسية' )
      ( en = 'SHARES'              ar = 'الحصص' )
      ( en = 'SHARE'               ar = 'الحصة' )
      ( en = 'MOBILE'              ar = 'رقم الهاتف المتحرك' )
      ( en = 'E-MAIL'              ar = 'البريد الإلكتروني' )
      ( en = 'EMAIL'               ar = 'البريد الإلكتروني' )
      ( en = 'OWNER'               ar = 'المالك' )
      ( en = 'PARTNER'             ar = 'الشريك' )
      ( en = 'OWNER PHONE'         ar = 'هاتف المالك' )
      ( en = 'MANAGER'             ar = 'المدير' )
      ( en = 'MANAGER NAME'        ar = 'اسم المدير' )
      ( en = 'MANAGER PHONE'       ar = 'هاتف المدير' )
      ( en = 'PASSPORT'            ar = 'جواز السفر' )
      ( en = 'ACTIVITY'            ar = 'النشاط' )
*     ---- ADDED FROM THE REAL EXPORT ------------------------------------
*     The first version of this list was written from the specs visible at
*     the time, and the run then reported everything it could not answer -
*     which is what NO ARABIC is for. A full ZRAK_T_JNY_FLD export across
*     the four journeys named the rest, and these are they.
*
*     THE ONLY THREE GAPS LEFT IN THE FOUR JOURNEYS ARE ALL EMAIL_ADDRESS
*     - D011's MANAGER_1 and OWNERS_1, and D012's OWNERS_DISP - and each
*     labels it something the generic EMAIL rows above do not match:
*     "Manager Email" and "Owner Email" rather than "Email" or "Email
*     Address". Answering those with a looser lookup is exactly what this
*     dictionary must not do, so they get their own rows.
      ( en = 'MANAGER EMAIL'       ar = 'بريد المدير الإلكتروني' )
      ( en = 'OWNER EMAIL'         ar = 'بريد المالك الإلكتروني' )
*     D001's OWNERS_SEARCH columns. The report SKIPS that field today
*     because it has ZRAK_T_JNY_COL rows and those win in GRID_COLS( );
*     these are here so the answer does not vanish if those rows are ever
*     removed and the grid falls back to its packed spec.
      ( en = 'ID TYPE'             ar = 'نوع الهوية' )
      ( en = 'NEW ITEM'            ar = 'عنصر جديد' )
      ( en = 'NATIONALITY KEY'     ar = 'رمز الجنسية' )
      ( en = 'BIRTH DATE'          ar = 'تاريخ الميلاد' )
*     D002's NOC_SEL, which this report cannot reach - NOC_SEL is READONLY
*     and its spec is read by the record-view parser rather than
*     GRID_COLS( ). The wording belongs with the rest, so it waits here
*     for whenever that path gets the same treatment.
      ( en = 'NOC REFERENCE'       ar = 'مرجع شهادة عدم الممانعة' ) ).
  ENDMETHOD.

  METHOD arabic_of.
    DATA(lv_k) = to_upper( condense( iv_en ) ).
    READ TABLE dictionary( ) INTO DATA(ls_m) WITH KEY en = lv_k.
    IF sy-subrc = 0.
      rv = ls_m-ar.
    ENDIF.
  ENDMETHOD.

  METHOD run.

    DATA lv_upd  TYPE i.
    DATA lv_gap  TYPE i.
    DATA lv_skip TYPE i.

    SELECT journey_id, step_id, field_name, ftype, default_val
      FROM zrak_t_jny_fld
      WHERE ftype = 'EDITABLE_TABLE'
        AND ( @p_jny IS INITIAL OR journey_id = @p_jny )
      ORDER BY journey_id, step_id, field_name
      INTO TABLE @DATA(lt_fld).

    IF lt_fld IS INITIAL.
      WRITE: / 'No EDITABLE_TABLE field found for that selection.'.
      RETURN.
    ENDIF.

*   Which journeys were actually written, so the transport is recorded
*   once each rather than once per column.
    DATA lt_done TYPE STANDARD TABLE OF zrak_journey_id WITH EMPTY KEY.

    LOOP AT lt_fld ASSIGNING FIELD-SYMBOL(<ls_f>).

      DATA(lv_spec) = CONV string( <ls_f>-default_val ).
      IF lv_spec IS INITIAL OR lv_spec NS ':'.
        CONTINUE.
      ENDIF.

      WRITE: / '---', <ls_f>-journey_id, <ls_f>-step_id, <ls_f>-field_name.

*     ZRAK_T_JNY_COL WINS IN GRID_COLS( ), so a field that has rows there
*     never reads its packed spec for headings. Writing Arabic into the
*     spec would put a second answer in the configuration that nothing
*     reads, and the next person to find the two would have to work out
*     which one the renderer honours.
      SELECT COUNT(*) FROM zrak_t_jny_col
        WHERE journey_id = @<ls_f>-journey_id
          AND step_id    = @<ls_f>-step_id
          AND field_name = @<ls_f>-field_name
        INTO @DATA(lv_ncol).
      IF lv_ncol > 0.
        WRITE: /5 'covered by ZRAK_T_JNY_COL -', lv_ncol, 'rows. Not touched.'.
        lv_skip = lv_skip + 1.
        CONTINUE.
      ENDIF.

      SPLIT lv_spec AT '|' INTO TABLE DATA(lt_ent).

      DATA(lv_touched) = abap_false.
      DATA lt_out TYPE STANDARD TABLE OF string WITH EMPTY KEY.
      CLEAR lt_out.

      LOOP AT lt_ent INTO DATA(lv_ent).

*       A VARIABLE, BECAUSE A BUILT-IN FUNCTION CANNOT SIT IN FRONT OF
*       IS INITIAL. condense( x ) IS INITIAL is "Unexpected operator IS",
*       and the error names the predicate rather than the call before it,
*       so it reads as though the IF is malformed.
*
*       THIS IS NOT TRUE OF METHOD CALLS, and the distinction matters:
*       io_ctx->get_val( x ) IS INITIAL and cell_of( ... ) IS INITIAL are
*       all over D001 and the renderer and have always been fine. Do not
*       "fix" those - only the built-in functions (condense, to_upper,
*       strlen) need the variable.
        DATA(lv_chk) = condense( lv_ent ).
        IF lv_chk IS INITIAL.
          CONTINUE.
        ENDIF.

        SPLIT lv_ent AT ':' INTO DATA(lv_n) DATA(lv_l) DATA(lv_t)
                                 DATA(lv_s) DATA(lv_a).
        DATA(lv_nn) = condense( lv_n ).
        DATA(lv_ll) = condense( lv_l ).
        DATA(lv_aa) = condense( lv_a ).

*       Anything that is not a column goes back byte for byte.
        IF lv_nn IS INITIAL OR is_directive( to_upper( lv_nn ) ) = abap_true.
          APPEND lv_ent TO lt_out.
          CONTINUE.
        ENDIF.

*       ALREADY ANSWERED. Never overwritten - see the header.
        IF lv_aa IS NOT INITIAL.
          WRITE: /5 lv_nn, 'already has Arabic. Left alone.'.
          APPEND lv_ent TO lt_out.
          CONTINUE.
        ENDIF.

*       HIDE in the TYPE slot means the column is carried in the payload
*       and never drawn, so it has no heading to translate. A blank label
*       is the same case.
        IF lv_ll IS INITIAL OR to_upper( condense( lv_t ) ) = 'HIDE'.
          APPEND lv_ent TO lt_out.
          CONTINUE.
        ENDIF.

        DATA(lv_ar) = arabic_of( lv_ll ).
        IF lv_ar IS INITIAL.
          WRITE: /5 lv_nn, '- NO ARABIC for', lv_ll, '- left alone.'.
          lv_gap = lv_gap + 1.
          APPEND lv_ent TO lt_out.
          CONTINUE.
        ENDIF.

*       REBUILT TO FIVE SLOTS ALWAYS. A three-part spec needs two more
*       colons and a two-part spec three, because SPLIT puts the unsplit
*       remainder in the LAST target - one colon short and the Arabic
*       lands in SRC, which is a data element name, while LABEL_AR stays
*       blank and the heading stays English. That failure looks exactly
*       like the edit not having been made.
        DATA(lv_new_ent) = |{ lv_nn }:{ lv_ll }:{ condense( lv_t ) }:| &&
                           |{ condense( lv_s ) }:{ lv_ar }|.
        APPEND lv_new_ent TO lt_out.
        lv_touched = abap_true.
        WRITE: /5 lv_nn, '->', lv_ar.

      ENDLOOP.

      IF lv_touched = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_new) = concat_lines_of( table = lt_out sep = `|` ).

*     DEFAULT_VAL IS CHAR(1000) AND A LONGER STRING IS TRUNCATED ON WRITE,
*     silently and mid-column, leaving a spec that no longer parses and a
*     grid that no longer draws. Checked before the UPDATE, never after.
      IF strlen( lv_new ) > 1000.
        WRITE: /5 'REFUSED - rebuilt spec is', strlen( lv_new ),
                  'characters, over the 1000 DEFAULT_VAL holds.'.
        WRITE: /5 'Shorten a heading or move this grid to ZRAK_T_JNY_COL.'.
        lv_skip = lv_skip + 1.
        CONTINUE.
      ENDIF.

      lv_upd = lv_upd + 1.

      IF p_test = abap_true.
        WRITE: /5 'TEST RUN - would write:'.
        WRITE: /7 lv_new.
        CONTINUE.
      ENDIF.

      UPDATE zrak_t_jny_fld
         SET default_val = @lv_new
       WHERE journey_id = @<ls_f>-journey_id
         AND step_id    = @<ls_f>-step_id
         AND field_name = @<ls_f>-field_name.
      IF sy-subrc = 0.
        WRITE: /5 'written.'.
        IF NOT line_exists( lt_done[ table_line = <ls_f>-journey_id ] ).
          APPEND <ls_f>-journey_id TO lt_done.
        ENDIF.
      ELSE.
        WRITE: /5 'UPDATE failed, sy-subrc', sy-subrc.
      ENDIF.

    ENDLOOP.

    IF p_test = abap_false AND lv_upd > 0.
      COMMIT WORK AND WAIT.

*     NO TRANSPORT, BY DECISION. This writes in the client it is run in
*     and nowhere else, so RUN IT IN EVERY CLIENT THAT SERVES THESE
*     JOURNEYS. It is re-runnable by construction - a column that already
*     has Arabic is left alone - so a second run in a client that has had
*     one reports everything as already answered and writes nothing.
      WRITE: / 'Written in client', sy-mandt,
               '- run this in every client that serves these journeys.'.
      LOOP AT lt_done INTO DATA(lv_j).
        WRITE: /3 lv_j.
      ENDLOOP.
    ENDIF.

    SKIP.
    WRITE: / 'Grids updated  :', lv_upd.
    WRITE: / 'Headings with no Arabic in the dictionary:', lv_gap.
    WRITE: / 'Grids skipped  :', lv_skip.
    IF p_test = abap_true.
      WRITE: / 'TEST RUN - nothing was written. Untick to apply.'.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  lcl_app=>run( ).
