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
| [controls/shapeit-reads.md](controls/shapeit-reads.md) | Which entity set each composite control reads, and with which filters |
| [gaps/open-questions.md](gaps/open-questions.md) | What is still missing, and which of it is blocked on access rather than effort |
| [gaps/abapgit-operations.md](gaps/abapgit-operations.md) | Pull and stage hazards observed in this repository, with the evidence |

## The one rule these notes keep proving

**Do not hand-write the shape of a standard SAP object you cannot open.**

Three activation rounds went on guessing `/IWBEP/CL_MGW_REQUEST`'s constructor.
A parcel selector was bound to an entity set that posts a case. A wrapper was
written against a method name that does not exist because the generator
truncates at 30 characters. Every one of those was cheaper to look up than to
guess, and every one of them is now written down below.
