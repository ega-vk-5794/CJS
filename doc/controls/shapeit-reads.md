# What each composite control actually reads

Taken from the controls' own JavaScript in `shapeit1120/js/controls/` and
`shapeitext2/controls/` — **not** inferred from entity-set names. Inferring cost
one real defect, recorded at the bottom.

`shapeitext2` was once described as ignorable. It is not: it holds `APPOINTMENT`,
`ACCOMODATIONS`, `MTABLE_COL` and `MTABLE_EXT`, which exist nowhere else.

| Control | Reads | Server-side filters |
| --- | --- | --- |
| `RAKPARCELSELECTOR` | `/PropertiesSet` (journey) | `Partnerguid`, `Partnerrole`, `Type` |
| `RAK_PARCELS`, `ADDPARCELS` | `/PropertiesSet` | `ParcelId` |
| `RAK_PROPERTIES` | `/PropertiesSet` | `ApplType`, `Partnerguid`, `Partnerrole` |
| `RAK_TITLEDEED` | `/PropertiesSet` | `ApplType`, `OwnerType`, `Partnerguid`, `Partnerrole`, `TitleDeedNo`, `TitleDeedYear` |
| `RAK_FLOORUNIT` | `/FloorSet` | `AOID`, `Id`, `Partnerguid`, `Partnerrole` |
| `RAK_FINDCONTRACT` | `/LeaseContractSet` | `ContractId` |
| `RAK_CONTRACTS` | `/LeaseContractSet` | `CaseId`, `ContractNumber`, `Role`, `ValidTo` |
| `RAK_SIGNCONTRACT` | `/SignMethodSet`, `/UAEPassSignSet`, `/AttachmentsSet`, `/ValueHelpSet` | |
| `RAK_BUILDINGCONTROL` | `/ValueHelpSet` | |
| `ENTITY_SELECT` | `/ValueHelpSet` | `DomainName` |
| `ACCOMODATIONS` | `/PortAccommodationSet`, `/WorkersListSet` | |
| `APPOINTMENT` | `/AppointmentsSet`, `/CasesSet`, `/DatesSet`, `/EngineersSet`, `/RolesSet`, `/SectorsSet`, `/SuggestEngineerSet` | service unidentified |

## RAKPARCELSELECTOR in detail

The list is **one** read. Everything else in that control is presentation.

```js
this.models.doRead(this, "/PropertiesSet", T, true, "journey")
```

Server filters: `Partnerrole` (`TR0800`, or `YTR080` when the category is
`GRANTS`), `Partnerguid`, `Type` (`Parcel` / `Unit`; `All` removes the filter).

`Favourite`, `ParcelId`, `SectorText` and `LandUse` are applied **client side**
to the already-fetched list, which is why they are search arguments rather than
filters.

Other reads in the same control:
- `/PartnerSet` with `ID` = partner number, `Role` = `Z00008` — the owners a property manager may act for
- `/MapUrlSet` with `Partnerguid`, `Parcel` — GIS url and token
- `/AddFavourite` function import with `Partner`, `Intreno`, `Remove`
- Full details: `PropertiesSet(Partnerguid=..,Intreno=..)` with `$expand=ToProject,ToPartner,ToMeasurement,ToLandUse,ToDevelopment,ToAttachment`

**What the citizen's press stores:** in single mode the **ParcelId** goes into
`INTRENO_PARCEL`; in multi mode rows go into the screen's table data as
`UiTableColumn1`. The value stored is the parcel id, **not** the internal
`Intreno`. Do not "improve" this to `Intreno` — a draft written by ShapeIt and one
written by CJS have to hold the same value.

Settings come from the definition row: `additionalData1` = multi-select,
`additionalData2` = map, `enabled` = edit mode, `categoryName === "GRANTS"` = grants.

## The defect that came from guessing

`PARCEL` was first bound to **`FindParcelSet`** — a plausible name for a parcel
selector, and wrong. `FindParcel` has no `_GET_ENTITYSET` at all; it is a
`CREATE_DEEP_ENTITY` target that opens a ZGCF case. **A selector bound to it
would have posted a case every time a citizen looked at a list.**

`TITLEDEED` was bound to a method name, and `FLOORUNIT` to the wrong set. All
three were found by reading the controls' `doRead` calls.

Same class of error, different gate: `CLASSIFY( )` typed the five partner-search
controls `'BP'` on the strength of a `WHEN 'BP'` in the renderer — which is in
`RENDER_POPUP( )`, the search *dialog*, not the field renderer. A field typed
`'BP'` reaches `RENDER_ONE( )`'s `WHEN OTHERS` and draws a plain input box. The
field ftype that draws a partner search is **`SEARCH`**.
