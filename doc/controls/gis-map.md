# The parcel map — two different maps, and which is which

Written from `RAK-eEGA/egardcjeng` `util/Map.js` and `js/gismappingIM.js`. Both were
guessed at for several rounds before either source was read; the guesses are recorded
here so they are not made again.

## `RakMap.Map` — the one the parcel dialog draws

`util/Map.js` is a `sap.ui.core.Control`. Its renderer writes one bare `<div>`, and
`createMap( )` then loads the **ArcGIS JS API into the application page**:

```js
require(["esri/Map","esri/views/MapView","esri/layers/FeatureLayer",
         "esri/identity/IdentityManager","esri/config", ...],
  (Map, MapView, FeatureLayer, IdentityManager, esriConfig, ...) => {
    esriConfig.portalUrl = envProxy.portalUrl;
    IdentityManager.registerToken(envProxy.token);
    ...
```

It is **not an iframe**. Everything below comes from that file:

| | |
| --- | --- |
| identity | `IdentityManager.registerToken(token)`, then again with `token.server = envProxy.serverUrl`. Request interceptors append `envProxy.token.token` as a `token` query parameter for the portal, the server and the imagery service. |
| the citizen's parcels | `envProxy.ownedProperties`, an array of parcel numbers **unpadded**. Every layer is filtered with `PARCELID IN ('a','b',…)` built from it — units use `UnitID`, floors `FloorID`, buildings `BldID`. |
| selection | `setParcelId( )` maintains `envProxy.selectedIds`; `ParcelModel>/settings/bMulti` decides whether a press adds to the list or replaces it. `envProxy` is a `Proxy` whose setter calls `updateView( )` whenever `selectedIds` changes. |
| what selection looks like | `queryFeatures` per layer, then `view.highlight(features)` and `view.goTo({target: features})`. Highlight colour `[191,19,19]`, `haloOpacity 0.7`, `fillOpacity 0`. |
| the click | `view.on("click")` → `view.hitTest` → **ignored unless the clicked `PARCELID` is in `ownedProperties`** → `setParcelId( )` and an EventBus publish `qvShaperEvents / parcelSelected`. Gated on `ParcelModel>/settings/bMap` and `/isDesktop`. |
| the view | centre `[55.9504, 25.7766]`, zoom 14, basemap `satellite`, plus a `BasemapGallery` in an `Expand` offering an aerial-imagery tile layer. |
| parcel symbology | `simple-fill`, colour `[0,0,0,0.001]`, outline `#0079c1` width 2, style `dash`; label `$feature.PARCELID` in white on a 1px black halo, bold 12px. |
| 3D | buildings, floors and units are `polygon-3d` extrusions on `SceneView` with `world-elevation`. The parcel **selector** uses them; a flat parcel map does not. |

### What CJS does with it

`ZCL_RAK_CJ_GIS` reproduces the flat half: token registration, the parcel (and property)
feature layer filtered to the citizen's own parcels, the same renderer and labels, the same
centre and zoom, `goTo` + `highlight`, and an optional click that raises a normal CJS
backend event through z2ui5's `eB`. `ZCL_RAK_CJ_PARCEL` uses it twice — the details
dialog's Map tab (one parcel, no click) and a List/Map toggle on the selector itself
(every owned parcel, click to select).

**Four endpoints are configuration, and two of them are blank until somebody fills them
in.** `Map.js` takes them from an `envProxy` the ShapeIt app assembles from its own
config, which lives in the UI5 repository and is in no service CJS can read:

| `ZRAK_T_CJ_TXT-MSGNO` | what it is | default |
| --- | --- | --- |
| `GIS_API` | the ArcGIS JS API | `https://js.arcgis.com/4.29/` |
| `GIS_CSS` | its stylesheet | the matching `main.css` |
| `GIS_PARCELS` | the parcel layer, `<feature service>/<layer id>` | **blank** |
| `GIS_PROPERTIES` | the property layer, same shape | **blank** |

`GIS_PARCELS` blank means `ZCL_RAK_CJ_GIS=>READY( )` is false: the List/Map toggle is not
offered and the details dialog falls back to the iframe below. That is deliberate — a
guessed feature-service URL draws an empty map in silence, which is the most expensive of
the three failures this map has already had.

Identity comes from `MapUrlSet` (`ZCL_RAK_PROPERTY_API->MAP_URL( )`), filtered by
`Partnerguid` and `Parcel`: `URL` → `esriConfig.portalUrl`, `GISURL` → the token's server,
`TOKEN` → the token. The token reaches the page as a JS string, the same place the ShapeIt
app puts it, and never as a URL parameter.

## `gismappingIM.js` — the standalone Defcon viewer

A separate site, embedded in an iframe, which **loads bare**: `parcelId`, `token` and
`lang` arrive by `postMessage` and never in the URL.

```js
function DefconReciveMessage(messageData, origin) {
  if (!DefconOriginValidation(origin)) { showForbidden(); return; }
  if (messageData.parcelId) { Param_ParcelId = messageData.parcelId; }
  if (messageData.token)    { Param_Token    = messageData.token;    }
  if (messageData.lang)     { App_Language   = messageData.lang;     }
  DefconAuth();
}
```

Six URL shapes were tried against this before the file was read (`?token=`, a path join,
`GISURL` alone, `URL` alone, a scheme upgrade, a CSP widening) and none of them could ever
have worked — the viewer was sitting on its splash screen waiting for a message that never
came. CJS posts the three values on the frame's `load`, on a handshake message from the
viewer, and on a retry interval that gives up after ten attempts.

This remains the fallback path in the details dialog. It is a real page and a real map; it
is simply not the control the parcel dialog was drawing.

## CSP

`Z2UI5_CL_EXIT` grants `js.arcgis.com`, `*.arcgis.com`, `*.arcgisonline.com`, `*.rak.ae`
and `blob:` in `default-src` and `connect-src`, and keeps `frame-src 'self'
https://*.rak.ae` for the iframe path. Without `connect-src` the map draws its frame and
nothing else: every feature query is an XHR.
