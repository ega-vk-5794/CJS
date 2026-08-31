*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_SCR
*&---------------------------------------------------------------------*

PARAMETERS: p_appl TYPE zcj_z2ui5_apps-appl OBLIGATORY.

AT SELECTION-SCREEN.

  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      PERFORM open_sm30 USING 'ZCJ_Z2UI5_APPS'.
  ENDCASE.
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'MAIN'.
  SET TITLEBAR 'MAIN'.
  go_editor->init_screens( ).
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE ok_code.
    WHEN 'EXIT'.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.
