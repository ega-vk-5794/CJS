*&---------------------------------------------------------------------*
*& Report ZRAK_CJ_MAP_DIAG
*&
*& BUILD map-fix-6.  IF THIS LINE IS NOT ON YOUR SCREEN, SAP HAS AN OLDER
*& COPY and the errors you are looking at were fixed in git. abapGit's
*& pull dialog pre-ticks only 'Add local object' rows; every 'Overwrite
*& local object' row arrives UNTICKED and the ticks reset each time the
*& dialog opens - so an object that already exists is skipped unless it is
*& ticked by hand, and the pull still reports success.
*&
*& map-fix-4 contains: MapUrlSet read BY SHAPE rather than by column name
*& (URL holds the token, GISURL the viewer page, TOKEN is empty), the
*& ArcGIS roots probed alongside the viewer path, and a refused connection
*& reported as what it is - a limit on THIS REPORT, not on the map.
*&---------------------------------------------------------------------*
* THE MAP HAS FAILED SEVEN TIMES AND EVERY ATTEMPT WAS A GUESS. This
* report stops guessing. It prints what MapUrlSet actually answers, then
* ASKS THE GIS SERVER what it is and what it holds.
*
* Why that closes it: ArcGIS Server and ArcGIS Portal both publish a REST
* directory. Given a base URL and a token, /rest/info says what kind of
* endpoint it is, /rest/services lists every folder and service, a
* FeatureServer says which layers it has, and a layer says which FIELDS
* it has. So the two values util/Map.js takes from the ShapeIt app's own
* configuration - the parcel and property feature layers, which are in
* the UI5 repository and in no service CJS can read - are DISCOVERABLE
* from the same token the map already gets.
*
* WHAT EACH SECTION SETTLES
*
*   1  MapUrlSet      what URL, GISURL and TOKEN actually contain. Every
*                     theory so far has been about the shape of these
*                     three strings and none of them has been read out
*                     loud. A full URL with a token in it and a bare
*                     portal host are different answers to the same
*                     question, and they need different code.
*   2  reachability   can this SAP system even open the GIS host? An
*                     untrusted certificate, a missing proxy or a closed
*                     port all show up here as a status rather than as a
*                     blank map in a browser three layers away.
*   3  the directory  which services exist, and which layer carries a
*                     PARCELID field. That layer IS GIS_PARCELS.
*   4  the block      the exact markup ZCL_RAK_CJ_GIS would emit, so it
*                     can be read rather than inferred from a screenshot.
*
* READ-ONLY unless P_WRITE is ticked, and then it writes two rows of
* ZRAK_T_CJ_TXT and nothing else.
*
* THE TOKEN IS A CREDENTIAL. It is printed only with P_TOK ticked, and
* every probe sends it as a form field rather than pasting it into the
* URL line this report shows.
*&---------------------------------------------------------------------*
REPORT zrak_cj_map_diag.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_key  TYPE c LENGTH 132.
PARAMETERS p_bp   TYPE bu_partner.
PARAMETERS p_guid TYPE c LENGTH 32.
PARAMETERS p_dept TYPE c LENGTH 4.
PARAMETERS p_pid  TYPE c LENGTH 20.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
* Probe the GIS server. Off would make this report the same one that has
* already been run; the whole point is the probe.
PARAMETERS p_prob TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
* Follow folders. ArcGIS puts services in folders and the parcel layer is
* rarely in the root, but each folder is another round trip.
PARAMETERS p_deep TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
* Ceiling on service probes, because a portal can publish hundreds.
PARAMETERS p_max  TYPE i DEFAULT 40.
* Only look at services whose name contains this. Blank looks at all.
PARAMETERS p_filt TYPE c LENGTH 30 DEFAULT 'PARCEL'.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
* Write the discovered layers into ZRAK_T_CJ_TXT (GIS_PARCELS /
* GIS_PROPERTIES). Off by default: look at what was found first.
PARAMETERS p_write TYPE abap_bool AS CHECKBOX DEFAULT ' '.
* Print the token. Off by default.
PARAMETERS p_tok  TYPE abap_bool AS CHECKBOX DEFAULT ' '.
* Print the generated map markup.
PARAMETERS p_html TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.


