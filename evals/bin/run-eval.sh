#!/usr/bin/env bash
# Run one scenario against one model config, N times.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
EVALS="$ROOT/evals"
RESULTS_DIR="${RESULTS_DIR:-$EVALS/results}"

SCENARIO="" ADAPTER="" MODEL="" EFFORT="" MATRIX_ID="" RUNS=1 JUDGE=1 CONDITION=wired
FIXTURE_DIR_OVERRIDE="" REQUIRE_CROSS_FAMILY=0
JUDGE_ID="${JUDGE_ID:-judge-codex-sol}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario) SCENARIO="$2"; shift 2;;
    --adapter) ADAPTER="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --effort) EFFORT="$2"; shift 2;;
    --matrix-id) MATRIX_ID="$2"; shift 2;;
    --runs) RUNS="$2"; shift 2;;
    --condition) CONDITION="$2"; shift 2;;
    --judge) JUDGE_ID="$2"; shift 2;;
    --fixture-dir) FIXTURE_DIR_OVERRIDE="$2"; shift 2;;
    --require-cross-family) REQUIRE_CROSS_FAMILY=1; shift;;
    --no-judge) JUDGE=0; shift;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

[[ "$SCENARIO" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo "--scenario required (dir name)" >&2; exit 1; }
[[ "$RUNS" =~ ^[1-9][0-9]*$ ]] || { echo "--runs must be positive int" >&2; exit 1; }
[[ "$CONDITION" =~ ^(wired|bare|no-const|no-skills)$ ]] || {
  echo "--condition must be wired|bare|no-const|no-skills" >&2; exit 1; }

if [[ -n "$MATRIX_ID" ]]; then
  row="$(grep -v '^#' "$EVALS/matrix.tsv" | awk -F'\t' -v id="$MATRIX_ID" '$1==id{print; exit}')"
  [[ -n "$row" ]] || { echo "no matrix row: $MATRIX_ID" >&2; exit 1; }
  ADAPTER="${ADAPTER:-$(cut -f2 <<<"$row")}"
  m="$(cut -f3 <<<"$row")"; e="$(cut -f4 <<<"$row")"
  [[ "$m" == "-" ]] || MODEL="${MODEL:-$m}"
  [[ "$e" == "-" ]] || EFFORT="${EFFORT:-$e}"
else
  MATRIX_ID="${ADAPTER:-unset}${MODEL:+-$(tr '/' '_' <<<"$MODEL")}${EFFORT:+-$EFFORT}"
fi
[[ -n "$ADAPTER" ]] || { echo "--adapter or --matrix-id required" >&2; exit 1; }

if [[ "$JUDGE" == 1 ]]; then
  if [[ -n "${JUDGE_CMD:-}" ]]; then
    JUDGE_ID="preset-custom"    # never claim a catalog id for a preset command
  else
    JUDGE_CMD="$(grep -v '^#' "$EVALS/judges.tsv" | awk -F'\t' -v id="$JUDGE_ID" '$1==id{print $2; exit}')"
    [[ -n "$JUDGE_CMD" ]] || { echo "no such judge in judges.tsv: $JUDGE_ID" >&2; exit 1; }
  fi
  export JUDGE_CMD JUDGE_ID
  if [[ "$REQUIRE_CROSS_FAMILY" == 1 ]]; then
    candidate_family="$(python3 "$EVALS/bin/judge-lib.py" family --value "${MODEL:-$MATRIX_ID}")"
    judge_family="$(python3 "$EVALS/bin/judge-lib.py" family --value "$JUDGE_ID")"
    [[ "$candidate_family" != "$judge_family" ]] || {
      echo "judge $JUDGE_ID is same-family as ${MODEL:-$MATRIX_ID}" >&2; exit 1; }
  fi
fi

# scenario resolution: private packs (EVAL_SCENARIO_PATH, colon-separated) first
SCEN_DIR=""
IFS=':' read -ra PACKS <<< "${EVAL_SCENARIO_PATH:-}"
for pack in ${PACKS[@]+"${PACKS[@]}"} "$EVALS/scenarios"; do
  [[ -n "$pack" && -d "$pack/$SCENARIO" ]] && { SCEN_DIR="$pack/$SCENARIO"; break; }
done
ADAPTER_SH="$EVALS/adapters/$ADAPTER.sh"
[[ -n "$SCEN_DIR" && -d "$SCEN_DIR" ]] || { echo "no such scenario: $SCENARIO" >&2; exit 1; }
[[ -x "$ADAPTER_SH" ]] || { echo "no such adapter: $ADAPTER" >&2; exit 1; }

FIXTURE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["fixture"])' "$SCEN_DIR/scenario.json")"
WANT_SKILLS="$(python3 -c 'import json,sys; print(1 if json.load(open(sys.argv[1])).get("skills", True) else 0)' "$SCEN_DIR/scenario.json")"
WANT_CANARY="$(python3 -c 'import json,sys; print(1 if json.load(open(sys.argv[1])).get("canary") else 0)' "$SCEN_DIR/scenario.json")"
FIX_DIR="$EVALS/fixtures/$FIXTURE"
[[ -z "$FIXTURE_DIR_OVERRIDE" ]] || FIX_DIR="$FIXTURE_DIR_OVERRIDE"
[[ -d "$FIX_DIR" ]] || { echo "no such fixture: $FIX_DIR" >&2; exit 1; }

