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
`OPT_TEXT_AR` all exist, and **`ZSECTION_AR` now does too** - it was added to
`ZRAK_T_JNY_FLD` and is wired through the repo, the renderer and the Studio field
editor, but it is in git only: it needs activation and a table adjust before a
seeded value is true in SAP, and a plain SM30 screen will not show it until that
screen is regenerated. **`DEFAULT_VAL_AR` does not exist** - a literal paragraph in
`DEFAULT_VAL` shows its English to an Arabic reader, which is what `TEXT:@nnn` and
`OTR:` are for. Assume nothing about which columns have a twin.


## Migrated wording is read, never typed — and never hand-translated

A migrated screen's words already exist, in both languages, in the legacy text
tables. The export carries the keys:

| Table | Key | Text | Keyed from |
| --- | --- | --- | --- |
| `/QNV/SB_LABELT` | `label_code` | `labeltext`, one row per `spras` | `LABEL_CON` |
| `/QNV/SB_VALUET` | `value_code` | `value_desc`, per `spras` | option / value codes |

`ZCL_RAK_MIGRATOR->LOAD_TEXT_CACHES( )` reads both into `MT_LBL` / `MT_VAL` and
`PROJECT_ROWS( )` resolves `LABEL_CON` through them, so a migration driven
through the migrator gets the department's own wording automatically.

**A hand-written feeder gets none of that and has to do the lookup itself.**
Mirror the shape the feeders already use for the Arabic title:

```abap
* Bilingual label from the legacy text table, by the export's LABEL_CON code.
* Blank falls back to the literal - a missing row must not blank a label.
  SELECT spras, labeltext FROM /qnv/sb_labelt
    WHERE label_code = @lv_code AND ( spras = @sy-langu OR spras = 'A' )
    INTO TABLE @DATA(lt_lbl).
```

then take `sy-langu` into `ZLABEL` and `'A'` into `ZLABEL_AR`, and the same for
`ZSECTION`, `MSG`, `PLACEHOLDER` and `OPT_TEXT`.

**Why this is not cosmetic.** Typing an English label off a spec `.docx` and
translating the Arabic yourself replaces wording the department owns with a
guess. It will differ from the live screen the citizen already uses; the
difference is in a language most reviewers of this repo cannot check; and
nothing — not `ZCL_RAK_CJS_XCHECK`, not activation, not a preview — reports it.
A wrong field name eventually shows up as a defect. Wrong wording just quietly
ships.

It also gives up the maintainable forms. `OTR:<alias>` and `@nnn`
(`ZRAK_T_CJ_TXT`) are both re-resolved by
`ZCL_RAK_JOURNEY_REPO->PICK( )` on **every** round trip, so wording can change
with no reseed and no redeploy. Prefer one of those over a literal wherever the
text is likely to be revised.

Applies to every migration, whether or not anyone asks about translations.
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

### Check it mechanically, and not with a paren count

`reference/check_value_rows.awk` finds an assignment that landed OUTSIDE
its row - the shape that reports **`Field "DEFAULT_VAL" is unknown`**:

```bash
awk -f .claude/skills/cjs-development/reference/check_value_rows.awk src/zrak_*_load.prog.abap
```

**A paren count will not catch this.** Nothing is added or removed when a
line lands in the wrong place, so the balance stays even - seven misplaced
`DTYPE:` defaults passed a 122/122 paren check and still would not compile.
The script tracks depth instead: `FROM TABLE @( VALUE #(` puts the table at
depth 2 and each row at 3, so an assignment seen at depth 2 on a line that
does not itself open a row is outside every row. Depth also matters because
"ends with `)`" is not the test - a nested call like
`lcl_txt=>en( iv_code = ... )` closes a paren of its own, and a naive check
reports every following assignment as orphaned.
## Add rows with a standalone INSERT, not by editing inside a `VALUE #( )`

