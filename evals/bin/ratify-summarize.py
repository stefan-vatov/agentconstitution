#!/usr/bin/env python3
"""Aggregate ratify results: process, document, fidelity, and gated governance."""
import json, sys
from pathlib import Path

RESULTS = Path(__file__).resolve().parent.parent / "results"

def main() -> int:
    rows = []
    for s in sorted(RESULTS.glob("ratify-*/summary.json")):
        d = json.loads(s.read_text())
        j = d.get("judge") or {}
        dims = j.get("dimensions") or {}
        fid = dims.get("fidelity_coverage", "-")
        missing = len(j.get("invariants_missing") or [])
        invented = len(j.get("invented_values") or [])
        g = lambda k: (f"{d[k]['passed']}/{d[k]['tasks']}" if d.get(k) else "-")
        flags = []
        if not d.get("calibrated"): flags.append("uncalibrated")
        if j.get("error"): flags.append("judge-unparsed")
        if j.get("same_family"): flags.append("same-family-judge")
        if d.get("persona_mode") != "replay": flags.append("stochastic-author")
        rows.append((d["persona"], d["matrix_id"], d["status"][:18],
                     d["inspection"]["process"], d["inspection"]["document"],
                     fid, f"{missing}/{invented}", g("gov_gated"), g("gov_raw"),
                     ",".join(flags) or "-"))
    if not rows:
        print("no ratify results under", RESULTS); return 0
    hdr = (f"{'persona':11} {'candidate':20} {'status':18} {'proc':5} {'doc':5} {'fidel':7} "
           f"{'miss/inv':8} {'gov*':>5} {'raw':>5}  flags")
    print(hdr); print("-" * len(hdr))
    for r in rows:
        print(f"{r[0]:11} {r[1]:20} {r[2]:18} {r[3]:5} {r[4]:5} {r[5]:7} {r[6]:8} {r[7]:>5} {r[8]:>5}  {r[9]}")
    print("\ngov* = governing power over DISCRIMINATING tasks only (gold passes, absent fails).")
    print("raw = all downstream tasks, uncalibrated — never quote it as governing power.")
    print("miss/inv = invariants missing / values invented, per the fidelity judge.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
