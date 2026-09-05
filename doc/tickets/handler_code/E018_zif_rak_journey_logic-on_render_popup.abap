* E018  CJSMIG-697  ZCL_E018_NOC_TRANS_CHEM_LOGIC
* Add Chemical: the fourteen required markers, and IV_COLUMNS = 2
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

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