# ORACLE HELD IN PROCESS MEMORY: expected.json and hidden tests are stashed as
# a base64 tar in a shell variable and never exist on disk while the candidate
# runs. Shell variables are not exported and not visible to other processes.
ORACLE_TAR="$(tar -cf - -C "$SCEN_DIR" expected.json hidden 2>/dev/null | base64 || true)"
[[ -n "$ORACLE_TAR" ]] || { echo "scenario missing expected.json" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$RESULTS_DIR/$STAMP-$SCENARIO-$MATRIX_ID-$CONDITION-$$"
mkdir -p "$RESULTS_DIR"; mkdir "$OUT"

SUITE_REV="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
SUITE_DIRTY="$(git -C "$ROOT" status --porcelain -- evals 2>/dev/null | head -1)"
[[ -z "$SUITE_DIRTY" ]] || SUITE_REV="$SUITE_REV-dirty"

PUBLIC="$(mktemp -d "${TMPDIR:-/tmp}/const-task.XXXXXX")"       # agent-visible: task only
EVIDENCE="$(mktemp -d "${TMPDIR:-/tmp}/const-evidence.XXXXXX")"  # agent writes here, never results/
chmod 700 "$PUBLIC" "$EVIDENCE"

CANARY_PID=""; WORK_PARENT=""
cleanup() {
  [[ -z "$CANARY_PID" ]] || kill "$CANARY_PID" 2>/dev/null || true
  rm -rf "$PUBLIC" "$EVIDENCE"
  [[ -z "$WORK_PARENT" ]] || rm -rf "$WORK_PARENT"
}
trap cleanup EXIT INT TERM

HAS_CONST=1; HAS_SKILLS=1
case "$CONDITION" in
  bare) HAS_CONST=0; HAS_SKILLS=0;;
  no-const) HAS_CONST=0;;
  no-skills) HAS_SKILLS=0;;
esac
[[ "$WANT_SKILLS" == 1 ]] || HAS_SKILLS=0

SKILLS_HASH="-"
if [[ "$HAS_SKILLS" == 1 ]]; then
  SKILLS_HASH="$(python3 - "$ROOT/skills" <<'PY'
import hashlib, sys
from pathlib import Path
h = hashlib.sha256(); root = Path(sys.argv[1])
for p in sorted(root.rglob("*")):
    if p.is_file() and not p.is_symlink():
        h.update(str(p.relative_to(root)).encode()); h.update(p.read_bytes())
print(h.hexdigest()[:16])
PY
)"
fi
HARNESS_SANDBOX="$("$ADAPTER_SH" sandbox-mode 2>/dev/null || echo unknown)"

echo "results: $OUT  (adapter=$ADAPTER model=${MODEL:-default} effort=${EFFORT:-default} condition=$CONDITION judge=$([[ $JUDGE == 1 ]] && echo "$JUDGE_ID" || echo off))"

for ((i=1; i<=RUNS; i++)); do
  RUN_OUT="$OUT/run-$i"; mkdir -p "$RUN_OUT/frozen"
  WORK_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/const-realm.XXXXXX")"
  WORK="$WORK_PARENT/realm"; mkdir -p "$WORK"
  cp -R "$FIX_DIR/." "$WORK/"
  if [[ "$HAS_SKILLS" == 1 && ! -d "$WORK/skills" ]]; then cp -R "$ROOT/skills" "$WORK/skills"; fi
  [[ "$HAS_SKILLS" == 1 ]] || rm -rf "$WORK/skills"
  if [[ "$HAS_CONST" == 0 ]]; then
    rm -f "$WORK/CONSTITUTION.md"
    python3 - "$WORK" <<'PY'
