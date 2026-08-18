*&---------------------------------------------------------------------*
*& Report ZCA_CJ_MAINTENANCE_Z2UI
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zca_cj_maintenance_z2ui.

INCLUDE zca_cj_maintenance_z2ui_top.
INCLUDE zca_cj_maintenance_z2ui_evt.
INCLUDE zca_cj_maintenance_z2ui_cls.
INCLUDE zca_cj_maintenance_z2ui_scr.

START-OF-SELECTION.

  CALL SCREEN 100.