A feeder is one long `VALUE #( ( … ) ( … ) )` per table, and splicing a row into
the middle of one **by line number** is how two unrelated config rows in
`ZRAK_M016_LOAD` got silently overwritten — a `msg_ar` and the opening
`( mandt = … seqnr = 60` of a different field. The paren count caught it
(`65/66`); nothing else would have.

Two habits that avoid it:

- **Match on text, never on a line number.** The same block sits at different
  lines in each feeder, so a number that is right for M011 lands mid-row in M016.
- **Prefer a separate `INSERT … FROM TABLE @( VALUE #( … ) )` statement** before
  the final `COMMIT`. Order between statements does not matter, and a new
  statement cannot damage an existing one. That is how the parcel grid was added
  to M011 and M016.

And check `grep -c '('` against `grep -c ')'` on the file afterwards. An
unbalanced feeder is a syntax error whose message points at the `VALUE`
operator, not at the row you broke.

## Feeder reports: migrating from a /QNV export

The export is the source of truth. `FIELD_NAME`, `CONTROL_TYPE`, `MANDATORY`,
`SH_NAME`, `TECHNICAL_NAME`, `DATA*` and `LIST_SEQUENCE` all copy across;
captions resolve from `LABEL_CON` or `VALUE` through the label dictionary.

**Read it before writing anything.** A field list inferred from a screenshot is
a guess with a compile error at the end of it.

### The CJS `FIELD_NAME` must BE the legacy `FIELD_NAME`

This is the single most expensive thing to get wrong, because nothing reports it.

Backend field control only reaches a CJS field whose `FIELD_NAME` equals the
legacy one. The whole chain is keyed on it:

| Step | Keyed on |
|---|---|
| `ZCL_RAK_QNV_BRIDGE->SEED_CTRL( )` | `READ TABLE ls_s-fields WITH KEY name = to_upper( iv_field )`, where `iv_field` is the **definition row's** `FIELDNAME` |
| `ZCL_RAK_QNV_BRIDGE->CTRL_OF( )` | `is_def-fieldname`, the same legacy name |
| `ZCL_RAK_JOURNEY_BE->APPLY_CTRL( )` | calls `SET_HIDDEN` / `SET_READONLY` / `SET_REQUIRED` with that name — and on a name the journey does not have, that is **legal and does nothing** |

So a tidier name does not merely miss a nicety: `MANDATORY`, `ENABLED` and
`VISIBLE` from the live field-control engine all silently fail to apply, and it
looks exactly like a backend that never sent them.

```
PARCELSEL      ->  PARCELSELECTOR        DOC_TITLEDEED ->  NOCCONT
PLOTLONGTEXT   ->  ENTERTEXT             DOC_ID        ->  LETTERCONT
TOTALFEESVALUE ->  TOTALVALUE            ACCEPT_TERMS  ->  CHECKBOX_3
USAGETYPE      ->  RAKSELECTUSAGETYPE    DONATE        ->  CHECKBOX_4
```

`TECH_NAME` is a **different key** and keeps the technical name — `ENTERTEXT`'s
`TECH_NAME` is still `PLOTLONGTEXT`. Only the `FIELD_NAME` has to match.

Verify mechanically: every seeded `FIELD_NAME` should appear in the export for
that screen, and the exceptions should be a short list of CJS-only controls
(`PAYFEE`, `REVIEW`, guidance paragraphs) that you can name.

### A container-driven hide lands on the CONTAINER

When the BAdI hides by `CONTROLGROUP`, it clears `ISVISIBLE` on the row carrying
that group — which is a `VBOX`, not the control inside it:

```abap
READ TABLE ct_definition ASSIGNING <fs_defn> WITH KEY controlgroup = 'NOC'.
IF sy-subrc EQ 0. CLEAR <fs_defn>-isvisible. ENDIF.
```

CJS has no containers, so **name the CJS field after the container** and let the
group collapse to its one real control. A field called `UPLOADER1` would never
hear the hide; one called `NOCCONT` does, through the ordinary mechanism, with
nothing duplicated and no second opinion about when to show it.

