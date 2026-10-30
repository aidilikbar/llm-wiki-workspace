#!/usr/bin/env bash
#
# LLM Wiki Workspace installer
#
# Run it where the new workspace should go. It asks a few questions, generates the
# workspace, checks that it works, and writes a kick-off brief for your agent:
#
#   curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh | bash
#
# Every question has a flag, so it also runs unattended:
#
#   bash install.sh --yes --full --git --project "Recipe site" my-project
#   bash install.sh --yes --handoff path/to/code-repo
#
# To install a specific release instead of main, set LWW_REF to its tag:
#
#   curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/v0.2.1/install.sh | LWW_REF=v0.2.1 bash

set -Eeuo pipefail

VERSION="0.2.1"
REPO_SLUG="${LWW_REPO:-aidilikbar/llm-wiki-workspace}"
REF="${LWW_REF:-main}"

# Empty means "ask, or use the default when not interactive".
MODE=""; TARGET=""; TIER=""; OBSIDIAN=""; GIT=""; HANDOFF_IGNORE=""
PROJECT_NAME=""; PROJECT_ABOUT=""; OWNER=""
NAME_SET=0; ABOUT_SET=0; OWNER_SET=0
FORCE=0; MERGE=0; EJECT=0; DRY=0; ASSUME_YES=0

# Paths inside template/ that make up the core tier. CI checks every entry exists.
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
kickoff
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
ABOUT_PLACEHOLDER="Not given at install. Start by asking the human what the project is."

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
fail() {
  printf '\nInstallation failed: %s\n' "$1" >&2
  shift
  for line in "$@"; do printf '%s\n' "$line" >&2; done
  exit 1
}
# Report only from the main shell. bash 3.2, the default on macOS, also runs this trap
# inside $(...) subshells, including ones whose failure is expected and handled by an
# `if` around them. A failure that matters still reaches the main shell and is reported.
trap 'if [ "${BASH_SUBSHELL:-0}" -eq 0 ]; then fail "unexpected error on line $LINENO of install.sh, while running: $BASH_COMMAND"; fi' ERR

usage() {
  cat <<'USAGE'
LLM Wiki Workspace installer

usage: install.sh [options] [folder]

In a terminal with no --yes, it asks what to set up. Any flag answers its question.

what to install:
  (default)          a workspace: the knowledge base your agents read and write
  --handoff          a .handoff/ task exchange in an existing code repo instead

workspace:
  --project NAME     project name, used in the kick-off brief
  --about TEXT       what you are making, in a sentence or two
  --owner NAME       your name, written into each file's owner field
  --core | --full    the files you need in week one (default), or every folder
  --obsidian         also write .obsidian/ so the folder opens as a vault
  --git              git init, turn on the front-matter check, make the first commit
  --no-obsidian, --no-git

existing folders:
  The folder must be new or empty. To install into one that is not:
  --merge            add only the files that are missing
  --force            overwrite files that already exist
  --eject            for a "Use this template" clone: install into it, then delete
                     the packaging

handoff:
  --handoff-ignore   add .handoff/ to the code repo's .gitignore

general:
  -y, --yes          never ask; use the flags given and defaults for the rest
  --dry-run          print what would happen, write nothing
  --version, -h, --help
USAGE
}

need_value() { [ $# -ge 2 ] && [ -n "$2" ] || fail "$1 needs a value."; }

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
    --project)          need_value "$@"; PROJECT_NAME="$2"; NAME_SET=1; shift ;;
    --project=*)        PROJECT_NAME="${1#*=}"; NAME_SET=1 ;;
    --about)            need_value "$@"; PROJECT_ABOUT="$2"; ABOUT_SET=1; shift ;;
    --about=*)          PROJECT_ABOUT="${1#*=}"; ABOUT_SET=1 ;;
    --owner)            need_value "$@"; OWNER="$2"; OWNER_SET=1; shift ;;
    --owner=*)          OWNER="${1#*=}"; OWNER_SET=1 ;;
    --merge)            MERGE=1 ;;
    --force)            FORCE=1 ;;
    --eject)            EJECT=1 ;;
    --dry-run)          DRY=1 ;;
    -y|--yes|--no-interaction) ASSUME_YES=1 ;;
    --version)          say "$VERSION"; exit 0 ;;
    -h|--help)          usage; exit 0 ;;
    -*)                 fail "unknown option $1." "Run with --help to see the options." ;;
    *)                  TARGET="$1" ;;
  esac
  shift
