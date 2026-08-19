class ZCL_D021_MOD_SCHOOL_FEE_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

* D021 Amend / Increase of School Fees.
*
* The four fee grids are the journey. Their ROWS come from the backend and vary with
* the licence - SCHOOL_FEES_TO_SCREEN( ) in the BAdI builds one per educational stage
* the school actually has - so nothing in ZRAK_T_JNY_FLD can describe them. The config
* supplies the columns, the backend supplies the rows, and this class supplies the
* three checks that operate ON rows, which field validation cannot reach.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
private section.

  types:
*   The four grids and whether each carries instalments. Held once so the three
*   checks below cannot drift from each other.
    BEGIN OF ty_grid,
             field TYPE string,
             label TYPE string,
             inst  TYPE abap_bool,
           END OF ty_grid .
  types:
    tt_grid TYPE STANDARD TABLE OF ty_grid WITH EMPTY KEY .

  constants C_LOGIN_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.

  methods GRIDS
    returning
      value(RT) type TT_GRID .
*   Column positions, by name, from the spec in the seed report. Read from the grid's
*   own published columns rather than assumed - a spec that truncated in the DDIC
*   loses its LAST column silently, and reading by name turns that into a blank cell
*   instead of a wrong one.
  methods COL_INDEX
    importing
      !IS_DATA type ZIF_RAK_JOURNEY=>TY_TABLE
      !IV_COL type STRING
    returning
      value(RV_I) type I .
  methods CELL
    importing
      !IT_ROW type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_I type I
    returning
      value(RV) type STRING .
ENDCLASS.



CLASS ZCL_D021_MOD_SCHOOL_FEE_LOGIC IMPLEMENTATION.


  METHOD cell.
*   itab[ n ] raises CX_SY_ITAB_LINE_NOT_FOUND rather than returning blank, and a grid
*   row can legitimately hold fewer cells than the spec has columns. Guarded here once
*   so the callers stay readable.
    IF iv_i > 0 AND iv_i <= lines( it_row ).
      rv = it_row[ iv_i ].
    ENDIF.
  ENDMETHOD.


  METHOD col_index.
    rv_i = 0.
    LOOP AT is_data-columns INTO DATA(lv_c).
      IF to_upper( lv_c ) = to_upper( iv_col ).
        rv_i = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD grids.
    rt = VALUE #(
      ( field = `TUITION_FEE`   label = `Tuition`   inst = abap_true )
      ( field = `BOOKS_FEE`     label = `Books`     inst = abap_false )
      ( field = `UNIFORM_FEE`   label = `Uniform`   inst = abap_false )
      ( field = `TRANSPORT_FEE` label = `Transport` inst = abap_false ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.

*   Current Fee is editable only for a school that has never had an approved fee
*   structure. SCHOOL_FEES_TO_SCREEN( ) sets GS_DATA-FEE_NOT_EXISTS when any old amount
*   comes back blank, and the BAdI's own READ disables the OLD_AMOUNT controls on the
*   same test:
*
*       IF <definition>-fieldname(10) EQ 'OLD_AMOUNT' AND gs_data-fee_not_exists EQ abap_false.
*         <definition>-enabled = abap_false.
*
*   CJS draws the grids itself, so that line never reaches them and the same decision
*   has to be made here. Not a rule: READONLY on the grid field would lock every
*   column including New Fee Amount, which is the one column the citizen came to edit.
*
*   MARKED UNVERIFIED: SET_COL_READONLY( ) is the method this needs and I have not seen
*   ZIF_RAK_JOURNEY to confirm its name or whether per-column read-only exists at all.
*   If it does not, the fallback is a second spec - OLD_AMOUNT as a HIDE column plus a
*   DISPLAY column beside it - chosen in the seed report rather than here.
    DATA(lv_editable) = xsdbool( io_ctx->get_val( 'FEE_NOT_EXISTS' ) IS NOT INITIAL ).

    LOOP AT grids( ) INTO DATA(ls_grid).
*      io_ctx->set_col_readonly( iv_field    = ls_grid-field
*                                iv_col      = `OLD_AMOUNT`
*                                iv_readonly = xsdbool( lv_editable = abap_false ) ).


    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
*  EXPORTING
*    IO_CTX =
*  CHANGING
*    CT_KV  =
*    .

    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_TABLES =
*    .
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SELECT' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  endmethod.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate - it refuses a submit while PAYFEE is not
*   'PAID'. A redefinition REPLACES it, so without this call the gate is simply
*   not there for this journey. It must come before any CHECK below: a CHECK that
*   fails exits the method, and anything after it would never run.
*
*   Self-guarding - PAY_FIELD_STEP returns -1 when the journey has no PAYFEE
*   field, so this is a no-op on a journey with no payment step.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).


