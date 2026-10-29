#!/usr/bin/env node
'use strict';

// LLM Wiki Workspace — Node installer.
// Mirrors install.sh so Windows users get the same result without bash.
// CI diffs the output of the two to keep them identical.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const VERSION = '1.1.0';
const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'template');
const PRESET = path.join(ROOT, 'obsidian-preset');
const HANDOFF_SRC = path.join(ROOT, 'handoff');
const HANDOFF_MARKER = 'llm-wiki-workspace:handoff-protocol';

const CORE_PATHS = [
  'AGENTS.md', '.gitignore', '.githooks/pre-commit',
  'system/RULES.md', 'system/agents/escalation.md', 'system/templates',
  'context/AGENTS.md', 'context/constraints', 'context/requirements',
  'state/AGENTS.md', 'state/STATE.md', 'state/handoff.md', 'state/backlog',
  'record/AGENTS.md', 'record/decisions', 'record/logbook', 'record/backlog',
  'work/AGENTS.md', 'work/sources/INDEX.md', 'work/temp',
];

const EJECT_PATHS = [
  'template', 'handoff', 'install.sh', 'bin', 'scripts', 'obsidian-preset',
  'package.json', 'package-lock.json', 'docs', '.github',
];

const USAGE = `LLM Wiki Workspace installer

usage: npx llm-wiki-workspace [options] [folder]

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

general:
  -y, --yes         never ask; use the flags given and defaults for the rest
  --force           overwrite files that already exist
  --dry-run         print what would happen, write nothing
  --version         print the installer version
  -h, --help        this text`;

const say = (s = '') => console.log(s);
const warn = (s) => process.stderr.write(s + '\n');
function die(msg) { process.stderr.write(`error: ${msg}\n`); process.exit(1); }

// undefined means "ask, or default when not interactive"
const o = {
  mode: undefined, target: undefined, tier: undefined, obsidian: undefined,
  git: undefined, handoffIgnore: undefined, force: false, eject: false, dry: false, yes: false,
};

for (const arg of process.argv.slice(2)) {
  switch (arg) {
    case '--handoff': o.mode = 'handoff'; break;
    case '--core': o.tier = 'core'; break;
    case '--full': o.tier = 'full'; break;
    case '--obsidian': o.obsidian = true; break;
    case '--no-obsidian': o.obsidian = false; break;
    case '--git': o.git = true; break;
    case '--no-git': o.git = false; break;
    case '--handoff-ignore': o.handoffIgnore = true; break;
    case '--eject': o.eject = true; break;
    case '--force': o.force = true; break;
    case '--dry-run': o.dry = true; break;
    case '-y': case '--yes': case '--no-interaction': o.yes = true; break;
    case '--version': say(VERSION); process.exit(0); break;
    case '-h': case '--help': say(USAGE); process.exit(0); break;
    default:
      if (arg.startsWith('-')) die(`unknown option: ${arg} (try --help)`);
      o.target = arg;
  }
}

// ------------------------------------------------------------------ prompting
// Reads answers synchronously from the terminal (or LWW_TTY, a file of answers, for
// tests). Where there is no terminal to open — Windows, CI — it runs with defaults.

let ttyFd = null;
if (!o.yes && !process.env.LWW_NONINTERACTIVE) {
  try { ttyFd = fs.openSync(process.env.LWW_TTY || '/dev/tty', 'r'); } catch (_) { ttyFd = null; }
}
const interactive = ttyFd !== null;

