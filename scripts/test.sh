#!/usr/bin/env bash
#
# Verification suite. Everything the README claims, checked.
#
#   bash scripts/test.sh
#
# Exits non-zero on the first failure. CI runs this on every push.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok()   { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "1. Syntax"
check "install.sh parses"            "bash -n '$ROOT/install.sh'"
check "make-vault-zip.sh parses"     "bash -n '$ROOT/scripts/make-vault-zip.sh'"
check "test.sh parses"               "bash -n '$ROOT/scripts/test.sh'"
check "pre-commit hook parses"       "bash -n '$ROOT/template/.githooks/pre-commit'"
if command -v node >/dev/null 2>&1; then
  check "bin/cli.js parses"          "node --check '$ROOT/bin/cli.js'"
  check "package.json is valid JSON" "node -e \"require('$ROOT/package.json')\""
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
    awk 'NR==1 && $0!="---"{exit} NR==1{next} $0=="---"{exit} {print}' "$f" \
      | grep -q "^$k:[[:space:]]*[^[:space:]]" \
      || { echo "     $f missing $k"; bare=1; }
  done
done < <(find "$ROOT/template" -name '*.md' \
         ! -name 'README.md' ! -name 'AGENTS.md' ! -path '*/work/temp/*')
[ "$bare" -eq 0 ] && ok "all payload markdown carries the four required fields" \
                  || bad "payload markdown missing required front matter"

echo "4. Core install"
bash "$ROOT/install.sh" "$TMP/core" >/dev/null 2>&1
for p in AGENTS.md system/RULES.md system/agents/escalation.md state/STATE.md \
         record/AGENTS.md work/sources/INDEX.md .githooks/pre-commit .gitignore; do
  check "core has $p" "[ -e '$TMP/core/$p' ]"
done
check "core omits the optional tier" "[ ! -e '$TMP/core/context/vision.md' ]"
check "core leaks no packaging"      "[ ! -e '$TMP/core/template' ] && [ ! -e '$TMP/core/install.sh' ]"
check "hook is executable"           "[ -x '$TMP/core/.githooks/pre-commit' ]"
check "updated: is stamped to today" "grep -q \"^updated: $(date +%F)\$\" '$TMP/core/state/STATE.md'"
check "templates keep YYYY-MM-DD"    "grep -q '^updated: YYYY-MM-DD$' '$TMP/core/system/templates/adr.md'"

check "core install exits 0" "bash '$ROOT/install.sh' '$TMP/exitcode' >/dev/null 2>&1"
check "--help exits 0"        "bash '$ROOT/install.sh' --help >/dev/null 2>&1"
check "--dry-run exits 0"     "bash '$ROOT/install.sh' --dry-run '$TMP/dry2' >/dev/null 2>&1"
check "re-install exits 0"    "bash '$ROOT/install.sh' '$TMP/exitcode' >/dev/null 2>&1"
if command -v node >/dev/null 2>&1; then
  check "node install exits 0" "node '$ROOT/bin/cli.js' '$TMP/exitcode-node' >/dev/null 2>&1"
fi

echo "5. Full install"
bash "$ROOT/install.sh" --full "$TMP/full" >/dev/null 2>&1
check "full has context/vision.md"       "[ -e '$TMP/full/context/vision.md' ]"
check "full has all five role files"     "[ \$(ls '$TMP/full/system/agents' | wc -l) -eq 6 ]"
check "full is larger than core" \
  "[ \$(find '$TMP/full' -type f | wc -l) -gt \$(find '$TMP/core' -type f | wc -l) ]"

echo "6. Obsidian install"
bash "$ROOT/install.sh" --full --obsidian "$TMP/vault" >/dev/null 2>&1
check "vault has .obsidian/app.json"      "[ -e '$TMP/vault/.obsidian/app.json' ]"
check "templates plugin points at system/templates" \
  "python3 -c \"import json;assert json.load(open('$TMP/vault/.obsidian/templates.json'))['folder']=='system/templates'\""
check "core plugins enable templates"     "python3 -c \"import json;assert json.load(open('$TMP/vault/.obsidian/core-plugins.json'))['templates'] is True\""
check "plain install writes no .obsidian" "[ ! -e '$TMP/full/.obsidian' ]"

echo "7. Existing files are never clobbered"
mkdir -p "$TMP/existing"
printf 'MINE\n' > "$TMP/existing/AGENTS.md"
bash "$ROOT/install.sh" "$TMP/existing" >/dev/null 2>&1
check "an existing file survives"     "grep -qx MINE '$TMP/existing/AGENTS.md'"
bash "$ROOT/install.sh" --force "$TMP/existing" >/dev/null 2>&1
check "--force overwrites it"         "! grep -qx MINE '$TMP/existing/AGENTS.md'"

echo "8. Dry run writes nothing"
bash "$ROOT/install.sh" --dry-run "$TMP/dry" >/dev/null 2>&1
check "no target directory created"   "[ ! -e '$TMP/dry/AGENTS.md' ]"

