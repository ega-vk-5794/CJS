*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_TOP
*&---------------------------------------------------------------------*

CLASS lcl_editor DEFINITION DEFERRED.
CLASS lcl_editor DEFINITION LOAD.
CLASS lcl_event_receiver DEFINITION DEFERRED.
CLASS lcl_dragdropobj DEFINITION LOAD.

TABLES: sscrfields.
SELECTION-SCREEN FUNCTION KEY 1.

TYPES: BEGIN OF ty_screens,
         appl   TYPE zcj_z2ui5_screet-appl,
         screen TYPE zcj_z2ui5_screet-screen,
         sdescr TYPE zcj_z2ui5_screet-sdescr,
         action TYPE icon-id,
       END OF ty_screens,
       tt_screens TYPE STANDARD TABLE OF ty_screens WITH DEFAULT KEY.

DATA: ok_code         TYPE sy-ucomm,
      go_editor       TYPE REF TO lcl_editor,
      go_event        TYPE REF TO lcl_event_receiver,
      go_screens_cont TYPE REF TO cl_gui_custom_container,
      go_screens_grid TYPE REF TO cl_gui_alv_grid,
      gt_screens      TYPE tt_screens,
      gv_screen       TYPE zcj_z2ui5_screen-screen.
