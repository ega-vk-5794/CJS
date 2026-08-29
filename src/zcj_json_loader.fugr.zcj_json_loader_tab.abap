FUNCTION zcj_json_loader_tab.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_NAME) TYPE  WWWPARAMS-OBJID OPTIONAL
*"----------------------------------------------------------------------
  DATA: lv_size_txt TYPE soli-line,
        ls_key      TYPE wwwdatatab,
        lv_len      TYPE i,
        lt_file     TYPE w3html_tab,
        lv_json     TYPE string,
        lo_parser   TYPE REF TO /ui5/cl_json_parser.

  CALL FUNCTION 'WWWPARAMS_READ'
    EXPORTING
      relid            = 'HT'
      objid            = iv_name
      name             = 'filesize'
    IMPORTING
      value            = lv_size_txt
    EXCEPTIONS
      entry_not_exists = 1
      OTHERS           = 2.
  IF sy-subrc EQ 0.
    ls_key-relid = 'HT'.
    ls_key-objid = iv_name.
    CALL FUNCTION 'WWWDATA_IMPORT'
      EXPORTING
        key               = ls_key
      TABLES
        html              = lt_file
      EXCEPTIONS
        wrong_object_type = 1
        import_error      = 2
        OTHERS            = 3.
    lv_len = lines( lt_file ) * 255.
    CALL FUNCTION 'SCMS_FTEXT_TO_STRING'
      EXPORTING
        length    = lv_len
      IMPORTING
        ftext     = lv_json
      TABLES
        ftext_tab = lt_file.
    CONDENSE lv_json.

    CREATE OBJECT lo_parser.
    lo_parser->parse( json = lv_json ).
*    DATA: lo_data TYPE REF TO data.
*
*    CALL METHOD /ui2/cl_json=>deserialize
*      EXPORTING
*        json = lv_json
*      CHANGING
*        data = lo_data.

    BREAK-POINT.

  ENDIF.
ENDFUNCTION.
