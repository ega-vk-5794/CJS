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

### What the control looks like on screen

From screenshots of the live control on "Change Building Regulations" (M016),
September 2026. This is the part a `doRead` call does not tell you, and it is
what decides how the CJS field has to be drawn.

The selector is **not a dropdown**. It is a paginated card list with a chrome
of its own:

| Element | What it does | Where it lands in the wrapper API |
| --- | --- | --- |
| `Owned` / `Property Agent` tabs | whose property to list | `Partnerrole` — `TR0800` vs the managed-owner path |
| owner company dropdown | which owner the agent is acting for | `MANAGED_OWNERS( )` → `IV_OWNER_GUID` |
| ★ `Favorites` toggle | filters to favourites | `Favourite` — **client side**, on the fetched list |
| `Search` box | free text over the list | client side |
| `N Properties found` + pager | **5 cards per page** | client side; the read is not paged |
| per card: `Select` | the citizen's press | writes the **ParcelId**, per above |
| per card: `Full Details` | opens the 7-tab dialog below | `$expand`, and that is the blocked one |

**677 properties over 136 pages** on a property-agent account. The read returns
all of them in one call — `IS_PAGING` is empty and the client pages. So a CJS
`PARCEL` field rendered as a `sap.m.Select` of 677 entries is the wrong control,
not a smaller version of the right one: it needs the typable ComboBox at
minimum (leave `CLOSED_LIST` blank) and really wants a hand-drawn list from
`ON_RENDER_START( )` / `ON_RENDER_END( )`, the way a per-row action has to be.

### The Full Details dialog, tab by tab

One `$expand` read behind seven tabs. The columns below are the live dialog's
own headers, so a CJS rebuild has something exact to match rather than a guess
at what each expand carries:

| Tab | Expand | Columns as the dialog draws them |
| --- | --- | --- |
| Map | `/MapUrlSet` (a separate read, already wrapped) | GIS viewer, parcel outlined, pin |
| General | `ToProject` | Location Information — Area Name, Address, Property Type; then Active Projects |
| Business Partners | `ToPartner` | Role, BP number, Name, Valid From |
| Land | `ToLandUse` | Characteristic, Value, Unit, Valid From (e.g. Land Use / Residential - Private / USAGE) |
| Development | `ToDevelopment` | Building Type, Building Number, Building Name, Valid From |
| Measurements | `ToMeasurement` | Measurements Type, Amount, Unit, Valid From (Gate Level, Parcel Area registered, Parcel Area GIS, No of Coordinates) |
| Documents | `ToAttachment` | Number, Department, Issuing date, Expiry Date — "No data" when empty |

Only the Map tab is reachable from CJS today. The other six are behind
`GET_EXPANDED_ENTITYSET`, which dereferences `IO_EXPAND->GET_CHILDREN( )`
unguarded — the same shape of problem the request context was, and unsolved by
the same measure: nothing here can name `/IWBEP/IF_MGW_ODATA_EXPAND`'s
implementing classes without printing them from the system first. Do that
before writing any of it.

### The list read is confirmed against the live control

`ZRAK_CJ_API_DIAG` on E10 returned parcels `00000000000507060119`,
`00000000000313030024` and `00000000000202040187` for partner `3000401630`.
The screenshots of the same account's selector show **the same three parcels**,
in the same order, with the same `LANDUSE` values. The wrapper reads what the
control reads.

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