done

# ------------------------------------------------------------------ prompting
# Answers come from the terminal, not stdin, so this works when the script itself
# arrives on stdin through `curl | bash`. LWW_TTY points at a file of answers for tests.

INTERACTIVE=0
if [ "$ASSUME_YES" -eq 0 ] && [ -z "${LWW_NONINTERACTIVE:-}" ]; then
  if { exec 3<"${LWW_TTY:-/dev/tty}"; } 2>/dev/null; then INTERACTIVE=1; fi
fi

ask() { # ask <question> [default] -> REPLY
  if [ -n "${2:-}" ]; then printf ' %s [%s]: ' "$1" "$2" >&2; else printf ' %s: ' "$1" >&2; fi
  IFS= read -r REPLY <&3 || REPLY=""
  if [ -z "$REPLY" ]; then REPLY="${2:-}"; fi
}

ask_yn() { # ask_yn <question> <Y|N> -> status 0 for yes
  if [ "$2" = "Y" ]; then printf ' %s [Y/n]: ' "$1" >&2; else printf ' %s [y/N]: ' "$1" >&2; fi
  IFS= read -r REPLY <&3 || REPLY=""
  case "$REPLY" in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    *)     [ "$2" = "Y" ] ;;
  esac
}

ask_choice() { # ask_choice <question> <default> <option>... -> REPLY (1-based)
  q="$1"; d="$2"; shift 2
  printf '\n %s\n' "$q" >&2
  i=1
  for o in "$@"; do printf '   [%d] %s\n' "$i" "$o" >&2; i=$((i + 1)); done
  printf ' > [%s]: ' "$d" >&2
  IFS= read -r REPLY <&3 || REPLY=""
  case "$REPLY" in ''|*[!0-9]*) REPLY="$d" ;; esac
  if [ "$REPLY" -lt 1 ] || [ "$REPLY" -gt $# ]; then REPLY="$d"; fi
}

# A folder counts as empty when it is missing or holds only .git or .DS_Store.
dir_is_empty() {
  [ -d "$1" ] || return 0
  for e in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    case "${e##*/}" in .git|.DS_Store) continue ;; esac
    return 1
  done
  return 0
}

shown_path() { if [ "$1" = "." ]; then printf './'; else printf '%s/' "${1%/}"; fi; }

# The folder that will actually be written to: the target if it exists, otherwise the
# nearest existing folder above it (where the target would be created).
writable_base() {
  d="$1"
  while [ ! -e "$d" ]; do
    parent=$(dirname "$d")
    if [ "$parent" = "$d" ]; then break; fi
    d="$parent"
  done
  printf '%s' "$d"
}

if [ "$INTERACTIVE" -eq 1 ]; then
  printf '\n  LLM Wiki Workspace  v%s\n' "$VERSION" >&2
  if [ -z "$MODE" ]; then
    ask_choice "What would you like to set up?" 1 \
      "A workspace: the knowledge base your agents read and write" \
      "A .handoff/ exchange in a code repo, for the planner-executor workflow"
    if [ "$REPLY" = "2" ]; then MODE="handoff"; else MODE="workspace"; fi
  fi
  if [ -z "$TARGET" ]; then
    printf '\n' >&2
    if [ "$MODE" = "handoff" ]; then
      ask "Path to the code repo" "."
    elif dir_is_empty "."; then
      ask "Folder for the workspace (a new folder name, or . for this one)" "."
    else
      ask "Folder for the workspace (a new folder name)" "my-workspace"
    fi
    TARGET="$REPLY"
  fi
