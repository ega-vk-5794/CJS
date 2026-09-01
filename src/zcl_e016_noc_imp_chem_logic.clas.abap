class ZCL_E016_NOC_IMP_CHEM_LOGIC definition
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
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
protected section.
private section.

  constants C_ROLE type STRING value 'APPLICANT_ROLE' ##NO_TEXT.
  constants C_PERMIT type STRING value 'PERMIT_HELD' ##NO_TEXT.
  constants C_GRID type STRING value 'CHEMICALS_DETAILS' ##NO_TEXT.
  constants C_EVT_DETAILS type STRING value 'ADD Details' ##NO_TEXT.
  constants C_HS_CODE_POP type STRING value 'HS_CODE_POP' ##NO_TEXT.
  constants C_MATERIAL_NAME_POP type STRING value 'MAT_NAME_POP' ##NO_TEXT.
  constants C_CHEMICAL_NAME_POP type STRING value 'CHEMICAL_NAME_POP' ##NO_TEXT.
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
  constants C_CHEM type STRING value 'CHEM' ##NO_TEXT.
  constants C_EVT_OWNOK type STRING value 'OWN_OK' ##NO_TEXT.
  constants C_EVT_OWNCX type STRING value 'OWN_CANCEL' ##NO_TEXT.
  constants C_OWN_ADD type STRING value 'OWNER_ADD' ##NO_TEXT.

  methods WRITE_FLAGS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods COMPANY_FIELDS
    returning
      value(RT) type ZIF_RAK_JOURNEY=>TT_STRING .
  methods RENDER_CHEM_DETAILS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_VIEW type ref to Z2UI5_CL_XML_VIEW .
  methods CHEM_FORM_LOAD
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
  methods RENDER_OWN_POPUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_POPUP type ref to Z2UI5_CL_XML_VIEW .
  methods FORM_SAVE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
ENDCLASS.



CLASS ZCL_E016_NOC_IMP_CHEM_LOGIC IMPLEMENTATION.


  method CHEM_FORM_LOAD.

    io_ctx->set_val( iv_name = c_HS_CODE_POP         iv_value = '' ).
    io_ctx->set_val( iv_name = C_MATERIAL_NAME_POP    iv_value = '' ).
    io_ctx->set_val( iv_name = C_CHEMICAL_NAME_POP    iv_value = '' ).
    io_ctx->set_val( iv_name = C_CAS_POP              iv_value = '' ).
    io_ctx->set_val( iv_name = C_CHEMICAL_FORMULA_POP iv_value = '' ).
    io_ctx->set_val( iv_name = C_PACKAGING_POP        iv_value = '' ).
    io_ctx->set_val( iv_name = C_QUANTITY_POP         iv_value = '' ).
    io_ctx->set_val( iv_name = C_GROSS_WEIGHT_POP     iv_value = '' ).
    io_ctx->set_val( iv_name = C_UOM_POP              iv_value = '' ).
    io_ctx->set_val( iv_name = C_INVOICE_POP          iv_value = '' ).
    io_ctx->set_val( iv_name = C_ORIGIN_POP           iv_value = '' ).
    io_ctx->set_val( iv_name = C_END_USER_POP         iv_value = '' ).
    io_ctx->set_val( iv_name = C_BOL_POP              iv_value = '' ).


    IF iv_id IS INITIAL.
*****     New owner. The id is minted NOW and not on save, because the uploaders in
*****     the dialog key their files on it - a file attached before the row exists
*****     still has to belong to the right person.
****      io_ctx->set_val( iv_name  = c_own_id
****                       iv_value = 'YFS002' ).
      RETURN.
    ENDIF.

