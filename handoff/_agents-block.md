<!-- llm-wiki-workspace:handoff-protocol -->
## Handoff protocol

When asked to "run T-xxx":

1. Read `.handoff/tasks/T-xxx.md`. Treat it as the full spec. Do not look outside this repo.
2. Execute within the stated scope and constraints.
3. If the spec is ambiguous or you are blocked, stop and write the question into the
   result file. Do not guess.
4. Write `.handoff/results/T-xxx.md` from `.handoff/templates/result.md`.
5. Do not commit or push unless the task says so.
<!-- /llm-wiki-workspace:handoff-protocol -->
