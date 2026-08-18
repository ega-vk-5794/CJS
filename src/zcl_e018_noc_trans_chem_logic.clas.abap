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
PRIVATE SECTION.

  CONSTANTS c_role TYPE string VALUE 'APPLICANT_ROLE' ##NO_TEXT.
  CONSTANTS c_permit TYPE string VALUE 'PERMIT_HELD' ##NO_TEXT.
  CONSTANTS c_grid TYPE string VALUE 'CHEMICALS_DETAILS' ##NO_TEXT.
  CONSTANTS c_evt_details TYPE string VALUE 'ADD Details' ##NO_TEXT.
  CONSTANTS c_hs_code_pop TYPE string VALUE 'HS_CODE_POP' ##NO_TEXT.
  CONSTANTS c_material_name_pop TYPE string VALUE 'MATERIAL_NAME_POP' ##NO_TEXT.
  CONSTANTS c_chemical_name_pop TYPE string VALUE 'CHEMICAL_NAME_POP' ##NO_TEXT.
  CONSTANTS c_cas_pop TYPE string VALUE 'CAS_POP' ##NO_TEXT.
  CONSTANTS c_chemical_formula_pop TYPE string VALUE 'CHEMICAL_FORMULA_POP' ##NO_TEXT.
  CONSTANTS c_packaging_pop TYPE string VALUE 'PACKAGING_POP' ##NO_TEXT.
  CONSTANTS c_quantity_pop TYPE string VALUE 'QUANTITY_POP' ##NO_TEXT.
  CONSTANTS c_gross_weight_pop TYPE string VALUE 'GROSS_WEIGHT_POP' ##NO_TEXT.
  CONSTANTS c_uom_pop TYPE string VALUE 'UOM_POP' ##NO_TEXT.
  CONSTANTS c_invoice_pop TYPE string VALUE 'INVOICE_POP' ##NO_TEXT.
  CONSTANTS c_origin_pop TYPE string VALUE 'ORIGIN_POP' ##NO_TEXT.
  CONSTANTS c_end_user_pop TYPE string VALUE 'END_USER_POP' ##NO_TEXT.
  CONSTANTS c_bol_pop TYPE string VALUE 'BOL_POP' ##NO_TEXT.
  CONSTANTS c_trans_comp TYPE string VALUE 'BOL_POP' ##NO_TEXT.
  CONSTANTS c_chem TYPE string VALUE 'CHEM' ##NO_TEXT.
  CONSTANTS c_evt_ownok TYPE string VALUE 'OWN_OK' ##NO_TEXT.
  CONSTANTS c_evt_owncx TYPE string VALUE 'OWN_CANCEL' ##NO_TEXT.
  CONSTANTS c_own_add TYPE string VALUE 'OWNER_ADD' ##NO_TEXT.

  METHODS write_flags
    IMPORTING
      !io_ctx TYPE REF TO zif_rak_journey .
  METHODS company_fields
    RETURNING
      VALUE(rt) TYPE zif_rak_journey=>tt_string .
  METHODS chem_form_load
    IMPORTING
      !io_ctx TYPE REF TO zif_rak_journey
      !iv_id  TYPE string OPTIONAL .
  METHODS render_chem_details
    IMPORTING
      !io_ctx  TYPE REF TO zif_rak_journey
      !io_view TYPE REF TO z2ui5_cl_xml_view .
  METHODS render_own_popup
    IMPORTING
      !io_ctx   TYPE REF TO zif_rak_journey
      !io_popup TYPE REF TO z2ui5_cl_xml_view .
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
ENDCLASS.



CLASS ZCL_E018_NOC_TRANS_CHEM_LOGIC IMPLEMENTATION.


  METHOD chem_form_load.

    io_ctx->set_val( iv_name = c_HS_CODE_POP         iv_value = '' ).
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


****    IF iv_id IS INITIAL.
*****     New owner. The id is minted NOW and not on save, because the uploaders in
*****     the dialog key their files on it - a file attached before the row exists
*****     still has to belong to the right person.
****      io_ctx->set_val( iv_name  = c_own_id
****                       iv_value = 'YFS002' ).
****      RETURN.
****    ENDIF.

