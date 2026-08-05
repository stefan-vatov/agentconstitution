#!/usr/bin/env bash
# Adapter: OpenAI Codex CLI. Env: WORKDIR TASK_FILE TRANSCRIPT FINAL_FILE FINAL_MODE_FILE
# EVAL_MODEL EVAL_EFFORT SESSION_FILE. Subcommands: install run continue version sandbox-mode.
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd -P)"

finalize() {
  python3 "$BIN/extract-final.py" --transcript "$TRANSCRIPT" --out "$FINAL_FILE" \
    --mode-out "${FINAL_MODE_FILE:-/dev/null}" --format codex
}

case "${1:-run}" in
  install) ;;
  version) codex --version ;;
  sandbox-mode) echo "harness" ;;
  run)
    cd "$WORKDIR"
    prompt="$(cat "$TASK_FILE")"
    args=(exec --json --skip-git-repo-check --sandbox workspace-write)
    [[ -z "${EVAL_MODEL:-}" ]] || args+=(-m "$EVAL_MODEL")
    [[ -z "${EVAL_EFFORT:-}" ]] || args+=(-c "model_reasoning_effort=\"$EVAL_EFFORT\"")
    rc=0; codex "${args[@]}" "$prompt" </dev/null > "$TRANSCRIPT" 2>&1 || rc=$?
    if [[ -n "${SESSION_FILE:-}" ]]; then
      grep -o '"thread_id":"[^"]*"' "$TRANSCRIPT" | head -1 | cut -d'"' -f4 > "$SESSION_FILE" || true
    fi
    finalize || rc=${rc:-0}
    if [[ $rc -eq 0 && ! -s "$FINAL_FILE" ]]; then rc=3; fi
    exit $rc
    ;;
  continue)
    cd "$WORKDIR"
    prompt="$(cat "$TASK_FILE")"
    sid="$(cat "$SESSION_FILE" 2>/dev/null || true)"
    [[ -n "$sid" ]] || { echo "no session id" >&2; exit 2; }
    # resume accepts only --json/--skip-git-repo-check; model+effort+sandbox persist
    rc=0; codex exec resume "$sid" --json --skip-git-repo-check "$prompt" </dev/null > "$TRANSCRIPT" 2>&1 || rc=$?
    finalize || rc=${rc:-0}
    if [[ $rc -eq 0 && ! -s "$FINAL_FILE" ]]; then rc=3; fi
    exit $rc
    ;;
  *) echo "usage: codex.sh install|run|continue|version|sandbox-mode" >&2; exit 1;;
esac
