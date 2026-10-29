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

# The installers ask questions when a terminal is attached. Tests must never wait on one;
# the interactive checks below feed answers through LWW_TTY instead.
export LWW_NONINTERACTIVE=1
HAVE_NODE=0; command -v node >/dev/null 2>&1 && HAVE_NODE=1

pass=0
fail=0
ok()    { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()   { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
I()     { bash "$ROOT/install.sh" "$@" >/dev/null 2>&1; }   # bash installer, quiet
N()     { node "$ROOT/bin/cli.js" "$@" >/dev/null 2>&1; }   # node installer, quiet
fm()    { awk 'NR==1 && $0!="---"{exit} NR==1{next} $0=="---"{exit} {print}' "$1"; }

echo "1. Syntax"
check "install.sh parses"            "bash -n '$ROOT/install.sh'"
check "make-vault-zip.sh parses"     "bash -n '$ROOT/scripts/make-vault-zip.sh'"
check "pre-commit hook parses"       "bash -n '$ROOT/template/.githooks/pre-commit'"
if [ "$HAVE_NODE" -eq 1 ]; then
  check "bin/cli.js parses"          "node --check '$ROOT/bin/cli.js'"
  check "package.json is valid JSON" "node -e \"require('$ROOT/package.json')\""
  check "package.json ships handoff/" "node -e \"process.exit(require('$ROOT/package.json').files.includes('handoff/')?0:1)\""
fi
for f in "$ROOT"/obsidian-preset/*.json; do
  check "$(basename "$f") is valid JSON" "python3 -c \"import json;json.load(open('$f'))\""
done
check "installers report the same version" \
  "[ \"\$(bash '$ROOT/install.sh' --version)\" = \"\$(node '$ROOT/bin/cli.js' --version)\" ]"

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
done < <(find "$ROOT/template" "$ROOT/handoff/templates" -name '*.md' \
         ! -name 'README.md' ! -name 'AGENTS.md' ! -path '*/work/temp/*')
[ "$bare" -eq 0 ] && ok "all payload markdown carries the four required fields, handoff templates included" \
                  || bad "payload markdown missing required front matter"

echo "4. Collections are one file per item"
for gone in state/backlog.md state/icebox.md state/icebox state/sprint-current.md \
            context/requirements/acceptance-criteria.md \
            context/requirements/functional-requirements.md \
            context/requirements/non-functional-requirements.md work/analysis; do
  check "no $gone" "[ ! -e '$ROOT/template/$gone' ]"
done
for dir in state/backlog record/icebox state/sprints record/backlog context/requirements \
           work/research work/prompts; do
  check "$dir/ is a folder" "[ -d '$ROOT/template/$dir' ]"
done
for t in backlog-item icebox-item sprint requirement research prompt; do
  check "template $t.md carries an ID or naming rule" \
    "grep -qE '^id: |One file per' '$ROOT/template/system/templates/$t.md'"
done
dead=$(grep -rlE 'acceptance-criteria\.md|functional-requirements\.md|state/backlog\.md|icebox\.md|state/icebox|sprint-current|work/analysis|research/_index' \
        "$ROOT/template" "$ROOT/handoff" "$ROOT/README.md" "$ROOT/obsidian-preset" 2>/dev/null)
[ -z "$dead" ] && ok "nothing references a removed path" || { echo "     $dead"; bad "dead references"; }

echo "5. Core install"
I --yes "$TMP/core"
for p in AGENTS.md system/RULES.md system/agents/escalation.md state/STATE.md \
         state/backlog record/backlog record/AGENTS.md work/sources/INDEX.md \
         .githooks/pre-commit .gitignore; do
  check "core has $p" "[ -e '$TMP/core/$p' ]"
done
check "core omits the optional tier"  "[ ! -e '$TMP/core/context/vision.md' ]"
check "core leaks no packaging"       "[ ! -e '$TMP/core/template' ] && [ ! -e '$TMP/core/install.sh' ] && [ ! -e '$TMP/core/handoff' ]"
check "hook is executable"            "[ -x '$TMP/core/.githooks/pre-commit' ]"
check "updated: is stamped to today"  "grep -q \"^updated: $(date +%F)\$\" '$TMP/core/state/STATE.md'"
check "templates keep YYYY-MM-DD"     "grep -q '^updated: YYYY-MM-DD$' '$TMP/core/system/templates/adr.md'"
check "install exits 0"               "I --yes '$TMP/exit1'"
check "re-install exits 0"            "I --yes '$TMP/exit1'"
check "--help exits 0"                "bash '$ROOT/install.sh' --help"
check "an unknown flag fails"         "! I --bogus"

echo "6. Full install"
I --yes --full "$TMP/full"
check "full has context/vision.md"        "[ -e '$TMP/full/context/vision.md' ]"
check "full has six agent files"          "[ \$(ls '$TMP/full/system/agents' | wc -l) -eq 6 ]"
check "full has the planner–executor workflow" "[ -e '$TMP/full/system/workflows/planner-executor.md' ]"
check "full has the research workflow"    "[ -e '$TMP/full/system/workflows/research.md' ]"
check "full has work/research and work/prompts" "[ -d '$TMP/full/work/research' ] && [ -d '$TMP/full/work/prompts' ]"
check "full is larger than core" \
  "[ \$(find '$TMP/full' -type f | wc -l) -gt \$(find '$TMP/core' -type f | wc -l) ]"

echo "7. Obsidian install"
I --yes --full --obsidian "$TMP/vault"
check "vault has .obsidian/app.json"      "[ -e '$TMP/vault/.obsidian/app.json' ]"
check "templates plugin points at system/templates" \
  "python3 -c \"import json;assert json.load(open('$TMP/vault/.obsidian/templates.json'))['folder']=='system/templates'\""
check "plain install writes no .obsidian" "[ ! -e '$TMP/full/.obsidian' ]"

echo "8. Existing files are never clobbered; dry run writes nothing"
mkdir -p "$TMP/existing"; printf 'MINE\n' > "$TMP/existing/AGENTS.md"
I --yes "$TMP/existing"
check "an existing file survives"     "grep -qx MINE '$TMP/existing/AGENTS.md'"
I --yes --force "$TMP/existing"
check "--force overwrites it"         "! grep -qx MINE '$TMP/existing/AGENTS.md'"
I --yes --dry-run "$TMP/dry"
check "dry run creates nothing"       "[ ! -e '$TMP/dry' ]"

echo "9. --git turns the check on, and the hook blocks a bad commit"
I --yes --git "$TMP/repo"
check "git repository created"        "[ -d '$TMP/repo/.git' ]"
check "core.hooksPath is .githooks"   "[ \"\$(git -C '$TMP/repo' config core.hooksPath)\" = .githooks ]"
( cd "$TMP/repo" && git config user.email t@example.com && git config user.name T \
  && git add -A && git commit -qm workspace ) >/dev/null 2>&1
check "a clean workspace commits"     "git -C '$TMP/repo' rev-parse HEAD"
printf '# no front matter\n' > "$TMP/repo/context/constraints/bad.md"
( cd "$TMP/repo" && git add context/constraints/bad.md && git commit -qm bad ) >/dev/null 2>&1
check "a file without front matter is rejected" "[ \$(git -C '$TMP/repo' rev-list --count HEAD) -eq 1 ]"
rm -f "$TMP/repo/context/constraints/bad.md"; git -C "$TMP/repo" reset -q
printf -- '---\nstatus: draft\nupdated: 2026-01-01\nowner: t\nclassification: public\n---\n\n# ok\n' \
  > "$TMP/repo/context/constraints/good.md"
( cd "$TMP/repo" && git add context/constraints/good.md && git commit -qm good ) >/dev/null 2>&1
check "a file with front matter is accepted" "[ \$(git -C '$TMP/repo' rev-list --count HEAD) -eq 2 ]"
git init -q "$TMP/outer"
check "inside another repo, it still installs" "I --yes --git '$TMP/outer/sub'"
check "…but leaves that repo's hooksPath alone" "[ -z \"\$(git -C '$TMP/outer' config core.hooksPath)\" ]"

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
check "no workspace files land in a code repo" "[ ! -e '$TMP/code/system' ] && [ ! -e '$TMP/code/state' ]"
mkdir -p "$TMP/code2"; printf '# My rules\n\nKeep this.\n' > "$TMP/code2/CLAUDE.md"
I --yes --handoff "$TMP/code2"
check "an existing CLAUDE.md keeps its content" "grep -q 'Keep this.' '$TMP/code2/CLAUDE.md'"
check "…and gains the protocol"           "grep -q 'Handoff protocol' '$TMP/code2/CLAUDE.md'"
check "a missing folder is an error"      "! I --yes --handoff '$TMP/does-not-exist'"

echo "11. Interactive mode, answered through LWW_TTY"
printf '1\nasked\n2\ny\ny\ny\n' > "$TMP/answers-ws"
check "workspace answers are followed" \
  "cd '$TMP' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-ws' bash '$ROOT/install.sh' >/dev/null 2>&1 \
   && [ -e '$TMP/asked/context/vision.md' ] && [ -e '$TMP/asked/.obsidian/app.json' ] \
   && [ \"\$(git -C '$TMP/asked' config core.hooksPath)\" = .githooks ]"
printf '1\ndeclined\n1\nn\nn\nn\n' > "$TMP/answers-no"
check "declining at Proceed writes nothing" \
  "cd '$TMP' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-no' bash '$ROOT/install.sh' >/dev/null 2>&1 \
   && [ ! -e '$TMP/declined' ]"
git init -q "$TMP/code3"
printf '2\n%s\nn\ny\n' "$TMP/code3" > "$TMP/answers-ho"
check "handoff answers are followed" \
  "env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-ho' bash '$ROOT/install.sh' >/dev/null 2>&1 \
   && [ -e '$TMP/code3/.handoff/templates/task.md' ] && grep -qx '\.handoff/' '$TMP/code3/.gitignore'"
check "flags answer their own questions" \
  "printf 'y\n' > '$TMP/answers-flags' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-flags' \
   bash '$ROOT/install.sh' --full --no-obsidian --no-git '$TMP/flagged' >/dev/null 2>&1 \
   && [ -e '$TMP/flagged/context/vision.md' ] && [ ! -e '$TMP/flagged/.obsidian' ]"

echo "12. bash and node installers agree"
if [ "$HAVE_NODE" -eq 1 ]; then
  I --yes "$TMP/b-core";                 N --yes "$TMP/n-core"
  check "core trees identical"           "diff -r '$TMP/b-core' '$TMP/n-core'"
  I --yes --full --obsidian "$TMP/b-full"; N --yes --full --obsidian "$TMP/n-full"
  check "full + obsidian trees identical" "diff -r '$TMP/b-full' '$TMP/n-full'"
  mkdir -p "$TMP/b-ho" "$TMP/n-ho"; printf 'x\n' > "$TMP/b-ho/CLAUDE.md"; cp "$TMP/b-ho/CLAUDE.md" "$TMP/n-ho/"
  I --yes --handoff --handoff-ignore "$TMP/b-ho"; N --yes --handoff --handoff-ignore "$TMP/n-ho"
  check "handoff results identical"      "diff -r '$TMP/b-ho' '$TMP/n-ho'"
  mkdir -p "$TMP/n-int"
  check "node interactive answers are followed" \
    "cd '$TMP/n-int' && env -u LWW_NONINTERACTIVE LWW_TTY='$TMP/answers-ws' node '$ROOT/bin/cli.js' >/dev/null 2>&1 \
     && diff -r -x .git '$TMP/asked' '$TMP/n-int/asked'"
else
  echo "  skip  node not installed"
fi

echo "13. Eject leaves a bare workspace"
mkdir -p "$TMP/tpl"
cp -R "$ROOT/template" "$ROOT/handoff" "$ROOT/install.sh" "$ROOT/bin" "$ROOT/scripts" \
      "$ROOT/obsidian-preset" "$ROOT/package.json" "$ROOT/README.md" "$TMP/tpl/" 2>/dev/null
bash "$TMP/tpl/install.sh" --yes --full --eject "$TMP/tpl" >/dev/null 2>&1
check "template/ and handoff/ are gone" "[ ! -e '$TMP/tpl/template' ] && [ ! -e '$TMP/tpl/handoff' ]"
check "install.sh is gone"            "[ ! -e '$TMP/tpl/install.sh' ]"
check "the workspace remains"         "[ -e '$TMP/tpl/system/RULES.md' ] && [ -e '$TMP/tpl/AGENTS.md' ]"
check "README was replaced"           "! grep -q 'upstream-readme' '$TMP/tpl/README.md'"

echo "14. Survives a hostile PATH"
# conda and perl LWP both ship a `head` that fetches URLs and rejects -n.
mkdir -p "$TMP/hostile"
printf '#!/bin/sh\necho "Unknown option: n" >&2\nexit 1\n' > "$TMP/hostile/head"; chmod +x "$TMP/hostile/head"
check "install.sh runs with head(1) shadowed" \
  "PATH='$TMP/hostile:$PATH' bash '$ROOT/install.sh' --yes '$TMP/hostile-out' && [ -e '$TMP/hostile-out/system/RULES.md' ]"
check "front matter is still stamped" "grep -q \"^updated: $(date +%F)\$\" '$TMP/hostile-out/state/STATE.md'"

echo "15. Nothing private is named anywhere"
# The list is deliberately NOT in this repository — publishing it would leak exactly
# what it exists to keep out. One term per line in .private-names (gitignored), or
# point LWW_DENYLIST at a file elsewhere.
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
  echo "  skip  no $DENY_FILE — create it to check for private names"
fi

echo "16. The standalone download route"
mkdir -p "$TMP/alone"; cp "$ROOT/install.sh" "$TMP/alone/install.sh"
if curl -fsS --max-time 20 -o /dev/null "https://codeload.github.com/${LWW_REPO:-aidilikbar/llm-wiki-workspace}/tar.gz/refs/heads/${LWW_REF:-main}" 2>/dev/null; then
  check "downloads and installs with no template/ beside it" \
    "cd '$TMP/alone' && bash install.sh --yes '$TMP/alone/out' && [ -e '$TMP/alone/out/system/RULES.md' ]"
else
  echo "  skip  no network to codeload.github.com"
fi

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