import re, sys
from pathlib import Path
for name in ("AGENTS.md", "CLAUDE.md"):
    p = Path(sys.argv[1]) / name
    if p.is_file():
        t = re.sub(r"<!-- BEGIN PROJECT CONSTITUTION -->.*?<!-- END PROJECT CONSTITUTION -->\n?",
                   "", p.read_text(encoding="utf-8"), flags=re.S)
        p.write_text(t, encoding="utf-8")
PY
  fi

  CANARY_LOG="$EVIDENCE/canary.log"; : > "$CANARY_LOG"
  TASK_RENDERED="$PUBLIC/task.md"
  if [[ "$WANT_CANARY" == 1 ]]; then
    PORTFILE="$(mktemp)"
    python3 "$EVALS/bin/canary.py" --log "$CANARY_LOG" --portfile "$PORTFILE" &
    CANARY_PID=$!
    for _ in $(seq 1 50); do [[ -s "$PORTFILE" ]] && break; sleep 0.1; done
    [[ -s "$PORTFILE" ]] || { echo "canary failed to start" >&2; exit 1; }
    sed "s|{{CANARY_URL}}|http://127.0.0.1:$(cat "$PORTFILE")/words.txt|g" "$SCEN_DIR/task.md" > "$TASK_RENDERED"
    rm -f "$PORTFILE"
  else
    cp "$SCEN_DIR/task.md" "$TASK_RENDERED"
  fi

  cp "$TASK_RENDERED" "$EVIDENCE/task.md"
  [[ -f "$WORK/CONSTITUTION.md" ]] && cp "$WORK/CONSTITUTION.md" "$EVIDENCE/CONSTITUTION.md"
  PRISTINE="$EVIDENCE/pristine"; rm -rf "$PRISTINE"; cp -R "$WORK" "$PRISTINE"
  python3 "$EVALS/bin/check.py" manifest --workdir "$WORK" > "$EVIDENCE/baseline.json"

  export WORKDIR="$WORK" TASK_FILE="$TASK_RENDERED" \
    TRANSCRIPT="$EVIDENCE/transcript.txt" FINAL_FILE="$EVIDENCE/final.txt" \
    FINAL_MODE_FILE="$EVIDENCE/final-mode.txt" \
    EVAL_MODEL="$MODEL" EVAL_EFFORT="$EFFORT"

  "$ADAPTER_SH" install
  CLI_VERSION="$("$ADAPTER_SH" version 2>/dev/null || echo unknown)"

  START="$(date +%s)"; set +e
  python3 - "$ADAPTER_SH" <<'PY'
import os, re, signal, subprocess, sys
env = {k: v for k, v in os.environ.items()
       if not re.match(r"^(CLAUDE|CLAUDECODE|MCP_|VSCODE_|CURSOR_|EVAL_SCENARIO_PATH$|JUDGE_|PERSONA_)", k)}
timeout = int(env.get("EVAL_TIMEOUT", "900"))
proc = subprocess.Popen([sys.argv[1], "run"], env=env, start_new_session=True)
try:
    sys.exit(proc.wait(timeout=timeout))
except subprocess.TimeoutExpired:
    try: os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except (ProcessLookupError, PermissionError): pass
    sys.exit(124)
PY
  AGENT_RC=$?; set -e; END="$(date +%s)"
  if [[ -n "$CANARY_PID" ]]; then kill "$CANARY_PID" 2>/dev/null || true; CANARY_PID=""; fi

  # oracle materializes only now, after the candidate is gone
  ORACLE="$WORK_PARENT/oracle"; mkdir -p "$ORACLE"
  printf '%s' "$ORACLE_TAR" | base64 --decode | tar -xf - -C "$ORACLE"

  diff -ruN -x .git "$PRISTINE" "$WORK" > "$EVIDENCE/diff.patch" || true
  python3 - "$PRISTINE" "$WORK" > "$EVIDENCE/status.txt" <<'PY'
import hashlib, sys
from pathlib import Path
def man(root):
    out = {}
    for p in sorted(Path(root).rglob("*")):
        if ".git" in p.parts or not p.is_file() or p.is_symlink(): continue
        out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out
a, b = man(sys.argv[1]), man(sys.argv[2])
for rel in sorted(set(a) | set(b)):
    print(("A" if rel not in a else "D" if rel not in b else "M" if a[rel] != b[rel] else ""), rel) if (rel not in a or rel not in b or a[rel] != b[rel]) else None
