class ZCL_D008_SCHOOL_CYCL_CHG_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  constants C_OWN_ADD type STRING value 'OWNER_ADD' ##NO_TEXT.
  constants C_BLOB type STRING value 'OWNER_BLOB' ##NO_TEXT.

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
protected section.
private section.

  constants C_ROWSEP type STRING value '|' ##NO_TEXT.
  constants C_COLSEP type STRING value '~' ##NO_TEXT.
  constants C_GRID type STRING value 'OWNERS_SEARCH' ##NO_TEXT.
  constants C_EVT_OWNEW type STRING value 'OWN_NEW' ##NO_TEXT.
  constants C_EVT_OWNSR type STRING value 'OWN_SEARCH' ##NO_TEXT.
  constants C_EVT_OWNOK type STRING value 'OWN_OK' ##NO_TEXT.
  constants C_EVT_OWNCX type STRING value 'OWN_CANCEL' ##NO_TEXT.
  constants C_OWN_ID type STRING value 'IDENTIFICATION_POP' ##NO_TEXT.
  constants C_POP_OWN type STRING value 'OWNER' ##NO_TEXT.
  data C_OWN_NAME type STRING value 'IDENTIFICATION_POP' ##NO_TEXT.
  data C_OWN_EID type STRING value 'EMIRATES_ID_POP' ##NO_TEXT.
  data C_OWN_NAT type STRING value 'NATIONALITY_POP' ##NO_TEXT.
  data C_OWN_SHARE type STRING value 'SHARES_POP' ##NO_TEXT.
  data C_PAY_POLLS type STRING value 'PAY_POLLS' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'PARTNER_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'PARTNER_EMAIL' ##NO_TEXT.
  constants C_DOB type STRING value 'DATE_OF_BIRTH_POP' ##NO_TEXT.

  methods SED_FEES
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
ENDCLASS.



CLASS ZCL_D008_SCHOOL_CYCL_CHG_LOGIC IMPLEMENTATION.


    METHOD sed_fees.
*   One table, written whole, five times. There is no per-cell write in
*   ZIF_RAK_JOURNEY and no way for set_val( ) to reach a grid cell, so the shape
*   of this is fixed by the interface: build the rows, hand them over, done.
    DATA ls_data TYPE zif_rak_journey=>ty_table.
    DATA lt_grid TYPE zif_rak_journey=>tt_string.

