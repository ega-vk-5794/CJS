*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_CLS
*&---------------------------------------------------------------------*
CLASS lcl_event_receiver DEFINITION.

  PUBLIC SECTION.
    METHODS:

      handle_line_drag
        FOR EVENT on_drag
        OF cl_gui_alv_tree
        IMPORTING sender node_key fieldname drag_drop_object,
      handle_fav_drop
        FOR EVENT on_drop
        OF cl_gui_alv_tree
        IMPORTING sender node_key drag_drop_object,
      handle_hotspot_click
        FOR EVENT hotspot_click
        OF cl_gui_alv_grid
        IMPORTING sender e_row_id e_column_id es_row_no,
      tree_selection_changed
        FOR EVENT selection_changed
        OF cl_gui_alv_tree
        IMPORTING sender node_key,
      hotspot_click
        FOR EVENT hotspot_click
        OF cl_gui_alv_grid
        IMPORTING sender e_row_id e_column_id es_row_no.


ENDCLASS.
CLASS lcl_editor DEFINITION.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_properties,
        exp_icon    TYPE icon-id,
        value       TYPE string,
        binding     TYPE icon-id,
        group       TYPE char30,
        handle      TYPE int4,
        name        TYPE string,
        text        TYPE string,
        fullname    TYPE string,
        sapmethod   TYPE string,
        scc_cstring TYPE string,
        library     TYPE string,
        type        TYPE string,
        cardinality TYPE string,
        color       TYPE char10,
        field_style TYPE lvc_t_styl,
      END OF ty_properties,
      tt_properties TYPE STANDARD TABLE OF ty_properties WITH DEFAULT KEY,
      BEGIN OF ty_search_category,
        node_key  TYPE lvc_nkey,
        text      TYPE string,
        fullname  TYPE string,
        sapmethod TYPE fieldname,
        prop      TYPE tt_properties,
      END OF ty_search_category,
      tt_search_category TYPE STANDARD TABLE OF ty_search_category WITH DEFAULT KEY.

    DATA: lo_controls           TYPE REF TO cl_gui_alv_tree,
          lo_editor             TYPE REF TO cl_gui_alv_tree,
          lo_category_container TYPE REF TO cl_gui_docking_container,
          lo_editor_container   TYPE REF TO cl_gui_docking_container,
          lo_property_container TYPE REF TO cl_gui_docking_container,
          lo_property_grid      TYPE REF TO cl_gui_alv_grid,
          lt_category           TYPE zcj_z2ui5_categoty_tb, "tt_category,
          lt_controls           TYPE zcj_z2ui5_controls_tb, "tt_control,
          lt_search_category    TYPE tt_search_category,
          lt_editor             TYPE tt_search_category,
          lt_prop               TYPE tt_properties,
          lc_event_receiver     TYPE REF TO lcl_event_receiver,
          lo_line_behaviour     TYPE REF TO cl_dragdrop,
          lo_fav_behaviour      TYPE REF TO cl_dragdrop.

    METHODS:
      constructor,
      init_screens,
      init_params_screens,
      on_load_json_end IMPORTING p_task TYPE clike,
      load_controls,
      load_editor,
      load_properties,
      add_editor_node IMPORTING VALUE(relat_node_key) TYPE lvc_nkey
                                VALUE(item)           TYPE ty_search_category
                                VALUE(node_text)      TYPE lvc_value
                                VALUE(item_layout)    TYPE lvc_t_layi
                                VALUE(node_layout)    TYPE lvc_s_layn,
      select_editor_node IMPORTING VALUE(node_key)    TYPE lvc_nkey,
      add_prop_items IMPORTING it_props TYPE zcj_z2ui5_properties_tb
                               iv_group TYPE string
                     CHANGING  ct_prop  TYPE tt_properties,
      property_icon_click IMPORTING e_row_id    TYPE  lvc_s_row
                                    e_column_id TYPE  lvc_s_col
                                    es_row_no   TYPE  lvc_s_roid,
      search_controls IMPORTING text TYPE any.

