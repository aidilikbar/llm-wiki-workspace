---
status: active
updated: 2026-10-29
owner: TODO
classification: public
type: data
supersedes:
---

# 0011 — The icebox lives in `record/`, as the one folder an item may leave

## Context

Decision 0009 split the icebox into one file per item under `state/icebox/`. But `state/`
is the zone for what is current, with a 7-day staleness rule, and an iced item is by
definition not current: it sits untouched for weeks or months. In `state/`, every iced
item would be flagged as stale for as long as it stayed iced — noise that teaches agents
to ignore the staleness flag.

## Options considered

### A — `record/icebox/`, with thawing as an explicit exception to append-only
Trade-off: costs the purity of `record/` — one folder whose files can move out. Buys an
icebox in the zone whose trust model matches it: not current, not edited, kept.

### B — Keep `state/icebox/`, exempt it from the staleness rule
Trade-off: costs an exception inside the freshness rule instead, and leaves non-current
items in the zone that means current.

### C — Both: `state/icebox/` for recently iced, `record/icebox/` for long-term
Trade-off: costs two iceboxes and a boundary between them that nobody will maintain.

## Decision

A, decided by the owner. Iced items move to `record/icebox/` and are not edited while
there. Thawing moves the file back to `state/backlog/`, and only on the human's say-so —
which the escalation matrix already requires, since it lists removing a `record/` entry
as must-escalate.

## Rejected, and why

- **B** — rejected because it puts the exception in the rule that every other `state/`
  file depends on. An exemption in the freshness rule is easier to over-apply than a
  named exception for one folder.
- **C** — rejected because two locations for the same kind of item is the failure 0008
  already rejected for `analysis/` and `research/`.

## Consequences

Easier: `state/` holds only current things, so the staleness flag stays meaningful.

Harder: `record/` is no longer strictly append-only. The exception is stated in three
places — `system/RULES.md` §3, `record/AGENTS.md` and the icebox template — and is
limited to a move back to `state/backlog/`, never an edit in place.

## Revisit if

Any other `record/` folder acquires a reason for files to leave it. Two exceptions would
mean the zone's rule has changed, and that should be its own decision.
