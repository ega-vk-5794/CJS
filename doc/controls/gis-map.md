# The parcel map — two different maps, and which is which

Written from `RAK-eEGA/egardcjeng` `util/Map.js` and `js/gismappingIM.js`. Both were
guessed at for several rounds before either source was read; the guesses are recorded
here so they are not made again.

## SETTLED — the framed map works, and what it took

The parcel dialog's Map tab draws the citizen's parcel, zoomed and outlined, on
`ZCL_RAK_CJ_PARCEL` **map-fix-21**. Five separate faults stood between the frame
rendering and the map drawing, and every one of them was invisible from a
screenshot. In the order they had to be fixed:

| # | fault | why it was invisible |
| --- | --- | --- |
| 1 | The snippet shipped only through `FOLLOW_UP_ACTION( )`, which runs from the **main** view's `onAfterRendering` — and a round trip that only opens a dialog need not repaint the main view. | The frame loaded and sat on its splash logo, exactly as it does when the message is refused. |
| 2 | The load flag was set by `addEventListener("load", …)` **registered from inside the `onload` attribute** — an event that had already fired. | Worked on the first open only, because that one round trip has both channels. Every reopen announced "the viewer did not load" over a viewer that had. |
| 3 | The iframe id was the constant `rakPclMap`. `sap.ui.core.HTML` is a **preserved** control, so reopening on another parcel kept the first parcel's iframe and document. | Only the first parcel ever rendered. Every channel was working — on an element that no longer belonged to the parcel being asked for. |
| 4 | The retry counter was also the post counter (`s()` did `n++`, the interval tested `++n>10`), so retries stopped after 5 ticks — 2.5s. | Intermittent. The viewer attaches its `message` listener late; a post before that is dropped silently. |
| 5 | Widening that window to 12s made it worse: **`DefconReciveMessage` calls `DefconAuth( )` on every message**, so each post restarts the viewer's map. | Nothing drew at all. 24 restarts and it never settled. |

**The rule that came out of 4 and 5 together: what matters is a quiet tail, not a
long window.** The last post must be early enough that an uninterrupted run
follows it. `map-fix-16` worked whenever it worked because its counter bug
clustered 6 posts inside 2.5s and then went silent — the silence was the
mechanism, not the retrying.

### 6 — and the tail was measured from the wrong end

The schedule that came out of 4 and 5 was `0, 250, 750, 1750, 3500` ms **from
markup insertion**, and it left the map intermittent. Nothing about the viewer is
measured from there. What varies, and varies by seconds, is how long the viewer's
own document takes to load and authenticate: on a warm cache the cluster lands
after its listener and the map draws, on a cold one every post is dropped before
the listener exists. Same code, same parcel, different outcome.

A post already went out on the frame's `load`, and one is not enough on its own —
`gismappingIM.js` registers its `message` listener from its own script *after* the
ArcGIS API has been required, work that begins at `load` and ends an unknown time
later.

So the cluster is now anchored to `load`: **`load + 0, +400, +1200`, then
silence**, stopping early if the viewer replies. The start-anchored cluster is
gone, and removing it is a fix rather than a tidy-up — its posts either landed
before the listener, wasted, or just after a fast frame had drawn, restarting a
map that was already correct. A single immediate post stays, because it costs one
message and catches a frame that is already loaded and listening. A floor at 10s
runs the cluster anyway if `load` never fires, which is what a preserved iframe
from an earlier open does.

Simulated against a virtual clock before pushing, since this is the third schedule:

| frame loads at | posts at | last post |
| --- | --- | --- |
| 200 ms | 0, 200, 600, 1400 | 1.2 s after load |
| 2 s | 0, 2000, 2400, 3200 | 1.2 s after load |
| 6 s | 0, 6000, 6400, 7200 | 1.2 s after load — **the case that used to fail** |
| never | 0, 10000, 10400, 11200 | the floor |

Every row ends in a quiet tail, which is the rule from 4 and 5, and the tail is now
1.2 s after the viewer finished loading rather than 3.5 s after CJS drew markup.

### Two things that cannot be observed, and must not be guessed

- **There is no signal that the map has drawn.** The viewer never replies even on
  a successful render, so `no reply` cannot mean failure — a warning keyed on it
  appears underneath working maps. The overlay is therefore lifted on a grace
  period (4.5s, past the last post) and by a CSS fallback, never on evidence.
