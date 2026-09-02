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

*   ============ EVERY NAME HERE IS THE LEGACY FIELD NAME ================
*
*   AND THAT IS A HARD REQUIREMENT, NOT A CONVENTION. The backend's field
*   control only reaches a CJS field whose FIELD_NAME equals the legacy
*   /QNV/SB_UI_DEFIN FIELD_NAME, because the whole chain is keyed on it:
*
*     ZCL_RAK_QNV_BRIDGE->SEED_CTRL( )  looks the field up as
*         READ TABLE ls_s-fields WITH KEY name = to_upper( iv_field )
*         where iv_field is the DEFINITION ROW's FIELDNAME - so a CJS field
*         under any other name is never found, and the row goes out with
*         the neutral defaults instead of this journey's configuration.
*     ZCL_RAK_QNV_BRIDGE->CTRL_OF( )    reports back keyed on
*         is_def-fieldname, the same legacy name.
*     ZCL_RAK_JOURNEY_BE->APPLY_CTRL( ) then calls SET_HIDDEN / SET_READONLY
*         / SET_REQUIRED with that name - and SET_HIDDEN( ) on a field name
*         the journey does not have is legal and does NOTHING.
*
*   So a renamed field does not merely miss a nicety: MANDATORY, ENABLED and
*   VISIBLE from the live field-control engine all silently fail to apply,
*   and the failure looks exactly like a backend that never sent them.
*
*   The first version of these feeders used tidier names - PARCELSEL,
*   DOC_TITLEDEED, DOC_ID - and would have had no field control at all.
*   Do not rename them.
*
*   RAKPARCELSELECTOR, not PARCELSELECTOR: the export's FIELD_NAME on
*   NSUBDIVISION_1_1 / NMERGE_1_1 / NCBR_1_1 is PARCELSELECTOR and the
*   CONTROL_TYPE is RAKPARCELSELECTOR. The FIELD_NAME is what is keyed on.
    CONSTANTS c_fld_parcel  TYPE string VALUE 'PARCELSELECTOR'.

*   The chosen-parcels grid. Only M012 has one; PARCEL_ROWS( ) is written so
*   the constant is harmless on the other two.
*
*   A FIELD NAME NOT ON THE JOURNEY IS SILENT: get_val / get_grid_data /
*   set_val / bind against it are all legal and all do nothing. That is why
*   HAS_PARCEL( ) checks the selector first rather than trusting a row
*   count - see the note in PARCEL_ROWS( ).
    CONSTANTS c_fld_parcels TYPE string VALUE 'RAKPARCELS'.

*   The applicant's own description of what they want done. The legacy
*   FIELD_NAME is 'EnterText' and the TECHNICAL_NAME is PLOTLONGTEXT; the
*   field name is what the field control keys on, upper-cased by the engine.
*   It lands on characteristic CJ11 and on the RE note
*   <intreno>#CJ11#00000000.
    CONSTANTS c_fld_note    TYPE string VALUE 'ENTERTEXT'.

*   ---- the two CONDITIONAL DOCUMENT GROUPS ---------------------------
*   Both are driven entirely by the backend, in
*   ZCL_EGA_CJ_FW_RO_ABS_V1->FIELD_CONTROL( ), which reads the parcel's own
*   state and then clears ISVISIBLE on the matching CONTROLGROUP:
*
*     NOC     the bank's no-objection certificate. Hidden unless the parcel
*             is MORTGAGED  (<fs_parcel>-is_mortgaged = abap_true).
*     LETTER  the other owners' letter of consent. Hidden unless the parcel
*             has MORE THAN ONE TR0800 owner  (line_exists( partners[ 2 ] )).
*
*   THE CJS FIELD IS NAMED AFTER THE CONTAINER, and that is deliberate. In
*   the legacy screen NOCCONT and LETTERCONT are VBOXes each holding one
*   RAKUPLOADER (UPLOADER1 and UPLOADER2) plus its labels, and the BAdI
*   hides the CONTAINER - not the uploader. CJS has no containers, so the
*   group collapses to the one control that matters and takes the
*   container's name; the hide then lands on it through the ordinary
*   mechanism, with nothing duplicated and no second opinion on when to
*   show it.
*
*   THEY ARE REQUIRED AND THAT IS SAFE. Both are MANDATORY = X in the
*   export, and mandatory is correct WHEN SHOWN - a mortgaged parcel does
*   need the bank's NOC. ZCL_RAK_JOURNEY_RULES->VALIDATE_STEP( ) skips
*   hidden fields (`IF is_hidden( ls_f ) = abap_true. CONTINUE.`), so a
*   sole owner of an unmortgaged parcel is not blocked by two uploads they
*   can never see. Checked, because the alternative failure is a step
*   nobody can leave.
    CONSTANTS c_fld_noc    TYPE string VALUE 'NOCCONT'.
    CONSTANTS c_fld_letter TYPE string VALUE 'LETTERCONT'.

