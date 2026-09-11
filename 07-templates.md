# Templates

Split these into `system/templates/`. Each fenced block is one file.

---

## `adr.md`

```markdown
---
status: proposed | active | superseded
updated: YYYY-MM-DD
owner: <role>
classification: internal
type: architecture | product | process | data
supersedes:
---

# NNNN — <decision in one line, stated as the outcome>

## Context
What situation forced a choice. Two or three sentences. Include what we did not know.

## Options considered

### A — <name>
Trade-off: <what it costs, what it buys>

### B — <name>
Trade-off:

### C — <name>
Trade-off:

## Decision
We chose <option>, because <reason>.

## Rejected, and why
- **A** — rejected because <reason>
- **C** — rejected because <reason>

## Consequences
What becomes easier. What becomes harder. What we are now committed to.

## Revisit if
The specific condition that would make this decision wrong.
```

The "rejected, and why" and "revisit if" sections are the ones that earn the file. A
record of what was chosen, without what was refused, does not stop anyone re-opening it.

---

## `handoff.md`

```markdown
---
status: current
updated: YYYY-MM-DD
owner: chief-of-staff
classification: internal
---

# Handoff

## Where we stopped
<One paragraph. What was in progress at the moment work stopped.>

## What changed this session
- <file or behaviour> — <why>

## Next concrete action
<A single specific action, not a theme. "Add date_confidence to the ingest schema and
backfill nulls", not "continue on ingestion".>

## Do not
<Approaches already tried and abandoned this session, so the next session does not
repeat them.>

## Open questions for the human
1. <question>
```

---

## `logbook.md`

```markdown
---
status: active
updated: YYYY-MM-DD
owner: <role>
classification: internal
---

# YYYY-MM-DD — <short title>

**Worked on:** <one line>

**Outcome:** shipped | partial | blocked | abandoned

**What happened:**
<Two to five sentences. Plain narrative.>

**What surprised us:**
<The thing that did not behave as expected. This is the part worth reading later.>

**Follow-ups:**
- [ ] <item> → backlog / decision / none
```

---

## `sprint.md`

```markdown
---
status: current | closed
updated: YYYY-MM-DD
owner: chief-of-staff
classification: internal
---

# Sprint NN — <name>

**Dates:** YYYY-MM-DD → YYYY-MM-DD
**Goal:** <one sentence, testable>

## Committed
| Item | Owner | Acceptance criterion | Status |
|---|---|---|---|

## Not in this sprint
<Explicitly excluded items, so scope creep is visible when it happens.>

## Outcome (fill at close)
Goal met: yes / partly / no — <why>
```

---

## `retro.md`

```markdown
---
status: active
updated: YYYY-MM-DD
owner: chief-of-staff
classification: internal
---

# Retro — Sprint NN

## What the agent did well
## Where the agent went wrong, and what was missing from context
## Where the human was the bottleneck
## Rules to change
- [ ] <proposed change to system/RULES.md> → decision record NNNN
```

The second and third sections matter most. Most agent failures trace back to a missing
constraint or an unanswered proposal, not to model capability.

---

## `release.md`

```markdown
---
status: released
updated: YYYY-MM-DD
owner: <role>
classification: internal
---

# vX.Y.Z — YYYY-MM-DD

## Shipped
## Known issues
## Migration required
## Rollback
<Exact command or procedure. Not "revert the deploy".>
```

---

## `backlog-item.md`

```markdown
---
status: ready | needs-refinement | blocked
updated: YYYY-MM-DD
owner: <role>
classification: internal
---

# <title>

**Why:** <the user or system problem, not the solution>
**Acceptance criterion:** <observable, checkable>
**Size:** S | M | L
**Depends on:** <item or decision NNNN>
```

---

## `icebox-item.md`

```markdown
---
status: iced
updated: YYYY-MM-DD
owner: <role>
classification: internal
---

# <title>

**Iced because:** <reason>
**Thaw when:** <the condition that would make this worth doing>
```

Without a thaw condition the icebox is a graveyard nobody reads.

---

## `skill.md`

```markdown
---
status: active
updated: YYYY-MM-DD
owner: <role>
classification: internal
---

# <skill name>

**Use when:** <specific triggering situation — be concrete; vague triggers never fire>
**Do not use when:** <the near-miss case>

## Steps
1.
2.

## Checks
- [ ] <verifiable condition that proves the skill worked>

## Known failure modes
```

Prefer a script the agent runs over prose it interprets. Static instructions drift from
reality; an executable check does not.