**    io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).
    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).
    CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) = iv_id.
    io_ctx->set_val( iv_name = c_HS_CODE_POP          iv_value = VALUE #( lt_r[ 2 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_material_name_pop    iv_value = VALUE #( lt_r[ 3 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_chemical_name_pop    iv_value = VALUE #( lt_r[ 4 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_cas_pop              iv_value = VALUE #( lt_r[ 5 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_chemical_formula_pop iv_value = VALUE #( lt_r[ 6 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_packaging_pop        iv_value = VALUE #( lt_r[ 7 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_quantity_pop         iv_value = VALUE #( lt_r[ 8 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_gross_weight_pop     iv_value = VALUE #( lt_r[ 9 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_uom_pop              iv_value = VALUE #( lt_r[ 10 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_invoice_pop          iv_value = VALUE #( lt_r[ 11 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_origin_pop           iv_value = VALUE #( lt_r[ 12 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_end_user_pop         iv_value = VALUE #( lt_r[ 13 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_bol_pop              iv_value = VALUE #( lt_r[ 14 ] OPTIONAL ) ).
    io_ctx->set_val( iv_name = c_trans_comp           iv_value = VALUE #( lt_r[ 14 ] OPTIONAL ) ).
    EXIT.
  ENDLOOP.

ENDMETHOD.


  METHOD company_fields.
    rt = VALUE #(
      ( `COMPANY_NAME_EN` ) ( `COMPANY_NAME_AR` ) ( `CO_REG_EMIRATES` )
      ( `CO_ADDRESS` )      ( `CO_TRADE_LICENSE` ) ( `CO_MOBILE` )
      ( `CO_TELEPHONE` )    ( `CO_EMAIL` ) ).
  ENDMETHOD.


  METHOD render_chem_details.

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
    lo_cl->column( )->text( 'Chemical Name' ).
    lo_cl->column( )->text( 'Material name' ).
    lo_cl->column( )->text( 'CAS Number' ).
    lo_cl->column( )->text( 'Gross Weight' ).
    lo_cl->column( halign = 'End' )->text( '' ).

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
      DATA(lv_id)  = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_nam) = VALUE string( lt_r[ 2 ] OPTIONAL ).
      DATA(lv_eid) = VALUE string( lt_r[ 3 ] OPTIONAL ).
      DATA(lv_nat) = VALUE string( lt_r[ 4 ] OPTIONAL ).
      DATA(lv_shr) = VALUE string( lt_r[ 5 ] OPTIONAL ).

*     How many files this owner has. Counting them here is the only way the
*     citizen can see, from the list, whose documents are still missing.
      DATA lv_docs TYPE i.
      CLEAR lv_docs.
      LOOP AT io_ctx->get_attachment_files( ) INTO DATA(ls_af).
        IF ls_af-identifier1 CS |_{ lv_id }|.
          lv_docs = lv_docs + 1.
        ENDIF.
      ENDLOOP.

      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
*     Name over Emirates ID, as the legacy screen had it.
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_nam ).
      lo_nm->text( text = lv_eid class = 'rakRecMeta' ).
      lo_cells->text( lv_nat ).
      lo_cells->text( lv_shr ).
      lo_cells->object_status(
        text  = |{ lv_docs } file(s)|
        state = COND #( WHEN lv_docs > 0 THEN 'Success' ELSE 'Warning' )
        icon  = COND #( WHEN lv_docs > 0 THEN 'sap-icon://attachment' ELSE 'sap-icon://alert' ) ).
*     Two buttons rather than the legacy overflow menu: one press instead of
*     two, and nothing hidden behind an icon a citizen has to discover.
      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = 'Edit owner details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_id }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_id }| ) ).
    ENDLOOP.

    IF ls_g-rows IS INITIAL.
      io_view->message_strip( text     = 'No owners yet. Press Add Owner to enter the first one.'
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiSmallMarginTop' ).
    ENDIF.


  ENDMETHOD.


  METHOD render_own_popup.

**    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = 'Chemical/Material Details' contentwidth = '55rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*   Search sits ON the section title, not under the Emirates ID field, because
*   it acts on the whole form: type the ID, press Search, and the rest fills in.
**    DATA(lo_hdr) = lo_c->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
**    lo_hdr->title( text = 'Owner Details' class = 'rakBlkTitle' ).
**    lo_hdr->button( text  = 'Search'
**                    type  = 'Emphasized'
**                    icon  = 'sap-icon://search'
**                    press = io_ctx->event( c_evt_ownsr ) ).

*   Two per row, the way the legacy dialog laid it out.
    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' )."ROw 1

    DATA(lo_c1) = lo_r1->vbox( class = 'rakCell' ).
    lo_c1->label( text = 'HS Code' class = 'rakReq' ).
    lo_c1->input( value = io_ctx->bind( c_hs_code_pop ) width = '17rem' ).

    DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).
    lo_c2->label( text = 'Material Name' ).
    lo_c2->input( value = io_ctx->bind( 'C_MATERIAL_NAME_POP' ) width = '17rem' ).

    DATA(lo_c3) = lo_r1->vbox( class = 'rakCell' ).
    lo_c3->label( text = 'Chemical Name' ).
    lo_c3->input( value = io_ctx->bind( 'C_CHEMICAL_NAME_POP' ) width = '17rem' ).

*&--------Row 2-----------&
    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).

    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
    lo_c4->label( text = 'CAS Number' ).
    lo_c4->input( value = io_ctx->bind( 'C_CAS_POP' ) width = '17rem' ).

    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
    lo_c5->label( text = 'Chemical formula' ).
    lo_c5->input( value = io_ctx->bind( c_chemical_formula_pop ) width = '17rem' ).

    DATA(lo_c6) = lo_r2->vbox( class = 'rakCell' ).
    lo_c6->label( text = 'Packing' class = 'rakReq' ).
    lo_c6->input( value = io_ctx->bind( c_packaging_pop ) type = 'Number' width = '17rem' ).

    DATA(lo_c7) = lo_r2->vbox( class = 'rakCell' ).
    lo_c7->label( text = 'Quantity' class = 'rakReq' ).
    lo_c7->input( value = io_ctx->bind( c_quantity_pop ) type = 'Number' width = '17rem' ).

    DATA(lo_c8) = lo_r2->vbox( class = 'rakCell' ).
    lo_c8->label( text = 'Gross Weight' class = 'rakReq' ).
    lo_c8->input( value = io_ctx->bind( c_gross_weight_pop ) type = 'Number' width = '17rem' ).

    DATA(lo_c9) = lo_r2->vbox( class = 'rakCell' ).
    lo_c9->label( text = 'UOM' class = 'rakReq' ).
    lo_c9->input( value = io_ctx->bind( c_uom_pop ) width = '17rem' ).

    DATA(lo_c10) = lo_r2->vbox( class = 'rakCell' ).
    lo_c10->label( text = 'Invoice Number' class = 'rakReq' ).
    lo_c10->input( value = io_ctx->bind( c_invoice_pop ) width = '17rem' ).


    DATA(lo_c11) = lo_r2->vbox( class = 'rakCell' ).
    lo_c11->label( text = 'Country of Origin' class = 'rakReq' ).
    lo_c11->input( value = io_ctx->bind( c_origin_pop ) width = '17rem' ).


    DATA(lo_c12) = lo_r2->vbox( class = 'rakCell' ).
    lo_c12->label( text = 'Point of Entrance/End User' class = 'rakReq' ).
    lo_c12->input( value = io_ctx->bind( c_end_user_pop ) width = '17rem' ).


    DATA(lo_c13) = lo_r2->vbox( class = 'rakCell' ).
    lo_c13->label( text = 'Bill of Lading' class = 'rakReq' ).
    lo_c13->input( value = io_ctx->bind( c_bol_pop ) width = '17rem' ).


    DATA(lo_c14) = lo_r2->vbox( class = 'rakCell' ).
    lo_c14->label( text = 'Transport Company' class = 'rakReq' ).
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

    CASE iv_step.

      WHEN 0.
        IF io_ctx->get_val( c_role ) IS NOT INITIAL
           AND io_ctx->get_val( 'PARTNER_OWNER' ) IS INITIAL
           AND io_ctx->get_val( 'PARTNER_REP' )   IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = c_role
                          text  = `Re-select Owner or Representative before continuing.` ) TO rt.
        ENDIF.

        IF io_ctx->get_val( c_permit ) IS NOT INITIAL
           AND io_ctx->get_val( 'PERMIT_YES' ) IS INITIAL
           AND io_ctx->get_val( 'PERMIT_NO' )  IS INITIAL.
          APPEND VALUE #( type  = 'Error'
