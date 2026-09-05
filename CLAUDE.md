# CJS — Customer Journey Studio

Metadata-driven wizard engine for RAK government services. ABAP + [abap2UI5](https://github.com/abap2UI5/abap2UI5).
A service is **rows in `ZRAK_T_JNY*`**, not a program: one generic engine renders, validates and
posts it. ABAP is for what configuration cannot express.

Full detail is in [README.md](README.md). This file is the short version plus the rules that
have already cost time when broken.

## Settled — do not reopen these two

Both cost many rounds, both are **verified working on E10/200**, and both fail in ways that
look like something else. Change either only for a defect you can demonstrate, and read the
reasoning first — every plausible-looking "improvement" listed below has already been tried
and was wrong.

**1. The parcel map draws.** `ZCL_RAK_CJ_PARCEL` `mun-6`. The dialog frames the GIS viewer
and hands it `parcelId`/`token`/`lang` by `postMessage`; it does **not** build an ArcGIS view
in the page (that path exists as a fallback and is not the one that runs). Six faults are
behind it — see [`doc/controls/gis-map.md`](doc/controls/gis-map.md), SETTLED section. The
two rules that keep being violated:

- **A `<script>` in `html( )` never runs**, so the snippet travels by `follow_up_action( )`
  *and* an `onload` attribute, and must contain no single quote. See the trap below.
- **A quiet tail matters, not a long window — and the tail is measured from the FRAME'S
  LOAD**, not from when CJS drew markup. Every post restarts the viewer's map, so the last
  one must have an uninterrupted run behind it. The schedule is `load + 0, +400, +1200`,
  then silence, with a 10 s floor for a preserved frame that fires no `load`. Widening it,
  or re-anchoring it to markup insertion, has made the map intermittent twice.

**2. A case is created from CJS itself, with no portal launch.** On **E10 client 200 only**,
a journey opened without `&userdata=` resolves `HISHAM.M` and their partner and instantiates
normally. The mechanism, and the thing that broke it twice:

- **The partner and the session key are independent, and must stay that way.** Who the
  citizen is comes from `ZFM_EGA_GET_BP_FROM_INTERNET_U` — stable configuration. The session
  key comes from `ZEGA_T_CJ_US_LOG` — a live portal login that often does not exist.
  `SIM_USERDATA( )` resolves the partner **unconditionally** and treats the key as a bonus:
  with a row it mimics the envelope, without one it still answers the partner and
  `RESOLVE_IDENTITY( )`'s fallback takes it. Coupling them again means no case can be
  created unless somebody happens to be logged into the portal.
- **Nothing is ever written to `ZEGA_T_CJ_US_LOG`.** It is the portal's table and every real
  login owns a row in it. Read it when a row is there; mimic it when it is not.
- **A blank partner is silent.** `ZFM_EGA_CJ_FW_POST_N` returns before `GET BADI` when the
  partner is blank and the journey is not anonymous — no draft reference, no message, ~1 ms.
  That reads as a missing BAdI registration, a wrong category or a filter miss, and has sent
  an investigation to each. `RESOLVE_IDENTITY( )` now says so on the trace instead.
- **`MV_TRACE` is resolved BEFORE `RESOLVE_IDENTITY( )`.** It used to be set twenty lines
  after, and `TRACE( )` drops everything while it is blank — so a `&trace=x` launch printed
  the journey, the path and the CREATE, and not one word about the partner, on the one
  screen where the partner is the question. Do not move it back down.

## Reference notes

Facts about the systems CJS wraps live in [`doc/`](doc/README.md) so they are not
re-derived from uploads every session. Read them before asking for a DPC, an MPC
or a control's source — most of it is already written down:

| | |
| --- | --- |
| [`doc/services/odata-services.md`](doc/services/odata-services.md) | every service, method by method — which entity sets are real, which are stubs, which function module sits behind each |
| [`doc/services/request-context.md`](doc/services/request-context.md) | calling a Gateway DPC with no Gateway |
| [`doc/controls/shapeit-census.md`](doc/controls/shapeit-census.md) | all 110 control types against what the migrator does with each |
| [`doc/controls/shapeit-reads.md`](doc/controls/shapeit-reads.md) | what each composite control reads, and with which filters |
| [`doc/controls/gis-map.md`](doc/controls/gis-map.md) | the parcel map — **working**, via the framed viewer. Read the SETTLED section first: the deployed screen renders the ArcGIS view **inside an iframe** on the GIS host's own origin (which is why the live map has no proxy/CORS problem and an in-page rebuild cannot get past one), and the five faults between a rendered frame and a drawn map — popup round trips not repainting the main view, a load flag set by a listener for an event that had already fired, a constant element id against a **preserved** `sap.ui.core.HTML` control, a retry counter doubling as a post counter, and `DefconAuth( )` running on **every** postMessage so each retry restarts the map. The rule from the last two: **a quiet tail matters, not a long window** - and the tail is measured from the
FRAME'S LOAD, not from when CJS drew the markup, because what varies by seconds is
the viewer's own load and auth, not anything on the CJS side. |
| [`doc/gaps/open-questions.md`](doc/gaps/open-questions.md) | what is still missing, and which of it is blocked on access |
| [`doc/gaps/abapgit-operations.md`](doc/gaps/abapgit-operations.md) | pull and stage hazards, with the evidence |

## Namespace boundary

**Never modify anything in the legacy namespace.** It is the legacy backend CJS is replacing, and
it must keep behaving exactly as it does today — other consumers still depend on it, and a
regression there surfaces far from the change. Fix on the CJS side instead: handler class, config,
or engine. If a defect genuinely cannot be fixed CJS-side, say so and stop rather than proposing a
legacy-side edit.

In scope for changes: `ZRAK_*`, `Z2UI5_*`, and the BAdI chain despite it serving the legacy path —
`ZIF_EGA_FW_CJI`, `ZCL_EGA_CJ_*_ABS`, `ZCL_EGA_CJ_ENH_IMPL_*`, `ZFM_EGA_CJ_FW_*`, `ZEGA_T_CJ_*`.

## Handler classes

```abap
CLASS zcl_e999_x_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic   " never INTERFACES zif_rak_journey_logic
  FINAL
  CREATE PUBLIC.
```

`INTERFACES` obliges all ~25 methods, so the class will not activate. Inheriting gives the empty
defaults and the payment card. Redefine only what you need.

**Redefining `ON_CUSTOM_VALIDATE` means calling `super->` first.** The base implementation is the
PAID gate — it refuses a submit while `PAYFEE <> 'PAID'`. A redefinition replaces it, so omitting
the call silently removes payment protection.

```abap
rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).
```

It must come **before** any `CHECK` (a failing `CHECK` exits the method), and if you then assign
`rt`, use `rt = VALUE #( BASE rt ( … ) )` so you extend rather than discard.

## Journey identity — case, draft, payment

The engine's live case/draft guid (`io_ctx->get_case( )`) is the **one identity that threads a
journey through draft saves, payment, and every backend post across round trips.** It is not a
model field, and it may not exist yet — it can be created mid-journey by a draft save. Handler
code must always read it through `get_case( )`, never invent or cache an id of its own, or a
resumed draft and its payment can silently diverge into two records.

This shows up in several places that all trace back to the same rule:

- **`commit_step( )` carries the guid the engine already holds**, so the backend treats a repeat
  call as an update, not a duplicate create — that's what makes it safe to call more than once.
  It exists so a payment handler can create the case lazily, from the citizen's own PAYNOW event,
  instead of the engine creating one for every abandoned form. **Never call it from
  `ON_BEFORE_POST` or `ON_BEFORE_TABLES`** — both already run *inside* the post `commit_step( )`
  triggers, so calling it there re-enters the post it's already inside of.
- **`advance_step( )` is the move only** — no validation, no post. It exists for the moment right
  after a payment confirms, not as a general "go to next" for a background poll. It deliberately
  no-ops on the last step: submitting is the citizen's press, never something a timer decides.
- **The external-backend handle's `token` rides the serialized engine instance** between round
  trips; the engine clears it before every serialize so the backend re-acquires it on demand
  (`zif_rak_journey~get_handle`). Never persist it — writing `-token` to a table or cache breaks
  the assumption that clearing it before serialize is enough.
- **`set_reference( )` must be called from `ON_SUBMIT( )`**, after the engine has decided the
  screen was submitted — call it earlier and it does nothing yet; call it elsewhere and it
  competes with the engine's own guid/backend-request-id/timestamp fallback chain.
- **The PAID gate (above) and the case guid are two ends of the same rule.** A case's payment
  status and its identity must always refer to the same underlying application — never re-derive
  either independently in handler code.
- **The journey key is NOT always the case id, and the payment path needs the case.**
  `DFKKOP-ZZEXT_KEY` is a case id. On DOK and EPDA the backend re-points the journey key at
  the case the moment `CREATE_CASE` runs, so the key *is* the case and the whole payment path
  worked by coincidence. On **Municipality it does not**: the create makes an RE rental object
  and the key stays its INTRENO (`IM00100123344`) while the case is a separate number
  (`1959738`). The gate searched `DFKKOP` for that INTRENO — matching nothing, for ever —
  while the citizen watched the timer under "Complete your payment in the new tab".
  `ZCL_RAK_JOURNEY_LOGIC->CASE_KEY_OF( )` is the one resolver, and it is **not a new lookup**:
  it is the first two branches of `ZCL_RAK_PAY_ENGINE->RESOLVE_CASE( )`, which has always known
  both shapes — `SCMG_T_CASE_ATTR-EXT_KEY` for a case, `VIBDCHARACT-SUPPLEMENTINFO` under
  `FIXFITCHARACT = 'CJ12'` for an INTRENO. The pay engine resolved correctly and the *gate in
  front of it* did not, so the gate refused before the engine was ever asked. Three things hold
  it together and each has already been got wrong: **resolve at every read, never once at
  write** — `TAKE_CASE( )` publishes whatever the backend returned, which on Municipality is
  the INTRENO, so a resolved-and-cached `CASE_NUMBER` is resolved too early; **blank means wait
  for the case, not "no fee yet"** — both are legitimate not-yet states and only one is fixed
  by waiting for billing, so saying the wrong one sends the reader to the wrong place; and
  **both selects stay wrapped in `CATCH cx_root`** — a journey key can be a `GUID_22` with
  punctuation in it, and an `SCMG_EXT_KEY` comparison against one raises
  `CX_SY_OPEN_SQL_DATA_ERROR` rather than simply missing, mid-payment with the gateway open in
  another tab. `IV_CASEID` takes the resolved case; `IV_INTRENO` keeps the raw key. They are
  different parameters and were being handed the same value. **The resolver is
  identity-fallback and must stay that way** — it sets its answer to the key it was given
  first and overwrites it only on a confirmed hit, so every exit (both `CATCH` blocks
  included) leaves the caller holding exactly what it passed in. That is the whole reason
  the change is safe for DOK and EPDA, which pay on the raw key and do so whether or not
  `SCMG_T_CASE_ATTR` answers at the moment Pay is pressed. The first version returned
  **blank** when it could not confirm a case and the gate refused on blank — which would
  have blocked two families that have never depended on a case-attribute row. `IS_CASE`
  reports only whether a case was *confirmed*, and it picks the **wording** of a wait,
  never the control flow. Resist making any of this Municipality-specific: a family branch
  has to be kept right as families are added, whereas identity fallback is right by
  construction.

- **`APPLICATIONURL` is the ATB path's field, and most journeys do not take that path.**
  `ZCL_RAK_PAY_ENGINE->ROUTE_GATEWAY( )` picks the route from `ZDT_PG_DEP_MAP`: an ATB
  department gets a ready-made `APPLICATIONURL`, and **everything else** — `PW_RB1` set,
  `ATB_FLAG` DISABLED — goes to the standard CPG through the payments Web Dynpro, where
  **no pre-built URL exists and none is ever going to arrive.** M011 polled 48 times and
  gave up waiting for one, while the read was answering richly the whole time (`AMOUNT`,
  `MERCHANTID`, `SERVICEID`, `SECRETKEY`, `REFERENCEID`, `PAYCHANNEL`, `REDIRECTURL`) and
  every value was discarded because one field it never sets was blank.
  **`REDIRECTURL` is the launch address, not a return address** — the name is misleading.
  `ZCL_CJ_DEMO_P001` settles it: after filling the same details it returns `EV_URL` built
  as `ZWDA_EGA_EUSER_PAYMENTS?sap-language=EN?referenceId=…`, character for character what
  the BAdI puts in `REDIRECTURL`, doubled `?` included (that is the legacy's own
  construction and the WD app accepts it — do not "fix" it). **That app holds the CPG form
  and posts it**, which is why `SECRETKEY` never has to reach a CJS page — building the CPG
  registration in CJS would ship a shared secret to the browser and is the wrong answer.
  `PREPARE_PAYMENT( )` resolves in order — `APPLICATIONURL`, `REDIRECTURL`,
  `WD_PAY_URL( REFERENCEID )` — and **ATB stays first** so a department already routed to it
  is untouched. `/sap/bc/zrak_cj_pay`, which `BUILD_PAY_URL( )` used to fall back to, was
  never built and 404s.
- **`window.open( )` is pop-up blocked outside a user gesture, and the payment poll is a
  timer.** `ZCL_RAK_JOURNEY_UTIL=>OPEN_URL_HTML( )` launches the gateway from an inline
  `onerror` attribute (the correct channel — a `<script>` through `html( )` is inert). On
  DOK and EPDA the open item already exists when Pay is pressed, so the address resolves on
  the **press** round trip, inside the browser's transient activation, and the pop-up is
  allowed. Where the address only arrives on a **poll tick** there is no activation and
  Chrome blocks it silently — no error, no tab. The snippet now checks the return value and,
  when blocked, writes a real link into the card; clicking that is itself a gesture and
  cannot be blocked in turn.
- **The payment poll runs quiet for 47 of its 48 ticks.** `PREPARE_PAYMENT( iv_quiet = X )`
  suppresses what the citizen sees, and it was suppressing every diagnosis with it — two
  minutes of spinner and nothing on the trace. It now names the exit taken (`NOCASE`,
  `NOSCREEN`, `NOURL`), what went out to the read (screen, case, category, backend journey),
  the backend's own messages **regardless of `IV_QUIET`**, and the **keys** that came back —
  which is what separates "the BAdI answered nothing" from "it answered and the address is
  under another name". `TRACE( )` emits only under `&trace=x`.

## Silent-failure traps

These raise nothing and render nothing. They account for most of the bugs found so far.

- **`io_ctx->bind( 'C_FOO' )`** binds to a model component literally named `C_FOO`. Pass the
  constant, not its name: `bind( c_foo )`.
- **A field name not on the journey** — `set_val`/`get_val`/`bind` against it are all legal and
  all do nothing. Check `ZRAK_T_JNY_FLD` before trusting a name.
- **`type = 'Number'` on a non-numeric value** renders an empty `sap.m.Input`.
- **A step whose `BKND_SCREEN` has no legacy configuration rows** renders, validates and posts, and
  creates nothing. `ZCL_RAK_CJS_XCHECK` exists for this; it runs in the Studio on load and save.
- **`/QNV/SB_UI_DEFIN` is only half the screen contract, and Municipality runs on the other
  half.** DOK and EPDA BAdIs branch on the screen *name* (`IF cs_general_data-screenname EQ
  'ND026_1_2'`) — X03/X04/X11/X12 cover that. `ZCL_EGA_CJ_FW_RO_ABS_V1`, which every M journey
  posts through, uses the name as a **key into `ZEGA_T_CJ_UI_MAP`** and then runs each operation
  only where an `OBJECTKEY` row exists: `ATTACHMENT` → `GET_ATTACHMENT( )`, `PLDTL` →
  `GET_PARCELS( )`, `INITIAL`/`FINAL` → `GET_FEES( )`, `CPG_1`/`CPG_2` → the gateway block, and
  **`FEES_1` → `PAYMENT_CHECK( )` + `CREATE_DUMMY_CASE( )`**, which is the only thing that creates
  the container case. A screen correct in `/QNV` and missing from the map posts, returns success,
  and does nothing — and on the fee step that is the gateway opening against a case with no open
  item. Rule **X16** checks it, from the CJS side: it derives what each step needs from the step's
  own fields (an `UPLOAD` field wants `ATTACHMENT`, `PARCEL` wants `PLDTL`, `PAYFEE` wants
  `FEES_*`) and reports only what is both needed and unmapped, so a DOK/EPDA journey with no map
  rows gets one note rather than a page of false blockers. **CJS never reads that table at
  runtime and must not start** — the engine sends a screen name and the department's map decides
  the rest, which is what keeps a legacy table rename out of the engine. X16 resolves the table
  **and** its columns dynamically for the same reason; when the map is renamed, add the new name
  to `LT_TAB` in X16 and nothing else changes.
- **`ftype = 'TABLE'` never reaches `RENDER_FIELD( )`.** `RENDER_BLOCK( )` answers TABLE itself -
  it calls `GET_TABLE( )` and draws the grid there - so a TABLE field never passes through
  `RENDER_ONE( )`, the only caller of the handler hook. Claiming one in `RENDER_FIELD( )` is dead
  code that looks live. A per-row action (view, edit, delete) must be hand-drawn from
  `ON_RENDER_START( )` or `ON_RENDER_END( )`; see `ZCL_RAK_TEST_ALL_LOGIC->RENDER_OWN_LIST( )`.
- **`RENDER_ONE( )` wraps `RENDER_FIELD( )` in `CATCH cx_root` with an empty handler** and falls
  back to the engine renderer. A hook that dumps and a hook that is never called look identical on
  screen. `ON_RENDER_END( )` at least reports `on_render_end failed: ...`.
- **A field name over 30 characters cannot be a model component.** `BUILD_MODEL( )` calls
  `CL_ABAP_STRUCTDESCR=>CREATE( )` per field, and `CX_SY_STRUCT_COMP_NAME` is uncaught - the whole
  app dies with UNCAUGHT EXCEPTION. The real cap is **23**, not 30: the model also builds `_VS`,
  `_VST`, `_IDTYPE`, `_NAME`, `_IX` and `_EXP` companions on the same name. Any runtime field name
  (a Notary blueprint `jsonKey`) must go through `ZCL_RAK_JOURNEY_UTIL=>COMP_NAME( )`, never plain
  `to_upper( )`.
- **A DDIC-typed field will not bind to a `TYPE string` formal parameter.** Methods here take
  their parameters *by reference*, and by-reference binding demands type compatibility. A
  character **literal** is fine — `iv_rule = 'X13'` — which is what makes this easy to miss,
  but `iv_step = ls_f-step_id` where `STEP_ID` is `ZRAK_JOURNEY_STEP` is a syntax error, and a
  syntax error in one method takes the **whole class** down at load. Wrap it: `CONV #( … )` or
  `|{ … }|`. This dumped `ZCL_RAK_CJS_XCHECK` once already.
- **The Arabic column used to be shorter than its English twin** — `ZLABEL_AR` was `CHAR(80)`
  against `ZLABEL`'s `CHAR(150)`, so Arabic truncated on insert while English did not. Every
  EN/AR pair in `ZRAK_T_JNY*` is now the same length, but **only in git**: it is a DDIC widening
  that needs activation and a table adjust before it is true in SAP.
  Long text of any kind — a consent paragraph, a declaration on a checkbox — goes in
  `DEFAULT_VAL` (`CHAR(1000)`) behind a `TEXT:` prefix, read by
  `ZCL_RAK_JOURNEY_RENDER->LONG_TEXT( )`. `TEXT:@nnn` resolves `ZRAK_T_CJ_TXT` by `sy-langu`
  and is the form to use when the text must be bilingual: `DEFAULT_VAL` has no `_AR` twin, so a
  literal paragraph shows its English to an Arabic reader. A `TEXT:` default is never seeded
  as the field's value — without that guard a consent checkbox renders pre-ticked and passes
  its own required check. `ZCL_RAK_CJS_XCHECK` rule **X13** reports any label sitting exactly
  at 150 characters, which is what a truncated one looks like.
- **`OTR:<alias>` in any bilingual text column resolves to that OTR concept, live, on every
  round trip.** `ZCL_RAK_JOURNEY_REPO->PICK( )` — the one place every `ZLABEL`/`ZLABEL_AR`,
  `MSG`/`MSG_AR`, `PLACEHOLDER`/`PLACEHOLDER_AR`, `ZSECTION`/`ZSECTION_AR`, title, subtitle and
  option-text pair already resolves EN/AR through — checks for the prefix after picking a
  language and, if present, calls `SOTR_GET_TEXT_KEY` with the rest of the string as the alias
  and the resolved language. `ENSURE_CONFIG( )` rebuilds `MS_CONFIG` from scratch every round
  trip (nothing here is cached across requests), so this genuinely re-resolves each time — a
  wording change in SOTR reaches the journey with no redeploy. An alias with no OTR entry falls
  back to the literal `OTR:...` string, on screen, rather than going blank — a visible symptom
  instead of a silent one. Existing literal text is unaffected: only a value that starts with
  the four characters `OTR:` is treated this way.
- **An unsupplied z2ui5 OPTIONAL is not "false" — it is whatever UI5 defaults to.**
  `XML_GET_PARTS( )` builds the markup with a `REDUCE` that skips every property whose
  value is blank, so an unsupplied one is **dropped from the XML** rather than emitted as
  `false`. A control property
  whose UI5 default is `true` therefore stays `true`, and the ABAP reads as "we never set
  this" while behaving as "we set it on". That is what made a `CLOSED_LIST` dropdown draw
  its **first option while the model held nothing** — `sap.m.Select`'s `forceSelection`
  defaults to true, so an untouched required field looked answered, no rule keyed on it
  fired, and `VALIDATE_STEP( )` refused a field the citizen could see filled in.
  `ZCL_RAK_JOURNEY_RENDER` now passes `forceselection = abap_false` explicitly. Passing
  `abap_false` **does** work: it is typed `ABAP_BOOL`, so `BOOLEAN_ABAP_2_JSON( )` renders
  the literal string `false`, which is not blank and survives that filter — but a bare
  `''` or an untyped blank would be dropped again. Check the parameter's documented UI5
  default before assuming that leaving it out is the safe option.
  **The same filter means a SPACE cannot be sent as a property value at all**, which is a
  different-looking version of the same trap and was met a second time on the COUNT mask:
  `sap.m.MaskInput`'s `placeholderSymbol` was to be set to a space so an empty two-digit
  field showed nothing rather than `__`, and a space **is** blank — the property never
  reached the markup, the ABAP read as set, and UI5's `_` default applied. There is no way
  to pass it. When a control's default is wrong and the value that would fix it is a space,
  the fix has to be downstream of the control (`ZCL_RAK_JOURNEY_ENGINE->NORM_MASKED( )`
  strips `_` and spaces from every `COUNT` value once per round trip) rather than a
  property. `forceSelection` and `placeholderSymbol` are one mechanism, not two.
- **A required label is marked by the `required` property, never by a CSS class.**
  `label( ... required = abap_true )` is what makes UI5's own renderer draw the asterisk
  (`sapMLabelRequired`). The old mechanism — a `rakReq` class plus a hand-written
  `.rakReq::after` rule — never reliably reached the DOM, so every mandatory field on every
  journey rendered unmarked while `VALIDATE_STEP( )` went on correctly refusing the submit:
  a form that looks optional and won't submit. The class and the CSS rule behind it are both
  gone; `.rakReqStar` is a different thing and stays (the required-**checkbox** marker is a
  sibling control, because a checkbox's text is a whole sentence, not a label).
  `ZCL_RAK_JOURNEY_RENDER->REQ_LABEL( )` is the engine's one label, but it is **not the only
  place a label is drawn** — `RENDER_ATTACH( )` and `ZCL_RAK_JOURNEY_LOGIC->DIALOG_FORM( )`
  draw their own, and a hand-drawn popup that calls `z2ui5_cl_xml_view->label( )` directly
  bypasses all three. Prefer `DIALOG_FORM( )` for a new popup: it sets `REQUIRED` from each
  field's own flag, so the marker cannot be forgotten.
- **An offset on `IV_EVENT` is an offset on a `STRING`, and a short event throws.**
  `IV_EVENT` is `TYPE string`, so `iv_event(8)` on anything shorter raises
  `CX_SY_RANGE_OUT_OF_BOUNDS` - and event names are short: `C_EVT_OWNOK` is `'OWN_OK'`,
  six characters. E016 dispatched its Edit/Delete rows with `CASE iv_event(8)` after a
  `CASE` whose Add branch did not `RETURN`, so pressing Add fell into it and threw.
  It never dumped, which is why it survived: the engine wraps `ON_POPUP_EVENT` in
  `TRY/CATCH cx_root` and turns it into a Warning - so the row saved, the popup closed,
  and the citizen got an unexplained offset error on a **successful** Add. Match event
  names with `CP` (`iv_event CP c_edit_pop`) the way D001/D004/E017/E018 do - a pattern
  match cannot run off the end - or guard the offset with `strlen( )`.
- **An empty redefinition is a DELETION, not a no-op.** Handlers INHERIT from
  `ZCL_RAK_JOURNEY_LOGIC`, so redefining a hook REPLACES its base body. Most of the
  interface is genuinely empty and overriding it costs nothing - but four hooks are not:
  `ON_CUSTOM_VALIDATE` is the PAID gate, `RENDER_FIELD` is the payment card,
  `ON_POPUP_EVENT` is the BP and attachment machinery, `WANTS_FEEDBACK` returns true.
  Emptying one removes that silently. This is not hypothetical: **E128 lost its PAID
  gate and could be submitted unpaid, D020 lost its fee card, E014 and E027 lost the
  payload strip** - all four with a commented-out `CALL METHOD SUPER->` template sitting
  in the body, which is what SE24's "redefine" button generates and which reads exactly
  like the call has been made. Either chain (`rt = super->...( )`, extending with
  `VALUE #( BASE rt ... )`) or delete the redefinition so the base runs. `ON_BEFORE_POST`
  and `ON_BEFORE_FIELDS` are the deliberate exception - their base strips `PAY_*`/`PAYFEE`,
  which is wrong for a fee-bearing journey, so D001, D025 and E027 skip it on purpose.
- **A popup's `REQUIRED` is a marker; the handler is the enforcement, and the two drift.**
  `DIALOG_FORM( )` sets `REQUIRED` on the label and nothing else - `VALIDATE_STEP( )` never
  sees popup fields, so the OK event has to check them itself. The two lists must mirror
  each other: a field marked but not checked promises an asterisk it never enforces, and a
  field checked but not marked is the looks-optional-and-won't-submit bug. E016/E017/E018
  had *no* markers against 9/4/10 enforced fields until this was fixed.
- **Validation that only adds a message does not block anything.** E017's `VALIDATE_INPUT( )`
  returned nothing and the caller ran `POPULATE_GRID( )` and `CLOSE_POPUP( )` regardless, so
  a blank chemical row was saved and the dialog shut with a warning toast as the only sign.
  A popup check has to return a verdict and the caller has to gate the save AND the close on
  it - leaving the dialog open is the point, so the citizen keeps what they typed.
- **Check whether a method is reachable before believing what it renders.** Several handlers
  keep a hand-drawn `RENDER_OWN_POPUP( )` whose only call site is commented out, sitting
  beside the live `DIALOG_FORM( )` path. Nothing marks it dead. Twenty of thirty-one label
  fixes in one session landed in exactly that kind of code and changed nothing on screen.
  `grep` for the call site, not just the method.
- **Every round trip used to repaint the whole page, and that is what "flickering" is.**
  `VIEW_DISPLAY( )` hands the client a fresh XML view, so UI5 tears the control tree down
  and rebuilds it - taking the scroll position and the focus with it. Picking from a
  dropdown raises `CHANGE` (see `OPT_EVT( )`), and the round trip is *correct* - `ON_CHANGE( )`
  has to run - but repainting afterwards when nothing moved is not. `SEND_VIEW( )` in
  `ZCL_RAK_JOURNEY_RENDER` is now the single exit for the finished view: it hashes the
  stringified markup against `ZCL_RAK_JOURNEY_ENGINE-MV_VIEW_SIG` and, when it matches,
  calls `VIEW_MODEL_UPDATE( )` instead - which sets `CHECK_UPDATE_MODEL` and refreshes the
  bound values without touching the controls, so a value `ON_CHANGE( )` wrote server-side
  still reaches the screen. **The test is the markup itself, never a list of things that
  might have moved**, so it cannot go stale: anything that really changes the page changes
  the markup. `MV_QUIET_EVT` keeps the quiet path to `CHANGE_` round trips only, so
  navigation, submit and popups always repaint; popups go out through `POPUP_DISPLAY( )`
  regardless. Confirmed fixed on screen. If you ever need the old behaviour, do not
  reintroduce a second `VIEW_DISPLAY( )` call - go through `SEND_VIEW( )`.
- **A backend TABLE's cells are positional at BOTH ends, and the two orders are set in
  different places.** `ZCL_RAK_JOURNEY_BE` reads a backend table by assigning
  `FIELD1..FIELDn` in order and handing cell N to configured column N of the
  `KEY:Label:TYPE` spec in `DEFAULT_VAL`. The BAdI fills those same components the other
  way round - `ZCL_EGA_CJ_ECOMP_ABS->ZIF_EGA_FW_CJI~READ( )` does
  `lv_field = 'FIELD' && ls_child-list_sequence`, so the slot a value lands in comes from
  **`LIST_SEQUENCE` in `/QNV/SB_UI_DEFIN`**, not from the CJS spec. Nothing checks that the
  two agree: a column whose `LIST_SEQUENCE` is missing renders blank, and one whose
  sequence differs from its position in `DEFAULT_VAL` renders the neighbouring value.
  Before believing a wrong or empty column is a rendering bug, line the spec up against
  the `/QNV/SB_UI_DEFIN` rows for that screen.
- **`FIELDn` is a fixed-width DDIC component; a `TYPE string` source is cut to fit.**
  The BAdI assigns a `string` (e.g. `TY_COMPLAINT_DETAILS-COMPLAINERNAME`) into a `FIELDn`
  of `/QNV/SBUILD_UI_TABLE_CUST_TT`, and the truncation happens silently at that
  assignment - which is why a 1000-character description came back as exactly 250. That
  structure is legacy and must not be widened. Long text belongs on a scalar field bound
  to the `GS_DATA` component that holds the whole string, the way EC05's `DESCRIPTION_1`
  binds `GS_DATA-COMPLAINT_DESC`, with the table column left as a summary.
- **A grid row written by hand is positional against the *configured* columns.**
  `SET_GRID_DATA( )` maps by name, but the `COLUMNS` a handler passes came straight back from
  `GET_GRID_DATA( )`, so the map is an identity map and cell N lands in configured column N.
  A cell appended out of order is written to the neighbouring column; one appended past the
  last configured column is dropped. Neither raises anything. The order lives in
  `ZRAK_T_JNY_FLD-DEFAULT_VAL` for the grid field — read it before adding or reordering a
  field in an Add-a-row popup's save. E016/E017/E018 each carry this note at their save method,
  and their orders legitimately differ from each other because their specs do.
- **A handler override OUTRANKS a rule, not the other way round.** `set_hidden( )`,
  `set_readonly( )` and `set_required( )` all write `MT_OVR`, and
  `ZCL_RAK_JOURNEY_RULES->IS_HIDDEN( )` / `IS_READONLY( )` check that table **before**
  `MT_RULEHIDE` and before the configured flag — a handler spoke deliberately, so it wins.
  The trap is calling one of them with a value you did not mean as an instruction:
  `set_required( iv_on = abap_false )` does not "leave it alone", it forces the field
  optional and silently removes a configured required marker. `ZCL_RAK_JOURNEY_BE->APPLY_CTRL( )`
  did exactly that for every field the BAdI did not name, on every screen it answered.
  The fix is upstream: `ZCL_RAK_QNV_BRIDGE->SEED_CTRL( )` sends the journey's own config
  into `ZIF_EGA_FW_CJI~READ`, `READ( )` keeps a copy of what went out, and `CTRL_OF( )`
  reports `MANDATORY`/`ENABLED`/`VISIBLE` **only where the BAdI changed them** — so what
  reaches an override is an instruction and never an echo. Move that gate and every
  rule-hidden field on a BAdI-answering screen un-hides.
- **A migrated layout is DERIVED, not designed.** `ZCL_RAK_MIGRATOR` pairs a legacy caption
  row with the control it captions and drops the two into two cells of the twelve-column
  `ZRAK_CJ_LAY` grid, because that is the shape of the `/QNV/` definition. Right for an input
  and its label; wrong for a composite (`PARCEL`, `PROPERTY`, `TITLEDEED`, `CONTRACT`,
  `FLOORUNIT`, `BUILDINGS`, `ACCOM`), which is a full-width card list, and wrong for a DISPLAY
  paragraph. `ZCL_RAK_JOURNEY_RENDER->WIDE_FIELD( )` forces those two shapes to a full-width,
  line-broken cell (`rakWide` on the unlaid path, where `rakRowCn` pins each child to a
  fraction of the row). It overrides two shapes, never the grid — a cell an author placed by
  hand in the Design tab stays where they put it.
- **A `<script>` block inside `html( )` NEVER RUNS.** `Z2UI5_CL_XML_VIEW->HTML( )` sets
  `sap.ui.core.HTML`'s `content`, which reaches the DOM as innerHTML, and a script
  inserted that way is inert by specification - parsed, kept, never executed, nothing
  logged. This cost the parcel map six rounds: the iframe rendered and the viewer sat on
  its splash screen waiting for a `postMessage` that never left, which looks exactly like
  a wrong URL. An inline event **attribute** does run, which is why
  `RENDER_UPLOADER( )`'s `onchange=` FileReader has always worked. For anything else use
  `mo_client->follow_up_action( )`, which the frontend runs after the view and after any
  popup fragment have rendered - **and put not one single quote in the snippet**:
  `_runCustomJs` splits on `'` and, finding any, calls a frontend action with the pieces
  instead of running the code. Double quotes throughout, `String.fromCharCode(39)` where a
  quote character is genuinely needed, and the whole thing an expression (an IIFE),
  because it is evaluated as `Function("return " + snippet)()`.
- **`follow_up_action( )` may not fire on a round trip that only opens a POPUP.** It runs
  from the **main** view's `onAfterRendering`, and opening a dialog need not re-render the
  main view. Carry the snippet in an inline event attribute as well — the `onload` of a 1×1
  data-URI image works anywhere — and make the payload idempotent so both channels can run.
- **`{` and `}` in `html( )` content must be escaped `\{` `\}`.** The markup travels as an
  XML view attribute, and UI5 reads braces there as a binding expression; unescaped, a
  snippet of JavaScript object literals parses as malformed bindings and the control never
  renders. `RENDER_UPLOADER( )` and `ZCL_RAK_CJ_GIS->CONTAINER( )` both do this.
- **A literal `|` must be escaped `\|` inside an ABAP string template**, so JavaScript's
  `||` is written `\|\|`. Unescaped it closes the literal mid-expression and the class
  will not activate. Three of these were caught in one file by extracting the generated
  JS and running `node --check` on it - worth doing for any non-trivial embedded script.
- **`CONSTANTS ... TYPE string VALUE ''` will not activate** - a string constant does not
  take an empty literal; `VALUE IS INITIAL` is the form that means blank. It is the most
  expensive shape in this list because the class then has **no active version**, so the
  error surfaces at every *caller* as `Method X is unknown or PROTECTED or PRIVATE` and
  points nowhere near the cause. `ZCL_RAK_CJ_GIS` cost a round exactly this way.
- **A DEFAULT does not make a second importing parameter invisible.** `meth( x )` with two
  formal importing parameters is a syntax error however optional the second one is - say
  `PREFERRED PARAMETER`, or name the arguments.
- **An inline `DATA( )` in the IMPORTING part of a functional call that is itself the
  source of an assignment** is refused: *the inline declaration is not possible in this
  position*. Declare the variables first.
- **An item's `TECHNICALNAME` is ASSIGNED BY NAME in the BAdI, and then written to.**
  `ZIF_EGA_FW_CJI~MAPPER` does `ASSIGN (<ms_item_data>-technicalname) TO <value>.` — assign
  by **name**, not `ASSIGN COMPONENT` — so it resolves the string as a data object visible
  in *its own program* and assigns the item's value into whatever it finds. It does check
  `sy-subrc`, which is why this looks safe; the check does not help when the name resolves
  to something read-only. Sending an item called `LOGINBP` bound the FM's own IMPORTING
  parameter, `sy-subrc` was 0, and the write dumped every DOK journey with
  `MOVE_TO_LIT_NOTALLOWED_NODATA` — *"Overwriting of a protected field. Declare the
  parameter as a VALUE."* The comment that made it look safe said the DOK and EPDA
  abstracts map items through their own config table by `TECHNICALNAME`; they do, **second**.
  So: **never send an item whose `TECHNICALNAME` could name a data object in the BAdI's
  program.** A bare identifier — `LOGINBP`, `ROLEBP`, `ROLE`, `GUID`, `STATUS` — is exactly
  such a name. The `CJS_` prefix exists for this: nothing is called `CJS_LOGINBP`, so the
  assign fails and the row is skipped as intended. A name only the one family reads, like
  Municipality's bare `BP`, goes only to that family.
- **An uploader's DOCUMENT TYPE rides `DEFAULT_VAL` behind `DTYPE:`.** Every legacy
  uploader carries `DATA2` = 1/2/3 in `/QNV/SB_UI_DEFIN` and the BAdI files it as
  `ZDT_EGA_CJ_ATTR-DIFFCRT`. `ATTACHMENTS_FOR_BACKEND( )` sent only `identifier1/2`,
  the name and the content, so `DIFFCRT` arrived blank — and `CREATE_ATTACHMENT` only
  checks `OBJTRG`/`OBJSRC`, so it passed silently and the case could not tell a title deed
  from an Emirates ID. The value now goes out through `ASSIGN COMPONENT` over a candidate
  list (`DIFFCRT`, `DOCTYPE`, `DOC_TYPE`, `IDENTIFIER3`, `DATA2`), because
  `/QNV/SBUILD_ATTACHMENTS_TT` cannot be opened from here — the trace names which one
  answered, so one run cuts the list down. **It does not unlock `ATTACH_MULTI`**: two files
  on one field share a field and so share a type, and `GET_ATTACHMENT( )` de-duplicates on
  `(objsrc, diffcrt, objsrctype, objtrgtype)`. Multi-file needs the occurrence key in
  `identifier1`, which is a different mechanism.
- **A guidance paragraph must never become a caption.** `PAIR_LABELS( )` used to leave a long
  DISPLAY row pending and attach it to the next control, so the wording landed in `ZLABEL`
  (CHAR 150), was cut mid-word, and `MT_CONSUMED` hid the row it came from — the full text
  then appeared nowhere. `IS_NOTICE( )` now gates it, which also restores the real caption:
  the short row above stays pending and reaches the control.

## Conventions

- **A citizen-typed date reaches the backend as raw text, and the backend converts it.**
  `sap.m.DatePicker` does **not** discard input it fails to parse — it flags its own
  `valueState` and still writes the typed characters through the two-way binding. Nothing
  on the CJS side objects (`TY_REQ-DOB` is `TYPE string`; `ZCL_RAK_BP_SEARCH->ADD_FLT( )`
  only rejects a *blank* value), so `'19.08.1987'` travelled all the way into
  `ZCL_EGA_BP_BO_API=>BP_QUERY` and raised an uncatchable `CX_SY_CONVERSION_NO_DATE` —
  "Application Error - Please Restart The App", the whole session gone, no message.
  `ZCL_RAK_BP_SEARCH=>SEARCH( )` now normalises `IS_REQ-DOB` through
  `ZCL_RAK_BP_SEARCH=>NORM_DOB( )` (which delegates to `ZCL_RAK_JOURNEY_UTIL=>TO_DATS( )`,
  the same parser the DATE range check uses) and, when a **filled** value does not
  normalise, reports it on `CT_MSG` and does not search. `SEARCH( )` is the choke point
  both popups go through, which is why the guard is there and not in `ZCL_RAK_BP_POPUP` —
  a journey drawing its own dialog has no hook between the model and the filter.
  Three things follow. The normalisation must happen **before** `VALIDATE( )`'s MOI
  cross-check (`LS_BP-DOB <> IS_REQ-DOB`), or that comparison starts failing against a
  value it used to match. **The refusal is always `'E'`, never `IS_REQ-MSG_TYPE`** —
  `MSG_TYPE` governs how strictly to judge a partner that *was found*, and this is a
  precondition failure where nothing was searched for, so it sits on the same side of
  that line as "No data found" (which `VALIDATE( )`'s own comment already excludes).
  Severity is the smaller half: on a `'W'` path the **empty result set** would assert
  "no such partner" when no question was asked, and `'E'` is what stops
  `ZCL_RAK_BP_POPUP` reaching that at all. And **any other `TY_REQ` field `BP_QUERY`
  converts on the far side has the same exposure** — date of birth is only the one that
  has been hit, and a sweep was deliberately not done: the fix for each would be a guess
  about a target type nothing on the CJS side can see. The cheap version, if it ever
  matters, is to ask whoever owns `ZCL_EGA_BP_BO_API` which filter properties it
  converts to something other than a string, and look only at those.
- **Drafts and attachments have an owner, and it is not always CJS.** `DRAFT_MODE` and
  `ATTACH_MODE` on `ZRAK_T_JNY` answer `DELEGATE` / `NATIVE` / `OFF`; blank lets the engine
  derive one. The derivation is the rule: **a backend that creates and re-opens the case IS
  the draft**, so CJS delegates and keeps no second copy. Attachments are derived from
  `capabilities( )-attachments` instead, *not* from whether a case exists — a backend can own
  the case and still have nowhere to put a file. `OFF` is refused in `HANDLE_SAVE( )`, not only
  hidden in the renderer: a hidden button is not an unreachable event. There is **no native
  draft store yet**, so `NATIVE` on a journey with no backend reports an error rather than a
  false success.
- **Layout is per element in `ZRAK_CJ_LAY`, edited in the Studio's Design tab.** Row, column
  and span come from the twelve-column grid; `FLOW` makes one cell lay its contents left to
  right, which is how a handler's search or ADD button ends up *beside* its field instead of
  under it — a cell is a `vbox`, so `AFTER_FIELD( )` content always stacks otherwise. `FLOW`
  is not `INLINE`: `INLINE` decides which **row** a cell lands on, `FLOW` the direction
  **inside** one cell. `PERSIST( )` does a full `MODIFY`, so anything writing an attribute must
  `RESOLVE( )` first and overwrite only its own fields, or it blanks the rest.
- **`ZRAK_T_JNY_FLD-MSG` can be written per check.** One column is read by the required
  check, by MIN_VAL/MAX_VAL, by the DATE range, by the numeric CATCH and by REGEX. They
  never fire together, so this was only ever a wording limit — but a field that is both
  REQUIRED and format-constrained had one column and two sentences to write in it.
  `MSG` may now carry `KEY:text` clauses separated by `;` —
  `REQUIRED:Please state the number;FORMAT:@201` — with the keys `REQUIRED`, `LEN`,
  `RANGE`, `NUMBER`, `FORMAT` and `*` as a catch-all. Each clause splits on its **first**
  colon, so its text may itself be `@nnn` (a `ZRAK_T_CJ_TXT` row, as a TABLE column header
  takes) or `OTR:<alias>` — which is what lets a migrated WD message keep its own OTR
  concept on the FORMAT check while REQUIRED keeps its own words. `ZCL_RAK_JOURNEY_UTIL=>MSG_FOR( )`
  is the one resolver; `ZCL_RAK_JOURNEY_RULES` routes every read of MSG through it.
  **Additive, and the guard is narrow on purpose**: the keyed form is recognised only when
  the text *begins* with one of those keys immediately followed by `:`, so every MSG
  configured today — including a whole-column `OTR:` alias, or an ordinary sentence
  containing a colon — behaves exactly as it did. A blank answer means "nothing configured
  for this check" and falls back to the catalogue. `MIN_LEN`/`MAX_LEN` are the exception:
  they never read MSG, so a plain MSG is still ignored there and only an explicit `LEN:`
  clause reaches them.
  **`NUMBER:` runs before `FORMAT:` and stops it.** `VALIDATE_STEP( )`'s numeric gate
  sits ahead of the REGEX check and `CONTINUE`s, so on a field carrying `MIN_VAL` or
  `MAX_VAL` a non-numeric value raises `CX_SY_CONVERSION_NO_NUMBER`, takes
  `MSG_FOR( 'NUMBER' )`, and `MSG_FOR( 'FORMAT' )` is never reached. The ordering is
  right — a value that is not a number cannot be range-checked, and one message per
  field is the point of the `CONTINUE`s — but it is not visible from the column
  names: a field with **both** `REGEX` and `MIN_VAL`/`MAX_VAL` that configures only
  `FORMAT:` silently shows the catalogue's "&1 must be a valid number" instead. Write
  `NUMBER:` as well as `FORMAT:` on any field that has both.
- **Config before code.** Show/hide belongs in `ZRAK_T_JNY_RULE`, options in `ZRAK_T_JNY_OPT`.
  Write ABAP for payment routing, live BP search, cross-container side effects.
- **Migrating a legacy screen?** Drive `ZCL_RAK_MIGRATOR`. Do not hand-author `ZRAK_T_JNY*`
  `INSERT`s — they drift from its mapping.
- **Migrated wording is READ, never written — and never hand-translated.** Every label,
  section heading, message, placeholder and option text on a migrated screen already
  exists in both languages in the legacy text tables, keyed by the columns the export
  already carries: **`/QNV/SB_LABELT`** (`label_code` → `labeltext`, one row per `spras`)
  for `LABEL_CON`, and **`/QNV/SB_VALUET`** (`value_code` → `value_desc`) for option and
  value texts. `ZCL_RAK_MIGRATOR->LOAD_TEXT_CACHES( )` loads both into `MT_LBL`/`MT_VAL`,
  so a migration driven through the migrator gets the department's own words for free.
  **A hand-written feeder has to do the same lookup itself** — the same shape it already
  uses for the Arabic title out of `ZEGA_T_CJ_IDT` — and fall back to a literal only when
  no row answers. Typing an English label off a spec document and translating the Arabic
  by hand substitutes a guess for wording the department owns: it differs from the live
  screen the citizen already knows, in a language most reviewers of this repo cannot
  check, and nothing anywhere reports the difference. It also gives up the only
  maintainable form — a text row, an `OTR:<alias>` or an `@nnn` `ZRAK_T_CJ_TXT` key all
  change wording with no reseed, because `ZCL_RAK_JOURNEY_REPO->PICK( )` re-resolves
  every round trip. This applies to **every** migration, not only the ones where somebody
  remembers to ask.
- **`VALUE` takes a TYPE NAME, never a type declaration.** `VALUE STANDARD TABLE OF
  ty_map WITH EMPTY KEY ( ... )` is not a constructor expression, and the Class
  Builder reports it as **`Field "VALUE" is unknown`** — naming the operator rather
  than the mistake, which reads like a missing field. Declare the table type
  (`tt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY`) and write `VALUE tt_map( … )`.
  A named type is fine inline — `VALUE string_table( … )`, `VALUE abap_parmbind_tab( … )`
  — which is what makes the invalid form look plausible.
- **`TYPE HANDLE` takes a VARIABLE, never a method call.** `CREATE DATA lr TYPE
  HANDLE lo_tt->get_table_line_type( )` fails with **`No method can be specified in
  the current position`** — a message that names neither `TYPE HANDLE` nor the call.
  Assign the descriptor to a `DATA lo_line TYPE REF TO cl_abap_datadescr` first.
  Same family as the `VALUE` trap above: the error describes where the parser gave
  up, not what is wrong.
- **An ABAP source line stops at 255 characters.** Past that the Class Builder truncates and
  reports `Field "LV_V" is unknown` - naming whatever the cut left behind, at the line it cut,
  never the length. Three unrelated-looking unknown-field errors on three neighbouring lines is
  the signature. Several single-line `io_form->input( ... )` calls in `ZCL_RAK_JOURNEY_RENDER`
  already sit in the 250s, so adding one parameter tips them over. After editing, check with
  `awk 'length($0)>255' src/*.abap` and split the call across lines.
- **Source files in this git history are LF, not CRLF** — checked with `git show HEAD:<path> |
  file -` across every `.abap` and `.xml` file here, zero CRLF found. (An earlier version of
  this file claimed the opposite; that claim cost a real session a spurious six-file diff before
  `check_crlf.py` was caught nudging the wrong direction and both were fixed. If you're editing
  against a *different* working copy — one synced live from SAP via abapGit rather than this git
  history — re-check with `file -b` before trusting either direction.) `sed -i` and a plain-text
  `Write` can still silently normalize line endings depending on the tool; if a diff on a file
  you touched looks far larger than your edit, check `file -b` before committing.
- **New engine capability?** Cover it in `ZCL_RAK_TEST_ALL_LOGIC` if it's a **hook** (`on_*`,
  `render_*` — see the class header for the full list); it exercises every hook with no database
  dependency. If it's config-only framework behaviour instead — a rule, a validation, a grid
  column property — a hook class can't reach it: seed a small, self-contained, re-runnable
  journey instead, the way `ZRAK_SEED_GRIDTEST` (grid/rules features) and `ZRAK_SEED_VALIDTEST`
  (scalar validation features) do. Neither needs `ZCL_RAK_MIGRATOR`: both are throwaway
  `journey_id`s that delete their own rows first, not production journeys, so the rule two lines
  up doesn't apply to them.

## Hooks

The traps above are also enforced mechanically in `.claude/hooks/`, so they block before a
mistake lands rather than relying on this file being read closely:

| Hook | Event | Enforces |
| --- | --- | --- |
| `session_start.py` | SessionStart | Pulls `main`, reprints the short list of rules below |
| `block_legacy_writes.py` | PreToolUse (Write/Edit/MultiEdit) | The namespace boundary — denies creating/editing a legacy-namespace object |
| `check_journey_rules.py` | PreToolUse (Write/Edit/MultiEdit) | `ON_CUSTOM_VALIDATE` redefinitions call `super->` before any `CHECK`; `commit_step( )` is never called from `ON_BEFORE_POST`/`ON_BEFORE_TABLES` |
| `check_empty_redefinition.py` | PreToolUse (Write/Edit/MultiEdit) | Denies emptying a hook whose base does real work — reads which those are from `ZCL_RAK_JOURNEY_LOGIC` itself, exempts `ON_BEFORE_POST`/`ON_BEFORE_FIELDS` |
| `check_required_label.py` | PreToolUse (Write/Edit/MultiEdit) | The required marker stays the native `required` property — denies a `rakReq` class on a `label( )` call, and denies a `.rakReq` rule reappearing in the theme CSS |
| `protect_abapgit_config.py` | PreToolUse (Write/Edit/MultiEdit) | Asks for confirmation before touching `.abapgit.xml` / `*.devc.xml` |
| `check_crlf.py` | PostToolUse (Write/Edit/MultiEdit) | Flags a file under `src/` that gained CRLF line endings, since this repo's git history is LF |
| `check_abap_shape.py` | PostToolUse (Write/Edit/MultiEdit) | Four mechanical activation-breakers nothing here compiles to catch: `METHOD`/`ENDMETHOD` imbalance, `CONSTANTS ... TYPE string VALUE ''`, an unescaped `\|\|` inside a string template, and a line over 255 characters |

> **Whether these run depends on whether `python3` is on PATH.** On a machine where it resolves
> to a stub (the Windows Store alias is the one that's bitten this project before), every hook
> prints an install message and **exits 0**, so every check silently passes — verify with
> `echo '{}' | python3 .claude/hooks/check_crlf.py` before trusting anything below. On other
> machines, including at least one Claude Code cloud/remote session, `python3` is real and these
> hooks fire for real: a `check_crlf.py` nudge landed and was acted on mid-session. Don't assume
> either way — check on the machine you're actually on, and don't trust a hook's nudge over
> `git show HEAD:<path> | file -` if the two disagree, per the CRLF note above.

These are static, regex-based checks on the text being written — they catch the shape of a
known mistake, not everything semantically wrong. They deny/ask before the tool call, except
`check_crlf.py` which nudges after (the file is already on disk by then). None of it replaces
`ZCL_RAK_TEST_ALL_LOGIC` or `ZCL_RAK_CJS_XCHECK`; both still need to run in SAP.

## Verification

There is no ADT/SAP connection from this environment. Nothing here can be compiled, activated or
run — **do not report ABAP changes as verified.** Say what was checked (structure, balance,
diffs) and that activation is outstanding.

Getting a change into SAP is manual: `git push` → abapGit **Pull** → activate. `ZCL_RAK_CJS` and
`ZCL_RAK_JOURNEY_LOGIC` are the two that break widest; activate them first.

**Active does not mean current.** A pull writes the source and leaves the object inactive; until it
activates, the runtime keeps running the OLD active version and the Class Builder still displays
it. A syntax error therefore looks exactly like a pull that never happened - nothing on screen
changes. This cost a whole session once: one missing `CLASS ... DEFINITION` line meant five
consecutive commits reached SAP and silently failed to activate, while every symptom pointed at
code that was never running.

So verify by **content, not status**: open SE24 and look for a method or a string you just added.
`Implemented / Active` proves nothing. Check this before re-diagnosing code that appears to have no
effect - and if two rounds produce no visible change, stop theorising and instrument: a
`message_strip` that renders unconditionally settles in one round trip what inference will not
settle in five.

## abapGit — pull before you stage

One branch: `main`. Never create others.

Staging an object that has **not** been pulled pushes the older SAP copy over newer work in git.
This has already reverted fixes across five classes. In the pull dialog the State column is
`local` + `remote`:

| State | Meaning | Action |
| --- | --- | --- |
| `_M` `_A` | git is ahead | tick — safe |
| `M_` | **SAP has changes git does not** | ticking discards them |
| `MM` | both changed | conflict — diff before choosing |

**This is not a hypothetical: it happened again during the last review session.** The
E128 PAID-gate fix was pushed to git, E128 showed `M_` in the pull dialog, the row was
not ticked, and the next Stage pushed SAP's older copy back over it - the gate was gone
a second time and had to be re-applied. If a fix you know you made is missing, check the
stage history before re-diagnosing the code.

**The pull dialog pre-ticks only Add local object rows.** Every `Overwrite local object` row arrives
**unticked**, and the ticks reset every time the dialog opens - so an existing object is skipped
unless you tick it by hand, on every pull. abapGit still reports success, which is why this reads as
"the pull is broken" rather than "that row was not selected".

## Open items

- **The ShapeIt wrapper layer has started: `ZCL_RAK_CJ_API` + `ZCL_RAK_FEES_API`.** CJS
  replaces ShapeIt's OData-backed UI5 composites with ABAP class APIs, the way
  `ZCL_RAK_BP_SEARCH` already wraps `BP_QUERY`. `ZCL_RAK_CJ_API` **inherits**
  `ZCL_ZEGA_CJ_DPC_EXT` because the `<Set>_GET_ENTITYSET` methods are protected —
  a subclass may call them and only a subclass may. Two constraints are written into
  its header and must not be re-derived: several DPC methods **dereference
  `IO_TECH_REQUEST_CONTEXT` unguarded** despite it being OPTIONAL (`PropertiesSet`,
  `LeaseContractSet`, `PartnerSet`, `OccupantSet`, `UserSet` — `FeesSet`, `TrackerSet`
  and `ProjectSet` do not, which is why those three came first); and **CJS cannot
  impersonate the portal session**, because `GET_BP( )` resolves the caller by
  AES-decrypting a `ZEGA_T_CJ_US_LOG` row keyed on an `x-custom1` header. Identity
  therefore travels in `MS_CTX` and goes out as **filters**, never inferred by the DPC.
- **A Gateway DPC CAN be called outside its runtime context — settled, not assumed.**
  `ZRAK_CJ_REQCTX_DIAG` reports `BOUND` in the RAK system on
  `/IWBEP/CL_MGW_REQUEST_UNITTST`, whose constructor is `IT_HEADERS` (mandatory)
  plus an optional `IO_MODEL` and takes **no `IR_REQUEST_DETAILS`** — which is why
  the subclass attempts kept failing. **But `_UNITTST` is NOT the one to use** —
  it never sets `MR_REQUEST`, so the inherited `GET_REQUEST_HEADERS( )` raises an
  uncatchable `DATREF_NOT_ASSIGNED` the first time anything reads a header.
  `/IWBEP/CL_MGW_REQUEST` is, because its `IR_REQUEST_DETAILS` can be bound to a
  real structure and the session key written into
  `TECHNICAL_REQUEST-REQUEST_HEADER`. **Verified on E10**: `x-custom1` reaches the
  context and `GET_BP( )` returns `HISHAM.M` / `3000401630`. Construction proves
  nothing — only a read does.
- **And the reads answer real rows. Settled too, on E10.** `ZRAK_CJ_API_DIAG`,
  partner `3000401630`, guid derived from BUT000, session key 64 characters:
  `PropertiesSet Type=Parcel` returned **three parcels** with `PARCELID`,
  `LANDUSE`, `PARCELSTATUS`, `SECTOR` and validity dates filled — a real read
  through `ZCL_RAK_PROPERTY_API`, through the request context, outside Gateway.
  `FeesSet`/`TrackerSet`/`ProjectSet` answered 0 rows in the same run, which is
  correct: no case, journey or screen was supplied, so their filters matched
  nothing. **What is still unproven is the last link only** —
  `ZCL_RAK_CJ_CTX=>BUILD( io_ctx )` reading the key out of the journey's own
  `USERDATA` launch parameter at runtime. The diag builds `TY_CTX` by hand and
  deliberately bypasses it. Run one migrated journey with a PARCEL field to
  close that.
- **The parcel full-details dialog is `GET_EXPANDED_ENTITY`, SINGULAR — this file
  said `ENTITYSET` and that was wrong.** The live URL settles it:

  ```
  PropertiesSet(Intreno='I800100108658',
                Partnerguid=guid'6aa93cf9-0402-1ed6-b5ca-421c803dd3ad')
    ?$expand=ToProject,ToPartner,ToMeasurement,ToLandUse,ToDevelopment,ToAttachment
  ```

  A key in the path decides the method: `EntitySet?$expand=` routes to
  `GET_EXPANDED_ENTITYSET`, `EntitySet(key)?$expand=` to `GET_EXPANDED_ENTITY`. So the
  six empty tabs were being chased through a method the dialog never calls. **CJS
  already holds both key parts** — `Intreno` from the parcel row, `Partnerguid` from
  `MS_CTX` — so nothing new has to be resolved. Whether the singular method wants
  `IO_EXPAND` at all is **unread**: only the plural one is known to dereference
  `GET_CHILDREN( )` unguarded. Run **`ZRAK_CJ_EXPAND_DIAG`** — it prints the DPC's own
  signature for every method whose name mentions EXPAND, which answers it in one run.
  `PropertiesSet` also has a flat `_GET_ENTITYSET`, which is what the parcel **list**
  uses, and that is why the list works.
- **`GET_EXPANDED_ENTITYSET`, the plural one, is still unreached** and still holds
  `FloorSet` (`RAK_FLOORUNIT`) — which exists *only* inside it, under
  `iv_entity_name = gc_floor` — plus `Project` and `License`.
- **A field's options now have a FOURTH source: an `API:` directive in `DEFAULT_VAL`.**
  `ZCL_RAK_MIGRATOR->BIND_TABLE( )` writes it, `ZCL_RAK_CJ_OPTS->RESOLVE( )` reads it,
  and `RENDER_ONE( )` consults it **ahead of the DDIC resolver** — an API-bound field
  must never fall through to a domain that happens to share its name, because a wrong
  list is harder to notice than no list. The composite ftypes (`PARCEL`, `PROPERTY`,
  `TITLEDEED`, `CONTRACT`, `FLOORUNIT`, `BUILDINGS`) render through the `SELECT`
  branch. **`RENDER_ONE( )` calls the resolver dynamically** (`CALL METHOD
  ('ZCL_RAK_CJ_OPTS')=>('RESOLVE') PARAMETER-TABLE`) on purpose: the chain leads to
  `ZCL_RAK_CJ_API`, which inherits the legacy DPC, and a static reference would stop
  the renderer — every journey and the Studio — from loading whenever anything in that
  chain is inactive. Do not "tidy" it into a static call.
- **`ZCL_RAK_MIGRATOR->RENDER_FTYPE( )` is a WHITELIST, and a cleared result is a
  DELETE.** The field loop reads a blank return as "discard this row", so an ftype
  `CLASSIFY( )` assigns correctly is still thrown away one gate later unless
  `RENDER_FTYPE( )` also names it — and a discarded row never reaches `API_BIND( )`,
  so it gets no `API:` directive either. This is what made M011 step 1 look empty:
  the control was dropped and its **caption**, a separate display row, survived
  alone — the grey "Parcel Selection:" box is a label whose control was deleted out
  from under it. Add a new ftype in **both** places. `SIGN`, `CHEMICALS`, `ACCOM`
  and `BOATS` are still deliberately dropped (nothing draws them), but counted and
  named in the run log rather than lumped into `discarded`.
- **The fifteen M journeys already loaded carry the OLD bindings and must be re-run.**
  Three were wrong and are fixed in `BIND_TABLE( )`/`CLASSIFY( )`: `PARCEL` pointed at
  `FindParcelSet` (a `CREATE_DEEP_ENTITY` target that opens a ZGCF case — a selector
  bound to it would have posted a case on every look), `TITLEDEED` at a method name,
  `FLOORUNIT` at the wrong set; and the five partner-search controls were typed `'BP'`,
  which is a `RENDER_POPUP( )` branch, not a field ftype, so they drew a plain input
  box where a search belongs — they are `'SEARCH'` now. Re-run `ZRAK_M_MUNI_LOAD`
  (teardown, then migrate) after activating; the rows do not update themselves.
- **Never hand-write the shape of a standard SAP object you cannot open from here.**
  `ZCL_RAK_CJ_REQ_CTX` was written three times as `INHERITING FROM
  `/IWBEP/CL_MGW_REQUEST`` with `GET_REQUEST_HEADERS` redefined, and each activation
  only revealed the next invisible fact — `MT_HEADERS` is already the parent's, the
  constructor wants a mandatory `IR_REQUEST_DETAILS` of an unreadable type, and the
  returning parameter is `RT_HEADER` not `RT_REQUEST_HEADERS`. Implementing
  `/IWBEP/IF_MGW_REQ_ENTITYSET` instead is worse: ~45 methods plus a component
  interface, each missing one an activation error. It is now a **factory** that reads
  the candidate class's own `CONSTRUCTOR` by RTTI, builds a `PARAMETER-TABLE` from
  whatever it declares mandatory, and creates it dynamically — `CREATE OBJECT ... TYPE
  (name) PARAMETER-TABLE` — trying `/IWBEP/CL_MGW_REQUEST_UNITTST` (SAP's own
  request context for a DPC with no HTTP request behind it) then
  `/IWBEP/CL_MGW_REQUEST`. Nothing in the source names a signature, so it activates
  whatever those turn out to be, and a wrong guess becomes a **catchable runtime
  error** instead of a class that will not load. `GET( )` may return unbound; that
  degrades rather than dumps, because every DPC call in the layer sits inside
  `CATCH cx_root` → `TO_MSG( )`. Run **`ZRAK_CJ_REQCTX_DIAG`** before theorising — it
  prints both constructors as the system declares them plus the last error.
- **E016/E017/E018 rebuilt a control that has a backing service.** The legacy
  `CHEMICALS_DETAILS` control reads `ChemicalHistorySet` (`zega_fw_fnd_srv`, filtered
  by `IvPermit`/`IvTradeLicense`/`IvRegisteredEmirates`/`IvImpExpType`) to offer the
  citizen their previous chemical declarations. `ZCL_RAK_MIGRATOR->CLASSIFY( )` has no
  branch for it, so it fell to `WHEN OTHERS` and became a text box; the three handlers
  then hand-built ~2,700 lines of dialog with exactly that entity set's fields
  (`CHEMICAL_NAME_POP`, `MATERIAL_NAME_POP`, `CAS_POP`, `HS_CODE_POP`, `PACKAGING_POP`)
  and **no history lookup**. No CJS class references `ChemicalHistorySet`. The known
  E016/E017/E018 defects below all sit in that replacement.
- **`ACCOMODATIONS` (E030/E130) is the same shape** — `WHEN OTHERS` in the migrator,
  and its real source is `PortAccommodationSet` + `WorkersListSet` on a fifth service,
  `ZEGA_EPDA_MAPLET_I_SRV`, which is in no repository here. `RAK_BOATCONTROL`
  (NE001/NE002, not yet migrated) is also unclassified.

- **The fifteen Municipality journeys (M011..M035) are staged in `ZRAK_M_MUNI_LOAD`,
  not yet run.** An M-code is not a legacy screen name: the Municipality screens are
  named by mnemonic (`NSUBDIVISION`, `NMERGE`, `NCBR`, `NOG`, `NNTC`...) and the M-code
  appears only as the `VALUE` of each screen's `JOURNEYTYPE` row, so the code-to-family
  mapping is carried in that report's table rather than derived. Each service exists
  three times — `<FAM>_n` desktop, `M<FAM>_n` mobile, `N<FAM>_n` current — and `N` is the
  one to migrate, as E023/E028/E029 already did. `IV_SCREEN_PREFIX` is always passed:
  `NSUBDIVISION_1_*` and `NSUBDIVISION_2_*` both derive to `SUBDIVISION` through
  `JOURNEY_OF_SCREEN( )`, and they are two separate services (apply-and-pay-initial-fee,
  then the later stage), not two halves of one wizard. Three things in that report are
  **unresolved and flagged in its header**: the six TEN journeys are mapped by mnemonic
  because their `JOURNEYTYPE` rows are wrong (NMTC says M032, NCTC/NPOA/NCPA all say
  M030); M029 has three DML families and only `NACO_1` is taken; and M016's title says
  "Building Regulations/Change of Land Use" while the code resolves to CBR alone — CLU
  is M015, a service not on the list.
- **Twelve of those fifteen carry `RAKPAY`, which the migrator drops.** The report sets
  `HANDLER_CLASS = ZCL_RAK_JOURNEY_LOGIC` on them — it is `CREATE PUBLIC` and concrete,
  so it supplies the payment card and the PAID gate with no subclass — but the `PAYFEE`
  **field** is still gone and has to be re-added per journey in the Studio. Until then
  those steps have no pay control at all.

- **E128 needs pulling and activating.** Its PAID gate fix is in git and was reverted
  once by a stage-without-pull; until the `Overwrite local object` row is ticked and the
  class activated, that journey can still be submitted unpaid.
- **Whether E014, E016, E017 and E018 should strip `PAY_*`/`PAYFEE` on post is unresolved.**
  They redefine `ON_BEFORE_POST` without chaining and without stripping, which is correct
  for a fee-bearing journey and wrong otherwise. Deciding it needs the `ZRAK_T_JNY_FLD`
  rows for those journeys - config, not git.
- **E017's dead `RENDER_OWN_POPUP( )` types CAS Number as `type = 'Number'`**, which would
  render blank for a value like `7732-18-5`. Unreachable today, so flagged not fixed.
- **E016 carries a stale duplicate of its Add Chemical dialog** under `WHEN C_EVT_DETAILS`,
  unreachable because popups always open with `C_CHEM`. Its bindings were corrected but it
  should be deleted; that is E016's owner's call.
- **~30 handler classes have only been pattern-scanned, not read.** The scans cover the
  traps in this file; a logic error unique to one journey (E017's non-blocking validation
  was exactly that) only surfaces on a real read.

- **Five DDIC changes are in git but not necessarily in SAP**: `ZRAK_T_JNY` gained
  `DRAFT_MODE` / `ATTACH_MODE`, `ZRAK_CJ_LAY` gained `FLOW`, `ZRAK_T_JNY_FLD` gained
  `ZSECTION_AR` and `CLOSED_LIST`, and `ZRAK_T_JNY_STEP` gained `NO_ACTION`. All need
  activation **and a table adjust** before the
  code reading them behaves. `ZSECTION_AR` additionally needs its Studio maintenance screen
  regenerated — the `ZCL_RAK_CJS` field editor already has a "Section (AR)" input wired to it,
  but the column won't reach a plain SM30/view-cluster screen on `ZRAK_T_JNY_FLD` until that's
  done. `CLOSED_LIST` (`FTYPE 'SELECT'` only — `'X'` renders `sap.m.Select` instead of the
  default typable `sap.m.ComboBox`, with `forceselection = abap_false` so an empty value
  draws an empty box rather than the first option — see the trap above) is fully wired
  end to end — DDIC column, `ZCL_RAK_JOURNEY_REPO`
  mapping, `ZCL_RAK_JOURNEY_RENDER`'s branch, and a "Closed list" checkbox in the Studio field
  editor — same activation caveat as the other three.
  `NO_ACTION` (`ZRAK_T_JNY_STEP`) is the **footer's fourth state**: `RENDER_FOOTER( )`'s
  three-way is Next / Close / Submit with no value for "this step is answered by acting on
  the page", so a search step that navigates by picking a row got a Close button that
  abandons a journey the citizen has not started. `'X'` returns after Back and the message
  strip and draws no primary action at all — including Pay, deliberately, since "no primary
  action" that made an exception for the one button that costs money would be the wrong
  half. It is **not** `NO_FORWARD`, which removes Next and lets Close or Submit through.
  Wired end to end with a "No footer action" checkbox in the Studio step editor; the SM30
  screen (`ZFG_MV_JNY_STEP`) needs regenerating, same as `ZSECTION_AR`.
- **`ZRAK_T_JNY_FLD-WIDTH` is read now, and it was not before.** The column has always
  existed and the Studio has always saved it; `ZCL_RAK_JOURNEY_UTIL=>CTRL_WIDTH( )` returned
  a per-type default and nothing else, and the Studio label said "Width (not applied yet)"
  in as many words. It now comes back through `TY_FIELD-CTRL_WIDTH` (named for the method,
  to keep it apart from the **cell** width in `ZRAK_CJ_LAYOUT`) and outranks both the type
  default and the laid-out cell's `100%` — the second one matters, because a laid-out step
  is exactly where two controls of different types come out different widths. **No DDIC
  change and no table adjust**, but for the same reason a width somebody typed years ago
  starts taking effect the moment the loader is active. `CFG_WIDTH( )` accepts only `%` and
  `rem`: a px width does not collapse on a phone, and a refused value falls through to the
  type default *and* leaves the cell's `100%` in place, so a typo renders as it did before
  rather than as a broken row.
- `ZRAK_CJ_ATT_PURGE` **has never been run.** Nothing has ever purged `ZRAK_CJ_ATTX`, so every
  file staged against an abandoned journey is still there with its content and its uploader.
  Test run is the default; schedule it once the retention days are agreed.
- **EC01's declaration is half reconstructed.** Everything after "…held responsible for" was
  written in `ZCL_RAK_TEXT=>LONG_TEXTS( )` because `ZLABEL` truncated the original at 150
  characters and it exists nowhere else. It is the most conservative ending available and is
  flagged in capitals at the method. **Needs sign-off from whoever owns the wording.**
- Four draft hooks are declared but not called: `GET_DRAFTS`, `ON_DRAFT_LOAD`,
  `ON_DRAFT_DISCARD`, `ON_ARCHIVE`. There is no CJS-side draft store behind them, which is why
  a derived `DRAFT_MODE` is `OFF` rather than `NATIVE` when no backend will hold the draft.
- Studio auth check is bypassed (`ZCL_RAK_CJS->AUTH_OK` returns early) — accepted in dev,
  **must be restored before production**.
- E018 `own_form_save` and `render_chem_details` disagree on grid row layout; Edit/Delete raise
  events nothing handles; `chem_form_load` still carries test values.
- `D014` is claimed by two handler classes.
- Notary `ZRAK_NOT_LOAD` seeds `P1_IDNUM` / `P2_IDNUM` with a live test Emirates ID
  (`784-1988-2718131-8`) and `P1_SEARCHBY` / `P2_SEARCHBY` with `YFS002`, so the partner search
  can be pressed without typing. **Remove the two `DEFAULT_VAL` lines before production.**
- Notary parties run the LIGHT partner search — `NO_MOI_CALL`, findings as warnings.
  `ZCL_RAK_NOT_APPROVAL_LOGIC->BP_OPTS( )` is the one place to restore full verification.
