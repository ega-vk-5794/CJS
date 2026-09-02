# Calling a Gateway DPC with no Gateway

`IO_TECH_REQUEST_CONTEXT` is OPTIONAL on every `<Set>_GET_ENTITYSET` and
dereferenced unguarded by many of them. Called with the parameter omitted that
is `CX_SY_REF_IS_INITIAL`, not an empty table.

`ZCL_RAK_CJ_REQ_CTX` supplies one. **It is a factory, not a subclass**, and the
reason is worth the three activation rounds it cost.

## What each attempt taught

| Attempt | Error | What it actually settled |
| --- | --- | --- |
| Subclass, redeclare `MT_HEADERS` | *There is already an attribute called MT_HEADERS* | The parent owns it. Renamed to `MT_HDR`. |
| Same subclass, `super->constructor( )` | *No value was passed to the mandatory parameter `IR_REQUEST_DETAILS`* | The constructor is **not** parameterless, and its type is not readable from a Claude Code environment |
| Same subclass, `RT_REQUEST_HEADERS` | *Field `RT_REQUEST_HEADERS` is unknown* | The returning parameter is **`RT_HEADER`** |

Implementing `/IWBEP/IF_MGW_REQ_ENTITYSET` directly is not the smaller problem
it looks like: ~45 methods plus a component interface, and each missing one is
another activation error.

## The signatures, as the system declares them

Read by `ZRAK_CJ_REQCTX_DIAG`, which prints them via RTTI:

```
/IWBEP/CL_MGW_REQUEST_UNITTST  CONSTRUCTOR: IT_HEADERS[I,MANDATORY] IO_MODEL[I,opt]
/IWBEP/CL_MGW_REQUEST          CONSTRUCTOR: IR_REQUEST_DETAILS[I,MANDATORY] IT_HEADERS[I,MANDATORY] IO_MODEL[I,opt]
```

**`/IWBEP/CL_MGW_REQUEST_UNITTST` takes no `IR_REQUEST_DETAILS` at all.** That is
why the subclass attempts kept failing and the unit-test context works: SAP ships
it as a request context for a DPC with no HTTP request behind it, which is
exactly this situation.

## SETTLED, AND VERIFIED ON E10

Use **`/IWBEP/CL_MGW_REQUEST`**. Not `_UNITTST`.

That is the reverse of the obvious choice and it cost several rounds, so the
reason is worth keeping:

| | `_UNITTST` | `/IWBEP/CL_MGW_REQUEST` |
| --- | --- | --- |
| Constructor | `IT_HEADERS`, `IO_MODEL` | `IR_REQUEST_DETAILS`, `IT_HEADERS`, `IO_MODEL` |
| Constructs? | trivially | yes, once the reference is bound |
| `GET_REQUEST_HEADERS( )`? | **dumps** | **works** |

`_UNITTST` does not redefine `GET_REQUEST_HEADERS( )`, so the inherited one runs:

```abap
rt_header = mr_request->*-technical_request-request_header.
```

and nothing in its constructor sets `MR_REQUEST`. It has no
`IR_REQUEST_DETAILS` to bind either. The object is perfect until the first
time anything uses it, then raises `DATREF_NOT_ASSIGNED` — **which is not
catchable**: a `TRY` around the call does not stop it.

So construction succeeding proves nothing. `ZRAK_CJ_REQCTX_DIAG` reported
`BOUND` for days while every read through the layer would have dumped.

**`BIND_REF( )` is what makes the base class work.** For any mandatory
constructor parameter that is a *data* reference it: reads the referenced type
by RTTI, `CREATE DATA`s onto the reference variable itself so the parameter is
bound rather than null, then walks `TECHNICAL_REQUEST` → `REQUEST_HEADER` and
puts `x-custom1` there — the exact component the getter reads. Every step is
guarded; a reference to a class or interface is left alone, because there is
nothing to fabricate.

### The run that proved it

```
Headers: x-custom1 IS on the context, 64 characters
GET_BP user:    HISHAM.M
GET_BP partner: 3000401630
```

Session key from `ZRAK_CJ_TESTKEY`, E10, September 2026.

### And the run that proved the reads

