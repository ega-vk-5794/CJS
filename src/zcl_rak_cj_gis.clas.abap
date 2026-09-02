CLASS zcl_rak_cj_gis DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& RakMap.Map, rebuilt as a CJS renderer.
*&
*& BUILD map-fix-9.  Missing this line means SAP has an older copy - see
*& the note on unticked 'Overwrite local object' rows in ZRAK_CJ_MAP_DIAG.
*& map-fix-8 contains: the proxy registered as a urlUtils.addProxyRule( )
*& rather than as cf.request.alwaysUseProxy, which is a 3.x property that
*& does not exist on 4.x and silently proxied nothing - so the layer was
*& fetched direct from a dotless alias and died as "Failed to fetch". The
*& note line now also reports e.details.url, which is what tells a rule
*& that did not apply from a proxy that refused.
*& map-fix-9 contains: the PROXY STATE on that same note line. The URL
*& alone was one round short - a blank proxy, a refused rule and a rule
*& on the wrong host all end as the same "Failed to fetch" against the
*& layer host, and it is not established whether ArcGIS reports
*& DETAILS.URL before or after its own proxy rewrite. PX says which of
*& the three it was, and asks GETPROXYRULE( ) whether the rule really
*& covers the layer URL rather than trusting that ADDPROXYRULE( )
*& returning quietly means it matched.
*& map-fix-3 contains: VALUE IS INITIAL on the two blank string constants
*& (VALUE '' does not activate, and the class then has no active version,
*& so every CALLER reports "Method X is unknown"), one ENDMETHOD after
*& SCRIPT( ) rather than two, and PREFERRED PARAMETER on CONTAINER( ).
*&
*& THE LEGACY MAP IS NOT AN IFRAME. That was the assumption for six
*& rounds and it was wrong. util/Map.js in the ShapeIt app is a
*& sap.ui.core.Control whose renderer writes one bare <div> and whose
*& createMap( ) then does
*&
*&     require(["esri/Map","esri/views/MapView","esri/layers/FeatureLayer",
*&              "esri/identity/IdentityManager", ...], function(...) {
*&       esriConfig.portalUrl = envProxy.portalUrl;
*&       IdentityManager.registerToken(envProxy.token);
*&       ...
*&
*& - the ArcGIS JS API rendered INSIDE the application page. There is a
*& second, separate thing that IS an iframe (gismappingIM.js, the Defcon
*& viewer, which takes parcelId/token/lang by postMessage); that is the
*& standalone GIS site, not the control the parcel dialog draws. This
*& class is the first one. ZCL_RAK_CJ_PARCEL keeps the iframe as the
*& fallback for as long as the layer configuration below is blank.
*&
*& WHAT COMES FROM WHERE:
*&
*&   MapUrlSet ..... THE TOKEN, and nothing else this class can use.
*&   this class .... the ArcGIS API to load and the feature service the
*&                   parcels live in. Map.js takes those from an envProxy
*&                   the ShapeIt app assembles from its own configuration,
*&                   which is in the UI5 repository and not in any service
*&                   CJS can read - so they are configuration HERE, blank
*&                   until somebody fills them in, and NEVER guessed. A
*&                   wrong feature service URL draws an empty map with no
*&                   error, which is the most expensive failure of the
*&                   three the map already has.
*&
*& MAPURLSET'S FIELDS ARE NOT WHAT THEIR NAMES SAY, and this is measured,
*& not assumed - ZRAK_CJ_MAP_DIAG on E10/200, partner 3000401630:
*&
*&     URL     len 236   4gat2CeMnEV2TYJvpD11wTXEDOeWXs4zd2F-4rVdBIJhsi...
*&     GISURL  len 44    https://rakgisstg.rak.ae/CustomerJourneyMap/
*&     TOKEN   len 0
*&
*& URL is THE TOKEN. GISURL is the VIEWER PAGE. TOKEN is empty and appears
*& to be always empty. So a caller must never hand -URL to something
*& expecting a URL or -TOKEN to something expecting a token; TOKEN_OF( )
*& and VIEWER_OF( ) below are the one place that knows this, and both
*& decide by SHAPE rather than by field name, so a system that fills the
*& three columns the way their names suggest still works.
*&
*& AND THE ARCGIS SERVER IS NOT IN THAT ANSWER AT ALL. /CustomerJourneyMap
*& is a web application path, not a REST root. The server the token is
*& good for is therefore derived from GIS_PARCELS' own origin, which is
*& the only place it is actually known - one less value to configure, and
*& one less that can be configured inconsistently.
*&
*& CONFIGURED IN TWO PLACES, code last. CFG( ) reads ZRAK_T_CJ_TXT rows
*& GIS_API / GIS_CSS / GIS_PARCELS / GIS_PROPERTIES first, so the
*& endpoints can differ per system without a transport, and falls back to
*& the constants below. Nothing here needs a DDIC change.
*&
*& A <SCRIPT> BLOCK INSIDE HTML( ) NEVER RUNS, AND THAT IS WHY THIS MAP
*& FAILED SEVEN TIMES. Z2UI5_CL_XML_VIEW->HTML( ) sets the CONTENT
*& property of sap.ui.core.HTML, which reaches the DOM as innerHTML - and
*& a <script> element inserted through innerHTML is inert BY SPECIFICATION.
*& The browser parses it, keeps it, and never executes it. Nothing is
*& logged. Every attempt so far shipped a <script> block: the iframe
*& rendered and sat on its splash screen for ever because the postMessage
*& beside it never ran, which read exactly like a wrong URL and sent six
*& rounds after the URL.
*&
*& THIS CODEBASE ALREADY KNEW. RENDER_UPLOADER( ) puts its FileReader in
*& an onchange= ATTRIBUTE, and an inline event attribute does run - which
*& is why the uploader works and every <script> has not.
*&
*& SO THE MARKUP AND THE SCRIPT ARE TWO CALLS. CONTAINER( ) returns the
*& div, and SCRIPT( ) returns the code for
*& Z2UI5_IF_CLIENT->FOLLOW_UP_ACTION( ), which the frontend runs after the
*& view - and after a popup fragment - has rendered
*& (Z2UI5_CL_APP_VIEW1_JS, _runPendingCustomJs in the finally block of
*& _processAfterRendering). A caller that renders one without the other
*& gets a grey box or a script with nothing to draw into.
*&
*& NOT ONE SINGLE QUOTE IN THE SCRIPT, ANYWHERE. _runCustomJs splits the
*& snippet on the single-quote character and, if it finds any, treats the
*& pieces as arguments to a FRONTEND action instead of running the code:
*&
*&     const parts = item.split("\u0027");
*&     const args = parts.filter((_, index) => index % 2 === 1);
*&     if (args.length > 0) { oController.eF(...args); }
*&     else { Function("return " + parts[0])(); }
*&
*& One stray quote and the whole map becomes a call to a frontend action
*& that does not exist. So every string here is double-quoted, and the two
*& places that genuinely need a quote CHARACTER - the SQL-style
*& PARCELID IN (...) list - build it with String.fromCharCode(39).
*&
*& THE CENTRE, ZOOM, RENDERER AND HIGHLIGHT ARE MAP.JS'S OWN - centre
*& [55.9504, 25.7766], zoom 14, a near-transparent fill with a dashed
*& #0079c1 outline, PARCELID labelled in white on a black halo, highlight
*& [191,19,19]. Copied rather than designed so the map a citizen sees in
*& CJS is the map they see in ShapeIt.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_cfg,
*            The ArcGIS JS API and its stylesheet.
             api        TYPE string,
             css        TYPE string,
*            Feature service layer URLs, complete - "<service>/<layer id>",
*            which is how Map.js composes them:
*                `${envProxy.parcelsLayersUrl}/${envProxy.portalItemParcelsID}`
             parcels    TYPE string,
             properties TYPE string,
*            The ArcGIS Resource Proxy the viewer app hosts. Blank means
*            "derive it from the viewer URL", which is where it lives.
             proxy      TYPE string,
           END OF ty_cfg.

*   The four endpoints, ZRAK_T_CJ_TXT first and the constants after.
    CLASS-METHODS cfg RETURNING VALUE(rs) TYPE ty_cfg.

*   Is there enough configuration to draw the real map? FALSE means the
*   caller should fall back - it is never a reason to draw an empty box.
    CLASS-METHODS ready RETURNING VALUE(rv) TYPE abap_bool.

*   WHICH OF MAPURLSET'S THREE STRINGS IS THE TOKEN, AND WHICH IS THE
*   VIEWER. Decided by shape, never by field name - see the header for the
*   measurement that made this necessary. Hand all three in; these answer
*   what they are, and a system that fills the columns as their names
*   suggest gets the same answer.
    CLASS-METHODS token_of
      IMPORTING iv_url    TYPE string
                iv_gisurl TYPE string
                iv_token  TYPE string
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS viewer_of
      IMPORTING iv_url    TYPE string
                iv_gisurl TYPE string
      RETURNING VALUE(rv) TYPE string.

*   THE MARKUP, AND THE SECOND WAY OF RUNNING THE CODE.
*
*   FOLLOW_UP_ACTION( ) ALONE WAS NOT ENOUGH. It runs from the MAIN view's
*   onAfterRendering, and a round trip that only opens a POPUP does not
*   necessarily re-render the main view - so the details dialog drew its
*   container and the snippet never fired: "Loading the map..." on screen
*   for ever, which is exactly the second row of the table below.
*
*   So the snippet is ALSO carried by an inline event attribute, on a 1x1
*   transparent image inside the container. An inline event attribute is
*   the one JavaScript delivery that has always worked here -
*   RENDER_UPLOADER( )'s onchange= FileReader - because it is the browser
*   parsing markup rather than a framework choosing a moment. It fires
*   when the image loads, which is when the markup is inserted, popup or
*   not.
*
*   RUNNING TWICE IS FREE. The snippet's own dataset.rakGis flag makes a
*   second arrival a no-op, so both channels stay and whichever wins,
*   wins. Two independent deliveries and an idempotent payload beat one
*   delivery and a lifecycle assumption.
*
*   THE ATTRIBUTE IS SINGLE-QUOTED, which is what makes one snippet serve
*   both. It is guaranteed free of single quotes - JSQ( ) turns any into
*   \u0027 for FOLLOW_UP_ACTION( )'s sake - and full of double ones, so
*   onload='...' cannot be broken out of and needs no second encoding.
*
*   THE THREE STATES IT LEAVES ON SCREEN:
*
*     grey box, no text ....... the markup never reached the page
*     "Loading the map..." .... the markup arrived, neither channel ran
*     an error sentence ....... it ran, and the API or the layer failed
*
*   IV_DIV     the id of the container. Must be unique on the page.
*   IV_SCRIPT  what SCRIPT( ) returned. Omitted, this is a plain box.
*
*   PREFERRED PARAMETER, because CONTAINER( lv_div ) is how this reads at
*   every call site. Without it the short form is a syntax error the
*   moment a method has more than one importing parameter - a DEFAULT
*   does not make the second one invisible.
    CLASS-METHODS container
      IMPORTING iv_div    TYPE string
                iv_height TYPE string DEFAULT '26rem'
                iv_script TYPE string OPTIONAL
      PREFERRED PARAMETER iv_div
      RETURNING VALUE(rv) TYPE string.

*   THE CODE. Goes to Z2UI5_IF_CLIENT->FOLLOW_UP_ACTION( ), and only
*   there. Returns blank when the endpoints are not configured, so a
*   caller that passes blank to FOLLOW_UP_ACTION( ) simply asks for
*   nothing.
*
*   IT_IDS     every parcel the layer may show - the citizen's own
*              properties, UNPADDED, the way Map.js holds ownedProperties.
*   IV_FOCUS   the one to zoom to and highlight. Blank zooms to all.
*   IV_EVENT   a CJS backend event name; when filled, clicking a parcel
*              the citizen owns raises |<IV_EVENT>~<parcelid>|. Blank
*              draws a map that cannot be clicked, which is what the
*              details dialog wants.
*   IV_CTRL    which z2ui5 controller carries that event - 'oController'
*              in the page, 'oControllerPopup' inside a dialog.
*
*   NOT TYPED ON ZCL_RAK_PROPERTY_API. A plain string instead of its
*   TY_MAP_RES: that class inherits the generated legacy DPC, and a static
*   reference to anything in that chain stops THIS class loading whenever
*   any link in it is inactive. The caller already lives inside the
*   dynamic zone and can unpack the read itself.
    CLASS-METHODS script
      IMPORTING iv_token     TYPE string
*               The viewer page from MapUrlSet. Used only to work out
*               where the resource proxy is; see C_PROXY.
                iv_viewer    TYPE string
                iv_div       TYPE string
                it_ids       TYPE string_table
                iv_focus     TYPE string OPTIONAL
                iv_event     TYPE string OPTIONAL
                iv_ctrl      TYPE string DEFAULT 'oController'
      RETURNING VALUE(rv)    TYPE string.

  PRIVATE SECTION.

*   READ OFF THE LIVE MAP'S OWN NETWORK TRACE, not guessed. Filtering the
*   working My Properties screen on "query" shows exactly three data
*   calls, and every one of them goes through the viewer's proxy:
*
*     proxy.ashx?https://gisserver/cadastral/parcel/query?...&where=Pa...
*     proxy.ashx?https://gisserver/cadastral/property/query?...&where=P...
*     proxy.ashx?https://gisserver/addressing/addresspoint/query?...
*
*   So the layers are addressed by a SHORT INTERNAL ALIAS - gisserver,
*   a host with no dot in it - and the browser never contacts it directly.
*   Filtering the same trace on "FeatureServer" returns NOTHING, which is
*   why the discovery in ZRAK_CJ_MAP_DIAG was looking for the wrong thing.
*
*   Still overridable through ZRAK_T_CJ_TXT, because these were read from
*   a truncated trace on the STAGING system and the production aliases may
*   differ.
*   VALUE IS INITIAL, not VALUE ''. A constant of type STRING will not
*   take an empty literal - "the field must be filled" - and the whole
*   class then fails to activate, which is what made ZCL_RAK_CJ_PARCEL
*   report "Method SCRIPT is unknown": a class with no active version has
*   no methods at all, so the error surfaces at the caller and points
*   nowhere near the cause.
    CONSTANTS c_parcels    TYPE string VALUE 'https://gisserver/cadastral/parcel'.
    CONSTANTS c_properties TYPE string VALUE 'https://gisserver/cadastral/property'.

*   THE PROXY IS THE WHOLE MECHANISM, and it is not optional. Every data
*   call in the live trace is
*
*       <viewer>/proxy.ashx?<the real service url>
*
*   an ArcGIS Resource Proxy hosted by the viewer application. It is what
*   resolves the internal "gisserver" alias, and it is what carries the
*   credentials - which is also why MapUrlSet's TOKEN column is empty and
*   nothing seemed to need it.
*
*   Blank means DERIVE IT from the viewer page MapUrlSet already answers
*   (https://rakgisstg.rak.ae/CustomerJourneyMap/ + proxy.ashx), so a
*   system that moves the viewer moves the proxy with it and nothing here
*   has to be re-typed.
    CONSTANTS c_proxy TYPE string VALUE IS INITIAL.

*   The public ArcGIS CDN, pinned to 4.24 - the version the LIVE ShapeIt
*   map loads, observed in its own network trace:
*
*     https://js.arcgis.com/4.24/esri/views/2d/layers/FeatureLayerView2D.js
*
*   Matching it is not cosmetic. The layer definitions, the token
*   handshake and the renderer JSON all move between 4.x minors, and
*   running the same layers on a different version is a difference nobody
*   would think to look for. It also settles that the browser reaches
*   js.arcgis.com directly, so the CDN is the right default rather than a
*   portal-hosted copy. Overridable through ZRAK_T_CJ_TXT either way.
    CONSTANTS c_api TYPE string VALUE 'https://js.arcgis.com/4.24/'.
    CONSTANTS c_css TYPE string VALUE 'https://js.arcgis.com/4.24/esri/themes/light/main.css'.

*   Map.js's own view constants.
    CONSTANTS c_lon  TYPE string VALUE '55.9504'.
    CONSTANTS c_lat  TYPE string VALUE '25.7766'.
    CONSTANTS c_zoom TYPE string VALUE '14'.

*   One ZRAK_T_CJ_TXT override, English column only - a URL has no
*   language. Missing row or blank text falls through to IV_DEFAULT.
    CLASS-METHODS txt
      IMPORTING iv_key     TYPE string
                iv_default TYPE string
      RETURNING VALUE(rv)  TYPE string.

*   A value on its way into a DOUBLE-quoted JS string literal. Backslash
*   and double quote are escaped; a SINGLE quote is turned into \u0027,
*   because one surviving single quote anywhere in the snippet makes
*   _runCustomJs treat the whole thing as a frontend action instead of
*   running it (see the header). Newlines go too - a snippet is one line.
    CLASS-METHODS jsq
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE string.

*   "'a','b','c'" - the inside of Map.js's PARCELID IN ( ... ).
    CLASS-METHODS in_list
      IMPORTING it        TYPE string_table
      RETURNING VALUE(rv) TYPE string.

ENDCLASS.



CLASS zcl_rak_cj_gis IMPLEMENTATION.


  METHOD jsq.
    rv = iv.
*   Backslash first, or the escapes added below get escaped again.
    REPLACE ALL OCCURRENCES OF `\` IN rv WITH `\\`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `\"`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `\u0027`.
    REPLACE ALL OCCURRENCES OF |\n| IN rv WITH ` `.
    REPLACE ALL OCCURRENCES OF |\r| IN rv WITH ` `.
  ENDMETHOD.


  METHOD txt.
    DATA lv_key TYPE zrak_t_cj_txt-msgno.
    lv_key = iv_key.
    SELECT SINGLE text_en FROM zrak_t_cj_txt
      WHERE msgno = @lv_key
      INTO @DATA(lv_v).
    DATA(lv_found) = xsdbool( sy-subrc = 0 ).
    DATA(lv_txt) = condense( CONV string( lv_v ) ).
    rv = COND string( WHEN lv_found = abap_true AND lv_txt IS NOT INITIAL
                      THEN lv_txt ELSE iv_default ).
  ENDMETHOD.


  METHOD cfg.
    rs-api        = txt( iv_key = `GIS_API`        iv_default = c_api ).
    rs-css        = txt( iv_key = `GIS_CSS`        iv_default = c_css ).
    rs-parcels    = txt( iv_key = `GIS_PARCELS`    iv_default = c_parcels ).
    rs-properties = txt( iv_key = `GIS_PROPERTIES` iv_default = c_properties ).
    rs-proxy      = txt( iv_key = `GIS_PROXY`      iv_default = c_proxy ).
  ENDMETHOD.


  METHOD ready.
*   The parcel layer is the one that cannot be done without. The property
*   layer is additive - Map.js draws both, and a system that configures
*   only the first still gets a map with the parcel on it.
    DATA(ls) = cfg( ).
    rv = xsdbool( ls-api IS NOT INITIAL AND ls-parcels IS NOT INITIAL ).
  ENDMETHOD.


  METHOD token_of.
*   An explicit TOKEN wins, if a system ever fills it. Otherwise the
*   token is whichever of the two remaining strings is NOT a URL - on E10
*   that is URL, 236 characters of opaque ArcGIS token, while GISURL
*   holds https://rakgisstg.rak.ae/CustomerJourneyMap/.
    rv = condense( iv_token ).
    IF rv IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF iv_url IS NOT INITIAL AND iv_url NP 'http*'.
      rv = condense( iv_url ).
      RETURN.
    ENDIF.
    IF iv_gisurl IS NOT INITIAL AND iv_gisurl NP 'http*'.
      rv = condense( iv_gisurl ).
    ENDIF.
  ENDMETHOD.


  METHOD viewer_of.
*   And the viewer is whichever one IS a URL. GISURL first, because that
*   is where it sits on every system measured so far.
    IF iv_gisurl CP 'http*'.
      rv = condense( iv_gisurl ).
      RETURN.
    ENDIF.
    IF iv_url CP 'http*'.
      rv = condense( iv_url ).
    ENDIF.
  ENDMETHOD.


  METHOD in_list.
*   DOUBLE quotes. The array is JS source; the SQL-style single quotes
*   the where clause needs are added at RUNTIME by the snippet, from
*   String.fromCharCode(39), so that no single quote appears in the text
*   sent to FOLLOW_UP_ACTION( ).
    LOOP AT it INTO DATA(lv).
      DATA(lv_c) = condense( lv ).
      IF lv_c IS INITIAL.
        CONTINUE.
      ENDIF.
      rv = COND string( WHEN rv IS INITIAL THEN |"{ jsq( lv_c ) }"|
                        ELSE |{ rv },"{ jsq( lv_c ) }"| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD container.

    rv = |<div id="{ iv_div }" class="rakGisMap" | &&
         |style="width:100%;height:{ iv_height };">| &&
         |<div class="rakGisErr">Loading the map...</div></div>| &&
*        OUTSIDE THE MAP, deliberately. The MapView takes the whole of its
*        container, so a status line inside it is wiped the instant the
*        map draws - which is precisely when there is something to say.
         |<div id="{ iv_div }_n" class="rakGisNote"></div>|.

*   THE 1x1 TRANSPARENT GIF whose onload runs the snippet. A data: URI, so
*   it costs no request and cannot fail to arrive; display:none, and an
*   image that is not displayed still fires onload.
    IF iv_script IS NOT INITIAL.
      rv = rv &&
        |<img alt="" style="display:none" | &&
        |src="data:image/gif;base64,| &&
        |R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" | &&
        |onload='{ iv_script }'>|.
    ENDIF.


*   BRACES ESCAPED, OR UI5 READS THEM AS DATA BINDINGS. This markup
*   travels as an XML view ATTRIBUTE - sap.ui.core.HTML's content - and
*   UI5's XML parser treats { } in an attribute value as a binding
*   expression. An unescaped snippet full of JavaScript object literals is
*   therefore parsed as dozens of malformed bindings and the control never
*   renders at all. RENDER_UPLOADER( ) has carried these same two lines
*   for the same reason ever since its FileReader went into an onchange=.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.

  ENDMETHOD.


  METHOD script.

    DATA(ls_cfg) = cfg( ).
    IF ready( ) = abap_false.
      RETURN.
    ENDIF.

*   NO PORTAL AND NO SERVER FROM MAPURLSET. That service answers a token
*   and a viewer page; the ArcGIS server it is good for is not in it, and
*   /CustomerJourneyMap is a web application path rather than a REST root.
*   The origin is taken from GIS_PARCELS instead - the one place the
*   server is genuinely known - which is one fewer value to configure and
*   one fewer that can be configured inconsistently.
*
*   The token is a credential. It reaches the page as a JS string, the
*   same place the ShapeIt app puts it, and never as a URL parameter
*   where every proxy on the way would log it.
*   PROXY: configured, or the viewer page with proxy.ashx on the end.
    DATA(lv_proxy) = ls_cfg-proxy.
    IF lv_proxy IS INITIAL AND iv_viewer CP 'http*'.
      lv_proxy = iv_viewer.
      IF substring( val = lv_proxy off = strlen( lv_proxy ) - 1 ) <> '/'.
        lv_proxy = |{ lv_proxy }/|.
      ENDIF.
      lv_proxy = |{ lv_proxy }proxy.ashx|.
    ENDIF.

    DATA(lv_c) =
      |var C=\{api:"{ jsq( ls_cfg-api ) }",css:"{ jsq( ls_cfg-css ) }",| &&
      |proxy:"{ jsq( lv_proxy ) }",| &&
      |parcels:"{ jsq( ls_cfg-parcels ) }",props:"{ jsq( ls_cfg-properties ) }",| &&
      |token:"{ jsq( iv_token ) }",ids:[{ in_list( it_ids ) }],| &&
      |focus:"{ jsq( iv_focus ) }",evt:"{ jsq( iv_event ) }",| &&
      |ctrl:"{ jsq( iv_ctrl ) }",div:"{ jsq( iv_div ) }"\};|.

*   IDEMPOTENT. FOLLOW_UP_ACTION( ) fires once per round trip, but a round
*   trip that does not repaint the map leaves the previous MapView in the
*   div - so the flag says "already built here" and a second run stops.
    DATA(lv_head) =
      |var D=document.getElementById(C.div);| &&
      |if(!D)\{return;\}| &&
      |if(D.dataset.rakGis==="1")\{return;\}| &&
      |D.dataset.rakGis="1";| &&
*     textContent, so no quoted markup is needed inside a quoted string.
      |function F(m)\{D.textContent=m;\}| &&
*     THE NOTE LINE, a sibling of the map rather than its content: the
*     MapView owns everything inside D, so anything written there is
*     destroyed the moment the map draws.
      |var NT=document.getElementById(C.div+"_n");| &&
      |function N(m)\{if(NT)\{NT.textContent=m;\}\}| &&
      |D.textContent="Loading the map library...";|.

*   LOADED BY SCRIPT ELEMENT. The API is a normal external script; it is
*   appended to the head rather than written into markup, because markup
*   is exactly what does not execute here.
    DATA(lv_load) =
      |function L(cb)\{| &&
      |if(window.require&&window.require.__esri)\{cb();return;\}| &&
      |if(C.css)\{var l=document.createElement("link");l.rel="stylesheet";| &&
      |l.href=C.css;document.head.appendChild(l);\}| &&
      |var s=document.createElement("script");s.src=C.api;s.onload=cb;| &&
      |s.onerror=function()\{F("The map library could not be loaded.");\};| &&
      |document.head.appendChild(s);\}|.

    DATA(lv_req) =
      |L(function()\{require([| &&
      |"esri/config","esri/identity/IdentityManager","esri/Map",| &&
      |"esri/views/MapView","esri/layers/FeatureLayer",| &&
      |"esri/core/urlUtils"| &&
      |],function(cf,IM,M,MV,FL,UU)\{try\{| &&
      |D.textContent="";| &&
*     THE ORIGIN OF THE LAYER, needed by the proxy rule below as well as
*     by the token interceptor, so it is computed ahead of both.
      |var p8=C.parcels.indexOf("/",8);| &&
      |var O=p8>0?C.parcels.substring(0,p8):C.parcels;| &&
      |var H=O.substring(O.indexOf("//")+2);| &&
*     THE PROXY, BEFORE ANY LAYER IS BUILT - AND AS A RULE, NOT A FLAG.
*
*     This is not a matter of taste. On the 4.x API:
*
*       cf.request.alwaysUseProxy   DOES NOT EXIST. It is 3.x, where it
*                                   was esriConfig.defaults.io
*                                   .alwaysUseProxy. Assigning it on
*                                   cf.request adds an unknown property
*                                   and changes nothing - no error, no
*                                   warning, and nothing proxied.
*       cf.request.proxyUrl         is a FALLBACK for a request that
*                                   fails CORS. It routes nothing by
*                                   itself.
*       UU.addProxyRule( )          is what actually routes a request.
*
*     Those two facts together are why the map drew and no parcel ever
*     appeared on it. The layer host is an internal alias with no dot in
*     it (GISSERVER) that only the viewer's resource proxy can resolve.
*     Unproxied, the browser tried to reach it directly and DNS refused -
*     and a DNS failure is not a CORS failure, so the proxyUrl fallback
*     never fired either. The query died as a bare "Failed to fetch",
*     which is exactly what reached the note line. The Esri basemap was
*     unaffected throughout, because its own hosts are real.
*
*     URLPREFIX IS A HOST, NOT AN ORIGIN. addProxyRule normalises the
*     prefix and matches on what follows the scheme, so H goes in rather
*     than O. A rule carrying https:// matches nothing, and fails every
*     bit as silently as the flag it replaces.
*     AND THE PROXY STATE IS REPORTED, not assumed. Three things can go
*     wrong here and the first round of this fix could not tell them
*     apart, because every one of them ends as the same "Failed to
*     fetch" against the layer host:
*
*       C.proxy is blank      - MapUrlSet answered no viewer page, so
*                               there is nothing to route THROUGH. The
*                               whole block below is skipped and no rule
*                               is ever added.
*       the rule was refused  - addProxyRule threw. The first version
*                               caught that into an empty block, which
*                               made a refused rule and a missing proxy
*                               identical on screen. That was a blind
*                               spot of this class's own making.
*       the rule did not match- registered, but not against the host the
*                               layer is actually fetched from.
*
*     PX carries whichever it was into the failure note. GETPROXYRULE( )
*     is asked whether the rule really covers the layer URL - the only
*     answer that comes from the API rather than from our own hopes -
*     and guarded on TYPEOF because it is not worth another activation
*     round if this version does not expose it.
      |var PX="no proxy configured - nothing to route through";| &&
      |if(C.proxy)\{cf.request.proxyUrl=C.proxy;| &&
      |try\{UU.addProxyRule(\{urlPrefix:H,proxyUrl:C.proxy\});| &&
      |PX="rule "+H+" -> "+C.proxy;\}| &&
      |catch(e2)\{PX="rule refused: "+(e2&&e2.message?e2.message:e2);\}| &&
*     And the property layer, when it sits on a different host. The same
*     host is the normal case, and a duplicate rule is refused, so this
*     is guarded rather than assumed.
      |if(C.props)\{var q8=C.props.indexOf("/",8);| &&
      |var O2=q8>0?C.props.substring(0,q8):C.props;| &&
      |var H2=O2.substring(O2.indexOf("//")+2);| &&
      |if(H2&&H2!==H)\{| &&
      |try\{UU.addProxyRule(\{urlPrefix:H2,proxyUrl:C.proxy\});\}| &&
      |catch(e3)\{\}\}\}| &&
      |if(typeof UU.getProxyRule==="function")\{| &&
      |PX=PX+(UU.getProxyRule(C.parcels)?" (matched)":" (NOT matched)");\}| &&
      |\}| &&
*     The token as well, when there is one. Belt and braces: the proxy is
*     what actually authenticates on this system, and MapUrlSet's TOKEN
*     column is empty - but a system that does answer one should use it.
      |if(C.token)\{| &&
      |IM.registerToken(\{server:C.parcels,token:C.token,ssl:true\});| &&
      |cf.request.interceptors.push(\{urls:O,before:function(p)\{| &&
      |if(!p.requestOptions.query)\{p.requestOptions.query=\{\};\}| &&
      |if(!p.requestOptions.query.token)\{p.requestOptions.query.token=C.token;\}| &&
      |\}\});\}|.

*   THE QUOTE CHARACTER, BUILT AT RUNTIME. PARCELID IN (...) needs literal
*   single quotes and this snippet may not contain one - see the header.
*   String.fromCharCode(39) is the only way to have both.
*
*   The renderer and the label are Map.js's, value for value: a
*   near-transparent fill so the imagery underneath still reads, a dashed
*   #0079c1 outline, and the parcel number in white on a black halo.
    DATA(lv_lay) =
      |var Q=String.fromCharCode(39);| &&
      |var W=C.ids.length?("PARCELID IN ("+C.ids.map(function(x)| &&
      |\{return Q+x+Q;\}).join(",")+")"):"1=0";| &&
      |var R=\{type:"simple",symbol:\{type:"simple-fill",| &&
      |color:[0,0,0,0.001],outline:\{color:"#0079c1",width:2,style:"dash"\}\}\};| &&
      |var LB=[\{labelExpressionInfo:\{expression:"$feature.PARCELID"\},| &&
      |symbol:\{type:"text",color:"white",haloColor:"black",haloSize:"1px",| &&
      |font:\{size:12,family:"sans-serif",weight:"bold"\}\}\}];| &&
      |var LY=[];| &&
      |var P=new FL(\{id:"ParcelLayer",url:C.parcels,definitionExpression:W,| &&
      |renderer:R,labelingInfo:LB,outFields:["*"]\});LY.push(P);| &&
      |if(C.props)\{LY.push(new FL(\{id:"PropertyLayer",url:C.props,| &&
      |definitionExpression:W,renderer:R,labelingInfo:LB,outFields:["*"]\}));\}|.

    DATA(lv_view) =
      |var mp=new M(\{basemap:"satellite",layers:LY\});| &&
      |var vw=new MV(\{container:D,map:mp,zoom:{ c_zoom },| &&
      |center:[{ c_lon },{ c_lat }],| &&
      |highlightOptions:\{color:[191,19,19],haloOpacity:0.7,fillOpacity:0\}\});|.

*   ZOOM TO WHAT WAS ASKED FOR, and highlight it - Map.js does the same
*   two things through queryFeatures, view.highlight and view.goTo. The
*   difference is only that a details dialog asks for ONE parcel and the
*   selector asks for all of them.
*   ZOOMING TO THE EXTENT, NOT TO THE FEATURES, and saying what happened.
*
*   goTo( features ) frames a single parcel edge to edge with no margin,
*   so it reads as a shape rather than as a place. Unioning the extents
*   and expanding by 60% is what puts the surrounding streets back in.
*   A geometry with no extent - a point - has nothing to expand, so that
*   one case asks for a zoom level instead.
*
*   THE SPATIAL REFERENCE IS THE VIEW'S, not 4326. Map.js asks for 4326
*   and hands whole FEATURES to goTo, which reprojects them; unioning and
*   expanding extents means doing arithmetic on them, and that must not
*   cross a projection half way through.
*
*   AND EVERY OUTCOME IS WRITTEN INTO THE NOTE LINE. A satellite basemap
*   proves only that the ArcGIS API loaded - it comes from Esri, not from
*   RAK - so a map that draws beautifully and shows no parcel is exactly
*   what a refused proxy call, a wrong layer alias and a PARCELID that
*   does not match all look like. N( ) is the difference between those
*   three and another round of guessing.
    DATA(lv_go) =
      |vw.when(function()\{| &&
      |var q=C.focus?("PARCELID IN ("+Q+C.focus+Q+")"):W;| &&
      |function Z(w,again)\{| &&
      |P.queryFeatures(\{where:w,outFields:["*"],returnGeometry:true,| &&
      |outSpatialReference:vw.spatialReference\}).then(function(r)\{| &&
*     \|\| - a literal pipe ends an ABAP string template, so JavaScript
*     OR has to be escaped inside one. Unescaped, the literal closes
*     mid-expression and the class will not activate.
      |if(!r.features\|\|!r.features.length)\{| &&
*     THE FOCUSED PARCEL MATCHED NOTHING. Fall back to the whole owned
*     set once rather than leaving the map at its default extent with no
*     highlight and no explanation - and say so, because a stored value
*     and a GIS layer disagreeing about zero-padding looks identical to
*     a layer that answered nothing at all.
      |N("No feature matched "+w+(again?" - showing all instead":""));| &&
      |if(again)\{Z(W,false);\}return;\}| &&
      |var ex=null;| &&
      |for(var i=0;i<r.features.length;i++)\{| &&
      |var g=r.features[i].geometry;if(!g\|\|!g.extent)\{continue;\}| &&
      |ex=ex?ex.union(g.extent):g.extent.clone();\}| &&
      |var opt=ex?\{target:ex.expand(1.6)\}:\{target:r.features,zoom:18\};| &&
      |vw.goTo(opt).catch(function()\{\});| &&
      |vw.whenLayerView(P).then(function(lv)\{| &&
      |lv.highlight(r.features);\}).catch(function()\{\});| &&
      |N(r.features.length+" parcel(s) drawn"+| &&
      |(C.focus?", zoomed to "+C.focus:""));| &&
      |\}).catch(function(e)\{| &&
*     THE MESSAGE ALONE IS NOT ENOUGH, and this is what cost the round
*     that led here. "Failed to fetch" is what a browser says for every
*     request that never reached a server - a dotless alias, a blocked
*     origin, a CSP refusal and an unproxied host are all identical in
*     it. An ArcGIS error carries DETAILS.URL, which is the one fact
*     that separates them: if it starts with the proxy the rule applied
*     and the far side refused; if it starts with the layer host the
*     rule did not apply at all.
      |var dt=(e&&e.details)?e.details:\{\};| &&
      |N("The parcel layer refused the query: "+| &&
      |(e&&e.message?e.message:e)+| &&
      |(dt.httpStatus?" (HTTP "+dt.httpStatus+")":"")+| &&
      |(dt.url?" - tried "+dt.url:" - no URL reported")+| &&
*     AND THE PROXY STATE. The URL alone said "the rule did not apply"
*     but not why, which is one round short: a blank proxy, a refused
*     rule and a rule on the wrong host all reach this same line.
      |" - proxy: "+PX);| &&
      |\});\}| &&
      |Z(q,C.focus?true:false);|.

*   THE CLICK, with the one guard Map.js also has: a parcel the citizen
*   does NOT own is ignored rather than selected. eB is z2ui5's backend
*   event entry point - the same one the generated view XML binds every
*   press to - so a map click and a card press arrive identically.
    DATA(lv_click) =
      |if(C.evt)\{vw.on("click",function(e)\{| &&
      |vw.hitTest(e).then(function(h)\{| &&
      |var g=(h.results\|\|[]).map(function(x)\{return x.graphic;\})| &&
      |.filter(function(x)\{return x&&x.attributes&&x.attributes.PARCELID;\})[0];| &&
      |if(!g)\{return;\}var id=String(g.attributes.PARCELID);| &&
      |if(C.ids.indexOf(id)<0)\{return;\}| &&
      |try\{z2ui5[C.ctrl].eB([C.evt+"~"+id]);\}catch(x)\{\}| &&
      |\}).catch(function()\{\});| &&
      |\});\}|.

*   AN EXPRESSION, not a statement. _runCustomJs evaluates the snippet as
*   Function("return " + snippet)( ), so an IIFE is what it has to be - a
*   bare function declaration would define something and run nothing.
    rv = |(function()\{| && lv_c && lv_head && lv_load && lv_req &&
         lv_lay && lv_view && lv_go && lv_click &&
         |\});| &&
         |\}catch(e)\{F("The map could not be started: "+e);\}| &&
         |\});\});| &&
         |\}())|.

  ENDMETHOD.

ENDCLASS.