ENDCLASS.
CLASS lcl_editor IMPLEMENTATION.
  METHOD constructor.
    CALL FUNCTION 'ZCJ_JSON_LOADER_TAB'
      STARTING NEW TASK 'CATG'
      CALLING me->on_load_json_end ON END OF TASK
      EXPORTING
        iv_name = 'Z2UI5_CATEGORIES'.

    CALL FUNCTION 'ZCJ_JSON_LOADER_TAB'
      STARTING NEW TASK 'CONT'
      CALLING me->on_load_json_end ON END OF TASK
      EXPORTING
        iv_name = 'Z2UI5_COTNTROLS'.

  ENDMETHOD.
  METHOD on_load_json_end.
    DATA: lt_category TYPE zcj_z2ui5_categoty_tb,
          lt_controls TYPE zcj_z2ui5_controls_tb.
    RECEIVE RESULTS FROM FUNCTION 'ZCJ_JSON_LOADER_TAB'
  IMPORTING
    et_category = lt_category
    et_controls = lt_controls.
    CASE p_task.
      WHEN 'CATG'.
        me->lt_category = lt_category.
      WHEN 'CONT'.
        me->lt_controls = lt_controls.
    ENDCASE.

  ENDMETHOD.
  METHOD init_screens.
    IF lo_category_container IS INITIAL.

      DATA(lv_style) = cl_gui_control=>ws_child + cl_gui_control=>ws_thickframe + cl_gui_control=>ws_visible.
      CREATE OBJECT lo_category_container
        EXPORTING
          repid                       = sy-repid
          dynnr                       = sy-dynnr
          side                        = cl_gui_docking_container=>dock_at_left
          ratio                       = 20
          style                       = lv_style
        EXCEPTIONS
          cntl_error                  = 1
          cntl_system_error           = 2
          create_error                = 3
          lifetime_error              = 4
          lifetime_dynpro_dynpro_link = 5
          OTHERS                      = 6.


      CREATE OBJECT lo_editor_container
        EXPORTING
          repid                       = sy-repid
          dynnr                       = sy-dynnr
          side                        = cl_gui_docking_container=>dock_at_left
          ratio                       = 50
          style                       = lv_style
        EXCEPTIONS
          cntl_error                  = 1
          cntl_system_error           = 2
          create_error                = 3
          lifetime_error              = 4
          lifetime_dynpro_dynpro_link = 5
          OTHERS                      = 6.

      CREATE OBJECT me->lo_property_container
        EXPORTING
          repid                       = sy-repid
          dynnr                       = '0100'
          extension                   = 300
          side                        = cl_gui_docking_container=>dock_at_bottom
          style                       = lv_style
        EXCEPTIONS
          cntl_error                  = 1
          cntl_system_error           = 2
          create_error                = 3
          lifetime_error              = 4
          lifetime_dynpro_dynpro_link = 5
          OTHERS                      = 6.

      DATA: effect TYPE i.

      CREATE OBJECT me->lo_line_behaviour.
      effect = cl_dragdrop=>copy.
      CALL METHOD me->lo_line_behaviour->add
        EXPORTING
          flavor     = 'favorit'                  "#EC NOTEXT
          dragsrc    = 'X'
          droptarget = ' '
          effect     = effect.

      CREATE OBJECT me->lo_fav_behaviour.
      effect = cl_dragdrop=>copy.
      CALL METHOD me->lo_fav_behaviour->add
        EXPORTING
          flavor     = 'favorit'                  "#EC NOTEXT
          dragsrc    = 'X'
          droptarget = 'X'
          effect     = effect.

      me->load_controls( ).
      me->load_editor( ).
      me->load_properties( ).
    ENDIF.
  ENDMETHOD.
  METHOD init_params_screens.
    IF me->lo_property_container IS INITIAL.
      DATA(lv_style) = cl_gui_control=>ws_child + cl_gui_control=>ws_thickframe + cl_gui_control=>ws_visible.


    ENDIF.
  ENDMETHOD.
  METHOD load_controls.
    DATA: lt_fcat            TYPE lvc_t_fcat,
          ls_fcat            TYPE lvc_s_fcat,
          ls_node            TYPE lvc_s_layn,
          lv_header          TYPE treev_hhdr,
          lv_toolb_ex        TYPE ui_functions,
          ls_search_category TYPE ty_search_category.

    APPEND cl_alv_tree_base=>mc_fc_load_variant     TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_save_variant     TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_print_back       TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_print_back_all   TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_calculate        TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_maintain_variant TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_current_variant  TO lv_toolb_ex.

    CREATE OBJECT me->lo_controls
      EXPORTING
        parent                      = me->lo_category_container
        node_selection_mode         = cl_gui_column_tree=>node_sel_mode_single
        item_selection              = 'X'
        no_html_header              = 'X'
        no_toolbar                  = ''
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        illegal_node_selection_mode = 5
        failed                      = 6
        illegal_column_name         = 7.

    me->lo_controls->get_registered_events( IMPORTING events = DATA(lt_events) ).
    me->lo_controls->set_registered_events( lt_events ).
    CREATE OBJECT lc_event_receiver.
    SET HANDLER lc_event_receiver->handle_line_drag FOR me->lo_controls.

    CLEAR: lt_fcat[].

