*"* use this source file for your ABAP unit test classes
CLASS ltcl_zcl_rak_be_factory DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      resolves_local_backend           FOR TESTING,
      resolves_local_case_insensitive  FOR TESTING,
      resolves_not_backend_rest        FOR TESTING,
      resolves_not_backend_notary      FOR TESTING,
      resolves_not_backend_not         FOR TESTING,
      unknown_category_returns_unbound FOR TESTING.

ENDCLASS.


CLASS ltcl_zcl_rak_be_factory IMPLEMENTATION.

  METHOD resolves_local_backend.
    DATA ls_config TYPE zif_rak_journey=>ty_config.
    ls_config-backend-category = 'LOCAL'.
    ls_config-backend-journey  = 'JOURNEY_LOCAL'.

    DATA(lo_backend) = zcl_rak_be_factory=>get( ls_config ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_backend
      msg = 'LOCAL category must return a bound backend instance' ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_backend )->get_relative_name( )
      exp = 'ZCL_RAK_BE_LOCAL'
      msg = 'LOCAL category must resolve to ZCL_RAK_BE_LOCAL' ).
  ENDMETHOD.

  METHOD resolves_local_case_insensitive.
    DATA ls_config TYPE zif_rak_journey=>ty_config.
    ls_config-backend-category = 'local'.
    ls_config-backend-journey  = 'JOURNEY_LOCAL'.

    DATA(lo_backend) = zcl_rak_be_factory=>get( ls_config ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_backend )->get_relative_name( )
      exp = 'ZCL_RAK_BE_LOCAL'
      msg = 'Category resolution must be case-insensitive' ).
  ENDMETHOD.

  METHOD resolves_not_backend_rest.
    DATA ls_config TYPE zif_rak_journey=>ty_config.
    ls_config-backend-category    = 'REST'.
    ls_config-backend-journey     = 'JOURNEY_REST'.
    ls_config-backend-loginbp_dev = 'BP0001'.

    DATA(lo_backend) = zcl_rak_be_factory=>get( ls_config ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_backend )->get_relative_name( )
      exp = 'ZCL_RAK_BE_NOT'
      msg = 'REST category must resolve to ZCL_RAK_BE_NOT' ).
  ENDMETHOD.

  METHOD resolves_not_backend_notary.
    DATA ls_config TYPE zif_rak_journey=>ty_config.
    ls_config-backend-category = 'NOTARY'.
    ls_config-backend-journey  = 'JOURNEY_NOTARY'.

    DATA(lo_backend) = zcl_rak_be_factory=>get( ls_config ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_backend )->get_relative_name( )
      exp = 'ZCL_RAK_BE_NOT'
      msg = 'NOTARY category must resolve to ZCL_RAK_BE_NOT' ).
  ENDMETHOD.

  METHOD resolves_not_backend_not.
    DATA ls_config TYPE zif_rak_journey=>ty_config.
    ls_config-backend-category = 'NOT'.
    ls_config-backend-journey  = 'JOURNEY_NOT'.

    DATA(lo_backend) = zcl_rak_be_factory=>get( ls_config ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_backend )->get_relative_name( )
      exp = 'ZCL_RAK_BE_NOT'
      msg = 'NOT category must resolve to ZCL_RAK_BE_NOT' ).
  ENDMETHOD.

  METHOD unknown_category_returns_unbound.
    DATA ls_config TYPE zif_rak_journey=>ty_config.
    ls_config-backend-category = 'BOGUS'.

    DATA(lo_backend) = zcl_rak_be_factory=>get( ls_config ).

    cl_abap_unit_assert=>assert_not_bound(
      act = lo_backend
      msg = 'An unrecognised category must not return a bound backend' ).
  ENDMETHOD.

ENDCLASS.
