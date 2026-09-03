CLASS zcl_rak_grant_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& The GRANTS family (M018, M019, M020 - and M021/M022 when they come).
*&
*& INHERITS ZCL_RAK_MUN_LOGIC RATHER THAN THE ENGINE BASE, because
*& everything that class added is still right here: the PAID gate chained
*& through ON_CUSTOM_VALIDATE, the terms gate and fee total on the Pay
*& press, and the deliberately empty ON_BEFORE_POST / ON_BEFORE_FIELDS
*& that stop the base stripping PAY_* out of a fee-bearing payload.
*&
*& WHAT IS DIFFERENT, AND IT IS A DIFFERENT BAdI. These journeys post
*& through ZCL_EGA_CJ_FW_RO_GRANT_ABS_V1, not ZCL_EGA_CJ_FW_RO_ABS_V1,
*& and the two are not interchangeable:
*&
*&   case type        ZGCR, not ZGCX
*&   owner role       ZTR080, not TR0800 - MAPPER( ) builds
*&                    mt_partner = ( role_type = 'ZTR080' ... )
*&                    ( role_type = 'TR0640' ... ) from the BP item
*&   the party list   note CJ03, split on '-', NOT the CJ02 parcel note.
*&                    CREATE_DUMMY_CASE( ) reads CJ03 and puts each
*&                    partner in CASE-BP_LIST with role 003
*&   beneficiary      CASE-BP_BENEFICIARY is set from the ZTR080 partner,
*&                    which the MML abstract never fills
*&   attachments      doc_type '13' on the case, not '31'
*&   the party table  BPDTL -> GET_PARTNERS( ), five columns: partner,
*&                    name, telephone, nationality, email. There is no
*&                    PLDTL on a grants journey.
*&
*& AND THE PARCEL LIST IS A DIFFERENT ROLE. A grants selector reads
*& PropertiesSet with Partnerrole YTR080 - the OData spelling, which the
*& DPC translates to ZTR080 on the way in. ZCL_RAK_PROPERTY_API already
*& has both: C_ROLE_GRANT and PARCELS( iv_grants = abap_true ). Sending
*& TR0800 on a grants journey answers the citizen's OWNED parcels, which
*& is a different list and a plausible-looking wrong one.
*&
*& THE CASE IS STILL CREATED BY THE FEE POST. Same as MML:
*& ZIF_EGA_FW_CJI~UPDATE( ) reaches CREATE_DUMMY_CASE( ) only on finding
*& TOTALFEESVALUE in the items with a FEES_1 row in ZEGA_T_CJ_UI_MAP for
*& that screen. So the inherited fee-total gate on the Pay press applies
*& unchanged, and every feeder here needs its TOTALVALUE carrier.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- the grants party note ------------------------------------------
*   CJ03 on an MML journey is the OWNER characteristic; on a grants
*   journey it is the note carrying the whole party list, hyphen
*   separated, which CREATE_DUMMY_CASE( ) splits into CASE-BP_LIST. Named
*   here so a subclass reads it rather than re-deriving it.
    CONSTANTS c_note_parties TYPE string VALUE 'CJ03'.

*   The role the grants DPC filter wants, in the OData spelling. Not
*   ZTR080 - that is what the DPC translates it to internally.
    CONSTANTS c_role_grants  TYPE string VALUE 'YTR080'.

*   ---- what every grants journey shares on screen ---------------------
*   JUST_DETAILS is the grants abstract's own name for the long text that
*   rides characteristic CJ11 and the RE note - the MML family calls the
*   same thing PLOTLONGTEXT. Confirmed in
*   ZCL_EGA_CJ_FW_RO_GRANT_ABS_V1->READ( )'s CASE on TECHNICALNAME.
    CONSTANTS c_fld_just     TYPE string VALUE 'JUST_DETAILS'.

*   Set by the abstract's READ( ) from the ZTR080 partner. Read-only on
*   screen everywhere it appears.
    CONSTANTS c_fld_account  TYPE string VALUE 'ACCOUNT'.

*   The container case id, from characteristic CJ12. The abstract's
*   READ( ) fills it and strips its leading zeros.
    CONSTANTS c_fld_case_id  TYPE string VALUE 'CASE_ID'.

*   ---- loan status, and the three fields it governs -------------------
*   M018's Program Details and M019's Grant status both draw a With Loan
*   / Without Loan toggle and three fields that only mean anything under
*   With Loan. The VALUES are not confirmed against the /QNV export -
*   only that the control is a two-option toggle - so a subclass that
*   learns the real keys should override these two rather than let the
*   comparison drift.
    CONSTANTS c_loan_with    TYPE string VALUE 'WITH'.
    CONSTANTS c_loan_without TYPE string VALUE 'WITHOUT'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PROTECTED SECTION.