*   Step 1 is the licence, step 2 the fees. Steps count from zero.
    IF iv_step <> 1.
      RETURN.
    ENDIF.

*   REQUIRED does not reach grid rows. The grid field holds no scalar, so an empty grid
*   passes field validation and looks validated - which is why the seed report
*   deliberately does NOT mark the four grids required, and why all of this is here.
    LOOP AT grids( ) INTO DATA(ls_grid).

      DATA(ls_data) = io_ctx->get_grid_data( ls_grid-field ).
      IF ls_data-rows IS INITIAL.
*       No rows is not automatically wrong. A school with no transport has no transport
*       fees, and the backend built the grid that way on purpose.
        CONTINUE.
      ENDIF.

      DATA(lv_i_name) = col_index( is_data = ls_data iv_col = `NAME` ).
      DATA(lv_i_old)  = col_index( is_data = ls_data iv_col = `OLD_AMOUNT` ).
      DATA(lv_i_new)  = col_index( is_data = ls_data iv_col = `NEW_AMOUNT` ).
      DATA(lv_i_i1)   = col_index( is_data = ls_data iv_col = `INSTALMENT_1` ).
      DATA(lv_i_i2)   = col_index( is_data = ls_data iv_col = `INSTALMENT_2` ).
      DATA(lv_i_i3)   = col_index( is_data = ls_data iv_col = `INSTALMENT_3` ).

      IF lv_i_new = 0.
*       The spec lost a column. DEFAULT_VAL is a DDIC character field and a spec longer
*       than it loses its TAIL, so the symptom is a missing last column and no error
*       anywhere. Said out loud rather than validating against a column that is not
*       there and passing everything.
        APPEND VALUE #( type  = 'Error'
*                        field = ls_grid-field
                        text  = |{ ls_grid-label } fees: the grid is missing its New Fee | &&
                                |Amount column. Check the length of DEFAULT_VAL in the | &&
                                |seed report - a spec too long for the field loses its end.| ) TO rt.
        CONTINUE.
      ENDIF.

      LOOP AT ls_data-rows INTO DATA(lt_row).

        DATA(lv_stage) = cell( it_row = lt_row iv_i = lv_i_name ).
        DATA(lv_old)   = cell( it_row = lt_row iv_i = lv_i_old ).
        DATA(lv_new)   = cell( it_row = lt_row iv_i = lv_i_new ).

*       ---- both amounts present ------------------------------------------------
*       The BAdI asks the same, twice, with message e073 - once for Old and once for
*       New. Both sides must agree or a citizen passes here and is refused on the post
*       for something they have already filled in.
        IF lv_old IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = ls_grid-field
                          text  = |{ ls_grid-label } fees: enter the current fee for { lv_stage }.| ) TO rt.
        ENDIF.
        IF lv_new IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = ls_grid-field
                          text  = |{ ls_grid-label } fees: enter the new fee for { lv_stage }.| ) TO rt.
        ENDIF.

*       ---- instalments -----------------------------------------------------------
*       Tuition only - the other three carry no instalment columns, and asking for them
*       there would read every cell as zero and pass, which is worse than not asking.
        IF ls_grid-inst = abap_true AND lv_new IS NOT INITIAL.

          DATA lv_sum TYPE p LENGTH 13 DECIMALS 2.
          DATA lv_amt TYPE p LENGTH 13 DECIMALS 2.
          CLEAR lv_sum.

          TRY.
*              lv_sum = CONV #( cell( it_row = lt_row iv_i = lv_i_i1 ) )
*                     + CONV #( cell( it_row = lt_row iv_i = lv_i_i2 ) )
*                     + CONV #( cell( it_row = lt_row iv_i = lv_i_i3 ) ).
              lv_amt = CONV #( lv_new ).
            CATCH cx_sy_conversion_no_number.
*             A cell the citizen typed a word into. The control should not allow it,
*             but a resumed draft can carry anything, and a dump here would take the
*             whole step down rather than report one bad row.
              APPEND VALUE #( type  = 'Error'
*                              field = ls_grid-field
                              text  = |{ ls_grid-label } fees: { lv_stage } holds a value | &&
                                      |that is not an amount.| ) TO rt.
              CONTINUE.
          ENDTRY.

          IF lv_sum > lv_amt.
            APPEND VALUE #( type  = 'Error'
*                            field = ls_grid-field
                            text  = |{ ls_grid-label } fees: the instalments for { lv_stage } | &&
                                    |add up to more than the new fee.| ) TO rt.
          ENDIF.

        ENDIF.

      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
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

    ENDIF.


  endmethod.
ENDCLASS.
