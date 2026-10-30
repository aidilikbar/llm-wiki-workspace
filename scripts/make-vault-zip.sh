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
bash "$ROOT/install.sh" --yes --full --obsidian "$STAGE/$NAME" >/dev/null

cat > "$STAGE/$NAME/OPEN-ME-FIRST.md" <<'NOTE'
---
status: active
updated: 2026-01-01
owner: TODO
classification: public
---

# Open this folder as an Obsidian vault

1. In Obsidian, choose **Open folder as vault** and pick this folder.
2. Open the folder with your AI agent and tell it: *Read instruction.md and start the
   kick-off.*
3. Delete this file.

This copy has no git, so the front-matter check is off. To turn it on, run the
installer instead: it sets up git, checks the hook and makes the first commit.
NOTE

(cd "$STAGE" && zip -qr "$OUT/$NAME-$VERSION.zip" "$NAME")

echo "Built $OUT/$NAME-$VERSION.zip"
unzip -l "$OUT/$NAME-$VERSION.zip" | awk 'END { print NR-5 " files" }'
