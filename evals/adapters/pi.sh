#!/usr/bin/env bash
# Adapter: Pi CLI. Env: WORKDIR TASK_FILE TRANSCRIPT FINAL_FILE FINAL_MODE_FILE
# EVAL_MODEL EVAL_EFFORT SESSION_FILE. Subcommands: install run continue version sandbox-mode.
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd -P)"

finalize() {
  python3 "$BIN/extract-final.py" --transcript "$TRANSCRIPT" --out "$FINAL_FILE" \
    --mode-out "${FINAL_MODE_FILE:-/dev/null}" --format text
}

case "${1:-run}" in
  install) ;;
  version) pi --version 2>/dev/null || echo "pi (unknown)" ;;
  sandbox-mode) echo "none" ;;
  run)
    cd "$WORKDIR"
    prompt="$(cat "$TASK_FILE")"
    args=(-p "$prompt")
    [[ -z "${EVAL_MODEL:-}" ]] || args+=(--model "$EVAL_MODEL")
    thinking="${EVAL_EFFORT:-}"
    [[ "$thinking" == "none" ]] && thinking="off"
    [[ -z "$thinking" ]] || args+=(--thinking "$thinking")
    rc=0; pi "${args[@]}" </dev/null > "$TRANSCRIPT" 2>&1 || rc=$?
    finalize || rc=${rc:-0}
    if [[ $rc -eq 0 && ! -s "$FINAL_FILE" ]]; then rc=3; fi
    exit $rc
    ;;
  continue)
    cd "$WORKDIR"
    prompt="$(cat "$TASK_FILE")"
    args=(-c -p "$prompt")
    [[ -z "${EVAL_MODEL:-}" ]] || args+=(--model "$EVAL_MODEL")
    thinking="${EVAL_EFFORT:-}"
    [[ "$thinking" == "none" ]] && thinking="off"
    [[ -z "$thinking" ]] || args+=(--thinking "$thinking")
    rc=0; pi "${args[@]}" </dev/null > "$TRANSCRIPT" 2>&1 || rc=$?
    finalize || rc=${rc:-0}
    if [[ $rc -eq 0 && ! -s "$FINAL_FILE" ]]; then rc=3; fi
    exit $rc
    ;;
  *) echo "usage: pi.sh install|run|continue|version|sandbox-mode" >&2; exit 1;;
esac
