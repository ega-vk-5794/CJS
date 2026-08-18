*----------------------------------------------------------------------*
***INCLUDE LZFG_T_JNY_STEPO01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module SORT_TABLE OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE sort_table OUTPUT.
  TYPES: BEGIN OF ts_jny_step.
           INCLUDE STRUCTURE zmv_jny_step.
  TYPES: END OF ts_jny_step.

  DATA lt_temp    LIKE zmv_jny_step OCCURS 1 WITH HEADER LINE.
  DATA lt_jny_step TYPE STANDARD TABLE OF ts_jny_step.
  DATA ls_jny_step TYPE ts_jny_step.

  FIELD-SYMBOLS <fs_rec_from> TYPE x.
  FIELD-SYMBOLS <fs_rec_to>   TYPE x. "Hexadecimal value of to record

  CASE sy-ucomm.
    WHEN space OR back OR  'AEND'.

      IF sy-tcode = 'SM34'.
        CLEAR lt_jny_step[].
        REFRESH lt_jny_step[].

        LOOP AT extract.
          APPEND INITIAL LINE TO lt_jny_step ASSIGNING <fs_rec_to> CASTING.
          ASSIGN extract TO <fs_rec_from> CASTING.
          <fs_rec_to> = <fs_rec_from>.
        ENDLOOP.

        UNASSIGN <fs_rec_to>.
        UNASSIGN <fs_rec_from>.

        SORT lt_jny_step BY seqnr ASCENDING.
        CLEAR extract[].
        REFRESH extract[].
        LOOP AT lt_jny_step INTO ls_jny_step.
          APPEND INITIAL LINE TO extract ASSIGNING <fs_rec_to> CASTING.
          ASSIGN ls_jny_step TO <fs_rec_from> CASTING.
          <fs_rec_to> = <fs_rec_from>.
        ENDLOOP.

      ELSE.
        lt_temp[] = extract[].
        SORT lt_temp ASCENDING BY seqnr.
        extract[] = lt_temp[].
      ENDIF.

    WHEN OTHERS.
  ENDCASE.
ENDMODULE.
