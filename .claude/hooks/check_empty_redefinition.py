#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit), *.clas.abap only: an empty redefinition of
a hook whose base implementation does real work is a DELETION, not a no-op.

ZCL_RAK_JOURNEY_LOGIC is inherited, not implemented, so a redefinition REPLACES
the base body. Where that body does something, an empty override silently
removes it - and SE24's "redefine" button generates exactly this shape,
pre-filled with a commented-out CALL METHOD SUPER-> template that reads like the
call has been made. Four defects in one review traced to it:

  ZCL_E128_RENEW_BERTH_LOGIC   ON_CUSTOM_VALIDATE  -> the PAID gate, gone; the
                                                      journey could be submitted
                                                      unpaid
  ZCL_D020_MOD_SCHOOL_DAY      RENDER_FIELD        -> the payment card, gone
  ZCL_E014_CONSULT_REG_LOGIC   ON_BEFORE_POST      -> the payload strip, gone
  ZCL_E027_VICE_CAPTAIN_LOGIC  ON_BEFORE_POST      -> same

Which hooks count as "does real work" is read from ZCL_RAK_JOURNEY_LOGIC itself
rather than hardcoded, so this stays true as the base class changes. Today that
is ON_CUSTOM_VALIDATE (the PAID gate), ON_POPUP_EVENT (the BP/attachment
machinery), RENDER_FIELD (the payment card) and WANTS_FEEDBACK. The rest of the
interface is genuinely empty and overriding it with an empty body costs nothing.

ON_BEFORE_POST and ON_BEFORE_FIELDS are deliberately EXEMPT. Their base strips
PAY_*/PAYFEE from the payload, which is exactly wrong for a journey that carries
a real fee - D001, D025 and E027 each skip it on purpose and say so in a
comment. Flagging those would train people to ignore this hook.
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
# The base class is allowed to have empty hooks - that is what makes them hooks.
if os.path.basename(path).lower().startswith("zcl_rak_journey_logic"):
    sys.exit(0)

# Skipping the strip is a real decision on a fee-bearing journey, not an oversight.
EXEMPT = {"on_before_post", "on_before_fields"}

METHOD_RE = re.compile(r"METHOD\s+([\w~]+)\b(.*?)ENDMETHOD", re.IGNORECASE | re.DOTALL)
# 'sy-subrc = 0.' is the classic filler used to make a method look implemented.
FILLER_RE = re.compile(r"^(\.|RETURN\s*\.|sy-subrc\s*=\s*0\s*\.)$", re.IGNORECASE)


def live_body(src):
    """Body lines that actually execute: no '*' comment lines, no bare filler."""
    out = []
    for ln in src.split("\n"):
        s = ln.strip()
        if not s or ln.startswith("*") or s.startswith('"') or FILLER_RE.match(s):
            continue
        out.append(s)
    return out


def base_hooks_that_do_work():
    """Hooks whose base body is not empty - read from the base class, not guessed."""
    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    base = os.path.join(root, "src", "zcl_rak_journey_logic.clas.abap")
    try:
        with open(base, encoding="utf-8") as fh:
            src = fh.read()
    except OSError:
        return set()          # cannot read the base: stay quiet rather than guess
    found = set()
    for m in METHOD_RE.finditer(src):
        name = m.group(1).lower()
        if not name.startswith("zif_rak_journey_logic~"):
            continue
        short = name.split("~")[-1]
        if short in EXEMPT:
            continue
        if live_body(m.group(2)):
            found.add(short)
    return found


WORKING = base_hooks_that_do_work()

for m in METHOD_RE.finditer(text):
    full = m.group(1)
    short = full.lower().split("~")[-1]
    if short not in WORKING:
        continue
    body = m.group(2)
    if live_body(body):
        continue              # it does something - not this hook's business
    if re.search(r"super->[\w~]*" + re.escape(short), "\n".join(
            l for l in body.split("\n") if not l.startswith("*")), re.IGNORECASE):
        continue              # chains to the base, which is the whole point

    deny(
        f"{full} is redefined here with an empty body. That is not a no-op: this "
        f"class INHERITS from ZCL_RAK_JOURNEY_LOGIC, so a redefinition REPLACES the "
        f"base implementation - and the base {short.upper()} does real work "
        f"(ON_CUSTOM_VALIDATE is the PAID gate, RENDER_FIELD is the payment card, "
        f"ON_POPUP_EVENT is the BP and attachment machinery). Emptying it removes "
        f"that silently, which is how E128 lost its PAID gate and D020 lost its fee "
        f"card. Either call the base and return its result - "
        f"rt = super->zif_rak_journey_logic~{short}( ... ), extending with "
        f"VALUE #( BASE rt ... ) if you add to it - or delete the redefinition "
        f"entirely so the base runs on its own. A commented-out CALL METHOD SUPER-> "
        f"template is not a call."
    )

sys.exit(0)
