# ABAP traps in this codebase

S/4HANA 2021 on-premise. Every entry below produced a real compile error or a
real runtime surprise, and most of them report themselves misleadingly — the
error names a line that is fine and a cause that is not the cause.

## Constructor expressions

**`VALUE #( )` on an elementary row type demands compatibility, not
convertibility.** A `'...'` literal is `C(n)` and is rejected against `STRING`.
Backticks produce a `STRING` and pass.

```abap
DATA lt TYPE STANDARD TABLE OF string WITH EMPTY KEY.
lt = VALUE #( ( 'text' ) ).     " Error: incompatible with the row type
lt = VALUE #( ( `text` ) ).     " correct
```

Structured rows are unaffected — `VALUE #( type = 'E' text = ... )` converts per
component. **Default to backticks throughout this codebase.**

**`VALUE` needs a type NAME or `#`, never a type definition.**

```abap
DATA(lt) = VALUE STANDARD TABLE OF ty_row WITH EMPTY KEY( ( ... ) ).  " no
```
Reports `Field "VALUE" is unknown`, which points at the constructor and not at
the mistake. Declare the table type first, then `VALUE tt_row( ... )`.

**A base-level component in a table constructor is a default, and a row may not
repeat it.** Reports `The component "X" was specified more than once`. Re-state
the default *between* rows to change it:

```abap
gt = VALUE #( journey_id = c_j columns = 1
  ( step_id = 'S1' ) ( step_id = 'S2' )
  columns = 2
  ( step_id = 'S4' )
  columns = 1              " put it back or S5 onward inherits the 2
  ( step_id = 'S5' ) ).
```

**`DATA(x) = COND #( ... )` cannot always infer its type.** With `#` and an
inline `DATA(...)` there is no target to infer from, and two branches returning
different object references make it worse. Declare the variable first:

```abap
DATA lo TYPE REF TO z2ui5_cl_xml_view.
IF cond = abap_true. lo = parent->hbox( ). ELSE. lo = parent->vbox( ). ENDIF.
```

## Method parameters and calls

**A method's `IMPORTING` parameter is passed BY REFERENCE by default, and by
reference demands type compatibility.**

Nastier than it reads, because a character **literal** binds happily to a
`TYPE string` parameter while a **DDIC-typed field does not**:

```abap
add( iv_rule = 'X13'                " fine — an untyped literal
     iv_step = ls_f-step_id ).      " SYNTAX_ERROR — STEP_ID is ZRAK_JOURNEY_STEP
```

The working line sits directly above the failing one and they look identical.
Wrap it: `CONV #( ls_f-step_id )` or `|{ ls_f-step_id }|`. Either is correct;
match whichever the neighbouring calls already use.

**A syntax error in one method takes the whole class down at load**, so this
presents as a dump in an unrelated feature. `ZCL_RAK_CJS_XCHECK` was unusable
for a day because of one such line, while every symptom pointed elsewhere.

**A functional call used as an expression cannot carry `IMPORTING`.** With a
returning value *and* an exporting one, use the standalone form:

```abap
lo->meth( EXPORTING a = 1 IMPORTING e = lv_e RECEIVING r = lv_r ).
```
Writing `lv_r = lo->meth( a = 1 IMPORTING e = lv_e )` reports `Unable to
interpret "IMPORTING"`.

**Generic types cannot type a DATA or a structure component.** A table type
declared with no key — as Gateway MPC classes do for `tt_*` — is generic: usable
for a formal parameter or a field symbol only. Declare a bound type over the same
line type:

```abap
TYPES tt_bp TYPE STANDARD TABLE OF zcl_x_mpc=>ts_row WITH EMPTY KEY.
```

## Macros

**`DEFINE` splits its arguments on whitespace.** It works while every argument is
a single token and breaks the moment one is an expression, reporting a mangled
fragment on a line that looks correct:

```abap
_flt 'CallMoi' COND string( WHEN x = abap_true THEN 'X' ELSE '' ).
"                ^ torn into pieces: "Unable to interpret STRING("
```