- **A per-parcel failure could not be told from a race** until the post count was
  put on screen. Which parcel drew *reversed* between two builds that did not
  touch the messaging, which is what ruled out the GIS data — an absent boundary
  cannot alternate. The counter (`map: 5x/4 L`) is gone from the screen again;
  the same figures remain on the note's `title`, and the build/parcel/intreno
  line returns under `MV_TRACE`.

### Verify by content, and the build says so

`ZCL_RAK_CJ_PARCEL` carries `C_BUILD` and prints it in the dialog under trace.
Three rounds here were spent re-diagnosing a build that was not running, because
a pull with the `Overwrite local object` row unticked and a pull that failed to
activate both leave the previous version live with nothing on screen to say so.
Read the build tag before believing anything else.

## CORRECTION — the deployed screen FRAMES the map

**Read this before the rest of the file.** Everything below was derived from `util/Map.js`
and concluded that the live control renders an ArcGIS view *in the application page*. The
DOM of the working **My Properties** screen says otherwise, and the DOM wins:

```
sap-ui-preserve="__xmlview2--mapIframe"
  #document  (https://rakgisstg.rak.ae/CustomerJourneyMap/)
    <html><body><div>
      <div id="welcome" style="display:none">
      <div id="cover-spin" style="display:none">
      <div class="maphoc" style="display:block">
        <div id="mapViewDiv" class="esri-view esri-view-orientation-landscape …">
          <div class="esri-view-root"> … <canvas width="941" height="915">
      <div id="SwitchOverlayDiv" class="switchOverLayClass" style="display:none">
      <div class="forbidden">
```

So the ArcGIS view is real — `esri-view`, `mapViewDiv`, a live canvas, the selected parcel
`310060052` labelled and highlighted — but it is **inside an iframe**, and that iframe's
document is the `CustomerJourneyMap` viewer. `welcome`, `cover-spin`, `SwitchOverlayDiv`
and `forbidden` are the viewer application's own furniture, not a UI5 control's.

### Why this is the whole explanation for "Failed to fetch"

The consequence is not cosmetic. Inside that frame the ArcGIS API is running **on the GIS
host's own origin**, so:

| | in the frame (live) | in the page (what CJS built) |
| --- | --- | --- |
| origin of the ArcGIS code | `rakgisstg.rak.ae` | the SAP application server |
| `proxy.ashx` | **same origin** — just works | cross-origin — needs CORS for the CJS host |
| `gisserver` alias | resolved by the proxy, same origin | unreachable unless the proxy allows us |
| token | the viewer obtains its own | CJS has to inject one |

That is why the live map has no proxy problem and CJS's in-page rebuild cannot get past
one. **The live application never fights the battle `ZCL_RAK_CJS_GIS`'s in-page path is
fighting.** The doc's earlier line — "the in-page ArcGIS path … is the route worth
finishing" — was wrong, and so is CLAUDE.md's summary of it.

It also means `GIS_PARCELS` and `GIS_PROPERTIES` are **not needed on the framed path at
all**: the viewer knows its own layers. Backlog item 6.5's "two strings still to find"
only applies to the in-page route.

### What is not settled by this

- Whether `util/Map.js` is dead, used on a *different* screen, or the control that renders
  *inside* the viewer page. The frame's document is a separate app; `Map.js` could well be
  its map. Not established either way from a DOM.
- Whether the viewer accepts a `postMessage` from the CJS origin. The portal in this trace
  is `rakportal1-….dispatcher.ae1.hana.ondemand.com` — a BTP host, which is evidently on
  the allowlist. CJS is served from `devgrpportal.rak.ae`, which is a different origin and
  has not been shown to be. `<div class="forbidden">` is exactly what appears when
  `DefconOriginValidation` refuses, so the failure mode is visible rather than silent.

`ZCL_RAK_CJ_PARCEL` already frames this exact URL — `viewer_of( )` returns
`https://rakgisstg.rak.ae/CustomerJourneyMap/`, the `src` in the trace above — but only as
a **fallback**, behind `ZCL_RAK_CJ_GIS=>READY( )`. On this evidence the precedence is
backwards.

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
| `GIS_PARCELS` | the parcel layer | `https://gisserver/cadastral/parcel` |
| `GIS_PROPERTIES` | the property layer | `https://gisserver/cadastral/property` |
| `GIS_PROXY` | the resource proxy | blank = derive `<viewer>/proxy.ashx` |

`GIS_PARCELS` blank means `ZCL_RAK_CJ_GIS=>READY( )` is false: the List/Map toggle is not
offered and the details dialog falls back to the iframe below.

