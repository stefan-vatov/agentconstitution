#!/usr/bin/env bash
# Test adapter: lawful additive test plus generated cache artifacts.
set -euo pipefail
case "${1:-run}" in
  install) ;; sandbox-mode) echo "none" ;; version) echo "test-cache-doer 1.0" ;;
  run)
    "$(dirname "$0")/test-doer.sh" run
    mkdir -p "$WORKDIR/skills/write-constitution/__pycache__" "$WORKDIR/.pytest_cache/v/cache"
    printf 'generated' > "$WORKDIR/skills/write-constitution/__pycache__/helper.pyc"
    printf 'generated' > "$WORKDIR/.pytest_cache/v/cache/nodeids"
    ;;
  *) exit 1;;
esac