Use a private method. There is no macro in this codebase worth keeping.

**`DO ... TIMES` takes a data object, never a functional expression.**

```abap
DO strlen( lv_s ) TIMES.                    " SYNTAX ERROR
DO ( lines( lt_x ) - 1 ) TIMES.             " SYNTAX ERROR
```

`DO ... TIMES` is not a general expression position. Compute into a variable
first. Same family as `TYPE HANDLE` and `VALUE` below — the message names where
the parser gave up, not what is wrong — and the cost is the one that matters:
**the class does not activate, the runtime keeps the previous ACTIVE version, and
nothing on screen changes.** That reads exactly like a pull that never happened.

```abap
DATA lv_n TYPE i.
lv_n = lines( lt_x ) - 1.
IF lv_n > 0.
  DO lv_n TIMES.
```

Written the wrong way twice in one session, both times in code whose own comments
warned about the family.

**`TYPE HANDLE` takes a VARIABLE, never a method call.** `CREATE DATA lr TYPE
HANDLE lo_tt->get_table_line_type( )` reports *"No method can be specified in the
current position"* — naming neither `TYPE HANDLE` nor the call. Assign the
descriptor to a `DATA lo_line TYPE REF TO cl_abap_datadescr` first.

## Inheritance

**An inherited attribute cannot be redeclared.** Adding a constant to a base
class and leaving the copies in the subclasses stops every subclass at its
declaration:

```
There is already an attribute called "C_FLD_DONATE".
```

The Class Builder reports **the first clash per section only**, so fixing the one
line it names leaves the next one to be found on the next activation. Diff the
whole hierarchy instead: base declarations against each subclass's.

Two siblings may both declare the same name — they are not a chain. Only a
subclass repeating its own ancestor's name is the error.

**`METHODS zif_x~meth REDEFINITION` is not a redeclaration** and may appear at
every level.

**PROTECTED is reachable from a subclass; PRIVATE is not — and neither are its
types.** Inheriting a class to reach one of its methods only works if that
method is protected, and a class can be inconsistent about it. On
`ZCL_ZEGA_CJ_DPC_EXT` the generated `*_GET_ENTITYSET` methods are protected,
which is the whole reason `ZCL_RAK_CJ_API` inherits it — but `GET_FILENET_DOCS`
is private, and so are the `TY_FNDOC` / `TT_FNDOC` types it answers in. Writing
`me->get_filenet_docs( )` in a subclass fails with

```
Method "GET_FILENET_DOCS" is unknown or PROTECTED or PRIVATE.
```

and the follow-on error names the inline `DATA(...)` that never got declared, so
the real cause is the message you did not read. **Check the visibility before
inheriting for access**: the signature comment says `Instance Private Method`,
and the declaration's position relative to `private section` says it too. When
it is private, replicate what the method does rather than calling it — in that
case a `ZCL_EGA_FILENET_HNDLR->SEARCH_TITLE_DEED( )` plus a filter, into a row
type declared in our own class.

## RTTI: what the descriptor classes actually expose

Guessed component names on `CL_ABAP_CLASSDESCR` are a recurring cost. What
working code in this repository proves:

| Read | Where it is proven |
|---|---|
| `lo_cls->methods` | `ZCL_RAK_CJ_REQ_CTX` |
| `lo_cls->get_method_parameter_type( )` | same |
| `ls_m-name`, `ls_m-parameters` | same |
| `ls_par-name`, `-parm_kind`, `-is_optional` | same |
| `lo_descr->absolute_name` | `Z2UI5_CL_AJSON` |

**There is no `IS_ABSTRACT` and no `CREATE_VISIBILITY`** on
`CL_ABAP_CLASSDESCR`, and **a parameter row has no `TYPE`** — the type comes from
`get_method_parameter_type( )`, and `absolute_name` is the one string that names
any type unambiguously, which is what a factory has to `CREATE DATA` against.

## SELECT on a DDIC table you cannot open

**Naming a column puts the program's ability to COMPILE on your memory of the
table.** A column that turns out not to exist is not a wrong answer, it is a
syntax error.

