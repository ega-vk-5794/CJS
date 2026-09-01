# CJS — Customer Journey Studio

Metadata-driven wizard engine for RAK government services. ABAP + [abap2UI5](https://github.com/abap2UI5/abap2UI5).
A service is **rows in `ZRAK_T_JNY*`**, not a program: one generic engine renders, validates and
posts it. ABAP is for what configuration cannot express.

Full detail is in [README.md](README.md). This file is the short version plus the rules that
have already cost time when broken.

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
- **A grid row written by hand is positional against the *configured* columns.**
  `SET_GRID_DATA( )` maps by name, but the `COLUMNS` a handler passes came straight back from
  `GET_GRID_DATA( )`, so the map is an identity map and cell N lands in configured column N.
  A cell appended out of order is written to the neighbouring column; one appended past the
  last configured column is dropped. Neither raises anything. The order lives in
  `ZRAK_T_JNY_FLD-DEFAULT_VAL` for the grid field — read it before adding or reordering a
  field in an Add-a-row popup's save. E016/E017/E018 each carry this note at their save method,
  and their orders legitimately differ from each other because their specs do.

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
