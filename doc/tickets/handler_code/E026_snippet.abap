* E026  CJSMIG-704  ZCL_E026_TREE_REMOVAL_LOGIC
* Applicant BP never reached LOGIN_BP
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

* --- private section: add, leave C_LOGIN_BP exactly as it is ---------
  constants C_APP_BP type STRING value 'LOGIN_BP' ##NO_TEXT.

* --- ZIF_RAK_JOURNEY_LOGIC~ON_INIT, straight after the existing line --
    io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).
    io_ctx->set_val( iv_name = c_app_bp   iv_value = |{ lv_loginbp }| ).