*&---------------------------------------------------------------------*
CLASS lcl DEFINITION.
  PUBLIC SECTION.

    TYPES: BEGIN OF ty_hit,
             url    TYPE string,
             layer  TYPE string,
             fields TYPE string,
           END OF ty_hit.
    TYPES tt_hit TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY.

*   One GET. The token goes as a form field, never into IV_URL, so the
*   URL this report prints is safe to paste into a ticket.
    CLASS-METHODS get
      IMPORTING iv_url    TYPE string
                iv_token  TYPE string OPTIONAL
      EXPORTING ev_status TYPE i
                ev_err    TYPE string
      RETURNING VALUE(rv) TYPE string.

*   ArcGIS REST answers are small, flat and regular, so a regex over
*   them is honest here and avoids tying this report to whichever JSON
*   class the release happens to have.
*
*   NAME AND TYPE AS A PAIR, never two parallel lists. A directory
*   answer carries other "name" keys than the services', so matching
*   list position against list position silently pairs a service with
*   another service's type. ArcGIS emits the two adjacent and in this
*   order, which is what the regex keys on.
    TYPES: BEGIN OF ty_pair,
             a TYPE string,
             b TYPE string,
           END OF ty_pair.
    TYPES tt_pair TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.

    CLASS-METHODS json_pairs
      IMPORTING iv_json   TYPE string
                iv_regex  TYPE string
      RETURNING VALUE(rt) TYPE tt_pair.

    CLASS-METHODS say
      IMPORTING iv_label TYPE string
                iv_value TYPE string.

*   Trim a value for one WRITE line. A 3,000-character JSON body on one
*   line is not evidence, it is noise.
*
*   PREFERRED PARAMETER on both: a DEFAULT does not make the second
*   importing parameter invisible, so CUT( x ) is a syntax error without
*   it however optional IV_LEN is.
    CLASS-METHODS cut
      IMPORTING iv        TYPE string
                iv_len    TYPE i DEFAULT 200
      PREFERRED PARAMETER iv
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS wrap
      IMPORTING iv     TYPE string
                iv_len TYPE i DEFAULT 110
      PREFERRED PARAMETER iv.

ENDCLASS.

CLASS lcl IMPLEMENTATION.

  METHOD cut.
    rv = iv.
    IF strlen( rv ) > iv_len.
      rv = |{ substring( val = rv len = iv_len ) }...|.
    ENDIF.
  ENDMETHOD.

  METHOD wrap.
    DATA(lv) = iv.
    WHILE lv IS NOT INITIAL.
      DATA(lv_n) = COND i( WHEN strlen( lv ) > iv_len THEN iv_len ELSE strlen( lv ) ).
      WRITE: / |    { substring( val = lv len = lv_n ) }|.
      lv = substring( val = lv off = lv_n ).
    ENDWHILE.
  ENDMETHOD.

  METHOD say.
    WRITE: / iv_label, 24 cut( iv = iv_value ).
  ENDMETHOD.

  METHOD get.
    CLEAR: ev_status, ev_err.

    DATA lo_c TYPE REF TO if_http_client.
    cl_http_client=>create_by_url(
      EXPORTING  url                = iv_url
                 ssl_id             = 'ANONYM'
      IMPORTING  client             = lo_c
      EXCEPTIONS argument_not_found = 1
                 plugin_not_active  = 2
                 internal_error     = 3
                 OTHERS             = 4 ).
    IF sy-subrc <> 0 OR lo_c IS NOT BOUND.
      ev_err = |create_by_url failed, sy-subrc { sy-subrc }|.
      RETURN.
    ENDIF.

