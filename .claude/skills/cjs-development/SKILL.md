---
name: cjs-development
description: "Use this skill for any work on the RAK Customer Journey Studio (CJS) — the config-driven citizen-service framework built on ABAP and abap2UI5/z2ui5 at RAK Digital. Triggers include: mentions of CJS, journey engine, ZCL_RAK_JOURNEY_*, ZCL_RAK_CJS, ZRAK_T_JNY* config tables, journey steps/fields/rules, EDITABLE_TABLE or grid specs, PAYFEE and payment flows, the /QNV/ BAdI bridge, ZFM_EGA_CJ_FW_POST_N or READ_N, the Notary REST backend ZCL_RAK_BE_NOT, business partner search via ZCL_EGA_BP_BO_API or ZCL_RAK_BP_SEARCH, or any request to add a control, a step, a validation, a popup or a seed report to a citizen journey. Also use when writing ABAP for S/4HANA 2021 on-premise in this codebase, because the dialect traps in reference/abap-traps.md apply to all of it. Do NOT use for generic ABAP unrelated to CJS, or for OData service building that does not touch a journey."
---

# CJS development

A config-driven journey framework. **Configuration renders the screen; handler
code only decides what happens to the data.** Almost every mistake in this
codebase is a violation of that line in one direction or the other.

## Before writing anything

1. **Read the real source.** Never write against a field name, method signature
   or DDIC component inferred from how it is used elsewhere. Ask for the class or
   the table. Four separate compile errors in one session traced to one guessed
   structure type.
2. **Patch, do not reissue.** Return the changed method or a marked hunk. Whole
   classes handed back lose hardcodes nobody remembers adding.
3. **Say what is unverified.** A comment naming the assumption costs one line; a
   silent guess costs an afternoon. Mark it in the code, not only in chat.
4. **Active does not mean current.** A pull writes the source and leaves the
   object inactive; until it activates the runtime keeps running the OLD version
   and the Class Builder still displays it. Verify by CONTENT — open the method
   and look for a string you just added. `Implemented / Active` proves nothing.

## Decision table — where does this change belong?

| The requirement | Where it goes |
|---|---|
| A control on a step | config: `ZRAK_T_JNY_FLD` row |
| Show/hide/require based on an answer | config: `ZRAK_T_JNY_RULE` |
| Field layout, side by side | config: `FGROUP = 'ROW:<token>'` |
| Row / column / span on the grid | config: `ZRAK_CJ_LAY`, Studio Design tab |
| A field's buttons beside it, not under it | config: `ZRAK_CJ_LAY-FLOW` |
| Multi-column uploads | config: step `COLUMNS = 2` |
| Grid columns, hidden columns, fixed rows | config: `ZRAK_T_JNY_COL` or the `DEFAULT_VAL` spec |
| Text longer than 150 characters | config: `DEFAULT_VAL` `TEXT:` prefix, or `ZCL_RAK_TEXT=>LONG_TEXTS( )` |
| Totals, cross-field maths | handler: `on_change` |
| Anything a rule cannot express | handler: `on_custom_validate` |
| Rows the domain owns, not the citizen | config `FIX` + handler `on_init` seeding |
| A dialog | handler: `on_render_popup` + `on_popup_event` |
| Backend call, case creation | the bridge or the backend adapter, not the handler |
| Who keeps the draft and the files | config: `DRAFT_MODE` / `ATTACH_MODE`, or the `draft_mode( )` / `attach_mode( )` hooks |

If a handler is drawing a form, the configuration is wrong rather than
insufficient.

## Reference files

Read the one that matches the task. They are short.

