#!/usr/bin/env bash
#
# Verification suite. Everything the README claims, checked.
#
#   bash scripts/test.sh
#
# CI runs this on every push, on Linux and macOS.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Installers ask questions when a terminal is attached; tests must never wait on one.
# The interactive checks below feed answers through LWW_TTY instead.
export LWW_NONINTERACTIVE=1
# CI machines have no git identity; the installer's first commit needs one.
export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.invalid"
HAVE_NODE=0; command -v node >/dev/null 2>&1 && HAVE_NODE=1
# Which bash runs install.sh. CI sets LWW_BASH=/bin/bash on macOS to test bash 3.2.
BASH_BIN="${LWW_BASH:-bash}"
echo "install.sh runs under: $("$BASH_BIN" --version | sed -n 1p)"

pass=0
fail=0
ok()    { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()   { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
I()     { "$BASH_BIN" "$ROOT/install.sh" "$@" >/dev/null 2>&1; }   # bash installer, quiet
N()     { node "$ROOT/bin/cli.js" "$@" >/dev/null 2>&1; }   # node installer, quiet
fm()    { awk 'NR==1 && $0!="---"{exit} NR==1{next} $0=="---"{exit} {print}' "$1"; }
commits() { git -C "$1" rev-list --count HEAD 2>/dev/null || echo 0; }

echo "1. Syntax"
check "install.sh parses"            "bash -n '$ROOT/install.sh'"
check "make-vault-zip.sh parses"     "bash -n '$ROOT/scripts/make-vault-zip.sh'"
check "pre-commit hook parses"       "bash -n '$ROOT/template/.githooks/pre-commit'"
if [ "$HAVE_NODE" -eq 1 ]; then
  check "bin/cli.js parses"          "node --check '$ROOT/bin/cli.js'"
  check "package.json ships every payload folder" \
    "node -e \"const f=require('$ROOT/package.json').files;process.exit(['template/','handoff/','kickoff/','obsidian-preset/'].every(x=>f.includes(x))?0:1)\""
  check "installers report the same version" \
    "[ \"\$('$BASH_BIN' '$ROOT/install.sh' --version)\" = \"\$(node '$ROOT/bin/cli.js' --version)\" ]"
fi
for f in "$ROOT"/obsidian-preset/*.json; do
  check "$(basename "$f") is valid JSON" "python3 -c \"import json;json.load(open('$f'))\""
done

echo "2. Core manifest matches the template"
missing=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -e "$ROOT/template/$p" ] || { echo "     missing: template/$p"; missing=1; }
done < <(sed -n '/^CORE_PATHS="/,/^"$/p' "$ROOT/install.sh" | sed '1d;$d')
[ "$missing" -eq 0 ] && ok "every core path exists in template/" || bad "core manifest has missing paths"

echo "3. Front matter on every payload file"
bare=0
while IFS= read -r f; do
  for k in status updated owner classification; do
    fm "$f" | grep -q "^$k:[[:space:]]*[^[:space:]]" || { echo "     $f missing $k"; bare=1; }
  done
done < <(find "$ROOT/template" "$ROOT/handoff/templates" "$ROOT/kickoff" -name '*.md' \
         ! -name 'README.md' ! -name 'AGENTS.md' ! -path '*/work/temp/*')
[ "$bare" -eq 0 ] && ok "all payload markdown carries the four required fields" \
                  || bad "payload markdown missing required front matter"

echo "4. Collections are one file per item"
for gone in state/backlog.md state/icebox.md state/icebox state/sprint-current.md \
            context/requirements/acceptance-criteria.md work/analysis; do
  check "no $gone" "[ ! -e '$ROOT/template/$gone' ]"
done
for dir in state/backlog record/icebox state/sprints record/backlog context/requirements \
           work/research work/prompts; do
  check "$dir/ is a folder" "[ -d '$ROOT/template/$dir' ]"
done
dead=$(grep -rlE 'acceptance-criteria\.md|functional-requirements\.md|state/backlog\.md|icebox\.md|state/icebox|sprint-current|work/analysis|research/_index' \
        "$ROOT/template" "$ROOT/handoff" "$ROOT/kickoff" "$ROOT/README.md" "$ROOT/obsidian-preset" 2>/dev/null)
[ -z "$dead" ] && ok "nothing references a removed path" || { echo "     $dead"; bad "dead references"; }
check "README no longer tells users to run the hook check by hand" \
  "! grep -q 'tmp-check' '$ROOT/README.md'"

echo "5. Core install"
I --yes "$TMP/core"
for p in AGENTS.md instruction.md system/RULES.md system/agents/escalation.md state/STATE.md \
         state/backlog record/backlog work/sources/INDEX.md .githooks/pre-commit .gitignore; do
  check "core has $p" "[ -e '$TMP/core/$p' ]"
done
check "core omits the optional tier"  "[ ! -e '$TMP/core/context/vision.md' ]"
check "core leaks no packaging"       "[ ! -e '$TMP/core/template' ] && [ ! -e '$TMP/core/install.sh' ] && [ ! -e '$TMP/core/kickoff' ]"
check "hook is executable"            "[ -x '$TMP/core/.githooks/pre-commit' ]"
check "updated: is stamped to today"  "grep -q \"^updated: $(date +%F)\$\" '$TMP/core/state/STATE.md'"
check "templates keep YYYY-MM-DD"     "grep -q '^updated: YYYY-MM-DD$' '$TMP/core/system/templates/adr.md'"
check "without --owner, owner stays TODO" "grep -qx 'owner: TODO' '$TMP/core/state/STATE.md'"
check "install exits 0"               "I --yes '$TMP/exit1'"
check "--help exits 0"                "'$BASH_BIN' '$ROOT/install.sh' --help"
check "an unknown flag fails"         "! I --bogus"
check "a flag missing its value fails" "! I --project"

echo "6. The kick-off brief"
I --yes --project 'R&D / $site' --about 'Recipes & notes, with \ and $x' --owner 'Ana Lim' "$TMP/kick"
check "instruction.md names the project"   "grep -qF '# Kick-off: R&D / \$site' '$TMP/kick/instruction.md'"
check "special characters survive"         "grep -qF 'Recipes & notes, with \\ and \$x' '$TMP/kick/instruction.md'"
check "no placeholder is left"             "! grep -q '{{' '$TMP/kick/instruction.md'"
check "owner fills every owner: TODO"      "! grep -rqx 'owner: TODO' '$TMP/kick' && grep -qx 'owner: Ana Lim' '$TMP/kick/state/STATE.md'"
check "without --about, the brief says to ask" \
  "grep -q 'Start by asking the human what the project is' '$TMP/core/instruction.md'"
check "project name defaults to the folder name" "grep -qx '# Kick-off: core' '$TMP/core/instruction.md'"
check "AGENTS.md sends the agent to instruction.md first" "grep -q 'instruction.md' '$TMP/core/AGENTS.md'"

echo "7. Full install and Obsidian"
I --yes --full "$TMP/full"
check "full has context/vision.md"        "[ -e '$TMP/full/context/vision.md' ]"
check "full has six agent files"          "[ \$(ls '$TMP/full/system/agents' | wc -l) -eq 6 ]"
check "full has both workflows"           "[ -e '$TMP/full/system/workflows/planner-executor.md' ] && [ -e '$TMP/full/system/workflows/research.md' ]"
check "full is larger than core" \
  "[ \$(find '$TMP/full' -type f | wc -l) -gt \$(find '$TMP/core' -type f | wc -l) ]"
I --yes --full --obsidian "$TMP/vault"
check "vault has .obsidian/app.json"      "[ -e '$TMP/vault/.obsidian/app.json' ]"
check "templates plugin points at system/templates" \
  "python3 -c \"import json;assert json.load(open('$TMP/vault/.obsidian/templates.json'))['folder']=='system/templates'\""
check "plain install writes no .obsidian" "[ ! -e '$TMP/full/.obsidian' ]"

echo "8. Existing folders"
mkdir -p "$TMP/existing"; printf 'MINE\n' > "$TMP/existing/AGENTS.md"
check "a non-empty folder is refused"     "! I --yes '$TMP/existing'"
refusal=$("$BASH_BIN" "$ROOT/install.sh" --yes "$TMP/existing" 2>&1 || true)
check "…with a message that says why" \
  "printf '%s' \"\$refusal\" | grep -q 'already exists and is not empty'"
check "…and nothing is written"           "[ \$(ls -A '$TMP/existing' | wc -l) -eq 1 ]"
check "--merge adds the missing files"    "I --yes --merge '$TMP/existing' && [ -e '$TMP/existing/system/RULES.md' ]"
check "…and keeps the existing one"       "grep -qx MINE '$TMP/existing/AGENTS.md'"
check "--force overwrites it"             "I --yes --force '$TMP/existing' && ! grep -qx MINE '$TMP/existing/AGENTS.md'"
check "re-running into the same folder is refused" "! I --yes '$TMP/core'"
check "…but --merge --full upgrades it"   "I --yes --merge --full '$TMP/core' && [ -e '$TMP/core/context/vision.md' ]"
mkdir -p "$TMP/gitonly/.git"
check "a folder holding only .git counts as empty" "I --yes '$TMP/gitonly'"
check "a dry run creates nothing"         "I --yes --dry-run '$TMP/dry' && [ ! -e '$TMP/dry' ]"

echo "9. --git: verified hook and a first commit"
out=$("$BASH_BIN" "$ROOT/install.sh" --yes --git "$TMP/repo" 2>&1); rc=$?
check "install with --git exits 0"        "[ $rc -eq 0 ]"
check "it reports Installation complete, and nothing else" \
  "[ \"\$(printf '%s\n' \"\$out\" | grep -cE '^(Installation|Dry run)')\" -eq 1 ] && printf '%s' \"\$out\" | grep -q '^Installation complete.'"
check "it reports the hook as verified"   "printf '%s' \"\$out\" | grep -q 'verified: a file without front matter is rejected'"
check "core.hooksPath is .githooks"       "[ \"\$(git -C '$TMP/repo' config core.hooksPath)\" = .githooks ]"
check "the first commit is made"          "[ \$(commits '$TMP/repo') -eq 1 ]"
check "the first commit has no AI attribution" "! git -C '$TMP/repo' log -1 --format=%B | grep -qiE 'co-authored-by|claude'"
printf '# no front matter\n' > "$TMP/repo/context/constraints/bad.md"
( cd "$TMP/repo" && git add context/constraints/bad.md && git commit -qm bad ) >/dev/null 2>&1
check "a file without front matter is rejected" "[ \$(commits '$TMP/repo') -eq 1 ]"
printf -- '---\nstatus: draft\nupdated: 2026-01-01\nowner: t\nclassification: public\n---\n\n# fixed\n' \
  > "$TMP/repo/context/constraints/bad.md"
( cd "$TMP/repo" && git commit -qm sneaky ) >/dev/null 2>&1
check "fixing only the working copy does not get the staged bad version in" "[ \$(commits '$TMP/repo') -eq 1 ]"
( cd "$TMP/repo" && git add context/constraints/bad.md && git commit -qm good ) >/dev/null 2>&1
check "once staged, the fixed file is accepted" "[ \$(commits '$TMP/repo') -eq 2 ]"
git init -q "$TMP/outer"
check "inside another repo it reports a problem" "! I --yes --git '$TMP/outer/sub'"
check "…still installs the files"          "[ -e '$TMP/outer/sub/system/RULES.md' ]"
check "…and leaves that repo's hooksPath alone" "[ -z \"\$(git -C '$TMP/outer' config core.hooksPath)\" ]"
check "without a git identity it still succeeds" \
  "env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
     GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 '$BASH_BIN' '$ROOT/install.sh' --yes --git '$TMP/noid' \
   && [ -d '$TMP/noid/.git' ]"

echo "10. --handoff sets up a code repo"
git init -q "$TMP/code"
I --yes --handoff "$TMP/code"
for p in .handoff/README.md .handoff/templates/task.md .handoff/templates/result.md \
         .handoff/tasks/.gitkeep .handoff/results/.gitkeep AGENTS.md; do
  check "code repo has $p" "[ -e '$TMP/code/$p' ]"
done
check "the protocol source is not copied" "[ ! -e '$TMP/code/.handoff/_agents-block.md' ]"
check "CLAUDE.md links to AGENTS.md"      "[ -L '$TMP/code/CLAUDE.md' ] && [ \"\$(readlink '$TMP/code/CLAUDE.md')\" = AGENTS.md ]"
I --yes --handoff --handoff-ignore "$TMP/code"
I --yes --handoff --handoff-ignore "$TMP/code"
check "the protocol is added exactly once" "[ \$(grep -c '^## Handoff protocol' '$TMP/code/AGENTS.md') -eq 1 ]"
check ".handoff/ is ignored exactly once"  "[ \$(grep -cx '\.handoff/' '$TMP/code/.gitignore') -eq 1 ]"
check "no workspace files land in a code repo" "[ ! -e '$TMP/code/system' ] && [ ! -e '$TMP/code/instruction.md' ]"
mkdir -p "$TMP/code2"; printf '# My rules\n\nKeep this.\n' > "$TMP/code2/CLAUDE.md"
I --yes --handoff "$TMP/code2"
check "an existing CLAUDE.md keeps its content" "grep -q 'Keep this.' '$TMP/code2/CLAUDE.md' && grep -q 'Handoff protocol' '$TMP/code2/CLAUDE.md'"
check "a missing folder is an error"      "! I --yes --handoff '$TMP/does-not-exist'"

echo "11. Interactive mode, answered through LWW_TTY"
# Order: mode, folder, project name, about, owner, structure, Obsidian, git, proceed.
printf '1\nasked\nAsked Project\nA test project\nTester\n2\ny\ny\ny\n' > "$TMP/answers-ws"
check "workspace answers are followed" \
  "cd '$TMP' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-ws' '$BASH_BIN' '$ROOT/install.sh' >/dev/null 2>&1 \
   && [ -e '$TMP/asked/context/vision.md' ] && [ -e '$TMP/asked/.obsidian/app.json' ] \
   && grep -q 'Asked Project' '$TMP/asked/instruction.md' && grep -q 'A test project' '$TMP/asked/instruction.md' \
   && grep -qx 'owner: Tester' '$TMP/asked/state/STATE.md' && [ \$(commits '$TMP/asked') -eq 1 ]"
printf '1\ndeclined\n\n\n\n1\nn\nn\nn\n' > "$TMP/answers-no"
check "declining at Proceed writes nothing" \
  "cd '$TMP' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-no' '$BASH_BIN' '$ROOT/install.sh' >/dev/null 2>&1 \
   && [ ! -e '$TMP/declined' ]"
printf '1\nexisting\n' > "$TMP/answers-exists"
early=$(cd "$TMP" && env -u LWW_NONINTERACTIVE LWW_TTY="$TMP/answers-exists" "$BASH_BIN" "$ROOT/install.sh" 2>&1 || true)
check "a non-empty folder is refused before the other questions" \
  "printf '%s' \"\$early\" | grep -q 'already exists' && ! printf '%s' \"\$early\" | grep -q 'Project name'"
git init -q "$TMP/code3"
printf '2\n%s\nn\ny\n' "$TMP/code3" > "$TMP/answers-ho"
check "handoff answers are followed" \
  "env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-ho' '$BASH_BIN' '$ROOT/install.sh' >/dev/null 2>&1 \
   && [ -e '$TMP/code3/.handoff/templates/task.md' ] && grep -qx '\.handoff/' '$TMP/code3/.gitignore'"
printf '\n\n\ny\n' > "$TMP/answers-flags"
check "flags answer their own questions" \
  "env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-flags' \
   '$BASH_BIN' '$ROOT/install.sh' --full --no-obsidian --no-git '$TMP/flagged' >/dev/null 2>&1 \
   && [ -e '$TMP/flagged/context/vision.md' ] && [ ! -e '$TMP/flagged/.obsidian' ]"

echo "12. bash and node installers agree"
if [ "$HAVE_NODE" -eq 1 ]; then
  A=(--project 'R&D / $x' --about 'Line & \ back' --owner 'Ana Lim')
  I --yes "${A[@]}" "$TMP/b-core";                 N --yes "${A[@]}" "$TMP/n-core"
  check "core trees identical"                      "diff -r '$TMP/b-core' '$TMP/n-core'"
  I --yes --full --obsidian "${A[@]}" "$TMP/b-full"; N --yes --full --obsidian "${A[@]}" "$TMP/n-full"
  check "full + obsidian trees identical"           "diff -r '$TMP/b-full' '$TMP/n-full'"
  mkdir -p "$TMP/b-ho" "$TMP/n-ho"; printf 'x\n' > "$TMP/b-ho/CLAUDE.md"; cp "$TMP/b-ho/CLAUDE.md" "$TMP/n-ho/"
  I --yes --handoff --handoff-ignore "$TMP/b-ho"; N --yes --handoff --handoff-ignore "$TMP/n-ho"
  check "handoff results identical"                 "diff -r '$TMP/b-ho' '$TMP/n-ho'"
  N --yes --git "$TMP/n-git"
  check "node --git verifies the hook and commits"  "[ \$(commits '$TMP/n-git') -eq 1 ]"
  check "node refuses a non-empty folder too"       "! N --yes '$TMP/n-git'"
  mkdir -p "$TMP/n-int"
  check "node interactive answers are followed" \
    "cd '$TMP/n-int' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-ws' node '$ROOT/bin/cli.js' >/dev/null 2>&1 \
     && diff -r -x .git '$TMP/asked' '$TMP/n-int/asked'"
else
  echo "  skip  node not installed"
fi

echo "13. Eject leaves a bare workspace"
mkdir -p "$TMP/tpl"
cp -R "$ROOT/template" "$ROOT/handoff" "$ROOT/kickoff" "$ROOT/install.sh" "$ROOT/bin" "$ROOT/scripts" \
      "$ROOT/obsidian-preset" "$ROOT/package.json" "$ROOT/README.md" "$TMP/tpl/" 2>/dev/null
"$BASH_BIN" "$TMP/tpl/install.sh" --yes --full --eject --project Mine "$TMP/tpl" >/dev/null 2>&1
check "the packaging is gone" "[ ! -e '$TMP/tpl/template' ] && [ ! -e '$TMP/tpl/handoff' ] && [ ! -e '$TMP/tpl/kickoff' ] && [ ! -e '$TMP/tpl/install.sh' ]"
check "the workspace remains"  "[ -e '$TMP/tpl/system/RULES.md' ] && [ -e '$TMP/tpl/instruction.md' ]"
check "README was replaced"    "! grep -q 'upstream-readme' '$TMP/tpl/README.md' && grep -qx '# Mine' '$TMP/tpl/README.md'"

echo "14. Survives a hostile PATH"
# conda and perl LWP both ship a `head` that fetches URLs and rejects -n.
mkdir -p "$TMP/hostile"
printf '#!/bin/sh\necho "Unknown option: n" >&2\nexit 1\n' > "$TMP/hostile/head"; chmod +x "$TMP/hostile/head"
check "install.sh runs with head(1) shadowed" \
  "PATH='$TMP/hostile:$PATH' '$BASH_BIN' '$ROOT/install.sh' --yes --git '$TMP/hostile-out' && [ \$(commits '$TMP/hostile-out') -eq 1 ]"

echo "15. Every outcome ends in a plain verdict, in both setups and both installers"
# expect <installer> <label> <verdict-regex> <exit-code> <installer args...>
# The verdict is the first line starting "Installation", "Dry run" or "Cancelled".
expect() {
  inst="$1"; label="$2"; want="$3"; rc_want="$4"; shift 4
  if [ "$inst" = bash ]; then out=$("$BASH_BIN" "$ROOT/install.sh" "$@" 2>&1)
  else out=$(node "$ROOT/bin/cli.js" "$@" 2>&1); fi
  rc=$?
  verdict=$(printf '%s\n' "$out" | grep -E '^(Installation|Dry run|Cancelled)' | sed -n 1p)
  verdicts=$(printf '%s\n' "$out" | grep -cE '^(Installation|Dry run|Cancelled)')
  if [ "$rc" -eq "$rc_want" ] && [ "$verdicts" -eq 1 ] && printf '%s' "$verdict" | grep -qE "$want" \
     && ! printf '%s' "$out" | grep -q 'unexpected error'; then
    ok "$inst: $label"
  else
    bad "$inst: $label (exit $rc, $verdicts verdict line(s), first: ${verdict:-nothing})"
  fi
}
INSTALLERS="bash"; [ "$HAVE_NODE" -eq 1 ] && INSTALLERS="bash node"
for inst in $INSTALLERS; do
  d="$TMP/outcome-$inst"; mkdir -p "$d"
  git init -q "$d/code"; touch "$d/afile"; mkdir -p "$d/ro"
  "$BASH_BIN" "$ROOT/install.sh" --yes "$d/ws" >/dev/null 2>&1
  # handoff
  expect "$inst" "handoff into a code repo"        '^Installation complete\.$'        0 --yes --handoff "$d/code"
  expect "$inst" "handoff run again"               '^Installation complete\.$'        0 --yes --handoff "$d/code"
  expect "$inst" "handoff dry run"                 '^Dry run complete'                0 --yes --handoff --dry-run "$d/code"
  expect "$inst" "handoff, folder missing"         'failed: .* does not exist'        1 --yes --handoff "$d/missing"
  expect "$inst" "handoff, target is a file"       'failed: .* is a file'             1 --yes --handoff "$d/afile"
  expect "$inst" "handoff into a workspace"        'failed: .* looks like a workspace' 1 --yes --handoff "$d/ws"
  expect "$inst" "handoff into a workspace, --force" '^Installation complete\.$'      0 --yes --handoff --force "$d/ws"
  # workspace
  expect "$inst" "workspace, new folder with git"  '^Installation complete\.$'        0 --yes --git "$d/new"
  expect "$inst" "workspace, folder not empty"     'failed: .* not empty'             1 --yes "$d/new"
  expect "$inst" "workspace, target is a file"     'failed: .* is a file'             1 --yes "$d/afile"
  expect "$inst" "workspace dry run"               '^Dry run complete'                0 --yes --dry-run "$d/dry"
  git init -q "$d/outer"
  expect "$inst" "workspace inside another repo"   'finished, with problems'          1 --yes --git "$d/outer/kb"
  if [ "$(id -u)" -ne 0 ]; then
    chmod 555 "$d/ro"
    expect "$inst" "handoff, read-only folder"     'failed: cannot write to .*permission denied' 1 --yes --handoff "$d/ro"
    expect "$inst" "workspace, read-only parent"   'failed: cannot write to .*permission denied' 1 --yes "$d/ro/kb"
    chmod 755 "$d/ro"
  fi
done
printf '1\ncancelled\n\n\n\n1\nn\nn\nn\n' > "$TMP/answers-cancel"
for inst in $INSTALLERS; do
  if [ "$inst" = bash ]; then c=("$BASH_BIN" "$ROOT/install.sh"); else c=(node "$ROOT/bin/cli.js"); fi
  out=$(cd "$TMP" && env -u LWW_NONINTERACTIVE LWW_TTY="$TMP/answers-cancel" "${c[@]}" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'Cancelled. Nothing was written.' && [ ! -e "$TMP/cancelled" ]
  then ok "$inst: declining at Proceed says Cancelled"; else bad "$inst: declining at Proceed says Cancelled"; fi
done

echo "16. Nothing private is named anywhere"
# The list is deliberately not in this repository: publishing it would leak what it
# exists to keep out. One term per line in .private-names (gitignored), or point
# LWW_DENYLIST at a file elsewhere.
DENY_FILE="${LWW_DENYLIST:-$ROOT/.private-names}"
if [ -f "$DENY_FILE" ]; then
  leak=0
  while IFS= read -r term; do
    case "$term" in ''|\#*) continue ;; esac
    if grep -ril "$term" "$ROOT" --exclude-dir=.git --exclude-dir=node_modules \
         --exclude-dir=dist --exclude=".private-names" >/dev/null 2>&1; then
      echo "     found: $term"; leak=1
    fi
  done < "$DENY_FILE"
  [ "$leak" -eq 0 ] && ok "no private names in the tree" || bad "private names found"
else
  echo "  skip  no $DENY_FILE; create it to check for private names"
fi

echo "17. The published route: curl the installer from GitHub and pipe it to bash"
# Runs what users run, against what is published. It tests the published branch, not
# this checkout, so it can lag behind local changes until they are pushed.
RAW="https://raw.githubusercontent.com/${LWW_REPO:-aidilikbar/llm-wiki-workspace}/${LWW_REF:-main}/install.sh"
if curl -fsS --max-time 20 -o /dev/null "$RAW" 2>/dev/null; then
  mkdir -p "$TMP/alone"
  check "curl | bash installs a workspace" \
    "cd '$TMP/alone' && curl -fsSL '$RAW' | '$BASH_BIN' -s -- --yes out && [ -e '$TMP/alone/out/system/RULES.md' ]"
else
  echo "  skip  no network to codeload.github.com"
fi

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
