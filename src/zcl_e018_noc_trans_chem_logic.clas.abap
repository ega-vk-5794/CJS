class ZCL_E018_NOC_TRANS_CHEM_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
protected section.
private section.

  data CLIENT type ref to Z2UI5_IF_CLIENT .
  constants C_ROLE type STRING value 'APPLICANT_ROLE' ##NO_TEXT.
  constants C_PERMIT type STRING value 'PERMIT_HELD' ##NO_TEXT.
  constants C_GRID type STRING value 'CHEMICALS_DETAILS' ##NO_TEXT.
  constants C_EVT_DETAILS type STRING value 'ADD Details' ##NO_TEXT.
  constants C_HS_CODE_POP type STRING value 'HS_CODE_POP' ##NO_TEXT.
  constants C_MATERIAL_NAME_POP type STRING value 'MATERIAL_NAME_HF' ##NO_TEXT.
  constants C_CHEMICAL_NAME_POP type STRING value 'CHEMICAL_NAME_HF' ##NO_TEXT.
  constants C_CAS_POP type STRING value 'CAS_POP' ##NO_TEXT.
  constants C_CHEMICAL_FORMULA_POP type STRING value 'CHEMICAL_FORMULA_POP' ##NO_TEXT.
  constants C_PACKAGING_POP type STRING value 'PACKAGING_POP' ##NO_TEXT.
  constants C_QUANTITY_POP type STRING value 'QUANTITY_POP' ##NO_TEXT.
  constants C_GROSS_WEIGHT_POP type STRING value 'GROSS_WEIGHT_POP' ##NO_TEXT.
  constants C_UOM_POP type STRING value 'UOM_POP' ##NO_TEXT.
  constants C_INVOICE_POP type STRING value 'INVOICE_POP' ##NO_TEXT.
  constants C_ORIGIN_POP type STRING value 'ORIGIN_POP' ##NO_TEXT.
  constants C_END_USER_POP type STRING value 'END_USER_POP' ##NO_TEXT.
  constants C_BOL_POP type STRING value 'BOL_POP' ##NO_TEXT.
  constants C_TRANS_COMP type STRING value 'TRANS_COMP' ##NO_TEXT.
  constants C_CHEM type STRING value 'CHEM' ##NO_TEXT.
  constants C_OPEN_POPUP type STRING value 'CHEMICAL_POP' ##NO_TEXT.
  constants C_EVT_OWNOK type STRING value 'OWN_OK' ##NO_TEXT.
  constants C_EVT_OWNCX type STRING value 'OWN_CANCEL' ##NO_TEXT.
  constants C_OWN_ADD type STRING value 'OWNER_ADD' ##NO_TEXT.
  constants C_EDIT_POP type STRING value 'OWN_EDIT_*' ##NO_TEXT.
  constants C_DELETE_POP type STRING value 'OWN_DEL_*' ##NO_TEXT.
  constants C_EVT_OWNSR type STRING value 'OWN_SEARCH' ##NO_TEXT.
* The previous-declarations picker and the event its selection raises. The
* legacy CHEMICALS_DETAILS control offered the applicant their earlier
* declarations from ChemicalHistorySet; this handler rebuilt the dialog and
* not the lookup. See HISTORY_OPTS( ).
  constants C_HIST_POP type STRING value 'CHEM_HIST_POP' ##NO_TEXT.
  constants C_EVT_HIST type STRING value 'CHEM_HIST_PICK' ##NO_TEXT.
* IV_IMP_EXP_TYPE, deliberately blank - and now for a settled reason rather
* than an unknown one. Domain ZDO_EPDA_CHEM_IMP_EXP has exactly two fixed
* values, 1 Import and 2 Export. There is NO transit code, so E018 sends
* none and sees the applicant's whole history. That is the domain's answer;
* inventing a third value would return nothing, which looks exactly like an
* applicant who has never declared anything.
* VALUE IS INITIAL, never VALUE ''. A string constant does not take an
* empty literal: the class then has NO ACTIVE VERSION, the runtime keeps
* running the previous one, and the error surfaces at every caller as
* "Method X is unknown or PROTECTED or PRIVATE" - nowhere near here. That
* is why the OWN_EDIT( ) and OWN_FORM_SAVE( ) fixes already in git never
* reached the tested screen.
  constants C_IMPEXP type STRING value IS INITIAL ##NO_TEXT.

*  CONSTANTS c_hs_pop TYPE string VALUE 'HS_CODE' ##NO_TEXT.
**  c_edit_pop
*  c_DELETE_POP
*  methods RENDER_CHEM_DETAILS
*    importing
*      !IO_CTX type ref to ZIF_RAK_JOURNEY
*      !IO_VIEW type ref to Z2UI5_CL_XML_VIEW .
*  methods CHEM_FORM_LOAD
*    importing
*      !IO_CTX type ref to ZIF_RAK_JOURNEY
*      !IV_ID type STRING optional .
*  methods RENDER_OWN_POPUP
*    importing
*      !IO_CTX type ref to ZIF_RAK_JOURNEY
*      !IO_POPUP type ref to Z2UI5_CL_XML_VIEW .
  methods WRITE_FLAGS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods COMPANY_FIELDS
    returning
      value(RT) type ZIF_RAK_JOURNEY=>TT_STRING .
  methods CHEM_FORM_LOAD
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
  methods RENDER_CHEM_DETAILS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_VIEW type ref to Z2UI5_CL_XML_VIEW .
  methods RENDER_OWN_POPUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_POPUP type ref to Z2UI5_CL_XML_VIEW .
  methods HISTORY_REQ
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
    returning
      value(RS) type ZCL_RAK_CHEM_API=>TY_REQ .
  methods HISTORY_OPTS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
    returning
      value(RT) type ZIF_RAK_JOURNEY=>TT_OPTION .
  methods HISTORY_APPLY
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods OWN_FORM_SAVE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods OWN_EDIT
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
  methods OWN_DELETE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING .
  methods OWN_SEARCH
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
ENDCLASS.



CLASS ZCL_E018_NOC_TRANS_CHEM_LOGIC IMPLEMENTATION.


  METHOD history_req.
    rs-permit  = io_ctx->get_val( c_permit ).
    rs-licence = io_ctx->get_val( `CO_TRADE_LICENSE` ).
    rs-emirate = io_ctx->get_val( `CO_REG_EMIRATES` ).
    rs-impexp  = c_impexp.
  ENDMETHOD.


  METHOD history_opts.
