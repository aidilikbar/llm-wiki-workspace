---
status: active
updated: 2026-09-14
owner: TODO
classification: public
---

# 2026-09-14 — The curl install route died on a shadowed `head`

**Worked on:** A failure report from the one-line install: `Unknown option: n` followed
by `Usage: head [-options] <url>...` and no files written.

**Outcome:** shipped

**What happened:**
`head` on the reporting machine was not coreutils. A conda `base` environment was active
and put perl LWP's `head` — a URL fetcher — earlier on `PATH`, so `head -n 1` parsed as
a malformed HTTP request and the installer aborted before writing anything. Two call
sites were affected: picking the extracted directory out of the downloaded tarball, and
the front-matter date stamp reading a file's first line. Both were rewritten without
`head`: a glob loop for the first, `IFS= read -r first < "$f"` for the second. The only
other coreutils dependency in a shipped script, a `tail -3` in the zip builder, became an
`awk` one-liner. Verified against the real scenario — shadowed `head` and the download
route together — and the tree now installs cleanly.

**What surprised us:**
The suite ran green on a machine where the product was broken. Every test invoked
`install.sh` through `bash`, inheriting a clean `PATH`, so the shadowing never occurred
under test. Portability was being checked across operating systems in CI and not at all
across environments, which is where this actually broke: same OS, same shell, different
`PATH`. The suite now runs the installers with a deliberately hostile `head` on `PATH`,
and separately exercises the standalone download route with no `template/` beside the
script — the two things the green run was not covering.

The general form is worth keeping: a script that shells out to a common utility has taken
a dependency on the user's `PATH`, not on the utility. `head`, `timeout`, `sort` and
`date` are all shadowed by something in common developer environments.

**Follow-ups:**
- [ ] Push the fix; the raw URL still serves the broken installer until then → backlog
- [ ] Consider a CI job that runs the suite inside an activated conda env → icebox
