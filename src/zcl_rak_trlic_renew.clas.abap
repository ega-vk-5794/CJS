CLASS zcl_rak_trlic_renew DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ---- handler-owned events (io_ctx->event) --------------------------
    CONSTANTS c_owner_add TYPE string VALUE 'OWNER_ADD'.   " open the popup
    CONSTANTS c_owner_ok  TYPE string VALUE 'OWNER_OK'.    " popup Save
    CONSTANTS c_owner_del TYPE string VALUE 'OWNER_DEL'.   " remove selected row

    " ---- handler-owned popup id ----------------------------------------
    CONSTANTS c_pop_owner TYPE string VALUE 'OWNER'.

    " ---- scratch model fields (all HIDDEN in config) --------------------
    CONSTANTS c_blob TYPE string VALUE 'OWNERS_BLOB'.
    CONSTANTS c_sel  TYPE string VALUE 'OWNERS_SEL'.

    METHODS zif_rak_journey_logic~on_init             REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read       REDEFINITION.
    METHODS zif_rak_journey_logic~on_change           REDEFINITION.
    METHODS zif_rak_journey_logic~on_attach           REDEFINITION.
    METHODS zif_rak_journey_logic~on_fee_calc         REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help       REDEFINITION.
    METHODS zif_rak_journey_logic~get_table           REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate  REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_start     REDEFINITION.
    METHODS zif_rak_journey_logic~render_field        REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_popup     REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event      REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post      REDEFINITION.
    METHODS zif_rak_journey_logic~on_save             REDEFINITION.

  PROTECTED SECTION.
    METHODS prepare_payment REDEFINITION.

  PRIVATE SECTION.
    " Owners live in ONE hidden string field, because the handler is
    " re-instantiated on every round-trip. Rows are '|'-separated,
    " columns '~'-separated. Never put the blob in ct_kv.
    TYPES: BEGIN OF ty_owner,
             name  TYPE string,
             share TYPE string,
           END OF ty_owner,
           tt_owner TYPE STANDARD TABLE OF ty_owner WITH EMPTY KEY.

    CONSTANTS c_rowsep TYPE c LENGTH 1 VALUE '|'.
    CONSTANTS c_colsep TYPE c LENGTH 1 VALUE '~'.

    METHODS blob_read
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE tt_owner.
    METHODS blob_write
      IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                it_owner TYPE tt_owner.
    METHODS calc_fee
      IMPORTING iv_area   TYPE string
                iv_act    TYPE string
      RETURNING VALUE(rv) TYPE string.
    METHODS to_num
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE decfloat34.
    METHODS owners_step
      IMPORTING io_ctx         TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv_step) TYPE i.
ENDCLASS.



