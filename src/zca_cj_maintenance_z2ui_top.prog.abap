*&---------------------------------------------------------------------*
*& Include          ZCA_CJ_MAINTENANCE_Z2UI_TOP
*&---------------------------------------------------------------------*

CLASS lcl_editor DEFINITION DEFERRED.
CLASS lcl_editor DEFINITION LOAD.
CLASS lcl_event_receiver DEFINITION DEFERRED.
CLASS lcl_loader DEFINITION DEFERRED.
CLASS lcl_dragdropobj DEFINITION LOAD.

DATA: ok_code   TYPE sy-ucomm,
      go_editor TYPE REF TO lcl_editor,
      go_event  TYPE REF TO lcl_event_receiver.