*   Failure is a Warning and an empty list, never an exception: Add Chemical
*   must still open and still work by hand if the history service is down.
    TRY.
        DATA(lo_api) = NEW zcl_rak_chem_api( ).
        DATA(ls_res) = lo_api->history( history_req( io_ctx ) ).
        IF ls_res-msg IS NOT INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Previous declarations unavailable: | &&
                                     |{ VALUE #( ls_res-msg[ 1 ]-message OPTIONAL ) }| ).
          RETURN.
        ENDIF.
        rt = lo_api->as_options( ls_res-rows ).
      CATCH cx_root INTO DATA(lx).
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Previous declarations unavailable: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD history_apply.
*   Matched by NAME against whatever components TS_CHEMICALHISTORY actually
*   has - see ZCL_RAK_CHEM_API. Anything unmatched is named in a Warning
*   rather than left quietly blank.
    DATA(lv_key) = io_ctx->get_val( c_hist_pop ).
    IF lv_key IS INITIAL.
      RETURN.
    ENDIF.

*   TT_MAP is declared, not written inline on the VALUE below. VALUE takes a
*   TYPE NAME - 'VALUE STANDARD TABLE OF ty_map WITH EMPTY KEY( ... )' is not
*   a constructor expression at all, and the Class Builder reports it as
*   'Field "VALUE" is unknown', naming the operator rather than the mistake.
    TYPES: BEGIN OF ty_map,
             field TYPE string,
             cands TYPE string,
           END OF ty_map,
           tt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

*   EXACT NAMES NOW - CHEMINAL_NAME is the source's own misspelling, not a
*   slip here, and CAS_NO carries the underscore.
    DATA(lt_map) = VALUE tt_map(
      ( field = c_hs_code_pop          cands = `HS_CODE` )
      ( field = c_material_name_pop    cands = `MATERIAL_NAME` )
      ( field = c_chemical_name_pop    cands = `CHEMINAL_NAME` )
      ( field = c_cas_pop              cands = `CAS_NO` )
      ( field = c_chemical_formula_pop cands = `CHEMICAL_FORMULA` )
      ( field = c_packaging_pop        cands = `PACKAGING` )
      ( field = c_uom_pop              cands = `UNIT` )
      ( field = c_origin_pop           cands = `COUNTRY_ORIGIN` )
      ( field = c_end_user_pop         cands = `POINT_OF_ENTRANCE` )
*     E018 is the transit journey, so the carrier is part of the route the
*     substance takes and the history is the right source for it.
      ( field = c_trans_comp           cands = `TRANSPORT_COMPANY` ) ).

    DATA lv_miss TYPE string.

    TRY.
        DATA(lo_api) = NEW zcl_rak_chem_api( ).
        DATA(ls_res) = lo_api->history( history_req( io_ctx ) ).
        DATA(lt_val) = lo_api->row_values( it_rows = ls_res-rows iv_key = lv_key ).
        IF lt_val IS INITIAL.
          RETURN.
        ENDIF.

        LOOP AT lt_map INTO DATA(ls_map).
          SPLIT ls_map-cands AT '|' INTO TABLE DATA(lt_cand).
          DATA lv_hit TYPE abap_bool.
          CLEAR lv_hit.
          LOOP AT lt_cand INTO DATA(lv_cand).
            READ TABLE lt_val INTO DATA(ls_val) WITH KEY name = to_upper( lv_cand ).
            IF sy-subrc = 0 AND ls_val-value IS NOT INITIAL.
              io_ctx->set_val( iv_name = ls_map-field iv_value = ls_val-value ).
              lv_hit = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.
          IF lv_hit = abap_false.
            lv_miss = COND string( WHEN lv_miss IS INITIAL THEN ls_map-field
                                   ELSE |{ lv_miss }, { ls_map-field }| ).
          ENDIF.
        ENDLOOP.

*       QUANTITY, GROSS WEIGHT, INVOICE and BILL OF LADING are deliberately
*       not prefilled - they belong to this shipment, not to the substance.
        IF lv_miss IS NOT INITIAL.
          io_ctx->add_msg(
            iv_type = 'Warning'
            iv_text = |Previous declaration loaded; these could not be matched | &&
                      |and need filling by hand: { lv_miss }| ).
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Could not load that declaration: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD chem_form_load.
    io_ctx->set_val( iv_name = c_hist_pop             iv_value = '' ).
    io_ctx->set_val( iv_name = c_hs_code_pop          iv_value = '' ).
    io_ctx->set_val( iv_name = c_material_name_pop    iv_value = '' ).
    io_ctx->set_val( iv_name = c_chemical_name_pop    iv_value = '' ).
    io_ctx->set_val( iv_name = c_cas_pop              iv_value = '' ).
    io_ctx->set_val( iv_name = c_chemical_formula_pop iv_value = '' ).
    io_ctx->set_val( iv_name = c_packaging_pop        iv_value = '' ).
    io_ctx->set_val( iv_name = c_quantity_pop         iv_value = '' ).
    io_ctx->set_val( iv_name = c_gross_weight_pop     iv_value = '' ).
    io_ctx->set_val( iv_name = c_uom_pop              iv_value = '' ).
    io_ctx->set_val( iv_name = c_invoice_pop          iv_value = '' ).
    io_ctx->set_val( iv_name = c_origin_pop           iv_value = '' ).
    io_ctx->set_val( iv_name = c_end_user_pop         iv_value = '' ).
    io_ctx->set_val( iv_name = c_bol_pop              iv_value = '' ).
    io_ctx->set_val( iv_name = c_trans_comp           iv_value = '' ).
  ENDMETHOD.


  METHOD company_fields.
    rt = VALUE #(
      ( `COMPANY_NAME_EN` ) ( `COMPANY_NAME_AR` ) ( `CO_REG_EMIRATES` )
      ( `CO_ADDRESS` )      ( `CO_TRADE_LICENSE` ) ( `CO_MOBILE` )
      ( `CO_TELEPHONE` )    ( `CO_EMAIL` ) ).
  ENDMETHOD.


  METHOD render_chem_details.

