#!/usr/bin/env python3
"""PostToolUse (Write|Edit|MultiEdit), files under src/: verify CRLF survived.

CLAUDE.md: "Source files are CRLF. sed -i strips them on this machine; use
perl -i -pe and check file -b afterwards." This reads the file back off disk
(the edit has already happened) and nudges Claude to fix it in place if any
bare LF (not preceded by CR) turns up, rather than blocking the turn.
"""
import sys
from _common import read_input, file_path, note

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)

if "/src/" not in path.replace("\\", "/"):
    sys.exit(0)

try:
    with open(path, "rb") as f:
        raw = f.read()
except OSError:
    sys.exit(0)

if b"\n" not in raw:
    sys.exit(0)

bare_lf = raw.count(b"\n") - raw.count(b"\r\n")
if bare_lf > 0:
    note(
        f"{path} now has {bare_lf} bare LF line ending(s) — CJS source files are CRLF. "
        "This is likely sed -i or a plain text write stripping them. Fix with "
        "perl -i -pe 's/(?<!\\r)\\n/\\r\\n/g' on this file, then confirm with file -b."
    )

sys.exit(0)
