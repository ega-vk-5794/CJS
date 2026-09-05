* E018  CJSMIG-697  ZCL_E018_NOC_TRANS_CHEM_LOGIC
* Add Chemical: all fourteen enforced on OK, and the dialog stays open when one fails
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

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
