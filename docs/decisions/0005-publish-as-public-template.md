---
status: superseded
updated: 2026-09-11
owner: <human owner>
classification: public
type: product
supersedes:
---

# 0005 — This workspace is published as a public template repository

## Context

The layout was written for one person's own projects and works whether or not anyone
else sees it. Publishing changes what the repository has to be: an example someone can
clone, which means it has to contain no material from the projects it was developed
against, and it has to survive the obvious objection that the author does not use it
himself. It started life as a Gist, which is where the numbered flat files came from.

## Options considered

### A — Public repository, laid out in its own structure
Trade-off: costs a permanent editorial constraint — every file is `public`, no real
project content can ever be committed, and the example decision records and state files
have to be maintained as examples rather than as working notes. Buys a template that can
be cloned, forked and criticised, and the credibility of the layout being visibly used by
the repository that describes it.

### B — Keep it as a Gist
Trade-off: costs nothing to maintain and is easy to share as a link. Buys a flat file
list, which cannot express the one thing the document is about. The tree exists only as a
picture inside a README, and the numbered-prefix filenames are a workaround for that
limitation.

### C — Private repository, shared on request
Trade-off: costs little and keeps the option open. Buys almost none of the value —
no forks, no outside pressure to keep it honest, and the same maintenance burden as A
for a fraction of the reach.

## Decision

We chose A. A layout argument that is only described, never demonstrated, is unfalsifiable
— the repository dogfooding its own rules is the evidence. That the structure survived
being applied to itself, including the parts that were inconvenient, is most of what makes
it worth publishing.

## Rejected, and why

- **B** — rejected because a flat Gist cannot demonstrate a tree. The numbered files were
  an artifact of that limitation, and converting them into the real structure is what this
  session did.
- **C** — rejected because the discipline is the point. A private copy attracts no
  scrutiny, and the repository would drift back into being working notes.

## Consequences

Easier: adoption — clone, run the bootstrap, delete this repository's own records. The
constraint that everything is publishable also keeps the writing general, which is what
makes it reusable.

Harder: the repository cannot double as anyone's real workspace. Its `state/` and
`record/` entries describe work on the template itself, and an adopter has to be told
explicitly to clear them — otherwise they inherit someone else's history as if it were
theirs. Every future change is a public change.

Committed to: everything in this repository being publishable, an audit that no employer
or private project is named anywhere in the tree, and a licence choice, which is still
open. The bootstrap stubs still carry `classification: internal`, which a public
repository contradicts; changing a classification requires an explicit human decision
under `system/agents/escalation.md`, so it stands open rather than being corrected here.

## Revisit if

Keeping the examples current becomes a burden that distorts them — example state that is
written to look good rather than to be true is worse than no example, and at that point
the examples should be cut down rather than the repository made private.
