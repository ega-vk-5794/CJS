class ZCL_E017_NOC_EXP_CHEM_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
    redefinition .
protected section.
private section.

  constants C_ROLE type STRING value 'APPLICANT_ROLE' ##NO_TEXT.
  constants C_PERMIT type STRING value 'PERMIT_HELD' ##NO_TEXT.
  constants C_GRID type STRING value 'CHEMICALS_DETAILS' ##NO_TEXT.
  constants C_OPEN_POPUP type STRING value 'CHEMICAL_POP' ##NO_TEXT.
  constants C_ADD_CHEMICAL type STRING value 'ADD_CHEMICAL' ##NO_TEXT.
  constants C_HS_POP type STRING value 'HS_CODE' ##NO_TEXT.
  constants C_MAT_POP type STRING value 'MATERIAL_NAME' ##NO_TEXT.
  constants C_CHEM_POP type STRING value 'CHEMINAL_NAME' ##NO_TEXT.
  constants C_CAS_NO_POP type STRING value 'CAS_NO' ##NO_TEXT.
  constants C_CHEM_FORM_POP type STRING value 'CHEMICAL_FORMULA' ##NO_TEXT.
  constants C_PACKAGING_POP type STRING value 'PACKAGING' ##NO_TEXT.
  constants C_QUANTITY_POP type STRING value 'QUANTITY' ##NO_TEXT.
  constants C_GROSS_WEIGHT_POP type STRING value 'GROSS_WEIGHT' ##NO_TEXT.
  constants C_UNIT_POP type STRING value 'UNIT' ##NO_TEXT.
  constants C_EVT_OWNOK type STRING value 'OWN_OK' ##NO_TEXT.
  constants C_EVT_OWNCX type STRING value 'OWN_CANCEL' ##NO_TEXT.
  constants C_EVT_DETAILS type STRING value 'ADD Details' ##NO_TEXT.
  constants C_INVOICE_POP type STRING value 'INVOICE_NO' ##NO_TEXT.
  constants C_BOL_POP type STRING value 'BOL_POP' ##NO_TEXT.
  constants C_EXIT_PORT_POP type STRING value 'EXIT_POP' ##NO_TEXT.
  constants C_IMPORT_POP type STRING value 'IMP_CONT_POP' ##NO_TEXT.
  constants C_CHEM type STRING value 'CHEM' ##NO_TEXT.
  constants C_TPORT_POP type STRING value 'TPORT_POP' ##NO_TEXT.
  constants C_EDIT_POP type STRING value 'OWN_EDIT_*' ##NO_TEXT.
  constants C_DELETE_POP type STRING value 'OWN_DEL_*' ##NO_TEXT.

  methods OWN_DELETE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING .
  methods POPULATE_GRID
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods RENDER_OWN_LIST
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_VIEW type ref to Z2UI5_CL_XML_VIEW .
  methods VALIDATE_INPUT
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
  methods RENDER_OWN_POPUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_POPUP type ref to Z2UI5_CL_XML_VIEW .
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
  methods OWN_EDIT
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
ENDCLASS.



CLASS ZCL_E017_NOC_EXP_CHEM_LOGIC IMPLEMENTATION.


  METHOD company_fields.
    rt = VALUE #(
      ( `COMPANY_NAME_EN` ) ( `COMPANY_NAME_AR` ) ( `CO_REG_EMIRATES` )
      ( `CO_ADDRESS` )      ( `CO_TRADE_LICENSE` ) ( `CO_MOBILE` )
      ( `CO_TELEPHONE` )    ( `CO_EMAIL` ) ).
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
          APPEND VALUE #( type  = 'Error' "field = c_role
                          text  = `Re-select Owner or Representative before continuing.` ) TO rt.
        ENDIF.

        IF io_ctx->get_val( c_permit ) IS NOT INITIAL
           AND io_ctx->get_val( 'PERMIT_YES' ) IS INITIAL
           AND io_ctx->get_val( 'PERMIT_NO' )  IS INITIAL.
          APPEND VALUE #( type  = 'Error' "field = c_permit
                          text  = `Re-select the permit answer before continuing.` ) TO rt.
        ENDIF.

      WHEN 2.
        DATA(ls_grid) = io_ctx->get_grid_data( c_grid ).
        IF ls_grid-rows IS INITIAL.
          APPEND VALUE #( type  = 'Error' "field = c_grid
                          text  = `Add at least one chemical row.` ) TO rt.
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx = io_ctx ).

    DATA(lv_user) = io_ctx->get_param( iv_name = 'USERDATA' ).

    zcl_ega_cj_utility=>get_bp(
      EXPORTING qv_key  = lv_user
      IMPORTING loginbp = DATA(lv_loginbp)
                rolebp  = DATA(lv_rolebp)
                role    = DATA(lv_role) ).

    IF lv_loginbp IS INITIAL.
      lv_loginbp = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
      lv_rolebp  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
      lv_role    = CAST zcl_rak_journey_engine( io_ctx )->mv_role.

