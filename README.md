# CJS — RAK Customer Journey Studio

A metadata-driven wizard engine for RAK government services, running on SAP with
[abap2UI5](https://github.com/abap2UI5/abap2UI5). A service is **rows in tables**, not a program:
one generic engine reads `ZRAK_T_JNY*` and renders, validates and posts the journey. You only
write ABAP for logic that configuration genuinely cannot express.

---

## 1. The sync loop

This repo is in abapGit format. Two systems hold the same code:

- **SAP** is where code *runs*.
- **GitHub** is where code is *reviewed and kept*.

abapGit is the bridge. Nothing moves between them on its own — someone presses a button.

### Bring GitHub changes into SAP

1. `SE38` → run **`ZABAPGIT_STANDALONE3`**
2. Pick the **CJS** repo (`github.com/ega-vk-5794/CJS`)
3. Check the branch selector says **`main`**
4. Press **Diff first.** This is the step people skip. Pull *overwrites* SAP objects with the
   repo version — if something in SAP is newer, Diff is your only chance to see it before it's gone.
5. **Pull**
6. Activate the objects — `SE24`, or mass-activate in ADT

### Send SAP changes to GitHub

1. Same transaction → **Stage**
2. **Diff** each object, so you know what you're committing
3. **Add** the objects → **Commit**

### One branch

`main`, and only `main`. Don't create others — a second branch means two truths about what the
service does, and abapGit points at exactly one of them.

---

## 2. Running it

Everything is served from one ICF node, `/sap/bc/rest/egardcjs`, and selected by `app_start`:

| What | URL |
| --- | --- |
| Studio (author journeys) | `…/sap/bc/rest/egardcjs?sap-client=200&app_start=ZCL_RAK_CJS` |
| Run a journey | `…&app_start=ZCL_RAK_JOURNEY_ENGINE&journey=<JOURNEY_ID>` |
| KPI dashboard | `…&app_start=ZCL_RAK_CJ_DASH` |

Useful query parameters when running a journey: `lang=EN|AR`, `trace=X` (shows what the engine
decided and which backend it used), `caseid=` / `draftid=` to resume.

Reports worth knowing:

- **`ZRAK_CJS_XCHECK`** — compares a journey against the ShapeIt `/QNV/` configuration it posts to.
  Also runs inside the Studio now, on load and save.
- **`ZRAK_<code>_LOAD`** — re-runnable seed programs for the journeys held in this repo.

---

## 3. House rules

Each of these exists because breaking it has already cost time.

**Never change the legacy `/QNV/` BAdI.** It must keep behaving exactly as legacy. If something
needs to change, change it on the CJS side — handler class, config, or engine. A BAdI edit to suit
CJS regresses the legacy services CJS is migrating away from, and the damage shows up far from
the change.

**Handler classes inherit; they do not declare the interface.**

```abap
CLASS zcl_e999_my_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic   " <- this
  FINAL
  CREATE PUBLIC.
```

`INTERFACES zif_rak_journey_logic` obliges you to implement all ~25 methods, so the class will not
activate. Inheriting gives you the empty defaults *and* the payment card for free. Redefine only
what you need.

**When you redefine `ON_CUSTOM_VALIDATE`, call `super->` first.** The base implementation is the
PAID gate — it refuses a submit while the fee is unpaid. A redefinition *replaces* it, so leaving
the call out silently removes payment protection from your journey.

```abap
rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                     iv_step = iv_step ).
```

Two details: it goes **before** any `CHECK` (a failing `CHECK` exits the method), and if you then
assign `rt` directly, use `rt = VALUE #( BASE rt ( … ) )` so you extend the result instead of
discarding it.

**Configuration before code.** Show/hide belongs in `ZRAK_T_JNY_RULE`, not in `on_change`. Options
belong in `ZRAK_T_JNY_OPT`, not in `on_value_help`. Write ABAP for things config cannot do:
payment routing, live BP search, cross-container side effects.

**Migrating a legacy screen? Drive `ZCL_RAK_MIGRATOR`.** It already maps `/QNV/SB_UI_DEFIN`
control types to CJS field types, builds grid specs and extracts show/hide rules. Hand-written
`INSERT`s drift from its mapping and duplicate work that is already correct.

**Pass constants, not their names.**

```abap
io_ctx->bind( c_cas_pop )     " binds to CAS_POP        — correct
io_ctx->bind( 'C_CAS_POP' )   " binds to C_CAS_POP      — silently empty
```

Binding to an unknown component is legal and raises nothing. The field just renders blank.

---

## 4. Where things live

**Configuration**

| Table | Holds |
| --- | --- |
| `ZRAK_T_JNY` | Journey header — title, layout, theme, handler class, backend wiring |
| `ZRAK_T_JNY_STEP` | Steps |
| `ZRAK_T_JNY_FLD` | Fields |
| `ZRAK_T_JNY_OPT` | Dropdown / radio options |
| `ZRAK_T_JNY_COL` | Grid columns |
| `ZRAK_T_JNY_RULE` | Show / hide / readonly / required rules |

**Core classes**

| Class | Role |
| --- | --- |
| `ZCL_RAK_JOURNEY_ENGINE` | Runtime — serialized between round trips |
| `ZCL_RAK_JOURNEY_REPO` | Reads the tables into one config structure |
| `ZCL_RAK_JOURNEY_RENDER` | Draws the fields |
| `ZCL_RAK_JOURNEY_RULES` | Visibility, requiredness, validation |
| `ZCL_RAK_JOURNEY_GRID` | Editable tables |
| `ZCL_RAK_JOURNEY_LOGIC` | Base class for every handler |
| `ZCL_RAK_CJS` | The Studio |
| `ZCL_RAK_MIGRATOR` | Legacy `/QNV/` → CJS |

**Two extension points**

- `ZIF_RAK_JOURNEY_LOGIC` — per-journey business logic (~25 hooks)
- `ZIF_RAK_JOURNEY_BACKEND` — where the data goes. `ZCL_RAK_BE_FACTORY` picks by
  `BKND_CATEGORY`; anything it doesn't recognise falls through to the legacy QNV bridge, which is
  what keeps existing journeys untouched.

---

## 5. Known limits

- **Label columns are short.** `ZLABEL` is `CHAR(150)` and `ZLABEL_AR` is `CHAR(80)`, so long
  consent and declaration text truncates silently on insert. Carry long paragraphs in
  `DEFAULT_VAL` (`CHAR(1000)`) as a `DISPLAY` field and keep the checkbox label short — but note
  there is only one `DEFAULT_VAL` per field, so the Arabic of a long paragraph has nowhere to live.
- **Some column settings are captured but not enforced** — per-row `REQUIRED`, `DECIMALS`, column
  `SHLP`, and field `WIDTH`. The Studio labels each one, so check the label before relying on it.
  `PINNED` is not implementable at all (`sap.m.Table` has no frozen column) and is disabled.
- **The Studio's authority check is bypassed in dev.** `ZCL_RAK_CJS->AUTH_OK` returns early. It
  must be restored before production — one flag, deliberately left as a flag rather than deleted.
