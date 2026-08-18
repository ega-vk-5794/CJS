CLASS zcl_rak_cj_txt_io DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_imp_log,
             journey  TYPE zif_rak_cj_text_src=>ty_key,
             elem_id  TYPE zif_rak_cj_text_src=>ty_key,
             action   TYPE c LENGTH 10,
             old_en   TYPE string,
             new_en   TYPE string,
             old_ar   TYPE string,
             new_ar   TYPE string,
             message  TYPE string,
           END OF ty_imp_log.

    TYPES ty_t_imp_log TYPE STANDARD TABLE OF ty_imp_log WITH EMPTY KEY.

    METHODS constructor
      IMPORTING io_src TYPE REF TO zif_rak_cj_text_src OPTIONAL.

    METHODS export
      IMPORTING it_journey    TYPE zif_rak_cj_text_src=>ty_t_journey
      RETURNING VALUE(rv_xstr) TYPE xstring.

    METHODS import
      IMPORTING iv_xstr       TYPE xstring
                iv_commit     TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rt_log) TYPE ty_t_imp_log.

  PRIVATE SECTION.

    CONSTANTS c_tab TYPE c LENGTH 1 VALUE cl_abap_char_utilities=>horizontal_tab.

    DATA mo_src TYPE REF TO zif_rak_cj_text_src.

    METHODS esc
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(rv_out) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_CJ_TXT_IO IMPLEMENTATION.


  METHOD constructor.
    IF io_src IS BOUND.
      mo_src = io_src.
    ELSE.
      mo_src = NEW zcl_rak_cj_text_src_cfg( ).
    ENDIF.
  ENDMETHOD.


  METHOD esc.
    rv_out = replace( val = iv_in sub = c_tab with = ` ` occ = 0 ).
    rv_out = replace( val = rv_out sub = cl_abap_char_utilities=>cr_lf with = ` ` occ = 0 ).
    rv_out = replace( val = rv_out sub = cl_abap_char_utilities=>newline with = ` ` occ = 0 ).
  ENDMETHOD.


  METHOD export.

    DATA lv_body TYPE string.

    lv_body = |JOURNEY{ c_tab }STEP{ c_tab }BLOCK{ c_tab }ELEMENT{ c_tab }KIND{ c_tab }ENGLISH{ c_tab }ARABIC|
           && cl_abap_char_utilities=>cr_lf.

    LOOP AT it_journey ASSIGNING FIELD-SYMBOL(<lv_j>).

      DATA(lt_txt) = mo_src->read_journey( <lv_j> ).

      SORT lt_txt BY step_id ASCENDING block_id ASCENDING elem_id ASCENDING.

      LOOP AT lt_txt ASSIGNING FIELD-SYMBOL(<ls_t>).
        lv_body = lv_body
               && |{ <ls_t>-journey }{ c_tab }|
               && |{ <ls_t>-step_id }{ c_tab }|
               && |{ <ls_t>-block_id }{ c_tab }|
               && |{ <ls_t>-elem_id }{ c_tab }|
               && |{ <ls_t>-txt_kind }{ c_tab }|
               && |{ esc( <ls_t>-text_en ) }{ c_tab }|
               && |{ esc( <ls_t>-text_ar ) }|
               && cl_abap_char_utilities=>cr_lf.
      ENDLOOP.

    ENDLOOP.

    DATA lv_bom TYPE xstring VALUE 'FFFE'.

    DATA(lo_conv) = cl_abap_conv_codepage=>create_out( codepage = 'UTF-16LE' ).
    DATA(lv_dat)  = lo_conv->convert( source = lv_body ).

    CONCATENATE lv_bom lv_dat INTO rv_xstr IN BYTE MODE.

  ENDMETHOD.


  METHOD import.

    DATA lt_write TYPE zif_rak_cj_text_src=>ty_t_txt.
    DATA lt_line  TYPE string_table.

    DATA(lv_in) = iv_xstr.
    IF xstrlen( lv_in ) >= 2 AND lv_in(2) = 'FFFE'.
      lv_in = lv_in+2.
    ENDIF.

    DATA(lo_conv) = cl_abap_conv_codepage=>create_in( codepage = 'UTF-16LE' ).
    DATA(lv_body) = lo_conv->convert( source = lv_in ).

    SPLIT lv_body AT cl_abap_char_utilities=>cr_lf INTO TABLE lt_line.

    DATA(lv_cur_journey) = VALUE zif_rak_cj_text_src=>ty_key( ).
    DATA lt_cur TYPE zif_rak_cj_text_src=>ty_t_txt.

    LOOP AT lt_line ASSIGNING FIELD-SYMBOL(<lv_line>) FROM 2.

      IF <lv_line> IS INITIAL.
        CONTINUE.
      ENDIF.

      SPLIT <lv_line> AT c_tab INTO TABLE DATA(lt_col).

      IF lines( lt_col ) < 7.
        APPEND VALUE #( action  = 'SKIP'
                        message = |Row { sy-tabix }: expected 7 columns, found { lines( lt_col ) }| ) TO rt_log.
        CONTINUE.
      ENDIF.

      DATA(ls_new) = VALUE zif_rak_cj_text_src=>ty_txt(
        journey  = condense( lt_col[ 1 ] )
        step_id  = condense( lt_col[ 2 ] )
        block_id = condense( lt_col[ 3 ] )
        elem_id  = condense( lt_col[ 4 ] )
        txt_kind = condense( lt_col[ 5 ] )
        text_en  = lt_col[ 6 ]
        text_ar  = lt_col[ 7 ] ).

      IF ls_new-journey <> lv_cur_journey.
        lt_cur = mo_src->read_journey( ls_new-journey ).
        lv_cur_journey = ls_new-journey.
      ENDIF.

      READ TABLE lt_cur ASSIGNING FIELD-SYMBOL(<ls_old>)
           WITH KEY step_id  = ls_new-step_id
                    block_id = ls_new-block_id
                    elem_id  = ls_new-elem_id
                    txt_kind = ls_new-txt_kind.

      IF sy-subrc <> 0.
        APPEND VALUE #( journey = ls_new-journey
                        elem_id = ls_new-elem_id
                        action  = 'REJECT'
                        new_en  = ls_new-text_en
                        new_ar  = ls_new-text_ar
                        message = |Key not present in the system, row ignored| ) TO rt_log.
        CONTINUE.
      ENDIF.

      IF <ls_old>-text_en = ls_new-text_en AND <ls_old>-text_ar = ls_new-text_ar.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( journey = ls_new-journey
                      elem_id = ls_new-elem_id
                      action  = 'CHANGE'
                      old_en  = <ls_old>-text_en
                      new_en  = ls_new-text_en
                      old_ar  = <ls_old>-text_ar
                      new_ar  = ls_new-text_ar ) TO rt_log.

      APPEND ls_new TO lt_write.

    ENDLOOP.

    IF iv_commit = abap_true AND lt_write IS NOT INITIAL.
      mo_src->write( lt_write ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
