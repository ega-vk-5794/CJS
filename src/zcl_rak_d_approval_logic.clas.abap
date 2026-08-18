*&---------------------------------------------------------------------*
*& ZCL_RAK_D_APPROVAL_LOGIC
*&
*& Journey logic for NOT_APPROVAL (Declaration of Approval & Signature).
*& Inherits the default (empty) implementations from ZCL_RAK_JOURNEY_LOGIC
*& and overrides only on_init.
*&
*& Bind via the journey config column HANDLER_CLASS =
*&   'ZCL_RAK_D_APPROVAL_LOGIC'
*&
*& on_init seeds the applicant context Create Draft requires
*& (applicantCategoryId / applicantName / applicantBusinessPartnerId).
*& Hardcoded here as a placeholder; in production these resolve from the
*& RAK Digital portal session (loginbp / userdata launch params).
*&---------------------------------------------------------------------*

CLASS zcl_rak_d_approval_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_init REDEFINITION.

ENDCLASS.



CLASS ZCL_RAK_D_APPROVAL_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.

    " Applicant context for Create Draft.
    " Category 1 = Individual (citizen submitting their own declaration).
    " TODO(RAK Digital): resolve from portal session instead of hardcode:
    "   loginbp  = io_ctx->get_param( 'loginbp' )   -> applicantBusinessPartnerId
    "   userdata = io_ctx->get_param( 'userdata' )  -> applicantName / category
    io_ctx->set_val( iv_name = 'applicantCategoryId'        iv_value = '1' ).
    io_ctx->set_val( iv_name = 'applicantName'              iv_value = 'Portal Applicant' ).
    io_ctx->set_val( iv_name = 'applicantBusinessPartnerId' iv_value = '1000000226' ).

  ENDMETHOD.
ENDCLASS.
