CLASS zcl_rak_d001_pay DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PROTECTED SECTION.
    METHODS prepare_payment REDEFINITION.

ENDCLASS.



CLASS ZCL_RAK_D001_PAY IMPLEMENTATION.


  METHOD prepare_payment.
    DATA ls_method TYPE zcl_rak_pay_engine=>ty_method.
    pay_engine( io_ctx )->persist_method( ls_method ).

    DATA lt_def TYPE /qnv/sbuild_definition_tt.
    lt_def = VALUE #( ( technicalname = 'REFERENCEID' )
                      ( technicalname = 'APPLICATIONURL' ) ).

    NEW zcl_rak_cpg_adapter( )->fill(
      EXPORTING
        case_key = CONV #( io_ctx->get_case( ) )
        etisalat = abap_true
      CHANGING
        ct_definition = lt_def ).

    io_ctx->set_val( iv_name  = 'PAY_REFERENCE'
                     iv_value = VALUE #( lt_def[ technicalname = 'REFERENCEID' ]-value OPTIONAL ) ).
    io_ctx->set_val( iv_name  = 'PAY_APPURL'
                     iv_value = VALUE #( lt_def[ technicalname = 'APPLICATIONURL' ]-value OPTIONAL ) ).
  ENDMETHOD.
ENDCLASS.