### The layers, and the proxy that makes them reachable

Read off the working My Properties screen's own network trace, not guessed. Filtering it
on `query` shows exactly three data calls:

```
proxy.ashx?https://gisserver/cadastral/parcel/query?...&where=Pa...
proxy.ashx?https://gisserver/cadastral/property/query?...&where=P...
proxy.ashx?https://gisserver/addressing/addresspoint/query?...
```

Three things fall out of that at once:

1. **There is no `FeatureServer` anywhere.** Filtering the same trace on `FeatureServer`
   returns nothing — which is why the auto-discovery in `ZRAK_CJ_MAP_DIAG` was hunting for
   the wrong shape entirely.
2. **The layers are addressed by an internal alias**, `gisserver` — a host with no dot in
   it. The browser never resolves it and never contacts it directly.
3. **Every call goes through `proxy.ashx`**, an ArcGIS Resource Proxy hosted by the viewer
   application. That is what resolves the alias, and what carries the credentials — which
   is also why `MapUrlSet`'s `TOKEN` column is empty and nothing appeared to need it.

The proxy address itself is derived from the viewer page `MapUrlSet` already answers:
`https://rakgisstg.rak.ae/CustomerJourneyMap/` + `proxy.ashx`. Move the viewer and the
proxy moves with it.

#### `proxyUrl` is not the mechanism — `addProxyRule` is

This was written here as "`esriConfig.request.proxyUrl` is the whole mechanism", and that
was wrong. It cost a round in which the map drew perfectly and no parcel ever appeared on
it. On the 4.x API:

| what | what it actually does |
| --- | --- |
| `esriConfig.request.proxyUrl` | a **fallback** for a request that fails CORS. Routes nothing by itself. |
| `esriConfig.request.alwaysUseProxy` | **does not exist.** It is 3.x — `esriConfig.defaults.io.alwaysUseProxy`. Assigning it on `cf.request` adds an unknown property: no error, no warning, nothing proxied. |
| `urlUtils.addProxyRule({ urlPrefix, proxyUrl })` | the thing that actually routes a request. `esri/core/urlUtils`. |

`ZCL_RAK_CJ_GIS` set `proxyUrl` and the 3.x flag, so **no request was ever proxied**. The
FeatureLayer went straight at `https://gisserver/cadastral/parcel/query`; `gisserver` is a
dotless internal alias only the proxy can resolve, so DNS refused — and a DNS failure is
not a CORS failure, so even the `proxyUrl` fallback never fired. The query died as a bare

    The parcel layer refused the query: Failed to fetch

The Esri basemap was unaffected throughout, because its own hosts are real. That is the
whole reason a beautiful map and a broken layer looked like one working map.

**`urlPrefix` is a bare hostname, not an origin** — `route.arcgis.com`, not
`https://route.arcgis.com`. The API normalises the prefix and matches on what follows the
scheme, so a rule carrying `https://` matches nothing and fails exactly as silently as the
flag it replaced. The rule is registered for the parcel layer's host, and again for the
property layer's when it differs.

*Verified from the 4.x SDK guide, not from memory. Activation in SAP is outstanding.*

The real ArcGIS roots are on the same host for anything that does not go through the
alias — `https://rakgisstg.rak.ae/server/rest/services/...` and
`.../serverimage/rest/services/Aerial_Imagery_2019/...` for the basemap tiles.

**The open question is CORS.** A resource proxy normally serves the application that hosts
it; CJS calls it from the SAP application server's origin. If the proxy does not return
`Access-Control-Allow-Origin` for that host, the calls are refused in the browser — the
same class of boundary as the viewer's own `postMessage` allowlist, and the same remedy:
the GIS side allows the CJS origin. The console will say so in one line.

### `MapUrlSet`'s columns do not mean what their names say

Measured, not assumed — `ZRAK_CJ_MAP_DIAG` on E10/200, partner `3000401630`:

```
URL     len 236   4gat2CeMnEV2TYJvpD11wTXEDOeWXs4zd2F-4rVdBIJhsiLj742A2Rspl...
GISURL  len 44    https://rakgisstg.rak.ae/CustomerJourneyMap/
TOKEN   len 0
```

**`URL` is the token. `GISURL` is the viewer page. `TOKEN` is empty.** Reading the three
columns by name hands the map a blank token and a token where a URL belongs — which is
exactly what the first version of `ZCL_RAK_CJ_GIS` did. `TOKEN_OF( )` and `VIEWER_OF( )`
are the one place that knows this, and both decide by **shape**, so a system that fills
the columns as their names suggest still works.

