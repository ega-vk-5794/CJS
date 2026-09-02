CLASS zcl_rak_cj_gis DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& RakMap.Map, rebuilt as a CJS renderer.
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

*   The <div> and the script that fills it.
*
*   IV_DIV     the id of the container. Must be unique on the page.
*   IT_IDS     every parcel the layer may show - the citizen's own
*              properties, UNPADDED, the way Map.js holds ownedProperties.
*   IV_FOCUS   the one to zoom to and highlight. Blank zooms to all.
*   IV_EVENT   a CJS backend event name; when filled, clicking a parcel
*              the citizen owns raises |<IV_EVENT>~<parcelid>|. Blank
*              draws a map that cannot be clicked, which is what the
*              details dialog wants.
*   IV_CTRL    which z2ui5 controller carries that event - 'oController'
*              in the page, 'oControllerPopup' inside a dialog.
*   NOT TYPED ON ZCL_RAK_PROPERTY_API. Three plain strings instead of its
*   TY_MAP_RES: that class inherits the generated legacy DPC, and a static
*   reference to anything in that chain stops THIS class loading whenever
*   any link in it is inactive. The caller already lives inside the
*   dynamic zone and can unpack the read itself.
    CLASS-METHODS block
      IMPORTING iv_portal    TYPE string
                iv_server    TYPE string
                iv_token     TYPE string
                iv_div       TYPE string
                it_ids       TYPE string_table
                iv_focus     TYPE string OPTIONAL
                iv_event     TYPE string OPTIONAL
                iv_ctrl      TYPE string DEFAULT 'oController'
                iv_height    TYPE string DEFAULT '26rem'
      RETURNING VALUE(rv)    TYPE string.

  PRIVATE SECTION.

*   BLANK ON PURPOSE, both of them. See the header: these are the two
*   values that cannot be derived from anything CJS can read, and a
*   plausible-looking guess would draw an empty map in silence. Fill them
*   from the ShapeIt app's envProxy - parcelsLayersUrl plus
*   portalItemParcelsID / portalItemPropertiesID - or set the
*   ZRAK_T_CJ_TXT rows instead.
    CONSTANTS c_parcels    TYPE string VALUE ''.
    CONSTANTS c_properties TYPE string VALUE ''.

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