Construction and identity are one thing; rows are another. `ZRAK_CJ_API_DIAG`,
same system, partner `3000401630`, guid derived from BUT000, key 64 characters:

```
request ctx  BOUND
FeesSet     (ZCL_RAK_FEES_API->FEES)     0 row(s)
TrackerSet  (ZCL_RAK_FEES_API->TRACKER)  0 row(s)
ProjectSet  (ZCL_RAK_FEES_API->PROJECTS) 0 row(s)
PropertiesSet Type=Parcel (->PARCELS)    3 row(s)
  [1] PARCELID=00000000000313030024  LANDUSE=Residential And Commercial  PARCELSTATUS=Created ...
  [2] PARCELID=00000000000202040187  LANDUSE=Residential And Commercial  SECTOR=2 ...
  [3] PARCELID=00000000000507060119  LANDUSE=Residential - Private       SECTOR=5 ...
```

So `PROPERTIESSET_GET_ENTITYSET` — the method that dereferences the request
context on its sixteenth line — runs to completion outside Gateway and returns
the citizen's own parcels. The three zero-row reads are not failures: no case,
journey or screen was passed, so `Intreno`/`JourneyId`/`ScreenId` filtered to
nothing. A read that answers 0 rows with no message is a filter question.

**One link is still untested.** The diag fills `TY_CTX` from its selection
screen. A journey fills it in `ZCL_RAK_CJ_CTX=>BUILD( io_ctx )`, from
`get_param( 'USERDATA' )` and `get_case( )`. Everything downstream of that
structure is now proven; the structure's own construction at runtime is not.

### The fallback that turned out not to be needed

`/IWBEP/IF_MGW_REQ_ENTITYSET` has **41 methods**. Implementing it directly —
every method empty but `GET_REQUEST_HEADERS( )` — was the last resort if no
standard class could be made to answer. It is not needed. The full method list
is printed by `ZRAK_CJ_REQCTX_DIAG` if it ever becomes so.

## How the factory avoids naming any of it

`ZCL_RAK_CJ_REQ_CTX=>GET( )` reads the candidate class's own `CONSTRUCTOR` by
RTTI, builds an `ABAP_PARMBIND_TAB` from whatever it declares **mandatory**, and
instantiates dynamically:

```abap
CREATE OBJECT lo_obj TYPE (iv_class) PARAMETER-TABLE lt_p.
```

Nothing in the source names a signature, so it activates whatever those turn out
to be, and a wrong assumption becomes a **catchable runtime error** instead of a
class that will not load. Optional parameters are deliberately omitted rather
than passed initial — an omitted optional is the constructor's own default, a
supplied one is a value.

Candidates in order: `/IWBEP/CL_MGW_REQUEST_UNITTST`, then `/IWBEP/CL_MGW_REQUEST`.
Confirmed **BOUND** on the first in the RAK system.

## The header, and a correction

**This page previously said the headers were deliberately empty. That was wrong
from the moment we looked properly, and it is worth recording why the wrong
answer was reasonable.**

The only header the DPC reads is `x-custom1`. `GET_BP( )` uses it as the key
into `ZEGA_T_CJ_US_LOG`, takes the row where `ACTIVE = 'X'`, AES-decrypts
`ENCRYPT_KEY` using `USER_KEY`, recovers the internet user, and resolves the
partner through `ZFM_EGA_GET_BP_FROM_INTERNET_U`. While no key was known,
sending nothing was right: a fabricated one would either miss or hit somebody
else's session.

**CJS already holds that key.** It arrives on the launch URL as `&userdata=`,
the engine keeps it in `MV_USERDATA`, and the engine *already* resolves the
login BP with it — `ZCL_EGA_CJ_UTILITY=>GET_BP( qv_key = mv_userdata )`. It is
the citizen's own portal session, created by the portal at login. Passing it
back is not impersonation; it is the same value by the route the DPC expects.

`ZCL_RAK_CJ_REQ_CTX=>GET( iv_userdata )` now puts one row into `IT_HEADERS`,
built through RTTI and `ASSIGN COMPONENT` rather than by naming `TIHTTPNVP` —
same reason as the rest of the class.

**`'x-custom1'` is compared case-sensitively** (`READ TABLE ... WITH KEY
name = 'x-custom1'` against a `STRING` component). Upper-casing it sends a
header nothing reads.

