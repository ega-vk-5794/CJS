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
- **The Arabic column used to be shorter than its English twin** — `ZLABEL_AR` was `CHAR(80)`
  against `ZLABEL`'s `CHAR(150)`, so Arabic truncated on insert while English did not. Every
  EN/AR pair in `ZRAK_T_JNY*` is now the same length, but **only in git**: it is a DDIC widening
  that needs activation and a table adjust before it is true in SAP.
  Long consent paragraphs still belong in `DEFAULT_VAL` (`CHAR(1000)`) as a `DISPLAY` field —
  150 characters is not a paragraph in either language.

## Conventions

- **Config before code.** Show/hide belongs in `ZRAK_T_JNY_RULE`, options in `ZRAK_T_JNY_OPT`.
  Write ABAP for payment routing, live BP search, cross-container side effects.
- **Migrating a legacy screen?** Drive `ZCL_RAK_MIGRATOR`. Do not hand-author `ZRAK_T_JNY*`
  `INSERT`s — they drift from its mapping.
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

## Open items

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
