* E025  CJSMIG-703  ZCL_E025_BEEKEEPING_LOGIC
* Applicant BP was written to the owner SEARCH field and then blanked
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

* --- private section: the constant named the wrong field ------------
*   was:  constants C_LOGIN_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.

* --- ZIF_RAK_JOURNEY_LOGIC~ON_INIT, last line inside the IF -----------
*   was:  io_ctx->set_val( iv_name = 'OWNER_BP' iv_value = ' ' ).
*   'OWNER_BP' is the owner search box (see ON_SEARCH), not the applicant.
  io_ctx->set_val( iv_name = c_owner_bp iv_value = ' ' ).
