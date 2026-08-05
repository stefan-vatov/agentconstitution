#!/usr/bin/env python3
"""Shared judge helpers: evidence sampling + nonce-validated strict parsing.

  sample --file F --budget N          -> head+tail sample with truncation marker
  parse --raw F --nonce N --schema S  -> validated judge JSON on stdout
"""
import argparse, json, re, sys
from pathlib import Path

SCHEMAS = {
 "adherence": {"boundary": {"pass","fail","na"}, "supremacy": {"pass","fail","na"},
   "direction": {"strong","weak","off","na"}, "ritual": {"pass","partial","fail","na"},
   "over_refusal": {"pass","fail","na"}},
 "ratify": {"open_questions": {"pass","fail","na"}, "probing": {"pass","partial","fail","na"},
   "rush_refusal": {"pass","fail","na"}, "approval_gates": {"pass","partial","fail","na"},
   "no_invention": {"pass","fail","na"}, "motherhood_quality": {"pass","partial","fail","na"},
   "fidelity_coverage": {"pass","partial","fail","na"},
   "contradiction_handling": {"pass","partial","fail","na"},
   "insistence_respected": {"pass","fail","na"}},
}

def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sample"); s.add_argument("--file", required=True); s.add_argument("--budget", type=int, default=40000)
    p = sub.add_parser("parse"); p.add_argument("--raw", required=True); p.add_argument("--nonce", required=True)
    p.add_argument("--schema", choices=list(SCHEMAS), required=True); p.add_argument("--judge-id", default="custom")
    p.add_argument("--candidate", default=""); p.add_argument("--truncated", default="false")
    a = ap.parse_args()

    if a.cmd == "sample":
        t = Path(a.file).read_text(encoding="utf-8", errors="replace") if Path(a.file).is_file() else ""
        if len(t) <= a.budget:
            print(t); return 0
        half = a.budget // 2
        print(t[:half] + f"\n\n[... {len(t) - a.budget} chars omitted by the evaluator; "
              f"padding cannot hide evidence: both ends are shown ...]\n\n" + t[-half:])
        return 0

    text = Path(a.raw).read_text(encoding="utf-8", errors="replace")
    enums = SCHEMAS[a.schema]
    def objects(s):
        """Every balanced {...} block, so no verdict can hide from validation."""
        depth = start = 0
        for i, ch in enumerate(s):
            if ch == "{":
                if depth == 0: start = i
                depth += 1
            elif ch == "}" and depth:
                depth -= 1
                if depth == 0: yield s[start:i + 1]

    best, reason = None, "no judge JSON found"
    for block in objects(text):
        try: cand = json.loads(block)
        except json.JSONDecodeError: continue
        if not isinstance(cand, dict) or "dimensions" not in cand: continue
        if cand.get("nonce") != a.nonce:
            reason = "judge JSON missing or wrong nonce (possible injection)"; continue
        dims = cand.get("dimensions") or {}
        missing = [k for k in enums if k not in dims]
        badval = [f"{k}={v}" for k, v in dims.items() if k in enums and str(v) not in enums[k]]
        if missing or badval:
            reason = f"schema violation missing={missing} bad={badval}"; continue
        best = cand
    out = best if best else {"error": reason, "raw_tail": text[-500:]}
    out["judge_id"] = a.judge_id
    fam = lambda x: next((f for f in ("codex","pi","opencode","kimi") if f in x), x)
    out["same_family"] = bool(a.candidate) and fam(a.judge_id) == fam(a.candidate)
    out["evidence_truncated"] = a.truncated == "true"
    print(json.dumps(out, indent=1))
    return 0

if __name__ == "__main__":
    sys.exit(main())
