*&---------------------------------------------------------------------*
*& Report ZCA_CJ_MAINTENANCE_Z2UI
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zca_cj_maintenance_z2ui.

INCLUDE zca_cj_maintenance_z2ui_top.
INCLUDE zca_cj_maintenance_z2ui_cls.
INCLUDE zca_cj_maintenance_z2ui_evt.
INCLUDE zca_cj_maintenance_z2ui_scr.
INCLUDE zca_cj_maintenance_z2ui_frm.

INITIALIZATION.
  IF go_editor IS INITIAL.
    go_event = NEW lcl_event_receiver( ).
    go_editor = NEW lcl_editor( ).
  ENDIF.
  sscrfields-functxt_01 = '@0Y@Create Application'.



START-OF-SELECTION.

  CALL SCREEN 100.
