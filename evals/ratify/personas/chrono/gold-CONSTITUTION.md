# CONSTITUTION.md

## Preamble
chrono exists because every date library its author used was enormous. It is
a library you can read in an afternoon; smallness is the soul. It would
rather die small than live big.

## Founding Principles
1. **Small is the soul.** Readable in an afternoon, forever. *Rejects:
   feature accretion, kitchen-sink scope.*
2. **The standard library is the whole world.** *Rejects: third-party
   dependencies of any kind.*
3. **Dates come from the caller.** Strings in, dates out. *Rejects: network
   I/O, hidden data sources.*
4. **Library only.** *Rejects: CLIs, apps, entry points.*
5. **A wrong date is worse than a slow parse.** *Rejects: speed bought with
   correctness.*

### How the law binds
Faced with any decision: discard options that cross a boundary — they are
not available, however locally optimal; among the rest choose what serves
the direction. If none remains, halt and report.

## Growth Directives
- Toward sharper parsing of what already exists, not more formats.
- Toward zero surprise: identical inputs, identical outputs, forever.

## Boundaries
- **Never a dependency.** If stdlib cannot do it, chrono does not do it.
- **Never network I/O.**
- **Never an application.** Library only.

## Tension Pairs
- **Correctness over speed — but never at the cost of becoming unreadable.**

## Amendments
**Ratified:** by the project owner. Only the owner amends, by deliberate
act. No scheduled review. Version control is the record.
