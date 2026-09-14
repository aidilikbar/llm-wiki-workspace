---
status: active
updated: 2026-09-14
owner: TODO
classification: public
type: product
supersedes:
---

# 0007 — Obsidian support ships as an opt-in flag, not as the default

## Context

The tree is plain markdown with YAML front matter, which is already an Obsidian vault in
everything but configuration. Configuring it — templates folder, properties view, graph
colours by zone, new files defaulting to the untrusted zone — turns the structure from
something you have to remember into something the editor shows you. But a `.obsidian/`
directory is not inert: it overrides an existing vault's settings, and it is meaningless
noise in a repository whose users work in an editor and a terminal.

## Options considered

### A — Ship `.obsidian/` in every install
Trade-off: costs every non-Obsidian adopter an unexplained directory, and costs Obsidian
users with an existing config a merge they did not ask for. Buys "it just works" with no
flag to discover.

### B — Document the conventions, ship no config
Trade-off: costs the entire benefit — an unconfigured vault shows the tree as a file
list, which is what every other wiki looks like. Buys zero risk of clobbering.

### C — Plain by default, `--obsidian` writes the config
Trade-off: costs a second install path that has to be tested, and the flag has to be
discoverable or it may as well not exist. Buys both audiences the right default.

## Decision

We chose C. The config is genuinely useful — zone colours in the graph make zone drift
visible, which is the failure this layout is built to prevent — but it is useful to a
subset, and writing editor configuration into someone's repository uninvited is the kind
of quiet decision the escalation rules exist to stop.

## Rejected, and why

- **A** — rejected because it writes to a file the user's editor owns. An install that
  changes settings the adopter did not ask about is the same class of error as an agent
  making a plausible decision quietly.
- **B** — rejected because the conventions alone do not survive contact with a real vault.
  Told to "point Obsidian at `system/templates`", most people will not.

## Consequences

Easier: one command produces a vault that opens correctly, and the zip release for
non-terminal users is the same install with the flag already set.

Harder: two install paths to keep working, and the Obsidian config is now a compatibility
surface — a future Obsidian release that changes the `core-plugins.json` format breaks it
silently. The verification suite checks the files are valid JSON and that the templates
folder points where it claims, which catches corruption but not a schema change upstream.

Committed to: no community plugins in the preset, per-machine vault state staying
gitignored, and the config remaining small enough to read in one sitting.

## Revisit if

Obsidian changes its config format in a way that makes the preset version-specific. At
that point the honest move is to ship the smallest config that survives version changes
and document the rest.