*   NO SAP LOGON POPUP. Left on, an unauthenticated call to a foreign
*   host can block the work process waiting for credentials nobody is
*   there to type.
    lo_c->propertytype_logon_popup = if_http_client=>co_disabled.
    lo_c->request->set_method( 'GET' ).

    DATA lt_p TYPE tihttpnvp.
    APPEND VALUE #( name = 'f' value = 'json' ) TO lt_p.
    IF iv_token IS NOT INITIAL.
      APPEND VALUE #( name = 'token' value = iv_token ) TO lt_p.
    ENDIF.
    lo_c->request->set_form_fields( lt_p ).

    lo_c->send( EXCEPTIONS http_communication_failure = 1
                           http_invalid_state         = 2
                           http_processing_failed     = 3
                           http_invalid_timeout       = 4
                           OTHERS                     = 5 ).
    IF sy-subrc <> 0.
      lo_c->get_last_error( IMPORTING message = DATA(lv_m1) ).
      ev_err = |send failed: { lv_m1 }|.
      lo_c->close( ).
      RETURN.
    ENDIF.

    lo_c->receive( EXCEPTIONS http_communication_failure = 1
                              http_invalid_state         = 2
                              http_processing_failed     = 3
                              OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      lo_c->get_last_error( IMPORTING message = DATA(lv_m2) ).
      ev_err = |receive failed: { lv_m2 }|.
      lo_c->close( ).
      RETURN.
    ENDIF.

    lo_c->response->get_status( IMPORTING code = ev_status ).
    rv = lo_c->response->get_cdata( ).
    lo_c->close( ).
  ENDMETHOD.

  METHOD json_pairs.
    DATA lt_m TYPE match_result_tab.
    FIND ALL OCCURRENCES OF REGEX iv_regex IN iv_json RESULTS lt_m.
    LOOP AT lt_m INTO DATA(ls_m).
      READ TABLE ls_m-submatches INTO DATA(ls_1) INDEX 1.
      CHECK sy-subrc = 0.
      READ TABLE ls_m-submatches INTO DATA(ls_2) INDEX 2.
      CHECK sy-subrc = 0.
      APPEND VALUE #(
        a = substring( val = iv_json off = ls_1-offset len = ls_1-length )
        b = substring( val = iv_json off = ls_2-offset len = ls_2-length ) ) TO rt.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.

  WRITE: / 'CJS PARCEL MAP - DIAGNOSIS'.
  WRITE: / |System { sy-sysid } client { sy-mandt } user { sy-uname }|.
  ULINE.

* ---------------------------------------------------------------- 1
  DATA ls_ctx TYPE zcl_rak_cj_api=>ty_ctx.
  ls_ctx-session_key = zcl_rak_cj_ctx=>session_key_of(
                         condense( CONV string( p_key ) ) ).
  ls_ctx-partner     = |{ p_bp ALPHA = OUT }|.
  CONDENSE ls_ctx-partner.
  ls_ctx-partnerguid = CONV string( p_guid ).
  ls_ctx-department  = CONV string( p_dept ).
  ls_ctx-langu       = sy-langu.
  IF ls_ctx-partnerguid IS INITIAL.
    ls_ctx-partnerguid = zcl_rak_cj_ctx=>guid_of( ls_ctx-partner ).
  ENDIF.

  WRITE: / '1. MAPURLSET'.
  lcl=>say( iv_label = '  partner'  iv_value = ls_ctx-partner ).
  lcl=>say( iv_label = '  guid'     iv_value = ls_ctx-partnerguid ).
  lcl=>say( iv_label = '  key len'  iv_value = |{ strlen( ls_ctx-session_key ) }| ).
  lcl=>say( iv_label = '  parcel'   iv_value = CONV string( p_pid ) ).

  DATA ls_mp TYPE zcl_rak_property_api=>ty_map_res.
  TRY.
      DATA(lo_pr) = NEW zcl_rak_property_api( is_ctx = ls_ctx ).
      ls_mp = lo_pr->map_url( iv_parcel = CONV string( p_pid ) ).
    CATCH cx_root INTO DATA(lx).
      WRITE: / '  ** map_url raised:', 30 lx->get_text( ).
  ENDTRY.

  LOOP AT ls_mp-msg INTO DATA(ls_msg).
