CLASS zcl_rak_be_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS get
      IMPORTING is_config        TYPE zif_rak_journey=>ty_config
      RETURNING VALUE(ro_backend) TYPE REF TO zif_rak_journey_backend.

  PRIVATE SECTION.

    CLASS-METHODS resolve_type
      IMPORTING is_config      TYPE zif_rak_journey=>ty_config
      RETURNING VALUE(rv_type) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_BE_FACTORY IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_RAK_BE_FACTORY=>GET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_CONFIG                      TYPE        ZIF_RAK_JOURNEY=>TY_CONFIG
* | [<-()] RO_BACKEND                     TYPE REF TO ZIF_RAK_JOURNEY_BACKEND
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get.

    DATA(lv_type) = resolve_type( is_config ).

    CASE lv_type.
      WHEN 'REST' OR 'NOTARY' OR 'NOT'.
        ro_backend = NEW zcl_rak_be_not( iv_subservice = is_config-backend-journey
                                         iv_loginbp    = is_config-backend-loginbp_dev
                                         iv_userdata   = is_config-backend-userdata ).

      WHEN 'LOCAL'.
        ro_backend = NEW zcl_rak_be_local( iv_journey = is_config-backend-journey ).

      WHEN OTHERS.
        CLEAR ro_backend.
    ENDCASE.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Private Method ZCL_RAK_BE_FACTORY=>RESOLVE_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_CONFIG                      TYPE        ZIF_RAK_JOURNEY=>TY_CONFIG
* | [<-()] RV_TYPE                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD resolve_type.
    rv_type = to_upper( is_config-backend-category ).
  ENDMETHOD.
ENDCLASS.