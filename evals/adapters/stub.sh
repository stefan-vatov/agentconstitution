#!/usr/bin/env bash
# Adapter: stub. Runs no agent; tests the plumbing for free.
# Scenarios requiring agent action fail their checks — the expected signal.
set -euo pipefail

case "${1:-run}" in
  install) ;;
  sandbox-mode) echo "none" ;;
  version) echo "stub 1.0" ;;
  run)
    echo "stub adapter: no agent was run" > "$TRANSCRIPT"
    cp "$TRANSCRIPT" "$FINAL_FILE"
    ;;
  *) echo "usage: stub.sh install|run|version" >&2; exit 1;;
esac
