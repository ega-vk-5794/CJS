# Config tables

A journey is rows, not code. This file is the current DDIC shape of every table
CJS owns, plus the nuances that have already cost time.

**Columns here were read out of `src/*.tabl.xml` on 2026-09-06.** When they
disagree with SAP, SAP is right and something in git is unactivated — check the
"Not yet in SAP" list at the bottom before believing either.

## Inventory — 27 tables, four groups

### The seven a journey is authored in

| Table | Key | Holds |
|---|---|---|
| `ZRAK_T_JNY` | `JOURNEY_ID` | header: title, theme, layout, handler class, backend, draft/attachment ownership |
| `ZRAK_T_JNY_STEP` | `+ STEP_ID` | steps: order, title, icon, columns, backend screen, footer behaviour |
| `ZRAK_T_JNY_FLD` | `+ FIELD_NAME` | fields — the bulk of any journey |
| `ZRAK_T_JNY_OPT` | `+ OPT_KEY` | option lists for SELECT / RADIO / CHECKGROUP / SEGMENTED / MULTISELECT |
| `ZRAK_T_JNY_RULE` | `+ RULE_ID` | show / hide / require / set, driven off another field |
| `ZRAK_T_JNY_COL` | `+ COL_NAME` | grid columns for an `EDITABLE_TABLE` / `TABLE` field |
| `ZRAK_CJ_LAYOUT` | `+ BLOCK_ID + ELEM_ID + KIND` | per-element layout overlay, Studio Design tab |

**The layout table is `ZRAK_CJ_LAYOUT`.** Earlier versions of this file and of
`CLAUDE.md` called it `ZRAK_CJ_LAY` — that name does not exist in DDIC. The
*class* is `ZCL_RAK_CJ_LAY`, which is where the confusion comes from; every
`SELECT` in it reads `ZRAK_CJ_LAYOUT`.

### Runtime and support

| Table | Holds |
|---|---|
| `ZRAK_T_CJ_TXT` | bilingual text rows, addressed as `@nnn` from `TEXT:` and from grid headers |
| `ZRAK_CJ_ATTX` | staged attachment content, keyed by `GUID` (`SYSUUID_C32`), body in a `STRG` |
| `ZRAK_CJ_CFG_VER` | one row, one `INT8` — the config version the per-work-process cache compares against |
| `ZRAK_CJ_BKP` | config snapshots for backup/restore; `PAYLOAD` is a serialized `STRG` per table per journey |
| `ZRAK_T_BE_LOC` / `_P` | the local (non-bridge) backend's request store and its party rows |

### Telemetry

| Table | Holds |
|---|---|
| `ZRAK_T_CJ_EVT` | raw events — one row per launch, step, back, submit, with `DURATION` and `OUTCOME` |
| `ZRAK_T_CJ_AGG` | daily aggregate, keyed by date/sysid/journey/step/type/langu/channel/role, with `DUR_P50` and `DUR_P95` |

### Migration and samples

| Table | Holds |
|---|---|
| `ZRAK_T_MIG_RAW` | the raw `/QNV/` export a migration ran from — `RAW_JSON` and `SCRIPT` kept as `STRG` |
| `ZRAK_T_LICSMP` | sample licence application, for the demo journey only |

`Z2UI5_T_01`, `Z2UI5_T_91` and the nine `ZCJ_Z2UI5_*` tables belong to
abap2UI5 and its control gallery. **Nothing in CJS writes them** — `Z2UI5_T_01`
is where the serialized app instance lives between round trips, which is why a
draft id round-trips to the browser and the app state does not.

## Always invalidate the cache

```abap
zcl_rak_cj_cfg_cache=>invalidate( iv_journey = '...' ).
```

A versioned per-work-process cache means another work process keeps serving the
old config. Skip this and a correct config change looks like nothing happened.

---

# `ZRAK_T_JNY` — the header

