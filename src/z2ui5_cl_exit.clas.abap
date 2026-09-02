CLASS z2ui5_cl_exit DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_exit.

    CLASS-METHODS init_context
      IMPORTING
        http_info TYPE z2ui5_cl_util_http=>ty_s_http_req.

    CLASS-METHODS get_instance
      RETURNING
        VALUE(ri_exit) TYPE REF TO z2ui5_if_exit.

    CLASS-METHODS get_user_exit_class
      RETURNING
        VALUE(r_class_name) TYPE string.

  PROTECTED SECTION.
    CLASS-DATA gi_me        TYPE REF TO z2ui5_if_exit.
    CLASS-DATA gi_user_exit TYPE REF TO z2ui5_if_exit.
    CLASS-DATA context      TYPE z2ui5_if_types=>ty_s_http_context.

  PRIVATE SECTION.
*   The browser tab title for EVERY page this framework renders - the
*   Studio and every citizen-facing journey alike - used to be the fixed
*   literal `abap2UI5`, the framework's own name, on every single one of
*   them. Contextual instead: a citizen's tab now names the journey they
*   are actually on, the way any other government e-service does.
    METHODS contextual_title
      IMPORTING is_context    TYPE z2ui5_if_types=>ty_s_http_context
      RETURNING VALUE(rv)     TYPE string.

    METHODS param_value
      IMPORTING it_params     TYPE z2ui5_if_types=>ty_t_name_value
                iv_name       TYPE string
      RETURNING VALUE(rv)     TYPE string.
ENDCLASS.


CLASS z2ui5_cl_exit IMPLEMENTATION.

  METHOD get_instance.

    IF gi_me IS BOUND.
      ri_exit = gi_me.
      RETURN.
    ENDIF.

    DATA(lv_class_name) = get_user_exit_class( ).

    IF lv_class_name IS NOT INITIAL.
      TRY.
          CREATE OBJECT gi_user_exit TYPE (lv_class_name).
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.

    gi_me = NEW z2ui5_cl_exit( ).
    ri_exit = gi_me.

  ENDMETHOD.

  METHOD get_user_exit_class.

    TRY.
        DATA(exit_classes) = z2ui5_cl_util=>rtti_get_classes_impl_intf( `Z2UI5_IF_EXIT` ).
        DELETE exit_classes WHERE classname = `Z2UI5_CL_EXIT`.

        r_class_name = VALUE #( exit_classes[ 1 ]-classname OPTIONAL ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.

  METHOD z2ui5_if_exit~set_config_http_get.

    cs_config-title = contextual_title( is_context ).
    cs_config-theme = `sap_horizon`.

    cs_config-src = `https://sdk.openui5.org/resources/sap-ui-cachebuster/sap-ui-core.js`.

    " since 21.11.2025 without unsafe-eval
    cs_config-content_security_policy =
      |<meta http-equiv="Content-Security-Policy" | &&
      |content="default-src 'self' 'unsafe-inline' data: | &&
      |ui5.sap.com *.ui5.sap.com | &&
      |sapui5.hana.ondemand.com *.sapui5.hana.ondemand.com | &&
      |openui5.hana.ondemand.com *.openui5.hana.ondemand.com | &&
      |sdk.openui5.org *.sdk.openui5.org | &&
      |cdn.jsdelivr.net *.cdn.jsdelivr.net | &&
      |cdnjs.cloudflare.com *.cdnjs.cloudflare.com schemas *.schemas | &&
*     THE ARCGIS API AND THE RAK HOSTS. util/Map.js in the ShapeIt app
*     renders the parcel map with the ArcGIS JS API loaded INTO the
*     application page - it is not a framed site - so the script, its
*     stylesheet, its fonts and its map tiles all have to be reachable
*     from here or the map is a grey rectangle with nothing in the
*     console but a CSP violation. Both hosts are named because a RAK
*     system may serve the API from its own portal rather than the CDN.
*
*     BLOB: is for the API's web workers, which it uses for tile
*     decoding; WORKER-SRC below already allows it and this keeps the
*     DEFAULT-SRC fallback from refusing them first.
      |js.arcgis.com *.arcgis.com *.arcgisonline.com | &&
      |*.rak.ae blob:; | &&
      |connect-src 'self' | &&
      |  ui5.sap.com *.ui5.sap.com | &&
      |  sapui5.hana.ondemand.com *.sapui5.hana.ondemand.com | &&
      |  openui5.hana.ondemand.com *.openui5.hana.ondemand.com | &&
      |  sdk.openui5.org *.sdk.openui5.org | &&
      |  cdn.jsdelivr.net *.cdn.jsdelivr.net | &&
      |  cdnjs.cloudflare.com *.cdnjs.cloudflare.com | &&
