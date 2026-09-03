# Config tables

Seven tables. A journey is rows, not code.

| Table | Holds |
|---|---|
| `ZRAK_T_JNY` | journey header: title, theme, layout, handler class, backend, draft/attachment ownership |
| `ZRAK_T_JNY_STEP` | steps: `STEP_ID`, `SEQNR`, title, icon, `COLUMNS`, `BKND_SCREEN`, `NEXT_REQUIRES`, `NO_FORWARD` |
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
| `ROLLNAME` / `DOMNAME` / `SHLP` | three of the **four** F4 sources — see below |
| `CLOSED_LIST` | `'X'` on an `FTYPE 'SELECT'` renders `sap.m.Select` instead of the typable `sap.m.ComboBox`. Blank keeps type-ahead, so no existing dropdown changes |

**Get the column names from the DDIC, not from this table.** `NEXT_REQUIRES` was
written here as `NEXT_REQ` for a while and a feeder using that name simply does
not compile. One `grep -oE "<FIELDNAME>[A-Z0-9_]+"` over `src/zrak_t_jny*.tabl.xml`
settles all seven tables in a second.

**And the runtime component is `default`, not `default_val`.** The DDIC column is
`DEFAULT_VAL`; `ZIF_RAK_JOURNEY=>TY_FIELD`, which is what engine code reads at
runtime, calls it `default`. Reading `ls_field-default_val` in a hook does not
compile.

## The three payment carriers

`PAY_SCREEN`, `PAY_JOURNEY` and `PAY_CATEGORY` are ordinary hidden readonly
fields on the payment step whose `DEFAULT_VAL` carries a value.
`PREPARE_PAYMENT( )` overlays all three onto the config it hands the bridge, so
between them they decide which service the gateway read goes to.

**They are for a payment screen that sits under a DIFFERENT service, and most
journeys should leave all three blank.** Blank means "use the journey's own", and
that is right wherever payment is a step of the journey — DOK and EPDA.

**Setting `PAY_JOURNEY` changes the BAdI filter, which is almost never what you
want.** It becomes `CS_HEADER-PARAM2`, and `ZFM_EGA_CJ_FW_READ_N` does
`journeytype = cs_header-param2` then `GET BADI cj_badi FILTERS journey_type =
journeytype`. Set it to a journey with no implementation and the read comes back
with the screen's definition keys and every value empty — the screen existed, the
BAdI behind it did not. On Municipality the fee list and the gateway are two
screens of the **same** journey, so only `PAY_SCREEN` moves and the other two
stay unset. See `seed-reports.md` for which screen.

**A carrier's `DEFAULT_VAL` must win over the value in the draft, and "fill when
blank" is not enough.** `PAY_SCREEN` is a model value: it lives in the draft and
survives every round trip, so a journey that has already run with one value never
picks up a corrected `DEFAULT_VAL` — the old value is not blank, so nothing
overwrites it. `ZCL_RAK_JOURNEY_LOGIC` re-seeds it from config on every pay
event for exactly that reason. The general rule: **for a field that is static
configuration rather than something a citizen types or a backend returns, config
is authoritative and the model copy is only a carrier.**

## Field names have a hard ceiling of 23, not 30

`BUILD_MODEL( )` calls `CL_ABAP_STRUCTDESCR=>CREATE( )` per field, and a model
component is capped at 30 — but the model also builds `_VS`, `_VST`, `_IDTYPE`,
`_NAME`, `_IX` and `_EXP` companions on the same name. So **23 is the real limit**,
and `CX_SY_STRUCT_COMP_NAME` is uncaught: an over-long name kills the whole app
with UNCAUGHT EXCEPTION rather than hiding one field. Any runtime-derived name
goes through `ZCL_RAK_JOURNEY_UTIL=>COMP_NAME( )`, never plain `to_upper( )`.

## The fourth option source: an `API:` directive

`DEFAULT_VAL` can carry `API:<api>:<entityset>[:<domain>[:<filter>]]`, read by
`ZCL_RAK_CJ_OPTS=>RESOLVE( )` **ahead of the DDIC resolver** — an API-bound field
must never fall through to a domain that happens to share its name, because a
wrong list is harder to notice than no list.

```
API:PROPERTY:PropertiesSet::Type=Parcel
```

The empty domain slot before the filter is required. Only `PROPERTY` and
`MAPLET` have resolver branches today; `TENANCY`, `SIGN`, `VALUEHELP` and `FND`
are named in the migrator's bind table and **their wrapper classes do not
exist** — so a field bound to one of those gets no options and no error.

## The parcel / property composites

| FTYPE | Draws |
|---|---|
| `PARCEL` | the live card list, single-select, one Select button per card |
| `PARCELS` | the same list **multi-select**, a checkbox per card, storing a `-` separated list |
| `PROPERTY` / `TITLEDEED` | as `PARCEL`, different `Type` filter |
| `REVIEW` | the engine's own review renderer — one field, nothing to configure, nothing to post |

`PARCELS` stores its list `-` separated because the backend already does:
`ZIF_EGA_FW_CJI~UPDATE( )` builds the CJ02 note as
`parcel && '-' && ui_table_column1` and splits it back the same way.

All of them need the `API:` directive as well as the FTYPE. Without it the field
renders as an empty ComboBox and says nothing.

## Hidden fields are not validated

`ZCL_RAK_JOURNEY_RULES->VALIDATE_STEP( )` skips them outright:

```abap
IF is_hidden( ls_f ) = abap_true. CONTINUE. ENDIF.
```

So **`REQUIRED` + hidden is safe**, which is what makes a backend-driven
conditional document work: the field is authored required because it *is*
mandatory when shown, and a citizen who never sees it is not blocked. Check this
before relying on it in any release — the alternative failure is a step nobody
can leave.

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

### `EDITABLE_TABLE` or the handler cannot touch it

`GET_GRID_DATA( )` and `SET_GRID_DATA( )` work **only** on an `EDITABLE_TABLE`.
With `FTYPE 'TABLE'` the engine warns and both calls are no-ops:

```
Grid RAKPARCELS: FTYPE is TABLE, not EDITABLE_TABLE.
Only an editable grid has rows to read or write.
```

**And field-level `READONLY` does the same thing.** It takes the rows away from
the handler as well as from the keyboard. If the intent is "the handler writes
the rows, the citizen does not type in them" — which is the normal shape for a
grid the backend fills — then:

- `FTYPE = 'EDITABLE_TABLE'`, field `READONLY` **blank**
- `ZRAK_T_JNY_COL-READONLY = 'X'` on **every** column

That leaves the grid editable enough for `SET_GRID_DATA( )` and for the per-row
delete button, with no cell typable.

Do not put `REQUIRED` on a column the backend fills. It is enforced against every
row that already exists, so it refuses the row the moment the handler adds it and
before the read can fill the rest.

### Rows are positional at both ends

`SET_GRID_DATA( )` matches `is_data-columns` **by name**, so handing back exactly
what `GET_GRID_DATA( )` returned is an identity map and cannot shift a value into
the neighbouring column. Building a fresh column list is how a cell ends up one
place to the left.

A row shorter than the column list has undefined later cells, not blank ones —
pad it.

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
