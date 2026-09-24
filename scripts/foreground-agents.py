#!/usr/bin/env python3
"""PreToolUse hook: runs this plugin's own agents in the foreground.

A headless run (claude -p, CI) stops waiting on background agents after ten minutes, and on a large
repo the documenters, renderer and verifier each take longer, so a backgrounded one is killed before
it reports. The skill can only ask for the foreground, and left to itself the model backgrounds
them. Interactive sessions run subagents in the background regardless, so only headless runs change.
"""
import json
import sys

try:
    event = json.load(sys.stdin)
except ValueError:
    sys.exit(0)

tool_input = event.get("tool_input") or {}
if str(tool_input.get("subagent_type", "")).startswith("d2:") and tool_input.get("run_in_background") is not False:
    tool_input["run_in_background"] = False
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": tool_input}}))