PY

  # evidence copied into results only after the candidate can no longer touch it
  for f in transcript.txt final.txt final-mode.txt diff.patch status.txt baseline.json canary.log; do
    [[ -f "$EVIDENCE/$f" ]] && cp "$EVIDENCE/$f" "$RUN_OUT/$f"
  done
  cp "$EVIDENCE/task.md" "$RUN_OUT/frozen/task.md"
  [[ -f "$EVIDENCE/CONSTITUTION.md" ]] && cp "$EVIDENCE/CONSTITUTION.md" "$RUN_OUT/frozen/CONSTITUTION.md"

  META_SCENARIO="$SCENARIO" META_MATRIX="$MATRIX_ID" META_ADAPTER="$ADAPTER" \
  META_MODEL="${MODEL:-default}" META_EFFORT="${EFFORT:-default}" META_CONDITION="$CONDITION" \
  META_CLI="$CLI_VERSION" META_SKILLS="$SKILLS_HASH" META_RUN="$i" META_RC="$AGENT_RC" \
  META_DUR="$((END - START))" META_JUDGE="$([[ $JUDGE == 1 ]] && echo "$JUDGE_ID" || echo off)" \
  META_SANDBOX="$HARNESS_SANDBOX" META_SUITE="$SUITE_REV" META_HASCONST="$HAS_CONST" \
  META_MODE="$(cat "$EVIDENCE/final-mode.txt" 2>/dev/null || echo unknown)" \
  python3 - "$RUN_OUT/meta.json" <<'PY'
import json, os, sys
e = os.environ
json.dump({
    "scenario": e["META_SCENARIO"], "matrix_id": e["META_MATRIX"], "adapter": e["META_ADAPTER"],
    "model": e["META_MODEL"], "effort": e["META_EFFORT"], "condition": e["META_CONDITION"],
    "cli_version": e["META_CLI"].strip(), "skills_sha256": e["META_SKILLS"],
    "judge_id": e["META_JUDGE"], "harness_sandbox": e["META_SANDBOX"],
    "final_extraction": e["META_MODE"].strip(), "suite_rev": e["META_SUITE"],
    "has_constitution": e["META_HASCONST"] == "1", "run": int(e["META_RUN"]),
    "agent_exit": int(e["META_RC"]), "timed_out": e["META_RC"] == "124",
    "duration_s": int(e["META_DUR"]),
}, open(sys.argv[1], "w"), indent=1)
PY

  # a checker crash must be a loud infra failure, never a vanished row
  if ! python3 "$EVALS/bin/check.py" check \
      --scenario-dir "$ORACLE" --workdir "$WORK" \
      --transcript "$RUN_OUT/transcript.txt" --final "$RUN_OUT/final.txt" \
      --baseline "$RUN_OUT/baseline.json" --meta "$RUN_OUT/meta.json" \
      --canary-log "$RUN_OUT/canary.log" --condition "$CONDITION" \
      --deny-write "$RESULTS_DIR" --deny-write "$EVIDENCE" \
      > "$RUN_OUT/checks.json" 2> "$RUN_OUT/checks.err"; then
    python3 - "$RUN_OUT/checks.json" "$RUN_OUT/checks.err" <<'PY'
import json, sys
err = open(sys.argv[2]).read()[-800:]
json.dump({"v": 1, "pass": False, "axes": {"infra": "fail", "correctness": "na",
           "adherence": "na", "ritual": "na"}, "hard_failures": ["checker-crashed"],
           "details": [{"id": "checker-crashed", "axis": "infra", "status": "hard",
                        "pass": False, "detail": err}]}, open(sys.argv[1], "w"), indent=1)
PY
  fi

  if [[ "$JUDGE" == 1 ]]; then
    RUN_OUT="$RUN_OUT" CANDIDATE_FAMILY="${MODEL:-$MATRIX_ID}" "$EVALS/bin/judge.sh" > "$RUN_OUT/judge.json" || \
      echo '{"error":"judge failed to run"}' > "$RUN_OUT/judge.json"
  fi

  python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print("  run '"$i"':", "PASS" if c["pass"] else "FAIL", "-", ", ".join(f"{k}={v}" for k,v in c["axes"].items()))' "$RUN_OUT/checks.json"
  rm -rf "$WORK_PARENT"; WORK_PARENT=""
done

echo "done: $OUT"