*   CONV, because BAPIRET2-MESSAGE is a DDIC CHAR(220) and IV is TYPE
*   STRING. Parameters bind BY REFERENCE, so the two must be compatible -
*   a character LITERAL would have been accepted, which is exactly what
*   makes this easy to miss.
    WRITE: / '  msg', 12 ls_msg-type, 16 lcl=>cut( CONV string( ls_msg-message ) ).
  ENDLOOP.

* THE THREE STRINGS, IN FULL AND WRAPPED. Every theory about this map has
* been a theory about their shape.
  WRITE: / '  URL    ', 12 |len { strlen( ls_mp-url ) }|.
  lcl=>wrap( ls_mp-url ).
  WRITE: / '  GISURL ', 12 |len { strlen( ls_mp-gisurl ) }|.
  lcl=>wrap( ls_mp-gisurl ).
  WRITE: / '  TOKEN  ', 12 |len { strlen( ls_mp-token ) }|.
  IF p_tok = abap_true.
    lcl=>wrap( ls_mp-token ).
  ELSE.
    WRITE: / '    (tick Print token to show it)'.
  ENDIF.

* Which of the two is a URL at all, and does either already carry a
* token? "The url should be a full url with the token value" and "the
* token never goes in the url" are two different claims about these
* strings and this settles which is true HERE.
  DATA(lv_url_tok) = xsdbool( to_lower( ls_mp-url ) CS 'token='
                           OR to_lower( ls_mp-gisurl ) CS 'token=' ).
  lcl=>say( iv_label = '  url has token='
            iv_value = COND #( WHEN lv_url_tok = abap_true THEN 'YES' ELSE 'no' ) ).

* WHICH COLUMN IS WHICH, decided by shape. Measured on E10/200: URL holds
* a 236-character token, GISURL holds https://rakgisstg.rak.ae/
* CustomerJourneyMap/ and TOKEN is empty - so the three columns do NOT
* mean what their names say, and anything reading them by name gets a
* blank token and a token where a URL belongs.
  DATA(lv_tok_r) = zcl_rak_cj_gis=>token_of( iv_url    = ls_mp-url
                                             iv_gisurl = ls_mp-gisurl
                                             iv_token  = ls_mp-token ).
  DATA(lv_view_r) = zcl_rak_cj_gis=>viewer_of( iv_url    = ls_mp-url
                                               iv_gisurl = ls_mp-gisurl ).
  ULINE.
  WRITE: / '  READ BY SHAPE, not by column name'.
  lcl=>say( iv_label = '    token is'
            iv_value = COND #( WHEN lv_tok_r IS INITIAL THEN '** NONE FOUND **'
                               ELSE |{ strlen( lv_tok_r ) } characters| ) ).
  lcl=>say( iv_label = '    viewer is'
            iv_value = COND #( WHEN lv_view_r IS INITIAL THEN '** NONE FOUND **'
                               ELSE lv_view_r ) ).
  DATA(ls_c0) = zcl_rak_cj_gis=>cfg( ).
  lcl=>say( iv_label = '    proxy is'
            iv_value = COND #( WHEN ls_c0-proxy IS NOT INITIAL THEN ls_c0-proxy
                               WHEN lv_view_r IS NOT INITIAL THEN |{ lv_view_r }proxy.ashx|
                               ELSE '** cannot be derived - no viewer URL **' ) ).

