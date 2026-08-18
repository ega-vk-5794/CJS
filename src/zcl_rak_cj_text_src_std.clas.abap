"! <p>Adapter onto the existing CJS text store.</p>
"! <p>This is the only class that knows the physical table. Set the
"! constants in the CONFIGURATION block to match your table, then never
"! touch it again. Two shapes are supported:</p>
"! <p>c_mode = 'C' — one row per element, EN and AR in separate columns.</p>
"! <p>c_mode = 'R' — one row per element per language, keyed by a
"! language field holding SPRAS values.</p>
CLASS zcl_rak_cj_text_src_std DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_rak_cj_text_src.

  PRIVATE SECTION.

    CONSTANTS c_mode TYPE c LENGTH 1 VALUE 'C'.

    CONSTANTS c_tab TYPE string VALUE 'ZRAK_CJ_TXT'.

    CONSTANTS c_f_journey TYPE string VALUE 'JOURNEY'.
    CONSTANTS c_f_step    TYPE string VALUE 'STEP_ID'.
    CONSTANTS c_f_block   TYPE string VALUE 'BLOCK_ID'.
    CONSTANTS c_f_elem    TYPE string VALUE 'ELEM_ID'.
    CONSTANTS c_f_kind    TYPE string VALUE 'TXT_KIND'.

    CONSTANTS c_f_en   TYPE string VALUE 'TEXT_EN'.
    CONSTANTS c_f_ar   TYPE string VALUE 'TEXT_AR'.

    CONSTANTS c_f_lang TYPE string VALUE 'SPRAS'.
    CONSTANTS c_f_text TYPE string VALUE 'TEXT'.

    CONSTANTS c_lang_en TYPE sy-langu VALUE 'E'.
    CONSTANTS c_lang_ar TYPE sy-langu VALUE 'A'.

    METHODS tab_ok
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS sel_list
      RETURNING VALUE(rt_sel) TYPE string_table.

    METHODS comp
      IMPORTING is_line       TYPE any
                iv_name       TYPE string
      RETURNING VALUE(rv_val) TYPE string.

    METHODS set_comp
      IMPORTING iv_name  TYPE string
                iv_val   TYPE string
      CHANGING  cs_line  TYPE any.

ENDCLASS.



