# Business partner search

Three ways to use it, in increasing order of how much code you write. **Pick
the first one that fits** — most journeys need the first, which is config only.

`SKILL.md` has advertised this file for a long time and it did not exist. If
something here disagrees with the source, the source wins: `ZCL_RAK_BP_SEARCH`
and `ZCL_RAK_BP_POPUP`.

---

## 1. `FTYPE = 'SEARCH'` — config only, no handler code

One row in `ZRAK_T_JNY_FLD`. The engine draws the field, a Browse button, the
whole dialog, the result list, and writes the pick back. **This is what a
migrated partner-search control becomes**, and what M018 uses:

```abap
( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 50
  field_name = 'SHAERDID' ftype = 'SEARCH'
  zlabel = 'Find Business Partner' zlabel_ar = 'البحث عن شريك تجاري'
  attach_label = 'Identification Document'
  has_attach = 'X' attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = '5' )
```

**Do not also seed the five identity fields.** The dialog already carries Search
By, Emirates ID, Date of Birth, Nationality and the results list. Seeding those
as fields draws the search twice and leaves the second copy wired to nothing.

### What the engine does with it

| Event | Raised by | Effect |
|---|---|---|
| `BPOPEN_<field>` | the Browse button | sets `MV_POP_FIELD`, opens the BP popup, clears the previous hits |
| `BPPICK_<partner>` | a row in the result list | writes the partner into `<field>`, the name into `<field>_NAME`, calls `ON_CHANGE( )`, clears the field's value state |

**The `_NAME` companion is why the field name ceiling matters.** `BUILD_MODEL( )`
builds `_VS`, `_VST`, `_IDTYPE`, `_NAME`, `_IX` and `_EXP` on the same name, so a
`SEARCH` field name is capped at **23** characters like every other. Over that
and the app dies with an uncaught `CX_SY_STRUCT_COMP_NAME` — not just that field.

`ON_CHANGE( )` fires **after** both values are written, so a handler reading
`get_val( 'SHAERDID' )` and `get_val( 'SHAERDID_NAME' )` there gets both.

### Suppressing the Browse button

`ZRAK_T_JNY_FLD-NO_BROWSE = 'X'` draws the field without it — for a journey
where the citizen types a formatted Emirates ID and the browse dialog is not
part of the service. **Opt-in**: blank renders exactly what it renders today.

---

## 2. `ZCL_RAK_BP_POPUP` — a handler's own dialog

When the step needs the search somewhere the `SEARCH` ftype cannot put it — a
party card, a second partner on the same step, a dialog of your own.

```abap
" ON_INIT( ) or wherever the popup is created
mo_bp = NEW zcl_rak_bp_popup( io_ctx     = io_ctx
                              iv_subject = 'P1'
                              iv_title   = 'First Party'
                              is_search  = ls_template ).

" ON_RENDER_POPUP( )
mo_bp->render( io_popup ).

" ON_POPUP_EVENT( ) — returns X when the event was one of its own,
" so several popups can chain
IF mo_bp->handle( iv_event ) = abap_true.
  RETURN.
ENDIF.

" the result, for the step's own read-only card. Blank until a search succeeds.
DATA(lv_bp) = mo_bp->partner( ).
```

Its own events are `BPP_SEARCH`, `BPP_RESUME`, `BPP_CLOSE` — constants on the
class, not literals to retype.

**`IS_SEARCH` is a TEMPLATE, not a full request.** The popup fills the five
identity fields from what the citizen types — `IDTYPE`, `EID`, `TRADE_LICENCE`,
`DOB`, `NATIONALITY` — and takes everything else from the template verbatim:
`NO_MOI_CALL`, the three `SKIP_` switches, `MSG_TYPE`, `MAX_ROWS`, `FLAG`,
`ZP28`, `SEARCH_TERM`. Passing nothing reproduces the default behaviour.

Its wording comes from `ZCL_RAK_TEXT`, not literals — the dialog is shared
across journeys, and a bare literal is what left it untranslated on an Arabic
run once.

### Document type constants

`c_eid` `YFS002` · `c_pass` `YFS005` · `c_unif` `YFS001` · `c_tlic` `YP0001`.
Use the constants; the four spellings are the backend's interface.

---

## 3. `ZCL_RAK_BP_SEARCH=>SEARCH( )` — direct

```abap
DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).
```

`SEARCH( )` is the **choke point both popups go through**, which is why every
guard below lives there and not in the popup — a journey drawing its own dialog
has no hook between the model and the filter.