function readLine() {
  let s = '';
  const b = Buffer.alloc(1);
  for (;;) {
    let n;
    try { n = fs.readSync(ttyFd, b, 0, 1, null); }
    catch (e) { if (e.code === 'EAGAIN') continue; return s; }
    if (n === 0) return s;
    const c = b.toString('utf8');
    if (c === '\n') return s;
    if (c !== '\r') s += c;
  }
}
function ask(q, d) {
  process.stderr.write(` ${q} [${d}]: `);
  const r = readLine();
  return r === '' ? d : r;
}
function askYN(q, d) {
  process.stderr.write(` ${q} [${d ? 'Y/n' : 'y/N'}]: `);
  const r = readLine();
  if (/^[Yy]/.test(r)) return true;
  if (/^[Nn]/.test(r)) return false;
  return d;
}
function askChoice(q, d, opts) {
  process.stderr.write(`\n ${q}\n`);
  opts.forEach((t, i) => process.stderr.write(`   [${i + 1}] ${t}\n`));
  process.stderr.write(` > [${d}]: `);
  const n = parseInt(readLine(), 10);
  return Number.isInteger(n) && n >= 1 && n <= opts.length ? n : d;
}

if (interactive) {
  process.stderr.write(`\n  LLM Wiki Workspace  v${VERSION}\n`);
  if (o.mode === undefined) {
    o.mode = askChoice('What would you like to set up?', 1, [
      'A workspace — the knowledge base your agents read and write',
      'A .handoff/ exchange in a code repo — for the planner–executor workflow',
    ]) === 2 ? 'handoff' : 'workspace';
  }
  if (o.target === undefined) {
    process.stderr.write('\n');
    o.target = o.mode === 'handoff'
      ? ask('Path to the code repo', '.')
      : ask('Where should the workspace go? A folder name, or . for this folder', '.');
  }
  if (o.mode === 'workspace') {
    if (o.tier === undefined) {
      o.tier = askChoice('Which structure?', 1, [
        'Core — the files you fill in during week one (recommended)',
        'Full — every folder, including design, architecture and evals',
      ]) === 2 ? 'full' : 'core';
    }
    process.stderr.write('\n');
    if (o.obsidian === undefined) o.obsidian = askYN('Configure it as an Obsidian vault?', false);
    if (o.git === undefined) o.git = askYN('Initialise git and turn on the front-matter check?', true);
  } else {
    process.stderr.write('\n');
    if (o.handoffIgnore === undefined) {
      o.handoffIgnore = !askYN('Commit .handoff/ to git? Answer no for restricted or air-gapped repos', true);
    }
  }
}

if (o.mode === undefined) o.mode = 'workspace';
if (o.target === undefined) o.target = '.';
if (o.tier === undefined) o.tier = 'core';
if (o.obsidian === undefined) o.obsidian = false;
if (o.git === undefined) o.git = false;
if (o.handoffIgnore === undefined) o.handoffIgnore = false;
const shown = o.target.replace(/\/$/, '') + '/';

if (interactive) {
  process.stderr.write('\n');
  if (o.mode === 'handoff') {
    process.stderr.write(`  .handoff/ exchange into ${shown}${o.handoffIgnore ? ', gitignored' : ''}\n`);
  } else {
    process.stderr.write(`  ${o.tier} workspace into ${shown}` +
      `${o.obsidian ? ', as an Obsidian vault' : ''}` +
      `${o.git ? ', with git and the front-matter check' : ''}\n`);
  }
  if (!askYN('Proceed?', true)) { say('Nothing written.'); process.exit(0); }
  process.stderr.write('\n');
}

// ------------------------------------------------------------------ helpers
if (!fs.existsSync(SRC)) die(`template directory not found at ${SRC}`);
const today = new Date().toISOString().slice(0, 10);
let installed = 0;
let skipped = 0;

function walk(dir, base = '', out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? path.posix.join(base, e.name) : e.name;
    if (e.isDirectory()) walk(path.join(dir, e.name), rel, out);
    else out.push(rel);
  }
  return out;
}

function coreList() {
  const out = [];
  for (const p of CORE_PATHS) {
    const abs = path.join(SRC, p);
    if (!fs.existsSync(abs)) { warn(`warning: core path missing from template: ${p}`); continue; }
    if (fs.statSync(abs).isDirectory()) walk(abs, p, out); else out.push(p);
  }
  return [...new Set(out)].sort();
}

