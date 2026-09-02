# Reference notes

Facts about the systems CJS wraps, written down so a session does not have to
re-derive them from source that is not in this repository.

Everything here was read out of a DPC, an MPC, a domain, a control's own
JavaScript or the `/QNV/SB_UI_DEFIN` export. Where something is inferred
rather than read, it says so.

| File | What it settles |
| --- | --- |
| [services/odata-services.md](services/odata-services.md) | Every OData service CJS reads, method by method: which entity sets are real, which are stubs, and which function module sits behind each one |
| [services/request-context.md](services/request-context.md) | How to call a Gateway DPC with no Gateway, and the three failures that taught it |
| [controls/shapeit-census.md](controls/shapeit-census.md) | All 110 ShapeIt control types against what the migrator does with each |
| [migration/sources.md](migration/sources.md) | **Start here for any journey.** The seven artifacts a journey is built from, what only each one carries, and what skipping it has cost |
| [controls/shapeit-reads.md](controls/shapeit-reads.md) | Which entity set each composite control reads, and with which filters |
| [journeys/m016-change-building-regulations.md](journeys/m016-change-building-regulations.md) | One legacy journey walked end to end on the live portal — three steps, every field, the payment screen and a defect |
| [gaps/open-questions.md](gaps/open-questions.md) | What is still missing, and which of it is blocked on access rather than effort |
| [gaps/abapgit-operations.md](gaps/abapgit-operations.md) | Pull and stage hazards observed in this repository, with the evidence |

## What a new session needs, and what it does not

**Does not need to be supplied again** — it is in this repository:

- Every backend DPC and MPC read so far, in [`reference/legacy-src/`](reference/legacy-src/)
- The `/QNV/SB_UI_DEFIN` export, in [`reference/export/`](reference/export/)
- The domain values, filter names and function-module names, in the notes above

**Not in this repository, but nobody has to send it** — these are public GitHub
repositories a session can clone for itself:

| Repository | Holds |
| --- | --- |
| `RAK-eEGA/shapeit1120` | 85 ShapeIt UI controls under `js/controls/` — `RAKPARCELSELECTOR`, `RAK_PROPERTIES`, `RAK_CONTRACTS`, `RAK_SIGNCONTRACT`, `RAK_BOATCONTROL` … |
| `RAK-eEGA/shapeitext2` | `APPOINTMENT`, `ACCOMODATIONS`, `MTABLE_COL`, `MTABLE_EXT` — these four exist nowhere else |
| `RAK-eEGA/rdcusjourney` | the legacy ABAP backend, including `ZCL_ZEGA_CJ_DPC_EXT` and the BAdI implementations |

Clone all three. `shapeitext2` was once described as ignorable; it is not.

**Genuinely still missing** — see [gaps/open-questions.md](gaps/open-questions.md).
The appointment service, the `ACADEMIC_CALENDAR` control, three zero-hit controls
and the fishery reads are in none of the above and have to be supplied by hand.

## The one rule these notes keep proving

**Do not hand-write the shape of a standard SAP object you cannot open.**

Three activation rounds went on guessing `/IWBEP/CL_MGW_REQUEST`'s constructor.
A parcel selector was bound to an entity set that posts a case. A wrapper was
written against a method name that does not exist because the generator
truncates at 30 characters. Every one of those was cheaper to look up than to
guess, and every one of them is now written down below.
