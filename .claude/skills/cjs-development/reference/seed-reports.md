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
