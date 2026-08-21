class ZCL_E146_CONSULT_APPEAL_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E146 - Consultant Appeal
*   (legacy NE014_3_*, seeded by ZRAK_E146_LOAD).
*
*   The third sub-flow of the E014 legacy screen family: registration is
*   NE014_1_*, renewal NE014_2_*, this appeal NE014_3_*. All three share
*   backend class ZCL_EGA_CJ_CONSULTANT_ABS and raw journey code E014, so
*   BKND_JOURNEY is E014 while the CJS journey_id is E146 - which the
*   legacy configuration itself agrees with, since every NE014_3_* screen
*   carries a JOURNEYTYPE row with VALUE = 'E146'.
*
*   Deliberately small. Everything this journey needs that CAN be
*   expressed as configuration IS configuration:
*     - STP1's case picker is an EDITABLE_TABLE with five READONLY columns
*       in ZRAK_T_JNY_COL, fed by the backend read; the D3 =
*       SingleSelectLeft on the legacy MTABLE means one case per appeal,
*       and the grid handles the selection itself
*     - APPEAL_REASON_1 is a REQUIRED TEXTAREA with MAX_LEN 250, enforced
*       by the engine's own validation
*     - the whole payment card comes from ZCL_RAK_JOURNEY_LOGIC
*   so what is left here is the applicant-role fan-out and the payment
*   wiring, both of which config cannot do.
*
*   REVIEW-CONTAINER: NE014_3_2 also carries the three-way applicant-type
*   toggle feeding an OWNER_FINDER > PANEL_2 container, which on E014 is
*   shown or hidden by that toggle. This screen carries NO UI_FIELD_LOGICS
*   row, so the feeder authors the four owner rows always-visible and no
*   show/hide is wired here either - see the matching note in
*   ZRAK_E146_LOAD. If a citizen ends up seeing an owner panel that should
*   have toggled and did not, that is why: the fix is two SHOW rules in the
*   feeder, not set_hidden( ) here. set_hidden( ) OUTRANKS the rules for
*   the rest of the session, so putting the logic in this class would take
*   the decision away from config permanently.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_login_bp TYPE string VALUE 'LOGIN_BP' ##NO_TEXT.
    CONSTANTS c_partner_name TYPE string VALUE 'PARTNER_NAME' ##NO_TEXT.
    CONSTANTS c_PARTNER_ID TYPE string VALUE 'PARTNER_ID' ##NO_TEXT.
    CONSTANTS c_APPLICANTTYPE1 TYPE string VALUE 'APPLICANTTYPE' ##NO_TEXT.
    CONSTANTS c_lang_en TYPE string VALUE 'E' ##NO_TEXT.

*   One segmented field on screen, three booleans in the backend. Same
*   idiom and same reason as ZCL_E014_CONSULT_REG_LOGIC and
*   ZCL_E142_RENEW_CONSULT_LOGIC: the legacy screen had three separate
*   TBUTTONs, each bound to its own GS_DATA-PARTNER_* flag, and a
*   segmented field carries ONE value - so the chosen option has to be
*   fanned back out or the backend receives nothing for the applicant's
*   role. Duplicated rather than factored into a shared base class,
*   because the three journeys can diverge and a shared base would make
*   changing one a change to all three.
    METHODS write_role_flags
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string.
ENDCLASS.



CLASS ZCL_E146_CONSULT_APPEAL_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   The journey's own payment step. PREPARE_PAYMENT reads this to know
*   whose read BAdI resolves the gateway, and NE014_3_4 is that screen -
*   this journey's OWN payment screen, not the standalone pay app and not
*   the registration flow's NE014_1_4 that it is otherwise identical to.
*   Routing an in-journey payment through another journey's screen finishes
*   the payment but not the journey.
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'NE014_3_4' ).

*   ---- the payment terms block, from the legacy screen itself ----------
*   NE014_3_4 is field-for-field identical to NE014_1_4, so these are the
*   same four method radios (RB1..RB4) and two channel radios
*   (PW_RB1/PW_RB2) the registration journey has, with the same captions.
*   They are set per journey rather than in the base class because the
*   base class's defaults name one method and one channel, which is not
*   what either screen offers.
*
*   "KISOK machine" keeps the legacy misspelling: it is the caption in
*   production, and silently correcting it here would make the migrated
*   card and the live screen disagree.
    io_ctx->set_val( iv_name  = c_pay_method
                     iv_value = 'RAK.ae / quick payment|mRak|KISOK machine|Walk-in' ).

*   REVIEW-TEXT: the two channel radios have NO usable caption in the
*   export - PW_RB2's label row is empty and PW_RB1's resolves to the
*   literal 'X'. Their TECHNICAL names are unambiguous (EDIRHAM and
*   CREDITCARD), so the captions below are derived from those. Replace
*   with the real portal wording when someone confirms it.
    io_ctx->set_val( iv_name  = c_pay_channel
                     iv_value = 'eDirham|Credit Card' ).

*   The charges bullets, verbatim from the legacy screen's LABEL_33..35.
*   REVIEW-BE: these are somebody else's numbers and they will change
*   without this class being touched. If a TVARV entry or a BAdI can serve
*   them, point PAY_CHARGES at that instead of at this literal.
    io_ctx->set_val(
      iv_name  = c_pay_charges
      iv_value = 'Cards Visa/MasterCard on RAK Government portal: 1.00%' &&
                 '|RAK Wallet: 0.80% with CAP 1000 AED' &&
                 '|The above bank charges are subject to VAT 5%' ).

*   REVIEW-BE: PAY_BUKRS / PAY_MATERIAL / PAY_CASESFOR deliberately not
*   set - the same open item as ZCL_E014_CONSULT_REG_LOGIC, and here it
*   needs its own answer rather than that journey's: an APPEAL fee is very
*   likely a DIFFERENT fee material from the registration fee it shares a
*   screen family with. Do not copy E014's values across once they arrive.
*
*   Left blank rather than guessed: PREPARE_GATEWAY tests the first two
*   before it does anything else and refuses with "company code / fee
*   material were not supplied to the payment engine", so today Pay is
*   inert and says why. A guessed material would instead raise a real fee
*   against the wrong revenue account, which is the failure nobody notices
*   until reconciliation. Fill these in once EPDA Finance confirms them:
*     io_ctx->set_val( iv_name = c_pay_bukrs    iv_value = '...' ).
*     io_ctx->set_val( iv_name = c_pay_material iv_value = '...' ).
*     io_ctx->set_val( iv_name = c_pay_casesfor iv_value = '...' ).

    DATA: lv_loginbp TYPE bu_partner.
    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

    IF lv_loginbp IS NOT INITIAL.
      NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
        EXPORTING
          iv_bp_id      = lv_loginbp
        IMPORTING
          es_bp_details = DATA(ls_bp) ).

      io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).

      IF sy-langu = c_lang_en.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = c_applicanttype1 iv_value = |{ lv_role }| ).

    ELSE.


      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '1000116563' ).
*
**    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
**    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
*
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
*      io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).

    ENDIF.

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


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES.
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SEL' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'APPEALS' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  endmethod.
ENDCLASS.
