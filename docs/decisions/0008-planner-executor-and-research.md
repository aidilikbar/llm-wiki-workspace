---
status: active
updated: 2026-10-29
owner: TODO
classification: public
type: process
supersedes:
---

# 0008 — The template ships a planner–executor workflow and a research zone

## Context

The layout assumed one agent working in one folder. In practice the work splits across
two: a planner that can see the workspace and the code repo, and an executor that can see
only the code repo. Without a protocol the human carries prompts and results between them
by hand, and the reasoning behind each change lives in a chat transcript rather than in
`record/`. Investigation had no home either — it went to `work/analysis/`, an empty folder
nobody had defined.

## Options considered

### A — Exchange folder named `.handoff/`
Trade-off: costs a name collision with `state/handoff.md`, which has to be called out in
the workflow, the tree and the README. Buys a name that already matches how the workflow
is used and described.

### B — Rename the exchange folder (`.exchange/`, `.agent-tasks/`)
Trade-off: costs a departure from established practice. Buys an unambiguous name.

### C — Replace `work/analysis/` with `work/research/`
Trade-off: costs the only generic scratch-analysis folder. Buys a folder with a defined
contract — one question per file, options not verdicts, explicit promotion.

### D — Keep both `analysis/` and `research/`
Trade-off: costs two near-synonyms in the same zone and a boundary nobody will hold.

## Decision

A and C. The exchange folder stays `.handoff/`; the collision is handled by stating the
difference wherever both appear. `work/analysis/` is replaced by `work/research/`.

## Rejected, and why

- **B** — rejected by the owner. The name is already in use, and renaming costs more than
  the collision it removes.
- **D** — rejected because two folders with overlapping meaning are filed into
  inconsistently, and an agent cannot tell which one a finding belongs in.

## Consequences

Easier: the human triggers each step with two words (`run T-012`, `review T-012`) instead
of copying text. Every task has a file in the code repo and a backlog item in the
workspace under the same ID. Result files are treated as data under RULES §7, so an
executor cannot talk the planner into anything.

Harder: two places named "handoff". Task and result templates live in the code repo, not
in `system/templates/`, because the executor must be able to read the result template —
so they are installed by `--handoff`, not by the workspace install.

Committed to: the executor never reading the workspace, context copied into task files
rather than linked, and research ending in options rather than verdicts.

## Revisit if

Agents confuse the two handoffs in practice — a session writes continuity notes into
`.handoff/` or a task into `state/handoff.md`. That is the signal the name costs more
than it was judged to.
