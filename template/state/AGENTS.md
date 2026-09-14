# state/ — current

High trust only while fresh. Check `updated` on every file before use.

- Stale threshold: 7 days. Past that, flag it and ask before treating it as current.
- Update freely; this is the one zone you own day to day.
- One truth per fact. If two files disagree, fix one — do not annotate the conflict.
- `STATE.md` stays at one screen. Overflow goes to `record/`, not into a longer STATE.
- `handoff.md` must end with one concrete next action, not a summary of what happened.
- `codebase-map.md` is generated. Never hand-edit it; regenerate it.
- Closed sprints move to `record/sprints/`. `sprint-current.md` holds exactly one sprint.
