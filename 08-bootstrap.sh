#!/usr/bin/env bash
# LLM Wiki Workspace — bootstrap
#
#   ./bootstrap.sh          core tier only (recommended)
#   ./bootstrap.sh --full   entire tree
#
# Creates directories and stubs. Copy the Gist files in afterwards; see the mapping
# table in README.

set -euo pipefail
FULL=0
[[ "${1:-}" == "--full" ]] && FULL=1
TODAY=$(date +%F)

fm() { # fm <classification>
  printf -- '---\nstatus: draft\nupdated: %s\nowner: TODO\nclassification: %s\n---\n\n' "$TODAY" "$1"
}

stub() { # stub <path> <classification> <heading>
  [[ -e "$1" ]] && return 0
  mkdir -p "$(dirname "$1")"
  { fm "$2"; printf '# %s\n\nTODO\n' "$3"; } > "$1"
}

keep() { mkdir -p "$1"; [[ -e "$1/.gitkeep" ]] || touch "$1/.gitkeep"; }

# ---------------------------------------------------------------- core tier
mkdir -p system/agents system/templates
mkdir -p context/constraints context/requirements
mkdir -p state
mkdir -p record/decisions record/logbook
mkdir -p work/sources work/temp

keep context/constraints
keep record/decisions
keep record/logbook
keep work/temp

stub system/RULES.md                                public   "RULES"
stub system/agents/escalation.md                    public   "Roles and escalation"
stub system/templates/_frontmatter.md               public   "Front matter schema"
stub context/requirements/functional-requirements.md     internal "Functional requirements"
stub context/requirements/non-functional-requirements.md internal "Non-functional requirements"
stub context/requirements/acceptance-criteria.md         internal "Acceptance criteria"
stub state/STATE.md                                 internal "STATE"
stub state/handoff.md                               internal "Handoff"
stub work/sources/INDEX.md                          internal "Source index"

# AGENTS.md and README.md are entry points, not wiki content: no front matter.
[[ -e AGENTS.md ]] || printf '# AGENTS.md\n\nTODO — copy from the Gist.\n' > AGENTS.md
for z in context state record work; do
  [[ -e "$z/AGENTS.md" ]] || printf '# %s/ — zone rules\n\nTODO — copy from the Gist.\n' "$z" > "$z/AGENTS.md"
done

cat > README.md <<EOF
# <project name>

LLM Wiki Workspace. Zones: \`context/\` stable, \`state/\` current, \`record/\` append-only,
\`work/\` untrusted. See \`AGENTS.md\` and \`system/RULES.md\`.

Bootstrapped $TODAY.
EOF

cat > .gitignore <<'EOF'
work/temp/*
!work/temp/.gitkeep
EOF

# ---------------------------------------------------------------- full tier
if [[ $FULL -eq 1 ]]; then
  for d in \
    system/skills system/evals system/workflows \
    context/principles context/architecture/infrastructures \
    context/architecture/schemas context/architecture/security \
    context/design/design-system context/design/assets \
    record/sprints record/releases record/retrospectives record/eval-runs \
    work/analysis
  do keep "$d"; done

  stub system/workflows/documentation-workflow.md internal "Documentation workflow"
  stub system/workflows/onboarding.md             internal "Onboarding"
  stub context/vision.md                          internal "Vision"
  stub context/architecture/system-overview.md    internal "System overview"
  stub context/design/DESIGN.md                   internal "Design tokens"
  stub state/roadmap.md                           internal "Roadmap"
  stub state/sprint-current.md                    internal "Sprint — current"
  stub state/backlog.md                           internal "Backlog"
  stub state/icebox.md                            internal "Icebox"

  cat > state/codebase-map.md <<EOF
---
status: draft
updated: $TODAY
owner: engineer
classification: internal
generated: true
source: TODO
---

# Codebase map

GENERATED — do not hand-edit. Regenerate instead.
EOF

  for t in adr handoff logbook sprint retro release backlog-item icebox-item skill; do
    stub "system/templates/$t.md" public "$t template"
  done
fi

# ---------------------------------------------------------------- check hook
mkdir -p .githooks
cat > .githooks/pre-commit <<'EOF'
#!/usr/bin/env bash
fail=0
while IFS= read -r f; do
  for k in status updated owner classification; do
    head -n 10 "$f" | grep -q "^$k:" || { echo "front matter missing '$k': $f"; fail=1; }
  done
done < <(git diff --cached --name-only --diff-filter=ACM \
         | grep '\.md$' \
         | grep -v '^work/temp/' \
         | grep -vE '(^|/)(README|AGENTS)\.md$')
exit $fail
EOF
chmod +x .githooks/pre-commit

echo "Done. Next:"
echo "  git init && git config core.hooksPath .githooks"
echo "  Copy the Gist files in per the README mapping table."
echo "  Fill context/constraints/ and system/agents/escalation.md first."