fi

[ -n "$MODE" ]   || MODE="workspace"
[ -n "$TARGET" ] || TARGET="."
SHOWN=$(shown_path "$TARGET")

# ------------------------------------------------------------------ preflight
# Checked before the remaining questions, so nobody answers five questions to be told
# the folder was never usable.

if [ "$MODE" = "handoff" ]; then
  if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
    fail "$SHOWN is a file, not a folder." "--handoff installs into the folder of an existing code repo."
  fi
  [ -d "$TARGET" ] || fail "$SHOWN does not exist." \
    "--handoff installs into an existing code repo. Check the path."
  if [ "$DRY" -eq 0 ] && [ ! -w "$TARGET" ]; then
    fail "cannot write to $SHOWN (permission denied)." "Check the folder's permissions, or choose another folder."
  fi
  if [ "$FORCE" -eq 0 ] && [ -e "$TARGET/system/RULES.md" ] && [ -d "$TARGET/state" ]; then
    fail "$SHOWN looks like a workspace, not a code repo." \
      "The .handoff/ exchange goes in the code repo the executor works in." \
      "Run again with --force to install it here anyway."
  fi
else
  if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
    fail "$SHOWN is a file, not a folder."
  fi
  base=$(writable_base "$TARGET")
  if [ "$DRY" -eq 0 ] && [ ! -w "$base" ]; then
    fail "cannot write to $(shown_path "$base") (permission denied)." "Check the folder's permissions, or choose another folder."
  fi
  if [ "$EJECT" -eq 1 ]; then MERGE=1; fi
  if [ "$MERGE" -eq 0 ] && [ "$FORCE" -eq 0 ] && ! dir_is_empty "$TARGET"; then
    fail "$SHOWN already exists and is not empty." \
      "Choose a new folder name, or run again with:" \
      "  --merge   to add only the files that are missing" \
      "  --force   to overwrite files that already exist"
  fi
fi

if [ "$INTERACTIVE" -eq 1 ]; then
  if [ "$MODE" = "workspace" ]; then
    if [ "$TARGET" = "." ]; then default_name=$(basename "$(pwd)"); else default_name=$(basename "$TARGET"); fi
    printf '\n' >&2
    if [ "$NAME_SET" -eq 0 ]; then ask "Project name" "$default_name"; PROJECT_NAME="$REPLY"; fi
    if [ "$ABOUT_SET" -eq 0 ]; then
      ask "What are you making? A sentence or two, or Enter to skip"
      PROJECT_ABOUT="$REPLY"
    fi
    if [ "$OWNER_SET" -eq 0 ]; then
      git_name=""
      if command -v git >/dev/null 2>&1; then git_name=$(git config --global user.name 2>/dev/null || true); fi
      ask "Your name, for the owner field in each file" "$git_name"
      OWNER="$REPLY"
    fi
    if [ -z "$TIER" ]; then
      ask_choice "Which structure?" 1 \
        "Core: the files you fill in during week one (recommended)" \
        "Full: every folder, including design, architecture and evals"
      if [ "$REPLY" = "2" ]; then TIER="full"; else TIER="core"; fi
    fi
    printf '\n' >&2
    if [ -z "$OBSIDIAN" ]; then
      if ask_yn "Configure it as an Obsidian vault?" "N"; then OBSIDIAN=1; else OBSIDIAN=0; fi
    fi
    if [ -z "$GIT" ]; then
      if ask_yn "Set up git, the front-matter check and a first commit?" "Y"; then GIT=1; else GIT=0; fi
    fi
  else
    printf '\n' >&2
    if [ -z "$HANDOFF_IGNORE" ]; then
      if ask_yn "Commit .handoff/ to git? Answer no for restricted or air-gapped repos" "Y"
      then HANDOFF_IGNORE=0; else HANDOFF_IGNORE=1; fi
    fi
  fi
