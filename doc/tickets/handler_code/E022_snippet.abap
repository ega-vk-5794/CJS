* E022 E026 E027 D021 D014gv  CJSMIG-684 / 704  six classes - see the code
* The applicant's own partner never reached LOGIN_BP, the field every other journey and the record model use. Additive: the existing OWNER_BP write is left alone, so nothing that works today changes
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

* Applies to ZCL_EPDA_E022_DEV_PROJ_LOGIC, ZCL_E026_TREE_REMOVAL_LOGIC,
* ZCL_E027_VICE_CAPTAIN_LOGIC, ZCL_D021_MOD_SCHOOL_FEE_LOGIC and
* ZCL_D014_STAFF_GOLD_VISA_LOGIC - all five declare C_LOGIN_BP as 'OWNER_BP'.
* E025 is the exception and has its own row above: there OWNER_BP is the owner
* SEARCH box, so the constant itself has to be corrected, not added to.

* --- private section: ADD this. Leave C_LOGIN_BP exactly as it is. ----
  constants C_APP_BP type STRING value 'LOGIN_BP' ##NO_TEXT.

* --- ON_INIT: ADD the second line under the existing first one. -------
    io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).
    io_ctx->set_val( iv_name = c_app_bp   iv_value = |{ lv_loginbp }| ).
