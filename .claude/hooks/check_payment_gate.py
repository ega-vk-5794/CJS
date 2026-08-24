#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit), *.clas.abap only: guard the PAID gate.

CLAUDE.md: redefining ON_CUSTOM_VALIDATE must call super-> first, before any
CHECK, because the base implementation is the payment gate (refuses submit
while PAYFEE <> 'PAID'). This only fires when the changed text contains a
full redefinition of the method (its own METHOD/ENDMETHOD block); it can't
see across a partial Edit that touches only part of an existing method, so
it's a best-effort catch, not a guarantee.
"""
import re
import sys
from _common import read_input, changed_text, file_path, deny

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)
text = changed_text(ti)

if not path.lower().endswith(".clas.abap"):
    sys.exit(0)

method_re = re.compile(
    r"METHOD\s+zif_rak_journey_logic~on_custom_validate\b(?P<body>.*?)ENDMETHOD\b",
    re.IGNORECASE | re.DOTALL,
)

for m in method_re.finditer(text):
    body = m.group("body")
    super_re = re.search(
        r"super->zif_rak_journey_logic~on_custom_validate\b", body, re.IGNORECASE
    )
    if not super_re:
        deny(
            "This redefines ON_CUSTOM_VALIDATE without calling "
            "super->zif_rak_journey_logic~on_custom_validate( ) first. That base call is "
            "the PAID gate — it refuses a submit while PAYFEE <> 'PAID'. Omitting it "
            "silently removes payment protection from this journey. Call it before any "
            "CHECK, and if you assign rt, use rt = VALUE #( BASE rt ( ... ) ) to extend "
            "rather than discard it."
        )
    first_check = re.search(r"(?<![\w-])CHECK(?![\w-])", body, re.IGNORECASE)
    if first_check and first_check.start() < super_re.start():
        deny(
            "This redefines ON_CUSTOM_VALIDATE with a CHECK before the "
            "super->zif_rak_journey_logic~on_custom_validate( ) call. A failing CHECK "
            "exits the method, so the PAID gate never runs. Move the super-> call to "
            "before the first CHECK."
        )

sys.exit(0)