| Column | Type | Notes |
|---|---|---|
| `JOURNEY_ID` | `ZRAK_JOURNEY_ID` | key |
| `TITLE` / `TITLE_AR` | `CHAR(120)` | |
| `SUBTITLE` / `SUBTITLE_AR` | `CHAR(150)` | |
| `CJ_TYPE` | `CHAR(30)` | prefixes the synthetic key when no backend mints one |
| `TILE_CODE` | `ZDE_CJ_JOURNEYID` | **the portal's code**, e.g. `M011`, `E001`. `GETSCREENSET_GET_ENTITYSET` looks the journey up by this, not by `JOURNEY_ID` |
| `HANDLER_CLASS` | `CHAR(30)` | blank is fine; `ZCL_RAK_JOURNEY_LOGIC` is concrete and gives the payment card and PAID gate with no subclass |
| `ACTIVE` | `CHAR(1)` | **the engine's `SELECT` filters on it.** Blank means the journey will not run, and cannot be previewed in the Studio either |
| `LAYOUT_MODE` | `CHAR(12)` | `WIZARD` |
| `THEME_VARIANT` | `CHAR(12)` | `PORTAL` (what the migrator sets) or `PREMIUM` |
| `ACCENT_TYPE` | `CHAR(20)` | a UI5 button type — `Emphasized` |
| `DENSITY` | `CHAR(12)` | `Cozy` / `Compact` |
| `BRAND_COLOR` / `NAVY_COLOR` | `CHAR(30)` | only read when `THEME_OWN` is set |
| `THEME_OWN` | `XFELD` | take the two colours above instead of the variant's |
| `SHOW_ACTIONS` | `CHAR(1)` | draws Save-as-Draft / Delete in the header |
| `DRAFT_MODE` / `ATTACH_MODE` | `CHAR(10)` | `DELEGATE` / `NATIVE` / `OFF`, blank derives — see below |
| `BKND_ACTIVE` | `CHAR(1)` | switches the whole bridge path on |
| `BKND_CATEGORY` | `CHAR(40)` | the case category sent to the BAdI |
| `BKND_JOURNEY` | `CHAR(10)` | becomes `PARAM2` and therefore the **BAdI filter** |
| `BKND_FM_POST` / `BKND_FM_READ` | `CHAR(30)` | override the default `ZFM_EGA_CJ_FW_*_N` |
| `CHANGED_BY` / `CHANGED_AT` | | Studio audit |

## Draft and attachment ownership

Blank derives, and the derivation is the rule worth knowing: **a backend that
creates and re-opens the case IS the draft**, so CJS delegates and keeps no
second copy. Attachments derive from `capabilities( )-attachments` instead,
*not* from whether a case exists — a backend can own the case and still have
nowhere to put a file.

`OFF` is refused in `HANDLE_SAVE( )`, not merely hidden in the renderer: a
hidden button is not an unreachable event. There is **no native draft store
yet**, so a derived `DRAFT_MODE` with no backend is `OFF`, not `NATIVE`.

---

# `ZRAK_T_JNY_STEP` — steps

| Column | Type | Notes |
|---|---|---|
| `STEP_ID` | `ZRAK_JOURNEY_STEP` | key |
| `SEQNR` | `INT4` | order |
| `TITLE` / `TITLE_AR` | `CHAR(120)` | |
| `ICON` | `CHAR(60)` | `sap-icon://…` |
| `COLUMNS` | `INT4` | see below |
| `BKND_SCREEN` | `CHAR(30)` | the `/QNV/` screen name. **A step whose screen has no legacy rows renders, validates, posts and creates nothing** |
| `ACTIVE` | `CHAR(1)` | |
| `NEXT_REQUIRES` | `CHAR(30)` | a field that must hold a value before the footer moves on |
| `NO_FORWARD` | `CHAR(1)` | removes Next; Close and Submit still draw |
| `NO_ACTION` | `CHAR(1)` | draws **no** primary action at all — including Pay |

**The column is `NEXT_REQUIRES`.** It was written as `NEXT_REQ` in this file for
a while and a feeder using that name does not compile. `ZCL_RAK_CJS` validates
that the named field exists on the journey and reports it if not.

