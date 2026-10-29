<!-- llm-wiki-workspace:upstream-readme -->

# LLM Wiki Workspace

A folder structure for working with AI agents on long-running projects. Run one command
in a folder and it generates the workspace — the way a framework installer scaffolds a
new project.

```bash
curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh | bash
```

Most project wikis are libraries: they store knowledge well and tell an agent nothing
about what is current, what it may change, or when it is finished. This layout organises
files **by mutability** instead of by topic. Where a file sits tells you — and the agent —
how much to trust it and who may edit it.

| Zone | Contains | Changes | Trust | Who writes |
|---|---|---|---|---|
| `context/` | Vision, principles, constraints, architecture, design, requirements | Rarely, deliberately | High | Human decides, agent drafts |
| `state/` | Current state, handoff, roadmap, backlog, sprints | Constantly | High **if fresh** | Agent updates, human reviews |
| `record/` | Decisions, logbook, finished backlog, icebox, closed sprints, releases, retros, eval runs | Append only | High, permanently | Agent appends, nobody edits |
| `work/` | Sources, research, prompts, temp | Freely | **None** | Anyone, nothing is settled |

Plus `system/`, which is not a zone — it is how the workspace itself operates: rules,
agent roles, workflows, skills, evals, templates.

The rule that makes it work: **a claim is only settled once it reaches `record/` or
`context/`.** Anything in `work/` is raw material. Anything in `state/` is true until
proven stale.

Every markdown file carries front matter with `status`, `updated`, `owner` and
`classification`, and a git hook rejects any file that does not. That is what makes
staleness visible: without it, a two-year-old requirement loads with exactly the same
authority as one written this morning.

## Install

Open a terminal in the folder where the workspace should live and run:

```bash
curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh | bash
```

It asks what you want, then generates it:

```
  LLM Wiki Workspace  v0.1.0

 What would you like to set up?
   [1] A workspace — the knowledge base your agents read and write
   [2] A .handoff/ exchange in a code repo — for the planner–executor workflow
 > [1]:

 Where should the workspace go? A folder name, or . for this folder [.]: my-project

 Which structure?
   [1] Core — the files you fill in during week one (recommended)
   [2] Full — every folder, including design, architecture and evals
 > [1]:

 Configure it as an Obsidian vault? [y/N]: y
 Initialise git and turn on the front-matter check? [Y/n]:

  core workspace into my-project/, as an Obsidian vault, with git and the front-matter check
 Proceed? [Y/n]:
```

Press Enter to take the default in brackets. Nothing already in the folder is
overwritten.

### Without the questions

Every question has a flag. Pass `--yes` and anything not given takes its default — use
this in scripts, CI, or when you already know what you want:

```bash
curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh \
  | bash -s -- --yes --full --obsidian --git my-project
```

| Flag | Effect |
|---|---|
| `--core` / `--full` | Core tier (default) or the entire tree |
| `--obsidian` / `--no-obsidian` | Write `.obsidian/` so the folder opens as a configured vault |
| `--git` / `--no-git` | `git init` if needed and set `core.hooksPath` so the front-matter check runs |
| `--handoff` | Set up a `.handoff/` exchange in an existing code repo instead of a workspace |
| `--handoff-ignore` | With `--handoff`: add `.handoff/` to that repo's `.gitignore` |
| `--force` | Overwrite files that already exist |
| `--eject` | Remove the packaging afterwards — for a repo made with "Use this template" |
| `--dry-run` | Print what would happen, write nothing |
| `-y`, `--yes` | Never ask |

### Other ways in

- **npx** — `npx llm-wiki-workspace` asks the same questions and takes the same flags.
  Use it on Windows, where it runs without bash. On Windows it cannot open the terminal
  for questions, so pass flags. *Not yet published to npm — until it is, use the curl
  route.*