*   ---- the payment step's two checkboxes ------------------------------
*   CHECKBOX_3 and CHECKBOX_4 are the legacy FIELD_NAMEs; ACCEPT_TERMS and
*   DONATE are their TECHNICAL_NAMEs, which is a different key and is what
*   the feeders put in TECH_NAME.
*
*   CHECKBOX_3 carries UI_FIELD_LOGICS 'PAY-E' on the legacy screen - it
*   ENABLES the Pay button - which is why ON_POPUP_EVENT below refuses the
*   press without it rather than leaving it to step validation.
    CONSTANTS c_fld_terms  TYPE string VALUE 'CHECKBOX_3'.
    CONSTANTS c_fld_donate TYPE string VALUE 'CHECKBOX_4'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

*   ---- the case, and when it comes into existence ---------------------
*   MUNICIPALITY DIFFERS FROM EPDA HERE, and it matters for the Pay button.
*
*   On these journeys the container case is created the moment the fee step
*   POSTS - not on submit. ZIF_EGA_FW_CJI~UPDATE( ) does it:
*
*       READ TABLE ct_item_data ... WITH KEY technicalname = 'TOTALFEESVALUE'
*       IF sy-subrc = 0 AND line_exists( mt_ui_map[ objectkey = 'FEES_1' ] ).
*         payment_check( ) ... IF caseid IS INITIAL. create_dummy_case( ).
*
*   so pressing Next on the fees screen is what calls
*   ZFM_EGA_CREATE_CASE_GEN for case type ZGCX and writes the new case id to
*   characteristic CJ12.
*
*   THE BASE CLASS ALREADY HANDLES THE PAY PRESS CORRECTLY and this class
*   deliberately does NOT re-implement it. ZCL_RAK_JOURNEY_LOGIC's
*   ON_POPUP_EVENT( PAYNOW ) sets PAY_STARTED, sets STATUS = 'PAYMENT',
*   calls COMMIT_STEP( ) - which is the post that makes the backend create
*   the case if it does not exist yet - and RETURNS without reaching the
*   gateway when that commit fails. That is exactly "if there is no case,
*   create it first, then go to payment", and it is why COMMIT_STEP( )
*   exists at all.
*
*   WHAT IS ADDED BELOW is the one thing the base cannot know: the fee
*   total. The backend only creates the case when TOTALFEESVALUE is in the
*   posted items, so a Pay press with no total posts, creates nothing, and
*   sends the citizen to a gateway with no open item to bill against - a
*   dead payment screen that looks like a gateway fault. Refusing it here
*   costs one comparison.
    METHODS zif_rak_journey_logic~on_popup_event REDEFINITION.

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


  METHOD zif_rak_journey_logic~on_popup_event.

*   THE FEE TOTAL GATE, BEFORE THE BASE DOES ANYTHING.
*
*   Checked first and only for the Pay press, because on every other event
*   this method must reach super untouched: ON_POPUP_EVENT is the BP and
*   attachment machinery for the whole framework, and a redefinition that
*   does not chain deletes all of it. That is not hypothetical - it is one
*   of the four hooks CLAUDE.md names for exactly this reason.
    IF iv_event CP |*{ c_pay_now }*|.

