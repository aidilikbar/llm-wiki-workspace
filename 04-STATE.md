---
status: current
updated: 2026-09-11
owner: <human owner>
classification: internal
---

# STATE

One screen. If it does not fit, the excess belongs in `record/`. Rewrite in place — this
file has no history.

## Now

<One sentence: what is actively being worked on.>

## Sprint

- **Sprint:** <number / name>, ends <date>
- **Goal:** <one sentence>
- **On track:** yes / no / at risk — <why, if not yes>

## Open decisions

Decisions that are blocking or will block. Remove the line once it reaches
`record/decisions/`.

| # | Question | Waiting on | Since |
|---|---|---|---|
| 1 | <question> | <who> | <date> |

## Blocked

| Item | Blocked by | Since | Action to unblock |
|---|---|---|---|
| <item> | <cause> | <date> | <concrete next step> |

## Recently changed

Last 3–5 material changes only. Older entries go to `record/logbook/`.

- <date> — <what changed and why it matters>

## Known stale

Files whose `updated` date has passed its review cadence and that someone is currently
trusting anyway.

- `<path>` — last updated <date>, <what may be wrong>

---

## Example (delete this section)

**Now:** Reworking the ingestion pipeline to handle documents with no machine-readable
date field.

**Sprint:** 14, ends 2026-09-19. Goal: ingestion handles the full source corpus without
manual pre-processing. On track: at risk — the undated-document case was not scoped.

**Open decisions:** (1) Infer missing dates from document content, or reject and queue for
manual review? Waiting on owner since 2026-09-09.

**Blocked:** Eval suite — blocked by undated-document handling since 2026-09-09. Unblocks
once decision 1 lands.

**Recently changed:** 2026-09-10 — schema gained a `date_confidence` field; existing rows
backfilled as `null`, not `0`, so absence stays distinguishable from low confidence.