fi

[ -n "$TIER" ]           || TIER="core"
[ -n "$OBSIDIAN" ]       || OBSIDIAN=0
[ -n "$GIT" ]            || GIT=0
[ -n "$HANDOFF_IGNORE" ] || HANDOFF_IGNORE=0
if [ -z "$PROJECT_NAME" ]; then
  if [ "$TARGET" = "." ]; then PROJECT_NAME=$(basename "$(pwd)"); else PROJECT_NAME=$(basename "$TARGET"); fi
fi
OWNER=$(printf '%s' "$OWNER" | tr -d '\r\n')
PROJECT_NAME=$(printf '%s' "$PROJECT_NAME" | tr -d '\r\n')

if [ "$INTERACTIVE" -eq 1 ]; then
  printf '\n' >&2
  if [ "$MODE" = "handoff" ]; then
    printf '  Code repo  %s\n  .handoff/  %s\n' "$SHOWN" \
      "$(if [ "$HANDOFF_IGNORE" -eq 1 ]; then echo 'gitignored'; else echo 'committed with the repo'; fi)" >&2
  else
    extras="$TIER"
    if [ "$OBSIDIAN" -eq 1 ]; then extras="$extras, Obsidian vault"; fi
    if [ "$GIT" -eq 1 ]; then extras="$extras, git"; fi
    printf '  Project    %s\n  Folder     %s\n  Owner      %s\n  Setup      %s\n' \
      "$PROJECT_NAME" "$SHOWN" "${OWNER:-not set}" "$extras" >&2
  fi
  printf '\n' >&2
  if ! ask_yn "Proceed?" "Y"; then say "Cancelled. Nothing was written."; exit 0; fi
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
  command -v curl >/dev/null 2>&1 || fail "curl is not installed, so the workspace cannot be downloaded."
  command -v tar  >/dev/null 2>&1 || fail "tar is not installed, so the workspace cannot be unpacked."
  TMPDIR_DL=$(mktemp -d)
  url="https://codeload.github.com/$REPO_SLUG/tar.gz/$REF"
  say "Downloading $REPO_SLUG@$REF ..."
  if ! curl -fsSL "$url" | tar xz -C "$TMPDIR_DL"; then
    fail "could not download $url." "Check your internet connection and try again."
  fi
  # Pure shell, no head(1): conda and perl LWP can shadow it with a URL fetcher.
  ROOT=""
  for d in "$TMPDIR_DL"/*/; do ROOT="${d%/}"; break; done
  if [ -z "$ROOT" ] || [ ! -d "$ROOT/template" ]; then fail "the downloaded archive has no template/ folder."; fi
fi

SRC="$ROOT/template"
PRESET="$ROOT/obsidian-preset"
HANDOFF_SRC="$ROOT/handoff"
KICKOFF_SRC="$ROOT/kickoff/instruction.md"

# ------------------------------------------------------------------ helpers
TODAY=$(date +%F)
export LWW_TODAY="$TODAY" LWW_OWNER="$OWNER"
installed=0
skipped=0

# On a copied markdown file: stamp `updated:` with today's date (real dates only;
# templates keep YYYY-MM-DD) and fill `owner: TODO` with the owner's name.
finish_md() {
  awk 'NR == 1 { if ($0 != "---") plain = 1; print; next }
       plain { print; next }
       !done && $0 == "---" { done = 1; print; next }
       !done && /^updated: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print "updated: " ENVIRON["LWW_TODAY"]; next }
       !done && $0 == "owner: TODO" && ENVIRON["LWW_OWNER"] != "" { print "owner: " ENVIRON["LWW_OWNER"]; next }
       { print }' "$1" > "$1.lww-tmp"
  mv "$1.lww-tmp" "$1"
}

# copy_tree <source-root> <dest-root> <finish:1|0>, relative file paths on stdin
copy_tree() {
  src_root="$1"; dest_root="$2"; finish="$3"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="$dest_root/$rel"
    if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then skipped=$((skipped + 1)); continue; fi
    if [ "$DRY" -eq 1 ]; then
      say "  would write ${dest#./}"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$src_root/$rel" "$dest"
      case "$rel" in
        *.md) if [ "$finish" -eq 1 ]; then finish_md "$dest"; fi ;;
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
    if [ -d "$SRC/$p" ]; then (cd "$SRC" && find "$p" -type f)
    elif [ -f "$SRC/$p" ]; then printf '%s\n' "$p"
    else warn "warning: core path missing from template: $p"
    fi
  done | sort -u
}

# Writes instruction.md from the kick-off template, substituting literally (no regex,
# so names and descriptions with & / \ $ survive intact).
write_instruction() {
  dest="$TARGET/instruction.md"
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then skipped=$((skipped + 1)); return 0; fi
  if [ "$DRY" -eq 1 ]; then say "  would write instruction.md"; installed=$((installed + 1)); return 0; fi
  about="$PROJECT_ABOUT"; [ -n "$about" ] || about="$ABOUT_PLACEHOLDER"
  LWW_K_NAME="$PROJECT_NAME" LWW_K_ABOUT="$about" LWW_K_OWNER="${OWNER:-TODO}" \
  awk 'function repl(s, from, to,   i, out) {
         out = ""
         while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
         return out s
       }
       { s = $0
         s = repl(s, "{{project_name}}", ENVIRON["LWW_K_NAME"])
         s = repl(s, "{{project_description}}", ENVIRON["LWW_K_ABOUT"])
         s = repl(s, "{{owner}}", ENVIRON["LWW_K_OWNER"])
         s = repl(s, "{{date}}", ENVIRON["LWW_TODAY"])
         print s }' "$KICKOFF_SRC" > "$dest"
  installed=$((installed + 1))
}

# Proves the hook works: in a throwaway repository, a file without front matter must
# be rejected and a file with it accepted. Status 0 ok, 1 accepts bad, 2 rejects good.
verify_hook() {
  t=$(mktemp -d)
  git -C "$t" init -q
  mkdir "$t/.githooks"
  cp "$1" "$t/.githooks/pre-commit"
  chmod +x "$t/.githooks/pre-commit"
  printf '# no front matter\n' > "$t/bad.md"
  git -C "$t" add bad.md
  if t_commit "$t" check-bad; then rm -rf "$t"; return 1; fi
  git -C "$t" rm -q --cached bad.md
  rm "$t/bad.md"
  printf -- '---\nstatus: draft\nupdated: %s\nowner: check\nclassification: public\n---\n\n# ok\n' "$TODAY" > "$t/good.md"
  git -C "$t" add good.md
  if ! t_commit "$t" check-good; then rm -rf "$t"; return 2; fi
  rm -rf "$t"
  return 0
}
t_commit() {
  GIT_AUTHOR_NAME=check GIT_AUTHOR_EMAIL=check@example.invalid \
  GIT_COMMITTER_NAME=check GIT_COMMITTER_EMAIL=check@example.invalid \
    git -C "$1" -c core.hooksPath=.githooks -c commit.gpgsign=false commit -q -m "$2" >/dev/null 2>&1
}

append_block() { # append_block <file> -> REPLY: status text
  f="$1"
  if [ -f "$f" ] && grep -q "$HANDOFF_MARKER" "$f"; then REPLY="protocol already present"; return 0; fi
  if [ "$DRY" -eq 1 ]; then REPLY="would add the protocol"; return 0; fi
  if [ -s "$f" ]; then printf '\n' >> "$f"; else printf '# AGENTS.md\n\n' > "$f"; fi
  cat "$HANDOFF_SRC/_agents-block.md" >> "$f"
  REPLY="protocol added"
}

# ------------------------------------------------------------------ handoff mode
if [ "$MODE" = "handoff" ]; then
  [ -d "$HANDOFF_SRC" ] || fail "the handoff files are missing from the download."
  existed=0; if [ -d "$TARGET/.handoff" ]; then existed=1; fi

  copy_tree "$HANDOFF_SRC" "$TARGET/.handoff" 0 < <(list_all "$HANDOFF_SRC" | grep -v '^_agents-block\.md$')

  append_block "$TARGET/AGENTS.md"; agents_state="$REPLY"

  claude="$TARGET/CLAUDE.md"
  if [ -L "$claude" ]; then claude_state="a link already; left as it is"
  elif [ -f "$claude" ]; then append_block "$claude"; claude_state="$REPLY"
  elif [ "$DRY" -eq 1 ]; then claude_state="would link to AGENTS.md"
  else (cd "$TARGET" && ln -s AGENTS.md CLAUDE.md); claude_state="linked to AGENTS.md"
  fi

  ignore_state=""
  if [ "$HANDOFF_IGNORE" -eq 1 ]; then
    gi="$TARGET/.gitignore"
    if [ -f "$gi" ] && grep -qx '\.handoff/' "$gi"; then ignore_state=".handoff/ already ignored"
    elif [ "$DRY" -eq 1 ]; then ignore_state="would ignore .handoff/"
    else
      if [ -s "$gi" ] && [ -n "$(tail -c 1 "$gi")" ]; then printf '\n' >> "$gi"; fi
      printf '.handoff/\n' >> "$gi"
      ignore_state=".handoff/ added"
    fi
  fi

  if command -v git >/dev/null 2>&1 && git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_state="git repository"
  else
    repo_state="not a git repository (fine; .handoff/ works without git)"
  fi

  if [ "$existed" -eq 1 ]; then files_state="$installed file(s) written, $skipped already there"
  else files_state="$installed file(s): tasks/, results/, templates/"; fi

  say ""
  if [ "$DRY" -eq 1 ]; then say "Dry run complete. Nothing was written."
  else say "Installation complete."
  fi
  say ""
  row() { printf '  %-10s %s\n' "$1" "$2"; }
  row "Setup"     "$(if [ "$existed" -eq 1 ]; then echo '.handoff/ exchange, updated'; else echo '.handoff/ exchange'; fi)"
  row "Code repo" "$SHOWN  ($repo_state)"
  row ".handoff/" "$files_state"
  row "AGENTS.md" "$agents_state"
  row "CLAUDE.md" "$claude_state"
  if [ -n "$ignore_state" ]; then row ".gitignore" "$ignore_state"; fi
  if [ "$DRY" -eq 0 ]; then
    say ""
    say "Next:"
    say "  The planner writes .handoff/tasks/T-001.md from .handoff/templates/task.md."
    say "  Then tell the executor, in this repo:"
    say ""
    say "      run T-001"
    say ""
  fi
  exit 0
fi

# ------------------------------------------------------------------ workspace mode
[ "$DRY" -eq 1 ] || mkdir -p "$TARGET"

if [ "$TIER" = "full" ]; then
  copy_tree "$SRC" "$TARGET" 1 < <(list_all "$SRC")
else
  copy_tree "$SRC" "$TARGET" 1 < <(list_core)
fi

if [ ! -f "$KICKOFF_SRC" ]; then fail "the kick-off template is missing from the download."; fi
write_instruction

if [ "$OBSIDIAN" -eq 1 ]; then
  [ -d "$PRESET" ] || fail "the Obsidian settings are missing from the download."
  copy_tree "$PRESET" "$TARGET/.obsidian" 0 < <(list_all "$PRESET")
fi

if [ "$EJECT" -eq 1 ]; then
  printf '%s\n' "$EJECT_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$TARGET/$p" ] || continue
    if [ "$DRY" -eq 1 ]; then say "  would remove $p"; else rm -rf "${TARGET:?}/$p"; fi
  done
  if [ -f "$TARGET/README.md" ] && grep -q 'llm-wiki-workspace:upstream-readme' "$TARGET/README.md"; then
    if [ "$DRY" -eq 1 ]; then say "  would replace README.md with a project stub"
    else printf '# %s\n\nAn LLM Wiki Workspace. Start at `instruction.md`, then `AGENTS.md`.\n' "$PROJECT_NAME" > "$TARGET/README.md"
    fi
  fi
fi

# ------------------------------------------------------------------ git
git_state="not set up"
check_state="off: the front-matter check needs git"
commit_state=""
problems=0

if [ "$GIT" -eq 1 ]; then
  if ! command -v git >/dev/null 2>&1; then
    git_state="not set up: git is not installed"
    problems=1
  elif [ "$DRY" -eq 1 ]; then
    git_state="would initialise git and turn on the check"
    check_state="would verify the hook"
  else
    abs_target=$(cd "$TARGET" && pwd -P)
    top=""
    if top=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null); then top=$(cd "$top" && pwd -P); else top=""; fi
    if [ -n "$top" ] && [ "$top" != "$abs_target" ]; then
      git_state="not set up: the folder is inside the git repository at $top"
      check_state="off: core.hooksPath applies to that whole repository, so it was left alone"
      problems=1
    else
      if [ -z "$top" ]; then git -C "$TARGET" init -q; git_state="new repository"; else git_state="existing repository"; fi
      git -C "$TARGET" config core.hooksPath .githooks

      if verify_hook "$TARGET/.githooks/pre-commit"; then
        check_state="on, and verified: a file without front matter is rejected"
      else
        rc=$?
        if [ "$rc" -eq 1 ]; then check_state="FAILED: the hook accepted a file without front matter"
        else check_state="FAILED: the hook rejected a valid file"; fi
        problems=1
      fi

      if ! git -C "$TARGET" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        git -C "$TARGET" add -A
        if out=$(git -C "$TARGET" commit -q -m "Install LLM Wiki Workspace" 2>&1); then
          commit_state="first commit made"
        else
          case "$out" in
            *"tell me who you are"*|*"identity unknown"*|*"auto-detect"*)
              commit_state="not made yet: git does not know your name and email. Set them, then commit:
               git config --global user.name \"Your Name\"
               git config --global user.email you@example.com
               git commit -m \"Install LLM Wiki Workspace\"" ;;
            *)
              commit_state="FAILED: $(printf '%s' "$out" | sed -n 1p)"
              problems=1 ;;
          esac
        fi
      fi
    fi
  fi
fi

# ------------------------------------------------------------------ report
say ""
if [ "$DRY" -eq 1 ]; then say "Dry run complete. Nothing was written."
elif [ "$problems" -eq 0 ]; then say "Installation complete."
else say "Installation finished, with problems. See below."
fi
say ""

files_line="$installed file(s), $TIER"
if [ "$skipped" -gt 0 ]; then files_line="$installed file(s) written, $skipped already there and kept"; fi
row() { printf '  %-10s %s\n' "$1" "$2"; }
row "Project"  "$PROJECT_NAME"
row "Folder"   "$SHOWN  ($files_line)"
row "Owner"    "${OWNER:-not set: files keep owner: TODO}"
if [ "$OBSIDIAN" -eq 1 ]; then row "Obsidian" "configured: open the folder as a vault"; fi
row "Git"      "$git_state"
row "Check"    "$check_state"
if [ -n "$commit_state" ]; then row "Commit" "$commit_state"; fi

if [ "$DRY" -eq 0 ]; then
  say ""
  say "Next:"
  if [ "$TARGET" != "." ]; then say "  cd $TARGET"; fi
  say "  Open the folder with your AI agent and tell it:"
  say ""
  say "      Read instruction.md and start the kick-off."
  say ""
fi

exit "$problems"
