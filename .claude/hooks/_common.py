"""Shared helpers for CJS hook scripts. Not a hook itself."""
import json
import sys


def read_input():
    try:
        return json.loads(sys.stdin.read() or "{}")
    except Exception:
        return {}


def changed_text(tool_input):
    """Best-effort text of what's about to be written, for Write/Edit/MultiEdit."""
    if "content" in tool_input:
        return tool_input.get("content") or ""
    if "new_string" in tool_input:
        return tool_input.get("new_string") or ""
    if "edits" in tool_input:
        return "\n".join(e.get("new_string", "") for e in tool_input.get("edits") or [])
    return ""


def file_path(tool_input):
    return tool_input.get("file_path") or ""


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def ask(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def note(context):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context,
        }
    }))
    sys.exit(0)