* Create Fieldscat
    ls_fcat-fieldname  = 'TEXT'.
    ls_fcat-coltext    = 'Control'.
    ls_fcat-outputlen  = '40'.
    ls_fcat-no_out     = 'X'.
    APPEND ls_fcat TO lt_fcat.  CLEAR: ls_fcat.

    lv_header-heading   = 'Objects'.
    lv_header-width     = 200.


    CALL METHOD me->lo_controls->set_table_for_first_display
      EXPORTING
        is_hierarchy_header  = lv_header
        it_toolbar_excluding = lv_toolb_ex
      CHANGING
        it_outtab            = me->lt_search_category
        it_fieldcatalog      = lt_fcat[].

    CLEAR: me->lt_search_category[].

    LOOP AT me->lt_category ASSIGNING FIELD-SYMBOL(<ls_category>).
      <ls_category>-text = <ls_category>-category.
      MOVE-CORRESPONDING <ls_category> TO ls_search_category.
      CALL METHOD me->lo_controls->add_node
        EXPORTING
          i_relat_node_key = ''
          i_relationship   = cl_gui_column_tree=>relat_last_child
          i_node_text      = CONV #( <ls_category>-text )
          is_outtab_line   = ls_search_category
        IMPORTING
          e_new_node_key   = <ls_category>-id.
      LOOP AT <ls_category>-libraries ASSIGNING FIELD-SYMBOL(<ls_library>).
        MOVE-CORRESPONDING <ls_library> TO ls_search_category.
        ls_search_category-text = <ls_library>-library.
        CALL METHOD me->lo_controls->add_node
          EXPORTING
            i_relat_node_key = <ls_category>-id
            i_relationship   = cl_gui_column_tree=>relat_last_child
            i_node_text      = CONV #( <ls_library>-library )
            is_outtab_line   = ls_search_category
          IMPORTING
            e_new_node_key   = <ls_library>-id.
        LOOP AT <ls_library>-controls ASSIGNING FIELD-SYMBOL(<ls_control>).
          MOVE-CORRESPONDING <ls_control> TO ls_search_category.
          ls_node-n_image   = icon_layout_control.
          ls_node-exp_image = icon_layout_control.
          me->lo_line_behaviour->get_handle( IMPORTING handle = DATA(dnd_handle) ).
          ls_node-dragdropid = dnd_handle.
          CALL METHOD me->lo_controls->add_node
            EXPORTING
              i_relat_node_key = <ls_library>-id
              i_relationship   = cl_gui_column_tree=>relat_last_child
              i_node_text      = CONV #( <ls_control>-text )
              is_outtab_line   = ls_search_category
              is_node_layout   = ls_node
            IMPORTING
              e_new_node_key   = <ls_control>-id.
          LOOP AT <ls_control>-aggregations ASSIGNING FIELD-SYMBOL(<ls_aggr>).
            MOVE-CORRESPONDING <ls_aggr> TO ls_search_category.
            ls_node-n_image   = icon_wd_context.
            ls_node-exp_image = icon_wd_context.
            me->lo_line_behaviour->get_handle( IMPORTING handle = dnd_handle ).
            ls_node-dragdropid = dnd_handle.
            CALL METHOD me->lo_controls->add_node
              EXPORTING
                i_relat_node_key = <ls_control>-id
                i_relationship   = cl_gui_column_tree=>relat_last_child
                i_node_text      = CONV #( <ls_aggr>-text )
                is_outtab_line   = ls_search_category
                is_node_layout   = ls_node
              IMPORTING
                e_new_node_key   = <ls_aggr>-id.
          ENDLOOP.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    me->lo_controls->frontend_update( ).

    cl_gui_cfw=>flush( ).


  ENDMETHOD.
  METHOD load_editor.

    DATA: lt_fcat     TYPE lvc_t_fcat,
          ls_fcat     TYPE lvc_s_fcat,
          ls_node     TYPE lvc_s_layn,
          lv_header   TYPE treev_hhdr,
          lv_toolb_ex TYPE ui_functions,
          ls_editor   TYPE ty_search_category,
          lt_events   TYPE cntl_simple_events,
          l_event     TYPE cntl_simple_event.

    APPEND cl_alv_tree_base=>mc_fc_load_variant     TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_save_variant     TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_print_back       TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_print_back_all   TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_calculate        TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_maintain_variant TO lv_toolb_ex.
    APPEND cl_alv_tree_base=>mc_fc_current_variant  TO lv_toolb_ex.

    CREATE OBJECT me->lo_editor
      EXPORTING
        parent                      = me->lo_editor_container
        node_selection_mode         = cl_gui_column_tree=>node_sel_mode_single
        item_selection              = ''
        no_html_header              = 'X'
        no_toolbar                  = ''
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        illegal_node_selection_mode = 5
        failed                      = 6
        illegal_column_name         = 7.

    CLEAR lt_events[].