### What it buys, and why filters were never enough

`GET_BP( )` is called from **25** `<Set>_GET_ENTITYSET` methods. The partner it
resolves is consumed downstream in about a dozen places that are *not* the
`PORTAL1` / `RAKDIGI_USER` gate — passed as `IM_BP` to sub-methods, as
`IV_PAY_PARTNER`, written to `LOGINBP`, and used in `WHERE PARTNER = @xpartner`.
**Every one of those received blank, and none of them said so.** No filter can
reach them: they consume the partner `GET_BP( )` resolves, not one the caller
supplies.

The `PORTAL1` gate itself was never the problem. `new` is only set when
`x-custom1` is present, so with empty headers it stays initial and the inner
`RETURN` never fires — and a CJS dialog user is not `PORTAL1` anyway.

### Identity now travels both ways, deliberately

Filters remain primary — `Partnerguid`, `Partner`, `Partnerrole`. The header
reaches what filters cannot. Neither replaces the other.

An expired or logged-out session has no `ACTIVE` row, so `GET_BP( )` returns
early and the read comes back empty rather than dumping. `GET( )` also caches on
the key, not just on the object: a context carries its headers from
construction, so one built for a blank key cannot answer for a real one.

### What the launch carries — CJS and the portal differ

**A CJS journey launch passes the RAW KEY.** That is the normal case and it
goes straight into `x-custom1` with no processing. Nothing below applies to it.

The rest of this section is about the legacy shape, which the same parameter
carries on a portal launch.

**`&userdata=` is JSON there, and the two `GET_BP( )`s disagree about it.**

`ZCL_EGA_CJ_UTILITY=>GET_BP( qv_key )` — the one the *engine* already calls —
deserializes it into `{ ebp, rolebp, rolename }` and matches
`ZEGA_T_CJ_US_LOG` on **`EBP`**.

`ZCL_ZEGA_CJ_UTILITY_DPC_EXT=>GET_BP( )` — the one the *DPC* calls — takes the
`x-custom1` header value **as** the key, with no unwrapping:
`WHERE user_key EQ @l_key`.

Two classes, the same method name, different input formats. Passing the
envelope where the raw key belongs matches no row and resolves nobody, and
nothing says so. `ZCL_RAK_CJ_CTX=>SESSION_KEY_OF( )` unwraps it, and returns
the input unchanged when it is not JSON — so a launch carrying the bare key
still works.

This was got wrong once, in the commit that first added the header, and caught
by asking whether an existing class already did the job.

**Note the asymmetry it leaves.** The JSON envelope also carries `ROLEBP` and
`ROLENAME`, and `ZCL_EGA_CJ_UTILITY=>GET_BP( )` returns both straight out of it
without touching the database. A CJS launch passing only the key does not carry
them, so `ZCL_RAK_CJ_CTX` takes the role from `GET_PARAM( 'ROLE' )` instead. If
a DPC path is ever found that needs the role **BP** specifically, it will not
come from the session.

### There is a second door

`GET_BP( )` takes `KEY TYPE XSTRING OPTIONAL` as an alternative to the context.
The `<Set>_GET_ENTITYSET` methods do not expose it — they always pass the
context — which is why the header is the injection point. But for direct calls
to `GET_BP( )` the key can go straight in.

### And a lookup that is not possible

`ZEGA_T_CJ_US_LOG` has no partner column. The mapping is one-way: key →
encrypted internet user → BP. **You cannot find a session row from a business
partner**, so "look up the row for this user" is not an option; the key has to
be carried in from the launch.

## If GET( ) returns unbound

It degrades, it does not dump. Every DPC call in this layer runs inside
`CATCH cx_root -> TO_MSG( )`, so a failed read reaches the citizen as a message.
`WHY( )` gives the reason and `DIAG( )` prints both constructors.

**Run `ZRAK_CJ_REQCTX_DIAG` before theorising about this.**

## And the better answer, where it exists

For chemical history and port accommodation the request context turned out to be
unnecessary: those DPC methods only exist to turn an HTTP request into a handful
of variables before calling a function module. Prefer the function module. See
[odata-services.md](odata-services.md).
