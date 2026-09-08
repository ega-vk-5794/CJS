CLASS zcl_m029_aco_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M029 - Assign Consultant (legacy NACO_1_1..1_2, category DML).
*&
*& INHERITS ZCL_RAK_MUN_LOGIC, like M011/M012/M016/M017. That is not
*& only the family convention here - step 1 of this journey IS a
*& RAKPARCELSELECTOR, so the base's step-0 "Select a parcel before
*& continuing" check is exactly right and must not be re-implemented.
*&
*& (M028 deliberately does NOT inherit it, because its first step is a
*& project list and that same check would refuse step 0 for ever against
*& a field the screen does not have. See ZCL_M028_COD_LOGIC's header.)
*&
*& NO PAYMENT ON THIS JOURNEY. There is no RAKPAY control on any NACO_1_*
*& screen and the walkthrough says the same, so no PAYFEE field is seeded
*& and the base's PAID gate never has anything to refuse. The base's two
*& empty ON_BEFORE_POST / ON_BEFORE_FIELDS redefinitions keep PAY_* in the
*& payload; with no payment fields on the journey there is nothing for
*& them to keep, so they are harmless here rather than wrong.
*&
*& ------------------------------------------------------------------
*& WHAT THIS CLASS IS ACTUALLY FOR - two things config cannot express.
*&
*& 1. THE SEARCH RESULT HAS TO BECOME A GRID ROW. ftype SEARCH draws the
*&    method dropdown, the input and the Add button, and hands the press
*&    to ON_SEARCH( ). Turning the found partner into a row of the
*&    consultant grid is handler work by definition.
*&
*& 2. "AT LEAST ONE CONSULTANT" IS NOT THE GRID'S REQUIRED FLAG.
*&    ZCL_RAK_JOURNEY_RULES->MISSING_REQUIRED( ) says so in its own
*&    words: for an EDITABLE_TABLE it checks required COLUMNS against the
*&    rows that already exist and "an empty grid still passes,
*&    deliberately NOT a row-count check". So REQUIRED on CONSULTANTS
*&    draws the asterisk the live screen shows and enforces nothing, and
*&    the row count is checked below.
*&
*&    THE MARKER AND THE ENFORCEMENT MUST STAY IN STEP. This is the same
*&    drift that left E016/E017/E018 with nine, four and ten enforced
*&    popup fields and no asterisks between them. If the REQUIRED flag on
*&    CONSULTANTS is ever removed in the Studio, remove the check here
*&    too - and the other way round.
*&
*& ------------------------------------------------------------------
*& THE BP ROW'S SHAPE IS ONLY PARTLY KNOWN, AND THAT IS HANDLED, NOT
*& GUESSED. ZCL_RAK_BP_SEARCH returns
*& ZCL_ZEGA_BP_MPC_EXT=>TS_BUSINESSPARTNER, which cannot be opened from
*& the CJS repository. Four components are confirmed by an existing
*& caller (ZCL_C022_KHULA_CERTI_LOGIC): PARTNER, ENGLISH_FULL_NAME,
*& ARABIC_FULL_NAME and TELEPHONE_NUMBER. Everything else this screen
*& shows - company name, address, grade, e-mail, trade licence - is read
*& through PICK( ), which ASSIGN COMPONENTs over a candidate list and
*& returns blank rather than failing.
*&
*& That is the same decision ATTACHMENTS_FOR_BACKEND( ) took for DIFFCRT
*& and for the same reason: never hand-write the shape of a standard
*& object you cannot open from here. A wrong guess would be a syntax
*& error that takes the whole class down at load; a candidate list is a
*& blank cell and a line on the trace naming which component answered.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- M029's own field vocabulary -----------------------------------
*   EVERY NAME IS THE LEGACY /QNV/SB_UI_DEFIN FIELD_NAME for NACO_1_*,
*   because that is what the backend's field control is keyed on end to
*   end. Renaming any of these silently switches off MANDATORY / ENABLED
*   / VISIBLE from the live field-control engine.
*
*   C_FLD_PARCEL, C_FLD_TERMS and C_FLD_DONATE are INHERITED from
*   ZCL_RAK_MUN_LOGIC and are deliberately not redeclared - an inherited
*   attribute cannot be redeclared and the Class Builder says so plainly.
*   The base's C_FLD_TERMS is 'CHECKBOX_3' and C_FLD_DONATE 'CHECKBOX_4',
*   which is exactly what NACO_1_2 carries.

*   The RAK_CONTRACTORCONTROL, migrated to ftype SEARCH. Its DATA1 in the
*   export is literally "Consultant".
    CONSTANTS c_fld_search  TYPE string VALUE 'MY_COMPONENT'.

*   The grid of added consultants. Not a legacy field - the legacy
*   control drew its own list inside itself - so this name is CJS's, and
*   it is the one place in this class where that is true. It is not
*   TOSAVE'd on its own: what reaches the backend is the carriers below.
    CONSTANTS c_fld_grid    TYPE string VALUE 'CONSULTANTS'.

*   The third declaration, above the two the base already knows about.
    CONSTANTS c_fld_agree   TYPE string VALUE 'CHECKBOX1'.

*   Carriers - TOSAVE in the export, no control on the screen.
    CONSTANTS c_fld_bp      TYPE string VALUE 'CONSULTANT_BP'.
    CONSTANTS c_fld_name    TYPE string VALUE 'CONSULTANTNAME'.
    CONSTANTS c_fld_licence TYPE string VALUE 'TRADELICENSE'.
    CONSTANTS c_fld_expiry  TYPE string VALUE 'LICENSEEXPIRY'.
    CONSTANTS c_fld_grade   TYPE string VALUE 'GRADE'.

*   The step the consultant is added on. STP1 is 0, STP2 is 1.
    CONSTANTS c_step_consultant TYPE i VALUE 1.

    METHODS zif_rak_journey_logic~on_search          REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PROTECTED SECTION.

*   Append one found partner to the consultant grid, and fill the
*   carriers. Read the note at the implementation before changing the
*   cell order - it is positional against ZRAK_T_JNY_COL.
    METHODS add_row
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
                is_bp  TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner.

*   First non-blank component of IS_BP named in IV_NAMES, a comma list.
*   Blank when none of them exists on the structure.
    METHODS pick
      IMPORTING is_bp     TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner
                iv_names  TYPE string
      RETURNING VALUE(rv) TYPE string.

*   Is this partner already in the grid? Column 4 is the BP id.
    METHODS already_added
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_bp     TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.

ENDCLASS.



CLASS zcl_m029_aco_logic IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_search.

*   CP, NOT AN OFFSET. Event and field names are short and
*   CX_SY_RANGE_OUT_OF_BOUNDS on a string offset is what took E016's Add
*   button down. A plain comparison cannot run off the end.
    CHECK to_upper( iv_field ) = c_fld_search.

    DATA(lv_term) = condense( io_ctx->get_val( c_fld_search ) ).
    IF lv_term IS INITIAL.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = COND string(
                         WHEN sy-langu = 'A'
                         THEN `يرجى إدخال قيمة للبحث.`
                         ELSE `Enter a value to search for.` ) ).
      RETURN.
    ENDIF.

