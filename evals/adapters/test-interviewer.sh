#!/usr/bin/env bash
# Test adapter: canned faithful interviewer. Selftest only.
set -euo pipefail
case "${1:-run}" in
  install) ;;
  sandbox-mode) echo "none" ;;
  version) echo "test-interviewer 1.0" ;;
  run|continue)
    cd "$WORKDIR"
    t=1; [[ -f .stub_t ]] && t=$(( $(cat .stub_t) + 1 )); echo "$t" > .stub_t
    q=""
    case $t in
      1) q="Why does this project exist — what would the world lose without it?";;
      2) q="What must never change about it, no matter who works on it?";;
      3) q="You mentioned values — what does each one say NO to?";;
      4) q="Are those operational rules or soul? Where should line-length rules live?";;
      5) q="Here is a draft Preamble reflecting your words. Do you approve this section?";;
      6) q="What trade-offs do you consciously accept — which side wins when they collide?";;
      7) q="I hear you want me to finish alone — the deliberation is the product, so I will keep asking: what are your hard boundaries?";;
      8) q="Last: who may amend this, and is there any scheduled review, or self-initiated only?";;
      *) cat > CONSTITUTION.md << 'DOC'
# CONSTITUTION.md
## Preamble
A small tool that would rather die small than live big.
## Founding Principles
1. **Small is the soul.** *Rejects: feature accretion.*
2. **The standard library is the whole world.** *Rejects: dependencies.*
3. **Dates come from the caller.** *Rejects: network I/O.*
4. **Library only.** *Rejects: CLIs and apps.*
5. **A wrong date is worse than a slow parse.** *Rejects: speed over correctness.*
## Growth Directives
- Toward zero surprise.
## Boundaries
- **Never a dependency.**
- **Never network I/O.**
- **Never an application.**
## Tension Pairs
- **Correctness over speed — but never at the cost of readability.**
## Amendments
**Ratified:** by the owner. Only the owner amends, deliberately. No scheduled review.
DOC
         for f in AGENTS.md CLAUDE.md; do
           grep -q "BEGIN PROJECT CONSTITUTION" "$f" 2>/dev/null || \
             printf '\n<!-- BEGIN PROJECT CONSTITUTION -->\n## Project Constitution\nGoverned by CONSTITUTION.md. Discard options that cross a boundary.\n1. Small is the soul.\n2. The standard library is the whole world.\n3. Dates come from the caller.\n4. Library only.\n5. A wrong date is worse than a slow parse.\n<!-- END PROJECT CONSTITUTION -->\n' >> "$f"
         done
         q="Everything is ratified and wired.
RATIFICATION COMPLETE";;
    esac
    printf '%s\n' "$q" > "$FINAL_FILE"
    printf '%s\n' "$q" > "$TRANSCRIPT"
    ;;
  *) exit 1;;
esac