*   COLUMNS ARE NAMED, and that is what makes this short. set_grid_data matches
*   them to the DEFAULT_VAL spec BY NAME, so:
*
*     - the order here does not have to match the spec's
*     - the amount columns can simply be LEFT OUT rather than sent empty
*
*   Leaving them out is the point. 0.00 on the form is a NUMBER cell rendering an
*   empty value; sending actual zeros would make "not answered" and "no charge"
*   the same answer, and on a fee schedule that distinction is the document.
*
*   K and L are upper case because grid_cols( ) upper-cases every column name it
*   parses. A lower-case name here matches nothing and is silently ignored - the
*   spec says unknown columns are dropped, so the failure would be three blank
*   rows rather than an error.
    ls_data-columns = VALUE #( ( `K1` ) ( `L1` ) ).
    ls_data-rows    = VALUE #(
      ( VALUE #( ( `SCHOOL` )  ( `School Fee` ) ) )
      ( VALUE #( ( `BOOKS` )   ( `Books Fee` ) ) )
      ( VALUE #( ( `UNIFORM` ) ( `Uniform Fee` ) ) ) ).

*   One list, five grids. A sixth cycle is one line here and one field in the
*   seed - not a sixth copy of this method.
    lt_grid = VALUE #( ( `FEES_PREKG` ) ( `FEES_KG` )
                       ( `FEES_C1` ) ( `FEES_C2` ) ( `FEES_C3` ) ).

    LOOP AT lt_grid INTO DATA(lv_grid).

*     NEVER OVERWRITE. On a resumed draft the rows are already in the model with
*     the citizen's amounts in them, and re-seeding would replace a completed fee
*     schedule with three empty ones without saying a word.
*
*     Test -ROWS and not the structure. get_grid_data publishes the COLUMNS even
*     when there are no rows yet - the interface is explicit that it does, so an
*     index can be resolved before anything is typed - which means the structure
*     is never initial and a plain IS INITIAL check here would seed exactly never.
      IF io_ctx->get_grid_data( lv_grid )-rows IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      io_ctx->set_grid_data( iv_field = lv_grid
                             is_data  = ls_data ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.
         DATA(lt_licenses) = io_ctx->get_grid_data( 'LICENSES' ).
        rs_data = io_ctx->get_backend_table( 'LICENSES' ).
**        DATA(lt_mat) = blob_read( io_ctx ).
**        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).

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

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    TYPES: BEGIN OF ty_fee,
             k1  TYPE string,
             l1  TYPE string,
             g1  TYPE string,
             g2  TYPE string,
             g3  TYPE string,
             g4  TYPE string,
             g5  TYPE string,
             g6  TYPE string,
             g7  TYPE string,
             g8  TYPE string,
             g9  TYPE string,
             g10 TYPE string,
             g11 TYPE string,
             g12 TYPE string,
           END OF ty_fee.
    DATA: lt_fees_prekg TYPE STANDARD TABLE OF ty_fee,
          lt_fees_kg    TYPE STANDARD TABLE OF ty_fee,
          lt_fees_c1    TYPE STANDARD TABLE OF ty_fee,
          lt_fees_c2    TYPE STANDARD TABLE OF ty_fee,
          lt_fees_c3    TYPE STANDARD TABLE OF ty_fee,
          lv_json       TYPE string.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.
    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 2), not omitted by oversight.
***** assign field details back to the IO_CTX
*   A test override stood here: it read CYCLE3GENDER, threw the citizen's answer
*   away and forced 'GIRL' back into the model on every post. Removed.

*   GENDER_C2 / GENDER_C3 are read BEFORE the loop that copies them into
*   CYCLE2GENDER / CYCLE3GENDER. They used to be picked up inside that same
*   LOOP, which made the result depend on the order CT_KV happened to arrive in:
*   if CYCLE3GENDER came before GENDER_C3, the variable was still empty and the
*   gender posted blank.
    DATA(lv_c2gender) = VALUE string( ct_kv[ key = 'GENDER_C2' ]-value OPTIONAL ).
    DATA(lv_c3gender) = VALUE string( ct_kv[ key = 'GENDER_C3' ]-value OPTIONAL ).

    LOOP AT ct_kv ASSIGNING FIELD-SYMBOL(<lfs_kv>).
      CASE <lfs_kv>-key.
        WHEN 'FEES_PREKG'.
          lv_json = <lfs_kv>-value.
          CALL METHOD /ui2/cl_json=>deserialize
            EXPORTING
              json = lv_json
            CHANGING
              data = lt_fees_prekg.
        WHEN 'FEES_KG'.
          lv_json = <lfs_kv>-value.
          CALL METHOD /ui2/cl_json=>deserialize
            EXPORTING
              json = lv_json
            CHANGING
              data = lt_fees_kg.
        WHEN 'FEES_C1'.
          lv_json = <lfs_kv>-value.
          CALL METHOD /ui2/cl_json=>deserialize
            EXPORTING
              json = lv_json
            CHANGING
              data = lt_fees_C1.
        WHEN 'FEES_C2'.
          lv_json = <lfs_kv>-value.
          CALL METHOD /ui2/cl_json=>deserialize
            EXPORTING
              json = lv_json
            CHANGING
              data = lt_fees_C2.
        WHEN 'FEES_C3'.
          lv_json = <lfs_kv>-value.
          CALL METHOD /ui2/cl_json=>deserialize
            EXPORTING
              json = lv_json
            CHANGING
              data = lt_fees_C3.
          CLEAR lv_json.
        when 'CYCLE3GENDER'.
          <lfs_kv>-value = lv_c3gender.
          when 'CYCLE2GENDER'.
          <lfs_kv>-value = lv_c2gender.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_fees_prekg ASSIGNING FIELD-SYMBOL(<lfs_prekg>).
      CASE <lfs_prekg>-k1.
        WHEN 'SCHOOL'.
**          io_ctx->set_val( iv_name = 'INPUT_1' iv_value = <lfs_prekg>-g1 ).
          READ TABLE ct_kv ASSIGNING FIELD-SYMBOL(<lfs_kv1>) WITH KEY key = 'FEE_SCH_PREKG'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_prekg>-g1.
          ENDIF.
        WHEN 'BOOKS'.
**          io_ctx->set_val( iv_name = 'INPUT_2' iv_value = <lfs_prekg>-g1 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_PREKG'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_prekg>-g1.
          ENDIF.
        WHEN 'UNIFORM'.
**          io_ctx->set_val( iv_name = 'INPUT_3' iv_value = <lfs_prekg>-g1 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_PREKG'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_prekg>-g1.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_fees_kg ASSIGNING FIELD-SYMBOL(<lfs_kg>).
      CASE <lfs_kg>-k1.
        WHEN 'SCHOOL'.
**          io_ctx->set_val( iv_name = 'INPUT_5' iv_value = <lfs_kg>-g1 ).
**          io_ctx->set_val( iv_name = 'INPUT_9' iv_value = <lfs_kg>-g2 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_KG1'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_kg>-g1.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_KG2'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_kg>-g2.
          ENDIF.
        WHEN 'BOOKS'.
**          io_ctx->set_val( iv_name = 'INPUT_6' iv_value = <lfs_kg>-g1 ).
**          io_ctx->set_val( iv_name = 'INPUT_10' iv_value = <lfs_kg>-g2 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_KG1'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_kg>-g1.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_KG2'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_kg>-g2.
          ENDIF.
        WHEN 'UNIFORM'.
**          io_ctx->set_val( iv_name = 'INPUT_7' iv_value = <lfs_kg>-g1 ).
**          io_ctx->set_val( iv_name = 'INPUT_11' iv_value = <lfs_kg>-g2 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_KG1'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_kg>-g1.
          ENDIF.
      READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_KG2'.
      IF sy-subrc IS INITIAL.
        <lfs_kv1>-value = <lfs_kg>-g2.
      ENDIF.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_fees_C1 ASSIGNING FIELD-SYMBOL(<lfs_c1>).
      CASE <lfs_c1>-k1.
        WHEN 'SCHOOL'.
**          io_ctx->set_val( iv_name = 'INPUT_13' iv_value = <lfs_c1>-g1 ).
**          io_ctx->set_val( iv_name = 'INPUT_16' iv_value = <lfs_c1>-g2 ).
**          io_ctx->set_val( iv_name = 'INPUT_19' iv_value = <lfs_c1>-g3 ).
**          io_ctx->set_val( iv_name = 'INPUT_22' iv_value = <lfs_c1>-g4 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G1'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g1.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G2'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g2.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G3'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g3.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G4'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g4.
          ENDIF.
        WHEN 'BOOKS'.
**          io_ctx->set_val( iv_name = 'INPUT_14' iv_value = <lfs_c1>-g1 ).
**          io_ctx->set_val( iv_name = 'INPUT_17' iv_value = <lfs_c1>-g2 ).
**          io_ctx->set_val( iv_name = 'INPUT_20' iv_value = <lfs_c1>-g3 ).
**          io_ctx->set_val( iv_name = 'INPUT_23' iv_value = <lfs_c1>-g4 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G1'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g1.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G2'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g2.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G3'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g3.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G4'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g4.
          ENDIF.
        WHEN 'UNIFORM'.
**          io_ctx->set_val( iv_name = 'INPUT_15' iv_value = <lfs_c1>-g1 ).
**          io_ctx->set_val( iv_name = 'INPUT_18' iv_value = <lfs_c1>-g2 ).
**          io_ctx->set_val( iv_name = 'INPUT_21' iv_value = <lfs_c1>-g3 ).
**          io_ctx->set_val( iv_name = 'INPUT_24' iv_value = <lfs_c1>-g4 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G1'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g1.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G2'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g2.
          ENDIF.
*         G3 and G4, not G1 and G2 again. These two read the grade 1 and grade 2
*         keys while assigning the grade 3 and grade 4 amounts, so grades 3 and 4
*         never reached the backend and grades 1 and 2 were posted with the wrong
*         figures. The BOOKS branch directly above uses G1..G4 correctly, which
*         is what makes this a copy-paste slip rather than a decision.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G3'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g3.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G4'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c1>-g4.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_fees_C2 ASSIGNING FIELD-SYMBOL(<lfs_c2>).
      CASE <lfs_c2>-k1.
        WHEN 'SCHOOL'.
**          io_ctx->set_val( iv_name = 'INPUT_25' iv_value = <lfs_c2>-g5 ).
**          io_ctx->set_val( iv_name = 'INPUT_28' iv_value = <lfs_c2>-g6 ).
**          io_ctx->set_val( iv_name = 'INPUT_31' iv_value = <lfs_c2>-g7 ).
**          io_ctx->set_val( iv_name = 'INPUT_34' iv_value = <lfs_c2>-g8 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G5'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g5.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G6'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g6.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G7'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g7.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G8'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g8.
          ENDIF.
        WHEN 'BOOKS'.
**          io_ctx->set_val( iv_name = 'INPUT_26' iv_value = <lfs_c2>-g5 ).
**          io_ctx->set_val( iv_name = 'INPUT_29' iv_value = <lfs_c2>-g6 ).
**          io_ctx->set_val( iv_name = 'INPUT_32' iv_value = <lfs_c2>-g7 ).
**          io_ctx->set_val( iv_name = 'INPUT_35' iv_value = <lfs_c2>-g8 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G5'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g5.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G6'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g6.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G7'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g7.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G8'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g8.
          ENDIF.
        WHEN 'UNIFORM'.
**          io_ctx->set_val( iv_name = 'INPUT_27' iv_value = <lfs_c2>-g5 ).
**          io_ctx->set_val( iv_name = 'INPUT_30' iv_value = <lfs_c2>-g6 ).
**          io_ctx->set_val( iv_name = 'INPUT_33' iv_value = <lfs_c2>-g7 ).
**          io_ctx->set_val( iv_name = 'INPUT_36' iv_value = <lfs_c2>-g8 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G5'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g5.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G6'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g6.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G7'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g7.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G8'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c2>-g8.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_fees_C3 ASSIGNING FIELD-SYMBOL(<lfs_c3>).
      CASE <lfs_c3>-k1.
        WHEN 'SCHOOL'.
**          io_ctx->set_val( iv_name = 'INPUT_37' iv_value = <lfs_c3>-g9 ).
**          io_ctx->set_val( iv_name = 'INPUT_40' iv_value = <lfs_c3>-g10 ).
**          io_ctx->set_val( iv_name = 'INPUT_43' iv_value = <lfs_c3>-g11 ).
**          io_ctx->set_val( iv_name = 'INPUT_36' iv_value = <lfs_c3>-g12 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G9'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g9.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G10'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g10.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G11'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g11.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_SCH_G12'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g12.
          ENDIF.
        WHEN 'BOOKS'.
**          io_ctx->set_val( iv_name = 'INPUT_38' iv_value = <lfs_c3>-g9 ).
**          io_ctx->set_val( iv_name = 'INPUT_41' iv_value = <lfs_c3>-g10 ).
**          io_ctx->set_val( iv_name = 'INPUT_44' iv_value = <lfs_c3>-g11 ).
**          io_ctx->set_val( iv_name = 'INPUT_47' iv_value = <lfs_c3>-g12 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G9'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g9.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G10'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g10.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G11'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g11.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_BK_G12'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g12.
          ENDIF.
        WHEN 'UNIFORM'.
*****          io_ctx->set_val( iv_name = 'INPUT_39' iv_value = <lfs_c3>-g9 ).
*****          io_ctx->set_val( iv_name = 'INPUT_42' iv_value = <lfs_c3>-g10 ).
*****          io_ctx->set_val( iv_name = 'INPUT_45' iv_value = <lfs_c3>-g11 ).
*****          io_ctx->set_val( iv_name = 'INPUT_48' iv_value = <lfs_c3>-g12 ).
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G9'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g9.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G10'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g10.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G11'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g11.
          ENDIF.
          READ TABLE ct_kv ASSIGNING <lfs_kv1> WITH KEY key = 'FEE_UNI_G12'.
          IF sy-subrc IS INITIAL.
            <lfs_kv1>-value = <lfs_c3>-g12.
          ENDIF.
      ENDCASE.
    ENDLOOP.

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
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel.
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  endmethod.


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
    " TELEPHONE, POBOX, PARCELID, the 5 MANAGER* fields, and the CURRENT
    " state of the PREKG/KG/CYCLE1-3 checkboxes + their fee fields (so
    " the applicant sees what the school already offers before adding or
    " reducing) here from the same selected license/school record.
    " io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = |{ ls_school-name_en }| ).
    " io_ctx->set_val( iv_name = 'PREKG' iv_value = |{ ls_school-prekg_active }| ).
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

    CHECK iv_step = 1.   " zero-based: step 2 "Grades" in the wizard

*    DATA(lv_any_stage) = abap_false.
*    LOOP AT VALUE string_table( ( 'PREKG' ) ( 'KG' ) ( 'CYCLE1' ) ( 'CYCLE2' ) ( 'CYCLE3' ) ) INTO DATA(lv_stage).
*      IF io_ctx->get_val( lv_stage ) = abap_true.
*        lv_any_stage = abap_true.
*      ENDIF.
*    ENDLOOP.

*    IF lv_any_stage = abap_false.
*      rt_msg = VALUE #( ( type = 'Error' text = 'Select at least one education stage.' ) ).
*    ENDIF.
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

*      io_ctx->set_val( iv_name = 'OWNER_BP' iv_value = |{ lv_loginbp }| ).
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).

      IF sy-langu = c_lang_en.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = c_PARTNER_MOBILE iv_value = CONV #( ls_bp-mobile_number ) ).
      io_ctx->set_val( iv_name = c_PARTNER_EMAIL iv_value = CONV #( ls_bp-email_address ) ).


      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

    ENDIF.

**    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
***    DATA(user_data) = io_ctx->get_val( iv_name = 'PARAM1' ).
***    user_data = ''.
**    zcl_ega_cj_utility=>get_bp(
**      EXPORTING
**        qv_key  = user_data
**      IMPORTING
**        loginbp = DATA(loginbp)
**        rolebp  = DATA(rolebp)
**        role    = DATA(role)
**    ).
**
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
**
***    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
***   The signed-in citizen, read from the business partner register. What stood
***   here was a fixed name and Emirates ID, written AFTER the real read, so every
***   applicant saw and posted the same test person.
**    NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
**      EXPORTING
**        iv_bp_id      = CONV bu_partner( loginbp )
**      IMPORTING
**        es_bp_details = DATA(ls_bp_real) ).
**    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = COND #(
**      WHEN sy-langu <> 'E' AND ls_bp_real-bp_name_ar IS NOT INITIAL
**      THEN CONV string( ls_bp_real-bp_name_ar )
**      ELSE CONV string( ls_bp_real-bp_name ) ) ).
**    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( ls_bp_real-emirates_id ) ).
***    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
**
***    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
**    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).
****   added below method to display fees structure for PREKG, KG, Cycle1, CYCLE2, CYCLE3
**    sed_fees( io_ctx ).
  endmethod.
ENDCLASS.
