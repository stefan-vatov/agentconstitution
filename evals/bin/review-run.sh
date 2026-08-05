#!/usr/bin/env bash
# Operator calibration aid: show one run's evidence side by side.
# Usage: review-run.sh <results/...-dir/run-N>
set -euo pipefail
RUN="${1:?usage: review-run.sh <run dir>}"

echo "=== meta ==="; cat "$RUN/meta.json"
echo; echo "=== checks ==="
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print('pass:', d['pass'], '| axes:', d['axes']); [print(' ', c['id'], '->', 'PASS' if c['pass'] else 'FAIL', '|', c['detail'][:120]) for c in d['details']]" "$RUN/checks.json"
echo; echo "=== judge ==="; cat "$RUN/judge.json" 2>/dev/null || echo "(no judge)"
echo; echo "=== diff (head) ==="; head -80 "$RUN/diff.patch"
echo; echo "=== final answer (head) ==="; head -c 2500 "$RUN/final.txt"; echo
