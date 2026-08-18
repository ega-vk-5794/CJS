CLASS zcl_e146_consult_appeal_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Migrated from NE014_3_1..5 (EPDA) by ZRAK_EPDA_MIGRATE6 / ZCL_RAK_MIGRATOR -
*   the Appeal sub-flow of the E014 legacy screen family (shares its raw
*   BKND_JOURNEY 'E014' - see the REVIEW-TECH note in ZRAK_EPDA_MIGRATE6).
*
*   Step 1 (NE014_3_1): APPEALS, an MTABLE - the case(s) the consultant can
*   appeal against. Projects as a pick-list EDITABLE_TABLE via
*   ZCL_RAK_MIGRATOR->grid_spec (DATA3 SingleSelect -> SEL:/_PICK column),
*   so the selection itself needs no handler code.
*
*   Step 2 (NE014_3_2): APPEAL_REASON_1, a required TEXTAREA - enforced by
*   the migrated REQUIRED flag, no handler needed.
*
*   REVIEW-CONTAINER: NE014_3_2 also carries the same three-way
*   PARTNER_OWNER_1/PARTNER_PRO_1/PARTNER_MANAGER_1 toggle seen on E014,
*   feeding an OWNER_FINDER container - but here OWNER_FINDER's own child
*   is a PANEL (PANEL_2), not a PERSON_SEARCH. What PANEL_2 actually shows
*   is not visible from /QNV/SB_UI_DEFIN's field-level export (a PANEL is
*   a container, not a field with resolvable content), so - unlike
*   ZCL_E014_CONSULT_REG_LOGIC / ZCL_E015_ENV_STUDY_LOGIC / ZCL_E027_VICE_CAPTAIN_LOGIC,
*   whose OWNER_FINDER always resolves to one concrete PERSON_SEARCH field -
*   no show/hide is wired here rather than guess PANEL_2's contents. If a
*   citizen ends up seeing an appeal-role panel that should have toggled
*   and did not, this is why: come back here with the real PANEL_2 layout.
*
*   Step 4 (NE014_3_4) carries the same RAKPAY the E014/E015 registration
*   flows do; PAYFEE is restored on it by ZRAK_EPDA_MIGRATE6.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_init REDEFINITION.
ENDCLASS.



CLASS ZCL_E146_CONSULT_APPEAL_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   PAY_SCREEN is real: NE014_3_4 is this journey's own migrated payment
*   step (PAYFEE restored there by ZRAK_EPDA_MIGRATE6).
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'NE014_3_4' ).

*   REVIEW-BE: PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR - same open item as
*   ZCL_E014_CONSULT_REG_LOGIC (an appeal fee is very likely a DIFFERENT
*   material from the registration fee it shares a screen family with -
*   do not assume they are the same code without confirming with EPDA
*   Finance).
  ENDMETHOD.
ENDCLASS.
