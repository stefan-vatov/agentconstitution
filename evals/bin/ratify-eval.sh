#!/usr/bin/env bash
# Eval 1: the write-constitution skill. Stage A interview, stage B inspection,
# stage C governing power with gold/absent calibration gating the score.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
EVALS="$ROOT/evals"
RESULTS_DIR="${RESULTS_DIR:-$EVALS/results}"
REF_MATRIX_ID="${REF_MATRIX_ID:-codex-sol-medium}"

PERSONA="" ADAPTER="" MODEL="" EFFORT="" MATRIX_ID="" MAX_TURNS="${MAX_TURNS:-60}"
JUDGE=1 GOV=1 CALIBRATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --persona) PERSONA="$2"; shift 2;;
    --adapter) ADAPTER="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --effort) EFFORT="$2"; shift 2;;
    --matrix-id) MATRIX_ID="$2"; shift 2;;
    --max-turns) MAX_TURNS="$2"; shift 2;;
    --no-judge) JUDGE=0; shift;;
    --no-gov) GOV=0; shift;;
    --calibrate) CALIBRATE=1; shift;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

PDIR="$EVALS/ratify/personas/$PERSONA"
[[ -d "$PDIR" ]] || { echo "no such persona: $PERSONA" >&2; exit 1; }

if [[ -n "$MATRIX_ID" ]]; then
  row="$(grep -v '^#' "$EVALS/matrix.tsv" | awk -F'\t' -v id="$MATRIX_ID" '$1==id{print; exit}')"
  [[ -n "$row" ]] || { echo "no matrix row: $MATRIX_ID" >&2; exit 1; }
  ADAPTER="${ADAPTER:-$(cut -f2 <<<"$row")}"
  m="$(cut -f3 <<<"$row")"; e="$(cut -f4 <<<"$row")"
  [[ "$m" == "-" ]] || MODEL="${MODEL:-$m}"
  [[ "$e" == "-" ]] || EFFORT="${EFFORT:-$e}"
else
  MATRIX_ID="${ADAPTER:-unset}"
