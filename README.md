<!-- llm-wiki-workspace:upstream-readme -->

# LLM Wiki Workspace

A folder structure for working with AI agents on long-running projects. Install it into
a repository you already have, a new one, or an Obsidian vault.

Most project wikis are libraries: they store knowledge well and tell an agent nothing
about what is current, what it may change, or when it is finished. This layout organises
files **by mutability** instead of by topic. Where a file sits tells you — and the agent —
how much to trust it and who may edit it.

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

Every markdown file carries front matter with `status`, `updated`, `owner` and
`classification`, and a git hook rejects any file that does not. That is the mechanism
that makes staleness visible: without it, a two-year-old requirements document loads with
exactly the same authority as one written this morning.

## Install

Four ways in. They all produce the same tree.

### 1. One command, into any folder

```bash
curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh | bash
```

Installs the core tier into the current directory. Nothing is overwritten. To choose the
target, the tier, or Obsidian support, download it first:

```bash
curl -fsSLO https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh
bash install.sh --help
bash install.sh --full --obsidian ./my-project
```

| Flag | Effect |
|---|---|
| *(none)* | Core tier only — the files you will actually fill in week one |
| `--full` | The entire tree, including the optional folders |
| `--obsidian` | Also write `.obsidian/`, so the folder opens as a configured vault |
| `--force` | Overwrite files that already exist in the target |
| `--eject` | Remove the packaging afterwards — for the "Use this template" route below |
| `--dry-run` | Print what would happen, write nothing |

### 2. npx

```bash
npx llm-wiki-workspace --full ./my-project
```

Same flags, same output, no bash required. Use this on Windows.

### 3. GitHub template repository

