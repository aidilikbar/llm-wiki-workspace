---
status: active
updated: 2026-10-29
owner: TODO
classification: public
type: data
supersedes:
---

# 0009 — Every collection is a folder with one file per item

## Context

The template held several collections as single files: `state/backlog.md`,
`state/icebox.md`, `state/sprint-current.md`, and three requirements files each holding
many requirements. Meanwhile `system/templates/backlog-item.md` described a single item,
and the planner–executor workflow linked tasks to `state/backlog.md#T-xxx` — an anchor
inside a long file. The template disagreed with itself about what a backlog item is.

## Options considered

### A — One file per item, everywhere items accumulate
Trade-off: costs more files, and the loss of seeing a whole collection on one screen.
Buys a `status`, `owner` and `updated` per item — the front-matter mechanism working at
the level it was designed for — stable links, and no edit conflicts between agents.

### B — Single file per collection, items as headings
Trade-off: costs per-item staleness (one `updated` for fifty items), anchor links that
break when a heading is renamed, and every agent editing the same file. Buys one place to
scan.

### C — One file per work item, but keep requirements as three files
Trade-off: costs inconsistency, and a definition of done that cannot be cited per
requirement. Buys a spec that is read as a whole.

## Decision

A, including requirements. Work items, requirements, prompts and research questions are
each one file per item, named by ID or date. Single files remain only where the thing is
genuinely one item: `STATE.md`, `handoff.md`, `roadmap.md`, `vision.md`.

## Rejected, and why

- **B** — rejected by the owner, and because it defeats the front-matter mechanism: one
  `updated` date over many items says nothing about any of them.
- **C** — rejected by the owner. A task should be able to cite `R-014` and a reviewer
  should be able to check exactly that requirement's acceptance criteria.

## Consequences

Easier: per-item freshness, per-item ownership, links from `.handoff/` tasks to
`state/backlog/T-012-….md` that survive edits, Obsidian search as the view
(`path:state/backlog status:ready`).

Harder: no single-screen view of a collection without a search. Hand-maintained indexes
were considered and rejected — an index is a second copy of every status, and it drifts.
`work/sources/INDEX.md` stays, because it records provenance for files that cannot carry
front matter. Items now move between zones (backlog to `record/backlog/`, sprint to
`record/sprints/`), which needed `record/backlog/` and a rule that moving is never
copying.

Committed to: IDs that are never reused, file names that do not change when an item moves,
and `system/RULES.md` §9 as the single statement of names and IDs.

## Revisit if

The number of items makes the folders unreadable without an index — at that point the
answer is a generated index (`generated: true`), never a hand-kept one.
