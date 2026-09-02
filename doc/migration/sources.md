# The artifacts a journey is built from

A RAK journey is not described by any one system. Seven artifacts each hold
something none of the others do, and every defect in this migration so far came
from building on a subset and inferring the rest.

**Consult all seven before writing a journey, and say in the run log which ones
answered.** A migration that cannot name what it consulted cannot be reviewed.

| Artifact | What ONLY it carries | What skipping it cost, in this project |
| --- | --- | --- |
| **`/QNV/SB_UI_DEFIN` export** | the field list, `CONTROL_TYPE`, `LEVEL_CON`, `DATA1..8`, `LIST_SEQUENCE`, design-time `MANDATORY`, `TECHNICAL_NAME` | a field list inferred from a screenshot is a guess with a compile error at the end of it |
| **BAdI implementation** (`ZCL_EGA_CJ_ENH_IMPL_*`, `ZIF_EGA_FW_CJI~READ`) | the `STAGES` step names in `ADDITIONALDATA3`, runtime field control, BAdI-filled option lists, the create/update/payment shape | every migrated step title was derived and wrong; required flags did not match the live screen; `BKND_ACTIVE` and the two function modules were never written, so journeys posted nothing |
| **ShapeIt control JS** (`RAK-eEGA/shapeit1120`) | what a composite actually READS, with which filters, what it STORES, and how it hands values to anything it embeds | `PARCEL` was bound to `FindParcelSet`, which opens a case on every look. The parcel map took six wrong URL shapes before the control's own `DefconReciveMessage` showed the token travels by `postMessage` |
| **OData DPC / MPC** (`ZCL_ZEGA_CJ_DPC_EXT`, `..._MPC`) | which entity sets are real, which are `$expand`-only, the row types, and which methods dereference the request context | `TITLEDEED` was bound to a method name; `tt_*` row types are generic and cannot type a `DATA` |
| **Screenshots of the live service** | the step count, the layout, what the citizen actually sees | M016 has three steps; the migration produced five. The parcel selector is a paginated card list, not a dropdown |
| **Customization** (`/QNV/SB_LABELT`, `SB_VALUET`, `SB_PLACEHT`, `ZRAK_T_CJ_TXT`) | the captions, option texts and placeholders in both languages | labels fall back to the field name — "Parcelselector" where the screen says "Parcel Selection" |
| **Portal tables** (`ZEGA_T_CJ_GRP` / `_ID` / `_IDT`) | the live portal tree the journey has to hang in | a `MODIFY` relabelled a production group carrying twenty-five services, and fifteen journeys shared one truncated tile |

## The rule behind the table

**Each artifact describes the service from one angle, and the angles disagree.**

- the export says how the screen was **designed**
- the BAdI says how it is **served**
- the control JS says what it **does**
- the screenshots say what the citizen **sees**
- the OData model says what can be **read**

None is wrong; they answer different questions. A migration that reads only the
export produces a screen that is defensible from the export and wrong on every
other axis — which is exactly what the first fifteen Municipality journeys were.

## What the migrator does with each

`ZCL_RAK_MIGRATOR` consults five of the seven directly and reports on all of
them in its run log:

| Artifact | How |
| --- | --- |
| export | `EXTRACT_ROWS( )` — the base |
| BAdI | `BADI_PROBE( )` — one `READ` per screen for `STAGES` and `MANDATORY` |
| OData | `API_BIND( )` — writes the `API:` directive a composite renders from |
| customization | `LOAD_TEXT_CACHES( )` — `/QNV/SB_VALUET` and `SB_LABELT` |
| portal | refuses a group or tile it did not create |
| control JS | **read by hand**, recorded in [`../controls/shapeit-reads.md`](../controls/shapeit-reads.md) |
| screenshots | **read by hand**, recorded per journey under [`../journeys/`](../journeys/) |

The last two cannot be automated, which is why they are written down instead:
the point of `doc/` is that the reading happens once.

## Before starting a journey

1. Is the screen family's export loaded, and does `JOURNEY_OF_SCREEN( )` resolve
   the code you expect?
2. Does the BAdI answer? Run the migrator with `IV_BADI` on and read the log —
   "the BAdI answered nothing" means the step names and required flags are the
   export's own, and nobody should be surprised later.
3. Does any control on it appear in `shapeit-reads.md`? If it is a composite and
   it does not, its source has not been read yet.
4. Is there a walkthrough under `doc/journeys/`? If not, get screenshots of the
   live service before deciding what the steps are.
5. Does the journey take a payment? Then it needs `PAYFEE`, a `handler_class`,
   and the fee reads — see the M016 walkthrough.
