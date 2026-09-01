*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_FRM
*&---------------------------------------------------------------------*
FORM open_sm30 USING iv_view TYPE dd02v-tabname.

  DATA: lt_sellist TYPE STANDARD TABLE OF vimsellist.
  IF iv_view EQ 'ZCJ_Z2UI5_SCREEN'.
    APPEND INITIAL LINE TO lt_sellist ASSIGNING FIELD-SYMBOL(<sellist>).
    <sellist>-viewfield = 'APPL'.
    <sellist>-operator  = 'EQ'.
    <sellist>-value     = p_appl.
  ENDIF.

  CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
    EXPORTING
      action                       = 'U'
      view_name                    = iv_view
    TABLES
      dba_sellist                  = lt_sellist
    EXCEPTIONS
      client_reference             = 1
      foreign_lock                 = 2
      invalid_action               = 3
      no_clientindependent_auth    = 4
      no_database_function         = 5
      no_editor_function           = 6
      no_show_auth                 = 7
      no_tvdir_entry               = 8
      no_upd_auth                  = 9
      only_show_allowed            = 10
      system_failure               = 11
      unknown_field_in_dba_sellist = 12
      view_not_found               = 13
      maintenance_prohibited       = 14
      OTHERS                       = 15.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form pbo_screens
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM pbo_screens .

  DATA: ls_variant TYPE disvariant,
        ls_layout  TYPE lvc_s_layo,
        lt_fcat    TYPE lvc_t_fcat,
        ls_fcat    TYPE lvc_s_fcat.

  IF go_screens_cont IS INITIAL.

    PERFORM load_screens.

    go_screens_cont = NEW #( container_name = 'SCREENS' ).

    CREATE OBJECT go_screens_grid
      EXPORTING
        i_parent          = go_screens_cont
      EXCEPTIONS
        error_cntl_create = 1
        error_cntl_init   = 2
        error_cntl_link   = 3
        error_dp_create   = 4.

    ls_variant-report    = sy-repid.
    ls_layout-zebra      = 'X'.
    ls_layout-cwidth_opt = 'X'.
    ls_layout-no_toolbar = ''.
    ls_layout-sel_mode   = 'A'.
*    ls_layout-edit       = 'X'.

    ls_fcat-fieldname = 'SCREEN'.
    ls_fcat-ref_table = 'ZCJ_Z2UI5_SCREET'.
    ls_fcat-ref_field = 'SCREEN'.
    APPEND ls_fcat TO lt_fcat. CLEAR: ls_fcat.

    ls_fcat-fieldname = 'SDESCR'.
    ls_fcat-ref_table = 'ZCJ_Z2UI5_SCREET'.
    ls_fcat-ref_field = 'SDESCR'.
    APPEND ls_fcat TO lt_fcat. CLEAR: ls_fcat.

    ls_fcat-fieldname = 'ACTION'.
    ls_fcat-ref_table = 'ICON'.
    ls_fcat-ref_field = 'ID'.
    ls_fcat-hotspot   = 'X'.
    ls_fcat-icon      = 'X'.
    APPEND ls_fcat TO lt_fcat. CLEAR: ls_fcat.


    CALL METHOD go_screens_grid->set_table_for_first_display
      EXPORTING
        is_variant      = ls_variant
        i_save          = 'A'
        i_default       = 'X'
        is_layout       = ls_layout
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = gt_screens[].

    SET HANDLER go_event->handle_hotspot_click FOR go_screens_grid.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form load_screens
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM load_screens .

  CLEAR: gt_screens[].
  SELECT zcj_z2ui5_screet~appl, zcj_z2ui5_screet~screen,
    zcj_z2ui5_screet~sdescr
    FROM zcj_z2ui5_screet
    INNER JOIN zcj_z2ui5_screen
    ON  zcj_z2ui5_screen~appl   EQ zcj_z2ui5_screet~appl
    AND zcj_z2ui5_screen~screen EQ zcj_z2ui5_screet~screen
    INTO TABLE @gt_screens
    WHERE zcj_z2ui5_screet~appl  EQ @p_appl
    AND   zcj_z2ui5_screet~langu EQ @sy-langu
    ORDER BY zcj_z2ui5_screen~seqnr.

  LOOP AT gt_screens ASSIGNING FIELD-SYMBOL(<screens>).
    <screens>-action = icon_execute_object.
  ENDLOOP.

  IF go_screens_grid IS NOT INITIAL.
    go_screens_grid->refresh_table_display( ).
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form exec_screen
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM exec_screen .

  CHECK go_screens_grid IS NOT INITIAL.
  go_screens_grid->get_selected_rows( IMPORTING et_index_rows = DATA(lt_index_rows) et_row_no = DATA(lt_row_no) ).
  IF lt_row_no[] IS INITIAL.
    MESSAGE s028(1g) DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.
  READ TABLE lt_row_no INTO DATA(ls_row_no) INDEX 1.
  READ TABLE gt_screens INTO DATA(ls_screen) INDEX ls_row_no-row_id.
  IF sy-subrc EQ 0.
    gv_screen = ls_screen-screen.
    CALL SCREEN 100.
  ENDIF.


ENDFORM.