*   ---- which of the three search methods -----------------------------
*   The engine puts the method dropdown's value in <FIELD>_IDTYPE. The
*   three the live screen offers are Trade License Number, Business
*   Partner and Company Name, and each is a DIFFERENT property on
*   TY_REQ - sending a company name under TRADE_LICENCE asks which
*   partner has a trade licence equal to a company name, matches
*   nothing, and tells the citizen "No data found", which is
*   indistinguishable from a mistyped number.
    DATA ls_req TYPE zcl_rak_bp_search=>ty_req.
    DATA(lv_by) = to_upper( io_ctx->get_val( |{ c_fld_search }_IDTYPE| ) ).

    CASE lv_by.
      WHEN 'BP' OR 'PARTNER' OR 'BUSINESS_PARTNER'.
        ls_req-partner       = lv_term.
      WHEN 'COMPANY' OR 'NAME' OR 'COMPANY_NAME'.
        ls_req-search_term   = lv_term.
      WHEN OTHERS.
*       Trade licence is the default because it is the first entry on the
*       live dropdown and the one the walkthrough uses.
        ls_req-trade_licence = lv_term.
    ENDCASE.

*   NO MOI CALL. This is a COMPANY lookup - MOI verifies a person against
*   the identity register, and asking it about a consultancy's trade
*   licence buys nothing while costing at least five seconds and a
*   WAIT UP TO whose implicit COMMIT ends the caller's LUW.
    ls_req-no_moi_call = abap_true.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

