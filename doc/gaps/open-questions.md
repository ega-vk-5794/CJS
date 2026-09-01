# What is still missing

Split by cause, because "blocked on access" and "blocked on effort" need
different answers.

## Blocked on access — someone has to supply it

| # | Needed | For | Why it is blocked |
| --- | --- | --- | --- |
| 1 | The **appointment service** — name, DPC, MPC | `APPOINTMENT`, NBA01 | The control reads seven entity sets (`AppointmentsSet`, `CasesSet`, `DatesSet`, `EngineersSet`, `RolesSet`, `SectorsSet`, `SuggestEngineerSet`) and **none** is on any DPC held so far |
| 2 | `ACADEMIC_CALENDAR` control source + its entity set | D019 | Exists in no repository available; only `ZCL_EGA_CJ_ENH_IMPL_D019` references the name |
| 3 | `INPUT_DIRECTED`, `CHECKBOX_GRID`, `PDF_VIEWER` | DOKSL, EPDA, COURT, MP | Zero hits across all three cloned repositories |
| 4 | Where **fishery / boat reads** come from | NE001/NE002, `RAK_BOATCONTROL` | `ZEGA_EPDA_FSHRY_CR` is 100% write-only — 112 methods raise not-implemented. Possibly `ZCL_ZEGA_EPDA_TD_DPC_EXT` (`PermitSet`, `PermitSearchSet`, `PermitItemSet`), unconfirmed |
| 5 | Whether NE001/NE002 are in the `/QNV` export | boats | Not present in the export supplied |

## Blocked on effort — buildable now

| Piece | Note |
| --- | --- |
| **Backend post for the M journeys** | Nothing submits today. No `CREATE_DEEP_ENTITY` wrapper, no screen→`FIELDn` mapping. The pattern to copy is `ZCL_ZEGA_EPDA_FSHRY_CR_DPC_EXT` → `ZCL_EGA_EPDA_FSHRY_HANDLER_API->CREATE_CASE( )` |
| **`GET_EXPANDED_ENTITYSET`** | One blocker gating four features. Needs an expand object the way the entity-set reads needed a request context — same RTTI technique should apply |
| **Real controls** | PARCEL covers 11 of 15 M journeys, CONTRACT 6, SIGN 4. Today PARCEL is a dropdown; the real control is a filtered list, a map, a favourites toggle and a detail dialog |
| **15 Municipality handler classes** | All sit on the generic `ZCL_RAK_JOURNEY_LOGIC`. No journey logic, no payment routing, and the `PAYFEE` field the migrator drops is not re-added on the twelve fee-bearing services |
| **The defaulted 41** | See the census. `PAYMENT` (44 rows) and `INPUT_DIRECTED` (40) first |
| **Workers half of ACCOMODATIONS** | `ZCL_RAK_ACCOM_API->WORKERS( )` exists; E030/E130 do not call it yet |

## Journeys needing a re-run of their loader

Config does not update itself. These carry bindings or ftypes from before the
migrator was corrected:

- **The fifteen M journeys** (`ZRAK_M_MUNI_LOAD`, teardown then migrate) — they were loaded when `PARCEL` pointed at `FindParcelSet`, `TITLEDEED` at a method name, `FLOORUNIT` at the wrong set, and the partner searches were typed `'BP'`
- **E030 / E130** (`ZRAK_E030_LOAD`, `ZRAK_E130_LOAD`) — loaded before `CLASSIFY( )` had an `ACCOM` branch, so the accommodation control is still a text box in their config

## Unresolved from earlier scoping

- The six TEN journeys are mapped by mnemonic because their `JOURNEYTYPE` rows are wrong: NMTC says M032, and NCTC / NPOA / NCPA all say M030
- M029 has three DML families and only `NACO_1` is taken
- M016's title says "Building Regulations/Change of Land Use" while the code resolves to CBR alone — CLU is M015, which is not on the list
- **M031 has 0 fields** — `NMTC_1` contains no interactive control at all (screens `_3` and `_4` only). Needs a decision from the TEN screen owner
- `ZCL_E028_NEW_BERTH_LOGIC` is a duplicate class: real source under a dead name, referenced by nothing, while `ZCL_E028_BERTH_NEW_LOGIC` is referenced six times including by its loader. Deleting a class with an implementation is its owner's call
