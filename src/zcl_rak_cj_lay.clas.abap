CLASS zcl_rak_cj_lay DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES ty_key   TYPE c LENGTH 30.
    TYPES ty_kind  TYPE c LENGTH 1.
    TYPES ty_align TYPE c LENGTH 6.
    TYPES ty_width TYPE c LENGTH 12.

    TYPES: BEGIN OF ty_attr,
             row_no     TYPE i,
             col_start  TYPE i,
             col_span   TYPE i,
             label_span TYPE i,
             inline     TYPE abap_bool,
*            Lay this cell's own contents left to right instead of top to bottom,
*            so a button a handler adds after the field sits BESIDE it rather
*            than under it. Distinct from INLINE, which is about which ROW a
*            cell lands on; this is about the direction INSIDE one cell.
             flow       TYPE abap_bool,
             hidden     TYPE abap_bool,
             fixed      TYPE abap_bool,
             align      TYPE ty_align,
             width      TYPE ty_width,
           END OF ty_attr.

    TYPES: BEGIN OF ty_cell,
             elem_id TYPE ty_key,
             attr    TYPE ty_attr,
           END OF ty_cell.
    TYPES ty_t_cell TYPE STANDARD TABLE OF ty_cell WITH EMPTY KEY.

    TYPES: BEGIN OF ty_row,
             row_no TYPE i,
             cells  TYPE ty_t_cell,
           END OF ty_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES ty_t_elem TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

    CONSTANTS: BEGIN OF c_align,
                 start  TYPE ty_align VALUE 'START',
                 center TYPE ty_align VALUE 'CENTER',
                 end    TYPE ty_align VALUE 'END',
               END OF c_align.

    CONSTANTS: BEGIN OF c_kind,
                 form TYPE ty_kind VALUE 'F',
                 grid TYPE ty_kind VALUE 'G',
               END OF c_kind.

    CONSTANTS: BEGIN OF c_tri,
                 yes TYPE c LENGTH 1 VALUE 'X',
                 no  TYPE c LENGTH 1 VALUE '-',
               END OF c_tri.

    CONSTANTS c_any TYPE ty_key VALUE '*'.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_lay) TYPE REF TO zcl_rak_cj_lay.

    CLASS-METHODS span_str
      IMPORTING iv_span       TYPE i
      RETURNING VALUE(rv_str) TYPE string.

    CLASS-METHODS text_align
      IMPORTING iv_align      TYPE ty_align
      RETURNING VALUE(rv_str) TYPE string.

    METHODS invalidate.

    METHODS resolve
      IMPORTING iv_journey     TYPE ty_key
                iv_step        TYPE ty_key
                iv_block       TYPE ty_key
                iv_elem        TYPE ty_key
                iv_kind        TYPE ty_kind DEFAULT c_kind-form
      RETURNING VALUE(rs_attr) TYPE ty_attr.

    METHODS has_layout
      IMPORTING iv_journey    TYPE ty_key
                iv_step       TYPE ty_key
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    METHODS plan
      IMPORTING iv_journey     TYPE ty_key
                iv_step        TYPE ty_key
                iv_block       TYPE ty_key
                it_elem        TYPE ty_t_elem
      RETURNING VALUE(rt_rows) TYPE ty_t_row.

    METHODS grid_columns
      IMPORTING iv_journey    TYPE ty_key
                iv_step       TYPE ty_key
                iv_block      TYPE ty_key
                it_col        TYPE ty_t_elem
      RETURNING VALUE(rt_col) TYPE ty_t_cell.

    METHODS persist
      IMPORTING iv_journey TYPE ty_key
                iv_step    TYPE ty_key
                iv_block   TYPE ty_key
                iv_elem    TYPE ty_key
                iv_kind    TYPE ty_kind DEFAULT c_kind-form
                is_attr    TYPE ty_attr.

    METHODS reset_block
      IMPORTING iv_journey TYPE ty_key
                iv_step    TYPE ty_key
                iv_block   TYPE ty_key.

  PRIVATE SECTION.

    CLASS-DATA go_inst TYPE REF TO zcl_rak_cj_lay.

    DATA mv_journey TYPE ty_key.
    DATA mv_loaded  TYPE abap_bool.
    DATA mt_lay     TYPE STANDARD TABLE OF zrak_cj_lay WITH EMPTY KEY.

    METHODS load
      IMPORTING iv_journey TYPE ty_key.

    METHODS score
      IMPORTING is_row          TYPE zrak_cj_lay
      RETURNING VALUE(rv_score) TYPE i.

    METHODS merge
      IMPORTING is_row  TYPE zrak_cj_lay
      CHANGING  cs_attr TYPE ty_attr.

ENDCLASS.



