# The OData services CJS wraps

CJS has no OData. Every read below is reached from ABAP, either by calling a
DPC method a subclass may call, or — more often — by calling the function
module the DPC method itself calls.

**The important discovery, and it holds across three services:** most of these
generated `<Set>_GET_ENTITYSET` methods have no logic of their own. They unpack
filters from an HTTP request into four or five variables and `CALL FUNCTION`.
CJS already has those variables. Calling the function module directly skips the
Gateway plumbing entirely — no request context, no expand object, no DPC
superclass, and no exposure to an inactive DPC chain.

---

## How the four services take their filters — they are NOT the same

This is the single most expensive difference to get wrong, because guessing it
wrong returns *everything* or *nothing* instead of erroring.

| Service | Filters come from | Property names |
| --- | --- | --- |
| CUSTOMERJOURNEY | `IT_FILTER_SELECT_OPTIONS`, the parameter | External — `Partnerguid`, `ApplType` |
| EPDA Maplet, accommodation | `IT_FILTER_SELECT_OPTIONS`, the parameter | External — `IvCase`, `IvPort` |
| **FND, chemical history** | **`IO_TECH_REQUEST_CONTEXT->GET_FILTER( )`** | **Internal — `IV_PERMIT`** |
| **EPDA Maplet, workers** | **`IO_TECH_REQUEST_CONTEXT->GET_FILTER( )`** | **Internal — `IV_LICENSE`** |

The two context-driven methods also call `GET_CONVERTED_SOURCE_KEYS( )`,
`GET_TOP( )` and `GET_SKIP( )`, and they **RAISE** on a filter property they do
not recognise rather than ignoring it.

---

## CUSTOMERJOURNEY — `ZCL_ZEGA_CJ_DPC_EXT`

Wrapped by `ZCL_RAK_CJ_API` (inherits the DPC; the entity-set reads are
protected, so only a subclass may call them).

33 `<Set>_GET_ENTITYSET` methods. `IO_TECH_REQUEST_CONTEXT` is OPTIONAL on all
of them and dereferenced unguarded on many — `GET_REQUEST_HEADERS( )`, 25 times,
and **nothing else is ever called on the context**.

`FeesSet`, `TrackerSet` and `ProjectSet` never touch it. `PropertiesSet`,
`LeaseContractSet`, `PartnerSet`, `OccupantSet` and `UserSet` do.

### PropertiesSet — the one the parcel selector uses
Filters read: `ApplType`, `ParcelId`, `Type`, `Partnerguid`, `Partnerrole`, `Favourite`.

- **`Partnerguid` is mandatory** — blank returns an empty table, silently.
- `ApplType` = `LEASE` or `POA` diverts to `LEASE_PROPERTIESSET( )` before anything else.
- `ParcelId` short-circuits everything: it checks `VILMPL` and answers one row carrying only `PARCELID`. Use it to validate a typed number, never to display a parcel.
- `Partnerrole`: `TR0800` is ownership and property management, `YTR080` is grants — and the DPC translates `YTR080` to `ZTR080` internally, so send the OData spelling.
- It calls `GET_BP( )` on the headers but only *gates* on it when `SY-UNAME` is `PORTAL1` or `RAKDIGI_USER`, which a CJS dialog user is not. That is why an empty header table works here.

### Other confirmed filters
| Entity set | Filters |
| --- | --- |
| `PartnerSet` | `ID` (partner **number**, not guid), `Role` |
| `MapUrlSet` | `Partnerguid`, `Parcel` — returns `URL`, `GISURL`, `TOKEN` |
| `FeesSet` | `Department`, `Intreno`, `JourneyId`, `Partner`, `Role` |
| `TrackerSet` | `Intreno`, `JourneyCode`, `Partner`, `Partnerguid`, `Role`, `ScreenId` |
| `ProjectSet` | `CaseId`, `Dept`, `Partner` |

`JourneyId` on fees but `JourneyCode` on tracker, and `Dept` on projects against
`Department` on fees. They are not consistent and must not be made consistent.

### FindParcelSet is a WRITE
There is no `FINDPARCELSET_GET_ENTITYSET`. `FindParcel` is a
`CREATE_DEEP_ENTITY` target that opens a **ZGCF case** for the "I cannot find my
property" flow, refuses when one is already open, and takes attachments. Binding
a parcel selector to it would post a case every time a citizen looked at a list.