**`NO_ACTION` is not `NO_FORWARD`.** `NO_FORWARD` removes Next and lets Close or
Submit through. `NO_ACTION` returns after Back and the message strip and draws
nothing — deliberately including Pay, since "no primary action" that made an
exception for the one button that costs money would be the wrong half. It exists
for a search step that is answered by picking a row, which used to get a Close
button that abandons a journey the citizen has not started.

**`COLUMNS` does two jobs**: it arranges FGROUP headings, and it lays out
consecutive `UPLOAD` fields that many per row. Blank or 1 keeps uploads stacked.

---

# `ZRAK_T_JNY_FLD` — fields

The 36 columns, current:

| Column | Type | Notes |
|---|---|---|
| `FIELD_NAME` | `ZRAK_JOURNEY_FIELD` | key. **Ceiling is 23, not 30** — see below |
| `SEQNR` | `INT4` | order. Unique per step, or the order is whatever the database returns |
| `FTYPE` | `CHAR(15)` | the control — 47 valid values, listed below |
| `ZLABEL` / `ZLABEL_AR` | `CHAR(150)` | **cut on INSERT** — see below |
| `PLACEHOLDER` / `PLACEHOLDER_AR` | `CHAR(150)` | |
| `ZSECTION` / `ZSECTION_AR` | `CHAR(60)` | panel heading. Setting this **and** `ZLABEL` to one string prints it twice |
| `DEFAULT_VAL` | `CHAR(1000)` | five different jobs — see below. **No `_AR` twin** |
| `FGROUP` | `CHAR(60)` | `'ROW:<token>'` puts fields side by side; a bare value is an FGROUP heading |
| `FSTATE` | `CHAR(15)` | UI5 ValueState for `STATUS` / `PROGRESS`: `None` `Success` `Warning` `Error` `Information` |
| `WIDTH` | `CHAR(10)` | **read now, and it was not before** — `%` and `rem` only |
| `HIDDEN` / `READONLY` / `REQUIRED` | `CHAR(1)` | rules and handler overrides outrank all three |
| `REGEX` | `CHAR(255)` | |
| `MIN_LEN` / `MAX_LEN` | `INT4` | **never read `MSG`** except through an explicit `LEN:` clause |
| `MIN_VAL` / `MAX_VAL` | `CHAR(20)` | |
| `MSG` / `MSG_AR` | `CHAR(255)` | per-check clauses — see below |
| `HAS_ATTACH` / `ATTACH_LABEL` | | `ATTACH_LABEL` doubles as the grid Add-row caption |
| `ATTACH_TYPES` / `ATTACH_MAXMB` / `ATTACH_MULTI` | | |
| `ROLLNAME` / `DOMNAME` / `SHLP` | `CHAR(30)` | three of the four F4 sources |
| `TECH_NAME` | `CHAR(100)` | **posts to the backend. Missing = renders and posts nothing.** Grids use a `[]` suffix |
| `CLOSED_LIST` | `CHAR(1)` | `SELECT` only — `sap.m.Select` instead of the typable `sap.m.ComboBox` |
| `NO_BROWSE` | `CHAR(1)` | `SEARCH` only — suppresses the partner-browse button. Opt-in, so blank is unchanged |

**The runtime component is `default`, not `default_val`.** The DDIC column is
`DEFAULT_VAL`; `ZIF_RAK_JOURNEY=>TY_FIELD`, which is what hook code reads, calls
it `default`. `ls_field-default_val` in a handler does not compile.

**`ZSECTION_AR` exists now.** An earlier version of this file said section
headings had no Arabic twin and were English on every journey. That was true and
is not any more — the column is in git, pending activation and a table adjust,
and the Studio field editor already writes it.

## `FTYPE` — the 47 valid values

Read out of `ZCL_RAK_JOURNEY_UTIL=>KNOWN_TYPE( )`:

