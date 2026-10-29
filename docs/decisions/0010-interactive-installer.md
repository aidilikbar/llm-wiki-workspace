---
status: active
updated: 2026-10-29
owner: TODO
classification: public
type: product
supersedes:
---

# 0010 — The installer asks, like a framework scaffolder, and also sets up code repos

## Context

The installer was flag-driven: run with no arguments and it silently wrote the core tier
into the current folder. That is correct but opaque — a first-time user does not know the
core tier exists, that Obsidian support is a flag, or that the hook does nothing until
`core.hooksPath` is set. The planner–executor workflow (0008) also needs files in a
second place, the code repo, which nothing installed.

## Options considered

### A — Interactive, flags answer their own questions
Trade-off: costs a second code path to test, and terminal handling that must work when
the script itself arrives on stdin via `curl | bash`. Buys discoverability: every choice
is put in front of the user once, with a default.

### B — Full tree by default, no questions
Trade-off: costs the core-tier default, which exists because empty folders cost agents
tokens. Buys the simplest possible first run.

### C — Keep it flag-driven
Trade-off: costs discoverability. Buys nothing new.

For the code repo: **D** — `--handoff` writes `.handoff/` and the executor protocol;
**E** — document the manual steps only.

## Decision

A and D. With a terminal attached and no `--yes`, the installer asks: workspace or
`.handoff/`, folder, core or full, Obsidian, git. Any flag given answers its question.
Answers are read from `/dev/tty`, so `curl | bash` works. `--handoff` installs into an
existing code repo, appends the protocol to `AGENTS.md` once, and links `CLAUDE.md` to it
or appends to an existing one.

## Rejected, and why

- **B** — rejected because it reverses the core-tier argument without new evidence.
  Asking puts the choice in front of the user instead.
- **C** — rejected by the owner: the goal is an install that feels like scaffolding a
  project, not reading a flag table first.
- **E** — rejected by the owner: three manual steps across two repositories are exactly
  what gets half-done.

## Consequences

Easier: one command and a few answers produce a working workspace with the hook on.
Setting up the executor side is the same command run in another folder.

Harder: a test that runs the installer from a terminal would now block on a question, so
the suite sets `LWW_NONINTERACTIVE` and feeds scripted answers through `LWW_TTY`. The
zip builder passes `--yes`. Writing into someone else's code repo is a new kind of
reach: it is limited to `.handoff/`, a marked block in `AGENTS.md` / `CLAUDE.md`, one
`.gitignore` line, and never overwrites.

Committed to: every question having a flag, `--yes` never asking, and the bash and Node
installers behaving identically — verified by diffing their output in every mode.

## Revisit if

Users run the installer mainly from scripts and the questions get in the way — then the
default flips to non-interactive and `--interactive` opts in.
