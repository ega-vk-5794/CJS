#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit): enforce the CJS namespace boundary.

CLAUDE.md: "Never modify anything in the legacy namespace. It is the legacy
backend and must keep behaving exactly as it does today." This blocks
creating/editing a file that IS a legacy-namespace object, and blocks
introducing a legacy-namespace object definition into any file's content.
It does NOT block references to the legacy system in comments, strings, or
table names — only object definitions.

The regex below matches on the real SAP namespace prefix, because that's
what actually appears in object names and abapGit file paths — it has to,
to catch anything. Nothing else in this repo's docs or messages names it.
"""
import re
import sys
from _common import read_input, changed_text, file_path, deny

_LEGACY_NS = "qnv"

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)
text = changed_text(ti)

if re.search(rf"(^|/)#?{_LEGACY_NS}#", path, re.IGNORECASE) or f"/{_LEGACY_NS}/" in path.lower():
    deny(
        f"{path} is a legacy-namespace object. The legacy backend must never be modified — "
        "CJS must keep it behaving exactly as it does today. Fix this on the CJS side "
        "instead (handler class, config, or engine in ZRAK_*/Z2UI5_*/the BAdI chain). If "
        "it genuinely can't be fixed CJS-side, stop and say so instead of editing it."
    )

OBJECT_DEF = re.compile(
    rf"\b(CLASS|REPORT|FUNCTION-POOL|INTERFACE|PROGRAM)\s+/{_LEGACY_NS}/",
    re.IGNORECASE,
)
if OBJECT_DEF.search(text):
    deny(
        "This defines a legacy-namespace object. The legacy backend must keep behaving "
        "exactly as it does today — never modify it, even from a CJS-side file. Fix this "
        "on the CJS side instead."
    )

sys.exit(0)