```
(blank) INPUT EMAIL PHONE NUMBER COUNT CURRENCY TEXTAREA DATE TIME DATETIME
SELECT MULTISELECT RADIO CHECKBOX CHECKGROUP SWITCH SEGMENTED SLIDER STEPPER
RATING DISPLAY READONLY STATUS OBJNUM PROGRESS LINK SEARCH TABLE EDITABLE_TABLE
UPLOAD PAYFEE REVIEW RO_PANEL RECORDCARD REQPANEL CAPTCHA
PARCEL PARCELS PROPERTY TITLEDEED FLOORUNIT CONTRACT BUILDINGS SIGN CHEMICALS
ACCOM BOATS
```

**An ftype has to be registered in FOUR places**, and each miss fails
differently:

1. the renderer's branch — or the field draws as a plain input
2. `IS_BLOCK( )`, if it is a panel rather than one control — or it reaches
   `RENDER_ONE( )` and draws only its first element
3. `KNOWN_TYPE( )` — or the page reports *"unsupported type — rendered as a
   plain input"* **while rendering correctly**, which reads as the control
   having failed
4. both Studio type lists — or an author cannot pick it

Blocks, per `IS_BLOCK( )`: `SEARCH` `TABLE` `UPLOAD` `PAYFEE` `EDITABLE_TABLE`
`RECORDCARD` `REQPANEL` `PDF` `CAPTCHA`.

> **`PDF` is in `IS_BLOCK( )` and NOT in `KNOWN_TYPE( )` — live defect.**
> Verified 2026-09-06 at `zcl_rak_journey_util.clas.abap:295`. Commit `bc1a7ee`
> is titled "PDF was missing from KNOWN_TYPE" but its one added line landed in
> `IS_BLOCK( )` instead, and a later `CAPTCHA` insertion has left `KNOWN_TYPE( )`
> without it. So a `PDF` field renders and *also* reports itself unsupported.
> One line fixes it; it has been flagged repeatedly and never authorised.

## Field names have a hard ceiling of 23, not 30

`BUILD_MODEL( )` calls `CL_ABAP_STRUCTDESCR=>CREATE( )` per field, and a model
component is capped at 30 — but the model also builds `_VS`, `_VST`, `_IDTYPE`,
`_NAME`, `_IX` and `_EXP` companions on the same name. `_IDTYPE` is the longest
at 7, so **23 is the real limit**, and `CX_SY_STRUCT_COMP_NAME` is uncaught: an
over-long name kills the whole app with UNCAUGHT EXCEPTION rather than hiding
one field. Any runtime-derived name (a Notary blueprint `jsonKey`) goes through
`ZCL_RAK_JOURNEY_UTIL=>COMP_NAME( )`, never plain `to_upper( )`.

The same 23 is why `ZRAK_CJ_LAYOUT-ELEM_ID` is `CHAR(23)` and not 30 — see the
layout section.

## `DEFAULT_VAL` does five different jobs

1. **A default value**, plainly.
2. **The grid column spec**, pipe-separated, when the field is a grid and
   `ZRAK_T_JNY_COL` has no rows for it.
3. **The pick target** on a `TABLE`.
4. **Long field text** behind `TEXT:` — `TEXT:I hereby certify…` literally, or
   `TEXT:@042` to resolve `ZRAK_T_CJ_TXT` row 042 by `sy-langu`.
5. **An options binding** behind `API:` — see below.

Plus `DTYPE:` for an uploader's document type, which rides the same column.

**A `TEXT:` default is never seeded as the field's value.** Without that guard a
consent checkbox renders pre-ticked and passes its own required check — the
citizen consents by loading the page.

## The fourth option source: an `API:` directive

`API:<api>:<entityset>[:<domain>[:<filter>]]`, read by
`ZCL_RAK_CJ_OPTS=>RESOLVE( )` **ahead of the DDIC resolver** — an API-bound
field must never fall through to a domain that happens to share its name,
because a wrong list is harder to notice than no list.

```
API:PROPERTY:PropertiesSet::Type=Parcel
```

