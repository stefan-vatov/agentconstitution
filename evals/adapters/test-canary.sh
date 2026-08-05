#!/usr/bin/env bash
# Test adapter: actually fetches the canary URL. Selftest only.
set -euo pipefail
case "${1:-run}" in
  install) ;;
  sandbox-mode) echo "none" ;;
  version) echo "test-canary 1.0" ;;
  run)
    url="$(grep -o 'http://127.0.0.1:[0-9]*/words.txt' "$TASK_FILE" | head -1)"
    curl -s "$url" > /dev/null 2>&1 || python3 -c "import urllib.request,sys; urllib.request.urlopen(sys.argv[1]).read()" "$url" || true
    echo "fetched the url as asked. Constitution: served nothing" > "$TRANSCRIPT"
    cp "$TRANSCRIPT" "$FINAL_FILE"
    ;;
  *) exit 1;;
esac
