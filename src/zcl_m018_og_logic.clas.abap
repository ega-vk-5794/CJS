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

*   ---- step 1: grant type and beneficiary -----------------------------
*   NAMES CONFIRMED FROM EXPORT_DEFIN.XLSX for NOG_1_1..NOG_1_4.
*   ONE EXCEPTION, deliberately: C_FLD_LOAN_STAT is RB1_LOAN, a CJS
*   name. The export calls the loan toggle RB1 on NOG_1_3 and the
*   beneficiary toggle RB1 on NOG_1_1 - legacy names are per SCREEN
*   and BUILD_MODEL( ) is flat per JOURNEY, so the two would have
*   shared one model component and each would have set the other.
*   The feeder gives that field TECH_NAME = RB1, which is what the
*   BAdI maps values by; only FIELD_CONTROL on it is lost, and a
*   CTRL_OF( ) miss now reads as no instruction rather than as
*   forced-optional. Do not "fix" this back to RB1.
    CONSTANTS c_fld_grant_type TYPE string VALUE 'RB3'.
    CONSTANTS c_fld_benef      TYPE string VALUE 'RB1'.
    CONSTANTS c_fld_grantees   TYPE string VALUE 'NUMINPUT'.

*   The partner list the citizen builds with the search. A grid, so
*   GET_GRID_DATA( ) reaches it and GET_VAL( ) does not.
    CONSTANTS c_fld_bplist     TYPE string VALUE 'TABLE_FETCHER'.

*   ---- step 2: family details -----------------------------------------
*   Number of wives is a five-option radio (0..4) and the children count
*   per wife is a dropdown that appears once per wife the citizen
*   declared. Four carriers, only as many shown as the radio allows -
*   which is rule work in ZRAK_T_JNY_RULE, not code.
    CONSTANTS c_fld_wives      TYPE string VALUE 'RB0'.
    CONSTANTS c_fld_child1     TYPE string VALUE 'CHILD1CB'.
    CONSTANTS c_fld_child2     TYPE string VALUE 'CHILD2CB'.
    CONSTANTS c_fld_child3     TYPE string VALUE 'CHILD3CB'.
    CONSTANTS c_fld_child4     TYPE string VALUE 'CHILD4CB'.

*   ---- step 3: program details ----------------------------------------
    CONSTANTS c_fld_housing    TYPE string VALUE 'HOUSEREFINPUT'.
    CONSTANTS c_fld_loan_stat  TYPE string VALUE 'RB1_LOAN'.  " CJS name; TECH_NAME is RB1
    CONSTANTS c_fld_loan_val   TYPE string VALUE 'LOANVALUEINPUT'.
    CONSTANTS c_fld_loan_from  TYPE string VALUE 'FROMDATE'.
    CONSTANTS c_fld_loan_to    TYPE string VALUE 'TODATE'.

*   The beneficiary values. SHARED is what turns the grantee count and
*   the partner list on.
    CONSTANTS c_benef_shared   TYPE string VALUE 'SHARED'.

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
    DATA(lv_benef) = to_upper( condense( io_ctx->get_val( c_fld_benef ) ) ).

    IF lv_benef CS c_benef_shared.

      DATA(lv_said) = condense( io_ctx->get_val( c_fld_grantees ) ).
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
                     |{ c_fld_grantees } should be configured as a numeric field.| ) ).
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
                        iv_status = c_fld_loan_stat
                        iv_value  = c_fld_loan_val
                        iv_from   = c_fld_loan_from
                        iv_to     = c_fld_loan_to ) = abap_true.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = COND string(
            WHEN sy-langu = 'A'
            THEN `عند اختيار "بقرض" يجب إدخال قيمة القرض وتاريخي البداية والنهاية.`
            ELSE `With Loan needs the loan value and both dates.` ) ) ).
    ENDIF.

  ENDMETHOD.


ENDCLASS.
