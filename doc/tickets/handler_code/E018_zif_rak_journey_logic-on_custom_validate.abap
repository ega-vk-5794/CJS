* E018  CJSMIG-697  ZCL_E018_NOC_TRANS_CHEM_LOGIC
* Same role-flag fix as E017
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

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