### GET_EXPANDED_ENTITYSET is not reachable
It dispatches on `iv_entity_name` for `gc_properties`, `gc_project`, `gc_floor`
and `gc_license`, and calls `IO_EXPAND->GET_CHILDREN( )` **unguarded**. Nothing
in this layer can build an expand object yet, so everything behind it is
unserved: `FloorSet`, `Project`, `License`, and the parcel full-details dialog
(`$expand=ToProject,ToPartner,ToMeasurement,ToLandUse,ToDevelopment,ToAttachment`).

`PropertiesSet` also has a flat `_GET_ENTITYSET`, which is why the parcel **list**
works and the detail view does not.

---

## zega_fw_fnd_srv — `ZCL_ZEGA_FW_FND_DPC` / `_EXT`

Wrapped by `ZCL_RAK_CHEM_API`, which calls the function module rather than the DPC.

### ChemicalHistorySet
The method is **`CHEMICALHISTORYS_GET_ENTITYSET`** — the generator truncates at
30 characters, so the `et` of `Set` is gone. It is in the **base** class; the
`_EXT` does not mention chemicals at all.

Its whole body is: unpack four filters from the request context, then

```abap
CALL FUNCTION 'ZFE_CJ_CHEMICALS_HIST'
  EXPORTING iv_imp_exp_type, iv_permit, iv_registered_emirates, iv_trade_license
  IMPORTING et_hist          " zif_zfe_cj_chemicals_hist=>zv_epda_chevhelp_tb
```

then copy fifteen fields out.

**Row columns** (`ZV_EPDA_CHEVHELP`, and `TS_CHEMICALHISTORY` under the same names):

```
MANDT  IMPEXPTYPE  PERMIT  TRADE_LICENSE  REGISTERED_EMIRATES
HS_CODE  CHEMINAL_NAME  MATERIAL_NAME  CHEMICAL_FORMULA  CAS_NO
UNIT  PACKAGING  COUNTRY_ORIGIN  POINT_OF_ENTRANCE  TRANSPORT_COMPANY
```

**`CHEMINAL_NAME` is the source's own misspelling.** Not a typo in these notes.
E017's `C_CHEM_POP` constant carries the identical misspelling, which is how we
know that handler's field names were copied from this service. Correcting it
stops it matching.

**`CAS_NO` has the underscore.** Not `CASNO`, not `CAS`.

### Domain ZDO_EPDA_CHEM_IMP_EXP
Exactly two fixed values:

| Value | Meaning |
| --- | --- |
| `1` | Import |
| `2` | Export |

**There is no transit code.** E016 sends `1`, E017 sends `2`, E018 sends nothing
and sees unfiltered history. That is the domain's answer, not a gap — inventing a
third value returns nothing, which looks exactly like an applicant who has never
declared anything.

### What `_EXT` actually redefines
`ATTACHMENTSET_*`, `ATTACHMENTV2SET_*`, `DOCUMENTSET_`, `DOCUMENTV2SET_`,
`FILL_CUSTOM_DOMAIN`, `FILTER_DOMAIN`, `IF_SADL_GW_QUERY_CONTROL~SET_QUERY_OPTIONS`,
`READ_TITLE_DEED`, `VALUEHELPSET_GET_ENTITYSET`. The service also implements
SADL, but only `FieldControlSet` is routed through it.

---

## ZEGA_EPDA_MAPLET_I_SRV — `ZCL_ZEGA_EPDA_MAPLET_I_DPC` / `_EXT`

Wrapped by `ZCL_RAK_ACCOM_API`, again through the function modules.

25 entity sets, including `PortAccommodationSet`, `PortRoomSet`, `PortBedSet`,
`PortBerthSet`, `PortStorageSet`, `WorkersListSet`, `WaitingListSet`,
`MainActivitySet`, `InspectionAnswerSet`, `CheckListSet`, `TaskSet`, `TokenSet`.

### PortAccommodationSet
In `_EXT`. Reads `IvCase`, `IvPort`, `IvReservedItems` off the **parameter**, then

