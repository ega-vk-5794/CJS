CLASS zcl_rak_cj_txt_qa DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_key TYPE c LENGTH 30.

    TYPES: BEGIN OF ty_find,
             journey  TYPE ty_key,
             step_id  TYPE ty_key,
             block_id TYPE ty_key,
             elem_id  TYPE ty_key,
             txt_kind TYPE c LENGTH 10,
             sev      TYPE c LENGTH 1,
             code     TYPE c LENGTH 12,
             message  TYPE string,
             text_en  TYPE string,
             text_ar  TYPE string,
           END OF ty_find.

    TYPES ty_t_find TYPE STANDARD TABLE OF ty_find WITH EMPTY KEY.

    TYPES: BEGIN OF ty_stat,
             journey  TYPE ty_key,
             elements TYPE i,
             miss_en  TYPE i,
             miss_ar  TYPE i,
             errors   TYPE i,
             warnings TYPE i,
             pct_done TYPE p LENGTH 5 DECIMALS 1,
           END OF ty_stat.

    TYPES ty_t_stat TYPE STANDARD TABLE OF ty_stat WITH EMPTY KEY.

    CONSTANTS: BEGIN OF c_sev,
                 error   TYPE c LENGTH 1 VALUE 'E',
                 warning TYPE c LENGTH 1 VALUE 'W',
                 info    TYPE c LENGTH 1 VALUE 'I',
               END OF c_sev.

    CONSTANTS: BEGIN OF c_code,
                 miss_en    TYPE c LENGTH 12 VALUE 'MISSING_EN',
                 miss_ar    TYPE c LENGTH 12 VALUE 'MISSING_AR',
                 technical  TYPE c LENGTH 12 VALUE 'TECHNICAL',
                 untransl   TYPE c LENGTH 12 VALUE 'UNTRANSLATED',
                 latin_ar   TYPE c LENGTH 12 VALUE 'LATIN_IN_AR',
                 arabic_en  TYPE c LENGTH 12 VALUE 'ARABIC_IN_EN',
                 placehold  TYPE c LENGTH 12 VALUE 'PLACEHOLDER',
                 whitespace TYPE c LENGTH 12 VALUE 'WHITESPACE',
                 length     TYPE c LENGTH 12 VALUE 'LENGTH_RISK',
                 duplicate  TYPE c LENGTH 12 VALUE 'DUPLICATE',
               END OF c_code.

    METHODS constructor
      IMPORTING io_src TYPE REF TO zif_rak_cj_text_src OPTIONAL.

    METHODS available_journeys
      RETURNING VALUE(rt_journey) TYPE zif_rak_cj_text_src=>ty_t_journey.

    METHODS scan
      IMPORTING it_journey     TYPE zif_rak_cj_text_src=>ty_t_journey OPTIONAL
      RETURNING VALUE(rt_find) TYPE ty_t_find.

    METHODS summarise
      IMPORTING it_journey     TYPE zif_rak_cj_text_src=>ty_t_journey OPTIONAL
      RETURNING VALUE(rt_stat) TYPE ty_t_stat.

  PRIVATE SECTION.

    DATA mo_src TYPE REF TO zif_rak_cj_text_src.

    METHODS check_row
      IMPORTING is_txt         TYPE zif_rak_cj_text_src=>ty_txt
      RETURNING VALUE(rt_find) TYPE ty_t_find.

    METHODS check_block_dups
      IMPORTING it_txt         TYPE zif_rak_cj_text_src=>ty_t_txt
      RETURNING VALUE(rt_find) TYPE ty_t_find.

    METHODS add
      IMPORTING is_txt   TYPE zif_rak_cj_text_src=>ty_txt
                iv_sev   TYPE c
                iv_code  TYPE c
                iv_msg   TYPE string
      CHANGING  ct_find  TYPE ty_t_find.

    METHODS has_arabic
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    METHODS has_latin
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    METHODS looks_technical
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    METHODS ph_count
      IMPORTING iv_text     TYPE string
      RETURNING VALUE(rv_n) TYPE i.

