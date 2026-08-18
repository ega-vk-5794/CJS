CLASS zcl_e014_consult_reg_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   REVIEW-TECH: this class used to declare INTERFACES zif_rak_journey_logic
*   directly and implement only 3 of its ~24 methods - a class that declares
*   an interface itself (rather than inheriting a base that already does)
*   must supply every method or it cannot activate. Switched to inheriting
*   ZCL_RAK_JOURNEY_LOGIC, the pattern every other journey handler in this
*   system uses (ZCL_D009_..., ZCL_EPDA_E022_..., ZCL_RAK_D_APPROVAL_LOGIC):
*   the base supplies empty defaults for everything, including the whole
*   payment card (fee list, gateway hand-off, the PAID gate on Submit), and
*   this class redefines only what E014 actually needs on top of it.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_init            REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read       REDEFINITION.
    METHODS zif_rak_journey_logic~on_change           REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate  REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   The OWNER_FINDER container's real children, confirmed against the
*   /QNV/SB_UI_DEFIN export (NE014_1_1, PARENT_CONTAINER = OWNER_FINDER):
*   one live field, a PERSON_SEARCH named OWNER_FINDER_BP (posts as
*   GS_DATA-OWNER). The migrator projects it under this same safe name -
*   see ZCL_RAK_MIGRATOR->safe_of/norm_name - so no name translation is
*   needed here.
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
    rt = VALUE #( ( `OWNER_FINDER_BP` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   PAY_SCREEN is real: NE014_1_4 is this journey's own migrated payment
*   step (see ZRAK_EPDA_MIGRATE6, which puts PAYFEE back on it after the
*   migrator drops it). The base class's PREPARE_PAYMENT reads this to
*   know which BKND_SCREEN's read BAdI resolves the gateway.
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'NE014_1_4' ).

*   REVIEW-BE: PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR are NOT in the
*   /QNV/SB_UI_DEFIN export (there is nowhere on a UI screen for a company
*   code or a fee material to appear) - they are backend Financial /
*   FI-CA configuration for the EPDA department's registration fee, and
*   guessing them risks a fee raised against the wrong company code or
*   material rather than one that simply fails loudly. PREPARE_GATEWAY
*   refuses cleanly with "company code / fee material were not supplied"
*   until these are set, so Pay is inert rather than wrong until this is
*   confirmed with EPDA Finance:
*     io_ctx->set_val( iv_name = c_pay_bukrs    iv_value = '' ).
*     io_ctx->set_val( iv_name = c_pay_material iv_value = '' ).
*     io_ctx->set_val( iv_name = c_pay_casesfor iv_value = '' ).
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
*   REDEFINITION replaces the base implementation outright, and the base's
*   own on_custom_validate is what refuses Submit while PAYFEE <> 'PAID' -
*   so this call is not optional once a payment step is wired back on.
*   Without it, E014 could be submitted with the fee unpaid.
    rt = super->zif_rak_journey_logic~on_custom_validate(
      io_ctx = io_ctx iv_step = iv_step ).

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