echo "9. The front matter hook actually blocks a commit"
git init -q "$TMP/repo"
bash "$ROOT/install.sh" "$TMP/repo" >/dev/null 2>&1
(
  cd "$TMP/repo"
  git config user.email test@example.com
  git config user.name  Test
  git config core.hooksPath .githooks
  git add -A >/dev/null 2>&1
  git commit -qm "workspace" >/dev/null 2>&1
) 
check "a clean workspace commits"     "git -C '$TMP/repo' rev-parse HEAD"
printf '# no front matter\n' > "$TMP/repo/context/constraints/bad.md"
(cd "$TMP/repo" && git add context/constraints/bad.md >/dev/null 2>&1 && git commit -qm bad >/dev/null 2>&1)
check "a file without front matter is rejected" \
  "[ \$(git -C '$TMP/repo' rev-list --count HEAD) -eq 1 ]"
rm -f "$TMP/repo/context/constraints/bad.md"
printf -- '---\nstatus: draft\nupdated: 2026-01-01\nowner: test\nclassification: public\n---\n\n# ok\n' \
  > "$TMP/repo/context/constraints/good.md"
(cd "$TMP/repo" && git add context/constraints/good.md >/dev/null 2>&1 && git commit -qm good >/dev/null 2>&1)
check "a file with front matter is accepted" \
  "[ \$(git -C '$TMP/repo' rev-list --count HEAD) -eq 2 ]"

echo "10. bash and node installers agree"
if command -v node >/dev/null 2>&1; then
  bash "$ROOT/install.sh" --full --obsidian "$TMP/via-bash" >/dev/null 2>&1
  node "$ROOT/bin/cli.js" --full --obsidian "$TMP/via-node" >/dev/null 2>&1
  check "identical trees" "diff -r '$TMP/via-bash' '$TMP/via-node'"
else
  echo "  skip  node not installed"
fi

echo "11. Eject leaves a bare workspace"
mkdir -p "$TMP/tpl"
cp -R "$ROOT/template" "$ROOT/install.sh" "$ROOT/bin" "$ROOT/scripts" \
      "$ROOT/obsidian-preset" "$ROOT/package.json" "$ROOT/README.md" "$TMP/tpl/" 2>/dev/null
bash "$TMP/tpl/install.sh" --full --eject "$TMP/tpl" >/dev/null 2>&1
check "template/ is gone"          "[ ! -e '$TMP/tpl/template' ]"
check "install.sh is gone"         "[ ! -e '$TMP/tpl/install.sh' ]"
check "the workspace remains"      "[ -e '$TMP/tpl/system/RULES.md' ] && [ -e '$TMP/tpl/AGENTS.md' ]"
check "README was replaced"        "! grep -q 'upstream-readme' '$TMP/tpl/README.md'"

echo "12. Nothing private is named anywhere"
# The list of names to scrub is deliberately NOT in this repository — publishing it
# would leak exactly what it exists to keep out. Put one term per line in
# .private-names (gitignored) or point LWW_DENYLIST at a file elsewhere.
DENY_FILE="${LWW_DENYLIST:-$ROOT/.private-names}"
if [ -f "$DENY_FILE" ]; then
  leak=0
  while IFS= read -r term; do
    case "$term" in ''|\#*) continue ;; esac
    if grep -ril "$term" "$ROOT" \
         --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist \
         --exclude=".private-names" >/dev/null 2>&1; then
      echo "     found: $term"; leak=1
    fi
  done < "$DENY_FILE"
  [ "$leak" -eq 0 ] && ok "no private names in the tree" || bad "private names found"
else
  echo "  skip  no $DENY_FILE — create it to check for private names"
fi

echo "13. Survives a hostile PATH"
# conda and perl LWP both ship a `head` that fetches URLs and rejects -n. Anything the
# installer needs must either not be shadowed or not be used.
mkdir -p "$TMP/hostile"
cat > "$TMP/hostile/head" <<'SHADOW'
#!/bin/sh
echo "Unknown option: n" >&2
echo "Usage: head [-options] <url>..." >&2
exit 1
SHADOW
chmod +x "$TMP/hostile/head"
check "install.sh runs with head(1) shadowed" \
  "PATH='$TMP/hostile:$PATH' bash '$ROOT/install.sh' '$TMP/hostile-out' >/dev/null 2>&1"
check "the tree is complete anyway" \
  "[ -e '$TMP/hostile-out/system/RULES.md' ] && [ -e '$TMP/hostile-out/AGENTS.md' ]"
check "front matter was still stamped" \
  "grep -q \"^updated: $(date +%F)\$\" '$TMP/hostile-out/state/STATE.md'"
if command -v node >/dev/null 2>&1; then
  check "the node installer too" \
    "PATH='$TMP/hostile:$PATH' node '$ROOT/bin/cli.js' '$TMP/hostile-node' >/dev/null 2>&1"
fi

echo "14. The standalone download route"
# install.sh with no template/ beside it must fetch the repository itself. Skipped
# without network, since that is the one thing this check cannot fake.
mkdir -p "$TMP/alone"
cp "$ROOT/install.sh" "$TMP/alone/install.sh"
if curl -fsS --max-time 20 -o /dev/null "https://codeload.github.com/${LWW_REPO:-aidilikbar/llm-wiki-workspace}/tar.gz/refs/heads/${LWW_REF:-main}" 2>/dev/null; then
  check "downloads and installs with no template/ present" \
    "cd '$TMP/alone' && bash install.sh '$TMP/alone/out' >/dev/null 2>&1 && [ -e '$TMP/alone/out/system/RULES.md' ]"
else
  echo "  skip  no network to codeload.github.com"
fi

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
