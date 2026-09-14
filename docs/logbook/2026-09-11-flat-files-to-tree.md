---
status: active
updated: 2026-09-11
owner: chief-of-staff
classification: public
---

# 2026-09-11 — Flat Gist files converted into the tree

**Worked on:** Converting the nine numbered files into the real zone structure and making
the repository follow its own rules.

**Outcome:** partial

**What happened:**
Ran `08-bootstrap.sh --full` in the repository, then split and moved the numbered files
per the mapping. `05-zone-AGENTS.md` became four zone `AGENTS.md` files and
`07-templates.md` became nine templates, both extracted by taking each fenced block as a
file and dropping the commentary around it. `08-bootstrap.sh` stays at the root; the other
eight originals were deleted. The README's Gist mapping table was replaced with
clone-and-bootstrap instructions. Decisions `0001`–`0005` were written, each with its
rejected options. All four verification checks pass: `bash -n`, clean bootstrap runs in an
empty directory with and without `--full`, a full-tree commit accepted by the pre-commit
hook and a front-matter-less file rejected by it, and no employer or private project named
anywhere in the tree. Outcome is partial because nothing is committed and nine questions
are open.

**What surprised us:**
Three things, all of them the repository disagreeing with itself.

The bootstrap claims to be idempotent, and is, except that it writes `README.md` and
`.gitignore` with `cat >` rather than through the `stub` guard. Re-running it in a repo
with a real README destroys the README. The order of work here hid it — bootstrap first,
README second — which is exactly why it would survive to an adopter.

`02-RULES.md` and `06-frontmatter.md` shipped with no front matter, so the rule file that
mandates front matter was itself rejected by the check it specifies. Both were given front
matter before being moved.

The stubs are written `classification: internal` in a repository whose whole point is that
it is public. Correcting that looked mechanical, but changing a classification is on the
must-escalate list in `system/agents/escalation.md`, so it went to the owner instead. The
first real test of the escalation matrix was the matrix stopping a cleanup that felt
obvious.

**Follow-ups:**
- [ ] Nine open questions listed in `state/handoff.md` → owner decision
- [ ] Patch `08-bootstrap.sh`: guard `README.md` and `.gitignore`, drop the Gist
      references from the header comment and closing output → decision 8
- [ ] Classification sweep once decision 6 lands → must escalate, do not pre-empt