*     "Login BP
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
    ENDIF.


  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
    CALL METHOD super->zif_rak_journey_logic~on_popup_event
      EXPORTING
        io_ctx   = io_ctx
        iv_id    = iv_id
        iv_event = iv_event.

    CASE iv_event.
*    "TRIGGER ON ADD CHEMICAL BUTTON
      WHEN c_evt_details.
        chem_form_load( io_ctx ).
        io_ctx->open_popup( c_open_popup ).

*     "Trigger on click of ADD button in POP-UP Screen
      WHEN c_evt_ownok.
        validate_input( io_ctx ).

        populate_grid( io_ctx ).

*       "Close pop-up screen after adding data
        io_ctx->close_popup( ).

*    "Trigger on click of CANCEL button in POP-UP Screen
      WHEN c_evt_owncx.
        io_ctx->close_popup( ).

      WHEN OTHERS.
*    "Edit Chemicals Details GRID
        IF iv_event CP c_edit_pop.
          own_edit( io_ctx = io_ctx iv_id = substring( val = iv_event off = 9 ) ).
          io_ctx->open_popup( c_open_popup ).
          RETURN.
*     "Delete data from Chemicals Details GRID
        ELSEIF iv_event CP c_DELETE_POP.
          own_delete( io_ctx = io_ctx iv_id = substring( val = iv_event off = 8 ) ).
          RETURN.
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .

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
          io_ctx->set_val( iv_name = 'PERMIT_LOADED'  iv_value = |{ lv_contrat }| ).
        ELSE.
          io_ctx->set_val( iv_name = 'PERMIT_LOADED' iv_value = ' ' ).
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = |Enter Valid Permit No to search| ).
        ENDIF.

      ENDIF.




    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    super->zif_rak_journey_logic~on_render_popup(
      io_ctx   = io_ctx
      io_popup = io_popup
      iv_id    = iv_id
    ).

    CASE iv_id.
*  "On click of ADD Chemical button
      WHEN c_open_popup.
        render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
        RETURN.
*      WHEN c_evt_details.
*
*        dialog_form(
*          io_ctx     = io_ctx
*          io_popup   = io_popup
*          iv_title   = 'Add Chemical'
*          it_fields  = VALUE #(
*                                ( name = 'C_HS_POP'          label = 'HS Code'  )
*                                ( name = 'C_MAT_POP'    label = 'Material Name' )
*                                ( name = 'C_CHEM_POP'    label = 'Chemical Name' )
*                                ( name = 'C_CAS_NO_POP'              label = 'CAS Number' )
*                                ( name = 'C_CHEM_FORM_POP' label = 'Chemical Formula' )
*                                ( name = 'C_PACKAGING_POP'        label = 'Packing' )
*                                ( name = 'C_QUANTITY_POP'         label = 'Quantity'  )
*                                ( name = 'C_GROSS_WEIGHT_POP'     label = 'Gross Weight'  )
*                                ( name = 'C_UNIT_POP'              label = 'UOM'  )
*                                ( name = 'C_INVOICE_POP'          label = 'Invoice Number'  )
*                                ( name = 'C_IMPORT_POP'           label = 'Importing Country' )
*                                ( name = 'C_EXIT_PORT_POP'         label = 'Exit Port' )
*                                ( name = 'C_BOL_POP'      label = 'Bill of Lading'  )
*                                 )
*          iv_ok_text = 'Add'
*          iv_ok_evt  = c_evt_ownok ).
    ENDCASE.
  ENDMETHOD.


  METHOD render_own_popup.

*"Title of dialog box
    DATA(lo_dlg) = io_popup->dialog( title = 'Chemical Details' contentwidth = '40rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*"HS Code
*    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c1) = lo_r2->vbox( class = 'rakCell' ).
    lo_c1->label( text = 'HS Code' class = 'rakReq' ).
    lo_c1->input( value = io_ctx->bind( c_hs_pop )  ).
*   lo_c1->combobox( selectedkey = io_ctx->bind(  c_hs_pop ).

*"Material Name
*    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c2) = lo_r2->vbox( class = 'rakCell' ).
    lo_c2->label( text = 'Material Number' ).
    lo_c2->input( value = io_ctx->bind( c_mat_pop )  ).

*"Chemcial Name
    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
    lo_c4->label( text = 'Chemical Name' ).
    lo_c4->input( value = io_ctx->bind( c_chem_pop )  ).