### `TY_REQ` — one field per identifier, and it matters

```abap
eid              " Emirates ID, dashes or not
document_number  " passport number
uid              " unified number
trade_licence    " trade licence
partner          " partner number
```

**Sending a passport number in `EID` asks which partner has an Emirates ID equal
to a passport number.** That matches nothing, and the citizen is told *"No data
found"* — indistinguishable from a mistyped number. The four spellings are the
backend's own (`ZCRM_MOI_CR_UPD`, `SET_MOI_QUERY_PARAM`), not a guess.

`ADD_FLT( )` skips a blank value, so filling only `EID` sends exactly the
filters it sends today. It rejects only a *blank* value — it does **not**
validate content.

### `FLAG` is not a boolean. Three values, each switching off something else.

| Value | Meaning |
|---|---|
| `''` | everything runs |
| `'X'` | MOI is called and the BP updated from it, but a DOB or nationality mismatch does **not** reject. Both expiry checks still run |
| `'T'` | tenancy. **Both expiry checks off.** Not a general "skip validation" switch and must not be used as one |

### `MSG_TYPE` governs a partner that WAS found

It decides how strictly to judge a hit — not whether to search. A precondition
failure (nothing was searched for) is always `'E'`, never `MSG_TYPE`, because on
a `'W'` path the empty result set would assert "no such partner" when no
question was asked.

---

## The two normalisers — use them, don't reimplement

### `NORM_EID( )` — public, a class method on purpose

`784-1988-2718131-8` and `784198827181318` are the same Emirates ID. Anything
comparing two of them has to say so. It is public and static because the popup
and the engine both take an ID straight from a citizen, who types it the way it
is printed on the card, and every layer below expects the digits — a caller
should not have to instantiate a search to tidy a string.

### `NORM_DOB( )` — and the dump it prevents

**`sap.m.DatePicker` does not discard input it fails to parse.** It flags its own
`valueState` and still writes the typed characters through the two-way binding.
Nothing on the CJS side objects — `TY_REQ-DOB` is `TYPE string` — so `'19.08.1987'`
travelled into `ZCL_EGA_BP_BO_API=>BP_QUERY` and raised an **uncatchable**
`CX_SY_CONVERSION_NO_DATE`: *"Application Error - Please Restart The App"*, the
whole session gone, no message.

`SEARCH( )` now normalises `IS_REQ-DOB` through `NORM_DOB( )` (which delegates to
`ZCL_RAK_JOURNEY_UTIL=>TO_DATS( )`, the same parser the DATE range check uses) and,
when a **filled** value will not normalise, reports it and does not search.

Two consequences worth knowing:

- The normalisation happens **before** `VALIDATE( )`'s MOI cross-check
  (`LS_BP-DOB <> IS_REQ-DOB`), or that comparison starts failing against a value
  it used to match.
- **Any other `TY_REQ` field `BP_QUERY` converts on the far side has the same
  exposure.** Date of birth is only the one that has been hit, and a sweep was
  deliberately not done — the fix for each would be a guess about a target type
  nothing on the CJS side can see. The cheap version, if it ever matters: ask
  whoever owns `ZCL_EGA_BP_BO_API` which filter properties it converts to
  something other than a string, and look only at those.

---

## The light search — Notary, and what it costs

`ZCL_RAK_NOT_APPROVAL_LOGIC->BP_OPTS( )` runs the parties with `NO_MOI_CALL` and
findings as **warnings** rather than errors. That is the one place to restore
full verification, and it is a deliberate relaxation, not the default.

---

## UX notes

- **An empty partner list should draw nothing, not a blank row.**
  `ZCL_RAK_JOURNEY_BE` now drops a backend row whose every cell is blank and
  traces the count. The grants abstract's `GET_BP_TABLE( )` appends a row for a
  partner range built from a possibly-blank `ZTR080` partner, and `GET_BP( )`
  returns on `IF partner IS INITIAL` — so an untouched partner list used to show
  one empty line carrying nothing but a delete button.
- **A partner grid is `EDITABLE_TABLE` with per-column `READONLY`**, never
  field-level `READONLY` — the field flag takes the rows away from the search
  that fills them as well as from the citizen. See `config-tables.md`.
- **Do not set `ZSECTION` and `ZLABEL` to the same string** on the grid the
  search fills; the section draws the panel header and the control draws its own
  title, so the heading prints twice.
