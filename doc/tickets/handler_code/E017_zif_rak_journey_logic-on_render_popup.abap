* E017  CJSMIG-687  ZCL_E017_NOC_EXP_CHEM_LOGIC
* Add Chemical: the fourteen required markers, and IV_COLUMNS = 2 for the two-column dialog
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

  METHOD zif_rak_journey_logic~on_render_popup.
    super->zif_rak_journey_logic~on_render_popup(
      io_ctx   = io_ctx
      io_popup = io_popup
      iv_id    = iv_id
    ).

    CASE iv_id.
*  "On click of ADD Chemical button
      WHEN c_open_popup.
*        render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
*        RETURN.

*       REQUIRED here is the marker only - DIALOG_FORM( ) sets it on the label
*       and enforces nothing; a popup's enforcement is the handler's, in
*       VALIDATE_INPUT( ). So this list has to mirror that method exactly,
*       and now does: all fourteen marked, all fourteen checked.
*
*       That mirror used to read four and four, with ten lines commented out
*       in VALIDATE_INPUT( ) and a note here saying the decision had not been
*       made. It has been now - CJSMIG-687 Issue 4, "all fields should be
*       mandatory" - so both ends were opened together. Change one end and
*       the other has to move with it, or the dialog either promises an
*       asterisk it does not enforce or refuses an OK it never marked.
*
*       THE HISTORY PICKER IS GONE, not commented out: "Use a previous
*       declaration - field not required" (same ticket). HISTORY_OPTS( ),
*       HISTORY_APPLY( ) and C_EVT_HIST are deliberately left in place - the
*       same ticket asks for the legacy Search-from-History screen, which is
*       a different control reading the same ChemicalHistorySet, and it will
*       want them.
        dialog_form(
          io_ctx     = io_ctx
          io_popup   = io_popup
          iv_title   = 'Add Chemical'
*         Two per row. "Alignment instead each row one filed, can have 2 or
*         more field for better user experiences" - fourteen fields one to a
*         row is a dialog nobody can see the bottom of.
          iv_columns = 2
          it_fields  = VALUE #(
                                ( name = c_hs_pop           label = 'HS Code' required = abap_true
                                  placeholder = 'e.g. 2933.99.90' )
                                ( name = c_mat_pop          label = 'Material Name' required = abap_true )
                                ( name = c_chem_pop         label = 'Chemical Name' required = abap_true )
                                ( name = c_cas_no_pop       label = 'CAS Number' maxlen = 20 required = abap_true )
                                ( name = c_chem_form_pop    label = 'Chemical Formula' required = abap_true )
                                ( name = c_packaging_pop    label = 'Packing' required = abap_true )
                                ( name = c_quantity_pop     label = 'Quantity' required = abap_true )
                                ( name = c_gross_weight_pop label = 'Gross Weight' required = abap_true type = 'Number' )
                                ( name = c_unit_pop         label = 'Unit' required = abap_true
                                type = 'SELECT'
                                options = VALUE #( ( key = 'GAL' text = 'Gallon' )
                                                     ( key = 'KG'  text = 'Kilogram' )
                                                     ( key = 'LIT' text = 'Liter' )
                                                     ( key = 'MAT' text = 'Metric Ton' ) ) )
                                ( name = c_invoice_pop      label = 'Invoice Number' required = abap_true )
                                ( name = c_import_pop       label = 'Importing Country' shlp = 'H_T005' required = abap_true )
                                ( name = c_exit_port_pop    label = 'Exit Port' required = abap_true )
                                ( name = c_bol_pop          label = 'Bill of Lading' required = abap_true )
                                ( name = c_tport_pop        label = 'Transport Details' required = abap_true )
                              )
          iv_ok_text = 'Add'
          iv_ok_evt  = c_evt_ownok
          iv_cxl_evt = c_evt_owncx ).
    ENDCASE.
  ENDMETHOD.
