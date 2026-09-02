CLASS zcl_rak_mun_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& The Municipality family's shared handler.  M011, M012, M016 inherit it.
*&
*& NOT FINAL and not abstract: the three journeys differ in almost nothing
*& that is code, so they inherit this and redefine at most one method each.
*& Concrete because a fourth Municipality journey with no peculiarities can
*& point HANDLER_CLASS straight at this class and get the whole contract.
*&
*& INHERITING, NEVER `INTERFACES zif_rak_journey_logic`. The interface
*& obliges all ~25 methods and the class will not activate; inheriting gives
*& the empty defaults plus the payment card and the PAID gate.
*&
*& ============ WHAT THIS CLASS DELIBERATELY DOES NOT DO ===============
*&
*& IT DOES NOT RE-IMPLEMENT THE LEGACY VALIDATIONS, and that is the main
*& design decision here rather than an omission.
*&
*& ZCL_EGA_CJ_FW_RO_ABS_V1->VALIDATE( ) already enforces, on every post
*& through ZFM_EGA_CJ_FW_POST_N:
*&
*&   - one location hierarchy across all selected parcels   (ZMSG_EGA_CJ 004)
*&   - no parcel already inside an open ZGCX container      (005)
*&   - every parcel has a TR0800 owner role                 (006)
*&   - no YTR080 grant role on any parcel                   (007)
*&   - at least one parcel actually owned by the applicant   (011)
*&   - no duplicate parcels                                  (012)
*&   - no building on the parcel at status 03, under construction (013)
*&   - parcel not in status E0012/E0013/E0014/E0017          (031)
*&   - ZCM_CASE_PARCEL_CHARACT_PERMIT per parcel, per case type
*&
*& Every one of those needs VILMPL, VIBPOBJREL, VIBDAO, JEST, SCMG_T_CASE_ATTR
*& and a function module. Copying them here would fork nine domain rules that
*& nobody will keep in step, and the copy would be the one that goes stale -
*& the legacy path is still live for the ShapeIt screens.
*&
*& So the split is: THE BACKEND OWNS THE DOMAIN RULES, and this class only
*& adds what makes the citizen's round trip better - a missing parcel caught
*& before a post rather than after one. A rejection from the backend surfaces
*& through the engine's own message channel either way.
*&
*& ============ THE FOUR HOOKS THAT ARE NOT EMPTY =======================
*&
*& An empty redefinition is a DELETION, not a no-op. Of the base's methods
*& four do real work - ON_CUSTOM_VALIDATE is the PAID gate, RENDER_FIELD is
*& the payment card, ON_POPUP_EVENT is the BP and attachment machinery, and
*& WANTS_FEEDBACK returns true. This class redefines exactly one of them and
*& chains it. RENDER_FIELD, ON_POPUP_EVENT and WANTS_FEEDBACK are left alone
*& on purpose: all three of these journeys want the payment card, and E128
*& lost its PAID gate and D020 lost its fee card to redefinitions that looked
*& deliberate and were not.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   The parcel the citizen picked. One field name across the family, so this
*   class can check it without knowing which journey it is running for. The
*   feeders all use it.
    CONSTANTS c_fld_parcel  TYPE string VALUE 'PARCELSEL'.

*   The added-parcel grid. Only M012 has one; the check below is guarded on
*   the field existing, so the constant is harmless on the other two.
*
*   A FIELD NAME NOT ON THE JOURNEY IS SILENT: get_val/set_val/bind against
*   it are all legal and all do nothing. That is why this is guarded rather
*   than assumed - see the guard in HAS_PARCEL( ).
    CONSTANTS c_fld_parcels TYPE string VALUE 'PARCELS'.

*   The applicant's own description of what they want done, CJ11 on the
*   legacy side. Mandatory on all three screens.
    CONSTANTS c_fld_note    TYPE string VALUE 'PLOTLONGTEXT'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