*   A value on its way into a JS string literal. Single quotes and
*   backslashes cannot reach one intact, and these values come from a
*   backend read rather than from this code.
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
    REPLACE ALL OCCURRENCES OF `\` IN rv WITH `\\`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `\'`.
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
    LOOP AT it INTO DATA(lv).
      DATA(lv_c) = condense( lv ).
      IF lv_c IS INITIAL.
        CONTINUE.
      ENDIF.
      rv = COND string( WHEN rv IS INITIAL THEN |'{ jsq( lv_c ) }'|
                        ELSE |{ rv },'{ jsq( lv_c ) }'| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD block.

    DATA(ls_cfg) = cfg( ).
    IF ready( ) = abap_false.
      RETURN.
    ENDIF.

*   PORTAL AND SERVER OUT OF MAPURLSET. Map.js sets esriConfig.portalUrl
*   from envProxy.portalUrl and registers the token against
*   envProxy.serverUrl - two different hosts in the general case, which is
*   why MapUrlSet answers URL and GISURL and not one of them. Whichever
*   arrives is used; a blank one simply is not set, and the API falls back
*   to its own default portal.
    DATA(lv_portal) = jsq( iv_portal ).
    DATA(lv_server) = jsq( iv_server ).
    DATA(lv_token)  = jsq( iv_token ).

*   The token is a credential. It goes into the page as a JS string - the
*   same place the ShapeIt app puts it - and never into a URL, a link or
*   an iframe src, where it would be logged by every proxy on the way.
    DATA(lv_ids)   = in_list( it_ids ).
    DATA(lv_focus) = jsq( iv_focus ).
    DATA(lv_evt)   = jsq( iv_event ).
    DATA(lv_ctrl)  = jsq( iv_ctrl ).

*   The container. Height is fixed rather than flexed: a MapView in a box
*   of height 0 initialises, reports no errors and draws nothing, which is
*   exactly what an empty tab looks like.
    rv = |<div id="{ iv_div }" class="rakGisMap" | &&
         |style="width:100%;height:{ iv_height };"></div>| &&
         |<script>(function()\{| &&
         |var D=document.getElementById('{ iv_div }');| &&
*        A LITERAL PIPE MUST BE ESCAPED. | ends an ABAP string template,
*        so JavaScript's || has to be written \|\| inside one - unescaped
*        it closes the literal mid-expression and the class does not
*        activate. Three of these in the block below.
         |if(!D\|\|D.dataset.rakGis==='1')return;| &&
         |D.dataset.rakGis='1';| &&
         |var C=\{| &&
           |api:'{ jsq( ls_cfg-api ) }',css:'{ jsq( ls_cfg-css ) }',| &&
           |parcels:'{ jsq( ls_cfg-parcels ) }',| &&
           |props:'{ jsq( ls_cfg-properties ) }',| &&
           |portal:'{ lv_portal }',server:'{ lv_server }',token:'{ lv_token }',| &&
           |ids:[{ lv_ids }],focus:'{ lv_focus }',| &&
           |evt:'{ lv_evt }',ctrl:'{ lv_ctrl }'| &&
         |\};|.

*   LOADED BY SCRIPT ELEMENT, not by a <script src> in this markup.
*   sap.ui.core.HTML hands the markup to jQuery, and whether an external
*   script written into innerHTML is fetched and run is exactly the kind
*   of thing that differs between UI5 versions. Appending the element
*   ourselves does not differ.
    rv = rv &&
         |function F(m)\{D.innerHTML='<div class="rakGisErr">'+m+'</div>';\}| &&
         |function L(cb)\{| &&
           |if(window.require&&window.require.__esri)\{cb();return;\}| &&
           |if(C.css)\{var l=document.createElement('link');l.rel='stylesheet';| &&
           |l.href=C.css;document.head.appendChild(l);\}| &&
           |var s=document.createElement('script');s.src=C.api;s.onload=cb;| &&
           |s.onerror=function()\{F('The map library could not be loaded.');\};| &&
           |document.head.appendChild(s);\}|.

    rv = rv &&
         |L(function()\{require([| &&
           |"esri/config","esri/identity/IdentityManager","esri/Map",| &&
           |"esri/views/MapView","esri/layers/FeatureLayer"| &&
         |],function(cf,IM,M,MV,FL)\{try\{| &&
           |if(C.portal)\{cf.portalUrl=C.portal;\}| &&
           |if(C.token&&C.server)\{| &&
             |IM.registerToken(\{server:C.server,token:C.token,ssl:true\});| &&
             |cf.request.interceptors.push(\{urls:C.server,before:function(p)\{| &&
             |if(!p.requestOptions.query)\{p.requestOptions.query=\{\};\}| &&
             |if(!p.requestOptions.query.token)\{p.requestOptions.query.token=C.token;\}| &&
             |\}\});\}|.

*   THE RENDERER AND THE LABEL ARE MAP.JS'S, VALUE FOR VALUE. A parcel is
*   drawn as a near-transparent fill so the imagery underneath still
*   reads, with a dashed #0079c1 outline and its PARCELID in white on a
*   black halo.
    rv = rv &&
         |var W=C.ids.length?("PARCELID IN ("+C.ids.map(function(x)| &&
         |\{return "'"+x+"'";\}).join(",")+")"):"1=0";| &&
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

    rv = rv &&
         |var mp=new M(\{basemap:"satellite",layers:LY\});| &&
         |var vw=new MV(\{container:D.id,map:mp,zoom:{ c_zoom },| &&
         |center:[{ c_lon },{ c_lat }],| &&
         |highlightOptions:\{color:[191,19,19],haloOpacity:0.7,fillOpacity:0\}\});|.

*   ZOOM TO WHAT WAS ASKED FOR, and highlight it. Map.js does the same
*   two things through queryFeatures + view.highlight + view.goTo; the
*   difference here is that a details dialog asks for ONE parcel and the
*   selector asks for all of them.
    rv = rv &&
         |vw.when(function()\{| &&
           |var q=C.focus?("PARCELID IN ('"+C.focus+"')"):W;| &&
           |P.queryFeatures(\{where:q,outFields:["*"],returnGeometry:true,| &&
           |outSpatialReference:4326\}).then(function(r)\{| &&
             |if(!r.features\|\|!r.features.length)\{return;\}| &&
             |vw.goTo(\{target:r.features\});| &&
             |vw.whenLayerView(P).then(function(lv)\{lv.highlight(r.features);\});| &&
           |\}).catch(function()\{\});|.

*   THE CLICK, and the one guard Map.js also has: a parcel the citizen
*   does NOT own is ignored rather than selected. eB is z2ui5's backend
*   event entry point - the same one the generated view XML binds every
*   press to - so a map click and a button press arrive identically.
    rv = rv &&
         |if(C.evt)\{vw.on("click",function(e)\{| &&
           |vw.hitTest(e).then(function(h)\{| &&
             |var g=(h.results\|\|[]).map(function(x)\{return x.graphic;\})| &&
             |.filter(function(x)\{return x&&x.attributes&&x.attributes.PARCELID;\})[0];| &&
             |if(!g)\{return;\}var id=String(g.attributes.PARCELID);| &&
             |if(C.ids.indexOf(id)<0)\{return;\}| &&
             |try\{z2ui5[C.ctrl].eB([C.evt+'~'+id]);\}catch(x)\{\}| &&
           |\}).catch(function()\{\});| &&
         |\});\}| &&
         |\});| &&
         |\}catch(e)\{F('The map could not be started: '+e);\}| &&
         |\});\});| &&
         |\})();</script>|.

  ENDMETHOD.

ENDCLASS.
