# The ShapeIt control census

Every `CONTROL_TYPE` in the `/QNV/SB_UI_DEFIN` export (43,726 rows, 110 distinct
types), scored against what `ZCL_RAK_MIGRATOR` does with it.

Four outcomes are possible. Only one of them is migration.

| Outcome | Types | Rows | Meaning |
| --- | --- | --- | --- |
| Drawn as intended | 36 | 13,817 | `CLASSIFY( )` names it and `RENDER_FTYPE( )` keeps it |
| Flattened | 4 | 148 | becomes a simpler control; behaviour lost silently |
| **Defaulted** | **41** | **1,565** | `WHEN OTHERS` → a text box or a label. **The backlog.** |
| Correctly dropped | 29 | 20,845 | containers, chrome, decoration — `VBOX`, `HBOX`, `BUTTON` |

## Why a defaulted control is invisible

`CLASSIFY( )`'s `WHEN OTHERS` writes `INPUT` when the row saves and `DISPLAY`
when it does not, then sets `DEFAULTED` — so the migration report counts it as
reviewed. A parcel selector arrived as a text box and nothing said so.

## Two gates, not one

`CLASSIFY( )` assigning an ftype is not enough. `RENDER_FTYPE( )` is a
**whitelist** and its `WHEN OTHERS` clears the result, which the field loop reads
as *discard this row*. A discarded row never reaches `API_BIND( )` either, so it
gets no `API:` directive.

That is what made M011 step 1 look empty: the control was dropped and its
**caption** — a separate display row — survived alone. The grey "Parcel
Selection:" box was a label whose control had been deleted out from under it.

**Add a new ftype in both places.**

## Flattened — 4 types

| Control | Becomes | Cost |
| --- | --- | --- |
| `RAKREMAININGFEES` (89) | `FEES` → `DISPLAY` | static text, no live fee read |
| `MESSAGE_STRIP` (57) | `MESSAGE` → `DISPLAY` | loses severity and icon |
| **`ACADEMIC_CALENDAR`** (1) | `CALENDAR` → `DATE` | a calendar becomes one date field |
| `ACADEMIC_HOURS` (1) | `HOURS` → `NUMBER` | |

## The two calendars

Both are real custom controls and neither survives migration.

**`ACADEMIC_CALENDAR`** — D019, screen `ND019_1_3`, category `DOKSL`. Flattened to
`DATE`. Term structure and non-teaching days are gone. The UI control source is
in **no repository available** — only `ZCL_EGA_CJ_ENH_IMPL_D019` references the
name.

**`APPOINTMENT`** — screens `NBA01_1_2` and `NBA01_1_4`, category `APPOINT`,
3 rows including a companion `APPOINT_JSON2_1` carrying slot state as JSON and a
re-book variant `APPOINT_1_RE`. Falls to `WHEN OTHERS` → a text box, with the
JSON field as a second text box beside it. Control source is in `shapeitext2`.

## Defaulted — the backlog, biggest first

| Control | Rows | Departments |
| --- | --- | --- |
| `PAYMENT` | 44 | CI DML GRANTS MML PAY |
| `RAK_UPLOADER` | 40 | MP (mobile twin of the working `RAKUPLOADER`) |
| `INPUT_DIRECTED` | 40 | DOKSL EPDA |
| `MTABLE_COL` | 23 | APPOINT COURT |
| `MUPLOADER` | 17 | CI GRANTS MML |
| `RAK_PENCIL` | 14 | TEN |
| `MRAKREMAININGFEES` | 9 | DML GRANTS MML |
| `MPARCELSELECTOR` | 8 | DML GRANTS MML |
| `MTABLE_EXT` | 5 | APPOINT COURT |
| `APPOINTMENT` | 3 | APPOINT |
| `CUSTOMER_ACTION` | 3 | CA |
| `DATE_FORMATTER` | 3 | DML |
| `CHECKBOX_GRID` | 2 | COURT MP |
| `RAK_DURATION` | 2 | TEN |
| `RAK_RENTALDETAILS` | 2 | TEN |
| `RAK_RENEWLESSEE` | 2 | TEN |
| `CASE_IDENTIFICATION` | 2 | USAR |
| `RAK_USAR_TABLE` | 2 | USAR |
| `GIS_MAP` | 1 | MP |
| `PDF_VIEWER` | 1 | COURT |
| `WORKER_VERIFICATION` | 1 | PHD |
| `LIMS_CATEGORIES` | 1 | PHD |
| `RAK_PARTYCONTROL` | 1 | COURT |
| `RAK_NCPA_1_1` / `_OWNER` / `_TITLEDEED` | 3 | TEN (M035) |
| `RAK_NCTC_1_3` | 1 | TEN (M033) |

**Eleven of the 41 are `M*` mobile twins** of controls that already work. CJS
renders responsively, so migrating them may be work nobody needs — that is a
decision, not a build.

## Classified but still not drawn

| Control | ftype | Blocked on |
| --- | --- | --- |
| `RAK_SIGNCONTRACT`, `SIGNATURE` | `SIGN` | UAEPass signing wrapper |
| `CHEMICALS_DETAILS` | `CHEMICALS` | deliberately dropped — E016/E017/E018 draw the dialog themselves from `ON_RENDER_END( )`, so a field would be a second empty control beside the real one |
| `RAK_FLOORUNIT` | `FLOORUNIT` | reads `/FloorSet`, which exists only inside `GET_EXPANDED_ENTITYSET` |
| `RAK_BOATCONTROL` | `BOATS` | NE001/NE002 not migrated, and the fishery service has no reads |

`ACCOMODATIONS` was on this list and has come off it — `ZCL_RAK_ACCOM_API` serves it.

## Drawn as intended — selection

| Control | Rows | ftype |
| --- | --- | --- |
| `LABEL` | 11,447 | `DISPLAY` |
| `RADIOBUTTON` | 597 | `RADIO` |
| `RAKUPLOADER` | 420 | `UPLOAD` |
| `COMBOBOX` | 248 | `SELECT` |
| `TBUTTON` | 157 | `SEGMENTED` |
| `DATEPICKER` | 34 | `DATE` |
| `PERSON_SEARCH` | 34 | `SEARCH` |
| `RAKPARCELSELECTOR` | 19 | `PARCEL` — as a list; no map, no detail dialog |