* Get existing events
    CALL METHOD me->lo_editor->get_registered_events
      IMPORTING
        events = lt_events.

* Change selection
    l_event-eventid    = cl_gui_column_tree=>eventid_selection_changed.
    l_event-appl_event = 'X'.
    APPEND l_event TO lt_events.
    CLEAR l_event.

* Context Menu - Request
    l_event-eventid    = cl_gui_column_tree=>eventid_node_context_menu_req.
    l_event-appl_event = 'X'.
    APPEND l_event TO lt_events.
    CLEAR l_event.

* PressKey
    l_event-eventid    = cl_gui_column_tree=>eventid_node_keypress.
    l_event-appl_event = 'X'.
    APPEND l_event TO lt_events.
    CLEAR l_event.

* register events
    CALL METHOD me->lo_editor->set_registered_events
      EXPORTING
        events                    = lt_events
      EXCEPTIONS
        cntl_error                = 1
        cntl_system_error         = 2
        illegal_event_combination = 3.

    CREATE OBJECT lc_event_receiver.
    SET HANDLER lc_event_receiver->handle_fav_drop FOR me->lo_editor.
    SET HANDLER lc_event_receiver->handle_line_drag FOR me->lo_editor.
    SET HANDLER lc_event_receiver->tree_selection_changed FOR  me->lo_editor.

    CLEAR: lt_fcat[].

