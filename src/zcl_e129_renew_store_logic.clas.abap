CLASS zcl_e129_renew_store_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Handler for E129 - Renew Store Contract
*   (legacy NE129_1_*, seeded by ZRAK_E129_LOAD).
*
*   ZCL_E028_BERTH_NEW_LOGIC is the REFERENCE HANDLER for this family and
*   the reasoning behind the shared shapes is written out there, once.
*   Read it first, then ZCL_E128_RENEW_BERTH_LOGIC, which is this class's
*   near twin. Only what differs is commented here.
*
*   NO PAYMENT anywhere in NE129_1_* - confirmed against the export. So no
*   on_init, no PAY_SCREEN, no PAY_BUKRS. If a fee is introduced later,
*   that goes here and STP3 needs NEXT_REQUIRES = 'PAYFEE' in the feeder
*   at the same time.
*
*   ---- WHY on_custom_validate IS NOT REDEFINED HERE --------------------
*   E029 - the journey that ISSUES these contracts - redefines it for the
*   storage either/or: a unit must be chosen or the Waiting List ticked.
*   That does not apply to a renewal. The storage unit is DISPLAYED here,
*   not chosen: the legacy screen carries it as a LABEL bound to
*   GS_DATA-PORT_STORAGE-AOID_TX, with no combobox, no Waiting List
*   checkbox and no PORT filter row anywhere in NE129_1_*. There is
*   nothing for the citizen to get wrong, so there is nothing to validate.
*
*   The base implementation is therefore left in place, which is the point
*   of not redefining: the inherited PAID gate keeps working, unchanged
*   and unrepeated. Copying E029's method across "for symmetry" would read
*   STORAGE_NUMBER_1 - a field this journey does not render - find it
*   blank on every run, and refuse to let anybody submit.
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



CLASS ZCL_E129_RENEW_STORE_LOGIC IMPLEMENTATION.


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

*     FIVE options here, against E029's TWO - so a store contract can be
*     RENEWED for longer than it could ever have been ISSUED for. That is
*     what both exports say and it is flagged as REVIEW-BE in
*     ZRAK_E129_LOAD; it is a business decision for EPDA, not a mapping
*     error, and the map below follows the export rather than quietly
*     capping it at two. If EPDA confirms the renewal should match the
*     issue, DROP the last three lines here AND the three matching option
*     rows in the feeder - changing only one of the two leaves options on
*     screen that write nothing, which is the worst of both.
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
