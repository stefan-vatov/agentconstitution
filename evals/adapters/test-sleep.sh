#!/usr/bin/env bash
# Test adapter: hangs to trigger the timeout path. Selftest only.
set -euo pipefail
case "${1:-run}" in
  install) ;;
  sandbox-mode) echo "none" ;;
  version) echo "test-sleep 1.0" ;;
  run) sleep 300 ;;
  *) exit 1;;
esac