```abap
CALL FUNCTION 'ZEGA_CJ_EPDA_PORT_OBJECTS'
  EXPORTING iv_port, iv_case, iv_reserved_items
  IMPORTING et_building, et_rooms, et_beds
```

All three come back as `ZEGA_CJ_EPDA_PORT_OBJECTS_TT` — the same architectural
object shape at three depths, related by `PARENT_ARCH_OBJECT_ID`.

**`PORTROOMSET_GET_ENTITYSET` and `PORTBEDSET_GET_ENTITYSET` are empty method
bodies.** The accommodation call stashes rooms and beds in protected attributes
`GT_PORT_ROOMS` / `GT_PORT_BEDS` and nothing ever returns them, so over OData
those two entity sets answer nothing at all. Calling the function module gets all
three levels — **CJS is better off here than the legacy UI**.

`TS_PORTACCOMMODATION`: `IV_CASE IV_CONTRACT IV_LICENSE IV_PORT IV_RESERVED_ITEMS`
then `ARCH_OBJECT_ID ARCH_OBJECT_TYPE PART_ARCH_OBJECT_ID ARCH_OBJECT_NUMBER
PARENT_ARCH_OBJECT_ID ARCH_OBJECT_TEXT AVAILABLE AVAILABLE_FROM AVAILABLE_TO
SHARED_STORAGE`.

### WorkersListSet
In the **base**. Filters from the request context, `IV_LICENSE`, then

```abap
CALL FUNCTION 'ZEGA_CJ_EPDA_LABORS_LIST'
  EXPORTING iv_license  IMPORTING et_workers
```
→ `zif_zega_cj_epda_labors_list1=>ztt_cj_fishery_workers`

`TS_WORKERSLIST` carries 36 fields including `WORKER_ID WORKER_BP WORKER_STATUS
VISA_STATUS BOAT_ID ROOM_ALLOCAT ROOM_NO CARD_EXP_ON TRANSFER_LICNO
TRANSFER_BEG TRANSFER_END BP_NAME EMIRATES_ID VISA_ID NATIONALITY`.

Other function modules in this base: `ZEGA_CJ_EPDA_UPDATE_PORT_OBJ`,
`ZFE_CJ_GET_WAITING_LIST`.

---

## ZEGA_EPDA_FSHRY_CR — write-only

**Every read on this service is a stub.** 112 methods raise
`/IWBEP/CX_MGW_NOT_IMPL_EXC=>METHOD_NOT_IMPLEMENTED` — every `GET_ENTITYSET`,
`GET_ENTITY`, `CREATE_`, `UPDATE_` and `DELETE_ENTITY` across `BoatSet`,
`HeaderSet`, `PartnerSet`, `WorkersSet`, `TransferSet`, `FeesSet`,
`FishingAreaSet`, `TreeListSet`, `LocateHoneyBeeSet` and
`AdditionalServicesSet`.

The `_EXT` redefines exactly one method: `CREATE_DEEP_ENTITY`. Its body maps a
deep structure into

```abap
NEW zcl_ega_epda_fshry_handler_api( )->create_case( is_frshy_case = ... )
```

with ten child tables. **That is the posting pattern the Municipality journeys
need** — a handler API class with `create_case( )`, not the BAdI.

So there is no read API for boats on this service. Wherever `RAK_BOATCONTROL`
gets its data, it is not here.

---

## ZCL_ZEGA_EPDA_TD_DPC_EXT — surveyed, not yet used

32 methods covering permits, decisions, inspections, notes, partner relations
and billing: `PERMITSET_`, `PERMITSEARCHSET_`, `PERMITITEMSET_`, `DECISIONSET_`,
`DECISIONVALIDATE_`, `INSPECTIONHIST*`, `NOTESET_`, `OVERVIEWSET_`,
`PARTNERRELATIONS_`, `BILLINGDOCUMENTS_`, `SUBACTIVITYSET_`, `TASKSET_`,
plus `GET_DOMAIN`, `CHECK_PAYMENT_FOR_PERMIT`, `GET_CASE_DETAILS`,
`GET_EXPANDED_FISHING` and `GET_EXPANDED_NOC_CONSULTANT`.

`GET_EXPANDED_NOC_CONSULTANT` handles `CHEMICALSDETAILS` as an expand clause —
that is the **posting** side of the chemical journeys.
