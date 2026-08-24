#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit): enforce the CJS namespace boundary.

CLAUDE.md: "Never modify anything under /QNV/. It is the legacy backend and
must keep behaving exactly as it does today." This blocks creating/editing a
file that IS a /QNV/ object, and blocks introducing a /QNV/ object definition
into any file's content. It does NOT block references to /QNV/ in comments,
strings, or table names (e.g. "/QNV/SB_UI_DEFIN") — only object definitions.
"""
import re
import sys
from _common import read_input, changed_text, file_path, deny

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)
text = changed_text(ti)

if re.search(r"(^|/)#?qnv#", path, re.IGNORECASE) or "/qnv/" in path.lower():
    deny(
        f"{path} is a /QNV/ namespace object. /QNV/ is the legacy backend — CJS must "
        "never modify it. Fix this on the CJS side (handler class, config, or engine "
        "in ZRAK_*/Z2UI5_*/the BAdI chain). If it genuinely can't be fixed CJS-side, "
        "stop and say so instead of editing /QNV/."
    )

OBJECT_DEF = re.compile(
    r"\b(CLASS|REPORT|FUNCTION-POOL|INTERFACE|PROGRAM)\s+/qnv/",
    re.IGNORECASE,
)
if OBJECT_DEF.search(text):
    deny(
        "This defines a /QNV/ namespace object. /QNV/ is the legacy backend and must "
        "keep behaving exactly as it does today — never modify it, even from a CJS-side "
        "file. Fix this on the CJS side instead."
    )

sys.exit(0)
