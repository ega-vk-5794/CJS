*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_EVT
*&---------------------------------------------------------------------*
CLASS lcl_event_receiver DEFINITION.

  PUBLIC SECTION.
    CLASS-METHODS:

      handle_tree_drag
        FOR EVENT on_drag
        OF cl_gui_simple_tree
        IMPORTING sender node_key drag_drop_object,

      handle_tree_drop
        FOR EVENT on_drop
        OF cl_gui_simple_tree
        IMPORTING sender node_key drag_drop_object,

      handle_tree_drop_complete
        FOR EVENT on_drop_complete
        OF cl_gui_simple_tree
        IMPORTING node_key drag_drop_object.

ENDCLASS.
CLASS lcl_dragdropdataobject DEFINITION.
  PUBLIC SECTION.
    DATA: node_key TYPE char12.
ENDCLASS.
CLASS lcl_event_receiver IMPLEMENTATION.
  METHOD handle_tree_drag.
    DATA: left_node TYPE mtreesnode,
          dataobj   TYPE REF TO lcl_dragdropdataobject.
    " get the dragged node
    CREATE OBJECT dataobj.
    dataobj->node_key = node_key.

  ENDMETHOD.
  METHOD handle_tree_drop.
    DATA: dataobj   TYPE REF TO lcl_dragdropdataobject.
    " get information about the dragged object:
    " the data object

*    CATCH SYSTEM-EXCEPTIONS move_cast_error = 1.
*      dataobj ?= drag_drop_object->object.
*    ENDCATCH.
*    IF sy-subrc = 1.
*      " data object has unexpected class
*      " => cancel Drag & Drop operation
*      CALL METHOD drag_drop_object->abort.
*      EXIT.
*    ENDIF.
*    IF dataobj->node_key IS NOT INITIAL.
**      go_builder->move_control( node_key = dataobj->node_key parent_key = node_key ).
*    ENDIF.
*    IF dataobj->control IS NOT INITIAL.
**      go_builder->add_control( control = dataobj->control node_key = node_key ).
*    ENDIF.
  ENDMETHOD.
  METHOD handle_tree_drop_complete.
  ENDMETHOD.
ENDCLASS.
