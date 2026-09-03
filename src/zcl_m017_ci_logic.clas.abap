CLASS zcl_m017_ci_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M017 Comprehensive Investigation.
*&
*& TWO STEPS, AND NO PARCEL. This is the one Municipality journey in the
*& set that selects nothing: the citizen attaches a family book, names the
*& entity the investigation is for, optionally comments, and pays. There
*& is no parcel selector, no property list and no PLDTL table.
*&
*&   STP1  NCI_1_1   General information  attachment + entity + comment
*&   STP2  NCI_1_2   Fees & Payment
*&   ---   NCI_1_3   the CPG screen - PAY_SCREEN, never a CJS step
*&
*& IT POSTS THROUGH ZCL_EGA_CJ_FW_RO_ABS_V1, the MML abstract, NOT the
*& grants one - confirmed from ZCL_EGA_CJ_ENH_IMPL_M017_V1, which
*& inherits it. So the case is ZGCX, the owner role is TR0800, and
*& ZCL_RAK_MUN_LOGIC is the right base. It is the grants journeys
*& (M018/M019/M020) that need ZCL_RAK_GRANT_LOGIC.
*&
*& THE IMPLEMENTATION CLASS REDEFINES VALIDATE( ), AND WHAT IT CHECKS IS
*& THE ONE RULE THIS JOURNEY HAS: the same citizen may not have an open
*& case for the same entity. It joins ZDT_EGA_CS_2_BO to
*& SCMG_T_CASE_ATTR twice - once for ZGCX cases through characteristics
*& CJ12 and CJ07, once for ZL24 through ZDT_EGA_CAAT_OWN - and answers
*& ZMSG_EGA_CJ 008 naming every open case id it found.
*&
*& THAT CHECK IS THE BACKEND'S AND IS NOT REPEATED HERE. It needs
*& CJ07 characteristics and two case tables CJS has no business reading,
*& and it already runs on both CREATE and UPDATE. Re-implementing it
*& CJS-side would give two answers to one question and they would drift.
*& What this class adds is only what the backend cannot see.
*&
*& AND `properties IS INITIAL` IS COMMENTED OUT IN THE BACKEND'S OWN
*& VALIDATE( ), deliberately: ZMSG_EGA_CJ 010 - "no properties" - does
*& not apply to a journey that never asks for one. So do NOT add a
*& parcel requirement here to make it look like its siblings.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- this journey's own vocabulary ----------------------------------
*   EVERY NAME HERE IS THE LEGACY /QNV/ FIELD_NAME and must stay that
*   way: backend field control is keyed on it end to end, and
*   APPLY_CTRL( ) calling SET_HIDDEN with a name the journey does not
*   have is legal and does nothing.
*
*   CONFIRMED from ZCL_EGA_CJ_ENH_IMPL_M017_V1's own source:
*   CI_ENTITY_CODE (read in VALIDATE( )), CI_NOTE (the CJ11 long text in
*   READ( )'s CASE), CHECKBOX_2 and CHECKBOX_3 (both forced TOSAVE).
    CONSTANTS c_fld_entity  TYPE string VALUE 'CI_ENTITY_SELECT'.
    CONSTANTS c_fld_note    TYPE string VALUE 'ENTERTEXT'.

*   CONFIRMED FROM THE EXPORT. NCI_1_1 carries exactly one RAKUPLOADER
*   and it is called UPLOADER, with no DATA2 - so the attachment
*   reaches the case with a blank DIFFCRT, as the legacy screen does.
    CONSTANTS c_fld_family  TYPE string VALUE 'UPLOADER'.

*   Both checkboxes come back with TOSAVE forced true by the backend
*   read, which means the backend intends to store whatever they hold -
*   so they are real fields, not chrome. CHECKBOX_3 is the terms gate the
*   base class already enforces on the Pay press (its legacy
*   UI_FIELD_LOGICS is PAY-E); CHECKBOX_2 is this journey's own
*   declaration.
    CONSTANTS c_fld_declare TYPE string VALUE 'CHECKBOX_2'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

ENDCLASS.



CLASS zcl_m017_ci_logic IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. The chain is the engine's PAID
*   gate, then ZCL_RAK_MUN_LOGIC's own rule. A failing CHECK exits the
*   method and would take the gate with it.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   ---- the declaration, on the last step only -------------------------
*   CHECKBOX_2 is this journey's declaration and the backend stores it
*   (TOSAVE forced on the read), but nothing in the legacy screen makes
*   it a condition of anything. Left as a configured REQUIRED it would
*   only gate LEAVING the step - which on the last step is submitting,
*   and submitting is exactly when it should be checked. So config
*   carries the marker and this adds nothing.
*
*   THE ENTITY IS CONFIGURED REQUIRED AND THAT IS ENOUGH. It is a
*   dropdown on step 1, so VALIDATE_STEP( ) refuses Next without it long
*   before submit. Repeating it here would produce two messages for one
*   empty field.
*
*   SO THIS METHOD ADDS NOTHING TODAY, and it is here rather than absent
*   for one reason: an EMPTY redefinition of ON_CUSTOM_VALIDATE deletes
*   the PAID gate. Deleting the method entirely would be equivalent and
*   safe; keeping it with the SUPER-> call documented is what stops
*   somebody adding a rule later and forgetting the chain, which is how
*   E128 lost its gate twice.
    RETURN.

  ENDMETHOD.


ENDCLASS.
