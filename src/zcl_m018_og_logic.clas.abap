CLASS zcl_m018_og_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_grant_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M018 Grant Request - the longest journey in the family.
*&
*&   STP1  NOG_1_1   Grant Information   type, beneficiary, BP list
*&   STP2  NOG_1_2   Family Details      wives and children
*&   STP3  NOG_1_3   Program Details     housing ref, loan
*&   STP4  NOG_1_4   Documents           seven uploads
*&   STP5  NOG_1_5   Fees & Payment
*&   ---   NOG_1_6   the CPG screen - PAY_SCREEN, never a CJS step
*&
*& TWO ATTACHMENT SCREENS, and ZEGA_T_CJ_UI_MAP says so: ATTACHMENT sits
*& on both NOG_1_1 and NOG_1_4. Step 1 has the identification document
*& inside the partner search; step 4 is the documents page. A feeder that
*& puts uploads on only one of them loses the other silently, because a
*& screen with no ATTACHMENT row never calls GET_ATTACHMENT( ).
*&
*& AND M018 IS THE ONE JOURNEY THE ABSTRACT SKIPS ATTACHMENTS FOR ON THE
*& CASE. CREATE_DUMMY_CASE( ) reads
*&
*&     IF mv_journeytype <> 'M018'.
*&       get_attachment( ... for_case = abap_true ... ).
*&
*& so its files stay against the draft and are NOT copied into the
*& container case as base64. That is deliberate on the backend side -
*& seven documents including a family book would be a large case payload
*& - and it means an uploaded file is still there, still readable, and
*& simply not duplicated. Do not "fix" it CJS-side by posting them again.
*&
*& THE BENEFICIARY TOGGLE DRIVES THE WHOLE OF STEP 1. Individual asks
*& for nothing more; Shared asks for a grantee COUNT and then a partner
*& list, and the count is what the citizen is held to. That rule is
*& below - it is the one thing the backend cannot check, because at the
*& time it validates it has the list but not the number the citizen
*& said.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- WHAT THESE CONSTANTS NOW HOLD ----------------------------------
*   The legacy TECHNICAL_NAME, not the field name - and the journey is
*   MIGRATED, which is what forces it.
*
*   ZCL_RAK_MIGRATOR->BUILD_NAME_MAP( ) allocates CJS field names from a
*   journey-wide used-names set and suffixes a counter onto any repeat.
*   The export gives the beneficiary toggle FIELD_NAME 'RB1' on NOG_1_1
*   and the loan toggle FIELD_NAME 'RB1' on NOG_1_3, so one of the two
*   arrives as 'RB11' - and which one depends on screen order, so no
*   constant here can name either.
*
*   TECHNICAL_NAME does not move: 'I_BENEFICIARY', 'WITH_LOAN',
*   'SHARED_NUM', 'CHILDREN_WIFE1'. The migrator writes it verbatim to
*   ZRAK_T_JNY_FLD-TECH_NAME and the BAdI maps values by it, so it is
*   both stable and meaningful. FLD_BY_TECH( ) resolves one to the
*   allocated field name off the journey's own config.
*
*   THREE FIELDS HAVE NO TECHNICAL_NAME IN THE EXPORT - the uploaders,
*   PARCELSELECTOR and TABLE_FETCHER are all blank - so those keep their
*   field name. None of them collides, and if one ever did, the resolver
*   has nothing to resolve with and the answer would have to be a
*   migrator change rather than a handler one.
    CONSTANTS c_tech_grant_type TYPE string VALUE 'GTYPE_N'.
    CONSTANTS c_tech_benef      TYPE string VALUE 'I_BENEFICIARY'.
    CONSTANTS c_tech_grantees   TYPE string VALUE 'SHARED_NUM'.

*   The partner list the citizen builds with the search. A grid, so
*   GET_GRID_DATA( ) reaches it and GET_VAL( ) does not. No
*   TECHNICAL_NAME, so this is the field name.
    CONSTANTS c_fld_bplist      TYPE string VALUE 'TABLE_FETCHER'.

*   ---- step 2: family details -----------------------------------------
    CONSTANTS c_tech_wives      TYPE string VALUE 'WIFE0'.
    CONSTANTS c_tech_child1     TYPE string VALUE 'CHILDREN_WIFE1'.
    CONSTANTS c_tech_child2     TYPE string VALUE 'CHILDREN_WIFE2'.
    CONSTANTS c_tech_child3     TYPE string VALUE 'CHILDREN_WIFE3'.
    CONSTANTS c_tech_child4     TYPE string VALUE 'CHILDREN_WIFE4'.

