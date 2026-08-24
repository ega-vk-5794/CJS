#!/usr/bin/env python3
"""SessionStart: pull main, then remind Claude of the rules that have already
cost time on CJS (see CLAUDE.md). Output goes to stdout as plain-text context."""
import subprocess

print(subprocess.run(
    ["git", "pull", "--ff-only"],
    capture_output=True, text=True,
).stdout.strip() or "git pull: nothing to report")

print("""
CJS reminders (full detail in CLAUDE.md):
- Never modify anything in the legacy namespace. Fix on the CJS side (handler class, config, engine).
- Handler classes INHERIT FROM zcl_rak_journey_logic; never INTERFACES zif_rak_journey_logic.
- Redefining ON_CUSTOM_VALIDATE must call super-> first, before any CHECK.
- bind()/set_val()/get_val() take the constant, not its name as a string literal.
- Don't hand-author INSERTs into ZRAK_T_JNY* — drive ZCL_RAK_MIGRATOR instead.
- Source files are CRLF. Use perl -i -pe, not sed -i.
- One branch in abapGit: main. Diff before Pull, diff before Stage.
- Nothing here compiles or activates from this environment — say so, don't claim verified.
""")