*     TOTALFEESVALUE IS WHAT MAKES THE BACKEND CREATE THE CASE. See the
*     declaration: ZIF_EGA_FW_CJI~UPDATE( ) branches on finding it in the
*     posted items, and without it CREATE_DUMMY_CASE( ) is never reached.
*     So a Pay press with no total does post, creates nothing, and then
*     sends the citizen to a gateway with no open item behind it.
*
*     PAY_TOTAL is the engine's own carrier for the payable amount, filled
*     from the backend's fee read - so this asks "does the card know what it
*     is charging", which is the same question one step earlier.
      DATA(lv_total) = condense( io_ctx->get_val( c_pay_total ) ).

*     '0' and '0.00' are a total the citizen cannot pay, not a total. A fee
*     journey whose fee read answered nothing arrives here looking exactly
*     like one that has not been read yet.
      REPLACE ALL OCCURRENCES OF '.' IN lv_total WITH ''.
      REPLACE ALL OCCURRENCES OF ',' IN lv_total WITH ''.
      SHIFT lv_total LEFT DELETING LEADING '0'.

*     AND THE TERMS, WHICH IS THE LEGACY 'PAY-E' SEMANTIC ENFORCED.
*
*     CHECKBOX_3's UI_FIELD_LOGICS on the legacy screen is 'PAY-E' - it
*     ENABLES the Pay button, so on the live service Pay is dead until the
*     citizen accepts. CJS cannot reproduce that from configuration: the
*     PAYFEE card is drawn whole by ZCL_RAK_JOURNEY_LOGIC->RENDER_FIELD( )
*     and its Pay button is inside it, so nothing in ZRAK_T_JNY_FLD can
*     grey it out. REQUIRED on the checkbox only makes it a condition of
*     LEAVING the step - which on the last step of the journey is a
*     condition of submitting, not of paying.
*
*     Left at that, a citizen can press Pay, complete a real payment at the
*     gateway, and only then be told they had to accept terms first. So the
*     press is refused here instead. Same outcome as the legacy disabled
*     button, one step later and with a reason given.
*
*     REORDERING WAS THE OTHER OPTION AND IS WORSE. Putting the checkbox
*     above PAYFEE by SEQNR does put it above the Pay button - and also
*     above the fee table and the total, so the citizen accepts terms
*     before being shown the amount. The card cannot be reordered
*     internally from config.
      DATA(lv_terms) = io_ctx->get_val( c_fld_terms ).

      IF lv_terms <> 'X' AND lv_terms <> 'true' AND lv_terms IS NOT INITIAL.
*       Any other non-blank is still an acceptance - the renderer's own
*       checkbox writes 'X', but a value arriving from a draft or a
*       backend read is not guaranteed to, and refusing a payment over the
*       spelling of a boolean would be a worse failure than accepting a
*       loose one.
        CLEAR lv_terms.
        lv_terms = 'X'.
      ENDIF.

      IF lv_terms IS INITIAL.
        io_ctx->add_msg(
          iv_type = 'Error'
          iv_text = COND string(
            WHEN sy-langu = 'A'
            THEN `يرجى قبول الشروط والأحكام قبل الدفع.`
            ELSE `Accept the Terms & Conditions before paying.` ) ).
        RETURN.
      ENDIF.

      IF lv_total IS INITIAL.
        io_ctx->add_msg(
          iv_type = 'Error'
          iv_text = COND string(
            WHEN sy-langu = 'A'
            THEN `لم يتم تحديد الرسوم بعد. يرجى العودة إلى خطوة الرسوم والمحاولة مرة أخرى.`
            ELSE `The fees for this request are not available yet. ` &&
                 `Go back to the fees step and try again.` ) ).
*       RETURN without chaining, deliberately and only on this branch: the
*       point is to stop the payment starting. PAY_STARTED has not been set
*       yet - the base sets it - so the button stays live and the citizen
*       can retry once the fees are there.
        RETURN.
      ENDIF.

    ENDIF.

*   EVERYTHING ELSE, AND THE PAY PRESS THAT PASSED, GOES TO THE BASE. It is
*   the base that sets PAY_STARTED, sets STATUS = 'PAYMENT', calls
*   COMMIT_STEP( ) - the post on which the backend creates the case - and
*   refuses to reach the gateway if that commit fails.
    super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                 iv_id    = iv_id
                                                 iv_event = iv_event ).

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