**The ArcGIS server is not in that answer at all.** `/CustomerJourneyMap` is a web
application path, not a REST root. So the server the token is good for is derived from
`GIS_PARCELS`' own origin — the only place it is genuinely known, one fewer value to
configure and one fewer that can be configured inconsistently.

The token reaches the page as a JS string, the same place the ShapeIt app puts it, and
never as a URL parameter.

### SAP cannot reach the GIS host, and that does not block the map

```
base https://rakgisstg.rak.ae/CustomerJourneyMap
  /rest/info   HTTP 0 receive failed: Direct connect to rakgisstg.rak.ae:443
               failed: NIECONN_REFUSED(-10)
```

No route from the application server to the GIS host. This blocks the **discovery** in
`ZRAK_CJ_MAP_DIAG` and nothing else: when the map runs it is the **browser** that talks to
the GIS server, and the browser reaches it perfectly well — the viewer's own page loads in
the dialog. So `GIS_PARCELS` has to be read off the live ShapeIt screen instead: open the
legacy parcel control, network tab, and take the `.../FeatureServer/<n>/query` request's
URL up to the layer number.

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

**And it may not be reachable from CJS at all.** `DefconReciveMessage` validates the
**sender's** origin before it reads anything, against the viewer's own allowlist — which
holds the portal's hosts. CJS is served from the SAP application server, a different
origin. So a correctly addressed, correctly timed message can still be discarded, and the
viewer then sits on its splash screen *exactly* as it does when no message arrives at all.
The two are indistinguishable from a screenshot, which is why the frame now prints both
origins underneath it: what the frame is, and what we are to it. If that line appears and
the viewer still shows only its logo, the fix is on the GIS side — add the CJS host to the
allowlist — not in this repository.

The in-page ArcGIS path has no such gate: it is REST calls carrying a token, and origin
never enters into it. That is the route worth finishing.

## Why it never worked, for six rounds

Not the URL, not the token, not CSP. **A `<script>` block inside `html( )` never
executes.** `Z2UI5_CL_XML_VIEW->HTML( )` sets the `content` property of
`sap.ui.core.HTML`, which reaches the DOM as innerHTML, and a script element inserted
through innerHTML is inert by specification — parsed, kept, never run. Nothing is logged
and nothing is thrown.

So the iframe rendered, the viewer sat on its splash screen waiting for a `postMessage`
that was never sent, and that is indistinguishable on screen from a wrong URL. Six rounds
went into the URL.

This repository already knew: `ZCL_RAK_JOURNEY_RENDER->RENDER_UPLOADER( )` puts its
FileReader in an `onchange=` **attribute** — an inline event attribute does run — and
the engine carries a message that says "inline scripts are blocked".

**Two channels, because one was not enough.**

`Z2UI5_IF_CLIENT->FOLLOW_UP_ACTION( )` stashes the snippet as `pendingCustomJs` and runs it
in the `finally` block of `_processAfterRendering`. That looked sufficient — until the
details dialog rendered its container and the snippet never fired. `_processAfterRendering`
hangs off the **main view's** `onAfterRendering`, and a round trip that only opens a popup
need not re-render the main view. "Loading the map…" on screen, for ever.

So the snippet is *also* carried in an **inline event attribute** — the `onload` of a 1×1
transparent data-URI image inside the container. An inline event attribute is the one
JavaScript delivery that has always worked here (`RENDER_UPLOADER( )`'s `onchange=`
FileReader), because it is the browser parsing markup rather than a framework choosing a
moment.

Both stay. The snippet guards on `dataset.rakGis`, so whichever arrives first wins and the
other is a no-op. **Two independent deliveries and an idempotent payload beat one delivery
and a lifecycle assumption.** The attribute is single-quoted, and the snippet is already
guaranteed free of single quotes for `follow_up_action`'s sake — so one text serves both
channels with no second encoding.

The iframe fallback got the same treatment: its `postMessage` now also hangs off the
frame's own `onload`, which is better timing than the retry interval as well as a second
channel.