**    io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).
    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).
      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) = iv_id.
      io_ctx->set_val( iv_name = c_HS_CODE_POP          iv_value = VALUE #( lt_r[ 2 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_MATERIAL_NAME_POP    iv_value = VALUE #( lt_r[ 3 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_CHEMICAL_NAME_POP    iv_value = VALUE #( lt_r[ 4 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_CAS_POP              iv_value = VALUE #( lt_r[ 5 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_CHEMICAL_FORMULA_POP iv_value = VALUE #( lt_r[ 6 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_PACKAGING_POP        iv_value = VALUE #( lt_r[ 7 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_QUANTITY_POP         iv_value = VALUE #( lt_r[ 8 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_GROSS_WEIGHT_POP     iv_value = VALUE #( lt_r[ 9 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_UOM_POP              iv_value = VALUE #( lt_r[ 10 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_INVOICE_POP          iv_value = VALUE #( lt_r[ 11 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_ORIGIN_POP           iv_value = VALUE #( lt_r[ 12 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_END_USER_POP         iv_value = VALUE #( lt_r[ 13 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = C_BOL_POP              iv_value = VALUE #( lt_r[ 14 ] OPTIONAL ) ).
      EXIT.
    ENDLOOP.

  endmethod.


  METHOD company_fields.
    rt = VALUE #(
      ( `COMPANY_NAME_EN` ) ( `COMPANY_NAME_AR` ) ( `CO_REG_EMIRATES` )
      ( `CO_ADDRESS` )      ( `CO_TRADE_LICENSE` ) ( `CO_MOBILE` )
      ( `CO_TELEPHONE` )    ( `CO_EMAIL` ) ).
  ENDMETHOD.


  method RENDER_CHEM_DETAILS.
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

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
      DATA(lv_hs_code)  = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_material_name) = VALUE string( lt_r[ 2 ] OPTIONAL ).
      DATA(lv_chem_name) = VALUE string( lt_r[ 3 ] OPTIONAL ).
      DATA(lv_cas_number) = VALUE string( lt_r[ 4 ] OPTIONAL ).
      DATA(lv_gross_weight) = VALUE string( lt_r[ 7 ] OPTIONAL ).

*     How many files this owner has. Counting them here is the only way the
*     citizen can see, from the list, whose documents are still missing.
**      DATA lv_docs TYPE i.
**      CLEAR lv_docs.
**      LOOP AT io_ctx->get_attachment_files( ) INTO DATA(ls_af).
**        IF ls_af-identifier1 CS |_{ lv_id }|.
**          lv_docs = lv_docs + 1.
**        ENDIF.
**      ENDLOOP.

      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
*     Name over Emirates ID, as the legacy screen had it.
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_hs_code ).
**      lo_nm->text( text = lv_chem_name class = 'rakRecMeta' ).
      lo_cells->text( lv_material_name ).
      lo_cells->text( lv_chem_name ).
      lo_cells->text( lv_cas_number ).
      lo_cells->text( lv_gross_weight ).