*   ---- step 3: program details ----------------------------------------
    CONSTANTS c_tech_housing    TYPE string VALUE 'BUILDING_NUMBER'.
    CONSTANTS c_tech_loan_stat  TYPE string VALUE 'WITH_LOAN'.
    CONSTANTS c_tech_loan_val   TYPE string VALUE 'LOAN_VAL'.
    CONSTANTS c_tech_loan_from  TYPE string VALUE 'FROM_DATE'.
    CONSTANTS c_tech_loan_to    TYPE string VALUE 'TO_DATE'.

*   ---- THE BENEFICIARY VALUE, AND WHY IT IS A FIELD NAME --------------
*   A radio or segmented group is ONE CJS field whose options are the
*   group's member buttons, and COLLECT_LOGIC_RULES( ) sets each rule's
*   SRC_VALUE to the member's OWN FIELD_NAME - not its technical name.
*   So the option keys on the beneficiary toggle are 'RB1' (individual)
*   and 'RB2' (shared), and the shared one is what turns the grantee
*   count and the partner list on.
*
*   Matched with CS on the SECOND member's name so a suffix allocated to
*   a colliding option key cannot break it.
    CONSTANTS c_opt_benef_shared TYPE string VALUE 'RB2'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PROTECTED SECTION.

*   How many partners the citizen has actually added. Zero for a journey
*   with no grid, which is why the caller checks the beneficiary toggle
*   first rather than reading this on its own.
    METHODS bp_rows
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE i.

ENDCLASS.



CLASS zcl_m018_og_logic IMPLEMENTATION.


  METHOD bp_rows.
*   GET_GRID_DATA( ), never GET_VAL( ). The interface is explicit that
*   GET_VAL( ) answers BLANK for a grid - the model member is a JSON
*   string and the accessor refuses it - so reading the list as a scalar
*   would report an empty table as confidently as a full one.
    rv = lines( io_ctx->get_grid_data( c_fld_bplist )-rows ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. The chain is the engine's PAID
*   gate, then ZCL_RAK_MUN_LOGIC's parcel rule, then the grants base.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   ---- SHARED means the list must match the number promised ----------
*   THE BACKEND CANNOT CHECK THIS. By the time
*   ZCL_EGA_CJ_FW_RO_GRANT_ABS_V1 validates, it has the party list in
*   note CJ03 and it does not have the count the citizen typed - that is
*   a screen field, not a characteristic it stores. So the only place the
*   two can be compared is here.
*
*   AND GETTING IT WRONG IS EXPENSIVE THE QUIET WAY: a Shared grant that
*   posts with one grantee creates a case, raises a fee and takes a
*   payment for a grant that will then be rejected on review.
    DATA(lv_benef) = to_upper( condense(
                       io_ctx->get_val( fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_benef ) ) ) ).

    IF lv_benef CS c_opt_benef_shared.

      DATA(lv_gfld) = fld_by_tech( io_ctx = io_ctx iv_tech = c_tech_grantees ).
      DATA(lv_said) = condense( io_ctx->get_val( lv_gfld ) ).
      DATA(lv_have) = bp_rows( io_ctx ).

*     A BLANK COUNT IS THE CONFIGURED REQUIRED CHECK'S BUSINESS, not
*     this one's - VALIDATE_STEP( ) refuses Next on step 1 without it.
*     Reaching submit with it blank means the field is not configured
*     required, and saying so here is more useful than a comparison
*     against nothing.
      IF lv_said IS INITIAL.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `يرجى تحديد عدد المستفيدين المشتركين.`
              ELSE `State the number of shared grantees before submitting.` ) ) ).
        RETURN.
      ENDIF.

      DATA lv_want TYPE i.
      TRY.
          lv_want = CONV i( lv_said ).
        CATCH cx_root.
*         A count that will not convert is a configuration problem, not
*         a citizen one - the field should be numeric. Reported rather
*         than silently treated as zero, which would let any list pass.
          rt = VALUE #( BASE rt
            ( type = 'Error'
              text = |The number of shared grantees ({ lv_said }) is not a number. | &&
                     |{ lv_gfld } should be configured as a numeric field.| ) ).
          RETURN.
      ENDTRY.

      IF lv_want > 0 AND lv_have <> lv_want.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN |تم تحديد { lv_want } من المستفيدين المشتركين، وتمت إضافة { lv_have }. |
                && |يرجى مطابقة القائمة مع العدد المحدد.|
              ELSE |You said { lv_want } shared grantee(s) and added { lv_have }. |
                && |Add or remove partners so the list matches the number.| ) ) ).
      ENDIF.

    ENDIF.

*   ---- the loan section, when there is a loan -------------------------
*   LOAN_INCOMPLETE( ) is on the grants base because M019 draws the same
*   three fields; only the names differ, so they are passed in. It
*   answers false unless the toggle actually says With Loan, which is
*   what keeps a Without Loan application from being blocked by fields
*   the backend has hidden.
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

  ENDMETHOD.


ENDCLASS.