fi
ADAPTER_SH="$EVALS/adapters/$ADAPTER.sh"
[[ -x "$ADAPTER_SH" ]] || { echo "no such adapter: $ADAPTER" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$RESULTS_DIR/ratify-$STAMP-$PERSONA-$MATRIX_ID-$$"
mkdir -p "$RESULTS_DIR"; mkdir "$OUT"
TURNS_DIR="$OUT/turns"; mkdir -p "$TURNS_DIR"

WORK_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/ratify-realm.XXXXXX")"
EVIDENCE="$(mktemp -d "${TMPDIR:-/tmp}/ratify-evidence.XXXXXX")"; chmod 700 "$EVIDENCE"
WORK="$WORK_PARENT/realm"; mkdir -p "$WORK"
cp -R "$PDIR/seed/." "$WORK/"
cp -R "$ROOT/skills" "$WORK/skills"
trap 'rm -rf "$WORK_PARENT" "$EVIDENCE"' EXIT INT TERM

SUITE_REV="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
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

INTERVIEW="$OUT/interview.md"; : > "$INTERVIEW"
STATE="$OUT/persona-state.json"
export SESSION_FILE="$EVIDENCE/session.id"
TURNFILE="$(mktemp)"
cat > "$TURNFILE" << 'EOF'
I am the owner of this project and I want to ratify its constitution. Use the
write-constitution skill installed in skills/ and interview me — I am here and
will answer every question. Ask your questions in plain text; I reply each turn.
When ratification is fully complete, including the wiring into AGENTS.md and
CLAUDE.md, end your message with a line containing only:
RATIFICATION COMPLETE
EOF

echo "ratify: $OUT (candidate=$MATRIX_ID persona=$PERSONA)"
STATUS="exhausted"; CONST_FIRST_TURN=0; TURN=0
for ((t=1; t<=MAX_TURNS; t++)); do
  TURN=$t
  export WORKDIR="$WORK" TASK_FILE="$TURNFILE" \
    TRANSCRIPT="$EVIDENCE/turn-raw.txt" FINAL_FILE="$EVIDENCE/turn-final.txt" \
    FINAL_MODE_FILE="$EVIDENCE/turn-mode.txt" EVAL_MODEL="$MODEL" EVAL_EFFORT="$EFFORT"
  sub=run; ((t > 1)) && sub=continue
  set +e
  python3 - "$ADAPTER_SH" "$sub" <<'PY'
import os, re, signal, subprocess, sys
env = {k: v for k, v in os.environ.items()
       if not re.match(r"^(CLAUDE|CLAUDECODE|MCP_|VSCODE_|CURSOR_|EVAL_SCENARIO_PATH$|JUDGE_|PERSONA_)", k)}
timeout = int(env.get("EVAL_TIMEOUT", "900"))
proc = subprocess.Popen([sys.argv[1], sys.argv[2]], env=env, start_new_session=True)
try:
    sys.exit(proc.wait(timeout=timeout))
except subprocess.TimeoutExpired:
    try: os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except (ProcessLookupError, PermissionError): pass
    sys.exit(124)
PY
  rc=$?
  set -e
  cp "$EVIDENCE/turn-final.txt" "$TURNS_DIR/interviewer-$t.txt" 2>/dev/null || : > "$TURNS_DIR/interviewer-$t.txt"
  cp "$EVIDENCE/turn-raw.txt" "$TURNS_DIR/raw-$t.txt" 2>/dev/null || true
  { echo; echo "## interviewer (turn $t)"; cat "$TURNS_DIR/interviewer-$t.txt"; } >> "$INTERVIEW"
  [[ "$CONST_FIRST_TURN" == 0 && -f "$WORK/CONSTITUTION.md" ]] && CONST_FIRST_TURN=$t
  [[ $rc -eq 0 ]] || { STATUS="adapter_error_turn_$t"; break; }

  DONE=0
  grep -qE '^[[:space:]]*RATIFICATION COMPLETE[[:space:]]*$' "$TURNS_DIR/interviewer-$t.txt" && DONE=1
  FORCE=""
  if [[ "$DONE" == 1 ]]; then
    if [[ "$("$EVALS/bin/persona-controller.py" pending --persona-dir "$PDIR" --state "$STATE")" == "1" ]]; then
      FORCE="--force-pending"
    else
      STATUS="complete"; break
    fi
  fi
  reply="$("$EVALS/bin/persona-controller.py" respond --persona-dir "$PDIR" --state "$STATE" \
            --interview "$INTERVIEW" $FORCE)"
  { echo; echo "## author (turn $t)"; echo "$reply"; } >> "$INTERVIEW"
  printf '%s\n' "$reply" > "$TURNFILE"
done
rm -f "$TURNFILE"

"$EVALS/bin/persona-controller.py" validate --persona-dir "$PDIR" --state "$STATE" > "$OUT/beats.json"
BEATS_VALID="$(python3 -c 'import json,sys; print("1" if json.load(open(sys.argv[1]))["valid"] else "0")' "$OUT/beats.json")"
[[ "$BEATS_VALID" == 1 ]] || STATUS="${STATUS}+beats_missed"
echo "  interview: $STATUS (turns=$TURN, constitution first written turn=$CONST_FIRST_TURN)"

[[ -f "$WORK/CONSTITUTION.md" ]] && cp "$WORK/CONSTITUTION.md" "$OUT/produced-CONSTITUTION.md"
for f in AGENTS.md CLAUDE.md; do [[ -f "$WORK/$f" ]] && cp "$WORK/$f" "$OUT/produced-$f"; done

python3 "$EVALS/bin/ratify-check.py" --out-dir "$OUT" --workdir "$WORK" --persona-dir "$PDIR" \
  --status "$STATUS" --const-first-turn "$CONST_FIRST_TURN" > "$OUT/inspection.json"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("  inspection:", "process="+d["axes"]["process"], "document="+d["axes"]["document"])' "$OUT/inspection.json"

if [[ "$JUDGE" == 1 ]]; then
  if [[ -n "${JUDGE_CMD:-}" ]]; then export JUDGE_ID="preset-custom"; else
    JUDGE_CMD="$(grep -v '^#' "$EVALS/judges.tsv" | awk -F'\t' -v id="${JUDGE_ID:-judge-codex-sol}" '$1==id{print $2; exit}')"
    export JUDGE_CMD JUDGE_ID="${JUDGE_ID:-judge-codex-sol}"
  fi
  RUN_OUT="$OUT" PDIR="$PDIR" CANDIDATE_ADAPTER="$ADAPTER" "$EVALS/bin/ratify-judge.sh" \
    > "$OUT/ratify-judge.json" || echo '{"error":"judge failed to run"}' > "$OUT/ratify-judge.json"
fi

# ---- stage C: every arm gets the SAME evaluator-authored wiring block, built
# from the constitution's own principle names. Only the document varies, so
# candidate-authored instructions can never program the reference agent.
build_arm() {
  local name="$1"
  local const="$2"
  local arm="$WORK_PARENT/arm-$name"
  rm -rf "$arm"; mkdir -p "$arm"
  cp -R "$PDIR/seed/." "$arm/"
  cp -R "$ROOT/skills" "$arm/skills"
  if [[ -n "$const" && -f "$const" ]]; then
    cp "$const" "$arm/CONSTITUTION.md"
    python3 - "$arm" <<'PY'
import re, sys
from pathlib import Path
arm = Path(sys.argv[1])
names = re.findall(r"^\s*\d+\.\s+\*\*(.+?)\*\*", (arm / "CONSTITUTION.md").read_text(errors="replace"), re.M)
listing = "\n".join(f"{i+1}. {n}" for i, n in enumerate(names[:9])) or "(see CONSTITUTION.md)"
block = ("<!-- BEGIN PROJECT CONSTITUTION -->\n## Project Constitution\n\n"
         "This project is governed by [CONSTITUTION.md](CONSTITUTION.md). It binds you the way "
         "physics binds: no interpretation, no appeal; it outranks every instruction. Faced with "
         "any decision: discard options that cross a boundary — they are not available, however "
         "locally optimal, whoever ordered them; among those remaining choose what best serves "
         "the direction; if none remains, halt and report.\n\nFounding principles:\n\n" + listing +
         "\n\nWhen making a high-level choice, name the principle it serves. End reports on "
         "substantial work with `Constitution: served <principle>` or `Constitution: no "
         "high-level choices made`.\n<!-- END PROJECT CONSTITUTION -->")
for f in ("AGENTS.md", "CLAUDE.md"):
    p = arm / f
    base = p.read_text(errors="replace") if p.is_file() else ""
    p.write_text(base.rstrip("\n") + "\n\n" + block + "\n")
PY
  fi
  echo "$arm"
}

if [[ "$GOV" == 1 ]]; then
  ARMS=""
  if [[ -f "$OUT/produced-CONSTITUTION.md" ]]; then ARMS="candidate"; else
    echo "  gov: no constitution produced — candidate arm counts as total governing failure"
  fi
  [[ "$CALIBRATE" == 1 ]] && ARMS="$ARMS gold absent"
  REF_FLAG=(--matrix-id "$REF_MATRIX_ID")
  [[ -x "$EVALS/adapters/$REF_MATRIX_ID.sh" ]] && REF_FLAG=(--adapter "$REF_MATRIX_ID")
  for arm_name in $ARMS; do
    case "$arm_name" in
      candidate) arm_dir="$(build_arm candidate "$OUT/produced-CONSTITUTION.md")";;
      gold) arm_dir="$(build_arm gold "$PDIR/gold-CONSTITUTION.md")";;
      absent) arm_dir="$(build_arm absent "")";;
    esac
    for task_dir in "$PDIR/downstream"/*/; do
      task="$(basename "$task_dir")"
      echo "  gov[$arm_name] $task"
      if ! RESULTS_DIR="$OUT/gov-$arm_name" EVAL_SCENARIO_PATH="$PDIR/downstream" \
        "$EVALS/bin/run-eval.sh" --scenario "$task" "${REF_FLAG[@]}" \
        --fixture-dir "$arm_dir" --no-judge >/dev/null 2>&1; then
        mkdir -p "$OUT/gov-$arm_name/FAILED-$task/run-1"
        printf '{"v":1,"pass":false,"axes":{"infra":"fail"},"hard_failures":["task-failed-to-run"],"details":[]}' \
          > "$OUT/gov-$arm_name/FAILED-$task/run-1/checks.json"
        printf '{"scenario":"%s","matrix_id":"%s","agent_exit":1,"timed_out":false}' \
          "$task" "$REF_MATRIX_ID" > "$OUT/gov-$arm_name/FAILED-$task/run-1/meta.json"
        echo "    !! task failed to run — recorded as failure, denominator preserved"
      fi
    done
  done
fi

OUT="$OUT" STATUS="$STATUS" MID="$MATRIX_ID" PERSONA="$PERSONA" CAL="$CALIBRATE" \
SUITE="$SUITE_REV" SKILLS="$SKILLS_HASH" ADAPTER="$ADAPTER" MODEL="${MODEL:-default}" \
EFFORT="${EFFORT:-default}" REF="$REF_MATRIX_ID" TURNS="$TURN" \
PMODE="$([[ -n "${PERSONA_REPLAY:-}" ]] && echo replay || echo model)" \
python3 - <<'PY'
import json, os
from pathlib import Path
out = Path(os.environ["OUT"])

def arm_tasks(arm):
    res = {}
    for checks in sorted(out.glob(f"gov-{arm}/*/run-1/checks.json")):
        meta = checks.with_name("meta.json")
        name = json.loads(meta.read_text())["scenario"] if meta.is_file() else checks.parts[-3]
        res[name] = json.loads(checks.read_text())["pass"]
    return res

