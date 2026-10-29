#!/usr/bin/env bash
#
# LLM Wiki Workspace — installer
#
# Run it in the folder where you want the workspace. It asks a few questions, then
# generates the structure — the way a framework installer scaffolds a new project:
#
#   curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh | bash
#
# Every question has a flag, so it also runs unattended:
#
#   bash install.sh --yes --full --obsidian --git my-project
#   bash install.sh --yes --handoff path/to/code-repo
#
# Existing files are never overwritten unless you pass --force.

set -euo pipefail

VERSION="0.1.0"
REPO_SLUG="${LWW_REPO:-aidilikbar/llm-wiki-workspace}"
REF="${LWW_REF:-main}"

# Unset means "ask, or fall back to the default when not interactive".
MODE=""          # workspace | handoff
TARGET=""
TIER=""          # core | full
OBSIDIAN=""      # 1 | 0
GIT=""           # 1 | 0
HANDOFF_IGNORE="" # 1 | 0
FORCE=0
EJECT=0
DRY=0
ASSUME_YES=0

# Paths inside template/ that make up the core tier. Everything else is --full only.
# CI checks that every entry exists.
CORE_PATHS="
AGENTS.md
.gitignore
.githooks/pre-commit
system/RULES.md
system/agents/escalation.md
system/templates
context/AGENTS.md
context/constraints
context/requirements
state/AGENTS.md
state/STATE.md
state/handoff.md
state/backlog
record/AGENTS.md
record/decisions
record/logbook
record/backlog
work/AGENTS.md
work/sources/INDEX.md
work/temp
"

# Removed from the target by --eject: the packaging, not the workspace.
EJECT_PATHS="
template
handoff
install.sh
bin
scripts
obsidian-preset
package.json
package-lock.json
docs
.github
"

HANDOFF_MARKER="llm-wiki-workspace:handoff-protocol"

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
LLM Wiki Workspace installer

usage: install.sh [options] [folder]

With no options in a terminal, it asks what to set up. Any flag answers its question.

what to install:
  (default)         a workspace — the knowledge base your agents read and write
  --handoff         a .handoff/ task exchange in an existing code repo instead

workspace options:
  --core            only the files you fill in during week one (default)
  --full            every folder, including design, architecture, evals
  --obsidian        also write .obsidian/ so the folder opens as a vault
  --no-obsidian     do not write .obsidian/
  --git             git init if needed and turn on the front-matter check
  --no-git          leave git alone
  --eject           delete the packaging afterwards (for "Use this template" clones)

handoff options:
  --handoff-ignore  add .handoff/ to the code repo's .gitignore
                    (for restricted or air-gapped repos)

general:
  -y, --yes         never ask; use the flags given and defaults for the rest
  --force           overwrite files that already exist
  --dry-run         print what would happen, write nothing
  --version         print the installer version
  -h, --help        this text

folder defaults to the current directory. For a workspace it is created if missing.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --handoff)          MODE="handoff" ;;
    --core)             TIER="core" ;;
    --full)             TIER="full" ;;
    --obsidian)         OBSIDIAN=1 ;;
    --no-obsidian)      OBSIDIAN=0 ;;
    --git)              GIT=1 ;;
    --no-git)           GIT=0 ;;
    --handoff-ignore)   HANDOFF_IGNORE=1 ;;
    --eject)            EJECT=1 ;;
    --force)            FORCE=1 ;;
    --dry-run)          DRY=1 ;;
    -y|--yes|--no-interaction) ASSUME_YES=1 ;;
    --version)          say "$VERSION"; exit 0 ;;
    -h|--help)          usage; exit 0 ;;
    -*)                 die "unknown option: $1 (try --help)" ;;
    *)                  TARGET="$1" ;;
  esac
  shift
done

# ------------------------------------------------------------------ prompting
# Answers are read from the terminal, not stdin, so this works when the script itself
# arrives on stdin through `curl | bash`. LWW_TTY points at a file of answers for tests.

INTERACTIVE=0
if [ "$ASSUME_YES" -eq 0 ] && [ -z "${LWW_NONINTERACTIVE:-}" ]; then
  if { exec 3<"${LWW_TTY:-/dev/tty}"; } 2>/dev/null; then
    INTERACTIVE=1
  fi
fi

ask() { # ask <question> <default>  → REPLY
  printf ' %s [%s]: ' "$1" "$2" >&2
  IFS= read -r REPLY <&3 || REPLY=""
  [ -n "$REPLY" ] || REPLY="$2"
}