| File | When |
|---|---|
| `reference/abap-traps.md` | **Always.** Dialect traps that produce misleading compile errors, plus the z2ui5 view-building ones. Every one was hit for real. |
| `reference/config-tables.md` | Adding fields, steps, rules, grid columns, layout |
| `reference/seed-reports.md` | Writing a seed report, or migrating a journey from a /QNV export |
| `reference/grids.md` | `EDITABLE_TABLE`, `TABLE`, column specs, hidden columns, fixed rows |
| `reference/hooks.md` | Handler hooks and the `ZIF_RAK_JOURNEY` context API |
| `reference/payment.md` | `PAYFEE`, the footer state machine, the gateway, fees |
| `reference/bp-search.md` | Business partner lookup, MOI, expiry rules, the popup |

## The rules that catch the most bugs

1. **`TECH_NAME` or it never posts.** A field without it renders, survives every
   round trip, and reaches the backend as nothing. Grids use a `[]` suffix.
2. **`ZLABEL` is `CHAR(150)` and cuts on INSERT.** The tail is gone from the
   database, not hidden by the renderer, so no rendering change recovers it. Long
   text goes in `DEFAULT_VAL` behind `TEXT:` or in `ZCL_RAK_TEXT=>LONG_TEXTS( )`.
   `XCHECK` rule X13 reports any label sitting exactly on the limit.
3. **Field `REQUIRED` does not reach grid rows — grid COLUMN `REQUIRED` does.**
   The grid field holds no scalar, so an empty grid passes field validation:
   check `rows IS INITIAL` yourself. But `ZRAK_T_JNY_COL-REQUIRED` *is* enforced,
   against every row that already exists.
4. **`ZSECTION` and `ZLABEL` both set prints the heading twice.** The section
   draws the panel header, the control draws its own title.
5. **Steps count from zero in hooks.** `get_step( ) = 0` is the first step.
6. **Id columns are three characters.** `RULE_ID` is CHAR3. Generate `GS01..GS15`
   and they truncate to `GS0`/`GS1`, and the INSERT dumps on a duplicate key
   pointing at the statement rather than the naming.
7. **Bilingual is not uniform.** `ZLABEL_AR`, `MSG_AR`, `PLACEHOLDER_AR` and
   `OPT_TEXT_AR` exist. `ZSECTION_AR` and `DEFAULT_VAL_AR` do not. Check before
   assuming a twin.
8. **A DDIC-typed field will not bind to a `TYPE string` parameter**, though a
   character literal will — so the working call sits right above the failing one.
   Wrap it, and remember a syntax error in one method takes the whole class down.

## Trusting a backend's metadata

A REST backend that describes its own fields is describing them for itself, not
for this engine. Carry what genuinely describes the field — labels, options,
`maxLength`, `required` — and be sceptical of the rest.

The Notary blueprint sends a pattern demanding ten digits on a two-choice lookup
whose own `maxLength` is 5. Nothing can satisfy it, and enforcing it blocked
every free-text field on the step with "The format is not valid". One field with
an impossible constraint is evidence the whole attribute is a default nobody
filled in — check a second field before deciding it is intentional.

The general shape: **a value the citizen cannot possibly enter is a bug in the
contract, not in the citizen's typing.**

## Diagnosing

`&trace=X` on the launch URL turns on the gate report and the backend trace —
every HTTP call, every cache hit, every validation rejection with the field, the
pattern and the value. It is the difference between three rounds of inference and
one screenshot.

Do not leave diagnostics on a live screen. A `message_strip` that renders
unconditionally settles in one round trip what inference will not settle in five,
and then it has to come out — the temporary probes in
`ZCL_RAK_NOT_APPROVAL_LOGIC` printed on every step for days after they had
answered their question.

## Testing

`ZRAK_TEST_ALL_SEED` is the regression bed: every control, rule, hook, grid
shape and layout, plus `ZTEST_LINT` which breaks every Studio lint rule on
purpose. Add coverage there rather than building a new demo journey — a feature
with no row in that report is a feature nobody will notice breaking.

`ZCL_RAK_TEST_ALL_LOGIC` is the matching handler and exercises every hook with no
database dependency. A new engine capability belongs in both.
