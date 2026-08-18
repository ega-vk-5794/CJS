CLASS zcl_e014_consult_reg_logic DEFINITION
 PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_rak_journey_logic.

  PRIVATE SECTION.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   REVIEW: the children of each legacy container. The export names the
*   CONTAINER only - UI_FIELD_LOGICS says OWNER_FINDER-V-T, never which
*   fields live inside it - so these lists are the migration decision that
*   most needs a second pair of eyes. A missing name leaves a field on
*   screen holding a value the citizen cannot see and the backend still gets.
    METHODS owner_finder_fields RETURNING VALUE(rt) TYPE string_table.

    METHODS set_group
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string
                it_all  TYPE string_table
                it_tech TYPE string_table.

    METHODS show_only
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
                it_on  TYPE string_table
                it_off TYPE string_table.

ENDCLASS.



CLASS ZCL_E014_CONSULT_REG_LOGIC IMPLEMENTATION.


  METHOD owner_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD set_group.
*   Every flag in the group, every time. IT_ALL and IT_TECH are positional:
*   the nth option writes the nth technical name. A short IT_TECH would
*   silently stop writing the tail of the group, so it is checked.
    IF lines( it_all ) <> lines( it_tech ).
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |Handler misconfigured: { lines( it_all ) } options |
                                 && |against { lines( it_tech ) } backend fields| ).
      RETURN.
    ENDIF.

    LOOP AT it_all INTO DATA(lv_opt).
      DATA(lv_i) = sy-tabix.
      io_ctx->set_val( iv_name  = it_tech[ lv_i ]
                       iv_value = COND string( WHEN lv_opt = iv_pick
                                               THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD show_only.
*   Both directions. SHOW alone leaves the other panel on screen after its
*   trigger is cleared, still holding values and still posting them.
    LOOP AT it_on INTO DATA(lv_on).
      io_ctx->set_hidden( iv_field = lv_on iv_on = abap_false ).
    ENDLOOP.
    LOOP AT it_off INTO DATA(lv_off).
      io_ctx->set_hidden( iv_field = lv_off iv_on = abap_true ).
      io_ctx->set_val( iv_name = lv_off iv_value = '' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*   The same show/hide the change handler does, applied on arrival. Without
*   this the first render shows both panels until the citizen touches the
*   control - and a resumed draft shows both for good.
    show_only(
      io_ctx = io_ctx
      it_on  = COND #( WHEN io_ctx->get_val( c_partner_owner_1 ) = `PARTNER_OWNER_1`
                       THEN owner_finder_fields( ) )
      it_off = COND #( WHEN io_ctx->get_val( c_partner_owner_1 ) <> `PARTNER_OWNER_1`
                       THEN owner_finder_fields( ) ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_partner_owner_1.
        DATA(lt_partner_owner_1) = VALUE string_table( ( `PARTNER_OWNER_1` ) ( `PARTNER_PRO_1` ) ( `PARTNER_MANAGER_1` ) ).
        DATA(lt_partner_owner_1_t) = VALUE string_table( ( `GS_DATA-PARTNER_OWNER` ) ( `GS_DATA-PARTNER_PRO` ) ( `GS_DATA-PARTNER_MANAGER` ) ).
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_partner_owner_1 )
                   it_all  = lt_partner_owner_1
                   it_tech = lt_partner_owner_1_t ).

        DATA(lv_owner_finder) = xsdbool(
          io_ctx->get_val( c_partner_owner_1 ) = `PARTNER_OWNER_1` ).
        show_only(
          io_ctx = io_ctx
          it_on  = COND #( WHEN lv_owner_finder = abap_true
                           THEN owner_finder_fields( ) )
          it_off = COND #( WHEN lv_owner_finder = abap_false
                           THEN owner_finder_fields( ) ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   REQUIRED does not reach grid rows. The grid field holds no scalar, so an
*   empty grid satisfies field validation and the application submits with
*   no rows in it - which the backend accepts.
*
*   Steps count from ZERO in hooks, so the guards below are one less than the
*   step number in the seed.

    IF io_ctx->get_step( ) = 5.
*      IF lines( io_ctx->get_rows( `LICENSE` ) ) = 0.
*        APPEND VALUE #( type = 'Error'
*                        text = |At least one row is required in License| )
*               TO rt_msg.
*      ENDIF.
    ENDIF.

    IF io_ctx->get_step( ) = 10.
*      IF lines( io_ctx->get_rows( `APPEALS` ) ) = 0.
*        APPEND VALUE #( type = 'Error'
*                        text = |At least one row is required in Appeals| )
*               TO rt_msg.
*      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