ask_yn() { # ask_yn <question> <Y|N>  → status 0 for yes
  if [ "$2" = "Y" ]; then printf ' %s [Y/n]: ' "$1" >&2; else printf ' %s [y/N]: ' "$1" >&2; fi
  IFS= read -r REPLY <&3 || REPLY=""
  case "$REPLY" in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    *)     [ "$2" = "Y" ] ;;
  esac
}

ask_choice() { # ask_choice <question> <default-index> <option>...  → REPLY (1-based)
  q="$1"; d="$2"; shift 2
  printf '\n %s\n' "$q" >&2
  i=1
  for o in "$@"; do printf '   [%d] %s\n' "$i" "$o" >&2; i=$((i + 1)); done
  printf ' > [%s]: ' "$d" >&2
  IFS= read -r REPLY <&3 || REPLY=""
  case "$REPLY" in ''|*[!0-9]*) REPLY="$d" ;; esac
  if [ "$REPLY" -lt 1 ] || [ "$REPLY" -gt $# ]; then REPLY="$d"; fi
}

if [ "$INTERACTIVE" -eq 1 ]; then
  printf '\n  LLM Wiki Workspace  v%s\n' "$VERSION" >&2

  if [ -z "$MODE" ]; then
    ask_choice "What would you like to set up?" 1 \
      "A workspace — the knowledge base your agents read and write" \
      "A .handoff/ exchange in a code repo — for the planner–executor workflow"
    if [ "$REPLY" = "2" ]; then MODE="handoff"; else MODE="workspace"; fi
  fi

  if [ -z "$TARGET" ]; then
    printf '\n' >&2
    if [ "$MODE" = "handoff" ]; then
      ask "Path to the code repo" "."
    else
      ask "Where should the workspace go? A folder name, or . for this folder" "."
    fi
    TARGET="$REPLY"
  fi

  if [ "$MODE" = "workspace" ]; then
    if [ -z "$TIER" ]; then
      ask_choice "Which structure?" 1 \
        "Core — the files you fill in during week one (recommended)" \
        "Full — every folder, including design, architecture and evals"
      if [ "$REPLY" = "2" ]; then TIER="full"; else TIER="core"; fi
    fi
    printf '\n' >&2
    if [ -z "$OBSIDIAN" ]; then
      if ask_yn "Configure it as an Obsidian vault?" "N"; then OBSIDIAN=1; else OBSIDIAN=0; fi
    fi
    if [ -z "$GIT" ]; then
      if ask_yn "Initialise git and turn on the front-matter check?" "Y"; then GIT=1; else GIT=0; fi
    fi
  else
    printf '\n' >&2
    if [ -z "$HANDOFF_IGNORE" ]; then
      if ask_yn "Commit .handoff/ to git? Answer no for restricted or air-gapped repos" "Y"
      then HANDOFF_IGNORE=0; else HANDOFF_IGNORE=1; fi
    fi
  fi
fi

# Defaults for anything still unanswered.
[ -n "$MODE" ]           || MODE="workspace"
[ -n "$TARGET" ]         || TARGET="."
[ -n "$TIER" ]           || TIER="core"
[ -n "$OBSIDIAN" ]       || OBSIDIAN=0
[ -n "$GIT" ]            || GIT=0
[ -n "$HANDOFF_IGNORE" ] || HANDOFF_IGNORE=0

if [ "$INTERACTIVE" -eq 1 ]; then
  printf '\n' >&2
  if [ "$MODE" = "handoff" ]; then
    printf '  .handoff/ exchange into %s%s\n' "${TARGET%/}/" \
      "$([ "$HANDOFF_IGNORE" -eq 1 ] && echo ', gitignored')" >&2
  else
    printf '  %s workspace into %s%s%s\n' "$TIER" "${TARGET%/}/" \
      "$([ "$OBSIDIAN" -eq 1 ] && echo ', as an Obsidian vault')" \
      "$([ "$GIT" -eq 1 ] && echo ', with git and the front-matter check')" >&2
  fi
  if ! ask_yn "Proceed?" "Y"; then
    say "Nothing written."
    exit 0
  fi
  printf '\n' >&2
fi

# ------------------------------------------------------------------ source tree
# Prefer the payload next to this script. Fall back to downloading the repository,
# which is what happens when the script is piped from curl.

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

TMPDIR_DL=""
cleanup() { if [ -n "$TMPDIR_DL" ]; then rm -rf "$TMPDIR_DL"; fi; return 0; }
trap cleanup EXIT

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/template" ]; then
  ROOT="$SCRIPT_DIR"
