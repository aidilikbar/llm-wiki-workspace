#!/usr/bin/env bash
#
# Builds the Obsidian-ready release asset: a folder you unzip and open as a vault.
#
#   bash scripts/make-vault-zip.sh [version]
#
# Output: dist/llm-wiki-workspace-vault-<version>.zip

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION="${1:-$(node -p "require('$ROOT/package.json').version" 2>/dev/null || echo dev)}"
OUT="$ROOT/dist"
STAGE=$(mktemp -d)
NAME="llm-wiki-workspace-vault"

trap 'rm -rf "$STAGE"' EXIT

command -v zip >/dev/null 2>&1 || { echo "error: zip is required" >&2; exit 1; }

mkdir -p "$OUT"
mkdir -p "$STAGE/$NAME"

# Full tree plus the Obsidian config, so the unzipped folder opens as a vault.
bash "$ROOT/install.sh" --full --obsidian "$STAGE/$NAME" >/dev/null

cat > "$STAGE/$NAME/OPEN-ME-FIRST.md" <<'NOTE'
---
status: active
updated: 2026-01-01
owner: TODO
classification: public
---

# Open this folder as an Obsidian vault

1. Open Obsidian → **Open folder as vault** → choose this folder.
2. Trust the folder when asked. The bundled config only sets core plugins, the
   templates folder and graph colours; there are no community plugins.
3. Start at `AGENTS.md`, then `system/RULES.md`.
4. Fill `context/constraints/` first. It prevents more bad agent work than anything
   else in the tree.

To version this vault with git as well:

```bash
git init
git config core.hooksPath .githooks
git add -A && git commit -m "Start workspace"
```

Delete this file once you have read it.
NOTE

(cd "$STAGE" && zip -qr "$OUT/$NAME-$VERSION.zip" "$NAME")

echo "Built $OUT/$NAME-$VERSION.zip"
unzip -l "$OUT/$NAME-$VERSION.zip" | awk 'END { print NR-5 " files" }'
