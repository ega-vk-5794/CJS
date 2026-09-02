INTERFACE zif_rak_cj_control
  PUBLIC.

*&---------------------------------------------------------------------*
*& A composite control the engine draws itself, rather than a field.
*&
*& WHY AN INTERFACE AND NOT A CLASS REFERENCE. A control that renders a
*& parcel list reaches ZCL_RAK_PROPERTY_API -> ZCL_RAK_CJ_API, which
*& INHERITS the generated legacy DPC. A static reference anywhere in the
*& engine or the renderer would put that whole chain in their load graph:
*& one inactive object down there and every journey, plus the Studio,
*& stops loading. That is the same reason RENDER_ONE( ) already calls
*& ZCL_RAK_CJ_OPTS=>RESOLVE( ) dynamically.
*&
*& An INTERFACE reference costs nothing at load - the implementing class
*& is pulled in only by the CREATE OBJECT ... TYPE ('...') that makes one,
*& and that sits in a TRY/CATCH. So the engine holds a typed reference,
*& gets compile-time checking on the three calls below, and still degrades
*& to the plain renderer when the chain is not active.
*&
*& Every method answers a BOOLEAN rather than raising: a control that did
*& not draw is not an error, it is a control that had nothing to draw, and
*& the caller falls back.
*&---------------------------------------------------------------------*

* Draw the control in place of the engine's own field renderer.
* ABAP_FALSE means "not mine" - the caller renders the field normally.
  METHODS render
    IMPORTING io_view         TYPE REF TO z2ui5_cl_xml_view
              is_field        TYPE zif_rak_journey=>ty_field
    RETURNING VALUE(rv_drawn) TYPE abap_bool.

* Draw whatever dialog this control currently has open. Called from
* RENDER_POPUP( ) when the engine's popup kind belongs to the control.
  METHODS render_popup
    IMPORTING io_popup        TYPE REF TO z2ui5_cl_xml_view
    RETURNING VALUE(rv_drawn) TYPE abap_bool.

* Handle one round trip's event. ABAP_FALSE means the event was not this
* control's, and the engine's own dispatch continues.
  METHODS on_event
    IMPORTING iv_event          TYPE string
    RETURNING VALUE(rv_handled) TYPE abap_bool.

ENDINTERFACE.
