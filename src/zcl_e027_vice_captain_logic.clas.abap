CLASS zcl_e027_vice_captain_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Migrated from NE027_1_1..5 (EPDA) by ZRAK_EPDA_MIGRATE6 / ZCL_RAK_MIGRATOR.
*   No RAKPAY anywhere in the real export - confirmed, not assumed - so
*   unlike E014/E015/E146 this journey has no payment step and needs no
*   PAY_SCREEN/PAY_BUKRS wiring.
*
*   Three separate BP-search points, confirmed from PARENT_CONTAINER:
*     NE027_1_1  OWNER_ID_1   standalone (VBOX_5)     - REVIEW-BE: which
*                party this looks up is not named anywhere in the export
*                (no label resolved); likely the license holder / current
*                captain, to be confirmed functionally before wiring on_search.
*     NE027_1_2  OWNER_1      OWNER_FINDER container  - the SAME shared
*                Owner/Representative toggle as ZCL_E015_ENV_STUDY_LOGIC
*                (identical LABEL_CON EPDA_NE014_1_1_TBUTTON_1, identical
*                two-way DATA1 group) - handled below.
*     NE027_1_3  OWNER_ID_2   CAPTAIN_FINDER container - REVIEW-BE: the
*                vice-captain nominee lookup, by the container name. Its
*                own container has no other live field to show/hide.
*
*   REVIEW-BE: none of the three has on_search wired - each renders (SEARCH
*   is a recognised ftype) but a press returns nothing until a BP-search
*   API is confirmed and wired for all three (and for OWNER_1 / OWNER_FINDER_BP
*   on E015 / E014 - same open item, same API, one place to fix it).
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_after_read REDEFINITION.
    METHODS zif_rak_journey_logic~on_change     REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

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



CLASS ZCL_E027_VICE_CAPTAIN_LOGIC IMPLEMENTATION.


  METHOD owner_finder_fields.
    rt = VALUE #( ( `OWNER_1` ) ).
  ENDMETHOD.


  METHOD set_group.
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