*   ---- RESOLVING A FIELD WHEN THE MIGRATOR CHOSE ITS NAME --------------
*   A migrated journey's field names are ALLOCATED, not authored.
*   ZCL_RAK_MIGRATOR->BUILD_NAME_MAP( ) keeps a journey-wide set of used
*   names and suffixes a counter onto any repeat, so the loan toggle -
*   legacy FIELD_NAME 'RB1' on NOG_1_3, colliding with the beneficiary
*   toggle 'RB1' on NOG_1_1 - reaches CJS as 'RB11'. Which of the two
*   gets the suffix depends on screen order, so no handler can hard-code
*   either one.
*
*   What IS stable is the legacy TECHNICAL_NAME: 'WITH_LOAN', 'NO_LOAN',
*   'I_BENEFICIARY', 'SHARED_NUM', 'CHILDREN_WIFE1'. The migrator writes
*   it to ZRAK_T_JNY_FLD-TECH_NAME verbatim, and it is what the BAdI maps
*   values by - so it is the name that actually means something.
*
*   FLD_BY_TECH( ) turns one into the other by reading the journey's own
*   config. Cached per instance because MS_CONFIG is rebuilt every round
*   trip and this is called from validation, which runs per field.
*
*   A BLANK ANSWER IS NORMAL AND MUST STAY HARMLESS: a step the citizen
*   has not reached is still in the config, but a field whose TECH_NAME
*   the export never set has none to match. Every caller here treats
*   blank as "nothing to check", because GET_VAL( ) on a name that is not
*   on the journey is legal and silently returns nothing - so a wrong
*   answer here would fabricate a passing check, and a blank one only
*   skips it.
    METHODS fld_by_tech
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_tech   TYPE string
      RETURNING VALUE(rv) TYPE string.

    DATA mt_bytech TYPE HASHED TABLE OF zif_rak_journey=>ty_kv WITH UNIQUE KEY key.

*   Is the loan section answered - the toggle set to With Loan and all
*   three dependent fields filled. PROTECTED so M018 and M019 share one
*   implementation of a rule they both draw.
*
*   THE FIELD NAMES COME FROM THE SUBCLASS, not from here: M018 and M019
*   put the same three fields under different legacy names, and guessing
*   one shared set would break the field-control chain that keys on the
*   legacy FIELD_NAME.
    METHODS loan_incomplete
      IMPORTING io_ctx      TYPE REF TO zif_rak_journey
                iv_status   TYPE string
                iv_value    TYPE string
                iv_from     TYPE string
                iv_to       TYPE string
      RETURNING VALUE(rv)   TYPE abap_bool.

ENDCLASS.



CLASS zcl_rak_grant_logic IMPLEMENTATION.



  METHOD fld_by_tech.
*   Cache hit, including a cached BLANK - a tech name that is not on this
*   journey must not be re-scanned on every field of every round trip.
    DATA(lv_t) = to_upper( condense( iv_tech ) ).
    IF lv_t IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE mt_bytech INTO DATA(ls_c) WITH TABLE KEY key = lv_t.
    IF sy-subrc = 0.
      rv = ls_c-value.
      RETURN.
    ENDIF.

    LOOP AT io_ctx->get_config( )-steps INTO DATA(ls_s).
      LOOP AT ls_s-fields INTO DATA(ls_f) WHERE tech_name IS NOT INITIAL.
        IF to_upper( condense( ls_f-tech_name ) ) = lv_t.
          rv = ls_f-name.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF rv IS NOT INITIAL.
        EXIT.
      ENDIF.
    ENDLOOP.

*   Insert even when blank, so the miss is paid for once.
    INSERT VALUE #( key = lv_t value = rv ) INTO TABLE mt_bytech.
  ENDMETHOD.

  METHOD loan_incomplete.

    IF iv_status IS INITIAL.
      RETURN.
    ENDIF.

*   ONLY UNDER "WITH LOAN". Without a loan the three fields are hidden by
*   the backend's FIELD_CONTROL( ) and demanding them would block a
*   perfectly valid application - which is the shape of bug that reads as
*   "the form will not submit and does not say why".
*
*   COMPARED WITH CS, NOT EQ. The stored value of a two-option toggle is
*   whatever the legacy control's option key is, and that key is not
*   confirmed from here. A containment test on the word matches 'WITH',
*   'WITHLOAN' and 'W_LOAN' alike, and cannot match 'WITHOUT' by
*   accident because that is tested first.
    DATA(lv_st) = to_upper( condense( io_ctx->get_val( iv_status ) ) ).
    IF lv_st IS INITIAL OR lv_st CS c_loan_without.
      RETURN.
    ENDIF.
    IF NOT lv_st CS c_loan_with.
      RETURN.
    ENDIF.

    IF io_ctx->get_val( iv_value ) IS INITIAL
       OR io_ctx->get_val( iv_from ) IS INITIAL
       OR io_ctx->get_val( iv_to )   IS INITIAL.
      rv = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. ZCL_RAK_MUN_LOGIC's
*   implementation chains the engine's PAID gate and then adds its own
*   parcel rule; skipping this call removes payment protection from every
*   grants journey at once, which is how E128 became submittable unpaid
*   twice.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   NOTHING FURTHER HERE ON PURPOSE. The family has no rule that is true
*   of all three journeys and not already in the base: M018 validates a
*   grantee count and a family tree, M019 a grant letter, M020 a
*   mortgage NOC, and each of those lives in its own subclass. A rule
*   invented here to look symmetrical would run on journeys it was never
*   written for.
*
*   The method is redefined at all so the chain is explicit and a future
*   family-wide rule has an obvious home - and because an EMPTY
*   redefinition of this hook is a deletion of the PAID gate, which is
*   what the call above prevents.

  ENDMETHOD.


ENDCLASS.