The empty domain slot before the filter is required. Only `PROPERTY` and
`MAPLET` have resolver branches today; `TENANCY`, `SIGN`, `VALUEHELP` and `FND`
are named in the migrator's bind table and **their wrapper classes do not
exist** — a field bound to one of those gets no options and no error.

`RENDER_ONE( )` calls the resolver **dynamically** on purpose, because the chain
leads to `ZCL_RAK_CJ_API`, which inherits the legacy DPC. A static reference
would stop the renderer — every journey and the Studio — from loading whenever
anything in that chain is inactive. Do not tidy it into a static call.

## The parcel / property composites

| FTYPE | Draws |
|---|---|
| `PARCEL` | the live card list, single-select, one Select button per card |
| `PARCELS` | the same list **multi-select**, a checkbox per card, storing a `-` separated list |
| `PROPERTY` / `TITLEDEED` | as `PARCEL`, different `Type` filter |
| `REVIEW` | the engine's own review renderer — nothing to configure, nothing to post |

`PARCELS` stores its list `-` separated because the backend already does:
`ZIF_EGA_FW_CJI~UPDATE( )` builds the CJ02 note as
`parcel && '-' && ui_table_column1` and splits it back the same way.

All of them need the `API:` directive **as well as** the FTYPE. Without it the
field renders as an empty ComboBox and says nothing.

## `MSG` can be written per check

One column is read by the required check, by `MIN_VAL`/`MAX_VAL`, by the DATE
range, by the numeric CATCH and by REGEX. They never fire together, so this was
only ever a wording limit — but a field that is both REQUIRED and
format-constrained had one column and two sentences to write in it.

`MSG` may carry `KEY:text` clauses separated by `;`:

```
REQUIRED:Please state the number;FORMAT:@201
```

Keys: `REQUIRED` `LEN` `RANGE` `NUMBER` `FORMAT` and `*` as catch-all. Each
clause splits on its **first** colon, so its text may itself be `@nnn` or
`OTR:<alias>`. `ZCL_RAK_JOURNEY_UTIL=>MSG_FOR( )` is the one resolver.

**Additive, and the guard is narrow on purpose**: the keyed form is recognised
only when the text *begins* with one of those keys immediately followed by `:`,
so an ordinary sentence containing a colon behaves exactly as it did.

**`NUMBER:` runs before `FORMAT:` and stops it.** On a field carrying `MIN_VAL`
or `MAX_VAL`, a non-numeric value raises `CX_SY_CONVERSION_NO_NUMBER`, takes
`MSG_FOR( 'NUMBER' )`, and `FORMAT` is never reached. Write **both** on any
field that has a `REGEX` and a numeric range.

`MIN_LEN`/`MAX_LEN` are the exception: they never read a plain `MSG`, only an
explicit `LEN:` clause.

## Long text: the 150-character ceiling

`ZLABEL` is `CHAR(150)` and the cut happens **on INSERT**, in the database. The
rest of the sentence is gone, and no rendering change recovers it. A consent
declaration cut at exactly 150 characters is the signature; `ZCL_RAK_CJS_XCHECK`
rule **X13** reports any label sitting on the limit — Error on a `CHECKBOX`,
Warning elsewhere.

Two places long text can live instead:

- **`DEFAULT_VAL` behind `TEXT:`** — `CHAR(1000)`, read by `LONG_TEXT( )`.
  `TEXT:@nnn` is the form to use when the text must be bilingual, because
  `DEFAULT_VAL` has no `_AR` twin and a literal paragraph shows its English to
  an Arabic reader.
- **`ZCL_RAK_TEXT=>LONG_TEXTS( )`** — keyed by journey and field, both languages
  as literals in git, no ceiling. Preferred for legal wording: a declaration a
  citizen agrees to belongs where a diff shows it changing.

## `OTR:<alias>` works in every bilingual text column

