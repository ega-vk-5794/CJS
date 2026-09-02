CLASS zcl_rak_cj_gis DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& RakMap.Map, rebuilt as a CJS renderer.
*&
*& BUILD map-fix-3.  Missing this line means SAP has an older copy - see
*& the note on unticked 'Overwrite local object' rows in ZRAK_CJ_MAP_DIAG.
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
*&   MapUrlSet ..... PORTAL_URL, SERVER_URL and TOKEN, read per parcel
*&                   through ZCL_RAK_PROPERTY_API->MAP_URL( ).
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
           END OF ty_cfg.

*   The four endpoints, ZRAK_T_CJ_TXT first and the constants after.
    CLASS-METHODS cfg RETURNING VALUE(rs) TYPE ty_cfg.

*   Is there enough configuration to draw the real map? FALSE means the
*   caller should fall back - it is never a reason to draw an empty box.
    CLASS-METHODS ready RETURNING VALUE(rv) TYPE abap_bool.

*   THE MARKUP. Goes to Z2UI5_CL_XML_VIEW->HTML( ). It carries no script -
*   see the header for why one there would never run - and it carries a
*   visible "loading" line, so a grey box means the markup never reached
*   the page and a stuck "loading" means the script did not.
*
*   IV_DIV     the id of the container. Must be unique on the page.
*   PREFERRED PARAMETER, because CONTAINER( lv_div ) is how this reads at
*   every call site. Without it the short form is a syntax error the
*   moment a method has more than one importing parameter - a DEFAULT
*   does not make the second one invisible.
    CLASS-METHODS container
      IMPORTING iv_div    TYPE string
                iv_height TYPE string DEFAULT '26rem'
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
*   NOT TYPED ON ZCL_RAK_PROPERTY_API. Three plain strings instead of its
*   TY_MAP_RES: that class inherits the generated legacy DPC, and a static
*   reference to anything in that chain stops THIS class loading whenever
*   any link in it is inactive. The caller already lives inside the
*   dynamic zone and can unpack the read itself.
    CLASS-METHODS script
      IMPORTING iv_portal    TYPE string
                iv_server    TYPE string
                iv_token     TYPE string
                iv_div       TYPE string
                it_ids       TYPE string_table
                iv_focus     TYPE string OPTIONAL
                iv_event     TYPE string OPTIONAL
                iv_ctrl      TYPE string DEFAULT 'oController'
      RETURNING VALUE(rv)    TYPE string.

  PRIVATE SECTION.

*   BLANK ON PURPOSE, both of them. See the header: these are the two
*   values that cannot be derived from anything CJS can read, and a
*   plausible-looking guess would draw an empty map in silence. Fill them
*   from the ShapeIt app's envProxy - parcelsLayersUrl plus
*   portalItemParcelsID / portalItemPropertiesID - or set the
*   ZRAK_T_CJ_TXT rows instead.
*   VALUE IS INITIAL, not VALUE ''. A constant of type STRING will not
*   take an empty literal - "the field must be filled" - and the whole
*   class then fails to activate, which is what made ZCL_RAK_CJ_PARCEL
*   report "Method SCRIPT is unknown": a class with no active version has
*   no methods at all, so the error surfaces at the caller and points
*   nowhere near the cause.
    CONSTANTS c_parcels    TYPE string VALUE IS INITIAL.
    CONSTANTS c_properties TYPE string VALUE IS INITIAL.

*   The public ArcGIS CDN. Overridable the same way, because a RAK system
*   that serves the API from its own portal will not reach this one.
    CONSTANTS c_api TYPE string VALUE 'https://js.arcgis.com/4.29/'.
    CONSTANTS c_css TYPE string VALUE 'https://js.arcgis.com/4.29/esri/themes/light/main.css'.

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
  ENDMETHOD.


  METHOD ready.
*   The parcel layer is the one that cannot be done without. The property
*   layer is additive - Map.js draws both, and a system that configures
*   only the first still gets a map with the parcel on it.
    DATA(ls) = cfg( ).
    rv = xsdbool( ls-api IS NOT INITIAL AND ls-parcels IS NOT INITIAL ).
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

*   A VISIBLE LOADING LINE, not an empty div. The three failures this map
*   can have look identical from a screenshot otherwise:
*
*     grey box, no text ....... the markup never reached the page
*     "Loading the map..." .... the markup arrived, the script did not
*     an error sentence ....... both ran and the API or the layer failed
*
*   That distinction is the whole reason this method exists separately.
    rv = |<div id="{ iv_div }" class="rakGisMap" | &&
         |style="width:100%;height:{ iv_height };">| &&
         |<div class="rakGisErr">Loading the map...</div></div>|.

  ENDMETHOD.


  METHOD script.

    DATA(ls_cfg) = cfg( ).
    IF ready( ) = abap_false.
      RETURN.
    ENDIF.

*   PORTAL AND SERVER OUT OF MAPURLSET. Map.js sets esriConfig.portalUrl
*   from envProxy.portalUrl and registers the token against
*   envProxy.serverUrl - two different hosts in the general case, which is
*   why MapUrlSet answers URL and GISURL and not one of them. Whichever
*   arrives is used; a blank one is simply not set.
*
*   The token is a credential. It reaches the page as a JS string, the
*   same place the ShapeIt app puts it, and never as a URL parameter
*   where every proxy on the way would log it.
    DATA(lv_c) =
      |var C=\{api:"{ jsq( ls_cfg-api ) }",css:"{ jsq( ls_cfg-css ) }",| &&
      |parcels:"{ jsq( ls_cfg-parcels ) }",props:"{ jsq( ls_cfg-properties ) }",| &&
      |portal:"{ jsq( iv_portal ) }",server:"{ jsq( iv_server ) }",| &&
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
      |"esri/views/MapView","esri/layers/FeatureLayer"| &&
      |],function(cf,IM,M,MV,FL)\{try\{| &&
      |D.textContent="";| &&
      |if(C.portal)\{cf.portalUrl=C.portal;\}| &&
      |if(C.token&&C.server)\{| &&
      |IM.registerToken(\{server:C.server,token:C.token,ssl:true\});| &&
      |cf.request.interceptors.push(\{urls:C.server,before:function(p)\{| &&
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
    DATA(lv_go) =
      |vw.when(function()\{| &&
      |var q=C.focus?("PARCELID IN ("+Q+C.focus+Q+")"):W;| &&
      |P.queryFeatures(\{where:q,outFields:["*"],returnGeometry:true,| &&
      |outSpatialReference:4326\}).then(function(r)\{| &&
*     \|\| - a literal pipe ends an ABAP string template, so JavaScript
*     OR has to be escaped inside one. Unescaped, the literal closes
*     mid-expression and the class will not activate.
      |if(!r.features\|\|!r.features.length)\{return;\}| &&
      |vw.goTo(\{target:r.features\});| &&
      |vw.whenLayerView(P).then(function(lv)\{lv.highlight(r.features);\});| &&
      |\}).catch(function()\{\});|.

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
