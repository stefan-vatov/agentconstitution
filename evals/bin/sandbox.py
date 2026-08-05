#!/usr/bin/env python3
"""Run a command under OS sandboxing where available.

sandbox.py --cwd DIR [--timeout N] [--deny-write PATH]... -- cmd [args...]

Prints JSON {rc, stdout, stderr, sandboxed, timed_out}. On darwin uses
sandbox-exec to deny network and deny writes to evaluator-owned paths, so
candidate code executed by hidden tests can neither exfiltrate nor tamper
with evidence. Elsewhere it degrades to plain execution with sandboxed:
false — never silently claiming protection it does not have.
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile

SCRUB = re.compile(r"^(CLAUDE|CLAUDECODE|MCP_|VSCODE_|CURSOR_|EVAL_|JUDGE_|PERSONA_|ANTHROPIC|OPENAI)")


def profile(deny_write, home):
    lines = ["(version 1)", "(allow default)", "(deny network*)"]
    for path in deny_write:
        lines.append(f'(deny file-write* (subpath "{os.path.realpath(path)}"))')
    for rel in (".codex", ".claude", ".config", ".ssh", ".aws"):
        p = os.path.join(home, rel)
        lines.append(f'(deny file-write* (subpath "{p}"))')
        if rel in (".ssh", ".aws"):
            lines.append(f'(deny file-read* (subpath "{p}"))')
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cwd", required=True)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--deny-write", action="append", default=[])
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    args = ap.parse_args()

    cmd = args.cmd[1:] if args.cmd and args.cmd[0] == "--" else args.cmd
    if not cmd:
        print(json.dumps({"rc": 2, "stdout": "", "stderr": "no command", "sandboxed": False,
                          "timed_out": False}))
        return 2

    env = {k: v for k, v in os.environ.items() if not SCRUB.match(k)}
    env["PYTHONDONTWRITEBYTECODE"] = "1"

    sandboxed = False
    if platform.system() == "Darwin" and shutil.which("sandbox-exec"):
        with tempfile.NamedTemporaryFile("w", suffix=".sb", delete=False) as f:
            f.write(profile(args.deny_write, os.path.expanduser("~")))
            sb = f.name
        cmd = ["sandbox-exec", "-f", sb] + cmd
        sandboxed = True
    else:
        sb = None

    try:
        proc = subprocess.run(cmd, cwd=args.cwd, env=env, capture_output=True, text=True,
                              timeout=args.timeout, stdin=subprocess.DEVNULL)
        out = {"rc": proc.returncode, "stdout": proc.stdout[-8000:], "stderr": proc.stderr[-8000:],
               "sandboxed": sandboxed, "timed_out": False}
    except subprocess.TimeoutExpired:
        out = {"rc": 124, "stdout": "", "stderr": "timed out", "sandboxed": sandboxed,
               "timed_out": True}
    finally:
        if sb:
            os.unlink(sb)

    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
