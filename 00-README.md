# LLM Wiki Workspace

A repository layout for working with AI agents on long-running projects.

Most project wikis are libraries: they store knowledge well and tell an agent nothing
about what is current, what it may change, or when it is finished. This layout fixes
that by organising files **by mutability** rather than by topic. Where a file sits tells
you — and the agent — how much to trust it and who may edit it.

## The four zones

| Zone | Contains | Changes | Trust | Who writes |
|---|---|---|---|---|
| `context/` | Vision, principles, constraints, architecture, design, requirements | Rarely, deliberately | High | Human decides, agent drafts |
| `state/` | Current sprint, roadmap, backlog, handoff | Constantly | High **if fresh** | Agent updates, human reviews |
| `record/` | Decisions, logbook, closed sprints, releases, retros, eval runs | Append only | High, permanently | Agent appends, nobody edits |
| `work/` | Sources, scratch analysis, temp | Freely | **None** | Anyone, nothing is settled |

Plus `system/`, which is not a zone — it is how the workspace itself operates: rules,
agent roles, skills, evals, templates.

The rule that makes it work: **a claim is only settled once it reaches `record/` or
`context/`.** Anything in `work/` is raw material. Anything in `state/` is true until
proven stale.

## Tree

```
.
├── README.md
├── AGENTS.md
│
├── system/                            HOW WE WORK
│   ├── RULES.md
│   ├── agents/
│   │   ├── escalation.md
│   │   ├── chief-of-staff.md
│   │   ├── designer.md
│   │   ├── engineer.md
│   │   ├── qa.md
│   │   └── technical-writer.md
│   ├── skills/
│   ├── evals/
│   ├── workflows/
│   │   ├── documentation-workflow.md
│   │   └── onboarding.md
│   └── templates/
│       ├── _frontmatter.md
│       ├── adr.md
│       ├── handoff.md
│       ├── backlog-item.md
│       ├── icebox-item.md
│       ├── logbook.md
│       ├── release.md
│       ├── retro.md
│       ├── sprint.md
│       └── skill.md
│
├── context/                           STABLE
│   ├── AGENTS.md
│   ├── vision.md
│   ├── principles/
│   ├── constraints/
│   ├── architecture/
│   │   ├── system-overview.md
│   │   ├── infrastructures/
│   │   ├── schemas/
│   │   └── security/
│   ├── design/
│   │   ├── DESIGN.md
│   │   ├── design-system/
│   │   └── assets/
│   └── requirements/
│       ├── functional-requirements.md
│       ├── non-functional-requirements.md
│       └── acceptance-criteria.md
│
├── state/                             CURRENT
│   ├── AGENTS.md
│   ├── STATE.md
│   ├── handoff.md
│   ├── roadmap.md
│   ├── sprint-current.md
│   ├── backlog.md
│   ├── icebox.md
│   └── codebase-map.md                (generated)
│
├── record/                            APPEND-ONLY
│   ├── AGENTS.md
│   ├── decisions/
│   ├── logbook/
│   ├── sprints/
│   ├── releases/
│   ├── retrospectives/
│   └── eval-runs/
│
└── work/                              TRANSIENT
    ├── AGENTS.md
    ├── sources/
    │   └── INDEX.md
    ├── analysis/
    └── temp/
```

## Core vs optional

Do not create all of it on day one. Empty folders cost real tokens — agents glob into
them, find nothing, and retry — and they signal abandonment to humans.

**Core (create now):** `AGENTS.md`, `system/RULES.md`, `system/agents/escalation.md`,
`system/templates/`, `context/constraints/`, `context/requirements/`, `state/STATE.md`,
`state/handoff.md`, `record/decisions/`, `record/logbook/`, `work/temp/`.

**Optional (create at first real need):** everything else. `record/eval-runs/` when you
have evals. `context/design/` when there is a UI. `state/codebase-map.md` when the
codebase outgrows one person's head.

## Adopting it

1. Run `bootstrap.sh` (file 08) in an empty repo. It creates the core tier and stubs.
2. Fill `context/constraints/` first. Constraints prevent more bad agent work than any
   other file — they tell the agent where your project deliberately diverges from the
   statistically common pattern.
3. Fill `system/agents/escalation.md`. If you skip this, the agent will either ask about
   everything or ask about nothing.
4. Write `state/STATE.md` at the end of every working session. One screen, no history.
5. Append to `record/logbook/` as you go. Never edit an entry afterwards.

Expect the first two weeks to feel like overhead. The return arrives the first time a
new session picks up mid-task without you re-explaining the project.

## Gist file mapping

Gists are flat. These files map into the tree as:

| Gist file | Repository path |
|---|---|
| `00-README.md` | `README.md` |
| `01-AGENTS.md` | `AGENTS.md` |
| `02-RULES.md` | `system/RULES.md` |
| `03-escalation.md` | `system/agents/escalation.md` |
| `04-STATE.md` | `state/STATE.md` |
| `05-zone-AGENTS.md` | split into `context/`, `state/`, `record/`, `work/` `AGENTS.md` |
| `06-frontmatter.md` | `system/templates/_frontmatter.md` |
| `07-templates.md` | split into `system/templates/*.md` |
| `08-bootstrap.sh` | run once, then delete |

## Why AGENTS.md and not a tool-specific file

`AGENTS.md` is an open format read by most coding agents, and nested files are picked up
automatically when an agent works inside that directory — which is exactly what the zone
structure needs. If your tool wants its own filename, symlink it rather than maintaining
two copies that drift.

## Licence

CC0 / public domain. Take it, cut it down, change the zone names.
