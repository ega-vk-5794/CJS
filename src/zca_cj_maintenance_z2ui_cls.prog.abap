*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_CLS
*&---------------------------------------------------------------------*

CLASS lcl_editor DEFINITION.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_controls,
             id        TYPE numc10,
             text      TYPE string,
             fullname  TYPE string,
             sapmethod TYPE fieldname,
           END OF ty_controls,
           tt_controls TYPE STANDARD TABLE OF ty_controls WITH DEFAULT KEY,
           BEGIN OF ty_category,
             id       TYPE numc10,
             category TYPE string,
             controls TYPE tt_controls,
           END OF ty_category,
           tt_category TYPE STANDARD TABLE OF ty_category WITH DEFAULT KEY.

    DATA: lo_controls           TYPE REF TO cl_gui_simple_tree,
          lo_category_container TYPE REF TO cl_gui_docking_container,
          lo_editor_container   TYPE REF TO cl_gui_docking_container,
          lo_property_container TYPE REF TO cl_gui_docking_container,
          lt_category           TYPE tt_category.

    METHODS:
      constructor,
      load_json IMPORTING name TYPE wwwparams-objid
                CHANGING  data TYPE any,
      load_controls.

ENDCLASS.
CLASS lcl_editor IMPLEMENTATION.
  METHOD constructor.

    CREATE OBJECT lo_category_container
      EXPORTING
        repid                       = sy-repid             " Current Program ID
        dynnr                       = sy-dynnr             " Screen/Dynpro Number (e.g., '1000' for Selection Screens)
        side                        = cl_gui_docking_container=>dock_at_left " Dock Position: LEFT, RIGHT, TOP, or BOTTOM
        extension                   = 300                  " Width or height of the container in pixels
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.


    CREATE OBJECT lo_property_container
      EXPORTING
        repid                       = sy-repid             " Current Program ID
        dynnr                       = sy-dynnr             " Screen/Dynpro Number (e.g., '1000' for Selection Screens)
        side                        = cl_gui_docking_container=>dock_at_right " Dock Position: LEFT, RIGHT, TOP, or BOTTOM
        extension                   = 300                  " Width or height of the container in pixels
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.

    me->load_controls( ).
  ENDMETHOD.
  METHOD load_controls.
    DATA: node        TYPE zcj_mtreesnode,
          nodes       TYPE zcj_mtreesnode_tab,
          lv_category TYPE numc10,
          lv_control  TYPE numc10,
          lv_id       TYPE numc10.

    me->load_json( EXPORTING name = 'Z2UI5_CATEGORIES' CHANGING data = me->lt_category ).


    node-node_key = 'Root'.
    node-isfolder = 'X'.
    node-text     = 'Controls'.
    APPEND node TO nodes. CLEAR: node.

    LOOP AT me->lt_category ASSIGNING FIELD-SYMBOL(<ls_category>).
      ADD 1 TO lv_id.
      <ls_category>-id = lv_id.
      node-node_key   = <ls_category>-id.
      node-relatkey   = 'Root'.
      node-relatship  = cl_gui_simple_tree=>relat_last_child.
      node-text       = <ls_category>-category.
      node-isfolder   = 'X'.
      APPEND node TO nodes. CLEAR: node.
      LOOP AT <ls_category>-controls ASSIGNING FIELD-SYMBOL(<ls_control>).
        ADD 1 TO lv_id.
        <ls_control>-id = lv_id.
        node-node_key   = <ls_control>-id.
        node-relatkey   = <ls_category>-id.
        node-relatship  = cl_gui_simple_tree=>relat_last_child.
        node-text       = <ls_control>-text.
        node-isfolder   = ''.
        APPEND node TO nodes. CLEAR: node.
      ENDLOOP.
    ENDLOOP.

    CREATE OBJECT me->lo_controls
      EXPORTING
        parent                      = me->lo_category_container
        node_selection_mode         = cl_simple_tree_model=>node_sel_mode_single
      EXCEPTIONS
        illegal_node_selection_mode = 1.

    CALL METHOD me->lo_controls->add_nodes
      EXPORTING
        table_structure_name = 'ZCJ_MTREESNODE'
        node_table           = nodes
      EXCEPTIONS
        error_in_node_table  = 1
        OTHERS               = 2.

    SET HANDLER lcl_event_receiver=>handle_tree_drag FOR me->lo_controls.
    SET HANDLER lcl_event_receiver=>handle_tree_drop_complete FOR me->lo_controls.

    cl_gui_cfw=>flush( ).


  ENDMETHOD.
  METHOD load_json.

    DATA: lv_size_txt TYPE soli-line,
          ls_key      TYPE wwwdatatab,
          lv_len      TYPE i,
          lt_file     TYPE w3html_tab,
          lv_json     TYPE string.

    CALL FUNCTION 'WWWPARAMS_READ'
      EXPORTING
        relid            = 'HT'
        objid            = name
        name             = 'filesize'
      IMPORTING
        value            = lv_size_txt
      EXCEPTIONS
        entry_not_exists = 1
        OTHERS           = 2.
    IF sy-subrc EQ 0.
      ls_key-relid = 'HT'.
      ls_key-objid = name.
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
*         jsonx            =
*         pretty_name      = PRETTY_MODE-NONE
*         assoc_arrays     = C_BOOL-FALSE
*         assoc_arrays_opt = C_BOOL-FALSE
*         name_mappings    =
*         conversion_exits = C_BOOL-FALSE
*         hex_as_base64    = C_BOOL-TRUE
        CHANGING
          data = data.

    ENDIF.
  ENDMETHOD.
ENDCLASS.