else
  command -v curl >/dev/null 2>&1 || die "curl is required to download the workspace"
  command -v tar  >/dev/null 2>&1 || die "tar is required to unpack the workspace"
  TMPDIR_DL=$(mktemp -d)
  url="https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$REF"
  say "Fetching $REPO_SLUG@$REF ..."
  curl -fsSL "$url" | tar xz -C "$TMPDIR_DL" || die "could not download $url"
  # Pure shell — no head(1). Some environments (conda, perl LWP) shadow it with a
  # URL fetcher that does not understand -n.
  ROOT=""
  for d in "$TMPDIR_DL"/*/; do ROOT="${d%/}"; break; done
  [ -n "$ROOT" ] && [ -d "$ROOT/template" ] || die "downloaded archive has no template/ directory"
fi

SRC="$ROOT/template"
PRESET="$ROOT/obsidian-preset"
HANDOFF_SRC="$ROOT/handoff"

# ------------------------------------------------------------------ helpers
TODAY=$(date +%F)
installed=0
skipped=0

# Stamp the install date onto a file's own `updated:` field, but only when the value
# is a real date. Templates carry the literal YYYY-MM-DD and keep it.
stamp_date() {
  f="$1"
  IFS= read -r first < "$f" || first=""
  [ "$first" = "---" ] || return 0
  awk -v today="$TODAY" '
    NR == 1 { print; next }
    !done && /^---$/ { done = 1; print; next }
    !done && /^updated: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print "updated: " today; next }
    { print }
  ' "$f" > "$f.lww-tmp" && mv "$f.lww-tmp" "$f"
}

# copy_tree <source-root> <dest-root> <stamp:1|0>  (file list on stdin, relative paths)
copy_tree() {
  src_root="$1"; dest_root="$2"; stamp="$3"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="$dest_root/$rel"
    if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
      skipped=$((skipped + 1))
      continue
    fi
    if [ "$DRY" -eq 1 ]; then
      say "  would write ${dest#./}"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$src_root/$rel" "$dest"
      case "$rel" in
        *.md) if [ "$stamp" -eq 1 ]; then stamp_date "$dest"; fi ;;
        .githooks/*) chmod +x "$dest" ;;
      esac
    fi
    installed=$((installed + 1))
  done
}

list_all() { (cd "$1" && find . -type f | sed 's|^\./||' | sort); }

list_core() {
  printf '%s\n' "$CORE_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -d "$SRC/$p" ]; then
      (cd "$SRC" && find "$p" -type f)
    elif [ -f "$SRC/$p" ]; then
      printf '%s\n' "$p"
    else
      warn "warning: core path missing from template: $p"
    fi
  done | sort -u
}

# append_block <file>: add the handoff protocol once, keyed on its marker.
append_block() {
  f="$1"
  if [ -f "$f" ] && grep -q "$HANDOFF_MARKER" "$f"; then
    say "  $(basename "$f") already has the handoff protocol"
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    say "  would add the handoff protocol to $(basename "$f")"
    return 0
  fi
  if [ -s "$f" ]; then
    printf '\n' >> "$f"
  else
    printf '# AGENTS.md\n\n' > "$f"
  fi
  cat "$HANDOFF_SRC/_agents-block.md" >> "$f"
  say "  added the handoff protocol to $(basename "$f")"
}

# ------------------------------------------------------------------ handoff mode
if [ "$MODE" = "handoff" ]; then
  [ -d "$TARGET" ] || die "no such folder: $TARGET — --handoff installs into an existing code repo"
  [ -d "$HANDOFF_SRC" ] || die "handoff payload not found at $HANDOFF_SRC"
  if [ -e "$TARGET/system/RULES.md" ] && [ -d "$TARGET/state" ]; then
    warn "warning: $TARGET looks like a workspace, not a code repo. .handoff/ belongs in the code repo."
  fi
  if [ "$DRY" -eq 1 ]; then say "DRY RUN — nothing will be written"; fi
  say "Setting up .handoff/ in ${TARGET%/}/"

  # Process substitution, not a pipe: copy_tree must run in this shell so its counters survive.
  copy_tree "$HANDOFF_SRC" "$TARGET/.handoff" 0 < <(list_all "$HANDOFF_SRC" | grep -v '^_agents-block\.md$')

  append_block "$TARGET/AGENTS.md"

  claude="$TARGET/CLAUDE.md"
  if [ -L "$claude" ]; then
    say "  CLAUDE.md is a link; left as it is"
  elif [ -f "$claude" ]; then
    append_block "$claude"
  elif [ "$DRY" -eq 1 ]; then
    say "  would link CLAUDE.md to AGENTS.md"
  else
    (cd "$TARGET" && ln -s AGENTS.md CLAUDE.md)
    say "  linked CLAUDE.md to AGENTS.md"
  fi

  if [ "$HANDOFF_IGNORE" -eq 1 ]; then
    gi="$TARGET/.gitignore"
    if [ -f "$gi" ] && grep -qx '\.handoff/' "$gi"; then
      say "  .gitignore already ignores .handoff/"
    elif [ "$DRY" -eq 1 ]; then
      say "  would add .handoff/ to .gitignore"
    else
      if [ -s "$gi" ] && [ -n "$(tail -c 1 "$gi")" ]; then printf '\n' >> "$gi"; fi
      printf '.handoff/\n' >> "$gi"
      say "  added .handoff/ to .gitignore"
    fi
  fi

  say ""
  say "Wrote $installed file(s); skipped $skipped that already existed."
  cat <<NEXT

Next:

  1. The planner writes .handoff/tasks/T-001.md from .handoff/templates/task.md
  2. Tell the executor, in this repo:  run T-001
  3. Tell the planner:                 review T-001

The full loop is in system/workflows/planner-executor.md in your workspace.
NEXT
  exit 0
fi

# ------------------------------------------------------------------ workspace mode
if [ "$DRY" -eq 1 ]; then say "DRY RUN — nothing will be written"; fi
say "Installing the $TIER workspace into ${TARGET%/}/"
[ "$DRY" -eq 1 ] || mkdir -p "$TARGET"

if [ "$TIER" = "full" ]; then
  copy_tree "$SRC" "$TARGET" 1 < <(list_all "$SRC")
else
  copy_tree "$SRC" "$TARGET" 1 < <(list_core)
fi

if [ "$OBSIDIAN" -eq 1 ]; then
  [ -d "$PRESET" ] || die "obsidian preset not found at $PRESET"
  copy_tree "$PRESET" "$TARGET/.obsidian" 0 < <(list_all "$PRESET")
fi

if [ "$EJECT" -eq 1 ]; then
  printf '%s\n' "$EJECT_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$TARGET/$p" ] || continue
    if [ "$DRY" -eq 1 ]; then say "  would remove $p"; else rm -rf "${TARGET:?}/$p"; fi
  done
  if [ -f "$TARGET/README.md" ] && grep -q 'llm-wiki-workspace:upstream-readme' "$TARGET/README.md"; then
    if [ "$DRY" -eq 1 ]; then
      say "  would replace README.md with a project stub"
    else
      cat > "$TARGET/README.md" <<'STUB'
# <project name>

An LLM Wiki Workspace. Zones: `context/` stable, `state/` current, `record/`
append-only, `work/` untrusted. Start at `AGENTS.md`, then `system/RULES.md`.
STUB
    fi
  fi
fi

HOOK_ON=0
if [ "$GIT" -eq 1 ]; then
  if ! command -v git >/dev/null 2>&1; then
    warn "warning: git not found; skipped git init and the front-matter check"
  elif [ "$DRY" -eq 1 ]; then
    say "  would initialise git and set core.hooksPath to .githooks"
  else
    abs_target=$(cd "$TARGET" && pwd -P)
    if top=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null); then
      top=$(cd "$top" && pwd -P)
      if [ "$top" != "$abs_target" ]; then
        warn "warning: $TARGET is inside the git repository at $top."
        warn "         core.hooksPath is relative to that repository's root, so it was not set."
      else
        git -C "$TARGET" config core.hooksPath .githooks
        HOOK_ON=1
      fi
    else
      git -C "$TARGET" init -q
      git -C "$TARGET" config core.hooksPath .githooks
      say "  initialised a git repository"
      HOOK_ON=1
    fi
    if [ "$HOOK_ON" -eq 1 ]; then say "  front-matter check is on (core.hooksPath = .githooks)"; fi
  fi
fi

say ""
say "Wrote $installed file(s); skipped $skipped that already existed."
if [ "$skipped" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
  say "Re-run with --force to overwrite the skipped files."
fi

step=1
printf '\nNext, in %s/:\n\n' "${TARGET%/}"
if [ "$HOOK_ON" -eq 0 ]; then
  printf '  %d. git config core.hooksPath .githooks     turn on the front-matter check\n' "$step"; step=$((step + 1))
fi
printf '  %d. fill context/constraints/               highest-value folder in the tree\n' "$step"; step=$((step + 1))
printf '  %d. fill system/agents/escalation.md        what the agent may decide alone\n' "$step"; step=$((step + 1))
printf '  %d. fill the Commands block in AGENTS.md    your real install/test/lint commands\n' "$step"
cat <<'VERIFY'

Verify the check is live:

  printf '# no front matter\n' > context/constraints/tmp-check.md
  git add context/constraints/tmp-check.md && git commit -m 'should fail'
  rm context/constraints/tmp-check.md

The commit must be rejected. If it is not, the hook is not on.
VERIFY

exit 0