*    DATA(ls_chem) = io_ctx->get_grid_data( 'CHEMICALS_DETAILS' ).
*    DATA(ls_chem1) = io_ctx->get_backend_table( 'CHEMICALS_DETAILS' ).
*
*    DATA(lv_hs_code) = io_ctx->get_val( iv_name = c_hs_code_pop ).




    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    DATA(lo_hd) = io_view->hbox( justifycontent = 'SpaceBetween'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
    lo_hd->title( text = 'Chemical Details' class = 'rakBlkTitle' ).
    lo_hd->button( text  = 'Add Details'
                   type  = 'Emphasized'
                   icon  = 'sap-icon://add'
                   press = io_ctx->event( c_evt_details ) ).

    DATA(lo_t)  = io_view->table( alternaterowcolors = abap_true ).
    DATA(lo_cl) = lo_t->columns( ).
    lo_cl->column( )->text( 'HS Code' ).
    lo_cl->column( )->text( 'Material name' ).
    lo_cl->column( )->text( 'Chemical Name' ).
    lo_cl->column( )->text( 'CAS Number' ).
    lo_cl->column( )->text( 'Gross Weight' ).
    lo_cl->column( halign = 'End' )->text( '' ).


*-----Added
*    DATA lt_seen_hs TYPE HASHED TABLE OF string
*                    WITH UNIQUE KEY table_line.
*    DATA lt_final_rows LIKE ls_g-rows.
*
*    LOOP AT ls_g-rows INTO DATA(lt_r). "STEP -1.
*
*      DATA(lv_hs_no) = VALUE string( lt_r[ 1 ] OPTIONAL ).
*
*      IF lv_hs_no IS INITIAL.
*        CONTINUE.
*      ENDIF.
*
*      "Already found this HS code in a newer row
*      IF line_exists( lt_seen_hs[ table_line = lv_hs_no ] ).
*        CONTINUE.
*      ENDIF.
*
*      "Remember HS code
*      INSERT lv_hs_no INTO TABLE lt_seen_hs.
*
*      "Keep the latest row
*      INSERT lt_r INTO lt_final_rows INDEX 1.
*
*    ENDLOOP.
*
*    LOOP AT lt_final_rows INTO DATA(lt_r1).
*
*      DATA(lv_hs_no1) = VALUE string( lt_r1[ 1 ] OPTIONAL ).
*      DATA(lv_mat)   = VALUE string( lt_r1[ 2 ] OPTIONAL ).
*      DATA(lv_chem)  = VALUE string( lt_r1[ 3 ] OPTIONAL ).
*      DATA(lv_cas)   = VALUE string( lt_r1[ 4 ] OPTIONAL ).
*      DATA(lv_w8t)   = VALUE string( lt_r1[ 8 ] OPTIONAL ).
*
*      DATA(lo_cells) = lo_t->column_list_item( )->cells( ).
*
*      DATA(lo_nm) = lo_cells->vbox( ).
*
*      lo_nm->text( text = lv_hs_no1 ).
*      lo_cells->text( lv_mat ).
*      lo_cells->text( lv_chem ).
*      lo_cells->text( lv_cas ).
*      lo_cells->text( lv_w8t ).
*
*      DATA(lo_act) = lo_cells->hbox( ).
*      lo_act->button( icon    = 'sap-icon://edit'
*                      type    = 'Transparent'
*                      tooltip = 'Edit details'
*                      press   = io_ctx->event( |OWN_EDIT_{ lv_hs_no }| ) ).
*      lo_act->button( icon    = 'sap-icon://delete'
*                      type    = 'Transparent'
*                      tooltip = 'Delete'
*                      press   = io_ctx->event( |OWN_DEL_{ lv_hs_no }| ) ).
*
*    ENDLOOP.







    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).

      DATA(lv_hs_no) = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_mat)   = VALUE string( lt_r[ 2 ] OPTIONAL ).
      DATA(Lv_chem)  = VALUE string( lt_r[ 3 ] OPTIONAL ).
      DATA(lv_cas)   = VALUE string( lt_r[ 4 ] OPTIONAL ).
      DATA(lv_w8t)   = VALUE string( lt_r[ 8 ] OPTIONAL ).



      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_hs_no ).
      lo_cells->text( lv_mat ).
      lo_cells->text( lv_chem ).
      lo_cells->text( lv_cas ).
      lo_cells->text( lv_w8t ).

      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = 'Edit details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_hs_no }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_hs_no }| ) ).
    ENDLOOP.


  ENDMETHOD.


  METHOD render_own_popup.

    DATA(lo_dlg) = io_popup->dialog( title = 'Chemical/Material Details' contentwidth = '55rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*   Search sits ON the section title, not under the Emirates ID field, because
*   it acts on the whole form: type the ID, press Search, and the rest fills in.
    DATA(lo_hdr) = lo_c->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    lo_hdr->title( text = 'Owner Details' class = 'rakBlkTitle' ).
    lo_hdr->button( text  = 'Search'
                    type  = 'Emphasized'
                    icon  = 'sap-icon://search'
                    press = io_ctx->event( c_evt_ownsr ) ).

*   Two per row, the way the legacy dialog laid it out.
    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' )."ROw 1
    DATA(lo_c1) = lo_r1->vbox( class = 'rakCell' ).
    lo_c1->label( text = 'HS Code' required = abap_true ).
    lo_c1->input( value = io_ctx->bind( c_hs_code_pop ) width = '17rem' ).

    DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).
    lo_c2->label( text = 'Material Name' ).
    lo_c2->input( value = io_ctx->bind( c_material_name_pop ) width = '17rem' ).

    DATA(lo_c3) = lo_r1->vbox( class = 'rakCell' ).
    lo_c3->label( text = 'Chemical Name' ).
    lo_c3->input( value = io_ctx->bind( c_chemical_name_pop ) width = '17rem' ).