ENDCLASS.



CLASS ZCL_RAK_CJ_TXT_QA IMPLEMENTATION.


  METHOD add.
    APPEND VALUE #( journey  = is_txt-journey
                    step_id  = is_txt-step_id
                    block_id = is_txt-block_id
                    elem_id  = is_txt-elem_id
                    txt_kind = is_txt-txt_kind
                    sev      = iv_sev
                    code     = iv_code
                    message  = iv_msg
                    text_en  = is_txt-text_en
                    text_ar  = is_txt-text_ar ) TO ct_find.
  ENDMETHOD.


  METHOD check_block_dups.

    TYPES: BEGIN OF ty_seen,
             block_id TYPE ty_key,
             text_en  TYPE string,
             elem_id  TYPE ty_key,
           END OF ty_seen.

    DATA lt_seen TYPE STANDARD TABLE OF ty_seen WITH EMPTY KEY.

    LOOP AT it_txt ASSIGNING FIELD-SYMBOL(<ls_t>) WHERE text_en IS NOT INITIAL.

      READ TABLE lt_seen ASSIGNING FIELD-SYMBOL(<ls_seen>)
           WITH KEY block_id = <ls_t>-block_id
                    text_en  = <ls_t>-text_en.

      IF sy-subrc = 0.
        add( EXPORTING is_txt  = <ls_t>
                       iv_sev  = c_sev-warning
                       iv_code = c_code-duplicate
                       iv_msg  = |Same text already used by { <ls_seen>-elem_id } in this block|
             CHANGING  ct_find = rt_find ).
      ELSE.
        APPEND VALUE #( block_id = <ls_t>-block_id
                        text_en  = <ls_t>-text_en
                        elem_id  = <ls_t>-elem_id ) TO lt_seen.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD check_row.

    DATA(lv_en) = is_txt-text_en.
    DATA(lv_ar) = is_txt-text_ar.

    IF lv_en IS INITIAL.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-error
                     iv_code = c_code-miss_en
                     iv_msg  = |No English text maintained|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_ar IS INITIAL.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-error
                     iv_code = c_code-miss_ar
                     iv_msg  = |No Arabic text maintained|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_en IS NOT INITIAL AND looks_technical( lv_en ) = abap_true.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-error
                     iv_code = c_code-technical
                     iv_msg  = |Technical field name showing as a label|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_ar IS NOT INITIAL AND has_arabic( lv_ar ) = abap_false.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-error
                     iv_code = c_code-latin_ar
                     iv_msg  = |Arabic column holds no Arabic characters|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_en IS NOT INITIAL AND lv_ar IS NOT INITIAL AND lv_en = lv_ar.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-warning
                     iv_code = c_code-untransl
                     iv_msg  = |English and Arabic are identical|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_en IS NOT INITIAL AND has_arabic( lv_en ) = abap_true AND has_latin( lv_en ) = abap_false.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-warning
                     iv_code = c_code-arabic_en
                     iv_msg  = |English column appears to hold Arabic|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF ph_count( lv_en ) <> ph_count( lv_ar ) AND lv_en IS NOT INITIAL AND lv_ar IS NOT INITIAL.
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-error
                     iv_code = c_code-placehold
                     iv_msg  = |Placeholder count differs between languages|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_en <> condense( lv_en ) OR lv_ar <> condense( lv_ar ).
      add( EXPORTING is_txt  = is_txt
                     iv_sev  = c_sev-info
                     iv_code = c_code-whitespace
                     iv_msg  = |Leading, trailing or repeated spaces|
           CHANGING  ct_find = rt_find ).
    ENDIF.

    IF lv_en IS NOT INITIAL AND lv_ar IS NOT INITIAL.
      IF strlen( lv_ar ) > 30 AND strlen( lv_ar ) * 10 > strlen( lv_en ) * 16.
        add( EXPORTING is_txt  = is_txt
                       iv_sev  = c_sev-warning
                       iv_code = c_code-length
                       iv_msg  = |Arabic much longer than English, truncation risk|
             CHANGING  ct_find = rt_find ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD constructor.
    IF io_src IS BOUND.
      mo_src = io_src.
    ELSE.
      mo_src = NEW zcl_rak_cj_text_src_cfg( ).
    ENDIF.
  ENDMETHOD.


  METHOD has_arabic.
    rv_yes = xsdbool( count( val = iv_text pcre = '\p{Arabic}' ) > 0 ).
  ENDMETHOD.


  METHOD has_latin.
    rv_yes = xsdbool( count( val = iv_text pcre = '[A-Za-z]' ) > 0 ).
  ENDMETHOD.


  METHOD looks_technical.
    rv_yes = abap_false.
    IF strlen( iv_text ) < 3.
      RETURN.
    ENDIF.
    IF matches( val = iv_text pcre = '^(ZZ|Z_|ZRAK|SAP_).*' ).
      rv_yes = abap_true.
      RETURN.
    ENDIF.
    IF matches( val = iv_text pcre = '^[A-Z][A-Z0-9_]{3,}$' ).
      rv_yes = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD ph_count.
    rv_n = count( val = iv_text pcre = '\{\d+\}' ).
  ENDMETHOD.


  METHOD scan.

    DATA(lt_journey) = it_journey.
    IF lt_journey IS INITIAL.
      lt_journey = mo_src->list_journeys( ).
    ENDIF.

    LOOP AT lt_journey ASSIGNING FIELD-SYMBOL(<lv_j>).

      DATA(lt_txt) = mo_src->read_journey( <lv_j> ).

      LOOP AT lt_txt ASSIGNING FIELD-SYMBOL(<ls_t>).
        APPEND LINES OF check_row( <ls_t> ) TO rt_find.
      ENDLOOP.

      APPEND LINES OF check_block_dups( lt_txt ) TO rt_find.

    ENDLOOP.

    SORT rt_find BY journey ASCENDING
                    sev     ASCENDING
                    step_id ASCENDING
                    block_id ASCENDING
                    elem_id ASCENDING.

  ENDMETHOD.


  METHOD summarise.

    DATA(lt_journey) = it_journey.
    IF lt_journey IS INITIAL.
      lt_journey = mo_src->list_journeys( ).
    ENDIF.

    DATA(lt_find) = scan( lt_journey ).

    LOOP AT lt_journey ASSIGNING FIELD-SYMBOL(<lv_j>).

      DATA(lt_txt) = mo_src->read_journey( <lv_j> ).

      DATA(ls_stat) = VALUE ty_stat( journey  = <lv_j>
                                     elements = lines( lt_txt ) ).

      LOOP AT lt_find ASSIGNING FIELD-SYMBOL(<ls_f>) WHERE journey = <lv_j>.
        CASE <ls_f>-code.
          WHEN c_code-miss_en.
            ls_stat-miss_en = ls_stat-miss_en + 1.
          WHEN c_code-miss_ar.
            ls_stat-miss_ar = ls_stat-miss_ar + 1.
        ENDCASE.
        CASE <ls_f>-sev.
          WHEN c_sev-error.
            ls_stat-errors = ls_stat-errors + 1.
          WHEN c_sev-warning.
            ls_stat-warnings = ls_stat-warnings + 1.
        ENDCASE.
      ENDLOOP.

      IF ls_stat-elements > 0.
        DATA(lv_ok) = ls_stat-elements * 2 - ls_stat-miss_en - ls_stat-miss_ar.
        ls_stat-pct_done = lv_ok * 100 / ( ls_stat-elements * 2 ).
      ENDIF.

      APPEND ls_stat TO rt_stat.

    ENDLOOP.

    SORT rt_stat BY pct_done ASCENDING.

  ENDMETHOD.


  METHOD available_journeys.
    rt_journey = mo_src->list_journeys( ).
  ENDMETHOD.
ENDCLASS.