Things the export says that are easy to miss:

| Seen in the export | What it means |
|---|---|
| `LEVEL_CON = T` | a grid COLUMN, not a field |
| `DATA8` blank on a grid | rows post, are accepted, and are **dropped silently** by the mapper |
| `DATA2` ≠ `FIELD_NAME` | correct — the bridge asks by `DATA2` — but it reads as a typo |
| `UI_FIELD_LOGICS` | the legacy rules. `X-V-T` / `-V-F` = show/hide a CONTAINER, so a CJS rule targets its children |
| `SH_NAME` | goes in `SHLP`. In `ROLLNAME` it resolves to nothing and the dropdown is empty, silently |
| `EXTENDED = X` | a composite control drawn by JavaScript. The export describes none of its inner fields — **and none of its value help either**; see below |
| `CONTROL_TYPE = TBUTTON` sharing one `DATA1` | one segmented field, not two checkboxes |
| `MANDATORY` on the LABEL but not the control | the asterisk is decorative; the control is not enforced |

### An EXTENDED control's value help is in SE11, not in the export

For `EXTENDED = X` the export tells you the control **exists** and nothing
else. `SH_NAME`, `DATA1..DATA10` and `TECHNICAL_NAME` are all typically blank,
because the list is not wired on the screen at all — the ShapeIt control reaches
it through the OData service, and the help itself lives on the DDIC side.

So "nothing in the export names the list" is a true statement about the export
and a wrong conclusion about the field. **Look in SE11** for a `ZSH_CJ_*` help
against the entity the control edits.

M016's usage type is the worked example: the export row for
`RAKSELECTUSAGETYPE` carries nothing, and the list is `ZSH_CJ_PROPERTY_USAGE` —
selection method `TIVBDCHARACT`, text table `TIVBDCHARACTT`, import parameter
`FIXFITCHARACT` defaulted to `'L3*'`, no search-help exit.

Bind it with **`SHLP`**. `ZCL_RAK_F4_RESOLVER->FROM_SHLP( )` reads a help with
`F4IF_GET_SHLP_DESCR` then `F4IF_SELECT_VALUES`, so one with a real selection
method and text table is readable. Two things decide whether it works:

- **a help whose values come only from a search-help EXIT** tests green in SE11
  and returns nothing at runtime — check that the exit is blank;
- **a defaulted import parameter may or may not be honoured.** Whether
  `F4IF_GET_SHLP_DESCR` pre-fills `SHLP-SELOPT` from a parameter default, or the
  default is only applied by the interactive F4 dialog, is not established. The
  resolver already gates on both failure shapes under `&trace=X` — `resolved 0
  option(s)` means the mandatory parameter left the selection empty, and
  `resolved 200 option(s)` is the cap, meaning the filter was not applied and the
  whole table came back. Anything between the two is the real list.

Never invent the list instead. A wrong list is harder to notice than no list,
and it posts values the backend has never heard of.

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

## Municipality (MML / DML / GRANTS / TEN) journeys

The six Manage-My-Land journeys — M011 Divide, M012 Merge, M016 Change Building
Regulations, and M013/M014/M015 — all run through **one** BAdI abstract,
`ZCL_EGA_CJ_FW_RO_ABS_V1`. Read that class before writing a Municipality feeder;
almost everything below is in it.

Reference feeders: `ZRAK_M011_LOAD` (the family reference), `ZRAK_M012_LOAD`,
`ZRAK_M016_LOAD`. Handlers: `ZCL_RAK_MUN_LOGIC` (shared) plus one thin subclass
per journey.

### Screen naming and scope

An M-code is **not** a screen name. Municipality screens are named by mnemonic —
`NSUBDIVISION`, `NMERGE`, `NCBR`, `NOG`, `NNTC` — and the M-code appears only as
the `VALUE` of each screen's `JOURNEYTYPE` row. Each service exists three times:
`<FAM>_n` desktop, `M<FAM>_n` mobile, `N<FAM>_n` current. **Migrate the `N` one.**

