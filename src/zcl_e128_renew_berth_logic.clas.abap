CLASS zcl_e128_renew_berth_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Handler for E128 - Renew Berth Contract
*   (legacy NE128_1_*, seeded by ZRAK_E128_LOAD).
*
*   ZCL_E028_BERTH_NEW_LOGIC is the REFERENCE HANDLER for this family and
*   the reasoning behind the shared shapes is written out there, once.
*   Read it first. Only what differs is commented here.
*
*   NO PAYMENT anywhere in NE128_1_* - confirmed against the export. So no
*   on_init, no PAY_SCREEN, no PAY_BUKRS. If a fee is introduced later,
*   that goes here and STP3 needs NEXT_REQUIRES = 'PAYFEE' in the feeder
*   at the same time.
*
*   ---- WHY on_custom_validate IS NOT REDEFINED HERE --------------------
*   E028 redefines it for the berth either/or: at least one of three
*   fields, and two berths that must differ. NONE of that applies to a
*   renewal. The berths are DISPLAYED on this journey, not chosen - the
*   legacy screen carries them as LABELs bound to GS_DATA-BERTH-AOID_TX
*   and GS_DATA-BERTH2-AOID_TX, with no combobox, no Waiting List
*   checkbox, no Add-another checkbox and no PORT filter row anywhere in
*   NE128_1_*. There is nothing for the citizen to get wrong, so there is
*   nothing to validate.
*
*   The base implementation is therefore left in place, which is the point
*   of not redefining: the inherited PAID gate keeps working, unchanged
*   and unrepeated. Copying E028's method across "for symmetry" would
*   read GS_DATA-BERTH-AOID (a field this journey does not render),
*   find it blank on every run, and refuse to let anybody submit.
*
*   So this class does exactly two things config cannot express:
*
*   1. TWO segmented fields, SEVEN backend flags. Two applicant-type
*      buttons and five validity buttons, each bound to its own GS_DATA-*
*      flag on the legacy screen. A segmented field carries ONE value, so
*      both groups have to be fanned back out or the backend receives
*      nothing for either.
*
*   2. The declaration sentence. The legacy DECLARATION_LONG rows are
*      invisible; what the citizen reads is DECLARATION_NAME, which the
*      BAdI composes as "I, <partner name> as the company owner, ...".
*      Config can hold the sentence but not the name.
*
*   NOTE for anyone adding a show/hide here later: set_hidden( ) OUTRANKS
*   the rules for the rest of the session. OWNER_1 is already governed by
*   rule R01, so calling set_hidden( ) on it from this class would not add
*   to that rule - it would silently take the decision away from it. That
*   is the exact mistake that had E015 and E027 showing the owner lookup
*   backwards.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change     REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_validity       TYPE string VALUE 'VALIDITY_YEAR1'  ##NO_TEXT.

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



CLASS ZCL_E128_RENEW_BERTH_LOGIC IMPLEMENTATION.


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

*   REVIEW-BE: the second berth row (BERTH_AOID_TX_2, bound to
*   GS_DATA-BERTH2-AOID_TX) renders BLANK on a one-berth contract, because
*   configuration cannot hide a field on the basis of its own emptiness.
*   If EPDA decides a blank row is unacceptable, THIS is where it goes:
*
*     IF io_ctx->get_val( 'BERTH_AOID_TX_2' ) IS INITIAL.
*       io_ctx->set_hidden( 'BERTH_AOID_TX_2' ).
*     ENDIF.
*
*   Left commented rather than enabled because nobody has asked for it and
*   a hidden field is harder to notice than an empty one. Note also that
*   set_hidden( ) is permanent for the session - a later read that DOES
*   supply a second berth would not bring the row back.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_applicant_type.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_applicant_type )
                   it_map  = VALUE #(
                     ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
                     ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ) ).

*     Five options, the same set as E028. E029 has two of these and E030
*     seven - the option list is per journey and is not shared, so do not
*     lift this map into a shared superclass without checking each caller.
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
ENDCLASS.