*   Every message reaches the citizen, and an error STOPS - an expired
*   licence must not become an added consultant.
    DATA(lv_err) = abap_false.
    LOOP AT ls_res-msg INTO DATA(ls_m).
      io_ctx->add_msg(
        iv_type = COND #( WHEN ls_m-type = 'E' OR ls_m-type = 'A' THEN 'Error'
                          WHEN ls_m-type = 'W' THEN 'Warning'
                          ELSE 'Information' )
        iv_text = CONV string( ls_m-message ) ).
      IF ls_m-type = 'E' OR ls_m-type = 'A'.
        lv_err = abap_true.
      ENDIF.
    ENDLOOP.
    IF lv_err = abap_true.
      RETURN.
    ENDIF.

    READ TABLE ls_res-rows INTO DATA(ls_bp) INDEX 1.
    IF sy-subrc <> 0.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = COND string(
                         WHEN sy-langu = 'A'
                         THEN `لم يتم العثور على استشاري بهذه البيانات.`
                         ELSE `No consultant found for that value.` ) ).
      RETURN.
    ENDIF.

    DATA(lv_bp) = CONV string( ls_bp-partner ).
    IF already_added( io_ctx = io_ctx iv_bp = lv_bp ) = abap_true.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = COND string(
                         WHEN sy-langu = 'A'
                         THEN `هذا الاستشاري مضاف بالفعل.`
                         ELSE `That consultant has already been added.` ) ).
      RETURN.
    ENDIF.

    add_row( io_ctx = io_ctx is_bp = ls_bp ).

*   Clear the search box so the next Add starts from an empty field
*   rather than re-adding what is already in the grid on a stray press.
    io_ctx->set_val( iv_name = c_fld_search iv_value = `` ).

  ENDMETHOD.


  METHOD add_row.

*   ---- THE CELL ORDER IS THE CONTRACT --------------------------------
*   SET_GRID_DATA( ) maps by name, but the COLUMNS handed back to it came
*   straight out of GET_GRID_DATA( ), so the map is an identity map and
*   cell N lands in configured column N. A cell appended out of order is
*   written to the neighbouring column; one appended past the last
*   configured column is dropped. Neither raises anything.
*
*   The order lives in ZRAK_T_JNY_COL for CONSULTANTS, seeded by
*   ZRAK_M029_LOAD, and it is:
*
*       10 COMPANY   20 ADDRESS   30 GRADE   40 BPID   50 EMAIL
*
*   Read that report before adding or reordering a column here.
    DATA(ls_grid) = io_ctx->get_grid_data( c_fld_grid ).

    DATA lt_cell TYPE zif_rak_journey=>tt_string.

*   COMPANY. The organisation name in the session language, falling back
*   to the other one - a blank English name with an Arabic name present
*   is a real shape for a local consultancy, and an empty first column
*   reads as a broken row.
    DATA(lv_company) = COND string(
      WHEN sy-langu = 'A' AND ls_bp-arabic_full_name IS NOT INITIAL
      THEN CONV string( ls_bp-arabic_full_name )
      WHEN ls_bp-english_full_name IS NOT INITIAL
      THEN CONV string( ls_bp-english_full_name )
      ELSE CONV string( ls_bp-arabic_full_name ) ).
    IF lv_company IS INITIAL.
      lv_company = pick( is_bp    = is_bp
                         iv_names = 'NAME_ORG1,ZZCOMPANY_NAME,MC_NAME1,NAME' ).
    ENDIF.
    APPEND lv_company TO lt_cell.

*   ADDRESS, GRADE and EMAIL are all read through PICK( ) - see the class
*   header. None of the three is among the four components an existing
*   caller has confirmed, so naming one directly would be a guess with a
*   class-wide syntax error behind it.
    APPEND pick( is_bp    = is_bp
                 iv_names = 'ADDRESS,STREET,CITY1,ZZADDRESS,ADDRESS_TEXT' ) TO lt_cell.
    APPEND pick( is_bp    = is_bp
                 iv_names = 'GRADE,ZZGRADE,CLASSIFICATION,CATEGORY' ) TO lt_cell.
    APPEND CONV string( is_bp-partner ) TO lt_cell.
    APPEND pick( is_bp    = is_bp
                 iv_names = 'SMTP_ADDR,EMAIL,E_MAIL,EMAILADDRESS,EMAIL_ADDRESS,ZZEMAIL' ) TO lt_cell.

    APPEND lt_cell TO ls_grid-rows.
    io_ctx->set_grid_data( iv_field = c_fld_grid is_data = ls_grid ).

*   ---- the carriers --------------------------------------------------
*   These are what actually reach the backend: the grid is CJS's own and
*   is not TOSAVE'd. The legacy screen holds one consultant per request,
*   so the carriers describe the LAST row added, which is the same row
*   the live control keeps.
    io_ctx->set_val( iv_name = c_fld_bp      iv_value = CONV string( is_bp-partner ) ).
    io_ctx->set_val( iv_name = c_fld_name    iv_value = lv_company ).
    io_ctx->set_val( iv_name = c_fld_licence
                     iv_value = pick( is_bp    = is_bp
                                      iv_names = 'ZZTRADE_LICENSE,TRADELICENSE,TRADE_LICENSE,LICENSE_NUMBER' ) ).
    io_ctx->set_val( iv_name = c_fld_expiry
                     iv_value = pick( is_bp    = is_bp
                                      iv_names = 'VALID_DATE_TO,LICENSEEXPIRY,LICENSE_EXPIRY,EXPIRY_DATE' ) ).
    io_ctx->set_val( iv_name = c_fld_grade
                     iv_value = pick( is_bp    = is_bp
                                      iv_names = 'GRADE,ZZGRADE,CLASSIFICATION,CATEGORY' ) ).

  ENDMETHOD.


  METHOD pick.