**Stage 1 and stage 2 are SEPARATE SERVICES, not two halves of one wizard.**
`NSUBDIVISION_1_*` is apply-and-pay-initial-fee; `NSUBDIVISION_2_*` is the later
stage. Deriving both into one journey gives the citizen a wizard that stops for
weeks in the middle. One feeder per stage.

### Structure: three steps, and NO review step

```
STP1  N<FAM>_1_1  Parcel Selection
STP2  N<FAM>_1_2  Documents
STP3  N<FAM>_1_3  Fees & Payment
```

`N<FAM>_1_4` is the confirmation page and is **framework chrome** — the engine
draws the result card from `MV_SUBMITTED` and the happiness meter from
`WANTS_FEEDBACK`. Do not seed it.

**Do not insert a Review step.** The migrator does, and it is wrong here: the
legacy service has no review screen, and on screen it reads as a step standing
between the citizen and paying.

### The four things the migrator omits

1. **`BKND_ACTIVE` / `BKND_FM_POST` / `BKND_FM_READ`.** Without them a journey
   renders, validates, collects every answer and **posts nothing**. Category
   `MML`, `BKND_JOURNEY` the M-code, both FMs `ZFM_EGA_CJ_FW_POST_N` /
   `..._READ_N`.
2. **`TITLE_AR`.** Read it — `SELECT SINGLE description FROM zega_t_cj_idt WHERE
   journeyid = @c_jny AND spras = 'A'`. That is the row the legacy service renders
   its own name from. `SPRAS 'A'`, not `'AR'`. Every earlier loader left it blank
   "because the authoritative text is `ZEGA_T_CJ_IDT`" and then left it blank.
3. **`PAYFEE`.** The migrator drops `RAKPAY` and counts it, so twelve migrated M
   journeys have no pay control at all.
4. **`DRAFT_MODE` blank.** The RE rental object created on
   `ZIF_EGA_FW_CJI~CREATE` **is** the draft, so the engine's derivation
   (`DELEGATE`) is correct. Forcing `NATIVE` errors — there is no CJS draft store.

### What the backend owns — do not re-implement it

`ZCL_EGA_CJ_FW_RO_ABS_V1->VALIDATE( )` enforces, on every post:

| `ZMSG_EGA_CJ` | Rule |
|---|---|
| 004 | one location hierarchy across all selected parcels |
| 005 | no parcel already inside an open ZGCX container |
| 006 | every parcel has a `TR0800` owner role |
| 007 | no `YTR080` grant role |
| 011 | at least one parcel actually owned by the applicant |
| 012 | no duplicate parcels |
| 013 | nothing under construction (building status 03) |
| 031 | parcel not in status E0012/E0013/E0014/E0017 |
| — | `ZCM_CASE_PARCEL_CHARACT_PERMIT` per parcel, per case type |

Every one needs `VILMPL`, `VIBPOBJREL`, `VIBDAO`, `JEST` or a function module. A
CJS copy forks nine domain rules and **the copy is the one that goes stale**,
because the legacy path stays live for the ShapeIt screens. Messages come back on
the post through `ET_MSG` (bridge → `ZCL_RAK_JOURNEY_BE`) and surface as engine
messages.

Only add a CJS-side check that needs **no table read** — M012's "a merge needs
two parcels" is the family's one example, and it earns it by not re-deciding
anything the backend decides.

`FIELD_CONTROL( )` owns two conditional documents, read from
`ZCL_EGA_MUN_CJ_ODATA_API`:

| Group | Hidden unless |
|---|---|
| `NOC` (→ CJS field `NOCCONT`) | the parcel `is_mortgaged` |
| `LETTER` (→ CJS field `LETTERCONT`) | it has **more than one** `TR0800` owner |

Both are `MANDATORY = X` in the export, and required-when-shown is correct
because validation skips hidden fields.

### Characteristics and where values land