*&--------Row 2-----------&
    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).

    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
    lo_c4->label( text = 'CAS Number' ).
    lo_c4->input( value = io_ctx->bind( c_cas_pop ) width = '17rem' ).

    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
    lo_c5->label( text = 'Chemical formula' ).
    lo_c5->input( value = io_ctx->bind( c_chemical_formula_pop ) width = '17rem' ).

    DATA(lo_c6) = lo_r2->vbox( class = 'rakCell' ).
    lo_c6->label( text = 'Packing' required = abap_true ).
    lo_c6->input( value = io_ctx->bind( c_packaging_pop ) width = '17rem' ).

    DATA(lo_c7) = lo_r2->vbox( class = 'rakCell' ).
    lo_c7->label( text = 'Quantity' required = abap_true ).
    lo_c7->input( value = io_ctx->bind( c_quantity_pop ) type = 'Number' width = '17rem' ).

    DATA(lo_c8) = lo_r2->vbox( class = 'rakCell' ).
    lo_c8->label( text = 'Gross Weight' required = abap_true ).
    lo_c8->input( value = io_ctx->bind( c_gross_weight_pop ) type = 'Number' width = '17rem' ).

    DATA(lo_c9) = lo_r2->vbox( class = 'rakCell' ).
*    DATA(lo_u) = lo_c9->select( selectedkey = io_ctx->bind( c_uom_pop ) )->items( ).
*    lo_u->item( key = 'KG' text = 'Kilogram'
*                key = 'EA' text = 'Each').
    lo_c9->label( text = 'UOM' required = abap_true ).
    lo_c9->input( value = io_ctx->bind( c_uom_pop ) width = '17rem' ).


    DATA(lo_c10) = lo_r2->vbox( class = 'rakCell' ).
    lo_c10->label( text = 'Invoice Number' required = abap_true ).
    lo_c10->input( value = io_ctx->bind( c_invoice_pop ) width = '17rem' ).


    DATA(lo_c11) = lo_r2->vbox( class = 'rakCell' ).
    lo_c11->label( text = 'Country of Origin' required = abap_true ).
    lo_c11->input( value = io_ctx->bind( c_origin_pop )
                   width = '17rem'
                   placeholder = 'IN'
                   submit      = io_ctx->event( c_evt_ownsr ) ).

    DATA(lo_c12) = lo_r2->vbox( class = 'rakCell' ).
    lo_c12->label( text = 'Point of Entrance/End User' required = abap_true ).
    lo_c12->input( value = io_ctx->bind( c_end_user_pop ) width = '17rem' ).


    DATA(lo_c13) = lo_r2->vbox( class = 'rakCell' ).
    lo_c13->label( text = 'Bill of Lading' required = abap_true ).
    lo_c13->input( value = io_ctx->bind( c_bol_pop ) width = '17rem' ).


    DATA(lo_c14) = lo_r2->vbox( class = 'rakCell' ).
    lo_c14->label( text = 'Transport Company' required = abap_true ).
    lo_c14->input( value = io_ctx->bind( c_trans_comp ) width = '17rem' ).





***    DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).
***    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
*****    lo_c2->label( text = 'HS Code' class = 'rakReq' ).
****   Enter in the ID box does the same as pressing Search. Somebody who has just
****   typed fifteen digits should not have to reach for the mouse.
*****    lo_c2->input( value       = io_ctx->bind( c_own_eid )
*****                  width       = '17rem'
*****                  placeholder = '784-xxxx-xxxxxxx-x'
*****                  submit      = io_ctx->event( c_evt_ownsr ) ).
***
***
***    DATA(lo_c3) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c3->label( text = 'Material Name' ).
***    lo_c3->input( value = io_ctx->bind( 'C_MATERIAL_NAME_POP' ) width = '17rem' ).
***    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c4->label( text = 'Chemical Name' ).
***    lo_c4->input( value = io_ctx->bind( 'C_CHEMICAL_NAME_POP' ) width = '17rem' ).
***    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c5->label( text = 'CAS Number' ).
***    lo_c5->input( value = io_ctx->bind( 'C_CAS_POP' ) width = '17rem' ).
***    DATA(lo_c6) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c6->label( text = 'Chemical formula' ).
***    lo_c6->input( value = io_ctx->bind( c_chemical_formula_pop ) width = '17rem' ).
***    DATA(lo_c7) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c7->label( text = 'Packing' class = 'rakReq' ).
***    lo_c7->input( value = io_ctx->bind( c_packaging_pop ) type = 'Number' width = '17rem' ).
***    DATA(lo_c8) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c8->label( text = 'Quantity' class = 'rakReq' ).
***    lo_c8->input( value = io_ctx->bind( c_quantity_pop ) type = 'Number' width = '17rem' ).
***    DATA(lo_c9) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c9->label( text = 'Gross Weight' class = 'rakReq' ).
***    lo_c9->input( value = io_ctx->bind( c_gross_weight_pop ) type = 'Number' width = '17rem' ).
***    DATA(lo_c10) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c10->label( text = 'UOM' class = 'rakReq' ).
***    lo_c10->input( value = io_ctx->bind( c_uom_pop ) width = '17rem' ).
***    DATA(lo_c11) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c11->label( text = 'Invoice Number' class = 'rakReq' ).
***    lo_c11->input( value = io_ctx->bind( c_invoice_pop ) width = '17rem' ).
***    DATA(lo_c12) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c12->label( text = 'Country of Origin' class = 'rakReq' ).
***    lo_c12->input( value = io_ctx->bind( c_origin_pop ) width = '17rem' ).
***    DATA(lo_c13) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c13->label( text = 'Point of Entrance/End User' class = 'rakReq' ).
***    lo_c13->input( value = io_ctx->bind( c_end_user_pop ) width = '17rem' ).
***    DATA(lo_c14) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c14->label( text = 'Bill of Lading' class = 'rakReq' ).
***    lo_c14->input( value = io_ctx->bind( c_bol_pop ) width = '17rem' ).
***    DATA(lo_c15) = lo_r2->vbox( class = 'rakCell' ).
***    lo_c14->label( text = 'Transport Company' class = 'rakReq' ).
***    lo_c14->input( value = io_ctx->bind( c_trans_comp ) width = '17rem' ).