**      lo_cells->object_status(
**        text  = |{ lv_docs } file(s)|
**        state = COND #( WHEN lv_docs > 0 THEN 'Success' ELSE 'Warning' )
**        icon  = COND #( WHEN lv_docs > 0 THEN 'sap-icon://attachment' ELSE 'sap-icon://alert' ) ).
*     Two buttons rather than the legacy overflow menu: one press instead of
*     two, and nothing hidden behind an icon a citizen has to discover.
      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = 'Edit owner details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_hs_code }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_hs_code }| ) ).
    ENDLOOP.

    IF ls_g-rows IS INITIAL.
      io_view->message_strip( text     = 'No owners yet. Press Add Owner to enter the first one.'
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiSmallMarginTop' ).
    ENDIF.
  endmethod.


  METHOD render_own_popup.
**    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = 'Chemical Details' contentwidth = '55rem' ).
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
    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c1) = lo_r1->vbox( class = 'rakCell' ).
    lo_c1->label( text = 'HS Code' class = 'rakReq' ).
    lo_c1->input( value = io_ctx->bind( C_HS_CODE_POP ) width = '17rem' ).
     DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).
    lo_c2->label( text = 'Material Name' ).
    lo_c2->input( value = io_ctx->bind( C_MATERIAL_NAME_POP ) width = '17rem' ).
    DATA(lo_c3) = lo_r1->vbox( class = 'rakCell' ).
    lo_c3->label( text = 'Chemical Name' ).
    lo_c3->input( value = io_ctx->bind( C_CHEMICAL_NAME_POP ) width = '17rem' ).

    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
    lo_c4->label( text = 'CAS Number' ).
    lo_c4->input( value = io_ctx->bind( C_CAS_POP ) width = '17rem' ).
    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
    lo_c5->label( text = 'Chemical formula' ).
    lo_c5->input( value = io_ctx->bind( C_CHEMICAL_FORMULA_POP ) width = '17rem' ).
    DATA(lo_c6) = lo_r2->vbox( class = 'rakCell' ).
    lo_c6->label( text = 'Packing' class = 'rakReq' ).
    lo_c6->input( value = io_ctx->bind( C_PACKAGING_POP ) width = '17rem' ).
    DATA(lo_c7) = lo_r2->vbox( class = 'rakCell' ).
    lo_c7->label( text = 'Quantity' class = 'rakReq' ).
    lo_c7->input( value = io_ctx->bind( C_QUANTITY_POP ) type = 'Number' width = '17rem' ).
    DATA(lo_c8) = lo_r2->vbox( class = 'rakCell' ).
    lo_c8->label( text = 'Gross Weight' class = 'rakReq' ).
    lo_c8->input( value = io_ctx->bind( C_GROSS_WEIGHT_POP ) type = 'Number' width = '17rem' ).
    DATA(lo_c9) = lo_r2->vbox( class = 'rakCell' ).
    lo_c9->label( text = 'UOM' class = 'rakReq' ).
    lo_c9->input( value = io_ctx->bind( C_UOM_POP ) type = 'SELECT' width = '17rem' ).
    DATA(lo_c10) = lo_r2->vbox( class = 'rakCell' ).
    lo_c10->label( text = 'Invoice Number' class = 'rakReq' ).
    lo_c10->input( value = io_ctx->bind( C_INVOICE_POP ) width = '17rem' ).
    DATA(lo_c11) = lo_r2->vbox( class = 'rakCell' ).
    lo_c11->label( text = 'Country of Origin' class = 'rakReq' ).
    lo_c11->input( value = io_ctx->bind( C_ORIGIN_POP ) width = '17rem' ).
    DATA(lo_c12) = lo_r2->vbox( class = 'rakCell' ).
    lo_c12->label( text = 'Point of Entrance/End User' class = 'rakReq' ).
    lo_c12->input( value = io_ctx->bind( C_END_USER_POP ) width = '17rem' ).
    DATA(lo_c13) = lo_r2->vbox( class = 'rakCell' ).
    lo_c13->label( text = 'Bill of Lading' class = 'rakReq' ).
    lo_c13->input( value = io_ctx->bind( C_BOL_POP ) width = '17rem' ).

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
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

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

      WHEN c_evt_ownok.
        form_save( io_ctx ).
        io_ctx->close_popup( ).

    ENDCASE.

    CASE iv_event(8).
      WHEN 'OWN_EDIT'.
        DATA(lv_id) = iv_event+9.
        CALL METHOD chem_form_load
          EXPORTING
            io_ctx = io_ctx
            iv_id  = lv_id.
        io_ctx->open_popup( c_chem ).
       WHEN 'OWN_DEL_'.
         lv_id = iv_event+8.
         DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).
         LOOP AT ls_g-rows INTO DATA(lt_r).
           IF VALUE string( lt_r[ 1 ] OPTIONAL ) = lv_id.
             data(lv_index) = sy-tabix.
             ENDIF.
           ENDLOOP.
           IF lv_index is NOT INITIAL.
           delete ls_g-rows INDEX lv_index.
            io_ctx->set_grid_data( iv_field = c_grid is_data = ls_g ).
            endif.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.
    CALL METHOD super->zif_rak_journey_logic~on_render_end
      EXPORTING
        io_ctx  = io_ctx
        io_view = io_view.

     IF io_ctx->get_step( ) = 2.
      render_chem_details( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP.
super->zif_rak_journey_logic~on_render_popup(
      io_ctx   = io_ctx
      io_popup = io_popup
      iv_id    = iv_id
    ).

**    CHECK iv_id = c_pop_mat.
    CASE iv_id.
      when C_CHEM.
**      render_own_popup( io_ctx = io_ctx io_popup = io_popup ).


        dialog_form(
          io_ctx     = io_ctx
          io_popup   = io_popup
          iv_title   = 'Add Chemical'
          it_fields  = VALUE #(
                                ( name = c_hs_code_pop          label = 'HS Code'  )
                                ( name = c_material_name_pop    label = 'Material Name' )
                                ( name = c_chemical_name_pop    label = 'Chemical Name' )
                                ( name = c_cas_pop              label = 'CAS Number' maxlen = 20 )
                                ( name = c_chemical_formula_pop label = 'Chemical Formula' )
                                ( name = c_packaging_pop        label = 'Packing' )
                                ( name = c_quantity_pop         label = 'Quantity'  )
                                ( name = c_gross_weight_pop     label = 'Gross Weight'  )
                                ( name = c_uom_pop              label = 'UOM' type = 'SELECT'
                                  options = VALUE #( ( key = 'GAL' text = 'Gallon' )
                                                     ( key = 'KG'  text = 'Kilogram' )
                                                     ( key = 'LIT' text = 'Liter' )
                                                     ( key = 'MAT' text = 'Metric Ton' ) ) )

                                ( name = c_invoice_pop          label = 'Invoice Number'  )
                                ( name = c_origin_pop           label = 'Country of Origin' shlp = 'H_T005'  )
                                ( name = c_end_user_pop         label = 'Point of Entrance'  )
                                ( name = c_bol_pop              label = 'Bill of Lading'  )
**                                ( name = c_trans_comp           label = 'Transport Company'  )
                              )
          iv_ok_text = 'Add'
          iv_ok_evt  = c_evt_ownok
          iv_cxl_evt = c_evt_owncx ).
        RETURN.
      RETURN.
      WHEN C_EVT_DETAILS.


        dialog_form(
          io_ctx     = io_ctx
          io_popup   = io_popup
          iv_title   = 'Add Chemical'
          it_fields  = VALUE #(
                                ( name = 'C_HS_CODE_POP'        label = 'HS Code'  )
                                ( name = 'C_MATERIAL_NAME_POP'  label = 'Material Name' )
                                ( name = 'C_CHEMICAL_NAME_POP'  label = 'Chemical Name' )
                                ( name = 'C_CAS_POP'            label = 'CAS Number' )
                                ( name = 'C_CHEMICAL_FORMULA_POP'     label = 'Chemical Formula' )
                                ( name = 'C_PACKAGING_POP'          label = 'Packing' )
                                ( name = 'C_QUANTITY_POP'        label = 'Quantity'  )
                                ( name = 'C_GROSS_WEIGHT_POP'        label = 'Gross Weight'  )
                                ( name = 'C_UOM_POP'        label = 'UOM'  )
                                ( name = 'C_INVOICE_POP'        label = 'Invoice Number'  )
                                ( name = 'C_ORIGIN_POP'        label = 'Country of Origin'  )
                                ( name = 'C_END_USER_POP'        label = 'Point of Entrance/End User'  )
                                ( name = 'C_BOL_POP'        label = 'Bill of Lading'  )
*                                ( name = 'DATE_OF_BIRTH_POP' label = 'Date of Birth' )
*                                ( name = 'DATE_OF_BIRTH_POP' label = 'Date of Birth' )
                                 )
          iv_ok_text = 'Add'
          iv_ok_evt  = c_own_add ).

      WHEN OTHERS.
    ENDCASE.
  endmethod.


  METHOD form_save.
    DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).
    DATA(lv_id) = io_ctx->get_val( c_hs_code_pop ).

    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF VALUE string( lt_r[ 1 ] OPTIONAL ) = lv_id.
      lv_found = abap_true.
      CLEAR lt_row.
