---
status: active
updated: 2026-09-14
owner: TODO
classification: public
---

# 2026-09-14 — Repository turned into an installable package

**Worked on:** Converting the repository from "clone this and delete our stuff" into a
package that installs the workspace into someone else's project or Obsidian vault.

**Outcome:** shipped

**What happened:**
The tree moved wholesale into `template/`, which is now the only thing that ships. The
repository's own decision records and logbook moved to `docs/`, so an adopter no longer
inherits them. Four install routes were built on the same payload: `install.sh` (which
downloads the repository when it is piped from curl and has no `template/` beside it),
`bin/cli.js` for `npx`, `--eject` for the GitHub "Use this template" button, and a zip
release built by `scripts/make-vault-zip.sh`. Obsidian support went in behind
`--obsidian`: templates folder, properties view, graph coloured by zone, new files
defaulting to `work/temp/`. Gaps from the old tree were filled — the five role files the
README had always listed, a `constraint.md` template for the folder the README calls the
highest-value one, and a rewritten pre-commit hook that parses to the closing `---`
instead of `head -n 10` and warns on a passed `review_by`. `scripts/test.sh` now runs 51
checks and CI runs it on Linux and macOS. Decisions 0006 and 0007 record the package
framing and the Obsidian flag; 0006 supersedes 0005.

**What surprised us:**
Two things, both of them the tooling disagreeing with its own tests.

`install.sh` exited 1 on every successful run and the suite did not notice, because every
test asserted on files existing rather than on the exit code. The cause was the EXIT trap:
`cleanup() { [ -n "$TMPDIR_DL" ] && rm -rf "$TMPDIR_DL"; }` returns 1 when there is
nothing to clean, and a trap's status becomes the script's. It only showed up when
`make-vault-zip.sh` called the installer under `set -e` and died silently. A test that
checks outputs but never checks exit status will hide this class of bug indefinitely.

The private-name scan passed for the wrong reason and then failed for the right one: the
denylist was written into the test file, so the test found its own terms. Any denylist
that lives in the repository it protects publishes exactly what it is meant to suppress.
It now reads a gitignored file and skips when there is none.

**Follow-ups:**
- [ ] Publish v1.0.0 and confirm the curl route works against the real raw URL → backlog
- [ ] Enable "Template repository" and set description/topics on GitHub → backlog
- [ ] Decide whether to publish to npm, which needs a token in repository secrets → decision
