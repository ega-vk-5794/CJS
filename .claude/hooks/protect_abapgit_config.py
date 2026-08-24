#!/usr/bin/env python3
"""PreToolUse (Write|Edit|MultiEdit): ask before touching abapGit's own
structural config (.abapgit.xml, package.devc.xml, *.devc.xml). These map
this repo to SAP packages and the abapGit repo itself; a hand edit that
drifts from what's actually in SAP breaks Pull/Stage for everyone, and
there's no ADT connection here to check the result. Not a hard block —
just a confirmation checkpoint.
"""
import os
import sys
from _common import read_input, file_path, ask

data = read_input()
ti = data.get("tool_input") or {}
path = file_path(ti)
name = os.path.basename(path).lower()

if name == ".abapgit.xml" or name == "package.devc.xml" or name.endswith(".devc.xml"):
    ask(
        f"{path} is abapGit/package structural config, not journey logic — it maps this "
        "repo to SAP packages. A hand edit here that doesn't match SAP can break Pull/"
        "Stage for everyone, and there's no ADT connection from this environment to "
        "verify the result. Confirm this edit is intentional before proceeding."
    )

sys.exit(0)
