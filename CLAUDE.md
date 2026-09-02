# CJS — Customer Journey Studio

Metadata-driven wizard engine for RAK government services. ABAP + [abap2UI5](https://github.com/abap2UI5/abap2UI5).
A service is **rows in `ZRAK_T_JNY*`**, not a program: one generic engine renders, validates and
posts it. ABAP is for what configuration cannot express.

Full detail is in [README.md](README.md). This file is the short version plus the rules that
have already cost time when broken.

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
| [`doc/controls/gis-map.md`](doc/controls/gis-map.md) | the parcel map: `RakMap.Map` is an ArcGIS view **in the page**, not an iframe — and the framed Defcon viewer is a different map |
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

## Silent-failure traps

These raise nothing and render nothing. They account for most of the bugs found so far.

- **`io_ctx->bind( 'C_FOO' )`** binds to a model component literally named `C_FOO`. Pass the
  constant, not its name: `bind( c_foo )`.
- **A field name not on the journey** — `set_val`/`get_val`/`bind` against it are all legal and
  all do nothing. Check `ZRAK_T_JNY_FLD` before trusting a name.
- **`type = 'Number'` on a non-numeric value** renders an empty `sap.m.Input`.
- **A step whose `BKND_SCREEN` has no legacy configuration rows** renders, validates and posts, and
  creates nothing. `ZCL_RAK_CJS_XCHECK` exists for this; it runs in the Studio on load and save.
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
- **A guidance paragraph must never become a caption.** `PAIR_LABELS( )` used to leave a long
  DISPLAY row pending and attach it to the next control, so the wording landed in `ZLABEL`
  (CHAR 150), was cut mid-word, and `MT_CONSUMED` hid the row it came from — the full text
  then appeared nowhere. `IS_NOTICE( )` now gates it, which also restores the real caption:
  the short row above stays pending and reaches the control.

## Conventions

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
- **Config before code.** Show/hide belongs in `ZRAK_T_JNY_RULE`, options in `ZRAK_T_JNY_OPT`.
  Write ABAP for payment routing, live BP search, cross-container side effects.
- **Migrating a legacy screen?** Drive `ZCL_RAK_MIGRATOR`. Do not hand-author `ZRAK_T_JNY*`
  `INSERT`s — they drift from its mapping.
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
- **`GET_EXPANDED_ENTITYSET` is NOT reachable yet, and that is what limits the layer.**
  It calls `IO_EXPAND->GET_CHILDREN( )` unguarded, so it needs an expand object the
  same way the entity-set reads needed a request context. Everything behind it is
  therefore unserved: `FloorSet` (`RAK_FLOORUNIT`), `Project`, `License`, and the
  parcel **full-details** dialog (`$expand=ToProject,ToPartner,ToMeasurement,…`).
  `PropertiesSet` has a flat `_GET_ENTITYSET` as well, which is the one the parcel
  **list** uses — that is why the list works and the detail view does not.
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

- **Four DDIC changes are in git but not necessarily in SAP**: `ZRAK_T_JNY` gained
  `DRAFT_MODE` / `ATTACH_MODE`, `ZRAK_CJ_LAY` gained `FLOW`, and `ZRAK_T_JNY_FLD` gained
  `ZSECTION_AR` and `CLOSED_LIST`. All four need activation **and a table adjust** before the
  code reading them behaves. `ZSECTION_AR` additionally needs its Studio maintenance screen
  regenerated — the `ZCL_RAK_CJS` field editor already has a "Section (AR)" input wired to it,
  but the column won't reach a plain SM30/view-cluster screen on `ZRAK_T_JNY_FLD` until that's
  done. `CLOSED_LIST` (`FTYPE 'SELECT'` only — `'X'` renders `sap.m.Select` instead of the
  default typable `sap.m.ComboBox`) is fully wired end to end — DDIC column, `ZCL_RAK_JOURNEY_REPO`
  mapping, `ZCL_RAK_JOURNEY_RENDER`'s branch, and a "Closed list" checkbox in the Studio field
  editor — same activation caveat as the other three.
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
