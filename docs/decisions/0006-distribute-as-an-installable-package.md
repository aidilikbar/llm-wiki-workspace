---
status: active
updated: 2026-09-14
owner: TODO
classification: public
type: product
supersedes: 0005
---

# 0006 — The workspace is distributed as an installable package, not a repository to clone

## Context

Decision 0005 published the layout as a repository laid out in its own structure, on the
argument that a template which does not use itself is unfalsifiable. That held while the
audience was people reading the layout. It stops holding once the goal is people
*installing* it: an adopter who clones the repository inherits its decision records, its
logbook and its state files, and has to be told which of them are examples and which are
theirs. "Then delete these directories" is a step everyone skips, and an agent reading a
fresh clone cannot tell the difference — it reads someone else's history as if it were
the project's own.

## Options considered

### A — Payload in `template/`, repository root is the installer
Trade-off: costs the dogfooding argument — the root no longer visibly runs on the layout
it describes. Buys a clean install with no exclusion logic, nothing of the project's own
history reaching an adopter, and a payload that can be shipped through four channels
without special-casing any of them.

### B — Root stays the workspace, the installer carries an exclusion manifest
Trade-off: costs a manifest that silently rots — a file added to `record/` is shipped to
every adopter until someone notices. Buys the dogfooding argument intact and no
duplication.

### C — Both: a `template/` payload and a separate working workspace at the root
Trade-off: costs two copies of `system/RULES.md`, the escalation matrix and the
templates. Buys both properties, until the copies drift, at which point it buys neither.

## Decision

We chose A. The install being clean matters more than the repository being a live
demonstration, because the install is what everyone experiences and the demonstration is
what a handful of readers experience. The parts of the dogfooding that carry real
information — why the layout is shaped this way — are kept as `docs/decisions/`, which
also serves as the worked ADR examples the templates cannot provide.

## Rejected, and why

- **B** — rejected because an exclusion list is a correctness requirement with no failing
  test. The first symptom of it being wrong is an adopter asking who "chief of staff" is.
- **C** — rejected because duplicated rule files are the specific failure this layout
  exists to prevent. Two copies of a rule means nobody knows which one is binding.

## Consequences

Easier: installing, and shipping through several channels — `install.sh`, `npx`, the
GitHub template button and a zip release all copy the same directory. Adding a file to
the payload is a single, obvious act.

Harder: the claim that the layout survives contact with itself is now made by
`docs/decisions/` rather than by the repository's shape, which is weaker evidence. The
verification suite has to carry the weight instead: it checks that both installers agree,
that the core manifest matches the payload, and that every payload file passes the front
matter rule the payload itself mandates.

Committed to: `template/` being the only thing that ships, a core manifest kept in step
with it by test rather than by discipline, and the installers staying behaviourally
identical.

## Revisit if

The payload and the repository's own practice diverge far enough that the layout is being
recommended but not used — for instance if this repository's own decisions stop being
written. At that point the dogfooding argument was load-bearing after all.