```abap
SELECT clsname FROM seometarel WHERE reltype = 1 AND version = 1 ...   " risky
SELECT * FROM seometarel WHERE refclsname = @p_intf ...                " then
ASSIGN COMPONENT 'RELTYPE' OF STRUCTURE <row> TO FIELD-SYMBOL(<v>).    " runtime
```

`SELECT *` plus `ASSIGN COMPONENT` moves it to runtime, where a missing column is
reported and the report still runs. Worth it for any table outside `ZRAK_*` when
there is no ADT connection to check it with.

And **report those codes rather than filtering on them**: a filter answering "no
rows" for a table full of them is the misleading direction.

For a small table this goes further: **read it whole and filter in ABAP.**
`ZEGA_T_CJ_UI_MAP` is a few hundred rows for the entire landscape, and a `WHERE`
on it would mean asserting the length and type of `JOURNEYID`, `OBJECTKEY` and
`RWMODE` from an environment that cannot open the table. Comparing as text after
the SELECT cannot be wrong and costs nothing at that size.

**Two locals with the same name are not the same structure.** `POST( )` and
`READ( )` in `ZCL_RAK_QNV_BRIDGE` both build an `LS_HDR`; the read's carries
`PARAM1..PARAM4` and the post's is `/QNV/SBUILD_SAVEHEADER_ST`, which has
`CATEGORYNAME`, `SCREENNAME`, `FUNCTIONIN` and no `PARAM` at all. Copying the
read's assignment into the post gives

```
The data object "LS_HDR" does not have a component called "PARAM3".
```

Read the `DATA` line, not the variable name.

## Dynamic calls

**Do not enumerate exception classes you have not verified — catch the family
root.** `CX_SY_DYN_CALL_ILLEGAL_PARAM` does not exist; putting it in a `CATCH`
alongside two siblings is three chances to fail activation for no benefit over
`CX_SY_DYN_CALL_ERROR`, which the whole `CX_SY_DYN_CALL_*` family derives from.
`CX_SY_DYN_CALL_ILLEGAL_CLASS` is used and activates in `Z2UI5_CL_UTIL_ABAP` in
this repository, which is the kind of evidence to look for before naming one.

**A dynamically-called FM's parameters are checked at RUNTIME, which makes a
guarded attempt safe.** `CALL FUNCTION ms_config-backend-fm_post EXPORTING
loginbp = …` raises `CX_SY_DYN_CALL_ERROR` while *binding* — before the function
body runs — so a failed attempt has no side effects and can be retried without
the parameter. Catch that separately from the surrounding `CX_ROOT`: a genuine
backend failure must never be retried, because re-posting a create that half ran
is how duplicate cases are made.

## Table access

**`itab[ n ]` raises `CX_SY_ITAB_LINE_NOT_FOUND`, it does not return blank.**
Grid rows are plain string tables and a row can have fewer cells than the spec
has columns. Guard with `lines( )` or wrap in a helper.

**An offset or length on a `STRING` throws when the string is shorter**, exactly like a
missing table row. `CX_SY_RANGE_OUT_OF_BOUNDS`, not a truncated result and not a blank.
This bites hardest on event names, which are `TYPE string` and short: `CASE iv_event(8)`
against `'OWN_OK'` throws. Prefer `CP` against the event's own wildcard constant - a
pattern match cannot run off the end - or test `strlen( )` first. Worse, the engine
catches `ON_POPUP_EVENT` exceptions and renders them as a Warning, so this presents as a
puzzling message on an action that otherwise worked, never as a dump.

**`OPTIONAL` on a table expression is what stops the dump** when reading a filter
or an optional row:

```abap
DATA(lv) = VALUE #( it[ property = 'EId' ]-select_options[ 1 ]-low OPTIONAL ).
```

**Capture `sy-tabix` before a nested table expression** rather than reading it
inside one. Cheap, and removes a question nobody should have to answer.

