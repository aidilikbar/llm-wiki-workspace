# record/ — append-only

Permanent. This zone is the project's memory and its value comes from being unedited.

- Append new files only. Never edit, reword, or delete an existing entry.
- A superseded decision is not corrected. Write a new one with `supersedes: <id>`.
- Decision records must state the rejected options and why. A record without rejected
  alternatives does not stop the next session re-litigating the same choice.
- Decisions live in one folder with a `type:` field. Do not create per-type subfolders.
- Filenames are zero-padded and never renumbered: `0042-short-slug.md`.
- If you believe an entry is factually wrong, append a correction entry. Do not touch
  the original.
