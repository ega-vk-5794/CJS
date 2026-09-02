#!/usr/bin/env python3
"""PostToolUse (Write|Edit|MultiEdit) on src/*.abap: mechanical activation-breakers.

Every check here is a shape that costs a WHOLE ROUND TRIP when it lands:
git push, abapGit pull, activate, read the Class Builder error, fix, repeat.
There is no compiler in this environment, so none of it is caught locally
unless something looks for it. These four have each cost at least one round
in this project already, and two of them cost one on the same day:

  1. METHOD / ENDMETHOD imbalance. A duplicated ENDMETHOD from a bad splice
     reads as valid code line by line.
  2. CONSTANTS ... TYPE string VALUE ''. A string constant will not take an
     empty literal; VALUE IS INITIAL is the form that means blank. This one
     is especially expensive because the class then has NO ACTIVE VERSION,
     so the error surfaces at every CALLER as "Method X is unknown or
     PROTECTED or PRIVATE" and points nowhere near the cause.
  3. An unescaped | inside an ABAP string template - JavaScript's || is the
     one that keeps happening. A literal pipe ends the template, so the
     statement breaks mid-expression.
  4. A source line over 255 characters. The Class Builder truncates and then
     reports "Field ... is unknown" at whatever the cut left behind, naming
     neither the length nor the line that is actually too long.

It reads the file back off disk (the edit has already happened) and nudges
rather than blocking - a partial edit mid-sequence can legitimately be
unbalanced for one call.
"""
import re
import sys
from _common import read_input, file_path, note

data = read_input()
path = file_path(data.get("tool_input") or {})
norm = path.replace("\\", "/")

if "/src/" not in norm or not norm.endswith(".abap"):
    sys.exit(0)

try:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
except OSError:
    sys.exit(0)

problems = []


def is_comment(line):
    return line.startswith("*") or line.lstrip().startswith('"')


code = [(i + 1, l) for i, l in enumerate(lines) if not is_comment(l)]

# 1 -------------------------------------------------------------- balance
opens = [n for n, l in code if re.match(r"\s*METHOD\s+[\w~/]", l, re.I)]
closes = [n for n, l in code if re.match(r"\s*ENDMETHOD\s*\.", l, re.I)]
if len(opens) != len(closes):
    problems.append(
        f"METHOD/ENDMETHOD imbalance: {len(opens)} METHOD vs {len(closes)} ENDMETHOD. "
        "An extra ENDMETHOD is usually a bad splice and reads as valid code line by "
        "line; the Class Builder reports it as an unexpected statement much further down."
    )

# 2 -------------------------------------------------- string constant VALUE ''
for n, l in code:
    if re.search(r"CONSTANTS\s+\w+\s+TYPE\s+x?string\s+VALUE\s+(''|``)\s*\.", l, re.I):
        problems.append(
            f"line {n}: CONSTANTS ... TYPE string VALUE '' — a string constant will not "
            "take an empty literal. Use VALUE IS INITIAL. The class will not activate, "
            "and because it then has no active version every CALLER reports "
            '"Method X is unknown or PROTECTED or PRIVATE" instead.'
        )

# 3 ------------------------------------------- unescaped pipe in a template
# A template is |...|; a literal pipe inside it must be \|. Cheap, targeted
# test: a non-comment line containing || that is not already escaped.
for n, l in code:
    if "||" in l and r"\|\|" not in l:
        problems.append(
            f"line {n}: an unescaped || inside what looks like an ABAP string template. "
            r"A literal pipe ends the template - write \|\| for JavaScript's OR, or the "
            "statement breaks mid-expression and the object will not activate."
        )

# 4 ------------------------------------------------------------ line length
for n, l in enumerate(lines, 1):
    if len(l) > 255:
        problems.append(
            f"line {n} is {len(l)} characters. An ABAP source line stops at 255; past "
            'that the Class Builder truncates and reports "Field ... is unknown" at '
            "whatever the cut left behind, naming neither the length nor this line."
        )

if problems:
    note(
        f"{path}: shapes that will fail activation in SAP, and that nothing in this "
        "environment compiles to catch —\n  - " + "\n  - ".join(problems)
    )

sys.exit(0)