// Stamp the install date onto a file's own `updated:` field, but only when the value
// is a real date. Templates carry the literal YYYY-MM-DD and keep it.
function stampDate(file) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  if (lines[0] !== '---') return;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') break;
    if (/^updated: \d{4}-\d{2}-\d{2}$/.test(lines[i])) lines[i] = `updated: ${today}`;
  }
  fs.writeFileSync(file, lines.join('\n'));
}

function copyTree(srcRoot, destRoot, rels, stamp) {
  for (const rel of rels) {
    const dest = path.join(destRoot, rel);
    if (fs.existsSync(dest) && !o.force) { skipped++; continue; }
    if (o.dry) {
      say(`  would write ${path.relative('.', dest) || dest}`);
    } else {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(path.join(srcRoot, rel), dest);
      if (rel.endsWith('.md') && stamp) stampDate(dest);
      if (rel.startsWith('.githooks/')) fs.chmodSync(dest, 0o755);
    }
    installed++;
  }
}

function appendBlock(file) {
  const name = path.basename(file);
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8').includes(HANDOFF_MARKER)) {
    say(`  ${name} already has the handoff protocol`); return;
  }
  if (o.dry) { say(`  would add the handoff protocol to ${name}`); return; }
  const block = fs.readFileSync(path.join(HANDOFF_SRC, '_agents-block.md'), 'utf8');
  if (fs.existsSync(file) && fs.statSync(file).size > 0) fs.appendFileSync(file, '\n' + block);
  else fs.writeFileSync(file, '# AGENTS.md\n\n' + block);
  say(`  added the handoff protocol to ${name}`);
}

function git(args) { return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); }

// ------------------------------------------------------------------ handoff mode
if (o.mode === 'handoff') {
  if (!fs.existsSync(o.target) || !fs.statSync(o.target).isDirectory()) {
    die(`no such folder: ${o.target} — --handoff installs into an existing code repo`);
  }
  if (fs.existsSync(path.join(o.target, 'system/RULES.md')) && fs.existsSync(path.join(o.target, 'state'))) {
    warn(`warning: ${o.target} looks like a workspace, not a code repo. .handoff/ belongs in the code repo.`);
  }
  if (o.dry) say('DRY RUN — nothing will be written');
  say(`Setting up .handoff/ in ${shown}`);

  copyTree(HANDOFF_SRC, path.join(o.target, '.handoff'),
    walk(HANDOFF_SRC).filter((r) => r !== '_agents-block.md').sort(), false);

  appendBlock(path.join(o.target, 'AGENTS.md'));

  const claude = path.join(o.target, 'CLAUDE.md');
  let lst = null;
  try { lst = fs.lstatSync(claude); } catch (_) { lst = null; }
  if (lst && lst.isSymbolicLink()) {
    say('  CLAUDE.md is a link; left as it is');
  } else if (lst) {
    appendBlock(claude);
  } else if (o.dry) {
    say('  would link CLAUDE.md to AGENTS.md');
  } else {
    try { fs.symlinkSync('AGENTS.md', claude); say('  linked CLAUDE.md to AGENTS.md'); }
    catch (_) {
      // Windows without symlink rights: a copy is the fallback.
      fs.copyFileSync(path.join(o.target, 'AGENTS.md'), claude);
      say('  could not link CLAUDE.md; wrote a copy of AGENTS.md instead');
    }
  }

  if (o.handoffIgnore) {
    const gi = path.join(o.target, '.gitignore');
    const cur = fs.existsSync(gi) ? fs.readFileSync(gi, 'utf8') : '';
    if (cur.split('\n').includes('.handoff/')) {
      say('  .gitignore already ignores .handoff/');
    } else if (o.dry) {
      say('  would add .handoff/ to .gitignore');
    } else {
      fs.appendFileSync(gi, (cur.length && !cur.endsWith('\n') ? '\n' : '') + '.handoff/\n');
      say('  added .handoff/ to .gitignore');
    }
  }

  say('');
  say(`Wrote ${installed} file(s); skipped ${skipped} that already existed.`);
  say(`
Next:

  1. The planner writes .handoff/tasks/T-001.md from .handoff/templates/task.md
  2. Tell the executor, in this repo:  run T-001
  3. Tell the planner:                 review T-001

The full loop is in system/workflows/planner-executor.md in your workspace.`);
  process.exit(0);
}