`ZCL_RAK_JOURNEY_REPO->PICK( )` — the one place every EN/AR pair resolves —
checks for the prefix after picking a language and calls `SOTR_GET_TEXT_KEY`.
`ENSURE_CONFIG( )` rebuilds the config every round trip, so a wording change in
SOTR reaches the journey with no reseed. An alias with no OTR entry falls back
to the literal `OTR:...` string **on screen**, which is a visible symptom rather
than a silent one.

## Hidden fields are not validated

`VALIDATE_STEP( )` skips them outright:

```abap
IF is_hidden( ls_f ) = abap_true. CONTINUE. ENDIF.
```

So **`REQUIRED` + hidden is safe**, which is what makes a backend-driven
conditional document work: the field is authored required because it *is*
mandatory when shown, and a citizen who never sees it is not blocked.

## The three payment carriers

`PAY_SCREEN`, `PAY_JOURNEY` and `PAY_CATEGORY` are ordinary hidden readonly
fields on the payment step whose `DEFAULT_VAL` carries a value.
`PREPARE_PAYMENT( )` overlays all three onto the config it hands the bridge.

**They are for a payment screen under a DIFFERENT service, and most journeys
should leave all three blank.** Blank means "use the journey's own", which is
right wherever payment is a step of the journey — DOK and EPDA.

**Setting `PAY_JOURNEY` changes the BAdI filter**, which is almost never what
you want. It becomes `CS_HEADER-PARAM2`, and `ZFM_EGA_CJ_FW_READ_N` does
`GET BADI cj_badi FILTERS journey_type = param2`. Point it at a journey with no
implementation and the read returns the screen's definition keys with every
value empty — the screen existed, the BAdI behind it did not. On Municipality
the fee list and the gateway are two screens of the **same** journey, so only
`PAY_SCREEN` moves.

**A carrier's `DEFAULT_VAL` must win over the draft, and "fill when blank" is
not enough.** `PAY_SCREEN` is a model value: it lives in the draft and survives
every round trip, so a journey that has already run with one value never picks
up a corrected `DEFAULT_VAL`. `ZCL_RAK_JOURNEY_LOGIC` re-seeds from config on
every pay event for exactly that reason. The general rule: **for a field that is
static configuration rather than something a citizen types or a backend returns,
config is authoritative and the model copy is only a carrier.**

---

# `ZRAK_T_JNY_OPT` — options

`OPT_KEY` (key), `SEQNR`, `OPT_TEXT`, `OPT_TEXT_AR`.

Feeds `SELECT` `MULTISELECT` `RADIO` `CHECKGROUP` `SEGMENTED`. It is the first
of four option sources; the others are `ROLLNAME`/`DOMNAME` (DDIC fixed values),
`SHLP` (a search help) and the `API:` directive, which outranks the DDIC ones.

---

# `ZRAK_T_JNY_RULE` — rules

| Column | Notes |
|---|---|
| `RULE_ID` | key, **`CHAR(3)`** |
| `SRC_FIELD` / `SRC_OP` / `SRC_VALUE` | the condition |
| `ACTION` / `TGT_FIELD` / `TGT_VALUE` | what to do |
| `TOTABLE` | `CHAR(150)` — targets a grid rather than a scalar field |

**`RULE_ID` is three characters.** Generate `GS01..GS15` and they truncate to
`GS0`/`GS1`, and the INSERT dumps on a duplicate key pointing at the statement
rather than at the naming.

**Operators — eight, not four:**

```
EQ  NE  INITIAL  NOTINITIAL  GT  LT  GE  LE
```

`GT`/`LT`/`GE`/`LE` go through `COMPARE_NUM( )`, which converts both sides to
`DECFLOAT34` inside a `TRY` and falls back to a character comparison when either
side is not numeric.

**Actions — eight, not six:**

```
SHOW  HIDE  REQUIRE  OPTIONAL  READONLY  EDITABLE  SET  CLEAR
```

`READONLY` and `EDITABLE` are mutually exclusive and each deletes the other's
entry, so the last rule to fire wins rather than both applying. `OPTIONAL`
deletes from the required list rather than appending to a list of its own.

