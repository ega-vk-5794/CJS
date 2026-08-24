#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit), *.abap only: catch the CJS silent-failure
traps that are legal ABAP but wrong on this engine (see CLAUDE.md).
"""
import re
import sys
from _common import read_input, changed_text, file_path, deny, ask

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)
text = changed_text(ti)

if not path.lower().endswith(".abap"):
    sys.exit(0)

if re.search(r"\bINTERFACES\s+zif_rak_journey_logic\b", text, re.IGNORECASE):
    deny(
        "This declares INTERFACES zif_rak_journey_logic. That obliges implementing all "
        "~25 methods, so the class will not activate. Handler classes must "
        "INHERITING FROM zcl_rak_journey_logic instead — it gives the empty defaults "
        "and the payment card for free; redefine only what you need."
    )

bind_literal = re.search(
    r"\b(bind|set_val|get_val)\(\s*['\"]C_[A-Za-z0-9_]*['\"]", text
)
if bind_literal:
    deny(
        f"{bind_literal.group(0)} passes a string literal starting with C_ — that binds "
        "to a model component literally named that string, not to the constant of the "
        "same name. Binding to an unknown component is legal and renders blank; nothing "
        "raises. Pass the constant itself, e.g. bind( c_cas_pop ), not bind( 'C_CAS_POP' )."
    )

if "zcl_rak_migrator" not in path.lower():
    insert_jny = re.search(r"\bINSERT\s+(INTO\s+)?zrak_t_jny\w*", text, re.IGNORECASE)
    if insert_jny:
        deny(
            f"{insert_jny.group(0)} hand-authors a row into a ZRAK_T_JNY* table outside "
            "ZCL_RAK_MIGRATOR. Hand-written INSERTs drift from its mapping and duplicate "
            "work it already does correctly — drive ZCL_RAK_MIGRATOR for this instead."
        )

# The external-backend handle's TOKEN rides the serialized engine instance
# between round trips; the engine clears it before every serialize so the
# backend re-acquires it on demand (zif_rak_journey~get_handle). Writing it
# into a persistence statement breaks that assumption. Checked per ABAP
# statement (split on '.') so an unrelated INSERT elsewhere in the same
# file doesn't trip this.
for stmt in re.split(r"\.(?=\s|$)", text):
    if re.search(r"\b(INSERT|MODIFY|UPDATE|EXPORT)\b", stmt, re.IGNORECASE) and re.search(
        r"[-~>]token\b", stmt, re.IGNORECASE
    ):
        ask(
            f"This statement looks like it persists a handle's -token field: {stmt.strip()[:200]!r}. "
            "The engine clears the token before every serialize and expects the backend to "
            "re-acquire it on demand (see zif_rak_journey~get_handle) — never persist it. "
            "Confirm this isn't writing -token to a table, cache, or anything outside the "
            "handle itself."
        )

sys.exit(0)