| Char | Holds |
|---|---|
| `CJ02` | the parcel, or the `-` separated parcel list, also written to the RE note `<intreno>#CJ02#00000000` |
| `CJ03` | owner BP (`TR0800`) |
| `CJ04` | applicant BP (`TR0640`) |
| `CJ10` | the tasheel transaction id, when a property agent launched it |
| `CJ11` | the citizen's description — `TECH_NAME 'PLOTLONGTEXT'`, also an RE note |
| `CJ12` | the ZGCX container case id |

The journey object is an RE rental object: company `2000`, business entity
`CJMUN`, usage type `3000`, RO type `RU`, `PROPERTY` carrying the M-code.

### The payment deviation from EPDA — read this before touching the fee step

**The case is created when the FEES STEP POSTS, not on submit.**
`ZIF_EGA_FW_CJI~UPDATE( )`:

```abap
READ TABLE ct_item_data ... WITH KEY technicalname = 'TOTALFEESVALUE'.
IF sy-subrc = 0 AND line_exists( mt_ui_map[ objectkey = 'FEES_1' ] ).
  payment_check( ) ... IF caseid IS INITIAL. create_dummy_case( ).
```

Two consequences a feeder must respect:

- **`TOTALVALUE` must carry `TECH_NAME 'TOTALFEESVALUE'` and reach the post.**
  Without it the backend creates nothing and the citizen pays against no open
  item. Seed it hidden and readonly rather than leaving it to the card.
- **`ZEGA_T_CJ_UI_MAP` needs a `FEES_1` row for that screen** — legacy config, not
  CJS. No row, no case, ever.

### `ZEGA_T_CJ_UI_MAP` is the backend's switchboard — read it before guessing

`ZCL_EGA_CJ_FW_RO_ABS_V1->MAPPER( )` fills `MT_UI_MAP` from it, keyed on
**journey + rwmode + screen** (`1` read, `2` post), and every optional block in
`READ( )` and `UPDATE( )` is gated on an `OBJECTKEY` row being present:

| objectkey | gates |
|---|---|
| `ATTACHMENT` | `get_attachment( )` |
| `PLDTL` / `BPDTL` | `get_parcels( )` |
| `INITIAL` / `FINAL` | `get_fees( )` — the fee lines **and** `TOTALFEESVALUE` |
| `CPG_1` / `CPG_2` | the gateway block — `MERCHANTID`, `REFERENCEID`, `REDIRECTURL` |
| `FEES_1` | `payment_check( )` + `create_dummy_case( )` |
| `FEES_2` | the final deposit amount |

**No row means the block silently does not run.** No exception, no message.

**And its screens do not line up with CJS's steps.** CJS collapses each service
into three steps and reads `*_1_1..*_1_3`, while the map puts the fee list and
the gateway on two different screens:

```
M011   INITIAL NSUBDIVISION_1_3    CPG_1 NSUBDIVISION_1_4
M012   INITIAL NMERGE_1_3          CPG_1 NMERGE_1_4
M016   INITIAL NCBR_1_3            CPG_1 NCBR_1_4
```

That is why the fee total displays and the case is created — both live on `_1_3`,
a screen CJS reads — while the gateway never resolves. **So `PAY_SCREEN` is the
`CPG_1` screen, and `PAY_JOURNEY` / `PAY_CATEGORY` stay blank** because it is the
same journey and category.

**Look it up per journey; never compute it.** The gap is not a fixed offset:
M017 is `_1_2`/`_1_3`, M018 `_1_5`/`_1_6`, M028 `_1_4`/`_1_6`, and M030 puts
`CPG_1` on `_1_11`. `MP00..MP04`, the standalone payment journeys, carry no CPG
row at all — so a payment screen is not found by looking for one of those.
`XCHECK` rule X16 cross-checks the map offline.

### The payment read is asked with the DRAFT key, not the case number

`VIBDRO` is keyed on the INTRENO, and the case is a characteristic **on** the
rental object:

```
MAPPER    ms_rero-intreno = ms_header_param-param1
          SELECT swenr, smenr FROM vibdro WHERE intreno = ms_rero-intreno
READ( )   BAPI_RE_RO_GET_DETAIL -> mt_char
CPG blk   caseid = mt_char[ fix_fit_charact = 'CJ12' ]-supplementinfo
```

Hand `param1` the case number and `VIBDRO` matches nothing, so `MS_RERO` stays
blank, `MT_CHAR` is empty, `caseid` never resolves and `GET_RB_CPG_DETAILS`
returns on its first line. The draft key finds the object; the object carries the
case. `PREPARE_PAYMENT( )` therefore sends `GET_CASE( )` first and `CASE_NUMBER`
only as a fallback — one rule for both families, since on DOK and EPDA the
backend re-points the key at the case and the two are the same value anyway.

### The post must send the partner, or the FM never reaches the BAdI

`ZFM_EGA_CJ_FW_POST_N` has an exit **earlier** than `GET BADI`:

```abap
IF loginbp IS INITIAL AND anonymous <> 'X'.
  RETURN.                       "Authentication not valid
ENDIF.
GET BADI cj_badi FILTERS journey_type = journeytype.
```

That returns with no draft, no messages and about a millisecond —
**indistinguishable from a filter matching nothing.** Three Municipality journeys
were diagnosed as unregistered BAdIs on that signature. It used to be covered by
a dev hardcode inside the FM (`IF loginbp IS INITIAL AND sy-sysid <> 'E30'`),
which is commented out; the partner now travels in the payload. If a create
returns nothing in ~1 ms, **check the partner before SE18.**

### Two hazards in the CPG block itself

- **Its `DO` loop is unbounded.** There is no exit when `DFKKOP` has no open item
  — it spins the work process, with a `WAIT UP TO 7 SECONDS` on the way through.
  `PREPARE_PAYMENT( )`'s `SELECT … FROM dfkkop` gate before the read is therefore
  a **safety requirement**, not an optimisation.
- **`APPLICATIONURL` is blank on the standard CPG route and always will be.**
  `ROUTE_GATEWAY( )` picks from `ZDT_PG_DEP_MAP`: an ATB department gets a
  ready-made URL, and everything else — `PW_RB1` set, `ATB_FLAG DISABLED`, which
  is what M011 returns — goes through the payments Web Dynpro, where no
  pre-built URL exists. Waiting for that one field discards a full payload. And
  a company code with **no** `ZDT_PG_DEP_MAP` row is routed nowhere at all: the
  read answers with `PW_RB1`/`ATB_FLAG` set and nothing else.

**The base handler already does the Pay press correctly** — `ON_POPUP_EVENT
( PAYNOW )` sets `PAY_STARTED`, sets `STATUS = 'PAYMENT'`, calls `COMMIT_STEP( )`
(the post on which the case is created) and returns without reaching the gateway
if that commit fails. Do not re-implement it; add only what it cannot know.

**`CHECKBOX_3` is a gate, not chrome.** Its `UI_FIELD_LOGICS` is `PAY-E` — it
*enables* the Pay button on the live screen. CJS cannot reproduce that from
config: the `PAYFEE` card is drawn whole by the base `RENDER_FIELD( )` with Pay
inside it, and `REQUIRED` only gates *leaving* the step — which on the last step
means submitting, not paying. So a citizen can complete a real payment and only
then be told they had to accept terms. Refuse the press in the handler instead.
Reordering the checkbox above `PAYFEE` also puts it above the fee table, so terms
get accepted before the amount is shown.

### The parcel details table — all three journeys, and no `TECH_NAME`

Give every MML journey the same `RAKPARCELS` grid, so they read the way the
legacy screens do. Seven columns in this order:

```
PARCELID | OWNSTATE | LOCATION | ADDRESS | OWNMETHOD | GRANTTYPE | ACTIONREQ
```

It needs **no UI-map row**. `ZIF_EGA_FW_CJI~READ( )` ends with an unconditional
fallback, unlike `GET_PARCELS( )` which is gated on `PLDTL`:

