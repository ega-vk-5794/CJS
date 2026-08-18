CLASS zcl_rak_cpg_adapter DEFINITION
  PUBLIC
  INHERITING FROM zcl_ega_rd_core_functions
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS fill
      IMPORTING case_key       TYPE scmg_ext_key
                invoice_number TYPE char35   DEFAULT ''
                etisalat       TYPE boolean  DEFAULT abap_false
      CHANGING  ct_definition  TYPE /qnv/sbuild_definition_tt.
ENDCLASS.



CLASS ZCL_RAK_CPG_ADAPTER IMPLEMENTATION.


  METHOD fill.
    get_cpg_details(
      EXPORTING
        case_key       = case_key
        invoice_number = invoice_number
        etisalat       = etisalat
      CHANGING
        ct_definition  = ct_definition ).
  ENDMETHOD.
ENDCLASS.
