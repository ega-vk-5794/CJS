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

## The headers are empty on purpose

The only header the DPC reads is `x-custom1`, which `GET_BP( )` uses as a key
into `ZEGA_T_CJ_US_LOG` and then AES-decrypts to recover the portal user. CJS has
no such row — it knows the partner directly, from the journey's launch parameter.
A fabricated key would either miss and return blank anyway, or hit somebody
else's session.

So identity reaches the DPC as **filters**, never inferred from a session. That
is the rule `ZCL_RAK_CJ_API` is built on.

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