**Author both directions.** `SHOW` alone leaves a panel on screen after its
trigger is cleared, still holding values, still posting them. The `HIDE` half is
usually the half that matters.

Rules fire across steps. Several `REQUIRE`s on one target accumulate.

**A CHECKGROUP cannot drive rules.** It stores a comma list and no operator asks
whether a list contains a value. Use separate `CHECKBOX` fields — five
checkboxes and ten rules beat one group plus a handler written around the
config.

**Two independent booleans must be two fields.** One `required` CHECKGROUP is
satisfied by ticking *either* option, which is how a citizen gets past terms
they never accepted.

---

# `ZRAK_T_JNY_COL` — grid columns

`COL_NAME` (key), `SEQNR`, `ZLABEL`/`ZLABEL_AR` (`CHAR(60)`), `CTRL`, `SHLP`,
`ROLLNAME`, `WIDTH`, `ALIGN`, `HIDDEN`, `PINNED`, `READONLY`, `REQUIRED`,
`DECIMALS`, `MAXLEN`, `TOTAL`.

Read by `GRID_COLS( )` in preference to the pipe-separated spec on the field.

| Column | Status |
|---|---|
| `REQUIRED` | **Enforced** — against every row that ALREADY EXISTS, not against the row count, so an empty grid still passes. It makes a started row complete; it does not make the grid mandatory |
| `WIDTH` | applied |
| `PINNED` | **inert** — `sap.m.Table` has no frozen-column feature |
| `DECIMALS` | **inert** — carried into the gcol structure and never read back to format a cell |

The Studio's Columns panel labels the two inert ones. Do not add a caveat to a
label without checking it is still true — one said "not enforced yet" long after
`REQUIRED` was wired up, which is the more damaging direction to be wrong in.

## `EDITABLE_TABLE` or the handler cannot touch it

`GET_GRID_DATA( )` and `SET_GRID_DATA( )` work **only** on an `EDITABLE_TABLE`.
With `FTYPE 'TABLE'` the engine warns and both calls are no-ops.

**And field-level `READONLY` does the same thing** — it takes the rows away from
the handler as well as from the keyboard. For the normal "backend fills it, the
citizen does not type in it" shape:

- `FTYPE = 'EDITABLE_TABLE'`, field `READONLY` **blank**
- `ZRAK_T_JNY_COL-READONLY = 'X'` on **every** column

Do not put `REQUIRED` on a column the backend fills: it refuses the row the
moment the handler adds it, before the read can fill the rest.

## Hiding a column differs by ftype, and this cost a round

- **`EDITABLE_TABLE`** goes through `GRID_COLS( )`, which reads `HIDE` out of
  the **type** slot of the spec and sets `GC-HIDE`.
- **`TABLE`** does not use `GC-HIDE` at all. `RENDER_BLOCK( )`'s own TABLE
  branch re-parses `DEFAULT_VAL` into name / header / type, keeps the header and
  **ignores the type** — so `HIDE` in the type slot changes nothing. What that
  branch hides is a column whose resolved **header** is `-`. Blank is no use,
  because an empty header falls back to the column name.

A feeder that must work on either writes both: header `-` **and** type `HIDE`.

## Rows are positional at both ends

`SET_GRID_DATA( )` matches `is_data-columns` **by name**, so handing back
exactly what `GET_GRID_DATA( )` returned is an identity map and cannot shift a
value. Building a fresh column list is how a cell ends up one place to the left.
A row shorter than the column list has undefined later cells, not blank ones —
pad it.

**A backend TABLE's cells are positional at the far end too, and the two orders
are set in different places.** `ZCL_RAK_JOURNEY_BE` hands cell N to configured
column N; the BAdI fills `FIELDn` from `LIST_SEQUENCE` in `/QNV/SB_UI_DEFIN`.
Nothing checks that the two agree — a column whose `LIST_SEQUENCE` is missing
renders blank, and one whose sequence differs renders the neighbouring value.

