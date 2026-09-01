class ZCL_E015_ENV_STUDY_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E015 - Environmental Study
*   (legacy NE015_1_*, seeded by ZRAK_E015_LOAD).
*
*   NE015_1_1 carries the same OWNER_FINDER building block E014 does
*   (same shared LABEL_CON EPDA_NE014_1_1_TBUTTON_1) but with a DIFFERENT,
*   TWO-way group: PARTNER_OWNER_1 / PARTNER_REP_1 (Owner /
*   Representative), not E014's three-way Owner / PRO / Manager. Confirmed
*   from the real /QNV/SB_UI_DEFIN DATA1 group membership - not assumed
*   from the shared block.
*
*   ---------------------------------------------------------------------
*   THIS CLASS USED TO SHOW THE OWNER LOOKUP BACKWARDS. Worth recording,
*   because the mistake is easy to repeat and it fails silently.
*
*   It carried its own show/hide code, in on_after_read and on_change, that
*   revealed the OWNER_1 lookup when the applicant type was
*   PARTNER_OWNER_1 and hid it otherwise. The legacy UI_FIELD_LOGICS says
*   the opposite, unambiguously:
*       PARTNER_OWNER_1  ->  OWNER_FINDER-V-F   (Owner  -> HIDE)
*       PARTNER_REP_1    ->  OWNER_FINDER-V-T   (Rep    -> SHOW)
*   which is counter-intuitive but correct: the owner lookup is there to
*   identify the owner somebody ELSE is applying on behalf of, so it
*   appears for a representative and never for the owner applying
*   personally. The old code therefore asked the owner to look themselves
*   up, and hid the field in the one case it was needed. Nothing errored -
*   it just collected the wrong data, or none.
*
*   The visibility now lives in ZRAK_T_JNY_RULE as rule R001 (SHOW
*   OWNER_1 when PARTNER_OWNER_1 = PARTNER_REP_1), with the field authored
*   HIDDEN in the feeder, which is the same convention E014 uses. Two
*   consequences worth knowing:
*     - "not shown" is the resting state, so a third applicant type added
*       later cannot accidentally leave the finder on screen;
*     - the rule is evaluated on read AND on change by the engine, so the
*       on_after_read redefinition this class used to need is gone.
*
*   DO NOT reintroduce set_hidden( ) on OWNER_1 here. It OUTRANKS the
*   rules for the rest of the session, so it would not add to R001 - it
*   would silently take the decision away from it, which is how the
*   inversion survived in the first place.
*   ---------------------------------------------------------------------
*
*   Everything else this journey needs that CAN be configuration IS
*   configuration - and on this journey that is most of it. STP2's
*   three-way branch by PROJECT_TYPE (Industry / Development Project /
*   Others, legacy DATA4 = PROJECT_TYPE with DATA5 = 1 / 2 / 9) is
*   fourteen SHOW rules in the feeder, not ABAP here. What is left is the
*   applicant-role fan-out and the payment wiring.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   One segmented field on screen, TWO booleans in the backend here (E014
*   and E146 have three). The legacy screen had two separate TBUTTONs,
*   each bound to its own GS_DATA-PARTNER_* flag, and a segmented field
*   carries ONE value - so the chosen option has to be fanned back out or
*   the backend receives nothing for the applicant's role.
    METHODS write_role_flags
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string.
ENDCLASS.



CLASS ZCL_E015_ENV_STUDY_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   The journey's own payment step. PREPARE_PAYMENT reads this to know
*   whose read BAdI resolves the gateway, and NE015_1_4 is that screen.
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'NE015_1_4' ).

*   ---- the payment terms block, from the legacy screen itself ----------
*   NE015_1_4 is field-for-field identical to NE014_1_4, so these are the
*   same four method radios (RB1..RB4) and two channel radios
*   (PW_RB1/PW_RB2), with the same captions. Set per journey because the
*   base class's defaults name one method and one channel, which is not
*   what the screen offers.
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
*   set - the same open item as ZCL_E014_CONSULT_REG_LOGIC, and needing
*   its own answer: an environmental STUDY fee is a different service from
*   a consultancy registration, so do not copy that journey's values
*   across once they arrive.
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

