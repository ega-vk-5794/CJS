CLASS zcl_e029_new_store_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Handler for E029 - Issuance of New Store Contract
*   (legacy NE029_1_*, seeded by ZRAK_E029_LOAD).
*
*   ZCL_E028_BERTH_NEW_LOGIC is the REFERENCE HANDLER for this family and
*   the reasoning is written out once, there. Only what differs is
*   explained here.
*
*   NO PAYMENT. No RAKPAY, no RAKREMAININGFEES and no fee CLIST anywhere in
*   NE029_1_* - confirmed against the export. So no on_init, no PAY_SCREEN,
*   no PAY_BUKRS.
*
*   WHAT DIFFERS FROM E028:
*
*   1. TWO validity options, not five. The legacy DATA1 group on
*      NE029_1_2 is VALIDITY_YEAR1,VALIDITY_YEAR2 and nothing else, so
*      only two backend flags exist to fan out to. Writing
*      GS_DATA-VALIDITY_YEAR3..5 here would post flags this journey's
*      backend never declared.
*
*   2. The either/or is simpler. E029 has ONE storage dropdown and a
*      waiting list, where E028 has two berth dropdowns and a waiting
*      list. So the "at least one of three" check becomes "at least one
*      of two", and E028's "the two must differ" check has no second
*      field to compare against and is absent.
*
*   NOTE for anyone adding a show/hide here later: set_hidden( ) OUTRANKS
*   the rules for the rest of the session. OWNER_1 is already governed by
*   rule R001, so calling set_hidden( ) on it from this class would not
*   add to that rule - it would silently take the decision away from it.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read      REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_validity       TYPE string VALUE 'VALIDITY_YEAR1'  ##NO_TEXT.
*   The Lease Details step, zero-based as the hooks count them: STP1 is
*   the licence picker at index 0, STP2 Lease Details at index 1.
    CONSTANTS c_step_lease     TYPE i      VALUE 1.

*   Write EVERY flag in a group on every change, not only the chosen one.
*   The citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both - and the same for a validity changed from
*   2 years down to 1.
    METHODS set_group
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string
                it_map  TYPE zif_rak_journey=>tt_kv.
ENDCLASS.



CLASS ZCL_E029_NEW_STORE_LOGIC IMPLEMENTATION.


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


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_applicant_type.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_applicant_type )
                   it_map  = VALUE #(
                     ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
                     ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ) ).

*     Two members only. See the note in the class header on why the other
*     three VALIDITY_YEAR flags are deliberately absent.
      WHEN c_validity.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_validity )
                   it_map  = VALUE #(
                     ( key = `VALIDITY_YEAR1` value = `GS_DATA-VALIDITY_YEAR1` )
                     ( key = `VALIDITY_YEAR2` value = `GS_DATA-VALIDITY_YEAR2` ) ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   super-> FIRST. The base implementation is the PAID gate, and a
*   redefinition replaces it. This journey has no payment today, so the
*   gate has nothing to refuse - but calling it costs one compare and
*   keeps the protection if a fee is ever added. It also has to come
*   BEFORE the CHECK below, because a failing CHECK exits the method.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).

    CHECK iv_step = c_step_lease.

*   ---- the storage choice, which config cannot express -----------------
*   Modelled on ZCL_EGA_CJ_ENH_IMPL_E028->UPDATE, which refuses to leave
*   the lease screen when neither a berth nor the waiting list has been
*   chosen. The storage equivalent is "at least one of two", and
*   ZRAK_T_JNY_RULE compares one source against one literal, so it needs
*   ABAP.
*
*   The rules do the other half: R002 greys the dropdown out when the
*   waiting list is ticked and R003 drops its REQUIRED flag, so a citizen
*   who joins the queue is not then blocked by a mandatory field. Without
*   the check below, the two rules together would let them leave the step
*   having chosen NEITHER.
*
*   REVIEW-BE: unlike E028, this is NOT lifted from a legacy UPDATE that
*   was read - it is the same shape applied to the one dropdown this
*   screen has. If ZCL_EGA_CJ_ENH_IMPL_E029 raises a different message or
*   allows an empty storage choice, match it rather than this.
    DATA(lv_waiting) = io_ctx->get_val( 'WAITING_1' ).
    DATA(lv_storage) = io_ctx->get_val( 'STORAGE_NUMBER_1' ).

    IF lv_waiting IS INITIAL AND lv_storage IS INITIAL.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = 'Choose a storage number, or tick Waiting List to join the queue.' ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