*"CAS Number
    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
    lo_c5->label( text = 'CAS Number' ).
    lo_c5->input( value = io_ctx->bind( c_cas_no_pop ) type = 'Number'  ).

*"Chemical Formula
    DATA(lo_c6) = lo_r2->vbox( class = 'rakCell' ).
    lo_c6->label( text = 'Chemical Formula' ).
    lo_c6->input( value = io_ctx->bind( c_chem_form_pop ) ).

*"Packaging
    DATA(lo_c7) = lo_r2->vbox( class = 'rakCell' ).
    lo_c7->label( text = 'Packaging' ).
    lo_c7->input( value = io_ctx->bind( c_packaging_pop ) ).

*"Quantity
    DATA(lo_c8) = lo_r2->vbox( class = 'rakCell' ).
    lo_c8->label( text = 'Quantity' ).
    lo_c8->input( value = io_ctx->bind( c_quantity_pop ) ).

*"GROSS Weight
    DATA(lo_c9) = lo_r2->vbox( class = 'rakCell' ).
    lo_c9->label( text = 'Gross Weight' ).
    lo_c9->input( value = io_ctx->bind( c_gross_weight_pop ) ).

*"Unit
    DATA(lo_c10) = lo_r2->vbox( class = 'rakCell' ).
    lo_c10->label( text = 'Unit' ).
    lo_c10->input( value = io_ctx->bind( c_unit_pop )  width = '5rem' ).

*"Invoice Number
    DATA(lo_c11) =  lo_r2->vbox( class = 'rakCell' ).
    lo_c11->label( text = 'Invoice Number' ).
    lo_c11->input( value = io_ctx->bind( c_invoice_pop ) ).

*"Importing Country
    DATA(lo_c12) = lo_r2->vbox( class = 'rakCell' ).
    lo_c12->label( text = 'Importing Country' ).
    lo_c12->input( value = io_ctx->bind( c_import_pop ) ).

*"Exit Port
    DATA(lo_c13)  = lo_r2->vbox( class = 'rakCell' ).
    lo_c13->label( text = 'Exit Port' ).
    lo_c13->input( value = io_ctx->bind( c_exit_port_pop  ) ).

*"Bill of lading
    DATA(lo_c14)  = lo_r2->vbox( class = 'rakCell' ).
    lo_c14->label( text = 'Bill of lading' ).
    lo_c14->input( value = io_ctx->bind( c_bol_pop ) ).

*"Transport Details
    DATA(lo_c15) =  lo_r2->vbox( class = 'rakCell' ).
    lo_c15->label( text = ' Transport Details' ).
    lo_c15->input( value = io_ctx->bind( c_tport_pop ) ).

* Add button on pop-up
    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = 'Add'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_ownok ) ).
* Close button on pop-up
    lo_b->button( text = 'Close' press = io_ctx->event( c_evt_owncx ) ).
  ENDMETHOD.


  METHOD chem_form_load.

    io_ctx->set_val( iv_name = c_HS_POP              iv_value = '' ).
    io_ctx->set_val( iv_name = c_mat_pop             iv_value = '' ).
    io_ctx->set_val( iv_name = c_chem_pop            iv_value = '' ).
    io_ctx->set_val( iv_name = c_cas_no_pop          iv_value = '' ).
    io_ctx->set_val( iv_name = c_chem_form_pop       iv_value = '' ).
    io_ctx->set_val( iv_name = c_packaging_pop       iv_value = '' ).
    io_ctx->set_val( iv_name = c_quantity_pop        iv_value = '' ).
    io_ctx->set_val( iv_name = c_gross_weight_pop    iv_value = '' ).
    io_ctx->set_val( iv_name = c_unit_pop            iv_value = '' ).
    io_ctx->set_val( iv_name = c_invoice_pop         iv_value = '' ).
    io_ctx->set_val( iv_name = c_import_pop          iv_value = '' ).
    io_ctx->set_val( iv_name = c_exit_port_pop       iv_value = '' ).
    io_ctx->set_val( iv_name = c_bol_pop             iv_value = '' ).
    io_ctx->set_val( iv_name = c_tport_pop           iv_value = '' ).

  ENDMETHOD.


  METHOD render_own_list.

*  "Get grid data - CHEMICALS_DETAILS
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

*  "Adding push button for pop - up
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

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
*      DATA(lv_id) = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_hs_no) = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_mat) = VALUE string( lt_r[ 2 ] OPTIONAL ).
      DATA(LV_chem) = VALUE string( lt_r[ 3 ] OPTIONAL ).
      DATA(lv_cas) = VALUE string( lt_r[ 4 ] OPTIONAL ).
      DATA(lv_w8t) =  VALUE string( lt_r[ 5 ] OPTIONAL ).

      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_hs_no ).
