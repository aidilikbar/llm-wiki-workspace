---
status: active
updated: 2026-09-11
owner: <human owner>
classification: public
type: data
supersedes:
---

# 0003 — Every file carries a classification, and derived files inherit the highest of their inputs

## Context

Agents move text between contexts for a living: they read a source, write a summary,
paste the summary into a prompt, and send the prompt to a model that may be someone
else's. Sensitivity travels with the content, but nothing in a plain markdown file
records it, so at the moment of sending there is nothing to check. The workspace needed
a sensitivity marker that is present before it is needed, and a rule for what happens
when files are combined. What we did not know: how many adopters have a confidentiality
dimension at all.

## Options considered

### A — Four levels on every file, derived files take the highest of their inputs
Trade-off: costs a field on every file including throwaway scratch, and a rule that has
to be applied by hand at each derivation. Buys a check that can be made mechanically at
the moment of sending, and a default — no classification means treat as `restricted` —
that fails closed.

### B — No classification field; add one when the first sensitive file arrives
Trade-off: costs nothing up front and keeps the front matter to three fields. Buys a
retrofit: the first sensitive file arrives with nowhere to put the marker, and every
file already written has to be classified retroactively by someone reconstructing where
it came from.

### C — Classification set per zone or per folder rather than per file
Trade-off: costs far less bookkeeping — one marker covers a directory. Buys a rule that
breaks precisely where it matters: a summary of a restricted source written into
`state/` picks up `state/`'s classification and quietly launders its origin.

## Decision

We chose A, because the classification has to survive derivation, and only a per-file
marker plus an inheritance rule does that. The inheritance rule is the substance here;
the four levels are just labels.

## Rejected, and why

- **B** — rejected because the retrofit is the expensive part and it lands exactly when
  you are least able to afford it. Keeping the field and setting everything to `public`
  costs one line per file and leaves somewhere for the first sensitive file to go.
- **C** — rejected because it attaches sensitivity to location while the whole point of
  the workspace is that content moves between locations. A marker that a file loses when
  it is promoted is worse than no marker, because it looks like a check.

## Consequences

Easier: deciding whether something may be sent to an external model — read one field,
compare against the provider agreement. `work/sources/INDEX.md` becomes the place the
chain starts, and derivation is auditable backwards from any file.

Harder: every scratch file needs a field nobody wants to write, and inheritance has to
be applied by a person or agent who may not know all the inputs. Downgrading requires a
human and a decision record, which makes correcting an over-cautious classification
slower than setting it.

Committed to: the four levels being stable names, since they appear in front matter
across the whole tree, and to fail-closed behaviour when the field is missing.

## Revisit if

Adopters routinely set everything to `public` and the field becomes noise — or the
opposite, if the inheritance rule is silently skipped often enough that the field is
trusted while being wrong. A field that lies is worse than one that is absent.