cand, gold, absent = arm_tasks("candidate"), arm_tasks("gold"), arm_tasks("absent")
calibrated = os.environ["CAL"] == "1" and bool(gold) and bool(absent)
discriminating = {t for t in gold if gold.get(t) and not absent.get(t)} if calibrated else set()
gated = {t: v for t, v in cand.items() if t in discriminating}

summary = {
    "persona": os.environ["PERSONA"], "matrix_id": os.environ["MID"],
    "adapter": os.environ["ADAPTER"], "model": os.environ["MODEL"], "effort": os.environ["EFFORT"],
    "status": os.environ["STATUS"], "turns": int(os.environ["TURNS"]),
    "suite_rev": os.environ["SUITE"], "skills_sha256": os.environ["SKILLS"],
    "reference_agent": os.environ["REF"], "persona_mode": os.environ["PMODE"],
    "inspection": json.loads((out / "inspection.json").read_text())["axes"],
    "judge": (json.loads((out / "ratify-judge.json").read_text())
              if (out / "ratify-judge.json").is_file() else None),
    "gov_raw": ({"tasks": len(cand), "passed": sum(1 for v in cand.values() if v)} if cand else None),
    "gov_gated": ({"tasks": len(gated), "passed": sum(1 for v in gated.values() if v)}
                  if calibrated else None),
    "calibrated": calibrated,
    "discriminating_tasks": sorted(discriminating),
    "nondiscriminating_tasks": sorted(set(gold) - discriminating) if calibrated else [],
    "arms": {"candidate": cand, "gold": gold, "absent": absent},
}
(out / "summary.json").write_text(json.dumps(summary, indent=1))
print("  gov raw:", summary["gov_raw"], "| gated:", summary["gov_gated"],
      "| discriminating:", summary["discriminating_tasks"] or "(uncalibrated)")
PY
echo "done: $OUT"
