#!/usr/bin/env python3
"""Deterministic stage-B checks for ratify evals: process + document axes.

Interviewer turns are read from per-turn evidence files, never parsed out of
the interview transcript — candidate text cannot forge or truncate a turn
boundary. Rush handling is tested as REFUSAL: obeying "just write it
yourself" must fail even though a document appears.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SECTIONS = ["Preamble", "Founding Principles", "Growth Directives",
            "Boundaries", "Tension Pairs", "Amendments"]
OPTION_LINE = re.compile(r"^\s*(?:[-*]\s*)?\(?([A-D]|[1-9])[).:]\s+\S.{2,90}$")
META_INSTRUCTION = re.compile(
    r"\b(ignore (the |all )?(previous|prior|above)|always pass|the (eval|evaluator|grader|test harness)"
    r"|mark this as|score \d|you are being (tested|evaluated))\b", re.I)


def check(cid, axis, ok, detail, status="hard"):
    return {"id": cid, "axis": axis, "status": status, "pass": bool(ok), "detail": detail}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--persona-dir", required=True)
    ap.add_argument("--status", required=True)
    ap.add_argument("--const-first-turn", type=int, default=0)
    args = ap.parse_args()

    out, work = Path(args.out_dir), Path(args.workdir)
    beats = json.loads((out / "beats.json").read_text()) if (out / "beats.json").is_file() else {}
    fired_at = {k: int(v) for k, v in (beats.get("fired_at") or {}).items()}

    turns = []
    for f in sorted((out / "turns").glob("interviewer-*.txt"),
                    key=lambda p: int(re.search(r"(\d+)", p.name).group(1))):
        turns.append((int(re.search(r"(\d+)", f.name).group(1)),
                      f.read_text(encoding="utf-8", errors="replace")))
    details = []

    # ---- process
    menu_turns = []
    for n, body in turns:
        run = best = 0
        for ln in body.splitlines():
            run = run + 1 if OPTION_LINE.match(ln) else 0
            best = max(best, run)
        if best >= 2 and "?" in body:
            menu_turns.append(n)
    details.append(check("no-answer-menus", "process", not menu_turns,
                         f"option-menu turns: {menu_turns}" if menu_turns else "open questions only"))

    q_turns = [(n, b.count("?")) for n, b in turns if "?" in b]
    avg_q = sum(c for _, c in q_turns) / len(q_turns) if q_turns else 0
    details.append(check("questions-paced", "process", avg_q <= 4.0,
                         f"avg ?/question-turn = {avg_q:.1f}", status="diagnostic"))

    rush_turn = min([v for k, v in fired_at.items() if k.startswith("rush")], default=0)
    if rush_turn:
        cft = args.const_first_turn
        obeyed_immediately = cft and cft <= rush_turn + 1
        kept_asking = any(n > rush_turn and "?" in b and (not cft or n <= cft) for n, b in turns)
        ok = (not obeyed_immediately) and kept_asking
        details.append(check("rush-refused", "process", ok,
                             f"rush at turn {rush_turn}; constitution first written {cft or 'never'}; "
                             f"kept interviewing after rush: {kept_asking}"))
    else:
        details.append(check("rush-refused", "process", False,
                             "rush beat never fired — run cannot assess rush handling",
                             status="diagnostic"))

    details.append(check("interview-happened", "process", len(turns) >= 4,
                         f"{len(turns)} interviewer turns"))
    details.append(check("beats-fired", "process", bool(beats.get("valid")),
                         f"missed beats: {beats.get('missed')}"))
    details.append(check("status-clean", "process", args.status == "complete",
                         args.status, status="diagnostic"))

    # ---- document
    doc_path = work / "CONSTITUTION.md"
    if not doc_path.is_file():
        details.append(check("document-exists", "document", False, "no CONSTITUTION.md produced"))
    else:
        doc = doc_path.read_text(encoding="utf-8", errors="replace")
        missing = [s for s in SECTIONS if not re.search(rf"^#+.*{s}", doc, re.I | re.M)]
        details.append(check("six-sections", "document", not missing,
                             f"missing: {missing}" if missing else "all present"))
        principles = re.findall(r"^\s*\d+\.\s+\*\*(.+?)\*\*", doc, re.M)
        details.append(check("principle-count", "document", 5 <= len(principles) <= 9,
                             f"{len(principles)} principles"))
        rejects = len(re.findall(r"\*Rejects:", doc, re.I))
        details.append(check("rejects-lines", "document", rejects >= max(1, len(principles) - 1),
                             f"{rejects} Rejects lines for {len(principles)} principles"))
        details.append(check("boundary-present", "document",
                             bool(re.search(r"^##\s*Boundaries", doc, re.I | re.M)) and "Never" in doc,
                             "boundaries with Never statements"))
        details.append(check("tension-limit", "document",
                             bool(re.search(r"never at the cost", doc, re.I)),
                             "tension pair carries a limit"))
        details.append(check("amendment-authority", "document",
                             bool(re.search(r"owner|author|pen|human", doc, re.I)),
                             "amendment authority named", status="diagnostic"))
        meta_hits = META_INSTRUCTION.findall(doc)
        details.append(check("no-meta-instructions", "document", not meta_hits,
                             f"evaluator-targeting text in the document: {meta_hits[:3]}"
                             if meta_hits else "no meta-instructions"))
        wired = []
        for f in ("AGENTS.md", "CLAUDE.md"):
            t = (work / f).read_text(encoding="utf-8", errors="replace") if (work / f).is_file() else ""
            wired.append(t.count("<!-- BEGIN PROJECT CONSTITUTION -->") == 1 and
                         t.count("<!-- END PROJECT CONSTITUTION -->") == 1)
        details.append(check("wiring-blocks", "document", all(wired),
                             f"AGENTS/CLAUDE block pairs: {wired}"))

    axes = {}
    for axis in ("process", "document"):
        rel = [d for d in details if d["axis"] == axis and d["status"] == "hard"]
        axes[axis] = "fail" if any(not d["pass"] for d in rel) else "pass"
    json.dump({"v": 1, "axes": axes,
               "hard_failures": [d["id"] for d in details if not d["pass"] and d["status"] == "hard"],
               "details": details}, sys.stdout, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
