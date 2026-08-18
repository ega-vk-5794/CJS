CLASS zcl_rak_d001_owner_popup DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_render_start REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_popup REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event  REDEFINITION.
    METHODS zif_rak_journey_logic~get_table       REDEFINITION.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_owner,
             partner TYPE string,
             name    TYPE string,
             share   TYPE string,
             eid     TYPE string,
           END OF ty_owner,
           tt_owner TYPE STANDARD TABLE OF ty_owner WITH EMPTY KEY.

    METHODS read_owners
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE tt_owner.
    METHODS write_owners
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                it_owners TYPE tt_owner.
    METHODS clear_popup
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.
ENDCLASS.



CLASS ZCL_RAK_D001_OWNER_POPUP IMPLEMENTATION.


  METHOD clear_popup.
    io_ctx->set_val( iv_name = 'POP_BP'    iv_value = `` ).
    io_ctx->set_val( iv_name = 'POP_NAME'  iv_value = `` ).
    io_ctx->set_val( iv_name = 'POP_SHARE' iv_value = `` ).
    io_ctx->set_val( iv_name = 'POP_EID'   iv_value = `` ).
  ENDMETHOD.


  METHOD read_owners.
    SPLIT io_ctx->get_val( 'OWNERS_BLOB' ) AT ';' INTO TABLE DATA(lt).
    LOOP AT lt INTO DATA(lv) WHERE table_line IS NOT INITIAL.
      SPLIT lv AT '|' INTO DATA(a) DATA(b) DATA(c) DATA(d).
      APPEND VALUE #( partner = a name = b share = c eid = d ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD write_owners.
    DATA lv TYPE string.
    LOOP AT it_owners INTO DATA(ls).
      lv = lv && COND #( WHEN lv IS INITIAL THEN `` ELSE `;` )
              && |{ ls-partner }\|{ ls-name }\|{ ls-share }\|{ ls-eid }|.
    ENDLOOP.
    io_ctx->set_val( iv_name = 'OWNERS_BLOB' iv_value = lv ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
    CHECK to_upper( iv_name ) = 'OWNERS'.
    rs_data-columns = VALUE #( ( `Partner` ) ( `Name` ) ( `Share %` ) ( `Emirates ID` ) ).
    LOOP AT read_owners( io_ctx ) INTO DATA(ls).
      APPEND VALUE #( ( ls-partner ) ( ls-name ) ( ls-share ) ( ls-eid ) ) TO rs_data-rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
    CASE iv_event.
      WHEN 'OPEN'.
        clear_popup( io_ctx ).
        io_ctx->open_popup( 'OWNER' ).

      WHEN 'CANCEL'.
        io_ctx->close_popup( ).

      WHEN 'OK'.
        DATA(lv_bp) = io_ctx->get_val( 'POP_BP' ).
        IF lv_bp IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning' iv_text = 'Partner is required.' ).
          RETURN.                          " leave the popup open for correction
        ENDIF.

        DATA(lt) = read_owners( io_ctx ).
        IF NOT line_exists( lt[ partner = lv_bp ] ).
          APPEND VALUE #( partner = lv_bp
                          name    = io_ctx->get_val( 'POP_NAME' )
                          share   = io_ctx->get_val( 'POP_SHARE' )
                          eid     = io_ctx->get_val( 'POP_EID' ) ) TO lt.
          write_owners( io_ctx = io_ctx it_owners = lt ).
        ENDIF.

        clear_popup( io_ctx ).
        io_ctx->close_popup( ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    CHECK iv_id = 'OWNER'.
    dialog_form(
      io_ctx    = io_ctx
      io_popup  = io_popup
      iv_title  = 'Add owner'
      it_fields = VALUE #(
        ( name = 'POP_BP'    label = 'Partner' )
        ( name = 'POP_NAME'  label = 'Name' )
        ( name = 'POP_SHARE' label = 'Share %' )
        ( name = 'POP_EID'   label = 'Emirates ID' ) ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
    CHECK io_ctx->get_step( ) = 2.
    io_view->button(
      text  = 'Add owner'
      icon  = 'sap-icon://add'
      type  = 'Emphasized'
      class = 'sapUiSmallMargin'
      press = io_ctx->event( 'OPEN' ) ).    " -> on_popup_event iv_event = 'OPEN'
  ENDMETHOD.
ENDCLASS.
