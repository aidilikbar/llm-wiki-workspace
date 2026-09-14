#!/usr/bin/env bash
#
# LLM Wiki Workspace — installer
#
#   bash install.sh                      core tier into the current directory
#   bash install.sh --full ./my-project  whole tree into ./my-project
#   bash install.sh --obsidian           also write an Obsidian vault config
#   bash install.sh --eject              flatten a "Use this template" clone
#
# Run it from a clone, or straight from the network:
#
#   curl -fsSL https://raw.githubusercontent.com/aidilikbar/llm-wiki-workspace/main/install.sh | bash
#
# Existing files are never overwritten unless you pass --force.

set -euo pipefail

VERSION="1.0.0"
REPO_SLUG="${LWW_REPO:-aidilikbar/llm-wiki-workspace}"
REF="${LWW_REF:-main}"

TARGET="."
TIER="core"
OBSIDIAN=0
FORCE=0
EJECT=0
DRY=0

# Paths inside template/ that make up the core tier. Anything not listed here is
# installed only with --full. CI checks that every entry exists.
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
record/AGENTS.md
record/decisions
record/logbook
work/AGENTS.md
work/sources/INDEX.md
work/temp
"

# Files removed from the target by --eject: the packaging, not the workspace.
EJECT_PATHS="
template
install.sh
bin
scripts
obsidian-preset
package.json
package-lock.json
docs
.github
"

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
LLM Wiki Workspace installer

usage: install.sh [options] [target-directory]

options:
  --full        install the entire tree (default: the core tier only)
  --obsidian    also write .obsidian/ so the folder opens as an Obsidian vault
  --force       overwrite files that already exist in the target
  --eject       after installing, delete the packaging files from the target.
                Use this on a repository created with GitHub's "Use this template".
  --dry-run     print what would happen, write nothing
  --version     print the installer version
  -h, --help    this text

target-directory defaults to the current directory and is created if missing.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --full)      TIER="full" ;;
    --obsidian)  OBSIDIAN=1 ;;
    --force)     FORCE=1 ;;
    --eject)     EJECT=1 ;;
    --dry-run)   DRY=1 ;;
    --version)   say "$VERSION"; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    -*)          die "unknown option: $1 (try --help)" ;;
    *)           TARGET="$1" ;;
  esac
  shift
done

# ------------------------------------------------------------------ source tree
# Prefer a template/ next to this script. Fall back to downloading the repository,
# which is what happens when the script is piped from curl.

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

TMPDIR_DL=""
cleanup() { if [ -n "$TMPDIR_DL" ]; then rm -rf "$TMPDIR_DL"; fi; return 0; }
trap cleanup EXIT

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/template" ]; then
  SRC="$SCRIPT_DIR/template"
  PRESET="$SCRIPT_DIR/obsidian-preset"
else
  command -v curl >/dev/null 2>&1 || die "curl is required to download the workspace"
  command -v tar  >/dev/null 2>&1 || die "tar is required to unpack the workspace"
  TMPDIR_DL=$(mktemp -d)
  url="https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$REF"
  say "Fetching $REPO_SLUG@$REF ..."
  curl -fsSL "$url" | tar xz -C "$TMPDIR_DL" \
    || die "could not download $url"
  root=$(find "$TMPDIR_DL" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  [ -d "$root/template" ] || die "downloaded archive has no template/ directory"
  SRC="$root/template"
  PRESET="$root/obsidian-preset"
fi

# ------------------------------------------------------------------ file list
list_files() {
  if [ "$TIER" = "full" ]; then
    (cd "$SRC" && find . -type f | sed 's|^\./||' | sort)
    return
  fi
  printf '%s\n' "$CORE_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -d "$SRC/$p" ]; then
      (cd "$SRC" && find "$p" -type f | sed 's|^\./||')
    elif [ -f "$SRC/$p" ]; then
      printf '%s\n' "$p"
    else
      warn "warning: core path missing from template: $p"
    fi
  done | sort -u
}

# Stamp the install date onto a file's own `updated:` field, but only when the value
# is a real date. Templates carry the literal YYYY-MM-DD and keep it.
stamp_date() {
  f="$1"; today="$2"
  head -n 1 "$f" | grep -q '^---$' || return 0
  awk -v today="$today" '
    NR == 1 { print; next }
    !done && /^---$/ { done = 1; print; next }
    !done && /^updated: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print "updated: " today; next }
    { print }
  ' "$f" > "$f.lww-tmp" && mv "$f.lww-tmp" "$f"
}

TODAY=$(date +%F)
installed=0
skipped=0

if [ "$DRY" -eq 1 ]; then say "DRY RUN — nothing will be written"; fi
say "Installing the $TIER tier into ${TARGET%/}/"

if [ "$DRY" -eq 0 ]; then
  mkdir -p "$TARGET"
fi

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  dest="$TARGET/$rel"
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    skipped=$((skipped + 1))
    continue
  fi
  if [ "$DRY" -eq 1 ]; then
    say "  would write $rel"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$SRC/$rel" "$dest"
    case "$rel" in
      *.md) stamp_date "$dest" "$TODAY" ;;
      .githooks/*) chmod +x "$dest" ;;
    esac
  fi
  installed=$((installed + 1))
done <<EOF
$(list_files)
EOF

# ------------------------------------------------------------------ obsidian
if [ "$OBSIDIAN" -eq 1 ]; then
  [ -d "$PRESET" ] || die "obsidian preset not found at $PRESET"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="$TARGET/.obsidian/$rel"
    if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
      skipped=$((skipped + 1))
      continue
    fi
    if [ "$DRY" -eq 1 ]; then
      say "  would write .obsidian/$rel"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$PRESET/$rel" "$dest"
    fi
    installed=$((installed + 1))
  done <<EOF
$(cd "$PRESET" && find . -type f | sed 's|^\./||' | sort)
EOF
fi

# ------------------------------------------------------------------ eject
if [ "$EJECT" -eq 1 ]; then
  printf '%s\n' "$EJECT_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$TARGET/$p" ] || continue
    if [ "$DRY" -eq 1 ]; then
      say "  would remove $p"
    else
      rm -rf "${TARGET:?}/$p"
    fi
  done
  # Replace the upstream README only if it is still the upstream README.
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

# ------------------------------------------------------------------ report
say ""
say "Wrote $installed file(s); skipped $skipped that already existed."
if [ "$skipped" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
  say "Re-run with --force to overwrite the skipped files."
fi

cat <<NEXT

Next, in ${TARGET%/}/:

  1. git config core.hooksPath .githooks     turn on the front-matter check
  2. fill context/constraints/               highest-value file in the tree
  3. fill system/agents/escalation.md        what the agent may decide alone
  4. fill the Commands block in AGENTS.md    your real install/test/lint commands

Verify the check is live:

  printf '# no front matter\n' > context/constraints/tmp-check.md
  git add context/constraints/tmp-check.md && git commit -m 'should fail'
  rm context/constraints/tmp-check.md

The commit must be rejected. If it is not, step 1 did not take effect.
NEXT

exit 0
