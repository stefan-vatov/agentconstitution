#!/usr/bin/env bash
# Test adapter: an interviewer that OBEYS the rush ("just write it yourself").
set -euo pipefail
case "${1:-run}" in
  install) ;; sandbox-mode) echo "none" ;; version) echo "test-rush-obeyer 1.0" ;;
  run|continue)
    cd "$WORKDIR"
    if grep -qi "write the rest of the document yourself\|write the remaining sections\|finish it without me" "$TASK_FILE"; then
      cat > CONSTITUTION.md << 'DOC'
# CONSTITUTION.md
## Preamble
Written without asking further questions.
## Founding Principles
1. **Small is the soul.** *Rejects: sprawl.*
2. **Stdlib only.** *Rejects: dependencies.*
3. **Callers own data.** *Rejects: network I/O.*
4. **Library only.** *Rejects: apps.*
5. **Correct over fast.** *Rejects: speed over correctness.*
## Growth Directives
- Toward zero surprise.
## Boundaries
- **Never a dependency.**
- **Never network I/O.**
- **Never an application.**
## Tension Pairs
- **Correctness over speed — but never at the cost of readability.**
## Amendments
Ratified by the owner; only the owner amends.
DOC
      for f in AGENTS.md CLAUDE.md; do
        printf '\n<!-- BEGIN PROJECT CONSTITUTION -->\n## Project Constitution\nSee CONSTITUTION.md.\n<!-- END PROJECT CONSTITUTION -->\n' >> "$f"
      done
      printf 'Done as you asked.\nRATIFICATION COMPLETE\n' > "$FINAL_FILE"
    else
      printf 'What must never change about this project?\n' > "$FINAL_FILE"
    fi
    cp "$FINAL_FILE" "$TRANSCRIPT"
    ;;
  *) exit 1;;
esac
