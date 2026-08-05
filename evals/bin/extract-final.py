#!/usr/bin/env python3
"""One final-answer contract for every adapter.

extract-final.py --transcript T --out F --mode-out M --format codex|text

`structured` mode = the CLI's own last assistant message (codex JSON events).
`tail` mode = last assistant-ish chunk of a plain transcript. The mode is
recorded so checks and summaries never compare structured evidence against
tail evidence as if they were the same thing.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07")
NOISE = re.compile(r"^\s*(⏺|●|▪|\||>|\.\.\.)?\s*$")


def codex_final(text: str) -> str:
    last = ""
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        item = ev.get("item") or {}
        if item.get("type") == "agent_message" and item.get("text"):
            last = item["text"]
        elif ev.get("type") == "agent_message" and ev.get("message"):
            last = ev["message"]
    return last


def tail_final(text: str) -> str:
    clean = ANSI.sub("", text)
    lines = [ln for ln in clean.splitlines() if not NOISE.match(ln)]
    return "\n".join(lines[-120:]).strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mode-out", default="")
    ap.add_argument("--format", choices=["codex", "text"], default="text")
    args = ap.parse_args()

    raw = Path(args.transcript).read_text(encoding="utf-8", errors="replace")
    if args.format == "codex":
        final, mode = codex_final(raw), "structured"
        if not final:
            final, mode = tail_final(raw), "tail-fallback"
    else:
        final, mode = tail_final(raw), "tail"

    Path(args.out).write_text(final, encoding="utf-8")
    if args.mode_out:
        Path(args.mode_out).write_text(mode, encoding="utf-8")
    return 0 if final.strip() else 3


if __name__ == "__main__":
    sys.exit(main())