* ---------------------------------------------------------------- 2
  ULINE.
  WRITE: / '2. CJS CONFIGURATION'.
  DATA(ls_cfg) = zcl_rak_cj_gis=>cfg( ).
  lcl=>say( iv_label = '  GIS_API'        iv_value = ls_cfg-api ).
  lcl=>say( iv_label = '  GIS_CSS'        iv_value = ls_cfg-css ).
  lcl=>say( iv_label = '  GIS_PARCELS'    iv_value = COND #(
              WHEN ls_cfg-parcels IS INITIAL THEN '** BLANK **' ELSE ls_cfg-parcels ) ).
  lcl=>say( iv_label = '  GIS_PROPERTIES' iv_value = COND #(
              WHEN ls_cfg-properties IS INITIAL THEN '(blank)' ELSE ls_cfg-properties ) ).
  lcl=>say( iv_label = '  READY( )'
            iv_value = COND #( WHEN zcl_rak_cj_gis=>ready( ) = abap_true
                               THEN 'yes - the ArcGIS map is drawn'
                               ELSE 'NO - the dialog falls back to the iframe' ) ).

* ---------------------------------------------------------------- 3
  DATA lt_hit TYPE lcl=>tt_hit.

  IF p_prob = abap_true.
    ULINE.
    WRITE: / '3. THE GIS SERVER, ASKED DIRECTLY'.

*   Both strings are tried as a base. Which one is the ArcGIS server is
*   exactly what is not known, so both are asked rather than one being
*   assumed and the other blamed.
*   ONLY THE STRING THAT IS ACTUALLY A URL. Probing the other one meant
*   sending a 236-character token to CREATE_BY_URL as if it were a host.
    DATA lt_base TYPE string_table.
    IF lv_view_r IS NOT INITIAL.
      APPEND lv_view_r TO lt_base.
    ENDIF.

*   AND THE ARCGIS ROOTS THAT COULD SIT ON THE SAME HOST.
*   /CustomerJourneyMap is a web application path, not a REST root, so
*   the directory is never under it. These four are where an ArcGIS
*   Server or Portal normally lives; each costs one request and a wrong
*   guess simply answers 404 rather than misleading anyone.
    IF lv_view_r IS NOT INITIAL.
      DATA(lv_p8) = find( val = lv_view_r sub = '/' occ = 3 ).
      IF lv_p8 > 0.
        DATA(lv_host) = substring( val = lv_view_r len = lv_p8 ).
        APPEND |{ lv_host }/server| TO lt_base.
        APPEND |{ lv_host }/arcgis| TO lt_base.
        APPEND |{ lv_host }/portal| TO lt_base.
        APPEND lv_host TO lt_base.
      ENDIF.
    ENDIF.

    IF lt_base IS INITIAL.
      WRITE: / '  Neither URL nor GISURL is an http address - nothing to probe.'.
    ENDIF.

    DATA lv_probes TYPE i.
*   Everything the probe reads back, declared here rather than inline for
*   the reason spelled out at the first GET( ) call below.
    DATA lv_st    TYPE i.
    DATA lv_er    TYPE string.
    DATA lv_info  TYPE string.
    DATA lv_dir   TYPE string.
    DATA lv_sj    TYPE string.
    DATA lv_lj    TYPE string.

    LOOP AT lt_base INTO DATA(lv_base).
*     Trailing slash off, and any /rest tail off: this report adds its own.
      DATA(lv_root) = lv_base.
      WHILE strlen( lv_root ) > 0 AND substring( val = lv_root
                                                 off = strlen( lv_root ) - 1 ) = '/'.
        lv_root = substring( val = lv_root len = strlen( lv_root ) - 1 ).
      ENDWHILE.
      DATA(lv_low) = to_lower( lv_root ).
      IF lv_low CS '/rest'.
        lv_root = substring( val = lv_root len = find( val = lv_low sub = '/rest' ) ).
      ENDIF.

      ULINE.
      WRITE: / '  base', 12 lv_root.