* Create Fieldscat
    ls_fcat-fieldname  = 'TEXT'.
    ls_fcat-coltext    = 'Control'.
    ls_fcat-outputlen  = '40'.
    ls_fcat-no_out     = 'X'.
    APPEND ls_fcat TO lt_fcat.  CLEAR: ls_fcat.

    lv_header-heading   = 'Objects'.
    lv_header-width     = 200.


    CALL METHOD me->lo_editor->set_table_for_first_display
      EXPORTING
        is_hierarchy_header  = lv_header
        it_toolbar_excluding = lv_toolb_ex
      CHANGING
        it_outtab            = me->lt_editor
        it_fieldcatalog      = lt_fcat[].

    me->lo_fav_behaviour->get_handle( IMPORTING handle = DATA(dnd_handle) ).
    ls_node-dragdropid = dnd_handle.
    CALL METHOD me->lo_editor->add_node
      EXPORTING
        i_relat_node_key = ''
        i_relationship   = cl_gui_column_tree=>relat_last_child
        i_node_text      = 'Root'
        is_outtab_line   = ls_editor
        is_node_layout   = ls_node.

    me->lo_editor->frontend_update( ).

    me->lo_editor->add_key_stroke( cl_tree_control_base=>key_delete ).
    me->lo_editor->add_key_stroke( cl_tree_control_base=>key_copy ).
    me->lo_editor->add_key_stroke( cl_tree_control_base=>key_paste ).
    me->lo_editor->add_key_stroke( cl_tree_control_base=>key_cut ).
    me->lo_editor->add_key_stroke( cl_tree_control_base=>key_enter ).


    cl_gui_cfw=>flush( ).
  ENDMETHOD.
  METHOD load_properties.

    DATA: ls_layout   TYPE lvc_s_layo,
          lt_fcat     TYPE lvc_t_fcat,
          ls_fcat     TYPE lvc_s_fcat,
          lt_dropdown TYPE lvc_t_drop,
          ls_dropdown TYPE lvc_s_drop.

    CREATE OBJECT me->lo_property_grid
      EXPORTING
        i_parent          = me->lo_property_container
      EXCEPTIONS
        error_cntl_create = 1
        error_cntl_init   = 2
        error_cntl_link   = 3
        error_dp_create   = 4.

    ls_layout-grid_title = 'Attributes'.
    ls_layout-smalltitle = 'X'.
    ls_layout-no_rowmark = 'X'.
    ls_layout-sel_mode   = 'B'.
    ls_layout-info_fname = 'COLOR'.
    ls_layout-no_headers = 'X'.
    ls_layout-no_rowmove = 'X'.
    ls_layout-no_rowins  = 'X'.
    ls_layout-stylefname = 'FIELD_STYLE'.
    ls_layout-cwidth_opt = 'X'.
    ls_layout-no_toolbar = 'X'.

    ls_fcat-fieldname  = 'EXP_ICON'.
    ls_fcat-outputlen  = '2'.
    ls_fcat-icon       = 'X'.
    ls_fcat-emphasize  = 'C30'.
    ls_fcat-hotspot    = 'X'.
    APPEND ls_fcat TO lt_fcat.  CLEAR  ls_fcat.

    ls_fcat-fieldname  = 'NAME'.
    ls_fcat-outputlen  = '30'.
    ls_fcat-emphasize  = 'C21'.
    APPEND ls_fcat TO lt_fcat.  CLEAR  ls_fcat.

    ls_fcat-fieldname  = 'VALUE'.
    ls_fcat-drdn_field = 'HANDLE'.
    ls_fcat-edit       = 'X'.
    ls_fcat-outputlen  = '30'.
    ls_fcat-ref_table  = 'ZCJ_Z2UI5_PROPERTIES'.
    ls_fcat-ref_field  = 'NAME'.
    ls_fcat-lowercase  = 'X'.
    APPEND ls_fcat TO lt_fcat.  CLEAR  ls_fcat.

    ls_fcat-fieldname  = 'BINDING'.
    ls_fcat-outputlen  = '4'.
    ls_fcat-icon       = 'X'.
    ls_fcat-hotspot    = 'X'.
    APPEND ls_fcat TO lt_fcat.  CLEAR  ls_fcat.

    ls_dropdown-handle = '1'.
    ls_dropdown-value  = space.
    APPEND ls_dropdown TO lt_dropdown. CLEAR  ls_dropdown.
    ls_dropdown-handle = '1'.
    ls_dropdown-value  = 'true'.
    APPEND ls_dropdown TO lt_dropdown. CLEAR  ls_dropdown.
    ls_dropdown-handle = '1'.
    ls_dropdown-value  = 'false'.
    APPEND ls_dropdown TO lt_dropdown. CLEAR  ls_dropdown.

    CALL METHOD me->lo_property_grid->set_drop_down_table
      EXPORTING
        it_drop_down = lt_dropdown.

