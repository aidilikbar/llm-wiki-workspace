---
status: active
updated: 2026-09-11
owner: <human owner>
classification: public
type: architecture
supersedes:
---

# 0001 — The tree is organised by mutability, not by topic

## Context

An agent opening this repository has to answer three questions before it can work: what
here is current, what may I change, and what is already settled. A conventional wiki
answers none of them from structure alone — it answers "what is this about". The
directory an agent lands in had to carry the freshness and permission signal, because
that is the signal the agent reads first and the one it reads for free. What we did not
know at the time: whether humans would tolerate a tree that splits related material
across four directories.

## Options considered

### A — Four zones by mutability: `context/`, `state/`, `record/`, `work/`
Trade-off: costs human familiarity — material about one subject is split across zones,
and a newcomer has to learn the vocabulary before finding anything. Buys a trust and
permission signal on every path, with no extra file to read and nothing to keep in sync.

### B — Topic-based tree (`architecture/`, `product/`, `ops/`, …)
Trade-off: costs nothing to learn; every contributor already knows it. Buys no freshness
signal at all — a two-year-old requirements document and one written this morning sit in
the same folder with the same apparent authority.

### C — Topic-based tree with a thin agent layer bolted on
Trade-off: cheap to adopt — keep the existing tree, add an `AGENTS.md` that explains
which parts are current. Buys a description of the rule rather than an enforcement of
it: the ambiguity stays in the tree, and the layer describing it drifts from the tree it
describes.

## Decision

We chose A, because the question an agent asks first is "how much do I trust this file",
and only a mutability split answers that from the path itself. Topic is recoverable from
a filename, tags, or grep; freshness is not.

## Rejected, and why

- **B** — rejected because familiarity is a one-off cost paid by humans, while the
  missing freshness signal is a recurring cost paid on every agent session. Topic
  grouping optimises for the cheaper problem.
- **C** — rejected because it leaves the ambiguity in place and adds a second thing to
  maintain. A rule that contradicts the structure loses to the structure, since the
  structure is what the agent sees without being told.

## Consequences

Easier: an agent can be told "trust `context/`, check the date on `state/`, never edit
`record/`, cite nothing from `work/`" in one sentence, and the sentence stays true.
Front matter, review cadence and the escalation matrix all key off the zone.

Harder: everything about one subject is now in up to four places, and there is a real
filing decision on every new file. Adopters who skip the zone `AGENTS.md` files will
mis-file, because zone names are not self-explanatory.

Committed to: zone names in paths, which are expensive to rename once anything links to
them, and to the discipline that content moves between zones rather than being edited in
place.

## Revisit if

Filing mistakes become the common failure mode instead of stale-context mistakes — that
would mean the split is costing more than the signal is worth.