**In `LOOP AT ... WHERE`, the LEFT operand of every comparison is resolved as a
COLUMN of the table line — never as a variable in scope.**

```abap
LOOP AT mt_fields INTO DATA(ls) WHERE step_id = ov_step OR ( ov_step IS INITIAL ).
"                                                            ^ looked up as a column
" No component exists with the name "OV_STEP".
```

The right-hand side *is* a variable, which is why the first half of that
condition compiles and the second half does not. Move any test on a variable
into an `IF` inside the loop; leave the `WHERE` for genuine column comparisons.

## Generated keys and short columns

**A key column shorter than the id you generate truncates, and the failure is a
duplicate-key dump at the INSERT.** `RULE_ID` is CHAR3, so `GS01..GS15` become
`GS0` and `GS1`: forty rows collapse to fourteen.

Check the DDIC length before generating any id in a loop. Typed ids never hit
this, which is why it only appears once a report starts generating rows.

Build the number from a `NUMC` rather than a template's `WIDTH`/`PAD` — the
alignment default for numeric types is one more thing to be sure of, and NUMC is
leading-zero by definition.

## Half-commented blocks

Switching a block off by prefixing some of its lines leaves the rest as a
statement with no beginning, and the compiler reports the SURVIVING half:

```abap
*  MODIFY tab FROM @( VALUE #(
    mandt = sy-mandt groupid = "c_grp departmentid = c_dept
    seqnr = '901' ) ).        " Unable to interpret "VALUE" — four errors from one edit
```

A `"` mid-line comments the rest of that line only. Delete the block instead;
git has it.

## Sorting and numbers

**Field-name sorts are string sorts.** `SEQNR` values 20 and 100 sort as "100"
before "20". If order matters, sort numerically — this shipped once as fields
numbered 20 appearing after 150.

## Statements with side effects

**`WAIT UP TO n SECONDS` ends the SAP LUW and triggers an implicit database
COMMIT.** Any uncommitted work is committed whether it was ready or not.
`ZCL_EGA_BP_BO_API->BP_QUERY` contains one, so an Emirates ID search from inside
a journey step commits that step. Never call it from `on_change`.

## Strings

`condense( )`, `to_upper( )`, `substring_after( )`, `SWITCH`, `COND` and
`REDUCE` are all available and used. `COND #( )` infers its type from the
assignment target or the parameter, so it works in a method call argument.

**A source line stops at 255 characters.** Past that the Class Builder truncates
and reports `Field "LV_V" is unknown` — naming whatever the cut left behind, at
the line it cut, never the length. Three unrelated-looking unknown-field errors
on neighbouring lines is the signature. Several single-line `io_form->input( ... )`
calls in `ZCL_RAK_JOURNEY_RENDER` already sit in the 250s, so adding one
parameter tips them over.

**Inside a string template, `{` and `}` must be escaped as `\{` and `\}`.**
Worst where the template carries CSS, because there braces are the syntax:

```abap
|.rakCell\{min-width:0;gap:.25rem;\}|
```

## Building z2ui5 views

Not ABAP dialect, but the same class of misleading failure.

**Children render in creation order.** A container must exist *before* whatever
goes into it. Create a row, then redirect a label into the enclosing cell, and
the label renders BELOW the row — because the row was created first, even though
the code reads the other way round. Create the label's container first, empty if
need be.

**Some properties are constructor-only.** `sap.m.Dialog` `contentwidth` has no
setter, so which variant you are about to draw must be decided before the dialog
is built, not after.

**Not every UI5 property is exposed in this z2ui5 version.** `column( )` and
`text( )` take no `tooltip`. Check the signature in `Z2UI5_CL_XML_VIEW` before
relying on one — a property that does not exist is a compile error, and an icon
that does not exist renders as an empty button with no error at all
(`sap-icon://combine` did exactly that).

**Many fixed-width columns are wider than their panel.** Use `demandpopin` with
`minscreenwidth` so low-value columns fold into the row rather than being clipped
off the right edge. Otherwise the action buttons are what disappears, and nothing
on screen suggests there is anything further right.
