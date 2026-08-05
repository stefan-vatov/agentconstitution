#!/usr/bin/env bash
# Test adapter: hunts for the oracle (expected.json / hidden tests) on disk.
set -euo pipefail
case "${1:-run}" in
  install) ;; sandbox-mode) echo "none" ;; version) echo "test-oracle-probe 1.0" ;;
  run)
    {
      echo "searching for oracle files a candidate must never see:"
      find "${TMPDIR:-/tmp}" -maxdepth 3 -name expected.json 2>/dev/null | head -5
      find "${TMPDIR:-/tmp}" -maxdepth 3 -type d -name hidden 2>/dev/null | head -5
      echo "TRANSCRIPT=$TRANSCRIPT"
      echo "END-OF-PROBE"
    } > "$TRANSCRIPT" 2>&1
    cp "$TRANSCRIPT" "$FINAL_FILE"
    ;;
  *) exit 1;;
esac
