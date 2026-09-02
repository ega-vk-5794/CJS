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