*     DECLARED UP FRONT. An inline DATA( ) in the IMPORTING part of a
*     functional call that is itself the source of an assignment is not
*     allowed - "the inline declaration is not possible in this position"
*     - because the declaration would have to take effect inside the
*     expression it is being read into.
      lv_info = lcl=>get( EXPORTING iv_url    = |{ lv_root }/rest/info|
                                    iv_token  = ls_mp-token
                          IMPORTING ev_status = lv_st
                                    ev_err    = lv_er ).
      WRITE: / '    /rest/info', 24 |HTTP { lv_st } { lv_er }|.
      IF lv_info IS NOT INITIAL.
        lcl=>wrap( lcl=>cut( iv = lv_info iv_len = 400 ) ).
      ENDIF.
      IF lv_st <> 200.
*       NOT A FAILURE OF THE MAP - a failure to reach the map FROM HERE.
*       The distinction matters more than it looks: the browser is what
*       talks to the GIS server when the map runs, not this system, and
*       the browser demonstrably reaches it (the viewer's own page loads
*       in the dialog). A refusal here therefore blocks THIS REPORT'S
*       discovery and nothing else.
        IF lv_er CS 'NIECONN_REFUSED' OR lv_er CS 'ICM_HTTP_CONNECTION_FAILED'.
          WRITE: / '    ** no route from SAP to that host. This blocks only the'.
          WRITE: / '       discovery below - the MAP itself is drawn by the'.
          WRITE: / '       browser, which reaches the host perfectly well.'.
          WRITE: / '       Fix by hand: read GIS_PARCELS off the live ShapeIt'.
          WRITE: / '       screen (network tab, the .../FeatureServer/<n>/query'.
          WRITE: / '       request) and put it in ZRAK_T_CJ_TXT.'.
        ELSE.
          WRITE: / '    ** this system cannot read that endpoint. Check STRUST'.
          WRITE: / '       for the GIS host certificate and SM59 for a proxy.'.
        ENDIF.
        CONTINUE.
      ENDIF.

*     ---- the service directory
      lv_dir = lcl=>get( EXPORTING iv_url   = |{ lv_root }/rest/services|
                                   iv_token = lv_tok_r
                         IMPORTING ev_status = lv_st
                                   ev_err    = lv_er ).
      WRITE: / '    /rest/services', 24 |HTTP { lv_st } { lv_er }|.
      IF lv_st <> 200.
        CONTINUE.
      ENDIF.

*     "folders" is an ARRAY OF STRINGS, not of objects, so neither regex
*     above sees it. Pull the array whole and split it.
      DATA lt_folder TYPE string_table.
      FIND REGEX '"folders"\s*:\s*\[([^\]]*)\]' IN lv_dir
           SUBMATCHES DATA(lv_farr).
      IF sy-subrc = 0.
        REPLACE ALL OCCURRENCES OF '"' IN lv_farr WITH ``.
        CONDENSE lv_farr.
        IF lv_farr IS NOT INITIAL.
          SPLIT lv_farr AT ',' INTO TABLE lt_folder.
        ENDIF.
      ENDIF.
      WRITE: / '    folders', 24 |{ lines( lt_folder ) }|.

*     Root first, then each folder.
      DATA lt_scan TYPE string_table.
      APPEND `` TO lt_scan.
      IF p_deep = abap_true.
        LOOP AT lt_folder INTO DATA(lv_f).
          DATA(lv_fc) = condense( lv_f ).
          IF lv_fc IS NOT INITIAL.
            APPEND lv_fc TO lt_scan.
          ENDIF.
        ENDLOOP.
      ENDIF.

      LOOP AT lt_scan INTO DATA(lv_folder).
        DATA(lv_path) = COND string( WHEN lv_folder IS INITIAL THEN ``
                                     ELSE |/{ lv_folder }| ).