CLASS ZCL_RAK_CJ_TEXT_SRC_STD IMPLEMENTATION.


  METHOD comp.
    FIELD-SYMBOLS <lv_any> TYPE any.
    CLEAR rv_val.
    IF iv_name IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT iv_name OF STRUCTURE is_line TO <lv_any>.
    IF sy-subrc = 0.
      rv_val = |{ <lv_any> }|.
    ENDIF.
  ENDMETHOD.


  METHOD sel_list.
    APPEND c_f_journey TO rt_sel.
    APPEND c_f_step    TO rt_sel.
    APPEND c_f_block   TO rt_sel.
    APPEND c_f_elem    TO rt_sel.
    IF c_f_kind IS NOT INITIAL.
      APPEND c_f_kind TO rt_sel.
    ENDIF.
    IF c_mode = 'C'.
      APPEND c_f_en TO rt_sel.
      APPEND c_f_ar TO rt_sel.
    ELSE.
      APPEND c_f_lang TO rt_sel.
      APPEND c_f_text TO rt_sel.
    ENDIF.
  ENDMETHOD.


  METHOD set_comp.
    FIELD-SYMBOLS <lv_any> TYPE any.
    IF iv_name IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT iv_name OF STRUCTURE cs_line TO <lv_any>.
    IF sy-subrc = 0.
      <lv_any> = iv_val.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_cj_text_src~list_journeys.

    DATA lr_tab TYPE REF TO data.

    FIELD-SYMBOLS <lt_raw> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_raw> TYPE any.

    IF tab_ok( ) = abap_false.
      MESSAGE |Text table { c_tab } does not exist. Set c_tab in ZCL_RAK_CJ_TEXT_SRC_STD.| TYPE 'I'.
      RETURN.
    ENDIF.

    DATA(lv_tab) = c_tab.
    DATA(lv_fld) = c_f_journey.

    CREATE DATA lr_tab TYPE STANDARD TABLE OF (c_tab).
    ASSIGN lr_tab->* TO <lt_raw>.

    SELECT DISTINCT (lv_fld) FROM (lv_tab)
      ORDER BY (lv_fld)
      INTO CORRESPONDING FIELDS OF TABLE @<lt_raw>.

    LOOP AT <lt_raw> ASSIGNING <ls_raw>.
      APPEND CONV zif_rak_cj_text_src=>ty_key( comp( is_line = <ls_raw>
                                                     iv_name = c_f_journey ) ) TO rt_journey.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_cj_text_src~read_journey.

    DATA lr_tab TYPE REF TO data.

    FIELD-SYMBOLS <lt_raw> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_raw> TYPE any.

    IF tab_ok( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_tab) = c_tab.
    DATA(lt_sel) = sel_list( ).
    DATA(lv_wh)  = |{ c_f_journey } = { cl_abap_dyn_prg=>quote( CONV string( iv_journey ) ) }|.

    CREATE DATA lr_tab TYPE STANDARD TABLE OF (c_tab).
    ASSIGN lr_tab->* TO <lt_raw>.

    SELECT (lt_sel) FROM (lv_tab)
      WHERE (lv_wh)
      INTO CORRESPONDING FIELDS OF TABLE @<lt_raw>.

    LOOP AT <lt_raw> ASSIGNING <ls_raw>.

      DATA(ls_key) = VALUE zif_rak_cj_text_src=>ty_txt(
        journey  = comp( is_line = <ls_raw> iv_name = c_f_journey )
        step_id  = comp( is_line = <ls_raw> iv_name = c_f_step )
        block_id = comp( is_line = <ls_raw> iv_name = c_f_block )
        elem_id  = comp( is_line = <ls_raw> iv_name = c_f_elem )
        txt_kind = comp( is_line = <ls_raw> iv_name = c_f_kind ) ).

      IF c_mode = 'C'.

        ls_key-text_en = comp( is_line = <ls_raw> iv_name = c_f_en ).
        ls_key-text_ar = comp( is_line = <ls_raw> iv_name = c_f_ar ).
        APPEND ls_key TO rt_txt.

      ELSE.

        DATA(lv_lang) = comp( is_line = <ls_raw> iv_name = c_f_lang ).
        DATA(lv_text) = comp( is_line = <ls_raw> iv_name = c_f_text ).

        READ TABLE rt_txt ASSIGNING FIELD-SYMBOL(<ls_out>)
             WITH KEY journey  = ls_key-journey
                      step_id  = ls_key-step_id
                      block_id = ls_key-block_id
                      elem_id  = ls_key-elem_id
                      txt_kind = ls_key-txt_kind.
        IF sy-subrc <> 0.
          APPEND ls_key TO rt_txt ASSIGNING <ls_out>.
        ENDIF.

        IF lv_lang = c_lang_ar.
          <ls_out>-text_ar = lv_text.
        ELSE.
          <ls_out>-text_en = lv_text.
        ENDIF.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_cj_text_src~write.

    DATA lr_line TYPE REF TO data.

    FIELD-SYMBOLS <ls_line> TYPE any.

    IF tab_ok( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_tab) = c_tab.

    CREATE DATA lr_line TYPE (c_tab).
    ASSIGN lr_line->* TO <ls_line>.

    LOOP AT it_txt ASSIGNING FIELD-SYMBOL(<ls_txt>).

      CLEAR <ls_line>.
      set_comp( EXPORTING iv_name = c_f_journey iv_val = CONV #( <ls_txt>-journey )  CHANGING cs_line = <ls_line> ).
      set_comp( EXPORTING iv_name = c_f_step    iv_val = CONV #( <ls_txt>-step_id )  CHANGING cs_line = <ls_line> ).
      set_comp( EXPORTING iv_name = c_f_block   iv_val = CONV #( <ls_txt>-block_id ) CHANGING cs_line = <ls_line> ).
      set_comp( EXPORTING iv_name = c_f_elem    iv_val = CONV #( <ls_txt>-elem_id )  CHANGING cs_line = <ls_line> ).
      set_comp( EXPORTING iv_name = c_f_kind    iv_val = CONV #( <ls_txt>-txt_kind ) CHANGING cs_line = <ls_line> ).

      IF c_mode = 'C'.

        set_comp( EXPORTING iv_name = c_f_en iv_val = <ls_txt>-text_en CHANGING cs_line = <ls_line> ).
        set_comp( EXPORTING iv_name = c_f_ar iv_val = <ls_txt>-text_ar CHANGING cs_line = <ls_line> ).
        MODIFY (lv_tab) FROM <ls_line>.

      ELSE.

        set_comp( EXPORTING iv_name = c_f_lang iv_val = CONV #( c_lang_en ) CHANGING cs_line = <ls_line> ).
        set_comp( EXPORTING iv_name = c_f_text iv_val = <ls_txt>-text_en    CHANGING cs_line = <ls_line> ).
        MODIFY (lv_tab) FROM <ls_line>.

        set_comp( EXPORTING iv_name = c_f_lang iv_val = CONV #( c_lang_ar ) CHANGING cs_line = <ls_line> ).
        set_comp( EXPORTING iv_name = c_f_text iv_val = <ls_txt>-text_ar    CHANGING cs_line = <ls_line> ).
        MODIFY (lv_tab) FROM <ls_line>.

      ENDIF.

    ENDLOOP.

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD tab_ok.

    DATA lo_descr TYPE REF TO cl_abap_typedescr.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING  p_name         = CONV string( c_tab )
      RECEIVING  p_descr_ref    = lo_descr
      EXCEPTIONS type_not_found = 1
                 OTHERS         = 2 ).

    rv_ok = xsdbool( sy-subrc = 0 AND lo_descr IS BOUND ).

  ENDMETHOD.
ENDCLASS.