*   ---- the two fee-bearing exceptions --------------------------------
*   These two are the ONE case where not chaining is correct, and they are
*   named as the exception in CLAUDE.md for exactly this reason. Their base
*   bodies are:
*
*       DELETE ct_kv     WHERE key  CP 'PAY_*'.
*       DELETE ct_kv     WHERE key  = c_pay_field.
*       DELETE ct_fields WHERE name CP 'PAY_*'.
*       DELETE ct_fields WHERE name = c_pay_field.
*
*   - they strip the payment state out of the post. That is right for a
*   journey with no fee and wrong for these three, where the legacy screen
*   posts TOTALFEESVALUE and the payment channel radios and the backend
*   writes them into ZEGA_T_CJ_PAYUPD. Redefining them EMPTY keeps the
*   payment fields in the payload, which is the intended behaviour.
*
*   This is the only place in this class where an empty redefinition is
*   deliberate, and it is only safe because the base body is a strip rather
*   than a feature. D001, D025 and E027 do the same and for the same reason.
    METHODS zif_rak_journey_logic~on_before_post   REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_fields REDEFINITION.

  PROTECTED SECTION.

*   Has the citizen chosen a parcel yet - by the selector, or by the added
*   parcel grid where the journey has one. PROTECTED so a subclass can reuse
*   it; M012 does.
    METHODS has_parcel
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE abap_bool.

*   How many rows the parcel grid holds. Zero when the journey has no grid,
*   which is the honest answer for M011 and M016 and is why the caller must
*   not read it as "no parcels".
    METHODS parcel_rows
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE i.

ENDCLASS.



CLASS zcl_rak_mun_logic IMPLEMENTATION.


  METHOD has_parcel.
    IF io_ctx->get_val( c_fld_parcel ) IS NOT INITIAL.
      rv = abap_true.
      RETURN.
    ENDIF.
    rv = xsdbool( parcel_rows( io_ctx ) > 0 ).
  ENDMETHOD.


  METHOD parcel_rows.
*   GET_GRID_DATA( ), not GET_VAL( ). The interface is explicit that
*   get_val( ) returns BLANK for a grid - the model member is a JSON string
*   and the accessor deliberately refuses it - so reading the grid field as a
*   scalar would answer "empty" for a full table.
*
*   AND GET_GRID_DATA( ) ON A FIELD THAT IS NOT ON THE JOURNEY ANSWERS AN
*   EMPTY STRUCTURE AND RAISES NOTHING, which is the same silent-failure
*   trap. So the zero this returns for M011 and M016 - which have no parcel
*   grid at all - is indistinguishable from a grid the citizen has not filled
*   in. HAS_PARCEL( ) is the method that knows that and checks the selector
*   first; a caller reading this one on its own has to know it too.
    rv = lines( io_ctx->get_grid_data( c_fld_parcels )-rows ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. The base implementation is the PAID
*   gate; a redefinition REPLACES it, so omitting this call silently removes
*   payment protection - which is precisely how E128 became submittable
*   unpaid, twice. And it has to come before a CHECK because a failing CHECK
*   exits the method, taking the gate with it.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*   VALUE #( BASE rt ... ) below rather than `rt = VALUE #( ... )`, so what
*   the gate returned is extended rather than discarded.

*   Only the parcel step. The field is on the first step of all three
*   journeys, and the check is meaningless anywhere else.
    IF io_ctx->get_val( c_fld_parcel ) IS INITIAL AND parcel_rows( io_ctx ) = 0.
*     Guarded on the field being ON this step, not merely on the journey:
*     otherwise every later step would refuse to advance because a field it
*     does not show is empty.
      IF iv_step = 0.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `يرجى اختيار قطعة أرض للمتابعة.`
              ELSE `Select a parcel before continuing.` ) ) ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_fields.
*   DELIBERATELY EMPTY - see the declaration. The base strips PAY_* and
*   PAYFEE out of the field list; these journeys are fee-bearing and need
*   them to reach the backend. Do not "tidy" this by chaining to super.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
*   DELIBERATELY EMPTY - see the declaration and ON_BEFORE_FIELDS above.
*
*   NEVER CALL COMMIT_STEP( ) FROM HERE. This method already runs INSIDE the
*   post that COMMIT_STEP( ) triggers, so calling it re-enters the post it is
*   inside of. The payment path creates the case lazily from the citizen's
*   own PAYNOW event instead, which is what COMMIT_STEP( ) exists for.
  ENDMETHOD.


ENDCLASS.