*                          field = c_permit
                          text  = `Re-select the permit answer before continuing.` ) TO rt.
        ENDIF.

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


    IF lv_loginbp IS INITIAL AND sy-sysid <> 'E30'.
      lv_loginbp = '3000000049'.
    ENDIF.

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


    io_ctx->set_val( iv_name = 'APP_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).



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

      WHEN c_evt_owncx.
        io_ctx->close_popup( ).

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
    CASE iv_id.
      WHEN c_chem.
        render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
        RETURN.
      WHEN c_evt_details.


        dialog_form(
          io_ctx     = io_ctx
          io_popup   = io_popup
          iv_title   = 'Add Chemical'
          it_fields  = VALUE #(
                                ( name = 'C_HS_CODE_POP'          label = 'HS Code'  )
                                ( name = 'C_MATERIAL_NAME_POP'    label = 'Material Name' )
                                ( name = 'C_CHEMICAL_NAME_POP'    label = 'Chemical Name' )
                                ( name = 'C_CAS_POP'              label = 'CAS Number' )
                                ( name = 'C_CHEMICAL_FORMULA_POP' label = 'Chemical Formula' )
                                ( name = 'C_PACKAGING_POP'        label = 'Packing' )
                                ( name = 'C_QUANTITY_POP'         label = 'Quantity'  )
                                ( name = 'C_GROSS_WEIGHT_POP'     label = 'Gross Weight'  )
                                ( name = 'C_UOM_POP'              label = 'UOM'  )
                                ( name = 'C_INVOICE_POP'          label = 'Invoice Number'  )
                                ( name = 'C_ORIGIN_POP'           label = 'Country of Origin'  )
                                ( name = 'C_END_USER_POP'         label = 'Point of Entrance'  )
                                ( name = 'BOL_POP'                label = 'Bill of Lading'  )
                                ( name = 'TRANS_COMP'             label = 'Transport Company'  )
*                                ( name = 'DATE_OF_BIRTH_POP' label = 'Date of Birth' )
*                                ( name = 'DATE_OF_BIRTH_POP' label = 'Date of Birth' )
                                 )
          iv_ok_text = 'Add'
          iv_ok_evt  = c_own_add ).

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
ENDCLASS.