- **GitHub template** — click **Use this template** on
  [the repository](https://github.com/aidilikbar/llm-wiki-workspace), clone it, then run
  `bash install.sh --yes --full --eject .` to flatten it. `--eject` deletes `template/`,
  `handoff/`, `install.sh` and the other packaging; your README is replaced with a stub
  only if it is still this one.
- **Obsidian vault, no terminal** — download `llm-wiki-workspace-vault-<version>.zip`
  from [Releases](https://github.com/aidilikbar/llm-wiki-workspace/releases), unzip it,
  and choose **Open folder as vault**.

## Make sure it is running

If you answered yes to git, the front-matter check is already on. Otherwise:

```bash
git config core.hooksPath .githooks
```

That setting is per clone — anyone who clones your repo runs it too. Then prove it works.
This commit must be rejected:

```bash
printf '# no front matter\n' > context/constraints/tmp-check.md
git add context/constraints/tmp-check.md && git commit -m 'should fail'
rm context/constraints/tmp-check.md
```

Expected output: `front matter missing entirely: context/constraints/tmp-check.md`, and no
new commit. If the commit succeeds, the hook is not on — check that `.githooks/pre-commit`
exists and is executable.

The hook checks staged markdown only, skips `README.md`, `AGENTS.md` and `work/temp/`,
and warns without blocking when a `review_by` date has passed.

## Fill it in, in this order

1. **`context/constraints/`** — first, and it is not close. Constraints record where your
   project deliberately diverges from the statistically common pattern, which is exactly
   what an agent defaults to. Template: `system/templates/constraint.md`.
2. **`system/agents/escalation.md`** — what the agent may decide alone, what it must
   propose, what it must never do without you.
3. **The `## Commands` block at the bottom of `AGENTS.md`** — your real install, test,
   lint and build invocations. Exact commands, not descriptions.
4. **`context/requirements/`** — one file per requirement, each with its own acceptance
   criteria. Together they are the definition of done.
5. **`state/STATE.md`** — at the end of every working session. One screen, no history.
6. **`record/logbook/`** — one entry per session. Never edit one afterwards.

Everything else can stay a `TODO` until something forces it. The installer stamps
`updated:` with the install date, so the freshness clock starts the day you adopt it.

## One file per item

Anything that accumulates items is a folder with one file per item — never one long file
holding many. Each item gets its own owner, status and `updated` date, links point at the
item rather than an anchor, and two agents working on two items never edit the same file.

| Collection | Folder | File name |
|---|---|---|
| Requirements | `context/requirements/` | `R-001-short-slug.md` |
| Backlog | `state/backlog/` | `T-012-short-slug.md` |
| Icebox | `record/icebox/` | `T-012-short-slug.md` — keeps its ID |
| Sprints | `state/sprints/` → `record/sprints/` at close | `S-03-short-slug.md` |
| Finished backlog | `record/backlog/` | `T-012-short-slug.md` |
| Decisions | `record/decisions/` | `0007-short-slug.md` |
| Logbook | `record/logbook/` | `2026-10-29-short-slug.md` |
| Retrospectives | `record/retrospectives/` | `S-03-retro.md` |
| Releases | `record/releases/` | `v1.2.0.md` |
| Research | `work/research/` | `2026-10-29-short-slug.md` |
| Prompts | `work/prompts/` | `short-slug.md` |

IDs are never reused. An item changes zone by moving its file — a finished backlog item
moves to `record/backlog/`, an iced one to `record/icebox/`, a closed sprint to
`record/sprints/` — keeping its name. The icebox sits in `record/` because an iced item
is not current: in `state/` it would trip the 7-day staleness flag forever. It is the one
`record/` folder an item can leave — thawing moves it back to `state/backlog/`. There
is no hand-kept index over any collection: each file's front matter is the truth about
that item, and an index would be a second copy that drifts. Templates for every item type
are in `system/templates/`. Full rules: `system/RULES.md` §9.

## Planner and executor

The workspace is built for a two-agent loop: a **planner** that can see this workspace
and the code repo, and an **executor** that sees only the code repo. They exchange work
through a `.handoff/` folder in the code repo, so the human never copies prompts and
results between them. Set that folder up by running the installer from the code repo:

```bash
cd path/to/code-repo
curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh \
  | bash -s -- --handoff .
```

It writes `.handoff/` with task and result templates, and adds the executor protocol to
the repo's `AGENTS.md` — once, however often you run it. If the repo has no `CLAUDE.md`,
one is linked to `AGENTS.md`; if it has one, the protocol is appended there too.

The loop: the human states a requirement → the planner writes `state/backlog/T-012-….md`
and `.handoff/tasks/T-012.md` → the human tells the executor `run T-012` → the executor
writes `.handoff/results/T-012.md` → the human tells the planner `review T-012` → the
planner checks the result **and the diff** against the acceptance criteria and presents
options → the human decides. Nothing is merged, committed or pushed without the human.

Full workflow: `system/workflows/planner-executor.md`. How investigation feeds it:
`system/workflows/research.md`.

## Using it with Obsidian

The tree is plain markdown, so any vault works. `--obsidian` adds a config that makes the
structure legible rather than adding features:

- **Templates** plugin on, pointed at `system/templates/` — *Insert template* gives you a
  correctly shaped requirement, backlog item, ADR, research question or prompt, front
  matter included.
- **Properties** on, so `status`, `updated`, `owner` and `classification` are editable
  fields rather than raw YAML.
- **Graph colours by zone** — `context/` blue, `state/` amber, `record/` green, `work/`
  grey, `system/` purple. A cluster of grey nodes that everything links to is `work/`
  content being treated as settled.
- New files and attachments default to `work/temp/`, the untrusted zone. Nothing lands in
  `context/` by accident.
- With one file per item, search replaces the index: `path:state/backlog status:ready`.

No community plugins. Per-machine state (`workspace.json`, `cache`) is gitignored; the
shared settings are committed.

## The tree

```
.
├── AGENTS.md                          entry point for the agent
├── .gitignore
├── .githooks/pre-commit               front-matter check
│
├── system/                            HOW WE WORK
│   ├── RULES.md
│   ├── agents/                        escalation, chief-of-staff, designer,
│   │                                  engineer, qa, technical-writer
│   ├── workflows/                     planner-executor, research,
│   │                                  documentation-workflow, onboarding
│   ├── skills/
│   ├── evals/
│   └── templates/                     adr, backlog-item, constraint, handoff,
│                                      icebox-item, logbook, prompt, release,
│                                      requirement, research, retro, skill,
│                                      sprint, _frontmatter
├── context/                           STABLE
│   ├── vision.md
│   ├── principles/
│   ├── constraints/                   fill this first
│   ├── architecture/
│   ├── design/
│   └── requirements/                  R-001-….md, one per requirement
│
├── state/                             CURRENT
│   ├── STATE.md                       one screen, no history
│   ├── handoff.md                     where the last session stopped
│   ├── roadmap.md
│   ├── backlog/                       T-012-….md, one per item
│   ├── sprints/                       the current sprint
│   └── codebase-map.md                (generated)
│
├── record/                            APPEND-ONLY
│   ├── decisions/
│   ├── logbook/
│   ├── backlog/                       finished and dropped items
│   ├── icebox/                        iced items; thawing moves them back
│   ├── sprints/                       closed sprints
│   ├── releases/
│   ├── retrospectives/
│   └── eval-runs/
│
└── work/                              TRANSIENT
    ├── sources/INDEX.md               provenance of every source
    ├── research/                      one file per question
    ├── prompts/                       one file per prompt
    └── temp/                          purged at 14 days
```

Each zone has its own `AGENTS.md`. Most coding agents read the nearest one automatically
when working inside a directory, which is why the rules live next to the files they
govern rather than in one long root file.

`state/handoff.md` is session continuity inside the workspace. `.handoff/` is the task
exchange inside a code repo. They are different things.

## Core vs optional

The default is the core tier, deliberately. Empty folders cost real tokens — agents glob
into them, find nothing, and retry — and they signal abandonment to humans.

**Core:** `AGENTS.md`, the hook, `system/RULES.md`, `system/agents/escalation.md`,
`system/templates/`, `context/constraints/`, `context/requirements/`, `state/STATE.md`,
`state/handoff.md`, `state/backlog/`, `record/decisions/`, `record/logbook/`,
`record/backlog/`, `work/sources/INDEX.md`, `work/temp/`, and the zone `AGENTS.md` files.

**Full:** everything else, including the workflows, research, prompts, sprints, icebox,
design, architecture and evals. Re-running the installer is safe — existing files are
skipped — so starting core and adding `--full` later costs nothing.

## Customising it

- **Staleness threshold.** `state/` files are stale after 7 days. That number appears in
  `AGENTS.md`, `system/RULES.md` and `state/AGENTS.md`. Change all three or none.
- **Classification.** If your project has no confidentiality dimension, keep the field
  and set everything to `public`. Deleting it means the first sensitive file arrives with
  nowhere to go.
- **Owners.** Replace every `owner: TODO`. Never write "team" — that means nobody.
- **Tool-specific agent files.** If your agent wants its own filename instead of
  `AGENTS.md`, link it rather than keeping two copies that drift. `--handoff` does this
  for `CLAUDE.md`.

## Repository layout

This repository is the installer, not the workspace.

| Path | What it is |
|---|---|
| `template/` | The workspace — what a workspace install writes |
| `handoff/` | What `--handoff` writes into a code repo as `.handoff/` |
| `obsidian-preset/` | Vault config, written to `.obsidian/` by `--obsidian` |
| `install.sh` | The installer; downloads the repository itself when piped from curl |
| `bin/cli.js` | The same installer in Node, for `npx`; CI keeps the two identical |
| `scripts/test.sh` | The verification suite |
| `scripts/make-vault-zip.sh` | Builds the Obsidian release asset |
| `docs/decisions/` | Why this repository is shaped the way it is — also worked ADR examples |
| `docs/logbook/` | Its build history |

## Contributing and verification

```bash
bash scripts/test.sh
```

Covers both installers producing identical results in every mode, the interactive
questions, `--handoff` being idempotent in a code repo, `--git` turning the check on and
the hook blocking a bad commit, one-file-per-item holding across the template, no file
referencing a path that no longer exists, front matter on every payload file, and the
installer surviving a shadowed `head(1)` on `PATH`. CI runs it on Linux and macOS.

The last check scans for names that must never be published. The list is not in this
repository — publishing it would leak what it exists to prevent. Put one term per line in
`.private-names` (gitignored) or point `LWW_DENYLIST` at a file elsewhere; without one,
that check is skipped.

Changes to `template/` need a matching entry in `docs/decisions/` when they are expensive
to reverse or had a real alternative — the same rule the workspace asks of its users.

## Licence

CC0 1.0 — public domain. Take it, cut it down, rename the zones. Attribution is welcome
and not required.