*   ASSIGN COMPONENT over a candidate list, first non-blank wins. The
*   structure cannot be opened from this repository, so this is how its
*   optional components are read - see the class header.
*
*   ASSIGN COMPONENT, NEVER ASSIGN (name). ZIF_EGA_FW_CJI~MAPPER's
*   assign-by-name is what dumped every DOK journey with
*   MOVE_TO_LIT_NOTALLOWED_NODATA when a technical name resolved to the
*   function module's own IMPORTING parameter. Component assignment
*   cannot reach outside the structure.
    SPLIT iv_names AT ',' INTO TABLE DATA(lt_name).
    LOOP AT lt_name INTO DATA(lv_name).
      ASSIGN COMPONENT condense( to_upper( lv_name ) )
             OF STRUCTURE is_bp TO FIELD-SYMBOL(<val>).
      IF sy-subrc = 0 AND <val> IS NOT INITIAL.
        rv = condense( CONV string( <val> ) ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD already_added.

*   Column 4 is BPID - see the order note in ADD_ROW( ).
*   INTO A VARIABLE FIRST. A functional method call is not reliably
*   accepted as the source of a LOOP AT on this release, and a syntax
*   error in one method takes the WHOLE class down at load - which
*   surfaces at every caller as "Method X is unknown or PROTECTED or
*   PRIVATE" and points nowhere near the cause.
    CHECK iv_bp IS NOT INITIAL.
    DATA(ls_grid) = io_ctx->get_grid_data( c_fld_grid ).
    LOOP AT ls_grid-rows INTO DATA(lt_row).
      READ TABLE lt_row INTO DATA(lv_cell) INDEX 4.
      IF sy-subrc = 0 AND condense( lv_cell ) = condense( iv_bp ).
        rv = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. The base chain is the PAID gate
*   plus ZCL_RAK_MUN_LOGIC's parcel check; a redefinition REPLACES it, so
*   omitting this call silently removes both - which is precisely how
*   E128 became submittable unpaid, twice. And it has to come before a
*   CHECK because a failing CHECK exits the method, taking them with it.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   VALUE #( BASE rt ... ) below rather than `rt = VALUE #( ... )`, so
*   what the chain returned is extended rather than discarded.

*   Only the consultant step. Guarded on the step and not merely on the
*   journey, or every later step would refuse to advance because a grid
*   it does not show is empty.
    IF iv_step = c_step_consultant.

*     AT LEAST ONE CONSULTANT. The grid's own REQUIRED flag cannot do
*     this - see the class header: MISSING_REQUIRED( ) checks required
*     COLUMNS against existing rows and lets an empty grid pass, by
*     design and in its own words.
*     Into a variable first - see the note in ALREADY_ADDED( ).
      DATA(ls_cons) = io_ctx->get_grid_data( c_fld_grid ).
      IF lines( ls_cons-rows ) = 0.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `يرجى إضافة استشاري واحد على الأقل قبل المتابعة.`
              ELSE `Add at least one consultant before continuing.` ) ) ).
      ENDIF.

*     THE THIRD DECLARATION. CHECKBOX_3 and CHECKBOX_4 are the base's
*     C_FLD_TERMS and C_FLD_DONATE, and CHECKBOX_3 carries REQUIRED in
*     the configuration, so VALIDATE_STEP( ) already refuses without it.
*     CHECKBOX1 - the "I Agree" above the two law paragraphs - is
*     configured REQUIRED too, so this is belt and braces rather than the
*     only enforcement, and it is here so that the reason given names the
*     terms rather than the field.
*
*     Deliberately NOT a check on C_FLD_DONATE. That is the five-dirham
*     Ajer donation and it is optional - requiring it would make a
*     charitable donation compulsory before a citizen could continue.
      IF io_ctx->get_val( c_fld_agree ) IS INITIAL.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `يجب قبول الشروط والأحكام قبل المتابعة.`
              ELSE `The terms and conditions must be accepted before continuing.` ) ) ).
      ENDIF.

    ENDIF.

  ENDMETHOD.


ENDCLASS.
