#!/usr/bin/env bash
# Adapter: Kimi CLI. Env: WORKDIR TASK_FILE TRANSCRIPT FINAL_FILE FINAL_MODE_FILE
# EVAL_MODEL EVAL_EFFORT SESSION_FILE. Subcommands: install run continue version sandbox-mode.
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd -P)"

finalize() {
  python3 "$BIN/extract-final.py" --transcript "$TRANSCRIPT" --out "$FINAL_FILE" \
    --mode-out "${FINAL_MODE_FILE:-/dev/null}" --format text
}

case "${1:-run}" in
  install) ;;
  version) kimi --version 2>/dev/null || echo "kimi (unknown)" ;;
  sandbox-mode) echo "none" ;;
  run)
    cd "$WORKDIR"
    prompt="$(cat "$TASK_FILE")"
    [[ -z "${EVAL_EFFORT:-}" ]] || { echo "kimi adapter does not support --effort" >&2; exit 2; }
    args=(--auto -p "$prompt")
    [[ -z "${EVAL_MODEL:-}" ]] || args+=(-m "$EVAL_MODEL")
    rc=0; kimi "${args[@]}" </dev/null > "$TRANSCRIPT" 2>&1 || rc=$?
    finalize || rc=${rc:-0}
    if [[ $rc -eq 0 && ! -s "$FINAL_FILE" ]]; then rc=3; fi
    exit $rc
    ;;
  continue)
    cd "$WORKDIR"
    prompt="$(cat "$TASK_FILE")"
    args=(--auto -c -p "$prompt")
    [[ -z "${EVAL_MODEL:-}" ]] || args+=(-m "$EVAL_MODEL")
    rc=0; kimi "${args[@]}" </dev/null > "$TRANSCRIPT" 2>&1 || rc=$?
    finalize || rc=${rc:-0}
    if [[ $rc -eq 0 && ! -s "$FINAL_FILE" ]]; then rc=3; fi
    exit $rc
    ;;
  *) echo "usage: kimi.sh install|run|continue|version|sandbox-mode" >&2; exit 1;;
esac
