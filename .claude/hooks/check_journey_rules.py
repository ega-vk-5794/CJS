#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit), *.clas.abap only: guard the journey's
one identity thread — the case/draft guid — and the PAID gate riding on it.

CLAUDE.md: the engine's live case/draft guid (io_ctx->get_case()) is the one
identity that threads a journey through draft saves, payment, and every
backend post across round trips. Two mistakes break that thread and are
checked here, both only when the changed text contains a full METHOD/
ENDMETHOD block for the method in question — this can't see across a
partial Edit that touches only part of an existing method, so it's a
best-effort catch, not a guarantee:

1. Redefining ON_CUSTOM_VALIDATE without calling super-> first (the PAID
   gate) or after a CHECK that would skip it.
2. Calling commit_step( ) from inside ON_BEFORE_POST or ON_BEFORE_TABLES —
   both hooks already run INSIDE the post that commit_step( ) triggers, so
   calling it there re-enters the post it's already inside of.
"""
import os
import re
import sys
from _common import read_input, changed_text, file_path, deny

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)
text = changed_text(ti)

if not path.lower().endswith(".clas.abap"):
    sys.exit(0)

# ZCL_RAK_JOURNEY_LOGIC *is* the base. Its own ON_CUSTOM_VALIDATE is the PAID
# gate rather than a caller of one, so the super-> rule cannot apply to it -
# without this guard the hook blocks every edit to the class it protects.
if os.path.basename(path).lower().startswith("zcl_rak_journey_logic"):
    sys.exit(0)

method_re = re.compile(
    r"METHOD\s+(?P<name>[\w~]+)\b(?P<body>.*?)ENDMETHOD\b",
    re.IGNORECASE | re.DOTALL,
)

def live(src):
    """Drop ABAP full-line comments ('*' in column 1) before matching.

    Without this the checks below run against prose and fail BOTH ways. The
    false negative is the one that mattered: ZCL_E128_RENEW_BERTH_LOGIC carried
    a commented-out '*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE'
    template above an empty body, which satisfied the super-> search while the
    PAID gate was in fact gone. The false positive is the mirror: a comment
    explaining why the super-> call has to precede the CHECK contains the word
    'check', and tripped the ordering rule on correct code.
    """
    return "\n".join(ln for ln in src.split("\n") if not ln.startswith("*"))


for m in method_re.finditer(text):
    name = m.group("name").lower()
    body = live(m.group("body"))

    if name.endswith("on_custom_validate"):
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

    if name.endswith("on_before_post") or name.endswith("on_before_tables"):
        commit_re = re.search(r"\bcommit_step\(", body, re.IGNORECASE)
        if commit_re:
            deny(
                f"This calls commit_step( ) from inside {m.group('name')}. That hook already "
                "runs INSIDE the post commit_step( ) triggers, so calling it here re-enters "
                "the post it's already inside of. commit_step( ) is meant to be called from "
                "a citizen action (e.g. a PAYNOW event) before the post starts, not from a "
                "hook the post fires along the way."
            )

sys.exit(0)