*   ---- their documents ------------------------------------------------
*   iv_key is what makes a repeating list work. Every uploader here is keyed on
*   THIS owner's id, so the chips shown are only theirs and the file reaches the
*   backend as identifier1 = MAIN_DOC_<owner id> - the shape the D0xx BAdI
*   already reads for OWNERS_SEARCH_<n>.
*
*   Without the key every owner's files would land in one chip list with nothing
*   to tell them apart, and the delete button beside a chip would remove
*   somebody else's document.
**    lo_c->title( text = 'Documents' class = 'rakBlkTitle sapUiSmallMarginTop' ).
**    lo_c->label( text = 'Emirates ID copy' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'EMI_COPY_POP' iv_key = lv_id ).
**    lo_c->label( text = 'Passport copy' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'PASSPORT_COPY_POP' iv_key = lv_id ).
**    lo_c->label( text = 'Introductory Statement' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'INTRODUCTORY_POP' iv_key = lv_id ).
**    lo_c->label( text = 'Criminal clearance certificate' ).
**    io_ctx->render_upload( io_view = lo_c iv_field = 'CRIMINAL_CLEAR_POP' iv_key = lv_id ).

    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = 'Add'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_ownok ) ).
    lo_b->button( text = 'Close' press = io_ctx->event( c_evt_owncx ) ).

  ENDMETHOD.


  METHOD write_flags.
    DATA(lv_role) = io_ctx->get_val( c_role ).
    io_ctx->set_val( iv_name  = 'PARTNER_OWNER'
                     iv_value = COND #( WHEN lv_role = 'O' THEN 'X' ELSE '' ) ).
    io_ctx->set_val( iv_name  = 'PARTNER_REP'
                     iv_value = COND #( WHEN lv_role = 'R' THEN 'X' ELSE '' ) ).

    DATA(lv_permit) = io_ctx->get_val( c_permit ).
    io_ctx->set_val( iv_name  = 'PERMIT_YES'
                     iv_value = COND #( WHEN lv_permit = 'Y' THEN 'X' ELSE '' ) ).
    io_ctx->set_val( iv_name  = 'PERMIT_NO'
                     iv_value = COND #( WHEN lv_permit = 'N' THEN 'X' ELSE '' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.

    IF io_ctx->get_val( c_role ) IS INITIAL.
      IF io_ctx->get_val( 'PARTNER_REP' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_role iv_value = 'R' ).
      ELSEIF io_ctx->get_val( 'PARTNER_OWNER' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_role iv_value = 'O' ).
      ENDIF.
    ENDIF.

    IF io_ctx->get_val( c_permit ) IS INITIAL.
      IF io_ctx->get_val( 'PERMIT_NO' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_permit iv_value = 'N' ).
      ELSEIF io_ctx->get_val( 'PERMIT_YES' ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_permit iv_value = 'Y' ).
      ENDIF.
    ENDIF.

    IF io_ctx->get_val( 'PERMIT_LOADED' ) IS NOT INITIAL.
      LOOP AT company_fields( ) INTO DATA(lv_field).
        io_ctx->set_readonly( iv_field = lv_field iv_on = abap_true ).
        io_ctx->set_required( iv_field = lv_field iv_on = abap_false ).
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

    write_flags( io_ctx ).
    DELETE ct_kv WHERE key = 'APPLICANT_ROLE'.
    DELETE ct_kv WHERE key = 'PERMIT_HELD'.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

    CASE iv_field.
      WHEN c_role.
        write_flags( io_ctx ).
        IF io_ctx->get_val( c_role ) <> 'R'.
          io_ctx->set_val( iv_name = 'OWNER' iv_value = '' ).
        ENDIF.

      WHEN c_permit.
        write_flags( io_ctx ).
        IF io_ctx->get_val( c_permit ) = 'Y'.
          io_ctx->set_val( iv_name = 'REGISTERED_EMIRATES' iv_value = '' ).
          io_ctx->set_val( iv_name = 'TRADE_LICENSE' iv_value = '' ).
        ELSE.
          io_ctx->set_val( iv_name = 'PERMIT_NUMBER' iv_value = '' ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

    CASE iv_step.

      WHEN 0.
*       RE-DERIVED, NOT REFUSED.
*
*       PARTNER_OWNER/PARTNER_REP and PERMIT_YES/PERMIT_NO are not answers
*       in their own right - they are WRITE_FLAGS( )'s projection of
*       APPLICANT_ROLE and PERMIT_HELD, which are the fields the citizen
*       actually fills in. This used to refuse the step whenever the role
*       was set and its flags were not, with "Re-select Owner or
*       Representative before continuing."
*
*       The citizen had already selected it. WRITE_FLAGS( ) only runs from
*       ON_CHANGE( ), so any round trip that reinstates the model without
*       raising a change on APPLICANT_ROLE - a backend read answering the
*       step, the BP search coming back - leaves the role set and the flags
*       blank. Re-selecting the same value raises no CHANGE either, so the
*       one instruction the message gave could not clear it: the journey
*       stopped at step 1. Reported on all three chemical journeys as
*       "error showing we u select representative and search with owner EID
*       details, not moving to next step".
*
*       Rewriting them is what the handler does at post time anyway -
*       ON_BEFORE_POST( ) calls WRITE_FLAGS( ) before every post - so doing
*       it here costs nothing and removes the only state that could block.
        write_flags( io_ctx ).

      WHEN 2.
        DATA(ls_grid) = io_ctx->get_grid_data( c_grid ).
        IF ls_grid-rows IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = c_grid
                          text  = `Add at least one material row.` ) TO rt.
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

    CONSTANTS c_login_bp TYPE string VALUE 'LOGIN_BP' ##NO_TEXT.
    CONSTANTS c_owner_bp TYPE string VALUE 'OWNER_BP' ##NO_TEXT.

    CONSTANTS c_partner_name TYPE string VALUE 'APP_NAME' ##NO_TEXT.
    CONSTANTS c_partner_id TYPE string VALUE 'PARTNER_ID' ##NO_TEXT.
    CONSTANTS c_applicanttype TYPE string VALUE 'APPLICANTTYPE' ##NO_TEXT.
    CONSTANTS c_lang_en TYPE string VALUE 'E' ##NO_TEXT.




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

      io_ctx->set_val( iv_name = c_owner_bp iv_value = |{ ls_bp-owner_id }| ).

    ENDIF.


    io_ctx->set_val( iv_name = 'APP_NAME' iv_value = COND #(
      WHEN sy-langu <> 'E' AND ls_bp-bp_name_ar IS NOT INITIAL
      THEN CONV string( ls_bp-bp_name_ar )
      ELSE CONV string( ls_bp-bp_name ) ) ).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( ls_bp-emirates_id ) ).

    io_ctx->set_val( iv_name = 'OWNER_SEARCH_IDTYPE'    iv_value = CONV #( 'YFS002' ) ).
    io_ctx->set_val( iv_name = 'PERMIT_NUMBER_IDTYPE'    iv_value = CONV #( 'HF' ) ).
   ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.



    CALL METHOD super->zif_rak_journey_logic~on_popup_event
      EXPORTING
        io_ctx   = io_ctx
        iv_id    = iv_id
        iv_event = iv_event.

    CASE iv_event.
      WHEN c_evt_details.
        chem_form_load( io_ctx ).          " no id = a new owner
        io_ctx->open_popup( c_chem ).

      WHEN c_evt_ownok. "'OWNER_ADD'. "
*       Nothing here used to check any field - Add saved whatever was typed,
*       blank fields included. All fourteen are now tested, mirroring the
*       REQUIRED markers in ON_RENDER_POPUP( ) one for one.
        IF io_ctx->get_val( c_hs_code_pop )          IS INITIAL
           OR io_ctx->get_val( c_material_name_pop )    IS INITIAL
           OR io_ctx->get_val( c_chemical_name_pop )    IS INITIAL
           OR io_ctx->get_val( c_cas_pop )              IS INITIAL
           OR io_ctx->get_val( c_chemical_formula_pop ) IS INITIAL
           OR io_ctx->get_val( c_packaging_pop )     IS INITIAL
           OR io_ctx->get_val( c_quantity_pop )      IS INITIAL
           OR io_ctx->get_val( c_gross_weight_pop )  IS INITIAL
           OR io_ctx->get_val( c_uom_pop )           IS INITIAL
           OR io_ctx->get_val( c_invoice_pop )       IS INITIAL
           OR io_ctx->get_val( c_origin_pop )        IS INITIAL
           OR io_ctx->get_val( c_end_user_pop )      IS INITIAL
           OR io_ctx->get_val( c_bol_pop )           IS INITIAL
           OR io_ctx->get_val( c_trans_comp )        IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Kindly fill required details.' ).
          RETURN.
        ENDIF.

        own_form_save( io_ctx ).
        io_ctx->close_popup( ). "Close pop-up screen after adding data


*      WHEN c_evt_hist.
**       Fill the dialog from the chosen declaration and leave it OPEN - this
**       shipment's own figures are still to type.
*        history_apply( io_ctx ).

      WHEN c_evt_owncx. "'CANCEL'. "
        io_ctx->close_popup( ).

*      WHEN c_evt_ownsr.
*        own_search( io_ctx ).

      WHEN OTHERS.
*    "Edit Chemicals Details GRID
        IF iv_event CP c_edit_pop.
          own_edit( io_ctx = io_ctx iv_id = substring( val = iv_event off = 9 ) ).
          io_ctx->open_popup( c_chem ).
          RETURN.
*     "Delete data from Chemicals Details GRID
        ELSEIF iv_event CP c_DELETE_POP.
          own_delete( io_ctx = io_ctx iv_id = substring( val = iv_event off = 8 ) ).
          RETURN.
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END.
    CALL METHOD super->zif_rak_journey_logic~on_render_end
      EXPORTING
        io_ctx  = io_ctx
        io_view = io_view.

     IF io_ctx->get_step( ) = 2.
      render_chem_details( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.
  endmethod.


  METHOD zif_rak_journey_logic~on_render_popup.

    super->zif_rak_journey_logic~on_render_popup(
          io_ctx   = io_ctx
          io_popup = io_popup
          iv_id    = iv_id
        ).

**    CHECK iv_id = c_pop_mat.
    CASE iv_id. "c_chem."
      WHEN 'c_chem1'.
*        render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
*        RETURN.
      WHEN c_chem. "c_evt_details. "c_chem. "c_evt_details. " FOr F4 use this

*       REQUIRED here is the marker only - DIALOG_FORM( ) sets it on the label
*       and enforces nothing; a popup's enforcement is the handler's own, in the
*       OK event. So this list mirrors WHEN c_evt_ownok exactly - now all
*       fourteen marked and all fourteen tested, per CJSMIG-697 Issue 4 "all
*       fields should be mandatory". Move one end and the other has to move
*       with it.
        dialog_form(
          io_ctx     = io_ctx
          io_popup   = io_popup
          iv_title   = 'Add Chemical'
*         Two per row. "Alignment instead each row one filed, can have 2 or
*         more field for better user experiences" - same ticket.
          iv_columns = 2
          it_fields  = VALUE #(
*                             The history picker stays out: "Use a previous
*                             declaration - field not required". HISTORY_OPTS( )
*                             and HISTORY_APPLY( ) are kept for the legacy
*                             Search-from-History screen the same ticket asks
*                             for, which is a different control.
                                ( name = c_hs_code_pop          label = 'HS Code' required = abap_true
                                  placeholder = 'e.g. 2933.99.90' )
                                ( name = c_material_name_pop    label = 'Material Name' required = abap_true )
                                ( name = c_chemical_name_pop    label = 'Chemical Name' required = abap_true )
                                ( name = c_cas_pop              label = 'CAS Number' maxlen = 20 required = abap_true )
                                ( name = c_chemical_formula_pop label = 'Chemical Formula' required = abap_true )
                                ( name = c_packaging_pop        label = 'Packing' required = abap_true )
                                ( name = c_quantity_pop         label = 'Quantity' required = abap_true )
                                ( name = c_gross_weight_pop     label = 'Gross Weight' required = abap_true )
                                ( name = c_uom_pop              label = 'UOM' type = 'SELECT' required = abap_true
                                  options = VALUE #( ( key = 'GAL' text = 'Gallon' )
                                                     ( key = 'KG'  text = 'Kilogram' )
                                                     ( key = 'LIT' text = 'Liter' )
                                                     ( key = 'MAT' text = 'Metric Ton' ) ) )

                                ( name = c_invoice_pop          label = 'Invoice Number' required = abap_true )
                                ( name = c_origin_pop           label = 'Country of Origin' shlp = 'H_T005' required = abap_true )
                                ( name = c_end_user_pop         label = 'Point of Entrance' required = abap_true )
                                ( name = c_bol_pop              label = 'Bill of Lading' required = abap_true )
                                ( name = c_trans_comp           label = 'Transport Company' required = abap_true )
                              )

          iv_ok_text = 'Add'
          iv_ok_evt  = c_evt_ownok
          iv_cxl_evt = c_evt_owncx ).
        RETURN.

*        dialog_form(
*          io_ctx     = io_ctx
*          io_popup   = io_popup
*          iv_title   = 'Add Chemical'
*          it_fields  = VALUE #(
*                                ( name = c_hs_code_pop          label = 'HS Code'  )
*                                ( name = c_material_name_pop    label = 'Material Name' )
*                                ( name = c_chemical_name_pop    label = 'Chemical Name' )
*                                ( name = c_cas_pop              label = 'CAS Number' )
*                                ( name = c_chemical_formula_pop label = 'Chemical Formula' )
*                                ( name = c_packaging_pop        label = 'Packing' )
*                                ( name = c_quantity_pop         label = 'Quantity'  )
*                                ( name = c_gross_weight_pop     label = 'Gross Weight'  )
*                                ( name = c_uom_pop              label = 'UOM'  )
*                                ( name = c_invoice_pop          label = 'Invoice Number'  )
*                                ( name = c_origin_pop           label = 'Country of Origin'  )
*                                ( name = c_end_user_pop         label = 'Point of Entrance'  )
*                                ( name = c_bol_pop              label = 'Bill of Lading'  )
*                                ( name = c_trans_comp           label = 'Transport Company'  )
*                              )
*          iv_ok_text = 'Add'
*          iv_ok_evt  = c_own_add ).

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    IF iv_field = 'OWNER_SEARCH'.

      CHECK to_upper( iv_field ) = 'OWNER_SEARCH'.

      DATA(lv_eid) = condense( io_ctx->get_val( 'OWNER_SEARCH' ) ).
      IF lv_eid IS INITIAL.
        io_ctx->add_msg( iv_type = 'Warning'
                         iv_text = |Enter Emirates ID to search| ).
        RETURN.
      ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( 'OWNER_SEARCH_IDTYPE' ).
      IF lv_idtype IS INITIAL.
        lv_idtype = 'YFS002'.
      ENDIF.

      DATA: lv_eid_no   TYPE bu_id_number,
            lv_eid_type TYPE bu_id_type.

      lv_eid_no = lv_eid.
      lv_eid_type = lv_idtype.

      DATA ev_partner         TYPE partner.
      DATA ev_id_number       TYPE bu_id_number.
      DATA ev_passport        TYPE bu_id_number.
      DATA ev_name            TYPE bu_name1tx.
      DATA ev_phone           TYPE farp_mobile.
      DATA ev_email           TYPE ad_smtpadr.
      DATA ev_nationality     TYPE natio50.
      DATA ev_nationality_key TYPE bu_natio.
      DATA ev_date_of_birth   TYPE bu_birthdt.
      DATA ev_message         TYPE bapiret2-message.

      CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
        EXPORTING
          iv_type            = lv_eid_type
          iv_idnumber        = lv_eid_no
*         IV_APP             = IV_APP
        IMPORTING
          ev_partner         = ev_partner
          ev_id_number       = ev_id_number
          ev_passport        = ev_passport
          ev_name            = ev_name
          ev_phone           = ev_phone
          ev_email           = ev_email
          ev_nationality     = ev_nationality
          ev_nationality_key = ev_nationality_key
          ev_date_of_birth   = ev_date_of_birth
          ev_message         = ev_message.

      io_ctx->set_val( iv_name = 'OWNER_NAME'        iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_PHONE'      iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_EMAIL'       iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_DOB'         iv_value = ' ' ).
      io_ctx->set_val( iv_name = 'OWNER_NATIONALITY' iv_value = ' ' ).

*

      io_ctx->set_val( iv_name = 'OWNER_SEARCH'  iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = 'OWNER_NAME'        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = 'OWNER_PHONE'      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = 'OWNER_EMAIL'       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = 'OWNER_DOB'         iv_value = |{ ev_date_of_birth DATE = USER }| ).
      io_ctx->set_val( iv_name = 'OWNER_NATIONALITY' iv_value = |{ ev_nationality }| ).

    ELSEIF iv_field = 'PERMIT_NUMBER'.
      DATA(lv_permit) = condense( io_ctx->get_val( 'PERMIT_NUMBER' ) ).

      IF lv_permit IS NOT INITIAL.
        SELECT SINGLE contractname FROM zv_epdapmmast INTO @DATA(lv_contrat) WHERE permitid = @lv_permit.

        IF lv_contrat IS NOT INITIAL.
          io_ctx->set_val( iv_name = 'PERMIT_NUMBER'  iv_value = |{ lv_permit }| ).
          io_ctx->set_val( iv_name = 'PERMIT_DETAIL'  iv_value = |{ lv_contrat }| ).
        ELSE.
          io_ctx->set_val( iv_name = 'PERMIT_DETAIL' iv_value = ' ' ).
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Enter Valid Permit No to search| ).
        ENDIF.

      ENDIF.




    ENDIF.

  ENDMETHOD.


  METHOD own_form_save.
*   This used to copy every existing row through unchanged and then always
*   APPEND a new one - there was no check anywhere for "does a row with
*   this HS Code already exist". Every Add after an Edit duplicated the
*   row it came from instead of updating it, leaving the stale original
*   still in the grid. HS Code is the row's key (RENDER_CHEM_DETAILS and
*   OWN_DELETE already match on column 1 by it), so this now finds that
*   row and overwrites it in place, the same as every other Add-a-row
*   popup in this codebase.
*
*   THE APPEND ORDER BELOW IS THE CONFIGURED COLUMN ORDER, not a free choice.
*   SET_GRID_DATA( ) is handed COLUMNS straight back from GET_GRID_DATA( ), so
*   its map-by-name is an identity map and cell N lands in configured column N
*   (ZCL_RAK_JOURNEY_ENGINE:2614). Append a cell out of order and it is written
*   to the neighbouring column; append past the last configured column and it is
*   dropped. Neither raises anything. Before adding or reordering a field here,
*   read the grid spec in ZRAK_T_JNY_FLD-DEFAULT_VAL for this grid field and
*   match it - the display methods in this class only corroborate the first few.
    DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).

    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.

    DATA(lv_hs_code)    = condense( io_ctx->get_val( C_HS_CODE_POP ) ).
    DATA(lv_mat_name)   = condense( io_ctx->get_val( C_MATERIAL_NAME_POP ) ).
    DATA(lv_chem_name)  = condense( io_ctx->get_val( C_CHEMICAL_NAME_POP ) ).
    DATA(lv_cas)        = condense( io_ctx->get_val( C_CAS_POP ) ).
    DATA(lv_chem_form)  = condense( io_ctx->get_val( C_CHEMICAL_FORMULA_POP ) ).
    DATA(lv_packaging)  = condense( io_ctx->get_val( C_PACKAGING_POP ) ).
    DATA(lv_qty)        = condense( io_ctx->get_val( C_QUANTITY_POP ) ).
    DATA(lv_gr_wt)      = condense( io_ctx->get_val( C_GROSS_WEIGHT_POP ) ).
    DATA(lv_uom)        = condense( io_ctx->get_val( C_UOM_POP ) ).
    DATA(lv_inv_no)     = condense( io_ctx->get_val( C_INVOICE_POP ) ).
    DATA(lv_orig_ctry)  = condense( io_ctx->get_val( C_ORIGIN_POP ) ).
    DATA(lv_entrance)   = condense( io_ctx->get_val( C_END_USER_POP ) ).
    DATA(lv_bol)        = condense( io_ctx->get_val( C_BOL_POP ) ).
    DATA(lv_trans_comp) = condense( io_ctx->get_val( C_TRANS_COMP ) ).

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF VALUE string( lt_r[ 1 ] OPTIONAL ) = lv_hs_code.
        lv_found = abap_true.
        CLEAR lt_row.
        APPEND lv_hs_code     TO lt_row. " HS Code
        APPEND lv_mat_name    TO lt_row. " Material name
        APPEND lv_chem_name   TO lt_row. " Chemical Name
        APPEND lv_cas         TO lt_row. " CAS No
        APPEND lv_chem_form   TO lt_row. " Chemical Formulae
        APPEND lv_packaging   TO lt_row. " Packaging
        APPEND lv_qty         TO lt_row. " Quantity
        APPEND lv_gr_wt       TO lt_row. " Gross weight
        APPEND lv_uom         TO lt_row. " Unit
        APPEND lv_inv_no      TO lt_row. " Invoice No
        APPEND lv_orig_ctry   TO lt_row. " Ctry of origin
        APPEND lv_entrance    TO lt_row. " Point of entrance
        APPEND lv_bol         TO lt_row. " Bill of lading
        APPEND lv_trans_comp  TO lt_row. " Transport Company
        APPEND lt_row TO ls_new-rows.
      ELSE.
        APPEND lt_r TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      CLEAR lt_row.
      APPEND lv_hs_code     TO lt_row. " HS Code
      APPEND lv_mat_name    TO lt_row. " Material name
      APPEND lv_chem_name   TO lt_row. " Chemical Name
      APPEND lv_cas         TO lt_row. " CAS No
      APPEND lv_chem_form   TO lt_row. " Chemical Formulae
      APPEND lv_packaging   TO lt_row. " Packaging
      APPEND lv_qty         TO lt_row. " Quantity
      APPEND lv_gr_wt       TO lt_row. " Gross weight
      APPEND lv_uom         TO lt_row. " Unit
      APPEND lv_inv_no      TO lt_row. " Invoice No
      APPEND lv_orig_ctry   TO lt_row. " Ctry of origin
      APPEND lv_entrance    TO lt_row. " Point of entrance
      APPEND lv_bol         TO lt_row. " Bill of lading
      APPEND lv_trans_comp  TO lt_row. " Transport Company
      APPEND lt_row TO ls_new-rows.
    ENDIF.

    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
  ENDMETHOD.


  METHOD own_delete.
    DATA(ls_g)   = io_ctx->get_grid_data( c_grid ).
    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).

    LOOP AT ls_g-rows INTO DATA(lt_r).
      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) <> iv_id.
      APPEND lt_r TO ls_new-rows.
    ENDLOOP.

    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).

