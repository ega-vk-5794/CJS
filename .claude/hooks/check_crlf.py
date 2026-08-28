#!/usr/bin/env python3
"""PostToolUse (Write|Edit|MultiEdit), files under src/: verify LF survived.

This repo's git history stores every src/ file as plain LF - checked with
`git show HEAD:<path> | file -` across every file type here (.abap, .xml),
zero exceptions found. CLAUDE.md used to claim these files were CRLF; that
was wrong for this repository (it may describe a different working copy,
e.g. one synced live against SAP via abapGit) and cost a real session a
spurious six-file, ~10k-line diff before the mistake was caught. Fixed
2026-08-28 - see the session that found this. Match what's actually in git:
flag a file that GAINED CRLF line endings, not one that lost them.

This reads the file back off disk (the edit has already happened) and nudges
Claude to fix it in place, rather than blocking the turn.
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

crlf = raw.count(b"\r\n")
if crlf > 0:
    note(
        f"{path} now has {crlf} CRLF line ending(s) — this repo's git history stores "
        "src/ files as plain LF (verified across every file here), so this file just "
        "picked up line endings that don't match the rest of the repo. Fix with "
        "perl -i -pe 's/\\r\\n/\\n/g' on this file, then confirm with file -b."
    )

sys.exit(0)
