---
status: active
updated: 2026-09-11
owner: <human owner>
classification: public
type: process
supersedes:
---

# 0002 — Decisions live in one folder, separated by a `type:` field

## Context

Decision records divide naturally into architecture, product, process and data, and the
obvious move is a folder per kind. The question is what happens when a record does not
belong cleanly to one — "we will publish this repo publicly" is product and process and
has a data-classification consequence. Filing is a decision made once, in a hurry, by
whoever writes the record; retrieval happens repeatedly, often by someone who was not
there.

## Options considered

### A — One `record/decisions/` folder, kind recorded in a `type:` front-matter field
Trade-off: costs an unbrowsable folder — at a hundred records, the listing is a wall of
filenames and you need grep or a tool to filter it. Buys one obvious place to put a
record and one obvious place to look for one, and a record can carry a type that turns
out to be wrong without becoming hard to find.

### B — Separate `record/decisions/architecture/` and `record/decisions/product/`
Trade-off: costs a filing judgement on every record, and the cost of getting it wrong is
paid by the reader, not the writer. Buys a browsable tree, and a numbering sequence per
kind.

## Decision

We chose A, because misfiling costs more than filtering. A record filed under the wrong
folder is invisible to the next session, which then re-litigates the decision; a record
with the wrong `type:` is still in the list and still turns up in a grep.

## Rejected, and why

- **B** — rejected because it forces the classification at the moment of least
  information and makes the error unrecoverable by the person who suffers it. It also
  fragments the numbering: `0042` under two folders is two different decisions, and the
  cross-references stop being unambiguous.

## Consequences

Easier: writing a record — there is one destination and no judgement call. Numbering
stays a single zero-padded sequence, so `supersedes: 0031` always resolves.

Harder: browsing. Once the folder is large, filenames have to carry enough meaning to
scan, which puts weight on the slug. Anyone wanting a per-type view has to filter on
front matter rather than change directory.

Committed to: a flat, never-renumbered sequence, and to `type:` being present on every
decision record even when it is arguable.

## Revisit if

The folder passes a few hundred records and filename slugs stop being enough to find
things by eye — the answer then is an index generated from front matter, not subfolders.