*      lo_nm->text( text = lv_eid class = 'rakRecMeta' ).
*      lo_cells->text( lv_hs_no ).
       lo_cells->text( lv_mat ).
      lo_cells->text( lv_chem ).
      lo_cells->text( lv_cas ).
      lo_cells->text( lv_w8t ).



      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = 'Edit owner details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_hs_no }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_hs_no }| ) ).

    ENDLOOP.

*       IF ls_g-rows IS INITIAL.
*      io_view->message_strip( text     = 'No owners yet. Press Add Owner to enter the first one.'
*                              type     = 'Information'
*                              showicon = abap_true
*                              class    = 'sapUiSmallMarginTop' ).
*    ENDIF.
  ENDMETHOD.


  METHOD validate_input.

    IF io_ctx->get_val( c_hs_pop )  IS INITIAL
             OR io_ctx->get_val( c_mat_pop ) IS INITIAL
             OR io_ctx->get_val( c_chem_pop ) IS INITIAL
             OR io_ctx->get_val( c_cas_no_pop ) IS INITIAL.
*             OR io_ctx->get_val( c_chem_form_pop ) IS INITIAL
*             OR io_ctx->get_val( c_packaging_pop ) IS INITIAL
*             OR io_ctx->get_val( c_quantity_pop ) IS INITIAL
*             OR io_ctx->get_val( c_gross_weight_pop ) IS INITIAL
*             OR io_ctx->get_val( c_unit_pop ) IS INITIAL
*             OR io_ctx->get_val( c_bol_pop ) IS INITIAL
*             OR io_ctx->get_val( c_exit_port_pop ) IS INITIAL
*             OR io_ctx->get_val( c_import_pop ) IS INITIAL
*             OR io_ctx->get_val( c_tport_pop ) IS INITIAL.


      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Kindly fill required details.' ).
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.
*    CALL METHOD super->zif_rak_journey_logic~on_render_end
*      EXPORTING
*        io_ctx  = io_ctx
*        io_view = io_view.

    IF io_ctx->get_step( ) = 2.
      render_own_list( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD populate_grid.
*  "Populate Chemicals Details grid with data

    DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).
    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.

    DATA(lv_hs_code) = condense( io_ctx->get_val( 'HS_CODE' ) ).
    DATA(lv_m_name) = condense( io_ctx->get_val( 'MATERIAL_NAME' ) ).
    DATA(lv_c_name) = condense( io_ctx->get_val( 'CHEMINAL_NAME' ) ).
    DATA(lv_cas) = condense( io_ctx->get_val( 'CAS_NO' ) ).
    DATA(lv_chem_form) = condense( io_ctx->get_val( 'CHEMICAL_FORMULA' ) ).
    DATA(lv_pack) = condense( io_ctx->get_val( 'PACKAGING' ) ).
    DATA(lv_qty) = condense( io_ctx->get_val( 'QUANTITY' ) ).
    DATA(lv_gw8t) = condense( io_ctx->get_val( 'GROSS_WEIGHT' ) ).
    DATA(lv_unit) = condense( io_ctx->get_val( 'UNIT' ) ).
    DATA(lv_inv) = condense( io_ctx->get_val( 'INVOICE_NO' ) ).
    DATA(lv_icoun)  = condense( io_ctx->get_val( 'IMP_CONT_POP' ) ).
    DATA(lv_exit) = condense( io_ctx->get_val( 'EXIT_POP' ) ).
    DATA(lv_bol) = condense( io_ctx->get_val( 'C_BOL_POP' ) ).
    DATA(lv_tport) = condense( io_ctx->get_val( 'TPORT_POP' ) ).


    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF lt_r IS NOT INITIAL.
        lv_found = abap_true.
        CLEAR lt_row.
        APPEND lv_hs_code TO lt_row.
        APPEND lv_m_name TO lt_row.
        APPEND lv_c_name TO lt_row.
        APPEND lv_cas  TO lt_row.
        APPEND lv_gw8t TO lt_row.
        APPEND lt_row TO ls_new-rows.
      ELSE.
        APPEND lt_row TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      CLEAR lt_row.
      APPEND lv_hs_code TO lt_row.
      APPEND lv_m_name TO lt_row.
      APPEND lv_c_name TO lt_row.
      APPEND lv_cas  TO lt_row.
      APPEND lv_gw8t TO lt_row.
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

  ENDMETHOD.


  METHOD own_edit.
*    "When user click on edit pencil for OWNER ROW they should be able
*    "to see existing details and edit it

    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).

      io_ctx->set_val( iv_name = c_hs_pop iv_value = VALUE #( lt_r[ 1 ] OPTIONAL ) ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
