REPORT zrak_cj_fixpack.

*&---------------------------------------------------------------------*
*& CJS CORRECTION PACK - EPDA / DOK correction ticket, 03 Aug 26
*& CJSMIG-682 .. CJSMIG-697
*&
*& The ticket batch left 43 configuration points. This report applies the
*& ones that can be applied MECHANICALLY - a rename, a flag, a step turned
*& off, a column appended - and prints the rest as a worklist for the
*& Studio. It is deliberately not a migrator and not a feeder.
*&
*& WHAT IT WILL NOT DO, AND WHY
*&
*& It never INSERTs a field row. Adding a field is a decision about
*& TECH_NAME, FTYPE, layout and backend mapping, and a row invented here
*& would drift from ZCL_RAK_MIGRATOR's mapping - which is the rule this
*& repository already carries. Layout is the same: ROW_NO / COL_START /
*& COL_SPAN in ZRAK_CJ_LAYOUT is a design, not a correction, and belongs
*& in the Studio's Design tab where an author can see it.
*&
*& So of the 43 points, this covers 19. The other 24 print at the end with
*& their ticket number. That split is the honest one, not a shortfall to
*& be worked around by guessing.
*&
*& HOW IT ADDRESSES ROWS, AND WHY IT DOES NOT USE STEP IDS
*&
*& Nothing here hard-codes a STEP_ID, because a step id is not visible
*& from outside SAP and a wrong one silently matches nothing. Steps are
*& found by their CURRENT TITLE - the words the tester quoted on the
*& ticket - and a field's step is found by an ANCHOR field known to live
*& on it (the chemical step is "the step that has CHEMICALS_DETAILS on
*& it"). If the title has since been edited, the change reports NOT FOUND
*& against the exact key it looked for, which is the answer, rather than
*& doing nothing quietly.
*&
*& EVERY CHANGE IS READ-COMPARE-WRITE, so the report is idempotent: a
*& second run reports ALREADY for everything it did on the first. That is
*& what makes it safe to re-run after fixing one name in the table below.
*&
*& THE WRITE IS A FULL MODIFY OF A ROW THAT WAS SELECTED FIRST. Never a
*& targeted UPDATE SET built from a literal - the row is read, one field
*& is changed on the structure, and the structure goes back. Anything else
*& risks blanking the columns it did not name.
*&
*& TEST RUN IS THE DEFAULT. A report that edits live journey config should
*& never do it because somebody pressed F8 to see what it did.
*&---------------------------------------------------------------------*

* SELECT-OPTIONS needs a real data object to type itself against - a
* parenthesised name is a dynamic READ, not a declaration, and does not
* compile here.
DATA gv_jrny TYPE zrak_journey_id.

PARAMETERS     p_test TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECT-OPTIONS s_jrny FOR gv_jrny.
PARAMETERS     p_todo TYPE abap_bool AS CHECKBOX DEFAULT 'X'.

*&---------------------------------------------------------------------*
CLASS lcl_fix DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS run.

  PRIVATE SECTION.

*   KIND decides which applier runs. One row of TT_CHG is one ticket point.
*
*   LABEL        set ZLABEL / ZLABEL_AR on a field
*   HIDE         set HIDDEN on a field, on the step carrying ANCHOR
*   ATTACH_TYPE  set ATTACH_TYPES on EVERY upload field of the journey
*   STEP_TITLE   rename the step whose TITLE is OLDV
*   STEP_OFF     set ACTIVE = blank on the step whose TITLE contains OLDV
*   GRIDCOL      append a column to a grid field's pipe-separated spec.
*                NEWV is the column KEY and NEWAR carries its LABEL - the
*                two text slots are reused rather than adding a pair only
*                one kind would ever fill.
    TYPES: BEGIN OF ty_chg,
             ticket TYPE string,
             jrny   TYPE zrak_journey_id,
             kind   TYPE string,
             fld    TYPE zrak_journey_field,
             anchor TYPE zrak_journey_field,
             oldv   TYPE string,
             newv   TYPE string,
             newar  TYPE string,
           END OF ty_chg,
           tt_chg TYPE STANDARD TABLE OF ty_chg WITH EMPTY KEY.

*   A point the Studio has to do by hand, printed at the end.
    TYPES: BEGIN OF ty_todo,
             ticket TYPE string,
             jrny   TYPE string,
             what   TYPE string,
           END OF ty_todo,
           tt_todo TYPE STANDARD TABLE OF ty_todo WITH EMPTY KEY.

    CLASS-DATA gv_ok   TYPE i.
    CLASS-DATA gv_same TYPE i.
    CLASS-DATA gv_miss TYPE i.

    CLASS-METHODS changes  RETURNING VALUE(rt) TYPE tt_chg.
    CLASS-METHODS worklist RETURNING VALUE(rt) TYPE tt_todo.

    CLASS-METHODS do_label      IMPORTING is_c TYPE ty_chg.
    CLASS-METHODS do_hide       IMPORTING is_c TYPE ty_chg.
    CLASS-METHODS do_attach     IMPORTING is_c TYPE ty_chg.
    CLASS-METHODS do_step_title IMPORTING is_c TYPE ty_chg.
    CLASS-METHODS do_step_off   IMPORTING is_c TYPE ty_chg.
    CLASS-METHODS do_gridcol    IMPORTING is_c TYPE ty_chg.

*   The step that carries IV_ANCHOR. Blank when the anchor is not on the
*   journey at all, which is itself the finding.
    CLASS-METHODS step_of  IMPORTING iv_jrny       TYPE zrak_journey_id
                                     iv_anchor     TYPE zrak_journey_field
                           RETURNING VALUE(rv)     TYPE zrak_journey_step.

    CLASS-METHODS say      IMPORTING iv_state TYPE string
                                     is_c     TYPE ty_chg
                                     iv_detail TYPE string.
ENDCLASS.

CLASS lcl_fix IMPLEMENTATION.

  METHOD run.
    DATA(lt_chg) = changes( ).

    WRITE: / 'CJS correction pack - EPDA / DOK ticket 03 Aug 26'.
    IF p_test = abap_true.
      WRITE: / 'TEST RUN - nothing is written. Untick Test run to apply.'
               COLOR col_total.
    ELSE.
      WRITE: / 'APPLYING CHANGES' COLOR col_negative.
    ENDIF.
    SKIP.

    LOOP AT lt_chg INTO DATA(ls_c).

*     The select-option is a filter, not a key - an empty one means every
*     journey in the pack, which is the normal run.
      IF s_jrny[] IS NOT INITIAL AND ls_c-jrny NOT IN s_jrny.
        CONTINUE.
      ENDIF.

      CASE ls_c-kind.
        WHEN 'LABEL'.       do_label( ls_c ).
        WHEN 'HIDE'.        do_hide( ls_c ).
        WHEN 'ATTACH_TYPE'. do_attach( ls_c ).
        WHEN 'STEP_TITLE'.  do_step_title( ls_c ).
        WHEN 'STEP_OFF'.    do_step_off( ls_c ).
        WHEN 'GRIDCOL'.     do_gridcol( ls_c ).
        WHEN OTHERS.
          say( iv_state = 'SKIP' is_c = ls_c iv_detail = 'unknown kind' ).
      ENDCASE.
    ENDLOOP.

    SKIP.
    WRITE: / 'Changed:', gv_ok, '  Already correct:', gv_same,
             '  Not found:', gv_miss.

    IF p_test = abap_false AND gv_ok > 0.
      COMMIT WORK.
      WRITE: / 'Committed.' COLOR col_positive.
    ENDIF.

    IF p_todo = abap_true.
      SKIP 2.
      WRITE: / 'STILL TO DO IN THE STUDIO - not mechanical, not attempted here'
               COLOR col_group.
      ULINE.
      DATA(lt_todo) = worklist( ).
      LOOP AT lt_todo INTO DATA(ls_t).
        WRITE: / ls_t-ticket, 12 ls_t-jrny, 20 ls_t-what.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD say.
    DATA lv_col TYPE i.
    CASE iv_state.
      WHEN 'DONE'.    lv_col = col_positive. gv_ok   = gv_ok   + 1.
      WHEN 'ALREADY'. lv_col = col_normal.   gv_same = gv_same + 1.
      WHEN OTHERS.    lv_col = col_negative. gv_miss = gv_miss + 1.
    ENDCASE.
    FORMAT COLOR = lv_col.
    WRITE: / iv_state, 12 is_c-ticket, 25 is_c-jrny, 33 is_c-kind, 47 iv_detail.
    FORMAT COLOR OFF.
  ENDMETHOD.


  METHOD step_of.
    CLEAR rv.
    SELECT SINGLE step_id FROM zrak_t_jny_fld
      WHERE journey_id = @iv_jrny AND field_name = @iv_anchor
      INTO @rv.
  ENDMETHOD.


  METHOD do_label.
    DATA(lv_step) = step_of( iv_jrny = is_c-jrny iv_anchor = is_c-fld ).
    IF lv_step IS INITIAL.
      say( iv_state = 'NOTFOUND' is_c = is_c
           iv_detail = |field { is_c-fld } is not on this journey| ).
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrak_t_jny_fld
      WHERE journey_id = @is_c-jrny AND step_id = @lv_step
        AND field_name = @is_c-fld
      INTO @DATA(ls_f).
    IF sy-subrc <> 0.
      say( iv_state = 'NOTFOUND' is_c = is_c iv_detail = 'row vanished' ).
      RETURN.
    ENDIF.

    IF ls_f-zlabel = is_c-newv AND ls_f-zlabel_ar = is_c-newar.
      say( iv_state = 'ALREADY' is_c = is_c iv_detail = is_c-newv ).
      RETURN.
    ENDIF.

    say( iv_state = 'DONE' is_c = is_c
         iv_detail = |{ ls_f-zlabel } -> { is_c-newv }| ).
    IF p_test = abap_false.
      ls_f-zlabel = is_c-newv.
      IF is_c-newar IS NOT INITIAL.
        ls_f-zlabel_ar = is_c-newar.
      ENDIF.
      MODIFY zrak_t_jny_fld FROM ls_f.
    ENDIF.
  ENDMETHOD.


  METHOD do_hide.
*   The field is hidden on ONE step only - the step carrying the anchor.
*   Hiding it everywhere would take it off the step where the citizen is
*   supposed to answer it, which is the opposite of what the ticket asked.
    DATA(lv_step) = step_of( iv_jrny = is_c-jrny iv_anchor = is_c-anchor ).
    IF lv_step IS INITIAL.
      say( iv_state = 'NOTFOUND' is_c = is_c
           iv_detail = |anchor { is_c-anchor } is not on this journey| ).
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrak_t_jny_fld
      WHERE journey_id = @is_c-jrny AND step_id = @lv_step
        AND field_name = @is_c-fld
      INTO @DATA(ls_f).
    IF sy-subrc <> 0.
      say( iv_state = 'NOTFOUND' is_c = is_c
           iv_detail = |{ is_c-fld } is not on step { lv_step }| ).
      RETURN.
    ENDIF.

    IF ls_f-hidden = 'X'.
      say( iv_state = 'ALREADY' is_c = is_c
           iv_detail = |{ is_c-fld } already hidden on { lv_step }| ).
      RETURN.
    ENDIF.

    say( iv_state = 'DONE' is_c = is_c
         iv_detail = |hide { is_c-fld } on step { lv_step }| ).
    IF p_test = abap_false.
      ls_f-hidden = 'X'.
      MODIFY zrak_t_jny_fld FROM ls_f.
    ENDIF.
  ENDMETHOD.


  METHOD do_attach.
*   Every upload field on the journey, because the ticket asked for the
*   accept list as a whole rather than naming one field - and the accept
*   list is what drives both the file picker's filter and the hint text.
    SELECT * FROM zrak_t_jny_fld
      WHERE journey_id = @is_c-jrny AND has_attach = 'X'
      INTO TABLE @DATA(lt_f).
    IF sy-subrc <> 0.
      say( iv_state = 'NOTFOUND' is_c = is_c
           iv_detail = 'no upload fields on this journey' ).
      RETURN.
    ENDIF.

    LOOP AT lt_f INTO DATA(ls_f).
      IF ls_f-attach_types = is_c-newv.
        gv_same = gv_same + 1.
        CONTINUE.
      ENDIF.
      say( iv_state = 'DONE' is_c = is_c
           iv_detail = |{ ls_f-field_name }: { ls_f-attach_types } -> { is_c-newv }| ).
      IF p_test = abap_false.
        ls_f-attach_types = is_c-newv.
        MODIFY zrak_t_jny_fld FROM ls_f.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD do_step_title.
    SELECT * FROM zrak_t_jny_step
      WHERE journey_id = @is_c-jrny
      INTO TABLE @DATA(lt_s).

    LOOP AT lt_s INTO DATA(ls_s).
      IF to_upper( condense( CONV string( ls_s-title ) ) ) <>
         to_upper( condense( is_c-oldv ) ).
        CONTINUE.
      ENDIF.

      IF ls_s-title = is_c-newv.
        say( iv_state = 'ALREADY' is_c = is_c iv_detail = is_c-newv ).
        RETURN.
      ENDIF.

      say( iv_state = 'DONE' is_c = is_c
           iv_detail = |step { ls_s-step_id }: { ls_s-title } -> { is_c-newv }| ).
      IF p_test = abap_false.
        ls_s-title = is_c-newv.
        IF is_c-newar IS NOT INITIAL.
          ls_s-title_ar = is_c-newar.
        ENDIF.
        MODIFY zrak_t_jny_step FROM ls_s.
      ENDIF.
      RETURN.
    ENDLOOP.

    say( iv_state = 'NOTFOUND' is_c = is_c
         iv_detail = |no step titled "{ is_c-oldv }"| ).
  ENDMETHOD.


  METHOD do_step_off.
*   ACTIVE = blank, never a DELETE. The step's field rows stay where they
*   are, so turning it back on is one flag and not a re-migration.
*
*   Matched with CS rather than equality because the ticket named these
*   steps by what they do ("request confirmation") and not by their exact
*   configured title. Run in test mode first and read which step matched -
*   that print is the whole reason this is safe.
    SELECT * FROM zrak_t_jny_step
      WHERE journey_id = @is_c-jrny
      INTO TABLE @DATA(lt_s).

    DATA lv_hit TYPE abap_bool.
    LOOP AT lt_s INTO DATA(ls_s).
      IF to_upper( CONV string( ls_s-title ) ) NS to_upper( is_c-oldv ).
        CONTINUE.
      ENDIF.
      lv_hit = abap_true.

      IF ls_s-active IS INITIAL.
        say( iv_state = 'ALREADY' is_c = is_c
             iv_detail = |step { ls_s-step_id } "{ ls_s-title }" already off| ).
        CONTINUE.
      ENDIF.

      say( iv_state = 'DONE' is_c = is_c
           iv_detail = |turn off step { ls_s-step_id } "{ ls_s-title }"| ).
      IF p_test = abap_false.
        CLEAR ls_s-active.
        MODIFY zrak_t_jny_step FROM ls_s.
      ENDIF.
    ENDLOOP.

    IF lv_hit = abap_false.
      say( iv_state = 'NOTFOUND' is_c = is_c
           iv_detail = |no step whose title contains "{ is_c-oldv }"| ).
    ENDIF.
  ENDMETHOD.


  METHOD do_gridcol.
*   ZRAK_T_JNY_COL WINS OVER THE SPEC. ZCL_RAK_JOURNEY_GRID->GRID_COLS( )
*   reads the column table in preference to the pipe-separated spec on the
*   field, so appending to DEFAULT_VAL while ZRAK_T_JNY_COL rows exist
*   changes nothing on screen. When rows exist this reports that and stops
*   rather than writing somewhere nobody reads.
    DATA(lv_step) = step_of( iv_jrny = is_c-jrny iv_anchor = is_c-fld ).
    IF lv_step IS INITIAL.
      say( iv_state = 'NOTFOUND' is_c = is_c
           iv_detail = |grid { is_c-fld } is not on this journey| ).
      RETURN.
    ENDIF.

    SELECT COUNT(*) FROM zrak_t_jny_col
      WHERE journey_id = @is_c-jrny AND step_id = @lv_step
        AND field_name = @is_c-fld
      INTO @DATA(lv_cnt).
    IF lv_cnt > 0.
      say( iv_state = 'SKIP' is_c = is_c
           iv_detail = |{ lv_cnt } ZRAK_T_JNY_COL rows own this grid - add the column there| ).
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrak_t_jny_fld
      WHERE journey_id = @is_c-jrny AND step_id = @lv_step
        AND field_name = @is_c-fld
      INTO @DATA(ls_f).
    IF sy-subrc <> 0.
      say( iv_state = 'NOTFOUND' is_c = is_c iv_detail = 'grid row vanished' ).
      RETURN.
    ENDIF.

*   A literal pipe as a CONSTANT, not inside a string template. A bare | in
*   a template closes the literal, and the escaped form is one of the
*   easiest things in this dialect to get wrong.
    CONSTANTS lc_pipe TYPE c LENGTH 1 VALUE '|'.

    DATA(lv_spec) = CONV string( ls_f-default_val ).
    SPLIT lv_spec AT lc_pipe INTO TABLE DATA(lt_col).

    LOOP AT lt_col INTO DATA(lv_col).
      SPLIT condense( lv_col ) AT ':' INTO DATA(lv_key) DATA(lv_rest).
      IF to_upper( condense( lv_key ) ) = to_upper( condense( is_c-newv ) ).
        say( iv_state = 'ALREADY' is_c = is_c
             iv_detail = |column { is_c-newv } already in the spec| ).
        RETURN.
      ENDIF.
    ENDLOOP.

    DATA(lv_add) = is_c-newv && ':' && is_c-newar && ':TEXT'.
    DATA(lv_new) = COND string( WHEN lv_spec IS INITIAL THEN lv_add
                                ELSE lv_spec && lc_pipe && lv_add ).

    IF strlen( lv_new ) > 1000.
      say( iv_state = 'SKIP' is_c = is_c
           iv_detail = 'spec would exceed DEFAULT_VAL CHAR(1000)' ).
      RETURN.
    ENDIF.

    say( iv_state = 'DONE' is_c = is_c
         iv_detail = |append column { is_c-newv } ({ lines( lt_col ) } -> { lines( lt_col ) + 1 })| ).
    IF p_test = abap_false.
      ls_f-default_val = lv_new.
      MODIFY zrak_t_jny_fld FROM ls_f.
    ENDIF.
  ENDMETHOD.


  METHOD changes.
*&-------------------------------------------------------------------
*& THE PACK. One row per ticket point.
*&
*& Field names here are the ones the handler classes actually use - they
*& were read out of the ABAP, not inferred from the screen. A name that
*& turns out wrong reports NOT FOUND against the exact key it tried, so a
*& test run tells you which line to correct rather than leaving you to
*& guess. Correct the line, run again; every applier is idempotent.
*&-------------------------------------------------------------------
    rt = VALUE tt_chg(

*     --- Step renames. Matched on the CURRENT title, exactly as quoted on
*     --- the tickets. Arabic supplied so the rename does not leave the AR
*     --- twin saying the old thing.
      ( ticket = 'CJSMIG-683' jrny = 'E021' kind = 'STEP_TITLE'
        oldv = 'Letter from the Supplier Company'
        newv = 'Documents' newar = 'المستندات' )

      ( ticket = 'CJSMIG-684' jrny = 'E022' kind = 'STEP_TITLE'
        oldv = 'Development Project'
        newv = 'Project Details' newar = 'تفاصيل المشروع' )

      ( ticket = 'CJSMIG-684' jrny = 'E022' kind = 'STEP_TITLE'
        oldv = 'Trade license'
        newv = 'Documents' newar = 'المستندات' )

*     --- Steps the testers asked to remove. ACTIVE = blank, reversible.
      ( ticket = 'CJSMIG-684' jrny = 'E022' kind = 'STEP_OFF'
        oldv = 'CONFIRM' )
      ( ticket = 'CJSMIG-686' jrny = 'E016' kind = 'STEP_OFF'
        oldv = 'CONFIRM' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' kind = 'STEP_OFF'
        oldv = 'CONFIRM' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' kind = 'STEP_OFF'
        oldv = 'PREVIEW' )

*     --- "Context tab - permit number, trade licence etc. not required in
*     --- chemical tab", raised on all three chemical journeys. The three
*     --- names are the ones ZCL_E016/E017/E018 read in ON_CHANGE( ), and
*     --- the chemical step is found by its CHEMICALS_DETAILS grid.
      ( ticket = 'CJSMIG-686' jrny = 'E016' kind = 'HIDE'
        fld = 'PERMIT_NUMBER'      anchor = 'CHEMICALS_DETAILS' )
      ( ticket = 'CJSMIG-686' jrny = 'E016' kind = 'HIDE'
        fld = 'TRADE_LICENSE'      anchor = 'CHEMICALS_DETAILS' )
      ( ticket = 'CJSMIG-686' jrny = 'E016' kind = 'HIDE'
        fld = 'REGISTERED_EMIRATES' anchor = 'CHEMICALS_DETAILS' )

      ( ticket = 'CJSMIG-687' jrny = 'E017' kind = 'HIDE'
        fld = 'PERMIT_NUMBER'      anchor = 'CHEMICALS_DETAILS' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' kind = 'HIDE'
        fld = 'TRADE_LICENSE'      anchor = 'CHEMICALS_DETAILS' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' kind = 'HIDE'
        fld = 'REGISTERED_EMIRATES' anchor = 'CHEMICALS_DETAILS' )

      ( ticket = 'CJSMIG-697' jrny = 'E018' kind = 'HIDE'
        fld = 'PERMIT_NUMBER'      anchor = 'CHEMICALS_DETAILS' )
      ( ticket = 'CJSMIG-697' jrny = 'E018' kind = 'HIDE'
        fld = 'TRADE_LICENSE'      anchor = 'CHEMICALS_DETAILS' )
      ( ticket = 'CJSMIG-697' jrny = 'E018' kind = 'HIDE'
        fld = 'REGISTERED_EMIRATES' anchor = 'CHEMICALS_DETAILS' )

*     --- The fourteenth grid column E016 owes its new Transport Company
*     --- field. Without it the value is collected by the dialog and
*     --- dropped on save, silently - see FORM_SAVE( ) in the handler.
      ( ticket = 'CJSMIG-686' jrny = 'E016' kind = 'GRIDCOL'
        fld = 'CHEMICALS_DETAILS'
        newv = 'TRANS_COMP' newar = 'Transport Company' )

*     --- "Add Manager - wrong text - should be Birthday". MANAGER_DOB is
*     --- the field ZCL_D002_SCHOOL_LIC_NEW_LOGIC writes the date into.
      ( ticket = 'CJSMIG-688' jrny = 'D002' kind = 'LABEL'
        fld = 'MANAGER_DOB'
        newv = 'Birthday' newar = 'تاريخ الميلاد' )

*     --- "Attachment type should be PDF, JPG - but DOC type showing", and
*     --- "can't upload PDF or photo" - one accept list, both symptoms.
      ( ticket = 'CJSMIG-688' jrny = 'D002' kind = 'ATTACH_TYPE'
        newv = 'pdf,jpg,jpeg,png' )
    ).
  ENDMETHOD.


  METHOD worklist.
*   The 24 points this report deliberately leaves alone. Each needs a
*   decision - a layout, a new field, wording - that config cannot be
*   derived into.
    rt = VALUE tt_todo(
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Applicant details: lay out row wise (Design tab)' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Add EPDA permit no + applicant type fields' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Permit/EID/trade licence order; search button needs FTYPE SEARCH' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Company details: field order' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Company name EN/AR must fill from permit number' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Grid: all row fields REQUIRED; drop the delete1 column' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Units and No. of Months become dropdowns' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Supplier company: order + REQUIRED markers' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'REQUIRED on the mandatory upload fields' )
      ( ticket = 'CJSMIG-683' jrny = 'E021' what = 'Declaration and Notes text (DEFAULT_VAL TEXT: prefix)' )
      ( ticket = 'CJSMIG-684' jrny = 'E022' what = 'Applicant details: lay out row wise' )
      ( ticket = 'CJSMIG-684' jrny = 'E022' what = 'Emirates ID search format; drop the Browse button' )
      ( ticket = 'CJSMIG-684' jrny = 'E022' what = 'Permit/EID/trade licence order; permit number not a dropdown' )
      ( ticket = 'CJSMIG-684' jrny = 'E022' what = 'Company details: field order' )
      ( ticket = 'CJSMIG-684' jrny = 'E022' what = 'Add the trade licence upload field' )
      ( ticket = 'CJSMIG-684' jrny = 'E022' what = 'Declaration and Note text' )
      ( ticket = 'CJSMIG-686' jrny = 'E016' what = 'Owner search: EID format, drop Browse button' )
      ( ticket = 'CJSMIG-686' jrny = 'E016' what = 'Remove the owner message on Chemical Details' )
      ( ticket = 'CJSMIG-686' jrny = 'E016' what = 'REQUIRED on the mandatory upload fields' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' what = 'Owner search: EID format, drop Browse button' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' what = 'Check BOL_POP exists in ZRAK_T_JNY_FLD - why BOL clears' )
      ( ticket = 'CJSMIG-687' jrny = 'E017' what = 'REQUIRED on the mandatory upload fields' )
      ( ticket = 'CJSMIG-688' jrny = 'D002' what = 'Arabic text: ZLABEL_AR across the journey' )
      ( ticket = 'CJSMIG-688' jrny = 'D002' what = 'Building Information fields' )
      ( ticket = 'CJSMIG-692' jrny = 'D003' what = 'Add the missing BP labels' )
      ( ticket = 'CJSMIG-693' jrny = 'D021' what = 'Rename educational stage to Distance (field name unknown here)' )
      ( ticket = 'CJSMIG-695' jrny = 'D004' what = 'Add Nationality and Birthdate to the Add Owner popup' )
      ( ticket = 'CJSMIG-697' jrny = 'E018' what = 'Owner search: EID format, drop Browse button' )
      ( ticket = 'CJSMIG-697' jrny = 'E018' what = 'Check BOL_POP exists in ZRAK_T_JNY_FLD' )
    ).
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  lcl_fix=>run( ).
