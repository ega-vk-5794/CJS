CLASS zcl_e028_berth_new_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Handler for E028 - Issuance of New Berth Contract
*   (legacy NE028_1_*, seeded by ZRAK_E028_LOAD).
*
*   THIS IS THE REFERENCE HANDLER for the berth/store/housing family. E128,
*   E029, E129, E030 and E130 repeat this shape with different option sets
*   and different objects; the reasoning is written out once, here.
*
*   NO PAYMENT. No RAKPAY, no RAKREMAININGFEES and no fee CLIST anywhere in
*   NE028_1_* - confirmed against the export. So no on_init, no PAY_SCREEN,
*   no PAY_BUKRS. If a fee is introduced later, that goes here and STP3
*   needs NEXT_REQUIRES = 'PAYFEE' in the feeder at the same time.
*
*   Three things config cannot express, and nothing else:
*
*   1. TWO segmented fields, EIGHT backend flags. The legacy screen had two
*      TBUTTONs for the applicant type and five for the validity, each
*      bound to its own GS_DATA-* flag. A segmented field carries ONE
*      value, so both groups have to be fanned back out or the backend
*      receives nothing for either.
*
*   2. The declaration sentence. The legacy DECLARATION_LONG rows are
*      invisible; what the citizen reads is DECLARATION_NAME, which the
*      BAdI composes as "I, <partner name> as the company owner, ...".
*      Config can hold the sentence but not the name.
*
*   3. The berth choice is an EITHER/OR that spans three fields. See
*      on_custom_validate.
*
*   NOTE for anyone adding a show/hide here later: set_hidden( ) OUTRANKS
*   the rules for the rest of the session. OWNER_1 and
*   CB_DOK_PARKING_NUMBER_2 are already governed by rules R001 and R004,
*   so calling set_hidden( ) on either from this class would not add to
*   them - it would silently take the decision away from them. That is the
*   exact mistake that had E015 and E027 showing the owner lookup
*   backwards.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read      REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_validity       TYPE string VALUE 'VALIDITY_YEAR1'  ##NO_TEXT.
*   The Lease Details step, zero-based as the hooks count them. The legacy
*   screen runs its berth check when the screen name has already advanced
*   to NE028_1_3, i.e. on the way OUT of NE028_1_2 - which is step index 1.
    CONSTANTS c_step_lease     TYPE i      VALUE 1.

*   Write EVERY flag in a group on every change, not only the chosen one.
*   The citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both - and the same for a validity changed from
*   5 years down to 1.
    METHODS set_group
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string
                it_map  TYPE zif_rak_journey=>tt_kv.
ENDCLASS.



CLASS ZCL_E028_BERTH_NEW_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_applicant_type.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_applicant_type )
                   it_map  = VALUE #(
                     ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
                     ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ) ).

      WHEN c_validity.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_validity )
                   it_map  = VALUE #(
                     ( key = `VALIDITY_YEAR1` value = `GS_DATA-VALIDITY_YEAR1` )
                     ( key = `VALIDITY_YEAR2` value = `GS_DATA-VALIDITY_YEAR2` )
                     ( key = `VALIDITY_YEAR3` value = `GS_DATA-VALIDITY_YEAR3` )
                     ( key = `VALIDITY_YEAR4` value = `GS_DATA-VALIDITY_YEAR4` )
                     ( key = `VALIDITY_YEAR5` value = `GS_DATA-VALIDITY_YEAR5` ) ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD set_group.
    LOOP AT it_map INTO DATA(ls_map).
      io_ctx->set_val( iv_name  = ls_map-value
                       iv_value = COND string( WHEN ls_map-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*   ---- the declaration sentence ----------------------------------------
*   The legacy BAdI builds this as "I, <name> as the company owner, hereby
*   declare ...". The feeder seeds the sentence WITHOUT the name so the
*   field reads correctly even if this method never runs; here it is
*   replaced with the full version once the read has supplied a name.
*
*   Guarded on the name being present rather than on the step, because the
*   read that fills GS_DATA-PARTNER_NAME may arrive on any step and
*   overwriting a good sentence with "I,  as the company owner" would be
*   worse than leaving the seeded one alone.
    DATA(lv_name) = io_ctx->get_val( 'APP_NAME' ).
    IF lv_name IS NOT INITIAL.
      io_ctx->set_val(
        iv_name  = 'DECLARATION_NAME'
        iv_value = |I, { lv_name } as the company owner, hereby declare that all | &&
                   |information provided in this application and in attached documents | &&
                   |are true and accurate, that I will be responsible for any | &&
                   |consequences of them, and I will be abide by all relevant regular | &&
                   |conditions, instructions and guidelines to avoid legal action in | &&
                   |case of violations and that I authorize our representative to | &&
                   |follow up all the related to the activity.| ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   super-> FIRST. The base implementation is the PAID gate, and a
*   redefinition replaces it. This journey has no payment today, so the
*   gate has nothing to refuse - but calling it costs one compare and
*   keeps the protection if a fee is ever added. It also has to come
*   BEFORE the CHECK below, because a failing CHECK exits the method.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).

    CHECK iv_step = c_step_lease.

*   ---- the berth choice, which config cannot express -------------------
*   Straight from ZCL_EGA_CJ_ENH_IMPL_E028->UPDATE, which runs both of
*   these when the screen name has advanced to NE028_1_3:
*
*     IF berth-waiting IS INITIAL AND berth-aoid IS INITIAL
*                                 AND berth2-aoid IS INITIAL.   -> e054
*     IF berth-waiting IS INITIAL AND berth-aoid EQ berth2-aoid
*                                 AND berth-aoid IS NOT INITIAL. -> e056
*
*   Neither is a per-field rule: the first is "at least one of three", the
*   second is "these two must differ". ZRAK_T_JNY_RULE compares one source
*   against one literal, so both need ABAP.
    DATA(lv_waiting) = io_ctx->get_val( 'WAITING_1' ).
    DATA(lv_berth1)  = io_ctx->get_val( 'DOK_PARKING_NUMBER_1' ).
    DATA(lv_berth2)  = io_ctx->get_val( 'CB_DOK_PARKING_NUMBER_2' ).

    IF lv_waiting IS INITIAL AND lv_berth1 IS INITIAL AND lv_berth2 IS INITIAL.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = 'Choose a dock/parking number, or tick Waiting List to join the queue.' ) ).
      RETURN.
    ENDIF.

*   Only meaningful when a berth was actually chosen - two blanks are
*   equal but that case is already covered above.
    IF lv_waiting IS INITIAL AND lv_berth1 IS NOT INITIAL AND lv_berth1 = lv_berth2.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = 'The second dock/parking number must be different from the first.' ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
