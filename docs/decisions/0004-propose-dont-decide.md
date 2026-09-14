---
status: active
updated: 2026-09-11
owner: <human owner>
classification: public
type: process
supersedes:
---

# 0004 — Agents propose options with trade-offs; the human owner decides

## Context

An agent working a long task meets several choices an hour that have real alternatives:
a library, a schema shape, a scope cut. Left undefined, the boundary collapses one of two
ways — the agent decides everything quietly, or it asks about everything and the human
becomes a queue. The failure mode of the first is not bad code, which gets caught in
review; it is plausible decisions taken quietly, which surface weeks later as constraints
nobody remembers choosing.

## Options considered

### A — Propose 2–4 options with trade-offs by default; the human decides
Trade-off: costs a turn on every non-mechanical choice, and the human has to be available
or work stops. Buys a record of what the alternatives were, and decisions that stay the
human's even when the agent wrote the analysis.

### B — Agent decides autonomously within a defined blast radius
Trade-off: costs nothing per turn and the agent runs unattended for long stretches. Buys
a growing set of commitments nobody chose, discoverable only when something built on them
has to change.

### C — Agent asks before every action
Trade-off: costs enormously in turns and attention. Buys nothing that A does not, and
actively erodes review quality: a human approving trivia stops reading, and then approves
the one thing that mattered along with the rest.

## Decision

We chose A, with an explicit three-way matrix in `system/agents/escalation.md` —
decide alone, propose and wait, must escalate — and **propose** as the default when a
case is unclear. Presenting options is slower per turn and cheaper per project.

This carries a reciprocal obligation on the human: proposals get answered promptly and
decisively. An agent that proposes into silence learns nothing and blocks, and a human
who leaves proposals open converts option A into option C at a worse price. The
obligation is part of the decision, not a courtesy attached to it.

## Rejected, and why

- **B** — rejected because the damage is invisible at the time and expensive later. The
  work an autonomous agent does fastest is exactly the work whose assumptions nobody
  wrote down.
- **C** — rejected because it makes the human the bottleneck for things the rules
  already answer, and because blanket approval is what a human does when asked too
  often. It degrades into rubber-stamping and then into B without the speed.

## Consequences

Easier: reconstructing why something is the way it is — the rejected options are on the
record because proposing them was a required step. The escalation matrix also gives the
agent permission to act on mechanical work without asking, which is most of the work.

Harder: throughput depends on the human's response latency. Anything sitting in "propose"
is stopped, so a slow week of answers is a slow week of progress, and the failure is
quiet unless `state/STATE.md` names the open decisions and how long they have been open.

Committed to: the escalation matrix being binding rather than advisory, and to the
open-decisions table in `STATE.md` as the mechanism that makes an unanswered proposal
visible.

## Revisit if

The open-decisions table is routinely several items deep and days old. That means the
reciprocal obligation is not being met, and the honest fix is to widen "decide alone"
rather than to keep proposing into a queue.
