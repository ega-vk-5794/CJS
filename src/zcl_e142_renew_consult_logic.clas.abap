CLASS zcl_e142_renew_consult_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Handler for E142 - Renew Consultancy Registration
*   (legacy NE014_2_*, seeded by ZRAK_E142_LOAD).
*
*   WHY THIS CLASS EXISTS AT ALL, because the feeder used to say it did
*   not need one and that was wrong.
*
*   The argument for shipping E142 handler-less was that it has no payment
*   card and no UI_FIELD_LOGICS row to translate, so ZCL_RAK_JOURNEY_LOGIC's
*   generic behaviour was the whole journey. Both halves of that are true
*   and the conclusion still does not follow. STP2 carries the same
*   three-way applicant-type group the registration journey has -
*   PARTNER_OWNER_1 / PARTNER_PRO_1 / PARTNER_MANAGER_1, one shared legacy
*   DATA1 group, three separate GS_DATA-PARTNER_* flags in the backend -
*   and the migrated SEGMENTED field carries ONE value bound to ONE of
*   those three members.
*
*   So without this class, a citizen who renews as a PRO writes the string
*   'PARTNER_PRO_1' into GS_DATA-PARTNER_OWNER and leaves
*   GS_DATA-PARTNER_PRO blank. The application posts, nothing errors, and
*   the backend records a renewal by the owner personally. That is exactly
*   the failure ZCL_E014_CONSULT_REG_LOGIC exists to prevent, and the two
*   journeys share the legacy control group that causes it.
*
*   Everything else this journey needs IS still configuration: the licence
*   picker, the four sections, the six uploads, the read-only owner panel.
*   This class does the one thing config cannot.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   Deliberately identical to ZCL_E014_CONSULT_REG_LOGIC's method of the
*   same name, rather than factored into a shared superclass. The two
*   journeys read the same legacy control group TODAY; they are separate
*   CJS journeys that can diverge tomorrow, and a shared base would make
*   changing one of them a change to both. Twelve duplicated lines is the
*   cheaper mistake.
    METHODS write_role_flags
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string.
ENDCLASS.



CLASS ZCL_E142_RENEW_CONSULT_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_change.
    IF to_upper( iv_field ) = c_applicant_type.
      write_role_flags( io_ctx = io_ctx iv_pick = io_ctx->get_val( c_applicant_type ) ).
    ENDIF.
  ENDMETHOD.


  METHOD write_role_flags.
*   Every flag written on every change, not just the chosen one - the
*   citizen who picks Manager after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both.
    DATA(lt_role) = VALUE zif_rak_journey=>tt_kv(
      ( key = `PARTNER_OWNER_1`   value = `GS_DATA-PARTNER_OWNER` )
      ( key = `PARTNER_PRO_1`     value = `GS_DATA-PARTNER_PRO` )
      ( key = `PARTNER_MANAGER_1` value = `GS_DATA-PARTNER_MANAGER` ) ).

    LOOP AT lt_role INTO DATA(ls_role).
      io_ctx->set_val( iv_name  = ls_role-value
                       iv_value = COND string( WHEN ls_role-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.

*   NO on_init REDEFINITION, and that is the point of the journey rather
*   than an omission: there is no RAKPAY, no RAKREMAININGFEES and no fee
*   CLIST anywhere in NE014_2_*, and the last screen's NEXT button carries
*   D3 = SUBMIT rather than a pay event. So there is no PAY_SCREEN to name
*   and no payment terms to supply. If a renewal fee is introduced later,
*   this is where PAY_SCREEN / PAY_METHOD / PAY_CHANNEL / PAY_CHARGES go -
*   and STP4 needs NEXT_REQUIRES = 'PAYFEE' in the feeder at the same time.
ENDCLASS.
