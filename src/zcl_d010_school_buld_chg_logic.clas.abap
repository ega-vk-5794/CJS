class ZCL_D010_SCHOOL_BULD_CHG_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
protected section.

  constants C_GRID type STRING value 'BUILDINGS' ##NO_TEXT.

  methods TO_I
    importing
      value(IV_VAL) type STRING
    returning
      value(RV) type I .
  methods CELL
    importing
      !IT_ROW type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_IX type I
    returning
      value(RV) type STRING .
ENDCLASS.



CLASS ZCL_D010_SCHOOL_BULD_CHG_LOGIC IMPLEMENTATION.


  METHOD cell.
    IF lines( it_row ) >= iv_ix AND iv_ix > 0.
      rv = it_row[ iv_ix ].
      CONDENSE rv.
    ENDIF.
  ENDMETHOD.


  METHOD to_i.
    CONDENSE iv_val NO-GAPS.
    IF iv_val IS INITIAL.
      RETURN.
    ENDIF.

*   TRY rather than a regex or a CO check on '0123456789'. Leading zeros, a plus
*   sign and a decimal point are all things a citizen types into a number box, and
*   the kernel already knows which of them it can convert.
    TRY.
        rv = CONV i( iv_val ).
      CATCH cx_sy_conversion_error.
        CLEAR rv.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.
        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).

        " REVIEW: replace with the real school-license read (the export
        " names FM ZFM_EGA_CJ_FW_READ_TABLE_DATAN / context LICENCES).