CLASS ZCL_RAK_CJ_LAY IMPLEMENTATION.


  METHOD get_instance.
    IF go_inst IS INITIAL.
      go_inst = NEW #( ).
    ENDIF.
    ro_lay = go_inst.
  ENDMETHOD.


  METHOD grid_columns.

    LOOP AT it_col ASSIGNING FIELD-SYMBOL(<lv_c>).
      DATA(ls_attr) = resolve( iv_journey = iv_journey
                               iv_step    = iv_step
                               iv_block   = iv_block
                               iv_elem    = <lv_c>
                               iv_kind    = c_kind-grid ).
      IF ls_attr-hidden = abap_true.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( elem_id = <lv_c>
                      attr    = ls_attr ) TO rt_col.
    ENDLOOP.

    SORT rt_col STABLE BY attr-row_no ASCENDING.

  ENDMETHOD.


  METHOD has_layout.

    load( iv_journey ).

    LOOP AT mt_lay TRANSPORTING NO FIELDS
         WHERE kind    = c_kind-form
           AND journey = iv_journey
           AND ( step_id = iv_step OR step_id = c_any ).
      rv_yes = abap_true.
      EXIT.
    ENDLOOP.

  ENDMETHOD.


  METHOD invalidate.
    CLEAR mv_journey.
    CLEAR mv_loaded.
    CLEAR mt_lay.
  ENDMETHOD.


  METHOD load.
    IF mv_loaded = abap_true AND mv_journey = iv_journey.
      RETURN.
    ENDIF.
    CLEAR mt_lay.
    SELECT * FROM zrak_cj_lay
      WHERE journey = @iv_journey
         OR journey = @c_any
      INTO TABLE @mt_lay.
    mv_journey = iv_journey.
    mv_loaded  = abap_true.
  ENDMETHOD.


  METHOD merge.
    IF is_row-row_no IS NOT INITIAL.
      cs_attr-row_no = is_row-row_no.
    ENDIF.
    IF is_row-col_start IS NOT INITIAL.
      cs_attr-col_start = is_row-col_start.
    ENDIF.
    IF is_row-col_span IS NOT INITIAL.
      cs_attr-col_span = is_row-col_span.
    ENDIF.
    IF is_row-label_span IS NOT INITIAL.
      cs_attr-label_span = is_row-label_span.
    ENDIF.
    IF is_row-align IS NOT INITIAL.
      cs_attr-align = is_row-align.
    ENDIF.
    IF is_row-width IS NOT INITIAL.
      cs_attr-width = is_row-width.
    ENDIF.
    CASE is_row-inline.
      WHEN c_tri-yes.
        cs_attr-inline = abap_true.
      WHEN c_tri-no.
        cs_attr-inline = abap_false.
    ENDCASE.
    CASE is_row-flow.
      WHEN c_tri-yes.
        cs_attr-flow = abap_true.
      WHEN c_tri-no.
        cs_attr-flow = abap_false.
    ENDCASE.
    CASE is_row-hidden.
      WHEN c_tri-yes.
        cs_attr-hidden = abap_true.
      WHEN c_tri-no.
        cs_attr-hidden = abap_false.
    ENDCASE.
    CASE is_row-fixed.
      WHEN c_tri-yes.
        cs_attr-fixed = abap_true.
      WHEN c_tri-no.
        cs_attr-fixed = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD persist.

    DATA ls_db TYPE zrak_cj_lay.

    ls_db-journey    = iv_journey.
    ls_db-step_id    = iv_step.
    ls_db-block_id   = iv_block.
    ls_db-elem_id    = iv_elem.
    ls_db-kind       = iv_kind.
    ls_db-row_no     = is_attr-row_no.
    ls_db-col_start  = is_attr-col_start.
    ls_db-col_span   = is_attr-col_span.
    ls_db-label_span = is_attr-label_span.
    ls_db-align      = is_attr-align.
    ls_db-width      = is_attr-width.
    ls_db-inline     = COND #( WHEN is_attr-inline = abap_true THEN c_tri-yes ELSE c_tri-no ).
    ls_db-flow       = COND #( WHEN is_attr-flow   = abap_true THEN c_tri-yes ELSE c_tri-no ).
    ls_db-hidden     = COND #( WHEN is_attr-hidden = abap_true THEN c_tri-yes ELSE c_tri-no ).
    ls_db-fixed      = COND #( WHEN is_attr-fixed  = abap_true THEN c_tri-yes ELSE c_tri-no ).
    ls_db-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_db-changed_at.

    MODIFY zrak_cj_lay FROM ls_db.
    COMMIT WORK AND WAIT.

    invalidate( ).

  ENDMETHOD.


  METHOD plan.

    DATA lt_cell  TYPE ty_t_cell.
    DATA lv_cur   TYPE i.
    DATA lv_sort  TYPE abap_bool.
    DATA lv_first TYPE abap_bool VALUE abap_true.

    LOOP AT it_elem ASSIGNING FIELD-SYMBOL(<lv_e>).
      DATA(ls_attr) = resolve( iv_journey = iv_journey
                               iv_step    = iv_step
                               iv_block   = iv_block
                               iv_elem    = <lv_e> ).
      IF ls_attr-hidden = abap_true.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( elem_id = <lv_e>
                      attr    = ls_attr ) TO lt_cell.
    ENDLOOP.

    LOOP AT lt_cell TRANSPORTING NO FIELDS WHERE attr-row_no > 0.
      lv_sort = abap_true.
      EXIT.
    ENDLOOP.

    IF lv_sort = abap_true.
      SORT lt_cell STABLE BY attr-row_no ASCENDING attr-col_start ASCENDING.
    ENDIF.

    LOOP AT lt_cell ASSIGNING FIELD-SYMBOL(<ls_c>).

      IF lv_first = abap_true.
        lv_cur   = COND #( WHEN <ls_c>-attr-row_no > 0 THEN <ls_c>-attr-row_no ELSE 1 ).
        lv_first = abap_false.
      ELSEIF <ls_c>-attr-inline = abap_false.
        IF <ls_c>-attr-row_no > 0.
          lv_cur = <ls_c>-attr-row_no.
        ELSE.
          lv_cur = lv_cur + 1.
        ENDIF.
      ENDIF.

      READ TABLE rt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WITH KEY row_no = lv_cur.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO rt_rows ASSIGNING <ls_row>.
        <ls_row>-row_no = lv_cur.
      ENDIF.

      APPEND <ls_c> TO <ls_row>-cells.

    ENDLOOP.

  ENDMETHOD.


  METHOD reset_block.

    DELETE FROM zrak_cj_lay
      WHERE journey  = @iv_journey
        AND step_id  = @iv_step
        AND block_id = @iv_block.

    COMMIT WORK AND WAIT.

    invalidate( ).

  ENDMETHOD.


  METHOD resolve.

    TYPES: BEGIN OF ty_scored,
             score TYPE i,
             row   TYPE zrak_cj_lay,
           END OF ty_scored.

    DATA lt_scored TYPE STANDARD TABLE OF ty_scored WITH EMPTY KEY.

    load( iv_journey ).

    LOOP AT mt_lay ASSIGNING FIELD-SYMBOL(<ls_r>) WHERE kind = iv_kind.
      IF <ls_r>-journey <> c_any AND <ls_r>-journey <> iv_journey.
        CONTINUE.
      ENDIF.
      IF <ls_r>-step_id <> c_any AND <ls_r>-step_id <> iv_step.
        CONTINUE.
      ENDIF.
      IF <ls_r>-block_id <> c_any AND <ls_r>-block_id <> iv_block.
        CONTINUE.
      ENDIF.
      IF <ls_r>-elem_id <> c_any AND <ls_r>-elem_id <> iv_elem.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( score = score( <ls_r> )
                      row   = <ls_r> ) TO lt_scored.
    ENDLOOP.

    SORT lt_scored STABLE BY score ASCENDING.

    LOOP AT lt_scored ASSIGNING FIELD-SYMBOL(<ls_s>).
      merge( EXPORTING is_row  = <ls_s>-row
             CHANGING  cs_attr = rs_attr ).
    ENDLOOP.

    IF rs_attr-col_span <= 0 OR rs_attr-col_span > 12.
      rs_attr-col_span = 12.
    ENDIF.
    IF rs_attr-align IS INITIAL.
      rs_attr-align = c_align-start.
    ENDIF.

  ENDMETHOD.


  METHOD score.
    rv_score = 0.
    IF is_row-journey <> c_any.
      rv_score = rv_score + 8.
    ENDIF.
    IF is_row-step_id <> c_any.
      rv_score = rv_score + 4.
    ENDIF.
    IF is_row-block_id <> c_any.
      rv_score = rv_score + 2.
    ENDIF.
    IF is_row-elem_id <> c_any.
      rv_score = rv_score + 1.
    ENDIF.
  ENDMETHOD.


  METHOD span_str.
    DATA(lv_span) = iv_span.
    IF lv_span < 1 OR lv_span > 12.
      lv_span = 12.
    ENDIF.
    DATA(lv_med) = COND i( WHEN lv_span <= 6 THEN 6 ELSE 12 ).
    rv_str = |XL{ lv_span } L{ lv_span } M{ lv_med } S12|.
  ENDMETHOD.


  METHOD text_align.
    rv_str = SWITCH string( iv_align
                            WHEN c_align-center THEN 'Center'
                            WHEN c_align-end    THEN 'End'
                            ELSE 'Begin' ).
  ENDMETHOD.
ENDCLASS.
