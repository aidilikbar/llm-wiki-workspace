---
status: active
updated: 2026-10-29
owner: TODO
classification: public
---

# 2026-10-29 — Planner–executor workflow, one file per item, interactive installer

**Worked on:** Bringing a planner–executor workflow and a research zone into the template,
splitting every collection into one file per item, and making the installer ask questions.

**Outcome:** shipped (not yet pushed)

**What happened:**
A draft workflow document was reviewed against the template before anything was written,
and seven defects were found where it disagreed with existing rules — task and result
templates that the template's own hook rejects, result files with no classification,
result files not treated as untrusted executor output, a decision filename that broke the
naming rule, URLs exempt from the source index, a vendor-specific agent filename, and new
front-matter fields absent from the schema. The owner decided four questions (decisions
0008–0010); the defects were fixed in the process. Collections became folders —
`state/backlog/`, `state/icebox/`, `state/sprints/`, `record/backlog/`,
`context/requirements/R-NNN-….md`, `work/research/`, `work/prompts/` — with templates and
an ID rule in RULES §9. Both installers were rewritten: interactive questions read from
`/dev/tty`, `--handoff` for code repos, `--git` to switch the hook on. The suite grew from
56 to 104 checks.

**What surprised us:**
The first rewrite piped the file list into the copy function, which ran it in a subshell.
Files were written; the "wrote N files" count stayed at zero. Earlier versions had fed the
loop with a heredoc for exactly this reason, and the reason was not written down, so the
rewrite lost it. The fix is process substitution, with a comment saying why.

The test for "protocol appended once" failed on correct output: it counted lines matching
`handoff-protocol -->`, which both the opening and the closing marker contain. A test that
fails on correct output gets ignored, and then it stops catching the real duplicate.

The scripted-answer tests passed but proved less than they seemed — they never opened a
real terminal. A run under a real pseudo-terminal, with the script arriving on stdin as it
does through `curl | bash`, confirmed the path users actually take.

**Follow-ups:**
- [ ] Push; until then the curl route serves the previous template → owner
- [ ] Tag v1.1.0 so the release workflow builds the vault zip → owner
- [ ] `documentation-workflow.md` and `onboarding.md` are still TODO stubs → backlog