*        SELECT license_no, school_name, issued_at, expired_at
*          FROM ztb_dok_licenses                         "#EC CI_NOORDBY
*          WHERE partner = @io_ctx->get_val( 'OWNER_BP' )
*          INTO TABLE @DATA(lt_lic).
*
*        LOOP AT lt_lic INTO DATA(ls_lic).
*          APPEND VALUE #( ( |{ ls_lic-license_no }| )
*                          ( |{ ls_lic-school_name }| )
*                          ( |{ ls_lic-issued_at DATE = USER }| )
*                          ( |{ ls_lic-expired_at DATE = USER }| ) ) TO rs_table-rows.
*        ENDLOOP.

      WHEN 'OWNERS'.
        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile Number` ) ( `E-mail` ) ).

        " REVIEW: replace with the real current-owners read for the
        " SELECTED license (export context OWNERS_DISP).
*        SELECT partner_name, nationality, share_pct, mobile, email
*          FROM ztb_dok_owners                           "#EC CI_NOORDBY
*          WHERE license_no = @io_ctx->get_val( 'LICENSE_SEL' )
*          INTO TABLE @DATA(lt_own).
*
*        LOOP AT lt_own INTO DATA(ls_own).
*          APPEND VALUE #( ( |{ ls_own-partner_name }| )
*                          ( |{ ls_own-nationality }|   )
*                          ( |{ ls_own-share_pct }|     )
*                          ( |{ ls_own-mobile }|        )
*                          ( |{ ls_own-email }|         ) ) TO rs_table-rows.
*        ENDLOOP.

      WHEN 'BUILDINGS'.
        " Column order matches the export's LEVEL_CON='T' children of
        " BUILDINGS: Block Name, No. of floors, No. of rooms.
*        rs_data-columns = VALUE #( ( `Block Name` ) ( `No. of floors` ) ( `No. of rooms` ) ).

        " REVIEW: as with TREES/OWNERSTABLE on the E026/D001 journeys,
        " the exact API for reading back an in-progress MTABLE_CADD/
        " MTABLE_DELETE-editable grid's current rows is not documented
        " in the templates given.
*        DATA(lt_rows) = io_ctx->get_val( 'BUILDINGS' ).   " REVIEW: retrieval API unconfirmed
        " ... deserialize lt_rows into rs_table-rows here ...

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
*  EXPORTING
*    IO_CTX =
*    .
*    DATA(ls_g) = io_ctx->get_grid_data( 'BUILDINGS' ).
*    CHECK ls_g-rows IS NOT INITIAL.
*    DATA ls_clean TYPE zif_rak_journey=>ty_table.
*    ls_clean-columns = ls_g-columns.
*    LOOP AT ls_g-rows INTO DATA(lt_row).
*      CHECK NOT ( VALUE #( lt_row[ 3 ] OPTIONAL ) CS '.' ).
*      APPEND lt_row TO ls_clean-rows.
*    ENDLOOP.
*    IF lines( ls_clean-rows ) <> lines( ls_g-rows ).
*      io_ctx->set_grid_data( iv_field = 'BUILDINGS' is_data = ls_clean ).
*    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.



    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 2), not omitted by oversight.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_TABLES =
*    .



    DATA(lv_sel) = io_ctx->get_val( 'LIC_SELECT' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel.
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.





  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CHECK to_upper( iv_field ) = 'LICENSE_SEL'.

    DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
    IF lv_license IS INITIAL.
      RETURN.
    ENDIF.

    " REVIEW: replace with the real license/school/manager detail read —
    " placeholder shown for the pattern only.
*    SELECT SINGLE license_no, issued_at, expired_at
*      FROM ztb_dok_licenses
*      WHERE license_no = @lv_license
*      INTO @DATA(ls_lic).
*
*    IF sy-subrc = 0.
*      io_ctx->set_val( iv_name = 'LICNO' iv_value = |{ ls_lic-license_no }| ).
*      io_ctx->set_val( iv_name = 'LICISSUED' iv_value = |{ ls_lic-issued_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_lic-expired_at DATE = USER }| ).
*    ENDIF.

    " REVIEW: populate SCHOOLNAMEEN/AR, TRADELICNO, SCHOOLADDRESS,
    " TELEPHONE, POBOX, PARCELID, and the 5 MANAGER* fields here from the
    " same selected license/school record.
    " io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = |{ ls_school-name_en }| ).
    " io_ctx->set_val( iv_name = 'MANAGERNAME'  iv_value = |{ ls_school-manager_name }| ).

*   Fires for every field on the journey, so the first thing to do is leave unless
*   it is ours. Without this the totals are recalculated when the citizen edits
*   something unrelated - harmless here, and the habit that makes a handler slow
*   on a journey with sixty fields.
    CHECK to_upper( iv_field ) = c_grid.

    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

*    DATA lv_floors TYPE i.
*    DATA lv_rooms  TYPE i.

*   Columns are positional in DEFAULT_VAL order: 1 BLK, 2 FLR, 3 RMS. ls_g-columns
*   carries the names if you would rather resolve an index than count - worth doing
*   the moment a spec has more than about four columns, because a miscount reads as
*   a wrong total rather than as an error.
*    LOOP AT ls_g-rows INTO DATA(lt_row).
*      lv_floors = lv_floors + to_i( cell( it_row = lt_row iv_ix = 2 ) ).
*      lv_rooms  = lv_rooms  + to_i( cell( it_row = lt_row iv_ix = 3 ) ).
*    ENDLOOP.

*    io_ctx->set_val( iv_name = 'TOTAL_FLOORS' iv_value = |{ lv_floors }| ).
*    io_ctx->set_val( iv_name = 'TOTAL_ROOMS'  iv_value = |{ lv_rooms }| ).


  ENDMETHOD.


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

    CHECK iv_step = 1.   " zero-based: step 2 "Building" in the wizard

*    DATA(lv_buildings) = io_ctx->get_val( 'BUILDINGS' ).
    DATA(ls_g) = io_ctx->get_grid_data( 'BUILDINGS' ).

    IF ls_g-rows IS INITIAL.
      APPEND VALUE #( type = 'Error' text = 'Add at least one building.' ) TO rt.
      RETURN.
    ENDIF.

    LOOP AT ls_g-rows INTO DATA(lt_row).
      IF lt_row[ 1 ] IS INITIAL OR lt_row[ 2 ] IS INITIAL OR lt_row[ 3 ] IS INITIAL.
        APPEND VALUE #( type = 'Error'
                        text = |Building { sy-tabix }: block name, floors and rooms are all required.| ) TO rt.
      ENDIF.
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
*
    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
*
    zcl_ega_cj_utility=>get_bp(
      EXPORTING
        qv_key  = user_data
      IMPORTING
        loginbp = DATA(loginbp)
        rolebp  = DATA(rolebp)
        role    = DATA(role)
    ).

    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = CONV string( '3000000049' ) ). "'3000000049' ).

  endmethod.
ENDCLASS.
