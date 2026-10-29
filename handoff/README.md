# .handoff/

Task exchange between a planning agent and an execution agent. The planner writes
`tasks/T-xxx.md`; the executor writes `results/T-xxx.md`. One file per task, named by its
ID. Templates are in `templates/`.

The executor's rules are in the `## Handoff protocol` section of `AGENTS.md` at the root
of this repository.

This folder is not session state. The durable record — backlog items, decisions,
logbook — lives in the planner's workspace, which the executor cannot see.
