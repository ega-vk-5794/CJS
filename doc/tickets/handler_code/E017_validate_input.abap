* E017  CJSMIG-687  ZCL_E017_NOC_EXP_CHEM_LOGIC
* Add Chemical: all fourteen fields enforced. Ten of the checks were commented out
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

  METHOD validate_input.

*   ALL FOURTEEN, mirroring the REQUIRED markers in ON_RENDER_POPUP( ).
*   Ten of these were commented out; CJSMIG-687 Issue 4 settled it.
    IF io_ctx->get_val( c_hs_pop ) IS INITIAL
             OR io_ctx->get_val( c_mat_pop ) IS INITIAL
             OR io_ctx->get_val( c_chem_pop ) IS INITIAL
             OR io_ctx->get_val( c_cas_no_pop ) IS INITIAL
             OR io_ctx->get_val( c_chem_form_pop ) IS INITIAL
             OR io_ctx->get_val( c_packaging_pop ) IS INITIAL
             OR io_ctx->get_val( c_quantity_pop ) IS INITIAL
             OR io_ctx->get_val( c_gross_weight_pop ) IS INITIAL
             OR io_ctx->get_val( c_unit_pop ) IS INITIAL
             OR io_ctx->get_val( c_bol_pop ) IS INITIAL
             OR io_ctx->get_val( c_exit_port_pop ) IS INITIAL
             OR io_ctx->get_val( c_import_pop ) IS INITIAL
             OR io_ctx->get_val( c_tport_pop ) IS INITIAL.


      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Kindly fill required details.' ).
*     RV_OK stays FALSE. This used to return nothing at all, and ON_POPUP_EVENT
*     called POPULATE_GRID( ) and CLOSE_POPUP( ) straight afterwards whatever
*     happened here - so a blank row was added to the grid and the dialog shut,
*     with only a warning toast to say otherwise. The verdict has to reach the
*     caller for the message to mean anything.
      RETURN.
    ENDIF.

    rv_ok = abap_true.

  ENDMETHOD.
