*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_EVT
*&---------------------------------------------------------------------*
CLASS lcl_dragdropdataobject DEFINITION.
  PUBLIC SECTION.
    DATA: item        TYPE lcl_editor=>ty_search_category,
          node_text   TYPE lvc_value,
          node_key    TYPE lvc_nkey,
          item_layout	TYPE lvc_t_layi,
          node_layout	TYPE lvc_s_layn.


ENDCLASS.
CLASS lcl_event_receiver IMPLEMENTATION.
  METHOD handle_line_drag.
    DATA: dataobj TYPE REF TO lcl_dragdropdataobject.
    CREATE OBJECT dataobj.
    dataobj->node_key = node_key.

    CALL METHOD sender->get_outtab_line
      EXPORTING
        i_node_key     = node_key
      IMPORTING
        e_outtab_line  = dataobj->item
        e_node_text    = dataobj->node_text
        et_item_layout = dataobj->item_layout
        es_node_layout = dataobj->node_layout.

    drag_drop_object->object = dataobj.
  ENDMETHOD.

*--------------------------------------------------------------------
  METHOD handle_fav_drop.
    DATA: dataobj   TYPE REF TO lcl_dragdropdataobject,
          l_new_key TYPE lvc_nkey.
    CATCH SYSTEM-EXCEPTIONS move_cast_error = 1.
      dataobj ?= drag_drop_object->object.
      go_editor->add_editor_node( EXPORTING
                                    relat_node_key = node_key
                                    node_text      = dataobj->node_text
                                    item           = dataobj->item
                                    item_layout    = dataobj->item_layout
                                    node_layout    = dataobj->node_layout ).

    ENDCATCH.
    CALL METHOD sender->expand_node
      EXPORTING
        i_node_key = node_key.
    IF sy-subrc <> 0.
      CALL METHOD drag_drop_object->abort.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_loader IMPLEMENTATION.
  METHOD constructor.
    mv_input = iv_data.
    GET REFERENCE OF iv_table INTO mt_table.
  ENDMETHOD.

  METHOD if_abap_parallel~do.
*    go_editor->load_json( EXPORTING name = CONV #( mv_input ) CHANGING data = mt_table ).
    DATA: lv_size_txt TYPE soli-line,
          ls_key      TYPE wwwdatatab,
          lv_len      TYPE i,
          lt_file     TYPE w3html_tab,
          lv_json     TYPE string.

    CALL FUNCTION 'WWWPARAMS_READ'
      EXPORTING
        relid            = 'HT'
        objid            = mv_input
        name             = 'filesize'
      IMPORTING
        value            = lv_size_txt
      EXCEPTIONS
        entry_not_exists = 1
        OTHERS           = 2.
    IF sy-subrc EQ 0.
      ls_key-relid = 'HT'.
      ls_key-objid = mv_input.
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

      CALL METHOD /ui2/cl_json=>deserialize
        EXPORTING
          json = lv_json
        CHANGING
          data = mt_table.
    ENDIF.
  ENDMETHOD.

  METHOD get_output.
    rv_result = mt_table.
  ENDMETHOD.
ENDCLASS.
