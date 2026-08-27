# Config tables

Seven tables. A journey is rows, not code.

| Table | Holds |
|---|---|
| `ZRAK_T_JNY` | journey header: title, theme, layout, handler class, backend, draft/attachment ownership |
| `ZRAK_T_JNY_STEP` | steps: `STEP_ID`, `SEQNR`, title, icon, `COLUMNS`, `BKND_SCREEN`, `NEXT_REQ` |
| `ZRAK_T_JNY_FLD` | fields: the bulk of any journey |
| `ZRAK_T_JNY_OPT` | option lists for SELECT / RADIO / CHECKGROUP / SEGMENTED / MULTISELECT / SEARCH |
| `ZRAK_T_JNY_RULE` | rules: `SRC_FIELD`, `SRC_OP`, `SRC_VALUE`, `ACTION`, `TGT_FIELD`, `TGT_VALUE` |
| `ZRAK_T_JNY_COL` | grid columns for an `EDITABLE_TABLE` / `TABLE` field |
| `ZRAK_CJ_LAY` | per-element layout overlay, edited in the Studio's Design tab |

Always `zcl_rak_cj_cfg_cache=>invalidate( iv_journey = ... )` after a change, or
it looks like nothing happened. A versioned per-work-process cache means another
work process keeps serving the old config otherwise.

## Field columns worth knowing

| Column | Notes |
|---|---|
| `FTYPE` | the control. 27+ types |
| `ZLABEL` / `ZLABEL_AR` | `CHAR(150)` each. **Longer text is cut on INSERT** — see below |
| `ZSECTION` | `CHAR(60)`, panel heading. Setting this AND `ZLABEL` to one string prints it twice. **No `_AR` twin** — section headings are English on every journey |
| `FGROUP` | `'ROW:<token>'` puts fields side by side; a bare value is an FGROUP heading |
| `SEQNR` | order. Unique per step, or the order is whatever the database returns |
| `DEFAULT_VAL` | `CHAR(1000)`. Default value — **or** the grid column spec — **or** the pick target on `TABLE` — **or** long field text behind a `TEXT:` prefix |
| `TECH_NAME` | posts to the backend. Missing = renders and posts nothing. Grids use `[]` |
| `HIDDEN` / `READONLY` | rules and `set_hidden( )` / `set_readonly( )` outrank these |
| `REQUIRED` + `MSG` | the FIELD flag; does **not** reach grid rows. The grid COLUMN flag is separate and *is* enforced — see Grid columns |
| `ATTACH_*` | uploads. `ATTACH_LABEL` doubles as the grid Add-row caption |
| `MIN_LEN` / `MAX_LEN` / `REGEX` / `MIN_VAL` / `MAX_VAL` | validation, with `MSG` (`CHAR(255)`) |
| `ROLLNAME` / `DOMNAME` / `SHLP` | the three config-driven F4 sources |

## Long text: the 150-character ceiling

`ZLABEL` is `CHAR(150)` and the cut happens **on INSERT**, in the database. The
rest of the sentence is not hidden by the renderer — it is gone, and no rendering
change can recover it. A consent declaration cut at exactly 150 characters is the
signature; `ZCL_RAK_CJS_XCHECK` rule **X13** reports any label sitting on the
limit, Error on a `CHECKBOX` and Warning elsewhere.

Two places long text can live instead:

- **`DEFAULT_VAL` behind a `TEXT:` prefix** — `CHAR(1000)`, read by
  `ZCL_RAK_JOURNEY_RENDER->LONG_TEXT( )`. `TEXT:@nnn` resolves `ZRAK_T_CJ_TXT`
  by `sy-langu` and is the form to use when the text must be bilingual, because
  `DEFAULT_VAL` has no `_AR` twin and a literal paragraph shows its English to
  an Arabic reader.
- **`ZCL_RAK_TEXT=>LONG_TEXTS( )`** — keyed by journey and field, English and
  Arabic as string literals in git, no length ceiling. Preferred for legal
  wording: a declaration a citizen agrees to belongs where a diff shows it
  changing, not in a table nobody reviews.

**A `TEXT:` default is never seeded as the field's value.** Without that guard a
consent checkbox renders pre-ticked and passes its own required check — the
citizen consents by loading the page.

## Rules

Operators: `EQ` `NE` `INITIAL` `NOTINITIAL`.
Actions: `SHOW` `HIDE` `REQUIRE` `OPTIONAL` `SET` `CLEAR`.

**Author both directions.** `SHOW` alone leaves a panel on screen after its
trigger is cleared, still holding values, still posting them. The `HIDE` half is
usually the half that matters.

Rules fire across steps. Several `REQUIRE`s on one target accumulate.

**A CHECKGROUP cannot drive rules.** It stores a comma list and no operator asks
whether a list contains a value. Use separate `CHECKBOX` fields — five checkboxes
and ten rules beat one group plus a handler written to work around the config.

**Two independent booleans must be two fields.** One `required` CHECKGROUP is
satisfied by ticking *either* option, which is how a citizen donates their way
past terms they never accepted.

## Grid columns

`ZRAK_T_JNY_COL`, read by `ZCL_RAK_JOURNEY_GRID->GRID_COLS( )` in preference to
the pipe-separated spec on the field itself.

| Column | Status |
|---|---|
| `REQUIRED` | **Enforced.** `MISSING_REQUIRED( )` checks it against every row that ALREADY EXISTS — not against the row count, so an empty grid still passes. It makes a started row complete; it does not make the grid mandatory |
| `WIDTH` | applied |
| `PINNED` | **inert.** `sap.m.Table` has no frozen-column feature; nothing reads the value |
| `DECIMALS` | **inert.** Carried into the gcol structure and never read back to format a cell |

The Studio's Columns panel labels the two inert ones so an author is not left
guessing. Do not add a caveat to a label without checking it is still true — one
said "not enforced yet" long after `REQUIRED` was wired up, which is the more
damaging direction for a caveat to be wrong in.

## Steps

`COLUMNS` does two jobs: it arranges FGROUP headings, and it lays out consecutive
`UPLOAD` fields that many per row. Blank or 1 keeps uploads stacked.

`NEXT_REQ` names a field that must hold a value before the footer moves on. No
longer needed for payment — a `PAYFEE` control is its own gate.

## Layout overlay

`ZRAK_CJ_LAY` holds row, column and span on the twelve-column grid, per element,
edited in the Studio's Design tab. Two flags read alike and are not:

- **`INLINE`** decides which **row** a cell lands on.
- **`FLOW`** decides the direction **inside** one cell. A cell is a `vbox`, so a
  button a handler adds through `AFTER_FIELD( )` always stacks under its field;
  `FLOW` puts it beside instead.

`PERSIST( )` does a full `MODIFY`, so anything writing one attribute must
`RESOLVE( )` the row first and overwrite only its own fields — otherwise it
blanks every other attribute on that element.

## Draft and attachment ownership

`DRAFT_MODE` and `ATTACH_MODE` on `ZRAK_T_JNY` answer `DELEGATE` / `NATIVE` /
`OFF`; blank lets the engine derive one.

The derivation is the rule worth knowing: **a backend that creates and re-opens
the case IS the draft**, so CJS delegates and keeps no second copy. Attachments
derive from `capabilities( )-attachments` instead, *not* from whether a case
exists — a backend can own the case and still have nowhere to put a file.

There is **no native draft store yet**, so a derived `DRAFT_MODE` with no backend
is `OFF` rather than `NATIVE`.

## Seed reports

See `seed-reports.md` — structure, idempotency, generated ids, and migrating
from a /QNV export.
