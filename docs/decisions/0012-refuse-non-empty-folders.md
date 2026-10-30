---
status: active
updated: 2026-10-30
owner: TODO
classification: public
type: product
supersedes:
---

# 0012 — The installer refuses a non-empty folder unless told otherwise

## Context

v0.1.0 installed into any folder and skipped files that already existed. A typo in the
folder name, or answering `.` in the wrong place, silently mixed the workspace into an
unrelated folder, and the report gave no sign that anything was wrong.

## Options considered

### A — Refuse, and offer `--merge` and `--force`
Trade-off: costs one extra flag for the rare deliberate case. Buys a mistake that stops
before anything is written, with a message saying how to continue.

### B — Keep skipping existing files
Trade-off: costs nothing to keep. Buys no protection against the wrong folder.

### C — Ask interactively what to do
Trade-off: costs a question most people never need, and behaves differently with
`--yes`.

## Decision

A. A folder holding only `.git` or `.DS_Store` still counts as empty. `--eject` implies
`--merge`, because a template clone is never empty.

## Rejected, and why

- **B**: the failure it allows is silent.
- **C**: the default answer would be wrong for most people who reach that question.

## Revisit if

People mostly install into existing project folders, and `--merge` becomes the common
case rather than the exception.
