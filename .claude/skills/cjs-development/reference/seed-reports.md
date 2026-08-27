# Seed and feeder reports

A journey is rows. A seed report writes them, and a feeder report writes them
from a legacy `/QNV/SB_UI_DEFIN` export.

## Shape

```abap
REPORT z..._load.
CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'Z...'.
TYPES tt_fld TYPE STANDARD TABLE OF zrak_t_jny_fld WITH EMPTY KEY.   " and step/opt/rule
START-OF-SELECTION.
  DELETE FROM ... x5          " everything it owns
  INSERT header / steps / fields / options / rules
  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).
  WRITE the walkthrough and the REVIEW lists
```

**Idempotent or it is not a seed.** Delete all five tables first; a report that
can only be run once is a report nobody dares re-run.

**Invalidate, always.** A versioned per-work-process cache means another work
process keeps serving the old config, and the change looks like it did not take.

**`WRITE` a walkthrough.** The report is the only documentation the next person
gets. Say what to click and what should happen.

## Generated ids will truncate, and it dumps at the INSERT

**Every id column in this framework is short.** `RULE_ID` is CHAR3 — every id in
the codebase is three characters, `R10`, `F01`, `B14`.

Generating thirty rules as `GS01..GS15` / `GH01..GH15` gives `GS0`, `GS1`, `GH0`,
`GH1` — 40 rows collapse to 14 and the INSERT short-dumps on a duplicate key,
pointing at the statement rather than at the naming.

```abap
DATA lv_n TYPE n LENGTH 2.       " NUMC, not WIDTH = 2 PAD = '0'
lv_n = sy-tabix.
rule_id = |G{ lv_n }|.           " G01..G15, three characters
```

`NUMC` rather than a template's `WIDTH`/`PAD` because a numeric template's
alignment default is not worth anyone's afternoon; NUMC is leading-zero by
definition.

**Check the DDIC length before generating any id in a loop.** Truncation-to-
duplicate only appears when rows are generated rather than typed.

## Text columns truncate too, and that one is silent

`ZLABEL` is `CHAR(150)`. A seed that inserts a longer label does not fail — the
row goes in with the tail removed, and nothing anywhere reports it. A consent
declaration is the usual casualty, and the original wording is then gone from the
database entirely; it has to be re-supplied from somewhere, not recovered.

Put long text in `DEFAULT_VAL` behind a `TEXT:` prefix, or in
`ZCL_RAK_TEXT=>LONG_TEXTS( )` when it must be bilingual. See `config-tables.md`.

## Generate the repetitive rows

Fifteen checkboxes needing show *and* hide is thirty near-identical rows. Typed
out, exactly one of them gets a copy-paste slip, and that one shows a grade to
non-teaching staff. Put the field names in a `string_table` and loop.

## Bilingual is not uniform

`ZLABEL_AR`, `MSG_AR`, `PLACEHOLDER_AR`, `TITLE_AR`, `SUBTITLE_AR`,
`OPT_TEXT_AR` all exist. **`ZSECTION_AR` does not**, and neither does a
`DEFAULT_VAL_AR`. Section headings are English only, on every journey in the
framework — a DDIC gap, not something a seed can work around. Assume nothing
about which columns have a twin.

## Never half-comment a block

Switching off a block by prefixing some of its lines leaves the rest as a
statement with no beginning:

```abap
*  MODIFY zega_t_cj_grp FROM @( VALUE #(
    mandt = sy-mandt groupid = "c_grp departmentid = c_dept
    seqnr = '901' active = 'X' ) ).        " <-- orphan, four cascading errors
```

The compiler reports the surviving half — *"Unable to interpret VALUE"* — and
not the missing one. **Delete the block.** Git has it.

Same hazard wearing a different hat: a commented-out `INSERT` above a live
`DELETE`. That report removes rows on every run and puts none back.

## Feeder reports: migrating from a /QNV export

The export is the source of truth. `FIELD_NAME`, `CONTROL_TYPE`, `MANDATORY`,
`SH_NAME`, `TECHNICAL_NAME`, `DATA*` and `LIST_SEQUENCE` all copy across;
captions resolve from `LABEL_CON` or `VALUE` through the label dictionary.

**Read it before writing anything.** A field list inferred from a screenshot is
a guess with a compile error at the end of it.

Things the export says that are easy to miss:

| Seen in the export | What it means |
|---|---|
| `LEVEL_CON = T` | a grid COLUMN, not a field |
| `DATA8` blank on a grid | rows post, are accepted, and are **dropped silently** by the mapper |
| `DATA2` ≠ `FIELD_NAME` | correct — the bridge asks by `DATA2` — but it reads as a typo |
| `UI_FIELD_LOGICS` | the legacy rules. `X-V-T` / `-V-F` = show/hide a CONTAINER, so a CJS rule targets its children |
| `SH_NAME` | goes in `SHLP`. In `ROLLNAME` it resolves to nothing and the dropdown is empty, silently |
| `EXTENDED = X` | a composite control drawn by JavaScript. The export describes none of its inner fields |
| `CONTROL_TYPE = TBUTTON` sharing one `DATA1` | one segmented field, not two checkboxes |
| `MANDATORY` on the LABEL but not the control | the asterisk is decorative; the control is not enforced |

**When screens disagree, say so.** `CLASS_NAME` and `JOURNEYTYPE` vary across
screens of one legacy journey. A CJS journey has one `BKND_JOURNEY`, so merging
forces a decision that belongs to the owning team — write it up, don't pick.

**Run `ZCL_RAK_CJS_XCHECK` after a feeder.** It compares the seeded journey
against the ShapeIt rows it claims to drive, and a step whose `BKND_SCREEN` has
no legacy configuration renders, validates, posts — and creates nothing.

## Say what needs a human

End the report with `WRITE` blocks the developer will actually read:

- **REVIEW-BE** — backend behaviour the migration changes or cannot carry
- **REVIEW-GRID** — `DATA8`, `DATA2` mismatches, anything silent
- **REVIEW-F4** — every search help. One backed only by a search-help EXIT tests
  green in SE11 and returns zero options at runtime; nothing in the export says
  which kind it is
- **REVIEW-TECH** — every field without a `TECH_NAME`, and why each one is
  deliberate. Without the list, nobody can tell an omission from a decision
- **REVIEW-TEXT** — every label at or near 150 characters. Truncation is silent
  and the original is unrecoverable once the row is written
- **NOT MIGRATED** — chrome, stage bars, feedback widgets the framework draws
  itself. A reader who cannot see what was dropped assumes it was missed

## Never seed a live credential or a test identity

`ZRAK_NOT_LOAD` seeds `P1_IDNUM` / `P2_IDNUM` with a real Emirates ID so the
partner search can be pressed without typing. Convenient in dev, and it ships
unless somebody remembers. Anything of that kind belongs behind a `sy-sysid`
guard or in a separate report that is never transported.
