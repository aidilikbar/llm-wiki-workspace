#!/usr/bin/env node
'use strict';

// LLM Wiki Workspace — Node installer.
// Mirrors install.sh so Windows users get the same tree without bash.
// CI diffs the output of the two to keep them identical.

const fs = require('fs');
const path = require('path');

const VERSION = '1.0.0';
const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'template');
const PRESET = path.join(ROOT, 'obsidian-preset');

const CORE_PATHS = [
  'AGENTS.md',
  '.gitignore',
  '.githooks/pre-commit',
  'system/RULES.md',
  'system/agents/escalation.md',
  'system/templates',
  'context/AGENTS.md',
  'context/constraints',
  'context/requirements',
  'state/AGENTS.md',
  'state/STATE.md',
  'state/handoff.md',
  'record/AGENTS.md',
  'record/decisions',
  'record/logbook',
  'work/AGENTS.md',
  'work/sources/INDEX.md',
  'work/temp',
];

const EJECT_PATHS = [
  'template', 'install.sh', 'bin', 'scripts', 'obsidian-preset',
  'package.json', 'package-lock.json', 'docs', '.github',
];

const USAGE = `LLM Wiki Workspace installer

usage: npx llm-wiki-workspace [options] [target-directory]

options:
  --full        install the entire tree (default: the core tier only)
  --obsidian    also write .obsidian/ so the folder opens as an Obsidian vault
  --force       overwrite files that already exist in the target
  --eject       after installing, delete the packaging files from the target
  --dry-run     print what would happen, write nothing
  --version     print the installer version
  -h, --help    this text

target-directory defaults to the current directory and is created if missing.`;

function die(msg) {
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}

const opts = { target: '.', tier: 'core', obsidian: false, force: false, eject: false, dry: false };

for (const arg of process.argv.slice(2)) {
  switch (arg) {
    case '--full': opts.tier = 'full'; break;
    case '--obsidian': opts.obsidian = true; break;
    case '--force': opts.force = true; break;
    case '--eject': opts.eject = true; break;
    case '--dry-run': opts.dry = true; break;
    case '--version': console.log(VERSION); process.exit(0); break;
    case '-h': case '--help': console.log(USAGE); process.exit(0); break;
    default:
      if (arg.startsWith('-')) die(`unknown option: ${arg} (try --help)`);
      opts.target = arg;
  }
}

if (!fs.existsSync(SRC)) die(`template directory not found at ${SRC}`);

function walk(dir, base, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, entry.name);
    const rel = path.posix.join(base, entry.name);
    if (entry.isDirectory()) walk(abs, rel, out);
    else out.push(rel);
  }
  return out;
}

function fileList() {
  if (opts.tier === 'full') return walk(SRC, '', []).sort();
  const out = [];
  for (const p of CORE_PATHS) {
    const abs = path.join(SRC, p);
    if (!fs.existsSync(abs)) {
      process.stderr.write(`warning: core path missing from template: ${p}\n`);
      continue;
    }
    if (fs.statSync(abs).isDirectory()) walk(abs, p, out);
    else out.push(p);
  }
  return [...new Set(out)].sort();
}

// Stamp the install date onto a file's own `updated:` field, but only when the value
// is a real date. Templates carry the literal YYYY-MM-DD and keep it.
function stampDate(file, today) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split('\n');
  if (lines[0] !== '---') return;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') break;
    if (/^updated: \d{4}-\d{2}-\d{2}$/.test(lines[i])) lines[i] = `updated: ${today}`;
  }
  fs.writeFileSync(file, lines.join('\n'));
}

const today = new Date().toISOString().slice(0, 10);
let installed = 0;
let skipped = 0;

function copyInto(srcRoot, relPaths, destPrefix) {
  for (const rel of relPaths) {
    const dest = path.join(opts.target, destPrefix, rel);
    if (fs.existsSync(dest) && !opts.force) { skipped++; continue; }
    if (opts.dry) {
      console.log(`  would write ${path.posix.join(destPrefix, rel)}`);
    } else {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(path.join(srcRoot, rel), dest);
      if (rel.endsWith('.md')) stampDate(dest, today);
      if (rel.startsWith('.githooks/')) fs.chmodSync(dest, 0o755);
    }
    installed++;
  }
}

if (opts.dry) console.log('DRY RUN — nothing will be written');
console.log(`Installing the ${opts.tier} tier into ${opts.target.replace(/\/$/, '')}/`);
if (!opts.dry) fs.mkdirSync(opts.target, { recursive: true });

copyInto(SRC, fileList(), '');

if (opts.obsidian) {
  if (!fs.existsSync(PRESET)) die(`obsidian preset not found at ${PRESET}`);
  copyInto(PRESET, walk(PRESET, '', []).sort(), '.obsidian');
}

if (opts.eject) {
  for (const p of EJECT_PATHS) {
    const abs = path.join(opts.target, p);
    if (!fs.existsSync(abs)) continue;
    if (opts.dry) console.log(`  would remove ${p}`);
    else fs.rmSync(abs, { recursive: true, force: true });
  }
  const readme = path.join(opts.target, 'README.md');
  if (fs.existsSync(readme) &&
      fs.readFileSync(readme, 'utf8').includes('llm-wiki-workspace:upstream-readme')) {
    const stub = `# <project name>

An LLM Wiki Workspace. Zones: \`context/\` stable, \`state/\` current, \`record/\`
append-only, \`work/\` untrusted. Start at \`AGENTS.md\`, then \`system/RULES.md\`.
`;
    if (opts.dry) console.log('  would replace README.md with a project stub');
    else fs.writeFileSync(readme, stub);
  }
}

console.log('');
console.log(`Wrote ${installed} file(s); skipped ${skipped} that already existed.`);
if (skipped > 0 && !opts.force) console.log('Re-run with --force to overwrite the skipped files.');

console.log(`
Next, in ${opts.target.replace(/\/$/, '')}/:

  1. git config core.hooksPath .githooks     turn on the front-matter check
  2. fill context/constraints/               highest-value file in the tree
  3. fill system/agents/escalation.md        what the agent may decide alone
  4. fill the Commands block in AGENTS.md    your real install/test/lint commands
`);