```abap
IF ct_table_data IS INITIAL.
  get_pl_table( CHANGING ct_table_data = ct_table_data ).
ENDIF.
```

`GET_PL_TABLE( )` reads the CJ02 note, splits on `-` and fills exactly those
seven columns — which is why the spec matches: it was written against that
method.

**Leave `TECH_NAME` blank on a display-only grid.** `FLATTEN_KV( )` skips an
`EDITABLE_TABLE` whose tech name is empty, so the grid draws and posts nothing.
M012 needs its rows to post — they *are* the merge list, and `UPDATE( )` builds
the CJ02 note from `CT_TABLE_DATA` — but on a single-select journey the parcel
comes from the selector, and giving the display table a tech name lets it
overwrite the note the selector wrote.

`EDITABLE_TABLE` with per-**column** `READONLY`, never field-level `READONLY`:
the field flag takes the rows away from the backend read as well as from the
citizen.

### The payment card is one field

`NSUBDIVISION_1_3` has 134 export rows and nearly all of them are inside the
card: `RB1..RB4` (method), `PW_RB1/PW_RB2` (channel), the `FEESLIST` CLIST and
its template, `REMAININGFEES`, `ATB_FLAG`, `TOTALVALUE`'s display. Seed `PAYFEE`,
`TOTALVALUE`, `CHECKBOX_3` and `CHECKBOX_4` and **nothing else** — re-creating
the rest draws the payment screen twice.

Fees come from `ZCL_EGA_MUN_CJ_FEES_<M0xx>->GET_INITIAL_FEE`.

### Attachments: send the document type

Legacy uploaders carry `DATA2 = 1/2/3`, which the BAdI files as
`ZDT_EGA_CJ_ATTR-DIFFCRT` via `CREATE_ATTACHMENT`'s `DOC_TYPE`. Carry it as
`DTYPE:n` in `DEFAULT_VAL`.

`CREATE_ATTACHMENT` only checks `OBJTRG` and `OBJSRC`, so a missing type passes
silently and the case cannot tell a title deed from an Emirates ID. And because
`GET_ATTACHMENT( )` de-duplicates on `( objsrc, diffcrt, objsrctype, objtrgtype )`,
**two files on one field come back as one** — so leave `ATTACH_MULTI` off, one
file per field, even with the type carried.

### The property-agent screens are not fields

A requirement document full of "Property Agent" screenshots is the family's
tasheel flow, already handled in `MAPPER( )`: a BP value longer than ten
characters is read as a transaction id, `ZEGA_T_CJ_BP_REL` resolves it to the
owner/applicant pair, and it lands on `CJ10`. No CJS field, no CJS code — the
launch parameter decides it.

### The parcel details dialog

Six of its seven tabs are one read, and it is **`GET_EXPANDED_ENTITY`, singular**:

```
PropertiesSet(Intreno='…',Partnerguid=guid'…')
  ?$expand=ToProject,ToPartner,ToMeasurement,ToLandUse,ToDevelopment,ToAttachment
```

A key in the path routes to the singular method; `EntitySet?$expand=` routes to
`GET_EXPANDED_ENTITYSET`. CJS already holds both key parts — `Intreno` from the
parcel row, `Partnerguid` from `MS_CTX`. Only the **plural** method is known to
dereference `IO_EXPAND->GET_CHILDREN( )` unguarded, so the tabs may be one call
away. Run `ZRAK_CJ_EXPAND_DIAG` before writing anything against it.

`FloorSet` genuinely is behind the plural method (`iv_entity_name = gc_floor`).

## Never seed a live credential or a test identity

`ZRAK_NOT_LOAD` seeds `P1_IDNUM` / `P2_IDNUM` with a real Emirates ID so the
partner search can be pressed without typing. Convenient in dev, and it ships
unless somebody remembers. Anything of that kind belongs behind a `sy-sysid`
guard or in a separate report that is never transported.
