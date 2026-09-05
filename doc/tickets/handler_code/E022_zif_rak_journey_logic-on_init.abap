* E022  CJSMIG-684  ZCL_EPDA_E022_DEV_PROJ_LOGIC
* Applicant details were written twice on ON_INIT
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

  METHOD zif_rak_journey_logic~on_init.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .

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

*     WRITTEN ONCE. C_PARTNER_NAME is 'APP_NAME' and C_PARTNER_ID is
*     'APP_ID', and both were then written a SECOND time below this IF, under
*     a different language rule - so the two disagreed and the later one won.
*     The pair below the IF was also outside this guard, so a launch with no
*     login partner blanked the applicant's name and ID rather than leaving
*     them alone.
*
*     The rule kept is the one that degrades: an Arabic session with no
*     Arabic name on the partner record falls back to the English name
*     rather than showing an empty applicant.
      io_ctx->set_val( iv_name  = c_partner_name
                       iv_value = COND #( WHEN sy-langu <> c_lang_en AND ls_bp-bp_name_ar IS NOT INITIAL
                                          THEN CONV string( ls_bp-bp_name_ar )
                                          ELSE CONV string( ls_bp-bp_name ) ) ).

      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = c_partner_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
      io_ctx->set_val( iv_name = c_partner_email iv_value = CONV #( ls_bp-email_address ) ).


      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).

    ENDIF.


  ENDMETHOD.