* Show table
    CALL METHOD me->lo_property_grid->set_table_for_first_display
      EXPORTING
        is_layout       = ls_layout
      CHANGING
        it_fieldcatalog = lt_fcat[]
        it_outtab       = me->lt_prop.

    SET HANDLER lc_event_receiver->hotspot_click FOR me->lo_property_grid.
  ENDMETHOD.
  METHOD add_editor_node.
    me->lo_fav_behaviour->get_handle( IMPORTING handle = DATA(dnd_handle) ).
    node_layout-dragdropid = dnd_handle.
    CLEAR: node_layout-isfolder, node_layout-expander.
    me->lo_editor->add_node(
      EXPORTING
        i_relat_node_key = relat_node_key
        i_relationship   = cl_gui_column_tree=>relat_last_child
        i_node_text      = node_text
        is_outtab_line   = item
        is_node_layout   = node_layout
        it_item_layout   = item_layout
      IMPORTING
        e_new_node_key = DATA(lv_node_key) ).

    READ TABLE me->lt_editor ASSIGNING FIELD-SYMBOL(<editor>) INDEX lines( me->lt_editor ).
    IF sy-subrc EQ 0.
      <editor>-node_key = lv_node_key.
    ENDIF.

    me->lo_editor->frontend_update( ).
    CALL METHOD cl_gui_cfw=>flush.
  ENDMETHOD.
  METHOD select_editor_node.

    READ TABLE me->lt_editor INTO DATA(ls_editor) WITH KEY node_key = node_key.
    IF sy-subrc EQ 0.
      READ TABLE me->lt_controls INTO DATA(ls_control)
      WITH KEY fullname = ls_editor-fullname BINARY SEARCH.
      IF sy-subrc EQ 0.
        IF ls_editor-prop[] IS INITIAL.
          CLEAR: me->lt_prop[].
          me->add_prop_items( EXPORTING it_props = ls_control-events iv_group = 'Events' CHANGING ct_prop = me->lt_prop[] ).
          me->add_prop_items( EXPORTING it_props = ls_control-properties iv_group = 'Properties' CHANGING ct_prop = me->lt_prop[] ).
          me->add_prop_items( EXPORTING it_props = ls_control-aggregations iv_group = 'Aggregations' CHANGING ct_prop = me->lt_prop[] ).
          me->add_prop_items( EXPORTING it_props = ls_control-associations iv_group = 'Associations' CHANGING ct_prop = me->lt_prop[] ).
        ELSE.
          me->lt_prop[] = ls_editor-prop[].
        ENDIF.
        IF me->lo_property_grid IS NOT INITIAL.
          me->lo_property_grid->refresh_table_display( ).
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD add_prop_items.
    DATA: ls_style TYPE lvc_s_styl.


    APPEND INITIAL LINE TO ct_prop ASSIGNING FIELD-SYMBOL(<prop>).
    <prop>-exp_icon = icon_collapse.
    <prop>-name     = iv_group.
    <prop>-color    = 'C30'.
    ls_style-style  = cl_gui_alv_grid=>mc_style_disabled.
    APPEND ls_style  TO <prop>-field_style.
    CLEAR ls_style.
    LOOP AT it_props INTO DATA(ls_prop).
      APPEND INITIAL LINE TO ct_prop ASSIGNING <prop>.
      MOVE-CORRESPONDING ls_prop TO <prop>.
      <prop>-group   = iv_group.
      IF iv_group EQ 'Events'.
        <prop>-binding = icon_operation.
      ELSE.
        <prop>-binding = icon_connect.
      ENDIF.
      IF ls_prop-type EQ 'boolean'.
        <prop>-handle = '1'.

      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD property_icon_click.
    READ TABLE me->lt_prop[] ASSIGNING FIELD-SYMBOL(<ls_prop>) INDEX e_row_id-index.
    CHECK sy-subrc EQ 0.
    CASE e_column_id-fieldname.
      WHEN 'EXP_ICON'.
        IF <ls_prop>-exp_icon IS NOT INITIAL.
          me->lo_property_grid->check_changed_data( ).
          me->lo_property_grid->get_filter_criteria( IMPORTING et_filter = DATA(lt_filter) ).
          IF <ls_prop>-exp_icon EQ icon_collapse.
            <ls_prop>-exp_icon = icon_expand.
            APPEND INITIAL LINE TO lt_filter ASSIGNING FIELD-SYMBOL(<filter>).
            <filter>-fieldname = 'GROUP'.
            <filter>-sign      = 'E'.
            <filter>-option    = 'EQ'.
            <filter>-low       = <ls_prop>-name.
          ELSE.
            DELETE lt_filter WHERE low EQ <ls_prop>-name.
            <ls_prop>-exp_icon = icon_collapse.
          ENDIF.
          me->lo_property_grid->set_filter_criteria( lt_filter ).
          me->lo_property_grid->refresh_table_display( ).
        ENDIF.
      WHEN 'BINDING'.
    ENDCASE.
  ENDMETHOD.
  METHOD search_controls.
*    DATA: lv_search TYPE string.
*    lv_search = '*' && text && '*'.
*    me->lo_controls->get_selected_node( IMPORTING node_key = DATA(node_key) ).
*    READ TABLE me->lt_search_category INTO DATA(ls_search) WITH KEY id = node_key.
*    IF sy-subrc EQ 0.
*      DATA(lv_tabix) = sy-tabix.
*      ADD 1 TO lv_tabix.
*    ENDIF.
*    DO 2 TIMES.
*      DATA(lv_found) = abap_false.
*      LOOP AT me->lt_search_category INTO ls_search FROM lv_tabix.
*        IF ls_search-text CP lv_search.
**          OR ls_search-fullname CP lv_search
**          OR ls_search-sapmethod CP lv_search.
*          node_key = ls_search-id.
*          me->lo_controls->set_selected_node( node_key ).
*          lv_found = abap_true.
*          EXIT.
*        ENDIF.
*      ENDLOOP.
*      IF lv_found EQ abap_false.
*        CLEAR: lv_tabix.
*      ENDIF.
*
*    ENDDO.

  ENDMETHOD.
ENDCLASS.