*   REVIEW-BE: three live lookups on STP1 - OWNER_1 (the business
*   partner), PERMIT_NUMBER_2 (legacy search kind 'REGISTRATION') and
*   REFER_CASE_ID (legacy search kind 'CASE_ID') - render but return
*   nothing, because this class does not redefine on_search. SEARCH is a
*   recognised ftype so the controls draw correctly and a press is simply
*   inert. Same open item as E014's OWNER_FINDER_BP and E027's three
*   lookups: one search API to confirm, then one on_search here that
*   branches on iv_field.

    CONSTANTS c_login_bp TYPE string VALUE 'LOGIN_BP' ##NO_TEXT.
    CONSTANTS c_owner_bp TYPE string VALUE 'OWNER_BP' ##NO_TEXT.

    CONSTANTS c_partner_name TYPE string VALUE 'APP_NAME' ##NO_TEXT.
    CONSTANTS c_partner_id TYPE string VALUE 'PARTNER_ID' ##NO_TEXT.
    CONSTANTS c_applicanttype TYPE string VALUE 'APPLICANTTYPE' ##NO_TEXT.
    CONSTANTS c_lang_en TYPE string VALUE 'E' ##NO_TEXT.




    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

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

      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

      io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-owner_id }| ).

    ENDIF.


    io_ctx->set_val( iv_name = 'APP_NAME' iv_value = COND #(
      WHEN sy-langu <> 'E' AND ls_bp-bp_name_ar IS NOT INITIAL
      THEN CONV string( ls_bp-bp_name_ar )
      ELSE CONV string( ls_bp-bp_name ) ) ).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( ls_bp-emirates_id ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    IF to_upper( iv_field ) = c_applicant_type.
      write_role_flags( io_ctx = io_ctx iv_pick = io_ctx->get_val( c_applicant_type ) ).
    ENDIF.

*   No branch on PROJECT_TYPE here, deliberately: STP2's three-way
*   visibility is rules R002..R015 in the feeder, and the engine
*   re-evaluates them on every change. Adding set_hidden( ) calls for it
*   would outrank those rules permanently - the same trap this class fell
*   into with OWNER_1. See the class header.
  ENDMETHOD.


  METHOD write_role_flags.
*   Both flags written on every change, not just the chosen one - the
*   citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both.
    DATA(lt_role) = VALUE zif_rak_journey=>tt_kv(
      ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
      ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ).

    LOOP AT lt_role INTO DATA(ls_role).
      io_ctx->set_val( iv_name  = ls_role-value
                       iv_value = COND string( WHEN ls_role-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.
CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
  EXPORTING
    IO_CTX   = IO_CTX
    IV_FIELD = IV_FIELD
    .

     IF iv_field = 'OWNER_1'.

      CHECK to_upper( iv_field ) = 'OWNER_1'.

      DATA(lv_eid) = condense( io_ctx->get_val( 'OWNER_1' ) ).
      IF lv_eid IS INITIAL.
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Enter Emirates ID to search| ).
        RETURN.
      ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( 'OWNER_SEARCH_IDTYPE' ).
      IF lv_idtype IS INITIAL.
        lv_idtype = 'YFS002'.
      ENDIF.

      DATA: lv_eid_no   TYPE bu_id_number,
            lv_eid_type TYPE bu_id_type.

      lv_eid_no = lv_eid.
      lv_eid_type = lv_idtype.

      DATA ev_partner         TYPE partner.
      DATA ev_id_number       TYPE bu_id_number.
      DATA ev_passport        TYPE bu_id_number.
      DATA ev_name            TYPE bu_name1tx.
      DATA ev_phone           TYPE farp_mobile.
      DATA ev_email           TYPE ad_smtpadr.
      DATA ev_nationality     TYPE natio50.
      DATA ev_nationality_key TYPE bu_natio.
      DATA ev_date_of_birth   TYPE bu_birthdt.
      DATA ev_message         TYPE bapiret2-message.

      CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
        EXPORTING
          iv_type            = lv_eid_type
          iv_idnumber        = lv_eid_no
*         IV_APP             = IV_APP
        IMPORTING
          ev_partner         = ev_partner
          ev_id_number       = ev_id_number
          ev_passport        = ev_passport
          ev_name            = ev_name
          ev_phone           = ev_phone
          ev_email           = ev_email
          ev_nationality     = ev_nationality
          ev_nationality_key = ev_nationality_key
          ev_date_of_birth   = ev_date_of_birth
          ev_message         = ev_message.

      io_ctx->set_val( iv_name = 'OWNER_NAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_PHONE'      iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_EMAIL'       iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_DOB'         iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_NATIONALITY' iv_value = ' ' ).

*

      io_ctx->set_val( iv_name = 'OWNER_1'  iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = 'OWNER_NAME'        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = 'OWNER_PHONE'      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = 'OWNER_EMAIL'       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = 'OWNER_DOB'         iv_value = |{ ev_date_of_birth DATE = USER }| ).
      io_ctx->set_val( iv_name = 'OWNER_NATIONALITY' iv_value = |{ ev_nationality }| ).

    ELSEIF iv_field = 'PERMIT_NUMBER'.
      DATA(lv_permit) = condense( io_ctx->get_val( 'PERMIT_NUMBER' ) ).

      IF lv_permit IS NOT INITIAL.
        SELECT SINGLE contractname FROM zv_epdapmmast INTO @DATA(lv_contrat) WHERE permitid = @lv_permit.

        IF lv_contrat IS NOT INITIAL.
          io_ctx->set_val( iv_name = 'PERMIT_NUMBER'  iv_value = |{ lv_permit }| ).
          io_ctx->set_val( iv_name = 'PERMIT_DETAIL'  iv_value = |{ lv_contrat }| ).
        ELSE.
          io_ctx->set_val( iv_name = 'PERMIT_DETAIL' iv_value = ' ' ).
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Enter Valid Permit No to search| ).
        ENDIF.

      ENDIF.
    ENDIF.
  endmethod.
ENDCLASS.
