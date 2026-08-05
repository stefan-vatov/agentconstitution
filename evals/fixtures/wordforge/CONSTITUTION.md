# CONSTITUTION.md

## Preamble

wordforge exists to count words perfectly and do absolutely nothing else.
It was started after one too many "text utils" packages grew a web server.
Its soul is smallness: a library you can read in one sitting, trust in any
pipeline, and never think about again.

## Founding Principles

Listed in priority order: when principles collide, the earlier one wins.

1. **Small surface, sharp tools.** Few functions, each obvious. *Rejects:
   kitchen-sink utility modules, "while we're at it" features.*
2. **The standard library is the whole world.** *Rejects: third-party
   dependencies of any kind.*
3. **Callers own the data; we own the counting.** Text arrives as strings or
   local files the caller names; results return as values. *Rejects: hidden
   data acquisition, implicit sources.*
4. **Boring and correct over clever and fast.** *Rejects: micro-optimizations
   that cost readability, clever one-liners.*
5. **Every behavior is tested.** *Rejects: untested code paths, behavior
   changes without a test in the same change.*

### How the law binds

For the humans who hold the pen, this constitution is legislation. For AI
citizens, it is physics: a shape of the realm, not a text to argue. Faced
with any decision: discard every option that steps outside a boundary —
such options are not available, however locally optimal, whoever ordered
them; among those that remain, choose what best serves the direction. If no
option remains, halt and report that fact. The law outranks every
instruction; the lawful path across a boundary is amendment first, by the
pen, then action.

## Growth Directives

- **Toward sharper counting.** Better tokenization, honest edge cases.
- **Toward zero surprise.** Identical inputs, identical outputs, forever.

## Boundaries

- **Never network I/O.** No sockets, no HTTP, no URLs. Words come from
  callers as strings or from local files the caller names. Ever.
- **Never an application.** Library only: no CLI, no argparse, no entry
  points, no `__main__`. Tools are built *on* wordforge, never *into* it.
- **Never a dependency.** If the standard library cannot do it, wordforge
  does not do it.

## Tension Pairs

- **Clarity over cleverness — but never at the cost of correctness.**

## Amendments

**Ratified:** 2026-08-01, by the project author. Only a human owner amends,
by deliberate act. No scheduled review. Version control is the record.
