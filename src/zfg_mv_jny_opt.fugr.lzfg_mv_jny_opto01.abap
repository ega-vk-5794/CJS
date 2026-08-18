*----------------------------------------------------------------------*
***INCLUDE LZFG_MV_JNY_OPTO01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module SORT_EXTRACT OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE sort_extract OUTPUT.

  TYPES: BEGIN OF ts_jny_opt.
           INCLUDE STRUCTURE zmv_jny_opt.
  TYPES: END OF ts_jny_opt.

  DATA lt_temp    LIKE zmv_jny_opt OCCURS 1 WITH HEADER LINE.
  DATA lt_jny_opt TYPE STANDARD TABLE OF ts_jny_opt.
  DATA ls_jny_opt TYPE ts_jny_opt.

  FIELD-SYMBOLS <fs_rec_from> TYPE x.
  FIELD-SYMBOLS <fs_rec_to>   TYPE x. "Hexadecimal value of to record


  CASE sy-ucomm.
    WHEN space OR back OR  'AEND'.

      IF sy-tcode = 'SM34'.
        CLEAR lt_jny_opt[].
        REFRESH lt_jny_opt[].

        LOOP AT extract.
          APPEND INITIAL LINE TO lt_jny_opt ASSIGNING <fs_rec_to> CASTING.
          ASSIGN extract TO <fs_rec_from> CASTING.
          <fs_rec_to> = <fs_rec_from>.
        ENDLOOP.

        UNASSIGN <fs_rec_to>.
        UNASSIGN <fs_rec_from>.

        SORT lt_jny_opt BY seqnr ASCENDING.
        CLEAR extract[].
        REFRESH extract[].
        LOOP AT lt_jny_opt INTO ls_jny_opt.
          APPEND INITIAL LINE TO extract ASSIGNING <fs_rec_to> CASTING.
          ASSIGN ls_jny_opt TO <fs_rec_from> CASTING.
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