**And the braces have to be escaped.** The markup travels as an XML view *attribute*
(`sap.ui.core.HTML`'s `content`), and UI5's XML parser reads `{ }` in an attribute value as
a binding expression — so an unescaped snippet full of JavaScript object literals parses as
dozens of malformed bindings and the control never renders at all. `\{` and `\}`, exactly
as `RENDER_UPLOADER( )` has done since its FileReader went into an `onchange=`.

**And not one single quote may appear in the snippet.** `Server._runCustomJs` splits the
text on `'` and, if it finds any, calls `oController.eF(...args)` with the pieces —
a *frontend action*, not the code:

```js
const parts = item.split("'");
const args = parts.filter((_, index) => index % 2 === 1);
if (args.length > 0) { oController.eF(...args); }
else { Function("return " + parts[0])(); }
```

One stray quote turns the whole map into a call to an action that does not exist. Every
string in `SCRIPT( )` is double-quoted; the SQL-style `PARCELID IN ('…')` list builds its
quote character at runtime with `String.fromCharCode(39)`. The snippet must also be an
**expression**, because it is evaluated as `Function("return " + snippet)()` — hence the
IIFE.

### The basemap is not evidence

The `satellite` basemap comes from Esri's own public services, not from RAK. A map that
draws beautiful imagery therefore proves one thing only: **the ArcGIS API loaded**. It says
nothing about whether the parcel layer answered — and a refused proxy call, a wrong layer
alias and a `PARCELID` that does not match all look exactly the same: a lovely satellite
view of Ras Al Khaimah at the default extent, with no parcel on it.

So the snippet writes its outcome into a status line under the map — a sibling of the map
div, because the `MapView` owns everything inside its own container and wipes it the moment
it draws:

| what the line says | what it means |
| --- | --- |
| *(empty)* | the map worked; nothing to report |
| `3 parcel(s) drawn, zoomed to 313030024` | the layer answered and the view moved |
| `No feature matched PARCELID IN ('…') - showing all instead` | the layer is reachable but that id is not in it — usually zero-padding |
| `The parcel layer refused the query: …` | the proxy or the service said no, in its own words |

And that last line now carries **the URL it actually tried**, plus the HTTP status when
there was one, because the message alone cannot distinguish the failures that matter:
`Failed to fetch` is what a browser says for *every* request that never reached a server —
a dotless alias, a blocked origin, a CSP refusal and an unproxied host are identical in it.
`e.details.url` is the one fact that separates them:

| the URL reported | what it means |
| --- | --- |
| starts with the **proxy** | the rule applied; the far side refused — CORS or credentials, on the GIS side |
| starts with the **layer host** | the rule did not apply at all; the proxy wiring is still wrong here |
| `no URL reported` | the error came from before the request was composed |

And it zooms to the **extent**, expanded by 60%, rather than to the features: `goTo(features)`
frames a single parcel edge to edge with no margin, so it reads as a shape rather than as a
place. The geometry is requested in the view's own spatial reference rather than 4326,
because unioning and expanding extents is arithmetic and must not cross a projection half
way through.

### Telling the three failures apart

`CONTAINER( )` ships with a visible "Loading the map…" line, because otherwise the three
ways this can fail look identical on a screenshot:

| what you see | what happened |
| --- | --- |
| bare grey box | the markup never reached the page |
| "Loading the map…", stuck | the markup arrived, the script did not run |
| a sentence | both ran; the API or the layer failed, and it says which |

## Diagnosis: `ZRAK_CJ_MAP_DIAG`

Run it before theorising. It prints `URL`, `GISURL` and `TOKEN` **in full** — every theory
about this map has been a theory about the shape of those three strings, and none of them
had been read out loud — then asks the GIS server directly:

1. `/rest/info` — can this SAP system reach the host at all? An untrusted certificate or a
   missing proxy shows up here as a status, rather than as a blank map three layers away.
2. `/rest/services` — the folders and services.
3. each `FeatureServer` / `MapServer`, then each layer, looking for one that carries a
   **`PARCELID`** field. That layer is `GIS_PARCELS`.
4. the markup and the snippet CJS would emit, with the token masked, and whether the
   snippet contains a single quote.

`P_WRITE` stores what it found into `ZRAK_T_CJ_TXT`. So the two endpoints `Map.js` takes
from the ShapeIt app's own configuration are discoverable from the same token the map
already gets — they never needed the UI5 repository.

## CSP

`Z2UI5_CL_EXIT` grants `js.arcgis.com`, `*.arcgis.com`, `*.arcgisonline.com`, `*.rak.ae`
and `blob:` in `default-src` and `connect-src`, and keeps `frame-src 'self'
https://*.rak.ae` for the iframe path. Without `connect-src` the map draws its frame and
nothing else: every feature query is an XHR.
