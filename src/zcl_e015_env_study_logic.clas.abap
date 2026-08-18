CLASS zcl_e015_env_study_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Migrated from NE015_1_1..5 (EPDA) by ZRAK_EPDA_MIGRATE6 / ZCL_RAK_MIGRATOR.
*   NE015_1_1 carries the identical OWNER_FINDER component seen on E014
*   (same LABEL_CON EPDA_NE014_1_1_TBUTTON_1 - a shared legacy building
*   block), but with a DIFFERENT, two-way group: PARTNER_OWNER_1 /
*   PARTNER_REP_1 (Owner / Representative), not E014's three-way Owner /
*   PRO / Manager. Confirmed from the real /QNV/SB_UI_DEFIN DATA1 group
*   membership - not assumed from E014.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_init      REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read REDEFINITION.
    METHODS zif_rak_journey_logic~on_change     REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   OWNER_FINDER's only child on this screen: one PERSON_SEARCH, OWNER_1
*   (no distinct "_BP" suffix here - the export names it plainly).
*
*   REVIEW-BE: OWNER_1's live business-partner lookup is not wired - this
*   class does not redefine on_search, so the field renders (SEARCH is a
*   recognised ftype) but a press returns nothing. Same open item as
*   ZCL_E014_CONSULT_REG_LOGIC's OWNER_FINDER_BP; wire both from the same
*   BP-search API once its contract is confirmed.
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



CLASS ZCL_E015_ENV_STUDY_LOGIC IMPLEMENTATION.


  METHOD owner_finder_fields.
    rt = VALUE #( ( `OWNER_1` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   PAY_SCREEN is real: NE015_1_4 is this journey's own migrated payment
*   step (PAYFEE restored there by ZRAK_EPDA_MIGRATE6).
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'NE015_1_4' ).

*   REVIEW-BE: PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR - see the identical
*   note on ZCL_E014_CONSULT_REG_LOGIC. Not derivable from the UI export;
*   confirm with EPDA Finance before Pay can raise a real fee.
  ENDMETHOD.


  METHOD set_group.
*   Every flag in the group, every time - a short IT_TECH would silently
*   stop writing the tail of the group. Same idiom as ZCL_E014_CONSULT_REG_LOGIC.
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
    LOOP AT it_on INTO DATA(lv_on).
      io_ctx->set_hidden( iv_field = lv_on iv_on = abap_false ).
    ENDLOOP.
    LOOP AT it_off INTO DATA(lv_off).
      io_ctx->set_hidden( iv_field = lv_off iv_on = abap_true ).
      io_ctx->set_val( iv_name = lv_off iv_value = '' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
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
        DATA(lt_grp)   = VALUE string_table( ( `PARTNER_OWNER_1` ) ( `PARTNER_REP_1` ) ).
        DATA(lt_grp_t) = VALUE string_table( ( `GS_DATA-PARTNER_OWNER` ) ( `GS_DATA-PARTNER_REP` ) ).
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_partner_owner_1 )
                   it_all  = lt_grp
                   it_tech = lt_grp_t ).

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
ENDCLASS.
