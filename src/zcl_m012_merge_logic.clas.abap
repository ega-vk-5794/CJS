CLASS zcl_m012_merge_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M012 - Request for Plots Merge (legacy NMERGE_1_1..1_4).
*&
*& THE ONE THING M012 NEEDS THAT THE FAMILY DOES NOT: a merge of one parcel
*& is not a merge. The legacy screen carries TWO controls on step 1 -
*& PARCELSELECTOR for the citizen's own parcels and ADDPRCLCTL (ADDPARCELS)
*& for one they do not own - and then RAK_PARCELS on step 2 listing what was
*& chosen. Nothing in /QNV/SB_UI_DEFIN says two is the minimum; it is in the
*& nature of the service.
*&
*& WHY THIS ONE IS WORTH DOING CJS-SIDE when the other nine validations are
*& deliberately left to the backend: it needs no table read. Every rule in
*& ZCL_EGA_CJ_FW_RO_ABS_V1->VALIDATE( ) needs VILMPL, VIBPOBJREL, JEST or a
*& function module, so a copy here would fork domain logic and go stale. A
*& row count does not. It saves the citizen a post that the backend would
*& reject anyway, and it cannot disagree with the backend because it is not
*& re-deciding anything the backend decides.
*&
*& REVIEW-BE: whether the legacy service ALSO refuses a single-parcel merge,
*& and with which message, is not established - VALIDATE( ) has no such
*& check and the "at least one owned parcel" rule (ZMSG_EGA_CJ 011) is a
*& different condition. If it turns out the backend permits it, this class is
*& stricter than the service it replaces and that is a decision for the
*& owning team, not a defect to fix quietly.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   A merge needs two. Named rather than inline so the number is findable.
    CONSTANTS c_min_parcels TYPE i VALUE 2.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_m012_merge_logic IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. This chains TWO levels - the
*   family's "pick a parcel" check in ZCL_RAK_MUN_LOGIC, which itself chains
*   ZCL_RAK_JOURNEY_LOGIC's PAID gate. Skipping it here would remove both,
*   and the payment one silently.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*   Step 1 only - steps count from ZERO in hooks, so the parcel step is 0.
    CHECK iv_step = 0.

*   AND ONLY WHEN SOMETHING WAS CHOSEN. With nothing chosen at all the base
*   has already said "select a parcel", and two messages for one empty
*   screen reads as two problems.
    DATA(lv_rows) = parcel_rows( io_ctx ).
    CHECK lv_rows > 0 OR io_ctx->get_val( c_fld_parcel ) IS NOT INITIAL.

*   The selector's own pick counts as one, and the grid holds the rest. A
*   citizen who picked one of their own and added one they do not own has
*   two, which is a valid merge.
    DATA(lv_total) = lv_rows.
    IF io_ctx->get_val( c_fld_parcel ) IS NOT INITIAL.
      lv_total = lv_total + 1.
    ENDIF.

    IF lv_total < c_min_parcels.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = COND string(
            WHEN sy-langu = 'A'
            THEN `يجب اختيار قطعتي أرض على الأقل للدمج.`
            ELSE `Select at least two parcels to merge.` ) ) ).
    ENDIF.

  ENDMETHOD.


ENDCLASS.
