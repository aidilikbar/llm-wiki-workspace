---
status: active
updated: {{date}}
owner: {{owner}}
classification: internal
---

# Kick-off: {{project_name}}

This workspace was installed on {{date}} and does not describe the project yet. This
file is the brief for the first session. When the human has approved the drafts below,
move this file to `record/logbook/{{date}}-kick-off.md`.

## The project

{{project_description}}

## First session

Work through these in order. Draft each one, show it to the human, and wait for approval
before treating it as settled.

1. Read `AGENTS.md` and `system/agents/escalation.md`.
2. Ask the human what the description above leaves out: who the project is for, what is
   out of scope, deadlines, and anything that must not be done the usual way. Ask
   rather than guess.
3. Draft `context/vision.md`: what the project is, who it is for, and what success
   looks like. Half a page at most.
4. Draft the constraints in `context/constraints/`, one file each, from
   `system/templates/constraint.md`. A constraint is a place where this project must
   not follow the common approach.
5. Draft the first requirements in `context/requirements/` (`R-001`, `R-002`, ...), one
   file each, from `system/templates/requirement.md`, each with acceptance criteria.
6. Propose the first backlog items in `state/backlog/` (`T-001`, ...), from
   `system/templates/backlog-item.md`.
7. If the project has a code repository, ask for its install, test, lint and build
   commands and fill the `## Commands` block in `AGENTS.md`.
8. Write `state/STATE.md`, `state/handoff.md` and a first entry in `record/logbook/`.
