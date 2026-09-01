CLASS zcl_e031_matstorage_logic DEFINITION
 PUBLIC INHERITING FROM zcl_rak_journey_logic CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_search          REDEFINITION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post     REDEFINITION.
  PRIVATE SECTION.
    CONSTANTS c_min_search_len TYPE i      VALUE 3.
    CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.
    CONSTANTS c_owner_bp       TYPE string VALUE 'OWNER_BP'.
    CONSTANTS c_step_storage   TYPE i      VALUE 2.   " 0-based: APPL,COMP,STORAGE
    TYPES: BEGIN OF ty_fan, src TYPE string, key_a TYPE string, fld_a TYPE string, fld_b TYPE string, END OF ty_fan.
    TYPES: tt_fan TYPE STANDARD TABLE OF ty_fan WITH EMPTY KEY.
    METHODS fan_map RETURNING VALUE(rt) TYPE tt_fan .

ENDCLASS.



CLASS ZCL_E031_MATSTORAGE_LOGIC IMPLEMENTATION.


  METHOD fan_map.
    rt = VALUE #(
      ( src = 'APP_ROLE'    key_a = 'REP' fld_a = 'PARTNER_REP_FLG' fld_b = 'PARTNER_OWNER_FLG' )
      ( src = 'PERMIT_MODE' key_a = 'YES' fld_a = 'PERMIT_YES_FLG'  fld_b = 'PERMIT_NO_FLG' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.
    LOOP AT fan_map( ) INTO DATA(ls).
      DATA lv_v TYPE string.
      CLEAR lv_v.
      READ TABLE ct_kv INTO DATA(ls_s) WITH KEY key = ls-src.
      IF sy-subrc = 0. lv_v = to_upper( condense( CONV string( ls_s-value ) ) ). ENDIF.
      LOOP AT ct_kv ASSIGNING FIELD-SYMBOL(<kv>) WHERE key = ls-fld_a OR key = ls-fld_b.
        IF <kv>-key = ls-fld_a.
          <kv>-value = COND string( WHEN lv_v = ls-key_a THEN `X` ELSE `` ).
        ELSE.
          <kv>-value = COND string( WHEN lv_v = ls-key_a THEN `` ELSE `X` ).
        ENDIF.
      ENDLOOP.
      DELETE ct_kv WHERE key = ls-src.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    DATA(lv_f) = to_upper( iv_field ).
    LOOP AT fan_map( ) INTO DATA(ls) WHERE src = lv_f.
      DATA(lv_v) = to_upper( condense( io_ctx->get_val( ls-src ) ) ).
      io_ctx->set_val( iv_name = ls-fld_a iv_value = COND string( WHEN lv_v = ls-key_a THEN `X` ELSE `` ) ).
      io_ctx->set_val( iv_name = ls-fld_b iv_value = COND string( WHEN lv_v = ls-key_a THEN `` ELSE `X` ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   THE BASE CALL IS THE PAID GATE - it refuses a submit while PAYFEE <> 'PAID'.
*   It has to run BEFORE the CHECK below: a failing CHECK exits the method, so a
*   CHECK placed first skips the gate on every step this handler does not own,
*   which is every step where payment is actually decided. Nothing here assigns
*   RT today; when the block below is revived it must EXTEND it with
*   VALUE #( BASE rt ... ), never assign over it, or the gate's own messages go.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

    CHECK iv_step = c_step_storage.
    " STILL DEAD. The block below was written against an assumed get_grid( )
    " that does not exist: the real accessor is io_ctx->get_grid_data( <field> ),
    " which returns ty_table - COLUMNS plus ROWS as plain string tables, NOT the
    " typed row structure this code reads (<row>-material_type and friends). See
    " ZCL_E016/E017/E018 for the shape that works. Reviving it also needs the
    " grid field name confirmed and a decision on whether >=1 row is really
    " required, so it is left off rather than guessed at.
*    DATA(lt_rows) = io_ctx->get_grid( 'MATERIALS' ).
*    IF lt_rows IS INITIAL.
*      rt = VALUE #( ( type = 'Error' text = 'Add at least one material row' ) ).
*      RETURN.
*    ENDIF.
*    IF lines( lt_rows ) > 2.
*      rt = VALUE #( ( type = 'Error' text = 'A maximum of two material rows is allowed' ) ).
*      RETURN.
*    ENDIF.
*    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<row>).
*      IF     <row>-material_type    IS INITIAL
*          OR <row>-quantity         IS INITIAL
*          OR <row>-unit             IS INITIAL
*          OR <row>-outside_duration IS INITIAL.
*        rt_msg = VALUE #( ( type = 'Error' text = 'Complete every column on each material row' ) ).
*        RETURN.
*      ENDIF.
*    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    CHECK to_upper( iv_field ) = c_owner_bp.
    DATA(lv_term) = condense( io_ctx->get_val( c_owner_bp ) ).
    IF strlen( lv_term ) < c_min_search_len.
      io_ctx->add_msg( iv_type = 'Warning' iv_text = |Enter at least { c_min_search_len } characters to search| ).
      RETURN.
    ENDIF.
    DATA(lv_idt) = io_ctx->get_val( |{ c_owner_bp }_IDTYPE| ).
    IF lv_idt IS INITIAL. lv_idt = c_default_idtype. ENDIF.
    SELECT SINGLE a~partner, a~zzfull_name_eng
      FROM but000 AS a LEFT JOIN but0id AS b ON b~partner = a~partner AND b~type = @lv_idt
      WHERE b~idnumber = @lv_term OR a~partner = @lv_term INTO @DATA(ls_bp).
    IF sy-subrc <> 0.
      io_ctx->add_msg( iv_type = 'Error' iv_text = |Nothing found for { lv_term }| ).
      RETURN.
    ENDIF.
    io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-partner }| ).
    io_ctx->set_val( iv_name = |{ c_owner_bp }_NAME| iv_value = |{ ls_bp-zzfull_name_eng }| ).
  ENDMETHOD.
ENDCLASS.