// ------------------------------------------------------------------ workspace mode
if (o.dry) say('DRY RUN — nothing will be written');
say(`Installing the ${o.tier} workspace into ${shown}`);
if (!o.dry) fs.mkdirSync(o.target, { recursive: true });

copyTree(SRC, o.target, o.tier === 'full' ? walk(SRC).sort() : coreList(), true);

if (o.obsidian) {
  if (!fs.existsSync(PRESET)) die(`obsidian preset not found at ${PRESET}`);
  copyTree(PRESET, path.join(o.target, '.obsidian'), walk(PRESET).sort(), false);
}

if (o.eject) {
  for (const p of EJECT_PATHS) {
    const abs = path.join(o.target, p);
    if (!fs.existsSync(abs)) continue;
    if (o.dry) say(`  would remove ${p}`); else fs.rmSync(abs, { recursive: true, force: true });
  }
  const readme = path.join(o.target, 'README.md');
  if (fs.existsSync(readme) && fs.readFileSync(readme, 'utf8').includes('llm-wiki-workspace:upstream-readme')) {
    if (o.dry) say('  would replace README.md with a project stub');
    else fs.writeFileSync(readme, '# <project name>\n\nAn LLM Wiki Workspace. Zones: `context/` stable, `state/` current, `record/`\nappend-only, `work/` untrusted. Start at `AGENTS.md`, then `system/RULES.md`.\n');
  }
}

let hookOn = false;
if (o.git) {
  let haveGit = true;
  try { git(['--version']); } catch (_) { haveGit = false; }
  if (!haveGit) {
    warn('warning: git not found; skipped git init and the front-matter check');
  } else if (o.dry) {
    say('  would initialise git and set core.hooksPath to .githooks');
  } else {
    const absTarget = fs.realpathSync(o.target);
    let top = null;
    try { top = fs.realpathSync(git(['-C', o.target, 'rev-parse', '--show-toplevel'])); } catch (_) { top = null; }
    if (top && top !== absTarget) {
      warn(`warning: ${o.target} is inside the git repository at ${top}.`);
      warn("         core.hooksPath is relative to that repository's root, so it was not set.");
    } else {
      if (!top) { git(['-C', o.target, 'init', '-q']); say('  initialised a git repository'); }
      git(['-C', o.target, 'config', 'core.hooksPath', '.githooks']);
      hookOn = true;
      say('  front-matter check is on (core.hooksPath = .githooks)');
    }
  }
}

say('');
say(`Wrote ${installed} file(s); skipped ${skipped} that already existed.`);
if (skipped > 0 && !o.force) say('Re-run with --force to overwrite the skipped files.');

const steps = [];
if (!hookOn) steps.push('git config core.hooksPath .githooks     turn on the front-matter check');
steps.push('fill context/constraints/               highest-value folder in the tree');
steps.push('fill system/agents/escalation.md        what the agent may decide alone');
steps.push('fill the Commands block in AGENTS.md    your real install/test/lint commands');
say(`\nNext, in ${shown}:\n`);
steps.forEach((s, i) => say(`  ${i + 1}. ${s}`));
say(`
Verify the check is live:

  printf '# no front matter\\n' > context/constraints/tmp-check.md
  git add context/constraints/tmp-check.md && git commit -m 'should fail'
  rm context/constraints/tmp-check.md

The commit must be rejected. If it is not, the hook is not on.`);