Click **Use this template** on
[the repository](https://github.com/aidilikbar/llm-wiki-workspace), clone your new repo,
then flatten it:

```bash
bash install.sh --full --eject .
```

`--eject` moves the workspace to the root and deletes `template/`, `install.sh`, `bin/`,
`scripts/`, `docs/` and `.github/` — the packaging, not the workspace. Your README is
replaced with a project stub only if it is still the upstream one.

### 4. Obsidian vault, no terminal

Download `llm-wiki-workspace-vault-<version>.zip` from
[Releases](https://github.com/aidilikbar/llm-wiki-workspace/releases), unzip it, and in
Obsidian choose **Open folder as vault**. Read `OPEN-ME-FIRST.md` and delete it.

## Make sure it is running

Installing files is not the same as the rules being enforced. Two steps, both quick.

**Turn on the front-matter check.** The hook ships with the workspace but git ignores it
until you point at it. This setting is per clone — anyone else who clones your repo runs
it too:

```bash
git config core.hooksPath .githooks
```

**Prove it works.** This commit must be rejected:

```bash
printf '# no front matter\n' > context/constraints/tmp-check.md
git add context/constraints/tmp-check.md && git commit -m 'should fail'
rm context/constraints/tmp-check.md
```

Expected output is `front matter missing entirely: context/constraints/tmp-check.md` and
no new commit. If the commit succeeds, `core.hooksPath` did not take effect — check that
`.githooks/pre-commit` exists and is executable.

The hook checks staged markdown only, skips `README.md`, `AGENTS.md` and `work/temp/`,
and warns without blocking when a `review_by` date has passed.

## Fill it in, in this order

1. **`context/constraints/`** — first, and it is not close. Constraints record where your
   project deliberately diverges from the statistically common pattern, which is exactly
   what an agent defaults to. Use `system/templates/constraint.md`.
2. **`system/agents/escalation.md`** — what the agent may decide alone, what it must
   propose, what it must never do without you. Skip this and the agent will either ask
   about everything or ask about nothing.
3. **The `## Commands` block at the bottom of `AGENTS.md`** — your real install, test,
   lint and build invocations. Exact commands, not descriptions.
4. **`state/STATE.md`** — at the end of every working session. One screen, no history.
5. **`record/logbook/`** — append as you go. Never edit an entry afterwards.

Everything else can stay a `TODO` until something forces it. The installer stamps
`updated:` with the install date, so the freshness clock starts the day you adopt it.

Expect the first two weeks to feel like overhead. The return arrives the first time a new
session picks up mid-task without you re-explaining the project.

## Using it with Obsidian

The tree is plain markdown, so any vault works. `--obsidian` adds a config that makes the
structure legible rather than adding features:

- **Templates** plugin on, pointed at `system/templates/` — `Insert template` gives you a
  correctly shaped ADR, logbook entry or handoff, front matter included.
- **Properties** on, so `status`, `updated`, `owner` and `classification` are editable
  fields rather than raw YAML.
- **Graph colours by zone** — `context/` blue, `state/` amber, `record/` green, `work/`
  grey, `system/` purple. Zone drift becomes visible: a cluster of grey nodes that
  everything cites is `work/` content being treated as settled.
- New files and attachments default to `work/temp/`, which is the untrusted zone and is
  purged at 14 days. Nothing lands in `context/` by accident.
- Wikilinks rather than markdown links, and daily notes off.

No community plugins. Per-machine state (`workspace.json`, `cache`) is gitignored; the
shared settings are committed.

## The tree

```
.
├── README.md
├── AGENTS.md                          entry point for the agent
├── .gitignore
├── .githooks/pre-commit               front-matter check
│
├── system/                            HOW WE WORK
│   ├── RULES.md
│   ├── agents/
│   │   ├── escalation.md              what may be decided alone
│   │   ├── chief-of-staff.md
│   │   ├── designer.md
│   │   ├── engineer.md
│   │   ├── qa.md
│   │   └── technical-writer.md
│   ├── skills/
│   ├── evals/
│   ├── workflows/
│   └── templates/                     adr, constraint, handoff, logbook, sprint,
│                                      retro, release, backlog-item, icebox-item,
│                                      skill, _frontmatter
├── context/                           STABLE
│   ├── AGENTS.md
│   ├── vision.md
│   ├── principles/
│   ├── constraints/                   fill this first
│   ├── architecture/
│   ├── design/
│   └── requirements/
│
├── state/                             CURRENT
│   ├── AGENTS.md
│   ├── STATE.md                       one screen, no history
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
    ├── sources/INDEX.md
    ├── analysis/
    └── temp/
```

Each zone has its own nested `AGENTS.md`. Most coding agents read the nearest one
automatically when working inside a directory, which is the whole reason the rules live
next to the files they govern rather than in one long root file.

## Core vs optional

The default install is the core tier, deliberately. Empty folders cost real tokens —
agents glob into them, find nothing, and retry — and they signal abandonment to humans.

**Core:** `AGENTS.md`, `system/RULES.md`, `system/agents/escalation.md`,
`system/templates/`, `context/constraints/`, `context/requirements/`, `state/STATE.md`,
`state/handoff.md`, `record/decisions/`, `record/logbook/`, `work/sources/INDEX.md`,
`work/temp/`, plus the zone `AGENTS.md` files and the hook.

**Optional (`--full`):** everything else. `record/eval-runs/` when you have evals.
`context/design/` when there is a UI. `state/codebase-map.md` when the codebase outgrows
one person's head.

Re-running the installer later is safe — existing files are skipped — so starting core
and adding `--full` when you need it costs nothing.

## Customising it

- **Staleness threshold.** `state/` files are stale after 7 days. That number appears in
  `AGENTS.md`, `system/RULES.md` and `state/AGENTS.md`. Change all three or none.
- **Classification.** If your project has no confidentiality dimension, keep the field
  and set everything to `public`. Deleting it means the first sensitive file arrives with
  nowhere to go.
- **Owners.** Replace every `owner: TODO`. Never write "team" — that means nobody.
- **Zone names.** Nothing in the tooling depends on them beyond the core manifest in
  `install.sh` and the hook's skip list.
- **Tool-specific agent files.** If your agent wants its own filename instead of
  `AGENTS.md`, symlink it rather than maintaining two copies that drift.

## Repository layout

This repository is the installer, not the workspace. The payload that gets installed is
`template/`; nothing else ships to your project.

| Path | What it is |
|---|---|
| `template/` | The workspace itself — the only thing that gets installed |
| `obsidian-preset/` | Vault config, copied to `.obsidian/` by `--obsidian` |
| `install.sh` | Bash installer; also runs standalone by downloading the repo |
| `bin/cli.js` | Node installer for `npx`, kept identical to the bash one by CI |
| `scripts/test.sh` | The verification suite |
| `scripts/make-vault-zip.sh` | Builds the Obsidian release asset |
| `docs/decisions/` | Why this repository is shaped the way it is — also worked ADR examples |
| `docs/logbook/` | Its build history |

## Contributing and verification

```bash
bash scripts/test.sh
```

Runs the whole suite: both installers produce byte-identical trees, the core manifest
matches the template, every payload file carries valid front matter, the hook blocks a
bad commit and accepts a good one, and `--eject` leaves a bare workspace. CI runs it on
every push, on macOS as well as Linux.

The last check scans the tree for names that must never be published. The list is not in
this repository — publishing it would leak the thing it exists to prevent. Put one term
per line in `.private-names` (gitignored) or point `LWW_DENYLIST` at a file elsewhere;
without one, that check is skipped.

Changes to `template/` need a matching entry in `docs/decisions/` when they are expensive
to reverse or had a real alternative — the same rule the workspace asks of its users.

## Licence

CC0 1.0 — public domain. Take it, cut it down, rename the zones. Attribution is welcome
and not required.