CLASS ZCL_RAK_TRLIC_RENEW IMPLEMENTATION.


  METHOD blob_read.
    DATA(lv_blob) = io_ctx->get_val( c_blob ).
    CHECK lv_blob IS NOT INITIAL.

    SPLIT lv_blob AT c_rowsep INTO TABLE DATA(lt_row).
    LOOP AT lt_row INTO DATA(lv_row).
      IF lv_row IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT lv_row AT c_colsep INTO DATA(lv_n) DATA(lv_s).
      IF lv_n IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = lv_n share = lv_s ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD blob_write.
    DATA lv_blob TYPE string.
    LOOP AT it_owner INTO DATA(ls).
      DATA(lv_row) = |{ ls-name }{ c_colsep }{ ls-share }|.
      lv_blob = COND #( WHEN lv_blob IS INITIAL
                        THEN lv_row
                        ELSE |{ lv_blob }{ c_rowsep }{ lv_row }| ).
    ENDLOOP.
    io_ctx->set_val( iv_name = c_blob iv_value = lv_blob ).
  ENDMETHOD.


  METHOD calc_fee.
    DATA(lv_area) = to_num( iv_area ).
    DATA lv_fee TYPE decfloat34 VALUE 1500.

    IF lv_area > 0.
      lv_fee = lv_fee + lv_area * '12.50'.
    ENDIF.

    CASE iv_act.
      WHEN 'FOOD'. lv_fee = lv_fee + 2000.
      WHEN 'IND'.  lv_fee = lv_fee + 3500.
      WHEN OTHERS.
    ENDCASE.

    rv = |{ lv_fee DECIMALS = 2 }|.
  ENDMETHOD.


  METHOD owners_step.
    rv_step = -1.
    DATA lv_ix TYPE i.
    DATA(ls_cfg) = io_ctx->get_config( ).
    LOOP AT ls_cfg-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF to_upper( ls_f-name ) = 'OWNERS'.
          rv_step = lv_ix.
          RETURN.
        ENDIF.
      ENDLOOP.
      lv_ix = lv_ix + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD prepare_payment.
    DATA ls_method TYPE zcl_rak_pay_engine=>ty_method.
    pay_engine( io_ctx )->persist_method( ls_method ).

    DATA lt_def TYPE /qnv/sbuild_definition_tt.
    lt_def = VALUE #( ( technicalname = 'REFERENCEID' )
                      ( technicalname = 'APPLICATIONURL' ) ).

    NEW zcl_rak_cpg_adapter( )->fill(
      EXPORTING
        case_key      = CONV #( io_ctx->get_case( ) )
        etisalat      = abap_true
      CHANGING
        ct_definition = lt_def ).

    io_ctx->set_val( iv_name  = 'PAY_REFERENCE'
                     iv_value = VALUE #( lt_def[ technicalname = 'REFERENCEID' ]-value OPTIONAL ) ).
    io_ctx->set_val( iv_name  = 'PAY_APPURL'
                     iv_value = VALUE #( lt_def[ technicalname = 'APPLICATIONURL' ]-value OPTIONAL ) ).
  ENDMETHOD.


  METHOD to_num.
    TRY.
        rv = CONV decfloat34( condense( iv ) ).
      CATCH cx_sy_conversion_no_number.
        CLEAR rv.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
    CHECK iv_name = 'OWNERS'.

    rs_data-columns = VALUE #( ( `Owner` ) ( `Share %` ) ).

    DATA(lt_own) = blob_read( io_ctx ).
    LOOP AT lt_own INTO DATA(ls_own).
      APPEND VALUE #( ( ls_own-name ) ( ls_own-share ) ) TO rs_data-rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
    DATA(lv_case) = io_ctx->get_case( ).
    CHECK lv_case IS NOT INITIAL.

    IF io_ctx->get_val( 'LICENSE_NO' ) IS INITIAL.
      io_ctx->set_val( iv_name = 'LICENSE_NO' iv_value = io_ctx->get_param( 'caseid' ) ).
    ENDIF.

    DATA(lv_bp) = condense( io_ctx->get_param( 'loginbp' ) ).
    IF lv_bp IS NOT INITIAL AND io_ctx->get_val( 'OWNER_NAME' ) IS INITIAL.
      DATA(lv_partner) = CONV bu_partner( lv_bp ).
      SELECT SINGLE zzfull_name_eng
        FROM but000
        WHERE partner = @lv_partner
        INTO @DATA(lv_name).
      IF sy-subrc = 0 AND lv_name IS NOT INITIAL.
        io_ctx->set_val( iv_name = 'OWNER_NAME' iv_value = CONV #( lv_name ) ).
      ENDIF.
    ENDIF.

    io_ctx->set_val( iv_name  = 'EST_FEE'
                     iv_value = calc_fee( iv_area = io_ctx->get_val( 'AREA_SQM' )
                                          iv_act  = io_ctx->get_val( 'ACTIVITY' ) ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_attach.
    CHECK to_upper( iv_field ) = 'TRADE_CERT'.
    io_ctx->set_val( iv_name = 'ATT_STATUS' iv_value = 'Certificate attached' ).
    io_ctx->add_msg( iv_type = 'Success'
                     iv_text = 'Trade certificate received. It is staged and will be filed on submit.' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    super->zif_rak_journey_logic~on_before_post( EXPORTING io_ctx = io_ctx
                                                 CHANGING  ct_kv  = ct_kv ).

    DATA(lt_own) = blob_read( io_ctx ).
    IF lt_own IS NOT INITIAL.
      DATA(lv_flat) = REDUCE string(
        INIT s = ``
        FOR ls IN lt_own
        NEXT s = COND #( WHEN s IS INITIAL
                         THEN |{ ls-name }={ ls-share }|
                         ELSE |{ s };{ ls-name }={ ls-share }| ) ).
      READ TABLE ct_kv ASSIGNING FIELD-SYMBOL(<kv>) WITH KEY key = 'OWNERS_SUMMARY'.
      IF sy-subrc = 0.
        <kv>-value = lv_flat.
      ENDIF.
    ENDIF.

    DELETE ct_kv WHERE key = c_blob.
    DELETE ct_kv WHERE key = c_sel.
    DELETE ct_kv WHERE key CP 'POP_*'.
    DELETE ct_kv WHERE key = 'EST_FEE'.
    DELETE ct_kv WHERE key = 'ATT_STATUS'.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE iv_field.
      WHEN 'AREA_SQM' OR 'ACTIVITY'.
        io_ctx->set_val( iv_name = 'EST_FEE'
                         iv_value = calc_fee( iv_area = io_ctx->get_val( 'AREA_SQM' )
                                              iv_act  = io_ctx->get_val( 'ACTIVITY' ) ) ).

      WHEN 'PREMISE_TYPE'.
        IF io_ctx->get_val( 'PREMISE_TYPE' ) = 'VIRTUAL'.
          io_ctx->set_val( iv_name = 'AREA_SQM' iv_value = '' ).
          io_ctx->set_val( iv_name = 'EST_FEE'
                           iv_value = calc_fee( iv_area = ''
                                                iv_act  = io_ctx->get_val( 'ACTIVITY' ) ) ).
        ENDIF.

      WHEN c_sel.
        DATA(lv_pick) = io_ctx->get_val( c_sel ).
        IF lv_pick IS NOT INITIAL.
          io_ctx->add_msg( iv_type = 'Information'
                           iv_text = |Owner { lv_pick } selected| ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).

    IF iv_step = 0.
      DATA(lv_mob) = condense( io_ctx->get_val( 'MOBILE' ) ).
      IF lv_mob IS NOT INITIAL AND lv_mob NP '+9715++++++++'.
        APPEND VALUE #( type = 'Error'
                        text = 'Enter a valid UAE mobile number, e.g. +971501234567.' ) TO rt.
      ENDIF.
    ENDIF.

    IF iv_step = owners_step( io_ctx ).
      DATA(lt_own) = blob_read( io_ctx ).
      IF lt_own IS INITIAL.
        APPEND VALUE #( type = 'Error'
                        text = 'At least one owner is required.' ) TO rt.
      ELSE.
        DATA lv_tot TYPE decfloat34.
        LOOP AT lt_own INTO DATA(ls_own).
          lv_tot = lv_tot + to_num( ls_own-share ).
        ENDLOOP.
        IF lv_tot <> 100.
          APPEND VALUE #( type = 'Error'
                          text = |Owner shares total { lv_tot } %. They must total exactly 100 %.| ) TO rt.
        ENDIF.
      ENDIF.

      IF io_ctx->get_val( 'PREMISE_TYPE' ) <> 'VIRTUAL'
         AND to_num( io_ctx->get_val( 'AREA_SQM' ) ) <= 0.
        APPEND VALUE #( type = 'Error'
                        text = 'Premise area is required for a physical premise.' ) TO rt.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_fee_calc.
    CHECK io_ctx->get_val( 'EST_FEE' ) IS INITIAL.
    io_ctx->set_val( iv_name = 'EST_FEE'
                     iv_value = calc_fee( iv_area = io_ctx->get_val( 'AREA_SQM' )
                                          iv_act  = io_ctx->get_val( 'ACTIVITY' ) ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    IF io_ctx->get_val( 'PREMISE_TYPE' ) IS INITIAL.
      io_ctx->set_val( iv_name = 'PREMISE_TYPE' iv_value = 'PHYSICAL' ).
    ENDIF.
    io_ctx->set_val( iv_name = 'ATT_STATUS' iv_value = 'No certificate attached yet' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
    super->zif_rak_journey_logic~on_popup_event(
      io_ctx   = io_ctx
      iv_id    = iv_id
      iv_event = iv_event ).

    CASE iv_event.
      WHEN c_owner_add.
        io_ctx->set_val( iv_name = 'POP_NAME'  iv_value = '' ).
        io_ctx->set_val( iv_name = 'POP_SHARE' iv_value = '' ).
        io_ctx->open_popup( c_pop_owner ).

      WHEN c_owner_ok.
        DATA(lv_nm) = condense( io_ctx->get_val( 'POP_NAME' ) ).
        DATA(lv_sh) = condense( io_ctx->get_val( 'POP_SHARE' ) ).

        IF lv_nm IS INITIAL OR lv_sh IS INITIAL.
          io_ctx->add_msg( iv_type = 'Error' iv_text = 'Both name and share are required.' ).
          RETURN.
        ENDIF.
        IF lv_nm CS c_rowsep OR lv_nm CS c_colsep.
          io_ctx->add_msg( iv_type = 'Error'
                           iv_text = |Owner name must not contain { c_rowsep } or { c_colsep }.| ).
          RETURN.
        ENDIF.
        IF to_num( lv_sh ) <= 0.
          io_ctx->add_msg( iv_type = 'Error' iv_text = 'Share must be a positive number.' ).
          RETURN.
        ENDIF.

        DATA(lt_own) = blob_read( io_ctx ).
        IF line_exists( lt_own[ name = lv_nm ] ).
          io_ctx->add_msg( iv_type = 'Warning' iv_text = |{ lv_nm } is already an owner.| ).
          RETURN.
        ENDIF.

        APPEND VALUE #( name = lv_nm share = lv_sh ) TO lt_own.
        blob_write( io_ctx = io_ctx it_owner = lt_own ).
        io_ctx->set_val( iv_name = 'POP_NAME'  iv_value = '' ).
        io_ctx->set_val( iv_name = 'POP_SHARE' iv_value = '' ).
        io_ctx->close_popup( ).

      WHEN c_owner_del.
        DATA(lv_pick) = io_ctx->get_val( c_sel ).
        CHECK lv_pick IS NOT INITIAL.
        DATA(lt_del) = blob_read( io_ctx ).
        DELETE lt_del WHERE name = lv_pick.
        blob_write( io_ctx = io_ctx it_owner = lt_del ).
        io_ctx->set_val( iv_name = c_sel iv_value = '' ).
        io_ctx->add_msg( iv_type = 'Success' iv_text = |{ lv_pick } removed| ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    CHECK iv_id = c_pop_owner.

    dialog_form(
      io_ctx     = io_ctx
      io_popup   = io_popup
      iv_title   = 'Add owner'
      it_fields  = VALUE #( ( name = 'POP_NAME'  label = 'Owner name' )
                            ( name = 'POP_SHARE' label = 'Share %' ) )
      iv_ok_text = 'Add'
      iv_ok_evt  = c_owner_ok ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
    super->zif_rak_journey_logic~on_render_start( io_ctx = io_ctx io_view = io_view ).

    CHECK io_ctx->get_step( ) = owners_step( io_ctx ).

    DATA(lo_bar) = io_view->hbox( alignitems = 'Center'
                                  class      = 'sapUiSmallMarginBegin sapUiTinyMarginTop' ).
    lo_bar->button( text  = 'Add owner'
                    icon  = 'sap-icon://add-employee'
                    type  = 'Emphasized'
                    press = io_ctx->event( c_owner_add ) ).

    IF io_ctx->get_val( c_sel ) IS NOT INITIAL.
      lo_bar->button( text  = 'Remove selected'
                      icon  = 'sap-icon://delete'
                      type  = 'Reject'
                      class = 'sapUiTinyMarginBegin'
                      press = io_ctx->event( c_owner_del ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_save.
    io_ctx->add_msg( iv_type = 'Information'
                     iv_text = 'Owners and attachments are kept with the draft.' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
    CHECK iv_field = 'ACTIVITY'.
    rt = VALUE #( ( key = 'FOOD'   text = 'Food & Beverage' )
                  ( key = 'RETAIL' text = 'Retail Trade' )
                  ( key = 'PROF'   text = 'Professional Services' )
                  ( key = 'IND'    text = 'Light Industrial' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
    rv_done = super->zif_rak_journey_logic~render_field(
      io_ctx   = io_ctx
      io_form  = io_form
      is_field = is_field ).
    CHECK rv_done = abap_false.
    CHECK to_upper( is_field-name ) = 'EST_FEE'.

    io_form->label( is_field-label ).
    io_form->object_number( number     = io_ctx->bind( 'EST_FEE' )
                            numberunit = 'AED'
                            emphasized = abap_true
                            state      = 'Information' ).
    rv_done = abap_true.
  ENDMETHOD.
ENDCLASS.
