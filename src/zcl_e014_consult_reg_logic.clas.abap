class ZCL_E014_CONSULT_REG_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E014 - Consultancy Registration
*   (legacy NE014_1_*, seeded by ZRAK_E014_LOAD).
*
*   Deliberately small. Everything this journey needs that CAN be
*   expressed as configuration IS configuration:
*     - the applicant-type choice is a SEGMENTED field with three options
*     - revealing the owner lookup for a PRO/Manager applicant is two
*       SHOW rules in ZRAK_T_JNY_RULE
*     - the whole payment card comes from ZCL_RAK_JOURNEY_LOGIC
*   so only two things are left here, and both are things config cannot do:
*   fanning one segmented value back out into three backend flags, and
*   telling the payment engine which screen and which terms are this
*   journey's.
*
*   NOTE for anyone adding a show/hide here later: set_hidden( ) OUTRANKS
*   the rules for the rest of the session. The owner-finder visibility is
*   already handled by rules R001/R002, so calling set_hidden( ) on
*   OWNER_FINDER_BP from this class would not add to them - it would
*   silently take the decision away from them.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   One segmented field on screen, three booleans in the backend. The
*   legacy screen had three separate TBUTTONs, each bound to its own
*   GS_DATA-PARTNER_* flag; a segmented field carries ONE value, so the
*   chosen option has to be fanned back out into the three flags or the
*   backend receives nothing at all for the applicant's role.
    METHODS write_role_flags
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string.
ENDCLASS.



CLASS ZCL_E014_CONSULT_REG_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   The journey's own payment step. PREPARE_PAYMENT reads this to know
*   whose read BAdI resolves the gateway, and NE014_1_4 is that screen.
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'NE014_1_4' ).

*   ---- the payment terms block, from the legacy screen itself ----------
*   ZCL_RAK_JOURNEY_LOGIC->pay_terms draws these as radio lists, splitting
*   on '|', and falls back to platform defaults when they are blank. The
*   defaults are one method ("RAK.ae / quick payment") and one channel
*   ("RAK Pay"), which is NOT what this journey's legacy screen offered:
*   NE014_1_4 carries FOUR method radios (RB1..RB4) and TWO channel radios
*   (PW_RB1/PW_RB2). Setting them here is what keeps the migrated card
*   showing the same choices the citizen sees in production today.
*
*   The four method captions are the legacy label texts, verbatim -
*   "KISOK machine" included, misspelling and all, because that is the
*   caption in production and silently correcting it here would make the
*   two screens disagree.
    io_ctx->set_val( iv_name  = c_pay_method
                     iv_value = 'RAK.ae / quick payment|mRak|KISOK machine|Walk-in' ).

*   REVIEW-TEXT: the two channel radios have NO usable caption in the
*   export - PW_RB2's label row is empty and PW_RB1's resolves to the
*   literal 'X', which is placeholder text, not a caption. Their TECHNICAL
*   names are unambiguous though (EDIRHAM and CREDITCARD), so the captions
*   below are derived from those rather than left to the "RAK Pay"
*   default, which names neither. Replace with the real portal wording
*   when someone confirms it.
    io_ctx->set_val( iv_name  = c_pay_channel
                     iv_value = 'eDirham|Credit Card' ).

*   The charges bullets, verbatim from the legacy screen's LABEL_33..35.
*   Supplied rather than computed, for the reason the base class gives:
*   a percentage this framework prints and the gateway then bills
*   differently is a number the citizen was misled by.
*   REVIEW-BE: these are somebody else's numbers and they will change
*   without this class being touched. If a TVARV entry or a BAdI can serve
*   them, point PAY_CHARGES at that instead of at this literal.
    io_ctx->set_val(
      iv_name  = c_pay_charges
      iv_value = 'Cards Visa/MasterCard on RAK Government portal: 1.00%' &&
                 '|RAK Wallet: 0.80% with CAP 1000 AED' &&
                 '|The above bank charges are subject to VAT 5%' ).

*   REVIEW-BE: PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR deliberately not
*   set. They are FI-CA configuration for the EPDA registration fee -
*   a company code and a fee material - and nothing on a UI screen
*   carries them, so there is nothing in the legacy export to migrate.
*
*   Left blank rather than guessed on purpose: PREPARE_GATEWAY tests
*   both before it does anything else and refuses with "company code /
*   fee material were not supplied to the payment engine", so today Pay
*   is inert and says why. A guessed material would instead raise a real
*   fee against the wrong revenue account, which is the failure nobody
*   notices until reconciliation. Fill these in once EPDA Finance
*   confirms them:
*     io_ctx->set_val( iv_name = c_pay_bukrs    iv_value = '...' ).
*     io_ctx->set_val( iv_name = c_pay_material iv_value = '...' ).
*     io_ctx->set_val( iv_name = c_pay_casesfor iv_value = '...' ).
  ENDMETHOD.


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
ENDCLASS.
