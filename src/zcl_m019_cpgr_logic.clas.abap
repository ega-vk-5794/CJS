CLASS zcl_m019_cpgr_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_grant_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M019 Convert To Program Grant Request.
*&
*&   STP1  NCPGR_1_1   Grant Selection   the grant card list
*&   STP2  NCPGR_1_2   Documents         grant letter, loan, one upload
*&   STP3  NCPGR_1_3   Fees & Payment
*&   ---   NCPGR_1_4   the CPG screen - PAY_SCREEN, never a CJS step
*&
*& THE SELECTOR READS GRANTS, NOT OWNED PARCELS. Step 1 is the parcel
*& card list with Partnerrole YTR080, which is what
*& ZCL_RAK_PROPERTY_API=>C_ROLE_GRANT and PARCELS( iv_grants = abap_true )
*& are for. On TR0800 the same control answers the citizen's owned
*& parcels - a list that renders perfectly and is the wrong one, which is
*& worse than an empty list because nothing looks broken. The screenshot
*& shows one card with an "Expired On" date and no Owned / Property Agent
*& / Grants tabs, only Favourites: a grants selector has one source.
*&
*& ZEGA_T_CJ_UI_MAP GIVES THIS JOURNEY TWO CPG_1 ROWS - NCPGR_1_4 and
*& NCPGR_1_5 - where every other journey has one. PAY_SCREEN takes the
*& EARLIER screen, which is what ZCL_RAK_QNV_BRIDGE=>MAP_SCREEN( ) would
*& do if it were consulted and what the feeder hard-codes. If the
*& gateway comes back empty on _1_4, _1_5 is the other candidate and the
*& trace prints which screen was asked.
*&
*& NO PLDTL AND NO BPDTL ON STAGE 1. The map puts BPDTL on NCPGR_2_1,
*& which is the later stage and has no feeder. So step 1 shows the card
*& list and nothing else; there is no party table to seed here.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- the grant the citizen picked -----------------------------------
*   PARCELSELECTOR, CONFIRMED FROM THE EXPORT: NCPGR_1_1 carries a
*   RAKPARCELSELECTOR called exactly that, the same control M011,
*   M012 and M016 use. Only the ROLE it reads with differs.
    CONSTANTS c_fld_grant      TYPE string VALUE 'PARCELSELECTOR'.

*   ---- step 2: the grant letter ---------------------------------------
*   Four fields in one row on screen - letter reference, grant
*   reference, program type, and the letter's expiry date.
    CONSTANTS c_fld_letter_ref TYPE string VALUE 'REFNUM'.
    CONSTANTS c_fld_grant_ref  TYPE string VALUE 'GRANTREFNUM'.
    CONSTANTS c_fld_prog_type  TYPE string VALUE 'COMBOBOX'.
    CONSTANTS c_tech_expiry    TYPE string VALUE 'EXP_DATE'.

*   ---- step 2: grant status -------------------------------------------
*   TECHNICAL_NAMEs, resolved through FLD_BY_TECH( ) - see the note in
*   ZCL_RAK_GRANT_LOGIC. This journey has no name collision today, but
*   the field names are ALLOCATED by the migrator and RB1 is exactly the
*   kind that acquires a suffix when a screen is added, so resolving by
*   technical name costs nothing and cannot go stale.
    CONSTANTS c_tech_loan_stat TYPE string VALUE 'WITH_LOAN'.
    CONSTANTS c_tech_loan_val  TYPE string VALUE 'LOAN_VAL'.
    CONSTANTS c_tech_loan_from TYPE string VALUE 'FROM_DATE'.
    CONSTANTS c_tech_loan_to   TYPE string VALUE 'TO_DATE'.

*   ---- step 2: the one document ---------------------------------------
    CONSTANTS c_fld_sz_appr    TYPE string VALUE 'UPLOADER'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

ENDCLASS.



CLASS zcl_m019_cpgr_logic IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK` - the engine's PAID gate, then
*   the MML parcel rule, then the grants base.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   ---- the loan section, when there is a loan -------------------------
*   Shared with M018 through the grants base; only the field names
*   differ, so they are passed in. Answers false unless the toggle says
*   With Loan, which is what stops a Without Loan application being
*   blocked by three fields the backend's FIELD_CONTROL( ) has hidden.
    IF loan_incomplete( io_ctx    = io_ctx
                        iv_status = fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_loan_stat )
                        iv_value  = fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_loan_val )
                        iv_from   = fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_loan_from )
                        iv_to     = fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_loan_to ) ) = abap_true.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = COND string(
            WHEN sy-langu = 'A'
            THEN `عند اختيار "بقرض" يجب إدخال قيمة القرض وتاريخي البداية والنهاية.`
            ELSE `With Loan needs the loan value and both dates.` ) ) ).
    ENDIF.

*   ---- the grant letter must not already have expired -----------------
*   THE ONE RULE THAT IS THIS JOURNEY'S OWN. The citizen is converting an
*   existing grant on the strength of a letter, and a letter whose expiry
*   is in the past cannot support the conversion. Nothing on the backend
*   side checks the date against today - it stores it as a
*   characteristic - and the field is a DatePicker, so a past date is
*   perfectly typable.
*
*   TO_DATS( ) IS THE ONE PARSER, and it matters here more than it looks.
*   A DatePicker does NOT discard input it fails to parse: it flags its
*   own valueState and still writes the typed characters through the
*   two-way binding, so this field can hold '01/09/2026' or worse. A raw
*   comparison against SY-DATUM on that string is meaningless, and
*   feeding it to a DATS conversion elsewhere is what raised an
*   uncatchable CX_SY_CONVERSION_NO_DATE on the BP search.
*
*   A VALUE THAT WILL NOT NORMALISE IS LEFT ALONE HERE, not reported.
*   The DATE range check in ZCL_RAK_JOURNEY_RULES already refuses an
*   unparseable date with the field's own message, so saying it twice
*   would put two errors on one field. This rule only has an opinion
*   about a date it can read.
    DATA(lv_raw) = io_ctx->get_val(
                     fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_expiry ) ).
    IF lv_raw IS NOT INITIAL.
      DATA(lv_dats) = zcl_rak_journey_util=>to_dats( lv_raw ).
      IF lv_dats IS NOT INITIAL AND lv_dats < |{ sy-datum }|.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `انتهت صلاحية خطاب المنحة. لا يمكن تقديم الطلب بخطاب منتهي.`
              ELSE `The grant letter has already expired - it cannot support ` &&
                   `a conversion request.` ) ) ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
