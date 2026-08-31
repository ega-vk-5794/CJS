#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit), *.clas.abap only: keep the mandatory-field
asterisk on the native control property and off a CSS class.

CLAUDE.md: a required label is marked by the sap.m.Label REQUIRED property —
label( ... required = abap_true ) — which UI5's own renderer draws
(sapMLabelRequired). The 'rakReq' CSS class plus a hand-written .rakReq::after
rule was the old mechanism. It never reliably reached the DOM: a page-wide
search for the class on two live journeys returned zero matches while
VALIDATE_STEP( ) was correctly blocking Submit on the very same fields. That
is the worst shape a bug can have here — the form looks optional and refuses
to submit — and it cost a session before anyone compared the two paths.

Both halves are checked, because either one alone reintroduces the trap:

1. class = '... rakReq ...' on a label( ) call — renders nothing at all now
   that the CSS rule is gone.
2. A .rakReq rule reappearing in the theme CSS — that would pair with any
   stray class and draw a SECOND asterisk beside the native marker.

Sibling classes that share the prefix are deliberately NOT flagged:
rakReqStar (the required-checkbox marker, a real sibling control and not a
label at all), rakReqPanel/Title/Row/Ok/Pend/Done/Todo (the requirements
panel). The word boundary is what separates them.
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

# An ABAP full-line comment is '*' in column 1. Dropping those keeps the check
# off commented-out history (E018 carries ten such lines) without trying to
# parse inline " comments, which cannot be told from a quote inside a literal.
live = "\n".join(ln for ln in text.split("\n") if not ln.startswith("*"))

# 'rakReq' as its own class token: \b stops it matching rakReqStar/rakReqPanel.
class_re = re.compile(r"class\s*=[^\n]*?'[^']*\brakReq\b", re.IGNORECASE)
css_re = re.compile(r"\.rakReq(?![0-9A-Za-z_])")

if class_re.search(live):
    deny(
        "This sets the 'rakReq' CSS class to mark a required label. That class "
        "draws nothing — the .rakReq::after rule behind it was removed once the "
        "last call site stopped setting it, because a leftover rule would draw a "
        "second asterisk beside the native marker. Pass the sap.m.Label property "
        "instead: label( text = '...' required = abap_true ), or required = "
        "<your abap_bool flag>. Better still for a popup, build the dialog with "
        "ZCL_RAK_JOURNEY_LOGIC->DIALOG_FORM( ), which sets REQUIRED for you from "
        "each field's own REQUIRED flag."
    )

if css_re.search(live):
    deny(
        "This adds a '.rakReq' rule back to the theme CSS. The required marker is "
        "drawn by UI5 from the sap.m.Label REQUIRED property and styled by "
        "sapMLabelRequired; a .rakReq rule here would pair with any stray class "
        "and render a SECOND asterisk beside the native one. If you meant the "
        "required-checkbox star, that is .rakReqStar and it still exists."
    )

sys.exit(0)
