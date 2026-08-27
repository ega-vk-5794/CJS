*----------------------------------------------------------------------*
***INCLUDE LZFG_MV_JNY_COLO01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module SORT_EXTRACT OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE sort_extract OUTPUT.
  TYPES: BEGIN OF ts_jny_col.
           INCLUDE STRUCTURE zmv_jny_col.
  TYPES: END OF ts_jny_col.

  DATA lt_temp    LIKE zmv_jny_col OCCURS 1 WITH HEADER LINE.
  DATA lt_jny_col TYPE STANDARD TABLE OF ts_jny_col.
  DATA ls_jny_col TYPE ts_jny_col.

  FIELD-SYMBOLS <fs_rec_from> TYPE x.
  FIELD-SYMBOLS <fs_rec_to>   TYPE x. "Hexadecimal value of to record


  CASE sy-ucomm.
    WHEN space OR back OR  'AEND'.

      IF sy-tcode = 'SM34'.
        CLEAR lt_jny_col[].
        REFRESH lt_jny_col[].

        LOOP AT extract.
          APPEND INITIAL LINE TO lt_jny_col ASSIGNING <fs_rec_to> CASTING.
          ASSIGN extract TO <fs_rec_from> CASTING.
          <fs_rec_to> = <fs_rec_from>.
        ENDLOOP.

        UNASSIGN <fs_rec_to>.
        UNASSIGN <fs_rec_from>.

        SORT lt_jny_col BY seqnr ASCENDING.
        CLEAR extract[].
        REFRESH extract[].
        LOOP AT lt_jny_col INTO ls_jny_col.
          APPEND INITIAL LINE TO extract ASSIGNING <fs_rec_to> CASTING.
          ASSIGN ls_jny_col TO <fs_rec_from> CASTING.
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
