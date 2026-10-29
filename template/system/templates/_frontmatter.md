---
status: active
updated: 2026-01-01
owner: TODO
classification: public
---

# Front matter schema

Every markdown file in this workspace carries YAML front matter. This is the mechanism
that makes staleness visible; without it, a two-year-old requirements document loads with
exactly the same authority as one written this morning.

## Required on every file

```yaml
---
status: draft | active | superseded | archived
updated: YYYY-MM-DD
owner: <name or role>
classification: public | internal | restricted | air-gapped
---
```

| Field | Notes |
|---|---|
| `status` | `draft` means not yet trustworthy. `superseded` files stay in place; they are not deleted. Collection items use their own vocabulary — see below. |
| `updated` | The date the **content** changed, not the date the file was touched. Reformatting is not an update. |
| `owner` | A person or a role from `system/agents/`. Never "team" — that means nobody. |
| `classification` | See `system/RULES.md` §1. Absent means treat as `restricted`. |

## Conditional fields

```yaml
type: architecture | product | process | data    # decisions only
supersedes: 0031                                  # decisions only, when replacing one
generated: true                                   # never hand-edit this file
source: <generator command>                       # required when generated: true
review_by: YYYY-MM-DD                             # context/ default updated + 90d; research + 30d
tags: [ingestion, schema]                         # optional, keep under 5
id: T-012                                         # collection items with an ID (RULES §9)
kind: functional | non-functional                 # requirements only
promoted-to: record/decisions/0007-slug.md        # research only, once promoted
backlog-ref: state/backlog/T-012-slug.md          # .handoff/ task files only
```

## Status by file type

`status` is required everywhere; its values depend on what the file is.

| File | `status` values |
|---|---|
| Most files, requirements | `draft`, `active`, `superseded`, `archived` |
| Decisions | `proposed`, `active`, `superseded` |
| Backlog items | `ready`, `needs-refinement`, `blocked`, `in-progress`, `done`, `dropped` |
| Icebox items | `iced` |
| Sprints | `current`, `closed` |
| Research | `open`, `concluded`, `promoted`, `abandoned` |
| Prompts | `draft`, `active`, `retired` |
| `.handoff/` tasks | `ready`, `in-progress`, `done`, `blocked` |
| `.handoff/` results | `done`, `partial`, `blocked` |

## Examples

Decision record:

```yaml
---
status: active
updated: 2026-09-10
owner: engineer
classification: internal
type: architecture
supersedes: 0031
---
```

Generated file:

```yaml
---
status: active
updated: 2026-09-11
owner: engineer
classification: internal
generated: true
source: make codebase-map
---
```

## Enforcement

Written rules that nothing checks will drift. Add a pre-commit hook or CI step that
rejects any markdown file missing the four required fields, and warns on files whose
`review_by` has passed. The check is twenty lines and it is the difference between a
convention and a habit.

Minimal check:

`README.md` and `AGENTS.md` are exempt at every level — they are entry points, not wiki
content, and `AGENTS.md` must stay parseable by tools that expect plain markdown.
`work/temp/` is exempt because it is purged anyway.

```bash
#!/usr/bin/env bash
# fails if any staged .md lacks required front matter
fail=0
while IFS= read -r f; do
  for k in status updated owner classification; do
    head -n 10 "$f" | grep -q "^$k:" || { echo "front matter missing '$k': $f"; fail=1; }
  done
done < <(git diff --cached --name-only --diff-filter=ACM \
         | grep '\.md$' \
         | grep -v '^work/temp/' \
         | grep -vE '(^|/)(README|AGENTS)\.md$')
exit $fail
```
