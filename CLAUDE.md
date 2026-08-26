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
- **Source files are CRLF.** `sed -i` strips them on this machine; use `perl -i -pe` and check
  `file -b` afterwards.
- **New engine capability?** Cover it in `ZCL_RAK_TEST_ALL_LOGIC`, which exercises every hook
  and runs with no database dependency.

## Hooks

The traps above are also enforced mechanically in `.claude/hooks/`, so they block before a
mistake lands rather than relying on this file being read closely:

| Hook | Event | Enforces |
| --- | --- | --- |
| `session_start.py` | SessionStart | Pulls `main`, reprints the short list of rules below |
| `block_legacy_writes.py` | PreToolUse (Write/Edit/MultiEdit) | The namespace boundary — denies creating/editing a legacy-namespace object |
| `check_journey_rules.py` | PreToolUse (Write/Edit/MultiEdit) | `ON_CUSTOM_VALIDATE` redefinitions call `super->` before any `CHECK`; `commit_step( )` is never called from `ON_BEFORE_POST`/`ON_BEFORE_TABLES` |
| `protect_abapgit_config.py` | PreToolUse (Write/Edit/MultiEdit) | Asks for confirmation before touching `.abapgit.xml` / `*.devc.xml` |
| `check_crlf.py` | PostToolUse (Write/Edit/MultiEdit) | Flags a file under `src/` that lost its CRLF line endings |

> **They are not running on this machine.** Every hook shells out to `python3`, which here
> resolves to the Windows Store alias stub: it prints an install message and **exits 0**, so
> every check silently passes. Verify with `echo '{}' | python3 .claude/hooks/check_crlf.py`
> before trusting anything below. Until a real Python is on PATH, the CRLF rule and the
> namespace boundary are conventions you enforce by hand, not guardrails.

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

**The pull dialog pre-ticks only Add local object rows.** Every `Overwrite local object` row arrives
**unticked**, and the ticks reset every time the dialog opens - so an existing object is skipped
unless you tick it by hand, on every pull. abapGit still reports success, which is why this reads as
"the pull is broken" rather than "that row was not selected".

## Open items

- **Two DDIC changes are in git but not necessarily in SAP**: `ZRAK_T_JNY` gained
  `DRAFT_MODE` / `ATTACH_MODE`, `ZRAK_CJ_LAY` gained `FLOW`. Both need activation **and a table
  adjust** before the code reading them behaves.
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
