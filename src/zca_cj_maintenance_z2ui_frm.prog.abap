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
