CLASS zcl_rak_showcase_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_open_note TYPE string VALUE 'OPENNOTE'.
    CONSTANTS c_note_ok   TYPE string VALUE 'NOTE_OK'.
    CONSTANTS c_pop_note  TYPE string VALUE 'NOTE'.

    METHODS zif_rak_journey_logic~get_table          REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help      REDEFINITION.
    METHODS zif_rak_journey_logic~render_field       REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_start     REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_popup     REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event      REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate  REDEFINITION.

  PRIVATE SECTION.
    METHODS to_num
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE decfloat34.
    METHODS step_of
      IMPORTING io_ctx         TYPE REF TO zif_rak_journey
                iv_field       TYPE string
      RETURNING VALUE(rv_step) TYPE i.
ENDCLASS.



CLASS ZCL_RAK_SHOWCASE_LOGIC IMPLEMENTATION.


  METHOD step_of.
    rv_step = -1.
    DATA lv_ix TYPE i.
    DATA(ls_cfg) = io_ctx->get_config( ).
    LOOP AT ls_cfg-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF to_upper( ls_f-name ) = to_upper( iv_field ).
          rv_step = lv_ix.
          RETURN.
        ENDIF.
      ENDLOOP.
      lv_ix = lv_ix + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_num.
    TRY.
        rv = CONV decfloat34( condense( iv ) ).
      CATCH cx_sy_conversion_no_number.
        CLEAR rv.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
    CHECK iv_name = 'FEE_TABLE'.
    rs_data-columns = VALUE #( ( `Description` ) ( `Amount (AED)` ) ).
    rs_data-rows = VALUE #(
      ( VALUE #( ( `Base service fee` ) ( `500.00` ) ) )
      ( VALUE #( ( `Processing` )       ( `150.00` ) ) )
      ( VALUE #( ( `VAT (5%)` )         ( `32.50` ) ) ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).

    CHECK iv_step = step_of( io_ctx = io_ctx iv_field = 'APPROVAL_NOTE' ).

    IF io_ctx->get_val( 'PLAN' ) = 'PRO'
       AND to_num( io_ctx->get_val( 'PRO_SEATS' ) ) > 10
       AND io_ctx->get_val( 'APPROVAL_NOTE' ) IS INITIAL.
      APPEND VALUE #( type = 'Error'
                      text = 'Approval note is required for a Professional plan with more than 10 seats.' ) TO rt.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
    super->zif_rak_journey_logic~on_popup_event( io_ctx = io_ctx iv_id = iv_id iv_event = iv_event ).

    CASE iv_event.
      WHEN c_open_note.
        io_ctx->set_val( iv_name = 'POP_NOTE' iv_value = '' ).
        io_ctx->open_popup( c_pop_note ).
      WHEN c_note_ok.
        DATA(lv_note) = condense( io_ctx->get_val( 'POP_NOTE' ) ).
        IF lv_note IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning' iv_text = 'Type a remark first.' ).
          RETURN.
        ENDIF.
        io_ctx->add_msg( iv_type = 'Success' iv_text = |Remark noted: { lv_note }| ).
        io_ctx->close_popup( ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    CHECK iv_id = c_pop_note.
    dialog_form(
      io_ctx     = io_ctx
      io_popup   = io_popup
      iv_title   = 'Add a remark'
      it_fields  = VALUE #( ( name = 'POP_NOTE' label = 'Remark' type = 'TEXTAREA' ) )
      iv_ok_text = 'Save remark'
      iv_ok_evt  = c_note_ok ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
    super->zif_rak_journey_logic~on_render_start( io_ctx = io_ctx io_view = io_view ).
    CHECK io_ctx->get_step( ) = step_of( io_ctx = io_ctx iv_field = 'CUSTOM_CARD' ).

    io_view->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBegin sapUiTinyMarginTop'
      )->button( text  = 'Add remark'
                 icon  = 'sap-icon://comment'
                 type  = 'Emphasized'
                 press = io_ctx->event( c_open_note ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
    CASE iv_field.
      WHEN 'DEPARTMENT'.
        rt = VALUE #( ( key = 'FIN' text = 'Finance' )
                      ( key = 'HR'  text = 'Human Resources' )
                      ( key = 'IT'  text = 'Information Technology' ) ).
      WHEN 'MATERIALS.UNIT'.
        rt = VALUE #( ( key = 'KG'     text = 'KG' )
                      ( key = 'Ton'    text = 'Ton' )
                      ( key = 'Pieces' text = 'Pieces' )
                      ( key = 'Litre'  text = 'Litre' ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
    rv_done = super->zif_rak_journey_logic~render_field(
      io_ctx = io_ctx io_form = io_form is_field = is_field ).
    CHECK rv_done = abap_false.
    CHECK to_upper( is_field-name ) = 'CUSTOM_CARD'.

    io_form->label( is_field-label ).
    DATA(lo_card) = io_form->vbox( class = 'rakSearch' ).
    lo_card->object_status(
      text  = |Applicant: { COND #( WHEN io_ctx->get_val( 'FULL_NAME' ) IS NOT INITIAL
                                    THEN io_ctx->get_val( 'FULL_NAME' ) ELSE '(not entered yet)' ) }|
      state = 'Information'
      icon  = 'sap-icon://person-placeholder' ).
    lo_card->object_status(
      text  = |Plan: { COND #( WHEN io_ctx->get_val( 'PLAN' ) IS NOT INITIAL THEN io_ctx->get_val( 'PLAN' ) ELSE 'BASIC' ) }|
      state = COND #( WHEN io_ctx->get_val( 'PLAN' ) = 'PRO' THEN 'Success' ELSE 'None' )
      icon  = 'sap-icon://token'
      class = 'sapUiTinyMarginTop' ).
    rv_done = abap_true.
  ENDMETHOD.
ENDCLASS.