*        APPEND lv_id                                      TO lt_row.
      APPEND io_ctx->get_val( c_hs_code_pop )           TO lt_row.
      APPEND io_ctx->get_val( c_material_name_pop )     TO lt_row.
      APPEND io_ctx->get_val( c_chemical_name_pop )     TO lt_row.
      APPEND io_ctx->get_val( c_cas_pop )               TO lt_row.
      APPEND io_ctx->get_val( c_chemical_formula_pop )  TO lt_row.
      APPEND io_ctx->get_val( c_packaging_pop )         TO lt_row.
      APPEND io_ctx->get_val( c_gross_weight_pop )      TO lt_row.
      APPEND io_ctx->get_val( c_uom_pop )               TO lt_row.
      APPEND io_ctx->get_val( c_quantity_pop )          TO lt_row.
      APPEND io_ctx->get_val( c_invoice_pop )           TO lt_row.
      APPEND io_ctx->get_val( c_origin_pop )            TO lt_row.
      APPEND io_ctx->get_val( c_end_user_pop )          TO lt_row.
      APPEND io_ctx->get_val( c_bol_pop )               TO lt_row.
      APPEND lt_row TO ls_new-rows.
      ELSE.
        APPEND lt_r TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      CLEAR lt_row.
      APPEND io_ctx->get_val( c_hs_code_pop )           TO lt_row.
      APPEND io_ctx->get_val( c_material_name_pop )     TO lt_row.
      APPEND io_ctx->get_val( c_chemical_name_pop )     TO lt_row.
      APPEND io_ctx->get_val( c_cas_pop )               TO lt_row.
      APPEND io_ctx->get_val( c_chemical_formula_pop )  TO lt_row.
      APPEND io_ctx->get_val( c_packaging_pop )         TO lt_row.
      APPEND io_ctx->get_val( c_gross_weight_pop )      TO lt_row.
      APPEND io_ctx->get_val( c_uom_pop )               TO lt_row.
      APPEND io_ctx->get_val( c_quantity_pop )          TO lt_row.
      APPEND io_ctx->get_val( c_invoice_pop )           TO lt_row.
      APPEND io_ctx->get_val( c_origin_pop )            TO lt_row.
      APPEND io_ctx->get_val( c_end_user_pop )          TO lt_row.
      APPEND io_ctx->get_val( c_bol_pop )               TO lt_row.
      APPEND lt_row TO ls_new-rows.
    ENDIF.

    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.
CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
  EXPORTING
    IO_CTX   = IO_CTX
    IV_FIELD = IV_FIELD
    .

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
  endmethod.
ENDCLASS.
