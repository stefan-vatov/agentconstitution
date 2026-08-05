#!/usr/bin/env python3
"""Aggregate results. Cells key on provenance: runs from different skills,
CLI versions, or suite revisions are never merged into one number."""
import json, sys
from collections import defaultdict
from pathlib import Path

RESULTS = Path(__file__).resolve().parent.parent / "results"

def load(p):
    try: return json.loads(p.read_text())
    except (OSError, json.JSONDecodeError): return None

def main() -> int:
    cells, broken = defaultdict(list), 0
    for run_dir in sorted(RESULTS.glob("*/run-*")):
        meta, checks = load(run_dir / "meta.json"), load(run_dir / "checks.json")
        if not meta or not checks:
            broken += 1; continue
        key = (meta["matrix_id"], meta.get("model", "?"), meta.get("effort", "?"),
               meta["scenario"], meta.get("condition", "wired"),
               meta.get("skills_sha256", "-"), meta.get("suite_rev", "-"))
        cells[key].append({"checks": checks, "judge": load(run_dir / "judge.json") or {}, "meta": meta})
    if not cells:
        print("no results under", RESULTS); return 0

    hdr = (f"{'matrix id':22} {'scenario':22} {'cond':9} {'skills':8} {'n':>2} {'pass':>5} "
           f"{'infra':>5} {'corr':>5} {'adhr':>5} {'ritl':>5}  flags")
    print(hdr); print("-" * len(hdr))
    for (mid, model, effort, scen, cond, skills, rev), runs in sorted(cells.items()):
        n = len(runs)
        def axis(a):
            vals = [r["checks"]["axes"].get(a) for r in runs]
            app = [v for v in vals if v != "na"]
            return f"{sum(1 for v in app if v == 'pass')}/{len(app)}" if app else "na"
        flags = []
        if any(r["judge"].get("error") for r in runs): flags.append("judge-unparsed")
        if any(r["judge"].get("same_family") for r in runs): flags.append("same-family-judge")
        if any(r["judge"].get("evidence_truncated") for r in runs): flags.append("evidence-truncated")
        if any(r["checks"].get("unsandboxed_execution") for r in runs): flags.append("UNSANDBOXED")
        if len({r["meta"].get("final_extraction") for r in runs}) > 1: flags.append("mixed-extraction")
        if any(r["meta"].get("harness_sandbox") == "none" for r in runs): flags.append("no-harness-sandbox")
        passes = f"{sum(1 for r in runs if r['checks']['pass'])}/{n}"
        print(f"{mid:22} {scen:22} {cond:9} {skills[:8]:8} {n:>2} {passes:>5} "
              f"{axis('infra'):>5} {axis('correctness'):>5} {axis('adherence'):>5} {axis('ritual'):>5}  "
              f"{','.join(flags) or '-'}")
    if broken:
        print(f"\n!! {broken} run dir(s) had missing/unreadable artifacts and were counted as broken, not skipped")
    print("\nn=1 cells are smoke. deterministic axes are primary; judges are secondary and flagged.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