*     CONNECT-SRC is the one the map cannot do without: every feature
*     query, every token check and every tile request is an XHR to the
*     RAK GIS server or to ArcGIS's own services.
      |  js.arcgis.com *.arcgis.com *.arcgisonline.com | &&
      |  *.rak.ae; | &&
*     FRAME-SRC, or the parcel map is a grey rectangle. The Property
*     Details dialog embeds the RAK GIS viewer, and with no frame-src of
*     its own the browser falls back to DEFAULT-SRC - which lists this
*     host and the UI5 CDNs and nothing else, so the frame is refused:
*
*       Framing 'https://rakgisstg.rak.ae/' violates the following
*       Content Security Policy directive: "default-src 'self' ..."
*       Note that 'frame-src' was not explicitly set, so 'default-src'
*       is used as a fallback.
*
*     Named as a WILDCARD over rak.ae rather than the one staging host,
*     because the GIS viewer is a different hostname per environment
*     (rakgisstg / rakgis) and a CSP that has to be edited per system is
*     a CSP that will be wrong in one of them. The widening is contained:
*     FRAME-SRC grants nothing but the right to embed - no script, no
*     connect, no style - and the framed document brings its own policy.
      |frame-src 'self' https://*.rak.ae; | &&
      |worker-src 'self' blob:; "/>|.

    cs_config-t_security_header = VALUE #(
        ( n = `cache-control`          v = `no-cache, no-store, must-revalidate` )
        ( n = `Pragma`                 v = `no-cache` )
        ( n = `Expires`                v = `0` )
        ( n = `X-Content-Type-Options` v = `nosniff` )
        ( n = `X-Frame-Options`        v = `SAMEORIGIN` )
        ( n = `Referrer-Policy`        v = `strict-origin-when-cross-origin` )
        ( n = `Permissions-Policy`     v = `geolocation=(self), microphone=(self), camera=(self), payment=(), usb=()` ) ).

    IF gi_user_exit IS BOUND.
      gi_user_exit->set_config_http_get( EXPORTING is_context = context
                                         CHANGING  cs_config  = cs_config ).
    ENDIF.

  ENDMETHOD.

  METHOD z2ui5_if_exit~set_config_http_post.

    cs_config-draft_exp_time_in_hours = 4.

    IF gi_user_exit IS BOUND.
      gi_user_exit->set_config_http_post( EXPORTING is_context = context
                                          CHANGING  cs_config  = cs_config ).
    ENDIF.

    IF cs_config-draft_exp_time_in_hours <= 0.
      cs_config-draft_exp_time_in_hours = 4.
    ENDIF.

  ENDMETHOD.

  METHOD init_context.

    context = CORRESPONDING #( http_info ).
    context-app_start = VALUE #( http_info-t_params[ n = `app_start` ]-v OPTIONAL ).

  ENDMETHOD.


  METHOD param_value.
    rv = VALUE #( it_params[ n = iv_name ]-v OPTIONAL ).
  ENDMETHOD.


  METHOD contextual_title.
    DATA(lv_journey) = to_upper( param_value( it_params = is_context-t_params iv_name = `journey` ) ).

    IF lv_journey IS INITIAL.
*     No JOURNEY param on this URL - not a citizen-facing journey. Studio
*     gets its own label; anything else this framework hosts (a demo app,
*     the startup tutorial) gets the generic one - neither shows the
*     framework's own name any more.
      rv = COND #( WHEN to_upper( is_context-app_start ) = `ZCL_RAK_CJS`
                   THEN `CJS Studio` ELSE `CJS` ).
      RETURN.
    ENDIF.

*   Same param name and precedence ZCL_RAK_JOURNEY_ENGINE~READ_PARAMS
*   itself resolves language by (LANG on the URL, SY-LANGU when absent) -
*   this hook runs before that engine instance exists, so it re-reads the
*   same raw query string rather than depending on it.
    DATA(lv_lang) = to_upper( param_value( it_params = is_context-t_params iv_name = `lang` ) ).
    IF lv_lang <> `A`.
      lv_lang = sy-langu.
    ENDIF.

    SELECT SINGLE title, title_ar FROM zrak_t_jny
      WHERE journey_id = @lv_journey
      INTO @DATA(ls_jny).

    rv = COND #( WHEN lv_lang = `A` AND ls_jny-title_ar IS NOT INITIAL THEN ls_jny-title_ar
                 WHEN ls_jny-title IS NOT INITIAL THEN ls_jny-title
                 ELSE `CJS` ).
  ENDMETHOD.

ENDCLASS.
