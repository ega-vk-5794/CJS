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
  METHOD handle_hotspot_click.
    READ TABLE gt_screens INTO DATA(ls_screen) INDEX es_row_no-row_id.
    IF sy-subrc EQ 0.
      gv_screen = ls_screen-screen.
      CALL SCREEN 100.
    ENDIF.
  ENDMETHOD.
  METHOD tree_selection_changed.
    go_editor->select_editor_node( node_key ).
  ENDMETHOD.
  METHOD hotspot_click.
    CASE sender.
      WHEN go_editor->lo_property_grid.
        go_editor->property_icon_click( EXPORTING e_row_id = e_row_id e_column_id  = e_column_id es_row_no = es_row_no ).
    ENDCASE.
  ENDMETHOD.
  METHOD data_changed.
    CASE sender.
      WHEN go_editor->lo_property_grid.
        go_editor->property_data_changed( EXPORTING er_data_changed = er_data_changed
                                                    e_onf4          = e_onf4
                                                    e_onf4_before   = e_onf4_before
                                                    e_onf4_after    = e_onf4_after
                                                    e_ucomm         = e_ucomm ).
    ENDCASE.
  ENDMETHOD.
  METHOD data_changed_finished.
    CASE sender.
      WHEN go_editor->lo_property_grid.
        go_editor->property_data_changed_finished( EXPORTING e_modified    = e_modified
                                                             et_good_cells = et_good_cells ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