*       NOT INSIDE A COND. A method that also has IMPORTING parameters
*       does not belong in a constructor expression; the root answer is
*       already in hand and only a folder needs a second read.
        DATA lv_slist TYPE string.
        IF lv_folder IS INITIAL.
          lv_slist = lv_dir.
        ELSE.
          lv_slist = lcl=>get( EXPORTING iv_url   = |{ lv_root }/rest/services{ lv_path }|
                                         iv_token = lv_tok_r
                               IMPORTING ev_status = lv_st ).
        ENDIF.

        DATA(lt_svc) = lcl=>json_pairs(
          iv_json  = lv_slist
          iv_regex = '"name"\s*:\s*"([^"]*)"\s*,\s*"type"\s*:\s*"([^"]*)"' ).

        LOOP AT lt_svc INTO DATA(ls_svc).
          DATA(lv_sname) = ls_svc-a.
          DATA(lv_stype) = ls_svc-b.
          IF lv_stype <> 'FeatureServer' AND lv_stype <> 'MapServer'.
            CONTINUE.
          ENDIF.
          IF p_filt IS NOT INITIAL
             AND to_upper( lv_sname ) NS to_upper( CONV string( p_filt ) ).
            CONTINUE.
          ENDIF.
          IF lv_probes >= p_max.
            WRITE: / |    ** probe ceiling { p_max } reached - raise it or narrow the filter|.
            EXIT.
          ENDIF.
          lv_probes = lv_probes + 1.

*         The service name already carries its folder in the directory
*         answer ("Folder/Service"), so it is not prefixed again.
          DATA(lv_svc) = |{ lv_root }/rest/services/{ lv_sname }/{ lv_stype }|.
          lv_sj = lcl=>get( EXPORTING iv_url   = lv_svc
                                      iv_token = lv_tok_r
                            IMPORTING ev_status = lv_st ).
          WRITE: / |    { lv_stype } { lv_sname }|, 70 |HTTP { lv_st }|.
          IF lv_st <> 200.
            CONTINUE.
          ENDIF.

          DATA(lt_lay) = lcl=>json_pairs(
            iv_json  = lv_sj
            iv_regex = '"id"\s*:\s*(-?[0-9]+)\s*,\s*"name"\s*:\s*"([^"]*)"' ).

          LOOP AT lt_lay INTO DATA(ls_lay).
            DATA(lv_lid) = ls_lay-a.
            DATA(lv_ln)  = ls_lay-b.
            IF lv_probes >= p_max.
              EXIT.
            ENDIF.
            lv_probes = lv_probes + 1.
            DATA(lv_lurl) = |{ lv_svc }/{ lv_lid }|.
            lv_lj = lcl=>get( EXPORTING iv_url   = lv_lurl
                                        iv_token = lv_tok_r
                              IMPORTING ev_status = lv_st ).
            IF lv_st <> 200.
              CONTINUE.
            ENDIF.

*           THE TEST IS THE FIELD, not the name. Map.js filters every
*           layer with PARCELID (and UnitID / FloorID / BldID), so a
*           layer that has a PARCELID field is a layer Map.js could
*           have been pointed at - whatever it happens to be called.
*           SPACES OUT FIRST. f=json is normally compact, and "normally"
*           is not a thing to build a test on.
            DATA(lv_up) = to_upper( lv_lj ).
            REPLACE ALL OCCURRENCES OF ` ` IN lv_up WITH ``.
            IF lv_up CS '"NAME":"PARCELID"'.
              APPEND VALUE #( url    = lv_lurl
                              layer  = lv_ln
                              fields = COND #( WHEN lv_up CS '"NAME":"UNITID"'
                                               THEN 'PARCELID,UNITID' ELSE 'PARCELID' ) )
                     TO lt_hit.
              WRITE: / |      layer { lv_lid } { lv_ln }|, 70 'HAS PARCELID'.
            ENDIF.
          ENDLOOP.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    ULINE.
    WRITE: / |  { lines( lt_hit ) } layer(s) carry a PARCELID field|.
    LOOP AT lt_hit INTO DATA(ls_hit).
      WRITE: / |    { ls_hit-layer }|.
      lcl=>wrap( ls_hit-url ).
    ENDLOOP.
    IF lt_hit IS INITIAL AND lv_probes > 0.
      WRITE: / '  Nothing matched. Widen the filter (blank looks at every'.
      WRITE: / '  service) or raise the ceiling, then run again.'.
    ENDIF.
  ENDIF.