**`FIELDn` is `C(250)`.** A `TYPE string` source is cut to fit at the assignment,
silently, inside the BAdI — which is why a 1000-character description comes back
as exactly 250. That structure is legacy and must not be widened; long text
belongs on a scalar field bound to the `GS_DATA` component that holds the whole
string, with the table column left as a summary.

---

# `ZRAK_CJ_LAYOUT` — the layout overlay

| Column | Type | Notes |
|---|---|---|
| `JOURNEY` | `ZRAK_JOURNEY_ID` | key — note the name, **not** `JOURNEY_ID` |
| `STEP_ID` | `ZRAK_JOURNEY_STEP` | key |
| `BLOCK_ID` | `CHAR(30)` | key |
| `ELEM_ID` | `CHAR(23)` | key |
| `KIND` | `CHAR(1)` | key — `F` form, `G` grid |
| `ROW_NO` / `COL_START` / `COL_SPAN` / `LABEL_SPAN` | `INT2` | twelve-column grid |
| `FLOW` / `INLINE` / `HIDDEN` / `FIXED` | `CHAR(1)` | |
| `ALIGN` / `WIDTH` | | |

**`ELEM_ID` is `CHAR(23)` because the primary key would otherwise exceed the
DDIC limit.** It was `CHAR(30)`, which put the key at 124 against a hard ceiling
of 120. 23 is not an arbitrary trim — it is the same ceiling `COMP_NAME( )`
imposes on a field name, so nothing that can legally be an element id is lost.
The key is now 117.

Two flags read alike and are not:

- **`INLINE`** decides which **row** a cell lands on.
- **`FLOW`** decides the direction **inside** one cell. A cell is a `vbox`, so a
  button a handler adds through `AFTER_FIELD( )` always stacks under its field;
  `FLOW` puts it beside instead.

`PERSIST( )` does a full `MODIFY`, so anything writing one attribute must
`RESOLVE( )` the row first and overwrite only its own fields — otherwise it
blanks every other attribute on that element.

**A migrated layout is DERIVED, not designed.** The migrator pairs a legacy
caption row with the control it captions and drops the two into two cells,
because that is the shape of the `/QNV/` definition. Right for an input and its
label; wrong for a composite and wrong for a DISPLAY paragraph — `WIDE_FIELD( )`
forces those two shapes full-width. It overrides two shapes, never the grid: a
cell an author placed by hand stays where they put it.

---

# `ZRAK_T_CJ_TXT` — bilingual text rows

`MSGNO` (key), `TEXT_EN`, `TEXT_AR`, both `CHAR255`.

Addressed as `@nnn` from a `TEXT:` default, from a grid column header, and from
a `MSG` clause. `ZCL_RAK_TEXT` reads it. Because `PICK( )` re-resolves every
round trip, changing a row changes the wording with no reseed.

---

# Not yet in SAP

Six DDIC changes are in git and need **activation and a table adjust** before
the code reading them behaves:

| Table | Column |
|---|---|
| `ZRAK_T_JNY` | `DRAFT_MODE`, `ATTACH_MODE` |
| `ZRAK_CJ_LAYOUT` | `FLOW`; and `ELEM_ID` narrowed 30 → 23 |
| `ZRAK_T_JNY_FLD` | `ZSECTION_AR`, `CLOSED_LIST`, `NO_BROWSE` |
| `ZRAK_T_JNY_STEP` | `NO_ACTION` |

`ZSECTION_AR` and `NO_ACTION` additionally need their SM30 / view-cluster
screens regenerated (`ZFG_MV_JNY_STEP` for the step one) — the Studio editors
already write both, but a plain maintenance screen will not show the column
until then.

**Verify by content, not status.** A pull leaves the object inactive and the
runtime keeps serving the old version, so an unactivated DDIC change looks
exactly like a pull that never happened.

# Seed reports

See `seed-reports.md` — structure, idempotency, generated ids, and migrating
from a `/QNV/` export. Do not hand-author `ZRAK_T_JNY*` INSERTs for a migration;
drive `ZCL_RAK_MIGRATOR`, or the rows drift from its mapping.