*    c_hs_code_pop

  ENDMETHOD.


  METHOD own_edit.
*   Every field but HS Code was commented out here, so Edit opened with
*   the row's own HS Code and thirteen blank fields regardless of what had
*   actually been saved - it looked like a fresh Add, not an edit. Row
*   layout is the one OWN_FORM_SAVE( ) writes: 1 HS Code, 2 Material,
*   3 Chemical Name, 4 CAS, 5 Formula, 6 Packaging, 7 Quantity,
*   8 Gross Weight, 9 UOM, 10 Invoice, 11 Origin, 12 End User, 13 BOL,
*   14 Transport Company.
    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).

      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) = iv_id.
      io_ctx->set_val( iv_name = c_hs_code_pop          iv_value = VALUE #( lt_r[ 1 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_material_name_pop    iv_value = VALUE #( lt_r[ 2 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_chemical_name_pop    iv_value = VALUE #( lt_r[ 3 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_cas_pop              iv_value = VALUE #( lt_r[ 4 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_chemical_formula_pop iv_value = VALUE #( lt_r[ 5 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_packaging_pop        iv_value = VALUE #( lt_r[ 6 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_quantity_pop         iv_value = VALUE #( lt_r[ 7 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_gross_weight_pop     iv_value = VALUE #( lt_r[ 8 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_uom_pop              iv_value = VALUE #( lt_r[ 9 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_invoice_pop          iv_value = VALUE #( lt_r[ 10 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_origin_pop           iv_value = VALUE #( lt_r[ 11 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_end_user_pop         iv_value = VALUE #( lt_r[ 12 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_bol_pop              iv_value = VALUE #( lt_r[ 13 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_trans_comp           iv_value = VALUE #( lt_r[ 14 ] OPTIONAL ) ).
      EXIT.
    ENDLOOP.

  ENDMETHOD.


  METHOD own_search.

    DATA(lv_eid) = condense( io_ctx->get_val( c_origin_pop ) ). " Ctry of origin if added
    IF strlen( lv_eid ) < 2.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Type at least 2 characters of country.' ).
      RETURN.
    ENDIF.
    DATA: lv_ctr TYPE t005-land1 .
    lv_ctr = lv_eid.
    SELECT SINGLE land1 FROM t005 INTO @DATA(lv_country) WHERE land1 = @lv_ctr .

    io_ctx->set_val( iv_name = c_origin_pop iv_value = CONV string( lv_country ) ).

  ENDMETHOD.
ENDCLASS.