* ---------------------------------------------------------------- write
  IF p_write = abap_true AND lt_hit IS NOT INITIAL.
    ULINE.
    WRITE: / '4. WRITING ZRAK_T_CJ_TXT'.
*   The FIRST hit is the parcel layer and the SECOND, when there is one,
*   the property layer - which is the order ArcGIS lists them in and the
*   order Map.js uses them in. Both are printed above, so a wrong guess
*   here is visible and one edit away rather than silent.
    DATA(lv_p1) = VALUE string( lt_hit[ 1 ]-url OPTIONAL ).
    DATA(lv_p2) = VALUE string( lt_hit[ 2 ]-url OPTIONAL ).

    MODIFY zrak_t_cj_txt FROM @( VALUE #(
      mandt = sy-mandt msgno = 'GIS_PARCELS' text_en = lv_p1 ) ).
    WRITE: / '  GIS_PARCELS   written'.
    IF lv_p2 IS NOT INITIAL.
      MODIFY zrak_t_cj_txt FROM @( VALUE #(
        mandt = sy-mandt msgno = 'GIS_PROPERTIES' text_en = lv_p2 ) ).
      WRITE: / '  GIS_PROPERTIES written'.
    ENDIF.
    COMMIT WORK.
    WRITE: / '  Re-run this report to see READY( ) turn yes.'.
  ELSEIF p_write = abap_true.
    ULINE.
    WRITE: / '4. NOTHING TO WRITE - no layer carried a PARCELID field.'.
  ENDIF.

* ---------------------------------------------------------------- html
  IF p_html = abap_true.
    ULINE.
    WRITE: / '5. THE MARKUP ZCL_RAK_CJ_GIS WOULD EMIT'.
    DATA(lv_show) = CONV string( p_pid ).
    SHIFT lv_show LEFT DELETING LEADING '0'.
*   TWO PIECES, because the page gets them through two different
*   channels: the div through HTML( ) and the code through
*   FOLLOW_UP_ACTION( ). A <script> inside HTML( ) never executes, which
*   is the defect that cost this map six rounds.
    WRITE: / '  container (without the snippet, which is printed below):'.
    lcl=>wrap( zcl_rak_cj_gis=>container( iv_div = 'rakGisDiag' ) ).
    DATA(lv_block) = zcl_rak_cj_gis=>script(
      iv_token  = lv_tok_r
      iv_viewer = lv_view_r
      iv_div    = 'rakGisDiag'
      it_ids    = VALUE string_table( ( lv_show ) )
      iv_focus  = lv_show ).
    IF lv_block IS INITIAL.
      WRITE: / '  (blank - READY( ) is false, so the iframe fallback is used)'.
    ELSE.
      WRITE: / |  script: { strlen( lv_block ) } chars, | &&
               |{ COND string( WHEN lv_block CS `'` THEN '** CONTAINS A SINGLE QUOTE - it will be'
                               && ' run as a frontend action, not as code **'
                               ELSE 'no single quote (correct)' ) }|.
*     The token is IN this markup. Masked unless it was asked for.
      IF p_tok = abap_false AND lv_tok_r IS NOT INITIAL.
        REPLACE ALL OCCURRENCES OF lv_tok_r IN lv_block WITH '<TOKEN>'.
      ENDIF.
      lcl=>wrap( lv_block ).
    ENDIF.
  ENDIF.

  ULINE.
  WRITE: / 'Done.'.
