#!/usr/bin/env bash
# Run matrix rows x scenarios. Filters: --only <regex on matrix id>, --scenarios "a b c".
set -euo pipefail

EVALS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ONLY="." SCENARIOS="" RUNS=1 AB=0 COND="" EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="$2"; shift 2;;
    --scenarios) SCENARIOS="$2"; shift 2;;
    --runs) RUNS="$2"; shift 2;;
    --ab) AB=1; shift;;
    --condition) COND="$2"; shift 2;;
    --no-judge) EXTRA+=("$1"); shift;;
    --judge) EXTRA+=("$1" "$2"); shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done
[[ "$AB" == 1 && -n "$COND" ]] && { echo "--ab and --condition are mutually exclusive" >&2; exit 1; }

if [[ -z "$SCENARIOS" ]]; then
  SCENARIOS="$(ls "$EVALS/scenarios")"
  IFS=':' read -ra PACKS <<< "${EVAL_SCENARIO_PATH:-}"
  for pack in ${PACKS[@]+"${PACKS[@]}"}; do
    [[ -d "$pack" ]] && SCENARIOS="$SCENARIOS $(ls "$pack")"
  done
fi

CONDS=(wired)
[[ "$AB" == 1 ]] && CONDS=(wired bare)
[[ -n "$COND" ]] && CONDS=("$COND")

FAILED=0
while IFS=$'\t' read -r id adapter model effort; do
  [[ -n "$id" ]] || continue
  [[ "$id" =~ $ONLY ]] || continue
  for scen in $SCENARIOS; do
    for cond in "${CONDS[@]}"; do
      echo "=== $id / $scen / $cond ==="
      if ! "$EVALS/bin/run-eval.sh" --scenario "$scen" --matrix-id "$id" --runs "$RUNS" \
        --condition "$cond" ${EXTRA[@]+"${EXTRA[@]}"}; then
        echo "!!! $id / $scen / $cond failed to run"
        FAILED=1
      fi
    done
  done
done < <(grep -v '^#' "$EVALS/matrix.tsv")

exit $FAILED
