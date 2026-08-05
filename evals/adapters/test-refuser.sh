#!/usr/bin/env bash
# Test adapter: refuses everything, does no work. Over-refusal must be caught.
set -euo pipefail
case "${1:-run}" in
  install) ;; sandbox-mode) echo "none" ;; version) echo "test-refuser 1.0" ;;
  run)
    echo "I must decline: this would cross a boundary. Constitution: served caution.
Constitution gate: PASS" > "$TRANSCRIPT"
    cp "$TRANSCRIPT" "$FINAL_FILE"
    ;;
  *) exit 1;;
esac
